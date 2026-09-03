#!/usr/bin/env perl

use v5.26.0;
use strict;
use warnings;

use Test2::V0    qw( done_testing is like skip_all subtest unlike );
use feature      qw( signatures );
use experimental qw( signatures );

use Cwd            qw( abs_path );
use File::Basename qw( dirname );
use File::Temp     qw( tempdir );

use lib "t/lib";
use TestSupport qw( git_available read_file write_file );

skip_all "the commit-msg hook needs POSIX process control" if $^O eq "MSWin32";

use POSIX qw( setsid );

my $Hook = abs_path("utils/commit-msg-hook");
my $Work = tempdir(CLEANUP => 1);
my $N    = 0;

sub run_hook ($bytes, $dir = $Work) {
  $N++;
  my $msg = "$Work/msg$N.txt";
  my $out = "$Work/out$N.txt";
  write_file($msg, $bytes);

  my $pid = fork // die "Cannot fork: $!\n";
  unless ($pid) {
    delete @ENV{qw( GIT_DIR GIT_WORK_TREE GIT_COMMON_DIR )};
    $ENV{GIT_CEILING_DIRECTORIES} = dirname(abs_path($Work));
    setsid() != -1 or die "Cannot setsid: $!\n";
    chdir $dir     or die "Cannot chdir $dir: $!\n";
    open STDIN,  "<",  "/dev/null" or die "Cannot open /dev/null: $!\n";
    open STDOUT, ">",  $out        or die "Cannot open $out: $!\n";
    open STDERR, ">&", \*STDOUT    or die "Cannot dup stdout: $!\n";
    exec $^X, $Hook, $msg or die "Cannot exec $Hook: $!\n";
  }
  waitpid $pid, 0;
  my $exit = $? >> 8;
  (read_file($out), $exit)
}

sub init_repo ($name, @setup) {
  return unless git_available();
  local $ENV{GIT_CONFIG_GLOBAL} = "/dev/null";
  local $ENV{GIT_CONFIG_SYSTEM} = "/dev/null";
  my $dir = "$Work/$name";
  return unless system("git", "init", "-q", $dir) == 0;
  for my $step (@setup) {
    return unless system("git", "-C", $dir, @$step) == 0;
  }
  $dir
}

sub skip_without ($repo) { skip_all "git not available" unless $repo }

subtest "Without a terminal the hook declines cleanly" => sub {
  my ($out, $exit) = run_hook("bad subject line\n\nTicket GH-1234\n");
  like $out,   qr/Errors found:/,  "the error report is printed";
  unlike $out, qr/Can't open tty/, "the hook does not die";
  unlike $out, qr/Force commit\?/, "no unanswerable prompt is printed";
  is $exit, 1, "the commit is rejected";
};

subtest "A clean message needs no terminal" => sub {
  my ($out, $exit) = run_hook("Improve the widget\n\nTicket GH-1234\n");
  is $out,  "", "no output";
  is $exit, 0,  "the commit is accepted";
};

subtest "An empty message is reported without printf warnings" => sub {
  my ($out, $exit) = run_hook("");
  like $out,   qr/Empty commit message/, "the empty message is reported";
  unlike $out, qr/Missing argument/,     "printf receives both values";
  is $exit, 1, "the commit is rejected";
};

subtest "A message with invalid UTF-8 is reported, not fatal" => sub {
  my ($out, $exit)
    = run_hook("Improve the widget\xE9 handling\n\nTicket GH-1234\n");
  like $out,   qr/not valid UTF-8/,         "the encoding is reported";
  unlike $out, qr/does not map to Unicode/, "the hook does not die";
  is $exit, 1, "the commit is rejected";
};

subtest "A valid UTF-8 message with multibyte characters passes" => sub {
  my ($out, $exit)
    = run_hook("Improve the widget\xC3\xA9 handling\n\nTicket GH-1234\n");
  is $out,  "", "no output";
  is $exit, 0,  "the commit is accepted";
};

subtest "Subject length is counted in characters, not bytes" => sub {
  my $subject = "Improve " . "\xC3\xA9" x 42;  # 50 characters, 92 bytes
  my ($out, $exit) = run_hook("$subject\n\nTicket GH-1234\n");
  is $exit, 0, "a 50-character multibyte subject is accepted";
};

subtest "A detached HEAD does not demand a ticket" => sub {
  my $repo = init_repo(
    "detached", [
      qw( -c user.email=t@t -c user.name=t commit -q --allow-empty -m Initial )
    ],
    [qw( checkout -q --detach )],
  );
  skip_without($repo);
  my ($out, $exit) = run_hook("Improve the widget\n", $repo);
  is $out,  "", "no error report";
  is $exit, 0,  "the reworded message is accepted";
};

subtest "A ticket branch still demands a ticket" => sub {
  my $repo
    = init_repo("ticket", [qw( symbolic-ref HEAD refs/heads/GH-1234-test )]);
  skip_without($repo);
  my ($out, $exit) = run_hook("Improve the widget\n", $repo);
  like $out, qr/Line 3 does not reference ticket id/,
    "the ticket is asked for";
  is $exit, 1, "the commit is rejected";
};

subtest "Body line numbers count the comment lines" => sub {
  my $long = "x" x 98;
  my ($out, $exit)
    = run_hook("Improve the widget\n\nTicket GH-1234\n# a comment\n$long\n");
  like $out, qr/Line 5 is longer than 72 characters/,
    "the reported number matches the file";
  is $exit, 1, "the commit is rejected";
};

subtest "A subject may start with a digit or an underscore" => sub {
  my ($out, $exit)
    = run_hook("2x speedup for the parser\n\nTicket GH-1234\n");
  is $out,  "", "a digit start is accepted";
  is $exit, 0,  "the commit is accepted";

  ($out, $exit) = run_hook("_internal rework\n\nTicket GH-1234\n");
  is $out,  "", "an underscore start is accepted";
  is $exit, 0,  "the commit is accepted";
};

subtest "A lower case subject is still rejected" => sub {
  my ($out, $exit) = run_hook("improve the widget\n\nTicket GH-1234\n");
  like $out, qr/does not start with a capital letter/,
    "the lower case start is reported";
  is $exit, 1, "the commit is rejected";
};

done_testing
