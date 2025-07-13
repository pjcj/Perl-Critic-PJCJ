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

Readonly::Scalar my $DESC => "Use consistent and optimal quoting";
Readonly::Scalar my $EXPL_DOUBLE =>
  "Simple strings should use double quotes for consistency";
Readonly::Scalar my $EXPL_SINGLE =>
  'Strings with literal $ or @ should use single quotes';
Readonly::Scalar my $EXPL_NO_QQ => 'Use "" instead of qq() when possible';
Readonly::Scalar my $EXPL_NO_Q  => "Use '' instead of q() when possible";
Readonly::Scalar my $EXPL_OPTIMAL =>
  "Choose (), [], <> or {} delimiters that require the fewest escape characters";

sub supported_parameters { return () }
sub default_severity     { return $SEVERITY_MEDIUM }
sub default_themes       { return qw( cosmetic ) }

sub applies_to {
  return qw(
    PPI::Token::Quote::Single
    PPI::Token::Quote::Double
    PPI::Token::Quote::Literal
    PPI::Token::Quote::Interpolate
    PPI::Token::QuoteLike::Words
    PPI::Token::QuoteLike::Command
  );
}

sub violates ($self, $elem, $) {
  # Handle single-quoted strings
  if ($elem->isa("PPI::Token::Quote::Single")) {
    return $self->_check_single_quoted($elem);
  }

  # Handle double-quoted strings
  if ($elem->isa("PPI::Token::Quote::Double")) {
    return $self->_check_double_quoted($elem);
  }

  # Handle q() strings (PPI::Token::Quote::Literal)
  if ($elem->isa("PPI::Token::Quote::Literal")) {
    return $self->_check_q_literal($elem);
  }

  # Handle qq() strings (PPI::Token::Quote::Interpolate)
  if ($elem->isa("PPI::Token::Quote::Interpolate")) {
    return $self->_check_qq_interpolate($elem);
  }

  # Handle other quote-like operators (qw, qx)
  return $self->_check_quote_operators($elem);
}

sub _check_single_quoted ($self, $elem) {
  # Get the string content without the surrounding quotes
  my $string = $elem->string;

  # Rule 1: Prefer interpolating quotes unless literal $ or @ OR content has double quotes
  # Single quotes are appropriate for:
  # 1. Strings with literal $ or @
  # 2. Strings that contain double quotes (to avoid escaping)

  if ($string !~ /[\$\@]/ && index($string, '"') == -1) {
    # No $ or @ and no double quotes, so should use double quotes per Rule 1
    return $self->violation($DESC, $EXPL_DOUBLE, $elem);
  }

  return;
}

sub _check_double_quoted ($self, $elem) {
  # Double quotes are generally preferred, so no violations for double-quoted strings
  # unless they contain literal $ or @ that shouldn't be interpolated
  # But we can't detect that reliably, so we accept all double-quoted strings
  return;
}

sub _check_q_literal ($self, $elem) {
  my $string = $elem->string;

  # First check if delimiter is optimal (Rule 2 & 5)
  my ($current_start, $current_end, $content, $operator)
    = $self->_parse_quote_token($elem);

  if (defined $current_start) {
    my ($optimal_delim, $current_is_optimal)
      = $self->_find_optimal_delimiter($content, $operator, $current_start,
        $current_end);

    if (!$current_is_optimal) {
      return $self->violation($DESC,
        "$EXPL_OPTIMAL (hint: use $optimal_delim->{display})", $elem);
    }
  }

  # Rule 4: Prefer simpler quotes to q() when content is simple
  # But q() is justified when content has special characteristics

  my $has_single_quotes = index($string, "'") != -1;
  my $has_double_quotes = index($string, '"') != -1;
  my $has_literal_vars  = $string =~ /[\$\@]/;

  # If content has both single and double quotes, q() is appropriate
  if ($has_single_quotes && $has_double_quotes) {
    return;  # q() is justified
  }

  # Check if content is truly "simple" - no special characters that justify q()
  my $has_special_chars = $string =~ /[|\/\"#!%&~()\[\]<>{}]/;

  # If simple content (no special chars, no $ or @ and doesn't require q() for quote conflicts)
  if (!$has_literal_vars && !$has_single_quotes && !$has_special_chars) {
    # Simple content should use double quotes per Rule 1
    return $self->violation($DESC, $EXPL_DOUBLE, $elem);
  }

  # If has literal vars but no single quotes, should use single quotes
  if ($has_literal_vars && !$has_single_quotes) {
    return $self->violation($DESC, $EXPL_NO_Q, $elem);
  }

  return;
}

sub _check_qq_interpolate ($self, $elem) {
  my $string = $elem->string;

  # First check if delimiter is optimal (Rule 2 & 5)
  my ($current_start, $current_end, $content, $operator)
    = $self->_parse_quote_token($elem);

  if (defined $current_start) {
    my ($optimal_delim, $current_is_optimal)
      = $self->_find_optimal_delimiter($content, $operator, $current_start,
        $current_end);

    if (!$current_is_optimal) {
      return $self->violation($DESC,
        "$EXPL_OPTIMAL (hint: use $optimal_delim->{display})", $elem);
    }
  }

  # Rule 3: Prefer "" to qq() when possible
  # Check if content can be represented as a simple double-quoted string
  if (index($string, '"') == -1) {
    # No double quotes in content, so can use ""
    return $self->violation($DESC, $EXPL_NO_QQ, $elem);
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

sub _parse_quote_token ($self, $elem) {
  my $content = $elem->content();

  # Parse quote-like operators: qw{}, q{}, qq{}, qx{}
  # Handle all possible delimiters, not just bracket pairs
  # Order matters: longer matches first
  if ($content =~ /\A(qw|qq|qx|q)\s*(.)(.*)\z/s) {
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
  my $min_count
    = (sort { $a <=> $b } map { $_->{escape_count} } @delimiters)[0];

  # Find optimal delimiter: minimize escapes, then preference order
  my ($optimal) = sort {
    $a->{escape_count} <=> $b->{escape_count} ||  # Minimize escapes first
      $self->_delimiter_preference_order($a->{start}) <=> # Then prefer by order
      $self->_delimiter_preference_order($b->{start})
  } @delimiters;

  # Check if current delimiter is a bracket operator
  my $current_is_bracket = 0;
  my $current_delim;
  for my $delim (@delimiters) {
    if ($delim->{start} eq $current_start && $delim->{end} eq $current_end) {
      $current_delim      = $delim;
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

Perl::Critic::Policy::ValuesAndExpressions::UseConsistentQuoting - Use consistent and optimal quoting

=head1 SYNOPSIS

  # Bad examples:
  my $greeting = 'hello';           # simple strings should use double quotes
  my @words = qw{word(with)parens}; # should use qw[] to avoid escaping
  my $text = qq(simple);            # should use "" instead of qq()
  my $file = q/path\/to\/file/;     # exotic delimiter needs escaping

  # Good examples:
  my $greeting = "hello";           # double quotes for simple strings
  my @words = qw[word(with)parens]; # optimal delimiter choice
  my $text = "simple";              # "" preferred over qq()
  my $file = "path/to/file";        # "" avoids escaping

=head1 DESCRIPTION

This policy enforces consistent quoting to improve code readability and maintainability.
It applies five priority rules in order:

=head2 Rule 1: Prefer double quotes for simple strings

Use double quotes (C<"">) as the default for most strings. Only use single quotes
when the string contains literal C<$> or C<@> that should not be interpolated.

  # Good
  my $name = "John";              # simple string uses double quotes
  my $email = 'user@domain.com';  # literal @ uses single quotes
  my $var = 'Price: $10';         # literal $ uses single quotes

  # Bad
  my $name = 'John';              # should use double quotes

=head2 Rule 2: Minimize escape characters

Choose delimiters that require the fewest backslash escapes.

  # Good
  my $path = "path/to/file";      # no escaping needed
  my @list = qw[word(with)parens xx]; # [] avoids escaping parentheses

  # Bad
  my $path = q/path\/to\/file/;   # requires escaping slashes
  my @list = qw(word\(with\)parens xx); # requires escaping parentheses

=head2 Rule 3: Prefer "" over qq()

Use simple double quotes instead of C<qq()> when possible.

  # Good
  my $text = "hello world";

  # Bad
  my $text = qq(hello world);

=head2 Rule 4: Prefer '' over q()

Use simple single quotes instead of C<q()> for literal strings.

  # Good
  my $literal = 'contains$literal';

  # Bad
  my $literal = q(contains$literal);

=head2 Rule 5: Use only bracket delimiters

Only use bracket delimiters C<()>, C<[]>, C<< <> >>, C<{}> for quote-like operators.
Choose the delimiter that minimizes escape characters. When escape counts are equal,
prefer them in this order: C<()>, C<[]>, C<< <> >>, C<{}>.

  # Good
  my @words = qw(simple list);     # () preferred when no escapes needed
  my @data = qw[has(parens)];      # [] optimal - avoids escaping ()
  my $cmd = qx(has[brackets]);     # () optimal - avoids escaping []
  my $text = q(has<angles>);       # () optimal - avoids escaping <>

  # Bad - exotic delimiters
  my @words = qw/word word/;       # should use qw()
  my $path = q|some|path|;         # should use ""
  my $text = qq#some#text#;        # should use ""

=head1 AFFILIATION

This Policy is part of the Perl::Critic::Strings distribution.

=head1 CONFIGURATION

This Policy is not configurable except for the standard options.

=head1 EXAMPLES

=head2 String Literals

  # Bad
  my $greeting = 'hello';          # Rule 1: should use double quotes
  my $email = "user@domain.com";   # Rule 1: should use single quotes (literal @)
  my $path = 'C:\Program Files';   # Rule 1: should use double quotes

  # Good
  my $greeting = "hello";          # double quotes for simple strings
  my $email = 'user@domain.com';   # single quotes for literal @
  my $path = "C:\\Program Files";  # double quotes allow escaping

=head2 Quote Operators

  # Bad
  my $simple = q(hello);           # Rule 4: should use ''
  my $text = qq(hello);            # Rule 3: should use ""
  my @words = qw/one two/;         # Rule 5: should use qw()
  my $cmd = qx|ls|;                # Rule 5: should use qx()

  # Good
  my $simple = 'hello$literal';    # single quotes for literal content
  my $text = "hello";              # double quotes preferred
  my @words = qw(one two);         # bracket delimiters only
  my $cmd = qx(ls);                # bracket delimiters only

=head2 Optimal Delimiter Selection

  # Bad - suboptimal escaping
  my @list = qw(word\(with\)parens);     # () requires escaping parentheses
  my $cmd = qx[command\[with\]brackets]; # [] requires escaping brackets
  my $text = q{word\{with\}braces};      # {} requires escaping braces

  # Good - minimal escaping
  my @list = qw[word(with)parens];       # [] avoids escaping parentheses
  my $cmd = qx(command[with]brackets);   # () avoids escaping brackets

=head2 Complex Content

  # When content has multiple delimiter types, choose the one requiring fewest escapes
  my $both = qq(has 'single' and "double" quotes); # qq() needed for both quote types

=head1 AUTHOR

Paul Johnson C<< <paul@pjcj.net> >>

=head1 COPYRIGHT

Copyright (c) 2025 Paul Johnson.

=head1 LICENSE

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
