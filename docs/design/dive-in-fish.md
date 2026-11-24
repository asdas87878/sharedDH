# Every fish's dive off the lip: the table (2026-11-24)

Offline sums on the game's own code and the map generator's boxes (how: [The leap on a fish](dive-in.md), `tools/dive/fish_dive_check.luau`), not a play. 78 kinds, the six size tiers (a size is capped by rarity; a colour never changes it), straight out over the lip at the land pace. **Before**: the leap as the partner left it, switched on. **Now**: branch `fish-dive`.

## By size

| Size | Dived before | Dive now | On the arc as asked (1) | A smaller arc (2, 3) | Only the rider's path tested (5) | Tail still back of the lip at the swap | Longest until under water, s |
|---|---|---|---|---|---|---|---|
| Tiny | 45 of 78 | 78 of 78 | 78 | 0 | 0 | 0 (most 0 studs) | 2.67 |
| Normal | 32 of 78 | 78 of 78 | 77 | 0 | 1 | 0 (most 0 studs) | 3.11 |
| Big | 20 of 78 | 78 of 78 | 68 | 2 | 8 | 1 (most 5 studs) | 2.95 |
| Giant | 17 of 78 | 78 of 78 | 65 | 4 | 9 | 6 (most 28 studs) | 3.29 |
| Huge | 16 of 78 | 78 of 78 | 51 | 7 | 20 | 12 (most 40 studs) | 3.38 |
| Colossal | 11 of 78 | 78 of 78 | 47 | 5 | 26 | 28 (most 40 studs) | 3.38 |

All sizes: 141 of 468 dived before, 468 of 468 now. Why the others did not (the first reason on the first arc): its tail comes down over the dock 192; its box is in the dock floor (the run-up, not a thing in the way) 132; its box meets the gate 3.

## The camera, by size

The player's beat is the camera going through the surface after the diver. It is kept wherever it fits: behind the fish, or else beside it. The gate: how many of the 78 have something (always the gate) between the camera and the rider before the water (and for the 0.15 s after it that a big one's is not pulled in), counted whether or not the camera is pulled in to it, at 30 frames a second from 0.1 s on. From 3 times the diver's distances up (`Config.Dive.LeapMountedAloft`) the camera is not pulled in to it, as that was a jump.

| Size | Goes under after the fish | of them beside it | Stays over the water | The gate between: fish | frames in all | longest run, frames | Not pulled in to it |
|---|---|---|---|---|---|---|---|
| Tiny | 78 of 78 | 0 | 0 | 0 | 0 | 0 | 25 |
| Normal | 78 of 78 | 0 | 0 | 3 | 13 | 3 | 45 |
| Big | 78 of 78 | 1 | 0 | 7 | 20 | 4 | 51 |
| Giant | 73 of 78 | 4 | 5 | 16 | 60 | 5 | 60 |
| Huge | 67 of 78 | 8 | 11 | 25 | 89 | 5 | 66 |
| Colossal | 61 of 78 | 14 | 17 | 30 | 117 | 7 | 69 |

All: 435 of 468 go under after the fish, 33 do not; the gate is between in 81 of 468, 299 frames. In the water nothing is between in any, and the camera is inside no fish's box.

## The ones that stay over the water

What is in the way of following the fish under. Behind it: its back is over the riding camera's line by that many studs when the chase begins (the camera can't be under the surface without being in the fish). Beside it: what stands between, tried on both sides (Grass and Wall: the cove's own walls, as the fish fills the opening; Gate/Brick: the arch).

| Fish | Size | Long / wide | Behind it | Beside it |
|---|---|---|---|---|
| AbyssalWatcher | Huge | 169 / 94 | its back is in the way (1 over the line) | Grass in the way |
| AbyssalWatcher | Colossal | 173 / 96 | its back is in the way (6 over the line) | Grass in the way |
| BlueWhale | Giant | 182 / 79 | its back is in the way (35 over the line) | Grass in the way |
| BlueWhale | Huge | 200 / 87 | its back is in the way (38 over the line) | Grass in the way |
| BlueWhale | Colossal | 200 / 87 | its back is in the way (38 over the line) | Grass in the way |
| CoralDragon | Colossal | 200 / 80 | its back is in the way (35 over the line) | Grass in the way |
| Dunkleosteus | Colossal | 157 / 73 | its back is in the way (11 over the line) | Grass in the way |
| GalleonWhale | Huge | 196 / 76 | its back is in the way (33 over the line) | Grass in the way |
| GalleonWhale | Colossal | 200 / 78 | its back is in the way (34 over the line) | Grass in the way |
| HalfboneMegalodon | Giant | 148 / 96 | its back is in the way (27 over the line) | Grass in the way |
| HalfboneMegalodon | Huge | 148 / 96 | its back is in the way (27 over the line) | Grass in the way |
| HalfboneMegalodon | Colossal | 148 / 96 | its back is in the way (27 over the line) | Grass in the way |
| Helicoprion | Colossal | 167 / 71 | its back is in the way (31 over the line) | Wall in the way |
| HellfinShark | Colossal | 177 / 88 | its back is in the way (34 over the line) | Grass in the way |
| Hellmaw | Huge | 136 / 78 | its back is in the way (36 over the line) | Grass in the way |
| Hellmaw | Colossal | 168 / 96 | its back is in the way (44 over the line) | Grass in the way |
| Kraken | Giant | 163 / 81 | its back is in the way (24 over the line) | Grass in the way |
| Kraken | Huge | 194 / 96 | its back is in the way (28 over the line) | Grass in the way |
| Kraken | Colossal | 194 / 96 | its back is in the way (28 over the line) | Grass in the way |
| Megalodon | Giant | 143 / 92 | its back is in the way (13 over the line) | Grass in the way |
| Megalodon | Huge | 150 / 96 | its back is in the way (26 over the line) | Grass in the way |
| Megalodon | Colossal | 150 / 96 | its back is in the way (26 over the line) | Grass in the way |
| MoltenMegalodon | Giant | 150 / 96 | its back is in the way (21 over the line) | Grass in the way |
| MoltenMegalodon | Huge | 150 / 96 | its back is in the way (21 over the line) | Grass in the way |
| MoltenMegalodon | Colossal | 150 / 96 | its back is in the way (21 over the line) | Grass in the way |
| Mosasaurus | Colossal | 200 / 79 | its back is in the way (12 over the line) | Grass in the way |
| PhantomWhale | Huge | 200 / 83 | its back is in the way (7 over the line) | Grass in the way |
| PhantomWhale | Colossal | 200 / 83 | its back is in the way (7 over the line) | Grass in the way |
| Shonisaurus | Colossal | 200 / 78 | its back is in the way (7 over the line) | Grass in the way |
| TheDevourer | Huge | 200 / 82 | its back is in the way (18 over the line) | Grass in the way |
| TheDevourer | Colossal | 200 / 82 | its back is in the way (18 over the line) | Grass in the way |
| VoidWhale | Huge | 200 / 86 | its back is in the way (18 over the line) | Grass in the way |
| VoidWhale | Colossal | 200 / 86 | its back is in the way (18 over the line) | Grass in the way |

## Where the gate is between

Frames of 30 a second, from 0.1 s to the water: AuroraJelly Normal 7 of 56, BlueWhale Normal 3 of 65, TheDevourer Normal 3 of 73, AbyssalWatcher Big 3 of 65, BlueWhale Big 4 of 65, HalfboneMegalodon Big 1 of 65, Kraken Big 3 of 65, MoltenMegalodon Big 1 of 65, TheDevourer Big 4 of 65, VoidWhale Big 4 of 59, AbyssalWatcher Giant 3 of 73, BlueWhale Giant 5 of 73, EmberSerpent Giant 5 of 59, GalleonWhale Giant 4 of 65, HalfboneMegalodon Giant 3 of 65, Hellmaw Giant 3 of 65, InfernalAngler Giant 2 of 70, Kraken Giant 5 of 73, Kronosaurus Giant 4 of 73, Livyatan Giant 4 of 73, Megalodon Giant 3 of 65, MoltenMegalodon Giant 3 of 65, Mosasaurus Giant 4 of 65, PhantomWhale Giant 4 of 65, Shonisaurus Giant 4 of 73, VoidWhale Giant 4 of 65, Anomalocaris Huge 3 of 73, Basilosaurus Huge 5 of 73, BlueWhale Huge 4 of 73, CoralDragon Huge 4 of 65, Dunkleosteus Huge 4 of 65, Elasmosaurus Huge 3 of 65, EmberSerpent Huge 4 of 65, GalleonWhale Huge 4 of 73, HalfboneMegalodon Huge 3 of 65, Helicoprion Huge 3 of 65, HellfinShark Huge 3 of 65, Hellmaw Huge 3 of 73, InfernalAngler Huge 5 of 73, Kraken Huge 2 of 73, Kronosaurus Huge 3 of 73, Liopleurodon Huge 4 of 73, Livyatan Huge 4 of 59, Megalodon Huge 3 of 65, MoltenMegalodon Huge 3 of 65, Mosasaurus Huge 4 of 59, Orca Huge 3 of 65, PhantomWhale Huge 4 of 65, Shonisaurus Huge 4 of 65, VoidWhale Huge 4 of 65, Xiphactinus Huge 3 of 65, Anomalocaris Colossal 3 of 65, BlueWhale Colossal 4 of 73, CoralDragon Colossal 3 of 73, Dakosaurus Colossal 5 of 59, Dunkleosteus Colossal 5 of 65, Elasmosaurus Colossal 4 of 65, EmberSerpent Colossal 4 of 65, GalleonWhale Colossal 7 of 73, GoliathGrouper Colossal 6 of 65, GreatWhite Colossal 4 of 65, HalfboneMegalodon Colossal 3 of 65, Helicoprion Colossal 4 of 73, HellfinShark Colossal 4 of 73, Hellmaw Colossal 4 of 73, KelpWyrm Colossal 4 of 65, Kraken Colossal 2 of 73, Kronosaurus Colossal 3 of 73, Liopleurodon Colossal 4 of 65, Livyatan Colossal 3 of 65, Megalodon Colossal 3 of 65, MoltenMegalodon Colossal 3 of 65, Mosasaurus Colossal 3 of 65, Orca Colossal 4 of 65, PearlSerpent Colossal 4 of 65, PhantomWhale Colossal 4 of 65, Shonisaurus Colossal 4 of 65, SkullAngler Colossal 5 of 73, StellersSeaCow Colossal 4 of 65, VoidWhale Colossal 4 of 65, Xiphactinus Colossal 3 of 65.

## By fish

Before: the sizes that dived. Now: the arc each size takes, Tiny to Colossal (1: as asked; 2 and 3: lower, shorter; 5: the first of the three arcs only the rider's own path is tested on, so a tail or fin may pass through the dock's end or the gate; no fish needs a later one). Tail: how much of its length is still back of the lip, in the dock, as the server swaps it (Colossal). Floor: how deep its box cuts the dock floor on the way out (Colossal; a box is bigger than the fish).

| Fish | Length Normal / Colossal | Dived before | Now | Under water after, s (Normal / Colossal) | Tail, studs | Floor, studs |
|---|---|---|---|---|---|---|
| SergeantMajor | 13 / 27 | all six | 1 1 1 1 1 1 | 1.59 / 1.97 | 0 | 1 |
| YellowTang | 14 / 27 | all six | 1 1 1 1 1 1 | 1.62 / 2.02 | 0 | 1 |
| Clownfish | 11 / 21 | all six | 1 1 1 1 1 1 | 1.50 / 1.84 | 0 | 1 |
| Pufferfish | 15 / 30 | all six | 1 1 1 1 1 1 | 1.66 / 2.07 | 0 | 1 |
| Stingray | 27 / 59 | Tiny | 1 1 1 1 1 1 | 1.86 / 2.36 | 0 | 1 |
| Seahorse | 16 / 41 | all six | 1 1 1 1 1 1 | 1.71 / 2.31 | 0 | 1 |
| ReefShark | 36 / 102 | Tiny, Normal | 1 1 1 1 1 1 | 2.12 / 2.94 | 0 | 4 |
| Parrotfish | 18 / 41 | all six | 1 1 1 1 1 1 | 1.75 / 2.24 | 0 | 2 |
| Lionfish | 16 / 35 | all six | 1 1 1 1 1 1 | 1.66 / 2.11 | 0 | 1 |
| MorayEel | 33 / 81 | Tiny | 1 1 1 1 1 1 | 2.01 / 2.68 | 0 | 2 |
| HumpheadWrasse | 40 / 112 | Tiny, Normal | 1 1 1 1 1 5 | 2.21 / 2.90 | 0 | 5 |
| AbyssalWatcher | 73 / 173 | Tiny | 1 1 5 1 2 2 | 2.82 / 2.99 | 0 | 15 |
| Angelfish | 13 / 29 | all six | 1 1 1 1 1 1 | 1.61 / 2.07 | 0 | 1 |
| Anglerfish | 28 / 79 | Tiny, Normal, Big, Giant, Huge | 1 1 1 1 1 5 | 2.02 / 2.74 | 0 | 5 |
| Anomalocaris | 51 / 153 | Tiny | 1 1 1 1 1 5 | 2.34 / 2.77 | 0 | 5 |
| Archelon | 51 / 87 | Tiny, Normal | 1 1 1 1 1 1 | 2.36 / 2.82 | 0 | 3 |
| AuroraJelly | 40 / 104 | Tiny | 1 1 1 1 5 5 | 2.48 / 3.15 | 0 | 53 |
| Barracuda | 29 / 63 | Tiny, Normal, Big, Giant, Huge | 1 1 1 1 1 1 | 1.94 / 2.48 | 0 | 2 |
| Basilosaurus | 75 / 200 | none | 1 1 1 1 1 2 | 2.57 / 2.70 | 34 | 3 |
| BlueWhale | 101 / 200 | none | 1 5 5 1 1 1 | 2.75 / 3.36 | 40 | 7 |
| BobbitWorm | 53 / 160 | none | 1 1 1 1 1 1 | 2.30 / 2.79 | 14 | 2 |
| BoneLeviathan | 89 / 200 | none | 1 1 1 5 5 5 | 2.77 / 2.70 | 9 | 4 |
| BrimstoneEel | 58 / 175 | none | 1 1 1 1 1 2 | 2.41 / 2.74 | 12 | 4 |
| CinderRay | 43 / 85 | none | 1 1 1 1 1 1 | 2.17 / 2.70 | 0 | 2 |
| CoralDragon | 70 / 200 | none | 1 1 1 5 5 1 | 2.59 / 3.06 | 12 | 5 |
| Cuttlefish | 19 / 41 | all six | 1 1 1 1 1 1 | 1.72 / 2.20 | 0 | 1 |
| Dakosaurus | 58 / 175 | none | 1 1 1 1 1 3 | 2.43 / 2.72 | 14 | 4 |
| Dolphin | 27 / 67 | Tiny, Normal, Big | 1 1 1 1 1 1 | 1.91 / 2.56 | 0 | 2 |
| Dunkleosteus | 52 / 157 | none | 1 1 1 1 5 5 | 2.38 / 2.99 | 14 | 6 |
| Elasmosaurus | 69 / 200 | Tiny, Normal | 1 1 1 1 5 5 | 2.51 / 2.57 | 0 | 3 |
| ElectricRay | 29 / 81 | Tiny, Normal | 1 1 1 1 1 1 | 1.93 / 2.68 | 0 | 2 |
| EmberSerpent | 81 / 200 | none | 1 1 1 3 5 5 | 2.70 / 2.75 | 14 | 5 |
| FrilledShark | 35 / 97 | Tiny | 1 1 1 1 1 1 | 2.03 / 2.81 | 0 | 2 |
| GalleonWhale | 85 / 200 | none | 1 1 2 5 1 1 | 2.80 / 3.11 | 10 | 6 |
| Garibaldi | 14 / 30 | all six | 1 1 1 1 1 1 | 1.60 / 2.04 | 0 | 1 |
| GiantIsopod | 21 / 60 | Tiny, Normal, Big, Giant | 1 1 1 1 1 1 | 1.79 / 2.49 | 0 | 2 |
| GiantSeaBass | 33 / 83 | Tiny, Normal | 1 1 1 1 1 1 | 2.09 / 2.85 | 0 | 4 |
| GiantSquid | 55 / 153 | none | 1 1 1 1 1 1 | 2.34 / 2.83 | 1 | 3 |
| GoblinShark | 39 / 109 | Tiny, Normal | 1 1 1 1 1 1 | 2.12 / 2.89 | 0 | 3 |
| GoliathGrouper | 48 / 135 | Tiny | 1 1 1 1 5 5 | 2.37 / 2.90 | 0 | 7 |
| GraveRay | 43 / 87 | Tiny | 1 1 1 1 1 1 | 2.18 / 2.72 | 0 | 2 |
| GraveTurtle | 54 / 87 | Tiny, Normal | 1 1 1 1 1 1 | 2.39 / 2.82 | 0 | 3 |
| GreatWhite | 52 / 146 | Tiny | 1 1 1 1 2 5 | 2.36 / 2.75 | 0 | 5 |
| HalfboneMegalodon | 83 / 148 | none | 1 1 5 5 5 5 | 2.80 / 2.85 | 0 | 5 |
| HammerheadShark | 36 / 91 | Tiny | 1 1 1 1 1 1 | 2.09 / 2.82 | 0 | 3 |
| Helicoprion | 56 / 167 | none | 1 1 1 1 5 1 | 2.41 / 3.08 | 3 | 5 |
| HellfinShark | 59 / 177 | none | 1 1 1 1 5 1 | 2.45 / 3.04 | 3 | 5 |
| Hellmaw | 59 / 168 | none | 1 1 5 5 1 1 | 2.51 / 3.34 | 20 | 7 |
| InfernalAngler | 47 / 141 | Tiny, Normal, Big | 1 1 1 1 1 1 | 2.39 / 3.19 | 0 | 8 |
| KelpWyrm | 72 / 200 | none | 1 1 1 1 5 5 | 2.57 / 2.70 | 15 | 4 |
| Kraken | 91 / 194 | none | 1 1 5 1 1 1 | 2.92 / 3.29 | 19 | 8 |
| Kronosaurus | 71 / 144 | Tiny | 1 1 1 1 1 1 | 2.60 / 2.91 | 0 | 4 |
| LanternLeviathan | 79 / 200 | none | 1 1 1 3 3 5 | 2.68 / 2.82 | 25 | 5 |
| LeopardShark | 27 / 69 | Tiny, Normal | 1 1 1 1 1 1 | 1.92 / 2.56 | 0 | 2 |
| Liopleurodon | 62 / 164 | Tiny | 1 1 1 1 1 5 | 2.49 / 2.72 | 0 | 5 |
| Livyatan | 73 / 200 | none | 1 1 1 1 3 5 | 2.62 / 2.80 | 9 | 5 |
| MantaRay | 46 / 87 | none | 1 1 1 1 1 1 | 2.21 / 2.72 | 0 | 2 |
| Megalodon | 80 / 150 | none | 1 1 5 5 5 5 | 2.77 / 2.87 | 0 | 6 |
| MoltenMegalodon | 84 / 150 | none | 1 1 5 5 5 5 | 2.84 / 2.87 | 0 | 6 |
| Mosasaurus | 77 / 200 | none | 1 1 1 2 3 5 | 2.65 / 2.90 | 37 | 5 |
| Octopus | 26 / 66 | Tiny, Normal | 1 1 1 1 1 1 | 1.95 / 2.65 | 0 | 3 |
| Orca | 56 / 156 | none | 1 1 1 1 5 5 | 2.40 / 2.77 | 9 | 4 |
| PearlSerpent | 66 / 198 | none | 1 1 1 1 2 5 | 2.48 / 2.64 | 12 | 4 |
| PhantomWhale | 90 / 200 | none | 1 1 1 5 5 5 | 2.85 / 2.94 | 19 | 6 |
| Sawfish | 42 / 105 | Tiny, Normal | 1 1 1 1 1 1 | 2.15 / 2.81 | 0 | 2 |
| SeaLion | 24 / 53 | Tiny, Normal, Big, Giant, Huge | 1 1 1 1 1 1 | 1.85 / 2.37 | 0 | 2 |
| SeaScorpion | 34 / 95 | Tiny, Normal, Big | 1 1 1 1 1 1 | 2.03 / 2.82 | 0 | 2 |
| SeaTurtle | 25 / 55 | all six | 1 1 1 1 1 1 | 1.87 / 2.39 | 0 | 2 |
| Shonisaurus | 73 / 200 | none | 1 1 1 1 5 5 | 2.63 / 2.87 | 10 | 6 |
| SkullAngler | 42 / 126 | Tiny, Normal | 1 1 1 1 5 1 | 2.27 / 3.14 | 0 | 6 |
| StellersSeaCow | 58 / 164 | Tiny | 1 1 1 1 5 5 | 2.50 / 2.84 | 0 | 6 |
| StormSerpent | 75 / 200 | none | 1 1 1 3 3 5 | 2.58 / 2.72 | 36 | 3 |
| Swordfish | 38 / 96 | Tiny, Normal, Big, Giant, Huge | 1 1 1 1 1 1 | 2.13 / 2.89 | 0 | 3 |
| TheDevourer | 96 / 200 | none | 1 1 5 1 1 1 | 3.11 / 3.38 | 7 | 13 |
| Viperfish | 21 / 52 | Tiny, Normal, Big, Giant, Huge | 1 1 1 1 1 1 | 1.78 / 2.36 | 0 | 2 |
| VoidWhale | 89 / 200 | none | 1 1 3 5 5 5 | 2.82 / 2.95 | 28 | 5 |
| WraithEel | 59 / 176 | none | 1 1 1 1 1 2 | 2.40 / 2.65 | 9 | 3 |
| Xiphactinus | 58 / 173 | none | 1 1 1 1 5 5 | 2.46 / 2.89 | 7 | 6 |
