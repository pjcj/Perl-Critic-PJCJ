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
use ViolationFinder qw(find_violations count_violations good bad);

my $Policy
  = Perl::Critic::Policy::ValuesAndExpressions::UseConsistentQuoting->new;

subtest "Condition coverage tests" => sub {
  # Test to hit the uncovered condition in single quote checking (line 229)
  # This should exercise: not $would_interpolate and index($string, "\"") == -1
  bad $Policy, q(my $x = 'simple';), 'use ""',
    "simple single quoted string without double quotes";

  # Test single quoted string that contains double quotes (should not violate)
  good $Policy, q(my $x = 'has "quotes" inside';),
    "single quotes justified by double quotes inside";

  # Test to hit the condition in double quote checking (line 292)
  # This should exercise: $would_interpolate and not $has_single_quotes
  good $Policy, 'my $x = "simple";',
    "simple double quoted string is acceptable";
};

subtest "Use statement structure parsing" => sub {
  # Test to hit the semicolon condition (line 373)
  # $child->isa("PPI::Token::Structure") and $child->content eq ";"
  bad $Policy, 'use Foo "arg1", "arg2";', "use qw()",
    "use statement with semicolon and multiple args";

  # Test to hit condition line 410: $string_count > 1 and not $has_qw
  # This should be triggered by multiple string arguments without qw
  bad $Policy, 'use Foo "arg1", "arg2", "arg3"', "use qw()",
    "three string arguments without qw should violate";
};

subtest "Quote parsing edge cases" => sub {
  # Test cases to exercise various parsing branches

  # Test with single quotes that have escaped characters
  bad $Policy, q(my $x = 'don\\'t';), 'use ""',
    "single quotes with escaped single quote should use double quotes";

  # Test interpolation cases to exercise would_interpolate branches
  good $Policy, 'my $x = "variable: $var";',
    "double quotes justified by interpolation";
  good $Policy, 'my $x = "array: @arr";',
    "double quotes justified by array interpolation";
  bad $Policy, 'my $x = "escaped: \\$var";', "use ''",
    "escaped variables suggest single quotes";
};

subtest "q() delimiter optimization path" => sub {
  # Test cases to cover when q() is justified and needs delimiter optimization

  # Test: q() with both quote types - justified, optimize delimiter
  bad $Policy, q(my $text = q[mix 'single' and "double"]), "use q()",
    "q[] with mixed quotes should use q()";

  # Test: q() with single quotes and interpolation - justified,
  # optimize delimiter
  bad $Policy, q(my $text = q|can't use $var|), "use q()",
    "q| with single quotes and interpolation should use q()";

  # Test: q() with double quotes and interpolation - justified,
  # optimize delimiter
  bad $Policy, q(my $text = q|Hello "there" $name|), "use q()",
    "q| with double quotes and interpolation should use q()";

  # Test: q() already using optimal delimiter should not violate
  good $Policy, q[my $text = q(mix 'single' and "double")],
    "q() with mixed quotes and optimal delimiter is justified";

  good $Policy, q[my $text = q(Hello "there" $name)],
    "q() with double quotes and interpolation is justified";
};

done_testing;
