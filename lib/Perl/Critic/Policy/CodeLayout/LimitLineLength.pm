package Perl::Critic::Policy::CodeLayout::LimitLineLength;

use v5.20.0;
use strict;
use warnings;
use feature "signatures";
no warnings "experimental::signatures";

use Perl::Critic::Utils qw( $SEVERITY_MEDIUM );
use parent "Perl::Critic::Policy";
use PPI;

# VERSION

my $Desc = "Line exceeds maximum length";
my $Expl = "Keep lines under the configured maximum for readability";

sub supported_parameters { {
  name            => "max_line_length",
  description     => "Maximum allowed line length in characters",
  default_string  => "80",
  behavior        => "integer",
  integer_minimum => 1,
} }

sub default_severity { $SEVERITY_MEDIUM }
sub default_themes   { qw( cosmetic formatting ) }

sub applies_to { "PPI::Document" }

sub violates ($self, $elem, $doc) {
  my $max_length = $self->{_max_line_length};
  my $source     = $doc->serialize;
  my @lines      = split /\n/, $source;

  my @violations;
  for my $line_num (0 .. $#lines) {
    my $length = length $lines[$line_num];
    if ($length > $max_length) {
      my $violation_desc
        = "Line is $length characters long (exceeds $max_length)";

      # Find a token on this line for accurate line number reporting
      my $line_token = $self->_find_token_on_line($doc, $line_num + 1);

      push @violations,
        $self->violation($violation_desc, $Expl, $line_token || $elem);
    }
  }

  @violations
}

sub _find_token_on_line ($self, $doc, $target_line) {
  my $found_token;

  $doc->find(
    sub ($top, $elem) {
      return 0 unless $elem->isa("PPI::Token");

      my $line = $elem->line_number;
      if (defined $line && $line == $target_line) {
        $found_token = $elem;
        return 1;  # Stop searching
      }
      return 0;
    }
  );

  $found_token
}

1;

__END__

=pod

=head1 NAME

Perl::Critic::Policy::CodeLayout::LimitLineLength - Limit the length of lines

=head1 SYNOPSIS

  [CodeLayout::LimitLineLength]
  max_line_length = 72

  # Bad - line exceeds configured maximum
  my $very_long_variable_name = "long string that exceeds maximum length";

  # Good - line within limit
  my $very_long_variable_name =
    "long string that exceeds maximum length";

=head1 DESCRIPTION

This policy flags lines that exceed a configurable maximum length. Long lines
can be difficult to read, especially in narrow terminal windows or when
viewing code side-by-side with diffs or other files.

The default maximum line length is 80 characters, which provides good
readability across various display contexts while still allowing reasonable
code density.

You can configure C<perltidy> to keep lines within the specified limit.  Only
when it is unable to do that will you need to manually make changes.

=head1 CONFIGURATION

=head2 max_line_length

The maximum allowed line length in characters. Defaults to 80.

  [CodeLayout::LimitLineLength]
  max_line_length = 72

=head1 EXAMPLES

=head2 Long Variable Assignments

  # Bad - exceeds 72 characters
  my $configuration_manager = VeryLongModuleName::ConfigurationManager->new;

  # Good - broken into multiple lines
  my $configuration_manager =
    VeryLongModuleName::ConfigurationManager->new;

=head2 Long Method Calls

  # Bad - exceeds 72 characters
  $object->some_very_very_long_method_name($param1, $param2, $param3, $param4);

  # Good - parameters on separate lines
  $object->some_very_very_long_method_name(
    $param1, $param2, $param3, $param4
  );

=head2 Long String Literals

  # Bad - exceeds 72 characters
  my $error_message =
    "This is a very long error message that exceeds the configured maximum";

  # Good - use concatenation or heredoc
  my $error_message = "This is a very long error message that " .
    "exceeds the configured maximum";

=head1 AFFILIATION

This Policy is part of the Perl::Critic::PJCJ distribution.

=head1 AUTHOR

Paul Johnson C<< <paul@pjcj.net> >>

=head1 COPYRIGHT

Copyright 2025 Paul Johnson.

=head1 LICENCE

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
