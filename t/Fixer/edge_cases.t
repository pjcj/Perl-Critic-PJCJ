#!/usr/bin/env perl

use v5.26.0;
use strict;
use warnings;

use Test2::V0    qw( done_testing is subtest );
use feature      qw( signatures );
use experimental qw( signatures );

use lib                       qw( lib t/lib );
use Perl::Critic::PJCJ::Fixer ();

my $Fixer = Perl::Critic::PJCJ::Fixer->new;

sub fixes ($in, $out, $desc) {
  is $Fixer->fix($in), $out, $desc;
}

sub unchanged ($in, $desc) {
  is $Fixer->fix($in), $in, $desc;
}

subtest "Unparsable and empty sources pass through" => sub {
  unchanged "", "empty source is returned as is";
};

subtest "Unsafe fixes are declined" => sub {
  unchanged 'my @w = qw/( [ < { \\\\/;',
    "content with a backslash and every delimiter is left alone";
  unchanged "use Foo 'a b';",
    "an import name containing a space cannot become a qw word";
};

subtest "Fallback re-delimiting inside use statements" => sub {
  fixes 'use Foo qw[ a ], "b$x";', 'use Foo qw( a ), "b$x";',
    "interpolating argument restricts the fix to the qw token";
  fixes 'use Foo qw[ a ], qw{ b }, $v;', 'use Foo qw( a ), qw( b ), $v;',
    "every qw token is re-delimited when a full rewrite is unsafe";
};

subtest "Whitespace oddities" => sub {
  fixes "use Foo 'a' ;", "use Foo qw( a ) ;",
    "trailing whitespace before the semicolon survives";
};

done_testing
