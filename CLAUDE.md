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
  Grey-box 4 (offline, Python, no Lune needed; the hub sized from the reference's, plots `Dock.Plots.PlotN`, the floor as 20-stud tiles on one world grid so Roblox pictures line up; pictures by `tools/art/map_roblox_textures.py`, their asset ids in `art/map/textures.json`): `python tools/map/greybox.py` writes every box to
  `art/map/greybox/parts.json` and the game's path to `path.json`; `tools/blender/map_greybox_view.py` renders views,
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
  the animal. For now models carry studs only; other tiles wait for a hand texture pass. Batch building: a lean brief for
  fresh agents is in the session scratchpad (`BUILDER_BRIEF.md`, `preview.py`, `finish.py`); the fifty to model are listed in
  `docs/design/roster.md`. `voxel_kit.py --export <folder>` writes a creature's game mesh into `art/creatures/<Folder>/game/`:
  `<Name>.glb` (one object to a part, origin at its pivot, vertex colours, glowing faces split as `<Part>_Glow`; GLB, not FBX:
  FBX came back turned and scaled) and `<Name>.mesh.json` (parts, pivots, seat, glowParts, swimKeys as quaternions); the 33 built
  so far are listed in `docs/design/creature-queue.md`. Nothing is in Roblox yet: an import is an upload and needs the user's word. A brow sits on the eye (overlaps its
  top, only a little proud of the pupil); light follows the model's own lines (a colour edge, a seam, a fin's edge), never
  a mark in the middle of a plain surface. An archetype is a loose guide and a shared vocabulary, never a template to copy:
  each creature is designed from its own real animal (the user). Taper one step at a time; more slices are for a smooth
  taper, not bulk; don't over-apply a single note. A joint's sleeve is sized from the smaller
  of the two pieces and kept clear of its steps (the gate checks cube faces across parts).
- **The game code (2026-11-10):** riding is `RideService` (server: states Dock, Free, Riding, Jumping, Drowning; Oxygen)
  with `RideController` (the fish turns to where the camera looks; the camera), fish are `FishService` (a herd swimming
  straight down the lane in one layer), and going fish to fish is `JumpController`: Ride a Dino's jump, read from the
  user's recordings ([reference](docs/reference/ride-a-dino.md)). What is built, measured and still open:
  [riding feel](docs/design/riding-feel.md). Every number is in `src/shared/Config.luau`, read live. In Studio the game
  starts as the **movement sandbox** ([docs/sandbox.md](docs/sandbox.md): no fail, R reset, V side view, N a panel of every
  number): the user tunes there and pastes "Copy changes" for Claude to write into Config. What each push changed is in
  [Handoff](docs/Handoff.md); who has which files, [Sessions](docs/Sessions.md).
