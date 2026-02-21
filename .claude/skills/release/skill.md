---
name: release
description: >
  Release workflow for Perl-Critic-PJCJ. Use when preparing or performing
  a CPAN release. Covers creating a release ticket, bumping the version,
  running pre-release checks, the dzil release command, and post-release
  verification. Both commands live in utils/run and support --dryrun.
user_invocable: true
---

# Release workflow for Perl-Critic-PJCJ

This distribution uses Dist::Zilla. The release process is driven by two
recipes in `utils/run`. Both support `--dryrun`.

## 1. Create a release ticket — `utils/run release-ticket`

Prompts for a version bump (patch/minor/major/custom) if the version in
`dist.ini` still matches the last release in `Changes.md`, updates
`dist.ini`, and creates a GitHub issue with a pre-release checklist.

## 2. Perform the release — `utils/run release`

Runs the pre-release checklist automatically and aborts on failure:

- On the `main` branch.
- Working tree is clean (`git status`).
- Tests pass: `make test`
- Lint passes: `make lint`
- `Changes.md` has an entry under the `{{$NEXT}}` heading.
- Version in `dist.ini` has been bumped from the last release.

Then calls `dzil release`, which performs the following steps
(configured in `dist.ini`):

1. **Git::Check** — aborts if the working tree is dirty.
2. **Build** — assembles the distribution tarball.
3. **TestRelease** — runs the full test suite against the built dist.
4. **ConfirmRelease** — prompts for confirmation before uploading.
5. **UploadToCPAN** — uploads the tarball to CPAN.
6. **NextRelease** — rewrites the `{{$NEXT}}` token in `Changes.md` to
   the actual version and date (format: `## v0.1.4  - 2025-08-31`).
7. **Git::Commit** — commits the updated `Changes.md`.
8. **Git::Tag** — tags the commit with the version.
9. **Git::Push** — pushes the commit and tag to the remote.

## 3. Post-release verification

- Check that the new version appears on
  [MetaCPAN](https://metacpan.org/dist/Perl-Critic-PJCJ) (may take a few
  minutes to index).
- Verify the git tag exists: `git tag -l`
- Confirm `Changes.md` now has a concrete version heading where
  `{{$NEXT}}` was, and a fresh `{{$NEXT}}` section has been added above
  it.
