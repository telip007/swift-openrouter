---
title: Support all Apple platforms and Linux
summary: One package for apps, CLIs and servers, with per-platform default transports.
updated: 2026-10-17
---

# 0004 Support all Apple platforms and Linux

## Context

OpenRouter is used from servers (Linux), command-line tools, and native apps
with bring-your-own-key or OAuth PKCE flows. Supporting extra Apple platforms
costs one `platforms:` line. Linux needs a different transport for real
streaming.

## Decision

Support macOS 15+, iOS/tvOS 18+, watchOS 11+, visionOS 2+ and Linux.
Default to URLSession on Apple platforms and AsyncHTTPClient on Linux
([Platforms and transports](../concepts/platforms-and-transports.md)).

## Consequences

- CI runs on macOS and on Linux (`swift:6.2-noble`).
- Platform-specific code stays behind `canImport` checks with tests on both.
- Apps shipping an API key in the binary is unsafe. Docs point to per-user
  keys or OAuth instead.
