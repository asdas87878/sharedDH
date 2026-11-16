# Camera shakes

Up: [riding feel](riding-feel.md). Built 2026-11-16 on the user's word: "I'd also like to get some professional camera
shakes on this". The code: `src/client/Lib/Shake.luau` (the shaking), `src/client/Controllers/ShakeController.luau`
(the shakes nothing else asks for). The numbers: `Config.Shake`.

## Before
`RideController` kept one shake. A new one replaced whatever was running, and every shake had the same pattern: thrown
left-right and up-down, with a little roll.

## Now
- **Shakes add up.** Any number run at once: a landing on top of the speed tremble on top of a giant going by.
- **A shake moves the camera and turns it.** Three ways each (right, up, forward; nose, side, roll), each on its own
  smooth noise, so it never repeats and never jumps from one frame to the next.
- **Each moment has a character.** How far, how fast it trembles (slow reads as heavy, quick as sharp), how it comes
  on, how long it holds, how it dies away.
- **A knock.** A push one way that swings back and settles: the nose dips on a landing and comes back.
- **Rumbles.** A shake that stays for as long as something lasts, and grows or fades with it.
- **A limit.** All together they never move the view more than 2.2 studs or turn it more than 5 degrees.
- **Phones.** Every shake is 0.7 of itself on a touch screen (`Shake.Touch`): the same shake looks harder on a small
  screen held close.
- **By the clock, not the frame:** the same at 30 frames a second and at 144.

## The shakes
| Shake | When | What it is like |
|---|---|---|
| Land | You land on a fish | Sharp, over in a third of a second. The nose dips and comes back. Harder after a faster pull-in |
| LandBig | The fish is 60 studs long or more | Bigger, slower, twice as long: weight |
| Hop | You hop off | Small and quick, the nose flicks up. Bigger off a Leaper |
| Crash | Your fish runs into something | Hard, thrown back and rolled to one side. Harder the more speed it took |
| Thrown | A fish throws you off | Slow and wide, the view turning over |
| Pass | A hunter or a giant goes by within 75 studs | A swell that comes on and goes, low and slow. Once a fish every 5 seconds |
| Tame | The fish under you becomes yours | One soft lift |
| Strain (rumble) | You are on a fish too strong for you | Starts at a third and grows to full as the meter empties |
| Speed (rumble) | You ride faster than 78 studs a second | A fine tremble, full at 135 |

A prop breaking and the archetypes' moments (a bite, a smash) still call `RideController.shake(size, time)`. That call
now adds a plain shake to the rest, where it used to replace them.

## Checked
In the user's Studio, by script: the camera's roll read every frame through a hop and a landing.
- The hop: 0.15 degrees of roll for a quarter of a second.
- The landing: 1.36 degrees at once, 0.23 a quarter second later, then still.
- No errors.
- **Not judged by eye by the user yet.** The numbers are Claude's first go. **Not tried on a phone.**

## To tune
- `Config.Shake.Amount`: every shake, times. 0 turns them all off. On the sandbox panel with `Touch`, `MostMove`,
  `MostTurn`, `GrandLength`, `StrainFrom`, `SpeedFrom`, `SpeedFull`, `PassRange`, `PassSpeed`.
- `Config.Shake.Presets.<Name>`: one shake's own numbers. In the file, not on the panel.

| Number | What |
|---|---|
| `Move` | Right, up, forward: studs at full strength |
| `Turn` | Nose, side, roll: degrees at full strength |
| `Rate` | Trembles a second |
| `In`, `Hold`, `Out` | Seconds coming on, held, dying away |
| `Shape` | How it dies: 1 evenly, 2 quick at first with a long tail |
| `Knock` | The one-way push: nose (degrees, + is up), roll (degrees), back (studs) |
| `KnockRate`, `KnockDamp` | Its swings a second, and how fast it settles |

- `Jump.LandShake` (Hugo's) still sets how hard a landing shakes: it is measured against the 0.9 it was. 0 is none.
  `LandShakeTime`, `LandShakeRate` and `LandShakeRoll` now only shape the plain shake that props and bites use.

## For the other chats
- **A new shake from your code:** `Shake.play("Name", strength, side)` for one of the presets, or
  `Shake.at("Name", place, radius)` for something that happened at a place. `RideController.shake` still works.
- **Not built:** a setting for the player to turn shakes down; a shake for another player's crash near you.
