---
title: swift-openapi-generator
summary: Apple's OpenAPI code generator and runtime, the version pinned here, and its limits as relevant to this spec.
updated: 2026-10-17
---

# swift-openapi-generator

Repository: https://github.com/apple/swift-openapi-generator (Apache 2.0).
Runtime: swift-openapi-runtime. Transports: swift-openapi-urlsession,
swift-openapi-async-http-client.

- Pinned exactly in [Tools/Package.swift](../../Tools/Package.swift) (1.14.1 at
  creation). Bumping it is a normal change: regenerate, `make check`, log it.
- Config used: `types` + `client`, `accessModifier: public`,
  `namingStrategy: idiomatic`, tag `filter`.
- Limits relevant here: `{type: null}` schemas are unsupported (skipped but
  still referenced in `anyOf`), strict 3.1 parsing (rejects 3.0
  `exclusiveMinimum: true`), and closed enums for every `enum`. All are
  handled in [OpenAPI pipeline](../concepts/openapi-pipeline.md).
- Runtime facts we rely on: middlewares see transport errors wrapped in
  `ClientError`; `HTTPBody.asDecodedServerSentEventsWithJSONData(of:decoder:while:)`
  decodes SSE; `OpenAPIValueContainer` has scalar literals only.
