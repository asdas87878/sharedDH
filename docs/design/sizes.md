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
- **Every spawned fish rolls a size and a colour, apart, with the reference's odds.** 24 of every fish.
- **A size is the whole fish scaled:** model, seat, the body the lock and the hop use, and its tag.

  | Size | Times the species' size |
  |---|---|
  | Tiny | 0.75 |
  | Normal | 1 |
  | Big | 1.25 |
  | Giant | 1.5 |
  | Huge | 1.8 |
  | Colossal | 2.2 |

  These are ours, to be judged by eye.
- **The tag names it,** as the reference's does: "GIANT Gold Great White". A Normal size isn't named.
- **Silver is new.** A cool grey with a mirror's sheen, white sparkles, an ice-blue glow. It is a tint: a stand-in
  until the creature chat writes its rules and bakes it, as Gold and Rainbow were. Its speed is x1.05 for now, under
  Gold's 1.1 and Rainbow's 1.2.
- **Gold and Rainbow's chances changed** to the reference's: 1 in 50 and 1 in 250 (Hugo's were 3% and 0.8%).
- **Size changes nothing else yet:** not speed (that is next) and not the Oxygen a fish needs. `Config.SizeWorth`
  holds the reference's numbers for that (0.8, 1, 1.2, 1.5, and our 2 and 3), but nothing reads it.
- **The herd goes by a fish's own length:** the room it wants, how high it swims, whether it goes straight through
  props and whether it breaks them. A Colossal reef fish behaves like the big fish it now is.

## The kinds' own sizes
`Config.BaseScale`: each kind's size, times what the creature chat exported it at. The creature files are not
touched. Claude's first go, for the user's eye: small reef fish a little smaller; the flat, the round and the heavy
bigger; the whales and the last lands' monsters most. The average is 1.23, from 0.85 to 1.6.

| Land | Smaller | As it was | Bigger |
|---|---|---|---|
| 1 | Blue Chromis 0.85, Clownfish 0.85, Butterflyfish 0.9, Boxfish 0.95, Seahorse 0.95 | Sergeant Major, Flying Fish | Yellow Tang 1.1, Cuttlefish 1.2, Stingray 1.2, Archelon 1.25, Pufferfish 1.3, Pearl Serpent 1.3, Reef Shark 1.45, **Sea Turtle 1.6** |
| 2 | Angelfish 0.95 | | Lionfish 1.15, Octopus 1.15, Moray Eel 1.2, Parrotfish 1.25, Coral Dragon 1.3, Humphead Wrasse 1.35, Dunkleosteus 1.4 |
| 3 | Garibaldi 0.9 | | Leopard Shark 1.15, Dakosaurus 1.2, Sea Lion 1.25, Giant Sea Bass 1.3, Kelp Wyrm 1.3, Great White 1.4, Steller's Sea Cow 1.4 |
| 4 | | Barracuda | Electric Ray 1.1, Xiphactinus 1.2, Hammerhead 1.25, Sawfish 1.25, Goliath Grouper 1.35, Galleon Whale 1.4 |
| 5 | | | Swordfish 1.15, Elasmosaurus 1.15, Dolphin 1.2, Helicoprion 1.2, Storm Serpent 1.3, Orca 1.35, Manta Ray 1.5, Blue Whale 1.6 |
| 6 | Viperfish 0.9 | | Goblin Shark 1.15, Giant Squid 1.2, Liopleurodon 1.2, Aurora Jelly 1.2, Lantern Leviathan 1.25, Shonisaurus 1.3 |
| 7 | | Frilled Shark | Anglerfish 1.1, Basilosaurus 1.25, Livyatan 1.3, Mosasaurus 1.3, Kraken 1.4, Void Whale 1.45 |
| 8 | Giant Isopod 0.9 | Bobbit Worm | Sea Scorpion 1.1, Anomalocaris 1.1, Kronosaurus 1.2, Ember Serpent 1.3, Megalodon 1.4, Molten Megalodon 1.45 |
| 9 | | | Skull Angler 1.15, Wraith Eel 1.2, Grave Turtle 1.3, Bone Leviathan 1.35, Grave Ray 1.4, Halfbone Megalodon 1.45, Phantom Whale 1.45 |
| 10 | | | Brimstone Eel 1.2, Infernal Angler 1.2, Hellfin Shark 1.3, Abyssal Watcher 1.4, Hellmaw 1.4, Cinder Ray 1.45, The Devourer 1.5 |

- The fish of the first land's kinds now run from 6 to 42 studs long in one sea, 13 at the median (measured on 60
  of them). Before, each kind was one size, 9 to 37.
- The longest fish there can be: a Colossal Blue Whale, 162 studs.

## Measured
In Studio on grey-box 15, by script.
- **The rolls:** of 690 fish, Tiny 13%, Normal 58%, Big 18%, Giant 7%, Huge 2.3%, Colossal 0.6%; Silver 8.4%,
  Gold 1.6%, Rainbow 0.3%. Inside what the odds give for 690.
- **Every model is the size its body says** (0% off, all 690).
- **Riding the biggest:** with every fish forced Colossal and Silver, a sandbox ride and three hops worked: the seat
  on the back, the fish at its speed (a Silver Blue Chromis at 50), 12 fish inside the hook's reach, 4 pairs of 1,378
  overlapping, the tag reading "COLOSSAL Silver Sergeant Major". No errors.
- **Not checked:** anything by eye, Silver's look most of all (Studio draws no 3D for Claude on this PC). A Colossal
  of the biggest kinds in the narrow first lands. Phones.

## To look at one
In Studio, on `Workspace`, before Play: the attribute `TestSize` (a size's name, such as `Colossal`) makes every new
fish that size, and `TestVariant` (`Silver`, `Gold`, `Rainbow`) that colour. Take them off after. The sandbox panel
has `SizeChance`, `SizeScale` and `Variant` rows; they change the fish spawned from then on.

## Open, for the user
- **Should a bigger fish need more Oxygen,** as the reference's needs more stamina (x0.8 to x1.5)? Not built: it
  changes how hard every Big fish is to hold, and there is no earning yet to pay for it.
- **How big each size is** (0.75 to 2.2), and each kind's own number.
- **The Index** (the page in the screenshot, with its 24 boxes and rewards) is not built. Nothing remembers which of
  the 24 a player has caught yet.
- **Speed** comes next.
