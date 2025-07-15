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

subtest "Single quoted strings" => sub {
  # Should violate - single quotes for simple strings
  bad q(my $x = 'hello'),
    "Single quoted simple string should use double quotes";
  bad q(my $x = 'world'), "Another simple string should use double quotes";
  bad q(my $x = 'hello world'),
    "Simple string with space should use double quotes";
  bad q(my $x = 'no special chars'),
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
  # Escaped single quotes should recommend q()
  bad q(my $x = 'I\'m happy'),
    "Escaped single quotes should use q() to avoid escapes";

  # Literal special characters
  good q(my $text = 'A $ here'), 'Literal $ should use single quotes';
  good q(my $x = 'user@domain.com'),
    "String with literal @ using single quotes";
  good q(my $x = 'literal$var'), 'String with literal $ using single quotes';
};

subtest "Mixed quote content" => sub {
  # When content has both types of quotes
  good q[my $x = q(has 'single' and "double" quotes)],
    "q() is justified when content has both quote types";
  good q[my $x = q(has 'single' and "double")],
    "q() justified when content has both quote types";

  # When content has only single quotes
  good q[my $x = q(has 'single' quotes)],
    "q() appropriate when content has single quotes but no double quotes";
};

done_testing;
