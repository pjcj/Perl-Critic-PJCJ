#!/usr/bin/env perl

use v5.24.0;
use strict;
use warnings;

use Test2::V0;

subtest "Module loading" => sub {
  ok require Perl::Critic::PJCJ, "Can load Perl::Critic::PJCJ";
  ok require Perl::Critic::Policy::ValuesAndExpressions::UseConsistentQuoting,
    "Can load UseConsistentQuoting policy";
};

done_testing;
