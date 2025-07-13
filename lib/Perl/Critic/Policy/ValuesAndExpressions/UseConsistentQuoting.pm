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
  q(Choose (), [], <> or {} delimiters that require the fewest escape characters);

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
  my $content     = $elem->content;
  my $has_escapes = $content =~ /\\/;

  # Check if this is a "simple" string - no double quotes, @ symbols, or escapes
  if (!$has_escapes && $self->_is_simple_string($string)) {
    return $self->violation($DESC, $EXPL_DOUBLE, $elem);
  }

  return;
}

sub _check_quote_operators ($self, $elem) {
  # Get current delimiters and content by parsing the token
  my ($current_start, $current_end, $content, $operator)
    = $self->_parse_quote_token($elem);
  return unless defined $current_start;  # Skip if parsing failed

  # Check all delimiters, including exotic ones

  # Don't skip empty content - () is preferred even for empty quotes

  # Find optimal delimiter and check if current is suboptimal
  my ($optimal_delim, $current_is_optimal)
    = $self->_find_optimal_delimiter($content, $operator, $current_start,
      $current_end);

  # Check if current delimiter is suboptimal
  if (!$current_is_optimal) {
    return $self->violation($DESC,
      "$EXPL_OPTIMAL (hint: use $optimal_delim->{display})", $elem);
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
  # Handle all possible delimiters, not just bracket pairs
  # Order matters: longer matches first
  if ($content =~ /\A(qw|qq|qx|qr|q)\s*(.)(.*)\z/s) {
    my ($op, $start_delim, $rest) = ($1, $2, $3);
    my $end_delim = $start_delim;

    # Handle bracket pairs - they have different start/end delimiters
    if    ($start_delim eq "(") { $end_delim = ")" }
    elsif ($start_delim eq "[") { $end_delim = "]" }
    elsif ($start_delim eq "{") { $end_delim = "}" }
    elsif ($start_delim eq "<") { $end_delim = ">" }
    # For all other delimiters (/, |, ", ', #, !, %, &, ~, etc.)
    # the start and end delimiter are the same

    # Remove the ending delimiter from the content
    $rest =~ s/\Q$end_delim\E\z//;

    return ($start_delim, $end_delim, $rest, $op);
  }

  return;  # Parsing failed
}

sub _find_optimal_delimiter (
  $self, $content,
  $operator      = "qw",
  $current_start = "",
  $current_end   = "",
) {
  # Only support bracket operators - any other delimiter should be replaced
  my @delimiters = (
    {
      start   => "(",
      end     => ")",
      display => "${operator}()",
      chars   => [ "(", ")" ],
    }, {
      start   => "[",
      end     => "]",
      display => "${operator}[]",
      chars   => [ "[", "]" ],
    }, {
      start   => "<",
      end     => ">",
      display => "${operator}<>",
      chars   => [ "<", ">" ],
    }, {
      start   => "{",
      end     => "}",
      display => "${operator}{}",
      chars   => [ "{", "}" ],
    },
  );

  # Count escape chars needed for each delimiter
  # Escape count = number of delimiter chars that appear in the content
  for my $delim (@delimiters) {
    my $count = 0;
    for my $char (@{ $delim->{chars} }) {
      $count += () = $content =~ /\Q$char\E/g;
    }
    $delim->{escape_count} = $count;
  }

  # Find minimum escape count
  my $min_count = (sort { $a <=> $b } map { $_->{escape_count} } @delimiters)[0];

  # Find optimal delimiter: minimize escapes, then preference order
  my ($optimal) = sort {
    $a->{escape_count} <=> $b->{escape_count} ||    # Minimize escapes first
      $self->_delimiter_preference_order($a->{start}) <=>  # Then prefer by order
      $self->_delimiter_preference_order($b->{start})
  } @delimiters;

  # Check if current delimiter is a bracket operator
  my $current_is_bracket = 0;
  my $current_delim;
  for my $delim (@delimiters) {
    if ($delim->{start} eq $current_start && $delim->{end} eq $current_end) {
      $current_delim = $delim;
      $current_is_bracket = 1;
      last;
    }
  }

  # If current delimiter is not a bracket operator, it's never optimal
  # If current delimiter is a bracket operator, check if it's the optimal one
  my $current_is_optimal = 0;
  if ($current_is_bracket && $current_delim) {
    $current_is_optimal = ($current_delim eq $optimal);
  }

  return ($optimal, $current_is_optimal);
}

sub _delimiter_preference_order ($self, $delimiter_start) {
  # Preference order for bracket operators: () > [] > <> > {}
  return 0 if $delimiter_start eq "(";
  return 1 if $delimiter_start eq "[";
  return 2 if $delimiter_start eq "<";
  return 3 if $delimiter_start eq "{";
  return 99;  # Should never reach here for valid bracket operators
}

1;

__END__

=pod

=head1 NAME

Perl::Critic::Policy::ValuesAndExpressions::UseConsistentQuoting - Use
consistent and optimal quoting

=head1 SYNOPSIS

  # Bad:
  my $greeting = 'hello';                # simple string should use
                                          # double quotes
  my @words = qw{word(with)parens};     # should use qw() to minimize
                                         # escaping

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
(@) characters) should use double quotes rather than single quotes. The
rationale
is that double quotes are the "normal" case in Perl, and single quotes should be
reserved for cases where they are specifically needed to avoid interpolation or
escaping.

=item * Quote Operators

Quote-like operators (C<q()>, C<qq()>, C<qw()>, C<qx()>, C<qr()>) should use the
delimiter that requires the fewest escape characters. When multiple delimiters
require the same number of escapes, the policy prefers them in order:
parentheses C<()>, square brackets C<[]>, angle brackets C<< <> >>, and curly
braces C<{}>.

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

    my @list = qw{word(with)parens};      # should use qw[] - fewer escapes
    my $cmd = qx{command[with]brackets};  # should use qx() - fewer escapes
    my $regex = qr{text<with>angles};     # should use qr<> - fewer escapes
    my $simple = qw<no delimiters here>;  # should use qw() - preferred
    my $words = qw{simple words};         # should use qw() - preferred

Good:

    my @list = qw[word(with)parens];      # [] optimal - content has parentheses
    my $cmd = qx(command[with]brackets);  # () optimal - content has brackets
    my $regex = qr<text<with>angles>;     # <> optimal - content has angles
    my $simple = qw(no delimiters here);  # () preferred - no special chars
    my $words = qw(simple words);         # () preferred for simple content

=head1 AUTHOR

Paul Johnson C<< <paul@pjcj.net> >>

=head1 COPYRIGHT

Copyright (c) 2025 Paul Johnson.

=head1 LICENSE

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
