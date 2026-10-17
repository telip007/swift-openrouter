---
title: Generate a filtered subset of operations
summary: Only the commonly used tags are generated to keep build times reasonable; widening is one config line.
updated: 2026-10-17
---

# 0002 Generate a filtered subset of operations

## Context

Generating the whole spec yields ~184k lines and roughly doubles clean build
times (numbers in [OpenAPI pipeline](../concepts/openapi-pipeline.md#filtering)).
Most clients use chat, models and account endpoints. Management APIs
(workspaces, guardrails, SCIM, …) are for administrative tooling.

## Decision

Generate only these tags: Chat, Responses, Anthropic Messages, Models,
Credits, Generations, API Keys, Endpoints, Providers, Embeddings. Everything
generated is reachable through `OpenRouterClient.api`.

## Consequences

- Requests for more endpoints are a one-line change in
  `openapi/generator-config.yaml` plus `make generate`. Contributions are
  welcome when there's a use case.
- If build times become a non-issue (or SwiftPM gains per-operation
  products), revisit generating everything.
