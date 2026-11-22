# What to sort in the code

A check of all of `src/` (97 files, about 50,000 lines) for what should be organised before another team takes it
over. Read 2026-11-22 by five helpers, one per area; their full lists, with file and line for every item, are in
[code-audit](code-audit/server.md) (their line numbers are as of commit `06cc484`). **The safe batch was done the
same day, on the user's word:** see "Done" at the end. Everything else is still the list to pick from.

Up: [Home](../../Home.md). Related: [Code map](../Code%20map.md), [handing the game over](../plans/sale-readiness.md).

## What the user asked
"Could you also go through and check if theres anything that should be organized and sorted in the code"

## In short
- **The code is in better order than its size suggests.** Every module is used, nothing is in the wrong folder, the
  server decides everything that matters, StyLua and the Rojo build pass, and selene has 0 errors.
- **What a new team would trip on is not the folders.** It is, in order: features that look finished and are not;
  code left in from choices already made; comments that are a diary of who asked for what; a few names that mislead;
  and files that grew very large.
- **Done today, no risk:** a [code map](../Code%20map.md), and a contents list with section markers in the twelve
  largest files (comment lines only).

## 1. Looks finished, is not (a buyer must know)
These are gaps in the game, listed here because the code hides them. The plan for them is in
[handing the game over](../plans/sale-readiness.md).

| What | Where |
|---|---|
| **Nothing is saved.** No DataStore anywhere: coins, the tank, upgrades and levels last one session. | all of `src/server` |
| **Nothing can be bought.** The shop prompts a purchase, but all 11 product ids are 0 and the server has no receipt handler, no pass check and no code that grants anything. | `shared/Products`, `UI/ShopScreen` |
| **The aura stall sends a message nobody hears.** `AuraBuy` has no server handler and nothing sets a player's aura. | `UI/AuraShop`, `AuraController` |
| **The trainer and the submarines are free,** and the trainer's twelve prices are placeholders. | `Config.Train.Free`, `Config.Sub.Free` |
| **The Index button opens nothing.** | `UI/HubButtons`, `StallController` |
| **Some pictures show only in Studio on one PC** (window header icons, fish icon pages, archetype badges). A live game shows blanks or falls back to 3D portraits. | `UI/Shop`, `UI/FishIcons`, `shared/Archetypes` |
| **Stand-ins for art not made yet:** every sound is a built-in Roblox sound re-pitched; fail, bite, smash and angry motions are code stand-ins waiting for animations. | `Lib/Fx`, `FailController`, `AnimController` |
| **A player with no free plot has no wallet.** Coins live inside the tank. | `AquariumService` |

## 2. Left in from choices already made (the biggest tidy-up)
The UI was built as numbered options for the user to pick from. The picks are made, but the options not picked are
still in the code, reachable only through Studio switches. A reader cannot tell which look is the game.

| File | Live | Still there |
|---|---|---|
| `UI/Tags` (2,800 lines) | look 7 | looks 0 to 6, word families 1 to 4 |
| `UI/CatchShow` | look 5 (which is `DiveScreen`) | looks 1 to 4 |
| `UI/DiveScreen` | variant 2 | variants 1, 3, 4 |
| `UI/CaughtText` | look 3 | looks 1, 2, 4, 5 |
| `UI/Kit` | ring style 1, Oxygen box 5 | ring styles 2 to 7, boxes 1 to 4 |
| `UI/LandStrip`, `UI/Rings`, `UI/Banners` | | older styles and fallbacks |

- **Taking these out would shrink the UI code by a good share** and is the one tidy-up that most helps a new reader.
- **It needs a play test** (what the player sees must not change), and the user's word that the unpicked looks will not
  be wanted again. They stay in git history either way.

## 3. Dead code
**Taken out 2026-11-22** (commit `8a427ce`, 222 lines, no code added; each had no caller in `src/` or `tools/`):
- **Server:** `RideService.deposited`, the `Owned` attribute, `AquariumService.sell`, `earningOf` and `stageOf`,
  `PropService.brokenCount`, `FishService.Tag`.
- **Client:** `State.secondsOn`, `Shake.at` and `Shake.clear`, `StallController.open`, the fail screen's switched-off
  arms, `ShopScreen.isOpen`, `Slots.chosen`, `Kit.shade`, `oxygenCorner`, `bubbles`, `Lime` and `Space`,
  `Portrait.rendered` and `kindOf`.
- **Shared:** `Spawn.Wander`, the Oxygen rows of four fish cut from the game, `Ease.clamp01` and `inQuad`, `Auras.get`,
  `Variants.clear`.
- **Repo:** the stray `--help/` folder (commit `ce30041`).

**Still there, unused by the game, not free to delete:**
- **The old `Action "Place"` handler:** no client sends it, but `tools/studio/e2_click_check.py` listens for it.
  Remove both together.
- **`Config.archetypeOf`:** only `tools/playtest/archetypes/client.luau` calls it.
- **`RideController.turn`:** no caller, but it shares state with `steer`. Needs a play test.
- **Five `AimHud` numbers** nothing reads: the sandbox panel still lists them, so its rows go too.
- **`Slots.Selected` and `StatRows.Pressed`:** events that live code fires and nothing listens to. Wire them or
  remove them with the lines that fire them.
- **`r.Owned` in `RideService`:** a count nothing reads now that the attribute is gone.
- **The four cut fish** (Butterflyfish, BlueChromis, Boxfish, FlyingFish) still have rows in `Config.LandRide.Kinds`
  and `UI/FishIcons`, models in `art/creatures`, and are used as test data by a few old scripts in `tools/`.

## 4. Comments
- **Every file explains itself, at length.** That is the strength. `Config.luau` has three times as many characters
  of comment as of code.
- **About a third of it is history:** who asked, on what date, the old value, a quote, a task id ("task e4", "grade
  issue 7") that points at notes a buyer will not have. 277 comments in `src/` name the partner, 172 "the user".
- **A few were wrong, corrected 2026-11-22** (commit `5dd24f5`, comment lines only): the header of `Net.luau` now
  lists every message as the code sends it; the comment above `Config.Wild`, `speedOf`'s, two in `FishService` that
  sat above the wrong function, and a handful more.
- **Suggested:** one pass that moves the history into the design notes (the comments already link them) and leaves a
  plain line per number. Safe for the game, but it touches nearly every line of `Config`, so it has to be done when
  nobody else is tuning, and it will clash with any unmerged work of Hugo's.

## 5. Names that mislead
| Name | The trouble | Suggested |
|---|---|---|
| `ClaudeBlockout` | The map's folder, written out in about 26 places across client, server and shared. | One constant in Shared, and a plain name (`Map`). Needs the place renamed too. |
| `UI/Shop` | It is the window kit. The shops are `ShopScreen` and `AuraShop`. | `DockWindow` or `WindowKit`. |
| `Config.Wild` | Everywhere else "wild" is an unridden fish; this is the bucking of the fish you ride. | `Config.Rodeo` or `Buck`. |
| "sandbox" in `RideService` | `sandbox(...)`, `sandboxReset` and `SandboxSit` also serve the live admin panel. | Say "test or admin". |
| land / zone / home | Three words for the ten areas. Tier means rarity, sub level and aura level. Giant means three things. | Pick one word each when next in those files. |

Renames need a play test and a word to everyone with open work; none is urgent.

## 6. Size and shape
- **Very large files:** `Config` (4,000 lines), `UI/Tags` (2,800), `RideService` (2,400), `AnimController` and
  `FailController` (2,300 each). They now have contents lists and markers, so they can be read; the markers are also
  where each would be split.
- **Files doing two jobs:** `AquariumService` (the wallet, the tank, selling, upgrades, and holding a fish),
  `RideService` (also the land ride fish and the ragdoll), `FailController` (outcomes, ragdoll, the fail words, the
  camera), `Kit` (also the fail words), `TankRideController` (also animates every tank fish).
- **Small helpers copied between files:** easing curves (three UI files), `hex`, a JSON decode, `flat`, `rootOf`, the
  sign builders, the variant list (four times on the server).
- **Messages handled in eight places:** every `Action` runs eight separate handlers across four services, each
  filtering by name. One router would be clearer, and is where a rate limit belongs.
- **Tuning numbers outside Config,** against its own header: `AngryStyles.Sync`, `RideStyles.Trainer`, a few constants
  in `ArriveController`. Robux prices sit in two places (`Products` and `Config`).
- **Splitting is not worth doing before a sale** unless the buyer asks. It carries the most risk (the sandbox tunes
  `Config`'s tables live, by reference) for the least gain now that the files have a way in.

## 7. Sturdiness (small, worth doing)
- **One error no longer stops everything** (2026-11-22, commit `d422ac6`): both `Main` scripts report a module that
  fails to load or whose `Init` fails (`[Main]` in the output) and carry on with the rest.
- **`SubController.Init` waits** for the PlayerGui, against the rule that `Init` never waits.
- **The admin panel works in a live game** for the place's owner (coins, fish, max Oxygen). Correctly locked to the
  owner; the new owner should know it is there and set `Config.Admin`.
- **The fish you ride is moved by your own machine.** The server checks its speed once a second but only notes a
  breach; it never corrects. Taming and money cannot be cheated this way; distance can.
- **No general rate limit** on the ride and submarine messages (the tank and sell ones have one).
- **Test hooks used only by the scripted checks** (`pretend`, `press`, `landInfo`...) sit among the live functions.
  Each now carries a "Test hook" comment naming the script that calls it (23 of them).
- **Phones:** a lot runs every frame (the fail camera's raycasts, `AnimController` moving every fish within 450
  studs, three places that walk a model's parts each frame). Nothing has been measured on a phone.
- **Text:** every word the player reads is hard-coded English, often joined from pieces; a few sizes are fixed pixels.

## What I would do, in order
Each is its own small piece of work.
1. **The safe batch: done 2026-11-22** (see below).
2. **Take out the unpicked looks** (section 2), with a play test of each screen.
3. **The two renames that confuse most:** `ClaudeBlockout` and `UI/Shop`.
4. **The history out of the comments,** once Hugo's work is merged and nobody is tuning.
5. **Leave the splits** (section 6) to the new team.

## Done (2026-11-22)
On the user's word: "tidy as such, just make sure you dont break anything".

| Commit | What | How it was checked |
|---|---|---|
| `ce30041` | The stray `--help/` folder removed (81 working files of `tools/art/rarity_ladder.py`). | Nothing refers to the path; the files stay in git history. |
| `8a427ce` | The dead code of section 3 (222 lines out, none added). | Every name searched again across `src/` and `tools/` after the change: 0 uses. StyLua, selene (0 errors, the 3 old warnings) and the Rojo build pass. |
| `5dd24f5` | Comments only: the `Net.luau` header, the wrong comments, the test-hook marks. | The diff holds no code line. |
| `d422ac6` | Both `Main` scripts guard loading and `Init`. | StyLua, selene and the Rojo build. |

**Not yet played in Studio.** Studio was in Play (left running) the whole time and was not touched. The check still to
run: sync `src/`, press Play, read the output for `[Main]`, "attempt to call a nil value" and "not a valid member",
then run `tools/studio/b4_tank_ride_check.py`, `e4_land_check.py` and `tank_panel_check.py`.

**A few design notes still name what was removed:** `docs/design/camera-shake.md` (`Shake.at`),
`docs/design/progression.md` and `docs/design/ui.md` (`State.secondsOn`, `Portrait.kindOf`),
`docs/design/ui-review.md` (`Kit.Lime`).
