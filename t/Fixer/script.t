#!/usr/bin/env perl

use v5.26.0;
use strict;
use warnings;

use Test2::V0    qw( done_testing is isnt like ok skip_all subtest );
use feature      qw( signatures );
use experimental qw( signatures );

use File::Temp qw( tempdir tempfile );

use lib "t/lib";
use TestSupport qw(
  read_file
  run_capture
  skip_for_root
  skip_on_windows
  write_file
);

my $Script = "script/perl-quote-fix";

sub temp_source ($source, $mode = undef) {
  my ($fh, $file) = tempfile(UNLINK => 1);
  close $fh or die "Cannot close $file: $!";
  write_file($file, $source, $mode)
}

sub chmod_path ($mode, $path) {
  chmod $mode, $path or die "Cannot chmod $path: $!";
}

sub make_symlink ($target, $link) {
  symlink $target, $link or skip_all "cannot create symlinks";
}

sub run_files (@args) {
  open my $out, "-|", $^X, "-Ilib", $Script, @args
    or die "Cannot run $Script: $!";
  my $output = do { local $/ = undef; <$out> };
  close $out or $! == 0 or die "Cannot close pipe from $Script: $!";
  $output
}

sub run_script ($source, @args) {
  run_files(@args, temp_source($source))
}

sub run_inplace (@files) {
  run_capture($^X, "-Ilib", $Script, "--inplace", @files)
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
  my $file = temp_source("");
  my $out  = qx($^X -Ilib $Script --lines nonsense \Q$file\E 2>/dev/null);
  isnt $?, 0, "invalid --lines exits non-zero";
  $out = qx($^X -Ilib $Script --lines 9-1 \Q$file\E 2>/dev/null);
  isnt $?, 0, "reversed --lines exits non-zero";
};

subtest "Filter mode fails on unopenable input" => sub {
  my $missing = "/no/such/perl-quote-fix-input.pl";
  my $out     = qx($^X -Ilib $Script \Q$missing\E 2>&1);
  isnt $?, 0, "a missing input file exits non-zero";
  like $out, qr/\ACannot read [^\n]+\n\z/,
    "the cause is reported and nothing reaches stdout";
};

subtest "Every named file is processed in filter mode" => sub {
  my $one = temp_source(q(my $x = 'a';));
  my $two = temp_source(q(my $y = 'b';));
  is run_files($one, $two), 'my $x = "a";my $y = "b";',
    "both files appear fixed";
};

subtest "Empty input produces empty output" => sub {
  skip_on_windows "null-device redirection is POSIX-specific";
  my $out = qx($^X -Ilib $Script </dev/null 2>&1);
  is $out, "", "no output and no warnings";
  is $?,   0,  "the script succeeds";
};

subtest "Multiple files are fixed in place" => sub {
  skip_on_windows "shell quoting in the test helper is POSIX-specific";
  my $one   = temp_source(q(my $x = 'hello';));
  my $two   = temp_source(q(my $y = 'world';));
  my $clean = temp_source('my $n = 42;');
  my ($out, $exit) = run_inplace($one, $two, $clean);
  is $out,              "",                 "no output on success";
  is $exit,             0,                  "the script succeeds";
  is read_file($one),   'my $x = "hello";', "the first file is fixed";
  is read_file($two),   'my $y = "world";', "the second file is fixed";
  is read_file($clean), 'my $n = 42;',      "a clean file is unchanged";
};

subtest "File modes are preserved" => sub {
  skip_on_windows "file modes are not enforced on Windows";
  my $file = temp_source(q(my $x = 'hello';), 0755);
  my ($out, $exit) = run_inplace($file);
  is $exit,                      0,    "the script succeeds";
  is +((stat $file)[2] & 07777), 0755, "the mode is preserved";
};

subtest "An unreadable file fails but the others are still fixed" => sub {
  skip_all "file permissions are not enforced for root" if $> == 0;
  my $hidden = temp_source(q(my $x = 'hello';), 0000);
  my $good   = temp_source(q(my $y = 'world';));
  my ($out, $exit) = run_inplace($hidden, $good);
  like $out, qr/Cannot read/, "the cause is reported";
  is $exit,            1,                  "the script fails";
  is read_file($good), 'my $y = "world";', "the other file is still fixed";
};

subtest "A failed write leaves the original file intact" => sub {
  skip_on_windows "ulimit is POSIX-specific";
  my $dir    = tempdir(CLEANUP => 1);
  my $file   = "$dir/big.pl";
  my $source = join "", map qq(my \$x$_ = 'value $_';\n), 1 .. 200;
  write_file($file, $source);
  my $cmd = qq(ulimit -f 0; exec \Q$^X\E -Ilib \Q$Script\E )
    . qq(--inplace \Q$file\E >/dev/null 2>&1);
  system "sh", "-c", $cmd;
  isnt $?,             0,       "the script fails";
  is read_file($file), $source, "the original content survives";
};

subtest "An unwritable directory fails cleanly" => sub {
  skip_on_windows "directory permissions differ on Windows";
  skip_for_root "directory permissions are not enforced for root";
  my $dir  = tempdir(CLEANUP => 1);
  my $file = "$dir/a.pl";
  write_file($file, q(my $x = 'hello';));
  chmod_path(0555, $dir);
  my ($out, $exit) = run_inplace($file);
  chmod_path(0755, $dir);
  like $out, qr/Cannot create temporary file/, "the cause is reported";
  is $exit,            1,                   "the script fails";
  is read_file($file), q(my $x = 'hello';), "the original is untouched";
};

subtest "A symlink target is fixed and the link preserved" => sub {
  skip_on_windows "symlinks are not reliable on Windows";
  my $target = temp_source(q(my $x = 'hello';));
  my $dir    = tempdir(CLEANUP => 1);
  my $link   = "$dir/link.pl";
  make_symlink($target, $link);
  my ($out, $exit) = run_inplace($link);
  is $exit, 0, "the script succeeds";
  ok -l $link, "the symlink is still a symlink";
  is read_file($target), 'my $x = "hello";', "the target is fixed";
};

subtest "In-place mode rejects bad usage" => sub {
  my $file = temp_source("");
  my $out  = qx($^X -Ilib $Script --inplace --lines 1-2 \Q$file\E 2>&1);
  isnt $?, 0, "--inplace with --lines exits non-zero";
  $out = qx($^X -Ilib $Script --inplace 2>&1);
  isnt $?, 0, "--inplace without files exits non-zero";
};

done_testing
