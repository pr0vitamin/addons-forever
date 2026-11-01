# The agent runs outside the game, not inside it

WoW addons are sandboxed Lua with no network or file access; the only way out is SavedVariables, which the client writes only on reload, logout or disconnect. An in-game prompt window bridged by a desktop companion app would therefore cost two reloads and tens of seconds per change, so we decided the agent (Claude Code or similar) runs in a terminal or app on the same PC as the game, and playing the game is kept separate from building Modules.

## Considered Options

- **In-game prompt + companion app bridge** (the WeakAuras Companion pattern): rejected for its slow round trip and extra moving parts. It remains possible to build later on top of the Harness if ever wanted.
