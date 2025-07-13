# Perl::Critic::Strings

A Perl::Critic policy distribution for enforcing consistent string quoting
practices in Perl code.

## Description

This distribution provides a Perl::Critic policy that enforces consistent
quoting to improve code readability and maintainability. It applies five
priority rules to ensure optimal string and quote operator usage.

## Policy

### Perl::Critic::Policy::ValuesAndExpressions::UseConsistentQuoting

This policy enforces consistent and optimal quoting practices through five
priority rules:

1. **Prefer double quotes for simple strings** - Use `""` as the default for
   most strings. Only use single quotes when the string contains literal `$`
   or `@` that should not be interpolated.

2. **Minimize escape characters** - Choose delimiters that require the fewest
   backslash escapes.

3. **Prefer "" over qq()** - Use simple double quotes instead of `qq()`
   when possible.

4. **Prefer '' over q()** - Use simple single quotes instead of `q()` for
   literal strings.

5. **Use only bracket delimiters** - Only use bracket delimiters `()`, `[]`,
   `<>`, `{}` for quote-like operators. Choose the delimiter that minimizes
   escape characters. When escape counts are equal, prefer them in this
   order: `()`, `[]`, `<>`, `{}`.

#### Rationale

- Double quotes are preferred for consistency and to allow potential
  interpolation
- Minimizing escape characters improves readability and reduces errors
- Simple quotes are preferred over their `q()` and `qq()` equivalents when
  possible
- Only bracket delimiters should be used (no exotic delimiters like `/`,
  `|`, `#`, etc.)
- Optimal delimiter selection reduces visual noise in code

#### Examples

**Bad examples:**

```perl
# Rule 1: Simple strings should use double quotes
my $greeting = 'hello';           # should use double quotes

# Rule 2, 5: Suboptimal escaping and exotic delimiters
my @words = qw{word(with)parens}; # should use qw[] to avoid escaping
my $file = q/path\/to\/file/;     # exotic delimiter needs escaping

# Rule 3: Should prefer "" over qq()
my $text = qq(simple);            # should use "" instead of qq()

# Rule 4: Should prefer '' over q()
my $literal = q(contains$literal); # should use '' instead of q()
```

**Good examples:**

```perl
# Rule 1: Double quotes for simple strings, single quotes for literals
my $greeting = "hello";           # double quotes for simple strings
my $email = 'user@domain.com';    # literal @ uses single quotes
my $var = 'Price: $10';           # literal $ uses single quotes

# Rule 2, 5: Optimal delimiter selection
my @words = qw[word(with)parens]; # [] avoids escaping parentheses
my $cmd = qx(command[with]brackets); # () avoids escaping brackets
my $file = "path/to/file";        # "" avoids escaping

# Rule 3, 4: Simple quotes preferred
my $text = "simple";              # "" preferred over qq()
my $literal = 'contains$literal'; # '' preferred over q()

# Exotic delimiters avoided
my @list = qw(one two);           # bracket delimiters only
my $path = "some/path";           # "" instead of q|some|path|
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
