#!/usr/bin/env perl

use v5.18;
use strict;
use warnings;

use FindBin qw( $Script );
use HTTP::Tiny;
use JSON;
use Path::Tiny;
use SMS::Send::KR::CoolSMS;
use SMS::Send;

my $CONF = load_config();

my $continue = 1;
$SIG{TERM} = sub { $continue = 0;        };
$SIG{HUP}  = sub { $CONF = load_config() };
while ($continue) {
    do_work();
    sleep $CONF->{delay};
}

#
# load from app.conf
#
sub load_config {
    my $conf_file = 'app.conf';
    die "cannot find config file" unless -e $conf_file;
    my $conf = eval path($conf_file)->slurp_utf8;

    # default
    $conf->{$Script}{delay}      //= 60;
    $conf->{$Script}{send_delay} //= 1;

    return $conf->{$Script};
}

sub do_work {
    for my $sms ( get_pending_sms_list() ) {
        #
        # updating status to sending
        #
        my $ret = update_sms( $sms, status => 'sending' );
        next unless $ret;

        #
        # sending sms
        #
        $ret = send_sms($sms);
        next unless $ret;

        #
        # updating status to sent and set return value
        #
        update_sms( $sms, status => 'sent', ret => $ret || 0 );

        sleep $CONF->{send_delay};
    }
}

#
# fetch pending sms list
#
sub get_pending_sms_list {
    my $res = HTTP::Tiny->new->get(
        "$CONF->{base_url}/search/sms.json?"
        . HTTP::Tiny->www_form_urlencode({ status => 'pending' })
    );
    return unless $res->{success};

    my $sms_list = decode_json( $res->{content} );

    return @$sms_list;
}

sub update_sms {
    my ( $sms, %params ) = @_;

    return unless $sms;
    return unless %params;

    my $id = $sms->id;
    my $res = HTTP::Tiny->new->put(
        "$CONF->{base_url}/sms/$id.json",
        {
            content => HTTP::Tiny->www_form_urlencode(\%params),
            headers => { 'content-type' => 'application/x-www-form-urlencoded' },
        },
    );

    return $res->{success};
}

sub send_sms {
    my $sms = shift;

    return unless $sms;
    return unless $sms->{from};
    return unless $sms->{to};
    return unless $sms->{text};

    my $sender = SMS::Send->new(
        'KR::CoolSMS',
        _ssl      => 1,
        _user     => $CONF->{user},
        _password => $CONF->{pass},
        _type     => 'sms',
        _from     => $sms->{from},
    );

    my $sent = $sender->send_sms(
        to   => $sms->{to},
        text => $sms->{text},
    );

    return $sent->{success};
}
