---
name: release
description: >
  Release workflow for Perl-Critic-PJCJ. Use when preparing or performing a
  CPAN release. Covers pre-release checks, the dzil release command, and
  post-release verification.
user_invocable: true
---

# Release workflow for Perl-Critic-PJCJ

This distribution uses Dist::Zilla. The release process is largely automated
by `dzil release`, but several manual steps must be completed first.

## 1. Pre-release checklist

Run each check and confirm it passes before proceeding.

- [ ] All changes are committed (`git status` is clean).
- [ ] Tests pass: `make test`
- [ ] Lint passes: `make lint`
- [ ] `Changes.md` has an entry under the `{{$NEXT}}` heading describing
  what changed in this release.
- [ ] Version is set correctly in `dist.ini` (field `version`).
  Dist::Zilla injects this into all modules via `[PkgVersion]`.
- [ ] You are on the `main` branch. Releases are only made from `main`.
  Any feature branches must have been merged already; they are not part
  of the release process.

## 2. Run `dzil release`

```bash
dzil release
```

This single command performs the following steps automatically (configured
in `dist.ini`):

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
  `{{$NEXT}}` was, and a fresh `{{$NEXT}}` section has been added above it.
