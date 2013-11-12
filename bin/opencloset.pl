#!/usr/bin/env perl

use Mojolicious::Lite;

use Data::Pageset;
use DateTime;
use SMS::Send::KR::CoolSMS;
use SMS::Send;
use Try::Tiny;

use Opencloset::Constant;
use Opencloset::Schema;

plugin 'validator';
plugin 'haml_renderer';
plugin 'FillInFormLite';

app->defaults( %{ plugin 'Config' => { default => {
    jses        => [],
    csses       => [],
    breadcrumbs => [],
    active_id   => q{},
}}});

my $DB = Opencloset::Schema->connect({
    dsn      => app->config->{database}{dsn},
    user     => app->config->{database}{user},
    password => app->config->{database}{pass},
    %{ app->config->{database}{opts} },
});

helper error => sub {
    my ($self, $status, $error) = @_;

    ## TODO: `ok.haml.html`, `bad_request.haml.html`, `internal_error.haml.html`
    my %error_map = (
        200 => 'ok',
        400 => 'bad_request',
        404 => 'not_found',
        500 => 'internal_error',
    );

    $self->respond_to(
        json => { json => { error => $error || '' }, status => $status },
        html => {
            template => $error_map{$status},
            error    => $error || '',
            status   => $status
        }
    );
};

helper cloth2hr => sub {
    my ($self, $cloth) = @_;

    return {
        $cloth->get_columns,
        donor    => $cloth->donor ? $cloth->donor->user->name : '',
        category => $cloth->category->name,
        price    => $self->commify($cloth->category->price),
        status   => $cloth->status->name,
    };
};

helper order2hr => sub {
    my ($self, $order) = @_;

    my @clothes;
    for my $cloth ($order->cloths) {
        push @clothes, $self->cloth2hr($cloth);
    }

    return {
        $order->get_columns,
        clothes => [@clothes],
    };
};

helper sms2hr => sub {
    my ($self, $sms) = @_;

    return { $sms->get_columns };
};

helper guest2hr => sub {
    my ($self, $user) = @_;

    my %columns;
    if ($user->guest) {
        %columns = ($user->get_columns, $user->guest->get_columns);
    } else {
        %columns = $user->get_columns;
        map { $columns{$_} = undef } $DB->resultset('Guest')->result_source->columns;
        $columns{user_id} = $user->id;
    }

    return { %columns };
};

helper overdue_calc => sub {
    my ($self, $target_dt, $return_dt) = @_;

    my $DAY_AS_SECONDS = 60 * 60 * 24;

    my $epoch1 = $target_dt->epoch;
    my $epoch2 = $return_dt->epoch;

    my $dur = $epoch2 - $epoch1;
    return 0 if $dur < 0;
    return int($dur / $DAY_AS_SECONDS);
};

helper commify => sub {
    my $self = shift;
    local $_ = shift;
    1 while s/((?:\A|[^.0-9])[-+]?\d+)(\d{3})/$1,$2/s;
    return $_;
};

helper validate_user => sub {
    my $self = shift;

    my $validator = $self->create_validator;
    $validator->field('name')->required(1);
    $validator->field('phone')->regexp(qr/^01\d{8,9}$/);
    $validator->field('email')->email;
    $validator->field('gender')->regexp(qr/^[12]$/);
    $validator->field('age')->regexp(qr/^\d+$/);

    return unless $self->validate($validator);
    ## TODO: check exist email and set to error
    return 1;
};

helper create_user => sub {
    my $self = shift;

    my %params;
    map {
        $params{$_} = $self->param($_) if defined $self->param($_)
    } qw/name email password phone gender age address/;

    return $DB->resultset('User')->find_or_create(\%params);
};

helper validate_guest => sub {
    my $self = shift;

    my $validator = $self->create_validator;
    $validator->field([qw/chest waist arm length height weight/])
        ->each(sub { shift->required(1)->regexp(qr/^\d+$/) });

    ## TODO: validate `target_date`
    return unless $self->validate($validator);
    return 1;
};

helper create_guest => sub {
    my ($self, $user_id) = @_;

    return unless $user_id;

    my %params = ( user_id => $user_id );
    map {
        $params{$_} = $self->param($_) if defined $self->param($_)
    } qw/chest waist arm length height weight purpose domain target_date/;

    return $DB->resultset('Guest')->find_or_create(\%params);
};

helper create_donor => sub {
    my ($self, $user_id) = @_;

    my %params = ( id => $user_id );
    map { $params{$_} = $self->param($_) } qw/donation_msg comment/;

    return $DB->resultset('Donor')->find_or_create(\%params);
};

helper create_cloth => sub {
    my ($self, $category_id) = @_;

    ## generate no
    my $category = $DB->resultset('Category')->find({ id => $category_id });
    return unless $category;

    my $cloth = $DB->resultset('Cloth')->search({
        category_id => $category_id
    }, {
        order_by => { -desc => 'no' }
    })->next;

    my $index = 1;
    if ($cloth) {
        $index = substr $cloth->no, -5, 5;
        $index =~ s/^0+//;
        $index++;
    }

    my $no = sprintf "%s%05d", $category->abbr, $index;

    my %params;
    if ($category->which eq 'top') {
        map { $params{$_} = $self->param($_) } qw/chest arm/;
    } elsif ($category->which eq 'bottom') {
        map { $params{$_} = $self->param($_) } qw/waist length/;
    } elsif ($category->which eq 'onepiece') {
        map { $params{$_} = $self->param($_) } qw/chest waist length/;
    } elsif ($category->which eq 'foot') {
        map { $params{$_} = $self->param($_) } qw/foot/;
    }

    $params{no}              = $no;
    $params{donor_id}        = $self->param('donor_id');
    $params{category_id}     = $category_id;
    $params{status_id}       = $Opencloset::Constant::STATUS_AVAILABLE;
    $params{designated_for}  = $self->param('designated_for');
    $params{color}           = $self->param('color');
    $params{compatible_code} = $self->param('compatible_code');

    my $new_cloth = $DB->resultset('Cloth')->find_or_create(\%params);
    return unless $new_cloth;
    return $new_cloth unless $new_cloth->compatible_code;

    my $compatible_code = $new_cloth->compatible_code;
    $compatible_code =~ s/[A-Z]/_/g;
    my $top_or_bottom = $DB->resultset('Cloth')->search({
        category_id     => { '!=' => $new_cloth->category_id },
        compatible_code => { like => $compatible_code },
    })->next;

    if ($top_or_bottom && $top_or_bottom->category->which) {
        my $which = $top_or_bottom->category->which;
        if ($which eq 'top') {
            $new_cloth->top_id($top_or_bottom->id);
            $top_or_bottom->bottom_id($new_cloth->id);
            $new_cloth->update;
            $top_or_bottom->update;
        }
        elsif ($which eq 'bottom') {
            $new_cloth->bottom_id($top_or_bottom->id);
            $top_or_bottom->top_id($new_cloth->id);
            $new_cloth->update;
            $top_or_bottom->update;
        }
    }

    return $new_cloth;
};

helper _q => sub {
    my ($self, %params) = @_;

    my $q = $self->param('q') || q{};
    my ($chest, $waist, $arm, $status_id, $category_id) = split /\//, $q;
    my %q = (
        chest    => $chest       || '',
        waist    => $waist       || '',
        arm      => $arm         || '',
        status   => $status_id   || '',
        category => $category_id || '',
        %params,
    );

    return join('/', ($q{chest}, $q{waist}, $q{arm}, $q{status}, $q{category}));
};

get '/'      => 'home';
get '/login';

get '/new-borrower' => sub {
    my $self = shift;

    my $q      = $self->param('q') || '';
    my $users = $DB->resultset('User')->search({
        -or => [
            id    => $q,
            name  => $q,
            phone => $q,
            email => $q
        ],
    });

    my @candidates;
    while (my $user = $users->next) {
        push @candidates, $self->guest2hr($user);
    }

    $self->respond_to(
        json => { json => [@candidates] },
        html => { template => 'new-borrower' }
    );
};

post '/users' => sub {
    my $self = shift;

    return $self->error(400, 'invalid request') unless $self->validate_user;

    my $user = $self->create_user;
    return $self->error(500, 'failed to create a new user') unless $user;

    $self->res->headers->header('Location' => $self->url_for('/users/' . $user->id));
    $self->respond_to(
        json => { json => { $user->get_columns }, status => 201 },
        html => sub {
            $self->redirect_to('/users/' . $user->id);
        }
    );
};

any [qw/put patch/] => '/users/:id' => sub {
    my $self  = shift;

    return $self->error(400, 'invalid request') unless $self->validate_user;

    my $rs   = $DB->resultset('User');
    my $user = $rs->find({ id => $self->param('id') });
    map { $user->$_($self->param($_)) } qw/name phone gender age address/;
    $user->update;
    $self->respond_to(
        json => { json => { $user->get_columns } },
    );
};

post '/guests' => sub {
    my $self = shift;

    return $self->error(400, 'invalid request')
        unless ($self->validate_guest && $self->param('user_id'));

    my $user = $DB->resultset('User')->find({ id => $self->param('user_id') });
    return $self->error(404, 'not found user') unless $user;

    my $guest = $self->create_guest($user->id);
    return $self->error(500, 'failed to create a new guest') unless $guest;

    $self->res->headers->header('Location' => $self->url_for('/guests/' . $guest->id));
    $self->respond_to(
        json => { json => { $guest->get_columns }, status => 201 },
        html => sub {
            $self->redirect_to('/guests/' . $guest->id);
        }
    );
};

get '/guests/:id' => sub {
    my $self   = shift;
    my $guest  = $DB->resultset('Guest')->find({ id => $self->param('id') });
    return $self->error(404, 'not found guest') unless $guest;

    my @orders = $DB->resultset('Order')->search({
        guest_id => $self->param('id')
    }, {
        order_by => { -desc => 'rental_date' }
    });
    $self->stash(
        guest  => $guest,
        orders => [@orders],
    );

    $self->respond_to(
        json => { json => { $guest->get_columns } },
        html => { template => 'guests/id' }
    );
};

any [qw/put patch/] => '/guests/:id' => sub {
    my $self  = shift;

    return $self->error(400, 'invalid request') unless $self->validate_guest;

    my $rs = $DB->resultset('Guest');
    my $guest = $rs->find({ id => $self->param('id') });
    return $self->error(404, 'not found') unless $guest;

    map {
        $guest->$_($self->param($_)) if defined $self->param($_);
    } qw/chest waist arm length height weight purpose domain/;
    $guest->update;
    $self->respond_to(
        json => { json => { $guest->get_columns } },
    );
};

post '/clothes' => sub {
    my $self = shift;
    my $validator = $self->create_validator;
    $validator->field('category_id')->required(1);
    $validator->field('designated_for')->required(1)->regexp(qr/^[123]$/);

    # Jacket
    $validator->when('category_id')->regexp(qr/^(-1|-2|1)$/)
        ->then(sub { shift->field('chest')->required(1) });
    $validator->when('category_id')->regexp(qr/^(-1|-2|1)$/)
        ->then(sub { shift->field('arm')->required(1) });

    # Pants, Skirts
    $validator->when('category_id')->regexp(qr/^(-1|-2|2|10)$/)
        ->then(sub { shift->field('waist')->required(1) });
    $validator->when('category_id')->regexp(qr/^(-1|-2|2|10)$/)
        ->then(sub { shift->field('length')->required(1) });

    # Shoes
    $validator->when('category_id')->regexp(qr/^4$/)
        ->then(sub { shift->field('foot')->required(1) });

    ## 나머지는 강제하지 않는다

    my @fields = qw/chest waist arm length foot/;
    $validator->field([@fields])
        ->each(sub { shift->regexp(qr/^\d+$/) });

    unless ($self->validate($validator)) {
        my @error_str;
        while ( my ($k, $v) = each %{ $validator->errors } ) {
            push @error_str, "$k:$v";
        }
        return $self->error( 400, { str => join(',', @error_str), data => $validator->errors } );
    }

    my $cid      = $self->param('category_id');
    my $donor_id = $self->param('donor_id');

    my $cloth;
    my $guard = $DB->txn_scope_guard;
    # BEGIN TRANSACTION ~
    if ($cid == $Opencloset::Constant::CATEOGORY_JACKET_PANTS ||
            $cid == $Opencloset::Constant::CATEOGORY_JACKET_SKIRT) {
        my $top = $self->create_cloth($Opencloset::Constant::CATEOGORY_JACKET);
        my $bot_category_id = $cid == $Opencloset::Constant::CATEOGORY_JACKET_PANTS ?
            $Opencloset::Constant::CATEOGORY_PANTS : $Opencloset::Constant::CATEOGORY_SKIRT;
        my $bot = $self->create_cloth($bot_category_id);
        return $self->error(500, 'failed to create a new cloth') unless ($top && $bot);

        if ($donor_id) {
            $top->create_related('donor_clothes', { donor_id => $donor_id });
            $bot->create_related('donor_clothes', { donor_id => $donor_id });
        }
        $top->bottom_id($bot->id);
        $bot->top_id($top->id);
        $top->update;
        $bot->update;
        $cloth = $top;
    } else {
        $cloth = $self->create_cloth($cid);
        return $self->error(500, 'failed to create a new cloth') unless $cloth;

        if ($donor_id) {
            $cloth->create_related('donor_clothes', { donor_id => $donor_id });
        }
    }
    # ~ COMMIT
    $guard->commit;

    $self->res->headers->header('Location' => $self->url_for('/clothes/' . $cloth->no));
    $self->respond_to(
        json => { json => $self->cloth2hr($cloth), status => 201 },
        html => sub {
            $self->redirect_to('/clothes/' . $cloth->no);
        }
    );
};

put '/clothes' => sub {
    my $self = shift;
    my $clothes = $self->param('clothes');
    return $self->error(400, 'Nothing to change') unless $clothes;

    my $status = $DB->resultset('Status')->find({ name => $self->param('status') });
    return $self->error(400, 'Invalid status') unless $status;

    my $rs    = $DB->resultset('Cloth')->search({ 'me.id' => { -in => [split(/,/, $clothes)] } });
    my $guard = $DB->txn_scope_guard;
    my @rows;
    # BEGIN TRANSACTION ~
    while (my $cloth = $rs->next) {
        $cloth->status_id($status->id);
        $cloth->update;
        push @rows, { $cloth->get_columns };
    }
    # ~ COMMIT
    $guard->commit;

    $self->respond_to(
        json => { json => [@rows] },
        html => { template => 'clothes' }    # TODO: `cloth.html.haml`
    );
};

get '/new-cloth' => 'new-cloth';

get '/clothes/:no' => sub {
    my $self = shift;
    my $no = $self->param('no');
    my $cloth = $DB->resultset('Cloth')->find({ no => $no });
    return $self->error(404, "Not found `$no`") unless $cloth;

    my $co_rs = $cloth->cloth_orders->search({
        'order.status_id' => { -in => [$Opencloset::Constant::STATUS_RENT, $cloth->status_id] },
    }, {
        join => 'order'
    })->next;

    unless ($co_rs) {
        $self->respond_to(
            json => { json => $self->cloth2hr($cloth) },
            html => { template => 'clothes/no', cloth => $cloth }    # also, CODEREF is OK
        );
        return;
    }

    my @with;
    my $order = $co_rs->order;
    for my $_cloth ($order->cloths) {
        next if $_cloth->id == $cloth->id;
        push @with, $self->cloth2hr($_cloth);
    }

    my $overdue = $self->overdue_calc($order->target_date, DateTime->now);
    my %columns = (
        %{ $self->cloth2hr($cloth) },
        rental_date => {
            raw => $order->rental_date,
            md  => $order->rental_date->month . '/' . $order->rental_date->day,
            ymd => $order->rental_date->ymd
        },
        target_date => {
            raw => $order->target_date,
            md  => $order->target_date->month . '/' . $order->target_date->day,
            ymd => $order->target_date->ymd
        },
        order_id    => $order->id,
        price       => $self->commify($order->price),
        overdue     => $overdue,
        late_fee    => $self->commify($order->price * 0.2 * $overdue),
        clothes     => \@with,
    );

    $columns{status} = $DB->resultset('Status')->find({ id => 6 })->name
        if $overdue;    # 6: 연체중, 한글을 쓰면 `utf8` pragma 를 써줘야 해서..

    $self->respond_to(
        json => { json => { %columns } },
        html => { template => 'clothes/no', cloth => $cloth }    # also, CODEREF is OK
    );
};

any [qw/put patch/] => '/clothes/:no' => sub {
    my $self = shift;
    my $no = $self->param('no');
    my $cloth = $DB->resultset('Cloth')->find({ no => $no });
    return $self->error(404, "Not found `$no`") unless $cloth;

    map {
        $cloth->$_($self->param($_)) if defined $self->param($_);
    } qw/chest waist arm length foot/;

    $cloth->update;
    $self->respond_to(
        json => { json => $self->cloth2hr($cloth) },
        html => { template => 'clothes/no', cloth => $cloth }    # also, CODEREF is OK
    );
};

get '/search' => sub {
    my $self = shift;

    my $q                = $self->param('q')                || q{};
    my $gid              = $self->param('gid')              || q{};
    my $color            = $self->param('color')            || q{};
    my $entries_per_page = $self->param('entries_per_page') || app->config->{entries_per_page};

    my $guest    = $gid ? $DB->resultset('Guest')->find({ id => $gid }) : undef;
    my $cond = {};
    my ($chest, $waist, $arm, $status_id, $category_id) = split /\//, $q;
    $category_id = $Opencloset::Constant::CATEOGORY_JACKET unless $category_id;
    $cond->{'me.category_id'} = $category_id;
    $cond->{'me.chest'}       = { '>=' => $chest } if $chest;
    $cond->{'bottom.waist'}   = { '>=' => $waist } if $waist;
    $cond->{'me.arm'}         = { '>=' => $arm   } if $arm;
    $cond->{'me.status_id'}   = $status_id         if $status_id;
    $cond->{'me.color'}       = $color             if $color;

    ### row, current_page, count
    my $clothes = $DB->resultset('Cloth')->search(
        $cond,
        {
            page     => $self->param('p') || 1,
            rows     => $entries_per_page,
            order_by => [qw/chest bottom.waist arm/],
            join     => 'bottom',
        }
    );

    my $pageset = Data::Pageset->new({
        total_entries    => $clothes->pager->total_entries,
        entries_per_page => $entries_per_page,
        current_page     => $self->param('p') || 1,
        mode             => 'fixed'
    });

    $self->stash(
        q           => $q,
        gid         => $gid,
        guest       => $guest,
        clothes     => $clothes,
        pageset     => $pageset,
        status_id   => $status_id || 0,
        category_id => $category_id,
        color       => $color || q{},
    );
};

get '/rental' => sub {
    my $self = shift;

    my $today = DateTime->now;
    $today->set_hour(0);
    $today->set_minute(0);
    $today->set_second(0);

    my $q      = $self->param('q');
    my @guests = $DB->resultset('Guest')->search({
        -or => [
            'user_id'    => $q,
            'user.name'  => $q,
            'user.phone' => $q,
            'user.email' => $q
        ],
    }, {
        join => 'user'
    });

    ### DBIx::Class::Storage::DBI::_gen_sql_bind(): DateTime objects passed to search() are not
    ### supported properly (InflateColumn::DateTime formats and settings are not respected.)
    ### See "Formatting DateTime objects in queries" in DBIx::Class::Manual::Cookbook.
    ### To disable this warning for good set $ENV{DBIC_DT_SEARCH_OK} to true
    ###
    ### DateTime object 를 search 에 바로 사용하지 말고 parser 를 이용하라능 - @aanoaa
    my $dt_parser = $DB->storage->datetime_parser;
    push @guests, $DB->resultset('Guest')->search({
        -or => [
            create_date => { '>=' => $dt_parser->format_datetime($today) },
            visit_date  => { '>=' => $dt_parser->format_datetime($today) },
        ],
    }, {
        order_by => { -desc => 'create_date' },
    });

    $self->stash(guests => \@guests);
} => 'rental';

post '/orders' => sub {
    my $self = shift;

    my $validator = $self->create_validator;
    $validator->field([qw/gid cloth-id/])
        ->each(sub { shift->required(1)->regexp(qr/^\d+$/) });

    return $self->error(400, 'failed to validate')
        unless $self->validate($validator);

    my $guest   = $DB->resultset('Guest')->find({ id => $self->param('gid') });
    my @clothes = $DB->resultset('Cloth')->search({ 'me.id' => { -in => [$self->param('cloth-id')] } });

    return $self->error(400, 'invalid request') unless $guest || @clothes;

    my $guard = $DB->txn_scope_guard;
    my $order;
    try {
        # BEGIN TRANSACTION ~
        $order = $DB->resultset('Order')->create({
            guest_id  => $guest->id,
            chest     => $guest->chest,
            waist     => $guest->waist,
            arm       => $guest->arm,
            length    => $guest->length,
            purpose   => $guest->purpose,
        });

        for my $cloth (@clothes) {
            $order->create_related('cloth_orders', { cloth_id => $cloth->id });
        }
        my $dt_parser = $DB->storage->datetime_parser;
        $guest->visit_date($dt_parser->format_datetime(DateTime->now()));
        $guest->update;    # refresh `visit_date`
        $guard->commit;
        # ~ COMMIT
    } catch {
        # ROLLBACK
        my $error = shift;
        $self->app->log->error("Failed to create `order`: $error");
        return $self->error(500, "Failed to create `order`: $error") unless $order;
    };

    $self->res->headers->header('Location' => $self->url_for('/orders/' . $guest->id));
    $self->respond_to(
        json => { json => $self->order2hr($order), status => 201 },
        html => sub {
            $self->redirect_to('/orders/' . $order->id);
        }
    );
};

get '/orders' => sub {
    my $self = shift;

    my $q      = $self->param('q') || '';
    my $cond;
    $cond->{status_id} = $q if $q;
    my $orders = $DB->resultset('Order')->search($cond);

    $self->stash( orders => $orders );
} => 'orders';

get '/orders/:id' => sub {
    my $self = shift;

    my $order = $DB->resultset('Order')->find({ id => $self->param('id') });
    return $self->error(404, "Not found") unless $order;

    my @clothes = $order->cloths;
    my $price = 0;
    for my $cloth (@clothes) {
        $price += $cloth->category->price;
    }

    my $overdue  = $order->target_date ? $self->overdue_calc($order->target_date, DateTime->now()) : 0;
    my $late_fee = $order->price * 0.2 * $overdue;

    my $c_jacket = $DB->resultset('Category')->find({ name => 'jacket' });
    my $cond = { category_id => $c_jacket->id };
    my $cloth = $order->cloths($cond)->next;

    my $satisfaction;
    if ($cloth) {
        $satisfaction = $cloth->satisfactions({
            cloth_id => $cloth->id,
            guest_id  => $order->guest->id,
        })->next;
    }

    $self->stash(
        order        => $order,
        clothes      => [@clothes],
        price        => $price,
        overdue      => $overdue,
        late_fee     => $late_fee,
        satisfaction => $satisfaction,
    );

    my %fillinform = $order->get_columns;
    $fillinform{price} = $price unless $fillinform{price};
    $fillinform{late_fee} = $late_fee;
    unless ($fillinform{target_date}) {
        $fillinform{target_date} = DateTime->now()->add(days => 3)->ymd;
    }

    my $status_id = $order->status ? $order->status->id : undef;
    if ($status_id) {
        if ($status_id == $Opencloset::Constant::STATUS_RENT) {
            $self->stash(template => 'orders/id/status_rent');
        } elsif ($status_id == $Opencloset::Constant::STATUS_RETURN) {
            $self->stash(template => 'orders/id/status_return');
        } elsif ($status_id == $Opencloset::Constant::STATUS_PARTIAL_RETURN) {
            $self->stash(template => 'orders/id/status_partial_return');
        }
    } else {
        $self->stash(template => 'orders/id/nil_status');
    }

    map { delete $fillinform{$_} } qw/chest waist arm length/;
    $self->render_fillinform({ %fillinform });
};

any [qw/post put patch/] => '/orders/:id' => sub {
    my $self = shift;

    # repeat codes; use `under`?
    my $order = $DB->resultset('Order')->find({ id => $self->param('id') });
    return $self->error(404, "Not found") unless $order;

    my $validator = $self->create_validator;
    unless ($order->status_id) {
        $validator->field('target_date')->required(1);
        $validator->field('payment_method')->required(1);
    }
    if ($order->status_id && $order->status_id == $Opencloset::Constant::STATUS_RENT) {
        $validator->field('return_method')->required(1);
    }
    $validator->field([qw/price discount late_fee l_discount/])
        ->each(sub { shift->regexp(qr/^\d+$/) });
    $validator->field([qw/chest waist arm top_fit bottom_fit/])
        ->each(sub { shift->regexp(qr/^[12345]$/) });

    return $self->error(400, 'failed to validate')
        unless $self->validate($validator);

    ## Note: target_date INSERT as string likes '2013-01-01',
    ##       maybe should convert to DateTime object
    map {
        $order->$_($self->param($_)) if defined $self->param($_);
    } qw/price discount target_date comment return_method late_fee l_discount payment_method staff_name/;
    my %status_to_be = (
        0 => $Opencloset::Constant::STATUS_RENT,
        $Opencloset::Constant::STATUS_RENT => $Opencloset::Constant::STATUS_RETURN,
        $Opencloset::Constant::STATUS_PARTIAL_RETURN => $Opencloset::Constant::STATUS_RETURN,
    );

    my $guard = $DB->txn_scope_guard;
    # BEGIN TRANSACTION ~
    my $status_id = $status_to_be{$order->status_id || 0};
    my @missing_clothes;
    if ($status_id == $Opencloset::Constant::STATUS_RETURN) {
        my $missing_clothes = $self->param('missing_clothes') || '';
        if ($missing_clothes) {
            $status_id = $Opencloset::Constant::STATUS_PARTIAL_RETURN;
            @missing_clothes = $DB->resultset('Cloth')->search({
                'me.no' => { -in => [split(/,/, $missing_clothes)] }
            });
        }
    }

    $order->status_id($status_id);
    my $dt_parser = $DB->storage->datetime_parser;
    if ($status_id == $Opencloset::Constant::STATUS_RETURN ||
            $status_id == $Opencloset::Constant::STATUS_PARTIAL_RETURN) {
        $order->return_date($dt_parser->format_datetime(DateTime->now()));
    }
    $order->rental_date($dt_parser->format_datetime(DateTime->now))
        if $status_id == $Opencloset::Constant::STATUS_RENT;
    $order->update;

    for my $cloth ($order->cloths) {
        if ($order->status_id == $Opencloset::Constant::STATUS_RENT) {
            $cloth->status_id($Opencloset::Constant::STATUS_RENT);
        } else {
            next if grep { $cloth->id == $_->id } @missing_clothes;
            if ($cloth->category_id == $Opencloset::Constant::CATEOGORY_SHOES ||
                  $cloth->category_id == $Opencloset::Constant::CATEOGORY_TIE ||
                  $cloth->category_id == $Opencloset::Constant::CATEOGORY_HAT) {
                $cloth->status_id($Opencloset::Constant::STATUS_AVAILABLE);    # Shoes, Tie, Hat
            } else {
                # otherwise
                if ($cloth->status_id != $Opencloset::Constant::STATUS_AVAILABLE) {
                    $cloth->status_id($Opencloset::Constant::STATUS_WASHING);
                }
            }
        }
        $cloth->update;
    }

    for my $cloth (@missing_clothes) {
        $self->app->log->debug('##########' . $cloth->no);
        $cloth->status_id($Opencloset::Constant::STATUS_PARTIAL_RETURN);
        $cloth->update;
    }
    $guard->commit;
    # ~ COMMIT

    my %satisfaction;
    map { $satisfaction{$_} = $self->param($_) } qw/chest waist arm top_fit bottom_fit/;

    if (values %satisfaction) {
        # $order
        my $c_jacket = $DB->resultset('Category')->find({ name => 'jacket' });
        my $cond = { category_id => $c_jacket->id };
        my $cloth = $order->cloths($cond)->next;
        if ($cloth) {
            $DB->resultset('Satisfaction')->update_or_create({
                %satisfaction,
                guest_id  => $order->guest_id,
                cloth_id => $cloth->id,
            });
        }
    }

    $self->respond_to(
        json => { json => $self->order2hr($order) },
        html => sub {
            $self->redirect_to($self->url_for);
        }
    );
};

del '/orders/:id' => sub {
    my $self = shift;

    my $order = $DB->resultset('Order')->find({ id => $self->param('id') });
    return $self->error(404, "Not found") unless $order;

    for my $cloth ($order->cloths) {
        $cloth->status_id($Opencloset::Constant::STATUS_AVAILABLE);
        $cloth->update;
    }

    $order->delete;

    $self->respond_to(
        json => { json => {} },    # just 200 OK
    );
};

post '/donors' => sub {
    my $self   = shift;

    my $validator = $self->create_validator;
    $validator->field('name')->required(1);
    $validator->field('phone')->regexp(qr/^\d{10,11}$/);
    $validator->field('email')->email;
    $validator->field('gender')->regexp(qr/^[12]$/);

    unless ($self->validate($validator)) {
        my @error_str;
        while ( my ($k, $v) = each %{ $validator->errors } ) {
            push @error_str, "$k:$v";
        }
        return $self->error( 400, { str => join(',', @error_str), data => $validator->errors } );
    }

    my $donor = $self->create_donor;
    return $self->error( 500, { str => 'failed to create a new donor' } ) unless $donor;

    $self->res->headers->header('Location' => $self->url_for('/donors/' . $donor->id));
    $self->respond_to(
        json => { json => { $donor->get_columns }, status => 201 },
    );
};

post '/sms' => sub {
    my $self = shift;

    my $validator = $self->create_validator;
    $validator->field('to')->required(1)->regexp(qr/^0\d{9,10}$/);
    return $self->error(400, 'Bad receipent') unless $self->validate($validator);

    my $to     = $self->param('to');
    my $from   = app->config->{sms}{sender};
    my $text   = app->config->{sms}{text};
    my $sender = SMS::Send->new(
        'KR::CoolSMS',
        _ssl      => 1,
        _user     => app->config->{sms}{username},
        _password => app->config->{sms}{password},
        _type     => 'sms',
        _from     => $from,
    );

    my $sent = $sender->send_sms(
        text => $text,
        to   => $to,
    );

    return $self->error(500, $sent->{reason}) unless $sent;

    my $sms = $DB->resultset('ShortMessage')->create({
        from => $from,
        to   => $to,
        msg  => $text,
    });

    $self->res->headers->header('Location' => $self->url_for('/sms/' . $sms->id));
    $self->respond_to(
        json => { json => { $sms->get_columns }, status => 201 },
        html => sub {
            $self->redirect_to('/sms/' . $sms->id);    # TODO: GET /sms/:id
        }
    );
};

app->secret( app->defaults->{secret} );
app->start;

__DATA__

@@ login.html.haml
- my $id = 'login';
- layout 'login', active_id => $id;
- title $sidebar->{meta}{login}{text};


@@ home.html.haml
- my $id   = 'home';
- my $meta = $sidebar->{meta};
- layout 'default', active_id => $id;
- title $meta->{$id}{text};

.search
  %form#cloth-search-form
    .input-group
      %input#cloth-id.form-control{ :type => 'text', :placeholder => '품번' }
      %span.input-group-btn
        %button#btn-cloth-search.btn.btn-sm.btn-default{ :type => 'button' }
          %i.icon-search.bigger-110 검색
      %span.input-group-btn
        %button#btn-clear.btn.btn.btn-sm.btn-default{:type => 'button'}
          %i.icon-eraser.bigger-110 지우기

#cloth-table
  %table.table.table-striped.table-bordered.table-hover
    %thead
      %tr
        %th.center
          %label
            %input#input-check-all.ace{ :type => 'checkbox' }
            %span.lbl
        %th 옷
        %th 상태
        %th 묶음
        %th 기타
    %tbody
  %ul
  #action-buttons{:style => 'display: none'}
    %span 선택한 항목을
    %button.btn.btn-mini{:type => 'button', :data-status => '세탁'} 세탁
    %button.btn.btn-mini{:type => 'button', :data-status => '대여가능'} 대여가능
    %button.btn.btn-mini{:type => 'button', :data-status => '분실'} 분실
    %span (으)로 변경 합니다

:plain
  <script id="tpl-row-checkbox-disabled" type="text/html">
    <tr data-order-id="<%= order_id %>">
      <td class="center">
        <label>
          <input class="ace" type="checkbox" disabled>
          <span class="lbl"></span>
        </label>
      </td>
      <td> <a href="/clothes/<%= no %>"> <%= no %> </a> </td> <!-- 옷 -->
      <td>
        <span class="order-status label">
          <%= status %>
          <span class="late-fee"><%= late_fee ? late_fee + '원' : '' %></span>
        </span>
      </td> <!-- 상태 -->
      <td>
        <% _.each(clothes, function(cloth) { %> <a href="/clothes/<%= cloth.no %>"><%= cloth.no %></a><% }); %>
      </td> <!-- 묶음 -->
      <td>
        <a href="/orders/<%= order_id %>"><span class="label label-info arrowed-right arrowed-in">
          <strong>주문서</strong>
          <time class="js-relative-date" datetime="<%= rental_date.raw %>" title="<%= rental_date.ymd %>"><%= rental_date.md %></time>
          ~
          <time class="js-relative-date" datetime="<%= target_date.raw %>" title="<%= target_date.ymd %>"><%= target_date.md %></time>
        </span></a>
      </td> <!-- 기타 -->
    </tr>
  </script>

:plain
  <script id="tpl-overdue-paragraph" type="text/html">
    <span>
      연체료 <%= late_fee %>원 = <%= price %>원 x <%= overdue %>일 x 20%
    </span>
  </script>

:plain
  <script id="tpl-row-checkbox-enabled" type="text/html">
    <tr class="row-checkbox" data-cloth-id="<%= id %>">
      <td class="center">
        <label>
          <input class="ace" type="checkbox" data-cloth-id="<%= id %>">
          <span class="lbl"></span>
        </label>
      </td>
      <td> <a href="/clothes/<%= no %>"> <%= no %> </a> </td> <!-- 옷 -->
      <td> <span class="order-status label"><%= status %></span> </td> <!-- 상태 -->
      <td> </td> <!-- 묶음 -->
      <td> </td> <!-- 기타 -->
    </tr>
  </script>


@@ new-borrower.html.haml
- my $id   = 'new-borrower';
- my $meta = $sidebar->{meta};
- layout 'default',
-   active_id   => $id,
-   breadcrumbs => [
-     { text => $meta->{$id}{text} },
-   ],
-   jses => ['/lib/bootstrap/js/fuelux/fuelux.wizard.min.js'];
- title $meta->{$id}{text};

#new-borrower
  = include 'new-borrower-inner'


@@ new-borrower-inner.html.ep
<div class="row-fluid">
  <div class="span12">
    <div class="widget-box">
      <div class="widget-header widget-header-blue widget-header-flat">
        <h4 class="lighter">대여자 등록</h4>
      </div>

      <div class="widget-body">
        <div class="widget-main">

          <div data-target="#step-container" class="row-fluid" id="fuelux-wizard">
            <ul class="wizard-steps">
              <li class="active" data-target="#step1">
                <span class="step">1</span>
                <span class="title">대여자 검색</span>
              </li>

              <li data-target="#step2" class="">
                <span class="step">2</span>
                <span class="title">개인 정보</span>
              </li>

              <li data-target="#step3" class="">
                <span class="step">3</span>
                <span class="title">신체 치수</span>
              </li>

              <li data-target="#step4" class="">
                <span class="step">4</span>
                <span class="title">대여 목적</span>
              </li>

              <li data-target="#step5" class="">
                <span class="step">5</span>
                <span class="title">완료</span>
              </li>
            </ul>
          </div>

          <hr>

          <div id="step-container" class="step-content row-fluid position-relative">

            <div id="step1" class="step-pane active">
              <h3 class="lighter block green">이전에 방문했던 적이 있나요?</h3>

              <div class="form-horizontal">

                <div class="form-group has-info">
                  <label class="control-label col-xs-12 col-sm-3 no-padding-right">대여자 검색:</label>

                  <div class="col-xs-12 col-sm-9">
                    <div class="search">
                      <div class='input-group'>
                        <input class='form-control' id='guest-search' type='text' name='q' placeholder='이름 또는 이메일, 휴대전화 번호' />
                        <span class='input-group-btn'>
                          <button class='btn btn-default btn-sm' id='btn-guest-search' type='submit'>
                            <i class='bigger-110 icon-search'>검색</i>
                          </button>
                        </span>
                      </div>
                    </div>
                  </div>
                </div>

                <div class="form-group has-info">
                  <label class="control-label col-xs-12 col-sm-3 no-padding-right">대여자 선택:</label>

                  <div class="col-xs-12 col-sm-9">
                    <div id="guest-search-list">
                      <div>
                        <label class="blue">
                          <input type="radio" class="ace valid" name="user-id" value="0">
                          <span class="lbl"> 처음 방문했습니다.</span>
                        </label>
                      </div>
                    </div>
                  </div>
                </div>

                <div class="hr hr-dotted"></div>
              </div>

              <form method="get" id="validation-form" class="form-horizontal" novalidate="novalidate">

                <div class="form-group has-info">
                  <label class="control-label col-xs-12 col-sm-3 no-padding-right"></label>
                  <div class="col-xs-12 col-sm-9">
                    <div>
                      <strong class="co-name"><%= $company_name %></strong>은 정확한 의류 선택 및
                      대여 관리를 위해 개인 정보와 신체 치수를 수집합니다.
                      수집한 정보는 <strong class="co-name"><%= $company_name %></strong>의
                      대여 서비스 품질을 높이기 위한 통계 목적으로만 사용합니다.
                    </div>

                    <div class="space-8"></div>

                    <div>
                      <strong class="co-name"><%= $company_name %></strong>은 대여자의 반납 편의를 돕거나
                      <strong class="co-name"><%= $company_name %></strong> 관련 유용한 정보를 알려드리기 위해
                      기재된 연락처로 휴대폰 단문 메시지 또는 전자우편을 보내거나 전화를 드립니다.
                    </div>

                  </div>
                </div>

              </form>
            </div>

            <div id="step2" class="step-pane">
              <h3 class="lighter block green">다음 개인 정보를 입력해주세요.</h3>

              <form method="get" id="validation-form" class="form-horizontal" novalidate="novalidate">
                <div class="form-group has-info">
                  <label for="email" class="control-label col-xs-12 col-sm-3 no-padding-right">전자우편:</label>

                  <div class="col-xs-12 col-sm-9">
                    <div class="clearfix">
                      <input type="email" class="col-xs-12 col-sm-4 valid" id="email" name="email">
                    </div>
                  </div>
                </div>

                <div class="hr hr-dotted"></div>

                <div class="form-group has-info">
                  <label for="name" class="control-label col-xs-12 col-sm-3 no-padding-right">이름:</label>

                  <div class="col-xs-12 col-sm-9">
                    <div class="clearfix">
                      <input type="text" class="col-xs-12 col-sm-4 valid" name="name" id="name">
                    </div>
                  </div>
                </div>

                <div class="space-2"></div>

                <div class="form-group has-info">
                  <label for="age" class="control-label col-xs-12 col-sm-3 no-padding-right">나이:</label>

                  <div class="col-xs-12 col-sm-9">
                    <div class="clearfix">
                      <input type="text" class="col-xs-12 col-sm-4 valid" name="age" id="age">
                    </div>
                  </div>
                </div>

                <div class="space-2"></div>

                <div class="form-group has-info">
                  <label class="control-label col-xs-12 col-sm-3 no-padding-right">성별:</label>

                  <div class="col-xs-12 col-sm-9">
                    <div>
                      <label class="blue">
                        <input type="radio" class="ace valid" value="1" name="gender">
                        <span class="lbl"> 남자</span>
                      </label>
                    </div>

                    <div>
                      <label class="blue">
                        <input type="radio" class="ace valid" value="2" name="gender">
                        <span class="lbl"> 여자</span>
                      </label>
                    </div>
                  </div>
                </div>

                <div class="space-2"></div>

                <div class="form-group has-info">
                  <label for="input-phone" class="control-label col-xs-12 col-sm-3 no-padding-right">휴대전화:</label>

                  <div class="col-xs-12 col-sm-7">
                    <div class="input-group">
                      <input type="tel" name="phone" id="input-phone" class="valid form-control">

                      <span class="input-group-btn">
                        <button id="btn-sendsms" class="btn btn-sm btn-default"> <i class="icon-phone"></i> 인증 </button>
                      </span>
                    </div>
                  </div>
                </div>

                <div class="space-2"></div>

                <div class="form-group has-info">
                  <label for="address" class="control-label col-xs-12 col-sm-3 no-padding-right">주소:</label>

                  <div class="col-xs-12 col-sm-9">
                    <div class="clearfix">
                      <input type="text" class="col-xs-12 col-sm-8 valid" name="address" id="address">
                    </div>
                  </div>
                </div>

              </form>
            </div>

            <div id="step3" class="step-pane">
              <h3 class="lighter block green">다음 신체 치수를 입력해주세요.</h3>

              <form method="get" id="validation-form" class="form-horizontal" novalidate="novalidate">
                <div class="form-group has-info">
                  <label for="guest-height" class="control-label col-xs-12 col-sm-3 no-padding-right">키:</label>

                  <div class="col-xs-12 col-sm-5">
                    <div class="input-group">
                      <input type="text" class="valid form-control" id="guest-height" name="height">
                      <span class="input-group-addon"> <i>cm</i> </span>
                    </div>
                  </div>
                </div>

                <div class="space-2"></div>

                <div class="form-group has-info">
                  <label for="guest-weight" class="control-label col-xs-12 col-sm-3 no-padding-right">몸무게:</label>

                  <div class="col-xs-12 col-sm-5">
                    <div class="input-group">
                      <input type="text" class="valid form-control" id="guest-weight" name="weight">
                      <span class="input-group-addon"> <i>kg</i> </span>
                    </div>
                  </div>
                </div>

                <div class="hr hr-dotted"></div>

                <div class="form-group has-info">
                  <label for="guest-bust" class="control-label col-xs-12 col-sm-3 no-padding-right">가슴:</label>

                  <div class="col-xs-12 col-sm-5">
                    <div class="input-group">
                      <input type="text" class="valid form-control" id="guest-chest" name="chest">
                      <span class="input-group-addon"> <i>cm</i> </span>
                    </div>
                  </div>
                </div>

                <div class="space-2"></div>

                <div class="form-group has-info">
                  <label for="guest-waist" class="control-label col-xs-12 col-sm-3 no-padding-right">허리:</label>

                  <div class="col-xs-12 col-sm-5">
                    <div class="input-group">
                      <input type="text" class="valid form-control" id="guest-waist" name="waist">
                      <span class="input-group-addon"> <i>cm</i> </span>
                    </div>
                  </div>
                </div>

                <div class="space-2"></div>

                <div class="form-group has-info">
                  <label for="guest-arm" class="control-label col-xs-12 col-sm-3 no-padding-right">팔 길이:</label>

                  <div class="col-xs-12 col-sm-5">
                    <div class="input-group">
                      <input type="text" class="valid form-control" id="guest-arm" name="arm">
                      <span class="input-group-addon"> <i>cm</i> </span>
                    </div>
                  </div>
                </div>

                <div class="space-2"></div>

                <div class="form-group has-info">
                  <label for="guest-length" class="control-label col-xs-12 col-sm-3 no-padding-right">다리 길이:</label>

                  <div class="col-xs-12 col-sm-5">
                    <div class="input-group">
                      <input type="text" class="valid form-control" id="guest-length" name="length">
                      <span class="input-group-addon"> <i>cm</i> </span>
                    </div>
                  </div>
                </div>

              </form>
            </div>

            <div id="step4" class="step-pane">
              <h3 class="lighter block green">대여 목적을 입력해주세요.</h3>

              <form method="get" id="validation-form" class="form-horizontal" novalidate="novalidate">

                <div class="form-group has-info">
                  <label for="guest-why" class="control-label col-xs-12 col-sm-3 no-padding-right">대여 목적:</label>

                  <div class="col-xs-12 col-sm-7">
                    <div class="guest-why">
                      <input type="text" class="valid" id="guest-why" name="purpose" data-provide="tag" value="" placeholder="대여 목적을 선택하거나 입력하세요...">
                      <p>
                        <span class="label label-info clickable"> 입사면접 </span>
                        <span class="label label-info clickable"> 사진촬영 </span>
                        <span class="label label-info clickable"> 결혼식 </span>
                        <span class="label label-info clickable"> 장례식 </span>
                        <span class="label label-info clickable"> 입학식 </span>
                        <span class="label label-info clickable"> 졸업식 </span>
                        <span class="label label-info clickable"> 세미나 </span>
                        <span class="label label-info clickable"> 발표 </span>
                      </p>
                    </div>
                  </div>
                </div>

                <div class="space-2"></div>

                <div class="form-group has-info">
                  <label for="guest-domain" class="control-label col-xs-12 col-sm-3 no-padding-right">응시 기업 및 분야:</label>

                  <div class="col-xs-12 col-sm-9">
                    <div class="clearfix">
                      <input type="text" class="col-xs-12 col-sm-4 valid" id="guest-domain" name="domain">
                    </div>
                  </div>
                </div>

              </form>
            </div>

            <div id="step5" class="step-pane">
              <h3 class="lighter block green">등록이 완료되었습니다!</h3>
            </div>
          </div>

          <hr>
          <div class="row-fluid wizard-actions">
            <button class="btn btn-prev" disabled="disabled">
              <i class="icon-arrow-left"></i>
              이전
            </button>

            <button data-last="완료 " class="btn btn-success btn-next">
              다음
            <i class="icon-arrow-right icon-on-right"></i></button>
          </div>
        </div><!-- /widget-main -->
      </div><!-- /widget-body -->
    </div>
  </div>
</div>

<script id="tpl-new-borrower-guest-id" type="text/html">
  <div>
    <label class="blue highlight">
      <input type="radio" class="ace valid" name="user-id" value="<%%= user_id %>" data-user-id="<%%= user_id %>" data-guest-id="<%%= id %>">
      <span class="lbl"> <%%= name %> (<%%= email %>)</span>
      <span><%%= address %></span>
    </label>
  </div>
</script>


@@ guests/status.html.haml
%ul
  %li
    %i.icon-user
    %a{:href => "#{url_for('/guests/' . $guest->id)}"} #{$guest->user->name}
    %span (#{$guest->user->age})
  %li
    %i.icon-map-marker
    = $guest->user->address
  %li
    %i.icon-envelope
    %a{:href => "mailto:#{$guest->user->email}"}= $guest->user->email
  %li= $guest->user->phone
  %li
    %span #{$guest->height} cm,
    %span #{$guest->weight} kg
  - if ($guest->target_date) {
    %li= $guest->target_date->ymd . ' 착용'
  - }


@@ guests/id.html.haml
- layout 'default';
- title $guest->user->name . '님';

%div= include 'guests/status', guest => $guest
%div= include 'guests/breadcrumb', guest => $guest, status_id => 1;
%h3 주문내역
%ul
  - for my $order (@$orders) {
    - if ($order->status) {
      %li
        %a{:href => "#{url_for('/orders/' . $order->id)}"}
          - if ($order->status->name eq '대여중') {
            - if (overdue_calc($order->target_date, DateTime->now())) {
              %span.label.label-important 연체중
            - } else {
              %span.label.label-important= $order->status->name
            - }
            %span.highlight{:title => '대여일'}= $order->rental_date->ymd
            ~
            %span{:title => '반납예정일'}= $order->target_date->ymd
          - } else {
            %span.label= $order->status->name
            %span.highlight{:title => '대여일'}= $order->rental_date->ymd
            ~
            %span.highlight{:title => '반납일'}= $order->return_date->ymd
          - }
    - }
  - }


@@ guests/breadcrumb.html.haml
%p
  %a{:href => '/guests/#{$guest->id}'}= $guest->user->name
  님
  - if ($guest->visit_date) {
    %strong= $guest->visit_date->ymd
    %span 일 방문
  - }
  %div
    %span.label.label-info.search-label
      %a{:href => "#{url_with('/search')->query([q => $guest->chest])}///#{$status_id}"}= $guest->chest
    %span.label.label-info.search-label
      %a{:href => "#{url_with('/search')->query([q => '/' . $guest->waist . '//' . $status_id])}"}= $guest->waist
    %span.label.label-info.search-label
      %a{:href => "#{url_with('/search')->query([q => '//' . $guest->arm])}/#{$status_id}"}= $guest->arm
    %span.label= $guest->length
    %span.label= $guest->height
    %span.label= $guest->weight


@@ guests/breadcrumb/radio.html.haml
%label.radio.inline
  %input{:type => 'radio', :name => 'gid', :value => '#{$guest->id}'}
  %a{:href => '/guests/#{$guest->id}'}= $guest->user->name
  님
  - if ($guest->visit_date) {
    %strong= $guest->visit_date->ymd
    %span 일 방문
  - }
%div
  %i.icon-envelope
  %a{:href => "mailto:#{$guest->user->email}"}= $guest->user->email
%div.muted= $guest->user->phone
%div
  %span.label.label-info= $guest->chest
  %span.label.label-info= $guest->waist
  %span.label.label-info= $guest->arm
  %span.label= $guest->length
  %span.label= $guest->height
  %span.label= $guest->weight


@@ donors/breadcrumb/radio.html.haml
%input{:type => 'radio', :name => 'donor_id', :value => '#{$donor->id}'}
%a{:href => '/donors/#{$donor->id}'}= $donor->user->name
님
%div
  - if ($donor->email) {
    %i.icon-envelope
    %a{:href => "mailto:#{$donor->email}"}= $donor->email
  - }
  - if ($donor->phone) {
    %div.muted= $donor->phone
  - }


@@ search.html.haml
- my $id   = 'search';
- my $meta = $sidebar->{meta};
- layout 'default',
-   active_id   => $id,
-   breadcrumbs => [
-     { text => $meta->{$id}{text} },
-   ];
- title $meta->{$id}{text};

.row
  .col-xs-12
    %p
      %span.badge.badge-inverse 매우작음
      %span.badge 작음
      %span.badge.badge-success 맞음
      %span.badge.badge-warning 큼
      %span.badge.badge-important 매우큼
    %p.muted
      %span.text-info 상태
      %span{:class => "#{$status_id == 1 ? 'highlight' : ''}"}
        %a{:href => "#{url_with->query(q => _q(status => 1))}"} 1: 대여가능
      %span{:class => "#{$status_id == 2 ? 'highlight' : ''}"}
        %a{:href => "#{url_with->query(q => _q(status => 2))}"} 2: 대여중
      %span{:class => "#{$status_id == 3 ? 'highlight' : ''}"}
        %a{:href => "#{url_with->query(q => _q(status => 3))}"} 3: 세탁
      %span{:class => "#{$status_id == 4 ? 'highlight' : ''}"}
        %a{:href => "#{url_with->query(q => _q(status => 4))}"} 4: 수선
      %span{:class => "#{$status_id == 5 ? 'highlight' : ''}"}
        %a{:href => "#{url_with->query(q => _q(status => 5))}"} 5: 대여불가
      %span{:class => "#{$status_id == 7 ? 'highlight' : ''}"}
        %a{:href => "#{url_with->query(q => _q(status => 7))}"} 7: 분실
    %p.muted
      %span.text-info 종류
      %span{:class => "#{$category_id == 1 ? 'highlight' : ''}"}
        %a{:href => "#{url_with->query(q => _q(category => 1))}"} 1: Jacket
      %span{:class => "#{$category_id == 2 ? 'highlight' : ''}"}
        %a{:href => "#{url_with->query(q => _q(category => 2))}"} 2: Pants
      %span{:class => "#{$category_id == 3 ? 'highlight' : ''}"}
        %a{:href => "#{url_with->query(q => _q(category => 3))}"} 3: Shirts
      %span{:class => "#{$category_id == 4 ? 'highlight' : ''}"}
        %a{:href => "#{url_with->query(q => _q(category => 4))}"} 4: Shoes
      %span{:class => "#{$category_id == 5 ? 'highlight' : ''}"}
        %a{:href => "#{url_with->query(q => _q(category => 5))}"} 5: Hat
      %span{:class => "#{$category_id == 6 ? 'highlight' : ''}"}
        %a{:href => "#{url_with->query(q => _q(category => 6))}"} 6: Tie
      %span{:class => "#{$category_id == 7 ? 'highlight' : ''}"}
        %a{:href => "#{url_with->query(q => _q(category => 7))}"} 7: Waistcoat
      %span{:class => "#{$category_id == 8 ? 'highlight' : ''}"}
        %a{:href => "#{url_with->query(q => _q(category => 8))}"} 8: Coat
      %span{:class => "#{$category_id == 9 ? 'highlight' : ''}"}
        %a{:href => "#{url_with->query(q => _q(category => 9))}"} 9: Onepiece
      %span{:class => "#{$category_id == 10 ? 'highlight' : ''}"}
        %a{:href => "#{url_with->query(q => _q(category => 10))}"} 10: Skirt
      %span{:class => "#{$category_id == 11 ? 'highlight' : ''}"}
        %a{:href => "#{url_with->query(q => _q(category => 11))}"} 11: Blouse

.row
  .col-xs-12
    .search
      %form{ :method => 'get', :action => '' }
        .input-group
          %input#gid{:type => 'hidden', :name => 'gid', :value => "#{$gid}"}
          %input#q.form-control{ :type => 'text', :placeholder => '가슴/허리/팔/상태/종류', :name => 'q', :value => "#{$q}" }
          %span.input-group-btn
            %button#btn-cloth-search.btn.btn-sm.btn-default{ :type => 'submit' }
              %i.icon-search.bigger-110 검색

    .space-10

    .col-xs-12.col-lg-10
      %a.btn.btn-sm.btn-info{:href => "#{url_with->query([color => ''])}"} 모두 보기
      %a.btn.btn-sm.btn-black{:href => "#{url_with->query([color => 'B'])}"} 검정(B)
      %a.btn.btn-sm.btn-navy{:href => "#{url_with->query([color => 'N'])}"} 감청(N)
      %a.btn.btn-sm.btn-gray{:href => "#{url_with->query([color => 'G'])}"} 회색(G)
      %a.btn.btn-sm.btn-red{:href => "#{url_with->query([color => 'R'])}"} 빨강(R)
      %a.btn.btn-sm.btn-whites{:href => "#{url_with->query([color => 'W'])}"} 흰색(W)

.space-10

.row
  .col-xs-12
    - if ($q) {
      %p
        %strong= $q
        %span.muted 의 검색결과
    - }

.row
  .col-xs-12
    = include 'guests/breadcrumb', guest => $guest if $guest

.row
  .col-xs-12
    %ul.ace-thumbnails
      - while (my $c = $clothes->next) {
        %li
          %a{:href => '/clothes/#{$c->no}'}
            %img{:src => 'http://placehold.it/160x160', :alt => '#{$c->no}'}

          .tags-top-ltr
            %span.label-holder
              %span.label.label-warning.search-label
                %a{:href => '/clothes/#{$c->no}'}= $c->no

          .tags
            %span.label-holder
              - if ($c->chest) {
                %span.label.label-info.search-label
                  %a{:href => "#{url_with->query([p => 1, q => $c->chest . '///' . $status_id])}"}= $c->chest
                - if ($c->bottom) {
                  %span.label.label-info.search-label
                    %a{:href => "#{url_with->query([p => 1, q => '/' . $c->bottom->waist . '//' . $status_id])}"}= $c->bottom->waist
                - }
              - }
              - if ($c->arm) {
                %span.label.label-info.search-label
                  %a{:href => "#{url_with->query([p => 1, q => '//' . $c->arm . '/' . $status_id])}"}= $c->arm
              - }
              - if ($c->foot) {
                %span.label.label-info.search-label= $c->foot
              - }

            %span.label-holder
              - if ($c->status->name eq '대여가능') {
                %span.label.label-success= $c->status->name
              - }
              - elsif ($c->status->name eq '대여중') {
                %span.label.label-important= $c->status->name
                - if (my $order = $c->orders({ status_id => 2 })->next) {
                  %small.muted{:title => '반납예정일'}= $order->target_date->ymd if $order->target_date
                - }
              - }
              - else {
                %span.label= $c->status->name
              - }
          .satisfaction
            %ul
              - for my $s ($c->satisfactions({}, { rows => 5, order_by => { -desc => [qw/create_date/] } })) {
                %li
                  %span.badge{:class => 'satisfaction-#{$s->chest || 0}'}= $s->guest->chest
                  %span.badge{:class => 'satisfaction-#{$s->waist || 0}'}= $s->guest->waist
                  %span.badge{:class => 'satisfaction-#{$s->arm || 0}'}=   $s->guest->arm
                  %span.badge{:class => 'satisfaction-#{$s->top_fit || 0}'}    상
                  %span.badge{:class => 'satisfaction-#{$s->bottom_fit || 0}'} 하
                  - if ($guest && $s->guest->id == $guest->id) {
                    %i.icon-star{:title => '대여한적 있음'}
                  - }
              - }
      - } # end of while

.row
  .col-xs-12
    .center
      = include 'pagination'


@@ clothes/no.html.haml
- layout 'default', jses => ['clothes-no.js'];
- title 'clothes/' . $cloth->no;

%h1
  %a{:href => ''}= $cloth->no
  %span - #{$cloth->category->name}

%form#edit
  %a#btn-edit.btn.btn-sm{:href => '#'} edit
  #input-edit{:style => 'display: none'}
    - if ($cloth->category->which eq 'top') {
      %input{:type => 'text', :name => 'chest', :value => '#{$cloth->chest}', :placeholder => '가슴둘레'}
      %input{:type => 'text', :name => 'arm', :value => '#{$cloth->arm}', :placeholder => '팔길이'}
    - } elsif ($cloth->category->which eq 'bottom') {
      %input{:type => 'text', :name => 'waist', :value => '#{$cloth->waist}', :placeholder => '허리둘레'}
      %input{:type => 'text', :name => 'length', :value => '#{$cloth->length}', :placeholder => '기장'}
    - } elsif ($cloth->category->which eq 'foot') {
      %input{:type => 'text', :name => 'foot', :value => '#{$cloth->foot}', :placeholder => '발크기'}
    - }
    %input#btn-submit.btn.btn-sm{:type => 'submit', :value => 'Save Changes'}
    %a#btn-cancel.btn.btn-sm{:href => '#'} Cancel

%h4= $cloth->compatible_code

.row
  .span8
    - if ($cloth->status->name eq '대여가능') {
      %span.label.label-success= $cloth->status->name
    - } elsif ($cloth->status->name eq '대여중') {
      %span.label.label-important= $cloth->status->name
      - if (my $order = $cloth->orders({ status_id => 2 })->next) {
        - if ($order->target_date) {
          %small.highlight{:title => '반납예정일'}
            %a{:href => "/orders/#{$order->id}"}= $order->target_date->ymd
        - }
      - }
    - } else {
      %span.label= $cloth->status->name
    - }

    %span
      - if ($cloth->top) {
        %a{:href => '/clothes/#{$cloth->top->no}'}= $cloth->top->no
      - }
      - if ($cloth->bottom) {
        %a{:href => '/clothes/#{$cloth->bottom->no}'}= $cloth->bottom->no
      - }

    %div
      %img.img-polaroid{:src => 'http://placehold.it/200x200', :alt => '#{$cloth->no}'}

    %div
      - if ($cloth->chest) {
        %span.label.label-info.search-label
          %a{:href => "#{url_with('/search')->query([q => $cloth->chest])}///1"}= $cloth->chest
      - }
      - if ($cloth->waist) {
        %span.label.label-info.search-label
          %a{:href => "#{url_with('/search')->query([q => '/' . $cloth->waist . '//1'])}"}= $cloth->waist
      - }
      - if ($cloth->arm) {
        %span.label.label-info.search-label
          %a{:href => "#{url_with('/search')->query([q => '//' . $cloth->arm])}/1"}= $cloth->arm
      - }
      - for my $column (qw/length foot/) {
        - if ($cloth->$column) {
          %span.label.label-info.search-label{:class => 'category-#{$column}'}= $cloth->$column
        - }
      - }
    - if ($cloth->donor) {
      %h3= $cloth->donor->user->name
      %p.muted 님께서 기증하셨습니다
    - }
  .span4
    %ul
      - for my $order ($cloth->orders({ status_id => { '!=' => undef } }, { order_by => { -desc => [qw/rental_date/] } })) {
        %li
          %a{:href => '/guests/#{$order->guest->id}'}= $order->guest->user->name
          님
          - if ($order->status && $order->status->name eq '대여중') {
            - if (overdue_calc($order->target_date, DateTime->now())) {
              %span.label.label-important 연체중
            - } else {
              %span.label.label-important= $order->status->name
            - }
          - } else {
            %span.label= $order->status->name
          - }
          %a.highlight{:href => '/orders/#{$order->id}'}
            %time{:title => '대여일'}= $order->rental_date->ymd
      - }


@@ pagination.html.ep
<ul class="pagination">
  <li class="previous">
    <a href="<%= url_with->query([p => $pageset->first_page]) %>">
      <i class="icon-double-angle-left"></i>
      <i class="icon-double-angle-left"></i>
    </a>
  </li>

  % if ( $pageset->previous_set ) {
  <li class="previous">
    <a href="<%= url_with->query([p => $pageset->previous_set]) %>">
      <i class="icon-double-angle-left"></i>
    </a>
  </li>
  % }
  % else {
  <li class="previous disabled">
    <a href="#">
      <i class="icon-double-angle-left"></i>
    </a>
  </li>
  % }

  % for my $p ( @{$pageset->pages_in_set} ) {
  %   if ( $p == $pageset->current_page ) {
  <li class="active"> <a href="#"> <%= $p %> </a> </li>
  %   }
  %   else {
  <li> <a href="<%= url_with->query([p => $p]) %>"> <%= $p %> </a> </li>
  %   }
  % }

  % if ( $pageset->next_set ) {
  <li class="previous">
    <a href="<%= url_with->query([p => $pageset->next_set]) %>">
      <i class="icon-double-angle-right"></i>
    </a>
  </li>
  % }
  % else {
  <li class="previous disabled">
    <a href="#">
      <i class="icon-double-angle-right"></i>
    </a>
  </li>
  % }

  <li class="next">
    <a href="<%= url_with->query([p => $pageset->last_page]) %>">
      <i class="icon-double-angle-right"></i>
      <i class="icon-double-angle-right"></i>
    </a>
  </li>
</ul>


@@ bad_request.html.haml
- layout 'default';
- title 'Bad request';

%h1 400 Bad request
- if ($error) {
  %p.text-error= $error
- }


@@ rental.html.haml
- my $id   = 'rental';
- my $meta = $sidebar->{meta};
- layout 'default',
-   active_id   => $id,
-   breadcrumbs => [
-     { text => $meta->{$id}{text} },
-   ];
- title $meta->{$id}{text};

.pull-right
  %form.form-search{:method => 'get', :action => ''}
    %input.input-medium.search-query{:type => 'text', :id => 'search-query', :name => 'q', :placeholder => '이메일, 이름 또는 휴대폰번호'}
    %button.btn{:type => 'submit'} 검색

.search
  %form#cloth-search-form
    .input-group
      %input#cloth-id.form-control{ :type => 'text', :placeholder => '품번' }
      %span.input-group-btn
        %button#btn-cloth-search.btn.btn-sm.btn-default{ :type => 'button' }
          %i.icon-search.bigger-110 검색
      %span.input-group-btn
        %button#btn-clear.btn.btn.btn-sm.btn-default{:type => 'button'}
          %i.icon-eraser.bigger-110 지우기

%form#order-form{:method => 'post', :action => '/orders'}
  .row
    .span8
      #clothes-list
        %ul
        #action-buttons{:style => 'display: none'}
          %button.btn{:type => 'button'} 주문서 확인
    .span4
      %ul
        - for my $g (@$guests) {
          %li= include 'guests/breadcrumb/radio', guest => $g
        - }

:plain
  <script id="tpl-row-checkbox" type="text/html">
    <li class="row-checkbox" data-cloth-id="<%= id %>">
      <% if (!/^대여가능/.test(status)) { %>
      <label>
        <a href="/clothes/<%= no %>"><%= category %></a>
        <% if (/^(대여중|연체중)/.test(status)) { %>
        <span class="order-status label label-important"><%= status %></span>
        <% } else { %>
        <span class="order-status label"><%= status %></span>
        <% } %>
      </label>
      <% } else { %>
      <label class="checkbox">
        <input type="checkbox" name="cloth-id" value="<%= id %>" checked="checked" data-cloth-id="<%= id %>">
        <a href="/clothes/<%= no %>"><%= category %></a>
        <span class="order-status label"><%= status %></span>
        <strong><%= price %></strong>
      </label>
      <% } %>
    </li>
  </script>


@@ orders.html.haml
- my $id   = 'orders';
- my $meta = $sidebar->{meta};
- layout 'default',
-   active_id   => $id,
-   breadcrumbs => [
-     { text => $meta->{$id}{text} },
-   ];
- title $meta->{$id}{text};

%ul
  - while(my $order = $orders->next) {
      - if ($order->status) {
        %li
          %a{:href => "#{url_for('/orders/' . $order->id)}"}
            - if ($order->status->name eq '대여중') {
              - if (overdue_calc($order->target_date, DateTime->now())) {
                %span.label.label-important 연체중
              - } else {
                %span.label.label-important= $order->status->name
              - }
              %span.highlight{:title => '대여일'}= $order->rental_date->ymd
              ~
              %span{:title => '반납예정일'}= $order->target_date->ymd
            - } else {
              %span.label= $order->status->name
              %span.highlight{:title => '대여일'}= $order->rental_date->ymd
              ~
              %span.highlight{:title => '반납일'}= $order->return_date->ymd
            - }
      - }
  - }


@@ orders/id/nil_status.html.haml
- layout 'default', jses => ['orders-id.js'];
- title '주문확인';

%div.pull-right= include 'guests/breadcrumb', guest => $order->guest, status_id => ''

%div
  %p.muted
    최종금액 = 정상가 + 추가금액 - 에누리금액
  %p#total_price
    %strong#total_fee{:title => '최종금액'}
    %span =
    %span#origin_fee{:title => '정상가'}
    %span +
    %span#additional_fee{:title => '추가금액'}
    %span -
    %span#discount_fee{:title => '에누리금액'}

%form.form-horizontal{:method => 'post', :action => ''}
  %legend
    - my $loop = 0;
    - for my $cloth (@$clothes) {
      - $loop++;
      - if ($loop == 1) {
        %span
          %a{:href => '/clothes/#{$cloth->no}'}= $cloth->category->name
          %small.highlight= commify($cloth->category->price)
      - } elsif ($loop == 2) {
        %span
          with
          %a{:href => '/clothes/#{$cloth->no}'}= $cloth->category->name
          %small.highlight= commify($cloth->category->price)
      - } else {
        %span
          ,
          %a{:href => '/clothes/#{$cloth->no}'}= $cloth->category->name
          %small.highlight= commify($cloth->category->price)
      - }
    - }
  .control-group
    %label.control-label{:for => 'input-price'} 가격
    .controls
      %input{:type => 'text', :id => 'input-price', :name => 'price', :value => '#{$price}'}
      원
  .control-group
    %label.control-label{:for => 'input-discount'} 에누리
    .controls
      %input{:type => 'text', :id => 'input-discount', :name => 'discount'}
      원
  .control-group
    %label.control-label 결제방법
    .controls
      %label.radio.inline
        %input{:type => 'radio', :name => 'payment_method', :value => '현금'}
          현금
      %label.radio.inline
        %input{:type => 'radio', :name => 'payment_method', :value => '카드'}
          카드
      %label.radio.inline
        %input{:type => 'radio', :name => 'payment_method', :value => '현금+카드'}
          현금 + 카드
  .control-group
    %label.control-label{:for => 'input-target-date'} 반납예정일
    .controls
      %input#input-target-date{:type => 'text', :name => 'target_date'}
  .control-group
    %label.control-label{:for => 'input-purpose'} 대여목적
    .controls
      %input{:type => 'text', :id => 'input-purpose', :name => 'purpose', :placeholder => '선택하거나 입력'}
      %p
        %span.label.clickable 입사면접
        %span.label.clickable 사진촬영
        %span.label.clickable 결혼식
        %span.label.clickable 장례식
        %span.label.clickable 학교행사
  .control-group
    %label.control-label{:for => 'input-staff'} staff
    .controls
      %input#input-staff{:type => 'text', :name => 'staff_name'}
      %p
        %span.label.clickable 한만일
        %span.label.clickable 김소령
        %span.label.clickable 서동건
        %span.label.clickable 정선경
        %span.label.clickable 김기리
  .control-group
    %label.control-label{:for => 'input-comment'} Comment
    .controls
      %textarea{:id => 'input-comment', :name => 'comment'}
  .control-group
    %label.control-label 만족도
    .controls
      %input.span1{:type => 'text', :name => 'chest', :placeholder => '가슴'}
      %input.span1{:type => 'text', :name => 'waist', :placeholder => '허리'}
      %input.span1{:type => 'text', :name => 'arm', :placeholder => '팔'}
      %input.span1{:type => 'text', :name => 'top_fit', :placeholder => '상의'}
      %input.span1{:type => 'text', :name => 'bottom_fit', :placeholder => '하의'}
  .control-group
    .controls
      %input.btn.btn-success{:type => 'submit', :value => '대여완료'}

@@ partial/status_label.html.haml
- if ($overdue && $order->status_id == $Opencloset::Constant::STATUS_RENT) {
  %span.label{:class => 'status-#{$order->status_id}'} 연체중
- } else {
  %span.label{:class => 'status-#{$order->status_id}'}= $order->status->name
- }
%p
  %span.highlight= $order->purpose
  으로 방문

@@ partial/order_info.html.haml
- if ($order->rental_date) {
  %h3
    %time.highlight= $order->rental_date->ymd . ' ~ '
    %time.highlight= $order->return_date->ymd if $order->return_date
  %p.muted= '반납예정일: ' . $order->target_date->ymd if $order->target_date
- }

%h3
  %span.highlight= commify($order->price - $order->discount)
%p.muted= commify($order->discount) . '원 할인'

%p= $order->payment_method
%p= $order->staff_name

- if ($overdue) {
  %p.muted
    %span 연체료
    %strong.text-error= commify($late_fee)
    는 연체일(#{ $overdue }) x 대여금액(#{ commify($order->price) })의 20% 로 계산됩니다
- }

- if ($order->comment) {
  %p.well= $order->comment 
- }


@@ partial/satisfaction.html.haml
%h5 만족도
- my ($c, $w, $a, $t, $b) = ($s->chest || 0, $s->waist || 0, $s->arm || 0, $s->top_fit || 0, $s->bottom_fit || 0);
%p
  %span.badge{:class => "satisfaction-#{$c}"} 가슴
  %span.badge{:class => "satisfaction-#{$w}"} 허리
  %span.badge{:class => "satisfaction-#{$a}"} 팔길이
  %span.badge{:class => "satisfaction-#{$t}"} 상의fit
  %span.badge{:class => "satisfaction-#{$b}"} 하의fit


@@ orders/id/status_rent.html.haml
- layout 'default', jses => ['orders-id.js'];
- title '주문확인 - 대여중';

%p= include 'partial/status_label'
%div.pull-right= include 'guests/breadcrumb', guest => $order->guest, status_id => ''
%p.text-info 반납품목을 확인해주세요
#clothes-category
  %form#form-cloth-no
    %fieldset
      .input-append
        %input#input-cloth-no.input-large{:type => 'text', :placeholder => '품번'}
        %button#btn-cloth-no.btn{:type => 'button'} 입력
      - for my $cloth (@$clothes) {
        %label.checkbox
          %input.input-cloth{:type => 'checkbox', :data-cloth-no => '#{$cloth->no}'}
          %a{:href => '/clothes/#{$cloth->no}'}= $cloth->category->name
          %small.highlight= commify($cloth->category->price)
      - }
%div= include 'partial/order_info'

%form#form-return.form-horizontal{:method => 'post', :action => "#{url_for('')}"}
  %fieldset
    %legend 연체료 및 반납방법
    .control-group
      %label 연체료
      .controls
        %input#input-late_fee.input-mini{:type => 'text', :name => 'late_fee', :placeholder => '연체료'}
    .control-group
      %label{:for => '#input-ldiscount'} 연체료의 에누리
      .controls
        %input#input-ldiscount.input-mini{:type => 'text', :name => 'l_discount', :placeholder => '연체료의 에누리'}
    .control-group
      %label 반납방법
      .controls
        %label.radio.inline
          %input{:type => 'radio', :name => 'return_method', :value => '방문'}
          방문
        %label.radio.inline
          %input{:type => 'radio', :name => 'return_method', :value => '택배'}
          택배
    .control-group
      %label 결제방법
      .controls
        %label.radio.inline
          %input{:type => 'radio', :name => 'l_payment_method', :value => '현금'}
          현금
        %label.radio.inline
          %input{:type => 'radio', :name => 'l_payment_method', :value => '카드'}
          카드
        %label.radio.inline
          %input{:type => 'radio', :name => 'l_payment_method', :value => '현금+카드'}
          현금+카드
    .control-group
      .controls
        %button.btn.btn-success{:type => 'submit'} 반납
        %a.pull-right#btn-order-cancel.btn.btn-danger{:href => '#{url_for()}'} 주문취소

%p= include 'partial/satisfaction', s => $satisfaction


@@ orders/id/status_return.html.haml
- layout 'default', jses => ['orders-id.js'];
- title '주문확인 - 반납';

%p= include 'partial/status_label'
%div.pull-right= include 'guests/breadcrumb', guest => $order->guest, status_id => ''

- for my $cloth (@$clothes) {
  %p
    %a{:href => '/clothes/#{$cloth->no}'}= $cloth->category->name
    %small.highlight= commify($cloth->category->price)
- }

%div= include 'partial/order_info'
%p= commify($order->late_fee)
%p= $order->return_method
%p= '연체료 ' . commify($order->l_discount) . ' 원 할인'
%p= include 'partial/satisfaction', s => $satisfaction


@@ orders/id/status_partial_return.html.haml
- layout 'default', jses => ['orders-id.js'];
- title '주문확인 - 부분반납';

%p= include 'partial/status_label'
%div.pull-right= include 'guests/breadcrumb', guest => $order->guest, status_id => ''
#clothes-category
  %form#form-cloth-no
    %fieldset
      .input-append
        %input#input-cloth-no.input-large{:type => 'text', :placeholder => '품번'}
        %button#btn-cloth-no.btn{:type => 'button'} 입력
      - for my $cloth (@$clothes) {
        %label.checkbox
          - if ($cloth->status_id != $Opencloset::Constant::STATUS_PARTIAL_RETURN) {
            %input.input-cloth{:type => 'checkbox', :checked => 'checked', :data-cloth-no => '#{$cloth->no}'}
          - } else {
            %input.input-cloth{:type => 'checkbox', :data-cloth-no => '#{$cloth->no}'}
          - }
          %a{:href => '/clothes/#{$cloth->no}'}= $cloth->category->name
          %small.highlight= commify($cloth->category->price)
      - }
%div= include 'partial/order_info'
%p= commify($order->late_fee)
%p= $order->return_method
%form#form-return.form-horizontal{:method => 'post', :action => "#{url_for('')}"}
  %fieldset
    .control-group
      .controls
        %button.btn.btn-success{:type => 'submit'} 반납
%p= include 'partial/satisfaction', s => $satisfaction


@@ new-cloth.html.haml
- my $id   = 'new-cloth';
- my $meta = $sidebar->{meta};
- layout 'default',
-   active_id   => $id,
-   breadcrumbs => [
-     { text => $meta->{$id}{text} },
-   ],
-   jses => [
-     '/lib/bootstrap/js/fuelux/fuelux.wizard.min.js',
-   ];
- title $meta->{$id}{text};

#new-cloth
  .row-fluid
    .span12
      .widget-box
        .widget-header.widget-header-blue.widget-header-flat
          %h4.lighter 새 옷 등록

        .widget-body
          .widget-main
            /
            / step navigation
            /
            #fuelux-wizard.row-fluid{ "data-target" => '#step-container' }
              %ul.wizard-steps
                %li.active{ "data-target" => "#step1" }
                  %span.step  1
                  %span.title 기증자 검색
                %li{ "data-target" => "#step2" }
                  %span.step  2
                  %span.title 기증자 정보
                %li{ "data-target" => "#step3" }
                  %span.step  3
                  %span.title 새 옷 등록
                %li{ "data-target" => "#step4" }
                  %span.step  4
                  %span.title 등록 완료

            %hr

            #step-container.step-content.row-fluid.position-relative
              /
              / step1
              /
              #step1.step-pane.active
                %h3.lighter.block.green 새 옷을 기증해주신 분이 누구신가요?
                .form-horizontal
                  /
                  / 기증자 검색
                  /
                  .form-group.has-info
                    %label.control-label.no-padding-right.col-xs-12.col-sm-3 기증자 검색:
                    .col-xs-12.col-sm-9
                      .search
                        .input-group
                          %input#giver-search.form-control{ :name => 'giver-search' :type => 'text', :placeholder => '이름 또는 이메일, 휴대전화 번호' }
                          %span.input-group-btn
                            %button#btn-giver-search.btn.btn-default.btn-sm{ :type => 'submit' }
                              %i.icon-search.bigger-110 검색
                  /
                  / 기증자 선택
                  /
                  .form-group.has-info
                    %label.control-label.no-padding-right.col-xs-12.col-sm-3{ :for => "email" } 기증자 선택:
                    .col-xs-12.col-sm-9
                      #giver-search-list
                        %div
                          %label.blue
                            %input.ace.valid{ :name => 'giver-id', :type => 'radio', 'data-giver-id' => '0', :value => '0' }
                            %span.lbl= ' 기증자를 모릅니다.'
                      :plain
                        <script id="tpl-new-cloth-giver-id" type="text/html">
                          <div>
                            <label class="blue">
                              <input type="radio" class="ace valid" name="giver-id" value="<%= giver_id %>" data-giver-id="<%= giver_id %>">
                              <span class="lbl"> <%= giver_name %></span>
                            </label>
                          </div>
                        </script>
              /
              / step2
              /
              #step2.step-pane
                %h3.lighter.block.green 기증자의 정보를 입력하세요.
                %form#giver-info.form-horizontal{ :method => 'get' :novalidate="novalidate" }
                  /
                  / 이름
                  /
                  .form-group.has-info
                    %label.control-label.no-padding-right.col-xs-12.col-sm-3{ :for => 'giver-name' } 이름:
                    .col-xs-12.col-sm-9
                      .clearfix
                        %input#giver-name.valid.col-xs-12.col-sm-6{ :name => 'giver-name', :type => 'text' }

                  .space-2

                  /
                  / 전자우편
                  /
                  .form-group.has-info
                    %label.control-label.no-padding-right.col-xs-12.col-sm-3{ :for => 'giver-email' } 전자우편:
                    .col-xs-12.col-sm-9
                      .clearfix
                        %input#giver-email.valid.col-xs-12.col-sm-6{ :name => 'giver-email', :type => 'text' }

                  .space-2

                  /
                  / 나이
                  /
                  .form-group.has-info
                    %label.control-label.no-padding-right.col-xs-12.col-sm-3{ :for => 'giver-age' } 나이:
                    .col-xs-12.col-sm-9
                      .clearfix
                        %input#giver-age.valid.col-xs-12.col-sm-3{ :name => 'giver-age', :type => 'text' }

                  .space-2

                  /
                  / 성별
                  /
                  .form-group.has-info
                    %label.control-label.no-padding-right.col-xs-12.col-sm-3{ :for => 'giver-gender' } 성별:
                    .col-xs-12.col-sm-9
                      %div
                        %label.blue
                          %input.ace.valid{ :name => 'giver-gender', :type => 'radio', :value => '1' }
                          %span.lbl= ' 남자'
                      %div
                        %label.blue
                          %input.ace.valid{ :name => 'giver-gender', :type => 'radio', :value => '2' }
                          %span.lbl= ' 여자'

                  .space-2

                  /
                  / 휴대전화
                  /
                  .form-group.has-info
                    %label.control-label.no-padding-right.col-xs-12.col-sm-3{ :for => 'giver-phone' } 휴대전화:
                    .col-xs-12.col-sm-9
                      .clearfix
                        %input#giver-phone.valid.col-xs-12.col-sm-6{ :name => 'giver-phone', :type => 'text' }

                  .space-2

                  /
                  / 주소
                  /
                  .form-group.has-info
                    %label.control-label.no-padding-right.col-xs-12.col-sm-3{ :for => 'giver-address' } 주소:
                    .col-xs-12.col-sm-9
                      .clearfix
                        %input#giver-address.valid.col-xs-12.col-sm-8{ :name => 'giver-address', :type => 'text' }

              /
              / step3
              /
              #step3.step-pane
                %h3.lighter.block.green 새로운 옷의 종류와 치수를 입력하세요.

                .form-horizontal
                  .form-group.has-info
                    %label.control-label.no-padding-right.col-xs-12.col-sm-3{ :for => 'cloth-type' } 종류:
                    .col-xs-12.col-sm-6
                      %select#cloth-type{ :name => 'cloth-type', 'data-placeholder' => '옷의 종류를 선택하세요', :size => '14' }
                        %option{ :value => '-1' } Jacket & Pants
                        %option{ :value => '-2' } Jacket & Skirts
                        %option{ :value => '1'  } Jacket
                        %option{ :value => '2'  } Pants
                        %option{ :value => '3'  } Shirts
                        %option{ :value => '4'  } Shoes
                        %option{ :value => '5'  } Hat
                        %option{ :value => '6'  } Tie
                        %option{ :value => '7'  } Waistcoat
                        %option{ :value => '8'  } Coat
                        %option{ :value => '9'  } Onepiece
                        %option{ :value => '10' } Skirt
                        %option{ :value => '11' } Blouse

                  #display-cloth-color
                    .space-2

                    .form-group.has-info
                      %label.control-label.no-padding-right.col-xs-12.col-sm-3{ :for => 'cloth-color' } 색상:
                      .col-xs-12.col-sm-4
                        %select#cloth-color{ :name => 'cloth-color', 'data-placeholder' => '옷의 색상을 선택하세요', :size => '6' }
                          %option{ :value => 'B' } 검정(B)
                          %option{ :value => 'N' } 감청(N)
                          %option{ :value => 'G' } 회색(G)
                          %option{ :value => 'R' } 빨강(R)
                          %option{ :value => 'W' } 흰색(W)

                  #display-cloth-bust
                    .space-2

                    .form-group.has-info
                      %label.control-label.no-padding-right.col-xs-12.col-sm-3{ :for => 'cloth-bust' } 가슴:
                      .col-xs-12.col-sm-5
                        .input-group
                          %input#cloth-bust.valid.form-control{ :name => 'cloth-bust', :type => 'text' }
                          %span.input-group-addon
                            %i cm

                  #display-cloth-arm
                    .space-2

                    .form-group.has-info
                      %label.control-label.no-padding-right.col-xs-12.col-sm-3{ :for => 'cloth-arm' } 팔 길이:
                      .col-xs-12.col-sm-5
                        .input-group
                          %input#cloth-arm.valid.form-control{ :name => 'cloth-arm', :type => 'text' }
                          %span.input-group-addon
                            %i cm

                  #display-cloth-waist
                    .space-2

                    .form-group.has-info
                      %label.control-label.no-padding-right.col-xs-12.col-sm-3{ :for => 'cloth-waist' } 허리:
                      .col-xs-12.col-sm-5
                        .input-group
                          %input#cloth-waist.valid.form-control{ :name => 'cloth-waist', :type => 'text' }
                          %span.input-group-addon
                            %i cm

                  #display-cloth-hip
                    .space-2

                    .form-group.has-info
                      %label.control-label.no-padding-right.col-xs-12.col-sm-3{ :for => 'cloth-hip' } 엉덩이:
                      .col-xs-12.col-sm-5
                        .input-group
                          %input#cloth-hip.valid.form-control{ :name => 'cloth-hip', :type => 'text' }
                          %span.input-group-addon
                            %i cm

                  #display-cloth-length
                    .space-2

                    .form-group.has-info
                      %label.control-label.no-padding-right.col-xs-12.col-sm-3{ :for => 'cloth-length' } 기장:
                      .col-xs-12.col-sm-5
                        .input-group
                          %input#cloth-length.valid.form-control{ :name => 'cloth-length', :type => 'text' }
                          %span.input-group-addon
                            %i cm

                  #display-cloth-foot
                    .space-2

                    .form-group.has-info
                      %label.control-label.no-padding-right.col-xs-12.col-sm-3{ :for => 'cloth-foot' } 발 크기:
                      .col-xs-12.col-sm-5
                        .input-group
                          %input#cloth-foot.valid.form-control{ :name => 'cloth-foot', :type => 'text' }
                          %span.input-group-addon
                            %i mm

                  .form-group.has-info
                    %label.control-label.no-padding-right.col-xs-12.col-sm-3= ' '
                    .col-xs-12.col-sm-5
                      .input-group
                        %button#btn-cloth-reset.btn.btn-default 지움
                        %button#btn-cloth-add.btn.btn-primary 추가

                  .hr.hr-dotted

                  %form.form-horizontal{ :method => 'get', :novalidate => 'novalidate' }
                    .form-group.has-info
                      %label.control-label.no-padding-right.col-xs-12.col-sm-3 추가할 의류 선택:
                      .col-xs-12.col-sm-9
                        #display-cloth-list
                        :plain
                          <script id="tpl-new-cloth-cloth-item" type="text/html">
                            <div>
                              <label>
                                <input type="checkbox" class="ace valid" name="cloth-list"
                                  value="<%= [ cloth_type, cloth_color, cloth_bust, cloth_waist, cloth_hip, cloth_arm, cloth_length, cloth_foot ].join('-') %>"
                                  data-cloth-type="<%= cloth_type %>"
                                  data-cloth-color="<%= cloth_color %>"
                                  data-cloth-bust="<%= cloth_bust %>"
                                  data-cloth-arm="<%= cloth_arm %>"
                                  data-cloth-waist="<%= cloth_waist %>"
                                  data-cloth-hip="<%= cloth_hip %>"
                                  data-cloth-length="<%= cloth_length %>"
                                  data-cloth-foot="<%= cloth_foot %>"
                                />
                                <%
                                  var cloth_detail = []
                                  typeof yourvar != 'undefined'
                                  if ( typeof cloth_color != 'undefined') { cloth_detail.push( "색상("    + cloth_color_str + ")"   ) }
                                  if ( cloth_bust         >  0          ) { cloth_detail.push( "가슴("    + cloth_bust      + "cm)" ) }
                                  if ( cloth_arm          >  0          ) { cloth_detail.push( "팔 길이(" + cloth_arm       + "cm)" ) }
                                  if ( cloth_waist        >  0          ) { cloth_detail.push( "허리("    + cloth_waist     + "cm)" ) }
                                  if ( cloth_hip          >  0          ) { cloth_detail.push( "엉덩이("  + cloth_hip       + "cm)" ) }
                                  if ( cloth_length       >  0          ) { cloth_detail.push( "기장("    + cloth_length    + "cm)" ) }
                                  if ( cloth_foot         >  0          ) { cloth_detail.push( "발 크기(" + cloth_foot      + "mm)" ) }
                                %>
                                <span class="lbl"> &nbsp; <%= cloth_type_str %>: <%= cloth_detail.join(', ') %> </span>
                              </label>
                            </div>
                            <div class="space-4"></div>
                          </script>

              /
              / step4
              /
              #step4.step-pane
                %h3.lighter.block.green 등록이 완료되었습니다!

            %hr

            .wizard-actions.row-fluid
              %button.btn.btn-prev{ :disabled => "disabled" }
                %i.icon-arrow-left
                이전
              %button.btn.btn-next.btn-success{ "data-last" => "완료 " }
                다음
                %i.icon-arrow-right.icon-on-right


@@ layouts/default.html.haml
!!! 5
%html{:lang => "ko"}
  %head
    %title= title . ' - ' . $site->{name}
    = include 'layouts/default/meta'
    = include 'layouts/default/before-css'
    = include 'layouts/default/before-js'
    = include 'layouts/default/theme'
    = include 'layouts/default/css-page'
    = include 'layouts/default/after-css'
    = include 'layouts/default/after-js'

  %body
    = include 'layouts/default/navbar'
    #main-container.main-container
      .main-container-inner
        %a#menu-toggler.menu-toggler{:href => '#'}
          %span.menu-text
        = include 'layouts/default/sidebar'
        .main-content
          = include 'layouts/default/breadcrumbs'
          .page-content
            .page-header
              %h1
                = $sidebar->{meta}{$active_id}{text} // q{}
                %small
                  %i.icon-double-angle-right
                  = $sidebar->{meta}{$active_id}{desc} // q{}
            .row
              .col-xs-12
                / PAGE CONTENT BEGINS
                = content
                / PAGE CONTENT ENDS
    = include 'layouts/default/body-js'
    = include 'layouts/default/body-js-theme'
    = include 'layouts/default/body-js-page'


@@ layouts/default/meta.html.haml
/ META
    %meta{:charset => "utf-8"}
    %meta{:content => "width=device-width, initial-scale=1.0", :name => "viewport"}


@@ layouts/default/before-css.html.haml
/ CSS
    %link{:rel => "stylesheet", :href => "/lib/bootstrap/css/bootstrap.min.css"}
    %link{:rel => "stylesheet", :href => "/lib/font-awesome/css/font-awesome.min.css"}
    /[if IE 7]
      %link{:rel => "stylesheet", :href => "/lib/font-awesome/css/font-awesome-ie7.min.css"}
    %link{:rel => "stylesheet", :href => "/lib/prettify/css/prettify.css"}
    %link{:rel => "stylesheet", :href => "/lib/datepicker/css/datepicker.css"}
    %link{:rel => "stylesheet", :href => "/lib/select2/select2.css"}


@@ layouts/default/after-css.html.haml
/ CSS
    %link{:rel => "stylesheet", :href => "/css/font-nanum.css"}
    %link{:rel => "stylesheet", :href => "/css/screen.css"}


@@ layouts/default/before-js.html.haml
/ JS


@@ layouts/default/after-js.html.haml
/ JS
    /[if lt IE 9]>
      %script{:src => "/lib/html5shiv/html5shiv.min.js"}
      %script{:src => "/lib/respond/respond.min.js"}


@@ layouts/default/css-page.html.ep
<!-- css-page -->
    <!-- page specific -->
    % my @include_csses = @$csses;
    % #push @include_csses, "$active_id.css" if $active_id;
    % for my $css (@include_csses) {
    %   if ( $css =~ m{^/} ) {
          <link rel="stylesheet" href="<%= $css %>" />
    %   }
    %   else {
          <link rel="stylesheet" href="/css/<%= $css %>" />
    %   }
    % }


@@ layouts/default/body-js.html.ep
<!-- body-js -->
    <!-- Le javascript -->
    <!-- Placed at the end of the document so the pages load faster -->

    <!-- jQuery -->
    <!--[if !IE]> -->
      <script type="text/javascript">
        window.jQuery
          || document.write("<script src='/lib/jquery/js/jquery-2.0.3.min.js'>"+"<"+"/script>");
      </script>
    <!-- <![endif]-->

    <!--[if IE]>
      <script type="text/javascript">
        window.jQuery
          || document.write("<script src='/lib/jquery/js/jquery-1.10.2.min.js'>"+"<"+"/script>");
      </script>
    <![endif]-->

    <script type="text/javascript">
      if ("ontouchend" in document)
        document.write("<script src='/lib/jquery/js/jquery.mobile.custom.min.js'>"+"<"+"/script>");
    </script>

    <!-- bootstrap -->
    <script src="/lib/bootstrap/js/bootstrap.min.js"></script>
    <script src="/lib/bootstrap/js/bootstrap-tag.min.js"></script> <!-- tag -->

    <!--[if lte IE 8]>
      <script src="/lib/excanvas/excanvas.min.js"></script>
    <![endif]-->

    <!-- prettify -->
    <script src="/lib/prettify/js/prettify.js"></script>

    <!-- underscore -->
    <script src="/lib/underscore/underscore-min.js"></script>

    <!-- datepicker -->
    <script src="/lib/datepicker/js/bootstrap-datepicker.js"></script>
    <script src="/lib/datepicker/js/locales/bootstrap-datepicker.kr.js"></script>

    <!-- select2 -->
    <script src="/lib/select2/select2.min.js"></script>
    <script src="/lib/select2/select2_locale_ko.js"></script>

    <!-- bundle -->
    <script src="/js/bundle.js"></script>


@@ layouts/default/body-js-page.html.ep
<!-- body-js-page -->
    <!-- page specific -->
    % my @include_jses = @$jses;
    % push @include_jses, "$active_id.js" if $active_id;
    % for my $js (@include_jses) {
    %   if ( $js =~ m{^/} ) {
          <script type="text/javascript" src="<%= $js %>"></script>
    %   }
    %   else {
          <script type="text/javascript" src="/js/<%= $js %>"></script>
    %   }
    % }


@@ layouts/default/theme.html.ep
<!-- theme -->
    <link rel="stylesheet" href="/theme/<%= $theme %>/css/<%= $theme %>-fonts.css" />
    <link rel="stylesheet" href="/theme/<%= $theme %>/css/<%= $theme %>.min.css" />
    <link rel="stylesheet" href="/theme/<%= $theme %>/css/<%= $theme %>-rtl.min.css" />
    <link rel="stylesheet" href="/theme/<%= $theme %>/css/<%= $theme %>-skins.min.css" />
    <!--[if lte IE 8]>
      <link rel="stylesheet" href="/theme/<%= $theme %>/css/<%= $theme %>-ie.min.css" />
    <![endif]-->
    <script src="/theme/<%= $theme %>/js/<%= $theme %>-extra.min.js"></script>


@@ layouts/default/body-js-theme.html.ep
<!-- body js theme -->
    <script src="/theme/<%= $theme %>/js/<%= $theme %>-elements.min.js"></script>
    <script src="/theme/<%= $theme %>/js/<%= $theme %>.min.js"></script>


@@ layouts/default/navbar.html.ep
<!-- navbar -->
    <div class="navbar navbar-default" id="navbar">
      <div class="navbar-container" id="navbar-container">
        <div class="navbar-header pull-left">
          <a href="/" class="navbar-brand">
            <small> <i class="<%= $site->{icon} ? "icon-$site->{icon}" : q{} %>"></i> <%= $site->{name} %> </small>
          </a><!-- /.brand -->
        </div><!-- /.navbar-header -->

        <div class="navbar-header pull-right" role="navigation">
          <ul class="nav <%= $theme %>-nav">
            <li class="grey">
              <a data-toggle="dropdown" class="dropdown-toggle" href="#">
                <i class="icon-tasks"></i>
                <span class="badge badge-grey">4</span>
              </a>

              <ul class="pull-right dropdown-navbar dropdown-menu dropdown-caret dropdown-close">
                <li class="dropdown-header">
                  <i class="icon-ok"></i> 4 Tasks to complete
                </li>

                <li>
                  <a href="#">
                    <div class="clearfix">
                      <span class="pull-left">Software Update</span>
                      <span class="pull-right">65%</span>
                    </div>

                    <div class="progress progress-mini ">
                      <div style="width:65%" class="progress-bar "></div>
                    </div>
                  </a>
                </li>

                <li>
                  <a href="#">
                    <div class="clearfix">
                      <span class="pull-left">Hardware Upgrade</span>
                      <span class="pull-right">35%</span>
                    </div>

                    <div class="progress progress-mini ">
                      <div style="width:35%" class="progress-bar progress-bar-danger"></div>
                    </div>
                  </a>
                </li>

                <li>
                  <a href="#">
                    <div class="clearfix">
                      <span class="pull-left">Unit Testing</span>
                      <span class="pull-right">15%</span>
                    </div>

                    <div class="progress progress-mini ">
                      <div style="width:15%" class="progress-bar progress-bar-warning"></div>
                    </div>
                  </a>
                </li>

                <li>
                  <a href="#">
                    <div class="clearfix">
                      <span class="pull-left">Bug Fixes</span>
                      <span class="pull-right">90%</span>
                    </div>

                    <div class="progress progress-mini progress-striped active">
                      <div style="width:90%" class="progress-bar progress-bar-success"></div>
                    </div>
                  </a>
                </li>

                <li>
                  <a href="#">
                    See tasks with details
                    <i class="icon-arrow-right"></i>
                  </a>
                </li>

              </ul>

              </li> <!-- grey -->

              <li class="purple">
                <a data-toggle="dropdown" class="dropdown-toggle" href="#">
                  <i class="icon-bell-alt icon-animated-bell"></i>
                  <span class="badge badge-important">8</span>
                </a>

                <ul class="pull-right dropdown-navbar navbar-pink dropdown-menu dropdown-caret dropdown-close">
                  <li class="dropdown-header">
                    <i class="icon-warning-sign"></i>
                    8 Notifications
                  </li>

                  <li>
                    <a href="#">
                      <div class="clearfix">
                        <span class="pull-left">
                          <i class="btn btn-xs no-hover btn-pink icon-comment"></i>
                          New Comments
                        </span>
                        <span class="pull-right badge badge-info">+12</span>
                      </div>
                    </a>
                  </li>

                  <li>
                    <a href="#">
                      <i class="btn btn-xs btn-primary icon-user"></i>
                      Bob just signed up as an editor ...
                    </a>
                  </li>

                  <li>
                    <a href="#">
                      <div class="clearfix">
                        <span class="pull-left">
                          <i class="btn btn-xs no-hover btn-success icon-shopping-cart"></i>
                          New Orders
                        </span>
                        <span class="pull-right badge badge-success">+8</span>
                      </div>
                    </a>
                  </li>

                  <li>
                    <a href="#">
                      <div class="clearfix">
                        <span class="pull-left">
                          <i class="btn btn-xs no-hover btn-info icon-twitter"></i>
                          Followers
                        </span>
                        <span class="pull-right badge badge-info">+11</span>
                      </div>
                    </a>
                  </li>

                  <li>
                    <a href="#">
                      See all notifications
                      <i class="icon-arrow-right"></i>
                    </a>
                  </li>
                </ul>
                </li> <!-- purple -->

                <li class="green">
                  <a data-toggle="dropdown" class="dropdown-toggle" href="#">
                    <i class="icon-envelope icon-animated-vertical"></i>
                    <span class="badge badge-success">5</span>
                  </a>

                  <ul class="pull-right dropdown-navbar dropdown-menu dropdown-caret dropdown-close">
                    <li class="dropdown-header">
                      <i class="icon-envelope-alt"></i>
                      5 Messages
                    </li>

                    <li>
                      <a href="#">
                        <img src="https://pbs.twimg.com/profile_images/1814758551/keedi_bigger.jpg" class="msg-photo" alt="Alex's Avatar" />
                        <span class="msg-body">
                          <span class="msg-title">
                            <span class="blue">Alex:</span>
                            Ciao sociis natoque penatibus et auctor ...
                          </span>

                          <span class="msg-time">
                            <i class="icon-time"></i>
                            <span>a moment ago</span>
                          </span>
                        </span>
                      </a>
                    </li>

                    <li>
                      <a href="#">
                        <img src="https://pbs.twimg.com/profile_images/576748805/life.jpg" class="msg-photo" alt="Susan's Avatar" />
                        <span class="msg-body">
                          <span class="msg-title">
                            <span class="blue">Susan:</span>
                            Vestibulum id ligula porta felis euismod ...
                          </span>

                          <span class="msg-time">
                            <i class="icon-time"></i>
                            <span>20 minutes ago</span>
                          </span>
                        </span>
                      </a>
                    </li>

                    <li>
                      <a href="#">
                        <img src="https://pbs.twimg.com/profile_images/684939202/__0019_3441_.jpg" class="msg-photo" alt="Bob's Avatar" />
                        <span class="msg-body">
                          <span class="msg-title">
                            <span class="blue">Bob:</span>
                            Nullam quis risus eget urna mollis ornare ...
                          </span>

                          <span class="msg-time">
                            <i class="icon-time"></i>
                            <span>3:15 pm</span>
                          </span>
                        </span>
                      </a>
                    </li>

                    <li>
                      <a href="#">
                        <img src="https://pbs.twimg.com/profile_images/96856366/img_9494_doldolshadow.jpg" class="msg-photo" alt="Bob's Avatar" />
                        <span class="msg-body">
                          <span class="msg-title">
                            <span class="blue">Bob:</span>
                            Nullam quis risus eget urna mollis ornare ...
                          </span>

                          <span class="msg-time">
                            <i class="icon-time"></i>
                            <span>3:15 pm</span>
                          </span>
                        </span>
                      </a>
                    </li>

                    <li>
                      <a href="inbox.html">
                        See all messages
                        <i class="icon-arrow-right"></i>
                      </a>
                    </li>
                  </ul>
                </li> <!-- green -->

                <li class="light-blue">
                  <a data-toggle="dropdown" href="#" class="dropdown-toggle">
                    <img class="nav-user-photo" src="https://pbs.twimg.com/profile_images/1814758551/keedi_bigger.jpg" alt="Keedi's Photo" />
                    <span class="user-info"> <small>Welcome,</small> Keedi </span>
                    <i class="icon-caret-down"></i>
                  </a>

                  <ul class="user-menu pull-right dropdown-menu dropdown-yellow dropdown-caret dropdown-close">
                    <li> <a href="#"> <i class="icon-cog"></i> 설정 </a> </li>
                    <li> <a href="#"> <i class="icon-user"></i> 프로필 </a> </li>
                    <li class="divider"></li>
                    <li> <a href="#"> <i class="icon-off"></i> 로그아웃 </a> </li>
                  </ul>
                </li> <!-- light-blue -->

          </ul><!-- /.<%= $theme %>-nav -->
        </div><!-- /.navbar-header -->
      </div><!-- /.container -->
    </div>


@@ layouts/default/sidebar.html.ep
<!-- SIDEBAR -->
        <div class="sidebar" id="sidebar">
          <div class="sidebar-shortcuts" id="sidebar-shortcuts">
            <div class="sidebar-shortcuts-large" id="sidebar-shortcuts-large">
              <button class="btn btn-success"> <i class="icon-signal"></i> </button>
              <button class="btn btn-info"   > <i class="icon-pencil"></i> </button>
              <button class="btn btn-warning"> <i class="icon-group" ></i> </button>
              <button class="btn btn-danger" > <i class="icon-cogs"  ></i> </button>
            </div>

            <div class="sidebar-shortcuts-mini" id="sidebar-shortcuts-mini">
              <span class="btn btn-success"></span>
              <span class="btn btn-info"   ></span>
              <span class="btn btn-warning"></span>
              <span class="btn btn-danger" ></span>
            </div>
          </div><!-- #sidebar-shortcuts -->

          % my $menu = begin
          %   my ( $m, $items, $active_id, $level ) = @_;
          %   my $space = $level ? q{  } x ( $level * 2 ) : q{};
          %
          <%= $space %><ul class="<%= $level ? "submenu" : "nav nav-list" %>">
          %
          %   for my $item (@$items) {
          %     my $meta  = $sidebar->{meta}{$item->{id}};
          %     my $icon  = $meta->{icon} ? "icon-$meta->{icon}" : $level ? "icon-double-angle-right" : q{};
          %     my $link  = $meta->{link} // "/$item->{id}";
          %
          %     if ( $item->{id} eq $active_id ) {
          %       if ( $item->{items} ) {
          %
            <%= $space %><li class="active">
              <%= $space %><a href="<%= $link %>" class="dropdown-toggle">
                <%= $space %><i class="<%= $icon %>"></i>
                <%= $space %><span class="menu-text"> <%= $meta->{text} %> </span>
                <%= $space %><b class="arrow icon-angle-down"></b>
              <%= $space %></a>
              %== $m->( $m, $item->{items}, $active_id, $level + 1 );
            <%= $space %></li>
          %
          %       }
          %       else {
          %
            <%= $space %><li class="active">
              <%= $space %><a href="<%= $link %>">
                <%= $space %><i class="<%= $icon %>"></i>
                <%= $space %><span class="menu-text"> <%= $meta->{text} %> </span>
              <%= $space %></a>
            <%= $space %></li>
          %
          %       }
          %     }
          %     else {
          %       if ( $item->{items} ) {
          %
            <%= $space %><li>
              <%= $space %><a href="<%= $link %>" class="dropdown-toggle">
                <%= $space %><i class="<%= $icon %>"></i>
                <%= $space %><span class="menu-text"> <%= $meta->{text} %> </span>
                <%= $space %><b class="arrow icon-angle-down"></b>
              <%= $space %></a>
              %== $m->( $m, $item->{items}, $active_id, $level + 1 );
            <%= $space %></li>
          %
          %       }
          %       else {
          %
            <%= $space %><li>
              <%= $space %><a href="<%= $link %>">
                <%= $space %><i class="<%= $icon %>"></i>
                <%= $space %><span class="menu-text"> <%= $meta->{text} %> </span>
              <%= $space %></a>
            <%= $space %></li>
          %
          %       }
          %     }
          %   }
          %
          <%= $space %></ul> <!-- <%= $level ? "submenu" : "nav-list" %> -->
          %
          % end
          %
          %== $menu->( $menu, $sidebar->{items}, $active_id, 0 );
          %

          <div class="sidebar-collapse" id="sidebar-collapse">
            <i class="icon-double-angle-left" data-icon1="icon-double-angle-left" data-icon2="icon-double-angle-right"></i>
          </div>
        </div> <!-- sidebar -->


@@ layouts/default/breadcrumbs.html.ep
<!-- BREADCRUMBS -->
          <div class="breadcrumbs" id="breadcrumbs">
            <ul class="breadcrumb">
            % if (@$breadcrumbs) {
              <li> <i class="icon-home home-icon"></i> <a href="/"><%= $sidebar->{meta}{home}{text} %></a> </li>
            %   for my $i ( 0 .. $#$breadcrumbs ) {
            %     my $b = $breadcrumbs->[$i];
            %     if ( $i < $#$breadcrumbs ) {
            %       if ( $b->{link} ) {
              <li> <a href="<%= $b->{link} %>"><%= $b->{text} %></a> </li>
            %       }
            %       else {
              <li> <%= $b->{text} %> </li>
            %       }
            %     }
            %     else {
              <li class="active"> <%= $b->{text} %> </li>
            %     }
            %   }
            % }
            % else {
              <li class="active"> <i class="icon-home home-icon"></i> <a href="/"><%= $sidebar->{meta}{home}{text} %></a> </li>
            % }
            </ul><!-- .breadcrumb -->

            <div class="nav-search" id="nav-search">
              <form class="form-search">
                <span class="input-icon">
                  <input type="text" placeholder="검색 ..." class="nav-search-input" id="nav-search-input" autocomplete="off" />
                  <i class="icon-search nav-search-icon"></i>
                </span>
              </form>
            </div><!-- #nav-search -->
          </div> <!-- breadcrumbs -->


@@ not_found.html.ep
% layout 'error',
%   breadcrumbs => [
%     { text => 'Other Pages' },
%     { text => 'Error 404' },
%   ];
% title '404 Error Page';
<!-- 404 NOT FOUND -->
                <div class="error-container">
                  <div class="well">
                    <h1 class="grey lighter smaller">
                      <span class="blue bigger-125">
                        <i class="icon-sitemap"></i>
                        404
                      </span>
                      Page Not Found
                    </h1>

                    <hr />
                    <h3 class="lighter smaller">We looked everywhere but we couldn't find it!</h3>

                    <div>
                      <form class="form-search">
                        <span class="input-icon align-middle">
                          <i class="icon-search"></i>

                          <input type="text" class="search-query" placeholder="Give it a search..." />
                        </span>
                        <button class="btn btn-sm" onclick="return false;">Go!</button>
                      </form>

                      <div class="space"></div>
                      <h4 class="smaller">Try one of the following:</h4>

                      <ul class="list-unstyled spaced inline bigger-110 margin-15">
                        <li>
                          <i class="icon-hand-right blue"></i>
                          Re-check the url for typos
                        </li>

                        <li>
                          <i class="icon-hand-right blue"></i>
                          Read the faq
                        </li>

                        <li>
                          <i class="icon-hand-right blue"></i>
                          Tell us about it
                        </li>
                      </ul>
                    </div>

                    <hr />
                    <div class="space"></div>

                    <div class="center">
                      <a href="#" class="btn btn-grey">
                        <i class="icon-arrow-left"></i>
                        Go Back
                      </a>

                      <a href="#" class="btn btn-primary">
                        <i class="icon-dashboard"></i>
                        Dashboard
                      </a>
                    </div>
                  </div>
                </div>


@@ exception.html.ep
% layout 'error',
%   breadcrumbs => [
%     { text => 'Other Pages' },
%     { text => 'Error 500' },
%   ];
% title '500 Error Page';
<!-- 500 EXCEPTIONS -->
                <div class="error-container">
                  <div class="well">
                    <h1 class="grey lighter smaller">
                      <span class="blue bigger-125">
                        <i class="icon-random"></i>
                        500
                      </span>
                      <%= $exception->message %>
                    </h1>

                    <hr />
                    <h3 class="lighter smaller">
                      But we are working
                      <i class="icon-wrench icon-animated-wrench bigger-125"></i>
                      on it!
                    </h3>

                    <div class="space"></div>

                    <div>
                      <h4 class="lighter smaller">Meanwhile, try one of the following:</h4>

                      <ul class="list-unstyled spaced inline bigger-110 margin-15">
                        <li>
                          <i class="icon-hand-right blue"></i>
                          Read the faq
                        </li>

                        <li>
                          <i class="icon-hand-right blue"></i>
                          Give us more info on how this specific error occurred!
                        </li>
                      </ul>
                    </div>

                    <hr />
                    <div class="space"></div>

                    <div class="center">
                      <a href="#" class="btn btn-grey">
                        <i class="icon-arrow-left"></i>
                        Go Back
                      </a>

                      <a href="#" class="btn btn-primary">
                        <i class="icon-dashboard"></i>
                        Dashboard
                      </a>
                    </div>
                  </div>
                </div>


@@ layouts/login.html.haml
!!! 5
%html
  %head
    %title= title . ' - ' . $site->{name}
    = include 'layouts/default/meta'
    = include 'layouts/default/before-css'
    = include 'layouts/default/before-js'
    = include 'layouts/default/theme'
    = include 'layouts/default/css-page'
    = include 'layouts/default/after-css'
    = include 'layouts/default/after-js'

  %body.login-layout
    .main-container
      .main-content
        .row
          .col-sm-10.col-sm-offset-1
            .login-container
              .center
                %h1
                  != $site->{icon} ? qq[<i class="icon-$site->{icon} orange"></i>] : q{};
                  %span.white= $site->{name}
              .center
                %h1
                %h4.blue= "&copy; $company_name"
              .space-6
              .position-relative
                = include 'layouts/login/login-box'
                = include 'layouts/login/forgot-box'
                = include 'layouts/login/signup-box'
    = include 'layouts/default/body-js'
    = include 'layouts/default/body-js-theme'
    = include 'layouts/default/body-js-page'


@@ layouts/login/login-box.html.ep
<!-- LOGIN-BOX -->
                <div id="login-box" class="login-box visible widget-box no-border">
                  <div class="widget-body">
                    <div class="widget-main">
                      <h4 class="header blue lighter bigger">
                        <i class="icon-lock green"></i>
                        정보를 입력해주세요.
                      </h4>

                      <div class="space-6"></div>

                      <form>
                        <fieldset>
                          <label class="block clearfix">
                            <span class="block input-icon input-icon-right">
                              <input type="text" class="form-control" placeholder="사용자 이름" />
                              <i class="icon-user"></i>
                            </span>
                          </label>

                          <label class="block clearfix">
                            <span class="block input-icon input-icon-right">
                              <input type="password" class="form-control" placeholder="비밀번호" />
                              <i class="icon-key"></i>
                            </span>
                          </label>

                          <div class="space"></div>

                          <div class="clearfix">
                            <label class="inline">
                              <input type="checkbox" class="<%= $theme %>" />
                              <span class="lbl"> 기억하기</span>
                            </label>

                            <button type="button" class="width-35 pull-right btn btn-sm btn-primary">
                              <i class="icon-unlock"></i>
                              로그인
                            </button>
                          </div>

                          <div class="space-4"></div>
                        </fieldset>
                      </form>
                    </div><!-- /widget-main -->

                    <div class="toolbar clearfix">
                      <div>
                        <a href="#" onclick="show_box('forgot-box'); return false;" class="forgot-password-link">
                          <i class="icon-arrow-left"></i>
                          암호를 잊어버렸어요
                        </a>
                      </div>

                      <div>
                        <a href="#" onclick="show_box('signup-box'); return false;" class="user-signup-link">
                          가입할래요
                          <i class="icon-arrow-right"></i>
                        </a>
                      </div>
                    </div>
                  </div><!-- /widget-body -->
                </div><!-- /login-box -->


@@ layouts/login/forgot-box.html.ep
<!-- FORGOT-BOX -->
                <div id="forgot-box" class="forgot-box widget-box no-border">
                  <div class="widget-body">
                    <div class="widget-main">
                      <h4 class="header red lighter bigger">
                        <i class="icon-key"></i>
                        비밀번호를 초기화합니다.
                      </h4>

                      <div class="space-6"></div>
                      <p>
                        비밀번호를 새로 설정하는 방법을 이메일로 전달드립니다.
                        이메일 주소를 입력하세요.
                      </p>

                      <form>
                        <fieldset>
                          <label class="block clearfix">
                            <span class="block input-icon input-icon-right">
                              <input type="email" class="form-control" placeholder="이메일" />
                              <i class="icon-envelope"></i>
                            </span>
                          </label>

                          <div class="clearfix">
                            <button type="button" class="width-35 pull-right btn btn-sm btn-danger">
                              <i class="icon-lightbulb"></i>
                              보내주세요!
                            </button>
                          </div>
                        </fieldset>
                      </form>
                    </div><!-- /widget-main -->

                    <div class="toolbar center">
                      <a href="#" onclick="show_box('login-box'); return false;" class="back-to-login-link">
                        로그인 페이지로 돌아가기
                        <i class="icon-arrow-right"></i>
                      </a>
                    </div>
                  </div><!-- /widget-body -->
                </div><!-- /forgot-box -->


@@ layouts/error.html.haml
!!! 5
%html
  %head
    %title= title . ' - ' . $site->{name}
    = include 'layouts/default/meta'
    = include 'layouts/default/before-css'
    = include 'layouts/default/before-js'
    = include 'layouts/default/theme'
    = include 'layouts/default/after-css'
    = include 'layouts/default/after-js'

  %body
    = include 'layouts/default/navbar'
    #main-container.main-container
      .main-container-inner
        %a#menu-toggler.menu-toggler{:href = '#'}
          %span.menu-text
        = include 'layouts/default/sidebar'
        .main-content
          = include 'layouts/default/breadcrumbs'
          .page-content
            .row
              .col-xs-12
                / PAGE CONTENT BEGINS
                = content
                / PAGE CONTENT ENDS
    = include 'layouts/default/body-js'
    = include 'layouts/default/body-theme'


@@ layouts/login/signup-box.html.ep
<!-- SIGNUP-BOX -->
                <div id="signup-box" class="signup-box widget-box no-border">
                  <div class="widget-body">
                    <div class="widget-main">
                      <h4 class="header green lighter bigger">
                        <i class="icon-group blue"></i>
                        새로운 사용자 등록하기
                      </h4>

                      <div class="space-6"></div>
                      <p> 등록을 위해 다음 내용을 입력해주세요. </p>

                      <form>
                        <fieldset>
                          <label class="block clearfix">
                            <span class="block input-icon input-icon-right">
                              <input type="email" class="form-control" placeholder="이메일" />
                              <i class="icon-envelope"></i>
                            </span>
                          </label>

                          <label class="block clearfix">
                            <span class="block input-icon input-icon-right">
                              <input type="text" class="form-control" placeholder="사용자 이름" />
                              <i class="icon-user"></i>
                            </span>
                          </label>

                          <label class="block clearfix">
                            <span class="block input-icon input-icon-right">
                              <input type="password" class="form-control" placeholder="비밀번호" />
                              <i class="icon-lock"></i>
                            </span>
                          </label>

                          <label class="block clearfix">
                            <span class="block input-icon input-icon-right">
                              <input type="password" class="form-control" placeholder="비밀번호 확인" />
                              <i class="icon-retweet"></i>
                            </span>
                          </label>

                          <label class="block">
                            <input type="checkbox" class="<%= $theme %>" />
                            <span class="lbl">
                              <a href="#">사용자 약관</a>에 동의합니다.
                            </span>
                          </label>

                          <div class="space-24"></div>

                          <div class="clearfix">
                            <button type="reset" class="width-30 pull-left btn btn-sm">
                              <i class="icon-refresh"></i>
                              새로 쓰기
                            </button>

                            <button type="button" class="width-65 pull-right btn btn-sm btn-success">
                              등록하기
                              <i class="icon-arrow-right icon-on-right"></i>
                            </button>
                          </div>
                        </fieldset>
                      </form>
                    </div>

                    <div class="toolbar center">
                      <a href="#" onclick="show_box('login-box'); return false;" class="back-to-login-link">
                        <i class="icon-arrow-left"></i>
                        로그인 페이지로 돌아가기
                      </a>
                    </div>
                  </div><!-- /widget-body -->
                </div><!-- /signup-box -->
