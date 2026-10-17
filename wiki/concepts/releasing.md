---
title: Releasing
summary: Versioning, the changelog, how a release is cut and published, and the automated spec-update and dependency PRs.
updated: 2026-10-17
---

# Releasing

Policy: [0009 Versioning and releases](../decisions/0009-versioning-and-releases.md).

## Day to day

- Every user-visible change adds a line under **Unreleased** in
  [CHANGELOG.md](../../CHANGELOG.md) (enforced by the PR checklist and review).
- [Dependabot](../../.github/dependabot.yml) opens monthly PRs for GitHub
  Actions and Swift dependencies.
- [spec-update.yml](../../.github/workflows/spec-update.yml) runs every Monday
  (and on demand): `make generate-fetch`, `make check`, and a PR if the spec
  changed. The PR body states whether `make check` passed.

## Cutting a release (maintainers)

```sh
make release VERSION=0.2.0
```

[Scripts/release.sh](../../Scripts/release.sh) refuses unless you're on a
clean `main` in sync with `origin`, the tag is new, and **Unreleased** isn't
empty. It then:

1. moves **Unreleased** under `## [0.2.0] - <date>`,
2. sets the version in the `User-Agent`
   ([HeadersMiddleware.swift](../../Sources/OpenRouter/Middleware/HeadersMiddleware.swift))
   and in the README's install snippet,
3. runs `make check`, commits `Release 0.2.0`, creates an annotated tag
   `0.2.0` and pushes both.

[release.yml](../../.github/workflows/release.yml) then publishes the GitHub
release, using that CHANGELOG section as the notes.

## Gotchas

- PRs opened by GitHub Actions with `GITHUB_TOKEN` don't trigger other
  workflows, so CI doesn't run on spec-update PRs automatically. Push a
  commit or close and reopen the PR. That's why the workflow runs
  `make check` itself.
- The repository setting "Allow GitHub Actions to create and approve pull
  requests" must stay enabled for spec-update PRs.
- Tags have no `v` prefix (`0.2.0`). SwiftPM accepts both forms, but plain
  versions are the convention across the Swift ecosystem.
- After the first tag, the package can be submitted to the Swift Package
  Index, which also hosts the DocC documentation (`.spi.yml`).
