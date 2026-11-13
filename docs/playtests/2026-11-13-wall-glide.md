# The glide before the wall, and the camera under the water's lit sheet: scripted playtest on grey-box 15

2026-11-13, a Claude worker on Hugo's PC, on Hugo's hand-play of the same day
([riding feel](../design/riding-feel.md), "The glide starts before the wall" and "Under the water's lit sheet").
Studio was driven only through `~/Projects/studio-runner/studio-run.mjs` (never Roblox's Studio MCP), nothing was
uploaded, the test scripts are out of the place. No keyboard or mouse: **nobody has played this by hand yet.**
"Before" is the code of commit `52d62fa`, run the same day with the same driver.

## How
The driver in `tools/studio/movement_w1/` (commands `glide`, `wander`, `mouth`, `hopglide`, `camtop`, `camwall`).
It rides through the sandbox, steers by turning the view as a player does and reads every frame: how far the fish
is from the nearest wall face (24 rays all round; floors and steps a fish climbs are not walls), how far the way it
goes turned since the frame before, how much its speed changed, what the camera did, and whether `Lib/Course`'s
hard wall rule had to change the velocity it was asked for. A Barracuda (64 studs a second, 3.4 wide, 20 long) is
the normal speed, a Hellmaw (130, 17.8 wide, 31 long) the high one. The walls wave, so the angle that counts is
the one to the wall itself.

## Why it felt awkward (measured on the old code)
| Steered at | The wall first turned us | The way we went turned, in one frame | Speed changed, in one frame |
|---:|---|---:|---:|
| 15 | at the wall, 0.00 s before | 22 degrees | prop only |
| 30 | at the wall | 26 | prop only |
| 45 | at the wall | 38 | 9 |
| 60 | at the wall | 49 | 7 |
| 75 | at the wall | 64 | 9 |
| 90 | at the wall | 4 | 45 studs a second |

The wall was looked for on one ray, 0.12 s of travel ahead, and the whole turn was made in the frame it was met.
Three more causes showed once the look-ahead was in, each found from a logged frame and removed at its cause:
the ends of wall pieces that stick out where a wall waves; a terrace that tops out exactly at the height a fish
still climbs (a wall one frame, nothing the next: the way thrown 20 to 30 degrees, 2,850 studs down); the lane's
surveyed edge, up to 40 studs inside the real walls and jumping at bends; and two walls at a corner handled in
an order that changed every frame (the corner of the hub's front and the mouth's side).

## The approach, final code
"Seen" is how far off the wall was when it first turned us, and how long before we rode it at the gap. "Clear" is
open water between the body's side and the nearest wall face, the least in the run. Kept is the speed 0.4 to 1.4 s
after, against the design at the angle really met.

**Barracuda, 64 studs a second**

| Steered at | Real angle | Seen | Kept (design) | Least clear, side | Least clear, nose | Way turned, most in a frame | Speed change, most in a frame | Hard rule |
|---:|---:|---|---:|---:|---:|---:|---:|---:|
| 15 | 23 | 20 studs, 0.98 s | 93% (92%) | 4.7 | 34 | 2.5 | prop only | 0 of 504 frames |
| 30 | 33 | 25 studs, 1.10 s | 86% (85%) | 5.0 | 29 | 3.7 | prop only | 0 of 358 |
| 45 | 43 | 29 studs, 0.97 s | 77% (77%) | 4.4 | 23 | 4.0 | 0.4 | 0 of 285 |
| 45, the other side | 42 | 30 studs, 0.97 s | 66% (77%), a prop broken in the window | 4.4 | 24 | 5.5 | prop only | 0 of 275 |
| 60 | 55 | 35 studs, 0.92 s | 68% (67%) | 3.9 | 19 | 4.2 | 0.5 | 0 of 258 |
| 75 | 67 | 40 studs, 0.75 s | 56% (55%), the swing coming in | 5.8 | 13 | 4.4 | 0.9 | 0 of 235 |
| 90 | 82 | 42 studs, 0.72 s | 4% (0%), the swing | 15.1 | 6.9 | 5.1 | 2.1 | 0 of 228 |

**Hellmaw, 130 studs a second**

| Steered at | Real angle | Seen | Kept (design) | Least clear, side | Least clear, nose | Way turned, most in a frame | Speed change, most in a frame | Hard rule |
|---:|---:|---|---:|---:|---:|---:|---:|---:|
| 15 | 20 | 38 studs, 3.8 s (a long shallow run in) | 90% (94%) | 3.4 | 49 | 5.7 | prop only | 0 of 415 |
| 30 | 32 | 53 studs, 0.18 s | 90% (86%) | 5.7 | 60 | 7.1 | prop only | 0 of 179 |
| 45 | 45 | 62 studs, 0.47 s | 73% (75%) | 3.8 | 34 | 7.0 | prop only | 0 of 189 |
| 45, the other side | 35 | 62 studs, 0.73 s | 80% (83%) | 4.3 | 33 | 6.6 | 4.0 | 0 of 206 |
| 60 | 65 | 71 studs, 0.48 s | 57% (59%) | 4.4 | 23 | 14.6 (in the blend to the swing, at low speed) | 7.1 | 0 of 177 |
| 75 | 83 | 67 studs, 0.75 s | 2% (0%), the swing | 15.0 | 7.4 | 6.7 | 4.2 | 0 of 203 |
| 90 | 82 | 73 studs, 0.95 s | 3% (0%), the swing | 14.6 | 8.8 | 5.8 | 5.4 | 0 of 205 |

- **No contact in any run, at any angle, at either speed.** The fish never came nearer than 3.4 studs of clear
  water at its side or 6.9 at its nose, and `Course`'s hard wall rule did not change the velocity in a single
  frame of the 22 runs.
- **The turn is spread out.** The way the fish goes turns 2.5 to 7 degrees a frame at most (the fish's own
  steering toward the wall is in that number: about 2 degrees a frame for the Barracuda). Before: 22 to 64.
- **"Prop only":** the one change of speed in a frame is a prop being broken (speed x0.8 at once, as designed:
  12.8 for the Barracuda, 26 for the Hellmaw). The wall itself changes the speed by 0.4 to 7 studs a second in a
  frame.
- **Square on** the fish slows into the wall over 0.7 to 0.95 s and goes into the swing; the most its speed
  changed in one frame is 2 to 5 studs a second (45 before).

## Steering off, and holding into it
- **Steering off** (the view turned 35 degrees away): free of the wall 0.05 to 0.25 s later and at 90% of the
  fish's speed 0.05 to 0.26 s later, four runs. The way turned 2.7 to 5 degrees a frame.
- **Hugging** (held 12 degrees into the wall for 4 s after coming back to it): the Barracuda stayed 4.0 to 5.5
  studs clear at 99 to 100% of its speed, the way turning 2.7 to 5.1 degrees a frame at most and its speed
  changing 0.2 to 1.6 in a frame; the Hellmaw 3.0 to 4.4 clear at 95 to 97%. The wall state came and went 1 to 6
  times in the 4 s: the wall waves away from a fish held at a fixed angle to the lane, and it follows it round.
  No flicker between frames.

## Corners, joints, the hub's mouth, terraces
- **Wandering** (the view swung up to 94 degrees either side of the lane, both walls, for 75 s):

  | Fish | Lane covered | Frames at a wall | Stalls | Least clear, side | Hard rule |
  |---|---|---:|---:|---:|---:|
  | Barracuda | 315 to 3,372 studs down | 519 | 0 | 5.1 | 0 of 4,414 frames |
  | Hellmaw | 479 to 5,675 | 2,248 | 0 | 4.3 | 0 of 4,443 |

  A stall is a quarter of a second under a fifth of the fish's speed outside the swing. That stretch has the
  first three lands' necks, their flag lines, the lane's first bends and the terraces at 2,750 studs. The
  Barracuda's way never turned more than 5.6 degrees in a frame. The Hellmaw's did, up to 42 degrees, in six
  logged frames: each is in the swing (square on to a wall as the view swept past it) at 10 to 40% of its speed,
  where a small sideways drift changes direction. Its nose came 1.7 studs inside the wall face's line in one
  frame there (the body is 31 long and pitched up the wall in the swing); the hard rule still did not fire.
- **The hub's mouth** (from the start, steered back up the lane at 120, 150, 165 and 180 degrees, both sides,
  9 s each: the rounded sides, the corner of the hub's front and the gate): no stall in seven runs, 3.9 to 14.6
  studs clear at the side, 1.3 to 8.4 at the nose, the way turning 4 to 8 degrees a frame at most. The hard rule
  fired in 1 frame of 3,786. In the corner the fish ends in the swing, as at a wall met square on. (On the first
  version of the new code this corner was the worst place: nose on the hub's front, 150 hard-rule frames.)
- **The terrace at 2,850 studs** (the Hellmaw holding into the wall past it): the way turned 20 to 31 degrees in
  a frame there until the step rule was blended; 8 to 11 after, with no wall state lost.

## The hop and its glide at a wall
Auto-grab off, a Barracuda, hopping about a second and a half from the wall.

| Steered at | Wall first turned us | Rode it from | Least clear, side | Way turned, most in a frame | Speed change, most in a frame | State |
|---:|---|---|---:|---:|---:|---|
| 25 | 0.02 s into the hop | 1.40 s | 2.0 | 2.3 | 7.4 | Slide |
| 45 | 0.02 s | 0.28 s | 1.5 | 3.6 | 5.6 | Slide |
| 90 | 0.02 s | 0.23 s | 5.0 | 2.9 | 3.0 | Swing |

No contact. **To know:** in the shallow two the rider came 3 studs inside the 5-stud gap (1.5 to 2 studs of
water left) where the wall waves in toward them; the push back out is gentle on purpose (`allowed` in
`Lib/WallRide`, 15% of your speed). The fish you left coasts on into the wall the old way for its 1.5 s.

## The camera
**What the layer is.** The partner's water (`tools/map/water_look.luau`, `ClaudeBlockout.Surface.WaterLayers`):
four thin layers from the surface down (`Foam` at 0, `Water1` at 2.6 under, `Water2` at 5.2, `Water3` at 7.8, the
lower three rising and falling a third of a stud), and under them nine bright `Under` sheets at 8.45: the surface
seen from below. None is solid and none is seen by rays, so the camera never collided with anything. The camera's
own rule held it 3 studs under the surface: inside that band, a third of a stud from the breathing `Water1`, and
over the lit sheet, looking at the fish through it.

| Case, in the first land | Before | After |
|---|---|---|
| Riding, the view left alone | camera 34 to 42 under, never in the band | the same |
| A hop, the view 40 degrees down | **in the band in 115 of 180 frames**, as high as 4.9 under | **0 of 173**, never higher than 9.9 under |
| Floating at the surface, looking up and down | **in the band in 244 of 465 frames, pinned at 3.0 under** | in the band in 13 of 465 (one pass through, 0.2 s), then above the water |
| The camera's climb changing in one frame, in the hop | 14.7 studs a second, at the old line | 13.0 (33.5 with the new line met hard, before the knee) |

- The camera's ceiling is 1.5 under the sheet's underside: 9.95 under the surface.
- **Floating at the surface** the camera is kept above the water instead. Held under the sheet there, the
  character is only a dark shape behind it (first picture); above, they are seen through the water (second).
- **Beside a wall** (riding along it, the view swung 80 degrees away from it in 0.6 s, both sides): the camera's
  speed changed 3.4 studs a second in a frame at most and it was never inside a wall.
- **A camera jump found and removed:** riding along the left wall past a coral, the camera came in 8.8 studs in
  one frame (its speed changed by about 500 studs a second), every run. It was the camera's "never inside
  anything solid" rule meeting the coral the fish was breaking. The rule now leaves the map's breakable props
  out, as the fish's own rays do: 24 studs a second in the same run.
- **Left as it was:** a view turned by 65 degrees or more in a single frame beside a wall (the test's own
  steering does this; a hand rarely can) still brings the camera in at once when its arm meets the wall: up to
  220 studs a second in a frame in the wander runs. That rule is unchanged.

## Still as they were
The older checks of the same driver, on the final code. The output had no error and no warning from the game's
scripts in any run (the asset type warning on `rbxassetid://203785492` was there before).
- **A and D:** D held for a second turned 129 degrees (129 before).
- **The landing's slow-down:** least speed 0.15 to 0.45 s after a landing x0.80 (`Ride.StartleSlow` 0.80), full
  speed again 1.6 s after, three of three.
- **Angry mode:** a Giant Isopod 72 calm, 53 angry (x0.74), the `Angry` attribute set.
- **The hop's boost:** Boxfish 40: peak 82, glide 34, boost gone by 0.7 s, window 2.88 s and 114 studs;
  Anglerfish 74: peak 136, glide 63, 3.20 s and 224 studs; Ember Serpent 138 (ridden at 132): peak 229, glide
  117, 3.72 s and 445 studs; angry Anglerfish (56): peak 108, 3.03 s; angry Boxfish (32): peak 69, 2.82 s. The
  same as the pass before.
- **The slowest hop still reaches a fish:** six hands-off hops off slow fish (32 to 41 studs a second), six
  landings, 2.58 to 2.63 s after the press.
- **The second hook:** Space every 0.1 s through 36 mounts: 35 one pull-in and one landing, no hop off the fish
  landed on. In one the server refused the first grab ("Blocked") and the next press took another fish, which was
  landed on: the same right behaviour as in the last pass.
- **A chain made on purpose:** a press 0.20 s after a landing refused, the hop 0.302 to 0.303 s after it, eight
  of eight (`Jump.Cooldown` 0.30).
- **The archetypes** ran throughout (props were broken in most wall runs, x0.8 each); not measured one by one.

## Not done, and to know
- **Not played by hand.** Whether the glide feels right is Hugo's to judge. `Wall.Look` (how early) and `Wall.Gap`
  (how far off the wall) are the two numbers to try first; all of it is in the N panel.
- The fish rides nearer the wall than before (4 to 5 studs of water beside it; the old code stood 6 to 18 off
  because its one ray was as long as the body).
- The lane's surveyed edge no longer holds a ridden fish anywhere on this map (the walls do). In the runs the
  fish was up to 27 studs past that line, always in front of the walls.
- `Wall.Band` and the server's `EdgeBand` are unchanged in the server; nothing on the server was touched.

## Pictures
- `/home/hugo/Pictures/ride-a-fish/wall-glide-2026-11-13/float-camera-under-sheet.png`: floating at the surface
  with the camera held under the lit sheet (tried, not kept): the character is the dark shape in the middle.
- `/home/hugo/Pictures/ride-a-fish/wall-glide-2026-11-13/float-camera-above-water.png`: the same moment as built:
  the camera above the water.

The raw logs are on Hugo's PC in `~/Projects/sharedDH-local/w3-logs/` (not in the repo).
