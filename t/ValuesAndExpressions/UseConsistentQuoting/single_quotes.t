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

subtest "Single quoted strings" => sub {
  # Should violate - single quotes for simple strings
  bad $Policy, q(my $x = 'hello'), 'use ""',
    "Single quoted simple string should use double quotes";
  bad $Policy, q(my $x = 'world'), 'use ""',
    "Another simple string should use double quotes";
  bad $Policy, q(my $x = 'hello world'), 'use ""',
    "Simple string with space should use double quotes";
  bad $Policy, q(my $x = 'no special chars'), 'use ""',
    "Single quotes for non-interpolating string should use double quotes";

  # Should NOT violate - appropriate use of single quotes
  good $Policy, q(my $x = 'user@domain.com'),
    "String with literal @ using single quotes";
  good $Policy, q(my $x = 'He said "hello"'),
    "String with double quotes using single quotes";
  good $Policy, q(my $x = 'literal$var'),
    'String with literal $ using single quotes';
  good $Policy, q(my $x = 'literal@var'),
    'String with literal @ using single quotes';
};

subtest "Escaped characters in single quotes" => sub {
  # Escaped single quotes should recommend double quotes
  bad $Policy, q(my $x = 'I\'m happy'), 'use ""',
    'Escaped single quotes should use ""';

  # Literal special characters
  good $Policy, q(my $text = 'A $ here'),
    'Literal $ should use single quotes';
  good $Policy, q(my $x = 'user@domain.com'),
    "String with literal @ using single quotes";
  good $Policy, q(my $x = 'literal$var'),
    'String with literal $ using single quotes';
};

subtest "Mixed quote content" => sub {
  # When content has both types of quotes with optimal delimiter - acceptable
  good $Policy, q[my $x = q(has 'single' and "double" quotes)],
    "q() is justified when content has both quote types";
  good $Policy, q[my $x = q(has 'single' and "double")],
    "q() justified when content has both quote types";

  # When content has both types with suboptimal delimiter - should suggest
  # better delimiter
  bad $Policy, q(my $x = q[has 'single' and "double" quotes]), "use q()",
    "q[] with both quote types should recommend q() for optimal delimiter";
  bad $Policy, q(my $x = q{contains 'single' and "double" quotes}), "use q()",
    "q{} with both quote types should recommend q() for optimal delimiter";

  # When content has only single quotes - should recommend double quotes
  bad $Policy, q[my $x = q(has 'single' quotes)], 'use ""',
    "q() with only single quotes should recommend double quotes";

  # Bug case: content with both $ and ' should keep q()
  # (single quotes would require escaping: '$x \''', double quotes would
  # interpolate)
  good $Policy, q[my $x = q($x ')],
    'q() is justified when content has both $ and single quote';

  # Single quotes with interpolatable content and double quotes are justified
  good $Policy, q(my $x = 'literal $var with "quotes"'),
    "Single quotes justified when content has both interpolation and quotes";
  good $Policy, q(my $x = 'email@domain.com has "quotes"'),
    'Single quotes justified when content has @ and double quotes';
};

done_testing;
