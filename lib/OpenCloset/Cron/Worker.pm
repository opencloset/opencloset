package OpenCloset::Cron::Worker;
# ABSTRACT: OpenCloset cron worker module

use v5.18;
use Moo;
use MooX::Types::MooseLike::Base qw( CodeRef Str );
use namespace::clean -except => 'meta';

use Scalar::Util qw( weaken );

has name => ( is => 'ro', isa => Str,     required => 1 );
has cron => ( is => 'ro', isa => Str,     required => 1 );
has cb   => ( is => 'rw', isa => CodeRef, builder  => '_default_cb' );

sub _default_cb {
    my $self = shift;

    weaken($self);
    return sub {
        my $name = $self->name;
        AE::log( debug => "$name: dummy cron worker" );
    };
}

has _timer => (
    is        => 'rw',
    predicate => '_has_timer',
    clearer   => '_clear_timer',
);

has _cron => (
    is        => 'rw',
    predicate => '_has_cron',
    clearer   => '_clear_cron',
);

1;
__END__

