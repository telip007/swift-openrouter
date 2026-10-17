---
name: regenerate-api
description: Regenerate the OpenRouterAPI target from OpenRouter's OpenAPI spec, widen or narrow the generated operations, or fix problems in generated code. Use when the upstream API changed, when an endpoint is missing from `api`, or when generated code fails to compile or decode a real response.
---

# Regenerating the API layer

Pipeline and rationale: `wiki/concepts/openapi-pipeline.md`. Read it first.

## Steps

1. `make generate-fetch` downloads `https://openrouter.ai/openapi.json` into
   `openapi/openapi.json`, then patches and generates. Use `make generate` to
   regenerate from the committed spec, e.g. after changing the tag filter in
   `openapi/generator-config.yaml`.
2. `git diff --stat openapi Sources/OpenRouterAPI` to see the size of the change.
3. `make check`. Then fix the hand-written layer (`Sources/OpenRouter`)
   against renamed or reshaped generated types.
4. Record the spec change in the wiki log. If new spec quirks needed patching,
   document them in the pipeline page's patch table.

## Rules

- **Never edit `Sources/OpenRouterAPI/Generated/` by hand.** Fix the input:
  either add a normalisation to `Scripts/patch_openapi.py` (with a comment
  explaining the upstream quirk) or change `generator-config.yaml`.
- A patch must preserve the API's meaning. Typical valid patches: make
  nullable fields optional, open up enums the server extends, drop vendor
  extensions. Never make a field the server can omit non-optional.
- When a real response fails to decode, add the payload (redacted) as a test
  fixture before fixing the patch, so the regression stays covered.
