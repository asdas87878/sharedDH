# Handoff

What each push changed, so whoever pulls next knows where things stand. Newest first. Every hand-made push gets an entry
here; the Obsidian Git plugin's own "vault sync" commits don't need one.

## 2026-11-12 · void (Hugo's PC): Movement pass: a longer hook, real rider animations, the startle, more juice
**State:** built and run in Hugo's Studio through `~/Projects/studio-runner` (driven by script and judged from
pictures: no keys, no mouse, no sound, so the feel by hand is still Hugo's to judge). StyLua, selene and
`rojo build` pass. Nothing uploaded. **Hugo owns the mechanics: the hold on the ride, jump and camera code is lifted
for these changes** ([Decisions](Decisions.md), four rows of 2026-11-12). The fish here are still block stand-ins
(the 82 models are private to the partner's account), so the startle on a real creature's rig is written but unseen.

- **Files:** `src/shared/Config.luau`, `src/client/Lib/Lock.luau`, `src/client/Lib/Feel.luau` (new),
  `src/client/Controllers/JumpController.luau`, `RideController.luau`, `AnimController.luau`, and rows only in
  `SandboxController.luau`. No server file changed: `FishModel`'s `MaxForce` 40,000 and `MaxTorque` 400,000 stay.
- **The hook and the lock:** `Jump.GrabRange` 130 to 180 (the server reads the same number, times
  `Net.RangeSlack`). `Lock.DistanceWeight` 0.2 to 0.07, and the new `Lock.FarAim` (5 degrees at the full range): a
  margin round a far fish that counts as aimed at it. The ring at long range is wider (`Jump.RingFar` 1.5), thicker
  (`RingGrow` 60 to 40) and turned to the camera (`RingFarFace` 0.8). **Seen:** locks taken at 158 to 176 studs,
  grabs granted by the server at 153, 135 and 116 studs.
- **The startle** (`Ride.Startle...`, 0 turns it off): a landing (not the sandbox's R) makes the fish rear for 0.8 s
  with a "!" over its head, the rider curled against its back, then it bolts. `AnimController` plays it on a
  creature's rig and on a stand-in, as one reaction named "rear"; **with the startle on it replaces
  `Animation.LandingMix`'s reactions**, which are all still there with `Ride.Startle` 0. The stall and the bolt are
  `RideController`'s speed curve for that fish: measured on a Common (ridden 45), 13 studs a second while it rears,
  71 at the bolt's peak, back to 45 about a second later. No force is added anywhere.
- **The partner's thrown-rider check, run again:** 67 landings by hop and 23 resets across all ten lands (two
  rounds, before and after the joint fix below). **None thrown:** the biggest move of the rider in one frame was
  17.7 studs (a pull-in), and the server never flagged a fish as too fast. Two hops in the deep lands found no fish
  and sank, as before.
- **The rider's animation** (`Config.Pose`): a front crawl in the hop, a breaststroke lying flat while floating, a
  crouch and push off, streamlined through the pull-in, a tuck and forward flip into the seat, and a riding pose
  that leans with speed and into turns. Written once in the body's own directions and carried into each joint's,
  so R6 works too (run once on an R6 rig: riding, crawl and float all posed, no errors).
- **Found, and it matters on both PCs: no rider pose had ever shown on Hugo's avatar.** It has Roblox's newer
  joints (`AnimationConstraint`, 15 of them, no `Motor6D`), and `AnimController` looked for Motor6Ds only, so the
  body stayed in its rest pose in every state. It takes both now. Every joint of the avatar is written each frame
  and our own tracks are stopped as they start, so Roblox's Animate script can't show through.
- **The juice** (`Config.Feel`, drawn by the new `Lib/Feel`): the view kicks wider at the pop and at the bolt;
  speed lines on the screen through the pop's extra speed, the pull-in and the bolt; a bubble trail; bubbles off
  the fish at the pop and round it at our own landing; a swish, a whoosh and a splash from Roblox's own character
  sounds (`Lib/Fx`'s "Rumble" names `action_falling.mp3`, which this Studio has only as `.ogg`: not mine to change).
- **`RideController.look(yaw, pitch)`** is new: it turns the view as a mouse drag would, for tests by script.
- **The panel (N):** new rows under `Ride` (twelve `Startle...`), `Lock` (`FarAim`), `Jump` (`RingFar`,
  `RingFarFace`), and two new groups, `Pose` and `Feel`.
- **For the tuning chat:** a landing now costs a stall. With these numbers the bolt gives most of it back (about a
  sixth of a second of travel lost a landing), but a new player has only 2.5 s on a fish: `Ride.StartleTime` and
  `StartleStall` are the rows if it is too much.
- **Not done / not judged:** the sounds were never heard; the startle and the poses were seen slowed down in
  pictures (the numbers stretched for the capture), at full speed only by their measurements; other players' dash
  shows without the flip; nothing was tried with two players.
- Pictures (Hugo's PC, not in the repo): `~/Pictures/ride-a-fish/movement-2026-11-12/`.

## 2026-11-12 · void (Hugo's PC): Hugo's place brought up to the merged game; the 82 creature models can't be loaded here yet
**State:** run in Hugo's Studio through `~/Projects/studio-runner`. StyLua, selene and `rojo build` pass on 830e028
with no merge leftovers. One file changed: `tools/creatures/install.py`. No ride, jump or camera change. Nothing
uploaded.

- **Code:** Rojo (127.0.0.1:34873) is connected here and the place has the merged `src/` (82 creature data modules,
  `RideStyles`, `Look`, the HUD's `UI` folder, five services, eight controllers).
- **Map:** grey-box 9 loaded from `tools/studio/greybox/` (106 parts files, the water, the check): 62,835 parts
  (the check expects 62,834), 1,974 asset models, 8 plots, 44,588 pictures, `DockSpawn` and `Path` present, no file
  refused. The pictures show on this account.
- **Lighting:** `ReplicatedStorage.Skies` made (`1 Place`, `2 Anime Sky`) and `tools/studio/look_install.luau` run:
  Realistic style set, the Anime Sky shown. `InsertService:LoadAsset` refused the sky in this unpublished place;
  `game:GetObjects` took it.
- **BLOCKED: the creature templates.** All 82 assets in `tools/creatures/assets.json` are private to the account
  that uploaded them (TheSyurpyPancake, 165352993). Hugo's Studio (user 8607502680) gets "Requester does not have
  permission for Asset" for every one, by `LoadAsset` and by `GetObjects`. So `ReplicatedStorage.FishModels` is empty
  here and every fish is `FishModel`'s block stand-in. **Needed from the owner's side, no new upload:** share the 82
  model assets with user 8607502680 (Creator Hub, each asset's permissions; or the Open Cloud asset-permissions
  call in one batch). Then on Hugo's PC: `python tools/creatures/install.py runner`.
- **`install.py`:** `runner` in place of a studio id runs it through Hugo's studio-runner; it tries `GetObjects`
  when `LoadAsset` refuses; a creature that fails now makes the run exit 1.
- **Played by script (the game's own `Actions.jump` and the sandbox's remote; no keys, so feel is unjudged):** R onto
  a fish, riding, a hop with a grab and a landing in the Shallows (Boxfish to Pufferfish), the Open Blue (Hammerhead
  to Sawfish) and the Underworld (Infernal Angler to Hellmaw). Each land spawned its own kinds: 11 in the Shallows,
  17 in the Open Blue, 14 in the Underworld. Server and client logs: nothing but the known
  `rbxassetid://203785492` asset-type warning. `AnimController` was only exercised on stand-ins.
- **Not saved:** a plugin can't save a place opened from a file; Hugo presses Ctrl+S. The file before this is
  `~/Projects/sharedDH-local/backups/ride-a-fish-map.1112-before-port.rbxl`.
- Pictures (Hugo's PC, not in the repo): `~/Pictures/ride-a-fish/port-2026-11-12/`.

## 2026-11-12 · 8570-F43F (the user's PC): riders thrown at a mount: the cause, and the fix
**State:** fixed and run in Studio by the game-code chat. StyLua, selene and `rojo build` pass.

- **The cause: a fish's `Swim` and `Turn` had no force limit** (`MaxForce` and `MaxTorque` were `math.huge`, in
  `src/server/Lib/FishModel.luau`). In the one physics step in which a rider's body was joined to a fish, on the
  rider's own machine as it took the fish over, that now and then threw the pair hundreds to hundreds of thousands of
  studs. It was caught frame by frame: the throw happened between the step before the physics and the step after,
  with nothing else pushing, the rider already on the saddle and every number ordinary. About one mount in five on the
  big creatures of the deep lands; rare in the Shallows. **Fixed:** `MaxForce` 40,000 and `MaxTorque` 400,000.
  **Seen after: 42 mounts across all ten lands and 26 more at the normal start, none thrown**, and every fish still
  reaches its ridden speed (60, 68, 78, 90 measured on a Rare, Epic, Legendary and Mythic).
- **This was not only the sandbox's reset.** The same join happens at every landing; the reset just made it easy to
  repeat.
- **Wrong turns on the way, for the record** (each was tried alone and did not stop it): a ride starting at a speed
  the engine misreported (a real fault, fixed, but not this one); the weld made across a distance; the floating push;
  the server moving a rider who was already seated; how long the rider had been on the saddle; how long the fish had
  been in the Workspace (four seconds looked like a cure at 1 throw in 30, which was chance); the rider's body
  touching the map. The last two were taken out again.
- **What is kept from the hunt:**
  - A ride's start speed is never more than the fish's own.
  - **The sandbox's reset seats the rider as a landing does:** the server keeps a fish and sends "SandboxMount", the
    player's machine sits the character on the saddle for 0.4 s and answers "SandboxSit", then the weld is made. If the
    pair is somewhere else a moment later, the reset is done again by itself (twice at most; not needed since the fix).
  - **R is quick:** the fish round the sandbox's start are kept in the Workspace whoever is near
    (`FishService.keepNear`). Riding begins 0.9 seconds after R at the normal start; the first reset to a NEW start
    (a changed `Sandbox.StartS`) waits 2 to 4 seconds for its fish, the next ones 0.9.
  - The server no longer moves a rider who is already on the saddle; the floating push has a force of a few times
    the character's weight and comes off before the physics step once a weld has arrived.
- **Two leftovers of the review, done:** a wild fish's place along the lane is taken from where it really is at each
  top-up (it drifted behind after detours); the ride's rays are set up again when any character appears.
- **Still not done from the review:** prop break-ups replicate up to 60 part updates a frame in a burst
  (`PropService`); a surplus fish out of sight is destroyed and a new one built, where it could be moved.

## 2026-11-12 · 8570-F43F (the user's PC): all 82 creatures are in the game; the sandbox's reset still glitches
**State:** run in Studio by the game-code chat. StyLua, selene and `rojo build` pass. Nothing committed by hand.

- **All 82 creatures are uploaded and installed** (the user's word of 2026-11-12). 81 uploads through
  `tools/creatures/upload.py` (the Reef Shark kept its asset); `tools/creatures/assets.json` has 82 ids,
  `assets_dark.json` the 32 old too-dark ones (still in the inventory), `upload_log.json` each upload. The place has
  82 templates in `ReplicatedStorage.FishModels`, each matching its data module. **Seen in play, all ten lands:** every
  land spawns its own creatures (64 kinds seen in ten samples of 28 to 44 fish), every fish has its rig and joints
  (up to 38 on one), no errors from `AnimController` or anything else.
  - **A slip to know about:** two upload runs overlapped for about five minutes (the first looked dead and wasn't).
    The asset list is consistent (every Id's asset is the one the log names), but the second run may have made one or
    two stray duplicate assets in the inventory before it was stopped, and the Kraken's first two tries failed on
    Roblox's side ("Unknown Error") before the third went through.
- **Real play, soaked:** 18 hops in a row with a watch on the rider's position: the biggest move in one frame was 18
  studs. Hands off (nobody aiming the view), 5 of 8 hops from a fish landed in the Coral Reef; the lock follows the
  view, so a player who aims should do better. To judge in play.
- **The sandbox's reset (R) is not right yet.** It was throwing the rider hundreds to hundreds of thousands of studs
  on about one reset in three. What was found and done, in order:
  1. A ride started at the fish's speed as read at the mount, which the engine can report in the thousands for a
     frame: clamped (this one could have hit real landings too).
  2. The weld was made while the rider floated 30 to 250 studs from the fish: the reset now seats the rider first,
     as a landing does (the server keeps a fish, sends "SandboxMount", the player's machine sits the character on the
     saddle and answers "SandboxSit", then the weld is made), takes only a fish that has been in the Workspace for a
     second, and keeps trying for eight seconds.
  3. The floating push now has a force of a few times the character's weight, not a million, and is taken off just
     before the physics step when a fish's weld has arrived.
  **After all that, 20 resets across the ten lands: 17 clean, 3 with a jump** (one of 650,000 studs for a frame; the
  rider ended near the start in two of the three). Riding begins 1.4 to 3.8 seconds after R, because fish near the
  new place have to come back into the Workspace first. **Not understood yet:** what still throws the pair in those
  three. Two leads: `RideController.float` lifts a floating player found under the lane's floor, and after a
  teleport its idea of where the lane is may be stale; and the fish's own `Swim` and `Turn` have no force limit.
- **Lighting at depth:** at 671 metres (the Twilight) the view is as bright and blue-skied as the Shallows
  ([capture](attachments/game-twilight-all-creatures.jpg)). The tint and fog by depth is in the map chat's queued
  plan ([water](design/water.md)), waiting for the user's go.

## 2026-11-12 · 8570-F43F (the user's PC): AnimController after the review (cost, joints cached too soon)
**State:** written, synced by the Obsidian Git plugin. StyLua, selene and `rojo build` pass. **Not run** by this chat
(Studio is the game chat's). One file: `src/client/Controllers/AnimController.luau`. The game chat's own edit
(`MOUNT_REACH`) is kept.

- **Cost:** a fish behind the camera is not moved at all (with its own length of grace). A fish past 150 studs is
  moved every second frame, past 300 every third. Each fish keeps its own clock, so its step is the time since it
  was last moved, and one that was out of view for over 0.3 s starts afresh. The ridden fish is always moved.
- **Joints:** a fish's joints are no longer kept until the first part's joint and every keyed part's joint are
  found. Until then it is tried again every 0.2 s for 5 s; after that it makes do and warns, naming the creature.
- **Not read every frame any more:** the fish folder (kept from `ChildAdded` and `ChildRemoved`) and the players
  (kept from `PlayerAdded` and `PlayerRemoving`).
- **A landing's number from the server:** the "Land" effect may carry a fourth value, a count; if it does, the
  reaction is seeded from it, so a player who joined late sees the same one. Without it each client counts.
- **Left:** the rider's pose table is still made each frame for each rider (a few players; the CFrames in it are
  made each frame anyway).

## 2026-11-12 · 8570-F43F (the user's PC): the large check, first half: an independent review and its fixes
**State:** fixed and run in Studio by the game-code chat (the herd moves, none inside an obstacle, five hops in a row
land, no errors; the server's frame is 0.7 ms with one player). StyLua, selene and `rojo build` pass. An independent
reviewer read every file of `src/` for bugs and cost; what it found, and what was done:

- **Fixed, cost on the server** (`FishService`): each fish looked at all 302 obstacles every frame (725,000 steps a
  second for 40 fish): obstacles are now kept by where they stand along the lane and a fish looks at its own 250-stud
  stretch and its neighbours. A fish's `Swim` and `Turn` were written every frame and replicate to everyone: now only
  when its way turns a degree or its speed changes half a stud a second (and twice a second regardless). The top-up
  read every player's position for each of 800 fish and walked all 250 slices: positions are read five times a
  second at most, and the slice is found by halving.
- **Fixed, traffic** (`RideService`): `Oxygen` went to every client every frame at today's drain rates; now ten times
  a second, or at once when it moves a twentieth of the meter.
- **Fixed, new fish appearing beside a player** (`FishService.spawnFish`, `Spawn.AppearClear` 160): of a few tries in
  the slice, the place furthest from every player. A player at the lane's start still sees some appear, because the
  first slice is all within reach of them.
- **Fixed, bugs:** `Ease.smoothstep` gave NaN with no width (a sandbox number could lose the character); a late
  refusal for one fish no longer stops a pull-in begun on the next (the refusal now names its fish); a landing the
  server sees out of reach is a refused grab, not a drown; with no dock spawn the rider was sent to the dock every
  frame while the character loaded; a creature file missing a field, or an unknown rarity, is left out with a warning
  instead of stopping every script; the lock looks over the herd 20 times a second, not every frame.
- **Passed to their owners:** the animation's cost per fish per frame, fish behind the camera, and joints cached too
  early (the creature chat); the HUD's speed lines and ring gradient every frame (the UI chat).
- **Not done:** a fish's place along the lane drifts from where it really is after detours (a check first: print the
  gap for old fish); the prop tweens replicate 60 parts a frame in a burst; an out-of-sight surplus fish is destroyed
  and a new one built, where it could be moved; the ray filter isn't rebuilt when another player joins mid-ride.

## 2026-11-12 · 8570-F43F (the user's PC): riders thrown thousands of studs at a mount: found and fixed
**State:** fixed and run in Studio by the game-code chat: 16 sandbox resets in a row, none thrown (before: 6 of 12).

- **What was seen:** now and then, a third of a second after mounting a fish, the rider and the fish were somewhere
  else entirely: 1,150 studs up, 750 under the map, once 10,000 studs away. The server's log: the pair sat right at
  the mount, then jumped together, with "fish moved too fast".
- **The cause** (`RideController.onMounted`): a ride carries on at the speed the fish was swimming, read from the
  fish's Root at the mount. In the frame the fish's body joins the rider's, the engine can report a speed in the
  thousands, and the ride then started at that speed along the fish's nose. **Fixed:** the start speed is never more
  than the fish's own ridden speed, and the start pitch never more than 35 degrees. This was not only the sandbox's
  reset: any mount could have hit it, a landing too.
- **Also changed on the way:** the sandbox's reset now waits a third of a second before mounting, so the player's
  own machine has moved the character to the lane first (`RideService.sandboxReset`); and the rider's body follows
  the fish's motion only when that fish is within 40 studs (`AnimController`, `MOUNT_REACH`): for a few frames round a
  mount it could name a fish far away. Neither was the cause, both are kept as guards.
- **The pull-in's dots** have their own deeper yellow (`Jump.DotGlow`): in the ring's colour they bloomed to white
  blobs under the new lighting.

## 2026-11-12 · 8570-F43F (the user's PC): a training spot, all 82 creatures on their way in, and a Config clash
**State:** written and run in Studio by the game-code chat; StyLua, selene and `rojo build` pass. The uploads were
running when this was written.

- **Training** (new `src/server/Services/TrainService.luau`, `RideService.train`, `Config.Train`): a pad in the hub;
  standing on it adds `Train.Rate` (4) to your max Oxygen every second, kept for the session (no saves). The pad is
  the map's part named `TrainSpot` under the hub when it has one; until then a stand-in disc is made at run time
  70 studs to the right of the dock's spawn and 24 toward the water. The player's `Training` attribute is true while
  gaining. Seen in play: 100 to 120 in 5 seconds, and it stops when you step off. `Train.On` 0 takes it out.
- **Creatures:** `tools/creatures/collect.py` wrote all 82 data files. The five placeholder fish are out of Config's
  table; the Bobbit Worm is kept out of the herd (`NO_SPAWN`, Reach -1) until it is in the roster; Secrets have no
  land's mix, so they don't spawn. The uploads (81 models) go through `tools/creatures/upload.py`.
- **A clash, fixed:** the creature chat's rewrite of `Config.Animation` removed the whole `Config.Look` block, so the
  lighting controller and the N panel errored at start. Restored from the last sync, above the Animation comment.
  Four chats edit `Config.luau`: small exact edits only.
- **`MaxOxygen`** on the player is rounded to a tenth now (training makes it a fraction).
- **Tools:** `tools/studio/sync_src.py` sends the creature data too, in batches.

## 2026-11-12 · 8570-F43F (the user's PC): the dive's HUD rebuilt from the UI plan (pass 3), not run yet
**State:** written by the UI chat, synced by the Obsidian Git plugin. StyLua, selene and `rojo build` pass. **Not run
and not type-checked.** The game-code chat runs it first.

- **What:** `HudController.luau` rewritten, and nine new modules in `src/client/UI/`. The HUD now follows the
  reference's riding screen: the strip of lands on top, a ring with the seconds left on this fish beside the rider,
  the jump button at the lower right, a tag on each of the nearest wild fish, your Oxygen as a stat row. Detail and
  the choices taken: [UI](design/ui.md), "Piece 2".
- **Gone:** the Oxygen bar, the rate and the speed beside it, the depth gauge, the bracket on the locked fish.
- **Waiting on the game code:** the server's own rate for the ring (`State.Drain`), the locked fish's seconds
  (`State.LockSeconds`), Roblox's jump button hidden on touch. It runs without them.
- **Nothing uploaded.** No pattern and no picture signs until the user says yes to uploads.

## 2026-11-12 · 8570-F43F (the user's PC): the creature chat's side of the import of all 82 is ready
**State:** written, synced by the Obsidian Git plugin. StyLua, selene and `rojo build` pass. **Not run:** no type
check on this PC and Studio is the game chat's, so the animation has not played in the game. No upload by this chat.
The user's word, passed on by the game chat: import all the models and all the animations, with a mix of landing
types. Files: `art/creatures/BlueWhale`, `tools/creatures/import_plan.json`, `src/shared/RideStyles.luau`,
`src/client/Controllers/AnimController.luau`, `Config.Animation`, five rows on the N panel.

- **The exports:** all 82 present, each with one `<Id>.glb` and `<Id>.mesh.json`, a seat, swim keys and a size.
  Every vertex colour in every GLB is one of its palette's colours, so none is a too-dark export. The Blue Whale's
  files were named `BlueWhaletheoldone` (its `NAME` said "the old one"): renamed in `voxel.py`, exported again, the
  old files deleted. The plan: 49 new uploads, 32 again, 1 as it is ([creature import](design/creature-import.md)).
- **Rarity and land:** all 81 roster creatures' exports agree with [the roster list](design/roster-list.md).
- **The animation is the Swim Lab's**, the preview the user tuned over 2026-11-11 and 12 (its "Lively, balanced"
  set), carried into `AnimController`, all of it seen only:
  - **A slow wave** for each body type (`RideStyles.Waves`, `Animation.Wave`): the stroke, the height, a drift to
    one side and a lean, on one rhythm of 3 to 7 seconds that swells and fades. A small fish shows about half.
  - **Landings** (`RideStyles.Landings`, `Animation.Wild`, `LandingMix`): the dip at the touch, then one of seven
    reactions (startle, buck, thrash, bolt, wobble, shudder, barrel roll) that builds from the touch and falls off
    over about two seconds. `LandingMix` 2 is the user's mix: the body type's own most often, its second often, now
    and then any of the seven. Each client seeds the pick from the rider's id and its count of their landings.
  - **Side fins in a turn** (`RideStyles.Fins`, `Animation.FinTurn`): tilt, sweep and a wider stroke on the outside.
    Only the 48 creatures with separate side parts show it.
  - **A calmer rider** (`Animation.RiderCalm`): they take the body's shift eased and at half its turning; thrown
    off the seat by a buck; arms and legs flung about while the animal fights.
  - **A steadier beat:** it changes over a moment and by little; small fish beat slower; the per-beat body sway is
    smaller on a small fish and a quick beat. The landing's dip and the rider's squash now swing in from nothing.
- **Not carried over, because they need the Root to move** (`RideController`, the server; not handed to this chat):
  the wave's 1 to 3 per cent change of speed, the bolt's burst of speed (the body lunges ahead instead), the surge
  waiting for a landing's build-up. **And eyes that look about:** `FishModel` welds each `<Part>_Glow` to its part.
- **To check in play:** that nothing errors in `AnimController` (it runs every frame for every fish near the
  camera); a landing on a small fish, a shark, a turtle and a whale; the rider through a barrel roll.

## 2026-11-12 · 8570-F43F (the user's PC): the locked fish's mark as the reference's, and hooks for the HUD
**State:** written and run in Studio by the game-code chat; StyLua, selene and `rojo build` pass.

- **The locked fish** (`JumpController`, `Config.Jump`): its glow is one flat yellow-orange, nearly solid
  (`GlowFill` 247, 190, 62; `FlyGlow` 0.6 to 0.12), with a black outline (`GlowOutline`; it was pale yellow). The
  ring and the pull-in's dots keep the brighter yellow (`Glow`). Seen in play: off while riding, on at the hop with
  those values.
- **Nothing is marked while you ride** (`Lock.Preview` 1 to 0), as in the reference (read from the user's recording
  of 2026-11-10; the row is in [Decisions](Decisions.md)). The N panel's `Lock.Preview` row puts it back.
- **For the HUD (the UI chat):** the server publishes `Drain` on the player, the Oxygen a second the fish under you
  takes as the server counts it (0 off a fish), so seconds left = Oxygen / Drain; `State.secondsOn(fish)` gives how
  long a full meter would last on any fish where it swims; `Actions.jump()` is the hop and the grab.
- **New tools:** `tools/studio/sync_src.py <studio_id>` puts every script of `src/` into the open place while the
  Rojo plugin is disconnected; `tools/creatures/upload.py <studio_id>` uploads the creature models of
  `import_plan.json` through Studio (permanent: on the user's word, given 2026-11-12 for all 82), writing
  `assets.json` as it goes and carrying on where it stopped.

## 2026-11-12 · 8570-F43F (the user's PC): a character appears on the dock from its first frame
**State:** written and run in Studio by the game-code chat; StyLua, selene and `rojo build` pass. One file:
`src/server/Services/RideService.luau`.

- **What happened:** the user pressed Play while the map was half loaded (no `DockSpawn` yet) and stood on Studio's
  default `Workspace.SpawnLocation`, on the grey Baseplate at the origin, 3,000 studs from the map. With the map
  whole, a character still appeared there for a moment before the server stood it on the dock.
- **Now:** when the server finds the dock's spawn it moves every `SpawnLocation` in Workspace onto it and makes it
  unseen and non-solid, for that run only. Seen in play on the reloaded map (the hub in its new colours): the
  character's first position was the dock's spawn, the view faced the water, no errors, and a ride lasted 2.50 s on
  100 Oxygen.
- **Not changed:** the place itself. The default SpawnLocation and Baseplate are still in it; deleting them is the
  user's call. With no `DockSpawn` at all (a half-loaded map) the default spawn is still where you land.

## 2026-11-11 · 8570-F43F (the user's PC): the tutorial's lighting, tweakable, and its sky
**State:** written and run in Studio by the game-code chat; StyLua, selene and `rojo build` pass. **Not seen by eye:**
Studio's window wasn't being drawn, so it was checked by its numbers in play (every value on, no errors, the sky
shown). The note: [lighting](design/lighting.md).

- **New:** `Config.Look` (the numbers), `src/shared/Look.luau` (puts them on Lighting and two effects of our own),
  `src/client/Controllers/LookController.luau` (keeps them while playing; all on the player's own machine),
  `tools/studio/look_install.luau` (the same in Edit mode, plus LightingStyle Realistic, which a game script can't
  set), and 24 `Look` rows on the N panel. `Look.On` 0 shows Roblox's plain lighting to compare.
- **In the place (Studio-owned, not in the repo):** `ReplicatedStorage.Skies` with `1 Place` and `2 Anime Sky`
  (Creator Store asset 72835926026092, the Sky only), and Lighting set by the installer. **Hugo's place needs** the
  installer run once and a `Skies` folder, or it keeps its own sky and a Soft style with the rest of the look.
- **Left out on the user's word:** the tutorial's last step, a `Highlight` on the character (a black outline and a 20%
  black wash).
- `tools/studio/push_scripts.py` now also makes a script that isn't in the place yet.
- **This replaces** the agreement that the game code never sets Lighting (map-structure.md, "Still different", 1).


## 2026-11-11 · 8570-F43F (the user's PC): animation is tried in a preview page now, not in the game
**State:** no change to `src/` or to Studio. The user's word: two chats changing the game at once got confusing, so
until the other chat stops making changes, this chat (creatures and animation) stays out of `src/` and out of Studio.

- **The Swim Lab:** a private page, <https://claude.ai/artifact/PxpF8Mdhxbh5mrcE21GXQE>, that plays any of the 82
  creatures in 3D from their exports with the same steps as `AnimController`'s layers. Five feel sets (keys only, the
  first slice as built, lively, heavy, arcade), four ride patterns (rail, undulate, surge and glide, weave, or by body
  type), a rider, a small herd, and buttons to turn, land, crash and buck. Every number is a slider.
- **What is only in the page, not in the game:** the ride patterns other than rail, the beat multiplier, the bank by
  body type and the herd's weave. The first slice of this morning is still in `src/` as it was.
- **Next:** the user picks a feel from the page; its numbers then go into `Config.Animation` and `Shared/RideStyles`
  in one go, when the other chat is no longer editing.

## 2026-11-11 · 8570-F43F (the user's PC): the Oxygen numbers are seconds on a fish now
**State:** written, synced by the Obsidian Git plugin. StyLua, selene and `rojo build` pass. **Not played, not
type-checked.** By the tuning chat, on the user's answer of 2026-11-11 ([Decisions](Decisions.md), top row). Studio's
sandbox starts with Endless air on, so nothing is felt until that is switched off. The note:
[progression](design/progression.md).

- **A landing refills the whole meter:** `Oxygen.Refill` 0.25 to 1. Every fish starts full, as the reference's ring
  is the time left on this dino. Seconds on a fish = max Oxygen / (`ZoneDrain` x `RarityDrain`).
- **`Oxygen.KeepUp` 6 to 2:** it now means the seconds on a fish that count as enough, so the HUD's "needs" and a
  fish's tag show the Oxygen for 2 seconds on it.
- **`ZoneDrain`:** 1, 4, 14, 48, 160, 500, 1,500, 4,500, 13,000, 36,000 to 40, 160, 480, 2,000, 6,000, 24,000,
  60,000, 240,000, 1,000,000, 4,000,000. The starting 100 lasts 2.5 seconds on a Shallows Common; each land takes 2.5
  to 4 times the land before.
- **`RarityDrain`:** 1, 1.15, 1.3, 1.45, 1.6, 1.75, 1.9 to 1, 1.25, 2.5, 4.5, 15, 50, 150. Gentle to Epic, steep from
  Legendary; Rare to Legendary follow the reference's required stamina in one zone.
- **What that makes:** a new player has 2.5 s on a Shallows Common, 2 on an Uncommon, 1 on a Rare, and is thrown off
  an Epic or a Legendary at once. A dive is about 15 seconds (played: 15.6 s, 1,141 studs): the Shallows, five
  fish long, ending on the first fish of the Coral Reef. (This entry first said 40 seconds, from a model whose
  rider hopped faster than a player can; corrected the same day.) To try a deeper land set Workspace's `TestMaxOxygen`: 500 for the Coral Reef, 3,000 for the Kelp Forest,
  12,500 for the Shipwrecks.
- **On the N panel:** the `ZoneDrain` rows' steps fit the new sizes; `KeepUp` steps by 0.25.
- **Not changed:** the speeds (proposed in the note: 54, 58, 62, 67, 74, 82, 90, on the `TierSpeed` rows), the
  shares by rarity, and everything in the hop.
- **The model:** `python tools/balance/model.py` reads `Config.RarityDrain` and prints seconds on a fish by land and
  rarity; `--max 3000` does it for a trained player.

## 2026-11-11 · 8570-F43F (the user's PC): the first slice of the animation study is built, not played
**State:** written, synced by the Obsidian Git plugin. StyLua, selene and `rojo build` pass. **Not played and not
type-checked** (no luau-lsp here, and Studio was not connected): expect numbers to tune and possibly bugs. The study:
[animation study](design/animation-study.md). Files: `src/client/Controllers/AnimController.luau`, new
`src/shared/RideStyles.luau`, a new `Config.Animation` group, 21 rows on the N panel. No server change, no upload.
`RideController` is not touched.

- **Everything is seen only.** Each layer turns or shifts joints of the fish, never its Root, so the Saddle, the lock,
  the pull-in and the server's checks are as they were. Every layer has a row that turns it off at 0.
- **Effort** (`Effort`, `EffortAccel`, `EffortBeat`, `LandEffort`): the swing and the beat rise when a fish speeds up or
  is landed on, and ease when it coasts.
- **The turn layer** (`Turn`, `TurnLead`, `TurnBend`, `TurnMax`, `TurnTotal`, `WildBank`): the tail joints trail a turn
  and come round late; the head leads (most creatures' first part is the head, so the whole body is turned a little
  ahead instead); wild fish roll into bends. The chains are found from each creature's `Parts`: checked by script on
  the 33 creatures in the game (the Anglerfish's rod and the octopus's arm chain are picked up too, harmlessly).
- **The body layer by style** (`Body`; nine styles in `Shared/RideStyles`, all 82 creatures assigned): a heave, a nod,
  a sway and a rock each beat, as one shift of the whole body about the Root. `Cadence` 1 sets the beat's rate by
  style (a turtle strokes at 0.6 of what its length gives, a jetter at 0.45).
- **The landing** (`LandDip`, `LandNod`, `LandDipTime`): the fish sinks under the rider and springs back, a small fish
  further. It is seen only, not the real dip in `drive` the study proposed, to stay out of `RideController`.
- **The rider goes with the body** (`RiderFollow`): the same shift is put on the rider's Root joint, so they ride the
  heave, the dip and the buck. The seat part's own keyed swing (the Basilosaurus's back under you) is NOT followed yet.
- **The brace** (`Brace`): arms up and knees folded for a moment at a landing.
- **A jaw** hangs nearly shut and opens now and then (`Jaw`), instead of chomping every beat.
- **A crash** makes your own fish rear and shake (`CrashFlinch`).
- **Fixed on the way:** the buck was multiplied onto the first joint's last value, which piled up on creatures whose
  first part has no keys (Cuttlefish, Octopus, Kraken, Anomalocaris, Elasmosaurus). The joint is now written afresh.
- **To judge:** the list at the end of section 5 of the study. Set a row to 0 and back to see what its layer adds. Count
  hops landed out of ten with the layers on and off: it should not change.
- **Not done from the slice:** the buck's numbers and the swim's base rate are still literals in `AnimController`.

## 2026-11-11 · 8570-F43F (the user's PC): the tuning chat's first turn: a balance model, the progression note, panel rows
**State:** written, synced by the Obsidian Git plugin. StyLua, selene and `rojo build` pass. **Not played, not
type-checked. No tuning number changed:** every speed, share and Oxygen number is as it was.

- **The model:** `python tools/balance/model.py` reads Config, the creature files and the map's path, and prints, land
  by land, the length, the seconds to cross, the Oxygen needed, the fish by rarity and the creatures. `--sim 8` plays
  dives through the herd's stocking rules. `--set Oxygen.TierDrain=1` tries a number without touching the game.
- **The note:** [progression](design/progression.md): the tables, what is off with a proposed value for each, what
  isn't built, and six questions for the user. All of it is proposed.
- **The three findings:** a new player's dive is 75 seconds and ends at the third land's door, with no way yet to grow
  max Oxygen; a rarer fish costs almost nothing more, so nothing is out of reach to chase; and hopping without
  stopping makes every land 20 times cheaper in Oxygen.
- **In `src/`:** `Config.TierSpeed` and ten names for `Config.ZoneMix`'s rows (both only so the panel can reach those
  numbers), five lines in `Config.refresh` so a changed speed reaches fish already swimming, and rows on the N panel:
  the speed of each rarity, `Oxygen.StartMax`, and each land's shares by rarity.
- **Not live yet:** `Oxygen.StartMax` from the panel doesn't reach a player already in the game (use Workspace's
  `TestMaxOxygen`). The fix is in the game-code chat's files; it is in [Sessions](Sessions.md), Notes.

## 2026-11-11 · 8570-F43F (the user's PC): the creature import is prepared, nothing uploaded
**State:** written, synced by the Obsidian Git plugin. No upload, no change to `src/` or to the place.

- **The plan and the steps:** [creature import](design/creature-import.md). With no picks made: 49 new uploads, 32
  uploads again (the too-dark ones), the Reef Shark as it is.
- **The user picks by hand** which creatures go in, on a picker page (every creature's picture, a tick each). The picks
  land in `tools/creatures/picks.json`; `python tools/creatures/plan_import.py` turns them into
  `tools/creatures/import_plan.json`. Both files are new; `collect.py`, `install.py` and `assets.json` are untouched.
- **For the chat doing speed, rarity, sizes and spawns:** a creature in `leftOut` of the plan is not coming; the variants
  and the Secrets have no spawn rule yet.

## 2026-11-11 · 8570-F43F (the user's PC): the game on grey-box 9, the view faces the water, and the tuning chat's first turn
**State:** written and run in Studio by Claude (StyLua, selene and `rojo build` pass). Not committed by hand. **Studio
was restarted, so the Rojo plugin is not connected:** the changed scripts were put into the place directly, and the
user needs to press Connect in the Rojo plugin again (the server still runs on port 34872).

- **Grey-box 9 (the map chat: 8-stud squares, a 480 by 256 hub, a rounded mouth 248 wide at the lane's start):** the
  game runs on it. The floor survey is within 3 studs at all 2,941 places checked; 302 obstacles read. Riding at full
  speed in open water (52 to 54 on an Uncommon); of four hops in the Coral Reef three landed. Hands off with the real
  rules on 100 Oxygen, a fish went straight down the first land: across the Shallows in 20 seconds with one crash, and
  down to 31 Oxygen 28 seconds in, 480 studs into the Coral Reef (four crashes by then, 3% each).
- **Fixed: a new player started with their back to the water.** On the dock Roblox's own camera kept the direction it
  had before the server stood the character on the dock's spawn, so the view looked at the hub and the character faced
  the camera; a fish mounted like that swam back at the hub, because the movement follows the view. The server now
  publishes the dock spawn (`Dock` attribute on Remotes) and `RideController.faceWater` brings the view round behind
  the character every time it is put on the dock (a spawn, and the return from a dive). Seen in play: the view looks
  down the lane at the start.
- **`Oxygen.DockRadius` 120 to 165** for the new hub: the spawn is 104 studs behind the start and the mouth is 248
  wide, so 165 covers the mouth's corners and the first 60 studs of water in the middle.
- **The tuning chat's first turn, checked** ([progression](design/progression.md), `tools/balance/model.py`): its code
  is rows on the N panel and what carries them (`Config.TierSpeed`, ten names for `Config.ZoneMix`'s rows, five lines
  in `Config.refresh`). In play: `TierSpeed.Common` set to 70 moved the wild Commons to 59 or 60 at once (0.85 of 70).
  No tuning number changed. Its six questions wait for the user.
- **`Oxygen.StartMax` is live on the panel** (the tuning chat's ask): `RideService.readMax`, called by
  `SandboxService` when that row changes. Seen: 500 and back to 100 showed on the player at once.
- **Not measured:** a whole first dive with hops (the model says 75 seconds, ending just inside the Kelp Forest). It
  needs steering through the bends, which the connector can't do: for the user's own play, with "No fail" and
  "Endless air" off.

## 2026-11-11 · 8570-F43F (the user's PC): the hop matched to the reference, and the movement follows the camera
**State:** written, synced by the Obsidian Git plugin. StyLua, selene and `rojo build` pass. **Not played, and not
type-checked** (no luau-lsp on this PC): expect numbers to tune and possibly bugs. The user's brief after playing
Movement v3.1: match the reference's hop one to one for now, and make the movement follow the camera. Files:
`RideController`, `JumpController`, `Config` (Ride, Jump, Camera), `SandboxController`.

- **This turns four of Hugo's answers of 2026-11-11 back**, on the user's word; each is one number, so either way can
  be played from the N panel. The rows are in [Decisions](Decisions.md). For the two of you to settle.
- **The movement follows the camera** (`Ride.CameraSteer` 1, new `RideController.steer`): the fish, the hop and the
  float come round to where the view looks, at `SteerEase` 6 and never faster than `SteerRate` 140 degrees a second.
  A and D still turn the view, so they steer as before; now a drag, a stick, and the mouse in the hop steer too. The
  bank follows the real turn. `CameraSteer` 0: only A and D steer (Movement v3.1).
- **The pull-in starts by itself** (`Jump.AutoGrab` 2): when the glide ends the locked fish pulls you in, and with none
  locked then, the first one locked in the drop does. A press still grabs sooner. The reference: the pull-in begins
  about 1.7 s after the press. `FloatTime` 1.4 to 1.3 so ours does too (0.4 + 1.3). `AutoGrab` 0: press only.
- **You hang with the herd in the glide** (`Jump.AirShare` 0.85, new): the glide's speed is 0.85 of the ridden speed
  of the fish you left (the reference: 46 against 54), 38 from floating (`FreeAirSpeed`). It was 54 for every fish, so
  you flew past the fish beside you. The drop slows by the same share as before. `AirShare` 0: `AirSpeed` 54 again.
- **The view tilts down in the hop again** (`Camera.AirRest` 1; the reference's camera lifts to look down from
  behind), until you move it, and now comes back up to the riding view at the landing if you never touched it. With
  the lock aimed by the view this matters: at the riding tilt of -12 the aim meets the herd about 100 studs ahead, so
  far fish took the lock; at -30 it meets it about 45 studs ahead.
- **Not changed:** the pop (0.4 s, 20 studs: the user's own height of 2026-11-10; the reference's is about half as
  high in 0.3 s), the launch (1.6 times for 0.75 s), the window (3.0 s), the pull-in's curve and speed, the landing's
  camera, the lock's 130-stud reach, the server.
- **To judge in play:** after a landing the fish turns to where you look, so landing while looking across the lane
  swings it that way; whether 38 to 45 in the glide feels slow again (Hugo found it so: raise `AirShare`); whether a
  pull-in from 100 studs or more by itself looks wrong (the reference's are 15 to 22 m: lower `GrabRange`).

## 2026-11-11 · 8570-F43F (the user's PC): a steadier lock-on, after the user played Movement v3.1
**State:** written, synced by the Obsidian Git plugin. StyLua, selene and `rojo build` pass. **Not played:** the
numbers are a first guess for the user to judge. Files: `src/client/Lib/Lock.luau`, `Config.Lock`, two rows on the N panel.

- **What the user said:** the lock is better than before, but it switches onto too many fish, they are too close
  together and it is hard to pick one; the reference feels more automatic and closer to what you mean.
- **`Lock.EdgeAim` 1 (new):** "off the aim" is now measured from the fish's nearest edge, in degrees as a share of half
  the `Cone`. It was measured from the fish's middle as a share of that fish's own allowance, which is wide for a near
  fish, so near fish off to the side scored well and kept taking the lock. Now the fish nearest the middle of the view
  wins, and a fish the aim passes through scores 0. `EdgeAim` 0 gives the old score back.
- **`Lock.SwitchTime` 0.15 (new):** a better fish must stay the better one this long before it takes the lock, so a
  fish crossing the view for a moment doesn't. 0 is as before.
- **Stickier:** `Sticky` 0.2 to 0.35 (with `EdgeAim`, 7 degrees of aim), `MinHold` 0.3 to 0.45, `KeepCone` 1.4 to 1.6.
- **To get Hugo's lock back exactly:** `EdgeAim` 0, `SwitchTime` 0, `Sticky` 0.2, `MinHold` 0.3, `KeepCone` 1.4.
- **Still to come, the user's order:** speed and camera shake, then optimising, then bugs and the parts that aren't
  movement, then optimising again.

## 2026-11-11 · 8570-F43F (the user's PC): every roster creature has a model; Studio here now runs Hugo's movement
**State:** pushed by hand (`13de842`). Nothing uploaded to Roblox.

- **Creatures:** the last 18 (the eight variants and the ten Secrets) are built, pass the gate and are exported, so all
  81 creatures of [the roster](design/roster.md) have a model: 82 in [the creature queue](design/creature-queue.md) with
  the Bobbit Worm. All but the first 14 are first drafts seen only on batch sheets. The user's word: these are what the
  game uses for now; polish, more creatures and the texture pass come later.
- **Not in the game:** 49 of the 82 were never uploaded, and 32 of the 33 uploaded ones are still the dark versions.
  Uploads are permanent and wait for the user's word.
- **Movement v3.1, the feel pass and the missed-hop fix are in the place on this PC.** Checked in Studio: all 27 scripts
  under `src/` are the same length in the place as in the checkout, `PropService`, `Lock` and `Spring` included. The
  merge kept this PC's map numbers (`Spawn.MaxTotal` 800, `BandMax` 200, `Ride.LaneMargin` -3, `Oxygen.DockRadius`
  120, `Dock.WalkSpeed` 28). StyLua, selene and `rojo build` pass on the merged code.
- **The place has what the new code looks for:** `Workspace.ClaudeBlockout.Lane.Props` (1,974 children) and
  `FallenPartsDestroyHeight` -20,000.
- **Not done:** nobody has played Hugo's movement on this PC's ten-land map. His tests were on a three-land place.

## 2026-11-11 · Ivy (Codex, Hugo's PC): unattended feel-pass check; missed-hop message fixed
**State:** two Studio playtests through studio-runner, then stopped to leave Studio idle. All 27 runtime scripts
matched the checkout before testing and again after the fix. StyLua, selene and `rojo build` pass. No ride/jump/camera
or server mechanics changes: the partner's rework stays untouched. Full check: [playtest record](playtests/2026-11-11-away.md).

- **Tested:** reset onto a fish; visible locked-fish dashed ring (lock sampled at 128.9 studs); pop/glide/drop;
  two grabs/landings (about 0.65 s pull-in, landing camera roll); no Oxygen drain in the hop and refill from 88.2 to
  100 at landing; prop collision and rebuild; missed-hop drown; actual Oxygen depletion, throw-off and dock recovery.
  Crash-free intervals gave about 4/s in Coral Reef and 14/s in Kelp Forest on a Common. This open place has three
  zone markers, not the ten-land map mentioned in Sessions. No map rebuild was done.
- **Fixed:** missed hops said OUT OF AIR with 99/100 Oxygen. `HudController` and `DeathController` now use the existing
  `DeathQuick` flag to show MISSED THE FISH for a miss; actual depletion still says OUT OF AIR. Both warning and fade
  checked in a fresh playtest, and the dock recovery still works.
- **Evidence:** `/home/hugo/Pictures/ride-a-fish/away-2026-11-11/`, screenshots plus two telemetry/output logs. Prop
  before/after pictures use temporary three-box fixtures hit through the real ridden-fish collision path; all three
  returned exactly home and solid. Fixtures and driver disappeared when Play stopped.
- **Delivery blocked:** every `discord_deliver` attempt returned "no Discord thread" for this mission; no screenshots
  were posted to Discord. Shared in NULLROOM with `share_file`; the boss/reviewer can forward them to the intended thread.
- **Still observed:** asset-type warning for `rbxassetid://203785492` (not in src); LaneSurvey's one missing and one
  inaccurate floor sample. A speed-check warning during the deliberate inter-zone teleport is a test artifact.
- **Human hand-play still needed:** free-camera comfort, aiming/steering and exact range boundary, gamepad/mobile,
  lag and two-player grabs. Scripts establish behavior, not feel. The known breakable-floor and wanted-speed HUD
  observations remain unchanged.

## 2026-11-11 · void (Hugo's PC): Feel pass after Hugo played v3.1: faster air, a free camera, a longer hook, the ring back, a landing shake
**State:** written, not committed by hand (the Obsidian Git plugin syncs it with Movement v3 and v3.1 below). StyLua,
selene and `rojo build` pass. Played in Studio by script through the runner (the same driver as the entry below, no
keys and no mouse): the numbers below are the game's own. **How it feels is still Hugo's to judge**, most of all the
camera, which a script can't move. Hugo's five points are in [Decisions](Decisions.md). Files: `src/shared/Config.luau`,
`JumpController`, `RideController`, `SandboxController`. Pictures (Hugo's PC, not in the repo):
`~/Pictures/ride-a-fish/feel-pass-2026-11-11/`.

- **Faster air** (`Config.Jump`): `AirSpeed` 38 to 54, `DropSpeed` 30 to 42, `Launch` 1.4 to 1.6, `FreeLaunch` 55 to
  78. The pull-in: `GrabSpeed` 55 to 95, `ReelMax` 0.8 to 0.7. The window, the heights and the drop are unchanged
  (3.0 s, 20 up, 12 down). Seen: off a Common at 45 the pop is 72 st/s, the glide 54, and a 3 s hop covers about 150
  to 200 studs (it was about 110); you now leave the fish beside you behind, so the fish you grab is one ahead.
- **The camera is yours** (`RideController`, `Config.Camera`): the settle behind a new fish is gone
  (`Switch.CameraSettle` deleted), and so is the hop's tilt to 30 degrees down and its swing behind you (`AirRest` 1
  gives the tilt back). The view still turns with A and D. Left alone for `LookBack` (4 s, was 1.2) it drifts back
  behind you at `Recentre` 1.2 (was 3); `AutoRecentre` 0: never. A hop and a landing count as touching it. New: a
  gamepad's right stick looks round (`StickSensitivity`); there was no stick look at all. Seen: the view's tilt stayed
  at -12 through every hop; after a landing the view held for 4 s, then came round over about 2 s.
- **The hook: 130 studs** (`Jump.GrabRange`, was 85). `Lock.DistanceWeight` 0.35 to 0.2 so a far fish you aim at still
  beats a nearer one off to the side. `Net.RangeSlack` 1.1 to 1.2: at the new air speed the server refused a grab at
  exactly 130 studs ("Denied Grab Range") with 1.1; with 1.2 grabs at 130 land. Seen: locks at 95 to 130 studs
  without touching the view, pull-ins of 0.70 to 0.77 s from 80 to 130 studs.
- **The partner's ring is back, on the locked fish** (`JumpController`, `Jump.Ring...`): the 16 yellow neon dashes of
  2026-11-10 (`git show e72fbe4:src/client/Controllers/JumpController.luau`, `placeRing`), which lay flat under the
  rider at radius 20, now lie round the locked fish at radius 15 (wider for a fish longer than that). Added so it reads
  on a fish 130 studs off: it is tipped a third of the way toward the camera (`RingFace`; 0 is flat as it was), the
  dashes thicken with distance (`RingGrow`), they turn slowly (`RingSpin`; 0 is still as it was), and the ring glides
  from one locked fish to the next. Fainter while you still ride. The fish's own glow stays but fainter (`FlyGlow` 0.6,
  `PreviewGlow` 0.85). The HUD's square bracket on the fish is still there (`HudController`, not touched): with the
  ring it may be one mark too many.
- **The landing shakes the camera** (`RideController.shake`, `Jump.LandShake...`): thrown about 0.9 studs with 2.2
  degrees of roll, 16 times a second, gone in 0.38 s, on top of the dip (`LandKick`) and the view's snap. Scaled by
  the pull-in's speed (distance over time): 0.8 times at 40 st/s, 1.3 times at 140. Seen: the camera rolled 0.9 to
  2.8 degrees at the landings measured.
- **All of it is on the N panel.** New rows: Jump `LandShake`, `LandShakeTime`, `LandShakeRate`, `LandShakeRoll`,
  `LandShakeAt`, `LandShakeBySpeed`, `RingRadius`, `RingGrow`, `RingFollow`, `RingSpin`, `RingFace`, `RingPreview`,
  `FlyGlow`; Camera `AutoRecentre`, `AirRest`, `StickSensitivity`. Gone: Switch `CameraSettle`.
- **To judge in play:** with nothing bringing the view round, you can land on a fish while looking across it and ride
  that way for 4 s unless you drag the view (on a fish the mouse looks only with the right button held). If that is
  worse than the pull was, lower `Camera.LookBack`. At 54 st/s the hop outruns the herd (38), so there are stretches
  of "FIND A FISH" with nothing locked until a fish ahead comes into the aim.
- **Not updated:** [riding feel](design/riding-feel.md) and [sandbox](sandbox.md) still give the old numbers and the
  old camera (not this task's files).

## 2026-11-11 · void (Hugo's PC): Movement v3.1 played by script on grey-box 5; one fix (the land between two lands)
**State:** one file changed (`src/shared/Zones.luau`), not committed by hand. StyLua, selene and `rojo build` pass.
Played in Studio through the new runner (`~/Projects/studio-runner/`, Hugo's PC only), with a temporary script calling
the game's own `Actions.jump`, the sandbox remote and `RideController.moveVector` (steering): no keys, no mouse, so
the feel is still unjudged. Pictures: `~/Projects/sharedDH-local/shots/` (Hugo's PC, not in the repo).

- **Seen working, with the server's own numbers:** R onto a fish; the hop (pop, glide, drop; 3.0 s); the lock and a
  grab (the pull-in took 0.87 s, landed, refill); a miss with No fail off (the 2.8 s drown, then the dock); a wall
  crash square on (speed to 0.45, 10 Oxygen of 100) and none while sliding along it for 7 s; props knocked loose (3%
  each time, 1 to 15 boxes) and home again about 9 s later; the drain by land (1, 4.6 on an Uncommon in the Reef,
  16 in the Kelp Forest); a hop at 5 Oxygen taken, no drain in the window, +25 on landing; riding dry: thrown off,
  the 5.5 s drown, the dock.
- **Fixed: `Zones.locate` found no land between two lands** (grey-box 5's zone boxes don't meet end to end: s 1100 to
  1330 and 3540 to 3770), so the server drained at the Shallows' rate there and the HUD lost the land's name. It now
  gives the nearer land; before the first land it is still none (the dock).
- **Not exercised:** aiming the lock with the mouse, a press with nothing locked, a refused grab, two players, lands 4
  to 10 (the map is built to s 4500: `R` past that puts you at the lane's end; the deep drain was tried by setting
  `ZoneDrain.3` to 160 with `TestMaxOxygen` 3840).
- **For the map chat:** `path.json`'s Lands start the Coral Reef at s 1000 and the Kelp Forest at 3500; the game's
  zones change at 1340 and 3770. `floor_tiles_*` and `stones_*` are in `Lane.Props`, so a fish knocks floor tiles
  loose.
- **Seen, not changed:** following the lane's middle a fish hits small props (sea grass, stones) every 2 or 3 s, 3%
  each: in the Shallows that costs more than the drain. The HUD's speed is the wanted speed (32 st/s shown with the
  nose held against a wall). A missed hop's drown says OUT OF AIR with the meter full. Swimming through a big coral
  puts the camera inside its boxes for a moment. Roblox's chat window covers the sandbox's top-left lines.

## 2026-11-11 · void (Hugo's PC): Movement v3.1: the hop is back, Oxygen by land, crashes, props that break
**State:** written, not committed by hand (the Obsidian Git plugin will sync it, together with Movement v3 below, which
was never committed on its own). StyLua, selene and `rojo build` pass; luau-lsp's type check finds nothing new.
**Nobody has played it, Claude included:** Studio's connector was being replaced. Expect numbers to tune and possibly
bugs, most of all in what needs the map (crashes, props). Hugo's answers of 2026-11-11 are in
[Decisions](Decisions.md); the model, the numbers and what to play: [riding feel](design/riding-feel.md), "Movement
v3.1"; two pictures: `docs/attachments/hop-arc.png`, `stamina-drain.png`.

- **The partner's hop is back** (`JumpController`): the pop (0.4 s, 20 studs up, 1.4 times your speed), the glide
  (1.4 s at the herd's pace) and the drop (the rest of the window: slower, sinking), with the pull-in and landing
  camera as they were. Movement v3's "no hop, slow down and sink" is gone, with its numbers (`SinkSpeed`, `SinkRamp`,
  `Drag`). `Config.herdTop` presses the herd down in the shallows again.
- **Kept from Movement v3:** the lock-on, A and D only, the spring camera, the window on the HUD (now the whole hop:
  `Jump.Window` 3.0, the same in every land), the server's "Grab". **Not back from 2026-11-10:** the ring under you,
  the flight making for a fish by itself, the fish and the hop turning with the camera, W and S, the landing without
  a press (`Jump.AutoGrab` 1 gives that last one back). **For the two of you:** these are Hugo's answers; the
  2026-11-10 rows they replace are named in the new Decisions rows, not edited.
- **The swim:** a pose for the pop (arms ahead), the swim strokes in the glide, longer strokes and a harder kick in
  the drop (`AnimController`, from `State.JumpPhase`).
- **Oxygen is the stamina, and it is the progression** (`RideService`, `Config.ZoneDrain`): what a ridden fish takes a
  second goes by the land you are in (1, 4, 14, 48, 160...), times 15% for each rarity above Common. It was by the
  fish's home land and rarity (`Required / Seconds`; `Tier.Seconds` and `FishType.Drain` are gone, `Required` is now
  worked out from the drain). A hop is never refused for Oxygen and costs none. The HUD shows the drain a second and
  what a land needs.
- **Crashes** (`Config.Crash`): a ridden fish run square into something solid loses speed (the client, told by the
  server: `Net.Ride` "Crashed") and a tenth of max Oxygen (the server), never the last of it. Never a death.
- **Props break** (new `src/server/Services/PropService.luau`, `Config.Props`): the boxes of
  `Workspace.ClaudeBlockout.Lane.Props` are knocked loose by a fish and tweened home after 8 s, all on the server. A
  ridden fish swims through them (`Course.begin(true)`); wild fish only when inside a big thing's circle. Players'
  characters are in a "Riders" collision group that doesn't collide with "Props".
- **The sandbox panel** has every new number, and one row a land for `ZoneDrain`; [the sandbox note](sandbox.md) is
  brought up to date (it still described the first jump's numbers).
- **To check by feel:** the six points at the end of "Movement v3.1" in [riding feel](design/riding-feel.md). Turn
  "No fail" and "Endless air" off for the real rules.
- **Open:** training max Oxygen isn't built, so the third land can't be kept up in without `TestMaxOxygen`; whether
  only big creatures break props (`Props.MinLength`, 0 now); map-method.md still says props break "on the player's
  own screen only" (the map chat's note: it is the server now); the server's crash check is a ray along the nose, so a
  fish swung side-on into a wall isn't counted.

## 2026-11-11 · void (Hugo's PC): Movement v3 on top of JumpController, not played yet
**State:** written, not committed by hand (the Obsidian Git plugin will sync it). StyLua, selene and `rojo build` pass.
**Nobody has played it, Claude included:** Studio was open but its MCP server did not answer, so there was no playtest.
Expect numbers that need tuning and possibly bugs. Hugo's brief of 2026-11-11; a Codex draft finished and reviewed by
Claude. The model, every number and what to check: [riding feel](design/riding-feel.md), "Movement v3".

- **This changes how fish to fish plays,** and overrides several of 2026-11-10's rows in [Decisions](Decisions.md)
  (the pop, glide and drop; the fish turning with the camera; the hands-off landing; grabbing without looking). Those
  rows are **not** edited: for Hugo and his partner to settle. The partner's `JumpController` is still the base: its
  pull-in curve, landing camera, glow, trail dots, `Course`, `LaneSurvey` and the sandbox are kept. Nothing deleted
  came back (no Grapple or Dash controller).
- **Leaving a fish** (Space): no hop. You keep going forward, slow in the water from the speed you rode at to 24 studs
  a second, and sink (5 studs a second, easing in). That opens the window: `Jump.Window`, 3.0 s, shown as a bar and
  seconds under a reticle in the middle of the screen, red and pulsing for the last 0.8 s. Out of time with no fish:
  the short drown (in the sandbox with No fail on: you float).
- **Steering:** always forward; only A and D steer, at one rate (`Ride.YawRate` 95) on a fish, in the swim and
  floating. W, S and the mouse no longer steer or change speed; a ridden fish keeps the herd's height by itself.
- **The lock-on** (new `src/client/Lib/Lock.luau`, `Config.Lock`): a cone along where the camera looks, wider for near
  fish; scored by angle and distance; nothing past `Jump.GrabRange` (85); sticky so it doesn't flicker; the locked
  fish keeps the yellow glow and gets a bracket on the screen. It shows faintly while you still ride. Space again, a
  left click, E or gamepad X grabs the locked fish; with none locked the reticle flashes red. In the swim the mouse
  aims with no button held.
- **The camera** (new `src/client/Lib/Spring.luau`): where it looks from, its turn, its zoom and its field of view each
  go through a critically damped spring, so riding, the swim, the pull-in and the landing run into each other. The
  pull-in now eases into its arrival; the landing's snap, jolt, burst and glow fade are as before.
- **Server** (`RideService`): new actions "Grab" (checks the fish is free, in range, not behind something solid, and
  keeps it for the player) and "CancelGrab"; "Land" is only taken for the fish that was granted; its own clock ends a
  window or a pull-in that the client never finishes.
- **What Claude changed in the Codex draft:** `Lock.LeftPenalty` 0 to 0.5 (the fish you just left sits in the middle of
  the view and took nearly every lock); the server's range check allows `Net.RangeSlack` (1.1) over the 85 for lag, and
  no longer refuses a grab for coming early; every number of Jump, Lock, Ride, Camera and AimHud is on the sandbox
  panel (N); the trail's timing reads Config live.
- **For Hugo to check by feel** (Play in Studio; N, then turn "No fail" off to judge the real window):
  1. Is 3.0 s enough to find and grab a fish, and short enough to press? (`Jump.Window`, 2.5 to 3.5.)
  2. The slow-down and the sinking: too floaty, too fast? (`Jump.Drag`, `AirSpeed`, `SinkSpeed`, `SinkRamp`.)
  3. Do you get the fish you look at? Aim between two fish, then at each; aim at a far one past a near one.
     (`Lock.Cone`, `AimRadius`, `DistanceWeight`, `Sticky`, `LeftPenalty`.)
  4. A and D on a fish and in the swim: the same feel? Is 95 degrees a second right?
  5. The camera through a whole chain (ride, leave, pull, land, ride): any snap, lag or wobble? (`Camera.FocusTime`,
     `TurnTime`, `ZoomTime`.) Does the landing still hit?
- **Not done:** [the sandbox note](sandbox.md) still describes the old jump's numbers and switches (not this
  session's file); two players going for one fish and bad lag are untested; phones aim by dragging, untried.

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
- **Grey-box 8 (2026-11-11, the map chat: all ten lands, 56,894 parts, the lane 30,000 studs long and up to 980
  wide, 2,225 deep):** the game runs on it after one change to the herd.
  - As loaded: the floor survey within 3.1 studs everywhere; fish in every land; 302 obstacles read from the map.
  - **Found:** the 480-fish limit (`Spawn.MaxTotal`) was used up by the deep lands, so the Shallows held 11 fish 90
    studs apart; and the herd spread over the whole width of the wide lands. Riding a fish in the Vents (the sandbox
    reset moved there), three jumps in a row found nothing to land on.
  - **Changed:** `Spawn.MaxTotal` 800, and the herd keeps to a band at most 200 studs wide down the lane's middle
    (`Spawn.BandMax`, `band()` in `FishService`). After: 741 fish, a fish's nearest neighbour 38 to 49 studs away in
    every land, and four jumps in a row landed in the Vents (2.6 to 3.0 s each).
  - **Not settled:** the frame rate. Every reading through the connector in this session was 15 a second, which looks
    like Studio's limit for a window that isn't in front; the one reading of 59 was on grey-box 6. Needs the user's
    own eyes on the ten-land map.
  - **Seen, for the friend's mechanics (the held code):** a player floating off a fish rises 6 studs a second with no
    limit below the surface, so in deep water they are out of a jump's reach of the herd within about 7 seconds.
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
