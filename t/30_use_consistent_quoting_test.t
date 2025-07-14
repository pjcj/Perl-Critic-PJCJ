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
  bad q(my $x = 'hello'),
    "Single quoted simple string should use double quotes";
  bad q(my $x = 'world'), "Another simple string should use double quotes";
  bad q(my $x = 'hello world'),
    "Simple string with space should use double quotes";
  bad 'my $x = q(simple)', "q() simple string should use double quotes";

  # Should NOT violate - appropriate use of quotes
  good 'my $x = "hello"', "Double quoted simple string";
  good q(my $x = 'user@domain.com'),
    "String with literal @ using single quotes";
  good q(my $x = 'He said "hello"'),
    "String with double quotes using single quotes";
  good q(my $x = "It's a nice day"),
    "String with single quote needs double quotes";
  good 'my $x = "Hello $name"',
    "String with interpolation needs double quotes";
  good q(my $x = 'literal$var'), 'String with literal $ using single quotes';
  good q[my $x = qq(contains 'both' and "quotes")],
    "Complex content may need qq() delimiters";

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

  # Test cases for escaped characters - should recommend better quoting
  bad q(my $x = 'I\'m happy'),
    "Escaped single quotes should use q() to avoid escapes";
  bad 'my $output = "Price: \$10"',
    "Escaped dollar signs should use single quotes";
  bad 'my $email = "\@domain"', "Escaped at-signs should use single quotes";
  good 'my $mixed = "\$a $b"',
    "Mixed escaped and real interpolation should stay double quotes";

  # Test case for literal $ that should use single quotes
  good q(my $text = 'A $ here'), 'Literal $ should use single quotes';
};

subtest "Quote operators" => sub {
  # Minimise escapes first - content with parens should avoid () delimiters
  bad 'my @x = qw(word(with)parens)',
    "qw() with parens should use qw[] to avoid escapes";
  good 'my @x = qw[word(with)parens]', "qw[] with parens avoids escapes";
  bad 'my @x = qw{word(with)parens}',
    "qw{} with parens should use qw[] to avoid escapes";

  # Content with brackets should avoid [] delimiters
  bad 'my @x = qw[word[with]brackets]',
    "qw[] with brackets should use qw() to avoid escapes";
  good 'my @x = qw(word[with]brackets)', "qw() with brackets avoids escapes";
  bad 'my @x = qw{word[with]brackets}',
    "qw{} with brackets should use qw() to avoid escapes";

  # Content with braces should avoid {} delimiters
  bad 'my @x = qw{word{with}braces}',
    "qw{} with braces should use qw() to avoid escapes";
  good 'my @x = qw(word{with}braces)', "qw() with braces avoids escapes";
  bad 'my @x = qw[word{with}braces]',
    "qw[] with braces should use qw() to avoid escapes";

  # Content with angles should avoid <> delimiters
  bad 'my @x = qw<word<with>angles>',
    "qw<> with angles should use qw() to avoid escapes";
  good 'my @x = qw(word<with>angles)', "qw() with angles avoids escapes";
  bad 'my @x = qw[word<with>angles]',
    "qw[] with angles should use qw() to avoid escapes";
  bad 'my @x = qw{word<with>angles}',
    "qw{} with angles should use qw() to avoid escapes";

  # Simple content (no delimiters) should prefer () first
  bad 'my @x = qw{simple words}', "qw{} with no delimiters should use qw()";
  bad 'my @x = qw[simple words]', "qw[] with no delimiters should use qw()";
  bad 'my @x = qw<simple words>', "qw<> with no delimiters should use qw()";
  good 'my @x = qw(simple words)', "qw() is preferred for simple content";

  # Other operators follow same rules
  bad 'my $x = q(text(with)parens)',
    "q() with parens should use q[] to avoid escapes";
  good 'my $x = q[text(with)parens]', "q[] with parens avoids escapes";

  bad 'my $x = qq[text[with]brackets]',
    'qq[] with brackets should use "" to avoid escapes';
  good 'my $x = "text[with]brackets"', "qq() with brackets avoids escapes";

  bad 'my $x = qx[command[with]brackets]',
    "qx[] with brackets should use qx() to avoid escapes";
  good 'my $x = qx(command[with]brackets)',
    "qx() with brackets avoids escapes";

  # Empty quotes should prefer () first
  bad 'my @x = qw{}', "Empty qw{} should use qw()";
  bad 'my @x = qw[]', "Empty qw[] should use qw()";
  good 'my @x = qw()', "Empty qw() is preferred";

  # When all delimiters appear in content, prefer () (least escapes needed)
  bad 'my @x = qw{has(parens)[and]<angles>{braces}}',
    "All delimiters present - should use qw()";
  bad 'my @x = qw[has(parens)[and]<angles>{braces}]',
    "All delimiters present - should use qw()";
  bad 'my @x = qw<has(parens)[and]<angles>{braces}>',
    "All delimiters present - should use qw()";
  good 'my @x = qw(has(parens)[and]<angles>{braces})',
    "qw() preferred when all delimiters present";

  # Tie-breaking: when escape counts equal, prefer () over [] over <> over {}
  bad 'my @x = qw{one[bracket}', "When tied, () is preferred over {}";
  bad 'my @x = qw<one[bracket>', "When tied, () is preferred over <>";
  bad 'my @x = qw[one[bracket]', "When tied, () is preferred over []";
  good 'my @x = qw(one[bracket])',
    "() is preferred when escape counts are tied";

  # Test [] vs <> vs {} preference order
  bad 'my @x = qw{one(paren}', "When tied, [] is preferred over {}";
  bad 'my @x = qw<one(paren>', "When tied, [] is preferred over <>";
  good 'my @x = qw[one(paren)]', "[] is preferred over <> and {}";

  # Test <> vs {} preference order
  bad 'my @x = qw{one(paren)[bracket}', "When tied, <> is preferred over {}";
  good 'my @x = qw<one(paren)[bracket>', "<> is preferred over {}";

  # Content with only one type of delimiter that's not the preferred one
  good 'my @x = qw[text(only)parens]',
    "[] optimal when content has only parens";
  good 'my @x = qw(text[only]brackets])',
    "() optimal when content has only brackets";
  bad 'my @x = qw<text<only>angles>',
    "qw<> with angles should use qw() - fewer escapes";
  good 'my @x = qw(text<only>angles)', "() optimal when content has angles";
  good 'my @x = qw(text{only}braces)',
    "() optimal when content has only braces";

  # Test exotic delimiters - these should be violations when content conflicts
  subtest "Exotic delimiters" => sub {
    bad 'my $text = qq/path\/to\/file/',
      "qq// with slashes should use qq() to avoid escapes";
    good 'my $text = qq(path"to"file)',
      "qq() optimal when content has double quotes";
    bad 'my $text = q|option\|value|',
      "q|| with pipes should use q() to avoid escapes";
    good 'my $text = q(option|value)', "q() optimal when content has pipes";
    bad 'my $text = q"say \"hello\""',
      'q"" with quotes should use q() to avoid escapes';
    good 'my $text = q(say "hello")', "q() optimal when content has quotes";
    bad q(my $output = qx'echo \'hello\''),
      "qx'' with single quotes should use qx() to avoid escapes";
    good q[my $output = qx(echo 'hello')],
      "qx() optimal when content has single quotes";
    bad 'my $text = q#path\#to\#file#',
      "q## with hashes should use q() to avoid escapes";
    good 'my $text = q(path#to#file)', "q() optimal when content has hashes";
    bad 'my $text = q!wow\!amazing!',
      "q!! with exclamation marks should use q() to avoid escapes";
    good 'my $text = q(wow!amazing)',
      "q() optimal when content has exclamation marks";
    bad 'my $text = q%100\%complete%',
      "q%% with percent signs should use q() to avoid escapes";
    good 'my $text = q(100%complete)',
      "q() optimal when content has percent signs";
    bad 'my $text = q&fish\&chips&',
      "q&& with ampersands should use q() to avoid escapes";
    good 'my $text = q(fish&chips)',
      "q() optimal when content has ampersands";
    bad 'my $text = q~home\~user~',
      "q~~ with tildes should use q() to avoid escapes";
    good 'my $text = q(home~user)', "q() optimal when content has tildes";
  };
};

subtest "Combined tests" => sub {
  # Code with both types of violations
  my @violations = count_violations q<
    my $simple = 'hello';
    my @words = qw{word(with)parens};
    my $ok = "world";
    my @ok_words = qw[more(parens)];
  >, 2, "Code with multiple types of violations";

  # Check violation messages
  like $violations[0]->description, qr(consistent),
    "First violation mentions consistency";
  like $violations[1]->description, qr(consistent),
    "Second violation mentions consistency";
};

subtest "Edge cases" => sub {
  # Whitespace in quote operators
  bad 'my @x = qw  {word(with)parens}', "qw with whitespace before delimiter";
  bad 'my @x = qw\t{word(with)parens}', "qw with tab before delimiter";

  # Different quote styles - prefer "" to qq and '' to q
  bad q(my $x = qq'simple'),
    "qq'' should use double quotes for simple content";
  bad 'my $x = qq/simple/',
    "qq// should use double quotes for simple content";
  bad 'my $x = qq(simple)',
    "qq() should use double quotes for simple content";
  bad q(my $x = q'simple'), "q'' should use double quotes for simple content";
  bad 'my $x = q/simple/',  "q// should use double quotes for simple content";
  bad 'my $x = q(simple)',  "q() should use double quotes for simple content";
};

subtest "Priority rules" => sub {
  # Rule 1: Prefer interpolating quotes unless strings shouldn't interpolate
  bad q(my $x = 'simple'), "Simple string should use double quotes";
  good 'my $x = "simple"', "Simple string with double quotes";
  good q(my $x = 'literal$var'),
    'String with literal $ should use single quotes';
  good q(my $x = 'literal@var'),
    'String with literal @ should use single quotes';

  # Rule 2: Always prefer fewer escaped characters
  bad 'my $text = q/path\/to\/file/',
    'q// with slashes should use "" to avoid escapes';
  good 'my $text = "path/to/file"', '"" optimal when content has slashes';

  # Various quote operators with escaped characters
  bad 'my $text = q|option\|value|',
    'q|| with pipes should use "" to avoid escapes';
  good 'my $text = "option|value"', '"" optimal when content has pipes';

  bad 'my $text = q#path\#to\#file#',
    'q## with hashes should use "" to avoid escapes';
  good 'my $text = "path#to#file"', '"" optimal when content has hashes';

  bad 'my $text = q!wow\!amazing!',
    'q!! with exclamation should use "" to avoid escapes';
  good 'my $text = "wow!amazing"', '"" optimal when content has exclamation';

  bad 'my $text = q%100\%complete%',
    'q%% with percent should use "" to avoid escapes';
  good 'my $text = "100%complete"', '"" optimal when content has percent';

  bad 'my $text = q&fish\&chips&',
    'q&& with ampersand should use "" to avoid escapes';
  good 'my $text = "fish&chips"', '"" optimal when content has ampersand';

  bad 'my $text = q~home\~user~',
    'q~~ with tilde should use "" to avoid escapes';
  good 'my $text = "home~user"', '"" optimal when content has tilde';

  # qq operators with escaped characters
  bad 'my $text = qq/path\/to\/file/',
    'qq// with slashes should use "" to avoid escapes';
  good 'my $text = "path/to/file"',
    '"" optimal for interpolated strings with slashes';

  bad 'my $text = qq|option\|value|',
    'qq|| with pipes should use "" to avoid escapes';
  good 'my $text = "option|value"',
    '"" optimal for interpolated strings with pipes';

  # qx operators with escaped characters
  bad 'my $output = qx/ls \/tmp/',
    "qx// with slashes should use qx() to avoid escapes";
  good 'my $output = qx(ls /tmp)', "qx() optimal when content has slashes";

  bad 'my $output = qx|echo \|pipe|',
    "qx|| with pipes should use qx() to avoid escapes";
  good 'my $output = qx(echo |pipe)', "qx() optimal when content has pipes";

  # qw operators with various escaped characters
  bad 'my @words = qw/word\/with\/slashes/',
    "qw// with slashes should use qw() to avoid escapes";
  good 'my @words = qw(word/with/slashes)',
    "qw() optimal when words have slashes";

  bad 'my @words = qw|word\|with\|pipes|',
    "qw|| with pipes should use qw() to avoid escapes";
  good 'my @words = qw(word|with|pipes)',
    "qw() optimal when words have pipes";

  # Mixed content - choose delimiter that minimises total escapes
  bad 'my $text = q/has\/slashes(and)parens/',
    "q// should use q[] - fewer total escapes";
  good 'my $text = q[has/slashes(and)parens]',
    "q[] optimal - avoids escaping parens, allows slashes";

  bad 'my $text = q(has(parens)\/and\/slashes)',
    'q() should use "" - fewer total escapes';
  good 'my $text = "has(parens)/and/slashes/"',
    '"" optimal - avoids escaping slashes, allows parens';

  # String literals vs quote operators - prefer simpler forms
  bad 'my $text = q(simple)', 'q() should use "" for simple content';
  good 'my $text = "simple"', '"" preferred over q() for simple content';

  bad 'my $text = q(literal)', 'q() should use "" for literal content';
  good 'my $text = "literal"', '"" preferred over q() for literal content';

  # When content has quotes, use appropriate delimiter
  good q(my $text = 'contains "double" quotes'),
    "'' appropriate when content has double quotes";
  good q(my $text = "contains 'single' quotes"),
    '"" appropriate when content has single quotes';
  good q[my $text = qq(contains 'both' and "quotes")],
    "qq() appropriate when content has both quote types";

  # Rule 3: Prefer "" to qq
  bad 'my $x = qq(simple)',
    "qq() should use double quotes for simple content";
  good 'my $x = "simple"', "Double quotes preferred over qq()";
  bad 'my $x = qq/hello/', "qq// should use double quotes";

  # Rule 4: Prefer '' to q
  bad 'my $x = q(literal$x)',
    "q() should use single quotes for literal content";
  good q(my $x = 'literal$x'), "Single quotes preferred over q()";
  bad 'my $x = q/literal$x/', "q// should use single quotes";

  # Rule 5: Prefer bracketed delimiters in order (), [], <>, {}
  bad 'my @x = qw/word word/', "qw// should use qw() - brackets preferred";
  bad 'my @x = qw|word word|', "qw|| should use qw() - brackets preferred";
  bad 'my @x = qw#word word#', "qw## should use qw() - brackets preferred";
  good 'my @x = qw(word word)', "qw() uses preferred bracket delimiters";

  # Bracket priority: () > [] > <> > {}
  bad 'my @x = qw{simple words}',
    "qw{} should use qw() - () preferred over {}";
  bad 'my @x = qw<simple words>',
    "qw<> should use qw() - () preferred over <>";
  bad 'my @x = qw[simple words]',
    "qw[] should use qw() - () preferred over []";
  good 'my @x = qw(simple words)', "qw() is most preferred bracket delimiter";
};

subtest "Coverage edge cases" => sub {
  good q[my $x = q(has 'single' and "double" quotes)],
    "q() is justified when content has both quote types";

  bad 'my $x = q(literal $var here)',
    'q() with literal $ should use single quotes';

  # Test applies_to and default_themes methods
  my $policy
    = Perl::Critic::Policy::ValuesAndExpressions::UseConsistentQuoting->new;

  # Call default_themes
  my @themes = $policy->default_themes;
  is scalar @themes, 1,          "default_themes returns one theme";
  is $themes[0],     "cosmetic", "default theme is cosmetic";

  # Call applies_to
  my @types = $policy->applies_to;
  is scalar @types, 6, "applies_to returns 6 token types";
  like $types[0], qr/Quote/, "applies_to returns quote token types";

  # Test invalid token type that should fail parsing
  my $doc = PPI::Document->new(\'my $x = 42');
  $doc->find(
    sub ($top, $elem) {
      if ($elem->isa("PPI::Token::Number")) {
        # This should return undef from _parse_quote_token
        my $violation = $policy->violates($elem, $doc);
        is $violation, undef, "Non-quote tokens don't violate";
      }
      0
    }
  );

  # More edge cases for better coverage
  # Test q() with literal @ but no literal $
  bad 'my $x = q(user@domain.com)',
    'q() with only literal @ should use double quotes';

  # Test single quoted string that wouldn't interpolate anyway
  bad q(my $x = 'no special chars'),
    "Single quotes for non-interpolating string should use double quotes";

  # Test escaping conditions that tie
  good 'my @x = qw(has[only]brackets)', "qw() with only brackets";
  good 'my @x = qw[has(only)parens]',   "qw[] with only parens";

  # Test edge case with whitespace variations
  bad 'my @x = qw     <simple words>',
    "qw<> with multiple spaces should use qw()";

  # Test delimiter_preference_order method directly for coverage
  is $policy->delimiter_preference_order("("), 0, "() has preference 0";
  is $policy->delimiter_preference_order("["), 1, "[] has preference 1";
  is $policy->delimiter_preference_order("<"), 2, "<> has preference 2";
  is $policy->delimiter_preference_order("{"), 3, "{} has preference 3";
  is $policy->delimiter_preference_order("x"), 99,
    "invalid delimiter returns 99";

  # Test would_interpolate method directly
  ok !$policy->would_interpolate("simple"),
    "Simple string doesn't interpolate";
  ok $policy->would_interpolate('$var'),   "Variable interpolates";
  ok $policy->would_interpolate('@array'), "Array interpolates";
  ok !$policy->would_interpolate('\\$escaped'),
    "Escaped variable doesn't interpolate";
};

subtest "Coverage for uncovered branches" => sub {
  # Test case to cover "has both single and double quotes" condition
  good q[my $x = q(has 'single' and "double")],
    "q() justified when content has both quote types";

  # Test string with double quotes but would interpolate
  good q(my $text = "contains $var and \"quotes\""),
    "Double quotes with interpolation and quotes";

  # Test string with interpolation but no single quotes
  bad 'my $x = q(interpolates $var)',
    "q() should use single quotes when content would interpolate";

  # Test coverage for policy methods
  my $policy
    = Perl::Critic::Policy::ValuesAndExpressions::UseConsistentQuoting->new;

  # Test with simple alphanumeric content in q()
  bad 'my $x = q(simple123)',
    "q() with simple alphanumeric content should use double quotes";

  # Test when content has only double quotes but no interpolation
  good q[my $x = q(has "only" double quotes)],
    "q() appropriate when content has double quotes but no interpolation";

  # Test where all delimiters have same escape count for sort condition
  # This tests the preference order when escape counts are equal
  bad 'my @x = qw{no_special_chars}',
    "qw{} should use qw() when escape counts are equal - preference order";
  bad 'my @x = qw<no_special_chars>',
    "qw<> should use qw() when escape counts are equal - preference order";
  bad 'my @x = qw[no_special_chars]',
    "qw[] should use qw() when escape counts are equal - preference order";
  good 'my @x = qw(no_special_chars)',
    "qw() is preferred when all delimiters have same escape count";

  # Test find_optimal_delimiter with non-bracket current delimiter
  # This covers the condition where current delimiter is not in bracket list
  my ($optimal, $is_optimal)
    = $policy->find_optimal_delimiter("content", "qw", "/", "/");
  is $is_optimal, 0, "Non-bracket delimiter is never optimal";

  # Test conditions with bracket vs non-bracket delimiters
  my ($optimal2, $is_optimal2)
    = $policy->find_optimal_delimiter("content", "qw", "(", ")");
  is $is_optimal2, 1, "Bracket delimiter can be optimal";
};

subtest "Additional branch coverage tests" => sub {
  # Test to cover the case where escape counts are different
  bad 'my @x = qw{word(with)(many)parens}',
    "qw{} with many parens should use qw[] - fewer escapes";

  # Test where string has both quotes and would interpolate
  good q(my $x = "string with $var and \"quotes\""),
    "Double quotes appropriate when string interpolates and has quotes";

  # Test where find_optimal_delimiter current_delim is matched
  good 'my @x = qw(optimal_choice)',
    "qw() is already optimal for simple content";
};

subtest "Complex edge cases for condition coverage" => sub {
  # Test where string has content that would interpolate OR has quotes
  bad 'my $x = q(would interpolate $var)',
    "q() should use single quotes when content would interpolate";

  # Test where string has single quotes but no double quotes
  good q[my $x = q(has 'single' quotes)],
    "q() appropriate when content has single quotes but no double quotes";
};

done_testing;
