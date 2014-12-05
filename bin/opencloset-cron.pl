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
use HTTP::Tiny;
use JSON;

use OpenCloset::Cron;
use OpenCloset::Cron::Worker;
use OpenCloset::Util;

my $config_file = shift || "$Bin/../app.conf";
die "cannot find $config_file\n" unless -f $config_file;

my $CONF = OpenCloset::Util::load_config(
    $config_file,
    $Script,
    ping_port => 5001,
    delay     => 10,
    ae_log    => 'filter=debug:log=stderr',
    workers   => {},
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

my %workers;
for my $k ( keys %{ $CONF->{workers} } ) {
    next unless $CONF->{workers}{$k};

    my $worker = OpenCloset::Cron::Worker->new(
        name => $k,
        cron => $CONF->{workers}{$k}{cron},
    );

    $workers{$k} = $worker;
}

$workers{send_sms_to_late_users}->cb( \&cb_send_sms_to_late_users );

my $cron = OpenCloset::Cron->new(
    delay      => $opt->delay,
    ping_port  => $opt->ping_port,
    workers    => [ values %workers ],
);
$cron->add_ping(sub { 1 });
$cron->start;

sub cb_send_sms_to_late_users {
    my $worker_name = 'send_sms_to_late_users';
    my $conf        = $CONF->{workers}{$worker_name};

    my $from     = $conf->{from},
    my $base_url = $conf->{base_url};
    my $timeout  = $conf->{timeout};
    my $text_fmt = $conf->{text_fmt};

    unless ($from) {
        AE::log( warn => "$worker_name: config from is needed" );
        return;
    }

    unless ($base_url) {
        AE::log( warn => "$worker_name: config base_url is needed" );
        return;
    }

    unless ($timeout) {
        AE::log( warn => "$worker_name: config timeout is needed" );
        return;
    }

    my $res = HTTP::Tiny->new( timeout => $timeout )->get( "$base_url/search/user/late.json" );
    unless ( $res->{success} ) {
        AE::log( warn => "$worker_name: fetching late user failed: %s", $res->{reason} );
        return;
    }

    AE::log( debug => "$worker_name: fetching late user" );

    my $data = decode_json( $res->{content} );
    for my $user (@$data) {
        my $res = HTTP::Tiny->new( timeout => 3 )->post_form(
            "$base_url/sms.json",
            {
                from   => "$from",
                to     => "$user->{phone}",
                text   => sprintf( $text_fmt, $user->{name} ),
                status => 'pending',
            },
        );
        if ( $res->{success} ) {
            AE::log( debug => "$worker_name: pending sms [$from]->[$user->{phone}]" );
        }
        else {
            AE::log( debug => "$worker_name: failed to send sms [$from]->[$user->{phone}]" );
        }
    }
}
