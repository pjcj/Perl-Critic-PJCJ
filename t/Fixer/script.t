#!/usr/bin/env perl

use v5.26.0;
use strict;
use warnings;

use Test2::V0    qw( done_testing is isnt subtest );
use feature      qw( signatures );
use experimental qw( signatures );

use File::Temp qw( tempfile );

my $Script = "script/perl-quote-fix";

sub run_script ($source, @args) {
  my ($fh, $file) = tempfile(UNLINK => 1);
  print {$fh} $source;
  close $fh or die "Cannot close $file: $!";
  my $args = join " ", @args;
  qx($^X -Ilib $Script $args < $file)
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

done_testing
