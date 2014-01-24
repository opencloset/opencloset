package OpenCloset::Cron::Worker;
# ABSTRACT: OpenCloset cron worker module

use v5.18;
use Moo;
use MooX::Types::MooseLike::Base qw( CodeRef Str );
use namespace::clean -except => 'meta';

has name => ( is => 'ro', isa => Str,     required => 1 );
has cron => ( is => 'ro', isa => Str,     required => 1 );
has cb   => ( is => 'ro', isa => CodeRef, required => 1 );

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

