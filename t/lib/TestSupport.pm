package TestSupport;

use v5.26.0;
use strict;
use warnings;
use feature      qw( signatures );
use experimental qw( signatures );

use Exporter  qw( import );
use Test2::V0 qw( skip_all );

our @EXPORT_OK = qw( git_available read_file run_capture skip_for_root
  skip_on_windows write_file );

sub write_file ($path, $content, $mode = undef) {
  open my $fh, ">:raw", $path or die "Cannot write $path: $!\n";
  print {$fh} $content;
  close $fh or die "Cannot close $path: $!\n";
  chmod $mode, $path or die "Cannot chmod $path: $!\n" if defined $mode;
  $path
}

sub read_file ($path) {
  open my $fh, "<:raw", $path or die "Cannot read $path: $!\n";
  my $content = do { local $/ = undef; <$fh> };
  close $fh or die "Cannot close $path: $!\n";
  $content // ""
}

sub run_capture (@cmd) {
  my $command = join " ", map "\Q$_\E", @cmd;
  my $out     = qx($command 2>&1);
  ($out, $? >> 8)
}

sub git_available () {
  open my $fh, "-|", "git", "--version" or return 0;
  my $out = do { local $/ = undef; <$fh> };
  close $fh or return 0;
  defined $out && $out =~ /git version/
}

sub skip_on_windows ($why) { skip_all $why if $^O eq "MSWin32" }

sub skip_for_root ($why) { skip_all $why if $> == 0 }

"
And the trees are all kept equal
By hatchet, axe and saw
"

__END__

=head1 NAME

TestSupport - file, process and skip helpers shared by the test files

=head1 SYNOPSIS

  use lib "t/lib";
  use TestSupport qw( read_file run_capture write_file );

  my $path = write_file("$dir/a.pm", "my \$x = 1;\n");
  my ($out, $exit) = run_capture($^X, "utils/perl-hook", "tidy", $path);
  my $content = read_file($path);

=head1 DESCRIPTION

Small helpers that several test files need. Each one dies with a message
naming the path on failure, so a broken fixture stops the test rather than
producing a confusing assertion later.

=head1 FUNCTIONS

=head2 write_file

  write_file($path, $content);
  write_file($path, $content, $mode);

Writes C<$content> to C<$path> as raw bytes, sets the permissions to C<$mode>
when one is given, and returns C<$path>.

=head2 read_file

  my $content = read_file($path);

Returns the whole content of C<$path> as raw bytes, or the empty string for
an empty file.

=head2 run_capture

  my ($output, $exit) = run_capture(@command);

Runs C<@command> through the shell with each word quoted, and returns its
combined standard output and standard error together with its exit status.

=head2 git_available

  skip_all "git not available" unless git_available();

Returns true when a C<git> command runs and reports its version.

=head2 skip_on_windows

  skip_on_windows "symlinks are not reliable on Windows";

Skips the enclosing test or subtest with the given reason on Windows.

=head2 skip_for_root

  skip_for_root "directory permissions are not enforced for root";

Skips the enclosing test or subtest with the given reason when running as
root, for tests that depend on permission checks.

=head1 AUTHOR

Paul Johnson <paul@pjcj.net>

=head1 LICENCE

This library is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut
