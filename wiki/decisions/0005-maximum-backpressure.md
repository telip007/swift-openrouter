---
title: Maximum backpressure
summary: Warnings are errors, strict lint, 90% coverage gate, hooks and CI so contributors and agents get fast, automated feedback.
updated: 2026-10-17
---

# 0005 Maximum backpressure

## Context

Feedback a tool can give is feedback a reviewer doesn't have to
([Don't waste your back pressure](../sources/dont-waste-your-backpressure.md)).
That matters doubly for an open-source project that receives contributions
from humans and agents.

## Decision

Turn every deterministic check to its strictest useful setting
([Backpressure setup](../concepts/backpressure-setup.md)). Checks are never
weakened to get a green build. Changing a rule needs maintainer agreement and
a decision record.

## Consequences

- Contributors get precise local feedback (`make check`) that matches CI.
- Nondeterministic checks (type-checking time limits) are excluded.
- swift-format owns layout, SwiftLint owns semantics. Conflicts are resolved
  in favour of swift-format.
