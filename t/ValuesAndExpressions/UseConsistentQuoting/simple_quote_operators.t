#!/usr/bin/env perl

use v5.20.0;
use strict;
use warnings;
use feature "signatures";

use Test2::V0;

no warnings "experimental::signatures";

# Test that q() and qq() suggest simpler quotes for simple strings
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

sub check_violation_message ($code, $expected_message, $description) {
  my @violations = find_violations($Policy, $code);
  is @violations, 1, "$description - should have one violation";
  like $violations[0]->explanation, qr/$expected_message/,
    "$description - should suggest $expected_message";
}

subtest "q() with simple strings - follow single quote rules" => sub {
  # Case 1: Simple strings that would cause single quotes to suggest double
  # quotes
  check_violation_message 'my $x = q(simple);', 'use ""',
    "q() with simple string should suggest double quotes";
  check_violation_message q{my $x = q{simple};}, 'use ""',
    "q{} with simple string should suggest double quotes";

  # Case 2: Strings where single quotes would be acceptable
  check_violation_message q{my $x = q(has "quotes");},
    "use '' instead of q()",
    "q() with content that justifies single quotes should suggest single quotes";
  check_violation_message q{my $x = q{$variable};}, "use '' instead of q()",
    "q{} with variable content should suggest single quotes";

  # Case 3: Strings that would cause single quotes to suggest double quotes
  # (because they contain single quotes but no variables)
  check_violation_message q{my $x = q(don't);}, 'use ""',
    "q() with embedded single quote should suggest double quotes";
  check_violation_message q{my $x = q{user's};}, 'use ""',
    "q{} with embedded single quote should suggest double quotes";

  # Case 3: Strings that would cause single quotes to need q()
  # (because they have both single and double quotes)
  check_violation_message q{my $x = q/mix 'single' and "double"/;}, "use q()",
    "q/ with mixed quotes should suggest q() with optimal delimiter";
  check_violation_message q{my $x = q|mix 'single' and "double"|;}, "use q()",
    "q| with mixed quotes should suggest q() with optimal delimiter";

  # Case 4: Strings that have single quotes that would need escaping
  check_violation_message q{my $x = q/can't and won't/;},
    'use ""',
    "q/ with single quotes should suggest double quotes";
};

subtest "qq() with simple strings - follow double quote rules" => sub {
  # Case 1: Simple strings that would be fine as double quotes
  check_violation_message q{my $x = qq(simple);}, 'use "" instead of qq()',
    "qq() with simple string should suggest double quotes";
  check_violation_message q{my $x = qq{simple};}, 'use "" instead of qq()',
    "qq{} with simple string should suggest double quotes";

  # Case 2: Strings that would cause double quotes to suggest single quotes
  # (because they have escaped characters that look like variables)
  check_violation_message q{my $x = qq(price: \$5.00);},
    "use '' instead of qq()",
    "qq() with escaped dollar should suggest single quotes";
  check_violation_message q{my $x = qq{email\@domain.com};},
    "use '' instead of qq()",
    "qq{} with escaped at-sign should suggest single quotes";

  # Case 3: Strings that would cause double quotes to need qq()
  # (because they contain double quotes and need interpolation)
  check_violation_message
    q{my $var = "test"; my $x = qq/has "quotes" and $var/;}, "use qq()",
    "qq/ with quotes and interpolation should suggest qq() with optimal delimiter";
  check_violation_message q{my @arr = (); my $x = qq|has "quotes" and @arr|;},
    "use qq()",
    "qq| with quotes and interpolation should suggest qq() with optimal delimiter";
};

subtest "Consistency verification" => sub {
  # Verify that following the suggestion doesn't create new violations

  # These simple cases should not violate when changed to suggested form
  count_violations q{my $x = "simple";}, 0,
    "suggested form for q(simple) should not violate";
  count_violations q{my $x = "simple";}, 0,
    "suggested form for qq(simple) should not violate";

  # These should not violate when changed to suggested form
  count_violations q{my $x = 'has "quotes"';}, 0,
    "suggested form for q(has \"quotes\") should not violate";
  count_violations q{my $x = "don't";}, 0,
    "suggested form for q(don't) should not violate";
  count_violations q{my $x = 'price: \$5.00';}, 0,
    "suggested form for qq(price: \$5.00) should not violate";

  # These complex cases should not violate when using q()/qq() with optimal delimiters
  count_violations q{my $x = q(mix 'single' and "double");}, 0,
    "q() with optimal delimiter should not violate";
  count_violations q{my $var = "test"; my $x = qq(has "quotes" and $var);},
    0, "qq() with optimal delimiter should not violate";
};

done_testing;
