# The herd: how wild fish find their way

Up: [riding feel](riding-feel.md). The reference: [Ride a Dino breakdown](../reference/ride-a-dino.md), "The herd".
Built 2026-11-13 on the user's word: the fish should mind obstacles less, swim much straighter, not all sit on one
line, be spaced out in a balanced way, and vary a little in height, most of all the bigger fish, which need room to
be seen. The code: `src/server/Lib/Stream.luau` (the herd's water) and `src/server/Services/FishService.luau`.
The numbers: `Config.Herd` and `Config.Spawn`.

## What the reference does
Read from the user's recordings, most of all the flight over the first two lands (frames a quarter second apart,
from above).
- **Every dino runs dead straight.** Each leaves a dust trail, and the trails are long straight lines, all parallel
  to the track. Nothing weaves.
- **Nothing is avoided.** Dinos and the rider pass through trees and rocks: the prop turns see-through for a
  moment, or breaks if the dino is big. No dino steers round anything.
- **The herd is a loose scatter, not a line.** Seen from above, the dinos fill about the middle half of a room, at
  uneven distances along it. Five or six stand abreast across a room.
- **At a neck they funnel.** The scatter narrows with the track and opens again in the next room. Each dino seems to
  keep its share of the width.
- **Big dinos are mixed in** with the small ones, and stand out by size alone.
- **Why it feels good:** the herd is something you can read. Every dino holds its line and its speed, so the gap you
  aim a hop at is still there when you land. The camera, the trails and the ground's squares all say "forward".
  Nothing in view moves sideways except you.

## What ours did wrong
Measured on grey-box 15 before the change.
- **The herd followed the lane's middle, and the middle wanders.** The map's centre line is the middle between its
  two walls. The walls swell into rooms and pinch into necks one side at a time, so that middle swings from side to
  side: it turns 32 degrees for every 100 studs, with corners of up to 100 degrees. A fish 80 studs off the middle
  had a line that turned over 200 degrees per 100 studs. Each fish chased a point on that line, so the herd wove.
- **Fish dodged what they saw.** Each fish looked 150 studs ahead for a big thing and moved its place across at 45
  studs a second, which at herd speed is a swerve of about 50 degrees.
- **Dodging put them in single file.** A fish that moved aside stayed there, at the same distance from the thing as
  every other fish that had dodged it. After a few obstacles the herd was a few lines through the gaps.
- **The band was thin:** 200 studs at most, in lanes up to 900 wide, and one layer 8 studs deep.
- **New fish went anywhere** in their slice of the lane: some bunched, some alone.
- **In one place the lane's middle crosses a terrace** (400 studs sideways in 100 of travel). The herd swam through
  the ground there.

## What it does now
- **The stream.** When the server starts it works out the herd's own water from the built map, once:
  - *The spine.* The lane's middle, evened out, then let find its own way through the open water. The open water
    is read off the map by dropping rays on a 20-stud grid: seabed is water, ground that has stepped up is not. The
    spine is pushed away from any edge nearer than the band is wide and evened out again, 14 times.
  - *The band.* The open water either side of the spine that the herd uses: up to 400 studs wide, narrower where
    the lane is, and narrowing well before a neck so fish funnel in slowly. Its two sides are fitted one by one, so
    a fish near the middle swims the spine's straight line and only the fish out at the sides follow a room's shape.
  - *The floor.* The seabed under five lines of the band, with its steps rounded, so fish glide down the slope.
  - It takes about a third of a second and 28,000 looks at the map.
- **A fish keeps three numbers** for as long as it swims: its share of the band's width, its height above the
  floor, and how far along it is. Its path is the stream's line for those numbers. Nothing is decided as it swims.
- **Big things in the lane** bend a fish's line round them, starting a long way before (ten times as far ahead as
  the bend is wide) and ending as far after. Lines either side of a thing are pressed apart, never onto each other,
  so the herd keeps its spread through the gaps. A fish pressed between a thing and the edge just goes through the
  thing's rim.
- **Some bend, some go straight through** (the user, after the first build). Four in ten of the fish go straight
  through every prop, decided when the fish is made; so does every fish 80 studs long or more. A fish going through
  a prop breaks it only if it is at least 40 studs long. A smaller one swims through and leaves it whole, as the
  reference's small dinos do.
- **Passing.** Fish swim at their own speeds, so one catches another up. The two move apart a little, at 5 studs a
  second at most, and drift back after.
- **Where a new fish goes.** Of fourteen places in its slice, the one with the most room round it. Room is counted
  in what each fish wants: 32 studs and 1.2 times its own length. So a whale gets clear water and small fish fill
  in between. (Ten places, 22 studs and its length at first; the user asked for the fish further apart, and some
  out at the sides.)
- **A fish's length is its own:** its kind's size times its size's ([sizes](sizes.md)). The lengths here were
  raised twice with the bigger sizes of 2026-11-13 (40, 24, 16 and 44 at first).
- **Height.** The layer is 8 to 20 studs above the floor. A fish longer than 26 studs swims above it by its size,
  up to 14 studs higher. No belly is nearer the floor than 4.
- **Out of sight.** A fish that swims out of everyone's sight (700 studs) is given a new place with room round it.
  Before, such fish stopped in a row at that distance.
- **Distance is real distance.** Slices and "fish per 1,000 studs" are measured down the stream. The lane's own
  measure runs 28% long, unevenly, so some stretches had more fish than others.

## Measured
On grey-box 15. "Turning" is how much a line changes heading per 100 studs.

| | Before | After |
|---|---|---|
| The middle line | 32 | 3 |
| A line at the band's side | 200 to 230 | 7 |
| The same lines, going round the big things | | 5 to 9 |
| The worst 100 studs of any line | over 1,400 | under 40 |
| Up and down | 1.4 to 24 | 1 |
| Live fish at the lane's start, 5 seconds | 4.0 (worst fish 16) | 1.2 to 1.9 (worst 2 to 4) |
| Live fish round a rider in the second land | not measured | 6 to 7 (worst fish 15) |
| Places a line leaves the water or the floor | the terrace crossing | 0 of 4,825 |
| Nearest neighbour, all fish | not measured | median 85 studs, a tenth under 53 |
| Height of the middle, small / mid / big fish | 8 to 16, all | 8 to 21 / 9 to 26 / 12 to 31 |

- The 6 to 7 round a rider is mostly the lane: past the first land it bends (its centre line turns about 13
  degrees per 100 studs in the bend at z 1,000 to 1,400). Giving way adds 1 of it (measured with giving way
  switched off: 6.2 against 7.2).
- Also checked: a sandbox ride with hops (riding at 46, 16 fish inside the hook's reach), 45 seconds standing at the
  dock (no row of fish at the edge of sight), no errors.
- **Not checked:** anything by eye. The lands past the first, live. Phones. A big fish breaking props as it goes.

## To check a new map
`python tools/studio/herd_stream_test.py <studio_id> Edit` builds the stream on the map in Studio and prints the
table above for it. Run it after loading a new map. The stream needs what the lane already needs: parts named or
inside `Seabed`, props inside a folder named `Props`, and the dive's `Path` and `BigAssets`.

## The numbers
All in `src/shared/Config.luau`. Those marked "start" are read once, when the server starts.

| Number | Now | What it does |
|---|---|---|
| `Herd.Smooth` | 240 (start) | How far the lane's middle is evened out before the spine finds its way |
| `Herd.SpineRoom` | 150 (start) | The spine keeps this far from the edges where the water is wide enough |
| `Herd.EdgeGap` | 12 (start) | The band stays this far inside the open water |
| `Herd.NeckAhead` | 96 (start) | The band starts to narrow this far before a neck |
| `Herd.BandSmooth` | 120 (start) | The band's width changes no quicker than over this |
| `Herd.FloorAhead`, `FloorSmooth` | 96, 72 (start) | How early a fish rises for a step, and how round the step is |
| `Herd.Turn` | 2.5 | How quickly a fish comes round to its heading |
| `Herd.DodgeShare`, `DodgeGap` | 0.85, 4 | How much of a thing's circle a fish goes round, and the water left |
| `Herd.DodgeLength` | 10 | How far ahead the bend starts, in bend widths. Higher is gentler |
| `Herd.SmashLength` | 80 | Wild fish this long always go straight through props |
| `Herd.StraightShare` | 0.4 | The share of shorter fish that go straight through too (new fish only) |
| `Herd.BreakLength` | 40 | A fish going through a prop breaks it only if this long |
| `Herd.GiveSide`, `GiveAlong`, `GiveRate` | 18, 44, 5 | Passing: the gap kept, when it starts, how fast |
| `Spawn.BandMax` | 400 (start) | The band's greatest width (200 before) |
| `Spawn.LaneFill` | 0.95 (start) | The share of the open water each side that is used |
| `Spawn.HeightMin`, `HeightMax` | 8, 20 | The layer (8, 16 before) |
| `Spawn.BigLength`, `BigFull`, `BigRise` | 26, 110, 14 | Which fish swim higher, and by how much |
| `Spawn.Tries`, `Space`, `SpaceByLength` | 14, 32, 1.2 | Placing a new fish |
| `Spawn.PerThousand` | 30 | Fish per 1,000 real studs (24 per 1,000 of the lane's own measure before: about the same count) |
| `Spawn.FullBand`, `ThinLeast` | 300, 0.65 | A stretch whose band is narrower than this gets fewer fish, down to this share ([sizes](sizes.md), "Crowding") |

The sandbox panel has the rows that work live: `Turn`, the `Dodge` and `Give` numbers, `SmashLength`,
`StraightShare`, `BreakLength`, `BigRise`, `Space`, `SpaceByLength`.

## Open
- **For the user to judge by eye:** the mix (four in ten straight through), small fish swimming through a prop
  that stays whole, and whether 400 is the right width.
- **Sizes are in** (the same day): [sizes](sizes.md). **Next, on the user's word:** fish speed.
- `tools/balance/model.py` still works the band out the old way (the lane's width times `LaneFill`).
