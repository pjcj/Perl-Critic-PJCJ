package Perl::Critic::PJCJ::AtomicWrite;

use v5.26.0;
use strict;
use warnings;
use feature      qw( signatures );
use experimental qw( signatures );

use Cwd            qw( abs_path );
use Exporter       qw( import );
use File::Basename qw( dirname );
use File::Temp     qw( tempfile );

our @EXPORT_OK = qw( write_atomic );

sub write_atomic ($file, $content, $mode) {
  $file = abs_path($file) // $file if -l $file;

  my ($out, $temp) = eval {
    tempfile("perl-critic-pjcj-XXXXXX", DIR => dirname($file), UNLINK => 0)
  };
  return "Cannot create temporary file for $file: $@" unless $out;

  my $ok    = print {$out} $content;
  my $error = $ok ? "" : "$!";
  unless (close $out) {
    $ok      = 0;
    $error ||= "$!";
  }
  $ok &&= chmod $mode, $temp;
  $ok &&= rename $temp, $file;
  return if $ok;

  $error ||= "$!";
  unlink $temp;
  "Cannot write $file: $error"
}

"
Hold on to what you've got
It's only in your mind
"

__END__

=head1 NAME

Perl::Critic::PJCJ::AtomicWrite - replace a file without risking its contents

=head1 SYNOPSIS

  use Perl::Critic::PJCJ::AtomicWrite qw( write_atomic );

  my $error = write_atomic($file, $content, $mode);
  warn "$error\n" if defined $error;

=head1 DESCRIPTION

Writes a new body for an existing file through a temporary file in the same
directory, followed by a rename. A failed write leaves the original file
untouched rather than truncated, which matters for the tools in this
distribution because they rewrite files a user has already composed or
committed.

=head1 FUNCTIONS

=head2 write_atomic ($file, $content, $mode)

Replace C<$file> with C<$content> and give the result the permissions
C<$mode>. A symbolic link is resolved first, so the link keeps pointing at its
target and the target takes the new content. Return the undefined value on
success, or a message describing the failure. The caller decides how to report
it.

=head1 AUTHOR

Paul Johnson <paul@pjcj.net>

=head1 LICENCE

This library is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut
