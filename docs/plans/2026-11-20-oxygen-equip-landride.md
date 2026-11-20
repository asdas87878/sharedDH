# Ride a Fish: oxygen, clicks, equipped fish and land locomotion

2026-11-20 · NULLROOM a0 · Astra planning/review contract for the implementation team.
Scope: plan only; no game code changed. Hugo's instructions in this mission supersede older land-cost and E-prompt notes.

## 1. Code and mission state checked before planning

Read `CLAUDE.md`, [Working together](../Working%20together.md), [Sessions](../Sessions.md),
[Handoff](../Handoff.md), [Findings](../Findings.md), [holding](../design/holding.md), and the relevant code below.
Local NULLROOM `mission_status` confirms both referenced missions are **done**:

| Mission/task | Delivered state | Contract for this mission |
|---|---|---|
| `4a8812a6/f1` | AquariumService Hold action; exact carried-entry tracking; HeldFish/HeldSize/HeldVariant/HeldIndex; replicated overhead model; HoldController arms; Slots.Picked | Reuse this holding path. Holding becomes preview/selection; Q commits the ride choice. f1's two-player check remains unperformed. |
| `4a8812a6/f2` | SubService.rideWith and diveFish read heldOf; RideService.DiveFish; temporary ridden copy retains kind/size/variant and leaves inventory intact | Replace held-first selection with equipped-first selection in **both** sub arrival and direct dive. Preserve trip timing/title work. |
| `2362bee3/s2` | UpgradeSign uses player-local SurfaceGui adorning UpgradeBoard; Cash and Robux are decorative Frames; TrainerController supplies E upgrade | Keep this sign's appearance; turn cash into a real action, remove E upgrade. |
| `2362bee3/s3` | TankPrompt draws the custom E/TAP prompt and deposit feedback; TankPanel has PUT IN, PUT ALL IN and earning EQUIP actions | Keep the shop style, replace placing hold/E with click/tap. Tank earning EQUIP is a separate concept from the new ride slot. |

Observed in this checkout:

- `Config.Oxygen`, `ZoneDrain`, `RarityDrain` (the replacement for historical TierDrain), and `required(zone,tier)` still produce area-dependent needs. `drainOf`, `secondsOn`, `strained`, `tameTime`, `grow` and `drainFor` depend on it. `FishType.Required` is baked from Home/Tier during construction and refresh.
- `Config.Train.Levels` already has 12 integer Oxygen values and placeholder prices, but `Train.Share = 0.004`; TrainService.gain awards `(rate + max*Share)*dt` every approximately 0.25 s. Removing Share alone would still award fractions. Trainer gain popups aggregate these fractions.
- `Train.Free = 1` deliberately bypasses cash deduction today. `TrainService` already validates owner, Dock state, distance and top level for remote `Trainer "Up"`.
- `Config.incomeOf` currently uses `required(Home,Tier) * PerRequired * sizeWorth * colour`. AquariumService caches income and ranks earners from it.
- `Slots` has **seven** visible inventory slots and a newest-seven window; Tame.Carry is seven. `Picked` fires for all clicks, `Selected` for filled clicks. AquariumController interprets a filled-slot click near the tank as immediate deposit.
- TankPrompt's clickable cap still calls InputHoldBegin/End on a ProximityPrompt; changing HoldDuration alone would leave E active. AquariumController creates PlaceFish with E and 0.25 s hold.
- `FishIcons` is generated atlas metadata with live-model fallback through Portrait; do not hand-edit it for a keyboard glyph. `Kit.Themes.Key`, Kit panels/text, and TankPrompt's Shop.button cap provide the existing visual language.
- AnimController owns procedural joint transforms, keyed swimming, body offsets and the rider's seat-chain lock in PreSimulation. Its fish discovery watches `Workspace.Fish`; a new hub mount folder needs explicit registration. Its Dock override currently covers TankRide only. HoldController separately writes shoulders/elbows.
- RideStyles has nine swim groups; those groups are too broad for land (Bobber includes Seahorse and pufferfish; Jetter includes octopus, squid and jelly; Paddler includes turtles and marine reptiles).
- All **82** current creature JSONs are accounted for in E4 below, including no-spawn BobbitWorm and Secrets. FeelLogController also handles number keys: audit debug/input focus before binding the hotbar.

These are source/readback findings, not a claim of a new Studio playtest. No running implementation task in the referenced missions needs waiting for.

## 2. Workstreams and acceptance tests

### E1 — Fixed training and intrinsic per-fish oxygen

**Owners/dependencies:** oxygen/config implementation owner first; coordinate all shared Config edits with E2/E3/E4 owners. Land determines what species spawn, never what an instance needs. Do not replace zone-of-spawn with Home in the formula: that would retain a hidden area factor.

**Training contract.** A level grants exactly its integer `Levels[level].Oxygen` once per completed **one seated second**. Set Share to zero and remove its influence in every training path, including the legacy stand-in pad. Server accumulates eligible seated time, awards completed ticks, and retains only subsecond time internally. Do not round each Heartbeat grant, which makes the result frame-rate dependent. MaxOxygen increases and Gain remote payloads are integers; stat labels show full grouped integers, no decimal K/M formatting.

On dismount/reset/death discard incomplete seated time. On upgrade settle elapsed completed ticks at the old level, then begin a new one-second tick at the new level. A delayed server update may grant several completed ticks as one integer total; it must not invent elapsed training while unseated. Keep the spring animation's visual cadence independent of economic ticks. This replaces the current approximately half-second gain popup with one popup per awarded second (or combined integer catch-up).

**Fish contract.** Introduce one pure shared resolver, proposed name `Config.requiredOf(kind, sizeTier, variant, special?)`:

```text
required = max(1, ceil(kind.OxygenBase
                       * RarityOxygen[kind.Tier]
                       * SizeOxygen[sizeTier]
                       * VariantOxygen[variant]
                       * product(approved special oxygen multipliers)))
```

`OxygenBase` is an explicit positive number for **every kind**, authored from its intended strength and animal identity. It is not generated from Home, current zone, depth, position, spawn time, or a zone index. Use the same size-tier label on carried records and models; never use a cosmetic held/tank scale. Rarity uses the kind's actual rarity. Approved special multipliers are an explicit server-defined allowlist, neutral 1 by default; do not silently make every passive or Swift affect oxygen. Variant is applied once; special multiplication must not apply the same variant again. Final requirement is one integer, rounded only once at the end.

Different kinds must have independently authored base values and visibly distinct baseline requirements. Rounding or modifier combinations may create equal values for some instances; “unique” means intrinsic to the individual fish's identity and properties, not a globally collision-free number encoding. Flag any equal **Normal/plain species baselines** for intentional review.

Separate the threshold from ride-duration rules: keep current StrainTime, refill, red-zone ticks, Tank drain benefit, cap and tame behavior, but feed them the resolved instance requirement. A Tank passive remains a duration benefit, rather than being counted again as a hidden threshold discount. Continuous drain rates and timers may be fractional internally; the whole-number request applies to awarded trainer oxygen and displayed/required oxygen, not rounding every simulation delta.

**Migration inventory (all must move together):**

| Surface | Required change |
|---|---|
| Config FishType.Required construction + config refresh | Store Normal/plain baseline only if retaining this field; never confuse it with an instance's resolved requirement. |
| FishModel.create; FishService spawn/size/variant application; held/tank/sub/owned copies | Set model `Required` after the instance's actual modifiers are known. Refresh on legitimate modifier/config changes. No later copying of the baseline over it. |
| Config.required, drain, drainOf, strained, grow, secondsOn, drainFor, tameTime | Replace zone/tier inputs with fish identity + instance modifiers or a resolved requirement; grow uses explicit starter reference 80, not required(1,Common). Remove runtime zone oxygen dependencies. |
| RideService landing/strained, tame length, normal/red drain | Resolve the actual wild/owned instance including size/variant. Retain sandbox EndlessAir behavior and existing duration model. |
| State.secondsOn / too-strong helper; HUD “needs”; both Tags presentation paths | Read the same actual instance requirement; changing zone cannot invalidate oxygen caches or change the displayed number. Tooltips and tag tint/hold-time classification agree with the server. |
| Aquarium incomeOf, cached Income, best-earner sorting, tank panels, deposit feedback, HUD $/s | Use intrinsic requirement; default income = requirement × PerRequired, without applying the requirement's size/variant premiums a second time. See economy option below. Recalculate existing session tank entries once after migration. |
| SandboxController oxygen controls, SandboxService config paths, balance/Studio check scripts and comments | Remove/relabel obsolete zone-cost controls. Update fixtures and old API callers; keep zone spawning/movement controls. |

Do not leave a compatibility fallback accepting `(zone,tier)` in production: it could keep tags and server divergent. Audit the whole tree for `required(`, `strained(`, `drainOf(`, `secondsOn(`, `drainFor(`, `tameTime(`, `.Required`, `ZoneDrain`, `RarityDrain`, historical `TierDrain` and `incomeOf(`. Document any surviving non-oxygen use. Speed/spawn area rules are outside E1.

**Acceptance E1:**

1. For all 12 levels, ten completed seated seconds award exactly 10 × the configured integer. Repeat at MaxOxygen 100 and 100,000, under different frame timings. 0.9 seconds awards zero; stepping off prevents later catch-up. Upgrade mid-tick follows the specified old/new boundary; legacy fallback follows the same rule.
2. Clownfish Normal/plain in areas 1 and 2 has identical requirement, label, too-strong verdict, tame time, income and drain at the same player max. Repeat with the same legendary instance in test areas 6 and 10, regardless of natural spawn eligibility.
3. Enumerate 82 kinds × 6 sizes × 4 variants; all results are positive integers, deterministic and monotonically increasing with chosen size/variant multipliers. No missing bases or accidental default fallbacks. Check species baseline duplicates.
4. At requirement−1 the fish is strained; at requirement it is not. Client verdict equals server verdict for Tiny/plain and Colossal/Rainbow samples. Existing too-strong landing still works.
5. Spawn, hold, equip, ride on land, enter tank, direct dive and sub handoff preserve actual size/variant/requirement. Modifiers are applied once in income, including existing tank entries after refresh.
6. All dependency searches are reviewed; no active oxygen calculation reads current zone or Home. Existing oxygen ring/tick and Tank passive regression checks pass.

### E2 — Click/tap placing and clickable upgrade sign

**Owners/dependencies:** UI/interaction owner after coordinating s2/s3 delivered files. Trainer gain logic remains E1's. Use existing server actions; the client never charges money or grants levels.

- Remove the TrainerUpgrade E ProximityPrompt and its update loop from TrainerController. On UpgradeSign's cash block use an actual GuiButton/Activated action inside the existing PlayerGui SurfaceGui with Active enabled. Only the nearby owner's non-maxed sign can request `Trainer "Up"`; show pending until acknowledgement, then refresh its level/price. Disable while pending so a double-click cannot accidentally buy multiple levels. Server checks remain authoritative and should reject overlapping duplicate requests.
- Cash behavior uses existing `Train.Free` policy: when 1, show FREE and grant without charge; when 0, charge exactly the next level's listed Price, once, only on successful upgrade. Both branches must be tested. Activating paid mode is a Hugo option, not an implicit economy decision.
- Robux block remains visual-only: no Activated purchase action, Marketplace call, remote, debit or optimistic upgrade. At max level show MAX LEVEL and no actionable cash/Robux purchase.
- Replace placing ProximityPrompt input with click/tap on the existing shop-styled place control on the tank front. Keep distance, owner, Dock, capacity and fish ownership server checks. E press/hold must have no placing effect; a mouse/touch click must not require a hold timer.
- A filled inventory click or number key always selects/holds, even near the tank. Deposit only through an explicit “PUT IN TANK” click/tap or TankPanel PUT IN/PUT ALL IN. Remove the near-tank Slots.Selected auto-deposit listener and prevent the tank popup's world-click handler from also firing on the place control.
- Tank empty-hand practice riding is an existing separate action. Preserve its behavior through an explicit click/tap affordance when replacing the combined prompt, rather than silently deleting it. Keep TankPrompt.deposited feedback. No other unrelated game's E actions need removal.

**Acceptance E2:**

1. E press and hold beside trainer/tank neither upgrade nor place. No stale E label or filling hold bar appears. One click/tap deposits exactly the shown/held inventory fish. A rejection leaves it in inventory and shows the reason.
2. Cash click works free and paid; insufficient coins, too far, another plot, dead/underwater and maxed level refuse. Rapid double-click cannot charge/buy twice while pending. Successful upgrade retains the rider and animation.
3. Click the Robux area repeatedly: no purchase prompt, no remote, no charge, no level change. Cash and Robux hit targets do not overlap.
4. Number selection at the tank holds rather than deposits; tank card PUT IN and PUT ALL IN still work. Filled/empty tank practice controls remain reachable by click/tap.
5. Exercise pointer and touch, including a narrow viewport, sign distance/occlusion, own versus other signs, and tank popup click propagation.

### E3 — Number-key selection, Q equip and one ride slot

**Hugo (2026-11-20), binding:** "not holding 1 and pressing q at the same time, 1 should be first inventory slot while q should be a completely seperate slot." Two separate key presses, never a chord: press 1 (or any number) → that inventory fish is held over the head; then press Q → it moves into the equipped slot. Key 1 is always the first inventory slot; the Q slot is its own slot outside the numbered row, never counted as slot 1 and never reached by a number key. No code may require a number key to be held down while Q is pressed.

**Owners/dependencies:** inventory/equip owner defines identity/API first; E2 uses that selection path; E4 and SubService consume equippedOf. Reuse f1's overhead pose and ownership validation.

**State contract:** “selected” is the UI highlight; “held” is a carried fish displayed overhead; “equipped” is the committed ride fish. A number/click changes selected/held only. Q while holding commits that **exact inventory entry**, clears its overhead display and mounts it in the hub on land. Q on a different held fish replaces the mount. The new far-left slot displays only the equipped fish and a small Q keycap, separated by a small gap from numbered slots. Empty: show a neutral fish silhouette/hint “Hold a fish, then Q”. Use Portrait/FishIcons fallback and the current square rarity/rim treatment; create Q using existing keycap/button styling, not a new icon upload or editing generated FishIcons.

Recommended layout: `[Q equipped]  [1] [2] [3] [4] [5] [6] [7] [8] [9]`. Nine selectable UI positions; keep current **seven-fish carry cap** by default, so 8/9 are empty until capacity changes. This avoids silently changing catch balance; Hugo can choose nine capacity below. Slot key labels must track visible positions, never a hidden shifted list index. There is currently no carry paging beyond seven; if capacity later exceeds nine, implement explicit paging before showing only a hidden tail of the list. On phones fit/scale the ten-slot row or use an accessible compact layout; keep touch targets practical and all nine numbered positions reachable.

Bind 1–9 (plus keypad equivalents if supported) once on InputBegan, ignore repeat, gameProcessed and focused TextBoxes. Number selects/holds corresponding slot; same held slot or an empty slot clears hold, never the equipped choice. While mounted, selecting another fish may briefly dismount to show the overhead pose; retain old equipped reference until Q commits replacement. Do not let HoldController and a riding pose write the same arms simultaneously. No inventory deposit on number keys. During underwater rides/hops/sub transit, do not repurpose number keys into live wild-fish switching: reject/ignore holding/equipping until Dock. Audit FeelLogController number capture and UI modal input so one key cannot do two actions.

**Identity and lifecycle:** add server `equippedOf(player)` returning the validated entry descriptor, not trusting client species/size/variant. Prefer a stable per-catch ID; f1's exact table-entry reference is sufficient for current session-only storage if indices are recomputed and every mutation invalidates it correctly. Do not identify an owned fish only by `{Id,Size,Variant}`: duplicates exist. Replicate EquippedFish/EquippedSize/EquippedVariant plus stable entry identity (or current index) for the UI. Equipment is a reference to one inventory fish, not a second inventory copy or extra capacity. The fish remains counted once in carried catches; the equipped portrait is an alias.

Default equipped-slot click/tap toggles hub mount on/off (SPACE may dismount too); it retains the equipped choice. Provide an explicit UNEQUIP affordance on that slot for clearing selection. Q with no held fish can remount the equipped fish, otherwise does nothing. Dismount before trainer seating, tank practice or opening an action that needs ordinary walking. Keep one mount/seat owner at a time. Reject Q while trainer-seated rather than starting two rides.

Deposit/sell/removal of the equipped entry clears the equip reference and destroys its land mount atomically; removing another entry preserves it. Death/reset clears holding, mount and equipment by default (same session model as f1). Dismounting, entering water, or a successful trip hides/destroys only the land visual; equipped identity persists through the dive and is revalidated on returning Dock. Player removal cleans connections/models. Reject another player's entry, stale index/id, removed entry, non-Dock and duplicate equip requests.

**Dive/sub integration:** snapshot the validated equipped descriptor at departure. Direct dive and sub arrival both use it instead of `heldOf`; the merely held preview must not override the equipped fish. Preserve f2's same kind/size/variant and temporary ride-copy semantics; owned inventory remains unchanged after riding/taming/failure. Land visual must be gone before the dive/sub owns a body. If there is no equipped fish, retain the existing tank RIDE WITH fallback for sub trips; a mere held fish no longer supplies a direct-dive mount. If the snapshot becomes invalid before departure, refuse/clear it; while in transit freeze inventory mutations or revalidate before spawning.

TankPanel's existing EQUIP/EQUIP BEST determines which tank fish **earn**. Keep those server actions distinct from ride equipment; relabel/help text if needed so the new Q slot is unambiguous.

**Acceptance E3:**

1. Each key 1–9 and matching slot tap chooses the corresponding visible fish or clears hold when empty. Same-slot toggles hold; focus in chat/search and debug capture prevent game action. Near-tank selection never deposits.
2. Hold A → Q: A appears left with Q and is ridden on land, no overhead copy remains. Hold B without Q: ride choice stays A; Q replaces with B. Merely selecting a slot never silently changes the next dive's equipped choice.
3. Two identical catches: equip the second, remove first, and verify the second survives at its new index; remove second, and equipment/mount clear. Stale/malicious requests fail without state changes.
4. Walk/ride, stop, dismount/remount, trainer seat, tank practice, reset/death and two-player observation leave one mount and one pose writer per player. No stuck PlatformStand/weld/hidden avatar or orphan fish.
5. Equipped Colossal Gold fish survives direct dive and sub-to-area-2/10 with the same descriptor/requirement, inventory count unchanged. Held preview cannot override. Test empty equipment and tank fallback separately.
6. UI review on desktop and a small phone: far-left equipped distinction, Q cap/icon style, 1–9 mapping, no HUD overlap, touch equip/dismount reachable. Test actual two-player replication, which f1 did not cover.

### E4 — Land movement by animal body type

**Owners/dependencies:** land-mount/movement owner consumes E3 identity and owns server hub movement; animation owner coordinates changes to AnimController/RideStyles/HoldController. These are procedural on the **existing creature joints**, with no new uploaded animation assets. AnimController supplies body motion and rider lock, not gameplay translation.

Keep hub land mounting distinct from underwater Riding and TankRide while remaining compatible with the Dock state needed for hub actions. Proposed replicated attributes: LandRide model identity, rider id, locomotion profile and movement state; do not make new state names without auditing every Dock check. Server validates ownership, hub bounds, reasonable speed and one rider; collisions/ground-following belong to the movement owner. Use a raycast with self/mount exclusions and a stable ground clearance derived from rest-pose bounds. Cap slope tilt and blend across small steps. Lost ground/large drops use a safe dismount or water transition, never permanent hovering.

Default all land mounts use the same hub travel speed 32 studs/s, matching the proposed hub walking pace, so animal scale/underwater speed cannot make a giant uncontrollably fast. Cycle cadence follows actual horizontal movement and stops into an idle pose at rest. Root movement remains smooth; flops/hops are body-joint offsets that the rider follows through the existing seat chain. No accumulating CFrame offsets: apply from stored rest transforms every frame. Suppress underwater wave/fits/buck layers on land. Blend land/swim over approximately 0.2 s; ground-contact clearance and saddle/rider alignment must survive this blend.

Register hub fish with the animator explicitly (current Workspace.Fish discovery will miss them). Reuse near-camera throttling and cached rig metadata; no per-frame tables, remotes, constraints or new parts. Establish one writer for each Motor6D and a land-aware rider pose so HoldController/Roblox Animate cannot overwrite it. Missing optional limbs get a bounded profile-specific body motion and a developer warning; missing joints must not error or silently leave an entire species without animation.

**Complete roster-to-profile contract (82/82; no duplicate memberships):**

| Land profile | Species IDs | Required readable motion |
|---|---|---|
| Fish flop-hop (18) | BlueChromis, SergeantMajor, YellowTang, Butterflyfish, Clownfish, FlyingFish, Angelfish, Parrotfish, Lionfish, Garibaldi, Viperfish, HumpheadWrasse, GiantSeaBass, GoliathGrouper, Barracuda, Swordfish, Xiphactinus, Dunkleosteus | Side-to-side body flop, short forward-looking visual hops and tail flick; heavier restrained flop for armoured/big fish. FlyingFish opens fins on hop. |
| Turtle slide (3) | SeaTurtle, Archelon, GraveTurtle | Belly/shell slides close to floor; alternating front/back limb paddles provide the push; little shell roll. |
| Seahorse tail-hop (1) | Seahorse | Upright body; tail compresses/curls then extends for a small hop; nose/crest reacts, rider remains seated. |
| Tentacle crawl (2) | Octopus, Kraken | Staggered tentacle plant–pull–release waves; mantle rocks forward between pulls. Kraken slower/heavier. |
| Squid/cuttle scoot (2) | GiantSquid, Cuttlefish | Front arms plant and pull; mantle lifts briefly and scoots, fin edge ripples. Distinct from octopus spreading crawl. |
| Ray shuffle (5) | Stingray, MantaRay, ElectricRay, CinderRay, GraveRay | Wing edges press alternately into ground with low body shuffles; tail trails, no airborne swimming. |
| Eel/serpent/worm slither (12) | MorayEel, BrimstoneEel, WraithEel, PearlSerpent, StormSerpent, EmberSerpent, CoralDragon, LanternLeviathan, BoneLeviathan, KelpWyrm, Basilosaurus, BobbitWorm | Travelling ground-level S-wave; head leads and tail trails. BobbitWorm gets segment compression ripple; long-bodied whales/dragons use lower frequency. |
| Crab/crawler (3) | SeaScorpion, GiantIsopod, Anomalocaris | Alternating side legs with phased rear-to-front wave; body stays low. SeaScorpion adds claw reach; isopod many-leg shuffle. No crab species exists yet; a future crab must get an explicit assignment. |
| Shark wriggle-lunge (12) | ReefShark, LeopardShark, GreatWhite, HammerheadShark, Sawfish, Helicoprion, GoblinShark, FrilledShark, Megalodon, MoltenMegalodon, HalfboneMegalodon, HellfinShark | Strong tail sweep pushes a low chest lunge; side fins brace. FrilledShark uses a longer travelling wave; giant sharks have heavier slower recoil. |
| Whale/dolphin heave (9) | Dolphin, Orca, BlueWhale, GalleonWhale, Livyatan, Shonisaurus, VoidWhale, PhantomWhale, StellersSeaCow | Belly heave and flipper push, short settle/glide; gentle tail flex rather than full swim stroke. Dolphin quick, giant whales weighty. |
| Marine-reptile belly crawl (6) | Mosasaurus, Dakosaurus, Elasmosaurus, Liopleurodon, Kronosaurus, SeaLion | Opposed flipper plants with torso slide; neck/head leads for Elasmosaurus, SeaLion stronger front-flipper pull. |
| Bulbous waddle-hop (7) | Boxfish, Pufferfish, Anglerfish, InfernalAngler, SkullAngler, AbyssalWatcher, Hellmaw | Alternating low rolls and stubby fin braces, small rounded hops; angler lure lags and Hellmaw lands heavily. |
| Jelly pulse-scoot (1) | AuroraJelly | Bell compresses/extends, fringe reaches floor then pulls it forward in short scoots. No floating swim cycle on dry land. |
| Colossal monster stomp-drag (1) | TheDevourer | Low heavy heave, appendage brace and body drag, restrained yaw; readable distinct weight rather than scaled fish flop. |

Profiles are baselines, with per-kind amplitude/cadence/limb overrides. Rarity/passive archetypes such as Tank/Fast are not body anatomy. Audit actual rig part names before choosing limb roles; list missing joints in review. The coverage table does not require changing meshes.

**Acceptance E4:**

1. Automated roster enumeration reports each of the 82 species assigned exactly once; no fallback-only species, including Secrets/BobbitWorm. Every profile runs on existing rigs and placeholder rigs without errors.
2. Record side/front clips for one per profile, plus turtle, small fish, octopus, seahorse, and giant extremes. Their required motions must be identifiable without species labels. Review per-kind variation within shared profiles.
3. At rest the movement cycle settles; accelerating/turning/stopping blends, with no foot/body sinking or free-floating swim wave. Ride across flat ground, slope, hub small steps and plot boundaries; body and rider stay aligned through hops.
4. Tiny Clownfish through Colossal whale/serpent: no displaced seat, ground clipping, camera occlusion that makes riding unusable, runaway speed or map escape. Mount cannot collide with its own rider or fling others.
5. Two clients see the same rider/mount and broadly synchronized cadence, and still see f1 arms when genuinely holding. Near/far animation throttling preserves visible continuity; compare frame cost before/after with several hub riders.
6. Land → direct dive, land → sub, return → hub, trainer and tank practice restore the correct animation/controller with no duplicate fish, joint writer, orphan mount or stuck movement.

## 3. Hugo's options, defaults and sample tables

These are proposed balance/UX defaults, **not approved economy numbers**. Implementation can proceed with named configuration dials and current placeholder values; no need to stop mechanical work for every tuning answer. Hugo may say “use defaults” or override rows. His explicit requirements (no area oxygen factor, fixed whole training gains, clicks, Q slot, body-type land motion) are not optional.

| Decision | Recommended default | Alternative / consequence |
|---|---|---|
| A. Training cadence and curve | One integer award per seated second; retain current 12 gain/price placeholder rows below | Pick a new gain/price curve after comparing early/mid/late play time. Half-second ticks would require a separate whole-number-per-tick table and different sign units. |
| B. Fish modifier strength | Rarity from current RarityDrain values, modest size/variant table below; explicit species bases | Gentler top-end rarity spread needs retuning every base against trainer progression. Never restore Home/zone multipliers. |
| C. Earnings coupling | Coins/s = intrinsic required × 0.025; no repeated size/variant multiplier | To preserve old premium earnings, define separate **residual** income multipliers and show their combined effect. Reusing old multipliers directly would compound the new oxygen premiums. |
| D. Carry capacity | Keep 7 carried catches; nine numbered positions supported, 8/9 empty | Raise cap to 9 to fill all nine positions: changes catch capacity and balance and needs narrow-phone layout testing. Equipped slot remains an alias either way. |
| E. Cash economy | Keep Train.Free=1 for current testing; cash block says FREE and works | Set Free=0 after choosing prices: cash charge/insufficient-funds checks already part of acceptance. Robux remains inert either way. |
| F. Land ride speed / size | Common land speed 32; preserve true fish size initially | Slower giants or capped cosmetic land display size can improve hub clearance, but require an explicit visual scale that never affects oxygen/inventory identity. |
| G. Equip behavior | Q commits and mounts; slot click toggles mount, explicit UNEQUIP clears; death clears equipment | Q could only equip and require another click to mount, but adds an action. Keeping equipment after respawn is possible with validated ownership cleanup. |

**A: current placeholder trainer table, retained by default.** “Gain” is the amount added per completed seated second, never a percentage of max.

| Level | Seahorse | Gain | Price for this level |
|---|---|---:|---:|
| 1 | Toy | 4 | 0 |
| 2 | Painted | 6 | 100 |
| 3 | Saddled | 10 | 300 |
| 4 | Racer | 15 | 1,000 |
| 5 | Iron | 25 | 3,000 |
| 6 | Spiked | 40 | 10,000 |
| 7 | Knight | 60 | 30,000 |
| 8 | Royal | 100 | 100,000 |
| 9 | Golden | 150 | 300,000 |
| 10 | Abyssal | 250 | 1,000,000 |
| 11 | Starfire | 400 | 3,000,000 |
| 12 | Prismatic | 600 | 10,000,000 |

**B: proposed modifier tables.** These are design multipliers; only the final fish requirement is shown as a whole number.

| Axis | Values |
|---|---|
| Rarity | Common 1; Uncommon 1.25; Rare 2.5; Epic 4.5; Legendary 15; Mythic 50; Secret 150 |
| Size | Tiny 0.8; Normal 1; Big 1.2; Giant 1.5; Huge 2; Colossal 3 |
| Variant | Plain 1; Silver 1.25; Gold 1.5; Rainbow 2 |
| Special | None 1; only explicitly approved specials get another multiplier; sample special 1.2 is illustrative, not a new feature |

**Illustrative species bases and outputs, not a complete 82-species balance table:**

| Fish | Base | Rarity | Size / variant / special | Required | Coins/s at 0.025 |
|---|---:|---|---|---:|---:|
| Clownfish | 80 | Common | Normal / plain / none | 80 | 2 |
| Clownfish | 80 | Common | Tiny / plain / none | 64 | 1.6 |
| Clownfish | 80 | Common | Giant / Gold / none | 180 | 4.5 |
| Clownfish | 80 | Common | Colossal / Rainbow / none | 480 | 12 |
| YellowTang | 90 | Common | Normal / plain / none | 90 | 2.25 |
| Seahorse | 52 | Rare | Normal / plain / none | 130 | 3.25 |
| ReefShark | 120 | Epic | Normal / plain / none | 540 | 13.5 |
| Dunkleosteus | 200 | Legendary | Normal / plain / none | 3,000 | 75 |
| Dunkleosteus | 200 | Legendary | Big / Silver / none | 4,500 | 112.5 |
| BlueWhale | 600 | Mythic | Normal / plain / none | 30,000 | 750 |
| Kraken | 900 | Mythic | Normal / plain / none | 45,000 | 1,125 |
| Clownfish (special example) | 80 | Common | Normal / Gold / ×1.2 | 144 | 3.6 |

Coins/s may retain decimals; Hugo asked for whole oxygen, not a coin-currency redesign. Final implementation must supply the full species base table and a generated output audit before balance acceptance. A fish in another area uses the **same row**, not a second area-specific row.

## Orchestration, handoffs and review gate

1. Agree shared interfaces first: instance oxygen resolver, exact carried-entry identity, equippedOf and land-mount lifecycle. Each owner names actual files before edits. One writer for Config; combine owner patches serially. Do not race edits to AquariumController, Slots, SubService, RideService, AnimController or HoldController.
2. Build E1 pure config/resolver and its migration as one coherent change. E2 can prepare sign/tank hit targets separately, then use E3's unified hold/selection contract. E3 must replace f2's two heldOf consumers before declaring ride equipment complete. E4 can author profile data independently but depends on E3 mount ownership to test moving riders.
3. For handoff, implementation owners provide changed files, checks run, known failures, missing rig roles, and short visual evidence. Run repository formatting/lint on touched Luau and focused resolver/ownership/tick checks; do not claim lint replaces Studio input/physics tests.
4. Astra reviews against every E1–E4 acceptance item: **pass, fail, or unverified**, with source/test evidence. Block completion on area-dependent oxygen, fractional trainer grants, E placing/upgrading, decorative-only cash action, merely held fish overriding equipped, missing body profiles, or duplicate mount/pose ownership. Balance remains explicitly provisional until Hugo chooses/plays it.
5. Integrator owns consolidated Sessions/Handoff/design updates and Studio scheduling; this planning task owns only `docs/plans/`. This plan intentionally does not edit the other owners' notes/code or claim uploads, commits, publishing or new Studio results.

## Hugo's corrections after E2/E3 (2026-11-20, binding; mission follow-up)

- Tank (on `docs/attachments/e2-tank-click.png`): hovering the tank outlines the WHOLE tank; no "CLICK / PUT IN TANK" prompt and no click-to-add. Clicking the tank just opens the tank GUI.
- Hotbar (on `docs/attachments/e3-hotbar-holding.png`): back to the original number of inventory slots (before E3), centred exactly where the original row was; the Q slot sits a little to the side of that row, not shifting it.
