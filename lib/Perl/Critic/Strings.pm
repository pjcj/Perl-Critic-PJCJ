package Perl::Critic::Strings;

use v5.20.0;
use strict;
use warnings;

# VERSION

1;

__END__

=pod

=head1 NAME

Perl::Critic::Strings - Perl::Critic policies for string handling

=head1 SYNOPSIS

  # In your .perlcriticrc file:
  include = Perl::Critic::Strings

  # Or from the command line:
  perlcritic --include Perl::Critic::Strings lib/

=head1 DESCRIPTION

This distribution provides Perl::Critic policies for enforcing consistent
string quoting practices in Perl code.

=head1 POLICIES

=over 4

=item L<Perl::Critic::Policy::ValuesAndExpressions::UseConsistentQuoting>

Enforces consistent and optimal quoting practices. This policy combines two
requirements: simple strings (containing no double quotes or @ symbols) should
use double quotes, and quote-like operators should use delimiters that minimise
escape characters.

=back

=head1 AUTHOR

Paul Johnson C<< <paul@pjcj.net> >>

=head1 COPYRIGHT

Copyright 2025 Paul Johnson.

=head1 LICENCE

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
