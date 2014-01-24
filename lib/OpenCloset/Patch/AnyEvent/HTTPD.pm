package OpenCloset::Patch::AnyEvent::HTTPD;
# ABSTRACT: Patch AnyEvent::HTTPD

{
    package AnyEvent::HTTPD;

    use strict;
    use warnings;

    no warnings 'redefine';

    #
    # this code is almost same as AnyEvent::HTTPD 0.93
    #
    sub handle_app_req {
        my ( $self, $meth, $url, $hdr, $cont, $host, $port, $respcb ) = @_;

        my $req = $self->{request_class}->new(
            httpd   => $self,
            method  => $meth,
            url     => $url,
            hdr     => $hdr,
            parm    => ( ref $cont ? $cont : {} ),
            content => ( ref $cont ? undef : $cont ),
            resp    => $respcb,
            host    => $host,
            port    => $port,
        );

        $self->{req_stop} = 0;
        $self->event( request => $req );
        return if $self->{req_stop};

        my @evs;
        my $cururl = '';
        for my $seg ( $url->path_segments ) {
            $cururl .= $seg;
            push @evs, $cururl;
            $cururl .= '/';
        }

        for my $ev ( 'auto', reverse @evs ) {
            $self->event( $ev => $req );
            last if $self->{req_stop};
        }
    }

    1;
}

1;
__END__

=head1 SYNOPSIS

    use AnyEvent::HTTPD;
    use OpenCloset::Patch::AnyEvent::HTTPD;

    my $httpd = AnyEvent::HTTPD->new( port => 9000 );
    $httpd->reg_cb(
        'auto' => sub {
            my ( $httpd, $req ) = @_;

            # this will be processed before every request event
        },
        '/foo' => sub { },
        '/bar' => sub { },
    );


=head1 DESCRIPTION

This patch enables B<auto> event like Catalyst's auto event.
B<auto> event is emitted before normal request event.
If you load this module after L<AnyEvent::HTTPD>,
then C<handle_app_req> method will be overridden.
