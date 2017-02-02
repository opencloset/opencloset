package OpenCloset::Web::Controller::Coupon;
use Mojo::Base 'Mojolicious::Controller';

use Algorithm::CouponCode qw(cc_validate);
use DateTime;

our %ERROR_MAP = (
    1 => '유효하지 않은 코드 입니다',
    2 => '없는 쿠폰 입니다',
    3 => '사용할 수 없는 쿠폰입니다',
    4 => '유효기간이 지난 쿠폰입니다',
);

has DB => sub { shift->app->DB };

=head1 METHODS

=head2 index

    GET /coupon

=cut

sub index { }

=head2 validate

    POST /coupon/validate

=cut

sub validate {
    my $self = shift;

    my $v = $self->validation;

    $v->required('code');
    if ( $v->has_error ) {
        $self->flash( error => 'coupon 코드를 입력해주세요' );
        return $self->redirect_to('/coupon');
    }

    my $codes = $v->every_param('code');
    my $code = join( '-', @$codes );

    my ( $coupon, $err_code ) = $self->_validate_code($code);
    if ($coupon) {
        $self->session( coupon_code => $coupon->code );
        $self->redirect_to('/visit');
    }
    else {
        $self->flash( error => $ERROR_MAP{$err_code} );
        $self->redirect_to('/coupon');
    }
}

sub _validate_code {
    my ( $self, $code ) = @_;

    my $valid_code = cc_validate( code => $code, parts => 3 );
    return ( undef, 1 ) unless $valid_code;

    my $coupon = $self->DB->resultset('Coupon')->find( { code => $valid_code } );
    return ( undef, 2 ) unless $coupon;

    if ( my $coupon_status = $coupon->status ) {
        return ( undef, 3 ) if $coupon_status =~ m/(us|discard|expir)ed/;
        $self->transfer_order($coupon);
    }

    if ( my $expires = $coupon->expires_date ) {
        if ( $expires->epoch < DateTime->now->epoch ) {
            $self->log->info("coupon is expired: $valid_code");
            $coupon->update( { status => 'expired' } );
            return ( undef, 4 );
        }
    }

    return $coupon;
}

1;
