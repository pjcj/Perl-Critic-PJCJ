#!/usr/bin/env perl

use v5.26.0;
use strict;
use warnings;

use Test2::V0    qw( done_testing is subtest );
use feature      qw( signatures );
use experimental qw( signatures );

use lib                       qw( lib t/lib );
use FakePolicy                ();
use Perl::Critic::PJCJ::Fixer ();

sub fixer ($flags, $explanation) {
  my $fixer = Perl::Critic::PJCJ::Fixer->new;
  $fixer->{policy}
    = FakePolicy->new(flags => $flags, explanation => $explanation);
  $fixer
}

subtest "Class and explanation pairs the policy cannot produce" => sub {
  my @cases = (
    ["PPI::Token::Quote::Single",  "use ''",             q(my $x = 'a';)],
    ["PPI::Token::Quote::Double",  'use ""',             'my $x = "a";'],
    ["PPI::Token::Quote::Literal", "remove parentheses", 'my $x = q(a);'],
    [
      "PPI::Token::Quote::Interpolate",
      "remove parentheses",
      'my $x = qq(a);',
    ],
    ["PPI::Token::QuoteLike::Words", "use ''", 'my @w = qw( a );'],
  );
  for my $case (@cases) {
    my ($class, $expl, $code) = @$case;
    is fixer($class, $expl)->fix($code), $code, "$class with $expl declines";
  }
};

subtest "Include explanations without matching structure" => sub {
  is fixer("PPI::Statement::Include", "use say")->fix('use Foo "a";'),
    'use Foo "a";', "an unknown include explanation declines";
  is fixer("PPI::Statement::Include", "use ''")->fix('use Foo "a";'),
    'use Foo "a";', "a non-operator include explanation declines";
  is fixer("PPI::Statement::Include", "use q()")->fix('use Foo "a";'),
    'use Foo "a";', "a non-qw operator include explanation declines";
  is fixer("PPI::Statement::Include", "use qw()")->fix("use Foo;"),
    "use Foo;", "a use statement without arguments declines";
  is fixer("PPI::Statement::Include", "remove parentheses")->fix("use Foo;"),
    "use Foo;", "a use statement without parentheses declines";
  is fixer("PPI::Statement::Include", "remove parentheses")
    ->fix("use Foo ();"), "use Foo ;", "empty parentheses are removed";
};

subtest "Replacements which do not preserve the value are declined" => sub {
  is fixer("PPI::Token::Quote::Single", "use qw()")->fix(q(my $x = ' ';)),
    q(my $x = ' ';), "a space cannot survive as a qw word";
};

done_testing
