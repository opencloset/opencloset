package OpenCloset::Web::Controller::Rental;
use Mojo::Base 'Mojolicious::Controller';

use DateTime;
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
    my $self = shift;
    my $id   = $self->param('id');

    my $order = $self->DB->resultset('Order')->find( { id => $id } );
    return $self->error( 404, { str => "Order not found: $id" } ) unless $order;

    my $v = $self->validation;
    $v->optional('price_pay_with');
    $v->optional('additional_day');

    if ( $v->has_error ) {
        my $failed = $v->failed;
        my $error = 'Parameter Validation Failed: ' . join( ', ', @$failed );
        return $self->error( 400, { str => $error } );
    }

    my $price_pay_with = $v->param('price_pay_with');
    my $additional_day = $v->param('additional_day');

    my $success = $self->app->api->payment2rental(
        $order,
        price_pay_with => $price_pay_with,
        additional_day => $additional_day
    );

    unless ($success) {
        my $err = "payment2rental failed: order_id($id)";
        $self->log->error($err);
        $self->flash( error => $err );
    }
    else {
        $self->flash( success => '정상적으로 처리되었습니다.' );
    }

    $self->redirect_to("/orders/$id");
}

1;
