# Feel review 3: the hook's speed

The hook's pull-in measured against the reference's, after the user found it might be too fast. Written and measured
2026-11-19.

Up: [Home](../../Home.md). Related: [feel review 2](feel-review-2.md), [feel review 1](feel-review-1.md),
[the sling](../design/sling.md), [the lock](../design/the-lock.md), [Ride a Dino](../reference/ride-a-dino.md).

## What the user asked
"the hook animation might be too fast now, do another pass research"

## How it was measured
- **The reference:** its distance counter (the metres on the zone bar) read on every frame of 49 hooks across three of
  the user's recordings, every reading checked by the reader and 88 by eye; the rope's arrival by eye on 17. The counter
  counts progress along the track only, in whole metres. Every speed is compared with that hop's own riding speed, so
  no scale between their metres and our studs is needed (it could not be measured). The reader:
  [tools/review/rad/counter](../../tools/review/rad/counter/README.md).
- **Ours:** 29 hooks in Studio (land 1 onward, the herd at 0.85, the safety switches on, Space every 3.0 s), from the
  feel log (the gap, the pull-in's time, the fish's pace) and a log of every frame. Studio drew at only 13 frames a
  second, so our peak speeds are worked out from the pull-in's own curve rather than read off the frames.

## The reference's hook
- **Two kinds of pull.** Short, 0.23 s (0.20-0.30), when the dino is near, below or beside (17 of 49). Long, **0.50 s**
  (0.33-0.57; 12 took exactly 0.50), when it is ahead (32 of 49).
- **The rope is on the dino 3 frames after the throw** (0.10 s; 2 to 4 frames). The zip you see after that: 0.37 s.
- **The pull starts at the press,** before the rope lands: in the first 0.1 s the rider already goes 70 m a second,
  against 48 in the glide just before.
- **With the dino ahead** (16 hops): it is 30 m ahead at the throw (19-34), **0.52 s of riding**. The pull covers 48 m
  along the track, at **1.95 times riding speed** on average (1.49-2.89), peaking at **2.68 times** (1.92-3.68) in its last
  tenth of a second, then it stops dead on the dino.
- **It speeds up evenly:** 40% of the distance comes in the first half of the time. No creep, then a rush.

## Ours
- **The gap at the hook: 69 studs** (6-119), about **0.97 s of riding** (0.83 s of the target fish's own pace). The lock
  reaches fish far ahead, and since feel review 2 the glide hovers at the locked fish's pace, so it keeps that gap.
- **The pull-in: 0.40 s** for 21 of 29 (the cap, `Jump.SlingMax`), 0.20-0.40 for the rest.
- **The anchor flies for its first 0.16 s** (`Hook.ThrowShare` 0.4), so the zip you see is **0.24 s**.
- **It closes as time squared** (`Jump.SlingCurve` 2): 25% of the gap in the first half, and the last moment is twice the
  average speed.
- So it goes about **3.5 times riding speed** on average and peaks near **6 times** (the fish's pace plus twice the gap
  over the time; read off the frames, the last frame before the touch was already 2.9 times at 13 frames a second).

## Side by side
| | The reference (long pulls) | Ours |
|---|---|---|
| The gap at the throw, in seconds of riding | 0.52 (0.32-0.75) | 0.97 |
| The pull-in | 0.50 s (0.33-0.57) | 0.40 s (the cap) |
| The rope or anchor reaches the fish | 0.10 s | 0.16 s |
| The zip you see | 0.37 s | 0.24 s |
| The first half's share of the distance | 40% | 25% |
| Average speed, against riding | 1.95 times (1.49-2.89) | about 3.5 times |
| Peak speed, against riding | 2.68 times (1.92-3.68) | about 6 times |

## What it shows
1. **Yes, ours is too fast:** about twice the reference's speed, on average and at the peak.
2. **Three reasons, about equal:**
   - **The gap.** Ours hooks from nearly twice as far, in riding time. The reference's rider throws at a dino about half
     a second of riding ahead; ours hovers at its locked fish's pace and keeps whatever gap it locked at.
   - **The time.** Our cap of 0.4 s came from two pull-ins read off the counter (0.33 and 0.47 s). Over 32 long pulls
     the reference's takes 0.50 s.
   - **The shape.** Ours creeps and then rushes (time squared, and the anchor's flight takes 40% of it); the reference's
     speeds up evenly from the press, with the rope on in 0.1 s.
3. **A correction to the reference notes:** the "creep, then faster" read off the counter in 2026-11-10 was the end of
   the glide. Measured from the press, that pull-in took 0.30 s at 107 m a second, with no slow start. Our pull-in's
   shape was fitted to it (`SlingCurve`'s "1.5 and 2.5"); the steady speed-up fits about 1.3.

## What we could change
Worked out for our median hook; the hook still comes 1.7 s after the jump.

| | Change | Average, against riding | Peak | The zip you see | Lands after the jump |
|---|---|---|---|---|---|
| Now | | about 3.5 times | about 6 times | 0.24 s | about 2.1 s |
| **A. The pull-in's dials** | `SlingMax` 0.5 (the reference's long pull); `SlingBase` 0.2 and `SlingSpeed` 120, so a reference-sized gap (about 35 studs) takes 0.5 s and a fish beside you 0.25 s (its short pull: 0.23); `SlingCurve` 1.3 (its even speed-up); `Hook.ThrowShare` 0.2 (the anchor on in 0.1 s) | about 3 times | about 3.6 times | 0.4 s | about 2.2 s, as the reference's long pulls |
| **B. Closer gaps** | the hover closes in on the locked fish, to about half a second of riding behind it (about 35 studs) by the hook, instead of holding the gap. The lock still reaches far fish; you glide toward them | | | | |
| **A and B** | both | about 2 times | about 2.5 times | 0.4 s | about 2.2 s |

- **A alone** is three numbers in `Config`; it brings the peak down most, but the pull still crosses twice the
  reference's distance.
- **B** is code in `JumpController`'s hover. It changes the hover built after feel review 1 ("keeps its place before
  you") into "glides in over its fish, then drops on", as the reference's rider floats over its dino before the throw.
- **A and B** match the reference on all three: the distance, the time and the shape.
- The pull-in was capped at 0.4 s on 2026-11-18 to land when the reference lands ("Yes, match it"); with 49 hooks
  measured, matching it means 0.5 s for a long pull.

## Built: A and B (the same day)
The user: "Both A and B". In the game code, measured in Studio over 28 hooks each way (same set-up as above; Studio
still at 13 frames a second):
- **A:** `Jump.SlingMax` 0.5, `SlingBase` 0.2, `SlingSpeed` 120, `SlingCurve` 1.3; `Hook.ThrowShare` 0.2.
- **B:** `Jump.HoverClose` 1: after the pop the glide closes on a spot `HoverGap` (0.45 s of the fish's pace, at least
  `HoverGapMin` 12 studs) behind its saddle, timed to arrive at the hook (`SlingBy`), never more than `HoverCloseMost`
  (45 studs a second) over its pace. Only along our heading (`HoverSide` 0): closing sideways too, the glide drifted onto
  one of two fish side by side, the camera's look line moved onto the other, the lock swung between them, and 3 of 28
  hooks waited for the glide's end. Along the heading only: 1 of 28, as before.

| | Before | After A and B | The reference (long pulls) |
|---|---|---|---|
| The gap at the hook | 69 studs | 59 studs: 15 along the fish's way, the rest sideways and height (19 above) | 30 m along its track |
| The pull-in | 0.40 s | 0.54 s | 0.50 s |
| The zip you see | 0.24 s | about 0.4 s | 0.37 s |
| Average speed, against riding | about 3.5 times | 2.85 times | 1.95 times |
| Peak speed, against riding | about 6 times | 3.3 times | 2.68 times |
| Landing after the jump | 2.16 s | 2.29 s | about 2.2 s for a long pull |
| Lock switches a hop | 0.5 | 0.52 | |

- **The peak, the part that reads as too fast, is near the reference's now;** the average is still half as fast again,
  as the gap left is mostly sideways, which the pull-in still crosses quickly.
- **Back onto the fish just left:** 8 of 28 in both runs, within the 9-48% that 25-hop runs swing by (feel review 2).

## Next
- **A hand playtest** at a proper frame rate: does it still feel too fast? Studio drew at 13 frames a second today.
- **If the sideways part still reads fast:** close sideways once the lock has settled on its fish (`HoverSide` above 0
  only then), or make the lock prefer the fish nearer your line.
- The pull-in's dials and the hover's are in the N panel (Jump: SlingMax, SlingCurve, HoverClose, HoverGap,
  HoverCloseMost, HoverSide; Hook: ThrowShare).
