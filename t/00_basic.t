#!/usr/bin/env perl

use 5.010001;
use strict;
use warnings;

use Test::More;

BEGIN {
    use_ok('Perl::Critic::Strings');
    use_ok('Perl::Critic::Policy::ValuesAndExpressions::RequireDoubleQuotedStrings');
}

done_testing();
