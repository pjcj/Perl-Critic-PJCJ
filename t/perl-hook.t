#!/usr/bin/env perl

use v5.26.0;
use strict;
use warnings;

use Test2::V0    qw( done_testing is isnt like ok skip_all subtest unlike );
use feature      qw( signatures );
use experimental qw( signatures );

use Cwd        qw( abs_path );
use File::Path qw( make_path );
use File::Temp qw( tempdir );
use IPC::Cmd   qw( can_run );

use lib "t/lib";
use TestSupport qw( read_file run_capture write_file );

skip_all "file permissions are not enforced for root" if $> == 0;

my $Hook     = "utils/perl-hook";
my $Hook_abs = abs_path($Hook);

sub run_tidy   (@files) { run_capture($^X, $Hook, "tidy",   @files) }
sub run_format (@files) { run_capture($^X, $Hook, "format", @files) }

sub link_or_skip ($target, $link) {
  skip_all "symlinks are not supported here"
    unless eval { symlink $target, $link };
}

sub fix_dir () {
  my $dir = tempdir(CLEANUP => 1);
  write_file("$dir/.perltidyrc", read_file(".perltidyrc"));
  $dir
}

sub run_fix ($dir, @files) {
  my $files = join " ", map "\Q$_\E", @files;
  my $out   = qx(cd \Q$dir\E && $^X \Q$Hook_abs\E fix $files 2>&1);
  ($out, $? >> 8)
}

sub read_backup ($dir, $file) {
  my $backup = "$dir/tmp/perltidy/$file";
  -f $backup ? read_file($backup) : undef
}

sub perlimports_or_skip () {
  skip_all "perlimports is not installed" unless can_run("perlimports");
}

my $Work = tempdir(CLEANUP => 1);
write_file("$Work/clean.pm", "my \$x = 1;\n");

subtest "A file perltidy cannot process is reported as a failure" => sub {
  write_file("$Work/broken.pm", "}\n");
  my ($out, $exit) = run_tidy("$Work/broken.pm");
  like $out,   qr/perltidy failed/, "the cause is reported";
  unlike $out, qr/Not tidy/,        "the file is not misreported as untidy";
  is $exit, 1, "the hook fails";
};

subtest "Tidy and untidy files are distinguished" => sub {
  my ($out, $exit) = run_tidy("$Work/clean.pm");
  is $out,  "", "a tidy file produces no output";
  is $exit, 0,  "a tidy file passes";

  write_file("$Work/untidy.pm", "my  \$x=1;\n");
  ($out, $exit) = run_tidy("$Work/untidy.pm");
  like $out, qr/Not tidy/, "an untidy file is reported";
  is $exit, 1, "an untidy file fails";
};

subtest "Every file is checked, not just the first failure" => sub {
  write_file("$Work/messy.pm", "my  \$y=2;\n");
  my ($out, $exit) = run_tidy("$Work/untidy.pm", "$Work/messy.pm");
  like $out, qr/Not tidy: \Q$Work\E\/untidy\.pm/, "the first is reported";
  like $out, qr/Not tidy: \Q$Work\E\/messy\.pm/,  "the second is reported";
  is $exit, 1, "the hook fails";
};

subtest "No perltidy process is spawned" => sub {
  local $ENV{PATH} = tempdir(CLEANUP => 1);
  my ($out, $exit) = run_tidy("$Work/clean.pm");
  is $out,  "", "a tidy file passes without a perltidy binary";
  is $exit, 0,  "the hook succeeds";
};

subtest "List mode prints only the Perl files" => sub {
  write_file("$Work/app.psgi",  "my \$app = sub { };\n");
  write_file("$Work/tool",      "#!/usr/bin/env perl\nsay 1;\n");
  write_file("$Work/shelly",    "#!/bin/sh\necho hi\n");
  write_file("$Work/notes.txt", "hello\n");
  my ($out, $exit) = run_capture(
    $^X,              $Hook,
    "list",           "$Work/clean.pm",
    "$Work/app.psgi", "$Work/tool",
    "$Work/shelly",   "$Work/notes.txt",
  );
  is $exit, 0, "the hook succeeds";
  is $out, "$Work/clean.pm\n$Work/app.psgi\n$Work/tool\n",
    "only the Perl files are listed, in order";
};

subtest "An unreadable file is reported, not skipped" => sub {
  write_file("$Work/hidden.pm", "my \$x = 1;\n", 0000);
  my ($out, $exit) = run_tidy("$Work/hidden.pm");
  like $out, qr/Cannot read/, "the cause is reported";
  is $exit, 1, "the hook fails";
};

subtest "An unreadable candidate is reported, the rest still checked" => sub {
  write_file("$Work/mystery", "#!/usr/bin/env perl\n", 0000);
  write_file("$Work/scruffy.pm", "my  \$z=3;\n");
  my ($out, $exit) = run_tidy("$Work/mystery", "$Work/scruffy.pm");
  like $out, qr/Cannot read \Q$Work\E\/mystery/, "the cause is reported";
  like $out, qr/Not tidy: \Q$Work\E\/scruffy\.pm/,
    "the other file is still checked";
  is $exit, 1, "the hook fails";
};

subtest "List mode keeps its output clean of warnings" => sub {
  write_file("$Work/veiled", "#!/usr/bin/env perl\n", 0000);
  my $files = join " ", map "\Q$_\E", "$Work/veiled", "$Work/clean.pm";
  my $list  = qx($^X $Hook list $files 2>/dev/null);
  is $? >> 8, 1,                  "the hook fails";
  is $list,   "$Work/clean.pm\n", "only readable Perl files are listed";
  my $all = qx($^X $Hook list $files 2>&1);
  like $all, qr/Cannot read/, "the unreadable candidate is reported";
};

subtest "Format mode rewrites an untidy file in place" => sub {
  write_file("$Work/reformat.pm", "my  \$x=1;\n");
  my ($out, $exit) = run_format("$Work/reformat.pm");
  is $exit,                          0,               "the hook succeeds";
  is read_file("$Work/reformat.pm"), "my \$x = 1;\n", "the file is tidied";
};

subtest "Format mode reports an unreadable candidate" => sub {
  write_file("$Work/obscure", "#!/usr/bin/env perl\n", 0000);
  write_file("$Work/plain.pm", "my \$x = 1;\n");
  my ($out, $exit) = run_format("$Work/obscure", "$Work/plain.pm");
  like $out, qr/Cannot read \Q$Work\E\/obscure/, "the cause is reported";
  is $exit, 1, "the hook fails";
};

subtest "Format mode leaves the original intact on a failed write" => sub {
  skip_all "ulimit is POSIX-specific" if $^O eq "MSWin32";
  write_file("$Work/atomic.pm", "my  \$x=1;\n");
  my $cmd = qq(ulimit -f 0; exec \Q$^X\E \Q$Hook\E format )
    . qq(\Q$Work/atomic.pm\E >/dev/null 2>&1);
  system "sh", "-c", $cmd;
  isnt $?, 0, "the hook fails";
  is read_file("$Work/atomic.pm"), "my  \$x=1;\n",
    "the original content survives";
};

subtest "Format mode rewrites the target of a symlink" => sub {
  write_file("$Work/linked.pm", "my  \$x=1;\n");
  link_or_skip("linked.pm", "$Work/alias.pm");
  my ($out, $exit) = run_format("$Work/alias.pm");
  is $exit, 0, "the hook succeeds";
  ok -l "$Work/alias.pm", "the symlink survives";
  is read_file("$Work/linked.pm"), "my \$x = 1;\n", "the target is tidied";
};

subtest "Fix mode keeps backups of files sharing a basename" => sub {
  my $dir = fix_dir();
  make_path("$dir/a", "$dir/b");
  write_file("$dir/a/basic.t", "my  \$a=1;\n");
  write_file("$dir/b/basic.t", "my  \$b=2;\n");
  run_fix($dir, "a/basic.t", "b/basic.t");
  is read_backup($dir, "a/basic.t"), "my  \$a=1;\n",
    "the first backup holds its original";
  is read_backup($dir, "b/basic.t"), "my  \$b=2;\n",
    "the second backup holds its original";
};

subtest "Fix mode leaves no backup beside the sources on failure" => sub {
  my $dir = fix_dir();
  write_file("$dir/secret", "#!/usr/bin/env perl\n", 0000);
  write_file("$dir/rough.pm", "my  \$x=1;\n");
  my ($out, $exit) = run_fix($dir, "secret", "rough.pm");
  like $out, qr/Cannot read secret/, "the cause is reported";
  is $exit,                         1,  "the hook fails";
  is [glob "$dir/*.tdybak"],        [], "no backup is left beside the sources";
  is read_backup($dir, "rough.pm"), "my  \$x=1;\n", "the backup is under tmp";
};

subtest "Fix mode reports a missing perlimports and still tidies" => sub {
  local $ENV{PATH} = tempdir(CLEANUP => 1);
  my $dir = fix_dir();
  write_file("$dir/lonely.pm", "my  \$x=1;\n");
  my ($out, $exit) = run_fix($dir, "lonely.pm");
  like $out, qr/perlimports/, "the missing tool is reported";
  isnt $exit,                     0,               "the hook fails";
  is read_file("$dir/lonely.pm"), "my \$x = 1;\n", "the file is still tidied";
};

subtest "Fix mode formats a file and reports it once" => sub {
  perlimports_or_skip();
  my $dir = fix_dir();
  write_file("$dir/first.pm", "my  \$x=1;\n");
  my ($out, $exit) = run_fix($dir, "first.pm");
  is $exit, 0,                      "the hook succeeds";
  is $out,  "Formatted first.pm\n", "the changed file is reported";
  is read_file("$dir/first.pm"), "my \$x = 1;\n", "the file is tidied";
  is read_backup($dir, "first.pm"), "my  \$x=1;\n",
    "the backup holds the original";
  ($out, $exit) = run_fix($dir, "first.pm");
  is $exit, 0,  "a second run succeeds";
  is $out,  "", "a second run reports nothing";
};

done_testing
