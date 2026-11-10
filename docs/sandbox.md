# The movement sandbox

For play-testing how the ride, the jump and the camera feel, against Ride a Dino. It is the normal game with the
penalties off and its numbers open, and it only exists in Studio: a published game never has it. Built 2026-11-10 at the
user's request ([Decisions](Decisions.md)). What the numbers mean is in [riding feel](design/riding-feel.md).

## Using it
Press Play in Studio. The top left of the screen says SANDBOX.

| Key | What it does |
|---|---|
| **R** | Puts you on a fish in deep water down the lane, where a jump has room to rise. If no fish is there yet, you float for two or three seconds and are put on the first one that comes. |
| **N** | Opens and closes the panel of numbers. |
| **V** | The side view: the camera stands off to the side, square on to the way you are headed, so you see the whole arc. Steering still works. |
| Space, A, D, W, S | As in the game. |

While the sandbox is on:
- **No fail:** a jump that sinks leaves you floating, and you can jump again. Floating never sends you back to the dock.
- **Endless air:** Oxygen doesn't drain.
- **The arc trace:** a white dot every 0.04 s of your flight stays in the water until your next jump. With the side view,
  that is the arc drawn out.
- **The last jump's numbers,** top left: landed or sank, seconds in the air, studs up, studs along, and the speed you
  came down at.

## The panel (N)
- **Six switches** at the top: the sandbox itself, no fail, endless air, the side view, the arc trace, and whether the
  flight finds a fish for you. Turn the sandbox off to play the real rules.
- **Every number** of the jump, the herd, the ride and the camera, in groups. Change one with - and +, or click its box
  and type. It takes effect at once, on your next jump at the latest. A changed number turns yellow.
- **Copy changes** lists every number you changed, in the box at the bottom and in Studio's Output. Click in the box,
  Ctrl+A, Ctrl+C, and paste it to Claude.
- **Numbers back to start** undoes all of them.

**Nothing you change outlives the play session.** Stop and Play again and the numbers are the ones in
`src/shared/Config.luau`. So when something feels right, press Copy changes and send them: Claude writes them into
Config, and then they are the game's.

## A way to work through a feel
1. R, then ride and jump a few times to get the feel as it is.
2. V, and jump again: look at the arc and the last jump's numbers.
3. N, change one number, jump again. One number at a time, so you know what did what.
4. When it is better, Copy changes and paste them to Claude with a line on what you were after.

Most of the arc is six numbers: `LaunchTime`, `Launch` and `Apex` (the throw), `FloatTime` and `FloatRise` (the hang),
`DropTime` and `Drop` (the sink). How easy a fish is to reach is `RingRadius`, `GrabRange`, `AutoGrab` and the Assist
ones. How the turn feels is `YawRate` and `TurnFollow`, once under Jump and once under Ride.

## What it doesn't do yet
- No slow motion and no replay of a jump.
- No side-by-side with the reference: compare by eye against your recordings.
- The fish are the real herd in the real lane, so they are never in the same places twice.
- Animations, camera shakes and sounds have no controls here, because they aren't built: that is the movement work itself.

## For Claude
- Server: `src/server/Services/SandboxService.luau` (the switches as Workspace attributes `Sandbox`, `SandboxNoFail`,
  `SandboxEndlessAir`; the panel's changes into the server's Config; the reset). `RideService` reads the switches in
  `sandbox()`. The defaults are `Config.Sandbox`.
- Client: `src/client/Controllers/SandboxController.luau` (the panel, the keys, the trace, the jump's numbers). The list of
  numbers on the panel is `TUNABLES` at its top: add a row there when Config gets a number worth tuning.
- `Config.refresh()` works out the numbers that depend on others (the flight's longest time, each fish's wild speed).
  Call it after changing Config at run time.
