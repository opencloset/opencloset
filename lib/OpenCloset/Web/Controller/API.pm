package OpenCloset::Web::Controller::API;
use Mojo::Base 'Mojolicious::Controller';
use Mojo::JSON;

use DateTime;
use Encode qw/decode_utf8/;
use HTTP::Body::Builder::MultiPart;
use HTTP::Tiny;
use Path::Tiny ();
use Postcodify;
use String::Random;
use Try::Tiny;

use OpenCloset::Constants::Status qw/$LOST $DISCARD/;

has DB => sub { shift->app->DB };

=head1 METHODS

=head2 create_user

    POST /api/user

=cut

sub api_create_user {
    my $self = shift;

    #
    # fetch params
    #
    my %user_params = $self->get_params(
        qw/
            name
            email
            password
            create_date
            update_date
            /
    );
    my %user_info_params = $self->get_params(
        qw/
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
            neck
            pants
            phone
            purpose
            purpose2
            thigh
            topbelly
            waist
            wearon_date
            weight
            /
    );

    #
    # validate params
    #
    my $v = $self->create_validator;
    $v->field('name')->required(1)->trim(0)->callback(
        sub {
            my $value = shift;

            return 1 unless $value =~ m/(^\s+|\s+$)/;
            return ( 0, "name has trailing space" );
        }
    );
    $v->field('email')->email;
    $v->field('phone')->regexp(qr/^\d+$/);
    $v->field('gender')->in(qw/ male female /);
    $v->field('birth')->regexp(qr/^(19|20)\d{2}$/);
    $v->field(
        qw/ height weight neck bust waist hip topbelly belly thigh arm leg knee foot pants /
        )->each(
        sub {
            shift->regexp(qr/^\d{1,3}$/);
        }
        );
    unless ( $self->validate( $v, { %user_params, %user_info_params } ) ) {
        my @error_str;
        while ( my ( $k, $v ) = each %{ $v->errors } ) {
            push @error_str, "$k:$v";
        }
        return $self->error( 400, { str => join( ',', @error_str ), data => $v->errors, } );
    }

    #
    # create user
    #
    my $user = do {
        my $guard = $self->DB->txn_scope_guard;

        my %_user_params = %user_params;
        if ( $_user_params{create_date} ) {
            $_user_params{create_date} = DateTime->from_epoch(
                epoch => $_user_params{create_date}, time_zone => $self->config->{timezone},
            );
        }
        if ( $_user_params{update_date} ) {
            $_user_params{update_date} = DateTime->from_epoch(
                epoch => $_user_params{update_date}, time_zone => $self->config->{timezone},
            );
        }

        my $user = $self->DB->resultset('User')->create( \%_user_params );
        return $self->error( 500, { str => 'failed to create a new user', data => {}, } )
            unless $user;

        my $user_info = $self->DB->resultset('UserInfo')
            ->create( { %user_info_params, user_id => $user->id, } );
        return $self->error(
            500,
            { str => 'failed to create a new user info', data => {}, }
        ) unless $user_info;

        $guard->commit;

        $user;
    };

    #
    # response
    #
    my %data = ( $user->user_info->get_columns, $user->get_columns );
    delete @data{qw/ user_id password /};

    $self->res->headers->header(
        'Location' => $self->url_for( '/api/user/' . $user->id ), );
    $self->respond_to( json => { status => 201, json => \%data } );
}

=head2 get_user

    GET /api/user/:id

=cut

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

=head2 update_user

    PUT /api/user/:id

=cut

sub api_update_user {
    my $self = shift;

    #
    # fetch params
    #
    my %user_params = $self->get_params(
        qw/
            id
            name
            email
            password
            expires
            create_date
            update_date
            /
    );
    my %user_info_params = $self->get_params(
        qw/
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
            neck
            pants
            phone
            pre_category
            pre_color
            purpose
            purpose2
            staff
            thigh
            topbelly
            waist
            wearon_date
            weight
            /
    );

    #
    # GitHub #199
    #
    # 패스워드 수정 요청이지만 만료 시간을 지정하지 않았을 경우
    # 기본 값으로 1개월 뒤를 만료 시간으로 설정합니다.
    #
    if ( $user_params{password} && !$user_params{expires} ) {
        $user_params{expires} =
            DateTime->now( time_zone => $self->config->{timezone} )->add( months => 1 )
            ->epoch;
    }

    my ( $user, $msg ) = try {
        $self->update_user( \%user_params, \%user_info_params );
    }
    catch {
        chomp;
        my $err = $_;

        $err = $1 if $err =~ m/(Duplicate entry .*? for key '.*?')/;

        ( undef, $err );
    };
    unless ($user) {
        $self->app->log->error("failed to update the user: $msg");
        $self->respond_to( json => { status => 400, json => { error => $msg } } );
        return;
    }

    #
    # response
    #
    my $data = $self->flatten_user($user);

    $self->respond_to( json => { status => 200, json => $data } );
}

=head2 delete_user

    DELETE /api/user/:id

=cut

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
        return $self->error( 400, { str => join( ',', @error_str ), data => $v->errors, } );
    }

    #
    # find user
    #
    my $user = $self->DB->resultset('User')->find( \%params );
    return $self->error( 404, { str => 'user not found', data => {}, } ) unless $user;

    #
    # delete & response
    #
    my %data = ( $user->user_info->get_columns, $user->get_columns );
    delete @data{qw/ user_id password /};
    $user->delete;

    $self->respond_to( json => { status => 200, json => \%data } );
}

=head2 api_search_clothes_user

    GET /api/user/:id/search/clothes

=cut

sub api_search_clothes_user {
    my $self = shift;
    my $id   = $self->param('id');

    my $user = $self->get_user( { id => $id } );
    return $self->error( 404, { str => "User not found: $id" } ) unless $user;

    my $result = $self->search_clothes($id);
    return $self->render unless $result;

    my $guess = shift @$result;
    my @result = map { [ @{$_}{qw/upper_code lower_code rss rent_count/} ] } @$result;
    $self->respond_to( json => { json => { guess => $guess, result => [@result] } } );
}

=head2 api_user_list

    GET /api/user-list

=cut

sub api_user_list {
    my $self = shift;
}

=head2 create_order

    POST /api/order

=cut

sub api_create_order {
    my $self = shift;

    #
    # fetch params
    #
    my %order_params = $self->get_params(
        qw/
            additional_day
            arm
            belly
            bestfit
            bust
            compensation_pay_with
            desc
            foot
            height
            hip
            knee
            late_fee_pay_with
            leg
            message
            neck
            pants
            parent_id
            price_pay_with
            purpose
            purpose2
            rental_date
            return_date
            return_method
            return_memo
            staff_id
            status_id
            target_date
            thigh
            topbelly
            user_id
            user_target_date
            waist
            wearon_date
            weight
            /
    );
    my %order_detail_params = $self->get_params(
        [ order_detail_clothes_code => 'clothes_code' ],
        [ order_detail_status_id    => 'status_id' ],
        [ order_detail_name         => 'name' ],
        [ order_detail_price        => 'price' ],
        [ order_detail_final_price  => 'final_price' ],
        [ order_detail_desc         => 'desc' ],
    );
    my $order = $self->create_order( \%order_params, \%order_detail_params );
    return unless $order;

    #
    # response
    #
    my $data = $self->flatten_order($order);

    $self->res->headers->header(
        'Location' => $self->url_for( '/api/order/' . $order->id ), );
    $self->respond_to( json => { status => 201, json => $data } );
}

=head2 get_order

    GET /api/order/:id

=cut

sub api_get_order {
    my $self = shift;

    #
    # fetch params
    #
    my %params = $self->get_params(qw/ id today /);

    #
    # validate params
    #
    my $v = $self->create_validator;
    $v->field('today')->regexp(qr/^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}$/);
    unless ( $self->validate( $v, \%params ) ) {
        my @error_str;
        while ( my ( $k, $v ) = each %{ $v->errors } ) {
            push @error_str, "$k:$v";
        }
        return $self->error( 400, { str => join( ',', @error_str ), data => $v->errors, } );
    }

    my $order = $self->get_order( \%params );
    return unless $order;

    #
    # response
    #
    my $data = $self->flatten_order( $order, $params{today} );

    $self->respond_to( json => { status => 200, json => $data } );
}

=head2 update_order

    PUT /api/order/:id

=cut

sub api_update_order {
    my $self = shift;

    #
    # fetch params
    #
    my %order_params = $self->get_params(
        qw/
            additional_day
            arm
            belly
            bestfit
            bust
            compensation_pay_with
            desc
            does_wear
            foot
            height
            hip
            id
            ignore
            ignore_sms
            knee
            late_fee_pay_with
            leg
            message
            neck
            pants
            parent_id
            pass
            price_pay_with
            purpose
            purpose2
            rental_date
            return_date
            return_memo
            return_method
            staff_id
            status_id
            target_date
            thigh
            topbelly
            user_id
            user_target_date
            waist
            wearon_date
            weight
            /
    );
    my %order_detail_params = $self->get_params(
        [ order_detail_id           => 'id' ],
        [ order_detail_clothes_code => 'clothes_code' ],
        [ order_detail_status_id    => 'status_id' ],
        [ order_detail_name         => 'name' ],
        [ order_detail_price        => 'price' ],
        [ order_detail_final_price  => 'final_price' ],
        [ order_detail_desc         => 'desc' ],
    );

    my $order = $self->update_order( \%order_params, \%order_detail_params );
    return unless $order;

    #
    # response
    #
    my $data = $self->flatten_order($order);

    $self->respond_to( json => { status => 200, json => $data } );
}

=head2 delete_order

    DELETE /api/order/:id

=cut

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

=head2 update_order_unpaid

    PUT /api/order/:id/unpaid

=cut

sub api_update_order_unpaid {
    my $self = shift;

    #
    # fetch params
    #
    my %params = $self->get_params(
        qw/
            id
            price
            pay_with
            /
    );

    #
    # validate params
    #
    my $v = $self->create_validator;
    $v->field('id')->required(1)->regexp(qr/^\d+$/);
    $v->field('price')->required(1)->regexp(qr/^\d+$/);
    unless ( $self->validate( $v, \%params ) ) {
        my @error_str;
        while ( my ( $k, $v ) = each %{ $v->errors } ) {
            push @error_str, "$k:$v";
        }
        return $self->error( 400, { str => join( ',', @error_str ), data => $v->errors, } );
    }

    my $id       = $params{id};
    my $price    = $params{price} || 0;
    my $pay_with = $params{pay_with} || q{};

    #
    # find order
    #
    my ( $cond_ref, $attr_ref ) = $self->get_dbic_cond_attr_unpaid;
    $cond_ref->{id} = $id;
    my $order = $self->DB->resultset('Order')->find( $cond_ref, $attr_ref );
    return $self->error( 404, { str => 'unpaid order not found', data => {}, } )
        unless $order;

    #
    # stage
    #
    # - 연장: 1
    # - 배상: 2
    # - 환불: 3
    # - 불납: 4
    # - 완납: 5
    # - 부분완납: 6
    #

    #
    # 연장
    #
    my $unpaid_late_fee = 0;
    if ( $order->late_fee_pay_with eq '미납' ) {
        for my $od ( $order->order_details->search( { stage => 1 } )->all ) {
            $unpaid_late_fee += $od->final_price;
        }

    }

    #
    # 배상
    #
    my $unpaid_compensation_pay = 0;
    if ( $order->compensation_pay_with eq '미납' ) {
        for my $od ( $order->order_details->search( { stage => 2 } )->all ) {
            $unpaid_compensation_pay += $od->final_price;
        }
    }

    #
    # 미납금 = 미납 연장료 + 미납 배상료
    #
    my $unpaid = $unpaid_late_fee + $unpaid_compensation_pay;

    $self->app->log->info( '미납금.연장료: ' . $self->commify($unpaid_late_fee) );
    $self->app->log->info(
        '미납금.배상료: ' . $self->commify($unpaid_compensation_pay) );
    $self->app->log->info( '미납금.총합: ' . $self->commify($unpaid) );

    #
    # 완납 / 부분완납 / 불납 구분
    #
    my $stage;
    my $od_name = q{};
    if ($price) {
        if ( $price == $unpaid ) {
            $stage   = 5;
            $od_name = '완납';
        }
        else {
            $stage   = 6;
            $od_name = '부분완납';
        }
    }
    else {
        $stage   = 4;
        $od_name = '불납';
    }

    $self->app->log->info("미납금.상태: $od_name");
    $self->app->log->info("미납금.지불방식: $pay_with");
    $self->app->log->info("미납금.받은금액: $price");

    #
    # TRANSACTION:
    #
    my ( $ret, $status, $error ) = do {
        my $guard = $self->DB->txn_scope_guard;
        try {
            #
            # 미납 주문서의 경우 주문서 표시 금액보다 적은 금액을 받았기 때문에
            # 실제 열린옷장에서 현재 시점 기준 받은 금액으로 맞춰주기 위해
            # 미납료 만큼을 제거하는 항목 추가
            #
            # 예)
            # 3만원 주문서에 2만원 연장료와 5만원 배상료가 나왔을 경우
            # 주문서상으로 10만원을 받은 것으로 표시되지만 실제로는 3만원만
            # 받은 상태입니다. 따라서 주문서에 -7만원을 표시해서 결과적으로
            # 3만원만을 현재 받은 것으로 계산하기 위한 항목을 추가합니다.
            #
            {
                my $od = $self->create_order_detail(
                    {
                        order_id    => $order->id,
                        name        => '미납금 총합',
                        price       => -($unpaid),
                        final_price => -($unpaid),
                        stage       => $stage,
                        desc        => sprintf(
                            "미납금 = 연장료 + 배상료 ( %s = %s + %s )",
                            $self->commify($unpaid), $self->commify($unpaid_late_fee),
                            $self->commify($unpaid_compensation_pay),
                        ),
                    }
                );
                die "failed to create a new order_detail: unpaid\n" unless $od;
            }

            #
            # 받은 금액 표시 및 완납 / 부분완납 / 불납 여부 표시
            #
            {
                my $od = $self->create_order_detail(
                    {
                        order_id    => $order->id,
                        name        => $od_name,
                        price       => $price,
                        final_price => $price,
                        stage       => $stage,
                        desc        => sprintf(
                            "결제방식(%s), 포기금액(%s), 미납금 중 대여자로부터 받은 최종 금액",
                            $pay_with, $self->commify( $unpaid - $price ),
                        ),
                        pay_with => $pay_with,
                    }
                );
                die "failed to create a new order_detail: final user paid\n" unless $od;
            }

            #
            # 주문서의 연장료 납부 방식 및 배상료 납부 방식 갱신
            #
            {
                my %order_params;
                if ( $order->late_fee_pay_with eq '미납' ) {
                    $order_params{late_fee_pay_with} = $pay_with;
                }
                if ( $order->compensation_pay_with eq '미납' ) {
                    $order_params{compensation_pay_with} = $pay_with;
                }
                $order->update( \%order_params );
            }

            $guard->commit;

            return 1;
        }
        catch {
            chomp;
            my $err = $_;
            $self->app->log->error($err);

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
    $order = $self->get_order( { id => $id } );
    my $data = $self->flatten_order($order);

    $self->respond_to( json => { status => 200, json => $data } );
}

=head2 update_order_nonpayment2full

    PUT /api/order/:id/nonpayment2full

=cut

sub api_update_order_nonpayment2full {
    my $self = shift;
    my $id   = $self->param('id');

    my $order = $self->DB->resultset('Order')->find( { id => $id } );
    return $self->error( 404, { str => "Not found order: $id", data => {} } )
        unless $order;

    my $bool = $self->is_nonpayment($id);
    return $self->error( 400, { str => "Not nonpayment order: $id", data => {} } )
        unless $bool;

    my $detail = $order->order_details( { stage => 1 }, { rows => 1 } )->single;
    return $self->error( 400, { str => "Not found unpayment price", data => {} } )
        unless $detail;

    my $final_price = $detail->final_price;
    my ( $ret, $status, $error ) = do {
        my $guard = $self->DB->txn_scope_guard;
        my $details = $order->order_details( { stage => 4 } );
        while ( my $detail = $details->next ) {
            my $cond = { stage => 5 };
            if ( $detail->name eq '불납' ) {
                $cond->{name}        = '완납';
                $cond->{price}       = $final_price;
                $cond->{final_price} = $final_price;
            }
            $detail->update($cond);
        }
        $guard->commit;
    };

    $self->respond_to( json => { status => 200, json => {} } );
}

=head2 order_return_part

    PUT /api/order/:id/return-part

=cut

sub api_order_return_part {
    my $self = shift;

    #
    # fetch params
    #
    my %order_params = $self->get_params(
        qw/
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
            message
            neck
            pants
            parent_id
            price_pay_with
            purpose
            purpose2
            rental_date
            return_date
            return_method
            return_memo
            staff_id
            status_id
            target_date
            thigh
            topbelly
            user_id
            user_target_date
            waist
            wearon_date
            weight
            /
    );
    my %order_detail_params = $self->get_params( [ order_detail_id => 'id' ], );

    #
    # update the order
    #
    my $order = $self->get_order( { id => $order_params{id} } );
    return unless $order;
    {
        my %_params = ( id => [], status_id => [], );
        for my $order_detail ( $order->order_details ) {
            next unless $order_detail->clothes;
            push @{ $_params{id} },        $order_detail->id;
            push @{ $_params{status_id} }, 9;
        }
        $order = $self->update_order( \%order_params, \%_params, );
        return unless $order;
    }

    #
    # create new order
    #
    $order_params{additional_day}   = $order->additional_day;
    $order_params{desc}             = $order->desc;
    $order_params{parent_id}        = $order->id;
    $order_params{wearon_date}      = $order->wearon_date;
    $order_params{purpose}          = $order->purpose;
    $order_params{purpose2}         = $order->purpose2;
    $order_params{rental_date}      = $order->rental_date;
    $order_params{target_date}      = $order->target_date;
    $order_params{user_id}          = $order->user_id;
    $order_params{user_target_date} = $order->user_target_date;
    $order_params{booking_id}       = $order->booking_id;
    $order_params{return_memo}      = $order->return_memo;
    $order_params{status_id}        = 19;                      # 결제대기

    delete $order_params{id};
    delete $order_params{late_fee_pay_with};
    delete $order_params{price_pay_with};
    delete $order_params{return_date};
    delete $order_params{return_method};

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
                        id => { -not_in => $order_detail_params{id} }, clothes_code => { '!=' => undef },
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
        'Location' => $self->url_for( '/api/order/' . $order->id ), );
    $self->respond_to( json => { status => 201, json => $data } );
}

=head2 order_set_package

    GET /api/order/:id/set-package

=cut

sub api_order_set_package {
    my $self = shift;

    #
    # fetch params
    #
    my %order_params = $self->get_params(qw/ id /);

    #
    # update the order
    #
    my $order = $self->get_order( { id => $order_params{id} } );
    unless ($order) {
        $self->app->log->warn( "cannot find such order: " . $order->id );
    }
    return unless $order;

    for my $clothes ( $order->clothes ) {
        $clothes->update( { status_id => 41 } ); # 포장취소
    }

    $order->order_details->delete_all;
    $order = $self->update_order(
        {
            id                => $order->id,
            status_id         => 18,             # 포장
            staff_id          => undef,
            rental_date       => undef,
            target_date       => undef,
            user_target_date  => undef,
            return_date       => undef,
            return_method     => undef,
            price_pay_with    => undef,
            late_fee_pay_with => undef,
            bestfit           => 0,
        },
    );

    #
    # response
    #
    my $data = $self->flatten_order($order);
    $self->respond_to( json => { status => 200, json => $data } );
}

=head2 delete_order_booking

    DELETE /api/order/:id/booking

=cut

sub api_delete_order_booking {
    my $self = shift;

    #
    # fetch params
    #
    my %order_params = $self->get_params(qw/ id /);

    #
    # update the order
    #
    my $order = $self->get_order( { id => $order_params{id} } );
    unless ($order) {
        $self->app->log->warn( "cannot find such order: " . $order->id );
    }
    return $self->error(
        400,
        {
            str  => "cannot find such order: " . $order->id,
            data => {},
        },
    ) unless $order;

    #
    # 방문 예약(14) 상태의 주문서의 예약만 취소할 수 있도록 합니다.
    #
    if ( $order->status_id != 14 ) {
        return $self->error(
            500,
            {
                str  => "cannot delete booking since order.status_id is not 14",
                data => { status_id => $order->status_id },
            }
        );
    }

    $order = $self->update_order(
        {
            id         => $order->id,
            booking_id => undef,
        },
    );

    #
    # response
    #
    my $data = $self->flatten_order($order);
    $self->respond_to( json => { status => 200, json => $data } );
}

=head2 order_list

    GET /api/order-list

=cut

sub api_order_list {
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

=head2 create_order_detail

    POST /api/order_detail

=cut

sub api_create_order_detail {
    my $self = shift;

    #
    # fetch params
    #
    my %params = $self->get_params(
        qw/
            clothes_code
            desc
            final_price
            name
            order_id
            price
            stage
            status_id
            /
    );

    my $order_detail = $self->create_order_detail( \%params );
    return unless $order_detail;

    #
    # response
    #
    my $data = $self->flatten_order_detail($order_detail);

    $self->res->headers->header(
        'Location' => $self->url_for( '/api/order_detail/' . $order_detail->id ), );
    $self->respond_to( json => { status => 201, json => $data } );
}

=head2 create_clothes

    POST /api/clothes

=cut

sub api_create_clothes {
    my $self = shift;

    #
    # fetch params
    #
    my %params = $self->get_params(
        qw/
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
            neck
            price
            status_id
            thigh
            topbelly
            waist
            /
    );

    #
    # validate params
    #
    my $v = $self->create_validator;
    $v->field('code')->required(1)->regexp(qr/^[A-Z0-9]{4,5}$/);
    $v->field('category')->required(1)->in( keys %{ $self->config->{category} } );
    $v->field('gender')->in(qw/ male female unisex /);
    $v->field('price')->regexp(qr/^\d*$/);
    $v->field(qw/ topbelly belly neck bust waist hip thigh arm length /)->each(
        sub {
            shift->regexp(qr/^\d{1,3}$/);
        }
    );
    $v->field('donation_id')->regexp(qr/^\d*$/)->callback(
        sub {
            my $val = shift;

            return 1 if $self->DB->resultset('Donation')->find( { id => $val } );
            return ( 0, 'donation not found using donation_id' );
        }
    );

    $v->field('status_id')->regexp(qr/^\d*$/)->callback(
        sub {
            my $val = shift;

            return 1 if $self->DB->resultset('Status')->find( { id => $val } );
            return ( 0, 'status not found using status_id' );
        }
    );

    $v->field('group_id')->regexp(qr/^\d*$/)->callback(
        sub {
            my $val = shift;

            return 1 if $self->DB->resultset('Group')->find( { id => $val } );
            return ( 0, 'status not found using group_id' );
        }
    );
    unless ( $self->validate( $v, \%params ) ) {
        my @error_str;
        while ( my ( $k, $v ) = each %{ $v->errors } ) {
            push @error_str, "$k:$v";
        }
        return $self->error( 400, { str => join( ',', @error_str ), data => $v->errors, } );
    }

    #
    # adjust params
    #
    $params{code} = sprintf( '%05s', $params{code} ) if length( $params{code} ) == 4;

    #
    # create clothes
    #
    my $clothes = $self->DB->resultset('Clothes')->create( \%params );
    return $self->error( 500, { str => 'failed to create a new clothes', data => {}, } )
        unless $clothes;

    #
    # response
    #
    my %data = ( $clothes->get_columns );

    $self->res->headers->header(
        'Location' => $self->url_for( '/api/clothes/' . $clothes->code ), );
    $self->respond_to( json => { status => 201, json => \%data } );
}

=head2 get_clothes

    GET /api/clothes/:code

=cut

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

=head2 update_clothes

    PUT /api/clothes/:code

=cut

sub api_update_clothes {
    my $self = shift;

    #
    # fetch params
    #
    my %params = $self->get_params(
        qw/
            arm
            belly
            bust
            category
            code
            color
            comment
            compatible_code
            donation_id
            gender
            group_id
            hip
            length
            neck
            price
            status_id
            thigh
            topbelly
            waist
            cuff
            /
    );

    #
    # validate params
    #
    my $v = $self->create_validator;
    $v->field('code')->required(1)->regexp(qr/^[A-Z0-9]{4,5}$/);
    $v->field('category')->in( keys %{ $self->config->{category} } );
    $v->field('gender')->in(qw/ male female unisex /);
    $v->field('price')->regexp(qr/^\d*$/);
    $v->field(qw/ topbelly belly neck bust waist hip thigh arm length /)->each(
        sub {
            shift->regexp(qr/^\d{1,3}$/);
        }
    );
    $v->field('cuff')->regexp(qr/^\d{1,3}(\.)?(\d{1,2})?$/);
    $v->field('donation_id')->regexp(qr/^\d*$/)->callback(
        sub {
            my $val = shift;

            return 1 if $self->DB->resultset('Donation')->find( { id => $val } );
            return ( 0, 'donation not found using donation_id' );
        }
    );

    $v->field('status_id')->regexp(qr/^\d*$/)->callback(
        sub {
            my $val = shift;

            return 1 if $self->DB->resultset('Status')->find( { id => $val } );
            return ( 0, 'status not found using status_id' );
        }
    );

    $v->field('group_id')->regexp(qr/^\d*$/)->callback(
        sub {
            my $val = shift;

            return 1 if $self->DB->resultset('Group')->find( { id => $val } );
            return ( 0, 'status not found using group_id' );
        }
    );
    unless ( $self->validate( $v, \%params ) ) {
        my @error_str;
        while ( my ( $k, $v ) = each %{ $v->errors } ) {
            push @error_str, "$k:$v";
        }
        return $self->error( 400, { str => join( ',', @error_str ), data => $v->errors, } );
    }

    #
    # adjust params
    #
    $params{code} = sprintf( '%05s', $params{code} ) if length( $params{code} ) == 4;
    if ( exists $params{donation_id} && !$params{donation_id} ) {
        $params{donation_id} = undef;
    }

    #
    # find clothes
    #
    my $clothes = $self->DB->resultset('Clothes')->find( \%params );
    return $self->error( 404, { str => 'clothes not found', data => {}, } )
        unless $clothes;

    #
    # update clothes
    #
    {
        my %_params = %params;
        delete $_params{code};
        $clothes->update( \%params )
            or
            return $self->error( 500, { str => 'failed to update a clothes', data => {}, } );

        ## 분실, 폐기일때에 의류의 모든 태그를 제거 #1127
        ## 분실, 폐기일때에 셋트의류를 해제 #1118
        if ( $params{status_id} == $LOST || $params{status_id} == $DISCARD ) {
            while ( my $c = $clothes->next ) {
                $c->delete_related('clothes_tags');
                $c->delete_related('suit_code_top');
                $c->delete_related('suit_code_bottom');
            }
        }
    }

    #
    # response
    #
    my $data = $self->flatten_clothes($clothes);

    $self->respond_to( json => { status => 200, json => $data } );
}

=head2 delete_clothes

    DELETE /api/clothes/:code

=cut

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
        return $self->error( 400, { str => join( ',', @error_str ), data => $v->errors, } );
    }

    #
    # adjust params
    #
    $params{code} = sprintf( '%05s', $params{code} ) if length( $params{code} ) == 4;

    #
    # find clothes
    #
    my $clothes = $self->DB->resultset('Clothes')->find( \%params );
    return $self->error( 404, { str => 'clothes not found', data => {}, } )
        unless $clothes;

    #
    # delete & response
    #
    my $data = $self->flatten_clothes($clothes);
    $clothes->delete;

    $self->respond_to( json => { status => 200, json => $data } );
}

=head2 update_clothes_tag

    PUT /api/clothes/:code/tag

=cut

sub api_update_clothes_tag {
    my $self = shift;

    #
    # fetch params
    #
    my %params = $self->get_params( [ code => 'clothes_code' ], 'tag_id' );

    #
    # validate params
    #
    my $v = $self->create_validator;
    $v->field('clothes_code')->required(1)->regexp(qr/^[A-Z0-9]{4,5}$/)->callback(
        sub {
            my $val = shift;

            $val = sprintf( '%05s', $val ) if length $val == 4;

            return 1 if $self->DB->resultset('Clothes')->find( { code => $val } );
            return ( 0, 'clothes not found using clothes_code' );
        }
    );
    $v->field('tag_id')->regexp(qr/^\d+$/)->callback(
        sub {
            my $val = shift;

            return 1 if $self->DB->resultset('Tag')->find( { id => $val } );
            return ( 0, 'tag not found using tag_id' );
        }
    );
    unless ( $self->validate( $v, \%params ) ) {
        my @error_str;
        while ( my ( $k, $v ) = each %{ $v->errors } ) {
            push @error_str, "$k:$v";
        }
        return $self->error( 400, { str => join( ',', @error_str ), data => $v->errors, } );
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
        my $guard = $self->DB->txn_scope_guard;
        try {
            #
            # remove existing clothes tag data
            #
            $self->DB->resultset('ClothesTag')
                ->search( { clothes_code => $params{clothes_code} } )->delete_all;

            my @clothes_tags;
            if ( $params{tag_id} ) {
                #
                # update new clothes tag data
                #
                for my $tag_id (
                    ref( $params{tag_id} ) eq 'ARRAY' ? @{ $params{tag_id} } : ( $params{tag_id} ) )
                {
                    my $clothes_tag = $self->DB->resultset('ClothesTag')
                        ->create( { clothes_code => $params{clothes_code}, tag_id => $tag_id, } );
                    push @clothes_tags, $clothes_tag;
                }
            }

            $guard->commit;

            return \@clothes_tags;
        }
        catch {
            chomp;
            my $err = $_;
            $self->app->log->error("failed to delete & update the clothes_tag");

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

=head2 update_clothes_discard

    PUT  /api/clothes/:code/discard
    POST /api/clothes/:code/discard

=cut

sub api_update_clothes_discard {
    my $self = shift;
    my $code = $self->param('code');

    $code = sprintf( '%05s', $code );

    my $clothes = $self->DB->resultset('Clothes')->find( { code => $code } );
    return $self->error( 404, { str => "Not found clothes: $code" } ) unless $clothes;

    my $discard_clothes = $self->DB->resultset('DiscardClothes')
        ->find_or_create( { clothes_code => $code } );

    return $self->error( 500, { str => "Couldn't create a discard_clothes" } )
        unless $discard_clothes;

    my $v = $self->validation;
    $v->optional('discard_to');
    $v->optional('comment');

    if ( $v->has_error ) {
        my $failed = $v->failed;
        return $self->error(
            400,
            { str => 'Parameter Validation Failed: ' . join( ', ', @$failed ) }
        );
    }

    my $input = $v->input;
    $discard_clothes->update($input);
    $self->render( json => { $discard_clothes->get_columns } );
}

=head2 clothes_list

    GET /api/clothes-list

=cut

sub api_clothes_list {
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
        return $self->error( 400, { str => join( ',', @error_str ), data => $v->errors, } );
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
    my @clothes_list =
        $self->DB->resultset('Clothes')->search( { code => $params{code} } )->all;
    return $self->error( 404, { str => 'clothes list not found', data => {}, } )
        unless @clothes_list;

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

=head2 update_clothes_list

    PUT /api/clothes-list

=cut

sub api_update_clothes_list {
    my $self = shift;

    #
    # fetch params
    #
    my %params = $self->get_params(
        qw/
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
            neck
            price
            status_id
            thigh
            waist
            /
    );

    #
    # validate params
    #
    my $v = $self->create_validator;
    $v->field('code')->required(1)->regexp(qr/^[A-Z0-9]{4,5}$/);
    $v->field('category')->in( keys %{ $self->config->{category} } );
    $v->field('gender')->in(qw/ male female unisex /);
    $v->field('price')->regexp(qr/^\d*$/);
    $v->field(qw/ neck bust waist hip thigh arm length /)->each(
        sub {
            shift->regexp(qr/^\d{1,3}$/);
        }
    );
    $v->field('donation_id')->regexp(qr/^\d*$/)->callback(
        sub {
            my $val = shift;

            return 1 if $self->DB->resultset('Donation')->find( { id => $val } );
            return ( 0, 'donation not found using donation_id' );
        }
    );

    $v->field('status_id')->regexp(qr/^\d*$/)->callback(
        sub {
            my $val = shift;

            return 1 if $self->DB->resultset('Status')->find( { id => $val } );
            return ( 0, 'status not found using status_id' );
        }
    );

    $v->field('group_id')->regexp(qr/^\d*$/)->callback(
        sub {
            my $val = shift;

            return 1 if $self->DB->resultset('Group')->find( { id => $val } );
            return ( 0, 'status not found using group_id' );
        }
    );
    unless ( $self->validate( $v, \%params ) ) {
        my @error_str;
        while ( my ( $k, $v ) = each %{ $v->errors } ) {
            push @error_str, "$k:$v";
        }
        return $self->error( 400, { str => join( ',', @error_str ), data => $v->errors, } );
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
        my $code    = delete $_params{code};
        my $clothes = $self->DB->resultset('Clothes')->search( { code => $params{code} } );
        $clothes->update( \%_params );
        ## 분실, 폐기일때에 의류의 모든 태그를 제거 #1127
        ## 분실, 폐기일때에 셋트의류를 해제 #1118
        if ( $params{status_id} == $LOST || $params{status_id} == $DISCARD ) {
            while ( my $c = $clothes->next ) {
                $c->delete_related('clothes_tags');
                $c->delete_related('suit_code_top');
                $c->delete_related('suit_code_bottom');
            }
        }
    }

    #
    # response
    #
    my %data = ();

    $self->respond_to( json => { status => 200, json => \%data } );
}

=head2 create_tag

    POST /api/tag

=cut

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
        return $self->error( 400, { str => join( ',', @error_str ), data => $v->errors, } );
    }

    my ( $tag, $status, $error ) = do {
        try {
            #
            # create tag
            #
            my $tag = $self->DB->resultset('Tag')->create( \%params );
            die "failed to create a new tag\n" unless $tag;

            return $tag;
        }
        catch {
            chomp;
            my $err = $_;

            no warnings 'experimental';
            given ($err) {
                when (
                    /DBIx::Class::Storage::DBI::_dbh_execute\(\): DBI Exception:.*Duplicate entry.*for key 'name'/
                    )
                {
                    $err = 'duplicate tag.name';
                }
            }

            return ( undef, 400, $err );
        };
    };

    $self->error( $status, { str => $error, data => {}, } ), return unless $tag;

    #
    # response
    #
    my %data = $tag->get_columns;

    $self->res->headers->header(
        'Location' => $self->url_for( '/api/tag/' . $tag->id ),
    );
    $self->respond_to( json => { status => 201, json => \%data } );
}

=head2 get_tag

    GET /api/tag/:id

=cut

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
        return $self->error( 400, { str => join( ',', @error_str ), data => $v->errors, } );
    }

    #
    # find tag
    #
    my $tag = $self->DB->resultset('Tag')->find( { id => $params{id} } );
    return $self->error( 404, { str => 'tag not found', data => {}, } ) unless $tag;

    #
    # response
    #
    my %data = $tag->get_columns;

    $self->respond_to( json => { status => 200, json => \%data } );
}

=head2 update_tag

    PUT /api/tag/:id

=cut

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
        return $self->error( 400, { str => join( ',', @error_str ), data => $v->errors, } );
    }

    #
    # TRANSACTION:
    #
    my ( $tag, $status, $error ) = do {
        my $guard = $self->DB->txn_scope_guard;
        try {
            #
            # find tag
            #
            my $tag = $self->DB->resultset('Tag')->find( { id => $params{id} } );
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
                    when (
                        /DBIx::Class::Storage::DBI::_dbh_execute\(\): DBI Exception:.*Duplicate entry.*for key 'name'/
                        )
                    {
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
            $self->app->log->error("failed to find & update the tag");

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
    $self->error( $status, { str => $error, data => {}, } ), return unless $tag;

    #
    # response
    #
    my %data = $tag->get_columns;

    $self->respond_to( json => { status => 200, json => \%data } );
}

=head2 delete_tag

    DELETE /api/tag/:id

=cut

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
        return $self->error( 400, { str => join( ',', @error_str ), data => $v->errors, } );
    }

    #
    # find tag
    #
    my $tag = $self->DB->resultset('Tag')->find( { id => $params{id} } );
    return $self->error( 404, { str => 'tag not found', data => {}, } ) unless $tag;

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

=head2 create_donation

    POST /api/donation

=cut

sub api_create_donation {
    my $self = shift;

    #
    # fetch params
    #
    my %params = $self->get_params(
        qw/
            user_id
            message
            create_date
            /
    );

    #
    # validate params
    #
    my $v = $self->create_validator;
    $v->field('user_id')->required(1)->regexp(qr/^\d*$/)->callback(
        sub {
            my $val = shift;

            return 1 if $self->DB->resultset('User')->find( { id => $val } );
            return ( 0, 'user not found using user_id' );
        }
    );

    unless ( $self->validate( $v, \%params ) ) {
        my @error_str;
        while ( my ( $k, $v ) = each %{ $v->errors } ) {
            push @error_str, "$k:$v";
        }
        return $self->error( 400, { str => join( ',', @error_str ), data => $v->errors, } );
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
                time_zone => $self->config->{timezone},
            );
        }
        $donation = $self->DB->resultset('Donation')->create( \%_params );
        return $self->error( 500, { str => 'failed to create a new donation', data => {}, } )
            unless $donation;
    }

    #
    # response
    #
    my %data = ( $donation->get_columns );

    $self->res->headers->header(
        'Location' => $self->url_for( '/api/donation/' . $donation->id ), );
    $self->respond_to( json => { status => 201, json => \%data } );
}

=head2 update_donation

    PUT /api/donation/:id

=cut

sub api_update_donation {
    my $self = shift;

    #
    # fetch params
    #
    my %params = $self->get_params(qw/id message user_id/);

    #
    # validate params
    #
    my $v = $self->create_validator;

    unless ( $self->validate( $v, \%params ) ) {
        my @error_str;
        while ( my ( $k, $v ) = each %{ $v->errors } ) {
            push @error_str, "$k:$v";
        }
        return $self->error( 400, { str => join( ',', @error_str ), data => $v->errors, } );
    }

    my $donation = $self->DB->resultset('Donation')->find( { id => $params{id} } );
    die "donation not found\n" unless $donation;

    $donation->message( $params{message} || '' );
    $donation->user_id( $params{user_id} ) if $params{user_id};
    $donation->update;

    my %data = ( $donation->get_columns );
    $self->respond_to( json => { status => 200, json => \%data } );
}

=head2 create_group

    POST /api/group

=cut

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
        return $self->error( 400, { str => join( ',', @error_str ), data => $v->errors, } );
    }

    #
    # create group
    #
    my $group = $self->DB->resultset('Group')->create( \%params );
    return $self->error( 500, { str => 'failed to create a new group', data => {}, } )
        unless $group;

    #
    # response
    #
    my %data = ( $group->get_columns );

    $self->res->headers->header(
        'Location' => $self->url_for( '/api/group/' . $group->id ), );
    $self->respond_to( json => { status => 201, json => \%data } );
}

=head2 create_suit

    POST /api/suit

=cut

sub api_create_suit {
    my $self = shift;

    #
    # fetch params
    #
    my %params = $self->get_params(qw/code_top code_bottom/);

    #
    # validate params
    #
    my $v = $self->create_validator;
    $v->field('code_top')->required(1)->regexp(qr/^J/);
    $v->field('code_bottom')->required(1)->regexp(qr/^(P|K)/);

    unless ( $self->validate( $v, \%params ) ) {
        my @error_str;
        while ( my ( $k, $v ) = each %{ $v->errors } ) {
            push @error_str, "$k:$v";
        }
        return $self->error( 400, { str => join( ',', @error_str ), data => $v->errors, } );
    }

    $params{code_top}    = sprintf( '%05s', $params{code_top} );
    $params{code_bottom} = sprintf( '%05s', $params{code_bottom} );

    #
    # create suit
    #
    my $suit = $self->DB->resultset('Suit')->create( \%params );
    return $self->error( 500, { str => 'failed to create a new suit', data => {}, } )
        unless $suit;

    #
    # response
    #
    my %data = ( $suit->get_columns );
    $self->respond_to( json => { status => 201, json => \%data } );
}

=head2 delete_suit

    DELETE /api/suit/:code

=cut

sub api_delete_suit {
    my $self = shift;

    #
    # fetch params
    #
    my %params = $self->get_params(qw/ code /);

    #
    # validate params
    #
    my $v = $self->create_validator;
    $v->field('code')->required(1)->regexp(qr/^0?[JPS][A-Z0-9]{3}$/);
    unless ( $self->validate( $v, \%params ) ) {
        my @error_str;
        while ( my ( $k, $v ) = each %{ $v->errors } ) {
            push @error_str, "$k:$v";
        }
        return $self->error( 400, { str => join( ',', @error_str ), data => $v->errors, } );
    }

    #
    # adjust params
    #
    $params{code} = sprintf( '%05s', $params{code} ) if length( $params{code} ) == 4;
    my $key = $params{code} =~ /0J/ ? 'code_top' : 'code_bottom';

    #
    # find suit
    #
    my $suit = $self->DB->resultset('Suit')->find( { $key => $params{code} } );
    return $self->error( 404, { str => 'suit not found', data => {}, } ) unless $suit;

    #
    # delete & response
    #
    $suit->delete;
    $self->respond_to( json => { status => 200, json => {} } );
}

=head2 create_sms

    POST /api/sms

=cut

sub api_create_sms {
    my $self = shift;

    #
    # fetch params
    #
    my %params = $self->get_params(qw/ from to text status /);

    #
    # validate params
    #
    my $v = $self->create_validator;
    $v->field('from')->regexp(qr/^#?\d+$/);
    $v->field('to')->required(1)->regexp(qr/^#?\d+$/);
    $v->field('text')->required(1)->regexp(qr/^(\s|\S)+$/);
    $v->field('status')->in(qw/ pending sending sent /);

    unless ( $self->validate( $v, \%params ) ) {
        my @error_str;
        while ( my ( $k, $v ) = each %{ $v->errors } ) {
            push @error_str, "$k:$v";
        }
        $self->error( 400, { str => join( ',', @error_str ), data => $v->errors, } ), return;
    }

    $params{from} =~ s/-//g;
    $params{to} =~ s/-//g;
    my $from =
        $params{from} || $self->config->{sms}{ $self->config->{sms}{driver} }{_from};
    my $to = $params{to};
    if ( $params{to} =~ m/^#(\d+)/ ) {
        my $order_id = $1;
        return $self->error(
            404,
            { str => 'failed to create a new sms: no order id', data => {}, }
        ) unless $order_id;

        my $order_obj = $self->DB->resultset('Order')->find($order_id);
        return $self->error(
            404,
            { str => 'failed to create a new sms: cannot get order object', data => {}, }
        ) unless $order_obj;

        my $phone = $order_obj->user->user_info->phone;
        return $self->error(
            404,
            {
                str  => 'failed to create a new sms: cannot get order.user.user_info.phone',
                data => {},
            }
        ) unless $phone;

        my $booking_time = $order_obj->booking->date->strftime('%H:%M');
        $self->app->log->debug("booking time: $booking_time");
        if ( $order_obj->online ) {
            $from = $self->config->{sms}{from}{online};
        }
        $to = $phone;
    }
    my $sms =
        $self->DB->resultset('SMS')->create( { %params, from => $from, to => $to, } );
    return $self->error( 404, { str => 'failed to create a new sms', data => {}, } )
        unless $sms;

    #
    # response
    #
    my %data = ( $sms->get_columns );

    $self->res->headers->header(
        'Location' => $self->url_for( '/api/sms/' . $sms->id ),
    );
    $self->respond_to( json => { status => 201, json => \%data } );
}

=head2 update_sms

    PUT /api/sms/:id

=cut

sub api_update_sms {
    my $self = shift;

    #
    # fetch params
    #
    my %params =
        $self->get_params(qw/ id from to text ret status method detail sent_date /);

    #
    # validate params
    #
    my $v = $self->create_validator;
    $v->field('id')->required(1)->regexp(qr/^\d+$/);
    $v->field(qw/ from to /)->each( sub { shift->regexp(qr/^\d+$/) } );
    $v->field('text')->regexp(qr/^.+$/);
    $v->field('ret')->regexp(qr/^\d+$/);
    $v->field('status')->in(qw/ pending sending sent /);
    $v->field('sent_date')->regexp(qr/^\d+$/);

    unless ( $self->validate( $v, \%params ) ) {
        my @error_str;
        while ( my ( $k, $v ) = each %{ $v->errors } ) {
            push @error_str, "$k:$v";
        }
        $self->error( 400, { str => join( ',', @error_str ), data => $v->errors, } ), return;
    }

    if ( $params{sent_date} ) {
        $params{sent_date} = DateTime->from_epoch(
            epoch     => $params{sent_date},
            time_zone => $self->config->{timezone},
        );
    }

    #
    # TRANSACTION:
    #
    my ( $sms, $status, $error ) = do {
        my $guard = $self->DB->txn_scope_guard;
        try {
            #
            # find sms
            #
            my $sms = $self->DB->resultset('SMS')->find( { id => $params{id} } );
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
            $self->app->log->error("failed to find & update the sms");

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

    $self->error( $status, { str => $error, data => {}, } ), return unless $sms;

    #
    # response
    #
    my %data = ( $sms->get_columns );

    $self->respond_to( json => { status => 200, json => \%data } );
}

=head2 create_sms_validation

    POST /api/sms/validation

=cut

sub api_create_sms_validation {
    my $self = shift;

    #
    # fetch params
    #
    my %params = $self->get_params(qw/ name to /);

    #
    # validate params
    #
    my $v = $self->create_validator;
    $v->field('name')->required(1)->trim(0)->callback(
        sub {
            my $value = shift;

            return 1 unless $value =~ m/(^\s+|\s+$)/;
            return ( 0, "name has trailing space" );
        }
    );
    $v->field('to')->required(1)->regexp(qr/^\d+$/);

    unless ( $self->validate( $v, \%params ) ) {
        my @error_str;
        while ( my ( $k, $v ) = each %{ $v->errors } ) {
            push @error_str, "$k:$v";
        }
        $self->error( 400, { str => join( ',', @error_str ), data => $v->errors, } ), return;
    }

    #
    # find user
    #
    my @users = $self->DB->resultset('User')
        ->search( { 'user_info.phone' => $params{to} }, { join => 'user_info' }, );
    my $user = shift @users;

    if ($user) {
        #
        # fail if name and phone does not match
        #
        unless ( $user->name eq $params{name} ) {
            my $msg = sprintf(
                'name and phone does not match: input(%s,%s), db(%s,%s)',
                $params{name}, $params{to}, $user->name, $user->user_info->phone,
            );
            $self->app->log->warn($msg);

            $self->error( 400, { str => 'name and phone does not match', } ), return;
        }
    }
    else {
        #
        # add user using one's name and phone if who does not exist
        #
        {
            my $guard = $self->DB->txn_scope_guard;

            my $_user = $self->DB->resultset('User')->create( { name => $params{name} } );
            unless ($_user) {
                $self->app->log->warn('failed to create a user');
                last;
            }

            my $_user_info = $self->DB->resultset('UserInfo')
                ->create( { user_id => $_user->id, phone => $params{to}, } );
            unless ($_user_info) {
                $self->app->log->warn('failed to create a user_info');
                last;
            }

            $guard->commit;

            $user = $_user;
        }

        $self->app->log->info("create a user: name($params{name}), phone($params{to})");
    }

    #
    # fail if creating user is failed
    #
    unless ($user) {
        $self->error( 400, { str => 'failed to create a user', } ), return;
    }

    my $password = String::Random->new->randregex('\d\d\d\d\d\d');
    my $expires =
        DateTime->now( time_zone => $self->config->{timezone} )->add( minutes => 20 );
    $user->update( { password => $password, expires => $expires->epoch, } )
        or return $self->error( 500, { str => 'failed to update a user', data => {}, } );
    $self->app->log->debug(
        "sent temporary password: to($params{to}) password($password)");

    my $sms = $self->DB->resultset('SMS')->create(
        {
            to   => $params{to},
            from => $self->config->{sms}{ $self->config->{sms}{driver} }{_from},
            text => "열린옷장 인증번호: $password",
        }
    );
    return $self->error( 404, { str => 'failed to create a new sms', data => {}, } )
        unless $sms;

    #
    # response
    #
    my %data = ( $sms->get_columns );

    $self->res->headers->header(
        'Location' => $self->url_for( '/api/sms/' . $sms->id ),
    );
    $self->respond_to( json => { status => 201, json => \%data } );
}

=head2 search_user

    GET /api/search/user

=cut

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
        return $self->error( 400, { str => join( ',', @error_str ), data => $v->errors, } );
    }

    #
    # find user
    #
    my @users = $self->DB->resultset('User')->search(
        {
            -or => [
                'me.name' => $params{q}, 'me.email' => $params{q}, 'user_info.phone' => $params{q},
            ],
        },
        { join => 'user_info' },
    );
    return $self->error( 404, { str => 'user not found', data => {}, } ) unless @users;

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

=head2 search_late_user

    GET /api/search/user/late

=cut

sub api_search_late_user {
    my $self = shift;

    #
    # find user
    #
    my $now = $self->DB->storage->datetime_parser->format_datetime(
        DateTime->now( time_zone => $self->config->{timezone} ), );
    my @users = $self->DB->resultset('User')->search(
        {
            -and => [
                'order_users.target_date'      => { '<' => $now },
                'order_users.user_target_date' => { '<' => $now },
                'order_users.status_id'        => 2,
            ],
        },
        { join => 'order_users' },
    );
    return $self->error( 404, { str => 'user not found', data => {}, } ) unless @users;

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

=head2 search_donation

    GET /api/search/donation

=cut

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
        return $self->error( 400, { str => join( ',', @error_str ), data => $v->errors, } );
    }

    #
    # find user
    #
    my @users = $self->DB->resultset('User')->search(
        {
            -or => [
                'me.name' => $params{q}, 'me.email' => $params{q}, 'user_info.phone' => $params{q},
            ],
        },
        { join => 'user_info' },
    );
    return $self->error( 404, { str => 'user not found', data => {}, } ) unless @users;

    #
    # gather donation
    #
    my @donations = map { $_->donations } @users;

    #
    # response
    #
    my @data;
    for my $donation (@donations) {
        my %user = ( $donation->user->user_info->get_columns, $donation->user->get_columns );
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

=head2 search_sms

    GET /api/search/sms

=cut

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
        return $self->error( 400, { str => join( ',', @error_str ), data => $v->errors, } );
    }

    #
    # find sms
    #
    my @sms_list = $self->DB->resultset('SMS')->search( { status => $params{status} } );
    return $self->respond_to( json => { status => 200, json => [] } ) unless @sms_list;

    #
    # response
    #
    my @data;
    push @data, { $_->get_columns } for @sms_list;

    $self->respond_to( json => { status => 200, json => \@data } );
}

=head2 gui_staff_list

    GET /api/gui/staff-list

=cut

sub api_gui_staff_list {
    my $self = shift;

    #
    # find staff
    #
    my @users = $self->DB->resultset('User')
        ->search( { 'user_info.staff' => 1 }, { join => 'user_info' }, );
    return $self->error( 404, { str => 'staff not found', data => {}, } ) unless @users;

    #
    # response
    #
    my @data;
    push @data, { value => $_->id, text => $_->name } for @users;

    $self->respond_to( json => { status => 200, json => \@data } );
}

=head2 gui_update_booking

    PUT /api/gui/booking/:id

=cut

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
        return $self->error( 400, { str => join( ',', @error_str ), data => $v->errors, } );
    }

    #
    # find booking
    #
    my $booking = $self->DB->resultset('Booking')->find( { id => $params{id} } );
    return $self->error( 404, { str => 'booking not found', data => {}, } )
        unless $booking;

    my $old_data = $self->flatten_booking($booking);

    #
    # update booking
    #
    my %_params = %params;
    delete $_params{id};

    $booking->update( \%_params )
        or
        return $self->error( 500, { str => 'failed to update a booking', data => {}, } );

    #
    # response
    #
    my $data = $self->flatten_booking($booking);

    #
    # log
    #
    my $log_str = sprintf(
        "%s -> %s",
        Mojo::JSON::encode_json($old_data),
        Mojo::JSON::encode_json($data),
    );
    $self->app->log->info($log_str);

    $self->respond_to( json => { status => 200, json => $data } );
}

=head2 gui_booking_list

    GET /api/gui/booking-list

=cut

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
        return $self->error( 400, { str => join( ',', @error_str ), data => $v->errors, } );
    }

    my @booking_list = $self->booking_list( $params{gender} );
    return unless @booking_list;

    #
    # response
    #
    $self->respond_to( json => { status => 200, json => \@booking_list } );
}

=head2 gui_timetable

    GET /api/gui/timetable/:ymd

=cut

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
    $v->field('ymd')->required(1)->callback(
        sub {
            my $val = shift;

            unless ( $val =~ m/^(\d{4})-(\d{2})-(\d{2})$/ ) {
                my $msg = "invalid ymd format: $params{ymd}";
                $self->app->log->warn($msg);
                return ( 0, $msg );
            }

            my $dt = try {
                DateTime->new(
                    time_zone => $self->config->{timezone}, year => $1, month => $2,
                    day       => $3,
                );
            };
            unless ($dt) {
                my $msg = "cannot create start datetime object: $params{ymd}";
                $self->app->log->warn($msg);
                return ( 0, $msg );
            }

            return 1;
        }
    );
    unless ( $self->validate( $v, \%params ) ) {
        my @error_str;
        while ( my ( $k, $v ) = each %{ $v->errors } ) {
            push @error_str, "$k:$v";
        }
        return $self->error( 400, { str => join( ',', @error_str ), data => $v->errors, } );
    }

    $params{ymd} =~ m/^(\d{4})-(\d{2})-(\d{2})$/;
    my $dt_start = DateTime->new(
        time_zone => $self->config->{timezone}, year => $1, month => $2,
        day       => $3,
    );
    my $dt_end = $dt_start->clone->add( hours => 24, seconds => -1 );
    my $count = $self->count_visitor( $dt_start, $dt_end );

    $self->respond_to( json => { status => 200, json => $count } );
}

=head2 gui_user_id_avg

    GET /api/gui/user/:id/avg

=cut

sub api_gui_user_id_avg {
    my $self = shift;

    #
    # fetch params
    #
    my %params = $self->get_params(qw/ id /);

    my $user = $self->get_user( \%params );
    return unless $user;

    my $data = $self->user_avg_diff($user);

    $self->respond_to( json => { status => 200, json => $data } );
}

=head2 gui_user_id_avg2

    GET /api/gui/user/:id/avg2

=cut

sub api_gui_user_id_avg2 {
    my $self = shift;

    #
    # fetch params
    #
    my %params = $self->get_params(qw/ id /);

    my $user = $self->get_user( \%params );
    return unless $user;

    my $data = $self->user_avg2($user);

    $self->respond_to( json => { status => 200, json => $data } );
}

=head2 postcode_preflight_cors

    OPTIONS /api/postcode/search

=cut

sub api_postcode_preflight_cors {
    my $self = shift;

    my $origin = $self->req->headers->header('origin');
    my $method = $self->req->headers->header('access-control-request-method');

    $self->res->headers->header( 'Access-Control-Allow-Origin'  => $origin );
    $self->res->headers->header( 'Access-Control-Allow-Methods' => $method );
    $self->respond_to( any => { data => '', status => 200 } );
}

=head2 postcode_search

    GET /api/postcode/search

=cut

sub api_postcode_search {
    my $self = shift;
    my $q    = $self->param('q');

    my $origin = $self->req->headers->header('origin');
    $self->res->headers->header( 'Access-Control-Allow-Origin' => $origin );

    if ( length $q < 3 || length $q > 80 ) {
        return $self->error( 400, { str => 'Query is too long or too short : ' . $q } );
    }

    my $p = Postcodify->new( config => $ENV{MOJO_CONFIG} || './app.psgi.conf' );
    my $result = $p->search($q);
    $self->app->log->info("postcode search query: $q");
    $self->render( text => decode_utf8( $result->json ), format => 'json' );
}

=head2 api_upload_photo

    POST /api/photos

=cut

sub api_upload_photo {
    my $self = shift;

    my $v = $self->validation;
    $v->required('key');
    $v->required('photo')->upload->size( 1, 1024 * 1024 * 10 ); # 10MB

    if ( $v->has_error ) {
        my $failed = $v->failed;
        return $self->error(
            400,
            { str => 'Parameter Validation Failed: ' . join( ', ', @$failed ) }
        );
    }

    my $key   = $v->param('key');
    my $photo = $v->param('photo');

    my $temp = Path::Tiny->tempfile;
    $photo->move_to("$temp");

    my $oavatar = $self->config->{oavatar};
    my ( $token, $url ) = ( $oavatar->{token}, $oavatar->{url} );
    return $self->error( 500, { str => 'Configuration failed' } ) unless $token;

    my $multipart = HTTP::Body::Builder::MultiPart->new;
    $multipart->add_content( token => $oavatar->{token} );
    $multipart->add_content( key   => $key );
    $multipart->add_file( img => $temp );

    my $http = HTTP::Tiny->new;
    my $res  = $http->request(
        'POST', $url,
        {
            headers =>
                { 'content-type' => 'multipart/form-data; boundary=' . $multipart->{boundary} },
            content => $multipart->as_string
        }
    );

    unless ( $res->{success} ) {
        my $error = "Failed to upload photo: $res->{reason}";
        $self->log->error($error);
        return $self->error( 500, { str => $error } );
    }

    $self->render( text => $res->{content} );
}

1;
