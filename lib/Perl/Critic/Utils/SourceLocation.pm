package Perl::Critic::Utils::SourceLocation;

use v5.20.0;
use strict;
use warnings;
use feature "signatures";
no warnings "experimental::signatures";

use parent "PPI::Element";

# This is NOT a Perl::Critic policy - it's a helper class
sub is_policy { 0 }

# VERSION

# Synthetic element for accurate line number reporting when no PPI token exists

sub new ($class, %args) {
  bless {
    line_number   => $args{line_number},
    column_number => $args{column_number} // 1,
    content       => $args{content}       // "",
    filename      => $args{filename},
    },
    $class
}

# CRITICAL: This is what Perl::Critic::Violation actually calls
sub location ($self) {
  my $line = $self->{line_number};
  my $col  = $self->{column_number};
  [ $line, $col, $col, $line, $self->{filename} ]
}

# Standard PPI::Element interface
sub line_number          ($self) { $self->{line_number} }
sub column_number        ($self) { $self->{column_number} }
sub logical_line_number  ($self) { $self->{line_number} }
sub visual_column_number ($self) { $self->{column_number} }
sub logical_filename     ($self) { $self->{filename} }
sub content              ($self) { $self->{content} }
sub filename             ($self) { $self->{filename} }

# Support for filename extraction by violation system
# Return self as the "document"
sub top ($self) { $self }

1;

__END__

=pod

=head1 NAME

Perl::Critic::Utils::SourceLocation - Synthetic PPI element

=head1 SYNOPSIS

  # Used internally by LimitLineLength policy
  my $location = SourceLocation->new(
    line_number => 42,
    content     => "long line content"
  );

=head1 DESCRIPTION

This is a synthetic PPI element used by LimitLineLength policy to provide
accurate line number reporting when no real PPI token exists on a line (such as
within POD blocks).

=head1 AUTHOR

Paul Johnson C<< <paul@pjcj.net> >>

=head1 COPYRIGHT

Copyright 2025 Paul Johnson.

=head1 LICENCE

This program is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut
