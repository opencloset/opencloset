#!/usr/bin/env perl
use Mojolicious::Lite;

plugin 'haml_renderer';

get '/' => sub {
    my $self = shift;
    $self->render('index');
};

app->start;
__DATA__

@@ index.html.ep
% layout 'default';
% title 'Welcome';
Welcome to the Mojolicious real-time web framework!

@@ layouts/default.html.haml
!!! 5
%html{:lang => "en"}
  %head
    %meta{:charset => "utf-8"}/
    %title Opencloset, sharing clothes
    %meta{:content => "", :name => "description"}/
    %meta{:content => "", :name => "author"}/
    %link{:href => "/assets/css/bootstrap.css", :rel => "stylesheet"}/
    %link{:href => "/assets/css/screen.css", :rel => "stylesheet"}/
  %body
    .container
      .navbar
        .navbar-inner
          %a.brand{:href => "#"} OPEN-CLOSET
          %ul.nav
            %li
              %a{:href => "#"} Home
            %li
              %a{:href => "#"} Search
      .content
        = content
      %footer.footer
        .container
          %p
            %a{:href => "#"} facebook
          %p
            %a{:href => "#"} twitter
      %script{:src => "//cdnjs.cloudflare.com/ajax/libs/jquery/1.10.2/jquery.min.js"}
