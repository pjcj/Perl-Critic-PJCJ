#!/usr/bin/env perl

use v5.20.0;
use strict;
use warnings;
use feature "signatures";

use Test2::V0;

no warnings "experimental::signatures";

# Test the policy directly without using Perl::Critic framework
use lib qw( lib t/lib );
use Perl::Critic::Policy::CodeLayout::LimitLineLength;
use ViolationFinder qw(find_violations);

my $Policy = Perl::Critic::Policy::CodeLayout::LimitLineLength->new;

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
  is @themes,    2,            "default_themes returns two themes";
  is $themes[0], "cosmetic",   "first theme is cosmetic";
  is $themes[1], "formatting", "second theme is formatting";

  # Test applies_to
  my @types = $Policy->applies_to;
  is @types,    1,               "applies_to returns one type";
  is $types[0], "PPI::Document", "applies_to returns PPI::Document";

  # Test default configuration
  is $Policy->_get_max_line_length(), 80, "default max_line_length is 80";
};

subtest "Basic functionality" => sub {
  # Test lines within limit
  good 'my $x = "hello"', "Short line within 80 chars";
  good 'my $short = 1',   "Very short line";
  good "",                "Empty string";
  good "\n",              "Just newline";

  # Test lines exactly at limit (80 chars)
  my $exactly_80 = 'my $var = "' . ("x" x 67) . '";';
  is length($exactly_80), 80, "Test string is exactly 80 chars";
  good $exactly_80, "Line exactly at 80 characters";

  # Test lines over limit
  my $over_80 = 'my $var = "' . ("x" x 68) . '";';
  is length($over_80), 81, "Test string is 81 chars";
  bad $over_80, "Line over 80 characters should violate";
};

subtest "Multiple lines" => sub {
  # Multiple short lines - all good
  good qq(my \$x = "hello";\nmy \$y = "world";), "Multiple short lines";

  # Multiple long lines - all bad
  my $code
    = qq(my \$very_long_variable_name = "this is a very long string that exceeds eighty chars";\nmy \$another_long_variable = "this is another very long string that also exceeds eighty chars";);
  count_violations($code, 2, "Multiple long lines both violate");

  # Mixed lines - only long ones violate
  my $mixed
    = qq(my \$short = 1;\nmy \$very_long_variable_name = "this is a very long string that exceeds eighty chars";\nmy \$also_short = 2;);
  count_violations($mixed, 1, "Only long line in mixed content violates");
};

subtest "Edge cases" => sub {
  # Empty file
  good "", "Empty file";

  # Just whitespace
  good "   ",  "Whitespace only";
  good "\t\t", "Tabs only";

  # Very long line
  my $very_long = 'my $x = ' . ('"' . "a" x 200 . '"') . ';';
  bad $very_long, "Very long line (200+ chars) violates";

  # Line with exactly 81 characters (one over limit)
  my $line_81 = "a" x 81;
  is length($line_81), 81, "Test string is exactly 81 chars";
  bad $line_81, "Line with exactly 81 characters violates";
};

subtest "Configuration parameter handling" => sub {
  # Test supported_parameters method
  my @params = $Policy->supported_parameters();
  is @params, 1, "One supported parameter";

  my $param = $params[0];
  is $param->{name}, "max_line_length",    "Parameter name is max_line_length";
  is $param->{default_string},  "80",      "Default value is 80";
  is $param->{behavior},        "integer", "Parameter type is integer";
  is $param->{integer_minimum}, 1,         "Minimum value is 1";
};

done_testing;
