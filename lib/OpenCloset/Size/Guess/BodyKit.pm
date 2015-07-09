package OpenCloset::Size::Guess::BodyKit;

use utf8;
use Moo;

use HTTP::Tiny;
use JSON;

has access_key => ( is => 'ro', required => 1 );
has secret     => ( is => 'ro', required => 1 );
has height     => ( is => 'rw', required => 1 );
has weight     => ( is => 'rw', required => 1 );
has gender     => (
    is  => 'rw',
    isa => sub { die "male or female only" unless $_[0] =~ /^(fe)?male$/i }
);

has _scheme     => ( is => 'ro', default => 'flexible' );
has _unitSystem => ( is => 'ro', default => 'metric' );
has _generation => ( is => 'ro', default => '2.0' );

has belly    => ( is => 'rw', default => 0 );
has topbelly => ( is => 'rw', default => 0 );
has bust     => ( is => 'rw', default => 0 );
has arm      => ( is => 'rw', default => 0 );
has thigh    => ( is => 'rw', default => 0 );
has waist    => ( is => 'rw', default => 0 );
has leg      => ( is => 'rw', default => 0 );
has foot     => ( is => 'rw', default => 0 );
has hip      => ( is => 'rw', default => 0 );
has knee     => ( is => 'rw', default => 0 );

our $BODYKIT_URL = "https://api.bodylabs.com/instant/measurements";

sub BUILD { shift->measurement }

sub clear {
    my $self = shift;
    map { $self->$_(0) }
        qw/belly topbelly bust arm thigh waist leg foot hip knee/;
}

sub measurement {
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
    my $data         = decode_json( $res->{content} );
    my $measurements = $data->{output}{measurements};
    $self->clear;
    $self->bust( $measurements->{bust_girth} );
    $self->arm( $measurements->{full_sleeve_length} );
    $self->thigh( $measurements->{thigh_girth} );
    $self->waist( $measurements->{waist_girth} );
    $self->leg( $measurements->{waist_height} );
    $self->hip( $measurements->{high_hip_girth} );
    $self->knee(
        $measurements->{waist_height} - $measurements->{knee_height} );
}

use overload '""' => sub {
    my $self = shift;
    my $format
        = $self->gender eq 'male'
        ? "[남][%s/%s] 중동: %s, 윗배: %s, 가슴: %s, 팔: %s, 허벅지: %s, 허리: %s, 다리: %s, 발: %s"
        : "[여][%s/%s] 중동: %s, 가슴: %s, 팔: %s, 엉덩이: %s, 허리: %s, 무릎: %s, 발: %s";
    my @args
        = $self->gender eq 'male'
        ? map { $self->$_ || '' }
        qw/height weight belly topbelly bust arm thigh waist leg foot/
        : map { $self->$_ || '' }
        qw/height weight belly bust arm hip waist knee foot/;
    return sprintf $format, @args;
};

1;
