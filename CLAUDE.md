# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with
code in this repository.

## Project Overview

Perl::Critic::PJCJ is a CPAN distribution providing Perl::Critic policies for
code style consistency. Built with Dist::Zilla.

## Skills

Always use the `development` and `perl` skills when working on this codebase.

## Development Commands

Run these after every change:

- **Format**: `make format` (runs `utils/perl-hook fix`, which backs up each
  tracked Perl file to `tmp/perltidy/` and then runs perlimports,
  `script/perl-quote-fix` and perltidy). Always run it before other formatting.
- **Test**: `make test` (dzil clean + dzil test)
- **Lint**: `make lint` (pre-commit run --all-files, includes perlcritic)
- **Coverage**: `make cover-compilation` (statement/branch/condition report)

Quick test during development (no clean/rebuild): `make t`

Single test file: `yath test -j20 --qvf -T t/path/to/test.t`

## Architecture

### Policies

- `lib/Perl/Critic/Policy/ValuesAndExpressions/RequireConsistentQuoting.pm` -
  the main policy. Enforces three rules: (1) reduce punctuation, (2) prefer
  interpolated strings, (3) use bracket delimiters in preference order. Handles
  six PPI token types via a dispatch table in `violates()`, routing to
  `check_single_quoted`, `check_double_quoted`, `check_q_literal`,
  `check_qq_interpolate`, `check_quote_operators`, and `check_use_statement`.
- `lib/Perl/Critic/Policy/CodeLayout/ProhibitLongLines.pm` - configurable
  maximum line length enforcement. Supports per-file overrides via
  `.gitattributes` (attribute `custom-line-length` with value `ignore` or an
  integer).
- `lib/Perl/Critic/Utils/SourceLocation.pm` - helper for ProhibitLongLines to
  create synthetic PPI elements with line/column info for violations.

### Key internal methods in RequireConsistentQuoting

- `would_interpolate($string)` - uses PPI to check if content would interpolate
  in double quotes.
- `has_quote_sensitive_escapes($string)` - regex check for escape sequences
  (`\n`, `\t`, `\x1b`, `\N{...}`, etc.) that differ between `''` and `""`.
- `find_optimal_delimiter($content, $op, $start, $end)` - determines best
  bracket delimiter (`()` > `[]` > `<>` > `{}`), accounting for unbalanced
  content.
- `delimit_content($content, $start, $end)` - escapes delimiter characters in
  content or returns undef when that is unsafe. Shared with the Fixer, so the
  policy only suggests rewrites the fixer can apply.
- `parse_quote_token($elem)` - extracts operator, delimiters, and content from
  any quote-like token.
- `decode_q_literal($raw, $start, $end)` - decodes the raw content of a `q()`
  literal. Shared with the Fixer, so the words the policy approves for
  `use qw()` are the words the fixer writes.
- `probe_quote_token($code)` - parses `$code` and returns the first quote-like
  token with its document. Shared with the Fixer for reading source back.
  Callers must keep the document in scope while they read the token.

### Test framework

Tests use `Test2::V0` and a shared helper `t/lib/ViolationFinder.pm` which
exports:

- `good $policy, $code, $desc` - assert no violations.
- `bad $policy, $code, $expected_msg, $desc` - assert exactly one violation
  whose `description` matches `$expected_msg` via `like`.
- `fixes`, `unchanged` and `declined` - assert what the Fixer does with the
  source. `declined` also asserts that the Fixer reports the fix it could not
  apply.
- `find_violations` / `count_violations` - lower-level helpers.

Tests are organised by concern under
`t/ValuesAndExpressions/RequireConsistentQuoting/`: `single_quotes.t`,
`double_quotes.t`, `escape_sequences.t`, `quote_operators.t`,
`delimiter_optimisation.t`, `use_statement_quote_types.t`, `newlines.t`,
`messages.t`, etc.

### Violation messages

RequireConsistentQuoting puts the per-violation suggestion (e.g. `use ''`,
`use ""`, `use qq()`, `use qw()`) in the `description` field, which is what `%m`
formats show. The `explanation` is a single static rationale. Tests check
`description`. The test helper runs its fixer round-trip assertions for any
policy that provides `fix_data`, keyed on that capability rather than on a
policy class name.

Each violation is a `Perl::Critic::PJCJ::Violation` that holds its structured
fix (`->fix`). The Fixer reads that attached fix directly and only falls back to
`fix_data($description)` for test doubles. A violation with no fix mapping, and
a fix the Fixer declines to apply, are each reported once on standard error. The
suggestion wording is kept in one place: the exported constant subs
`desc_double`, `desc_single`, `desc_use_qw`, `desc_remove_parens` and
`desc_optimal($display)`, which tests import rather than duplicating literals.
The plain fix types are listed once in `%Plain_fixes`, which pairs each type
with its `desc_*` sub and fix structure. `_render_fix` and `_known_fixes` both
read that table, and `_render_fix` dies on a type that is neither in the table
nor `operator`.

## Style Notes

- Perl 5.26+ with `use feature qw( signatures )` and
  `use experimental qw( signatures )`.
- Formatting is controlled by `.perltidyrc` and imports by `perlimports`. Do not
  manually reformat - run `make format`.
- Perlcritic configuration is in `.perlcriticrc` (severity 2).
- Each `.pm` file ends with a quoted string (song lyric) instead of `1;`. The
  `Modules::RequireEndWithOne` policy is disabled.
