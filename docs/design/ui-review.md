# UI review 1: every screen, against Ride a Dino (2026-11-22)

Up: [UI](ui.md). Asked by the user, 2026-11-22: "do a large scale review of the ui in our game and try to improve it, get
more of a studded style. leave the inventory bar alone but suggest improvements. ... look for lazy design, design that
differs too much from ride a dino, designs that arent consistent and designs that signal AI involvement. And we also need
to focus on getting the UX UI part of the animations a lot better ... For now the shop button opens up the sell dinos and
auras UI's. This is wrong, they should pop up when you stand on the stands corresponding to them in game. The shop UI is
a seperate thing ... if we have a deposit fish UI, make sure its formatted liek ride a dino".

How it was done: every module in `src/client/UI/` and the controllers that open them read through (two surveys), and
the reference measured from the user's 30 fps recording and cached video frames (one new fetch). The reference's full
measurements are kept privately with the frames (they quote its screens); what we take from it is below. We take its
**build, behaviour and timings**, never its art, words or exact colours.

## What Ride a Dino does (what we copy)
- **One frame for every panel:** a dark border about 8 to 10 px with small rounded corners; a header strip about 10%
  of the screen's height, a vertical gradient with a darker lip at its foot, a near-black outline about 3 px, and
  faint square studs; a white heavy title with a black stroke; a red square X; a dark studded body. Each panel has its
  own header colour (selling green, auras lavender, index and shop sky blue).
- **Buttons follow the header's recipe:** green = buy, equip, claim; grey = can't; red = unequip; yellow-orange = Robux.
- **How screens open:**
  - **Sell, Auras, Fuse:** stand on the stall's coloured floor circle and the panel opens; walk off and it closes.
    These dim the world and the HUD to about half, fading over about 0.2 s.
  - **Shop and Index:** from the hub buttons, no dim.
  - **The pen panel:** docked at the right, no dim, no X; it comes up when the pen is full.
  - **Upgrade stands:** no screen; the sign is the whole UI.
- **Motion (fitted from 30 fps frames, about 0.03 s either way):**
  - Stand panel opens with a spring from the centre: about 30% at first sight, about 110% at 0.2 s, about 98.5% at
    0.47 s, settled by 0.6 s.
  - Closing on walking off: it swells to about 108% then collapses to nothing, about 0.27 s in all.
  - Shop opens about 75% to 105% to 100% in about 0.3 s.
  - Hub buttons: about 12% darker and 5% wider under the mouse; about 0.96 for 0.1 s on a press.
  - Panel buttons: no hover; a purchase squashes the button to about 88% of its height for 0.1 s.
  - The red "!" bounces every 1.8 s: a squash, a 12 px stretched hop with a 15 to 20 degree wobble, a landing squash,
    and a ring that grows and fades over 0.2 s; each bounce about 0.6 s.
  - Selling: the button greys ("Selling..."), the total counts down over about a second (fast first), the cards go one
    by one over about 0.4 s throwing cash icons, a big green "+$N" pops and drifts up, then the empty state.
  - The HUD's cash snaps to its new value; income ticks are small numbers that drift up and fade over 0.5 to 0.7 s.
- **Depositing:** while carrying a catch home, the middle of the screen reads "GO TO YOUR PEN TO DEPOSIT". At the pen,
  Roblox's own prompts: deposit, manage, ride. On success a line "<Name> is in your pen!" with the name in green, a
  "+$N/s!" chip, and the money ticking up. When the pen is full: a "PEN FULL!" pill and one short line saying what to
  press, popping in over about 0.17 s, with the pen panel at the same moment.

## What we have, by the user's four questions
Line numbers are as of 2026-11-22.

### 1. Lazy design
- **No shared motion at all.** The only shared tween is `Kit.pulse` (`Kit.luau:1060`). The same hand-written easings
  are copied into `CatchShow.luau:53-77`, `CaughtText.luau:48-82` and `DiveScreen.luau:63-98`; `badge()` three times
  (`Banners:109`, `CatchShow:145`, `CaughtText:288`).
- **Things that snap instead of moving:** every window closes by switching off (`Shop.luau:488`); toasts and hints
  only switch `Visible` (`SellFish:703-706`, `TankPanel:1209`, `SubPanel:474`); the Index "!" never moves
  (`HubButtons:177-214`, `237`); `HopButton`'s arrow flips at once (`:155-175`) and the button has no press; "FIND A
  FISH!" (`Aim:76`); the tags' lock and state colour (`Tags:2460-2491`); the tame ring (`Rings:583`); the land strip's
  current tile (`LandStrip:1519-1532`); no money ever counts (`StatRows:299`, `SellFish:379`, `TankPanel:625`,
  `SubPanel:114`).
- **Placeholder content shown to players:** every aura card has the same bubble icon and three discs, and every price
  reads SOON (`AuraShop:38-65`, `98-100`); "SUBS ARE FREE FOR NOW!" (`SubPanel:363`); the sub stand opens from a plain
  Roblox prompt (`SubPanel:290-297`) and its ticket and hint are bare yellow text with no plate (`:324-330`, `:436-443`).
- **Empty states are a sentence** (`SellFish:620`, `TankPanel:899`); labels pushed right with spaces (`SellFish:523`);
  section heads glued with double spaces ("Stored  3", `TankPanel:677-683`).
- **Dead controls:** the Index button and the stat rows' plus buttons fire, and nothing listens (`HubButtons`,
  `StatRows:22-24`).
- **In a live game the shop kit's pictures are missing:** `Shop.Textures` is empty (`Shop.luau:28-51`), so every
  window falls back to the water picture and shows no header icons. Only Studio shows them (local copies).

### 2. Differs too much from Ride a Dino
- **No studs where it counts.** Kit's stud tile exists (`Kit.luau:36`) but only three Kit themes use it, at 70 to 88%
  see-through, and no dock window or live HUD piece calls them. The shop kit put bubble dots and fish scales in place
  of studs on purpose (2026-11-20, [UI](ui.md), "Shop style"); the user now asks for studs.
- **Sell and Auras open from the Shop button as two tabs of one window** (`HubButtons:155-157` to
  `AuraController:1047-1050` to `Shop.go`); the reference opens each by standing on its stall's circle, and its Shop is
  a separate screen. The stalls are already in the hub (`Dock/Stations/Sell` and `Auras`, each with a floor `Ring`:
  `tools/map/hub_kit.py:944-956`, `980`), unused.
- **No dim behind a stand panel; no spring on open; no close at all.** Ours pops 0.86 to 1 in 0.16 s.
- **The deposit:** we have the line over the tank ("<name> in your tank!", `TankPrompt`), but no "go to your tank"
  line while carrying, no "+$N/s!" chip, and no "tank full" moment.

### 3. Not consistent
- **Outline colour, three of them:** `Kit.Ink` (16,36,63) in the HUD, `Shop.Edge` (10,12,22) in the shops, pure black
  in `HubButtons` and `StatRows`, near-black (6,8,14) in `Slots`, the catch tiles and the ring border.
- **Corner radii:** 0, 1, 4, 5, 6, 8, 9, 10, 11, 14 and 999 across the screens (HubButtons 1, windows 10, sign 14).
- **Stroke weights:** 1.2 to 6; text outlines at size x 0.19 in Kit and x 0.13 in the shop kit.
- **Money green, six of them:** `Shop.Money`, `Kit.Cash`, `Kit.Good`, `Kit.Lime`, `Shop.Kinds.Cash`, `StatRows` FACE.
- **Fonts:** FredokaOne (the Kit), GothamBlack (tags, slots, "CAUGHT!"), Bangers (end of dive, fail), LuckiestGuy
  (metres). The land strip's intro is GothamBlack where the end of dive uses Bangers.
- **Press feedback, three kinds:** a 0.94 scale snap (`Shop:292-301`), a 1 px shift (`HubButtons:150-154`,
  `StatRows:167-171`), a 0.12 s scale (`UpgradeSign:543-546`). No hover anywhere but the slots (1.06 in 0.12 s).
- **Open speeds:** 0.16, 0.22, 0.28, 0.32 to 0.38, 0.35 s, Back or Quad, no rule.
- **Words:** "Auras", "Sell Fish", "Your Tank" against "SUBMARINES"; "Select All", "Sell (n)" against "SELL", "EQUIP
  BEST"; "Sort By:" against "Sort by:"; "METERS DEEP" against "m".
- **Two sell flows that look different:** the shop's green "Sell (n)" and the tank card's red SELL, each with its own
  SURE?.
- `UpgradeSign` and the Oxygen row use TextScaled, against the Kit's own rule (`Kit.luau:7`).

### 4. Signs of AI-made UI
- **Glitter:** spinning diamond sparks beside the Legendary words (`Tags:1269-1281`, `1947-1971`), sparkle specks on
  the catch plate (`CaughtText:763`), two diagonal gloss streaks on every shop surface.
- **Typographic tells:** " · " separators (`LandStrip:996`, `1052`), "\u{2022}" in "Tier n • Sub" (`SubPanel:218`),
  "✓" ticks (`SellFish:257`, `564`).
- **Over-explaining:** the "equipped can't be sold" rule said three times (`SellFish:219`, `259-281`, `575`); notes
  written as full sentences; long all-caps toasts with colons ("ALL PLACES TAKEN: UNEQUIP ONE OR UPGRADE YOUR TANK",
  `TankPanel:1176-1189`); "NONE: FLING ME" (`SubPanel:82`).
- **Cheerful filler:** "Dive in and catch some!", "Pick a sub, pick a land, jump in!", "You caught %d fish!", "+$x a
  second", "holds 1.2 s".
- (Not a tell: "Required:" is the reference's own word.)

## Kept, on purpose (recorded picks, not faults)
The tag's look 7 and its Gotham Black rarity words with Legendary and up moving (Hugo, 2026-11-14), the Oxygen box in
the corner (Hugo's option 5), the catch screen option 3, the land strip's G4 pictures. Restyles of those are proposals
below, not done. The unused looks and options (CatchShow looks 1 to 4, CaughtText 1, 2, 4, 5, Tags 1 to 6, LandStrip
style 0, Kit RingStyles 2 to 7 and Boxes 1 to 4) stay in the code: they are Hugo's to pick from.

## The inventory bar (left alone; suggestions only)
1. A new catch flies into its slot and the slot punches (1.15 back to 1, Back, 0.25 s); the count beside the bar bumps.
2. A press squashes the slot (0.94 for 0.08 s) as every other button will.
3. The caught slots wear the stud plate (the empty ones stay glass), so the bar reads as the same family as the windows.
4. The X as an icon, not a letter; the near-black outline to the one outline colour.
5. Shorter hints: "HOLD A FISH, THEN TAP" and "CLICK TO RIDE" to one or two words, or a picture.
6. Names never cut to "Great.": a smaller size for long names before cutting.

## The plan (this pass)
1. **`UI/Anim.luau`, one module for motion:** open (the reference's spring), close (swell and collapse), press, hover,
   the "!" bounce, count up, float up and fade, the stand dim. Every screen uses it; the copied easings go.
2. **One studded frame** in the shop kit's window (`Shop.window`), so every dock window gets it at once: the stud tile
   on body and header, one outline colour, one radius set, our own header colours and icons.
3. **The stalls:** Sell and Auras open when you stand on their floor ring and close when you walk off (a wider ring to
   leave than to enter, so the edge doesn't flicker), with the dim; their tabs go. The Shop button opens the Shop, its
   own screen.
4. **The deposit,** formatted like the reference: the "go to your tank" line while carrying, the success line with the
   "+$N/s!" chip, a "tank full" pill.
5. **Words:** the tells and the over-explaining in section 4 cut; one case rule (titles in capitals, as SUBMARINES).
6. **The dive HUD gets motion only** (the hop button's press and arrow turn, "FIND A FISH!", the tame ring, the land
   strip's tile); its restyle and fonts are proposals for the user and Hugo.

Checked in Studio by numbers (the open curve sampled each frame, stepping on and off a ring fast, leaving the dock with
a window open). A script can't hover or click: those need the user's hand.

## What was built (2026-11-22, this pass; the UI chat)
All in `src/client/UI/` unless named; lint clean; checked in Studio by numbers (below). Hover and press were read by
numbers with a scripted mouse; not played by hand. Three Studio passes (2026-11-22, all clean in the console):
the stalls open and close on their rings (open peaks about 1.10, settled by about 0.8 s from stepping on, poll lag
included), the hub button hovers to 1.05 with its shade and presses to 1.05 x 0.96, the dim reads 0.5, a sale's total
only falls and its "+$N"s clear, the deposit line and "+$N/s!" chip read right, "TANK FULL!" shows and goes after 2 s,
the "!" hops 12 px with a wobble (now timed by the clock, every 1.8 s), and in a dive the hop button dips to 0.88 on
Space and its arrow turns in about 0.14 s. Not built: the cards leaving one by one, the tame ring. Not checked: a
phone layout. The Shop's offers are placeholders (every Id 0).
- **Motion:** `Anim.luau` as planned. Every dock window opens and closes through it; every `Shop.button` hovers and
  presses through it (the old 1 px dip is gone); the hub buttons grow under the mouse with a shade and press; the red
  "!" bounces; toasts pop in and shrink away; the tank's line pops in. Selling: a green "+$N" rises over the sell
  button for each fish sold, the button punches, and the total runs down after.
- **The studded frame:** `Shop.window` has a grey border plate (`Shop.Border`, rim 6), one outline colour (`Kit.Edge`),
  one radius set (`Shop.Round`), the stud tile (`Kit.Textures.Emboss`) on header, body, buttons and cards at set sizes
  (`Shop.Studs`). Gloss only on the Shop's header. The "✓" glyph is a drawn tick (`Shop.check`).
- **The stalls:** `Controllers/StallController.luau`. Sell and Auras open on their ring (`Dock/Stations/<name>/Ring`,
  2.5 studs wider to leave), close on walking off, with the dim; X keeps it shut until you step off and on. The Shop
  button toggles the Shop. Leaving the dock closes all. The tabs are gone. `AuraController` opens nothing now.
- **The Shop:** `ShopScreen.luau` with the offers in `src/shared/Products.luau` (Featured, Packs, Passes, Oxygen,
  Cash): wide cards and rows of three, vivid gradients, a sunburst. Every Id is 0, so each button reads Soon. To sell
  one: make the product or pass, write its id and price in Products, and give the server its grant (ProcessReceipt or a
  pass check). Nothing in the client grants anything.
- **The deposit:** `DockNotes.luau`: "GO TO YOUR TANK TO DEPOSIT" while carrying a catch on the dock with no window up;
  a pink "TANK FULL!" pill with one line when the tank is full. `TankPrompt` reads "<name> is in your tank!" in green
  with a green "+$N/s!" chip.
- **Words:** buttons and section heads in title case ("Equip", "Sort By", "Stored (3)"), toasts and alerts in capitals
  and short ("UNEQUIP IT FIRST", "HANDS FULL"); the over-explaining notes cut ("Pick a Sub", "No fish yet").
- **The dive HUD, motion only:** the hop button grows under the mouse and dips on every press (mouse, finger or key);
  its arrow turns over in 0.15 s between HOP and GRAB; "FIND A FISH!" pops in and out; the land strip (the live look,
  style 1) pops the new land's tile (no slide: its rail and markers are placed from the same spots and would lag). **Not done:** the tame ring. **Not run in a
  dive:** these HUD motions were only linted, not seen.
- **After the look check (Fable, 2026-11-22):** cards a step lighter than the body (`Shop.Card`, as the reference's
  mid-grey cards), the studs quieter on body and cards, the Off buttons a recessed grey (never louder than a live
  one), the Select All mark and the card tick square boxes, and the tag line one plain word or two (the usual size
  says nothing, so it is left out). The dark border stays: the reference's is dark.

- **The studs' fade and the Shop's "!" (the user, 2026-11-22: "ours is just like very homogenous stud, stud, stud";
  "Is it possible to do the bouncing exclamation point on the shop?"):** every stud surface fades from full at its top
  to fainter at its foot (a UIGradient on the tile, `Shop.Studs` Tail; the hub buttons the same), so a surface reads
  lit from above. A body starts at 0.12 and is plain by its foot; headers keep the most. The study
  ([ui-motion-and-studs](../reference/ui-motion-and-studs.md)) found no big game that fades its studs (they turn them
  down, or tint them with a colour gradient), so the fade is ours. The Shop button wears the same bouncing red "!"
  as the Index, up on each arrival at the dock until the Shop is opened. Checked in Studio (pass 5: readback of every
  stud layer, mark up on arrival, no errors; `docs/attachments/ui-studs-fade.png`).

- **The cards' stagger (the user, 2026-11-22: "Card stagger", first pick from the transitions study):** as the
  Sell window or the Tank panel opens, its cards pop in one after another (`Anim.stagger`, numbers in
  `Anim.Stagger`: 0.08 s in, 0.04 s apart, each from 0.4 to full with a little overshoot; only the first 12, all in
  by about 0.6 s). Only on opening: a pick, a sale or a refresh doesn't replay it. Grids only: a grid scales a card
  about its middle and leaves the rest put, while a list moves every card after it (measured in Studio), so the
  Shop's list and the Aura and Sub carousels don't stagger. Checked in Studio (pass 6: scales sampled in order and
  all ending at 1, close and reopen mid-stagger, a sale with the window open, a held card draws nothing).

- **The quicker open and the shine (the user, 2026-11-23: "build the shine sweep but also make the ui animation as it
  appears (for example the shop ui popping up) a bit faster. Not just a speed increase but make it a bit less elastic
  and slightly more responsive"):** a window now opens from 0.7 to a 104% peak about 0.14 s in, settled by about
  0.37 s (was 0.3 to 110%, 0.7 s; `Anim.Open`); the dim and the cards' stagger are quicker to match. The user's word
  overrides the reference's stand-panel spring. Closing is unchanged. The spring waits for the first frame drawn, so a
  first build can't swallow it. The shine (`Anim.shine`, `Anim.Shine`): two thin streaks cross a button in 0.7 s,
  0.5 s after it lights and every 4 s, only on a button that takes or gives money AND works now: Sell with fish
  picked, the Sub's next Buy, an Aura's price (none priced yet), the hub's Shop button once its "!" is down, your own
  plot and seahorse signs when affordable and near. Nothing in the Shop window shines until an offer is on sale. Off
  with Roblox's Reduce Motion. Checked in Studio (2026-11-23: open curve, stagger, when each button shines and
  doesn't, `docs/attachments/ui-shine.png` mid-sweep; the streak's end when its button goes dead was 0.15 s late, now
  next frame, checked in Edit). Not tested: a sub that can't be paid for (the place has `Sub.Free` = 1), another
  player's plot. Studio ran at 15 to 48 fps and nobody has played it by hand.

Still proposed (the user's or Hugo's call): the dive HUD's restyle and fonts; the inventory bar's suggestions above;
the server's sell check near the stall (raised with the game-code chat); the Shop's real offers and prices.
