package OpenCloset::Web::Controller::Income;
use Mojo::Base 'Mojolicious::Controller';

use DateTime;
use DateTime::Format::Strptime;

has DB => sub { shift->app->DB };

=head1 METHODS

=head2 ymd

    GET /income/:ymd

=cut

our $STAGE_RENTAL_FEE = 0;
our $STAGE_LATE_FEE   = 1;

sub ymd {
    my $self = shift;
    my $ymd  = $self->param('ymd');

    my $strp    = DateTime::Format::Strptime->new( pattern => '%Y-%m-%d' );
    my $dt      = $strp->parse_datetime($ymd);
    my $parser  = $self->DB->storage->datetime_parser;
    my $between = {
        -between => [
            $parser->format_datetime($dt),
            $parser->format_datetime( $dt->clone->add( hours => 24, seconds => -1 ) )
        ]
    };

    my $rental_rs = $self->DB->resultset('Order')->search( { rental_date => $between } );

    my $total_fee  = 0;
    my $rental_fee = {};
    while ( my $order = $rental_rs->next ) {
        my $pay_with = $order->price_pay_with || 'Unknown';
        my ( undef, $price ) = $self->order_price($order);
        my $fee = $price->{$STAGE_RENTAL_FEE} || 0;
        $rental_fee->{$pay_with} += $fee;
        $total_fee += $fee;
    }

    my $return_rs = $self->DB->resultset('Order')->search( { return_date => $between } );
    my $late_fee = {};
    while ( my $order = $return_rs->next ) {
        my $pay_with = $order->late_fee_pay_with || 'Unknown';
        my ( undef, $price ) = $self->order_price($order);
        my $fee = $price->{$STAGE_LATE_FEE} || 0;
        $late_fee->{$pay_with} += $fee;
        $total_fee += $fee;
    }

    $self->render(
        ymd       => $ymd, rental_fee => $rental_fee, late_fee => $late_fee,
        total_fee => $total_fee,
        rental_orders => $rental_rs->reset, return_orders => $return_rs->reset
    );
}

1;
