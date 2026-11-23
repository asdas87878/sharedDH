# Sub propellers

Back to [sub models](sub-models.md) and [the submarine](submarine.md). Hugo, 2026-11-23, about the toy submarines: "make
the blades on the back better, again give me a better preview and animate them to actually spin."

**State (2026-11-23, task p1): options only. Nothing here is in the game and no default is picked.** Hugo picks from
the sheet and the clip; a later mission builds the pick into `tools/blender/sub_stages.py` (`tail()`) and the turn
rule into the game. Everything below was made and checked in Blender. Studio was not opened.

![the propeller options](../attachments/sub-props-options-2026-11-23.png)

The clip, 6 seconds, the turn rising from the dock to the fastest trip's top speed:
[sub-props-options-spin-2026-11-23.mp4](../attachments/sub-props-options-spin-2026-11-23.mp4)

![the clip](../attachments/sub-props-options-spin-2026-11-23.mp4)

## Why today's propeller doesn't look as if it turns

It does turn: `SubController.place` turns `Prop` and `Prop_Glow` by `dt * (4 + speed * 0.12)` radians a frame.

**Proven, from the code and the numbers:**

- **It turns too far in one frame to be seen turning.** Today's wheel is three bars through the hub: six arms, so it
  looks the same every 60 degrees. A turn of more than half of that in one frame reads as flicker or as turning
  backwards, and a turn of exactly 60 degrees reads as standing still.

  | Speed, studs a second | Turn, turns a second | Degrees a frame at 60 | At 30 | How it reads at 60 |
  |---|---|---|---|---|
  | 0 to 10 (the pick-up) | 0.6 to 0.8 | 4 to 5 | 8 to 10 | turns |
  | 90 (the arrival and the drop) | 2.4 | 14 | 28 | turns, fast |
  | 228 | 5.0 | 30 | 60 | half the gap: no direction |
  | 464 (the slowest trip's top) | 9.5 | 57 | 114 | 3 degrees short of a gap: creeps backwards |
  | 490 | 10.0 | 60 | 120 | stands still |
  | 4,315 (the fastest trip's top) | 83.0 | 498 | 997 | 8.3 gaps a frame: flicker |

  The run is the only part of a trip where the camera is behind the sub (`cameraFor`), and on the run the speed is
  over 228 from a third of a second in (the slowest trip gets to 464 in 0.64 seconds). On a phone at 30 frames a
  second the limit is 98 studs a second. So for almost all the time the propeller faces the camera, it is past the
  point where a six-armed wheel can be seen to turn. The third playtest of task t3 measured the same thing from the
  other side: frames where the angle read the same were whole turns ([sub models](sub-models.md)).
- **The shop's cards never turn it.** `UI/SubPanel` builds each sub into its card's picture and never touches `Prop`
  again. `place` is called only for a trip.
- **No sub stands at the dock.** `SubModels.build` has two callers, the trip and the shop's cards. Outside a trip the
  only subs to look at are the cards', which stand still.
- **Flat bars give nothing to follow.** No twist, one thickness, one colour: every arm is the same as the next, and
  the wheel looks the same face on at any angle within its 60 degrees.
- **It is big enough to see.** By the riding camera's numbers at full speed (38 studs behind, 7 up, 88 degrees high)
  the ring's dark disc is 18% of the screen's height on tier 1 and 26% on tier 9. So size is not the reason.

**Guesses, not checked:**

- The wake's bubbles may cover it on the run: their emitter sits on the propeller, sends up to 260 a second backwards
  toward the camera, each 0.5 to 1.4 studs. Not seen; it needs a look in the game.
- Where Hugo was looking when he said it (a card in the shop, or a trip) is not known. Both fail, for different reasons.

## The four options

All four are on tiers 1, 6 and 9 on the sheet, each from straight behind, from three-quarter rear and from the riding
camera. Triangles are counted from the built mesh.

| | Option | Blades | Triangles (`Prop`) | More than today | Reach (ring's inside 3.7) | Behind the dark disc |
|---|---|---|---|---|---|---|
| now | three flat bars | 6 arms | 64 | | 3.41 | 0.85 |
| 1 | Fat paddles: narrow at the root, wide and round at the tip, twisted 38 to 20 degrees | 3 | 140 | 76 | 3.52 | 2.10 |
| 2 | Scimitars: swept back against the turn to a blunt point, twisted 36 to 20 degrees | 4 | 140 | 76 | 3.42 | 2.00 |
| 3 | Toy fan: flat rounded petals, each tipped 24 degrees, on a fat hub | 5 | 156 | 92 | 3.45 | 1.85 |
| 4 | Screw: a long nose cone with two fat flights winding back along it | 2 | 132 | 68 | 3.25 | 3.40 |

Sizes are tier 1's, in studs; tier 9's ring is bigger and the propeller grows with it. The glowing hub of tiers 6 to 9
(`Prop_Glow`, 48 triangles) is the same ball as today on every option. A whole sub is 1,288 to 3,028 triangles, so
an option adds 2% to 7% to a sub.

What every option keeps:

- The red ring, the tier's own blade and hub colours, the glowing hub, the part names `Prop` and `Prop_Glow`.
- **It spins true.** The game turns a part about the middle of its box. On every option, on all nine tiers, the
  box's middle is on the hub's line (0.000 studs off, printed by the script's `gate` step). A wheel of three or five blades is not
  centred by itself, so options 1 and 3 carry a thin backing plate in the disc's own dark colour (28 of their
  triangles), with corners on the four axes at the blades' reach.
- Inside the ring, and no flat face closer than a tenth of a stud to the dark disc (the builder's gate does not
  compare the propeller with the hull, so the script checks this itself). The builder's own gate passes on every
  option on all nine tiers (0 faults).
- **One blade in another colour,** so a turn can be seen even when the blades are all alike: the colour furthest
  from both the blades and the dark disc. That comes out as the ring's red on tier 1, the hull's purple on tier 6
  and white on tier 9. On all nine: the ring's red on tiers 1, 4, 5, 7 and 8, the hull's own colour on tiers 2
  (orange), 3 (green) and 6 (purple), white on tier 9.
- The pitch follows the turn: the game turns the part anticlockwise seen from behind (by the code; see "Not tested"),
  and the blades' leading edges are the forward ones.

Two things to know when picking:

- **Option 2's four blades line up with the tail's four fins** four times a turn on tiers 1, 2, 4, 8 and 9. The
  coloured blade still shows the turn.
- **Options 1 to 4 stand further out behind the ring** than today's bars (1.9 to 3.4 studs behind the dark disc,
  against 0.85), because a twisted blade has depth. The screw stands out most. On tiers 6 to 9 the glowing ball
  sits on the end of the hub, about a stud further still (the screw ends 4.3 studs behind the disc there, 5.0 on
  tier 9; today's ends 1.8 and 1.9). No part of any sub is in that space (boxes compared, all nine tiers).

## The turn rule proposed

Not in the game. Three parts: a turn at the dock, a cap on the turn in one frame, and a blur disc at speed.

```
rate = Idle + PerSpeed * speed                    radians a second
step = min(rate * dt, StepMost)                   radians this frame
blur = BlurMost * smoothstep(BlurFrom, BlurFull, speed)       the disc's Transparency is 1 - blur
```

| Number | Value | Why |
|---|---|---|
| `Idle` | 4 radians a second (0.64 turns a second) | today's own number at no speed: a calm turn |
| `PerSpeed` | 0.04 (today 0.12) | 1.2 turns a second at the drop's 90; the cap is reached at 370 to 690 studs a second, so the spin-up is seen |
| `StepMost` | a quarter of the gap between two blades, and at most 30 degrees | under half a gap it can't read backwards; a quarter leaves the direction plain |
| `BlurFrom`, `BlurFull` | 150 and 700 studs a second | starts as the turn nears its cap, full where every trip's run is |
| `BlurMost` | 0.35 (Transparency 0.65) | hazes the dark disc without hiding the blades; in the clip the dark disc goes to a light grey, so white blades stand out less at the top and the coloured blade carries the turn |

The cap is on the turn in one frame, not in one second, so a phone at 30 frames a second can't alias either: there
the wheel turns half as fast at the top, and still reads.

| Wheel | Gap | `StepMost` | Top turn at 60 a second | At 30 | Cap reached at (60 a second) |
|---|---|---|---|---|---|
| today's six arms | 60 | 15 | 2.5 turns a second | 1.25 | 292 studs a second |
| 1, three paddles | 120 | 30 | 5.0 | 2.5 | 685 |
| 2, four scimitars | 90 | 22.5 | 3.75 | 1.9 | 489 |
| 3, five petals | 72 | 18 | 3.0 | 1.5 | 371 |
| 4, two flights | 180 | 30 | 5.0 | 2.5 | 685 |

- **At the dock.** The shop's cards need their own turn at `Idle`: `UI/SubPanel` would turn each card's `Prop` and
  `Prop_Glow` about their own Z while the shop is open (nine cards, 13 parts in all). On a trip the pick-up
  already turns it at 0.66 turns a second.
- **The blur disc.** A thin flat disc in the blades' colour, as wide as the blades reach, sitting low in the blades
  just behind the backing plate, so the blades and the coloured blade stay sharp in front of it and the dark disc
  behind them hazes over. It does not turn. A disc in front of the blades was tried first and dropped: it washed the
  coloured blade out, which is the thing that shows the turn. Only what Roblox can do without an uploaded picture:
  one flat colour, one Transparency.
- **Where it would go** (none of it done): `Config.Sub` for the numbers; `SubController.place` for the step;
  `Shared/SubModels` for the disc, made by code beside the beam and the wake; `UI/SubPanel` for the cards' turn;
  `tools/blender/sub_stages.py` `tail()` for the picked blades, then the nine exports and the install.
- **Two traps for whoever builds it.** `SubController`'s fade at a trip's end writes `Transparency` on every part in
  the sub's list, which would make the disc solid; and `SubModels` turns any part whose name ends in `_Glow` to
  Neon, so the disc must not be named that way.

## Cost

- **Triangles:** 68 to 92 more a sub than today (the table above); nothing else in the meshes changes.
- **The blur disc:** made by code as one Cylinder part a sub, so nothing is added to the meshes: one more part on
  each sub in a trip (6 or 7 parts instead of 5 or 6), see-through only above 150 studs a second. As a mesh instead
  it would be 92 triangles (24 sides).
- **The turn:** the same one line a frame as today, with a `min`. The cards' turn is new: 13 parts set a frame
  while the shop is open.

## The clip, checked frame by frame

Tier 1. Six tiles: today's propeller by today's rule (the proof), then today's propeller and the four options by the
proposed rule. One frame of the clip is one frame of the game at 60 a second, with nothing smeared, as nothing is in
the game. The speed stands at 0 for a second, rises for four (each second about 4.6 times faster, so the slow end is
not over in a blink), and holds 4,315 for the last.

The script reads the encoded clip back frame by frame and measures, in each tile, where the blades are: the coloured
blade's middle on the options, the six arms' pattern on today's wheel. "Seen" is the turn from one frame to the next
as the eye takes it (the shortest way round to the next look-alike position).

| Tile | Drawn, degrees a frame | Seen | Backwards | Still | Furthest the blade is from its place |
|---|---|---|---|---|---|
| Today's wheel, today's rule (the proof, not judged) | 3.8 to 498 | -30 to 30 | 68 frames | 2 frames | lost: it flickers |
| Today's wheel, proposed rule | 3.8 to 15 | 3.7 to 15.1 | 0 | 0 | 0.1 |
| 1, fat paddles | 3.8 to 30 | 3.7 to 30.5 | 0 | 0 | 1.5 |
| 2, scimitars | 3.8 to 22.5 | 3.4 to 23.5 | 0 | 0 | 4.1 |
| 3, toy fan | 3.8 to 18 | 3.6 to 18.8 | 0 | 0 | 2.5 |
| 4, screw | 3.8 to 30 | 2.4 to 44.8 | 0 | 0 | 24.5 |

- Every tile was read on all 359 steps (none unread). A tile passes with no step backwards, none still, and the blade
  never more than 30 degrees from where it was turned to.
- **Today's rule strobes, measured:** from the moment the speed rises the six arms are seen going backwards on 68
  frames and standing on 2, while turning up to 498 degrees a frame.
- **The screw's steps are uneven to look at:** drawn at an even 30 degrees a frame at the top, its coloured flight is
  seen moving 20 to 45. It is a spiral round a cone seen from one side, so its middle does not travel evenly. It never
  goes backwards or stands, and it reads as turning, but it is the least even of the four.
- **By eye,** on strips of six frames in a row at the dock, rising, near the cap and at the top: on all four options
  the coloured blade goes round anticlockwise seen from behind, one step at a time, at every speed. Today's wheel by
  the proposed rule steps a quarter of a gap at the top and reads; by today's rule it looks like a different wheel on
  every frame.
- The first version of this check failed on two tiles, both the measuring and not the turn: the blur disc's haze
  counted as blade on today's wheel (the white limit was too low), and the screw was held to an even step it cannot
  show from this side. Both are fixed in the script and said here so the pass is not taken for more than it is.

## Not tested in the game

Studio was not opened for this task (another task had it). So:

- No option has been exported, installed or seen in Roblox. How the twisted blades shade there, and whether the
  backing plate shows against the dark disc, is not known.
- **The turn's direction is read from the code, not seen.** `place` turns the part about its own +Z, the install
  puts each part at its box's middle with no turn of its own, and the tail is at +Z, so seen from behind it should
  turn anticlockwise. If it turns the other way in the game, the blades need mirroring (`TURN` in the script).
- The turn rule, the blur disc and the cards' turn are not written. How a see-through part looks in the game's
  underwater light, and whether it sorts right against the wake's bubbles, is not known.
- Whether the wake's bubbles cover the propeller on the run.
- The options stand 1 to 2.5 studs further out behind the ring than today's bars. No part of any sub is in that
  space in the builder (boxes compared, all nine tiers), but the wake's emitter and the trip's camera have not been
  looked at with them.
- Only tiers 1, 6 and 9 were drawn. Tiers 2, 3, 4, 5, 7 and 8 went through the gate (0 faults) but nobody has looked
  at a picture of them.
- The clip is tier 1 only, from one three-quarter view, with white blades. The blur disc on a coloured-blade tier (6,
  7, 9) has not been drawn.

## Making them again

`python tools/blender/sub_props_options.py all` (12 to 14 minutes; Blender 5.2, no other tools). It builds the stills
for tiers 1, 6 and 9, the sheet, the clip's 360 frames, encodes the clip through Blender, decodes it again and checks
it frame by frame. The script runs `sub_stages.py`'s own builders, colours and gate without editing that file. Scratch
files go to `work/sub_props/` (not in the repo). `blender --background --python tools/blender/sub_props_options.py
-- gate <tier> work/sub_props/gate` runs the gate alone on one tier, with no pictures (a few seconds).
