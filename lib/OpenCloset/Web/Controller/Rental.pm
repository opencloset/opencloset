package OpenCloset::Web::Controller::Rental;
use Mojo::Base 'Mojolicious::Controller';

use DateTime;
use Mojo::JSON qw/decode_json/;
use Try::Tiny;

has DB => sub { shift->app->DB };

=head1 METHODS

=head2 index

    GET /rental

=cut

sub index {
    my $self = shift;

    my $dt_today = DateTime->now( time_zone => $self->config->{timezone} );
    $self->redirect_to( $self->url_for( '/rental/' . $dt_today->ymd ) );
}

=head2 ymd

    GET /rental/:ymd

=cut

sub ymd {
    my $self = shift;

    #
    # fetch params
    #
    my %params = $self->get_params(qw/ ymd /);

    unless ( $params{ymd} ) {
        app->log->warn("ymd is required");
        $self->redirect_to( $self->url_for('/rental') );
        return;
    }

    unless ( $params{ymd} =~ m/^(\d{4})-(\d{2})-(\d{2})$/ ) {
        app->log->warn("invalid ymd format: $params{ymd}");
        $self->redirect_to( $self->url_for('/rental') );
        return;
    }

    my $dt_start = try {
        DateTime->new(
            time_zone => $self->config->{timezone}, year => $1, month => $2,
            day       => $3,
        );
    };
    unless ($dt_start) {
        app->log->warn("cannot create start datetime object");
        $self->redirect_to( $self->url_for('/rental') );
        return;
    }

    my $dt_end = $dt_start->clone->add( hours => 24, seconds => -1 );
    unless ($dt_end) {
        app->log->warn("cannot create end datetime object");
        $self->redirect_to( $self->url_for('/rental') );
        return;
    }

    my $dtf      = $self->DB->storage->datetime_parser;
    my $order_rs = $self->DB->resultset('Order')->search(
        {
            'booking.date' => {
                -between => [ $dtf->format_datetime($dt_start), $dtf->format_datetime($dt_end), ],
            },
            'status.name' => '포장',
        },
        { join => [qw/ booking status /], order_by => { -asc => 'update_date' }, },
    );

    my $json    = $self->redis->get('opencloset:storage') || '{}';
    my $data    = decode_json($json);
    my @repairs = keys %{ $data->{repair} ||= {} };

    $self->stash(
        order_rs => $order_rs,
        repairs  => [@repairs],
        dt_start => $dt_start,
        dt_end   => $dt_end
    );
}

1;
