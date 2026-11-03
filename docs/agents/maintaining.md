# Maintaining the Harness

Instructions for agents working on the Addons Forever Harness itself (the Host, sync tooling, agent docs). Players building their own addons never load this file.

Read `docs/design.md`, `GLOSSARY.md` and `docs/adr/` before changing the Harness. The player-facing rules in `AGENTS.md` also apply: keep the Harness consistent with them.

## Agent skills

### Issue tracker

Issues and specs live in GitHub Issues for `pr0vitamin/addons-forever`. See `docs/agents/issue-tracker.md`.

### Triage labels

The five default labels: `needs-triage`, `needs-info`, `ready-for-agent`, `ready-for-human`, `wontfix`. See `docs/agents/triage-labels.md`.

### Domain docs

Single-context: `GLOSSARY.md` and `docs/adr/` at the repo root. See `docs/agents/domain.md`.

## Tests

Run `tests/run.sh` (optionally with a name filter). Tests must pass under macOS's built-in bash 3.2 (`/bin/bash tests/run.sh`) as well as newer bash, because players run sync in Git Bash on Windows or the system bash on macOS. Some tests skip when no Lua interpreter is installed.
