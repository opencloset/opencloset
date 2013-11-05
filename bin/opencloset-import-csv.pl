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
        [ 'url=s',  "opencloset url (default: $URL)", { default => $URL } ],
        [],
        [ 'help|h', 'print usage message and exit' ],
        [ 'category=s', '-1: Jacket & Pants, -2: Jacket & Skirts, 4: Shoes' ],
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

    my $loop = 1;
    my ( $success, $fail ) = ( 0, 0 );
    while (my $row = $csv->getline_hr($fh)) {
        $loop++;

        my $category_id;
        my $designated_for;
        if ($opt->{category} == $Opencloset::Constant::CATEOGORY_JACKET_PANTS) {
            $designated_for = $Opencloset::Constant::CLOTHE_DESIGNATED_FOR_MAN;
            if ($row->{'가슴둘레'} && $row->{'허리둘레'}) {
                $category_id = $Opencloset::Constant::CATEOGORY_JACKET_PANTS;
            }
            elsif ($row->{'가슴둘레'}) {
                $category_id = $Opencloset::Constant::CATEOGORY_JACKET;
            }
            elsif ($row->{'허리둘레'}) {
                $category_id = $Opencloset::Constant::CATEOGORY_PANTS;
            }
            else {
                say STDERR "[$loop] NOT FOUND category";
                next;
            }
        } elsif ($opt->{category} == $Opencloset::Constant::CATEOGORY_JACKET_SKIRTS) {
            $designated_for = $Opencloset::Constant::CLOTHE_DESIGNATED_FOR_WOMAN;
            if ($row->{'가슴둘레'} && $row->{'허리둘레'}) {
                $category_id = $Opencloset::Constant::CATEOGORY_JACKET_SKIRTS;
            }
            elsif ($row->{'가슴둘레'}) {
                $category_id = $Opencloset::Constant::CATEOGORY_JACKET;
            }
            elsif ($row->{'허리둘레'}) {
                $category_id = $Opencloset::Constant::CATEOGORY_SKIRTS;
            }
            else {
                say STDERR "[$loop] NOT FOUND category";
                next;
            }
        } elsif ($opt->{category} == $Opencloset::Constant::CATEOGORY_SHOES) {
            $designated_for = $row->{'성별'} eq 'M' ?
                $Opencloset::Constant::CLOTHE_DESIGNATED_FOR_MAN :
                $Opencloset::Constant::CLOTHE_DESIGNATED_FOR_WOMAN;
            $row->{FootSize} = $row->{'사이즈'};
        }

        my $res = $ua->request(
            POST $opt->url . '/clothes.json',
            [
                chest          => $row->{'가슴둘레'},
                waist          => $row->{'허리둘레'},
                arm            => $row->{'팔길이'} || $row->{'소매길이'},
                pants_len      => $row->{'바지기장'},
                foot           => $row->{FootSize} || '',
                category_id    => $category_id || $opt->{category},
                designated_for => $designated_for,
            ]
        );

        my $data = decode_json($res->content);
        if ($res->is_success) {
            $success++;
        }
        else {
            $fail++;
            say STDERR $data->{error};
        }
    }

    close $fh;

    say "SUCCESS: $success";
    say "FAIL   : $fail";
}

__END__
