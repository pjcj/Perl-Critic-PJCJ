#!/usr/bin/env perl

use v5.20.0;
use strict;
use warnings;
use feature "signatures";

use Test2::V0;

no warnings "experimental::signatures";

# Test to exercise uncovered branches in quote checking within use statements
use lib qw( lib t/lib );
use Perl::Critic::Policy::ValuesAndExpressions::UseConsistentQuoting;
use ViolationFinder qw(find_violations count_violations good bad);

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
  bad($Policy, $code, $expected_message, $description);
}

subtest "Exercise _is_in_use_statement branches" => sub {
  # These test cases are designed to exercise the _is_in_use_statement method
  # by having quote tokens inside use statements that would normally be flagged

  # Test q() quotes inside use statements - should be skipped by regular q() checking
  good_code q{use Foo q(simple)},
    "q() in use statements bypasses regular q() rules";
  good_code q{use Foo q{simple}},
    "q{} in use statements bypasses regular q() rules";
  good_code q{use Foo q[simple]},
    "q[] in use statements bypasses regular q() rules";
  good_code q{use Foo q<simple>},
    "q<> in use statements bypasses regular q() rules";

  # Test qq() quotes inside use statements - should be skipped by regular qq() checking
  good_code q{use Foo qq(simple)},
    "qq() in use statements bypasses regular qq() rules";
  good_code q{use Foo qq{simple}},
    "qq{} in use statements bypasses regular qq() rules";
  good_code q{use Foo qq[simple]},
    "qq[] in use statements bypasses regular qq() rules";
  good_code q{use Foo qq<simple>},
    "qq<> in use statements bypasses regular qq() rules";
};

subtest "Use statements with multiple quote types" => sub {
  # Test multiple arguments to trigger the use statement multiple argument rule
  check_message q{use Foo q(arg1), q(arg2)}, "use qw()",
    "multiple q() arguments trigger use statement rule";
  check_message q{use Foo qq(arg1), qq(arg2)}, "use qw()",
    "multiple qq() arguments trigger use statement rule";

  # Mixed quote types
  check_message q{use Foo q(arg1), "arg2"}, "use qw()",
    "mixed q() and double quotes trigger use statement rule";
  check_message q{use Foo qq(arg1), "arg2"}, "use qw()",
    "mixed qq() and single quotes trigger use statement rule";
};

subtest "Edge cases for coverage" => sub {
  # Test semicolon handling - covers the semicolon branch in _extract_use_arguments
  good_code q{use Foo "arg"; # with semicolon},
    "use statement with semicolon works";

  # Test require and no statements to ensure they don't trigger use statement logic
  check_message q{require q(file.pl)}, 'use ""',
    "require with q() is not processed by use statement logic";
  check_message q{no warnings qq(experimental)}, 'use ""',
    "no statement qq() is processed by regular quote logic";
};

done_testing;
