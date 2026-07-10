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

sub fake_perltidy ($body) {
  my $dir = tempdir(CLEANUP => 1);
  write_file("$dir/perltidy", "#!/bin/sh\n$body\n", 0755);
  $dir
}

sub run_tidy ($path, @files) {
  local $ENV{PATH} = $path;
  my $files = join " ", map "\Q$_\E", @files;
  my $out   = qx($^X $Hook tidy $files 2>&1);
  ($out, $? >> 8)
}

my $Work = tempdir(CLEANUP => 1);
write_file("$Work/clean.pm", "my \$x = 1;\n");

subtest "A missing perltidy is reported as a failure" => sub {
  my ($out, $exit) = run_tidy(tempdir(CLEANUP => 1), "$Work/clean.pm");
  like $out,   qr/perltidy failed/, "the cause is reported";
  unlike $out, qr/Not tidy/,        "the file is not misreported as untidy";
  is $exit, 1, "the hook fails";
};

subtest "A crashing perltidy is reported as a failure" => sub {
  my ($out, $exit) = run_tidy(fake_perltidy("exit 3"), "$Work/clean.pm");
  like $out, qr/perltidy failed/, "the cause is reported";
  is $exit, 1, "the hook fails";
};

subtest "Tidy and untidy files are distinguished" => sub {
  my $pass = fake_perltidy('/bin/cat "$3"');
  my ($out, $exit) = run_tidy($pass, "$Work/clean.pm");
  is $out,  "", "a tidy file produces no output";
  is $exit, 0,  "a tidy file passes";

  ($out, $exit) = run_tidy(fake_perltidy("echo DIFFERENT"), "$Work/clean.pm");
  like $out, qr/Not tidy/, "an untidy file is reported";
  is $exit, 1, "an untidy file fails";
};

subtest "An unreadable file is reported, not skipped" => sub {
  write_file("$Work/hidden.pm", "my \$x = 1;\n", 0000);
  my ($out, $exit)
    = run_tidy(fake_perltidy('/bin/cat "$3"'), "$Work/hidden.pm");
  like $out, qr/Cannot read/, "the cause is reported";
  is $exit, 1, "the hook fails";
};

subtest "An unreadable candidate file aborts the run" => sub {
  write_file("$Work/mystery", "#!/usr/bin/env perl\n", 0000);
  my ($out, $exit)
    = run_tidy(fake_perltidy('/bin/cat "$3"'), "$Work/mystery");
  like $out, qr/Cannot read/, "the cause is reported";
  isnt $exit, 0, "the hook fails";
};

done_testing
