package Postcodify::Result;

use Moo;
use Types::Standard qw/Str/;

use JSON;
use Time::HiRes qw/gettimeofday tv_interval/;

use Postcodify::Util 'trim';

use version; our $VERSION = version->declare("v2.2.0");

has lang  => ( is => 'ro', isa => Str, default => 'KO' );
has sort  => ( is => 'ro', isa => Str, default => 'JUSO' );
has nums  => ( is => 'ro', isa => Str );
has type  => ( is => 'ro', isa => Str );
has cache => ( is => 'ro', isa => Str, default => 'miss' );
has time  => ( is => 'ro' );
has resultset => ( is => 'ro' );

sub data {
    my $self = shift;
    return () unless $self->resultset;

    my @data;
    while ( my $row = $self->resultset->next ) {
        ## 한글 도로명 및 지번주소를 정리한다.
        my $address_ko_base = trim(
            sprintf "%s %s %s %s",
            $row->road->sido_ko     || '',
            $row->road->sigungu_ko  || '',
            $row->road->ilbangu_ko  || '',
            $row->road->eupmyeon_ko || ''
        );
        my $address_ko_new = trim(
            sprintf "%s %s %s%s",
            $row->road->road_name_ko || '',
            $row->is_basement ? '지하' : '',
            $row->num_major || '',
            $row->num_minor ? '-' . $row->num_minor : ''
        );
        my $address_ko_old = trim(
            sprintf "%s %s %s%s",
            $row->dongri_ko || '',
            $row->is_mountain ? '산' : '',
            $row->jibeon_major || '',
            $row->jibeon_minor ? '-' . $row->jibeon_minor : ''
        );
        $address_ko_base =~ s/ {2,}/ /g;
        $address_ko_new =~ s/ {2,}/ /g;
        $address_ko_old =~ s/ {2,}/ /g;

        ## 영문 도로명 및 지번주소를 정리한다.
        my $address_en_base = trim(
            sprintf "%s %s %s %s",
            $row->road->eupmyeon_en || '',
            $row->road->ilbangu_en  || '',
            $row->road->sigungu_en  || '',
            $row->road->sido_en     || ''
        );
        my $address_en_new = trim(
            sprintf "%s %s%s %s",
            $row->is_basement ? 'Jiha' : '',
            $row->num_major || '',
            $row->num_minor ? '-' . $row->num_minor : '',
            $row->road->road_name_en || ''
        );
        my $address_en_old = trim(
            sprintf "%s %s%s %s",
            $row->is_mountain ? 'San' : '',
            $row->jibeon_major || '',
            $row->jibeon_minor ? '-' . $row->jibeon_minor : '',
            $row->dongri_en || ''
        );
        $address_en_base =~ s/ {2,}/ /g;
        $address_en_new =~ s/ {2,}/ /g;
        $address_en_old =~ s/ {2,}/ /g;

        ## 추가정보를 정리한다.
        my ( $extra_info_long, $extra_info_short, $other_addresses );
        if ( $self->sort eq 'POBOX' ) {
            $address_ko_new = $address_ko_old
                = $row->dongri_ko . ' ' . $row->other_addresses;
            $address_en_new = $address_en_old
                = $row->dongri_en . ' ' . $row->other_addresses;
            $extra_info_long = $extra_info_short = $other_addresses = '';
        }
        else {
            $extra_info_long = trim(
                join( '', $address_ko_old, $row->building_name || '' ) );
            $extra_info_short = trim(
                join( '', $row->dongri_ko || '', $row->building_name || '' ) );
            $other_addresses = $row->other_addresses;
        }

        my $data = {
            dbid  => $row->address_id,
            code6 => substr( $row->postcode6, 0, 3 ) . '-'
                . substr( $row->postcode6, 3, 3 ),
            code5   => $row->postcode5,
            address => {
                base     => $address_ko_base,
                new      => $address_ko_new,
                old      => $address_ko_old,
                building => $row->building_name
            },
            english => {
                base     => $address_en_base,
                new      => $address_en_new,
                old      => $address_en_old,
                building => ''
            },
            other => {
                long   => $extra_info_long,
                short  => $extra_info_short,
                others => $other_addresses,
                addrid => $row->id,
                roadid => $row->road_id
            }
        };

        push @data, $data;
    }

    return @data;
}

sub json {
    my $self = shift;

    my @data = $self->data();
    return encode_json(
        {
            version => $VERSION->stringify,
            error   => '',
            msg     => '',
            count   => scalar @data,
            time    => sprintf( '%.4f', tv_interval( $self->time ) ),
            lang    => $self->lang,
            sort    => $self->sort,
            type    => $self->type,
            nums    => $self->nums,
            cache   => $self->cache,
            results => [@data]
        }
    );    # utf8 encoded text
}

1;

=pod

=head1 NAME

Postcodify::Result - Contain various search result

=head1 SYNOPSIS

    my $result = Postcodify::Result->new(
        lang      => 'KO',
        sort      => 'JUSO',
        nums      => '123-12',
        type      => 'JUSO+NUMS',
        time      => '0.002',
        resultset => $rs    # PostcodifyRoad prefetched PostcodifyAddress ResultSet
    );

    print $result->json;    # utf8 encoded text

=cut
