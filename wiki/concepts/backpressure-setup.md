---
title: Backpressure setup
summary: Every automated check in this repository, where it runs, and the traps hit while wiring it up.
updated: 2026-10-17
---

# Backpressure setup

Why: [0005 Maximum backpressure](../decisions/0005-maximum-backpressure.md),
based on [Don't waste your back pressure](../sources/dont-waste-your-backpressure.md).

## The checks

| Check | Config | Runs in |
| --- | --- | --- |
| Swift 6 language mode, complete concurrency checking | tools-version 6.2 | every build |
| Upcoming features `ExistentialAny`, `InternalImportsByDefault`, `MemberImportVisibility`, `NonisolatedNonsendingByDefault`, `InferIsolatedConformances`, plus `strictMemorySafety()` | `strictSettings` in [Package.swift](../../Package.swift) | every build of hand-written targets |
| All warnings are errors | `.treatAllWarnings(as: .error)` | same |
| Formatting (4 spaces, 120 cols, documented public API, no force unwraps/try) | [.swift-format](../../.swift-format) | `make lint`, pre-commit, Claude Code PostToolUse hook, CI |
| Semantic lint (~60 opt-in rules, small functions/types/files) | [.swiftlint.yml](../../.swiftlint.yml), `--strict` | same |
| Tests + 90 % line coverage | [Scripts/check-coverage.py](../../Scripts/check-coverage.py) | `make check`, pre-push, CI |
| Wiki structure and privacy | [Scripts/wiki-lint.py](../../Scripts/wiki-lint.py) | `make lint`, pre-commit, CI |
| iOS/tvOS/watchOS/visionOS build, Linux build + tests | [ci.yml](../../.github/workflows/ci.yml) | CI |
| Generated code matches spec + generator | `make generate` + clean diff | CI |

`make check` = wiki lint + format lint + SwiftLint + build + tests + coverage.
Git hooks in [.githooks](../../.githooks/pre-commit) run lint on commit, and
`make check` plus `make test-linux` (when Docker is running) on push.

## Gotchas

- **swift-format vs SwiftLint on `case let`.** swift-format's
  `UseLetInEveryBoundCaseVariable` wants `case .x(let a)`; SwiftLint's
  `pattern_matching_keywords` wants `case let .x(a)`. The SwiftLint rule is
  disabled: swift-format owns layout, SwiftLint owns semantics.
- **`multilineTrailingCommaBehavior: alwaysUsed` is buggy** in the
  toolchain's swift-format (emits `],)` and then flags it), so we use
  `keptAsWritten`.
- **`NonisolatedNonsendingByDefault` changes closure types.** Conforming to
  `ClientMiddleware` needs `@concurrent @Sendable` on the `next` parameter.
- **`treatAllWarnings` only applies to targets that opt in.** The generated
  target doesn't: the upstream spec has deprecated fields that warn.
- `discouraged_none_name` caught a real bug (see [Architecture](architecture.md)).
- Timing-based compiler flags (`-warn-long-expression-type-checking`) were
  rejected: nondeterministic across machines.
