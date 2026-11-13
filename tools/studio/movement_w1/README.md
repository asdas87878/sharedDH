# Movement regression driver

Temporary scripted tests for hop speed/airtime, repeated grab presses, wall angles, head-on swing, bounds and camera transitions. These scripts exercise the real game controllers and server mounts. They do not replace any game module. Coordinate Studio ownership before using them. Use the HTTP runner; never Studio MCP.

From the repository root:

```sh
python3 tools/studio/movement_w1/install.py
node /home/hugo/Projects/studio-runner/studio-run.mjs /tmp/ride-fish-movement/install.luau
node /home/hugo/Projects/studio-runner/studio-run.mjs play
```

Wait for a new connected server in runner `status` and `driver up` in `game.ServerStorage.W1Log.Value`. Then send a command through the runner's `--ctx server --code`, for example:

```luau
game.ReplicatedStorage.W1Cmd.Value = "finalsuite " .. tostring(os.clock())
return "started"
```

Read `game.ServerStorage.W1Log.Value` through the server context. Wait for `FINAL SUITE DONE`; an `ERROR` line is a failed test. The suite takes several minutes. Commands can also run separately:

- `mounts 32 0 1`: reproduce the original repeated-press bug with guards disabled; restores defaults afterward.
- `mounts 36 1 1`: fixed repeated-press run; distinguish server-denied retries before mounting from unintended hops after a confirmed mount.
- `chain`: early cooldown press followed by a deliberate hop after cooldown.
- `hop`: slow, normal, fast and angry departure-speed sweep; disables auto-grab temporarily to measure full windows.
- `fair`: six slow/angry hands-off hops to another fish.
- `wall 1`: both sides and 15/30/45/60/75/90-degree approaches, steering away, hop-off, camera and bounds checks.
- `hopwall`: glide into shallow and head-on boundaries.
- `cameradiag`: three focused wall/hop camera scenarios, with commanded look rates recorded alongside actual camera motion.
- `regress`: direct steering, startle dip and angry mode.
- `wallone <angle> <lead seconds> <hop 0|1> [fish]`: one wall approach after riding straight for the lead time (to
  test walls further down); `walldeep [fish]` runs seven of them; `walltrace <angle> <lead> <from>` adds a line every
  0.12 s (where we are, what we asked for, what `Course` gave, what the rays meet).
- `set <Group> <Key> <value>`: a Config number on both machines, for comparisons.
- Since 2026-11-13 (the glide before the wall; `wall` and `walldeep` were written for the old contact rule and
  report false failures now): `glide [fish] [lead s]` (15 to 90 degrees into the side, steering off, hugging: the
  least water kept from the wall, the most the way turned and the speed changed in a frame, whether `Course`'s
  hard rule fired), `glideone <angle> [fish] [lead] [extras 0|1] [trace 0|1]`, `wander [fish] [seconds]` (both
  walls down the lane, stalls logged where they happen), `mouth [fish]` (back up into the hub's mouth),
  `hopglide [fish]`, `camtop [label]` (the camera against the water's lit sheet), `camwall [fish]`,
  `pose <float|hop|ride> <pitch> <seconds>` (holds a view for a picture).
- Since 2026-11-13 (the wait between fish, the air's shape, the hook's reach): `spacing [fish] [seconds]` (how far
  the free fish are from a rider), `air [times]` (whole hops with no grab off a slow, a normal and a fast fish:
  speed, height, reach and the fish inside it every 0.1 s, and the biggest change between two frames),
  `relock [count]` (touch, landing animation, mount, next hop), `rate [seconds] [label]` (fish to fish as fast as
  presses allow), `serverreach [count]` (grabs asked straight of the server, past and inside the reach), and
  `mounts <count> <fix> <mash> <every>` takes the seconds between the mash's presses. The driver calls
  `Actions.jump` itself: it does not test `InputController`'s reading of a held key.

A failed check is logged as `CHECK FAIL` and the run goes on. The wall check compares the speed kept with the
design's share at the angle the wall is REALLY met at (the walls wave: the angle to the lane is not it), and checks
that we are never behind a wall or the barrier, that the camera is never inside a solid box, and the camera's
acceleration. Each phase ends with a `CAMERA` line (peak turn, the peak with no look command in the last 0.3 s, peak
change of speed in a frame; the sandbox's resets pollute the last two) and a `WALLS MET` line (which boxes the wall
ride met, a face or an end). Each mount logs the camera's biggest change of speed in one frame.

After collecting the log:

```sh
node /home/hugo/Projects/studio-runner/studio-run.mjs stop
```

Wait until the server stops polling (stop returns before Studio completes the transition), then run:

```sh
node /home/hugo/Projects/studio-runner/studio-run.mjs /tmp/ride-fish-movement/remove.luau
```

Never save the temporary test scripts into the place. The test scripts accept commands only from the local server-side StringValue; they are not a production remote-code interface. How movement feels by hand remains a human judgement.
