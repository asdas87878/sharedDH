# Workout 5: the rarity look

**State (2026-11-10): the ideas are proposed, not decided. Two tests are built: the Hellmaw redone as a Mythic, and the
ladder.** Back to [Style workouts](Style%20workouts.md).

## The question
How does a creature look as rare as it is? The user's read of the five voxel creatures
([workout 4](04-voxel-style.md)): the Mythic almost comes off as a Legendary, and the Legendary as an Epic. They need
something that makes them look cooler: colour, kind of creature, glow, how colour is spread, ribbons of colour, silhouette.

## What the references show
The user's two screenshots from Ride a Dino are in `research/ride-a-dino/` (private). Read for rules, not copied. The user
doesn't think its Legendary is a good display of a Legendary.

- **Its Legendary (a long-necked dinosaur):** only two colours. What lifts it: its size; a long silhouette nothing else has;
  dozens of thin stripes in the belly colour laid across the spine, of uneven lengths, which follow every box of the neck
  and tail and so show off the curve; an eye framed in a third colour.
- **Its Uncommon (a dome-headed dinosaur):** three colours, spikes round the head, chevrons on the neck, patches on the
  back. So decoration there is not tied to rarity. Rarity is mostly the species and the size.
- **Online (video thumbnails only, small and unverified):** the top of its range stops being animals. A white machine
  dinosaur with a red eye; a skeleton dragon with red wings, labelled Eternal; a glowing gold figure with a halo; a
  glowing blue "Spectral" dinosaur. Its tiers run Common to Mythic with Secret above, and auras and mutations are separate
  layers put on any creature.

## Why ours read a tier low
- **The Hellmaw (Mythic)** is a fish with fire painted on: the same body plan as a Common, with horns. One glow colour.
  Nothing on it is impossible. It is also smaller than the Legendary (20.5 studs against 24.5).
- **Dunkleosteus (Legendary)** is special only at the head. Behind the shield it is plain slabs in two quiet colours, like
  the Epic shark, with small fins and no pattern.
- **No ladder.** Nothing gets stronger step by step from Common to Mythic. Each creature was dressed alone.

## The idea: a ladder with a budget on each rung
Each rarity gets a fixed allowance on a few axes. A creature of that rarity spends it. Going up a tier always adds something
on every axis, so two tiers can't look alike.

| | Common | Uncommon | Rare | Epic | Legendary | Mythic |
|---|---|---|---|---|---|---|
| **Kind** | familiar fish | odd-shaped fish | strange real animals | predators | prehistoric giants | not real: myth |
| **Length (studs)** | 9 to 12 | 11 to 14 | 13 to 17 | 17 to 21 | 24 to 28 | 30 and up |
| **Silhouette** | body and fins | one mark (a crest, a long fin) | two marks | a weapon at one end | the outline is broken all along (plates, a sail, spikes) | parts no animal has (below) |
| **Colours** | 2 | 3 | 3 | 3, darker and sharper | 4, one of them a strong signature colour | a dark body and two glowing colours |
| **Pattern** | big bands or none | one simple pattern | pattern and coloured tips | scattered thin stripes | two layers (armour, then stripes or runes) | pattern that glows and moves |
| **Glow** | none | none | none | the eye only | spots and thin lines, steady | whole ribbons, pulsing, casting light |
| **Movement** | swims | and a fin flicks | and the jaw works | fins on their own joints | trailing parts that follow late | floating parts, a trail, an aura |

## Ideas, axis by axis
**Silhouette** (the strongest, and the one seen from the riding camera):
- Break the outline more with every tier: a row of back plates, a sail, spikes, a clubbed or forked tail.
- **Mythic means impossible anatomy.** Parts that float (a broken crown of rock over the horns, shards that orbit), two
  jaws or a split jaw, fins as wide as wings, long tendrils or chains that trail behind.
- Make it uneven on purpose at the top: one huge horn, one torn fin.

**Size.** Make the ladder true first. The Mythic has to be the biggest thing in its zone.

**Colour and how it is spread:**
- **Value does the work.** Commons sit in friendly middle tones. Rarer creatures get a darker body with brighter accents.
- **A signature colour** from Legendary up, used only in ribbons and tips, never as a body colour: amber on bone, teal on
  slate, violet on black.
- **A shift along the body** at Mythic: white-hot at the head cooling to deep red at the tail, or the reverse.
- **Two glowing colours** at Mythic, one hot and one cool, so it doesn't read as one orange light.

**Ribbons and stripes:**
- **Scattered stripes** as in the reference: thin bands in the belly colour across the back, of uneven lengths and
  spacing. We have the piece for it (`band`, stopped short). They show the body's curve as it swims.
- **A ribbon along the body:** one line of the signature colour from the eye to the tail. Plain at Epic, glowing at
  Legendary, pulsing at Mythic.
- **Chevrons, spots, plate edges** as other patterns, one family per creature, so a zone's creatures don't all look striped.
- On the Hellmaw: make the cracks its stripes. Uneven ribs of lava across the back in place of the even grid.

**Glow** (the sea makes this fair: deeper zones are darker, so living light reads as both depth and rarity):
- None below Epic. An Epic's eyes. A Legendary's lure, spots and lines. A Mythic's whole ribbons, with light cast on the
  rider and the water.
- A pulse that runs from head to tail on a Mythic.

**Movement and effects:**
- Trailing parts that lag behind the body: tendrils, ribbons of fin, chains.
- Floating parts that turn slowly.
- Particles: embers, bubbles, motes, by zone.

**Material:** Roblox materials are cheap. Bone and armour in Metal, some fins in Glass, glow in Neon.

**The saddle:** a tamed creature's saddle could be grander by rarity (the reference's Legendary carries a little house).

## What this would mean for ours
- **Hellmaw:** longer than everything else; a second glow colour; lava ribs in place of the grid; a floating crown of
  broken rock; trailing flames that lag; a second jaw or a split one; the head-to-tail colour shift.
- **Dunkleosteus:** the armour carried down the spine as plates; scattered pale stripes on the slate; a signature colour
  (amber or teal) in the eye and a thin line along the side; a heavier tail.
- **Reef Shark:** a few scattered darker stripes over the back; a brighter eye. It is close already.
- **Commons:** nothing. Their plainness is what makes the rest read.

## How to test it
Build the ladder on one body: the same fish dressed at each of the six tiers, on one sheet. If the six read in order at a
glance and at game distance, the budget works. Then redo the Hellmaw and Dunkleosteus by it.

## Test 1: the Hellmaw as a Mythic (built 2026-11-10)
The user asked for the Hellmaw to be redone first. It spends the Mythic's whole allowance:

![Before, now, front and top](../attachments/voxel-hellmaw-mythic.jpg)

- **Size:** 31.3 studs, from 20.5. It is now the biggest creature made.
- **Impossible parts:** a broken crown of rock shards that floats over the head and turns; a lower jaw split down the
  middle, each half on its own joint, opening down and apart; flame fins as wide as wings.
- **Pattern that glows:** the even grid of cracks is gone. Uneven ribs of lava are cut across the back, some short, some
  running down the flank.
- **A shift along the body:** the lava is white-hot in the skull, yellow behind the head, orange, then deep red at the tail.
- **Two glowing colours:** the hot one, and a cold soul-fire blue in the eyes, the throat, the crown, the snapped horn and
  the last tips of the whiskers and the tail.
- **Trailing parts:** a whisker each side of the snout, and the two tips of the tail on joints of their own, which whip late.
- Kept: the horns (bigger), the snapped one, the fangs in a glowing gum, the tongues of flame down the back.

It is 2,390 triangles in 13 parts, and passes the gate. The kit gained `FLOATING`: a model names the parts whose pieces
float on purpose, and the gate doesn't ask those to touch anything. [Its swim](../attachments/voxel-hellmaw-swim.gif) shows
the jaw, the crown and the tail tips moving.

**Fable's read.** It now looks a tier above Dunkleosteus at a glance, mostly from the crown, the second colour and the
size. What is still fish-like is the body itself: a straight chain of slabs. A longer, more serpentine body would push it
further.

## Open, for the user
- Which axes matter most to them?
- Should Mythics leave real animals behind entirely?
- Does glow belong only to the upper tiers, or also to deep-zone Commons?
