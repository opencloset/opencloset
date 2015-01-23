use Test::Most tests => 7;

use_ok('OpenCloset::Parcel');

dies_ok { OpenCloset::Parcel->new('Yellowcaps') } 'Not found parcel service';

my $p = OpenCloset::Parcel->new('Yellowcap');

ok( $p, 'new' );
diag('Yellowcap');
like( $p->tracking_url,  qr/http/,   'tracking_url' );
like( $p->url,           qr/http/,   'url shortcut' );
like( $p->url('000000'), qr/000000/, 'url with number' );

my $p = OpenCloset::Parcel->new('cj');
like( $p->url('000000'), qr{https://www\.doortodoor\.co\.kr}, 'CJ' );
