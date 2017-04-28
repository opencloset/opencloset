package OpenCloset::Web::Controller::Coupon;
use Mojo::Base 'Mojolicious::Controller';

use DateTime;

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
    $v->optional('extra');
    if ( $v->has_error ) {
        $self->flash( error => 'coupon 코드를 입력해주세요' );
        return $self->redirect_to('/coupon');
    }

    my $extra = $v->param('extra');
    my $codes = $v->every_param('code');
    my $code  = join( '-', @$codes );

    my ( $coupon, $err ) = $self->coupon_validate($code);
    if ($coupon) {
        $coupon->update( { extra => $extra } ) if $extra;
        $self->session( coupon_code => $coupon->code );
        $self->redirect_to('/visit');
    }
    else {
        $self->flash( error => $err );
        $self->redirect_to('/coupon');
    }
}

1;
