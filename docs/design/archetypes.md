# Archetypes and speed per fish

What makes one fish different from another to ride: its own speed, and its passive archetypes. Hugo's request,
2026-11-12. **Built so far:** the per-fish table (speed and archetypes) and the `Archetype` attribute on every fish.
**Not built yet:** the passive behaviours themselves (the next task). The rules and numbers below are Claude's
proposals for them, for Hugo to confirm or change; the numbers are in `Config.Archetype`, ready to tune.

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
  Higher rarities do cooler things or combine archetypes.
- Deeper fish may be faster on the whole, but only because each is set so.

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
- **Reads as:** you land and it takes off.

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
- **Reads as:** a chomp, bubbles, a lurch forward, the ring jumps up.

### Frenzy (always with Predator)
The twist for the great sharks and the last monsters: eats chain.
- Each eat within 6 s of the last adds a stack, up to 3. A stack adds 0.08 to the burst (three: x1.49) and 0.5 s to
  its length. The cooldown is 1.2 s in place of 2.5.
- **Reads as:** every bite makes the next one bigger. Miss for 6 seconds and it is back to one.

### Breaker
It goes through props. The swordfish's cousin with the saw, the whales, the armoured ones.
- **Free smashing:** a prop costs it no speed and no Oxygen (a plain fish drops to 0.8 of its speed and pays 3% of
  the meter: `Props.Slow`, `Props.Cost`).
- **A wider hole:** 5 studs more reach than a plain fish (`Reach`), so more of the prop comes down.
- **What breaking gives:** a short push, x1.12 for 1 s, and **4% of max Oxygen back** per prop, at most once every
  1.5 s. So for a breaker the props are the best line through a land, not the thing to steer round.
- **Walls:** a crash into a wall costs it half the usual speed and Oxygen (`Crash`). It still stops at the wall.
- **Reads as:** you aim at the coral on purpose and come out the far side faster.

### Tank
The calm giant. Turtles, whales, the sea cow, the fish that wait.
- **Oxygen drains at 0.65 of the usual** for its rarity and land (`Drain`), so you sit on it a good half longer.
- **Angry later:** the red part of the meter, where a fish slows and pulses, starts at 0.18 of the meter in place
  of 0.3 (`AngryAt` x0.6).
- Its speed number is usually low for its rarity. That is the trade: slow, and the fish you rest on.
- **Reads as:** the ring barely moves.

### Leaper
The hop off it goes higher and further. Dolphins, rays, the serpents.
- `Jump.Apex` x1.3, the glide 20% faster, and 0.3 s more glide (the window grows by the same, so the drop is as
  long as it was).
- **Reads as:** you press hop and get thrown. It reaches fish a plain hop does not.

## Who gets what
| Rarity | Archetypes | In the table |
|---|---|---|
| Common | none | 7 of 7 have none |
| Uncommon | none. A quick one (Flying Fish, Barracuda, Sea Lion) is quick by its number only | 10 of 10 have none |
| Rare | none, or one | 7 of 10 have one (the Swordfish is Fast, the Dolphin a Leaper: the small, fast Rares) |
| Epic | one | 14 of 14 |
| Legendary | two | 23 of 23 |
| Mythic | three | 8 of 8 |
| Secret | two to four | 10 of 10 |

How many fish carry each: Predator 39, Breaker 23, Tank 20, Leaper 17, Fast 15, Frenzy 6.

## Speeds
From **40** (Pufferfish, Boxfish) to **150** (The Devourer); a Rainbow Devourer does 180. Until now the range was
41 to 205 (307 as a Rainbow).

| Rarity | Slowest | Fastest |
|---|---|---|
| Common | 40 | 48 |
| Uncommon | 44 | 64 |
| Rare | 42 | 84 |
| Epic | 56 | 90 |
| Legendary | 62 | 118 |
| Mythic | 84 | 130 |
| Secret | 96 | 150 |

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
| 10 The Underworld | 100 | 150 | 119 |

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
| Archelon | Legendary | 1 Shallows | 62 | Tank, Breaker | A giant turtle: calm to sit on, and its shell goes through anything |
| Pearl Serpent | Secret | 1 Shallows | 100 | Fast, Leaper | The first Secret: a long quick serpent that throws you far |
| Parrotfish | Uncommon | 2 Coral Reef | 50 | none | An ordinary grazer |
| Angelfish | Uncommon | 2 Coral Reef | 48 | none | Tall and showy, not quick |
| Lionfish | Uncommon | 2 Coral Reef | 46 | none | Drifts with its fins spread |
| Moray Eel | Rare | 2 Coral Reef | 58 | Predator | A lunging ambusher with two sets of jaws |
| Octopus | Rare | 2 Coral Reef | 54 | none | Jets in pulses: a plain Rare |
| Humphead Wrasse | Epic | 2 Coral Reef | 60 | Breaker | It really does crush coral with the bump on its head |
| Dunkleosteus | Legendary | 2 Coral Reef | 76 | Predator, Breaker | Armour plate and a bite that sheared through bone |
| Coral Dragon | Secret | 2 Coral Reef | 108 | Breaker, Leaper, Tank | A reef come alive: heavy, calm, and it launches you |
| Sea Lion | Uncommon | 3 Kelp Forest | 58 | none | Agile and playful: quick for an Uncommon, by its number only |
| Garibaldi | Uncommon | 3 Kelp Forest | 52 | none | An ordinary kelp fish |
| Leopard Shark | Rare | 3 Kelp Forest | 62 | none | A small harmless shark: a plain Rare |
| Giant Sea Bass | Rare | 3 Kelp Forest | 54 | Tank | A heavy, slow, gentle giant: the Rare you rest on |
| Great White | Epic | 3 Kelp Forest | 82 | Predator | The shark |
| Steller's Sea Cow | Epic | 3 Kelp Forest | 56 | Tank | A gentle floating giant: slow, and the meter barely moves |
| Dakosaurus | Legendary | 3 Kelp Forest | 88 | Predator, Fast | A sea crocodile built for the chase |
| Kelp Wyrm | Secret | 3 Kelp Forest | 112 | Fast, Predator, Leaper | Winds through the kelp and strikes |
| Barracuda | Uncommon | 4 Shipwrecks | 64 | none | A torpedo: the fastest Uncommon, by its number only |
| Hammerhead Shark | Rare | 4 Shipwrecks | 68 | Predator | A strong schooling shark |
| Sawfish | Rare | 4 Shipwrecks | 64 | Breaker | A saw for a nose |
| Electric Ray | Epic | 4 Shipwrecks | 62 | Tank | A sluggish disc that waits: slow and easy on the meter |
| Goliath Grouper | Epic | 4 Shipwrecks | 60 | Predator | A heavy lump that gulps fish whole |
| Xiphactinus | Legendary | 4 Shipwrecks | 96 | Fast, Predator | The fast "bulldog fish", found with whole fish inside it |
| Galleon Whale | Secret | 4 Shipwrecks | 104 | Breaker, Tank, Leaper | A whale carrying a ship: it rams, it lasts, and its back is a launch deck |
| Swordfish | Rare | 5 Open Blue | 84 | Fast | One of the fastest fish alive (the small, fast Rare) |
| Dolphin | Rare | 5 Open Blue | 76 | Leaper | The leaper: small, quick and loved (a trait on a Rare) |
| Orca | Epic | 5 Open Blue | 90 | Predator | The top hunter: big enough to eat most of what swims by |
| Manta Ray | Epic | 5 Open Blue | 78 | Leaper | A flier: it breaches, and its hop is a long glide |
| Helicoprion | Legendary | 5 Open Blue | 92 | Predator, Breaker | The buzz-saw shark |
| Elasmosaurus | Legendary | 5 Open Blue | 86 | Predator, Tank | A long-necked fish catcher, and an unhurried paddler |
| Blue Whale | Mythic | 5 Open Blue | 84 | Tank, Breaker, Leaper | The biggest and the calmest: nothing stops it, the meter crawls, and it breaches |
| Storm Serpent | Secret | 5 Open Blue | 135 | Fast, Leaper, Predator | Lightning |
| Viperfish | Rare | 6 Twilight | 70 | Predator | A deep ambusher, all teeth |
| Giant Squid | Epic | 6 Twilight | 86 | Fast | Jet powered |
| Goblin Shark | Epic | 6 Twilight | 78 | Predator | Its jaws shoot out |
| Liopleurodon | Legendary | 6 Twilight | 98 | Predator, Breaker | A big four-flippered hunter |
| Shonisaurus | Legendary | 6 Twilight | 92 | Tank, Breaker | A whale-sized ichthyosaur with no teeth: mass, not bite |
| Lantern Leviathan | Mythic | 6 Twilight | 108 | Fast, Tank, Leaper | A long lit serpent: quick, easy on the meter, a long hop |
| Aurora Jelly | Secret | 6 Twilight | 96 | Tank, Leaper | A drifting jelly: slow for a Secret, but it floats you far and long |
| Frilled Shark | Epic | 7 Midnight | 82 | Predator | An eel of a shark that swallows prey whole |
| Anglerfish | Epic | 7 Midnight | 74 | Predator | A lure and a mouth |
| Mosasaurus | Legendary | 7 Midnight | 110 | Predator, Fast | The star of the deep |
| Livyatan | Legendary | 7 Midnight | 104 | Predator, Breaker | The killer sperm whale: a ram for a head |
| Basilosaurus | Legendary | 7 Midnight | 102 | Predator, Breaker | A serpent whale that crushed its prey |
| Kraken | Mythic | 7 Midnight | 104 | Predator, Breaker, Tank | A mass of arms: it drags fish in and ships down, and it is in no hurry |
| Void Whale | Secret | 7 Midnight | 110 | Tank, Breaker, Predator | A whale, dark and slow, that swallows what it passes |
| Sea Scorpion | Epic | 8 Vents | 84 | Predator | A paddling hunter with claws |
| Giant Isopod | Epic | 8 Vents | 72 | Breaker | An armoured crawler |
| Megalodon | Legendary | 8 Vents | 112 | Predator, Frenzy | The biggest shark that ever was: every bite makes the next one bigger |
| Kronosaurus | Legendary | 8 Vents | 108 | Predator, Breaker | Huge jaws, strong flippers |
| Anomalocaris | Legendary | 8 Vents | 96 | Predator, Leaper | The first big hunter, flying on its side flaps |
| Bobbit Worm | Legendary | 8 Vents | 90 | Predator, Breaker | Bursts out of the sand (not in the herd yet) |
| Molten Megalodon | Mythic | 8 Vents | 122 | Predator, Frenzy, Breaker | A Megalodon on fire |
| Ember Serpent | Secret | 8 Vents | 138 | Fast, Predator, Leaper | A serpent of fire |
| Wraith Eel | Legendary | 9 Bone Graveyard | 114 | Fast, Predator | A quick ghost |
| Grave Ray | Legendary | 9 Bone Graveyard | 104 | Leaper, Tank | A ghostly glider |
| Skull Angler | Legendary | 9 Bone Graveyard | 98 | Predator, Tank | An angler, still: it waits |
| Grave Turtle | Legendary | 9 Bone Graveyard | 92 | Tank, Breaker | A turtle, still |
| Bone Leviathan | Mythic | 9 Bone Graveyard | 126 | Fast, Breaker, Leaper | A racing skeleton: nothing to slow it |
| Halfbone Megalodon | Mythic | 9 Bone Graveyard | 124 | Predator, Frenzy, Tank | Half a Megalodon is still a Megalodon, and the dead half needs no air |
| Phantom Whale | Secret | 9 Bone Graveyard | 120 | Tank, Breaker, Leaper | A ghost whale |
| Hellfin Shark | Legendary | 10 The Underworld | 118 | Predator, Frenzy | A shark from the Underworld |
| Brimstone Eel | Legendary | 10 The Underworld | 116 | Fast, Predator | An eel of fire |
| Cinder Ray | Legendary | 10 The Underworld | 108 | Leaper, Fast | A burning glider |
| Infernal Angler | Legendary | 10 The Underworld | 100 | Predator, Tank | An angler, still |
| Hellmaw | Mythic | 10 The Underworld | 130 | Predator, Frenzy, Breaker | The last land's monster |
| Abyssal Watcher | Mythic | 10 The Underworld | 112 | Tank, Predator, Leaper | It watches; it doesn't hurry |
| The Devourer | Secret | 10 The Underworld | 150 | Predator, Frenzy, Breaker, Fast | The end of the list |

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
2. **The six archetypes and their numbers:** right set? Tank and Leaper are Claude's additions to the three asked
   for (fast, predator, breaker); Frenzy is the twist for the top sharks. Any of them can be dropped by clearing it
   from the rows.
3. **What eating gives:** speed and Oxygen (proposed), or only one of them?
4. **The speeds:** to play. The first thing to check is the hop between a slow and a fast fish of one land, now
   that speeds inside a land differ more (the Open Blue: 76 to 135).
5. **Props for plain fish:** today every fish breaks props, for a small cost (`Props.MinLength` 0). With Breakers
   in, should a small plain fish bounce off them? Left as it is.

## For the next task (building the passives)
- Read the archetypes from the fish's type (`Config.hasArchetype(w.Type, "Predator")`), on the server. The eat, the
  prop reward and the Oxygen are the server's (`RideService`, `FishService`, `PropService`); never trust the client.
- The speed bursts change what the rider's client drives and what the server's speed check allows
  (`Ride.SpeedSlack`): both must use the same factor, as angry mode does.
- An eaten fish goes through the herd's own removal, so the top-up replaces it.
- Tank touches `Config.drain` and `Oxygen.AngryAt`; Leaper touches the hop's numbers in `JumpController`.
- The partner's animations hang on the `Archetype` attribute; an eat or a smash will want its own signal (a tag or
  a remote) when built.
