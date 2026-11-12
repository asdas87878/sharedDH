# The movement sandbox

For play-testing how the ride, the hop and the camera feel, against Ride a Dino. It is the normal game with the
penalties off and its numbers open, and it only exists in Studio: a published game never has it. Built 2026-11-10 at the
user's request ([Decisions](Decisions.md)). What the numbers mean is in [riding feel](design/riding-feel.md).

## Using it
Press Play in Studio. The top left of the screen says SANDBOX.

| Key | What it does |
|---|---|
| **R** | Puts you on a fish in deep water down the lane, where a hop has room to rise. If no fish is there yet, you float for two or three seconds and are put on the first one that comes. |
| **N** | Opens and closes the panel of numbers. |
| **V** | The side view: the camera stands off to the side, square on to the way you are headed, so you see the whole arc. Steering still works. |
| Space | On a fish or floating: the hop. In the hop: grab the fish that glows (a left click, E and gamepad X too). |
| A, D | Steer, on a fish, in the hop and floating. W and S do nothing. |
| The mouse | In the hop it aims with no button held; on a fish a right drag looks round. It never steers. |

While the sandbox is on:
- **No fail:** a hop whose window runs out leaves you floating, and you can hop again. Floating never sends you back
  to the dock. **Turn it off to judge the real 3 seconds.**
- **Endless air:** Oxygen doesn't drain, and a crash costs none. **Turn it off to judge the drain by land.** To try a
  deeper land with more Oxygen, set the `TestMaxOxygen` attribute on Workspace (0 turns it off).
- **The arc trace:** a white dot every 0.04 s of your flight stays in the water until your next jump. With the side view,
  that is the arc drawn out.
- **The last jump's numbers,** top left: landed or sank, seconds in the air, studs up, studs along, and the speed you
  came down at.

## The panel (N)
- **Six switches** at the top: the sandbox itself, no fail, endless air, the side view, the arc trace, and whether a
  locked fish is grabbed for you when the window ends. Turn the sandbox off to play the real rules.
- **Every number** in groups: `Jump` (the hop, the window, the pull-in, the landing), `Lock`, `ZoneDrain` (Oxygen a
  second, one row a land), `Oxygen`, `Crash`, `Props`, `Herd`, `Ride`, `Camera`, `AimHud`, `Net`, `Switch`, `Burst`,
  `Spawn`. What each one does is its comment in `src/shared/Config.luau`. Change one with - and +, or click its box
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

What to reach for:
- **The arc:** `Jump.LaunchTime`, `Launch` and `Apex` (the pop), `FloatTime` and `AirSpeed` (the glide), `Drop`,
  `DropCurve` and `DropSpeed` (the drop). `Window` is the whole hop: the drop is what the pop and the glide leave of
  it (3.0 - 0.4 - 1.4 = 1.2 s), so a longer glide means a shorter drop unless `Window` grows too.
- **The landing's slow-down** (a fish you land on slows for a moment, never stopping): `Ride.Startle` (0 off),
  `StartleBrake`, `StartleSlow` (the share of its speed it drops to), `StartleHold`, `StartleRecover`. The rearing
  that came with it is gone (2026-11-12), and its rows with it.
- **The camera under the surface:** `Camera.Submerge` (0 off), `WaterTop`, `SurfaceMargin`, `SurfaceTilt`.
- **The rider's animation:** the `Pose` group (`CrawlRate`, `BreastRate`, `FloatTilt`, `PopTuck`, `Flip`, `FlipStart`,
  `RideCrouch`, `RideLean`, `BraceLean`). **The juice:** the `Feel` group (`PopFov`, `PopLines`, `ReelLines`,
  `BoltLines`, `Trail`, `Whoosh`, `Splash`, `Mark`).
- **How easy a fish is to get:** `Jump.GrabRange`, and `Lock.Cone`, `AimRadius`, `DistanceWeight`, `FarAim`, `Sticky`, `SwitchTime`, `EdgeAim`,
  `LeftPenalty`. Where the view rests in the hop: `Jump.CameraPitch`, `CameraZoom`.
- **How the turn feels:** `Ride.YawRate` and `TurnEase` (one rate, everywhere).
- **The progression:** `ZoneDrain` land 1 to 10, `Oxygen.Refill`, `KeepUp`, `RarityDrain` Common to Secret (how many times a Common's Oxygen each rarity takes), and `Oxygen.StartMax` (live:
  everyone's max Oxygen changes at once; the `TestMaxOxygen` attribute, when above 0, still wins).
- **The tuning rows** ([progression](design/progression.md); [riding feel](design/riding-feel.md), "Speed by fish"):
  `Speed.Base` (a Common's ridden speed in land 1), `TierMult` Common to Secret (each rarity's speed, times),
  `Speed.AreaStep` and `Speed.AreaGrow` (faster by a fish's home land: the first land's step, and how much bigger each
  step after is; 0.06 and 0.01 make land 10 x1.90; both 0 turn it off), `Speed.Gold`, `Speed.Rainbow` (wild fish, the
  glide and the server's speed check follow at once); `Variant.Gold`, `Rainbow` (the variants' chances, for fish
  spawned from then on; the `Size` rows and `Speed.SizeBonus` went with the size roll, 2026-11-12); and
  `MixShallows` to `MixUnderworld`, the share of spawns by rarity in each land. (`TierSpeed` went 2026-11-12.)
- **Running into things:** `Crash.Slow`, `Recover`, `Cost`, `HeadOn`; `Props.Rebuild`, `Push`, `Topple`, `MinLength`.

## What it doesn't do yet
- No slow motion and no replay of a jump.
- No side-by-side with the reference: compare by eye against your recordings.
- The fish are the real herd in the real lane, so they are never in the same places twice.
- The poses' shapes are in code (`AnimController`); their rates and angles are the `Pose` group. The sounds are
  placeholders from Roblox's own character sounds.
- The last jump's line says "sank" for a window that ran out.

## For Claude
- Server: `src/server/Services/SandboxService.luau` (the switches as Workspace attributes `Sandbox`, `SandboxNoFail`,
  `SandboxEndlessAir`; the panel's changes into the server's Config; the reset). `RideService` reads the switches in
  `sandbox()`. The defaults are `Config.Sandbox`.
- Client: `src/client/Controllers/SandboxController.luau` (the panel, the keys, the trace, the jump's numbers). The list of
  numbers on the panel is `TUNABLES` at its top: add a row there when Config gets a number worth tuning. A row's key
  can be a number, for a list (`{ "ZoneDrain", 3, 2 }` is `Config.ZoneDrain[3]`).
- `Config.refresh()` works out the numbers that depend on others (the drop's time, the hop's longest time, each fish's
  wild speed and Required).
  Call it after changing Config at run time.
