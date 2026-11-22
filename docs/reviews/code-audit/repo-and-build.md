# Repo and build audit: what a new developer would be missing

Read-only audit of `C:\Users\blast\RideAFish` on 2026-11-22. No Studio, no uploads, no commits. Every fact below is
from a file (file:line) or from a command run here. Where the code was read but not run, it says "read from code, not
run". Where nothing was found, it says "not found".

Snapshot this was taken from: branch `main`, **20 commits ahead of `origin/main`**, with 39 modified and 17 untracked
paths (`git status -sb`, `git rev-list --count origin/main..main`). A clone of the GitHub repo today would not have
those. Among the untracked paths are three new creatures (`art/creatures/ScytheLeviathan/`, `TrialClawShark/`,
`TrialWhaleShark/`), four of the five `docs/handoffs/*.md` briefs, and `tools/balance/rad_economy.py`. `docs/Sessions.md`
(about line 33) mentions a "[Code map](Code%20map.md)". No file of that name is on disk: not found.

This report is in `work/`, which is gitignored (`.gitignore`: `/work/`), so it does not sync to the other PC.

---

## 1. What the game needs that is not in the repo

`default.project.json` maps only `src/shared` -> `ReplicatedStorage.Shared`, `src/server` -> `ServerScriptService.Server`
and `src/client` -> `StarterPlayer.StarterPlayerScripts.Client`. Everything below has to be in the place already.
All the "if missing" behaviour is **read from code, not run**.

### 1a. The map: `Workspace.ClaudeBlockout` (26 lookups in `src/`)
| What | Needed by | If missing (read from code, not run) |
|---|---|---|
| `ClaudeBlockout` folder: `Surface`, `Lane/{Seabed,Ground,Walls,Far,Props,Trim,Barrier,Set}`, `Dock`, `Dock/Plots` (`tools/studio/greybox/00_start.luau:14-30`) | `RideService.luau:205,1176,1456,1528`, `PropService.luau:69`, `AquariumService.luau:1092`, `SubService.luau:129`, `TrainService.luau:503,523`, and client: `RideController.luau:820,1058`, `Course.luau:78,194`, `Lock.luau:86`, `TankPanel.luau:204`, `SubPanel.luau:273`, `UpgradeSign.luau:609`, `HubSigns.luau:17`, `FailController.luau:1411,1509` and others | Every lookup is a `FindFirstChild` with a nil check, so nothing errors. But there is no floor, walls, hub or tanks: nothing to play on. |
| `ClaudeBlockout.Dive`, carrying a `Path` attribute (JSON centreline, `00_start.luau:28-29`) and one child per zone with a `Floor` part | `src/shared/Lane.luau:2-4`, `src/shared/Zones.luau:4-6` | Zones fall back to a built-in list (`Zones.luau:30`, `FALLBACK`). The lane falls back to straight chords between zones (`Lane.luau:3-4`). |
| The dock spawn: any BasePart named or tagged `DockSpawn`, else `Dock.Spawn` | `RideService.luau:200-210` | `dockSpawn` stays nil, and the character is not moved to the dock (`RideService.luau:910-911,1815`). |
| `Dock.Plots.PlotN`, each with `TankWater`, `Pad`, `SignBoard`, `TrainerSpot`, `TrainerRide`, `UpgradeBoard` (`tools/map/hub_kit.py:14-15`) | `AquariumService.luau:1093-1098`, `AquariumController.luau:63-66` | No plots are registered, so there are no tanks and no tank income. |
| `Dock.Stations.<Sell, Auras, Fuse, Index, Sub, Earners>`, each a Model with a `Ring` (`tools/map/hub_luau.py:9-15`) | `SubService.luau:129-135`, `StallController.luau`, `SubPanel.luau` (the files in `src/` that name `Stations`) | The sub check returns `true` when the ring is missing (`SubService.luau:134-135`). The stalls have nothing to stand on. |
| `Seabed` and `Props` folders | `src/server/Lib/Stream.luau:162,172`, `LaneSurvey.luau:75`, `PropService.luau:70-71` | The herd's water probe has no named floor (`Stream.luau:172`, `Named = false`). There are no props. |
| `Surface.WaterLayers` | `RideController.luau:822` | Made at run time by the `WaterLook` script below. Without that script, it is absent. |

**Game code that lives only in the map, not in `src/`:**
- The `WaterLook` client Script is inserted by `tools/studio/greybox/98_water.luau:19-21` (`RunContext = Client`), from
  `tools/map/water_look.luau` through `tools/map/water_luau.py`.
- The `HubLife` client Script is inserted by `tools/studio/greybox/97_hub.luau:405-408`, from `tools/map/hub_luau.py`.

Neither is synced by Rojo. Both are rebuilt only by the map loader.

**Place settings the game relies on, set by scripts and not by `src/`:**
- `workspace.FallenPartsDestroyHeight = -20000`, commented "only Studio can set this" (`00_start.luau:9`).
- `workspace.StreamingTargetRadius = 2400` (`00_start.luau:12`).
- The water kit model is set to `ModelStreamingMode.Persistent` (`98_water.luau:685`).
- Lighting's style is set to Realistic, which "a game script can't" set (`tools/studio/look_install.luau:1-3`,
  `docs/design/lighting.md:231-233`).

### 1b. Templates in ReplicatedStorage
| What | Needed by | If missing (read from code, not run) |
|---|---|---|
| `ReplicatedStorage.FishModels.<Id>` (82 creatures) | `src/server/Lib/FishModel.luau:2,473-480`, `src/client/UI/Portrait.luau:168` | `warn` and a "chunky" block stand-in (`FishModel.luau:499-501`, `placeholder(fish)`). |
| `ReplicatedStorage.FishVariants.Gold/Rainbow.<Id>` | `src/shared/Variants.luau:17,62,143` | The parts are tinted instead (`docs/Handoff.md:1806-1808`). |
| `ReplicatedStorage.SubMeshes.<Id>` (nine subs) | `src/shared/SubModels.luau:18,145-159` | "the old placeholder of plain parts" (`tools/subs/install.py:1-2`). |
| `ReplicatedStorage.TrainerModels.T1..T12` (seahorse levels) | `TrainService.luau:353-355,400`, `UpgradeSign.luau:305-311` | The kit's toy on a red pad (`TrainService.luau:357-365`). The sign shows an icon instead of a model (`UpgradeSign.luau:309-311`). |
| `ReplicatedStorage.Skies` (Sky objects "1 Place", "2 Anime Sky") | `LookController.luau:37-50`, `Config.luau:2830` (`Sky = 2`) | An empty list, so the chosen sky is not shown. "Studio-owned", made by hand (`lighting.md:234-236`). |

### 1c. Pictures in Studio's own content folder (only on the PC that made them)
| Path in code | Needed by | In a live game, or on another PC |
|---|---|---|
| `rbxasset://textures/ridefish/fish_icons_1..3.png` | `src/client/UI/FishIcons.luau:10-15` (`Pages = { "", "", "" }`) | The live model picture is used instead (`FishIcons.luau:8-9`). |
| `rbxasset://textures/ridefish/shop_icons_s1b.png` | `src/client/UI/Shop.luau:33-37` (`Icons = ""`) | "a live game before the upload: no header icon" (`Shop.luau:49-50`). |
| `rbxasset://ridefish/ui/archetypes/<id>.png` | `src/shared/Archetypes.luau:19-24` (`UPLOADED = {}`) | Shows only in Studio on Hugo's PC (`Archetypes.luau:19-21`). The code has no fallback for a live game, so it points at a missing file. |
| `rbxasset://textures/ridefish/land_atlas_g4.png`, `lock_atlas_k1.png` | `Kit.luau:333`, `LandStrip.luau:410` | These are Studio-only copies. The uploaded ids are used first (`Kit.luau:331`, `LandStrip.luau:409`). |
| `rbxasset://ridefish/<Id>/<Part>.mesh`, `.../submarines/...`, `.../Trainer<n>/...` | The `--local` creature templates, the subs and the trainer (`tools/creatures/local_meshes.py:1-3,23`) | "Such a place only shows its fish on this PC, and only while the files are there" (`tools/creatures/install.py:11-12`). The files are lost when Studio updates (`local_meshes.py:9-11`). |

### 1d. Sounds and engine content: nothing to supply
Every sound is an engine file shipped with the client:
- `rbxasset://sounds/action_swim.mp3`, `action_falling.ogg`, `action_jump_land.mp3`, `impact_water.mp3`
  (`src/client/Lib/Feel.luau:31-33`, `Fx.luau:17-22`, `HookController.luau:456`, `LongHookController.luau:62,67`,
  `WildController.luau:66`).

The particles are engine files (`rbxasset://textures/particles/...`, `AuraController.luau:34-40`), and so is the Robux
sign (`Shop.luau:39`).

No uploaded sound ids and no `AnimationId` were found in `src/`.

### 1e. Made by the code itself (not needed in the place)
- `Remotes` (`src/shared/Net.luau:58-63`)
- `workspace.Fish` (`FishService.luau:1824`), `LandFish` (`RideService.luau:239`)
- `TankFish` and `HeldFish` (`AquariumService.luau:333,1032`)
- The collision groups (`PropService.luau:276-277`)

### 1f. Not built at all
- **No saving.** There is no `DataStoreService` in `src/`. "For the session only: nothing is saved yet"
  (`docs/design/aquarium.md:8`, also `:255`; `SubService.luau:6`).
- **No sales.** "NONE IS ON SALE YET ... every Id is 0" (`src/shared/Products.luau:3-7`). There is no `ProcessReceipt`
  in `src/`. Only the client prompt exists (`ShopScreen.luau:124-126`).
- **The sandbox runs in Studio only.** The game starts in the sandbox there (`SandboxService.luau:41,68`,
  `docs/sandbox.md:3-4`).
- **One failing service stops the rest.** The server loader calls every `Init` unprotected
  (`src/server/Main.server.luau:17`), so one `Init` that errors stops the later `Init`s and every `Start`
  (`Start` is `task.spawn`ed, `:22`). The client loader does the same (`src/client/Main.client.luau:17`).

---

## 2. How each piece is made, and where the steps are written

| Piece | Script(s) | Source files | Steps written in |
|---|---|---|---|
| Code into the place | `rojo serve` + Rojo plugin; or `rojo build`; or `python tools/studio/sync_src.py <studio_id>` | `src/` | `docs/Working together.md:43-44,52`; `.claude/skills/studio-test/SKILL.md:15-18` |
| Map + hub + water + check (`ClaudeBlockout`, `WaterLook`, `HubLife`, settings) | `python tools/map/greybox.py`, then `python tools/map/greybox_luau.py`, then `python tools/studio/load_greybox.py <studio_id>` (runs the 180 files of `tools/studio/greybox/` through `run_luau.js`) | `tools/map/*.py` (hub_kit, props, water_zones...); output `art/map/greybox/parts.json` + `path.json` (both tracked); pictures in `art/map/textures.json` | `.claude/skills/map-build/SKILL.md:34-37`; `docs/design/map-method.md:193-199`; `tools/studio/load_greybox.py:1-8` |
| Hub hand placing | Carried by hand into `tools/map/hub_kit.py:943-950` (`spots`, "the user's own placing in Studio") | - | `map-build/SKILL.md:28-29` ("read the hub from the place first and carry any hand change into hub_kit.py/greybox.py") |
| Light | `node tools/studio/run_luau.js <id> tools/studio/look_install.luau` | `Config.Look` | `docs/design/lighting.md:231-233` |
| Skies folder | none (by hand in Studio) | Creator Store asset 72835926026092 | What it holds: `lighting.md:234-236`. How to build it: not written down anywhere. |
| Creature templates `FishModels` | `python tools/creatures/install.py <studio_id>` (from asset ids); `--local` for mesh files | `tools/creatures/assets.json` (82 ids). All 82 have their GLB tracked in git (each id's file in `tools/creatures/import_plan.json` `files` was checked against `git ls-files`). | `tools/creatures/install.py:1-30`; `upload.py:1-12` (plan_import -> upload -> collect -> install); `creature-look/SKILL.md:76-82` |
| Creature data modules | `python tools/creatures/collect.py` | `art/creatures/<Folder>/game/*.mesh.json` -> `src/shared/Creatures/*.json` (tracked) | `src/shared/Creatures/init.luau:2-5` |
| Creature GLBs | `tools/blender/voxel_kit.py <voxel.py> <out> --export <folder>` (Blender 5.2) | `art/creatures/<Name>/voxel.py` | `creature-look/SKILL.md:26-28,76-78` |
| Variant meshes `FishVariants` | `install.py runner --local` only | same GLBs | `install.py:5-12` |
| Subs `SubMeshes` | `python tools/subs/install.py <studio_id>` (local meshes only) | `art/subs/<Id>/<Id>.glb` (13 GLBs tracked) from `tools/blender/sub_stages.py --export` | `tools/subs/install.py:1-13`. Upload route: "upload each GLB as the creatures' were ... write the ids to tools/subs/assets.json" (`:10-13`). No script does it. |
| Trainer `TrainerModels` | `art/creatures/Seahorse/tiers/build_tiers.py --export`, then `install_tiers.py [runner|<studio_id>]` (local meshes only) | `art/creatures/Seahorse/tiers/` (65 files tracked, 12 GLBs) | `install_tiers.py:1-16` ("A published game needs real uploads ... not done", `:15-16`) |
| Fish icon pages | `tools/ui/export_portraits.py` -> `tools/ui/fish_icons/cut.py [--studio]` | `art/ui/fish_icons/renders` (80 tracked), pages `docs/attachments/fish-icons/fish_icons_1..3.png` | `cut.py:15-18`; `art/ui/fish_icons/README.md` |
| Land atlas / lock atlas | `tools/ui/land_icons/atlas.py [--studio] [--gen 4]`, `tools/ui/lock_icon/lock_art.py [--studio]` | `docs/attachments/land-icons/`, `art/ui/icons/lock_atlas.png` | Script docstrings (`atlas.py:1-8`, `lock_art.py:8-14`) |
| Archetype badges | `art/ui/archetypes/cut_icons.py [--install]` | `art/ui/archetypes/*.png` (tracked) | `cut_icons.py:6-10` |
| Map stud picture | `tools/art/map_tile3.py [studs.dds]` (reads the engine's `studs.dds` from `%LOCALAPPDATA%`, `:32`) | `art/style/map_tiles/roblox/tile3.png` | `map-build/SKILL.md:30-33` |

**Written down versus only in scripts:**
- **There is no single written path from an empty place.** The pieces are in the skills, design notes and script
  docstrings above. The order (code, then map, then light, then templates, then pictures) is not written down anywhere
  as one list. It comes from those sources.
- **None of the Studio steps runs from this repo alone.**
  - `tools/studio/run_luau.js:4,33` (used by `load_greybox.py`, `look_install`, every `install.py` on Windows) calls
    `C:/Users/blast/RpgGame/tools/studio/studio_mcp.py`.
  - So do `sync_src.py` (through `run_luau.js`), `tools/creatures/upload.py:23`, `upload_recolour.py:18`,
    `tools/ui/export_portraits.py:19` and `herd_stream_test.py:216`.
  - On Linux they call `~/Projects/studio-runner/studio-run.mjs` (`run_luau.js:5-7,13-17`, `STUDIO_RUNNER` overrides).
  - **Neither file is in this repo.** `studio_mcp.py` exists on this PC at
    `C:\Users\blast\RpgGame\tools\studio\studio_mcp.py` and starts `%LOCALAPPDATA%\Roblox\mcp.bat`
    (`RpgGame/tools/studio/studio_mcp.py:1-9`). How to get or install either is not written down anywhere.
- **The 15 scripted checks** (`tools/studio/*_check.py`, `hook_b3/check.py`) need Studio, Rojo serving, and the
  studio-runner plugin (for example `hold_check.py:9`, `b2_shop_check.py:4`).

**Place files:**
- No `.rbxl`, `.rbxlx`, `.rbxm` or `.rbxmx` is tracked (`git ls-files`), and none is on disk in the repo.
- `.gitignore` has no `*.rbxl` rule. None has been added, and none is ignored.
- `docs/Working together.md:53-54` says Studio-built pieces "are to be saved as `.rbxmx` model files in the repo ...
  This gets set up when the first Studio-built piece needs sharing." That set-up was not found.
- The latest place known from the notes is on Hugo's PC: `~/Documents/RideAFish/ride-a-fish-map.rbxl`
  (`docs/blockout.md:166`; `docs/Handoff.md:1184-1187`, with copies in `~/Projects/sharedDH-local/`).
- The user's PC's place has had changes left unsaved: "Not saved" in the W32 hub note (`docs/Sessions.md`, top notes,
  2026-11-22). The old hub is kept as `ServerStorage.DockBackup_2026-11-22` inside that place.
- A place id or a published game for Ride a Fish: not found.

---

## 3. What must be installed

**`rokit.toml`:**
| Tool | Version |
|---|---|
| rojo | rojo-rbx/rojo@7.7.0 |
| StyLua | JohnnyMorganz/StyLua@2.5.2 |
| selene | Kampfkarren/selene@0.31.0 |
| wally | UpliftGames/wally@0.3.2 |

Wally is listed, but there is no `wally.toml`. `Packages/` is gitignored, and `src/` requires no `Packages`. Config:
`selene.toml` (`std = "roblox"`), `stylua.toml` (120 columns, tabs).

**Python third-party packages**, from imports across 344 tracked `.py` files:
| Package | Import lines |
|---|---|
| Pillow (`PIL`) | 107 |
| numpy | 25 |
| opencv-python (`cv2`) | 15 |
| scipy | 2 |
| faster-whisper | 2 |
| youtube-transcript-api | 1 |
| imageio-ffmpeg | 1 |
| yt-dlp | run as `python -m yt_dlp`, `tools/sources/yt.py:36` |

`bpy`, `bmesh` and `mathutils` (14, 13 and 15 import lines) come with Blender, and run only inside it.

**Other software:**
- **Blender 5.2.** `docs/Working together.md:45`; hard-coded `C:\Program Files\Blender Foundation\Blender 5.2\blender.exe`
  in `art/creatures/build.py:19`, `tools/art/rarity_ladder.py:25`, `tools/map/hub_looks.py:12`; `BLENDER` env or PATH
  first in `art/creatures/Seahorse/tiers/build_tiers.py:27`; a glob in `tools/art/voxel_paths.py:20`.
- **Node.js** for `run_luau.js` (builtins only) and for yt-dlp (`docs/reference/research-tools.md:54`).
- **Lune 0.11** for the offline map bake (`tools/studio/bake_map.luau:3`). It is not in `rokit.toml`
  (`docs/blockout.md:156-159,167`).
- **Roblox Studio**, the Rojo plugin, and Studio's MCP server (`%LOCALAPPDATA%\Roblox\mcp.bat`).
- **Obsidian** with the Git, Dataview, Excalidraw and Kanban plugins, tracked in `.obsidian/`
  (`Working together.md:34-40`).
- Python version: not found.

**Requirements file:** not found (no `requirements*.txt`, `pyproject.toml` or `package.json`). Setup notes:
- `docs/Working together.md:42-46` (Rokit, Rojo plugin, Blender 5.2)
- `docs/reference/research-tools.md:51-54` (the pip line for the research readers)
- `tools/review/README.md:45` ("OpenCV is in the user's site-packages")
- `docs/blockout.md:162-163` (map_plot needs OpenCV and numpy)

Hugo's tools use a venv at `~/.cache/sharedDH-venv` (`tools/ui/lock_icon/lock_art.py:8`).

---

## 4. Uploaded Roblox assets, authentication, secrets, one-PC paths

**Files that record asset ids:**
| File | Count | Kind | Uploaded by |
|---|---|---|---|
| `tools/creatures/assets.json` | 82 (current) | Model assets made from each creature's GLB (MeshParts) | `tools/creatures/upload.py` (`assetType "Model"`, `:101-106`) and `upload_recolour.py` |
| `tools/creatures/assets_before_recolour.json` | 29 (superseded) | Model | same |
| `tools/creatures/assets_dark.json` | 34 (superseded) | Model | `upload.py:142-144` |
| `tools/creatures/upload_log.json`, `recolour_log.json` | logs (asset, operation id, time, bytes) | - | same |
| `tools/subs/assets.json` | 0 (`{}`) | - | none yet |
| `art/ui/icons/roblox.json` | 8 (6 in use: oxygen, cash, shop, index, lock_atlas, land_atlas_g4; 2 retired) | Image | Studio connector's `upload_image` (`docs/Sessions.md:400-401`) |
| `art/ui/tiles/roblox.json` | 1 (emboss) | Image | "by tools/ui/make_ui_tile.py" (drawn; upload route not stated) |
| `art/map/textures.json` | 5 (stud, floor, tile, tile2, tile3; tile3 in use, tile2 still in `Kit.luau:38`) | Image | "uploaded through Studio on the user's word" (`textures.json:4`) |

**Ids written straight into code:**
- `src/client/UI/Kit.luau:38-49,331`: 8 ids.
- `src/client/UI/LandStrip.luau:409`: 1 id.
- The map loader uses `tile3` (`rbxassetid://80588427262742`) 177 times.

**Third-party ids:**
- `rbxassetid://6126332496`, the water picture (`Kit.luau:39`, `tools/map/hub_luau.py`, `98_water.luau`).
- `rbxassetid://446556804`, a cube mesh (`tools/map/water_luau.py:33`).
- Creator Store sky asset 72835926026092 (`lighting.md:235`).

**Not found:** a repo script that uploads images or sounds, and any uploaded sounds or animations.

**Authentication:**
- `upload.py` and `upload_recolour.py` call Studio's own MCP tool `open_cloud_invoke` through the external
  `studio_mcp.py` (`upload.py:23,42-52`), with scopes `asset:read`, `asset:write` (`:25`).
- The creator is a hard-coded Roblox user id (`upload.py:24`, `upload_recolour.py:19`, with the comment "the user's
  Roblox account").
- So auth is Studio's signed-in session: "Studio must be open with the Assistant's MCP permissions granting asset:read
  and asset:write" (`upload.py:9-10`).
- No API key, cookie or credential variable is used.
  - `git grep -E "os\.environ|getenv|process\.env" -- tools art` finds only build and tuning switches: `BENCH`,
    `BENCH_TO`, `BLACK_HOLE_SLOW`, `BLENDER`, `DRAFTS`, `EXTRA_VIEWS`, `FOGS`, `GREYBOX_OUT`, `HUB_BENCH`, `HUB_JSON`,
    `HUB_LOOK`, `HUB_SIZE`, `HUB_TRY`, `LAND_SHOTS`, `MCP_VERSION`, `PALETTE`, `PATH`, `PROBE_*`, `PROPS2`,
    `RAD_REVIEW`, `RES`, `RESEARCH_CACHE` (`tools/sources/common.py:22`), `SKY`, `STUDIO_CONTENT`, `STUDIO_RUNNER` and
    `TRANSPARENT`.
  - None of them is a secret.
- **Ownership:** "The assets are private to the account that uploaded them (the user's ...). Another account's Studio
  gets 'Requester does not have permission for Asset' ... the game shows its block stand-in"
  (`tools/creatures/install.py:14-17`).
- "a published game needs real assets that belong to the publishing account or to a group. Recommended: one Roblox
  group ..." (`docs/Handoff.md:1795-1797`). That group: not found.
- "Uploads come from the account that owns the game" (`Working together.md:56-57`).

**Secrets scan:**
- Ran `git grep -nIE "(api[_-]?key|x-api-key|ROBLOSECURITY|Bearer |token\s*=|password)"` over **tracked files in the
  working tree only**, not git history and not untracked files.
- Hits are variable names only: `local token = ...` in `RideService.luau:774,947,1049,1231,1957,2080`,
  `FishService.luau:1310`, `AquariumService.luau:288`, `EquipController.luau:130`, `tools/studio/x1_fix_check.py:199,
  383,456,462`, and minified code in `.obsidian/plugins/*/main.js` and `obsidian-git/styles.css:666-674`.
  **No key, cookie or token value found.**
- A second scan for `ghp_`, `github_pat_`, `sk-...`, `AKIA...` and the `.ROBLOSECURITY` warning prefix found nothing.
- `.obsidian/plugins/obsidian-git/data.json` holds sync settings only.

**Paths that work on one PC only:**
- **The Windows user's PC:**
  - `C:\Users\blast\RpgGame\tools\studio\studio_mcp.py` in `tools/studio/run_luau.js:4,33`,
    `tools/creatures/upload.py:23`, `upload_recolour.py:18`, `tools/ui/export_portraits.py:19`,
    `tools/studio/herd_stream_test.py:216`, `water_see_buttons.luau:7`, `.claude/skills/studio-test/SKILL.md:12`,
    `docs/Working together.md:74`.
  - `%LOCALAPPDATA%\Roblox\mcp.bat` (`tools/studio/look_shots.py:20`).
  - `%LOCALAPPDATA%\Roblox\Versions\*\...\studs.dds` (`tools/art/map_tile3.py:32`).
  - `D:\ResearchCache` (`tools/sources/common.py:19-22`, `art/ui/icons/CREDITS.md:8`).
  - `D:\program files for me\videos\` (`tools/review/README.md:31`, `rad/counter/README.md:5`, `map-build/SKILL.md:37`).
  - `C:\Users\blast\RideAFish` (`.claude/skills/handoff/SKILL.md:19`).
- **Hugo's Linux PC:**
  - `~/Projects/studio-runner/studio-run.mjs`. `studio-runner` appears 118 times in 61 tracked files, and `~/Projects`
    56 times in 31 files. Among them: `tools/creatures/install.py:173,219`,
    `tools/subs/install.py:129`, `art/creatures/Seahorse/tiers/install_tiers.py:258`, every `*_check.py` header, and
    `tools/playtest/archetypes/*.sh`.
  - `/home/hugo/...`: 17 mentions in 8 files. The fonts in `tools/ui/land_icons/icons.py:35-36`, and
    `tools/studio/movement_w1/README.md:9-66`.
  - `~/.var/app/org.vinegarhq.Vinegar/...` (`tools/ui/land_icons/atlas.py:23`).
  - `~/.cache/sharedDH-venv` (`lock_art.py:8`).
- **Studio content folder (one PC, one Studio version):** `rbxasset://textures/ridefish/...` and `rbxasset://ridefish/...`
  in `FishIcons.luau:12-14`, `Kit.luau:328,333`, `LandStrip.luau:410`, `Shop.luau:36`, `Archetypes.luau:24`, plus the
  tools that write them (`local_meshes.py:23`, `tools/subs/install.py:9`, `install_tiers.py:2`, `cut.py:17`,
  `atlas.py:7`, `lock_art.py:14`, `cut_icons.py:10`, `tools/ui/catch_show/capture.py:277`).

---

## 5. Third-party material

**What the files say was taken from elsewhere:**
- **HUD icons.** `shop.png`, `index.png` and `cash.png` come from "Free Icon Pack 3.0.1 (Basic)" by gvesster. The terms
  as written: "Free for commercial and non-commercial projects. Not to be resold, edited and resold, or claimed as our
  own. Credit @gvesster is optional" (`art/ui/icons/CREDITS.md:5`).
  - The three source PNGs are tracked: `art/ui/icons_src/pack_*_1st_outline.png`.
  - "The pack itself is not in this repo" (`CREDITS.md:8`).
  - They are uploaded (`roblox.json`) and used in `Kit.luau:43-46`.
- **The water picture,** `rbxassetid://6126332496`: "from the free pack the tutorial uses (Creator Store asset
  6127206197 ...) ... Someone else's asset: fine to use, but it could be taken down" (`docs/design/water.md:301`;
  `tools/map/water_look.luau:41`).
- **The water layer mesh,** `rbxassetid://446556804`: "a plain cube from the Creator Store ('Smooth Cube', asset
  446556868, free)" (`water.md:302`, `tools/map/water_luau.py:33`).
- **The sky.** "2 Anime Sky" is "the tutorial's (Creator Store asset 72835926026092: only its Sky was kept; it had no
  scripts)" (`lighting.md:234-236`). The video's pick is "Anime Sky" by Aschorking (`lighting.md:149`).
- **The map stud picture.** `tile3` contains "Roblox's own square stud, read from the engine's `studs.dds`"
  (`map-build/SKILL.md:30-31`, `tools/art/map_tile3.py:5,32`).
- **AI-generated pictures:**
  - **The land atlas in the game.** `rbxassetid://124258870686064` is "generated set G4"
    (`Kit.luau:316-331`): "The land pictures redrawn by OpenAI's gpt-image-2 (Hugo ... 'run through chatgpt image
    generation') ... (ElevenLabs connector, image edit ...)" (`tools/ui/land_icons/gen_sheet.py:1-3`). The source
    images are game captures (`icons.py:1-4`).
  - **Creature concepts.** The user's ChatGPT concept sheets `art/concepts/creatures/*-gpt.webp` (3 tracked) were used
    to build the Sea Turtle, Sergeant Major, Stingray and Yellow Tang (`art/creatures/SeaTurtle/spec.json:6`,
    `creature-look/SKILL.md:13-14`, `docs/style/02-creature-look.md:4`).
  - **Fish icons.** "nothing has been generated yet" (`art/ui/fish_icons/README.md:7`). A ChatGPT pack is prepared in
    the ignored `research/fish_icons_chatgpt/` (`tools/ui/chatgpt_pack.py:1-16`). The icon pages in the game today are
    renders of our own models (`FishIcons.luau:2`).
- **Fonts.** `tools/ui/land_icons/icons.py:35-36` draws text into the land pictures with `FredokaOne-Regular.ttf` (from
  the Roblox client's content folder) and `Nunito[wght].ttf` (a system font on Hugo's PC). The licence of either: not
  found. The game itself uses only Roblox's built-in `Enum.Font` faces: GothamBlack, LuckiestGuy, Bangers,
  GothamMedium, GothamBold, DenkOne and FredokaOne. There is no `Font.fromId`, `FontFace` or font file in `src/`.
- **Not found:** "toolbox" or "free model" use in the game. The 3 + 2 files that mention them are research notes:
  `docs/design/cosmic.md:42`, `lighting.md:149`, `docs/reference/look-lighting.md`, `creators-and-trending.md`,
  `look-assets.md:473-474`. The one "licen" hit is a table of open-source repos' licences
  (`docs/reference/roblox-repos.md`). No third-party sounds (all sounds are engine files, section 1d). No downloaded
  textures other than the above.

**Material from the reference game, Ride a Dino** (listed, not judged):
- **Notes (tracked):**
  - `docs/reference/ride-a-dino.md`, `ride-a-dino-deep.md`, `ride-a-dino-map.md`, plus the other study notes in
    `docs/reference/`.
  - `ride-a-dino.md:5`: "The recording and frames are private, in `research/ride-a-dino/` (gitignored)".
  - Three tracked docs link 34 images into the ignored `research/` (`docs/design/ui.md`, `ride-a-dino.md`,
    `ride-a-dino-map.md`). The links break in a clone.
- **Analysis code (tracked):** `tools/review/rad/` has 22 Python scripts, plus `rad/counter/` (6 files, including a
  README). They read the user's recordings, which are kept out of the repo (`tools/review/README.md:30-31`).
  `tools/balance/rad_economy.py` is untracked.
- **Tracked images that may show the reference.** This is by filename and by the line that embeds them, matched on
  whole words. None was opened.
  - Named after the reference: `docs/attachments/colour-ride-a-dino.jpg`, `map-hub-dino-studio.jpg`,
    `map-hub-look-dino.jpg`, `shop-aura-vs-ref.jpg`, `shop-kit-vs-ref.jpg`, `shop-sub-vs-ref.jpg`, `tank-vs-ref.jpg`,
    `upgrade-sign-vs-ref.jpg`.
  - Embedded on a line that names the reference: `docs/reference/look-assets.md:614,618,626,636`
    (`map-hub-models-spawn.jpg`, `map-hub-models-over.jpg`, `map-hub-clam.jpg`, `map-hub-seahorse.jpg`),
    `docs/design/map-structure.md:339` (`map-hub-look-dino.jpg`), and `docs/design/hub-review-2.md:32,44`
    (`hub-scale-plans.png`, `hub-pens-three.png`: our plans set against the reference's).
- **The ignored `research/` folder** holds `ride-a-dino/`, `steal-an-egg/`, `water-tutorial/` and
  `fish_icons_chatgpt/`. It is 233 MB on disk, with **0 files tracked** (`git ls-files research`).
- **The ChatGPT style sheet.** "its style sheet is the reference game's art" (`art/ui/fish_icons/README.md:49-50`), in
  the ignored folder.
- **Rule on copying.** "copy Ride a Dino's loop, feel and layout, never its look or models"
  (`docs/Working together.md:28`; `CLAUDE.md`; `docs/Decisions.md`, top row of 2026-11-22).

---

## 6. Personal and private material

**People and accounts in tracked files** (`git grep -o | wc -l`, so these are mentions, not lines; `.obsidian/plugins`
left out):
| Item | Mentions | Files | Where |
|---|---|---|---|
| "Hugo" (the partner) | 1,094 | 139 | 277 in `src/` (56 files, code comments), 38 in `tools/` (29 files), 766 in `docs/` |
| lowercase "hugo" (paths) | 22 | 10 | - |
| "the user" | 1,754 | 392 | 172 in `src/` |
| GitHub account `asdas87878` | 3 | 3 | `CLAUDE.md`, `docs/Decisions.md`, `docs/Working together.md` |
| Repo name `sharedDH` | 21 | 12 | - |
| The owner's Roblox user id | 5 | 5 | `tools/creatures/install.py`, `upload.py`, `upload_recolour.py`, `docs/Handoff.md`, `docs/Sessions.md` |
| Windows user folder `C:\Users\blast` / `C:/Users/blast` | 11 + 4 | 10 + 4 | - |

**Other personal details:**
- The owner's PC specs and failing drive: `docs/Working together.md:76-78`.
- A personal budget figure: `docs/Decisions.md:103`.

**Git history:**
- 322 commits since 2026-11-09, by two author names, "Hugo" (216) and "blastmanv2" (106), with an email address on
  each.
- 157 auto-commits name the PC's hostname ("vault sync from 8570-F43F": 58, "from void": 99).

**`claude://` links (open only in the Claude app on the PC that ran the chat):** 11, all in `docs/Sessions.md`, on
lines 11-15 (the "Who has what" table) and 1653 and 1696.

**AI workspace files:**
- `CLAUDE.md` (46 lines)
- `.claude/`: 11 files: 4 agents, 6 skills, `settings.json`
- `docs/AI setup.md` (78 lines)
- `docs/Sessions.md` (1,781 lines, 189 KB)
- `docs/Handoff.md` (2,774 lines, 263 KB)
- `docs/handoffs/` (1 tracked, 4 untracked)
- The `.tmp_*` ignore rule

**Diary-style notes rather than documentation:**
- `docs/Sessions.md` (chat log and messages between chats)
- `docs/Handoff.md` (per-push log)
- `docs/Decisions.md` (277 lines, 141 KB: a dated log of the owners' decisions, with quotes)
- `docs/Inbox.md`
- `docs/playtests/*.log`
- The many `docs/attachments/` working pictures

**Stray folder:** `--help/` at the root holds 81 tracked files (21.8 MB): rarity-ladder specs and renders. It was added
in commit `a399c68` (2026-11-10, an auto "vault sync"), apparently from a script run with `--help` taken as an output
folder (`tools/art/rarity_ladder.py`).

**Tracked files by top folder** (sizes from the working tree):
| Folder | Files | Size |
|---|---|---|
| `docs` | 1,149 | 725.4 MB (`docs/attachments` alone: 1,033 files, 694 MB on disk) |
| `art` | 1,213 | 249.3 MB |
| `--help` | 81 | 21.8 MB |
| `tools` | 485 | 17.3 MB |
| `.obsidian` | 18 | 9.7 MB |
| `src` | 178 | 2.5 MB |
| `.claude` | 11 | <0.1 MB |
| root files | 8 | <0.1 MB |
| **Total** | **3,143** | **1,026 MB** |

`git count-objects -vH`: `size-pack: 650.29 MiB` in 6 packs, loose `size: 562.49 MiB` (7,221 loose objects). There is no
Git LFS (`.gitattributes` holds only `* text=auto eol=lf`).

---

## 7. Checks a team can run

| Check | Command | Result here |
|---|---|---|
| Format | `stylua --check src` (StyLua 2.5.2) | **Pass**: exit 0, no diffs |
| Lint | `selene src` (selene 0.31.0) | **0 errors, 3 warnings, 0 parse errors, exit code 1**. All three are `shadowing`: `PropController.luau:492:51` and `:559:10` (`velocity`), `FishService.luau:1777:69` (`count`). The Handoff entries call them "the three old warnings". |
| Build | `rojo build default.project.json -o %TEMP%\rideafish_build.rbxlx` (Rojo 7.7.0) | **Pass**: exit 0, a 2.58 MB file. It holds the code only: no map, no templates. |
| Scripted Studio checks | 15: `tools/studio/{b1_inventory,b2_shop,b4_tank_ride,b5_fail_text,c1_tank_hotbar,e2_click,e3_equip,e4_land,held_sub,hold,s2_subs,sub_titles,tank_panel,x1_fix}_check.py`, `hook_b3/check.py`; also `herd_stream_test.py`, `tools/playtest/archetypes/`, `tools/review/*.luau` | Not run (no Studio in this audit). Each needs a running Studio, a loaded map, and the external `studio_mcp.py` or studio-runner. Most say `install / run / remove` with Play started by hand or the runner in between (`b2_shop_check.py:1-9`). |

**One command:** not found. There is no CI (`.github/` is absent), no test runner (TestEZ or similar is not found), and
no script that runs StyLua, selene and Rojo together. The three can be run one after the other as above. Nothing in
`src/` is unit-tested.

---

## From a fresh clone to a playable place

The steps as best the files support them, in order.

1. **Clone the repo; set the git name and email.** Written down in `docs/Working together.md:33-35`. Note: the GitHub
   repo is 20 commits behind this PC, and untracked work is not in it (see the top).
2. **Install Rokit; run `rokit install`** (Rojo 7.7.0, StyLua, selene, wally). Written down in
   `docs/Working together.md:43-44`.
3. **Install Roblox Studio and the Rojo plugin.** Written down in `docs/Working together.md:43-44` (plugin named, no
   version).
4. **Install Python with Pillow, numpy, opencv-python (and scipy), Node.js and Blender 5.2.** Only Blender is written
   down (`docs/Working together.md:45`). The Python packages for the game pipeline are not written down anywhere. The
   research readers' pip line is in `docs/reference/research-tools.md:53-54`.
5. **Get a way for scripts to reach Studio.** On Windows that is `studio_mcp.py`, a copy outside this repo at
   `C:\Users\blast\RpgGame\tools\studio\`, which starts `%LOCALAPPDATA%\Roblox\mcp.bat`. On Linux it is
   `~/Projects/studio-runner`. The paths are written down (`.claude/skills/studio-test/SKILL.md:11-12,28`,
   `tools/studio/run_luau.js:4-7`). How to get or install either is not written down anywhere, and neither is in the
   repo. The hard-coded paths in `run_luau.js:33` and the upload scripts need editing on any other PC.
6. **Open a new, empty place in Studio.** Not written down anywhere.
7. **Put the code in:** `rojo serve` and connect the plugin, or `python tools/studio/sync_src.py <studio_id>`, or
   `rojo build -o x.rbxl` and open it. Written down in `docs/Working together.md:52`,
   `.claude/skills/studio-test/SKILL.md:15-18` and `docs/Handoff.md:2769`.
8. **Build the map, hub and water:**
   - Optionally regenerate with `python tools/map/greybox.py` and then `python tools/map/greybox_luau.py`. The outputs
     (`art/map/greybox/parts.json`, `path.json`, `tools/studio/greybox/*.luau`) are already tracked.
   - Then load with `python tools/studio/load_greybox.py <studio_id>`, in Edit mode.
   - This builds `Workspace.ClaudeBlockout`, the `WaterLook` and `HubLife` client scripts, and the workspace settings.
   - Written down in `.claude/skills/map-build/SKILL.md:34-37`, `docs/design/map-method.md:193-199` and
     `tools/studio/load_greybox.py:1-8`.
   - The hub's hand placing comes from `tools/map/hub_kit.py:943-950` as last carried over. Any newer hand placing in
     the owners' places is lost.
9. **Light:** `node tools/studio/run_luau.js <studio_id> tools/studio/look_install.luau`. Written down in
   `docs/design/lighting.md:231-233`.
10. **Skies:** make `ReplicatedStorage.Skies` with "1 Place" (the place's own sky) and "2 Anime Sky" (Creator Store
    asset 72835926026092). What it holds is written down in `docs/design/lighting.md:234-236`. How to build it step by
    step is not written down anywhere.
11. **Creatures:** `python tools/creatures/install.py <studio_id>` makes `ReplicatedStorage.FishModels` from the 82 ids
    in `tools/creatures/assets.json`. Written down in `tools/creatures/install.py:1-30`. All 82 source GLBs are
    tracked. It works only for an account
    allowed to load the owner's private assets (`install.py:14-17`).
    - **Another account** must upload its own: `python tools/creatures/plan_import.py`, then `upload.py <studio_id>`,
      then `collect.py`, then `install.py`. Written down in `tools/creatures/upload.py:1-12`. The uploader's creator id
      is hard-coded (`upload.py:24`).
    - Or use `install.py --local` (this PC only, no variants elsewhere). Written down in `install.py:5-12`.
12. **Subs:** `python tools/subs/install.py <studio_id>` (local mesh files, this PC only). Written down in
    `tools/subs/install.py:1-13`. For a published game, an upload plus `tools/subs/assets.json` is written down there
    as an instruction (`:10-13`). No script does it.
13. **Seahorse trainer:** `build_tiers.py --export`, then `python art/creatures/Seahorse/tiers/install_tiers.py
    <studio_id>` (local mesh files only). Written down in `install_tiers.py:14-16`. Uploading for a published game is
    "not done" (`:15-16`) and its steps are not written down anywhere.
14. **UI pictures for Studio:** `tools/ui/fish_icons/cut.py --studio`, `tools/ui/land_icons/atlas.py --gen 4 --studio`,
    `tools/ui/lock_icon/lock_art.py --studio`, `art/ui/archetypes/cut_icons.py --install`. Written down in each
    script's docstring. For a live game, upload the pictures and fill in `FishIcons.Pages`, `Shop.Textures.Icons` and
    `Archetypes.UPLOADED`: written down as code comments (`FishIcons.luau:8-9`, `Shop.luau:33`,
    `Archetypes.luau:19-21`). No script does it.
15. **Check the herd on the new map:** `python tools/studio/herd_stream_test.py <studio_id> Edit`. Written down in
    `.claude/skills/game-code/SKILL.md:14-15`.
16. **Play.** In Studio the game starts as the movement sandbox (R, F, N, V keys). Written down in `docs/sandbox.md:1-20`.
17. **Save the place as `.rbxl`.** No place file is in the repo and none is ignored. Where Hugo keeps his is written
    down in `docs/blockout.md:166` and `docs/Handoff.md:1184-1187`. A team convention is not written down anywhere.
18. **Before publishing:**
    - Saving progress is not built (`docs/design/aquarium.md:8,255`).
    - Developer products and passes are not made (`src/shared/Products.luau:3-7`, which says what to fill in).
    - The assets must belong to the publishing account or group (`docs/Handoff.md:1795-1797`).
    - A publishing checklist is not written down anywhere.
