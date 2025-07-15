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

  # Find all elements the policy applies to
  state @element_types = qw(
    PPI::Token::Quote::Single
    PPI::Token::Quote::Double
    PPI::Token::Quote::Literal
    PPI::Token::Quote::Interpolate
    PPI::Token::QuoteLike::Words
    PPI::Token::QuoteLike::Command
  );

  for my $type (@element_types) {
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
