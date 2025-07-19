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
use ViolationFinder
  qw(find_violations count_violations good bad check_violation_message);

my $Policy
  = Perl::Critic::Policy::ValuesAndExpressions::UseConsistentQuoting->new;

# Helper subs that use the common policy
sub good_code ($code, $description) {
  ViolationFinder::good($Policy, $code, $description);
}

sub bad_code ($code, $description) {
  count_violations($Policy, $code, 1, $description);
}

sub check_message ($code, $expected_message, $description) {
  check_violation_message($Policy, $code, $expected_message, $description);
}

subtest "qw() operator" => sub {
  # Simple content should use ()
  check_message 'my @x = qw{simple words}', 'use qw()',
    "qw{} with no delimiters should use qw()";
  check_message 'my @x = qw[simple words]', 'use qw()',
    "qw[] with no delimiters should use qw()";
  check_message 'my @x = qw<simple words>', 'use qw()',
    "qw<> with no delimiters should use qw()";
  good_code 'my @x = qw(simple words)',
    "qw() is preferred for simple content";

  # Empty quotes should prefer ()
  check_message 'my @x = qw{}', 'use qw()', "Empty qw{} should use qw()";
  check_message 'my @x = qw[]', 'use qw()', "Empty qw[] should use qw()";
  good_code 'my @x = qw()', "Empty qw() is preferred";

  # Non-bracket delimiters
  check_message 'my @x = qw/word word/', 'use qw()',
    "qw// should use qw() - brackets preferred";
  check_message 'my @x = qw|word word|', 'use qw()',
    "qw|| should use qw() - brackets preferred";
  check_message 'my @x = qw#word word#', 'use qw()',
    "qw## should use qw() - brackets preferred";
  good_code 'my @x = qw(word word)', "qw() uses preferred bracket delimiters";

  # With slashes and pipes
  check_message 'my @words = qw/word\/with\/slashes/', 'use qw()',
    "qw// with slashes should use qw() to avoid escapes";
  good_code 'my @words = qw(word/with/slashes)',
    "qw() optimal when words have slashes";

  check_message 'my @words = qw|word\|with\|pipes|', 'use qw()',
    "qw|| with pipes should use qw() to avoid escapes";
  good_code 'my @words = qw(word|with|pipes)',
    "qw() optimal when words have pipes";

  # Whitespace variations
  check_message 'my @x = qw  {word(with)parens}', 'use qw[]',
    "qw with whitespace before delimiter";
  check_message 'my @x = qw\t{word(with)parens}', 'use qw[]',
    "qw with tab before delimiter";
  check_message 'my @x = qw     <simple words>', 'use qw()',
    "qw<> with multiple spaces should use qw()";
};

subtest "qx() operator" => sub {
  # Simple commands
  check_message 'my $output = qx[ls]', 'use qx()',
    "qx[] for simple command should use qx()";
  check_message 'my $output = qx{ls}', 'use qx()',
    "qx{} for simple command should use qx()";
  check_message 'my $output = qx<ls>', 'use qx()',
    "qx<> for simple command should use qx()";
  good_code 'my $output = qx(ls)', "qx() is preferred for simple commands";

  # Commands with special characters
  check_message 'my $output = qx/ls \/tmp/', 'use qx()',
    "qx// with slashes should use qx() to avoid escapes";
  good_code 'my $output = qx(ls /tmp)',
    "qx() optimal when content has slashes";

  check_message 'my $output = qx|echo \|pipe|', 'use qx()',
    "qx|| with pipes should use qx() to avoid escapes";
  good_code 'my $output = qx(echo |pipe)',
    "qx() optimal when content has pipes";

  # With single quotes
  check_message q(my $output = qx'echo \'hello\''), 'use qx()',
    "qx'' with single quotes should use qx() to avoid escapes";
  good_code q[my $output = qx(echo 'hello')],
    "qx() optimal when content has single quotes";
};

done_testing;
