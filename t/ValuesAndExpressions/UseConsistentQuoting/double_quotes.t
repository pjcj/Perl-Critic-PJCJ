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

subtest "Double quoted strings" => sub {
  # Should NOT violate - appropriate use of double quotes
  good 'my $x = "hello"', "Double quoted simple string";
  good 'my $x = "It\'s a nice day"',
    "String with single quote needs double quotes";
  good 'my $x = "Hello $name"',
    "String with interpolation needs double quotes";

  # Mixed escaped and real interpolation
  good 'my $mixed = "\$a $b"',
    "Mixed escaped and real interpolation should stay double quotes";
};

subtest "Escaped special characters" => sub {
  # Should violate - escaped characters that should use single quotes
  bad 'my $output = "Price: \$10"',
    "Escaped dollar signs should use single quotes";
  bad 'my $email = "\@domain"', "Escaped at-signs should use single quotes";
};

subtest "Interpolation with quotes" => sub {
  # Strings that interpolate and have quotes
  good q(my $text = "contains $var and \"quotes\""),
    "Double quotes with interpolation and quotes";
  good q(my $x = "string with $var and \"quotes\""),
    "Double quotes appropriate when string interpolates and has quotes";

  # Contains both single and double quotes
  good q(my $text = "contains 'single' quotes"),
    '"" appropriate when content has single quotes';
  good q[my $text = qq(contains 'both' and "quotes")],
    "qq() appropriate when content has both quote types";
};

done_testing;
