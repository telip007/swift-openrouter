---
title: Commit the OpenAPI spec
summary: The upstream spec is committed rather than fetched at build time, because it can't be pinned and generated code embeds it anyway.
updated: 2026-10-17
---

# 0008 Commit the OpenAPI spec

## Context

Generation could fetch `https://openrouter.ai/openapi.json` on demand instead
of committing a copy. But the spec has no versioned URL (`info.version` stays
`1.0.0`), so a fetched spec can't be pinned: every regeneration could produce
different code, and CI's "generated code is up to date" check would be
meaningless. The generated Swift also embeds the spec's content (descriptions
become doc comments, schemas become types), so not committing the raw file
would barely change what the repository contains. OpenRouter's API overview
explicitly invites using the spec "with any OpenAPI-compatible code generator
to … generate client libraries".

## Decision

Commit `openapi/openapi.json` as the pinned input: sorted keys and masked
sample API keys ([OpenAPI pipeline](../concepts/openapi-pipeline.md#gotchas)),
otherwise unmodified. Update it only via `make generate-fetch`, in its own commit or
PR, so spec changes are reviewable.

## Consequences

- Regeneration is reproducible, and spec drift shows up as a reviewable diff.
- `SpecExampleTests` can use the official examples offline.
- If OpenRouter ever objects to redistribution, switch to fetching plus a
  committed checksum and ship the examples as test fixtures instead.
