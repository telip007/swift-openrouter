---
title: Retries
summary: The backoff algorithm, what is retried and why, and retry pitfalls.
updated: 2026-10-17
---

# Retries

Implementation: [RetryPolicy.swift](../../Sources/OpenRouter/Middleware/RetryPolicy.swift),
[RetryMiddleware.swift](../../Sources/OpenRouter/Middleware/RetryMiddleware.swift).
Tests: [RetryTests.swift](../../Tests/OpenRouterTests/RetryTests.swift).
Behavioural reference: [OpenRouter API reference](../sources/openrouter-api-docs.md)
(errors § Retry-After, limits).

## Algorithm

- Delay before retry *n* (0-based): `initial × (n+1)^exponent`, shifted by a
  random jitter of up to ±25 %, ≤ 0 → `initial`, capped at `maxInterval`.
- Defaults: `initial` 500 ms, `maxInterval` 60 s, `exponent` 1.5,
  `maxElapsedTime` 5 min.
- `Retry-After-Ms` (milliseconds), then `Retry-After` (seconds or an HTTP
  date) override the computed delay. The docs promise `Retry-After` on 429
  and 503.
- Stop once `elapsed + next delay ≥ maxElapsedTime`. The last response or
  error is returned as-is (and then mapped by [Errors](errors.md)).
- Retried statuses: 429 and all 5xx (`RetryPolicy.defaultRetryableStatusCodes`).
- Network failures: timeouts, DNS errors and unreachable hosts are retried for
  any method. A dropped connection is retried only for idempotent methods,
  since the server may already have acted.
- `RetryPolicy.disabled` turns everything off (not `none`, see
  [Architecture](architecture.md)).

## What is deliberately not retried

- **402 Payment Required.** Per the docs, a 402 is only a wait-and-retry case
  when `error.metadata.limit_source == "openrouter_in_flight_budget"` *and*
  `Retry-After` is present. Callers decide; the header value is exposed as
  `OpenRouterError.retryAfter`.
- **Errors after `200 OK`** (mid-stream or in-band). Partial output may
  already have been produced and billed, so replaying is the caller's call.
- **4xx other than 429**: retrying an invalid request can't succeed.

## Gotchas

- **Transport errors reach middlewares already wrapped in `ClientError`.**
  The first version checked `error as? URLError` and never retried network
  failures. `isTransient` unwraps `ClientError` first. A test covers this.
- Request bodies with `iterationBehavior == .single` can't be re-sent. Such
  requests bypass retries. Generated JSON bodies are `.multiple`.
- Tests inject `sleep` and `random`. Because the mocked sleep doesn't advance
  the clock, only the *next* delay counts against `maxElapsedTime` in tests.
