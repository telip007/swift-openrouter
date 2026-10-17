---
title: Conventional Commits and release-please
summary: Commit headers drive SemVer bumps and the changelog; release-please opens release PRs that tag and publish on merge.
updated: 2026-10-17
---

# 0010 Conventional Commits and release-please

Supersedes the release mechanics (hand-written changelog, `make release`) of
[0009](0009-versioning-and-releases.md). Its versioning policy (SemVer from
0.1.0, plain tags) still applies.

## Context

A hand-curated changelog duplicates information already in commit messages,
and contributors forget it. [Conventional Commits](https://www.conventionalcommits.org/)
map directly onto [SemVer](https://semver.org/) (`fix` → patch, `feat` →
minor, `!` → major), so versions and release notes can be derived from
history instead of decided and written by hand.

## Decision

- Conventional Commits for every commit on `main`, enforced by a local
  `commit-msg` hook and a CI check on PR titles. Squash merges only, with the
  PR title as the commit message.
- [release-please](https://github.com/googleapis/release-please) (GitHub
  Action) maintains a release PR, generates `CHANGELOG.md`, and tags and
  publishes releases on merge. While on `0.x`, breaking changes bump the
  minor version.

## Consequences

- No manual changelog edits or version bumps. The PR title is the release
  note, so reviewers review titles.
- Releasing is merging a PR, which works from the GitHub UI without a local
  toolchain.
- PRs created by `GITHUB_TOKEN` need a manual CI trigger
  ([Releasing](../concepts/releasing.md#gotchas)).

Process details: [Releasing](../concepts/releasing.md).
