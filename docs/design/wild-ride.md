# The wild ride

Making a ride feel like a rodeo, not a train. Built 2026-11-17. Run and measured by script, not yet played.
The stride (the fish's steps, left and right in turn) came on 2026-11-18: "The stride" at the end.

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

## The stride (2026-11-18)

The user: "could we try to alter the movement and camera shake of the fish so that the feel is more rhythmic like ride
a dino. Ride a dino you feel the feet step from side to side in a rhymic manner, we need something more akin to that
from what we have".

### Why ours had no rhythm
- **The camera never felt the fish's body.** The rider is fixed to the body, but the camera follows the rider's root
  part, and that rides the fish's Root. The body's swim is drawn on top of the Root, so the camera saw none of it.
- **The camera's only riding motion was noise.** The loose sway (`Wild.Rumble`) is random, so it shook the view
  instead of carrying it.
- **The body's beat was one smooth wobble:** up, sway and roll together, once a beat, and tiny on small fish (a land
  1 fish rose and fell less than a tenth of a stud).
- **Nothing landed.** A step is felt as a sudden stop at the bottom. A smooth wave has none.

### Ride a Dino, measured (2026-11-18)
On the user's word ("Yes, measure it"): eight seconds of a ride at 30 frames a second, a big two-legged dino ridden
straight with the camera behind, measured frame by frame. The numbers and how they were read are in
[Ride a Dino's breakdown](../reference/ride-a-dino.md), "The stride while riding".
- **One step every 0.45 seconds** (2.2 a second), the same in both straight stretches.
- **The dino and the rider bob together, about a stud,** in a smooth wave: lowest at each footfall, round at the
  bottom and the top. No hard footfall.
- **They shift about half a stud to each side,** one way each step: over soon after the footfall, held for most of
  the step, back through the middle at the next one.
- **The camera does not step.** The scenery moved about 2 pixels at the step rate, at the edge of what can be read,
  against 9 for the dino. The steps are seen in the animal and the rider, in a steady view.

So our stride was changed to match: round steps (`Sharp` 0.65 to 0), the side held (`Hold` 0.6, new), and the
camera's share cut to a faint pulse (about a quarter of what it was). The fish's own steps are as they were.

### What is built
Each stroke of the tail is one step, to the left and the right in turn.
- **The fish:** at each footfall its body is at its lowest and its nose dips; between footfalls it rises, in a round
  wave. It shifts over onto each step's side soon after its footfall (it rolls and swings its nose that way), holds
  there, and swings through the middle onto the other side at the next footfall.
- **Each kind steps its own way,** from its style: dolphins and whales heave more, eels and puffers rock and swing
  more, and a bigger animal moves more. Its old beat still plays under the steps, at 30%.
- **How fast:** a step is one beat of the fish's own swim, which already quickens with speed and slows with size. It is
  kept between 1.2 steps a second (a giant's stomp) and 3.2 (a small fish's patter).
- **The rider** goes with the back, gives at each footfall (the back rounds forward, the knees fold) and rises
  between. The chest leans a little against the roll, and the free arm bounces with the steps.
- **The camera** stays nearly still, as Ride a Dino's does: a faint dip, lean and jolt at each footfall. On a phone it
  is less, as every shake is.
- **A soft thump** marks each footfall, a little lower on one side than the other.
- **The loose sway is cut to a tenth** under the steps: it is noise, and the reference has none.

### The dials (`Config.Stride`, in the N panel)
| Dial | Value | What it does |
|---|---|---|
| `Amount` | 1 | All of it, times. 0 is the ride as it was, with the old sway and knock |
| `MinRate`, `MaxRate` | 1.2, 3.2 | Steps a second, at the least and the most |
| `Sharp` | 0 | How hard a footfall lands. 0: a round wave (the reference's); 1: a drop that stops dead (0.65 at first) |
| `Hold` | 0.6 | The shift to a side. 0: a smooth swing; 1: over at once and held |
| `Drop`, `Roll`, `Yaw`, `Nod` | 0.5, 6, 2.5, 3 | The fish: studs down, degrees over, nose to the side, nose down |
| `Style` | 0.3 | How much of the old beat plays under the steps |
| `Bob`, `Sway`, `Lean`, `Dip` | 0.12, 0.06, 0.4, 0.15 | The camera: studs down, studs over, degrees of lean, degrees down (at first 0.45, 0.35, 1.6, 0.7) |
| `Kick` | 0.02 | The camera's jolt at each footfall, studs (0.06 at first) |
| `Rumble` | 0.1 | How much of the loose sway is kept (0.25 at first) |
| `Post` | 1 | The rider giving with the steps. 0: sits still |
| `Sound` | 0.2 | The thump's loudness. 0: none |

For a camera that steps as well, turn up `Bob`, `Lean` and `Kick`: the first version's numbers are in the table.

### Measured
In Studio by script, land 1, the camera never moved:

| | First version: a Pufferfish at 52 studs a second, 14 s | Matched to the reference: a Butterflyfish, 10 s |
|---|---|---|
| Steps | 27: 1.9 a second | 28: 2.8 a second (a small fish steps quicker) |
| The camera's lean, each step | 1.6 to 1.7 degrees, turn about | 0.5 to 0.6 degrees |
| The rider against their root part | rolls 8 to 12 degrees to each side (a puffer rocks more than most), drops about 0.8 studs | rolls 7 to 9 degrees, about a stud side to side |
| Hops | three hops and landings: the steps stop in the air and start again on each new fish within a second | not hopped |
| Errors | none | none |

The first run was sampled at about 15 frames a second (Studio's window was behind others), so its shapes are coarse;
the step counts and the sides are exact.

### Not known, not done
- **Not felt by anyone yet.** `Stride.Amount` is the first dial to turn.
- **Ride a Dino was measured on one dino at one speed.** Whether its smaller dinos step quicker, as ours do, is not
  known.
- **The thump** may not be wanted: `Stride.Sound` 0 turns it off. The reference's sound was not studied.
- **A ridden fish's swim now goes at most 3.2 beats a second.** Fast fish in later lands swam quicker than that.
- Stand-in fish (no model) have no steps.
- Where it is in the code: `strideHeight`, `strideAcross` and the stride in `AnimController` (the fish and the
  rider's `astride`); the stride in `WildController.step` (the camera, the jolt, the thump); `State.Stride` and
  `State.CamStep`.
