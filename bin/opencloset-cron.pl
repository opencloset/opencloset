#!perl
# ABSTRACT: OpenCloset cron scheduler
# PODNAME: opencloset-cron.pl

BEGIN {
    $ENV{PERL_OBJECT_EVENT_DEBUG} = 2;
    $ENV{PERL_JSON_BACKEND}       = 'JSON::PP';
}

use v5.18;
use utf8;
use strict;
use warnings;

use FindBin qw( $Bin $Script );
use Getopt::Long::Descriptive;

use AnyEvent;

use OpenCloset::Cron;
use OpenCloset::Cron::Worker;
use OpenCloset::Util;

my $CONF = OpenCloset::Util::load_config(
    "$Bin/../app.conf",
    $Script,
    ping_port => 5001,
    delay     => 10,
    ae_log    => 'filter=debug:log=stderr',
    cron      => {},
);

my $ping_port //= $CONF->{ping_port};
my $delay     //= $CONF->{delay};
my $ae_log    //= $CONF->{ae_log};

my ( $opt, $usage ) = describe_options(
    "%c %o ...",
    [ 'ping-port=i', "ping port (default: $ping_port)",           { default => $ping_port } ],
    [ 'delay=i',     "database check interval (default: $delay)", { default => $delay     } ],
    [ 'ae-log=s',    "anyevent log (default: $ae_log)",           { default => $ae_log    } ],
    [],
    [ 'help|h',    'print usage message and exit' ],
);
print( $usage->text ), exit if $opt->help;

OpenCloset::Util->set_ae_log( $opt->ae_log );

my @workers;
for my $k ( keys %{ $CONF->{cron} } ) {
    next unless $CONF->{cron}{$k};

    my $worker = OpenCloset::Cron::Worker->new(
        name => $k,
        cron => $CONF->{cron}{$k},
        cb   => sub {
            AE::log( debug => "$k: hello world!" );
        },
    );

    push @workers, $worker;
}

my $cron = OpenCloset::Cron->new(
    delay      => $opt->delay,
    ping_port  => $opt->ping_port,
    workers    => \@workers,
);
$cron->add_ping(sub { 1 });
$cron->start;
