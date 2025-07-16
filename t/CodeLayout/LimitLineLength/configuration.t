#!/usr/bin/env perl

use v5.20.0;
use strict;
use warnings;
use feature "signatures";

use Test2::V0;

no warnings "experimental::signatures";

# Test the policy with custom configuration
use lib qw( lib t/lib );
use Perl::Critic::Policy::CodeLayout::LimitLineLength;
use ViolationFinder qw(find_violations);

sub count_violations ($policy, $code, $expected_violations, $description) {
  my @violations = find_violations($policy, $code);
  is @violations, $expected_violations, $description;
  return @violations;
}

sub good ($policy, $code, $description) {
  count_violations($policy, $code, 0, $description);
}

sub bad ($policy, $code, $description) {
  count_violations($policy, $code, 1, $description);
}

subtest "Custom max_line_length = 40" => sub {
  my $policy = Perl::Critic::Policy::CodeLayout::LimitLineLength->new();
  $policy->{_max_line_length} = 40;

  # Test lines within 40 char limit
  good $policy, 'my $x = "hello"', "Short line within 40 chars";

  # Test line exactly at 40 chars
  my $exactly_40 = 'my $var = "' . ("x" x 27) . '";';
  is length($exactly_40), 40, "Test string is exactly 40 chars";
  good $policy, $exactly_40, "Line exactly at 40 characters";

  # Test line over 40 chars (but under default 80)
  my $over_40 = 'my $var = "' . ("x" x 28) . '";';
  is length($over_40), 41, "Test string is 41 chars";
  bad $policy, $over_40, "Line over 40 characters violates with custom limit";

  # Test getter method
  is $policy->_get_max_line_length(), 40, "Custom max_line_length is 40";
};

subtest "Custom max_line_length = 120" => sub {
  my $policy = Perl::Critic::Policy::CodeLayout::LimitLineLength->new();
  $policy->{_max_line_length} = 120;

  # Test line that would violate default 80 but is OK with 120
  my $line_100 = 'my $var = "' . ("x" x 87) . '";';
  is length($line_100), 100, "Test string is 100 chars";
  good $policy, $line_100, "Line under 120 chars with custom limit";

  # Test line over 120 chars
  my $over_120 = 'my $var = "' . ("x" x 108) . '";';
  is length($over_120), 121, "Test string is 121 chars";
  bad $policy, $over_120, "Line over 120 characters violates";

  # Test getter method
  is $policy->_get_max_line_length(), 120, "Custom max_line_length is 120";
};

subtest "Very short custom limit" => sub {
  my $policy = Perl::Critic::Policy::CodeLayout::LimitLineLength->new();
  $policy->{_max_line_length} = 10;

  # Even short lines violate with very short limit
  bad $policy, 'my $x = 1; ', "Normal line violates 10-char limit";

  # Very short line is OK
  good $policy, 'my $x=1', "Compact line within 10 chars";

  # Test getter method
  is $policy->_get_max_line_length(), 10, "Custom max_line_length is 10";
};

subtest "Default behavior when no configuration set" => sub {
  my $policy = Perl::Critic::Policy::CodeLayout::LimitLineLength->new();

  # Should use default of 80
  is $policy->_get_max_line_length(), 80, "Default max_line_length is 80";

  # Test with 80-char line
  my $exactly_80 = 'my $var = "' . ("x" x 67) . '";';
  good $policy, $exactly_80, "80-char line OK with default";

  # Test with 81-char line
  my $over_80 = 'my $var = "' . ("x" x 68) . '";';
  bad $policy, $over_80, "81-char line violates default";
};

done_testing;
