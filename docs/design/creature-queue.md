# Creature queue: models ready to go into the game
Up: [Home](../../Home.md). The creatures built in the voxel style ([workout 4](../style/04-voxel-style.md), [5](../style/05-rarity-look.md),
[6](../style/06-textures.md)), exported as game meshes and imported into the game. Written by a script from the exports
(2026-11-10); run it again after a model changes.

**Imported 2026-11-10.** All 33 were uploaded by the chat that has `src/` and Studio, on the user's go-ahead, and are in the
place; the 21 of zones 1 and 2 spawn, swim and can be ridden. The other 12 wait for their lands. The GLB export needed no
change. Asset ids: `tools/creatures/assets.json`. Capture: [the Reef Shark in Studio](../attachments/creature-reefshark-in-studio.jpg).

- **To change a creature that is already in:** re-export it, then it needs a new upload (permanent, so batch changes) and that
  chat's `tools/creatures/collect.py` and `install.py`. Tell that chat which ones changed.
- **What Roblox does to a file** (handled in the loader): turns the model 180 degrees about up, wraps each part in a
  `<part>_Node`, moves each part's origin to its box's middle (so pivots come from the json), and makes parts grey Plastic.
- **Not in yet:** studs; gold and rainbow. Nobody has yet looked at them swimming in play.
- The Blue Whale's files are named `BlueWhaletheoldone.*` (from its long name); its id everywhere is the folder name, `BlueWhale`.
- **Colours:** the first upload came in too dark (the file's colours were stored as linear light, and Roblox shows them as
  stored). The export now writes the palette's own numbers; the Reef Shark was tested in Studio and matches. All 33 were
  re-exported that way on 2026-11-10 and need one more upload, in one batch.

## What each creature's folder holds
`art/creatures/<Folder>/game/`:
- **`<Name>.glb`: the file the game imports.** One mesh object to a part (a part is one rigid piece: one MeshPart and one
  Motor6D), named as in the json, its origin at the part's pivot, parented as the parts are; the colours baked in as vertex
  colours; the faces of a glowing colour split off as `<Part>_Glow` (Neon is set per part). 1 unit = 1 stud.
- `<Name>.obj`: the same mesh as an OBJ, one object to a part, with a palette texture (kept for looking at; the game uses the GLB).
- `<Name>_palette.png` and `<Name>.mtl`: a strip of the creature's colours; every face is mapped onto its colour's cell.
- `<Name>.mesh.json`: size, the rider's seat, each part's parent and pivot, the colours, which colours glow, `glowParts`,
  `swimKeys` (every moving part's turn about its pivot at twelve moments of one swim cycle, as quaternions in Roblox's axes),
  and the stud rule (studs are not in the mesh yet: the texture route in Roblox is untested).
- Axes as Roblox has them: 1 unit = 1 stud, +Y up, the head toward -Z, right toward +X, the origin at the middle of the box.
- The same layout `tools/blender/fish_kit_export.py` writes for the older kit, with parts added.
- To export one again: `blender --background --python tools/blender/voxel_kit.py -- art/creatures/<Folder>/voxel.py <scratch> --export art/creatures/<Folder>/game`.

## The queue
64 creatures. "Worked over" means built and corrected with the user; "first draft" means built in the batches of
2026-11-10 and 11 and passed by the gate, seen by the user only on a batch sheet.

| Zone | Creature | Rarity | Length (studs) | Triangles | Parts | Glow | State | Folder |
|---|---|---|---|---|---|---|---|---|
| 1 Shallows | Blue Chromis | Common | 9.8 | 442 | 5 |  | first draft | `art/creatures/BlueChromis/game/` |
| 1 Shallows | Boxfish | Common | 8.8 | 480 | 7 |  | first draft | `art/creatures/Boxfish/game/` |
| 1 Shallows | Butterflyfish | Common | 9.5 | 454 | 4 |  | first draft | `art/creatures/Butterflyfish/game/` |
| 1 Shallows | Clownfish | Common | 10.1 | 976 | 6 |  | worked over | `art/creatures/Clownfish/game/` |
| 1 Shallows | Pufferfish | Common | 10.0 | 674 | 6 |  | first draft | `art/creatures/Pufferfish/game/` |
| 1 Shallows | Sergeant Major | Common | 12.7 | 792 | 6 |  | worked over | `art/creatures/SergeantMajor/game/` |
| 1 Shallows | Yellow Tang | Common | 9.8 | 382 | 3 |  | first draft | `art/creatures/YellowTang/game/` |
| 1 Shallows | Cuttlefish | Uncommon | 13.0 | 1,110 | 11 |  | first draft | `art/creatures/Cuttlefish/game/` |
| 1 Shallows | Flying Fish | Uncommon | 12.3 | 812 | 9 |  | first draft | `art/creatures/FlyingFish/game/` |
| 1 Shallows | Sea Turtle | Uncommon | 15.8 | 832 | 6 |  | first draft | `art/creatures/SeaTurtle/game/` |
| 1 Shallows | Stingray | Uncommon | 23.4 | 410 | 8 |  | first draft | `art/creatures/Stingray/game/` |
| 1 Shallows | Seahorse | Rare | 12.6 | 770 | 9 |  | first draft | `art/creatures/Seahorse/game/` |
| 1 Shallows | Reef Shark | Epic | 17.3 | 1,088 | 6 |  | worked over | `art/creatures/ReefShark/game/` |
| 1 Shallows | Archelon | Legendary | 32.9 | 1,932 | 12 | yes | worked over | `art/creatures/Archelon/game/` |
| 2 Coral Reef | Angelfish | Uncommon | 12.1 | 636 | 7 |  | first draft | `art/creatures/Angelfish/game/` |
| 2 Coral Reef | Lionfish | Uncommon | 12.1 | 966 | 7 |  | first draft | `art/creatures/Lionfish/game/` |
| 2 Coral Reef | Parrotfish | Uncommon | 12.8 | 922 | 9 |  | first draft | `art/creatures/Parrotfish/game/` |
| 2 Coral Reef | Moray Eel | Rare | 21.7 | 1,368 | 14 |  | first draft | `art/creatures/MorayEel/game/` |
| 2 Coral Reef | Octopus | Rare | 18.2 | 1,030 | 26 |  | first draft | `art/creatures/Octopus/game/` |
| 2 Coral Reef | Humphead Wrasse | Epic | 22.2 | 1,214 | 7 |  | first draft | `art/creatures/HumpheadWrasse/game/` |
| 2 Coral Reef | Dunkleosteus | Legendary | 26.2 | 1,406 | 9 | yes | worked over | `art/creatures/Dunkleosteus/game/` |
| 3 Kelp Forest | Garibaldi | Uncommon | 12.5 | 886 | 5 |  | first draft | `art/creatures/Garibaldi/game/` |
| 3 Kelp Forest | Sea Lion | Uncommon | 16.1 | 956 | 12 |  | first draft | `art/creatures/SeaLion/game/` |
| 3 Kelp Forest | Giant Sea Bass | Rare | 20.1 | 1,266 | 8 |  | first draft | `art/creatures/GiantSeaBass/game/` |
| 3 Kelp Forest | Leopard Shark | Rare | 18.3 | 1,102 | 8 |  | first draft | `art/creatures/LeopardShark/game/` |
| 3 Kelp Forest | Great White | Epic | 26.1 | 1,788 | 7 |  | first draft | `art/creatures/GreatWhite/game/` |
| 3 Kelp Forest | Steller's Sea Cow | Epic | 29.2 | 1,578 | 16 |  | first draft | `art/creatures/StellersSeaCow/game/` |
| 3 Kelp Forest | Dakosaurus | Legendary | 34.3 | 2,148 | 22 | yes | first draft | `art/creatures/Dakosaurus/game/` |
| 4 Shipwrecks | Barracuda | Uncommon | 20.4 | 1,193 | 8 |  | first draft | `art/creatures/Barracuda/game/` |
| 4 Shipwrecks | Hammerhead Shark | Rare | 20.1 | 980 | 9 |  | first draft | `art/creatures/HammerheadShark/game/` |
| 4 Shipwrecks | Sawfish | Rare | 24.7 | 920 | 7 |  | first draft | `art/creatures/Sawfish/game/` |
| 4 Shipwrecks | Electric Ray | Epic | 18.0 | 1,180 | 4 | yes | first draft | `art/creatures/ElectricRay/game/` |
| 4 Shipwrecks | Goliath Grouper | Epic | 24.1 | 1,326 | 10 |  | first draft | `art/creatures/GoliathGrouper/game/` |
| 4 Shipwrecks | Xiphactinus | Legendary | 33.9 | 1,986 | 17 | yes | first draft | `art/creatures/Xiphactinus/game/` |
| 5 Open Blue | Dolphin | Rare | 15.8 | 1,122 | 12 |  | first draft | `art/creatures/Dolphin/game/` |
| 5 Open Blue | Swordfish | Rare | 23.9 | 1,074 | 8 |  | first draft | `art/creatures/Swordfish/game/` |
| 5 Open Blue | Manta Ray | Epic | 24.0 | 754 | 12 |  | worked over | `art/creatures/MantaRay/game/` |
| 5 Open Blue | Orca | Epic | 29.2 | 1,356 | 15 |  | first draft | `art/creatures/Orca/game/` |
| 5 Open Blue | Elasmosaurus | Legendary | 43.0 | 1,982 | 22 | yes | first draft | `art/creatures/Elasmosaurus/game/` |
| 5 Open Blue | Helicoprion | Legendary | 32.7 | 2,064 | 13 | yes | first draft | `art/creatures/Helicoprion/game/` |
| 5 Open Blue | Blue Whale (the old one) | Mythic | 46.0 | 2,164 | 14 | yes | worked over | `art/creatures/BlueWhale/game/` |
| 6 Twilight | Viperfish | Rare | 16.0 | 1,152 | 13 | yes | first draft | `art/creatures/Viperfish/game/` |
| 6 Twilight | Giant Squid | Epic | 34.2 | 1,166 | 38 |  | first draft | `art/creatures/GiantSquid/game/` |
| 6 Twilight | Goblin Shark | Epic | 24.2 | 1,266 | 8 |  | first draft | `art/creatures/GoblinShark/game/` |
| 6 Twilight | Liopleurodon | Legendary | 36.3 | 2,232 | 12 | yes | first draft | `art/creatures/Liopleurodon/game/` |
| 6 Twilight | Shonisaurus | Legendary | 40.5 | 2,350 | 16 | yes | first draft | `art/creatures/Shonisaurus/game/` |
| 6 Twilight | Lantern Leviathan | Mythic | 46.4 | 2,446 | 24 | yes | first draft | `art/creatures/LanternLeviathan/game/` |
| 7 Midnight | Anglerfish | Epic | 17.6 | 964 | 10 | yes | worked over | `art/creatures/Anglerfish/game/` |
| 7 Midnight | Frilled Shark | Epic | 24.7 | 1,486 | 13 |  | first draft | `art/creatures/FrilledShark/game/` |
| 7 Midnight | Basilosaurus | Legendary | 44.1 | 2,650 | 26 | yes | worked over | `art/creatures/Basilosaurus/game/` |
| 7 Midnight | Livyatan | Legendary | 40.3 | 2,342 | 22 | yes | first draft | `art/creatures/Livyatan/game/` |
| 7 Midnight | Mosasaurus | Legendary | 43.0 | 2,394 | 24 | yes | worked over | `art/creatures/Mosasaurus/game/` |
| 7 Midnight | Kraken | Mythic | 47.8 | 2,596 | 26 | yes | worked over | `art/creatures/Kraken/game/` |
| 8 Vents | Giant Isopod | Epic | 16.4 | 1,070 | 10 | yes | first draft | `art/creatures/GiantIsopod/game/` |
| 8 Vents | Sea Scorpion | Epic | 21.2 | 1,462 | 14 |  | first draft | `art/creatures/SeaScorpion/game/` |
| 8 Vents | Anomalocaris | Legendary | 31.9 | 1,328 | 25 | yes | worked over | `art/creatures/Anomalocaris/game/` |
| 8 Vents | Bobbit Worm | Legendary | 38.0 | 2,396 | 16 | yes | worked over | `art/creatures/BobbitWorm/game/` |
| 8 Vents | Kronosaurus | Legendary | 42.0 | 2,700 | 12 | yes | first draft | `art/creatures/Kronosaurus/game/` |
| 8 Vents | Megalodon | Legendary | 42.0 | 2,546 | 9 | yes | first draft | `art/creatures/Megalodon/game/` |
| 9 Bone Graveyard | Wraith Eel | Legendary | 34.5 | 1,970 | 19 | yes | first draft | `art/creatures/WraithEel/game/` |
| 9 Bone Graveyard | Bone Leviathan | Mythic | 49.7 | 2,062 | 16 | yes | first draft | `art/creatures/BoneLeviathan/game/` |
| 10 Underworld | Brimstone Eel | Legendary | 34.3 | 2,272 | 20 | yes | first draft | `art/creatures/BrimstoneEel/game/` |
| 10 Underworld | Abyssal Watcher | Mythic | 38.6 | 2,732 | 10 | yes | first draft | `art/creatures/AbyssalWatcher/game/` |
| 10 Underworld | Hellmaw | Mythic | 31.1 | 2,386 | 13 | yes | worked over | `art/creatures/Hellmaw/game/` |

Totals: 92,489 triangles, 802 parts.

## To put one in the game
1. The user says yes to the upload (permanent).
2. Import the `.glb` (one MeshPart to a part).
3. Build the Model: a Motor6D from each part to its parent at the part's pivot; set the colours' Neon parts; the seat.
4. The swim: play `swimKeys` from the json on the joints.
The game's fish are made by `src/server/Lib/FishModel.luau` today (placeholders); the chat that has `src/` in hand does this step.
