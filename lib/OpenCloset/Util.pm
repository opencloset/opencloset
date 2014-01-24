package OpenCloset::Util;
# ABSTRACT: Random snippets of code that OpenCloset wants

use v5.18;
use utf8;
use strict;
use warnings;

use AnyEvent::Log;
use Path::Tiny;

sub load_config {
    my ( $conf_file, $section, %default ) = @_;

    $conf_file ||= 'app.conf';
    die "cannot find config file" unless -e $conf_file;
    my $conf = eval path($conf_file)->slurp_utf8;

    return $conf unless $section;

    $conf->{$section}{$_} //= $default{$_} for keys %default;

    return $conf->{$section};
}

sub set_ae_log {
    my ( $class, $conf ) = @_;

    return unless $conf;

    my %anon;

    my $pkg = sub {
        $_[0] eq "log"              ? $AnyEvent::Log::LOG
        : $_[0] eq "filter"         ? $AnyEvent::Log::FILTER
        : $_[0] eq "collect"        ? $AnyEvent::Log::COLLECT
        : $_[0] =~ /^%(.+)$/        ? ($anon{$1} ||= do { my $ctx = AnyEvent::Log::ctx undef; $ctx->[0] = $_[0]; $ctx })
        : $_[0] =~ /^(.*?)(?:::)?$/ ? AnyEvent::Log::ctx "$1" # egad :/
        : die # never reached?
    };

    $_ = $conf;

    /\G[[:space:]]+/gc; # skip initial whitespace

    while (/\G((?:[^:=[:space:]]+|::|\\.)+)=/gc) {
        my $ctx = $pkg->($1);
        my $level = "level";

        while (/\G((?:[^,:[:space:]]+|::|\\.)+)/gc) {
            for ("$1") {
                if ($_ eq "stderr"                           ) { $ctx->log_to_warn;
                } elsif (/^file=(.+)/                        ) { $ctx->log_to_file ("$1");
                } elsif (/^path=(.+)/                        ) { $ctx->log_to_path ("$1");
                } elsif (/^syslog(?:=(.*))?/                 ) { require Sys::Syslog; $ctx->log_to_syslog ("$1");
                } elsif ($_ eq "nolog"                       ) { $ctx->log_cb (undef);
                } elsif (/^cap=(.+)/                         ) { $ctx->cap ("$1");
                } elsif (/^\+(.+)$/                          ) { $ctx->attach ($pkg->("$1"));
                } elsif ($_ eq "+"                           ) { $ctx->slaves;
                } elsif ($_ eq "off" or $_ eq "0"            ) { $ctx->level (0);
                } elsif ($_ eq "all"                         ) { $ctx->level ("all");
                } elsif ($_ eq "level"                       ) { $ctx->level ("all"); $level = "level";
                } elsif ($_ eq "only"                        ) { $ctx->level ("off"); $level = "enable";
                } elsif ($_ eq "except"                      ) { $ctx->level ("all"); $level = "disable";
                } elsif (/^\d$/                              ) { $ctx->$level ($_);
                } elsif (exists $AnyEvent::Log::STR2LEVEL{$_}) { $ctx->$level ($_);
                } else                             { die "PERL_ANYEVENT_LOG ($conf): parse error at '$_'\n";
                }
            }

            /\G,/gc or last;
        }

        /\G[:[:space:]]+/gc or last;
    }

    /\G[[:space:]]+/gc; # skip trailing whitespace

    if (/\G(.+)/g) {
        die "PERL_ANYEVENT_LOG ($conf): parse error at '$1'\n";
    }
}

1;
__END__
