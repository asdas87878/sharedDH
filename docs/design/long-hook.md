# The long hook

Hooking onto a far fish should feel far, and land hard. Built 2026-11-18. Run and measured by script, not yet played.

Up: [Home](../../Home.md). Related: [the sling](sling.md) (the pull-in itself, and the fast-fish fix of the same day),
[the hook](hook.md) (the anchor and rope), [the wild ride](wild-ride.md) (the camera on a fish).

## What the user asked
"add an extra camera feature plus anything else to make hooking onto a far away fish feel really far away and
satisfying".

## How long counts as long
By the gap at the grab. Nothing changes under 55 studs, so an ordinary hop is as it was; all of it at 110 and over
(`Config.longOf`). The dive's first grab is left out: the dive has its own camera.

Measured over three test runs: the hooks were 22 to 103 studs; about one in three was 55 or more.

## What a long hook gets
1. **The long shot (the camera).**
   - As the hook flies out, the camera pulls back (up to 30% further) and the view widens (up to 6 degrees): the gap
     is seen.
   - As the rope hauls you in, the view narrows hard and the camera falls behind you.
   - At the touch it holds still for a beat (up to 0.07 s; four frames at 60 a second), with the landing waiting.
   - Then it all lands at once: the view snaps wide, the knock and the shake (both harder), and the camera swoops
     in after you.
2. **The landing is heavier:** a harder knock, a harder shake, twice the bubbles, and more speed lines in the
   pull-in.
3. **The sound:** the rope's rush rises in pitch and loudness as you are hauled in and stops dead at the touch, which
   lands with a deep thud.
4. **The word:** "LONG HOOK!" from 70 studs, "HUGE HOOK!" from 95, "MEGA HOOK!" from 115, with how far it was
   ("103 STUDS"), and "BEST!" when it is your longest this session. In the HUD's own letters, tilted, under the land
   strip. It slides up and fades; its text never changes size.

And for every hop, long or not: **the camera never falls more than 22 studs behind you** in a hop (33 on the longest
hook). A long pull-in arrives at up to 470 studs a second, and the camera, which follows on a spring, was left 90
studs behind at the touch: you were tiny in the distance at the very moment that should land hardest.

## The dials (`Config.Long`, in the N panel)
| Dial | Value | What it does |
|---|---|---|
| `Amount` | 1 | All of it, times. 0: off |
| `From`, `Full` | 55, 110 | Studs: where a hook starts to count as long, and where it is the longest |
| `Back`, `Wide` | 0.3, 6 | The camera's pull back and the wider view as the hook flies out |
| `Narrow` | 0.4 | The narrowing as you are hauled in, deeper by this share (0.7 at first: with the snap it threw the view from 70 to 104 degrees in one frame) |
| `Hold` | 0.07 | The beat at the touch, seconds. 0: none |
| `LandFov`, `Kick`, `Shake` | 0.2, 0.6, 0.5 | The landing's snap, knock and shake, this much more |
| `Leash` | 0.5 | How much further behind the camera may fall on a long hook (`Camera.ReelLeash` 22 for every hop) |
| `Lines`, `Splash` | 1, 1 | More speed lines, more bubbles |
| `Rush`, `Thud` | 0.55, 0.7 | The two sounds' loudness. 0: none |
| `Words`, `WordTime`, `Best` | 70 / 95 / 115, 1.2 s, 1 | The word, how long it stays, and "BEST!" |

## Measured
In Studio by script, hopping every three seconds, land 1:

| | Before the leash | After |
|---|---|---|
| The camera from you at a long hook's touch | 63 to 90 studs | 57 to 62 |
| The view through a long hook | narrows to 70 to 73, snaps to 100 to 104 | narrows to 73 to 76, snaps to 98 to 100 |
| The beat at the touch | 1 frame at 15 a second | 1 to 4 frames at 58 a second, by how long the hook was |
| Words | 3 of 3 long-enough hooks | 3 of 3 |
| Errors | none | none |

Seen in a capture: "HUGE HOOK!" in coral, "103 STUDS", "BEST!", under the land strip. Not seen moving.

## Not known, not done
- **Not felt by anyone yet.** `Long.Amount` is the first dial; `Hold` is the one most worth trying at 0 and at 0.1.
- **The word is the UI chat's to restyle:** it is in `Controllers/LongHookController`, made with `UI/Kit`, not in
  `UI/`.
- **Other players** don't see your long shot or your word (both are yours only). Your landing's splash and the fish's
  reaction they do see, as before.
- **Longer hooks since the same night:** straight ahead, just after the launch, the hook reaches about 140 studs
  ([the lock](the-lock.md), "Further in front"), so "MEGA HOOK!" (115 and over) can now happen.
- **The longest pull-ins still arrive very fast** (up to 470 studs a second). That is the sling's (`Jump.SlingCurve`,
  `SlingMax`); the long shot is built round it.
- Where it is in the code: `Controllers/LongHookController` (the long shot, the sounds, the word); the harder landing
  and `State.Touched` in `JumpController`'s touch; the hold, the pull back, the wider view and the leash in
  `RideController`'s camera.
