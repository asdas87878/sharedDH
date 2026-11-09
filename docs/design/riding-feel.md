# Riding feel

How riding, the Oxygen meter, the dash and the grapple feel, with starting numbers to tune in play. From the user's brief of
2026-11-09. The run around it is in [the dive](the-dive.md).

**Oxygen** is the riding resource. It replaces "stamina" and "Breath" in the riding notes: the meter is Oxygen, and the stat you
train is your max Oxygen. A creature's tag shows the Oxygen it needs ("Required").

## Decided
- **An Oxygen meter that drains while you ride.** Higher tiers drain it faster.
- **A ridden fish speeds up from its idle speed.** Wild fish cruise slowly; once you're on, it surges to its riding speed.
- **Out of Oxygen, you fall off:** you float up, with a few seconds' grace to reach another fish, then pass out and wake at the
  dock.
- **The dash takes you fish to fish and refills Oxygen.** It's the main move, so it has to feel very smooth and animated: a
  corkscrew, a swimming screw through the water. Switching fish must be satisfying.
- **Jumping off opens a grapple shot:** an aim window with a brief slow-mo, a reticle on the best fish in a cone, a rope, and
  you reel yourself in.

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

- **Drain = the creature's Required ÷ the seconds above,** every second. So the tag reads straight off the meter (Required is
  what it takes to last that long), and drain grows with the zone on its own, as Required does (about 5 times a zone). Example:
  a Shallows Common, Required 10, drains about 0.8 a second; with a starting max of 100 you'd ride it about two minutes. A
  Forest-style Legendary at 750 drains 125 a second.
- **Speed-up on mount:** idle to ridden speed over 1.2 s, easing out, plus a 1.25x surge for the first 0.5 s. Back to idle over
  2 s after you leave.
- **Fall-off:** float up at 6 studs a second, **3 s of grace** (the screen narrows and the meter flashes), then a fade and the
  dock. During grace you can still dash or grapple.
- **Dash:** to the auto-picked fish within **30 studs** in a 60-degree cone ahead (marked while you ride). **0.45 s**, **2 full
  spins** (720 degrees) round the line of travel on a spiral about 2 studs wide, easing in and out. Camera FOV +8 and back,
  a bubble trail, a whoosh rising in pitch. **Refills 25% of max Oxygen** on landing (never above max). Cooldown 0.3 s after
  landing.
- **The landing** (dash or grapple): the last 0.08 s snaps onto the saddle, a squash on the rider, a ring flash, a thump, and the
  fish's surge kicks in.
- **Grapple:** jump off (Space with no fish in dash range, or always on a held Space) and the aim window opens: **1.2 s**, the world
  at **0.3x** speed for you only. Range **90 studs**, a **20-degree cone** round the camera's aim; the reticle sits on the fish
  closest to the cone's centre, nearer fish winning ties; click or Space fires. The rope flies in 0.12 s, you reel in over
  0.6 s, speeding up, into the same landing and the same 25% refill. A miss leaves you floating, in grace if you're out.
- **Co-op:** Oxygen, targets and refills are the server's; the client only animates. The slow-mo is the local player's view and
  camera; the server allows 20% more range for lag.

## Built: the first playable draft (2026-11-09, not playtested yet)
All the numbers above are in `src/shared/Config.luau`, in one place, to tune.

- **Fish** (`FishService`, `Lib/FishModel`): 17 placeholder fish for the first four zones, among them the Sergeant Major,
  Yellow Tang, Clownfish, Pufferfish and Reef Shark. Each has its tier's idle and ridden speed, a Required number (10 for a
  Shallows Common, then ×5 a zone and ×2 a tier step, our guess) and a drain of Required ÷ the tier's seconds. They spawn
  per zone by the [roster](roster.md)'s rarity mix and their one or two zones of range, swim from waypoint to waypoint along
  the lane, and stay under the surface. The zones come from the map's markers: v2's and v3's `ClaudeBlockout.Dive`
  folders, which carry a `Floor` part and `ZoneName` and `Metres` attributes. Without markers, the code uses v2's numbers.
  A model in `ReplicatedStorage.FishModels.<Id>` takes over from the placeholder, which is chunky parts in the fish's
  colours (a body, a tail on a joint, fins, square eyes, stripes or bands).
- **Riding** (`RideService`, `RideController`): the server welds you to the fish's saddle and hands the fish to your
  client, which steers it. A/D or the stick turns, W dives and S climbs; with nothing held, the fish levels off. The fish
  pulls up near the floor and stays under the surface. Speed rises from idle with the surge. The camera chases smoothly,
  its field of view widens with speed, and speed lines come in. Right mouse or a touch drag looks around.
- **Oxygen** is the server's. It drains while you ride, and at a guessed 4 a second while you're off a fish, so floating
  can't last forever. At zero you're knocked off and float up with 3 s of grace: the meter flashes and the screen closes
  in. Then you pass out, the screen fades, and you wake at the dock's Spawn. Surfacing near the dock puts you back on it.
- **Dash** (`DashController`): Space or E dashes to the marked fish ahead. You swim along a bowed path head first, rolling
  2 turns on a spiral that opens and closes. There's a bubble trail, the FOV kicks, you snap onto the saddle, and then the
  ring, the squash and the refill.
- **Grapple** (`GrappleController`): Space with no fish marked, or F/Q, jumps off and opens the aim window. Your own view
  slows to 0.3x (the camera, your float, the fish's tail beats), cools and blurs. The reticle snaps to the best fish in the
  cone, and click, Space or E fires. The rope flies out, you reel in, speeding up, and land as for a dash.
- **HUD** (`HudController`): the Oxygen meter, speed, the depth gauge with the zone's name, the dash marker in the tier's
  colour, and the reticle with its timer. Mobile gets Dash and Hook buttons beside the jump button.
- **Animation** (`AnimController`): all of it is procedural. Fish beat their tails and flap their fins, faster at speed.
  Rider poses run for every player: astride, head first in a dash, an arm out on the rope, treading water. They're for
  R15 characters only.
- **Not in yet:** taming ("IT'S YOURS!"), money, your own creature to start the dive on (you jump off the dive board and
  dash or grapple a wild fish), sounds, and training max Oxygen (it's fixed at 100).

## Ideas not agreed
- Chained dashes within 1 s of landing refill a little more (a combo).
- The reticle prefers fish you haven't caught yet.

## Open
- Whether a wild fish still eats you when Oxygen runs out on it (the [dive](the-dive.md)'s rule), or you just fall off.
- Whether drain scales only by Required, or tiers also get a flat multiplier.
- Revives, as in the reference.
