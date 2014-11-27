#!/usr/bin/env perl

use v5.18;
use Mojolicious::Lite;

#
# redirect to login rather than not found page
#
#   https://groups.google.com/forum/#!topic/mojolicious/UbY9Ac9unfY
#   https://github.com/kraih/mojo/compare/69fbd6807611ec209eff4147b511c8c324a80118...d9145abedbbebe226f9f6f3b22488de88809ba4d
#
{
    package OpenCloset::Web::Controller;

    use base 'Mojolicious::Controller';

    sub render_not_found {
        my ( $self, $e ) = @_;

        if ( !$self->is_user_authenticated ) {
            $self->redirect_to( $self->url_for('/visit') );
            return;
        }

        Mojolicious::Controller::_development( 'not_found', @_ );
    }

    1;
}
app->controller_class("OpenCloset::Web::Controller");

use Data::Pageset;
use DateTime;
use Gravatar::URL;
use List::MoreUtils qw( zip );
use List::Util qw( sum );
use Mojo::Util qw( encode );
use SMS::Send::KR::CoolSMS;
use SMS::Send;
use String::Random;
use Text::CSV;
use Try::Tiny;
use Unicode::GCString;
use Unicode::Normalize;
use Encode 'decode_utf8';

use Postcodify;

use OpenCloset::Schema;

app->defaults( %{ plugin 'Config' => { default => {
    jses        => [],
    csses       => [],
    breadcrumbs => [],
    active_id   => q{},
    page_id     => q{},
    alert       => q{},
    type        => q{},
}}});

my $DB = OpenCloset::Schema->connect({
    dsn      => app->config->{database}{dsn},
    user     => app->config->{database}{user},
    password => app->config->{database}{pass},
    %{ app->config->{database}{opts} },
});

plugin 'validator';
plugin 'haml_renderer';
plugin 'FillInFormLite';

plugin 'authentication' => {
    autoload_user => 1,
    load_user     => sub {
        my ( $app, $uid ) = @_;

        my $user_obj = $DB->resultset('User')->find({ id => $uid });

        return $user_obj
    },
    session_key   => 'access_token',
    validate_user => sub {
        my ( $self, $user, $pass, $extradata ) = @_;

        my $user_obj = $DB->resultset('User')->find({ email => $user });
        unless ($user_obj) {
            app->log->warn("cannot find such user: $user");
            return;
        }

        unless ( $user_obj->check_password($pass) ) {
            app->log->warn("$user\'s password is wrong");
            return;
        }

        unless ( $user_obj->user_info->staff ) {
            app->log->warn("$user is not a staff");
            return;
        }

        return $user_obj->id;
    },
};

helper error => sub {
    my ($self, $status, $error) = @_;

    app->log->error( $error->{str} );

    no warnings 'experimental';
    my $template;
    given ($status) {
        $template = 'bad_request' when 400;
        $template = 'not_found'   when 404;
        $template = 'exception'   when 500;
        default { $template = 'unknown' }
    }

    $self->respond_to(
        json => { status => $status, json  => { error => $error || q{} } },
        html => { status => $status, error => $error->{str} || q{}, template => $template },
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
    return int($dur / $DAY_AS_SECONDS) + 1;
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

helper flatten_booking => sub {
    my ( $self, $booking ) = @_;

    return unless $booking;

    my %data = $booking->get_columns;

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
        my $v;
        if ( ref($k) eq 'ARRAY' ) {
            push @src_keys,  $k->[0];
            push @dest_keys, $k->[1];

            $v = $self->every_param( $k->[0] );
        }
        else {
            push @src_keys,  $k;
            push @dest_keys, $k;

            $v = $self->every_param($k);
        }

        if ($v) {
            if ( @$v == 1 ) {
                push @values, $v->[0];
            }
            elsif ( @$v < 1 ) {
                push @values, undef;
            }
            else {
                push @values, $v;
            }
        }
        else {
            push @values, undef;
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
    $v->field('expires')->regexp(qr/^\d+$/);
    $v->field('phone')->regexp(qr/^\d+$/);
    $v->field('gender')->in(qw/ male female /);
    $v->field('birth')->regexp(qr/^(0|((19|20)\d{2}))$/);
    $v->field(qw/ height weight bust waist hip belly thigh arm leg knee foot /)->each(sub {
        shift->regexp(qr/^\d{1,3}$/);
    });
    $v->field('staff')->in( 0, 1 );
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

        if ( $_user_params{create_date} ) {
            $_user_params{create_date} = DateTime->from_epoch(
                epoch     => $_user_params{create_date},
                time_zone => app->config->{timezone},
            );
        }
        if ( $_user_params{update_date} ) {
            $_user_params{update_date} = DateTime->from_epoch(
                epoch     => $_user_params{update_date},
                time_zone => app->config->{timezone},
            );
        }

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

helper get_user_list => sub {
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
    # find user
    #
    my $rs;
    if ( defined $params->{id} ) {
        $rs
            = $DB->resultset('User')
            ->search({ id => $params->{id} })
            ;
    }
    else {
        $rs = $DB->resultset('User');
    }
    return $self->error( 404, {
        str  => 'user list not found',
        data => {},
    }) if $rs->count == 0 && !$params->{allow_empty};

    return $rs;
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
        $v->field('bestfit')->in( 0, 1 );
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
    {
        #
        # override body measurement(size) from user's data
        #
        my $user = $self->get_user({ id => $order_params->{user_id} });
        #
        # we believe user is exist since parameter validator
        #
        for (qw/ height weight bust waist hip belly thigh arm leg knee foot /) {
            next if     defined $order_params->{$_};
            next unless defined $user->user_info->$_;

            app->log->debug( "overriding $_ from user for order creation" );
            $order_params->{$_} = $user->user_info->$_;
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
    {
        my $v = $self->create_validator;
        $v->field('id')->required(1)->regexp(qr/^\d+$/);
        $v->field('user_id')->regexp(qr/^\d+$/)->callback(sub {
            my $val = shift;

            return 1 if $DB->resultset('User')->find({ id => $val });
            return ( 0, 'user not found using user_id' );
        });
        $v->field('additional_day')->regexp(qr/^\d+$/);
        $v->field(qw/ height weight bust waist hip belly thigh arm leg knee foot /)->each(sub {
            shift->regexp(qr/^\d{1,3}$/);
        });
        $v->field('bestfit')->in( 0, 1 );
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
    }) if $rs->count == 0 && !$params->{allow_empty};

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
# csv section
#
group {
    under '/csv';

    get '/user'    => \&csv_get_user;
    get '/clothes' => \&csv_get_clothes;

    sub csv_get_user {
        my $self = shift;

        my $csv = Text::CSV->new({
            binary => 1,
            eol    => "\n",
        }) or return $self->error( 500, {
            str  => "Cannot use CSV: " . Text::CSV->error_diag,
            data => {},
        });

        my $dt = DateTime->now( time_zone => app->config->{timezone} );
        my $filename = 'user-' . $dt->ymd(q{}) . '-' . $dt->hms(q{}) . '.csv';

        $self->res->headers->content_disposition( "attachment; filename=$filename" );

        my $rs = $DB->resultset('User');
        my $cb_finish; $cb_finish = sub {
            my $self = shift;

            my $user = $rs->next;
            $self->finish, return unless $user;

            $csv->combine(
                $user->id,
                $user->name,
                $user->email,
                $user->create_date,
                $user->user_info->phone,
                $user->user_info->address1,
                $user->user_info->address2,
                $user->user_info->address3,
                $user->user_info->address4,
                $user->user_info->gender,
                $user->user_info->birth,
            );
            $self->write_chunk( encode( 'UTF-8', $csv->string ) => $cb_finish );
        };

        $csv->combine(qw/
            id
            name
            email
            createdate
            phone
            address1
            address2
            address3
            address4
            gender
            birth
        /);
        $self->write_chunk( encode( 'UTF-8', $csv->string ) => $cb_finish );

        #
        # response
        #
        $self->res->headers->content_type('text/plain');
    }

    sub csv_get_clothes {
        my $self = shift;

        my $csv = Text::CSV->new({
            binary => 1,
            eol    => "\n",
        }) or return $self->error( 500, {
            str  => "Cannot use CSV: " . Text::CSV->error_diag,
            data => {},
        });

        my $dt = DateTime->now( time_zone => app->config->{timezone} );
        my $filename = 'clothes-' . $dt->ymd(q{}) . '-' . $dt->hms(q{}) . '.csv';

        $self->res->headers->content_disposition( "attachment; filename=$filename" );

        my $rs = $DB->resultset('Clothes');
        my $cb_finish; $cb_finish = sub {
            my $self = shift;

            my $clothes = $rs->next;
            $self->finish, return unless $clothes;

            $csv->combine(
                $clothes->id,
                $clothes->code,
                $clothes->category,
                $clothes->gender,
                $clothes->color,
                $clothes->bust,
                $clothes->waist,
                $clothes->hip,
                $clothes->belly,
                $clothes->arm,
                $clothes->thigh,
                $clothes->length,
                $clothes->compatible_code,
            );
            $self->write_chunk( encode( 'UTF-8', $csv->string ) => $cb_finish );
        };

        $csv->combine(qw/
            id
            code
            category
            gender
            color
            bust
            waist
            hip
            belly
            arm
            thigh
            length
            compatible_code
        /);
        $self->write_chunk( encode( 'UTF-8', $csv->string ) => $cb_finish );

        #
        # response
        #
        $self->res->headers->content_type('text/plain');
    }
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

    post '/user'                  => \&api_create_user;
    get  '/user/:id'              => \&api_get_user;
    put  '/user/:id'              => \&api_update_user;
    del  '/user/:id'              => \&api_delete_user;

    get  '/user-list'             => \&api_get_user_list;

    post '/order'                 => \&api_create_order;
    get  '/order/:id'             => \&api_get_order;
    put  '/order/:id'             => \&api_update_order;
    del  '/order/:id'             => \&api_delete_order;

    put  '/order/:id/return-part' => \&api_return_part_order;

    get  '/order-list'            => \&api_get_order_list;

    post '/order_detail'          => \&api_create_order_detail;

    post '/clothes'               => \&api_create_clothes;
    get  '/clothes/:code'         => \&api_get_clothes;
    put  '/clothes/:code'         => \&api_update_clothes;
    del  '/clothes/:code'         => \&api_delete_clothes;

    put  '/clothes/:code/tag'     => \&api_update_clothes_tag;

    get  '/clothes-list'          => \&api_get_clothes_list;
    put  '/clothes-list'          => \&api_update_clothes_list;

    post '/tag'                   => \&api_create_tag;
    get  '/tag/:id'               => \&api_get_tag;
    put  '/tag/:id'               => \&api_update_tag;
    del  '/tag/:id'               => \&api_delete_tag;

    post '/donation'              => \&api_create_donation;

    post '/group'                 => \&api_create_group;

    post '/sms'                   => \&api_create_sms;
    put  '/sms/:id'               => \&api_update_sms;
    post '/sms/validation'        => \&api_create_sms_validation;

    get  '/search/user'           => \&api_search_user;
    get  '/search/user/late'      => \&api_search_late_user;
    get  '/search/donation'       => \&api_search_donation;
    get  '/search/sms'            => \&api_search_sms;

    get  '/gui/staff-list'        => \&api_gui_staff_list;
    put  '/gui/booking/:id'       => \&api_gui_update_booking;
    get  '/gui/booking-list'      => \&api_gui_booking_list;
    post '/gui/utf8/gcs-columns'  => \&api_gui_utf8_gcs_columns;
    get  '/gui/timetable/:ymd'    => \&api_gui_timetable;

    any '/postcode/search'       => \&api_postcode_search;

    sub api_create_user {
        my $self = shift;

        #
        # fetch params
        #
        my %user_params = $self->get_params(qw/
            name
            email
            password
            create_date
            update_date
        /);
        my %user_info_params = $self->get_params(qw/
            address1
            address2
            address3
            address4
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
            purpose
            purpose2
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

            my %_user_params = %user_params;
            if ( $_user_params{create_date} ) {
                $_user_params{create_date} = DateTime->from_epoch(
                    epoch     => $_user_params{create_date},
                    time_zone => app->config->{timezone},
                );
            }
            if ( $_user_params{update_date} ) {
                $_user_params{update_date} = DateTime->from_epoch(
                    epoch     => $_user_params{update_date},
                    time_zone => app->config->{timezone},
                );
            }

            my $user = $DB->resultset('User')->create(\%_user_params);
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
        my %user_params = $self->get_params(qw/
            id
            name
            email
            password
            expires
            create_date
            update_date
        /);
        my %user_info_params = $self->get_params(qw/
            address1
            address2
            address3
            address4
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
            purpose
            purpose2
            staff
            thigh
            waist
            weight
        /);

        my ( $user, $msg )
            = try {
                $self->update_user( \%user_params, \%user_info_params );
            }
            catch {
                chomp;
                my $err = $_;

                $err = $1 if $err =~ m/(Duplicate entry .*? for key '.*?')/;

                ( undef, $err );
            };
        unless ($user) {
            app->log->error("failed to update the user: $msg");
            $self->respond_to( json => { status => 400, json => { error => $msg } } );
            return;
        }

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
            bestfit
            bust
            desc
            foot
            height
            hip
            knee
            late_fee_pay_with
            leg
            parent_id
            price_pay_with
            purpose
            rental_date
            return_date
            return_method
            staff_id
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
            belly
            bestfit
            bust
            desc
            foot
            height
            hip
            id
            knee
            late_fee_pay_with
            leg
            parent_id
            price_pay_with
            purpose
            rental_date
            return_date
            return_method
            staff_id
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

    sub api_return_part_order {
        my $self = shift;

        #
        # fetch params
        #
        my %order_params = $self->get_params(qw/
            additional_day
            arm
            belly
            bestfit
            bust
            desc
            foot
            height
            hip
            id
            knee
            late_fee_pay_with
            leg
            parent_id
            price_pay_with
            purpose
            rental_date
            return_date
            return_method
            staff_id
            status_id
            target_date
            thigh
            user_id
            user_target_date
            waist
            weight
        /);
        my %order_detail_params = $self->get_params(
            [ order_detail_id => 'id' ],
        );

        #
        # update the order
        #
        my $order = $self->get_order( { id => $order_params{id} } );
        return unless $order;
        {
            my %_params = (
                id        => [],
                status_id => [],
            );
            for my $order_detail ( $order->order_details ) {
                next unless $order_detail->clothes;
                push @{ $_params{id}        }, $order_detail->id;
                push @{ $_params{status_id} }, 9;
            }
            $order = $self->update_order(
                \%order_params,
                \%_params,
            );
            return unless $order;
        }

        #
        # create new order
        #
        $order_params{additional_day}   = $order->additional_day;
        $order_params{desc}             = $order->desc;
        $order_params{parent_id}        = $order->id;
        $order_params{purpose}          = $order->purpose;
        $order_params{rental_date}      = $order->rental_date;
        $order_params{target_date}      = $order->target_date;
        $order_params{user_id}          = $order->user_id;
        $order_params{user_target_date} = $order->user_target_date;

        delete $order_params{id};
        delete $order_params{late_fee_pay_with};
        delete $order_params{price_pay_with};
        delete $order_params{return_date};
        delete $order_params{return_method};
        delete $order_params{status_id};

        my $new_order;
        {
            my $pre_price       = 0;
            my $pre_final_price = 0;

            my @clothes_code;
            my @price;
            my @final_price;
            my @name;
            for my $order_detail (
                $order->order_details->search(
                    {
                        -and => [
                            id => { -not_in => $order_detail_params{id} },
                            clothes_code => { '!=' => undef },
                        ],
                    }
                )->all
                )
            {
                push @clothes_code, $order_detail->clothes_code;
                push @price,        $order_detail->price;
                push @final_price,  $order_detail->final_price;
                push @name,         $order_detail->name;

                $pre_price       -= $order_detail->price;
                $pre_final_price -= $order_detail->final_price;
            }

            push @clothes_code, undef;
            push @name,         '이전 주문 납부';
            push @price,        $pre_price;
            push @final_price,  $pre_final_price;

            $new_order = $self->create_order(
                \%order_params,
                {
                    clothes_code => \@clothes_code,
                    name         => \@name,
                    status_id    => [ map 2, @clothes_code ],
                    price        => \@price,
                    final_price  => \@final_price,
                },
            );
            return unless $new_order;
        }

        #
        # response
        #
        my $data = $self->flatten_order($new_order);

        $self->res->headers->header(
            'Location' => $self->url_for( '/api/order/' . $order->id ),
        );
        $self->respond_to( json => { status => 201, json => $data } );
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
            belly
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
        $v->field('category')->required(1)->in( keys %{ app->config->{category} } );
        $v->field('gender')->in(qw/ male female unisex /);
        $v->field('price')->regexp(qr/^\d*$/);
        $v->field(qw/ belly bust waist hip thigh arm length /)->each(sub {
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
            belly
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
        $v->field('category')->in( keys %{ app->config->{category} } );
        $v->field('gender')->in(qw/ male female unisex /);
        $v->field('price')->regexp(qr/^\d*$/);
        $v->field(qw/ belly bust waist hip thigh arm length /)->each(sub {
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

    sub api_update_clothes_tag {
        my $self = shift;

        #
        # fetch params
        #
        my %params = $self->get_params(
            [ code => 'clothes_code' ],
            'tag_id'
        );

        #
        # validate params
        #
        my $v = $self->create_validator;
        $v->field('clothes_code')->required(1)->regexp(qr/^[A-Z0-9]{4,5}$/)->callback(sub {
            my $val = shift;

            $val = sprintf( '%05s', $val ) if length $val == 4;

            return 1 if $DB->resultset('Clothes')->find({ code => $val });
            return ( 0, 'clothes not found using clothes_code' );
        });
        $v->field('tag_id')->regexp(qr/^\d+$/)->callback(sub {
            my $val = shift;

            return 1 if $DB->resultset('Tag')->find({ id => $val });
            return ( 0, 'tag not found using tag_id' );
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
        $params{clothes_code} = sprintf( '%05s', $params{clothes_code} )
            if length $params{clothes_code} == 4;

        #
        # TRANSACTION:
        #
        my ( $clothes_tag, $status, $error ) = do {
            my $guard = $DB->txn_scope_guard;
            try {
                #
                # remove existing clothes tag data
                #
                $DB->resultset('ClothesTag')->search({ clothes_code => $params{clothes_code} })->delete_all;

                my @clothes_tags;
                if ( $params{tag_id} ) {
                    #
                    # update new clothes tag data
                    #
                    for my $tag_id ( ref($params{tag_id}) eq 'ARRAY' ? @{ $params{tag_id} } : ( $params{tag_id} ) ) {
                        my $clothes_tag = $DB->resultset('ClothesTag')->create({
                            clothes_code => $params{clothes_code},
                            tag_id       => $tag_id,
                        });
                        push @clothes_tags, $clothes_tag;
                    }
                }

                $guard->commit;

                return \@clothes_tags;
            }
            catch {
                chomp;
                my $err = $_;
                app->log->error("failed to delete & update the clothes_tag");

                no warnings 'experimental';

                my $status;
                given ($err) {
                    default { $status = 500 }
                }

                return ( undef, $status, $err );
            };
        };

        #
        # response
        #
        my $data = {};

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
        $v->field('category')->in( keys %{ app->config->{category} } );
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

    sub api_create_tag {
        my $self = shift;

        #
        # fetch params
        #
        my %params = $self->get_params(qw/ name /);

        #
        # validate params
        #
        my $v = $self->create_validator;
        $v->field('name')->required(1)->regexp(qr/^.+$/);
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

        my ( $tag, $status, $error ) = do {
            try {
                #
                # create tag
                #
                my $tag = $DB->resultset('Tag')->create( \%params );
                die "failed to create a new tag\n" unless $tag;

                return $tag;
            }
            catch {
                chomp;
                my $err = $_;

                no warnings 'experimental';
                given ($err) {
                    when ( /DBIx::Class::Storage::DBI::_dbh_execute\(\): DBI Exception:.*Duplicate entry.*for key 'name'/ ) {
                        $err = 'duplicate tag.name';
                    }
                }

                return ( undef, 400, $err );
            };
        };

        $self->error( $status, {
            str  => $error,
            data => {},
        }), return unless $tag;

        #
        # response
        #
        my %data = $tag->get_columns;

        $self->res->headers->header(
            'Location' => $self->url_for( '/api/tag/' . $tag->id ),
        );
        $self->respond_to( json => { status => 201, json => \%data } );
    }

    sub api_get_tag {
        my $self = shift;

        #
        # fetch params
        #
        my %params = $self->get_params(qw/ id /);

        #
        # validate params
        #
        my $v = $self->create_validator;
        $v->field('id')->required(1)->regexp(qr/^\d*$/);
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
        # find tag
        #
        my $tag = $DB->resultset('Tag')->find({ id => $params{id} });
        return $self->error( 404, {
            str  => 'tag not found',
            data => {},
        }) unless $tag;

        #
        # response
        #
        my %data = $tag->get_columns;

        $self->respond_to( json => { status => 200, json => \%data } );
    }

    sub api_update_tag {
        my $self = shift;

        #
        # fetch params
        #
        my %params = $self->get_params(qw/ id name /);

        #
        # validate params
        #
        my $v = $self->create_validator;
        $v->field('id')->required(1)->regexp(qr/^\d*$/);
        $v->field('name')->required(1)->regexp(qr/^.+$/);
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
        # TRANSACTION:
        #
        my ( $tag, $status, $error ) = do {
            my $guard = $DB->txn_scope_guard;
            try {
                #
                # find tag
                #
                my $tag = $DB->resultset('Tag')->find({ id => $params{id} });
                die "tag not found\n" unless $tag;

                #
                # update tag
                #
                delete $params{id};
                try {
                    $tag->update( \%params ) or die "failed to update the tag\n";
                }
                catch {
                    chomp;
                    my $err = $_;

                    no warnings 'experimental';
                    given ($err) {
                        when ( /DBIx::Class::Storage::DBI::_dbh_execute\(\): DBI Exception:.*Duplicate entry.*for key 'name'/ ) {
                            $err = 'duplicate tag.name';
                        }
                    }

                    die "$err\n";
                };

                $guard->commit;

                return $tag;
            }
            catch {
                chomp;
                my $err = $_;
                app->log->error("failed to find & update the tag");

                no warnings 'experimental';

                my $status;
                given ($err) {
                    $status = 404 when 'tag not found';
                    $status = 500 when 'failed to update the tag';
                    $status = 400 when 'duplicate tag.name';
                    default { $status = 500 }
                }

                return ( undef, $status, $err );
            };
        };

        #
        # response
        #
        $self->error( $status, {
            str  => $error,
            data => {},
        }), return unless $tag;

        #
        # response
        #
        my %data = $tag->get_columns;

        $self->respond_to( json => { status => 200, json => \%data } );
    }

    sub api_delete_tag {
        my $self = shift;

        #
        # fetch params
        #
        my %params = $self->get_params(qw/ id /);

        #
        # validate params
        #
        my $v = $self->create_validator;
        $v->field('id')->required(1)->regexp(qr/^\d*$/);
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
        # find tag
        #
        my $tag = $DB->resultset('Tag')->find({ id => $params{id} });
        return $self->error( 404, {
            str  => 'tag not found',
            data => {},
        }) unless $tag;

        #
        # delete tag
        #
        my %data = $tag->get_columns;
        $tag->delete;

        #
        # response
        #
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
            create_date
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
        my $donation;
        {
            my %_params = %params;
            if ( $_params{create_date} ) {
                $_params{create_date} = DateTime->from_epoch(
                    epoch     => $_params{create_date},
                    time_zone => app->config->{timezone},
                );
            }
            $donation = $DB->resultset('Donation')->create( \%_params );
            return $self->error( 500, {
                str  => 'failed to create a new donation',
                data => {},
            }) unless $donation;
        }

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

    sub api_create_sms {
        my $self = shift;

        #
        # fetch params
        #
        my %params = $self->get_params(qw/ to text status /);

        #
        # validate params
        #
        my $v = $self->create_validator;
        $v->field('to')->required(1)->regexp(qr/^\d+$/);
        $v->field('text')->required(1)->regexp(qr/^.+$/);
        $v->field('status')->in(qw/ pending sending sent /);

        unless ( $self->validate( $v, \%params ) ) {
            my @error_str;
            while ( my ( $k, $v ) = each %{ $v->errors } ) {
                push @error_str, "$k:$v";
            }
            $self->error( 400, {
                str  => join(',', @error_str),
                data => $v->errors,
            }), return;
        }

        my $sms = $DB->resultset('SMS')->create({
            %params,
            from => app->config->{sms}{from},
        });
        return $self->error( 404, {
            str  => 'failed to create a new sms',
            data => {},
        }) unless $sms;

        #
        # response
        #
        my %data = ( $sms->get_columns );

        $self->res->headers->header(
            'Location' => $self->url_for( '/api/sms/' . $sms->id ),
        );
        $self->respond_to( json => { status => 201, json => \%data } );
    }

    sub api_update_sms {
        my $self = shift;

        #
        # fetch params
        #
        my %params = $self->get_params(qw/ id from to text status /);

        #
        # validate params
        #
        my $v = $self->create_validator;
        $v->field('id')->required(1)->regexp(qr/^\d+$/);
        $v->field(qw/ from to /)
            ->each( sub { shift->regexp(qr/^\d+$/) } );
        $v->field('text')->regexp(qr/^.+$/);
        $v->field('status')->in(qw/ pending sending sent /);

        unless ( $self->validate( $v, \%params ) ) {
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
        # TRANSACTION:
        #
        my ( $sms, $status, $error ) = do {
            my $guard = $DB->txn_scope_guard;
            try {
                #
                # find sms
                #
                my $sms = $DB->resultset('SMS')->find({ id => $params{id} });
                die "sms not found\n" unless $sms;

                #
                # update sms
                #
                delete $params{id};
                $sms->update( \%params ) or die "failed to update the sms\n";

                $guard->commit;

                return $sms;
            }
            catch {
                chomp;
                my $err = $_;
                app->log->error("failed to find & update the sms");

                no warnings 'experimental';

                my $status;
                given ($err) {
                    $status = 404 when 'sms not found';
                    $status = 500 when 'failed to update the sms';
                    default { $status = 500 }
                }

                return ( undef, $status, $err );
            };
        };

        $self->error( $status, {
            str  => $error,
            data => {},
        }), return unless $sms;

        #
        # response
        #
        my %data = ( $sms->get_columns );

        $self->respond_to( json => { status => 200, json => \%data } );
    }

    sub api_create_sms_validation {
        my $self = shift;

        #
        # fetch params
        #
        my %params = $self->get_params(qw/ to /);

        #
        # validate params
        #
        my $v = $self->create_validator;
        $v->field('to')->required(1)->regexp(qr/^\d+$/);

        unless ( $self->validate( $v, \%params ) ) {
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
        # find user
        #
        my @users = $DB->resultset('User')->search(
            { 'user_info.phone' => $params{to} },
            { join => 'user_info' },
        );
        my $user = shift @users;

        return $self->error( 404, {
            str  => 'user not found',
            data => {},
        }) unless $user;
        return $self->error( 404, {
            str  => 'user info not found',
            data => {},
        }) unless $user->user_info;

        my $password = String::Random->new->randregex('\d\d\d\d\d\d');
        my $expires  = DateTime->now( time_zone => app->config->{timezone} )->add( minutes => 5 );
        $user->update({
            password => $password,
            expires  => $expires->epoch,
        }) or return $self->error( 500, {
            str  => 'failed to update a user',
            data => {},
        });
        app->log->debug( "sent temporary password: to($params{to}) password($password)" );

        my $sms = $DB->resultset('SMS')->create({
            %params,
            from => app->config->{sms}{from},
            text => "열린옷장 인증번호: $password",
        });
        return $self->error( 404, {
            str  => 'failed to create a new sms',
            data => {},
        }) unless $sms;

        #
        # response
        #
        my %data = ( $sms->get_columns );

        $self->res->headers->header(
            'Location' => $self->url_for( '/api/sms/' . $sms->id ),
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

    #
    # FIXME
    #   parameter is wired.
    #   but it seemed enough for opencloset now
    #
    sub api_search_late_user {
        my $self = shift;

        #
        # find user
        #
        my $now = $DB->storage->datetime_parser->format_datetime(
            DateTime->now( time_zone => app->config->{timezone} ),
        );
        my @users = $DB->resultset('User')->search(
            {
                -and => [
                    'order_users.target_date'      => { '<' => $now },
                    'order_users.user_target_date' => { '<' => $now },
                    'order_users.status_id'        => 2,
                ],
            },
            { join => 'order_users' },
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

    #
    # FIXME
    #   parameter is wired.
    #   but it seemed enough for opencloset now
    #
    sub api_search_donation {
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
        # gather donation
        #
        my @donations = map { $_->donations } @users;

        #
        # response
        #
        my @data;
        for my $donation (@donations) {
            my %user  = ( $donation->user->user_info->get_columns, $donation->user->get_columns );
            delete @user{qw/ user_id password /};

            my %inner = $donation->get_columns;
            delete @inner{qw/ user_id /};
            $inner{user}        = \%user;
            $inner{create_date} = {
                raw => $donation->create_date,
                md  => $donation->create_date->month . '/' . $donation->create_date->day,
                ymd => $donation->create_date->ymd
            };

            push @data, \%inner;
        }

        $self->respond_to( json => { status => 200, json => \@data } );
    }

    #
    # FIXME
    #   parameter is wired.
    #   but it seemed enough for opencloset now
    #
    sub api_search_sms {
        my $self = shift;

        #
        # fetch params
        #
        my %params = $self->get_params(qw/ status /);

        #
        # validate params
        #
        my $v = $self->create_validator;
        $v->field('status')->required(1);
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
        # find sms
        #
        my @sms_list = $DB->resultset('SMS')->search({ status => $params{status} });
        return $self->error( 404, {
            str  => 'sms not found',
            data => {},
        }) unless @sms_list;

        #
        # response
        #
        my @data;
        push @data, { $_->get_columns } for @sms_list;

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

    sub api_gui_update_booking {
        my $self = shift;

        #
        # fetch params
        #
        my %params = $self->get_params(qw/ id date slot gender /);

        #
        # validate params
        #
        my $v = $self->create_validator;
        $v->field('id')->required(1)->regexp(qr/^\d+$/);
        $v->field('slot')->regexp(qr/^\d+$/);
        $v->field('gender')->in(qw/ male female /);
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
        # find booking
        #
        my $booking = $DB->resultset('Booking')->find({ id => $params{id} });
        return $self->error( 404, {
            str  => 'booking not found',
            data => {},
        }) unless $booking;

        #
        # update booking
        #
        my %_params = %params;
        delete $_params{id};

        $booking->update( \%_params )
            or return $self->error( 500, {
                str  => 'failed to update a booking',
                data => {},
            });

        #
        # response
        #
        my $data = $self->flatten_booking($booking);

        $self->respond_to( json => { status => 200, json => $data } );
    }

    sub api_gui_booking_list {
        my $self = shift;

        #
        # fetch params
        #
        my %params = $self->get_params(qw/ gender /);

        #
        # validate params
        #
        my $v = $self->create_validator;
        $v->field('gender')->in(qw/ male female /);
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
        # find booking
        #
        my $dt_start = DateTime->now( time_zone => app->config->{timezone} );
        unless ($dt_start) {
            my $msg = "cannot create start datetime object";
            app->log->warn($msg);
            $self->error( 500, {
                str  => $msg,
                data => {},
            });
            return;
        }

        my $dt_end = $dt_start->clone->truncate( to => 'day' )->add( hours => 24 * 15, seconds => -1 );
        unless ($dt_end) {
            my $msg = "cannot create end datetime object";
            app->log->warn($msg);
            $self->error( 500, {
                str  => $msg,
                data => {},
            });
            return;
        }

        #
        # SELECT
        #     `me`.`id`,
        #     `me`.`date`,
        #     `me`.`gender`,
        #     `me`.`slot`,
        #     COUNT( `user`.`id` ) AS `user_count`
        # FROM `booking` `me`
        # LEFT JOIN `order` `orders`
        #     ON `orders`.`booking_id` = `me`.`id`
        # LEFT JOIN `user` `user`
        #     ON `user`.`id` = `orders`.`user_id`
        # WHERE (
        #     ( `me`.`date` BETWEEN ? AND ? )
        #     AND `me`.`gender` = ?
        #     AND `me`.`id` IS NOT NULL
        # )
        # GROUP BY `me`.`id` HAVING COUNT(user.id) < me.slot
        # ORDER BY `me`.`date` ASC
        #
        # http://stackoverflow.com/questions/5285448/mysql-select-only-not-null-values
        # https://metacpan.org/pod/DBIx::Class::Manual::Joining#Across-multiple-relations
        #
        my $dtf        = $DB->storage->datetime_parser;
        my $booking_rs = $DB->resultset('Booking')->search(
            {
                'me.id'     => { '!=' => undef },
                'me.gender' => $params{gender},
                'me.date'   => {
                    -between => [
                        $dtf->format_datetime($dt_start),
                        $dtf->format_datetime($dt_end),
                    ],
                },
            },
            {
                '+columns' => [
                    { user_count => { count => 'user.id', -as => 'user_count' } },
                ],
                join       => { 'orders' => 'user' },
                group_by   => [ qw/ me.id / ],
                having     => \[ 'COUNT(user.id) < me.slot' ],
                order_by   => { -asc => 'me.date' },
            },
        );

        my @booking_list = $booking_rs->all;
        return $self->error( 404, {
            str  => 'booking list not found',
            data => {},
        }) unless @booking_list;

        #
        # additional information for clothes list
        #
        my @data;
        push @data, $self->flatten_booking($_) for @booking_list;

        #
        # response
        #
        $self->respond_to( json => { status => 200, json => \@data } );
    }

    sub api_gui_utf8_gcs_columns {
        my $self = shift;

        #
        # fetch params
        #
        my %params = $self->get_params(qw/ str /);

        #
        # validate params
        #
        my $v = $self->create_validator;
        $v->field('str')->required(1);
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

        my $val = $params{str};

        my $nfc  = NFC($val);
        my $gcs  = Unicode::GCString->new($nfc);
        my $cols = $gcs->columns;

        #
        # response
        #
        my $data = { ret => $cols };

        $self->respond_to( json => { status => 200, json => $data } );
    }

    sub api_gui_timetable {
        my $self = shift;

        #
        # fetch params
        #
        my %params = $self->get_params(qw/ ymd /);

        #
        # validate params
        #
        my $v = $self->create_validator;
        $v->field('ymd')->required(1)->callback(sub {
            my $val = shift;

            unless ( $val =~ m/^(\d{4})-(\d{2})-(\d{2})$/ ) {
                my $msg = "invalid ymd format: $params{ymd}";
                app->log->warn($msg);
                return ( 0, $msg );
            }

            my $dt = try {
                DateTime->new(
                    time_zone => app->config->{timezone},
                    year      => $1,
                    month     => $2,
                    day       => $3,
                );
            };
            unless ($dt) {
                my $msg = "cannot create start datetime object: $params{ymd}";
                app->log->warn($msg);
                return ( 0, $msg );
            }

            return 1;
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

        $params{ymd} =~ m/^(\d{4})-(\d{2})-(\d{2})$/;
        my $dt_start = DateTime->new(
            time_zone => app->config->{timezone},
            year      => $1,
            month     => $2,
            day       => $3,
        );
        my $dt_end = $dt_start->clone->add( hours => 24, seconds => -1 );

        my $dtf        = $DB->storage->datetime_parser;
        my $booking_rs = $DB->resultset('Booking')->search(
            {
                date => {
                    -between => [
                        $dtf->format_datetime($dt_start),
                        $dtf->format_datetime($dt_end),
                    ],
                },
            },
            {
                order_by => { -asc => 'date' },
            },
        );

        my %count = (
            all        => 0,
            visited    => 0,
            notvisited => 0,
        );
        while ( my $booking = $booking_rs->next ) {
            for my $order ( $booking->orders ) {
                ++$count{all};
                use feature qw( switch );
                use experimental qw( smartmatch );
                given ( $order->status_id ) {
                    ++$count{notvisited} when 12;
                    ++$count{notvisited} when 14;
                }
            }
        }
        $count{visited} = $count{all} - $count{notvisited};

        $self->respond_to( json => { status => 200, json => \%count } );

    }

    sub api_postcode_search {
        my $self   = shift;
        my $q      = $self->param('q');
        my $p      = Postcodify->new( config => $ENV{MOJO_CONFIG} || './app.psgi.conf' );
        my $result = $p->search( $q );
        $self->render(text => decode_utf8($result->json), format => 'json');
    }

}; # end of API section

under '/' => sub {
    my $self = shift;

    my $req_path = $self->req->url->path;
    return 1 if $self->is_user_authenticated;
    return 1 if $req_path eq '/login';
    return 1 if $req_path eq '/visit';

    $self->redirect_to( $self->url_for('/visit') );

    return;
};

get '/login';
post '/login' => sub {
    my $self = shift;

    my $username = $self->param('email');
    my $password = $self->param('password');
    my $remember = $self->param('remember');

    if ( $self->authenticate($username, $password) ) {
        $self->session->{expiration} = $remember ? $self->app->config->{expire}{remember} : $self->app->config->{expire}{default},
        $self->redirect_to( $self->url_for('/') );
    }
    else {
        $self->flash(error => 'Failed to Authentication');
        $self->redirect_to( $self->url_for('/login') );
    }
};

get '/logout' => sub {
    my $self = shift;

    $self->logout;
    $self->redirect_to( $self->url_for('/login') );
};

any '/visit' => sub {
    my $self = shift;

    my $type    = $self->param('type') || q{};
    my $name    = $self->param('name');
    my $phone   = $self->param('phone');
    my $service = $self->param('service');
    my $privacy = $self->param('privacy');
    my $sms     = $self->param('sms');

    my $email         = $self->param('email');
    my $gender        = $self->param('gender');
    my $address1      = $self->param('address1');
    my $address2      = $self->param('address2');
    my $address3      = $self->param('address3');
    my $address4      = $self->param('address4');
    my $birth         = $self->param('birth');
    my $height        = $self->param('height');
    my $weight        = $self->param('weight');
    my $booking       = $self->param('booking');
    my $booking_saved = $self->param('booking-saved');
    my $purpose       = $self->param('purpose');
    my $purpose2      = $self->param('purpose2');

    app->log->debug("type: $type");
    app->log->debug("name: $name");
    app->log->debug("phone: $phone");
    app->log->debug("service: $service");
    app->log->debug("privacy: $privacy");
    app->log->debug("sms: $sms");

    app->log->debug("email: $email");
    app->log->debug("gender: $gender");
    app->log->debug("address1: $address1");
    app->log->debug("address2: $address2");
    app->log->debug("address3: $address3");
    app->log->debug("address4: $address4");
    app->log->debug("birth: $birth");
    app->log->debug("height: $height");
    app->log->debug("weight: $weight");
    app->log->debug("booking: $booking");
    app->log->debug("booking-saved: $booking_saved");
    app->log->debug("purpose: $purpose");
    app->log->debug("purpose2: $purpose2");

    #
    # find user
    #
    my @users = $DB->resultset('User')->search(
        {
            'me.name'         => $name,
            'user_info.phone' => $phone,
        },
        { join => 'user_info' },
    );
    my $user = shift @users;
    unless ($user) {
        app->log->warn( 'user not found' );
        return;
    }
    unless ($user->user_info) {
        app->log->warn( 'user_info not found' );
        return;
    }

    #
    # validate code
    #
    my $now = DateTime->now( time_zone => app->config->{timezone} )->epoch;
    unless ( $user->expires && $user->expires > $now ) {
        app->log->warn( $user->email . "\'s password is expired" );
        $self->stash( alert => '인증코드가 만료되었습니다.' );
        return;
    }
    unless ( $user->check_password($sms) ) {
        app->log->warn( $user->email . "\'s password is wrong" );
        $self->stash( alert => '인증코드가 유효하지 않습니다.' );
        return;
    }

    if ( $type eq 'visit' ) {
        #
        # 예약 신청/변경/취소
        #

        my %user_params;
        my %user_info_params;

        $user_params{id}            = $user->id;
        $user_params{email}         = $email    if $email    && $email    ne $user->email;
        $user_info_params{gender}   = $gender   if $gender   && $gender   ne $user->user_info->gender;
        $user_info_params{address1} = $address1 if $address1 && $address1 ne $user->user_info->address1;
        $user_info_params{address2} = $address2 if $address2 && $address2 ne $user->user_info->address2;
        $user_info_params{address3} = $address3 if $address3 && $address3 ne $user->user_info->address3;
        $user_info_params{address4} = $address4 if $address4 && $address4 ne $user->user_info->address4;
        $user_info_params{birth}    = $birth    if $birth    && $birth    ne $user->user_info->birth;
        $user_info_params{height}   = $height   if $height   && $height   ne $user->user_info->height;
        $user_info_params{weight}   = $weight   if $weight   && $weight   ne $user->user_info->weight;
        $user_info_params{purpose}  = $purpose  if $purpose  && $purpose  ne $user->user_info->purpose;
        $user_info_params{purpose2} = $purpose2 || q{};

        if ( $booking == -1 ) {
            #
            # 예약 취소
            #
            my $order = $user->find_related( 'orders', { booking_id => $booking_saved } );

            my $msg = sprintf(
                "%s님 %s 방문 예약이 취소되었습니다.",
                $user->name,
                $order->booking->date->strftime('%m월 %d일 %H시 %M분'),
            );
            $DB->resultset('SMS')->create({
                to   => $user->user_info->phone,
                from => app->config->{sms}{from},
                text => $msg,
            }) or app->log->warn("failed to create a new sms: $msg");

            $order->delete if $order;
        }
        else {
            $user = $self->update_user( \%user_params, \%user_info_params );
            if ($booking_saved) {
                #
                # 이미 예약 정보가 저장되어 있는 경우 - 예약 변경 상황
                #
                my $order = $user->find_related( 'orders', { booking_id => $booking_saved } );
                if ( $booking != $booking_saved ) {
                    #
                    # 변경한 예약 정보가 기존 정보와 다를 경우 갱신함
                    #
                    $order->update({ booking_id => $booking }) if $order;
                }

                my $msg = sprintf(
                    "%s님 %s으로 방문 예약이 변경되었습니다.",
                    $user->name,
                    $order->booking->date->strftime('%m월 %d일 %H시 %M분'),
                );
                $DB->resultset('SMS')->create({
                    to   => $user->user_info->phone,
                    from => app->config->{sms}{from},
                    text => $msg,
                }) or app->log->warn("failed to create a new sms: $msg");
            }
            else {
                #
                # 예약 정보가 없는 경우 - 신규 예약 신청 상황
                #
                my $order = $user->create_related('orders', {
                    status_id  => 14,      # 방문예약: status 테이블 참조
                    booking_id => $booking,
                });

                my $msg = sprintf(
                    "%s님 %s으로 방문 예약이 완료되었습니다.",
                    $user->name,
                    $order->booking->date->strftime('%m월 %d일 %H시 %M분'),
                );
                $DB->resultset('SMS')->create({
                    to   => $user->user_info->phone,
                    from => app->config->{sms}{from},
                    text => $msg,
                }) or app->log->warn("failed to create a new sms: $msg");
            }
        }
    }

    my $booking_obj = do {
        my $dt_now = DateTime->now( time_zone => app->config->{timezone} );
        my $dtf    = $DB->storage->datetime_parser;
        my $rs     = $user->search_related('orders')->search_related('booking', {
            date => { '>' => $dtf->format_datetime($dt_now) },
        });

        $rs->next;
    };

    $self->stash(
        type     => $type,
        user     => $user,
        sms      => $sms,
        booking  => $booking_obj,
    );
};

get '/'            => 'home';
get '/new-clothes' => 'new-clothes';

get '/tag' => sub {
    my $self = shift;

    #
    # response
    #
    $self->stash( 'tag_rs' => $DB->resultset('Tag') );
};

get '/user' => sub {
    my $self = shift;

    #
    # fetch params
    #
    my %params = $self->get_params(qw/ id /);

    my $p = $self->param('p') || 1;
    my $s = $self->param('s') || app->config->{entries_per_page};
    my $q = $self->param('q');
    my $cond = $q
        ? [
        { 'name'               => { like => "%$q%" } },
        { 'email'              => { like => "%$q%" } },
        { 'user_info.phone'    => { like => "%$q%" } },
        { 'user_info.address4' => { like => "%$q%" } },    # 상세주소만 검색
        { 'user_info.birth'    => { like => "%$q%" } },
        { 'user_info.gender'   => $q },
        ]
        : {};

    my $rs = $self->get_user_list({
        %params,
        allow_empty => 1,
    });
    $rs = $rs->search(
        $cond,
        {
            join     => 'user_info',
            order_by => { -asc => 'id' },
            page     => $p,
            rows     => $s,
        },
    );

    my $pageset = Data::Pageset->new({
        total_entries    => $rs->pager->total_entries,
        entries_per_page => $rs->pager->entries_per_page,
        pages_per_set    => 5,
        current_page     => $p,
    });

    #
    # response
    #
    $self->stash(
        user_list => $rs,
        pageset   => $pageset,
        q         => $q || q{},
    );
    $self->respond_to( html => { status => 200 } );
};

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
    $rented_clothes_count += $_->clothes->count for $user->orders;

    #
    # response
    #
    $self->stash(
        user                  => $user,
        donated_clothes_count => $donated_clothes_count,
        rented_clothes_count  => $rented_clothes_count,
    );
} => 'user-id';

get '/clothes' => sub {
    my $self = shift;

    #
    # fetch params
    #
    my %params = $self->get_params(qw/ status /);

    #
    # validate params
    #
    my $v = $self->create_validator;
    $v->field('status')->regexp(qr/^\d+$/);
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
    # count for each status
    #
    my $count_rs = $DB->resultset('Clothes')->search(
        undef,
        {
            select   => [ 'status_id', { count => 'me.status_id' } ],
            as       => [ qw/ id count / ],
            group_by => [ qw/ status_id / ],
            order_by => [ qw/ status_id / ],
        },
    );

    my %status = (
        all => $DB->resultset('Clothes')->count,
        1   => 0,
        2   => 0,
        3   => 0,
        4   => 0,
        5   => 0,
        6   => 0,
        7   => 0,
        8   => 0,
        9   => 0,
        11  => 0,
    );
    while ( my $s = $count_rs->next ) {
        my $id    = $s->get_column('id');
        my $count = $s->get_column('count');
        $status{$id} = $count;
    }

    #
    # search clothes
    #
    my $p      = $self->param('p') || 1;
    my $s      = $self->param('s') || app->config->{entries_per_page};
    my $status = $self->param('status');

    my $cond = $status ? { 'status_id' => $status } : {};
    my $rs = $DB->resultset('Clothes')->search(
        $cond,
        {
            order_by => { -asc => 'id' },
            page     => $p,
            rows     => $s,
        },
    );

    my $pageset = Data::Pageset->new({
        total_entries    => $rs->pager->total_entries,
        entries_per_page => $rs->pager->entries_per_page,
        pages_per_set    => 5,
        current_page     => $p,
    });

    #
    # response
    #
    $self->stash(
        status       => \%status,
        clothes_list => $rs,
        pageset      => $pageset,
    );
} => 'clothes';

get '/clothes/:code' => sub {
    my $self = shift;

    #
    # fetch params
    #
    my %params = $self->get_params(qw/ code /);

    my $clothes = $self->get_clothes( \%params );
    return unless $clothes;

    my $rented_count = 0;
    my @measurements = qw(
        height
        weight
        bust
        waist
        hip
        belly
        thigh
        arm
        leg
        knee
        foot
    );
    my %average_size = map { $_ => [] } @measurements;
    for my $order_detail ( $clothes->order_details->search({ status_id => { '!=' => undef } }) ) {
        ++$rented_count;
        for (@measurements) {
            next unless $order_detail->order->$_;
            push @{ $average_size{$_} }, $order_detail->order->$_;
        }
    }
    for (@measurements) {
        if ( @{ $average_size{$_} } ) {
            $average_size{$_} = ( sum @{ $average_size{$_} } ) / @{ $average_size{$_} };
        }
        else {
            $average_size{$_} = 0;
        }
    }

    #
    # response
    #
    $self->stash(
        average_size => \%average_size,
        clothes      => $clothes,
        rented_count => $rented_count,
        tag_rs       => $DB->resultset('Tag'),
    );
} => 'clothes-code';

get '/rental' => sub {
    my $self = shift;

    my $dt_today = DateTime->now( time_zone => app->config->{timezone} );
    $self->redirect_to( $self->url_for( '/rental/' . $dt_today->ymd ) );
};

get '/rental/:ymd' => sub {
    my $self = shift;

    #
    # fetch params
    #
    my %params = $self->get_params(qw/ ymd /);

    unless ( $params{ymd} ) {
        app->log->warn( "ymd is required" );
        $self->redirect_to( $self->url_for('/rental') );
        return;
    }

    unless ( $params{ymd} =~ m/^(\d{4})-(\d{2})-(\d{2})$/ ) {
        app->log->warn( "invalid ymd format: $params{ymd}" );
        $self->redirect_to( $self->url_for('/rental') );
        return;
    }

    my $dt_start = try {
        DateTime->new(
            time_zone => app->config->{timezone},
            year      => $1,
            month     => $2,
            day       => $3,
        );
    };
    unless ($dt_start) {
        app->log->warn( "cannot create start datetime object" );
        $self->redirect_to( $self->url_for('/rental') );
        return;
    }

    my $dt_end = $dt_start->clone->add( hours => 24, seconds => -1 );
    unless ($dt_end) {
        app->log->warn( "cannot create end datetime object" );
        $self->redirect_to( $self->url_for('/rental') );
        return;
    }

    my $dtf      = $DB->storage->datetime_parser;
    my $order_rs = $DB->resultset('Order')->search(
        {
            'booking.date' => {
                -between => [
                    $dtf->format_datetime($dt_start),
                    $dtf->format_datetime($dt_end),
                ],
            },
        },
        {
            join     => 'booking',
            order_by => { -asc => 'booking.date' },
        },
    );

    $self->stash(
        order_rs => $order_rs,
        dt_start => $dt_start,
        dt_end   => $dt_end,
    );
} => 'rental';

get '/order' => sub {
    my $self = shift;

    #
    # fetch params
    #
    my %params        = $self->get_params(qw/ id /);
    my %search_params = $self->get_params(qw/ status /);

    my $rs = $self->get_order_list({
        %params,
        allow_empty => 1,
    });

    #
    # undef       => '상태없음'
    # late        => '연체중'
    # rental-late => '대여중(연체아님)'
    #
    # 1     =>  '대여가능'
    # 2     =>  '대여중'
    # 3     =>  '대여불가'
    # 4     =>  '예약'
    # 5     =>  '세탁'
    # 6     =>  '수선'
    # 7     =>  '분실'
    # 8     =>  '폐기'
    # 9     =>  '반납'
    # 10    =>  '부분반납'
    # 11    =>  '반납배송중'
    # 12    =>  '미방문'
    # 13    =>  '방문'
    # 14    =>  '방문예약'
    # 15    =>  '배송예약'
    #

    {
        no warnings 'experimental';
        my $status_id = $search_params{status};
        my %cond;
        given ($status_id) {
            when ('undef') {
                %cond = ( status_id => { '=' => undef },);
            }
            when ('late') {
                %cond = (
                    -and => [
                        status_id   => 2,
                        target_date => { '<' => DateTime->now },
                    ],
                );
            }
            when ('rental-late') {
                %cond = (
                    -and => [
                        status_id   => $status_id,
                        target_date => { '>=' => DateTime->now },
                    ],
                );
            }
            default {
                my @valid = 1 .. 15;
                %cond = ( status_id => $status_id ) if $status_id ~~ @valid;
            }
        }
        $rs = $rs->search(\%cond);
    }

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
    my %order_params        = $self->get_params(qw/ id /);
    my %order_detail_params = $self->get_params(qw/ clothes_code /);

    #
    # adjust params
    #
    if ( $order_detail_params{clothes_code} ) {
        $order_detail_params{clothes_code} = [ $order_detail_params{clothes_code} ]
            unless ref $order_detail_params{clothes_code};

        for ( @{ $order_detail_params{clothes_code} } ) {
            next unless length == 4;
            $_ = sprintf( '%05s', $_ );
        }
    }

    my ( $order, $error ) = do {
        my $guard = $DB->txn_scope_guard;
        try {
            #
            # find order
            #
            my $order = $DB->resultset('Order')->find( $order_params{id} );
            die "order not found: $order_params{id}\n" unless $order;

            for ( my $i = 0; $i < @{ $order_detail_params{clothes_code} }; ++$i ) {
                my $clothes_code = $order_detail_params{clothes_code}[$i];
                my $clothes      = $DB->resultset('Clothes')->find({ code => $clothes_code });

                die "clothes not found: $clothes_code\n" unless $clothes;

                my $name = join(
                    q{ - },
                    $self->trim_clothes_code($clothes),
                    app->config->{category}{ $clothes->category }{str},
                );

                $order->add_to_order_details({
                    clothes_code => $clothes->code,
                    name         => $name,
                    price        => $clothes->price,
                    final_price  => $clothes->price,
                }) or die "failed to create a new order_detail\n";
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
            app->log->error("failed to update the order & create a new order_detail");
            app->log->error($_);
            return ( undef, $_ );
        }
    };
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

get '/booking' => sub {
    my $self = shift;

    my $dt_today = DateTime->now( time_zone => app->config->{timezone} );
    $self->redirect_to( $self->url_for( '/booking/' . $dt_today->ymd ) );
};

get '/booking/:ymd' => sub {
    my $self = shift;

    #
    # fetch params
    #
    my %params = $self->get_params(qw/ ymd /);

    unless ( $params{ymd} ) {
        app->log->warn( "ymd is required" );
        $self->redirect_to( $self->url_for('/booking') );
        return;
    }

    unless ( $params{ymd} =~ m/^(\d{4})-(\d{2})-(\d{2})$/ ) {
        app->log->warn( "invalid ymd format: $params{ymd}" );
        $self->redirect_to( $self->url_for('/booking') );
        return;
    }

    my $dt_start = try {
        DateTime->new(
            time_zone => app->config->{timezone},
            year      => $1,
            month     => $2,
            day       => $3,
        );
    };
    unless ($dt_start) {
        app->log->warn( "cannot create start datetime object" );
        $self->redirect_to( $self->url_for('/booking') );
        return;
    }

    my $dt_end = $dt_start->clone->add( hours => 24, seconds => -1 );
    unless ($dt_end) {
        app->log->warn( "cannot create end datetime object" );
        $self->redirect_to( $self->url_for('/booking') );
        return;
    }

    my $dtf        = $DB->storage->datetime_parser;
    my $booking_rs = $DB->resultset('Booking')->search(
        {
            date => {
                -between => [
                    $dtf->format_datetime($dt_start),
                    $dtf->format_datetime($dt_end),
                ],
            },
        },
        {
            order_by => { -asc => 'date' },
        },
    );

    $self->render(
        'booking',
        booking_rs => $booking_rs,
        dt_start   => $dt_start,
        dt_end     => $dt_end,
    );
};

get '/booking/:ymd/open' => sub {
    my $self = shift;

    #
    # fetch params
    #
    my %params = $self->get_params(qw/ ymd /);

    unless ( $params{ymd} ) {
        app->log->warn( "ymd is required" );
        $self->redirect_to( $self->url_for('/booking') );
        return;
    }

    unless ( $params{ymd} =~ m/^(\d{4})-(\d{2})-(\d{2})$/ ) {
        app->log->warn( "invalid ymd format: $params{ymd}" );
        $self->redirect_to( $self->url_for('/booking') );
        return;
    }

    my $dt_start = try {
        DateTime->new(
            time_zone => app->config->{timezone},
            year      => $1,
            month     => $2,
            day       => $3,
        );
    };
    unless ($dt_start) {
        app->log->warn( "cannot create start datetime object" );
        $self->redirect_to( $self->url_for('/booking') );
        return;
    }

    for my $gender ( qw/ male female / ) {
        for my $key ( sort keys %{ app->config->{booking}{$gender} } ) {
            my $value = app->config->{booking}{$gender}{$key};

            my ( $h, $m ) = split /:/, $key, 2;
            my $dt = $dt_start->clone;
            $dt->set_hour($h);
            $dt->set_minute($m);

            my $dtf = $DB->storage->datetime_parser;
            $DB->resultset('Booking')->find_or_create({
                date   => $dtf->format_datetime($dt),
                gender => $gender,
                slot   => $value,
            });
        }
    }

    $self->redirect_to( $self->url_for( '/booking/' . $dt_start->ymd ) );
};

get '/timetable' => sub {
    my $self = shift;

    my $dt_today = DateTime->now( time_zone => app->config->{timezone} );
    $self->redirect_to( $self->url_for( '/timetable/' . $dt_today->ymd ) );
};

get '/timetable/:ymd' => sub {
    my $self = shift;

    #
    # fetch params
    #
    my %params = $self->get_params(qw/ ymd /);

    unless ( $params{ymd} ) {
        app->log->warn( "ymd is required" );
        $self->redirect_to( $self->url_for('/timetable') );
        return;
    }

    unless ( $params{ymd} =~ m/^(\d{4})-(\d{2})-(\d{2})$/ ) {
        app->log->warn( "invalid ymd format: $params{ymd}" );
        $self->redirect_to( $self->url_for('/timetable') );
        return;
    }

    my $dt_start = try {
        DateTime->new(
            time_zone => app->config->{timezone},
            year      => $1,
            month     => $2,
            day       => $3,
        );
    };
    unless ($dt_start) {
        app->log->warn( "cannot create start datetime object" );
        $self->redirect_to( $self->url_for('/timetable') );
        return;
    }

    my $dt_end = $dt_start->clone->add( hours => 24, seconds => -1 );
    unless ($dt_end) {
        app->log->warn( "cannot create end datetime object" );
        $self->redirect_to( $self->url_for('/timetable') );
        return;
    }

    my $dtf        = $DB->storage->datetime_parser;
    my $booking_rs = $DB->resultset('Booking')->search(
        {
            date => {
                -between => [
                    $dtf->format_datetime($dt_start),
                    $dtf->format_datetime($dt_end),
                ],
            },
        },
        {
            order_by => { -asc => 'date' },
        },
    );

    $self->render(
        'timetable',
        booking_rs => $booking_rs,
        dt_start   => $dt_start,
        dt_end     => $dt_end,
    );
};

get '/sms' => sub {
    my $self = shift;

    my %params = $self->get_params(qw/ to msg /);

    my $sender = SMS::Send->new(
        'KR::CoolSMS',
        _api_key    => app->config->{sms}{api_key},
        _api_secret => app->config->{sms}{api_secret},
        _from       => app->config->{sms}{from},
    );
    my $balance = $sender->balance;

    $self->stash(
        to      => $params{to}  || q{},
        msg     => $params{msg} || q{},
        balance => $balance->{success} ? $balance->{detail} : { cash => 0, point => 0 },
    );
};

app->secrets( app->defaults->{secrets} );
app->start;
