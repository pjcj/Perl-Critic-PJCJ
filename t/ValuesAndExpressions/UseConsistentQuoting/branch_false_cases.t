#!/usr/bin/env perl

use v5.20.0;
use strict;
use warnings;
use feature "signatures";

use Test2::V0;

no warnings "experimental::signatures";

# Test cases to make "branch never false" conditions evaluate to false
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

subtest "Try to trigger false branches" => sub {
  # Try to create a quote that fails to parse (line 73)
  # This is tricky because PPI usually handles malformed quotes gracefully

  # Try to create conditions where parse_quote_token might fail (line 169, 324)
  # These require invalid quote structures that PPI might reject

  # Try to hit the delimiter comparison false case (line 148)
  # This needs a delimiter that doesn't match the current one

  # For now, test normal cases to ensure tests are working
  count_violations q{my $x = "normal";}, 0, "normal double quote case";
  count_violations q{my $x = 'normal';}, 1,
    "normal single quote case should violate";

  # Test qw with different delimiters to try to hit different code paths
  count_violations q{my @x = qw/word1 word2/;}, 1,
    "qw with / delimiter should suggest ()";
  count_violations q{my @x = qw{word1 word2};}, 1,
    "qw with {} delimiter should suggest ()";
  count_violations q{my @x = qw[word1 word2];}, 1,
    "qw with [] delimiter should suggest ()";
  count_violations q{my @x = qw<word1 word2>;}, 1,
    "qw with <> delimiter should suggest ()";

  # Test cases that might trigger different sorting/comparison results
  count_violations q{my $x = qq{content with (parens) and [brackets]};}, 1,
    "qq with {} containing multiple bracket types";
};

done_testing;
