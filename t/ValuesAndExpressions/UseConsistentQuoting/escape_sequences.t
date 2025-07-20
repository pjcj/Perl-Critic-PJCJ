#!/usr/bin/env perl

use v5.20.0;
use strict;
use warnings;
use feature "signatures";

use Test2::V0;

no warnings "experimental::signatures";

# Test escape sequence handling in quotes
use lib qw( lib t/lib );
use Perl::Critic::Policy::ValuesAndExpressions::UseConsistentQuoting;
use ViolationFinder qw(find_violations count_violations good bad);

## no critic (ValuesAndExpressions::UseConsistentQuoting)

my $Policy
  = Perl::Critic::Policy::ValuesAndExpressions::UseConsistentQuoting->new;

subtest "Escaped sigils should suggest double quotes" => sub {
  # These are currently incorrectly handled by line 218
  # In single quotes: '\$' is literally backslash-dollar
  # In double quotes: "\$" is properly escaped dollar

  bad $Policy, q(my $price = "Cost: \$10"), "use ''",
    "Escaped dollar in single quotes should suggest double quotes";

  bad $Policy, q(my $email = "Contact: \@domain"), "use ''",
    "Escaped at in single quotes should suggest double quotes";

  # Mixed escaped and literal content
  bad $Policy, q(my $mixed = "\$escaped and literal text"), "use ''",
    "Escaped sigils with text should suggest double quotes";
};

subtest "Other escape sequences in single quotes" => sub {
  # Single quotes treat these as literal, double quotes interpret them

  good $Policy, q(my $text = "Line 1\nLine 2"),
    "Escape sequences in double quotes are acceptable";

  good $Policy, q(my $text = "Tab\there"),
    "Tab escape sequence in double quotes is acceptable";

  good $Policy, q(my $path = "C:\new\folder"),
    "Path with backslashes in double quotes is acceptable";
};

subtest "True variable interpolation should keep single quotes" => sub {
  # These should remain single quotes to prevent interpolation

  good $Policy, q(my $literal = '$var should not interpolate'),
    "Literal variable reference should stay single quotes";

  good $Policy, q(my $array = '@array should not interpolate'),
    "Literal array reference should stay single quotes";

  good $Policy, q(my $complex = '$hash{key} should not interpolate'),
    "Complex variable reference should stay single quotes";
};

subtest "Escape sequences in single quotes should NOT suggest double quotes" =>
  sub {
  # Single quotes with literal backslash-escape sequences should NOT suggest
  # double quotes because that would change their meaning from literal to
  # escaped

  # Literal backslash-n in single quotes should stay single quotes
  # (in '' it's literal \n, in "" it would become newline)
  good $Policy, q(my $literal_newline = 'text with \\n literal'),
    'Literal \n in single quotes should stay single quotes';

  # Literal backslash-t in single quotes should stay single quotes
  # (in '' it's literal \t, in "" it would become tab)
  good $Policy, q(my $literal_tab = 'text with \\t literal'),
    'Literal \t in single quotes should stay single quotes';

  # Literal backslash-dollar in single quotes should stay single quotes
  # (in '' it's literal \$, in "" it would become escaped $)
  good $Policy, q{my $literal_dollar = 'price: \\$5.00'},
    'Literal \$ in single quotes should stay single quotes';

  # Literal backslash-at in single quotes should stay single quotes
  # (in '' it's literal \@, in "" it would become escaped @)
  good $Policy, q{my $literal_at = 'email: user\\@domain.com'},
    'Literal \@ in single quotes should stay single quotes';

  # Complex case with multiple literal escapes should stay single quotes
  good $Policy, q{my $complex = 'path: C:\\new\\folder with \\$var'},
    'Multiple literal escapes in single quotes should stay single quotes';
};

subtest "All Perl escape sequences should stay in single quotes" => sub {
  # Test all escape sequences from perlop documentation

  # Single character escapes: \t \n \r \f \b \a \e
  good $Policy, q(my $text = 'Line with \\r carriage return'),
    'Literal \r in single quotes should stay single quotes';
  good $Policy, q(my $text = 'Form \\f feed here'),
    'Literal \f in single quotes should stay single quotes';
  good $Policy, q(my $text = 'Backspace \\b here'),
    'Literal \b in single quotes should stay single quotes';
  good $Policy, q(my $text = 'Bell \\a sound'),
    'Literal \a in single quotes should stay single quotes';
  good $Policy, q(my $text = 'Escape \\e sequence'),
    'Literal \e in single quotes should stay single quotes';

  # Hex escapes: \x1b \xff \x{263A}
  good $Policy, q(my $hex = 'Hex \\x1b escape'),
    'Literal \x hex escape should stay single quotes';
  good $Policy, q(my $hex = 'Hex \\xff value'),
    'Literal \xff hex escape should stay single quotes';
  good $Policy, q{my $hex = 'Unicode \\x{263A} smiley'},
    'Literal \x{} hex escape should stay single quotes';

  # Octal escapes: \033 \377 \o{033}
  good $Policy, q(my $oct = 'Octal \\033 escape'),
    'Literal \033 octal escape should stay single quotes';
  good $Policy, q(my $oct = 'Octal \\377 max'),
    'Literal \377 octal escape should stay single quotes';
  good $Policy, q{my $oct = 'Octal \\o{033} braced'},
    'Literal \o{} octal escape should stay single quotes';

  # Control characters: \c[ \cA \c@
  good $Policy, q(my $ctrl = 'Control \\c[ char'),
    'Literal \c control char should stay single quotes';
  good $Policy, q(my $ctrl = 'Control \\cA char'),
    'Literal \cA control char should stay single quotes';
  good $Policy, q(my $ctrl = 'Control \\c@ null'),
    'Literal \c@ control char should stay single quotes';

  # Named Unicode: \N{name} \N{U+263A}
  good $Policy, q{my $named = 'Named \\N{SMILEY} char'},
    'Literal \N{name} escape should stay single quotes';
  good $Policy, q{my $named = 'Unicode \\N{U+263A} point'},
    'Literal \N{U+} escape should stay single quotes';
};

subtest "Variables in single quotes are not suggested for interpolation" =>
  sub {
  # These test that the policy doesn't suggest interpolating actual variables
  # Variables in single quotes should stay literal (not interpolated)

  # Variable that exists in scope should not suggest interpolation
  good $Policy, q(my $x = '$var literal'),
    'Variables in single quotes should stay literal';

  # Array reference should not suggest interpolation
  good $Policy, q(my $x = '@arr literal'),
    'Array refs in single quotes should stay literal';

  # Hash reference should not suggest interpolation
  good $Policy, q(my $x = '$hash{key} literal'),
    'Hash refs in single quotes should stay literal';

  # Email addresses with @ should not suggest interpolation
  good $Policy, q(my $email = 'user@domain.com'),
    'Email addresses should stay in single quotes';
};

subtest "Edge cases with backslashes" => sub {
  # Test boundary conditions

  good $Policy, q(my $backslash = "Just \\ backslash"),
    "Escaped backslash in double quotes is acceptable";

  good $Policy, q(my $quote = 'Has "double" quotes'),
    "Single quotes justified by containing double quotes";

  # Test the two valid single-quote escapes
  # Actually, escaped single quotes should suggest double quotes
  # for better readability
  good $Policy, q(my $escaped_quote = "Don't worry"),
    "Simple apostrophe in double quotes is acceptable";
};

done_testing;
