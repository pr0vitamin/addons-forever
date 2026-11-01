# Modules run inside one Host addon, not as standalone addons

The WoW client only discovers addon folders and TOC-listed files at startup, so every new standalone addon would need a full client restart. To keep the build loop to a `/reload`, every Module runs inside a single Host addon ("Addons Forever"): a sync script merges all Module sources into one Bundle file the Host's TOC already lists, and Modules keep their data in their own section of the Host's SavedVariables.

## Consequences

- Each sync needs a Bundle step, which the agent runs.
- A Module only works for someone who has the Host, so in v1 Modules are shared only between Harness users. The Module interface should stay clean enough that an "eject to standalone addon" command can be added later.
- Modules can't declare their own SavedVariables; they share the Host's, under their own section.
