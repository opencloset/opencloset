package OpenCloset::Web::Plugin::Helpers;

use Mojo::Base 'Mojolicious::Plugin';

use Crypt::Mode::ECB;
use DateTime::Format::Duration;
use DateTime::Format::Human::Duration;
use DateTime::Format::Strptime;
use DateTime;
use Gravatar::URL;
use HTTP::Tiny;
use List::MoreUtils qw( zip );
use List::Util qw/any uniq/;
use Mojo::ByteStream;
use Mojo::DOM::HTML;
use Mojo::JSON qw/encode_json/;
use Mojo::Redis2;
use Parcel::Track;
use Statistics::Basic;
use Try::Tiny;

use OpenCloset::Calculator::LateFee;
use OpenCloset::Common::Unpaid ();
use OpenCloset::Size::Guess;
use OpenCloset::Constants::Measurement;
use OpenCloset::Constants::Category qw/$JACKET $PANTS $SKIRT/;
use OpenCloset::Constants::Status
    qw/$RENTABLE $RENTAL $PAYMENT $RESERVATED $PAYBACK/;

=encoding utf8

=head1 NAME

OpenCloset::Web::Plugin::Helpers - opencloset web mojo helper

=head1 SYNOPSIS

    # Mojolicious::Lite
    plugin 'OpenCloset::Web::Plugin::Helpers';

    # Mojolicious
    $self->plugin('OpenCloset::Web::Plugin::Helpers');

=cut

sub register {
    my ( $self, $app, $conf ) = @_;

    $app->helper( log => sub { shift->app->log } );
    $app->helper( error                    => \&error );
    $app->helper( meta_link                => \&meta_link );
    $app->helper( meta_text                => \&meta_text );
    $app->helper( get_gravatar             => \&get_gravatar );
    $app->helper( trim_clothes_code        => \&trim_clothes_code );
    $app->helper( order_clothes_price      => \&order_clothes_price );
    $app->helper( flatten_user             => \&flatten_user );
    $app->helper( tracking_url             => \&tracking_url );
    $app->helper( order_price              => \&order_price );
    $app->helper( flatten_order            => \&flatten_order );
    $app->helper( flatten_order_detail     => \&flatten_order_detail );
    $app->helper( flatten_clothes          => \&flatten_clothes );
    $app->helper( flatten_booking          => \&flatten_booking );
    $app->helper( get_params               => \&get_params );
    $app->helper( get_user                 => \&get_user );
    $app->helper( update_user              => \&update_user );
    $app->helper( get_user_list            => \&get_user_list );
    $app->helper( create_order             => \&create_order );
    $app->helper( get_order                => \&get_order );
    $app->helper( update_order             => \&update_order );
    $app->helper( delete_order             => \&delete_order );
    $app->helper( get_order_list           => \&get_order_list );
    $app->helper( create_order_detail      => \&create_order_detail );
    $app->helper( get_clothes              => \&get_clothes );
    $app->helper( get_nearest_booked_order => \&get_nearest_booked_order );
    $app->helper( convert_sec_to_locale    => \&convert_sec_to_locale );
    $app->helper( convert_sec_to_hms       => \&convert_sec_to_hms );
    $app->helper( phone_format             => \&phone_format );
    $app->helper( user_avg_diff            => \&user_avg_diff );
    $app->helper( user_avg2                => \&user_avg2 );
    $app->helper( count_visitor            => \&count_visitor );
    $app->helper( is_nonpaid               => \&is_nonpaid );
    $app->helper( coupon2label             => \&coupon2label );
    $app->helper( measurement2text         => \&measurement2text );
    $app->helper( decrypt_mbersn           => \&decrypt_mbersn );
    $app->helper( redis                    => \&redis );
    $app->helper( calc_late_fee            => \&calc_late_fee );
    $app->helper( calc_overdue             => \&calc_overdue );
    $app->helper( calc_extension_fee       => \&calc_extension_fee );
    $app->helper( calc_extension_days      => \&calc_extension_days );
    $app->helper( calc_overdue_fee         => \&calc_overdue_fee );
    $app->helper( calc_overdue_days        => \&calc_overdue_days );
    $app->helper( search_clothes           => \&search_clothes );
    $app->helper( clothes2link             => \&clothes2link );
    $app->helper( is_suit_order            => \&is_suit_order );
    $app->helper( choose_value_by_range    => \&choose_value_by_range );
    $app->helper( mean_status              => \&mean_status );
    $app->helper( booking_list             => \&booking_list );
    $app->helper( create_vbank             => \&create_vbank );
}

=head1 HELPERS

=head2 error( $status, $error )

=cut

sub error {
    my ( $self, $status, $error, $template ) = @_;

    $self->app->log->error( $error->{str} );
    $self->log->debug($template);

    unless ($template) {
        no warnings 'experimental';
        given ($status) {
            $template = 'bad_request' when 400;
            $template = 'not_found' when 404;
            $template = 'exception' when 500;
            default { $template = 'unknown' }
        }
    }

    $self->respond_to(
        json => { status => $status, json => { error => $error || q{} } },
        html => { status => $status, error => $error->{str} || q{}, template => $template },
    );

    return;
}

=head2 meta_link( $id )

=cut

sub meta_link {
    my ( $self, $id ) = @_;

    my $meta = $self->config->{sidebar}{meta};

    return $meta->{$id}{link} || $id;
}

=head2 meta_text( $id )

=cut

sub meta_text {
    my ( $self, $id ) = @_;

    my $meta = $self->config->{sidebar}{meta};

    return $meta->{$id}{text};
}

=head2 get_gravatar( $user, $size, %opts )

=cut

sub get_gravatar {
    my ( $self, $user, $size, %opts ) = @_;

    $opts{default} ||= $self->config->{avatar_icon};
    $opts{email}   ||= $user->email;
    $opts{size}    ||= $size;

    my $url = Gravatar::URL::gravatar_url(%opts);

    return $url;
}

=head2 trim_clothes_code( $clothes )

=cut

sub trim_clothes_code {
    my ( $self, $clothes ) = @_;

    my $code = $clothes->code;
    $code =~ s/^0//;

    return $code;
}

=head2 order_clothes_price( $order )

=cut

sub order_clothes_price {
    my ( $self, $order ) = @_;

    return 0 unless $order;

    my $price = 0;
    for ( $order->order_details ) {
        next unless $_->clothes;
        $price += $_->price;
    }

    return $price;
}

=head2 calc_extension_days( $order, $today )

연장일

=cut

sub calc_extension_days {
    my ( $self, $order, $today ) = @_;
    my $calc = OpenCloset::Calculator::LateFee->new;
    return $calc->extension_days( $order, $today );
}

=head2 calc_overdue_days( $order, $today )

연체일

=cut

sub calc_overdue_days {
    my ( $self, $order, $today ) = @_;
    my $calc = OpenCloset::Calculator::LateFee->new;
    return $calc->overdue_days( $order, $today );
}

=head2 calc_overdue( $order, $today )

연체일 + 연장일

=cut

sub calc_overdue {
    my ( $self, $order, $today ) = @_;

    my $calc = OpenCloset::Calculator::LateFee->new;
    my $days = $calc->overdue_days( $order, $today );
    return $days + $calc->extension_days( $order, $today );
}

=head2 calc_extension_fee( $order, $today )

연장비

=cut

sub calc_extension_fee {
    my ( $self, $order, $today ) = @_;

    my $calc = OpenCloset::Calculator::LateFee->new;
    return $calc->extension_fee( $order, $today );
}

=head2 calc_overdue_fee( $order, $today )

연체비

=cut

sub calc_overdue_fee {
    my ( $self, $order, $today ) = @_;
    my $calc = OpenCloset::Calculator::LateFee->new;
    return $calc->overdue_fee( $order, $today );
}

=head2 calc_late_fee( $order, $today )

연체비 + 연장비

=cut

sub calc_late_fee {
    my ( $self, $order, $today ) = @_;

    my $calc = OpenCloset::Calculator::LateFee->new;
    return $calc->late_fee( $order, $today );
}

=head2 flatten_user( $user )

=cut

sub flatten_user {
    my ( $self, $user ) = @_;

    return unless $user;

    my %data = ( $user->user_info->get_columns, $user->get_columns, );
    delete @data{qw/ user_id password /};

    return \%data;
}

=head2 tracking_url( $order )

=cut

sub tracking_url {
    my ( $self, $order ) = @_;

    return unless $order;
    return unless $order->return_method;

    my ( $company, $id ) = split /,/, $order->return_method;
    return unless $id;

    my $driver;
    {
        no warnings 'experimental';

        given ($company) {
            $driver = 'KR::PostOffice' when /^우체국/;
            $driver = 'KR::CJKorea' when m/^(대한통운|CJ|CJ\s*GLS|편의점)/i;
            $driver = 'KR::KGB' when m/^KGB/i;
            $driver = 'KR::Hanjin' when m/^한진/;
            $driver = 'KR::Yellowcap' when m/^(KG\s*)?옐로우캡/i;
            $driver = 'KR::Dongbu' when m/^(KG\s*)?동부/i;
        }
    }
    return unless $driver;

    my $tracking_url = Parcel::Track->new( $driver, $id )->uri;

    return $tracking_url;
}

=head2 order_price( $order )

=cut

sub order_price {
    my ( $self, $order ) = @_;

    return unless $order;

    my $order_price       = 0;
    my %order_stage_price = (
        0 => 0,
        1 => 0, # 연장료 / 연장료 에누리
        2 => 0, # 배상비 / 배상비 에누리
        3 => 0, # 환불 수수료
    );
    for my $order_detail ( $order->order_details ) {
        $order_price += $order_detail->final_price;
        $order_stage_price{ $order_detail->stage } += $order_detail->final_price;
    }

    return ( $order_price, \%order_stage_price );
}

=head2 flatten_order( $order, $today )

=cut

sub flatten_order {
    my ( $self, $order, $today ) = @_;

    return unless $order;

    my ( $order_price, $order_stage_price ) = $self->order_price($order);
    my $sale_price = 0;
    {
        my $original_price = 0;
        my $jacket         = 0;
        my $pants_skirt    = 0;
        my $tie            = 0;
        for my $order_detail ( $order->order_details ) {
            next unless $order_detail->stage == 0;
            next unless $order_detail->clothes_code;

            $original_price += $order_detail->clothes->price
                + $order_detail->clothes->price * 0.2 * $order->additional_day;

            use experimental qw( smartmatch );
            given ( $order_detail->clothes->category ) {
                ++$jacket when "jacket";
                ++$pants_skirt when /^pants|skirt$/;
                ++$tie when "tie";
            }
        }

        #
        # 현재 데이터베이스에 타이 가격이 0원으로 책정되어 있어
        # 수동으로 타이 가격을 더해야 함
        #
        my $set = List::Util::min $jacket, $pants_skirt;
        if ( $tie > $set ) {
            my $tie_price = ( $tie - $set ) * 2000;
            $original_price += $tie_price + $tie_price * 0.2 * $order->additional_day;
        }

        $sale_price = $original_price - $order_stage_price->{0};
    }

    my $extension_fee = $self->calc_extension_fee( $order, $today );
    my $overdue_fee = $self->calc_overdue_fee( $order, $today );

    my %data = (
        $order->get_columns,
        status_name => $order->status ? $order->status->name : q{},
        rental_date => undef,
        target_date => undef,
        user_target_date => undef,
        return_date      => undef,
        price            => $order_price,
        stage_price      => $order_stage_price,
        sale_price       => $sale_price,
        clothes_price    => $self->order_clothes_price($order),
        clothes          => [
            $order->order_details( { clothes_code => { '!=' => undef } } )
                ->get_column('clothes_code')->all
        ],

        ## 연장료와 연체료를 구분해야한다
        ## 연장료: extension-fee
        ## 연체료: overdue-fee
        ## 둘의합: late-fee = extension-fee + overdue-fee
        extension_fee  => $extension_fee,
        extension_days => $self->calc_extension_days( $order, $today ),
        overdue_fee    => $overdue_fee,
        overdue_days   => $self->calc_overdue_days( $order, $today ),
        late_fee       => $extension_fee + $overdue_fee,
        overdue        => $self->calc_overdue( $order, $today ),
        return_method  => $order->return_method || q{},
        tracking_url => $self->tracking_url($order) || q{},
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
}

=head2 flatten_order_detail( $order_detail )

=cut

sub flatten_order_detail {
    my ( $self, $order_detail ) = @_;

    return unless $order_detail;

    my %data = ( $order_detail->get_columns );

    return \%data;
}

=head2 flatten_clothes( $clothes )

=cut

sub flatten_clothes {
    my ( $self, $clothes ) = @_;

    return unless $clothes;

    #
    # additional information for clothes
    #
    my %extra_data;

    # '대여중'인 항목만 주문서 정보를 포함합니다.
    my $order = $clothes->orders->find( { status_id => 2 } );
    $extra_data{order} = $self->flatten_order($order) if $order;

    my @tags = $clothes->tags;

    my %data = (
        $clothes->get_columns,
        %extra_data,
        status => $clothes->status->name,
        tags   => [
            map {
                { $_->get_columns }
            } @tags
        ],
    );

    return \%data;
}

=head2 flatten_booking( $booking )

=cut

sub flatten_booking {
    my ( $self, $booking ) = @_;

    return unless $booking;

    my %data = $booking->get_columns;

    return \%data;
}

=head2 get_params( @keys )

=cut

sub get_params {
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
}

=head2 get_user( $params )

=cut

sub get_user {
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
        return $self->error( 400, { str => join( ',', @error_str ), data => $v->errors, } );
    }

    #
    # find user
    #
    my $user = $self->app->DB->resultset('User')->find($params);
    return $self->error( 404, { str => 'user not found', data => {}, } ) unless $user;
    return $self->error( 404, { str => 'user info not found', data => {}, } )
        unless $user->user_info;

    return $user;
}

=head2 update_user( $user_params, $user_info_params )

=cut

sub update_user {
    my ( $self, $user_params, $user_info_params ) = @_;

    #
    # validate params
    #
    my $v = $self->create_validator;
    $v->field('id')->required(1)->regexp(qr/^\d+$/);
    $v->field('name')->trim(0)->callback(
        sub {
            my $value = shift;

            return 1 unless $value =~ m/(^\s+|\s+$)/;
            return ( 0, "name has trailing space" );
        }
    );
    $v->field('email')->email;
    $v->field('expires')->regexp(qr/^\d+$/);
    $v->field('phone')->regexp(qr/^\d+$/);
    $v->field('gender')->in(qw/ male female /);
    $v->field('birth')->regexp(qr/^(0|((19|20)\d{2}))$/);
    $v->field(
        qw/ height weight neck bust waist hip topbelly belly thigh arm leg knee foot pants /
        )->each(
        sub {
            shift->regexp(qr/^\d{1,3}$/);
        }
        );
    $v->field('staff')->in( 0, 1 );
    unless ( $self->validate( $v, { %$user_params, %$user_info_params } ) ) {
        my @error_str;
        while ( my ( $k, $v ) = each %{ $v->errors } ) {
            push @error_str, "$k:$v";
        }
        $self->error( 400, { str => join( ',', @error_str ), data => $v->errors, } );
        return ( undef, join( ',', @error_str ) );
    }

    #
    # find user
    #
    my $user = $self->app->DB->resultset('User')->find( { id => $user_params->{id} } );
    return $self->error( 404, { str => 'user not found', data => {}, } ) unless $user;
    return $self->error( 404, { str => 'user info not found', data => {}, } )
        unless $user->user_info;

    #
    # update user
    #
    {
        my $guard = $self->app->DB->txn_scope_guard;

        my %_user_params = %$user_params;
        delete $_user_params{id};

        if ( $_user_params{create_date} ) {
            $_user_params{create_date} = DateTime->from_epoch(
                epoch     => $_user_params{create_date},
                time_zone => $self->config->{timezone},
            );
        }
        if ( $_user_params{update_date} ) {
            $_user_params{update_date} = DateTime->from_epoch(
                epoch     => $_user_params{update_date},
                time_zone => $self->config->{timezone},
            );
        }

        $user->update( \%_user_params )
            or return $self->error( 500, { str => 'failed to update a user', data => {}, } );

        $user->user_info->update( { %$user_info_params, user_id => $user->id, } )
            or return $self->error(
            500,
            { str => 'failed to update a user info', data => {}, }
            );

        $guard->commit;

        #
        # event posting to opencloset/monitor
        #
        my $monitor_uri_full = $self->config->{monitor_uri} . "/events";
        my $res = HTTP::Tiny->new( timeout => 1 )->post_form(
            $monitor_uri_full,
            { sender => 'user', user_id => $user->id },
        );
        $self->app->log->warn(
            "Failed to post event to monitor: $monitor_uri_full: $res->{reason}")
            unless $res->{success};
    }

    return $user;
}

=head2 get_user_list( $params )

=cut

sub get_user_list {
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
        return $self->error( 400, { str => join( ',', @error_str ), data => $v->errors, } );
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
        $rs = $self->app->DB->resultset('User')->search( { id => $params->{id} } );
    }
    else {
        $rs = $self->app->DB->resultset('User');
    }
    return $self->error( 404, { str => 'user list not found', data => {}, } )
        if $rs->count == 0 && !$params->{allow_empty};

    return $rs;
}

=head2 create_order( $order_params, $order_detail_params )

=cut

sub create_order {
    my ( $self, $order_params, $order_detail_params ) = @_;

    return unless $order_params;
    return unless ref($order_params) eq 'HASH';

    #
    # validate params
    #
    {
        my $v = $self->create_validator;
        $v->field('user_id')->required(1)->regexp(qr/^\d+$/)->callback(
            sub {
                my $val = shift;

                return 1 if $self->app->DB->resultset('User')->find( { id => $val } );
                return ( 0, 'user not found using user_id' );
            }
        );
        $v->field('additional_day')->regexp(qr/^\d+$/);
        $v->field(
            qw/ height weight neck bust waist hip topbelly belly thigh arm leg knee foot pants /
            )->each(
            sub {
                shift->regexp(qr/^\d{1,3}$/);
            }
            );
        $v->field('bestfit')->in( 0, 1 );
        unless ( $self->validate( $v, $order_params ) ) {
            my @error_str;
            while ( my ( $k, $v ) = each %{ $v->errors } ) {
                push @error_str, "$k:$v";
            }
            $self->error( 400, { str => join( ',', @error_str ), data => $v->errors, } ), return;
        }
    }
    {
        my $v = $self->create_validator;
        $v->field('clothes_code')->regexp(qr/^[A-Z0-9]{4,5}$/)->callback(
            sub {
                my $val = shift;

                $val = sprintf( '%05s', $val ) if length $val == 4;

                return 1 if $self->app->DB->resultset('Clothes')->find( { code => $val } );
                return ( 0, 'clothes not found using clothes_code' );
            }
        );
        unless ( $self->validate( $v, $order_detail_params ) ) {
            my @error_str;
            while ( my ( $k, $v ) = each %{ $v->errors } ) {
                push @error_str, "$k:$v";
            }
            $self->error( 400, { str => join( ',', @error_str ), data => $v->errors, } ), return;
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
        my $user = $self->get_user( { id => $order_params->{user_id} } );
        #
        # we believe user is exist since parameter validator
        #
        for (
            qw/ height weight neck bust waist hip topbelly belly thigh arm leg knee foot pants /
            )
        {
            next if defined $order_params->{$_};
            next unless defined $user->user_info->$_;

            $self->app->log->debug("overriding $_ from user for order creation");
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
        my $guard = $self->app->DB->txn_scope_guard;
        try {
            #
            # create order
            #
            my $order = $self->app->DB->resultset('Order')->create($order_params);
            die "failed to create a new order\n" unless $order;

            #
            # create order_detail
            #
            my ($f_key) = keys %$order_detail_params;
            return $order unless $f_key;
            unless ( ref $order_detail_params->{$f_key} ) {
                $order_detail_params->{$_} = [ $order_detail_params->{$_} ]
                    for keys %$order_detail_params;
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
                        my $clothes =
                            $self->app->DB->resultset('Clothes')->find( { code => $params{clothes_code} } );

                        my $name = $params{name} // join(
                            q{ - },
                            $self->trim_clothes_code($clothes),
                            $self->config->{category}{ $clothes->category }{str},
                        );
                        my $price       = $params{price}       // $clothes->price;
                        my $final_price = $params{final_price} // (
                            $clothes->price + $clothes->price * 0.2 * ( $order_params->{additional_day} || 0 ) );

                        $order->add_to_order_details(
                            {
                                %params,
                                clothes_code => $clothes->code,
                                name         => $name,
                                price        => $price,
                                final_price  => $final_price,
                            }
                        ) or die "failed to create a new order_detail\n";
                    }
                }
                else {
                    $order->add_to_order_details( \%params )
                        or die "failed to create a new order_detail\n";
                }
            }

            $order->add_to_order_details(
                { name => '배송비', price => 0, final_price => 0, } )
                or die "failed to create a new order_detail for delivery_fee\n";
            $order->add_to_order_details(
                { name => '에누리', price => 0, final_price => 0, } )
                or die "failed to create a new order_detail for discount\n";

            $guard->commit;

            return $order;
        }
        catch {
            chomp;
            $self->app->log->error("failed to create a new order & a new order_clothes");
            $self->app->log->error($_);

            return ( undef, $_ );
        };
    };

    #
    # response
    #
    $self->error( 500, { str => $error, data => {}, } ), return unless $order;

    return $order;
}

=head2 get_order( $params )

=cut

sub get_order {
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
        return $self->error( 400, { str => join( ',', @error_str ), data => $v->errors, } );
    }

    #
    # find order
    #
    my $order = $self->app->DB->resultset('Order')->find($params);
    return $self->error( 404, { str => 'order not found', data => {}, } ) unless $order;

    return $order;
}

=head2 update_order( $order_params, $order_detail_params )

=cut

sub update_order {
    my ( $self, $order_params, $order_detail_params ) = @_;

    #
    # validate params
    #
    {
        my $v = $self->create_validator;
        $v->field('id')->required(1)->regexp(qr/^\d+$/);
        $v->field('user_id')->regexp(qr/^\d+$/)->callback(
            sub {
                my $val = shift;

                return 1 if $self->app->DB->resultset('User')->find( { id => $val } );
                return ( 0, 'user not found using user_id' );
            }
        );
        $v->field('additional_day')->regexp(qr/^\d+$/);
        $v->field(
            qw/ height weight neck bust waist hip topbelly belly thigh arm leg knee foot pants /
            )->each(
            sub {
                shift->regexp(qr/^\d{1,3}$/);
            }
            );
        $v->field('bestfit')->in( 0, 1 );
        $v->field('ignore_sms')->in( 0, 1 );
        unless ( $self->validate( $v, $order_params ) ) {
            my @error_str;
            while ( my ( $k, $v ) = each %{ $v->errors } ) {
                push @error_str, "$k:$v";
            }
            $self->error( 400, { str => join( ',', @error_str ), data => $v->errors, } ), return;
        }
    }
    {
        my $v = $self->create_validator;
        $v->field('clothes_code')->regexp(qr/^[A-Z0-9]{4,5}$/)->callback(
            sub {
                my $val = shift;

                $val = sprintf( '%05s', $val ) if length $val == 4;

                return 1 if $self->app->DB->resultset('Clothes')->find( { code => $val } );
                return ( 0, 'clothes not found using clothes_code' );
            }
        );
        unless ( $self->validate( $v, $order_detail_params ) ) {
            my @error_str;
            while ( my ( $k, $v ) = each %{ $v->errors } ) {
                push @error_str, "$k:$v";
            }
            $self->error( 400, { str => join( ',', @error_str ), data => $v->errors, } ), return;
        }
    }

    #
    # adjust params
    #
    if ($order_detail_params) {
        for my $key (
            qw/
            id
            order_id
            clothes_code
            status_id
            name
            price
            final_price
            stage
            desc
            /
            )
        {

            if ( $order_detail_params->{$key} ) {
                $order_detail_params->{$key} = [ $order_detail_params->{$key} ]
                    unless ref $order_detail_params->{$key};

                if ( $key eq 'clothes_code' ) {
                    for ( @{ $order_detail_params->{$key} } ) {
                        next unless length == 4;
                        $_ = sprintf( '%05s', $_ );
                    }
                }
            }
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
        my $guard = $self->app->DB->txn_scope_guard;
        try {
            #
            # find order
            #
            my $order =
                $self->app->DB->resultset('Order')->find( { id => $order_params->{id} } );
            die "order not found\n" unless $order;
            my $from = $order->status_id;

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
            if ( my $status_id = $order_params->{status_id} ) {
                for my $clothes ( $order->clothes ) {
                    $clothes->update( { status_id => $order_params->{status_id} } )
                        or die "failed to update the clothes status\n";
                }

                ## 환불하면 쿠폰을 사용가능하도록 변경한다 (Github-#1193)
                if ( my $coupon = $order->coupon and $status_id == $PAYBACK ) {
                    $coupon->update( { status => 'reserved' } );
                }
            }

            #
            # update order_detail
            #
            if ( $order_detail_params && $order_detail_params->{id} ) {
                my %_params = %$order_detail_params;
                for my $i ( 0 .. $#{ $_params{id} } ) {
                    my %p = map { $_ => $_params{$_}[$i] } keys %_params;
                    my $id = delete $p{id};

                    my $order_detail = $self->app->DB->resultset('OrderDetail')->find( { id => $id } );
                    die "order_detail not found\n" unless $order_detail;
                    $order_detail->update( \%p ) or die "failed to update the order_detail\n";
                }
            }

            $guard->commit;

            #
            # event posting to opencloset/monitor
            #
            my $to = $order_params->{status_id};
            return $order unless $to;
            return $order if $to == $from;

            my $monitor_uri_full = $self->config->{monitor_uri} . "/events";
            my $res = HTTP::Tiny->new( timeout => 1 )->post_form(
                $monitor_uri_full,
                { sender => 'order', order_id => $order->id, from => $from, to => $to },
            );
            $self->app->log->warn(
                "Failed to post event to monitor: $monitor_uri_full: $res->{reason}")
                unless $res->{success};

            return $order;
        }
        catch {
            chomp;
            $self->app->log->error("failed to update a new order & a new order_clothes");
            $self->app->log->error($_);

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
    $self->error( $status, { str => $error, data => {}, } ), return unless $order;

    return $order;
}

=head2 delete_order( $params )

=cut

sub delete_order {
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
        return $self->error( 400, { str => join( ',', @error_str ), data => $v->errors, } );
    }

    #
    # find order
    #
    my $order = $self->app->DB->resultset('Order')->find($params);
    return $self->error( 404, { str => 'order not found', data => {}, } ) unless $order;

    #
    # delete order
    #
    my $data = $self->flatten_order($order);
    $order->delete;

    return $data;
}

=head2 get_order_list( $params )

=cut

sub get_order_list {
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
        return $self->error( 400, { str => join( ',', @error_str ), data => $v->errors, } );
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
        $rs = $self->app->DB->resultset('Order')->search( { id => $params->{id} } );
    }
    else {
        $rs = $self->app->DB->resultset('Order');
    }
    return $self->error( 404, { str => 'order list not found', data => {}, } )
        if $rs->count == 0 && !$params->{allow_empty};

    return $rs;
}

=head2 create_order_detail( $params )

=cut

sub create_order_detail {
    my ( $self, $params ) = @_;

    return unless $params;
    return unless ref($params) eq 'HASH';

    #
    # validate params
    #
    my $v = $self->create_validator;
    $v->field('order_id')->required(1)->regexp(qr/^\d+$/)->callback(
        sub {
            my $val = shift;

            return 1 if $self->app->DB->resultset('Order')->find( { id => $val } );
            return ( 0, 'order not found using order_id' );
        }
    );
    $v->field('clothes_code')->regexp(qr/^[A-Z0-9]{4,5}$/)->callback(
        sub {
            my $val = shift;

            $val = sprintf( '%05s', $val ) if length $val == 4;

            return 1 if $self->app->DB->resultset('Clothes')->find( { code => $val } );
            return ( 0, 'clothes not found using clothes_code' );
        }
    );
    $v->field('status_id')->regexp(qr/^\d+$/)->callback(
        sub {
            my $val = shift;

            return 1 if $self->app->DB->resultset('Status')->find( { id => $val } );
            return ( 0, 'status not found using status_id' );
        }
    );
    $v->field(qw/ price final_price /)->each( sub { shift->regexp(qr/^-?\d+$/) } );
    $v->field('stage')->regexp(qr/^\d+$/);

    unless ( $self->validate( $v, $params ) ) {
        my @error_str;
        while ( my ( $k, $v ) = each %{ $v->errors } ) {
            push @error_str, "$k:$v";
        }
        $self->error( 400, { str => join( ',', @error_str ), data => $v->errors, } ), return;
    }

    #
    # adjust params
    #
    $params->{clothes_code} = sprintf( '%05s', $params->{clothes_code} )
        if $params->{clothes_code} && length( $params->{clothes_code} ) == 4;

    my $order_detail = $self->app->DB->resultset('OrderDetail')->create($params);
    return $self->error(
        500,
        { str => 'failed to create a new order_detail', data => {}, }
    ) unless $order_detail;

    return $order_detail;
}

=head2 get_clothes( $params )

=cut

sub get_clothes {
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
        return $self->error( 400, { str => join( ',', @error_str ), data => $v->errors, } );
    }

    #
    # adjust params
    #
    $params->{code} = sprintf( '%05s', $params->{code} )
        if length( $params->{code} ) == 4;

    #
    # find clothes
    #
    my $clothes = $self->app->DB->resultset('Clothes')->find($params);
    return $self->error( 404, { str => 'clothes not found', data => {}, } )
        unless $clothes;

    return $clothes;
}

=head2 get_nearest_booked_order( $user )

=cut

sub get_nearest_booked_order {
    my ( $self, $user ) = @_;

    my $dt_now = DateTime->now( time_zone => $self->config->{timezone} );
    my $dtf = $self->app->DB->storage->datetime_parser;

    my $rs = $user->search_related(
        'orders',
        {
            'me.status_id' => { -in => [ $RESERVATED, $PAYMENT ] }, # 방문예약, 결제대기
        },
        {
            join => 'booking', order_by => [ { -asc => 'booking.date' }, { -asc => 'me.id' }, ],
        },
        )->search_literal(
        'DATE_FORMAT(`booking`.`date`, "%Y-%m-%d") >= ?',
        $dt_now->ymd
        );

    my $order = $rs->next;

    return $order;
}

=head2 convert_sec_to_locale( $seconds )

=cut

sub convert_sec_to_locale {
    my ( $self, $seconds ) = @_;

    my $dfd = DateTime::Format::Duration->new( normalize => 'ISO', pattern => '%M:%S' );
    my $dur1 = DateTime::Duration->new( seconds => $seconds );
    my $dur2 = DateTime::Duration->new( $dfd->normalize($dur1) );
    my $dfhd = DateTime::Format::Human::Duration->new;

    my $locale = $dfhd->format_duration( $dur2, locale => "ko" );
    $locale =~ s/\s*(년|개월|주|일|시간|분|초|나노초)/$1/gms;
    $locale =~ s/\s+/ /gms;
    $locale =~ s/,//gms;

    return $locale;
}

=head2 convert_sec_to_hms( $seconds )

=cut

sub convert_sec_to_hms {
    my ( $self, $seconds ) = @_;

    return unless $seconds;

    my $dfd = DateTime::Format::Duration->new( normalize => 'ISO', pattern => "%M:%S" );
    my $dur1 = DateTime::Duration->new( seconds => $seconds );
    my $hms = sprintf(
        '%02d:%s',
        $seconds / 3600,
        $dfd->format_duration( DateTime::Duration->new( $dfd->normalize($dur1) ) ),
    );

    return $hms;
}

=head2 phone_format( $phone )

=cut

sub phone_format {
    my ( $self, $phone ) = @_;
    return $phone if $phone !~ m/^[0-9]{10,11}$/;

    $phone =~ s/(\d{3})(\d{4})/$1-$2/;
    $phone =~ s/(\d{4})(\d{3,4})/$1-$2/;
    return $phone;
}

=head2 user_avg_diff( $user )

=cut

sub user_avg_diff {
    my ( $self, $user ) = @_;

    my %data = ( ret => 0, diff => undef, avg => undef, );
    for (qw/ neck belly topbelly bust arm thigh waist hip leg foot knee /) {
        $data{diff}{$_} = '-';
        $data{avg}{$_}  = 'N/A';
    }

    unless ( $user->user_info->gender =~ m/^(male|female)$/
        && $user->user_info->height
        && $user->user_info->weight )
    {
        return \%data;
    }

    my $osg_db = OpenCloset::Size::Guess->new(
        'DB', _time_zone => $self->config->{timezone},
        _schema => $self->app->DB, _range => 0,
    );
    $osg_db->gender( $user->user_info->gender );
    $osg_db->height( int $user->user_info->height );
    $osg_db->weight( int $user->user_info->weight );
    my $avg = $osg_db->guess;
    my $diff;
    for (qw/ neck belly topbelly bust arm thigh waist hip leg foot knee /) {
        $diff->{$_} = $user->user_info->$_
            && $avg->{$_} ? sprintf( '%+.1f', $user->user_info->$_ - $avg->{$_} ) : '-';
        $avg->{$_} = $avg->{$_} ? sprintf( '%.1f', $avg->{$_} ) : 'N/A';
    }

    %data = ( ret => 1, diff => $diff, avg => $avg, );

    return \%data;
}

=head2 user_avg2( $user )

=cut

sub user_avg2 {
    my ( $self, $user ) = @_;

    my %data = ( ret => 0, avg => undef, );
    for (qw/ bust waist topbelly belly thigh hip /) {
        $data{avg}{$_} = 'N/A';
    }

    unless ( $user->user_info->gender =~ m/^(male|female)$/
        && $user->user_info->height
        && $user->user_info->weight )
    {
        return \%data;
    }

    my $height = $user->user_info->height;
    my $weight = $user->user_info->weight;
    my $gender = $user->user_info->gender;
    my $range  = 0;
    my %ret;
    do {
        my $dt_base = try {
            DateTime->new(
                time_zone => $self->config->{timezone}, year => 2015, month => 5,
                day       => 29,
            );
        };
        last unless $dt_base;

        my $dtf  = $self->app->DB->storage->datetime_parser;
        my $cond = {
            -or => [
                {
                    # 대여일이 2015-05-29 이전
                    -and => [
                        { 'booking.date' => { '<' => $dtf->format_datetime($dt_base) }, },
                        \[ "DATE_FORMAT(booking.date, '%H') < ?" => 19 ],
                    ],
                },
                {
                    # 대여일이 2015-05-29 이후
                    -and => [
                        { 'booking.date' => { '>=' => $dtf->format_datetime($dt_base) }, },
                        \[ "DATE_FORMAT(booking.date, '%H') < ?" => 22 ],
                    ],
                },
            ],
            'booking.gender' => $gender,
            'height'         => { -between => [ $height - $range, $height + $range ] },
            'weight'         => { -between => [ $weight - $range, $weight + $range ] },
        };
        my $attr = { join => [qw/ booking /] };

        my $avg2_range = 1;
        $cond->{belly} =
            { -between =>
                [ $user->user_info->belly - $avg2_range, $user->user_info->belly + $avg2_range ]
            }
            if $user->user_info->belly;
        $cond->{bust} =
            { -between =>
                [ $user->user_info->bust - $avg2_range, $user->user_info->bust + $avg2_range ] }
            if $user->user_info->bust;
        $cond->{hip} =
            { -between =>
                [ $user->user_info->hip - $avg2_range, $user->user_info->hip + $avg2_range ] }
            if $user->user_info->hip;
        $cond->{thigh} =
            { -between =>
                [ $user->user_info->thigh - $avg2_range, $user->user_info->thigh + $avg2_range ]
            }
            if $user->user_info->thigh;
        $cond->{topbelly} = {
            -between => [
                $user->user_info->topbelly - $avg2_range, $user->user_info->topbelly + $avg2_range
            ]
            }
            if $user->user_info->topbelly;
        $cond->{waist} =
            { -between =>
                [ $user->user_info->waist - $avg2_range, $user->user_info->waist + $avg2_range ]
            }
            if $user->user_info->waist;

        my $order_rs = $self->app->DB->resultset('Order')->search( $cond, $attr );

        my %item = (
            belly => [], bust => [], hip => [], thigh => [], topbelly => [], waist => [],
        );
        my %count = (
            total => 0, belly => 0, bust => 0, hip => 0, thigh => 0, topbelly => 0,
            waist => 0,
        );
        while ( my $order = $order_rs->next ) {
            ++$count{total};
            for (
                qw/
                belly
                bust
                hip
                thigh
                topbelly
                waist
                /
                )
            {
                next unless $order->$_; # remove undef & 0

                ++$count{$_};
                push @{ $item{$_} }, $order->$_;
            }
        }
        %ret = (
            height   => $height,
            weight   => $weight,
            gender   => $gender,
            count    => \%count,
            belly    => 0,
            bust     => 0,
            hip      => 0,
            thigh    => 0,
            topbelly => 0,
            waist    => 0,
        );
        $ret{belly}    = Statistics::Basic::mean( $item{belly} )->query;
        $ret{bust}     = Statistics::Basic::mean( $item{bust} )->query;
        $ret{hip}      = Statistics::Basic::mean( $item{hip} )->query;
        $ret{thigh}    = Statistics::Basic::mean( $item{thigh} )->query;
        $ret{topbelly} = Statistics::Basic::mean( $item{topbelly} )->query;
        $ret{waist}    = Statistics::Basic::mean( $item{waist} )->query;
    };
    return \%data unless %ret;

    my $avg = \%ret;
    for (qw/ bust waist topbelly belly thigh hip /) {
        $avg->{$_} = $avg->{$_} ? sprintf( '%.1f', $avg->{$_} ) : 'N/A';
    }

    %data = ( ret => 1, avg => $avg, );

    return \%data;
}

=head2 count_visitor( $start_dt, $end_dt, $cb )

=cut

sub count_visitor {
    my ( $self, $start_dt, $end_dt, $cb ) = @_;

    my $dtf        = $self->app->DB->storage->datetime_parser;
    my $booking_rs = $self->app->DB->resultset('Booking')->search(
        {
            date => {
                -between => [ $dtf->format_datetime($start_dt), $dtf->format_datetime($end_dt), ],
            },
        },
        { prefetch => { 'orders' => { 'user' => 'user_info' } }, },
    );

    my %count = (
        all        => { total => 0, male => 0, female => 0 },
        visited    => { total => 0, male => 0, female => 0 },
        notvisited => { total => 0, male => 0, female => 0 },
        bestfit    => { total => 0, male => 0, female => 0 },
        loanee     => { total => 0, male => 0, female => 0 },
    );
    while ( my $booking = $booking_rs->next ) {
        for my $order ( $booking->orders ) {
            next unless $order->user->user_info;

            my $gender = $order->user->user_info->gender;
            next unless $gender;

            ++$count{all}{total};
            ++$count{all}{$gender};

            if ( $order->rental_date ) {
                ++$count{loanee}{total};
                ++$count{loanee}{$gender};
            }

            if ( $order->bestfit ) {
                ++$count{bestfit}{total};
                ++$count{bestfit}{$gender};
            }

            use feature qw( switch );
            use experimental qw( smartmatch );
            given ( $order->status_id ) {
                when (/^12|14$/) {
                    ++$count{notvisited}{total};
                    ++$count{notvisited}{$gender};
                }
            }

            $cb->( $booking, $order, $gender ) if $cb && ref($cb) eq 'CODE';
        }
    }
    $count{visited}{total}  = $count{all}{total} - $count{notvisited}{total};
    $count{visited}{male}   = $count{all}{male} - $count{notvisited}{male};
    $count{visited}{female} = $count{all}{female} - $count{notvisited}{female};

    return \%count;
}

=head2 is_nonpaid( $order )

C<order> 에 대해 불납의 이력이 있는지 확인
불납이면 order_detail 에 대한 C<$resultset> 아니면 C<undef> 를 return

=cut

sub is_nonpaid {
    my ( $self, $order ) = @_;
    return unless $order;
    return OpenCloset::Common::Unpaid::is_nonpaid($order);
}

=head2 coupon2label( $coupon )

    %= coupon2label($order->coupon);
    # <span class="label label-info">사용가능 쿠폰</span>
    # <span class="label label-info">사용가능 쿠폰 10,000</span>
    # <span class="label label-danger">사용된 쿠폰</span>

=cut

my %COUPON_EVENT_NAME_MAP = (
    seoul        => '취업날개',
    gwanak       => '관악고용',
    '10bob'      => '십시일밥',
    'seoul-2017' => '취업날개'
);

our %COUPON_STATUS_MAP = (
    ''        => '사용가능',
    used      => '사용된',
    provided  => '사용가능',
    reserved  => '사용가능',
    discarded => '폐기된'
);

sub coupon2label {
    my ( $self, $coupon ) = @_;
    return '' unless $coupon;

    my $type   = $coupon->type;
    my $status = $coupon->status || '';
    my $price  = $coupon->price;
    my $title  = sprintf( "%d(%s)", $coupon->id, $coupon->code );
    my $event  = $coupon ? $coupon->desc : '';
    ($event) = split( /\|/, $event ) if $event;
    $event = $COUPON_EVENT_NAME_MAP{$event} || $event;

    my $klass = 'label-info';
    $klass = 'label-danger' if $status =~ /(us|discard)ed/;

    my $extra = '';
    $extra = ' ' . $self->commify($price) if $type eq 'default';

    my $html = Mojo::DOM::HTML->new;
    $html->parse(
        qq{<span class="label $klass" title="$title">$COUPON_STATUS_MAP{$status} 쿠폰($event)$extra</span>}
    );

    my $tree = $html->tree;
    return Mojo::ByteStream->new( Mojo::DOM::HTML::_render($tree) );
}

=head2 measurement2text( $user )

    my $text = $self->measurement2text($user);

    키 180cm
    몸무게 70kg
    가슴둘레 95cm
    ..
    ...
    발크기 270mm

=cut

sub measurement2text {
    my ( $self, $user ) = @_;
    return '' unless $user;

    my $user_info = $user->user_info;
    return '' unless $user_info;

    my @sizes;
    for my $part (@OpenCloset::Constants::Measurement::PRIMARY) {
        my $size = $user_info->get_column($part);
        push @sizes,
            sprintf(
            '%s: %s%s', $OpenCloset::Constants::Measurement::LABEL_MAP{$part},
            $size,      $OpenCloset::Constants::Measurement::UNIT_MAP{$part}
            ) if $size;
    }

    return join( "\n", @sizes );
}

=head2 decrypt_mbersn( $ciphertext_hex )

    my $plaintext = $self->decrypt_mbersn('a81f368a9771ce2e8db7d98a50b52068');

=cut

sub decrypt_mbersn {
    my ( $self, $ciphertext_hex ) = @_;
    return '' unless $ciphertext_hex;

    my $hex_key    = $self->config->{events}{seoul}{key};
    my $ciphertext = pack( 'H*', $ciphertext_hex );
    my $key        = pack( 'H*', $hex_key );
    my $m          = Crypt::Mode::ECB->new('AES');
    my $plaintext  = try {
        $m->decrypt( $ciphertext, $key );
    }
    catch {
        warn $_;
        return '';
    };

    return $plaintext;
}

=head2 redis

    my $json = $self->redis->get('opencloset:storage');

=cut

sub redis {
    my $self = shift;

    $self->stash->{redis} ||= do {
        my $log   = $self->app->log;
        my $redis = Mojo::Redis2->new; # just use `redis://localhost:6379`
        $redis->on(
            error => sub {
                $log->error("[REDIS ERROR] $_[1]");
            }
        );

        $redis;
    };
}

=head2 search_clothes

    my $result_arrref = $self->search_clothes($user_id);

=cut

sub range_filter {
    my ( $f, $measure, $guess ) = @_;

    return $measure unless $f;

    my $result;
    if ( $guess < $measure ) {
        my $max = ( $f->($guess) )[1];
        my $min = ( $f->($measure) )[0];

        $result = $max - $min >= 0 ? $guess : $measure;
    }
    elsif ( $guess > $measure ) {
        my $min = ( $f->($guess) )[0];
        my $max = ( $f->($measure) )[1];

        $result = $min - $max >= 0 ? $measure : $guess;
    }
    else { $result = $guess }

    return $result;
}

sub choose_value_by_range {
    my ( $self, $guess, $gender, $sizes ) = @_;

    my $config = $self->config->{'search-clothes'}{$gender};

    for my $part ( @{ $config->{'fix_sizes'} } ) {
        next unless $guess->{$part};
        next unless $sizes->{$part};

        my $val = range_filter(
            $config->{range_rules}{$part}, $sizes->{$part},
            $guess->{$part}
        );
        next if $val == $guess->{$part};

        $self->log->info( "guess replace user $part : " . $guess->{$part} . ' => ' . $val );
        $guess->{$part} = $val;
    }
    if ( $gender eq 'female' ) {
        $self->log->info( "guess always replace female waist with topbelly : "
                . $guess->{waist} . ' => '
                . $sizes->{topbelly} );
        $guess->{waist} = $sizes->{topbelly};
    }

    return $guess;
}

sub search_clothes {
    my ( $self, %params ) = @_;

    my $gender     = $params{gender};
    my $config     = $self->config->{'search-clothes'}{$gender};
    my $upper_name = $config->{upper_name};
    my $lower_name = $config->{lower_name};

    my $guesser = OpenCloset::Size::Guess->new(
        'OpenCPU::RandomForest',
        gender => $gender,
        height => $params{height},
        weight => $params{weight},
        map { ( sprintf( "_%s", $_ ) => $params{sizes}->{$_} ) } keys %{ $params{sizes} },
    );
    $self->log->info( "guess params : " . encode_json( {%params} ) );

    my $guess = $guesser->guess;
    return $self->error( 500, { str => "Guess failed: $guess->{reason}" } )
        unless $guess->{success};

    $self->log->info( "guess result size : " . encode_json($guess) );

    $guess = $self->choose_value_by_range( $guess, $gender, $params{sizes} );

    my %between;
    for my $part ( keys %$guess ) {
        next unless exists $config->{range_rules}{$part};
        my $fn = $config->{range_rules}{$part};
        $between{$part} = [ $fn->( $guess->{$part} ) ];
    }
    $self->log->info( "guess filter range : " . encode_json( \%between ) );

    my $clothes_rs = $self->DB->resultset('Clothes')->search(
        {
            'category' => { '-in' => [ $upper_name, $lower_name ] },
            'gender'   => $gender,
            'order_details.order_id' => { '!=' => undef },
        },
        {
            join  => 'order_details', '+select' => ['order_details.order_id'],
            '+as' => ['order_id'],
        }
    );

    my ( %order_pair, %pair_count, %pair );
    while ( my $clothes = $clothes_rs->next ) {
        my $order_id = $clothes->get_column('order_id');
        my $category = $clothes->get_column('category');
        my $code     = $clothes->get_column('code');

        $order_pair{$order_id}{$category} = $code;
    }

    while ( my ( $order_id, $pair ) = each %order_pair ) {
        ## upper: top(jacket), lower: bottom(pants, skirt)
        my ( $upper_code, $lower_code ) = ( $pair->{$upper_name}, $pair->{$lower_name} );
        next unless $upper_code;
        next unless $lower_code;
        next unless keys %{$pair} == 2;

        $pair_count{$upper_code}{$lower_code}++;
    }

    for my $upper_code ( keys %pair_count ) {
        my $upper = $pair_count{$upper_code};
        my ($highest_rent_lower_code) = sort { $upper->{$b} <=> $upper->{$a} } keys %$upper;
        $pair{$upper_code} = {
            $upper_name => $upper_code,
            $lower_name => $highest_rent_lower_code,
            count       => $pair_count{$upper_code}{$highest_rent_lower_code},
        };
    }

    my $upper_rs = $self->DB->resultset('Clothes')->search(
        {
            category    => $upper_name,
            gender      => $gender,
            'status.id' => 1,
            map { $_ => { -between => $between{$_} } } @{ $config->{upper_params} }
        },
        { prefetch => [ { 'donation' => 'user' }, 'status' ] }
    );

    my $lower_rs = $self->DB->resultset('Clothes')->search(
        {
            'category'  => $lower_name,
            'gender'    => $gender,
            'status.id' => 1,
            map { $_ => { -between => $between{$_} } } @{ $config->{lower_params} }
        },
        { prefetch => [ { 'donation' => 'user' }, 'status' ] }
    );

    my @result;
    my %lower_map = map { $_->code => $_ } $lower_rs->all;
    while ( my $upper = $upper_rs->next ) {
        my $upper_code = $upper->code;
        next unless $pair{$upper_code};

        my $lower_code = $pair{$upper_code}{$lower_name};
        my $lower      = $lower_map{$lower_code};
        next unless $lower_code;
        next unless any { $_ eq $pair{$upper_code}{$lower_name} } keys %lower_map;

        my $rent_count = $pair{$upper_code}{count};
        my $color      = $upper->color;
        my @tags       = map { $_->name } $upper->tags;
        $self->log->info(
            sprintf '< %s / %s / %d / %s / %s >', $upper->code, $lower->code,
            $rent_count, $color, join( ', ', @tags )
        );
        my $rss;

        for my $size ( keys %$guess ) {
            next if $size eq 'reason';
            next if $size eq 'success';
            next unless $guess->{$size};
            next unless $upper->$size || $lower->$size;

            my $guess    = $guess->{$size};
            my $real     = $upper->$size || $lower->$size;
            my $residual = $guess - $real;

            $rss += $residual**2;
            $self->log->info(
                sprintf '[%-8s] guess : %.2f / real : %.2f / residual : %.2f',
                $size, $guess, $real, $residual
            );
        }
        $self->log->info( '-' x 50 . "RSS : $rss" );

        push @result,
            {
            upper_code => $upper_code, lower_code => $lower_code,
            upper_rs   => $upper,      lower_rs   => $lower,
            rss        => $rss,        rent_count => $rent_count,
            color      => $color,
            };
    }

    my $fav_color = ${ $params{colors} }[0];
    $self->log->info( "guess user pre_color : " . join( ',', @{ $params{colors} } ) );
    $self->log->info( "guess user fav color : " . $fav_color );

    my @sorted;
    if ( $fav_color
        && any { $fav_color eq $_ } (qw/black navy charcoalgray gray brown/) )
    {
        my @fav_suits =
            sort { $a->{rss} <=> $b->{rss} } grep { $_->{color} eq $fav_color } @result;
        my @nonfav_suits =
            sort { $a->{rss} <=> $b->{rss} } grep { $_->{color} ne $fav_color } @result;

        @sorted = (
            @fav_suits,
            @nonfav_suits,
        );
    }
    else {
        @sorted = sort { $a->{rss} <=> $b->{rss} } @result;
    }

    $self->log->info(
        "guess result list : "
            . encode_json(
            [ map { [ @{$_}{qw/upper_code lower_code rss rent_count/} ] } @sorted ]
            )
    );
    $self->log->info( "guess result list count : " . scalar @sorted );

    return [ $guess, @sorted ];
}

=head2 clothes2link( $clothes, $opts )

    %= clothes2link($clothes)
    # <a href="/clothes/J001">
    #   <span class="label label-primary">
    #     <i class="fa fa-external-link"></i>
    #     J001
    #   </span>
    # </a>

    %= clothes2link($clothes, { with_status => 1, external => 1, class => ['label-success'] })    # external link with status
    # <a href="/clothes/J001" target="_blank">
    #   <span class="label label-primary">
    #     <i class="fa fa-external-link"></i>
    #     J001
    #     <small>대여가능</small>
    #   </span>
    # </a>

=head3 $opt

외부링크로 제공하거나, 상태를 함께 표시할지 여부를 선택합니다.
Default 는 모두 off 입니다.

=over

=item C<1>

상태없이 외부링크로 나타냅니다.

=item C<$hashref>

=over

=item C<$text>

의류코드 대신에 나타낼 text.

=item C<$with_status>

상태도 함께 나타낼지에 대한 Bool.

=item C<$external>

외부링크로 제공할지에 대한 Bool.

=item C<$class>

label 태그에 추가될 css class.

=back

=back

=cut

sub clothes2link {
    my ( $self, $clothes, $opts ) = @_;
    return '' unless $clothes;

    my $code = $clothes->code;
    $code =~ s/^0//;
    my $prefix = '/clothes';
    my $dom    = Mojo::DOM::HTML->new;

    my $html  = "$code";
    my @class = qw/label/;
    if ($opts) {
        if ( ref $opts eq 'HASH' ) {
            if ( my $text = $opts->{text} ) {
                $html = $text;
            }

            if ( $opts->{with_status} ) {
                my $status = $clothes->status;
                my $name   = $status->name;
                my $sid    = $status->id;
                if ( $sid == $RENTABLE ) {
                    push @class, 'label-primary';
                }
                elsif ( $sid == $RENTAL ) {
                    push @class, 'label-danger';
                }
                else {
                    push @class, 'label-default';
                }
                $html .= qq{ <small>$name</small>};
            }
            else {
                push @class, 'label-primary' unless $opts->{class};
            }

            push @class, @{ $opts->{class} ||= [] };

            if ( $opts->{external} ) {
                $html = qq{<i class="fa fa-external-link"></i> } . $html;
                $html = qq{<span class="@class">$html</span>};
                $html = qq{<a href="$prefix/$code" target="_blank">$html</a>};
            }
            else {
                $html = qq{<span class="@class">$html</span>};
                $html = qq{<a href="$prefix/$code">$html</a>};
            }
        }
        else {
            $html = qq{<i class="fa fa-external-link"></i> } . $html;
            $html = qq{<span class="@class">$html</span>};
            $html = qq{<a href="$prefix/$code" target="_blank">$html</a>};
        }
    }
    else {
        $html = qq{<a href="$prefix/$code"><span class="@class">$html</span></a>};
    }

    $dom->parse($html);
    my $tree = $dom->tree;
    return Mojo::ByteStream->new( Mojo::DOM::HTML::_render($tree) );
}

=head2 is_suit_order

    % my $bool = is_suit_order($order)

=cut

sub is_suit_order {
    my ( $self, $order ) = @_;
    return unless $order;

    my ( @code_top, @code_bottom );
    for my $detail ( $order->order_details ) {
        my $clothes = $detail->clothes;
        next unless $clothes;

        my $category = $clothes->category;
        next unless "$JACKET $PANTS $SKIRT" =~ m/\b$category\b/;

        my $top    = $clothes->top;
        my $bottom = $clothes->bottom;
        return unless $top && $bottom;

        my $code_top    = $top->code;
        my $code_bottom = $top->code;

        return 1
            if "@code_top" =~ m/\b$code_top\b/ and "@code_bottom" =~ m/\b$code_bottom\b/;

        push @code_top,    $code_top;
        push @code_bottom, $code_bottom;
    }

    return;
}

=head2 mean_status( $start_dt, $end_dt )

=cut

sub mean_status {
    my ( $self, $start_dt, $end_dt ) = @_;

    my $dtf      = $self->app->DB->storage->datetime_parser;
    my $order_rs = $self->app->DB->resultset('Order')->search(
        {
            -and => [
                'booking.date' => {
                    -between => [ $dtf->format_datetime($start_dt), $dtf->format_datetime($end_dt), ],
                },
                online => 0,
            ]
        },
        { join => [qw/ booking /], order_by => { -asc => 'date' }, prefetch => 'booking', },
    );

    my @status = (qw/대기 치수측정 의류준비 탈의 수선 포장 결제/);
    my %count  = (
        '대기'       => 0,
        '치수측정' => 0,
        '의류준비' => 0,
        '탈의'       => 0,
        '수선'       => 0,
        '포장'       => 0,
        '결제'       => 0,
    );

    my %total;
    while ( my $order = $order_rs->next ) {
        my %analyze = $order->analyze_order_status_logs;
        next unless $analyze{elapsed_time};

        for (@status) {
            next unless $analyze{elapsed_time}{$_};

            push @{ $total{$_} }, $analyze{elapsed_time}{$_};
        }
    }
    for my $status ( keys %total ) {
        $count{$status} = Statistics::Basic::mean( $total{$status} )->query;
    }

    return \%count;
}

=head2 booking_list( $gender [, $from, $to ] )

    my @list = $self->booking_list('male');

=cut

sub booking_list {
    my ( $self, $gender, $from, $to ) = @_;

    #
    # find booking
    #
    my $dt_start = $from;
    unless ($dt_start) {
        $dt_start = DateTime->now( time_zone => $self->config->{timezone} );
        unless ($dt_start) {
            my $msg = "cannot create start datetime object";
            $self->log->warn($msg);
            $self->error( 500, { str => $msg, data => {}, } );
            return;
        }
    }

    my $dt_end = $to;
    unless ($dt_end) {
        $dt_end = $dt_start->clone->truncate( to => 'day' )
            ->add( hours => 24 * 15, seconds => -1 );
        unless ($dt_end) {
            my $msg = "cannot create end datetime object";
            $self->app->log->warn($msg);
            $self->error( 500, { str => $msg, data => {}, } );
            return;
        }
    }

    my %search_attrs = (
        '+columns' => [ { user_count => { count => 'user.id', -as => 'user_count' } }, ],
        join     => { 'orders' => 'user' },
        group_by => [qw/ me.id /],
        order_by => { -asc     => 'me.date' },
    );

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
    my $dtf        = $self->DB->storage->datetime_parser;
    my $booking_rs = $self->DB->resultset('Booking')->search(
        {
            'me.id'     => { '!=' => undef },
            'me.gender' => $gender,
            'me.date'   => {
                -between => [ $dtf->format_datetime($dt_start), $dtf->format_datetime($dt_end), ],
            },
        },
        \%search_attrs,
    );

    my @booking_list = $booking_rs->all;
    unless (@booking_list) {
        $self->error( 404, { str => 'booking list not found', data => {}, } );
        return;
    }

    #
    # additional information for clothes list
    #
    my @data;
    #
    # [GH 279] 직원 전용 방문 예약은 인원 제한과 상관없이 예약 가능하게 함
    # [GH 548] 방문 예약시 예약 마감된 시간을 표시할 수 있도록 수정
    #
    for my $b (@booking_list) {
        my $flat = $self->flatten_booking($b);

        unless ( $self->is_user_authenticated
            && $self->current_user
            && $self->current_user->user_info
            && $self->current_user->user_info->staff )
        {
            next unless $flat->{slot} > 0;

            $flat->{id} = 0 unless $flat->{slot} > $flat->{user_count};
        }

        push @data, $flat;
    }

    return @data;
}

=head2 create_vbank( $tname, $code, $holder, $amount, $due, $order_id )

    my $json = $self->create_vbank('연장비', '04', '홍길동', '22000', time + 86400, 51183);

=cut

sub create_vbank {
    my ( $self, $tname, $code, $holder, $amount, $limit, $order_id ) = @_;

    my $order =
        $self->app->DB->resultset('Order')->find( { id => $order_id } );
    die "order not found\n" unless $order;

    my $user      = $order->user;
    my $user_info = $user->user_info;
    my $iamport   = $self->app->iamport;

    my $opt = {
        merchant_uid => $self->merchant_uid( "staff-%d-", $order->id ),
        amount       => $amount,
        vbank_due    => $limit,
        vbank_holder => $holder,
        vbank_code   => $code,
        name         => $tname . "#$order_id",
        buyer_name   => $user->name,
        buyer_email  => $user->email,
        buyer_tel    => $user_info->phone,
        buyer_addr   => $user_info->address2,
        notice_url => $self->url_for("/order/$order_id/unpaid/hook")->to_abs->to_string,
    };

    return $iamport->create_vbank($opt);
}

1;
