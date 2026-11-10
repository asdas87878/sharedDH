# Handoff

What each push changed, so whoever pulls next knows where things stand. Newest first. Every hand-made push gets an entry
here; the Obsidian Git plugin's own "vault sync" commits don't need one.

## 2026-11-10 · 8570-F43F (the user's PC): fish to fish is now the reference's jump
**State:** built and run in Studio by Claude (pressing Space through the connector): floating onto a fish, riding, a
jump onto the next fish, the early drop, and a miss into the drown. StyLua and selene pass. **No person has judged the
feel yet.** The user decided this with void's owner: [Decisions](Decisions.md), 2026-11-10.

- **Gone:** the corkscrew dash, the hook window (slow motion, reticle, rope) and the eaten death.
  `DashController`, `GrappleController` and `Lib/Eater` are deleted; E, F and Q no longer do anything.
- **New:** `src/client/Controllers/JumpController.luau` and `Config.Jump`. Space throws you into a flight you steer, a
  dashed yellow ring lies in the water under you, the fish inside it glows, and you land on it. How it works and what
  differs from the reference: [riding feel](design/riding-feel.md).
- **Server** (`RideService`): states are now Dock, Free, Riding, Jumping, Drowning. Remote actions are "Jump", "Land"
  and "Miss".
- **Fish are twice as dense** (`Config.Spawn.PerThousand` 24), so a jump has a fish within its flight. To tune.
- **Second pass the same day, after the user played it:** the flight is launch, float and drop (3.65 s), with a fast
  pull onto the glowing fish and a short drown when a drop finds nothing; a miss from floating drowns too. Wild fish
  now swim as a herd: all straight down the lane, at 0.85 of ridden speed (measured from the reference), in one layer
  16 to 30 studs above the floor, and a ridden fish follows that layer when W and S are let go.
- **Third pass, after the user played the second:** a ridden fish turns to where the camera looks (A and D turn the
  camera), and so does the flight; a second press with nothing in the ring grabs the best fish within 45 studs, the one
  you left included; a fish near by is grabbed in the drop without a press. Fixed: A and D did nothing on a fish (the
  player module gave no move vector), so `RideController.moveVector` now reads the keys as well.
- **The movement sandbox** ([how to use it](sandbox.md)): in Studio the game now starts with no fail and endless air,
  with R, V and N for a reset, a side view and a panel of every movement number. `Config.Sandbox.On = false` starts
  Studio with the real rules instead. A published game never has it.
- **The pull-in and the reach:** the pull onto the fish follows the reference's measured curve (`Jump.ReelCurve`, on a
  line from the hand); the grab reaches 85 studs whichever way you look, and 50 without a press in the drop.
- **The flight's shape and the landing's camera,** from a side-on recording: a 0.3 s pop then a flat glide; at the
  landing the view snaps 12 degrees wider and settles (`Jump.LandFov`), the camera is jolted (`Jump.LandKick`), and
  yellow dots trail the pull-in instead of the line.
- **Front targeting and height:** a jump makes for the nearest fish in front (`Jump.AheadCone`), never the one it left
  unless nothing else is in reach; it rises `Jump.Apex` above the fish in front; the herd swims lower (8 to 16 studs
  above the floor) to leave water to jump into.
- **Kept:** Oxygen, the throw-off and the drown, the speed-up on mount, the bubble burst, map v4.
- **The Studio place on this PC is not in the repo.** It was rebuilt in an unsaved place from `claude_blockout.luau`
  and `src/`; the user saves it locally.
- **Open:** the ring and landing effects for a floating fish, tuning the glow and outline, a revive after a miss, and a
  ridden fish left alone swimming out of the lane and up to the surface.

## 2026-11-10 · 8570-F43F (the user's PC): void's draft merged with the creature work of the 10th
**State:** merged and pushed by the Obsidian Git plugin. StyLua and selene pass and `rojo build` builds the place. **Still
no one has played it**: the playtest is the next thing.

- **What came in from this PC:** the Yellow Tang, Sea Turtle and Stingray built on one kit (`kit_common.py` under
  `fish_kit.py`, `shell_kit.py`, `disc_kit.py`), the voxel style test (`voxel_kit.py`, five creatures), the rarity look
  notes, and [Sessions](Sessions.md) (which Claude chat has which files in hand).
- **Three clashes, both sides kept:**
  - **Decisions:** both sets of rows are in. Note for the user: void's rows replace stamina with an **Oxygen** meter for
    riding and falling off with drowning or being eaten. They were written on void, so the user hasn't confirmed them here.
  - **The fish kit:** `fish_kit.py` had moved onto `kit_common.py` here while void added `--export` and new spec pieces
    (belly, coloured bars, fin tips, spikes, `viewScale`) to the old single file. The two don't merge line by line, so
    void's file is kept whole as `tools/blender/fish_kit_export.py`, and `art/creatures/build.py` now runs that one.
    `fish_kit.py` is this PC's version and has **no `--export` yet**.
  - **The Yellow Tang:** the folder holds the hand-built one (spec, renders, sheet). Void's placeholder spec, renders and
    sheet moved to `art/creatures/YellowTang/placeholder/`; its `YellowTang.obj` game mesh is unchanged.
- **Open:**
  - Move `--export` and void's spec pieces into the kit proper (`kit_common.py`), so the shell, disc and voxel creatures
    can export game meshes too, then delete `fish_kit_export.py`.
  - The playtest of the riding, the hook and map v4.

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
