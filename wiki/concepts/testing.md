---
title: Testing
summary: How the tests are structured, the mock transport, spec-example conformance tests and the coverage gate.
updated: 2026-10-17
---

# Testing

All tests use Swift Testing and run without network access.

| Suite | File | Covers |
| --- | --- | --- |
| Chat | [ChatTests.swift](../../Tests/OpenRouterTests/ChatTests.swift) | send/stream, headers, request body, HTTP errors, in-band and mid-stream errors, `Retry-After` |
| Builders | [BuilderTests.swift](../../Tests/OpenRouterTests/BuilderTests.swift) | exact JSON produced by message/tool/tool-choice builders |
| ChatStreamAccumulator | [StreamAccumulatorTests.swift](../../Tests/OpenRouterTests/StreamAccumulatorTests.swift) | fragmented, interleaved tool calls; text and reasoning |
| Retries | [RetryTests.swift](../../Tests/OpenRouterTests/RetryTests.swift) | backoff math, `Retry-After`, give-up, network errors |
| Client | [ClientTests.swift](../../Tests/OpenRouterTests/ClientTests.swift) | environment config, platform wrappers, status → kind, dates |
| Spec examples | [SpecExampleTests.swift](../../Tests/OpenRouterTests/SpecExampleTests.swift) | the official response examples in `openapi.json` decode through the wrappers |
| README examples | [ReadmeExampleTests.swift](../../Tests/OpenRouterTests/ReadmeExampleTests.swift) | the README's code samples compile and run, so docs can't drift from the API |

## Mock transport

[MockTransport](../../Tests/OpenRouterTests/Support/MockTransport.swift)
implements `ClientTransport`, answers from a closure that receives the
attempt number, and records every request (headers and body). Tests build the
real `OpenRouterClient` with it, so the full middleware chain is exercised.
Transport paths are relative to the server URL (`/chat/completions`, not
`/api/v1/...`).

## Spec examples as conformance tests

`SpecExampleTests` serves the `200` examples published in the spec. This
is cheap backpressure against the patched schema drifting from reality. It
already found the fractional-seconds date bug ([Architecture](architecture.md))
and a stale upstream example, which is tracked with `withKnownIssue` so the
test flags when upstream fixes it.

## Coverage

`make coverage` enforces 90 % line coverage of `Sources/OpenRouter`
(generated code excluded) via [Scripts/check-coverage.py](../../Scripts/check-coverage.py).
See [Backpressure setup](backpressure-setup.md).

## Gotchas

- Mocked sleeps don't advance the clock (see [Retries](retries.md)).
- Linux tests need several GB of RAM to compile the generated target. Docker
  Desktop's default of 1 GB gets the compiler killed (signal 9); give it
  ~6 GB (Settings → Resources). The first run takes ~2–3 minutes; later runs
  reuse the cached volume.
