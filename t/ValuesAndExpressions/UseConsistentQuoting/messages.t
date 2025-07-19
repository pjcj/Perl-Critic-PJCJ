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
use ViolationFinder
  qw(find_violations count_violations good bad check_violation_message);

my $Policy
  = Perl::Critic::Policy::ValuesAndExpressions::UseConsistentQuoting->new;

# Helper subs that use the common policy
sub good_code ($code, $description) {
  ViolationFinder::good($Policy, $code, $description);
}

sub check_message ($code, $expected_message, $description) {
  check_violation_message($Policy, $code, $expected_message, $description);
}

subtest "Single quote violation messages" => sub {
  check_message(q(my $x = 'hello'), 'use ""', "Simple single-quoted string");

  check_message(
    q(my $x = 'I\'m happy'),
    'use ""',
    "Single quotes with escaped apostrophe"
  );
};

subtest "Double quote violation messages" => sub {
  check_message(
    'my $output = "Price: \$10"',
    "use ''",
    "Double quotes with escaped dollar"
  );
};

subtest "q() operator violation messages" => sub {
  check_message('my $x = q(simple)', 'use ""', "q() with simple content");

  check_message('my $x = q(literal$x)', "use ''", "q() with literal dollar");
};

subtest "qq() operator violation messages" => sub {
  check_message('my $x = qq(simple)', 'use ""', "qq() with simple content");
};

subtest "Delimiter optimisation messages with hints" => sub {
  check_message(
    'my @x = qw(word(with)parens)',
    "use qw[]",
    "qw() with parens - hint to use qw[]"
  );

  check_message(
    'my @x = qw[word[with]brackets]',
    "use qw()",
    "qw[] with brackets - hint to use qw()"
  );

  check_message(
    'my @x = qw{word{with}braces}',
    "use qw()",
    "qw{} with braces - hint to use qw()"
  );

  check_message(
    'my @x = qw<word<with>angles>',
    "use qw()",
    "qw<> with angles - hint to use qw()"
  );

  check_message(
    'my @x = qw{simple words}',
    "use qw()",
    "qw{} simple - hint to use qw()"
  );

  check_message(
    'my $x = q(text(with)parens)',
    "use q[]",
    "q() with parens - hint to use q[]"
  );

  check_message(
    'my $x = qq[text[with]brackets]',
    "use qq()",
    "qq[] with brackets - hint to use qq()"
  );
};

subtest "Exotic delimiter messages" => sub {
  check_message('my $text = q/path\/to\/file/',
    'use q()', "q// with slashes - should use q() to avoid escapes");

  check_message(
    'my $text = q|option\|value|',
    'use q()',
    "q|| with pipes - should use q() to avoid escapes"
  );

  check_message(
    'my @x = qw/word\/with\/slashes/',
    "use qw()",
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

  # Check that descriptions are about quoting
  like $violations[0]->description, qr(Quoting),
    "First violation is about quoting";
  like $violations[1]->description, qr(Quoting),
    "Second violation is about quoting";
};

done_testing;
