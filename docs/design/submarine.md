# The submarine (the carry to a land)

Up: [the dive-in](dive-in.md), [riding feel](riding-feel.md), [the hook](hook.md), [money](money.md),
[progression](progression.md), [the aquarium](aquarium.md). The reference's version:
[Ride a Dino](../reference/ride-a-dino.md) ("Jurassic Airlines") and
[the deep study](../reference/ride-a-dino-deep.md) ("Zones, gates and travel").

Written 2026-11-17 by worker m1 on Hugo's order:

> "Ride a Dino has a feature where you start up and instantly get carried by a pterodactyl, my friend wants to
> implement this same feature as a submarine, try to impliment with animations and camera movements, you should jump
> in the water start swimming while the submarine swims in and picks you up, then swims really fast to your
> destination, each area should have its own upgrade tier increasing the distance to the area, make sure that when
> youre let go you either get flung forward instantly going arial(with no selected fish), or your fish swims beside the
> submarine then you get kicked out onto the fish being able to play normally after that, there should be custom
> animations for getting picked up and getting dropped off but add this and make sure its satisfying, dont implement
> custom models yet only use placeholders."

**Built 2026-11-17, placeholders only:** the submarine is a few plain parts, and the pick-up and drop-off are moved
by code. There are no uploaded animations. **Run by script in Studio to lands 2, 3, 5, 7 and 10, both drop-offs;
not played by hand** ([the playtests](../playtests/2026-11-17-submarine.md), clips:
[fling](../attachments/submarine-fling.gif), [fish](../attachments/submarine-fish-dropoff.gif)). Where this note says
**reading, not confirmed**, it is a guess at what Hugo meant, waiting for his word.

## What the reference does
- **"Buy once. Fly forever."** A stall by the start sells one flyer per zone, each bought once (Desert $25M, Snow
  $1B, Giant Forest $50B, Abyss Ocean $500B, Volcano $5T, Extinction $50T, or Robux). You "Equip" one flight; that
  is where you go.
- **F at the hub starts it.** A banner, "JURASSIC AIRLINES: Snow". You fly the pterosaur yourself over every zone on
  the way, about ten seconds, between two white lines. Then "NOW ARRIVING" and "Drop onto a dino!": you pick the dino
  you land on. Commenters say your own dino and the flight go together: you land already mounted.
- **Why it matters** ([findings](../Findings.md) and the deep study): players stick in zones 5 to 7, and a creator
  paid Robux for the zone-6 flight the minute he saw it. Late on, the early zones are dead time; the flight is what
  skips them.

## How ours goes, beat by beat
1. **At the sub stand** (2026-11-18, Hugo: "remove the sub button, make the player able to buy the subs there and
   equip them"): walk onto the SUBMARINE stall's circle on the floor and the shop opens; walk off and it closes
   (2026-11-24, the same way as Sell and Auras: `StallController`, no E prompt any more; the X shuts it until you
   step off and on again). A small copy of your equipped sub (the Bathtub when you have none) floats and turns over
   the stall, on your own screen only (`SubStandController`; checked in Studio by
   `python tools/studio/h4_hub_check.py run rings sub`). The shop lists nine subs, one a tier
   (Bathtub, Reef Runner, Kelp Cruiser, Wreck Diver, Blue Streak, Twilight Ray, Midnight Hunter, Vent Crawler, Abyss
   King), each with its picture, the land it reaches and its price. You buy them in order (free for now), and
   **equip** one; the equipped sub is the one that comes for you, and it reaches its own land or any before it.
   "NO SUB" is the ordinary dive-in. Under the list, GO TO picks the land and RIDE WITH a fish from your tank.
   The shop closes as you walk away. A small ticket at the left edge says where the sub will take you.
2. **You jump in.** With a destination picked, stepping off the dock is no longer the dive-in's auto-hop: you drop
   in with a splash and **swim** at the surface, breaststroking forward.
3. **The sub swims in** from behind and below (1.2 s; 1.6 until 2026-11-24), its light on you, a wake of bubbles. The camera is behind
   you on your own line, close at first and drawing back as you swim on, and tips down so the sub shows as it comes
   in under you (see "The camera is always behind").
4. **The pick-up** (0.75 s; 0.96 until 2026-11-24): it rises under you, the camera stays behind you and draws back, you are scooped up in
   a tumble (a tuck and a half-turn) and set on the seat behind the tower. A bump, a shake, the view kicks.
5. **The run:** it noses down and goes. The view, already behind, pulls further back behind the sub and widens with
   speed, streaks of bubbles, speed lines. No banner as it sets off (Hugo, 2026-11-20: "let the intro text for submarines begone"). It follows the herd's own line down the lane (the stream: the
   middle of the open water, bent round the big things), well above the fish. 3.2 to 7 seconds whatever the land,
   its top speed growing with the distance (task f2, below: about 500 studs a second to land 2, 2,100 to land 5,
   4,250 to land 10), picking up over a fifth of the run and slowing over a quarter of it.
6. **Arriving:** "NOW ARRIVING" over "KELP FOREST", in the land titles' own look (see "Titles on the run"). It
   slows to the speed of a quick fish (90). The camera stays behind the sub through the drop-off, a little further
   back (36 studs, not 30) when your fish swims up beside it, so the fish is in the picture without the camera going
   to its side.
7. **The drop-off**, one of two:
   - **(a) No fish picked:** the sub pitches its nose up and **flings you forward**. You leave at its speed into an
     ordinary hop (the pop, the glide, the drop, the lock and the hook), so you hook the nearest fish as in any hop.
     It is the dive's first hop, so a miss leaves you floating rather than drowning (as the dive-in's). Six fish of
     the land's herd are put in the water just ahead of the drop point 2.5 s before you arrive (`Sub.Stock`): without
     them the first fling to land 5 found nothing in reach.
   - **(b) A fish held or picked:** your fish **swims up beside the sub** (from behind, on the right, 1.1 s, matching
     its speed), then the sub **kicks you off sideways** in an arc onto its saddle (0.5 s). The fish you hold over
     your head as you go in comes first (task f2, below); else the tank fish picked under RIDE WITH. You land as on any fish: the
     shake, the splash, the refill. From there you play normally.
8. **The sub peels away** up and to the side, and is gone.

The player can't steer or hop while carried, and no Oxygen goes. The whole trip is decided by the server.

### The camera is always behind (Hugo, 2026-11-23)
**In the game since 2026-11-24** (`862ff88`, `5f18f3f`; measured in Studio, passed by the mission's reviewer; Hugo has
not played it yet).

Hugo, after seeing a side view of the sub in a dev session: "what is this new camera perspective for the submarine? i
saw it playing in dev sesh, make sure it doesnt implement the camera on the side ever". Read as a rule for every
phase of the trip (the boss's reading, mission "submarine camera always behind"):
- **Behind, on the middle line, in every phase:** behind you on your own line while you swim and are scooped up,
  behind the sub on its line for the run, the arrival and the drop-off. Nothing in the camera's place or in where it
  looks goes to the side (`SubController.cameraFor`).
- **No swing round:** a camera that starts in front and comes round to behind passes the side on the way, so it
  starts behind too. Before this the approach sat ahead of you and 5 studs to the side looking back, the pick-up
  swung round through up to 9 studs to the side, and the arrival stood 6.4 studs to the fish's side and looked
  8 studs that way.
- **What that costs:** from behind you no longer watch the sub come from far off. It comes in under the camera and
  rises into the bottom of the picture in about the last third of a second of the swim, then is in view for the
  whole scoop.
- **The fish at the drop-off** is 16 studs to the right of the sub. From 36 studs behind it sits about 23 degrees off
  the middle of the picture: well inside a wide screen (53 degrees each way) and a tablet (45), at the very edge of
  a phone held upright (23).
- **The gate's kelp goes see-through for you while the camera is behind it** (2026-11-24, added when the camera was
  measured; Hugo has not seen or picked this). The kelp curtain under the dock's lip (`Dock.Gate.Kelp`) hangs between
  a camera behind you and you from about half way through the pick-up until the sub has left: the first stills were a
  wall of green ([before](../attachments/subcam-kelp-before-fix-pickup.jpg)). The camera's pull-in cannot keep out of
  it, because the kelp is not something a ray can hit (`CanQuery` off). So on your own trip the 25 plates under the
  water are see-through on your own screen from the trip's first frame until one second into the run, then back
  (`SubController.gateKelp`; nobody else's screen changes). The camera looks away from the dock, so the kelp going
  and coming back is not in the picture ([after](../attachments/subcam-behind-fish-2-pickup.jpg)). To undo it alone:
  `git show 5f18f3f -- src/client/Controllers/SubController.luau | git apply -R --index`, then commit (a plain revert of that commit conflicts in this note). Another way would be to keep the camera in front of the curtain (closer to you for the
  whole pick-up); not tried.
- **Measured in Studio 2026-11-24** (`python tools/studio/sub_camera_check.py`, every frame of scripted trips; stills
  `docs/attachments/subcam-behind-*.jpg`), on calm frames, old camera in brackets:
  - Swim and pick-up: 0.00 to 0.02 studs off your line and under 0.1 degrees off straight behind (5.0 to 8.4 studs,
    161 degrees: in front). The shake moves it up to 0.6 studs.
  - Arrival and drop-off: at most 2.3 studs and 4.0 degrees off the sub's line, from the lane's bend (6.4 studs,
    12 degrees). Behind in every frame, 30 studs, 36 with a fish.
  - The hand-over to the hop and to the saddle: under 1 degree of turn and 2.4 studs of move in a frame, as before.
  - The run is the old code and lags the sub's nose in a bend: 8 degrees to land 2, 17 to 21 degrees for 7 or 8
    frames to land 10 (4,267 studs a second; the old camera reads the same there), 15 to 16 for a moment after going
    in at the very end of the dock's lip (the old camera: 16, and up to 24 in the shake).

### Getting on is quicker (Hugo, 2026-11-24)
Hugo: "i liked how there was a little camera movement on the intro of the submarine when jumped into the water, make
it a little shorter and speed it up.(just the animation getting onto it (at most 2-3 secs)".
- **Getting on takes 1.95 s, was 2.56** (`Sub.Approach` 1.2, was 1.6; `Sub.Pickup` 0.75, was 0.96). The swim is as far
  as before (`Sub.SwimOut`, 12.8 studs, was the swim speed x Approach), so it is the same move, played quicker.
- **The camera's move is kept:** its easing in these two phases goes by their lengths (`cameraFor`), so it draws back
  and tips as far as before. The seat's shake goes with the landing, not a fixed 0.15 s before the run.
- **Reading, not confirmed:** the camera movement meant is the one in the game now (behind you, drawing back, tipping
  down to the sub), not the old one that started in front and swung round, which his rule of 2026-11-23 rules out.
- Nothing after the sub sets off is changed.

### Titles on the run (task t1, Hugo 2026-11-20)
Hugo: "let the intro text for submarines begone ... add a special rule for submarines, if title pops up, make sure
that the old ones blends out quicker to fit in the next title directly after, now arriving text should be just as
stylised as the area text ... replace the area text with the arriving text in these cases."
- **No intro:** nothing comes up as the sub sets off.
- **Each land crossed** shows its ordinary land title (`UI/LandStrip`'s intro, `Kit.LandIntroLook`, Punch by
  default). On a run a title due while the last one still shows hands off: the old one blends out in
  `Config.SubTitles.Out` (0.18 s), the new one comes in `Gap` (0.04 s) after it is gone. Never two at once, and
  nothing queues: if lands go by faster than that, only the newest land's title comes in.
- **NOW ARRIVING** is the arrival land's title, in the same look: the small line over the name says NOW ARRIVING
  where it would say LAND 5, the name in the land's colours, the same pop in and fade (looks 1 and 2; the other looks
  use Punch's layout for it). It stays `SubTitles.ArriveHold` (1.9 s) and hands off from any title still up.
- **The arrival land's own title never shows** on a sub trip, even when the sub crosses into it before the slow-down
  or you cross the border after the drop; also when it is the first land crossed (a trip to land 2). Held back until
  you are back on the dock; a trip given up before the drop releases it.
- Swimming and riding keep their titles exactly as before; only a title that came up on a run hands off to the next.
- Checked by `tools/studio/sub_titles_check.py` (a run to land 10 and one to land 2, every title logged with its
  time from the trip's start).

## The held fish, and a faster sub (task f2, Hugo 2026-11-20)
> "jumping into the gameplay loop with the fish should let you ride it after submarine, make animation and
> travelling slightly faster, make travelling faster the further away the destination too."

**Built and run by script in Studio; not played by hand** ([the playtest](../playtests/2026-11-20-held-fish-sub.md),
clip: [held-sub-ride.gif](../attachments/held-sub-ride.gif)).
- **The ride fish rides with you** (task f2 built it for the held fish; since task e3 it is the **equipped** fish:
  hold a fish, press Q, [the ride fish](equip.md); a fish only held no longer counts). Equip a fish and go into the
  water. With a sub and a land picked: after the run that fish swims up beside the sub and the kick puts
  you on it, riding (the drop-off (b) above). With no sub (NO SUB equipped, no land, or `Sub.On` 0): you are put
  straight on it where you go in, instead of the dive-in's hop. It is that very fish: its kind, size and colour, so
  its speed and archetypes too. It is yours, so riding it tames nothing new; it is held to the usual rule, so a fish
  too strong for your Oxygen breaks off the meter and turns angry as any would (seen: an Epic Reef Shark on the
  starting Oxygen).
- **It is borrowed, never lost** (a reading, not confirmed by Hugo): it stays in your hands the whole dive, and the
  fish in the water is a copy made for the ride. A miss, a drown or the end of the dive takes nothing; back on the
  dock it is still in your hands and still equipped. Riding another fish leaves the copy to swim on in
  the herd.
- **Which fish:** the equipped one wins over the tank fish picked under RIDE WITH; with nothing equipped, the tank pick
  works as before; with neither, the fling. Nothing equipped on a plain dive-in: the dive-in's hop as before.
- **Faster animations:** every phase about a fifth shorter: the approach 2.0 to 1.6 s, the pick-up 1.2 to 0.96, the
  arrival 0.8 to 0.64, the fling 1.0 to 0.8, the fish's swim-in 1.4 to 1.12, the kick 0.6 to 0.48.
- **Faster runs, faster still when far:** the top speed is `Sub.Speed` (620) plus `Sub.SpeedPer` (0.17) for each
  stud of the run; the run is then kept between `MinRide` 3.2 s and `MaxRide` 7 s. Speeding up takes `UpShare` (a
  fifth) of the run and slowing `DownShare` (a quarter), so a far run's burst is as big as a near one's. The camera
  widens with speed as before (`Fov` 18 up to `Speed`), and up to `FovFar` (10) more on the way to `FovFarAt`
  (4,000 studs a second), so a far land's run looks faster too. The math is `Shared/SubTrip.plan`.

Measured in Studio, 2026-11-20 (the run is the pick-up's end to "NOW ARRIVING"; "in to drop" is from the water to the
drop). Before is the old plan on the same distances, matching the 2026-11-17 logs:

| Land | Run distance | Before: run, top speed | Before: in to drop | After: run, top speed | After: in to drop |
|---|---|---|---|---|---|
| 2 Coral Reef | 1,294 studs | 4.0 s, 520 | 8.0 s | 3.2 s, 507 | 6.4 s |
| 5 Open Blue | 8,822 studs | 10.0 s, 1,017 | 14.0 s | 5.3 s, 2,120 | 8.5 s |
| 10 The Underworld | 21,365 studs | 10.0 s, 2,476 | 14.0 s | 6.5 s, 4,252 | 9.7 s |

## Readings, not confirmed
- **The trigger** (reading, not confirmed). Hugo's words are "jump in the water start swimming while the submarine
  swims in". The reference starts the flight with F at the hub, with no jump. Ours: the destination is picked at the
  hub first (the reference's Equip), then the ordinary walk off the dock starts it. With no destination picked the
  dive is the dive-in as it is today. F at the dock opens the panel; it doesn't launch.
- **The tiers** (reading, not confirmed). One tier per land after the first. **Tier N takes you to land N + 1, and to
  any land before it.** Each tier needs the one before (an upgrade, as Hugo's "upgrade tier increasing the distance").
- **The prices** (guesses to tune). Set by [progression](progression.md)'s twice-as-fast plan: a tier costs about the
  trainer level for the land before it, so you buy the sub to a land once you are at home a land short of it. It
  skips a ride you can almost make yourself. That is cheaper, relative to income, than the reference's, whose
  flights cost far more than a sitting earns.

| Tier | Takes you to | Price (guess) |
|---|---|---|
| 1 | 2 Coral Reef | 2,500 |
| 2 | 3 Kelp Forest | 25,000 |
| 3 | 4 Shipwrecks | 250,000 |
| 4 | 5 Open Blue | 2,000,000 |
| 5 | 6 Twilight | 15,000,000 |
| 6 | 7 Midnight | 150,000,000 |
| 7 | 8 Vents | 1,000,000,000 |
| 8 | 9 Bone Graveyard | 8,000,000,000 |
| 9 | 10 The Underworld | 50,000,000,000 |

- **The selected fish** (reading, not confirmed). The game has no "selected fish" today: what you tame is carried
  home and goes into your tank, where it earns. So here **the selected fish is one fish from your own tank**, chosen
  in the SUB panel ("Ride with"). It isn't taken out of the tank: a copy of it (its kind, size and colour) swims up
  for the drop-off, and it counts as already yours, so riding it tames nothing new. It is held to the usual rule: a
  fish too strong for your Oxygen in the land you are dropped in empties the meter, as any fish would. Nothing is
  saved yet; the pick goes with the tank when saving arrives.
- **Where you are dropped** (reading, not confirmed): 150 studs into the land, in the middle of the lane, at the
  herd's height.
- **A missed fling** leaves you floating (the dive-in's forgiveness), and the herd at the drop point is kept stocked
  from the moment the sub sets off.

## Ideas not agreed
- Flying it yourself, as the reference does (WASD between two lines). Hugo asked for a carry, so ours is a ride.
- A Robux price per tier, as the reference's (49 to 1,999).
- Other players riding along (a bus), and seeing the trip on the land strip.

## Open
- (2026-11-23) The nine subs are toy models, one a tier, in the style Hugo picked (A, the chunky toy):
  [sub models](sub-models.md). Ridden by script on all nine tiers, not by hand. The voxel models of 2026-11-22 were
  a fallback and are out of the game. Before that:
- (2026-11-18) The nine subs are placeholders (`Shared/SubModels`: the same hull in a new colour with one more
  piece a tier, its name floating over the tower). Only the look changes with the tier; speed and the trip are the
  same for all. Buying is free while `Config.Sub.Free` is 1; the prices still show.
- Hugo's word on the readings above, and a play by hand: is it satisfying? (Measured only by script.)
- (2026-11-24, measured with the camera behind) **The dock is behind the camera at the pick-up.** You are thrown
  back toward the dock onto the seat while the camera draws back, so the dock's wall pulls it in from 20 to 14 studs
  behind you over the last half second (one step of 2 studs in a frame), still on your line. Gone in at the very end
  of the lip (5 studs from the lane's wall) it is held 8 to 11 studs behind you for the whole swim and 4.5 at the
  seat ([still](../attachments/subcam-behind-lip-end-pickup.jpg)): close, never to the side. The flag posts were
  never within 4 studs of it (the bunting between them was, on two frames of one trip). For Hugo's eye; nothing changed for it.
- (2026-11-24) The sub's own hull turns 6.9 degrees in one frame as the pick-up begins (it swims in from one side and
  is on the lane a frame later). Seen in the numbers, not looked at.
- (2026-11-24) The run's camera swings up to 21 degrees off the sub's nose on land 10's bends (the nose turns at up to
  350 degrees a second there). Old code, not part of "never at the side" as built; Hugo's call whether it should
  follow the nose more tightly.
- The panel and the ticket are placeholders, not the UI chat's style; the N panel doesn't list `Sub` yet.
- On a phone: not tried. F opens the panel on a keyboard; the SUB button works by touch.
- The prices, once the pace is set (progression's question 4).
- The partner's animations for the pick-up and the drop-off (hooks below). The sub's models are made
  ([sub models](sub-models.md)); they are not uploaded.

## Built (2026-11-17)
Every number is in `Config.Sub`, read live (the N panel doesn't list them yet).

| Piece | Where |
|---|---|
| Tiers, the purchase, the destination and the fish to ride with, per player, for the session (no saves: kept with the tank's coins, so they save with it) | `src/server/Services/SubService.luau`; the coins are the tank's (`AquariumService.spend`) |
| The carried state: no drain, no hop, no send-back; the trip's clock and path | `RideService` ("Carried"), `SubService` |
| The path: the herd's stream from where you went in to the drop point, sampled every `Sub.Sample` studs, `Sub.Lift` over the floor, kept under the surface | `FishService.streamPath` |
| The fish at the drop point are kept in the water from the moment the sub sets off, and six more put just ahead of it | `FishService.keepFor`, `FishService.stockNear` |
| The fling: an ordinary hop, launched at the sub's drop speed (`Config.hopFrom`, both sides) | `RideService.fling`; client `JumpController.fling` |
| Your fish beside the sub, held for you, driven by your machine, then the kick onto it | `FishService.spawnFor`; `RideService.seatOn` |
| Which fish: the equipped one (`RideService.equippedOf`, task e3), else the tank pick, fixed as the trip is made; the plain dive-in onto the equipped fish | `SubService` (`rideWith`, `diveFish`); `RideService.DiveFish` |
| The run's plan: top speed by distance, kept between MinRide and MaxRide | `Shared/SubTrip.plan` |
| The sub (placeholder parts), its motion, the rider's motion, the camera, the bubbles, banners | `src/client/Controllers/SubController.luau` |
| The panel and the ticket | `src/client/UI/SubPanel.luau`; the SUB button in `HubButtons` |
| The rider's poses while carried | `AnimController` ("Carried": a swim, a tuck, a crouch on the seat, the streamlined fling) |

### What the server says (attributes)
- On the player: `SubTier` (0 to 9), `SubDest` (0: none, else the land), `SubFish` (the index of the tank fish to ride
  with, 0: none), `SubPhase` ("Approach", "Pickup", "Ride", "Arrive", "Drop", nil off the sub), `SubTrip` (JSON: the
  trip's start in server time, its phases' lengths, its path, the drop speed, the land and whether a fish comes).
  `Tank` (JSON list of the tank's fish: id, size, colour) is set by `AquariumService` for the panel.
- Studio's tests: `ServerStorage.SubTest:Invoke(op, userId, ...)` ("give", "home", "buy", "pick"), used by
  `docs/playtests/submarine/drive.luau`.
- Remotes: Action `"SubBuy"`, `"SubPick", land, fishIndex`, `"SubLand", fish` (the kick has put us on our fish);
  Ride `"SubFish", fish` (this fish is yours, beside the sub), `"SubDenied", reason`, `"SubBought", tier`.

### Animation hooks (for the partner)
The placeholder motion is one function per phase in `SubController` (`approachPose`, `pickupPose`, `ridePose`,
`dropPose`, `kickPose`), each a CFrame for the rider against the sub's seat by a share 0 to 1 of the phase. The
rider's limbs are `AnimController`'s "Carried" pose, chosen by `SubPhase`. An uploaded animation replaces the pose and
keeps the CFrame path. The sub's model comes from `Shared/SubModels.build` (a template needs parts named `Hull`,
`Seat`, `Light` and `Prop`).
