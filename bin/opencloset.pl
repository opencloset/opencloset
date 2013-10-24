#!/usr/bin/env perl
use Mojolicious::Lite;

use Opencloset::Schema;

my $DB_NAME     = $ENV{OPENCLOSET_DB}       || 'opencloset';
my $DB_USERNAME = $ENV{OPENCLOSET_USERNAME} || 'root';
my $DB_PASSWORD = $ENV{OPENCLOSET_PASSWORD} || '';

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

    ### status_id => 2 : 대여중
    ### 상수(Constants)로써 관리해야 할까?
    my $co_rs = $clothe->clothe_orders->search(
        { 'order.status_id' => 2 }, { join => 'order' }
    )->next;

    ### $co_rs 가 undef 라면 이상한 상황임
    ### 빌린옷이 있는데 주문엔 빌려간 상태가 없을리가

    my $order = $co_rs->order;

    # join 해서 아직 반납 안된 것만..
    my %columns = (
        %{ $self->clothe2hr($clothe) },
        rental_date => $order->rental_date,
        target_date => $order->target_date,
        with        => []
    );

    $self->respond_to(
        json => { json => { %columns } },
        html => { template => 'clothes/item' }
        # html => sub { $self->render('clothes/item') }
    );
};

app->start;
__DATA__

@@ index.html.haml
- layout 'default';
- title 'Opencloset, sharing clothes';

%form.form-inline
  .input-append
    %input.input-large{:type => 'text', :placeholder => '품번'}
    %button.btn{:type => 'button'} 검색

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
      %script{:src => "//cdnjs.cloudflare.com/ajax/libs/jquery/1.10.2/jquery.min.js"}
      %script{:src => "/assets/lib/datepicker/js/bootstrap-datepicker.js"}
      %script{:src => "/assets/js/bundle.js"}
