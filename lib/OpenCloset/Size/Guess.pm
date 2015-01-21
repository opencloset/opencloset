package OpenCloset::Size::Guess;

use utf8;
use Moo;

has schema => ( is => 'ro', required => 1 );
has height => ( is => 'rw', required => 1 );
has weight => ( is => 'rw', required => 1 );
has gender => (
    is  => 'rw',
    isa => sub { die "male or female only" unless $_[0] =~ /^(fe)?male$/i }
);

my $ROE = $ENV{OPENCLOSET_RANGE_OF_ERROR} // 3;    # Range of error -3 ~ +3

use overload '""' => sub {
    my $self = shift;
    my $format
        = $self->gender eq 'male'
        ? "[남][%s/%s] 중동: %s, 가슴: %s, 팔: %s, 허벅지: %s, 허리: %s, 다리: %s, 발: %s"
        : "[여][%s/%s] 중동: %s, 가슴: %s, 팔: %s, 엉덩이: %s, 허리: %s, 무릎: %s, 발: %s";
    my @args
        = $self->gender eq 'male'
        ? map { $self->$_ || '' }
        qw/height weight belly bust arm thigh waist leg foot/
        : map { $self->$_ || '' }
        qw/height weight belly bust arm hip waist knee foot/;
    return sprintf $format, @args;
};

sub calc {
    my ( $self, $part ) = @_;

    my ( $height, $weight ) = ( $self->height, $self->weight );
    my $rs = $self->schema->resultset('UserInfo')->search(
        {
            gender => $self->gender,
            height => { -between => [$height - $ROE, $height + $ROE] },
            weight => { -between => [$weight - $ROE, $weight + $ROE] },
            -and   => [$part => { '!=' => 0 }, $part => { '!=' => undef }],
        }
    );

    my ( $sum, $i ) = ( 0, 0 );
    while ( my $info = $rs->next ) {
        my $size = $info->$part;
        next unless $size;
        $sum += $size;
        $i++;
    }

    return unless $sum;
    return sprintf "%.1f", $sum /= $i;    # zero division possibility
}

sub belly { shift->calc('belly') }
sub bust  { shift->calc('bust') }
sub arm   { shift->calc('arm') }
sub thigh { shift->calc('thigh') }
sub hip   { shift->calc('hip') }
sub waist { shift->calc('waist') }
sub leg   { shift->calc('leg') }
sub knee  { shift->calc('knee') }
sub foot  { shift->calc('foot') }

1;

=pod

=encoding utf-8

=head1 NAME

OpenCloset::Size::Guess - 통계를 바탕으로 키/몸무게 로 각 사이즈를 추측

=head1 SYNOPSIS

  my $guess = OpenCloset::Size::Guess->new(
    height => '180',    # cm
    weight => '80'      # kg
    gender => 'male'    # or 'female'
  );

  print "$guess\n";      # [남] 중동: xx, 가슴: xx, 팔: xx, 허벅지: xx, 허리: xx, 다리: xx, 발: xx
  print "$guess\n";      # [여] 중동: xx, 가슴: xx, 팔: xx, 엉덩이: xx, 허리: xx, 무릎: xx, 발: xx
  print $guess->belly;   # 중동
  print $guess->bust;    # 가슴
  print $guess->arm;     # 팔
  print $guess->waist;   # 허리
  print $guess->thigh;   # 허벅지
  print $guess->hip;     # 엉덩이
  print $guess->leg;     # 다리
  print $guess->knee;    # 무릎
  print $guess->foot;    # 발

=cut
