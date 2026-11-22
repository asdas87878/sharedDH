# The lock

Which fish a grab takes, and how far the hook reaches. Built 2026-11-18 in two passes the same evening, both run and
measured by script, neither played yet.

Up: [Home](../../Home.md). Related: [the sling](sling.md) (step 2 of its plan, "the intent lock"),
[riding feel](riding-feel.md) ("The lock-on": the camera's lock, which `Lock.Pick` 1 keeps), [the hook](hook.md),
[Ride a Dino](../reference/ride-a-dino.md) ("How the ring picks").

## What the user asked
First: "we still need the hook system to feel like it has a higher leniancy. Theres a mechanic in ride a dino in which
when you hop off a dino it pretty much auto selects the one in front of you for the most part. it also switches
selection often times when you press a or d on the keyboard. I dont know if thats intentional or a byproduct of the way
it was coded but id like to find a way to implement higher leniancy, the a d thing through whatever way it happens in
ride a dino and the auto selection or do it as a byproduct if its like that in ride a dino."

Then, after the first pass: "sometimes the a d function attatches to a fish thats basically behind the player or just
coming up to its peripherals instead of a fish in front or where the a d or camera is aiming. That needs to be fixed,
additionally id like you to change how the hitboxes for the fish work ... it should be based on the whole fish so that
large fish dont feel further than they are. meaning the hitbox for grabbing to the fish in the code should include the
tail/the full length of the fish".

## How the reference does it
Read off your own recording of 2026-11-10, frame by frame (the details are in [Ride a Dino](../reference/ride-a-dino.md),
"How the ring picks"). The ring lies under the rider and takes whichever dino is nearest it. It picks again every
frame, with no hold. Steering moves the rider, so it moves the pick.

- **The A/D switching is a byproduct.** Nothing about the keys picks a dino: they move you, and what is under you
  changes.
- **"The one in front"** is the dino you are flying over next.
- **It has an edge:** a dino just outside the ring is not taken. In the recording that is how a hop missed.

## What the lock does now (`Lock.Pick` 2)
1. **It takes the fish in front of you, where the camera looks.** Every free fish in the hook's reach is measured from
   the line the camera looks along, through you, as it and you will be 0.4 s on.
   - Off to the side counts in full. Being ahead counts a third (`LineAhead` 0.35), so the fish in front on the line
     wins. Being behind counts three times (`LineBehind`). Height counts 0.6.
   - A big fish counts as nearer by a quarter of its length (`LineBody`).
   - **Only fish in front count:** within 60 degrees of the camera's look, from you, both where the fish is now and
     where it will be (`FrontAngle`). The locked fish may drift 20 degrees further (`FrontKeep`).
   - **A fish beside you** (60 to 110 degrees round, `FrontAside`), say one coming up from behind, is taken only when
     no fish in front is in reach.
   - **A fish behind you is never newly taken.** The exceptions are the last chance at the end of the glide, which
     takes any fish in reach as before, and the fish you just left, when no other is in reach. A fish already locked
     keeps the lock as it slides back past you, so flying over it still lands you on it. Any fish in front takes the
     lock from it.
   - There's no cone and no aiming. The mouse still chooses: turn the view and the lock follows it at once.
2. **A or D steps it to the next fish that way,** in front of you: the one nearest round from the locked fish, at
   least 3 degrees further (`StepGap`). Holding the key steps again every 0.3 s (`StepEvery`). With no fish that way,
   the lock stays. A key already held when you hop counts only once you press it again.
   - The fish you step to keeps the lock until you step or turn the view again, or it leaves your reach or your front
     (`LineChosen`).
3. **Calm when you do nothing.** The locked fish keeps the lock until another is 12 studs nearer the line
   (`LineKeep`), and never within 0.12 s of the last switch (`LineHold`).
4. **The reach is to the whole fish** (`WholeBody`). Each fish's body is a box of its length, height and width round
   its middle, turned the way it swims. The hook reaches to the nearest point of that box, head to tail, not to the
   fish's middle. The server measures it the same way (`RideService`, `reachNearness`), with the same allowance for
   the delay as before. A 60-stud fish used to be 30 studs further away than it looked, tail on.
5. **Further in front, just after you launch** (`Jump.AheadReach`; the user, the same night: "you should still be able
   to hook further infront of you, especially if youre just launched forward it feels too short distance").
   - Straight ahead of you, where the camera looks, the hook reaches 1.5 times as far: about 140 studs at the launch,
     against 95 to the side.
   - It reaches less the further round a fish is: all of it within 20 degrees of the camera's look (`AheadFull`), none
     from 60 degrees (`AheadNone`).
   - In time: all of it for the first 0.9 s of a hop (`AheadFor`), easing back to the plain reach by 1.9 s
     (`AheadUntil`), about when the glide ends and the pull-in starts by itself.
   - To the side, behind, and late in the hop the reach is as before. That keeps your call of 2026-11-17 ("we need a
     lesser distance to grab onto the next fish when in the air") everywhere but straight ahead.
   - The server can't see where the camera looks, so in that window it allows the longer reach all round.
   - Long hooks get longer: a grab straight ahead at the launch can be up to about 140 studs, so "MEGA HOOK!" (115 and
     over) can now happen ([the long hook](long-hook.md)).
6. **Leniency from the first pass, kept.**
   - A press with nothing locked, or the locked fish just out of reach, takes the fish nearest the line anywhere in
     reach: one in front first, then one beside you, never one behind, the one you left last (`PressAny`). Before, it
     only flashed the reticle red.
   - A locked fish that leaves your reach keeps the lock for 0.6 s (was 0.45), and a grab may take it from 1.2 times
     the reach (was 1.12; the server allows 1.3).
   - The hands-off pull-in waits while you hold A or D or turn the view, so it never grabs the old fish mid-switch.

- **The camera's old lock is kept whole:** `Lock.Pick` 1 in the N panel puts it back.
- **The reach (`Jump.GrabRange`) is as you set it.** Only where it is measured to has changed.

## The first pass, and what was wrong with it
The first pass copied the reference's byproduct: the line was the way you fly, and A and D turn the way you fly.

- In a test, a tap of A or D with a fish that way moved the lock 6 times in 8, all to that side; the camera's lock
  moved it 2 times in 8.
- **But A and D turn you up to 90 degrees off the view** (`Ride.KeyAngle`), so the fish "ahead on your line" could be
  beside you, behind you, or at the edge of the screen. And a fish steered onto was held on purpose (letting go of a
  key turns you back, which had handed the lock straight back). So a wrong pick stuck. That is what you saw.
- The second pass keeps the line on the camera's look and makes A and D step across the fish in front.

## The dials (`Config.Lock`, in the N panel)
| Dial | Value | What it does |
|---|---|---|
| `Pick` | 2 | 2: in front, by the camera's look, A and D step. 1: the camera's old lock |
| `FrontAngle`, `FrontKeep` | 60, 20 | Degrees round from the camera's look that count as in front, and how much further the locked fish may go |
| `FrontAside` | 110 | Up to here a fish is beside you (taken only with none in front); further round it is behind you (never newly taken) |
| `StepEvery`, `StepGap` | 0.3, 3 | Holding A or D steps again this often; the next fish must be this many degrees further round |
| `LineAhead`, `LineBehind`, `LineUp` | 0.35, 3, 0.6 | How much being ahead, behind, and above or below count against being off to the side |
| `LineLead` | 0.4 | How many seconds ahead each fish and you are judged |
| `LineBody` | 0.5 | Big fish are easier, by this share of half their length |
| `LineKeep`, `LineHold` | 12, 0.12 | The hold when you aren't steering |
| `LineKeepSteer` | 0 | The hold while the view is being turned (0: none) |
| `LineChosen` | 200 | How hard a fish you stepped or turned onto keeps the lock (200: until you step or turn again) |
| `SteerSeen`, `SteerKeep` | 25, 0.25 | The view counts as being turned above 25 degrees a second, and for 0.25 s after |
| `PressAny` | 1 | 0: a press with nothing locked only flashes, as before |
| `WholeBody` | 1 | 0: the reach to the fish's middle, as before |
| `Jump.AheadReach` | 1.5 | How many times as far the hook reaches straight ahead at the launch (1: no further than to the side) |
| `Jump.AheadFull`, `Jump.AheadNone` | 20, 60 | Degrees round from the camera's look with all of it, and with none |
| `Jump.AheadFor`, `Jump.AheadUntil` | 0.9, 1.9 | Seconds into a hop with all of it, and with none |
| `Linger`, `LingerReach` | 0.6, 1.2 | The leeway |

## Measured
Studio wasn't drawing for this pass (the client ran at 6 to 8 frames a second), so the rules were tested on their
own, in Edit, with test fish set round a rider, and then in one short live run.

**The rules, with test fish** (the lock's own code, in Edit; a rider with A ahead, B and C ahead to the right and
left at about 35 degrees, D beside, 97 degrees round, and E behind, 173 degrees round):

| Test | The lock took |
|---|---|
| Hands off | A, the fish ahead |
| D from A, then D again | B, then B still: D beside you is not a step |
| A (the key) from B, then again | A, then C |
| Nothing pressed after that | C kept the lock |
| Only D beside and E behind in reach | D |
| Only E behind | nothing; in the last chance, E |
| E locked already, sliding behind you | E kept the lock; with A in front, A took it |
| A press with nothing locked, only E behind | nothing; with D beside too, D |
| A test eel, 130 long, its middle 117 studs away, its nearest point 61 (reach 95) | the eel; measured to its middle (`WholeBody` 0), nothing |

All 15 as meant.

**Further in front** (the same way, after the longer reach went in; the 15 above were run again and still hold):

| A fish (the reach to its body) | Just launched | 2 s into the hop |
|---|---|---|
| Straight ahead, 124 studs | reach 142: locked | reach 95: not |
| 45 degrees round, 123 studs | reach 110: not | reach 95: not |
| 45 degrees round, 98 studs | reach 110: locked | reach 95: not |
| Beside you, 102 studs | reach 95: not | reach 95: not |

**Live, in Play** (hands off, with two A/D presses, at 8 frames a second): no errors, and the server judged every grab by
the body. Four grabs were all allowed, and all landed. One stingray (48 long) was grabbed at 40 studs to its
body, while its middle was 77 away. Two of six hops missed. One had no fish in reach at all. The other lost a
locked fish as it slid behind, which is what the "it keeps the lock" rule above was added for. At that frame rate the
run says little about feel.

**From the first pass** (the line by the way you fly; more fish than your sea has): a tap of A or D with a fish that way
moved the lock 6 times in 8, all to that side; the camera's old lock moved it 2 times in 8. Every hop landed (37 in
four runs).

## Not known, not done
- **Not felt by anyone yet, and not seen at a proper frame rate.** Studio wasn't drawing for the second pass. `Lock.Pick`
  1 against 2, and `WholeBody` 0 against 1, are one click each in the N panel.
- **The thin sea is the limit for A and D.** Your sea keeps about two fish in the hook's reach at a time, so a step
  often has nothing to step to. The reference's herd is thick ("five or six abreast"). `Spawn.PerThousand` (20 since
  2026-11-17: "less bunching") is yours to raise.
- **The body box is the type's size** (`Config.bodyOf`: its length, height and width), not each model's own shape: a
  thin tail or long fins outside the box don't count, and a round fish's corners count a little more than it shows.
- **Not tried with a gamepad or on a phone.** Their sticks give the same move input as A and D.
- Where it is in the code: `Lib/Lock` (`lineScore`, the step, the line's hold, `Lock.any`), `Config.bodyGap` and
  `Config.fishGap` (shared), `JumpController` (`pick`, the steps it passes in, the press, every reach check),
  `RideService.reachNearness` (the server's grab).
