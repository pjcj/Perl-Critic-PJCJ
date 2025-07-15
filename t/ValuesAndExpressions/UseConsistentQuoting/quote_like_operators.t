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

  is scalar @violations, $expected_violations, $description;
  return @violations;
}

sub good ($code, $description) {
  count_violations($code, 0, $description);
}

sub bad ($code, $description) {
  count_violations($code, 1, $description);
}

subtest "qw() operator" => sub {
  # Simple content should use ()
  bad 'my @x = qw{simple words}', "qw{} with no delimiters should use qw()";
  bad 'my @x = qw[simple words]', "qw[] with no delimiters should use qw()";
  bad 'my @x = qw<simple words>', "qw<> with no delimiters should use qw()";
  good 'my @x = qw(simple words)', "qw() is preferred for simple content";
  
  # Empty quotes should prefer ()
  bad 'my @x = qw{}', "Empty qw{} should use qw()";
  bad 'my @x = qw[]', "Empty qw[] should use qw()";
  good 'my @x = qw()', "Empty qw() is preferred";
  
  # Non-bracket delimiters
  bad 'my @x = qw/word word/', "qw// should use qw() - brackets preferred";
  bad 'my @x = qw|word word|', "qw|| should use qw() - brackets preferred";
  bad 'my @x = qw#word word#', "qw## should use qw() - brackets preferred";
  good 'my @x = qw(word word)', "qw() uses preferred bracket delimiters";
  
  # With slashes and pipes
  bad 'my @words = qw/word\/with\/slashes/',
    "qw// with slashes should use qw() to avoid escapes";
  good 'my @words = qw(word/with/slashes)',
    "qw() optimal when words have slashes";
  
  bad 'my @words = qw|word\|with\|pipes|',
    "qw|| with pipes should use qw() to avoid escapes";
  good 'my @words = qw(word|with|pipes)',
    "qw() optimal when words have pipes";
  
  # Whitespace variations
  bad 'my @x = qw  {word(with)parens}', "qw with whitespace before delimiter";
  bad 'my @x = qw\t{word(with)parens}', "qw with tab before delimiter";
  bad 'my @x = qw     <simple words>',
    "qw<> with multiple spaces should use qw()";
};

subtest "qx() operator" => sub {
  # Simple commands
  bad 'my $output = qx[ls]', "qx[] for simple command should use qx()";
  bad 'my $output = qx{ls}', "qx{} for simple command should use qx()";
  bad 'my $output = qx<ls>', "qx<> for simple command should use qx()";
  good 'my $output = qx(ls)', "qx() is preferred for simple commands";
  
  # Commands with special characters
  bad 'my $output = qx/ls \/tmp/',
    "qx// with slashes should use qx() to avoid escapes";
  good 'my $output = qx(ls /tmp)', "qx() optimal when content has slashes";
  
  bad 'my $output = qx|echo \|pipe|',
    "qx|| with pipes should use qx() to avoid escapes";
  good 'my $output = qx(echo |pipe)', "qx() optimal when content has pipes";
  
  # With single quotes
  bad q(my $output = qx'echo \'hello\''),
    "qx'' with single quotes should use qx() to avoid escapes";
  good q[my $output = qx(echo 'hello')],
    "qx() optimal when content has single quotes";
};

done_testing;