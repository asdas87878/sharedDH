# Riding feel

How riding, the Oxygen meter, the dash and the grapple feel, with starting numbers to tune in play. From the user's brief of
2026-11-09 and their feedback after playing the v3 draft the same day (round 2, below). The run around it is in [the dive](the-dive.md).

**Oxygen** is the riding resource. It replaces "stamina" and "Breath" in the riding notes: the meter is Oxygen, and the stat you
train is your max Oxygen. A creature's tag shows the Oxygen it needs ("Required").

## Decided
- **An Oxygen meter that drains while you ride.** Higher tiers drain it faster.
- **A ridden fish speeds up from its idle speed.** Wild fish cruise slowly; once you're on, it surges to its riding speed.
- **Out of Oxygen while riding, the fish throws you off and you drown** (round 2; replaces falling off with grace).
- **The dash takes you fish to fish and refills Oxygen.** It's the main move, so it has to feel very smooth and animated: a
  corkscrew, a swimming screw through the water. Switching fish must be satisfying.
- **Jumping off opens a grapple shot:** an aim window with a brief slow-mo, a reticle on the best fish in a cone, a rope, and
  you reel yourself in. Round 2: the window is clear and fixed, and **missing it means a big fish eats you**. No float-up
  grace after a jump-off.
- **Switching fish must be smooth and clean** (hook and dash): it feels weird in the v3 draft.
- **A bubble burst on every successful landing** on a fish.
- **Fish spread over each zone's whole length,** not bunched at its start: more fish in all, less dense.

## Round 2: the user's flow after playing v3 (2026-11-09; numbers to tune in play)
These replace the fall-off, grace and grapple numbers further down where they differ.

- **The hook window.** Jumping off (Space with no fish in dash range, or F/Q) opens a fixed **2.5 s** window (real seconds),
  the world at **0.25x** for you. A ring round the reticle empties as it runs, and the last 0.8 s pulses red with a ticking
  sound. Oxygen doesn't drain in the window. Range 90 studs, cone widened to **30 degrees**, the reticle sticky (it holds its
  fish unless another comes clearly closer to the centre). One shot: fire on a fish and you land; fire at nothing, or let the
  window run out, and it's a miss.
- **The eaten death (a miss), 3.5 s, no input:** 0.6 s the slow-mo lets go and the water darkens, a low rumble; 1.0 s a big fish's
  shadow rises from below, then it opens its jaws under you, the camera pulled back to show it; 0.4 s the chomp, a shake and a
  cut to black; 1.5 s on black ("EATEN!"), then you wake at the dock. One eater to start (a big dark grouper-like shape, our
  own); variations later (by zone, a shark, an eel from the floor).
- **Out of Oxygen while riding, 5.5 s, no input:** a **0.8 s** throw-off (the fish bucks and flings you up and back about 8
  studs, tumbling); then a **4.5 s** drown: 2.5 s struggling (arms and legs flailing, a steady stream of bubbles from the
  mouth, the screen edges closing in), 1.2 s weaker (the bubbles thin out to a few), 0.8 s still and sinking slowly, the last
  bubble; then the fade and the dock. Others in the server see the same.
- **Smoother switching (hook and dash).** No snaps: the rider's path ends on the saddle the fish will have when you arrive
  (predicted, re-aimed every frame), and the last **0.15 s** blends position and turn onto it instead of the 0.08 s snap. The
  camera never cuts: it follows the rider through the whole move and settles behind the new fish over **0.4 s**. Slow-mo eases
  back to 1x over **0.25 s** from the shot, not at once. The rope flies in **0.15 s**, the reel takes **0.7 s** on an
  ease-in curve; the new fish isn't turned or yanked when you land. The old fish swims off at its idle speed, no jerk.
- **The bubble burst:** on every successful landing (dash or hook), **30 bubbles** from the saddle over **0.6 s**, flying out
  about 4 studs and rising, with a soft pop. The server tells every client, so friends see it too.
- **Fish spread.** Fish spread evenly over each zone's whole length: the lane is cut into **120-stud slices**, every slice
  keeps at least one fish, and new fish go into the emptiest slice. About **8 per 1,000 studs** of lane (from 10), per zone
  **20 to 80** (from 12 to 40), **260 in all** (from 140); they fill **0.7** of the lane's width (from 0.4). No start cluster
  (from 6), but the dive board's slice keeps 2. So any point in the lane has a fish within about 60 studs along it, inside the
  hook's 90.

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
- **Fall-off** (replaced in round 2 by the throw-off and the drown): float up at 6 studs a second, **3 s of grace** (the screen narrows and the meter flashes), then a fade and the
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

## Built: round 2 (2026-11-09, not playtested yet)
The round 2 flow above is in the code; the numbers are in `src/shared/Config.luau` (`Grapple`, `Switch`, `Burst`, `Death`,
`Spawn`). Where this differs from the first draft below, this wins.

- **No grace, no passing out.** Jumping off (or the hook while floating) opens the server's hook window: 2.5 s, 0.25x for
  you, no Oxygen drain, a ring of dots round the reticle that empties and pulses red with a tick for the last 0.8 s, a
  30-degree cone, a sticky reticle, one shot. A miss (nothing in the reticle, or time out, plus 0.15 s for lag) is the
  eaten death: 0.6 s dark, 1.0 s a big placeholder shark (our own blocks, built on each client) rising with its jaws open,
  0.4 s the chomp and a shake, 1.5 s "EATEN!" on black, then the dock.
- **Out of Oxygen** riding: the fish bucks, you're thrown about 8 studs up and back in a backflip (0.8 s), then drown: 2.5 s
  flailing with a stream of mouth bubbles, 1.2 s weaker as they thin, 0.8 s limp and sinking with the last bubble, the
  fade, the dock. Floating with no fish at zero (after diving in), you drown without the throw. Everyone sees both deaths.
- **Switching:** the hook flies in 0.15 s and the reel takes 0.7 s on an ease-in; hook and dash both aim at where the
  saddle will be on arrival and blend onto it over the last 0.15 s. The camera follows your own character, so it never
  cuts, and settles behind the new fish over 0.4 s. The fish you leave stays with your client for 1.5 s, coasting to its
  idle speed, so it doesn't hitch in front of you.
- **Bubble burst:** 30 bubbles from the saddle over 0.6 s, about 4 studs out, a soft pop, and a small camera kick for you.
- **Fish spread:** along the map's exact lane path (v3's `Path`; the zone markers without one), in 120-stud slices, every
  slice keeping at least one fish (the dive board's two), new fish into the emptiest slice, each fish wandering 80 studs
  either way from home. Every zone with fish types gets fish: zones 1 to 6 today (the four homes plus two zones of
  reach), about **171 fish** at **12 per 1,000 studs** (the spec's 8 would have given fewer than v3; the user asked for
  more), cap 320. Zones 7 to 10 stay empty until they have fish. Fish further than 700 studs from every player are
  parked out of the world.
- **Sounds** are pitched placeholders from Roblox's built-in character sounds; nothing is uploaded.

## Built: the first playable draft (2026-11-09, not playtested yet; partly replaced by round 2 above)
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
- Zones 7 to 10 (Midnight to the Underworld) have no fish types yet, so no fish: leave them empty for the first version,
  or let the deepest fish reach further down until their own exist.
- Whether a wild, untamed fish still eats you when Oxygen runs out on it (the [dive](the-dive.md)'s rule), or it throws you
  off and you drown as on any fish.
- Whether a friend can save you in co-op (hook you during the drown), or a revive, as in the reference.
- Whether drain scales only by Required, or tiers also get a flat multiplier.
