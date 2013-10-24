#!/usr/bin/env perl
use Mojolicious::Lite;

use Opencloset::Schema;
use DateTime;

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

    my %error_map = (
        400 => 'bad_request',
        404 => 'not_found',
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

plugin 'haml_renderer';

get '/' => sub {
    my $self = shift;
    $self->render('index');
};

get '/new' => sub {
    my $self = shift;
    $self->render('new');
};

get '/clothes/:no' => sub {
    my $self = shift;
    my $no = $self->param('no');
    my $clothe = $schema->resultset('Clothe')->find({ no => $no });
    return $self->error(404, 'Not found') unless $clothe;

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

app->start;
__DATA__

@@ index.html.haml
- layout 'default', javascripts => ['root-index.js'];
- title 'Opencloset, sharing clothes';

%form#clothe-search-form.form-inline
  .input-append
    %input.input-large{:type => 'text', :id => 'clothe-id', :placeholder => '품번'}
    %button#btn-clothe-search.btn{:type => 'button'} 검색
  %p.text-error

%ul#clothes-list

:plain
  <script id="tpl-li" type="text/html">
    <li>
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
  <script id="tpl-rent-available" type="text/html">
    <li>
      <label class="checkbox">
        <input type="checkbox" checked="checked">
        <a href="/clothes/<%= id %>"><%= category %></a>
        <span class="label label-success"><%= status %></span>
      </label>
    </li>
  </script>

@@ new.html.haml
- layout 'default';
- title 'type the new guest information';

%p.text-warning
  %strong 작성하시기전, 직원에게 언제 입으실 건지 알려주세요

.pull-right
  %form.form-search
    %input.input-medium.search-query{:type => 'text', :id => 'search-query', :placeholder => '이름 또는 휴대폰번호'}
    %button.btn{:type => 'submit'} Search

%form.form-horizontal
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
        %input{:type => 'checkbox'}
          정확한 의류선택과 편리한 이용관리를 위한 개인정보와 신체치수 수집에 동의 하십니까?
  .control-group
    .controls
      %button.btn{type => 'submit'} 다음

@@ clothes/item.html.haml
- layout 'default';
- title 'clothes/item';

%p clothes/item

@@ not_found.html.haml
- layout 'default';
- title 'Not found';

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
              %a{:href => "/new"} 대여
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
