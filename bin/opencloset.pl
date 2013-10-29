#!/usr/bin/env perl
use Mojolicious::Lite;

use Data::Pageset;
use DateTime;
use Opencloset::Schema;
use Try::Tiny;

app->defaults( %{ plugin 'Config' => { default => {
    javascripts => [],
}}});

my $schema = Opencloset::Schema->connect({
    dsn               => app->config->{database}{dsn},
    user              => app->config->{database}{user},
    password          => app->config->{database}{pass},
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

    return $schema->resultset('Guest')->find_or_create(\%params);
};

helper create_donor => sub {
    my $self = shift;

    my %params;
    map { $params{$_} = $self->param($_) } qw/name phone email comment/;

    return $schema->resultset('Donor')->find_or_create(\%params);
};

helper create_clothe => sub {
    my ($self, $category_id) = @_;

    ## generate no
    my $category = $schema->resultset('Category')->find({ id => $category_id });
    return unless $category;

    my $clothe = $schema->resultset('Clothe')->search({
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

    return $schema->resultset('Clothe')->find_or_create(\%params);
};

plugin 'validator';
plugin 'haml_renderer';
plugin 'FillInFormLite';

get '/' => sub {
    my $self = shift;
    $self->render('index');
};

get '/new' => sub {
    my $self   = shift;
    my $q      = $self->param('q') || '';
    my $guests = $schema->resultset('Guest')->search({
        -or => [
            id    => $q,
            name  => $q,
            phone => $q,
            email => $q
        ],
    });

    $self->render('new', candidates => $guests);
};

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

get '/guests/:id/size' => sub {
    my $self  = shift;
    my $guest = $schema->resultset('Guest')->find({ id => $self->param('id') });
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

    my $guest = $schema->resultset('Guest')->find({ id => $self->param('id') });
    map { $guest->$_($self->param($_)) } @fields;
    $guest->update;
    my ($chest, $waist) = ($guest->chest + 3, $guest->waist - 1);
    $self->respond_to(
        json => { json => { $guest->get_columns } },
        html => sub {
            $self->redirect_to(
                # ignore $guest->arm for wide search result
                $self->url_for('/search')
                    ->query(q => "$chest/$waist/", gid => $guest->id)
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
    my $guard = $schema->txn_scope_guard;
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

    my $status = $schema->resultset('Status')->find({ name => $self->param('status') });
    return $self->error(400, 'Invalid status') unless $status;

    my $rs    = $schema->resultset('Clothe')->search({ 'me.id' => { -in => [split(/,/, $clothes)] } });
    my $guard = $schema->txn_scope_guard;
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
    my $donors = [$schema->resultset('Donor')->search({
        -or => [
            id    => $q,
            name  => $q,
            phone => $q,
            email => $q
        ],
    })];

    my @categories = $schema->resultset('Category')->search;

    $self->render(
        'clothes/new',
        donors     => $donors,
        categories => [@categories],
    );
} => 'clothes/new';

get '/clothes/:no' => sub {
    my $self = shift;
    my $no = $self->param('no');
    my $clothe = $schema->resultset('Clothe')->find({ no => $no });
    return $self->error(404, "Not found `$no`") unless $clothe;

    my $co_rs = $clothe->clothe_orders->search(
        { 'order.status_id' => 2 }, { join => 'order' }    # 2: 대여중
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

    $columns{status} = $schema->resultset('Status')->find({ id => 6 })->name
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
    my $guest = $gid ? $schema->resultset('Guest')->find({ id => $gid }) : undef;

    my $c_jacket = $schema->resultset('Category')->find({ name => 'jacket' });
    my $cond = { category_id => $c_jacket->id };
    my ($chest, $waist, $arm) = split /\//, $q;
    $cond->{chest} = { '>=' => $chest } if $chest;
    $cond->{waist} = { '>=' => $waist } if $waist;
    $cond->{arm}   = { '>=' => $arm   } if $arm;

    ### row, current_page, count
    my $ENTRIES_PER_PAGE = 10;
    my $clothes = $schema->resultset('Clothe')->search(
        $cond,
        {
            page     => $self->param('p') || 1,
            rows     => $ENTRIES_PER_PAGE,
            order_by => [qw/chest waist arm/],
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
        guest   => $guest,
        clothes => $clothes,
        pageset => $pageset,
    );
};

get '/orders/new' => sub {
    my $self = shift;

    my $today = DateTime->now;
    $today->set_hour(0);
    $today->set_minute(0);
    $today->set_second(0);

    my $q      = $self->param('q');
    my @guests = $schema->resultset('Guest')->search({
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
    my $dt_parser = $schema->storage->datetime_parser;
    push @guests, $schema->resultset('Guest')->search({
        -or => [
            create_date => { '>=' => $dt_parser->format_datetime($today) },
            visit_date  => { '>=' => $dt_parser->format_datetime($today) },
        ],
    }, {
        order_by => { -desc => 'create_date' },
    });

    $self->stash(guests => \@guests);
} => 'orders/new';

post '/orders' => sub {
    my $self = shift;

    my $validator = $self->create_validator;
    $validator->field([qw/gid clothe-id/])
        ->each(sub { shift->required(1)->regexp(qr/^\d+$/) });

    return $self->error(400, 'failed to validate')
        unless $self->validate($validator);

    my $guest   = $schema->resultset('Guest')->find({ id => $self->param('gid') });
    my @clothes = $schema->resultset('Clothe')->search({ 'me.id' => { -in => [$self->param('clothe-id')] } });

    return $self->error(400, 'invalid request') unless $guest || @clothes;

    my $guard = $schema->txn_scope_guard;
    my $order;
    try {
        # BEGIN TRANSACTION ~
        $order = $schema->resultset('Order')->create({
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

    my $order = $schema->resultset('Order')->find({ id => $self->param('id') });
    return $self->error(404, "Not found") unless $order;

    my @clothes = $order->clothes;
    my $price = 0;
    for my $clothe (@clothes) {
        $price += $clothe->category->price;
    }

    my $overdue  = $order->target_date ? $self->overdue_calc($order->target_date, DateTime->now()) : 0;
    my $late_fee = $order->price * 0.2 * $overdue;

    my $c_jacket = $schema->resultset('Category')->find({ name => 'jacket' });
    my $cond = { category_id => $c_jacket->id };
    my $clothe = $order->clothes($cond)->next;

    my $satisfaction = $clothe->satisfactions({
        clothe_id => $clothe->id,
        guest_id  => $order->guest->id,
    })->next;

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

    $self->stash(template => 'orders/id/nil_status');
    $self->stash(template => 'orders/id') if ($order->status);
    $self->render_fillinform({ %fillinform });
};

any [qw/post put patch/] => '/orders/:id' => sub {
    my $self = shift;

    # repeat codes; use `under`?
    my $order = $schema->resultset('Order')->find({ id => $self->param('id') });
    return $self->error(404, "Not found") unless $order;

    my $validator = $self->create_validator;
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
    } qw/price discount target_date comment return_method late_fee l_discount/;
    my %status_to_be = (
        0 => 2,    # NULL   -> 대여중
        2 => 8,    # 대여중 -> 반납
        # TODO: consider `분실`
    );

    my $guard = $schema->txn_scope_guard;
    # BEGIN TRANSACTION ~
    $order->status_id($status_to_be{$order->status_id || 0});
    my $dt_parser = $schema->storage->datetime_parser;
    $order->rental_date($dt_parser->format_datetime(DateTime->now));
    $order->update;

    for my $clothe ($order->clothes) {
        if ($order->status_id == 2) {
            $clothe->status_id(2);
        } else {
            if ($clothe->category_id == 4) {
                $clothe->status_id(1);    # Shoes, 대여가능
            } else {
                $clothe->status_id(3);    # otherwise, 세탁
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
        my $c_jacket = $schema->resultset('Category')->find({ name => 'jacket' });
        my $cond = { category_id => $c_jacket->id };
        my $clothe = $order->clothes($cond)->next;
        if ($clothe) {
            $schema->resultset('Satisfaction')->update_or_create({
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

get '/donors/new' => sub {
    my $self   = shift;
    my $q      = $self->param('q') || '';
    my $donors = $schema->resultset('Donor')->search({
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

@@ index.html.haml
- layout 'default', javascripts => ['root-index.js'];
- title 'Opencloset, sharing clothes - 열린옷장';

%form#clothe-search-form.form-inline
  .input-append
    %input#clothe-id.input-large{:type => 'text', :placeholder => '품번'}
    %button#btn-clothe-search.btn{:type => 'button'} 검색
  %button#btn-clear.btn{:type => 'button'} Clear

#clothes-list
  %ul
  #action-buttons{:style => 'display: none'}
    %button.btn.btn-mini{:type => 'button', :data-status => '세탁'} 세탁
    %button.btn.btn-mini{:type => 'button', :data-status => '대여가능'} 반납
    %button.btn.btn-mini{:type => 'button', :data-status => '분실'} 분실

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

@@ new.html.haml
- layout 'default', javascripts => ['new.js'];
- title '새로 오신 손님 - 열린옷장';

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
      %label.checkbox.inline
        %input{:type => 'checkbox' :checked => 'checked'}
          정확한 의류선택과 편리한 이용관리를 위한 개인정보와 신체치수 수집에 동의 하십니까?
  .control-group
    .controls
      %button.btn{type => 'submit'} 다음

@@ guests/size.html.haml
- layout 'default';
- title '신체치수 - 열린옷장';

.row
  .span6
    - if (my $order = $guest->orders({ status_id => 2 })->next) {
      - if (overdue_calc($order->target_date, DateTime->now())) {
        %span.label.label-important 연체중
      - } else {
        %span.label.label-warning= $order->status->name
      - }
    - }
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
      %a{:href => '#{url_with->query([q => $guest->chest])}//'}= $guest->chest
    %span.label.label-info.search-label
      %a{:href => "#{url_with->query([q => '/' . $guest->waist . '/'])}"}= $guest->waist
    %span.label.label-info.search-label
      %a{:href => "#{url_with->query([q => '//' . $guest->arm])}"}= $guest->arm
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
- title '검색 - 열린옷장';

.pull-right
  %p
    %span.badge.badge-inverse 매우작음
    %span.badge 작음
    %span.badge.badge-success 맞음
    %span.badge.badge-warning 큼
    %span.badge.badge-important 매우큼

  %form.form-search{:method => 'get', :action => ''}
    %input{:type => 'hidden', :name => 'gid', :value => "#{param('gid')}"}
    %input.input-medium.search-query{:type => 'text', :id => 'search-query', :name => 'q', :placeholder => '가슴/허리/팔', :value => "#{param('q')}"}
    %button.btn{:type => 'submit'} 검색

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
      %a{:href => "#{url_with->query([q => $clothe->chest . '//'])}"}= $clothe->chest
    %span.label.label-info.search-label
      %a{:href => "#{url_with->query([q => '/' . $clothe->waist . '/'])}"}= $clothe->waist
    %span.label.label-info.search-label
      %a{:href => "#{url_with->query([q => '//' . $clothe->arm])}"}= $clothe->arm
    - if ($clothe->status->name eq '대여가능') {
      %span.label.label-success= $clothe->status->name
    - } elsif ($clothe->status->name eq '대여중') {
      %span.label.label-important= $clothe->status->name
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
- title 'clothes/' . $clothe->no . ' - 열린옷장';

%h1
  %a{:href => ''}= $clothe->no
  %span - #{$clothe->category->name}

.row
  .span8
    - if ($clothe->status->name eq '대여가능') {
      %span.label.label-success= $clothe->status->name
    - } elsif ($clothe->status->name eq '대여중') {
      %span.label.label-important= $clothe->status->name
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
      %span.label.label-info.search-label
        %a{:href => "#{url_for('/search')->query([q => $clothe->chest])}//"}= $clothe->chest
      %span.label.label-info.search-label
        %a{:href => "#{url_for('/search')->query([q => '/' . $clothe->waist . '/'])}"}= $clothe->waist
      %span.label.label-info.search-label
        %a{:href => "#{url_for('/search')->query([q => '//' . $clothe->arm])}"}= $clothe->arm
      %span.label= $clothe->pants_len

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

@@ not_found.html.haml
- layout 'default';
- title 'Not found - 열린옷장';

%h1 404 Not found
- if ($error) {
  %p.text-error= $error
- }

@@ bad_request.html.haml
- layout 'default';
- title 'Bad request - 열린옷장';

%h1 400 Bad request
- if ($error) {
  %p.text-error= $error
- }

@@ layouts/default.html.haml
!!! 5
%html{:lang => "ko"}
  %head
    %meta{:charset => "utf-8"}/
    %title= title
    %meta{:content => "", :name => "description"}/
    %meta{:content => "", :name => "author"}/
    %link{:href => "/assets/css/bootstrap.css", :rel => "stylesheet"}/
    %link{:href => "/assets/lib/datepicker-1.2.0/css/datepicker.css", :rel => "stylesheet"}/
    %link{:href => "/assets/css/screen.css", :rel => "stylesheet"}/
  %body
    .container
      .navbar
        .navbar-inner
          %a.brand{:href => "/"} OPEN-CLOSET
          %ul.nav
            %li
              %a{:href => "/"} Home
            %li
              %a{:href => "/new"} 새로 오신 손님
            %li
              %a{:href => "/orders/new"} 대여
            %li
              %a{:href => "/search"} 정장 검색
            %li
              %a{:href => "/donors/new"} 기증
      .content
        = content
      %footer.footer
        .container
          %p
            %a{:href => "#"} facebook
          %p
            %a{:href => "#"} twitter
      %script{:src => "/assets/lib/jquery/jquery-1.10.2.min.js"}
      %script{:src => "/assets/lib/underscore/underscore-min.js"}
      %script{:src => "/assets/lib/datepicker-1.2.0/js/bootstrap-datepicker.js"}
      %script{:src => "/assets/lib/datepicker-1.2.0/js/locales/bootstrap-datepicker.kr.js"}
      %script{:src => "/assets/js/bundle.js"}
      - for my $js (@$javascripts) {
      %script{:src => "/assets/js/#{$js}"}
      - }

@@ orders/new.html.haml
- layout 'default', javascripts => ['orders-new.js'];
- title '대여 - 열린옷장';

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
- layout 'default', javascripts => ['orders-id.js'];
- title '주문확인 - 열린옷장';

%div.pull-right= include 'guests/breadcrumb', guest => $order->guest
%form.form-horizontal{:method => 'post', :action => ''}
  %legend
    - my $loop = 0;
    - for my $clothe (@$clothes) {
      - $loop++;
      - if ($loop == 1) {
        %span
          %a{:href => '/clothes/#{$clothe->no}'}= $clothe->category->name
      - } elsif ($loop == 2) {
        %span
          with
          %a{:href => '/clothes/#{$clothe->no}'}= $clothe->category->name
      - } else {
        %span
          ,
          %a{:href => '/clothes/#{$clothe->no}'}= $clothe->category->name
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
- layout 'default', javascripts => ['orders-id.js'];
- title '주문확인 - 열린옷장';

%p
  - if ($order->status_id == 8) {
    %span.label{:class => 'status-#{$order->status_id}'}= $order->status->name
  - } elsif ($overdue) {
    %span.label{:class => 'status-#{$order->status_id}'} 연체중
  - } else {
    %span.label{:class => 'status-#{$order->status_id}'}= $order->status->name
  - }
%div.pull-right= include 'guests/breadcrumb', guest => $order->guest
%div
  - my $loop = 0;
  - for my $clothe (@$clothes) {
    - $loop++;
    - if ($loop == 1) {
      %span
        %a{:href => '/clothes/#{$clothe->no}'}= $clothe->category->name
    - } elsif ($loop == 2) {
      %span
        with
        %a{:href => '/clothes/#{$clothe->no}'}= $clothe->category->name
    - } else {
      %span
        ,
        %a{:href => '/clothes/#{$clothe->no}'}= $clothe->category->name
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

- if ($overdue) {
  %p.muted
    %span 연체료
    %strong.text-error= commify($late_fee)
    는 연체일(#{ $overdue }) x 대여금액(#{ commify($order->price) })의 20% 로 계산됩니다
- }

- if ($order->status_id == 8) {
  %p= commify($order->late_fee)
  %p= $order->return_method
- } else {
  %form.form-inline{:method => 'post', :action => "#{url_for('')}"}
    %fieldset
      %legend 연체료 및 반납방법
      %input#input-late_fee.input-mini{:type => 'text', :name => 'late_fee', :placeholder => '연체료'}
      %label.radio
        %input{:type => 'radio', :name => 'return_method', :value => '방문'}
        방문
      %label.radio
        %input{:type => 'radio', :name => 'return_method', :value => '택배'}
        택배
      %button.btn.btn-success{:type => 'submit'} 반납
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
- layout 'default';
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
- title '새로운 옷 - 열린옷장';

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
