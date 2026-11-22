---
name: map-build
description: "Ride a Fish's map: the grey-box generator (tools/map/greybox.py), the Studio loader, walls, floors, squares and studs, props, the hub, the water, the far view, and the user's rules for all of them. Load it before any map, hub, prop, water or blockout work, and before reviewing or answering questions about how the map is built."
---

# The map (rules and tools)

Moved here word for word from CLAUDE.md on 2026-11-22 (the token-saving setup, docs/AI setup.md), so only chats
doing this kind of work carry it. Keep it up to date HERE from now on, the way CLAUDE.md was kept.

- Blockouts: `tools/studio/claude_blockout.luau` (v2: the long gradual dive, 10 zones; returns the zones as JSON for
  `tools/art/depth_profile.py`), notes in [docs/blockout.md](docs/blockout.md). Long Luau files go through
  `node tools/studio/run_luau.js <studio_id> <file> [NAME=value ...]` (the direct client; replaces `local NAME = ...` lines).
  **The map starts again (the user, 2026-11-10): v4 is set aside.** Build it the way Ride a Dino builds its own, then
  improve: a lane that goes narrow, wide, narrow, wide, its two sides waving AGAINST each other (one goes in as the
  other goes out: the user's corrections), a line of flags at each neck, small floor squares (10 studs), rolling ground that steps up at a room's sides into broad terraces or a tall plain wall
  or rolls off at an open edge, one colour per land, a closed-in hub with one gate into the water, big assets per land that fish must steer round (corals, kelp, a wreck, bones: `tools/map/props.py`, sheet
  `docs/attachments/map-props-kit.jpg`), each of loose boxes so it can collapse when a big creature hits it,
  and a descent that steepens land by land with a step at each border and a big drop every few. Study:
  [docs/reference/ride-a-dino-map.md](docs/reference/ride-a-dino-map.md); method (proposed) and the user's decisions:
  [docs/design/map-method.md](docs/design/map-method.md).
  **The hub since W32 (2026-11-22, [docs/design/hub-layout.md](docs/design/hub-layout.md)):** `FRONT` -32 (the cut and
  the strip 32 deep), `HUB_BACK` -312, `PLOT_GAP` 15 behind the back tanks, `SIDE_GAP` 7 beside the side ones, and
  `HUB_SHIFT` 16 added to every hand-placed number (side tanks, SELL, AURAS, FUSE, DockSpawn at z -99.2, the back
  palms); the arch stays at the water's edge. The wall's pieces are marched from the middle of the hub's back, so any
  change to the hub's ring re-cuts every lane wall piece and re-scatters about 40% of the props (same rules, same
  lane): diff a scratch build (`GREYBOX_OUT`) against `art/map/greybox/parts.json` before a reload. A full reload loses
  the KitPivot tracker (00_start destroys ClaudeBlockout), so read the hub from the place first and carry any hand
  change into `hub_kit.py`/`greybox.py`.
  **Square studs since 2026-11-22:** the one surface picture is `tile3` (`tools/art/map_tile3.py`: `tile2` with each ring
  swapped for Roblox's own square stud, read from the engine's `studs.dds`), laid by the same per-piece numbers; the
  loaders read `tile3` from `art/map/textures.json`; a picture swap on a loaded place is `tools/studio/swap_stud_picture.luau`
  (OLD/NEW), no reload. Not the engine's Studs surface: it counts from each part's corner, so it can't follow curves or joints.
  Grey-box 15 (2026-11-13: lighter deep floors, cliffs fading into each land's water, glowing ledges from the Twilight down (`Glow`), `StreamingTargetRadius` 2400 set by `00_start`; the water a veil in eight lands, a lit ceiling and shafts all the way down: `docs/design/water.md` "Seeing far"). Grey-box 14 (2026-11-12, `docs/design/map-feel.md`: the lane is a canyon: behind every wall a shelf, then two coarse cliff layers (`CLIFFS`), round the hub too; big assets thinned to 243 and kept to the outer third of the lane; zone looks sheet by `tools/map/zone_looks.py`); the wall built on ribs: every tier shares the face's corners, each piece carries one tile slid a quarter so a square straddles every joint, no nose sharper than 100; Texture mapping rules in `greybox.py` above `cell`; a quick bench with `BENCH=1`; the hub after the reference, its tall walls mirrored and stepping evenly, the entrance rounded, the lane's first room the same on both sides: 480 by 320, a U of eight aquariums, a narrow gate (144) between two level posts with the start strip in it saying DIVE IN and flags over it, the lane widening just inside the gate; the filling behind hollow wall curves now reads as grass (the "cracks"), pieces end on sharp corners; the hub in the reference's own colours (`HUB_LOOKS`), the surface picture redrawn (`tile2`, `tools/art/map_tile2.py`); load with `python tools/studio/load_greybox.py <studio_id>`, which waits out Play mode). Before it, grey-box 9 (2026-11-11: ALL TEN LANDS, about 63,000 boxes, 105 loader files; squares of 8 studs (5 read too small to the user), the hub 480 by 256 with one joined row of aquariums, the hub's wall and each side's lane wall one unbroken run through a rounded mouth; a straight first land, bends after, wider as you go, one smooth floor with no steps or drops, a wall or rim on every edge with an unseen barrier behind it; offline, Python, no Lune needed; the hub sized from the reference's, plots `Dock.Plots.PlotN`, the floor as 64, 32 and 16-stud tiles on one world grid so Roblox pictures line up; pictures by `tools/art/map_roblox_textures.py`, their asset ids in `art/map/textures.json`). Open (the user, 2026-11-10): squares on ALL ground and Roblox's own darker studs; `tools/studio/texture_test.luau` is the Studio test that decides how (see map-method.md, "Squares everywhere"). The map is modelled by `greybox.py` as a list of boxes: Blender only draws it, the loader builds it in Studio. **Structure passes (2026-11-11, [docs/design/map-structure.md](docs/design/map-structure.md)):** the reference's walls are short straight pieces a whole number of squares long, so squares follow the curve; a square is a player tall (5 studs) with about 8 round studs across; the grass is a slab a square thick; heights change by whole squares. Tested on a bench in Studio, `tools/studio/map_bench.luau` (`Workspace.MapBench`), judged beside the user's screenshot; Roblox's own studs are square, one to a stud, so they don't give that look. In `greybox.py` since grey-box 6 (`build_wall`: each tier marched along its own face in 10-stud pieces; one picture, `tile` in `art/map/textures.json`, on everything): `python tools/map/greybox.py` writes every box to
  `art/map/greybox/parts.json` and the game's path to `path.json`; `tools/blender/map_greybox_view.py` renders views,
  The moving water (`docs/design/water.md`): `tools/map/water_look.luau` (a client script: ONE 2,048-stud block of four mesh layers that follows the camera, white glass on top for foam, one picture layer drifting, the layers breathing, plain water round it; numbers in its `LOOK` table), installed by `tools/studio/greybox/98_water.luau` from `python tools/map/water_luau.py`; under the surface it gives each land its own bright water colour (`tools/map/water_zones.py`: fog, tint, light shafts, specks, the surface seen from below; it sets Lighting's fog and takes the Atmosphere out while under); shows in Play only; a script inside the game can't make meshes or pictures (security setting), so it uses a store cube mesh and the tutorial pack's picture.
  `python tools/map/greybox_luau.py` writes the Studio loader (`tools/studio/greybox/*.luau`, run in order with `run_luau.js`; it replaces `Workspace.ClaudeBlockout`). The recordings are in `D:\program files for me\videos\`.
  v4's state and the stud tiles (set aside with v4):
  [docs/map-state.md](docs/map-state.md); tiles `tools/art/map_tiles.py` (borrows `creature_tiles.py`'s greys; `--test`
  lays out the test picture), test scene `tools/blender/map_stud_test.py`. No Lune on the user's PC yet: `map_plot.py
  <zones.json> <out> --top-from <old.png>` redraws the side view without a build.
