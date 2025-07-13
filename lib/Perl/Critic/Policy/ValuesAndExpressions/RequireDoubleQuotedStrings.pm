package Perl::Critic::Policy::ValuesAndExpressions::RequireDoubleQuotedStrings;

use v5.20.0;
use strict;
use warnings;
use feature 'signatures';
no warnings 'experimental::signatures';

use Readonly;

use Perl::Critic::Utils qw{ :severities };
use base 'Perl::Critic::Policy';

our $VERSION = '0.001';

Readonly::Scalar my $DESC => q{Use double quotes for simple strings};
Readonly::Scalar my $EXPL =>
  q{Simple strings (containing no double quotes or @ symbols) should use }
  . q{double quotes for consistency};

sub supported_parameters { return () }
sub default_severity     { return $SEVERITY_MEDIUM }
sub default_themes       { return qw( cosmetic ) }
sub applies_to           { return 'PPI::Token::Quote::Single' }

sub violates ($self, $elem, $) {
  # Get the string content without the surrounding quotes
  my $string = $elem->string;

  # Check if this is a "simple" string - no double quotes or @ symbols
  if ($self->_is_simple_string($string)) {
    return $self->violation($DESC, $EXPL, $elem);
  }

  return;
}

sub _is_simple_string ($self, $string) {
  # Simple strings contain no double quotes or @ symbols
  return index($string, '"') == -1 && index($string, '@') == -1;
}

1;

__END__

=pod

=head1 NAME

Perl::Critic::Policy::ValuesAndExpressions::RequireDoubleQuotedStrings - Use
double quotes for simple strings

=head1 SYNOPSIS

  # Bad:
  my $greeting = 'hello';

  # Good:
  my $greeting = "hello";

  # OK (contains @):
  my $email = 'user@domain.com';

=head1 AFFILIATION

This Policy is part of the Perl::Critic::Strings distribution.

=head1 DESCRIPTION

This policy requires that "simple" strings use double quotes rather than single
quotes. A simple string is one that contains no double quote characters (") and
no at-sign (@) characters.

The rationale is that double quotes are the "normal" case in Perl, and single
quotes should be reserved for cases where they are specifically needed to avoid
interpolation or escaping.

=head1 CONFIGURATION

This Policy is not configurable except for the standard options.

=head1 EXAMPLES

Bad:

    my $greeting = 'hello';        # simple string, should use double quotes
    my $name = 'world';            # simple string, should use double quotes
    my $message = 'hello world';   # simple string, should use double quotes

Good:

    my $greeting = "hello";        # simple string with double quotes
    my $name = "world";            # simple string with double quotes
    my $message = "hello world";   # simple string with double quotes

    # These are acceptable with single quotes because they're not "simple"
    my $email = 'user@domain.com';      # contains @, so single quotes OK
    my $quoted = 'He said "hello"';     # contains ", so single quotes OK
    my $complex = 'It\'s a nice day';   # escaping needed anyway

=head1 AUTHOR

Paul Johnson C<< <paul@pjcj.net> >>

=head1 COPYRIGHT

Copyright (c) 2025 Paul Johnson.

=head1 LICENSE

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
