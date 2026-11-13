# Archetypes and speed per fish

What makes one fish different from another to ride: its own speed, and its passive archetypes. Hugo's request,
2026-11-12. **Built (2026-11-12):** the per-fish table (speed and archetypes), the `Archetype` attribute on every
fish, and all six passives with their feedback, measured by a scripted playtest in Studio
([the numbers](../playtests/2026-11-12-archetypes.md)). **Not done:** nobody has played them by hand yet, the
motion on a bite and a smash is a stand-in until the partner's animations ([Animation hooks](#animation-hooks)),
and the rules and numbers are still Claude's proposals for Hugo to confirm or change (`Config.Archetype`, and on
the sandbox's N panel).

**Fewer abilities (Hugo, 2026-11-13):** the table was handed out again. 51 of the 82 fish now have no ability, and
31 have one (three of those have two). How the six abilities work is unchanged. See
[Fewer abilities](#fewer-abilities-2026-11-13).

Related: [riding feel](riding-feel.md), [progression](progression.md) ("What else makes a fish different": the eight
traits proposed earlier; this note takes four of them up), [the reference](../reference/ride-a-dino.md).

## Decided (Hugo, 2026-11-12)
- **Speed is set by hand, one number a fish.** No rarity formula, no home-land factor (the x1 to x1.90 by land of
  earlier the same day is removed, and so are the rarity multipliers and the species' 0.92 to 1.08).
- **Variants stay, smaller and the same for every fish:** Gold x1.1, Rainbow x1.2 (`Config.Speed.Gold`,
  `Config.Speed.Rainbow`). Hugo wrote "rainbow and gold 1.1x and 1.2x"; read as the rarer Rainbow getting the bigger
  one. To flip them, swap the two numbers.
- **The size roll stays out.**
- **Archetypes are passive:** no click and no ability button, they just happen while you ride. At least fast fish,
  predators that eat other fish, and breakers that smash props without losing speed.
- **Commons and Uncommons normally have none.** Exceptions are allowed, such as a few small, quite fast Rares.
  Higher rarities do cooler things or combine archetypes. **Changed 2026-11-13, see the next section:** a higher
  rarity no longer means an ability.
- Deeper fish may be faster on the whole, but only because each is set so.

## Fewer abilities (2026-11-13)
Hugo's feedback after the archetypes were built: too many fish had abilities.
- **Most fish have none**, and that includes Legendaries, Mythics and Secrets. A rare fish does not need one.
- **An ability only where it is the real animal's signature**, and only on the most fitting fish.
- **Fewer Predators and Breakers,** and fewer fish with two abilities. A couple may keep more than one.
- **A high-tier fish must not be overpowered.**
- No new archetypes, and the six work as built.

The targets (the boss chat's numbers) and what the table holds now:

| | Before | Target | Now |
|---|---|---|---|
| Fish with no ability | 20 | at least 45 | **51** |
| Predators | 39 | at most 10 | **10** |
| Breakers | 23 | at most 8 | **6** |
| Tanks | 20 | | **7** |
| Leapers | 17 | | **4** |
| Fast | 15 | | **5** |
| Frenzy | 6 | | **2** |
| Fish with one ability | 21 | | **28** |
| Fish with two | 25 | at most 6 | **3** |
| Fish with three | 15 | at most 2 | **0** |
| Fish with four | 1 | none | **0** |

How it was handed out (Claude's choices, for Hugo to change):
- **One eater a land, where the land has an obvious one:** Reef Shark, Dunkleosteus, Great White, Goliath Grouper,
  Orca, Liopleurodon, Mosasaurus, Megalodon, Hellfin Shark (lands 1 to 8 and 10), and The Devourer. The Bone
  Graveyard has none.
- **Breakers are the fish with a tool or the mass for it:** the Humphead Wrasse's bump, the Sawfish's saw, three
  whales (Blue, Galleon, Phantom) and the Kraken.
- **The three with two:** the Megalodon and The Devourer (Predator with Frenzy: a Frenzy only works with a
  Predator, so it always counts as two) and the Blue Whale (Tank and Breaker).
- **Not overpowered:** a fish with two abilities is never the fastest of its land. The Blue Whale (84) is the
  slowest Mythic by 20. The Megalodon (112) is slower than the Molten Megalodon (122), which has none.
  **The Devourer's speed is lowered from 150 to 128**, the only speed changed: it was the fastest fish and had
  four abilities. Now the Underworld's fastest is the Hellmaw (130, no ability), its eater is the Hellfin Shark
  (118), and the fastest fish of all is the Ember Serpent (138, Fast only).
- **Fast by its number only:** many quick fish lost Fast and kept their speed (Xiphactinus, Dakosaurus, the
  serpents). Fast stays on five: Swordfish, Giant Squid, Wraith Eel, Storm Serpent, Ember Serpent.

Each fish that keeps an ability has its one line of reasoning in the Why column of [Every creature](#every-creature).
`python tools/creatures/check_archetypes.py` checks the ids and these targets.

**Open from this pass:**
1. **Flying Fish as a Leaper?** It is the obvious leaper, but it is an Uncommon and Uncommons stay without. Left
   without. Say the word and it gets Leaper.
2. **One fish is the fastest of its land and has an ability:** the Mosasaurus (110, Predator; the Void Whale, a
   Secret, ties it). Left, as "the star of the deep". Lower it a little if it reads as too strong.
3. **The sandbox's F list** (`SandboxController`, `TRY_OUT`) still names the Giant Sea Bass as its Tank and the
   Dunkleosteus as its combo. Both ride fine, but the first now has no ability and the second only Predator.
   Steller's Sea Cow (Tank) and the Blue Whale (Tank, Breaker) would put that back. Not this pass's file.

## The single source
`Config.FishStats` in `src/shared/Config.luau`: one row a creature, `{ Speed = 70, Archetype = "Predator" }`.
- `Speed`: studs a second, ridden, no variant. A wild fish swims at 0.85 of it (`Herd.SpeedShare`), as before.
- `Archetype`: `""` for none; more than one comma-separated, no spaces (`"Predator,Breaker"`). The ids are the keys
  of `Config.Archetype`.
- `Config.speedOf(fish, variant)` reads it: the fish's number, times 1.1 for Gold or 1.2 for Rainbow. Nothing else.
- The server (`FishService`) writes each fish's archetypes on its model as the **`Archetype` attribute** (a string,
  `""` for none). This is the hook for the passives and for the partner's animations: read it with
  `Config.archetypeOf(model)`; `Config.archetypesOf(fish)` gives the list and `Config.hasArchetype(fish, id)` asks
  for one.
- A creature with no row warns in the output and swims at `Speed.Base` (45) with no archetype. A misspelt id warns.
- The table below is written from the same rows. Change a number in Config and change it here.

## The archetypes
Six ids. One rule for all: **none takes away steering or the hop, and none makes a fish worse to ride than a plain
one** apart from its own speed number.

How strong an archetype is comes from the animal, not from a rarity formula: a fast fish's speed is its own number,
a predator eats what is smaller than itself (so a bigger one eats more), a breaker's hole is as wide as its body.

### Fast
The sprinter. Sailfish, tuna, the torpedo shapes.
- Its speed is its own high number in the table: the fastest of its land and rarity.
- **On top:** the burst when you land on it is bigger and lasts longer. `Ride.Surge` x1.15 (1.25 becomes about
  1.44) for `Ride.SurgeTime` x2 (0.5 s becomes 1 s). Hopping onto one feels like a launch.
- **As built:** every landing first dips the fish to 0.8 of its speed (the landing's slow-down, kept). A plain
  fish eases back to its speed and no further; a Fast one goes on past it to the burst as it recovers (the peak
  is about 1.3 s after the landing) and settles. Measured on a Swordfish: 67 (x0.80), then 121 (x1.44), then 84.
- **Reads as:** you land and it takes off. Speed lines, the view kicks wider, a louder whoosh, "LAUNCH!".

### Predator
It eats other fish. Sharks, the orca, the sea reptiles, anglers.
- **When:** while you ride it (not in a hop), swimming into a wild fish that is **no longer than 0.7 of its own
  length** (`Prey`), within 3 studs of its nose (`Reach`).
- **Never:** a fish with a rider, a fish another player's hop is reserved on, a fish in a tank.
- **What happens:** the fish is gone in a burst of bubbles. It is not lost to the sea: the herd's top-up puts a new
  fish into the emptiest stretch of the lane within a couple of seconds, away from players, as it does today.
- **What eating gives:** a burst of speed, x1.25 for 1.5 s (fading out over the last third), and **10% of your max
  Oxygen back**. So a predator is the fish you stay on longer: steer through the small fish and the meter holds.
- **Cooldown:** 2.5 s between two eats. This is what stops a predator clearing the lane of fish to hop to.
- **As built:** the server looks ten times a second for a wild fish within reach of the ridden fish's nose
  (`RideService.checkEat`, `FishService.prey`); a fish too strong for you doesn't eat. You can't steer up or
  down, so what you can eat is what swims at your height: the herd's band is 8 studs deep and the reach covers
  most of it.
- **Reads as:** a chomp, bubbles and a ring where the fish was, the nose lunges, the view kicks wider, a lurch
  forward with speed lines, "CHOMP! +10% air" by the rider, the ring jumps up.

### Frenzy (always with Predator)
The twist for the great sharks and the last monsters: eats chain.
- Each eat within 6 s of the last adds a stack, up to 3. A stack adds 0.08 to the burst (three: x1.49) and 0.5 s to
  its length. The cooldown is 1.2 s in place of 2.5.
- **Reads as:** every bite makes the next one bigger ("FRENZY x2", "x3", "x4", the chomp pitched higher each
  time, the view kicking wider). Miss for 6 seconds and it is back to one.

### Breaker
It breaks props and comes out faster. The swordfish's cousin with the saw, the whales, the armoured ones.
- **Since 2026-11-13 only some fish break props at all** (below, "Who breaks props"): Breakers, Tanks and the
  giants. Every other fish swims straight through them.
- **Free smashing:** a prop costs it no speed and no Oxygen (a Tank or a giant drops to 0.8 of its speed and pays
  3% of the meter: `Props.Slow`, `Props.Cost`).
- **A wider hole:** 5 studs more reach than the others (`Reach`), so more of the prop comes down.
- **What breaking gives:** a short push, x1.12 for 1 s, and **4% of max Oxygen back** per prop, at most once every
  1.5 s. So for a breaker the props are the best line through a land, not the thing to steer round.
- **Walls:** a crash into a wall costs it half the usual speed and Oxygen (`Crash`). It still stops at the wall.
- **As built:** only the map's loose props break (`Lane.Props`). The lane's walls and terraces still stop a
  Breaker, as they stop every fish.
- **Reads as:** you aim at the coral on purpose and come out the far side faster: a rumble, bubbles, the body
  shudders, the camera shakes, "SMASH! +4% air".

### Tank
The calm giant. Turtles, whales, the sea cow, the fish that wait.
- **Oxygen drains at 0.65 of the usual** for its rarity and land (`Drain`), so you sit on it a good half longer.
- **Angry later:** the red part of the meter, where a fish slows and pulses, starts at 0.18 of the meter in place
  of 0.3 (`AngryAt` x0.6).
- Its speed number is usually low for its rarity. That is the trade: slow, and the fish you rest on.
- **As built:** what it takes to hold a fish at all (the number on its tag, and "too strong") is by rarity
  alone, Tank or not; the Tank only drains slower once you hold it. The tag's "holds N s" and the ring's seconds
  are the Tank's own.
- **Reads as:** the ring barely moves. It has no moment of its own: the tag and the line under the ring say TANK.

### Leaper
The hop off it goes higher and further. Dolphins, rays, the serpents.
- `Jump.Apex` x1.3, the glide 20% faster, and 0.3 s more glide (the window grows by the same, so the drop is as
  long as it was).
- **Reads as:** you press hop and get thrown: more bubbles, the view kicks wider, "BIG HOP!". It reaches fish a
  plain hop does not.

### Who breaks props (Hugo, 2026-11-13)
Only three kinds of fish break props. Every other fish, and every rider in the hop and the glide, goes straight
through them: no stop, no slow-down, no Oxygen. The rule is one function, `Config.breaks`, the same on the server
and on every player's machine:
- **a Tank** breaks them, for a small crash (speed to 0.8, 3% of the meter: `Props.Slow`, `Props.Cost`);
- **a Breaker** breaks them for nothing and is paid (above);
- **a really big fish** breaks them even with no archetype, for the same small crash as a Tank. "Really big" is the
  size of the creature's own model: its box, width x height x length in studs, as its `mesh.json` gives it
  (`src/shared/Creatures/<Id>.json`, the species' one base size). **At `Props.GiantVolume` = 12,000 cubic studs or
  more it is a giant.** The box, not the length alone: by length an eel or a serpent would count, and they are thin.
  12,000 sits in the one wide gap in the list: the Galleon Whale is 13,900, the next one down (the Void Whale) 10,800.
  (Since the merge of 2026-11-13 a kind's size in the game is that box times its `Config.BaseScale`, and each fish
  rolls one of six sizes: [sizes](sizes.md). Neither counts here: `Config.volumeOf` still measures the exported box,
  so the list below is unchanged. A wild fish must also be `Herd.BreakLength` (32) long itself: [the herd](herd.md).)
- **One fish can be set by hand:** `Breaks = true` or `Breaks = false` in its row of `Config.FishStats` wins over
  all of the above. No row uses it yet.

**16 of the 82 break props:** 7 Tanks, 6 Breakers (the Blue Whale is both) and 4 giants with neither: the three
megalodons and The Devourer. Printed by `python tools/creatures/check_breaks.py`:

| Creature | Rarity | Land | Box (w x h x l, studs) | Cubic studs | Why it breaks |
|---|---|---|---|---|---|
| Kraken | Mythic | 7 | 24 x 21 x 48 | 24,101 | Breaker, giant |
| Molten Megalodon | Mythic | 8 | 27 x 19 x 42 | 21,011 | giant |
| Megalodon | Legendary | 8 | 27 x 19 x 42 | 21,011 | giant |
| Halfbone Megalodon | Mythic | 9 | 27 x 19 x 42 | 20,824 | giant |
| The Devourer | Secret | 10 | 19 x 24 x 45 | 20,037 | giant |
| Blue Whale | Mythic | 5 | 20 x 21 x 46 | 19,697 | Tank, Breaker, giant |
| Aurora Jelly | Secret | 6 | 22 x 34 x 24 | 17,735 | Tank, giant |
| Abyssal Watcher | Mythic | 10 | 21 x 19 x 39 | 15,699 | Tank, giant |
| Galleon Whale | Secret | 4 | 17 x 18 x 45 | 13,948 | Breaker, giant |
| Void Whale | Secret | 7 | 19 x 13 x 45 | 10,816 | Tank |
| Phantom Whale | Secret | 9 | 19 x 11 x 45 | 9,239 | Breaker |
| Archelon | Legendary | 1 | 33 x 8 x 30 | 8,264 | Tank |
| Grave Turtle | Legendary | 9 | 33 x 8 x 30 | 8,043 | Tank |
| Steller's Sea Cow | Epic | 3 | 10 x 9 x 29 | 2,682 | Tank |
| Humphead Wrasse | Epic | 2 | 8 x 10 x 22 | 1,727 | Breaker |
| Sawfish | Rare | 4 | 8 x 5 x 25 | 1,056 | Breaker |

The biggest that go through: Kronosaurus (10,600; wide by its flippers, only 9 tall), Hellmaw (10,000), Coral
Dragon (8,700), Infernal Angler (8,500). To let them break too, lower `Props.GiantVolume` to 10,000 (two more) or
8,400 (four more), or give one fish `Breaks = true`.

A wild fish that would break props does so when it is inside one (`Props.WildBreaks`, 1); it gets no reward.

### How you know before you hop on
A fish's tag has a small line under its name naming its archetypes, each in its own colour ("PREDATOR · BREAKER");
the same line sits under the air ring while you ride it. Wording and colours: `src/shared/Archetypes.luau`.
`ArchetypeFeel.Tags` 0 hides both.

## Who gets what
Since 2026-11-13 rarity doesn't decide it: a fish has an ability only where its animal is known for it.

| Rarity | Fish | None | One | Two |
|---|---|---|---|---|
| Common | 7 | 7 | 0 | 0 |
| Uncommon | 10 | 10 | 0 | 0 |
| Rare | 10 | 7 | 3 (Swordfish Fast, Dolphin Leaper, Sawfish Breaker) | 0 |
| Epic | 14 | 6 | 8 | 0 |
| Legendary | 23 | 13 | 9 | 1 (Megalodon) |
| Mythic | 8 | 5 | 2 (Kraken, Abyssal Watcher) | 1 (Blue Whale) |
| Secret | 10 | 3 | 6 | 1 (The Devourer) |
| All | 82 | 51 | 28 | 3 |

How many fish carry each: Predator 10, Tank 7, Breaker 6, Fast 5, Leaper 4, Frenzy 2. (Before: Predator 39,
Breaker 23, Tank 20, Leaper 17, Fast 15, Frenzy 6, and 20 fish with none.)

## Speeds
From **40** (Pufferfish, Boxfish) to **138** (Ember Serpent); a Rainbow Ember Serpent does about 166. The Devourer
was 150 until 2026-11-13 and is 128 now (see [Fewer abilities](#fewer-abilities-2026-11-13)); no other speed changed.

| Rarity | Slowest | Fastest |
|---|---|---|
| Common | 40 | 48 |
| Uncommon | 44 | 64 |
| Rare | 42 | 84 |
| Epic | 56 | 90 |
| Legendary | 62 | 118 |
| Mythic | 84 | 130 |
| Secret | 96 | 138 |

| Land | Slowest | Fastest | Average |
|---|---|---|---|
| 1 Shallows | 40 | 100 | 52 |
| 2 Coral Reef | 46 | 108 | 62 |
| 3 Kelp Forest | 52 | 112 | 70 |
| 4 Shipwrecks | 60 | 104 | 74 |
| 5 Open Blue | 76 | 135 | 91 |
| 6 Twilight | 70 | 108 | 90 |
| 7 Midnight | 74 | 110 | 98 |
| 8 Vents | 72 | 138 | 103 |
| 9 Bone Graveyard | 92 | 126 | 111 |
| 10 The Underworld | 100 | 130 | 116 |

The Shallows' Commons stay where the hop was tuned (40 to 48; they were 41 to 47). The numbers are Claude's, set by
the real animal and by where it lives, and none has been played.

## Every creature
All 82 in the creature registry (`src/shared/Creatures/`), by home land, then rarity, then speed. The Bobbit Worm
has a row but is kept out of the herd, and no land's mix has a Secret yet, as before.

| Creature | Rarity | Home land | Speed | Archetypes | Why |
|---|---|---|---|---|---|
| Blue Chromis | Common | 1 Shallows | 48 | none | A small darting schooling fish: the quick Common, by its number only |
| Sergeant Major | Common | 1 Shallows | 46 | none | A bold, busy damselfish: the plain first fish |
| Yellow Tang | Common | 1 Shallows | 45 | none | A steady reef cruiser |
| Butterflyfish | Common | 1 Shallows | 44 | none | An ordinary reef fish |
| Clownfish | Common | 1 Shallows | 43 | none | Stays by its anemone, a wobbly swimmer |
| Boxfish | Common | 1 Shallows | 40 | none | A rigid box paddling with tiny fins |
| Pufferfish | Common | 1 Shallows | 40 | none | Round and slow: the slowest thing in the sea |
| Flying Fish | Uncommon | 1 Shallows | 58 | none | Built to burst out of the water: fast for an Uncommon, by its number only |
| Stingray | Uncommon | 1 Shallows | 48 | none | Glides low over the sand |
| Cuttlefish | Uncommon | 1 Shallows | 47 | none | Hovers on its skirt |
| Sea Turtle | Uncommon | 1 Shallows | 44 | none | An unhurried glider: slow by its number, no trait |
| Seahorse | Rare | 1 Shallows | 42 | none | The slowest swimmer there is: the Rare you catch for the tank, not the ride |
| Reef Shark | Epic | 1 Shallows | 70 | Predator | The Shallows' hunter: the first fish that eats, so the trait is met early |
| Archelon | Legendary | 1 Shallows | 62 | Tank | A giant turtle: calm to sit on, and the meter barely moves |
| Pearl Serpent | Secret | 1 Shallows | 100 | none | The first Secret: a long quick serpent, quick by its number only |
| Parrotfish | Uncommon | 2 Coral Reef | 50 | none | An ordinary grazer |
| Angelfish | Uncommon | 2 Coral Reef | 48 | none | Tall and showy, not quick |
| Lionfish | Uncommon | 2 Coral Reef | 46 | none | Drifts with its fins spread |
| Moray Eel | Rare | 2 Coral Reef | 58 | none | A lunging ambusher with two sets of jaws: a plain Rare |
| Octopus | Rare | 2 Coral Reef | 54 | none | Jets in pulses: a plain Rare |
| Humphead Wrasse | Epic | 2 Coral Reef | 60 | Breaker | It really does crush coral with the bump on its head |
| Dunkleosteus | Legendary | 2 Coral Reef | 76 | Predator | A bite that sheared through bone: the Reef's one eater |
| Coral Dragon | Secret | 2 Coral Reef | 108 | none | A reef come alive: quick by its number only |
| Sea Lion | Uncommon | 3 Kelp Forest | 58 | none | Agile and playful: quick for an Uncommon, by its number only |
| Garibaldi | Uncommon | 3 Kelp Forest | 52 | none | An ordinary kelp fish |
| Leopard Shark | Rare | 3 Kelp Forest | 62 | none | A small harmless shark: a plain Rare |
| Giant Sea Bass | Rare | 3 Kelp Forest | 54 | none | A heavy, slow, gentle giant: slow by its number, no trait |
| Great White | Epic | 3 Kelp Forest | 82 | Predator | The shark |
| Steller's Sea Cow | Epic | 3 Kelp Forest | 56 | Tank | A gentle floating giant: slow, and the meter barely moves |
| Dakosaurus | Legendary | 3 Kelp Forest | 88 | none | A sea crocodile built for the chase: quick by its number only |
| Kelp Wyrm | Secret | 3 Kelp Forest | 112 | none | Winds through the kelp: quick by its number only |
| Barracuda | Uncommon | 4 Shipwrecks | 64 | none | A torpedo: the fastest Uncommon, by its number only |
| Hammerhead Shark | Rare | 4 Shipwrecks | 68 | none | A strong schooling shark: a plain Rare |
| Sawfish | Rare | 4 Shipwrecks | 64 | Breaker | A saw for a nose |
| Electric Ray | Epic | 4 Shipwrecks | 62 | none | A sluggish disc that waits: slow by its number, no trait |
| Goliath Grouper | Epic | 4 Shipwrecks | 60 | Predator | A heavy lump that gulps fish whole: the slow eater |
| Xiphactinus | Legendary | 4 Shipwrecks | 96 | none | The fast "bulldog fish": the Shipwrecks' quick one, by its number only |
| Galleon Whale | Secret | 4 Shipwrecks | 104 | Breaker | A whale carrying a ship: it rams through whatever is in the way |
| Swordfish | Rare | 5 Open Blue | 84 | Fast | One of the fastest fish alive (the small, fast Rare) |
| Dolphin | Rare | 5 Open Blue | 76 | Leaper | The leaper: small, quick and loved (a trait on a Rare) |
| Orca | Epic | 5 Open Blue | 90 | Predator | The top hunter: big enough to eat most of what swims by |
| Manta Ray | Epic | 5 Open Blue | 78 | Leaper | A flier: it breaches, and its hop is a long glide |
| Helicoprion | Legendary | 5 Open Blue | 92 | none | The buzz-saw shark: a plain Legendary |
| Elasmosaurus | Legendary | 5 Open Blue | 86 | none | A long-necked, unhurried paddler: a plain Legendary |
| Blue Whale | Mythic | 5 Open Blue | 84 | Tank, Breaker | The biggest and the calmest: nothing stops it and the meter crawls; the slowest Mythic by far, which is the trade |
| Storm Serpent | Secret | 5 Open Blue | 135 | Fast | Lightning: the launch, and nothing else |
| Viperfish | Rare | 6 Twilight | 70 | none | A deep ambusher, all teeth: a plain Rare |
| Giant Squid | Epic | 6 Twilight | 86 | Fast | Jet powered |
| Goblin Shark | Epic | 6 Twilight | 78 | none | Its jaws shoot out: a plain Epic |
| Liopleurodon | Legendary | 6 Twilight | 98 | Predator | The Twilight's big four-flippered hunter |
| Shonisaurus | Legendary | 6 Twilight | 92 | none | A whale-sized ichthyosaur with no teeth: a plain Legendary |
| Lantern Leviathan | Mythic | 6 Twilight | 108 | none | A long lit serpent: quick by its number only |
| Aurora Jelly | Secret | 6 Twilight | 96 | Tank | A drifting jelly: slow for a Secret, and the meter barely moves |
| Frilled Shark | Epic | 7 Midnight | 82 | none | An eel of a shark: a plain Epic |
| Anglerfish | Epic | 7 Midnight | 74 | none | A lure and a mouth: a plain Epic |
| Mosasaurus | Legendary | 7 Midnight | 110 | Predator | The star of the deep: the Midnight's eater |
| Livyatan | Legendary | 7 Midnight | 104 | none | The killer sperm whale: a plain Legendary |
| Basilosaurus | Legendary | 7 Midnight | 102 | none | A serpent whale: a plain Legendary |
| Kraken | Mythic | 7 Midnight | 104 | Breaker | A mass of arms that drags ships down |
| Void Whale | Secret | 7 Midnight | 110 | Tank | A whale, dark and calm: the meter barely moves |
| Sea Scorpion | Epic | 8 Vents | 84 | none | A paddling hunter with claws: a plain Epic |
| Giant Isopod | Epic | 8 Vents | 72 | none | An armoured crawler: a plain Epic |
| Megalodon | Legendary | 8 Vents | 112 | Predator, Frenzy | The biggest shark that ever was: every bite makes the next one bigger |
| Kronosaurus | Legendary | 8 Vents | 108 | none | Huge jaws, strong flippers: a plain Legendary |
| Anomalocaris | Legendary | 8 Vents | 96 | none | The first big hunter, flying on its side flaps: a plain Legendary |
| Bobbit Worm | Legendary | 8 Vents | 90 | none | Bursts out of the sand (not in the herd yet) |
| Molten Megalodon | Mythic | 8 Vents | 122 | none | A Megalodon on fire: faster than the Megalodon, but it doesn't eat |
| Ember Serpent | Secret | 8 Vents | 138 | Fast | A serpent of fire: the fastest fish there is, and the launch |
| Wraith Eel | Legendary | 9 Bone Graveyard | 114 | Fast | A quick ghost |
| Grave Ray | Legendary | 9 Bone Graveyard | 104 | Leaper | A ghostly glider |
| Skull Angler | Legendary | 9 Bone Graveyard | 98 | none | An angler, still: a plain Legendary |
| Grave Turtle | Legendary | 9 Bone Graveyard | 92 | Tank | A turtle, still |
| Bone Leviathan | Mythic | 9 Bone Graveyard | 126 | none | A racing skeleton: the Graveyard's fastest, by its number only |
| Halfbone Megalodon | Mythic | 9 Bone Graveyard | 124 | none | Half a Megalodon: quick by its number, and it doesn't eat |
| Phantom Whale | Secret | 9 Bone Graveyard | 120 | Breaker | A ghost whale: it goes straight through things |
| Hellfin Shark | Legendary | 10 The Underworld | 118 | Predator | A shark from the Underworld: the last land's eater |
| Brimstone Eel | Legendary | 10 The Underworld | 116 | none | An eel of fire: quick by its number only |
| Cinder Ray | Legendary | 10 The Underworld | 108 | Leaper | A burning glider |
| Infernal Angler | Legendary | 10 The Underworld | 100 | none | An angler, still: a plain Legendary |
| Hellmaw | Mythic | 10 The Underworld | 130 | none | The last land's monster: the fastest thing in the Underworld, by its number only |
| Abyssal Watcher | Mythic | 10 The Underworld | 112 | Tank | It watches; it doesn't hurry |
| The Devourer | Secret | 10 The Underworld | 128 | Predator, Frenzy | The end of the list: the one that chains bites down there, so it is not also the fastest (was 150) |

## What Ride a Dino does
Looked up 2026-11-12 (web search; the guide pages themselves could not be opened from here, so this is from search
summaries and from our own [breakdown](../reference/ride-a-dino.md) of Hugo's recordings).

**Confirmed:**
- Its dinos differ by rarity, home zone, the stamina a dino requires (the number on its nameplate), and what it
  earns in the pen. Jumping to another dino refills stamina. (Guides: bloxron, 9to5gaming, bloxrant; our recordings.)
- Mutations exist (guides list Silver, Golden, Rainbow, Magma, Spectral) and sizes (Tiny to Giant). One guide says
  the game's own page states that a mutation boosts speed. Sizes change the stamina needed and the value (our
  recordings: Tiny x0.8, Big x1.2, Giant x1.5 of the required stamina).
- Its props are built of loose pieces that collapse when a big dino hits them (our map study).

**Not confirmed, and not found anywhere:**
- Any passive ability by species or rarity: nothing on a dino that eats others, that breaks props better than
  another, or that is a sprinter by kind. No guide found lists per-dino speeds or per-mutation speed multipliers.
- Whether breaking a prop gives or costs anything there.

So the archetypes here are our own addition, not a copy. What is copied is what the reference is known to do:
rarity and land carry the progression, variants are a small flat bonus on speed, props collapse.

## Open, for Hugo
1. **Gold and Rainbow:** Gold x1.1 and Rainbow x1.2 as read, or the other way round?
2. **The six archetypes and their numbers (all six are built now; who has them was cut down 2026-11-13):** right set? Tank and Leaper are Claude's additions to the three asked
   for (fast, predator, breaker); Frenzy is the twist for the top sharks. Any of them can be dropped by clearing it
   from the rows.
3. **What eating gives:** speed and Oxygen (proposed), or only one of them?
4. **The speeds:** to play. The first thing to check is the hop between a slow and a fast fish of one land, now
   that speeds inside a land differ more (the Open Blue: 76 to 135).
5. **Props for plain fish:** answered 2026-11-13: a plain fish goes straight through props; only Tanks, Breakers
   and giants break them ("Who breaks props").

## How it is built
- **The server decides everything** (`RideService`): the eat (`checkEat`), the prop reward and the cheaper wall
  (`checkCrash`), the Tank's drain and red part (`Config.drainOf`, `Config.low`), the Leaper's longer window
  (`jump`), and what speed it allows (`checkSpeed`: a Fast fish's burst, and an eat's or a smash's while it
  lasts). `FishService.prey` picks the fish, `FishService.eat` removes it, and the herd's top-up puts a new one
  in.
- **The rider's client plays it:** the burst of speed (`RideController.boost`, on the server's "Boost"), the
  Fast launch (`launchShare`), the Leaper's hop (`JumpController`, `Config.hopOf`), and the feedback
  (`Controllers/ArchetypeController`, numbers in `Config.ArchetypeFeel`).
- **Every number is in Config:** `Config.Archetype.<Id>` (also reachable as `Config.<Id>`) and
  `Config.ArchetypeFeel`, all on the sandbox's N panel. In the sandbox **F** rides the next fish of a try-out
  list (one of each archetype, a combo, a plain Common, a Gold and a Rainbow).
- **Unchanged:** steering, the hop, the landing's x0.8 slow-down, angry mode (a Tank only starts it later).

## Animation hooks
For the partner's animations, the same pattern as `AngryStyle` and `Angry.Motion`. The stand-in motion is one
marked block in `RideController.drive`; set `ArchetypeFeel.Motion` to 0 when an animation plays instead.

| Moment | What to read | Stand-in today |
|---|---|---|
| Which archetypes a fish has | the fish's `Archetype` attribute (`"Predator,Breaker"`, `""` for none) | none |
| A bite | the fish's `Bite` attribute counts up by one (listen for the change); for everyone also `Net.Fx` `"Eat", player, fish, where, stacks` | the nose lunges down and back (`Lunge`, `LungeTime`) |
| A Frenzy's chain | the fish's `Frenzy` attribute: 1 to 3 while the chain lasts, gone when it breaks or the rider leaves | none (the word and the sound's pitch) |
| A smash (a Breaker paid for a prop) | the fish's `Smash` attribute counts up by one; for everyone also `Net.Fx` `"Smash", player, fish, where, boxes` | the body shudders side to side (`Shudder`, `ShudderTime`) |
| A Fast fish's launch | `Net.Fx` `"Land", player, fish, count` on a fish whose `Archetype` has `Fast`; on the rider's own machine `State.Launched` fires as it takes off | none (speed only) |
| A Leaper's big hop | the rider's `State` attribute goes to `Jumping` off a fish whose `Archetype` has `Leaper`; on the rider's own machine `State.Leapt` fires | none (the hop itself) |
| A Tank | nothing happens; `Archetype` has `Tank` | none |

## Open, after building
- Nobody has played it by hand. The numbers are as designed; whether a bite every 2.5 s (1.2 s in a Frenzy)
  with 10% air each is too generous is the first thing to feel: a Megalodon let loose among small fish ate six in
  nine seconds in the test and its meter never dropped.
- Two players at once is untested (the rule that a ridden or a reserved fish is never eaten was checked by
  asking the server's own function, not with a second player).
- A wild fish that is a Breaker gets no reward and no wider hole: only ridden fish do.
