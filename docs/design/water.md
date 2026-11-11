# The moving water

Up: [the map: how we build it](map-method.md). Made 2026-11-11 by the map chat, from a video tutorial the user sent
("moving water here") and the free texture pack it uses, which the user found and linked.

![The water on the map and on the bench](../attachments/map-water.jpg)

## What the tutorial does
The water is **four flat layers stacked a stud apart**, from the top down:

| Layer | What it is |
|---|---|
| Foam | white Glass, 0.15 see-through, with an empty SurfaceAppearance inside it |
| Water1 | the water's colour, Neon, half see-through, with the water picture on its top |
| Water2 | near black, SmoothPlastic, 0.7 see-through |
| Water3 | a dark "Earth blue", Neon, half see-through |

- **Why it gives foam:** the glass layer is drawn before the three under it, so they show through it as water. Where
  something solid stands in the water, it hides the lower layers and only the white glass is left: a white line round
  it. The further apart the layers, the wider the line.
- **The layers must be meshes, not Parts:** a SurfaceAppearance only works on a MeshPart, and without it the glass
  hides the layers under it.
- **From underneath** (where our riders are) it reads as a bright blue ceiling, with things above it tinted. The
  tutorial warns it can look plain white from below; on our bench it didn't.

## The tutorial gone over again (2026-11-11, on the user's word)
What the first build had missed or got wrong, read from the tutorial's finished scenes:
- **The bottom layer is dark** (BrickColor "Earth blue"), not a bright blue. I had guessed bright, which washed the
  whole thing to one cyan. With it dark, each layer down darkens the water a step.
- **The steps.** At an edge the tutorial shows a white line, then a paler band, then the water: one band for each
  layer the edge cuts off. The user wants these more visible. They are as wide as the layers are far apart, so the
  layers now sit 2.6 studs apart (the tutorial's are about 1). On a sloping shore they spread wide; against our
  upright walls they stay narrow, and show best looking along a wall.
- **The colour is a soft sky blue,** not a glowing cyan, and **the picture's lines are faint**: only a little paler
  than the water (in the pack the picture is 0.9 see-through).
- **The cells are small:** about the size of a rock or a player.
- Not built: the waterfall (beams carrying the same picture) and the white spray at its foot.

**Where ours now differs on purpose:** the user wants the water somewhat see-through, so the glass layer is 0.25
see-through (theirs 0.15) and the three under it are thinner (0.7, 0.72 and 0.8, theirs 0.5, 0.7 and 0.5). The sunk
terrace beside the hub's mouth now shows through as a darker shape. More see-through means fainter foam and steps:
the two pull against each other.

| | The tutorial | Ours now |
|---|---|---|
| Layers apart | about 1 stud | 2.6 |
| Glass | 0.15 see-through | 0.35 (0.25 first; the user asked for a bit more see-through) |
| Water1, Water2, Water3 | 0.5, 0.7, 0.5 | 0.76, 0.78, 0.85 (0.7, 0.72, 0.8 first) |
| Picture | one layer, 9 studs to a tile, faint | one layer, 48 studs to a tile (the sea is far bigger than a pond), 0.6 see-through |

## What we added: the movement
The tutorial's water stands still. Ours, on the user's word ("a slight breathing and dynamic"):
- **The picture drifts,** slowly, in one direction. There is one layer of it, as in the tutorial; 48 studs to a tile now (128 was tried and the user asked for smaller).
  (The first build laid a second copy over it at another size, sliding the other way. That was my addition, not the
  tutorial's; the user saw the two didn't match up, and it was taken out.)
- **The water breathes.** The three lower layers rise and fall about a third of a stud, two slow waves of different
  lengths (5.3 and 8.9 seconds) added together, so the foam lines swell and shrink like small waves lapping, never
  quite repeating. The pictures swing a little with it.

## One block, not tiles (the user, 2026-11-11)
The first build dressed each of the map's 2,000-stud sea tiles separately. Two of them met in a line straight down
the middle of the hub's mouth, each block looked a little different from its neighbour, and the join showed as a
bright band. The user: no line should show at all, only the picture, and bigger; make it one huge block.
- **The sea is now one block, 2,048 studs on a side** (the biggest a part can be), **that stays under the camera.** It
  moves a whole tile of the picture at a time, so the picture never jumps.
- **Round it lies a ring of plain water,** eight flat parts of the same size, so the sea reaches the horizon. The
  nearest join is over 1,000 studs from the camera.
- The map's own sea tiles are turned unseen.

Every number is in one table, `LOOK`, at the top of `tools/map/water_look.luau`: colours, how far apart the layers
are (foam width), the pictures' sizes, speeds and strength, the breath's size and timing.

## How it is built here
- **`tools/map/water_look.luau`** is the whole thing: a script that runs on each player's machine. It hides the map's
  flat sea tiles (`ClaudeBlockout.Surface.SeaTile`, as they arrive: the map streams in by distance), builds the one
  block and its ring in `Surface.WaterLayers`, and keeps them under the camera and moving.
- **`python tools/map/water_luau.py`** writes the installer, `tools/studio/greybox/98_water.luau`. It sorts after the
  map's own loader files, so loading the map installs the water too. It puts in `Surface.WaterLook` (the script) and
  `Surface.WaterKit.Slab` (the mesh the layers are copies of, in a model marked Persistent so it reaches every
  player however far away).
- **It shows in Play, not in Edit.** In Edit mode the sea is still the plain flat tiles.
- **Checked in a play test:** one block of four layers and eight plain parts round it, no plain sea tile showing,
  the picture sliding, the lower layers moving.

## From inside and from underneath (play check, 2026-11-11, at the riding chat's prompting)
The layers reach from the surface down to about y = -8, and players are in that band: a player floating off a fish
rests at y = -3, a hop tops out at -6, a ridden fish may rise to -7.
- **From underneath** (camera at y = -30): a clean blue ceiling; things above the water show through it, tinted.
- **From inside the band** (camera at y = -5): the same ceiling, and a thin pale line across the view at eye level,
  where a layer is seen edge on. The layers were 0.4 thick; they are now 0.1, so the line is a hairline.

## Queued: making the water feel like water (the user, 2026-11-11)
**The aim, in the user's words:** make it obvious what's going on instantly when you're in the hub. "You walk up to
the water, you see the fish in the water slightly, you see the depth of the water." And inside: "feel like you're in
water when you're in the water", with the darkness and depth visible from outside. Not built yet; this is the plan to
talk through. It builds on [workout 1, going down](../style/01-going-down.md), which already tested fog by depth.

**From the hub, looking in** (the map chat's, in `water_look.luau`):
1. **Depth you can see from above.** Fog only works for a camera that is under water, so from the hub the sea has no
   depth of its own. The same trick as the foam, carried deeper: a few more faint dark-blue sheets well under the
   surface (say at 12, 25 and 40 studs down). Each one darkens what lies under it a step, so the floor fades to deep
   blue with depth and a fish near the top reads brighter than one near the floor.
2. **Fish as shapes under the surface.** With (1) and the clearer water, a fish below shows as a darker, bluer shape.
   Whether enough fish swim near the mouth, and near the top, is the herd's doing: a question for the riding chat.
3. **The mouth as the darkest water in view,** so the eye goes to where you dive: the floor's colour there, and
   nothing pale under the surface near the edge.
4. Later, with the parked dive-edge step: a sloping edge, where the foam's steps spread wide.

**Inside the water** (mostly the game's code, with the numbers set from here):
5. **Colour and distance by the camera's depth:** workout 1's main signal. The moment the camera goes under, the
   picture tints and fog closes in; deeper, darker and shorter. Needs Lighting's classic fog, which only works with
   no Atmosphere in Lighting, so the game's look controller has to swap them at the surface.
6. **Crossing the surface:** a splash, a short flash of bubbles across the view, and the sound going muffled.
7. **Things drifting in the water:** specks that hang and slide past the camera (they show speed too), bubble trails
   off fish.
8. **Light from above in the shallows:** the surface as a bright ceiling (already there), moving light on the floor
   (one drifting sheet of the cell picture just over the floor, following the camera, as the sea's block does), and
   a few shafts of light near the top. Deeper, these fade and glowing things take over.

**Suggested order:** 1 and 3 (small, mine, and they serve the hub's first look), then 5 (the biggest change inside),
then 7 and 8, then 6. **To settle first:** workout 1's open choice between look A (bright and saturated all the way
down) and look B (the light really goes); and how this sits with the game's new light, which is tuned for above
water.

## What it depends on
| Thing | Where it comes from | Note |
|---|---|---|
| The water picture | `rbxassetid://6126332496`, from the free pack the tutorial uses (Creator Store asset 6127206197, the user's link) | Someone else's asset: fine to use, but it could be taken down. Our own drawing is ready as a replacement (below) |
| The layers' mesh | `rbxassetid://446556804`, a plain cube from the Creator Store ("Smooth Cube", asset 446556868, free) | Same caution. A slab of our own would remove it |

## Tried and dropped
- **Making the mesh and the picture in the script** (so nothing depends on an asset). It works from Studio's own
  tools, but inside a running game both are refused unless a security setting is switched on in the experience
  ("EditableMesh / EditableImage is not accessible"). That setting is the user's to decide, so this way isn't used.
- **The creatures' own box meshes** (seven tail blocks are plain boxes). They are painted dark, and a mesh's paint
  darkens every layer: the foam came out black.
- **The first store cube tried** didn't show the picture and gave blue foam.

## Our own picture
`python tools/art/water_texture.py` draws one (`art/style/water/cells.png`): pale lines round bent cells, seamless,
drawn from shapes. It is **not uploaded**: the upload was asked for and is waiting on the user's plain yes. Once it
has an id, it goes in `LOOK.Picture`, and the two can be compared side by side.

## Still to do or decide
- Which picture: the pack's or ours.
- The colour: it is a bright pool blue now. It will want choosing with the light and fog (one of the
  [parked steps](map-structure.md#what-makes-their-map-read-and-where-ours-should-go)).
- The aquariums' water is still plain glass boxes; the same water could top them.
- Cost on phones: four see-through layers over the whole view. To measure with the thinning step.
- Waterfalls and currents (the tutorial's showcase uses beams with the same picture): not built.
