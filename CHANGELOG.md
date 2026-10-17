# Changelog

All notable changes to this project are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the project uses
[Semantic Versioning](https://semver.org/). While the version is `0.x`, minor
releases may contain breaking changes; they're called out under **Changed**.

## [Unreleased]

## [0.1.0] - 2026-10-17

### Added

- `OpenRouterClient` with `chat` (send, stream), `models`, `credits`,
  `generations` and `apiKey` resources, plus the generated low-level client
  as `api`.
- Generated API layer for the Chat, Responses, Anthropic Messages, Models,
  Credits, Generations, API Keys, Endpoints, Providers and Embeddings tags.
- Typed `OpenRouterError` with `kind`, `errorType`, `providerCode`,
  `retryAfter` and `isMidStream`, including errors reported after `200 OK`.
- Retries with exponential backoff, jitter and `Retry-After` support.
- Streaming with `ChatStreamAccumulator` for text, reasoning and tool calls.
- Message, tool and tool-choice builders; `JSONValue` for JSON Schema literals.
- macOS, iOS, tvOS, watchOS, visionOS (URLSession) and Linux (AsyncHTTPClient).
