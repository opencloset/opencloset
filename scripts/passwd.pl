#!/usr/bin/env perl

use v5.18;
use utf8;
use strict;
use warnings;
use open ':locale';

use OpenCloset::Schema;
use OpenCloset::Util;

my $email    = shift;
my $password = shift;
die "Usage: $0 <email> [<password>]\n" unless $email;

my $CONF = OpenCloset::Util::load_config( $ENV{MOJO_CONFIG} || 'app.conf' );
my $DB = OpenCloset::Schema->connect(
    {
        dsn      => $CONF->{database}{dsn},
        user     => $CONF->{database}{user},
        password => $CONF->{database}{pass},
        %{ $CONF->{database}{opts} },
    }
);

my $user = $DB->resultset('User')->find( { email => $email } );
die "not found such email: $email\n" unless $user;

if ($password) {
    $user->update( { password => $password } );
    print "successfully updated password\n";
}

print "$user\n";
