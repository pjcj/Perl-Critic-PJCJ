#!/usr/bin/env perl

use v5.24.0;
use strict;
use warnings;

use Test2::V0;
use feature      qw( signatures );
use experimental qw( signatures );

# Test the newline special case handling
use lib qw( lib t/lib );
use Perl::Critic::Policy::ValuesAndExpressions::UseConsistentQuoting;
use ViolationFinder qw( find_violations count_violations good bad );

my $Policy
  = Perl::Critic::Policy::ValuesAndExpressions::UseConsistentQuoting->new;

subtest "Single-quoted strings with newlines" => sub {
  # Single-quoted strings with literal newlines are allowed
  good $Policy, <<'CODE', "single quotes with literal newline";
my $text = 'line 1
line 2';
CODE

  good $Policy, <<'CODE', "single quotes with multiple newlines";
my $text = 'line 1
line 2
line 3';
CODE

  # Single quotes with escaped single quotes and newlines are allowed
  good $Policy, <<'CODE', "single quotes with escaped quotes and newlines";
my $text = 'line 1 with \'quote\'
line 2';
CODE
};

subtest "Double-quoted strings with newlines" => sub {
  # Double-quoted strings with literal newlines are allowed
  good $Policy, <<'CODE', "double quotes with literal newline";
my $text = "line 1
line 2";
CODE

  good $Policy, <<'CODE', "double quotes with interpolation and newlines";
my $var = "world";
my $text = "Hello $var
line 2";
CODE

  # Double quotes with escaped sigils and newlines are allowed
  good $Policy, <<'CODE', "double quotes with escaped sigils and newlines";
my $text = "Price: \$10
Next line";
CODE
};

subtest "q() operators with newlines" => sub {
  # q() with newlines is allowed regardless of content
  good $Policy, <<'CODE', "q() with newlines";
my $text = q(line 1
line 2);
CODE

  good $Policy, <<'CODE', "q[] with newlines and quotes";
my $text = q[line 1 with 'quotes'
line 2];
CODE

  good $Policy, <<'CODE', "q{} with newlines and complex content";
my $text = q{line 1 with 'single' and "double" quotes
line 2};
CODE
};

subtest "qq() operators with newlines" => sub {
  # qq() with newlines is allowed
  good $Policy, <<'CODE', "qq() with newlines";
my $text = qq(line 1
line 2);
CODE

  good $Policy, <<'CODE', "qq() with interpolation and newlines";
my $var = "world";
my $text = qq(Hello $var
line 2);
CODE

  good $Policy, <<'CODE', "qq[] with newlines and parentheses";
my $text = qq[line 1 (with parens)
line 2];
CODE

  # Common multi-line use case from documentation
  good $Policy, <<'CODE', "qq() with indented multi-line content";
my $text = qq(
  line 1
  line 2
);
CODE
};

subtest "Strings without newlines still follow rules" => sub {
  # Single quotes without newlines should still be checked
  bad $Policy, <<'CODE', 'use ""', "single quotes without newlines";
my $text = 'hello';
CODE

  # qq() without newlines for simple strings should still be checked
  bad $Policy, <<'CODE', 'use ""', "qq() without newlines for simple string";
my $text = qq(hello);
CODE
};

subtest "Edge cases" => sub {
  # Escape sequence \n in single quotes is preserved
  # (has dangerous escape sequences)
  good $Policy, <<'CODE', "\\n in single quotes preserved";
my $text = 'hello\nworld';
CODE

  # Mixed content: literal newline and escape sequence
  good $Policy, <<'CODE', "literal newline with \\n escape";
my $text = "hello\n
world";
CODE

  # Empty string with just newlines
  good $Policy, <<'CODE', "string with only newlines";
my $text = '

';
CODE

  # String without escape sequences or newlines should still be checked
  bad $Policy, <<'CODE', 'use ""', "simple string without newlines";
my $text = 'hello world';
CODE
};

done_testing;
