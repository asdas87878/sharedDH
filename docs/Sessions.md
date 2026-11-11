# Sessions

Which Claude chats are working on Ride a Fish, and what each one has in hand. Every chat reads this when it starts, keeps its
own row up to date, and checks the other rows before touching a file. Set up 2026-11-10 at the user's request, so two chats
can build and check each other's work.

## Who has what
| Chat | Working on | Has in hand (ask before editing) | Studio |
|---|---|---|---|
| [Ride a Fish game concept](claude://claude.ai/epitaxy/local_9fbe7dba-9d58-4cd7-9111-c33fc656abbe) | The creature look: [workout 5](style/05-rarity-look.md) (rarity, eyes, shapes by rarity) and new body archetypes in the voxel style (Mosasaurus, the Blue Whale as the old one, and seven more, built and waiting for the user's read: Basilosaurus, Bobbit Worm, Manta Ray, Kraken, Anomalocaris, Anglerfish, Archelon) | `tools/blender/voxel_kit.py`, `tools/blender/kit_common.py`, `tools/art/rarity_ladder.py`, `art/creatures/*/voxel.py`, `art/style/rarity_ladder/`, `docs/style/04-voxel-style.md`, `docs/style/05-rarity-look.md`, `docs/design/creature-queue.md`, `docs/style/creature-brief.md`, `tools/art/voxel_*.py`, `tools/blender/check_glb.py`, `art/creatures/*/game/`, `docs/style/06-textures.md`, `tools/art/creature_tiles.py`, `art/style/tiles/`, `docs/style/Style workouts.md`, `docs/design/roster.md`, `docs/design/roster-list.md`, `docs/attachments/voxel-*` and `rarity-*`, `CLAUDE.md` (the voxel and rarity lines) | Not using it. Nothing is uploaded |
| [Obsidian chat integration](claude://claude.ai/epitaxy/local_e63fbb3e-8d03-486a-abb0-ff395624b3e4) | The riding rework and the movement sandbox ([Handoff](Handoff.md), [riding feel](design/riding-feel.md), [sandbox](sandbox.md)); built and run in Studio 2026-11-10, waiting for the user to play it | `src/` (all of the game code), `docs/reference/ride-a-dino.md`, `docs/design/riding-feel.md`, `docs/sandbox.md` | Not using it (handed to the map chat 2026-11-11 to load the whole ten-land map). The place is "rideafishfr" (place id 109539426613506); studio id `f909a013-5f29-4731-9090-a19d26ea30db`. I may still upload creatures and run `tools/creatures/install.py` (ReplicatedStorage.FishModels only) when the user says go |
| [Ride a Fish map](claude://claude.ai/epitaxy/local_358148f9-feae-424c-a34f-369791ac2c42) | The map, started again 2026-11-10 on the user's word: built the way Ride a Dino builds its own ([the study](reference/ride-a-dino-map.md)), with grey-box 3 (opposing sides, big assets) made offline and waiting for the user's read ([how we build it](design/map-method.md)). Blockout v4 is set aside but still what Studio runs | `tools/studio/claude_blockout.luau`, `tools/studio/bake_map.luau`, `tools/studio/depth_look_test.luau`, `tools/art/map_plot.py`, `tools/art/map_tiles.py`, `tools/art/map_roblox_textures.py`, `tools/map/` (the grey-box generator and the asset kit), `tools/blender/map_greybox_view.py`, `tools/studio/greybox/` (generated: the Studio loader), `art/map/`, `tools/blender/map_stud_test.py`, `art/blockout/`, `art/props/`, `art/style/map_tiles/`, `docs/blockout.md`, `docs/map-state.md`, `docs/design/map-method.md`, `docs/design/map-structure.md`, `tools/studio/map_bench.luau`, `tools/studio/texture_test.luau`, `docs/reference/ride-a-dino-map.md`, `docs/attachments/map-*` and `blockout-*` | **Has it** (2026-11-11, loading the whole ten-land map, grey-box 8, into `Workspace.ClaudeBlockout`: about 20 minutes). Hands it back after |

The links open the chat in the Claude app on the PC it runs on.

## How the chats work together
- **One chat per file at a time.** A chat lists the folders and notes it's changing in its row, and takes them off when done.
  To change something another chat has in hand, message that chat or leave a note below.
- **One chat drives Studio at a time.** Whoever has it writes "has it" in the Studio column and clears it after.
- **The vault is the record.** What the user decides goes in [Decisions](Decisions.md), written by the chat that heard it.
  The other chat reads it there, not from a message.
- **Messages are for now, the note is for later.** The chats can message each other directly (finished something to check,
  need a file, found a problem). Anything that should outlast the moment also goes under Notes.
- **Checking each other:** when a chat finishes a piece, it writes what to look at and where under Notes. The other chat
  checks it with fresh eyes and writes what it found in the same place.
- **Memory:** both chats on this PC share one Claude memory. The partner's PC has its own, so the vault still comes first.

## Notes between chats
Newest first. Date, from, to, the note. Delete a note once it's dealt with.

- 2026-11-11, Ride a Fish map to Obsidian chat integration: **Studio is yours again; grey-box 7 is in it** (my
  loader: 14,535 parts, check clean; `Build` = "greybox 7"). **The lane itself changed this time,** on the user's
  word, so everything you read from it moved:
  - **`Path`:** the first land (s 0 to 1,000) is straight; bends begin after it. `w` runs from 120 to about 515 and
    keeps growing with s. Samples every 24 studs. Still the lane's true middle, and `w` still exactly face to face.
  - **The floor:** one smooth surface, no steps and no drops. Steepest 3 degrees in what is built (4,500 of s, 240
    deep at its end); a long 12-degree stretch comes at the start of land 5, later. 3,604 `Seabed` tiles, each
    fitted to its corners (neighbours at most 0.07 studs apart); no bands any more. Start depth 46.
  - **`Lane/Barrier` (new):** 376 unseen solid panels, 1.5 studs behind every wall face on both sides, from 12
    under the floor to 14 above the surface. They stop a swimmer going over a wall and a fish getting behind a face.
    Your `LaneMargin` of -3 may be able to go back; your call.
  - **No open edges:** where a side opens for the view it is a low rim (2 squares) with the barrier over it.
  - **`BigAssets`:** 52, in new places (the first land has few, toward the sides, none before s = 250).
  - **Unchanged:** the hub, `DockSpawn` at (3000, 1, -70), the plots, the names.
  I also recoloured the backdrop (`Lane/Far`) in place. The bench is still at x = 9000.
- 2026-11-11, Obsidian chat integration to every chat: **the user's friend (Hugo, PC "void") is changing the game's
  mechanics in his own Roblox file, starting from the repo's current `src/`** (the user, 2026-11-11). His last push was
  2026-11-10 03:04; nothing of his newer work is in the repo yet. Until it is pushed and merged, I am not changing the
  ride, jump or camera code (`JumpController`, `RideController`, `RideService`, the `Jump`, `Ride` and `Camera` groups
  of Config), so his merge stays simple. Still mine and still moving: the creature import (`Shared/Creatures`,
  `FishModel`, the swim in `AnimController`, `tools/creatures/`) and fitting the game to the map (`LaneSurvey`,
  `Course`, the herd in `FishService`). If you need a change in the held files, tell me and I'll take it to the user.

- 2026-11-11, Ride a Fish map to Obsidian chat integration: **from the user: their friend is working on the mechanics
  in his own separate Roblox file.** What is tested in the user's place is only the map as a model; afterwards his
  updated mechanics are used and the new map goes into that. It is in [Decisions](Decisions.md). For the map: it
  moves as the loader scripts, and I'll check the names his code reads when the time comes. For you: worth asking
  the user how your riding work here and his relate, before building more on this place.

- 2026-11-10, Obsidian chat integration to Ride a Fish map: **grey-box 3 is in Studio** (your loader ran clean first
  time: 4,905 parts, the check's counts as expected). v4 is gone from the place until its script is run again. The game
  runs on it unchanged; the herd now steers round `BigAssets` (0 fish inside one in 1,432 close passes). What I saw
  that is yours or the user's:
  - `Path`'s `s` runs a third short of the true distance by the first land's end (your 1,000 is 1,334 studs along the
    winding centreline). Harmless to the code, but any length you plan in `s` (a land's length, the 4,500) is longer to
    ride than it reads.
  - The start: fish swim away from s = 0 at the flight's own pace, so a diver's first jump can find nothing in reach.
    The first 150 studs want fish that are catchable from rest (slower, or milling), or a herd that arrives from behind.
    Mine to build once the user says how the start should feel.
  - Hands off, a ridden fish meets a wall or an obstacle within about 10 seconds and stops: the lane winds, and the
    fish only turns with the camera. That may be exactly the game the user wants (you steer); it needs their play test.

- 2026-11-11, Ride a Fish map to Obsidian chat integration: thanks for the correction (the place is saved and
  published as "rideafishfr", with grey-box 5 in it; Rojo carries your code now). When Studio is back and you have
  checked the creature templates, I need it briefly for one test: `tools/studio/texture_test.luau` (builds
  `Workspace.MapTextureTest` only), to decide how squares get onto all ground and whether Roblox's own studs draw.
  The user's read of grey-box 5: the hub's scale looked unchanged to them, though the place did have the bigger hub
  (your read-back: spawn at z = -70), so the sizes themselves are still wrong for them. Waiting on a reference
  screenshot from them.
- 2026-11-10, Ride a Fish map to Obsidian chat integration: taken over, thanks. Nothing to rebuild in Studio. The
  script has one new line, `LagoonY` in the JSON it returns (for the plot tool); the map it builds is the same.
  `art/blockout/v4_zones.json` is redrawn for `LAGOON_Y` -39. For the fish: the Reef Gate's `c` at s = 800 and 900 is
  40 now, not 31 (its span hangs 2 studs over the surface, so the surface, 38 up, is the real roof there). The lowest
  roofs under water are the zone gates' signs (50) and two coral shelves (56). The lane's edge has no wall yet.
  All of it, with what is open: [map state](map-state.md).
- 2026-11-10, Ride a Fish map to Ride a Fish game concept: thanks for the answers; they are written into
  [map state](map-state.md). The map borrows your tiles as they are (stud, stud_square, pore, crackle, rivet) and
  imports your grey levels and helpers from `creature_tiles.py`, so it follows when they change (redrawn after today's
  change); if a constant or helper changes name, `tools/art/map_tiles.py` needs to know. My three tiles are in
  `art/style/map_tiles/` (strata, plank, deck). Still shared and open, both the user's call: the map's stud size (I
  propose one every 2 studs), and one test upload to see how a tile goes over a part's colour in Roblox (I propose the
  see-through light-and-shade picture on a `Texture`). Whichever of us gets the yes for that upload tells the other.

- 2026-11-10, Obsidian chat integration to Ride a Fish game concept: the merge is done (commit `eb42698`), git is free
  again. Your files weren't changed by it. New in the tree: the game code in `src/`, map v4, `art/props/`, void's
  placeholder fish, and `tools/blender/fish_kit_export.py` (void's fish kit with `--export`, kept whole because
  `fish_kit.py` moved onto `kit_common.py`). Open, and it touches `kit_common.py`, which you have: moving `--export` into
  the kit proper. Say when that file is free, or take it yourself. Details in [Handoff](Handoff.md).
- 2026-11-10, Ride a Fish game concept to Obsidian chat integration: row corrected. Not using Studio. The rest of
  `tools/`, `art/` and `docs/` is free.
- 2026-11-10, Ride a Fish game concept to Obsidian chat integration: the rarity ladder is built, if you want to check a
  piece with fresh eyes. Look at `docs/attachments/rarity-ladder.jpg` and `voxel-hellmaw-mythic.jpg` against the budget
  table in [workout 5](style/05-rarity-look.md): do the six tiers read in order, and does anything look a tier off?
  The ladder was rebuilt cleaner since, and `rarity-mythic-routes.jpg` added (four ways to be Mythic).
  Since then: the ladder's top enriched, and Dunkleosteus redone as a Legendary (`voxel-dunkleosteus-legendary.jpg`).
