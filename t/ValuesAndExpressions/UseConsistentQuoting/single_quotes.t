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
use ViolationFinder qw(find_violations);

my $Policy
  = Perl::Critic::Policy::ValuesAndExpressions::UseConsistentQuoting->new;

sub count_violations ($code, $expected_violations, $description) {
  my @violations = find_violations($Policy, $code);
  is @violations, $expected_violations, $description;
  return @violations;
}

sub good ($code, $description) {
  count_violations($code, 0, $description);
}

sub bad ($code, $description) {
  count_violations($code, 1, $description);
}

sub check_violation_message ($code, $expected_message, $description) {
  my @violations = find_violations($Policy, $code);
  is @violations, 1, "$description - should have one violation";
  like $violations[0]->explanation, qr/$expected_message/,
    "$description - should suggest $expected_message";
}

subtest "Single quoted strings" => sub {
  # Should violate - single quotes for simple strings
  check_violation_message q(my $x = 'hello'), 'use ""',
    "Single quoted simple string should use double quotes";
  check_violation_message q(my $x = 'world'), 'use ""',
    "Another simple string should use double quotes";
  check_violation_message q(my $x = 'hello world'), 'use ""',
    "Simple string with space should use double quotes";
  check_violation_message q(my $x = 'no special chars'), 'use ""',
    "Single quotes for non-interpolating string should use double quotes";

  # Should NOT violate - appropriate use of single quotes
  good q(my $x = 'user@domain.com'),
    "String with literal @ using single quotes";
  good q(my $x = 'He said "hello"'),
    "String with double quotes using single quotes";
  good q(my $x = 'literal$var'), 'String with literal $ using single quotes';
  good q(my $x = 'literal@var'), 'String with literal @ using single quotes';
};

subtest "Escaped characters in single quotes" => sub {
  # Escaped single quotes should recommend double quotes
  check_violation_message q(my $x = 'I\'m happy'), 'use ""',
    'Escaped single quotes should use ""';

  # Literal special characters
  good q(my $text = 'A $ here'), 'Literal $ should use single quotes';
  good q(my $x = 'user@domain.com'),
    "String with literal @ using single quotes";
  good q(my $x = 'literal$var'), 'String with literal $ using single quotes';
};

subtest "Mixed quote content" => sub {
  # When content has both types of quotes with optimal delimiter - acceptable
  good q[my $x = q(has 'single' and "double" quotes)],
    "q() is justified when content has both quote types";
  good q[my $x = q(has 'single' and "double")],
    "q() justified when content has both quote types";

  # When content has both types with suboptimal delimiter - should suggest
  # better delimiter
  check_violation_message q[my $x = q[has 'single' and "double" quotes]],
    'use q()',
    "q[] with both quote types should recommend q() for optimal delimiter";

  # When content has only single quotes - should recommend double quotes
  check_violation_message q[my $x = q(has 'single' quotes)], 'use ""',
    "q() with only single quotes should recommend double quotes";
};

done_testing;
