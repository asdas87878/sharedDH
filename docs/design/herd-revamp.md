# The herd, rethought: speed, spawning and paths

Up: [the herd](herd.md), [pace](pace.md), [the loop review](loop-review.md). Written 2026-11-16 by the game-code
chat on the user's word: how could fish speed, spawn patterns and paths be revamped so everything works better,
feels faster, and groups less. Two rides were measured for it.

**Stage 1 is built (2026-11-16, on the user's "go ahead with making it feel better").** What was built and what
it measured is the next section. The rest of the note is the proposal as it was written; stages 2 and 3 are not
built.

## Built: stage 1
| | Before | Now |
|---|---|---|
| New fish made within 500 studs of the rider, in 58 seconds | 56, the nearest 76 studs away | 7, all at the lane's start as the ride began |
| Free fish ahead within 300 studs | 5.5 on average, from none to eight | 7.3 on average, from four to twelve. Never fewer than four |
| Fish within 200 studs | 8.9 | 9.2 |
| Pairs of bodies overlapping, in sight | 0.41 | 0.27 |
| Two fish of one layer overlapping | Not told apart | 0.04 |
| The herd against the rider | Cruisers 25 slower | Cruisers 22 slower, plodders 40 slower, the fast ones 7 faster |
| Ground made good | 62.6 studs a second | 76.4 |

The same 58-second ride through the first two lands, logged by `tools/studio/ride_log.luau`. The last row is not a
fair comparison: the key presses were not the same as in the first ride, and more of this ride was in the air.
The overlap count is made again from scratch; the first ride's script was not kept, so read 0.41 against 0.27 as
"about a third fewer", not to the digit.

What was built:
1. **One pace a land.** A wild fish swims at a share of its land's ride pace (`Config.LandPace`: 46, 55, 60, 65,
   82, 90, 100, 104, 112, 116), not of its own ridden speed. The pace eases over 240 studs at a border. Hunters
   alone keep their own speed.
2. **Three layers.** Plodders at 0.45 of the pace, low. The herd at 0.7, over them. The fast ones at 1.3, over the
   herd. Each layer is the water the fish's whole body keeps to (`Config.Layer`), with clear water between.
3. **Darters keep a place.** A burst carries one ahead and up over the fish in front; it drifts back slower than
   the herd, then swims with the herd until the next burst.
4. **The sea flows out of sight.** A parked fish swims on as a number and comes back into the water where it has
   got to, already at speed. The old "new place for a fish that left sight" is gone.
5. **No fish made in sight.** A new fish is made only 500 studs or more along the lane from every player. The one
   exception is the lane's start, where the herd begins: fish come in at the gate.
6. **Every arriving fish fades in** over 0.6 seconds on each player's own machine (`ArriveController`). The water's
   fog ends at 1,550 studs, so 500 and 700 studs away are not out of sight; they were popping in before too.
7. **Wakes.** A white streak from every fish's tail, as long as the fish is fast (`Config.Wake`).
8. **The landing kicks.** No dip: the fish goes from the herd's pace to its own in 0.12 seconds, and the view's
   kick and the speed lines come with the landing (`Ride.StartleSlow` 1, `StartleHold` 0.12, `RampTime` 0.4).
9. **More fish:** `Spawn.PerThousand` 44, was 30. In the water that is about 29 to 33 fish to 1,000 studs in
   the first six lands and about 41 in the last four (narrow water and `Spawn.MaxTotal` trim it), where it was
   about 20. The still sea bunched up ahead of a moving rider to
   about twice what it was stocked at. The flowing sea doesn't, so it is stocked nearer what a rider used to see.

What the measuring changed on the way:
- **Layers set by the fish's middles did not separate them.** Every overlap left was a plodder under a fish of the
  herd. Setting the layers by whole bodies, with a gap, cut those to a third.
- **The whole sea flowing all the time could not be kept stocked.** Every land lost fish at one end and wanted them
  at the other, for nobody: about 25 fish a second to build. So only the lands with a player in them or within
  1,500 studs flow (`Spawn.LiveReach`). A land nobody is near stands still, whole, and starts again whole.
- **Making a fish takes 2 to 8 milliseconds,** so they are made one a frame, not all in one go. The top-up's own
  pass takes 3.5 ms every 2 seconds with 900 fish.
- **A plain fish that leaves its lands out of sight comes in again at the start of its own** (`Spawn.WrapHome`).
  It happens less than hoped: 17 times in the ride against 174 fish built.

Not done, or not known:
- **Not played by the user.** Whether it feels faster is theirs to say.
- **One player only.** Two riders near each other, and a full server, are not tried.
- **Phones:** not tried. A wake is one Trail a fish.
- **Hugo's hop** was tuned to a herd at 0.85 of each fish's speed. It reaches further against a herd at 0.7.
- **The tuning chat's lengths in seconds** move with the herd's pace and the landing's kick.
- **With players in every land,** fish that have swum past their own lands can't be taken away while someone can
  see them, so kinds will mix further down than they do with one player.

## The short version
1. **The sea is stocked as a still thing, and it is a moving one.** Fish are counted in fixed stretches of lane,
   then swim out of them. So stretches near a rider are always draining and being refilled, in plain sight: about
   one new fish a second appears within 500 studs of the rider.
2. **Even spacing can't last while neighbours swim at different speeds.** A new fish is placed with room round it,
   and seconds later the fish round it have gone at their own pace. In one land wild fish swim at 26 to 63 studs a
   second, before any of the "characters" are added. Spacing made at the spawn is gone in about five seconds.
3. **The fix is one idea: the herd is a sheet that moves, and fish have places on the sheet.** Everything on a
   sheet moves at one pace, so spacing put into it stays. Variety comes from two or three sheets at different
   paces and heights, and from fish that leave their place for a moment and come back.
4. **Then fish are made at the edge of sight and nowhere else,** in patterns chosen for the hop: a line to chain
   along, a school, a lone giant with clear water.
5. **Fast is mostly what goes past you.** The rider already averages 62 studs a second, as fast as the reference.
   What is missing is things streaming by: a slower herd, wakes behind every fish, and a landing that kicks
   forward where today it dips.

## What was measured
A 58-second ride with a hop every 5 seconds, through the first two lands, logged on the server four times a
second.

| | The ride as the game is |
|---|---|
| Ground made good | 62.6 studs a second |
| Riding / in a hop | 55% / 45% of the time. Riding speed 58.8 on average |
| Wild fish against the rider | Cruisers 25 slower, darters 29 slower, plodders 42 slower |
| Fish within 200 studs | 8.9 on average |
| Fish ahead within 300 studs | 5.5 on average: none in 4% of looks, one in 4%, eight in 18% |
| Pairs of bodies overlapping, in sight | 0.41 at any moment. Pairs within 12 studs: 2.05 |
| **New fish made within sight** | **56 under 500 studs in 58 seconds, the nearest 76 studs away** |
| Fish woken ahead | 71, at about 650 studs |

- **The rider is not slow.** 62.6 a second is the reference's riding pace (54 to 57 of its metres).
- **The targets ahead swing between none and eight.** That is the grouping, in a number.
- **Fish appear out of nothing near the rider, all the time.** The rule that keeps a new fish 160 studs from a
  player only lowers a place's score; the emptiest stretch of lane is very often the one the rider is in.

A second ride was meant to test "one pace for every fish": every character's share set to the herd's 0.85, and
new fish asked to keep 650 studs away.
- **It did not make one pace.** Wild fish near the rider still swam at 26 to 63, because a wild fish's speed is a
  share of its own ridden speed, and one land's fish are ridden at 40 to 100.
- **It did not stop the fish appearing:** 53 new ones under 500 studs again.
- Overlaps were higher (1.14), but the run also put the hunters down in the herd and had more fish near, so it
  proves nothing about pace. **A clean test of one pace has not been done.**

## Why it groups: four causes
1. **Still stock, moving fish.** `FishService` keeps a wanted number in each 120-stud stretch. Every active fish
   swims on at 26 to 110 studs a second, so the stretches round a rider empty at the back and fill at the front,
   and the top-up answers by making fish in the emptiest stretch. Where a fish is made has nothing to do with
   where the rider is looking or going.
2. **A speed for every kind.** Wild speed is 0.85 of the kind's own ridden speed (and since 2026-11-13, times its
   character's share). Any two neighbours close or part at up to 40 studs a second. Giving way moves a fish aside
   at 5 studs a second: with a second or two of warning that is 5 to 10 studs, and two bodies need 25 to 30.
3. **The edge of the world is 700 studs away and moves with the rider.** Beyond it fish stand still. Ahead of the
   rider they wake and swim off; behind, they are left and parked. So the sea round a rider is always being made
   of fish that were placed for a sea at rest.
4. **Nothing is placed for the hop.** A hop off a 46 fish carries 154 studs before the pull-in and can reach about
   100 studs from there. Whether a fish is there is chance.

## The idea: sheets
Think of the herd as a sheet of water sliding down the lane at one pace. A fish has a place on the sheet. Its
place in the lane is its place on the sheet plus how far the sheet has slid.

- **Spacing lasts.** Two fish on one sheet never close or part. A pattern put on the sheet arrives at the rider as
  it was drawn.
- **Speed variety is two or three sheets,** at different paces and heights, sliding over each other:

  | Sheet | Pace (of the land's ride pace) | Height over the floor | Who | Share of the fish |
  |---|---|---|---|---|
  | Slow | 0.45 | 5 to 10 | The plodders: turtles, puffers, the vast | 15 to 20% |
  | Herd | 0.7 | 10 to 20 | Nearly everyone | 70% |
  | Fast | 1.1 | 24 to 34 | The zoomers | 8 to 10% |

  Sheets at different heights can't run into each other. Seen from a fish, the other sheets slide past: layers
  moving at different rates are the strongest cue of speed there is. And height then means something: up for the
  fast ones.
- **"The land's ride pace"** is one number a land: what its commonest fish are ridden at (46 in the Shallows, 56
  in the Reef, 60, 64, 85 and on). A wild fish's speed stops being its own. Its own speed is what you get when you
  ride it.
- **A fish may leave its place and come back.** A darter surges 60 studs ahead of its place in a second and drifts
  back over three. A plodder lurches. That is all the life the "characters" have now, with no drift, so no
  bunching.
- **Hunters stay an event,** as built: high over everything, one at a time, and the visit.
- **The herd at 0.7, not 0.85.** At 0.85 a rider who is only riding gains 7 studs a second on the herd. At 0.7 it
  is 14, and with hops about 30: twice as many fish go past, and a landing takes a fish from 0.7 to its full speed
  under you, which is a kick you can feel.

## Spawning: at the edge of sight, in patterns
- **A window, not a sea.** Only the sheets' cells within about 700 studs of a player hold fish. A cell's fish is
  made as the cell comes into the window, **ahead of the rider at the edge of the fog or behind them**, never
  inside it, and let go as it leaves. What a cell holds comes from the cell's own number and the server's seed, so
  it is the same for every player and needs no storing.
- **What kind:** rolled as now, by the mix of the land the cell is in as it enters the window. Size, colour, the
  grand fish rule and the visit stay as they are.
- **Far fewer fish:** 60 to 100 a player in place of 600 in all, most of them parked. That matters on a phone and
  on the server.
- **Patterns.** A stretch of sheet (400 to 600 studs) is drawn from a small set, by land and by how the dive is
  going. Their spacing comes from the hop's own numbers:

  | Pattern | What it is | What it is for |
  |---|---|---|
  | Stream | Even, staggered, 3 lines across | The default |
  | Stepping stones | 4 or 5 fish in a line, 90 to 130 studs apart | A chain: one hop each, in rhythm |
  | Fork | Two lines parting: plain fish one side, something better the other | A choice you can read ahead |
  | School | 6 to 8 Tiny fish close together, moving as one | Grouping on purpose: any of them will do |
  | Lone giant | One grand fish with 120 studs of clear water | The thing to admire and go for |
  | Gate | A row you can't hold with one gap you can | A land's border, seen coming |
  | Rest | Few fish, far apart | A breath, and a risk |

- **Why 90 to 130.** A hop off a 46 fish is 154 studs on when the pull-in starts, 1.94 seconds later. A herd at
  0.7 has slid 62 studs in that time. So the next fish should sit about 90 studs ahead on the sheet. Off a 75
  fish: 243 less 115, about 130.
- **Always a target.** With a fish every 90 to 130 studs on each of three lines there is one inside the hop's
  reach at the end of every glide. Today there is none ahead in 4% of looks.

## Speed: what would make it feel faster
The rider's pace is already the reference's. In order of what I think each is worth:
1. **A slower herd (0.7)** and the sheets: more goes past, steadily.
2. **Wakes.** Every moving fish leaves a short trail of bubbles, drawn on each player's own machine for the fish
   near them. The reference's dinos all leave dust: it is how you read their speed and their line from behind.
   Ours leave nothing.
3. **The landing kicks.** Today a landing holds the fish at 0.8 of its speed for 0.3 seconds
   (`Ride.StartleSlow`) and it takes 1.2 seconds to come up to speed (`Ride.RampTime`); the tuning chat found
   that on a 2.5-second ride 1.2 seconds are the fish getting going. Proposed: no dip, 0.4 seconds to speed, and
   the burst that is already there (`Ride.Surge` 1.25) felt at once.
4. **A streak.** Each landing made without floating or crashing adds a little ride speed (4%, up to 40%), shown on
   the HUD, lost on a mistake. The dive gets faster the better you play. It changes how far a dive goes, so it is
   the tuning chat's to weigh.
5. **More to pass close by:** specks and bubbles streaming past the camera by speed, the view widening more with
   speed (it widens 14 degrees at 100 now), the pitch of the water's sound.
6. **Ridden speeds themselves** (Hugo's table) I would leave. One land's fish run from 40 to 100: that spread is
   the reward for catching a good one.

## Paths
Keep the stream: the smooth spine, the band, the rounded floor ([the herd](herd.md)). On it:
- **Lines, not a scatter.** Three or four fixed lines across the band on the herd's sheet. Fish on a line show the
  line; wakes make it plain.
- **Layers by pace,** as above.
- **Necks stay funnels:** the band narrows and the lines close up.
- **Currents (later):** ribbons down the lane where everything, the rider too, moves a quarter faster, seen as a
  stream of bubbles. A reason to steer.
- **Props:** since Hugo's pass they fade as a fish goes through and only big fish break them. The gentle bend
  round the biggest can stay or go; it no longer matters much.

## How to get there
| Stage | What | Size | Risk |
|---|---|---|---|
| 1 | In today's code: one pace a land; the three layers by height; darts as a surge and back; no fish made within 500 studs; the landing's kick; wakes | 2 to 3 days | Low. Each is a switch that can be turned back |
| 2 | Sheets and the window: fish have places; cells make and let go fish at the window's edge; the patterns | 4 to 6 days | Medium. It replaces the stocking half of `FishService`. The stream, riding and the hop are untouched |
| 3 | Wild fish moved by each player's machine from the same numbers; the server checks a landing by the formula | 5 or more | Higher. Big gain on phones and in traffic. Only if stage 2's numbers say it is needed |

**Stage 1 first, measured with the same ride.** It should show: no new fish under 500 studs; overlapping pairs
well under 0.4; never fewer than two fish ahead. If one pace and layers don't cut the overlaps, stage 2 is still
right for the spawning, but the reason would be different from the one given here.

## What this costs and risks
- **The sea stops being one lasting place.** A rare fish you saw and lost is not swimming on somewhere. For a game
  of 15-second to two-minute dives I think that is no loss, and the announcement of a rare spawn can still be real.
- **Wild speed no longer tells you the ride.** A fast kind is on the fast sheet, high up; a Common and a Rare on
  the herd's sheet swim alike. The tag tells them apart, as now.
- **Hugo's hop is tuned to a herd at 0.85.** At 0.7 a hop gains more on the herd (about 90 studs, 78 now). Its
  reach and air need another look after stage 1, with him.
- **The tuning chat's numbers** (how long a land takes, how many fish a dive lands on) all move with the herd's
  pace and the landing's kick.
- **Two players near each other** share a window; with the cells' own numbers they see the same fish. Not built,
  so not proven.

## Open, for the user
1. **Go with stage 1?** It is the cheap half and it is measurable.
2. **The herd at 0.7:** right, or should it stay nearer the reference's 0.85?
3. **Sheets by height:** slow low, fast high. Or should the fast ones run at the sides?
4. **The streak** (4): wanted?
5. **Patterns:** which of the seven first? I would start with stream, stepping stones, school and lone giant.
