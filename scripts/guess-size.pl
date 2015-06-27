#!/usr/bin/env perl

use utf8;
use strict;
use warnings;

use OpenCloset::Schema;
use OpenCloset::Size::Guess;
use OpenCloset::Util;

binmode STDOUT, ':utf8';

my $gender = shift;
my $height = shift;
my $weight = shift;
die "Usage: $0 <gender> <height> <weight>\n"
    unless $gender
    and $height
    and $weight;

my $CONF = OpenCloset::Util::load_config( $ENV{MOJO_CONFIG} || 'app.conf' );
my $DB = OpenCloset::Schema->connect(
    {
        dsn      => $CONF->{database}{dsn},
        user     => $CONF->{database}{user},
        password => $CONF->{database}{pass},
        %{ $CONF->{database}{opts} },
    }
);

my $guess = OpenCloset::Size::Guess->new(
    schema => $DB,
    gender => $gender,
    height => $height,
    weight => $weight
);

print "$guess\n";