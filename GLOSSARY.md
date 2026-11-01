# Addons Forever

A Harness that lets a player, with an AI agent running outside the game, quickly build personal World of Warcraft: Forever addons.

## Language

**Harness**:
The whole toolkit a player clones: the Host, agent instructions, API reference and tooling for building Modules.
_Avoid_: Framework, plugin, SDK

**Host**:
The single real addon installed in the game, named "Addons Forever", which loads every Module and keeps the Debug Log.
_Avoid_: Core addon, loader

**Module**:
One personal addon built with the Harness, which runs inside the Host rather than as a standalone addon. Players call it an "addon"; "Module" is the precise term in docs and code.
_Avoid_: Plugin, personal addon, sub-addon

**Standalone Addon**:
A normal WoW addon with its own folder and TOC, such as the Host itself or third-party addons like Questie.
_Avoid_: Real addon, external addon

**Debug Log**:
The errors and log output the Host saves to disk so the agent can read what happened in-game after a reload.
_Avoid_: Error log, console

**Bundle**:
The single file, made from every Module's source, that the Host loads.
_Avoid_: Build, package
