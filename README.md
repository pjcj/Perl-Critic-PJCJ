# Perl::Critic::PJCJ

A Perl::Critic policy distribution for enforcing code style consistency
in Perl code.

## Description

This distribution provides Perl::Critic policies that enforce consistent
coding practices to improve code readability and maintainability. It includes
policies for string quoting consistency and line length limits.

## Policies

### Perl::Critic::Policy::ValuesAndExpressions::UseConsistentQuoting

This policy enforces consistent and optimal quoting practices through five
priority rules:

1. **Prefer double quotes for simple strings** - Use `""` as the default for
   most strings. Only use single quotes when the string contains literal `$`
   or `@` that should not be interpolated.

2. **Minimise escape characters** - Choose delimiters that require the fewest
   backslash escapes.

3. **Prefer "" over qq()** - Use simple double quotes instead of `qq()`
   when possible.

4. **Prefer '' over q()** - Use simple single quotes instead of `q()` for
   literal strings.

5. **Use only bracket delimiters** - Only use bracket delimiters `()`, `[]`,
   `<>`, `{}` for quote-like operators. Choose the delimiter that minimises
   escape characters. When escape counts are equal, prefer them in this
   order: `()`, `[]`, `<>`, `{}`.

#### Rationale

- Double quotes are preferred for consistency and to allow potential
  interpolation
- Minimising escape characters improves readability and reduces errors
- Simple quotes are preferred over their `q()` and `qq()` equivalents when
  possible
- Only bracket delimiters should be used (no exotic delimiters like `/`,
  `|`, `#`, etc.)
- Optimal delimiter selection reduces visual noise in code
- Many years ago, Tom Christiansen wrote a lengthy article on how perl's default
  quoting system is interpolation, and not interpolating means something
  extraordinary is happening. I can't find the original article, but you can
  see that double quotes are used by default in The Perl Cookbook, for example.

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

### Perl::Critic::Policy::CodeLayout::LimitLineLength

This policy enforces a configurable maximum line length to improve code
readability, especially in narrow terminal windows or when viewing code
side-by-side with diffs or other files.

The default maximum line length is 80 characters, which provides good
readability across various display contexts while still allowing reasonable
code density.

You can configure `perltidy` to keep lines within the specified limit. Only
when it is unable to do that will you need to manually make changes.

#### Configuration

- **max_line_length** - Maximum allowed line length in characters (default: 80)

#### Examples

**Bad examples (exceeds 72 characters):**

```perl
# Line exceeds configured maximum
my $very_long_variable_name = "long string that exceeds maximum length";

# Long variable assignment
my $configuration_manager = VeryLongModuleName::ConfigurationManager->new;

# Long method call
$object->some_very_very_long_method_name($param1, $param2, $param3, $param4);

# Long string literal
my $error_message =
  "This is a very long error message that exceeds the configured maximum";
```

**Good examples:**

```perl
# Line within limit
my $very_long_variable_name =
  "long string that exceeds maximum length";

# Broken into multiple lines
my $configuration_manager =
  VeryLongModuleName::ConfigurationManager->new;

# Parameters on separate lines
$object->some_very_very_long_method_name(
  $param1, $param2, $param3, $param4
);

# Use concatenation
my $error_message = "This is a very long error message that " .
  "exceeds the configured maximum";
```

#### Usage

Add to your `.perlcriticrc` file:

```ini
[CodeLayout::LimitLineLength]
max_line_length = 72
```

Or use the default 80 character limit:

```ini
[CodeLayout::LimitLineLength]
```

## Installation

To install this module, run the following commands:

```bash
cpan Perl::Critic::PJCJ
```

Or manually:

```bash
perl Makefile.PL
make
make test
make install
```

## Usage

Add individual policies to your `.perlcriticrc` file:

```ini
[ValuesAndExpressions::UseConsistentQuoting]

[CodeLayout::LimitLineLength]
max_line_length = 72
```

Or include the entire distribution:

```ini
include = Perl::Critic::PJCJ
```

Then run perlcritic on your code:

```bash
# Run individual policies
perlcritic --single-policy \
  ValuesAndExpressions::UseConsistentQuoting MyScript.pl

perlcritic --single-policy \
  CodeLayout::LimitLineLength MyScript.pl

# Or run all policies from the distribution
perlcritic --include Perl::Critic::PJCJ MyScript.pl
```

## Development

This module is built using Dist::Zilla. To build and test:

```bash
dzil test
dzil build
```

## Author

Paul Johnson <paul@pjcj.net>

## Copyright and Licence

Copyright 2025 Paul Johnson.

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.
