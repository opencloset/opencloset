#!/usr/bin/env perl

use v5.18;
use Mojolicious::Lite;

use Data::Pageset;
use DateTime;
use Gravatar::URL;
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
    page_id     => q{},
}}});

my $DB = Opencloset::Schema->connect({
    dsn      => app->config->{database}{dsn},
    user     => app->config->{database}{user},
    password => app->config->{database}{pass},
    %{ app->config->{database}{opts} },
});

helper error => sub {
    my ($self, $status, $error) = @_;

    no warnings 'experimental';
    given ($status) {
        $self->render_not_found                when 404;
        $self->render_exception($error->{str}) when 500;
    }

    $self->respond_to(
        json => { status => $status, json  => { error => $error || q{} } },
        html => { status => $status, error => $error->{str} || q{}       },
    );

    return;
};

helper meta_link => sub {
    my ( $self, $id ) = @_;

    my $meta = app->config->{sidebar}{meta};

    return $meta->{$id}{link} || $id;
};

helper meta_text => sub {
    my ( $self, $id ) = @_;

    my $meta = app->config->{sidebar}{meta};

    return $meta->{$id}{text};
};

helper get_gravatar => sub {
    my ( $self, $user, $size, %opts ) = @_;

    $opts{default} ||= app->config->{avatar_icon};
    $opts{email}   ||= $user->email;
    $opts{size}    ||= $size;

    my $url = Gravatar::URL::gravatar_url(%opts);

    return $url;
};

helper trim_clothes_code => sub {
    my ( $self, $clothes ) = @_;

    my $code = $clothes->code;
    $code =~ s/^0//;

    return $code;
};

helper order_clothes_price => sub {
    my ( $self, $order ) = @_;

    return 0 unless $order;

    my $price = 0;
    for ( $order->order_details ) {
        next unless $_->clothes;
        $price += $_->price;
    }

    return $price;
};

helper calc_overdue => sub {
    my ( $self, $order ) = @_;

    return 0 unless $order;

    my $target_dt = $order->target_date;
    my $return_dt = $order->return_date;

    return 0 unless $target_dt;

    $return_dt ||= DateTime->now( time_zone => app->config->{timezone} );

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
    my ( $self, $order ) = @_;

    my $price   = $self->order_clothes_price($order);
    my $overdue = $self->calc_overdue($order);
    return 0 unless $overdue;

    my $late_fee = $price * 0.2 * $overdue;

    return $late_fee;
};

helper flatten_user => sub {
    my ( $self, $user ) = @_;

    return unless $user;

    my %data = (
        $user->user_info->get_columns,
        $user->get_columns,
    );
    delete @data{qw/ user_id password /};

    return \%data;
};

helper flatten_order => sub {
    my ( $self, $order ) = @_;

    return unless $order;

    my $order_price        = 0;
    my $order_stage0_price = 0;
    for my $order_detail ( $order->order_details ) {
        $order_price        += $order_detail->final_price;
        $order_stage0_price += $order_detail->final_price if $order_detail->stage == 0;
    }

    my %data = (
        $order->get_columns,
        rental_date      => undef,
        target_date      => undef,
        user_target_date => undef,
        return_date      => undef,
        price            => $order_price,
        stage0_price     => $order_stage0_price,
        clothes_price    => $self->order_clothes_price($order),
        clothes          => [ $order->order_details({ clothes_code => { '!=' => undef } })->get_column('clothes_code')->all ],
        late_fee         => $self->calc_late_fee($order),
        overdue          => $self->calc_overdue($order),
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

    if ( $order->user_target_date ) {
        $data{user_target_date} = {
            raw => $order->user_target_date,
            md  => $order->user_target_date->month . '/' . $order->user_target_date->day,
            ymd => $order->user_target_date->ymd
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

helper flatten_order_detail => sub {
    my ( $self, $order_detail ) = @_;

    return unless $order_detail;

    my %data = ( $order_detail->get_columns );

    return \%data;
};

helper flatten_clothes => sub {
    my ( $self, $clothes ) = @_;

    return unless $clothes;

    #
    # additional information for clothes
    #
    my %extra_data;
    # '대여중'인 항목만 주문서 정보를 포함합니다.
    my $order = $clothes->orders->find({ status_id => 2 });
    $extra_data{order} = $self->flatten_order($order) if $order;

    my %data = (
        $clothes->get_columns,
        %extra_data,
        status => $clothes->status->name,
    );

    return \%data;
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

helper get_user => sub {
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
    # find user
    #
    my $user = $DB->resultset('User')->find( $params );
    return $self->error( 404, {
        str  => 'user not found',
        data => {},
    }) unless $user;
    return $self->error( 404, {
        str  => 'user info not found',
        data => {},
    }) unless $user->user_info;

    return $user;
};

helper update_user => sub {
    my ( $self, $user_params, $user_info_params ) = @_;

    #
    # validate params
    #
    my $v = $self->create_validator;
    $v->field('id')->required(1)->regexp(qr/^\d+$/);
    $v->field('email')->email;
    $v->field('phone')->regexp(qr/^\d+$/);
    $v->field('gender')->in(qw/ male female /);
    $v->field('birth')->regexp(qr/^(19|20)\d{2}$/);
    $v->field(qw/ height weight bust waist hip belly thigh arm leg knee foot /)->each(sub {
        shift->regexp(qr/^\d{1,3}$/);
    });
    unless ( $self->validate( $v, { %$user_params, %$user_info_params } ) ) {
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
    my $user = $DB->resultset('User')->find({ id => $user_params->{id} });
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

        my %_user_params = %$user_params;
        delete $_user_params{id};
        $user->update( \%_user_params )
            or return $self->error( 500, {
                str  => 'failed to update a user',
                data => {},
            });

        $user->user_info->update({
            %$user_info_params,
            user_id => $user->id,
        }) or return $self->error( 500, {
            str  => 'failed to update a user info',
            data => {},
        });

        $guard->commit;
    }

    return $user;
};

helper create_order => sub {
    my ( $self, $order_params, $order_detail_params ) = @_;

    return unless $order_params;
    return unless ref($order_params) eq 'HASH';

    #
    # validate params
    #
    {
        my $v = $self->create_validator;
        $v->field('user_id')->required(1)->regexp(qr/^\d+$/)->callback(sub {
            my $val = shift;

            return 1 if $DB->resultset('User')->find({ id => $val });
            return ( 0, 'user not found using user_id' );
        });
        $v->field('additional_day')->regexp(qr/^\d+$/);
        $v->field(qw/ height weight bust waist hip belly thigh arm leg knee foot /)->each(sub {
            shift->regexp(qr/^\d{1,3}$/);
        });
        unless ( $self->validate( $v, $order_params ) ) {
            my @error_str;
            while ( my ( $k, $v ) = each %{ $v->errors } ) {
                push @error_str, "$k:$v";
            }
            $self->error( 400, {
                str  => join(',', @error_str),
                data => $v->errors,
            }), return;
        }
    }
    {
        my $v = $self->create_validator;
        $v->field('clothes_code')->regexp(qr/^[A-Z0-9]{4,5}$/)->callback(sub {
            my $val = shift;

            $val = sprintf( '%05s', $val ) if length $val == 4;

            return 1 if $DB->resultset('Clothes')->find({ code => $val });
            return ( 0, 'clothes not found using clothes_code' );
        });
        unless ( $self->validate( $v, $order_detail_params ) ) {
            my @error_str;
            while ( my ( $k, $v ) = each %{ $v->errors } ) {
                push @error_str, "$k:$v";
            }
            $self->error( 400, {
                str  => join(',', @error_str),
                data => $v->errors,
            }), return;
        }
    }

    #
    # adjust params
    #
    if ( $order_detail_params && $order_detail_params->{clothes_code} ) {
        $order_detail_params->{clothes_code} = [ $order_detail_params->{clothes_code} ]
            unless ref $order_detail_params->{clothes_code};

        for ( @{ $order_detail_params->{clothes_code} } ) {
            next unless length == 4;
            $_ = sprintf( '%05s', $_ );
        }
    }

    #
    # TRANSACTION:
    #
    #   - create order
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

            #
            # create order_detail
            #
            my ( $f_key ) = keys %$order_detail_params;
            return $order unless $f_key;
            unless ( ref $order_detail_params->{$f_key} ) {
                $order_detail_params->{$_} = [ $order_detail_params->{$_} ] for keys %$order_detail_params;
            }
            for ( my $i = 0; $i < @{ $order_detail_params->{$f_key} }; ++$i ) {
                my %params;
                for my $k ( keys %$order_detail_params ) {
                    $params{$k} = $order_detail_params->{$k}[$i];
                }

                if ( $params{clothes_code} ) {
                    if (   defined $params{name}
                        && defined $params{price}
                        && defined $params{final_price} )
                    {
                        $order->add_to_order_details( \%params )
                            or die "failed to create a new order_detail\n";
                    }
                    else {
                        my $clothes = $DB->resultset('Clothes')->find({ code => $params{clothes_code} });

                        my $name = $params{name} // join(
                            q{ - },
                            $self->trim_clothes_code($clothes),
                            app->config->{category}{ $clothes->category }{str},
                        );
                        my $price       = $params{price} // $clothes->price;
                        my $final_price = $params{final_price} // (
                            $clothes->price + $clothes->price * 0.2 * ($order_params->{additional_day} || 0)
                        );

                        $order->add_to_order_details({
                            %params,
                            clothes_code => $clothes->code,
                            name         => $name,
                            price        => $price,
                            final_price  => $final_price,
                        }) or die "failed to create a new order_detail\n";
                    }
                }
                else {
                    $order->add_to_order_details( \%params )
                        or die "failed to create a new order_detail\n";
                }
            }
            $order->add_to_order_details({
                name        => '에누리',
                price       => 0,
                final_price => 0,
            }) or die "failed to create a new order_detail for discount\n";

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

helper update_order => sub {
    my ( $self, $order_params, $order_detail_params ) = @_;

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
    $v->field('additional_day')->regexp(qr/^\d+$/);
    $v->field(qw/ height weight bust waist hip belly thigh arm leg knee foot /)->each(sub {
        shift->regexp(qr/^\d{1,3}$/);
    });
    unless ( $self->validate( $v, $order_params ) ) {
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
    # TRANSACTION:
    #
    #   - find   order
    #   - update order
    #   - update clothes status
    #   - update order_detail
    #
    my ( $order, $status, $error ) = do {
        my $guard = $DB->txn_scope_guard;
        try {
            #
            # find order
            #
            my $order = $DB->resultset('Order')->find({ id => $order_params->{id} });
            die "order not found\n" unless $order;

            #
            # update order
            #
            {
                my %_params = %$order_params;
                delete $_params{id};
                $order->update( \%_params ) or die "failed to update the order\n";
            }

            #
            # update clothes status
            #
            if ( $order_params->{status_id} ) {
                for my $clothes ( $order->clothes ) {
                    $clothes->update({ status_id => $order_params->{status_id} })
                        or die "failed to update the clothes status\n";
                }
            }

            #
            # update order_detail
            #
            if ( $order_detail_params && $order_detail_params->{id} ) {
                my %_params = %$order_detail_params;
                for my $i ( 0 .. $#{ $_params{id} } ) {
                    my %p  = map { $_ => $_params{$_}[$i] } keys %_params;
                    my $id = delete $p{id};

                    my $order_detail = $DB->resultset('OrderDetail')->find({ id => $id });
                    die "order_detail not found\n" unless $order_detail;
                    $order_detail->update( \%p ) or die "failed to update the order_detail\n";
                }
            }

            $guard->commit;

            return $order;
        }
        catch {
            chomp;
            app->log->error("failed to create a new order & a new order_clothes");
            app->log->error($_);

            no warnings 'experimental';

            my $status;
            given ($_) {
                $status = 404 when 'order not found';
                default { $status = 500 }
            }

            return ( undef, $status, $_ );
        };
    };

    #
    # response
    #
    $self->error( $status, {
        str  => $error,
        data => {},
    }), return unless $order;

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

helper create_order_detail => sub {
    my ( $self, $params ) = @_;

    return unless $params;
    return unless ref($params) eq 'HASH';

    #
    # validate params
    #
    my $v = $self->create_validator;
    $v->field('order_id')->required(1)->regexp(qr/^\d+$/)->callback(sub {
        my $val = shift;

        return 1 if $DB->resultset('Order')->find({ id => $val });
        return ( 0, 'order not found using order_id' );
    });
    $v->field('clothes_code')->regexp(qr/^[A-Z0-9]{4,5}$/)->callback(sub {
        my $val = shift;

        $val = sprintf( '%05s', $val ) if length $val == 4;

        return 1 if $DB->resultset('Clothes')->find({ code => $val });
        return ( 0, 'clothes not found using clothes_code' );
    });
    $v->field('status_id')->regexp(qr/^\d+$/)->callback(sub {
        my $val = shift;

        return 1 if $DB->resultset('Status')->find({ id => $val });
        return ( 0, 'status not found using status_id' );
    });
    $v->field(qw/ price final_price /)
        ->each( sub { shift->regexp(qr/^-?\d+$/) } );
    $v->field('stage')->regexp(qr/^\d+$/);

    unless ( $self->validate( $v, $params ) ) {
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
    $params->{clothes_code} = sprintf( '%05s', $params->{clothes_code} )
        if $params->{clothes_code} && length( $params->{clothes_code} ) == 4;

    my $order_detail = $DB->resultset('OrderDetail')->create($params);
    return $self->error( 500, {
        str  => 'failed to create a new order_detail',
        data => {},
    }) unless $order_detail;

    return $order_detail;
};

helper get_clothes => sub {
    my ( $self, $params ) = @_;

    #
    # validate params
    #
    my $v = $self->create_validator;
    $v->field('code')->required(1)->regexp(qr/^[A-Z0-9]{4,5}$/);
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
    $params->{code} = sprintf( '%05s', $params->{code} ) if length( $params->{code} ) == 4;

    #
    # find clothes
    #
    my $clothes = $DB->resultset('Clothes')->find( $params );
    return $self->error( 404, {
        str  => 'clothes not found',
        data => {},
    }) unless $clothes;

    return $clothes;
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

    post '/order_detail'   => \&api_create_order_detail;

    post '/clothes'        => \&api_create_clothes;
    get  '/clothes/:code'  => \&api_get_clothes;
    put  '/clothes/:code'  => \&api_update_clothes;
    del  '/clothes/:code'  => \&api_delete_clothes;

    get  '/clothes-list'   => \&api_get_clothes_list;
    put  '/clothes-list'   => \&api_update_clothes_list;

    post '/donation'       => \&api_create_donation;

    post '/group'          => \&api_create_group;

    get  '/search/user'    => \&api_search_user;

    get  '/gui/staff-list' => \&api_gui_staff_list;

    sub api_create_user {
        my $self = shift;

        #
        # fetch params
        #
        my %user_params      = $self->get_params(qw/ name email password /);
        my %user_info_params = $self->get_params(qw/
            address
            arm
            belly
            birth
            bust
            comment
            foot
            gender
            height
            hip
            knee
            leg
            phone
            thigh
            waist
            weight
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
        $v->field(qw/ height weight bust waist hip belly thigh arm leg knee foot /)->each(sub {
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

        my $user = $self->get_user( \%params );
        return unless $user;

        #
        # response
        #
        my $data = $self->flatten_user($user);

        $self->respond_to( json => { status => 200, json => $data } );
    }

    sub api_update_user {
        my $self = shift;

        #
        # fetch params
        #
        my %user_params      = $self->get_params(qw/ id name email password /);
        my %user_info_params = $self->get_params(qw/
            address
            arm
            belly
            birth
            bust
            comment
            foot
            gender
            height
            hip
            knee
            leg
            phone
            thigh
            waist
            weight
        /);

        my $user = $self->update_user( \%user_params, \%user_info_params );
        return unless $user;

        #
        # response
        #
        my $data = $self->flatten_user($user);

        $self->respond_to( json => { status => 200, json => $data } );
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
            additional_day
            arm
            belly
            bust
            comment
            discount
            foot
            height
            hip
            knee
            l_discount
            late_fee
            late_fee_pay_with
            leg
            price
            price_pay_with
            purpose
            rental_date
            return_date
            return_method
            staff_name
            status_id
            target_date
            thigh
            user_id
            user_target_date
            waist
            weight
        /);
        my %order_detail_params = $self->get_params(
            [ order_detail_clothes_code => 'clothes_code' ],
            [ order_detail_status_id    => 'status_id'    ],
            [ order_detail_name         => 'name'         ],
            [ order_detail_price        => 'price'        ],
            [ order_detail_final_price  => 'final_price'  ],
            [ order_detail_desc         => 'desc'         ],
        );
        my $order = $self->create_order( \%order_params, \%order_detail_params );
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
        my %order_params = $self->get_params(qw/
            additional_day
            arm
            bust
            comment
            discount
            foot
            height
            hip
            id
            knee
            l_discount
            late_fee
            late_fee_pay_with
            leg
            price
            price_pay_with
            purpose
            rental_date
            return_date
            return_method
            staff_name
            status_id
            target_date
            thigh
            user_id
            user_target_date
            waist
            weight
        /);
        my %order_detail_params = $self->get_params(
            [ order_detail_id           => 'id'           ],
            [ order_detail_clothes_code => 'clothes_code' ],
            [ order_detail_status_id    => 'status_id'    ],
            [ order_detail_name         => 'name'         ],
            [ order_detail_price        => 'price'        ],
            [ order_detail_final_price  => 'final_price'  ],
            [ order_detail_desc         => 'desc'         ],
        );

        my $order = $self->update_order( \%order_params, \%order_detail_params );
        return unless $order;

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

    sub api_create_order_detail {
        my $self = shift;

        #
        # fetch params
        #
        my %params = $self->get_params(qw/
            clothes_code
            desc
            final_price
            name
            order_id
            price
            stage
            status_id
        /);

        my $order_detail = $self->create_order_detail( \%params );
        return unless $order_detail;

        #
        # response
        #
        my $data = $self->flatten_order_detail($order_detail);

        $self->res->headers->header(
            'Location' => $self->url_for( '/api/order_detail/' . $order_detail->id ),
        );
        $self->respond_to( json => { status => 201, json => $data } );
    }

    sub api_create_clothes {
        my $self = shift;

        #
        # fetch params
        #
        my %params = $self->get_params(qw/
            arm
            bust
            category
            code
            color
            compatible_code
            donation_id
            gender
            group_id
            hip
            length
            price
            status_id
            thigh
            waist
        /);

        #
        # validate params
        #
        my $v = $self->create_validator;
        $v->field('code')->required(1)->regexp(qr/^[A-Z0-9]{4,5}$/);
        $v->field('category')->required(1)->in(@CATEGORIES);
        $v->field('gender')->in(qw/ male female unisex /);
        $v->field('price')->regexp(qr/^\d*$/);
        $v->field(qw/ bust waist hip thigh arm length /)->each(sub {
            shift->regexp(qr/^\d{1,3}$/);
        });
        $v->field('donation_id')->regexp(qr/^\d*$/)->callback(sub {
            my $val = shift;

            return 1 if $DB->resultset('Donation')->find({ id => $val });
            return ( 0, 'donation not found using donation_id' );
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

        my $clothes = $self->get_clothes( \%params );
        return unless $clothes;

        #
        # response
        #
        my $data = $self->flatten_clothes($clothes);

        $self->respond_to( json => { status => 200, json => $data } );
    }

    sub api_update_clothes {
        my $self = shift;

        #
        # fetch params
        #
        my %params = $self->get_params(qw/
            arm
            bust
            category
            code
            color
            compatible_code
            donation_id
            gender
            group_id
            hip
            length
            price
            status_id
            thigh
            waist
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
        $v->field('donation_id')->regexp(qr/^\d*$/)->callback(sub {
            my $val = shift;

            return 1 if $DB->resultset('Donation')->find({ id => $val });
            return ( 0, 'donation not found using donation_id' );
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
        my $data = $self->flatten_clothes($clothes);

        $self->respond_to( json => { status => 200, json => $data } );
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
        my $data = $self->flatten_clothes($clothes);
        $clothes->delete;

        $self->respond_to( json => { status => 200, json => $data } );
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
        push @data, $self->flatten_clothes($_) for @clothes_list;

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
            arm
            bust
            category
            code
            color
            compatible_code
            donation_id
            gender
            group_id
            hip
            length
            price
            status_id
            thigh
            waist
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
        $v->field('donation_id')->regexp(qr/^\d*$/)->callback(sub {
            my $val = shift;

            return 1 if $DB->resultset('Donation')->find({ id => $val });
            return ( 0, 'donation not found using donation_id' );
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

    sub api_create_donation {
        my $self = shift;

        #
        # fetch params
        #
        my %params = $self->get_params(qw/
            user_id
            message
        /);

        #
        # validate params
        #
        my $v = $self->create_validator;
        $v->field('user_id')->required(1)->regexp(qr/^\d*$/)->callback(sub {
            my $val = shift;

            return 1 if $DB->resultset('User')->find({ id => $val });
            return ( 0, 'user not found using user_id' );
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
        # create donation
        #
        my $donation = $DB->resultset('Donation')->create( \%params );
        return $self->error( 500, {
            str  => 'failed to create a new donation',
            data => {},
        }) unless $donation;

        #
        # response
        #
        my %data = ( $donation->get_columns );

        $self->res->headers->header(
            'Location' => $self->url_for( '/api/donation/' . $donation->id ),
        );
        $self->respond_to( json => { status => 201, json => \%data } );
    }

    sub api_create_group {
        my $self = shift;

        #
        # fetch params
        #
        my %params = $self->get_params(qw//);

        #
        # validate params
        #
        my $v = $self->create_validator;

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
        # create group
        #
        my $group = $DB->resultset('Group')->create( \%params );
        return $self->error( 500, {
            str  => 'failed to create a new group',
            data => {},
        }) unless $group;

        #
        # response
        #
        my %data = ( $group->get_columns );

        $self->res->headers->header(
            'Location' => $self->url_for( '/api/group/' . $group->id ),
        );
        $self->respond_to( json => { status => 201, json => \%data } );
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

    #
    # fetch params
    #
    my %params = $self->get_params(qw/ id /);

    my $user = $self->get_user( \%params );
    return unless $user;

    my $donated_clothes_count = 0;
    $donated_clothes_count += $_->clothes->count for $user->donations;

    my $rented_clothes_count = 0;
    $rented_clothes_count += $_->clothes->count for $user->order_users;

    #
    # response
    #
    $self->stash(
        user                  => $user,
        donated_clothes_count => $donated_clothes_count,
        rented_clothes_count  => $rented_clothes_count,
    );
} => 'user-id';

get '/clothes/:code' => sub {
    my $self = shift;

    #
    # fetch params
    #
    my %params = $self->get_params(qw/ code /);

    my $clothes = $self->get_clothes( \%params );
    return unless $clothes;

    my $rented_count = 0;
    ++$rented_count for $clothes->order_details->search({ status_id => { '>' => 1 } });

    #
    # response
    #
    $self->stash(
        clothes      => $clothes,
        rented_count => $rented_count,
    );
} => 'clothes-code';

get '/rental' => sub {
    my $self = shift;

    my $q = $self->param('q');

    ### DBIx::Class::Storage::DBI::_gen_sql_bind(): DateTime objects passed to search() are not
    ### supported properly (InflateColumn::DateTime formats and settings are not respected.)
    ### See "Formatting DateTime objects in queries" in DBIx::Class::Manual::Cookbook.
    ### To disable this warning for good set $ENV{DBIC_DT_SEARCH_OK} to true
    ###
    ### DateTime object 를 search 에 바로 사용하지 말고 parser 를 이용하라능 - @aanoaa
    my $today     = DateTime->today( time_zone => app->config->{timezone} );
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
    my %order_params        = $self->get_params(qw/ user_id /);
    my %order_detail_params = $self->get_params(qw/ clothes_code /);

    my $order = $self->create_order( \%order_params, \%order_detail_params );
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
    $self->render( 'order-id', order => $order );
};

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
