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
  bad q(my $x = 'hello'),       "Single quoted simple string";
  bad q(my $x = 'world'),       "Another simple string";
  bad q(my $x = 'hello world'), "Simple string with space";

  # Should NOT violate
  good q(my $x = "hello"),           "Double quoted simple string";
  good q(my $x = 'user@domain.com'), "String with @ using single quotes";
  good q(my $x = 'He said "hello"'),
    "String with double quotes using single quotes";
  good q(my $x = 'It\'s a nice day'), "String with escaping";

  # Multiple violations
  count_violations q(
    my $x = 'hello';
    my $y = 'world';
    my $z = 'foo';
  ), 3, "Multiple simple strings all violate";

  # Mixed violations
  count_violations q(
    my $x = 'hello';
    my $y = "world";
    my $z = 'user@example.com';
  ), 1, "Only simple single-quoted string violates";
};

subtest "Quote operators (from RequireOptimalQuoteDelimiters)" => sub {
  # Minimize escapes first - content with parens should avoid () delimiters
  bad q[my @x = qw(word(with)parens)],
    "qw() with parens should use qw[] to avoid escapes";
  good q{my @x = qw[word(with)parens]}, "qw[] with parens avoids escapes";
  bad q[my @x = qw{word(with)parens}],
    "qw{} with parens should use qw[] to avoid escapes";

  # Content with brackets should avoid [] delimiters
  bad q(my @x = qw[word[with]brackets]),
    "qw[] with brackets should use qw() to avoid escapes";
  good q{my @x = qw(word[with]brackets)}, "qw() with brackets avoids escapes";
  bad q(my @x = qw{word[with]brackets}),
    "qw{} with brackets should use qw() to avoid escapes";

  # Content with braces should avoid {} delimiters
  bad q(my @x = qw{word{with}braces}),
    "qw{} with braces should use qw() to avoid escapes";
  good q[my @x = qw(word{with}braces)], "qw() with braces avoids escapes";
  bad q(my @x = qw[word{with}braces]),
    "qw[] with braces should use qw() to avoid escapes";

  # Content with angles should avoid <> delimiters
  bad q{my @x = qw<word<with>angles>},
    "qw<> with angles should use qw() to avoid escapes";
  good q{my @x = qw(word<with>angles)}, "qw() with angles avoids escapes";
  bad q{my @x = qw[word<with>angles]},
    "qw[] with angles should use qw() to avoid escapes";
  bad q{my @x = qw{word<with>angles}},
    "qw{} with angles should use qw() to avoid escapes";

  # Simple content (no delimiters) should prefer () first
  bad q(my @x = qw{simple words}), "qw{} with no delimiters should use qw()";
  bad q(my @x = qw[simple words]), "qw[] with no delimiters should use qw()";
  bad q{my @x = qw<simple words>}, "qw<> with no delimiters should use qw()";
  good q[my @x = qw(simple words)], "qw() is preferred for simple content";

  # Other operators follow same rules
  bad q[my $x = q(text(with)parens)],
    "q() with parens should use q[] to avoid escapes";
  good q{my $x = q[text(with)parens]}, "q[] with parens avoids escapes";

  bad q(my $x = qq[text[with]brackets]),
    "qq[] with brackets should use qq() to avoid escapes";
  good q{my $x = qq(text[with]brackets)}, "qq() with brackets avoids escapes";

  bad q{my $x = qr<text<with>angles>},
    "qr<> with angles should use qr() to avoid escapes";
  good q{my $x = qr(text<with>angles)}, "qr() with angles avoids escapes";

  bad q(my $x = qx[command[with]brackets]),
    "qx[] with brackets should use qx() to avoid escapes";
  good q{my $x = qx(command[with]brackets)},
    "qx() with brackets avoids escapes";

  bad q(my $x = qr[pattern[with]brackets]),
    "qr[] with brackets should use qr() to avoid escapes";
  good q{my $x = qr(pattern[with]brackets)},
    "qr() with brackets avoids escapes";

  # Empty quotes should prefer () first
  bad q(my @x = qw{}), "Empty qw{} should use qw()";
  bad q(my @x = qw[]), "Empty qw[] should use qw()";
  good q[my @x = qw()], "Empty qw() is preferred";

  # When all delimiters appear in content, prefer () (least escapes needed)
  bad q(my @x = qw{has(parens)[and]{braces}}),
    "All delimiters present - should use qw()";
  bad q(my @x = qw[has(parens)[and]{braces}]),
    "All delimiters present - should use qw()";
  good q[my @x = qw(has(parens)[and]{braces})],
    "qw() preferred when all delimiters present";

  # Tie-breaking: when escape counts equal, prefer () over [] over <> over {}
  bad q(my @x = qw{one[bracket}), "When tied, () is preferred over {}";
  bad q{my @x = qw<one[bracket>}, "When tied, () is preferred over <>";
  bad q(my @x = qw[one[bracket]), "When tied, () is preferred over []";
  good q{my @x = qw(one[bracket])},
    "() is preferred when escape counts are tied";

  # Test [] vs <> vs {} preference order
  bad q{my @x = qw{one(paren}}, "When tied, [] is preferred over {}";
  bad q{my @x = qw<one(paren>}, "When tied, [] is preferred over <>";
  good q{my @x = qw[one(paren)]}, "[] is preferred over <> and {}";

  # Test <> vs {} preference order
  bad q{my @x = qw{one(paren)[bracket}}, "When tied, <> is preferred over {}";
  good q{my @x = qw<one(paren)[bracket>}, "<> is preferred over {}";

  # Content with only one type of delimiter that's not the preferred one
  good q{my @x = qw[text(only)parens]},
    "[] optimal when content has only parens";
  good q{my @x = qw(text[only]brackets)},
    "() optimal when content has only brackets";
  good q{my @x = qw<text<only>angles>},
    "<> optimal when content has only angles";
  good q[my @x = qw(text{only}braces)],
    "() optimal when content has only braces";
};

subtest "Combined tests" => sub {
  # Code with both types of violations
  my @violations = count_violations q[
    my $simple = 'hello';
    my @words = qw{word(with)parens};
    my $regex = qr<text<with>angles>;
    my $ok = "world";
    my @ok_words = qw[more(parens)];
    my $ok_regex = qr<good<angles>>;
  ], 3, "Code with multiple types of violations";

  # Check violation messages
  like $violations[0]->description, qr/consistent/,
    "First violation mentions consistency";
  like $violations[1]->description, qr/consistent/,
    "Second violation mentions consistency";
};

subtest "Edge cases" => sub {
  # Whitespace in quote operators
  bad q[my @x = qw  {word(with)parens}],
    "qw with whitespace before delimiter";
  bad q[my @x = qw  {word(with)parens}], "qw with tab before delimiter";

  # Different quote styles
  good q(my $x = q'simple'), "q'' is not checked (not in our delimiter list)";
  good q(my $x = q/simple/), "q// is not checked (not in our delimiter list)";
};

done_testing;
