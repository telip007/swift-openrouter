---
title: Errors
summary: How HTTP errors, errors after 200 OK and stream errors become OpenRouterError, and what callers see.
updated: 2026-10-17
---

# Errors

Behavioural reference: [errors and debugging](https://openrouter.ai/docs/api_reference/errors-and-debugging),
summarised in [OpenRouter API reference](../sources/openrouter-api-docs.md).

## What callers get

| Failure | Thrown type |
| --- | --- |
| Non-2xx response from any operation | `OpenRouterError` |
| Error after `200 OK`: SSE error event, or error body on a non-streaming chat request | `OpenRouterError` with `isMidStream == true` |
| Network failure | `URLError` (Apple) / `HTTPClientError` (Linux) |
| Cancellation | `CancellationError` |
| Missing `OPENROUTER_API_KEY` in `fromEnvironment` | `MissingAPIKeyError` (typed throws) |
| Response doesn't match the spec | `ClientError` from the generated client (keeps operation context for debugging) |

`OpenRouterError` carries `statusCode`, `kind` (derived from the status),
`message`, `metadata`, `errorType` (the docs' typed
`error.metadata.error_type`, e.g. `context_length_exceeded`), `providerCode`,
`retryAfter`, `isMidStream`, `isRetryable` and `rawBody`.

**Prefer `errorType` for programmatic handling.** The docs call it stable
across providers and response formats, while status codes are coarse (several
error types share 400 or 403).

## How

- [ErrorMiddleware](../../Sources/OpenRouter/Middleware/ErrorMiddleware.swift)
  - buffers up to 1 MiB of a non-2xx body, decodes the envelope
    `{"error": {"code", "message", "metadata"}}`, and reads `Retry-After`;
  - for `sendChatCompletionRequest` JSON responses, buffers the `200` body and
    throws if it is an error envelope. The docs state that failures after
    the status is sent arrive "in the response body", and decoding that as a
    `ChatResult` would otherwise produce a confusing decoding error;
  - if the body isn't an envelope, uses `HTTP <status>` as the message and
    keeps the text in `rawBody`.
- Because errors are thrown in the middleware, wrappers can use `output.ok`
  without switching over each operation's ~12 error cases.
- The generated client wraps everything thrown below it in `ClientError`.
  Wrappers call `unwrappingClientError` (in
  [OpenRouterError.swift](../../Sources/OpenRouter/OpenRouterError.swift)) to
  surface the underlying error. Calls made directly on `api` still see
  `ClientError`.
- Stream error chunks are converted in `HTTPBody.chatStreamChunks()`
  ([Streaming](streaming.md)).

## Gotchas

- `HTTPResponse.Status(code:)` has an empty reason phrase for arbitrary codes,
  so the fallback message is `HTTP <code>`, not a phrase.
- On 500s the docs say the message is replaced with a generic string and
  `provider_code` is omitted, but `error_type` (`server`) remains.
- 403 covers several cases (guardrail block, budget exhausted, moderation,
  refusal). Use `errorType` and `metadata` (`remedy_hint`, `resets_at`) to
  tell them apart.
- Only chat completions are checked for in-band errors. Other inference
  endpoints (Responses, Messages) use different error shapes and are
  reachable via `api` without that check.
