#!/usr/bin/env perl

## no critic (ValuesAndExpressions::RequireOptimalQuoteDelimiters)

use v5.20.0;
use strict;
use warnings;
use feature "signatures";

use Test2::V0;

no warnings "experimental::signatures";

# Test the RequireOptimalQuoteDelimiters policy
use lib qw( lib );
use Perl::Critic::Policy::ValuesAndExpressions::RequireOptimalQuoteDelimiters;

my $Policy
  = Perl::Critic::Policy::ValuesAndExpressions::RequireOptimalQuoteDelimiters->new;

# Create a mock PPI document for testing
use PPI;

sub test_code ($code, $expected_violations, $description, $violation_pattern = undef) {
  my $doc = PPI::Document->new(\$code);
  my @violations;

  # Find all quote-like tokens that the policy applies to
  my @target_classes = qw(
    PPI::Token::Quote::Literal
    PPI::Token::Quote::Interpolate
    PPI::Token::QuoteLike::Words
    PPI::Token::QuoteLike::Command
    PPI::Token::QuoteLike::Regexp
  );

  for my $class (@target_classes) {
    $doc->find(
      sub ($top, $elem) {
        return 0 unless $elem->isa($class);

        my $violation = $Policy->violates($elem, $doc);
        push @violations, $violation if $violation;

        return 0;  # Don't descend further
      }
    );
  }

  is scalar @violations, $expected_violations, $description;

  if (@violations && $expected_violations > 0 && $violation_pattern) {
    like
      $violations[0]->description,
      $violation_pattern,
      "Violation message matches expected pattern";
  }

  return @violations;
}

subtest "qw() operators - parentheses optimal" => sub {
  test_code q{qw{simple words}}, 1,
    "qw{} should prefer qw() for simple content";
  test_code q{qw[simple words]}, 1,
    "qw[] should prefer qw() for simple content";
  test_code q{qw(simple words)}, 0,
    "qw() should not violate for simple content";
};

subtest "qw() operators - brackets optimal" => sub {
  test_code q{qw{content(with)parens}}, 1,
    "qw{} should prefer qw[] when content has parentheses";
  test_code q{qw(content(with)parens)}, 1,
    "qw() should prefer qw[] when content has parentheses";
  test_code q{qw[content(with)parens]}, 0,
    "qw[] should not violate when content has parentheses";
};

subtest "qw() operators - braces optimal" => sub {
  test_code q{qw(content(has)both[types])}, 1,
    "qw() should prefer qw{} when content has both parens and brackets";
  test_code q{qw[content(has)both[types]]}, 1,
    "qw[] should prefer qw{} when content has both parens and brackets";
  test_code q{qw{content(has)both[types]}}, 0,
    "qw{} should not violate when content has both parens and brackets";
};

subtest "q() operators" => sub {
  test_code q{q{simple string}}, 1,
    "q{} should prefer q() for simple content";
  test_code q{q[simple string]}, 1,
    "q[] should prefer q() for simple content";
  test_code q{q(simple string)}, 0,
    "q() should not violate for simple content";

  test_code q{q{string(with)parens}}, 1,
    "q{} should prefer q[] when content has parentheses";
  test_code q{q[string(with)parens]}, 0,
    "q[] should not violate when content has parentheses";
};

subtest "qq() operators" => sub {
  test_code q{qq{simple string}}, 1,
    "qq{} should prefer qq() for simple content";
  test_code q{qq[simple string]}, 1,
    "qq[] should prefer qq() for simple content";
  test_code q{qq(simple string)}, 0,
    "qq() should not violate for simple content";
};

subtest "qx() operators" => sub {
  test_code q{qx{ls -la}}, 1,
    "qx{} should prefer qx() for simple content";
  test_code q{qx[ls -la]}, 1,
    "qx[] should prefer qx() for simple content";
  test_code q{qx(ls -la)}, 0,
    "qx() should not violate for simple content";
};

subtest "qr// operators" => sub {
  test_code q{qr{pattern}}, 1,
    "qr{} should prefer qr() for simple content";
  test_code q{qr[pattern]}, 1,
    "qr[] should prefer qr() for simple content";
  test_code q{qr(pattern)}, 0,
    "qr() should not violate for simple content";
};

subtest "Simple quotes should be ignored" => sub {
  test_code q{my $string = 'simple';}, 0,
    "Simple single quotes should be ignored";
  test_code q{my $string = "simple";}, 0,
    "Simple double quotes should be ignored";
  test_code q{my $string = 'has(parens)';}, 0,
    "Single quotes with parens should be ignored";
};

subtest "Edge cases" => sub {
  test_code q{qw{}}, 0,
    "Empty qw{} should not violate (no content to optimize)";
  test_code q{qw()}, 0,
    "Empty qw() should not violate";
  test_code q{qw[]}, 0,
    "Empty qw[] should not violate";

  test_code q{qw{a}}, 1,
    "Single character should prefer parentheses";
  test_code q{qw(a)}, 0,
    "Single character in parentheses should not violate";
};

subtest "Complex cases with multiple delimiter types" => sub {
  test_code q{qw{has(parens)[and]{braces}}}, 1,
    "Content with all delimiter types should prefer () (tie-breaking)";

  test_code q{qw{one(paren}}, 1,
    "Content with one paren should prefer brackets";
  test_code q{qw[one(paren]}, 0,
    "Content with one paren in brackets should not violate";

  test_code q{qw{one[bracket}}, 1,
    "Content with one bracket should prefer parentheses (no escaping benefit)";
  test_code q{qw(one[bracket)}, 0,
    "Content with one bracket in parentheses should not violate";
};

subtest "Tie-breaking: equal escape counts" => sub {
  # When escape counts are equal, prefer () > [] > {}
  test_code q{qw{simple}}, 1,
    "No delimiters in content should prefer parentheses over braces";
  test_code q{qw[simple]}, 1,
    "No delimiters in content should prefer parentheses over brackets";
  test_code q{qw(simple)}, 0,
    "Parentheses should not violate when optimal";
};

subtest "Multiple violations in same code" => sub {
  my $multi_code = q{
      my @good1 = qw(simple words);
      my @bad1 = qw{simple words};
      my @good2 = qw[content(with)parens];
      my @bad2 = qw{content(with)parens};
      my @good3 = qw{content(has)both[types]};
      my @bad3 = qw(content(has)both[types]);
      my $simple = 'ignored';
  };

  my @violations = test_code $multi_code, 3,
    "Found exactly 3 violations in complex code";
};

subtest "Violation message content" => sub {
  my @violations = test_code q{qw{simple}}, 1,
    "Should have violation for suboptimal delimiter",
    qr/optimal.*delimiter/i;

  if (@violations) {
    like $violations[0]->explanation, qr/qw\(\)/,
      "Explanation should suggest qw()";
  }
};

done_testing;