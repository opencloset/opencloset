#!/usr/bin/env perl

use utf8;
use strict;
use warnings;

use FindBin qw( $Bin $Script );

use OpenCloset::Config;
use OpenCloset::Schema;

binmode STDOUT, ':utf8';
binmode STDERR, ':utf8';

my $config_file = shift || "$Bin/../app.conf";
my $order_id = shift;

die "Usage: $Script <config path> <order_id>\n"
    unless ( $config_file && -f $config_file && $order_id );

my $occ = OpenCloset::Config->new( file => $config_file );

{
    my $dbic_conf = $occ->dbic;
    die "$config_file: database is needed\n" unless $dbic_conf;

    my $DB = OpenCloset::Schema->connect($dbic_conf);

    print "----\n";
    print "$order_id\n";
    print "  BEFORE:\n";
    print_order( $DB, $order_id );
    _do_work( $DB, $order_id );
    print "  AFTER:\n";
    print_order( $DB, $order_id );
};

sub _do_work {
    my ( $db, $order_id ) = @_;

    my $order = $db->resultset("Order")->find($order_id);
    die "cannot find order: $order_id\n" unless $order;
    die "order status is not '반납'\n" unless $order->status_id == 9;

    {
        my $guard = $db->txn_scope_guard;

        $order->update( { status_id => 42 } );

        my $order_price = 0;
        for my $od ( $order->order_details ) {
            $order_price += $od->final_price;

            next unless $od->clothes_code;

            $od->update( { status_id => 42 } );
        }

        $db->resultset("OrderDetail")->create(
            {
                order_id    => $order->id,
                name        => "환불",
                stage       => 3,
                price       => -$order_price,
                final_price => -$order_price,
                desc        => "환불 수수료: 0원",
                create_date => $order->return_date,
            }
        );

        $db->source("OrderStatusLog")->set_primary_key( "order_id", "status_id", "timestamp" );
        my $osl_rs = $db->resultset("OrderStatusLog")->search(
            {
                order_id  => $order->id,
                status_id => 9,
            },
        );
        {
            my $osl = $osl_rs->first;
            $osl->update( { status_id => 42 } ) if $osl;
        }

        my $osl_42_rs = $db->resultset("OrderStatusLog")->search(
            {
                order_id  => $order->id,
                status_id => 42,
            },
            {
                order_by => { -desc => qw/ timestamp / },
            },
        );
        my $latest_osl = $osl_42_rs->first;
        $latest_osl->delete if $latest_osl && $osl_42_rs->count > 1;

        $guard->commit;
    }
}

sub print_order {
    my ( $db, $order_id ) = @_;

    my $order = $db->resultset("Order")->find($order_id);
    die "cannot find order: $order_id\n" unless $order;

    printf(
        "  id(%d), status_id(%s), status(%s), rental_date(%s), return_date(%s)\n",
        $order->id,
        $order->status_id,
        $order->status->name,
        $order->rental_date,
        $order->return_date,
    );

    my $order_price = 0;
    for my $od ( $order->order_details ) {
        $order_price += $od->final_price;

        printf(
            "    id(%d), status(%s - %s), name(%s), code(%s), stage(%d), price(%d), final_price(%d), desc(%s), date(%s)\n",
            $od->id,
            $od->status_id || "N/A",
            $od->status ? $od->status->name : "N/A",
            $od->name,
            $od->clothes_code || "N/A",
            $od->stage,
            $od->price,
            $od->final_price,
            $od->desc        || "N/A",
            $od->create_date || "N/A",
        );
    }

    print "  final_price: $order_price\n";
}
