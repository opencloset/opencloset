use strict;
use warnings;
use Crypt::Mode::ECB;
use Getopt::Long;
use Pod::Usage;

my %options;
GetOptions( \%options, "--help" );

run( \%options, @ARGV );

sub run {
    my ( $opts, @args ) = @_;
    return pod2usage(0) if $opts->{help};
    return pod2usage(0) unless @args;

    my $plaintext   = $args[0];
    my $hex_key     = $ENV{OPENCLOSET_EVENT_SEOUL_KEY} || 'A' x 32;
    my $key         = pack( 'H*', $hex_key );
    my $m           = Crypt::Mode::ECB->new('AES');
    my $chipher     = $m->encrypt( $plaintext, $key );
    my $chiphertext = unpack( 'H*', $chipher );
    print "$chiphertext\n";
}

__END__

=head1 NAME

encrypt_text.pl - plaintext to ECB encrypted chiphertext

=head1 SYNOPSIS

    $ encrypt_text.pl abcde
    # fb3371eb2b20abdaa9e9ce875f3e1fe6

    for test
    https://visit.theopencloset.net/events/seoul?MberSn=:CHIPHERTEXT

=head1 DESCRIPTION

requires C<$ENV{OPENCLOSET_EVENT_SEOUL_KEY}>

=cut
