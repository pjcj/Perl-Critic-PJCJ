#!/usr/bin/env perl

use v5.26.0;
use strict;
use warnings;

use Test2::V0    qw( done_testing ok );
use feature      qw( signatures );
use experimental qw( signatures );

use lib        qw( lib t/lib );
use List::Util qw( any );
use Test2::API qw( intercept );

use Perl::Critic::Policy::CodeLayout::ProhibitLongLines                  ();
use Perl::Critic::Policy::ValuesAndExpressions::RequireConsistentQuoting ();
use ViolationFinder qw( good );

package RenamedQuotingPolicy {
  use parent qw(
    -norequire
    Perl::Critic::Policy::ValuesAndExpressions::RequireConsistentQuoting
  );
}

sub runs_fixer_assertion ($policy) {
  my $events = intercept { good $policy, 'my $x = "ok";', "probe" };
  any { ($_->{name} // "") =~ /fixer leaves it alone/ } @$events
}

ok runs_fixer_assertion(
  Perl::Critic::Policy::ValuesAndExpressions::RequireConsistentQuoting->new),
  "the real policy triggers the fixer assertion";
ok runs_fixer_assertion(RenamedQuotingPolicy->new),
  "a renamed subclass triggers the fixer assertion";
ok !runs_fixer_assertion(
  Perl::Critic::Policy::CodeLayout::ProhibitLongLines->new),
  "a policy without fix_data does not trigger the fixer assertion";

done_testing
