# Code audit: src/shared

Scope: every `.luau` file in `src/shared/` (15 files, 6,617 lines with Config's new contents and markers). The 79
`Creatures/*.json` files were not opened (a script writes them). Users were found by grepping `require(` lines across
`src/` (97 `.luau` files). Line numbers are for the files as they are now, with Config's new contents list and markers in place.

## Part (a): code map

| File | What it holds | Who requires it |
|---|---|---|
| `Config.luau` (4,009 lines) | Every tuning number as `Config.X` tables, the fish roster build, and 64 helper functions that work numbers out from them. | 64 files: 49 client (26 Controllers, 7 Lib, 16 UI), 11 server (FishModel, Stream, AdminService, AquariumService, FishService, PropService, RideService, SandboxService, SubService, TankRideService, TrainService), 4 shared (AngryStyles, Archetypes, SubTrip, Zones) |
| `Net.luau` | Makes and finds the four shared RemoteEvents in `ReplicatedStorage.Remotes`. Its header lists the attributes the server sets. | 30 files (see the table below) |
| `Ease.luau` | Small easing maths: lerp, smoothstep, frame-rate-independent alpha, the ridden speed curve. | 16: 14 client Controllers, client/Lib/WallRide, shared/AngryStyles |
| `Zones.luau` | The ten lands as frames on the lane floor: read from the map's markers or a fallback, sent to clients as JSON, located by position. | 10: HudController, RideController, Lib/Course, Lib/State, UI/CatchShow, UI/DiveScreen, UI/Tags, BestService, FishService, shared/Lane |
| `Lane.luau` | The dive lane as one centreline path, in studs along it: projection, point at a distance, the zone at a distance, the room under roofs. | 3: client/Lib/Course, server/Lib/Stream, FishService |
| `Creatures/init.luau` | Loads and checks each creature's JSON rig (parts, pivots, seat, glow, swim keys) and builds swim frames. | 5: AnimController, FailController, TankRideController, server/Lib/FishModel, shared/Config |
| `RideStyles.luau` | Nine body types: motion numbers, swim waves, fin turns, landing reactions, which creature has which. Also the seahorse trainer's shape numbers and coil builder. | 6: AnimController, TankRideController, TrainerController, RideService, TrainService, shared/AngryStyles |
| `AngryStyles.luau` | Each body type's angry slow-down shape, the stand-in rocking motion, and the lock that keeps the struggle on the Oxygen ticks. | 3: AngryController, RideController, RideService |
| `Archetypes.luau` | The look of the six passive archetypes: word, colour, icon, short line; builds icon rows. | 5: ArchetypeController, HudController, UI/Rings, UI/Tags, UI/TankPanel |
| `Variants.luau` | Silver, Gold and Rainbow looks: tints, baked variant meshes, sparkles; puts them on and takes them off a model. | 3: AquariumService, FishService, RideService |
| `Auras.luau` | The twelve aura tiers (name, Oxygen multiplier, colours, blurb) and the spawn-in style switch. | 2: AuraController, UI/AuraShop |
| `Look.luau` | Puts `Config.Look`'s lighting numbers onto Lighting, Bloom and ColorCorrection. | 1: LookController (also `tools/studio/look_install.luau`, outside src) |
| `Products.luau` | The Robux shop's sections and offers (11 offers, every Id 0). | 1: UI/ShopScreen |
| `SubModels.luau` | The ten submarine tiers' names and colours, and building each one from its mesh template or a plain-part placeholder. | 2: SubController, UI/SubPanel |
| `SubTrip.luau` | A submarine trip's phases, speeds and path, worked out the same on server and clients; JSON encode and decode. | 2: SubController, SubService |

No shared module is required by nothing.

### Net.luau: every remote

Net makes four RemoteEvents (`Action`, `Ride`, `Fx`, `Sandbox`). Two more live in the same folder but are made by
services, and Net does not mention them: `Admin` (AdminService.Init) and `Trainer` (TrainService). Each row is one
message, which is the first argument.

| Remote | Message and arguments | Direction | Fired by | Listened to by |
|---|---|---|---|---|
| Action | `Jump`, `Grab` fish, `CancelGrab`, `Land` fish, `Miss` | client to server | JumpController | RideService |
| Action | `RideEquip`, `RideUnequip`, `RideMount` | client to server | EquipController | RideService |
| Action | `SandboxSit` fish | client to server | RideController | RideService |
| Action | `Hold` index, id (or 0 to put down) | client to server | AquariumController | AquariumService |
| Action | `Tank` "PutIn"/"TakeOut"/"Equip"/"Unequip"/"Best"/"PutAll", key or hand, id | client to server | UI/TankPanel | AquariumService (SubService also matches "Tank") |
| Action | `Sell` "Hand", hand, id or "Tank", key | client to server | UI/SellFish, UI/TankPanel | AquariumService |
| Action | `TankRide` "On", fish or "Off" | client to server | TankRideController, UI/TankPanel | TankRideService (also matched in AquariumService, RideService) |
| Action | `Plot` "Up" | client to server | UI/UpgradeSign | AquariumService |
| Action | `SubBuy`, `SubEquip` n, `SubPick` land, fishKey, `SubLand` fish | client to server | UI/SubPanel, SubController | SubService |
| Action | `AuraBuy` tierId | client to server | UI/AuraShop | **nobody** (no server code handles it) |
| Action | `Place` index, id | client to server | **nobody** (Net's header still lists it) | AquariumService |
| Ride | `Mounted` fish, landing; `Dismounted` reason | server to one client | RideService | JumpController, RideController |
| Ride | `Denied` action, reason, target? | server to one client | RideService, AquariumService, TankRideService | JumpController |
| Ride | `Crashed` slow | server to one client | RideService | RideController |
| Ride | `Tamed` fish, fishId; `Caught` ids | server to one client | RideService | TameController, SandboxController; TameController, UI/CaughtText |
| Ride | `Boost` kind, by, time, oxygen, count | server to one client | RideService | ArchetypeController |
| Ride | `OxygenTick` lost, oxygen, gap, "Tick"/"Break" | server to one client | RideService | AngryController, HudController, UI/Rings |
| Ride | `Respawned` | server to one client | RideService | **nobody** |
| Ride | `SandboxMount` fish | server to one client | RideService | RideController |
| Ride | `Deposited` count, gained, income, id; `Sold` id, coins | server to one client | AquariumService | AquariumController, UI/TankPrompt; UI/SellFish, UI/TankPanel |
| Ride | `TankDenied` why; `PlotUp` stage; `PlotNo` why | server to one client | AquariumService | UI/SellFish, UI/TankPanel; UI/UpgradeSign |
| Ride | `TankMounted` model, box, half; `TankDismounted` | server to one client | TankRideService | TankRideController |
| Ride | `SubFish` fish, `SubDrop` "Fling"/"Kick", fish, `SubDenied` reason, `SubBought` tier | server to one client | SubService | SubController, UI/SubPanel |
| Fx | `Land` player, fish, count | server to all | RideService | AnimController, JumpController |
| Fx | `Fail` player, fish, outcome; `Ragdoll` player, fish?, kind | server to all | RideService | FailController |
| Fx | `ThrowOff` player, fish | server to all | RideService | DeathController |
| Fx | `Eat` / `Smash` player, fish, where, count | server to all | RideService (sent as a variable `kind`) | ArchetypeController |
| Sandbox | `Tune` "Group.Key", number; `Flag` name, bool; `Reset`; `Ride` fishId, variant | client to server (Studio only: SandboxService.Init returns outside Studio) | SandboxController | SandboxService |
| Admin | client sends kinds such as "EndlessAir", "NoFail", "Max"; server answers "Done"/"Refused", text | both ways | AdminController / AdminService | AdminService / AdminController |
| Trainer | client "Off", "Up"; server "On", "Off", "Gain", "Up", "UpNo" | both ways | TrainerController, UI/UpgradeSign / TrainService | TrainService / TrainerController, UI/UpgradeSign |

Net's header misses about 20 of the messages above. Among them are Hold, Tank, Sell, TankRide, Plot, RideEquip,
RideMount, RideUnequip, SubEquip, AuraBuy, PlotUp, PlotNo, Sold, TankDenied, TankMounted, TankDismounted and Ragdoll,
plus the Admin and Trainer remotes. The table above is the full list from the code.

### Config.luau: helper functions by what they work out

There are 64 `function Config.x` helpers. All but `metresAt`, `landStyleOf`, `longOf` and `failOf` sit together at the
end of the file. Each line below gives what the function returns.

**Depth, land motion and the fail outcome** (these sit beside their own tables)
- `metresAt(y)`: the depth in metres the gauge shows for a height, never below 0.
- `landStyleOf(id)`: a kind's motion on land (its body type's numbers with the kind's own changes), and the type's name.
- `longOf(gap)`: how long a hook across this gap counts as, 0 to 1.
- `failOf(fish, style)`: the name of what this fish does when the Oxygen runs out.

**What a fish needs, and the Oxygen meter**
- `requiredOf(fish, size, variant)`: the Oxygen this fish needs, with its size and colour counted in.
- `requiredOfModel(model)`: the same, read from a fish model's attributes; nil for a model that is not a fish.
- `strained(required, max)`: whether a fish needs more Oxygen than the rider has, so it is too strong for them.
- `angryAt(fish)`: where the red part of the meter starts on this fish, as a share of the max.
- `low(oxygen, max, fish)`: whether the meter is in its red part now.
- `redLine(max, fish)`: the red line in Oxygen, measured on the big HUD ring.
- `heat(oxygen, max, fish)`: how far into the red part the meter is (no comment of its own; read from its name and the
  code around it).
- `grow(required)`: how many times longer a stronger fish is ridden and tamed than the first fish (used only inside
  Config).
- `pastCap(max)`: the small extra time a fish lasts for a rider whose max is past `Oxygen.Cap` (used only inside
  Config).
- `secondsOn(required, max, fish)`: how many seconds a full meter lasts on this fish.
- `redSeconds(seconds)`: how many seconds the red part lasts, out of a whole meter of `seconds`.
- `drainFor(required, fish, max)`: the Oxygen lost per second on this fish.
- `tickOf(max, rate)`: one tick's piece of Oxygen and the seconds between ticks.
- `redTicks(left, seconds)`: the red part's even ticks: the piece and the gap.
- `strainTicks(max, left, seconds)`: the ticks on a fish that is too strong, after the break-off.
- `strainSeconds(run)`: how long the meter lasts on the Nth too-strong fish landed on in a row (it shrinks each time).
- `ringsOf(max)`: how many HUD rings to show for this max, 1 or 2.
- `freeDrain(max)`: the Oxygen lost per second while floating off a fish.
- `tameTime(required, max)`: the seconds on a fish it takes to tame it.
- `trainTicks(carry, dt)`: how many whole training seconds are finished, and the part of a second left over.

**Speed**
- `speedOf(fish, variant)`: a kind's ridden speed. Its comment is out of date (see part b, 2).
- `riddenOf(model, fish)`: a fish model's ridden speed, from its type and attributes.
- `surgeOf(fish)`: the burst of speed when you get on a fish, and how long it lasts.
- `burstShare(t, time)`: how much of an eat or smash burst is left, `t` seconds in, 0 to 1.
- `wallKeep(into)`: the share of speed kept when riding a wall, by how square on you hit it.

**The hop and the hook**
- `hopOf(fish)`: the Leaper's changes to the hop: apex and glide multipliers, and extra seconds.
- `airOf(speed)`: the extra airtime for a hop that leaves at this speed (used only inside Config).
- `hopFrom(had, fish, ridden)`: the hop as it leaves: its speed, extra seconds and apex multiplier.
- `hopKept(t, extra)`: the share of the hop's leaving speed still there `t` seconds in.
- `hopSpeed(t, launch, extra)`: the hop's speed across the water `t` seconds in, the same on client and server.
- `hopSink(t, extra)`: how far the hop has fallen `t` seconds in.
- `aheadOf(t)`: how far the hook reaches straight ahead `t` seconds into a hop, as a multiple of its reach.
- `reachOf(speed, launch)`: the hook's reach at this speed, the same for the client's lock and the server's check.
- `bodyGap(at, body, point)`: how far a point is from a fish's body box (0 inside it).
- `fishGap(model, point)`: the same for a fish model.

**Props**
- `volumeOf(fish)`: a kind's box volume in cubic studs (used only inside Config).
- `giant(fish)`: whether that volume makes it a giant for props (used only inside Config).
- `boxSize(box)`: a single size for a box: the cube root of its volume.
- `propBreak(kind, fish, prop)`: whether a ridden fish breaks this prop, and the share of speed it keeps.
- `breaks(fish)`: whether a wild fish breaks the props it swims into.

**Sizes, variants and archetypes**
- `rollSize(roll, rarity)`: a spawned fish's size name, from a roll of 0 to 1.
- `rollVariant(roll)`: a spawned fish's variant: none, Silver, Gold or Rainbow.
- `sizeScale(tier, fish)`: how many times the kind's base size this size is, kept inside `SizeLimit`.
- `isGrand(tier)`: whether a size counts as a grand one.
- `sizeOf(model)`: a fish model's size multiplier, read from its attributes (used only inside Config).
- `sizeTierOf(model)`: a fish model's size name.
- `variantOf(model)`: a fish model's variant.
- `bodyOf(model, fish)`: a fish model's body size: width, height and length.
- `archetypesOf(fish)`: a kind's archetypes as a list.
- `hasArchetype(fish, id)`: whether a kind has this archetype.
- `archetypeOf(model)`: a model's "Archetype" attribute. Nothing calls it.

**Money**
- `incomeOf(fish, size, variant)`: the coins a second this fish earns in a tank.
- `sellOf(fish, size, variant)`: the fish's sell price in whole coins.
- `earningOf(stage)`: how many fish can earn at once at this plot stage.

**The herd**
- `paceOf(fish)`: a kind's character as a wild fish: Cruise, Plod, Zoom, Dart or Hunt.
- `herdTop(floorY)`: the highest the herd swims above a floor, pressed down in the shallows.
- `herdHeight(own, floorY)`: a herd fish's height above a floor.

**Text and setup**
- `wholeNumber(value)`: a number with its thousands grouped, such as 2,925.
- `shortNumber(value)`: a number written short, such as 1.2K. The HUD has its own copy, `Kit.short`.
- `refresh()`: works out the numbers made from other numbers. The sandbox calls it again after every change.

## Part (b): things to sort

Risk key: **safe** means a comment or deletion that no running code reads. **Play test** means the game's behaviour
could change.

### 1. Config items nothing reads

I grepped every `Config.X` table and `function Config.x` across `src/`, comments stripped. Every table is read
somewhere: some only by Config's own helpers (for example `OxygenBase`, `SizeLimit`, `GrowFrom`, `FishPace`), which is
fine. For fields I counted any `.Field`, `"Field"` or `["Field"]` anywhere in `src/`. A zero is a strong sign; a
non-zero proves nothing, because the names are short and common.

| Where | What | Evidence | Action | Risk |
|---|---|---|---|---|
| Config.luau:3930 | `Config.archetypeOf(model)` | 0 calls anywhere, inside Config included | delete | safe |
| Config.luau:3004-3008 | `AimHud.FollowRate`, `PreviewTransparency`, `PulsePeriod`, `PulseWhiten`, `PulseScale` | only the sandbox panel lists them (SandboxController:761-763); game code reads only `AimHud.RefusedTime` (HudController:505) | find out whether UI/Aim has its own copies; then delete or wire up | play test if wired up |
| Config.luau:3037 | `Spawn.Wander` | no mention outside its line | delete | safe |
| Config.luau:799 | `Train.RobuxProduct = 0` | no reader; the Robux block is a picture only | wire up with the shop work (see 7) | play test |
| Config.luau:636-638, 646 | `OxygenBase` rows Butterflyfish, BlueChromis, Boxfish, FlyingFish | Config.luau:111 says they were cut from the game; no creature JSON and no `FISH` row for them | delete (cut from the game); other tables may hold rows for them too (not checked) | safe |
| Config.luau:32, 67-73 | `Tiers[*].Idle` | the type's own comment says it is not used; no `Tiers…Idle` read found | delete the field | safe |
| Config.luau:2317 | `SizePace`: all six values 1 | read by code but changes nothing (comment: all 1 on purpose) | keep as a dial or delete | play test if deleted |
| Config.luau:748 | `SpecialOxygen = {}` | empty; `requiredOf` checks it | keep as a hook or delete | safe |
| Ease.luau:5, 14 | `Ease.clamp01`, `Ease.inQuad` | 0 calls | delete | safe |
| Archetypes.luau:102, 65 | `Archetypes.does` (0 calls); `Archetypes.rich`, an old alias of `line` (1 caller, HudController) | grep | delete `does`; point HudController at `line` | safe |
| Auras.luau:131, 139 | `Auras.SpawnNames`, `Auras.get` | 0 uses | delete | safe |
| Variants.luau:330 | `Variants.clear` | 0 uses (callers use `apply(model, "")`) | delete | safe |
| Config.luau (helpers) | `pastCap`, `airOf`, `volumeOf`, `giant`, `sizeOf`, `grow` | called only inside Config | could be `local` functions | safe |

### 2. Numbers that are duplicated or contradict each other

- **`speedOf` does more than its comment and the skill notes say** (Config.luau:3832-3849). The comment says "its
  species' own (FishStats), by its variant". The code first spreads the speed round the home land's pace
  (`LandPace`, `Speed.Spread = 2`) and then multiplies by `Speed.Ride = 1.6`. So a `FishStats` speed of 50 is not
  ridden at 50. The comment should give the real formula. Safe.
- **`LandPace` is a hand copy of `FishStats`** (Config.luau:2320, "about what its middling fish is ridden at"). Change
  the fish and the land paces drift. Safe to document; play test to compute it instead.
- **Tuning numbers outside Config:** `AngryStyles.Sync` (AngryStyles.luau:105, "Numbers here, not in Config") and
  `RideStyles.Trainer` (RideStyles.luau:199, "Kept here, not in Config"). The Config header promises every number. The
  plot sign's numbers are also copied into `tools/map/hub_kit.py` (comment at Config.luau:801). Safe to note; play
  test to move.
- **Two places for Robux prices:** `Products.luau` has `Price = 0` for every offer, while `Config.Train.Robux` (12
  prices) and the PlotUpgrades Robux list (Config.luau:922) hold Robux prices for signs. Pick one home. Safe.
- **Two number formatters:** `Config.shortNumber` and `Kit.short` (the comment at near Config.luau:3812 says the HUD has
  its own). Safe to merge.
- **Comments that contradict the code:**
  - `Tame` (Config.luau:845) and `Train` say "no tank and no income yet", but `Aquarium` with income and selling exists.
  - The 22-line comment above `Config.Wild` (Config.luau:1921-1942) is about the lock-on and the hook (`Lock`,
    `Hook`), not about `Wild`, which is the ridden fish's fits and camera sway.
  - The `TankRide.Reach` comment says "the server: 48", and I found no 48 in TankRideService (not resolved).
  - All safe.
- **Net's header is out of date** (see the remote table): it lists `Place`, which no client sends, and misses about
  20 messages. Safe.

### 3. Comments much longer than the numbers

`Config.luau` before my edit had 3,922 lines:

- 1,189 comment-only lines and 2,591 code lines; 1,127 of the code lines carry a trailing comment.
- By characters the comments are **3.1 times the code** (199k against 64k).
- 294 lines carry a date and 188 name a person ("Hugo", "the user"). 66 quote someone at length.
- Comments with history markers (a date, a name, "task x1", "until", "was") make up about 31% of the comment text.
  Counting the sentences that continue those, roughly **a third of the comment text is a change diary** rather than
  an explanation of what the number does.

Three typical examples:

- **`Config.Speed`** (Config.luau:84-96): 15 lines for 6 numbers. `Ride = 1.6` carries a trailing comment of over
  200 characters. It gives the old value (1.15 "for a day"), then a dated quote that "Everything needs to be faster".
  Useful content: "every fish's ridden speed, times".
- **`Config.Net`** (Config.luau:2786-2798): the `Lag` comment is an eight-line account of a bug report (players
  falling off fast fish). It explains the fix in a story rather than saying "the server rewinds the fish by up to Lag
  seconds and the rider by PlayerLag when judging a grab or landing".
- **`Config.Herd`** (Config.luau:2195-2201): the `SpeedShare` comment records 0.85, then 0.7, then 0.85 again with
  dates, a hop-rate measurement and a quote. That belongs in `docs/design/herd.md`; the code needs one line.

By comment characters per number, the heaviest tables are `Oxygen` (147 lines, 41 numbers, 12k comment chars),
`Tame`, `Net`, `Speed`, `Depth`, `Sandbox` and `Jump` (295 lines, 136 numbers, 31k comment chars).

Suggested action: move the history into the design notes (the comments already link them) and keep one plain line per
number. Safe, but it must not collide with people tuning the file, so do it in one pass when nobody else has it open.

### 4. PLACEHOLDER, DRAFT, stand-in and "not decided" marks

| Where | What is unfinished |
|---|---|
| Config.luau:773-789 | Trainer's 12 levels: every Oxygen and Price is marked PLACEHOLDER, waiting for the economy draft |
| Config.luau:796-799, 922 | Robux prices on the trainer and plot signs are pictures only; no developer product (`RobuxProduct = 0`) |
| Config.luau:759, 845, 905 | **No saves:** training, taming and plot stage last for the session only. A grep for DataStore or ProfileStore across `src/` finds nothing: no player data is saved at all |
| Config.luau:760, 768 | The training pad is a stand-in made by the server when the map has no `TrainSpot` |
| Config.luau:88 | `Speed.Silver = 1.05`, a stand-in |
| Config.luau:310, 985, 997, 2485-2486; AngryStyles.luau:15, 250 | Stand-in sine motion for bites, smashes, angry mode and the wall ride, until real animations exist |
| Config.luau:2635, 2659, 2994 | Fail outcomes and the throw use placeholder sounds and effects (Lib/Fx) |
| Config.luau:868, 2352, 2636, 3095, 3126 | Aquarium, pace, fail, dive-in and submarine numbers are "a first go", "unplayed"; submarine prices are "guesses" |
| Config.luau:47, 3245 | The `Shape` body field is a placeholder from before models; `FISH` rows keep only placeholder colours |
| Config.luau:3174 | `ZoneMix` comes from "the roster's draft weights" |
| Auras.luau:4-5, 129 | Auras are DRAFT 2, looks only; names are stand-ins; buying is not built. The server never handles `AuraBuy` and never reads `Auras.Mult`, so the Oxygen multiplier does nothing. The spawn-in style is "a draft" waiting for a pick |
| Archetypes.luau:19-24 | Archetype icons are not uploaded: `UPLOADED` is empty and icons load from `rbxasset://ridefish/...`, a folder on one PC. **On any other machine, and in a live game, the icons are blank.** The same `rbxasset://textures/ridefish/` pattern appears in client/UI/FishIcons, Kit, LandStrip and Shop (not checked in detail; outside my area) |
| Variants.luau:4-9 | Silver, Gold and Rainbow are tints until real variant meshes exist; the Silver rules are "still to be written" |
| SubModels.luau:5 | A tier without a mesh template falls back to plain-part placeholders |
| RideStyles.luau:10 | Body-type motion numbers are "first guesses, not judged in play" |

### 5. Modules never required

None. All 15 shared modules have at least one requirer (code map above).

### 6. Confusing names

- **Three words for one place:** "zone" (`Zones`, `ZoneMix`, `Creatures.Zone`), "land" (`LandPace`, `SubTitles`, the
  UI) and "home" (`FishType.Home`) all mean the same ten areas.
- **"Tier" means three things:** rarity (`Config.Tiers`, `FishType.Tier`), submarine tier (`Config.Sub`) and aura tier
  (`Auras.Tiers`). The trainer's twelve are "levels".
- **"Giant" means three things:** the size named Giant (`SizeOrder`), `Config.giant(fish)` (box volume at least
  `Props.GiantVolume`, for props) and `Angry.GiantLength` (length at least 68, for the angry style). "Grand" is yet
  another big-size idea (`Config.Grand`, `isGrand`).
- **`Config.Wild` is not about wild fish.** Everywhere else "wild" means an unridden herd fish; `Config.Wild` is the
  bucking of the fish you ride.
- **Four tables named for fish:** `Config.Fish` (the built list), `Config.FishById`, `Config.FishStats` (speed and
  archetypes), `Config.FishPace` (character), plus the local `FISH` list. Also `Config.Variant` (odds) next to the
  `Shared/Variants` module (looks) and `VariantOxygen`.
- **Oxygen is the stamina meter** (the comment at Config.luau:464 says so). New readers will look for "stamina".
- **Hidden aliases:** `Config.MixShallows` to `Config.MixUnderworld` exist only through `(Config :: any)[name]`
  (Config.luau:3189-3205), so they cannot be found by grepping `Config.Mix`.

### 7. Products.luau and the shop

Every one of the 11 offers has `Id = 0` and `Price = 0`, so the Shop shows SOON and the buy button does nothing
(ShopScreen:120). The offers are 3 game passes (Starter, DoubleOxygen, DoubleLuck) and 8 developer products
(Featured, Exclusive, Oxygen1-3, Cash1-3).

A new owner must create each pass and product on the Roblox site, then fill in its `Id` and Robux `Price`. The server
side does not exist:

- No `MarketplaceService.ProcessReceipt` anywhere in `src/`.
- No `UserOwnsGamePassAsync` check.
- No code that grants anything: the keys `DoubleOxygen`, `DoubleLuck` and `Starter` appear only in `Products.luau`.

So the double-Oxygen and double-luck effects, the cash and Oxygen grants, and the featured and exclusive contents are
all still to be designed and written. Because nothing is saved (section 4), passes and purchases also need a save
system first. The trainer's and plot signs' Robux blocks (`Train.RobuxProduct`) need the same.

Risk: needs a play test, and a purchase test on a published place.

### 8. Hard-coded user ids and names

- `Config.Admin` (Config.luau:2776): `Users = {}` and `Owner = 1`. No user ids are hard-coded; in a live server only
  the place's owner gets the admin panel, and in Studio everyone does (AdminService:37). A new owner who wants
  testers must add their user ids. Safe.
- A grep for 7-digit-or-longer numbers and `UserId ==` across `src/` found no hard-coded ids. The one hit is a random
  seed in client/Lib/BlackHole.
- People's names are only in comments: 188 Config lines name "Hugo" or "the user", and Archetypes.luau:19 mentions
  "Hugo's PC". Remove them with the history clean-up in section 3. Safe.

### 9. Should Config be split?

Yes, along the section markers now in the file, keeping `Config.luau` as the one thing everyone requires. Suggested
split:

- `Config/Fish` (rarities, stats, archetypes, variants, sizes, spawn mix and roster)
- `Config/Oxygen` (depth, Oxygen, training, taming)
- `Config/Hub` (aquarium, plot, angry mode, on foot, land riding)
- `Config/Movement` (Ride, Jump, Wild, Stride, Long, Hook, Lock, Net)
- `Config/World` (herd, pace, shakes, crashes, walls, props, spawning, dive-in, submarine)
- `Config/Look` (camera, look, animation)
- `Config/Dev` (sandbox, admin, feel log)
- `Config/Rules` (the helper functions)

`Config.luau` would require each part and copy its tables onto the one `Config` table. The 64 requiring files and
every `Config.X` stay as they are. `LandRide` alone (449 lines, 338 numbers) and `Jump` (295 lines) justify their own
files.

Risk: needs a play test. The sandbox panel (SandboxController, SandboxService "Tune") changes these tables live by
reference, and `Config.refresh` and the `Mix*` aliases depend on the same table objects. A copy that makes new tables,
or a helper that captured a sub-table early, would break live tuning without an error. Do it when no one else is
tuning the file; it touches every line of it.

## Not checked

- The 79 `Creatures/*.json` files.
- Whether the Config fields counted as used are really read for their meaning (the field check is a name match).
- Whether UI/Aim draws the warning pulse with its own numbers.
- The `TankRide.Reach` "server: 48" claim.
- The remaining client and server files beyond the grep lines quoted.
- Unused arguments inside functions, and the `SubModels.luau` and `Variants.luau` internals line by line (read in
  outline only).
