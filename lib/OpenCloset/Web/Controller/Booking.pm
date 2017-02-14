package OpenCloset::Web::Controller::Booking;
use Mojo::Base 'Mojolicious::Controller';

use DateTime;
use Try::Tiny;

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
            if ($order_obj) {
                my $msg = sprintf(
                    "%s님 %s 방문 예약이 취소되었습니다.",
                    $user->name, $order_obj->booking->date->strftime('%m월 %d일 %H시 %M분'),
                );
                $self->DB->resultset('SMS')->create(
                    {
                        to   => $user->user_info->phone,
                        from => $self->config->{sms}{ $self->config->{sms}{driver} }{_from},
                        text => $msg,
                    }
                ) or $self->app->log->warn("failed to create a new sms: $msg");

                $order_obj->delete;
            }
        }
        else {
            $user = $self->update_user( \%user_params, \%user_info_params );
            if ($user) {
                if ($booking_saved) {
                    #
                    # 이미 예약 정보가 저장되어 있는 경우 - 예약 변경 상황
                    #
                    my $order_obj = $self->DB->resultset('Order')->find($order);
                    if ($order_obj) {
                        #
                        # 쿠폰없이 예약했다가, 쿠폰을 사용해서 다시 예약을 했을때
                        #
                        my $coupon_id = $order_obj->coupon_id;
                        unless ($coupon_id) {
                            if ( my $code = delete $self->session->{coupon_code} ) {
                                my $coupon = $self->DB->resultset('Coupon')->find( { code => $code } );
                                $self->transfer_order( $coupon, $order_obj );
                            }
                        }

                        if ( $booking != $booking_saved ) {
                            #
                            # 변경한 예약 정보가 기존 정보와 다를 경우 갱신함
                            #
                            $order_obj->update( { booking_id => $booking } );
                        }

                        my $msg = sprintf(
                            "%s님 %s으로 방문 예약이 변경되었습니다.",
                            $user->name, $order_obj->booking->date->strftime('%m월 %d일 %H시 %M분'),
                        );
                        $self->DB->resultset('SMS')->create(
                            {
                                to   => $user->user_info->phone,
                                from => $self->config->{sms}{ $self->config->{sms}{driver} }{_from},
                                text => $msg,
                            }
                        ) or $self->app->log->warn("failed to create a new sms: $msg");
                    }
                }
                else {
                    #
                    # 예약 정보가 없는 경우 - 신규 예약 신청 상황
                    #
                    my $coupon_id;
                    if ( my $code = delete $self->session->{coupon_code} ) {
                        my $coupon = $self->DB->resultset('Coupon')->find( { code => $code } );
                        $coupon_id = $coupon->id if $self->transfer_order($coupon);
                    }

                    my $order_obj = $user->create_related(
                        'orders',
                        {
                            status_id  => 14,        # 방문예약: status 테이블 참조
                            booking_id => $booking,
                            coupon_id  => $coupon_id,
                        }
                    );
                    if ($order_obj) {
                        my $user_info = $user->user_info;
                        my $msg       = sprintf(
                            qq{%s님 %s으로 방문 예약이 완료되었습니다.
<열린옷장 위치안내>
서울특별시 광진구 아차산로 213 국민은행, 건대입구역 1번 출구로 나오신 뒤 오른쪽으로 꺾어 150M 가량 직진하시면 1층에 국민은행이 있는 건물 5층으로 올라오시면 됩니다. (도보로 약 3분 소요)
지도 안내: https://goo.gl/UuJyrx

예약시간 변경/취소는 %s 에서 가능합니다.

1. 지각은 NO!
꼭 예약 시간에 방문해주세요. 예약한 시간에 방문하지 못한 경우, 정시에 방문한 대여자를 먼저 안내하기 때문에 늦거나 일찍 온 시간만큼 대기시간이 길어집니다.

2. 노쇼(no show)금지
열린옷장은 하루에 방문 가능한 예약 인원이 정해져 있습니다. 방문이 어려운 경우 다른 분을 위해 반드시 '예약취소' 해주세요. 예약취소는 세 시간 전까지 가능합니다.},
                            $user->name,
                            $order_obj->booking->date->strftime('%m월 %d일 %H시 %M분'),
                            $self->url_for( '/order/' . $order_obj->id . '/booking/edit' )
                                ->query( phone => substr( $user_info->phone, -4 ) )->to_abs,
                        );

                        my $from = $self->config->{sms}{ $self->config->{sms}{driver} }{_from};
                        $self->DB->resultset('SMS')->create(
                            {
                                to   => $user->user_info->phone,
                                from => $from,
                                text => $msg,
                            }
                        ) or $self->app->log->warn("failed to create a new sms: $msg");

                        #
                        # 취업날개 예약시 신분증 관련한 문자 메세지를 보냄 (#1061)
                        #
                        if ( my $coupon = $order_obj->coupon ) {
                            my $desc = $coupon->desc || '';
                            if ( $desc =~ m/^seoul/ ) {
                                my $msg =
                                    "[열린옷장] 취업날개 서비스(면접정장 무료대여)는 주민등록상 '서울시'에 거주 중인 만18세 ~ 34세를 대상으로 합니다. 현장에서 이용조건의 증명이 불가능할 경우 무료 대여가 되지 않습니다. 따라서, 주소와 나이를 증명할 수 있는 신분증(주민등록증, 운전면허증)을 반드시 지참해주시기 바랍니다. 이용조건 증명을 할 수 있는 신분증이 없는 경우 본 서비스를 이용할 수 없다는 점을 거듭 안내드립니다. 감사합니다.";
                                $self->DB->resultset('SMS')->create(
                                    {
                                        to   => $user->user_info->phone,
                                        from => $from,
                                        text => $msg,
                                    }
                                ) or $self->app->log->warn("failed to create a new sms: $msg");
                            }
                        }
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

    $self->stash(
        load     => $self->config->{visit_load}, type => $type, user => $user,
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
            $order_obj->delete if $order_obj;
        }
        else {
            $user = $self->update_user( \%user_params, \%user_info_params );
            if ($user) {
                if ($booking_saved) {
                    #
                    # 이미 예약 정보가 저장되어 있는 경우 - 예약 변경 상황
                    #
                    my $order_obj = $self->DB->resultset('Order')->find($order);
                    if ($order_obj) {
                        if ( $booking != $booking_saved ) {
                            #
                            # 변경한 예약 정보가 기존 정보와 다를 경우 갱신함
                            #
                            $order_obj->update(
                                {
                                    booking_id => $booking,
                                    online     => $online,
                                }
                            );
                        }
                    }
                }
                else {
                    #
                    # 예약 정보가 없는 경우 - 신규 예약 신청 상황
                    #
                    my $order_obj = $user->create_related(
                        'orders',
                        {
                            status_id  => 14,      # 방문예약: status 테이블 참조
                            booking_id => $booking,
                            online     => $online,
                        }
                    );
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
