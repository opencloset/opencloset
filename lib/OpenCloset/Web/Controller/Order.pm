package OpenCloset::Web::Controller::Order;
use Mojo::Base 'Mojolicious::Controller';

use Data::Pageset;
use DateTime;
use HTTP::Tiny;
use List::MoreUtils;
use Try::Tiny;

use OpenCloset::Constants::Status qw/$RETURNED/;

has DB => sub { shift->app->DB };

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
    # late        => '연장중'
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
                %cond = (
                    -and => [
                        status_id => 2, target_date => { '<' => $dtf->format_datetime($dt_day_end) },
                    ],
                );
            }
            when ('rental-late') {
                %cond = (
                    -and => [
                        status_id => 2, target_date => { '>=' => $dtf->format_datetime($dt_day_end) },
                    ],
                );
            }
            when ('unpaid') {
                my ( $cond_ref, $attr_ref ) = $self->get_dbic_cond_attr_unpaid;

                %cond = %$cond_ref;
                %attr = ( %$attr_ref, order_by => 'return_date', );
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
            $self->app->log->warn("invalid booking_ymd format: $booking_ymd");
            last;
        }

        my $dt_start = try {
            DateTime->new(
                time_zone => $self->config->{timezone}, year => $1, month => $2,
                day       => $3,
            );
        };
        unless ($dt_start) {
            $self->app->log->warn("cannot create start datetime object using booking_ymd");
            last;
        }

        my $dt_end = $dt_start->clone->add( hours => 24, seconds => -1 );
        unless ($dt_end) {
            $self->app->log->warn("cannot create end datetime object using booking_ymd");
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

#
# GH #790: 3회째 대여자 부터 대여자의 부담을 줄이기 위해 비용을 할인함
#
sub _sale_order {
    my ( $self, $order, $order_details ) = @_;

    #
    # 쿠폰을 제외하고 몇 회째 대여인가?
    #
    my $visited = 0;
    {
        my $orders                          = $order->user->orders;
        my $visited_without_coupon_order_rs = $orders->search(
            {
                status_id => $RETURNED,
                parent_id => undef,
                -and      => [
                    -or => [
                        {
                            "coupon.id"     => { "!=" => undef },
                            "coupon.status" => { "!=" => "used" },
                        },
                        {
                            "coupon.id" => undef,
                        },
                    ],
                ],
            },
            {
                join => [qw/ coupon /],
            },
        );

        $visited = $visited_without_coupon_order_rs->count;
        $self->app->log->debug(
            sprintf( "order %d: %d visited without coupon", $order->id, $visited ) );
    }

    #
    # 3회 째 방문이라면 조건 충족
    #
    return unless $visited >= 2;

    my %order_details_by_category = (
        "shirt-blouse" => [],
        "pants-skirt"  => [],
        "jacket"       => [],
        "tie"          => [],
        "shoes"        => [],
        "belt"         => [],
        "etc"          => [],
    );
    my %count_by_category = (
        "shirt-blouse" => 0,
        "pants-skirt"  => 0,
        "jacket"       => 0,
        "tie"          => 0,
        "shoes"        => 0,
        "belt"         => 0,
        "etc"          => 0,
    );
    my $jacket      = 0;
    my $pants_skirt = 0;
    for my $order_detail (@$order_details) {
        my $category = $order_detail->{clothes_category};

        use experimental qw( smartmatch );
        given ($category) {
            when (/^shirt|blouse$/) {
                my $adjust_category = "shirt-blouse";
                push @{ $order_details_by_category{$adjust_category} }, $order_detail;
                ++$count_by_category{$adjust_category};
            }
            when (/^pants|skirt$/) {
                my $adjust_category = "pants-skirt";
                push @{ $order_details_by_category{$adjust_category} }, $order_detail;
                ++$count_by_category{$adjust_category};
            }
            when (/^jacket|tie|shoes|belt$/) {
                push @{ $order_details_by_category{$category} }, $order_detail;
                ++$count_by_category{$category};
            }
            default {
                my $adjust_category = "etc";
                push @{ $order_details_by_category{$adjust_category} }, $order_detail;
                ++$count_by_category{$adjust_category};
            }
        }
    }

    #
    # 재킷 또는 바지, 치마가 각각 3개 미만이어야 조건 충족
    #
    return
        unless $count_by_category{"jacket"} < 3 && $count_by_category{"pants-skirt"} < 3;

    my $ea = List::MoreUtils::each_arrayref(
        $order_details_by_category{"shirt-blouse"},
        $order_details_by_category{"pants-skirt"},
        $order_details_by_category{"jacket"},
        $order_details_by_category{"tie"},
        $order_details_by_category{"shoes"},
        $order_details_by_category{"belt"},
    );
    while ( my ( $shirt_blouse, $pants_skirt, $jacket, $tie, $shoes, $belt ) = $ea->() )
    {
        if ( $jacket && $pants_skirt ) {
            if ($tie) {
                $tie->{price}       = 0;
                $tie->{final_price} = 0;

                if ( $shirt_blouse || $shoes || $belt ) {
                    #
                    # 위 아래 셋트와 타이가 있으며 다른 항목이 있으므로 셋트 가격만 지불
                    #
                    for my $order_detail ( $shirt_blouse, $shoes, $belt ) {
                        next unless $order_detail;

                        $order_detail->{price}       = 0;
                        $order_detail->{final_price} = 0;
                    }
                }
                else {
                    #
                    # 위 아래 셋트와 타이가 있으며 다른 항목이 없으므로 30% 할인
                    #
                    for my $order_detail ( $jacket, $pants_skirt, $tie ) {
                        next unless $order_detail;

                        $order_detail->{price}       *= 0.7;
                        $order_detail->{final_price} *= 0.7;
                    }
                }
            }
            else {
                if ( $shirt_blouse || $shoes || $belt ) {
                    #
                    # 위 아래 셋트이며 다른 항목이 있으므로 셋트 가격만 지불
                    #
                    for my $order_detail ( $shirt_blouse, $shoes, $belt ) {
                        next unless $order_detail;

                        $order_detail->{price}       = 0;
                        $order_detail->{final_price} = 0;
                    }
                }
                else {
                    #
                    # 위 아래 셋트이며 다른 항목이 없으므로 30% 할인
                    #
                    for my $order_detail ( $jacket, $pants_skirt ) {
                        next unless $order_detail;

                        $order_detail->{price}       *= 0.7;
                        $order_detail->{final_price} *= 0.7;
                    }
                }
            }
        }
        else {
            #
            # 위 아래 셋트가 아니므로 일괄 30% 할인
            #
            if ($tie) {
                $tie->{price}       = 2000;
                $tie->{final_price} = 2000;
            }
            for my $order_detail ( $shirt_blouse, $pants_skirt, $jacket, $tie, $shoes, $belt ) {
                next unless $order_detail;

                $order_detail->{price}       *= 0.7;
                $order_detail->{final_price} *= 0.7;
            }
        }
    }

    #
    # 이외의 항목은 일괄 30% 할인
    #
    for my $order_detail ( @{ $order_details_by_category{etc} } ) {
        $order_detail->{price}       *= 0.7;
        $order_detail->{final_price} *= 0.7;
    }
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

    my ( $order, $error ) = do {
        my $guard = $self->DB->txn_scope_guard;
        try {
            use experimental qw( smartmatch );

            #
            # find order
            #
            my $order = $self->DB->resultset('Order')->find( $order_params{id} );
            die "order not found: $order_params{id}\n" unless $order;

            my @invalid = (
                2,  # 대여중
                9,  # 반납
                10, # 부분반납
                11, # 반납배송중
                12, # 방문안함
                19, # 결제대기
                40, # 대여안함
                42, # 환불
                43, # 사이즈없음
                44, # 포장완료
            );
            my $status_id = $order->status_id;
            if ( $status_id ~~ @invalid ) {
                my $status = $self->DB->resultset('Status')->find($status_id)->name;
                die "이미 $status 인 주문서 입니다.\n";
            }

            #
            # 주문서를 포장완료(44) 상태로 변경
            #
            $order->update( { status_id => 44 } );

            #
            # event posting to opencloset/monitor
            #
            my $monitor_uri_full = $self->config->{monitor_uri} . "/events";
            my $res = HTTP::Tiny->new( timeout => 1 )->post_form(
                $monitor_uri_full,
                { sender => 'order', order_id => $order_params{id}, from => 18, to => 44 },
            );
            $self->app->log->warn(
                "Failed to post event to monitor: $monitor_uri_full: $res->{reason}")
                unless $res->{success};

            my @order_details;
            for ( my $i = 0; $i < @{ $order_detail_params{clothes_code} }; ++$i ) {
                my $clothes_code = $order_detail_params{clothes_code}[$i];
                my $clothes = $self->DB->resultset('Clothes')->find( { code => $clothes_code } );

                die "clothes not found: $clothes_code\n" unless $clothes;

                my $name = join(
                    q{ - },
                    $self->trim_clothes_code($clothes),
                    $self->config->{category}{ $clothes->category }{str},
                );

                #
                # 주문서 하부의 모든 의류 항목을 결제대기(19) 상태로 변경
                #
                $clothes->update( { status_id => 19 } );

                push(
                    @order_details,
                    {
                        clothes_code     => $clothes->code,
                        clothes_category => $clothes->category,
                        status_id        => 19
                        , # 주문서 하부의 모든 의류 항목을 결제대기(19) 상태로 변경
                        name        => $name,
                        price       => $clothes->price,
                        final_price => $clothes->price,
                    },
                );
            }

            #
            # GH #790: 3회째 대여자 부터 대여자의 부담을 줄이기 위해 비용을 할인함
            #
            $self->_sale_order( $order, \@order_details ) if $self->config->{sale}{enable};

            for my $order_detail (@order_details) {
                $order->add_to_order_details(
                    {
                        clothes_code => $order_detail->{clothes_code},
                        status_id    => $order_detail->{status_id},
                        name         => $order_detail->{name},
                        price        => $order_detail->{price},
                        final_price  => $order_detail->{final_price},
                    }
                ) or die "failed to create a new order_detail\n";
            }

            $order->add_to_order_details(
                {
                    name        => '배송비',
                    price       => 0,
                    final_price => 0,
                }
            ) or die "failed to create a new order_detail for delivery_fee\n";

            $order->add_to_order_details(
                {
                    name        => '에누리',
                    price       => 0,
                    final_price => 0,
                }
            ) or die "failed to create a new order_detail for discount\n";

            #
            # 쿠폰을 사용했다면 결제방법을 입력
            #
            if ( my $coupon = $order->coupon ) {
                my $type           = $coupon->type;
                my $price_pay_with = '쿠폰';
                $price_pay_with .= '+현금' if $type eq 'default';
                $order->update( { price_pay_with => $price_pay_with } );
            }

            $guard->commit;

            return $order;
        }
        catch {
            chomp;
            $self->app->log->error("failed to update the order & create a new order_detail");
            $self->app->log->error($_);
            return ( undef, $_ );
        }
    };
    return $self->error( 500, { str => $error } ) unless $order;

    #
    # response
    #
    $self->redirect_to('/rental');
}

=head2 order

    GET /order/:id

=cut

sub order {
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
    # 결제 대기 상태이면 사용자의 정보를 주문서에 동기화 시킴
    #
    if ( $order->status_id == 19 ) {
        my $user      = $order->user;
        my $user_info = $user->user_info;
        my $comment   = $user_info->comment ? $user_info->comment . "\n" : q{};
        my $desc      = $order->desc ? $order->desc . "\n" : q{};
        $order->update(
            {
                wearon_date  => $user_info->wearon_date,
                purpose      => $user_info->purpose,
                purpose2     => $user_info->purpose2,
                pre_category => $user_info->pre_category,
                pre_color    => $user_info->pre_color,
                height       => $user_info->height,
                weight       => $user_info->weight,
                neck         => $user_info->neck,
                bust         => $user_info->bust,
                waist        => $user_info->waist,
                hip          => $user_info->hip,
                topbelly     => $user_info->topbelly,
                belly        => $user_info->belly,
                thigh        => $user_info->thigh,
                arm          => $user_info->arm,
                leg          => $user_info->leg,
                knee         => $user_info->knee,
                foot         => $user_info->foot,
                pants        => $user_info->pants,
                desc         => $comment . $desc,
            }
        );
    }

    my ( $history, $nonpayment );
    my $orders = $order->user->orders;
    while ( my $order = $orders->next ) {
        my $late_fee_pay_with     = $order->late_fee_pay_with     || '';
        my $compensation_pay_with = $order->compensation_pay_with || '';

        if ( $late_fee_pay_with =~ /미납/ || $compensation_pay_with =~ /미납/ ) {
            $history = '미납';
        }

        $nonpayment = $self->is_nonpayment( $order->id ) unless $nonpayment;
        last if $history && $nonpayment;
    }

    my $visited_order_rs = $orders->search(
        { status_id => $RETURNED, parent_id => undef },
        { order_by => { -desc => 'return_date' } },
    );

    my $visited    = $visited_order_rs->count;
    my $last_order = $visited_order_rs->first;

    #
    # response
    #
    $self->render(
        order      => $order,
        last_order => $last_order,
        history    => $history,
        nonpayment => $nonpayment,
        today      => $params{today},
        visited    => $visited,
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
    $self->app->log->info("order update: $name.$value");

    #
    # update column
    #
    if ( $name =~ s/^detail-// ) {
        my $detail = $order->order_details( { id => $pk } )->next;
        if ($detail) {
            unless ( $detail->$name eq $value ) {
                $self->app->log->info(
                    sprintf(
                        "  order_detail.$name %d [%s] -> [%s]",
                        $detail->id,
                        $detail->$name // 'N/A',
                        $value // 'N/A',
                    ),
                );
                $detail->update( { $name => $value } );
            }
        }
    }
    else {
        if ( $name eq 'status_id' ) {
            my $guard = $self->DB->txn_scope_guard;
            try {
                unless ( $order->status_id == $value ) {
                    #
                    # update order.status_id
                    #
                    $self->app->log->info(
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
                        my $msg  = $self->render_to_string(
                            "sms/order-confirmed", format => 'txt',
                            order => $order
                        );

                        my $sms =
                            $self->DB->resultset('SMS')
                            ->create( { to => $to, from => $from, text => $msg } );

                        $self->app->log->error("Failed to create a new SMS: $msg") unless $sms;
                    }

                    #
                    # 쿠폰의 상태를 변경
                    #
                    #   결제방식이 쿠폰(+현금|+카드)?
                    #
                    if ( my $coupon = $order->coupon ) {
                        if ( $order->price_pay_with =~ m/쿠폰/ ) {
                            $coupon->update( { status => 'used' } );
                        }
                    }
                }

                #
                # update clothes.status_id
                #
                for my $clothes ( $order->clothes ) {
                    unless ( $clothes->status_id == $value ) {
                        $self->app->log->info(
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
                        $self->app->log->info(
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
                $self->app->log->error("failed to update status of the order & clothes");
                $self->app->log->error($_);
            };
        }
        else {
            unless ( $order->$name eq $value ) {
                $self->app->log->info(
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
    return unless $order;

    my $error = $self->flash('error');
    $self->render( order => $order, error => $error );
}

=head2 create_order_extension

    POST /order/:order_id/extension

=cut

sub create_order_extension {
    my $self     = shift;
    my $order_id = $self->param('order_id');
    my $order    = $self->get_order( { id => $order_id } );
    return unless $order;

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

1;
