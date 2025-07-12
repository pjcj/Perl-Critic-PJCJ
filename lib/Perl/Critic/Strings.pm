package Perl::Critic::Strings;

use 5.010001;
use strict;
use warnings;

our $VERSION = '0.001';

1;

__END__

=pod

=head1 NAME

Perl::Critic::Strings - Perl::Critic policies for string handling

=head1 DESCRIPTION

This distribution provides Perl::Critic policies for enforcing consistent
string quoting practices in Perl code.

=head1 POLICIES

=over 4

=item L<Perl::Critic::Policy::ValuesAndExpressions::RequireDoubleQuotedStrings>

Requires that "simple" strings (containing no double quotes or @ symbols)
use double quotes rather than single quotes.

=back

=head1 AUTHOR

Paul Johnson C<< <paul@pjcj.net> >>

=head1 COPYRIGHT

Copyright (c) 2025 Paul Johnson.

=head1 LICENSE

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
