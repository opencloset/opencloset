package OpenCloset::Web::Controller::Order;
use Mojo::Base 'Mojolicious::Controller';

use Mojo::JSON qw/decode_json/;

use Data::Pageset;
use DateTime::Format::Strptime;
use DateTime;
use HTTP::Tiny;
use List::MoreUtils;
use Try::Tiny;
use WebService::Jandi::WebHook;

use OpenCloset::Calculator::LateFee;
use OpenCloset::Common::Unpaid
    qw/unpaid_cond unpaid_attr is_unpaid is_nonpaid unpaid2fullpaid/;
use OpenCloset::Constants
    qw/%PAY_METHOD_MAP $MAX_EXTENSION_DAYS $DEFAULT_RENTAL_PERIOD/;
use OpenCloset::Constants::Category;
use OpenCloset::Constants::Status
    qw/$RENTAL $RETURNED $PARTIAL_RETURNED $RETURNING $NOT_VISITED $PAYMENT $NOT_RENTAL $PAYBACK $NO_SIZE $BOX $BOXED/;
use OpenCloset::Events::EmploymentWing;

has DB => sub { shift->app->DB };

## Day of week map
my %DOW_MAP = (
    1 => '월',
    2 => '화',
    3 => '수',
    4 => '목',
    5 => '금',
    6 => '토',
    7 => '일',
);

=head1 METHODS

=head2 index

    GET /order

=cut

sub index {
    my $self = shift;

    #
    # fetch params
    #
    my %params        = $self->get_params(qw/ id /);
    my %search_params = $self->get_params(qw/ booking_ymd status /);

    my $q = $self->param('q') || '';
    my $p = $self->param('p') || 1;
    my $s = $self->param('s') || $self->config->{entries_per_page};

    my $rs = $self->get_order_list( { %params, allow_empty => 1, } );

    #
    # undef       => '상태없음'
    # late        => '연체중'
    # rental-late => '대여중(연장아님)'
    # unpaid      => '미납'
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
    # 12    =>  '방문안함'
    # 13    =>  '방문'
    # 14    =>  '방문예약'
    # 15    =>  '배송예약'
    # 16    =>  '치수측정'
    # 17    =>  '의류준비'
    # 18    =>  '포장'
    # 44    =>  '포장완료'
    # 19    =>  '결제대기'
    # 20    =>  '탈의01'
    # 21    =>  '탈의02'
    # 22    =>  '탈의03'
    # 23    =>  '탈의04'
    # 24    =>  '탈의05'
    # 25    =>  '탈의06'
    # 26    =>  '탈의07'
    # 27    =>  '탈의08'
    # 28    =>  '탈의09'
    # 29    =>  '탈의10'
    # 30    =>  '탈의11'
    # 31    =>  '탈의12'
    # 32    =>  '탈의13'
    # 33    =>  '탈의14'
    # 34    =>  '탈의15'
    # 35    =>  '탈의16'
    # 36    =>  '탈의17'
    # 37    =>  '탈의18'
    # 38    =>  '탈의19'
    # 39    =>  '탈의20'
    # 40    =>  '대여안함'
    # 41    =>  '포장취소'
    # 42    =>  '환불'
    # 43    =>  '사이즈없음'
    #

    {
        no warnings 'experimental';
        my $status_id = $search_params{status};
        my $dt_day_end = DateTime->today( time_zone => $self->config->{timezone} )
            ->add( hours => 24, seconds => -1 );
        my $dtf = $self->DB->storage->datetime_parser;
        my %cond;
        my %attr;
        given ($status_id) {
            when ('undef') {
                %cond = ( status_id => { '=' => undef }, );
            }
            when ('late') {
                ## 연체중
                my $dt_day_end =
                    DateTime->today( time_zone => $self->config->{timezone} )->subtract( days => 4 );
                %cond = (
                    -and => [
                        status_id => 2, user_target_date => { '<' => $dtf->format_datetime($dt_day_end) },
                    ],
                );
            }
            when ('rental-late') {
                ## 대여중
                %cond = (
                    -and => [
                        status_id => 2, target_date => { '>=' => $dtf->format_datetime($dt_day_end) },
                    ],
                );
            }
            when ('extension') {
                ## 연장중
                my $today = DateTime->today( time_zone => $self->config->{timezone} );
                %cond = (
                    -and => [
                        status_id        => 2,
                        target_date      => { '<' => $dtf->format_datetime($today) },
                        user_target_date => { '>=' => $dtf->format_datetime($today) },
                        \'DATEDIFF(user_target_date, target_date) > 7',
                    ],
                );
            }
            when ('unpaid') {
                my $cond_ref = unpaid_cond();
                my $attr_ref = unpaid_attr();

                %cond = %$cond_ref;
                %attr = ( %$attr_ref, order_by => 'return_date', );
            }
            when ('nonpaid') {
                %cond = (
                    'order_details.stage' => 4,
                    'order_details.name'  => '불납',
                );
                %attr = ( join => [qw/order_details/], order_by => 'return_date' );
            }
            default {
                my @valid = 1 .. 44;
                %cond = ( status_id => $status_id ) if $status_id ~~ @valid;
            }
        }
        $rs = $rs->search( \%cond, \%attr );
    }

    {
        my $status_id = $search_params{status} || '';
        my $dt_today = DateTime->now( time_zone => $self->config->{timezone} );
        my $booking_ymd = $search_params{booking_ymd} || $dt_today->ymd;
        last unless $booking_ymd;

        unless ( $booking_ymd =~ m/^(\d{4})-(\d{2})-(\d{2})$/ ) {
            $self->log->warn("invalid booking_ymd format: $booking_ymd");
            last;
        }

        my $dt_start = try {
            DateTime->new(
                time_zone => $self->config->{timezone}, year => $1, month => $2,
                day       => $3,
            );
        };
        unless ($dt_start) {
            $self->log->warn("cannot create start datetime object using booking_ymd");
            last;
        }

        my $dt_end = $dt_start->clone->add( hours => 24, seconds => -1 );
        unless ($dt_end) {
            $self->log->warn("cannot create end datetime object using booking_ymd");
            last;
        }

        my $dtf = $self->DB->storage->datetime_parser;
        ## 포장완료, #647
        my @order_by =
            $status_id =~ /^44$/
            ? ( { -asc => 'update_date' }, { -asc => 'booking.date' } )
            : ( { -asc => 'booking.date' }, { -desc => 'update_date' } );
        $rs = $rs->search(
            {
                'booking.date' => {
                    -between => [ $dtf->format_datetime($dt_start), $dtf->format_datetime($dt_end), ],
                },
            },
            { join => [qw/ booking /], order_by => [@order_by], },
        );
    }

    $rs = $rs->search( undef, { page => $p, rows => $s } );
    $rs = $rs->search( { 'user.name' => "$q" }, { join => 'user' } ) if $q;
    my $pageset = Data::Pageset->new(
        {
            total_entries    => $rs->pager->total_entries,
            entries_per_page => $rs->pager->entries_per_page,
            pages_per_set    => 5,
            current_page     => $p,
        }
    );

    #
    # response
    #
    $self->stash(
        order_list => $rs, pageset => $pageset,
        search_status => $search_params{status} || q{},
    );

    $self->respond_to( html => { status => 200 } );
}

=head2 create

    POST /order

=cut

sub create {
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

    my $order = $self->DB->resultset('Order')->find( $order_params{id} );
    return $self->error( 404, { str => "Order not found: $order_params{id}" } )
        unless $order;

    my $success =
        $self->app->api->box2boxed( $order, $order_detail_params{clothes_code} );

    return $self->error(
        500,
        { str => "Failed to update order status from BOX to BOXED" }
    ) unless $success;

    #
    # response
    #
    $self->redirect_to('/rental');
}

=head2 detail

    GET /orders/:id

=cut

sub detail {
    my $self = shift;
    my $id   = $self->param('id');

    my $order = $self->get_order( { id => $id } );
    return unless $order;

    my $user      = $order->user;
    my $user_info = $user->user_info;

    my $today = DateTime->today( time_zone => $self->config->{timezone} );
    my @staff = $self->DB->resultset('User')->search(
        { 'user_info.staff' => 1 },
        {
            join     => 'user_info',
            order_by => 'name'
        }
    );

    my $calc  = OpenCloset::Calculator::LateFee->new;
    my $price = {
        origin   => $calc->price($order),
        discount => $calc->discount_price($order),
        rental   => $calc->rental_price($order),
    };

    my $overdue_days   = $calc->overdue_days($order);
    my $overdue_fee    = $calc->overdue_fee($order);
    my $extension_days = $calc->extension_days($order);
    my $extension_fee  = $calc->extension_fee($order);

    my $returned = $user->orders(
        { status_id => $RETURNED, parent_id => undef },
        { order_by => { -desc => 'return_date' } },
    );

    my ( $unpaid, $nonpaid );
    my $orders = $user->orders;
    while ( my $row = $orders->next ) {
        $unpaid  = is_unpaid($row)  unless $unpaid;
        $nonpaid = is_nonpaid($row) unless $nonpaid;
        last if $unpaid and $nonpaid;
    }

    my $visited = { count => 0, delta => undef, coupon => 0 };
    if ( my $count = $returned->count ) {
        $visited->{count}  = $count;
        $visited->{coupon} = $returned->search(
            {
                coupon_id       => { '!=' => undef },
                'coupon.status' => 'used'
            },
            { join => 'coupon' }
        );
        my $last         = $returned->first;
        my $booking      = $order->booking;
        my $last_booking = $last->booking;
        if ( $booking and $last_booking ) {
            $visited->{last} = $last_booking->date;
        }
    }

    my $details = $order->order_details;

    my @set_clothes;
    {
        use experimental qw( smartmatch );

        my @tops;
        my @bottoms;
        while ( my $detail = $details->next ) {
            my $clothes = $detail->clothes;
            next unless $clothes;
            push @tops, $clothes if $clothes->category eq $JACKET;
            push @bottoms, $clothes if $clothes->category ~~ [ $PANTS, $SKIRT ];
        }
        $details->reset;

        for my $top (@tops) {
            my $suit = $top->suit_code_top;
            next unless $suit;
            next unless $suit->code_bottom;
            next unless $suit->code_bottom->code ~~ [ map $_->code, @bottoms ];
            push @set_clothes, $top, $suit->code_bottom;
        }
    }

    $self->render(
        order          => $order,
        user           => $user,
        user_info      => $user_info,
        staff          => \@staff,
        today          => $today,
        price          => $price,
        visited        => $visited,
        details        => $details,
        set_clothes    => \@set_clothes,
        overdue_days   => $overdue_days,
        overdue_fee    => $overdue_fee,
        extension_days => $extension_days,
        extension_fee  => $extension_fee,
        late_fee       => $overdue_fee + $extension_fee,
        unpaid         => $unpaid,
        nonpaid        => $nonpaid,
    );
}

=head2 late_fee

    GET /orders/:id/late_fee?return_date=yyyy-mm-dd

=cut

sub late_fee {
    my $self = shift;
    my $id   = $self->param('id');

    my $order = $self->get_order( { id => $id } );
    return unless $order;

    my $v = $self->validation;
    $v->optional('return_date')->like(qr/^\d{4}-\d{2}-\d{2}$/);
    return $self->error( 400, { str => "Wrong return_date format: yyyy-mm-dd" } )
        if $v->has_error;

    my $return_date = $v->param('return_date');
    $return_date .= 'T00:00:00' if $return_date;

    my $calc           = OpenCloset::Calculator::LateFee->new;
    my $overdue_days   = $calc->overdue_days( $order, $return_date );
    my $overdue_fee    = $calc->overdue_fee( $order, $return_date );
    my $extension_days = $calc->extension_days( $order, $return_date );
    my $extension_fee  = $calc->extension_fee( $order, $return_date );

    $self->render(
        json => {
            late_fee       => $overdue_fee + $extension_fee,
            overdue_days   => $overdue_days,
            overdue_fee    => $overdue_fee,
            extension_days => $extension_days,
            extension_fee  => $extension_fee,
            formatted      => {
                late_fee => $self->commify( $overdue_fee + $extension_fee ),
                tip      => sprintf(
                    "%d일 연장(%s) + %d일 연체(%s)", $extension_days,
                    $self->commify($extension_fee), $overdue_days, $self->commify($overdue_fee)
                )
            }
        }
    );
}

=head2 update

    POST /order/:id/update

=cut

sub update {
    my $self = shift;

    #
    # fetch params
    #
    my %search_params = $self->get_params(qw/ id /);
    my %update_params = $self->get_params(qw/ name value pk /);

    my $order = $self->get_order( \%search_params );
    return unless $order;

    my @status_objs = $self->DB->resultset('Status')->all;
    my %status;
    $status{ $_->id } = $_->name for @status_objs;

    my $name  = $update_params{name};
    my $value = $update_params{value};
    my $pk    = $update_params{pk};
    $self->log->info("order update: $name.$value");

    #
    # update column
    #
    if ( $name =~ s/^detail-// ) {
        my $detail = $order->order_details( { id => $pk } )->next;
        if ($detail) {
            unless ( $detail->$name eq $value ) {
                $self->log->info(
                    sprintf(
                        "  order_detail.$name %d [%s] -> [%s]",
                        $detail->id,
                        $detail->$name // 'N/A',
                        $value // 'N/A',
                    ),
                );

                if ( $name eq 'price' ) {
                    $self->app->detail_api->update_price( $detail, $value );
                }
                else {
                    $detail->update( { $name => $value } );
                }
            }
        }
    }
    else {
        if ( $name eq 'status_id' ) {
            my $guard = $self->DB->txn_scope_guard;
            try {
                #
                # 쿠폰의 상태를 변경
                #
                #   결제방식이 쿠폰(+현금|+카드)?
                #
                if ( my $coupon = $order->coupon ) {
                    if ( $order->price_pay_with =~ m/쿠폰/ ) {
                        my $coupon_limit =
                            $self->DB->resultset('CouponLimit')->find( { cid => $coupon->desc } );
                        if ($coupon_limit) {
                            my $coupon_count = $self->DB->resultset('Coupon')->search(
                                {
                                    desc   => $coupon->desc,
                                    status => 'used',
                                },
                            )->count;

                            my $log_str = sprintf(
                                "coupon: code(%s), limit(%d), count(%s)",
                                $order->coupon->code,
                                $coupon_limit->limit,
                                $coupon_count,
                            );
                            if ( $coupon_limit->limit == -1 || $coupon_count < $coupon_limit->limit ) {
                                $self->log->debug($log_str);
                            }
                            else {
                                die "coupon limit reached: $log_str\n";
                            }
                        }
                        $coupon->update( { status => 'used' } );
                    }
                }

                unless ( $order->status_id == $value ) {
                    #
                    # update order.status_id
                    #
                    $self->log->info(
                        sprintf(
                            "  order.status: %d [%s] -> [%s]",
                            $order->id,
                            $order->status->name // 'N/A',
                            $status{$value} // 'N/A',
                        ),
                    );
                    $order->update( { $name => $value } );

                    #
                    # GH #614
                    #
                    #   주문확정일때에 SMS 를 전송
                    #   주문서의 상태가 -> 대여중
                    #
                    if ( $value == 2 ) {
                        my $from = $self->config->{sms}{ $self->config->{sms}{driver} }{_from};
                        my $to   = $order->user->user_info->phone;

                        {
                            my $msg = $self->render_to_string(
                                "sms/order-confirmed-1",
                                format => 'txt',
                                order  => $order,
                            );

                            my $sms = $self->DB->resultset('SMS')->create(
                                {
                                    to   => $to,
                                    from => $from,
                                    text => $msg,
                                }
                            );

                            $self->log->error("Failed to create a new SMS: $msg") unless $sms;
                        }

                        #
                        # GH #949
                        #
                        #   기증 이야기 안내를 별도의 문자로 전송
                        #
                        #   이때, 다음과 같은 우선 순위로 기증 메시지를 보여주며,
                        #   기증 메시지가 없을 경우 문자를 발송하지 않음.
                        #
                        #   자켓
                        #   바지
                        #   스커트
                        #   원피스
                        #   코트
                        #   조끼
                        #   셔츠
                        #   블라우스
                        #   타이
                        #   벨트
                        #   구두
                        #   기타
                        #
                        {

                            my @clothes_list;
                            for my $order_detail ( $order->order_details ) {
                                next unless $order_detail->clothes;
                                next unless $order_detail->clothes->donation;
                                next unless $order_detail->clothes->donation->message;

                                push @clothes_list, $order_detail->clothes;
                            }

                            my %category_score = (
                                $OpenCloset::Constants::Category::JACKET    => 10,
                                $OpenCloset::Constants::Category::PANTS     => 20,
                                $OpenCloset::Constants::Category::SKIRT     => 30,
                                $OpenCloset::Constants::Category::ONEPIECE  => 40,
                                $OpenCloset::Constants::Category::COAT      => 50,
                                $OpenCloset::Constants::Category::WAISTCOAT => 60,
                                $OpenCloset::Constants::Category::SHIRT     => 70,
                                $OpenCloset::Constants::Category::BLOUSE    => 80,
                                $OpenCloset::Constants::Category::TIE       => 90,
                                $OpenCloset::Constants::Category::BELT      => 100,
                                $OpenCloset::Constants::Category::SHOES     => 110,
                                $OpenCloset::Constants::Category::MISC      => 120,
                            );

                            my @sorted_clothes_list =
                                sort { $category_score{ $a->category } <=> $category_score{ $b->category } }
                                @clothes_list;

                            my $clothes = $sorted_clothes_list[0];
                            my $donation = $clothes->donation if $clothes;
                            if ( $clothes and $donation ) {
                                my $msg = $self->render_to_string(
                                    "sms/order-confirmed-2",
                                    format   => 'txt',
                                    order    => $order,
                                    donation => $donation,
                                    category => $OpenCloset::Constants::Category::LABEL_MAP{ $clothes->category },
                                );

                                my $sms = $self->DB->resultset('SMS')->create(
                                    {
                                        to   => $to,
                                        from => $from,
                                        text => $msg,
                                    }
                                );

                                $self->log->debug(
                                    sprintf(
                                        "donation message: order(%d), donation(%d), clothes(%s)",
                                        $order->id,
                                        $donation->id,
                                        $clothes->code,
                                    )
                                );

                                $self->log->error("Failed to create a new SMS: $msg") unless $sms;
                            }
                            else {
                                $self->log->info( "no donation message to send SMS for order: " . $order->id );
                            }
                        }
                    }
                }

                #
                # update clothes.status_id
                #
                for my $clothes ( $order->clothes ) {
                    unless ( $clothes->status_id == $value ) {
                        $self->log->info(
                            sprintf(
                                "  clothes.status: [%s] [%s] -> [%s]",
                                $clothes->code,
                                $clothes->status->name // 'N/A',
                                $status{$value} // 'N/A',
                            ),
                        );
                        $clothes->update( { $name => $value } );
                    }
                }

                #
                # update order_detail.status_id
                #
                for my $order_detail ( $order->order_details ) {
                    next unless $order_detail->clothes;

                    unless ( $order_detail->status_id == $value ) {
                        $self->log->info(
                            sprintf(
                                "  order_detail.status: %d [%s] -> [%s]",
                                $order_detail->id,
                                $order_detail->status->name // 'N/A',
                                $status{$value} // 'N/A',
                            ),
                        );
                        $order_detail->update( { $name => $value } );
                    }
                }

                $guard->commit;
            }
            catch {
                $self->log->error("failed to update status of the order & clothes");
                $self->log->error($_);
            };
        }
        else {
            unless ( $order->$name eq $value ) {
                $self->log->info(
                    sprintf(
                        "  order.$name: %d %s -> %s", $order->id, $order->$name // 'N/A', $value // 'N/A',
                    ),
                );
                $order->update( { $name => $value } );
            }
        }
    }

    #
    # response
    #
    $self->respond_to( { data => q{} } );
}

=head2 order_return

    GET /order/:order_id/return

=cut

sub order_return {
    my $self = shift;

    my $order_id = $self->param('order_id');
    my $order = $self->get_order( { id => $order_id } );
    return unless $order;

    my $error = $self->flash('error');
    $self->render( order => $order, error => $error );
}

=head2 create_order_return

    POST /order/:order_id/return

=cut

sub create_order_return {
    my $self     = shift;
    my $order_id = $self->param('order_id');
    my $order    = $self->get_order( { id => $order_id } );
    return unless $order;

    ## parameters validation
    my $v = $self->validation;
    $v->required('parcel');
    $v->required('phone');
    $v->required('waybill');

    if ( $v->has_error ) {
        my $errors = {};
        my $failed = $v->failed;
        map { $errors->{$_} = $v->error($_) } @$failed;
        $self->flash( error => $errors );
        return $self->redirect_to( $self->url_for );
    }

    my $parcel  = $v->param('parcel');
    my $phone   = $v->param('phone');
    my $waybill = $v->param('waybill');

    ## phone number validation
    my $user_phone = $order->user->user_info->phone;
    if ( $phone ne $user_phone ) {
        $self->flash(
            error => {
                phone => [
                    '대여예약시에 사용했던 동일한 핸드폰 번호를 입력해주세요']
            }
        );
        return $self->redirect_to( $self->url_for );
    }

    $self->update_order(
        { id => $order_id, return_method => join( ',', $parcel, $waybill ) } );
    $self->redirect_to( $self->url_for("/order/$order_id/return/success") );
}

=head2 order_return_success

    GET /order/:order_id/return/success

=cut

sub order_return_success {
    my $self = shift;

    my $order_id = $self->param('order_id');
    my $order = $self->get_order( { id => $order_id } );
    return unless $order;

    $self->render( order => $order );
}

=head2 order_extension

    GET /order/:order_id/extension

=cut

sub order_extension {
    my $self = shift;

    my $order_id = $self->param('order_id');
    my $order = $self->get_order( { id => $order_id } );
    return $self->error( 404, { str => 'Order not found' }, 'error/not_found' )
        unless $order;

    my $calc           = OpenCloset::Calculator::LateFee->new;
    my $overdue_days   = $calc->overdue_days($order);
    my $extension_days = $calc->extension_days($order);
    my $rental_date    = $order->rental_date;
    return $self->error( 400, { str => 'Missing rental_date' }, 'error/bad_request' )
        unless $rental_date;

    my $today = DateTime->today( time_zone => $self->config->{timezone} );
    ## $DEFAULT_RENTAL_PERIOD: 3 인데 3박 4일 대여라서 +1
    my $end_date =
        $rental_date->clone->add(
        days => $DEFAULT_RENTAL_PERIOD + $MAX_EXTENSION_DAYS + 1 );
    my $dur = $end_date->delta_days($today);
    my ($delta_days) = $dur->in_units('days');

    my $error = $self->flash('error');
    $self->render(
        order     => $order,
        error     => $error,
        overdue   => { days => $overdue_days },
        extension => { days => $extension_days },
        end_days  => $delta_days,
    );
}

=head2 create_order_extension

    POST /order/:order_id/extension

=cut

sub create_order_extension {
    my $self     = shift;
    my $order_id = $self->param('order_id');
    my $order    = $self->get_order( { id => $order_id } );
    return $self->error( 404, { str => 'Order not found' }, 'error/not_found' )
        unless $order;

    my $rental_date = $order->rental_date;
    return $self->error( 400, { str => 'Missing rental_date' }, 'error/bad_request' )
        unless $rental_date;

    ## parameters validation
    my $v = $self->validation;
    $v->required('phone');
    $v->required('user-target-date');

    if ( $v->has_error ) {
        my $errors = {};
        my $failed = $v->failed;
        map { $errors->{$_} = $v->error($_) } @$failed;
        $self->flash( error => $errors );
        return $self->redirect_to( $self->url_for );
    }

    my $phone       = $v->param('phone');
    my $target_date = $v->param('user-target-date');

    ## phone number validation
    my $user_phone = $order->user->user_info->phone;
    if ( $phone ne $user_phone ) {
        $self->flash(
            error => {
                phone => [
                    '대여예약시에 사용했던 동일한 핸드폰 번호를 입력해주세요']
            }
        );
        return $self->redirect_to( $self->url_for );
    }

    my $calc           = OpenCloset::Calculator::LateFee->new;
    my $overdue_days   = $calc->overdue_days($order);
    my $extension_days = $calc->extension_days($order);
    if ($overdue_days) {
        return $self->error(
            400,
            { str => '연체중에는 연장을 할 수 없습니다.' }, 'error/bad_request'
        );
    }

    if ( $extension_days >= $MAX_EXTENSION_DAYS ) {
        return $self->error(
            400,
            {
                str =>
                    "최대연장기간($MAX_EXTENSION_DAYS 일) 이상 연장할 수 없습니다"
            },
            'error/bad_request'
        );
    }

    my $strp = DateTime::Format::Strptime->new(
        pattern   => '%Y-%m-%d',
        time_zone => $self->config->{timezone},
        on_error  => 'undef',
    );

    my $today = DateTime->today( time_zone => $self->config->{timezone} );
    my $dt = $strp->parse_datetime($target_date);
    my $max_date =
        $rental_date->clone->add(
        days => $DEFAULT_RENTAL_PERIOD + $MAX_EXTENSION_DAYS + 1 );

    if ( $dt > $max_date ) {
        return $self->error(
            400,
            { str => "최대연장기간 이상 연장할 수 없습니다" },
            'error/bad_request'
        );
    }

    $self->update_order( { id => $order_id, user_target_date => $target_date } );
    $self->redirect_to( $self->url_for("/order/$order_id/extension/success") );
}

=head2 order_extension_success

    GET /order/:order_id/extension/success

=cut

sub order_extension_success {
    my $self = shift;

    my $order_id = $self->param('order_id');
    my $order = $self->get_order( { id => $order_id } );
    return unless $order;

    $self->render( order => $order );
}

=head2 order_pdf

    GET /order/:order_id/pdf

=cut

sub rental_paper_pdf {
    my $self = shift;

    my $order_id = $self->param("order_id");
    my $order = $self->get_order( { id => $order_id } );
    return unless $order;

    my @donation_user_names =
        List::MoreUtils::uniq map { $_->donation->user->name } $order->clothes;

    my %donation_info;
    for my $clothes ( $order->clothes ) {
        my $user = $clothes->donation->user;

        unless ( $donation_info{ $user->id } ) {
            $donation_info{ $user->id }{name}     = $user->name;
            $donation_info{ $user->id }{category} = [];
        }

        push @{ $donation_info{ $user->id }{category} }, $clothes->category;
    }
    my @donation_str;
    my %category_score = (
        $OpenCloset::Constants::Category::JACKET    => 10,
        $OpenCloset::Constants::Category::PANTS     => 20,
        $OpenCloset::Constants::Category::SKIRT     => 30,
        $OpenCloset::Constants::Category::ONEPIECE  => 40,
        $OpenCloset::Constants::Category::COAT      => 50,
        $OpenCloset::Constants::Category::WAISTCOAT => 60,
        $OpenCloset::Constants::Category::SHIRT     => 70,
        $OpenCloset::Constants::Category::BLOUSE    => 80,
        $OpenCloset::Constants::Category::TIE       => 90,
        $OpenCloset::Constants::Category::BELT      => 100,
        $OpenCloset::Constants::Category::SHOES     => 110,
        $OpenCloset::Constants::Category::MISC      => 120,
    );
    for my $key (
        sort { $donation_info{$a}{name} cmp $donation_info{$b}{name} }
        keys %donation_info
        )
    {
        my @sorted_category_list =
            map  { $OpenCloset::Constants::Category::LABEL_MAP{$_}; }
            sort { $category_score{$a} <=> $category_score{$b} }
            List::MoreUtils::uniq @{ $donation_info{$key}{category} };

        push(
            @donation_str,
            sprintf(
                "[%s] %s",
                join( ", ", @sorted_category_list ),
                $donation_info{$key}{name},
            ),
        );
    }

    my $rental_date =
          $order->rental_date
        ? $order->rental_date->clone->set_time_zone( $self->config->{timezone} )
        : DateTime->today( time_zone => $self->config->{timezone} );
    my $target_date =
          $order->target_date
        ? $order->target_date->clone->set_time_zone( $self->config->{timezone} )
        : DateTime->today( time_zone => $self->config->{timezone} )
        ->add( days => 4, seconds => -1 );

    my $rental_date_str =
        $rental_date->set_locale("ko_KR")->strftime("대여 %m월 %d일(%a)");
    my $target_date_str =
        $target_date->set_locale("ko_KR")->strftime("반납 %m월 %d일(%a)");

    #
    # response
    #
    $self->stash(
        order           => $order,
        donation_str    => Mojo::JSON::to_json( \@donation_str ),
        rental_date_str => $rental_date_str,
        target_date_str => $target_date_str,
    );
}

=head2 auth

    under /order/:id

=cut

sub auth {
    my $self  = shift;
    my $id    = $self->param('id');
    my $phone = $self->param('phone') || '';

    my $order = $self->DB->resultset('Order')->find( { id => $id } );
    unless ($order) {
        $self->error(
            404, { str => "주문서를 찾을 수 없습니다: $id" },
            'error/not_found'
        );
        return;
    }

    unless ($phone) {
        $self->error(
            400, { str => "본인확인을 할 수 없습니다." },
            'error/bad_request'
        );
        return;
    }

    if ( $order->status_id != 14 ) {
        $self->error(
            400,
            { str => "방문예약 상태의 주문서만 변경/취소할 수 있습니다." },
            'error/bad_request'
        );
        return;
    }

    my $user      = $order->user;
    my $user_info = $user->user_info;

    unless ( $user_info->gender ) {
        $self->error(
            400, { str => "성별을 확인할 수 없습니다." },
            'error/bad_request'
        );
        return;
    }

    if ( substr( $user_info->phone, -4 ) ne $phone ) {
        $self->error(
            400,
            { str => "대여자의 휴대폰번호와 일치하지 않습니다." },
            'error/bad_request'
        );
        return;
    }

    my $booking = $order->booking;
    unless ( $booking and $booking->date ) {
        $self->error(
            400, { str => "예약시간이 비어있습니다." },
            'error/bad_request'
        );
        return;
    }

    ## 예약일이 이미 지난날이면 아니됨 최대 오늘까지
    my $today = DateTime->today( time_zone => $self->config->{timezone} );
    my $booking_day = $booking->date->clone->truncate( to => 'day' );
    if ( $today->epoch - $booking_day->epoch > 0 ) {
        $self->error(
            400,
            { str => "예약시간이 지났습니다. 다시 방문예약을 해주세요." },
            'error/bad_request'
        );
        return;
    }

    $self->stash(
        order     => $order,
        user      => $user,
        user_info => $user_info,
        booking   => $booking
    );

    return 1;
}

=head2 cancel_form

    GET /order/:id/cancel?phone=xxxx

=cut

sub cancel_form {
    my $self    = shift;
    my $booking = $self->stash('booking');
    my $dow     = $booking->date->day_of_week;
    $self->render( day_of_week => $DOW_MAP{$dow} );
}

=head2 delete_cors

    OPTIONS /order/:id

=cut

sub delete_cors {
    my $self = shift;

    my $origin = $self->req->headers->header('origin');
    my $method = $self->req->headers->header('access-control-request-method');

    return $self->error( 400, "Not Allowed Origin: $origin" )
        unless $origin =~ m/theopencloset\.net/;

    $self->res->headers->header( 'Access-Control-Allow-Origin'  => $origin );
    $self->res->headers->header( 'Access-Control-Allow-Methods' => $method );
    $self->respond_to( any => { data => '', status => 200 } );
}

=head2 delete

    DELETE /order/:id?phone=xxxx

=cut

sub delete {
    my $self  = shift;
    my $order = $self->stash('order');

    $self->app->api->cancel($order);
    $self->render( json => {} );
}

=head2 booking

    GET /order/:id/booking/edit

=cut

sub booking {
    my $self         = shift;
    my $user_info    = $self->stash('user_info');
    my @booking_list = $self->booking_list( $user_info->gender );
    return unless @booking_list;

    my $pattern = '%Y-%m-%d';
    my $strp    = DateTime::Format::Strptime->new(
        pattern   => $pattern,
        time_zone => $self->config->{timezone},
        on_error  => 'undef',
    );

    my %dateby;
    for my $row (@booking_list) {
        my $ymd = substr $row->{date}, 0,  10;
        my $hm  = substr $row->{date}, -8, 5;

        my $dt  = $strp->parse_datetime($ymd);
        my $dow = $dt->day_of_week;
        if ( $row->{slot} - $row->{user_count} ) {
            $row->{date_str} = sprintf "%s (%s요일) %s %d명 예약 가능", $ymd,
                $DOW_MAP{$dow}, $hm, $row->{slot} - $row->{user_count};
        }
        else {
            $row->{date_str} = sprintf "%s (%s요일) %s 예약 인원 초과", $ymd,
                $DOW_MAP{$dow}, $hm;
        }

        push @{ $dateby{$ymd} }, $row;
    }

    $self->render( booking_list => \%dateby );
}

=head2 update_booking

    PUT /order/:id/booking

=cut

sub update_booking {
    my $self  = shift;
    my $order = $self->stash('order');

    my $v = $self->validation;
    $v->required('booking_id');

    return $self->error( 400, { str => 'booking_id is required' }, 'error/bad_request' )
        if $v->has_error;

    my $booking_id = $v->param('booking_id');
    my $booking    = $self->DB->resultset('Booking')->find( { id => $booking_id } );
    my $success    = $self->app->api->update_reservated( $order, $booking->date );
    my $message =
        $success
        ? '예약시간이 변경되었습니다.'
        : '예약시간을 변경하지 못했습니다.';
    $self->flash( alert => $message );
    $self->render( json => $self->flatten_booking( $order->booking ) );
}

=head2 create_coupon

    POST /order/:id/coupon

=cut

sub create_coupon {
    my $self = shift;
    my $id   = $self->param('id');

    my $order = $self->DB->resultset('Order')->find( { id => $id } );
    return $self->error( 404, { str => "Not found order: $id" } ) unless $order;

    my $v = $self->validation;
    $v->required('coupon-code')->like(qr/^[0-9A-Z]{4}-[0-9A-Z]{4}-[0-9A-Z]{4}$/);
    return $self->error( 400, { str => 'Invalid coupon-code' } ) if $v->has_error;

    my $coupon_code = $self->param('coupon-code');
    my ( $coupon, $error ) = $self->coupon_validate($coupon_code);
    if ($error) {
        if ( $error =~ /used/ ) {
            my $coupon = $self->DB->resultset('Coupon')->find( { code => $coupon_code } );
            return $self->error( 400, { str => $error } ) unless $coupon;

            my $other = $coupon->orders( undef, { rows => 1 } )->single;
            return $self->error( 400, { str => $error } ) unless $other;

            my $url = $self->url_for( '/order/' . $other->id );
            return $self->render(
                status => 400,
                json   => {
                    error => $error,
                    order => $url->to_abs,
                }
            );
        }

        return $self->error( 400, { str => $error } );
    }

    $self->transfer_order( $coupon, $order );
    $self->discount_order($order) if $order->status_id == $PAYMENT;
    $self->render( json => { $coupon->get_columns } );
}

=head2 iamport_unpaid_hook

iamport로 부터 전달받는 가상계좌의 완납 hook

    POST /webhooks/iamport/unpaid

=cut

sub iamport_unpaid_hook {
    my $self = shift;

    my $v = $self->validation;
    $v->required("imp_uid");
    $v->required("merchant_uid");
    $v->required("status");

    my $sid    = $v->param("imp_uid");
    my $cid    = $v->param("merchant_uid");
    my $status = $v->param("status");

    my $payment = $self->DB->resultset("Payment")->find( { sid => $sid } );
    unless ($payment) {
        $self->log->warn("Not found payment: sid($sid)");
        $payment = $self->DB->resultset("Payment")->find( { cid => $cid } );
        return $self->error( 404, "Not found payment: cid($cid)" ) unless $payment;
    }

    my $payment_id = $payment->id;
    my $order      = $payment->order;
    return $self->error( 404, "Not found order: payment_id($payment_id)" ) unless $order;

    my $payment_log = $payment->payment_logs(
        {},
        {
            order_by => { -desc => "id" },
            rows     => 1
        }
    )->next;

    return $self->error( 404, "Not found payment log: payment_id($payment_id)" )
        unless $payment_log;

    ## 이후부터는 내부 처리중에 오류가 발생하더라도 완납 처리를 해야함
    ## 가상계좌(vbank)의 ready -> paid
    my $last_status = $payment_log->status || '';
    if ( $last_status eq "ready" && $status eq "paid" ) {
        ## 미납 -> 완납으로 변경
        unpaid2fullpaid( $order, $payment->amount, $PAY_METHOD_MAP{ $payment->pay_method } );

        my $iamport = $self->app->iamport;
        my $json    = $iamport->payment($sid);
        unless ($json) {
            $self->log->warn("Failed to get payment info from iamport: sid($sid)");
            return $self->render( text => '', status => 500 );
        }

        $payment->create_related(
            "payment_logs",
            {
                status => $status,
                detail => $json,
            },
        );

        my $data       = decode_json($json);
        my $amount     = $data->{response}{amount};
        my $vbank_num  = $data->{response}{vbank_num};
        my $buyer_name = $data->{response}{buyer_name};
        my $buyer_tel  = $data->{response}{buyer_tel};
        my $paid_at    = $data->{response}{paid_at};

        my $paid_dt = DateTime->from_epoch(
            epoch     => $paid_at,
            time_zone => $self->config->{timezone}
        );

        my $jandi = WebService::Jandi::WebHook->new( $self->config->{jandi}{hook} );
        return $self->render( text => 'OK' ) unless $jandi;

        my $msg = {
            body => sprintf(
                "[[결제완료]](%s) %s님", $self->url_for( '/orders/' . $order->id )->to_abs,
                $buyer_name
            ),
            connectColor => '#FAC11B',
            connectInfo  => [
                {
                    title       => '주문서 번호',
                    description => $order->id,
                },
                {
                    title       => '전화번호',
                    description => $buyer_tel,
                },
                {
                    title       => '금액',
                    description => $self->commify($amount),
                },
                {
                    title       => '결제시간',
                    description => $paid_dt->strftime('%F %T'),
                },
                {
                    title       => '계좌번호',
                    description => $vbank_num,
                },
            ]
        };

        my $res = $jandi->request($msg);
        unless ( $res->{success} ) {
            $self->log->error("Failed to post jandi message");
            $self->log->error("$res->{status}: $res->{reason}");
        }
    }

    $self->render( text => "OK" );
}

=head2 iamport_withoutorder_hook

iamport로 부터 전달받는 주문서 정보없는 가상계좌의 hook

    POST /webhooks/iamport/withoutorder

=cut

sub iamport_withoutorder_hook {
    my $self = shift;

    my $v = $self->validation;
    $v->required("imp_uid");
    $v->required("merchant_uid");
    $v->required("status");

    if ( $v->has_error ) {
        my $failed = $v->failed;
        $self->log->error('Missing required parameter from iamport');
        $self->log->error( 'Parameter Validation Failed: ' . join( ', ', @$failed ) );
        return $self->render( text => "NOT OK" );
    }

    my $imp_uid      = $v->param("imp_uid");
    my $merchant_uid = $v->param("merchant_uid");
    my $status       = $v->param("status");

    return $self->render( text => "NOT OK" ) if $status ne 'paid';

    my $iamport    = $self->app->iamport;
    my $json       = $iamport->payment($imp_uid);
    my $data       = decode_json($json);
    my $amount     = $data->{response}{amount};
    my $vbank_num  = $data->{response}{vbank_num};
    my $buyer_name = $data->{response}{buyer_name};
    my $buyer_tel  = $data->{response}{buyer_tel};
    my $paid_at    = $data->{response}{paid_at};

    my $paid_dt = DateTime->from_epoch(
        epoch     => $paid_at,
        time_zone => $self->config->{timezone}
    );

    my $jandi = WebService::Jandi::WebHook->new( $self->config->{jandi}{hook} );
    return $self->render( text => 'OK' ) unless $jandi;

    my $msg = {
        body => sprintf(
            "[[결제완료]](https://admin.iamport.kr/payments) %s님", $buyer_name
        ),
        connectColor => '#FAC11B',
        connectInfo  => [
            {
                title       => '전화번호',
                description => $buyer_tel,
            },
            {
                title       => '금액',
                description => $self->commify($amount),
            },
            {
                title       => '결제시간',
                description => $paid_dt->strftime('%F %T'),
            },
            {
                title       => '계좌번호',
                description => $vbank_num,
            },
        ]
    };

    my $res = $jandi->request($msg);
    unless ( $res->{success} ) {
        $self->log->error("Failed to post jandi message");
        $self->log->error("$res->{status}: $res->{reason}");
    }

    $self->render( text => "OK" );
}

1;
