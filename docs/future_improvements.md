# Future Improvements

Potential improvements that have been analysed but not yet implemented.

## Add coverage reporting to CI

**Area:** CI

### Problem

Coverage is only available locally via `make cover-compilation`. Adding
Coveralls or Codecov integration would show coverage trends over time and catch
regressions in pull requests.

### Why not implemented

Low priority - the coverage baseline is already high (97%+) and the project has
few contributors. Worth adding if the contributor base grows.

## Make rules individually configurable

**Area:** Feature **Policy:** RequireConsistentQuoting

### Problem

The policy has zero `supported_parameters`. Users cannot choose their preferred
quote style, exclude specific token types, or enable/disable individual rules
(reduce punctuation, prefer interpolated, delimiter preference).

### Why not implemented

The current opinionated approach is intentional - the policy enforces a single
consistent style. Adding configurability would increase complexity and the
amount of testing needed. Worth considering if users request specific
customisation.

## Add `pre-commit run --all-files` to CI

**Area:** CI

### Problem

Pre-commit checks (including perlcritic, perltidy, markdownlint, typos) only run
locally. CI does not verify that all hooks pass.

### Why not implemented

Low priority - the existing CI runs `dzil test` which covers correctness.
Pre-commit enforcement would catch formatting and style regressions but is not
blocking.
