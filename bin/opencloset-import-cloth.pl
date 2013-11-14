#!/usr/bin/env perl

use v5.14;
use utf8;
use strict;
use warnings;

use Getopt::Long::Descriptive;
use HTTP::Request::Common;
use HTTP::Request;
use JSON;
use LWP::UserAgent;
use Text::CSV;

use Opencloset::Constant;

my ( $opt, $usage ) = do {
    my $URL = $ENV{OPENCLOSET_URL} || 'http://localhost:5000';

    describe_options(
        "%c %o [csv file]",
        [ 'url=s',      "opencloset url (default: $URL)", { default => $URL } ],
        [ 'help|h',     'print usage message and exit' ],
    );
};

run( $opt, @ARGV );

sub run {
    my ( $opt, @args ) = @_;

    print($usage->text), exit                        if     $opt->help;
    print($usage->text), die("csv file is needed\n") unless @args >= 1;

    binmode STDOUT, ":utf8";
    binmode STDERR, ":utf8";

    my $csv = Text::CSV->new( { binary => 1, auto_diag => 1 } );
    open my $fh, "<:encoding(utf8)", "$args[0]" or die "$args[0]: $!";

    my @headers = map { s/(^\s+|\s+$)//g; $_ } @{ $csv->getline($fh) };
    $csv->column_names(@headers);

    my $ua = LWP::UserAgent->new;

    if ( $ENV{OPENCLOSET_DEBUG} ) {
        $ua->add_handler(
            'request_prepare' => sub {
                my ($req, $ua, $h) = @_;
                say $req->as_string;
            }
        );

        $ua->add_handler(
            'response_done' => sub {
                my ($res, $ua, $h) = @_;
                say $res->as_string;
            }
        );
    }

    my %gender_map = (
        M  => 1, m  => 1,
        W  => 2, w  => 2,
        '' => 3,
    );

    my $loop = 1;
    my ( $success, $fail ) = ( 0, 0 );
    while (my $row = $csv->getline_hr($fh)) {
        $loop++;

        my $gender = $row->{gender} // '';
        my $foot = $row->{foot};
        if ($row->{category} == $Opencloset::Constant::CATEOGORY_SHOES) {
            $foot = $row->{donor_id};
        }

        my %post_data = (
            chest           => $row->{chest},
            waist           => $row->{waist},
            arm             => $row->{arm},
            length          => $row->{length},
            foot            => $foot,
            category_id     => $row->{category},
            gender          => $gender_map{$gender},
            compatible_code => $row->{code},
            color           => $row->{color},
        );

        my $res = $ua->request( POST $opt->url . '/clothes.json', [ %post_data ] );

        my $data = decode_json($res->content);
        if ($res->is_success) {
            $success++;
        }
        else {
            $fail++;
            my $cloth_data = join q{,}, @post_data{ qw/ chest waist arm length foot category_id gender compatible_code color / };
            say STDERR "row($loop): data($cloth_data): $data->{error}{str}";
            say STDERR "  $_ => $post_data{$_}" for keys %{ $data->{error}{data} };
        }
    }

    close $fh;

    say "SUCCESS: $success";
    say "FAIL   : $fail";
}

__END__
