---
title: OpenRouter OpenAPI spec
summary: The upstream API description we generate from, its shape and its known quirks.
updated: 2026-10-17
---

# OpenRouter OpenAPI spec

Behavioural reference: [OpenRouter API reference](openrouter-api-docs.md).
The committed copy, [openapi/openapi.json](../../openapi/openapi.json), is
itself the raw source for generation (sorted keys, masked sample keys,
otherwise unmodified).

- OpenAPI 3.1.0 with vendor extensions (`x-speakeasy-unknown-values`,
  `x-speakeasy-name-override`, `x-speakeasy-sse-sentinel: "[DONE]"`, …),
  published at https://openrouter.ai/openapi.json.
- Error responses share one envelope:
  `{"error": {"code", "message", "metadata"}, "user_id"?, "openrouter_metadata"?}`.
- Streaming endpoints declare `text/event-stream` with a `[DONE]` sentinel.
- Quirks that break or mislead swift-openapi-generator, and the patch for
  each: [OpenAPI pipeline](../concepts/openapi-pipeline.md#spec-patches).
