# Ride a Dino: how its map is built

Up: [Ride a Dino breakdown](ride-a-dino.md). Read 2026-11-10 by the map chat from all five of the user's recordings
(`D:\program files for me\videos\`, 2026-11-09 and 2026-11-10: the 5-minute run, the 35-second ride, the side-on ride
and two short clips), and then from a sixth, a flight over the first two lands (`2026-11-10 19-34-58.mkv`). The frames are private, in `research/ride-a-dino/map/` (gitignored; `grab.py` there pulls more).
**We take how it is built, never its look, models or layout.** Sizes are judged by eye against the 5-stud player.

## What it is, in one paragraph
A chain of wide, rounded rooms joined by narrow necks, each neck with a line of flags. The ground rolls, and at a
room's sides it steps up into terraces or a tall plain wall, or simply rolls off into haze. One colour per land. On the
floor stand a few small props, each made of a handful of loose bricks, which come apart when a big dino runs through
them. A land changes by changing two colours and the prop set. Nothing is ever over the track.

## The floor
- **One surface, one colour per land** (lime in the Plains, teal-green in the Forest, sand in the Desert), covered in
  small round studs, about one a stud.
- **A faint checker** of two close shades in big squares, seen from above. It gives the floor scale and shows speed.
- **It rolls gently:** long low rises, no steps. Darker rounded patches lie flat on it.
- **A land border** is a straight line across the track: a string of coloured flags between two posts, the floor's
  colour changing there, and the land's name fading in across the screen.

## The track from above (read again 2026-11-10, after the user's correction)
![A wide room narrowing to a gate; terraces one side, an open edge the other](../../research/ride-a-dino/map/Q1.jpg)

The first reading (a track of one width that winds) was wrong. Frame by frame through the flight:
- **The track is a chain of rooms.** It goes narrow, then wide, then narrow, then wide. Each wide part is a rounded
  room; each narrow part is a short neck. The edges are smooth curves that swell out and pinch in.
- **A line of flags hangs across every neck,** not only at a land's border: four of them pass in under four seconds
  of flight. A land is several rooms; its border is one more neck, where the colour changes.
- **The ground rolls.** Each room is a low dome, and near its sides the ground curves up into the walls.
- **The walls are the ground stepping up.** A side of a room is one of three things:
  - a hill of two to four broad terraces, each about as deep as a tree is tall, their tops the same colour and
    checker as the floor, their risers a pale grey-green;
  - one tall plain wall, three or four trees high, with one or two long shelves on its face and a flat top;
  - nothing: the ground rolls off over a rounded shoulder into haze, with loose blocks and big flat-topped shapes
    far out.
- **The two sides of a room differ,** and the kinds change from room to room.
- **A wall's line is a smooth curve made of short straight pieces;** its height holds for a stretch, then steps.
- **One colour does nearly everything in a land:** floor, terrace tops, wall tops, shelves, and the leaves on the
  trees. The only other tone is the pale wall face.
- **Trees and rocks stand on the terraces and wall tops too,** and in clusters on the floor, the middle included.

## The walls
![A wall from the side: a studded face, green caps in steps, shelves](../../research/ride-a-dino/map/J.jpg)

- **One section everywhere:** a plain vertical face (grey, studded) with a thick cap in the land's colour, about one
  player thick, overhanging a little.
- **Curved along the track.** A wall sweeps in and out in long arcs; it is never a straight line for long.
- **The top goes in wavy steps.** Along its length the wall's height changes in flat steps, up and down, so the cap
  reads as a staircase wave. Near the track it is 4 to 8 players tall.
- **Shelves:** short slabs of the cap's colour stick out of the face at lower heights, a few per stretch.
- **Tiers:** behind the first wall stands a taller one, and often a third, each with the same cap. Trees stand on the
  caps. Far off, pale blocky towers and block clouds fade into the haze.
- **Simple:** no detail on the face beyond the studs. The colour of the cap and the wave of the top do all the work.

## The props
- **Few kinds per land,** each a handful of boxes: a rock pile (4 or 5 boxes stacked off-centre), a flat-topped tree (a
  trunk and two plates), a pine (a trunk and four square slabs getting smaller), a leafy tree (a white trunk in
  segments, a few plates), tall grass (three thin boxes), flowers (flat tiles), small stones.
- **Sparse.** Most of the floor is empty: room to run and to read the herd. Props sit in loose groups, the big ones
  toward the sides.
- **They break.** A big enough dino running into one knocks it apart into its bricks:
  - leaf bricks fly up and tumble;
  - a segmented trunk falls over as a row of loose blocks and lies there for a few seconds;
  - a pine tips over whole and fades out;
  - small brown and yellow bits stay scattered on the floor where herds have passed.

  ![A tree coming apart](../../research/ride-a-dino/map/K.jpg)
- So a prop is built to break: **separate plain bricks, each a part of the thing, with nothing fused.**

## The hub
![The hub and the start](../../research/ride-a-dino/map/A.jpg)

- **A closed bowl.** A wide flat floor ringed by the same tall wall with wavy stepped caps. You cannot see out.
- **One gap in the wall is the start:** a pale strip across the floor marked START ZONE, between two wall ends. The
  herd is in view through the gap from anywhere in the hub.
- **Stations stand loose on the open floor,** each a small stall with a floating name and a coloured ring on the floor:
  sell, auras, fuse, the airline by the gap, the earners board on the wall beside it. Pens along one side, fenced.
- **Short walks.** Spawn to the start is a few seconds.

## The hub, measured (2026-11-10, second reading)
The first reading used walking time and guessed the walking speed at Roblox's own 16 studs a second. That guess was
wrong, and the hub came out too small. This reading uses the floor's studs as a ruler: their spacing at many places in
a frame fixes where the camera is, and the player (5 studs tall) fixes the scale. Tool: `research/ride-a-dino/map/
ground.py` (private). Figures are good to about 15%; far-off points less.

![The pens in a row](../../research/ride-a-dino/map/H1.jpg)

| What | Measured | In studs, about |
|---|---|---|
| **How fast a player runs in the hub** | the same two toys seen a second apart | **28 a second** (Roblox's own is 16) |
| The walk from the player's own pen to the start strip | 4 seconds, twice | **110** |
| From the corner of the start strip to the nearest pen | one frame | 40 |
| The stalls you use most (sell, auras) | from beside the strip | 17 to 25 from the strip, 30 apart |
| The start strip | from its middle to the airline stall at its end | 90 to 100 wide |
| A pen | from inside one, on its sand | **50 wide, 60 or more deep**; fence 4 high |
| The hub along the strip | from its middle to the far wall | 100 to 130 each way: 200 to 260 in all |
| The floor's studs | | one every 0.64 studs |

- **So their hub is about 230 by 180, and a player crosses it in 4 seconds because they run at 28.** At Roblox's own
  16 the same hub would take 7.
- **Pens stand side by side, sharing fences,** in a row along the side facing the start, and carry on round the
  corner. There is no walk between them.
- **In front of each pen:** the owner's black sign, and the rocking toy (the upgrade machine) on a red pad, on the
  open floor. A pen has a wooden ramp at one front corner.
- **Everything else stands loose on the open floor** between the pens and the start: sell and auras nearest the
  start, the fuse machine a little further back, the earners board on the wall at one end of the strip, the airline
  stall at the other.
- **The hub's floor has studs and no squares.** The squares begin on the track.

## What the recordings don't show
- Lands 4 to 10.
- Whether broken props come back by a timer or with "ALL HERDS RESET!", and what size of dino breaks what.
- Whether breaking gives anything.
