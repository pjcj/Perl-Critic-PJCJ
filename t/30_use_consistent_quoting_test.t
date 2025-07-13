#!/usr/bin/env perl

## no critic (ValuesAndExpressions::UseConsistentQuoting)

use v5.20.0;
use strict;
use warnings;
use feature "signatures";

use Test2::V0;

no warnings "experimental::signatures";

# Test the policy directly without using Perl::Critic framework
use lib qw( lib );
use Perl::Critic::Policy::ValuesAndExpressions::UseConsistentQuoting;

my $Policy = Perl::Critic::Policy::ValuesAndExpressions::UseConsistentQuoting->new;

# Create a mock PPI document for testing
use PPI;

sub test_code ($code, $expected_violations, $description) {

  my $doc = PPI::Document->new(\$code);
  my @violations;

  # Find all elements the policy applies to
  my @element_types = qw(
    PPI::Token::Quote::Single
    PPI::Token::Quote::Literal
    PPI::Token::Quote::Interpolate
    PPI::Token::QuoteLike::Words
    PPI::Token::QuoteLike::Command
    PPI::Token::QuoteLike::Regexp
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

subtest "Simple strings (from RequireDoubleQuotedStrings)" => sub {
  # Should violate
  test_code q{my $x = 'hello'}, 1, "Single quoted simple string violates";
  test_code q{my $x = 'world'}, 1, "Another simple string violates";
  test_code q{my $x = 'hello world'}, 1, "Simple string with space violates";

  # Should NOT violate
  test_code q{my $x = "hello"}, 0, "Double quoted simple string is OK";
  test_code q{my $x = 'user@domain.com'}, 0, "String with @ is OK with single quotes";
  test_code q{my $x = 'He said "hello"'}, 0, "String with double quotes is OK with single quotes";
  test_code q{my $x = 'It\'s a nice day'}, 0, "String with escaping is OK";

  # Multiple violations
  test_code q{
    my $x = 'hello';
    my $y = 'world';
    my $z = 'foo';
  }, 3, "Multiple simple strings all violate";

  # Mixed violations
  test_code q{
    my $x = 'hello';
    my $y = "world";
    my $z = 'user@example.com';
  }, 1, "Only simple single-quoted string violates";
};

subtest "Quote operators (from RequireOptimalQuoteDelimiters)" => sub {
  # qw() tests
  test_code q{my @x = qw{word(with)parens}}, 1, "qw{} with parens should use qw()";
  test_code q{my @x = qw(word(with)parens)}, 0, "qw() with parens is optimal";
  test_code q{my @x = qw{word[with]brackets}}, 1, "qw{} with brackets should use qw[]";
  test_code q{my @x = qw[word[with]brackets]}, 0, "qw[] with brackets is optimal";
  test_code q{my @x = qw{simple words}}, 0, "qw{} with no special chars is optimal";

  # q() tests
  test_code q{my $x = q{text(with)parens}}, 1, "q{} with parens should use q()";
  test_code q{my $x = q(text(with)parens)}, 0, "q() with parens is optimal";

  # qq() tests
  test_code q{my $x = qq{text[with]brackets}}, 1, "qq{} with brackets should use qq[]";
  test_code q{my $x = qq[text[with]brackets]}, 0, "qq[] with brackets is optimal";

  # qx() tests
  test_code q{my $x = qx{command[with]brackets}}, 1, "qx{} with brackets should use qx[]";
  test_code q{my $x = qx[command[with]brackets]}, 0, "qx[] with brackets is optimal";

  # qr() tests
  test_code q{my $x = qr{pattern[with]brackets}}, 1, "qr{} with brackets should use qr[]";
  test_code q{my $x = qr[pattern[with]brackets]}, 0, "qr[] with brackets is optimal";

  # Empty quotes should not violate
  test_code q{my @x = qw{}}, 0, "Empty qw{} is OK";
  test_code q{my @x = qw()}, 0, "Empty qw() is OK";
  test_code q{my @x = qw[]}, 0, "Empty qw[] is OK";

  # Complex cases with multiple delimiters
  test_code q{my @x = qw{has(parens)[and]{braces}}}, 0, "All delimiters present - any is OK";

  # Tie-breaking cases
  test_code q{my @x = qw{one[bracket}}, 1, "When tied, () is preferred over {}";
  test_code q{my @x = qw(one[bracket)}, 0, "() with one bracket is OK (tied with [])";
};

subtest "Combined tests" => sub {
  # Code with both types of violations
  my @violations = test_code q{
    my $simple = 'hello';
    my @words = qw{word(with)parens};
    my $ok = "world";
    my @ok_words = qw(more(parens));
  }, 2, "Code with both types of violations";

  # Check violation messages
  like $violations[0]->description, qr/consistent/, "First violation mentions consistency";
  like $violations[1]->description, qr/consistent/, "Second violation mentions consistency";
};

subtest "Edge cases" => sub {
  # Whitespace in quote operators
  test_code q{my @x = qw  {word(with)parens}}, 1, "qw with whitespace before delimiter";
  test_code q{my @x = qw	{word(with)parens}}, 1, "qw with tab before delimiter";

  # Different quote styles
  test_code q{my $x = q'simple'}, 0, "q'' is not checked (not in our delimiter list)";
  test_code q{my $x = q/simple/}, 0, "q// is not checked (not in our delimiter list)";
};

done_testing;