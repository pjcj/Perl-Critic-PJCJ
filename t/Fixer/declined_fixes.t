#!/usr/bin/env perl

use v5.26.0;
use strict;
use warnings;

use Test2::V0    qw( done_testing is like subtest warning warnings );
use feature      qw( signatures );
use experimental qw( signatures );

use lib                       qw( lib t/lib );
use FakePolicy                ();
use Perl::Critic::PJCJ::Fixer ();
use Perl::Critic::Policy::ValuesAndExpressions::RequireConsistentQuoting qw(
  desc_double
  desc_optimal
  desc_remove_parens
  desc_single
  desc_use_qw
);

sub fixer ($flags, $description) {
  my $fixer = Perl::Critic::PJCJ::Fixer->new;
  $fixer->{policy}
    = FakePolicy->new(flags => $flags, description => $description);
  $fixer
}

sub fix_quietly ($flags, $description, $code) {
  my $out;
  warnings { $out = fixer($flags, $description)->fix($code) };
  $out
}

subtest "Class and explanation pairs the policy cannot produce" => sub {
  my @cases = (
    ["PPI::Token::Quote::Single",      desc_single,        q(my $x = 'a';)],
    ["PPI::Token::Quote::Double",      desc_double,        'my $x = "a";'],
    ["PPI::Token::Quote::Literal",     desc_remove_parens, 'my $x = q(a);'],
    ["PPI::Token::Quote::Interpolate", desc_remove_parens, 'my $x = qq(a);'],
    ["PPI::Token::QuoteLike::Words",   desc_single,        'my @w = qw( a );'],
  );
  for my $case (@cases) {
    my ($class, $expl, $code) = @$case;
    is fix_quietly($class, $expl, $code), $code, "$class with $expl declines";
  }
};

subtest "Unmapped descriptions warn" => sub {
  my $out;
  like warning {
    $out = fixer("PPI::Statement::Include", "use say")->fix('use Foo "a";')
  }, qr/no fix mapping for 'use say' at line 1/,
    "an unmapped description warns";
  is $out, 'use Foo "a";', "and the source is unchanged";

  my @w = warnings {
    fixer("PPI::Token::Quote::Single", "use say")
      ->fix(q(my $x = 'a'; my $y = 'b';))
  };
  is @w, 1, "the same unmapped description warns only once";
};

subtest "Include descriptions without matching structure" => sub {
  is fix_quietly("PPI::Statement::Include", desc_single, 'use Foo "a";'),
    'use Foo "a";', "a non-operator include explanation declines";
  is fix_quietly("PPI::Statement::Include", desc_optimal("q()"),
    'use Foo "a";'), 'use Foo "a";',
    "a non-qw operator include explanation declines";
  is fix_quietly("PPI::Statement::Include", desc_use_qw, "use Foo;"),
    "use Foo;", "a use statement without arguments declines";
  is fix_quietly("PPI::Statement::Include", desc_use_qw, "use"), "use",
    "a degenerate use statement passes through the fixer";
  is fix_quietly("PPI::Statement::Include", desc_remove_parens, "use Foo;"),
    "use Foo;", "a use statement without parentheses declines";
  is fix_quietly("PPI::Statement::Include", desc_remove_parens,
    "use Foo ();"), "use Foo;",
    "empty parentheses are removed with their leading space";
  is fix_quietly("PPI::Statement::Include", desc_remove_parens, "use Foo();"),
    "use Foo;", "empty parentheses without a leading space are removed";
};

subtest "Replacements which do not preserve the value are declined" => sub {
  is fix_quietly("PPI::Token::Quote::Single", desc_use_qw, q(my $x = ' ';)),
    q(my $x = ' ';), "a space cannot survive as a qw word";
};

subtest "Quote-sensitive escapes decline single-quote conversion" => sub {
  my $double = 'my $x = "\$a\FBAR";';
  is fix_quietly("PPI::Token::Quote::Double", desc_single, $double), $double,
    "a double-quoted string with \\F is not rewritten to single quotes";

  my $interp = 'my $x = qq(\$a\FBAR);';
  is fix_quietly("PPI::Token::Quote::Interpolate", desc_single, $interp),
    $interp, "a qq string with \\F is not rewritten to single quotes";

  my $plain = 'my $x = "\$aBAR";';
  is fix_quietly("PPI::Token::Quote::Double", desc_single, $plain),
    q(my $x = '$aBAR';), "escape-free content still converts to single quotes";
};

subtest "Interpolation-changing command fixes are declined" => sub {
  my $qx_single = q(my $out = qx'echo $$';);
  is fix_quietly(
    "PPI::Token::QuoteLike::Command",
    desc_optimal("qx()"), $qx_single,
    ),
    $qx_single, "qx'' keeps its non-interpolating delimiter";

  is fix_quietly(
    "PPI::Token::QuoteLike::Command", desc_optimal("qx()"),
    'my $out = qx"echo $$";',
    ),
    'my $out = qx(echo $$);', "interpolating qx is still re-delimited";

  is fix_quietly(
    "PPI::Token::Quote::Single", desc_optimal("qx()"), q(my $x = 'a';)
    ),
    q(my $x = 'a';), "a plain string does not become an interpolating command";
};

sub fix_words ($words, $code) {
  my $fixer = Perl::Critic::PJCJ::Fixer->new;
  $fixer->{policy} = FakePolicy->new(
    flags       => "PPI::Statement::Include",
    description => desc_use_qw,
    words       => $words,
  );
  my $out;
  warnings { $out = $fixer->fix($code) };
  $out
}

subtest "A qw insert which changes the word list is declined" => sub {
  is fix_words(["a b"], 'use Foo "a b";'), 'use Foo "a b";',
    "a word which re-parses as two words is not inserted";
  is fix_words(["a)"], 'use Foo "a)";'), 'use Foo "a)";',
    "a word which re-parses with different content is not inserted";
};

subtest "Declined fixes are reported" => sub {
  my $fixer = Perl::Critic::PJCJ::Fixer->new;
  my $code  = 'use Foo qw[ a\( ], $v;';
  my $out;
  like warning { $out = $fixer->fix($code, file => "demo.pl") },
    qr/cannot apply 'use qw\(\)' at line 1 of demo\.pl/,
    "a declined fix is reported";
  is $out, $code, "and the source is unchanged";
};

done_testing
