#!/usr/bin/env perl

use v5.26.0;
use strict;
use warnings;

use Test2::V0    qw( done_testing is like subtest warning );
use feature      qw( signatures );
use experimental qw( signatures );

use lib                       qw( lib t/lib );
use FakePolicy                ();
use Perl::Critic::PJCJ::Fixer ();

sub fixer ($flags, $description) {
  my $fixer = Perl::Critic::PJCJ::Fixer->new;
  $fixer->{policy}
    = FakePolicy->new(flags => $flags, description => $description);
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

subtest "Unmapped descriptions warn" => sub {
  my $out;
  like warning {
    $out = fixer("PPI::Statement::Include", "use say")->fix('use Foo "a";')
  }, qr/no fix mapping for 'use say' at line 1/,
    "an unmapped description warns";
  is $out, 'use Foo "a";', "and the source is unchanged";
};

subtest "Include descriptions without matching structure" => sub {
  is fixer("PPI::Statement::Include", "use ''")->fix('use Foo "a";'),
    'use Foo "a";', "a non-operator include explanation declines";
  is fixer("PPI::Statement::Include", "use q()")->fix('use Foo "a";'),
    'use Foo "a";', "a non-qw operator include explanation declines";
  is fixer("PPI::Statement::Include", "use qw()")->fix("use Foo;"),
    "use Foo;", "a use statement without arguments declines";
  is fixer("PPI::Statement::Include", "use qw()")->fix("use"), "use",
    "a degenerate use statement passes through the fixer";
  is fixer("PPI::Statement::Include", "remove parentheses")->fix("use Foo;"),
    "use Foo;", "a use statement without parentheses declines";
  is fixer("PPI::Statement::Include", "remove parentheses")
    ->fix("use Foo ();"), "use Foo;",
    "empty parentheses are removed with their leading space";
  is fixer("PPI::Statement::Include", "remove parentheses")
    ->fix("use Foo();"), "use Foo;",
    "empty parentheses without a leading space are removed";
};

subtest "Replacements which do not preserve the value are declined" => sub {
  is fixer("PPI::Token::Quote::Single", "use qw()")->fix(q(my $x = ' ';)),
    q(my $x = ' ';), "a space cannot survive as a qw word";
};

subtest "Quote-sensitive escapes decline single-quote conversion" => sub {
  my $double = 'my $x = "\$a\FBAR";';
  is fixer("PPI::Token::Quote::Double", "use ''")->fix($double), $double,
    "a double-quoted string with \\F is not rewritten to single quotes";

  my $interp = 'my $x = qq(\$a\FBAR);';
  is fixer("PPI::Token::Quote::Interpolate", "use ''")->fix($interp),
    $interp, "a qq string with \\F is not rewritten to single quotes";

  my $plain = 'my $x = "\$aBAR";';
  is fixer("PPI::Token::Quote::Double", "use ''")->fix($plain),
    q(my $x = '$aBAR';), "escape-free content still converts to single quotes";
};

subtest "Interpolation-changing command fixes are declined" => sub {
  my $qx_single = q(my $out = qx'echo $$';);
  is fixer("PPI::Token::QuoteLike::Command", "use qx()")->fix($qx_single),
    $qx_single, "qx'' keeps its non-interpolating delimiter";

  is fixer("PPI::Token::QuoteLike::Command", "use qx()")
    ->fix('my $out = qx"echo $$";'), 'my $out = qx(echo $$);',
    "interpolating qx is still re-delimited";

  is fixer("PPI::Token::Quote::Single", "use qx()")->fix(q(my $x = 'a';)),
    q(my $x = 'a';), "a plain string does not become an interpolating command";
};

done_testing
