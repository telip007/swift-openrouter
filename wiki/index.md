# Wiki index

Start here. Conventions: [SCHEMA.md](SCHEMA.md). Timeline: [log.md](log.md).

## Concepts

- [Architecture](concepts/architecture.md): the two targets, the middleware chain, resource wrappers and the convenience layer.
- [OpenAPI pipeline](concepts/openapi-pipeline.md): how openapi.json becomes the OpenRouterAPI target, every spec patch and why it exists.
- [Errors](concepts/errors.md): how HTTP errors, errors after 200 OK and stream errors become OpenRouterError, and what callers see.
- [Retries](concepts/retries.md): the backoff algorithm, what is retried and why, and retry pitfalls.
- [Streaming](concepts/streaming.md): how chat streams are decoded, terminated and accumulated, and the SSE quirks involved.
- [Platforms and transports](concepts/platforms-and-transports.md): supported platforms, minimum versions, and why Apple uses URLSession while Linux uses AsyncHTTPClient.
- [Testing](concepts/testing.md): how the tests are structured, the mock transport, spec-example conformance tests and the coverage gate.
- [Backpressure setup](concepts/backpressure-setup.md): every automated check in this repository, where it runs, and the traps hit while wiring it up.
- [Releasing](concepts/releasing.md): versioning, the changelog, how a release is cut and published, and the automated spec-update and dependency PRs.
- [Agent workflow](concepts/agent-workflow.md): how AGENTS.md, skills, hooks and the wiki make every agent session follow the same rules.

## Decisions

- [0001 Generate the API layer from the OpenAPI spec](decisions/0001-generate-from-openapi.md): generate types and client from openapi.json; hand-write only behaviour and ergonomics.
- [0002 Generate a filtered subset of operations](decisions/0002-filtered-generation.md): only the commonly used tags are generated; widening is one config line.
- [0003 Ergonomic layer](decisions/0003-ergonomic-layer.md): typed errors via middleware, retries, short type names, builders and stream helpers on top of generated code.
- [0004 Apple platforms and Linux](decisions/0004-apple-platforms-and-linux.md): one package for apps, CLIs and servers, with per-platform default transports.
- [0005 Maximum backpressure](decisions/0005-maximum-backpressure.md): warnings are errors, strict lint, 90% coverage gate, hooks and CI.
- [0006 LLM-maintained wiki](decisions/0006-llm-wiki.md): project knowledge lives in wiki/, maintained by agents and enforced by hooks and lint.
- [0007 Apache 2.0 license](decisions/0007-apache-2-license.md): permissive license with an explicit patent grant; trademarks are not covered.
- [0008 Commit the OpenAPI spec](decisions/0008-commit-the-spec.md): the spec is committed rather than fetched, because it can't be pinned and generated code embeds it anyway.
- [0009 Versioning and releases](decisions/0009-versioning-and-releases.md): SemVer starting at 0.x, plain version tags, Keep a Changelog, scripted releases and automated spec-update PRs.

## Sources

- [OpenRouter API reference](sources/openrouter-api-docs.md): the official API docs, the normative source for behaviour; what they specify and where this package implements it.
- [OpenRouter OpenAPI spec](sources/openrouter-openapi-spec.md): the upstream API description we generate from, its shape and its known quirks.
- [swift-openapi-generator](sources/swift-openapi-generator.md): Apple's OpenAPI code generator and runtime, the version pinned here, and its limits as relevant to this spec.
- [Don't waste your back pressure](sources/dont-waste-your-backpressure.md): Moss's essay on automated feedback as the lever for agent autonomy.
- [LLM wiki pattern](sources/llm-wiki-pattern.md): Karpathy's idea file for agent-maintained knowledge bases.
