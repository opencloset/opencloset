package OpenCloset::Web::Controller::Root;
use Mojo::Base 'Mojolicious::Controller';

has DB => sub { shift->app->DB };

=head1 METHODS

=head2 index

    GET /

=cut

sub index { shift->render('home') }

=head2 browse_happy

    GET /browse-happy

=cut

sub browse_happy { shift->render('browse-happy') }

1;
