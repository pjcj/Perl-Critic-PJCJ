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

subtest "Try to trigger false branches" => sub {
  # Try to create a quote that fails to parse (line 73)
  # This is tricky because PPI usually handles malformed quotes gracefully

  # Try to create conditions where parse_quote_token might fail (line 169, 324)
  # These require invalid quote structures that PPI might reject

  # Try to hit the delimiter comparison false case (line 148)
  # This needs a delimiter that doesn't match the current one

  # For now, test normal cases to ensure tests are working
  good_code 'my $x = "normal";', "normal double quote case";
  bad_code q(my $x = 'normal';), "normal single quote case should violate";

  # Test qw with different delimiters to try to hit different code paths
  check_message 'my @x = qw/word1 word2/;', "use qw()",
    "qw with / delimiter should suggest ()";
  check_message 'my @x = qw{word1 word2};', "use qw()",
    "qw with {} delimiter should suggest ()";
  check_message 'my @x = qw[word1 word2];', "use qw()",
    "qw with [] delimiter should suggest ()";
  check_message 'my @x = qw<word1 word2>;', "use qw()",
    "qw with <> delimiter should suggest ()";

  # Test cases that might trigger different sorting/comparison results
  check_message 'my $x = qq{content with (parens) and [brackets]};',
    'use ""', "qq with {} containing multiple bracket types";
};

done_testing;
