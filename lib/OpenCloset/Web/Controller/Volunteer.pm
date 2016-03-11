package OpenCloset::Web::Controller::Volunteer;
use Mojo::Base 'Mojolicious::Controller';

use Data::Pageset;
use DateTime;

has DB => sub { shift->app->DB };

=head1 METHODS

=head2 index

    GET /volunteer

=cut

sub index {
    my $self   = shift;
    my $status = $self->param('status') || 'reported';
    my $query  = $self->param('q') // '';

    $self->stash( pageset => '' ); # prevent undefined error in template

    my ( $works, $standby );
    my $parser = $self->DB->storage->datetime_parser;
    $works = $self->DB->resultset('VolunteerWork')
        ->search( { status => $status }, { order_by => 'activity_from_date' } );

    if ( $status eq 'done' ) {
        $works = $works->search(
            {
                activity_from_date =>
                    { '>' => $parser->format_datetime( DateTime->now->subtract( days => 7 ) ) },
                need_1365 => 1,
                done_1365 => { '<>' => 0 },
            },
            {
                order_by => [
                    { -desc => 'need_1365' }, { -asc => 'done_1365' }, { -asc => 'activity_from_date' }
                ]
            }
        );
        $standby = $self->DB->resultset('VolunteerWork')->search(
            { status   => $status, need_1365 => 1,             done_1365 => 0, },
            { order_by => [        { -desc   => 'need_1365' }, { -asc    => 'done_1365' } ] }
        );
    }
    elsif ( $status eq 'canceled' ) {
        my $p = $self->param('p') || 1;
        $works = $works->search(
            undef,
            { page => $p, rows => 10, order_by => { -desc => 'id' } }
        );

        my $pageset = Data::Pageset->new(
            {
                total_entries    => $works->pager->total_entries,
                entries_per_page => $works->pager->entries_per_page,
                pages_per_set    => 5,
                current_page     => $p,
            }
        );

        $self->stash( pageset => $pageset );
    }

    if ($query) {
        $works = $self->DB->resultset('VolunteerWork')->search(
            {
                -or => {
                    'volunteer.name'  => $query,
                    'volunteer.phone' => $self->phone_format($query),
                    'volunteer.email' => $query
                }
            },
            { join => 'volunteer' }
        );
    }

    $self->render( works => $works, standby => $standby );
}

1;
