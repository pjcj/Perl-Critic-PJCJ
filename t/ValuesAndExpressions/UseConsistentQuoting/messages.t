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

sub test_violation ($code, $expected_desc, $expected_expl, $description) {
  my @violations = find_violations($Policy, $code);

  is @violations, 1, "$description - one violation";

  if (@violations) {
    my $v = $violations[0];
    is $v->description, $expected_desc, "$description - description matches";
    is $v->explanation, $expected_expl, "$description - explanation matches";
  }
}

sub delimiter_msg ($hint) {
  state $msg = "choose (), [], <> or {} delimiters that require the fewest "
    . "escape characters";
  return "$msg (hint: use $hint)";
}

subtest "Single quote violation messages" => sub {
  test_violation(
    q(my $x = 'hello'),
    "Use consistent and optimal quoting",
    "simple strings should use double quotes for consistency",
    "Simple single-quoted string"
  );

  test_violation(
    q(my $x = 'I\'m happy'),
    "Use consistent and optimal quoting",
    "use q() to avoid escaping single quotes",
    "Single quotes with escaped apostrophe"
  );
};

subtest "Double quote violation messages" => sub {
  test_violation(
    'my $output = "Price: \$10"',
    "Use consistent and optimal quoting",
    'Use single quotes for strings with escaped $ or @ to avoid escaping',
    "Double quotes with escaped dollar"
  );
};

subtest "q() operator violation messages" => sub {
  test_violation(
    'my $x = q(simple)',
    "Use consistent and optimal quoting",
    "simple strings should use double quotes for consistency",
    "q() with simple content"
  );

  test_violation(
    'my $x = q(literal$x)',
    "Use consistent and optimal quoting",
    "use '' instead of q()",
    "q() with literal dollar"
  );
};

subtest "qq() operator violation messages" => sub {
  test_violation(
    'my $x = qq(simple)',
    "Use consistent and optimal quoting",
    'use "" instead of qq()',
    "qq() with simple content"
  );
};

subtest "Delimiter optimisation messages with hints" => sub {
  test_violation(
    'my @x = qw(word(with)parens)',
    "Use consistent and optimal quoting",
    delimiter_msg("qw[]"), "qw() with parens - hint to use qw[]"
  );

  test_violation(
    'my @x = qw[word[with]brackets]',
    "Use consistent and optimal quoting",
    delimiter_msg("qw()"), "qw[] with brackets - hint to use qw()"
  );

  test_violation(
    'my @x = qw{word{with}braces}',
    "Use consistent and optimal quoting",
    delimiter_msg("qw()"), "qw{} with braces - hint to use qw()"
  );

  test_violation(
    'my @x = qw<word<with>angles>',
    "Use consistent and optimal quoting",
    delimiter_msg("qw()"), "qw<> with angles - hint to use qw()"
  );

  test_violation(
    'my @x = qw{simple words}',
    "Use consistent and optimal quoting",
    delimiter_msg("qw()"), "qw{} simple - hint to use qw()"
  );

  test_violation(
    'my $x = q(text(with)parens)',
    "Use consistent and optimal quoting",
    delimiter_msg("q[]"), "q() with parens - hint to use q[]"
  );

  test_violation(
    'my $x = qq[text[with]brackets]',
    "Use consistent and optimal quoting",
    delimiter_msg("qq()"), "qq[] with brackets - hint to use qq()"
  );
};

subtest "Exotic delimiter messages" => sub {
  test_violation(
    'my $text = q/path\/to\/file/',
    "Use consistent and optimal quoting",
    delimiter_msg("q()"),
    "q// with slashes - hint to use q()"
  );

  test_violation(
    'my $text = q|option\|value|',
    "Use consistent and optimal quoting",
    delimiter_msg("q()"), "q|| with pipes - hint to use q()"
  );

  test_violation(
    'my @x = qw/word\/with\/slashes/',
    "Use consistent and optimal quoting",
    delimiter_msg("qw()"),
    "qw// with slashes - hint to use qw()"
  );
};

subtest "Combined violation messages" => sub {
  my @violations = find_violations($Policy, <<~'CODE');
    my $simple = 'hello';
    my @words = qw{word(with)parens};
    my $ok = "world";
    my @ok_words = qw[more(parens)];
    CODE

  is @violations, 2, "Two violations in combined code";

  # Check that descriptions mention consistency
  like $violations[0]->description, qr(consistent),
    "First violation mentions consistency";
  like $violations[1]->description, qr(consistent),
    "Second violation mentions consistency";
};

done_testing;
