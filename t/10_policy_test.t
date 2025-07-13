#!/usr/bin/env perl

use v5.20.0;
use strict;
use warnings;
use feature "signatures";

use Test2::V0;

no warnings "experimental::signatures";

# Test the policy directly without using Perl::Critic framework
use lib qw( lib );
use Perl::Critic::Policy::ValuesAndExpressions::RequireDoubleQuotedStrings;

my $Policy
  = Perl::Critic::Policy::ValuesAndExpressions::RequireDoubleQuotedStrings->new;

# Create a mock PPI document for testing
use PPI;

sub test_code ($code, $expected_violations, $description) {

  my $doc = PPI::Document->new(\$code);
  my @violations;

  $doc->find(
    sub ($top, $elem) {
      return 0 unless $elem->isa("PPI::Token::Quote::Single");

      my $violation = $Policy->violates($elem, $doc);
      push @violations, $violation if $violation;

      return 0;  # Don't descend further
    }
  );

  is scalar @violations, $expected_violations, $description;

  if (@violations && $expected_violations > 0) {
    like(
      $violations[0]->description,
      qr/double quotes/,
      "Violation mentions double quotes"
    );
  }
}

subtest "Simple strings should violate policy" => sub {
  test_code q{my $greeting = 'hello';}, 1,
    "Simple single-quoted string should violate";
  test_code q{my $name = 'world';}, 1,
    "Another simple single-quoted string should violate";
  test_code q{my $message = 'hello world';}, 1,
    "Simple string with spaces should violate";
  test_code q{my $empty = '';}, 1,
    "Empty single-quoted string should violate";
};

subtest "Complex strings should NOT violate policy" => sub {
  test_code q{my $email = 'user@domain.com';}, 0,
    'String with @ should not violate';
  test_code q{my $quoted = 'He said "hello"';}, 0,
    "String with embedded quotes should not violate";
  test_code q{my $complex = 'both @ and "quotes"';}, 0,
    'String with both @ and quotes should not violate';
};

subtest "Multiple violations in complex code" => sub {
  my $multi_code = q{
      my $good1 = "proper";
      my $bad1 = 'simple';
      my $good2 = 'has@symbol';
      my $bad2 = 'another simple';
  };

  my $doc = PPI::Document->new(\$multi_code);
  my @violations;

  $doc->find(
    sub ($top, $elem) {
      return 0 unless $elem->isa("PPI::Token::Quote::Single");

      my $violation = $Policy->violates($elem, $doc);
      push @violations, $violation if $violation;

      return 0;
    }
  );

  is @violations, 2, "Found exactly 2 violations in complex code";
};

done_testing;
