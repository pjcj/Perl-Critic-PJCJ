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

subtest "Simple strings (prefer double quotes for interpolation)" => sub {
  # Should violate - single quotes for simple strings that could be interpolated
  bad q(my $x = 'hello'),       "Single quoted simple string should use double quotes";
  bad q(my $x = 'world'),       "Another simple string should use double quotes";
  bad q(my $x = 'hello world'), "Simple string with space should use double quotes";
  bad q(my $x = q(simple)),     "q() simple string should use double quotes";

  # Should NOT violate - appropriate use of quotes
  good q(my $x = "hello"),           "Double quoted simple string";
  good q(my $x = 'user@domain.com'), "String with literal @ using single quotes";
  good q(my $x = 'He said "hello"'),
    "String with double quotes using single quotes";
  good q(my $x = "It's a nice day"), "String with single quote needs double quotes";
  good q(my $x = "Hello $name"),     "String with interpolation needs double quotes";
  good q(my $x = 'literal$var'),    "String with literal \$ using single quotes";
  good q[my $x = qq(contains 'both' and "quotes")], "Complex content may need qq() delimiters";

  # Multiple violations
  count_violations q(
    my $x = 'hello';
    my $y = 'world';
    my $z = 'foo';
  ), 3, "Multiple simple single-quoted strings all violate";

  # Mixed violations
  count_violations q(
    my $x = 'hello';
    my $y = "world";
    my $z = 'user@example.com';
  ), 1, "Only simple single-quoted string violates";
};

subtest "Quote operators" => sub {
  # Minimize escapes first - content with parens should avoid () delimiters
  bad q[my @x = qw(word(with)parens)],
    "qw() with parens should use qw[] to avoid escapes";
  good q<my @x = qw[word(with)parens]>, "qw[] with parens avoids escapes";
  bad q[my @x = qw{word(with)parens}],
    "qw{} with parens should use qw[] to avoid escapes";

  # Content with brackets should avoid [] delimiters
  bad q(my @x = qw[word[with]brackets]),
    "qw[] with brackets should use qw() to avoid escapes";
  good q<my @x = qw(word[with]brackets)>, "qw() with brackets avoids escapes";
  bad q(my @x = qw{word[with]brackets}),
    "qw{} with brackets should use qw() to avoid escapes";

  # Content with braces should avoid {} delimiters
  bad q(my @x = qw{word{with}braces}),
    "qw{} with braces should use qw() to avoid escapes";
  good q[my @x = qw(word{with}braces)], "qw() with braces avoids escapes";
  bad q(my @x = qw[word{with}braces]),
    "qw[] with braces should use qw() to avoid escapes";

  # Content with angles should avoid <> delimiters
  bad q(my @x = qw<word<with>angles>),
    "qw<> with angles should use qw() to avoid escapes";
  good q[my @x = qw(word<with>angles)], "qw() with angles avoids escapes";
  bad q(my @x = qw[word<with>angles]),
    "qw[] with angles should use qw() to avoid escapes";
  bad q(my @x = qw{word<with>angles}),
    "qw{} with angles should use qw() to avoid escapes";

  # Simple content (no delimiters) should prefer () first
  bad q(my @x = qw{simple words}), "qw{} with no delimiters should use qw()";
  bad q(my @x = qw[simple words]), "qw[] with no delimiters should use qw()";
  bad q(my @x = qw<simple words>), "qw<> with no delimiters should use qw()";
  good q[my @x = qw(simple words)], "qw() is preferred for simple content";

  # Other operators follow same rules
  bad q[my $x = q(text(with)parens)],
    "q() with parens should use q[] to avoid escapes";
  good q<my $x = q[text(with)parens]>, "q[] with parens avoids escapes";

  bad q(my $x = qq[text[with]brackets]),
    'qq[] with brackets should use "" to avoid escapes';
  good q<my $x = "text[with]brackets">, "qq() with brackets avoids escapes";


  bad q(my $x = qx[command[with]brackets]),
    "qx[] with brackets should use qx() to avoid escapes";
  good q<my $x = qx(command[with]brackets)>,
    "qx() with brackets avoids escapes";


  # Empty quotes should prefer () first
  bad q(my @x = qw{}), "Empty qw{} should use qw()";
  bad q(my @x = qw[]), "Empty qw[] should use qw()";
  good q[my @x = qw()], "Empty qw() is preferred";

  # When all delimiters appear in content, prefer () (least escapes needed)
  bad q(my @x = qw{has(parens)[and]<angles>{braces}}),
    "All delimiters present - should use qw()";
  bad q(my @x = qw[has(parens)[and]<angles>{braces}]),
    "All delimiters present - should use qw()";
  bad q(my @x = qw<has(parens)[and]<angles>{braces}>),
    "All delimiters present - should use qw()";
  good q[my @x = qw(has(parens)[and]<angles>{braces})],
    "qw() preferred when all delimiters present";

  # Tie-breaking: when escape counts equal, prefer () over [] over <> over {}
  bad q(my @x = qw{one[bracket}), "When tied, () is preferred over {}";
  bad q(my @x = qw<one[bracket>), "When tied, () is preferred over <>";
  bad q(my @x = qw[one[bracket]), "When tied, () is preferred over []";
  good q<my @x = qw(one[bracket])>,
    "() is preferred when escape counts are tied";

  # Test [] vs <> vs {} preference order
  bad q[my @x = qw{one(paren}], "When tied, [] is preferred over {}";
  bad q[my @x = qw<one(paren>], "When tied, [] is preferred over <>";
  good q<my @x = qw[one(paren)]>, "[] is preferred over <> and {}";

  # Test <> vs {} preference order
  bad q<my @x = qw{one(paren)[bracket}>, "When tied, <> is preferred over {}";
  good q{my @x = qw<one(paren)[bracket>}, "<> is preferred over {}";

  # Content with only one type of delimiter that's not the preferred one
  good q<my @x = qw[text(only)parens]>,
    "[] optimal when content has only parens";
  good q<my @x = qw(text[only]brackets)>,
    "() optimal when content has only brackets";
  bad q(my @x = qw<text<only>angles>),
    "qw<> with angles should use qw() - fewer escapes";
  good q[my @x = qw(text<only>angles)],
    "() optimal when content has angles";
  good q[my @x = qw(text{only}braces)],
    "() optimal when content has only braces";

  # Test exotic delimiters - these should be violations when content conflicts
  subtest "Exotic delimiters" => sub {
    bad q(my $text = qq/path\/to\/file/),
      "qq// with slashes should use qq() to avoid escapes";
    good q[my $text = qq(path"to"file)],
      "qq() optimal when content has double quotes";
    bad q(my $text = q|option\|value|),
      "q|| with pipes should use q() to avoid escapes";
    good q[my $text = q(option|value)],
      "q() optimal when content has pipes";
    bad q(my $text = q"say \"hello\""),
      'q"" with quotes should use q() to avoid escapes';
    good q[my $text = q(say "hello")],
      "q() optimal when content has quotes";
    bad q(my $output = qx'echo \'hello\''),
      "qx'' with single quotes should use qx() to avoid escapes";
    good q[my $output = qx(echo 'hello')],
      "qx() optimal when content has single quotes";
    bad q(my $text = q#path\#to\#file#),
      "q## with hashes should use q() to avoid escapes";
    good q[my $text = q(path#to#file)],
      "q() optimal when content has hashes";
    bad q(my $text = q!wow\!amazing!),
      "q!! with exclamation marks should use q() to avoid escapes";
    good q[my $text = q(wow!amazing)],
      "q() optimal when content has exclamation marks";
    bad q(my $text = q%100\%complete%),
      "q%% with percent signs should use q() to avoid escapes";
    good q[my $text = q(100%complete)],
      "q() optimal when content has percent signs";
    bad q(my $text = q&fish\&chips&),
      "q&& with ampersands should use q() to avoid escapes";
    good q[my $text = q(fish&chips)],
      "q() optimal when content has ampersands";
    bad q(my $text = q~home\~user~),
      "q~~ with tildes should use q() to avoid escapes";
    good q[my $text = q(home~user)],
      "q() optimal when content has tildes";
  };
};

subtest "Combined tests" => sub {
  # Code with both types of violations
  my @violations = count_violations q[
    my $simple = 'hello';
    my @words = qw{word(with)parens};
    my $ok = "world";
    my @ok_words = qw[more(parens)];
  ], 2, "Code with multiple types of violations";

  # Check violation messages
  like $violations[0]->description, qr(consistent),
    "First violation mentions consistency";
  like $violations[1]->description, qr(consistent),
    "Second violation mentions consistency";
};

subtest "Edge cases" => sub {
  # Whitespace in quote operators
  bad q[my @x = qw  {word(with)parens}],
    "qw with whitespace before delimiter";
  bad q[my @x = qw  {word(with)parens}], "qw with tab before delimiter";

  # Different quote styles - prefer "" to qq and '' to q
  bad q(my $x = qq'simple'), "qq'' should use double quotes for simple content";
  bad q(my $x = qq/simple/), "qq// should use double quotes for simple content";
  bad q(my $x = qq(simple)), "qq() should use double quotes for simple content";
  bad q(my $x = q'simple'), "q'' should use double quotes for simple content";
  bad q(my $x = q/simple/), "q// should use double quotes for simple content";
  bad q(my $x = q(simple)), "q() should use double quotes for simple content";
};

subtest "Priority rules" => sub {
  # Rule 1: Always prefer interpolating quotes unless strings should not be interpolated
  bad q(my $x = 'simple'),      "Simple string should use double quotes";
  good q(my $x = "simple"),     "Simple string with double quotes";
  good q(my $x = 'literal$var'), 'String with literal $ should use single quotes';
  good q(my $x = 'literal@var'), 'String with literal @ should use single quotes';

  # Rule 2: Always prefer fewer escaped characters
  bad q(my $text = q/path\/to\/file/), 'q// with slashes should use "" to avoid escapes';
  good q(my $text = "path/to/file"),  '"" optimal when content has slashes';

  # Various quote operators with escaped characters
  bad q(my $text = q|option\|value|), 'q|| with pipes should use "" to avoid escapes';
  good q(my $text = "option|value"), '"" optimal when content has pipes';

  bad q(my $text = q#path\#to\#file#), 'q## with hashes should use "" to avoid escapes';
  good q(my $text = "path#to#file"), '"" optimal when content has hashes';

  bad q(my $text = q!wow\!amazing!), 'q!! with exclamation should use "" to avoid escapes';
  good q(my $text = "wow!amazing"), '"" optimal when content has exclamation';

  bad q(my $text = q%100\%complete%), 'q%% with percent should use "" to avoid escapes';
  good q(my $text = "100%complete"), '"" optimal when content has percent';

  bad q(my $text = q&fish\&chips&), 'q&& with ampersand should use "" to avoid escapes';
  good q(my $text = "fish&chips"), '"" optimal when content has ampersand';

  bad q(my $text = q~home\~user~), 'q~~ with tilde should use "" to avoid escapes';
  good q(my $text = "home~user"), '"" optimal when content has tilde';

  # qq operators with escaped characters
  bad q(my $text = qq/path\/to\/file/), 'qq// with slashes should use "" to avoid escapes';
  good q(my $text = "path/to/file"), '"" optimal for interpolated strings with slashes';

  bad q(my $text = qq|option\|value|), 'qq|| with pipes should use "" to avoid escapes';
  good q(my $text = "option|value"), '"" optimal for interpolated strings with pipes';

  # qx operators with escaped characters
  bad q(my $output = qx/ls \/tmp/), 'qx// with slashes should use qx() to avoid escapes';
  good q(my $output = qx(ls /tmp)), 'qx() optimal when content has slashes';

  bad q(my $output = qx|echo \|pipe|), 'qx|| with pipes should use qx() to avoid escapes';
  good q(my $output = qx(echo |pipe)), 'qx() optimal when content has pipes';


  # qw operators with various escaped characters
  bad q(my @words = qw/word\/with\/slashes/), 'qw// with slashes should use qw() to avoid escapes';
  good q(my @words = qw(word/with/slashes)), 'qw() optimal when words have slashes';

  bad q(my @words = qw|word\|with\|pipes|), 'qw|| with pipes should use qw() to avoid escapes';
  good q(my @words = qw(word|with|pipes)), 'qw() optimal when words have pipes';

  # Mixed content - choose delimiter that minimizes total escapes
  bad q(my $text = q/has\/slashes(and)parens/), 'q// should use q[] - fewer total escapes';
  good q(my $text = q[has/slashes(and)parens]), 'q[] optimal - avoids escaping parens, allows slashes';

  bad q(my $text = q(has(parens)\/and\/slashes)), 'q() should use "" - fewer total escapes';
  good q(my $text = "has(parens)/and/slashes/"), '"" optimal - avoids escaping slashes, allows parens';

  # String literals vs quote operators - prefer simpler forms when no escapes needed
  bad q(my $text = q(simple)), 'q() should use "" for simple content';
  good q(my $text = "simple"), '"" preferred over q() for simple content';

  bad q(my $text = q(literal)), 'q() should use "" for literal content';
  good q(my $text = "literal"), '"" preferred over q() for literal content';

  # When content has quotes, use appropriate delimiter
  good q(my $text = 'contains "double" quotes'), '\'\' appropriate when content has double quotes';
  good q(my $text = "contains 'single' quotes"), '"" appropriate when content has single quotes';
  good q(my $text = qq(contains 'both' and "quotes")), 'qq() appropriate when content has both quote types';

  # Rule 3: Prefer "" to qq
  bad q(my $x = qq(simple)),    "qq() should use double quotes for simple content";
  good q(my $x = "simple"),     "Double quotes preferred over qq()";
  bad q(my $x = qq/hello/),     "qq// should use double quotes";

  # Rule 4: Prefer '' to q
  bad q(my $x = q(literal$x)),    "q() should use single quotes for literal content";
  good q(my $x = 'literal$x'),    "Single quotes preferred over q()";
  bad q(my $x = q/literal$x/),    "q// should use single quotes";

  # Rule 5: Prefer bracketed delimiters in order (), [], <>, {}
  bad q(my @x = qw/word word/), "qw// should use qw() - brackets preferred";
  bad q(my @x = qw|word word|), "qw|| should use qw() - brackets preferred";
  bad q(my @x = qw#word word#), "qw## should use qw() - brackets preferred";
  good q(my @x = qw(word word)), "qw() uses preferred bracket delimiters";

  # Bracket priority: () > [] > <> > {}
  bad q(my @x = qw{simple words}), "qw{} should use qw() - () preferred over {}";
  bad q(my @x = qw<simple words>), "qw<> should use qw() - () preferred over <>";
  bad q(my @x = qw[simple words]), "qw[] should use qw() - () preferred over []";
  good q(my @x = qw(simple words)), "qw() is most preferred bracket delimiter";
};

done_testing;
