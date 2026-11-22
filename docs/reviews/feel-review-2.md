# Feel review 2: after the first changes

The same measurements as [feel review 1](feel-review-1.md), run again after the changes it led to. Written and measured
2026-11-19. The tools: [tools/review](../../tools/review/README.md).

Up: [Home](../../Home.md). Related: [feel review 1](feel-review-1.md), [the sling](../design/sling.md),
[the lock](../design/the-lock.md).

## What the user asked
After review 1, asked "Build my fixes and try the herd at 0.85 for review 2?": "Yes, go ahead".

## What changed since review 1
| Change | What it does | Its dial | Before |
|---|---|---|---|
| **The herd at 0.85 of the pace** | Wild fish swim nearer a rider's speed, as the reference's herd does (0.85 of riding speed) | `Herd.SpeedShare` 0.85 | 0.7 |
| **Hover with your target** | After the pop the glide eases to the locked fish's pace, so it keeps its place before you; the hook's reach still goes by the hop's own speed. Not with the fish you just left: hovering with it kept you beside it, where no other fish came into reach | `Jump.Hover` 1 (`HoverFrom` 0.4, `HoverEase` 0.45, `HoverFollow` 4) | the glide kept 90% of the launch to 1.7 s |
| **The landing snap at the reference's size** | The picture shrinks to 0.80 of its size in one frame, worked out from the view as it is | `Jump.LandScale` 0.8 | a fixed +12 degrees on top of the pull-in's narrowing being let go: 0.68 |
| **A punch and a flick at the throw** | The view keeps the widening it had (the slow-mo's) and punches 5.5 degrees wider, easing out as the pull-in narrows it; a short high swish (a stand-in) | `Jump.ThrowFov` 5.5, `ThrowFovTime` 0.25; `Feel.ThrowSound` 0.45 | the view narrowed about 6 degrees at once |

The hook was left as it is (by itself at 1.7 s, or a press at any time): that call is the user's (review 1, question 1).

## Measured, review 1 against review 2
Land 1, 24 or 25 presses 3.0 s apart, hands off in the air, the sandbox's safety switches on (no drain), unless
marked. Studio drew at 14 to 60 frames a second.

| | Review 1 | Review 2 |
|---|---|---|
| Hops landed | 25 of 25 | 24 of 24, 25 of 25 |
| **Back onto the fish just left** | 48% and 9% (two runs); 21% with twice the fish; 25% with the herd at 0.85 | 32% and 21% (the second with the hover change); with the safety off 35% and 29%; 24% with half as many fish again (Studio only) |
| The hook | 1.70 to 2.00 s | median 1.73 s |
| The landing | 2.10 to 2.43 s (median 2.17) | median 2.15 and 2.20 s |
| **The glide against the locked fish** (0.9 s to the hook) | not measured; by design about 20 studs a second faster than the herd | 3.2 and 5.8 studs a second, median: it holds its place before you |
| **The throw** | the view narrowed about 6 degrees at once (from the code) | widens 1.7 degrees (median; `ThrowFov` 3.5), then 4.9 (`ThrowFov` 5.5). The reference: about 3.5 |
| **The landing snap** | about 76 to 98 degrees (0.68 of the picture), from the code | 74 to 86 and 75 to 87 degrees: **0.80 of the picture** (0.73 to 0.95). The reference: 0.80 (0.76 to 0.88) |
| Free fish within 95 studs in the air (the one left counted) | 2.71 | 2.40 |
| With the safety off: dives | 5.5 s (no fish to lock), 33 s, 15 s+ | 5.8, 10.1 and 34.3 s, then 8.3, 21.1 and 23.3 s; all ended out of air after bounces back onto the same fish |

## What it shows
1. **The hover, the snap and the throw do what they were made for,** as measured. Whether they feel right is for a
   hand playtest.
2. **The herd at 0.85 has not clearly cut the bounces back onto the same fish.** One run's count swings from 9% to
   48% with the stretch of sea it swims through, so 25-hop runs can't tell 0.7 from 0.85 apart. More fish looked
   better in both reviews (21%, 24%), but one run each.
3. **Bounces back still end dives.** Landing back on the fish just left gives no Oxygen, and a land-1 Common holds
   2.5 s of riding, so three or four bounces in a row drown you. With the safety off every dive in review 2 ended so.
   (Some of it is the test's fixed rhythm of presses, which can't wait for a better moment as a player would.)
4. **Studio's frame rate came and went** (14 to 60). Times are good to a frame.

## More fish, 100 hops a setting
Later the same day. Asked "Try more fish, measured over about 100 hops a setting?": "Yes, try more fish", the user.
Lands 1 to 4: four legs of 25 hops, each from the lane's start (the sandbox's R, about s 600 to 8,600). The herd at
0.85, the safety switches on, Space every 3.0 s, hands off in the air. Studio drew at 60 frames a second (median; dips
to 9 to 38). Only the Studio copy of `Config` was changed; the repo stays at 20.

| Fish per 1,000 studs | 20 (today) | 30 | 40 |
|---|---|---|---|
| Hops landed | 100 of 100 | 95 of 97 | 100 of 100 |
| **Back onto the fish just left** | 21% | 18% | **13%** |
| Three or more of those in a row | once (longest 3) | 3 times (longest 4) | never (longest 2) |
| In the air, free fish within 95 studs (the one left counted) | 2.83 | 3.21 | 3.83 |
| Within 140 | 4.25 | 5.28 | 6.20 |
| **Time in the air with at most one fish within 95** (often just the one left) | 16% | 12% | **3%** |
| Fish in the Workspace round the rider at the end | 42 | 52 | 65 |
| The hook, the landing (medians) | 1.71, 2.12 s | 1.71, 2.12 s | 1.71, 2.12 s |

By land: land 1 is well stocked at all three (the dive's start keeps it full; one bounce in 11 to 14 hops each time).
The bounces are in lands 2 to 4, where at 20 the air holds at most one fish 15 to 23% of the time (1 to 8% at 40).
Both misses at 30 were in land 4, with no fish within 95.

### What it shows
1. **More fish cut the bounces back, step by step:** 21, 18, 13%. At 100 hops a setting that is a trend, not yet
   proof (chance alone gives one this size about one time in eight), but the time with nothing else in reach falls
   clearly, from 16% to 3%.
2. **Only 40 meets review 1's aim:** bounces under 15%, no dive ended for lack of a fish.
3. **40 is about the sea before 2026-11-17** (38), when you asked for less bunching "to make it more difficult to get
   from animal to animal". That day's spacing rules stay (each fish keeps its clear water, fish give way to each
   other), so it would not be the same bunched sea. But it is twice today's fish, and 55% more fish drawn round the
   rider: a cost on phones, not measured.
4. **The first try rode off the end of the lane.** 100 presses in a row with the safety on carried the rider the whole
   30,000 studs and beyond, where there are no fish (land 7 on); its second half bounced on one fish 45 times. Thrown
   out, and the legs above are now the method in [the tools](../../tools/review/README.md).

### Your call
Keep 20 (harder: about one hop in five lands back on the fish you left), 40 (more forgiving: one in eight), or between.
To feel them: Play, N, `Spawn.PerThousand` (it applies at once).

## Next
- **Pass 3:** [feel review 3](feel-review-3.md), the hook's speed.
- **The fish count:** measured above; your call.
- **The hook's model** (review 1, question 1), still open.
- **A hand playtest** at a proper frame rate, then a phone.
- **A sound recording of the reference** (OBS with desktop audio), for the sound pass.
