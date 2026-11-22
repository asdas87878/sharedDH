---
name: game-code
description: Ride a Fish's game code: RideService, FishService and the herd, JumpController and the hop, the aquarium, props, angry mode, archetypes, sizes and variants, Config.luau (every number) and the movement sandbox. Load it before reading, changing, reviewing or testing anything in src/, or tuning a number.
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
