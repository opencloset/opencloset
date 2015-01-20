package OpenCloset::Parcel;

use utf8;

my %MMAP = (
    옐로우캡  => 'KR::Yellowcap',
    yellowcap => 'KR::Yellowcap',

    cj         => 'KR::CJ',
    cj대한통운 => 'KR::CJ',
    대한       => 'KR::CJ',
    대한통운   => 'KR::CJ',
);

sub new {
    my ($class, $service, @args) = @_;
    my $impl = $MMAP{lc $service};
    die "Not found Parcel service: $service" unless $impl;
    $impl = "OpenCloset::Parcel::$impl";
    my $pm = $impl . '.pm';
    $pm =~ s/::/\//g;
    eval { require "$pm" };
    die "$@" if $@;
    return $impl->new(@args);
}

1;

=pod

=head1 NAME

=head1 SYNOPSIS

    my $parcel = OpenCloset::Parcel->new('Yellowcap');
    say $parcel->tracking_url('xxxxxx');

    say $parcel->url('xxxxxx');    # shortcut

=cut
