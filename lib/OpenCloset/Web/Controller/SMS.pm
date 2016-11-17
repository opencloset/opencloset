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

    my $macros = $self->DB->resultset('SmsMacro')->search;
    $self->render(
        'sms',
        to  => $params{to}  || q{},
        msg => $params{msg} || q{},
        balance => $balance->{success} ? $balance->{detail} : { cash => 0, point => 0 },
        macros => $macros,
    );
}

=head2 macros

    GET /macros

=cut

sub macros {
    my $self   = shift;
    my $macros = $self->DB->resultset('SmsMacro')->search;
    $self->render( 'sms/macros', macros => $macros );
}

=head2 macro

    GET /macros/:id

=cut

sub macro {
    my $self = shift;
    my $id   = $self->param('id');
    my $macro = $self->DB->resultset('SmsMacro')->find( { id => $id } );
    return $self->error( 404, { str => "Not found macro: $id" } ) unless $macro;

    $self->render( 'sms/macro', macro => $macro );
}

=head2 update_macro

    PUT /macros/:id

=cut

sub update_macro {
    my $self = shift;
    my $id   = $self->param('id');
    my $macro = $self->DB->resultset('SmsMacro')->find( { id => $id } );
    return $self->error( 404, { str => "Not found macro: $id" } ) unless $macro;

    my $v = $self->validation;
    $macro->update($v->input);
    $self->flash(success => '수정되었습니다');
    $self->render(json => {});
}

=head2 delete_macro

    DELETE /macros/:id

=cut

sub delete_macro {
    my $self = shift;
    my $id   = $self->param('id');
    my $macro = $self->DB->resultset('SmsMacro')->find( { id => $id } );
    return $self->error( 404, { str => "Not found macro: $id" } ) unless $macro;

    $macro->delete;
    $self->flash(success => '삭제되었습니다');
    $self->render(json => {});
}

1;
