package OpenCloset::Web::Controller::Statistic;
use Mojo::Base 'Mojolicious::Controller';

use DateTime;
use Try::Tiny;

has DB    => sub { shift->app->DB };
has CACHE => sub { shift->app->CACHE };

=head1 METHODS

=head2 bestfit

    GET /stat/bestfit

=cut

sub bestfit {
    my $self = shift;

    my $rs = $self->DB->resultset('Order')->search(
        { bestfit => 1 },
        {
            order_by => [ { -asc => 'order_details.clothes_code' }, ],
            prefetch => { 'order_details' => { 'clothes' => { 'donation' => 'user', }, }, },
        },
    );

    $self->stash( order_rs => $rs, );
}

=head2 clothes_amount

    GET /stat/clothes/amount

=cut

sub clothes_amount {
    my $self = shift;

    my $rs = $self->DB->resultset('Clothes')
        ->search( undef, { columns => [qw/ category /], group_by => 'category' } );

    my @available_status_ids = (
        1, # 대여가능
        2, # 대여중
        5, # 세탁
        6, # 수선
        9, # 반납
    );

    my @amount;
    while ( my $clothes = $rs->next ) {
        my $category = $clothes->category;

        my $m_quantity =
            $self->DB->resultset('Clothes')
            ->search(
            { category => $category, gender => 'male', status_id => \@available_status_ids, }, );
        my $f_quantity = $self->DB->resultset('Clothes')->search(
            { category => $category, gender => 'female', status_id => \@available_status_ids, },
        );

        my $m_rental = $self->DB->resultset('Clothes')->search(
            {
                category  => $category,
                gender    => 'male',
                status_id => 2,        # 대여중
            }
        );
        my $f_rental = $self->DB->resultset('Clothes')->search(
            {
                category  => $category,
                gender    => 'female',
                status_id => 2,        # 대여중
            }
        );

        push(
            @amount,
            {
                category => $category,
                quantity => $m_quantity + $f_quantity,
                rental   => $m_rental + $f_rental,
                male     => { quantity => $m_quantity, rental => $m_rental, },
                female   => { quantity => $f_quantity, rental => $f_rental, },
            }
        );
    }

    $self->stash( amount => \@amount );
}

=head2 clothes_amount_category_gender

    GET /stat/clothes/amount/category/:category/gender/:gender

=cut

sub clothes_amount_category_gender {
    my $self = shift;

    my %criterion_of = (
        belt      => 'length',
        blouse    => 'bust',
        coat      => 'topbelly',
        jacket    => 'topbelly',
        onepiece  => 'topbelly',
        pants     => 'waist',
        shirt     => 'bust',
        shoes     => 'length',
        skirt     => 'hip',
        tie       => 'color',
        waistcoat => 'bust',
    );

    my @available_status_ids = (
        1, # 대여가능
        2, # 대여중
        5, # 세탁
        6, # 수선
        9, # 반납
    );

    my $category = $self->param('category');
    my $gender   = $self->param('gender');
    my $quantity = $self->DB->resultset('Clothes')
        ->search( { category => $category, gender => $gender, } );
    my $available_quantity =
        $self->DB->resultset('Clothes')
        ->search(
        { category => $category, gender => $gender, status_id => \@available_status_ids, } );

    my @items;
    my $criterion = $criterion_of{$category};
    if ($criterion) {
        my $rs = $self->DB->resultset('Clothes')
            ->search( undef, { columns => [$criterion], group_by => $criterion }, );

        while ( my $clothes = $rs->next ) {
            my $size = $clothes->$criterion;

            my $qty = $self->DB->resultset('Clothes')
                ->search( { category => $category, gender => $gender, $criterion => $size } );
            my $available_qty = $self->DB->resultset('Clothes')->search(
                {
                    category  => $category, gender => $gender, $criterion => $size,
                    status_id => \@available_status_ids
                }
            );
            my $rental =
                $self->DB->resultset('Clothes')
                ->search(
                { category => $category, gender => $gender, $criterion => $size, status_id => 2 } );
            my $repair =
                $self->DB->resultset('Clothes')
                ->search(
                { category => $category, gender => $gender, $criterion => $size, status_id => 6 } );
            my $cleaning =
                $self->DB->resultset('Clothes')
                ->search(
                { category => $category, gender => $gender, $criterion => $size, status_id => 5 } );
            my $lost =
                $self->DB->resultset('Clothes')
                ->search(
                { category => $category, gender => $gender, $criterion => $size, status_id => 7 } );
            my $disused =
                $self->DB->resultset('Clothes')
                ->search(
                { category => $category, gender => $gender, $criterion => $size, status_id => 8 } );

            push(
                @items,
                {
                    size          => $size,
                    qty           => $qty,
                    available_qty => $available_qty,
                    rental        => $rental,
                    repair        => $repair,
                    cleaning      => $cleaning,
                    lost          => $lost,
                    disused       => $disused,
                },
            );
        }
    }
    else {
        my $qty = $self->DB->resultset('Clothes')
            ->search( { category => $category, gender => $gender } );
        my $available_qty =
            $self->DB->resultset('Clothes')
            ->search(
            { category => $category, gender => $gender, status_id => \@available_status_ids } );
        my $rental = $self->DB->resultset('Clothes')
            ->search( { category => $category, gender => $gender, status_id => 2 } );
        my $repair = $self->DB->resultset('Clothes')
            ->search( { category => $category, gender => $gender, status_id => 6 } );
        my $cleaning = $self->DB->resultset('Clothes')
            ->search( { category => $category, gender => $gender, status_id => 5 } );
        my $lost = $self->DB->resultset('Clothes')
            ->search( { category => $category, gender => $gender, status_id => 7 } );
        my $disused = $self->DB->resultset('Clothes')
            ->search( { category => $category, gender => $gender, status_id => 8 } );

        push(
            @items,
            {
                qty           => $qty,
                available_qty => $available_qty,
                rental        => $rental,
                repair        => $repair,
                cleaning      => $cleaning,
                lost          => $lost,
                disused       => $disused,
            },
        );
    }

    $self->stash(
        items              => \@items,
        quantity           => $quantity,
        available_quantity => $available_quantity,
        criterion          => $criterion,
        gender             => $gender,
    );
}

=head2 clothes_hit

    GET /stat/clothes/hit

=cut

sub clothes_hit {
    my $self = shift;

    my $default_category = 'jacket';
    my $default_gender   = 'male';
    my $default_limit    = 10;

    my $dt_today = DateTime->now( time_zone => $self->config->{timezone} );
    my $dt_month_before = $dt_today->clone->subtract( months => 1 );
    unless ($dt_month_before) {
        $self->app->log->warn("cannot create end datetime object");
        $self->redirect_to( $self->url_for('/') );
        return;
    }

    $self->redirect_to(
        $self->url_for( '/stat/clothes/hit/' . $default_category )->query(
            start_date => $dt_month_before->ymd,
            end_date   => $dt_today->ymd,
            gender     => $default_gender,
            limit      => $default_limit,
        )
    );
}

=head2 clothes_hit_category

    GET /stat/clothes/hit/:category

=cut

sub clothes_hit_category {
    my $self = shift;

    #
    # fetch params
    #
    my %params = $self->get_params(qw/ start_date end_date category gender limit /);

    #
    # validate params
    #

    my $v = $self->create_validator;
    $v->field('category')->in( keys %{ $self->config->{category} } );
    $v->field('gender')->in(qw/ male female /);
    $v->field('limit')->regexp(qr/^\d+$/);

    unless ( $self->validate( $v, \%params ) ) {
        my @error_str;
        while ( my ( $k, $v ) = each %{ $v->errors } ) {
            push @error_str, "$k:$v";
        }
        return $self->error( 400, { str => join( ',', @error_str ), data => $v->errors, } );
    }

    unless ( $params{start_date} ) {
        $self->app->log->warn("start_date is required");
        $self->redirect_to( $self->url_for('/stat/clothes/hit') );
        return;
    }

    unless ( $params{start_date} =~ m/^(\d{4})-(\d{2})-(\d{2})$/ ) {
        $self->app->log->warn("invalid ymd format: $params{start_date}");
        $self->redirect_to( $self->url_for('/start_date') );
        return;
    }

    my $start_date = try {
        DateTime->new(
            time_zone => $self->config->{timezone}, year => $1, month => $2,
            day       => $3,
        );
    };

    unless ($start_date) {
        $self->app->log->warn("cannot create start datetime object");
        $self->redirect_to( $self->url_for('/stat/clothes/hit') );
        return;
    }

    unless ( $params{end_date} ) {
        $self->app->log->warn("end_date is required");
        $self->redirect_to( $self->url_for('/stat/clothes/hit') );
        return;
    }

    unless ( $params{end_date} =~ m/^(\d{4})-(\d{2})-(\d{2})$/ ) {
        $self->app->log->warn("invalid ymd format: $params{end_date}");
        $self->redirect_to( $self->url_for('/stat/clothes/hit') );
        return;
    }

    my $end_date = try {
        DateTime->new(
            time_zone => $self->config->{timezone}, year => $1, month => $2,
            day       => $3,
        );
    };
    unless ($end_date) {
        $self->app->log->warn("cannot create end datetime object");
        $self->redirect_to( $self->url_for('/stat/clothes/hit') );
        return;
    }

    #
    # fetch clothes
    #

    my $dtf        = $self->DB->storage->datetime_parser;
    my $clothes_rs = $self->DB->resultset('Clothes')->search(
        {
            'category'          => $params{category},
            'gender'            => $params{gender},
            'order.rental_date' => {
                -between =>
                    [ $dtf->format_datetime($start_date), $dtf->format_datetime($end_date), ],
            },
        },
        {
            join     => [ { order_details => 'order' }, { donation => 'user' }, ],
            prefetch => [ { donation      => 'user' } ],
            columns  => [
                qw/
                    arm
                    belly
                    bust
                    category
                    code
                    color
                    hip
                    length
                    neck
                    thigh
                    topbelly
                    waist
                    /
            ],
            '+columns' => [ { count => { count => 'me.id', -as => 'rent_count' } } ],
            group_by => [qw/ category code /],
            order_by => { -desc => 'rent_count' },
            rows     => $params{limit},
        }
    );

    $self->render(
        clothes_rs => $clothes_rs,
        start_date => $start_date,
        end_date   => $end_date,
        category   => $params{category},
        gender     => $params{gender},
        limit      => $params{limit},
    );
}

=head2 status

    GET /stat/status

=cut

sub status {
    my $self = shift;

    my $dt_today = DateTime->now( time_zone => $self->config->{timezone} );
    $self->redirect_to( $self->url_for( '/stat/status/' . $dt_today->ymd ) );
}

=head2 status_ymd

    GET /stat/status/:ymd

=cut

sub status_ymd {
    my $self = shift;

    #
    # fetch params
    #
    my %params = $self->get_params(qw/ ymd /);

    unless ( $params{ymd} ) {
        $self->app->log->warn("ymd is required");
        $self->redirect_to( $self->url_for('/stat/visitor') );
        return;
    }

    unless ( $params{ymd} =~ m/^(\d{4})-(\d{2})-(\d{2})$/ ) {
        $self->app->log->warn("invalid ymd format: $params{ymd}");
        $self->redirect_to( $self->url_for('/stat/visitor') );
        return;
    }

    my $dt = try {
        DateTime->new(
            time_zone => $self->config->{timezone}, year => $1, month => $2,
            day       => $3,
        );
    };
    unless ($dt) {
        $self->app->log->warn("cannot create datetime object");
        $self->redirect_to( $self->url_for('/stat/status') );
        return;
    }

    my $dt_start =
        try { $dt->clone->truncate( to => 'day' )->add( hours => 24 * 2 * -1 ); };
    unless ($dt_start) {
        $self->app->log->warn("cannot create start datetime object");
        $self->redirect_to( $self->url_for('/stat/status') );
        return;
    }

    my $dt_end = try {
        $dt->clone->truncate( to => 'day' )->add( hours => 24 * 3, seconds => -1 );
    };
    unless ($dt_end) {
        $self->app->log->warn("cannot create end datetime object");
        $self->redirect_to( $self->url_for('/stat/status') );
        return;
    }

    my $basis_dt = try {
        DateTime->new(
            time_zone => $self->config->{timezone}, year => 2015, month => 5,
            day       => 29
        );
    };
    my $online_order_hour = $dt >= $basis_dt ? 22 : 19;

    my $dtf      = $self->DB->storage->datetime_parser;
    my $order_rs = $self->DB->resultset('Order')->search(
        #
        # do not query all data for specific month due to speed
        #
        #\[ 'DATE_FORMAT(`booking`.`date`,"%Y-%m") = ?', $dt->strftime("%Y-%m") ],
        {
            -and => [
                'booking.date' => {
                    -between => [ $dtf->format_datetime($dt_start), $dtf->format_datetime($dt_end), ],
                },
                \[ 'HOUR(`booking`.`date`) != ?', $online_order_hour ],
            ]
        },
        { join => [qw/ booking /], order_by => { -asc => 'date' }, prefetch => 'booking', },
    );

    $self->render( order_rs => $order_rs, dt => $dt, );
}

=head2 visitor

    GET /stat/visitor

=cut

sub visitor {
    my $self = shift;

    my $dt_today = DateTime->now( time_zone => $self->config->{timezone} );
    $self->redirect_to( $self->url_for( '/stat/visitor/' . $dt_today->ymd ) );
}

=head2 visitor_ymd

    GET /stat/visitor/:ymd

=cut

sub visitor_ymd {
    my $self = shift;

    #
    # fetch params
    #
    my %params = $self->get_params(qw/ ymd /);

    unless ( $params{ymd} ) {
        $self->app->log->warn("ymd is required");
        $self->redirect_to( $self->url_for('/stat/visitor') );
        return;
    }

    unless ( $params{ymd} =~ m/^(\d{4})-(\d{2})-(\d{2})$/ ) {
        $self->app->log->warn("invalid ymd format: $params{ymd}");
        $self->redirect_to( $self->url_for('/stat/visitor') );
        return;
    }

    my $dt = try {
        DateTime->new(
            time_zone => $self->config->{timezone}, year => $1, month => $2,
            day       => $3,
        );
    };
    unless ($dt) {
        $self->app->log->warn("cannot create datetime object");
        $self->redirect_to( $self->url_for('/stat/visitor') );
        return;
    }

    my $today = try {
        DateTime->now( time_zone => $self->config->{timezone}, );
    };
    unless ($today) {
        $self->app->log->warn("cannot create datetime object: today");
        $self->redirect_to( $self->url_for('/stat/visitor') );
        return;
    }
    $today->truncate( to => 'day' );

    # -$day_range ~ +$day_range days from now
    my $day_range = 2;
    my %count;
    my $today_data;
    my $from = $dt->clone->truncate( to => 'day' )->add( days => -$day_range );
    my $to   = $dt->clone->truncate( to => 'day' )->add( days => $day_range );
    for ( ; $from <= $to; $from->add( days => 1 ) ) {
        my $f = $from->clone->truncate( to => 'day' );
        my $t = $from->clone->truncate( to => 'day' )->add( days => 1, seconds => -1 );

        my $f_str = $f->strftime('%Y%m%d%H%M%S');
        my $t_str = $t->strftime('%Y%m%d%H%M%S');
        my $name  = "day-$f_str-$t_str";

        my $data;
        if ( $f < $today && $t < $today ) {
            $data = $self->CACHE->get($name);
        }
        elsif ( $f->clone->truncate( to => 'day' ) == $today ) {
            $self->app->log->info("do not cache and by-pass cache: $name");
            $data = $self->count_visitor( $f, $t );
            $today_data = $data;
        }
        $data->{label} = $f->ymd;

        push @{ $count{day} }, $data;
    }

    # from first to current week of this year
    my $current_week_start_dt;
    my $current_week_end_dt;
    for (
        my $i = $dt->clone->subtract( years => 1 );
        $i <= $dt;
        $i->add( weeks => 1 )
        )
    {
        my $f = $i->clone->truncate( to => 'week' );
        my $t = $i->clone->truncate( to => 'week' )->add( weeks => 1, seconds => -1 );

        my $f_str = $f->strftime('%Y%m%d%H%M%S');
        my $t_str = $t->strftime('%Y%m%d%H%M%S');
        my $name  = "week-$f_str-$t_str";

        $current_week_start_dt = $f->clone;
        $current_week_end_dt   = $t->clone;

        my $data;
        if ( $f < $today && $t < $today ) {
            $data = $self->CACHE->get($name);
            $data->{label} = sprintf(
                "%04d %02d : %s ~ %s",
                ( $f->week ), # week_year, week_number
                $f->strftime('%m/%d'),
                $t->strftime('%m/%d'),
            );
        }

        push @{ $count{week} }, $data;
    }

    # from january to current months of this year
    my $current_month_start_dt;
    my $current_month_end_dt;
    for (
        my $i = $dt->clone->subtract( years => 1 );
        $i <= $dt;
        $i->add( months => 1 )
        )
    {
        my $f = $i->clone->truncate( to => 'month' );
        my $t = $i->clone->truncate( to => 'month' )->add( months => 1, seconds => -1 );

        my $f_str = $f->strftime('%Y%m%d%H%M%S');
        my $t_str = $t->strftime('%Y%m%d%H%M%S');
        my $name  = "month-$f_str-$t_str";

        $current_month_start_dt = $f->clone;
        $current_month_end_dt   = $t->clone;

        my $data;
        if ( $f < $today && $t < $today ) {
            $data = $self->CACHE->get($name);
            $data->{label} = $f->strftime('%Y-%m');
        }

        push @{ $count{month} }, $data;
    }

    my $no_cache_week;
    my $no_cache_month;
    ++$no_cache_week  if $today->clone->truncate( to => 'week' ) <= $dt;
    ++$no_cache_month if $today->clone->truncate( to => 'month' ) <= $dt;

    # current data with and without cache
    my %current_week = (
        label      => sprintf(
            "%04d %02d : %s ~ %s",
            ( $dt->week ), # week_year, week_number
            $dt->clone->truncate( to => 'week' )->strftime('%m/%d'),
            $dt->clone->truncate( to => 'week' )->add( weeks => 1, seconds => -1 )->strftime('%m/%d'),
        ),
        all        => { total => 0, male => 0, female => 0 },
        visited    => { total => 0, male => 0, female => 0 },
        notvisited => { total => 0, male => 0, female => 0 },
        bestfit    => { total => 0, male => 0, female => 0 },
        loanee     => { total => 0, male => 0, female => 0 },
    );
    my %current_month = (
        label      => $dt->strftime('%Y-%m'),
        all        => { total => 0, male => 0, female => 0 },
        visited    => { total => 0, male => 0, female => 0 },
        notvisited => { total => 0, male => 0, female => 0 },
        bestfit    => { total => 0, male => 0, female => 0 },
        loanee     => { total => 0, male => 0, female => 0 },
    );
    for (
        my $i = $today->clone->add( months => -1 )->truncate( to => 'month' );
        $i <= $today;
        $i->add( days => 1 )
        )
    {
        my $f = $i->clone->truncate( to => 'day' );
        my $t = $i->clone->truncate( to => 'day' )->add( days => 1, seconds => -1 );

        my $f_str = $f->strftime('%Y%m%d%H%M%S');
        my $t_str = $t->strftime('%Y%m%d%H%M%S');
        my $name  = "day-$f_str-$t_str";

        my $data;
        if ( $f < $today && $t < $today ) {
            $data = $self->CACHE->get($name);
        }
        elsif ( $f->clone->truncate( to => 'day' ) == $today ) {
            $self->app->log->info("do not cache and by-pass cache: $name");
            $data = $today_data;
        }

        if ( $current_week_start_dt <= $i && $i <= $current_week_end_dt ) {
            $self->app->log->info("calculationg for this week: $name");
            $current_week{all}{total}         += $data->{all}{total};
            $current_week{all}{male}          += $data->{all}{male};
            $current_week{all}{female}        += $data->{all}{female};
            $current_week{visited}{total}     += $data->{visited}{total};
            $current_week{visited}{male}      += $data->{visited}{male};
            $current_week{visited}{female}    += $data->{visited}{female};
            $current_week{notvisited}{total}  += $data->{notvisited}{total};
            $current_week{notvisited}{male}   += $data->{notvisited}{male};
            $current_week{notvisited}{female} += $data->{notvisited}{female};
            $current_week{bestfit}{total}     += $data->{bestfit}{total};
            $current_week{bestfit}{male}      += $data->{bestfit}{male};
            $current_week{bestfit}{female}    += $data->{bestfit}{female};
            $current_week{loanee}{total}      += $data->{loanee}{total};
            $current_week{loanee}{male}       += $data->{loanee}{male};
            $current_week{loanee}{female}     += $data->{loanee}{female};
        }
        if ( $current_month_start_dt <= $i && $i <= $current_month_end_dt ) {
            $self->app->log->info("calculationg for this month $name");
            $current_month{all}{total}         += $data->{all}{total};
            $current_month{all}{male}          += $data->{all}{male};
            $current_month{all}{female}        += $data->{all}{female};
            $current_month{visited}{total}     += $data->{visited}{total};
            $current_month{visited}{male}      += $data->{visited}{male};
            $current_month{visited}{female}    += $data->{visited}{female};
            $current_month{notvisited}{total}  += $data->{notvisited}{total};
            $current_month{notvisited}{male}   += $data->{notvisited}{male};
            $current_month{notvisited}{female} += $data->{notvisited}{female};
            $current_month{bestfit}{total}     += $data->{bestfit}{total};
            $current_month{bestfit}{male}      += $data->{bestfit}{male};
            $current_month{bestfit}{female}    += $data->{bestfit}{female};
            $current_month{loanee}{total}      += $data->{loanee}{total};
            $current_month{loanee}{male}       += $data->{loanee}{male};
            $current_month{loanee}{female}     += $data->{loanee}{female};
        }
    }
    $count{week}[-1]  = \%current_week  if $no_cache_week;
    $count{month}[-1] = \%current_month if $no_cache_month;

    $self->render( count => \%count, dt => $dt, );
}

=head2 events_seoul

    GET /stat/events/seoul

=cut

our $DEFAULT_BETWEEN_DAYS = 10;

sub events_seoul {
    my $self = shift;
    my $ymd  = $self->param('ymd');

    my $to;
    if ($ymd) {
        my ( $year, $month, $day ) = split /-/, $ymd;
        $to = DateTime->new( year => $year, month => $month, day => $day );
    }
    else {
        $to = DateTime->now;
    }

    my $timezone = $self->config->{timezone} or die "Config timezone is not set";
    $to->set_time_zone($timezone);
    my $from = $to->clone->subtract( days => $DEFAULT_BETWEEN_DAYS );

    my %counts;
    my %dates;
    my $storage = $self->DB->storage;
    # visited
    my $visited = $storage->dbh_do(
        sub {
            my ( $storage, $dbh, @args ) = @_;
            $dbh->selectall_arrayref(
                qq{SELECT DATE_FORMAT(b.date, '%Y-%m-%d') AS ymd, count(*) AS visited
FROM `order` o JOIN booking b ON o.booking_id = b.id
WHERE o.status_id NOT IN (12, 14) AND b.date BETWEEN '$from->ymd' AND '$to->ymd' GROUP BY DATE_FORMAT(b.date, '%Y-%m-%d')}
            );
        }
    );

    for my $row (@$visited) {
        my ( $ymd, $c ) = @$row;
        $dates{$ymd}++;
        $counts{visited}{$ymd}  = $c;
        $counts{reserved}{$ymd} = $c;
    }

    # not visited
    my $not_visited = $storage->dbh_do(
        sub {
            my ( $storage, $dbh, @args ) = @_;
            $dbh->selectall_arrayref(
                qq{SELECT DATE_FORMAT(b.date, '%Y-%m-%d') AS ymd, count(*) AS visited
FROM `order` o JOIN booking b ON o.booking_id = b.id
WHERE o.status_id IN (12, 14) AND b.date BETWEEN '$from->ymd' AND '$to->ymd' GROUP BY DATE_FORMAT(b.date, '%Y-%m-%d')}
            );
        }
    );

    for my $row (@$not_visited) {
        my ( $ymd, $c ) = @$row;
        $dates{$ymd}++;
        $counts{not_visited}{$ymd} = $c;
        $counts{reserved}{$ymd} += $c;
    }

    # events
    my $events = $self->DB->storage->dbh_do(
        sub {
            my ( $storage, $dbh, @args ) = @_;
            $dbh->selectall_arrayref(
                qq{SELECT DATE_FORMAT(b.date, '%Y-%m-%d'), status, COUNT(status)
FROM `order` o JOIN booking b ON o.booking_id = b.id JOIN coupon c ON o.coupon_id = c.id
WHERE coupon_id IS NOT NULL AND b.date BETWEEN '$from->ymd' AND '$to->ymd' GROUP BY DATE_FORMAT(b.date, '%Y-%m-%d'), status}
            );
        },
    );

    for my $row (@$events) {
        my ( $ymd, $status, $c ) = @$row;

        $dates{$ymd}++;
        $counts{events}{visited}{$ymd}     = $c if $status eq 'used';
        $counts{events}{not_visited}{$ymd} = $c if $status eq 'provided';
        $counts{events}{reserved}{$ymd} += $c;
    }

    $self->render( from => $from, $to => $to, counts => \%counts, dates => \%dates );
}

1;
