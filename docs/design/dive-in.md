# The dive-in, and the speed of the sea

Up: [riding feel](riding-feel.md), [the herd](herd.md), [the herd, rethought](herd-revamp.md), [pace](pace.md).
Written 2026-11-16 by the game-code chat on the user's word: "devise a plan to make the dive in feel the best
possible. One thing that needs changing is that fish spawn too far away initially ... Then I'd like you to work
through a much better plan for fish swimming speeds and feel for it all."

**A plan. Nothing here is built.** The first step of part 1 is a number to change and measure, waiting for Studio.

**Was this in the plan already?** Partly.
- **The dive-in: no.** [The refinement](../Refinement.md) rated the dive "strong" and planned three written helps
  for the first minute. Nobody had looked at the ten seconds between the gate and the first fish.
- **Speeds: half.** [The herd, rethought](herd-revamp.md) is a plan for the wild fish, and its first stage was
  built today. Nothing plans what a ridden fish's speed should mean to the player. That is part 2.

## Built and measured 2026-11-16; not yet played by the user
On the user's word the same day. Asked "Should stepping off the start strip itself be the first hop onto a fish?":
"Yes, aim for that". In the repo and in Studio (synced). StyLua, selene and the build pass. Every number is in
`Config.Dive` and is a first go.

### The cause, found by measuring
**The herd's stream began 142 studs inside the lane.** Building it evens the lane's middle out twice, and each pass
repeated the line's first point past its end, which pulls the start inward: 0.4 of `Herd.Smooth` (240) and of the
first pass's 120. So no fish could be in the water for the first 142 studs past the gate, whatever the stocking
said. New fish came in at 142 to 170 studs, already out of a floating hop's reach. This is the user's "fish spawn
too far away initially", and it has been so since the stream was built on 2026-11-13. Fixed in `Lib/Stream.luau`:
past its ends the line is carried on straight. (The lane's far end had the same fault.)

| A player put in the water at the gate | Before | Now |
|---|---|---|
| Nearest fish to the dive point, over 12 seconds | 141 to 148 studs | 24 to 74 studs; 24 to 40 once the room has filled |
| Fish within 100 studs | None, ever | One to five |
| From leaving the dock to sitting on a fish | Never: left floating | **1.75 seconds** (in the water at 0.50, hopping at 0.68, riding at 1.75) |

- Measured by script in Studio: one try of the dive, the character dropped just past the start strip. Not played
  by hand, and the count near the gate still swings (one to five), so the stocking there needs another look.
- **For the tuning chat:** distances along the stream are about 142 studs longer at each end than they were.

| Step of the plan | What was built | The numbers |
|---|---|---|
| 1. Stock the first room | The first 120 studs always hold eight fish | `Spawn.BoardSlice` 8, was 2 |
| 2. Bring them up | Near the gate every fish swims higher, sinking to its place in the herd as it goes. New fish come in at that height | `Dive.Rise` 12 studs, gone by `Dive.RampTo` 220 |
| 4, in a simpler form | **The sea gathers at the gate.** Fish there swim at under half the land's pace and pick up to the whole of it over the first 220 studs. So they linger under the dive point without any fish being held by a rule | `Dive.GateShare` 0.45 |
| 5. The dive is the first hop | Dropping off the dock into the water starts a hop by itself, the way you were walking. It takes the nearest fish in reach without a press, wherever the camera looks | `Dive.AutoHop`, `AutoGrab` 1; `HopDelay` 0.15 s; `GrabAfter` 0.5 s |
| 3. Don't send a first-timer back | A player who has not ridden yet this dive can float by the dock for 20 seconds, not 2.5 | `Dive.FirstDockWait` 20 |
| (found while building) | **A missed hop drowns you, and the sandbox hides that too.** A hop from floating that lands on nothing, before your first ride of a dive, now leaves you floating | `Dive.ForgiveMiss` 1 |

- **Not built:** the plunge (step 6: splash, camera, sound) and a first fish that is always one you can hold.
- **The sandbox's own start is untouched:** its reset puts you among the herd and seats you itself. The new hop only
  starts within 14 studs of the surface, which is where walking off the strip leaves you.
- **To judge it:** walk from the hub through the gate. The N panel has the `Dive` rows. `Dive.AutoHop` 0 gives the
  old dive back.
- **Where it is in the code:** `Config.Dive`; `FishService` (`gateEase`, `gateRise`, `landPace`); `RideService`
  (`Rode`, `DiveHop`, `miss`, the dock's wait); `JumpController` (`diving`, and the hop begun on the change from
  the dock to floating).

### Where fish come in, and how often (the same evening)
The user, after playing it: "fish spawn point needs to be spread out instead of a fixed singular point.
Additionally decrease the spawn rate a bit."

- **Why it was one point.** Two things. New fish came in only within 30 studs of the gate. And with the stream now
  beginning at the gate, its first sample stands in the thickness of the hub's wall, where there is no floor: the
  band was given no width there, and it widens slowly, so the herd was one line down the middle for the whole
  first room.
- **Fixed:** an end of the stream with no floor takes the water of the first sample that has some
  (`Lib/Stream.luau`). And fish come in anywhere in the first 240 studs: `Spawn.EntryAt` 120, was 30, in
  `Spawn.EntrySlices` 2 stretches, was 1.
- **Fewer:** `Spawn.PerThousand` 38, was 44; `Spawn.BoardSlice` 6, was 8. What comes in is what swims away, so
  the only way to have fewer fish come in is a thinner or a slower sea. This is a thinner one, by about a seventh.

| Fish coming into the first 400 studs, a player on the dock, 24 seconds | Before | Now |
|---|---|---|
| Across the lane | All within 15 studs of the middle | From 51 studs left to 53 right |
| Along the lane | 2 to 143 studs from the gate | 0 to 185 |
| How many | 0.92 a second | 0.79 a second |
| Within 100 studs of the dive point | 3 to 4 | 2 to 4 |
| The dive, from leaving the dock to riding | 1.75 s | 1.98 s (one try each) |

## Part 1: the dive-in

### What happens today, read from the code
1. You walk off the start strip at the gate and drop below the water line. You are now floating, with no fish.
2. **The water is 46 studs deep right at the gate.** The herd swims 14 to 26 studs over the floor, the slow fish
   lower. So the nearest fish are 17 to 40 studs straight down from a player floating at the surface.
3. **The first 120 studs of lane are stocked like any other stretch:** about four fish, and never fewer than two
   (`Spawn.BoardSlice`). They are spread over a lane 144 studs wide that opens to 270.
4. **They swim away.** The herd leaves the gate at about 32 studs a second. New fish come in within 30 studs of
   the gate (`Spawn.EntryAt`), fading in where you can see them.
5. **A hop from floating reaches about 60 to 105 studs** (`Jump.GrabNear`, `GrabRange`, at `FreeLaunch` 60).
6. **Floating costs Oxygen:** 4 a second, so a new player has 25 seconds.
7. **Floating at the surface near the dock for 2.5 seconds puts you back on the dock** (`Oxygen.DockWait`,
   `DockRadius` 165: the gate is inside it). The sandbox switches this off, so it has never been felt in Studio.
   In the real game a new player who drops in and hesitates is sent back to the hub.

So the user's "fish spawn too far away initially" is what the numbers say: four fish in a wide, deep first room,
all moving away, and a first hop that has to find one of them going down and forward at once.

### What the best dive-in is
Taken from the reference's first minute ([findings](../Findings.md), rank 1 point 5): its first target can't be
missed, and a new player has tamed a dino 25 seconds after the first prompt.

| Measure | Target | Today (by the numbers, not yet measured) |
|---|---|---|
| Time from touching the water to sitting on a fish | Under 3 seconds | Unknown; depends on luck |
| Fish within 60 studs of the dive point, at any moment | At least three | About one |
| The first hop's length | 40 to 70 studs | Up to the hop's whole reach |
| The first fish | One you can always hold | Any fish of the Shallows |
| Sent back to the dock for hesitating | Never in the first dive | After 2.5 seconds |
| The herd, seen from the hub through the gate | Always streaming past | Thin |

### The steps, in order
Each is judged by the same measurement: a rider put in the water at the gate, the distance to the nearest free
fish logged for a minute, and the time to a first landing over ten tries. Before and after.

| # | Step | What changes | Kind |
|---|---|---|---|
| 1 | **Stock the first room** | `Spawn.BoardSlice` 2 to 8: the first 120 studs always hold eight fish | A number. First |
| 2 | **Bring them up** | Fish in the first 150 studs swim higher, 8 to 16 studs under the surface, and sink to the herd's height as they go | Small code |
| 3 | **Don't send a first-timer back** | No return to the dock until a player has ridden once this dive, or a much longer wait at the gate | Small code |
| 4 | **The waiting shoal** | Five or six easy Commons hold their place just under the dive point until someone lands on one. A new one swims in from behind the gate's kelp, out of sight | Code |
| 5 | **The dive is the first hop** | Stepping off the strip throws you in an arc and pulls you onto the nearest waiting fish, as a hop does. No floating at the start at all | Code. The big one |
| 6 | **The plunge** | A splash, a burst of bubbles, a short push of the camera, one sound, and the fish's kick as you land | Code, small. Needs a sound |
| 7 | **The herd as the advert** | From the hub you see fish streaming past the gate, close and thick | Follows from 1, 2 and 4 |

- **Steps 1 to 3 are the tuning the user asked for.** They can go in as soon as Studio is free.
- **Step 5 is what I would aim at.** In the reference the first act is the fun one: you jump onto the herd. Ours
  makes a new player float, look down, and work out a button. If walking off the strip is itself the first hop,
  the first three seconds of the game are its best part.
- **Step 4 makes step 5 safe:** there is always a fish to land on, and it is always one you can hold.
- Steps 4 and 5 also give the scripted first minutes ([the refinement](../Refinement.md), stream 3) their
  opening, when that is built.

## Part 2, the first speed pass: built and run once (2026-11-16)
Asked what feels wrong about speed, the user picked three of four: **riding feels too slow, every fish feels
alike, the herd looks wrong.** Not the hop. So the plan's "find where it drags" is answered, and this is a first
pass at those three, as dials. In the repo and in Studio; run once by script; **not played by the user.**

| The complaint | What was changed | The dial (all in the N panel) |
|---|---|---|
| Riding feels too slow | Every fish is ridden 15% faster. The herd's pace is not raised with it, so you also pass more of the herd. The view widens sooner with speed | `Speed.Ride` 1.15; `Camera.SpeedFov` 16 from 25 to 90 (was 14 from 20 to 100) |
| Every fish feels alike | A fish's speed is stretched away from its land's pace by half again: a slow kind slower, a quick kind quicker, in the order Hugo's table has them. His table is not touched | `Speed.Spread` 1.5 |
| The herd looks wrong | Each fish of the herd swims a tenth faster and slower than the herd's pace in a slow beat of its own. It never gains or loses ground, so nothing bunches, but no two fish go at quite one speed. Since the morning every fish of a layer swam at exactly one pace | `Pace.CruiseSurge` 0.1, `Pace.CruiseBeat` 5 |

What it does to the first land's fish, ridden (its pace is 46):

| | Hugo's number | Ridden at now |
|---|---|---|
| Boxfish, Pufferfish (the slowest Commons) | 40 | 43 |
| Sergeant Major (the plain first fish) | 46 | 53 |
| Blue Chromis (the quick Common) | 48 | 56 |
| Flying Fish (Uncommon) | 58 | 74 |
| Reef Shark (Epic) | 70 | 94 |
| Seahorse (Rare, slow on purpose) | 42 | 46 |

- **Run once:** a dive onto a Sea Turtle rode at 52 studs a second, where it was 44, past wild fish averaging 29
  (from 16 to 74). So the rider gains about 23 studs a second on the herd, where it was about 12.
- **"The herd looks wrong" was three things in one answer** (too slow, too even, not streaming past). This pass
  takes on "too even" and "not streaming past". If it is something else, the user says.
- **Not done:** how a fish handles (turning, weight) does not differ by kind, so "alike" may need more than
  speed. Nothing on the tag shows speed. The hop was tuned against slower fish, and the tuning chat's timings
  move with all of this.
- **To put any of it back:** `Speed.Ride` 1, `Speed.Spread` 1, `Pace.CruiseSurge` 0.

### Everything faster (2026-11-17)
The user, having played the first pass: "Currently, it all feels very docile ... Everything needs to be faster.
Everything. It needs to feel a lot more wild and a lot more like a rodeo, like trying to wrangle onto the next
fish ... we keep the animations for now and then make them go faster. And then we'll probably have to alter the
bunching and the herd variety ... Go try and do it in a simple way." The camera shakes wait until the speeds and
the animations are right.

Three dials, nothing else:

| Dial | Was | Now | What it does |
|---|---|---|---|
| `Speed.Ride` | 1.15 | 1.6 | Every fish's ridden speed, times |
| `Pace.Land` | 1 | 1.5 | Every land's pace, times: the whole herd faster, each kind still at its share |
| `Animation.Beat` (new) | 1 | 1.2 | Every fish's swim beat, times. The beat already rises with speed, so the swim is about twice as quick as two days ago |

One scripted ride in the first land, the same as before:

| | Two days ago | The first pass | Now |
|---|---|---|---|
| The rider | 44 | 52 (a Sea Turtle) | 66 (a Clownfish, the second-slowest Common) |
| Wild fish near the rider, on average | about 32 | 29 | 40, from 19 to 109 |
| Ground made good | | 46 | 64 |

- The hop is not changed: it leaves at a share of the fish's speed, so it is faster and longer with it.
- **Fewer fish at the gate:** one within 100 studs of the dive point when measured, where there were two to
  four. The faster herd leaves the gate faster. The dive still landed, in 2.4 seconds. To look at with the
  bunching.
- **Not played by the user. Not tried in a deep land,** where the fast layer now swims at over 200 studs a second.

### More fast fish, and bolts (2026-11-17)
The user, having played "everything faster": "needs more variety in speed with more fast fish and some really
fast ones".

- **Why there were few.** A wild fish was fast only if its kind was, and few kinds are: about one fish in ten.
- **Now any fish of the herd may be born swift.** Three in ten are born fast: they swim up in the fast layer at
  the fast ones' pace (1.3 of the land's). One in ten is a **bolt,** at 2.4 of the land's pace: about 170 studs a
  second in the first land. Each is a little faster or slower than the next.
- **Riding one is faster too:** a fish born fast is ridden a fifth faster than its kind, a bolt half as fast
  again. So the fast ones are worth wrangling. The fish's `Swift` attribute carries it.
- **Kinds are further apart to ride:** `Speed.Spread` 2, was 1.5.

| Dial | Value |
|---|---|
| `Pace.FastShare`, `Pace.BoltShare` | 0.3, 0.1 |
| `Pace.Bolt` (a bolt's pace, of the land's) | 1.8 (2.4 at first: the user found some "darting past insanely quick"; now about 125 studs a second in the first land, was about 165) |
| `Pace.FastVary` | 0.15 |
| `Pace.FastRide`, `Pace.BoltRide` | 1.2, 1.5 |

Measured in one run at the first shares tried (0.22 and 0.07): of the herd's fish in the whole sea, 24 in 100
were fast and 7 in 100 bolts, as asked. **But near the rider only 3 of 58 were,** at 94, 103 and 173 studs a
second. A fast fish soon swims out of sight, so at any moment few are in view however many are made. The shares
were raised for that; it has not been measured again. If they are still too rare to the eye, the fix is in
where fast fish are put, not in how many are made: that belongs with the bunching.

- **Not done:** nothing on a fish's tag says it is swift; a bolt looks like its kind, only faster.
- A Sergeant Major rode at 74 studs a second in this run. The dive took 1.97 seconds.

### Less bunching (2026-11-17)
The user: "needs less bunching to make it more difficult to get from animal to animal. This isnt just a spawn
rate decrease i dont think."

Measured by `tools/studio/bunch_log.luau`: a scripted dive, then the herd read twice a second while riding.
"Ahead" is free fish in front of the rider; a hop reaches 60 to 150 studs.

| | Before | Spacing only | Spacing, heights, and a thinner sea |
|---|---|---|---|
| Free fish ahead within 60 studs | 0.8 | 0.5 | **0.4** |
| Within 100 studs | 2.0 | 1.2 | **1.0** |
| Within 150 studs | 3.6 | 2.7 | **2.2** |
| No fish ahead within 100 studs | 20% of looks | 27% | **31%** |
| The nearest free fish ahead | 62 studs | 91 | **86** |
| Free fish within 300 studs | 14.2 | 11.4 | **9.9** |
| A fish's nearest neighbour | 52 studs | 61 | **64** |
| Pairs of fish within 30 studs of each other | 1.3 | 1.2 | **0.7** |

One ride each (the last of 35 seconds, the others 20), and rides differ, so read it as "about half", not to the
digit. A run between the second and the third, with the heights fix and the sea at 28, read no better than the
start: the thinner sea is what moved the numbers most.

What was changed:

| Change | Was | Now |
|---|---|---|
| The clear water a new fish wants round it (`Spawn.Space`, `SpaceByLength`) | 32, 1.2 | 56, 1.6 |
| Places tried for a new fish (`Spawn.Tries`) | 14 | 24 |
| Height counts less when a new fish's room is measured (`Spawn.LiftRoom`, new) | 2 | 0.5 |
| Fish at different heights give way to each other too (`Herd.GiveHeight`, new) | 2 studs | 24 |
| How far and how fast they give way (`Herd.GiveSide`, `GiveAlong`, `GiveRate`) | 18, 44, 5 | 30, 64, 8 |
| Fish per 1,000 studs (`Spawn.PerThousand`) | 38 | 20 |
| The speed that gives the hop its whole reach (`Jump.GrabFullSpeed`) | 120 | 190 |

- **Why the pairs were stubborn.** The herd is three or four layers at different paces, passing through each
  other all the time. A slow fish, a fish of the herd and a fast one could sit one over the other, and only fish
  at one height moved apart. That is fixed, but layers that pass each other will always make and break close
  pairs: the only way to an even spacing that lasts is fish with places in the herd (stage 2 of
  [the herd, rethought](herd-revamp.md)), which is a rebuild.
- **The hop's reach** grew with the speed pass: fish are 1.6 times faster and the reach goes by speed, so it sat
  at its longest nearly always. `GrabFullSpeed` 190 puts it back in step.
- **The first room:** no fish within 100 studs of the dive point at the moment the test dived, three runs in a
  row, though the dive landed each time in about 2 seconds. The gate's stocking was put back (`BoardSlice` 6,
  `GateShare` 0.5) and still read none. To look at.
- **Not played by the user.**

### The hop: a shorter reach, less carried speed, and the outline after a landing (2026-11-17)
The user: "we need a lesser distance to grab onto the next fish when in the air ... we need the jump into the
air to not keep as much momentum from the fish you're currently riding ... when you jump onto a fish the black
outline remains from the fish for 1-2 seconds, not the yellow glow. Just the outline."

| Change | Was | Now |
|---|---|---|
| The hop's longest reach, and its shortest (`Jump.GrabRange`, `GrabNear`) | 150, 60 studs | 105, 45 |
| The share of the fish's speed the hop keeps, and the kick on top (`Jump.Launch`, `HopBoost`) | 1.25, 30 | 0.8, 20 |
| After a landing | The yellow glow flashed white and faded in 0.3 s | The fish keeps its black outline alone for 1.5 s, then it fades in 0.3 (`Jump.LandOutline`) |

- Off a fish ridden at 74 studs a second the hop left at 122. Now it leaves at 79.
- **The outline is its own highlight,** so the lock's glow is free for the next fish the moment you land.
- **The dive's own hop keeps a long reach** (`Dive.Reach` 110), so stepping off the dock still finds a fish.
- **Run once in Studio:** the dive landed in 2.0 seconds; two hops made by key press each landed; after each the
  outline was on with no fill and no yellow glow, and went off after 1.80 seconds.
- **Not played by the user.** With the thinner sea, a shorter reach and a slower hop together, missing will be far
  more common than it was this morning. That is what was asked for; if it overshoots, `Jump.GrabRange` is the
  first dial.

## Part 2: swimming speeds and the feel of speed

### Four different speeds
"Speed" is four things, each set in a different place. They need planning apart.

| | What it is | Where | Today |
|---|---|---|---|
| A | **How fast a fish is to ride** | `Config.FishStats`, by hand (Hugo's table) | 40 to 100 in the first land. Its seven Commons: 40 to 48 |
| B | **How fast the sea moves past you** | `Config.LandPace`, `Herd.SpeedShare`, `Config.Pace`, `Config.Layer` | A land's pace (46 to 116 down the ten lands); slow fish at 0.45 of it, the herd at 0.7, fast ones at 1.3 |
| C | **How fast the hop is** | `Config.Jump` | Leaves at 0.85 of the fish's speed plus a kick |
| D | **What sells it** | `Config.Wake`, `Config.Shake`, the camera | Wakes, a landing kick, a wider view with speed |

### What is wrong, or not known
1. **A better fish does not feel faster in a way you can read.** In the reference a fast mount is asked for by
   name and a slow one cursed; a shop card sells "1.6x SPEED" ([findings](../Findings.md)). Ours has the spread
   (40 to 100 in one land) but nothing shows it: not the tag, not the wild fish's own pace since today (every
   fish of a layer now swims alike), and the Commons a new player rides are all within 8 of each other.
2. **Rarity and speed don't line up.** The Rare of the first land (the Seahorse, 42) is slower than every Common
   but two. That is true to the animal and it may be right for the tank. It also means "rarer" can't be felt.
3. **The first land may simply be slow.** 46 is a third of the last land's pace. Whether a new player's first
   minute feels fast enough is the user's to say; no number answers it.
4. **Today's herd has been played once.** The user called the playtest fine. Hugo's hop was tuned against a herd
   at 0.85 and it is now 0.7; the tuning chat's timings moved with it. Nobody has re-measured either.
5. **Speed between lands is one list** (`LandPace`). There is no curve behind it and no test that a deeper land
   feels faster and not only harder.

### The plan
| # | Step | What it settles | Kind |
|---|---|---|---|
| 1 | **Measure a dive as it is:** one logged ride a land for lands 1, 2, 5 and 10 (`tools/studio/ride_log.luau`): fish passed a second, targets ahead, time between landings, how long each ride lasts | A baseline, so every later change is judged against a number | Studio, no code |
| 2 | **The user rides the same four and says where it drags** | Which of A to D is the complaint | The user, ten minutes |
| 3 | **Make ridden speed readable:** a fast kind leaves a longer wake and swims in the fast layer; a speed mark on the tag (one to three chevrons), fitted to Hugo's layout | Problem 1 | Small code, with the UI chat |
| 4 | **A speed ladder a land,** proposed to Hugo, not imposed: Commons 0.85 to 1.0 of the land's pace, Uncommon to 1.15, Rare to 1.3, Epic to 1.5, Legendary to 1.7, with named exceptions kept (the Seahorse, the turtles) | Problems 1 and 2. His table stays his | A table, his call |
| 5 | **The land curve:** `LandPace` from a rule (a start, and a gain a land) checked against the hop's reach and the wall of each land | Problem 5 | With the tuning chat |
| 6 | **Sheets and patterns** ([the herd, rethought](herd-revamp.md), stage 2): fish have places, made at the edge of sight in patterns built for the hop: stepping stones, a school, a lone giant | Never fewer than two targets; a rhythm to the hops. The dive-in's waiting shoal is the first pattern | The biggest piece |
| 7 | **More that sells speed:** specks streaming past by speed, the water's sound rising with it, a streak that speeds you up for clean landings | D | Small code each. The streak changes how far a dive goes: the tuning chat weighs it |

- **Steps 1 and 2 come first because the complaint is not yet located.** "Speeds and feel" could be the ride, the
  herd, the hop or the dressing, and each has a different fix.
- **Step 6 is the one that changes the dive most.** It is also what part 1's waiting shoal needs, so the two parts
  meet there.

## What I need from the user
1. A yes to part 1's steps 1 to 3 once Studio is free. They are small and can be turned back.
2. Whether step 5 (the dive is the first hop) is the direction.
3. For part 2: after ten minutes of riding lands 1, 2, 5 and 10, one line each on what drags.
