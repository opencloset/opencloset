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

    my $loop = 1;
    my ( $success, $fail ) = ( 0, 0 );
    while (my $row = $csv->getline_hr($fh)) {
        $loop++;

        my $gender = $row->{'성별'} // '';
        if ($gender eq '남') {
            $gender = 1;
        }
        else {
            $gender = 2;
        }
        $row->{'전화번호'} =~ s/-//g if $row->{'전화번호'};

        my %post_data = (
            name    => $row->{'기증자'},
            gender  => $gender,
            phone   => $row->{'전화번호'},
            email   => $row->{'이메일'},
            address => $row->{'주소'},
        );

        my $res = $ua->request( POST $opt->url . '/users.json', [ %post_data ] );

        my $data = decode_json($res->content);
        if ($res->is_success) {
            $res = $ua->request( POST $opt->url . '/donors.json', [
                donation_msg => $row->{'기증자메세지'},
                comment      => $row->{'비고'},
            ] );

            $data = decode_json($res->content);
            if ($res->is_success) {
                $success++;
            } else {
                $fail++;
                say STDERR "row($loop): $post_data{name}: $data->{error}";
            }
        }
        else {
            $fail++;
            say STDERR "row($loop): $post_data{name}: $data->{error}{str}";
            say STDERR "  $_ => $post_data{$_}" for keys %{ $data->{error}{data} };
        }
    }

    close $fh;

    say "SUCCESS: $success";
    say "FAIL   : $fail";
}

__END__
