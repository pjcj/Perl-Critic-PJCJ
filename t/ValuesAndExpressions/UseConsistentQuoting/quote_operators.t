#!/usr/bin/env perl

use v5.20.0;
use strict;
use warnings;
use feature "signatures";

use Test2::V0;

no warnings "experimental::signatures";

# Test the policy directly without using Perl::Critic framework
use lib qw( lib );
use Perl::Critic::Policy::ValuesAndExpressions::UseConsistentQuoting;

my $Policy
  = Perl::Critic::Policy::ValuesAndExpressions::UseConsistentQuoting->new;

# Create a mock PPI document for testing
use PPI;

sub count_violations ($code, $expected_violations, $description) {
  my $doc = PPI::Document->new(\$code);
  my @violations;

  # Find all elements the policy applies to
  my @element_types = qw(
    PPI::Token::Quote::Single
    PPI::Token::Quote::Double
    PPI::Token::Quote::Literal
    PPI::Token::Quote::Interpolate
    PPI::Token::QuoteLike::Words
    PPI::Token::QuoteLike::Command
  );

  for my $type (@element_types) {
    $doc->find(
      sub ($top, $elem) {
        return 0 unless $elem->isa($type);

        my $violation = $Policy->violates($elem, $doc);
        push @violations, $violation if $violation;

        return 0;  # Don't descend further
      }
    );
  }

  is @violations, $expected_violations, $description;
  return @violations;
}

sub good ($code, $description) {
  count_violations($code, 0, $description);
}

sub bad ($code, $description) {
  count_violations($code, 1, $description);
}

subtest "q() operator" => sub {
  # Simple content should use double quotes instead of q()
  bad 'my $x = q(simple)', "q() simple string should use double quotes";
  bad 'my $x = q(simple123)',
    "q() with simple alphanumeric content should use double quotes";
  bad 'my $x = q(literal)', 'q() should use "" for literal content';

  # When q() would interpolate, should use single quotes
  bad 'my $x = q(literal $var here)',
    'q() with literal $ should use single quotes';
  bad 'my $x = q(would interpolate $var)',
    "q() should use single quotes when content would interpolate";
  bad 'my $x = q(interpolates $var)',
    "q() should use single quotes when content would interpolate";
  bad 'my $x = q(user@domain.com)',
    'q() with only literal @ should use double quotes';

  # When q() is justified
  good q[my $x = q(has 'single' and "double" quotes)],
    "q() is justified when content has both quote types";
  good q[my $x = q(has "only" double quotes)],
    "q() appropriate when content has double quotes but no interpolation";

  # Different q() delimiters
  bad q(my $x = q'simple'), "q'' should use double quotes for simple content";
  bad 'my $x = q/simple/',  "q// should use double quotes for simple content";
  bad 'my $x = q(literal$x)',
    "q() should use single quotes for literal content";
  bad 'my $x = q/literal$x/', "q// should use single quotes";
};

subtest "qq() operator" => sub {
  # Should use double quotes instead of qq()
  bad 'my $x = qq(simple)',
    "qq() should use double quotes for simple content";
  bad 'my $x = qq/hello/', "qq// should use double quotes";
  bad q(my $x = qq'simple'),
    "qq'' should use double quotes for simple content";
  bad 'my $x = qq/simple/',
    "qq// should use double quotes for simple content";
  bad 'my $x = qq(simple)',
    "qq() should use double quotes for simple content";

  # When qq() is appropriate (has double quotes)
  good q[my $x = qq(has "double" quotes)],
    "qq() appropriate when content has double quotes";
};

subtest "Priority rules" => sub {
  # Rule 1: Prefer interpolating quotes unless strings shouldn't interpolate
  bad q(my $x = 'simple'), "Simple string should use double quotes";
  good 'my $x = "simple"', "Simple string with double quotes";
  good q(my $x = 'literal$var'),
    'String with literal $ should use single quotes';
  good q(my $x = 'literal@var'),
    'String with literal @ should use single quotes';

  # Rule 3: Prefer "" to qq
  bad 'my $x = qq(simple)',
    "qq() should use double quotes for simple content";
  good 'my $x = "simple"', "Double quotes preferred over qq()";

  # Rule 4: Prefer '' to q
  bad 'my $x = q(literal$x)',
    "q() should use single quotes for literal content";
  good q(my $x = 'literal$x'), "Single quotes preferred over q()";
};

done_testing;
