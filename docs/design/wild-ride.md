# The wild ride

Making a ride feel like a rodeo, not a train. Built 2026-11-17. Run and measured by script, not yet played.

The user, 2026-11-17: "making the ride feel proper, like rodeo wild style, because ours is still feeling too tame,
even though the speeds is technically correct, the actual feel isn't correct ... mass scale changes in character
placement on the fish, animations and camera shakes and camera movements ... make it really feel more wild,
untamed, and interesting, just in the way we manipulate the camera." And: "the character doesnt fully match with
the fish when riding ... the character clips into and out of the fish it isnt fully locked onto it".

## What was wrong

**Why it felt tame.** A fish was wild for two seconds after you landed on it, and then it carried you on rails:

| | Before |
|---|---|
| The fish's body | A small beat, turned down further on small fish and quick beats |
| Its line | Dead straight, at the herd's height |
| Its speed | One speed, to the stud |
| The camera | Still. The only shake of speed began at 78 studs a second, and no fish of the first lands reaches that |
| The rider | Both hands down, body still |

**Why the rider clipped.** It was built that way. The rider took only half of the fish's turning, a moment late,
and none of its keyed swim, so they would not be shaken. The back therefore moved through them.

## What is built

### 1. The rider is locked to the fish's back
- The game finds the part of the fish under the saddle once, and each frame gives the rider that part's exact
  move: the swim, the bends of a turn, a fit, a barrel roll, all of it, at once and in full.
- Measured: the rider moved 0.00 studs against that part in every direction over 271 frames of a wild ride.
- Dial: `Animation.RiderLock` (0 puts the old way back).

### 2. The fish throws fits while you ride it
- The seven reactions a fish already had for a landing (buck, thrash, bolt, wobble, shudder, startle, barrel
  roll) now come again and again: the first 2.6 seconds after the landing, then every 2.8 to 4.6 seconds.
- Each body type favours its own two. Barrel rolls are kept rare.
- **Rarer fish are wilder** (Common 0.85 up to Secret 1.35).
- **Your fish calms as you tame it:** by 45% when the taming is full. Wild when new, steadier when nearly yours.
- Its ordinary beat is 1.6 times bigger while ridden.
- Every player works out the same fits for the same fish, so all see the same.

### 3. The rider rides it like a rodeo
- The right arm is up, swinging the hook's rope. The left holds on.
- The hips are locked to the back; the chest and head are a moment behind every quick turn and catch up
  (whiplash).
- A buck still throws them off the seat; a fit still flings arms and legs.

### 4. The line and the speed move
- The fish's line rises and falls (3.5 degrees, about every 2.4 seconds) and weaves (2.5 degrees).
- Each stroke of the tail is a small push (3.5% of the speed).
- A bolt gathers (a fifth slower) and lunges (a seventh faster). The other fits check the speed by an eighth.
- All inside what the server allows.

### 5. The camera
- **Each fit has its own shake**, rolled to the side the fit goes: a buck is heavy and throws the view up, a
  thrash goes side to side, a wobble rocks slowly, a shudder is fine and fast.
- **A bolt** kicks the view 7 degrees wider, leaves the camera behind for a moment, and draws speed lines.
- **A loose sway at any riding speed**, from 25 studs a second, like a camera held by hand.
- **The view rolls into a turn**, 4 degrees.
- Each stroke of the tail is a faint knock.
- Bubbles burst from the tail at a fit.

## The one dial

`Wild.Amount` in the N panel scales all of it except the lock. 0 is the ride as it was. 2 is twice as wild.

| Dial (`Config.Wild`) | Value | What it does |
|---|---|---|
| `Amount` | 1 | Everything, times |
| `Fits` | 1 | 0: no fits after the landing's own |
| `FitMin`, `FitMax` | 2.8, 4.6 | Seconds between fits |
| `Fit` | 0.75 | How hard a fit is, against a landing's reaction |
| `TameCalm` | 0.45 | How much a nearly tamed fish calms |
| `Body` | 1.6 | The ridden fish's beat |
| `Whip` | 0.7 | The rider's whiplash. 0: stiff |
| `Rodeo` | 1 | 0: both hands down |
| `Porpoise`, `Weave` | 3.5, 2.5 | The rise and fall, the weave, degrees |
| `BeatSurge` | 0.035 | The push of each tail stroke |
| `FitSpeed` | 1 | 0: fits don't change the speed |
| `Shake` | 1 | The fits' shakes |
| `Rumble` | 1 | The loose sway |
| `CamRoll` | 4 | The roll into a turn, degrees |
| `BoltFov`, `Pull` | 7, 0.14 | A bolt's wider view and the camera left behind |
| `BuckKick`, `BeatKick` | 0.3, 0.03 | The view knocked by a buck, and by each tail stroke |

## Measured

One ride of 24 seconds in Studio by script, steering left and right once (land 1, a Common fish):

| | Result |
|---|---|
| The rider against the fish's back | 0.00 studs of movement |
| Fits | 6, the last a bolt |
| Speed | 66 on average, up to 75 |
| The line's climb and dive | 6.9 degrees down to 5.5 up |
| The camera's roll | 3.8 degrees each way |
| The field of view | 70 to 90 |
| Errors | None in a second run (the first found one in the pull-in's pose, fixed) |

One capture looked at: the rider on a cuttlefish, the right arm up with the rope to the anchor.

## Not known, not done

- **Not seen moving.** Whether it is wild enough, or too much, is the user's to say. `Wild.Amount` is the first
  thing to turn.
- **It may be too much on a phone,** where the same shake looks harder. `Config.Shake.Touch` already turns
  shakes down there; the sway and the roll have not been looked at on one.
- **The rider's seat was not re-placed fish by fish.** The lock fixes the moving through. Where the saddle sits
  on each of the 82 creatures is as it was.
- **Other players' fits show on their fish and rider,** but their fish don't change speed or line for it; only
  your own does.
- Stand-in fish (no model) have no fits.
- Where it is in the code: `seatOf`, `seat`, the fits and `astride` in `AnimController`; the block headed "The
  wild ride" in `RideController.drive`; `WildController` (new) for the camera; the "Fit..." and "Ride" presets
  in `Config.Shake`.
