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

subtest "Policy methods" => sub {
  # Test default_themes
  my @themes = $Policy->default_themes;
  is @themes,    1,          "default_themes returns one theme";
  is $themes[0], "cosmetic", "default theme is cosmetic";

  # Test applies_to
  my @types = $Policy->applies_to;
  is @types, 6, "applies_to returns 6 token types";
  like $types[0], qr/Quote/, "applies_to returns quote token types";

  # Test delimiter_preference_order method directly
  is $Policy->delimiter_preference_order("("), 0, "() has preference 0";
  is $Policy->delimiter_preference_order("["), 1, "[] has preference 1";
  is $Policy->delimiter_preference_order("<"), 2, "<> has preference 2";
  is $Policy->delimiter_preference_order("{"), 3, "{} has preference 3";
  is $Policy->delimiter_preference_order("x"), 99,
    "invalid delimiter returns 99";

  # Test would_interpolate method directly
  ok !$Policy->would_interpolate("simple"),
    "Simple string doesn't interpolate";
  ok $Policy->would_interpolate('$var'),   "Variable interpolates";
  ok $Policy->would_interpolate('@array'), "Array interpolates";
  ok !$Policy->would_interpolate('\\$escaped'),
    "Escaped variable doesn't interpolate";
};

subtest "Basic functionality" => sub {
  # Simple tests to verify policy is working
  bad q(my $x = 'hello'),
    "Single quoted simple string should use double quotes";
  good 'my $x = "hello"', "Double quoted simple string";

  # Multiple violations
  count_violations q(
    my $x = 'hello';
    my $y = 'world';
    my $z = 'foo';
  ), 3, "Multiple simple single-quoted strings all violate";

  # Mixed violations
  count_violations q(
    my $x = 'hello';
    my $y = "world";
    my $z = 'user@example.com';
  ), 1, "Only simple single-quoted string violates";
};

subtest "Invalid token types" => sub {
  # Test that non-quote tokens don't violate
  my $doc = PPI::Document->new(\'my $x = 42');
  $doc->find(
    sub ($top, $elem) {
      if ($elem->isa("PPI::Token::Number")) {
        # This should return undef from _parse_quote_token
        my $violation = $Policy->violates($elem, $doc);
        is $violation, undef, "Non-quote tokens don't violate";
      }
      0
    }
  );
};

subtest "Find optimal delimiter coverage" => sub {
  # Test find_optimal_delimiter with non-bracket current delimiter
  # This covers the condition where current delimiter is not in bracket list
  my ($optimal, $is_optimal)
    = $Policy->find_optimal_delimiter("content", "qw", "/", "/");
  is $is_optimal, 0, "Non-bracket delimiter is never optimal";

  # Test conditions with bracket vs non-bracket delimiters
  my ($optimal2, $is_optimal2)
    = $Policy->find_optimal_delimiter("content", "qw", "(", ")");
  is $is_optimal2, 1, "Bracket delimiter can be optimal";
};

done_testing;
