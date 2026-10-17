---
title: Architecture
summary: The two targets, the middleware chain, resource wrappers and the convenience layer.
updated: 2026-10-17
---

# Architecture

```text
OpenRouter (product, `import OpenRouter`)          hand-written, strict settings
 ├─ OpenRouterClient          configuration, transport selection, resources
 │    ├─ chat / models / credits / generations / apiKey   thin wrappers over `api`
 │    └─ api: Client          the generated client, for every other operation
 ├─ Middleware                ErrorMiddleware → RetryMiddleware → HeadersMiddleware → user middlewares → transport
 └─ Sugar                     builders, accessors, ChatStreamAccumulator, JSONValue
OpenRouterAPI (generated)                           re-exported via @_exported
```

Rationale: [0003 Ergonomic layer](../decisions/0003-ergonomic-layer.md).

## Middleware chain

Order matters ([OpenRouterClient.swift](../../Sources/OpenRouter/OpenRouterClient.swift)):

1. [ErrorMiddleware](../../Sources/OpenRouter/Middleware/ErrorMiddleware.swift) is
   outermost. It sees the final response after retries and throws
   `OpenRouterError` for any non-2xx. See [Errors](errors.md).
2. [RetryMiddleware](../../Sources/OpenRouter/Middleware/RetryMiddleware.swift)
   re-sends the request on retryable statuses and network failures. See
   [Retries](retries.md).
3. [HeadersMiddleware](../../Sources/OpenRouter/Middleware/HeadersMiddleware.swift)
   sets `Authorization`, `User-Agent`, and the attribution headers
   (`HTTP-Referer`, `X-OpenRouter-Title`) unless the request already set them.
4. User middlewares run innermost, so they see every attempt (good for logging).

## Naming

- Short public aliases for the common generated types live in
  [Exports.swift](../../Sources/OpenRouter/Exports.swift): `ChatRequest`,
  `ChatMessage`, `ChatTool`, `ModelInfo`, `CreditBalance`, ….
- The client type is `OpenRouterClient`, not `OpenRouter`. A type with the
  module's name breaks module-qualified lookup (`OpenRouter.ChatRequest`).
- Resource types are nested (`OpenRouterClient.Chat`, `.Models`, …) so
  they don't collide with the aliases.

## Gotchas

- Never name a static member `none` on a type that is used as an optional:
  `toolChoice: .none` resolves to `Optional.none` (`nil`) and silently sends
  nothing. SwiftLint's `discouraged_none_name` caught this in
  `ChatToolChoice` and `RetryPolicy`. Both use `.disabled` instead.
- `OpenAPIValueContainer` has no array or dictionary literals, so tool
  schemas use [JSONValue](../../Sources/OpenRouter/Sugar/JSONValue.swift), which
  converts losslessly.
- Timestamps mix whole and fractional seconds (`…:59Z` and `…:00.000Z` in
  one `GET /key` response). The runtime's default `.iso8601` transcoder
  rejects fractional seconds, so the client is configured with
  [LenientISO8601DateTranscoder](../../Sources/OpenRouter/Sugar/LenientISO8601DateTranscoder.swift).
  Found by [spec example tests](testing.md).
- Generated `anyOf` content (`content.value1` is a string, `content.value2`
  is parts) is wrapped by `ChatAssistantMessage.text`, which joins text parts.
