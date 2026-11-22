# Ride a Fish

A Roblox game: ride sea creatures down a long dive, hop from one to the next before your Oxygen runs out, tame them,
keep them in your tank on the dock, earn coins, train your breath and dive further.

This folder is the game's code, its art sources and tools, and the builders' notes (an Obsidian vault: open
[Home](Home.md)).

## Where things are
| Folder | What |
|---|---|
| `src/` | The game code (Luau). Start with the [code map](docs/Code%20map.md). |
| `art/` | Sources for the creatures, the map, the submarines and the UI pictures. |
| `tools/` | Scripts that build the map, export and install creatures, cut UI pictures, and run checks in Studio. |
| `docs/` | Design notes (`docs/design/`), reviews, plans and the working log. |

## Run it
1. Install [Rokit](https://github.com/rojo-rbx/rokit), then `rokit install` (Rojo, StyLua, selene; versions in
   `rokit.toml`).
2. Open a place that already has the map and the models, run `rojo serve`, and connect Studio's Rojo plugin.
3. Press Play. In Studio the game starts as the [movement sandbox](docs/sandbox.md).

Rojo carries the code only. Building the place from nothing takes the scripts in `tools/`; the steps, and what is
still missing for a new team, are in [handing the game over](docs/plans/sale-readiness.md).

## Check a change
```
stylua --check src
selene src
rojo build -o build.rbxl
```
selene reports 0 errors and 3 known "shadowing" warnings.

## State
Not launched. Progress is not saved yet and nothing is on sale yet: see
[what to sort in the code](docs/reviews/code-organisation.md).
