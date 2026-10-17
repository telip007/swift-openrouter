# Wiki log

Append-only. Format: see [SCHEMA.md](SCHEMA.md#log-format).

## [2026-10-17] ingest | OpenRouter API reference
Captured the overview, authentication, errors-and-debugging, limits, parameters and streaming pages as the behavioural reference.

## [2026-10-17] ingest | OpenRouter OpenAPI spec and swift-openapi-generator
Documented the spec's quirks and the generator's limits that the pipeline patches around.

## [2026-10-17] ingest | Don't waste your back pressure; LLM wiki pattern
Rationale for the tooling setup and for this wiki.

## [2026-10-17] decision | Foundations
Recorded decisions 0001–0008: generation, filtering, ergonomic layer, platforms, backpressure, wiki, license, committing the spec.

## [2026-10-17] update | Initial implementation
Documented architecture, pipeline patches, errors (incl. errors after 200 OK, typed error_type, Retry-After), retries, streaming, platforms, testing, tooling and agent workflow.

## [2026-10-17] decision | Versioning and releases
SemVer from 0.1.0, CHANGELOG with Unreleased, `make release`, release workflow, weekly spec-update PRs, Dependabot.

## [2026-10-17] update | Linux build fix and local Linux gate
First CI run failed on Linux: `TimeAmount.nanoseconds` needs `import NIOCore` under MemberImportVisibility. Added NIOCore (Linux-only); pre-push now runs `make test-linux` when Docker is up.
