# Client UI audit (`src/client/UI/`)

26 modules, 18,849 lines (Tags 2,847, Kit 1,876, LandStrip 1,633, CatchShow 1,442, TankPanel 1,309 are the big ones).
Line numbers are the files as they are now: Kit, Shop, Tags and TankPanel include the section markers added in this
pass (comment lines only). Every module in the folder is required by something; none is orphaned.

## (a) Code map

| File | What it draws | Where / when | Created by (`require`) | Reads |
|---|---|---|---|---|
| Kit | Shared look: colours, fonts, plates, rings, glass boxes, rarity colours and styled words, land list, fail words, touch check | Not a screen; used by almost every UI file | HudController, Admin, Archetype, Fail, GroundFx, LongHook, Sandbox, Trainer, TankRide controllers; most UI files | Studio-only workspace attributes for look switches; `HudTouch` |
| Anim | Motion helpers: open/close spring, press, hover, bounce, punch, count-up, rise, toast, stagger, dim | Not a screen | Many UI files | none (no State, Net or attribute reads) |
| Shop | The "shop kit": dock-window frame (title bar, red X, fit-to-screen), buttons, pages, money labels, cards, ticks/arrows, carousel, plus the page router (`Shop.page`/`Shop.go`) | Not a screen | AuraShop, SellFish, ShopScreen, SubPanel, TankPanel, Slots, DockNotes, TankPrompt, UpgradeSign; StallController, AuraController | Studio attribute `PanelPhone` |
| Tags | Name tags over wild fish: rarity word, name, size/colour chip, "Required: n" oxygen line, red when too strong | Over fish in the world, every frame while near | HudController | `State`, fish attributes; Studio attributes `FishTags`, `RarityWord`, `SizeChip`, `ShineAt`, `WordClock` |
| TankPanel | "Your Tank" window: equipped and stored fish cards, sort, Equip Best, Put All In, sell, take out | On the dock near your own tank | AquariumController, StallController, TankRideController | Attributes `TankList`, `Hands`, `TankEarning`, `PlotStage`, `Plot`, `TankRide`, plot `PanelReach`; `Net.Action` "Tank"/"Sell"/"TankRide"; `Net.Ride` TankDenied/Sold; `State.Mode` |
| Aim | Centre-screen aim with the grab window as an emptying ring; red near the end | During the hop | HudController | Config |
| Banners | Miss words, end-of-dive title, new land name, catch banner; hands off to CatchShow / CaughtText / Kit.FailShow | Mid-screen after events | HudController | no literal attribute, Net or State reads (FadeText arrives from its caller) |
| CatchShow | End-of-dive show (look 5 builds DiveScreen) | After a dive ends | Banners | Studio `CatchLook` |
| DiveScreen | The live end-of-dive screen ("Drop" variant) | After a dive ends | CatchShow | Studio `DiveLook` |
| CaughtText | "Tamed" words on a catch (look 3 "Banner" live) | On a tame | Banners | Studio `CaughtLook` |
| Portrait | A creature's picture as a ViewportFrame of its model | Slots, banners, cards | Banners, CatchShow, CaughtText, SellFish, Slots, TankPanel | `FishIcons`, `FishType` attributes |
| FishIcons | Generated table of icon atlas pages (not edited) | Data | Portrait | none |
| HopButton | Big jump/grab button, keycap or HOP/GRAB word, red beat in last second | Lower right while riding | HudController | Config |
| HubButtons | Shop and Index buttons at the left edge | On the dock | HudController, StallController | no literal attribute, Net or State reads |
| HubSigns | Shows "YOUR TANK" on own sign, hides other plots' trainer signs; starts UpgradeSign | Hub, polled once a second | HudController | `Plot` |
| LandStrip | Strip of the ten lands across the top, your badge and best line | Top of screen while diving | HudController, SubController | `BestLands`, `BestMetres`, `State.Zones` |
| Rings | Time-left ring and tame ring beside the rider, hop-ready arc | While riding | HudController | Config |
| SellFish | Sell Fish page: sort, select all, card grid, total, Sell (n) | Sell stall on the dock | StallController, AuraController | `Net.Action`, `Net.Ride`, `State.Player` |
| ShopScreen | Robux shop: offers as cards, SOON until product ids exist | Hub Shop button | StallController | Shared/Products, `State.Player` |
| AuraShop | Aura stall: twelve aura cards in a row, prices "Soon" | Standing on the Auras stall ring | StallController, AuraController | `Aura`, `Coins`; `Net.Action` "AuraBuy" |
| Slots | Bottom-middle row of carried catches, chosen one ringed, "3 CAUGHT" | While diving | HudController, AquariumController, EquipController, CatchShow | `State.Caught` |
| StatRows | Coins and Oxygen rows with plus buttons | Lower left | HudController | no literal attribute, Net or State reads |
| SubPanel | Submarine stand shop: subs, price, Equip, GO TO land, RIDE WITH | At the sub stand | SubController | `Net.Action`, `Net.Ride`, `State.Mode/Zones/Player` |
| DockNotes | "GO TO YOUR TANK TO DEPOSIT" line and "TANK FULL!" pill | Middle of screen on the dock | StallController | no literal attribute, Net or State reads |
| TankPrompt | "<Name> is in your tank!" plate and "+$n/s!" chip | Over the tank when a fish goes in | AquariumController | no literal attribute, Net or State reads |
| UpgradeSign | Seahorse upgrade board (SurfaceGui): next seahorse model, cost, Robux blocks | On each plot's sign post | HubSigns | `Plot`; `Net.Action`, `Net.Ride`; `ReplicatedStorage.Remotes.Trainer` |

### How a screen is put together

- HUD pieces (Aim, Rings, HopButton, LandStrip, Slots, StatRows, Banners, Tags) are built by HudController under one
  `Root` frame whose UIScale is set from the screen size (HudController.luau:205-226). Kit itself sets no global scale.
- Kit supplies the look: colours, fonts, plates, rings, rarity words, the land list, and the "look switch" numbers
  (Kit.luau:348-430) that pick between option looks; in Studio, workspace attributes can override them.
- Anim supplies every open, close, press, hover and toast, so all windows move the same way.
- Dock windows use the shop kit in Shop.luau: `Shop.window(props)` (Shop.luau:383) builds the frame, title bar, red X
  and its own UIScale that fits the window to the screen.
- `Shop.page(name, open)` (Shop.luau:606) registers a window; `Shop.go(name)` (:610) opens one and closes the rest.
  AuraShop (:198), SellFish (:805) and ShopScreen (:292) register at require time.
- SubPanel (:332) and TankPanel (:833) use `Shop.window` but do not register with `Shop.page`, so they open themselves.
- To add a dock window: new module that builds with `Shop.window` and the Shop pieces, calls `Shop.page("Name", open)`
  at the bottom, and is required from StallController (which opens pages by stall or button).
- Shop pieces are also reused outside windows: Slots, DockNotes, TankPrompt, UpgradeSign.

## (b) Things to sort

Risk: "safe" = removal or rename that grep shows nothing live depends on; "play test" = touches what players see.

### Option looks still in the code (the biggest cleanup)

The look switches are decided (Kit.luau:397 CatchLook 5, :404 DiveLook 2, :414 CaughtLook 3, :420 FishTags 7, :430
SizeChip 4, :113 RingStyle 1, :95 OxygenBox 5, :348 LandStripStyle 1, :384 LandIntroLook 1). The other options are
reachable only through Studio attribute overrides.

| Where | What | Evidence | Action | Risk |
|---|---|---|---|---|
| Banners.luau:569-575, 657-664 | Old dive plate and old TAMED plate run only when look is 0 | `if look ~= 0 and ... CatchShow.play(...)`, same for CaughtText | Remove the look-0 fallbacks once the switches are fixed | play test |
| CatchShow.luau:1285 | BUILDERS 1-4 unused live; header :4 still says "Four looks" | CatchLook = 5 | Keep look 5 and its helpers, drop 1-4 | play test |
| CaughtText.luau:1029 | `{ punch, stamp, banner, burst, slam }`; only banner (3) live; Shake (:21) runs at :1097 from `show.shake` (helper: set only by slam; not re-checked) | CaughtLook = 3 | Drop the other four and the Shake require | play test |
| DiveScreen.luau | Variants 1, 3, 4 unused (Drop = 2 live; helper read, branches not re-checked); `DiveScreen.Variants` has no caller | DiveLook = 2; grep: Variants 0 uses in src or tools | Drop the unused variants | play test |
| Tags.luau:521 | `Tags.Looks` 1-6 and the stacked tag (option 0: make :136, clear :275, put :281, shape :318, room :337, clash :344, follow :393, tagged :468, give :477, the non-alt half of Tags.update :2689) | FishTags = 7 takes the alt path (makeAlt :2064, putAlt :2267, shapeAlt :2386) | Keep look 7, drop the rest | play test |
| Tags.luau:953, :1099 | Word FAMILIES 1-4 unused (RarityWords all 5); comment :833 still says four families; `Tags.Families` has no caller | grep | Drop families 1-4, fix comment | play test |
| Tags.luau:80 | `LOCKED_WHILE_RIDING = false` switch for a decided choice | constant | Inline and remove | safe |
| Tags.luau:2691 | `_zones` parameter not read (its own comment says so) | comment on the line | Remove parameter and argument | safe |
| Kit.luau:133, :236 | `Kit.RingStyles` 2-7 and `Kit.Boxes` 1-4 unpicked | RingStyle 1, OxygenBox 5 | Drop the unpicked entries | play test |
| Shop.luau:471 | `local centre = true` with the `else` branches unused | constant | Inline | safe |
| LandStrip.luau | Style 0, intro looks 2-5 and a drawn padlock fallback unused (from helper read; not re-checked line by line) | LandStripStyle 1, LandIntroLook 1 | Drop after a check | play test |
| Rings.luau | `SECONDS_ON_RING`, `NAME_UNDER_RING` false; TickTrail modes 0/1/3 unused (helper read, not re-checked) | constants | Inline | play test |

### Exported functions with no caller

From a loop over every `function Mod.x` and `Mod.x =` export in all 25 hand-written files, counting non-comment uses
across `src` (no module is required under a different local name, checked). This is the complete list of zeros.

| Where | What | Evidence | Action | Risk |
|---|---|---|---|---|
| Slots.luau:636, :48 | `Slots.chosen`, `Slots.Selected` | 0 uses in src and tools; header :11 says AquariumController uses it, but AquariumController uses only `Slots.Picked` (:100) | Remove, fix header | safe |
| StatRows.luau:24 | `StatRows.Pressed` | 0 uses; its comment :22 says "Nothing listens yet" | Wire the plus buttons or remove | safe |
| ShopScreen.luau:273 | `ShopScreen.isOpen` | 0 uses | Remove | safe |
| Kit.luau:507, :755, :1055, :42, :49 | `Kit.shade`, `Kit.oxygenCorner`, `Kit.bubbles`, `Kit.Lime`, `Kit.Space` | 0 uses anywhere; no `Kit[...]` dynamic reads in src | Remove | safe |
| Portrait | `Portrait.rendered`, `Portrait.kindOf` | 0 uses | Remove | safe |
| CaughtText, DiveScreen | `CaughtText.Names`, `DiveScreen.Variants` | 0 uses | Remove with the old looks | safe |
| Tags.luau:1104, :1190 | `Tags.wordStyle`, `Tags.chipLook` exported but used only inside Tags (chipLook also by one tools mock) | grep | Make local | safe |
| Test hooks used only by `tools/` | CatchShow.placeOf/press/showing, Portrait.Settings/reset, CaughtText.preview, LandStrip.preview, SellFish.press, SubPanel.toggle, UpgradeSign.press/refresh, TankPanel.toggle :807, notice :825, pretendMouse :1175, outlined :1182 | 0 src uses, 1-6 tools files | Keep but mark as test hooks, or move behind one test module | safe |

### Pictures and Studio-only paths

No sound ids anywhere in `src/client/UI/`. Every `rbxassetid://` and `rbxasset://` in the folder is listed below.

| Where | What | Action | Risk |
|---|---|---|---|
| Shop.luau:49-67 | `Shop.Textures.Icons = ""`; Studio falls back to `rbxasset://textures/ridefish/shop_icons_s1b.png` (:52), a file on one PC. A live game shows no window header icons (comment :22 says so) | Upload the atlas and set the id | play test |
| FishIcons.luau:9-14 | Icon pages empty; Studio paths `rbxasset://textures/ridefish/fish_icons_1..3.png`. Live game uses 3D model portraits (Portrait) | Upload or delete the path (FishIcons is script-generated: change the script) | play test |
| Kit.luau:361, :363 | `LandAtlas` is 124258870686064; `LandAtlasStudio` is a one-PC path; comment :357 "Not uploaded yet" is stale | Fix comment, drop Studio path if not needed | safe |
| LandStrip.luau:409-410 | Lock atlas id 99889688472050 set; one-PC `rbxasset://.../lock_atlas_k1.png` unused while id is set | Remove the path | safe |
| Kit.luau:55-67 | Uploaded ids: Studs 124244361010023, Water 6126332496, Oxygen 133981557523389, Cash 119031387165673, Shop 139519009824812, Index 136062585112653, Emboss 74391096180253. Header :6 "nothing new is uploaded" is stale | Check ownership moves with the game; fix comment | safe |
| Shop.luau:55 | `rbxasset://textures/ui/common/robux.png` is Roblox's own client file, works live | none | safe |

`RunService:IsStudio()` branches. Read and confirmed as Studio overrides or test hooks: Kit:1857, Shop:62/545/592,
Tags:1116/1144/2621/2724, TankPanel:744/1176. CatchShow:45, CaughtText:40, DiveScreen:55 read the look attributes
(:44, :39, :54). LandStrip:94/119/436 and Portrait:135: not re-checked.

### Unfinished features (money)

| Where | What | Evidence | Risk |
|---|---|---|---|
| ShopScreen.luau:7, :115 | Every Robux offer shows "Soon" | Shared/Products has 11 `Id = 0` | play test |
| AuraShop.luau:11, :99-100, :160 | Buying off, prices "Soon"; fires `Net.Action "AuraBuy"` | grep: no server handler for "AuraBuy" anywhere in src | play test |
| SubPanel.luau:363 | "SUBS ARE FREE FOR NOW!" | text | play test |
| HubButtons.luau:13 | Index button opens nothing: StallController:81-83 acts only on "Shop"; HubButtons:234-236 only hides the Index's red mark | grep of "Index" and HubButtons.Pressed across src | play test |
| UpgradeSign | Purple Robux block shown with no product (header :10-11 "there is no product yet", block built :251); reads `Remotes.Trainer` (:526) outside the Net module | header and grep | play test |

### Naming and structure

- Three "shop" files: Shop.luau is the window kit and router, ShopScreen.luau is the Robux store, AuraShop.luau the aura
  stall. Suggest renaming Shop.luau to something like `DockWindow` (wide rename; play test).
- TankPanel and SubPanel bypass `Shop.page`, so "one dock window at a time" does not cover them. TankPanel's `layout()`
  (:735) repeats the fit logic in `Shop.window`.
- Files doing two jobs: Kit holds the fail words (`Kit.FailLook` :1591, `Kit.failWords` :1636, used only by
  FailController); HubSigns also starts UpgradeSign (HubSigns:54); SubPanel is shop plus land picker plus fish picker.
- Section markers: CatchShow, CaughtText and DiveScreen use 117 dashes; FailController and the new markers use 118.
  Tags keeps an older `-- ====` marker.

### Duplicated helpers

- Easing curves: the same `at` and `backOut` (and more) are copied in CatchShow:53, CaughtText:48, DiveScreen:63; Kit
  has its own `outBack` (:1631). Move to Anim.
- `hex`: AuraShop:35, SellFish:105, TankPanel:322. JSON `decode`: SellFish:109, TankPanel:179, and inline in SubPanel `tankFish` (:57).
  `attr`: SubPanel:52, TankPanel:174. `SIZE_HUE`: SellFish:45, TankPanel:77, Tags:1159. Tags `PAL` (:893) copied in
  CaughtText. `local WordText = game:GetService("TextService")` in Kit (:621) repeats the service fetched near the top.
- Helper reads (not re-checked): `fit()` CatchShow vs DiveScreen, `block` StatRows vs HubButtons, specks DiveScreen vs
  CaughtText, the `workspace.ClaudeBlockout.Dock` walk in SubPanel, UpgradeSign and TankPanel.

### Text and phones

- All player text is hard-coded English, often built by joining strings ("LAND " .. n .. " OF 10", " METERS DEEP",
  "SOLD %s FOR %s" TankPanel:1252, "Required:" Tags:1597 with its width measured from the English at :1611). No
  localization table. Sort keys are shown as labels (TankPanel, SellFish).
- Slots.luau:357 cuts names by bytes (`string.sub(words, 1, 6)`), which breaks non-ASCII names.
- HopButton shows "Space" on the keycap; gamepad input is not reflected (helper read, not re-checked).
- Fixed pixels outside any UIScale: SubPanel:325 (220x20), :437 (520x32); TankPrompt:28 (420x104), :66 (170x38) on a
  BillboardGui. TankPanel's toast is 610 wide (:1051) inside a window that narrows on phones. All need a phone test.

Unfinished marks: searched TODO, FIXME, DRAFT, PLACEHOLDER and stand-in (any case): none used as a mark; the open
items are written as plain notes (listed under money above).

Not checked: performance (per-frame cost of Tags, Portrait viewports), memory leaks or connection cleanup, and
behaviour in play. Nothing was run in Studio.
