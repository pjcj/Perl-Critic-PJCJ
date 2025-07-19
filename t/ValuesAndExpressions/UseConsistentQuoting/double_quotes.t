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
use ViolationFinder qw(find_violations count_violations good bad);

my $Policy
  = Perl::Critic::Policy::ValuesAndExpressions::UseConsistentQuoting->new;

# Helper subs that use the common policy
sub good_code ($code, $description) {
  ViolationFinder::good($Policy, $code, $description);
}

sub check_message ($code, $expected_message, $description) {
  bad($Policy, $code, $expected_message, $description);
}

subtest "Double quoted strings" => sub {
  # Should NOT violate - appropriate use of double quotes
  good_code 'my $x = "hello"', "Double quoted simple string";
  good_code 'my $x = "It\'s a nice day"',
    "String with single quote needs double quotes";
  good_code 'my $x = "Hello $name"',
    "String with interpolation needs double quotes";

  # Mixed escaped and real interpolation
  good_code 'my $mixed = "\$a $b"',
    "Mixed escaped and real interpolation should stay double quotes";
};

subtest "Escaped special characters" => sub {
  # Should violate - escaped characters that should use single quotes
  check_message 'my $output = "Price: \$10"', "use ''",
    "Escaped dollar signs should use single quotes";
  check_message 'my $email = "\@domain"', "use ''",
    "Escaped at-signs should use single quotes";
  check_message 'my $quote = "\""', "use ''",
    "Escaped double quotes should use single quotes";
};

subtest "Interpolation with quotes" => sub {
  # Strings that interpolate and have quotes
  good_code 'my $text = "contains $var and \"quotes\""',
    "Double quotes with interpolation and quotes";
  good_code 'my $x = "string with $var and \"quotes\""',
    "Double quotes appropriate when string interpolates and has quotes";

  # Contains both single and double quotes
  good_code q(my $text = "contains 'single' quotes"),
    '"" appropriate when content has single quotes';
  good_code q[my $text = qq(contains 'both' and "quotes")],
    "qq() appropriate when content has both quote types";
};

done_testing;
