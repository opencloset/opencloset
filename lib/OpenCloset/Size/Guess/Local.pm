package OpenCloset::Size::Guess::Local;

use Moo;

with 'OpenCloset::Size::Guess';

has schema => ( is => 'ro', required => 1 );
has cnt    => ( is => 'rw', default  => 0 );

after clear => sub {
    my $self = shift;
    $self->cnt(0);
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
        $self->cnt( $self->cnt + 1 );
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

sub refresh {
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
                $height - $OpenCloset::Size::Guess::ROE,
                $height + $OpenCloset::Size::Guess::ROE,
                $weight - $OpenCloset::Size::Guess::ROE,
                $weight + $OpenCloset::Size::Guess::ROE
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

                    my $n = 2;
                    $n = 1 unless $part1 && $part2;
                    $self->$part( sprintf "%.1f", ( $part1 + $part2 ) / $n );
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

OpenCloset::Size::Guess::Local - 통계를 바탕으로 키/몸무게 로 각 사이즈를 추측

=head1 SYNOPSIS

  my $guess = OpenCloset::Size::Guess::Local->new(
    schema => $schema,
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
