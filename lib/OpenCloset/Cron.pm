package OpenCloset::Cron;
# ABSTRACT: OpenCloset cron daemon module

use v5.18;
use Moo;
use MooX::Types::MooseLike::Base qw( ArrayRef Int );
use namespace::clean -except => 'meta';

extends qw( Object::Event );

use AnyEvent;
use AnyEvent::Timer::Cron;
use Object::Event;

has delay   => ( is => 'ro', isa => Int,      required => 1 );
has workers => ( is => 'ro', isa => ArrayRef, required => 1 );

has _timer => (
    is        => 'rw',
    predicate => '_has_timer',
    clearer   => '_clear_timer',
);

sub BUILD {
    my $self = shift;

    $self->reg_cb(
        'start' => sub {
            my $self = shift;

            my $t = AE::timer(
                $self->delay,
                0,
                sub { $self->event('do.work') },
            );
            $self->_timer($t);

            AnyEvent->condvar->recv;
        },
        'stop' => sub {
            my ( $self, $msg ) = @_;
            AE::log warn => $msg if $msg;

            AnyEvent->condvar->send;
        },
        'do.work' => sub {
            my $self = shift;

            $self->do_work;

            $self->_clear_timer if $self->_has_timer;
            my $t = AE::timer(
                $self->delay,
                0,
                sub { $self->event('do.work') },
            );
            $self->_timer($t);
        },
    );
}

sub start { $_[0]->event('start') }
sub stop  { $_[0]->event('stop')  }

sub do_work {
    my $self = shift;

    $self->_register_cron($_) for @{ $self->workers };
}

sub _register_cron {
    my ( $self, $worker ) = @_;

    my $name = $worker->name;
    my $cron = $worker->cron;
    my $cb   = $worker->cb;

    $cron //= q{};
    AE::log( debug => "$name: cron[$cron]" );

    if ( !$cron || $cron =~ /^\s*$/ ) {
        if ( $worker->_has_timer ) {
            AE::log( info  => "$name: clearing timer, cron rule is empty" );
            $worker->_clear_cron;
            $worker->_clear_timer;
        }
        return;
    }

    my @cron_items = split q{ }, $cron;
    unless ( @cron_items == 5 ) {
        AE::log( warn  => "$name: invalid cron format" );
        return;
    }

    if ( $worker->_has_timer ) {
        AE::log( debug => "$name: timer is already exists" );

        if ( $cron && $cron eq $worker->_cron ) {
            return;
        }
        AE::log( info => "$name: clearing timer before register" );
        $worker->_clear_cron;
        $worker->_clear_timer;
    }

    AE::log( info => "$name: register [$cron]" );
    my $cron_timer = AnyEvent::Timer::Cron->new(
        cron => $cron,
        cb   => $cb,
    );
    $worker->_cron($cron);
    $worker->_timer($cron_timer);
}

1;
__END__

=head1 SYNOPSIS

    ...


=head1 DESCRIPTION

...
