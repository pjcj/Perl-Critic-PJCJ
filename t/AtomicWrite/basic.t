#!/usr/bin/env perl

use v5.26.0;
use strict;
use warnings;

use Test2::V0    qw( done_testing is like ok skip_all subtest );
use feature      qw( signatures );
use experimental qw( signatures );

use File::Temp                      qw( tempdir );
use lib                             qw( lib );
use Perl::Critic::PJCJ::AtomicWrite qw( write_atomic );

sub write_file ($path, $content, $mode = 0644) {
  open my $fh, ">", $path or die "Cannot write $path: $!\n";
  print {$fh} $content;
  close $fh or die "Cannot close $path: $!\n";
  chmod $mode, $path or die "Cannot chmod $path: $!\n";
}

sub read_file ($path) {
  open my $fh, "<", $path or die "Cannot read $path: $!\n";
  local $/;
  <$fh>
}

sub set_mode ($path, $mode) {
  chmod $mode, $path or die "Cannot chmod $path: $!\n";
}

sub make_link ($target, $link) {
  symlink $target, $link or die "Cannot symlink $link: $!\n";
}

sub skip_on_windows ($why) { skip_all $why if $^O eq "MSWin32" }

sub skip_for_root ($why) { skip_all $why if $> == 0 }

subtest "A successful write replaces the file and keeps the mode" => sub {
  my $dir  = tempdir(CLEANUP => 1);
  my $file = "$dir/a.txt";
  write_file($file, "old\n", 0640);
  is write_atomic($file, "new\n", 0640), undef,   "no error is returned";
  is read_file($file),                   "new\n", "the content is replaced";
  is + ((stat $file)[2] & 07777),        0640,    "the mode is preserved";
};

subtest "A symlink keeps pointing at its target" => sub {
  skip_on_windows "symlinks are not reliable on Windows";
  my $dir    = tempdir(CLEANUP => 1);
  my $target = "$dir/target.txt";
  my $link   = "$dir/link.txt";
  write_file($target, "old\n");
  make_link($target, $link);
  is write_atomic($link, "new\n", 0644), undef, "no error is returned";
  is read_file($target), "new\n",               "the target takes the content";
  ok -l $link, "the link is still a link";
};

subtest "An unwritable directory reports the cause" => sub {
  skip_on_windows "directory permissions differ on Windows";
  skip_for_root "directory permissions are not enforced for root";
  my $dir  = tempdir(CLEANUP => 1);
  my $file = "$dir/a.txt";
  write_file($file, "old\n");
  set_mode($dir, 0555);
  my $error = write_atomic($file, "new\n", 0644);
  set_mode($dir, 0755);
  like $error, qr/\ACannot create temporary file/, "the cause is returned";
  is read_file($file), "old\n", "the original survives";
};

subtest "A failed write closes the temporary file" => sub {
  my $dir  = tempdir(CLEANUP => 1);
  my $temp = "$dir/probe-handle";
  write_file($temp, "");
  open my $ro, "<", $temp or die "Cannot reopen $temp: $!\n";

  no warnings qw( redefine once );
  local *Perl::Critic::PJCJ::AtomicWrite::tempfile = sub { ($ro, $temp) };
  local $SIG{__WARN__} = sub { };
  my $error = write_atomic("$dir/target", "content", 0644);

  like $error, qr/\ACannot write/, "the write fails";
  ok !defined fileno $ro, "the temporary handle is closed";
  ok !-e $temp,           "the temporary file is removed";
};

done_testing
