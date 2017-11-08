package OpenCloset::Web::Controller::Booking;
use Mojo::Base 'Mojolicious::Controller';

use DateTime;
use HTTP::Tiny;
use Try::Tiny;
use Mojo::JSON qw/decode_json/;

use OpenCloset::Calculator::LateFee;
use OpenCloset::Common::Unpaid ();
use OpenCloset::Constants::Status qw/$RESERVATED/;

has DB => sub { shift->app->DB };

=head1 METHODS

=head2 index

    GET /booking

=cut

sub index {
    my $self = shift;

    my $dt_today = DateTime->now( time_zone => $self->config->{timezone} );
    $self->redirect_to( $self->url_for( '/booking/' . $dt_today->ymd ) );
}

=head2 visit

    any /visit

=cut

sub visit {
    my $self = shift;

    my $type     = $self->param('type') || q{};
    my $name     = $self->param('name');
    my $phone    = $self->param('phone');
    my $service  = $self->param('service');
    my $privacy  = $self->param('privacy');
    my $authcode = $self->param('sms');

    my $email         = $self->param('email');
    my $gender        = $self->param('gender');
    my $address1      = $self->param('address1');
    my $address2      = $self->param('address2');
    my $address3      = $self->param('address3');
    my $address4      = $self->param('address4');
    my $birth         = $self->param('birth');
    my $order         = $self->param('order');
    my $booking       = $self->param('booking');
    my $booking_saved = $self->param('booking-saved');
    my $wearon_date   = $self->param('wearon_date');
    my $purpose       = $self->param('purpose');
    my $purpose2      = $self->param('purpose2');
    my $pre_category  = $self->param('pre_category');
    my $pre_color     = $self->param('pre_color');
    my $agent         = $self->param('agent') || 0;
    my $agent_qty     = $self->param('agent-quantity') || 1;
    my $past_order    = $self->param('past-order') || '';

    $self->app->log->debug("type: $type");
    $self->app->log->debug("name: $name");
    $self->app->log->debug("phone: $phone");
    $self->app->log->debug("service: $service");
    $self->app->log->debug("privacy: $privacy");
    $self->app->log->debug("sms: $authcode");

    $self->app->log->debug("email: $email");
    $self->app->log->debug("gender: $gender");
    $self->app->log->debug("address1: $address1");
    $self->app->log->debug("address2: $address2");
    $self->app->log->debug("address3: $address3");
    $self->app->log->debug("address4: $address4");
    $self->app->log->debug("birth: $birth");
    $self->app->log->debug("order: $order");
    $self->app->log->debug("booking: $booking");
    $self->app->log->debug("booking-saved: $booking_saved");
    $self->app->log->debug("wearon_date: $wearon_date");
    $self->app->log->debug("purpose: $purpose");
    $self->app->log->debug("purpose2: $purpose2");
    $self->app->log->debug("pre_category: $pre_category");
    $self->app->log->debug("pre_color: $pre_color");
    $self->app->log->debug("agent: $agent");
    $self->app->log->debug("agent-quantity: $agent_qty");
    $self->app->log->debug("past-order: $past_order");

    #
    # validate name
    #
    if ( $name =~ m/(^\s+|\s+$)/ ) {
        $self->app->log->warn("name includes trailing space: [$name]");
        $self->stash( alert => '이름에 빈 칸이 들어있습니다.' );
        return;
    }

    #
    # find user
    #
    my @users = $self->DB->resultset('User')->search(
        { 'me.name' => $name, 'user_info.phone' => $phone, },
        { join      => 'user_info' },
    );
    my $user = shift @users;
    unless ($user) {
        $self->app->log->warn('user not found');
        return;
    }
    unless ( $user->user_info ) {
        $self->app->log->warn('user_info not found');
        return;
    }

    #
    # validate code
    #
    my $now = DateTime->now( time_zone => $self->config->{timezone} )->epoch;
    unless ( $user->expires && $user->expires > $now ) {
        $self->log->warn( $user->email . "\'s authcode is expired" );
        $self->stash( alert => '인증코드가 만료되었습니다.' );
        return;
    }
    if ( $user->authcode ne $authcode ) {
        $self->log->warn( $user->email . "\'s authcode is wrong" );
        $self->stash( alert => '인증코드가 유효하지 않습니다.' );
        return;
    }

    $self->stash( order => $self->get_nearest_booked_order($user) );
    $self->stash( coupon => undef );
    if ( $type eq 'visit' ) {
        #
        # GH #253
        #
        #   사용자가 동일 시간대 중복 방문 예약할 수 있는 경우를 방지하기 위해
        #   예약 관련 신청/변경/취소 요청이 들어오면 인증 번호를 검증한 후
        #   강제로 만료시킵니다.
        #
        $user->update( { expires => $now } );

        #
        # 예약 신청/변경/취소
        #

        my %user_params;
        my %user_info_params;

        $user_params{id}          = $user->id;
        $user_params{email}       = $email if $email && $email ne $user->email;
        $user_info_params{gender} = $gender
            if $gender && $gender ne $user->user_info->gender;
        $user_info_params{address1} = $address1
            if $address1 && $address1 ne $user->user_info->address1;
        $user_info_params{address2} = $address2
            if $address2 && $address2 ne $user->user_info->address2;
        $user_info_params{address3} = $address3
            if $address3 && $address3 ne $user->user_info->address3;
        $user_info_params{address4} = $address4
            if $address4 && $address4 ne $user->user_info->address4;
        $user_info_params{birth} = $birth if $birth && $birth ne $user->user_info->birth;
        $user_info_params{wearon_date} = $wearon_date
            if $wearon_date && $wearon_date ne $user->user_info->wearon_date;
        $user_info_params{purpose} = $purpose
            if $purpose && $purpose ne $user->user_info->purpose;
        $user_info_params{purpose2} = $purpose2 || q{};
        $user_info_params{pre_category} = $pre_category
            if $pre_category && $pre_category ne $user->user_info->pre_category;
        $user_info_params{pre_color} = $pre_color
            if $pre_color && $pre_color ne $user->user_info->pre_color;

        #
        # tune pre_category
        #
        if ( $user_info_params{pre_category} ) {
            my $items_str = $user_info_params{pre_category};
            my @items = grep { $_ } map { s/^\s+|\s+$//g; $_ } split /,/, $items_str;
            $user_info_params{pre_category} = join q{,}, @items;
        }

        #
        # tune pre_color
        #
        if ( $user_info_params{pre_color} ) {
            my $items_str = $user_info_params{pre_color};
            my @items = grep { $_ } map { s/^\s+|\s+$//g; $_ } split /,/, $items_str;
            $user_info_params{pre_color} = join q{,}, @items;
        }

        if ( $booking == -1 ) {
            #
            # 예약 취소
            #
            my $order_obj = $self->DB->resultset('Order')->find($order);
            $self->app->api->cancel($order_obj);
        }
        else {
            $user = $self->update_user( \%user_params, \%user_info_params );
            if ($user) {
                if ($booking_saved) {
                    #
                    # 이미 예약 정보가 저장되어 있는 경우 - 예약 변경 상황
                    #
                    my %extra = (
                        agent  => $agent,
                        ignore => $agent ? 1 : undef,
                    );

                    my $order_obj = $self->DB->resultset('Order')->find($order);
                    if ($order_obj) {
                        unless ( $order_obj->coupon_id ) {
                            if ( my $code = delete $self->session->{coupon_code} ) {
                                $extra{coupon} = $self->DB->resultset('Coupon')->find( { code => $code } );
                            }
                        }

                        my $booking_obj = $self->DB->resultset('Booking')->find( { id => $booking } );
                        $self->app->api->update_reservated(
                            $order_obj,
                            $booking_obj->date,
                            %extra,
                        );
                    }
                }
                else {
                    #
                    # 예약 정보가 없는 경우 - 신규 예약 신청 상황
                    #
                    my %extra = (
                        past_order => $past_order,
                        agent      => $agent,
                        ignore     => $agent ? 1 : undef,
                    );

                    if ( my $code = delete $self->session->{coupon_code} ) {
                        $extra{coupon} = $self->DB->resultset('Coupon')->find( { code => $code } );
                    }

                    my $booking_obj = $self->DB->resultset('Booking')->find( { id => $booking } );
                    my $order_obj = $self->app->api->reservated( $user, $booking_obj->date, %extra );

                    #
                    # 대리인을 통한 대여일때는 대리인의 신체치수 입력화면으로 이동
                    #
                    if ( $order_obj and $order_obj->agent ) {
                        my $id = $order_obj->id;
                        $self->session( agent_quantity => $agent_qty );
                        return $self->redirect_to("/orders/$id/agent");
                    }
                }
            }
            else {
                my $error_msg = "유효하지 않은 정보입니다: " . $self->stash('error');
                $self->app->log->warn($error_msg);
                $self->stash( alert => $error_msg );
            }
        }
    }
    elsif ( $type eq 'visit-info' ) {
        #
        # GH #1197
        #
        # 미납(unpaid):  order.late_fee_pay_with = '미납' OR order.compensation_pay_with = '미납'
        # 불납(nonpaid): order_detail.stage = 4
        my $unpaid_order = $self->DB->resultset('Order')->search(
            {
                user_id => $user->id,
                -or     => [
                    { late_fee_pay_with     => '미납' },
                    { compensation_pay_with => '미납' },
                ]
            },
            {
                rows     => 1,
                order_by => { -desc => 'id' }
            }
        )->single;

        my $unpaid_msg = '';
        if ($unpaid_order) {
            my $calc        = OpenCloset::Calculator::LateFee->new;
            my $late_fee    = $calc->late_fee($unpaid_order);
            my $rental_date = $unpaid_order->rental_date;
            my $user_info   = $user->user_info;
            my $today       = DateTime->today( time_zone => $self->config->{timezone} );
            my $vbank_due   = $today->clone->add( days => 4 );
            my $params      = {
                merchant_uid =>
                    OpenCloset::Common::Unpaid::merchant_uid( "staff-%d-", $unpaid_order->id ),
                amount       => $late_fee,
                vbank_due    => $vbank_due->epoch,
                vbank_holder => '열린옷장-' . $user->name,
                vbank_code   => '04',                                        # 국민은행
                name         => sprintf( "미납금#%d", $unpaid_order->id ),
                buyer_name   => $user->name,
                buyer_email  => $user->email,
                buyer_tel    => $user_info->phone,
                buyer_addr   => $user_info->address2 || '',
                'notice_url[]' =>
                    $self->url_for("https://staff.theopencloset.net/webhooks/iamport/unpaid")
                    ->to_abs->to_string,
            };

            my ( $log, $error ) = OpenCloset::Common::Unpaid::create_vbank(
                $self->app->iamport, $unpaid_order,
                $params
            );

            if ($log) {
                my $data         = decode_json( $log->detail );
                my $vbank_name   = $data->{response}{vbank_name};
                my $vbank_num    = $data->{response}{vbank_num};
                my $vbank_holder = $data->{response}{vbank_holder};
                my $msg          = $self->render_to_string(
                    "sms/unpaid-on-booking",
                    format       => 'txt',
                    name         => $user->name,
                    rental_date  => $rental_date->strftime('%Y년 %m월 %d일'),
                    late_fee     => $self->commify($late_fee),
                    vbank_name   => $vbank_name,
                    vbank_num    => $vbank_num,
                    vbank_holder => $vbank_holder,
                );

                chomp $msg;
                $self->sms( $user_info->phone, $msg );
                $unpaid_msg = $msg;
            }
            else {
                $self->log->error("Failed to create vbank: $error");
            }
        }

        if ( $self->session->{coupon_code} ) {
            my $coupon = $self->DB->resultset("Coupon")->find( { code => $self->session->{coupon_code} } );
            $self->stash( coupon => $coupon );
        }

        $self->stash( unpaid_msg => $unpaid_msg );
    }

    my $orders = $user->orders(
        { rental_date => { '!='  => undef } },
        { order_by    => { -desc => 'id' } }
    );

    $self->stash(
        load     => $self->config->{visit_load},
        type     => $type,
        user     => $user,
        orders   => $orders,
        authcode => $authcode,
    );
}

=head2 visit2

    any /visit2

=cut

sub visit2 {
    my $self = shift;

    my $type   = $self->param('type') || q{};
    my $name   = $self->param('name');
    my $phone  = $self->param('phone');
    my $online = $self->param('online');

    my $email         = $self->param('email');
    my $gender        = $self->param('gender');
    my $address1      = $self->param('address1');
    my $address2      = $self->param('address2');
    my $address3      = $self->param('address3');
    my $address4      = $self->param('address4');
    my $birth         = $self->param('birth');
    my $order         = $self->param('order');
    my $booking       = $self->param('booking');
    my $booking_saved = $self->param('booking-saved');
    my $wearon_date   = $self->param('wearon_date');
    my $purpose       = $self->param('purpose');
    my $purpose2      = $self->param('purpose2');
    my $pre_category  = $self->param('pre_category');
    my $pre_color     = $self->param('pre_color');

    $self->app->log->debug("type: $type");
    $self->app->log->debug("name: $name");
    $self->app->log->debug("phone: $phone");
    $self->app->log->debug("online: $online");

    $self->app->log->debug("email: $email");
    $self->app->log->debug("gender: $gender");
    $self->app->log->debug("address1: $address1");
    $self->app->log->debug("address2: $address2");
    $self->app->log->debug("address3: $address3");
    $self->app->log->debug("address4: $address4");
    $self->app->log->debug("birth: $birth");
    $self->app->log->debug("order: $order");
    $self->app->log->debug("booking: $booking");
    $self->app->log->debug("booking-saved: $booking_saved");
    $self->app->log->debug("wearon_date $wearon_date");
    $self->app->log->debug("purpose: $purpose");
    $self->app->log->debug("purpose2: $purpose2");
    $self->app->log->debug("pre_category: $pre_category");
    $self->app->log->debug("pre_color: $pre_color");

    #
    # validate name
    #
    if ( $name =~ m/(^\s+|\s+$)/ ) {
        $self->app->log->warn("name includes trailing space: [$name]");
        $self->stash( alert => '이름에 빈 칸이 들어있습니다.' );
        return;
    }

    #
    # find user
    #
    my @users = $self->DB->resultset('User')->search(
        { 'me.name' => $name, 'user_info.phone' => $phone, },
        { join      => 'user_info' },
    );
    my $user = shift @users;
    unless ($user) {
        $self->app->log->warn('user not found');
        $self->stash( alert =>
                '이름과 휴대전화가 일치하는 사용자를 찾을 수 없습니다.' )
            if $name || $phone;
        return;
    }
    unless ( $user->user_info ) {
        $self->app->log->warn('user_info not found');
        $self->stash( alert =>
                '사용자 정보에 문제가 있습니다. 관리자에게 문의해주세요.'
        ) if $name || $phone;
        return;
    }

    $self->stash( order => $self->get_nearest_booked_order($user) );
    if ( $type eq 'visit' ) {
        #
        # 예약 신청/변경/취소
        #

        my %user_params;
        my %user_info_params;

        $user_params{id}          = $user->id;
        $user_params{email}       = $email if $email && $email ne $user->email;
        $user_info_params{gender} = $gender
            if $gender && $gender ne $user->user_info->gender;
        $user_info_params{address1} = $address1
            if $address1 && $address1 ne $user->user_info->address1;
        $user_info_params{address2} = $address2
            if $address2 && $address2 ne $user->user_info->address2;
        $user_info_params{address3} = $address3
            if $address3 && $address3 ne $user->user_info->address3;
        $user_info_params{address4} = $address4
            if $address4 && $address4 ne $user->user_info->address4;
        $user_info_params{birth} = $birth if $birth && $birth ne $user->user_info->birth;
        $user_info_params{wearon_date} = $wearon_date
            if $wearon_date && $wearon_date ne $user->user_info->wearon_date;
        $user_info_params{purpose} = $purpose
            if $purpose && $purpose ne $user->user_info->purpose;
        $user_info_params{purpose2} = $purpose2 || q{};
        $user_info_params{pre_category} = $pre_category
            if $pre_category && $pre_category ne $user->user_info->pre_category;
        $user_info_params{pre_color} = $pre_color
            if $pre_color && $pre_color ne $user->user_info->pre_color;

        #
        # tune pre_category
        #
        if ( $user_info_params{pre_category} ) {
            my $items_str = $user_info_params{pre_category};
            my @items = grep { $_ } map { s/^\s+|\s+$//g; $_ } split /,/, $items_str;
            $user_info_params{pre_category} = join q{,}, @items;
        }

        #
        # tune pre_color
        #
        if ( $user_info_params{pre_color} ) {
            my $items_str = $user_info_params{pre_color};
            my @items = grep { $_ } map { s/^\s+|\s+$//g; $_ } split /,/, $items_str;
            $user_info_params{pre_color} = join q{,}, @items;
        }

        if ( $booking == -1 ) {
            #
            # 예약 취소
            #
            my $order_obj = $self->DB->resultset('Order')->find($order);
            $self->app->api->cancel($order_obj);
        }
        else {
            $user = $self->update_user( \%user_params, \%user_info_params );
            if ($user) {
                if ($booking_saved) {
                    #
                    # 이미 예약 정보가 저장되어 있는 경우 - 예약 변경 상황
                    #
                    my %extra = ( online => $online );
                    my $order_obj = $self->DB->resultset('Order')->find($order);
                    if ($order_obj) {
                        unless ( $order_obj->coupon_id ) {
                            if ( my $code = delete $self->session->{coupon_code} ) {
                                $extra{coupon} = $self->DB->resultset('Coupon')->find( { code => $code } );
                            }
                        }

                        my $booking_obj = $self->DB->resultset('Booking')->find( { id => $booking } );
                        $self->app->api->update_reservated(
                            $order_obj,
                            $booking_obj->date,
                            %extra,
                        );
                    }
                }
                else {
                    #
                    # 예약 정보가 없는 경우 - 신규 예약 신청 상황
                    #
                    my %extra = ( online => $online );
                    if ( my $code = delete $self->session->{coupon_code} ) {
                        $extra{coupon} = $self->DB->resultset('Coupon')->find( { code => $code } );
                    }

                    my $booking_obj = $self->DB->resultset('Booking')->find( { id => $booking } );
                    my $order_obj = $self->app->api->reservated( $user, $booking_obj->date, %extra );
                }
            }
            else {
                my $error_msg = "유효하지 않은 정보입니다: " . $self->stash('error');
                $self->app->log->warn($error_msg);
                $self->stash( alert => $error_msg );
            }
        }
    }

    $self->stash( load => $self->config->{visit_load}, type => $type, user => $user, );
}

=head2 ymd

    GET /booking/:ymd

=cut

sub ymd {
    my $self = shift;

    #
    # fetch params
    #
    my %params = $self->get_params(qw/ ymd /);

    unless ( $params{ymd} ) {
        $self->app->log->warn("ymd is required");
        $self->redirect_to( $self->url_for('/booking') );
        return;
    }

    unless ( $params{ymd} =~ m/^(\d{4})-(\d{2})-(\d{2})$/ ) {
        $self->app->log->warn("invalid ymd format: $params{ymd}");
        $self->redirect_to( $self->url_for('/booking') );
        return;
    }

    my $dt_start = try {
        DateTime->new(
            time_zone => $self->config->{timezone}, year => $1, month => $2,
            day       => $3,
        );
    };
    unless ($dt_start) {
        $self->app->log->warn("cannot create start datetime object");
        $self->redirect_to( $self->url_for('/booking') );
        return;
    }

    my $dt_end = $dt_start->clone->add( hours => 24, seconds => -1 );
    unless ($dt_end) {
        $self->app->log->warn("cannot create end datetime object");
        $self->redirect_to( $self->url_for('/booking') );
        return;
    }

    my $dtf        = $self->DB->storage->datetime_parser;
    my $booking_rs = $self->DB->resultset('Booking')->search(
        {
            date => {
                -between => [ $dtf->format_datetime($dt_start), $dtf->format_datetime($dt_end), ],
            },
        },
        { order_by => { -asc => 'date' }, },
    );

    $self->render(
        booking_rs => $booking_rs,
        dt_start   => $dt_start,
        dt_end     => $dt_end,
    );
}

=head2 open

    GET /booking/:ymd/open

=cut

sub open {
    my $self = shift;

    #
    # fetch params
    #
    my %params = $self->get_params(qw/ ymd /);

    unless ( $params{ymd} ) {
        $self->app->log->warn("ymd is required");
        $self->redirect_to( $self->url_for('/booking') );
        return;
    }

    unless ( $params{ymd} =~ m/^(\d{4})-(\d{2})-(\d{2})$/ ) {
        $self->app->log->warn("invalid ymd format: $params{ymd}");
        $self->redirect_to( $self->url_for('/booking') );
        return;
    }

    my $dt_start = try {
        DateTime->new(
            time_zone => $self->config->{timezone}, year => $1, month => $2,
            day       => $3,
        );
    };
    unless ($dt_start) {
        $self->app->log->warn("cannot create start datetime object");
        $self->redirect_to( $self->url_for('/booking') );
        return;
    }

    #
    # GH #164
    #
    #   열린옷장 휴무일(일, 월요일)일 경우 슬롯을 0으로 강제합니다.
    #
    #   DateTime->day_of_week은 요일을 반환하며
    #   1은 월요일 7은 일요일 입니다.
    #
    # GH #460
    #
    #   열린옷장 휴무일을 기존 일, 월요일에서 일요일만으로 한정합니다.
    #
    # GH #618
    #
    #  월요일 예약 슬롯을 2~3명으로 조정하기 위해
    #  설정 및 처리 방식을 완전히 변경합니다.
    #

    my %map_day_of_week = (
        1 => 'mon', 2 => 'tue', 3 => 'wed', 4 => 'thu', 5 => 'fri', 6 => 'sat',
        7 => 'sun',
    );

    my $day_of_week = $map_day_of_week{ $dt_start->day_of_week };
    for my $gender (qw/ male female /) {
        for my $key ( sort keys %{ $self->config->{booking}{$day_of_week}{$gender} } ) {
            my $value = $self->config->{booking}{$day_of_week}{$gender}{$key} || 0;

            my ( $h, $m ) = split /:/, $key, 2;
            my $dt = $dt_start->clone;
            $dt->set_hour($h);
            $dt->set_minute($m);

            my $dtf = $self->DB->storage->datetime_parser;
            $self->DB->resultset('Booking')
                ->find_or_create(
                { date => $dtf->format_datetime($dt), gender => $gender, slot => $value, } );
        }
    }

    $self->redirect_to( $self->url_for( '/booking/' . $dt_start->ymd ) );
}

1;
