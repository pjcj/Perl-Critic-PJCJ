#!/usr/bin/env perl

use v5.26.0;
use strict;
use warnings;

use Test2::V0    qw( done_testing is like ok skip_all subtest unlike );
use feature      qw( signatures );
use experimental qw( signatures );

use Cwd            qw( abs_path getcwd );
use File::Basename qw( dirname );
use File::Temp     qw( tempdir );

use lib "utils/lib";
use GitHook qw( get_current_branch on_main ticket_re );

my $Ticket_re = ticket_re;

sub write_file ($path, $content) {
  open my $fh, ">", $path or die "Cannot write $path: $!\n";
  print {$fh} $content;
  close $fh or die "Cannot close $path: $!\n";
}

sub in_dir ($dir, $code) {
  delete local @ENV{qw( GIT_DIR GIT_WORK_TREE GIT_COMMON_DIR )};
  local $ENV{GIT_CEILING_DIRECTORIES} = dirname(abs_path($dir));
  my $cwd = getcwd;
  chdir $dir or die "Cannot chdir $dir: $!\n";
  my @result = $code->();
  chdir $cwd or die "Cannot chdir $cwd: $!\n";
  @result
}

sub in_temp_dir ($code) { in_dir(tempdir(CLEANUP => 1), $code) }

sub git_available () {
  open my $fh, "-|", "git", "--version" or return 0;
  my $out = do { local $/ = undef; <$fh> };
  close $fh or return 0;
  defined $out && $out =~ /git version/
}

sub skip_without_git () { skip_all "git not available" unless git_available() }

sub skip_unless ($ok, $why) { skip_all $why unless $ok }

sub run_git (@args) {
  local $ENV{GIT_CONFIG_GLOBAL} = "/dev/null";
  local $ENV{GIT_CONFIG_SYSTEM} = "/dev/null";
  system("git", @args) == 0
}

sub unborn_branch () {
  return 0
    unless run_git(qw( init -q ))
    && run_git(qw( symbolic-ref HEAD refs/heads/GH-1234-test ));
  (1, get_current_branch)
}

sub detached_head () {
  return 0
    unless run_git(qw( init -q ))
    && run_git(
      qw( -c user.email=t@t -c user.name=t commit -q --allow-empty -m Initial ))
    && run_git(qw( checkout -q --detach ));
  (1, get_current_branch, on_main)
}

subtest "Ticket regex" => sub {
  like "GH-1234",       qr/^$Ticket_re$/, "typical ticket matches";
  like "ABCDEFGH-1",    qr/^$Ticket_re$/, "eight-letter project matches";
  unlike "A-1",         qr/^$Ticket_re$/, "one letter is not a project";
  unlike "ABCDEFGHI-1", qr/^$Ticket_re$/, "nine letters is too long";
  unlike "gh-123",      qr/^$Ticket_re$/, "lower case does not match";
};

subtest "Branch detection outside a repository" => sub {
  my ($branch, $main) = in_temp_dir(sub { (get_current_branch, on_main) });
  is $branch, "", "no branch outside a repository";
  ok !$main, "not on main";
};

subtest "Branch detection on an unborn branch" => sub {
  skip_without_git();
  my ($ok, $branch) = in_temp_dir(\&unborn_branch);
  skip_unless($ok, "could not prepare an unborn repository");
  is $branch, "GH-1234-test", "an unborn branch reports its name";
};

subtest "Branch detection on a detached HEAD" => sub {
  skip_without_git();
  my ($ok, $branch, $main) = in_temp_dir(\&detached_head);
  skip_unless($ok, "could not prepare a detached repository");
  is $branch, "", "a detached HEAD reports no branch";
  ok !$main, "not on main";
};

subtest "A symlinked hook finds the shared library" => sub {
  skip_all "the hook runs only under a POSIX shell" if $^O eq "MSWin32";
  my $dir  = tempdir(CLEANUP => 1);
  my $link = "$dir/commit-msg";
  symlink abs_path("utils/commit-msg-hook"), $link
    or skip_all "symlinks not available";
  my $msg = "$dir/msg.txt";
  write_file($msg, "Improve the widget\n\nTicket GH-1234\n");
  delete local @ENV{qw( GIT_DIR GIT_WORK_TREE GIT_COMMON_DIR )};
  local $ENV{GIT_CEILING_DIRECTORIES} = dirname(abs_path($dir));
  my $out = qx(cd \Q$dir\E && \Q$link\E \Q$msg\E </dev/null 2>&1);
  is $? >> 8, 0,  "the hook runs and accepts a clean message";
  is $out,    "", "no output";
};

sub repo_with_subdir () {
  my $dir = tempdir(CLEANUP => 1);
  run_git("init", "-q", $dir);
  my $work = "$dir/work";
  mkdir $work or die "Cannot mkdir $work: $!\n";
  $work
}

subtest "A repository above the temp directory is ignored" => sub {
  my ($branch, $main)
    = in_dir(repo_with_subdir(), sub { (get_current_branch, on_main) });
  is $branch, "", "an enclosing repository does not leak in";
  ok !$main, "not on main";
};

done_testing
