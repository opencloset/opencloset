#!/usr/bin/env perl

#
# 월 단위로 3회 이상 대여로 할인 받은 인원과 금액의 확인 (#957)
#

use v5.18;
use utf8;
use strict;
use warnings;

use FindBin qw( $Script );

use DateTime;

use OpenCloset::Config;
use OpenCloset::Schema;

binmode STDOUT, ':utf8';
binmode STDERR, ':utf8';

my $BASE_URL = "http://monster.silex.kr:10301";

die "Usage: $Script <config file> <year> <month>\n"
    unless @ARGV == 3;

my ( $config_file, $year, $month ) = @ARGV;
die "cannot find $config_file\n" unless -f $config_file;

my $CONF = OpenCloset::Config::load($config_file);
my $DB   = OpenCloset::Schema->connect(
    {
        dsn      => $CONF->{database}{dsn},
        user     => $CONF->{database}{user},
        password => $CONF->{database}{pass},
        %{ $CONF->{database}{opts} },
    },
);

my $dt_start = DateTime->new(
    year      => $year,
    month     => $month,
    time_zone => $CONF->{timezone},
);

my $dt_end =
    $dt_start->clone->truncate( to => 'day' )->add( months => 1, seconds => -1 );

my $dtf      = $DB->storage->datetime_parser;
my $order_rs = $DB->resultset('Order')->search(
    {
        "booking.id"     => { "!=" => undef },
        "me.rental_date" => { "!=" => undef },
        "me.coupon_id"   => undef,
        "me.parent_id"   => undef,
        "booking.date"   => {
            -between => [ $dtf->format_datetime($dt_start), $dtf->format_datetime($dt_end) ],
        },
    },
    {
        join => [
            "booking",
            "coupon",
        ],
        prefetch => [
            "booking",
            "coupon",
        ],
        order_by => [
            "me.rental_date",
        ],
    },
);

my @result;
my @strange_result;
my $total_sale = 0;
while ( my $order = $order_rs->next ) {

    my $original_price = 0;
    my $final_price    = 0;
    for my $od ( $order->order_details->search( { stage => 0 } )->all ) {
        my $clothes = $od->clothes;
        if ($clothes) {
            my $price = $clothes->price;
            if ( $clothes->category eq "tie" ) {
                if ( $od->final_price != 0 ) {
                    # 넥타이 가격이 0원이 아닌 경우 직원이 수정한 것임
                    if ( $od->price == 0 ) {
                        # 직원이 대여 가격을 수정하지 않고 소계를 수정한 경우
                        $price = $od->final_price;
                    }
                    else {
                        # 직원이 소계를 수정한 경우
                        $price = $od->price;
                    }
                }
            }
            $original_price += $price * ( 1 + 0.2 * $order->additional_day );
        }
        else {
            $original_price += $od->final_price;
        }
        $final_price += $od->final_price;
    }

    next if $original_price == $final_price;
    next
        if $final_price == 0
        ; # 이유는 알 수 없지만 발생하는 경우가 있음. ex) 39008 주문서

    my $sale      = $original_price - $final_price;
    my $sale_rate = $sale / $original_price * 100;

    my $item = sprintf(
        "%6d %s %6s원 %5.1f%% 할인, %6s -> %6s %s %s",
        $order->id,
        $order->rental_date->ymd,
        commify($sale),
        $sale_rate,
        commify($original_price),
        commify($final_price),
        sprintf( "$BASE_URL/order/%d", $order->id ),
        $order->user->name,
    );

    #
    # 할인 폭이 50%를 넘어가는 경우는 3회 이상 대여가 아닐 가능성이 높음
    #
    if ( $sale_rate >= 50 ) {
        push @strange_result, $item;
        next;
    }

    $total_sale += $sale;

    push @result, $item;
}

printf(
    "%04d-%02d 주문서 (3회 대여 할인 개수 / 총 개수): %d / %d, %5.1f%%, %s 원\n",
    $year,
    $month,
    scalar(@result),
    $order_rs->count,
    ( @result / $order_rs->count * 100 ),
    commify($total_sale),
);
say hr();
say for @result;

printf "\n\n";

printf(
    "%04d-%02d 할인율이 50%% 이상이 넘는 주문서: %d / %d, %5.1f%%\n",
    $year,
    $month,
    scalar(@strange_result),
    $order_rs->count,
    ( @strange_result / $order_rs->count * 100 ),
);
say hr();
say for @strange_result;

sub commify {
    local $_ = shift;
    1 while s/((?:\A|[^.0-9])[-+]?\d+)(\d{3})/$1,$2/s;
    return $_;
}

sub hr {
    return "-" x 78;
}
