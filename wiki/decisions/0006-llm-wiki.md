---
title: LLM-maintained wiki
summary: Project knowledge lives in wiki/, maintained by agents and enforced by hooks and lint.
updated: 2026-10-17
---

# 0006 LLM-maintained wiki

## Context

Why a spec patch exists, which upstream quirk broke decoding, which errors
are deliberately not retried: this knowledge gets lost in PR threads and
chat sessions. [Karpathy's LLM-wiki pattern](../sources/llm-wiki-pattern.md)
compiles it once into interlinked markdown and keeps it current.

## Decision

Keep a wiki in `wiki/` following [SCHEMA.md](../SCHEMA.md), maintained by
agents as part of every change, with layered enforcement
([Agent workflow](../concepts/agent-workflow.md)).

## Consequences

- PRs that change behaviour also update the relevant wiki pages and the log.
  Reviewers check this.
- The index is the retrieval mechanism. If it outgrows a single file, add
  search and record that here.
