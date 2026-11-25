# The submarine (the carry to a land)

Up: [the dive-in](dive-in.md), [riding feel](riding-feel.md), [the hook](hook.md), [money](money.md),
[progression](progression.md), [the aquarium](aquarium.md). The reference's version:
[Ride a Dino](../reference/ride-a-dino.md) ("Jurassic Airlines") and
[the deep study](../reference/ride-a-dino-deep.md) ("Zones, gates and travel").

Written 2026-11-17 by worker m1 on Hugo's order:

> "Ride a Dino has a feature where you start up and instantly get carried by a pterodactyl, my friend wants to
> implement this same feature as a submarine, try to impliment with animations and camera movements, you should jump
> in the water start swimming while the submarine swims in and picks you up, then swims really fast to your
> destination, each area should have its own upgrade tier increasing the distance to the area, make sure that when
> youre let go you either get flung forward instantly going arial(with no selected fish), or your fish swims beside the
> submarine then you get kicked out onto the fish being able to play normally after that, there should be custom
> animations for getting picked up and getting dropped off but add this and make sure its satisfying, dont implement
> custom models yet only use placeholders."

**Built 2026-11-17, placeholders only:** the submarine is a few plain parts, and the pick-up and drop-off are moved
by code. There are no uploaded animations. **Run by script in Studio to lands 2, 3, 5, 7 and 10, both drop-offs;
not played by hand** ([the playtests](../playtests/2026-11-17-submarine.md), clips:
[fling](../attachments/submarine-fling.gif), [fish](../attachments/submarine-fish-dropoff.gif)). Where this note says
**reading, not confirmed**, it is a guess at what Hugo meant, waiting for his word.

## What the reference does
- **"Buy once. Fly forever."** A stall by the start sells one flyer per zone, each bought once (Desert $25M, Snow
  $1B, Giant Forest $50B, Abyss Ocean $500B, Volcano $5T, Extinction $50T, or Robux). You "Equip" one flight; that
  is where you go.
- **F at the hub starts it.** A banner, "JURASSIC AIRLINES: Snow". You fly the pterosaur yourself over every zone on
  the way, about ten seconds, between two white lines. Then "NOW ARRIVING" and "Drop onto a dino!": you pick the dino
  you land on. Commenters say your own dino and the flight go together: you land already mounted.
- **Why it matters** ([findings](../Findings.md) and the deep study): players stick in zones 5 to 7, and a creator
  paid Robux for the zone-6 flight the minute he saw it. Late on, the early zones are dead time; the flight is what
  skips them.

## How ours goes, beat by beat
1. **At the sub stand** (2026-11-18, Hugo: "remove the sub button, make the player able to buy the subs there and
   equip them"): walk onto the SUBMARINE stall's circle on the floor and the shop opens; walk off and it closes
   (2026-11-24, the same way as Sell and Auras: `StallController`, no E prompt any more; the X shuts it until you
   step off and on again). A small copy of your equipped sub (the Bathtub when you have none) floats and turns over
   the stall, on your own screen only (`SubStandController`; checked in Studio by
   `python tools/studio/h4_hub_check.py run rings sub`). The shop lists nine subs, one a tier
   (Bathtub, Reef Runner, Kelp Cruiser, Wreck Diver, Blue Streak, Twilight Ray, Midnight Hunter, Vent Crawler, Abyss
   King), each with its picture, the land it reaches and its price. You buy them in order (priced since 2026-11-24), and
   **equip** one; the equipped sub is the one that comes for you, and it reaches its own land or any before it.
   "NO SUB" is the ordinary dive-in. Under the list, GO TO picks the land and RIDE WITH a fish from your tank.
   The shop closes as you walk away. (A small ticket at the left edge said where the sub would take you until
   2026-11-24; Hugo took it out. GO TO in the panel says it now.)
2. **You jump in.** With a destination picked, stepping off the dock is no longer the dive-in's auto-hop: you drop
   in with a splash and **swim** at the surface, breaststroking forward.
3. **The sub swims in** from behind and below (1.2 s; 1.6 until 2026-11-24), its light on you, a wake of bubbles. The camera is behind
   you on your own line, close at first and drawing back as you swim on, and tips down so the sub shows as it comes
   in under you (see "The camera is always behind").
4. **The pick-up** (0.75 s; 0.96 until 2026-11-24): it rises under you, the camera stays behind you and draws back, you are scooped up in
   a tumble (a tuck and a half-turn) and set on the seat behind the tower. A bump, a shake, the view kicks.
5. **The run:** it noses down and goes. The view, already behind, pulls further back behind the sub and widens with
   speed, streaks of bubbles, speed lines. No banner as it sets off (Hugo, 2026-11-20: "let the intro text for submarines begone"). It follows the herd's own line down the lane (the stream: the
   middle of the open water, bent round the big things), well above the fish. 3.2 to 7 seconds whatever the land,
   its top speed growing with the distance (task f2, below: about 500 studs a second to land 2, 2,100 to land 5,
   4,250 to land 10), picking up over a fifth of the run and slowing over a quarter of it.
6. **Arriving:** "NOW ARRIVING" over "KELP FOREST", in the land titles' own look (see "Titles on the run"). It
   slows to the speed of a quick fish (90). The camera stays behind the sub through the drop-off, a little further
   back (36 studs, not 30) when your fish swims up beside it, so the fish is in the picture without the camera going
   to its side.
7. **The drop-off**, one of two:
   - **(a) No fish picked:** the sub pitches its nose up and **flings you forward**. You leave at its speed into an
     ordinary hop (the pop, the glide, the drop, the lock and the hook), so you hook the nearest fish as in any hop.
     It is the dive's first hop, so a miss leaves you floating rather than drowning (as the dive-in's). Six fish of
     the land's herd are put in the water just ahead of the drop point 2.5 s before you arrive (`Sub.Stock`): without
     them the first fling to land 5 found nothing in reach.
   - **(b) A fish held or picked:** your fish **swims up beside the sub** (from behind, on the right, 1.1 s, matching
     its speed), then the sub **kicks you off sideways** in an arc onto its saddle (0.5 s). The fish you hold over
     your head as you go in comes first (task f2, below); else the tank fish picked under RIDE WITH. You land as on any fish: the
     shake, the splash, the refill. From there you play normally.
8. **The sub peels away** up and to the side, and is gone.

The player can't steer or hop while carried, and no Oxygen goes. The whole trip is decided by the server.

### The camera is always behind (Hugo, 2026-11-23)
**In the game since 2026-11-24** (`862ff88`, `5f18f3f`; measured in Studio, passed by the mission's reviewer; Hugo has
not played it yet).

Hugo, after seeing a side view of the sub in a dev session: "what is this new camera perspective for the submarine? i
saw it playing in dev sesh, make sure it doesnt implement the camera on the side ever". Read as a rule for every
phase of the trip (the boss's reading, mission "submarine camera always behind"):
- **Behind, on the middle line, in every phase:** behind you on your own line while you swim and are scooped up,
  behind the sub on its line for the run, the arrival and the drop-off. Nothing in the camera's place or in where it
  looks goes to the side (`SubController.cameraFor`).
- **No swing round:** a camera that starts in front and comes round to behind passes the side on the way, so it
  starts behind too. Before this the approach sat ahead of you and 5 studs to the side looking back, the pick-up
  swung round through up to 9 studs to the side, and the arrival stood 6.4 studs to the fish's side and looked
  8 studs that way.
- **What that costs:** from behind you no longer watch the sub come from far off. It comes in under the camera and
  rises into the bottom of the picture in about the last third of a second of the swim, then is in view for the
  whole scoop.
- **The fish at the drop-off** is 16 studs to the right of the sub. From 36 studs behind it sits about 23 degrees off
  the middle of the picture: well inside a wide screen (53 degrees each way) and a tablet (45), at the very edge of
  a phone held upright (23).
- **The gate's kelp goes see-through for you while the camera is behind it** (2026-11-24, added when the camera was
  measured; Hugo has not seen or picked this). The kelp curtain under the dock's lip (`Dock.Gate.Kelp`) hangs between
  a camera behind you and you from about half way through the pick-up until the sub has left: the first stills were a
  wall of green ([before](../attachments/subcam-kelp-before-fix-pickup.jpg)). The camera's pull-in cannot keep out of
  it, because the kelp is not something a ray can hit (`CanQuery` off). So on your own trip the 25 plates under the
  water are see-through on your own screen from the trip's first frame until one second into the run, then back
  (`SubController.gateKelp`; nobody else's screen changes). The camera looks away from the dock, so the kelp going
  and coming back is not in the picture ([after](../attachments/subcam-behind-fish-2-pickup.jpg)). To undo it alone:
  `git show 5f18f3f -- src/client/Controllers/SubController.luau | git apply -R --index`, then commit (a plain revert of that commit conflicts in this note). Another way would be to keep the camera in front of the curtain (closer to you for the
  whole pick-up); not tried.
- **Measured in Studio 2026-11-24** (`python tools/studio/sub_camera_check.py`, every frame of scripted trips; stills
  `docs/attachments/subcam-behind-*.jpg`), on calm frames, old camera in brackets:
  - Swim and pick-up: 0.00 to 0.02 studs off your line and under 0.1 degrees off straight behind (5.0 to 8.4 studs,
    161 degrees: in front). The shake moves it up to 0.6 studs.
  - Arrival and drop-off: at most 2.3 studs and 4.0 degrees off the sub's line, from the lane's bend (6.4 studs,
    12 degrees). Behind in every frame, 30 studs, 36 with a fish.
  - The hand-over to the hop and to the saddle: under 1 degree of turn and 2.4 studs of move in a frame, as before.
  - The run is the old code and lags the sub's nose in a bend: 8 degrees to land 2, 17 to 21 degrees for 7 or 8
    frames to land 10 (4,267 studs a second; the old camera reads the same there), 15 to 16 for a moment after going
    in at the very end of the dock's lip (the old camera: 16, and up to 24 in the shake).

### Getting on is quicker (Hugo, 2026-11-24)
Hugo: "i liked how there was a little camera movement on the intro of the submarine when jumped into the water, make
it a little shorter and speed it up.(just the animation getting onto it (at most 2-3 secs)".
- **Getting on takes 1.95 s, was 2.56** (`Sub.Approach` 1.2, was 1.6; `Sub.Pickup` 0.75, was 0.96). The swim is as far
  as before (`Sub.SwimOut`, 12.8 studs, was the swim speed x Approach), so it is the same move, played quicker.
- **The camera's move is kept:** its easing in these two phases goes by their lengths (`cameraFor`), so it draws back
  and tips as far as before. The seat's shake goes with the landing, not a fixed 0.15 s before the run.
- **Reading, not confirmed:** the camera movement meant is the one in the game now (behind you, drawing back, tipping
  down to the sub), not the old one that started in front and swung round, which his rule of 2026-11-23 rules out.
  (The game open in Hugo's Studio when he asked held the new one: read from its scripts.)
- Type check and lint pass; **not run in Studio yet** (Hugo was in a playtest).
- Nothing after the sub sets off is changed.

### The air hop (Hugo, 2026-11-25)
Hugo: "make the player jump off the fish mid air then instantly hopping on the submarine that should fly in then splash into
the water, the animation should be fast enough to where the player has fun." And: "make sure it doesnt conflict with the
current dive mission, i want the new version but back up this current version".
**Built on branch `air-hop`, the default (`Sub.AirHop` 1). Checked offline (below); NOT seen in Studio, not played.**
**The hop under water** (the next section) is kept whole: `Sub.AirHop` 0 brings it back exactly, and it is what the tag
`backup-underwater-hop-2026-11-25` (db1f089) holds. It also still runs by itself when a leap gets no air hop (stepping off
the lip with no leap, a lost or refused message, a word so late the moment to jump has gone).

**Who:** a rider on their ride fish, with a sub and a land picked, who leaps off the lip. No sub, or no land picked: the fish
dives as before. On foot: as before.

**The timeline.** Seconds from the start of the leap (the crouch at the lip, all in server time); positions are height over
the water and distance out from the lip, studs. `SubAir` has it all as a function of the seconds.

| Moment (`SubPhase` `Leap`, then `Hop` from the jump to the run, then `Ride`) | What happens | Clownfish, sub 1 | Great White, sub 5 | Colossal Kraken, sub 9 |
|---|---|---|---|---|
| the leap | The fish crouches and leaps off the lip, the dive's own arc and view. The client has told the server the arc (`SubLeap`), the trip is made. In the last `AirCrouch` 0.12 s you crouch on its back | 0 | 0 | 0 |
| jump-off | At `AirAt` 85% of the way to its top. You jump off by yourself, the fish dips `AirPush` under you. **The swap:** the land fish goes, the trip's own copy takes its place in the same pose | 0.45 s, 12 up, 9 out | 0.70 s, 22 up, 22 out | about 0.6 s, 105 up, 18 out |
| the hop | The sub flies in from behind, under the gate's beam (small fish) or down over the arch (big ones), at 500 to 900 studs/s, level with you for the last `AirRushFrom` 0.18 s | 0.45 s long | 0.45 s | 0.6 s |
| on the seat | You land: a squash, the sub dips and nods, a shake | 0.90 s, sub 20 up, 29 out | 1.15 s, 39 up, 42 out | 1.20 s, 121 up, 40 out |
| the fall | Sub and rider tip over nose first (`AirNose` 50 degrees at most) and fall, past the fish's nose | 0.42 s | 0.42 s | 0.82 s |
| splash | The sub's spray and sound (strong, by its speed), a shake, the view kicks `AirFov` 10 degrees wider | 1.32 s, 74 out | 1.57 s, 122 out | 2.02 s, 311 out |
| the plunge | Down `AirUnder` 0.35 s to the run's line, no stop | to 1.67 s, 121 out | to 1.92 s, 194 out | to 2.37 s, 384 out |
| the run | The run, at `AirRun` 150 studs/s and speeding up as ever | 1.67 s | 1.92 s | 2.37 s |
| the fish | Goes on down its own arc, into the water with its own splash, then up beside the sub in `AirSwim` 0.9 s (1.6 times that for the longest) and weaves as before | in at 1.15 s, beside at 2.1 s | in at 1.94 s, beside at 2.9 s | in at 2.38 s, beside at 3.8 s |

**The camera** is behind you on the middle line all the way and never cuts: from the player's own view (`AirCamIn` 0.45 s),
under the sub as it comes by overhead (or over it, when it comes in low), up over its stern in the fall (`AirCamRise`,
`AirCamSubUp`, `AirCamNose`), through the surface after it, into the run's own view. The server picks it with the plan
(`SubAir.frame`): the nearest to what Config asks that stays out of the gate's arch, the sub and the fish and sees you.

**How it works.**
- **One new message**, Action `"SubLeap", leap` (the rider's machine, which has the leap: its start, where, which way, how
  far, its rise and fall and tilts). The server believes it only on the ride fish's land state, off the lip, from within
  `AirReach` of where it has the player, out from the dock, at a land fish's pace, begun within `AirSlack`, once a second.
- The server makes the plan (`SubAir.plan`: the least rise over the saddle that takes the hull's box clear over the fish's
  box and clear of the arch, by `AirSlopes`; then the nearest splash past its nose), the copy of the fish and the trip (with
  the leap's start as the trip's). The player stays on the land fish ("Dock") until the jump by the server's own clock, and
  is "Carried" from there.
- **The swap** is on each machine, in the frame of the jump: the land fish goes out of sight and the trip's copy into it, in the
  same pose and joints. Never both, never neither. Other players see the whole trip later by as much as their view of
  the rider's body is late (0.5 s at most), so nothing is off on their screens.
- The run is `SubTrip`'s own, starting at the splash's end. The sub's line keeps its room from the lane's sides for its own
  width; the fish is not beside it yet there.
- **Given up cleanly:** off the fish, unequipped, dead, gone, or the sub's plan impossible before the jump: no trip, and the
  leap goes on as the plain dive. After the jump: as the old hop (`SubLeave`, the fling, the copy taken away). A late word
  (a slow link): you still get `AirLate` 0.25 s in the air, and a word later than the jump falls back to the hop under
  water. A second trip while one runs is refused, as before; a second leap within a second is not heard.
- **`AirHop` 0** changes nothing of it: the same source as at the tag, checked trip for trip (below).

**Where it is not what was asked, and by how much** (the check's numbers, `tools/subs/air_check.luau`, in the table after):
- Lip to splash was asked as 1.3 to 1.6 s and trip control straight after. Up to a Great White it is; **the fish that leap
  highest (Kraken and the other tall ones) take up to 2.1 s** (they climb to 128 studs, and the sub has that to fall).
- **A rider on a big fish is out of sight behind the sub's belly for part of the hop** (see the numbers): the sub comes
  down over them from above the arch. The view sees them leave the saddle, and see them on the seat again in the fall.
- The sub is in sight only from 200 studs back (`AirFrom`), 1.1 s before it meets you.

**Checked offline (2026-11-25; the last run is this source).** 1,326 leaps (all 78 kinds at all six sizes, and more along the lip and
slanted) with each of the nine subs: 11,934 flights, every frame at 60 a second, told to the real `SubService`; each got its air
hop. 6,247 of them have the sub over the gate's arch, the rest under its beam. The numbers:

| | Least | Middle | 95 of 100 | Most | Asked |
|---|---|---|---|---|---|
| Jump-off to seated, s | 0.45 | 0.45 | 0.53 | 0.60 | about 0.5 |
| Lip to splash, s | 1.20 | 1.47 | 1.67 | 2.06 (Colossal; Normal 1.63) | 1.3 to 1.6 |
| Lip to the run (control), s | 1.55 | 1.82 | 2.02 | 2.41 | 2 to 3 at most |
| Nose down at the surface, degrees | 19 | 34 | 45 | 50 | nose first |
| The sub's room to the lane's sides, studs | 8.7 | 32 | | | clear |
| The rider's move, a frame against the last, studs | 0.29 | 0.73 | 1.01 | 1.25 | no jump |
| The swap: the copy off the dive's pose | 0.0 studs | 0.1 degrees | 0.5 | 1.2 degrees, 0.0 studs | not seen |

- **All of the 11,934 pass:** the sub clear of the gate, the arch and the map; the rider clear of them; the fish clear of the hull until
  its own splash; the sub in the lane; through the surface once; the seat met exactly; the camera on the middle line, behind,
  never in the sub and never cut; the rider in the picture; the fish's turn under 12 degrees a frame.
- **Over the aim:** the hop over 0.5 s in 2,496 (0.6 at most); the splash after 1.6 s in 1,133 (924 Colossal, 34 Normal; before 1.3 s in 851).
- **What fails, and by how much:**

| Check (its limit) | Fails | The worst | Where |
|---|---|---|---|
| The camera's turn in a frame (6 degrees) | 1,489 | 11.3 (middle 3.4) | all but 13 over the arch |
| The rider through the sub's hull as it sweeps by (0.1 s) | 874 | 0.20 s | 525 with sub 9, 784 over the arch |
| The fish's move, a frame against the last (3 studs) | 792 | 4.6 | all sizes, as it comes up beside the sub |
| The sub over the rider in the fall (0.3 s) | 301 | 0.43 s | 173 sub 9, 70 sub 6 |
| The sub over the rider in the hop (0.3 s) | 147 | 0.37 s | 60 sub 9, 55 sub 7 |
| The fish through the hull as it comes up beside (0) | 138 | 0.1 s, the boxes 9 studs into each other | 135 sub 9 |
| The camera's move, a frame against the last (2.5 studs) | 64 | 3.6 | big fish; 1 Normal |
| The camera in the fish (0.1 s) | 2 | 0.13 s | |

- **The limits that are looser than the brief, so they pass:** the splash's is 2.1 s; the hop's 0.6 s; a thing of the map between the camera
  and the rider 0.4 s (0.37 at most). Subs 5 and 7 hide their own seated rider from the run's own camera, in the old hop as well; there
  the fall is not judged.
- **The run after it, with the fish beside (1,716 runs: every kind Normal and Colossal, eleven sub-and-land trips each; the old hop's own checks):**
  camera, jump, hull, frame, turn, home and sub 0 fail. Walls: 12 Normal (rays and turtles; 7.7 studs at most, MantaRay to land 7; ten of
  them under 4) and 154 Colossal (27.7 at most). The surface or the floor: 83 Colossal (a giant, as before). A plain swim: 2 Normal
  (InfernalAngler and Hellmaw, sub 9 to land 2), 9 Colossal. In 213 of them the run is too short for a sweep (`AirWeave`): the fish swims beside.
- **`AirPeel` 0.25 is the middle of three tried:** 0.2 has 2 Normal walls and 255 joins, 0.3 has 14 and 69.
- **The server's rules: 48 of 48** (who may, where from, when, a second trip at once, a late word, a server hitch, off the fish, unequipped, dead or gone at each point; the rider handed over once).
  The client's own code in the frame of the swap is not run offline: Studio must see that no frame has two fish or none. **The dive's check, parts 1, 3, 4, 5, with the
  switch on: all pass** (468 of 468 plans, as before).
- **The switch off is the old hop:** escort_check with `AirHop` 0 against the tag's own check on the tag's own build, 2,652 trips: the text
  and the csvs the same, byte for byte, its 3 known fails included.
- **The server's cost of one leap:** about 107 ms in a quiet Lune (the plan 54, the rooms beside the lane 44, which the old hop
  has too), 200 with the PC busy. Studio's own number is not known.
- **Not known, for Studio:** all of the feel and look; two players; the gate, hub stands and kelp as they are in Studio (the check has the map generator's
  boxes); the sounds; real lag.

To run it (about 15 minutes on 12 threads):

```
L=~/.rokit/tool-storage/lune-org/lune/0.11.1/lune
~/.rokit/tool-storage/rojo-rbx/rojo/7.7.0/rojo build -o /tmp/place.rbxl
python3 tools/subs/escort_hulls.py /tmp/cells.json; python3 tools/dive/lip_boxes.py . /tmp/lip.json
$L run tools/subs/air_leaps.luau /tmp/place.rbxl /tmp/lip.json /tmp/leaps.json
for i in $(seq 1 11); do $L run tools/subs/escort_check.luau . /tmp/place.rbxl /tmp/a_$i.csv $i/11 /tmp/cells.json /tmp/leaps.json /tmp/lip.json > /tmp/a_$i.txt & done; wait
$L run tools/subs/escort_check.luau . /tmp/place.rbxl /tmp/r.csv rules /tmp/cells.json /tmp/leaps.json /tmp/lip.json
```

The old hop's check is the same command without the last two files, on a build with `AirHop` 0.

### From the fish onto the sub (Hugo, 2026-11-24)
Hugo: "you should also hop from fish to submarine while seeing the fish swim off next to you looping left and right then
come back once you arrive". **The hop under water: `Sub.AirHop` 0, and the fallback of [the air hop](#the-air-hop-hugo-2026-11-25).** On main since
2026-11-25; checked offline (below) and played by script in Studio (next); not played by hand. Kept as the tags
`backup-underwater-hop-2026-11-25` and `backup-underwater-hop-final`. The swim beside the sub, the weave and the return are the same
for both hops.

**Played by script in Studio (2026-11-25, `tools/studio/fish_sub_check.py all`, 18 runs: Clownfish to a Colossal Blue Whale,
lands 2, 5, 7 and 10, both ends of the lip, no fish, on foot, given up six ways).** [Stills](../attachments/fish-dive-and-sub-hop.png).
In every ridden trip: 0 frames with no fish, always one and the same model, never faded out, in the picture for the whole weave,
the kick cued with it, the hands' fish unchanged, the hop 1.2 to 1.95 s in. **Found and put right there:**
- **Thrown at the kick's end** (4 of 8 ridden trips, up to 480 studs off in a second): the server's seat reached the fish a frame
  before `State.Mode`, and for that frame `SubController` put the rider, welded to the fish, back on the sub's seat with that
  jump's speed. Main's old kick had the same race. Now `Visual.Seated` leaves the body alone: 112 to 233 studs/s, no throw.
- **The fish came in from invisible over 0.6 s** at the swap (the wild fish's fade, `ArriveController`): not for a rider's own
  fish made under them any more (the plain dive's swap too).
- **The camera cut at the hand-over** from the dive (its own last view is taken now: 3.3 degrees at most in a frame). From the
  Colossal whale's dive, filmed from beside, it swings in behind within 0.3 s (9 to 16 degrees a frame; it cut 77), before the
  sub is in view.
- **What the check still says FAIL to, read and left:** the run's camera is 16 to 20 degrees off behind on a few lands' bends
  (limit 15; the same with no fish, and before this work); `where the trip has it` at over 4,000 studs/s (1.4 ms between two
  readings is 6 studs; 0.61 once in the slow part); the Colossal whale's first frame, above; Manta Ray's first frame 1.4 studs
  off the line. **A death in the trip:** the body is taken on, and the copy goes as the new body comes 5 s later (as main's
  trip did); nothing is lost. The run with no fish began with the view turned
  right round (180 degrees, one frame), as the script left it.
- **Who:** a player who goes into the water riding their [ride fish](equip.md) with a sub and a land picked. Nothing
  else changes: on foot (with or without a fish equipped), and with a tank fish picked at the stand, it is the swim, the
  scoop, and the fish swimming up at the end or the fling, as before.
- **The way out** (`Sub.Approach`, 1.2 s as before). The fish dives in under you ([the dive-in](dive-in.md) has it up to
  there) and carries you out; the sub comes in dead straight through the gate, behind the
  fish's tail until the fish has drawn aside (`EscortAside`), then up level on the **left** of it (it comes from the
  right and below for a swimmer). Nobody is thrown about, so there is no swim.
  The camera goes on from the dive's own view when that is behind you, under the water and on your line, and stays behind
  the fish's tail and over its back (`EscortBack`, 130 studs behind you at most). While it is inside the body all the same
  the rider sees the fish see-through (`EscortThin` 0.8; on that screen only). It sets off at `EscortStart` (45), about the
  pace the dive hands over.
- **The hop** (`Sub.Pickup`, 0.75 s as before: 1.95 s in all). You push off the saddle, the fish dips under you, and you
  arc across onto the sub's seat.
- **The weave.** The fish swings out beside the hull and goes from its right to its left and back, once on most runs and
  twice on some (a longer fish takes longer over each), turning its nose and banking into each turn and swimming on its own
  tail beat. It swims **beside the sub wherever the water has the room** and crosses over or under the hull (small, short
  fish, where the water allows) or round the nose. On a side with no room it stays ahead of
  the nose, a little over the sub so it shows over the hull. The camera is the rule's: behind, on the middle line.
- **The return.** It is out to the right, then falls back beside the sub, settled `EscortSettle` before the drop, and
  the old kick puts you on it. The sub peels off to the left after (to the right before), so it doesn't cross the fish.
- **The sub stays level while the fish is beside it** (the start and the kick); it banks in the run's bends as before.
- **The fish is held to the sub's own line** for the whole trip (its place is across, up and ahead of the sub, and it
  faces the way the sub does), so a bend never swings it into the hull and it never jumps.
- **One fish, all the way:** the same copy from the water's surface to the kick (kind, size, colour), never hidden and
  never made again. Every number is in `Config.Sub` (`Escort…`); `Escort` 0 puts the old trip back.

How it works:
- The server makes the copy as the trip is made (`SubService.escortFor`) and anchors it. Where it is at any moment is a
  pure sum of the trip (`SubTrip.escort(trip, t)`), so **every machine places it for itself each frame, with no physics
  and no traffic**: other players see the same weave. The server moves its own copy only once, to the drop point. At
  "NOW ARRIVING" it lets go of the anchor and gives the fish to the rider's machine; from there the kick, `"SubLand"` and
  `RideService.seatOn` are the old ones. **There is no new message from the client**, so nothing new to trust.
- The plan is made from the fish's own box, the hull's (`SubTrip.Hulls`) and the open water either side of the line
  (`FishService.streamRoom`). The pick-up is put left of where the fish goes in, so the fish swims straight out; the line
  is held to the gate's and the lane's sides with the fish beside it (`EscortGate` 45), is straight past the gate, drifts
  to the left there if the lane's first neck needs it (`DRIFT`, `NECK` in SubService), and moves over before the drop so
  both fit. The room either side is measured along the line the sub really takes, for the stretch the weave goes over.
- **Given up cleanly.** Every step the server looks whether the very entry of the hands that went in is still the
  equipped one. If not (unequipped, put in the tank), the copy swims off and fades on every machine (`SubLeave`), is taken
  away, and the drop-off is the fling; the trip sent to the machines is rewritten too, so the rider's screen no longer says
  "Back on your fish!" or waits for a kick, and one given up in the kick itself is flung from where the rider is in the arc.
  Died (as the new body comes), reset, left the game, or a trip that can't be made: the copy is taken away.
  The fish of the hands is never touched, so it can't be lost or doubled.
- **The hand-over with the dive:** on the first frame of `State.Mode` "Carried", `DiveController` lets go of the body, the
  pose and the camera; from that frame they are `SubController`'s. The trip eases the fish from where the dive had it.
  The plain dive onto the ride fish (`SubService.diveFish`) now makes that fish with its saddle at the rider, not 4 ahead
  and 3 under (asked for by the dive's chat). RideService says whether they were riding (`Diving(player, mounted)`), as a
  fact, not from a 0.1 s window after the land fish went.

Readings, not confirmed by Hugo:
- **Equipped but on foot** is not this: you would be watching a fish you never rode swim out of nowhere. It stays as it was.
- **Where a side has no room the weave is ahead of the nose,** not beside: 180 of 858 Normal trips have room on neither
  side, 140 on the left only.
- **The return is to the right-hand side,** where the kick has always been.

Checked without Studio (`tools/subs/escort_check.luau`, the real code on the grey-box's lane, with the real camera sums:
all 78 kinds in `Config.Fish`, Normal and Colossal, with each of the nine subs, plus subs 1, 6 and 9 from both ends of the
lip (30 studs out): 2,652 trips, 60 frames a second, the fish as boxes and the sub as the models' own cells for what it
hides; `tools/subs/escort_hulls.py` for the hulls). The last run is after the review's ten fixes (2026-11-24), on
d7c958b. The check **fails** on a hull contact at every size and on a wall contact for Normal. **All Normal trips pass but
for what can't fit; Colossal has one check failing on 4 trips** (below). What can't fit is printed as `CANNOT FIT`, and the Colossal walls
that a fish of that size could have missed as `LIMIT`: neither counts as a failure.

| | Normal, middle of the lip (858) | Normal, the lip's ends (468) | Colossal, middle (858; up to 200 long, 96 wide, 147 tall) | Colossal, the lip's ends (468) |
|---|---|---|---|---|
| Hull in the run, nearest | 1.5 studs clear | 1.2 clear | 1.9 clear | 1.9 clear |
| Hull on the way out | 4.3 clear | 4.3 clear | 4.6 clear | 4.6 clear |
| Lane's sides from the hop on (its width, not the built terraces) | 3.0 clear | 2.9 clear | **347 trips, 46.7 at most** | **208 trips, 46.7 at most** |
| Lane's sides on the way out | 6.8 clear | 60 trips past them by 9.0 at most, where they dived in that far out (none goes further) | **365 trips, 56.1 at most** | **294 trips, 56.1 at most** |
| The sub in the gate / the lane, nearest side | 3.5 / 3.4 clear | 3.5 / 3.4 | 0.7 / 3.1 | 0.7 / 3.5 |
| Trips through the floor / the surface, by half a stud or more | 22 / 22 (AuroraJelly by 7 at most, TheDevourer by 2: taller than the water) | 12 / 12 (the same) | **286 / 278** | **156 / 152** |
| Tail out of the gate at the hop | by 51 | 51 | 20 | 20 |
| Nearest to the camera's line to you | 9.5 studs | 9.0 | 12.1 | 13.7 |
| Camera inside the fish's box on the way out | 0.22 s at most | 0.22 s | 1.63 s; over 0.5 s on 55 trips, see-through then | 1.63 s; 30 trips |
| In a 16:9 picture in the weave | always | always | always | always |
| Share of the weave with a third of it or more showing past the sub and you (average part showing) | 92% (79%) | 90% (76%) | 87% (61%) | 88% (61%) |
| Trips where that share is under half | 35 (all sub 9 to lands 2 or 5, no room on either side) | 0 | 76 | 17 (4 of the Colossal's 93 have room on a side: the failed check) |
| Most turn in one frame, degrees (the check fails over 12) | 10.3 | 10.3 | 10.6 | 10.7 |
| Most a frame's move differs from the last, studs | 1.5 | 1.5 | 1.3 | 1.5 |
| Off its place at the kick, studs | 0.4 | 0.2 | 0.4 | 0.2 |
| Trips that sweep more than 8 studs left of the middle | 835 | 453 | 529 | 342 |

Listed limits, all Colossal:
- **Walls** (from the hop on): 555 trips, 39 kinds: 337 are wider than the lane at its narrowest, 218 are not
  and still go through (listed as `LIMIT`). **Floor and surface:** 508 trips, 30 kinds (none fits the
  water it swims in; 447 trips by half a stud or more). BlueWhale at Normal size is through both by less than half a stud, on all 17.
- **The camera in the body over a second** (1.63 s at most): BlueWhale, Hellmaw, Kraken, Mosasaurus and StormSerpent, 85
  trips. The fish is see-through for it.
- **The one failed check:** LanternLeviathan (3 of its 17 trips) and WraithEel (1 of its 17), sub 9 to land 10, have a
  third of themselves in view for 0.48 to 0.49 of the weave; the check asks for half. Not chased further: outside the review's bar.

To run it, on a build with `Sub.AirHop` 0 (about 12 minutes; each part prints its own result, and the csvs are one line a trip). `lune` and `rojo` are not
on the PATH on every PC, so these are the whole paths (Rokit's own store):

```
~/.rokit/tool-storage/rojo-rbx/rojo/7.7.0/rojo build -o /tmp/place.rbxl
python3 tools/subs/escort_hulls.py /tmp/cells.json
for i in $(seq 1 11); do ~/.rokit/tool-storage/lune-org/lune/0.11.1/lune run tools/subs/escort_check.luau . /tmp/place.rbxl /tmp/p_$i.csv $i/11 /tmp/cells.json > /tmp/p_$i.txt & done; wait
grep -hE "FAIL|passed|LIMIT|CANNOT" /tmp/p_*.txt
```

So **a giant still goes through the walls, the floor or the surface** where the water is smaller than it is, as it does on
a plain dive. Nothing in this trip can shrink it without swapping the fish.

Not checked, for the Studio run (`tools/studio/fish_sub_check.py`, written and not run; it has the pictures in it too):
how it looks; the frames between the land fish going and the water one showing; the real terraces; other players' view
(the fish waits under their copy of the rider until the hop, which lags as it always has); a phone held upright, whose
picture is too narrow for a wide sweep.

### Titles on the run (task t1, Hugo 2026-11-20)
Hugo: "let the intro text for submarines begone ... add a special rule for submarines, if title pops up, make sure
that the old ones blends out quicker to fit in the next title directly after, now arriving text should be just as
stylised as the area text ... replace the area text with the arriving text in these cases."
- **No intro:** nothing comes up as the sub sets off.
- **Each land crossed** shows its ordinary land title (`UI/LandStrip`'s intro, `Kit.LandIntroLook`, Punch by
  default). On a run a title due while the last one still shows hands off: the old one blends out in
  `Config.SubTitles.Out` (0.18 s), the new one comes in `Gap` (0.04 s) after it is gone. Never two at once, and
  nothing queues: if lands go by faster than that, only the newest land's title comes in.
- **NOW ARRIVING** is the arrival land's title, in the same look: the small line over the name says NOW ARRIVING
  where it would say LAND 5, the name in the land's colours, the same pop in and fade (looks 1 and 2; the other looks
  use Punch's layout for it). It stays `SubTitles.ArriveHold` (1.9 s) and hands off from any title still up.
- **The arrival land's own title never shows** on a sub trip, even when the sub crosses into it before the slow-down
  or you cross the border after the drop; also when it is the first land crossed (a trip to land 2). Held back until
  you are back on the dock; a trip given up before the drop releases it.
- Swimming and riding keep their titles exactly as before; only a title that came up on a run hands off to the next.
- Checked by `tools/studio/sub_titles_check.py` (a run to land 10 and one to land 2, every title logged with its
  time from the trip's start).

## The held fish, and a faster sub (task f2, Hugo 2026-11-20)
> "jumping into the gameplay loop with the fish should let you ride it after submarine, make animation and
> travelling slightly faster, make travelling faster the further away the destination too."

**Built and run by script in Studio; not played by hand** ([the playtest](../playtests/2026-11-20-held-fish-sub.md),
clip: [held-sub-ride.gif](../attachments/held-sub-ride.gif)).
- **The ride fish rides with you** (task f2 built it for the held fish; since task e3 it is the **equipped** fish:
  hold a fish, press Q, [the ride fish](equip.md); a fish only held no longer counts). Equip a fish and go into the
  water. With a sub and a land picked: after the run that fish swims up beside the sub and the kick puts
  you on it, riding (the drop-off (b) above). With no sub (NO SUB equipped, no land, or `Sub.On` 0): you are put
  straight on it where you go in, instead of the dive-in's hop. It is that very fish: its kind, size and colour, so
  its speed and archetypes too. It is yours, so riding it tames nothing new; it is held to the usual rule, so a fish
  too strong for your Oxygen breaks off the meter and turns angry as any would (seen: an Epic Reef Shark on the
  starting Oxygen).
- **It is borrowed, never lost** (a reading, not confirmed by Hugo): it stays in your hands the whole dive, and the
  fish in the water is a copy made for the ride. A miss, a drown or the end of the dive takes nothing; back on the
  dock it is still in your hands and still equipped. Riding another fish leaves the copy to swim on in
  the herd.
- **Which fish:** the equipped one wins over the tank fish picked under RIDE WITH; with nothing equipped, the tank pick
  works as before; with neither, the fling. Nothing equipped on a plain dive-in: the dive-in's hop as before.
- **Faster animations:** every phase about a fifth shorter: the approach 2.0 to 1.6 s, the pick-up 1.2 to 0.96, the
  arrival 0.8 to 0.64, the fling 1.0 to 0.8, the fish's swim-in 1.4 to 1.12, the kick 0.6 to 0.48.
- **Faster runs, faster still when far:** the top speed is `Sub.Speed` (620) plus `Sub.SpeedPer` (0.17) for each
  stud of the run; the run is then kept between `MinRide` 3.2 s and `MaxRide` 7 s. Speeding up takes `UpShare` (a
  fifth) of the run and slowing `DownShare` (a quarter), so a far run's burst is as big as a near one's. The camera
  widens with speed as before (`Fov` 18 up to `Speed`), and up to `FovFar` (10) more on the way to `FovFarAt`
  (4,000 studs a second), so a far land's run looks faster too. The math is `Shared/SubTrip.plan`.

Measured in Studio, 2026-11-20 (the run is the pick-up's end to "NOW ARRIVING"; "in to drop" is from the water to the
drop). Before is the old plan on the same distances, matching the 2026-11-17 logs:

| Land | Run distance | Before: run, top speed | Before: in to drop | After: run, top speed | After: in to drop |
|---|---|---|---|---|---|
| 2 Coral Reef | 1,294 studs | 4.0 s, 520 | 8.0 s | 3.2 s, 507 | 6.4 s |
| 5 Open Blue | 8,822 studs | 10.0 s, 1,017 | 14.0 s | 5.3 s, 2,120 | 8.5 s |
| 10 The Underworld | 21,365 studs | 10.0 s, 2,476 | 14.0 s | 6.5 s, 4,252 | 9.7 s |

## Readings, not confirmed
- **The trigger** (reading, not confirmed). Hugo's words are "jump in the water start swimming while the submarine
  swims in". The reference starts the flight with F at the hub, with no jump. Ours: the destination is picked at the
  hub first (the reference's Equip), then the ordinary walk off the dock starts it. With no destination picked the
  dive is the dive-in as it is today. F at the dock opens the panel; it doesn't launch.
- **The tiers** (reading, not confirmed). One tier per land after the first. **Tier N takes you to land N + 1, and to
  any land before it.** Each tier needs the one before (an upgrade, as Hugo's "upgrade tier increasing the distance").
- **The prices** (the user, 2026-11-24: "Price subs with the tuning chat, they should be fairly pricey"): $75K, $500K,
  $5M, $50M, $500M, $5B, $75B, $1T, $15T, tiers 1 to 9 (`Config.Sub.Prices`, `Sub.Free` 0): 23 to 41 min of income each
  for tiers 1 to 6, more after ([progression](progression.md)). *Until then, guesses, and free:* set by [progression](progression.md)'s twice-as-fast plan: a tier costs about the
  trainer level for the land before it, so you buy the sub to a land once you are at home a land short of it. It
  skips a ride you can almost make yourself. That is cheaper, relative to income, than the reference's, whose
  flights cost far more than a sitting earns.

| Tier | Takes you to | Price (the old guess) |
|---|---|---|
| 1 | 2 Coral Reef | 2,500 |
| 2 | 3 Kelp Forest | 25,000 |
| 3 | 4 Shipwrecks | 250,000 |
| 4 | 5 Open Blue | 2,000,000 |
| 5 | 6 Twilight | 15,000,000 |
| 6 | 7 Midnight | 150,000,000 |
| 7 | 8 Vents | 1,000,000,000 |
| 8 | 9 Bone Graveyard | 8,000,000,000 |
| 9 | 10 The Underworld | 50,000,000,000 |

- **The selected fish** (reading, not confirmed). The game has no "selected fish" today: what you tame is carried
  home and goes into your tank, where it earns. So here **the selected fish is one fish from your own tank**, chosen
  in the SUB panel ("Ride with"). It isn't taken out of the tank: a copy of it (its kind, size and colour) swims up
  for the drop-off, and it counts as already yours, so riding it tames nothing new. It is held to the usual rule: a
  fish too strong for your Oxygen in the land you are dropped in empties the meter, as any fish would. Nothing is
  saved yet; the pick goes with the tank when saving arrives.
- **Where you are dropped** (reading, not confirmed): 150 studs into the land, in the middle of the lane, at the
  herd's height.
- **A missed fling** leaves you floating (the dive-in's forgiveness), and the herd at the drop point is kept stocked
  from the moment the sub sets off.

## Ideas not agreed
- Flying it yourself, as the reference does (WASD between two lines). Hugo asked for a carry, so ours is a ride.
- A Robux price per tier, as the reference's (49 to 1,999).
- Other players riding along (a bus), and seeing the trip on the land strip.

## Open
- (2026-11-23) The nine subs are toy models, one a tier, in the style Hugo picked (A, the chunky toy):
  [sub models](sub-models.md). Ridden by script on all nine tiers, not by hand. The voxel models of 2026-11-22 were
  a fallback and are out of the game. Before that:
- (2026-11-18) The nine subs are placeholders (`Shared/SubModels`: the same hull in a new colour with one more
  piece a tier, its name floating over the tower). Only the look changes with the tier; speed and the trip are the
  same for all. Buying was free until 2026-11-24 (`Config.Sub.Free` 1).
- Hugo's word on the readings above, and a play by hand: is it satisfying? (Measured only by script.)
- (2026-11-24, measured with the camera behind) **The dock is behind the camera at the pick-up.** You are thrown
  back toward the dock onto the seat while the camera draws back, so the dock's wall pulls it in from 20 to 14 studs
  behind you over the last half second (one step of 2 studs in a frame), still on your line. Gone in at the very end
  of the lip (5 studs from the lane's wall) it is held 8 to 11 studs behind you for the whole swim and 4.5 at the
  seat ([still](../attachments/subcam-behind-lip-end-pickup.jpg)): close, never to the side. The flag posts were
  never within 4 studs of it (the bunting between them was, on two frames of one trip). For Hugo's eye; nothing changed for it.
- (2026-11-24) The sub's own hull turns 6.9 degrees in one frame as the pick-up begins (it swims in from one side and
  is on the lane a frame later). Seen in the numbers, not looked at. (Coming up beside a ride fish it is straight by then.)
- (2026-11-24) The run's camera swings up to 21 degrees off the sub's nose on land 10's bends (the nose turns at up to
  350 degrees a second there). Old code, not part of "never at the side" as built; Hugo's call whether it should
  follow the nose more tightly.
- The panel is a placeholder, not the UI chat's style; the N panel doesn't list `Sub` yet.
- On a phone: not tried. F opens the panel on a keyboard; the SUB button works by touch.
- The prices, once the pace is set (progression's question 4).
- The partner's animations for the pick-up and the drop-off (hooks below). The sub's models are made
  ([sub models](sub-models.md)); they are not uploaded.

## Built (2026-11-17)
Every number is in `Config.Sub`, read live (the N panel doesn't list them yet).

| Piece | Where |
|---|---|
| Tiers, the purchase, the destination and the fish to ride with, per player, for the session (no saves: kept with the tank's coins, so they save with it) | `src/server/Services/SubService.luau`; the coins are the tank's (`AquariumService.spend`) |
| The carried state: no drain, no hop, no send-back; the trip's clock and path | `RideService` ("Carried"), `SubService` |
| The path: the herd's stream from where you went in to the drop point, sampled every `Sub.Sample` studs, `Sub.Lift` over the floor, kept under the surface | `FishService.streamPath` |
| The fish at the drop point are kept in the water from the moment the sub sets off, and six more put just ahead of it | `FishService.keepFor`, `FishService.stockNear` |
| The fling: an ordinary hop, launched at the sub's drop speed (`Config.hopFrom`, both sides) | `RideService.fling`; client `JumpController.fling` |
| Your fish beside the sub, held for you, driven by your machine, then the kick onto it | `FishService.spawnFor`; `RideService.seatOn` |
| The ride fish that swims with the sub (2026-11-24): its plan and its place at any moment, the same on every machine; made, watched and let go of by the server; placed and swum each frame | `Shared/SubTrip` (`escorted`, `escort`); `SubService` (`escortFor`, `looseEscort`, `dropEscort`); `SubController` (`escort`, `escortAt`, `leaving`) |
| Which fish: the equipped one (`RideService.equippedOf`, task e3), else the tank pick, fixed as the trip is made; the plain dive-in onto the equipped fish | `SubService` (`rideWith`, `diveFish`); `RideService.DiveFish` |
| The run's plan: top speed by distance, kept between MinRide and MaxRide | `Shared/SubTrip.plan` |
| The sub (placeholder parts), its motion, the rider's motion, the camera, the bubbles, banners | `src/client/Controllers/SubController.luau` |
| The panel | `src/client/UI/SubPanel.luau`; the SUB button in `HubButtons` |
| The rider's poses while carried | `AnimController` ("Carried": a swim, a tuck, a crouch on the seat, the streamlined fling) |

### What the server says (attributes)
- On the player: `SubTier` (0 to 9), `SubDest` (0: none, else the land), `SubFish` (the index of the tank fish to ride
  with, 0: none), `SubPhase` ("Approach", or "Saddle" when
  your ride fish carries you out, "Pickup", "Ride", "Arrive", "Drop", nil off the sub), `SubTrip` (JSON: the
  trip's start in server time, its phases' lengths, its path, the drop speed, the land, whether a fish comes, and
  `E`, 21 numbers, the plan of a fish that swims with it).
  `Tank` (JSON list of the tank's fish: id, size, colour) is set by `AquariumService` for the panel.
- On that fish: `SubFor` (the player's id, as on any drop-off fish) and `SubLeave` (given up: it swims off and fades).
- Studio's tests: `ServerStorage.SubTest:Invoke(op, userId, ...)` ("give", "home", "buy", "pick"), used by
  `docs/playtests/submarine/drive.luau`.
- Remotes: Action `"SubBuy"`, `"SubPick", land, fishIndex`, `"SubLand", fish` (the kick has put us on our fish), `"SubLeap", leap` (the air hop);
  Ride `"SubFish", fish` (this fish is yours, beside the sub), `"SubDenied", reason`, `"SubBought", tier`.

### Animation hooks (for the partner)
The placeholder motion is one function per phase in `SubController` (`approachPose`, `pickupPose`, `ridePose`,
`dropPose`, `kickPose`), each a CFrame for the rider against the sub's seat by a share 0 to 1 of the phase. The
rider's limbs are `AnimController`'s "Carried" pose, chosen by `SubPhase`. An uploaded animation replaces the pose and
keeps the CFrame path. The sub's model comes from `Shared/SubModels.build` (a template needs parts named `Hull`,
`Seat`, `Light` and `Prop`).
