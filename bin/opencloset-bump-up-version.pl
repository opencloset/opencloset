#!/usr/bin/env perl

use utf8;
use strict;
use warnings;

use feature qw( say );

use Capture::Tiny;
use Path::Tiny;
use Version::Next;
use version;

my @FILES = qw(
    Changes
    README.md
    lib/OpenCloset/Web.pm
    RELEASE-TODO.md
);

clear_files(@FILES);
my ( $next_version, $current_version ) = next_version();
update_version( $_, $current_version, $next_version )
    for qw{ README.md lib/OpenCloset/Web.pm };
update_changes( "Changes", $current_version, $next_version );
update_releasetodo( "RELEASE-TODO.md", $next_version );
git_add_commit(@FILES);

sub clear_files {
    my @files = @_;

    system( "git", "checkout", @FILES );
}

sub git_add_commit {
    my @files = @_;

    system( "git", "add",    @files );
    system( "git", "diff",   "--staged" );
    system( "git", "commit", "-m", "Bump up version" );
}

sub update_changes {
    my ( $file, $old_ver, $new_ver ) = @_;

    my $path    = path($file);
    my $content = $path->slurp_utf8;

    my $date;
    {
        my ( $stdout, @result ) = Capture::Tiny::capture_stdout { system "date", "-R" };
        $date = $stdout;
        chomp $date;
    }

    $content =~ s{## \[Unreleased\]\n}{## \[Unreleased\]\n\n## [$new_ver] - $date};
    $path->spew_utf8($content);
}

sub update_version {
    my ( $file, $old_ver, $new_ver ) = @_;

    my $path    = path($file);
    my $content = $path->slurp_utf8;
    $content =~ s/$old_ver/$new_ver/gms;
    $path->spew_utf8($content);
}

sub next_version {
    my ( $stdout, @result ) = Capture::Tiny::capture_stdout { system "git", "tag" };

    my @lines;
    {
        open my $fh, "<", \$stdout or die "$!\n";
        while (<$fh>) {
            chomp;
            push @lines, $_;
        }
    }
    my ($latest_version) =
        reverse sort { version->parse($a) <=> version->parse($b) } @lines;
    my $next_version = Version::Next::next_version($latest_version);

    return ( $next_version, $latest_version );
}

sub update_releasetodo {
    my ( $file, $new_ver ) = @_;

    my $path    = path($file);
    my $content = $path->slurp_utf8;

    $path->spew_utf8( "$new_ver\n\n", $content );
}
