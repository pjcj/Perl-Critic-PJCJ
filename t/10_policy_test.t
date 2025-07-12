#!/usr/bin/env perl

use 5.010001;
use strict;
use warnings;

use Test::More;
use File::Temp qw(tempfile);

# Test the policy directly without using Perl::Critic framework
use lib qw(lib);
use Perl::Critic::Policy::ValuesAndExpressions::RequireDoubleQuotedStrings;

my $policy = Perl::Critic::Policy::ValuesAndExpressions::RequireDoubleQuotedStrings->new();

# Create a mock PPI document for testing
use PPI;

sub test_code {
    my ($code, $expected_violations, $description) = @_;

    my $doc = PPI::Document->new(\$code);
    my @violations;

    $doc->find(sub {
        my ($top, $elem) = @_;
        return 0 unless $elem->isa('PPI::Token::Quote::Single');

        my $violation = $policy->violates($elem, $doc);
        push @violations, $violation if $violation;

        return 0;  # Don't descend further
    });

    is(scalar @violations, $expected_violations, $description);

    if (@violations && $expected_violations > 0) {
        like($violations[0]->description, qr/double quotes/, 'Violation mentions double quotes');
    }
}

# Test cases that should violate the policy
test_code(q{my $greeting = 'hello';}, 1, 'Simple single-quoted string should violate');
test_code(q{my $name = 'world';}, 1, 'Another simple single-quoted string should violate');
test_code(q{my $message = 'hello world';}, 1, 'Simple string with spaces should violate');
test_code(q{my $empty = '';}, 1, 'Empty single-quoted string should violate');

# Test cases that should NOT violate the policy
test_code(q{my $email = 'user@domain.com';}, 0, 'String with @ should not violate');
test_code(q{my $quoted = 'He said "hello"';}, 0, 'String with embedded quotes should not violate');
test_code(q{my $complex = 'both @ and "quotes"';}, 0, 'String with both @ and quotes should not violate');

# Test multiple strings in one piece of code
my $multi_code = q{
    my $good1 = "proper";
    my $bad1 = 'simple';
    my $good2 = 'has@symbol';
    my $bad2 = 'another simple';
};

my $doc = PPI::Document->new(\$multi_code);
my @violations;

$doc->find(sub {
    my ($top, $elem) = @_;
    return 0 unless $elem->isa('PPI::Token::Quote::Single');

    my $violation = $policy->violates($elem, $doc);
    push @violations, $violation if $violation;

    return 0;
});

is(scalar @violations, 2, 'Multiple violations in complex code');

done_testing();
