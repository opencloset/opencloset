#!/usr/bin/env perl

use 5.010;
use utf8;
use strict;
use warnings;

use Math::Fleximal;
use DDP;

my %last = (
    A => q{},    # 신발      / shoes
    B => q{},    # 블라우스  / blouse
    C => q{},    # 코드      / coat
    E => q{},    # 벨트      / belt
    H => q{},    # 모자      / hat
    J => q{},    # 자켓      / jacket
    K => q{},    # 스커트    / skirt
    O => q{},    # 원피스    / onepiece
    P => q{},    # 바지      / pants
    S => q{},    # 셔츠      / shirt
    T => q{},    # 타이      / tie
    W => q{},    # 조끼      / waistcoat
);

my %code = (
    A => 0,      # 신발      / shoes
    B => 0,      # 블라우스  / blouse
    C => 0,      # 코드      / coat
    E => 0,      # 벨트      / belt
    H => 0,      # 모자      / hat
    J => 0,      # 자켓      / jacket
    K => 0,      # 스커트    / skirt
    O => 0,      # 원피스    / onepiece
    P => 0,      # 바지      / pants
    S => 0,      # 셔츠      / shirt
    T => 0,      # 타이      / tie
    W => 0,      # 조끼      / waistcoat
);

my %next;

my @digits = ( 0 .. 9, 'A' .. 'Z' );

for my $k ( sort keys %code ) {
    my $n = $code{$k};

    my $last = Math::Fleximal->new( $last{$k}, \@digits );
    for ( 0 .. $n - 1 ) {
        my $code
            = Math::Fleximal->new($_)->change_flex( \@digits )->add($last)
            ->add( $last->one )->to_str;
        printf( "%s%03s\n", $k, $code );
        $next{$k} = $code;
    }
}
%next = ( %last, %next );

print STDERR "[ last code ]\n";
foreach my $k ( sort keys %next ) {
    print STDERR sprintf( "%s%03s\n", $k, $next{$k} );
}
