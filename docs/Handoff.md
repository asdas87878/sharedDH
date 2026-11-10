# Handoff

What each push changed, so whoever pulls next knows where things stand. Newest first. Every hand-made push gets an entry
here; the Obsidian Git plugin's own "vault sync" commits don't need one.

## 2026-11-10 · void (Hugo's PC): first playable draft and round 2, not playtested yet
**State:** the code builds and passes StyLua and selene, but **no one has played it in Studio yet**: Studio's MCP server
was off on void the whole time, so the playtests were ended without a run. Expect bugs and numbers that need tuning.

- **Riding** ([Riding feel](design/riding-feel.md), numbers in `src/shared/Config.luau`):
  - **Oxygen** drains while you ride, and the fish speeds up from idle.
  - **Out of Oxygen**, the fish throws you off and you drown (bubbles slow down and stop).
  - **The corkscrew dash** takes you fish to fish and refills Oxygen.
  - **Jumping off** opens a 2.5 s hook window (slow-mo, a reticle on the best fish, a rope, a smooth pull into the mount).
    Miss it and a big fish eats you.
  - **A bubble burst** on every landing.
  - **Fish** spread over the whole lane.
  - New files: `src/client/Controllers/DeathController.luau`, `src/client/Lib/Eater.luau`, `src/shared/Lane.luau`.
- **Map v4** ([Blockout](blockout.md), `tools/studio/claude_blockout.luau`):
  - A half-circle island with the flat side to the dive, so it's a short walk from spawn to the board.
  - Shops on the sides of a wider dock, and big plots/tanks.
  - A diagonal dive lane with a signature formation per zone.
  - Matching prop clusters along the sides, and a Subnautica-inspired look per zone.
  - About 6,900 parts. Props are part stand-ins tagged `PropName`, swapped for the Blender meshes once the meshes are
    uploaded (uploads need the user's OK).
- **Art:**
  - Placeholder fish built with the fish kit (Yellow Tang, Clownfish, Pufferfish, Reef Shark) as OBJ in `art/creatures/`.
  - A prop kit (`tools/blender/prop_kit.py`): rocks, corals, kelp, glow plants and clusters as FBX in `art/props/`, with
    `props.json` and contact sheets.
  - `fish_kit.py` gained `--export <mesh.obj>`.
- **Merged with the partner's work** (head and mouth, `--wire`, Yellow Tang, Sea Turtle, Stingray notes, workout 3): both
  sides kept. The one code conflict was `fish_kit.py`'s options (`--export` and `--wire`), and both are in.
- **To try it:** `rojo build -o ride-a-fish.rbxl` (or `rojo serve`; on void Rojo runs on port 34873), then run
  `tools/studio/claude_blockout.luau` in Studio to build the map. On void, the built place is
  `~/Documents/RideAFish/ride-a-fish-map.rbxl`.
- **Open:**
  - The playtest itself.
  - Importing the fish and prop meshes into Studio (an upload, so it needs the user's OK).
