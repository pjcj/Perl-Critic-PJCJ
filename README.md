# Perl::Critic::Strings

A Perl::Critic policy distribution for enforcing consistent string quoting
practices in Perl code.

## Description

This distribution provides a Perl::Critic policy that helps maintain consistent
and readable string quoting conventions in Perl code. It combines rules for
both simple string quoting (single vs double quotes) and optimal delimiter
selection for quote-like operators.

## Policy

### Perl::Critic::Policy::ValuesAndExpressions::UseConsistentQuoting

This policy enforces consistent and optimal quoting practices by combining two
requirements:

1. **Simple strings** (containing no double quotes, @ symbols, or escapes)
   should use double quotes rather than single quotes
2. **Quote operators** should use delimiters that minimize the need for
   escape characters

#### Rationale

- Double quotes are the "normal" case in Perl, and single quotes should be
  reserved for cases where they are specifically needed to avoid interpolation
  or escaping
- Choosing optimal delimiters for quote operators minimizes escape characters,
  making code more readable and less error-prone

#### Examples

**Simple Strings - Bad:**

```perl
my $greeting = 'hello';        # simple string, should use double quotes
my $name = 'world';            # simple string, should use double quotes
my $message = 'hello world';   # simple string, should use double quotes
```

**Simple Strings - Good:**

```perl
my $greeting = "hello";        # simple string with double quotes
my $name = "world";            # simple string with double quotes
my $message = "hello world";   # simple string with double quotes

# These are acceptable with single quotes because they're not "simple"
my $email = 'user@domain.com';      # contains @, so single quotes OK
my $quoted = 'He said "hello"';     # contains ", so single quotes OK
my $complex = 'It\'s a nice day';   # escaping needed anyway
```

**Quote Operators - Bad:**

```perl
my @words = qw{word(with)parens};      # should use qw() - content has parens
my $cmd = qx{command[with]brackets};   # should use qx[] - content has brackets
my $str = qq[simple string];           # should use qq{} - no special chars
```

**Quote Operators - Good:**

```perl
my @words = qw(word(with)parens);      # () optimal - content has parens
my $cmd = qx[command[with]brackets];   # [] optimal - content has brackets
my $str = qq{simple string};           # {} optimal - no special chars
my $complex = qw{has(parens)[and]{braces}}; # any delimiter OK when all present
```

## Installation

To install this module, run the following commands:

```bash
cpan Perl::Critic::Strings
```

Or manually:

```bash
perl Makefile.PL
make
make test
make install
```

## Usage

Add the policy to your `.perlcriticrc` file:

```ini
[ValuesAndExpressions::UseConsistentQuoting]
```

Or include the entire distribution:

```ini
include = Perl::Critic::Strings
```

Then run perlcritic on your code:

```bash
perlcritic --single-policy \
  ValuesAndExpressions::UseConsistentQuoting MyScript.pl

# Or run all policies from the distribution
perlcritic --include Perl::Critic::Strings MyScript.pl
```

## Development

This module is built using Dist::Zilla. To build and test:

```bash
dzil test
dzil build
```

## Author

Paul Johnson <paul@pjcj.net>

## Copyright and License

Copyright (c) 2025 Paul Johnson.

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.
