#!/usr/bin/env perl

use utf8;
use strict;
use warnings;

use FindBin qw( $Bin $Script );

use CHI;
use DateTime::TimeZone;
use DateTime;
use Try::Tiny;

use OpenCloset::Config;
use OpenCloset::Schema;

binmode STDOUT, ':utf8';
binmode STDERR, ':utf8';

my $config_file = shift || "$Bin/../app.conf";

die "Usage: $Script <config path>\n"
    unless (
        $config_file
        && -f $config_file
    );

my $CONF = OpenCloset::Config::load($config_file);
die "$config_file: cannot load config\n" unless $CONF;

{
    my $DB_CONF    = $CONF->{database};
    my $TIMEZONE   = $CONF->{timezone};
    my $CACHE_DIR  = $CONF->{cache}{dir};
    my $START_DATE = $CONF->{start_date};

    die "$config_file: database is needed\n"   unless $DB_CONF;
    die "$config_file: timezone is needed\n"   unless $TIMEZONE;
    die "$config_file: cache.dir is needed\n"  unless $CACHE_DIR;
    die "$config_file: start_date is needed\n" unless $START_DATE;

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

    my $today = try {
        DateTime->now(
            time_zone => $TIMEZONE,
        );
    };
    die "cannot create datetime object: today\n" unless $today;
    $today->truncate( to => 'day' );

    my $start_date = try {
        DateTime->new(
            year      => $START_DATE->{year},
            month     => $START_DATE->{month},
            day       => $START_DATE->{day},
            time_zone => $START_DATE->{time_zone},
        );
    };
    die "cannot create datetime object: start_date\n" unless $start_date;

    my %clothes_list;
    my $clothes_rs = $DB->resultset("Clothes")->search(
        {
            gender   => [ qw/ male female / ],
            category => [ qw/ jacket pants skirt / ],
        },
        {},
    );
    while ( my $clothes = $clothes_rs->next ) {
        use feature qw( switch );
        use experimental qw( smartmatch );

        print "calculating: " . $clothes->code . "\n";

        my %data = (
            code     => $clothes->code,
            rentable => $clothes->rentable_duration( $today, $start_date ),
            rented   => $clothes->rented_duration($TIMEZONE),
            ratio    => $clothes->rent_ratio( $today, $start_date ),
        );

        push @{ $clothes_list{ $clothes->gender }{ $clothes->category } }, \%data;
    }

    for my $gender (qw/ male female /) {
        for my $category (qw/ jacket pants skirt /) {
            my $data = $clothes_list{$gender}{$category};
            next unless $data && ref($data) eq "ARRAY";

            print "sorting: $gender - $category\n";
            my @sorted_clothes_list = sort { $a->{ratio} <=> $b->{ratio} } @$data;

            #
            # cache name:
            #   ex) stat-clothes-rent-male-jacket-2016-07-06-+0900
            #
            my $name = sprintf(
                "stat-clothes-rent-%s-%s-%s-%s",
                $gender,
                $category,
                $today->ymd,
                DateTime::TimeZone->offset_as_string(
                    $today->time_zone->offset_for_datetime($today)
                ),
            );

            print "caching: $name\n";
            $CACHE->set(
                $name,
                \@sorted_clothes_list,
            );
        }
    }
};
