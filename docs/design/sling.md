# The sling

Getting from fish to fish: what was weak, what is built, and how we study the feel. Started 2026-11-17.

Up: [Home](../../Home.md). Related: [the dive-in](dive-in.md) (the lock, the reach, the hop), [the hook](hook.md),
[the wild ride](wild-ride.md), [Ride a Dino's jump, measured](../reference/ride-a-dino.md).

## What the user asked
"Its about 90% there id say but it doesnt feel as snappy, quick, and the selection doesnt feel like it grabs onto
what is proper. In ride a dino it feels like its all done for you really. What areas of weakness could we have and
any areas of improvement for the feel of slinging from fish to fish in the most smooth sick feeling movement ever.
Doesnt even have to be 1:1 with ride a dino ... it needs to feel smoother, quicker, more cool." And: "How can we go
about getting you to understand this the best". On the plan below: "Yes, start there".

## What was weak (read from the code, against the reference's measured jump)

Studio has almost no network delay, so what is felt there is how the hop is built, not lag.

| | Ride a Dino (measured) | Ours, before |
|---|---|---|
| Press to landing, hands off | about 2 s (1.8 to 2.4) | 2.4 to 3.0 s, and longer off faster fish |
| The pull-in | 0.33 to 0.47 s | 0.7 s for most grabs |
| Its shape | creeps, then fastest at the very end; stops dead on the dino | started from the target's own speed (a brake), slowed to a stop onto the saddle |
| Floating | at the herd's pace: the dino under you stays under you | 15 to 25 studs a second faster than the herd: fish slide back under you all hop |
| Picking | whatever is under a ring that travels with you; you steer it | the fish nearest the middle of the screen, a line that runs through your own rider, with about 30 settings on top |

1. **Pressing grab braked you.** The pull-in began at the target fish's speed.
2. **The landing was cushioned.** The shake and the view's snap came on a body that had already slowed.
3. **The air was fixed and long.** The hands-off pull-in waited for the glide to end; airtime grew with the fish's
   speed, so a fast fish gave the longest wait.
4. **The lock picks from a moving crowd,** and its hold rules (0.3 s hold, 0.1 s switch, 0.45 s linger) make it slow
   to follow.
5. **Quick presses were thrown away,** and armed the mash guard, which could refuse the next press too.
6. **The lock is a pile of patches.** Each rule fixed one complaint.

## Built (2026-11-17): three fixes, each on a switch, and the feel log

| Fix | What it does | Its switch (N panel, Jump) | Old way |
|---|---|---|---|
| **The sling** | Keeps your own speed into the pull-in and bends it onto the fish, closing faster and faster, fastest at the touch. 0.14 s plus the gap at 170 studs a second, at most 0.5 s | `Sling` 1 (`SlingCurve` 2, `SlingBase`, `SlingSpeed`, `SlingMax`, `SlingCarry`) | `Sling` 0 |
| **Sooner, by itself** (since 2026-11-18 at 1.7 s, the reference's: "Airtime matched" below) | From 0.7 s after the press the locked fish pulls you in once it is under you (30 studs across the water, any height), or at 1.3 s whatever the gap. Only once the lock has held it 0.2 s, never while you are turning the view (you are still choosing), never the fish you just left (that one still waits for the glide's end, or a press) | `EarlySling` 1 (`SlingAfter`, `SlingNear`, `SlingBy`, `SlingSettle`, `SlingHoldTurn`) | `EarlySling` 0 |
| **Flat airtime** | A faster fish's hop goes further, not longer | `AirSlow` 0, `AirFast` 0 | -0.5 and 0.5 |
| **Kept presses** | A hop pressed in the last part of a pull-in (its second half, within 0.2 s of the touch), or between the touch and the moment you may hop, is kept and made the moment you may. Presses early in a pull-in are still the mash the guard is for | `Buffer` 0.2 | `Buffer` 0 |

### Measured, old against new
The same scripted run on each: a dive and six to eight hops, Space every few seconds, the camera never moved, land 1.
The new run had five early slings and two that waited for the glide's end (only the fish just left was in reach).

| | Old settings | New settings |
|---|---|---|
| Press to touch, hands off | 2.42 to 3.04 s | 1.03 to 2.19 s early; 2.67 to 2.71 s at the glide's end |
| The pull-in | 0.70 s every time (gaps 57 to 88 studs) | 0.31 to 0.50 s (gaps 28 to 86) |
| Speed as it begins, and its lowest in its first part | 34 to 69, falling to 0 to 50 | 61 to 120, never lower; except turning back to a fish behind you: 70 down to 18 to 33 |
| Speed as you hit the fish | 30 to 48: the fish's own speed | 158 to 225 |
| A press just after the touch | thrown away | the next hop left 0.01 s after the server's answer |
| The server's answer after the touch, in Studio | 0.06 to 0.09 s | 0.06 to 0.20 s |

- **Turning back to a fish behind you still dips:** you reverse, so your speed passes low. The "hover with your
  target" step below should mostly end this.
- **Long slings hit hard:** an 86-stud gap ended at over 200 studs a second. `SlingCurve` lower softens the end.
- **Not felt by anyone yet.** The test never moved the camera.

### The feel log (Studio only; `Config.FeelLog`, `Controllers/FeelLogController`)
- **Every hop is one `[FeelHop]` line in the Output:** off which fish, the launch speed, when the lock first took a
  fish and every fish it went to, how the pull-in began (`press`, `early`, `glide`, `window`, `dive`), the gap, its
  time, your speed at the grab, its lowest, your speed at the touch, the server's answer, every press and what it
  did (`grab`, `nothing`: no fish locked, `early`, `mash`, `kept`, `wait`, `guard`), and how long you rode the fish
  before (`AfterLanding`).
- **Press M when something feels off.** The last 5 seconds are written out (`[FeelMark]`): where you were, your
  speed, the camera's look, the lock and every nearby fish's place from you and its lock score, sampled ten times a
  second, with every event.
- **Then numbers come up over the fish near you** (the locked one in white). Press the number of the fish you WANTED,
  or 0 for none of them (`[FeelPick]`). Ten or so of these and the lock can be fitted to what you meant.
- **Tell Claude when you're done.** The lines stay in the Output after Play stops. A word per mark helps ("mark 3:
  slow", "mark 4: wrong fish"). If the Output is very long only its end can be read, so don't play for an hour first;
  while still in Play the whole log is on the player too (`FeelLog`, `FeelMarks`).

## Fast fish: hooks refused and riders falling off (fixed 2026-11-18)
The user: "the player falls off a fish if they hook onto one thats swimming away super fast. Often you get hook
cancelled or the player falls of the fish even if they get onto it for half a second."

**Why.** The server judges the grab and the landing by distance, but it sees things late. The rider's machine sees a
wild fish a moment late, and the server sees the rider a moment late: a fish going fast is ahead of where the rider
was held to it by its speed times both moments. And at the touch the server still sees the rider partway through the
pull-in, whose last tenth of a second covers most of the distance.
- **"Hook cancelled":** the grab was refused as out of range, though the rider's screen had the fish in reach.
- **"Falls off after half a second":** at the touch the rider's machine holds them on the saddle and waits for the
  server's word. The server gave the landing half a second (`Jump.LandWait`) to see them at the fish. With a fast fish
  the gap never closed in that time, so it refused, and the rider dropped off the saddle.

**The fix (`Config.Net.Lag`, `RideService` `nearness`).** Before judging, the server puts the fish back along its own
way by up to half a second (and the player's ping), and the rider on along theirs by up to 0.15 s, and takes the
nearest. The same in the grab, the landing, its half-second wait, and the mount's "move a far rider to the saddle"
(which would have thrown a rider forward to where the server has the fish). And the server's speed check no longer
flags the first second on a fish caught going fast (it still has that speed while the rider's machine eases it to its
ridden pace).

**Measured in Studio** (each judged distance is printed as a `[RideCheck]` line in the Output, Studio only):

| | As the server saw it (the old rule) | With the delay allowed for |
|---|---|---|
| A grab onto a SergeantMajor going 115 studs a second | 129.8 studs, reach 123.5: **refused** (hook cancelled) | 73.9: granted |
| Its landing | 93.1 studs, limit 46.7: **the half-second wait, then refused** | 12.0: mounted |
| Landings onto fish at 119 and 121 studs a second | 65.9 and 79.6, limits 46.2 and 45.4: refused | 15.8 and 18.7: mounted |
| Landings onto slow fish (33 to 48 studs a second) | 24 to 53 studs, one at 52.6 against 52.5 | 5 to 24 |
| 34 hops over three runs | 1 grab and 7 landings over the old limits: the grab refused at once, the landings left to the half-second wait, which a fast fish fails | all landed but one, a press with no fish locked |

Studio has almost no network delay: online, the old rule failed sooner and on slower fish.

## Airtime matched to the reference (2026-11-18)
> **Corrected 2026-11-19 ([feel review 1](../reviews/feel-review-1.md)):** the reference has no hands-off hook. Every
> landing in the recordings follows a second press, the throw. The 1.7 s matched here is when one player chose to
> press. Ours still hooks by itself at 1.7 s; whether to keep that, or move it later so the throw becomes the main way,
> is the review's first question for the user.

The user: "study the airtime in ride a dino and replicate it. when you jump to when you auto hook the next fish". Measured
in [Ride a Dino](../reference/ride-a-dino.md), "Airtime, hands off": its hook comes about 1.7 s after the jump, and it
lands 1.8 to 2.4 s after (median 2.08). Ours hooked by itself at 1.3 s (at 0.7 s if the fish was under you).

- **Now the hands-off hook comes at 1.7 s, whatever the gap** (`SlingAfter` and `SlingBy`, both 1.7; they were 0.7 and
  1.3). The fish you just left is taken then too, if it is the one locked; it waited for the glide's end before (2.2 s).
- **The rest of the hop is as it was:** a press still grabs at once, the glide still ends at 2.2 s, and the pull-in is
  as before (0.31 to 0.50 s; the reference's is 0.33 to 0.47).

| Hands off, press to... | The reference | Ours before | Ours now (10 hops by script) |
|---|---|---|---|
| The hook | about 1.7 s (1.4 to 2.0) | 0.9 to 1.36 s; at the glide's end 2.2 to 2.5 off the fish just left | 1.72 to 1.82 s in 8; 1.92 and 2.16 when the lock had just moved to another fish (it waits 0.2 s to settle) |
| The landing | 1.80 to 2.40 s (median 2.08) | 1.2 to 1.9 s; 2.7 to 3.0 at the glide's end | 2.15 to 2.70 s (median 2.29) |

- **The landing matched too (the same night, the user: "Yes, match it").** With the hook on time, ours landed about 0.2 s
  after the reference: our pull-in took the full 0.5 s on any gap over 61 studs, and more gaps are long now that the
  hook reaches further ahead. So the pull-in is never longer than 0.4 s now (`SlingMax`, was 0.5): 0.34 to 0.40 s,
  against the reference's 0.33 to 0.47. **The landing comes at about 2.1 s** (1.7 + 0.4), against its 2.08.
  - In ten more hops by script every pull-in was 0.38 to 0.40 s. Studio ran at only 7 frames a second, so the landings
    read 2.13 to 2.68 s: each frame is 0.14 s, and the hook waits for the first frame after 1.7 s. The landing time
    needs checking at a normal frame rate.
  - One of those ten missed: the server refused a late grab of a fish swimming away at 132 studs a second. At 7 frames a
    second the rider's machine sees the fish more than half a second late, beyond what the server allows for
    (`Net.Lag`). It is not expected at a normal frame rate.
- **The first run of ten** (the hook at 1.7, the pull-in up to 0.5) was at 14 frames a second: each time good to about 0.07 s.
- Not felt by anyone yet.

## Next, in order
1. **You play with the switches and the M key.** Old against new is one click each.
2. **The intent lock:** score each fish by where your hop and it will meet in the next second, the look as a
   nudge, in place of most of the 30 settings. Built against your marks.
   **Built in part, 2026-11-18:** [the lock](the-lock.md) (by the line you fly along, a
   moment ahead; the old settings stay for `Lock.Pick` 1).
3. **Hover with your target:** after the pop, ease to the locked fish's pace so it sits still on screen and the sling
   is short. Difficulty stays in the sea (spacing, fits, bolts), not in fighting the controls. **Built 2026-11-19**
   (`Jump.Hover`; not with the fish you just left): [feel review 2](../reviews/feel-review-2.md). **Since 2026-11-19 it
   also closes in** along your heading, to about half a second of the fish's pace behind it by the hook, and the
   pull-in is 0.5 s and even (`HoverClose`, `SlingMax`, `SlingCurve`): [feel review 3](../reviews/feel-review-3.md).
4. **The camera that sells it:** frame you and the target in the hover, lead into the fish in the sling.
5. **Flow:** quick chains build faster launches, a wider view, a rising whoosh, a chain count.
6. **Later, the optimisation pass:** land on your own machine at the touch instead of waiting for the server
   (0.06 to 0.2 s in Studio; more online).

Where it is in the code: `startReel`, the reeling branch, the early sling and `request` in `JumpController`; the
scores for the log in `Lib/Lock` (`Lock.Debug`); `Lib/FeelLog`; `Controllers/FeelLogController`.
