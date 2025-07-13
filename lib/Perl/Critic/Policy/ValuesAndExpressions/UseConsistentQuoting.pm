package Perl::Critic::Policy::ValuesAndExpressions::UseConsistentQuoting;

use v5.20.0;
use strict;
use warnings;
use feature "signatures";
no warnings "experimental::signatures";

use Readonly ();

use Perl::Critic::Utils qw( $SEVERITY_MEDIUM );
use base "Perl::Critic::Policy";

our $VERSION = "0.001";

Readonly::Scalar my $DESC => q(Use consistent and optimal quoting);
Readonly::Scalar my $EXPL_DOUBLE =>
  q[Simple strings (containing no double quotes or @ symbols) should use ]
  . q(double quotes for consistency);
Readonly::Scalar my $EXPL_OPTIMAL =>
  q(Choose (), [], or {} delimiters that require the fewest escape characters);

sub supported_parameters { return () }
sub default_severity     { return $SEVERITY_MEDIUM }
sub default_themes       { return qw( cosmetic ) }
sub applies_to {
  return qw(
    PPI::Token::Quote::Single
    PPI::Token::Quote::Literal
    PPI::Token::Quote::Interpolate
    PPI::Token::QuoteLike::Words
    PPI::Token::QuoteLike::Command
    PPI::Token::QuoteLike::Regexp
  );
}

sub violates ($self, $elem, $) {
  # Handle single-quoted strings
  if ($elem->isa("PPI::Token::Quote::Single")) {
    return $self->_check_single_quoted($elem);
  }

  # Handle quote-like operators
  return $self->_check_quote_operators($elem);
}

sub _check_single_quoted ($self, $elem) {
  # Get the string content without the surrounding quotes
  my $string = $elem->string;

  # Also check if the original content has any escapes
  my $content = $elem->content;
  my $has_escapes = $content =~ /\\/;

  # Check if this is a "simple" string - no double quotes, @ symbols, or escapes
  if (!$has_escapes && $self->_is_simple_string($string)) {
    return $self->violation($DESC, $EXPL_DOUBLE, $elem);
  }

  return;
}

sub _check_quote_operators ($self, $elem) {
  # Get current delimiters and content by parsing the token
  my ($current_start, $current_end, $content, $operator) = $self->_parse_quote_token($elem);
  return unless defined $current_start;  # Skip if parsing failed

  # Only check our preferred delimiters: (), [], {}
  return unless $current_start =~ /^[\(\[\{]$/;

  # Skip empty content - any delimiter is fine for empty quotes
  return if $content eq "";

  # Find optimal delimiter and check if current is suboptimal
  my ($optimal_delim, $current_is_optimal) = $self->_find_optimal_delimiter($content, $operator, $current_start, $current_end);

  # Check if current delimiter is suboptimal
  if (!$current_is_optimal) {
    return $self->violation(
      $DESC,
      "$EXPL_OPTIMAL (consider using $optimal_delim->{display})",
      $elem
    );
  }

  return;
}

sub _is_simple_string ($self, $string) {
  # Simple strings contain no double quotes or @ symbols
  return index($string, '"') == -1 && index($string, '@') == -1;
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

  # Count delimiter chars that appear in content
  for my $delim (@delimiters) {
    my $count = 0;
    for my $char (@{$delim->{chars}}) {
      $count += () = $content =~ /\Q$char\E/g;
    }
    $delim->{char_count} = $count;
  }

  # Determine optimal strategy based on content
  my $has_parens = $delimiters[0]->{char_count} > 0;
  my $has_brackets = $delimiters[1]->{char_count} > 0;
  my $has_braces = $delimiters[2]->{char_count} > 0;

  if ($has_parens && $has_brackets && $has_braces) {
    # All delimiters present - any is acceptable
    for my $delim (@delimiters) {
      $delim->{escape_count} = 0;  # All equally good
    }
  } elsif (!$has_parens && !$has_brackets && !$has_braces) {
    # No delimiters in content - prefer {} as default
    $delimiters[0]->{escape_count} = 1;  # ()
    $delimiters[1]->{escape_count} = 1;  # []
    $delimiters[2]->{escape_count} = 0;  # {} preferred
  } else {
    # Some delimiters present - prefer the ones that match content
    # Also allow () as acceptable when others are optimal (it's the preferred fallback)
    for my $delim (@delimiters) {
      if ($delim->{char_count} > 0) {
        $delim->{escape_count} = 0;  # Matching delimiters are optimal
      } elsif ($delim->{start} eq "(") {
        $delim->{escape_count} = 0;  # () is always acceptable as fallback
      } else {
        $delim->{escape_count} = 1;  # Other non-matching delimiters are suboptimal
      }
    }
  }

  # Find minimum escape count
  my $min_count = (sort { $a <=> $b } map { $_->{escape_count} } @delimiters)[0];

  # Return the preferred optimal delimiter (first one with min count)
  my ($optimal) = sort {
    $a->{escape_count} <=> $b->{escape_count}
  } @delimiters;

  # Check if current delimiter is optimal:
  # Current delimiter is optimal if:
  # 1. It has the minimum escape count, OR
  # 2. It's the preferred delimiter (first in list) when tied
  my $current_is_optimal = 0;
  my $current_delim;
  for my $delim (@delimiters) {
    if ($delim->{start} eq $current_start && $delim->{end} eq $current_end) {
      $current_delim = $delim;
      last;
    }
  }

  if ($current_delim) {
    # Current is optimal if it has the minimum escape count
    if ($current_delim->{escape_count} == $min_count) {
      $current_is_optimal = 1;
    }
  }

  return ($optimal, $current_is_optimal);
}

1;

__END__

=pod

=head1 NAME

Perl::Critic::Policy::ValuesAndExpressions::UseConsistentQuoting - Use consistent and optimal quoting

=head1 SYNOPSIS

  # Bad:
  my $greeting = 'hello';                # simple string should use double quotes
  my @words = qw{word(with)parens};     # should use qw() to minimize escaping

  # Good:
  my $greeting = "hello";               # simple string with double quotes
  my @words = qw(word(with)parens);     # optimal delimiter choice

=head1 AFFILIATION

This Policy is part of the Perl::Critic::Strings distribution.

=head1 DESCRIPTION

This policy combines two quoting requirements:

=over 4

=item * Simple Strings

"Simple" strings (those containing no double quote characters (") and no at-sign
(@) characters) should use double quotes rather than single quotes. The rationale
is that double quotes are the "normal" case in Perl, and single quotes should be
reserved for cases where they are specifically needed to avoid interpolation or
escaping.

=item * Quote Operators

Quote-like operators (C<q{}>, C<qq{}>, C<qw{}>, C<qx{}>, C<qr//>) should use the
delimiter that requires the fewest escape characters. The policy considers three
preferred delimiters in order: parentheses C<()>, square brackets C<[]>, and
curly braces C<{}>.

=back

=head1 CONFIGURATION

This Policy is not configurable except for the standard options.

=head1 EXAMPLES

=head2 Simple Strings

Bad:

    my $greeting = 'hello';        # simple string, should use double quotes
    my $name = 'world';            # simple string, should use double quotes

Good:

    my $greeting = "hello";        # simple string with double quotes
    my $name = "world";            # simple string with double quotes

    # These are acceptable with single quotes because they're not "simple"
    my $email = 'user@domain.com';      # contains @, so single quotes OK
    my $quoted = 'He said "hello"';     # contains ", so single quotes OK

=head2 Quote Operators

Bad:

    my @list = qw{word(with)parens};      # should use qw() - parens need escaping anyway
    my $cmd = qx{command[with]brackets};  # should use qx[] - brackets need escaping

Good:

    my @list = qw(word(with)parens);      # () optimal - content has parens
    my $cmd = qx[command[with]brackets];  # [] optimal - content has brackets
    my $simple = qw{no delimiters here};  # {} optimal - no special chars

=head1 AUTHOR

Paul Johnson C<< <paul@pjcj.net> >>

=head1 COPYRIGHT

Copyright (c) 2025 Paul Johnson.

=head1 LICENSE

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
