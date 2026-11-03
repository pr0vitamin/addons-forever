# Module code is embedded in the Bundle as strings and compiled in-game

The Bundle stores each Module file's source as a Lua long string, and the Host compiles each file separately with `loadstring`, naming the chunk after its source path (for example `modules/Hello/Hello.lua`). We chose this over pasting Module code straight into the Bundle because, with plain pasting, one syntax error anywhere would stop the whole Bundle from loading, taking every addon down with it. Errors would also point at Bundle line numbers instead of the player's own files. Most players won't have a Lua syntax checker installed, so sync can't be relied on to catch those errors first.

## Consequences

- One Module's syntax or load error disables only that Module, and every error names the real file and line.
- Sync must pick a long-bracket level (`[[`, `[=[`, …) that doesn't appear in the file being embedded.
- This relies on `loadstring` being available to addons in Forever, which is to be confirmed on launch day (#2).
