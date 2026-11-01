#!/usr/bin/env perl

use v5.26.0;
use strict;
use warnings;

use Test2::V0    qw( diag done_testing is skip_all subtest );
use feature      qw( signatures );
use experimental qw( signatures );

use Cwd        qw( abs_path );
use File::Temp qw( tempdir );

use lib         qw( t/lib );
use TestSupport qw( git_available read_file skip_on_windows write_file );

sub bash_major () {
  (qx(bash -c 'echo \${BASH_VERSINFO[0]}' 2>/dev/null) =~ /(\d+)/)[0] // 0
}

sub git_is_recent () {
  my ($major, $minor) = qx(git --version) =~ /(\d+)\.(\d+)/;
  $major > 2 || ($major == 2 && $minor >= 32)
}

sub skip_unsupported () {
  skip_on_windows "utils/run needs a POSIX shell";
  skip_all "git not available"                unless git_available();
  skip_all "utils/run needs bash 5 or later"  unless bash_major() >= 5;
  skip_all "the test needs git 2.32 or later" unless git_is_recent();
}

skip_unsupported();

my $Run = abs_path("utils/run");

my $Stub = <<~'BASH';
  #!/usr/bin/env bash
  if [[ -n "$(git config core.hooksPath || true)" ]]; then
    echo "Cowardly refusing to install hooks with core.hooksPath set"
    exit 1
  fi
  printf "%s\n" "$@" >"$STUB_LOG"
  BASH

sub run_setup ($global_config) {
  my $dir = tempdir(CLEANUP => 1);
  delete local $ENV{GIT_TEMPLATE_DIR};
  local $ENV{GIT_CONFIG_GLOBAL} = "$dir/gitconfig";
  local $ENV{GIT_CONFIG_SYSTEM} = "/dev/null";
  system("git", "init", "-q", $dir) == 0 or die "Cannot init $dir\n";
  mkdir "$dir/bin"                       or die "Cannot mkdir $dir/bin: $!\n";
  write_file("$dir/bin/pre-commit", $Stub, 0755);
  write_file("$dir/gitconfig", $global_config);

  delete local @ENV{qw( GIT_DIR GIT_WORK_TREE GIT_COMMON_DIR )};
  local $ENV{XDG_STATE_HOME} = "$dir/state";
  local $ENV{STUB_LOG}       = "$dir/stub.log";
  local $ENV{PATH}           = "$dir/bin:$ENV{PATH}";

  my $out  = qx(cd \Q$dir\E && \Q$Run\E setup </dev/null 2>&1);
  my $exit = $? >> 8;
  my $log  = -e "$dir/stub.log" ? read_file("$dir/stub.log") : "";

  ($out, $exit, $log)
}

sub setup_installs_hooks ($global_config) {
  my ($out, $exit, $log) = run_setup($global_config);
  is $exit, 0,                            "setup succeeds" or diag $out;
  is $log,  "install\n--install-hooks\n", "pre-commit installs the hooks";
}

subtest "Install hooks while core.hooksPath is set" => sub {
  setup_installs_hooks("[core]\n  hooksPath = /nonexistent/chain\n");
};

subtest "Install hooks without core.hooksPath" => sub {
  setup_installs_hooks("");
};

subtest "Install hooks with an empty template directory" => sub {
  local $ENV{GIT_TEMPLATE_DIR} = tempdir(CLEANUP => 1);
  setup_installs_hooks("");
};

done_testing
