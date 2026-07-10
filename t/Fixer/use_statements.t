#!/usr/bin/env perl

use v5.26.0;
use strict;
use warnings;

use Test2::V0 qw( done_testing subtest );

use lib             qw( lib t/lib );
use ViolationFinder qw( fixes unchanged );

subtest "String import lists become qw()" => sub {
  fixes "use Foo 'single_arg';", "use Foo qw( single_arg );",
    "single quoted argument becomes qw()";
  fixes 'use Bar "arg1", "arg2";', "use Bar qw( arg1 arg2 );",
    "multiple string arguments become qw()";
};

subtest "qw with wrong delimiters is re-delimited" => sub {
  fixes "use Baz qw[ arg1 arg2 ];", "use Baz qw( arg1 arg2 );",
    "square brackets become parentheses";
  fixes "use Baz qw{arg1 arg2};", "use Baz qw( arg1 arg2 );",
    "braces become parentheses";
  fixes 'use Foo qw[ a ], $v;', 'use Foo qw( a ), $v;',
    "qw is re-delimited even when other arguments are complex";
};

subtest "Mixed qw and strings are merged" => sub {
  fixes "use Foo qw( a ), 'b';", "use Foo qw( a b );",
    "qw and string arguments merge in order";
};

subtest "Escapes in string arguments are decoded faithfully" => sub {
  fixes 'use Foo "a\"b";', 'use Foo qw( a"b );',
    "escaped double quote decodes to the plain character";
  unchanged 'use Foo "a\tb", "c";', "escape sequence cannot become a qw word";
  unchanged 'use Foo "\x41", "b";', "hex escape cannot become a qw word";
};

subtest "Parentheses are removed" => sub {
  fixes 'use Qux ( key => "value" );', 'use Qux key => "value";',
    "fat comma arguments lose parentheses";
  fixes 'use Quux ( $VERSION );', 'use Quux $VERSION;',
    "complex expressions lose parentheses";
};

subtest "Comments in argument lists survive" => sub {
  unchanged qq(use Foo "a", # keep me\n  "b";),
    "a commented argument list is left alone";
  unchanged qq[use Foo ("a", # keep me\n  "b");],
    "a comment nested in parentheses is left alone";
};

subtest "Acceptable use statements are untouched" => sub {
  unchanged "use Foo;",      "bare use stays";
  unchanged "use Bar ();",   "empty parentheses stay";
  unchanged "use Baz 1.23;", "version number stays";
  unchanged 'no warnings ( "experimental" );',
    "single-argument pragma is exempt";
  unchanged 'use feature "class";', "pragma single argument stays";
  unchanged "use Data::Printer deparse => 0;",
    "fat comma without parentheses stays";
  unchanged 'use Mod $VERSION;',
    "complex expression without parentheses stays";
};

done_testing
