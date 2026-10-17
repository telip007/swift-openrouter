# OpenRouter API reference — capture

- Captured: 2026-10-17
- Index for agents: https://openrouter.ai/docs/llms.txt (API reference
  sub-index: https://openrouter.ai/docs/_llms/api-reference.txt). Every page
  is also served as Markdown by appending `.md`.
- Pages read in full:
  - https://openrouter.ai/docs/api_reference/overview
  - https://openrouter.ai/docs/api_reference/authentication
  - https://openrouter.ai/docs/api_reference/errors-and-debugging
  - https://openrouter.ai/docs/api_reference/limits
  - https://openrouter.ai/docs/api_reference/parameters
  - https://openrouter.ai/docs/api_reference/streaming
- OpenAPI spec: https://openrouter.ai/openapi.json (YAML: /openapi.yaml)
- Copyright belongs to OpenRouter. This file holds excerpts and notes only.

## Excerpts

Overview:

> OpenRouter normalizes the schema across models and providers so you only
> need to learn one.

> OpenRouter normalizes each model's `finish_reason` to one of the following
> values: `tool_calls`, `stop`, `length`, `content_filter`, `error`. Some
> models and providers may have additional finish reasons.

> `HTTP-Referer`: Identifies your app on openrouter.ai.
> `X-OpenRouter-Title`: Sets/modifies your app's title (`X-Title` also accepted).
> `X-OpenRouter-Categories`: Assigns marketplace categories.

Errors and debugging:

> The HTTP Response will have the same status code as `error.code`, forming a
> request error if: Your original request is invalid; Your API key/account is
> out of credits. Otherwise, the returned HTTP response status will be 200
> and any error occurred while the LLM is producing the output will be
> emitted in the response body or as an SSE data event.

> On 429 and 503 responses, and on 402 responses whose
> `error.metadata.limit_source` is `openrouter_in_flight_budget`, OpenRouter
> may include a standard HTTP `Retry-After` response header … A 402 without
> the header is not a wait-and-retry case.

> `error.metadata.error_type` carries a typed code you can switch on
> programmatically.

> When a request fails with a `500`, the `message` is replaced with a generic
> string and `provider_code` and `openrouter_metadata` are omitted, but
> `error_type` is still present (`server`).

Streaming:

> OpenRouter occasionally sends comments to prevent connection timeouts.
> These comments look like: `: OPENROUTER PROCESSING`

> On the Chat Completions endpoint, every stream ends with an extra chunk
> that carries the `usage` object for the request, sent just before the
> `[DONE]` message … the terminal `finish_reason` appears twice.

> The generation ID is returned in the `X-Generation-Id` response header for
> all endpoints.

> Streaming requests can be cancelled by aborting the connection. For
> supported providers, this immediately stops model processing and billing.

## Notes

- Typed `error_type` values seen in the table include
  `context_length_exceeded`, `max_tokens_exceeded`, `authentication`,
  `permission_denied`, `payment_required`, `rate_limit_exceeded`,
  `provider_overloaded`, `provider_unavailable`, `invalid_request`,
  `invalid_prompt`, `not_found`, `content_policy_violation`, `refusal`,
  `server`.
- The `/models` response example in the spec omits `links` and `total_count`,
  which the schema requires and the live API returns (checked 2026-10-17).
- Docs date formats mix whole and fractional seconds in ISO 8601 timestamps.
