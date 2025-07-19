#!/usr/bin/env perl

use v5.20.0;
use strict;
use warnings;
use feature "signatures";

use Test2::V0;

no warnings "experimental::signatures";

# Test edge cases for LimitLineLength policy to improve coverage
use lib qw( lib t/lib );
use Perl::Critic::Policy::CodeLayout::LimitLineLength;
use ViolationFinder qw(find_violations);

my $Policy = Perl::Critic::Policy::CodeLayout::LimitLineLength->new;

sub count_violations ($code, $expected_violations, $description) {
  my @violations = find_violations($Policy, $code);
  is @violations, $expected_violations, $description;
  return @violations;
}

subtest "Edge cases for line length detection" => sub {
  # Test very long line to trigger violation
  my $long_line = 'my $very_long_variable_name = "' . ("x" x 100) . '";';
  count_violations $long_line, 1, "very long line should violate";

  # Test line exactly at limit (80 characters)
  my $exact_limit = 'my $var = "' . ("x" x 67) . '";';
  count_violations $exact_limit, 0,
    "line exactly at 80 chars should not violate";

  # Test line just over limit (81 characters)
  my $just_over = 'my $var = "' . ("x" x 68) . '";';
  count_violations $just_over, 1, "line at 81 chars should violate";
};

subtest "Multi-line structures" => sub {
  # Test with multi-line structures that might have edge cases
  local $Policy->{_max_line_length} = 72;  ## no critic (local)
  my $multi_line = '
my $hash = {
  very_very_long_key_name_that_exceeds_eighty_characters_to_trigger_violation
    => "value",
  short => "ok"
};
';
  count_violations $multi_line, 1,
    "long line in hash structure should violate";
};

done_testing;
