package OpenCloset::Web::Controller::Agent;
use Mojo::Base 'Mojolicious::Controller';

use Data::Dump;

has DB => sub { shift->app->DB };

=head1 METHODS

=head2 add

    GET /orders/:id/agent

=cut

sub add {
    my $self = shift;
    my $id   = $self->param('id');

    my $order = $self->DB->resultset('Order')->find( { id => $id } );
    return $self->error( 404, { str => "Order not found: $id" } ) unless $order;
    return $self->error(
        400,
        { str => "대리인 대여 주문서가 아닙니다." },
        'error/bad_request'
    ) unless $order->agent;

    ## redirect from booking#visit
    my $qty = $self->session('agent_quantity') || 1;
    my $error = $self->flash('error');
    dd $error;
    $self->render( order => $order, quantity => $qty, error => $error );
}

=head2 create

    POST /orders/:id/agent

=cut

sub create {
    my $self = shift;
    my $id   = $self->param('id');

    my $order = $self->DB->resultset('Order')->find( { id => $id } );
    return $self->error( 404, { str => "Order not found: $id" } ) unless $order;
    return $self->error(
        400,
        { str => "대리인 대여 주문서가 아닙니다." },
        'error/bad_request'
    ) unless $order->agent;

    my $v = $self->validation;
    $v->required('gender')->like(qr/^(fe)?male$/);
    $v->required('label');
    $v->required('height');
    $v->required('weight');
    $v->optional('neck');
    $v->optional('bust');
    $v->optional('waist');
    $v->optional('hip');
    $v->optional('topbelly');
    $v->optional('belly');
    $v->optional('thigh');
    $v->optional('arm');
    $v->optional('leg');
    $v->optional('knee');
    $v->optional('pants');
    $v->optional('foot');
    $v->optional('skirt');

    if ( $v->has_error ) {
        my $errors = {};
        my $failed = $v->failed;
        map { $errors->{$_} = $v->error($_) } @$failed;
        $self->flash( error => $errors );
        return $self->redirect_to( $self->url_for );
    }

    my $gender = $self->every_param('gender');
    my $label  = $self->every_param('label');
    my $height = $self->every_param('height');
    my $weight = $self->every_param('weight');

    dd $gender;
    dd $label;
    dd $height;
    dd $weight;

    return $self->redirect_to( $self->url_for );
}

1;
