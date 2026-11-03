# Coding standards

Judgement calls for reviewers to apply to every diff. Mechanical rules (bash compatibility, Lua 5.1 syntax, shell lint) belong in automated checks, not here (see #17).

## Player-machine input

Anything the Harness reads from a player's computer (local config, `module.toc` manifests, Module source files, paths, the Debug Log) may come from a **Windows player's machine**, edited by a non-technical player in whatever editor they have. Code that reads it handles:

- UTF-8 byte-order marks and CRLF line endings
- files saved as UTF-16 or containing other non-text bytes, reported with how to fix them
- case-insensitive filesystems: `Foo.lua` and `foo.lua` are one file, and Module ids compare ignoring case
- spaces, quotes, backslashes and drive letters in paths
- Git Bash on Windows and bash 3.2 on macOS as the shells that run it

Messages about bad input name the addon and the file, say what's wrong, and say how to fix it, in words a non-technical player can act on.

## Vocabulary

Text a player sees says "addon". Code, docs and identifiers use the terms in `GLOSSARY.md` (Module, Host, Bundle, Debug Log).
