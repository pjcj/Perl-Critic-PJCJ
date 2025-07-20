package Perl::Critic::Policy::ValuesAndExpressions::UseConsistentQuoting;

use v5.20.0;
use strict;
use warnings;
use feature "signatures";
no warnings "experimental::signatures";

use Perl::Critic::Utils qw( $SEVERITY_MEDIUM );
use parent "Perl::Critic::Policy";

# VERSION

my $Desc         = "Quoting";
my $Expl_double  = 'use ""';
my $Expl_single  = "use ''";
my $Expl_optimal = "use %s";
my $Expl_use_qw  = "use qw()";

sub supported_parameters { }
sub default_severity     { $SEVERITY_MEDIUM }
sub default_themes       { qw( cosmetic ) }

sub applies_to { qw(
  PPI::Token::Quote::Single
  PPI::Token::Quote::Double
  PPI::Token::Quote::Literal
  PPI::Token::Quote::Interpolate
  PPI::Token::QuoteLike::Words
  PPI::Token::QuoteLike::Command
  PPI::Statement::Include
) }

sub would_interpolate ($self, $string) {
  # Test if this string content would interpolate if put in double quotes
  # This is the authoritative way to check - let PPI decide
  my $test_content = qq("$string");
  my $test_doc     = PPI::Document->new(\$test_content);

  my $would_interpolate = 0;
  $test_doc->find(
    sub ($top, $test_elem) {
      $would_interpolate = $test_elem->interpolations
        if $test_elem->isa("PPI::Token::Quote::Double");
      0
    }
  );

  $would_interpolate
}

sub delimiter_preference_order ($self, $delimiter_start) {
  # Preference order for bracket operators: () > [] > <> > {}
  return 0 if $delimiter_start eq "(";
  return 1 if $delimiter_start eq "[";
  return 2 if $delimiter_start eq "<";
  return 3 if $delimiter_start eq "{";
  99  # Should never reach here for valid bracket operators
}

sub parse_quote_token ($self, $elem) {
  my $content = $elem->content;

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

    ($start_delim, $end_delim, $rest, $op)
  }
}

sub find_optimal_delimiter (
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

  # Find optimal delimiter: minimise escapes, then preference order
  my ($optimal) = sort {
    $a->{escape_count} <=> $b->{escape_count} ||  # Minimise escapes first
      $self->delimiter_preference_order($a->{start}) <=>  # Then prefer by order
      $self->delimiter_preference_order($b->{start})
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

  ($optimal, $current_is_optimal)
}

sub check_delimiter_optimisation ($self, $elem) {
  my ($current_start, $current_end, $content, $operator)
    = $self->parse_quote_token($elem);

  return unless defined $current_start;

  my ($optimal_delim, $current_is_optimal)
    = $self->find_optimal_delimiter($content, $operator, $current_start,
      $current_end);

  return $self->violation($Desc,
    sprintf($Expl_optimal, $optimal_delim->{display}), $elem)
    if !$current_is_optimal;

  undef
}

sub violates ($self, $elem, $) {
  state $dispatch = {
    "PPI::Token::Quote::Single"      => "check_single_quoted",
    "PPI::Token::Quote::Double"      => "check_double_quoted",
    "PPI::Token::Quote::Literal"     => "check_q_literal",
    "PPI::Token::Quote::Interpolate" => "check_qq_interpolate",
    "PPI::Token::QuoteLike::Words"   => "check_quote_operators",
    "PPI::Token::QuoteLike::Command" => "check_quote_operators",
    "PPI::Statement::Include"        => "check_use_statement",
  };

  my $class      = ref $elem;
  my $method     = $dispatch->{$class} or return;
  my @violations = grep { defined } $self->$method($elem);
  @violations
}

sub check_single_quoted ($self, $elem) {
  # Skip if this quote is part of a use statement argument
  return if $self->_is_in_use_statement($elem);

  # Get the string content without the surrounding quotes
  my $string  = $elem->string;
  my $content = $elem->content;

  # Rule 1: Prefer interpolating quotes unless literal $ or @ OR content has
  # double quotes
  #
  # Single quotes are appropriate for:
  # 1. Strings with literal $ or @ that shouldn't be interpolated
  # 2. Strings that contain double quotes (to avoid escaping)

  # Check if string has double quotes - then single quotes are justified
  return
    if index($string, '"')
    != -1;  # Single quotes justified to avoid escaping double quotes

  # Check if string has escaped single quotes - then double quotes are better
  return $self->violation($Desc, $Expl_double, $elem) if $content =~ /\\'/;

  # Use PPI's interpolations() method to test if this content would interpolate
  # in double quotes
  my $would_interpolate = $self->would_interpolate($string);

  # Check if string contains escape sequences that would have different meanings
  # in single vs double quotes. If so, preserve single quotes.
  return if $self->_has_dangerous_escape_sequences($string);

  # Also check for literal \$ and \@ in single quotes that would become
  # escaped sigils in double quotes, changing their meaning
  return if $self->_has_literal_escape_sigils($string);

  # If content would not interpolate in double quotes, suggest double quotes
  return $self->violation($Desc, $Expl_double, $elem)
    if !$would_interpolate && index($string, '"') == -1;

  return
}

sub check_double_quoted ($self, $elem) {
  # Skip if this quote is part of a use statement argument
  return if $self->_is_in_use_statement($elem);

  # Check if this double-quoted string actually needs interpolation
  my $string  = $elem->string;
  my $content = $elem->content;

  # Check for escaped dollar/at signs or double quotes, but only suggest single
  # quotes if no other interpolation exists
  return $self->violation($Desc, $Expl_single, $elem)
    if $content =~ /\\[\$\@\"]/ && !$self->would_interpolate($string);

  return
}

sub check_q_literal ($self, $elem) {
  # Skip if this quote is part of a use statement argument
  return if $self->_is_in_use_statement($elem);

  my $string = $elem->string;

  # Check if string contains escape sequences that would have different meanings
  # in single vs double quotes. If so, preserve q() quoting.
  return if $self->_has_dangerous_escape_sequences($string);

  # Check if string contains literal \$ or \@ that would become escaped
  # in double quotes. If so, preserve q() quoting.
  return if $self->_has_literal_escape_sigils($string);

  # Apply simplified rules: prefer simpler quotes if possible, then
  # optimize delimiter
  my $has_single_quotes = index($string, "'") != -1;
  my $has_double_quotes = index($string, '"') != -1;
  my $would_interpolate = $self->would_interpolate($string);

  # Has both quote types - q() avoids escaping
  return $self->check_delimiter_optimisation($elem)
    if $has_single_quotes && $has_double_quotes;

  if ($has_single_quotes) {
    return $would_interpolate
      # Has single quotes and would interpolate - single quotes would need
      # escaping, double quotes would interpolate
      ? $self->check_delimiter_optimisation($elem)
      # Only has single quotes, no interpolation - double quotes simpler
      : $self->violation($Desc, $Expl_double, $elem);
  }

  if ($has_double_quotes) {
    return $would_interpolate
      # Has double quotes and would interpolate - single quotes would need
      # escaping, double quotes would interpolate
      ? $self->check_delimiter_optimisation($elem)
      # Only has double quotes, no interpolation - single quotes simpler
      : $self->violation($Desc, $Expl_single, $elem);
  }

  # Simple content without quotes - prefer simpler quotes
  return $self->violation($Desc, $Expl_single, $elem) if $would_interpolate;

  $self->violation($Desc, $Expl_double, $elem)
}

sub check_qq_interpolate ($self, $elem) {
  # Skip if this quote is part of a use statement argument
  return if $self->_is_in_use_statement($elem);

  my $string = $elem->string;

  # Check if string contains escape sequences. For qq(), these would be
  # interpreted, so preserve qq() if switching to single quotes would
  # change the meaning (escape sequences become literal in single quotes).
  if ($self->_has_dangerous_escape_sequences($string)) {
    # Only preserve qq() if the escape sequences are actually needed
    # (i.e., if we want them interpreted, not literal)
    return $self->check_delimiter_optimisation($elem);
  }

  # Apply simplified rules: prefer double quotes, then check if qq() justified
  my $double_quote_suggestion
    = $self->_what_would_double_quotes_suggest($string);

  # Rule 1: If double quotes would suggest single quotes, use single quotes
  if ($double_quote_suggestion && $double_quote_suggestion eq "''") {
    # qq() is only justified if it avoids escaping double quotes
    return if index($string, '"') != -1;
    return $self->violation($Desc, $Expl_single, $elem);
  }

  # Rule 2: If double quotes would suggest qq(), qq() is appropriate
  if ($double_quote_suggestion && $double_quote_suggestion eq "qq()") {
    return $self->check_delimiter_optimisation($elem);
  }

  # Rule 3: Otherwise prefer simple double quotes unless delimiter chars present
  my $has_special_chars
    = index($string, '"') != -1
    || index($string, "'") != -1
    || $self->would_interpolate($string);

  if (!$has_special_chars) {
    return $self->violation($Desc, $Expl_double, $elem);
  }

  # If qq() is justified, optimize delimiter
  return $self->check_delimiter_optimisation($elem);
}

sub check_quote_operators ($self, $elem) {
  # Skip if this quote is part of a use statement argument
  return if $self->_is_in_use_statement($elem);

  # Get current delimiters and content by parsing the token
  my ($current_start, $current_end, $content, $operator)
    = $self->parse_quote_token($elem);
  return unless defined $current_start;  # Skip if parsing failed

  # Check all delimiters, including exotic ones

  # Don't skip empty content - () is preferred even for empty quotes

  # Find optimal delimiter and check if current is suboptimal
  my ($optimal_delim, $current_is_optimal)
    = $self->find_optimal_delimiter($content, $operator, $current_start,
      $current_end);

  # Check if current delimiter is suboptimal
  return $self->violation($Desc,
    sprintf($Expl_optimal, $optimal_delim->{display}), $elem)
    if !$current_is_optimal;

  return
}

sub check_use_statement ($self, $elem) {
  # Only check 'use' statements, not 'require' or 'no'
  return unless $elem->type eq "use";

  my @args = $self->_extract_use_arguments($elem);
  return unless @args;

  my ($string_count, $has_qw, $qw_uses_parens)
    = $self->_analyze_use_arguments(@args);
  return $self->_check_use_violations($elem, $string_count, $has_qw,
    $qw_uses_parens, @args);
}

sub _extract_use_arguments ($self, $elem) {
  my @children     = $elem->children;
  my $found_module = 0;
  my @args;

  for my $child (@children) {
    if ($child->isa("PPI::Token::Word") && !$found_module) {
      # Skip the 'use' keyword
      next if $child->content eq "use";
      # This is the module name
      $found_module = 1;
      next;
    }

    # Collect arguments after the module name
    if ($found_module) {
      next if $child->isa("PPI::Token::Whitespace");
      next if $child->isa("PPI::Token::Structure") && $child->content eq ";";
      push @args, $child;
    }
  }

  return @args;
}

sub _analyze_use_arguments ($self, @args) {
  my $string_count   = 0;
  my $has_qw         = 0;
  my $qw_uses_parens = 1;

  for my $arg (@args) {
    $self->_count_use_arguments($arg, \$string_count, \$has_qw,
      \$qw_uses_parens);
  }

  return ($string_count, $has_qw, $qw_uses_parens);
}

sub _check_use_violations ($self, $elem, $string_count, $has_qw,
  $qw_uses_parens, @args,)
{
  my @violations;

  # Check for single quotes in single arguments
  if ($string_count == 1 && !$has_qw) {
    for my $arg (@args) {
      if ($arg->isa("PPI::Token::Quote::Single")) {
        push @violations, $self->violation($Desc, $Expl_use_qw, $elem);
        last;
      }
    }
  }

  # Check for multiple arguments without qw()
  if ($string_count > 1 && !$has_qw) {
    push @violations, $self->violation($Desc, $Expl_use_qw, $elem);
  }

  # Check for mixed usage (both strings and qw())
  if ($string_count > 0 && $has_qw) {
    push @violations, $self->violation($Desc, $Expl_use_qw, $elem);
  }

  # Check for qw() not using parentheses
  if ($has_qw && !$qw_uses_parens) {
    push @violations, $self->violation($Desc, $Expl_use_qw, $elem);
  }

  return @violations;
}

sub _count_use_arguments ($self, $elem, $string_count_ref, $has_qw_ref,
  $qw_uses_parens_ref,)
{

  if ( $elem->isa("PPI::Token::Quote::Single")
    || $elem->isa("PPI::Token::Quote::Double")
    || $elem->isa("PPI::Token::Quote::Literal")
    || $elem->isa("PPI::Token::Quote::Interpolate"))
  {
    $$string_count_ref++;
  }

  if ($elem->isa("PPI::Token::QuoteLike::Words")) {
    $$has_qw_ref = 1;
    # Check if qw uses parentheses
    my $content = $elem->content;
    if ($content !~ /\Aqw\s*\(/) {
      $$qw_uses_parens_ref = 0;
    }
  }

  # Recursively check children (for structures like lists)
  if ($elem->can("children")) {
    for my $child ($elem->children) {
      $self->_count_use_arguments($child, $string_count_ref, $has_qw_ref,
        $qw_uses_parens_ref);
    }
  }
}

sub _is_in_use_statement ($self, $elem) {
  # Walk up the parent tree to see if this element is inside a use statement
  my $current = $elem;
  while ($current) {
    return 1
      if $current->isa("PPI::Statement::Include") && $current->type eq "use";
    $current = $current->parent;
  }
  return 0;
}

sub _what_would_double_quotes_suggest ($self, $string) {
  # Apply simplified rules: prefer single quotes if literal sigils,
  # qq() if needs escaping
  my $would_interpolate = $self->would_interpolate($string);

  # Rule 1: If has escaped variables but no interpolation → suggest
  # single quotes
  return "''" if !$would_interpolate && ($string =~ /\\[\$\@]/);

  # Rule 2: If has quotes and needs escaping → suggest qq()
  my $has_single_quotes = index($string, "'") != -1;
  my $has_double_quotes = index($string, '"') != -1;

  if ($has_double_quotes) {
    return "qq()" if $would_interpolate || $has_single_quotes;
    return "''"   if !$has_single_quotes; # Only double quotes, no interpolation
  }

  # Rule 3: Otherwise double quotes are fine
  return undef;
}

sub _has_dangerous_escape_sequences ($self, $string) {
  # Check if string contains escape sequences that would have different meanings
  # in single vs double quotes. These should be preserved in their current
  # quote style to maintain their intended meaning.
  #
  # This only includes escape sequences where the conversion would change
  # the actual output, not just the internal representation.
  return $string =~ /
    \\(?:
      [tnrfbae]           |  # Single char escapes: \t \n \r \f \b \a \e
      x[0-9a-fA-F]*       |  # Hex escapes: \x1b \xff
      x\{[^}]*\}          |  # Hex braces: \x{1b} \x{263A}
      [0-7]{1,3}          |  # Octal: \033 \377
      o\{[^}]*\}          |  # Octal braces: \o{033}
      c.                  |  # Control chars: \c[ \cA
      N\{[^}]*\}             # Named chars: \N{name} \N{U+263A}
    )
  /x;
}

sub _has_literal_escape_sigils ($self, $string) {
  # Check if string contains literal \$ or \@ that would have different
  # meanings between single and double quotes when converting FROM
  # single quotes TO double quotes (not the other direction).
  return $string =~ /\\[\$\@]/;
}

1;

__END__

=pod

=head1 NAME

Perl::Critic::Policy::ValuesAndExpressions::UseConsistentQuoting - Use
consistent and optimal quoting

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

This policy enforces consistent quoting to improve code readability and
maintainability. It applies five priority rules in order:

=head2 Rule 1: Prefer double quotes for simple strings

Use double quotes (C<"">) as the default for most strings. Only use single
quotes when the string contains literal C<$> or C<@> that should not be
interpolated.

  # Good
  my $name = "John";              # simple string uses double quotes
  my $email = 'user@domain.com';  # literal @ uses single quotes
  my $var = 'Price: $10';         # literal $ uses single quotes

  # Bad
  my $name = 'John';              # should use double quotes

=head2 Rule 2: Minimise escape characters

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

Only use bracket delimiters C<()>, C<[]>, C<< <> >>, C<{}> for quote-like
operators. Choose the delimiter that minimises escape characters. When escape
counts are equal, prefer them in this order: C<()>, C<[]>, C<< <> >>, C<{}>.

  # Good
  my @words = qw(simple list);     # () preferred when no escapes needed
  my @data = qw[has(parens)];      # [] optimal - avoids escaping ()
  my $cmd = qx(has[brackets]);     # () optimal - avoids escaping []
  my $text = q(has<angles>);       # () optimal - avoids escaping <>

  # Bad - exotic delimiters
  my @words = qw/word word/;       # should use qw()
  my $path = q|some|path|;         # should use ""
  my $text = qq#some#text#;        # should use ""

=head2 Special Case: Use statements

Use statements have special quoting requirements for their import lists:

=over 4

=item * Modules with no arguments or empty parentheses are acceptable

=item * Modules with one argument may use double quotes C<""> or C<qw( )>

=item * Modules with multiple arguments must use C<qw( )> with parentheses only

=back

  # Good
  use Foo;                         # no arguments
  use Bar ();                      # empty parentheses
  use Baz "single_arg";            # one argument with double quotes
  use Qux qw( single_arg );        # one argument with qw()
  use Quux qw( arg1 arg2 arg3 );   # multiple arguments with qw()

  # Bad
  use Foo 'single_arg';            # single quotes not allowed
  use Bar "arg1", "arg2";          # multiple arguments need qw()
  use Baz qw[ arg1 arg2 ];         # qw() must use parentheses only
  use Qux qw{ arg1 arg2 };         # qw() must use parentheses only

=head2 Here's a different take on the rules:

1. Reduce punctuation

Prefer fewer escaped characters.  Prefer real quotes over quote-like operators.

2. Prefer interpolated strings

If it doesn't matter whether a string is interpolated or not, prefer the
interpolated version.

3. If the best choice is a quote-like operator, prefer `()`, `[]`, `<>`, or `{}`
   in that order to break the tie.

The special case for C<use> statements still applies.

=head1 AFFILIATION

This Policy is part of the Perl::Critic::PJCJ distribution.

=head1 CONFIGURATION

This Policy is not configurable except for the standard options.

=head1 EXAMPLES

=head2 String Literals

  # Bad
  my $greeting = 'hello';          # Rule 1: should use double quotes
  my $email = "user@domain.com";   # Rule 1: should use single quotes
                                   # (literal @)
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

  # When content has multiple delimiter types, choose the one requiring
  # fewest escapes
  my $both = qq(has 'single' and "double" quotes); # qq() needed for both
                                                   # quote types

=head2 Use Statement Examples

  # Bad
  use Foo 'single_arg';            # single quotes not allowed
  use Bar "arg1", "arg2";          # multiple args need qw()
  use Baz qw[ arg1 arg2 ];         # qw() must use parentheses
  use Qux qw{ arg1 arg2 arg3 };    # qw() must use parentheses

  # Good
  use Foo;                         # no arguments allowed
  use Bar ();                      # empty parentheses allowed
  use Baz "single_arg";            # one argument with double quotes
  use Qux qw( single_arg );        # one argument with qw()
  use Quux qw( arg1 arg2 arg3 );   # multiple arguments with qw() only

=head1 METHODS

=head2 violates

The main entry point for policy violation checking. Uses a dispatch table to
route different quote token types to their appropriate checking methods. This
design allows for efficient handling of the six different PPI token types that
represent quoted strings and quote-like operators.

=head2 would_interpolate

Determines whether a string would perform variable interpolation if placed in
double quotes. This is critical for deciding between single and double quotes -
strings that would interpolate variables should use single quotes to preserve
literal content, while non-interpolating strings should use double quotes for
consistency.

Uses PPI's authoritative parsing to detect interpolation rather than regex
patterns, ensuring accurate detection of complex cases like escaped variables.

=head2 delimiter_preference_order

Establishes the preference hierarchy for bracket delimiters when multiple
options require the same number of escape characters. The policy prefers
delimiters in this order: C<()> > C<[]> > C<< <> >> > C<{}>.

This ordering balances readability and convention - parentheses are most
familiar and commonly used, while braces are often reserved for hash
references and blocks.

=head2 parse_quote_token

Extracts delimiter and content information from quote-like operators such as
C<qw{}>, C<q{}>, C<qq{}>, and C<qx{}>. Handles both bracket pairs (where start
and end delimiters differ) and symmetric delimiters (where they're the same).

This parsing is essential for delimiter optimisation, as it separates the
operator, delimiters, and content for independent analysis.

=head2 find_optimal_delimiter

Determines the best delimiter choice for a quote-like operator by analysing the
content and counting required escape characters. Implements the core logic for
Rules 2 and 5: minimise escapes and prefer bracket delimiters.

Only considers bracket delimiters C<()>, C<[]>, C<< <> >>, C<{}> as valid
options, rejecting exotic delimiters like C</>, C<|>, C<#> regardless of their
escape count. When escape counts are tied, uses the preference order to break
ties.

=head2 check_delimiter_optimisation

Validates that quote-like operators use optimal delimiters according to Rules 2
and 5. This method coordinates parsing the current token and finding the
optimal alternative, issuing violations when the current choice is suboptimal.

Acts as a bridge between the parsing and optimisation logic, providing a
clean interface for the quote-checking methods.

=head2 check_single_quoted

Enforces Rule 1 for single-quoted strings: prefer double quotes for simple
strings unless the content contains literal C<$> or C<@> characters that
shouldn't be interpolated, or the string contains double quotes that would
require escaping.

Also detects when C<q()> operators would be better than single quotes with
escape characters, promoting cleaner alternatives.

=head2 check_double_quoted

Validates double-quoted strings to ensure they genuinely need interpolation.
Suggests single quotes when the content contains only escaped C<$> or C<@>
characters with no actual interpolation, as this indicates the developer
intended literal content.

This prevents unnecessary escaping and makes the code's intent clearer.

=head2 check_q_literal

Enforces Rules 2, 4, and 5 for C<q()> operators. First ensures optimal
delimiter choice, then evaluates whether simpler quote forms would be more
appropriate.

Allows C<q()> when the content has both single and double quotes (making it
the cleanest option), but suggests simpler alternatives for basic content that
could use C<''> or C<"">.

=head2 check_qq_interpolate

Enforces Rules 2, 3, and 5 for C<qq()> operators. First ensures optimal
delimiter choice, then determines whether simple double quotes would suffice.

The policy prefers C<""> over C<qq()> when the content doesn't contain double
quotes, as this reduces visual noise and follows common Perl conventions.

=head2 check_quote_operators

Handles C<qw()> and C<qx()> operators, focusing purely on delimiter
optimisation according to Rules 2 and 5. These operators don't have simpler
alternatives, so the policy only ensures they use the most appropriate
delimiters to minimise escape characters.

=head1 AUTHOR

Paul Johnson C<< <paul@pjcj.net> >>

=head1 COPYRIGHT

Copyright 2025 Paul Johnson.

=head1 LICENCE

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
