package OpenCloset::Web::Command::returned2payback;

use Mojo::Base 'Mojolicious::Command';

use OpenCloset::Common::OrderStatus qw/returned2payback/;

has description => 'Update order status to PAYBACK from RETURNED';
has usage =>
    "\$ MOJO_CONFIG=app.conf script/web returned2payback <ORDER_ID> <COMMISSION>?\n";

=encoding utf-8

=head1 NAME

OpenCloset::Web::Command::returned2payback - 반납 주문서를 환불로 변경

=head1 SYNOPSIS

    $ MOJO_CONFIG=/path/to/app.conf ./script/web returned2payback <ORDER_ID> <COMMISSION>?

    # 50102 주문서를 환불 수수료 없이
    $ MOJO_CONFIG=/path/to/app.conf ./script/web returned2payback 50102

    # 50102 주문서를 환불 수수료 5000원에
    $ MOJO_CONFIG=/path/to/app.conf ./script/web returned2payback 50102 5000

=head1 METHODS

=head2 run

=cut

sub run {
    my ( $self, $order_id, $commission ) = @_;
    die "order_id is required" unless $order_id;

    my $app   = $self->app;
    my $DB    = $app->DB;
    my $order = $DB->resultset('Order')->find( { id => $order_id } );
    die $self->usage unless $order;

    my $success = returned2payback( $order, $commission );
    die "Failed to update order to PAYBACK\n" unless $success;

    print "Successfully updated order($order_id) from RETURNED to PAYBACK\n";
}

=head1 COPYRIGHT

The MIT License (MIT)

Copyright (c) 2017 열린옷장

=cut

1;
