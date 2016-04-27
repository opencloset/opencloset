package OpenCloset::Web::Controller::Income;
use Mojo::Base 'Mojolicious::Controller';

use DateTime;
use DateTime::Format::Strptime;

has DB => sub { shift->app->DB };

our $STAGE_RENTAL_FEE  = 0;
our $STAGE_LATE_FEE    = 1;
our $STAGE_UNPAID_DENY = 4;
our $STAGE_UNPAID_DONE = 5;
our $STAGE_UNPAID_PART = 6;

=head1 METHODS

=head2 today

    GET /income

=cut

sub today {
    my $self = shift;

    my $today = DateTime->now( time_zone => 'Asia/Seoul' );
    $self->redirect_to( 'income.ymd', ymd => $today->ymd );
}

=head2 ymd

    # income.ymd
    GET /income/:ymd

=cut

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

    my $unpaid_rs =
        $self->DB->resultset('OrderDetail')
        ->search(
        { name => { -in => [qw/완납 부분완납 불납/] }, create_date => $between } );
    my $unpaid_fee = {};
    while ( my $od = $unpaid_rs->next ) {
        my $pay_with = $od->pay_with || 'Unknown';
        my $fee = $od->final_price;
        $unpaid_fee->{$pay_with} += $fee;
        $total_fee += $fee;
    }

    $self->render(
        ymd   => $ymd,
        today => DateTime->now,
        prev_date     => $dt->clone->add( days => -1 ),
        next_date     => $dt->clone->add( days => 1 ),
        rental_fee    => $rental_fee,
        late_fee      => $late_fee,
        unpaid_fee    => $unpaid_fee,
        total_fee     => $total_fee,
        rental_orders => $rental_rs->reset,
        return_orders => $return_rs->reset,
        unpaid_od     => $unpaid_rs->reset,
    );
}

1;
