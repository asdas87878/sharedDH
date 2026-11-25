# Code map

A way into the game code for someone who has never seen it: how it starts, who decides what, one dive followed through
the files, every file in a line, and every message the two sides send. Written 2026-11-22 from a read of all of `src/`.

Up: [Home](../Home.md). Related: [what to sort in the code](reviews/code-organisation.md),
[handing the game over](plans/sale-readiness.md), [the movement sandbox](sandbox.md).

## The shape of it
- **Three folders, synced into the place by Rojo** (`default.project.json`):
  - `src/server` becomes `ServerScriptService.Server`.
  - `src/client` becomes `StarterPlayerScripts.Client`.
  - `src/shared` becomes `ReplicatedStorage.Shared`.
- **Rojo carries the code only.** The map, the hub, the fish models and the pictures are built into the place by the
  scripts in `tools/` ([handing the game over](plans/sale-readiness.md), "From an empty place to the game").
- **How it starts.** `Main.server.luau` loads every module in `Services/`; `Main.client.luau` loads every module in
  `Controllers/`. Each calls `Init` on all of them (set up, no waiting), then `Start` on each in its own thread. A new
  module dropped in either folder runs by itself. A module that fails to load, or whose `Init` fails, is reported in
  the output with `[Main]` and left out; the rest carry on.
- **The server decides, the client shows.** Oxygen, taming, coins, what you own and how a ride ends are all worked out
  on the server. The client steers the fish it rides (the server hands it the fish's network ownership) and draws
  everything.
- **Every number is in `src/shared/Config.luau`,** in named tables (`Config.Jump`, `Config.Oxygen`...), with the sums
  made from them as functions at the end. It has a contents list at its top.
- **The big files have a contents list** ("In this file, in order:") under their header, and a marker line of dashes
  with the same title before each section. Search for a title to jump to it.
- **The words used:**
  - A **land** or **zone**: one of the ten areas going down the lane (the code says both).
  - **Oxygen**: the stamina meter. It drains while you ride and refills when you land on a new fish.
  - A **red** or **strained** fish: one that needs more Oxygen than your max; it throws you off soon.
  - The **hop**: the jump from fish to fish. The **hook**: the rope that pulls you onto the next one.
  - The **dock** or **hub**: the surface, with each player's **plot** and **tank**.
  - **Tier** means rarity for a fish, but also a submarine's or an aura's level.
  - `ClaudeBlockout`: the map's folder in `Workspace`. The name is written out in about 26 places.

## How the two sides talk
- **Remotes** (`src/shared/Net.luau`, in `ReplicatedStorage.Remotes`): `Action` (client to server), `Ride` (server to
  one client), `Fx` (server to every client), `Sandbox` (Studio only). Two more are made by their own services:
  `Admin` (AdminService) and `Trainer` (TrainService). The first argument is always the message's name.
- **Attributes** carry state that lasts: the server sets them on the player (`State`, `Oxygen`, `MaxOxygen`, `Tame`,
  `Coins`...), on fish (`FishType`, `Tier`, `Rider`, `Angry`...) and on the Remotes folder (`Zones`, `LanePath`,
  `Dock`). Clients read them and listen for changes.
- **Tags** (CollectionService) mark things many scripts look for: `Fish`, `AngryFish`, `TankFish`, `PropOut`, `AuraRig`.
- **On the client, `Lib/State` is the glue.** The server's attributes are copied into it in one place each, and the
  controllers read it and its events (`ModeChanged`, `Tamed`, `Touched`...) in place of each other.

## One dive, followed through the files
1. **Join.** `RideService` makes the rider's record and puts them on the dock (state `Dock`). `AquariumService` gives
   them the first free plot, a tank and 0 coins.
2. **Into the water.** The server sees the character drop below the water line and sets `State` to `Free`.
   `RideController` copies that into `State.Mode`; `JumpController` starts the dive-in hop. With `Config.Dive.Leap` on
   (it ships 0), running off the start strip's lip first plays the leap (`DiveController`, client only): the crouch,
   the arc, a camera film, the splash (`Lib/Splash`), then under the surface it hands the body to that same hop and the
   camera back to `RideController`. The server is not told; it sees the body go under as before.
3. **The hop.** Each frame `JumpController` moves the rider along the hop's curve; `Lib/Course` and `Lib/WallRide` keep
   them out of walls; `Lib/Lock` picks the fish a press would take, and the HUD rings it.
4. **The press.** `InputController` calls `Actions.jump`, which is `JumpController`'s. It sends `Action "Grab", fish`.
   The server (`RideService` `grab`) checks the timing, the reach and the line of sight, and keeps the fish for us.
5. **The pull-in.** `JumpController` reels us in; `HookController` draws the rope, `LongHookController` adds the camera
   for a far one, `AnimController` poses the rider.
6. **Landing.** The client sends `Action "Land", fish`. The server seats the rider, refills Oxygen, hands over the
   fish and sends `Ride "Mounted"` and `Fx "Land"`. `RideController` now steers the fish and runs the camera.
7. **Riding.** The server drains Oxygen in ticks (`Ride "OxygenTick"`), fills `Tame`, and marks the fish `Angry` when
   the meter is in its red part. `HudController` shows it; `AngryController`, `WildController` and `ShakeController`
   add the red pulse, the bucking and the shakes.
8. **Tamed.** At a full `Tame` the server adds the fish to what you carry and sends `Ride "Tamed"` and `"Caught"`.
   `TameController` passes it on; `UI/CaughtText` shows the words; `UI/Slots` shows the catch.
9. **Next fish.** Jump again (`Action "Jump"`) and it is step 3 once more. A miss sends `Action "Miss"`.
10. **Out of Oxygen.** The server picks what the fish does (`Config.failOf`) and sends `Fx "Fail"` or `"ThrowOff"`.
    `FailController` plays the outcome and the words, `DeathController` the drowning; the server sends you home.
11. **Home.** On the dock `AquariumController` shows what you caught. `UI/TankPanel` sends `Action "Tank"` to put a
    fish in; the server answers `Ride "Deposited"`. `UI/SellFish` sends `Action "Sell"`.
12. **Earning.** `AquariumService` pays `Coins += Income x time` in a loop. Coins buy plot upgrades, the trainer
    (`TrainService`, more max Oxygen) and submarines (`SubService`, a lift down to a later land).

## The server (`src/server`)
| File | What it does |
|---|---|
| `Main.server.luau` | Loads every service. |
| `Services/RideService` | Each rider's state (Dock, Free, Riding, Jumping, Drowning, Failing): the hop, the grab, mounting, Oxygen, taming, crashes, fails, and the ride fish on land. The centre of the game. |
| `Services/FishService` | The wild herd: rolls each fish, spawns it out of sight, swims it down the stream, keeps the stock up, hands fish to riders. |
| `Services/AquariumService` | Plots, tanks, coins, the income loop, selling, plot upgrades, holding a fish over the head, the way home. |
| `Services/TrainService` | The breath trainer on each plot: riding it raises max Oxygen; its levels and signs. |
| `Services/AuraService` | The auras bought and worn: order, price, place, saved; the multiplier on what the seahorse gives. |
| `Services/OfflineService` | What a tank earned while its player was away: kept in the save, claimed once ([the note](design/offline-rewards.md)). Nothing while saving is off. |
| `Services/SubService` | The submarine: buying, picking a land, carrying a diver down and dropping them on a fish. |
| `Services/TankRideService` | Riding one of your own fish round your tank. |
| `Services/PropService` | The props that break: which boxes are out, and putting a prop back when nobody is near. |
| `Services/LessonService` | A new player's first minutes ([the note](design/first-minutes.md)): the step they are on, the first-fish rule, the steps counted. Nothing with `Config.Lesson.On` 0. |
| `Services/BestService` | Each player's furthest depth this session. |
| `Services/AdminService` | The admin panel's server side (the place's owner, and anyone in Studio). |
| `Services/SandboxService` | The movement sandbox's server side. Studio only. |
| `Lib/FishModel` | Builds one fish: its model, movers, saddle and wake (or a block stand-in when a kind has no model). |
| `Lib/Stream` | The smooth line the herd swims down, worked out once from the lane and the map. |
| `Lib/LaneSurvey` | Measures the lane's floor from the built map. |

## The client's controllers (`src/client/Controllers`)
| File | What it does |
|---|---|
| **Riding and the hop** | |
| `RideController` | Steers the fish we ride, the float between fish, the camera, getting on and off. |
| `JumpController` | The hop: the lock-on, the grab, the pull-in, landing and missing. |
| `DiveController` | The leap off the dock into the water (`Config.Dive.Leap`, off at 0): the arc, the pose's clock, the camera film, the splash on every screen. Checked by `tools/studio/dive_leap_check.py`. |
| `InputController` | The one jump button for keyboard, pad and touch. |
| `HookController` | The rope from hand to fish. |
| `LongHookController` | The extra camera, sound and word when the hook reaches far. |
| `WildController` | The rodeo camera on a fish: sway, kicks, bumps. |
| `ShakeController` | The shakes nothing else asks for: the strain rumble, the top-speed tremble. |
| `TameController` | Keeps the tame meter and the catch list from the server's word. |
| `EquipController` | The number keys and Q: the hotbar and the ride fish on land. |
| **Fish and bodies** | |
| `AnimController` | Every fish's swim and every rider's pose, each frame. No uploaded animations: all by code. |
| `AngryController` | The red pulse on an angry fish. |
| `ArchetypeController` | The passive archetypes' moments (the eat, the smash, the boost): sounds, shakes, words. |
| `ArriveController` | Fades in a fish that appears in sight. |
| `FailController` | What a fish does to you at 0 Oxygen (bite, throw, swallow), the ragdoll, the fail words, the camera. |
| `DeathController` | The drowning, the dark and the fade. |
| `PropController` | Props on our own screen: see-through when in the way, the broken boxes thrown and faded. |
| **The dock** | |
| `AquariumController` | Swims the fish in the tanks; the caught slots and the deposit moment. |
| `StallController` | Opens the dock's windows when you stand on their stands. |
| `HoldController` | Arms up while holding a fish over the head. |
| `TankRideController` | Riding a fish in our own tank. |
| `TrainerController` | The trainer toy on every plot: rocking, the coil, the rider. |
| `SubController` | The submarine trip on every screen. |
| `AuraController` | Every player's aura (the flame, drawn by `Lib/AuraBeams`; the old look behind `Config.Aura.Flame` 0) and the spawn-in. |
| `OfflineController` | Shows the "Welcome back!" window (`UI/OfflinePanel`) once a visit, the small Claim after its X, and asks for the claim. |
| `GroundFxController` | Small effects on land. |
| **The screen and the light** | |
| `LessonController` | What the first minutes' step shows: the dock's line (`UI/DockNotes`), the arrow and trail (`UI/LessonPointer`), the hop button's words and the ring on PUT ALL IN (`UI/LessonPrompt`). Nothing with `Config.Lesson.On` 0. |
| `HudController` | Builds the dive's and the dock's HUD from the `UI/` pieces and feeds them each frame. |
| `LookController` | Keeps the lighting at `Config.Look`. |
| `BlackHoleDisplayController` | Puts a live black hole on any part tagged `BlackHole`. |
| **Testing** | |
| `SandboxController` | The tuning panel (N) of every number. Studio only. |
| `AdminController` | The admin panel (P), for the place's owner. |
| `FeelLogController` | Records how a hop felt, for the feel reviews. Studio only. |

`src/client/Lib` holds what several controllers share: `State` (what the player is doing), `Actions` (the jump, so
input need not know who jumps), `Course` (staying out of walls), `WallRide`, `Lock` (which fish a grab takes), `Shake`
and `Spring` (the camera), `Feel` and `Fx` (speed lines, bubbles, sounds), `Splash` (the leap's white water),
`FeelLog`, `BlackHole`.

## The screen (`src/client/UI`)
| File | What it draws |
|---|---|
| `Kit` | The shared look: colours, letters, plates, rings, rarity colours. Used by nearly everything. |
| `Anim` | The shared motion: open, close, press, bounce, count-up, toast. |
| `Shop` | The dock window kit, despite its name: the frame, title bar, buttons, cards, and which window is open. |
| **While diving** | |
| `Rings` | The time-left ring and the tame ring beside the rider. |
| `HopButton` | The jump button at the lower right. |
| `Aim` | The aim and the grab window in the hop. |
| `Tags` | The name tag over each wild fish near you. |
| `LandStrip` | The ten lands across the top, with your best. |
| `Slots` | What you carry, along the bottom. |
| `StatRows` | Coins and Oxygen at the lower left. |
| `Banners` | The words that come and go: the miss, a new land, the catch. |
| `CaughtText` | The words when a fish becomes yours. |
| `CatchShow`, `DiveScreen` | The end of a dive (`CatchShow` builds `DiveScreen`). |
| `Portrait`, `FishIcons` | A creature's picture (`FishIcons` is made by a script: do not edit). |
| **On the dock** | |
| `TankPanel` | The "Your Tank" window. |
| `SellFish` | The Sell Fish window. |
| `ShopScreen` | The Robux shop. Every offer reads "Soon". |
| `AuraShop` | The aura stall: the twelve cards, buying. |
| `OfflinePanel` | The "Welcome back!" window and the small Claim by the dock's buttons. |
| `SubPanel` | The submarine stand. |
| `UpgradeSign` | The trainer's upgrade board on each plot. |
| `HubButtons`, `HubSigns`, `DockNotes`, `TankPrompt` | The dock's buttons, signs, the line in the middle of the screen, the moment a fish goes in. |

**To add a dock window:** a new module that builds with `Shop.window(...)`, registers with `Shop.page("Name", open)`
at its end, and is required from `StallController`.

## Shared (`src/shared`)
| File | What it holds |
|---|---|
| `Config` | Every tuning number, the fish roster, and the sums made from them (64 functions, listed by subject in the [shared audit](reviews/code-audit/shared.md)). |
| `Net` | The remotes. |
| `Zones`, `Lane` | The ten lands and the lane as one path. |
| `Creatures/` | Each modelled creature's parts, pivots and swim (`*.json`, made by `tools/creatures/collect.py`). |
| `RideStyles`, `AngryStyles` | How each of the nine body types moves, and how it shows it wants you off. |
| `Archetypes`, `Variants`, `Auras` | How passives, Silver/Gold/Rainbow fish and auras look. |
| `AuraFlame` | The flame auras' numbers and how they move (plain sums, tested offline). |
| `SubModels`, `SubTrip` | The submarines and a trip's path, the same on server and client. |
| `Products` | What the Robux shop sells. Every id is 0. |
| `Look`, `Ease` | Putting the lighting numbers on; small maths. |

## Every message
The header of `Net.luau` carries the same list (brought up to date 2026-11-22); this table adds who sends and who
listens.

| Remote | Message | From | To |
|---|---|---|---|
| Action | `Jump`, `Grab` fish, `CancelGrab`, `Land` fish, `Miss` | JumpController | RideService |
| Action | `RideEquip`, `RideUnequip`, `RideMount` | EquipController | RideService |
| Action | `Hold` index, id | AquariumController | AquariumService |
| Action | `Tank` what, key or hand, id | UI/TankPanel | AquariumService |
| Action | `Sell` where, key or hand, id | UI/SellFish, UI/TankPanel | AquariumService |
| Action | `Plot` "Up" | UI/UpgradeSign | AquariumService |
| Action | `TankRide` "On" fish, or "Off" | TankRideController, UI/TankPanel | TankRideService |
| Action | `SubBuy`, `SubEquip`, `SubPick`, `SubLand` | UI/SubPanel, SubController | SubService |
| Action | `SandboxSit` fish | RideController | RideService |
| Action | `AuraBuy` tier | UI/AuraShop | AuraService |
| Action | `Place` index, id | nobody | AquariumService (left from before the tank window) |
| Ride | `Mounted`, `Dismounted`, `Denied`, `Crashed` | RideService | JumpController, RideController |
| Ride | `Tamed`, `Caught` | RideService | TameController, UI/CaughtText |
| Ride | `OxygenTick` lost, oxygen, gap, kind | RideService | HudController, AngryController, UI/Rings |
| Ride | `Boost` | RideService | ArchetypeController |
| Ride | `Deposited`, `Sold`, `TankDenied`, `PlotUp`, `PlotNo` | AquariumService | AquariumController, the tank, sell and sign UI |
| Ride | `TankMounted`, `TankDismounted` | TankRideService | TankRideController |
| Ride | `SubFish`, `SubDrop`, `SubDenied`, `SubBought` | SubService | SubController, UI/SubPanel |
| Ride | `AuraBought`, `AuraDenied` | AuraService | UI/AuraShop, SoundController |
| Fx | `Land`, `Fail`, `Ragdoll`, `ThrowOff`, `Eat`, `Smash` | RideService | AnimController, JumpController, FailController, DeathController, ArchetypeController |
| Sandbox | `Tune`, `Flag`, `Reset`, `Ride` | SandboxController | SandboxService (Studio only) |
| Admin | requests and "Done" or "Refused" | AdminController | AdminService, and back |
| Offline | `Claim`; `Paid` coins, `Denied` why | OfflineController, OfflineService | both ways |
| Trainer | `On`, `Off`, `Gain`, `Up`, `UpNo` | TrainService, TrainerController, UI/UpgradeSign | both ways |

## Running and checking it
- **Run:** `rokit install` once, then `rojo serve` and connect Studio's Rojo plugin in a place that already has the
  map and the models. In Studio the game starts as the [movement sandbox](sandbox.md) (N opens every number).
- **Check before a commit:** `stylua --check src`, `selene src` (0 errors; 3 old "shadowing" warnings), and
  `rojo build -o <any file>.rbxl`. There are no unit tests. The scripted Studio checks are in `tools/studio/*_check.py`.
- **Change a number:** edit its table in `Config.luau`, or tune it live in the sandbox panel and copy the changes out.

## More detail
The audits this page was written from, one per area, each with a longer table (what every file requires, the
attributes it reads and sets) and its list of things to sort:
[server](reviews/code-audit/server.md), [controllers](reviews/code-audit/client-controllers.md),
[UI](reviews/code-audit/client-ui.md), [shared](reviews/code-audit/shared.md),
[the repo and the build](reviews/code-audit/repo-and-build.md).
