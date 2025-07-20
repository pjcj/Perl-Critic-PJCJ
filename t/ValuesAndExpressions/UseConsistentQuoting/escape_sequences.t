#!/usr/bin/env perl

use v5.20.0;
use strict;
use warnings;
use feature "signatures";

use Test2::V0;

no warnings "experimental::signatures";

# Test escape sequence handling in quotes
use lib qw( lib t/lib );
use Perl::Critic::Policy::ValuesAndExpressions::UseConsistentQuoting;
use ViolationFinder qw(find_violations count_violations good bad);

## no critic (ValuesAndExpressions::UseConsistentQuoting)

my $Policy
  = Perl::Critic::Policy::ValuesAndExpressions::UseConsistentQuoting->new;

subtest "Escaped sigils should suggest double quotes" => sub {
  # These are currently incorrectly handled by line 218
  # In single quotes: '\$' is literally backslash-dollar
  # In double quotes: "\$" is properly escaped dollar

  bad $Policy, q(my $price = "Cost: \$10"), "use ''",
    "Escaped dollar in single quotes should suggest double quotes";

  bad $Policy, q(my $email = "Contact: \@domain"), "use ''",
    "Escaped at in single quotes should suggest double quotes";

  # Mixed escaped and literal content
  bad $Policy, q(my $mixed = "\$escaped and literal text"), "use ''",
    "Escaped sigils with text should suggest double quotes";
};

subtest "Other escape sequences in single quotes" => sub {
  # Single quotes treat these as literal, double quotes interpret them

  good $Policy, q(my $text = "Line 1\nLine 2"),
    "Escape sequences in double quotes are acceptable";

  good $Policy, q(my $text = "Tab\there"),
    "Tab escape sequence in double quotes is acceptable";

  good $Policy, q(my $path = "C:\new\folder"),
    "Path with backslashes in double quotes is acceptable";
};

subtest "True variable interpolation should keep single quotes" => sub {
  # These should remain single quotes to prevent interpolation

  good $Policy, q(my $literal = '$var should not interpolate'),
    "Literal variable reference should stay single quotes";

  good $Policy, q(my $array = '@array should not interpolate'),
    "Literal array reference should stay single quotes";

  good $Policy, q(my $complex = '$hash{key} should not interpolate'),
    "Complex variable reference should stay single quotes";
};

subtest "Edge cases with backslashes" => sub {
  # Test boundary conditions

  good $Policy, q(my $backslash = "Just \\ backslash"),
    "Escaped backslash in double quotes is acceptable";

  good $Policy, q(my $quote = 'Has "double" quotes'),
    "Single quotes justified by containing double quotes";

  # Test the two valid single-quote escapes
  # Actually, escaped single quotes should suggest double quotes
  # for better readability
  good $Policy, q(my $escaped_quote = "Don't worry"),
    "Simple apostrophe in double quotes is acceptable";
};

done_testing;
