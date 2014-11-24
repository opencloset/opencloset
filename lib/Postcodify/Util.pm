package Postcodify::Util;

use strict;
use warnings;

use Exporter;
our @ISA    = qw(Exporter);
our @EXPORT = qw(trim);

sub trim {
    my $str = shift;
    $str =~ s/^\s+|\s+$//g;
    return $str;
}

1;

=pod

=head1 NAME

Postcodify::Util - Utility subroutine packages

=head1 SYNOPSIS

    use Postcodify::Util 'trim';
    print trim('   yo   ');    # prints 'yo'

=cut
