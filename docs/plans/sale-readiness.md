# Handing the game over: getting it ready for another team

What a buyer's team would need that they would not get today, and the order to put it right. Written 2026-11-22 from
a read of all of `src/`, the `tools/` folder and the repo ([the five audits](../reviews/code-audit/repo-and-build.md)).
A plan: nothing in it is started except the notes in the code.

Up: [Home](../../Home.md). Related: [Code map](../Code%20map.md), [what to sort in the code](../reviews/code-organisation.md).

## What the user asked
"Im about to sell this game to someone else so i want it to be organized and ready to use for a team, all around. How
should we go about this fully"

## The blunt check first
- **Today this sells as code and art, not as a game.** It has not launched, so it has no players, no retention and no
  revenue to show, and those are what a Roblox game is usually priced on.
- **It also cannot be played by anyone but its two builders.** There is no saved place file in the repo, the scripts
  that build the place need a file from another project on this PC, and the creature models are private to one Roblox
  account.
- **It is not a finished product.** Nothing is saved between sessions and nothing can be bought.
- **So the first question is what the buyer is paying for,** because it decides how much of this plan is worth doing:
  - **The source as it is:** do stages 1 and 2 only. Small, low risk.
  - **A game ready to launch:** stages 1 to 4. Stage 3 (saving and purchases) is the large one.
  - **A launched game with numbers:** stages 1 to 4, then a launch, then sell. The most work, and the only version with
    proof.

## Four things only you can settle
1. **What the buyer gets:** the source and a place file, or a published game moved to them. Ask the buyer which.
2. **Hugo.** A large share of the game is his (the trainer, the submarine, the auras, the admin panel, much of the
   UI's direction). A sale needs his agreement and a split, in writing, before anything is handed over.
3. **A clean copy, or the repo with its history.** The repo is also your notes vault and the Claude workspace: 322
   commits, your names, PC names, a budget figure, 1,750 mentions of "the user" and 1,100 of Hugo, the chat logs. I
   would hand over a clean copy (stage 5) and keep the vault.
4. **The reference.** The notes, the code comments and `tools/review/rad/` record measuring Ride a Dino and copying its
   loop, feel and layout (never its look or models). The recordings are not in the repo, but eight comparison
   pictures and three study notes are. Whether a buyer sees that is your call to make openly; I would not quietly
   scrub it, and I would tell them.

## What is missing, by how much it matters

### A. Nobody else can build it
| Gap | Detail |
|---|---|
| **No place file is kept.** | Rojo carries the code only. The map, hub, water, models and light are built into a place by scripts. No `.rbxl` is in the repo. The place on this PC has unsaved work (the W32 hub); the last saved one in the notes is on Hugo's PC. |
| **The Studio scripts reach outside the repo.** | Every one calls `C:\Users\blast\RpgGame\tools\studio\studio_mcp.py` (or Hugo's `~/Projects/studio-runner`). Neither is in the repo and neither has install steps. |
| **Paths that only work on one PC.** | `C:\Users\blast\...`, `D:\ResearchCache`, `/home/hugo/...`, Blender's install folder, and Studio's own content folder. |
| **The 82 creature models belong to your Roblox account.** | Another account's Studio is refused them and shows block stand-ins. All 82 source files are in the repo, and the upload script exists, with your account id written into it. |
| **Some models and pictures were never uploaded.** | The submarines, the trainer's seahorses, the Silver/Gold/Rainbow meshes, the fish icon pages, the window header icons, the archetype badges. They load from files on one PC. |
| **The setup is not written down in one place.** | The order (code, map, light, sky, creatures, subs, trainer, pictures) exists only across script headers, design notes and Claude's skills. The Python packages are not listed anywhere. |
| **GitHub is behind.** | 20 commits and three new creatures are only on this PC. |

### B. It is not a finished product
| Gap | Detail |
|---|---|
| **Nothing is saved.** | No DataStore. Coins, the tank, upgrades, trainer level, subs and best depth are lost on leaving. |
| **Nothing can be bought.** | 11 offers with id 0; no receipt handling, no pass checks, and none of the things on sale (double Oxygen, double luck, cash, the starter pack) exists as code. |
| **Loose ends in the loop.** | The aura stall cannot sell; the trainer and subs are free with placeholder prices; the Index button opens nothing; a player with no free plot has no wallet. |
| **Art still to come.** | Every sound is a stand-in; fail, bite, smash and angry motions are code stand-ins; the hub and map art steps are parked. |

### C. Risks in a live game
- **The admin panel works live** for the place's owner. Fine, but the new owner must know.
- **The ridden fish is moved by the player's machine;** the server notes a speed breach and does nothing. Money and
  taming are safe; distance is not.
- **No rate limit** on the ride and submarine messages.
- **One script error stops every script after it** (no guard in either `Main`).
- **Phones are unmeasured,** and a lot runs every frame.
- **Not ours:** the water picture, a cube mesh and the sky are other people's Creator Store assets (one "could be
  taken down"); three HUD icons are from a free pack whose terms say it is "not to be resold"; the land pictures
  were made with an image generator. Check each against a sale, or replace them: they are few.

### D. Hard for a new person to read
The detail is in [what to sort in the code](../reviews/code-organisation.md): unpicked UI options still in the code,
comments that are a diary, a few misleading names, very large files. The first step is done: a
[code map](../Code%20map.md) and contents lists in the twelve largest files.

## The stages
Each stage leaves the project better whether or not the next one happens. Sized by what changes and what could go
wrong, not by time.

### Stage 0: stop losing work (now)
- **Save the place** from Studio to a file, and copy it somewhere safe. This is the one thing that can be lost today.
- **Push `main`** to GitHub, and commit or drop the untracked work (the three creatures, the handoff briefs).
- **Tell Hugo,** and merge anything he has not pushed, before any tidy-up touches the comments or names.
- Risk: none.

### Stage 1: anyone can build it
- **Keep a place file with the project** (in the repo, or a named release beside it), and write the rule for when it is
  re-saved.
- **Bring the Studio bridge into the repo** (`studio_mcp.py`), and turn every one-PC path into a setting read from one
  small config file.
- **One setup page:** what to install (with versions and a Python requirements file), then the steps from an empty
  place to the game, in order. The audit already has the 18 steps and which are unwritten.
- **One check command** that runs StyLua, selene and the Rojo build.
- **Move the assets to a Roblox group** the buyer can be given: upload the 82 creatures again under it (the script
  exists), and upload what never was (subs, trainer, variant meshes, the three sets of pictures), then fill the ids in.
- **Prove it:** a fresh clone on another PC and another Roblox account, built to a playable place by following the
  page alone. Hugo's PC is the natural test.
- Risk: low. No game code changes except asset ids. The upload is the long part.

### Stage 2: anyone can read it
- **The safe batch:** delete the dead code and the stray `--help/` folder, bring `Net.luau`'s header up to date, fix
  the wrong comments, guard both `Main` loops, mark the test hooks. No change to play.
- **Take out the unpicked UI looks.** Needs a play test of each screen.
- **Rename `ClaudeBlockout` and `UI/Shop`.** Needs a play test and the place renamed.
- **Move the history out of the comments** into the design notes. No change to play; touches nearly every file, so it
  comes after Hugo's work is merged.
- Risk: low to medium. Every step is checked by the build and a scripted dive.

### Stage 3: a product (only if the buyer is paying for one, or you launch first)
- **Saving:** one per-player record (coins, tank, plot stage, trainer level, subs, best depth), loaded on join, saved on
  leaving and on a timer. The wallet moves out of the tank at the same time.
- **Purchases:** the products made on Roblox, their ids filled in, a server receipt handler, pass checks, and the
  things they grant written.
- **The loose ends:** the aura stall's server side, real prices (the tuning chat's draft 2), the Index or its button
  removed.
- **Hardening:** one router for client messages with a rate limit; act on a speed breach; decide the admin panel.
- **A phone pass:** measure, then cut the per-frame work that shows.
- Risk: the highest here. Each needs play tests, and purchases need a test on a published place. This is the bulk of
  the remaining work.

### Stage 4: the art that is stand-in
- Sounds, the fail and angry animations, the parked map art steps. Only worth doing if you are launching it yourselves;
  a buyer's team will have its own taste.

### Stage 5: the package
- **A clean copy:** `src/`, `tools/`, `art/` sources, the place file, and a `docs/` cut down to what a team needs (the
  code map, the setup page, the design notes that describe the game as built, a known-issues list). Left out: Sessions,
  Handoff, Decisions, the Inbox, the Claude files, the research tools, your PC details, the git history.
- **A known-issues list,** honest and short. Section B and C above are most of it.
- **A credits and licences page:** what is not yours and on what terms.
- **The transfer itself.** Check Roblox's current rules for moving a game and its assets to another owner before you
  promise anything; I have not verified them and they change. A group that owns both is the usual route.
- **A walkthrough call** with their developer, with the code map open.
- Risk: low, but do it last so it is made from the finished state.

## What I would do
- **Stage 0 today,** whatever else is decided.
- **Ask the buyer the first question** before spending on anything past stage 2.
- **Stages 1 and 2 next:** they are cheap, they are needed for any kind of sale, and they are just as useful if you
  keep the game.
- **Stage 3 only against a price** that pays for it, or if you decide to launch it yourselves first.

## Done so far (2026-11-22)
- A [code map](../Code%20map.md) and a root `README.md`.
- Contents lists and section markers in the twelve largest code files (comment lines only; build and lint unchanged).
- The [check of what to sort](../reviews/code-organisation.md) and the five audits behind it.
