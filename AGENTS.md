# AGENTS.md

Instructions for coding agents (and humans) working on swift-openrouter.

## What this is

A Swift client for the OpenRouter API. Two targets:

- `OpenRouterAPI`: generated from `openapi/openapi.json`. **Never edit
  `Sources/OpenRouterAPI/Generated/` by hand**; see "Regenerating".
- `OpenRouter`: the hand-written public API (client, middlewares, builders,
  streaming helpers). Most changes happen here.

## Before you start

1. Read `wiki/index.md` and the pages relevant to your task. The wiki records
   why things are the way they are (spec patches, retry rules, gotchas).
2. API behaviour questions: the official docs are normative
   (`wiki/sources/openrouter-api-docs.md`, https://openrouter.ai/docs/llms.txt;
   append `.md` to any docs URL for Markdown).
3. Dependency APIs: read the exact resolved versions in `.build/checkouts/`.
   Apple/Swift docs: the DocC JSON behind a page
   (`https://developer.apple.com/tutorials/data/documentation/<path>.json`) or
   a Markdown converter such as sosumi.ai.

## Commands

| Command | What |
| --- | --- |
| `make bootstrap` | install SwiftLint (Homebrew), enable git hooks |
| `make fix` | auto-format |
| `make check` | wiki lint + swift-format + SwiftLint + build + tests + 90% coverage |
| `make test-linux` | tests in a `swift:6.2-noble` container (needs ~6 GB of Docker memory; runs in pre-push when Docker is up) |
| `make generate` / `make generate-fetch` | regenerate the API layer (from the committed / latest spec) |

## Rules

- `make check` must pass before you call work done. Quote the result.
- Never weaken a check (no lint disables, no lowering coverage, no
  `@preconcurrency`/`nonisolated(unsafe)`/`try!` to silence the compiler).
  If a rule seems wrong, ask a maintainer and record a decision in
  `wiki/decisions/`.
- Public API needs doc comments and tests. Behaviour that follows the API docs
  should link the relevant docs page.
- Never name a static member `none` (it collides with `Optional.none`).
- Keep `README.md` and `Tests/OpenRouterTests/ReadmeExampleTests.swift` in sync.
- User-visible changes get an entry under **Unreleased** in `CHANGELOG.md`.
  Releases are cut by maintainers only (`make release VERSION=x.y.z`).
- Platform-conditional code (`canImport`, transports) must keep Linux working.
  CI checks macOS, iOS/tvOS/watchOS/visionOS builds and Linux.
- Public repository: never put personal data, local paths, machine details
  or references to unrelated projects in code, docs, wiki or commit messages.

## Regenerating

Change `openapi/generator-config.yaml` (tag filter) or `Scripts/patch_openapi.py`
(spec normalisation), then `make generate`. Each patch needs a comment and a row
in `wiki/concepts/openapi-pipeline.md`. Details: `.claude/skills/regenerate-api/SKILL.md`.

## Wiki duties

After any change to code, configuration, tooling or decisions:

1. Update the affected pages in `wiki/` and bump their `updated:` date.
2. Add a decision record for new decisions, and gotchas to the relevant page.
3. Append `## [YYYY-MM-DD] update | <what>` to `wiki/log.md`.
4. `make wiki-lint`.

Conventions: `wiki/SCHEMA.md`. Workflow: `.claude/skills/wiki/SKILL.md`.
