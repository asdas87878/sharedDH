# Riding feel

How riding, the Oxygen meter and the jump from fish to fish feel, with starting numbers to tune in play. The run around it
is in [the dive](the-dive.md). The jump follows the reference's, read from the user's recordings
([the reference's jump](../reference/ride-a-dino.md)).

**Oxygen** is the riding resource (fine for now: the user, 2026-11-10). The meter is Oxygen, and the stat you train is your
max Oxygen. A creature's tag shows the Oxygen it needs ("Required").

## Decided
- **Going fish to fish works exactly like the reference's jump** (the user, 2026-11-10), changing only what our game
  forces. It replaces void's corkscrew dash, the hook window with its slow motion, reticle and rope, and the eaten death.
- **Any fish you are on, you steer, tamed or not** (the user, 2026-11-10). Taming doesn't change the riding.
- **Wild fish all swim the same way, straight down the lane** (the user, 2026-11-10).
- **The jump has a long air time: you float up, swimming, then you drop** (the user, 2026-11-10). A drop that finds no
  fish is the drowning. No hopping for ever.
- **An Oxygen meter that drains while you ride.** Higher tiers drain it faster.
- **Out of Oxygen while riding, the fish throws you off and you drown,** then wake at the dock.
- **A bubble burst on every landing** on a fish.

## The jump, as built (2026-11-10, second pass after the user played the first)
One button, as in the reference. The numbers are in `src/shared/Config.luau` under `Jump` and `Herd`.

1. **Space** throws you off the fish at once. A white ring pops where you left. From floating (after diving in off the
   board) Space does the same, so that is how a dive starts for now.
2. **The launch, 0.75 s:** up 12 studs and forward at 1.4 times the speed you rode at.
3. **The float, 1.6 s:** at the top, still rising a little, in a swimming pose, at the herd's pace (38 studs a second).
4. **The drop, 1.3 s:** you sink, faster and faster, head first.
5. **You steer all of it:** A and D turn, W and S speed up and slow down. The camera lifts and pulls back to look down.
6. **A dashed yellow ring lies flat in the water under you** (a radius of 13 studs), at the level of the fish below.
   **The fish inside the ring glows yellow with an outline:** that is the fish you will land on. The flight is drawn
   over it, so the ring stays on it.
7. **The reel-in, 0.35 s:** you are pulled onto the glowing fish, slowly at first and then fast. It happens when the
   drop begins, or at once if you press Space again. Then the bubble burst, the ring, the squash, and the glow fades
   off the fish over 0.3 s. Oxygen refills by a quarter.
8. **Space again with no fish glowing** starts the drop early.
9. **A drop that ends with no fish in the ring has sunk:** a short drown (about 2.8 s), then the dock. This is the same
   from a fish or from floating, so there is no hopping for ever. The reference offers a revive here; we have none yet.

The server decides: the client says which fish it came down on, and the server checks the fish is free and the player is
over it, give or take lag.

### The herd
- **All wild fish swim straight down the lane,** each at its own place across it.
- **At 0.85 of the speed they are ridden at** (a Common: 38 wild, 45 ridden). Measured from the reference: riding about
  55 m a second, the herd about 46. Before, wild fish idled at 14, a third of riding speed, so a jump flew past them.
- **In one layer, 16 to 30 studs above the floor** (it was 10 to 60). The reference's dinos are all on the ground; with
  fish spread over 50 studs of depth, a jump had nothing at its own depth.
- **A ridden fish with W and S let go follows the lane down at the herd's height.** W and S still dive and climb.
- The herd drains downstream, so new fish keep being put in behind it. They can pop in near you: not fixed.

### What differs from the reference, and why
- **The ring is in the water, not on the ground.** Their dinos stand on the ground, so their ring lies on it. Ours lies
  flat at the depth of the fish under you. A first answer, not a chosen one.
- **The flight makes for the nearest fish** when no turn is held and nothing is in the ring: it takes on the fish's speed
  and closes the gap. The reference pulls you onto a dino at the end (measured), but how it picks one isn't known.
  `Jump.Assist = false` turns ours off.
- **The float is longer** (1.6 s against about 1.1): the user's call.
- **Not built yet:** the yellow fan behind the fish on landing, the row of yellow dots behind you, the lasso in the
  rider's hand, the revive, and the green and pink rings (time left on this fish, taming).

### Tested in Studio (2026-11-10, by Claude, pressing Space through the connector)
Off the board onto a fish with no help (2.7 s); riding; a jump onto the next fish; a drop with nothing under it into
the short drown and the dock. The herd all heading down the lane at 38 to 44. No script errors. The user played the
first pass and found the faults this pass answers; nobody has played this pass.

### To measure in the reference now, before more is built on guesses
Each of these changes numbers that everything else is tuned round. Needs: 60 frames a second if possible, and the
distance counter in view.
1. **Hands off:** jump and press nothing, several times. Does it bring you to a dino by itself? This settles whether the
   assist should exist and how strong.
2. **Steering only:** jump and hold A or D the whole way. How far does the flight turn? Can you leave the dino it had?
3. **The second press:** jump, then press Space again at once; and jump and never press again. This settles what the
   down arrow does and when the pull-in starts.
4. **The longest gap:** jump at a dino as far ahead as you can make. And one jump with no dino anywhere near.
5. **From the side:** a few jumps with the camera turned side-on, the whole arc in frame, for the height and the shape.
6. **The herd:** ride straight for 20 s without jumping, looking ahead. For how fast you overtake the herd, how many
   dinos are on screen, how far apart, and whether any go another way.
7. **One dino to the end:** stay on one until its green ring runs out, for what happens and how long it is.
8. **Steering a dino:** hold A, then D, on a tame one and on a wild one.

## Starting numbers (ideas not agreed, to tune in play)
Speeds in studs a second. The reference rides at about 55 ([blockout](../blockout.md)).

| Tier | Idle speed | Ridden speed | Seconds on it with exactly its Required Oxygen |
|---|---|---|---|
| Common | 14 | 45 | 12 |
| Uncommon | 16 | 52 | 10 |
| Rare | 18 | 60 | 8 |
| Epic | 20 | 68 | 7 |
| Legendary | 22 | 78 | 6 |
| Mythic | 24 | 90 | 5 |
| Secret | 26 | 100 | 5 |

- **Drain = the creature's Required ÷ the seconds above,** every second. Example: a Shallows Common, Required 10, drains
  about 0.8 a second; with a starting max of 100 you'd ride it about two minutes.
- **Speed-up on mount:** idle to ridden speed over 1.2 s, easing out, plus a 1.25x surge for the first 0.5 s. Back to idle
  over 2 s after you leave.
- **Out of Oxygen while riding, 5.5 s, no input:** a 0.8 s throw-off (the fish bucks and flings you up and back about 8
  studs), then a 4.5 s drown: struggling with a stream of bubbles, weaker, still and sinking, the fade, the dock.
- **The bubble burst:** 30 bubbles from the saddle over 0.6 s, a soft pop, and a small camera kick for you.
- **Fish spread:** along the lane in 120-stud slices, every slice keeping at least one fish. **24 per 1,000 studs**
  (doubled from 12 on 2026-11-10 by Claude, because a jump needs a fish within its flight; to tune), 110 a zone at most,
  480 in all. Fish further than 700 studs from every player are parked. The table's idle speeds are no longer used: a
  wild fish swims at 0.85 of its ridden speed.
- **Co-op:** Oxygen, landings and refills are the server's; the client steers and animates.

## The rest of the code (void's first draft, 2026-11-09)
- **Fish** (`FishService`, `Lib/FishModel`): 17 placeholder fish for the first four zones, spawned per zone by the
  [roster](roster.md)'s rarity mix, swimming waypoint to waypoint along the lane. A model in
  `ReplicatedStorage.FishModels.<Id>` takes over from the placeholder.
- **Riding** (`RideService`, `RideController`): the server welds you to the saddle and hands the fish to your client,
  which steers it. A/D turn, W dives and S climbs. The camera chases smoothly and widens with speed.
- **Jump** (`JumpController`): the flight, the ring and the glow.
- **HUD** (`HudController`): the Oxygen meter, speed, the depth gauge with the zone's name.
- **Animation** (`AnimController`): all procedural. Fish beat their tails; rider poses for riding, the flight, floating
  and drowning. R15 characters only.
- **Not in yet:** taming ("IT'S YOURS!"), money, your own creature to start the dive on, sounds beyond placeholders, and
  training max Oxygen (it's fixed at 100).

## Seen in the test, not fixed
- **New fish can pop in beside you,** because the herd swims on and its place is filled behind it.
- **Nothing keeps a ridden fish in the lane** if you steer out of it.

## Open
- Where the ring and the landing effects sit for a floating fish (the user: several ways, not chosen).
- The glow and the outline: the look and the timing, to tune against the reference.
- A revive after a miss, as in the reference.
- Zones 7 to 10 have no fish types yet, so no fish.
- Whether drain scales only by Required, or tiers also get a flat multiplier.
