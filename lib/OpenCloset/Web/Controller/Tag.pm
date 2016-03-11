package OpenCloset::Web::Controller::Tag;
use Mojo::Base 'Mojolicious::Controller';

has DB => sub { shift->app->DB };

=head1 METHODS

=head2 index

    GET /

=cut

sub index {
    my $self = shift;

    #
    # response
    #
    $self->stash( 'tag_rs' => $self->DB->resultset('Tag') );
}

1;
