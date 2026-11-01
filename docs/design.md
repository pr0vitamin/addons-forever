# Addons Forever: v1 design

Agreed 2026-11-01. Terms are defined in [GLOSSARY.md](../GLOSSARY.md); key decisions in [docs/adr](./adr).

## Goal

A public, MIT-licensed GitHub repo (`addons-forever`) that lets a player — technical or not — bring their own AI agent and quickly build personal addons for World of Warcraft: Forever (launches 2026-11-04; Mainline-based client with Midnight-era restrictions, reportedly Interface 16001, `_Camelot` TOC suffix — verify in-game).

## Shape

- **Agent runs outside the game**, on the same PC as WoW (ADR-0001). Windows first, macOS second.
- **One Host addon, "Addons Forever"** (folder `AddonsForever`), loads every Module (ADR-0002).
- **Players say "addon"**; docs and code say Module. Agent treats "addon" as a Module by default and asks when the name matches a Standalone Addon or no Module exists.

## Repo layout (intended)

- `host/` — the Host addon source.
- `modules/` — the player's Modules, gitignored; Harness updates are a plain `git pull`.
- `examples/` — example Modules shipped with the Harness.
- `docs/forever-api.md` — hand-maintained notes on what's restricted or different in Forever.
- `AGENTS.md` — agent-neutral, player-facing instructions (`CLAUDE.md` imports it); maintainer instructions are opt-in via `docs/agents/maintaining.md` (see `CONTRIBUTING.md`); `.claude/` — Claude Code skills/commands (`/setup`, `/new-addon`, `/sync`, `/check-log`).
- Sync script (bash; runs in Git Bash on Windows) and a per-machine local config holding the WoW AddOns path.

## Module

- A folder `modules/<Name>/` with a manifest (name, description, enabled-by-default, Host interface version) plus Lua files.
- Code starts `local M = AddonsForever:NewModule("<Name>")` and uses only the Blizzard API plus Host helpers — no Ace3/LibStub.
- Host interface: event registration (`M:On(event, fn)`), slash command (`/af <name> ...`), storage (`M.db.account`, `M.db.char`), logging (`M:Log(...)`).

## Host

- Loads the Bundle; each Module is isolated so a failing one is disabled and logged while the rest load.
- Declares one account-wide and one per-character SavedVariables table, sectioned per Module.
- Keeps the Debug Log (Lua errors + Module log output) in SavedVariables for the agent to read after `/reload`.
- `/af` lists addons with on/off toggles, a hint that they run inside Addons Forever, and warnings for Host interface version mismatches.

## Build loop

1. Player asks the agent for an addon.
2. Agent writes/edits the Module, runs sync (builds the Bundle, copies the Host into the AddOns folder).
3. Player types `/reload` (a full restart is only needed on first install).
4. Agent reads the Debug Log and iterates.

## Agent knowledge

- Ketho's WoW API annotations for the Lua language server.
- `docs/forever-api.md`, checked first and grown as we hit problems.
- Unsure APIs are confirmed in-game via `/dump` output captured to the Debug Log.

## Onboarding

README: install an agent → clone the repo → open the agent in it and say "set me up". The agent finds the WoW folder, writes local config, runs the first sync and asks the player to restart WoW once.

## Testing

No automated tests in v1. Rely on language-server checks, an optional Lua syntax check in sync, and the Debug Log. Build the Host skeleton before launch; validate against the real client on 2026-11-04.

## To verify on launch day

- Forever interface number and TOC naming.
- The Forever install folder name and AddOns path on Windows and macOS.
- That `/reload` picks up a changed Bundle without a restart.
