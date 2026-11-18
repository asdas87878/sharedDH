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
   equip them"): walk up to the SUBMARINE stall and press its prompt (E). The shop lists nine subs, one a tier
   (Bathtub, Reef Runner, Kelp Cruiser, Wreck Diver, Blue Streak, Twilight Ray, Midnight Hunter, Vent Crawler, Abyss
   King), each with its picture, the land it reaches and its price. You buy them in order (free for now), and
   **equip** one; the equipped sub is the one that comes for you, and it reaches its own land or any before it.
   "NO SUB" is the ordinary dive-in. Under the list, GO TO picks the land and RIDE WITH a fish from your tank.
   The shop closes as you walk away. A small ticket at the left edge says where the sub will take you.
2. **You jump in.** With a destination picked, stepping off the dock is no longer the dive-in's auto-hop: you drop
   in with a splash and **swim** at the surface, breaststroking forward.
3. **The sub swims in** from ahead and below (2 s), its light on you, a wake of bubbles, the view tipped to show it
   coming.
4. **The pick-up** (1.2 s): it rises under you, the camera swings out to the side, you are scooped up in a tumble
   (a tuck and a half-turn) and set on the seat behind the tower. A bump, a shake, the view kicks.
5. **The run:** it noses down and goes. The view pulls back behind it and widens with speed, streaks of bubbles,
   speed lines, a banner "SUBMARINE: Kelp Forest". It follows the herd's own line down the lane (the stream: the
   middle of the open water, bent round the big things), well above the fish. 4 to 10 seconds whatever the land
   (the reference's flight is about ten): 520 studs a second at least, faster for a far land (measured: 581 to land
   3, 1,063 to land 5, 2,530 to land 10), picking up over 1.2 s and slowing over 1.6 s.
6. **Arriving:** "NOW ARRIVING: Kelp Forest". It slows to the speed of a quick fish (90).
7. **The drop-off**, one of two:
   - **(a) No fish picked:** the sub pitches its nose up and **flings you forward**. You leave at its speed into an
     ordinary hop (the pop, the glide, the drop, the lock and the hook), so you hook the nearest fish as in any hop.
     It is the dive's first hop, so a miss leaves you floating rather than drowning (as the dive-in's). Six fish of
     the land's herd are put in the water just ahead of the drop point 2.5 s before you arrive (`Sub.Stock`): without
     them the first fling to land 5 found nothing in reach.
   - **(b) A fish picked:** your fish **swims up beside the sub** (from behind, on the right, 1.4 s, matching its
     speed), then the sub **kicks you off sideways** in an arc onto its saddle (0.6 s). You land as on any fish: the
     shake, the splash, the refill. From there you play normally.
8. **The sub peels away** up and to the side, and is gone.

The player can't steer or hop while carried, and no Oxygen goes. The whole trip is decided by the server.

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
- (2026-11-18) The nine subs are placeholders (`Shared/SubModels`: the same hull in a new colour with one more
  piece a tier, its name floating over the tower). Only the look changes with the tier; speed and the trip are the
  same for all. Buying is free while `Config.Sub.Free` is 1; the prices still show.
- Hugo's word on the readings above, and a play by hand: is it satisfying? (Measured only by script.)
- At the pick-up the gate's posts stand close and the camera is pulled in against one for a moment.
- The panel and the ticket are placeholders, not the UI chat's style; the N panel doesn't list `Sub` yet.
- On a phone: not tried. F opens the panel on a keyboard; the SUB button works by touch.
- The prices, once the pace is set (progression's question 4).
- The partner's animations for the pick-up and the drop-off, and the sub's model (hooks below).

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
keeps the CFrame path; the sub's model replaces `buildSub` (it needs parts named `Seat`, `Light` and `Prop`).
