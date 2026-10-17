---
title: Generate the API layer from the OpenAPI spec
summary: Generate types and client from openapi.json with Apple's generator; hand-write only behaviour and ergonomics.
updated: 2026-10-17
---

# 0001 Generate the API layer from the OpenAPI spec

## Context

OpenRouter's API surface is large (~150 operations) and changes often.
OpenRouter publishes a complete OpenAPI 3.1 description
([OpenRouter OpenAPI spec](../sources/openrouter-openapi-spec.md)) and
documents behaviour separately ([OpenRouter API reference](../sources/openrouter-api-docs.md)).
Hand-writing models for every schema would be a lot of code that goes stale
within weeks.

## Decision

Generate types and the client with
[swift-openapi-generator](../sources/swift-openapi-generator.md) from the
committed spec, after normalising it
([OpenAPI pipeline](../concepts/openapi-pipeline.md)). Implement behaviour
described in the API reference (errors, retries, streaming) and ergonomics by
hand ([0003](0003-ergonomic-layer.md)).

## Consequences

- Upstream API changes become a regenerate plus compile errors, not manual
  model updates.
- Spec quirks have to be patched in `Scripts/patch_openapi.py`, and each
  patch is documented.
- Generated types are verbose (`value1`/`value2` for `anyOf`), which is why
  the ergonomic layer exists.
