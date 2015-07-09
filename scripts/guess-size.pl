#!/usr/bin/env perl

use utf8;
use strict;
use warnings;

use OpenCloset::Schema;
use OpenCloset::Size::Guess::Local;
use OpenCloset::Size::Guess::BodyKit;
use OpenCloset::Config;

binmode STDOUT, ':utf8';

my $gender = shift;
my $height = shift;
my $weight = shift;
die "Usage: $0 <gender> <height> <weight>\n"
    unless $gender
    and $height
    and $weight;

my $CONF = OpenCloset::Config::load( $ENV{MOJO_CONFIG} || 'app.conf' );
my $DB = OpenCloset::Schema->connect(
    {
        dsn      => $CONF->{database}{dsn},
        user     => $CONF->{database}{user},
        password => $CONF->{database}{pass},
        %{ $CONF->{database}{opts} },
    }
);

my $local = OpenCloset::Size::Guess::Local->new(
    schema => $DB,
    gender => $gender,
    height => $height,
    weight => $weight
);

my $bodykit = OpenCloset::Size::Guess::BodyKit->new(
    access_key => $CONF->{bodykit}{access_key},
    secret     => $CONF->{bodykit}{secret},
    gender     => $gender,
    height     => $height,
    weight     => $weight
);

print "$local\n";
print "$bodykit\n";
