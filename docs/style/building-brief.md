# Brief: the hub's buildings

> **Studies, 2026-11-16.** The rules marked "(corrected)" below came from the buildings study. The short of it, with the tests in order: [findings](../Findings.md), rank 3.

Up: [Home](../../Home.md). For whoever models the tanks, the stalls and the trainers: now the map chat. Written
2026-11-16 by the game-code chat on the user's word. It joins three things: how games of this kind lay out a hub,
what the creature chat learned about modelling ([workout 4](04-voxel-style.md), [5](05-rarity-look.md),
[6](06-textures.md), [the creature brief](creature-brief.md)), and what is wrong with the hub's models today
([the hub's models](../design/hub-models.md)).

**The user's words (2026-11-16):** "the aquarium, the shops, they need to be more detailed, refined, and fit our art
style more and the type of Roblox art style that we're going for ... we need better models for these aquariums and
shops. We're going to need different placements later, but for now, focusing on the models."

So: **the models only.** Where things stand, the hub's size and its colours stay as they are.

## Corrected against the builds (2026-11-16, evening)
A research agent then watched how four trending games are built (the reference, Throw an Egg, Pull an Egg and an
egg-stealing game): [how stud-style games build](../reference/look-assets.md), section 4. I checked its three biggest
claims against the frames myself and they hold. Where this brief was wrong it is changed below and marked
**(corrected)**. What it found, in short:

- **Studs go by what a piece is made of, not by which way it faces.** Ground, walls, leaves, awnings and counters
  are studded on every face that shows. Signs, eyes, glass and (in the reference) timber are plain.
- **Shops are one stall, recoloured.** Seen in three games. Colour, name, floor mark and what floats over it tell
  them apart. Only the machines (fuse, the board, the trainer) have a shape of their own.
- **Stalls are small:** about two players tall. The creatures and the words are what is big.
- **A plot is an open pen in all four games:** posts and two rails you can see over, the creatures in the open air
  with their labels. Nothing a player owns is shown behind anything. **Our tank is the opposite, and it is the
  hub's costliest thing to draw** (see-through walls over see-through water). Fish need water, so this is a question
  for the user, not a rule: how open can a tank be?
- **Nobody trusts the player to find things.** A trail of arrows on the floor, a marker with the distance, huge
  words on the floor, and something in the air over your own plot that says it is yours.
- **Two or three loud colours fill the whole hub.** Our stations are pastel on a loud green floor.
- **On a phone the cost is draw calls, not part count.** Plain parts of one material batch together. See-through
  parts, particles, beams and floating labels do not.

The user has since told the map chat to go simpler, with fewer things and nothing big on top
([Decisions](../Decisions.md), 2026-11-16). That agrees with all of this.

## What a hub is in this kind of game
Ride a Dino and the games like it share one layout. It is worth knowing why each piece exists, because the model has
to do that job.

- **The hub is a toy shelf, not a town.** Nothing in it is scenery. Every object is something you use, and each one
  is its own icon: you know what it does from across the hub, before you can read its name.
- **Your plot is the heart of the game.** It is the one thing you own. Your catch stands on it and earns, with
  its rarity and its money a second floating over it. Other players walk past and see it. Wanting what is on the
  next plot is what sends a player back out. So a plot's first job is to **show the creatures off**. In the
  reference the pen is a low open fence on a sand floor and nothing else: the dinosaurs are the display.
- **Each plot carries the same small kit:** the display, the owner's sign, the pad you collect on, and the upgrade
  machine. Plots stand side by side in a row, so the kit repeats eight times in one view. A weak plot model is seen
  eight times; a busy one is noise eight times.
- **The shared stations stand loose on the open floor:** sell, auras, fuse, the index, the travel stall, the
  earners board. Each is one object with a floating name and a coloured ring on the floor. The name is the label
  and the model is the picture. Station, ring and name share one colour, and no two stations share it.
- **Everything is bright and chunky. (corrected)** A stall is about two players tall; the creatures and the words
  are what is big. From far off it is the name in the air, the mark on the floor and the arrow that are read; the
  model is read from about a stall's length away.
- **Everything is made of the same stuff:** the world, the creatures and the buildings are all studded bricks. That
  sameness is the style. A building that isn't made that way looks like it came from another game.

## What the reference's buildings do
Read off the private frames (`research/ride-a-dino/map/hubA.jpg`, `hubB.jpg`, `H1.jpg`, `A.jpg`, `full_12.png`).
**For rules only. Never its models or its look; its layout may be copied (the user, 2026-11-22).**

- **Thick pieces.** A stall's posts and beams are about a third as thick as a player is wide, or more. Nothing is a
  thin stick. The frame reads as toy timber.
- **Few pieces.** A stall is perhaps 30 to 50 bricks: a frame, an awning, a counter. You can count them.
- **Studs on what faces up.** The awning's stripes, the counter and the pen's floor carry studs. The sides are
  plain. The floor of a pen has a different colour and stud pattern from the hub's floor, so the plot reads as a
  place.
- **An awning is rows of bricks in two colours,** stepping down in a curve, with a deep front edge.
- **Slightly crooked.** Posts lean a few degrees, the awning sags. It is cartoon carpentry, not a clean box.
- **One thing glows at each station, at most:** the fuse machine's core. The stalls don't glow at all.
- **The upgrade toy is a small creature built exactly as the creatures are,** on a spring, on a bright pad.
- **The board is a dark slab leaning back in a thick frame,** with a lamp at each lower corner.
- **A fence is posts and two rails,** the posts taller than the rails, the whole thing low enough to see over.

## What is wrong with ours today
From the three pictures in [the hub's models](../design/hub-models.md) and the kit (`tools/map/hub_kit.py`):

- **They are not made of our stuff.** The floor, the walls and the creatures carry studs and tones by a rule. The
  hub's models are flat single-colour boxes with no studs (the kit lays only the ripple picture). Beside a studded
  floor they read as blockout.
- **They are not built by the creatures' rules.** The seahorse is 16 plain boxes standing next to 82 creatures
  built with slabs, three tones, framed eyes and buried roots. `blocky_fish` on the sell sign and the gate is a
  third kind of fish again.
- **Thin and small.** Tank frames and stall posts are sticks. The stalls are low boxes on a slab on a floor
  230 studs wide.
- **One outline for everything.** The stall, the clam and the machine are each a low lump on a plinth. Filled in
  black from the spawn they would be hard to tell apart; only colour separates them.
- **No order of detail.** Pieces are mostly one size, so the eye has nowhere to land.
- **The tank dresses its inside and neglects itself.** About 27 pieces go inside, where the fish are meant to be
  the show, and the tank's own body is four thin bars and a band.

## The rules
These are the creature chat's lessons, said again for buildings. They were learned by getting each one wrong first.

1. **Outline first, in grey. (corrected)** This holds for the machines: fuse, the board, the trainer, the index.
   The shops (sell, auras, travel) may be one stall in three colours, as three games do it. A shape of its own for
   every shop is our idea, not the genre's: keep it only if it reads better in a side-by-side.
2. **Big blocks first.** A building is 30 to 80 blocks and each block is a part of the thing: a post, a counter, a
   roof slab. When in doubt, simpler. Half the surface stays plain.
3. **Three sizes of detail, in order.** One big form. Three to five middle pieces that say what it is. A handful of
   small touches near where the player stands. Small touches go where the camera gets close, not all over.
4. **Thick sections. (corrected)** On a stall, posts about 1 stud (half a player's body), as the reference has
   them; 2 studs made a two-player stall read as a bunker. On something tank-sized, 2 or more. Only plates (a
   stripe, a band, a sign face) are thinner.
5. **One step size to a building,** and every size a multiple of it. The creatures use one cube size each; it is
   why their steps read as meant.
6. **A slope is a whole block turned (corrected: for timber).** Posts and beams lean as whole pieces. Round and
   natural things (trees, hills, arches, awnings) are stepped stacks in every game seen: a wide flat and one or two
   broad steps. Wood leans a few degrees in the reference only; the neighbours build square.
7. **Three tones of each colour, by one rule:** lighter on plates that face up, the base on the sides, darker on
   whatever is below a step, recessed or underneath. Three to five named colours a building. One of them is the
   station's own, used on its ring and name too. No pure black on big areas: a dark tint. **(Note: tones by facing
   are our creatures' rule. The games do it with patches, checkers and a lighter plate set in from a darker block's
   edge. Either is fine; the hub as a whole wants two or three loud colours.)**
8. **Studs by material. (corrected)** A piece made of a studded stuff (a base, a counter, an awning, a shell, a
   wall) carries studs on every face that shows; posts, rails and signs do not. The same stud picture the map's
   floor and walls use, with sizes that fit it so no stud is cut. Glass, water, eyes, signs and anything that glows
   are never studded. (Studs on tops only is the older Roblox habit and what Reddit's builders prefer: worth one
   side-by-side.)
9. **Raised colour is raised a little** (a third of the step), and never where the shape changes size. A recess
   that doesn't glow is shallow. Stripes are thick plates with thin plates set back between them.
10. **Bury every root. Chains nest. Nothing floats.** A piece has one whole face inside another or flat against
    it. **No two faces in one plane, or under 0.05 studs apart:** they flicker in Roblox. The creature kit refuses
    to build with any of these faults; the hub kit should check the same three things before it writes.
11. **Glow needs a reason.** One glowing thing a station at most, and none on a stall. A big Neon ball blooms
    into a white blob (the pearl already taught this).
12. **Fish on buildings are our fish.** The trainer's toy, the catch on the sell stall, the fish in the fuse pods
    and the landmark's leaping fish should be the game's own creature models (they are in
    `ReplicatedStorage.FishModels`; a Seahorse, a Clownfish and a Sergeant Major are among the 82), scaled, or be
    built by the creature brief's rules. Not a third kind of box fish. If the trainer becomes a cloned creature the
    game code may need a small change: ask the game-code chat, it has `src/`.
13. **Judge it where it is seen,** in Studio, in the game's light, with a player beside it: from the spawn, from
    its ring, and from the next plot. Always a before and an after from the same spot.
14. **Lean does not mean careless.** Never show something you can see is wrong.

## The aquarium
Eight of them in one view, and the thing a player owns. It is the hero: do it first.

- **Its job is to show fish.** Rarity and size should read from the middle of the hub. Everything else serves that.
- **The body of the tank is where the modelling goes:** a thick base in the plot's colour, heavy corner posts with
  caps, a deep rim. It should look like a prized object, not a fence round water.
- **Inside, less.** A low reef along the back and the ends, built from the lane's own prop pieces so it matches the
  sea outside. The middle and the front glass stay clear (the fish lap there: see "The tanks' insides" in
  [the hub's models](../design/hub-models.md)).
- **The owner's sign is a real sign:** a board with a frame, big enough to read a name across the hub.
- **The way in for the catch** (the hopper and pipe) is the tank's one machine. Make it the middle-sized piece that
  says "this is where fish go in".
- **Light it,** so the fish show at any hour: a lit rim or a hood, not a glow on the tank itself.
- The parts the game reads keep their names: `TankWater`, `Pad`, `CollectPad`, `SignBoard`, `TrainerSpot`,
  `TrainerRide` (a Model, its PrimaryPart the part of that name), `Chute`, `ChuteHopper`, `ChuteMouth`.

## The shops
One line each on what the model has to say. The idea behind each is the map chat's to keep or change.

| Station | Must say | Today's weak point |
|---|---|---|
| Sell | "bring fish here, get coins" | a low wooden box; the awning is the only big shape |
| Auras | "this changes how your fish looks" | wide and flat; the pearl is the only thing above knee height |
| Fuse | "three go in, one comes out" | reads as a machine, not as fusing (its own note says so) |
| Index | "every fish you have found" | the lighthouse is the best outline in the hub; the book is small |
| Submarine | "travel" | long and low; hard to tell from the basin it sits in |
| Earners | "who is winning" | a slate on the wall; no frame with weight |
| Trainer | "ride this to get stronger" | 16 boxes; not one of our creatures |

## How to work
- **One building at a time, the hero first:** one tank with its trainer and sign, then the sell stall. Show those
  two to the user before the rest. The rules get corrected on two models, not on fourteen.
- **Each round:** the idea in a line, the outline in grey, then colour, then tones and studs, then the checks.
  At most three look-and-fix rounds, then show it.
- **Each building is one Model on its own foot.** Built round its own origin, with a PrimaryPart and its pivot at
  the middle of its foot, and nothing in it knowing where it stands. The user will want other placements later,
  and that must be one line.
- **Parts are not the worry.** The hub's models are 1,106 parts in a map of 59,000. A building may use what it
  needs. What matters: decoration can't be bumped, touched or hit by a ray, small pieces cast no shadow, and
  pictures go on top faces only.
- **Not without the user's word:** uploads (permanent), anything that costs credits, the hub's size, layout or
  colours.
- **Only one chat drives Studio at a time.** Write "has it" in [Sessions](../Sessions.md) first.

## Open, for the user
- Parts, as now, or meshes? Parts need no upload and share the world's studs. Meshes are lighter to draw and can
  carry finer shapes, but every one is a permanent upload. Claude's pick: parts, and look again only if the hub
  runs slow on a phone.
- Should the trainer's toy be a real creature from the game (the Seahorse), as the reference's is one of its own
  dinosaurs?
