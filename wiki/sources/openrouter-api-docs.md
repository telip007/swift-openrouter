---
title: OpenRouter API reference
summary: The official API docs, the normative source for behaviour; what they specify and where this package implements it.
updated: 2026-10-17
---

# OpenRouter API reference

Raw capture: [raw/2026-10-17-openrouter-api-docs.md](../raw/2026-10-17-openrouter-api-docs.md).
Live docs: https://openrouter.ai/docs/api_reference/overview. For agents:
https://openrouter.ai/docs/llms.txt, and every page is available as Markdown
by appending `.md` to its URL.

The docs are **normative for behaviour**; the [OpenAPI spec](openrouter-openapi-spec.md)
is normative for **data shapes**. When they disagree, follow the docs for
behaviour, the live API for shapes, and record the contradiction here.

## What the docs specify, and where we implement it

| Topic | Docs | Implementation |
| --- | --- | --- |
| Request/response schema normalised across providers; `finish_reason` normalised to five values, more possible | [Overview](https://openrouter.ai/docs/api_reference/overview) | Open-enum patch + `FinishReason` constants: [OpenAPI pipeline](../concepts/openapi-pipeline.md) |
| Attribution headers `HTTP-Referer`, `X-OpenRouter-Title`, `X-OpenRouter-Categories` | [Overview § Headers](https://openrouter.ai/docs/api_reference/overview) | `Configuration.appURL` / `appTitle`: [Architecture](../concepts/architecture.md) |
| Bearer API keys; OAuth PKCE for user keys | [Authentication](https://openrouter.ai/docs/api_reference/authentication) | `OpenRouterClient(apiKey:)`, `fromEnvironment()` |
| Error envelope, status codes, errors after `200 OK`, typed `error_type` | [Errors and debugging](https://openrouter.ai/docs/api_reference/errors-and-debugging) | [Errors](../concepts/errors.md) |
| `Retry-After` on 429/503 and on in-flight-budget 402 | [Errors § Retry-After](https://openrouter.ai/docs/api_reference/errors-and-debugging), [Limits](https://openrouter.ai/docs/api_reference/limits) | [Retries](../concepts/retries.md), `OpenRouterError.retryAfter` |
| SSE comments, `[DONE]`, mid-stream errors, final usage chunk, cancellation | [Streaming](https://openrouter.ai/docs/api_reference/streaming) | [Streaming](../concepts/streaming.md) |
| Sampling and routing parameters | [Parameters](https://openrouter.ai/docs/api_reference/parameters) | Generated `ChatRequest` fields |

## Contradictions and gaps

> **Contradiction:** the spec's `GET /models` example omits `links` and
> `total_count`, which its schema requires and the live API returns. Our
> schema follows the live API; `SpecExampleTests` tracks the stale example
> as a known issue.

- Not yet surfaced by the convenience layer: the `X-Generation-Id` response
  header, `native_finish_reason`, and the 403 budget metadata
  (`remedy_hint`, `resets_at`). All are reachable via `api` or `metadata`.
