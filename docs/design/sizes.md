# Sizes and colours: 24 of every fish

Up: [creatures](creatures.md). The herd these fish swim in: [the herd](herd.md). Built 2026-11-13 on the user's word:
more difference between the kinds' own sizes, and every fish in the reference's six sizes and four colours. The
numbers are in `src/shared/Config.luau`: `BaseScale`, `SizeChance`, `SizeScale`, `SizeWorth`, `Variant`.

## The reference's 24
Ride a Dino's Index shows every dino in six sizes (Tiny, Normal, Big, Giant, Huge, Colossal) and four colours (Normal,
Silver, Golden, Rainbow), with "1 in N" under each. The user's screenshot of the Bronto's page gives 23 of them.

Every one of the 23 is a size's chance times a colour's chance. Worked back:

| Size | Chance | | Colour | Chance |
|---|---|---|---|---|
| Tiny | 15% | | Normal | 89.3% |
| Normal | 55% | | Silver | 1 in 12 |
| Big | 20% | | Golden | 1 in 50 |
| Giant | 7% | | Rainbow | 1 in 250 |
| Huge | 2.5% | | | |
| Colossal | 0.5% | | | |

- These give back the page: a Silver Big 1 in 60, a Golden Giant 1 in 714, a Rainbow Colossal 1 in 50,000 (the page
  says 49.9K).
- So the two are rolled apart, and the odds are the same for every dino, a Mythic included.
- The reference's size also raises the stamina a dino needs: Tiny x0.8, Big x1.2, Giant x1.5 (measured 2026-11-09).
  Huge and Colossal were never seen.
- **How much bigger each size looks can't be read off it.**

## What is built
The user's second word, the same day, after seeing the first go: looks only for now; the fish are too small across
the board; too alike at the start; one or two should come through with a much grander size; and variety is to be
kept up all the way down, by rule. What follows is the second go.

- **Every spawned fish rolls a size and a colour, apart, with the reference's odds.** 24 of every fish.
- **A size is the whole fish scaled:** model, seat, the body the lock and the hop use, and its tag.

  | Size | Times the kind's size | At first |
  |---|---|---|
  | Tiny | 0.7 | 0.75 |
  | Normal | 1 | 1 |
  | Big | 1.35 | 1.25 |
  | Giant | 1.8 | 1.5 |
  | Huge | 2.3 | 1.8 |
  | Colossal | 3 | 2.2 |

  These are ours, to be judged by eye. No fish is longer than 200 studs or wider than 96, whatever its size
  (`Config.SizeLimit`): the biggest kinds' biggest sizes stop there.
- **A grand fish or two in every stretch.** A grand fish is a Giant, a Huge or a Colossal. By the odds alone they
  are one in ten, and whole stretches have none. So the stocking counts them (`Config.Grand`): a new fish going
  into a stretch with no grand fish within 200 studs either way is made one, and in a stretch that already has two,
  a fish that rolls grand is a Big instead.
- **Kinds are mixed.** A new fish's rarity is rolled as ever. Its kind is the least seen nearby of three draws from
  that rarity's kinds (`Spawn.KindTries`), so the same fish doesn't come three in a row.
- **The tag names the size,** as the reference's does: "GIANT Gold Great White". A Normal size isn't named.
- **Silver is new.** A cool grey with a mirror's sheen, white sparkles, an ice-blue glow. It is a tint: a stand-in
  until the creature chat writes its rules and bakes it, as Gold and Rainbow were. Its speed is x1.05 for now, under
  Gold's 1.1 and Rainbow's 1.2.
- **Gold and Rainbow's chances changed** to the reference's: 1 in 50 and 1 in 250 (Hugo's were 3% and 0.8%).
- **Size is looks only** (the user): not speed (that is next) and not the Oxygen a fish needs. `Config.SizeWorth`
  holds the reference's numbers for that (0.8, 1, 1.2, 1.5, and our 2 and 3), but nothing reads it.
- **The herd goes by a fish's own length:** the room it wants, how high it swims, whether it goes straight through
  props and whether it breaks them. A Colossal reef fish behaves like the big fish it now is.

## The kinds' own sizes
`Config.BaseScale`: each kind's size, times what the creature chat exported it at. The creature files are not
touched. Claude's numbers, for the user's eye. Every kind is bigger than it was exported (1.2 to 2.6, 1.75 on
average), and the first land's kinds are spread widest. The first go was 0.85 to 1.6.

| Land | Times its export |
|---|---|
| 1 | Blue Chromis 1.2, Clownfish 1.3, Butterflyfish 1.45, Sergeant Major 1.55, Flying Fish 1.7, Stingray 1.7, Archelon 1.7, Boxfish 1.75, Yellow Tang 1.8, Seahorse 1.8, Pearl Serpent 1.8, Cuttlefish 2, Pufferfish 2.3, Reef Shark 2.3, **Sea Turtle 2.6** |
| 2 | Angelfish 1.3, Lionfish 1.6, Moray Eel 1.6, Octopus 1.7, Coral Dragon 1.8, Parrotfish 1.9, Humphead Wrasse 2, Dunkleosteus 2 |
| 3 | Garibaldi 1.3, Leopard Shark 1.6, Dakosaurus 1.7, Sea Lion 1.8, Kelp Wyrm 1.8, Giant Sea Bass 1.9, Great White 2, Steller's Sea Cow 2 |
| 4 | Barracuda 1.4, Electric Ray 1.6, Sawfish 1.7, Xiphactinus 1.7, Hammerhead 1.8, Galleon Whale 1.9, Goliath Grouper 2 |
| 5 | Swordfish 1.6, Elasmosaurus 1.6, Dolphin 1.7, Helicoprion 1.7, Storm Serpent 1.8, Orca 1.9, Manta Ray 2.1, Blue Whale 2.2 |
| 6 | Viperfish 1.3, Giant Squid 1.6, Goblin Shark 1.6, Liopleurodon 1.7, Lantern Leviathan 1.7, Aurora Jelly 1.7, Shonisaurus 1.8 |
| 7 | Frilled Shark 1.4, Anglerfish 1.6, Basilosaurus 1.7, Livyatan 1.8, Mosasaurus 1.8, Kraken 1.9, Void Whale 2 |
| 8 | Giant Isopod 1.3, Bobbit Worm 1.4, Sea Scorpion 1.6, Anomalocaris 1.6, Kronosaurus 1.7, Ember Serpent 1.8, Megalodon 1.9, Molten Megalodon 2 |
| 9 | Skull Angler 1.6, Wraith Eel 1.7, Grave Turtle 1.8, Bone Leviathan 1.8, Grave Ray 2, Halfbone Megalodon 2, Phantom Whale 2 |
| 10 | Brimstone Eel 1.7, Infernal Angler 1.7, Hellfin Shark 1.8, Abyssal Watcher 1.9, Hellmaw 1.9, Cinder Ray 2, The Devourer 2.1 |

- **The first land's seven Commons** are now 12, 13, 14, 15, 18, 20 and 23 studs long (Blue Chromis, Clownfish,
  Butterflyfish, Boxfish, Yellow Tang, Sergeant Major, Pufferfish). As exported they were 9 to 13.
- A Sea Turtle is 37 long and 41 wide; a Reef Shark 40 long; a Blue Whale 101.

## Measured
In Studio on grey-box 15, by script, on the second go.
- **The sizes over 687 fish:** Tiny 13%, Normal 48%, Big 24%, Giant 11%, Huge 3.8%, Colossal 0.6%. The grand rule
  is why this is not the odds: one fish in six or seven is grand, not one in ten, and Normals pay for it.
- **Grand fish down the lane:** of 113 stretches of 400 studs, 1 had none, 38 had one, 51 had two, 23 had more.
- **In a stretch, the biggest fish is 4.8 times as long as the smallest,** on average.
- **Round a rider in the second land,** the 13 fish inside the hook's reach were 12 to 51 studs long: a Tiny, five
  Normals, five Bigs and two Giants, of ten kinds.
- **The colours** (first go, unchanged): Silver 8.4%, Gold 1.6%, Rainbow 0.3% of 690.
- **Every model is the size its body says** (0% off, all 690, first go).
- **Riding:** a sandbox ride with four hops through the mixed sea, and one with every fish forced Colossal, landing
  on a Sea Turtle 124 wide and 112 long (before the width was stopped at 96): the rider on its back, the fish at its
  speed, 13 fish inside the hook's reach. No errors.
- **Not checked:** anything by eye, Silver's look most of all (Studio draws no 3D for Claude on this PC). Phones.

## To look at one
In Studio, on `Workspace`, before Play: the attribute `TestSize` (a size's name, such as `Colossal`) makes every new
fish that size, and `TestVariant` (`Silver`, `Gold`, `Rainbow`) that colour. Take them off after. The sandbox panel
has `SizeChance`, `SizeScale`, `Grand` and `Variant` rows; they change the fish spawned from then on.

## Open, for the user
- **A bigger fish needing more Oxygen** is not built: the user chose looks only for now.
- **How big each size is** (0.7 to 3), each kind's own number, and how often a grand fish comes (`Config.Grand`).
- **The Index** (the page in the screenshot, with its 24 boxes and rewards) is not built. Nothing remembers which of
  the 24 a player has caught yet.
- **Speed** comes next.
