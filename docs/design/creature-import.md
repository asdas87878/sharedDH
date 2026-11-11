# Creature import: what goes into the game next

Up: [Home](../../Home.md). Written 2026-11-11. Every creature in [the roster](roster.md) has a model
([the creature queue](creature-queue.md): 82 exports). This note says how the next import is decided and what is ready.
**Nothing here is uploaded.** An upload is permanent and needs the user's word.

## Why import now
To get a feel for the game with the whole roster swimming. The models are first drafts: good enough to play with, to be
polished later from the user's notes. They carry studs only where a model asks for them, and the studs are not in the
meshes yet. The variants (gold, rainbow) are not in the game either.

## Where things stand
- **82 creatures exported** to `art/creatures/<Folder>/game/` (a `.glb`, a `.mesh.json`, a palette). The folder's name
  is the creature's Id in the game.
- **33 are in the game now** (`tools/creatures/assets.json`). 32 of them are still the first, too-dark uploads; only
  the Reef Shark was replaced (`assets_dark.json`). The too-dark ones go: each is uploaded again from its corrected
  export.
- **49 have never been uploaded:** the Kelp Forest down to the Underworld, the eight variants and the ten Secrets.

## The user picks what goes in
The user wants to keep some creatures and take others out by hand. The picker is a page with every creature's picture,
ticked to start with; clicking one takes it out of the import.
- The picks are saved to `tools/creatures/picks.json` as `{"remove": [Id, ...]}` by the chat that built the picker.
- `python tools/creatures/plan_import.py` reads the picks and writes `tools/creatures/import_plan.json`:
  - `uploadNew`: never uploaded, kept by the user.
  - `uploadAgain`: in the game but too dark, kept by the user.
  - `asItIs`: in the game and correct.
  - `leftOut`: taken out by the user. `takeOutOfGame` lists those that are in the game now: their template in
    `ReplicatedStorage.FishModels` and their row in the fish table go.
  - `files`: the `.glb` to upload for each kept creature.
- With no picks made yet: 49 new uploads, 32 uploads again, 1 as it is.

## The import, when the user says go
For the chat that has the game code ([Sessions](../Sessions.md)); the steps are its own tools, unchanged.
1. The user's word for the uploads (permanent). Run `plan_import.py` first so the plan follows the latest picks.
2. Upload each `.glb` in `uploadNew` and `uploadAgain` as a Model asset through Studio's connector; write the ids into
   `tools/creatures/assets.json`. For an upload done again, move the old id into `assets_dark.json`.
3. `python tools/creatures/collect.py` writes `src/shared/Creatures/<Id>.json` for every export. Delete the json of
   each creature in `leftOut`, or it stays in the fish table.
4. `python tools/creatures/install.py <studio_id> [Id ...]` puts the templates into the place.
5. Speed, rarity, sizes, Oxygen use and where each kind spawns are another chat's work: it reads the roster and
   `src/shared/Creatures`. The variants and the Secrets have no spawn rule yet.

## Not decided
- Whether the variants import as their own creatures (they are models of their own here) or wait for the variant system.
- How a Secret spawns.
- The old too-dark assets stay in the Roblox inventory until the user says to archive them.
