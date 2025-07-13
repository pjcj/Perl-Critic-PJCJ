#!/usr/bin/env perl

use v5.20.0;
use strict;
use warnings;

use Test2::V0;

subtest 'Module loading' => sub {
  ok require Perl::Critic::Strings, 'Can load Perl::Critic::Strings';
  ok
    require
    Perl::Critic::Policy::ValuesAndExpressions::RequireDoubleQuotedStrings,
    'Can load RequireDoubleQuotedStrings policy';
};

done_testing;
