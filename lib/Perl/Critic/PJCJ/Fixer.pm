package Perl::Critic::PJCJ::Fixer;

use v5.26.0;
use strict;
use warnings;
use feature      qw( signatures );
use experimental qw( signatures );

use List::Util qw( all );
use PPI        ();
use Perl::Critic::Policy::ValuesAndExpressions::RequireConsistentQuoting ();

my $Max_passes    = 10;
my %End_delimiter = ("(" => ")", "[" => "]", "<" => ">", "{" => "}");

sub new ($class) {
  my $policy
    = Perl::Critic::Policy::ValuesAndExpressions::RequireConsistentQuoting->new;
  bless { policy => $policy }, $class
}

sub _decode_single ($self, $raw) { $raw =~ s/\\([\\'])/$1/gr }

sub _decode_double ($self, $raw) { $raw =~ s/\\(.)/$1/gsr }

sub _decode_q ($self, $raw, $start, $end) {
  $raw =~ s/\\([\\\Q$start$end\E])/$1/gr
}

sub _encode_single ($self, $value) {
  "'" . ($value =~ s/([\\'])/\\$1/gr) . "'"
}

sub _encode_double ($self, $value) {
  '"' . ($value =~ s/\\/\\\\/gr) . '"'
}

sub _normalised_value ($self, $elem) {
  my $class = ref $elem;
  return $self->_decode_single($elem->string)
    if $class eq "PPI::Token::Quote::Single";
  return $self->_decode_double($elem->string)
    if $class eq "PPI::Token::Quote::Double";

  my ($start, $end, $raw) = $self->{policy}->parse_quote_token($elem);
  return $self->_decode_q($raw, $start, $end)
    if $class eq "PPI::Token::Quote::Literal";
  return $self->_decode_double($raw)
    if $class eq "PPI::Token::Quote::Interpolate"
    || $class eq "PPI::Token::QuoteLike::Command";

  my $content = $raw =~ s/\\([\Q$start$end\E])/$1/gr;
  join "\0", grep length, split /\s+/, $content
}

sub _balanced ($self, $content, $start, $end) {
  my $depth = 0;
  for my $char (split //, $content) {
    $depth++ if $char eq $start;
    if ($char eq $end) {
      $depth--;
      return 0 if $depth < 0;
    }
  }
  $depth == 0
}

sub _delimit_content ($self, $content, $start, $end) {
  return $content if $content !~ /[\Q$start$end\E]/;
  return          if $content =~ /\\/;
  return $content if $self->_balanced($content, $start, $end);
  $content =~ s/([\Q$start$end\E])/\\$1/gr
}

sub _operator_replacement ($self, $elem, $op, $start, $end) {
  my $class = ref $elem;
  my $content;

  if ($class eq "PPI::Token::Quote::Single") {
    $content
      = $self->_decode_single($elem->string) =~ s/([\\\Q$start$end\E])/\\$1/gr;
    return "$op$start$content$end";
  }

  if ($class eq "PPI::Token::Quote::Double") {
    $content = $elem->string =~ s/\\"/"/gr;
  } else {
    my ($old_start, $old_end, $raw) = $self->{policy}->parse_quote_token($elem);
    $content = $raw =~ s/\\([\Q$old_start$old_end\E])/$1/gr;
  }

  $content = $self->_delimit_content($content, $start, $end);
  defined $content ? "$op$start$content$end" : undef
}

sub _replacement ($self, $elem, $expl) {
  my $class = ref $elem;

  if ($elem->isa("PPI::Token") && $expl =~ /\Ause (qw|qq|qx|q)([(\[<{])/) {
    return $self->_operator_replacement($elem, $1, $2, $End_delimiter{$2});
  }

  if ($class eq "PPI::Token::Quote::Single") {
    return $self->_encode_double($self->_decode_single($elem->string))
      if $expl eq 'use ""';
  } elsif ($class eq "PPI::Token::Quote::Double") {
    return $self->_encode_single($self->_decode_double($elem->string))
      if $expl eq "use ''";
  } elsif ($class eq "PPI::Token::Quote::Literal") {
    my ($start, $end, $raw) = $self->{policy}->parse_quote_token($elem);
    my $value = $self->_decode_q($raw, $start, $end);
    return $self->_encode_double($value) if $expl eq 'use ""';
    return $self->_encode_single($value) if $expl eq "use ''";
  } elsif ($class eq "PPI::Token::Quote::Interpolate") {
    my $raw = $elem->string;
    return qq("$raw") if $expl eq 'use ""';
    return $self->_encode_single($self->_decode_double($raw))
      if $expl eq "use ''";
  }

  undef
}

sub _value_preserved ($self, $elem, $new_source) {
  my $code    = "$new_source;";
  my $doc     = PPI::Document->new(\$code) or return 0;
  my ($token) = grep {
    $_->isa("PPI::Token::Quote") || $_->isa("PPI::Token::QuoteLike")
  } $doc->tokens;
  $token
    && $doc->serialize eq $code
    && $self->_normalised_value($token) eq $self->_normalised_value($elem)
}

sub _apply_replacement ($self, $elem, $expl) {
  my $new = $self->_replacement($elem, $expl);
  return unless defined $new;
  $elem->set_content($new) if $self->_value_preserved($elem, $new);
}

sub _remove_include_parens ($self, $elem) {
  my ($list) = grep $_->isa("PPI::Structure::List"), $elem->children;
  return unless $list;

  my @kids = $list->children;
  while (@kids && !$kids[0]->significant)  { (shift @kids)->delete }
  while (@kids && !$kids[-1]->significant) { (pop @kids)->delete }
  $list->start->set_content("");
  $list->finish->set_content("");
}

sub _include_argument_span ($self, $elem) {
  my $module_seen = 0;
  my @span;
  for my $child ($elem->children) {
    if (!$module_seen) {
      $module_seen = 1
        if $child->isa("PPI::Token::Word")
        && $child->content !~ /\A(?:use|no)\z/;
      next;
    }
    last if $child->isa("PPI::Token::Structure") && $child->content eq ";";
    next if !@span                               && !$child->significant;
    push @span, $child;
  }
  pop @span while @span && !$span[-1]->significant;
  @span
}

sub _collect_use_words ($self, $words, @elements) {
  for my $el (@elements) {
    next unless $el->significant;
    my $class = ref $el;
    if (
         $class eq "PPI::Token::Quote::Single"
      || $class eq "PPI::Token::Quote::Literal"
    ) {
      push @$words, $self->_normalised_value($el);
    } elsif (
      $class eq "PPI::Token::Quote::Double"
      || $class eq "PPI::Token::Quote::Interpolate"
    ) {
      return 0 if $self->{policy}->would_interpolate($el->string);
      push @$words, $self->_normalised_value($el);
    } elsif ($class eq "PPI::Token::QuoteLike::Words") {
      my ($start, $end, $raw) = $self->{policy}->parse_quote_token($el);
      my $content = $raw =~ s/\\([\Q$start$end\E])/$1/gr;
      push @$words, grep length, split /\s+/, $content;
    } elsif ($class eq "PPI::Token::Operator" && $el->content eq ",") {
      next;
    } elsif (
      $el->isa("PPI::Structure::List")
      || $el->isa("PPI::Statement::Expression")
    ) {
      return 0 unless $self->_collect_use_words($words, $el->children);
    } else {
      return 0;
    }
  }
  @$words ? 1 : 0
}

sub _fix_include ($self, $elem, $expl) {
  return $self->_remove_include_parens($elem) if $expl eq "remove parentheses";
  return unless $expl eq "use qw()";

  my @span = $self->_include_argument_span($elem);
  return unless @span;

  my @words;
  if (
    $self->_collect_use_words(\@words, @span) && all { /\A[^\s()\\]+\z/ }
    @words
  ) {
    $span[0]->insert_before(PPI::Token->new("qw( @words )"));
    $_->delete for @span;
    return;
  }

  my $qw_tokens = $elem->find("PPI::Token::QuoteLike::Words") or return;
  for my $token (@$qw_tokens) {
    $self->_apply_replacement($token, "use qw()")
      if $token->content !~ /\Aqw\s*\(/;
  }
}

sub _apply_fix ($self, $elem, $explanation) {
  $elem->isa("PPI::Statement::Include")
    ? $self->_fix_include($elem, $explanation)
    : $self->_apply_replacement($elem, $explanation)
}

sub _in_range ($self, $elem, $lines) {
  return 1 unless $lines;
  my $line = $elem->line_number;
  $line >= $lines->[0] && $line <= $lines->[1]
}

sub _fix_once ($self, $source, $lines) {
  my $doc = PPI::Document->new(\$source) or return $source;

  my @fixes;
  $doc->find(
    sub ($top, $elem) {
      my ($violation) = $self->{policy}->violates($elem, $doc);
      push @fixes, [ $elem, $violation->explanation ]
        if $violation && $self->_in_range($elem, $lines);
      0
    }
  );
  $self->_apply_fix(@$_) for @fixes;

  $doc->serialize
}

sub fix ($self, $source, %opts) {
  my $previous = "";
  my $current  = $source;
  for (1 .. $Max_passes) {
    last if $current eq $previous;
    $previous = $current;
    $current  = $self->_fix_once($current, $opts{lines});
  }
  $current
}

"
A painter on the shore
Imagined all the world
Within the snowflake on his palm
"

__END__

=pod

=head1 NAME

Perl::Critic::PJCJ::Fixer - automatically fix RequireConsistentQuoting
violations

=head1 SYNOPSIS

  use Perl::Critic::PJCJ::Fixer;

  my $fixer = Perl::Critic::PJCJ::Fixer->new;
  my $fixed = $fixer->fix($source);

=head1 DESCRIPTION

This module rewrites Perl source so that it satisfies
L<Perl::Critic::Policy::ValuesAndExpressions::RequireConsistentQuoting>. It
never decides for itself what to change: it runs the policy over the parsed
document and rewrites only the tokens the policy flags, computing each
replacement so that the runtime value of every string is preserved.

Source that the policy accepts, including all surrounding whitespace and
comments, is passed through byte for byte.

=head1 METHODS

=head2 new

Create a new fixer.

=head2 fix ($source, %opts)

Take Perl source as a string and return the fixed source. Source that cannot be
parsed is returned unchanged. Fixing repeats until no further changes are
needed, since one fix can enable the next suggestion.

The C<lines> option restricts fixes to elements starting within an inclusive
line range, while still parsing the whole document:

  my $fixed = $fixer->fix($source, lines => [ 10, 20 ]);

=head1 AUTHOR

Paul Johnson <paul@pjcj.net>

=head1 LICENCE

This library is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut
