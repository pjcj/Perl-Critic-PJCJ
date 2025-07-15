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
  my @element_types = qw(
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
        return 0 unless $elem->isa($type);

        my $violation = $policy->violates($elem, $doc);
        push @violations, $violation if $violation;

        return 0;  # Don't descend further
      }
    );
  }

  return @violations;
}

1;