#!/usr/bin/env perl

use v5.18;
use utf8;
use strict;
use warnings;

use FindBin qw( $Script );

use DateTime::Duration;
use DateTime::Format::Duration;

use OpenCloset::Config;
use OpenCloset::Patch::DateTime::Format::Human::Duration;
use OpenCloset::Schema;

binmode STDOUT, ':utf8';
binmode STDERR, ':utf8';

die "Usage: $Script <config file> <list|remove> [ <order_id> [ <order_id> ... ]\n"
    unless @ARGV >= 3;

my ( $config_file, $cmd, @order_ids ) = @ARGV;
die "cannot find $config_file\n" unless -f $config_file;

my $CONF = OpenCloset::Config::load($config_file);
my $DB   = OpenCloset::Schema->connect({
    dsn      => $CONF->{database}{dsn},
    user     => $CONF->{database}{user},
    password => $CONF->{database}{pass},
    %{ $CONF->{database}{opts} },
});

for my $order_id (@order_ids) {
    my $order = $DB->resultset('Order')->find(
        $order_id,
        {
            prefetch => [
                'booking',
                'staff',
                'status',
                { 'user' => 'user_info' },
            ],
        }
    );
    unless ($order) {
        warn "cannot find such order: $order_id\n";
        next;
    }

    if ( $cmd eq 'list' ) {
        printf(<<"END_ORDER_FORMAT",
order_id: %d
  status:      %s
  staff:       %s
  booking:     %s
  create_date: %s
  update_date: %s
  user:
    name:        %s
    email:       %s
    phone:       %s
    create_date: %s
    update_date: %s
  analyze:
%s
END_ORDER_FORMAT
            $order->id,
            $order->status->name,
            ( $order->staff ? $order->staff->name : q{N/A} ),
            $order->booking->date,
            $order->create_date->set_time_zone('UTC')->set_time_zone('Asia/Seoul'),
            $order->update_date->set_time_zone('UTC')->set_time_zone('Asia/Seoul'),
            $order->user->name,
            $order->user->email            || q{N/A},
            $order->user->user_info->phone || q{N/A},
            $order->user->create_date->set_time_zone('UTC')->set_time_zone('Asia/Seoul'),
            $order->user->update_date->set_time_zone('UTC')->set_time_zone('Asia/Seoul'),
            analyze_order($order),
        );
    }
    elsif ( $cmd eq 'delete' ) {
        $order->delete;
    }
    else {
        die "allowed commands: [list|delete]\nunknown command: $cmd\n";
    }
}

sub analyze_order {
    my $order = shift;

    my $ret_str = q{};

    my %result = $order->analyze_order_status_logs;
    #
    # check each logs
    #
    my @normalize_status_list;
    for my $log ( @{ $result{logs} } ) {
        my $status           = $log->{status};           # status name
        my $normalize_status = $log->{normalize_status}; # normalize status name
        my $timestamp        = $log->{timestamp};        # DateTime object
        my $delta            = $log->{delta};            # seconds
                                                         # undef means last status
        if ($delta) {
            my ( $hms, $locale ) = convert_sec($delta);

            $ret_str .= sprintf "$status\n";
            $ret_str .= sprintf "  | $hms $locale\n";
            $ret_str .= sprintf "  V\n";
        }
        else {
            $ret_str .= sprintf "$status\n";
        }

        push @normalize_status_list, $normalize_status;
    }
    #
    # check elapsed time
    #
    $ret_str .= sprintf "\n";
    for my $normalize_status (@normalize_status_list) {
        my ( $hms, $locale ) = convert_sec( $result{elapsed_time}{$normalize_status} );

        my $space_len = 8 - ( length($normalize_status) * 2 );

        $ret_str .= sprintf "%s%s: $hms $locale\n", q{ } x $space_len, $normalize_status;
    }

    $ret_str =~ s/^/    /gms;

    return $ret_str;
}

sub convert_sec {
    my $seconds = shift;

    my $dfd   = DateTime::Format::Duration->new( normalize => 'ISO', pattern => '%M:%S' );
    my $dur1  = DateTime::Duration->new( seconds => $seconds );
    my $dur2  = DateTime::Duration->new( $dfd->normalize($dur1) );
    my $dfhd  = OpenCloset::Patch::DateTime::Format::Human::Duration->new;
    my $hms  = sprintf(
        '%02d:%s',
        $seconds / 3600,
        $dfd->format_duration( DateTime::Duration->new( $dfd->normalize($dur1) ) ),
    );

    my $locale = $dfhd->format_duration($dur2, locale => "ko" );
    $locale =~ s/\s*(년|개월|주|일|시간|분|초|나노초)/$1/gms;
    $locale =~ s/\s+/ /gms;
    $locale =~ s/,//gms;

    return ( $hms, $locale );
}
