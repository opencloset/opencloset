#!/usr/bin/env perl

use utf8;
use strict;
use warnings;

use FindBin qw( $Bin $Script );

use CHI;
use DateTime;
use Time::Piece;
use Try::Tiny;

use OpenCloset::Config;
use OpenCloset::Schema;

binmode STDOUT, ':utf8';
binmode STDERR, ':utf8';

my $config_file = shift || "$Bin/../app.conf";
my $ymd         = shift || localtime->ymd;

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

    my $from = $dt->clone->truncate( to => 'year' );
    my $to   = $dt->clone->truncate( to => 'day' );
    for ( ; $from <= $to; $from->add( days => 1 ) ) {
        my $f = $from->clone->truncate( to => 'day' );
        my $t = $from->clone->truncate( to => 'day' )->add( days => 1, seconds => -1 );

        next if $f >= $today;
        next if $t >= $today;

        my $result = count_visitor( $DB, $f, $t );
        use Data::Dumper;
        print Dumper [ $f->ymd, $t->ymd, $result ];
        last;
    }
}

=cut

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

    # 01/01 ~ specified day
    my %count;
    my $from = $dt->clone->truncate( to => 'year' );
    my $to   = $dt->clone->truncate( to => 'day' );
    for ( ; $from <= $to; $from->add( days => 1 ) ) {
        my $f = $from->clone->truncate( to => 'day' );
        my $t = $from->clone->truncate( to => 'day' )->add( days => 1, seconds => -1 );

        next if $f >= $today;
        next if $t >= $today;

        my $f_str = $f->strftime('%Y%m%d%H%M%S');
        my $t_str = $t->strftime('%Y%m%d%H%M%S');
        my $name  = "day-$f_str-$t_str";
        my $count = $CACHE->compute(
            $name,
            undef,
            sub {
                print "caching: $name\n";
                count_visitor( $DB, $f, $t );
            },
        );

        push @{ $count{day} }, $count;
    }

    # from first to current week of specified year
    for ( my $i = $dt->clone->truncate( to => 'year'); $i <= $today; $i->add( weeks => 1 ) ) {
        my $f = $i->clone->truncate( to => 'week' );
        my $t = $i->clone->truncate( to => 'week' )->add( weeks => 1, seconds => -1 );

        next if $f >= $today;
        next if $t >= $today;

        my $f_str = $f->strftime('%Y%m%d%H%M%S');
        my $t_str = $t->strftime('%Y%m%d%H%M%S');
        my $name  = "week-$f_str-$t_str";
        my $count = $CACHE->compute(
            $name,
            undef,
            sub {
                print "caching: $name\n";
                count_visitor( $DB, $f, $t );
            },
        );

        push @{ $count{week} }, $count;
    }

    # from january to current months of this year
    for ( my $i = $dt->clone->truncate( to => 'year'); $i <= $today; $i->add( months => 1 ) ) {
        my $f = $i->clone->truncate( to => 'month' );
        my $t = $i->clone->truncate( to => 'month' )->add( months => 1, seconds => -1 );

        next if $f >= $today;
        next if $t >= $today;

        my $f_str = $f->strftime('%Y%m%d%H%M%S');
        my $t_str = $t->strftime('%Y%m%d%H%M%S');
        my $name  = "month-$f_str-$t_str";
        my $count = $CACHE->compute(
            $name,
            undef,
            sub {
                print "caching: $name\n";
                count_visitor( $DB, $f, $t );
            },
        );

        push @{ $count{month} }, $count;
    }
};

=cut

sub count_visitor {
    my ( $DB, $start_dt, $end_dt, $cb ) = @_;

    my $dtf        = $DB->storage->datetime_parser;
    my $booking_rs = $DB->resultset('Booking')->search(
        {
            date => {
                -between => [
                    $dtf->format_datetime($start_dt),
                    $dtf->format_datetime($end_dt),
                ],
            },
        },
        {
            prefetch       => {
                'orders' => {
                    'user' => 'user_info'
                }
            },
        },
    );

    my %count = (
        all        => { total => 0, male => 0, female => 0 },
        visited    => { total => 0, male => 0, female => 0 },
        notvisited => { total => 0, male => 0, female => 0 },
        bestfit    => { total => 0, male => 0, female => 0 },
        loanee     => { total => 0, male => 0, female => 0 },
    );
    while ( my $booking = $booking_rs->next ) {
        for my $order ( $booking->orders ) {
            next unless $order->user->user_info;

            my $gender = $order->user->user_info->gender;
            next unless $gender;

            ++$count{all}{total};
            ++$count{all}{$gender};

            if ( $order->rental_date ) {
                ++$count{loanee}{total};
                ++$count{loanee}{$gender};
            }

            if ( $order->bestfit ) {
                ++$count{bestfit}{total};
                ++$count{bestfit}{$gender};
            }

            use feature qw( switch );
            use experimental qw( smartmatch );
            given ( $order->status_id ) {
                when (/^12|14$/) {
                    ++$count{notvisited}{total};
                    ++$count{notvisited}{$gender};
                }
            }

            $cb->( $booking, $order, $gender ) if $cb && ref($cb) eq 'CODE';
        }
    }
    $count{visited}{total}  = $count{all}{total}  - $count{notvisited}{total};
    $count{visited}{male}   = $count{all}{male}   - $count{notvisited}{male};
    $count{visited}{female} = $count{all}{female} - $count{notvisited}{female};

    return \%count;
};
