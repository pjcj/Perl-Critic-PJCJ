#!/usr/bin/env perl

use v5.26.0;
use strict;
use warnings;

use Test2::V0    qw( done_testing is isnt skip_all subtest );
use feature      qw( signatures );
use experimental qw( signatures );

use File::Temp qw( tempdir );

my $Fmt  = "utils/fmt-commit-msg";
my $Work = tempdir(CLEANUP => 1);

sub write_file ($path, $content) {
  open my $fh, ">", $path or die "Cannot write $path: $!\n";
  print {$fh} $content;
  close $fh or die "Cannot close $path: $!\n";
}

sub read_file ($path) {
  open my $fh, "<", $path or die "Cannot read $path: $!\n";
  local $/;
  <$fh>
}

sub skip_on_windows ($why) { skip_all $why if $^O eq "MSWin32" }

my $Body = "Improve the widget\n\nA body which is short enough to survive"
  . " a reflow unchanged.\n";

subtest "A message is reflowed in place" => sub {
  write_file("$Work/plain.txt", "Improve the widget\n\nOne\nline.\n");
  system $^X, $Fmt, "$Work/plain.txt";
  is $? >> 8, 0, "the hook succeeds";
  is read_file("$Work/plain.txt"), "Improve the widget\n\nOne line.\n",
    "the body is reflowed";
};

subtest "A failed write leaves the message intact" => sub {
  skip_on_windows "ulimit is POSIX-specific";
  write_file("$Work/atomic.txt", $Body);
  my $cmd = qq(ulimit -f 0; exec \Q$^X\E \Q$Fmt\E )
    . qq(\Q$Work/atomic.txt\E >/dev/null 2>&1);
  system "sh", "-c", $cmd;
  isnt $?,                          0,     "the hook fails";
  is read_file("$Work/atomic.txt"), $Body, "the message survives";
};

subtest "An indented block survives" => sub {
  my $msg = "Improve the widget\n\nHere is the code:\n\n"
    . "    my \$x = frob(1);\n    my \$y = frob(2);\n";
  write_file("$Work/indented.txt", $msg);
  system $^X, $Fmt, "$Work/indented.txt";
  is read_file("$Work/indented.txt"), $msg, "the example is not joined";
};

subtest "A fenced block survives" => sub {
  my $msg = "Improve the widget\n\nLike this:\n\n"
    . "```perl\nmy \$a = 1;\nmy \$b = 2;\n```\n";
  write_file("$Work/fenced.txt", $msg);
  system $^X, $Fmt, "$Work/fenced.txt";
  is read_file("$Work/fenced.txt"), $msg, "the fence and body are not joined";
};

subtest "An indented block under prose is not folded into it" => sub {
  my $msg = "Improve the widget\n\nThe fix is this:\n"
    . "    my \$x = 1;\n    my \$y = 2;\n";
  write_file("$Work/mixed.txt", $msg);
  system $^X, $Fmt, "$Work/mixed.txt";
  is read_file("$Work/mixed.txt"), $msg, "the prose keeps its own line";
};

subtest "Bullet items still reflow" => sub {
  write_file("$Work/bullet.txt",
        "Improve the widget\n\n"
      . "- a bullet item that is quite long and should be wrapped somewhere"
      . " around here\n  with a continuation\n");
  system $^X, $Fmt, "$Work/bullet.txt";
  is read_file("$Work/bullet.txt"),
      "Improve the widget\n\n"
    . "- a bullet item that is quite long and should be wrapped somewhere\n"
    . "  around here with a continuation\n",
    "a long list item wraps at 72 columns with a hanging indent";
};

done_testing
