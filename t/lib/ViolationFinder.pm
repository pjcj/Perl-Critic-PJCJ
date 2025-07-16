package ViolationFinder;

use v5.20.0;
use strict;
use warnings;
use feature "signatures";

use Exporter qw(import);
use PPI;

no warnings "experimental::signatures";

our @EXPORT_OK = qw(find_violations);

sub find_violations ($policy, $code) {
  my $doc = PPI::Document->new(\$code);
  my @violations;

  # Get the types this policy applies to
  my @applies_to = $policy->applies_to();

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
        0  # Don't descend further
      }
    );
  }

  @violations
}

1;
