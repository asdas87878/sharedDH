# The map: how we build it

Up: [Home](../../Home.md). The study it rests on: [how Ride a Dino's map is built](../reference/ride-a-dino-map.md).
Written 2026-11-10 by the map chat. It replaces blockout v4 ([Blockout](../blockout.md)), which the user set aside the
same day: it looked nothing like the way the reference builds its world.

## Decided (the user, 2026-11-10)
- **Start again.** The v4 hub and most of the v4 map are abandoned.
- **Build it the way Ride a Dino builds its map,** then improve on it, as we did with the creatures.
- **Wavy steps means the walls and the track.** The walls follow the track smoothly and sit flush on its edge. In
  some stretches the walls disappear.
- **The track goes narrow, then big, then narrow, then big, in a pattern,** as the reference's does.
- **Props are made to break:** a big enough creature swimming into one makes it collapse. Breaking gives nothing.
  It isn't coded yet: for now the props are only modelled so that they can break.
- **The descent:**
  - it starts at a gentle slope;
  - after one or two lands it gets a bit steeper, and then a little steeper each land;
  - every land border has a small step down;
  - every few lands there is a big change in elevation. It is a slope, clearly steeper than the lands round it, not
    a sheer drop.
  - It all has to link and match.
- **The hub is closed in,** like theirs: visual blocks all round, not a platform with open ocean to look at.
- **The start:** you dive in from the start zone. No diving board. Where the reference has ground beyond its start
  zone, we have the top of the water, level with the hub's floor.
- **Once you are in the dive it should feel expansive.**
- **The diving spot is marked** with light and other means. Later; easy.

## What was wrong with grey-box 1 (the user: "you are misunderstanding how their wavy pattern is formed")
Grey-box 1 was a road of one width with fences. Set against the reference:
1. **One width.** Theirs goes narrow, wide, narrow, wide: rooms and necks. This was the biggest miss.
2. **Walls as a separate thing.** Thin rock steps with a contrasting cap, stuck on the lane's edge. Theirs are the
   ground itself stepping up, in the ground's own colour.
3. **Terraces far too small and even:** 14 studs deep, 16 high, like stadium seats. Theirs are broad and uneven.
4. **A dead flat floor.** Theirs rolls.
5. **Open edges cut square,** like the end of a table. Theirs roll off over a shoulder.
6. **Two colours per land** (sand floor, green or pink caps). Theirs is one colour and a pale wall face.
7. **Flags only at land borders.** Theirs hang at every neck.
8. **Props small and thin,** only along the sides, none on the terraces.
9. **No checker,** so no scale and no sense of speed.
10. **Nothing far off,** so an open edge showed empty blue.

## Grey-box 2 (2026-11-10)
The hub and the first two lands, rebuilt as rooms and gates: about 3,400 boxes. Made offline by
`tools/map/greybox.py`, drawn in Blender. Not in Studio.

![Grey-box 2](../attachments/map-greybox.jpg)
![From above](../attachments/map-greybox-plan.png)

What it has:
- **Rooms and gates.** A gate is 92 studs wide. A room swells to between 230 and 340, more to one side than the
  other, and the fat side takes turns. Rooms are 330 to 640 studs long; the lane turns 9 to 22 degrees at each gate.
- **A line of flags at every gate.**
- **Rolling ground:** each room is a low dome, up to 8 studs.
- **Three kinds of side,** chosen per room and per side: a hill of two or three broad terraces (30 to 54 deep, 8
  to 18 high, the higher ones shorter along the room), a tall plain wall (40 to 58 high) with shelves, or an open
  edge that rolls off over a shoulder, with flat-topped shapes far out.
- **One colour per land** for floor, terrace tops, wall tops and shelves; wall faces are that colour greyed.
- **A faint checker** on everything that is ground.
- **Props** at the reference's size (a tree is three to four players tall), in clusters on the floor and standing on
  the terraces: 370 of them, each three to six loose boxes.
- **The hub:** the same bowl, now with one tall wavy wall and shelves, and a start gate 92 wide.

What is still off, by my own read against the reference:
- The low terraces read as thin ridges from above: their risers want to be taller and paler.
- The far backdrop is heavy grey slabs, too close. Theirs is pale and distant.
- Wall faces come out grey-blue in these pictures: that is the stand-in light, to be judged in Studio.
- Props are stand-ins (the "trees" are corals to be designed).
- Gates may be too narrow or too wide for the herd: to be ridden.

## The method
### 1. Four kinds of piece, all plain boxes
| Piece | What it is |
|---|---|
| Ground | the floor and the top of every terrace, wall and shelf: one colour per land, a faint checker, later studs |
| Wall face | the side of a terrace or wall: the land's colour greyed, plain |
| Prop | a coral, a rock pile, a kelp stalk, a crate: 3 to 12 loose bricks |
| Trim | the flags at a border, the start strip, a station |

Nothing roofs the lane. That is the reference's way, and it keeps every jump clear.

### 2. The descent
The user's rule with first numbers on it:

| Land | Slope | At its end |
|---|---|---|
| 1 Shallows | 2° | a step of 8 studs |
| 2 Coral Reef | 2° | a step of 10 |
| 3 Kelp Forest | 3° | a step of 12 |
| 4 Shipwrecks | 4° | **the first big slope: 150 studs down at 18°, 460 studs long** |
| 5 Open Blue | 4° | a step of 14 |
| 6 Twilight | 5° | a step of 16 |
| 7 Midnight | 6° | **the second big slope: 250 down at 18°, 770 long** |
| 8 Vents | 6° | a step of 18 |
| 9 Bone Graveyard | 7° | a step of 20 |
| 10 The Underworld | 8° | the end |

- About 2,430 studs deep in all (v4: 1,622). The first four lands end 510 down, at the top of the first big slope.
- **The first big slope is where the first version's four lands end:** players arrive at its top and look down it.
- 18° is well inside what the herd can follow (about 27°).
- The floor and both walls step down together at a border.

### 3. Props that break (modelled now, coded later)
- **Built the creature way:** a few big boxes, each a part of the thing (a stalk, a cap, a branch), turned where it
  leans. Nothing fused.
- **One list per prop:** its bricks, bottom to top. Built by code from that list, like the creatures.
- When it is coded: still until hit; the bricks come loose on the player's own screen only, drift, sink and fade;
  the prop comes back after a while.

### 4. The hub
- **A closed bowl,** as the reference has it: an open floor ringed by the tall wavy wall, stations standing loose on
  the floor, one gap that is the start. Our own stations and arrangement, not theirs copied piece for piece.
- **The gap is the water's edge.** The hub's floor stops there and the water is 38 studs deep at once: you run off
  the start strip and you are diving.

### 5. What the riding code needs (the riding chat, 2026-11-10)
- Anything a fish must not pass through can be collided with (floor, walls, rocks). Light, glow, markers and the
  water's surface cannot.
- The path has a sample at the top and at the foot of every step and slope, and one every 25 to 50 studs in bends.
- The names the code looks up stay: `Workspace.ClaudeBlockout`, its `Surface` folder, the hub's spawn.
- The first land stays at least 38 studs deep.
- The lane's floor parts are named `Seabed`: the server reads the floor's height off them.
- Studio's `Workspace.FallenPartsDestroyHeight` has to sit well below the deepest floor (it is -20,000 in the open
  place, set by hand). The script that puts the new map into Studio must set it, because the game's own code can't.
- Walking off the start into the water works with no code change. The herd glides off a step or a slope's top and
  sinks; a jump over a big slope is theirs to test once it is in Studio.

- **The path's width now changes all the way along** (92 at a gate, up to about 340 in a room). The herd uses the
  middle 70% of it, so it bunches through a gate and spreads in a room.
- **Open edges need no invisible wall.** The riding code already holds a ridden fish to the lane's width plus 20
  studs, at its height over the lane's floor: the rider can lean out over the drop and look down, but not leave.
  The herd keeps to the middle 70%. So the path's `w` must be the true wall-to-wall width everywhere. Letting fish
  swim right out over the blue would be one number on the riding side: the user's call.
- A jump on an 18° slope is close to its limit (the herd ends about 42 studs below the rider; a jump counts fish
  up to 45 below). The riding chat tests it on the first Studio build.

Grey-box 2's `art/map/greybox/path.json` follows these rules.

## Where we can do better than the reference
1. **One brick size for everything.** Theirs are any size. Ours stack on a grid, so walls, caps and props line up
   and a break looks like bricks, not rubble.
2. **Open edges that show something.** Theirs open onto empty haze. Ours open onto the next lands: far walls, the
   lane's own next bend lower down, big shapes in the blue.
3. **The caps carry the land.** The rock stays one family; the cap's colour, the prop set and the fog are the land.
   In the deep lands the caps glow, and that is the lighting.
4. **The descent gives us views they can't have.** Their track is level. From the top of every step and slope the
   lane ahead lies below you.
5. **Waves by rule.** The walls' terraces follow two waves that never line up, so they look meant; and the whole
   lane can be redone in seconds when a number changes.
6. **Life on the terraces.** Their terraces are mostly bare. Ours can hold coral, kelp and the odd treasure, out of
   the rider's way.
7. **Breaking under water,** when it is coded: slow tumbling pieces and bubbles.

## What happens to the earlier work
- **Blockout v4:** set aside. It stays in Studio and in its script until the new map can take its place, because the
  riding sandbox runs on it.
- **The prop kit's faceted meshes:** not used on the lane. They can't break into bricks.
- **The stud look** ([map state](../map-state.md)): the tiles still apply. The reference also studs its wall faces,
  not only the tops; to be looked at again on the first new wall in Studio.

## Open, for the user
- Does grey-box 2 have the pattern right: rooms and gates, the three kinds of side, one colour per land?
- Sizes: a gate 92 wide, rooms up to 340 wide and 330 to 640 long, the hub 460. Bigger, smaller?
- Who shapes the hub from here: the user by hand in Studio, or more passes by script?
