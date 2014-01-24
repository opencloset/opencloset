package OpenCloset::Patch::Object::Event;
# ABSTRACT: Patch Object::Event

{
    package Object::Event;

    use strict;
    use warnings;

    no warnings 'redefine';

    #
    # this code is almost same as Object::Event 1.23
    #

    our @DEBUG_STACK;

    sub _debug_cb {
        my ($callback) = @_;

        sub {
            my @a = @_;
            my $dbcb = $_[0]->{__oe_cbs}->[0]->[0];
            my $nam  = $_[0]->{__oe_cbs}->[2];
            push @DEBUG_STACK, $dbcb;

            my $pad = "  " x scalar @DEBUG_STACK;

            AE::log( debug => "%s-> %s\n", $pad, $dbcb->[3] );

            eval { $callback->(@a) };
            my $e = $@;

            AE::log( debug => "%s<- %s\n", $pad, $dbcb->[3] );

            pop @DEBUG_STACK;

            die $e if $e;
            ()
        };
    }

    sub _print_event_debug {
        my ($ev) = @_;
        my $pad = "  " x scalar @DEBUG_STACK;
        my ($pkg, $file, $line) = caller (1);
        for my $path (@INC) {
            last if $file =~ s/^\Q$path\E\/?//;
        }
        AE::log( debug => "%s!! %s @ %s:%d (%s::)\n", $pad, $ev, $file, $line, $pkg );
    }

    1;
}

1;
__END__

=head1 SYNOPSIS

    use Object::Event;
    use OpenCloset::Patch::Object::Event;


=head1 DESCRIPTION

This patch prints L<Object::Event>'s message via L<AnyEvent::Log>.
If you load this module after L<Object::Event>,
then C<_debug_cb()> and C<_print_event_debug()>
private method will be overridden.
