#!/usr/bin/env perl

use v5.18;
use Mojolicious::Lite;

use Data::Pageset;
use DateTime;
use List::MoreUtils qw( zip );
use SMS::Send::KR::CoolSMS;
use SMS::Send;
use Try::Tiny;

use Opencloset::Constant;
use Opencloset::Schema;

plugin 'validator';
plugin 'haml_renderer';
plugin 'FillInFormLite';

my @CATEGORIES = qw( jacket pants shirt shoes hat tie waistcoat coat onepiece skirt blouse belt );

app->defaults( %{ plugin 'Config' => { default => {
    jses        => [],
    csses       => [],
    breadcrumbs => [],
    active_id   => q{},
}}});

my $DB = Opencloset::Schema->connect({
    dsn      => app->config->{database}{dsn},
    user     => app->config->{database}{user},
    password => app->config->{database}{pass},
    %{ app->config->{database}{opts} },
});

helper error => sub {
    my ($self, $status, $error) = @_;

    ## TODO: `ok.haml.html`, `bad_request.haml.html`, `internal_error.haml.html`
    my %error_map = (
        200 => 'ok',
        400 => 'bad_request',
        404 => 'not_found',
        500 => 'internal_error',
    );

    $self->respond_to(
        json => { json => { error => $error || '' }, status => $status },
        html => {
            template => $error_map{$status},
            error    => $error || '',
            status   => $status
        }
    );

    return;
};

helper cloth_validator => sub {
    my $self = shift;

    my $validator = $self->create_validator;
    $validator->field('category')->required(1);
    $validator->field('gender')->required(1)->regexp(qr/^[123]$/);

    # jacket
    $validator->when('category')->regexp(qr/jacket/)
        ->then(sub { shift->field(qw/ bust arm /)->required(1) });

    # pants, skirts
    $validator->when('category')->regexp(qr/(pants|skirt)/)
        ->then(sub { shift->field(qw/ waist length /)->required(1) });

    # shoes
    $validator->when('category')->regexp(qr/^shoes$/)
        ->then(sub { shift->field('length')->required(1) });

    $validator->field(qw/ bust waist hip arm length /)
        ->each(sub { shift->regexp(qr/^\d+$/) });

    return $validator;
};

helper cloth2hr => sub {
    my ($self, $clothes) = @_;

    return {
        $clothes->get_columns,
        donor    => $clothes->donor ? $clothes->user->name : '',
        category => $clothes->category,
        price    => $self->commify($clothes->price),
        status   => $clothes->status->name,
    };
};

helper sms2hr => sub {
    my ($self, $sms) = @_;

    return { $sms->get_columns };
};

helper order_price => sub {
    my ( $self, $order, $commify ) = @_;

    return 0 unless $order;

    my $price = 0;
    $price += $_->price for $order->order_details;

    return $commify ? $self->commify($price) : $price;
};

helper calc_overdue => sub {
    my ( $self, $target_dt, $return_dt ) = @_;

    return unless $target_dt;

    $return_dt ||= DateTime->now;

    my $DAY_AS_SECONDS = 60 * 60 * 24;

    my $epoch1 = $target_dt->epoch;
    my $epoch2 = $return_dt->epoch;

    my $dur = $epoch2 - $epoch1;
    return 0 if $dur < 0;
    return int($dur / $DAY_AS_SECONDS);
};

helper commify => sub {
    my $self = shift;
    local $_ = shift;
    1 while s/((?:\A|[^.0-9])[-+]?\d+)(\d{3})/$1,$2/s;
    return $_;
};

helper calc_late_fee => sub {
    my ( $self, $order, $commify ) = @_;

    my $price = 0;
    $price += $_->price for $order->order_details;

    my $overdue  = $self->calc_overdue( $order->target_date );
    return 0 unless $overdue;

    my $late_fee = $price * 0.2 * $overdue;

    return $commify ? $self->commify($late_fee) : $late_fee;
};

helper flatten_order => sub {
    my ( $self, $order ) = @_;

    return unless $order;

    my %data = (
        $order->get_columns,
        rental_date => undef,
        target_date => undef,
        return_date => undef,
        price       => $self->order_price( $order, 'commify' ),
        clothes     => [ $order->clothes->get_column('code')->all ],
        late_fee    => $self->calc_late_fee( $order, 'commify' ),
        overdue     => $self->calc_overdue( $order->target_date ),
    );

    if ( $order->rental_date ) {
        $data{rental_date} = {
            raw => $order->rental_date,
            md  => $order->rental_date->month . '/' . $order->rental_date->day,
            ymd => $order->rental_date->ymd
        };
    }

    if ( $order->target_date ) {
        $data{target_date} = {
            raw => $order->target_date,
            md  => $order->target_date->month . '/' . $order->target_date->day,
            ymd => $order->target_date->ymd
        };
    }

    if ( $order->return_date ) {
        $data{return_date} = {
            raw => $order->return_date,
            md  => $order->return_date->month . '/' . $order->return_date->day,
            ymd => $order->return_date->ymd
        };
    }

    return \%data;
};

helper user_validator => sub {
    my $self = shift;

    my $validator = $self->create_validator;
    $validator->field('name')->required(1);
    $validator->field('phone')->regexp(qr/^01\d{8,9}$/);
    $validator->field('email')->email;
    $validator->field('gender')->regexp(qr/^[12]$/);
    $validator->field('age')->regexp(qr/^\d+$/);

    ## TODO: check exist email and set to error
    return $validator;
};

helper create_user => sub {
    my $self = shift;

    my %params;
    map {
        $params{$_} = $self->param($_) if defined $self->param($_)
    } qw/name email password phone gender age address/;

    return $DB->resultset('User')->find_or_create(\%params);
};

helper guest_validator => sub {
    my $self = shift;

    my $validator = $self->create_validator;
    $validator->field([qw/bust waist arm length height weight/])
        ->each(sub { shift->required(1)->regexp(qr/^\d+$/) });

    ## TODO: validate `target_date`
    return $validator;
};

helper create_cloth => sub {
    my ($self, %info) = @_;

    #
    # FIXME generate code
    #
    my $code;
    {
        my $clothes = $DB->resultset('Clothes')->search(
            { category => $info{category} },
            { order_by => { -desc => 'code' } },
        )->next;

        my $index = 1;
        if ($clothes) {
            $index = substr $clothes->code, -5, 5;
            $index =~ s/^0+//;
            $index++;
        }

        $code = sprintf '%05d', $index;
    }

    #
    # tune params to create clothes
    #
    my %params = (
        code            => $code,
        donor_id        => $self->param('donor_id') || undef,
        category        => $info{category},
        status_id       => $Opencloset::Constant::STATUS_AVAILABLE,
        gender          => $info{gender},
        color           => $info{color},
        compatible_code => $info{compatible_code},
    );
    {
        no warnings 'experimental';

        my @keys;
        given ( $info{category} ) {
            @keys = qw( bust arm )          when /^(jacket|shirt|waistcoat|coat|blouse)$/i;
            @keys = qw( waist length )      when /^(pants|skirt)$/i;
            @keys = qw( bust waist length ) when /^(onepiece)$/i;
            @keys = qw( length )            when /^(shoes)$/i;
        }
        map { $params{$_} = $info{$_} } @keys;
    }

    my $new_cloth = $DB->resultset('Clothes')->find_or_create(\%params);
    return unless $new_cloth;
    return $new_cloth unless $new_cloth->compatible_code;

    my $compatible_code = $new_cloth->compatible_code;
    $compatible_code =~ s/[A-Z]/_/g;
    my $top_or_bottom = $DB->resultset('Clothes')->search({
        category        => { '!=' => $new_cloth->category },
        compatible_code => { like => $compatible_code },
    })->next;

    if ($top_or_bottom) {
        no warnings 'experimental';
        given ( $top_or_bottom->category ) {
            when ( /^(jacket|shirt|waistcoat|coat|blouse)$/i ) {
                $new_cloth->top_id($top_or_bottom->id);
                $top_or_bottom->bottom_id($new_cloth->id);
                $new_cloth->update;
                $top_or_bottom->update;
            }
            when ( /^(pants|skirt)$/i ) {
                $new_cloth->bottom_id($top_or_bottom->id);
                $top_or_bottom->top_id($new_cloth->id);
                $new_cloth->update;
                $top_or_bottom->update;
            }
        }
    }

    return $new_cloth;
};

helper _q => sub {
    my ($self, %params) = @_;

    my $q = $self->param('q') || q{};
    my ( $bust, $waist, $arm, $status_id, $category ) = split /\//, $q;
    my %q = (
        bust     => $bust      || '',
        waist    => $waist     || '',
        arm      => $arm       || '',
        status   => $status_id || '',
        category => $category  || '',
        %params,
    );

    return join '/', ( $q{bust}, $q{waist}, $q{arm}, $q{status}, $q{category} );
};

helper get_params => sub {
    my ( $self, @keys ) = @_;

    #
    # parameter can have multiple values
    #
    my @src_keys;
    my @dest_keys;
    my @values;
    for my $k (@keys) {
        my @v;
        if ( ref($k) eq 'ARRAY' ) {
            push @src_keys,  $k->[0];
            push @dest_keys, $k->[1];

            @v = $self->param( $k->[0] );
        }
        else {
            push @src_keys,  $k;
            push @dest_keys, $k;

            @v = $self->param($k);
        }

        if ( @v > 1 ) {
            push @values, \@v;
        }
        else {
            push @values, $v[0];
        }
    }

    #
    # make parameter hash using explicit keys
    #
    my %params = zip @dest_keys, @values;

    #
    # remove not defined parameter key and values
    #
    defined $params{$_} ? 1 : delete $params{$_} for keys %params;

    return %params;
};

helper create_order => sub {
    my ( $self, $order_params, $order_clothes_params ) = @_;

    return unless $order_params;
    return unless ref($order_params) eq 'HASH';

    #
    # validate params
    #
    my $v = $self->create_validator;
    $v->field('user_id')->required(1)->regexp(qr/^\d+$/)->callback(sub {
        my $val = shift;

        return 1 if $DB->resultset('User')->find({ id => $val });
        return ( 0, 'user not found using user_id' );
    });
    #
    # FIXME
    #   need more validation but not now
    #   since columns are not perfect yet.
    #
    $v->field(qw/ height weight bust waist hip thigh arm leg knee foot /)->each(sub {
        shift->regexp(qr/^\d{1,3}$/);
    });
    $v->field('clothes_code')->regexp(qr/^[A-Z0-9]{4,5}$/);
    unless ( $self->validate( $v, { %$order_params, %$order_clothes_params } ) ) {
        my @error_str;
        while ( my ( $k, $v ) = each %{ $v->errors } ) {
            push @error_str, "$k:$v";
        }
        $self->error( 400, {
            str  => join(',', @error_str),
            data => $v->errors,
        }), return;
    }

    #
    # adjust params
    #
    if ( $order_clothes_params && $order_clothes_params->{clothes_code} ) {
        $order_clothes_params->{clothes_code} = [ $order_clothes_params->{clothes_code} ]
            unless ref $order_clothes_params->{clothes_code};

        for ( @{ $order_clothes_params->{clothes_code} } ) {
            next unless length == 4;
            $_ = sprintf( '%05s', $_ );
        }
    }

    #
    # TRANSACTION:
    #
    #   - create order
    #   - create order_clothes
    #   - create order_detail
    #
    my ( $order, $error ) = do {
        my $guard = $DB->txn_scope_guard;
        try {
            #
            # create order
            #
            my $order = $DB->resultset('Order')->create( $order_params );
            die "failed to create a new order\n" unless $order;

            if ( $order_clothes_params && $order_clothes_params->{clothes_code} ) {
                for ( @{ $order_clothes_params->{clothes_code} } ) {
                    #
                    # create order_clothes
                    #
                    $order->add_to_order_clothes({ clothes_code => $_ })
                        or die "failed to create a new order_clothes\n";

                    #
                    # create order_detail
                    #
                    my $clothes = $DB->resultset('Clothes')->find({ code => $_ });
                    $order->add_to_order_details({
                        clothes_code => $clothes->code,
                        status_id    => $clothes->status->id,
                        name         => join( q{ - }, $clothes->code, $clothes->category ),
                        price        => $clothes->price,
                    }) or die "failed to create a new order_detail\n";
                }
                #
                # create order_detail for discount
                #
                $order->add_to_order_details({
                    name  => '에누리',
                    price => 0,
                }) or die "failed to create a new order_detail for discount\n";
            }

            $guard->commit;

            return $order;
        }
        catch {
            chomp;
            app->log->error("failed to create a new order & a new order_clothes");
            app->log->error($_);

            return ( undef, $_ );
        };
    };

    #
    # response
    #
    $self->error( 500, {
        str  => $error,
        data => {},
    }), return unless $order;

    return $order;
};

helper get_order => sub {
    my ( $self, $params ) = @_;

    #
    # validate params
    #
    my $v = $self->create_validator;
    $v->field('id')->required(1)->regexp(qr/^\d+$/);
    unless ( $self->validate( $v, $params ) ) {
        my @error_str;
        while ( my ( $k, $v ) = each %{ $v->errors } ) {
            push @error_str, "$k:$v";
        }
        return $self->error( 400, {
            str  => join(',', @error_str),
            data => $v->errors,
        });
    }

    #
    # find order
    #
    my $order = $DB->resultset('Order')->find( $params );
    return $self->error( 404, {
        str  => 'order not found',
        data => {},
    }) unless $order;

    return $order;
};

helper delete_order => sub {
    my ( $self, $params ) = @_;

    #
    # validate params
    #
    my $v = $self->create_validator;
    $v->field('id')->required(1)->regexp(qr/^\d+$/);
    unless ( $self->validate( $v, $params ) ) {
        my @error_str;
        while ( my ( $k, $v ) = each %{ $v->errors } ) {
            push @error_str, "$k:$v";
        }
        return $self->error( 400, {
            str  => join(',', @error_str),
            data => $v->errors,
        });
    }

    #
    # find order
    #
    my $order = $DB->resultset('Order')->find( $params );
    return $self->error( 404, {
        str  => 'order not found',
        data => {},
    }) unless $order;

    #
    # delete order
    #
    my $data = $self->flatten_order($order);
    $order->delete;

    return $data;
};

helper get_order_list => sub {
    my ( $self, $params ) = @_;

    #
    # validate params
    #
    my $v = $self->create_validator;
    $v->field('id')->regexp(qr/^\d+$/);
    unless ( $self->validate( $v, $params ) ) {
        my @error_str;
        while ( my ( $k, $v ) = each %{ $v->errors } ) {
            push @error_str, "$k:$v";
        }
        return $self->error( 400, {
            str  => join(',', @error_str),
            data => $v->errors,
        });
    }

    #
    # adjust params
    #
    $params->{id} = [ $params->{id} ]
        if defined $params->{id} && not ref $params->{id} eq 'ARRAY';

    #
    # find order
    #
    my $rs;
    if ( defined $params->{id} ) {
        $rs
            = $DB->resultset('Order')
            ->search({ id => $params->{id} })
            ;
    }
    else {
        $rs = $DB->resultset('Order');
    }
    return $self->error( 404, {
        str  => 'order list not found',
        data => {},
    }) unless $rs->count;

    return $rs;
};

#
# API section
#
group {
    under '/api' => sub {
        my $self = shift;

        #
        # FIXME - need authorization
        #
        if (1) {
            return 1;
        }

        $self->render( json => { error => 'invalid_access' }, status => 400 );
        return;
    };

    post '/user'           => \&api_create_user;
    get  '/user/:id'       => \&api_get_user;
    put  '/user/:id'       => \&api_update_user;
    del  '/user/:id'       => \&api_delete_user;

    get  '/user-list'      => \&api_get_user_list;

    post '/order'          => \&api_create_order;
    get  '/order/:id'      => \&api_get_order;
    put  '/order/:id'      => \&api_update_order;
    del  '/order/:id'      => \&api_delete_order;

    get  '/order-list'     => \&api_get_order_list;

    post '/clothes'        => \&api_create_clothes;
    get  '/clothes/:code'  => \&api_get_clothes;
    put  '/clothes/:code'  => \&api_update_clothes;
    del  '/clothes/:code'  => \&api_delete_clothes;

    get  '/clothes-list'   => \&api_get_clothes_list;
    put  '/clothes-list'   => \&api_update_clothes_list;

    get  '/search/user'    => \&api_search_user;

    get  '/gui/staff-list' => \&api_gui_staff_list;

    sub api_create_user {
        my $self = shift;

        #
        # fetch params
        #
        my %user_params      = $self->get_params(qw/ name email password /);
        my %user_info_params = $self->get_params(qw/
            phone  address gender birth comment
            height weight  bust   waist hip
            thigh  arm     leg    knee  foot
        /);

        #
        # validate params
        #
        my $v = $self->create_validator;
        $v->field('name')->required(1);
        $v->field('email')->email;
        $v->field('phone')->regexp(qr/^\d+$/);
        $v->field('gender')->in(qw/ male female /);
        $v->field('birth')->regexp(qr/^(19|20)\d{2}$/);
        $v->field(qw/ height weight bust waist hip thigh arm leg knee foot /)->each(sub {
            shift->regexp(qr/^\d{1,3}$/);
        });
        unless ( $self->validate( $v, { %user_params, %user_info_params } ) ) {
            my @error_str;
            while ( my ( $k, $v ) = each %{ $v->errors } ) {
                push @error_str, "$k:$v";
            }
            return $self->error( 400, {
                str  => join(',', @error_str),
                data => $v->errors,
            });
        }

        #
        # create user
        #
        my $user = do {
            my $guard = $DB->txn_scope_guard;

            my $user = $DB->resultset('User')->create(\%user_params);
            return $self->error( 500, {
                str  => 'failed to create a new user',
                data => {},
            }) unless $user;

            my $user_info = $DB->resultset('UserInfo')->create({
                %user_info_params,
                user_id => $user->id,
            });
            return $self->error( 500, {
                str  => 'failed to create a new user info',
                data => {},
            }) unless $user_info;

            $guard->commit;

            $user;
        };

        #
        # response
        #
        my %data = ( $user->user_info->get_columns, $user->get_columns );
        delete @data{qw/ user_id password /};

        $self->res->headers->header(
            'Location' => $self->url_for( '/api/user/' . $user->id ),
        );
        $self->respond_to( json => { status => 201, json => \%data } );
    }

    sub api_get_user {
        my $self = shift;

        #
        # fetch params
        #
        my %params = $self->get_params(qw/ id /);

        #
        # validate params
        #
        my $v = $self->create_validator;
        $v->field('id')->required(1)->regexp(qr/^\d+$/);
        unless ( $self->validate( $v, \%params ) ) {
            my @error_str;
            while ( my ( $k, $v ) = each %{ $v->errors } ) {
                push @error_str, "$k:$v";
            }
            return $self->error( 400, {
                str  => join(',', @error_str),
                data => $v->errors,
            });
        }

        #
        # find user
        #
        my $user = $DB->resultset('User')->find( \%params );
        return $self->error( 404, {
            str  => 'user not found',
            data => {},
        }) unless $user;
        return $self->error( 404, {
            str  => 'user info not found',
            data => {},
        }) unless $user->user_info;

        #
        # response
        #
        my %data = ( $user->user_info->get_columns, $user->get_columns );
        delete @data{qw/ user_id password /};

        $self->respond_to( json => { status => 200, json => \%data } );
    }

    sub api_update_user {
        my $self = shift;

        #
        # fetch params
        #
        my %user_params      = $self->get_params(qw/ id name email password /);
        my %user_info_params = $self->get_params(qw/
            phone  address gender birth comment
            height weight  bust   waist hip
            thigh  arm     leg    knee  foot
        /);

        #
        # validate params
        #
        my $v = $self->create_validator;
        $v->field('id')->required(1)->regexp(qr/^\d+$/);
        $v->field('email')->email;
        $v->field('phone')->regexp(qr/^\d+$/);
        $v->field('gender')->in(qw/ male female /);
        $v->field('birth')->regexp(qr/^(19|20)\d{2}$/);
        $v->field(qw/ height weight bust waist hip thigh arm leg knee foot /)->each(sub {
            shift->regexp(qr/^\d{1,3}$/);
        });
        unless ( $self->validate( $v, { %user_params, %user_info_params } ) ) {
            my @error_str;
            while ( my ( $k, $v ) = each %{ $v->errors } ) {
                push @error_str, "$k:$v";
            }
            return $self->error( 400, {
                str  => join(',', @error_str),
                data => $v->errors,
            });
        }

        #
        # find user
        #
        my $user = $DB->resultset('User')->find({ id => $user_params{id} });
        return $self->error( 404, {
            str  => 'user not found',
            data => {},
        }) unless $user;
        return $self->error( 404, {
            str  => 'user info not found',
            data => {},
        }) unless $user->user_info;

        #
        # update user
        #
        {
            my $guard = $DB->txn_scope_guard;

            my %_user_params = %user_params;
            delete $_user_params{id};
            $user->update( \%_user_params )
                or return $self->error( 500, {
                    str  => 'failed to update a user',
                    data => {},
                });

            $user->user_info->update({
                %user_info_params,
                user_id => $user->id,
            }) or return $self->error( 500, {
                str  => 'failed to update a user info',
                data => {},
            });

            $guard->commit;
        }

        #
        # response
        #
        my %data = ( $user->user_info->get_columns, $user->get_columns );
        delete @data{qw/ user_id password /};

        $self->respond_to( json => { status => 200, json => \%data } );
    }

    sub api_delete_user {
        my $self = shift;

        #
        # fetch params
        #
        my %params = $self->get_params(qw/ id /);

        #
        # validate params
        #
        my $v = $self->create_validator;
        $v->field('id')->required(1)->regexp(qr/^\d+$/);
        unless ( $self->validate( $v, \%params ) ) {
            my @error_str;
            while ( my ( $k, $v ) = each %{ $v->errors } ) {
                push @error_str, "$k:$v";
            }
            return $self->error( 400, {
                str  => join(',', @error_str),
                data => $v->errors,
            });
        }

        #
        # find user
        #
        my $user = $DB->resultset('User')->find( \%params );
        return $self->error( 404, {
            str  => 'user not found',
            data => {},
        }) unless $user;

        #
        # delete & response
        #
        my %data = ( $user->user_info->get_columns, $user->get_columns );
        delete @data{qw/ user_id password /};
        $user->delete;

        $self->respond_to( json => { status => 200, json => \%data } );
    }

    sub api_get_user_list {
        my $self = shift;
    }

    sub api_create_order {
        my $self = shift;

        #
        # fetch params
        #
        my %order_params = $self->get_params(qw/
            user_id     status_id     rental_date    target_date
            return_date return_method price_pay_with price
            discount    late_fee      l_discount     late_fee_pay_with
            staff_name  comment       purpose        height
            weight      bust          waist          hip
            thigh       arm           leg            knee
            foot
        /);
        my %order_clothes_params = $self->get_params(qw/ clothes_code /);

        my $order = $self->create_order( \%order_params, \%order_clothes_params );
        return unless $order;

        #
        # response
        #
        my $data = $self->flatten_order($order);

        $self->res->headers->header(
            'Location' => $self->url_for( '/api/order/' . $order->id ),
        );
        $self->respond_to( json => { status => 201, json => $data } );
    }

    sub api_get_order {
        my $self = shift;

        #
        # fetch params
        #
        my %params = $self->get_params(qw/ id /);

        my $order = $self->get_order( \%params );
        return unless $order;

        #
        # response
        #
        my $data = $self->flatten_order($order);

        $self->respond_to( json => { status => 200, json => $data } );
    }

    sub api_update_order {
        my $self = shift;

        #
        # fetch params
        #
        my %params = $self->get_params(qw/
            id
            user_id     status_id     rental_date    target_date
            return_date return_method price_pay_with price
            discount    late_fee      l_discount     late_fee_pay_with
            staff_name  comment       purpose        height
            weight      bust          waist          hip
            thigh       arm           leg            knee
            foot
        /);

        #
        # validate params
        #
        my $v = $self->create_validator;
        $v->field('id')->required(1)->regexp(qr/^\d+$/);
        $v->field('user_id')->regexp(qr/^\d+$/)->callback(sub {
            my $val = shift;

            return 1 if $DB->resultset('User')->find({ id => $val });
            return ( 0, 'user not found using user_id' );
        });
        #
        # FIXME
        #   need more validation but not now
        #   since columns are not perfect yet.
        #
        $v->field(qw/ height weight bust waist hip thigh arm leg knee foot /)->each(sub {
            shift->regexp(qr/^\d{1,3}$/);
        });
        unless ( $self->validate( $v, \%params ) ) {
            my @error_str;
            while ( my ( $k, $v ) = each %{ $v->errors } ) {
                push @error_str, "$k:$v";
            }
            return $self->error( 400, {
                str  => join(',', @error_str),
                data => $v->errors,
            });
        }

        #
        # find order
        #
        my $order = $DB->resultset('Order')->find({ id => $params{id} });
        return $self->error( 404, {
            str  => 'order not found',
            data => {},
        }) unless $order;

        #
        # update order
        #
        {
            my %_params = %params;
            delete $_params{id};
            $order->update( \%_params )
                or return $self->error( 500, {
                    str  => 'failed to update a order',
                    data => {},
                });
        }

        #
        # response
        #
        my $data = $self->flatten_order($order);

        $self->respond_to( json => { status => 200, json => $data } );
    }

    sub api_delete_order {
        my $self = shift;

        #
        # fetch params
        #
        my %params = $self->get_params(qw/ id /);

        my $data = $self->delete_order( \%params );
        return unless $data;

        #
        # response
        #
        $self->respond_to( json => { status => 200, json => $data } );
    }

    sub api_get_order_list {
        my $self = shift;

        #
        # fetch params
        #
        my %params = $self->get_params(qw/ id /);

        my $rs = $self->get_order_list( \%params );
        return unless $rs;

        #
        # response
        #
        my @data;
        for my $order ( $rs->all ) {
            push @data, $self->flatten_order($order);
        }

        $self->respond_to( json => { status => 200, json => \@data } );
    }

    sub api_create_clothes {
        my $self = shift;

        #
        # fetch params
        #
        my %params = $self->get_params(qw/
            arm   bust            category code
            color compatible_code gender   group_id
            hip   length          price    status_id
            thigh user_id         waist
        /);

        #
        # validate params
        #
        my $v = $self->create_validator;
        $v->field('code')->required(1)->regexp(qr/^[A-Z0-9]{4,5}$/);
        $v->field('category')->required(1)->in(@CATEGORIES);
        $v->field('gender')->in(qw/ male female /);
        $v->field('price')->regexp(qr/^\d*$/);
        $v->field(qw/ bust waist hip thigh arm length /)->each(sub {
            shift->regexp(qr/^\d{1,3}$/);
        });
        $v->field('user_id')->regexp(qr/^\d*$/)->callback(sub {
            my $val = shift;

            return 1 if $DB->resultset('User')->find({ id => $val });
            return ( 0, 'user not found using user_id' );
        });

        $v->field('status_id')->regexp(qr/^\d*$/)->callback(sub {
            my $val = shift;

            return 1 if $DB->resultset('Status')->find({ id => $val });
            return ( 0, 'status not found using status_id' );
        });

        $v->field('group_id')->regexp(qr/^\d*$/)->callback(sub {
            my $val = shift;

            return 1 if $DB->resultset('Group')->find({ id => $val });
            return ( 0, 'status not found using group_id' );
        });
        unless ( $self->validate( $v, \%params ) ) {
            my @error_str;
            while ( my ( $k, $v ) = each %{ $v->errors } ) {
                push @error_str, "$k:$v";
            }
            return $self->error( 400, {
                str  => join(',', @error_str),
                data => $v->errors,
            });
        }

        #
        # adjust params
        #
        $params{code} = sprintf( '%05s', $params{code} ) if length( $params{code} ) == 4;

        #
        # create clothes
        #
        my $clothes = $DB->resultset('Clothes')->create( \%params );
        return $self->error( 500, {
            str  => 'failed to create a new clothes',
            data => {},
        }) unless $clothes;

        #
        # response
        #
        my %data = ( $clothes->get_columns );

        $self->res->headers->header(
            'Location' => $self->url_for( '/api/clothes/' . $clothes->code ),
        );
        $self->respond_to( json => { status => 201, json => \%data } );
    }

    sub api_get_clothes {
        my $self = shift;

        #
        # fetch params
        #
        my %params = $self->get_params(qw/ code /);

        #
        # validate params
        #
        my $v = $self->create_validator;
        $v->field('code')->required(1)->regexp(qr/^[A-Z0-9]{4,5}$/);
        unless ( $self->validate( $v, \%params ) ) {
            my @error_str;
            while ( my ( $k, $v ) = each %{ $v->errors } ) {
                push @error_str, "$k:$v";
            }
            return $self->error( 400, {
                str  => join(',', @error_str),
                data => $v->errors,
            });
        }

        #
        # adjust params
        #
        $params{code} = sprintf( '%05s', $params{code} ) if length( $params{code} ) == 4;

        #
        # find clothes
        #
        my $clothes = $DB->resultset('Clothes')->find( \%params );
        return $self->error( 404, {
            str  => 'clothes not found',
            data => {},
        }) unless $clothes;

        #
        # additional information for clothes
        #
        my %extra_data;
        # '대여중'인 항목만 주문서 정보를 포함합니다.
        my $order = $clothes->orders->find({ status_id => 2 });
        $extra_data{order} = $self->flatten_order($order) if $order;

        #
        # response
        #
        my %data = ( $clothes->get_columns, %extra_data );
        $data{status} = $clothes->status->name;

        $self->respond_to( json => { status => 200, json => \%data } );
    }

    sub api_update_clothes {
        my $self = shift;

        #
        # fetch params
        #
        my %params = $self->get_params(qw/
            arm   bust            category code
            color compatible_code gender   group_id
            hip   length          price    status_id
            thigh user_id         waist
        /);

        #
        # validate params
        #
        my $v = $self->create_validator;
        $v->field('code')->required(1)->regexp(qr/^[A-Z0-9]{4,5}$/);
        $v->field('category')->in(@CATEGORIES);
        $v->field('gender')->in(qw/ male female unisex /);
        $v->field('price')->regexp(qr/^\d*$/);
        $v->field(qw/ bust waist hip thigh arm length /)->each(sub {
            shift->regexp(qr/^\d{1,3}$/);
        });
        $v->field('user_id')->regexp(qr/^\d*$/)->callback(sub {
            my $val = shift;

            return 1 if $DB->resultset('User')->find({ id => $val });
            return ( 0, 'user not found using user_id' );
        });

        $v->field('status_id')->regexp(qr/^\d*$/)->callback(sub {
            my $val = shift;

            return 1 if $DB->resultset('Status')->find({ id => $val });
            return ( 0, 'status not found using status_id' );
        });

        $v->field('group_id')->regexp(qr/^\d*$/)->callback(sub {
            my $val = shift;

            return 1 if $DB->resultset('Group')->find({ id => $val });
            return ( 0, 'status not found using group_id' );
        });
        unless ( $self->validate( $v, \%params ) ) {
            my @error_str;
            while ( my ( $k, $v ) = each %{ $v->errors } ) {
                push @error_str, "$k:$v";
            }
            return $self->error( 400, {
                str  => join(',', @error_str),
                data => $v->errors,
            });
        }

        #
        # adjust params
        #
        $params{code} = sprintf( '%05s', $params{code} ) if length( $params{code} ) == 4;

        #
        # find clothes
        #
        my $clothes = $DB->resultset('Clothes')->find( \%params );
        return $self->error( 404, {
            str  => 'clothes not found',
            data => {},
        }) unless $clothes;

        #
        # update clothes
        #
        {
            my %_params = %params;
            delete $_params{code};
            $clothes->update( \%params )
                or return $self->error( 500, {
                    str  => 'failed to update a clothes',
                    data => {},
                });
        }

        #
        # response
        #
        my %data = ( $clothes->get_columns );

        $self->respond_to( json => { status => 200, json => \%data } );
    }

    sub api_delete_clothes {
        my $self = shift;

        #
        # fetch params
        #
        my %params = $self->get_params(qw/ code /);

        #
        # validate params
        #
        my $v = $self->create_validator;
        $v->field('code')->required(1)->regexp(qr/^[A-Z0-9]{4,5}$/);
        unless ( $self->validate( $v, \%params ) ) {
            my @error_str;
            while ( my ( $k, $v ) = each %{ $v->errors } ) {
                push @error_str, "$k:$v";
            }
            return $self->error( 400, {
                str  => join(',', @error_str),
                data => $v->errors,
            });
        }

        #
        # adjust params
        #
        $params{code} = sprintf( '%05s', $params{code} ) if length( $params{code} ) == 4;

        #
        # find clothes
        #
        my $clothes = $DB->resultset('Clothes')->find( \%params );
        return $self->error( 404, {
            str  => 'clothes not found',
            data => {},
        }) unless $clothes;

        #
        # delete & response
        #
        my %data = ( $clothes->get_columns );
        $clothes->delete;

        $self->respond_to( json => { status => 200, json => \%data } );
    }

    sub api_get_clothes_list {
        my $self = shift;

        #
        # fetch params
        #
        my %params = $self->get_params(qw/ code /);

        #
        # validate params
        #
        my $v = $self->create_validator;
        $v->field('code')->required(1)->regexp(qr/^[A-Z0-9]{4,5}$/);
        unless ( $self->validate( $v, \%params ) ) {
            my @error_str;
            while ( my ( $k, $v ) = each %{ $v->errors } ) {
                push @error_str, "$k:$v";
            }
            return $self->error( 400, {
                str  => join(',', @error_str),
                data => $v->errors,
            });
        }

        #
        # adjust params
        #
        $params{code} = [ $params{code} ] unless ref $params{code} eq 'ARRAY';
        for my $code ( @{ $params{code} } ) {
            next unless length($code) == 4;
            $code = sprintf( '%05s', $code );
        }

        #
        # find clothes
        #
        my @clothes_list
                = $DB->resultset('Clothes')
                ->search( { code => $params{code} } )
                ->all
                ;
        return $self->error( 404, {
            str  => 'clothes list not found',
            data => {},
        }) unless @clothes_list;

        #
        # additional information for clothes list
        #
        my @data;
        for my $clothes (@clothes_list) {
            # '대여중'인 항목만 주문서 정보를 포함합니다.
            my %extra_data;
            my $order = $clothes->orders->find({ status_id => 2 });
            $extra_data{order} = $self->flatten_order($order) if $order;

            push @data, {
                $clothes->get_columns,
                %extra_data,
                status => $clothes->status->name,
            };
        }

        #
        # response
        #
        $self->respond_to( json => { status => 200, json => \@data } );
    }

    sub api_update_clothes_list {
        my $self = shift;

        #
        # fetch params
        #
        my %params = $self->get_params(qw/
            arm   bust            category code
            color compatible_code gender   group_id
            hip   length          price    status_id
            thigh user_id         waist
        /);

        #
        # validate params
        #
        my $v = $self->create_validator;
        $v->field('code')->required(1)->regexp(qr/^[A-Z0-9]{4,5}$/);
        $v->field('category')->in(@CATEGORIES);
        $v->field('gender')->in(qw/ male female unisex /);
        $v->field('price')->regexp(qr/^\d*$/);
        $v->field(qw/ bust waist hip thigh arm length /)->each(sub {
            shift->regexp(qr/^\d{1,3}$/);
        });
        $v->field('user_id')->regexp(qr/^\d*$/)->callback(sub {
            my $val = shift;

            return 1 if $DB->resultset('User')->find({ id => $val });
            return ( 0, 'user not found using user_id' );
        });

        $v->field('status_id')->regexp(qr/^\d*$/)->callback(sub {
            my $val = shift;

            return 1 if $DB->resultset('Status')->find({ id => $val });
            return ( 0, 'status not found using status_id' );
        });

        $v->field('group_id')->regexp(qr/^\d*$/)->callback(sub {
            my $val = shift;

            return 1 if $DB->resultset('Group')->find({ id => $val });
            return ( 0, 'status not found using group_id' );
        });
        unless ( $self->validate( $v, \%params ) ) {
            my @error_str;
            while ( my ( $k, $v ) = each %{ $v->errors } ) {
                push @error_str, "$k:$v";
            }
            return $self->error( 400, {
                str  => join(',', @error_str),
                data => $v->errors,
            });
        }

        #
        # adjust params
        #
        $params{code} = [ $params{code} ] unless ref $params{code} eq 'ARRAY';
        for my $code ( @{ $params{code} } ) {
            next unless length($code) == 4;
            $code = sprintf( '%05s', $code );
        }

        #
        # update clothes list
        #
        {
            my %_params = %params;
            my $code = delete $_params{code};
            $DB->resultset('Clothes')
                ->search( { code => $params{code} } )
                ->update( \%_params )
        }

        #
        # response
        #
        my %data = ();

        $self->respond_to( json => { status => 200, json => \%data } );
    }

    #
    # FIXME
    #   parameter is wired.
    #   but it seemed enough for opencloset now
    #
    sub api_search_user {
        my $self = shift;

        #
        # fetch params
        #
        my %params = $self->get_params(qw/ q /);

        #
        # validate params
        #
        my $v = $self->create_validator;
        $v->field('q')->required(1);
        unless ( $self->validate( $v, \%params ) ) {
            my @error_str;
            while ( my ( $k, $v ) = each %{ $v->errors } ) {
                push @error_str, "$k:$v";
            }
            return $self->error( 400, {
                str  => join(',', @error_str),
                data => $v->errors,
            });
        }

        #
        # find user
        #
        my @users = $DB->resultset('User')->search(
            {
                -or => [
                    'me.name'         => $params{q},
                    'me.email'        => $params{q},
                    'user_info.phone' => $params{q},
                ],
            },
            { join => 'user_info' },
        );
        return $self->error( 404, {
            str  => 'user not found',
            data => {},
        }) unless @users;

        #
        # response
        #
        my @data;
        for my $user (@users) {
            my %inner = ( $user->user_info->get_columns, $user->get_columns );
            delete @inner{qw/ user_id password /};

            push @data, \%inner;
        }

        $self->respond_to( json => { status => 200, json => \@data } );
    }

    sub api_gui_staff_list {
        my $self = shift;

        #
        # find staff
        #
        my @users = $DB->resultset('User')->search(
            { 'user_info.staff' => 1 },
            { join => 'user_info'    },
        );
        return $self->error( 404, {
            str  => 'staff not found',
            data => {},
        }) unless @users;

        #
        # response
        #
        my @data;
        push @data, { value => $_->id, text => $_->name } for @users;

        $self->respond_to( json => { status => 200, json => \@data } );
    }

}; # end of API section

get '/login';

get '/'             => 'home';
get '/new-borrower' => 'new-borrower';
get '/new-clothes'  => 'new-clothes';

get '/user/:id' => sub {
    my $self = shift;

    my $user = $DB->resultset('User')->find({ id => $self->param('id') });
    return $self->error(404, 'not found user') unless $user;

    my @orders = $DB->resultset('Order')->search(
        { guest_id => $self->param('id') },
        { order_by => { -desc => 'rental_date' } },
    );

    $self->stash(
        user   => $user,
        orders => \@orders,
    );

    my %data = ( $user->user_info->get_columns, $user->get_columns );
    delete @data{qw/ user_id password /};

    $self->respond_to(
        json => { json     => \%data      },
        html => { template => 'user/id' },
    );
} => 'user/id';

post '/clothes' => sub {
    my $self = shift;

    my $validator  = $self->cloth_validator;
    my @cloth_list = $self->param('clothes-list');

    ###
    ### validate
    ###
    for my $clothes (@cloth_list) {
        my (
            $donor_id, $category, $color, $bust,
            $waist,    $hip,      $arm,   $thigh,
            $length,   $gender,   $compatible_code,
        ) = split /-/, $clothes;

        my $is_valid = $self->validate($validator, {
            category        => $category,
            color           => $color,
            bust            => $bust,
            waist           => $waist,
            hip             => $hip,
            arm             => $arm,
            thigh           => $thigh,
            length          => $length,
            gender          => $gender || 1,    # TODO: should get from params
            compatible_code => $compatible_code,
        });

        unless ($is_valid) {
            my @error_str;
            while ( my ($k, $v) = each %{ $validator->errors } ) {
                push @error_str, "$k:$v";
            }
            return $self->error( 400, { str => join(',', @error_str), data => $validator->errors } );
        }
    }

    ###
    ### create
    ###
    my @clothes_list;
    for my $clothes (@cloth_list) {
        my (
            $donor_id, $category, $color, $bust,
            $waist,    $hip,      $arm,   $thigh,
            $length,   $gender,   $compatible_code,
        ) = split /-/, $clothes;

        my %cloth_info = (
            color           => $color,
            bust            => $bust,
            waist           => $waist,
            hip             => $hip,
            arm             => $arm,
            thigh           => $thigh,
            length          => $length,
            gender          => $gender || 1,    # TODO: should get from params
            compatible_code => $compatible_code,
        );

        #
        # TRANSACTION
        #
        my $guard = $DB->txn_scope_guard;
        if ( $category =~ m/jacket/ && $category =~ m/pants/ ) {
            my $c1 = $self->create_cloth( %cloth_info, category => 'jacket' );
            my $c2 = $self->create_cloth( %cloth_info, category => 'pants'  );
            return $self->error(500, '!!! failed to create a new clothes') unless ($c1 && $c2);

            if ($donor_id) {
                $c1->create_related('donor_cloths', { donor_id => $donor_id });
                $c2->create_related('donor_cloths', { donor_id => $donor_id });
            }

            $c1->bottom_id($c2->id);
            $c2->top_id($c1->id);
            $c1->update;
            $c2->update;

            push @clothes_list, $c1, $c2;
        }
        elsif ( $category =~ m/jacket/ && $category =~ m/skirt/ ) {
            my $c1 = $self->create_cloth( %cloth_info, category => 'jacket' );
            my $c2 = $self->create_cloth( %cloth_info, category => 'skirt'  );
            return $self->error(500, '!!! failed to create a new clothes') unless ($c1 && $c2);

            if ($donor_id) {
                $c1->create_related('donor_cloths', { donor_id => $donor_id });
                $c2->create_related('donor_cloths', { donor_id => $donor_id });
            }

            $c1->bottom_id($c2->id);
            $c2->top_id($c1->id);
            $c1->update;
            $c2->update;

            push @clothes_list, $c1, $c2;
        } else {
            my $c = $self->create_cloth(%cloth_info);
            return $self->error(500, '--- failed to create a new clothes') unless $c;

            if ($donor_id) {
                $c->create_related('donor_cloths', { donor_id => $donor_id });
            }
            push @clothes_list, $c;
        }
        $guard->commit;
    }

    ###
    ### response
    ###
    ## 여러개가 될 수 있으므로 Location 헤더는 생략
    ## $self->res->headers->header('Location' => $self->url_for('/clothes/' . $clothes->code));
    $self->respond_to(
        json => { json => [map { $self->cloth2hr($_) } @clothes_list], status => 201 },
        html => sub {
            $self->redirect_to('/clothes');
        }
    );
};

put '/clothes' => sub {
    my $self = shift;

    my $clothes_list = $self->param('clothes_list');
    return $self->error(400, 'Nothing to change') unless $clothes_list;

    my $status = $DB->resultset('Status')->find({ name => $self->param('status') });
    return $self->error(400, 'Invalid status') unless $status;

    my $rs    = $DB->resultset('Clothes')->search({ 'me.id' => { -in => [split(/,/, $clothes_list)] } });
    my $guard = $DB->txn_scope_guard;
    my @rows;
    # BEGIN TRANSACTION ~
    while (my $clothes = $rs->next) {
        $clothes->status_id($status->id);
        $clothes->update;
        push @rows, { $clothes->get_columns };
    }
    # ~ COMMIT
    $guard->commit;

    $self->respond_to(
        json => { json => [@rows] },
        html => { template => 'clothes' }    # TODO: `clothes.html.haml`
    );
};

get '/clothes/:code' => sub {
    my $self = shift;
    my $code = $self->param('code');
    my $clothes = $DB->resultset('Clothes')->find({ code => $code });
    return $self->error(404, "Not found `$code`") unless $clothes;

    my $co_rs = $clothes->cloth_orders->search({
        'order.status_id' => { -in => [$Opencloset::Constant::STATUS_RENT, $clothes->status_id] },
    }, {
        join => 'order'
    })->next;

    unless ($co_rs) {
        $self->respond_to(
            json => { json => $self->cloth2hr($clothes) },
            html => { template => 'clothes/code', clothes => $clothes }    # also, CODEREF is OK
        );
        return;
    }

    my @with;
    my $order = $co_rs->order;
    for my $_cloth ($order->cloths) {
        next if $_cloth->id == $clothes->id;
        push @with, $self->cloth2hr($_cloth);
    }

    my %columns = (
        %{ $self->cloth2hr($clothes) },
        %{ $self->flatten_order($order) },
    );

    $self->respond_to(
        json => { json => { %columns } },
        html => { template => 'clothes/code', clothes => $clothes }    # also, CODEREF is OK
    );
};

any [qw/put patch/] => '/clothes/:code' => sub {
    my $self = shift;
    my $code = $self->param('code');
    my $clothes = $DB->resultset('Clothes')->find({ code => $code });
    return $self->error(404, "Not found `$code`") unless $clothes;

    map {
        $clothes->$_($self->param($_)) if defined $self->param($_);
    } qw/bust waist arm length/;

    $clothes->update;
    $self->respond_to(
        json => { json => $self->cloth2hr($clothes) },
        html => { template => 'clothes/code', clothes => $clothes }    # also, CODEREF is OK
    );
};

get '/search' => sub {
    my $self = shift;

    my $q                = $self->param('q')                || q{};
    my $gid              = $self->param('gid')              || q{};
    my $color            = $self->param('color')            || q{};
    my $entries_per_page = $self->param('entries_per_page') || app->config->{entries_per_page};

    my $user = $gid ? $DB->resultset('User')->find({ id => $gid }) : undef;
    my ( $bust, $waist, $arm, $status_id, $category ) = split /\//, $q;
    $status_id ||= 0;
    $category  ||= 'jacket';

    my %cond;
    $cond{'me.category'}  = $category;
    $cond{'me.bust'}      = { '>=' => $bust  } if $bust;
    $cond{'bottom.waist'} = { '>=' => $waist } if $waist;
    $cond{'me.arm'}       = { '>=' => $arm   } if $arm;
    $cond{'me.status_id'} = $status_id         if $status_id;
    $cond{'me.color'}     = $color             if $color;

    ### row, current_page, count
    my $clothes_list = $DB->resultset('Clothes')->search(
        \%cond,
        {
            page     => $self->param('p') || 1,
            rows     => $entries_per_page,
            order_by => [qw/bust bottom.waist arm/],
            join     => 'bottom',
        }
    );

    my $pageset = Data::Pageset->new({
        total_entries    => $clothes_list->pager->total_entries,
        entries_per_page => $entries_per_page,
        current_page     => $self->param('p') || 1,
        mode             => 'fixed'
    });

    $self->stash(
        q            => $q,
        gid          => $gid,
        user         => $user,
        clothes_list => $clothes_list,
        pageset      => $pageset,
        status_id    => $status_id,
        category     => $category,
        color        => $color,
    );
};

get '/rental' => sub {
    my $self = shift;

    my $q = $self->param('q');

    ### DBIx::Class::Storage::DBI::_gen_sql_bind(): DateTime objects passed to search() are not
    ### supported properly (InflateColumn::DateTime formats and settings are not respected.)
    ### See "Formatting DateTime objects in queries" in DBIx::Class::Manual::Cookbook.
    ### To disable this warning for good set $ENV{DBIC_DT_SEARCH_OK} to true
    ###
    ### DateTime object 를 search 에 바로 사용하지 말고 parser 를 이용하라능 - @aanoaa
    my $today     = DateTime->today( time_zone => 'Asia/Seoul' );
    my $dt_parser = $DB->storage->datetime_parser;

    my @users = $DB->resultset('User')->search(
        {
            -or => [
                {
                    -or => [
                        'me.id'           => $q,
                        'me.name'         => $q,
                        'me.email'        => $q,
                        'user_info.phone' => $q,
                    ],
                },
                { update_date => { '>=' => $dt_parser->format_datetime($today) } },
            ],
        },
        {
            order_by => { -desc => 'update_date' },
            join     => 'user_info',
        },
    );

    $self->stash( users => \@users );
} => 'rental';

get '/order' => sub {
    my $self = shift;

    #
    # fetch params
    #
    my %params = $self->get_params(qw/ id /);

    my $rs = $self->get_order_list( \%params );

    #
    # response
    #
    $self->stash( order_list => $rs );
    $self->respond_to( html => { status => 200 } );
} => 'order';

post '/order' => sub {
    my $self = shift;

    #
    # fetch params
    #
    my %order_params         = $self->get_params(qw/ user_id /);
    my %order_clothes_params = $self->get_params(qw/ clothes_code /);

    my $order = $self->create_order( \%order_params, \%order_clothes_params );
    return unless $order;

    #
    # response
    #
    $self->redirect_to( '/order/' . $order->id );
};

get '/order/:id' => sub {
    my $self = shift;

    #
    # fetch params
    #
    my %params = $self->get_params(qw/ id /);

    my $order = $self->get_order( \%params );
    return unless $order;

    #
    # response
    #
    $self->stash( order => $order );
} => 'order-id';

get '/order/:id/delete' => sub {
    my $self = shift;

    #
    # fetch params
    #
    my %params = $self->get_params(qw/ id /);
    $self->delete_order( \%params );

    #
    # response
    #
    $self->redirect_to('/order');
};

post '/order/:id/update' => sub {
    my $self = shift;

    #
    # fetch params
    #
    my %search_params = $self->get_params(qw/ id /);
    my %update_params = $self->get_params(qw/ name value pk /);

    my $order = $self->get_order( \%search_params );
    return unless $order;

    #
    # update column
    #
    if ( $update_params{name} =~ s/^detail-// ) {
        my $detail = $order->order_details({ id => $update_params{pk} });
        if ($detail) {
            $detail->update({ $update_params{name} => $update_params{value} });
        }
    }
    else {
        if ( $update_params{name} eq 'status_id' ) {
            my $guard = $DB->txn_scope_guard;
            try {
                #
                # update order.status_id
                #
                $order->update({ $update_params{name} => $update_params{value} });

                #
                # update clothes.status_id
                #
                for my $clothes ( $order->clothes ) {
                    $clothes->update({ $update_params{name} => $update_params{value} });
                }

                #
                # update order_detail.status_id
                #
                for my $order_detail ( $order->order_details ) {
                    next unless $order_detail->clothes;
                    $order_detail->update({ $update_params{name} => $update_params{value} });
                }

                $guard->commit;
            }
            catch {
                app->log->error("failed to update status of the order & clothes");
                app->log->error($_);
            };
        }
        else {
            $order->update({ $update_params{name} => $update_params{value} });
        }
    }

    #
    # response
    #
    $self->respond_to({ data => q{} });
};

post '/donors' => sub {
    my $self   = shift;

    my $user = $DB->resultset('User')->find({ id => $self->param('user_id') });
    return $self->error(404, 'not found user') unless $user;

    $user->user_info->update({
        map {
            defined $self->param($_) ? ( $_ => $self->param($_) ) : ()
        } qw()
    });

    my %data = ( $user->user_info->get_columns, $user->get_columns );
    delete @data{qw/ user_id password /};

    $self->res->headers->header('Location' => $self->url_for('/donors/' . $user->id));
    $self->respond_to(
        json => { json => \%data, status => 201                  },
        html => sub { $self->redirect_to('/donors/' . $user->id) },
    );
};

any [qw/put patch/] => '/donors/:id' => sub {
    my $self  = shift;

    my $user = $DB->resultset('User')->find({ id => $self->param('id') });
    return $self->error(404, 'not found user') unless $user;

    $user->user_info->update({
        map {
            defined $self->param($_) ? ( $_ => $self->param($_) ) : ()
        } qw()
    });

    my %data = ( $user->user_info->get_columns, $user->get_columns );
    delete @data{qw/ user_id password /};

    $self->respond_to( json => { json => \%data } );
};

post '/sms' => sub {
    my $self = shift;

    my $validator = $self->create_validator;
    $validator->field('to')->required(1)->regexp(qr/^0\d{9,10}$/);
    return $self->error(400, 'Bad receipent') unless $self->validate($validator);

    my $to     = $self->param('to');
    my $from   = app->config->{sms}{sender};
    my $text   = app->config->{sms}{text};
    my $sender = SMS::Send->new(
        'KR::CoolSMS',
        _ssl      => 1,
        _user     => app->config->{sms}{username},
        _password => app->config->{sms}{password},
        _type     => 'sms',
        _from     => $from,
    );

    my $sent = $sender->send_sms(
        text => $text,
        to   => $to,
    );

    return $self->error(500, $sent->{reason}) unless $sent;

    my $sms = $DB->resultset('ShortMessage')->create({
        from => $from,
        to   => $to,
        msg  => $text,
    });

    $self->res->headers->header('Location' => $self->url_for('/sms/' . $sms->id));
    $self->respond_to(
        json => { json => { $sms->get_columns }, status => 201 },
        html => sub {
            $self->redirect_to('/sms/' . $sms->id);    # TODO: GET /sms/:id
        }
    );
};

app->secrets( app->defaults->{secrets} );
app->start;

__DATA__

@@ user/id.html.haml
- layout 'default';
- title $user->name . '님';

%ul
  %li
    %i.icon-user
    %a{:href => "#{url_for('/guests/' . $user->id)}"} #{$user->name}
    %span (#{$user->user_info->birth})
  %li
    %i.icon-map-marker
    = $user->user_info->address
  %li
    %i.icon-envelope
    %a{:href => "mailto:#{$user->email}"}= $user->email
  %li= $user->user_info->phone
  %li
    %span #{$user->user_info->height} cm,
    %span #{$user->user_info->weight} kg

%div= include 'guests/breadcrumb', user => $user, status_id => 1;
%h3 주문내역
%ul
  - for my $order (@$orders) {
    - if ($order->status) {
      %li
        %a{:href => "#{url_for('/orders/' . $order->id)}"}
          - if ($order->status->name eq '대여중') {
            - if (calc_overdue($order->target_date, DateTime->now())) {
              %span.label.label-important 연체중
            - } else {
              %span.label.label-important= $order->status->name
            - }
            %span.highlight{:title => '대여일'}= $order->rental_date->ymd
            ~
            %span{:title => '반납예정일'}= $order->target_date->ymd
          - } else {
            %span.label= $order->status->name
            %span.highlight{:title => '대여일'}= $order->rental_date->ymd
            ~
            %span.highlight{:title => '반납일'}= $order->return_date->ymd
          - }
    - }
  - }


@@ guests/breadcrumb.html.haml
%p
  %a{:href => '/guests/#{$user->id}'}= $user->name
  님
  - if ( $user->update_date ) {
    %strong= $user->update_date->ymd
    %span 방문
  - }
  %div
    %span.label.label-info.search-label
      %a{:href => "#{url_with('/search')->query([q => $user->bust])}///#{$status_id}"}= $user->bust
    %span.label.label-info.search-label
      %a{:href => "#{url_with('/search')->query([q => '/' . $user->waist . '//' . $status_id])}"}= $user->waist
    %span.label.label-info.search-label
      %a{:href => "#{url_with('/search')->query([q => '//' . $user->arm])}/#{$status_id}"}= $user->arm
    %span.label= $user->length
    %span.label= $user->height
    %span.label= $user->weight


@@ donors/breadcrumb/radio.html.haml
%input{:type => 'radio', :name => 'donor_id', :value => '#{$donor->id}'}
%a{:href => '/donors/#{$donor->id}'}= $donor->user->name
님
%div
  - if ($donor->email) {
    %i.icon-envelope
    %a{:href => "mailto:#{$donor->email}"}= $donor->email
  - }
  - if ($donor->user_info->phone) {
    %div.muted= $donor->phone
  - }


@@ search.html.haml
- my $id   = 'search';
- my $meta = $sidebar->{meta};
- layout 'default',
-   active_id   => $id,
-   breadcrumbs => [
-     { text => $meta->{$id}{text} },
-   ];
- title $meta->{$id}{text};

.row
  .col-xs-12
    %p
      %span.badge.badge-inverse 매우작음
      %span.badge 작음
      %span.badge.badge-success 맞음
      %span.badge.badge-warning 큼
      %span.badge.badge-important 매우큼
    %p.muted
      %span.text-info 상태
      %span{:class => "#{$status_id == 1 ? 'highlight' : ''}"}
        %a{:href => "#{url_with->query(q => _q(status => 1))}"} 1: 대여가능
      %span{:class => "#{$status_id == 2 ? 'highlight' : ''}"}
        %a{:href => "#{url_with->query(q => _q(status => 2))}"} 2: 대여중
      %span{:class => "#{$status_id == 3 ? 'highlight' : ''}"}
        %a{:href => "#{url_with->query(q => _q(status => 3))}"} 3: 대여불가
      %span{:class => "#{$status_id == 4 ? 'highlight' : ''}"}
        %a{:href => "#{url_with->query(q => _q(status => 4))}"} 4: 예약
      %span{:class => "#{$status_id == 5 ? 'highlight' : ''}"}
        %a{:href => "#{url_with->query(q => _q(status => 5))}"} 5: 세탁
      %span{:class => "#{$status_id == 6 ? 'highlight' : ''}"}
        %a{:href => "#{url_with->query(q => _q(status => 6))}"} 6: 수선
      %span{:class => "#{$status_id == 7 ? 'highlight' : ''}"}
        %a{:href => "#{url_with->query(q => _q(status => 7))}"} 7: 분실
      %span{:class => "#{$status_id == 8 ? 'highlight' : ''}"}
        %a{:href => "#{url_with->query(q => _q(status => 8))}"} 8: 폐기
      %span{:class => "#{$status_id == 9 ? 'highlight' : ''}"}
        %a{:href => "#{url_with->query(q => _q(status => 9))}"} 9: 반납
      %span{:class => "#{$status_id == 10 ? 'highlight' : ''}"}
        %a{:href => "#{url_with->query(q => _q(status => 10))}"} 10: 부분반납
      %span{:class => "#{$status_id == 11 ? 'highlight' : ''}"}
        %a{:href => "#{url_with->query(q => _q(status => 11))}"} 11: 반납배송중
    %p.muted
      %span.text-info 종류
      - for (qw/ jacket pants shirt shoes hat tie waistcoat coat onepiece skirt blouse /) {
        %span{:class => "#{$category eq $_ ? 'highlight' : ''}"}
          %a{:href => "#{url_with->query(q => _q(category => $_))}"}= $_
      - }

.row
  .col-xs-12
    .search
      %form{ :method => 'get', :action => '' }
        .input-group
          %input#gid{:type => 'hidden', :name => 'gid', :value => "#{$gid}"}
          %input#q.form-control{ :type => 'text', :placeholder => '가슴/허리/팔/상태/종류', :name => 'q', :value => "#{$q}" }
          %span.input-group-btn
            %button#btn-clothes-search.btn.btn-sm.btn-default{ :type => 'submit' }
              %i.icon-search.bigger-110 검색

    .space-10

    .col-xs-12.col-lg-10
      %a.btn.btn-sm.btn-info{:href => "#{url_with->query([color => ''])}"} 모두 보기
      %a.btn.btn-sm.btn-black{:href => "#{url_with->query([color => 'B'])}"} 검정(B)
      %a.btn.btn-sm.btn-navy{:href => "#{url_with->query([color => 'N'])}"} 감청(N)
      %a.btn.btn-sm.btn-gray{:href => "#{url_with->query([color => 'G'])}"} 회색(G)
      %a.btn.btn-sm.btn-red{:href => "#{url_with->query([color => 'R'])}"} 빨강(R)
      %a.btn.btn-sm.btn-whites{:href => "#{url_with->query([color => 'W'])}"} 흰색(W)

.space-10

.row
  .col-xs-12
    - if ($q) {
      %p
        %strong= $q
        %span.muted 의 검색결과
    - }

.row
  .col-xs-12
    = include 'guests/breadcrumb', user => $user if $user

.row
  .col-xs-12
    %ul.ace-thumbnails
      - while (my $c = $clothes_list->next) {
        %li
          %a{:href => '/clothes/#{$c->code}'}
            %img{:src => 'http://placehold.it/160x160', :alt => '#{$c->code}'}

          .tags-top-ltr
            %span.label-holder
              %span.label.label-warning.search-label
                %a{:href => '/clothes/#{$c->code}'}= $c->code

          .tags
            %span.label-holder
              - if ($c->bust) {
                %span.label.label-info.search-label
                  %a{:href => "#{url_with->query([p => 1, q => $c->bust . '///' . $status_id])}"}= $c->bust
                - if ($c->bottom) {
                  %span.label.label-info.search-label
                    %a{:href => "#{url_with->query([p => 1, q => '/' . $c->bottom->waist . '//' . $status_id])}"}= $c->bottom->waist
                - }
              - }
              - if ($c->arm) {
                %span.label.label-info.search-label
                  %a{:href => "#{url_with->query([p => 1, q => '//' . $c->arm . '/' . $status_id])}"}= $c->arm
              - }
              - if ($c->length) {
                %span.label.label-info.search-label= $c->length
              - }

            %span.label-holder
              - if ($c->status->name eq '대여가능') {
                %span.label.label-success= $c->status->name
              - }
              - elsif ($c->status->name eq '대여중') {
                %span.label.label-important= $c->status->name
                - if (my $order = $c->orders({ status_id => 2 })->next) {
                  %small.muted{:title => '반납예정일'}= $order->target_date->ymd if $order->target_date
                - }
              - }
              - else {
                %span.label= $c->status->name
              - }
          .satisfaction
            %ul
              - for my $s ($c->satisfactions({}, { rows => 5, order_by => { -desc => [qw/create_date/] } })) {
                %li
                  %span.badge{:class => 'satisfaction-#{$s->bust || 0}'}= $s->guest->bust
                  %span.badge{:class => 'satisfaction-#{$s->waist || 0}'}= $s->guest->waist
                  %span.badge{:class => 'satisfaction-#{$s->arm || 0}'}=   $s->guest->arm
                  %span.badge{:class => 'satisfaction-#{$s->top_fit || 0}'}    상
                  %span.badge{:class => 'satisfaction-#{$s->bottom_fit || 0}'} 하
                  - if ($user && $s->user_id == $user->id) {
                    %i.icon-star{:title => '대여한적 있음'}
                  - }
              - }
      - } # end of while

.row
  .col-xs-12
    .center
      = include 'pagination'


@@ clothes/code.html.haml
- layout 'default', jses => ['clothes-code.js'];
- title 'clothes/' . $clothes->code;

%h1
  %a{:href => ''}= $clothes->code
  %span - #{$clothes->category}

%form#edit
  %a#btn-edit.btn.btn-sm{:href => '#'} edit
  #input-edit{:style => 'display: none'}
    - use v5.14;
    - no warnings 'experimental';
    - given ( $clothes->category ) {
      - when ( /^(jacket|shirt|waistcoat|coat|blouse)$/i ) {
        %input{:type => 'text', :name => 'bust', :value => '#{$clothes->bust}', :placeholder => '가슴둘레'}
        %input{:type => 'text', :name => 'arm',  :value => '#{$clothes->arm}',  :placeholder => '팔길이'}
      - }
      - when ( /^(pants|skirt)$/i ) {
        %input{:type => 'text', :name => 'waist',  :value => '#{$clothes->waist}',  :placeholder => '허리둘레'}
        %input{:type => 'text', :name => 'length', :value => '#{$clothes->length}', :placeholder => '기장'}
      - }
      - when ( /^(shoes)$/i ) {
        %input{:type => 'text', :name => 'length', :value => '#{$clothes->length}', :placeholder => '발크기'}
      - }
    - }
    %input#btn-submit.btn.btn-sm{:type => 'submit', :value => 'Save Changes'}
    %a#btn-cancel.btn.btn-sm{:href => '#'} Cancel

%h4= $clothes->compatible_code

.row
  .span8
    - if ($clothes->status->name eq '대여가능') {
      %span.label.label-success= $clothes->status->name
    - } elsif ($clothes->status->name eq '대여중') {
      %span.label.label-important= $clothes->status->name
      - if (my $order = $clothes->orders({ status_id => 2 })->next) {
        - if ($order->target_date) {
          %small.highlight{:title => '반납예정일'}
            %a{:href => "/orders/#{$order->id}"}= $order->target_date->ymd
        - }
      - }
    - } else {
      %span.label= $clothes->status->name
    - }

    %span
      - if ($clothes->top) {
        %a{:href => '/clothes/#{$clothes->top->code}'}= $clothes->top->code
      - }
      - if ($clothes->bottom) {
        %a{:href => '/clothes/#{$clothes->bottom->code}'}= $clothes->bottom->code
      - }

    %div
      %img.img-polaroid{:src => 'http://placehold.it/200x200', :alt => '#{$clothes->code}'}

    %div
      - if ($clothes->bust) {
        %span.label.label-info.search-label
          %a{:href => "#{url_with('/search')->query([q => $clothes->bust])}///1"}= $clothes->bust
      - }
      - if ($clothes->waist) {
        %span.label.label-info.search-label
          %a{:href => "#{url_with('/search')->query([q => '/' . $clothes->waist . '//1'])}"}= $clothes->waist
      - }
      - if ($clothes->arm) {
        %span.label.label-info.search-label
          %a{:href => "#{url_with('/search')->query([q => '//' . $clothes->arm])}/1"}= $clothes->arm
      - }
      - if ($clothes->length) {
        %span.label.label-info.search-label= $clothes->length
      - }
    - if ($clothes->donor) {
      %h3= $clothes->donor->name
      %p.muted 님께서 기증하셨습니다
    - }
  .span4
    %ul
      - for my $order ($clothes->orders({ status_id => { '!=' => undef } }, { order_by => { -desc => [qw/rental_date/] } })) {
        %li
          %a{:href => '/guests/#{$order->guest->id}'}= $order->guest->user->name
          님
          - if ($order->status && $order->status->name eq '대여중') {
            - if (calc_overdue($order->target_date, DateTime->now())) {
              %span.label.label-important 연체중
            - } else {
              %span.label.label-important= $order->status->name
            - }
          - } else {
            %span.label= $order->status->name
          - }
          %a.highlight{:href => '/orders/#{$order->id}'}
            %time{:title => '대여일'}= $order->rental_date->ymd
      - }


@@ pagination.html.ep
<ul class="pagination">
  <li class="previous">
    <a href="<%= url_with->query([p => $pageset->first_page]) %>">
      <i class="icon-double-angle-left"></i>
      <i class="icon-double-angle-left"></i>
    </a>
  </li>

  % if ( $pageset->previous_set ) {
  <li class="previous">
    <a href="<%= url_with->query([p => $pageset->previous_set]) %>">
      <i class="icon-double-angle-left"></i>
    </a>
  </li>
  % }
  % else {
  <li class="previous disabled">
    <a href="#">
      <i class="icon-double-angle-left"></i>
    </a>
  </li>
  % }

  % for my $p ( @{$pageset->pages_in_set} ) {
  %   if ( $p == $pageset->current_page ) {
  <li class="active"> <a href="#"> <%= $p %> </a> </li>
  %   }
  %   else {
  <li> <a href="<%= url_with->query([p => $p]) %>"> <%= $p %> </a> </li>
  %   }
  % }

  % if ( $pageset->next_set ) {
  <li class="previous">
    <a href="<%= url_with->query([p => $pageset->next_set]) %>">
      <i class="icon-double-angle-right"></i>
    </a>
  </li>
  % }
  % else {
  <li class="previous disabled">
    <a href="#">
      <i class="icon-double-angle-right"></i>
    </a>
  </li>
  % }

  <li class="next">
    <a href="<%= url_with->query([p => $pageset->last_page]) %>">
      <i class="icon-double-angle-right"></i>
      <i class="icon-double-angle-right"></i>
    </a>
  </li>
</ul>


@@ bad_request.html.haml
- layout 'default';
- title 'Bad request';

%h1 400 Bad request
- if ($error) {
  %p.text-error= $error
- }
