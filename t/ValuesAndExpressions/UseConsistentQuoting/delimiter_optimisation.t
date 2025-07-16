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

sub count_violations ($code, $expected_violations, $description) {
  my @violations = find_violations($Policy, $code);
  is @violations, $expected_violations, $description;
  return @violations;
}

sub good ($code, $description) {
  count_violations($code, 0, $description);
}

sub bad ($code, $description) {
  count_violations($code, 1, $description);
}

subtest "Delimiter optimisation - minimizing escapes" => sub {
  # Content with parens should avoid () delimiters
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
};

subtest "Delimiter preference order" => sub {
  # Bracket priority: () > [] > <> > {}
  bad 'my @x = qw{simple words}',
    "qw{} should use qw() - () preferred over {}";
  bad 'my @x = qw<simple words>',
    "qw<> should use qw() - () preferred over <>";
  bad 'my @x = qw[simple words]',
    "qw[] should use qw() - () preferred over []";
  good 'my @x = qw(simple words)', "qw() is most preferred bracket delimiter";

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

  # When all delimiters appear in content, prefer () (least escapes needed)
  bad 'my @x = qw{has(parens)[and]<angles>{braces}}',
    "All delimiters present - should use qw()";
  bad 'my @x = qw[has(parens)[and]<angles>{braces}]',
    "All delimiters present - should use qw()";
  bad 'my @x = qw<has(parens)[and]<angles>{braces}>',
    "All delimiters present - should use qw()";
  good 'my @x = qw(has(parens)[and]<angles>{braces})',
    "qw() preferred when all delimiters present";
};

subtest "Already optimal delimiters" => sub {
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

  # When current delimiter is already optimal
  good 'my @x = qw(optimal_choice)',
    "qw() is already optimal for simple content";
  good 'my @x = qw(has[only]brackets)', "qw() with only brackets";
  good 'my @x = qw[has(only)parens]',   "qw[] with only parens";
};

subtest "Different escape counts" => sub {
  # Test to cover the case where escape counts are different
  bad 'my @x = qw{word(with)(many)parens}',
    "qw{} with many parens should use qw[] - fewer escapes";

  # Mixed content - choose delimiter that minimises total escapes
  bad 'my $text = q/has\/slashes(and)parens/',
    "q// should use q[] - fewer total escapes";
  good 'my $text = q[has/slashes(and)parens]',
    "q[] optimal - avoids escaping parens, allows slashes";

  bad 'my $text = q(has(parens)\/and\/slashes)',
    'q() should use "" - fewer total escapes';
  good 'my $text = "has(parens)/and/slashes/"',
    '"" optimal - avoids escaping slashes, allows parens';
};

subtest "Equal escape counts" => sub {
  # Tests where all delimiters have same escape count for sort condition
  # This tests the preference order when escape counts are equal
  bad 'my @x = qw{no_special_chars}',
    "qw{} should use qw() when escape counts are equal - preference order";
  bad 'my @x = qw<no_special_chars>',
    "qw<> should use qw() when escape counts are equal - preference order";
  bad 'my @x = qw[no_special_chars]',
    "qw[] should use qw() when escape counts are equal - preference order";
  good 'my @x = qw(no_special_chars)',
    "qw() is preferred when all delimiters have same escape count";
};

subtest "Exotic delimiters to minimise escapes" => sub {
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
  good 'my $text = q(fish&chips)', "q() optimal when content has ampersands";
  bad 'my $text = q~home\~user~',
    "q~~ with tildes should use q() to avoid escapes";
  good 'my $text = q(home~user)', "q() optimal when content has tildes";
};

subtest "Priority: fewer escapes" => sub {
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
};

subtest "q() with other delimiter operators" => sub {
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
};

done_testing;
