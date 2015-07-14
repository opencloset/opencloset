package OpenCloset::Size::Guess::BodyKit;

use Moo;

with 'OpenCloset::Size::Guess';

use HTTP::Tiny;
use JSON;

our $BODYKIT_URL = "https://api.bodylabs.com/instant/measurements";

has access_key => ( is => 'ro', required => 1 );
has secret     => ( is => 'ro', required => 1 );

has _scheme     => ( is => 'ro', default => 'flexible' );
has _unitSystem => ( is => 'ro', default => 'metric' );
has _generation => ( is => 'ro', default => '2.0' );

sub refresh {
    my $self = shift;

    my $json = encode_json(
        {
            gender     => $self->gender,
            scheme     => $self->_scheme,
            unitSystem => $self->_unitSystem,
            measurements =>
                { height => $self->height + 0, weight => $self->weight + 0 }
        }
    );

    my $authorization = sprintf "SecretPair accessKey=%s,secret=%s",
        $self->access_key, $self->secret;

    my $res = HTTP::Tiny->new->request(
        'POST',
        $BODYKIT_URL,
        {
            headers => {
                'content-type' => 'application/x-www-form-urlencoded',
                authorization  => $authorization
            },
            content => $json,
        },
    );

    die "$res->{status}: $res->{reason}\n" unless $res->{success};

    my $measure = decode_json( $res->{content} )->{output}{measurements};
    $self->clear;
    $self->belly( $measure->{waist_girth} );
    $self->bust( $measure->{bust_girth} );
    $self->arm( $measure->{side_arm_length} );
    $self->thigh( $measure->{thigh_girth} );
    $self->waist( $measure->{waist_girth} );
    $self->leg( $measure->{outseam} );
    $self->hip( $measure->{low_hip_girth} );
    $self->knee( $measure->{outseam} - $measure->{knee_height} );
}

1;
