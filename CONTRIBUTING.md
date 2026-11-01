# Contributing to the Harness

`AGENTS.md` is for players building addons. Maintainer instructions live in `docs/agents/maintaining.md` and are opt-in, so players' agents never load them.

To work on the Harness itself:

- **Claude Code:** create a gitignored `CLAUDE.local.md` at the repo root containing `@docs/agents/maintaining.md`. The committed `CLAUDE.md` already imports `AGENTS.md`.
- **Other agents:** point your agent at `docs/agents/maintaining.md` alongside `AGENTS.md`.
