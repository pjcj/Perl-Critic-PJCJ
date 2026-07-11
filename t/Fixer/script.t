#!/usr/bin/env perl

use v5.26.0;
use strict;
use warnings;

use Test2::V0    qw( done_testing is isnt like skip_all subtest );
use feature      qw( signatures );
use experimental qw( signatures );

use File::Temp qw( tempfile );

my $Script = "script/perl-quote-fix";

sub write_file ($source, $mode = undef) {
  my ($fh, $file) = tempfile(UNLINK => 1);
  print {$fh} $source;
  close $fh or die "Cannot close $file: $!";
  chmod $mode, $file or die "Cannot chmod $file: $!" if defined $mode;
  $file
}

sub read_file ($file) {
  open my $fh, "<", $file or die "Cannot read $file: $!";
  local $/ = undef;
  <$fh>
}

sub run_script ($source, @args) {
  my $file = write_file($source);
  open my $out, "-|", $^X, "-Ilib", $Script, @args, $file
    or die "Cannot run $Script: $!";
  my $output = do { local $/ = undef; <$out> };
  close $out or $! == 0 or die "Cannot close pipe from $Script: $!";
  $output
}

sub run_inplace (@files) {
  my $files = join " ", map "\Q$_\E", @files;
  my $out   = qx($^X -Ilib $Script --inplace $files 2>&1);
  ($out, $? >> 8)
}

sub skip_on_windows ($reason) {
  skip_all $reason if $^O eq "MSWin32";
}

subtest "Source is fixed from stdin to stdout" => sub {
  is run_script(q(my $x = 'hello';)), 'my $x = "hello";', "quoting is fixed";
  is run_script('my $n = 42;'), 'my $n = 42;', "clean source passes through";
};

subtest "Line ranges are honoured" => sub {
  my $in = qq(my \$a = 'one';\nmy \$b = 'two';\n);
  is run_script($in, "--lines", "2-2"),
    qq(my \$a = 'one';\nmy \$b = "two";\n),
    "only the requested lines are fixed";
};

subtest "Bad arguments fail" => sub {
  run_script("", "--lines", "nonsense");
  isnt $?, 0, "invalid --lines exits non-zero";
  run_script("", "--lines", "9-1");
  isnt $?, 0, "reversed --lines exits non-zero";
};

subtest "Multiple files are fixed in place" => sub {
  skip_on_windows "shell quoting in the test helper is POSIX-specific";
  my $one   = write_file(q(my $x = 'hello';));
  my $two   = write_file(q(my $y = 'world';));
  my $clean = write_file('my $n = 42;');
  my ($out, $exit) = run_inplace($one, $two, $clean);
  is $out,              "",                 "no output on success";
  is $exit,             0,                  "the script succeeds";
  is read_file($one),   'my $x = "hello";', "the first file is fixed";
  is read_file($two),   'my $y = "world";', "the second file is fixed";
  is read_file($clean), 'my $n = 42;',      "a clean file is unchanged";
};

subtest "File modes are preserved" => sub {
  skip_on_windows "file modes are not enforced on Windows";
  my $file = write_file(q(my $x = 'hello';), 0755);
  my ($out, $exit) = run_inplace($file);
  is $exit,                      0,    "the script succeeds";
  is +((stat $file)[2] & 07777), 0755, "the mode is preserved";
};

subtest "An unreadable file fails but the others are still fixed" => sub {
  skip_all "file permissions are not enforced for root" if $> == 0;
  my $hidden = write_file(q(my $x = 'hello';), 0000);
  my $good   = write_file(q(my $y = 'world';));
  my ($out, $exit) = run_inplace($hidden, $good);
  like $out, qr/Cannot read/, "the cause is reported";
  is $exit,            1,                  "the script fails";
  is read_file($good), 'my $y = "world";', "the other file is still fixed";
};

subtest "In-place mode rejects bad usage" => sub {
  my $file = write_file("");
  my $out  = qx($^X -Ilib $Script --inplace --lines 1-2 \Q$file\E 2>&1);
  isnt $?, 0, "--inplace with --lines exits non-zero";
  $out = qx($^X -Ilib $Script --inplace 2>&1);
  isnt $?, 0, "--inplace without files exits non-zero";
};

done_testing
