#!/usr/bin/env perl

use utf8;
use strict;
use warnings;

use FindBin qw( $Bin $Script );

use CHI;
use DateTime;
use List::Util;
use Time::Piece;
use Try::Tiny;

use OpenCloset::Config;
use OpenCloset::Schema;

binmode STDOUT, ':utf8';
binmode STDERR, ':utf8';

my $config_file = shift || "$Bin/../app.conf";
my $ymd         = shift || localtime->ymd;
my $prefix      = 'stat-status';

die "Usage: $Script <config path> [ <yyyy-mm-dd> ] \n"
    unless (
        $config_file
        && -f $config_file
        && $ymd
        && $ymd =~ m/^\d{4}-\d{2}-\d{2}$/
    );

my $CONF = OpenCloset::Config::load($config_file);
die "$config_file: cannot load config\n" unless $CONF;

{
    my $DB_CONF   = $CONF->{database};
    my $TIMEZONE  = $CONF->{timezone};
    my $CACHE_DIR = $CONF->{cache}{dir};

    die "$config_file: database is needed\n"  unless $DB_CONF;
    die "$config_file: timezone is needed\n"  unless $TIMEZONE;
    die "$config_file: cache.dir is needed\n" unless $CACHE_DIR;

    my $DB = OpenCloset::Schema->connect(
        {
            dsn      => $DB_CONF->{dsn},
            user     => $DB_CONF->{user},
            password => $DB_CONF->{pass},
            %{ $DB_CONF->{opts} },
        }
    );

    my $CACHE = CHI->new(
        driver   => 'File',
        root_dir => $CACHE_DIR,
    );

    $ymd =~ m/^(\d{4})-(\d{2})-(\d{2})$/;
    my $year  = $1;
    my $month = $2;
    my $day   = $3;

    my $dt = try {
        DateTime->new(
            time_zone => $TIMEZONE,
            year      => $year,
            month     => $month,
            day       => $day,
        );
    };
    die "cannot create datetime object\n" unless $dt;

    my $today = try {
        DateTime->now(
            time_zone => $TIMEZONE,
        );
    };
    die "cannot create datetime object: today\n" unless $today;
    $today->truncate( to => 'day' );

    my %count;
    my $from = $dt->clone->truncate( to => 'year' );
    my $to   = $dt->clone->truncate( to => 'day' );
    my $basis_dt = try {
        DateTime->new(
            time_zone => $TIMEZONE,
            year      => 2015,
            month     => 5,
            day       => 29,
        );
    };

    # 01/01 ~ specified day
    for ( ; $from <= $to; $from->add( days => 1 ) ) {
        my $f = $from->clone->truncate( to => 'day' );
        my $t = $from->clone->truncate( to => 'day' )->add( days => 1, seconds => -1 );
        my $online_order_hour = $f >= $basis_dt ? 22 : 19;

        next if $f >= $today;
        next if $t >= $today;

        my $f_str = $f->strftime('%Y%m%d%H%M%S');
        my $t_str = $t->strftime('%Y%m%d%H%M%S');
        my $name  = "$prefix-day-$f_str-$t_str";
        my $count = $CACHE->compute(
            $name,
            undef,
            sub {
                print "caching: $name\n";
                mean_status( $DB, $f, $t, $online_order_hour );
            },
        );

        push @{ $count{day} }, $count;
    }

    # from first to current week of specified year
    for ( my $i = $dt->clone->truncate( to => 'year'); $i <= $today; $i->add( weeks => 1 ) ) {
        my $f = $i->clone->truncate( to => 'week' );
        my $t = $i->clone->truncate( to => 'week' )->add( weeks => 1, seconds => -1 );
        my $online_order_hour = $f >= $basis_dt ? 22 : 19;

        next if $f >= $today;
        next if $t >= $today;

        my $f_str = $f->strftime('%Y%m%d%H%M%S');
        my $t_str = $t->strftime('%Y%m%d%H%M%S');
        my $name  = "$prefix-week-$f_str-$t_str";
        my $count = $CACHE->compute(
            $name,
            undef,
            sub {
                print "caching: $name\n";
                mean_status( $DB, $f, $t, $online_order_hour );
            },
        );

        push @{ $count{week} }, $count;
    }

    # from january to current months of this year
    for ( my $i = $dt->clone->truncate( to => 'year'); $i <= $today; $i->add( months => 1 ) ) {
        my $f = $i->clone->truncate( to => 'month' );
        my $t = $i->clone->truncate( to => 'month' )->add( months => 1, seconds => -1 );
        my $online_order_hour = $f >= $basis_dt ? 22 : 19;

        next if $f >= $today;
        next if $t >= $today;

        my $f_str = $f->strftime('%Y%m%d%H%M%S');
        my $t_str = $t->strftime('%Y%m%d%H%M%S');
        my $name  = "$prefix-month-$f_str-$t_str";
        my $count = $CACHE->compute(
            $name,
            undef,
            sub {
                print "caching: $name\n";
                mean_status( $DB, $f, $t, $online_order_hour );
            },
        );

        push @{ $count{month} }, $count;
    }
};

sub mean_status {
    my ( $DB, $start_dt, $end_dt, $online_order_hour ) = @_;

    my $dtf      = $DB->storage->datetime_parser;
    my $order_rs = $DB->resultset('Order')->search(
        {
            -and => [
                'booking.date' => {
                    -between => [ $dtf->format_datetime($start_dt), $dtf->format_datetime($end_dt), ],
                },
                \[ 'HOUR(`booking`.`date`) != ?', $online_order_hour ],
            ]
        },
        {
            join     => [qw/ booking /],
            order_by => { -asc => 'date' },
            prefetch => 'booking',
        },
    );

    my @status_list = qw( 대기 치수측정 의류준비 탈의 수선 포장 결제 );

    my %total;
    while ( my $order = $order_rs->next ) {
        my %analyze = $order->analyze_order_status_logs;
        next unless $analyze{elapsed_time};

        for my $status (@status_list) {
            next unless $analyze{elapsed_time}{$status};

            push @{ $total{$status} }, $analyze{elapsed_time}{$status};
        }
    }

    my %count  = (
        '대기'       => 0,
        '치수측정'   => 0,
        '의류준비'   => 0,
        '탈의'       => 0,
        '수선'       => 0,
        '포장'       => 0,
        '결제'       => 0,
    );
    for my $status ( keys %total ) {
        my $n = scalar(@{$total{$status}});

        $count{$status} = List::Util::sum(@{ $total{$status} }) / $n;
    }
    $count{total} = List::Util::sum( values %count );

    return \%count;
}
