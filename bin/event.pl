use utf8;
use strict;
use warnings;

use Algorithm::CouponCode qw(cc_generate cc_validate);
use DateTime;
use Encode qw/decode_utf8/;
use Getopt::Long;
use Pod::Usage;
use Path::Tiny;

use OpenCloset::Schema;

binmode STDOUT, ':encoding(UTF-8)';
binmode STDERR, ':encoding(UTF-8)';

my $config = require './app.conf' or die "Not found config: $!";
my $db = $config->{database};

my $schema = OpenCloset::Schema->connect(
    {
        dsn      => $db->{dsn},
        user     => $db->{user},
        password => $db->{pass},
        %{ $db->{opts} },
    }
);

our %TYPE_MAP = (
    'reserve|reserve' => 1,
    'reserve|rental'   => 2,
    'rental|reserve'   => 3,
    'rental|rental'    => 4,
);

my %options;
GetOptions(
    \%options,
    "--help",
    "--name|n=s",
    "--title=s",
    "--type|t=s",
    "--desc|d=s",
    "--sponsor|s=s",
    "--year|y=i",
    "--nth=i",
    "--freeshipping|f",
    "--start_date|S=s",
    "--end_date|E=s"
);

run( \%options, @ARGV );

sub run {
    my ( $opts, @args ) = @_;
    pod2usage(0) if $opts->{help};
    pod2usage(0) unless $opts->{name};
    pod2usage(0) unless $opts->{title};

    my $name          = decode_utf8($opts->{name});
    my $title         = decode_utf8($opts->{title});
    my $type          = $opts->{type};
    my $desc          = decode_utf8($opts->{desc} || '');
    my $sponsor       = decode_utf8($opts->{sponsor} || '');
    my $year          = $opts->{year} || (localtime)[5] + 1900; # this year
    my $nth           = $opts->{nth} || 1;
    my $free_shipping = $opts->{freeshipping};
    my $start_date    = $opts->{start_date} || DateTime->today(time_zone => 'Asia/Seoul')->ymd;
    my $end_date      = $opts->{end_date};

    # prevent Use of uninitialized value warn
    my $date_s = $start_date || '';
    my $date_e = $end_date   || '';

    my $event_type_id;
    if ($type) {
        $event_type_id = $TYPE_MAP{$type};
        unless ($event_type_id) {
            warn "Not found $type\n";
            pod2usage(0);
        }
    }

    printf(<<EOL, $name, $title, $type, $desc, $sponsor, $year, $nth, $free_shipping ? 'Y' : 'N', $date_s, $date_e);
name          : %s
title         : %s
type          : %s
desc          : %s
sponsor       : %s
year          : %d
nth           : %d
free_shipping : %s
start_date    : %s
end_date      : %s

EOL

    print "Continue? [Y/n] ";
    my $answer = <STDIN>;
    chomp $answer;
    $answer = 'y' if $answer eq '';
    unless ($answer =~ m/y/i) {
        print "aborted\n";
        exit;
    }

    my $event = $schema->resultset('Event')->create({
        name          => $name,
        title         => $title,
        event_type_id => $event_type_id,
        desc          => $desc,
        sponsor       => $sponsor,
        year          => $year,
        nth           => $nth,
        free_shipping => $free_shipping,
        start_date    => $start_date,
        end_date      => $end_date
    });

    die "Failed to create a new event" unless $event;

    print "\n[OK] a new event created\n\n";
    print "$event\n";

    issue_coupon($opts, @args) if $opts->{'coupon-type'};
};

sub issue_coupon {
    my ($opts, @args) = @_;

    my $type  = $opts->{'coupon-type'};
    my $cnt   = $opts->{'coupon-count'};
    my $limit = $opts->{'coupon-limit'};
    my $out   = $opts->{'coupont-out'};

    pod2usage(0) unless $type;
    if ($type !~ m/^(suit|price|rate)$/) {
        warn "Unknown coupon type: $type\n";
        pod2usage(0);
    }

    my $fh = <STDOUT>;
    if ($out) {
        $out = path($out);
        $fh = $out->filehandle('openw');
    }

    for ( 1 .. $cnt ) {
        my $code = cc_generate( parts => 3 );
        my $coupon = $schema->resultset('Coupon')->create(
            {
                code => $code,
                type => $type,
            }
        );

        unless ($coupon) {
            print STDERR "Couldn't create a new Coupon\n";
            next;
        }

        print $fh "$code\n";
    }

    ## TODO: error 체크하고 에러 없으면 limit 설정
}

__END__

=encoding utf8

=head1 NAME

event.pl - Create a new event.

=head1 SYNOPSIS

    $ bin/event.pl
      * is required

        --help|h          print this help.
      * --name|n          name of event.
      * --title           title of event.
        --type|t          START_TYPE|END_TYPE; '|' seperated type values.
                          START_TYPE:
                            - reserve or rental
                          END_TYPE:
                            - reserve or rental
        --desc|d          description.
        --sponsor         sponsor name
        --year|y          if not present, this year is default.
        --nth             nth rounds.
        --freeshipping|f  free_shipping flag
        --start_date|S    if not present, today. TZ: Asia/Seoul
        --end_date|E

=cut
