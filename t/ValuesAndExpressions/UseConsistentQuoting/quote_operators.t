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

subtest "q() operator" => sub {
  # Simple content should use double quotes instead of q()
  check_violation_message 'my $x = q(simple)', 'use ""',
    "q() simple string should use double quotes";
  check_violation_message 'my $x = q(simple123)', 'use ""',
    "q() with simple alphanumeric content should use double quotes";
  check_violation_message 'my $x = q(literal)', 'use ""',
    'q() should use "" for literal content';

  # When q() would interpolate, should use single quotes
  check_violation_message 'my $x = q(literal $var here)',
    "use '' instead of q()", 'q() with literal $ should use single quotes';
  check_violation_message 'my $x = q(would interpolate $var)',
    "use '' instead of q()",
    "q() should use single quotes when content would interpolate";
  check_violation_message 'my $x = q(interpolates $var)',
    "use '' instead of q()",
    "q() should use single quotes when content would interpolate";
  check_violation_message 'my $x = q(user@domain.com)', 'use ""',
    'q() with only literal @ should use double quotes';

  # When q() is justified
  good q[my $x = q(has 'single' and "double" quotes)],
    "q() is justified when content has both quote types";
  check_violation_message q[my $x = q(has "only" double quotes)],
    "use '' instead of q()",
    "q() with only double quotes should recommend single quotes";

  # Different q() delimiters
  check_violation_message q(my $x = q'simple'), 'use ""',
    "q'' should use double quotes for simple content";
  check_violation_message 'my $x = q/simple/', 'use ""',
    "q// should use double quotes for simple content";
  check_violation_message 'my $x = q(literal$x)', "use '' instead of q()",
    "q() should use single quotes for literal content";
  check_violation_message 'my $x = q/literal$x/', "use '' instead of q()",
    "q// should use single quotes";
};

subtest "qq() operator" => sub {
  # Should use double quotes instead of qq()
  check_violation_message 'my $x = qq(simple)', 'use "" instead of qq()',
    "qq() should use double quotes for simple content";
  check_violation_message 'my $x = qq/hello/', 'use "" instead of qq()',
    "qq// should use double quotes";
  check_violation_message q(my $x = qq'simple'), 'use "" instead of qq()',
    "qq'' should use double quotes for simple content";
  check_violation_message 'my $x = qq/simple/', 'use "" instead of qq()',
    "qq// should use double quotes for simple content";
  check_violation_message 'my $x = qq(simple)', 'use "" instead of qq()',
    "qq() should use double quotes for simple content";

  # When qq() is appropriate (has double quotes)
  good q[my $x = qq(has "double" quotes)],
    "qq() appropriate when content has double quotes";
};

subtest "Priority rules" => sub {
  # Rule 1: Prefer interpolating quotes unless strings shouldn't interpolate
  check_violation_message q(my $x = 'simple'), 'use ""',
    "Simple string should use double quotes";
  good 'my $x = "simple"', "Simple string with double quotes";
  good q(my $x = 'literal$var'),
    'String with literal $ should use single quotes';
  good q(my $x = 'literal@var'),
    'String with literal @ should use single quotes';

  # Rule 3: Prefer "" to qq
  check_violation_message 'my $x = qq(simple)', 'use "" instead of qq()',
    "qq() should use double quotes for simple content";
  good 'my $x = "simple"', "Double quotes preferred over qq()";

  # Rule 4: Prefer '' to q
  check_violation_message 'my $x = q(literal$x)', "use '' instead of q()",
    "q() should use single quotes for literal content";
  good q(my $x = 'literal$x'), "Single quotes preferred over q()";
};

done_testing;
