# Sub propellers

Back to [sub models](sub-models.md) and [the submarine](submarine.md). Hugo, 2026-11-23, about the toy submarines: "make
the blades on the back better, again give me a better preview and animate them to actually spin."

**State (2026-11-24): option 4, the screw, is picked and built on all nine subs, and checked against the sheet; a
bubble trail streams from it (both below, neither seen in Studio yet).** "use text D, fish rider, screw for
submarine propeller and implement": the user. What was built is the next section. Everything after it is the options
as they were made on 2026-11-23 (task p1, in Blender); "today" in it is the old wheel of bars.

## The screw, as built (2026-11-24)

- **The models:** `tools/blender/sub_stages.py` (`screw`, `flight`, `odd_colour`; `PROP = "bars"` brings the old wheel
  back). All nine tiers re-exported, 68 triangles more each; the gate finds 0 faults on each, the other parts' points
  are unchanged, and the propeller's box is 0.000 studs off the hub on every tier. The flights reach further back than
  the bars did: the part ends 2.5 studs further out behind the ring on tier 1 (20.95 against 18.4).
- **Which way it turns, by sum:** each flight's angle falls 205 degrees toward the tail (`work/picks/hand.py`, read from
  the exported points), and the game turns the part about +Z, so the water is pushed backwards. Not mirrored.
- **The turn:** 4 + 0.04 x speed radians a second and never over 30 degrees in one frame (`Config.Sub.PropIdle`,
  `PropPerSpeed`, `PropStepMost`). It was 4 + 0.12 x speed with no limit, which strobed (below).
- **The blur disc:** a thin white disc behind the flights, made in code (`SubModels`, a part named `Blur`), unseen up to
  150 studs a second and 20% there from 450 (`PropBlurFrom`, `PropBlurFull`, `PropBlurMost`). The placeholder has none.
- **The cards in the shop turn theirs** at the resting 4 radians a second, the cards in view only, while the window is
  open (`UI/SubPanel`). The little sub over the stall turned already (`SubStandController`).

## The screw, checked against the sheet (2026-11-24, task s1)

Hugo: "make sure the propeller is the screw type in the sheet you showed me. I chose this before." It is, on all nine.

- **By number:** `python tools/subs/screw_check.py` reads each sub's game mesh (`art/subs/<Id>/<Id>.glb`) and works
  option 4 out again from the sheet's own formula. On all nine the propeller is option 4 point for point (to 0.002
  studs): the blunt cone of 8 sides, two flights wound 205 degrees, and on tiers 6 to 9 the glowing ball on the cone's
  end. Each is centred on the hub (0.000 off), inside its ring (reach 3.25 of 3.70; tier 9, a bigger ring, 3.77 of
  4.40) and clear of the rest of the sub (nearest: tier 8's glow, 1.9 studs from the space it turns in).
- **By eye:** the sheet below shows option 4 as it stood on the sheet he picked from, then the game's meshes for
  tiers 1, 8 and 9 from the same three cameras in the same light. **Blades and hub match. Colours match on tier 1.**
  Tier 9's flights are the same white and purple; its ball is the kraken's cyan now where the sheet's was pink (the
  sub's light changed with 9A, not the screw). Tier 8 was not on that sheet: one flight white, one the ring's light
  red, a yellow ball.
- **One thing found, not changed:** on tier 5 (Blue Streak) the cone and the coloured flight are the same red
  (232, 80, 58), so the cone does not stand apart from that flight. It is how option 4's colours fall on that tier.
- **From straight behind** (the game's camera): it reads as a disc in two halves, one white and one coloured, with
  the cone or the ball in the middle. The twist cannot be seen from there; the two colours are what show the turn.
  On tier 8 the coloured half is the ring's own red, so it stands out less than tier 1's or tier 9's. Not redesigned.
- **The colours of each sub's screw** (cone / flight / flight, read from the meshes): 1 navy, red, white. 2 brown,
  orange, white. 3 green-grey, green, white. 4 grey, red, white. 5 red, red, white. 6 dusk purple, purple, gold.
  7 dark grey, red, white. 8 dark rust, light red, white. 9 dark purple, white, purple.

![subs 8 and 9, the screw, the bubble trail](../attachments/subs-8a-9a-screw-trail.png)

## The bubble trail (2026-11-24, task s1)

Hugo: "can you add a bubble trail right behind the propeller". **Written, checked by sums and drawn in Blender (the
sheet above). Not seen in Studio: that is task s2.**

**Why there was no trail.** An emitter named `Wake` was on the propeller already. What it did, each point from the
code and a sum, none seen in Studio:

| | What the old emitter did | Did it hide the trail? |
|---|---|---|
| Rate | 0.6 a stud a second, at least 8 and at most 260 a second, set every frame of a trip | No: plenty were made |
| Speed | 4 to 10 studs a second backwards, lasting 0.8 to 1.6 seconds | **Yes, with the next line** |
| Left where they were made | The bubbles stayed in the water where they were born while the sub and the camera went on at 464 to 4,315 studs a second. The camera rides 12 to 17 studs behind the screw's end, so it passed each bubble within 2 frames on the slowest trip and within a quarter of a frame on the fastest. About 8 bubbles or fewer were ever in front of the camera, for a blink each | **Yes: this is the reason** |
| Size | 0.5 studs growing to 1.4 | Small, but not the reason |
| Colour | White, no picture set (Roblox's default sparkle) | No |
| When it was on | Always on during a trip; 0 a second on the shop's cards and the stand's sub | No |
| The fade at the trip's end | The fade changes the parts' see-through only; the bubbles kept coming from an unseen sub | No (it made too many, not too few) |
| The blur disc | It stands in front of the flights, further from the camera than the bubbles, so it should not cover them. The order Roblox draws them in is Studio's to show | Not by the sums |

**What is built now** (`Shared/SubModels`, `dress`; the numbers are `Config.Sub`'s `Wake...`):

- The bubbles **travel with the sub** (`LockedToPart`) and stream straight back from the screw's end at 26 studs a
  second for 0.4 seconds: a jet about 10 studs long (its farthest bubble 13) that stays behind the screw at any speed.
- The emitter hangs on the hull, on a point named `WakeAt` at the propeller's back end on the hub's line. Not on the
  propeller: locked to a part that spins, the bubbles would whirl round with it.
- **More with speed:** 6 a second standing, a quarter more for every stud a second, 70 a second from 256 studs a
  second up (every run's fast part): about 28 in the trail at once. 28 a second at the drop's 90.
- **The look is the aura shop's bubble** (`AuraController`'s `bubbles`): Roblox's own ring picture, the pale blue of
  the game's other bubbles, the same brightness. Nothing uploaded. The ring is hollow, so the screw shows through.
  The picture is faint and its ring is a little over half as wide as the size given, so the size is 2 studs (a ring
  1.1 across) shrinking to 0.6, each a quarter bigger or smaller by chance.
- They come in faint, are clearest just behind the screw and fade out along the trail. The trail's far end is the
  end nearer the camera, so the smallest and faintest bubbles are the ones nearest the screen.
- None once the sub fades out at the trip's end, and none on the shop's cards or the stand's sub.

**What it does to the picture, by sums** (`tools/blender/sub_trail_sheet.py`, from the game's meshes and
`SubController.cameraFor`'s camera; the trail taken as every place a bubble can be):

| | Rider seen, with and without bubbles | Trail in the picture | Biggest bubble | Bubbles cover |
|---|---|---|---|---|
| Tier 1, full speed | 41% | all of it, 27 bubbles | 5.0% of the screen's height | 0.7% of the screen |
| Tier 8, full speed | 42% | all of it, 27 bubbles | 5.0% | 0.7% |
| Tier 9, full speed | 42% | 78% of it, 21 bubbles | 9.3% | 1.3% |
| Tiers 1 and 8, as a run begins | 56%, 57% | 2% of it | - | 0.0% |
| Tier 9, as a run begins | 57% | none | - | 0.0% |
| Tiers 1 and 8, at the drop | 50%, 51% | 27% of it, 3 bubbles | 11% | 0.5% |
| Tier 9, at the drop | 51% | none | - | 0.0% |

- **The rider is never behind a bubble.** The trail's top is 2 studs under the seat's top and behind the ring; in the
  picture the nearest a bubble can come to the rider is 13% of the screen's height away.
- **The trail runs down the picture from the screw**, toward the bottom edge: it comes straight at the camera and
  passes under it. On tier 9, the longest sub, its last fifth leaves the picture at the bottom.
- **As a run begins and at the drop the camera mostly cannot see it.** The camera stands 30 studs behind the sub's
  middle and 9 to 10 up; the screw's end is then at the picture's bottom edge (tiers 1 to 8) or under it (tier 9), so
  the trail is under the picture. It was so for the screw itself before this task. Other players see the trail from
  the side at any time.
- **It swings with the tail.** A trail that travels with the sub turns as the sub turns. It is drawn back along the
  path only while the sub goes straight; on a bend it stays a straight jet behind the tail. A trail left in the water
  is the one that could not be seen (the table above).

**Not seen, for the Studio check (s2):** that the bubbles show at all and read as a trail at full speed; their
brightness against bright water near the surface (they add light, so on a pale background they wash out); that they
draw over the blur disc and not under it; that the newest bubbles do not hide the screw's middle; tier 9's big rings
at the bottom edge at full speed; that none show after the sub has faded. If it is too thin or too thick, the numbers
are `WakeMost`, `WakeSize` and `WakeBright`.

**Outside this task's own files, each a small change the trail needed:** `SubController.place` set the rate with its
own numbers (0.6, 8, 260); it now reads `Config.Sub`'s and stops at the fade. `tools/studio/t3_toy_subs_check.py`
looked for the emitter on the propeller; it now looks on the hull's `WakeAt`. `tools/subs/stand_sub_check.luau`'s
made-up Config got the `Wake` numbers. They are one commit of their own (039996a), but it belongs with the trail:
without it the rate is the old 8 to 260 a second, about 100 rings in the 10 studs (nearly four times what the
numbers above were worked out for), the bubbles go on after the sub has faded, and those two checks fail.
- **"More with speed" shows only under 256 studs a second:** the pick-up, the first moment of a run and the drop.
  Every run's fast part is at the most, 70 a second, so all trips look alike at speed.

![the propeller options](../attachments/sub-props-options-2026-11-23.png)

The clip, 6 seconds, the turn rising from the dock to the fastest trip's top speed (tier 1 itself stops at the 464 mark):
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

  The camera is behind the sub in three parts of a trip (`SubController.cameraFor`): on the run (30 to 38 studs
  behind, 10 to 7 up), on the arrival and the drop (30 behind, 6.4 to the side, 9 up, at 90 studs a second), and at
  the end of the pick-up, when it comes round to 18 studs behind the rider (the wheel then turns 4 degrees a frame).
  How much of the run, the arrival and the drop together the wheel is past half a gap, by `SubTrip.plan`:

  | Trip | Run + arrival + drop | Past half a gap at 60 a second | At 30 a second (limit 98) | Left where it can read |
  |---|---|---|---|---|
  | Land 2 (the slowest: top 464, run 3.2 s) | 4.64 s | 2.59 s, 56% | 3.05 s, 66% | 2.05 s at 60, 1.59 s at 30 |
  | Land 10 (the fastest: top 4,315, run 6.5 s) | 7.92 s | 6.36 s, 80% | 6.45 s, 81% | 1.56 s at 60, 1.47 s at 30 |

  (With the fling's 0.8 seconds as the drop; with the kick onto a fish, 0.48 seconds, the shares are 60% and 84%
  at 60 a second.) The run is over 228 from 0.31 seconds in on the land 2 trip and from 0.07 on the land 10 trip, and
  comes back under it 0.30 and 0.05 seconds before the run's end, while slowing. **So for 56% to 80% of the time the
  camera is behind the moving sub, a six-armed wheel cannot be seen to turn; that is all of the fast part of every
  run.** In the rest (the run's first and last moments, then 1.1 to 1.4 seconds of arrival and drop at 14 degrees a frame)
  the numbers say it can read at 60 frames a second; at 30 the arrival's 28 degrees a frame is just under half a
  gap, so barely. Why it is not noticed there either is a guess, below. The third playtest of task t3 measured the
  strobing from the other side: frames where the angle read the same were whole turns ([sub models](sub-models.md)).
- **The shop's cards never turn it.** `UI/SubPanel` builds each sub into its card's picture and never touches `Prop`
  again. `place` is called only for a trip.
- **No sub stands at the dock.** `SubModels.build` has two callers, the trip and the shop's cards. Outside a trip the
  only subs to look at are the cards', which stand still.
- **Flat bars give nothing to follow.** No twist, one thickness, one colour: every arm is the same as the next, and
  the wheel looks the same face on at any angle within its 60 degrees.
- **It is big enough to see.** By the riding camera's numbers (`cameraFor`: the distance, the height and the
  width of view all change with the speed) the ring's dark disc on the run is never under 15% of the screen's
  height. At 620 studs a second (38 studs behind, 7 up, 88 degrees high: the view the sheet draws) it is 18% on
  tier 1, 19% on tier 6 and 26% on tier 9. At tier 1's own top of 464 (36 behind, 7.8 up, 83.5 degrees) it is
  21%; at the land 10 trip's top (98 degrees high) tier 9's is 22%. So size is not the reason.

**Guesses, not checked:**

- **Why the turn is not noticed in the 1.5 to 2 seconds where it can read.** By the numbers it turns readably on
  the arrival and the drop (2.4 turns a second, seen from 30 studs behind and a little to the side). Likely
  reasons, none looked at: that is when "NOW ARRIVING" and the fling or the kick take the eye; six flat look-alike
  arms in one colour show a turn weakly; the wake's bubbles (next line). It may also simply turn there and not have
  been looked at.
- **Whether the propeller is in the picture at the end of the pick-up.** The camera ends 18 studs behind the rider
  and 9 up, looking at the rider; by the kit's sizes the propeller is then close under the camera and may be below
  the picture's bottom edge. Worked from the numbers, not seen.
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
- **The screw is the weakest read from straight behind,** which is the game's view: there it is a two-colour swirl
  more than a screw, because one of its two flights is the coloured one. It reads as a screw from three-quarter rear.
- **The backing plate of options 1 and 3 shows a little in Blender:** a thin lighter rim inside the ring in the
  three-quarter views of tiers 6 and 9. Not seen from straight behind.
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
| `BlurFrom`, `BlurFull` | 150 and 450 studs a second | starts once the sub is well under way, and is full by 450 so that even the slowest trip (land 2, top 464) gets the whole disc at its top. 700 was tried first: the land 2 trip then only reached 0.12, which is hard to tell from no disc |
| `BlurMost` | 0.2 (Transparency 0.8) | hazes the dark disc to a mid grey without hiding the blades. Tried at top speed on tier 1: at 0.35 the disc goes pale grey and white blades nearly vanish into it; at 0.12 it is hard to tell from no disc; 0.2 is between |

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
- **On tier 1's own trip** (land 2, the only one that sub makes, top 464) the turn tops out at 21.5 degrees a
  frame, 3.6 turns a second: the paddles, the scimitars and the screw stay under their caps there, the fan and
  today's six arms reach theirs (18 and 15). A trip to land 10 holds every wheel at its cap for nearly the whole run.
- **The blur disc.** A thin flat disc in the blades' colour, as wide as the blades reach, sitting low in the blades
  just behind the backing plate, so the blades and the coloured blade stay sharp in front of it and the dark disc
  behind them hazes over. It does not turn. A disc in front of the blades was tried first and dropped: it washed the
  coloured blade out, which is the thing that shows the turn. Only what Roblox can do without an uploaded picture:
  one flat colour, one Transparency. **So it is not soft:** at full strength it reads in the clip as a flat grey
  plate with a hard edge behind the blades, more than as a blur. A soft edge would need a second, wider and fainter
  disc (one more part) or an uploaded picture; neither is drawn.
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

**The clip's fast half is not something tier 1 ever shows.** Tier 1's sub only goes to land 2, where the top speed
is 464; the clip takes the same tier 1 tail on to 4,315, the land 10 trip's top, to show how each wheel holds up
at any sub's speed. The clip marks the 464 point on its bar (3.5 seconds in) and says so from there on. At that
mark tier 1's real trip is at its most: the turn at 21.5 degrees a frame and the blur disc just full (0.2). What
comes after the mark is what faster subs show, drawn on tier 1's colours: tiers 2 to 9 go past 464 on their
longer trips, and only tier 9, on the trip to land 10, reaches 4,315. Tier 9's own purple blades with the disc
behind them have not been drawn.

The script reads the encoded clip back frame by frame and measures, in each tile, where the blades are: the coloured
blade's middle on the options, the six arms' pattern on today's wheel. "Seen" is the turn from one frame to the next
as the eye takes it (the shortest way round to the next look-alike position).

| Tile | Drawn, degrees a frame | Seen | Backwards | Still | Furthest the blade is from its place |
|---|---|---|---|---|---|
| Today's wheel, today's rule (the proof, not judged) | 3.8 to 498 | -30 to 30 | 68 frames | 2 frames | lost: it flickers |
| Today's wheel, proposed rule | 3.8 to 15 | 3.8 to 15.1 | 0 | 0 | 0.1 |
| 1, fat paddles | 3.8 to 30 | 3.7 to 30.4 | 0 | 0 | 1.5 |
| 2, scimitars | 3.8 to 22.5 | 3.6 to 23.6 | 0 | 0 | 4.1 |
| 3, toy fan | 3.8 to 18 | 3.6 to 18.8 | 0 | 0 | 2.4 |
| 4, screw | 3.8 to 30 | 2.4 to 44.7 | 0 | 0 | 24.5 |

- Every tile was read on all 359 steps (none unread). A tile passes with no step backwards, none still, and the blade
  never further from where it was turned to than 30 degrees on the four options (their one coloured blade is what
  is followed) and 15 on today's wheel (a quarter of the gap between its six look-alike arms).
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
  show from this side. Both are fixed in the script and said here so the pass is not taken for more than it is: the
  screw's limit (the blade's place, not each step) was chosen after seeing its numbers.

## Not tested in the game

Studio was not opened for this task (another task had it). So:

- No option has been exported, installed or seen in Roblox. How the twisted blades shade there, and how much the
  backing plate shows against the dark disc there, is not known.
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
