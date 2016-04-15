package OpenCloset::Web::Constants::Measurement;

use utf8;
use strict;
use warnings;

our $HEIGHT   = 'height';
our $WEIGHT   = 'weight';
our $NECK     = 'neck';
our $BUST     = 'bust';
our $WAIST    = 'waist';
our $HIP      = 'hip';
our $TOPBELLY = 'topbelly';
our $BELLY    = 'belly';
our $THIGH    = 'thigh';
our $ARM      = 'arm';
our $LEG      = 'leg';
our $KNEE     = 'knee';
our $FOOT     = 'foot';
our $PANTS    = 'pants';
our $SKIRT    = 'skirt';
our $LENGTH   = 'length';
our $CUFF     = 'cuff';

our @ALL = (
    $HEIGHT, $WEIGHT, $NECK, $BUST,  $WAIST, $HIP,    $TOPBELLY, $BELLY, $THIGH, $ARM,
    $LEG,    $KNEE,   $FOOT, $PANTS, $SKIRT, $LENGTH, $CUFF
);

our @PRIMARY =
    ( $HEIGHT, $WEIGHT, $NECK, $BUST, $WAIST, $THIGH, $ARM, $LEG, $KNEE, $FOOT );

our $LABEL_HEIGHT   = '키';
our $LABEL_WEIGHT   = '몸무게';
our $LABEL_NECK     = '목둘레';
our $LABEL_BUST     = '가슴둘레';
our $LABEL_WAIST    = '허리둘레';
our $LABEL_HIP      = '엉덩이둘레';
our $LABEL_TOPBELLY = '윗배둘레';
our $LABEL_BELLY    = '배꼽둘레';
our $LABEL_THIGH    = '허벅지둘레';
our $LABEL_ARM      = '팔길이';
our $LABEL_LEG      = '다리길이';
our $LABEL_KNEE     = '무릎길이';
our $LABEL_FOOT     = '발크기';
our $LABEL_PANTS    = '바지길이';
our $LABEL_SKIRT    = '스커트길이';
our $LABEL_LENGTH   = '길이';
our $LABEL_CUFF     = '밑단둘레';

our @ALL_LABEL = (
    $LABEL_HEIGHT,   $LABEL_WEIGHT, $LABEL_NECK,  $LABEL_BUST, $LABEL_WAIST, $LABEL_HIP,
    $LABEL_TOPBELLY, $LABEL_BELLY,  $LABEL_THIGH, $LABEL_ARM,
    $LABEL_LEG, $LABEL_KNEE, $LABEL_FOOT, $LABEL_PANTS, $LABEL_SKIRT, $LABEL_LENGTH,
    $LABEL_CUFF
);

our %LABEL_MAP = (
    $HEIGHT   => $LABEL_HEIGHT,
    $WEIGHT   => $LABEL_WEIGHT,
    $NECK     => $LABEL_NECK,
    $BUST     => $LABEL_BUST,
    $WAIST    => $LABEL_WAIST,
    $HIP      => $LABEL_HIP,
    $TOPBELLY => $LABEL_TOPBELLY,
    $BELLY    => $LABEL_BELLY,
    $THIGH    => $LABEL_THIGH,
    $ARM      => $LABEL_ARM,
    $LEG      => $LABEL_LEG,
    $KNEE     => $LABEL_KNEE,
    $FOOT     => $LABEL_FOOT,
    $PANTS    => $LABEL_PANTS,
    $SKIRT    => $LABEL_SKIRT,
    $LENGTH   => $LABEL_LENGTH,
    $CUFF     => $LABEL_CUFF
);

our %UNIT_MAP = (
    $HEIGHT   => 'cm',
    $WEIGHT   => 'kg',
    $NECK     => 'cm',
    $BUST     => 'cm',
    $WAIST    => 'cm',
    $HIP      => 'cm',
    $TOPBELLY => 'cm',
    $BELLY    => 'cm',
    $THIGH    => 'cm',
    $ARM      => 'cm',
    $LEG      => 'cm',
    $KNEE     => 'cm',
    $FOOT     => 'mm',
    $PANTS    => 'cm',
    $SKIRT    => 'cm',
    $LENGTH   => 'cm',
    $CUFF     => 'cm'
);

1;
