# Endless: what comes after the Underworld

## Hugo's answer (2026-11-25): the Underworld itself, for ever
Hugo, on the study below: "This is not what i meant, i want thelast part the underworld or whatever to run infinitely after reaching
it, only looping those parts, fish shouldnt get stronger, maybe increase rare traits like size and colours with how far you are, dont
increase in heavy amounts though just very very slightly, oxygen needed shouldnt be stronger."

So: **no layers, no stronger fish, no Deep mark, no milestones, no other lands' looks.** The rest of this note (the Deep Run, its economy,
the ten looks) is set aside; its measurements of chunks, joints and distance still hold. **Not built; the go is Hugo's.**
The sheet: [endless-underworld-1.png](../attachments/endless-underworld-1.png).

- **The map:** past the end of land 10 the lane goes on in Underworld pieces only, in a random order (one seed a server, the same for every player). 18 pieces, each
  in two hands, made by our generator with every land wearing the Underworld's kit (`build_lane.py under`): 1,200 studs, 7 s, 4,420 to
  5,704 parts (mean 5,126). A shape comes back after 17 pieces on average, never within 8.
- **Laid out** as the Spiral below, but at **2.5 degrees** (the Underworld now 8): it winds down a column, each player's machine builds its own window (mean
  15,400 parts, most 16,800; 750 boxes a second at 175 studs a second), the server holds none. 100 seeds: at 10 / 30 / 60 minutes x and z under 29,000,
  y -6,700 / -15,900 / -29,700, so positions stay as exact as at today's far end for the first hour (they step down once at 32,768, about
  65 minutes in). Coils are at least 717 studs apart in height (40 seeds x 100 pieces) and the scenery is at most 480 high; the unseen barrier is
  1,269 high as the generator makes it and must be cut to 600. Never nearer than 788 to today's lane.
- **Joints:** 0 holes in the lane, holes beside it (median 700 square studs, 7,750 at worst; real neighbours 0 to 50), all closed by the joint
  piece (`chunks.joint(fall=2.5)`; `holes.py ... 2.5`). A sketch, not seen in Roblox. The kill height (`FallenPartsDestroyHeight`, -20,000) is passed after
  about 39 minutes: set it to -100,000 in Studio.
- **The fish:** the Underworld's own roster, the same strength, the same speeds, the same Oxygen each (`Config.requiredOf`). No code for strength.
- **The odds** (`odds.py`; FishService's own rules, 400,000 spawned fish a row). The PLACE has them, so two riders always see the same fish.
  **Our pick: +1% on the chances of Big and up and of Silver, Gold, Rainbow for every 10,500 studs (a minute), no more than +10%.** One dial.

| Chances | Big | Giant | Huge | Colossal | Silver | Gold | Rainbow | average fish needs / earns |
|---|---|---|---|---|---|---|---|---|
| now | 16.8% | 3.58% | 1.17% | 0.205% | 5.0% | 1.01% | 1 in 608 | 1 / 1 |
| +5% | 17.6% | 3.51% | 1.23% | 0.215% | 5.26% | 1.06% | 1 in 579 | 1.003 / 1.005 |
| **+10%** | **18.4%** | **3.43%** | **1.30%** | **0.226%** | **5.5%** | **1.11%** | **1 in 551** | **1.006 / 1.010** |
| +25% | 20.9% | 3.23% | 1.47% | 0.259% | 6.25% | 1.27% | 1 in 480 | 1.015 / 1.026 |
| +50% | 25.1% | 2.89% | 1.76% | 0.31% | 7.54% | 1.51% | 1 in 402 | 1.031 / 1.052 |

  A Giant falls a little as Huge rises because `Config.Grand` keeps one grand fish to 800 studs; that rule stays. **One thing to know:** a
  bigger or rarer fish has always needed more Oxygen (`SizeOxygen`, `VariantOxygen`: a Colossal three times, a Rainbow twice), so with more of them the average fish needs 0.6%
  more at +10%. Each fish's own need does not change. If Hugo wants it to be zero, the bonus would have to pick colours and sizes that need no more, which
  means changing that rule; we would not.
- **Where the odds go in the code:** `rollSize` and `rollVariant` in FishService get the place along the lane; `Config.rollSize`, `rollVariant` take the times. The rest is the map, below ("What
  would change in the code", D), shorter: no layers, marks, milestones, board or saves; the zone, fog and music stay land 10's.
- **Also looked at:** a closed level ring of 17 pieces (87,000 parts, sent to everyone; the same 2 minutes for ever; the place can't tell how far a rider is,
  so the odds would hang on each rider). Cheaper (3 days, a guess) but not random and no "further". We would not.
- **Work, a guess:** 4 to 5 days. First a half-day Studio test (a phone's building speed, fish at y -20,000 and past), then the baked
  pieces and the joint piece, the server's lane and herd from numbers, the client's builder, the mouth from land 10's end, the odds.

Everything from here on is the first study, as it was shown.

A study with options for Hugo (2026-11-25, NULLROOM e1). **Nothing is built in the game.** Hugo: "I need a
loop for gameplay after reaching last stage, can you make map go basically infinite? this can be a loop of parts of the area
stacked in a random way, find out what works best and let me decide."

The sheet, with three seeds drawn: [endless-options-1.png](../attachments/endless-options-1.png).

## The answer
**D + 1.** D, the Spiral: random chunks from our own map generator, winding down round a column, one seed shared by the
server, each player's own machine building only the part round them. With 1, the Deep Run: fish x1.35 stronger a layer, a first
time at a layer paying 10% of its need in Oxygen (no coins), a landmark every 5 layers, the DEEPEST DIVERS board. A cheap first step exists: the stack straight on, without the spiral.

## Questions for Hugo (four)
1. **Which map: A, B, C, D or E?** We would take D.
2. **Which game on it: 1, 2, 3, 4 or a mix?** We would take 1, then 3. No rebirth yet.
3. **What may the layers look like:** (a) all ten lands mixed, or (b) only deep, dark looks, a new set? We would take (a) first.
4. **Who gets in:** (a) only past land 10 (about 21 hours in for a free player, our model), or (b) also a gate in the hub for
   everybody, with fish by your own strength? We would take (a).

## What was measured
All offline: from `~/Documents/RideAFish/ride-a-fish-map.rbxl` as saved 2026-11-25 00:11, the map generator and `Config`.

- **The lane today:** 23,500 studs, 104,211 map parts (105,706 base parts counted in the saved place, 54,002 surface pictures), the generator's
  own line ends at x -110.6, y -2,224.5, z 23,076.5, heading -0.7 degrees (s 23,500); the place stands 3,000 further in x, so in the game that is
  x 2,889.4 (the path's true middle runs 20 studs on, to z 23,099). The stack starts there. **`StreamingEnabled` is false in the saved file**, so every player would get the
  whole map (the Team Create place can differ; it can't be read offline).
- **Pace:** 175 studs a second: land 10's ridden mean (109.9) x `Config.Speed.Ride` (1.6). 10 / 30 / 60 minutes is 105,000 / 315,000 /
  630,000 studs, 87 / 262 / 525 chunks of 1,200.
- **Chunks cut from today's lands** at the 39 deep necks (76 ends with mirroring): the lane's edge jumps 129 studs at a typical joint, 287
  at the ninth decile, 479 at worst; **1 pair in 20 fits within 24 studs and 2 ends fit nothing.** The floor joins fine (0.65 at
  most), once each chunk carries its floor 48 studs past its ends. So real cut-ups look broken at the sides, or need a hiding frame at every joint.
- **Chunks made by our generator** (`tools/endless/build_lane.py`: `greybox.py` run in memory with two chunks a land, both sides
  pinching together at each end, a straight 6 degree slope there): **every pair meets in the lane: edge step 0, floor step 0.28 at
  most.** What still shows: wall tops behind the neck differ by a median 21 studs, and where the look changes the floor's edge is a sawtooth
  (the floor is tiles on one world grid).
- **But there are holes beside the neck** (`tools/endless/holes.py`; `joints.py` could not see them: it skips what is missing
  outside the lane). All 1,224 joints of the 18 chunks in both hands, from above, 300 studs beside each edge of the neck and 72 each way
  of the cut: 0 holes in the lane; beside it a median of **600 square studs** with no floor, wall, grass or shelf, a tenth over 3,150, 7,575
  at worst, 39% at 1,000 or more, only 9% with none (a narrower strip along the cut gives a smaller figure). The nine pairs that were built as neighbours: 0 to 50.
  At a rider's height 7% of the rows across a joint have no wall at all on a side (36% at worst; neighbours 5%). The cause: each chunk is
  cut at its own neck, and its walls and shelves end there, on their own curve.
- **The fix, sketched and measured:** eight plain boxes a joint (`chunks.joint`; 8 parts on a chunk of 6,250): a slab 980 x 160 under
  both floors, a sill across the neck half a stud over them (hides most of the sawtooth), three blocks a side that step out with
  the lane so none stands in it. With them: 0 holes at all 1,224 joints, nothing open sideways. Not yet seen in Roblox, nor how it looks at speed. So **"every chunk
  fits every chunk" holds for the lane and, with this piece, for the ground; without it, it does not.**
- **A chunk:** 4,734 to 8,155 parts (mean 6,250, of them 3,267 in props), 3,031 pictures. About 1,800 are in props with no box over 7
  studs, which a rider at this speed may never read: the first thing to cut. 1,200 studs long, 6.9 s, 126 m down.
- **The stacker** (`tools/endless/stack.py`): same seed, same run, twice. No shape again within 8 chunks. 20 seeds of 100 chunks: no coil of the
  spiral within 950 studs across and 750 in height of another; and 100 seeds of 60 never nearer than 1,890 studs in height to today's lane where they pass under it. (Coils are about 2,100 studs apart in height; the canyon is 470 high.)

| | 10 min | 30 min | 60 min |
|---|---|---|---|
| Chunks | 87 | 262 | 525 |
| Spiral, 100 seeds: largest z / lowest y | 27,963 / -13,071 | 28,580 / -35,143 | 28,580 / -68,314 |
| Spiral, 100 seeds: x from and to (place) | -4,836 to 11,081 | -5,440 to 11,154 | -5,440 to 11,283 |
| Spiral: worst step of a position | 0.002 | 0.004 | 0.008 |
| Straight on: z / worst step | 121,000 / 0.008 | 316,000 / 0.031 | 606,000 / 0.063 |
| A shape is back after (mean / least) | 17 / 9 chunks | 18 / 9 | 18 / 9 |
| New shape + hand + look, share of chunks | 85% | 61% | 41% |

So x and z stay under 29,000 (17 seeds of 100 pass 27,700 at 60 minutes), under the 32,768 where a step doubles.

- **Where positions go bad:** today's far end is at a step of 0.002. Past 32,768 a step is 0.004, past 65,536 0.008, past 131,072 0.016, past
  524,288 0.0625. What players report (anecdotes, no official limit found; web pages could only be searched, not opened, so
  these are search summaries): avatars bend noticeably at about [30,000 studs](https://devforum.roblox.com/t/avatar-becomes-distorted-farther-from-0-0-0/4796832),
  [mesh-deformed seams](https://devforum.roblox.com/t/gaps-on-mesh-deformed-model-when-over-a-specific-stud-count-on-the-z-axis/3438026), walking off
  [far from the middle](https://devforum.roblox.com/t/walking-in-straight-lines-impossible-far-from-the-origin/26131),
  [loss of precision](https://devforum.roblox.com/t/loss-of-precision-causes-game-breaking-issues-at-distances-far-from-origin/202782). So straight
  on is at risk after 10 minutes; the spiral only in y after about 30.
- **The kill height:** `FallenPartsDestroyHeight` is -20,000 in the saved place, and only Studio can set it
  ([map method](map-method.md)). At 6 degrees it is reached after 141 chunks, 16 minutes. For D set it to -100,000.
- **Streaming** ([docs](https://create.roblox.com/docs/workspace/streaming)): on or off can't be set from a script, only Workspace streams; the
  place's target radius is 2,400. Moving many server parts is a
  [network spike](https://devforum.roblox.com/t/how-to-lower-network-receive-when-moving-many-parts-on-the-server-at-once-100/3007393);
  reusing parts is better than [destroying and making them](https://devforum.roblox.com/t/optimizing-mass-part-spawning-for-procedurally-generated-terrain/3660516);
  [a small gain only](https://devforum.roblox.com/t/bulkmoveto-vs-normal-cframe-ing/1278502) from BulkMoveTo.

## The map, five ways
| | A: random stack, built once | B: the ten lands again | C: treadmill | **D: the Spiral** | E: whirlpools |
|---|---|---|---|---|---|
| What it is | chunks after land 10, a shared seed, made at server start | the same lands, new light, paint and fish | the server moves a pool of chunks ahead of the deepest rider | random chunks round a column, each player's machine builds its own window | trenches of 6 chunks near the hub, a 1 s bubble cut between |
| 10 / 30 / 60 min | a wall: 36 chunks = 4 min | same order every 2.2 min: 4 / 13 / 27 laps | as D, but straight | see the table | as D, with 15 / 44 / 87 cuts |
| Seams | fixed by generator chunks; cut-ups do not fit | none inside a land; one at each lap | as D | lane 0 / 0.28; holes beside it, closed by the joint piece | the same |
| Parts | +225,000 for 36 chunks, sent to everyone | 0 new if shared, +106,000 a lap if built | 19,000 near one rider, 150,000 for 8 apart, all on the server | server 0, a player 19,000 (max 24,000) | a player about 19,000 |
| Far from zero | only as long as it is | 120,000 at 10 min | the same, unless the world slides, which 8 riders can't share | x, z under 29,000 (100 seeds); y grows | never grows |
| Riders apart | fine | two sets of fish | the weak point | one seed, one lane | 8 lanes and herds |
| Work / risk (a guess) | 2 to 3 days / low, not endless | 3 to 4 / medium, old fastest | 5 to 6 / high | 5 to 6 / medium | 7 to 9 / high |

Also looked at and dropped: a closed ring lane with laps (a rider on lap 1 and one on lap 7 can't share a fish), and simply making
the generator's lane longer in the place (fine for a few lands, never endless: it is A with better joints).

### What would change in the code (nothing touched)
- **All of them:** the lane is made once, at server start, from the built map (`FishService.Init`, `LaneSurvey`, `Stream.build` with
  rays); `Lane.at` stops at its length; `Zones.locate` gives the last land past the end; the client rebuilds the lane from an attribute
  (`Course`); pools, `ZoneMix` and `LandPace` are by land; `BestService` refuses a jump of more than one land; `SubService` has nine subs.
- **Trips / subs:** a sub to the mouth of the Spiral is one more entry; not needed first. **Hook, hop, taming, oxygen, fail:** no change, they work by the fish and the water.
- **A:** the lane, stream and zones get longer at server start; fish for the whole length (578 wild fish today).
- **B:** fish, looks and zones by lap; `SpecialOxygen` or a mark for the strength.
- **C:** a server job that moves parts; everything that asks the map with a ray must wait for it; replication.
- **D:** (1) chunk data baked offline: boxes for the client, and for the server only numbers (the way, half widths, open water, big
  things: about 255 numbers a chunk); (2) `Lane` and `Stream` grow chunk by chunk from them, no rays; (3) fish slices only near a rider
  (`LiveReach` is already 1,500); (4) a client builder with a pool (912 boxes a second at pace, 15 a frame); (5) the barrier and
  `checkCrash` use the half widths, as the server has no walls; (6) the far look and the fog by layer; (7) `BestService` by layer.
- **E:** the lane, stream, zones and herd must be able to exist more than once.

## The game, four ways
1. **Deep Run (recommended).** Fish in a layer carry a Deep mark that multiplies their own need, x1.35 a layer, saved with the fish
   (so Hugo's "a fish's Oxygen never depends on the land" holds: it is the fish's; the door is `Config.SpecialOxygen`, empty
   today). Coins go with the need, as every fish's do. You go as deep as your Oxygen holds; the red chain (2.5 s x 0.7 a fish) ends
   it. First time at a layer: 10% of its need in Oxygen and no coins. Every 5 layers a landmark (a gate and a chest, later a
   boss). 1 layer in 6 is rich: gold (better colours), giants (bigger sizes) or a shoal. It ends as a dive does now, with a depth card and your best.
   Board: DEEPEST DIVERS, in l1's list with `On` 0 because a client moves its own character: the server must first
   check the depth against the pace it allows.
2. **The Chase.** Fish as they are; a dark cloud comes up behind and speeds up. Skill, so it never ends by itself and a new player may
   enter. Pays score and small chests. Risk: a side game. The one we studied ([Ride a Dino deep](../reference/ride-a-dino-deep.md),
   "Endless mode") paid a special coin for permanent power and its creator seen on video played it once; its player count went on falling.
3. **Daily Trench.** The date is the seed: everybody rides the same layers, the board is today's, three goals. Goes with 1 or 2, almost free
   after D. With saving off, its board is this server's, as the other boards are.
4. **Rebirth (only an option).** Give back Oxygen and coins at layer 10, keep the Index and the fish, gain +x% for good. Not needed now:
   after 100 hours our model's player has seahorse 10 of 12, aura 11 of 12 and layer 9.

## The economy, in numbers
`tools/endless/economy.py`: the free player of `tools/balance/rad_economy.py` with layers under land 10, 5 seeds, the medians.

**What diving costs in Oxygen.** The model's rule: 70% of catches in the deepest land the player can work, 30% in the one above. With layers
under land 10 that player never finishes land 9 and 10's Index pages (each pays 5 times its land's commonest fish). So two divers are
shown: "only dives" (the model's rule) and "fills the Index" (the 30% go to the land's missing fish; the same without endless, so the
comparison is like for like: today 50.3B at 60 h, 77.5B at 100 h in both).

| Milestone (Oxygen, share of the layer's need / seconds of its coins) | only dives: Oxygen 60 h | 100 h | tank a second 100 h | fills the Index: Oxygen 60 h | 100 h | tank 100 h |
|---|---|---|---|---|---|---|
| no endless (today) | 50.3B | 77.5B | 22.2B | 50.3B | 77.5B | 22.2B |
| 0 / 0 | 20.2B | 41.1B | 19.2B | 50.5B | 81.9B | 42.1B |
| 2% / 60 | 22.1B | 46.7B | 20.9B | 56.0B | 91.9B | 47.1B |
| 4% / 60 | 24.0B | 54.5B | 24.1B | 61.3B | 106B | 49.8B |
| 6% / 60 | 25.9B | 61.9B | 27.5B | 67.0B | 118B | 61.2B |
| 8% / 60 | 28.1B | 68.8B | 33.1B | 83.0B | 145B | 71.4B |
| **10% / 60 (and 10% / 0: the same)** | **34.0B** | **85.4B** | **38.9B** | **92.0B** | **160B** | **83.1B** |
| 20% / 600 | 123B | 303B | 159B | not run | | |

| Hours | Oxygen today | Deep Run 10%, only dives | Tank today | Deep Run 10%, only dives | Fills the Index: Oxygen / tank | Layer held, only dives |
|---|---|---|---|---|---|---|
| 25 | 10.3B | 14.5B | 3.09B | 6.32B | 14.5B / 5.66B | 3 |
| 30 | 10.9B | 17.7B | 5.33B | 7.85B | 17.6B / 7.32B | 4 |
| 45 | 15.4B | 25.1B | 7.35B | 11.5B | 80.9B / 32.0B | 5 |
| 60 | 50.3B | 34.0B | 14.9B | 15.5B | 92.0B / 44.7B | 6 |
| 80 | 58.6B | 50.2B | 19.9B | 24.2B | 124B / 64.5B | 7 |
| 100 | 77.5B | 85.4B | 22.2B | 38.9B | 160B / 83.1B | 9 |

- **Too small punishes the diver** (2%: Oxygen 56% under today's at 60 h, 40% under at 100 h; the tank a little under too). **Recommended: 10% of the layer's need, no coins** (coins
  of 60 s changed nothing in the model). It is the smallest we tried where even the player who only dives is ahead of today at 100 h; at
  60 and 80 h they are 32% and 14% under. A player who goes back for missing fish is ahead from 25 h on. A layer's first time adds up
  to 0.39 of the deepest layer's need over all layers, so it can't feed itself.
- **The price of 10%:** the tank of the Index-filling diver is 3.7 times today's at 100 h (the diver who only dives 1.75), so the last shop
  steps (a seahorse at 25Qa, the last aura) come in sooner. 6% (118B / 61B for the Index-filler) is the setting if that is too much.
- **x1.25 and x1.5 a layer** with the 10%. Only dives, Oxygen at 100 h / tank / layers held: x1.25 120B / 53.1B / 14, x1.35 85.4B / 38.9B / 9,
  x1.5 71.5B / 32.6B / 6. A gentler ladder passes more milestones, so it pays more.
- **Big milestones break it** (20% of the need and 600 s: seven times the tank at 100 h).
- **Past 50B** (`Oxygen.Cap`) taming is slower (`Tame.CapSlow`): that starts at about layer 8 (51B), where the x1.35 ladder crosses it.

| Layer | Depth | Needs | Earns a second |
|---|---|---|---|
| Land 10 | 1,900 m | 4.65B | $116M |
| 1 | 2,230 m | 6.28B | $157M |
| 5 | 3,740 m | 20.9B | $521M |
| 10 | 5,630 m | 93.5B | $2.34B |
| 15 | 7,520 m | 419B | $10.5B |
| 20 | 9,410 m | 1.88T | $47B |

So a normal run is today's 3 to 5 minutes plus about 20 seconds a layer, so with the x1.35 ladder the 10-minute column is far past
where the model's player stops. The limits above matter for a very strong player or for 2, the Chase. The stairs (layer length, 1.35) are dials.

## Stages, if D is chosen
1. **One Studio test first (half a day):** a client builder that makes 900 boxes a second on a phone, and a fish and rider at y -35,000. If either fails: the straight stack (A) with smaller chunks, or E.
2. Bake the 18 chunks; the joint piece (`chunks.joint`); the mouth from land 10's end.
3. The server's lane and herd from numbers, flat strength. 4. The client builder. 5. Deep mark, layers, milestones, the card. 6. The board, the daily seed.

## Not known
Roblox was not run: no frame rate, memory or network is measured. The pictures are a plain drawing, not its light. How a joint feels at speed, the
fish pathing round chunk props, the joint piece, the barrier without walls on the server, and the Team Create place's streaming switch. The work days are guesses.

## The tools
`tools/endless/`: `census.luau` (a place's parts, `slim.luau` under it), `build_lane.py` (the generator run for chunks), `chunks.py` (cut and measure),
`stack.py` (the stacker and checks), `cost.py`, `economy.py` (about 10 minutes, 4 at a time), `joints.py` and `holes.py` (the joints), `draw.py` and `draw_joints.py` (the pictures), `sheet.py`; for the Underworld `build_lane.py under`, `pack.py ... under`, `odds.py`, `draw_under.py`, `sheet2.py`. In order: `build_lane.py today|chunks`, then pickle
`chunks.purpose` and `chunks.today`, then the rest. Needs numpy and Pillow.
