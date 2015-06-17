#!/usr/bin/env perl

use v5.18;
use strict;
use warnings;

use FindBin qw( $Bin $Script );
use HTTP::Tiny;
use JSON;
use SMS::Send::KR::CoolSMS;
use SMS::Send;
use Unicode::GCString;
use Unicode::Normalize;

use OpenCloset::Util;

binmode STDOUT, ':utf8';
binmode STDERR, ':utf8';

my $config_file = shift || "$Bin/../app.conf";
die "cannot find $config_file\n" unless -f $config_file;

my $CONF = OpenCloset::Util::load_config(
    $config_file,
    $Script,
    delay      => 60,
    send_delay => 1,
);

my $continue = 1;
$SIG{TERM} = sub { $continue = 0;        };
$SIG{HUP}  = sub {
    $CONF = OpenCloset::Util::load_config(
        $config_file,
        $Script,
        delay      => 60,
        send_delay => 1,
    );
};

while ($continue) {
    do_work();
    sleep $CONF->{delay};
}

sub do_work {
    for my $sms ( get_pending_sms_list() ) {
        print STDERR "$CONF->{fake_sms},$sms->{id},$sms->{from},$sms->{to},$sms->{text}\n";

        #
        # updating status to sending
        #
        my $ret = update_sms( $sms, status => 'sending' );
        next unless $ret;

        #
        # sending sms
        #
        # if fake_sms is set then fake sending sms
        # then return true always
        #
        $ret = !$CONF->{fake_sms} ? send_sms($sms) : 1;
        next unless $ret;

        #
        # updating status to sent and set return value
        #
        update_sms(
            $sms,
            status    => 'sent',
            ret       => $ret || 0,
            sent_date => time,
        );

        sleep $CONF->{send_delay};
    }
}

#
# fetch pending sms list
#
sub get_pending_sms_list {
    my $res = HTTP::Tiny->new->get(
        "$CONF->{base_url}/search/sms.json?"
        . HTTP::Tiny->www_form_urlencode({
            status   => 'pending',
            email    => $CONF->{email},
            password => $CONF->{password},
        })
    );
    return unless $res->{success};

    my $sms_list = decode_json( $res->{content} );

    return @$sms_list;
}

sub update_sms {
    my ( $sms, %params ) = @_;

    return unless $sms;
    return unless %params;

    %params = (
        email    => $CONF->{email},
        password => $CONF->{password},
        %params,
    );

    my $id = $sms->{id};
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

    my $type = 'SMS';
    {
        my $val = $sms->{text};

        my $nfc  = Unicode::Normalize::NFC($val);
        my $gcs  = Unicode::GCString->new($nfc);
        my $cols = $gcs->columns;

        $type = 'LMS' if $cols > 88;
    }

    my $sender = SMS::Send->new(
        'KR::CoolSMS',
        _api_key    => $CONF->{api_key},
        _api_secret => $CONF->{api_secret},
        _from       => $sms->{from},
        _type       => $type,
    );

    my $sent = $sender->send_sms(
        to   => $sms->{to},
        text => $sms->{text},
    );

    return $sent->{success};
}
