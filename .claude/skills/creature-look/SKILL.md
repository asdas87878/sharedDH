---
name: creature-look
description: "Ride a Fish's creatures: the voxel kit and the older plan kits, the user's rules for building, joining, scale, anatomy, rarity looks, eyes, studs, textures and variants, batch building, and the export into the game. Load it before designing, building, fixing, reviewing or exporting any creature in art/creatures, or answering how one is made."
---

# Creatures (rules and tools)

Moved here word for word from CLAUDE.md on 2026-11-22 (the token-saving setup, docs/AI setup.md), so only chats
doing this kind of work carry it. Keep it up to date HERE from now on, the way CLAUDE.md was kept.

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
  needs a new upload (permanent: batch changes and tell that chat). The 29 recoloured for land contrast went up and were
  installed on 2026-11-19 (`tools/creatures/recolour_log.json`, old ids in `assets_before_recolour.json`); to check the place,
  compare each `ReplicatedStorage.FishModels.<Id>`'s `AssetId` attribute with `assets.json`. Studs and the variants are not in the game yet. A brow sits on the eye (overlaps its
  top, only a little proud of the pupil); light follows the model's own lines (a colour edge, a seam, a fin's edge), never
  a mark in the middle of a plain surface. An archetype is a loose guide and a shared vocabulary, never a template to copy:
  each creature is designed from its own real animal (the user). Taper one step at a time; more slices are for a smooth
  taper, not bulk; don't over-apply a single note. A joint's sleeve is sized from the smaller
  of the two pieces and kept clear of its steps (the gate checks cube faces across parts).
