#!/usr/bin/env perl

use v5.26.0;
use strict;
use warnings;

use Test2::V0    qw( done_testing is skip_all subtest unlike );
use feature      qw( signatures );
use experimental qw( signatures );

use Cwd            qw( abs_path );
use File::Basename qw( dirname );
use File::Temp     qw( tempdir );

skip_all "the prepare-commit-msg hook needs a POSIX shell" if $^O eq "MSWin32";

my $Hook = abs_path("utils/prepare-commit-msg-hook");
my $Work = tempdir(CLEANUP => 1);
my $N    = 0;

sub run_hook ($bytes, $dir, @args) {
  $N++;
  my $msg = "$Work/msg$N.txt";
  open my $fh, ">:raw", $msg or die "Cannot write $msg: $!\n";
  print {$fh} $bytes;
  close $fh or die "Cannot close $msg: $!\n";

  delete local @ENV{qw( GIT_DIR GIT_WORK_TREE GIT_COMMON_DIR )};
  local $ENV{GIT_CEILING_DIRECTORIES} = dirname(abs_path($Work));
  my $args = join " ", map "\Q$_\E", $msg, @args;
  my $out  = qx(cd \Q$dir\E && $^X \Q$Hook\E $args 2>&1);
  my $exit = $? >> 8;

  open my $rd, "<:raw", $msg or die "Cannot read $msg: $!\n";
  my $content = do { local $/; <$rd> }
    // "";
  close $rd or die "Cannot close $msg: $!\n";
  ($content, $out, $exit)
}

sub git_available () {
  open my $fh, "-|", "git", "--version" or return 0;
  my $out = do { local $/ = undef; <$fh> };
  close $fh or return 0;
  defined $out && $out =~ /git version/
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

my $Ticket_repo
  = init_repo("ticket", [qw( symbolic-ref HEAD refs/heads/GH-1234-test )]);

subtest "A message with invalid UTF-8 passes through" => sub {
  skip_without($Ticket_repo);
  my ($content, $out, $exit)
    = run_hook("Widget\xE9 tweak\n", $Ticket_repo, "message");
  is $exit, 0, "the hook succeeds";
  is $content, "Widget\xE9 tweak\n\nTicket GH-1234\n",
    "the invalid byte survives and the ticket line is appended";
};

subtest "Valid multibyte UTF-8 content is preserved byte for byte" => sub {
  skip_without($Ticket_repo);
  my ($content, $out, $exit)
    = run_hook("Widget\xC3\xA9 tweak\n", $Ticket_repo, "message");
  is $exit, 0, "the hook succeeds";
  is $content, "Widget\xC3\xA9 tweak\n\nTicket GH-1234\n",
    "the UTF-8 bytes are unchanged";
};

subtest "Outside a repository the message is untouched" => sub {
  my ($content, $out, $exit)
    = run_hook("Improve the widget\n", $Work, "message");
  is $exit,    0,                      "the hook succeeds";
  is $content, "Improve the widget\n", "no placeholder is inserted";
};

subtest "A detached HEAD leaves replayed messages alone" => sub {
  my $repo = init_repo(
    "detached", [
      qw( -c user.email=t@t -c user.name=t commit -q --allow-empty -m Initial )
    ],
    [qw( checkout -q --detach )],
  );
  skip_without($repo);
  my ($content, $out, $exit)
    = run_hook("Improve the widget\n", $repo, "message");
  is $exit,    0,                      "the hook succeeds";
  is $content, "Improve the widget\n", "the message is untouched";
};

subtest "An unborn main gets no placeholder" => sub {
  my $repo = init_repo("unborn", [qw( symbolic-ref HEAD refs/heads/main )]);
  skip_without($repo);
  my ($content, $out, $exit) = run_hook("Improve the widget\n", $repo, "");
  is $exit, 0, "the hook succeeds";
  unlike $content, qr/Ticket GH-XXXXX/, "no placeholder ticket is appended";
};

done_testing
