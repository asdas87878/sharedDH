# Client code audit: Main, Controllers, Lib

Scope: `src/client/Main.client.luau`, the 30 files in `src/client/Controllers/`, the 11 in `src/client/Lib/` (about
20,200 lines). Nothing was changed for this report; the only edits in the area are the added section markers in
AnimController, RideController, JumpController and SandboxController (comments only).

How it was read: Main, State, Actions, Net, and the four big controllers (Anim, Ride, Jump, Sandbox) were read line by
line. The other 26 controllers were read in full in two helper passes; specific claims from those passes that matter
below were checked again by grep. Lib modules were read from their headers, their requires and their exported
functions, plus greps for costly calls. Every "uncalled" claim was checked by finding the name each file in `src/` and
`tools/` gives the module when it requires it, then grepping `<name>.<function>` for each, comment lines left out. Line numbers are as of this read (after the markers were added).

## (a) Code map

### How it boots

`Main.client.luau` requires every ModuleScript in `Controllers/`, calls `Init` on all of them, then `task.spawn(Start)`
for each. So every file in `Controllers/` runs in every game, live servers included; a file that should be Studio-only
has to return early itself. There is no `pcall`: an error in any `Init` stops every later `Init` and every `Start`.

### Shared pieces in Lib

| File | What it does | Requires | Server contract |
|---|---|---|---|
| State | One shared table: Mode (mirrors the server's `State` attribute; the client runs ahead into "Jumping"), the ridden fish, the lock, reel and tame numbers, and six BindableEvents (ModeChanged, Fitted, Touched, Tamed, Launched, Leapt). | Config, Zones | reads fish `FishType`, `Rider`, `Reserved`; player `MaxOxygen` |
| Actions | One stub, `Actions.jump`, filled in by JumpController so Input and HUD can press jump without requiring it. | none | none |
| Course | Keeps the client-moved fish and the hop out of walls and floors: raycasts plus the lane's centreline. | Config, Lane, Net, Zones, State | reads `LanePath`; the map under `Workspace.ClaudeBlockout` |
| WallRide | Bends the way we go along a wall instead of hitting it; the swing when steered straight in. | Config, Ease, Course | none |
| Lock | Picks the fish a grab would take (cone, distance, sticky lock, line of sight). | Config, FeelLog, State | scans `workspace.Fish`; reads `FishType`; `ClaudeBlockout` |
| Feel | Speed lines, bubble trail and the hop's sounds. | Config | none |
| Fx | Local landing ring, bubble bursts, mouth bubbles, placeholder sounds. | Config | none (called on `Fx` remote events) |
| Shake | Many camera shakes added together, by the clock. | Config | none |
| Spring | Critically damped spring for the camera. | none | none |
| FeelLog | The feel log's event notebook; does nothing unless the log is on (Studio). | none | none |
| BlackHole | A voxel black hole that bends its own cubes by the viewer. | none | none |

### Controllers

Remotes are those in `src/shared/Net.luau` unless named. "Fires" = client to server, "Hears" = server to client.

| File | What it does (25 words or fewer) | Requires (main) | Remotes | Attributes and tags read |
|---|---|---|---|---|
| AdminController | Playtest admin panel on P, built only when the server marks the player `Admin`; every button asks the server. | Config, Net, State, UI.Kit | fires/hears its own `Net.Folder.Admin` remote (not in Net.luau) | `Admin`, `AdminEndlessAir`, `AdminNoFail`, `MaxOxygen` |
| AngryController | Red Highlight pulse on every angry fish, faster as its rider's Oxygen runs out. | AngryStyles, Config, Ease, Net | hears Ride `OxygenTick` | tag `AngryFish`; `Angry`, `FishType`, `Rider`, `Oxygen`, `MaxOxygen`, `Strained` |
| AnimController | Moves every fish's joints (swim, land walk, buck) and every rider's pose, each frame. | Config, Creatures, RideStyles, State, JumpController, RideController | hears Fx `Land` | `Rig`, `FishType`, `Rider`, `Tier`, `LandRider`, `LandEpoch`, `LandMounted`, `State`, `TankRide`, `SubPhase`; Studio-only workspace `LandClock`, `LandMove` |
| AquariumController | Swims the dock tanks' fish locally; the caught slots and the deposit moment. | Config, Net, State, UI Slots/TankPanel/TankPrompt | fires Action `Hold`; hears Ride `Deposited` | tag `TankFish`; `TankCentre`, `TankReach`, `TankPhase`, `TankPace`, `HeldFish`, `HeldIndex`, `Plot` |
| ArchetypeController | Plays the server-decided archetype moments (sounds, shakes, words). | Archetypes, Config, Net, Fx, State, RideController | hears Ride `Boost`, Fx `Eat`, `Smash` | `Tier` |
| ArriveController | Fades in a fish that appears in sight. | none | none | `workspace.Fish` children |
| AuraController | Draws every player's aura from `Aura` (1 to 12) and the spawn-in. Draft, not sold yet. | Auras, Shop, UI AuraShop, SellFish | none (AuraShop fires `AuraBuy`) | tag `AuraRig`; `Aura`, `AuraClock`, `AuraSlow`, `SpawnAt`, `SpawnStyle` |
| BlackHoleDisplayController | Puts a live Lib/BlackHole on every part tagged `BlackHole`. | Lib/BlackHole | none | tag `BlackHole`; part attrs `Scale`, `Voxel`, `Quality`, `Jets`, `AutoFeed` |
| DeathController | The drowning, seen by everyone; the victim's camera, dark and fade. | Config, Course, Fx, Shake, State | hears Fx `ThrowOff` | `State`, `DeathAt`, `DeathClock`, `DeathLoose`, `DeathQuick`, `DeathThrown` |
| EquipController | Number keys and Q for the hotbar and the ride slot. | Config, Net, FeelLog, State, UI Slots | fires Action `RideEquip`, `RideMount`, `RideUnequip` | `EquippedFish`, `HeldFish`, `LandMounted`, `State` |
| FailController | What a fish does at 0 Oxygen (bite, throw, swallow), the ragdoll, the fail words, the death camera. | Config, Creatures, Course, Fx, Shake, State, UI.Kit, AnimController | hears Fx `Fail`, `Ragdoll` | `FailAt`, `FailClock`, `FailWords*`, `Ragdoll`, `DeathClock`, `DeathThrown`, `Rig`, `State`, `FishType` |
| FeelLogController | Studio-only recorder of how a hop felt; writes the log. | Config, FeelLog, Lock, State | none | `FishType` |
| GroundFxController | Small land effects: the trainer hop-off puff, landing rings. | Config, UI.Kit | none | `TrainerClock` |
| HoldController | Arms up for every player holding a fish over their head on the dock. | Config, Ease | none | `HeldFish`, `LandMounted`, `State`, `TankRide`, `TrainerRide` |
| HookController | The rope from hand to fish in every hop (Verlet rope). | Config, Ease, Fx, State, JumpController | none | `FishType` |
| HudController | Builds the dive and dock HUD screens and feeds them each frame. | Config, Net, Zones, Actions, State, 13 UI modules | hears Ride `OxygenTick` | `Coins`, `Oxygen`, `MaxOxygen`, `Drain`, `StrainSeconds`, `SizeTier`, `Variant`, `DeathQuick`, `Sandbox`, `SandboxEndlessAir`, `HudTouch` |
| InputController | One jump button for PC, pad and touch; grab keys in the hop. | Config, Actions, State | none | none |
| JumpController | The hop: lock-on, grab, pull-in, landing, miss, the sub's fling, slow-mo. | Config, Net, Actions, Course, Feel, FeelLog, Fx, Lock, Shake, State, WallRide, RideController | fires Action `Jump`, `Grab`, `CancelGrab`, `Land`, `Miss`; hears Ride `Mounted`, `Denied`, `Dismounted`, Fx `Land` | `Rider`, `Reserved`, `FishType`, `Tier`; `Net.Folder` `Dock`; workspace `SandboxEndlessAir` |
| LongHookController | Extra camera, sound and word when the hook reaches far. | Config, FeelLog, Spring, State, UI.Kit, JumpController | none | none (writes camera `LongHook` for tests) |
| LookController | Keeps Lighting, bloom and sky at Config.Look, checked 4 times a second. | Config, Shared/Look | none | `LookVista`, `SkyboxBkOwn`, `SkyboxBkVista` |
| PropController | Local look of breakable props: see-through near us, broken boxes thrown and faded. | Config, Ease, Fx, RideController, State | none | tag `PropOut`; `BreakAt`, `BreakT`, `BreakVel`, `PropSize`, `FishType` |
| RideController | Steering the ridden fish (client owns it), the float, the camera, mount and leave. | AngryStyles, Config, Net, Zones, Course, Feel, Shake, Spring, State, WallRide | fires Action `SandboxSit`; hears Ride `Mounted`, `SandboxMount`, `Crashed`, `Dismounted` | player `State`, `TankRide`, `Oxygen`, `MaxOxygen`, `Strained`; fish `Rider`, `FishType`, `Angry`; `Net.Folder` `Zones`, `Dock` |
| SandboxController | Studio-only tuning panel (N) of about 790 Config numbers, side view, reset, try-out fish. | Config, Net, State, UI.Kit | fires Sandbox `Tune`, `Flag`, `Reset`, `Ride` | workspace `Sandbox`, `SandboxNoFail`, `SandboxEndlessAir` |
| ShakeController | Camera shakes nobody else asks for: strain rumble, top-speed tremble. | Config, Lib/Shake, State | none | `FishType`, `Pace`, `Rider`, `StrainSeconds` |
| StallController | Opens the dock windows when standing on their stands. | State, UI DockNotes/HubButtons/Shop/TankPanel | none | `TankRide` |
| SubController | The submarine trip on every machine; our own ride in it; its banners. | Config, Net, SubModels, SubTrip, Feel, Fx, Shake, State, UI LandStrip/SubPanel, JumpController | fires Action `SubLand`; hears Ride `SubFish`, `SubDrop` | `SubTrip`, `SubPhase`, `SubEquip`, `Rider` |
| TameController | Keeps State.Tame, State.Caught and the Tamed event from the server's word. | Config, Net, State | hears Ride `Caught`, `Tamed` | `Tame`, `Strained` |
| TankRideController | Riding a fish in our own tank, and animating every tank fish's swim. | Config, Creatures, RideStyles, State, UI.Kit, TankPanel, RideController | fires Action `TankRide`; hears Ride `TankMounted`, `TankDismounted` | tag `TankFish`; `TankRide`, `TrainerRide`, `Plot`, `Rig`, `FishType` |
| TrainerController | The seahorse trainer toy on every plot: rocking, the coil, the rider. | Config, RideStyles, UI.Kit, GroundFxController | its own `ReplicatedStorage.Remotes.Trainer` (not in Net.luau): fires `Off` | `Build`, `PartCount`, `Rider`, `SpringBase`, `SpringTop`, `TrainerClock`, `UpgradeAt` |
| WildController | The rodeo camera on a fish: sway, kicks, bumps. | Config, Ease, Feel, Fx, Shake, State, RideController | none | `FishType` (writes camera `WildFit`, `StrideSteps` for tests) |

### One dive, traced

1. On the dock the server sets the player's `State` to "Free" when they step in. RideController's
   `fromServerState` sets `State.Mode` and fires `State.ModeChanged`.
2. JumpController hears ModeChanged: Dock to Free near `Net.Folder`'s `Dock` point starts the dive-in hop on its own.
3. Each frame JumpController's render step `step` runs `hop(dt)`: the hop curve (`heightAt`, `speedAt`), Course
   and WallRide keep it out of walls, and `pick` asks `Lib/Lock.pick` for the fish a grab would take
   (`State.JumpTarget`, shown by `setGlow` and the ring).
4. Steering in the hop and on a fish is `RideController.steer` (A/D plus where the camera looks).
5. The press: InputController calls `Actions.jump`, which is JumpController's `request`. It fires Action `Grab` with
   the locked fish; the server checks the reach and answers.
6. JumpController's `startReel` pulls us in (`JumpController.reel()` is read by HookController for the rope,
   LongHookController for the far-hook camera, AnimController for the pose).
7. At the touch it fires Action `Land`; the server welds us and sends Ride `Mounted`. RideController's `onMounted`
   takes the fish (the client gets its network ownership), and its render step `drive` moves it, `cameraStep` the
   camera. AnimController poses fish and rider; WildController and ShakeController add the camera's life.
8. Pressing jump on a fish fires Action `Jump` and the next hop starts (back to 3). A miss fires Action `Miss`.
9. Taming: the server raises the player's `Tame`; TameController puts it in `State.Tame` for the HUD. When it is done
   the server sends Ride `Tamed` and `Caught`; TameController fires `State.Tamed` and fills `State.Caught`.
10. Oxygen: the server sends Ride `OxygenTick` and sets `Oxygen`; HudController and AngryController show it, and in
    the red the server marks the fish `Angry` (RideController slows it, AngryController pulses it).
11. Out of Oxygen: the server sets `FailAt` and state "Failing"; FailController plays the outcome and the fail words;
    then DeathController plays the drowning from `DeathAt`, and the server sends the player home.
12. Back on the dock (`State` "Dock"), AquariumController shows the caught slots; clicking one fires Action `Hold`
    (the fish held over the head, HoldController). Putting it in the tank is the UI's TankPanel (Action `Tank`
    `PutIn` / `PutAll`); the server's `place` (`AquariumService.luau:683`) answers with Ride `Deposited` (:700), which
    AquariumController plays. (The server also handles an Action `Place` at `AquariumService.luau:1184`; nothing in
    `src/client` fires it. Server side, not in this area.)

`Lib/State` is the glue: the server's attributes are copied into it in one place each, and every controller reads it
rather than each other. The exceptions that require another controller directly are listed in finding 5.3.

## (b) Things to sort

Risk: "safe" = can be done without changing what anyone sees; "play test" = needs a play in Studio after.

### 1. Unfinished features that ship live

1.1 **Aura shop has no server side.** `src/client/UI/AuraShop.luau:160` fires Action `"AuraBuy"`; nothing in
`src/server` handles it (grep `AuraBuy` finds only AuraShop). `AuraController.luau:2` says "DRAFT 2 ... drawn but not
bought yet", and the word `Aura` does not appear anywhere in `src/server`, so nothing there sets the `Aura` attribute. Action: hide the aura stand until the server buys,
or write the handler. Risk: play test.

1.2 **Placeholder animations and sounds.** `FailController.luau:22-23` (stand-ins for the partner's animations; sounds
from Lib/Fx), `FailController.luau:1707` (the chomp sound), `Lib/Fx.luau:3,14,25` (all sounds are pitched built-in
character sounds), `AnimController.luau:2046` (Carried poses "Placeholders"), `AnimController.luau:605,1662` and
`TankRideController.luau:232` (stand-in tail beat), `SubController.luau:3,17` (placeholder sub when no model),
`RideController.luau:478,654,678` (marked stand-in motion blocks for angry, bite or smash, wall swing),
`AquariumController.luau:13` (stand-in deposit moment). Action: list for the art pass; each has a seam ready
(`AnimController.LandHook` at :524, `AnimController.FailPose` at :70). Risk: play test when replaced.

1.3 **`AnimController.LandHook` is never set.** Declared at `AnimController.luau:524`, read at :910; nothing in
`src/` assigns it. It is the seam for authored land animations, so it is not dead, but a reader will wonder. Action:
say so in its comment. Risk: safe.

1.4 HUD best depth and "NEW" are per session only (`HudController.luau:78`, "until the game saves a best"); its header
(:9) still says coins come "when the game has them". Other players' hooks are not drawn (`HookController.luau:19`).
Risk: safe to note; play test to build.

### 2. Dev and test code in the live build

2.1 **Admin panel works on a live server for the place owner.** `AdminController.luau:2-4`: built when the server sets
`Admin`; AdminService grants it to everyone in Studio and, live, the place owner (creator or group rank 255) plus
`Config.Admin.Users` (empty). Buttons include coins and subs on the owner's real data; the server checks again on each
request. Action: decide whether a buyer wants it live; at least document it. Risk: safe to switch off live.

2.2 **Studio gating checked and correct:** SandboxController returns from `Start` unless `RunService:IsStudio()`
(`SandboxController.luau:1316`), and the server ignores the Sandbox remote outside Studio (`SandboxService.luau:41`);
Action `SandboxSit` is honoured only in Studio or for an Admin (`RideService.luau:2120`). FeelLogController's `Start`
returns outside Studio. AnimController's `LandClock`/`LandMove` reads are behind `isStudio` (:1042-1043). RideController's
angry test (:465) is behind `IsStudio`. The Studio-only files still load and run `Init` live; that is harmless.

2.3 **Test hooks shipping ungated:** `TankRideController` `aimed`, `pretend`, `pressOff`, `speeds` (and `riding`) are
used only by `tools/studio/b4_tank_ride_check.py`. `AuraController.shop` and `shopOpen` only by tools
(`b2_shop_check.py`). `AnimController.landInfo` (:1011) only by `tools/studio/e4_land_check.py` and `x1_fix_check.py`.
`EquipController.press` only by tools (`c1_tank_hotbar_check.py`, `e3_equip_check.py`, `e4_land_check.py`,
`x1_fix_check.py`); `EquipController.input` only by `x1_fix_check.py`.
WildController and LongHookController write camera attributes (`WildFit`, `StrideSteps`, `LongHook`) every ride for
tests. Action: keep, but group them under a "test hooks" heading. Risk: safe.

2.4 UI text tells the tuner to "paste them to Claude" (SandboxController panel), and its `TRY_OUT` list hard-codes
fish ids. Studio only. Risk: safe.

### 3. Uncalled or stale code (grepped across `src/` and `tools/`, comments left out)

| Where | What | Action | Risk |
|---|---|---|---|
| `RideController.luau:179` `RideController.turn` | No caller anywhere; `steer` (:231) replaced it. `JumpController.luau:11` still says A and D steer "as they steer a fish (RideController.turn)". | Remove, fix the comment. | play test (it shares `turnNow`/`turned` with steer) |
| `Lib/State.luau:108` `State.secondsOn` | No caller (Tags and RideService call `Config.secondsOn` directly). | Remove. | safe |
| `Lib/Shake.luau:84` `Shake.at`, `:131` `Shake.clear` | No caller in `src/` or `tools/`. | Remove or note as kept for later. | safe |
| `StallController.open` (:76) | No caller in `src/` or `tools/`. | Remove. | safe |
| `AdminController.toggle` (:347) | Only called inside the file (the `toggle` hits in tools are `TankPanel.toggle`, `SubPanel.toggle`). | Make local. | safe |
| `AuraController.spawnIn`, `RideController.coast` (:727) | Public but only called inside their own file. | Make local. | safe |
| `Lib/BlackHole` methods `SetOrigin`, `Follow`, `Feed`, `Stop` | No caller outside the module (the display uses only `new`, `Start`, `Destroy`). | Keep as the module's API; note it. | safe |
| `FailController.luau:1294-1370` | Dead branch: `SHADE_ARMS = 0` switches it off. | Remove. | safe |
| `FailController` Def field `Hook` (:41) | Never read. | Remove or wire. | safe |
| `Lib/BlackHole.luau:4` | Says "Nothing requires this module yet", but BlackHoleDisplayController requires it. Nothing in `src/` tags a part `BlackHole` (only `tools/studio/black_hole_edit_preview.luau`); whether the place has one was not checked. | Fix the comment; confirm the tag in the place. | safe |
| `FeelLogController.luau:559` | `local _ = gui`. | Remove. | safe |
| `GroundFxController.ring` (:193) | Public but used only inside the file (TrainerController, which requires it as `GroundFx`, calls only `hopOff`). | Make local. | safe |

HookController and LongHookController are both live and do different jobs (rope every hop; extra camera only on a far
hook). Neither supersedes the other; the names suggest they might.

### 4. Things that cost on phones (per-frame work)

4.1 **FailController's view** during a fail or drowning: up to 7 raycasts with a new `RaycastParams` each frame
(`propsInWay`), 6 spherecasts, and a scan of `workspace.Fish` per frame (around `viewStep`/`clearView`). Action: reuse
one params object, cache the fish list. Risk: play test.

4.2 **GetDescendants every frame:** `ArriveController.luau:19` (per arriving fish), `AuraController.luau:924` (during a
spawn-in), `TrainerController.luau:244` `spreadLegs` (every frame for a seated rider when no hips are found). Action:
cache the part list once. Risk: play test.

4.3 **New objects every frame:** `AuraController.luau:366-375` (four `Random.new`), :651 (a new ColorSequence),
:961-983 (tables); `GroundFxController.luau:243` (a new filter table and a raycast per nearby player); AnimController
allocates pose tables per rider per frame. Action: reuse. Risk: play test.

4.4 **AnimController's per-frame loop** moves the joints of every fish within 450 studs and every player, in one
function `animateFish` (`AnimController.luau:1035`, about 680 lines). Mid-range phones were not measured. Action:
profile on a phone before launch; consider a lower rate for far fish. Risk: play test.

4.5 Also every frame: HookController's rope (up to 40 segments times 12 passes), TankRideController animating every tank
fish in sight, TrainerController's step for every plot, SubController's raycast, Lib/Lock's line-of-sight ray per
candidate fish. Each is bounded; none measured.

### 5. Structure and names

5.1 **Very large files doing several jobs:** AnimController (2,330 lines), FailController (2,326: outcomes, ragdoll,
fail words UI, death view, Studio record and replay), RideController (1,421), JumpController (1,376: `request` and
`fling` repeat much of the hop set-up), SandboxController (1,348, of which about 790 lines are the number list),
TankRideController (riding, and animating every tank fish at :72-255). Action: split along the new section markers when
there is time. Risk: play test.

5.2 **Duplicated helpers:** `flat` (Death:53, Fail:175, Sub:79), `rootOf` (Death:58, Fail:170, Aura:835), `new`/`edge`
(Admin:44,55 copy Sandbox's), `yawOf` (Sub:84, Jump:175), `anglesOf` (TankRide:67, Ride:369), `joint` (Hold:41,
TankRide:96, Anim), `clock` (GroundFx:25, Trainer:66), number-key maps (Equip:25, FeelLog:35), fade loops (Arrive:18,
Aura:924, Fail:1547), three banner makers (Sub:222, Trainer:635, TankRide:517). Action: one small Lib/Util. Risk: safe
if done carefully.

5.3 **Controllers that require other controllers** (so load order and cycles matter): Anim needs Jump and Ride; Fail
needs Anim; Hook, LongHook and Sub need Jump; Archetype, Prop, TankRide and Wild need Ride; Trainer needs GroundFx.
FailController also writes into AnimController (`AnimController.FailPose = ...` at `FailController.luau:2300`).
Action: document; fine for now. Risk: safe.

5.4 **The map's name is hard-coded:** `workspace:FindFirstChild("ClaudeBlockout")` in 14 places across 10 client files
(Aquarium:62, Fail:1411,1509, Prop:141, Ride:859,1097, Stall:36, Sub:437, TankRide:274, Trainer:94, Course:78,194,
Lock:86), plus the server and `Shared/Zones`. Action: one constant in Shared, and a name a buyer understands. Risk:
play test (one rename across client, server and the place).

5.5 **Remotes outside Net.luau:** AdminController uses `Net.Folder.Admin`, TrainerController
`ReplicatedStorage.Remotes.Trainer`. Net.luau's header list is out of date (no `Hold`, `Tank`, `RideEquip`, `RideMount`,
`RideUnequip`, `AuraBuy`, `TankRide`, `SubBuy`..., Ride `TankMounted`, `TankDismounted`, Fx `Ragdoll`, state "Failing", nor attributes such as `HeldFish`,
`EquippedFish`, `LandMounted`, `FailAt`, `StrainSeconds`, `TankRide`, `TrainerRide`). Action: bring the header up to
date; it is the server contract. Risk: safe.

5.6 **`SubController.Init` yields:** `SubController.luau:635` `State.Player:WaitForChild("PlayerGui")` inside `Init`,
against the no-yield rule; since Main has no `pcall` and runs `Init` in a row, a slow PlayerGui holds up every later
controller's `Init`. Action: move to `Start`. Risk: play test.

5.7 **Main has no error guard:** one failing `Init` stops every later `Init` and all `Start`s
(`Main.client.luau:15-19`). Action: wrap each call in `pcall` with a warn. Risk: safe.

5.8 Comments carry task ids and review numbers ("task e4", "grade issue 7", "task e1" in `Lib/State.luau:106`) and
people's names and dates. A buyer will not have the notes they point to. Risk: safe to leave; worth a pass later.

5.9 Open decision left in code: `EquipController.luau:122` ("choice F"). Constants that belong in Config:
ArriveController `NEAR`, `TIME`. Wrong folder: none found.

### 6. Client deciding server things

None found. Coins, taming, Oxygen, fails and deaths are all decided by the server; the client shows them. The client
does steer the fish it rides and the tank fish (network ownership). The server checks ride speed against
`Config.Ride.SpeedSlack` (`RideService.luau:1128,1623`) and the hook's reach by the hop's speed (`RideService.luau:1178`,
`Config.reachOf` times `Net.RangeSlack`), and clamps a tank fish into its tank (`TankRideService.luau:195,270`). How
well those checks hold against a cheating client was not checked.
`SandboxController`'s "Pull you onto the locked fish" switch changes `Config.Jump.AutoGrab` on the client only (Studio).

### 7. Hard-coded ids and names

No `rbxassetid://` ids, user ids or user names in code in this area (only built-in `rbxasset://` sounds and textures).
Part names `RideWeld`, `TrainerWeld`, `Right Arm`, hip joint names and sub part names are matched by string; the map
name `ClaudeBlockout` (5.4); `Random.new(20261117)` seed in `Lib/BlackHole.luau:148`.

### Not checked

- Run-time cost on a real phone (nothing was profiled).
- Whether the place file has a part tagged `BlackHole`, and every template the client looks up by name.
- The UI modules in `src/client/UI/` beyond the AuraShop fire above (another person's area).
- AdminService's checking of each admin request's arguments.
- `Zones.locate` cost per frame in HudController.
- Lib modules' internal functions beyond their exports and their raycasts.
