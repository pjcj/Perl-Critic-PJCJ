package Perl::Critic::Policy::ValuesAndExpressions::RequireOptimalQuoteDelimiters;

use v5.20.0;
use strict;
use warnings;
use feature "signatures";
no warnings "experimental::signatures";

use Readonly ();

use Perl::Critic::Utils qw( $SEVERITY_MEDIUM );
use base "Perl::Critic::Policy";

our $VERSION = "0.001";

Readonly::Scalar my $DESC => q(Use optimal quote delimiters to minimize escaping);
Readonly::Scalar my $EXPL =>
  q(Choose (), [], or {} delimiters that require the fewest escape characters);

sub supported_parameters { return () }
sub default_severity     { return $SEVERITY_MEDIUM }
sub default_themes       { return qw( cosmetic ) }
sub applies_to {
  return qw(
    PPI::Token::Quote::Literal
    PPI::Token::Quote::Interpolate
    PPI::Token::QuoteLike::Words
    PPI::Token::QuoteLike::Command
    PPI::Token::QuoteLike::Regexp
  );
}

sub violates ($self, $elem, $) {
  # Get current delimiters and content by parsing the token
  my ($current_start, $current_end, $content, $operator) = $self->_parse_quote_token($elem);
  return unless defined $current_start;  # Skip if parsing failed

  # Skip empty content - any delimiter is fine for empty quotes
  return if $content eq "";

  # Find optimal delimiter and check if current is suboptimal
  my ($optimal_delim, $current_is_optimal) = $self->_find_optimal_delimiter($content, $operator, $current_start, $current_end);

  # Check if current delimiter is suboptimal
  if (!$current_is_optimal) {
    return $self->violation(
      $DESC,
      "$EXPL (consider using $optimal_delim->{display})",
      $elem
    );
  }

  return;
}

sub _parse_quote_token ($self, $elem) {
  my $content = $elem->content();

  # Parse quote-like operators: qw{}, q{}, qq{}, qx{}, qr{}
  # Order matters: longer matches first
  if ($content =~ /\A(qw|qq|qx|qr|q)\s*(.)(.*)\z/s) {
    my ($op, $start_delim, $rest) = ($1, $2, $3);
    my $end_delim = $start_delim;

    # Handle bracket pairs
    if ($start_delim eq "(") { $end_delim = ")"; }
    elsif ($start_delim eq "[") { $end_delim = "]"; }
    elsif ($start_delim eq "{") { $end_delim = "}"; }
    elsif ($start_delim eq "<") { $end_delim = ">"; }

    # Remove the ending delimiter from the content
    $rest =~ s/\Q$end_delim\E\z//;

    return ($start_delim, $end_delim, $rest, $op);
  }

  return;  # Parsing failed
}

sub _find_optimal_delimiter ($self, $content, $operator = "qw", $current_start = "", $current_end = "") {
  my @delimiters = (
    { start => "(", end => ")", display => "${operator}()", chars => ["(", ")"] },
    { start => "[", end => "]", display => "${operator}[]", chars => ["[", "]"] },
    { start => "{", end => "}", display => "${operator}{}", chars => ["{", "}"] },
  );

  # Count escape chars needed for each delimiter
  for my $delim (@delimiters) {
    my $count = 0;
    for my $char (@{$delim->{chars}}) {
      $count += () = $content =~ /\Q$char\E/g;
    }
    $delim->{escape_count} = $count;
  }

  # Find minimum escape count
  my $min_count = (sort { $a <=> $b } map { $_->{escape_count} } @delimiters)[0];

  # Return the preferred optimal delimiter (first one with min count)
  my ($optimal) = sort {
    $a->{escape_count} <=> $b->{escape_count}
  } @delimiters;

  # Check if current delimiter is optimal:
  # Current delimiter is optimal if:
  # 1. It has strictly fewer escapes than other options, OR
  # 2. It's the preferred delimiter when escape counts are equal
  my $current_is_optimal = 0;
  for my $delim (@delimiters) {
    if ($delim->{start} eq $current_start && $delim->{end} eq $current_end) {
      # Is current delimiter strictly better (fewer escapes)?
      my $strictly_better = $delim->{escape_count} < $optimal->{escape_count};
      # Is current delimiter the preferred choice when tied?
      my $preferred_when_tied = ($delim eq $optimal && $delim->{escape_count} == $min_count);

      $current_is_optimal = $strictly_better || $preferred_when_tied;
      last;
    }
  }

  return ($optimal, $current_is_optimal);
}

1;

__END__

=pod

=head1 NAME

Perl::Critic::Policy::ValuesAndExpressions::RequireOptimalQuoteDelimiters - Use
optimal quote delimiters to minimize escaping

=head1 SYNOPSIS

  # Bad:
  my @words = qw{word(with)parens};     # {} requires no escaping, but () would be better
  my $regex = qr{pattern[with]brackets}; # {} requires no escaping, but [] would be better

  # Good:
  my @words = qw(word(with)parens);     # () requires 2 escapes for parens
  my $regex = qr[pattern[with]brackets]; # [] requires 2 escapes for brackets
  my $simple = qw{simple words};        # {} is optimal - no delimiters in content

=head1 AFFILIATION

This Policy is part of the Perl::Critic::Strings distribution.

=head1 DESCRIPTION

This policy requires that quote-like operators (C<q{}>, C<qq{}>, C<qw{}>, C<qx{}>, 
C<qr//>) use the delimiter that requires the fewest escape characters. The policy 
considers three preferred delimiters in order: parentheses C<()>, square brackets 
C<[]>, and curly braces C<{}>.

For each delimiter type, the policy counts how many characters in the quoted content 
would need escaping, and recommends the delimiter requiring the fewest escapes.

This policy only applies to explicit quote operators like C<qw{}>, not to simple 
quoted strings like C<'string'> or C<"string">.

=head1 CONFIGURATION

This Policy is not configurable except for the standard options.

=head1 EXAMPLES

Bad:

    my @list = qw{word(with)parens};      # should use qw() - parens need escaping anyway
    my $cmd = qx{command[with]brackets};  # should use qx[] - brackets need escaping
    my $str = qq{text[and]braces};        # should use qq[] - brackets need escaping

Good:

    my @list = qw(word(with)parens);      # () optimal - content has parens
    my $cmd = qx[command[with]brackets];  # [] optimal - content has brackets  
    my $str = qq[text[and]braces];        # [] optimal - content has brackets
    my $simple = qw{no delimiters here};  # {} optimal - no special chars

Acceptable (no better alternative):

    my $complex = qw{has(parens)[and]{braces}}; # all delimiters appear in content
    my $equal = qw(one[bracket)];               # () and [] tied, () preferred

=head1 AUTHOR

Paul Johnson C<< <paul@pjcj.net> >>

=head1 COPYRIGHT

Copyright (c) 2025 Paul Johnson.

=head1 LICENSE

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut