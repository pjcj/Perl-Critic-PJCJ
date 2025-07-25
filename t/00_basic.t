#!/usr/bin/env perl

use v5.24.0;
use strict;
use warnings;

use Test2::V0    qw( done_testing ok subtest );
use feature      qw( signatures );
use experimental qw( signatures );

subtest "Module loading" => sub {
  ok require Perl::Critic::PJCJ, "Can load Perl::Critic::PJCJ";
  ok require Perl::Critic::Policy::ValuesAndExpressions::UseConsistentQuoting,
    "Can load UseConsistentQuoting policy";
};

done_testing;
