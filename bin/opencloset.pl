#!/usr/bin/env perl
use Mojolicious::Lite;

use Opencloset::Schema;
use DateTime;
use Data::Pageset;

my $DB_NAME     = $ENV{OPENCLOSET_DB}       || 'opencloset';
my $DB_USERNAME = $ENV{OPENCLOSET_USERNAME} || 'root';
my $DB_PASSWORD = $ENV{OPENCLOSET_PASSWORD} || '';

app->defaults(
    javascripts => [],
);

my $schema = Opencloset::Schema->connect({
    dsn               => "dbi:mysql:$DB_NAME:127.0.0.1",
    user              => $DB_USERNAME,
    password          => $DB_PASSWORD,
    RaiseError        => 1,
    AutoCommit        => 1,
    mysql_enable_utf8 => 1,
    quote_char        => q{`},
    on_connect_do     => 'SET NAMES utf8'
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
    my ($self, $row) = @_;

    return {
        $row->get_columns,
        donor    => $row->donor->name,
        category => $row->category->name,
        status   => $row->status->name,
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

    return $schema->resultset('Guest')->create(\%params);
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
    my $q      = $self->param('q');
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

    return $self->error(400, 'invalid request')
        unless $self->validate($validator);

    my $guest = $self->create_guest;
    return $self->error(500, 'failed to create a new guest') unless $guest;

    $self->res->headers->header('Location' => $self->url_for('/guest/' . $guest->id));
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

put '/clothes' => sub {
    my $self = shift;
    my $clothes = $self->param('clothes');
    return $self->error(400, 'Nothing to change') unless $clothes;

    my $status = $schema->resultset('Status')->find({ name => $self->param('status') });
    return $self->error(400, 'Invalid status') unless $status;

    my $rs    = $schema->resultset('Clothe')->search({ 'me.id' => { -in => $clothes } });
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
            html => { template => 'clothes/item' }    # also, CODEREF is OK
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
        html => { template => 'clothes/item' }    # also, CODEREF is OK
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

app->start;
__DATA__

@@ index.html.haml
- layout 'default', javascripts => ['root-index.js'];
- title 'Opencloset, sharing clothes - 열린옷장';

%form#clothe-search-form.form-inline
  .input-append
    %input.input-large{:type => 'text', :id => 'clothe-id', :placeholder => '품번'}
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
        <a class="btn btn-success btn-mini" href="/order/<%= order_id %>">주문서</a>
        <a href="/clothe/<%= id %>"><%= category %></a>
        <span class="order-status label"><%= status %></span> with
        <% _.each(clothes, function(clothe) { %> <a href="/clothes/<%= clothe.id %>"><%= clothe.category %></a><% }); %>
        <a class="history-link" href="/order/<%= order_id %>">
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
        <a href="/clothes/<%= id %>"><%= category %></a>
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
  %a{:href => '/clothes/#{$clothe->id}'}= $clothe->no
%div
  %p
    %a{:href => '/clothes/#{$clothe->id}'}
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

@@ clothes/item.html.haml
- layout 'default';
- title 'clothes/item - 열린옷장';

%p clothes/item

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

%h3 404 Not found
%p= $error

@@ layouts/default.html.haml
!!! 5
%html{:lang => "ko"}
  %head
    %meta{:charset => "utf-8"}/
    %title= title
    %meta{:content => "", :name => "description"}/
    %meta{:content => "", :name => "author"}/
    %link{:href => "/assets/css/bootstrap.css", :rel => "stylesheet"}/
    %link{:href => "/assets/lib/datepicker/css/datepicker.css", :rel => "stylesheet"}/
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
              %a{:href => "/search"} 정장 검색
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
      %script{:src => "/assets/lib/datepicker/js/bootstrap-datepicker.js"}
      %script{:src => "/assets/js/bundle.js"}
      - for my $js (@$javascripts) {
      %script{:src => "/assets/js/#{$js}"}
      - }
