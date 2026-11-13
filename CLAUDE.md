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
- Toolchain as in the RPG (`C:\Users\blast\RpgGame`): `rokit.toml`, `rojo serve`, `stylua src`, `selene src`.
- `src/server` -> ServerScriptService.Server (`Main` loads `Services/`), `src/client` -> StarterPlayerScripts.Client
  (`Main` loads `Controllers/`), `src/shared` -> ReplicatedStorage.Shared. Modules have optional `Init` (no yield) / `Start`.
  Luau with `--!strict`, tabs. Never trust the client with taming, money or stamina.
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
  Grey-box 15 (2026-11-13: lighter deep floors, cliffs fading into each land's water, glowing ledges from the Twilight down (`Glow`), `StreamingTargetRadius` 2400 set by `00_start`; the water a veil in eight lands, a lit ceiling and shafts all the way down: `docs/design/water.md` "Seeing far"). Grey-box 14 (2026-11-12, `docs/design/map-feel.md`: the lane is a canyon: behind every wall a shelf, then two coarse cliff layers (`CLIFFS`), round the hub too; big assets thinned to 243 and kept to the outer third of the lane; zone looks sheet by `tools/map/zone_looks.py`); the wall built on ribs: every tier shares the face's corners, each piece carries one tile slid a quarter so a square straddles every joint, no nose sharper than 100; Texture mapping rules in `greybox.py` above `cell`; a quick bench with `BENCH=1`; the hub after the reference, its tall walls mirrored and stepping evenly, the entrance rounded, the lane's first room the same on both sides: 480 by 320, a U of eight aquariums, a narrow gate (144) between two level posts with the start strip in it saying DIVE IN and flags over it, the lane widening just inside the gate; the filling behind hollow wall curves now reads as grass (the "cracks"), pieces end on sharp corners; the hub in the reference's own colours (`HUB_LOOKS`), the surface picture redrawn (`tile2`, `tools/art/map_tile2.py`); load with `python tools/studio/load_greybox.py <studio_id>`, which waits out Play mode). Before it, grey-box 9 (2026-11-11: ALL TEN LANDS, about 63,000 boxes, 105 loader files; squares of 8 studs (5 read too small to the user), the hub 480 by 256 with one joined row of aquariums, the hub's wall and each side's lane wall one unbroken run through a rounded mouth; a straight first land, bends after, wider as you go, one smooth floor with no steps or drops, a wall or rim on every edge with an unseen barrier behind it; offline, Python, no Lune needed; the hub sized from the reference's, plots `Dock.Plots.PlotN`, the floor as 64, 32 and 16-stud tiles on one world grid so Roblox pictures line up; pictures by `tools/art/map_roblox_textures.py`, their asset ids in `art/map/textures.json`). Open (the user, 2026-11-10): squares on ALL ground and Roblox's own darker studs; `tools/studio/texture_test.luau` is the Studio test that decides how (see map-method.md, "Squares everywhere"). The map is modelled by `greybox.py` as a list of boxes: Blender only draws it, the loader builds it in Studio. **Structure passes (2026-11-11, [docs/design/map-structure.md](docs/design/map-structure.md)):** the reference's walls are short straight pieces a whole number of squares long, so squares follow the curve; a square is a player tall (5 studs) with about 8 round studs across; the grass is a slab a square thick; heights change by whole squares. Tested on a bench in Studio, `tools/studio/map_bench.luau` (`Workspace.MapBench`), judged beside the user's screenshot; Roblox's own studs are square, one to a stud, so they don't give that look. In `greybox.py` since grey-box 6 (`build_wall`: each tier marched along its own face in 10-stud pieces; one picture, `tile` in `art/map/textures.json`, on everything): `python tools/map/greybox.py` writes every box to
  `art/map/greybox/parts.json` and the game's path to `path.json`; `tools/blender/map_greybox_view.py` renders views,
  The moving water (`docs/design/water.md`): `tools/map/water_look.luau` (a client script: ONE 2,048-stud block of four mesh layers that follows the camera, white glass on top for foam, one picture layer drifting, the layers breathing, plain water round it; numbers in its `LOOK` table), installed by `tools/studio/greybox/98_water.luau` from `python tools/map/water_luau.py`; under the surface it gives each land its own bright water colour (`tools/map/water_zones.py`: fog, tint, light shafts, specks, the surface seen from below; it sets Lighting's fog and takes the Atmosphere out while under); shows in Play only; a script inside the game can't make meshes or pictures (security setting), so it uses a store cube mesh and the tutorial pack's picture.
  `python tools/map/greybox_luau.py` writes the Studio loader (`tools/studio/greybox/*.luau`, run in order with `run_luau.js`; it replaces `Workspace.ClaudeBlockout`). The recordings are in `D:\program files for me\videos\`.
  v4's state and the stud tiles (set aside with v4):
  [docs/map-state.md](docs/map-state.md); tiles `tools/art/map_tiles.py` (borrows `creature_tiles.py`'s greys; `--test`
  lays out the test picture), test scene `tools/blender/map_stud_test.py`. No Lune on the user's PC yet: `map_plot.py
  <zones.json> <out> --top-from <old.png>` redraws the side view without a build.
- The look: numbered style workouts in `docs/style/` ([index](docs/style/Style%20workouts.md)), each with options for the user
  to pick. Inspiration is Ride a Dino's broad style (chunky, bright, cheap), never its models or layout. Underwater lighting
  uses classic fog with the Atmosphere taken out (`tools/studio/depth_look_test.luau`, findings in workout 1).
- Creatures: `tools/blender/fish_kit.py <spec.json> <out>` (Blender 5.2 headless, `C:\Program Files\Blender Foundation\Blender 5.2\blender.exe
  --background --python ...`) builds a faceted fish from `art/creatures/<Name>/spec.json` as rigid spine segments + plate fins +
  square eyes, renders turnaround views and a riding view; `tools/art/creature_sheet.py` lays them out like the user's ChatGPT
  concept sheets (`art/concepts/creatures/`) and makes the side-by-side. The head is its own flat planes (spec `head`: a face
  narrowing to the mouth, one big eye face either side, chin and jaw), built from the user's drawings over our renders
  (`art/concepts/creatures/notes/`; `tools/art/lines_overlay.py` maps drawn lines back onto renders); the mouth is pushed out
  of the face in the same mesh; `--wire` renders every edge in red. Workout 2 in
  `docs/style/02-creature-look.md`.
- More creatures: one note each in `docs/style/creatures/` (Yellow Tang, Sea Turtle, Stingray so far), from the user's
  concepts in `art/concepts/creatures/`, each ending in a Build section; [workout 3](docs/style/03-creature-set.md) holds the
  three body plans, the proposed rules for every creature and the user's open decisions. The kit: `tools/blender/kit_common.py`
  (materials, mesh helpers, the turnaround, `--wire`, riding and swim views; spec `frame` = camera distance) under three plan
  scripts with the same command line (`<spec.json> <out> [--swim] [--wire]`): `fish_kit.py` (fish), `shell_kit.py` (the Sea
  Turtle; `--check` = clearance), `disc_kit.py` (the Stingray). Specs and renders in `art/creatures/<Name>/`;
  `tools/art/creature_sheet.py` makes the side-by-side with the concept, `tools/art/swim_gif.py <renders> <gif> <variant>`.
- **Voxel style test (2026-11-10, not decided):** [workout 4](docs/style/04-voxel-style.md). Creatures designed block by
  block live in `art/creatures/<Name>/voxel.py` (Sergeant Major, Clownfish, Reef Shark, Dunkleosteus, Hellmaw) and build with
  `tools/blender/voxel_kit.py <voxel.py> <out> [--swim] [--wire]`; `--voxel <size>` on the three plan scripts converts a
  built creature to cubes (the weaker way). The mesher (`cells_to_bm`) is in `kit_common.py`. Voxels aren't law (the user):
  a model can add free pieces (`taper`, `block`, `spike`, `tooth`, `prism`) where a slope or a point looks better, teeth are
  pointed, glow is `GLOW` + `LIGHTS`, and every creature has a `SEAT` with a place for the rider's legs (`seat.png`).
  Third pass (the user: big block elements, not everything voxelly; slopes must blend): build from few big boxes, each a
  body part; a slope is a whole block turned (`beam`), never a block squeezed; fins and tails are two or three angled
  boxes. All five voxel creatures are built this way.
  Joining rules (the user: no gaps, no overlapping faces, colour bands only a little proud): bury a piece's root (one whole
  face inside another piece), each box of a chain starts inside the one before, fillings stay behind what they fill, no two
  faces in one plane, raised colour is `band` (a third of a cube proud). Every build prints `  !` lines for faults;
  `--check` stops there, `--inspect` renders close views from below and behind. The check is a gate: the build stops
  before rendering while any line is printed (`--force` overrides). It also refuses same-facing overlapping faces under
  0.05 studs apart, so each box of a fin is clearly thinner than the one before. Faces nothing can see are left out of the
  mesh. `--weld` (one closed shell per part) works but measured a third more triangles: not the default. A bar never sits
  where the body changes size (the user: bands are touches of colour, not shapes). All five pass the gate. Touches in use:
  a gum line on predators, a darker collar at a big fin's root, a lighter side line, bars that stop short of the belly
  (`band(stop=)`), one flaw on each rarer creature. Recesses that don't glow are shallow (`dent`, a third of a cube): a
  whole cube deep reads as a Minecraft build (the user). The shark's pink gum line read as lipstick: the user picked the thin
  darker line (`GUM = "thin"`), for select animals. Rarity look: docs/style/05-rarity-look.md (a budget per rarity, proposed; the Hellmaw is redone by it as a Mythic; parts
  that float on purpose are named in a model's `FLOATING`). Chosen: the halo eye for Legendaries (a dark pupil, a thin
  soft glow round it), a fully glowing eye only on a few Mythics. Body archetypes so far: plain fish, shark, armoured fish,
  shark-lizard (Mosasaurus), giant (Blue Whale, the old one), invented (Hellmaw), serpent (Basilosaurus), worm (Bobbit
  Worm), flat (Manta Ray), tentacled (Kraken), crawler (Anomalocaris), bulbous (Anglerfish), shelled (Archelon); sixteen
  models in `art/creatures/*/voxel.py`, all passing the gate. Next, when the user says: textures. Scale shows in form (the
  user): a model has one base size, and spawn sizes only scale it; a big base animal is built from more cubes, not bigger
  ones: more and gentler steps, more slices, higher counts at the same feature size, a collar or lip where parts join,
  one second layer of form in a rhythm; never so far that the simple look goes (workout 5, "Scale shows in form").
  Cohesive anatomy: depth, width and length agree with the animal's mass, and the parts with each other; check side, front
  and top outlines against the real animal. One language for every body: cubes for the mass, turned blocks for snouts,
  fins and limbs; no creature solves its shape in a way the others don't (a faceted shell was rejected). A curved surface
  in cubes (the Archelon's shell) is a few big blocks, each a wide plateau, a broad step and a wall: never runs of one-cube
  terraces, and not many thin slices either. Blocky first, detail second: when a model stops reading as blocks, simplify.
  Thin continuous stripes along the whole body (really thin, an accent colour is fine) are welcome: variety and texture.
  Leave the rider a seat: a row of spikes, knobs or plates along the back parts at the seat (a flat line may run under it).
- Textures (workout 6, `docs/style/06-textures.md`, first test, nothing picked yet): cartoon grey tiles drawn by code
  (`tools/art/creature_tiles.py` -> `art/style/tiles/`; mid grey leaves the colour), one to a cube. A model's `TEXTURES`
  rules say which tile on which faces ("top" is the usual, "top+sides", "all"), colours and parts; `VARIANT` "gold" or
  "rainbow"; `--look file.json` tries a look without editing the model. The user: a mix of round and square studs, mostly
  from the top only, sometimes top and sides, sometimes selective (whole chosen parts of the body, such as the dark back or
  the pale belly, never a band across the middle), rarely all over. The tiles that aren't studs don't look good yet: to be
  worked one at a time, later. Which parts are studded on a selective creature is Claude's call (stud the part to be
  looked at). Variants: gold is yellow gold, never brown; the rainbow is one smooth, straight gradient (vivid, a little pastel) of flat hues
  dithered into each other in very small pixels (a ninth of a cube; never cube-sized blocks, never wandering or blotchy edges); on a variant the creature's glowing colours take a contrasting `ACCENT` (violet on
  gold, white on rainbow). A dark framing colour is a dark tint (the Archelon's navy), not pure black, unless black suits
  the animal. For now models carry studs only; other tiles wait for a hand texture pass. Batch building: the brief for a
  builder and how to run a batch are in `docs/style/creature-brief.md`; the scripts are `tools/art/voxel_preview.py`,
  `voxel_finish.py`, `voxel_batch_sheet.py`, `voxel_export_all.py`, `voxel_looks.py`, `voxel_look_sheets.py` (paths from
  `voxel_paths.py`; renders go to `work/voxel/`, not kept in the repo) and `tools/blender/check_glb.py`; the fifty to model
  are listed in `docs/design/roster.md`. `voxel_kit.py --export <folder>` writes a creature's game mesh into `art/creatures/<Folder>/game/`:
  `<Name>.glb` (one object to a part, origin at its pivot, vertex colours, glowing faces split as `<Part>_Glow`; GLB, not FBX:
  FBX came back turned and scaled) and `<Name>.mesh.json` (parts, pivots, seat, glowParts, swimKeys as quaternions); the 33 built
  so far are listed in `docs/design/creature-queue.md`. All 33 were uploaded and installed by the game-code chat on 2026-11-10 (`tools/creatures/assets.json`); a changed creature
  needs a new upload (permanent: batch changes and tell that chat). Studs and the variants are not in the game yet. A brow sits on the eye (overlaps its
  top, only a little proud of the pupil); light follows the model's own lines (a colour edge, a seam, a fin's edge), never
  a mark in the middle of a plain surface. An archetype is a loose guide and a shared vocabulary, never a template to copy:
  each creature is designed from its own real animal (the user). Taper one step at a time; more slices are for a smooth
  taper, not bulk; don't over-apply a single note. A joint's sleeve is sized from the smaller
  of the two pieces and kept clear of its steps (the gate checks cube faces across parts).
- **The game code (2026-11-10):** riding is `RideService` (server: states Dock, Free, Riding, Jumping, Drowning; Oxygen)
  with `RideController` (the fish turns to where the camera looks; the camera), fish are `FishService` (a herd swimming
  straight down the lane; since 2026-11-13 down its own smooth line through the open water, `src/server/Lib/Stream.luau`,
  built once from the map at server start: [the herd](docs/design/herd.md); check a new map with
  `python tools/studio/herd_stream_test.py <studio_id> Edit`), and going fish to fish is `JumpController`: Ride a Dino's jump, read from the
  user's recordings ([reference](docs/reference/ride-a-dino.md)). What is built, measured and still open:
  [riding feel](docs/design/riding-feel.md). Every number is in `src/shared/Config.luau`, read live. Every fish has its own
  speed and passive archetypes, set by hand in one table (`Config.FishStats`; `Config.speedOf` = that number x the variant's, Gold 1.1, Rainbow 1.2;
  no rarity or land formula; since 2026-11-13 every fish also rolls one of six sizes and four colours, 24 of each, with the
  reference's odds, and each kind has its own size multiplier, `Config.BaseScale`: [sizes](docs/design/sizes.md); size does not change speed; the `Archetype` attribute, "" or ids comma-separated; rules, numbers and all 82 rows in
  [archetypes](docs/design/archetypes.md); the passives are built: `RideService` decides, `ArchetypeController` and `Config.ArchetypeFeel` are the feedback, a fish's tag names them, sandbox key F rides a try-out fish; measured in [docs/playtests/2026-11-12-archetypes.md](docs/playtests/2026-11-12-archetypes.md), not played by hand; animation hooks at the end of the note) and now and then a
  variant (`Variant`; look in `Shared/Variants`); the camera stays under the surface once dived (`Camera.Submerge`). In Studio the game
  starts as the **movement sandbox** ([docs/sandbox.md](docs/sandbox.md): no fail, R reset, V side view, N a panel of every
  number): the user tunes there and pastes "Copy changes" for Claude to write into Config. Angry mode (Hugo, 2026-11-12): with the meter in its red part (`Oxygen.AngryAt`) the
  ridden fish pulses red (`AngryController`) and slows in its body type's own way (`Shared/AngryStyles`, `Config.Angry`;
  the server sets the fish's `Angry` and `AngryStyle`); its motion is a stand-in sine until the partner's animations. Props (Hugo, 2026-11-13; `Config.Props`, `PropService`, `PropController`): only a Tank, a Breaker or a giant (model box of `Props.GiantVolume` cubic studs or more; `Config.breaks`, 16 of 82, listed in archetypes.md) breaks a prop; every other fish and every rider in the hop goes straight through, and the prop fades on that player's screen as they come up to it (`Props.FadeTo`); the server keeps only which boxes are out (tag `PropOut`) and puts the prop back when no player has been near for a while, each machine throws and fades its own copies of the boxes; test driver `tools/studio/props_b1`. The hop (Hugo, 2026-11-13; `Config.hopFrom`, `hopSpeed`, `hopSink`, `reachOf`): fast for the whole glide, then a stall, then a
  fall; the hook's reach is by speed (`Jump.GrabNear` to `GrabRange`), counted the same by the server; the wait between fish is
  `Jump.Cooldown` 0.08 s from the touch ([docs/playtests/2026-11-13-hop-air-reach.md](docs/playtests/2026-11-13-hop-air-reach.md), not played by hand). What each push changed is in
  [Handoff](docs/Handoff.md); who has which files, [Sessions](docs/Sessions.md).
