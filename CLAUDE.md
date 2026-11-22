# Ride a Fish (working title)

A quick Roblox game in the "Ride a Dino" genre, going **down** instead of across: ride prehistoric sea creatures deeper and
deeper, tame them, show them off in your tank, earn, train your breath, dive further. It's meant to ship fast (a first version
in about two weeks) while the genre is hot, so keep scope small. The user postponed the Borderlands FPS and the Gatebound RPG
for it. Plan for co-op servers from the start: server-authoritative, per-player state.

- **This folder is the user's Obsidian vault.** Start at [Home](Home.md). Read [Working together](docs/Working%20together.md)
  first in every session. Design is in `docs/design/` (one note per system: decided, ideas not agreed, open), settled things in
  [Decisions](docs/Decisions.md), raw ideas in [Inbox](docs/Inbox.md) ("sort the inbox" = file them and clear it). Use plain
  markdown links (relative paths), not [[wikilinks]].
- **Two people, one repo:** the user and their partner share one Claude account from two PCs, through the private repo
  `asdas87878/sharedDH` (how: [Working together](docs/Working%20together.md), Sharing the project). Claude's memory is per
  PC, so anything both need goes in the vault. With Obsidian open, its Git plugin commits and pushes 5 minutes after edits
  stop (Claude's edits too) and pulls on open and every 5 minutes. Never commit secrets.
- **The reference:** Ride a Dino, broken down in [docs/reference/ride-a-dino.md](docs/reference/ride-a-dino.md) from the user's
  recording (frames in the gitignored `research/ride-a-dino/`). Copy the loop and the feel, never its look, models or layout.
- **The studies (2026-11-16):** before design or look work read [docs/Findings.md](docs/Findings.md): one ranked page over four
  studies (the reference in depth, lighting, buildings, creators and trending games; evidence in `docs/reference/`), with what
  we had wrong. Its changes to the plan are proposals in [docs/Refinement.md](docs/Refinement.md) until the user says yes.
  Reddit and YouTube are read through `tools/sources/` ([how](docs/reference/research-tools.md)), one request at a time.
- Toolchain as in the RPG (`C:\Users\blast\RpgGame`): `rokit.toml`, `rojo serve`, `stylua src`, `selene src`.
- `src/server` -> ServerScriptService.Server (`Main` loads `Services/`), `src/client` -> StarterPlayerScripts.Client
  (`Main` loads `Controllers/`), `src/shared` -> ReplicatedStorage.Shared. Modules have optional `Init` (no yield) / `Start`.
  Luau with `--!strict`, tabs. Never trust the client with taming, money or stamina.
- **Area rules live in skills now (2026-11-22, [AI setup](docs/AI%20setup.md)).** Load the one for your work before
  starting it; each holds, word for word, what used to be here:
  - `game-code`: anything in `src/` (riding, the herd, the hop, the aquarium, props, Config, the sandbox).
  - `creature-look`: any creature in `art/creatures` (the voxel kit, the user's building rules, rarity looks, export).
  - `map-build`: the map, the hub, props, water, blockouts (`tools/map/`, the Studio loader).
  - `studio-test`: before driving Studio (sync, play, scripted checks, captures, the traps).
  - `handoff`: ending a chat or passing work on (`/handoff`).
- **Model and tokens:** Fable 5.2 at `high` effort is the project default (`.claude/settings.json`). Never read
  [Sessions](docs/Sessions.md), [Handoff](docs/Handoff.md) or [Decisions](docs/Decisions.md) whole: they are newest first, so
  read the top (Sessions: its first 80 lines) and search the rest, or ask the `scout` helper. Helpers in `.claude/agents/`:
  `scout` (finds things, returns quotes), `studio-tester` (runs a Studio check, returns numbers), `fresh-eyes` (reviews a
  finished piece), `creature-builder` (builds one creature by the brief). Hand off to a fresh chat at the end of a piece of
  work rather than letting one chat run for days.
- The look: numbered style workouts in `docs/style/` ([index](docs/style/Style%20workouts.md)), each with options for the user
  to pick. Inspiration is Ride a Dino's broad style (chunky, bright, cheap), never its models or layout. Underwater lighting
  uses classic fog with the Atmosphere taken out (`tools/studio/depth_look_test.luau`, findings in workout 1).
