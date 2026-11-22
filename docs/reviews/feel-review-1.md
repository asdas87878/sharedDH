# Feel review 1: Ride a Dino against ours

The core loop measured on both sides, compared, with what to change. Written 2026-11-19, measured 2026-11-18 and 19.
Meant to be run again (passes 2 and 3) with the same measurements: [the tools](../../tools/review/README.md).
**Pass 2:** [feel review 2](feel-review-2.md) (the hover, the landing snap, the throw, the herd at 0.85).

Up: [Home](../../Home.md). Related: [the lock](../design/the-lock.md), [the sling](../design/sling.md),
[riding feel](../design/riding-feel.md), [Ride a Dino](../reference/ride-a-dino.md),
[the deep study](../reference/ride-a-dino-deep.md), [progression](../design/progression.md).

## What the user asked
"Could you do a large scale test of Ryderdino's mechanic, how the satisfying feel is created and their general flow, and
then compare it to ours? Test the points of weakness, points where ours is potentially stronger, and just generally
evaluate what we should change and what we might have missed so far. And just, we're sort of pulling all these pieces
together and seeing how to balance and tune it better. We might want to do this process once, twice, 3 times".

## How it was done
| Part | What | Source |
|---|---|---|
| Theirs, measured | Every hop in the user's four recordings, frame by frame: the jump button's state, the second press, the camera's motion, the landing's effects | `D:\program files for me\videos\` (private) |
| Theirs, heard | What creators say at each moment of the loop: all 19 Ride a Dino transcripts with speech, about 4 h 20 min | the research cache (nothing fetched) |
| Ours, on paper | Every timing, camera move, sound and effect in the code, per moment, with the open items in our notes | `src/`, `docs/design/` |
| Ours, measured | Scripted chain-hopping in Studio: 25-hop runs with today's settings and two levers, and dives with the sandbox's safety switches off | Studio, land 1 |

**How far to trust it:**
- Nothing on our side has been played by a person: every run is scripted.
- Studio drew at 7 to 14 frames a second, so our times are coarse (0.07 to 0.14 s).
- The recordings have no sound: every audio track is silent. The sound comparison is not done.
- Each of our runs swims through a different stretch of a random sea, so counts like "back onto the same fish" swing a
  lot from run to run.

## The headline
1. **Ride a Dino has no hands-off hook.** Every one of the 50 landings that could be checked in the recordings comes
   0.20 to 0.57 s after a second press (the button's pressed look). That press throws the lasso (their lesson calls it
   "Drop"), and the four hops with no second press all missed: the rider fell to the ground about 2 s after the jump
   and the run ended. **This corrects yesterday's airtime study:** the "hook at 1.7 s" was when that player chose to
   press, not a timer. Players pressed anywhere from 0.4 s to 2.1 s after the jump.
2. **Our biggest gap is the supply of next fish.** In Ride a Dino there is nearly always a dino under the ring. In ours,
   9 to 48% of hops (by run) landed back on the fish just left, which gives no oxygen. With the safety switches off,
   dives ended after 5.5 s (no fish to lock) and 33 s (out of air after a bounce back).
3. **Our timing windows are razor thin on a land-1 Common.** You can ride it 2.5 s; a tame takes 2.0 s, so a tame
   needs a hop in a 0.5 s window. The first fit comes at 2.6 s, so a new player never sees one.
4. **Our landing snap is much bigger than theirs:** about 76 to 98 degrees of view in one frame, against their 0.80 of
   the picture (about 70 to 82).
5. **Where ours is ahead:** choosing the target (their only complaint about the hop), leniency (they have no fallback:
   no press, you fall), the long hook, and the hook you can see thrown.
6. **The most important next step is a hand playtest** at a proper frame rate, then a phone.

## The loop side by side
| Moment | Ride a Dino (measured or said) | Ours (built; measured where marked) |
|---|---|---|
| The jump | The camera rises with the rider (the picture drops 25 to 46 pixels over 3 frames); after a settled ride the view widens to 0.93 to 0.97 in one frame. No ring or burst. Rise about 0.2 s fast, then slow | Pop 0.4 s, 20 studs up, the view 7 degrees wider, a Hop shake, 16 bubbles, a swish and a slow whoosh, the slow-mo look, zoom to 1.35 |
| The glide | Height held until the throw. The camera does not zoom. The rider floats at the herd's pace: the dino under them stays under them | Flat glide at the top, still at 90% of the leaving speed at 1.7 s: faster than the herd, so fish slide back under you |
| The target | A ring under the rider takes the nearest dino, again every frame, with an edge; the button greys out with nothing under it | The fish nearest the camera's line in front of you, A/D step it, the reach to the whole body, longer straight ahead early |
| The hook | **The second press throws the lasso** (0.4 to 2.1 s after the jump, by player). The view widens to 0.944 in one frame at the throw (19 of 21 hops) | Hands off at 1.7 s, or a press from 0.15 s. The anchor is thrown and bites (a tick, 12 bubbles). No camera punch at the throw |
| The pull-in | A zip: 0.20 to 0.30 s when close, 0.40 to 0.57 s otherwise; a yellow spark trail | The sling: 0.30 to 0.40 s (measured), the view narrows, yellow dots, speed lines, a whoosh |
| The landing | The view snaps wider to 0.80 in one frame, then a 7 to 20 pixel bump for 1 to 3 frames; eases back over about 0.5 s. A white ring at the feet for 0.15 to 0.2 s, a yellow dust cloud the whole ride; the ring vanishes | The view snaps about 76 to 98 degrees (0.68 of the picture), a knock, a Land shake, a splash, 26 bubbles, a coloured ring, a Pop; the body lands one server round trip later |
| Between hops | Riding is steady (no bob in the camera); hop again 0.35 to 0.57 s after landing (median by recording) | The stride's camera pulse and footfall thumps; ride time is the player's (we tested 0.3 to 1.1 s) |
| Hops a minute | 21 to 35 | 20 to 23 in our tests (set by the test's rhythm) |
| The ride window | The green ring: time left on this dino; every landing fills it whole | A land-1 Common: 2.5 s; every landing on another fish fills it whole; **back onto the same fish: no refill** |
| A miss | No press, or nothing under the ring: fall to the ground about 2 s after the jump, run over; "it costs seconds" | No fish in reach: the window runs out at 3.5 s, a 2.8 s drown, on the dock about 6.3 s after the press |
| Taming | Two rings race: the pink fills while the green drains; a tame at the last second is the game's peak | 2.0 s of one unbroken ride; on a Common, hop between 2.0 and 2.5 s |
| Sound | Not measurable: the recordings are silent | Roblox stand-ins; the tame, a miss, the red part and the buttons are silent; no music |
| A run | 1 to 2 minutes, then a 20-second hub checklist | Dives of 5.5 s to over 33 s with the safety switches off (three dives) |

## What makes theirs satisfying
From the creators' words and the measurements together (the evidence, by video and time, is in the helper's write-up).
- **The delight is on the first press, before anything is owned.** After the first minute nobody talks about the leap
  or the landing again: everything said in the air is about the target. The choosing is the game they feel.
- **A beat every two seconds that always pays.** A landing refills the green ring whole, so the safe thing is always
  to hop, and players settle into hopping past everything but what they want.
- **Two rings, one decision every few seconds.** The pink tame ring racing the green one is read at once (players
  compare it to Zelda's stamina wheel); the peak of the whole game is a tame that lands at the last second.
- **Two presses: jump, then throw when the ring is on what you want.** Timing and target are the skill, and a missed
  throw is visibly your own.
- **The camera punches at three moments:** the jump (a small widen), the throw (about 5%), the landing (about 20%,
  with a bump), and is steady in between.
- **Failing costs seconds, not things.** Every catch is kept; being eaten is laughed off; dying is the usual way home.
  A failure that names its cure ("needs more stamina") works.
- **Speed is the second stat players feel:** 13 of 19 videos ask for a fast mount or curse a slow one.

**What frustrates them:** a dino whose tag shows your own number throwing you off (the loudest late complaint), tames
that fail with no reason given, not being able to pick the target (one creator, four times), tags passing too fast to
read at speed, stray presses that cost a tame, and a far end that pays nothing.

## Where ours is weaker
In order of how much they matter to the loop.

### 1. The next fish is not there often enough
- **What we measured:** 25-hop runs, chain-hopping. With today's settings, 48% of hops in one run and 9% in another
  landed back on the fish just left. With twice the fish, 21%; with the herd at 0.85 of the pace, 25%. In the air there
  were 2.7 free fish within the hook's 95 studs on average, the one just left among them.
- **Why:** a ridden fish swims faster than the herd (land 1: about 66 against 48), so you are soon at the front of the
  fish around you, and the hop flies faster still. The reference's herd swims at 0.85 of riding speed and its rider
  floats at the herd's pace.
- **Why it matters:** a bounce back gives no oxygen, so a run of them drowns you; and the loop's verb, getting to the
  next one, is missing from up to half the hops.
- **Your calls behind it:** fewer fish (2026-11-17: "less bunching to make it more difficult to get from animal to
  animal") and the herd at 0.7 (2026-11-16, so more fish go past and a landing kicks; still open in
  [the herd revamp](../design/herd-revamp.md), question 2). The measurement suggests the difficulty shows up as
  bouncing on your own fish rather than as hard choices.

### 2. The glide outruns the herd
The reference's rider floats over its dino at the herd's pace; ours glides at 90% of the leaving speed. The target
slides on screen, the sling must bend back, and fish ahead are overtaken. "Hover with your target" is step 3 of
[the sling's plan](../design/sling.md) and is not built.

### 3. The windows on a Common are razor thin
A land-1 Common rides 2.5 s; a tame takes 2.0 s, so taming it needs a hop between 2.0 and 2.5 s, and an Uncommon (2.0
s) tames only in the tick it throws you. The first fit comes at 2.6 s, after every land-1 Common has run out. In the
reference the two rings race in plain sight and the last-second tame is the best moment; ours is a half-second you
cannot see coming. (These are the tuning chat's numbers: `Config.Tame`, `Oxygen`, `ZoneDrain`.)

### 4. The landing snap overshoots
Ours jumps from about 76 to 98 degrees of view in one frame (0.68 of the picture) because the speed's widening stays
on until the mount; theirs is 0.80. Ours may read as a jolt rather than a punch.

### 5. No sound to speak of
Every sound is a Roblox stand-in; the tame, a miss, the red part, the land strip and the buttons are silent; there is
no music or ambience. Theirs could not be measured (silent recordings).

### 6. A miss costs a run, and late
Ours: the window runs to 3.5 s, then a 2.8 s drown, the dock 6.3 s after the press. Theirs: you hit the ground about
2 s after the jump and are back fast. Both end the run; ours makes you wait longer for it.

### 7. Our notes disagree with the code
The inventory found stale numbers across the older notes (the launch, the reach, the refill, the herd's pace, the
hop's timing) and comments that say A and D turn the camera. Housekeeping, but it misleads whoever tunes next.

## Where ours is (or could be) stronger
None of these has been felt by a player yet.
1. **Choosing the target.** The lock in front of you, A/D stepping across fish, the camera's look: their one
   complaint about the hop is that the ring chooses for you.
2. **Leniency.** Theirs has no fallback: no press, you fall. Ours hooks by itself at 1.7 s, takes any fish in reach
   on a press, measures the reach to the whole body, reaches further straight ahead early, and keeps a lock 0.6 s
   after it slips out.
3. **The long hook:** the camera, the rush, the thud and "LONG / HUGE / MEGA HOOK!": a payoff for distance they don't
   have.
4. **A hook you can see:** the anchor whirled, thrown, biting, the rope pulling taut.
5. **A sea in three dimensions:** layers by height, fast fish high, hunters above, bolts. More variety than a herd on
   the ground, if it reads at speed.
6. **Life while riding:** the stride, the wild ride and its fits (theirs is a steady view over a bobbing dino).

## What we may have missed
- **The throw as the player's act,** with a button that greys out when there is nothing to throw at.
- **A camera punch at the throw** (theirs widens about 5%).
- **A quick, cheap end to a failed hop,** and a way home mid-run.
- **A hop counter or streak** (in [the sling's plan](../design/sling.md), step 5, not built).
- **Tags you can read at speed.**
- **A guard against a stray press just before a tame finishes,** and a stated reason when a tame fails.
- **Landing on your own machine at the touch** instead of a server round trip later (the sling's plan, step 6).
- **Music and ambience; a sound for every event.**
- **The server clock and announced rares** (planned: Refinement stage 3).
- **A phone test.**

## What to change
| # | Change | Why | Where | Whose call | How to check (pass 2) |
|---|---|---|---|---|---|
| 1 | **Decide the hook:** keep the hands-off hook only as a later fallback (about 2.0 s), so the second press, the throw, is the main way, as in the reference; or keep it at 1.7 | Theirs is a two-press loop; ours copied a player's press time as a timer | `Jump.SlingBy`, `SlingAfter` | **Yours** | Presses per hop, hops landed by press against by timer, in a hand playtest |
| 2 | **More next fish:** the herd at 0.85 of the pace, then more fish if still short | 9 to 48% of hops bounce back; the reference's herd is at 0.85 | `Herd.SpeedShare`, `Spawn.PerThousand` | **Yours** (you set 0.7 and 20) | Back-onto-the-same under 15%; dives not ended for lack of a fish |
| 3 | **Hover with your target:** the glide eases to the locked fish's pace | The reference floats at the herd's pace; ours outruns it | `JumpController` (the glide) | Mine to build | The target's drift on screen; the pull-in's bend |
| 4 | **Wider windows on Commons:** a ride long enough to see a tame coming, the first fit inside it | 0.5 s to tame; fits never seen | `Tame.Time`, `Oxygen`, `Wild.FitFirst` | With the tuning chat | Tames per dive, fits seen per dive |
| 5 | **The landing snap at the reference's 0.80** | Ours is 0.68 | `Jump.LandFov` and the speed's widening at the touch | Mine | The view's jump measured at the touch |
| 6 | **A camera punch and a sound at the throw** | The reference's 5% widen | `JumpController` (startReel) | Mine | Seen in a capture |
| 7 | **A faster miss:** the window's end sooner when nothing is in reach | 6.3 s to the dock against about 2 | `Jump.Window`, the drown | Yours | Seconds from the miss to riding again |
| 8 | **A sound pass** | All stand-ins, key events silent | `Feel`, `HookController`, the HUD | Needs theirs measured first: a recording with desktop audio, or your word to fetch a YouTube stretch | Their sound per event against ours |
| 9 | **Play it by hand at a proper frame rate, then on a phone,** with the feel log's marks | Nothing built on 2026-11-17 or 18 has been felt | | You and Hugo | The feel log |
| 10 | **Bring the notes in line with the code** | The inventory's list | the older notes | Mine | |

## Corrections to earlier notes
- **The airtime study (2026-11-18)** read the reference as hooking by itself about 1.7 s after the jump. It does not:
  every landing follows a second press. Corrected in [Ride a Dino](../reference/ride-a-dino.md), "Airtime".
- **In Studio the sandbox starts with no fail and endless air on,** so oxygen never drains and a miss never drowns you.
  Our test runs before this review all had them on; this review's last dives had them off.

## Measured: the numbers
**Theirs, the cycle** (from the user's recordings; "the throw" is the second press):

| Recording | Hops (landed / missed) | Air, landed (median, range) | Ride between hops (median) | Jump to the throw | Throw to landing | Hops a minute |
|---|---|---|---|---|---|---|
| 35 s ride | 10 (9 / 1) | 2.07 s (1.43 to 2.40) | 0.57 s | 1.70 s (0.93 to 2.10) | 0.30 s (0.20 to 0.50) | 21.8 |
| Side-on | 13 (12 / 1) | 1.30 s (0.93 to 2.20) | 0.35 s | 0.95 s | 0.47 s | 34.6 |
| 5-minute, run 1 | 17 (17 / 0) | 0.87 s | 1.13 s | 0.43 s | 0.40 s | 21.3 |
| 5-minute, run 2 | 14 (13 / 1) | 0.87 s | 0.83 s | 0.40 s | 0.40 s | 24.1 |

**Theirs, the camera** (the 35 s ride and the side-on; a scale under 1 is the view widening):

| Moment | Measured |
|---|---|
| Riding | Steady: no bob at the stride's rate; 1.3 to 2.8 pixels of jitter |
| The jump | The picture drops 25 to 46 pixels over 3 frames; after a settled ride it widens to 0.93 to 0.97 in one frame (after a short ride it tightens, cutting the landing's ease short) |
| The glide | No zoom |
| The throw | Widens to 0.944 in one frame (19 of 21 hops) |
| The pull-in | The target rushes in over the last 0.1 to 0.3 s |
| The landing | Widens to 0.80 (0.76 to 0.88) in one frame, then a 7 to 20 pixel bump for 1 to 3 frames; eases back over about 0.5 s (low confidence) |

**Ours, in Studio** (land 1; 25 presses 3.0 s apart; the client at 14 frames a second):

| | Today (fish 20 a 1,000, the herd at 0.7) | Twice the fish | The herd at 0.85 |
|---|---|---|---|
| Hops landed | 25 of 25 | 24 of 24 | 24 of 24 |
| Back onto the fish just left | 12 (48%) | 5 (21%) | 6 (25%) |
| The hook | 1.70 to 2.00 s | median 1.73 | median 1.75 |
| The landing | 2.10 to 2.43 s (median 2.17) | median 2.18 | median 2.18 |
| Free fish within 95 studs in the air (the one left included) | 2.71 | 3.31 | 2.84 |
| Within 140 | 4.20 | 5.83 | 5.16 |

**Ours with the safety switches off** (presses 2.6 s apart, diving again after each drown): three dives of 5.5 s
(ended by a press with no fish locked), 33 s (12 hops, out of air after landing back on the same fish) and 15 s (still
going); 2 of 22 hops back onto the same fish.

## Next pass
- Run `tools/review/` again after the changes, on the same land, with Studio drawing properly.
- Add a hand playtest: you mark the fish you wanted (the feel log's numbers), and count presses per hop.
- Measure their sound, given a recording with desktop audio (OBS: add the desktop audio source) or your word to fetch
  one YouTube stretch.
- Measure a deeper land, where the oxygen gate bites.
