#!/usr/bin/env perl

use v5.18;
use utf8;
use strict;
use warnings;
use open ':locale';

use OpenCloset::Config;
use OpenCloset::Schema;

my $email = shift;
die "Usage: $0 <email>\n" unless $email;

my $CONF = OpenCloset::Config::load('app.conf');
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

my $epoch = `date +%s`;
chomp $epoch;
$epoch += 86400 * 30;

$user->update( { expires => $epoch } );
say "Update expires successfully";
say "$user";
