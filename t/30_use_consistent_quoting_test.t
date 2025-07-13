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

my $Policy = Perl::Critic::Policy::ValuesAndExpressions::UseConsistentQuoting->new;

# Create a mock PPI document for testing
use PPI;

sub count_violations ($code, $expected_violations, $description) {
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

sub good ($code, $description) {
  count_violations($code, 0, $description);
}

sub bad ($code, $description) {
  count_violations($code, 1, $description);
}

subtest "Simple strings (from RequireDoubleQuotedStrings)" => sub {
  # Should violate
  bad q{my $x = 'hello'}, "Single quoted simple string";
  bad q{my $x = 'world'}, "Another simple string";
  bad q{my $x = 'hello world'}, "Simple string with space";

  # Should NOT violate
  good q{my $x = "hello"}, "Double quoted simple string";
  good q{my $x = 'user@domain.com'}, "String with @ using single quotes";
  good q{my $x = 'He said "hello"'}, "String with double quotes using single quotes";
  good q{my $x = 'It\'s a nice day'}, "String with escaping";

  # Multiple violations
  count_violations q{
    my $x = 'hello';
    my $y = 'world';
    my $z = 'foo';
  }, 3, "Multiple simple strings all violate";

  # Mixed violations
  count_violations q{
    my $x = 'hello';
    my $y = "world";
    my $z = 'user@example.com';
  }, 1, "Only simple single-quoted string violates";
};

subtest "Quote operators (from RequireOptimalQuoteDelimiters)" => sub {
  # qw() tests
  bad q{my @x = qw{word(with)parens}}, "qw{} with parens should use qw()";
  good q{my @x = qw(word(with)parens)}, "qw() with parens is optimal";
  bad q{my @x = qw{word[with]brackets}}, "qw{} with brackets should use qw[]";
  good q{my @x = qw[word[with]brackets]}, "qw[] with brackets is optimal";
  good q{my @x = qw{simple words}}, "qw{} with no special chars is optimal";

  # q() tests
  bad q{my $x = q{text(with)parens}}, "q{} with parens should use q()";
  good q{my $x = q(text(with)parens)}, "q() with parens is optimal";

  # qq() tests
  bad q{my $x = qq{text[with]brackets}}, "qq{} with brackets should use qq[]";
  good q{my $x = qq[text[with]brackets]}, "qq[] with brackets is optimal";

  # qx() tests
  bad q{my $x = qx{command[with]brackets}}, "qx{} with brackets should use qx[]";
  good q{my $x = qx[command[with]brackets]}, "qx[] with brackets is optimal";

  # qr() tests
  bad q{my $x = qr{pattern[with]brackets}}, "qr{} with brackets should use qr[]";
  good q{my $x = qr[pattern[with]brackets]}, "qr[] with brackets is optimal";

  # Empty quotes should not violate
  good q{my @x = qw{}}, "Empty qw{} is OK";
  good q{my @x = qw()}, "Empty qw() is OK";
  good q{my @x = qw[]}, "Empty qw[] is OK";

  # Complex cases with multiple delimiters
  good q{my @x = qw{has(parens)[and]{braces}}}, "All delimiters present - any is OK";

  # Tie-breaking cases
  bad q{my @x = qw{one[bracket}}, "When tied, () is preferred over {}";
  good q{my @x = qw(one[bracket)}, "() with one bracket is OK (tied with [])";
};

subtest "Combined tests" => sub {
  # Code with both types of violations
  my @violations = count_violations q{
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
  bad q{my @x = qw  {word(with)parens}}, "qw with whitespace before delimiter";
  bad q{my @x = qw	{word(with)parens}}, "qw with tab before delimiter";

  # Different quote styles
  good q{my $x = q'simple'}, "q'' is not checked (not in our delimiter list)";
  good q{my $x = q/simple/}, "q// is not checked (not in our delimiter list)";
};

done_testing;
