---
title: Hand-written ergonomic layer over the generated client
summary: Typed errors via middleware, retries, short type names, builders and stream helpers on top of generated code.
updated: 2026-10-17
---

# 0003 Hand-written ergonomic layer over the generated client

## Context

Generated APIs are complete but awkward: every operation returns an enum of
~12 status cases, `anyOf` content is `value1`/`value2`, tool schemas need
`OpenAPIValueContainer`, and streaming needs manual SSE decoding.

## Decision

Ship two targets: generated `OpenRouterAPI` (re-exported) and hand-written
`OpenRouter` ([Architecture](../concepts/architecture.md)). The hand-written
layer is deliberately thin:

- errors are handled once, in a middleware ([Errors](../concepts/errors.md)),
- retries follow the API reference's `Retry-After` guidance
  ([Retries](../concepts/retries.md)),
- wrappers exist only for the most common operations; `api` covers the rest,
- convenience lives in extensions on generated types (builders, accessors),
  not in parallel model types.

## Consequences

- One source of truth for data shapes (the spec). Sugar can't drift from it.
- New conveniences should be extensions with tests, not new model types.
