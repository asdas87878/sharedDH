# Handoff

What each push changed, so whoever pulls next knows where things stand. Newest first. Every hand-made push gets an entry
here; the Obsidian Git plugin's own "vault sync" commits don't need one.

## 2026-11-13 · a NULLROOM worker (Hugo's PC, task p3): seeing through props, measured
**State:** the rework's game code (`Config.Props`, `PropService`, `PropController`) was already on main; this
adds its check. **No game file and no number changed:** the run showed no bug. Changed: the test
(`tools/studio/props_b1`: the driver, a new `server_watch.luau`, the README) and the notes. StyLua and selene pass
on the test. Committed on Hugo's PC, not pushed by hand (main was 4 commits behind origin: the partner's paces
and visit; Obsidian's sync does the pull). Measured by script in Hugo's Studio on grey-box 15, on the code as it
was on this PC before that pull; **not played by hand**. Nothing uploaded.
- **Measured, the last of four runs, 20 passes, no failed check, no script error** (only the old asset type
  warning on `203785492`); all of it in [the playtest](playtests/2026-11-13-props-see-through.md):
  1. In the way: 0.00 see-through until the body is inside the prop, then 0.65, one fade and back, one shake
     (0.38 at 43 studs a second, 0.45 to 0.52 on a Reef Shark), the fish not slowed (43 and 43, 70 and 70).
  2. Beside: 0.65 at 4, 8 and 12 studs, 0.00 at 17, 25 and 42 (`SideNear` 12); a box kept between the camera and
     the fish 0.65, off that line 0.00, back on it 0.65.
  3. The loose boxes: 0.65 inside 12 studs of the player, 0.55 at 12 to 18, 0.3 at 18 to 24, 0 from 30.
  4. A Breaker, a Tank and a giant broke 12, 12 and 14 boxes of the prop; a Clownfish, a Reef Shark and the rider
     in the hop (off a Clownfish, off the Sea Cow) broke none and flew at the same share of the hop's own curve
     inside the prop as before it (1.03, 1.03).
  5. Own screen only: in 643 looks at all 14,111 prop boxes the server never held a changed `Transparency`, a
     `LocalTransparencyModifier` or a flying copy. **Two players in one server were not run** (memory).
- **To know (Hugo):** a touch gives no shake if another prop shook under `Props.ShakeGap` (0.7 s) before. On the
  Reef Shark's line to the test's coral that happened in six of eight passes (a big prop 0.5 to 0.6 s earlier):
  the coral turned see-through at the touch with no shake of its own. `ShakeGap` is the number if every big prop
  should shake.
- **The test's own faults, put right** (they were the "miscounts" of the run before): shakes at other props on the
  way counted for this one; the hop's speed read with the jump's rise in it; a speed read from the fish's tail,
  which swings when it turns; a Predator's burst running out read as a slow-down; a prop the megalodon could not
  be steered to. `suite3`, `view` and the server watch are in the test's README.
- **The Studio place:** the test scripts are out (checked by script). **On disk:** Studio's auto-recovery file of
  17:01, written in Edit after the scripts were removed, copied to `~/Documents/RideAFish/ride-a-fish-map.rbxl`
  and `~/Projects/sharedDH-local/ride-a-fish-map.2026-11-13-1701-after-props-p3.rbxl`; the file before is in
  `sharedDH-local/backups/` (`...1446-before-p3-save.rbxl`). A plugin still can't save: **Hugo presses Ctrl+S**.
  The run's logs are in `~/Projects/sharedDH-local/playtest-logs/` (not in the repo).
- **Not mine, left as found:** `src/client/UI/Kit.luau` and `Rings.luau` were changed and not committed on this PC
  during the afternoon (the playtests ran with them).

## 2026-11-13 · a NULLROOM worker (Hugo's PC, task u1): the Oxygen and tame pieces, flat with a thin outline
**State:** built; StyLua passes, selene has no warning in these files. Run by script in Hugo's Studio through the
studio runner (before and after, the same slowed ride: air draining, a tame filling, the red part, drowning); **not
played by hand**. Nothing uploaded; the test script is out of the place.
- **Hugo:** "edit the capturing and oxygen ui to have a little less detail -> no gradient thin outline". Read as:
  the two rings beside the rider and the Oxygen row, nothing else (the Boss's reading, for Hugo to correct).
- **`Kit.luau`:** `Kit.Style.Flat` (one colour, a 1.2-point outline, no bevel, no shine), on in `Kit.Themes.Oxygen`;
  `Kit.Outline.Hair` = 1.2; `Kit.ring` has a sixth argument `plain` (the dark line without the pale one).
  **`Rings.luau`:** both rings are built `plain` with the hairline. No other file changed: `StatRows.luau` gets the
  flat row through the theme, `Aim.luau`'s ring is as it was.
- **Seen:** [the sheet](attachments/ui5-flat-before-after.jpg); the design note is
  [ui.md](design/ui.md), "The Oxygen and tame pieces with a little less detail".
- **To know:** the row's warning beat is its outline's colour, so on a 1.2-point outline it is much quieter than
  before. The row's bubbles, the water's picture and the bubble sign are kept.

## 2026-11-13 · a NULLROOM worker (Hugo's PC, task h1): the hop as one curve
**State:** the code went out with Obsidian's own sync (`2a83610`, "vault sync from void", before it was measured:
the plugin is running on Hugo's PC again); the notes, the picture and the tools follow in this push. StyLua passes,
selene has no warning in these files, `rojo build` passes. Measured by script in Hugo's Studio through the studio
runner on grey-box 15 and the partner's new herd; **not played by hand**. Nothing uploaded; test scripts out.
- **Hugo, after playing the three-part air:** less of the fish's speed carried over, a slightly smaller boost, a
  bit slower overall, and a falloff that ramps off slowly and comes to a slow stop.
- **`Config.hopFrom`** now returns three things (speed leaving, extra seconds, apex): `Launch` 0.85 x the fish's
  speed + `HopBoost` 15, never under `AirShare` 0.6 x its ridden speed + `BoostFloor` 8. There is no glide's pace
  any more. **`Config.hopKept`** (new) is the curve, **`Config.hopSpeed(t, launch, extra)`** and
  **`Config.hopSink(t, extra)`** have new arguments. Anything else that calls them must follow
  (`JumpController` and `RideService` do).
- **`Config.Jump`:** new `SpeedHalf`, `SpeedTail`, `StopTime`, `StopShare`, `SinkCurve`; changed `Launch`,
  `HopBoost`, `AirShare` (new meaning: the least), `BoostFloor`, `FallSpeed` 80, `FreeLaunch` 60, `GrabFullSpeed`
  120; gone `FastKeep`, `FastCurve`, `StallTime`, `StallShare`, `FallGravity`, `AirSpeed`, `FreeAirSpeed`. The N
  panel's rows follow. A Leaper's `Air` now multiplies the speed it leaves at.
- **Measured:** flown hops match the formula (67, 117, 225 studs off a 40, 74 and 138 fish; they were 136, 268,
  557); no change of speed over 2 studs a second between frames; 38 landings with no second hook; 6 of 6 hands-off
  slow hops landed; the server's reach check right 7 of 7; the new herd's spacing is as the old one's. All in
  [the playtest](playtests/2026-11-13-hop-air-reach.md), "The one curve"; the design in
  [riding feel](design/riding-feel.md), "The one curve".
- **To know:** a hop is about half as long as before, and you fall behind the herd in it.
  `tools/balance/model.py` and `tools/playtest/archetypes/client.luau` still model the old hop (other chats' files).
- **Not touched:** the partner's animations, the wall glide, the camera, the props, the wait between fish.
- **Checked after (task h2, the same day):** the code against Hugo's list, the server in step with the client
  (`RideService` counts `Config.hopSpeed` and `reachOf` from its own clock), the logs against the note. The
  picture's caption sat on the column titles: redrawn (`hop_curves.py`, plots moved down). On "not the full
  speed, a slightly smaller boost": the hop left at 1.6 x the fish's speed + 18 (82, 136, 239 off a 40, 74, 138
  fish) and leaves at 0.85 x + 15 (49, 78, 132): 85% carried, the kick 3 less, the hop a little faster than the
  ride off slow fish and a little slower off the fastest. Left there: lower and a normal fish's hop is slower
  than the ride, which is no boost. `Jump.Launch` is the one number if Hugo wants less carried still.

## 2026-11-13 · a NULLROOM worker (Hugo's PC): Hugo's Studio place rebuilt after a crash, and now on disk
**State:** Hugo's Studio is open again on the Ride a Fish place, in Edit, and **the place is on disk**. No game
file changed; nothing uploaded. Only this note is in the commit.
- **What was lost:** the PC ran out of memory at about 14:27 and took Studio with it. The place had never been
  saved: the file on disk was from 2026-11-11 03:10 (before grey-box 9). Nothing in the repo was lost.
- **How it was rebuilt:** from Studio's own auto-recovery file of 14:27 (it held grey-box 15, the code and the 82
  creatures with their Gold and Rainbow templates). Then, in the open place: Rojo on 34873 synced `src/` (every
  script the same size as its file); `python tools/studio/load_greybox.py runner` loaded grey-box 15 again from
  the files on main (103 files, 0 problems, 59,002 parts, the water's script newer than the recovered one). The
  creatures were not installed again: no mesh changed since `install.py runner --local` of 2026-11-12, Studio is
  the same version, and all 3 x 1,365 MeshParts point at mesh files that are there.
- **Checked:** the herd's stream on this map (`herd_stream_test.py`'s code through the runner; the script itself
  calls the partner's Windows client and does not run here): 3 to 7 degrees per 100 studs, worst 31, 0 places
  over the edge or under the floor. One playtest by script: no errors (the old asset type warning on `203785492`
  only), 56 fish, a mount on a Clownfish, a hop onto a Sergeant Major in 1.2 s, 1,915 props. **Not played by
  hand.** The test scripts are out of the place.
- **Saved, and where:** a plugin can't save a place opened from a file, so the save is Studio's next
  auto-recovery file (14:46, after the rebuild, in Edit), copied to `~/Documents/RideAFish/ride-a-fish-map.rbxl`
  and to `~/Projects/sharedDH-local/ride-a-fish-map.2026-11-13-1446-rebuilt-greybox15.rbxl`. The old disk file is
  in `sharedDH-local/backups/` (`...2026-11-13-1437-old-disk-file-from-1111.rbxl`). **Hugo: press Ctrl+S in
  Studio once**, and after any session whose place state matters.
- **To know:** a playtest of this place left about 600 MB of the PC's 15 GB free with the swap full. One Studio,
  and no other heavy job (a compile, a second game) while it plays. After a crash: copy
  `~/.var/app/org.vinegarhq.Vinegar/data/vinegar/appdata/Roblox/RobloxStudio/AutoSaves/ride-a-fish-map_AutoRecovery_0.rbxl`
  over the place file and move it out of that folder before starting Studio.

## 2026-11-13 · a NULLROOM worker (Hugo's PC): the merge of the partner's herd, sizes and water with Hugo's props and hop
**State:** merged by hand and **pushed to `origin/main`** (Obsidian is not running on Hugo's PC, so nothing syncs
there by itself). Both sides are whole: the partner's four vault syncs up to `85b5be8` (the herd's stream, the six sizes and Silver,
the bigger kinds and the grand fish, the water's fog; the fourth came in while the first three were being tested
and was merged the same way) and Hugo's commit `0ca31d4` (props, the hop). StyLua and selene pass, `rojo build` passes. Run in
Hugo's Studio through the studio runner on grey-box 15, by script; **not played by hand**. Nothing uploaded; the test
scripts are out of the place.
- **`FishService`: the partner's file, whole,** with one condition changed. A wild fish inside a prop breaks it when
  **both** sides' rules say so: its kind breaks props (Hugo: `Config.breaks`, a Tank, a Breaker or a giant;
  `Props.WildBreaks` 0 turns it off) **and** the fish itself is at least `Herd.BreakLength` (40) long (the partner).
  `Config.smashes`, which the partner's code still called, went with Hugo's commit. Hugo's old place for this
  (`mindObstacles`, `mindOne`) is gone with the partner's rewrite.
- **What that changes for each side, to judge:** for the partner, a long wild fish that is no Tank, Breaker or giant
  (a Basilosaurus, a Bone Leviathan) now swims through a prop and leaves it whole. For Hugo, all 16 kinds that
  break are 40 or longer at Normal size, so they break; only a Tiny one of five kinds is under it and leaves the
  prop whole (Archelon, Humphead Wrasse, Sawfish, Aurora Jelly, Grave Turtle). Ridden, every one of the 16 breaks
  as before, whatever its size. `Herd.BreakLength` 0 gives Hugo's rule alone.
- **`Config.volumeOf`: the giants stay Hugo's 16.** A fish's `Size` is now its export times the partner's
  `Config.BaseScale` (1.2 to 2.6), and a volume grows with the cube of that: left alone, 44 of the 82 kinds would
  have been giants and broken props, where Hugo chose 9 giants (16 kinds that break, with the Tanks and Breakers). `volumeOf` takes the
  scale out again, so `Props.GiantVolume` is still measured on the exported box. A fish's rolled size (Tiny to
  Colossal) does not change who breaks either. Open, for Hugo and the partner: whether size should count.
- **Not changed, to know about:** `Config.Angry.GiantLength` is the partner's 68 (Hugo's 40, raised with the
  kinds' sizes; their entry below says which kinds). `Config.Variant` is the partner's (Silver 1/12, Gold 1/50, Rainbow 1/250), as their entry below says.
- **The panel:** no row twice, every row has its number; `Props` and the `Herd` and `Spawn` rows are both sides'.
- **Measured (the final merged code, and the same before the fourth sync):** the game starts with no errors (the
  old asset type warning on `203785492` only); the herd near the dock turns 3 degrees in 4 seconds on average
  (worst fish 6 to 10), sizes Tiny to Huge and a Silver and a Gold seen; the props suite as in
  [the props playtest](playtests/2026-11-13-props.md): a Clownfish and a Reef Shark through a whole prop at 0.65
  see-through, the Wrasse, the Sea Cow and the Molten Megalodon break all of it, props back 4.5 s after leaving;
  wild fish held 3 s inside a prop: Humphead Wrasse 14 of 16 boxes out, Steller's Sea Cow 13, Molten Megalodon 2
  to 5, Bone Leviathan (long, no breaker) 0, Clownfish 0; a hop from a Megalodon onto a wild Seahorse and from the
  Wrasse onto a Butterflyfish; the Wrasse's `Archetype` is "Breaker", its Smash boost and the Reef Shark's Eat
  fired; with the air draining a Clownfish got `Angry` and `AngryStyle` "Zigzag".
- **As before the merge, to know:** a wild fish looks for props only inside one of the map's 243 big things'
  circles (`BigAssets`, `Stream.inside`). The other props in `Lane.Props` (1,915 models in all) a wild breaker
  swims through whole; a ridden one breaks any of them.
- **Not checked:** by eye, anything. The lands past the second. `tools/studio/herd_stream_test.py` (it goes through
  `run_luau.js`, the partner's PC).
- **The partner:** pull, then sync your Studio as usual. Nothing of yours was replaced.

## 2026-11-13 · a NULLROOM worker (Hugo's PC): props, only Tanks, Breakers and giants break them; the rest go through
**State:** on Hugo's word of 2026-11-13. Run in Studio by script through the studio runner on grey-box 15
([the playtest](playtests/2026-11-13-props.md)); **not played by hand, and no one has seen the fade or the break
yet**. StyLua and selene pass. Nothing uploaded; the test scripts are out of the place. Not committed or pushed by
hand (the vault's own sync carries it). The rules: [riding feel](design/riding-feel.md), "Props: who breaks, who
goes through"; who qualifies: [archetypes](design/archetypes.md), "Who breaks props". One row in
[Decisions](Decisions.md).
- **Who breaks** (`Config.breaks`, shared by server and clients): a Tank, a Breaker, or a giant (model box of
  `Props.GiantVolume` = 12,000 cubic studs or more, from the creature's `mesh.json` size); a row of
  `Config.FishStats` may carry `Breaks = true/false` to override. 16 of 82. `python tools/creatures/check_breaks.py`
  prints the list. `Config.smashes` and `Props.MinLength` are gone.
- **Everyone else goes through:** `Lib/Course`'s rays leave `Lane/Props` out for every fish and for the hop
  (`Course.begin` takes no argument now), and so does the server's crash ray (`RideService.checkCrash`). No stop,
  no slow-down, no Oxygen. The wall glide never sees a prop.
- **The approach fade** (new `client/Controllers/PropController`): by the player's own distance, on their own
  screen, to `Props.FadeTo` (0.65, Hugo's pick from the sheet). One spatial query ten times a second; it writes
  `LocalTransparencyModifier` on a box and its Textures, never `Transparency`. Not on a fish that breaks props
  unless `Props.FadeForBreakers` is 1.
- **Breaking** (`PropService` rewritten): the server no longer moves any box. A box that is out carries the tag
  `PropOut` and isn't solid; its prop's Model carries `BreakAt`, `BreakVel`, `BreakT`, and `RebuildT` when it is
  back. Each machine hides the tagged boxes and throws its own copies of them (under the camera, not solid, not
  seen by rays), which fade and are removed. A Breaker is paid as before; a Tank or a giant pays the small crash
  (`Props.Slow`, `Props.Cost`).
- **Regenerate:** when no player has been within `Props.RegenRadius` (300) of the prop for `Props.RegenDelay`
  (3 s), the tags come off and the boxes fade in. `Props.Rebuild` (the fixed 8 s) is gone.
- **Numbers:** all in `Config.Props`, all on the N panel. The sandbox's F list now has Steller's Sea Cow (Tank),
  the Molten Megalodon (a giant with no archetype) and the Blue Whale.
- **For the partner (the map):** nothing of the generator or the loader changed, and the props need no new tag
  or attribute from it. The game finds them as before, by name: `ClaudeBlockout.Lane.Props`, one Model a prop,
  its boxes anchored parts inside. A reload of the map while the game runs is fine (the broken list drops props
  that are gone). If a prop ever gets parts that are not solid on purpose, they will never break (only
  `CanCollide` boxes do).
- **For the animations:** nothing of the partner's was touched. The fish's `Smash` attribute still counts up only
  for a Breaker's paid smash; a Tank's or a giant's break is a "Crashed" to its rider, as a prop was before.
- **For the UI chat:** a fish's tag does not say that a Tank or a giant breaks props (`Shared/Archetypes`'s
  `Does` lines are as they were). `Config.breaks(fish)` is there to ask.
- **Open:** small props (sea grass, floor tiles) also cost a Tank or a giant the small crash, see the playtest
  note; two players at one prop were not run; the rebuild fades in only (no scale-in).

## 2026-11-13 · a NULLROOM worker (Hugo's PC): a short wait between fish, the hop flies fast then stalls and falls, the hook's reach by speed
**State:** on Hugo's hand-play of 2026-11-13. Run in Studio by script through the studio runner on grey-box 15;
**not played by hand**. StyLua and selene pass. Nothing uploaded; the test scripts are out of the place. Not
committed or pushed by hand (the vault's own sync carries it). The numbers and the old and new curves:
[the playtest](playtests/2026-11-13-hop-air-reach.md). The rules: [riding feel](design/riding-feel.md), "The wait
between fish, the air's shape, the hook's reach". One row in [Decisions](Decisions.md).
- **The wait between fish** (`JumpController`, `RideService`, `InputController`): `Jump.Cooldown` is 0.08 s counted
  from the touch (the pull-in's end), not 0.3 s from the mount: the lock is only the gap until the landing
  animation starts. The server asks half of it after its own mount. A fish too strong for you keeps 0.3 s
  (`Jump.StrainLock`, both sides): `Oxygen.StrainTime` must stay shorter than the lock, or such a fish is a
  stepping stone. The second hook is still shut by `HopGuard`; and a held Space or gamepad A is now one press
  whatever the frame rate (`InputController` reads the key going down; the mobile button still uses `InputGap`).
- **The air** (`Config.hopFrom`, `Config.hopSpeed`, `Config.hopSink`; `JumpController` flies them): fast for the
  whole glide (`FastKeep`, `FastCurve`), then the stall (`StallTime`, `StallShare`), then a fall (`FallGravity`,
  `FallSpeed`). `BoostHold`, `BoostTime`, `Drop`, `DropCurve` and `DropSpeed` are gone from Config and the panel.
- **The hook's reach** (`Config.reachOf`; `Lib/Lock` takes the reach as an argument): `Jump.GrabNear` 60 with no
  speed to `Jump.GrabRange` 150 at `Jump.GrabFullSpeed` 180, by the speed across the water each frame. It was 180
  always. The ring thins out near the edge of the reach (`Jump.RingEdge`); `State.Reach` holds the reach in a hop
  (the sandbox shows it; free for the HUD). After the fast part the lock takes any fish in reach, all round
  (`Lock.LastChance`), so a hop that aimed at a fish too far still finds a near one.
- **The server** (`RideService`): the grab's range is `Config.reachOf` of the hop's own curve, from the server's
  clock and the speed it saw the fish go at. New: it measures the ridden fish's speed itself, from where it sees
  the fish go (`RideSpeed`): the velocity it read at the hop's word before was the hopping rider's, not the fish's
  (that had only made its window a little long). `Net.ReachLag` (0.2 s) is the lag allowance on the shrinking reach.
- **For the UI chat:** `State.Reach` (studs, nil outside a hop) is there if the reticle should show the reach.
  `HudController` was not changed; its `Ready` still divides by `Jump.Cooldown`, now 0.08.
- **For the partner (animations): nothing of yours was changed.** A hop can now begin 0.09 s after a landing, so
  the fish's landing reaction and the rider's brace (`Animation.Brace` 0.45 s) are often cut by the next hop's
  pop. `State.JumpPhase` still says Pop, Glide, Drop; the Drop is now a stall and then a real fall (up to 90
  studs a second down), which may want its own pose.
- **The test driver** (`tools/studio/movement_w1/`) gained `spacing`, `air`, `relock`, `rate`, `serverreach`, and
  a cadence on `mounts`. `tools/movement/hop_curves.py` draws the old and new curves from the formulas.
- **Left:** the fall ends on the sea floor with a stop in one frame (the camera barely shows it), and you lie
  there until the window ends; the window itself is as long as it was.

## 2026-11-13 · Obsidian chat integration (the user's PC): six sizes and Silver, 24 of every fish; the kinds' own sizes
**State:** on the user's word of 2026-11-13, with their screenshot of the reference's Index. In the user's Studio
place (synced, 132 scripts) and run there on grey-box 15 by script; **not looked at by eye**. StyLua and selene pass,
`rojo build` passes. Nothing uploaded. Not committed by hand. All of it, with the odds worked out and every number:
[sizes](design/sizes.md). One row in [Decisions](Decisions.md).
- **`Config`:** `Config.BaseScale` (new: each kind's size times the creature chat's export, 0.85 to 1.6, all 82);
  `Config.SizeOrder`, `SizeChance`, `SizeScale`, `SizeWorth` (new; `SizeWorth` is read by nothing yet);
  `Config.Variant` is now `Silver` 1/12, `Gold` 1/50, `Rainbow` 1/250 (**Hugo's 0.03 and 0.008 are replaced**);
  `Config.Speed.Silver` 1.05; `rollSize`, `sizeScale`, `sizeWorth`, `sizeTierOf` (new); `rollVariant` and `speedOf`
  know Silver. `Herd.SmashLength` 60 (40), `BreakLength` 32 (24), `Spawn.BigLength` 20 (16), `BigFull` 80 (44).
- **`FishService`:** every new fish rolls a size; `resize` scales the model and its seat (Hugo's own function of
  2026-11-12, back); `Wild.SizeTier`, and `Wild.Body` is the fish's own; the model's `SizeTier` and `Size`
  attributes. The herd's rules go by the fish's own length. Studio: `Workspace`'s `TestSize` and `TestVariant`.
- **`Shared/Variants`:** Silver, as a tint with a sheen (no baked meshes: `tools/creatures/local_meshes.py` and
  `install.py` are untouched, so Hugo's place tints Silver too).
- **`UI/Tags`:** the name line reads "GIANT Gold Great White". **`SandboxController`:** panel rows only.
- **The user's second word, the same day** (looks only; too small across the board; too alike; one or two much
  grander, kept up by rule): `Config.BaseScale` is now 1.2 to 2.6; `SizeScale` 0.7 / 1 / 1.35 / 1.8 / 2.3 / 3;
  `Config.SizeLimit` (no fish over 200 long or 96 wide; `Config.sizeScale(tier, fish)` keeps to it);
  `Config.Grand` and `FishService.census` / `rollSize(grandNear)` (a Giant or bigger in every stretch, never more
  than two made); `Spawn.KindTries` and `pick(zone, near)` (the least seen kind of three draws); `Wild.Grand`.
  `Herd.SmashLength` 80, `BreakLength` 40, `Spawn.BigLength` 26, `BigFull` 110, and **`Angry.GiantLength` 68**
  (Hugo's 40: the kinds grew; the same kinds but Coral Dragon and Kelp Wyrm, which now count).
- **Measured:** sizes over 687 fish 13 / 48 / 24 / 11 / 3.8 / 0.6%; 112 of 113 stretches of 400 studs have a grand
  fish; the biggest fish in a stretch is 4.8 times the smallest; every model is its body's size; rides and hops
  through the mixed sea and with every fish forced Colossal, no errors.
- **Not done:** size does not change the Oxygen a fish needs (the user: looks only for now) or its speed (next); no Index;
  nothing remembers which of the 24 a player has. `docs/design/roster.md` and `archetypes.md` still give the old
  sizes where they give any.

## 2026-11-13 · Obsidian chat integration (the user's PC): the herd swims its own straight line, spread out, big fish higher
**State:** on the user's word of 2026-11-13. In the user's Studio place (synced, 132 scripts) and run there on
grey-box 15 by script; **not looked at by eye**. StyLua and selene pass, `rojo build` passes. Nothing uploaded. Not
committed by hand. The study, what was wrong, what it does now, the measurements and every number:
[the herd](design/herd.md). One row in [Decisions](Decisions.md).
- **New: `src/server/Lib/Stream.luau`.** The herd's water, built once when the server starts (a third of a second):
  a smooth spine that finds its own way through the open water, a band of open seabed, a floor with its steps
  rounded, and the bends round the big things. It reads the map by rays, so it needs `Seabed` and `Props` named as
  they are.
- **`FishService`:** a fish keeps its share of the band, its lift and how far along it is; `steer` heads for its
  line of the stream. The old looking-ahead dodge (`mindObstacles`) is gone. New fish are placed where there is the
  most room; big fish want more and swim higher; fish passing give way a little; a fish that swims out of sight is
  given a new place. **"How far along" (`S`, `Home`, the slices) is now studs down the stream, not the lane's own
  s:** `Stream.laneS` and `Stream.fromLane` go between them.
- **`Config`:** `Herd.Obstacle*` and `Herd.WallGap` are gone; `Herd.Turn`, `Smooth`, `EdgeGap`, `NeckAhead`,
  `BandSmooth`, `Floor*`, `Dodge*`, `SmashLength`, `Give*` are new. `Spawn`: `HeightMax` 20 (16), `BandMax` 300
  (200; 400 since the second word), `LaneFill` 0.9 (0.7, and it now means the open water's width), `PerThousand` 30 (24, now per real stud),
  new `Big*`, `Belly`, `Tries`, `Space`, `SpaceByLength`. `Config.herdHeight` allows for the big fish's rise.
  `SandboxController`: panel rows only.
- **The user's second word, the same day** ("some gentle bends, some straight through", "separate the fish a bit
  more, some to the sides"): `Herd.StraightShare` 0.4 of the fish go straight through props, `BreakLength` 24 is how
  long a fish must be to break one; the band is up to 400 wide (`BandMax`) with its two sides fitted one by one
  (`Stream.HalfLeft`, `HalfRight`; `Herd.SpineRoom`); `Space` 32, `SpaceByLength` 1.2, `Tries` 14, `GiveSide` 14,
  `GiveAlong` 36, `LaneFill` 0.95. Synced and run again.
- **Measured:** the herd's middle line turns 3 degrees per 100 studs and its side lines 7 (the middle was 32, the
  sides over 200); live fish at the start 1.2 to 1.9 (4.0), round a rider in the bending second land 6 to 7; no
  line leaves the water or the floor in 4,825 places; nearest neighbour 85 studs at the median; a sandbox ride
  with hops, no errors.
- **Next, on the user's word:** proper fish size variations, and fish speed.
- **New tool:** `python tools/studio/herd_stream_test.py <studio_id> Edit` measures the stream on whatever map is
  in Studio. Run it after a new map.
- **Not done:** Hugo's place has none of this until he pulls and syncs. `tools/balance/model.py` still works the
  band out the old way.
- **For the user to judge:** the mix of bending and straight-through fish; small fish swimming through a prop
  that stays whole; the band's width; how the big fish read above the layer.

## 2026-11-13 · a NULLROOM worker (Hugo's PC): the glide starts before the wall, and the camera under the water's lit sheet
**State:** on Hugo's hand-play of 2026-11-13. Run in Studio by script through the studio runner on grey-box 15;
**not played by hand**. StyLua and selene pass. Nothing uploaded; the test scripts are out of the place. Not
committed or pushed by hand (the vault's own sync carries it). The numbers, before and after, and two pictures:
[the playtest](playtests/2026-11-13-wall-glide.md). The rules: [riding feel](design/riding-feel.md), "The glide
starts before the wall" and "Under the water's lit sheet". Two rows in [Decisions](Decisions.md).
- **The wall glide** (`Lib/WallRide` rewritten, `Lib/Course`, `RideController.drive`, `JumpController`): a wall is
  seen `Wall.Look` (0.5) seconds of travel ahead on three rays and one along the way really gone, and the way you
  go is bent onto it by a limit on how fast you may close on it, down to nothing at `Wall.Gap` (5 studs of water
  beside the body). No moment of contact any more. The speed kept by angle, the swing square on, steering off,
  `State.Wall` and `State.WallSide` are as they were. `WallRide.step` takes the body's half length and half width
  now, not a reach.
- **`Lib/Course`:** `Course.wall` is gone; new `Course.feel` (a wall ahead: its way out, its distance, how much
  of a wall it is, and the wall behind a step) and `Course.edge`. A step is a step only with 12 studs of open
  water past its face, asked the same way by the look-ahead and the hard rule. **The lane's surveyed edge now
  counts only where the map has no wall of its own beyond it** (it stood up to 40 studs inside the real walls and
  jumped at bends); the walls, terraces and barrier are the edge. The hard rules are still there behind it all.
- **The camera** (`RideController.cameraStep`): its ceiling is under the water's lit sheet, about 10 under the
  surface (was 3); riding and in a hop it is always under; it meets the line softly; floating at the surface it
  stays above the water instead (`Camera.FloatAbove`). And the camera's "never inside a wall" rule leaves the
  map's breakable props out (`Lane/Props`): riding along a wall past a coral, it came in 8 studs in one frame.
- **New numbers, all in the N panel:** `Wall.Look`, `Gap`, `Soft`, `Feelers`; `Camera.LightMargin`, `LightLayer`,
  `SurfaceKnee`, `SurfaceTime`, `FloatAbove`, `AirMargin`. `Wall.Band` now means how far inside the lane's own
  edge you ride it.
- **For the partner (the water and the lighting): nothing of yours was changed.** The "thin layer of light" is
  your water's own stack: the four layers `Foam`, `Water1`, `Water2`, `Water3` from the surface down to 8 studs
  under it, and the nine bright `Under` sheets at 8.45 under (`tools/map/water_look.luau`,
  `ClaudeBlockout.Surface.WaterLayers`). None is solid or seen by rays (`CanCollide`, `CanQuery` off), so no
  property needed changing and `water_look.luau`, `98_water.luau` and the Lighting are untouched. The camera reads
  the height of the part named `Under` each frame. **If you rename `Under` or `WaterLayers`, or move the sheet,**
  the camera falls back to `Camera.LightLayer` (8.5 under `WaterTop`): change that number, or tell the game-code
  chat.
- **For the map chat:** the look-ahead names the same folders as before (`Lane/Walls`, `Lane/Ground`,
  `Lane/Barrier`, `Lane/Props`, `Dock`). The surveyed width in `path.json` no longer holds a ridden fish where a
  wall stands beyond it, so it need not be exact.
- **The test driver** (`tools/studio/movement_w1/`) gained `glide`, `glideone`, `wander`, `mouth`, `hopglide`,
  `camtop`, `camwall` and `pose`; its older wall checks (`wall`, `walldeep`) were written for the old contact
  rule and will report false failures: use `glide`.
- **Left:** the fish you hop off coasts into a wall the old way for its 1.5 s (`RideController.coast`). A view
  flicked round in one frame beside a wall still brings the camera in at once (the old rule, unchanged).

## 2026-11-13 · a NULLROOM worker (Hugo's PC): fewer fish with abilities
**State:** on Hugo's feedback of 2026-11-13. Data and notes only: `Config.FishStats` and
[archetypes](design/archetypes.md). No code changed, nothing run in Studio, not played. StyLua, selene and
`rojo build` pass; `python tools/creatures/check_archetypes.py` (new) checks the ids and the targets.
- **The table:** 51 of 82 fish have no ability (was 20); Predator 10 (was 39), Breaker 6 (23), Tank 7 (20),
  Fast 5 (15), Leaper 4 (17), Frenzy 2 (6). 28 fish have one, three have two (Megalodon, The Devourer, Blue
  Whale), none more. Who and why: the note's "Fewer abilities" and its table of all 82.
- **One speed changed:** The Devourer 150 to 128. The fastest fish is now the Ember Serpent (138).
- **For the game-code chat:** the sandbox's F list (`SandboxController`, `TRY_OUT`) names the Giant Sea Bass as
  its Tank and the Dunkleosteus as its combo; the first has no ability now and the second only Predator.
  Steller's Sea Cow and the Blue Whale would put that back. Not changed here.
- **Open for Hugo:** Flying Fish as a Leaper (an Uncommon, left without); the Mosasaurus is its land's fastest
  and a Predator (left).

## 2026-11-13 · a NULLROOM worker (Hugo's PC): the hop-off boost, the second hook and the wall ride, finished on grey-box 15
**State:** on Hugo's word of 2026-11-12. Run in Studio by script through the studio runner on the new map, ten
playtests, no errors in the output; **not played by hand**. StyLua, selene and `rojo build` pass. Nothing uploaded;
the test scripts are out of the place. The numbers and three pictures:
[the playtest](playtests/2026-11-13-wall-hop.md). The rules: [riding feel](design/riding-feel.md), "Hop-off speed
and the map edge". A row in [Decisions](Decisions.md).
- **The hop** (`JumpController`, `Config.Jump`, `RideService.jump`): the pop is `Launch` x the fish's speed as you
  leave + `HopBoost`, whole for `BoostHold`, gone by `BoostTime`; the glide and the window are longer off a fast
  fish and shorter off a slow one (`Config.airOf`, the server counts the same), never under `AirLeast`.
- **The second hook:** `HopGuard` and `MashMost` (presses that began in the pull-in can't hop you off the fish you
  land on), `LandWait` (the server waits for a landing to be seen arriving before it refuses it), `RehookGuard`
  (after a refused pull-in the hands-off one waits).
- **The wall ride:** new `src/client/Lib/WallRide.luau`, used by `RideController.drive` and the hop;
  `Lib/Course` gained `Course.wall`, the step rule and the corner rule; `State.Wall` ("Slide", "Swing") and
  `State.WallSide` are the hooks for authored animations (none is played; the partner's animation code is
  untouched). Numbers in `Config.Wall`, all in the N panel.
- **Server:** a riding character collides with nothing (`PropService.riding`, group "Riding", set from
  `RideService`'s state); the map's boundary boxes are the lane's edge for `checkCrash`
  (`FishService.inside` is the old distance rule, still used beside it).
- **Map and code:** `Course` and `RideService` now name the loader's folders `Lane/Walls`, `Lane/Ground` and
  `Lane/Barrier`, and take a boundary box's X as across the wall and its Z as along it. **For the map chat: if
  the loader renames those folders or turns the boxes another way, say so here.**
- **Taken out again:** the last worker's camera turn cap and camera position spring (measured: no use, see the
  playtest). `Config.Camera` is as it was.
- **Not checked:** the archetypes one by one after this (they ran throughout); two riders at once; anything by hand.

## 2026-11-12 · Obsidian chat integration (the user's PC): Hugo's latest passes merged onto the user's new map (grey-box 13)
**State:** on the user's word ("crossover his new changes with my new map", the map kept). Merged, built, in the
user's Studio place and run once. (Since then the map chat has loaded grey-box 14 and then 15, which is what the loader files now
hold.) **Hugo's place still has the old map: see the note to void in
[Sessions](Sessions.md) for how to load the new one.**
- **Merged from Hugo:** the control pass, the speed by home land and then the speed reset (`Config.FishStats`),
  angry mode, the six passive archetypes. Only [Decisions](Decisions.md) and [Sessions](Sessions.md) conflicted;
  both sides are kept. No script conflicted and none of Hugo's code was changed.
- **Kept from here:** the map chat's grey-box 13 (the hub after the reference, a 144-wide gate, a mirrored first
  room, walls rebuilt even and flush; [map structure](design/map-structure.md)), and the landing mix
  (`Animation.LandingMix` 2; the startle's rearing stays out, `AnimController` and `Lib/Feel` are untouched by the
  merge).
- **Map and code together:** Hugo's passes touch no map file, and nothing in them holds a position on the map. The
  game finds the dock spawn by name and reads the lane's width from the map's `Path`.
- **Checked:** StyLua, selene, `rojo build`; `sync_src.py` sent 130 scripts; one sandbox run on grey-box 13: spawn
  on the dock at (3000, 1, -144), a ride and landings down the lane at about 44 studs a second on a Common, taming
  full, no game errors in the output.
- **Not checked:** the archetypes' bites and smashes and angry mode on this map (the sandbox's endless air was on);
  anything by eye (Studio draws no 3D on this PC).
- **For the user to judge:** Hugo's angry mode and archetypes each move the fish with a stand-in motion until the
  user's animations exist. They add to the ride and do not replace the landing mix. `Angry.Motion` 0 and
  `ArchetypeFeel.Motion` 0 switch them off.

## 2026-11-12 · a NULLROOM worker (Hugo's PC): the passive archetypes are built and measured
**State:** on Hugo's word (all passive, feel matters, no real animations). Run in Studio by script through the
studio runner, seven playtests, no errors in the output; **not played by hand**. StyLua, selene and `rojo build`
pass. Nothing uploaded; the temporary test scripts are out of the place. The numbers and three pictures:
[the playtest](playtests/2026-11-12-archetypes.md). The rules as built and the animation hooks:
[archetypes](design/archetypes.md). A row in [Decisions](Decisions.md).
- **Server** (`RideService`): `checkEat` (a Predator's bite, a Frenzy's stacks), the Breaker in `checkCrash`
  (props free and paid, a wall at half), `reward` (the burst the speed check allows, the Oxygen, the fish's
  `Bite` / `Smash` attributes, Ride "Boost" to the rider, Fx "Eat" / "Smash" to everyone), the Tank through
  `Config.drainOf` and `Config.low(oxygen, max, fish)`, the Leaper's longer window in `jump`. `FishService`:
  `prey`, `eat`, and `spawnTest` (Studio only); the making of a fish is now one function, `make`.
- **Client:** `RideController.boost` and the Fast launch in `drive`, with the stand-in lunge and shudder (one
  marked block; `ArchetypeFeel.Motion` 0 switches it off); `JumpController` flies a Leaper's hop
  (`Config.hopOf`); new `Controllers/ArchetypeController` (the words, bubbles, sounds, kicks); new
  `Shared/Archetypes` (names and colours). `State.Launched` and `State.Leapt` are new events.
- **UI files touched, as little as it took** (the UI chat's): `UI/Tags` has a line naming a fish's archetypes
  and uses the fish's own seconds; `UI/Rings` has a third line, `View.Kind`; `HudController` fills it and passes
  the fish to `Config.low`; `UI/Aim` clamps its ring (a Leaper's window is longer than `Jump.Window`).
- **Config:** `Config.ArchetypeFeel` (new), `Config.angryAt`, `drainOf`, `surgeOf`, `burstShare`, `hopOf`;
  `Config.low`, `heat` and `secondsOn` take the fish as an optional last argument; each archetype's numbers are
  also `Config.<Id>` so the panel can name them.
- **Sandbox:** F rides the next fish of a try-out list; `Net.Sandbox` "Ride", fishId, variant. The archetype
  numbers are rows on the N panel.
- **The test:** `tools/playtest/archetypes/` (the two temporary scripts and how to install them).
- **To play, first:** whether the bursts and the 10% air a bite are too generous (a Megalodon among small fish
  never ran low), how the words and kicks feel, two players at once.

## 2026-11-12 · void (Hugo's PC): speed reset to one hand-set number a fish; passive archetypes designed, the hook in
**State:** on Hugo's word (reset speed, set per fish, no rarity or land formula; Gold x1.1, Rainbow x1.2; passive
archetypes). Committed, not pushed. **Not run in Studio.** StyLua, selene and `rojo build` pass; Config was loaded
outside Studio (Lune, with stand-ins for the creature registry): 82 fish, speeds 40 to 150, The Devourer 150, Gold
165, Rainbow 180, a changed row followed by `Config.refresh`. Nothing uploaded. A row in [Decisions](Decisions.md);
the design, the numbers and the table of all 82: [archetypes](design/archetypes.md).
- **Speed:** `Config.FishStats` is the single source: one row a creature, `{ Speed, Archetype }`.
  `Config.speedOf` is that number times the variant's. Gone from Config: `TierMult`, `SpeciesSpeed`,
  `Speed.AreaStep`, `Speed.AreaGrow`, `Config.areaSpeed`, `Tiers.*.Ridden`, a spec's `RiddenSpeed`. `Speed.Base`
  (45) stays only as the fallback for a creature with no row (it warns). `Speed.Gold` 1.1, `Speed.Rainbow` 1.2.
- **Archetypes:** every spawned fish carries an `Archetype` attribute, set by the server in `FishService`
  (`""` for none, ids comma-separated: `"Predator,Breaker"`). Readers: `Config.archetypeOf(model)`,
  `Config.archetypesOf(fish)`, `Config.hasArchetype(fish, id)`, `FishType.Archetype`. The ids and the numbers for
  each are in `Config.Archetype` (Fast, Predator, Frenzy, Breaker, Tank, Leaper).
- **Not built:** the passive behaviours (eating, the prop reward, the slower drain, the longer hop, the bigger
  landing burst). Until they are, an archetype changes nothing in play; only the speeds and the variants' factors
  did. The notes for whoever builds them are at the end of [archetypes](design/archetypes.md).
- **Files:** `src/shared/Config.luau`; one line in `FishService.luau` (the attribute) and a comment; the sandbox
  panel's rows for the removed numbers taken out of `SandboxController.luau`; a comment in `RideController.luau`.
  Not touched: `AnimController`, `RideStyles`, `AngryStyles`, `JumpController`, `RideService`, `PropService`.
- **Broken by this, not mine to fix:** `tools/balance/speed_table.py` reads `TierMult` and `SpeciesSpeed`, which
  no longer exist (the tuning chat's tool). The speed tables in [progression](design/progression.md) and the
  "Speed by fish" section of [riding feel](design/riding-feel.md) describe the formula that is gone (the latter
  is marked).
- **To play:** hops between a slow and a fast fish of one land (speeds inside a land now differ more), and the
  deep lands, which are slower than they were (the last land's Legendaries 100 to 118, were 141 to 158).

## 2026-11-12 · void (Hugo's PC): angry mode: at low Oxygen the fish pulses red and slows, each body type in its own way
**State:** on Hugo's word ("make the fishes pulse red and go into angry mode dont add animations yet just make the
pulse red and slow down, different fishes should have different slowdowns ... when the bar turns red"). Run twice in
Hugo's Studio through `~/Projects/studio-runner` by script (no keys and no mouse: how it feels and looks is Hugo's to
judge). StyLua, selene and `rojo build` pass; no errors or warnings in the output. Not committed by hand. Nothing
uploaded. A row in [Decisions](Decisions.md); the design is "Angry mode" in [riding feel](design/riding-feel.md); the
note to the other chats is the top one in [Sessions](Sessions.md).
- **Files:** new `src/shared/AngryStyles.luau` (the styles) and `src/client/Controllers/AngryController.luau` (the
  red pulse); `src/shared/Config.luau` (`Oxygen.AngryAt`, `Config.Angry`, `Config.AngryTier`, `Config.low`,
  `Config.heat`), `RideService.luau` (decides it, marks the fish, the speed check), `RideController.luau` (the
  slow-down and the stand-in motion, in `drive`), `Net.luau` (the notes), rows in `SandboxController.luau`; in the UI
  chat's files, `HudController.luau` and `UI/Rings.luau` (the ring's red comes from the same threshold). Not touched:
  `AnimController`, `RideStyles` (its `Landings` and everything else), `JumpController`, `FishService`, `Variants`.
- **When:** while you ride and the meter is at or under `Oxygen.AngryAt` of your max (0.3), or from the touch on a
  fish too strong. The ring turns red at the same point (it was "under 1 second left"); so does the hop button's call.
  A fish you have tamed gets angry like any other (`Angry.Tamed` 1: taming doesn't change the riding, and it still
  throws you off at zero; 0 keeps a tamed fish calm).
- **Who decides:** the server. `RideService` sets the fish's `Angry` (true) and `AngryStyle` (the style's name)
  attributes and the `AngryFish` tag, and takes them off at a hop, a throw-off, a death or a leave. The rider's own
  client slows the fish (it drives it); the server's speed check then allows an angry fish only what its style gives.
- **The red pulse:** one Highlight a fish, on every client, nothing written to the fish's parts (so nothing to put
  back; a Gold or a Rainbow keeps its look). 1.2 pulses a second where the meter turns red, 4 when it is empty.
- **The slow-downs** (`Shared/AngryStyles`, by `RideStyles.nameOf`): Darter "Zigzag" (wags, loses speed at each
  turn-over), Cruiser "Drag" (steady, x0.7), Snake "Coil" (long swells), Galloper "Buck" (surge and stall, rocking),
  Glider "Flutter" (a quick shiver), Paddler "Balk" (brakes and lets go), Jetter "Pulse" (a jet and a run-down),
  Bobber "Wobble" (always slow, wobbling), Crawler "Dig" (a judder), and any fish 40 studs or longer "Fade" (slow and
  heavy, down to x0.6). A rarer fish loses more (`Config.AngryTier`, up to x1.3 of the loss); never under x0.3.
  Steering and the hop are untouched.
- **Animations:** none added. Each style's rock, nod or wag is one sine on the fish's turn spring, in one marked
  block (`AngryStyles.motion`, used in `RideController.drive`), switched by `Angry.Motion` (0 off). To replace it,
  play an animation by the fish's `AngryStyle` attribute while `Angry` is true.
- **Measured in Studio:** calm: the fish at x1.00, no pulse. Angry on a Clownfish (Zigzag): x0.72 to x0.79 on
  average, the pulse on every frame at 2.6 a second half way and 4.0 at empty, 0 of its 7 parts changed colour,
  A held 1 s turns 127 degrees (126 calm). Real Oxygen, 8 s on a Common: angry at 0.30 of the meter, on three rides
  of three; a hop at 0.07 of the meter was taken; after a hop or a throw-off the old fish was calm within 0.3 s; no
  pulse or tag left at the end. Each of the ten styles forced in turn: averages x0.73 to x0.79 (Fade x0.64), as the
  table says. Not seen: a second player's screen, a Gold or Rainbow fish, a phone.
- **To try it:** in the sandbox (endless air is on there), press N and set `Angry.Test` to 0.5: every fish you ride
  is angry. Or turn endless air off and ride a fish down.

## 2026-11-12 · void (Hugo's PC): the control pass: the landing slows to 0.8, faster and direct steering, a little more air
**State:** on Hugo's word ("make the ride feel more controlled, the startle is too strong make it just slow down by
like 0.8x ... the left right is kinda too slow and clunky ... more airtime (just a little), more control in general";
"only adapt the movement"). Run in Hugo's Studio through `~/Projects/studio-runner`, the old code and the new by the
same script (turns, taps, five hops; no keys and no mouse, so how it feels by hand is Hugo's to judge): no errors in
the output, taming and the landings work. StyLua, selene and `rojo build` pass. Not committed. Nothing uploaded. A row
in [Decisions](Decisions.md); the design is "The control pass" in [riding feel](design/riding-feel.md); the note to
the other chats is the top one in [Sessions](Sessions.md).
- **Files:** `src/shared/Config.luau` (`Ride`, `Jump`), `src/client/Controllers/RideController.luau` (`steer`, and
  one line in `drive`), two rows in `SandboxController.luau`. Not touched: `JumpController` (the hop steers through
  `RideController.steer`, so it got the same change), `RideService` (the server has no limit on turning, and its
  speed check and the hop's deadline read the same Config), `AnimController`, `RideStyles`, `Config.Animation`, the UI.
- **What made left and right clunky:** three lags one after the other. A key's turn eased in (`TurnEase`), that
  turned only the VIEW, and the way you go then chased the view (`SteerEase` 6: it trailed a held turn by 16 degrees
  and ran on that far after the key was let go); then the fish's own turn spring (`Lib/FishModel`, 14) trailed that.
- **Steering now:** A and D turn the way you go directly, and the view by as much; only a look (a drag, a stick, the
  mouse in the hop) is chased, twice as quickly. The fish's turn spring is set by the rider's own client while it
  drives the fish (`Ride.Response` 45); the herd's 14 and the limits on a fish's torque and turning speed in
  `Lib/FishModel` are untouched. For the first 0.3 s after a landing the pull of the view eases in
  (`Ride.LandSteerTime`), so the fish doesn't swerve to where you were aiming at the touch.

  | Measured in Studio, a land 1 fish | before | now |
  |---|---|---|
  | A held 1 s: the way you go turned | 73 degrees | 129 degrees |
  | and the fish's body | 47 degrees | 117 degrees |
  | The first 10 degrees (the body's) | 0.30 s (0.53 s) | 0.12 s (0.20 s) |
  | Let go: you turn on by (the body) | 23 degrees (48) | 9 degrees (21) |
  | A tap of 0.25 s turns you, in all | 22 degrees, 14 of them after the key is up | 36 degrees, 8 after |
  | The pull-in begins, after the press | 1.70 s | 1.90 s |
  | On the next fish, after the press | 2.49 s | 2.68 s |
  | The landing's slowest | 0.60 of the fish's speed | 0.80 |
  | Full speed again, after the touch | 1.10 s | 0.78 s |

- **The numbers (`Config.Ride`):** `YawRate` 95 to 135, `TurnEase` 10 to 14, `SteerEase` 6 to 12, `SteerRate` 140 to
  220, new `Response` 45 and `LandSteerTime` 0.3; `StartleSlow` 0.6 to 0.8, `StartleHold` 0.4 to 0.3,
  `StartleRecover` 0.8 to 0.6 (`StartleBrake` stays 0.12). **`Config.Jump`:** `FloatTime` 1.3 to 1.5 and `Window` 3.0
  to 3.2, so the drop is as long as it was (1.3 s) and the window is still one number for every land.
- **The panel (N):** new rows `Ride.Response`, `Ride.LandSteerTime`; the others were there.
- **Looked at for "more control" and left:** nothing locks input in the landing's slow-down (A, D and the look work
  through it); the pull-in (0.05 to 0.7 s) and the hop's wait after a landing (`Jump.Cooldown` 0.3 s) take the keys,
  and both stay: the wait is what makes a fish too strong a real bar (`Oxygen.StrainTime` 0.25 is under it). The
  view drifting back behind you (`Camera.AutoRecentre`) moves the view, never the way you go.
- **Not judged:** the feel by hand; anything past land 1 (the test fish did 41 to 57; a hop is shares of the fish's
  speed, so at land 10 it is the same hop 0.2 s longer, about 27 studs more at 158); a phone or a gamepad;
  `Feel.BoltLines`, `BoltFov` and the whoosh, which still play as the fish picks up from 0.8 (made for 0.6, not this
  task's to change). In two landings the fish broke a prop at the touch and read 0.64 (0.8 x `Props.Slow`): as before.
- **The runner:** a `play` sent while a playtest is still stopping starts a second one later; wait for
  `status` to show no server before `play`.

## 2026-11-12 · void (Hugo's PC): the size roll removed; every fish faster by its home land
**State:** on Hugo's word ("check that the further you go the faster the fish get, even if theyre legendary it should
still get faster by more per area, dont do the sizing yet remove it but keep rainbow and gold for now"). StyLua, selene
and `rojo build` pass. **Not run in Studio:** the numbers are worked out by `tools/balance/speed_table.py`, which
follows `Config.speedOf`; how land 10 speeds feel and hop is not played. Nothing uploaded. Two rows in
[Decisions](Decisions.md); the design is "Speed by fish" in [riding feel](design/riding-feel.md); the note to the
tuning chat and the game-code chat is the top one in [Sessions](Sessions.md).
- **Files:** `src/shared/Config.luau`, `src/server/Services/FishService.luau`, `src/client/UI/Tags.luau` (the name
  line), rows only in `SandboxController.luau`, `tools/balance/speed_table.py`.
- **What was found:** a fish's land did not count. speed was `Speed.Base` x species x rarity x size x variant, so a
  Legendary did 78 in land 2 and in land 10; a land was faster only through its mix of rarities.
- **Area speed (new):** `Config.areaSpeed(land)` = 1 + `Speed.AreaStep` x (n - 1) + `Speed.AreaGrow` x (n - 1)(n - 2)
  / 2, with 0.06 and 0.01: x1, 1.06, 1.13, 1.21, 1.30, 1.40, 1.51, 1.63, 1.76, 1.90. It is in each species'
  `RiddenSpeed` (`Config.refresh`, from the fish's `Home`), which `Config.speedOf` reads, so the herd, the ridden
  speed, the glide and the server's speed check all follow. Land 1 is unchanged.

  | Species base 1 | land 1 | land 5 | land 10 |
  |---|---|---|---|
  | Common, before and now | 45, 45 | 45, 58 | 45, 86 |
  | Epic | 68, 68 | 68, 88 | 68, 129 |
  | Legendary | 78, 78 | 78, 101 | 78, 148 |

  Real creatures: Reef Shark (Epic, land 1) 69 as before; Orca (Epic, land 5) 73 to 95; Sea Scorpion (Epic, land 8)
  68 to 111; Archelon (Legendary, land 1) 72 as before; Helicoprion (land 5) 79 to 103; Hellfin Shark (land 10) 83 to
  158. Every Common lives in land 1, so no Common changed. Fastest: The Devourer 205, as a Rainbow 307.
- **Removed (sizing):** `Config.Size` (`On`, `Min`, `Max`, `Curve`), `Config.rollSize`, `Config.sizeSpeed`,
  `Speed.SizeBonus`, the size argument of `Config.speedOf` (now `(fish, variant)`), `FishService`'s roll and its
  scaling of the model and seat, `Wild.Size`, the "Size" attribute, Studio's `TestSize`, the tag's "x1.23", and the
  five sandbox rows. Kept: `Config.sizeOf` (gives 1) and `Config.bodyOf` (the species' body), for `Lock`,
  `JumpController`, `RideController` and `AnimController`, which are untouched. Gold x1.2 and Rainbow x1.5, their
  chances and their looks are exactly as they were.
- **The panel (N):** new rows `Speed.AreaStep`, `Speed.AreaGrow`; gone `Speed.SizeBonus`, `Size.*`.
- **The table:** `python tools/balance/speed_table.py <out.png>` now draws all 82 under their home land, with the
  speed before and now, Gold and Rainbow, and a grid of rarity by land on top.
- **For the tuning chat:** the hop is made of shares of the fish's speed, so it scales; what does not is listed in
  riding feel (`Net.RangeSlack` against lag at 150 studs a second, `Jump.FreeAirSpeed` and `FreeLaunch` for a rider
  floating in a deep land, the herd's `ObstacleLook` and `ObstacleShift`). Oxygen and the too-strong rule go by land
  and rarity and are untouched. `tools/balance/model.py` does not know the area's factor.
- **Left as found:** `CLAUDE.md` and `RideController`'s header still say "size roll" (not this task's files).

## 2026-11-12 · 8570-F43F (the user's PC): the startle's rearing and "!" removed; our landing reactions play again
**State:** by the game-code chat, on the user's word. In the place on this PC, run once: two hops and landings, no
errors, no "!" made. StyLua, selene and `rojo build` pass. Not committed by hand. Nothing uploaded.
- **Why:** with `Ride.Startle` on, every landing got one reaction (the rear) and returned before the pick from
  `Animation.LandingMix`, so the seven reactions and their spread by body type never played.
- **Removed:** `AnimController`'s `startle` and its two "rear" branches (creature and stand-in), `Feel.mark` and its
  step, `Ride.StartleTime/Rear/Shake/ShakeRate/Coil/Lunge`, `Feel.Mark/MarkTime`, and their sandbox rows.
- **Kept:** the landing's slow-down in `RideController` (`Ride.Startle` 1, `StartleBrake/Slow/Hold/Recover`), the
  rider's animations, the speed lines and sounds. A fish's `brace` and `thrown` are now always 0 (the rider's
  astride pose still takes them).
- **Not seen:** the landing reactions themselves: Studio's window is not drawing 3D on this PC.

## 2026-11-12 · 8570-F43F (the user's PC): Hugo's four passes merged with the too-strong rule, taming and the UI chat's HUD
**State:** by the game-code chat, on the user's word ("update the game to what my partner has added"). Merged, in the
place on this PC, run once: riding, a tame, the slots and the HUD all work, no errors in the output. StyLua, selene and
`rojo build` pass. Committed here (286419a), not pushed by hand. Nothing uploaded.
- **Taken whole from Hugo:** the movement pass, speed by fish, the size roll, Gold and Rainbow, the camera under the
  surface, the startle, `Lib/Feel`, `Shared/Variants`, the creature tools. No clash with `RideService`'s too-strong
  rule or taming: git merged `Config`, `RideService` and the sandbox panel by itself.
- **Merged by hand:** the eight HUD files both sides changed. The rule used: Hugo's look, the local pieces kept.
  - From Hugo: `Kit` as the style system and the bold letter outlines, the abyss miss, the dressed pills and plates,
    the glass slots, the yellow jump button with its key cap, the small stat plates (104 by 29), the tag's red pill.
  - Kept from here: the ring as the reference's (small clear hole, the red lag, the tame ring, the hop's arc, red and
    shaking on a fish too strong), the creature pictures in the slots and the catch banner (206 by 50), the new-land
    banner, the hop arrow's pointed shape (now dark, on Hugo's disc), the phone scale of the stat rows.
  - New in the merge: `Kit.ring(parent, diameter, thick, meter, outline)` has both sides' options; the meter has
    Hugo's bold outline (2 and 1.6) and its glow beats red in the last second and on a fish too strong.
  - Not carried over: Hugo's deep-water fill in the ring's hole and the seconds written in it (the ring here has no
    number and a clear hole); the UI chat's bigger Oxygen row (150 by 34) and its thin letter outlines.
- **Two sheets had one name.** Hugo's is `attachments/ui4-before-after.jpg`; the UI chat's HUD sheet is now
  `attachments/ui4-before-after-hud.jpg` (`tools/ui/before_after.py` and `ui.md` point at it).
- **How it looks:** [capture](attachments/ui-merged-2026-11-12.jpg) (the world is black: Studio's window is still not
  drawing 3D on this PC; the HUD is as it is).
- **Not seen:** the 3D side of Hugo's work (rider animations, the startle, sizes, Gold and Rainbow, speed lines over
  the world), a phone layout, a too-strong ride and the miss banner after the merge.
- A copy of everything as it was before the merge: branch `backup/pre-partner-merge`.

## 2026-11-12 · void (Hugo's PC): speed by fish, a size roll, variants' chances, the camera stays underwater, a startle that never stops
**State:** built and run in Hugo's Studio through `~/Projects/studio-runner` (driven by script, judged from numbers
and pictures; how it feels by hand is Hugo's to judge). StyLua, selene and `rojo build` pass. Nothing uploaded.
Hugo's four asks are four rows in [Decisions](Decisions.md); the design is "Speed by fish" and "The camera stays
underwater" in [riding feel](design/riding-feel.md); the note to the other chats is the top one in
[Sessions](Sessions.md).

- **Files:** `src/shared/Config.luau`, `src/server/Services/FishService.luau`, `RideService.luau` (it reads each
  fish's own speed and body), `src/client/Controllers/RideController.luau`, `AnimController.luau`,
  `JumpController.luau`, `src/client/Lib/Lock.luau`, `Feel.luau`, `src/client/UI/Tags.luau` (the name line), rows only
  in `SandboxController.luau`; new `tools/balance/speed_table.py`. `FishModel` is untouched: its `MaxForce` and
  `MaxTorque` stay.
- **Speed:** `Config.speedOf(fish, size, variant)` = `Speed.Base` 45 x `SpeciesSpeed[id]` (0.92 to 1.08, all 82 with
  a reason each) x `TierMult` (1, 1.16, 1.33, 1.51, 1.73, 2, 2.22) x `Config.sizeSpeed(size)` (x1 at `Size.Min`
  up to x1.2 at `Size.Max`, `Speed.SizeBonus` 0.2) x `Speed.Gold` 1.2 or `Speed.Rainbow` 1.5 (Hugo, 2026-11-12). At the
  smallest size: Commons 41 to 47, Uncommons 49 to 56, Rares 55 to 65, Epics
  63 to 73, Legendaries 72 to 84, Mythics 85 to 97, Secrets 92 to 108: round the partner's measured 60, 68, 78, 90.
  The herd (0.85 of each fish's own), the ridden speed, the glide and the server's speed check all read it.
  **`Config.TierSpeed` is gone;** `Tiers[..].Ridden` is worked out in `Config.refresh`.
- **Size and variants:** `FishService` rolls both at the spawn (`Config.rollSize`, `rollVariant`), scales the built
  model (`ScaleTo`, the seat keeping `Ride.SeatHeight` above the back), sets the `Size` and `Variant` attributes and
  calls `Variants.apply`. What counts as a fish's body is its own (`Wild.Body`, `Config.bodyOf`): the lock, the
  landing's reach, crashes, props, the ring, the swim's pace. **Seen:** 741 fish at the start, sizes 0.8 to 1.4,
  mean 1.02, 20 Gold and 7 Rainbow; tags read "Blue Chromis x1.25".
- **The startle:** `Ride.StartleSlow` 0.6, `StartleHold` 0.4, `StartleRecover` 0.8 replace `StartleStall`,
  `StartleKick`, `StartleSnap`, `StartleKickTime`. **Measured** on a Yellow Tang (ridden 45.9): 27.5 through the
  hold, 45.9 again 1.2 s after the touch; the same shape on a Liopleurodon (81: 48.5). The rear, shake and thrash
  are unchanged. `Feel.BoltFov` 6 to 3 (there is no bolt now, only the pick-up).
- **The camera:** `Camera.Submerge`, `WaterTop`, `SurfaceMargin` 3, `SurfaceTilt` 0.5. **Measured** in the first
  land, a hop looking 40 degrees down: with it off, 94 frames above the surface (up to 2.4 studs above); with it on,
  none, in that hop and in every hop of the check below (the highest the camera came was 3.0 under).
- **The many-mounts check, run again:** 10 resets and 34 landings by hop across all ten lands, sizes 0.81 to 1.38, a
  Gold among them. **None thrown:** the biggest move of the rider in one frame was 20 studs (a pull-in); the server
  never flagged a fish as too fast; its log held only the known asset-type warning. 16 hops found no fish under the
  script's fixed aim and sank (the sandbox's no-fail), as before.
- **Not done / to know:** `tools/balance/model.py` still reads the rarities' old speeds and knows nothing of species,
  size or variants (the tuning chat's). The species' bases, the multipliers and the chances are Claude's first
  numbers, for Hugo and the tuning chat to tune. The tag's "x1.23" is plain text in the name line, for the UI chat
  to style. Pictures (Hugo's PC): `~/Pictures/ride-a-fish/speed-size-2026-11-12/`.

## 2026-11-12 · void (Hugo's PC): the 82 creatures show in Hugo's place (mesh files on his PC, nothing uploaded), and Gold and Rainbow fish
**State:** installed in Hugo's Studio and played through `~/Projects/studio-runner` (by script, judged from pictures).
StyLua, selene and `rojo build` pass. **Nothing uploaded.** This ends "BLOCKED: the creature templates" below for
Hugo's PC only. **Hugo saves the place with Ctrl+S.**

- **What was tried, in order.** (a) `LoadAsset` and `GetObjects` again: still "Requester does not have permission
  for Asset". (b) Uploading copies from Hugo's account: no way from this PC. There is no Open Cloud key here,
  `upload.py` goes through Studio's connector (which hangs Studio under Wine), and a plugin's
  `AssetService:CreateAssetAsync` answers "not available yet". (c) Building the meshes in the running game with
  `EditableMesh`: it works in Edit mode, but a client could make only about 8 of the 1,365 before
  `CreateEditableMesh` returned nil (its memory budget), and destroying each one after its MeshPart is made empties
  the part. Dropped.
- **What works: Roblox mesh files in Studio's own content folder.** `tools/creatures/local_meshes.py` reads each
  GLB (`glb_meshes.py`, no Blender) and writes every part as a "version 2.00" mesh file with its vertex colours
  (`rbxmesh.py`) to `<Studio>/content/ridefish/<Id>/<Part>.mesh`. `python tools/creatures/install.py runner --local`
  then makes `ReplicatedStorage.FishModels.<Id>` out of real MeshParts that show those files
  (`rbxasset://ridefish/...`, by `CreateMeshPartAsync` in Edit mode). `FishModel` is unchanged: it rigs them as it
  rigs the uploaded ones.
- **Checked in play:** all 82 fish types build from a template with every `Rig_` joint and a real mesh on every part.
  Wild fish in the Shallows (37), the Open Blue (40) and the Underworld (45): all rigged, all real meshes, the
  server's log clean.
- **The limits, and they matter.** These templates show only on Hugo's PC, and only while the files are there:
  **after Studio updates itself, run `python tools/creatures/local_meshes.py` again** (the content folder belongs to
  one Studio version; the place needs no new install). A place saved this way shows no fish on the other PC, and
  **a published game needs real assets that belong to the publishing account or to a group. Recommended: one Roblox
  group both accounts are in, the 82 models uploaded to it once, the game published under it;** then the plain
  `install.py` on each PC. Until then the other PC keeps its own place with the uploaded templates.
- **Gold and Rainbow** (`src/shared/Variants.luau`; `FishService` already calls `Variants.apply(model, variant)` at
  the spawn). No exported variant meshes exist, so these are placeholders by the creature chat's own rules (workout
  6, `voxel_kit.py`): the same gold ramp, rainbow stops and accents (violet on gold, white on rainbow).
  - With `--local` the installer also bakes each part in gold and in rainbow (`<Part>.gold.mesh`,
    `<Part>.rainbow.mesh`) and makes `ReplicatedStorage.FishVariants.Gold.<Id>` and `.Rainbow.<Id>`;
    `Variants.apply` swaps each part's mesh (`ApplyMesh`, on the server, so everyone sees it). The rainbow is one
    straight gradient nose to tail: faces are cut across the body 24 times so a long box stays smooth. Glowing parts
    take the accent. Dark details that cover under a fifth of the animal (pupils, a band's edge) stay dark.
  - Where a place has no variant meshes (the other PC's uploaded templates, block stand-ins) it tints the parts:
    gold by how light each part was, rainbow by where the part is along the body (turning slowly if a client calls
    `apply`). Rougher: a tint multiplies the mesh's own colours.
  - Both add sparkles. Gold is plain SmoothPlastic: Metal went ochre and Reflectance greyed it.
  - Not the creature chat's dithered rainbow (that needs a texture), and no studs.
- **Pictures** (Hugo's PC): `~/Pictures/ride-a-fish/models-2026-11-12/`.
- **Not done:** an uploader for Hugo's account (needs an Open Cloud key with asset write, or the group); the gold
  clownfish's dark details were re-baked after the last picture and Studio keeps a file it has loaded until it
  restarts, so that one change is unseen.

## 2026-11-12 · void (Hugo's PC): UI pass: bold outlines, gradients, patterns, a theme for each purpose
**State:** built and run in Hugo's Studio through `~/Projects/studio-runner` (driven by script, judged from
pictures): no errors in the output. StyLua, selene and `rojo build` pass. **Nothing uploaded.** Hugo's ask is a row
in [Decisions](Decisions.md); the design is "Pass 4" in [UI](design/ui.md); the note to the UI chat is the top one
in [Sessions](Sessions.md).

- **Files:** all of `src/client/UI/` (`Kit`, `Aim`, `Banners`, `HopButton`, `LandStrip`, `Rings`, `Slots`,
  `StatRows`, `Tags`), `src/client/Controllers/HudController.luau`, and the panel's look only in
  `SandboxController.luau`. `DeathController` is unchanged: it draws nothing itself (its black, its closing edges
  and its words are drawn by the HUD).
- **`Kit` is a small style system:** `Kit.Themes` (Oxygen, Danger, Action, Grab, Off, Gold, Good, Navy, Glass,
  Tool, Key), `Kit.dress(frame, style)` and `Kit.panel(parent, props, style)` (gradient, thick dark outline, a pale
  line inside it, a pattern, a shine, a shadow), `Kit.stripes`, `Kit.bubbles`, `Kit.grid`, `Kit.pulse`,
  `Kit.tierFill`, and the scales `Kit.Space`, `Kit.Outline`, `Kit.Radius`.
- **This turns back the hairline frames** of the user's second round (Decisions, 2026-11-12, the row under Hugo's).
  Places, sizes and spacing are as they were, but for a point or two of room for the outlines.
- **Patterns:** the map's stud tile (`tile2`) and the water's picture, both uploaded before. Both loaded in Hugo's
  Studio.
- **What beats:** in the last second on a fish the Oxygen row's outline, a red glow round the ring and a red ring
  round the jump button; nothing else is tweened, and nothing is made per frame.
- **The ring's seam is gone:** a full ring showed a faint line where its two halves meet (it was there before; the
  darker hole made it plain). A half that is whole now drops its gradient.
- **`StatRows.update` takes a fourth argument** (the last second on a fish). **`Kit.touch` reads the workspace's
  `HudTouch`** in Studio, to force the phone or the keyboard layout.
- **Not done / not judged:** no real phone; no second player; a Mythic's and a Secret's colours seen only in the
  slots (a made-up catch); the dock's screens don't exist yet. The catch banner, the slots, the coins and the tame
  ring were shown by feeding them made-up values, as the game has no taming or coins yet.
- Pictures (Hugo's PC, not in the repo): `~/Pictures/ride-a-fish/ui-2026-11-12/` (before and after of each screen,
  and `contact-sheet-before-after.png`); the sheet is in the vault as `docs/attachments/ui4-before-after.jpg`.

## 2026-11-12 · void (Hugo's PC): Movement pass: a longer hook, real rider animations, the startle, more juice
**State:** built and run in Hugo's Studio through `~/Projects/studio-runner` (driven by script and judged from
pictures: no keys, no mouse, no sound, so the feel by hand is still Hugo's to judge). StyLua, selene and
`rojo build` pass. Nothing uploaded. **Hugo owns the mechanics: the hold on the ride, jump and camera code is lifted
for these changes** ([Decisions](Decisions.md), four rows of 2026-11-12). The fish here are still block stand-ins
(the 82 models are private to the partner's account), so the startle on a real creature's rig is written but unseen.

- **Files:** `src/shared/Config.luau`, `src/client/Lib/Lock.luau`, `src/client/Lib/Feel.luau` (new),
  `src/client/Controllers/JumpController.luau`, `RideController.luau`, `AnimController.luau`, and rows only in
  `SandboxController.luau`. No server file changed: `FishModel`'s `MaxForce` 40,000 and `MaxTorque` 400,000 stay.
- **The hook and the lock:** `Jump.GrabRange` 130 to 180 (the server reads the same number, times
  `Net.RangeSlack`). `Lock.DistanceWeight` 0.2 to 0.07, and the new `Lock.FarAim` (5 degrees at the full range): a
  margin round a far fish that counts as aimed at it. The ring at long range is wider (`Jump.RingFar` 1.5), thicker
  (`RingGrow` 60 to 40) and turned to the camera (`RingFarFace` 0.8). **Seen:** locks taken at 158 to 176 studs,
  grabs granted by the server at 153, 135 and 116 studs.
- **The startle** (`Ride.Startle...`, 0 turns it off): a landing (not the sandbox's R) makes the fish rear for 0.8 s
  with a "!" over its head, the rider curled against its back, then it bolts. `AnimController` plays it on a
  creature's rig and on a stand-in, as one reaction named "rear"; **with the startle on it replaces
  `Animation.LandingMix`'s reactions**, which are all still there with `Ride.Startle` 0. The stall and the bolt are
  `RideController`'s speed curve for that fish: measured on a Common (ridden 45), 13 studs a second while it rears,
  71 at the bolt's peak, back to 45 about a second later. No force is added anywhere.
- **The partner's thrown-rider check, run again:** 67 landings by hop and 23 resets across all ten lands (two
  rounds, before and after the joint fix below). **None thrown:** the biggest move of the rider in one frame was
  17.7 studs (a pull-in), and the server never flagged a fish as too fast. Two hops in the deep lands found no fish
  and sank, as before.
- **The rider's animation** (`Config.Pose`): a front crawl in the hop, a breaststroke lying flat while floating, a
  crouch and push off, streamlined through the pull-in, a tuck and forward flip into the seat, and a riding pose
  that leans with speed and into turns. Written once in the body's own directions and carried into each joint's,
  so R6 works too (run once on an R6 rig: riding, crawl and float all posed, no errors).
- **Found, and it matters on both PCs: no rider pose had ever shown on Hugo's avatar.** It has Roblox's newer
  joints (`AnimationConstraint`, 15 of them, no `Motor6D`), and `AnimController` looked for Motor6Ds only, so the
  body stayed in its rest pose in every state. It takes both now. Every joint of the avatar is written each frame
  and our own tracks are stopped as they start, so Roblox's Animate script can't show through.
- **The juice** (`Config.Feel`, drawn by the new `Lib/Feel`): the view kicks wider at the pop and at the bolt;
  speed lines on the screen through the pop's extra speed, the pull-in and the bolt; a bubble trail; bubbles off
  the fish at the pop and round it at our own landing; a swish, a whoosh and a splash from Roblox's own character
  sounds (`Lib/Fx`'s "Rumble" names `action_falling.mp3`, which this Studio has only as `.ogg`: not mine to change).
- **`RideController.look(yaw, pitch)`** is new: it turns the view as a mouse drag would, for tests by script.
- **The panel (N):** new rows under `Ride` (twelve `Startle...`), `Lock` (`FarAim`), `Jump` (`RingFar`,
  `RingFarFace`), and two new groups, `Pose` and `Feel`.
- **For the tuning chat:** a landing now costs a stall. With these numbers the bolt gives most of it back (about a
  sixth of a second of travel lost a landing), but a new player has only 2.5 s on a fish: `Ride.StartleTime` and
  `StartleStall` are the rows if it is too much.
- **Not done / not judged:** the sounds were never heard; the startle and the poses were seen slowed down in
  pictures (the numbers stretched for the capture), at full speed only by their measurements; other players' dash
  shows without the flip; nothing was tried with two players.
- Pictures (Hugo's PC, not in the repo): `~/Pictures/ride-a-fish/movement-2026-11-12/`.

## 2026-11-12 · 8570-F43F (the user's PC): the progression takes in hold-or-not and taming
**State:** by the tuning chat. No number changed and no game file changed. Nothing played: it is the model.

- **The model** (`tools/balance/model.py`) knows `Oxygen.StrainTime` and `Config.Tame`. New tables: the bar (what
  each fish needs, and the share of a land's fish it opens) and the rarest fish a player can tame in each land. The
  dives count landings on a fish too strong and what a dive brings home. `--sim 40 --dives` plays the dives alone.
- **The note** ([progression](design/progression.md)): "Hold or not", the tables made again, "Taming: built,
  and what the numbers say". A land is a wall now: a player at home in one holds nothing in the next.
- **Kept as built:** `Oxygen.StrainTime` 0.25 (it has to stay under `Jump.Cooldown`), `Tame.Time` 2, `Tame.Carry` 7.
- **Asked of the game-code chat** ([Sessions](Sessions.md), top note): the lock gives red fish; a tag shows
  its home land's number; a fish right at your bar is tamed only as it throws you off; the seven slots fill in the
  first half minute (the user's call: question 8).

## 2026-11-12 · 8570-F43F (the user's PC): a fish too strong drains the meter at once; taming
**State:** built and run in Studio by the game-code chat. StyLua, selene and `rojo build` pass. The HUD side is with
the UI chat (the red ring, the reference's ring, the taming UI).

- **A fish too strong** (the user: never refuse the landing, drain it "insanely quickly"): judged at the mount, by the
  land the fish is in. If it needs more than your max Oxygen (`Config.required`), the whole meter empties in
  `Oxygen.StrainTime` (0.25 s, under the hop's 0.3 s wait) and the usual throw-off follows. Riding a fish you hold
  into a deeper land is not this: it pays that land's drain, as before. Player attribute `Strained`.
- **Taming** (`Config.Tame`: On 1, Time 2, Carry 7): riding a fish you can hold fills its tame (attribute `Tame`, 0 to
  1); full, it joins what you carry (Ride "Tamed" and "Caught"). At the dock the catch is counted (`Owned`) and the
  hands are empty. For the session only. New: `src/client/Controllers/TameController.luau` (keeps `State.Tame`,
  `Caught`, `Tamed`, `Strained` for the HUD).
- **Seen:** a Shallows Common tamed in 2.0 s, shown in the slots, counted at the dock. With max Oxygen 30 the same
  fish emptied the meter in 0.23 s and threw the rider. No errors.
- **Not seen:** a too-strong landing from a real hop (only the sandbox's seat, which takes the same path); the 3D
  world in the capture (Studio's window was not being drawn).

## 2026-11-12 · void (Hugo's PC): Hugo's place brought up to the merged game; the 82 creature models can't be loaded here yet
**State:** run in Hugo's Studio through `~/Projects/studio-runner`. StyLua, selene and `rojo build` pass on 830e028
with no merge leftovers. One file changed: `tools/creatures/install.py`. No ride, jump or camera change. Nothing
uploaded.

- **Code:** Rojo (127.0.0.1:34873) is connected here and the place has the merged `src/` (82 creature data modules,
  `RideStyles`, `Look`, the HUD's `UI` folder, five services, eight controllers).
- **Map:** grey-box 9 loaded from `tools/studio/greybox/` (106 parts files, the water, the check): 62,835 parts
  (the check expects 62,834), 1,974 asset models, 8 plots, 44,588 pictures, `DockSpawn` and `Path` present, no file
  refused. The pictures show on this account.
- **Lighting:** `ReplicatedStorage.Skies` made (`1 Place`, `2 Anime Sky`) and `tools/studio/look_install.luau` run:
  Realistic style set, the Anime Sky shown. `InsertService:LoadAsset` refused the sky in this unpublished place;
  `game:GetObjects` took it.
- **BLOCKED: the creature templates (worked round on Hugo's PC the same day: the entry "the 82 creatures show in
  Hugo's place" above; the assets are still private).** All 82 assets in `tools/creatures/assets.json` are private to the account
  that uploaded them (TheSyurpyPancake, 165352993). Hugo's Studio (user 8607502680) gets "Requester does not have
  permission for Asset" for every one, by `LoadAsset` and by `GetObjects`. So `ReplicatedStorage.FishModels` is empty
  here and every fish is `FishModel`'s block stand-in. **Needed from the owner's side, no new upload:** share the 82
  model assets with user 8607502680 (Creator Hub, each asset's permissions; or the Open Cloud asset-permissions
  call in one batch). Then on Hugo's PC: `python tools/creatures/install.py runner`.
- **`install.py`:** `runner` in place of a studio id runs it through Hugo's studio-runner; it tries `GetObjects`
  when `LoadAsset` refuses; a creature that fails now makes the run exit 1.
- **Played by script (the game's own `Actions.jump` and the sandbox's remote; no keys, so feel is unjudged):** R onto
  a fish, riding, a hop with a grab and a landing in the Shallows (Boxfish to Pufferfish), the Open Blue (Hammerhead
  to Sawfish) and the Underworld (Infernal Angler to Hellmaw). Each land spawned its own kinds: 11 in the Shallows,
  17 in the Open Blue, 14 in the Underworld. Server and client logs: nothing but the known
  `rbxassetid://203785492` asset-type warning. `AnimController` was only exercised on stand-ins.
- **Not saved:** a plugin can't save a place opened from a file; Hugo presses Ctrl+S. The file before this is
  `~/Projects/sharedDH-local/backups/ride-a-fish-map.1112-before-port.rbxl`.
- Pictures (Hugo's PC, not in the repo): `~/Pictures/ride-a-fish/port-2026-11-12/`.

## 2026-11-12 · 8570-F43F (the user's PC): riders thrown at a mount: the cause, and the fix
**State:** fixed and run in Studio by the game-code chat. StyLua, selene and `rojo build` pass.

- **The cause: a fish's `Swim` and `Turn` had no force limit** (`MaxForce` and `MaxTorque` were `math.huge`, in
  `src/server/Lib/FishModel.luau`). In the one physics step in which a rider's body was joined to a fish, on the
  rider's own machine as it took the fish over, that now and then threw the pair hundreds to hundreds of thousands of
  studs. It was caught frame by frame: the throw happened between the step before the physics and the step after,
  with nothing else pushing, the rider already on the saddle and every number ordinary. About one mount in five on the
  big creatures of the deep lands; rare in the Shallows. **Fixed:** `MaxForce` 40,000 and `MaxTorque` 400,000.
  **Seen after: 42 mounts across all ten lands and 26 more at the normal start, none thrown**, and every fish still
  reaches its ridden speed (60, 68, 78, 90 measured on a Rare, Epic, Legendary and Mythic).
- **This was not only the sandbox's reset.** The same join happens at every landing; the reset just made it easy to
  repeat.
- **Wrong turns on the way, for the record** (each was tried alone and did not stop it): a ride starting at a speed
  the engine misreported (a real fault, fixed, but not this one); the weld made across a distance; the floating push;
  the server moving a rider who was already seated; how long the rider had been on the saddle; how long the fish had
  been in the Workspace (four seconds looked like a cure at 1 throw in 30, which was chance); the rider's body
  touching the map. The last two were taken out again.
- **What is kept from the hunt:**
  - A ride's start speed is never more than the fish's own.
  - **The sandbox's reset seats the rider as a landing does:** the server keeps a fish and sends "SandboxMount", the
    player's machine sits the character on the saddle for 0.4 s and answers "SandboxSit", then the weld is made. If the
    pair is somewhere else a moment later, the reset is done again by itself (twice at most; not needed since the fix).
  - **R is quick:** the fish round the sandbox's start are kept in the Workspace whoever is near
    (`FishService.keepNear`). Riding begins 0.9 seconds after R at the normal start; the first reset to a NEW start
    (a changed `Sandbox.StartS`) waits 2 to 4 seconds for its fish, the next ones 0.9.
  - The server no longer moves a rider who is already on the saddle; the floating push has a force of a few times
    the character's weight and comes off before the physics step once a weld has arrived.
- **Two leftovers of the review, done:** a wild fish's place along the lane is taken from where it really is at each
  top-up (it drifted behind after detours); the ride's rays are set up again when any character appears.
- **Still not done from the review:** prop break-ups replicate up to 60 part updates a frame in a burst
  (`PropService`); a surplus fish out of sight is destroyed and a new one built, where it could be moved.

## 2026-11-12 · 8570-F43F (the user's PC): all 82 creatures are in the game; the sandbox's reset still glitches
**State:** run in Studio by the game-code chat. StyLua, selene and `rojo build` pass. Nothing committed by hand.

- **All 82 creatures are uploaded and installed** (the user's word of 2026-11-12). 81 uploads through
  `tools/creatures/upload.py` (the Reef Shark kept its asset); `tools/creatures/assets.json` has 82 ids,
  `assets_dark.json` the 32 old too-dark ones (still in the inventory), `upload_log.json` each upload. The place has
  82 templates in `ReplicatedStorage.FishModels`, each matching its data module. **Seen in play, all ten lands:** every
  land spawns its own creatures (64 kinds seen in ten samples of 28 to 44 fish), every fish has its rig and joints
  (up to 38 on one), no errors from `AnimController` or anything else.
  - **A slip to know about:** two upload runs overlapped for about five minutes (the first looked dead and wasn't).
    The asset list is consistent (every Id's asset is the one the log names), but the second run may have made one or
    two stray duplicate assets in the inventory before it was stopped, and the Kraken's first two tries failed on
    Roblox's side ("Unknown Error") before the third went through.
- **Real play, soaked:** 18 hops in a row with a watch on the rider's position: the biggest move in one frame was 18
  studs. Hands off (nobody aiming the view), 5 of 8 hops from a fish landed in the Coral Reef; the lock follows the
  view, so a player who aims should do better. To judge in play.
- **The sandbox's reset (R) is not right yet.** It was throwing the rider hundreds to hundreds of thousands of studs
  on about one reset in three. What was found and done, in order:
  1. A ride started at the fish's speed as read at the mount, which the engine can report in the thousands for a
     frame: clamped (this one could have hit real landings too).
  2. The weld was made while the rider floated 30 to 250 studs from the fish: the reset now seats the rider first,
     as a landing does (the server keeps a fish, sends "SandboxMount", the player's machine sits the character on the
     saddle and answers "SandboxSit", then the weld is made), takes only a fish that has been in the Workspace for a
     second, and keeps trying for eight seconds.
  3. The floating push now has a force of a few times the character's weight, not a million, and is taken off just
     before the physics step when a fish's weld has arrived.
  **After all that, 20 resets across the ten lands: 17 clean, 3 with a jump** (one of 650,000 studs for a frame; the
  rider ended near the start in two of the three). Riding begins 1.4 to 3.8 seconds after R, because fish near the
  new place have to come back into the Workspace first. **Not understood yet:** what still throws the pair in those
  three. Two leads: `RideController.float` lifts a floating player found under the lane's floor, and after a
  teleport its idea of where the lane is may be stale; and the fish's own `Swim` and `Turn` have no force limit.
- **Lighting at depth:** at 671 metres (the Twilight) the view is as bright and blue-skied as the Shallows
  ([capture](attachments/game-twilight-all-creatures.jpg)). The tint and fog by depth is in the map chat's queued
  plan ([water](design/water.md)), waiting for the user's go.

## 2026-11-12 · 8570-F43F (the user's PC): AnimController after the review (cost, joints cached too soon)
**State:** written, synced by the Obsidian Git plugin. StyLua, selene and `rojo build` pass. **Not run** by this chat
(Studio is the game chat's). One file: `src/client/Controllers/AnimController.luau`. The game chat's own edit
(`MOUNT_REACH`) is kept.

- **Cost:** a fish behind the camera is not moved at all (with its own length of grace). A fish past 150 studs is
  moved every second frame, past 300 every third. Each fish keeps its own clock, so its step is the time since it
  was last moved, and one that was out of view for over 0.3 s starts afresh. The ridden fish is always moved.
- **Joints:** a fish's joints are no longer kept until the first part's joint and every keyed part's joint are
  found. Until then it is tried again every 0.2 s for 5 s; after that it makes do and warns, naming the creature.
- **Not read every frame any more:** the fish folder (kept from `ChildAdded` and `ChildRemoved`) and the players
  (kept from `PlayerAdded` and `PlayerRemoving`).
- **A landing's number from the server:** the "Land" effect may carry a fourth value, a count; if it does, the
  reaction is seeded from it, so a player who joined late sees the same one. Without it each client counts.
- **Left:** the rider's pose table is still made each frame for each rider (a few players; the CFrames in it are
  made each frame anyway).

## 2026-11-12 · 8570-F43F (the user's PC): the large check, first half: an independent review and its fixes
**State:** fixed and run in Studio by the game-code chat (the herd moves, none inside an obstacle, five hops in a row
land, no errors; the server's frame is 0.7 ms with one player). StyLua, selene and `rojo build` pass. An independent
reviewer read every file of `src/` for bugs and cost; what it found, and what was done:

- **Fixed, cost on the server** (`FishService`): each fish looked at all 302 obstacles every frame (725,000 steps a
  second for 40 fish): obstacles are now kept by where they stand along the lane and a fish looks at its own 250-stud
  stretch and its neighbours. A fish's `Swim` and `Turn` were written every frame and replicate to everyone: now only
  when its way turns a degree or its speed changes half a stud a second (and twice a second regardless). The top-up
  read every player's position for each of 800 fish and walked all 250 slices: positions are read five times a
  second at most, and the slice is found by halving.
- **Fixed, traffic** (`RideService`): `Oxygen` went to every client every frame at today's drain rates; now ten times
  a second, or at once when it moves a twentieth of the meter.
- **Fixed, new fish appearing beside a player** (`FishService.spawnFish`, `Spawn.AppearClear` 160): of a few tries in
  the slice, the place furthest from every player. A player at the lane's start still sees some appear, because the
  first slice is all within reach of them.
- **Fixed, bugs:** `Ease.smoothstep` gave NaN with no width (a sandbox number could lose the character); a late
  refusal for one fish no longer stops a pull-in begun on the next (the refusal now names its fish); a landing the
  server sees out of reach is a refused grab, not a drown; with no dock spawn the rider was sent to the dock every
  frame while the character loaded; a creature file missing a field, or an unknown rarity, is left out with a warning
  instead of stopping every script; the lock looks over the herd 20 times a second, not every frame.
- **Passed to their owners:** the animation's cost per fish per frame, fish behind the camera, and joints cached too
  early (the creature chat); the HUD's speed lines and ring gradient every frame (the UI chat).
- **Not done:** a fish's place along the lane drifts from where it really is after detours (a check first: print the
  gap for old fish); the prop tweens replicate 60 parts a frame in a burst; an out-of-sight surplus fish is destroyed
  and a new one built, where it could be moved; the ray filter isn't rebuilt when another player joins mid-ride.

## 2026-11-12 · 8570-F43F (the user's PC): riders thrown thousands of studs at a mount: found and fixed
**State:** fixed and run in Studio by the game-code chat: 16 sandbox resets in a row, none thrown (before: 6 of 12).

- **What was seen:** now and then, a third of a second after mounting a fish, the rider and the fish were somewhere
  else entirely: 1,150 studs up, 750 under the map, once 10,000 studs away. The server's log: the pair sat right at
  the mount, then jumped together, with "fish moved too fast".
- **The cause** (`RideController.onMounted`): a ride carries on at the speed the fish was swimming, read from the
  fish's Root at the mount. In the frame the fish's body joins the rider's, the engine can report a speed in the
  thousands, and the ride then started at that speed along the fish's nose. **Fixed:** the start speed is never more
  than the fish's own ridden speed, and the start pitch never more than 35 degrees. This was not only the sandbox's
  reset: any mount could have hit it, a landing too.
- **Also changed on the way:** the sandbox's reset now waits a third of a second before mounting, so the player's
  own machine has moved the character to the lane first (`RideService.sandboxReset`); and the rider's body follows
  the fish's motion only when that fish is within 40 studs (`AnimController`, `MOUNT_REACH`): for a few frames round a
  mount it could name a fish far away. Neither was the cause, both are kept as guards.
- **The pull-in's dots** have their own deeper yellow (`Jump.DotGlow`): in the ring's colour they bloomed to white
  blobs under the new lighting.

## 2026-11-12 · 8570-F43F (the user's PC): a training spot, all 82 creatures on their way in, and a Config clash
**State:** written and run in Studio by the game-code chat; StyLua, selene and `rojo build` pass. The uploads were
running when this was written.

- **Training** (new `src/server/Services/TrainService.luau`, `RideService.train`, `Config.Train`): a pad in the hub;
  standing on it adds `Train.Rate` (4) to your max Oxygen every second, kept for the session (no saves). The pad is
  the map's part named `TrainSpot` under the hub when it has one; until then a stand-in disc is made at run time
  70 studs to the right of the dock's spawn and 24 toward the water. The player's `Training` attribute is true while
  gaining. Seen in play: 100 to 120 in 5 seconds, and it stops when you step off. `Train.On` 0 takes it out.
- **Creatures:** `tools/creatures/collect.py` wrote all 82 data files. The five placeholder fish are out of Config's
  table; the Bobbit Worm is kept out of the herd (`NO_SPAWN`, Reach -1) until it is in the roster; Secrets have no
  land's mix, so they don't spawn. The uploads (81 models) go through `tools/creatures/upload.py`.
- **A clash, fixed:** the creature chat's rewrite of `Config.Animation` removed the whole `Config.Look` block, so the
  lighting controller and the N panel errored at start. Restored from the last sync, above the Animation comment.
  Four chats edit `Config.luau`: small exact edits only.
- **`MaxOxygen`** on the player is rounded to a tenth now (training makes it a fraction).
- **Tools:** `tools/studio/sync_src.py` sends the creature data too, in batches.

## 2026-11-12 · 8570-F43F (the user's PC): the dive's HUD rebuilt from the UI plan (pass 3), not run yet
**State:** written by the UI chat, synced by the Obsidian Git plugin. StyLua, selene and `rojo build` pass. **Not run
and not type-checked.** The game-code chat runs it first.

- **What:** `HudController.luau` rewritten, and nine new modules in `src/client/UI/`. The HUD now follows the
  reference's riding screen: the strip of lands on top, a ring with the seconds left on this fish beside the rider,
  the jump button at the lower right, a tag on each of the nearest wild fish, your Oxygen as a stat row. Detail and
  the choices taken: [UI](design/ui.md), "Piece 2".
- **Gone:** the Oxygen bar, the rate and the speed beside it, the depth gauge, the bracket on the locked fish.
- **Waiting on the game code:** the server's own rate for the ring (`State.Drain`), the locked fish's seconds
  (`State.LockSeconds`), Roblox's jump button hidden on touch. It runs without them.
- **Nothing uploaded.** No pattern and no picture signs until the user says yes to uploads.

## 2026-11-12 · 8570-F43F (the user's PC): the creature chat's side of the import of all 82 is ready
**State:** written, synced by the Obsidian Git plugin. StyLua, selene and `rojo build` pass. **Not run:** no type
check on this PC and Studio is the game chat's, so the animation has not played in the game. No upload by this chat.
The user's word, passed on by the game chat: import all the models and all the animations, with a mix of landing
types. Files: `art/creatures/BlueWhale`, `tools/creatures/import_plan.json`, `src/shared/RideStyles.luau`,
`src/client/Controllers/AnimController.luau`, `Config.Animation`, five rows on the N panel.

- **The exports:** all 82 present, each with one `<Id>.glb` and `<Id>.mesh.json`, a seat, swim keys and a size.
  Every vertex colour in every GLB is one of its palette's colours, so none is a too-dark export. The Blue Whale's
  files were named `BlueWhaletheoldone` (its `NAME` said "the old one"): renamed in `voxel.py`, exported again, the
  old files deleted. The plan: 49 new uploads, 32 again, 1 as it is ([creature import](design/creature-import.md)).
- **Rarity and land:** all 81 roster creatures' exports agree with [the roster list](design/roster-list.md).
- **The animation is the Swim Lab's**, the preview the user tuned over 2026-11-11 and 12 (its "Lively, balanced"
  set), carried into `AnimController`, all of it seen only:
  - **A slow wave** for each body type (`RideStyles.Waves`, `Animation.Wave`): the stroke, the height, a drift to
    one side and a lean, on one rhythm of 3 to 7 seconds that swells and fades. A small fish shows about half.
  - **Landings** (`RideStyles.Landings`, `Animation.Wild`, `LandingMix`): the dip at the touch, then one of seven
    reactions (startle, buck, thrash, bolt, wobble, shudder, barrel roll) that builds from the touch and falls off
    over about two seconds. `LandingMix` 2 is the user's mix: the body type's own most often, its second often, now
    and then any of the seven. Each client seeds the pick from the rider's id and its count of their landings.
  - **Side fins in a turn** (`RideStyles.Fins`, `Animation.FinTurn`): tilt, sweep and a wider stroke on the outside.
    Only the 48 creatures with separate side parts show it.
  - **A calmer rider** (`Animation.RiderCalm`): they take the body's shift eased and at half its turning; thrown
    off the seat by a buck; arms and legs flung about while the animal fights.
  - **A steadier beat:** it changes over a moment and by little; small fish beat slower; the per-beat body sway is
    smaller on a small fish and a quick beat. The landing's dip and the rider's squash now swing in from nothing.
- **Not carried over, because they need the Root to move** (`RideController`, the server; not handed to this chat):
  the wave's 1 to 3 per cent change of speed, the bolt's burst of speed (the body lunges ahead instead), the surge
  waiting for a landing's build-up. **And eyes that look about:** `FishModel` welds each `<Part>_Glow` to its part.
- **To check in play:** that nothing errors in `AnimController` (it runs every frame for every fish near the
  camera); a landing on a small fish, a shark, a turtle and a whale; the rider through a barrel roll.

## 2026-11-12 · 8570-F43F (the user's PC): the locked fish's mark as the reference's, and hooks for the HUD
**State:** written and run in Studio by the game-code chat; StyLua, selene and `rojo build` pass.

- **The locked fish** (`JumpController`, `Config.Jump`): its glow is one flat yellow-orange, nearly solid
  (`GlowFill` 247, 190, 62; `FlyGlow` 0.6 to 0.12), with a black outline (`GlowOutline`; it was pale yellow). The
  ring and the pull-in's dots keep the brighter yellow (`Glow`). Seen in play: off while riding, on at the hop with
  those values.
- **Nothing is marked while you ride** (`Lock.Preview` 1 to 0), as in the reference (read from the user's recording
  of 2026-11-10; the row is in [Decisions](Decisions.md)). The N panel's `Lock.Preview` row puts it back.
- **For the HUD (the UI chat):** the server publishes `Drain` on the player, the Oxygen a second the fish under you
  takes as the server counts it (0 off a fish), so seconds left = Oxygen / Drain; `State.secondsOn(fish)` gives how
  long a full meter would last on any fish where it swims; `Actions.jump()` is the hop and the grab.
- **New tools:** `tools/studio/sync_src.py <studio_id>` puts every script of `src/` into the open place while the
  Rojo plugin is disconnected; `tools/creatures/upload.py <studio_id>` uploads the creature models of
  `import_plan.json` through Studio (permanent: on the user's word, given 2026-11-12 for all 82), writing
  `assets.json` as it goes and carrying on where it stopped.

## 2026-11-12 · 8570-F43F (the user's PC): a character appears on the dock from its first frame
**State:** written and run in Studio by the game-code chat; StyLua, selene and `rojo build` pass. One file:
`src/server/Services/RideService.luau`.

- **What happened:** the user pressed Play while the map was half loaded (no `DockSpawn` yet) and stood on Studio's
  default `Workspace.SpawnLocation`, on the grey Baseplate at the origin, 3,000 studs from the map. With the map
  whole, a character still appeared there for a moment before the server stood it on the dock.
- **Now:** when the server finds the dock's spawn it moves every `SpawnLocation` in Workspace onto it and makes it
  unseen and non-solid, for that run only. Seen in play on the reloaded map (the hub in its new colours): the
  character's first position was the dock's spawn, the view faced the water, no errors, and a ride lasted 2.50 s on
  100 Oxygen.
- **Not changed:** the place itself. The default SpawnLocation and Baseplate are still in it; deleting them is the
  user's call. With no `DockSpawn` at all (a half-loaded map) the default spawn is still where you land.

## 2026-11-11 · 8570-F43F (the user's PC): the tutorial's lighting, tweakable, and its sky
**State:** written and run in Studio by the game-code chat; StyLua, selene and `rojo build` pass. **Not seen by eye:**
Studio's window wasn't being drawn, so it was checked by its numbers in play (every value on, no errors, the sky
shown). The note: [lighting](design/lighting.md).

- **New:** `Config.Look` (the numbers), `src/shared/Look.luau` (puts them on Lighting and two effects of our own),
  `src/client/Controllers/LookController.luau` (keeps them while playing; all on the player's own machine),
  `tools/studio/look_install.luau` (the same in Edit mode, plus LightingStyle Realistic, which a game script can't
  set), and 24 `Look` rows on the N panel. `Look.On` 0 shows Roblox's plain lighting to compare.
- **In the place (Studio-owned, not in the repo):** `ReplicatedStorage.Skies` with `1 Place` and `2 Anime Sky`
  (Creator Store asset 72835926026092, the Sky only), and Lighting set by the installer. **Hugo's place needs** the
  installer run once and a `Skies` folder, or it keeps its own sky and a Soft style with the rest of the look.
- **Left out on the user's word:** the tutorial's last step, a `Highlight` on the character (a black outline and a 20%
  black wash).
- `tools/studio/push_scripts.py` now also makes a script that isn't in the place yet.
- **This replaces** the agreement that the game code never sets Lighting (map-structure.md, "Still different", 1).


## 2026-11-11 · 8570-F43F (the user's PC): animation is tried in a preview page now, not in the game
**State:** no change to `src/` or to Studio. The user's word: two chats changing the game at once got confusing, so
until the other chat stops making changes, this chat (creatures and animation) stays out of `src/` and out of Studio.

- **The Swim Lab:** a private page, <https://claude.ai/artifact/PxpF8Mdhxbh5mrcE21GXQE>, that plays any of the 82
  creatures in 3D from their exports with the same steps as `AnimController`'s layers. Five feel sets (keys only, the
  first slice as built, lively, heavy, arcade), four ride patterns (rail, undulate, surge and glide, weave, or by body
  type), a rider, a small herd, and buttons to turn, land, crash and buck. Every number is a slider.
- **What is only in the page, not in the game:** the ride patterns other than rail, the beat multiplier, the bank by
  body type and the herd's weave. The first slice of this morning is still in `src/` as it was.
- **Next:** the user picks a feel from the page; its numbers then go into `Config.Animation` and `Shared/RideStyles`
  in one go, when the other chat is no longer editing.

## 2026-11-11 · 8570-F43F (the user's PC): the Oxygen numbers are seconds on a fish now
**State:** written, synced by the Obsidian Git plugin. StyLua, selene and `rojo build` pass. **Not played, not
type-checked.** By the tuning chat, on the user's answer of 2026-11-11 ([Decisions](Decisions.md), top row). Studio's
sandbox starts with Endless air on, so nothing is felt until that is switched off. The note:
[progression](design/progression.md).

- **A landing refills the whole meter:** `Oxygen.Refill` 0.25 to 1. Every fish starts full, as the reference's ring
  is the time left on this dino. Seconds on a fish = max Oxygen / (`ZoneDrain` x `RarityDrain`).
- **`Oxygen.KeepUp` 6 to 2:** it now means the seconds on a fish that count as enough, so the HUD's "needs" and a
  fish's tag show the Oxygen for 2 seconds on it.
- **`ZoneDrain`:** 1, 4, 14, 48, 160, 500, 1,500, 4,500, 13,000, 36,000 to 40, 160, 480, 2,000, 6,000, 24,000,
  60,000, 240,000, 1,000,000, 4,000,000. The starting 100 lasts 2.5 seconds on a Shallows Common; each land takes 2.5
  to 4 times the land before.
- **`RarityDrain`:** 1, 1.15, 1.3, 1.45, 1.6, 1.75, 1.9 to 1, 1.25, 2.5, 4.5, 15, 50, 150. Gentle to Epic, steep from
  Legendary; Rare to Legendary follow the reference's required stamina in one zone.
- **What that makes:** a new player has 2.5 s on a Shallows Common, 2 on an Uncommon, 1 on a Rare, and is thrown off
  an Epic or a Legendary at once. A dive is about 15 seconds (played: 15.6 s, 1,141 studs): the Shallows, five
  fish long, ending on the first fish of the Coral Reef. (This entry first said 40 seconds, from a model whose
  rider hopped faster than a player can; corrected the same day.) To try a deeper land set Workspace's `TestMaxOxygen`: 500 for the Coral Reef, 3,000 for the Kelp Forest,
  12,500 for the Shipwrecks.
- **On the N panel:** the `ZoneDrain` rows' steps fit the new sizes; `KeepUp` steps by 0.25.
- **Not changed:** the speeds (proposed in the note: 54, 58, 62, 67, 74, 82, 90, on the `TierSpeed` rows), the
  shares by rarity, and everything in the hop.
- **The model:** `python tools/balance/model.py` reads `Config.RarityDrain` and prints seconds on a fish by land and
  rarity; `--max 3000` does it for a trained player.

## 2026-11-11 · 8570-F43F (the user's PC): the first slice of the animation study is built, not played
**State:** written, synced by the Obsidian Git plugin. StyLua, selene and `rojo build` pass. **Not played and not
type-checked** (no luau-lsp here, and Studio was not connected): expect numbers to tune and possibly bugs. The study:
[animation study](design/animation-study.md). Files: `src/client/Controllers/AnimController.luau`, new
`src/shared/RideStyles.luau`, a new `Config.Animation` group, 21 rows on the N panel. No server change, no upload.
`RideController` is not touched.

- **Everything is seen only.** Each layer turns or shifts joints of the fish, never its Root, so the Saddle, the lock,
  the pull-in and the server's checks are as they were. Every layer has a row that turns it off at 0.
- **Effort** (`Effort`, `EffortAccel`, `EffortBeat`, `LandEffort`): the swing and the beat rise when a fish speeds up or
  is landed on, and ease when it coasts.
- **The turn layer** (`Turn`, `TurnLead`, `TurnBend`, `TurnMax`, `TurnTotal`, `WildBank`): the tail joints trail a turn
  and come round late; the head leads (most creatures' first part is the head, so the whole body is turned a little
  ahead instead); wild fish roll into bends. The chains are found from each creature's `Parts`: checked by script on
  the 33 creatures in the game (the Anglerfish's rod and the octopus's arm chain are picked up too, harmlessly).
- **The body layer by style** (`Body`; nine styles in `Shared/RideStyles`, all 82 creatures assigned): a heave, a nod,
  a sway and a rock each beat, as one shift of the whole body about the Root. `Cadence` 1 sets the beat's rate by
  style (a turtle strokes at 0.6 of what its length gives, a jetter at 0.45).
- **The landing** (`LandDip`, `LandNod`, `LandDipTime`): the fish sinks under the rider and springs back, a small fish
  further. It is seen only, not the real dip in `drive` the study proposed, to stay out of `RideController`.
- **The rider goes with the body** (`RiderFollow`): the same shift is put on the rider's Root joint, so they ride the
  heave, the dip and the buck. The seat part's own keyed swing (the Basilosaurus's back under you) is NOT followed yet.
- **The brace** (`Brace`): arms up and knees folded for a moment at a landing.
- **A jaw** hangs nearly shut and opens now and then (`Jaw`), instead of chomping every beat.
- **A crash** makes your own fish rear and shake (`CrashFlinch`).
- **Fixed on the way:** the buck was multiplied onto the first joint's last value, which piled up on creatures whose
  first part has no keys (Cuttlefish, Octopus, Kraken, Anomalocaris, Elasmosaurus). The joint is now written afresh.
- **To judge:** the list at the end of section 5 of the study. Set a row to 0 and back to see what its layer adds. Count
  hops landed out of ten with the layers on and off: it should not change.
- **Not done from the slice:** the buck's numbers and the swim's base rate are still literals in `AnimController`.

## 2026-11-11 · 8570-F43F (the user's PC): the tuning chat's first turn: a balance model, the progression note, panel rows
**State:** written, synced by the Obsidian Git plugin. StyLua, selene and `rojo build` pass. **Not played, not
type-checked. No tuning number changed:** every speed, share and Oxygen number is as it was.

- **The model:** `python tools/balance/model.py` reads Config, the creature files and the map's path, and prints, land
  by land, the length, the seconds to cross, the Oxygen needed, the fish by rarity and the creatures. `--sim 8` plays
  dives through the herd's stocking rules. `--set Oxygen.TierDrain=1` tries a number without touching the game.
- **The note:** [progression](design/progression.md): the tables, what is off with a proposed value for each, what
  isn't built, and six questions for the user. All of it is proposed.
- **The three findings:** a new player's dive is 75 seconds and ends at the third land's door, with no way yet to grow
  max Oxygen; a rarer fish costs almost nothing more, so nothing is out of reach to chase; and hopping without
  stopping makes every land 20 times cheaper in Oxygen.
- **In `src/`:** `Config.TierSpeed` and ten names for `Config.ZoneMix`'s rows (both only so the panel can reach those
  numbers), five lines in `Config.refresh` so a changed speed reaches fish already swimming, and rows on the N panel:
  the speed of each rarity, `Oxygen.StartMax`, and each land's shares by rarity.
- **Not live yet:** `Oxygen.StartMax` from the panel doesn't reach a player already in the game (use Workspace's
  `TestMaxOxygen`). The fix is in the game-code chat's files; it is in [Sessions](Sessions.md), Notes.

## 2026-11-11 · 8570-F43F (the user's PC): the creature import is prepared, nothing uploaded
**State:** written, synced by the Obsidian Git plugin. No upload, no change to `src/` or to the place.

- **The plan and the steps:** [creature import](design/creature-import.md). With no picks made: 49 new uploads, 32
  uploads again (the too-dark ones), the Reef Shark as it is.
- **The user picks by hand** which creatures go in, on a picker page (every creature's picture, a tick each). The picks
  land in `tools/creatures/picks.json`; `python tools/creatures/plan_import.py` turns them into
  `tools/creatures/import_plan.json`. Both files are new; `collect.py`, `install.py` and `assets.json` are untouched.
- **For the chat doing speed, rarity, sizes and spawns:** a creature in `leftOut` of the plan is not coming; the variants
  and the Secrets have no spawn rule yet.

## 2026-11-11 · 8570-F43F (the user's PC): the game on grey-box 9, the view faces the water, and the tuning chat's first turn
**State:** written and run in Studio by Claude (StyLua, selene and `rojo build` pass). Not committed by hand. **Studio
was restarted, so the Rojo plugin is not connected:** the changed scripts were put into the place directly, and the
user needs to press Connect in the Rojo plugin again (the server still runs on port 34872).

- **Grey-box 9 (the map chat: 8-stud squares, a 480 by 256 hub, a rounded mouth 248 wide at the lane's start):** the
  game runs on it. The floor survey is within 3 studs at all 2,941 places checked; 302 obstacles read. Riding at full
  speed in open water (52 to 54 on an Uncommon); of four hops in the Coral Reef three landed. Hands off with the real
  rules on 100 Oxygen, a fish went straight down the first land: across the Shallows in 20 seconds with one crash, and
  down to 31 Oxygen 28 seconds in, 480 studs into the Coral Reef (four crashes by then, 3% each).
- **Fixed: a new player started with their back to the water.** On the dock Roblox's own camera kept the direction it
  had before the server stood the character on the dock's spawn, so the view looked at the hub and the character faced
  the camera; a fish mounted like that swam back at the hub, because the movement follows the view. The server now
  publishes the dock spawn (`Dock` attribute on Remotes) and `RideController.faceWater` brings the view round behind
  the character every time it is put on the dock (a spawn, and the return from a dive). Seen in play: the view looks
  down the lane at the start.
- **`Oxygen.DockRadius` 120 to 165** for the new hub: the spawn is 104 studs behind the start and the mouth is 248
  wide, so 165 covers the mouth's corners and the first 60 studs of water in the middle.
- **The tuning chat's first turn, checked** ([progression](design/progression.md), `tools/balance/model.py`): its code
  is rows on the N panel and what carries them (`Config.TierSpeed`, ten names for `Config.ZoneMix`'s rows, five lines
  in `Config.refresh`). In play: `TierSpeed.Common` set to 70 moved the wild Commons to 59 or 60 at once (0.85 of 70).
  No tuning number changed. Its six questions wait for the user.
- **`Oxygen.StartMax` is live on the panel** (the tuning chat's ask): `RideService.readMax`, called by
  `SandboxService` when that row changes. Seen: 500 and back to 100 showed on the player at once.
- **Not measured:** a whole first dive with hops (the model says 75 seconds, ending just inside the Kelp Forest). It
  needs steering through the bends, which the connector can't do: for the user's own play, with "No fail" and
  "Endless air" off.

## 2026-11-11 · 8570-F43F (the user's PC): the hop matched to the reference, and the movement follows the camera
**State:** written, synced by the Obsidian Git plugin. StyLua, selene and `rojo build` pass. **Not played, and not
type-checked** (no luau-lsp on this PC): expect numbers to tune and possibly bugs. The user's brief after playing
Movement v3.1: match the reference's hop one to one for now, and make the movement follow the camera. Files:
`RideController`, `JumpController`, `Config` (Ride, Jump, Camera), `SandboxController`.

- **This turns four of Hugo's answers of 2026-11-11 back**, on the user's word; each is one number, so either way can
  be played from the N panel. The rows are in [Decisions](Decisions.md). For the two of you to settle.
- **The movement follows the camera** (`Ride.CameraSteer` 1, new `RideController.steer`): the fish, the hop and the
  float come round to where the view looks, at `SteerEase` 6 and never faster than `SteerRate` 140 degrees a second.
  A and D still turn the view, so they steer as before; now a drag, a stick, and the mouse in the hop steer too. The
  bank follows the real turn. `CameraSteer` 0: only A and D steer (Movement v3.1).
- **The pull-in starts by itself** (`Jump.AutoGrab` 2): when the glide ends the locked fish pulls you in, and with none
  locked then, the first one locked in the drop does. A press still grabs sooner. The reference: the pull-in begins
  about 1.7 s after the press. `FloatTime` 1.4 to 1.3 so ours does too (0.4 + 1.3). `AutoGrab` 0: press only.
- **You hang with the herd in the glide** (`Jump.AirShare` 0.85, new): the glide's speed is 0.85 of the ridden speed
  of the fish you left (the reference: 46 against 54), 38 from floating (`FreeAirSpeed`). It was 54 for every fish, so
  you flew past the fish beside you. The drop slows by the same share as before. `AirShare` 0: `AirSpeed` 54 again.
- **The view tilts down in the hop again** (`Camera.AirRest` 1; the reference's camera lifts to look down from
  behind), until you move it, and now comes back up to the riding view at the landing if you never touched it. With
  the lock aimed by the view this matters: at the riding tilt of -12 the aim meets the herd about 100 studs ahead, so
  far fish took the lock; at -30 it meets it about 45 studs ahead.
- **Not changed:** the pop (0.4 s, 20 studs: the user's own height of 2026-11-10; the reference's is about half as
  high in 0.3 s), the launch (1.6 times for 0.75 s), the window (3.0 s), the pull-in's curve and speed, the landing's
  camera, the lock's 130-stud reach, the server.
- **To judge in play:** after a landing the fish turns to where you look, so landing while looking across the lane
  swings it that way; whether 38 to 45 in the glide feels slow again (Hugo found it so: raise `AirShare`); whether a
  pull-in from 100 studs or more by itself looks wrong (the reference's are 15 to 22 m: lower `GrabRange`).

## 2026-11-11 · 8570-F43F (the user's PC): a steadier lock-on, after the user played Movement v3.1
**State:** written, synced by the Obsidian Git plugin. StyLua, selene and `rojo build` pass. **Not played:** the
numbers are a first guess for the user to judge. Files: `src/client/Lib/Lock.luau`, `Config.Lock`, two rows on the N panel.

- **What the user said:** the lock is better than before, but it switches onto too many fish, they are too close
  together and it is hard to pick one; the reference feels more automatic and closer to what you mean.
- **`Lock.EdgeAim` 1 (new):** "off the aim" is now measured from the fish's nearest edge, in degrees as a share of half
  the `Cone`. It was measured from the fish's middle as a share of that fish's own allowance, which is wide for a near
  fish, so near fish off to the side scored well and kept taking the lock. Now the fish nearest the middle of the view
  wins, and a fish the aim passes through scores 0. `EdgeAim` 0 gives the old score back.
- **`Lock.SwitchTime` 0.15 (new):** a better fish must stay the better one this long before it takes the lock, so a
  fish crossing the view for a moment doesn't. 0 is as before.
- **Stickier:** `Sticky` 0.2 to 0.35 (with `EdgeAim`, 7 degrees of aim), `MinHold` 0.3 to 0.45, `KeepCone` 1.4 to 1.6.
- **To get Hugo's lock back exactly:** `EdgeAim` 0, `SwitchTime` 0, `Sticky` 0.2, `MinHold` 0.3, `KeepCone` 1.4.
- **Still to come, the user's order:** speed and camera shake, then optimising, then bugs and the parts that aren't
  movement, then optimising again.

## 2026-11-11 · 8570-F43F (the user's PC): every roster creature has a model; Studio here now runs Hugo's movement
**State:** pushed by hand (`13de842`). Nothing uploaded to Roblox.

- **Creatures:** the last 18 (the eight variants and the ten Secrets) are built, pass the gate and are exported, so all
  81 creatures of [the roster](design/roster.md) have a model: 82 in [the creature queue](design/creature-queue.md) with
  the Bobbit Worm. All but the first 14 are first drafts seen only on batch sheets. The user's word: these are what the
  game uses for now; polish, more creatures and the texture pass come later.
- **Not in the game:** 49 of the 82 were never uploaded, and 32 of the 33 uploaded ones are still the dark versions.
  Uploads are permanent and wait for the user's word.
- **Movement v3.1, the feel pass and the missed-hop fix are in the place on this PC.** Checked in Studio: all 27 scripts
  under `src/` are the same length in the place as in the checkout, `PropService`, `Lock` and `Spring` included. The
  merge kept this PC's map numbers (`Spawn.MaxTotal` 800, `BandMax` 200, `Ride.LaneMargin` -3, `Oxygen.DockRadius`
  120, `Dock.WalkSpeed` 28). StyLua, selene and `rojo build` pass on the merged code.
- **The place has what the new code looks for:** `Workspace.ClaudeBlockout.Lane.Props` (1,974 children) and
  `FallenPartsDestroyHeight` -20,000.
- **Not done:** nobody has played Hugo's movement on this PC's ten-land map. His tests were on a three-land place.

## 2026-11-11 · Ivy (Codex, Hugo's PC): unattended feel-pass check; missed-hop message fixed
**State:** two Studio playtests through studio-runner, then stopped to leave Studio idle. All 27 runtime scripts
matched the checkout before testing and again after the fix. StyLua, selene and `rojo build` pass. No ride/jump/camera
or server mechanics changes: the partner's rework stays untouched. Full check: [playtest record](playtests/2026-11-11-away.md).

- **Tested:** reset onto a fish; visible locked-fish dashed ring (lock sampled at 128.9 studs); pop/glide/drop;
  two grabs/landings (about 0.65 s pull-in, landing camera roll); no Oxygen drain in the hop and refill from 88.2 to
  100 at landing; prop collision and rebuild; missed-hop drown; actual Oxygen depletion, throw-off and dock recovery.
  Crash-free intervals gave about 4/s in Coral Reef and 14/s in Kelp Forest on a Common. This open place has three
  zone markers, not the ten-land map mentioned in Sessions. No map rebuild was done.
- **Fixed:** missed hops said OUT OF AIR with 99/100 Oxygen. `HudController` and `DeathController` now use the existing
  `DeathQuick` flag to show MISSED THE FISH for a miss; actual depletion still says OUT OF AIR. Both warning and fade
  checked in a fresh playtest, and the dock recovery still works.
- **Evidence:** `/home/hugo/Pictures/ride-a-fish/away-2026-11-11/`, screenshots plus two telemetry/output logs. Prop
  before/after pictures use temporary three-box fixtures hit through the real ridden-fish collision path; all three
  returned exactly home and solid. Fixtures and driver disappeared when Play stopped.
- **Delivery blocked:** every `discord_deliver` attempt returned "no Discord thread" for this mission; no screenshots
  were posted to Discord. Shared in NULLROOM with `share_file`; the boss/reviewer can forward them to the intended thread.
- **Still observed:** asset-type warning for `rbxassetid://203785492` (not in src); LaneSurvey's one missing and one
  inaccurate floor sample. A speed-check warning during the deliberate inter-zone teleport is a test artifact.
- **Human hand-play still needed:** free-camera comfort, aiming/steering and exact range boundary, gamepad/mobile,
  lag and two-player grabs. Scripts establish behavior, not feel. The known breakable-floor and wanted-speed HUD
  observations remain unchanged.

## 2026-11-11 · void (Hugo's PC): Feel pass after Hugo played v3.1: faster air, a free camera, a longer hook, the ring back, a landing shake
**State:** written, not committed by hand (the Obsidian Git plugin syncs it with Movement v3 and v3.1 below). StyLua,
selene and `rojo build` pass. Played in Studio by script through the runner (the same driver as the entry below, no
keys and no mouse): the numbers below are the game's own. **How it feels is still Hugo's to judge**, most of all the
camera, which a script can't move. Hugo's five points are in [Decisions](Decisions.md). Files: `src/shared/Config.luau`,
`JumpController`, `RideController`, `SandboxController`. Pictures (Hugo's PC, not in the repo):
`~/Pictures/ride-a-fish/feel-pass-2026-11-11/`.

- **Faster air** (`Config.Jump`): `AirSpeed` 38 to 54, `DropSpeed` 30 to 42, `Launch` 1.4 to 1.6, `FreeLaunch` 55 to
  78. The pull-in: `GrabSpeed` 55 to 95, `ReelMax` 0.8 to 0.7. The window, the heights and the drop are unchanged
  (3.0 s, 20 up, 12 down). Seen: off a Common at 45 the pop is 72 st/s, the glide 54, and a 3 s hop covers about 150
  to 200 studs (it was about 110); you now leave the fish beside you behind, so the fish you grab is one ahead.
- **The camera is yours** (`RideController`, `Config.Camera`): the settle behind a new fish is gone
  (`Switch.CameraSettle` deleted), and so is the hop's tilt to 30 degrees down and its swing behind you (`AirRest` 1
  gives the tilt back). The view still turns with A and D. Left alone for `LookBack` (4 s, was 1.2) it drifts back
  behind you at `Recentre` 1.2 (was 3); `AutoRecentre` 0: never. A hop and a landing count as touching it. New: a
  gamepad's right stick looks round (`StickSensitivity`); there was no stick look at all. Seen: the view's tilt stayed
  at -12 through every hop; after a landing the view held for 4 s, then came round over about 2 s.
- **The hook: 130 studs** (`Jump.GrabRange`, was 85). `Lock.DistanceWeight` 0.35 to 0.2 so a far fish you aim at still
  beats a nearer one off to the side. `Net.RangeSlack` 1.1 to 1.2: at the new air speed the server refused a grab at
  exactly 130 studs ("Denied Grab Range") with 1.1; with 1.2 grabs at 130 land. Seen: locks at 95 to 130 studs
  without touching the view, pull-ins of 0.70 to 0.77 s from 80 to 130 studs.
- **The partner's ring is back, on the locked fish** (`JumpController`, `Jump.Ring...`): the 16 yellow neon dashes of
  2026-11-10 (`git show e72fbe4:src/client/Controllers/JumpController.luau`, `placeRing`), which lay flat under the
  rider at radius 20, now lie round the locked fish at radius 15 (wider for a fish longer than that). Added so it reads
  on a fish 130 studs off: it is tipped a third of the way toward the camera (`RingFace`; 0 is flat as it was), the
  dashes thicken with distance (`RingGrow`), they turn slowly (`RingSpin`; 0 is still as it was), and the ring glides
  from one locked fish to the next. Fainter while you still ride. The fish's own glow stays but fainter (`FlyGlow` 0.6,
  `PreviewGlow` 0.85). The HUD's square bracket on the fish is still there (`HudController`, not touched): with the
  ring it may be one mark too many.
- **The landing shakes the camera** (`RideController.shake`, `Jump.LandShake...`): thrown about 0.9 studs with 2.2
  degrees of roll, 16 times a second, gone in 0.38 s, on top of the dip (`LandKick`) and the view's snap. Scaled by
  the pull-in's speed (distance over time): 0.8 times at 40 st/s, 1.3 times at 140. Seen: the camera rolled 0.9 to
  2.8 degrees at the landings measured.
- **All of it is on the N panel.** New rows: Jump `LandShake`, `LandShakeTime`, `LandShakeRate`, `LandShakeRoll`,
  `LandShakeAt`, `LandShakeBySpeed`, `RingRadius`, `RingGrow`, `RingFollow`, `RingSpin`, `RingFace`, `RingPreview`,
  `FlyGlow`; Camera `AutoRecentre`, `AirRest`, `StickSensitivity`. Gone: Switch `CameraSettle`.
- **To judge in play:** with nothing bringing the view round, you can land on a fish while looking across it and ride
  that way for 4 s unless you drag the view (on a fish the mouse looks only with the right button held). If that is
  worse than the pull was, lower `Camera.LookBack`. At 54 st/s the hop outruns the herd (38), so there are stretches
  of "FIND A FISH" with nothing locked until a fish ahead comes into the aim.
- **Not updated:** [riding feel](design/riding-feel.md) and [sandbox](sandbox.md) still give the old numbers and the
  old camera (not this task's files).

## 2026-11-11 · void (Hugo's PC): Movement v3.1 played by script on grey-box 5; one fix (the land between two lands)
**State:** one file changed (`src/shared/Zones.luau`), not committed by hand. StyLua, selene and `rojo build` pass.
Played in Studio through the new runner (`~/Projects/studio-runner/`, Hugo's PC only), with a temporary script calling
the game's own `Actions.jump`, the sandbox remote and `RideController.moveVector` (steering): no keys, no mouse, so
the feel is still unjudged. Pictures: `~/Projects/sharedDH-local/shots/` (Hugo's PC, not in the repo).

- **Seen working, with the server's own numbers:** R onto a fish; the hop (pop, glide, drop; 3.0 s); the lock and a
  grab (the pull-in took 0.87 s, landed, refill); a miss with No fail off (the 2.8 s drown, then the dock); a wall
  crash square on (speed to 0.45, 10 Oxygen of 100) and none while sliding along it for 7 s; props knocked loose (3%
  each time, 1 to 15 boxes) and home again about 9 s later; the drain by land (1, 4.6 on an Uncommon in the Reef,
  16 in the Kelp Forest); a hop at 5 Oxygen taken, no drain in the window, +25 on landing; riding dry: thrown off,
  the 5.5 s drown, the dock.
- **Fixed: `Zones.locate` found no land between two lands** (grey-box 5's zone boxes don't meet end to end: s 1100 to
  1330 and 3540 to 3770), so the server drained at the Shallows' rate there and the HUD lost the land's name. It now
  gives the nearer land; before the first land it is still none (the dock).
- **Not exercised:** aiming the lock with the mouse, a press with nothing locked, a refused grab, two players, lands 4
  to 10 (the map is built to s 4500: `R` past that puts you at the lane's end; the deep drain was tried by setting
  `ZoneDrain.3` to 160 with `TestMaxOxygen` 3840).
- **For the map chat:** `path.json`'s Lands start the Coral Reef at s 1000 and the Kelp Forest at 3500; the game's
  zones change at 1340 and 3770. `floor_tiles_*` and `stones_*` are in `Lane.Props`, so a fish knocks floor tiles
  loose.
- **Seen, not changed:** following the lane's middle a fish hits small props (sea grass, stones) every 2 or 3 s, 3%
  each: in the Shallows that costs more than the drain. The HUD's speed is the wanted speed (32 st/s shown with the
  nose held against a wall). A missed hop's drown says OUT OF AIR with the meter full. Swimming through a big coral
  puts the camera inside its boxes for a moment. Roblox's chat window covers the sandbox's top-left lines.

## 2026-11-11 · void (Hugo's PC): Movement v3.1: the hop is back, Oxygen by land, crashes, props that break
**State:** written, not committed by hand (the Obsidian Git plugin will sync it, together with Movement v3 below, which
was never committed on its own). StyLua, selene and `rojo build` pass; luau-lsp's type check finds nothing new.
**Nobody has played it, Claude included:** Studio's connector was being replaced. Expect numbers to tune and possibly
bugs, most of all in what needs the map (crashes, props). Hugo's answers of 2026-11-11 are in
[Decisions](Decisions.md); the model, the numbers and what to play: [riding feel](design/riding-feel.md), "Movement
v3.1"; two pictures: `docs/attachments/hop-arc.png`, `stamina-drain.png`.

- **The partner's hop is back** (`JumpController`): the pop (0.4 s, 20 studs up, 1.4 times your speed), the glide
  (1.4 s at the herd's pace) and the drop (the rest of the window: slower, sinking), with the pull-in and landing
  camera as they were. Movement v3's "no hop, slow down and sink" is gone, with its numbers (`SinkSpeed`, `SinkRamp`,
  `Drag`). `Config.herdTop` presses the herd down in the shallows again.
- **Kept from Movement v3:** the lock-on, A and D only, the spring camera, the window on the HUD (now the whole hop:
  `Jump.Window` 3.0, the same in every land), the server's "Grab". **Not back from 2026-11-10:** the ring under you,
  the flight making for a fish by itself, the fish and the hop turning with the camera, W and S, the landing without
  a press (`Jump.AutoGrab` 1 gives that last one back). **For the two of you:** these are Hugo's answers; the
  2026-11-10 rows they replace are named in the new Decisions rows, not edited.
- **The swim:** a pose for the pop (arms ahead), the swim strokes in the glide, longer strokes and a harder kick in
  the drop (`AnimController`, from `State.JumpPhase`).
- **Oxygen is the stamina, and it is the progression** (`RideService`, `Config.ZoneDrain`): what a ridden fish takes a
  second goes by the land you are in (1, 4, 14, 48, 160...), times 15% for each rarity above Common. It was by the
  fish's home land and rarity (`Required / Seconds`; `Tier.Seconds` and `FishType.Drain` are gone, `Required` is now
  worked out from the drain). A hop is never refused for Oxygen and costs none. The HUD shows the drain a second and
  what a land needs.
- **Crashes** (`Config.Crash`): a ridden fish run square into something solid loses speed (the client, told by the
  server: `Net.Ride` "Crashed") and a tenth of max Oxygen (the server), never the last of it. Never a death.
- **Props break** (new `src/server/Services/PropService.luau`, `Config.Props`): the boxes of
  `Workspace.ClaudeBlockout.Lane.Props` are knocked loose by a fish and tweened home after 8 s, all on the server. A
  ridden fish swims through them (`Course.begin(true)`); wild fish only when inside a big thing's circle. Players'
  characters are in a "Riders" collision group that doesn't collide with "Props".
- **The sandbox panel** has every new number, and one row a land for `ZoneDrain`; [the sandbox note](sandbox.md) is
  brought up to date (it still described the first jump's numbers).
- **To check by feel:** the six points at the end of "Movement v3.1" in [riding feel](design/riding-feel.md). Turn
  "No fail" and "Endless air" off for the real rules.
- **Open:** training max Oxygen isn't built, so the third land can't be kept up in without `TestMaxOxygen`; whether
  only big creatures break props (`Props.MinLength`, 0 now); map-method.md still says props break "on the player's
  own screen only" (the map chat's note: it is the server now); the server's crash check is a ray along the nose, so a
  fish swung side-on into a wall isn't counted.

## 2026-11-11 · void (Hugo's PC): Movement v3 on top of JumpController, not played yet
**State:** written, not committed by hand (the Obsidian Git plugin will sync it). StyLua, selene and `rojo build` pass.
**Nobody has played it, Claude included:** Studio was open but its MCP server did not answer, so there was no playtest.
Expect numbers that need tuning and possibly bugs. Hugo's brief of 2026-11-11; a Codex draft finished and reviewed by
Claude. The model, every number and what to check: [riding feel](design/riding-feel.md), "Movement v3".

- **This changes how fish to fish plays,** and overrides several of 2026-11-10's rows in [Decisions](Decisions.md)
  (the pop, glide and drop; the fish turning with the camera; the hands-off landing; grabbing without looking). Those
  rows are **not** edited: for Hugo and his partner to settle. The partner's `JumpController` is still the base: its
  pull-in curve, landing camera, glow, trail dots, `Course`, `LaneSurvey` and the sandbox are kept. Nothing deleted
  came back (no Grapple or Dash controller).
- **Leaving a fish** (Space): no hop. You keep going forward, slow in the water from the speed you rode at to 24 studs
  a second, and sink (5 studs a second, easing in). That opens the window: `Jump.Window`, 3.0 s, shown as a bar and
  seconds under a reticle in the middle of the screen, red and pulsing for the last 0.8 s. Out of time with no fish:
  the short drown (in the sandbox with No fail on: you float).
- **Steering:** always forward; only A and D steer, at one rate (`Ride.YawRate` 95) on a fish, in the swim and
  floating. W, S and the mouse no longer steer or change speed; a ridden fish keeps the herd's height by itself.
- **The lock-on** (new `src/client/Lib/Lock.luau`, `Config.Lock`): a cone along where the camera looks, wider for near
  fish; scored by angle and distance; nothing past `Jump.GrabRange` (85); sticky so it doesn't flicker; the locked
  fish keeps the yellow glow and gets a bracket on the screen. It shows faintly while you still ride. Space again, a
  left click, E or gamepad X grabs the locked fish; with none locked the reticle flashes red. In the swim the mouse
  aims with no button held.
- **The camera** (new `src/client/Lib/Spring.luau`): where it looks from, its turn, its zoom and its field of view each
  go through a critically damped spring, so riding, the swim, the pull-in and the landing run into each other. The
  pull-in now eases into its arrival; the landing's snap, jolt, burst and glow fade are as before.
- **Server** (`RideService`): new actions "Grab" (checks the fish is free, in range, not behind something solid, and
  keeps it for the player) and "CancelGrab"; "Land" is only taken for the fish that was granted; its own clock ends a
  window or a pull-in that the client never finishes.
- **What Claude changed in the Codex draft:** `Lock.LeftPenalty` 0 to 0.5 (the fish you just left sits in the middle of
  the view and took nearly every lock); the server's range check allows `Net.RangeSlack` (1.1) over the 85 for lag, and
  no longer refuses a grab for coming early; every number of Jump, Lock, Ride, Camera and AimHud is on the sandbox
  panel (N); the trail's timing reads Config live.
- **For Hugo to check by feel** (Play in Studio; N, then turn "No fail" off to judge the real window):
  1. Is 3.0 s enough to find and grab a fish, and short enough to press? (`Jump.Window`, 2.5 to 3.5.)
  2. The slow-down and the sinking: too floaty, too fast? (`Jump.Drag`, `AirSpeed`, `SinkSpeed`, `SinkRamp`.)
  3. Do you get the fish you look at? Aim between two fish, then at each; aim at a far one past a near one.
     (`Lock.Cone`, `AimRadius`, `DistanceWeight`, `Sticky`, `LeftPenalty`.)
  4. A and D on a fish and in the swim: the same feel? Is 95 degrees a second right?
  5. The camera through a whole chain (ride, leave, pull, land, ride): any snap, lag or wobble? (`Camera.FocusTime`,
     `TurnTime`, `ZoomTime`.) Does the landing still hit?
- **Not done:** [the sandbox note](sandbox.md) still describes the old jump's numbers and switches (not this
  session's file); two players going for one fish and bad lag are untested; phones aim by dragging, untried.

## 2026-11-10 · 8570-F43F (the user's PC): fish to fish is now the reference's jump
**State:** built and run in Studio by Claude (pressing Space through the connector): floating onto a fish, riding, a
jump onto the next fish, the early drop, and a miss into the drown. StyLua and selene pass. **No person has judged the
feel yet.** The user decided this with void's owner: [Decisions](Decisions.md), 2026-11-10.

- **Gone:** the corkscrew dash, the hook window (slow motion, reticle, rope) and the eaten death.
  `DashController`, `GrappleController` and `Lib/Eater` are deleted; E, F and Q no longer do anything.
- **New:** `src/client/Controllers/JumpController.luau` and `Config.Jump`. Space throws you into a flight you steer, a
  dashed yellow ring lies in the water under you, the fish inside it glows, and you land on it. How it works and what
  differs from the reference: [riding feel](design/riding-feel.md).
- **Server** (`RideService`): states are now Dock, Free, Riding, Jumping, Drowning. Remote actions are "Jump", "Land"
  and "Miss".
- **Fish are twice as dense** (`Config.Spawn.PerThousand` 24), so a jump has a fish within its flight. To tune.
- **Second pass the same day, after the user played it:** the flight is launch, float and drop (3.65 s), with a fast
  pull onto the glowing fish and a short drown when a drop finds nothing; a miss from floating drowns too. Wild fish
  now swim as a herd: all straight down the lane, at 0.85 of ridden speed (measured from the reference), in one layer
  16 to 30 studs above the floor, and a ridden fish follows that layer when W and S are let go.
- **Third pass, after the user played the second:** a ridden fish turns to where the camera looks (A and D turn the
  camera), and so does the flight; a second press with nothing in the ring grabs the best fish within 45 studs, the one
  you left included; a fish near by is grabbed in the drop without a press. Fixed: A and D did nothing on a fish (the
  player module gave no move vector), so `RideController.moveVector` now reads the keys as well.
- **The movement sandbox** ([how to use it](sandbox.md)): in Studio the game now starts with no fail and endless air,
  with R, V and N for a reset, a side view and a panel of every movement number. `Config.Sandbox.On = false` starts
  Studio with the real rules instead. A published game never has it.
- **The pull-in and the reach:** the pull onto the fish follows the reference's measured curve (`Jump.ReelCurve`, on a
  line from the hand); the grab reaches 85 studs whichever way you look, and 50 without a press in the drop.
- **The flight's shape and the landing's camera,** from a side-on recording: a 0.3 s pop then a flat glide; at the
  landing the view snaps 12 degrees wider and settles (`Jump.LandFov`), the camera is jolted (`Jump.LandKick`), and
  yellow dots trail the pull-in instead of the line.
- **Front targeting and height:** a jump makes for the nearest fish in front (`Jump.AheadCone`), never the one it left
  unless nothing else is in reach; it rises `Jump.Apex` above the fish in front; the herd swims lower (8 to 16 studs
  above the floor) to leave water to jump into.
- **Higher, and always underwater:** `Jump.Apex` 20; the flight stops `Jump.Ceiling` under the surface; in shallow water
  the herd is pressed down to leave the jump its room (`Config.herdTop`, `Spawn.HeightFloor`). The lagoon and the
  Shallows are 9 studs deeper for it (`LAGOON_Y` -39 in `tools/studio/claude_blockout.luau`; every later zone moves
  down with it), which gives the Shallows the whole 21-stud rise. The map in Studio was rebuilt from the script.
- **A critical pass of the riding code (2026-11-10):**
  - The "flown under the map" bug: fish are CanCollide false and the floor check was a ray from the fish itself, which
    sees nothing once it is inside a part. New `src/client/Lib/Course.luau` keeps the ridden fish (`clearVelocity`) and
    the flight (`clearMove`) in open water: rays from where we are (solid parts only), plus the lane's own floor and
    edge from the map's centreline, which the server now publishes to clients (the `LanePath` attribute on Remotes).
  - Air steering: A and D steer the flight; the camera no longer does (`Jump.CameraSteer`).
  - Taken out: the flight's ribbon and bubbles (`Fx.trail`), the launch ring, the launch's view widening
    (`State.FovKick`), the landing rattle (`State.shake`, `Burst.Kick`), the glide's bob, and the `Fx` "Jump" event.
  - Also: a pull-in is given up if its fish is put away or taken; no dividing by a sandbox number set to 0; the camera's
    and the fish's ray settings are made once, not every frame.
  - Run in Studio: a fish dived at the floor and steered into the lane's wall stayed in the water; three jumps landed.
- **A second, independent review of the same code (2026-11-10), and what was done with it:**
  - **The lane's floor was not the built floor.** The map's `Path` is the design's curve every 100 studs; the seabed
    is straight slabs. At the foot of every drop-off the two were 13 to 23 studs apart, so wild fish swam through the
    sand there. New `src/server/Lib/LaneSurvey.luau`: at startup the server drops a ray onto the seabed every 10 studs
    of the centreline and uses that as the lane (and publishes it to clients). After: within 3 studs at all but 13 of
    4,756 places checked along the centreline. Still seen: a fish near the lane's edge on a ramp in a bend can be up to
    7 studs into the sand (the lane is taken as flat from side to side; v4's slabs aren't quite).
  - **`Workspace.FallenPartsDestroyHeight` was -500 and the lane goes down to -1,622:** Roblox destroys fish and
    players below it. A game script can't change it; it is set to -20,000 in the open place by hand, the server now
    warns at startup when the lane goes below it, and the map script needs to set it.
  - Fixed: the descent is slowed before the floor instead of pushed back after it; a hitch can't carry a flight
    through a wall (frames over 0.05 s are flown as 0.05 s); the fish you left coasts in open water too; with no floor
    known a ridden fish levels out instead of nosing down; floating under the lane's floor is lifted back above it.
  - Fixed: the Oxygen refill is not given for landing back on the fish you left, nor for a landing sooner than a flight
    can be (hopping off and on the same fish refilled a quarter each time).
  - Fixed: a fish that reaches the client after the server's "mounted"; a jump the server took that the client isn't
    flying; a rider's fish left marked as taken after a respawn; three sandbox values that broke things at 0 or when
    crossed (`Ride.YawRate`, `Jump.GrabSpeed`, `Spawn.HeightMin` over `HeightMax`).
  - **Not done:** the landing's effect still makes new parts and a sound each landing (`Fx.landing`), and the poses
    build a table per player per frame (`AnimController`): performance only. The server still trusts where the client
    says it landed, within the flight's reach.
- **Grey-box 3 of the new map is in Studio (2026-11-10)** in place of blockout v4, loaded from
  `tools/studio/greybox/*.luau` (the map chat's; 4,905 parts, three lands, 4,500 studs). v4 comes back by running
  `tools/studio/claude_blockout.luau`. On it:
  - The game starts as it is: the lane's floor surveyed (over 3 studs off at 1 place of 566), fish spawn, running off
    the hub floor puts you in the water, a jump lands, a ridden fish stays in the water.
  - **The herd steers round the big obstacles** (`Zones.bigAssets`, `mindObstacles` in `FishService`, `Herd.Obstacle*`
    in Config): a fish that would pass too near one ahead moves its place across the lane, and one already inside the
    margin is pushed out. Measured: 0 wild fish inside an obstacle in 1,432 close passes (before: fish swam through).
  - `Oxygen.DockRadius` 520 to 300 for the new hub.
  - **Grey-box 4 since (the map chat's hub and texture pass, same lane):** the game runs on it; three jumps landed,
    the first from the start. `Oxygen.DockRadius` is 120 for the smaller hub (the spawn is 78 studs behind the start).
    Jumps took about 3.4 s against 2.2 on v4: the glide ended with no fish in front and the catch came in the drop.
  - **Grey-box 5 (a bigger hub, 436 by 202; the spawn 70 behind the start):** loaded, 7,198 parts. The game starts on
    it and a jump from the start landed. Seen once on that landing: the server's "fish moved too fast" warning
    (`checkSpeed`), not looked into.
  - **Hub walking speed 28** (`Config.Dock.WalkSpeed`, the user through the map chat; Roblox's own is 16): measured
    27.7 in play on grey-box 5.
  - **The ride's camera, floating and steering no longer start 10 seconds late.** `RideController.Start` waited up to
    10 s for Roblox's `PlayerModule` before binding its frame step, and in this Studio `PlayerScripts` has no
    `PlayerModule` at all. It is looked for on the side now. Fixed by reading the code; not timed in play.
- **Rojo is connected (2026-11-10):** `rojo serve` runs from this PC and the user connected the plugin, so `src/` syncs
  into Studio by itself. The push script is no longer used.
- **Modelled creatures, game side (2026-11-10), waiting on the upload:**
  - The user chose to upload the creature chat's 33 voxel creatures as meshes (one GLB each, vertex colours).
    **Nothing is uploaded:** Studio refuses until the user grants `asset:read` and `asset:write` under Assistant
    settings, MCP Permissions, and approves the folder `art/creatures`.
  - `tools/creatures/collect.py` writes `src/shared/Creatures/<Id>.json` from each export's `mesh.json`;
    `Shared.Creatures` reads them. `FishModel.fromRig` joins a model in `ReplicatedStorage.FishModels.<Id>` by them
    (a Motor6D `Rig_<part>` at each pivot); `AnimController` plays the keyed swim on those joints.
  - Tested on a block stand-in of the Reef Shark (`ReplicatedStorage.FishModels.ReefShark`, marked `StandIn`: one box
    a part): the tail sweeps 1.67 studs each way. Reef Sharks in the game are those grey blocks until the mesh is in.
  - **Uploaded 2026-11-10, on the user's word: all 33 creatures,** one GLB each as a Roblox Model asset through
    Studio's connector (Open Cloud; the user granted `asset:read`, `asset:write` and the folder). The ids are in
    `tools/creatures/assets.json`. All were approved by moderation.
  - `python tools/creatures/install.py <studio_id> [Id ...]` puts them in the place as
    `ReplicatedStorage.FishModels.<Id>`: it loads each asset, turns it half round (Roblox's GLB import turns a model
    180 degrees about up), flattens the importer's nested models, and makes the parts white SmoothPlastic so the vertex
    colours show. Part names, sizes and vertex colours came through the upload unchanged.
  - Each creature's rarity, land and size now come from its export (`Tier`, `Zone`, `Size` in
    `src/shared/Creatures/<Id>.json`; Config adds them to its fish table). Speed and Oxygen use follow the rarity, as
    for the placeholders. The six unmodelled placeholders are kept (Garibaldi, Leopard Shark, Great White for the Kelp
    Forest; Barracuda, Goliath Grouper).
  - **In play on grey-box 5:** 21 kinds spawn with their models (every creature of the Shallows and the Coral Reef,
    105 fish), swim with their keyed motion, and can be ridden (rode a Cuttlefish). The other 12 live in lands the
    map doesn't have yet, so they don't spawn. No script errors. Nobody has looked at them in play yet: Studio
    wasn't drawing for captures after the first ([the Reef Shark](attachments/creature-reefshark-in-studio.jpg)).
  - **The first uploads were too dark** (the export wrote vertex colours as linear light; Roblox shows them as
    stored). The creature chat fixed its exporter; the corrected Reef Shark was uploaded and checked against plain
    parts in the design's colours ([capture](attachments/creature-reefshark-colour-fix.jpg)) and is installed. The
    other 32 are re-exported and wait for the user's word to upload; the 33 dark assets are still in the inventory.
- **The friend's mechanics work is built on this repo's code (the user, 2026-11-11),** in his own Roblox file. Until it
  is pushed and merged the ride, jump and camera code here is left alone.
- **Grey-box 6 (2026-11-11, the map chat: every wall rebuilt as a 1-stud face with a hollow behind and grass on top):**
  the game runs on it at 59 frames a second in Studio on this PC (12,933 parts). One change was needed:
  `Ride.LaneMargin` 20 to -3. A ridden fish was allowed 20 studs past the lane's edge, which is now inside the hollow
  behind a wall face, and one got boxed in there under the grass. Now the fish and the flight stay 3 studs inside the
  edge; in the re-test it never passed the edge and stopped at the wall as it should.
- **Grey-box 7 (2026-11-11, the map chat: the lane itself changed: a straight first land, 120 to 515 wide, one smooth
  floor, a wall or rim on every edge with an unseen barrier behind):** the game runs on it with no code change.
  - The floor survey is within 0.1 stud of the built floor everywhere (985 places). 52 obstacles, read from the map.
  - The herd: 118 fish; a fish's nearest neighbour is 40 to 49 studs away on average, about the same in the narrow
    and the wide rooms.
  - Four jumps in a row landed, each with the whole 21-stud rise; they took 3.2 to 3.7 s (the catch came in the drop,
    as on grey-box 6). A ridden fish steered at a wall stopped 8 studs short of it and never passed the lane's edge.
  - The frame rate read 15 a second in this run; the run before (grey-box 6) read 59 and an earlier one 15 too, so it
    is probably Studio not being drawn, not the map. Not settled.
- **Grey-box 8 (2026-11-11, the map chat: all ten lands, 56,894 parts, the lane 30,000 studs long and up to 980
  wide, 2,225 deep):** the game runs on it after one change to the herd.
  - As loaded: the floor survey within 3.1 studs everywhere; fish in every land; 302 obstacles read from the map.
  - **Found:** the 480-fish limit (`Spawn.MaxTotal`) was used up by the deep lands, so the Shallows held 11 fish 90
    studs apart; and the herd spread over the whole width of the wide lands. Riding a fish in the Vents (the sandbox
    reset moved there), three jumps in a row found nothing to land on.
  - **Changed:** `Spawn.MaxTotal` 800, and the herd keeps to a band at most 200 studs wide down the lane's middle
    (`Spawn.BandMax`, `band()` in `FishService`). After: 741 fish, a fish's nearest neighbour 38 to 49 studs away in
    every land, and four jumps in a row landed in the Vents (2.6 to 3.0 s each).
  - **Not settled:** the frame rate. Every reading through the connector in this session was 15 a second, which looks
    like Studio's limit for a window that isn't in front; the one reading of 59 was on grey-box 6. Needs the user's
    own eyes on the ten-land map.
  - **Seen, for the friend's mechanics (the held code):** a player floating off a fish rises 6 studs a second with no
    limit below the surface, so in deep water they are out of a jump's reach of the herd within about 7 seconds.
  - **Seen, not solved:** the first jump from the start missed in one run (the herd swims off at the flight's own
    pace, so a diver starting from rest can't catch a fish ahead); a ridden fish left alone runs into a wall or an
    obstacle and stops, because the lane winds and the fish only turns with the camera; a jump's flight against the
    obstacles is the user's open decision.
- **Kept:** Oxygen, the throw-off and the drown, the speed-up on mount, the bubble burst, map v4.
- **The Studio place on this PC is not in the repo.** It was rebuilt in an unsaved place from `claude_blockout.luau`
  and `src/`; the user saves it locally.
- **Open:** the ring and landing effects for a floating fish, tuning the glow and outline, a revive after a miss, and a
  ridden fish left alone swimming out of the lane and up to the surface.

## 2026-11-10 · 8570-F43F (the user's PC): void's draft merged with the creature work of the 10th
**State:** merged and pushed by the Obsidian Git plugin. StyLua and selene pass and `rojo build` builds the place. **Still
no one has played it**: the playtest is the next thing.

- **What came in from this PC:** the Yellow Tang, Sea Turtle and Stingray built on one kit (`kit_common.py` under
  `fish_kit.py`, `shell_kit.py`, `disc_kit.py`), the voxel style test (`voxel_kit.py`, five creatures), the rarity look
  notes, and [Sessions](Sessions.md) (which Claude chat has which files in hand).
- **Three clashes, both sides kept:**
  - **Decisions:** both sets of rows are in. Note for the user: void's rows replace stamina with an **Oxygen** meter for
    riding and falling off with drowning or being eaten. They were written on void, so the user hasn't confirmed them here.
  - **The fish kit:** `fish_kit.py` had moved onto `kit_common.py` here while void added `--export` and new spec pieces
    (belly, coloured bars, fin tips, spikes, `viewScale`) to the old single file. The two don't merge line by line, so
    void's file is kept whole as `tools/blender/fish_kit_export.py`, and `art/creatures/build.py` now runs that one.
    `fish_kit.py` is this PC's version and has **no `--export` yet**.
  - **The Yellow Tang:** the folder holds the hand-built one (spec, renders, sheet). Void's placeholder spec, renders and
    sheet moved to `art/creatures/YellowTang/placeholder/`; its `YellowTang.obj` game mesh is unchanged.
- **Open:**
  - Move `--export` and void's spec pieces into the kit proper (`kit_common.py`), so the shell, disc and voxel creatures
    can export game meshes too, then delete `fish_kit_export.py`.
  - The playtest of the riding, the hook and map v4.

## 2026-11-10 · void (Hugo's PC): first playable draft and round 2, not playtested yet
**State:** the code builds and passes StyLua and selene, but **no one has played it in Studio yet**: Studio's MCP server
was off on void the whole time, so the playtests were ended without a run. Expect bugs and numbers that need tuning.

- **Riding** ([Riding feel](design/riding-feel.md), numbers in `src/shared/Config.luau`):
  - **Oxygen** drains while you ride, and the fish speeds up from idle.
  - **Out of Oxygen**, the fish throws you off and you drown (bubbles slow down and stop).
  - **The corkscrew dash** takes you fish to fish and refills Oxygen.
  - **Jumping off** opens a 2.5 s hook window (slow-mo, a reticle on the best fish, a rope, a smooth pull into the mount).
    Miss it and a big fish eats you.
  - **A bubble burst** on every landing.
  - **Fish** spread over the whole lane.
  - New files: `src/client/Controllers/DeathController.luau`, `src/client/Lib/Eater.luau`, `src/shared/Lane.luau`.
- **Map v4** ([Blockout](blockout.md), `tools/studio/claude_blockout.luau`):
  - A half-circle island with the flat side to the dive, so it's a short walk from spawn to the board.
  - Shops on the sides of a wider dock, and big plots/tanks.
  - A diagonal dive lane with a signature formation per zone.
  - Matching prop clusters along the sides, and a Subnautica-inspired look per zone.
  - About 6,900 parts. Props are part stand-ins tagged `PropName`, swapped for the Blender meshes once the meshes are
    uploaded (uploads need the user's OK).
- **Art:**
  - Placeholder fish built with the fish kit (Yellow Tang, Clownfish, Pufferfish, Reef Shark) as OBJ in `art/creatures/`.
  - A prop kit (`tools/blender/prop_kit.py`): rocks, corals, kelp, glow plants and clusters as FBX in `art/props/`, with
    `props.json` and contact sheets.
  - `fish_kit.py` gained `--export <mesh.obj>`.
- **Merged with the partner's work** (head and mouth, `--wire`, Yellow Tang, Sea Turtle, Stingray notes, workout 3): both
  sides kept. The one code conflict was `fish_kit.py`'s options (`--export` and `--wire`), and both are in.
- **To try it:** `rojo build -o ride-a-fish.rbxl` (or `rojo serve`; on void Rojo runs on port 34873), then run
  `tools/studio/claude_blockout.luau` in Studio to build the map. On void, the built place is
  `~/Documents/RideAFish/ride-a-fish-map.rbxl`.
- **Open:**
  - The playtest itself.
  - Importing the fish and prop meshes into Studio (an upload, so it needs the user's OK).
