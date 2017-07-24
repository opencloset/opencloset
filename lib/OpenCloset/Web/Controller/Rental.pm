package OpenCloset::Web::Controller::Rental;
use Mojo::Base 'Mojolicious::Controller';

use DateTime;
use DateTime::Format::Strptime;
use Try::Tiny;
use OpenCloset::Constants::Status
    qw/$REPAIR $BOX $FITTING_ROOM1 $FITTING_ROOM20 $RESERVATED/;

has DB => sub { shift->app->DB };

=head1 METHODS

=head2 index

    GET /rental

=cut

sub index {
    my $self = shift;

    my $dt_today = DateTime->now( time_zone => $self->config->{timezone} );
    $self->redirect_to( $self->url_for( '/rental/' . $dt_today->ymd ) );
}

=head2 ymd

    GET /rental/:ymd

=cut

sub ymd {
    my $self = shift;

    #
    # fetch params
    #
    my %params = $self->get_params(qw/ ymd /);

    unless ( $params{ymd} ) {
        app->log->warn("ymd is required");
        $self->redirect_to( $self->url_for('/rental') );
        return;
    }

    unless ( $params{ymd} =~ m/^(\d{4})-(\d{2})-(\d{2})$/ ) {
        app->log->warn("invalid ymd format: $params{ymd}");
        $self->redirect_to( $self->url_for('/rental') );
        return;
    }

    my $dt_start = try {
        DateTime->new(
            time_zone => $self->config->{timezone}, year => $1, month => $2,
            day       => $3,
        );
    };
    unless ($dt_start) {
        app->log->warn("cannot create start datetime object");
        $self->redirect_to( $self->url_for('/rental') );
        return;
    }

    my $dt_end = $dt_start->clone->add( hours => 24, seconds => -1 );
    unless ($dt_end) {
        app->log->warn("cannot create end datetime object");
        $self->redirect_to( $self->url_for('/rental') );
        return;
    }

    my $dtf      = $self->DB->storage->datetime_parser;
    my $order_rs = $self->DB->resultset('Order')->search(
        {
            'booking.date' => {
                -between => [ $dtf->format_datetime($dt_start), $dtf->format_datetime($dt_end), ],
            },
            'status.name' => '포장',
        },
        { join => [qw/ booking status /], order_by => { -asc => 'update_date' }, },
    );

    my $repairs = $self->redis->hkeys('opencloset:storage:repair');

    #
    # 탈의/수선 상태의 사용자
    #
    my $rs = $self->DB->resultset('Order')->search(
        {
            -and => [
                status_id      => { -in => [ $REPAIR, $FITTING_ROOM1 .. $FITTING_ROOM20 ] },
                'booking.date' => {
                    -between => [ $dtf->format_datetime($dt_start), $dtf->format_datetime($dt_end), ],
                },
                online => 0,
            ]
        },
        { order_by => { -asc => 'update_date' }, join => 'booking', prefetch => 'booking' }
    );

    $self->stash(
        order_rs     => $order_rs,
        repairs      => $repairs,
        dt_start     => $dt_start,
        dt_end       => $dt_end,
        room_repairs => $rs,
    );
}

=head2 search

    GET /rental/:ymd/search?q=xxx

=cut

sub search {
    my $self = shift;
    my $ymd  = $self->param('ymd');

    my $v = $self->validation;
    $v->input( { ymd => $ymd } );
    $v->required('ymd')->like(qr/^\d{4}-\d{2}-\d{2}$/);

    if ( $v->has_error ) {
        my $failed = $v->failed;
        my $error = 'Parameter Validation Failed: ' . join( ', ', @$failed );
        return $self->error( 400, { str => $error } );
    }

    my $q = $self->param('q');
    return $self->error( 400, { str => 'Parameter "q" is required' } ) unless $q;
    return $self->error( 400, { str => 'Query is too short' } ) if length $q < 2;

    my @or;
    if ( $q =~ /^[0-9\-]+$/ ) {
        $q =~ s/-//g;
        push @or, { 'user_info.phone' => { like => "%$q%" } };
    }
    elsif ( $q =~ /^[a-zA-Z0-9_\-]+/ ) {
        if ( $q =~ /\@/ ) {
            push @or, { email => { like => "%$q%" } };
        }
        else {
            push @or, { email => { like => "%$q%" } };
            push @or, { name  => { like => "%$q%" } };
        }
    }
    elsif ( $q =~ m/^[ㄱ-힣]+$/ ) {
        push @or, { name => { like => "%$q%" } };
    }

    my ( $yyyy, $mm, $dd ) = $ymd =~ m/^(\d{4})-(\d{2})-(\d{2})$/;
    my $timezone = $self->config->{timezone};
    my $dt_start =
        DateTime->new( year => $yyyy, month => $mm, day => $dd, time_zone => $timezone );
    my $dt_end = $dt_start->clone->add( hours => 24, seconds => -1 );

    my $dtf = $self->DB->storage->datetime_parser;
    my $rs  = $self->DB->resultset('Order')->search(
        {
            -or  => [@or],
            -and => [
                status_id      => $RESERVATED,
                'booking.date' => {
                    -between => [
                        $dtf->format_datetime($dt_start),
                        $dtf->format_datetime($dt_end)
                    ],
                },
                online => 0,
            ]
        },
        {
            join => [ 'booking', { user => 'user_info' } ],
            rows => 5,
            order_by => { -asc => 'booking.date' },
        }
    );

    my @orders;
    while ( my $order = $rs->next ) {
        my $user        = $order->user;
        my $user_info   = $user->user_info;
        my $coupon      = $order->coupon;
        my $coupon_desc = $coupon ? $coupon->desc : '';
        my $event_seoul = $coupon_desc =~ m/^seoul/;

        #
        # GH 1142: 대여 화면에서 예약자의 이전 방문 기록 확인
        #
        my $visited = 0;
        my $ago     = 0;
        {
            my $visited_order_rs = $order->user->orders->search(
                {
                    status_id => $OpenCloset::Constants::Status::RETURNED,
                    parent_id => undef,
                },
                { order_by => { -desc => 'return_date' } },
            );

            $visited = $visited_order_rs->count;
            my $last_order = $visited_order_rs->first;
            if ($last_order) {
                my $booking            = $order->booking;
                my $last_order_booking = $last_order->booking;
                if ( $booking && $last_order_booking ) {
                    my $dur = $booking->date->delta_days( $last_order_booking->date );
                    $ago = $dur->delta_days;
                }
            }
        }

        push @orders, {
            ago          => $ago,
            booking      => substr( $order->booking->date, 11, 5 ),
            email        => $user->email,
            event_seoul  => $event_seoul,
            foot         => $user_info->foot,
            name         => $user->name,
            order_id     => $order->id,
            phone        => $user_info->phone,
            pre_category => $user_info->pre_category,
            user_id      => $user->id,
            visited      => $visited,
            return_memo  => $order->return_memo,
        };
    }

    $self->render( json => [@orders] );
}

=head2 order

    GET /rental/order/:order_id

=cut

sub order {
    my $self     = shift;
    my $order_id = $self->param('order_id');

    my $order = $self->DB->resultset('Order')->find( { id => $order_id } );
    return $self->error( 404, { str => "Not found order: $order_id" } ) unless $order;
    return $self->error( 400, { str => "Invalid order status" } )
        if $order->status_id != $BOX;

    my $repairs    = $self->redis->hkeys('opencloset:storage:repair');
    my $had_repair = "@$repairs" =~ m/\b$order_id\b/;

    my $user      = $order->user;
    my $user_info = $user->user_info;

    my %order     = $order->get_columns;
    my %user      = $user->get_columns;
    my %user_info = $user_info->get_columns;

    delete $user{password};

    $self->render(
        json => {
            order      => \%order,
            user       => \%user,
            user_info  => \%user_info,
            had_repair => $had_repair,
        }
    );
}

=head2 payment2rental

    POST /orders/:id/rental

=cut

sub payment2rental {
    my $self  = shift;
    my $id    = $self->param('id');
    my $reset = $self->param('reset');

    my $order = $self->DB->resultset('Order')->find( { id => $id } );
    return $self->error( 404, { str => "Order not found: $id" } ) unless $order;

    unless ( $order->staff_id ) {
        my $user      = $self->current_user;
        my $user_info = $user->user_info;
        $order->update( { staff_id => $user->id } ) if $user_info->staff;
    }

    my ( $success, $method, $redirect );
    my $api = $self->app->api;
    if ($reset) {
        $method   = 'payment2box';
        $redirect = $self->url_for('/rental');
        $success  = $api->payment2box($order);
    }
    else {
        $redirect = $self->url_for("/orders/$id");
        unless ( $order->price_pay_with ) {
            $self->flash( error => '결제방법을 선택해주세요.' );
            return $self->redirect_to($redirect);
        }

        $method  = 'payment2rental';
        $success = $api->payment2rental($order);
    }

    unless ($success) {
        my $err = "$method failed: order_id($id)";
        $self->log->error($err);
        $self->flash( error => $err );
    }
    else {
        $self->flash( success => '정상적으로 처리되었습니다.' );
    }

    $self->redirect_to($redirect);
}

=head2 rental2returned

    POST /orders/:id/returned

=cut

sub rental2returned {
    my $self = shift;
    my $id   = $self->param('id');

    my $order = $self->DB->resultset('Order')->find( { id => $id } );
    return $self->error( 404, { str => "Order not found: $id" } ) unless $order;

    my $v = $self->validation;
    $v->optional('return_date')->like(qr/^\d{4}-\d{2}-\d{2}$/);
    $v->optional('late_fee_discount');
    $v->optional('ignore_sms');
    $v->optional('codes');
    return $self->error( 400, { str => "Wrong return_date format: yyyy-mm-dd" } )
        if $v->has_error;

    my $return_date       = $v->param('return_date');
    my $late_fee_discount = $v->param('late_fee_discount');
    my $ignore_sms        = $v->param('ignore_sms');
    my $codes             = $v->every_param('codes');

    if ($return_date) {
        my $strp = DateTime::Format::Strptime->new(
            pattern   => '%F',
            time_zone => $self->config->{timezone},
        );

        $return_date = $strp->parse_datetime($return_date);
    }

    my $api = $self->app->api;
    $api->{sms} = 0 unless $ignore_sms;

    my $success;
    if (@$codes) {
        ## 부분반납
        $success = $api->rental2partial_returned(
            $order,
            $codes,
            return_date       => $return_date,
            late_fee_discount => $late_fee_discount
        );
    }
    else {
        ## 전체반납
        $success = $api->rental2returned(
            $order,
            return_date       => $return_date,
            late_fee_discount => $late_fee_discount
        );
    }

    $api->{sms} = 1;

    unless ($success) {
        my $err = "rental2returned failed: order_id($id)";
        $self->log->error($err);
        $self->flash( error => $err );
    }
    else {
        $self->flash( success => '정상적으로 처리되었습니다.' );
    }

    $self->redirect_to("/orders/$id");
}

=head2 rental2payback

    POST /orders/:id/payback

=cut

sub rental2payback {
    my $self   = shift;
    my $id     = $self->param('id');
    my $charge = $self->param('charge');

    my $order = $self->DB->resultset('Order')->find( { id => $id } );
    return $self->error( 404, { str => "Order not found: $id" } ) unless $order;

    my $success = $self->app->api->rental2payback( $order, $charge );
    unless ($success) {
        my $err = "rental2payback failed: order_id($id)";
        $self->log->error($err);
        $self->flash( error => $err );
    }
    else {
        $self->flash( success => '정상적으로 처리되었습니다.' );
    }

    $self->redirect_to("/orders/$id");
}

1;
