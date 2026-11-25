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

### The lock (2026-11-17)
The user: "we need to alter the lock on mechanism, it still locks onto ur current fish or fish near the bottom of
ur screen too much, now it is also too hard to get to the next fish. I think the tolerance for how far it reaches
is vaugley okay but we need some new ways to make it feel smoother, more locked and responsive. Needs to work
better for fish that come by fast, ones that are more high up ... if you lock onto a fish even if it goes outside
of your boundaries you keep locked onto it for a small window of time to provide slightly more leeway".

**The cause of the first complaint.** The camera looks at the rider, so the aim's line runs through the rider's
own place. A fish right under you, the one you just left most of all, sat dead on the aim.

| Change | The dial (`Config.Lock`, all in the N panel) |
|---|---|
| The fish you just left is not locked at all until the hop's last chance | `LeftBan` 1; `LeftPenalty` 2 in the last chance |
| A fish must be ahead of you, the way the camera looks across the water: not under you or behind | `Ahead` 8 studs |
| "Ahead" is judged where the fish will be in a moment, against your own speed: a slow fish you are about to fly over doesn't count, a fast one coming up from behind does as soon as it will be ahead | `AheadLead` 0.6 s |
| The fish already locked may fall a little further back before it is let go | `AheadKeep` 25 studs |
| A fish above the aim is easier to take than one as far below it | `UpEase` 0.6, `DownHard` 1.8 |
| A fast fish is aimed at where it is going | `Lead` 0.2 s |
| **The leeway:** the locked fish keeps the lock for a moment after it leaves the reach or the aim, and a grab in that moment reaches a little further | `Linger` 0.45 s, `LingerReach` 1.12 (the server's `Net.RangeSlack` is 1.3 for it) |
| Quicker to take and to change | `MinHold` 0.3 (was 0.45), `SwitchTime` 0.1 (was 0.15) |

Run in Studio by script: a dive and five hops by key press, the camera not steered.

| | Result |
|---|---|
| Hops that landed | 6 of 6 |
| Looks with the lock on the fish just left | 0, in every hop |
| In the three short hops, looks with the target behind the rider | 5, 5 and 0 of about 45 each |
| In the three long hops | 17, 13 and 20: the last chance, which takes any fish in reach all round once the glide is over |

- **The last chance still takes a fish behind you.** That is the safety net (a hop must still be able to reach a
  fish that is near), and it is the only time the lock goes back. If the user wants that gone too, it is
  `Lock.LastChance` 0.
- **Not tested: aiming.** The script pressed keys and never moved the camera, so "smoother" and "more responsive"
  are the user's to judge. Two long hops had nothing ahead to lock for over a second, in the thinner sea.
- Where it is in the code: `src/client/Lib/Lock.luau`; the grab's distance in `JumpController` (`Lock.slack`).

### What was wrong with the hop, and the fixes (2026-11-17)
The user: "needs more tolerance on how far it can hook onto now. Id also like you to just thiink hard and find out
what might be wrong with our system and how to make it feel better."

**Three things were wrong, and all three came from changing one number at a time in a system where the numbers
lean on each other.**

1. **The reach was not what its setting said.** The hook's reach went by a fixed speed (`Jump.GrabFullSpeed`): the
   whole reach at that speed or faster, less below it. Three changes of the same day each cut it without meaning
   to: fish 1.6 times faster made me raise that fixed speed to 190; the hop was set to keep 0.8 of the fish's
   speed, where it kept 1.25; and the reach itself went from 150 to 105. Together, a hop off a 74 fish began with
   a reach of **70 studs, not 105, and ended at 45.** The morning's was 150.
2. **The hop died in a sea that kept moving.** The hop eased to a dead stop, and the herd now swims at 48. From
   about 2.3 seconds in you were slower than every fish of the herd, so every fish ahead was getting away while
   the window ran on for another second and more. A hop gained about 48 studs on the herd in all, where the
   morning's gained about 140.
3. **With nothing dead on the aim there was no lock at all.** The lock took only a fish inside a cone round the
   middle of the view. In the thin sea, a hop flown without steering the camera found nothing for two seconds and
   then fell back on the last chance: three hops of six in one run.

| Fix | The dial |
|---|---|
| The reach goes by the share of its own leaving speed the hop still has, not by a fixed speed: tuning the fish or the hop no longer moves it | `Jump.GrabFullShare` 0.75 |
| More reach: 95 studs while the hop has most of its speed, 55 at its end | `Jump.GrabRange` 95, `GrabNear` 55 |
| The hop eases down to half its leaving speed, about the herd's pace, not to a stop. The fall is as it was | `Jump.StopShare` 0.5 |
| An assist: with no fish under the aim, the lock takes the fish ahead nearest to the aim. Any fish that is aimed at still beats it, so aiming chooses | `Lock.Assist` 1, `AssistAngle` 70 |

The hop off a 74 fish, by the numbers:

| Seconds in | Speed, before | Reach, before | Speed, now | Reach, now |
|---|---|---|---|---|
| 0 | 79 | 70 | 79 | 95 |
| 1 | 77 | 69 | 78 | 95 |
| 2 | 60 | 64 | 70 | 95 |
| 2.5 | 42 | 58 | 61 | 95 |
| 3 | 21 | 52 | 50 | 76 |
| 3.5 | 4 | 46 | 42 | 59 |

Run in Studio by script (a dive and five hops by key press, the camera not steered):

| | The lock rework alone | With the reach and the stop fixed | With the assist as well |
|---|---|---|---|
| Hops that landed | 6 of 6 | 5 of 6 | 6 of 6 |
| Hops with a lock from the start | 4 of 6 | 3 of 6 | 5 of 6 |
| Hops under 2 seconds | 3 | 1 | 4 |
| Looks with the lock on the fish just left | 0 | 18, in one last chance | 0 |

- One run each, and runs differ: the middle column is not worse than the first, it is noise. Read the last
  column as "locks at once nearly always".
- **Still not known:** how any of it feels with the camera steered. That is the user's.
- **What I would look at next, if it is still not right:** the camera rests 30 degrees down in a hop, so the
  middle of the view points at the water 35 studs ahead and far fish sit high on the screen; and the sea is at
  20 fish to 1,000 studs, which may be thinner than the hop now wants.

### The plunge (2026-11-17)
The user: "how can we make the initial dive better? Instantly, I don't like how far up you are in the first zone
after you dive in. I also think maybe we could make it so that when you first dive in, some VFX, a few bubbles,
your camera follows a certain direction just for the dive in so that it feels and looks better."

**Why you were so far up: two causes.**

1. Fish at the gate were held 12 studs above their place in the herd (`Dive.Rise`), so the first fish was near the
   surface on purpose.
2. The dive's hop was an ordinary hop, and an ordinary hop rises 20 studs. Measured: you went in to 21 studs
   under, and the hop then took you back up to 12 under before the pull-in. The dive went up.

| Change | The dial (`Config.Dive`, all in the N panel) |
|---|---|
| Fish at the gate swim at their own depth in the herd | `Rise` 0 (was 12) |
| The dive's hop goes down, not up: no rise, and 10 studs deeper over 0.6 seconds | `Plunge` 10, `PlungeTime` 0.6 |
| Bubbles thrown out at the surface where you went in, and a smaller burst round you | `Splash` 46, `SplashReach` 13 |
| A splash sound | `SplashSound` 0.7 |
| Bubbles stream off you all the way down | `Trail` 1 |
| A shake as you hit the water | `Shake` 0.8 |
| The view kicks wider | `Fov` 9 degrees |
| The view turns down the lane and tips down at the fish below, for the dive only. It goes back to the riding view at the landing. Touch the mouse and your own look takes over | `Camera` 1, `CameraPitch` -34 |

One scripted dive in Studio, before and after (the surface is at -3, the floor at the gate at -46):

| | Before | Now |
|---|---|---|
| Depth when the hop begins | -21 | -19 |
| Depth half a second in | about -12 (it rose) | -33 |
| Depth at the landing | -37 with `Rise` 0; about -25 with `Rise` 12 | -38 |
| Dock to riding | 1.43 s | 1.46 s |
| The view's tilt in the hop | -22, then -14, then -28: it did not hold | -34 all the way |
| The view after the landing | -12 | -12, reached in about half a second |
| Widest view | 85 | 85 |

- **Why the tilt did not hold at first.** The camera is kept under the water's surface. With the rider rising to
  12 under there was no room above for a camera tipped 34 degrees down, so it gave the tilt up. Going down fixed
  that. The hop also pulled the tilt to its own -30; the dive's hop now rests at `CameraPitch`.
- **Not seen by eye.** The numbers are from a script. The bubbles, the splash and the shake ran (the trail's
  emitter was on for the whole plunge) but nobody has looked at them. How it looks and feels is the user's.
- **If it should go deeper still:** `Plunge`. The first fish is 35 to 41 studs under, about 8 above the floor.
- Where it is in the code: the dive's hook and the flight in `JumpController` (`plunging`, `plungeDepth`); the
  hop's own tilt in `RideController.look(yaw, pitch, true)`.

### Bolts slower again, and the stun on hitting an object (2026-11-17)
The user: "the super fast fish are still too fast. Impossible to grab when theyre that fast. Now the next step is
to fix that, make it so that when you run into an object as a smaller fish, instead of the object just fading out
as you ride into it, it needs to stunt you for a moment then fade out."

**The bolts.** The earlier cut (2.4 to 1.8) was judged against the wrong number. Measured in land 1:

| | Studs a second |
|---|---|
| The herd | 46 to 56 |
| You, on a common fish | 55 to 66 |
| Your hop, as it leaves | about 73 |
| Fast fish, before | 76 to 103 |
| Bolts, before | 105 to 143: 32 to 70 faster than the hop |
| Fast fish, now | 81 to 99 (measured 87 to 91) |
| Bolts, now | 96 to 105 (measured 102 to 106): 23 to 32 faster than the hop |

- Dials: `Pace.Bolt` 1.45 (was 1.8), `Pace.BoltVary` 0.05 (new: bolts had the fast fish's 15% either way),
  `Pace.FastVary` 0.1 (was 0.15).
- Riding a bolt is still 1.5 times its kind (`BoltRide`).
- **Not known:** whether 23 to 32 over the hop is grabbable by hand. If not, the next step is `Pace.Bolt` 1.35.

**The stun.** Riding a fish that can't break props, straight into one that is in your way:

1. The fish is stopped against it, at 5% of its speed, for 0.4 seconds. The prop stays solid.
2. The crash's shake, more bubbles and a deeper thud.
3. Then the prop turns see-through and your speed comes back over half a second.

| Dial (`Config.Props`, in the N panel) | Value |
|---|---|
| `Stun` | 1 (0: the old way, see-through at the touch) |
| `StunTime` | 0.4 s held |
| `StunSlow` | 0.05 of your speed |
| `StunRecover` | 0.5 s to pick up again |
| `StunShake` | 0.9 |
| `StunGap` | 1.5 s before the next stun, so a cluster of props stops you once |
| `StunSpeed` | 12: slower than this is a nudge |

- **What does not stun:** the hop; a prop you were passing beside (it is see-through before you touch it); small
  things under 10 studs (`ShakeMin`: sea grass, small stones); a fish that breaks props.
- **Nothing is taken.** No Oxygen. It costs about 0.9 seconds of speed.
- It is the rider's own machine that stops the fish, as with all the steering. The server is not told.
- Run in Studio by script, riding straight down the lane: two hits. Speed 3 for 0.4 s, back over 45 by 0.66 s.
  In the clean hit the prop stayed solid for 0.34 s and was see-through by 0.46 s.
- **Not seen by eye.** Whether 0.4 seconds is the right "moment" is the user's to say.
- Where it is in the code: `touched` and `judge` in `PropController` (`SolidUntil`), `RideController.stun`.

### Sharks at a steady pace, and back onto the fish you left (2026-11-17)
The user: "some of the fish go quite fast then stop their fast speed randomly usually when passing by a player.
Need that to stop. The shark speed is also too fast to catch normally." And: "make it easier for the player to
hop off a fish and then hook back onto the same fish ... a lot of the time you want to hop back onto the same
fish to farm the small period of oxygen you have if you have nowhere else to hop".

**The fish that sprinted and stopped were the hunters (the sharks).** Two causes, one fish:

- A hunter stoops into the herd when a player is near, runs through it until it is past that player, and then
  climbs away. It ran at 1.6 times its pace and climbed at the herd's share, so it sprinted at you and slowed
  once past.
- A hunter's pace went by its own ridden speed, not the land's. The speed pass more than doubled ridden speeds,
  so the first land's shark cruised at 114 studs a second and ran at 243. A hop leaves at 73.

| | Before | Now |
|---|---|---|
| The first land's shark, cruising | 114 | 72 |
| On its run through the herd | 243 | 72 |
| Climbing away, past the player | the herd's 48 | 72 |

- A hunter's pace is now a share of the land's pace, like every other fish's: `Pace.Hunt` 1.05, and the same on
  its run (`Pace.HuntRun` 1.05). It still comes down through the herd and climbs away; only the speed is steady.
- Riding a shark is as fast as it was.
- Measured, one visit by script: 72 a second for 13 seconds in land 1, rising to 87 as it crossed into land 2
  (that land's pace), and still 86 to 87 after it had passed the rider. One-second dips to about 60 twice.
- **If it was not only the sharks:** the first land's commonest fish (Blue Chromis, Clownfish, Cuttlefish) are
  darters. They burst to 1.6 times the herd's pace for a second and drift back at half of it, on their own clock,
  not near players. That is unchanged. Its dials are `Pace.DartBurst` and `Pace.Dart`.

**Back onto the fish you left.** The lock would not take the fish you had just left until the hop's last chance,
and never a fish under or behind you.

- Now, with no other fish to lock, the fish you left takes the lock, wherever it is round you (`Lock.LeftBack`).
- Any other fish that can be locked takes the lock from it at once, so it never gets in the way of a real hop.
- Not in the hop's first 0.4 seconds (`Lock.LeftBackAfter`), so a double press doesn't put you straight back.
- Tested by script with every other fish made unlockable: hop, press again 0.9 seconds later, twice. Both times
  the rider was back on the same fish 1.5 seconds after hopping. A press 0.2 seconds after the hop did nothing,
  as meant.
- **Not tested:** the lock flipping between the old fish and one at the edge of reach. That is for a played hop.

### The leap (2026-11-23)
The user: "make a sick dive animation for when the player jumps into the water initially from the dive stand. We
need nice camera angles, a splash and stuff. leave sound fx for now. We will need to make sure it looks good and
natural and dynamic." There is no dive stand in the place or the generator: "stand" was read as the strip's lip under
the DIVE IN arch (the edge is found by a ray at run time, so a raised stand placed by hand would work too).

**State: on for everyone (`Config.Dive.Leap` 1 in the file) since 2026-11-23, on the user's word ("switch that on for everyone"). Played by script, not seen with two players.**

| Piece | What it does | Where |
|---|---|---|
| The trigger | On the dock, on foot or on a fish (not in a tank), one line (branch `fish-dive`, 2026-11-24; before it was a ray ahead along the way you ran): the root comes within `Dive.LeapAhead` 2.5 studs straight in from the lip, running out at `Dive.LeapMinSpeed` 8 studs a second or more straight out and within 75 degrees of it (`Dive.LeapRefuse`). Run along the lip, or away, and nothing happens on the strip. **Gone off the edge already (along it, slowly, or jumping) you dive from there, whichever way you ran**: before, past 75 degrees off you dropped in. The heading is turned to within 40 degrees of straight out (`Dive.LeapCone`), and straight out if that way is blocked | `Controllers/DiveController` |
| The leap | A short crouch on the lip, then an arc: 11 studs up, 24 out, 0.85 s in the air, in head-first at 67 degrees and 72 studs a second, carrying on to 16 under | `Dive.LeapHigh`, `LeapFar`, `LeapTime`, `LeapDepth`, `LeapSink` |
| Into the plunge | The server's rule is unchanged (under -4 on the dock is in the water). The existing hop takes over with the leap's heading. With a fish equipped the server seats you at the water and the leap lets go; with a sub picked it lets go to the sub | `JumpController`, `RideController` (seams) |
| The pose | Crouch, a slight arch on the rise, arms overhead and legs together at the top, an arrow at the water; a tuck with `Dive.Flip` 1. Other players are posed on each machine from the diver's tilt (nothing new is sent) | `AnimController` (`leapPose`) |
| The camera | One move, no cuts: low beside the lip looking up, over the top with the diver, across the surface behind the entry, then following the diver into the hop's view. Moving the mouse takes the view back. `Dive.LeapCam` 0 leaves the view alone | `DiveController` (`filmAt`, `cameraFrame`) |
| The splash | A crown of big cubes, a squat mound, two foam rings on the surface; drawn on every machine for any character that goes through the surface fast. No new sound | `Lib/Splash` |

- **Played by script three times (2026-11-23), never by hand, never with two players.** No error from our scripts in
  any Play. With the dial off the walk-off is as before (in the water 0.55 s after the lip, riding at 1.8 s). With it
  on: every leap begins, 0.85 s in the air, one splash, the hop takes over 1.25 to 1.33 s after the lip (about half a
  second later than a plain drop), and everything is handed back after each dive (camera, Humanoid, state, splash).
  With a fish equipped the leap lets go at the water as the server seats you; with a sub picked it lets go to the sub.
- **The first Play's two faults are gone:** the camera no longer stops under water and jumps (0 frames still while
  the diver moves, 8 dives), and the view no longer goes white at the splash (the camera crosses the surface 12 studs
  behind the entry; the splash's blocks fade near the camera).
- **A code review's six small faults are fixed** (the body pulled back to the dive's path if the server sent you home
  during the hand-over; splashes frozen after an error; the "already splashed" flag outliving its dive; a leap from
  standing on another player's head; camera keys out of order off a high ledge; dead code). Played once since, at a
  throttled 15 frames a second (Studio's window was covered): they work, the frame numbers from that Play do not count.
- **Not seen yet:** the splash as it is now (white Neon blocks, a crown that opens to its widest at 0.3 s, a thicker
  first ring): the stills before it showed a grey lump from the side. Whether Neon white glows is not known.
- **Not known:** whether the leap adds a slow frame at the hop (round 2 showed one of about 30 ms in every dive and
  one of about 100 ms in two; the splash pool and the bubbles are now made ahead, not measured since).
- **Not the leap's:** a sub dive with no fish equipped ends in Drowning 2.5 s into the ride with the dial off too.
- **Slow networks:** if the server's word that you are in the water takes over 1.2 s (`Dive.LeapHold`) the leap lets
  go under water and the plain hop follows with its own splash.
- **The dial:** `Dive.Leap` 1 in the file (the user, 2026-11-23). 0 in the file or in the N panel puts the plain drop back.
- **To check it:** `python tools/studio/dive_leap_check.py` (install, then `run`, `run fish`, `run sub`, `run look`,
  and `hold <moment> own|director` for stills; logs in `work/dive_leap/`). `remove` takes the check out of the place: do it before any publish.
- **To try the flip:** `Dive.Flip` 1 in the N panel.

### The leap on a fish (2026-11-23, every fish 2026-11-24)

The user: "add an animation for if you are on a fish and you dive into the water you should have a slightly different
but similar dive animation because we dont have that coded". Hugo, 2026-11-24: "make sure each fish gets a diving
animation just like the player does, hitting a certain line should make you hit the animation with the same camera
movement". **On (`Config.Dive.LeapMounted` 1), on main since 2026-11-25; checked offline and by script in Studio (below), not
played by hand.** The partner's first version is extended, not replaced.

- **What it does.** A rider on a land fish who runs over the line at the lip dives with the fish: it takes off nose up,
  arcs, goes in nose down, and is level by the time the server swaps it for the water fish. Same camera keys and splash as
  the plain leap, scaled by the fish's length. All 78 kinds at all six sizes dive (468 of 468; 141 did before). And from five
  places along the lip, three ways of running, two paces, and gone over the edge already: 18720 of 18720. The table,
  fish by fish: [dive-in-fish](dive-in-fish.md). Side view: [three fish](../attachments/fish-dive-side.png), from the
  game's own sums. (There are 78 kinds, not 82: four were cut 2026-11-19.)
- **The line, and a change to the plain leap on foot.** One line `Config.Dive.LeapAhead` (2.5) in from the lip, straight out from
  the dock, the same for a rider and a walker: the check begins both at the same 2.4 studs inside the lip. **On foot this
  differs from what is live (2026-11-24):** (1) the line asks for 8 studs a second straight out, where before 8 any way did
  (speed times the cosine of the angle off: a walk at 16 a second from 60 degrees off, up to the old 75, is at or under that
  and no longer dives from the strip, only from over the edge); (2) over the edge the 75 degrees no longer apply, so running along the lip and off it dives where it dropped in;
  (3) a way that is blocked is tried again straight out. The walkers, on foot and on a Great White alike (18 of 18):

  | Walked | Before | Now |
  |---|---|---|
  | Straight out, or 45 or 55 degrees off | dives | dives from 2.4 in (2.5 at 45) |
  | 60 degrees off, at a run of 32 | dives | dives from the line |
  | 70 degrees off at 16 a second | dives from the strip | dives from over the edge |
  | Along the lip, on the strip; away from it | no dive | no dive |
  | Along the lip and off it (88 degrees) | drops in | **dives** from over the edge |
  | Slowly off it (6 a second) | dives from over the edge | dives from over the edge |

  (Before is read from main's code, not run.)
- **Why fish did not dive before.** The old test refused any arc where the fish's box met the dock floor it was standing
  on (132), or where its tail came down over the floor (192), or the gate (3). Now the floor and what it already stands in
  do not count, and eight arcs are tried: four with the fish's whole box (as asked, then lower, then shorter), three with
  only the rider's own path, the last with only that it comes down in open water. 386 of the 468 take the first, 18 the
  second or third, 64 the fifth (the first on the rider's path: a tail or fin may pass through a thing), and none a later one.
- **Camera.** The player's keys, placed on the fish's middle and further back for a long fish, and through the surface after
  it, as the diver's: **all 468 dives keep that beat** (from 30 and 44 studs either side of the middle as well, part 6: the gate between in 74 or
  75 dives there, 271 to 281 frames, at most 7 on end). It follows
  behind the fish (408), or, where the fish's back is over the riding camera's line so that a camera under the water
  would be in the fish, from beside it and half as far back (60: 1 Big, 9 Giant, 19 Huge, 31 Colossal, 31 kinds; named in
  [dive-in-fish](dive-in-fish.md)). If neither had room it would stay over the water; no fish needs that today. The check
  only asks what the gate and the cove hide, not the fish itself: from beside, a wide fish's own flank may
  hide part of its rider. Unseen.
- **The camera's side off the middle.** Wherever the rider is over 6 studs off the middle of the strip, a fish's camera goes
  to the middle's side, away from the nearer pillar, unless the player's view is well round on the other side already (the
  diver's is as it was). Before that rule the gate was between in 281 of 468 dives from 30 studs to one side and 75 from the
  other; it is 75 on both now.
- **The gate's arch, counted honestly.** From 3 times the diver's distances up (`Config.Dive.LeapMountedAloft`, 316 of the
  468) the camera is not pulled in to what is between it and the rider before the water (0.15 s after it at most): pulling
  in was a jump of up to 196 studs. So the gate's beam or pillars do hide the rider for those frames, and the check
  counts them whether exempt or not: **81 of 468 dives, 302 frames of 30 a second, at most 7 frames on end** (Tiny 0, Normal
  3, Big 7, Giant 16, Huge 25, Colossal 30; it was 180 dives and 902 frames, by the same count, before the film was planned
  round the gate). What is left is mostly the biggest fish, whose own view at the start is already behind the beam, and 2 to
  5 frames of a beam sweeping by. Nothing is between once it is in the water, and no camera is pulled in or inside the fish.
  The film's rises are worked out by a search for the dives whose rider the gate hides: 131 rays for the middle dive,
  over 400 for 183 of the 468, 1812 for the worst (Hellmaw Colossal), all in the one frame the dive begins. **Not timed in Studio.**
  The rider is never further than 0.80 from the view's middle (1 is the edge; AuroraJelly Huge).
- **The fish's own motion.** Its swim, not a tilt: the land hook (`AnimController.LandHook`) writes the fish's own keyed
  swim and fins (RideStyles) through the dive: its tail lifts as it goes in, and a short one (under 45 studs) arches its back
  over the top. A long one's back does not bend. All 78 kinds' joints move.
- **The swap.** The fish is level and heading straight out by then, so the camera has nothing to turn for. Whether the fish
  jumps is not settled: on this branch `SubService.diveFish` still makes the water fish with its root, not its saddle, at the
  rider, which is 5 to 72 studs off by the sums (a prediction: where it is spawned, before `RideService.mount`'s weld joins
  its saddle to the rider). d2's branch `fish-sub` (committed, 0287e35 and c5c38ca) places it by its saddle, at most 1.9 studs
  off by the sums; merged 2026-11-25 (0.2 to 3.1 studs in Studio, 4.65 once).
- **With a sub trip picked (d2).** Agreed, and written on their side too ([submarine](submarine.md), "The hand-over with the
  dive", commit c5c38ca on `fish-sub`): on the first frame `State.Mode` is "Carried" the dive lets everything go (body, pose,
  camera), and from that frame they are `SubController`'s; the trip eases the fish from where the dive had it.
  `DiveController.handOver()` gives the last frame's position, velocity, yaw, view and field of view. Root y is about -7 then,
  31 to 36 studs a second. Run offline here only against a stand-in for the trip, not their code.
- **Cost.** Until the rider is under the water line: 1.4 to 2.2 s for fish under 30 studs, about 2.5 s for a Great White, 3.4 s for
  the biggest. Half a second of that is the longer leap for fish over 48 studs (`LeapMountedMost`,
  4 to 8, 2026-11-24).
- **Known weak spots.** A long fish's tail is still back of the lip, inside the dock, as it sinks: 47 of 468 (none at
  Tiny or Normal, 12 of them over a tenth of their length; a Blue Whale Huge or Colossal by 40 studs). A box cuts the
  floor on the way out by 10 to 53 studs for AuroraJelly (a box far bigger than the jelly), TheDevourer and AbyssalWatcher
  at their big sizes. A fish bigger than the gate's arch goes through its beam, as it already does on land. 6 dives have an
  end of the fish out of the view more than 15% of the frames (Anglerfish Colossal, BlueWhale Tiny and Giant, Hellmaw Normal,
  SkullAngler Giant and Huge; 23% at most);
  one end is furthest out, 46 half-views from the middle, for a moment in the air (Basilosaurus Colossal, 2.1 s; it was 39,
  StormSerpent Colossal, before the camera followed from beside).
- **To check it offline:** `python3 tools/dive/lip_boxes.py . /tmp/lip.json`, `rojo build -o /tmp/place.rbxl`,
  `lune run tools/dive/fish_dive_check.luau /tmp/place.rbxl /tmp/lip.json` (exits 1 on any FAIL; parts 1, 3, 4, 5 in a minute
  and a half with a fourth argument of `1345`, part 6 films it off the middle in three more, part 2 is the long one). It reads the map GENERATOR's boxes, not the saved place.
- **To check it in Studio:** `python tools/studio/dive_leap_check.py install`, Play, then `run mounted-all` (a small, a
  middling, the biggest and the worst-shaped fish, one PASS or FAIL line each, log `work/dive_leap/check_mounted_all.log`),
  `run mounted ID:Size` for one, `remove` before any publish. Run on 2026-11-25 (below).
- **Played by script in Studio (2026-11-25; about 45 to 60 frames a second, so frame times are real):** 14 kinds and sizes, Tiny to
  Colossal, all dive: lip to Riding 1.5 s (Tiny) to 3.5 s (Colossal), 0 frames with no fish but one of 0.02 s, no error, no
  put-back, the worst frame 25 to 44 ms, the saddle moves 0.2 to 3.1 studs at the swap (4.65 once, Blue Whale Colossal). On foot
  the leap is as before (2.3 s lip to Riding, 0 frames out of sight). Great White's nose turned 17 degrees at the swap in
  one run of three (10 is the limit). **Found and put right:** the gate's beam stopped the tallest fish's riders (root 60 up) and
  lifted the Aurora Jelly's onto itself: `RiderGate` turns the gate off for a rider over `Config.Equip.GateFrom` (48), on their
  own machine, until they are off the fish. Still so: at takeoff the Colossal whale's own antlers fill much of the view
  ([stills](../attachments/fish-dive-and-sub-hop.png)).
- **Not known.** How it feels to a person, and whether the pace check ever puts a rider back on a bad
  network. Two players are not checked.
- **Played before this change (one run, a small fish, Studio at 15 fps):** no errors; the swap moved the fish 0.34 studs and its
  nose 0.7 degrees, never a frame with no fish; the land pace check never put the rider back; lip to riding 1.63 s against
  0.62 s with the dial off; taking the fish off mid-leap gave the camera back in 0.09 s.
- **The plain leap, owed since it went on:** the Neon splash was seen in a still (`work/dive_leap/dir3_splash.png`):
  it reads as a white burst now, not a grey lump, but the glow blows the crown's shape out; unjudged by the user. Its
  frame times at a real frame rate are still not measured (Studio's window was covered, 15 fps).

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
