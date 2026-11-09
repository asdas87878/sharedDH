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
  PC, so anything both need goes in the vault. Never commit secrets.
- **The reference:** Ride a Dino, broken down in [docs/reference/ride-a-dino.md](docs/reference/ride-a-dino.md) from the user's
  recording (frames in the gitignored `research/ride-a-dino/`). Copy the loop and the feel, never its look, models or layout.
- Toolchain as in the RPG (`C:\Users\blast\RpgGame`): `rokit.toml`, `rojo serve`, `stylua src`, `selene src`.
- `src/server` -> ServerScriptService.Server (`Main` loads `Services/`), `src/client` -> StarterPlayerScripts.Client
  (`Main` loads `Controllers/`), `src/shared` -> ReplicatedStorage.Shared. Modules have optional `Init` (no yield) / `Start`.
  Luau with `--!strict`, tabs. Never trust the client with taming, money or stamina.
- Blockouts: `tools/studio/claude_blockout.luau` (v2: the long gradual dive, 10 zones; returns the zones as JSON for
  `tools/art/depth_profile.py`), notes in [docs/blockout.md](docs/blockout.md). Long Luau files go through
  `node tools/studio/run_luau.js <studio_id> <file> [NAME=value ...]` (the direct client; replaces `local NAME = ...` lines).
- The look: numbered style workouts in `docs/style/` ([index](docs/style/Style%20workouts.md)), each with options for the user
  to pick. Inspiration is Ride a Dino's broad style (chunky, bright, cheap), never its models or layout. Underwater lighting
  uses classic fog with the Atmosphere taken out (`tools/studio/depth_look_test.luau`, findings in workout 1).
- Creatures: `tools/blender/fish_kit.py <spec.json> <out>` (Blender 5.2 headless, `C:\Program Files\Blender Foundation\Blender 5.2\blender.exe
  --background --python ...`) builds a faceted fish from `art/creatures/<Name>/spec.json` as rigid spine segments + plate fins +
  square eyes, renders turnaround views and a riding view; `tools/art/creature_sheet.py` lays them out like the user's ChatGPT
  concept sheets (`art/concepts/creatures/`) and makes the side-by-side. The head is its own flat planes (spec `head`: a face
  narrowing to the mouth, one big eye face either side, chin and jaw), built from the user's drawings over our renders
  (`art/concepts/creatures/notes/`; `tools/art/lines_overlay.py` maps drawn lines back onto renders). Workout 2 in
  `docs/style/02-creature-look.md`.
