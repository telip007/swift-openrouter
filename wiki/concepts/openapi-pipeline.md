---
title: OpenAPI pipeline
summary: How openapi.json becomes the OpenRouterAPI target, every spec patch and why it exists.
updated: 2026-10-17
---

# OpenAPI pipeline

Why we generate: [0001](../decisions/0001-generate-from-openapi.md). How to run
it: the `regenerate-api` skill or `make generate` / `make generate-fetch`.

```text
https://openrouter.ai/openapi.json
  └─(--fetch, sorted keys)→ openapi/openapi.json          committed, the raw source of truth
      └─ Scripts/patch_openapi.py → (temp) patched.json   normalisations below
          └─ swift-openapi-generator (pinned in Tools/)    filter: openapi/generator-config.yaml
              └→ Sources/OpenRouterAPI/Generated/*.swift   committed, never edited by hand
```

- [Scripts/generate.sh](../../Scripts/generate.sh) drives it.
- The generator CLI is pinned with `exact:` in
  [Tools/Package.swift](../../Tools/Package.swift). It's a separate package so
  that SDK consumers never fetch the generator and its dependencies.
- Generated code is committed (not a build plugin): it's greppable and
  reviewable in diffs, and consumers don't pay for a plugin run.
- The spec carries vendor extensions (`x-speakeasy-*`) that other generators
  understand; we strip them. See [OpenRouter OpenAPI spec](../sources/openrouter-openapi-spec.md).

## Spec patches

[Scripts/patch_openapi.py](../../Scripts/patch_openapi.py) applies these, in order:

| # | Upstream quirk | Symptom without the patch | Patch |
| --- | --- | --- | --- |
| 0 | Properties that are `required` **and** nullable (`type: [string, null]`, `nullable`, `enum` containing `null`, or `$ref` to a nullable component) | Non-optional Swift property; decoding `"system_fingerprint": null` or a stream chunk's `"finish_reason": null` throws | Drop nullable properties from `required` → Swift optional. `$ref`s are resolved against the set of nullable components collected up front. |
| 1a | `x-speakeasy-unknown-values: allow` marks *open* enums the server extends | A closed Swift enum fails to decode new values (e.g. a new `finish_reason`) | Remove `enum` → plain `String`. Well-known values live in sugar (`FinishReason`). |
| 1b | Speakeasy vendor extensions, one inside `discriminator.mapping` | Generator error: *Invalid discriminator.mapping value* | Drop every `x-speakeasy-*` key. |
| 2 | OpenAPI 3.0 boolean `exclusiveMinimum: true` inside a 3.1 document | Parse error: *Expected exclusiveMinimum … parsable as Double* | Fold into the 3.1 numeric form. |
| 3 | `{type: null}` branches in `anyOf`/`oneOf` | Generator skips the branch but still references its payload type → code doesn't compile | Remove null branches (and duplicates); collapse single-branch wrappers. |
| 4 | `type: [X, "null"]`, `enum` with `null`, 3.0 `nullable` | Rejected or ignored by the 3.1 parser | Normalise to `type: X` (nullability already handled by 0). |

Remaining generator warnings (1 known: a `required` entry missing from
`properties` upstream) are counted and printed by `generate.sh`.

## Filtering

Only the tags in [generator-config.yaml](../../openapi/generator-config.yaml)
are generated: [0002](../decisions/0002-filtered-generation.md). Rough numbers
from 2026-10-17 (debug, clean build, a recent Mac):

| Scope | Swift lines | Clean build of the generated target |
| --- | --- | --- |
| Full spec (~150 operations) | ~184k | ~120 s |
| Filtered (10 tags) | ~67k | ~50 s |

## Gotchas

- **Sample API keys in upstream examples.** The spec's examples contain
  full-length `sk-or-v1-…` sample keys. They aren't real, but GitHub push
  protection rejects them. `generate.sh --fetch` masks them to the spec's own
  short form (`sk-or-v1-0e6...1c96`) before writing `openapi.json`. This is
  the only change made to the committed spec besides key sorting.

- `anyOf` schemas become structs with `value1`, `value2`, … optional
  payloads, and `oneOf` with a discriminator becomes an enum. The
  [ergonomic layer](architecture.md) hides the common ones behind builders.
- Generator 1.14 splits types into `Types+Components+Schemas.swift`,
  `Types+Operations.swift`, …. `generate.sh` deletes stale outputs first, so
  narrowing the filter doesn't leave orphaned files.
- The generator's `ChatStreamingResponse` schema (`{data: chunk}`) describes
  the SSE envelope. Streams are decoded into `ChatStreamChunk` directly; see
  [Streaming](streaming.md).
