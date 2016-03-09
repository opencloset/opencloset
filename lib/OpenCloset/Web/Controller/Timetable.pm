package OpenCloset::Web::Controller::Timetable;
use Mojo::Base 'Mojolicious::Controller';

use DateTime;
use Try::Tiny;

has DB => sub { shift->app->DB };

=head1 METHODS

=head2 index

    GET /timetable

=cut

sub index {
    my $self = shift;

    my $dt_today = DateTime->now( time_zone => $self->config->{timezone} );
    $self->redirect_to( $self->url_for( '/timetable/' . $dt_today->ymd ) );
}

=head2 ymd

    GET /timetable/:ymd

=cut

sub ymd {
    my $self = shift;

    #
    # fetch params
    #
    my %params = $self->get_params(qw/ ymd /);

    unless ( $params{ymd} ) {
        $self->app->log->warn("ymd is required");
        $self->redirect_to( $self->url_for('/timetable') );
        return;
    }

    unless ( $params{ymd} =~ m/^(\d{4})-(\d{2})-(\d{2})$/ ) {
        $self->app->log->warn("invalid ymd format: $params{ymd}");
        $self->redirect_to( $self->url_for('/timetable') );
        return;
    }

    my $dt_start = try {
        DateTime->new(
            time_zone => $self->config->{timezone}, year => $1, month => $2,
            day       => $3,
        );
    };
    unless ($dt_start) {
        $self->app->log->warn("cannot create start datetime object");
        $self->redirect_to( $self->url_for('/timetable') );
        return;
    }

    my $dt_end = $dt_start->clone->add( hours => 24, seconds => -1 );
    unless ($dt_end) {
        $self->app->log->warn("cannot create end datetime object");
        $self->redirect_to( $self->url_for('/timetable') );
        return;
    }

    my %orders;
    my $count = $self->count_visitor(
        $dt_start,
        $dt_end,
        sub {
            my ( $booking, $order, $gender ) = @_;

            my $hm = sprintf '%02d:%02d', $booking->date->hour, $booking->date->minute;
            $orders{$hm}{$gender} = [] unless $orders{$hm}{$gender};
            push @{ $orders{$hm}{$gender} }, $order;
        }
    );

    $self->render(
        count    => $count,    orders => \%orders,
        dt_start => $dt_start, dt_end => $dt_end,
    );
}

1;
