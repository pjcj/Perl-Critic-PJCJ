package ViolationFinder;

use v5.20.0;
use strict;
use warnings;
use feature "signatures";

use Exporter qw(import);
use PPI;
use Test2::V0;

no warnings "experimental::signatures";

our @EXPORT_OK = qw(find_violations count_violations good bad);

sub find_violations ($policy, $code) {
  my $doc = PPI::Document->new(\$code);
  my @violations;

  # Get the types this policy applies to
  my @applies_to = $policy->applies_to;

  # Handle policies that apply to PPI::Document directly
  if (@applies_to == 1 && $applies_to[0] eq "PPI::Document") {
    push @violations, $policy->violates($doc, $doc);
    return @violations;
  }

  # Handle policies that apply to specific element types
  for my $type (@applies_to) {
    $doc->find(
      sub ($top, $elem) {
        push @violations, $policy->violates($elem, $doc) if $elem->isa($type);
        0
      }
    );
  }

  @violations
}

sub count_violations ($policy, $code, $expected_violations, $description) {
  my @violations = find_violations($policy, $code);
  Test2::V0::is @violations, $expected_violations, $description;
  @violations
}

sub good ($policy, $code, $description) {
  count_violations($policy, $code, 0, $description);
}

sub bad ($policy, $code, $expected_message, $description) {
  my @violations = find_violations($policy, $code);
  Test2::V0::is @violations, 1, "$description - should have one violation";
  Test2::V0::like $violations[0]->explanation, qr/\Q$expected_message\E/,
    "$description - should suggest $expected_message";
}

1;
