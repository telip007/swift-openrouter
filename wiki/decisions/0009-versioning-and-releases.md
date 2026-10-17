---
title: Versioning and releases
summary: SemVer starting at 0.x, plain version tags, Keep a Changelog, scripted releases and automated spec-update PRs.
updated: 2026-10-17
---

# 0009 Versioning and releases

## Context

Consumers pin versions through SwiftPM, which resolves semantic-version tags.
The API surface is new and partly generated from a spec that changes weekly,
so breaking changes are likely early on.

## Decision

- Semantic Versioning, starting at `0.1.0`. While on `0.x`, minor releases may
  break the API; breaking changes are listed under **Changed** in the
  changelog. `1.0.0` once the convenience API has settled.
- Plain tags (`0.1.0`), annotated, created only by `make release`.
- [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) with an
  **Unreleased** section maintained per PR.
- GitHub releases are generated from the changelog by CI. Spec updates arrive
  as weekly automated PRs and ship in the next release.

## Consequences

- Releasing is one command, and the release notes come from text that was
  reviewed with each PR.
- Regenerated code can rename generated types. Such spec updates bump the
  minor version while on `0.x`.

Process details: [Releasing](../concepts/releasing.md).
