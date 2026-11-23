# Sub models

Back to [the submarine](submarine.md). Hugo, 2026-11-22: "give me a selection of a couple of base models in the first
place, all in different styles but showing the same model (sub level), try copying the voxel style in one of them. Once
I approve you can do it for all of the stages."

**State (2026-11-23, tasks t2 and t3): Hugo picked style A, the chunky toy. All nine tiers are built in it and are in
the game on Hugo's PC. Task m4 (same day) saw them in the game for the first time, fixed the shop's cards and the
name sign: "Seen in the game" below.** The voxel set (style D) built on 2026-11-22 was a fallback, taken before Hugo had named a
letter; it is kept in `art/subs/voxel/` and is no longer in the game. Nothing is uploaded (see "In the game").

![the nine toy subs](../attachments/subs-toy-all-stages.png)

Tiers 1, 6 and 9 beside the approved model: [1](../attachments/subs-toy-1-beside-A.png),
[6](../attachments/subs-toy-6-beside-A.png), [9](../attachments/subs-toy-9-beside-A.png).

## The nine

Every tier keeps the placeholder's seat (its top 5.7 studs over the middle and 5 behind it), the tower in front of it
and the hull's top near 5, so the ride is the same on all of them. The colours are `SubModels.List`'s. Every tier has
the toy's fat rounded forms, thick rims round the glass, a red guard ring round the propeller (a lighter red on tier 8,
whose hull is red) and a wind-up key on the back in the tier's accent colour. The silhouette changes every few tiers.

| Tier | Sub | What sets it apart | Triangles | Across x tall x long |
|---|---|---|---|---|
| 1 | Bathtub | the approved model: the tub, two ports a side, stubby wings | 1,288 | 21.0 x 16.6 x 36.7 |
| 2 | Reef Runner | the tub with a bumper bar, a white band, a snorkel, back wings | 1,716 | 21.0 x 20.2 x 38.5 |
| 3 | Kelp Cruiser | longer, three ports, leaf wings, a V of leaf fins for a tail, kelp on the cap | 1,616 | 22.9 x 21.0 x 39.7 |
| 4 | Wreck Diver | boxy salvage boat: ballast tanks, a periscope, a crane and hook, patches, twin lamps | 2,492 | 16.6 x 21.1 x 37.6 |
| 5 | Blue Streak | a rocket: long and low, a red nose, swept wings, pods, a tall swept fin | 2,104 | 26.4 x 16.8 x 45.0 |
| 6 | Twilight Ray | a manta: wide rounded wings with a line of light, horns, a long tail spike | 1,824 | 41.4 x 16.5 x 51.0 |
| 7 | Midnight Hunter | a shark: a jaw with teeth, slit eyes, gills, a dorsal fin on the cap, claws | 1,868 | 22.0 x 21.8 x 45.0 |
| 8 | Vent Crawler | armour hoops over glowing seams, vent stacks, pincers, belly spikes | 2,400 | 17.7 x 19.2 x 44.6 |
| 9 | Abyss King | the biggest: a glowing crown, a trident ram, pods on wings, a crest, spikes | 3,028 | 27.3 x 23.4 x 56.6 |

The sizes are the models' boxes in studs, as they came into Studio.

Each is 5 or 6 MeshParts: `Hull` (all that is rigid), `Hull_Glow` (glass and lines of light, Neon), `Seat`, `Prop`
(spins; its box is centred on the hub), `Prop_Glow` (tiers 6 to 9: a glowing hub), `Light` (the lamp, Neon, carries the
beam). Colours are vertex colours, no pictures.

The builder has a gate, as the creatures' has: a piece that is open or inside out, and faces of two pieces that face
the same way, overlap and lie under 0.05 studs apart where no third piece covers them (they would flicker in Roblox),
are printed as `  !` lines and stop the build. All nine pass.

## In the game

- `Shared/SubModels.build(n)` clones `ReplicatedStorage.SubMeshes.<Id>` (Bathtub, ReefRunner, KelpCruiser, WreckDiver,
  BlueStreak, TwilightRay, MidnightHunter, VentCrawler, AbyssKing), adds the beam, the glow, the name and the wake,
  and hands back what it always did. A place without a tier's template gets the old placeholder of plain parts, so the
  other PC keeps working until its place has them. The stand's shop (`UI/SubPanel`) and the trip (`SubController`)
  both go through `build`, so both show the models.
- `SubController` places the hull part by its own rest frame (the placeholder's hull was a cylinder turned a quarter;
  a model's isn't) and spins `Prop` and `Prop_Glow`.
- **The name sign clears each model's top (2026-11-23).** The sign is 3 studs tall and used to sit at 12.5 studs over
  the middle on every tier, its lower edge at 11. Every toy tier is taller than that (11.2 to 15.7 studs: the cap, the
  snorkel, the kelp, the periscope, the dorsal fin, the crown). `SubModels` puts the sign's lower edge 2 studs over
  the model's tallest piece (`SIGN_GAP`), never lower than before. It was 0.6 studs until task m4: seen in the game
  from the dock, the snorkel, the kelp, the periscope, the fin and the crown still ran into the letters.
- **Midnight Hunter's name is written in its light's colour (task m4).** Every name is in its hull's colour on a navy
  outline, and tier 7's hull is navy: nobody could read it. A hull darker than `SIGN_DARK` gets its `Light` colour
  instead (only tier 7, cyan).
- **Nothing is uploaded.** Hugo's PC can't upload (no Open Cloud key, Studio's connector hangs under Wine: the same
  as for the creatures), so the templates are local mesh files, as the creatures' `install.py --local`:
  `rbxasset://ridefish/submarines/<Id>/<Part>.mesh` in Studio's content folder. They show only on this PC and are gone
  when Studio updates itself (run the install again). A published game needs the nine GLBs uploaded from the PC that
  can (as `tools/creatures/upload.py` does) and their ids in `tools/subs/assets.json`, which is empty for now.
- **Save the place, or run the install again after Studio next restarts.** The install wrote the toy mesh files over
  the voxel ones, at the same paths, and made the toy templates in the open place. The place was not saved, so what a
  reopened place holds is not known; the install puts it right either way.

## Checked in the game (2026-11-23, task t3)

Three playtests on Hugo's PC, by script (`tools/studio/t3_toy_subs_check.py`, log `work/t3/check.log`): all nine
tiers twice, then tiers 5 to 9 once more for the propeller. **Not played by hand, and not seen by eye:** see
"Pictures" below. The numbers here are the second playtest's, with the third's where it was worse.

- **Every tier builds from its template.** All nine come out as MeshParts (5 parts on tiers 1 to 5, 6 on tiers 6 to
  9), with 2 or 3 Neon parts, the lamp's beam on and the wake's emitter on the propeller.
- **A real trip on every tier,** tier N to land N + 1. The check reads our own sub on every frame of the Ride phase
  that it samples (192 to 369 frames a trip) and keeps the worst value, or counts the frames that were wrong. The
  pick-up, the arrival and the drop are not read. It stops reading about 6 seconds into the Ride: that is the whole
  Ride on the short trips (3.2 seconds on tier 1), but the longest take 7 seconds (`Config.Sub.MaxRide`), so on tiers
  8 and 9, and maybe 6 and 7, up to the last second of the slowing was not read:

| What | Result on all nine |
|---|---|
| The rider | at the seat's place (0, 7.4, 5 from the sub's middle); the furthest off on any frame was 0.00 studs. That is 1.7 studs over the seat's top |
| The seat | where the model has it; the furthest off on any frame was 0.00 studs |
| The propeller's place | its middle stays on the hub (0.005 studs off at most on any frame), and so does the glowing hub of tiers 6 to 9 (0.002); it stays turned about the sub's long axis on every frame |
| The propeller's turn | its angle changed on every frame on tiers 1 to 4 and 8. On tiers 5, 6, 7 and 9 it read the same on a few frames of about 350 (at most 2, 6, 7 and 1): whole turns in one frame wherever the check could tell, see below |
| The wake | its emitter on, on the propeller, on every frame; its rate went from 11 to 260 bubbles a second over a trip (`SubController` sets it from the speed) |
| The lamp | Neon with its beam on, on every frame; the beam points along the nose (1.00 at worst); it sits 10.4 (tier 7) to 20.2 (tier 9) studs ahead of the middle (read at the trip's end) |
| The name sign | on, on every frame; its lower edge 0.6 studs over the model's top (read once, as the model is built) |
| The nose | points the way the sub goes: 0.89 at worst (tier 8), 0.97 to 1.00 on the others |

- **The propeller's same-angle frames are whole turns, not stops (third playtest).** The check compares the angle
  on one frame with the last. `SubController` turns the propeller by 4 + 0.12 x speed radians a second, which at about
  3,100 studs a second is one whole turn a frame at 60 frames a second, and a whole turn reads as no turn. On the
  third playtest the check worked that turn out itself on each same-angle frame, from the rider's speed and the
  frame's length (it is not read from `SubController`), and counted the frames where it came within 0.35 radians of
  a whole number of turns: all 14 did (6 of 6 on tier 6, 7 of 7 on tier 7, 1 of 1 on tier 9). The smallest such
  turn on each tier was 6.23, 6.21 and 6.28 radians, one whole turn (6.28). The second playtest's same-angle frames
  (2, 6 and 4 on tiers 5, 6 and 7) were counted before the check could tell, so those are likely the same, not
  confirmed. Seen by eye, a propeller at those speeds may look still or seem to turn backwards; `SubController`
  turned the placeholder and the voxel set the same way.
- **Top speeds on the trips:** 464 studs a second to land 2, 4,315 to land 10.
- **The shop's cards cut off the big tiers (by the card camera's numbers, not seen). Fixed in task m4, see "Seen in
  the game".** What t3 found: `UI/SubPanel` pictures every
  sub from one fixed spot, in a box 188 wide less its padding and 112 high: 1.5 to 1.7 times as wide as it is tall.
  How wide a box each tier's far end needs, as a multiple of its height: tier 9, 2.41; tier 8, 1.79; tier 5, 1.55;
  tier 6, 1.54; tier 7, 1.49; tiers 1 to 4, 1.10 to 1.36. So tiers 8 and 9 are cut off at one side, and tiers 5, 6
  and 7 are at the edge. Tiers 8 and 9 also fill the box's whole height (1.00 and 1.02 of it). The voxel set was
  cut too (tier 9 needed 2.05), so this is older than the toy set, but worse now.
- **Not checked here:** whether the rider's body passes through the back rest, the wind-up key or a fin, and whether
  the blades cut the guard ring when seen. Task m4 looked: see below.

### Pictures

t3 got none: every still came out as one frozen picture of Studio in Edit. Task m4 found that stills are live while
a playtest runs, even with Studio's window off the screen (about one new picture a second), and took them: below.

## Seen in the game (2026-11-23, task m4)

Stills from playtests on Hugo's PC, taken by script (`tools/studio/m4_subs_shots.py`, log `work/m4/shots.log`) and
looked at one sheet at a time. Every still had to differ from the one before it, so none is a frozen picture. **Not
played by hand.**

![the nine over the stand](../attachments/m4-subs-stand.jpg)

- **All nine build from their meshes and carry the right name.** Each floats over the sub stand, nose to the camera,
  the screens hidden. This sheet is the code as it is now (the sign 2 studs up, tier 7's name in cyan).
- **On a trip** (tier N to land N + 1, a still about a second into the run):
  [the game's own view](../attachments/m4-subs-ride.jpg), and
  [a close view from a test camera](../attachments/m4-subs-seat.jpg). On all nine the rider sits on the seat behind
  the tower and the propeller is inside its ring. The rider is small in these views: whether the back rest, the key
  or a fin touches the rider can't be told from them. The
  numbers of the t3 check were read again on the same trips, on the new map: the rider and the seat 0.00 studs off,
  the propeller 0.004 at most, the wake, the beam and the sign on, on every frame (`work/m4/rides-run2.txt`). These
  trips ran before the sign was raised; nothing else differs.
- **The close view is a test camera, never the game's.** It stood to one side of the sub, only while the script's
  own trips ran. Hugo saw it in a playtest and said (2026-11-23): "what is this new camera perspective for the
  submarine? ... make sure it doesnt implement the camera on the side ever". It is in no file under `src/`, it is out
  of the place, and it is taken out of the script.
- **The shop's cards show every sub whole now**, at PC size and at a phone's (844 x 390, by the shop's `PanelPhone`
  test hook, not a real phone):

![the shop's cards before and after](../attachments/m4-sub-shop.jpg)

  - Before, `SubPanel` pictured every sub from one spot. By the models' own points the big tiers reached past the
    picture's edge: tier 5 to 1.01 of its half width, tier 8 to 1.17 (and 1.00 of its height), tier 9 to 1.57. The
    two "before" pictures are the old code in the game: tier 5's nose and tier 8's claws are at the edge or past it.
  - Now each model has its own camera spot (`SubPanel`'s `SHOTS` table). The view's direction is the same for all;
    the camera moves sideways until the model sits in the middle of the picture, and back until the whole of it is
    inside 0.9 of the picture, never nearer than the old camera stood. Seven tiers keep their size and are only
    centred; tier 6 is a little smaller (62 studs off, was 59) and tier 9 smaller (69).
  - Read in the game after the fix, PC and phone alike: every tier inside, the furthest reach 0.66 (tier 1) to 0.90
    (tiers 6 and 9) of the picture's half.
  - **Why a table and not a sum in the game:** the game knows only a mesh part's box, and a box's corners stand well
    outside a rounded hull: framing by them shows the subs 16 to 45% smaller than they need be.
    `python tools/subs/card_fit.py` reads the models' own points from `art/subs/<Id>/<Id>.glb`; `--write` puts the rows
    into `SubPanel.luau`, `--check` fails if they are stale or a model is cut. **Run it after a sub is rebuilt.** A
    place without the meshes (the placeholder) is framed in the game by its boxes (`shotBy`): written, not seen.
- **Open: on a trip the name sign shows on some stills and not on others.** In the game's own view it is there on
  tiers 5, 8 and 9 and missing on 1 to 4, 6 and 7; from the test camera it was there on 1, 3, 5, 8 and 9. The t3
  check reads the sign as on, on every frame. The placeholder's old picture (`s1-sub-ride.png`) has no sign either,
  so it is older than the toy set. **Cause not found.** Two guesses, neither tested: the sign is drawn a frame late
  and the sub moves 8 to 70 studs a frame (but where the sign shows, it sits in its right place), or its 140-stud
  limit (`MaxDistance`) cuts it. The script has a probe for
  it (`m4_subs_shots.py probes`: the sign watched frame by frame, a ball where it should be, with and without the
  limit); it was not run, because the playtest then running was Hugo's own.
- **Not checked:** a real phone; a trip by hand; the trip's pick-up, arrival and drop by eye; the stills are one
  moment of each trip, so a blade crossing the ring later in a trip would not show.

## Build

- `blender --background --python tools/blender/sub_stages.py -- <tier 1-9> <out folder> [--style toy|voxel]
  [--export art/subs] [--check]` builds one tier (toy unless told otherwise), runs the gate, renders hero, side and
  the riding side, and with `--export` writes `art/subs/<Id>/<Id>.glb` and `<Id>.mesh.json` (Roblox's axes, the nose
  to -Z, 1 unit = 1 stud, the origin at the sub's middle). The voxel set: `--style voxel --export art/subs/voxel`.
- `python tools/blender/sub_stages.py sheet <renders folder> docs/attachments/subs-toy-all-stages.png` lays out the
  sheet, and stops if a view is cut off at its picture's edge.
- `python tools/subs/install.py runner` writes the mesh files and makes the templates in the open place (Edit).
- `python tools/studio/s2_subs_check.py push` puts `SubModels` and `SubController` into the open place (Edit).
- `python tools/studio/t3_toy_subs_check.py install | run | remove` is the playtest check of all nine and the stills
  (`run` in a playtest; `install` and `remove` in Edit).
- `python tools/subs/card_fit.py [--write | --check]` works out the shop cards' camera spots from the GLBs.
- `python tools/studio/m4_subs_shots.py install | gate | closes | shop <tag> | rides | probes | sheets | remove`
  takes the stills and lays out the sheets (its top says how). It sends the player on trips and takes the camera:
  make sure nobody is playing in the playtest first.

## Open (the user)

- Notes on single subs, from the sheet above.
- A ride by hand on a few tiers: the rider on the seat, the propeller in its ring, the name over the tall pieces.
- The name sign that comes and goes on a trip ("Seen in the game"): find the cause, or decide the name isn't needed
  while riding.
- Whether the studs go on in the game (with the creatures').
- Uploading the nine models for a published game (permanent: on the user's word, from the PC that can).

## The voxel set (2026-11-22, task s2: the fallback)

Built first, in style D, when Hugo had allowed the build without naming a letter. Kept in `art/subs/voxel/<Id>/`
(sheet: [the nine voxel subs](../attachments/subs-all-stages.png); in-game stills of that day:
`docs/attachments/s2-*.png`). It is out of the game since the toy install.

# The style options (2026-11-22, task o1)

Four options of tier 1, for the pick. Built by headless Blender 5.2, not seen in Studio. **The pick: A, the chunky
toy** (Hugo). What follows is as written before the pick.

![the four options](../attachments/sub-options-2026-11-22.png)

## What every option is

Tier 1, "The Bathtub" (`Shared/SubModels`: yellow hull, navy trim, cyan glass), on the placeholder's measures so the
ride doesn't change: about 36 studs long, 10 across, the tower in front of the middle, the seat's top 5.7 studs over
the middle and 5 behind it (`SubController`'s `SEAT`), a bar for the hands, two ports a side, wings by the nose, a
cross of fins, a propeller, a lamp under the nose. One mesh to a part; `Seat`, `Light` and `Prop` keep the names
`SubController` needs, and `Prop` has its pivot on the hub so it can spin. Colours are flat materials, no pictures
(option D's studs are the creatures' stud tile, laid on in the render only).

| | Style | Triangles | Parts | What it is |
|---|---|---|---|---|
| A | Chunky toy | 1,288 | 11 | Fat rounded forms with few sides, smooth shaded, thick rims round the glass, a red guard ring and a wind-up key |
| B | Sleek faceted | 412 | 10 | Flat planes, a pointed nose, a swept canopy and fins: the first creature kit's look |
| C | Retro riveted | 2,356 | 15 | A boiler with brass hoops and rivets, a round turret with a copper dome, a lantern, a rail, a snorkel |
| D | Voxel | 576 | 10 | The creatures' block style: few big boxes, each a part; the nose is two turned blocks; studs on faces that look up; trim is navy, not black; colour touches a third of a cube proud; one flaw (a patch plate) |

All four are far under what Roblox takes for one mesh (the creatures run a few thousand triangles each).

## How each would scale to the nine tiers

The placeholders add one piece a tier (stripe, back wings, periscope, pods, crest, claws, spikes, crown) and change
colour. A real set should also change the silhouette every few tiers. Per style:

- **A, toy:** the same tub grows fatter and longer; add-ons are toy parts (pods, a periscope, a second ring). Cheap to
  vary, friendly, but the deep tiers ("Midnight Hunter", "Abyss King") will struggle to look dangerous.
- **B, faceted:** scales best toward fast and dangerous: longer nose, more and sharper fins, pods as blades. The
  early tiers look less fun, and it matches the old creature look, not the voxel creatures now in the game.
- **C, riveted:** the most character per tier (more pipes, lamps, claws, armour plates), but the most triangles and
  the most work per sub, and small detail is lost at riding distance and speed.
- **D, voxel:** matches the creatures and the map's squares. Tiers scale as the creatures' rarities do: more and
  gentler steps, a second layer of form, glow along seams for the deep ones. Lowest risk of looking out of place.

Claude's recommendation was **D**, with A's friendliness in the early tiers (round-ish proportions, the red accents).
Hugo picked A. The riding view is the one to judge by: the sub is mostly seen from behind and above.

## Build (the options)

- `blender --background --python tools/blender/sub_kit.py -- <A|B|C|D> <out folder> [--export art/subs]` builds one
  option, prints its triangle count, renders hero, side, front, top and the riding view, and with `--export` writes
  `art/subs/Sub_<style>.glb` (Roblox's axes, 1 unit = 1 stud; not checked in Studio).
- `python tools/blender/sub_sheet.py <renders folder> docs/attachments/sub-options-2026-11-22.png` lays out the sheet
  (the renders went to `work/subs/`, which isn't kept in the repo).
