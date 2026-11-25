# Fish trails: the haze behind a fish

Up: [the herd](herd.md), [wild ride](wild-ride.md). Numbers: `src/shared/FishTrails.luau`. Code:
`src/client/Controllers/FishTrailController.luau`, `src/client/Lib/FishTrailRig.luau`. Colours:
`src/shared/FishTrailColours.luau`, written by `tools/trails/fish_colours.py`. Started 2026-11-25.

**The user, 2026-11-25:** "get a chat to make the vfx for the trail of different fish. we need something like ride a
dino, a haze like thing. but ours with some bubbles maybe too. and make it really cool for larger fish with more power."

## What a trail is
A soft milky haze that builds behind the fish, low and to the sides, with bubbles rising out of it. Ours: water, not
dust. Roblox's own pictures only (`smoke_main`, `explosion01_implosion_main`, `explosion01_shockwave_main`,
`sparkles_main`); nothing is uploaded.

## Power, in six steps
Points = size + rarity + length. Each step has its own recipe and keeps what the step under it has.

| Size | pts | | Rarity | pts | | Real length | pts |
|---|---|---|---|---|---|---|---|
| Tiny | -1 | | Common | 0 | | under 60 studs | 0 |
| Normal | 0 | | Uncommon | 0.5 | | 60 and up | 0.5 |
| Big | 1 | | Rare | 1 | | 110 and up | 1 |
| Giant | 2 | | Epic | 1.5 | | | |
| Huge | 3 | | Legendary | 2 | | | |
| Colossal | 4 | | Mythic | 4 | | | |
| | | | Secret | 5.5 | | | |

Particles alive (rate x life, worked out) and things drawn (each emitter, ribbon and front sheet) are what
`FishTrails.cost` gives, so the table is the code's own.

| Step | Points | Who, for example | What is new | Alive | Drawn |
|---|---|---|---|---|---|
| 1 Wisp | under 1 | Normal Clownfish | one thin soft ribbon, a few bubbles | 6 | 2 |
| 2 Stream | 1 | Normal Rare, Epic; Big Common | the haze itself: small soft puffs low behind the tail | 15 | 3 |
| 3 Plume | 2 | Normal Legendary; Giant Common | a wide haze, and two fin ribbons that stream straight off the sides | 23 | 5 |
| 4 Surge | 3 | Big Legendary; Huge Common | the fin ribbons twist into corkscrews, and the haze rolls outward | 36 | 8 |
| 5 Storm | 4 | Mythic; Giant Legendary; Colossal Common | a pressure front: curved sheets of water off the head; bubbles off the whole body; its own light in the haze | 61 | 12 |
| 6 Titan | 5.5 | Secret; Colossal Legendary; Giant Mythic | vapour rings left hanging behind it, a second pair of curls in its glow colour | 83 | 15 |

**How common each is** (`python tools/trails/step_shares.py`, percent of the herd, from the lands' own odds; length points not counted):

| Land | Wisp | Stream | Plume | Surge | Storm | Titan |
|---|---|---|---|---|---|---|
| 1 | 88 | 9 | 3 | 1 | 0.2 | 0 |
| 3 | 45 | 41 | 10 | 3 | 1.2 | 0.3 |
| 5 | 17 | 55 | 17 | 7 | 3 | 0.9 |
| 8 | 4 | 28 | 49 | 10 | 7 | 2 |
| 10 | 0 | 15 | 58 | 12 | 11 | 4 |

## What drives what
- **Step** picks the layers. **Body size** (`Config.bodyOf`) sets every width, spread and puff, by a share that falls for big
  fish (the body's width x height to the power 0.35, 12 studs at most).
- **Speed** sets the rate: nothing at 8 studs a second, whole at 45. The ribbons get longer by themselves.
- **A burst of speed** (a dash, a landing's surge, a lurch) throws one puff of bubbles, read off the real gain in speed, so no event is
  needed. `Config.Pace` shows through speed and bursts alone.
- **The land's water:** the haze is white, 30% toward `Lighting.FogColor` (up to 70% in black water, where white would shine), then up
  to 45% toward the fish's own colour by step.
- **The fish's colour:** Main and Glow from its own palette. **Variants replace them:** Silver ice, Gold gold, Rainbow the rainbow along
  the ribbons; all three add glints.
- **Archetype:** Fast: ribbons half as long again and thinner. Tank: heavier haze, no curls until Storm. Breaker: the pressure front
  from Surge. Leaper: bubbles jet upward. Predator: the curls tight, in a red edge. Frenzy: one more burst each bite.

## It never hides the game
- Haze is put low (under the body's middle line). Tags are frames on the screen (`UI/Tags`), so no trail ever covers one.
- **Another fish's trail goes near the camera:** the whole of it, by how far the camera is from the part of it that is still
  alive, from 10 studs, gone at 4 (`LocalTransparencyModifier`).
- **The rider's own fish.** The camera is 17 studs behind at 66 to 150 studs a second, so a puff left hanging would reach it in a
  tenth to a quarter of a second. So the puffs are **sent on with the fish** at 0.7 of its speed and slide back beside it, low and
  out to the sides, and their life is cut so they end three quarters of the way to the camera; a long fish's haze starts under the
  rider, not at a tail that is behind them. 0.6 as solid, 0.7 as many, puffs of 4.5 studs at most, no rings, the middle ribbon a
  third as solid, and every ribbon ends before the camera.
- Nothing near or over the surface (2 studs), on a fish outside `workspace.Fish`, angry or failing (the wake's `Enabled` and the `Angry` attribute are
  only read; `AngryController` and `FailController` are not touched).

## The old wake, and the switch
`Wake` (the white streak) stays on every fish without a trail: the far ones. A fish with one has its streak see-through on this machine only.
Switch: `FishTrails.On` in the numbers (1 new, 0 the old wake); in Studio workspace's `FishTrails` attribute wins and the key **T** flips it
in Play. `FishTrailsLevel` ("Full" or "Lite") forces the level; `FishTrailsMeasure` true writes the numbers on workspace.

## Cost
- **Pool:** 8 rigs (Full) or 4 (Lite), made once. A rig is two anchored, invisible parts with all its layers on them, in
  `workspace.FishTrails`; a new fish only sets numbers. The parts move by one `BulkMoveTo` a frame. A rig that goes to another fish wipes its ribbons and
  throws nothing for two frames.
- **Who gets one:** every 0.25 s, our own fish first, then by nearness and step, within 180 studs (Lite 110), and never one off the screen. All
  of them together are held under 260 particles and 48 drawn (Lite 60 and 16): the last ones lose a step at a time.
  Eight Plumes (land 10's usual) come to 184 and 40, so they fit whole.
- **Lite:** Plume at most (so no corkscrews, rings, front or glow), half the rates. By the saved graphics level (3 or lower), any phone or tablet (`Kit.touch`), or
  3 seconds under 40 fps (back after 20 good ones). A covered Studio is slow too, so a measurement forces the level.
- **Budget:** under 1 ms of script a frame, under 260 particles, no instance made after the start.

## Measured
Not yet.
