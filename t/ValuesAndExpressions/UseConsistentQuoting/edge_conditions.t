#!/usr/bin/env perl

use v5.20.0;
use strict;
use warnings;
use feature "signatures";

use Test2::V0;

no warnings "experimental::signatures";

# Test edge conditions to improve coverage
use lib qw( lib t/lib );
use Perl::Critic::Policy::ValuesAndExpressions::UseConsistentQuoting;
use ViolationFinder
  qw(find_violations count_violations good bad check_violation_message);

my $Policy
  = Perl::Critic::Policy::ValuesAndExpressions::UseConsistentQuoting->new;

# Helper subs that use the common policy
sub good_code ($code, $description) {
  ViolationFinder::good($Policy, $code, $description);
}

sub bad_code ($code, $description) {
  count_violations($Policy, $code, 1, $description);
}

sub check_message ($code, $expected_message, $description) {
  check_violation_message($Policy, $code, $expected_message, $description);
}

subtest "Condition coverage tests" => sub {
  # Test to hit the uncovered condition in single quote checking (line 229)
  # This should exercise: not $would_interpolate and index($string, "\"") == -1
  bad_code q{my $x = 'simple';},
    "simple single quoted string without double quotes";

  # Test single quoted string that contains double quotes (should not violate)
  good_code q{my $x = 'has "quotes" inside';},
    "single quotes justified by double quotes inside";

  # Test to hit the condition in double quote checking (line 292)
  # This should exercise: $would_interpolate and not $has_single_quotes
  good_code q{my $x = "simple";}, "simple double quoted string is acceptable";
};

subtest "Use statement structure parsing" => sub {
  # Test to hit the semicolon condition (line 373)
  # $child->isa("PPI::Token::Structure") and $child->content eq ";"
  check_message q{use Foo "arg1", "arg2";}, 'use qw()',
    "use statement with semicolon and multiple args";

  # Test to hit condition line 410: $string_count > 1 and not $has_qw
  # This should be triggered by multiple string arguments without qw
  check_message q{use Foo "arg1", "arg2", "arg3"}, 'use qw()',
    "three string arguments without qw should violate";
};

subtest "Quote parsing edge cases" => sub {
  # Test cases to exercise various parsing branches

  # Test with single quotes that have escaped characters
  check_message q{my $x = 'don\\'t';}, 'use ""',
    "single quotes with escaped single quote should use double quotes";

  # Test interpolation cases to exercise would_interpolate branches
  good_code q{my $x = "variable: $var";},
    "double quotes justified by interpolation";
  good_code q{my $x = "array: @arr";},
    "double quotes justified by array interpolation";
  check_message q{my $x = "escaped: \\$var";}, "use ''",
    "escaped variables suggest single quotes";
};

done_testing;
