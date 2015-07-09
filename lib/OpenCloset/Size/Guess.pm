package OpenCloset::Size::Guess;

use utf8;
use Moo::Role;

our $ROE = $ENV{OPENCLOSET_RANGE_OF_ERROR} // 1;    # Range of error -1 ~ +1

has height => ( is => 'rw', required => 1 );
has weight => ( is => 'rw', required => 1 );
has gender => (
    is  => 'rw',
    isa => sub {
        die "male or female only" unless $_[0] =~ /^(fe)?male$/i;
    }
);

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

sub BUILD { shift->refresh }

sub refresh {...}

sub clear {
    my $self = shift;
    map { $self->$_(0) }
        qw/belly topbelly bust arm thigh waist leg foot hip knee/;
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
