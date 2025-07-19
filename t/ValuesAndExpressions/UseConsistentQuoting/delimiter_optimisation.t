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
use ViolationFinder qw(find_violations count_violations good bad);

my $Policy
  = Perl::Critic::Policy::ValuesAndExpressions::UseConsistentQuoting->new;

# Helper subs that use the common policy
sub good_code ($code, $description) {
  ViolationFinder::good($Policy, $code, $description);
}

sub bad_code ($code, $description) {
  count_violations($Policy, $code, 1, $description);
}

sub check_message ($code, $expected_message, $description) {
  bad($Policy, $code, $expected_message, $description);
}

subtest "Delimiter optimisation" => sub {
  # Content with parens should avoid () delimiters
  check_message(
    'my @x = qw(word(with)parens)',
    "use qw[]",
    "qw() with parens should use qw[]"
  );
  good_code 'my @x = qw[word(with)parens]', "qw[] with parens";
  check_message(
    'my @x = qw{word(with)parens}',
    "use qw[]",
    "qw{} with parens should use qw[]"
  );

  # Content with brackets should avoid [] delimiters
  check_message(
    'my @x = qw[word[with]brackets]',
    "use qw()",
    "qw[] with brackets should use qw()"
  );
  good_code 'my @x = qw(word[with]brackets)', "qw() with brackets";
  check_message(
    'my @x = qw{word[with]brackets}',
    "use qw()",
    "qw{} with brackets should use qw()"
  );

  # Content with braces should avoid {} delimiters
  check_message(
    'my @x = qw{word{with}braces}',
    "use qw()",
    "qw{} with braces should use qw()"
  );
  good_code 'my @x = qw(word{with}braces)', "qw() with braces";
  check_message(
    'my @x = qw[word{with}braces]',
    "use qw()",
    "qw[] with braces should use qw()"
  );

  # Content with angles should avoid <> delimiters
  check_message(
    'my @x = qw<word<with>angles>',
    "use qw()",
    "qw<> with angles should use qw()"
  );
  good_code 'my @x = qw(word<with>angles)', "qw() with angles";
  check_message(
    'my @x = qw[word<with>angles]',
    "use qw()",
    "qw[] with angles should use qw()"
  );
  check_message(
    'my @x = qw{word<with>angles}',
    "use qw()",
    "qw{} with angles should use qw()"
  );
};

subtest "Delimiter preference order" => sub {
  # Bracket priority: () > [] > <> > {}
  check_message(
    'my @x = qw{simple words}',
    "use qw()",
    "qw{} should use qw() - () preferred over {}"
  );
  check_message(
    'my @x = qw<simple words>',
    "use qw()",
    "qw<> should use qw() - () preferred over <>"
  );
  check_message(
    'my @x = qw[simple words]',
    "use qw()",
    "qw[] should use qw() - () preferred over []"
  );
  good_code 'my @x = qw(simple words)',
    "qw() is most preferred bracket delimiter";

  # Tie-breaking: when counts equal, prefer () over [] over <> over {}
  check_message(
    'my @x = qw{one[bracket}',
    "use qw()",
    "When tied, () is preferred over {}"
  );
  check_message(
    'my @x = qw<one[bracket>',
    "use qw()",
    "When tied, () is preferred over <>"
  );
  check_message(
    'my @x = qw[one[bracket]',
    "use qw()",
    "When tied, () is preferred over []"
  );
  good_code 'my @x = qw(one[bracket])',
    "() is preferred when all else is equal";

  # Test [] vs <> vs {} preference order
  check_message(
    'my @x = qw{one(paren}',
    "use qw[]",
    "When tied, [] is preferred over {}"
  );
  check_message(
    'my @x = qw<one(paren>',
    "use qw[]",
    "When tied, [] is preferred over <>"
  );
  good_code 'my @x = qw[one(paren)]', "[] is preferred over <> and {}";

  # Test <> vs {} preference order
  check_message(
    'my @x = qw{one(paren)[bracket}',
    "use qw<>",
    "When tied, <> is preferred over {}"
  );
  good_code 'my @x = qw<one(paren)[bracket>', "<> is preferred over {}";

  # When all delimiters appear in content, prefer ()
  check_message(
    'my @x = qw{has(parens)[and]<angles>{braces}}',
    "use qw()",
    "All delimiters present - should use qw()"
  );
  check_message(
    'my @x = qw[has(parens)[and]<angles>{braces}]',
    "use qw()",
    "All delimiters present - should use qw()"
  );
  check_message(
    'my @x = qw<has(parens)[and]<angles>{braces}>',
    "use qw()",
    "All delimiters present - should use qw()"
  );
  good_code 'my @x = qw(has(parens)[and]<angles>{braces})',
    "qw() preferred when all delimiters present";
};

subtest "Already optimal delimiters" => sub {
  # Content with only one type of delimiter that's not the preferred one
  good_code 'my @x = qw[text(only)parens]',
    "[] optimal when content has only parens";
  good_code 'my @x = qw(text[only]brackets])',
    "() optimal when content has only brackets";
  check_message(
    'my @x = qw<text<only>angles>',
    "use qw()",
    "qw<> with angles should use qw()"
  );
  good_code 'my @x = qw(text<only>angles)',
    "() optimal when content has angles";
  good_code 'my @x = qw(text{only}braces)',
    "() optimal when content has only braces";

  # When current delimiter is already optimal
  good_code 'my @x = qw(optimal_choice)',
    "qw() is already optimal for simple content";
  good_code 'my @x = qw(has[only]brackets)', "qw() with only brackets";
  good_code 'my @x = qw[has(only)parens]',   "qw[] with only parens";
};

subtest "Different brackets" => sub {
  check_message(
    'my @x = qw{word(with)(many)parens}',
    "use qw[]",
    "qw{} with many parens should use qw[]"
  );

  # Mixed content - choose preferred delimiter
  check_message(
    'my $text = q/has\/slashes(and)parens/',
    'use ""',
    "q// should use double quotes"
  );
  good_code 'my $text = "has/slashes(and)parens"',
    '"" optimal - no escaping needed';

  check_message('my $text = q(has(parens)\/and\/slashes)',
    'use ""', "q() should use double quotes");
  good_code 'my $text = "has(parens)/and/slashes"',
    '"" optimal - no escaping needed';
};

subtest "Equal bracket counts" => sub {
  # Tests where all delimiters have same count for sort condition
  # This tests the preference order when counts are equal
  check_message('my @x = qw{no_special_chars}',
    "use qw()",
    "qw{} should use qw() when counts are equal - preference order");
  check_message('my @x = qw<no_special_chars>',
    "use qw()",
    "qw<> should use qw() when counts are equal - preference order");
  check_message('my @x = qw[no_special_chars]',
    "use qw()",
    "qw[] should use qw() when counts are equal - preference order");
  good_code 'my @x = qw(no_special_chars)',
    "qw() is preferred when all delimiters have same count";
};

subtest "Exotic delimiters" => sub {
  check_message(
    'my $text = qq/path\/to\/file/',
    "use qq()",
    "qq// with slashes should use qq()"
  );
  good_code 'my $text = qq(path"to"file)',
    "qq() optimal when content has double quotes";
  check_message(
    'my $text = q|option\|value|',
    'use ""',
    "q|| with pipes should use double quotes"
  );
  good_code 'my $text = "option|value"',
    '"" optimal when content has pipes';
  check_message(
    'my $text = q"say \"hello\""',
    "use ''",
    'q"" with quotes should use single quotes'
  );
  check_message('my $text = q(say "hello")',
    "use ''", "q() with double quotes should use single quotes");
  check_message(
    'my $text = q#path\#to\#file#',
    'use ""',
    "q## with hashes should use double quotes"
  );
  good_code 'my $text = "path#to#file"',
    '"" optimal when content has hashes';
  check_message(
    'my $text = q!wow\!amazing!',
    'use ""',
    "q!! with exclamation marks should use double quotes"
  );
  good_code 'my $text = "wow!amazing"',
    '"" optimal when content has exclamation marks';
  check_message(
    'my $text = q%100\%complete%',
    'use ""',
    "q%% with percent signs should use double quotes"
  );
  good_code 'my $text = "100%complete"',
    '"" optimal when content has percent signs';
  check_message(
    'my $text = q&fish\&chips&',
    'use ""',
    "q&& with ampersands should use double quotes"
  );
  good_code 'my $text = "fish&chips"',
    '"" optimal when content has ampersands';
  check_message(
    'my $text = q~home\~user~',
    'use ""',
    "q~~ with tildes should use double quotes"
  );
  good_code 'my $text = "home~user"', '"" optimal when content has tildes';
};

subtest "Priority: fewer escapes" => sub {
  # Rule 2: Always prefer fewer escaped characters
  check_message(
    'my $text = q/path\/to\/file/',
    'use ""',
    "q// with slashes should use double quotes"
  );
  good_code 'my $text = "path/to/file"',
    '"" optimal when content has slashes';

  # Various quote operators with escaped characters
  check_message(
    'my $text = q|option\|value|',
    'use ""',
    "q|| with pipes should use double quotes"
  );
  good_code 'my $text = "option|value"', '"" optimal when content has pipes';

  check_message(
    'my $text = q#path\#to\#file#',
    'use ""',
    "q## with hashes should use double quotes"
  );
  good_code 'my $text = "path#to#file"', '"" optimal when content has hashes';

  check_message(
    'my $text = q!wow\!amazing!',
    'use ""',
    "q!! with exclamation should use double quotes"
  );
  good_code 'my $text = "wow!amazing"',
    '"" optimal when content has exclamation';

  check_message(
    'my $text = q%100\%complete%',
    'use ""',
    "q%% with percent should use double quotes"
  );
  good_code 'my $text = "100%complete"',
    '"" optimal when content has percent';

  check_message(
    'my $text = q&fish\&chips&',
    'use ""',
    "q&& with ampersand should use double quotes"
  );
  good_code 'my $text = "fish&chips"',
    '"" optimal when content has ampersand';

  check_message('my $text = q~home\~user~',
    'use ""', "q~~ with tilde should use double quotes");
  good_code 'my $text = "home~user"', '"" optimal when content has tilde';

  # qq operators with escaped characters
  check_message(
    'my $text = qq/path\/to\/file/',
    "use qq()",
    "qq// with slashes should use qq()"
  );
  good_code 'my $text = "path/to/file"',
    '"" optimal for interpolated strings with slashes';

  check_message(
    'my $text = qq|option\|value|',
    "use qq()",
    "qq|| with pipes should use qq()"
  );
  good_code 'my $text = "option|value"',
    '"" optimal for interpolated strings with pipes';
};

subtest "q() with other delimiter operators" => sub {
  check_message(
    'my $x = q(text(with)parens)',
    'use ""',
    "q() with parens should use double quotes"
  );
  good_code 'my $x = "text(with)parens"', "double quotes with parens";

  check_message(
    'my $x = qq[text[with]brackets]',
    "use qq()",
    "qq[] with brackets should use qq()"
  );
  good_code 'my $x = "text[with]brackets"', "qq() with brackets";

  check_message(
    'my $x = qx[command[with]brackets]',
    "use qx()",
    "qx[] with brackets should use qx()"
  );
  good_code 'my $x = qx(command[with]brackets)', "qx() with brackets";
};

done_testing;
