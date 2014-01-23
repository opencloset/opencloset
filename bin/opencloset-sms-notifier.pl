#!/usr/bin/env perl

use v5.18;
use strict;
use warnings;

use FindBin qw( $Script );
use Path::Tiny;

my $conf;
my $opt;

load_config();
$opt->{delay} //= 60;

my $continue = 1;
$SIG{TERM} = sub { $continue = 0; };
$SIG{HUP}  = sub { load_config()  };
while ($continue) {
    do_work();
    sleep $opt->{delay};
}

sub do_work {
    # ...
}

#
# load from app.conf
#
sub load_config {
    my $conf_file = 'app.conf';
    die "cannot find config file" unless -e $conf_file;
    $conf = eval path($conf_file)->slurp_utf8;
    $opt  = $conf->{$Script};
}
