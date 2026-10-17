---
title: Platforms and transports
summary: Supported platforms, minimum versions, and why Apple uses URLSession while Linux uses AsyncHTTPClient.
updated: 2026-10-17
---

# Platforms and transports

Decision: [0004 Apple platforms and Linux](../decisions/0004-apple-platforms-and-linux.md).

| Platform | Minimum | Default transport |
| --- | --- | --- |
| macOS / Mac Catalyst | 15 | `URLSessionTransport` (swift-openapi-urlsession) |
| iOS / tvOS | 18 | `URLSessionTransport` |
| watchOS | 11 | `URLSessionTransport` |
| visionOS | 2 | `URLSessionTransport` |
| Linux | Swift 6.2 | `AsyncHTTPClientTransport` (swift-openapi-async-http-client) |

The minimums are the 2024 OS releases. The code relies on typed
`some AsyncSequence<Element, Failure>` return types, and the tests use
`Mutex` from Synchronization (macOS 15 / iOS 18 per Apple's docs).

The transport packages are conditional target dependencies
(`condition: .when(platforms:)` in [Package.swift](../../Package.swift)), and
the code selects them with `#if canImport(OpenAPIURLSession)`. Any
`ClientTransport` can be injected instead.

## Timeouts

`Configuration.timeout` means different things per transport:

- **URLSession**: `timeoutIntervalForRequest`, an *idle* timeout that resets
  on every received byte. Long streams are fine. If unset, system default.
- **AsyncHTTPClient**: a deadline for the *whole* request, streaming included.
  The transport's own default is 1 minute, which would cut off long
  generations, so we default to 1 hour.

## Gotchas

- Network errors differ: `URLError` on Apple, `HTTPClientError` on Linux.
  [Retries](retries.md) classify both.
- `FoundationNetworking` must be imported on Linux for `URLError`/`URLSession`.
- With `MemberImportVisibility`, using a member such as `TimeAmount.nanoseconds`
  requires importing its defining module (`NIOCore`), even when the type
  arrives through another module's API. This broke the first Linux CI run;
  `NIOCore` is now a Linux-only dependency.
- `make test-linux` (Docker, `swift:6.2-noble`) runs in the pre-push hook
  whenever Docker is up, with build artefacts cached in the
  `swift-openrouter-linux-build` volume. CI runs it on every push too.
