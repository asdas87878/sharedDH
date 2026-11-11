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
- **Higher, and always underwater:** `Jump.Apex` 20; the flight stops `Jump.Ceiling` under the surface; in shallow water
  the herd is pressed down to leave the jump its room (`Config.herdTop`, `Spawn.HeightFloor`). The lagoon and the
  Shallows are 9 studs deeper for it (`LAGOON_Y` -39 in `tools/studio/claude_blockout.luau`; every later zone moves
  down with it), which gives the Shallows the whole 21-stud rise. The map in Studio was rebuilt from the script.
- **A critical pass of the riding code (2026-11-10):**
  - The "flown under the map" bug: fish are CanCollide false and the floor check was a ray from the fish itself, which
    sees nothing once it is inside a part. New `src/client/Lib/Course.luau` keeps the ridden fish (`clearVelocity`) and
    the flight (`clearMove`) in open water: rays from where we are (solid parts only), plus the lane's own floor and
    edge from the map's centreline, which the server now publishes to clients (the `LanePath` attribute on Remotes).
  - Air steering: A and D steer the flight; the camera no longer does (`Jump.CameraSteer`).
  - Taken out: the flight's ribbon and bubbles (`Fx.trail`), the launch ring, the launch's view widening
    (`State.FovKick`), the landing rattle (`State.shake`, `Burst.Kick`), the glide's bob, and the `Fx` "Jump" event.
  - Also: a pull-in is given up if its fish is put away or taken; no dividing by a sandbox number set to 0; the camera's
    and the fish's ray settings are made once, not every frame.
  - Run in Studio: a fish dived at the floor and steered into the lane's wall stayed in the water; three jumps landed.
- **A second, independent review of the same code (2026-11-10), and what was done with it:**
  - **The lane's floor was not the built floor.** The map's `Path` is the design's curve every 100 studs; the seabed
    is straight slabs. At the foot of every drop-off the two were 13 to 23 studs apart, so wild fish swam through the
    sand there. New `src/server/Lib/LaneSurvey.luau`: at startup the server drops a ray onto the seabed every 10 studs
    of the centreline and uses that as the lane (and publishes it to clients). After: within 3 studs at all but 13 of
    4,756 places checked along the centreline. Still seen: a fish near the lane's edge on a ramp in a bend can be up to
    7 studs into the sand (the lane is taken as flat from side to side; v4's slabs aren't quite).
  - **`Workspace.FallenPartsDestroyHeight` was -500 and the lane goes down to -1,622:** Roblox destroys fish and
    players below it. A game script can't change it; it is set to -20,000 in the open place by hand, the server now
    warns at startup when the lane goes below it, and the map script needs to set it.
  - Fixed: the descent is slowed before the floor instead of pushed back after it; a hitch can't carry a flight
    through a wall (frames over 0.05 s are flown as 0.05 s); the fish you left coasts in open water too; with no floor
    known a ridden fish levels out instead of nosing down; floating under the lane's floor is lifted back above it.
  - Fixed: the Oxygen refill is not given for landing back on the fish you left, nor for a landing sooner than a flight
    can be (hopping off and on the same fish refilled a quarter each time).
  - Fixed: a fish that reaches the client after the server's "mounted"; a jump the server took that the client isn't
    flying; a rider's fish left marked as taken after a respawn; three sandbox values that broke things at 0 or when
    crossed (`Ride.YawRate`, `Jump.GrabSpeed`, `Spawn.HeightMin` over `HeightMax`).
  - **Not done:** the landing's effect still makes new parts and a sound each landing (`Fx.landing`), and the poses
    build a table per player per frame (`AnimController`): performance only. The server still trusts where the client
    says it landed, within the flight's reach.
- **Grey-box 3 of the new map is in Studio (2026-11-10)** in place of blockout v4, loaded from
  `tools/studio/greybox/*.luau` (the map chat's; 4,905 parts, three lands, 4,500 studs). v4 comes back by running
  `tools/studio/claude_blockout.luau`. On it:
  - The game starts as it is: the lane's floor surveyed (over 3 studs off at 1 place of 566), fish spawn, running off
    the hub floor puts you in the water, a jump lands, a ridden fish stays in the water.
  - **The herd steers round the big obstacles** (`Zones.bigAssets`, `mindObstacles` in `FishService`, `Herd.Obstacle*`
    in Config): a fish that would pass too near one ahead moves its place across the lane, and one already inside the
    margin is pushed out. Measured: 0 wild fish inside an obstacle in 1,432 close passes (before: fish swam through).
  - `Oxygen.DockRadius` 520 to 300 for the new hub.
  - **Grey-box 4 since (the map chat's hub and texture pass, same lane):** the game runs on it; three jumps landed,
    the first from the start. `Oxygen.DockRadius` is 120 for the smaller hub (the spawn is 78 studs behind the start).
    Jumps took about 3.4 s against 2.2 on v4: the glide ended with no fish in front and the catch came in the drop.
  - **Grey-box 5 (a bigger hub, 436 by 202; the spawn 70 behind the start):** loaded, 7,198 parts. The game starts on
    it and a jump from the start landed. Seen once on that landing: the server's "fish moved too fast" warning
    (`checkSpeed`), not looked into.
  - **Hub walking speed 28** (`Config.Dock.WalkSpeed`, the user through the map chat; Roblox's own is 16): measured
    27.7 in play on grey-box 5.
  - **The ride's camera, floating and steering no longer start 10 seconds late.** `RideController.Start` waited up to
    10 s for Roblox's `PlayerModule` before binding its frame step, and in this Studio `PlayerScripts` has no
    `PlayerModule` at all. It is looked for on the side now. Fixed by reading the code; not timed in play.
- **Rojo is connected (2026-11-10):** `rojo serve` runs from this PC and the user connected the plugin, so `src/` syncs
  into Studio by itself. The push script is no longer used.
- **Modelled creatures, game side (2026-11-10), waiting on the upload:**
  - The user chose to upload the creature chat's 33 voxel creatures as meshes (one GLB each, vertex colours).
    **Nothing is uploaded:** Studio refuses until the user grants `asset:read` and `asset:write` under Assistant
    settings, MCP Permissions, and approves the folder `art/creatures`.
  - `tools/creatures/collect.py` writes `src/shared/Creatures/<Id>.json` from each export's `mesh.json`;
    `Shared.Creatures` reads them. `FishModel.fromRig` joins a model in `ReplicatedStorage.FishModels.<Id>` by them
    (a Motor6D `Rig_<part>` at each pivot); `AnimController` plays the keyed swim on those joints.
  - Tested on a block stand-in of the Reef Shark (`ReplicatedStorage.FishModels.ReefShark`, marked `StandIn`: one box
    a part): the tail sweeps 1.67 studs each way. Reef Sharks in the game are those grey blocks until the mesh is in.
  - **Uploaded 2026-11-10, on the user's word: all 33 creatures,** one GLB each as a Roblox Model asset through
    Studio's connector (Open Cloud; the user granted `asset:read`, `asset:write` and the folder). The ids are in
    `tools/creatures/assets.json`. All were approved by moderation.
  - `python tools/creatures/install.py <studio_id> [Id ...]` puts them in the place as
    `ReplicatedStorage.FishModels.<Id>`: it loads each asset, turns it half round (Roblox's GLB import turns a model
    180 degrees about up), flattens the importer's nested models, and makes the parts white SmoothPlastic so the vertex
    colours show. Part names, sizes and vertex colours came through the upload unchanged.
  - Each creature's rarity, land and size now come from its export (`Tier`, `Zone`, `Size` in
    `src/shared/Creatures/<Id>.json`; Config adds them to its fish table). Speed and Oxygen use follow the rarity, as
    for the placeholders. The six unmodelled placeholders are kept (Garibaldi, Leopard Shark, Great White for the Kelp
    Forest; Barracuda, Goliath Grouper).
  - **In play on grey-box 5:** 21 kinds spawn with their models (every creature of the Shallows and the Coral Reef,
    105 fish), swim with their keyed motion, and can be ridden (rode a Cuttlefish). The other 12 live in lands the
    map doesn't have yet, so they don't spawn. No script errors. Nobody has looked at them in play yet: Studio
    wasn't drawing for captures after the first ([the Reef Shark](attachments/creature-reefshark-in-studio.jpg)).
  - **The first uploads were too dark** (the export wrote vertex colours as linear light; Roblox shows them as
    stored). The creature chat fixed its exporter; the corrected Reef Shark was uploaded and checked against plain
    parts in the design's colours ([capture](attachments/creature-reefshark-colour-fix.jpg)) and is installed. The
    other 32 are re-exported and wait for the user's word to upload; the 33 dark assets are still in the inventory.
- **The friend's mechanics work is built on this repo's code (the user, 2026-11-11),** in his own Roblox file. Until it
  is pushed and merged the ride, jump and camera code here is left alone.
- **Grey-box 6 (2026-11-11, the map chat: every wall rebuilt as a 1-stud face with a hollow behind and grass on top):**
  the game runs on it at 59 frames a second in Studio on this PC (12,933 parts). One change was needed:
  `Ride.LaneMargin` 20 to -3. A ridden fish was allowed 20 studs past the lane's edge, which is now inside the hollow
  behind a wall face, and one got boxed in there under the grass. Now the fish and the flight stay 3 studs inside the
  edge; in the re-test it never passed the edge and stopped at the wall as it should.
- **Grey-box 7 (2026-11-11, the map chat: the lane itself changed: a straight first land, 120 to 515 wide, one smooth
  floor, a wall or rim on every edge with an unseen barrier behind):** the game runs on it with no code change.
  - The floor survey is within 0.1 stud of the built floor everywhere (985 places). 52 obstacles, read from the map.
  - The herd: 118 fish; a fish's nearest neighbour is 40 to 49 studs away on average, about the same in the narrow
    and the wide rooms.
  - Four jumps in a row landed, each with the whole 21-stud rise; they took 3.2 to 3.7 s (the catch came in the drop,
    as on grey-box 6). A ridden fish steered at a wall stopped 8 studs short of it and never passed the lane's edge.
  - The frame rate read 15 a second in this run; the run before (grey-box 6) read 59 and an earlier one 15 too, so it
    is probably Studio not being drawn, not the map. Not settled.
  - **Seen, not solved:** the first jump from the start missed in one run (the herd swims off at the flight's own
    pace, so a diver starting from rest can't catch a fish ahead); a ridden fish left alone runs into a wall or an
    obstacle and stops, because the lane winds and the fish only turns with the camera; a jump's flight against the
    obstacles is the user's open decision.
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
