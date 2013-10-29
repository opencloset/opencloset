use strict;
use warnings;

use Plack::Builder;
use Plack::App::File;

my $app = require "bin/opencloset.pl";
my $static = Plack::App::File->new(root => "./public")->to_app;

builder {
    enable_if { $_[0]->{REMOTE_ADDR} eq '127.0.0.1' } "Plack::Middleware::ReverseProxy";
    enable "ConditionalGET";

    mount "/"       => $app;
    mount "/public" => $static;
};
