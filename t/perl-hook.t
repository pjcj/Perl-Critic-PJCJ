#!/usr/bin/env perl

use v5.26.0;
use strict;
use warnings;

use Test2::V0    qw( done_testing is isnt like skip_all subtest unlike );
use feature      qw( signatures );
use experimental qw( signatures );

use File::Temp qw( tempdir );

skip_all "file permissions are not enforced for root" if $> == 0;

my $Hook = "utils/perl-hook";

sub write_file ($path, $content, $mode = 0644) {
  open my $fh, ">", $path or die "Cannot write $path: $!\n";
  print {$fh} $content;
  close $fh or die "Cannot close $path: $!\n";
  chmod $mode, $path or die "Cannot chmod $path: $!\n";
}

sub run_tidy (@files) {
  my $files = join " ", map "\Q$_\E", @files;
  my $out   = qx($^X $Hook tidy $files 2>&1);
  ($out, $? >> 8)
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
  my $files = join " ", map "\Q$_\E", "$Work/clean.pm", "$Work/app.psgi",
    "$Work/tool", "$Work/shelly", "$Work/notes.txt";
  my $out = qx($^X $Hook list $files 2>&1);
  is $? >> 8, 0, "the hook succeeds";
  is $out, "$Work/clean.pm\n$Work/app.psgi\n$Work/tool\n",
    "only the Perl files are listed, in order";
};

subtest "An unreadable file is reported, not skipped" => sub {
  write_file("$Work/hidden.pm", "my \$x = 1;\n", 0000);
  my ($out, $exit) = run_tidy("$Work/hidden.pm");
  like $out, qr/Cannot read/, "the cause is reported";
  is $exit, 1, "the hook fails";
};

subtest "An unreadable candidate file aborts the run" => sub {
  write_file("$Work/mystery", "#!/usr/bin/env perl\n", 0000);
  my ($out, $exit) = run_tidy("$Work/mystery");
  like $out, qr/Cannot read/, "the cause is reported";
  isnt $exit, 0, "the hook fails";
};

done_testing
