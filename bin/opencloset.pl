#!/usr/bin/env perl

use Mojolicious::Lite;

use Data::Pageset;
use DateTime;
use Try::Tiny;

use Opencloset::Constant;
use Opencloset::Schema;

plugin 'validator';
plugin 'haml_renderer';
plugin 'FillInFormLite';

app->defaults( %{ plugin 'Config' => { default => {
    jses        => [],
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

helper clothe2hr => sub {
    my ($self, $clothe) = @_;

    return {
        $clothe->get_columns,
        donor    => $clothe->donor ? $clothe->donor->name : '',
        category => $clothe->category->name,
        price    => $self->commify($clothe->category->price),
        status   => $clothe->status->name,
    };
};

helper order2hr => sub {
    my ($self, $order) = @_;

    my @clothes;
    for my $clothe ($order->clothes) {
        push @clothes, $self->clothe2hr($clothe);
    }

    return {
        $order->get_columns,
        clothes => [@clothes],
    };
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

helper create_guest => sub {
    my $self = shift;

    my %params;
    map { $params{$_} = $self->param($_) } qw/name gender phone address age email purpose height weight/;

    return $DB->resultset('Guest')->find_or_create(\%params);
};

helper create_donor => sub {
    my $self = shift;

    my %params;
    map { $params{$_} = $self->param($_) } qw/name phone email comment/;

    return $DB->resultset('Donor')->find_or_create(\%params);
};

helper create_clothe => sub {
    my ($self, $category_id) = @_;

    ## generate no
    my $category = $DB->resultset('Category')->find({ id => $category_id });
    return unless $category;

    my $clothe = $DB->resultset('Clothe')->search({
        category_id => $category_id
    }, {
        order_by => { -desc => 'no' }
    })->next;

    my %prefix_map = (
        1 => 'Jck',
        2 => 'Pts',
        3 => 'Shr',
        4 => 'Sho',
        5 => 'Hat',
        6 => 'Tie'
    );

    my $index = 1;
    if ($clothe) {
        $index = substr $clothe->no, -5, 5;
        $index =~ s/^0+//;
        $index++;
    }

    my $no = sprintf "%s%05d", $prefix_map{$category_id}, $index;

    my %params;
    if ($category_id == 1) {
        map { $params{$_} = $self->param($_) } qw/chest arm/;       # Jacket
    } elsif ($category_id == 2) {
        map { $params{$_} = $self->param($_) } qw/waist pants_len/; # Pants
    }

    $params{no}          = $no;
    $params{donor_id}    = $self->param('donor_id');
    $params{category_id} = $category_id;
    $params{status_id}   = 1;

    return $DB->resultset('Clothe')->find_or_create(\%params);
};

get '/' => 'home';

get '/new-borrower' => sub {
    my $self = shift;

    my $q      = $self->param('q') || '';
    my $guests = $DB->resultset('Guest')->search({
        -or => [
            id    => $q,
            name  => $q,
            phone => $q,
            email => $q
        ],
    });

    $self->stash( candidates => $guests );
} => 'new-borrower';

post '/guests' => sub {
    my $self = shift;

    my $validator = $self->create_validator;
    $validator->field('name')->required(1);
    $validator->field('phone')->regexp(qr/^\d{10,11}$/);
    $validator->field('email')->email;

    return $self->error(400, 'invalid request')
        unless $self->validate($validator);

    my $guest = $self->create_guest;
    return $self->error(500, 'failed to create a new guest') unless $guest;

    $self->res->headers->header('Location' => $self->url_for('/guests/' . $guest->id));
    $self->respond_to(
        json => { json => { $guest->get_columns }, status => 201 },
        html => sub {
            $self->redirect_to('/guests/' . $guest->id . '/size');
        }
    );
};

get '/guests/:id' => sub {
    my $self   = shift;
    my $guest  = $DB->resultset('Guest')->find({ id => $self->param('id') });
    my @orders = $DB->resultset('Order')->search({
        guest_id => $self->param('id')
    }, {
        order_by => { -desc => 'rental_date' }
    });
    $self->stash(
        guest  => $guest,
        orders => [@orders],
    );
} => 'guests/id';

get '/guests/:id/size' => sub {
    my $self  = shift;
    my $guest = $DB->resultset('Guest')->find({ id => $self->param('id') });
    $self->stash(guest => $guest);
    $self->render_fillinform({ $guest->get_columns });
} => 'guests/size';

post '/guests/:id/size' => sub {
    my $self  = shift;

    my $validator = $self->create_validator;
    my @fields = qw/chest waist arm pants_len/;
    $validator->field([@fields])
        ->each(sub { shift->required(1)->regexp(qr/^\d+$/) });

    return $self->error(400, 'failed to validate')
        unless $self->validate($validator);

    my $guest = $DB->resultset('Guest')->find({ id => $self->param('id') });
    map { $guest->$_($self->param($_)) } @fields;
    $guest->update;
    my ($chest, $waist) = ($guest->chest + 3, $guest->waist);
    $self->respond_to(
        json => { json => { $guest->get_columns } },
        html => sub {
            $self->redirect_to(
                # ignore $guest->arm for wide search result
                $self->url_for('/search')
                    ->query(q => "$chest/$waist//1", gid => $guest->id)
            );
        }
    );
};

post '/clothes' => sub {
    my $self = shift;
    my $validator = $self->create_validator;
    $validator->field('category_id')->required(1);
    # Jacket
    $validator->when('category_id')->regexp(qr/^-?1$/)
        ->then(sub { shift->field('chest')->required(1) });
    $validator->when('category_id')->regexp(qr/^-?1$/)
        ->then(sub { shift->field('arm')->required(1) });

    # Pants
    $validator->when('category_id')->regexp(qr/^(-1|2)$/)
        ->then(sub { shift->field('waist')->required(1) });
    $validator->when('category_id')->regexp(qr/^(-1|2)$/)
        ->then(sub { shift->field('pants_len')->required(1) });

    my @fields = qw/chest waist arm pants_len/;
    $validator->field([@fields])
        ->each(sub { shift->required(1)->regexp(qr/^\d+$/) });

    unless ($self->validate($validator)) {
        my $errors_hashref = $validator->errors;
        return $self->error(400, 'invalid request')
    }

    my $cid      = $self->param('category_id');
    my $donor_id = $self->param('donor_id');

    my $clothe;
    my $guard = $DB->txn_scope_guard;
    # BEGIN TRANSACTION ~
    if ($cid == -1) {
        my $top = $self->create_clothe(1);
        my $bot = $self->create_clothe(2);
        return $self->error(500, 'failed to create a new clothe') unless ($top && $bot);

        if ($donor_id) {
            $top->create_related('donor_clothes', { donor_id => $donor_id });
            $bot->create_related('donor_clothes', { donor_id => $donor_id });
        }
        $top->bottom_id($bot->id);
        $bot->top_id($top->id);
        $top->update;
        $bot->update;
        $clothe = $top;
    } else {
        $clothe = $self->create_clothe($cid);
        return $self->error(500, 'failed to create a new clothe') unless $clothe;

        if ($donor_id) {
            $clothe->create_related('donor_clothes', { donor_id => $donor_id });
        }
    }
    # ~ COMMIT
    $guard->commit;

    $self->res->headers->header('Location' => $self->url_for('/clothes/' . $clothe->no));
    $self->respond_to(
        json => { json => $self->clothe2hr($clothe), status => 201 },
        html => sub {
            $self->redirect_to('/clothes/' . $clothe->no);
        }
    );
};

put '/clothes' => sub {
    my $self = shift;
    my $clothes = $self->param('clothes');
    return $self->error(400, 'Nothing to change') unless $clothes;

    my $status = $DB->resultset('Status')->find({ name => $self->param('status') });
    return $self->error(400, 'Invalid status') unless $status;

    my $rs    = $DB->resultset('Clothe')->search({ 'me.id' => { -in => [split(/,/, $clothes)] } });
    my $guard = $DB->txn_scope_guard;
    my @rows;
    # BEGIN TRANSACTION ~
    while (my $clothe = $rs->next) {
        $clothe->status_id($status->id);
        $clothe->update;
        push @rows, { $clothe->get_columns };
    }
    # ~ COMMIT
    $guard->commit;

    $self->respond_to(
        json => { json => [@rows] },
        html => { template => 'clothes' }    # TODO: `clothe.html.haml`
    );
};

get '/clothes/new' => sub {
    my $self   = shift;
    my $q      = $self->param('q') || '';
    my $donors = [$DB->resultset('Donor')->search({
        -or => [
            id    => $q,
            name  => $q,
            phone => $q,
            email => $q
        ],
    })];

    my @categories = $DB->resultset('Category')->search;

    $self->render(
        'clothes/new',
        donors     => $donors,
        categories => [@categories],
    );
} => 'clothes/new';

get '/clothes/:no' => sub {
    my $self = shift;
    my $no = $self->param('no');
    my $clothe = $DB->resultset('Clothe')->find({ no => $no });
    return $self->error(404, "Not found `$no`") unless $clothe;

    my $co_rs = $clothe->clothe_orders->search(
        { 'order.status_id' => $Opencloset::Constant::STATUS_RENT }, { join => 'order' }
    )->next;

    unless ($co_rs) {
        $self->respond_to(
            json => { json => $self->clothe2hr($clothe) },
            html => { template => 'clothes/no', clothe => $clothe }    # also, CODEREF is OK
        );
        return;
    }

    my @with;
    my $order = $co_rs->order;
    for my $_clothe ($order->clothes) {
        next if $_clothe->id == $clothe->id;
        push @with, $self->clothe2hr($_clothe);
    }

    my $overdue = $self->overdue_calc($order->target_date, DateTime->now);
    my %columns = (
        %{ $self->clothe2hr($clothe) },
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
        html => { template => 'clothes/no', clothe => $clothe }    # also, CODEREF is OK
    );
};

get '/search' => sub {
    my $self  = shift;
    my $q     = $self->param('q')   || '';
    my $gid   = $self->param('gid') || '';
    my $guest = $gid ? $DB->resultset('Guest')->find({ id => $gid }) : undef;

    my $c_jacket = $DB->resultset('Category')->find({ name => 'jacket' });
    my $cond = { 'me.category_id' => $c_jacket->id };
    my ($chest, $waist, $arm, $status_id) = split /\//, $q;
    $cond->{'me.chest'}     = { '>=' => $chest } if $chest;
    $cond->{'bottom.waist'} = { '>=' => $waist } if $waist;
    $cond->{'me.arm'}       = { '>=' => $arm   } if $arm;
    $cond->{'me.status_id'} = $status_id if $status_id;

    ### row, current_page, count
    my $ENTRIES_PER_PAGE = 10;
    my $clothes = $DB->resultset('Clothe')->search(
        $cond,
        {
            page     => $self->param('p') || 1,
            rows     => $ENTRIES_PER_PAGE,
            order_by => [qw/chest bottom.waist arm/],
            join     => 'bottom',
        }
    );

    my $pageset = Data::Pageset->new({
        total_entries    => $clothes->pager->total_entries,
        entries_per_page => $ENTRIES_PER_PAGE,
        current_page     => $self->param('p') || 1,
        mode             => 'fixed'
    });

    $self->render(
        'search',
        guest     => $guest,
        clothes   => $clothes,
        pageset   => $pageset,
        status_id => $status_id || '',
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
            id    => $q,
            name  => $q,
            phone => $q,
            email => $q
        ],
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
    $validator->field([qw/gid clothe-id/])
        ->each(sub { shift->required(1)->regexp(qr/^\d+$/) });

    return $self->error(400, 'failed to validate')
        unless $self->validate($validator);

    my $guest   = $DB->resultset('Guest')->find({ id => $self->param('gid') });
    my @clothes = $DB->resultset('Clothe')->search({ 'me.id' => { -in => [$self->param('clothe-id')] } });

    return $self->error(400, 'invalid request') unless $guest || @clothes;

    my $guard = $DB->txn_scope_guard;
    my $order;
    try {
        # BEGIN TRANSACTION ~
        $order = $DB->resultset('Order')->create({
            guest_id  => $guest->id,
        });

        for my $clothe (@clothes) {
            $order->create_related('clothe_orders', { clothe_id => $clothe->id });
        }
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

get '/orders/:id' => sub {
    my $self = shift;

    my $order = $DB->resultset('Order')->find({ id => $self->param('id') });
    return $self->error(404, "Not found") unless $order;

    my @clothes = $order->clothes;
    my $price = 0;
    for my $clothe (@clothes) {
        $price += $clothe->category->price;
    }

    my $overdue  = $order->target_date ? $self->overdue_calc($order->target_date, DateTime->now()) : 0;
    my $late_fee = $order->price * 0.2 * $overdue;

    my $c_jacket = $DB->resultset('Category')->find({ name => 'jacket' });
    my $cond = { category_id => $c_jacket->id };
    my $clothe = $order->clothes($cond)->next;

    my $satisfaction;
    if ($clothe) {
        $satisfaction = $clothe->satisfactions({
            clothe_id => $clothe->id,
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

    $self->stash(template => 'orders/id/nil_status');
    $self->stash(template => 'orders/id') if ($order->status);
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
    } qw/price discount target_date comment return_method late_fee l_discount payment_method/;
    my %status_to_be = (
        0 => $Opencloset::Constant::STATUS_RENT,
        $Opencloset::Constant::STATUS_RENT => $Opencloset::Constant::STATUS_RETURN,
        # TODO: consider `분실`
    );

    my $guard = $DB->txn_scope_guard;
    # BEGIN TRANSACTION ~
    my $status_id = $status_to_be{$order->status_id || 0};
    $order->status_id($status_id);
    my $dt_parser = $DB->storage->datetime_parser;
    $order->return_date($dt_parser->format_datetime(DateTime->now()))
        if $status_id == $Opencloset::Constant::STATUS_RETURN;
    $order->rental_date($dt_parser->format_datetime(DateTime->now))
        if $status_id == $Opencloset::Constant::STATUS_RENT;
    $order->update;

    for my $clothe ($order->clothes) {
        if ($order->status_id == $Opencloset::Constant::STATUS_RENT) {
            $clothe->status_id($Opencloset::Constant::STATUS_RENT);
        } else {
            if ($clothe->category_id == $Opencloset::Constant::CATEOGORY_SHOES) {
                $clothe->status_id($Opencloset::Constant::STATUS_AVAILABLE);    # Shoes
            } else {
                $clothe->status_id($Opencloset::Constant::STATUS_WASHING);    # otherwise
            }
        }
        $clothe->update;
    }
    $guard->commit;
    # ~ COMMIT

    my %satisfaction;
    map { $satisfaction{$_} = $self->param($_) } qw/chest waist arm top_fit bottom_fit/;

    if (values %satisfaction) {
        # $order
        my $c_jacket = $DB->resultset('Category')->find({ name => 'jacket' });
        my $cond = { category_id => $c_jacket->id };
        my $clothe = $order->clothes($cond)->next;
        if ($clothe) {
            $DB->resultset('Satisfaction')->update_or_create({
                %satisfaction,
                guest_id  => $order->guest_id,
                clothe_id => $clothe->id,
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

    for my $clothe ($order->clothes) {
        $clothe->status_id($Opencloset::Constant::STATUS_AVAILABLE);
        $clothe->update;
    }

    $order->delete;

    $self->respond_to(
        json => { json => {} },    # just 200 OK
    );
};

get '/donors/new' => sub {
    my $self   = shift;
    my $q      = $self->param('q') || '';
    my $donors = $DB->resultset('Donor')->search({
        -or => [
            id    => $q,
            name  => $q,
            phone => $q,
            email => $q
        ],
    });

    $self->render('donors/new', candidates => $donors);
};

post '/donors' => sub {
    my $self   = shift;
    my $validator = $self->create_validator;
    $validator->field('name')->required(1);
    $validator->field('phone')->regexp(qr/^\d{10,11}$/);
    $validator->field('email')->email;

    return $self->error(400, 'invalid request')
        unless $self->validate($validator);

    my $donor = $self->create_donor;
    return $self->error(500, 'failed to create a new donor') unless $donor;

    $self->res->headers->header('Location' => $self->url_for('/donors/' . $donor->id));
    $self->respond_to(
        json => { json => { $donor->get_columns }, status => 201 },
        html => sub {
            $self->redirect_to(
                $self->url_for('/clothes/new')->query->([q => $donor->id])
            );
        }
    );
};

app->start;

__DATA__

@@ home.html.haml
- my $id   = 'home';
- my $meta = $sidebar->{meta};
- layout 'default', active_id => $id;
- title $meta->{$id}{text};

%form#clothe-search-form.form-inline
  .input-append
    %input#clothe-id.input-large{:type => 'text', :placeholder => '품번'}
    %button#btn-clothe-search.btn{:type => 'button'} 검색
  %button#btn-clear.btn{:type => 'button'} Clear

#clothes-list
  %ul
  #action-buttons{:style => 'display: none'}
    %span 선택한 항목을
    %button.btn.btn-mini{:type => 'button', :data-status => '세탁'} 세탁
    %button.btn.btn-mini{:type => 'button', :data-status => '대여가능'} 대여가능
    %button.btn.btn-mini{:type => 'button', :data-status => '분실'} 분실
    %span (으)로 변경 합니다

:plain
  <script id="tpl-row" type="text/html">
    <li data-order-id="<%= order_id %>">
      <label>
        <a class="btn btn-success btn-mini" href="/orders/<%= order_id %>">주문서</a>
        <a href="/clothes/<%= no %>"><%= category %></a>
        <span class="order-status label"><%= status %></span> with
        <% _.each(clothes, function(clothe) { %> <a href="/clothes/<%= clothe.no %>"><%= clothe.category %></a><% }); %>
        <a class="history-link" href="/orders/<%= order_id %>">
          <time class="js-relative-date" datetime="<%= rental_date.raw %>" title="<%= rental_date.ymd %>"><%= rental_date.md %></time>
          ~
          <time class="js-relative-date" datetime="<%= target_date.raw %>" title="<%= target_date.ymd %>"><%= target_date.md %></time>
        </a>
      </label>
    </li>
  </script>

:plain
  <script id="tpl-overdue-paragraph" type="text/html">
    <p class="muted">
      연체료 <span class="text-error"><%= late_fee %></span> 는 연체일(<%= overdue %>) x 대여금액(<%= price %>)의 20% 로 계산됩니다.
    </p>
  </script>

:plain
  <script id="tpl-row-checkbox" type="text/html">
    <li class="row-checkbox" data-clothe-id="<%= id %>">
      <label class="checkbox">
        <input type="checkbox" checked="checked" data-clothe-id="<%= id %>">
        <a href="/clothes/<%= no %>"><%= category %></a>
        <span class="order-status label"><%= status %></span>
      </label>
    </li>
  </script>


@@ new-borrower.html.haml
- my $id   = 'new-borrower';
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

%ul
  - while(my $g = $candidates->next) {
  %li
    %a{:href => "/guests/#{$g->id}/size"} #{$g->name} (#{$g->email})
    %p.muted
      %span= $g->address
      - if ($g->visit_date) {
        %time , #{$g->visit_date->ymd} #{$g->purpose} (으)로 방문
      - }
  - }

%p.text-warning
  %strong 작성하시기전, 직원에게 언제 입으실 건지 알려주세요

%form.form-horizontal{:method => 'post', :action => '/guests'}
  %legend
    대여자 기본 정보
  .control-group
    %label.control-label{:for => 'input-name'} 이름
    .controls
      %input{:type => 'text', :id => 'input-name', :name => 'name'}
  .control-group
    %label.control-label 성별
    .controls
      %label.radio.inline
        %input{:type => 'radio', :name => 'gender', :value => '1'}
          남
      %label.radio.inline
        %input{:type => 'radio', :name => 'gender', :value => '2'}
          여
  .control-group
    %label.control-label{:for => 'input-phone'} 휴대폰
    .controls
      %input{:type => 'text', :id => 'input-phone', :name => 'phone'}
      %button.btn{:type => 'button'} 본인확인
  .control-group
    %label.control-label{:for => 'input-address'} 주소
    .controls
      %textarea{:id => 'input-address', :name => 'address'}
  .control-group
    %label.control-label{:for => 'input-age'} 나이
    .controls
      %input{:type => 'text', :id => 'input-age', :name => 'age'}
  .control-group
    %label.control-label{:for => 'input-email'} 이메일
    .controls
      %input{:type => 'text', :id => 'input-email', :name => 'email'}
  .control-group
    %label.control-label{:for => 'input-purpose'} 대여목적
    .controls
      %input{:type => 'text', :id => 'input-purpose', :name => 'purpose', :placeholder => '선택하거나 입력'}
      %p
        %span.label.clickable 입사면접
        %span.label.clickable 사진촬영
        %span.label.clickable 결혼식
        %span.label.clickable 장례식
  .control-group
    %label.control-label{:for => 'input-height'} 키
    .controls
      %input{:type => 'text', :id => 'input-height', :name => 'height'}
        cm
  .control-group
    %label.control-label{:for => 'input-weight'} 몸무게
    .controls
      %input{:type => 'text', :id => 'input-weight', :name => 'weight'}
        kg
  .control-group
    .controls
      %label.text-info
        열린옷장은 정확한 의류선택과 편리한 이용관리만을 위해 개인정보와 신체치수를 수집 합니다.
  .control-group
    .controls
      %button.btn{type => 'submit'} 다음


@@ guests/status.html.haml
%h3= $guest->purpose
%ul
  %li
    %i.icon-user
    %a{:href => "#{url_for('/guests/' . $guest->id)}"} #{$guest->name}
    %span (#{$guest->age})
  %li
    %i.icon-map-marker
    = $guest->address
  %li
    %i.icon-envelope
    %a{:href => "mailto:#{$guest->email}"}= $guest->email
  %li= $guest->phone
  %li
    %span #{$guest->height} cm,
    %span #{$guest->weight} kg



@@ guests/id.html.haml
- layout 'default';
- title $guest->name . '님';

%div= include 'guests/status', guest => $guest
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

@@ guests/size.html.haml
- layout 'default';
- title '신체치수';

.row
  .span6
    - if (my $order = $guest->orders({ status_id => 2 })->next) {
      - if (overdue_calc($order->target_date, DateTime->now())) {
        %span.label.label-important 연체중
      - } else {
        %span.label.label-warning= $order->status->name
      - }
    - }
    %div= include 'guests/status', guest => $guest
  .span6
    %form.form-horizontal{:method => 'POST', :action => "#{url_for('')}"}
      %legend 대여자 치수 정보
      .control-group
        %label.control-label{:for => 'input-chest'} 가슴
        .controls
          %input{:type => 'text', :id => 'input-chest', :name => 'chest'}
            cm
      .control-group
        %label.control-label{:for => 'input-waist'} 허리
        .controls
          %input{:type => 'text', :id => 'input-waist', :name => 'waist'}
            cm
      .control-group
        %label.control-label{:for => 'input-arm'} 팔
        .controls
          %input{:type => 'text', :id => 'input-arm', :name => 'arm'}
            cm
      .control-group
        %label.control-label{:for => 'input-pants-len'} 기장
        .controls
          %input{:type => 'text', :id => 'input-pants-len', :name => 'pants_len'}
            cm
      .control-group
        .controls
          %input.btn.btn-primary{:type => 'submit', :value => '다음'}


@@ guests/breadcrumb.html.haml
%p
  %a{:href => '/guests/#{$guest->id}'}= $guest->name
  님
  %strong= $guest->purpose
  %span (으)로 방문
  %div
    %span.label.label-info.search-label
      %a{:href => '#{url_with->query([q => $guest->chest])}///#{$status_id}'}= $guest->chest
    %span.label.label-info.search-label
      %a{:href => "#{url_with->query([q => '/' . $guest->waist . '//' . $status_id])}"}= $guest->waist
    %span.label.label-info.search-label
      %a{:href => "#{url_with->query([q => '//' . $guest->arm])}/#{$status_id}"}= $guest->arm
    %span.label= $guest->pants_len
    %span.label= $guest->height
    %span.label= $guest->weight


@@ guests/breadcrumb/radio.html.haml
%label.radio.inline
  %input{:type => 'radio', :name => 'gid', :value => '#{$guest->id}'}
  %a{:href => '/guests/#{$guest->id}'}= $guest->name
  님
  %strong.history-link= $guest->purpose
  %span (으)로 방문
%div
  %i.icon-envelope
  %a{:href => "mailto:#{$guest->email}"}= $guest->email
%div.muted= $guest->phone
%div
  %span.label.label-info= $guest->chest
  %span.label.label-info= $guest->waist
  %span.label.label-info= $guest->arm
  %span.label= $guest->pants_len
  %span.label= $guest->height
  %span.label= $guest->weight


@@ donors/breadcrumb/radio.html.haml
%input{:type => 'radio', :name => 'donor_id', :value => '#{$donor->id}'}
%a{:href => '/donors/#{$donor->id}'}= $donor->name
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
- layout 'default';
- title '검색';

.pull-right
  %p
    %span.badge.badge-inverse 매우작음
    %span.badge 작음
    %span.badge.badge-success 맞음
    %span.badge.badge-warning 큼
    %span.badge.badge-important 매우큼
  %p.muted
    %span.text-info 상태
    1: 대여가능, 2: 대여중, 3: 세탁, 4: 수선, 5: 대여불가, 7: 분실

  %form.form-search{:method => 'get', :action => ''}
    %input{:type => 'hidden', :name => 'gid', :value => "#{param('gid')}"}
    %input.input-medium.search-query{:type => 'text', :id => 'search-query', :name => 'q', :placeholder => '가슴/허리/팔/상태', :value => "#{param('q')}"}
    %button.btn{:type => 'submit'} 검색
    %span.muted 가슴/허리/팔길이/상태

- if (param 'q') {
  %p
    %strong= param 'q'
    %span.muted 의 검색결과
- }

%div= include 'guests/breadcrumb', guest => $guest if $guest
%div= include 'pagination'

%ul
  - while (my $c = $clothes->next) {
    %li= include 'clothes/preview', clothe => $c
  - }

%div= include 'pagination'


@@ clothes/preview.html.haml
%span
  %a{:href => '/clothes/#{$clothe->no}'}= $clothe->no
%div
  %p
    %a{:href => '/clothes/#{$clothe->no}'}
      %img{:src => 'http://placehold.it/75x75', :alt => '#{$clothe->no}'}
    %span.label.label-info.search-label
      %a{:href => "#{url_with->query([q => $clothe->chest . '///' . $status_id])}"}= $clothe->chest
    %span.label.label-info.search-label
      %a{:href => "#{url_with->query([q => '/' . $clothe->bottom->waist . '//' . $status_id])}"}= $clothe->bottom->waist
    %span.label.label-info.search-label
      %a{:href => "#{url_with->query([q => '//' . $clothe->arm . '/' . $status_id])}"}= $clothe->arm
    - if ($clothe->status->name eq '대여가능') {
      %span.label.label-success= $clothe->status->name
    - } elsif ($clothe->status->name eq '대여중') {
      %span.label.label-important= $clothe->status->name
      - if (my $order = $clothe->orders({ status_id => 2 })->next) {
        %small.muted{:title => '반납예정일'}= $order->target_date->ymd if $order->target_date
      - }
    - } else {
      %span.label= $clothe->status->name
    - }
    %ul
      - for my $s ($clothe->satisfactions({}, { rows => 5, order_by => { -desc => [qw/create_date/] } })) {
        %li
          %span.badge{:class => 'satisfaction-#{$s->chest}'}= $s->guest->chest
          %span.badge{:class => 'satisfaction-#{$s->waist}'}= $s->guest->waist
          %span.badge{:class => 'satisfaction-#{$s->arm}'}=   $s->guest->arm
          %span.badge{:class => 'satisfaction-#{$s->top_fit}'}    상의fit
          %span.badge{:class => 'satisfaction-#{$s->bottom_fit}'} 하의fit
          - if ($guest && $s->guest->id == $guest->id) {
            %i.icon-star{:title => '대여한적 있음'}
          - }
      - }


@@ clothes/no.html.haml
- layout 'default';
- title 'clothes/' . $clothe->no;

%h1
  %a{:href => ''}= $clothe->no
  %span - #{$clothe->category->name}

.row
  .span8
    - if ($clothe->status->name eq '대여가능') {
      %span.label.label-success= $clothe->status->name
    - } elsif ($clothe->status->name eq '대여중') {
      %span.label.label-important= $clothe->status->name
      - if (my $order = $clothe->orders({ status_id => 2 })->next) {
        - if ($order->target_date) {
          %small.highlight{:title => '반납예정일'}
            %a{:href => "/orders/#{$order->id}"}= $order->target_date->ymd
        - }
      - }
    - } else {
      %span.label= $clothe->status->name
    - }

    %span
      - if ($clothe->top) {
        %a{:href => '/clothes/#{$clothe->top->no}'}= $clothe->top->no
      - }
      - if ($clothe->bottom) {
        %a{:href => '/clothes/#{$clothe->bottom->no}'}= $clothe->bottom->no
      - }

    %div
      %img.img-polaroid{:src => 'http://placehold.it/200x200', :alt => '#{$clothe->no}'}

    %div
      - if ($clothe->category_id == $Opencloset::Constant::CATEOGORY_JACKET) {
        %span.label.label-info.search-label
          %a{:href => "#{url_for('/search')->query([q => $clothe->chest])}//"}= $clothe->chest
        %span.label.label-info.search-label
          %a{:href => "#{url_for('/search')->query([q => '//' . $clothe->arm])}"}= $clothe->arm
      - } elsif ($clothe->category_id == $Opencloset::Constant::CATEOGORY_PANTS) {
        %span.label.label-info.search-label
          %a{:href => "#{url_for('/search')->query([q => '/' . $clothe->waist . '/'])}"}= $clothe->waist
        %span.label= $clothe->pants_len
      - }
    - if ($clothe->donor) {
      %h3= $clothe->donor->name
      %p.muted 님께서 기증하셨습니다
    - }
  .span4
    %ul
      - for my $order ($clothe->orders({ status_id => 'NOT NULL'}, { order_by => { -desc => [qw/rental_date/] } })) {
        %li
          %a{:href => '/guests/#{$order->guest->id}/size'}= $order->guest->name
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
          %time{:title => '대여일'}= $order->rental_date->ymd
      - }


@@ pagination.html.haml
.pagination
  %div
    %ul
      %li.previous
        %a{:href => '#{url_with->query([p => $pageset->first_page])}'}= '&laquo;&laquo;'
      - if ($pageset->previous_set) {
        %li.previous
          %a{:href => '#{url_with->query([p => $pageset->previous_set])}'}= '&laquo;'
      - } else {
        %li.previous.disabled
          %a= '&laquo;'
      - }
      - for my $p (@{ $pageset->pages_in_set }) {
        - if ($p == $pageset->current_page) {
          %li.active
            %a{:href => '#'}= $p
        - } else {
          %li
            %a{:href => '#{url_with->query([p => $p])}'}= $p
        - }
      - }
      - if ($pageset->next_set) {
        %li.next
          %a{:href => '#{url_with->query([p => $pageset->next_set])}'}= '&raquo;'
      - } else {
        %li.next.disabled
          %a= '&raquo;'
      - }
      %li.next
        %a{:href => '#{url_with->query([p => $pageset->last_page])}'}= '&raquo;&raquo;'


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

%form#clothe-search-form.form-inline
  .input-append
    %input#clothe-id.input-large{:type => 'text', :placeholder => '품번'}
    %button#btn-clothe-search.btn{:type => 'button'} 검색
  %button#btn-clear.btn{:type => 'button'} Clear

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
    <li class="row-checkbox" data-clothe-id="<%= id %>">
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
        <input type="checkbox" name="clothe-id" value="<%= id %>" checked="checked" data-clothe-id="<%= id %>">
        <a href="/clothes/<%= no %>"><%= category %></a>
        <span class="order-status label"><%= status %></span>
        <strong><%= price %></strong>
      </label>
      <% } %>
    </li>
  </script>


@@ orders/id/nil_status.html.haml
- layout 'default', jses => ['orders-id.js'];
- title '주문확인';

%div.pull-right= include 'guests/breadcrumb', guest => $order->guest, status_id => ''
%form.form-horizontal{:method => 'post', :action => ''}
  %legend
    - my $loop = 0;
    - for my $clothe (@$clothes) {
      - $loop++;
      - if ($loop == 1) {
        %span
          %a{:href => '/clothes/#{$clothe->no}'}= $clothe->category->name
          %small.highlight= commify($clothe->category->price)
      - } elsif ($loop == 2) {
        %span
          with
          %a{:href => '/clothes/#{$clothe->no}'}= $clothe->category->name
          %small.highlight= commify($clothe->category->price)
      - } else {
        %span
          ,
          %a{:href => '/clothes/#{$clothe->no}'}= $clothe->category->name
          %small.highlight= commify($clothe->category->price)
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


@@ orders/id.html.haml
- layout 'default', jses => ['orders-id.js'];
- title '주문확인';

%p
  - if ($overdue) {
    %span.label{:class => 'status-#{$order->status_id}'} 연체중
  - } else {
    %span.label{:class => 'status-#{$order->status_id}'}= $order->status->name
  - }
%div.pull-right= include 'guests/breadcrumb', guest => $order->guest, status_id => ''
%div
  - my $loop = 0;
  - for my $clothe (@$clothes) {
    - $loop++;
    - if ($loop == 1) {
      %span
        %a{:href => '/clothes/#{$clothe->no}'}= $clothe->category->name
        %small.highlight= commify($clothe->category->price)
    - } elsif ($loop == 2) {
      %span
        with
        %a{:href => '/clothes/#{$clothe->no}'}= $clothe->category->name
        %small.highlight= commify($clothe->category->price)
    - } else {
      %span
        ,
        %a{:href => '/clothes/#{$clothe->no}'}= $clothe->category->name
        %small.highlight= commify($clothe->category->price)
    - }
  - }

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

- if ($overdue) {
  %p.muted
    %span 연체료
    %strong.text-error= commify($late_fee)
    는 연체일(#{ $overdue }) x 대여금액(#{ commify($order->price) })의 20% 로 계산됩니다
- }

%p.well= $order->comment

- if ($order->status_id == $Opencloset::Constant::STATUS_RETURN) {
  %p= commify($order->late_fee)
  %p= $order->return_method
- } else {
  %form.form-horizontal{:method => 'post', :action => "#{url_for('')}"}
    %fieldset
      %legend 연체료 및 반납방법
      .control-group
        %label 연체료
        .controls
          %input#input-late_fee.input-mini{:type => 'text', :name => 'late_fee', :placeholder => '연체료'}
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
          %a#btn-order-cancel.btn.btn-danger{:href => '#{url_for()}'} 주문취소
- }

%h5 만족도
- if ($satisfaction) {
  %p
    %span.badge{:class => 'satisfaction-#{$satisfaction->chest}'} 가슴
    %span.badge{:class => 'satisfaction-#{$satisfaction->waist}'} 허리
    %span.badge{:class => 'satisfaction-#{$satisfaction->arm}'} 팔길이
    %span.badge{:class => 'satisfaction-#{$satisfaction->top_fit}'} 상의fit
    %span.badge{:class => 'satisfaction-#{$satisfaction->bottom_fit}'} 하의fit
- }


@@ donors/new.html.haml
- layout 'default', jses => ['donors-new.js'];
- title '기증 - 열린옷장';

.pull-right
  %form.form-search{:method => 'get', :action => ''}
    %input#search-query.input-medium.search-query{:type => 'text', :name => 'q', :placeholder => '이메일, 이름 또는 휴대폰번호'}
    %button.btn{:type => 'submit'} 검색

%ul
  - while(my $d = $candidates->next) {
  %li
    %a{:href => "#{url_for('/clothes/new')->query([q => $d->id])}"}= $d->name
    %span.muted= $d->email
    %span.muted= $d->phone
  - }

%form.form-horizontal{:method => 'post', :action => '/donors'}
  %legend
    기증자 기본 정보
    %small
      %a{:href => '/clothes/new'} 기증자모름
  .control-group
    %label.control-label{:for => 'input-name'} 이름
    .controls
      %input{:type => 'text', :id => 'input-name', :name => 'name'}
  .control-group
    %label.control-label{:for => 'input-phone'} 휴대폰
    .controls
      %input{:type => 'text', :id => 'input-phone', :name => 'phone'}
  .control-group
    %label.control-label{:for => 'input-email'} 이메일
    .controls
      %input{:type => 'text', :id => 'input-email', :name => 'email'}
  .control-group
    .controls
      %button.btn{type => 'submit'} 다음


@@ clothes/new.html.haml
- layout 'default';
- title '새로운 옷';

.pull-right
  %form.form-search{:method => 'get', :action => ''}
    %input#search-query.input-medium.search-query{:type => 'text', :name => 'q', :placeholder => '이메일, 이름 또는 휴대폰번호'}
    %button.btn{:type => 'submit'} 검색

%p.text-warning
  %strong Shirts 나 Shoes 와 같은 비주류는 종류만 있으면 됩니다

%form.form-horizontal{:method => 'post', :action => '/clothes'}
  %legend 새로운 옷
  .control-group
    %label.control-label{:for => 'input-category'} 기증해주신 분
    .controls
      - for my $donor (@$donors) {
        %label.radio.inline= include 'donors/breadcrumb/radio', donor => $donor
      - }
  .control-group
    %label.control-label 종류
    .controls
      %select{:name => 'category_id'}
        %option{:value => '-1'} Jacket & Pants
        - for my $c (@$categories) {
          %option{:value => '#{$c->id}'}= $c->name
        - }
  .control-group
    %label.control-label{:for => 'input-chest'} 가슴
    .controls
      %input{:type => 'text', :id => 'input-chest', :name => 'chest'}
  .control-group
    %label.control-label{:for => 'input-waist'} 허리
    .controls
      %input{:type => 'text', :id => 'input-waist', :name => 'waist'}
  .control-group
    %label.control-label{:for => 'input-arm'} 팔길이
    .controls
      %input{:type => 'text', :id => 'input-arm', :name => 'arm'}
  .control-group
    %label.control-label{:for => 'input-pants-len'} 기장
    .controls
      %input{:type => 'text', :id => 'input-pants-len', :name => 'pants_len'}
  .control-group
    .controls
      %button.btn{type => 'submit'} 다음


@@ layouts/default.html.haml
!!! 5
%html{:lang => "ko"}
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
    = include 'layouts/default/body-theme'


@@ layouts/default/meta.html.haml
/ META
    %meta{:charset => "utf-8"}
    %meta{:content => "width=device-width, initial-scale=1.0", :name => "viewport"}


@@ layouts/default/before-css.html.haml
/ CSS
    %link{:rel => "stylesheet", :href => "/lib/bootstrap/css/bootstrap.min.css"}
    %link{:rel => "stylesheet", :href => "/lib/bootstrap/css/bootstrap-responsive.min.css"}
    %link{:rel => "stylesheet", :href => "/lib/font-awesome/css/font-awesome.min.css"}
    /[if IE 7]
      %link{:rel => "stylesheet", :href => "/lib/font-awesome/css/font-awesome-ie7.min.css"}
    %link{:rel => "stylesheet", :href => "/lib/prettify/css/prettify.css"}
    %link{:rel => "stylesheet", :href => "/lib/datepicker/css/datepicker.css"}


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

    <!-- bundle -->
    <script src="/js/bundle.js"></script>

    <!-- page specific -->
    % my @include_jses = @$jses;
    % push @include_jses, "$active_id.js" if $active_id;
    % for my $js (@include_jses) {
      <script type="text/javascript" src="/js/<%= $js %>"></script>
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


@@ layouts/default/body-theme.html.ep
<!-- body theme -->
    <script src="/theme/<%= $theme %>/js/<%= $theme %>-elements.min.js"></script>
    <script src="/theme/<%= $theme %>/js/<%= $theme %>.min.js"></script>


@@ layouts/default/navbar.html.ep
<!-- navbar -->
    <div class="navbar navbar-default" id="navbar">
      <div class="navbar-container" id="navbar-container">
        <div class="navbar-header pull-left">
          <a href="#" class="navbar-brand">
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
          %     my $link  = $meta->{link} // $item->{id};
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
              <li> <i class="icon-home home-icon"></i> <a href="/">첫 화면</a> </li>
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
              <li class="active"> <i class="icon-home home-icon"></i>첫 화면</li>
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
    = include 'layouts/login/body-js'
    = include 'layouts/default/body-theme'


@@ layouts/login/body-js.html.ep
    <script type="text/javascript">
      function show_box(id) {
        jQuery('.widget-box.visible').removeClass('visible');
        jQuery('#'+id).addClass('visible');
      }
    </script>


@@ layouts/login/login-box.html.ep
<!-- LOGIN-BOX -->
                <div id="login-box" class="login-box visible widget-box no-border">
                  <div class="widget-body">
                    <div class="widget-main">
                      <h4 class="header blue lighter bigger">
                        <i class="icon-coffee green"></i>
                        정보를 입력해주세요
                      </h4>

                      <div class="space-6"></div>

                      <form>
                        <fieldset>
                          <label class="block clearfix">
                            <span class="block input-icon input-icon-right">
                              <input type="text" class="form-control" placeholder="Username" />
                              <i class="icon-user"></i>
                            </span>
                          </label>

                          <label class="block clearfix">
                            <span class="block input-icon input-icon-right">
                              <input type="password" class="form-control" placeholder="Password" />
                              <i class="icon-lock"></i>
                            </span>
                          </label>

                          <div class="space"></div>

                          <div class="clearfix">
                            <label class="inline">
                              <input type="checkbox" class="<%= $theme %>" />
                              <span class="lbl"> 기억하기</span>
                            </label>

                            <button type="button" class="width-35 pull-right btn btn-sm btn-primary">
                              <i class="icon-key"></i>
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
                        Retrieve Password
                      </h4>

                      <div class="space-6"></div>
                      <p>
                        Enter your email and to receive instructions
                      </p>

                      <form>
                        <fieldset>
                          <label class="block clearfix">
                            <span class="block input-icon input-icon-right">
                              <input type="email" class="form-control" placeholder="Email" />
                              <i class="icon-envelope"></i>
                            </span>
                          </label>

                          <div class="clearfix">
                            <button type="button" class="width-35 pull-right btn btn-sm btn-danger">
                              <i class="icon-lightbulb"></i>
                              Send Me!
                            </button>
                          </div>
                        </fieldset>
                      </form>
                    </div><!-- /widget-main -->

                    <div class="toolbar center">
                      <a href="#" onclick="show_box('login-box'); return false;" class="back-to-login-link">
                        Back to login
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
                        New User Registration
                      </h4>

                      <div class="space-6"></div>
                      <p> Enter your details to begin: </p>

                      <form>
                        <fieldset>
                          <label class="block clearfix">
                            <span class="block input-icon input-icon-right">
                              <input type="email" class="form-control" placeholder="Email" />
                              <i class="icon-envelope"></i>
                            </span>
                          </label>

                          <label class="block clearfix">
                            <span class="block input-icon input-icon-right">
                              <input type="text" class="form-control" placeholder="Username" />
                              <i class="icon-user"></i>
                            </span>
                          </label>

                          <label class="block clearfix">
                            <span class="block input-icon input-icon-right">
                              <input type="password" class="form-control" placeholder="Password" />
                              <i class="icon-lock"></i>
                            </span>
                          </label>

                          <label class="block clearfix">
                            <span class="block input-icon input-icon-right">
                              <input type="password" class="form-control" placeholder="Repeat password" />
                              <i class="icon-retweet"></i>
                            </span>
                          </label>

                          <label class="block">
                            <input type="checkbox" class="<%= $theme %>" />
                            <span class="lbl">
                              I accept the
                              <a href="#">User Agreement</a>
                            </span>
                          </label>

                          <div class="space-24"></div>

                          <div class="clearfix">
                            <button type="reset" class="width-30 pull-left btn btn-sm">
                              <i class="icon-refresh"></i>
                              Reset
                            </button>

                            <button type="button" class="width-65 pull-right btn btn-sm btn-success">
                              Register
                              <i class="icon-arrow-right icon-on-right"></i>
                            </button>
                          </div>
                        </fieldset>
                      </form>
                    </div>

                    <div class="toolbar center">
                      <a href="#" onclick="show_box('login-box'); return false;" class="back-to-login-link">
                        <i class="icon-arrow-left"></i>
                        Back to login
                      </a>
                    </div>
                  </div><!-- /widget-body -->
                </div><!-- /signup-box -->
