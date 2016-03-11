package OpenCloset::Web::Controller::Coupon;
use Mojo::Base 'Mojolicious::Controller';

has DB => sub { shift->app->DB };

=head1 METHODS

=head2 index

    GET /coupon

=cut

sub index { }

=head2 validate

    GET /coupon/:code/validate

=cut

sub validate {
    my $self = shift;
}

1;
