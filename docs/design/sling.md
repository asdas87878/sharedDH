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
| **Sooner, by itself** | From 0.7 s after the press the locked fish pulls you in once it is under you (30 studs across the water, any height), or at 1.3 s whatever the gap. Only once the lock has held it 0.2 s, never while you are turning the view (you are still choosing), never the fish you just left (that one still waits for the glide's end, or a press) | `EarlySling` 1 (`SlingAfter`, `SlingNear`, `SlingBy`, `SlingSettle`, `SlingHoldTurn`) | `EarlySling` 0 |
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

## Next, in order
1. **You play with the switches and the M key.** Old against new is one click each.
2. **The intent lock:** score each fish by where your hop and it will meet in the next second, the look as a
   nudge, in place of most of the 30 settings. Built against your marks.
3. **Hover with your target:** after the pop, ease to the locked fish's pace so it sits still on screen and the sling
   is short. Difficulty stays in the sea (spacing, fits, bolts), not in fighting the controls.
4. **The camera that sells it:** frame you and the target in the hover, lead into the fish in the sling.
5. **Flow:** quick chains build faster launches, a wider view, a rising whoosh, a chain count.
6. **Later, the optimisation pass:** land on your own machine at the touch instead of waiting for the server
   (0.06 to 0.2 s in Studio; more online).

Where it is in the code: `startReel`, the reeling branch, the early sling and `request` in `JumpController`; the
scores for the log in `Lib/Lock` (`Lock.Debug`); `Lib/FeelLog`; `Controllers/FeelLogController`.
