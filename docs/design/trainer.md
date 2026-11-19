# The trainer: ride the seahorse

Hugo, 2026-11-19 (task h1): "remove the current spring platform; a high-quality, stylised grey spring from the centre of
the bottom of the seahorse's body down to a small circular red platform; the player actually rides it: hop on, rock
with it, hop off; walk up to it or jump on it and you hop on; while riding, a +number with the oxygen icon pops up near
the player about every 0.5 s."

![hop on, rock with the pops, hop off](../attachments/seahorse-trainer-1.gif)
![the coil and the pad](../attachments/seahorse-trainer-still.png)

## What it is now
- **The toy:** the game's own Seahorse (the kit's `Toy`, as before) on a short grey coil, 4.2 studs from the pad to its
  body's underside, from the middle of that underside. The coil is 3.5 turns of chunky square wire, half a stud thick (42 straight pieces,
  each a little longer than its gap so the outer corners meet), fixed between two darker round plates. The pad is a
  small round red slab, just wider than the coil (radius 2.05 against the coil's 1.5 outside; 4.5 turns read as a stack of plates in the first still, so 3.5), with a lighter top face.
- **The kit's old machine is gone in the game:** at the server's start `TrainService` takes away the square red pad's
  look (the part stays, unseen: the sign hangs from it), the yellow block, the post, the three coil discs and the plate
  under the seahorse, and sets the seahorse down to the coil's length. **Not yet in the kit:** `tools/map/hub_kit.py`
  still builds the old machine, so in Edit (and after a hub rebuild) it is there until Play. Changing the kit means a
  hub rebuild in the place: left for Hugo's word.
- **Getting on:** walk up to it (within 5.5 studs of the coil, flat) and you are seated; or jump on it (come down within
  3.6 studs of the coil, above the body's underside). After hopping off you must step away before a walk-up seats you
  again (and off its top before coming down on it does), so you don't hop straight back on. Your own plot's toy only; with no plot, the nearest free one.
- **Hop on:** the server welds you to the toy's body at the seat; every machine carries you there from where you stood
  in a 0.42 s hop (an arc 3.2 studs over the straight line, eased into the seat), and the spring gives and bounces back
  as you land.
- **Riding:** the toy rocks nose down and up about the pad (11 degrees each way, 0.95 swings a second, a small dip at
  each end of a swing), the coil bending along a curve between the pad and the body, and you with it: you are welded to
  its body, so your rock is the toy's exactly. The rock grows as you sit and dies away when you leave.
- **Getting off:** jump, or steer (walk) any way, as before. You hop off along a 0.5 s arc, 8 studs the way you steer
  (or off the toy's side), and the spring springs up behind you.
- **Training:** only a seated rider trains (Config.Train's rate and share, unchanged); the server counts it and every
  0.5 s tells the rider what they gained. On screen a "+n" with the HUD's own Oxygen picture (Kit.Textures.Oxygen)
  springs up at a random spot round the player (to either side, from their middle to a little over their head), drifts up 70 px and fades out over
  1.15 s. The number is built like the fish tags' rarity words (Kit.word: glow, a darker copy under it, the metal
  gradient, the ink edge, the shine line), in the HUD's aqua. Under 10 it shows one decimal ("+2.2"), above that the
  HUD's short numbers ("+1.2K").

## Where it lives
- `src/shared/RideStyles.luau`: `RideStyles.Trainer` (every number above) and `RideStyles.coil` (the coil's pieces
  between a base frame and a top frame; the server builds with it, every machine bends with it).
- `src/server/Services/TrainService.luau`: the makeover, seating and unseating (the weld `TrainerWeld` on the toy's
  `Body`), training, and the `Remotes.Trainer` remote (client "Off"; server "On", "Off", "Gain"). The ride model
  carries `Rider` (the user id on it) and `SpringBase`, `SpringTop`, `Seat` (CFrames at rest); the player carries
  `TrainerRide` (the plot's name) while seated, and `Training` as before.
- `src/client/Controllers/TrainerController.luau`: the rock and the coil, the hop on (the weld's C0, on every machine),
  our own hop off, the pops. In Studio the workspace's `TrainerClock` (a number) holds its clock.
- `tools/studio/trainer_capture.py`: the GIF and the still from a playtest, frame by frame on that clock.

## Open
- Judged on captures only, not played by hand: the seat's place on the seahorse (`Seat`), the rock's size and pace,
  and the pop's size are first guesses.
- The kit (`hub_kit.py`) still draws the old machine (above).
- The rider sits with Roblox's own sit pose; a riding pose of our own waits for the partner's animations.
