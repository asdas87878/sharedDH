# Endless: what comes after the Underworld

A study with options for Hugo (2026-11-25, NULLROOM e1). **Nothing is built in the game and nothing is decided.** Hugo: "I need a
loop for gameplay after reaching last stage, can you make map go basically infinite? this can be a loop of parts of the area
stacked in a random way, find out what works best and let me decide."

The sheet, with three seeds drawn: [endless-options-1.png](../attachments/endless-options-1.png).

## The answer
**D + 1.** D, the Spiral: random chunks from our own map generator, winding down round a column, one seed shared by the
server, each player's own machine building only the part round them. With 1, the Deep Run: fish x1.35 stronger a layer, small
milestones, a landmark every 5 layers, the DEEPEST DIVERS board. A cheap first step exists: the stack straight on, without the spiral.

## Questions for Hugo (four)
1. **Which map: A, B, C, D or E?** We would take D.
2. **Which game on it: 1, 2, 3, 4 or a mix?** We would take 1, then 3. No rebirth yet.
3. **What may the layers look like:** (a) all ten lands mixed, or (b) only deep, dark looks, a new set? We would take (a) first.
4. **Who gets in:** (a) only past land 10 (about 21 hours in for a free player, our model), or (b) also a gate in the hub for
   everybody, with fish by your own strength? We would take (a).

## What was measured
All offline: from `~/Documents/RideAFish/ride-a-fish-map.rbxl` as saved 2026-11-25 00:11, the map generator and `Config`.

- **The lane today:** 23,500 studs, 104,211 map parts (105,706 base parts counted in the saved place, 54,002 surface pictures), end at
  z 23,099, y -2,227. The generator's lane and the place's are the same line. **`StreamingEnabled` is false in the saved file**, so every player would get the
  whole map (the Team Create place can differ; it can't be read offline).
- **Pace:** 175 studs a second: land 10's ridden mean (109.9) x `Config.Speed.Ride` (1.6). 10 / 30 / 60 minutes is 105,000 / 315,000 /
  630,000 studs, 87 / 262 / 525 chunks of 1,200.
- **Chunks cut from today's lands** at the 39 deep necks (76 ends with mirroring): the lane's edge jumps 129 studs at a typical joint, 287
  at the ninth decile, 479 at worst; **1 pair in 20 fits within 24 studs and 2 ends fit nothing.** The floor joins fine (0.65 at
  most), once each chunk carries its floor 48 studs past its ends. So real cut-ups look broken at the sides, or need a hiding frame at every joint.
- **Chunks made by our generator** (`tools/endless/build_lane.py`: `greybox.py` run in memory with two chunks a land, both sides
  pinching together at each end, a straight 6 degree slope there): **every pair fits. Edge step 0, floor step 0.28 at most.** What still
  shows: wall tops behind the neck differ by a median 21 studs, and where the look changes the floor's edge is a sawtooth (the
  floor is tiles on one world grid). A plain sill across the neck covers it; not made yet.
- **A chunk:** 4,734 to 8,155 parts (mean 6,250, of them 3,267 in props), 3,031 pictures. About 1,800 are in props with no box over 7
  studs, which a rider at this speed may never read: the first thing to cut. 1,200 studs long, 6.9 s, 126 m down.
- **The stacker** (`tools/endless/stack.py`): same seed, same run, twice. No shape again within 8 chunks. 60 seeds of 90 chunks: no coil of the
  spiral within 950 studs across and 750 in height of another. (Coils are about 2,100 studs apart in height; the canyon is 470 high.)

| | 10 min | 30 min | 60 min |
|---|---|---|---|
| Chunks | 87 | 262 | 525 |
| Spiral: largest x or z / lowest y | 27,350 / -13,074 | 27,611 / -35,146 | 27,611 / -68,317 |
| Spiral: worst step of a position | 0.002 | 0.004 | 0.008 |
| Straight on: z / worst step | 120,000 / 0.008 | 316,000 / 0.031 | 606,000 / 0.063 |
| A shape is back after (mean / least) | 16 / 9 chunks | 18 / 9 | 18 / 9 |
| New shape + hand + look, share of chunks | 86% | 61% | 41% |

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
| Seams | fixed by generator chunks; cut-ups do not fit | none inside a land; one at each lap | as D | 0 / 0.28 | 0 / 0.28 |
| Parts | +225,000 for 36 chunks, sent to everyone | 0 new if shared, +106,000 a lap if built | 19,000 near one rider, 150,000 for 8 apart, all on the server | server 0, a player 19,000 (max 24,000) | a player about 19,000 |
| Far from zero | only as long as it is | 120,000 at 10 min | the same, unless the world slides, which 8 riders can't share | x, z under 27,700; y grows | never grows |
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
   it. First time at a layer: 2% of its need in Oxygen and 60 s of its coins. Every 5 layers a landmark (a gate and a chest, later a
   boss). 1 layer in 6 is rich: gold (better colours), giants (bigger sizes) or a shoal. It ends as a dive does now, with a depth card and your best.
   Board: DEEPEST DIVERS, in l1's list with `On` 0 because a client moves its own character: the server must first
   check the depth against the pace it allows.
2. **The Chase.** Fish as they are; a dark cloud comes up behind and speeds up. Skill, so it never ends by itself and a new player may
   enter. Pays score and small chests. Risk: a side game. The one we studied ([Ride a Dino deep](../reference/ride-a-dino-deep.md),
   "Endless mode") paid a special coin for permanent power and its creator seen on video played it once; its player count went on falling.
3. **Daily Trench.** The date is the seed: everybody rides the same layers, the board is today's, three goals. Goes with 1 or 2, almost free
   after D. With saving off, its board is this server's, as the other boards are.
4. **Rebirth (only an option).** Give back Oxygen and coins at layer 10, keep the Index and the fish, gain +x% for good. Not needed now:
   after 100 hours our model's player has seahorse 10 of 12, aura 11 of 12 and layer 7.

## The economy, in numbers
`tools/endless/economy.py`: the free player of `tools/balance/rad_economy.py` with layers under land 10, 5 seeds, the medians.

| Hours | Tank a second today | Deep Run x1.35 | with milestones x10 | Max Oxygen today | Deep Run | Layer held |
|---|---|---|---|---|---|---|
| 25 | 3.09B | 4.88B | 15.7B | 10.3B | 10.8B | 2 |
| 30 | 5.33B | 6.22B | 19.0B | 10.9B | 12.1B | 3 |
| 45 | 7.35B | 8.14B | 31.6B | 15.4B | 17.0B | 4 |
| 60 | 14.9B | 11.2B | 59.5B | 50.3B | 22.1B | 5 |
| 80 | 19.9B | 15.1B | 109B | 58.6B | 30.4B | 6 |
| 100 | 22.2B | 20.9B | 159B | 77.5B | 46.7B | 7 |

- **No break with small milestones:** a fish earns need x 0.025 and can only be tamed under your own Oxygen, so the tank can't run ahead. Here the diver's
  tank is a little under today's at 60 to 100 h, because in the model they dive deep instead of finishing land 9 and 10's Index sets.
  x1.25 and x1.5 give the same tank; they only change how many layers (10 or 5 at 100 h, against 7).
- **Big milestones break it** (x10: seven times the tank at 100 h), so the milestones must stay small.
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
2. Bake the 18 chunks; the sill; the mouth from land 10's end.
3. The server's lane and herd from numbers, flat strength. 4. The client builder. 5. Deep mark, layers, milestones, the card. 6. The board, the daily seed.

## Not known
Roblox was not run: no frame rate, memory or network is measured. The pictures are a plain drawing, not its light. How a joint feels at speed, the
fish pathing round chunk props, the sill, the barrier without walls on the server, and the Team Create place's streaming switch. The work days are guesses.

## The tools
`tools/endless/`: `census.luau` (a place's parts, `slim.luau` under it), `build_lane.py` (the generator run for chunks), `chunks.py` (cut and measure),
`stack.py` (the stacker and checks), `cost.py`, `economy.py`, `draw.py` (the pictures), `sheet.py`. In order: `build_lane.py today|chunks`, then pickle
`chunks.purpose` and `chunks.today`, then the rest. Needs numpy and Pillow.
