use Test::Most tests => 6;

use_ok('OpenCloset::Parcel');

dies_ok { OpenCloset::Parcel->new('Yellowcaps') } 'Not found parcel service';

my $p = OpenCloset::Parcel->new('Yellowcap');

ok( $p, 'new' );
like( $p->tracking_url,  qr/http/,   'tracking_url' );
like( $p->url,           qr/http/,   'url shortcut' );
like( $p->url('000000'), qr/000000/, 'url with number' );
