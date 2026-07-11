#!/usr/bin/env perl

use v5.26.0;
use strict;
use warnings;

use Test2::V0    qw( done_testing is ok subtest );
use feature      qw( signatures );
use experimental qw( signatures );

# Test the policy directly without using Perl::Critic framework
use lib qw( lib t/lib );
use Perl::Critic::Policy::ValuesAndExpressions::RequireConsistentQuoting ();
use ViolationFinder qw( find_violations );

my $Policy
  = Perl::Critic::Policy::ValuesAndExpressions::RequireConsistentQuoting->new;

subtest "Plain quote explanations" => sub {
  is $Policy->fix_data('use ""'), { type => "double" },
    'use "" maps to double';
  is $Policy->fix_data("use ''"), { type => "single" },
    "use '' maps to single";
};

subtest "Use statement explanations" => sub {
  is $Policy->fix_data("remove parentheses"), { type => "remove_parens" },
    "remove parentheses maps to remove_parens";
};

subtest "Operator explanations" => sub {
  is $Policy->fix_data("use qw()"),
    { type => "operator", op => "qw", start => "(", end => ")" },
    "use qw() carries operator and delimiters";
  is $Policy->fix_data("use q[]"),
    { type => "operator", op => "q", start => "[", end => "]" },
    "use q[] carries operator and delimiters";
  is $Policy->fix_data("use qq<>"),
    { type => "operator", op => "qq", start => "<", end => ">" },
    "use qq<> carries operator and delimiters";
  is $Policy->fix_data("use qx{}"),
    { type => "operator", op => "qx", start => "{", end => "}" },
    "use qx{} carries operator and delimiters";
};

subtest "Unknown explanations" => sub {
  is $Policy->fix_data("use say"), undef,
    "an unknown explanation returns undef";
};

subtest "Every emitted explanation has fix data" => sub {
  my @snippets = (
    q(my $x = 'hello'),
    'my $output = "Price: \$10"',
    'my @x = qw{simple words}',
    'my @x = qw(word(with)parens)',
    'my $x = qq(simple)',
    'use Foo "a1", "a2";',
    'use Qux ( key => "value" );',
  );
  for my $code (@snippets) {
    for my $violation (find_violations($Policy, $code)) {
      my $expl = $violation->explanation;
      ok $Policy->fix_data($expl), "fix data exists for $expl";
    }
  }
};

done_testing;
