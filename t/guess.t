use utf8;
use open ':std', ':encoding(utf8)';
use Test::More tests => 12;

use OpenCloset::Schema;
use OpenCloset::Util;

use_ok('OpenCloset::Size::Guess');

my $CONF
    = OpenCloset::Util::load_config( $ENV{MOJO_CONFIG} || 'app.psgi.conf' );
my $schema = OpenCloset::Schema->connect(
    {
        dsn      => $CONF->{database}{dsn},
        user     => $CONF->{database}{user},
        password => $CONF->{database}{pass},
        %{ $CONF->{database}{opts} },
    }
);

my $guess = OpenCloset::Size::Guess->new(
    schema => $schema,
    gender => 'male',
    height => 180,
    weight => 70
);

ok( $guess->belly, 'belly' );
ok( $guess->bust,  'bust' );
ok( $guess->arm,   'arm' );
ok( $guess->thigh, 'thigh' );
ok( $guess->hip,   'hip' );
ok( $guess->waist, 'waist' );
ok( $guess->leg,   'leg' );
ok( $guess->knee,  'knee' );
ok( $guess->foot,  'foot' );

like "$guess", qr/남/, 'stringify';

$guess->gender('female');
$guess->height('160');
$guess->weight('50');

like "$guess", qr/여/, 'stringify';
