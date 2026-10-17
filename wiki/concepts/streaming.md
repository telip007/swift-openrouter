---
title: Streaming
summary: How chat streams are decoded, terminated and accumulated, and the SSE quirks involved.
updated: 2026-10-17
---

# Streaming

Behavioural reference: [streaming](https://openrouter.ai/docs/api_reference/streaming)
(summary: [OpenRouter API reference](../sources/openrouter-api-docs.md)).
Implementation: `chat.stream(_:)` and `HTTPBody.chatStreamChunks()` in
[Chat.swift](../../Sources/OpenRouter/Resources/Chat.swift),
[ChatStreamAccumulator.swift](../../Sources/OpenRouter/Sugar/ChatStreamAccumulator.swift).

## Wire format

- `Accept: text/event-stream` with `stream: true`. Each event's `data:` is a
  JSON `ChatStreamChunk`.
- Comment lines such as `: OPENROUTER PROCESSING` keep the connection alive
  while a provider queues. They produce events without data, and those are
  dropped.
- The stream ends with `data: [DONE]`. Decoding stops at the sentinel, so
  anything after it is ignored.
- Errors after the 200: a chunk with a top-level `error: {code, message,
  metadata: {error_type, provider_code}}` and `finish_reason: "error"`. It's
  thrown as `OpenRouterError(isMidStream: true)` with `errorType` set.
- Every Chat Completions stream ends with a usage chunk before `[DONE]`. It
  repeats the final `finish_reason` with an empty delta, so treat it as
  accounting, not as a second completion.
- Cancelling the consuming task cancels the transport request, closing the
  connection. Per the docs, that stops generation and billing for supported
  providers.

## Accumulating

`ChatStreamAccumulator` rebuilds the assistant message:

- Text and reasoning deltas are concatenated.
- Tool calls stream as fragments keyed by `index`. The first fragment carries
  `id` and `function.name`, later ones append to `function.arguments`.
  Several tool calls can interleave.
- `message` returns a `ChatAssistantMessage` ready to append to the history,
  with `tool_calls` omitted when empty (some providers reject `[]`).

## Gotchas

- `finish_reason` is `null` in every chunk but the last, which is why
  nullable-required fields must become optional
  ([OpenAPI pipeline](openapi-pipeline.md), patch 0).
- `send(_:)` and `stream(_:)` force `request.stream` to `false`/`true`, so
  callers can't mismatch the request flag and the decoding path.
- On Linux the transport is AsyncHTTPClient. URLSession on Linux buffers
  whole responses, so streams would only arrive at the end. See
  [Platforms and transports](platforms-and-transports.md).
