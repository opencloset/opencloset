package OpenCloset::Role::Ping;
# ABSTRACT: OpenCloset Ping Role

use Moo::Role;
use MooX::Types::MooseLike::Base qw( Int );
use namespace::clean -except => 'meta';

use AnyEvent::HTTPD;
use AnyEvent;
use Scalar::Util qw( weaken );

has ping_port => (
    is       => 'ro',
    isa      => Int,
    required => 1,
);

has _ping_httpd => (
    is => 'rw',
);

sub add_ping {
    my ( $self, $ping ) = @_;

    my $httpd = AnyEvent::HTTPD->new( port => $self->ping_port );
    $httpd->reg_cb(
        'auto' => sub {
            my ( $httpd, $req ) = @_;

            AE::log info => sprintf(
                'HTTP-REQ [%s:%s]->[%s:%s] %s',
                $req->client_host,
                $req->client_port,
                $httpd->host,
                $httpd->port,
                $req->url,
            );
        },
        '/ping' => sub {
            my ( $httpd, $req ) = @_;

            if ( $ping->($self, $httpd) ) {
                $req->respond([
                    200,
                    'OK',
                    { 'Content-Type' => 'text/plain' },
                    "pong\n",
                ]);
            }
            else {
                $req->respond([
                    400,
                    'Bad Request',
                    { 'Content-Type' => 'text/plain' },
                    "failed to pong\n",
                ]);
            }
        },
    );

    $self->_ping_httpd($httpd);
}

1;
__END__

=head1 SYNOPSIS

    package Your::Module;
    use Moo;
    with qw( OpenCloset::Role::Ping );

    package main;
    use Your::Module;

    my $ym = Your::Module->new(
        ping_port => 20000,
    );
    $ym->add_ping(sub {
        my ( $self, $httpd ) = @_;
        my $ret = ... # check it is available or not
        return $ret;  # true or false
    });


=head1 DESCRIPTION

This role will help to equip ping based on HTTP feature in you module.


=attr ping_port

Specify ping port via HTTP. Read-only.
No default value.

    my $ym = Your::Module->new(
        ping_port => 20000,
    );


=method add_ping

Register C</ping> controller with given C<ping_port>.

    $ym->add_ping(sub {
        my ( $self, $httpd ) = @_;

        # ...

        return $ret;  # true or false
    })
