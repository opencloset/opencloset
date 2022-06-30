#!/usr/bin/env perl

package
    App::OpenCloset::Coupon::Publish::script;

use common::sense;

use DateTime;
use Getopt::Long ();

sub new {
    my $class = shift;

    my $self = bless {
        # cli
        year   => 0,
        month  => 0,
        price  => 0,
        count  => 0,

        # internal
        action => q{},
        argv   => [],

        # override
        @_,
    }, $class;

    $self;
}

sub parse_options {
    my ( $self, @argv ) = @_;

    local @ARGV = @{$self->{argv}};
    push @ARGV, grep length, split /\s+/, $self->env('OPT');
    push @ARGV, @argv;

    Getopt::Long::Configure("bundling");
    Getopt::Long::GetOptions(
        'y|year=i'   => \$self->{year},
        'm|month=i'  => \$self->{month},
        'p|price=i'  => \$self->{price},
        'c|count=i'  => \$self->{count},
        'h|help'     => sub { $self->{action} = 'show_help' },
    );

    $self->{argv} = \@ARGV;
}

sub env {
    my ( $self, $key ) = @_;
    $ENV{"PERL_EVENT_OPENCLOSET_" . $key};
}

sub doit {
    my $self = shift;
    return $self->run;
}

sub run {
    my $self = shift;

    my $code;
    eval {
        $code = ($self->_doit == 0);
    }; if (my $e = $@) {
        warn $e;
        $code = 1;
    }

    $self->{status} = $code;
}


sub _doit {
    my $self = shift;

    if (my $action = $self->{action}) {
        $self->$action() and return 1;
    }

    use experimental qw( smartmatch );
    return $self->show_help(1)
        unless $self->{year}
        && $self->{month}
        && $self->{price}
        && $self->{price} ~~ [ 20000, 30000 ]
        && $self->{count};

    return $self->publish;
}

sub show_help {
    my ( $self, $fail ) = @_;
    if ($fail) {
        print <<"END_USAGE";
Usage: event-opencloset.pl [options]

Try `event-opencloset.pl --help` for more options.
END_USAGE
        return;
    }

    print <<"END_HELP";
Usage: event-opencloset.pl [options]

Options:
  -y,--year   year
  -m,--month  month
  -p,--price  price. 20000 or 30000
  -c,--count  count

Examples:

  event-opencloset.pl -y 2022 -m 7 -p 20000 -c 20
  event-opencloset.pl -y 2022 -m 7 -p 30000 -c 20

END_HELP

    return 1;
}

sub publish {
    my $self = shift;

    my $price_10k = $self->{price} / 10000;

    my $dt_start = DateTime->new(
        year => $self->{year},
        month => $self->{month},
        time_zone => "Asia/Seoul",
    );
    my $dt_end = $dt_start->clone->add( years => 1, months => 1, seconds => -1 );

    my $name         = sprintf( "opencloset%d-%04d%02d", $self->{price}, $self->{year}, $self->{month} );
    my $title        = "열린옷장 ${price_10k}만원 쿠폰";
    my $type         = "reserve|reserve";
    my $desc         = sprintf( "열린옷장 %04d-%02d %d만원 쿠폰 / 캠페인어스", $self->{year}, $self->{month}, $price_10k );
    my $sponsor      = "열린옷장";
    my $year         = $self->{year};
    my $nth          = 1;
    my $start_date   = $dt_start->ymd;
    my $end_date     = $dt_end->ymd;
    my $coupon_type  = "price";
    my $coupon_price = $self->{price};
    my $coupon_count = $self->{count};
    my $coupon_out   = "$name.txt";

    print <<"END_CLI";
perl bin/event.pl \\
    --name='$name' \\
    --title='$title' \\
    --type='$type' \\
    --desc='$desc' \\
    --sponsor='$sponsor' \\
    --year=$year \\
    --nth=$nth \\
    --start_date='$start_date' \\
    --end_date='$end_date' \\
    --coupon-type='$coupon_type' \\
    --coupon-price=$coupon_price \\
    --coupon-count=$coupon_count \\
    --coupon-out='$coupon_out'
END_CLI

    return 1;
}

1;

package main;

use common::sense;

unless (caller) {
    my $app = App::OpenCloset::Coupon::Publish::script->new;
    $app->parse_options(@ARGV);
    exit $app->doit;
}
