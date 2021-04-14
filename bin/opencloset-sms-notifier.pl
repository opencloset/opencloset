#!/usr/bin/env perl

use v5.18;
use utf8;
use strict;
use warnings;

use FindBin qw( $Bin $Script );
use HTTP::Tiny;
use JSON;
use SMS::Send::KR::APIStore;
use SMS::Send::KR::CoolSMS;
use SMS::Send;
use Unicode::GCString;
use Unicode::Normalize;

use OpenCloset::Config;

binmode STDOUT, ':utf8';
binmode STDERR, ':utf8';

my $config_file = shift || "$Bin/../app.conf";
die "cannot find $config_file\n" unless -f $config_file;

my $CONF = OpenCloset::Config::load(
    $config_file,
    { root => $Script },
    delay      => 60,
    send_delay => 1,
);

my $continue = 1;
$SIG{TERM} = sub { $continue = 0;        };
$SIG{HUP}  = sub {
    $CONF = OpenCloset::Config::load(
        $config_file,
        { root => $Script },
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
        print STDERR "$CONF->{fake_sms},$CONF->{sms}{driver},$sms->{id},$sms->{from},$sms->{to},$sms->{text}\n";

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
        $ret = !$CONF->{fake_sms} ? send_sms($sms) : +{ success => 1, fake_sms => 1 };
        next unless $ret->{success};

        #
        # updating status to sent and set return value
        #
        update_sms(
            $sms,
            status    => 'sent',
            ret       => $ret->{success} || 0,
            method    => ( $CONF->{fake_sms} ? 'fake_sms' : $CONF->{sms}{driver} ),
            detail    => encode_json($ret),
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

        $type = 'LMS' if $cols > 80;
    }

    my $sender = SMS::Send->new(
        $CONF->{sms}{driver},
        %{ $CONF->{sms}{ $CONF->{sms}{driver} } },
        _from => $sms->{from},
        _type => $type,
    );

    my $sent = $sender->send_sms(
        to       => $sms->{to},
        text     => $sms->{text},
        _type    => $type,
        _subject => "[열린옷장]",
    );

    return $sent;
}
