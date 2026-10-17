@AGENTS.md

## Claude Code specifics

- Skills in `.claude/skills/`: `wiki` (query/update/ingest/lint the wiki),
  `backpressure` (the `make check` loop), `regenerate-api` (spec → Swift).
- Hooks in `.claude/settings.json`: the session start loads the wiki index and
  enables the repository's git hooks, every Swift edit is linted (violations
  come back to you), and a Stop hook asks for a wiki update when code changed
  without one.
