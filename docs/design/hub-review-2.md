# Hub review 2: scale, open pens, layout, the water

Up: [the hub's layout](hub-layout.md), [the hub's models](hub-models.md), [the aquarium](aquarium.md), [water](water.md).
Written 2026-11-22 by the map chat. The user: "the scale feels wrong, whether it's in the actual scale of the hub or the
texture, or it's just the walk speed", "I don't like the look of the aquarium ... it diverges from the simplistic fence
feel that is a staple of the genre", "analyze my current hub ... see how we can place things to be as close to
one-to-one and to maximize player attention", and "experiment with a few variants of the water in its transparency ...
tell me other things we could do for the water".

**A study. Nothing in the place has changed.**

## What was read
- **The hub as it stands:** every part in its box was read from the place on 2026-11-22
  (`art/map/hub_study/dump_2026-11-22.csv`, by `tools/studio/hub_dump.luau`). **Nothing has been moved by hand since
  2026-11-20** apart from the W32 shift: every model sits where the W32 rebuild put it.
- **The reference:** our measured reading ([ride-a-dino-map](../reference/ride-a-dino-map.md), "The hub, measured",
  good to about 15%) and the frame of its pens (`research/ride-a-dino/map/H1.jpg`, private).

## 1. Scale: four things, one at a time

| | Ours | The reference | So |
|---|---|---|---|
| **Walk speed** | 28 (`Config.Dock.WalkSpeed`) | 28, measured | **Not the cause** |
| **The hub** | 400 x 312; the open floor between the tank fronts alone is **216 x 180** | about **230 x 180, pens included** | **The main cause.** Our open floor is the size of their whole hub. Every walk is long: back tank to the strip 180 studs (6.4 s) against their 110 (4 s) |
| **The pens** | 52 x 84 of water, **34 tall** (posts 34) | 50 x 60, **fence 4 high** | The footprint is close; the height is not. Eight 34-stud boxes make the hub read as a room of buildings |
| **The studs** | one every **1.0** stud, on an 8-stud checker | one every **0.64**, no checker on the hub floor | Ours are 1.56 times bigger. At the same speed the ground slides past 1.56 times slower in studs, so running *looks* slower and the world bigger |
| Camera | not measured | not measured | One capture framed like H1 would settle it |

![ours, the reference, and R, all at one scale](../attachments/hub-scale-plans.png)

**Reading:** the size of the hub and the height of the tanks are most of it, and the big studs add to it.

**The studs:** rescaling our picture would also shrink the squares toward the 5 studs the user turned down ("5 read too
small"). The reference's hub floor has studs and no squares, though, so the hub floor alone could take a stud-only picture
at 0.64 without touching the lane. That needs a new picture uploaded, and uploads wait for the user's word.

## 2. Open pens instead of tanks
The genre's plot (Findings, point 7; four trending games): a low fence of posts and two rails round a plate, a gap for a
gate, no roof, no glass. The user: posts "slightly offset with each other, slightly off kilter with a base plate".

![three open pens, the reference's size, sharing fences](../attachments/hub-pens-three.png)

Drawn by `tools/map/pen_bench.py` and `tools/blender/hub_view.py` (Blender: no studs, a stand-in light; its see-through
water is far more solid than Roblox's). Each pen is 50 x 60, the fence 4.4 high, posts 10 apart, each leaning up to 8
degrees with its height off by up to 0.35; the rails run between the posts' own points, so they tilt with them. The pens
share fences.

| | What it is | For | Against |
|---|---|---|---|
| **P1 a pool** (left) | a sand frame round a pool sunk to its brim; fish swim in it and just over it | Reads as water and as a pen. The fish are in the open, seen from anywhere | Big fish sit mostly above the pool |
| **P2 water to the rail** (middle) | the fence holds a block of clear water up to the top rail, with a foam line | The closest to "a tank" | The fish are behind water again, the thing Findings point 7 warns about. Needs a Roblox look before judging |
| **P3 a sand pen** (right) | sand, one small pool in a corner; the fish swim in the air over the sand | The reference's own idea: creatures stand in their pen. Every fish reads | A fish out of water. Fine in this genre's look, but the user's call |

**What the game code leans on** (`AquariumService`, `TankRideService`, `AquariumController`, `TankPanel`):
- `TankWater` is the space the fish swim in and you ride in. It can stay as an unseen box over the pen, so nothing in
  the game code changes. Fish are already drawn at their real size and pass through the glass today.
- `Post` and `TankWater` are stretched by the tank's level (`STRETCHED`). The fence posts are named `FencePost` so a level
  doesn't grow them. **Levels** become richer rather than taller: the fence wood, then painted, then stone; a gate arch;
  more inside. That is a note for the game-code chat before any of it goes in.

## 3. Layout, and where the eye goes
**R** (right in the plans): ours at the reference's size, 260 x 208. Eight pens of 50 x 60 in a U, sharing fences:
four along the back and two down each side, open toward the strip. Back pen to strip 108 (theirs 110), side pens 10 to 60,
and an open floor of about 124 x 108.

For attention, following the reference:
- **The spawn on the line from the pens to the strip**, facing the strip. The strip, the gap and the herd beyond it are
  straight ahead and fill the middle of the first view.
- **Sell and Auras flank that line**, 17 to 25 from the strip and 30 apart, as theirs. Every walk out passes them.
- **Nothing tall between the spawn and the gap.** The tanks' 34-stud height is what blocks the view today. Low pens give
  the whole hub one sightline, and from every pen front the herd shows through the gap.
- The Fuse machine a little further back, the Earners board on the wall beside the gap, the Index and the Submarine at
  the strip's two ends.

**Cost:** the hub's walls come from the generator, so R is one full map reload, which also re-scatters some lane props.
Pens, layout and size should be picked together and built in that one reload. The hand placing is read first and kept.

**To confirm with the user:** CLAUDE.md's rule is "copy the loop and the feel, never its look, models or layout". The ask
here is "as close to one-to-one". R copies the reference's sizes and the U, with our own models in it.

## 4. The water's see-through
The surface is four layers (`tools/map/water_look.luau`): white Glass on top (0.35 see-through), then Neon blue (0.76), a
dark layer (0.78) and a deep blue (0.85). Together they let through about **18%**. The glass on top blocks the most.

`tools/studio/water_see_buttons.luau` puts a row of buttons on the screen in Play (run it on the Client). Each button sets
the four layers live, so you can switch between them while looking at the herd. Nothing is saved.

| | Foam, Water, Dark, Deep | Lets through |
|---|---|---|
| Now | 0.35, 0.76, 0.78, 0.85 | 18% |
| A | 0.55, 0.82, 0.86, 0.88 | 35% |
| B | 0.70, 0.88, 0.90, 0.90 | 50% |
| C | 0.82, 0.92, 0.93, 0.93 | 65% |
| D, no glass | off, 0.70, 0.85, 0.85 | 50% |

**To check in Roblox:** parts with any see-through on them (halo eyes, glows) may not draw behind a Glass part at all.
If so, the glass hides those parts of a fish whatever the numbers are, and D fixes it.

## 5. More for the water, from the surface
Ranked by what they add for what they cost:
1. **Caustics:** moving light patterns on the floor under the shallow water by the hub. A Texture sliding on the floor
   near the surface, two layers drifting against each other. It is the strongest cue for "clear water". Cheap.
2. **Shallows:** the floor at the strip slopes off under clear water. You see the bottom go from sand to deep, so the
   water reads as see-through even where it isn't.
3. **Fish shadows:** a soft dark shape on the floor under each herd fish. It reads from above through any tint.
4. **A wake and a splash:** a foam ring where a fish breaks the surface, and a burst when a player dives in off the
   strip.
5. **Sun glints:** a few twinkles drifting on the surface (one emitter). Cheap.
6. **Colour by depth:** turquoise over the shallows to deep blue over the drop. It is the genre's most common water look.
7. **Rarity glow under water:** a Rare or better fish shows a soft coloured light through the surface, so you spot it
   from the hub.
8. **Our own surface picture** (`tools/art/water_texture.py`) in place of the tutorial pack's. It needs an upload.
9. **A shoreline:** foam lapping at the strip's edge and along the walls' feet.
- Not advised: Roblox's own terrain water. It refracts and has waves, but it can't take our layered look and costs more on
  phones.

## Also open
- **The map's material:** the user found SmoothPlastic better than Plastic in play ("Feels better, is better ... we'll
  touch more on that later"). The saved place is still Plastic. Switching it back is `tools/studio/matte_map.luau` with
  `FROM="Plastic"`, `TO="SmoothPlastic"`, plus the loaders' two lines. Waiting on the user's word.
