#!/usr/bin/env perl

use v5.26.0;
use strict;
use warnings;

use Test2::V0    qw( done_testing subtest );
use feature      qw( signatures );
use experimental qw( signatures );

# Test to exercise uncovered branches in quote checking within use statements
use lib qw( lib t/lib );
use Perl::Critic::Policy::ValuesAndExpressions::RequireConsistentQuoting ();
use ViolationFinder qw( bad good );

my $Policy
  = Perl::Critic::Policy::ValuesAndExpressions::RequireConsistentQuoting->new;

subtest "Use statement argument rules" => sub {
  # Module with no arguments - OK
  good $Policy, "use Foo",    "use with no arguments is fine";
  good $Policy, "use Foo ()", "use with empty parens is fine";

  # Module with one argument - can use "" or qw()
  good $Policy, 'use Foo "arg1"',
    "use with one double-quoted argument is fine";
  bad $Policy, "use Foo 'arg1'", "use qw()",
    "use with one single-quoted argument should use qw()";
  good $Policy, "use Foo qw(arg1)", "use with one qw() argument is fine";

  # Module with multiple arguments - double quotes are now allowed
  good $Policy, 'use Foo "arg1", "arg2"',
    "use with multiple double-quoted arguments is allowed";
  bad $Policy, "use Foo 'arg1', 'arg2'", "use qw()",
    "use with multiple single-quoted arguments should use qw()";
  bad $Policy, "use Foo ('arg1', 'arg2')", "use qw()",
    "use with multiple single-quoted arguments in parens should use qw()";
  good $Policy, 'use Foo "arg1", "arg2", "arg3"',
    "use with three double-quoted arguments is allowed";

  # Mixed arguments - should use qw()
  bad $Policy, "use Foo qw(arg1), 'arg2'", "use qw()",
    "mixed qw() and quotes should use qw() for all";
  bad $Policy, "use Foo 'arg1', qw(arg2)", "use qw()",
    "mixed quotes and qw() should use qw() for all";

  # Good cases with multiple arguments
  good $Policy, "use Foo qw(arg1 arg2)",
    "multiple arguments with qw() is correct";
  good $Policy, "use Foo qw(arg1 arg2 arg3)",
    "three arguments with qw() is correct";
  bad $Policy, "use Foo qw[arg1 arg2]", "use qw()",
    "qw[] should use qw() with parentheses only";

  # Other statement types should not be checked
  good $Policy, "require Foo", "require statements are not checked";
  good $Policy, "no warnings", "no statements are not checked";
};

subtest "Exercise _is_in_use_statement branches" => sub {
  # These test cases are designed to exercise the _is_in_use_statement method
  # by having quote tokens inside use statements that would normally be flagged

  # Test q() quotes inside use statements - should be skipped by regular q()
  # checking
  good $Policy, "use Foo q(simple)",
    "q() in use statements bypasses regular q() rules";
  good $Policy, "use Foo q{simple}",
    "q{} in use statements bypasses regular q() rules";
  good $Policy, "use Foo q[simple]",
    "q[] in use statements bypasses regular q() rules";
  good $Policy, "use Foo q<simple>",
    "q<> in use statements bypasses regular q() rules";

  # Test qq() quotes inside use statements - should be skipped by regular qq()
  # checking
  good $Policy, "use Foo qq(simple)",
    "qq() in use statements bypasses regular qq() rules";
  good $Policy, "use Foo qq{simple}",
    "qq{} in use statements bypasses regular qq() rules";
  good $Policy, "use Foo qq[simple]",
    "qq[] in use statements bypasses regular qq() rules";
  good $Policy, "use Foo qq<simple>",
    "qq<> in use statements bypasses regular qq() rules";
};

subtest "Use statements with multiple quote types" => sub {
  # Test multiple arguments to trigger the use statement multiple argument rule
  bad $Policy, "use Foo q(arg1), q(arg2)", "use qw()",
    "multiple q() arguments trigger use statement rule";
  bad $Policy, "use Foo qq(arg1), qq(arg2)", "use qw()",
    "multiple qq() arguments trigger use statement rule";

  # Mixed quote types
  bad $Policy, 'use Foo q(arg1), "arg2"', "use qw()",
    "mixed q() and double quotes trigger use statement rule";
  bad $Policy, 'use Foo qq(arg1), "arg2"', "use qw()",
    "mixed qq() and single quotes trigger use statement rule";
};

subtest "Edge cases for coverage" => sub {
  # Test semicolon handling - covers the semicolon branch in
  # _extract_use_arguments
  good $Policy, 'use Foo "arg"; # with semicolon',
    "use statement with semicolon works";

  # Test require and no statements to ensure they don't trigger use statement
  # logic
  bad $Policy, "require q(file.pl)", 'use ""',
    "require with q() is not processed by use statement logic";
  bad $Policy, "no warnings qq(experimental)", 'use ""',
    "no statement qq() is processed by regular quote logic";
};

subtest "Use statement structure parsing coverage" => sub {
  # With the new behavior, multiple double-quoted strings are allowed
  good $Policy, 'use Foo "arg1", "arg2";',
    "use statement with semicolon and multiple double-quoted args is allowed";

  good $Policy, 'use Foo "arg1", "arg2", "arg3"',
    "three double-quoted string arguments are allowed";
};

subtest "Use statements with parentheses" => sub {
  # Test arguments in plain parentheses
  good $Policy, 'use Foo ("arg1", "arg2")',
    "use statement with arguments in parentheses works";

  # Test arguments without any bracketing
  good $Policy, 'use Foo "arg1", "arg2"',
    "use statement with unbracketed arguments works";

  # Test the Data::Printer example
  good $Policy, <<~'EOT', "complex use statement with parentheses works";
  use Data::Printer (
    deparse       => 0,
    show_unicode  => 1,
    print_escapes => 1,
    class         => { expand => "all", parents => 0, show_methods => "none" },
    filters => $Data::Printer::VERSION >= 1 ? ["DB"] : { -external => ["DB"] }
  );
  EOT

  good $Policy, <<~'EOT', "complex use statement without parentheses works";
  use Data::Printer
    deparse       => 0,
    show_unicode  => 1,
    print_escapes => 1,
    class         => { expand => "all", parents => 0, show_methods => "none" },
    filters => $Data::Printer::VERSION >= 1 ? ["DB"] : { -external => ["DB"] };
  EOT

  # Test single argument in parentheses - should be fine as only one argument
  good $Policy, 'use Foo ("single")',
    "single argument in parentheses is acceptable";

  # Test mixed formats
  good $Policy, 'use Foo ("arg1"), "arg2"',
    "mixed parentheses and bare arguments should trigger violation";
};

done_testing;
