package OpenCloset::Size::Guess;

use utf8;
use Moo;

has schema => ( is => 'ro', required => 1 );
has height => ( is => 'rw', required => 1, trigger => 1 );
has weight => ( is => 'rw', required => 1, trigger => 1 );
has gender => (
    is  => 'rw',
    isa => sub { die "male or female only" unless $_[0] =~ /^(fe)?male$/i }
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

sub BUILD { shift->calc }

sub _trigger_height {
    my $self = shift;
    return unless $self->schema;
    $self->clear && $self->calc;
}

sub _trigger_weight {
    my $self = shift;
    return unless $self->schema;
    $self->clear && $self->calc;
}

sub clear {
    my $self = shift;
    map { $self->$_(0) }
        qw/belly topbelly bust arm thigh waist leg foot hip knee/;
}

my $ROE = $ENV{OPENCLOSET_RANGE_OF_ERROR} // 1;    # Range of error -1 ~ +1

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

sub average {
    my ( $self, $dbh, $where, @bind ) = @_;

    my $from = qq{`order` o};
    my $join
        = qq{`user` u ON o.user_id = u.id JOIN `user_info` ui ON u.id = ui.user_id JOIN `booking` b ON o.booking_id = b.id};
    my $sql
        = qq{SELECT o.belly AS belly, o.topbelly AS topbelly, o.bust AS bust, o.arm AS arm, o.thigh AS thigh, o.waist AS waist, o.leg AS leg, o.hip AS hip, o.knee AS knee, o.foot AS foot FROM $from JOIN $join WHERE $where};
    my $sth = $dbh->prepare($sql);
    $sth->execute(@bind);
    my ( %sum, %i, %measurement );

    while ( my $measurement = $sth->fetchrow_hashref ) {
        while ( my ( $part, $size ) = each %$measurement ) {
            next unless $size;
            $sum{$part} += $size;
            $i{$part}++;
        }
    }

    for my $part ( keys %sum ) {
        $measurement{$part} = $sum{$part} / $i{$part};
    }

    return {%measurement};
}

sub calc {
    my $self = shift;

    my ( $height, $weight ) = ( $self->height, $self->weight );
    my $average = $self->schema->storage->dbh_do(
        sub {
            my ( $storage, $dbh, @cols ) = @_;
            my $where1
                = qq{UNIX_TIMESTAMP(b.date) < UNIX_TIMESTAMP('2015-05-29 00:00:00') AND DATE_FORMAT(b.date, '%H') < 19 AND ui.gender = ? AND o.height BETWEEN ? AND ? AND o.weight BETWEEN ? AND ?};
            my $where2
                = qq{UNIX_TIMESTAMP(b.date) > UNIX_TIMESTAMP('2015-05-29 00:00:00') AND DATE_FORMAT(b.date, '%H') < 22 AND ui.gender = ? AND o.height BETWEEN ? AND ? AND o.weight BETWEEN ? AND ?};
            my @bind = (
                $self->gender,
                $height - $ROE,
                $height + $ROE,
                $weight - $ROE,
                $weight + $ROE
            );

            my $average1 = $self->average( $dbh, $where1, @bind );
            my $average2 = $self->average( $dbh, $where2, @bind );
            my @parts = keys %$average1 or keys %$average2;
            if ( keys %$average1 && keys %$average2 ) {
                for my $part (@parts) {
                    my $part1 = $average1->{$part} // 0;
                    my $part2 = $average2->{$part} // 0;
                    if ( abs( $part1 - $part2 ) > 5 ) {
                        warn sprintf
                            "$part data looks wrong: %.1f < 5/29, %.1f > 5/29\n",
                            $part1, $part2;
                    }
                    $self->$part( sprintf "%.1f", ( $part1 + $part2 ) / 2 );
                }
            }
            else {
                for my $part (@parts) {
                    $self->$part( sprintf "%.1f",
                        $average1->{$part} // $average2->{$part} // 0 );
                }
            }
        }
    );
}

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
