#!/usr/bin/env perl

use v5.18;
use strict;
use warnings;

use FindBin qw( $Script );

use OpenCloset::Util;
use OpenCloset::Schema;

binmode STDOUT, ':utf8';
binmode STDERR, ':utf8';

die "Usage: $Script <config file> <list|remove> [ <order_id> [ <order_id> ... ]\n"
    unless @ARGV >= 3;

my ( $config_file, $cmd, @order_ids ) = @ARGV;
die "cannot find $config_file\n" unless -f $config_file;

my $CONF = OpenCloset::Util::load_config($config_file);
my $DB   = OpenCloset::Schema->connect({
    dsn      => $CONF->{database}{dsn},
    user     => $CONF->{database}{user},
    password => $CONF->{database}{pass},
    %{ $CONF->{database}{opts} },
});

for my $order_id (@order_ids) {
    my $order = $DB->resultset('Order')->find($order_id);
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
        );
    }
    elsif ( $cmd eq 'delete' ) {
        $order->delete;
    }
    else {
        die "allowed commands: [list|delete]\nunknown command: $cmd\n";
    }
}
