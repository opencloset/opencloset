package OpenCloset::Util;
# ABSTRACT: Random snippets of code that OpenCloset wants

use v5.18;
use utf8;
use strict;
use warnings;

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

1;
__END__
