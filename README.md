# Perl::Critic::Strings

A Perl::Critic policy distribution for enforcing consistent string quoting practices in Perl code.

## Description

This distribution provides Perl::Critic policies that help maintain consistent and readable string quoting conventions in Perl code.

## Policies

### Perl::Critic::Policy::ValuesAndExpressions::RequireDoubleQuotedStrings

This policy requires that "simple" strings use double quotes rather than single quotes. A simple string is one that contains no double quote characters (") and no at-sign (@) characters.

#### Rationale

Double quotes are the "normal" case in Perl, and single quotes should be reserved for cases where they are specifically needed to avoid interpolation or escaping.

#### Examples

**Bad:**
```perl
my $greeting = 'hello';        # simple string, should use double quotes
my $name = 'world';            # simple string, should use double quotes
my $message = 'hello world';   # simple string, should use double quotes
```

**Good:**
```perl
my $greeting = "hello";        # simple string with double quotes
my $name = "world";            # simple string with double quotes  
my $message = "hello world";   # simple string with double quotes

# These are acceptable with single quotes because they're not "simple"
my $email = 'user@domain.com';      # contains @, so single quotes OK
my $quoted = 'He said "hello"';     # contains ", so single quotes OK
my $complex = 'It\'s a nice day';   # escaping needed anyway
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
[ValuesAndExpressions::RequireDoubleQuotedStrings]
```

Then run perlcritic on your code:

```bash
perlcritic --single-policy ValuesAndExpressions::RequireDoubleQuotedStrings MyScript.pl
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