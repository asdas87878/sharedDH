# Server code audit (src/server)

Scope: every file under `src/server/` (Main.server.luau, Lib/, Services/), read in full. Line numbers are for the files
as they stand after the section markers were added to RideService, FishService and AquariumService. Nothing was
changed for this report. "Not checked" means it was not verified, not that it is fine.

## (a) Code map

How it starts: `Main.server.luau` requires every ModuleScript in `Services/`, calls each `Init` (no yield), then
spawns each `Start`. Services find each other with `require(script.Parent.X)`; Lib modules are required by path.

Remotes are made by `src/shared/Net.luau` in `ReplicatedStorage.Remotes`: `Action` (client to server), `Ride`
(server to one client), `Fx` (server to every client), `Sandbox` (Studio). Two more are made by services inside the same
folder: `Admin` (AdminService) and `Trainer` (TrainService).

| File | What it does (25 words or fewer) | Requires (server) | Remotes | Attributes and tags |
|---|---|---|---|---|
| `Main.server.luau` | Loads every service: Init on all, then Start each in its own thread. | Services/* | none | none |
| `Lib/FishModel.luau` | Builds a wild fish model: an imported template, a rigged creature, or a parts placeholder; adds movers, saddle, wake. | Config, Creatures | none | sets `FishType`, `Tier`, `Rider`, `Reserved`, `Rig`; tag `Fish` (FishModel.Tag) |
| `Lib/LaneSurvey.luau` | Re-measures the lane's floor by raycasting the built map, returning a corrected Path JSON. | none | none | none (prints a summary) |
| `Lib/Stream.luau` | Builds the herd's smooth line, band, floor and obstacle dodges from the lane and map; answers position queries. | Config, Lane | none | none |
| `Services/RideService.luau` | Each rider's state machine: dock, dive, hop, grab, mount, Oxygen drain, taming, crashes, fails, ragdoll, land ride fish. | FishModel, FishService, PropService | listens `Action` (Jump, Grab, CancelGrab, Land, Miss, SandboxSit, RideEquip, RideMount, RideUnequip); fires `Ride` (Mounted, Dismounted, Denied, Tamed, Boost, SandboxMount and others), `Fx` (Land, Fail, ThrowOff, Eat, Smash, Ragdoll) | player: `State`, `Oxygen`, `MaxOxygen`, `Tame`, `Owned`, `Strained`, `StrainSeconds`, `Equipped*`; reads `Admin`, `AdminNoFail`, `AdminEndlessAir`, `TrainerRide`, `TankRide`; fish: `Angry`, `AngryStyle`, `Bite`, `Smash`, `Frenzy`; tag `AngryFish`; character `Ragdoll`, `Riding`; Remotes folder `Dock` |
| `Services/FishService.luau` | The wild herd: rolls, spawns, parks, steers fish down the stream, tops up stock, reserves and hands fish to riders. | FishModel, LaneSurvey, Stream, PropService | none (sets Remotes folder attributes) | Remotes folder `Zones`, `LanePath`; fish `SizeTier`, `Size`, `Variant`, `Pace`, `Swift`, `Archetype`, `Reserved`, `Rider`, `SubFor`, `Visitor`; folders `Workspace.Fish`, `ServerStorage.ParkedFish` |
| `Services/AquariumService.luau` | Plots, tanks, coins, income payout, selling, plot upgrades, holding a fish over the head, and the way home. | FishModel, RideService | listens `Action` (Hold, Place, Tank, Sell, Plot); fires `Ride` (Deposited, Sold, TankDenied, PlotUp, PlotNo, Denied) | player `Coins`, `Income`, `TankFish`, `Tank`, `TankList`, `TankEarning`, `PlotStage`, `Hands`, `Plot`, `Held*`; plot `Owner`, `Raised`; tag `TankFish`; folder `Workspace.HeldFish` |
| `Services/SubService.luau` | The submarine: buy, equip, pick a land; carries a diving player down the lane and drops them on a fish or into a hop. | AquariumService, FishService, RideService | listens `Action` (SubBuy, SubEquip, SubPick, SubLand); fires `Ride` (SubDenied, SubBought, SubFish, SubDrop) | player `SubTier`, `SubEquip`, `SubDest`, `SubFish`, `SubTrip`, `SubPhase` |
| `Services/TankRideService.luau` | Riding one of your own tank fish round the tank on the dock. | AquariumService, PropService, RideService | listens `Action` (TankRide On/Off); fires `Ride` (Denied, TankMounted, TankDismounted) | player `TankRide`; fish `TankRider` |
| `Services/TrainService.luau` | The breath trainer on each plot: a spring-seat ride that raises max Oxygen, its level upgrades, signs and coil visuals. | AquariumService, RideService | own `Trainer` remote (On, Off, Gain, Up, UpNo) | player `Training`, `TrainerRide`, `TrainerLevel`; ride model `Rider`, `Level`, `Seat`, `SpringBase`, `SpringTop` and others |
| `Services/PropService.luau` | Breakable props: which boxes are out, breaking them, and rebuilding when nobody is near. | none | none | tag `PropOut`; prop `PropSize`, `BreakAt`, `BreakVel`, `BreakT`, `RebuildT`; reads character `Riding` |
| `Services/BestService.luau` | Each player's furthest depth this session, read from their character's position four times a second. | none | none | reads `State`, Remotes `Zones`; sets `BestMetres`, `BestLands` |
| `Services/AdminService.luau` | An in-game admin panel for the place owner: coins, fish, subs, max Oxygen, no-fail, endless air, land teleport. | AquariumService, FishService, RideService, SubService | own `Admin` remote | sets `Admin`, `AdminEndlessAir`, `AdminNoFail` |
| `Services/SandboxService.luau` | Studio-only movement sandbox: live number tuning, flags and reset from the client panel. | AquariumService, FishService, RideService | listens `Sandbox` (Tune, Flag, Reset, Ride) | workspace `Sandbox*` flags |

### One dive, traced

1. Player joins: `RideService` `onPlayer` makes the rider record and `onCharacter` puts them at the dock (state Dock);
   `AquariumService` `join` gives them the first free plot, a tank and `Coins` 0.
2. Each Heartbeat `RideService` `tick` runs for each rider. In Dock, when the character drops below the water line it asks
   `RideService.Diving` (filled by SubService) and `RideService.DiveFish`; with neither, state becomes Free.
3. Client sends `Action "Jump"`: `jump` checks the cooldown and sets state Jumping.
4. Client sends `Action "Grab", fish`: `grab` checks the window, reach (`reachNearness`), line of sight, then
   `FishService.reserve`.
5. Client sends `Action "Land", fish`: `landing` checks nearness, then `mount` seats the rider, gives the fish's network
   ownership to the rider (`FishService.setRider`), refills Oxygen, fires `Fx "Land"`, state Riding.
6. While Riding, `tick` calls `tickDrain` (Oxygen and the red part, `setAngry`), `tame`, `checkEat`, `checkCrash`,
   `checkSpeed`.
7. `tame` fills `Tame`; at full the fish is added to `Caught` and `Carried` and `Ride "Tamed"` is sent.
8. At Oxygen 0, `drown` plays the fish's fail outcome (`Fx "Fail"`) or `throwOff` (`Fx "ThrowOff"`, `ragdoll`), then
   `die` (Drowning) and `toDock`, which uses `RideService.Home` (AquariumService `home`) to put them at their plot.
9. Or a Free player who swims back reaches the dock, and `toDock` runs the same way without a death.
10. At the tank the client sends `Action "Place", index, id`: AquariumService checks state Dock and `atTank`, then
    `place` calls `RideService.takeCarried`, then `add`, `trim` and `changed` update income and the shown fish.
11. `AquariumService.Start` runs the payout loop: `Coins += Income * elapsed`, written to the `Coins` attribute.
12. Coins are spent by plot upgrades (`upgrade`, inside AquariumService) and through `AquariumService.spend` by the
    trainer (`TrainService.luau:819`) and the sub (`SubService.luau:156`); both of those are free for now (see below).

## (b) Things to sort

Ordered by what matters most to a buyer. Risk: "safe" means a change that cannot alter play; "needs a play test" means
it can. Lines in files outside `src/server` (Config, Net, Zones, Products, ShopScreen) are as of writing; other
helpers are editing those folders, so search by the name given if a line has moved.

### Paid-game needs

1. **Nothing is saved.** Coins, tank fish, plot stage, trainer level, subs, max Oxygen and best depth all live in
   memory and are lost when the player leaves. No DataStoreService use anywhere in `src`.
   Evidence: `AquariumService.luau:50` "For the session only: there are no saves yet."; `BestService.luau:8`;
   `TrainService.luau:5`; `SubService.luau:6`; `RideService.luau:2275`.
   Action: add one per-player save module (coins, tank fish, stage, levels, sub tier, best), loaded on join and saved
   on leave and on a timer, with session locking. Risk: needs a play test.
2. **No purchase handling on the server.** The client prompts purchases (`src/client/UI/ShopScreen.luau:124`
   `PromptGamePassPurchase`, `:126` `PromptProductPurchase`) but nothing in `src` sets
   `MarketplaceService.ProcessReceipt` or checks pass ownership. `src/shared/Products.luau:3-7` says no product is on
   sale yet and every Id is 0. Action: add a server receipt handler and pass checks before any Id is set. Risk: needs a
   play test.
3. **Upgrades cost nothing.** `Config.Train.Free = 1` (`src/shared/Config.luau:791`) and `Config.Sub.Free = 1`
   (`Config.luau:3130`); trainer level rows are marked `-- PLACEHOLDER` (`Config.luau:773-785`). Plot upgrades are paid
   (`Config.luau:920`, `Free = 0`). Action: set the economy and turn the flags off (shared folder, not server).
   Risk: needs a play test.
4. **Coins only exist with a plot.** Coins are a field of the tank (`AquariumService.luau` `join`, tank `Coins = 0`);
   `coinsOf` returns 0 and `spend` returns false with no tank (`AquariumService.luau:1040-1053`). A player who joins when
   every plot is taken gets no tank and cannot earn or spend. How many plots the map has versus the server size: not
   checked. Action: move the wallet out of the tank into its own per-player record (also needed for saving). Risk:
   needs a play test.

### Server trusting the client

5. **The ridden fish's position is the rider's.** `FishService.setRider` gives the fish's network ownership to the
   rider (`FishService.luau:1314`; also `:1816` for the sub's fish). The only check is `checkSpeed`
   (`RideService.luau:1605-1634`): once a second it compares the distance moved with the allowed speed and on a
   breach only sets `r.Flagged` and `warn`s once; it never corrects or acts. Taming is server-timed
   (`tame`, starting at the line after `checkSpeed`), and a fish's value is fixed at spawn, so moving the fish does not
   raise what it is worth; what a speed cheat can gain (distance, escaping fails): not checked. Action: on a flag, pull
   the fish back or end the ride; log it. Risk: needs a play test.
6. **Best depth comes from the character's position.** `BestService.luau:9-10` says so itself. A teleporting client
   can set any `BestMetres` (one land a check is the only limit). Low stakes until leaderboards or rewards use it.
   Risk: needs a play test.
7. Coins, sell prices, taming and Oxygen are computed on the server from server-held data; no remote takes an amount
   from the client. Verified for `Action` "Place", "Sell", "Plot", "Tank", "Hold" (AquariumService), "SubBuy",
   "SubEquip", "SubPick", "SubLand" (SubService), the RideService actions, and `Trainer` "Up"/"Off".
   `Action "TankRide", "On", fish` accepts only a model inside the caller's own shown tank with the `TankFish` tag
   (`TankRideService.luau` `start`, "NotYours" otherwise). Trainer gains are timed on the server from seated seconds
   (`TrainService.luau` `gain` and `settle`), never an amount from the client; the seated body is client-owned
   (`TrainService.luau:721`), so a client could stay seated without moving, which is how the trainer is meant to work.

### Rate limits

8. AquariumService's `Action` handlers each have a per-player gap (Hold and Place 0.15 s, Sell and Tank 0.1 s, Plot
   `PlotUpgrades.UpAgain`: `AquariumService.luau:1083-1282`); TankRide 0.3 s (`TankRideService.luau:283-297`); Admin
   0.1 s; Trainer "Up" `Train.UpAgain` (`TrainService.luau:784`).
   **No general gap** on RideService's `Action` handler (`RideService.luau:2102-2160`) or SubService's
   (`SubService.luau:491-505`) or Trainer "Off" (`TrainService.luau:836-843`). Each action is state-gated: `grab`
   refuses on state, target and window before any reach or raycast work, but a refused grab can be sent again and
   again inside one hop's window, and each one that reaches the reach check costs raycasts.
   Action: a shared per-player, per-action limiter in one place. Risk: needs a play test.
9. **Action dispatch is scattered:** eight separate `Net.Action.OnServerEvent` connections across four services
   (`AquariumService.luau:1083`, `:1183`, `:1204`, `:1244`, `:1262`; `RideService.luau:2102`; `SubService.luau:491`;
   `TankRideService.luau:283`), each filtering by action name. Every event runs every handler. Action: one router in
   Net or Main that dispatches by name, which is also where the limiter goes. Risk: needs a play test.

### Admin and test code that ships live

10. **The admin panel is live outside Studio.** `AdminService.luau:36-44` `allowed`: Studio, anyone in
    `Config.Admin.Users` (empty), or the place owner (`Config.Admin.Owner = 1`; user owner, or rank 255 in the owning
    group, `:47-56`). It gives coins up to `MOST_COINS`, fish, every sub, max Oxygen up to `MOST_OXYGEN = 100000`
    (`:27`), no-fail, endless air and a land teleport. The `Admin`, `AdminNoFail`, `AdminEndlessAir` attributes are
    read by RideService outside Studio (`RideService.luau:195-202` `sandbox`, `:1975`, `:2120`). Correctly gated to the
    owner; a buyer should decide whether to keep it, and set `Config.Admin.Owner` for the new owner group.
    Risk: safe to keep; turning it off needs a play test.
11. Studio-only test hooks, all verified gated by `RunService:IsStudio()`: BindableFunctions `FishStats`
    (`FishService.luau:1924`), `SubTest` (`SubService.luau:522`), `TrainerTest` (`TrainService.luau:847`); workspace
    attributes `TestVariant`, `TestSize`, `TestKind`, `TestVisit` (`FishService.luau:157`, `:179`, `:915`, `:1662`),
    `TestMaxOxygen` (`RideService.luau:234`), `FailSlow` (`:1027`), angry test (`:438`), grab logging (`:632`);
    `FishService.spawnTest` refuses outside Studio (`:1729`); SandboxService returns outside Studio
    (`SandboxService.luau:41`, `:68`). Risk: safe.
12. `AquariumService.give` (`AquariumService.luau:1055-1056`) is commented "Studio's tests only" but has no gate of its
    own; its callers are AdminService (owner-gated) and SubService's Studio-only test. Action: fix the comment or add
    the gate. Risk: safe.

### Unused code (verified by grepping `src/` and `tools/`)

13. `RideService.deposited` (`RideService.luau:2190`): no caller anywhere. `takeCarried` (`:2204`) now does the counting.
    The comment at `:958-960` still says AquariumService calls `deposited`. Action: delete the function, fix the
    comment. Risk: safe.
14. The `Owned` player attribute is set three times (`RideService.luau:964`, `:2196`, `:2212`) and read by nothing in
    `src` or `tools`. Action: drop it, or keep it if a save or leaderboard will use it. Risk: safe.
15. `AquariumService.sell` (`:1034`) and `AquariumService.earningOf` (`:1029`): no caller in `src` or `tools`.
    `stageOf` (`:1024`) is used only by `earningOf`. Action: delete, or keep `sell` if a sell stall is planned.
    Risk: safe.
16. `PropService.brokenCount` (`PropService.luau:261`, "for tests"): no caller in `src` or `tools`. Risk: safe.
17. `FishService.Tag` (`FishService.luau:139`): never read; everything uses `FishModel.Tag`. Risk: safe.
18. `TankRideService.riding` (`TankRideService.luau:277`): no caller in `src`; used only by the Studio check script
    `tools/studio/b4_tank_ride_check.py:114`. Keep, and say so in its comment. Risk: safe.
19. Unused modules: none. Every Lib module is required (FishModel by three services, LaneSurvey and Stream by
    FishService) and Main loads every service. `Services/.gitkeep` is an empty leftover. Risk: safe.

### Duplicated helpers

20. `nearness` and `reachNearness` (`RideService.luau:581`, `:606`) repeat the same ping and lag rewind loop; only the
    distance function differs. Action: one helper taking the distance function. Risk: needs a play test.
21. `parts(player)` is written twice (`RideService.luau:204`, `TankRideService.luau:43`). Action: move to a server Lib.
    Risk: safe.
22. Sign styling `SIGN_BLUE`, `SIGN_INK` are copied (`AquariumService.luau:130-131`, `TrainService.luau:50-51`), and the
    board-and-post builders `plotSign` (`AquariumService.luau:227`) and `upgradeSign` (`TrainService.luau:158`) are near
    copies. Action: one sign module. Risk: needs a look in Studio.
23. "Build a FishModel, then strip its constraints and trails and make it massless" is done three times:
    `RideService.luau:321-328` (land ride fish), `AquariumService.luau:378` (shown tank fish), `:493-500` (held fish).
    Action: a `FishModel.buildStill` (or similar). Risk: needs a play test.
24. The variant list is written out four times: `AdminService.luau:26`, `FishService.luau:159`, `:1735`, `:1799`. Action:
    read it from `Shared/Variants`. Risk: safe.
25. The map folder name `"ClaudeBlockout"` is hard-coded 9 times in the server (`AquariumService.luau:1139`,
    `PropService.luau:69`, `RideService.luau:223`, `:1209`, `:1492`, `:1564`, `SubService.luau:129`,
    `TrainService.luau:503`, `:523`) and 17 times in the client. `Shared/Zones.luau:84` already falls back to `Map`.
    Action: one constant (and a neutral name) in Shared. Risk: needs a play test (and a map rename).

### Files doing two jobs, names, folders

26. `AquariumService.luau` (1306 lines) holds the wallet, the tank, selling, plot upgrades and holding a fish over the
    head. The wallet and holding are separate jobs. Action: split out a wallet (with saving) and a holding service.
    Risk: needs a play test.
27. `RideService.luau` (2404 lines) also holds the land ride fish (equip) and the ragdoll. Action: split those two out.
    Risk: needs a play test.
28. `TrainService.luau` builds its own signs and coil visuals as well as the gameplay. Risk: needs a play test.
29. Hook slots are filled by other services at Init (`RideService.Keeps`, `Home`, `HeldOf`, `PutAway` by
    AquariumService; `Diving`, `DiveFish` by SubService; `RideService.luau:157-168`). All six are filled and read; the
    pattern hides the dependency. Action: document it in one place, or invert it. Risk: safe to document.
30. Confusing names: `sandbox(flag, r)` (`RideService.luau:193-202`) is commented "Studio only" but first reads the
    live `Admin<flag>` attributes (`:196`), so it is the admin switch outside Studio. Likewise `RideService.sandboxReset`
    and `Action "SandboxSit"` serve the live admin land teleport. Action: rename to say "test or admin". Also selene's
    one warning: the parameter `count` of `FishService.stockNear` (`FishService.luau:1825`) shadows the local function
    `count`. Risk: safe.
31. Wrong folder: SandboxService is Studio-only but sits with the live services and is loaded in every server (it
    returns early outside Studio, `SandboxService.luau:41`). Harmless; a buyer may move it under a dev folder. No other
    file is in the wrong place. Risk: safe.
32. Net's contract misses an event: RideService fires `Fx "Ragdoll"` (`RideService.luau:828`) but the Fx list in
    `src/shared/Net.luau:16-19` does not name it. Action: add it to the list. Risk: safe.

### Comments that are wrong or out of date

33. `FishService.luau:1555` "The nearest fish in the water a player could get on" sits above `keepNear` (`:1557`); it
    belongs to `nearest` (`:1564`). `FishService.luau:1746` "After the sandbox changes how many fish there should be"
    sits above `keepFor` (`:1749`); it belongs to `restock` (`:1861`). Action: move each comment. Risk: safe.
34. `FishService.luau:20-21` "There is no size roll for now" is undone by the next lines (sizes are back). Risk: safe.
35. `RideService.luau:1191-1192`: two lag allowances are both kept, "To choose one: docs/Handoff.md". An open
    decision in code. Risk: needs a play test.
36. Comments across the server carry people's names, dates and task ids (for example `SubService.luau:2`,
    `FishService.luau:18-24`, `RideService.luau:1106`). Fine for the team; a buyer may want them cleaned.
    Risk: safe.

### Stand-ins and placeholders

37. `Lib/FishModel.luau:146` `placeholder`: a fish built from parts when a kind has no model; used as a fallback in
    `FishModel.build` (`:501`), with a `warn` when a model fails (`:499`). How many kinds still have no model: not
    checked. Risk: safe.
38. `TrainService.luau:8`: a map with no trainer plots gets "the old stand-in" (a part named TrainSpot, or a pad made
    once). Old fallback code; remove once every map has the plots. Risk: needs a play test.
39. Animation hooks waiting on art: RideService's header and `setAngry` comment say the fish's `Bite`, `Smash`,
    `Frenzy` and `AngryStyle` attributes are "for the animations to come". Risk: safe.
40. No TODO, FIXME or DRAFT markers in `src/server`.

### Performance

41. `FishService` `giveWay` (`FishService.luau:1365`) compares every pair of unparked, unridden fish, every
    `Herd.GiveEvery` (0.25 s, `Config.luau:2236`). Cost at full stock: not measured. Action: bucket by stream position.
    Risk: needs a play test.

### Hard-coded ids and names

42. Checked: no asset ids (`rbxassetid` or long numbers) and no user names or user ids in `src/server`; the owner is
    found from `game.CreatorId`. Risk: safe.

### Not checked

- Whether the map has enough plots for the server size; what a speed or teleport cheat can gain; memory clean-up of
  per-player tables on leave beyond the handlers seen.
