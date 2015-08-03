#!/usr/bin/env perl

use utf8;
use strict;
use warnings;

use DDP;
use FindBin qw( $Bin $Script );

use OpenCloset::Config;
use OpenCloset::Schema;
use OpenCloset::Size::Guess;

binmode STDOUT, ':utf8';
binmode STDERR, ':utf8';

my $config_file = shift || "$Bin/../app.conf";
my $gender      = shift;
my $height      = shift;
my $weight      = shift;

die "Usage: $Script <config path> <gender> <height> <weight>\n"
    unless ( $config_file
    && -f $config_file
    && $gender
    && $gender =~ m/^(male|female)$/
    && $height
    && $weight );

my $CONF = OpenCloset::Config::load($config_file);
die "$config_file: cannot load config\n" unless $CONF;

{
    my $DB_CONF  = $CONF->{database};
    my $TIMEZONE = $CONF->{timezone};

    die "$config_file: database is needed\n" unless $DB_CONF;
    die "$config_file: timezone is needed\n" unless $TIMEZONE;

    my $DB = OpenCloset::Schema->connect(
        {
            dsn      => $DB_CONF->{dsn},
            user     => $DB_CONF->{user},
            password => $DB_CONF->{pass},
            %{ $DB_CONF->{opts} },
        }
    );

    # Create a guesser
    my $guesser = OpenCloset::Size::Guess->new(
        'DB',
        height     => $height,
        weight     => $weight,
        gender     => $gender,
        _time_zone => $TIMEZONE,
        _schema    => $DB,
    );

    my $info = $guesser->guess;
    p $info;
}

{
    my $BODYKIT = $CONF->{bodykit};

    die "$config_file: bodykit is needed\n" unless $BODYKIT;

    # Create a guesser
    my $guesser = OpenCloset::Size::Guess->new(
        'BodyKit',
        height     => $height,
        weight     => $weight,
        gender     => $gender,
        _accessKey => $BODYKIT->{accessKey},
        _secret    => $BODYKIT->{secret},
    );

    my $info = $guesser->guess;
    p $info;
}
