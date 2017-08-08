package OpenCloset::Web::Controller::Agent;
use Mojo::Base 'Mojolicious::Controller';

use OpenCloset::Constants::Measurement ();

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
    my $agents = $order->order_agents;
    $self->render( order => $order, quantity => $qty, agents => $agents );
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
    $v->optional('label');
    $v->optional('gender')->in(qw/male female/);
    $v->optional('pre_category');
    $v->optional('height')->size( 3, 3 );
    $v->optional('weight')->size( 2, 3 );
    $v->optional('neck')->size( 2, 2 );
    $v->optional('bust')->size( 2, 3 );
    $v->optional('waist')->size( 2, 3 );
    $v->optional('hip')->size( 2, 3 );
    $v->optional('topbelly')->size( 2, 3 );
    $v->optional('belly')->size( 2, 3 );
    $v->optional('thigh')->size( 2, 3 );
    $v->optional('arm')->size( 2, 3 );
    $v->optional('leg')->size( 2, 3 );
    $v->optional('knee')->size( 2, 3 );
    $v->optional('foot')->size( 3, 3 );
    $v->optional('pants')->size( 3, 3 );
    $v->optional('skirt')->size( 3, 3 );

    if ( $v->has_error ) {
        my $failed = $v->failed;
        my @names = map { $OpenCloset::Constants::Measurement::LABEL_MAP{$_} } @$failed;
        $self->flash( alert_error => "잘못된 입력 값이 있습니다: @names" );
        return $self->redirect_to;
    }

    my $category = $self->every_param('pre_category');
    my $row      = $self->DB->resultset('OrderAgent')->create(
        {
            order_id     => $order->id,
            label        => $self->param('label'),
            gender       => $self->param('gender'),
            pre_category => join( ',', @$category ),
            height       => $self->param('height') || 0,
            weight       => $self->param('weight') || 0,
            neck         => $self->param('neck') || 0,
            bust         => $self->param('bust') || 0,
            waist        => $self->param('waist') || 0,
            hip          => $self->param('hip') || 0,
            topbelly     => $self->param('topbelly') || 0,
            belly        => $self->param('belly') || 0,
            thigh        => $self->param('thigh') || 0,
            arm          => $self->param('arm') || 0,
            leg          => $self->param('leg') || 0,
            knee         => $self->param('knee') || 0,
            foot         => $self->param('foot') || 0,
            pants        => $self->param('pants') || 0,
            skirt        => $self->param('skirt') || 0,
        }
    );

    return $self->redirect_to( $self->url_for );
}

=head2 delete

    DELETE /orders/:id/agent?agent_id=xxx

=cut

sub delete {
    my $self = shift;
    my $id   = $self->param('id');

    my $order = $self->DB->resultset('Order')->find( { id => $id } );
    return $self->error( 404, { str => "Order not found: $id" } ) unless $order;
    return $self->error(
        400,
        { str => "대리인 대여 주문서가 아닙니다." },
        'error/bad_request'
    ) unless $order->agent;

    my $agent_id = $self->param('agent_id');
    return $self->error( 400, { str => "agent_id parameter is required" } )
        unless $agent_id;

    my $agent = $order->order_agents( { id => $agent_id } )->next;
    return $self->error( 404, { str => "Agent info Not found: $agent_id" } )
        unless $agent;

    $agent->delete;
    $self->render( json => {} );
}

1;
