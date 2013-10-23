#!/usr/bin/env perl
use Mojolicious::Lite;

plugin 'haml_renderer';

get '/' => sub {
    my $self = shift;
    $self->render('index');
};

get '/new' => sub {
    my $self = shift;
    $self->render('new');
};

app->start;
__DATA__

@@ index.html.haml
- layout 'default';
- title 'Opencloset, sharing clothes';
%p
  %button.btn.btn-large.btn-primary{:type => "button"} 대여

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
