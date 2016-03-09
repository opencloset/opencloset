package OpenCloset::Web::Controller::CSV;
use Mojo::Base 'Mojolicious::Controller';

use DateTime;
use Mojo::Util qw( encode );
use Text::CSV;

has DB => sub { shift->app->DB };

=head1 METHODS

=head2 user

    GET /csv/user

=cut

sub user {
    my $self = shift;

    my $csv = Text::CSV->new( { binary => 1, eol => "\n", } )
        or return $self->error(
        500,
        { str => "Cannot use CSV: " . Text::CSV->error_diag, data => {}, }
        );

    my $dt = DateTime->now( time_zone => $self->config->{timezone} );
    my $filename = 'user-' . $dt->ymd(q{}) . '-' . $dt->hms(q{}) . '.csv';

    $self->res->headers->content_disposition("attachment; filename=$filename");

    my $rs = $self->DB->resultset('User');
    my $cb_finish;
    $cb_finish = sub {
        my $self = shift;

        my $user = $rs->next;
        $self->finish, return unless $user;

        $csv->combine(
            $user->id,                  $user->name,                $user->email,
            $user->create_date,         $user->user_info->phone,    $user->user_info->address1,
            $user->user_info->address2, $user->user_info->address3, $user->user_info->address4,
            $user->user_info->gender,   $user->user_info->birth,
        );
        $self->write_chunk( encode( 'UTF-8', $csv->string ) => $cb_finish );
    };

    $csv->combine(
        qw/
            id
            name
            email
            createdate
            phone
            address1
            address2
            address3
            address4
            gender
            birth
            /
    );
    $self->write_chunk( encode( 'UTF-8', $csv->string ) => $cb_finish );

    #
    # response
    #
    $self->res->headers->content_type('text/plain');
}

=head2 clothes

    GET /csv/clothes

=cut

sub clothes {
    my $self = shift;

    my $csv = Text::CSV->new( { binary => 1, eol => "\n", } )
        or return $self->error(
        500,
        { str => "Cannot use CSV: " . Text::CSV->error_diag, data => {}, }
        );

    my $dt = DateTime->now( time_zone => $self->config->{timezone} );
    my $filename = 'clothes-' . $dt->ymd(q{}) . '-' . $dt->hms(q{}) . '.csv';

    $self->res->headers->content_disposition("attachment; filename=$filename");

    my $rs = $self->DB->resultset('Clothes');
    my $cb_finish;
    $cb_finish = sub {
        my $self = shift;

        my $clothes = $rs->next;
        $self->finish, return unless $clothes;

        $csv->combine(
            $clothes->id,    $clothes->code,     $clothes->category, $clothes->gender,
            $clothes->color, $clothes->neck,     $clothes->bust,     $clothes->waist,
            $clothes->hip,   $clothes->topbelly, $clothes->belly,    $clothes->arm,
            $clothes->thigh, $clothes->length,   $clothes->compatible_code,
        );
        $self->write_chunk( encode( 'UTF-8', $csv->string ) => $cb_finish );
    };

    $csv->combine(
        qw/
            id
            code
            category
            gender
            color
            neck
            bust
            waist
            hip
            topbelly
            belly
            arm
            thigh
            length
            compatible_code
            /
    );
    $self->write_chunk( encode( 'UTF-8', $csv->string ) => $cb_finish );

    #
    # response
    #
    $self->res->headers->content_type('text/plain');
}

1;
