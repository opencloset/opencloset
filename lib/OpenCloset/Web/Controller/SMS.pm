package OpenCloset::Web::Controller::SMS;
use Mojo::Base 'Mojolicious::Controller';

use SMS::Send;

has DB => sub { shift->app->DB };

=head1 METHODS

=head2 index

    GET /sms

=cut

sub index {
    my $self = shift;

    my %params = $self->get_params(qw/ to msg /);

    my $sender = SMS::Send->new(
        $self->config->{sms}{driver},
        %{ $self->config->{sms}{ $self->config->{sms}{driver} } },
    );
    $self->app->log->debug(
        sprintf( 'sms.driver: [%s]', $self->config->{sms}{driver} ) );

    my $balance = +{ success => undef };
    $balance = $sender->balance if $sender->_OBJECT_->can('balance');

    $self->render(
        'sms',
        to  => $params{to}  || q{},
        msg => $params{msg} || q{},
        balance => $balance->{success} ? $balance->{detail} : { cash => 0, point => 0 },
    );
}

1;
