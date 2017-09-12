#!/usr/bin/env perl
use utf8;
use strict;
use warnings;
use DateTime;
use FindBin qw( $Bin );
use Getopt::Long;
use Pod::Usage;

use OpenCloset::Config;
use OpenCloset::Schema;

use OpenCloset::API::Order;
use OpenCloset::Constants::Status qw/$BOX $BOXED $PAYMENT $RENTAL/;

my $config_file = "$Bin/../app.conf";
die "cannot find $config_file\n" unless -f $config_file;

our %STATUS_MAP = (
    box     => $BOX,
    BOX     => $BOX,
    boxed   => $BOXED,
    BOXED   => $BOXED,
    payment => $PAYMENT,
    PAYMENT => $PAYMENT,
    rental  => $RENTAL,
    RENTAL  => $RENTAL,
);

my %options;
GetOptions(
    \%options,
    "--help",
    "--status=s",
    "--extension=i",
    "--overdue=i",
    "--userid=i"
);

run( \%options, @ARGV );

sub run {
    my ( $opts, @args ) = @_;
    return pod2usage(0) if $opts->{help};

    my $conf   = OpenCloset::Config::load($config_file);
    my $schema = OpenCloset::Schema->connect(
        {
            dsn      => $conf->{database}{dsn},
            user     => $conf->{database}{user},
            password => $conf->{database}{pass},
            %{ $conf->{database}{opts} },
        }
    );

    my $today = DateTime->today( time_zone => 'Asia/Seoul' );
    my $booking_date = $today->clone->set( hour => 10 );
    my $booking = $schema->resultset('Booking')->find_or_create(
        {
            date   => "$booking_date",
            gender => 'male',
            slot   => 4,
        }
    );

    my $user_id = $opts->{userid} || 2;
    my $order = $schema->resultset('Order')->create(
        {
            user_id               => $user_id,
            status_id             => $BOX,
            staff_id              => 2,
            parent_id             => undef,
            booking_id            => $booking->id,
            coupon_id             => undef,
            user_address_id       => undef,
            online                => 0,
            additional_day        => 0,
            rental_date           => undef,
            wearon_date           => $today->clone->add( days => 1 )->datetime,
            target_date           => undef,
            user_target_date      => undef,
            return_date           => undef,
            return_method         => undef,
            return_memo           => undef,
            price_pay_with        => undef,
            late_fee_pay_with     => undef,
            compensation_pay_with => undef,
            pass                  => undef,
            desc                  => undef,
            message               => undef,
            misc                  => undef,
            shipping_misc         => undef,
            purpose               => '입사면접',
            purpose2              => undef,
            pre_category          => 'jacket,pants,shirt,shoes',
            pre_color             => 'black',
            height                => 180,
            weight                => 70,
            neck                  => undef,
            bust                  => 89,
            waist                 => 82,
            hip                   => undef,
            topbelly              => 79,
            belly                 => undef,
            thigh                 => 53,
            arm                   => 62,
            leg                   => 99,
            knee                  => undef,
            foot                  => 270,
            pants                 => undef,
            skirt                 => undef,
            bestfit               => undef,
            ignore                => undef,
            ignore_sms            => undef,
            does_wear             => undef,
        }
    );

    print $order->id, "\n";

    my $status = $STATUS_MAP{ $opts->{status} || '' };
    return unless $status;

    my @codes = @args;
    @codes = qw/0J001 0P001 0S003 0A001/ unless @codes;
    my $api = OpenCloset::API::Order->new( schema => $schema, notify => 0, sms => 0 );
    $api->box2boxed( $order, \@codes );
    return if $status == $BOXED;

    $api->boxed2payment($order);
    return if $status == $PAYMENT;

    $api->payment2rental( $order, price_pay_with => '현금' );

    my $date = $today->clone->set( hour => 23, minute => 59, second => 59 );
    my $extension = $opts->{extension} || 0;
    my $overdue   = $opts->{overdue}   || 0;
    my %params;

    if ($overdue) {
        $params{user_target_date} = $date->clone->subtract( days => $overdue )->datetime;
    }

    if ($extension) {
        $params{target_date} =
            $date->clone->subtract( days => $overdue + $extension )->datetime;
    }

    $order->update( \%params );
}

__END__

=encoding utf8

=head1 NAME

generate_order.pl - Generate order for test

=head1 SYNOPSIS

    $ generate_order.pl --status <status> --extension <days> --overdue <days> --userid <id> 의류코드...
      status: box | boxed | payment | rental
      userid: default is <2>
      의류코드: default is <0J001 0P001 0S003 0A001>

    $ generate_order.pl
    $ generate_order.pl -s boxed                    # 포장완료 주문서
    $ generate_order.pl -s boxed J002 P003          # 포장완료 주문서(의류는 J002 P003)
    $ generate_order.pl -s payment --userid 8212    # userid 8212 이고 결제대기
    $ generate_order.pl -s rental --overdue 3       # 3일 연체중인 주문서

=cut
