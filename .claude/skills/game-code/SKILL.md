---
name: game-code
description: "Ride a Fish's game code: RideService, FishService and the herd, JumpController and the hop, the aquarium, props, angry mode, archetypes, sizes and variants, Config.luau (every number) and the movement sandbox. Load it before reading, changing, reviewing or testing anything in src/, or tuning a number."
---

# The game code (what is built and where)

Moved here word for word from CLAUDE.md on 2026-11-22 (the token-saving setup, docs/AI setup.md), so only chats
doing this kind of work carry it. Keep it up to date HERE from now on, the way CLAUDE.md was kept.

- **The game code (2026-11-10):** riding is `RideService` (server: states Dock, Free, Riding, Jumping, Drowning; Oxygen)
  with `RideController` (the fish turns to where the camera looks; the camera), fish are `FishService` (a herd swimming
  straight down the lane; since 2026-11-13 down its own smooth line through the open water, `src/server/Lib/Stream.luau`,
  built once from the map at server start: [the herd](docs/design/herd.md); check a new map with
  `python tools/studio/herd_stream_test.py <studio_id> Edit`; since 2026-11-16 a wild fish swims at a share of its
  land's pace in one of three layers, the sea flows out of sight and fish are made only out of sight:
  [the herd, rethought](docs/design/herd-revamp.md); measure a ride with `tools/studio/ride_log.luau`), and going fish to fish is `JumpController`: Ride a Dino's jump, read from the
  user's recordings ([reference](docs/reference/ride-a-dino.md)). What is built, measured and still open:
  [riding feel](docs/design/riding-feel.md). Every number is in `src/shared/Config.luau`, read live. Every fish has its own
  speed and passive archetypes, set by hand in one table (`Config.FishStats`; `Config.speedOf` = that number x the variant's, Gold 1.1, Rainbow 1.2;
  no rarity or land formula; since 2026-11-13 every fish also rolls one of six sizes and four colours, 24 of each, with the
  reference's odds, and each kind has its own size multiplier, `Config.BaseScale`: [sizes](docs/design/sizes.md); size does not change speed; a catch is carried home, put in the player's own tank on the dock and earns coins
  (`AquariumService`, `Config.Aquarium`, [the aquarium](docs/design/aquarium.md); not saved yet); wild fish swim in character (plod, cruise, zoom, dart, and hunters that stoop from above:
  `Config.Pace`, `Config.FishPace`, [pace](docs/design/pace.md)); the `Archetype` attribute, "" or ids comma-separated; rules, numbers and all 82 rows in
  [archetypes](docs/design/archetypes.md); the passives are built: `RideService` decides, `ArchetypeController` and `Config.ArchetypeFeel` are the feedback, a fish's tag names them, sandbox key F rides a try-out fish; measured in [docs/playtests/2026-11-12-archetypes.md](docs/playtests/2026-11-12-archetypes.md), not played by hand; animation hooks at the end of the note) and now and then a
  variant (`Variant`; look in `Shared/Variants`); the camera stays under the surface once dived (`Camera.Submerge`). In Studio the game
  starts as the **movement sandbox** ([docs/sandbox.md](docs/sandbox.md): no fail, R reset, V side view, N a panel of every
  number): the user tunes there and pastes "Copy changes" for Claude to write into Config. Angry mode (Hugo, 2026-11-12): with the meter in its red part (`Oxygen.AngryAt`) the
  ridden fish pulses red (`AngryController`) and slows in its body type's own way (`Shared/AngryStyles`, `Config.Angry`;
  the server sets the fish's `Angry` and `AngryStyle`); its motion is a stand-in sine until the partner's animations. Props (Hugo, 2026-11-13; `Config.Props`, `PropService`, `PropController`): only a Tank, a Breaker or a giant (model box of `Props.GiantVolume` cubic studs or more; `Config.breaks`, 16 of 82, listed in archetypes.md) breaks a prop; every other fish and every rider in the hop goes straight through: a prop in their way looks solid until their fish touches it (one short camera shake, `Props.Shake`, then see-through to `Props.FadeTo` while inside), a prop passed close by (`Props.SideNear`) or between the camera and the player is see-through while it is, and a broken prop's loose boxes are see-through near the player (`Props.DebrisNear`), all on that player's screen only; the server keeps only which boxes are out (tag `PropOut`) and puts the prop back when no player has been near for a while, each machine throws and fades its own copies of the boxes; test driver `tools/studio/props_b1`. The hop (Hugo, 2026-11-13; `Config.hopFrom`, `hopKept`, `hopSpeed`, `hopSink`, `reachOf`): it leaves at 0.85 of the fish's speed plus a kick (`Jump.Launch`, `HopBoost`), the speed is one curve easing to a stop (`SpeedHalf`, `SpeedTail`, `StopTime`) and the
  fall comes in along it (`FallSpeed`, `SinkCurve`); the hook's reach is by speed (`Jump.GrabNear` to `GrabRange`), counted the same by the server; the wait between fish is
  `Jump.Cooldown` 0.08 s from the touch ([docs/playtests/2026-11-13-hop-air-reach.md](docs/playtests/2026-11-13-hop-air-reach.md), not played by hand). What each push changed is in
  [Handoff](docs/Handoff.md); who has which files, [Sessions](docs/Sessions.md).
- **The dive leap (the user, 2026-11-23; `Config.Dive.Leap`, 1 in the file on the user's word the same day):** running off
  the strip's lip at the open water becomes a leap with its own camera move and a splash, client only
  (`Controllers/DiveController`, `Lib/Splash`, the pose in `AnimController`); the server's rule for being in the water
  is unchanged and the existing hop takes over with the leap's heading (`State.LeapHeading`, `LeapSplashed`). State,
  what is not known and the check (`tools/studio/dive_leap_check.py`): [the dive-in](docs/design/dive-in.md), "The leap".
- **The first minutes (2026-11-23; off: `Config.Lesson.On` 0):** `LessonService` (the player's `Lesson` step, the first-fish rule, the steps counted), `LessonController` with `UI/LessonPrompt` and `UI/LessonPointer`; hooks `RideService.FirstFish` and `OnTamed`, `Lock.Allow`, `HopButton.hold`, `DockNotes.words` and `lesson` (shown only after a respawn since 2026-11-25: `Lib/RespawnLine`, `Config.DockLine`), `FishService.put`. What is built and not checked: [first-minutes](docs/design/first-minutes.md), "Built"; check with `tools/studio/lesson_check.py` (`LessonTest` before Play).
- **Fails, the leap on a fish, riding out of the tank (2026-11-23), all OFF until played:** the eaten and drown fixes
  (`Config.Fail.MouthFromModel`, `Arrive`, `Smooth`, `EatSmall` with `EatMin`, `MouthAt`; `Config.Death.UnderWater`;
  `FailController`, `DeathController`, `Lib/Underwater`; [riding feel](docs/design/riding-feel.md), last section; check
  `tools/studio/fail_eat_check.py`, which refuses under 40 fps); the leap on a land fish (`Config.Dive.LeapMounted`,
  `DiveController`; [the dive-in](docs/design/dive-in.md)); riding a tank fish out through the gate (`Config.TankRide.Out`,
  `TankRideService.out`, `RideService.rideOut`; [equip](docs/design/equip.md)). A dial goes to 1 in the file only after its
  check has run at a real frame rate. **Bought Oxygen off the dock is banked** (`RideService.grantOxygen`, `Banked`) and
  joins the max at the dock: never raise the max mid-dive, the red line and the drain are shares of it.
- **The hub's new pieces (2026-11-24; NULLROOM h1 to h4):** the stalls open on their floor rings, the sub stand too
  (`StallController`: Sell, Auras, Sub, and Index where the map has that station; no ProximityPrompt; `SubPanel.toggle` is the Studio checks' door); a small
  copy of the equipped sub turns over the sub stand, on the player's own machine (`SubStandController`); **the Index**
  is `IndexService` (the server sees a catch in `RideService.carried` and `AquariumService.tankOf` every
  `Config.Index.Watch`; claims on the dock only, paid once; attributes `IndexFound`, `IndexClaims`; remote `Net.Index`)
  with `UI/IndexPanel` and the Index button in `UI/HubButtons`; every `Config.Index` number is a DRAFT; **the
  keepers** behind the stands are data in `Shared/Keepers` built and moved by `KeeperController` on each player's own
  machine (plain parts in `workspace.Keepers`, no collision, no query). Design: [UI](docs/design/ui.md) (top
  section), [hub models](docs/design/hub-models.md) ("The keepers behind the stands"),
  [submarine](docs/design/submarine.md). One Studio check for all of it:
  `python tools/studio/h4_hub_check.py` (install, play, `run`, `stills`; its head says how). Offline:
  `tools/index/*.luau`, `tools/subs/stand_sub_check.luau`, `tools/keepers/check.py` (lune and python).
- **Auras (2026-11-24; NULLROOM a1; seen in Studio 2026-11-25):** `AuraService` (server: Action "AuraBuy", tier; the next one
  only, on the dock near the stall, `Config.Aura.Prices`; attribute `Aura`; Ride "AuraBought"/"AuraDenied"; multiplies
  `TrainService.gain` only), the flame in `Shared/AuraFlame` (plain sums) and `Lib/AuraBeams`, worn by `AuraController`
  (`Config.Aura.Flame` 0 = the old look; no pictures = the old look too), cards in `UI/AuraShop` (never a stand-in behind an
  icon). Pictures `art/ui/aura_flame`, local only (`python tools/auras/flame_pics.py`); to upload: the six in its `upload/` (with ids
  in `Auras.Pictures`, `Aura.Turn` does nothing). Design:
  [auras](docs/design/auras.md). Checks: `tools/auras/aura_test.luau` (lune on a built place), `tools/studio/aura_check.py`.
