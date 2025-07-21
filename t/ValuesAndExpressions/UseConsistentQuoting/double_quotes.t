#!/usr/bin/env perl

use v5.20.0;
use strict;
use warnings;
use feature "signatures";

use Test2::V0;

no warnings "experimental::signatures";

# Test the policy directly without using Perl::Critic framework
use lib qw( lib t/lib );
use Perl::Critic::Policy::ValuesAndExpressions::UseConsistentQuoting;
use ViolationFinder qw(find_violations count_violations good bad);

my $Policy
  = Perl::Critic::Policy::ValuesAndExpressions::UseConsistentQuoting->new;

subtest "Double quoted strings" => sub {
  good $Policy, 'my $x = "hello"', "Double quoted simple string";
  good $Policy, 'my $x = "It\'s a nice day"',
    "String with single quote needs double quotes";
  good $Policy, 'my $x = "Hello $name"',
    "String with interpolation needs double quotes";

  good $Policy, 'my $mixed = "\$a $b"',
    "Mixed escaped and real interpolation should stay double quotes";
};

subtest "Escaped special characters" => sub {
  bad $Policy, 'my $output = "Price: \$10"', "use ''",
    "Escaped dollar signs should use single quotes";
  bad $Policy, 'my $email = "\@domain"', "use ''",
    "Escaped at-signs should use single quotes";
  bad $Policy, 'my $quote = "\""', "use ''",
    "Escaped double quotes should use single quotes";
};

subtest "Interpolation with quotes" => sub {
  # Strings that interpolate and have quotes
  good $Policy, 'my $text = "contains $var and \"quotes\""',
    "Double quotes with interpolation and quotes";
  good $Policy, 'my $x = "string with $var and \"quotes\""',
    "Double quotes appropriate when string interpolates and has quotes";

  # Contains both single and double quotes
  good $Policy, q(my $text = "contains 'single' quotes"),
    '"" appropriate when content has single quotes';
  good $Policy, q[my $text = qq(contains 'both' and "quotes")],
    "qq() appropriate when content has both quote types";
};

subtest "Additional double quote coverage tests" => sub {
  # Test to hit the condition in double quote checking (line 292)
  # This should exercise: $would_interpolate and not $has_single_quotes
  good $Policy, 'my $x = "simple";',
    "simple double quoted string is acceptable";

  # Test interpolation cases to exercise would_interpolate branches
  good $Policy, 'my $x = "variable: $var";',
    "double quotes justified by interpolation";
  good $Policy, 'my $x = "array: @arr";',
    "double quotes justified by array interpolation";
  bad $Policy, 'my $x = "escaped: \\$var";', "use ''",
    "escaped variables suggest single quotes";
};

done_testing;
