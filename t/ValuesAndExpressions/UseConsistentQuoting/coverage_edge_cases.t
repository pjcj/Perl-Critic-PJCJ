#!/usr/bin/env perl

use v5.20.0;
use strict;
use warnings;
use feature "signatures";

use Test2::V0;

no warnings "experimental::signatures";

# Test edge cases to achieve 100% coverage
use lib qw( lib t/lib );
use Perl::Critic::Policy::ValuesAndExpressions::UseConsistentQuoting;
use ViolationFinder qw(find_violations count_violations good bad);

## no critic (ValuesAndExpressions::UseConsistentQuoting)

my $Policy
  = Perl::Critic::Policy::ValuesAndExpressions::UseConsistentQuoting->new;

subtest "Edge cases for uncovered lines" => sub {
  # Test for line 229: single quotes that would interpolate but have no sigils
  # This should be impossible based on the logic, but let's test edge cases

  # Edge case: try strings with special characters that might confuse the parser
  # Note: strings with escape sequences in single quotes should stay single
  # quotes because \n has different meanings: literal in '', newline in ""
  good $Policy, q(my $x = 'text with \n newline but no interpolation'),
    'Single quotes with escape sequences should stay single quotes';

  # Test for line 291: q() cases that might fall through all conditions
  # Looking for: has_double_quotes && would_interpolate && !has_dollar &&
  # !has_single_quotes

  # Try edge case with @ but no $ and double quotes
  bad $Policy, q(my $x = q(user@domain.com "needs" quoting)), "use ''",
    'q() with @ and double quotes should suggest single quotes';

  # Try case that might have interpolation issues with complex content
  bad $Policy, q(my $x = q(complex@email.com with "embedded quotes" text)),
    "use ''", 'q() with @ and double quotes should suggest single quotes';

  # Edge case: content that might confuse the would_interpolate method
  bad $Policy, q(my $x = q(\@escaped at sign with "quotes")), "use ''",
    'q() with escaped @ and double quotes should suggest single quotes';
};

subtest "Boundary conditions for interpolation detection" => sub {
  # Test strings that might expose issues in would_interpolate logic

  # These test the boundary between interpolation and non-interpolation
  good $Policy, q(my $x = 'literal \$dollar with "quotes"'),
    'Single quotes justified for escaped dollar with double quotes';

  good $Policy, q(my $x = 'literal \@at with "quotes"'),
    'Single quotes justified for escaped at with double quotes';

  # Test q() with escaped sigils and quotes
  bad $Policy, q(my $x = q(\$var and "quotes" together)), "use ''",
    'q() with escaped dollar and double quotes should suggest single quotes';

  bad $Policy, q(my $x = q(\@var and "quotes" together)), "use ''",
    'q() with escaped at and double quotes should suggest single quotes';
};

subtest "Parser edge cases" => sub {
  # Test cases that might confuse the PPI parser in would_interpolate

  # Complex strings that might not parse correctly in double quotes
  good $Policy, q(my $x = 'text with " and \\ and other escapes'),
    'Single quotes for complex escape sequences';

  # Test q() with content that might not be handled by early returns
  bad $Policy, q(my $x = q(text with "quotes" and \\ escapes)), "use ''",
    'q() with quotes and escapes should suggest single quotes';
};

done_testing;
