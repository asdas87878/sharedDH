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

- **Every spawned fish rolls a size and a colour, apart.** 24 of every fish. The colours are on the reference's
  odds. The sizes started there and were then leaned small (below).
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
- **Sizes lean small, most of all for Commons** (the user's third word: big sizes were "over prescribed" on the
  smaller animals and "should be rarer especially among common folk"; fish "should tend to cluster around the
  smaller sizes, larger sizes being rarer but still occurring every now and then"). The chances of Big and up are
  times `Config.SizeLarge` for the fish's rarity, and Tiny's is times `Config.SizeSmall`:

  | Rarity | Big and up, times | Tiny, times | Tiny | Normal | Big | Giant | Huge | Colossal |
  |---|---|---|---|---|---|---|---|---|
  | The reference | 1 | 1 | 15% | 55% | 20% | 7% | 2.5% | 0.5% |
  | Common | 0.35 | 1.4 | 21% | 68.5% | 7% | 2.5% | 0.9% | 0.2% |
  | Uncommon | 0.5 | 1.3 | 19.5% | 65.5% | 10% | 3.5% | 1.25% | 0.25% |
  | Rare | 0.6 | 1.2 | 18% | 64% | 12% | 4.2% | 1.5% | 0.3% |
  | Epic, Legendary | 0.7 | 1.1 | 16.5% | 62.5% | 14% | 4.9% | 1.75% | 0.35% |
  | Mythic, Secret | 0.8 | 1 | 15% | 61% | 16% | 5.6% | 2% | 0.4% |

- **A grand fish every now and then, by rule.** A grand fish is a Giant, a Huge or a Colossal. On the odds above
  whole stretches would have none. So the stocking counts them (`Config.Grand`): a new fish going into a stretch
  with no grand fish within 400 studs either way is made one, and where there is one already a fish that rolls
  grand is a Big instead. A Common is seldom the one made grand (15 times in 100): the stretch waits for a rarer
  fish. (One or two in every 400 studs at first: too many, and too often a Common.)
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
In Studio on grey-box 15, by script, on the third go.
- **The sizes over 610 fish:** Tiny 15%, Normal 62%, Big 17%, Giant 4.6%, Huge 1.3%, Colossal 0.3%. One fish in
  sixteen is grand (the second go: one in six or seven).
- **By rarity:** no grand fish among the 25 Commons, 3% of the Uncommons, 6 to 8% of the Rares, Epics and
  Legendaries.
- **Grand fish down the lane:** of 56 stretches of 800 studs, 2 had none, 34 had one, 19 had two, 1 had three.
- **The first land (2,300 studs):** 43 fish; half are under 19 studs long, three quarters under 24, nine in ten
  under 37; the biggest was 63.
- **Round a rider there,** the ten fish inside the hook's reach: a Tiny, eight Normals and a Big, 11 to 37 studs.
- **Crowding, round a rider:** before, 8 to 11 of 41 swimming fish overlapped another by a rough measure, and 13
  or 14 were within 10 studs of touching. After the first changes, 6 and 7 to 10 of 30. On the last run, by a
  truer measure (bodies as boxes down the lane): 1 pair of 42 fish overlapping, 4 pairs within 8 studs.
- **The colours** (first go, unchanged): Silver 8.4%, Gold 1.6%, Rainbow 0.3% of 690.
- **Riding:** sandbox rides with hops through the mixed sea on each go, and one with every fish forced Colossal
  (second go). No errors.
- **Not checked:** anything by eye, Silver's look most of all (Studio draws no 3D for Claude on this PC). Phones.

## Crowding
The user, on the second go: "there's a crowded amount in some places". Measured: standing at the dock the sea was
even; riding, a third of the swimming fish were within touching distance of another. What was done:
- **Fewer big bodies** (above).
- **Fewer fish where the band is narrow.** The first lands' band is a third as wide as the deep lands' and had the
  same number of fish in every 1,000 studs. A stretch whose band is under 300 wide now gets fewer, in proportion,
  down to 0.65 of the number (`Spawn.FullBand`, `ThinLeast`). The sea went from 688 fish to 610.
- **Passing fish keep 18 studs apart** (14), from 44 studs nose to tail (36).
- **A fish that swims out of sight into a stretch that has its share is taken away,** not put back in.
- **What is left is speed.** Wild fish swim at 0.85 of their own ridden speed, so fast kinds run into slow ones
  all the time, and the fish a rider has just left stay beside them for a while. The reference's herd runs at one
  pace. That belongs to the speed work, which is next.

## To look at one
In Studio, on `Workspace`, before Play: the attribute `TestSize` (a size's name, such as `Colossal`) makes every new
fish that size, and `TestVariant` (`Silver`, `Gold`, `Rainbow`) that colour. Take them off after. The sandbox panel
has `SizeChance`, `SizeScale`, `SizeLarge`, `SizeSmall`, `Grand` and `Variant` rows; they change the fish spawned from then on.

## Open, for the user
- **A bigger fish needing more Oxygen** is not built: the user chose looks only for now.
- **How big each size is** (0.7 to 3), each kind's own number, how far the sizes lean small by rarity, and how
  often a grand fish comes (`Config.Grand`).
- **The reference's Index numbers are no longer ours:** it has one set of odds for every dino; ours differ by
  rarity and the grand rule moves them again. An Index of ours would show its own numbers.
- **The Index** (the page in the screenshot, with its 24 boxes and rewards) is not built. Nothing remembers which of
  the 24 a player has caught yet.
- **Speed** comes next.
