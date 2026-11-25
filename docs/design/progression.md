# Progression: speed, rarity and Oxygen

> **Studies, 2026-11-16.** Four things to know before the next pass. The reference has no cap of seven on a run's catch. Its first machine gives +2 for 300 coins, and it has twelve levels. Its typical player sees about an hour in all, so lands 1 to 3 are the game. Its zones are open to anyone who hops, and that is its trailer. [Findings](../Findings.md), rank 1 and "What we had wrong".

How long you can stay on a fish, how fast each fish is, how often each rarity turns up, and so how a player gets from
the Shallows to the tenth land. **Start at "What a fish needs is its own" (task e1): it replaces every land cost
below. Then "Today's rules"; the rest is the record.** The economy's draft 2 (2026-11-22: Ride a Dino's
progression, needs into the billions) is the next section, for the user's and Hugo's pick; it supersedes draft 1
(2026-11-19). Nothing in either is in the game. By the tuning chat
([Sessions](../Sessions.md)); fourth pass 2026-11-16, for the refinement; second pass 2026-11-11, after the
user's answer on how the Oxygen cost works; third pass 2026-11-12, after the user's answer on a fish that is too
strong for you, and with taming built ([Decisions](../Decisions.md)).

**What is applied and what is proposed.** The Oxygen numbers below are in the game (they follow the user's
direction). The speeds, the traits and everything under "Not built yet" are proposals. What the user decides goes in
[Decisions](../Decisions.md).

The tables come from a model that reads the game's own numbers, so they can be made again after any change:

```
python tools/balance/model.py              the tables
python tools/balance/model.py --sim 8      and 8 dives per rider played through the herd
python tools/balance/model.py --max 3000   the "seconds on a fish" table for a player with 3,000 max Oxygen
python tools/balance/model.py --set Tiers.Common=54 --set RarityOxygen.Legendary=10   try numbers without changing the game
```

It reads [Config](../../src/shared/Config.luau), the creature files in `src/shared/Creatures` and the map's path
(`art/map/greybox/path.json`). The dives are a model of the herd's rules, not a play test: they leave out steering,
walls and other players. Where a number matters, it should be checked in play.

## What a fish needs is its own (task e1, 2026-11-20): in the game

**State:** in the game code; checked by script in Studio (`tools/studio/oxygen_check.luau`, 12 of 12 pass) and in
one playtest by script; **not played by hand. Every number here is provisional** until Hugo plays it. Plan:
[E1](../plans/2026-11-20-oxygen-equip-landride.md); Hugo's rules: "each upgrade gives one set whole number of oxygen,
no decimals"; a fish's Oxygen never depends on the land it spawned in. Options A to G were not picked, so the plan's
defaults are used.

**The rule.** One whole number for each fish (`Config.requiredOf(kind, size, colour)`):

    need = ceil(OxygenBase[kind] x RarityOxygen[rarity] x SizeOxygen[size] x VariantOxygen[colour] x SpecialOxygen...)

rounded once, at the end. The land only decides which fish swim there. A Clownfish needs 80 in land 1 and in land 2;
a Normal plain Hellfin Shark needs 44,550 in land 6 and in land 10. That one number is the tag ("Required: 675"), too
strong or not (`Config.strained(need, max)`), the seconds on it and so the drain (`secondsOn`, `drainFor`), the tame
(`tameTime`) and the tank's coins (`incomeOf` = need x 0.025, size and colour not counted again). Server
(`RideService`, `needOf`) and every client (`Config.requiredOfModel`: the model's FishType, SizeTier and Variant) work
it out the same way; the model's old `Required` attribute is gone.

- **Bases** (`Config.OxygenBase`): one per kind, all 82, written by hand. The plan's samples are kept exactly
  (Clownfish 80, Yellow Tang 90, Seahorse 52, Reef Shark 120, Dunkleosteus 200, Blue Whale 600, Kraken 900); the rest
  were drafted on a ladder of about 1.5 times a land deeper (deeper animals are the stronger ones), spread within a
  land by the animal's bulk, then written down. Change any one freely: nothing works them out again. No two kinds
  share a base or a Normal plain need (two clashes were nudged: Cuttlefish 68, Barracuda 255).
- **Rarity** (`RarityOxygen`, the old RarityDrain's numbers): Common 1, Uncommon 1.25, Rare 2.5, Epic 4.5,
  Legendary 15, Mythic 50, Secret 150.
- **Size** (`SizeOxygen`, the reference's measured Tiny 0.8, Big 1.2, Giant 1.5; ours Huge 2, Colossal 3): a bigger
  fish now needs more, and earns more with it. **Colour** (`VariantOxygen`): Silver 1.25, Gold 1.5, Rainbow 2.
- **Specials** (`SpecialOxygen`, archetype id to times): empty. A Tank stays a longer ride (`Archetype.Tank.Drain`),
  never a smaller need.
- **The grow** of a fish's seconds and tame counts from `Config.GrowFrom` 80 (a Normal plain Clownfish), not from
  "the Shallows Common".
- **Gone:** `Config.ZoneDrain` (a cost by the land you were IN, x4 a land), `RarityDrain`, `Config.drain`,
  `drainOf`, `required(zone, tier)`, `SizeWorth`, the tank's own colour multipliers (`Aquarium.Silver/Gold/Rainbow`
  1.5 / 3 / 10: a Rainbow now earns twice a plain one, as it needs twice), `Train.Share`. The sandbox panel has
  SizeOxygen, VariantOxygen and RarityOxygen rows in place of ZoneDrain and RarityDrain.
- **Shown whole:** tags, the "needs" line when a fish is too strong, the trainer's "+n" and the upgrade sign use
  `Config.wholeNumber` (2,925, never 2.9K). Coins a second may keep decimals. The HUD's own Oxygen row is whole to
  999,999, then four figures (3.285M), so it keeps the coins' size (the user, 2026-11-23).
- **The balance model** (`tools/balance/model.py`) reads the new tables; a land's row there is the median need of
  the kinds that live in it. Its play-through on the draft's two paces reaches land 10 at 230 and 447 minutes and
  land 10's Mythics at 335 and 668 (it was built on the old land costs: read it as a rough guide).

**Training** (`TrainService`, `Config.trainTicks`): the level's whole Oxygen (`Train.Levels`, 4 to 600, placeholders)
once for every whole second seated, never a share of a frame, so it is the same at any frame rate. A part of a second
is dropped on getting off and starts again at the new level on an upgrade. One "Gain" (a whole number) and one "+n"
pop per second. Checked: 12 levels x 3 frame timings x max 100 and 100,000, 10 s gives exactly 10 x the level's gain,
0.9 s gives nothing; live in a playtest, level 1 took the max from 100 to 160 in 15 s, +4 each second.

Samples (from `oxygen_check.luau`'s run, `work/e1/oxygen_check.txt`):

| Fish | Land it lives in | Rarity | Base | Size / colour | Needs | Coins/s |
|---|---:|---|---:|---|---:|---:|
| Clownfish | 1 | Common | 80 | Normal / plain | 80 | 2 |
| Clownfish | 1 | Common | 80 | Tiny / plain | 64 | 1.6 |
| Clownfish | 1 | Common | 80 | Giant / Gold | 180 | 4.5 |
| Clownfish | 1 | Common | 80 | Colossal / Rainbow | 480 | 12 |
| YellowTang | 1 | Common | 90 | Normal / plain | 90 | 2.25 |
| Seahorse | 1 | Rare | 52 | Normal / plain | 130 | 3.25 |
| ReefShark | 1 | Epic | 120 | Normal / plain | 540 | 13.5 |
| Dunkleosteus | 2 | Legendary | 200 | Normal / plain | 3,000 | 75 |
| Dunkleosteus | 2 | Legendary | 200 | Big / Silver | 4,500 | 112.5 |
| GreatWhite | 3 | Epic | 205 | Normal / plain | 923 | 23.075 |
| Orca | 5 | Epic | 435 | Normal / plain | 1,958 | 48.95 |
| BlueWhale | 5 | Mythic | 600 | Normal / plain | 30,000 | 750 |
| Kraken | 7 | Mythic | 900 | Normal / plain | 45,000 | 1125 |
| Megalodon | 8 | Legendary | 1800 | Normal / plain | 27,000 | 675 |
| HellfinShark | 10 | Legendary | 2970 | Normal / plain | 44,550 | 1113.75 |
| Hellmaw | 10 | Mythic | 3180 | Normal / plain | 159,000 | 3975 |
| TheDevourer | 10 | Secret | 3650 | Colossal / Rainbow | 3,285,000 | 82125 |

Shots: the tags in play (a Silver Reef Shark "Required: 675" in red against a max of 244; a Tiny Boxfish 52; a Big
Clownfish 96), `docs/attachments/e1-tags.jpg`; the seahorse at level 1 ("+4 > +6 Oxygen/s", the "+4" pop, max 200),
`docs/attachments/e1-seahorse-level.jpg`.

<details><summary>Every kind (82): base, and what a Tiny plain, a Normal plain and a Colossal Rainbow one need</summary>

| Land | Fish | Rarity | Base | Tiny plain | Normal plain | Colossal Rainbow | Coins/s (Normal plain) |
|---:|---|---|---:|---:|---:|---:|---:|
| 1 | Butterflyfish | Common | 57 | 46 | 57 | 342 | 1.425 |
| 1 | BlueChromis | Common | 61 | 49 | 61 | 366 | 1.525 |
| 1 | Boxfish | Common | 65 | 52 | 65 | 390 | 1.625 |
| 1 | Pufferfish | Common | 76 | 61 | 76 | 456 | 1.9 |
| 1 | Clownfish | Common | 80 | 64 | 80 | 480 | 2 |
| 1 | SergeantMajor | Common | 82 | 66 | 82 | 492 | 2.05 |
| 1 | YellowTang | Common | 90 | 72 | 90 | 540 | 2.25 |
| 1 | Cuttlefish | Uncommon | 68 | 68 | 85 | 510 | 2.125 |
| 1 | SeaTurtle | Uncommon | 81 | 81 | 102 | 608 | 2.55 |
| 1 | Stingray | Uncommon | 83 | 83 | 104 | 623 | 2.6 |
| 1 | FlyingFish | Uncommon | 91 | 91 | 114 | 683 | 2.85 |
| 1 | Seahorse | Rare | 52 | 104 | 130 | 780 | 3.25 |
| 1 | ReefShark | Epic | 120 | 432 | 540 | 3,240 | 13.5 |
| 1 | Archelon | Legendary | 130 | 1,560 | 1,950 | 11,700 | 48.75 |
| 1 | PearlSerpent | Secret | 105 | 12,600 | 15,750 | 94,500 | 393.75 |
| 2 | Parrotfish | Uncommon | 100 | 100 | 125 | 750 | 3.125 |
| 2 | Angelfish | Uncommon | 110 | 110 | 138 | 825 | 3.45 |
| 2 | Lionfish | Uncommon | 115 | 115 | 144 | 863 | 3.6 |
| 2 | MorayEel | Rare | 93 | 186 | 233 | 1,395 | 5.825 |
| 2 | Octopus | Rare | 125 | 250 | 313 | 1,875 | 7.825 |
| 2 | HumpheadWrasse | Epic | 135 | 486 | 608 | 3,645 | 15.2 |
| 2 | Dunkleosteus | Legendary | 200 | 2,400 | 3,000 | 18,000 | 75 |
| 2 | CoralDragon | Secret | 185 | 22,200 | 27,750 | 166,500 | 693.75 |
| 3 | Garibaldi | Uncommon | 140 | 140 | 175 | 1,050 | 4.375 |
| 3 | SeaLion | Uncommon | 150 | 150 | 188 | 1,125 | 4.7 |
| 3 | LeopardShark | Rare | 145 | 290 | 363 | 2,175 | 9.075 |
| 3 | GiantSeaBass | Rare | 165 | 330 | 413 | 2,475 | 10.325 |
| 3 | StellersSeaCow | Epic | 190 | 684 | 855 | 5,130 | 21.375 |
| 3 | GreatWhite | Epic | 205 | 738 | 923 | 5,535 | 23.075 |
| 3 | Dakosaurus | Legendary | 195 | 2,340 | 2,925 | 17,550 | 73.125 |
| 3 | KelpWyrm | Secret | 210 | 25,200 | 31,500 | 189,000 | 787.5 |
| 4 | Barracuda | Uncommon | 255 | 255 | 319 | 1,913 | 7.975 |
| 4 | Sawfish | Rare | 260 | 520 | 650 | 3,900 | 16.25 |
| 4 | HammerheadShark | Rare | 270 | 540 | 675 | 4,050 | 16.875 |
| 4 | ElectricRay | Epic | 240 | 864 | 1,080 | 6,480 | 27 |
| 4 | GoliathGrouper | Epic | 310 | 1,116 | 1,395 | 8,370 | 34.875 |
| 4 | Xiphactinus | Legendary | 335 | 4,020 | 5,025 | 30,150 | 125.625 |
| 4 | GalleonWhale | Secret | 430 | 51,600 | 64,500 | 387,000 | 1612.5 |
| 5 | Swordfish | Rare | 355 | 710 | 888 | 5,325 | 22.2 |
| 5 | Dolphin | Rare | 385 | 770 | 963 | 5,775 | 24.075 |
| 5 | MantaRay | Epic | 350 | 1,260 | 1,575 | 9,450 | 39.375 |
| 5 | Orca | Epic | 435 | 1,566 | 1,958 | 11,745 | 48.95 |
| 5 | Elasmosaurus | Legendary | 420 | 5,040 | 6,300 | 37,800 | 157.5 |
| 5 | Helicoprion | Legendary | 465 | 5,580 | 6,975 | 41,850 | 174.375 |
| 5 | BlueWhale | Mythic | 600 | 24,000 | 30,000 | 180,000 | 750 |
| 5 | StormSerpent | Secret | 390 | 46,800 | 58,500 | 351,000 | 1462.5 |
| 6 | Viperfish | Rare | 490 | 980 | 1,225 | 7,350 | 30.625 |
| 6 | GiantSquid | Epic | 485 | 1,746 | 2,183 | 13,095 | 54.575 |
| 6 | GoblinShark | Epic | 495 | 1,782 | 2,228 | 13,365 | 55.7 |
| 6 | Liopleurodon | Legendary | 690 | 8,280 | 10,350 | 62,100 | 258.75 |
| 6 | Shonisaurus | Legendary | 695 | 8,340 | 10,425 | 62,550 | 260.625 |
| 6 | LanternLeviathan | Mythic | 610 | 24,400 | 30,500 | 183,000 | 762.5 |
| 6 | AuroraJelly | Secret | 860 | 103,200 | 129,000 | 774,000 | 3225 |
| 7 | FrilledShark | Epic | 545 | 1,962 | 2,453 | 14,715 | 61.325 |
| 7 | Anglerfish | Epic | 940 | 3,384 | 4,230 | 25,380 | 105.75 |
| 7 | Basilosaurus | Legendary | 785 | 9,420 | 11,775 | 70,650 | 294.375 |
| 7 | Livyatan | Legendary | 825 | 9,900 | 12,375 | 74,250 | 309.375 |
| 7 | Mosasaurus | Legendary | 910 | 10,920 | 13,650 | 81,900 | 341.25 |
| 7 | Kraken | Mythic | 900 | 36,000 | 45,000 | 270,000 | 1125 |
| 7 | VoidWhale | Secret | 985 | 118,200 | 147,750 | 886,500 | 3693.75 |
| 8 | SeaScorpion | Epic | 915 | 3,294 | 4,118 | 24,705 | 102.95 |
| 8 | GiantIsopod | Epic | 1040 | 3,744 | 4,680 | 28,080 | 117 |
| 8 | BobbitWorm | Legendary | 1060 | 12,720 | 15,900 | 95,400 | 397.5 |
| 8 | Anomalocaris | Legendary | 1280 | 15,360 | 19,200 | 115,200 | 480 |
| 8 | Kronosaurus | Legendary | 1570 | 18,840 | 23,550 | 141,300 | 588.75 |
| 8 | Megalodon | Legendary | 1800 | 21,600 | 27,000 | 162,000 | 675 |
| 8 | MoltenMegalodon | Mythic | 1805 | 72,200 | 90,250 | 541,500 | 2256.25 |
| 8 | EmberSerpent | Secret | 1440 | 172,800 | 216,000 | 1,296,000 | 5400 |
| 9 | WraithEel | Legendary | 1260 | 15,120 | 18,900 | 113,400 | 472.5 |
| 9 | SkullAngler | Legendary | 1900 | 22,800 | 28,500 | 171,000 | 712.5 |
| 9 | GraveTurtle | Legendary | 2050 | 24,600 | 30,750 | 184,500 | 768.75 |
| 9 | GraveRay | Legendary | 2210 | 26,520 | 33,150 | 198,900 | 828.75 |
| 9 | BoneLeviathan | Mythic | 1980 | 79,200 | 99,000 | 594,000 | 2475 |
| 9 | HalfboneMegalodon | Mythic | 2480 | 99,200 | 124,000 | 744,000 | 3100 |
| 9 | PhantomWhale | Secret | 2110 | 253,200 | 316,500 | 1,899,000 | 7912.5 |
| 10 | CinderRay | Legendary | 2170 | 26,040 | 32,550 | 195,300 | 813.75 |
| 10 | BrimstoneEel | Legendary | 2820 | 33,840 | 42,300 | 253,800 | 1057.5 |
| 10 | HellfinShark | Legendary | 2970 | 35,640 | 44,550 | 267,300 | 1113.75 |
| 10 | InfernalAngler | Legendary | 3080 | 36,960 | 46,200 | 277,200 | 1155 |
| 10 | Hellmaw | Mythic | 3180 | 127,200 | 159,000 | 954,000 | 3975 |
| 10 | AbyssalWatcher | Mythic | 3480 | 139,200 | 174,000 | 1,044,000 | 4350 |
| 10 | TheDevourer | Secret | 3650 | 438,000 | 547,500 | 3,285,000 | 13687.5 |

</details>

## The economy, draft 2 (2026-11-22): Ride a Dino's progression, for the user and Hugo
The user, 2026-11-22: *"We need to pretty much replicate ride a dinos progression ... The upper tier dinos in ride a
dino are in the billions, possibly higher ... we need that huge cap whilst making the progression possible."* **In
`Config` since 2026-11-23** (the user: "Yes, as drafted"): the needs, the seahorse's twelve levels, the plot's five
prices, and `Oxygen.Grow` 0.1 to 0.035 and `Oxygen.Cap` 500K to 50B so the seconds on a fish and the tame stay about
as they were. **Not yet:** selling at 200 s, earning while away. (Auras are bought since 2026-11-24, at the prices in "The aura
prices" below; the Index is built too.) The seahorse's levels
cost their coins since 2026-11-23 (`Train.Free` 0; the user: "Yes, charge"). **Checked in Studio by script 2026-11-23** (the game-code chat; not
played by hand): levels 2 and 3 and the plot stages charge their price once and refuse a short purse; at exactly its
need a Sea Scorpion (land 8) lasts 7.92 s (paper 7.65) and tames in 3.02 s (3.06), a Cinder Ray (land 10) 9.03 s
(9.25) and 3.65 s (3.70). Modelled on `Config` as written: the full design reaches land 10 in 31.2 h (five seeds); **without the auras and the Index, paying for
the seahorse, 199 h** (land 5 at 67 min, 7 at 8 h). It replaces draft 1 (below). Before it (task e1) the needs topped out
at 3.3M, because e1's bases grow only about 1.5 times a land. Every reference number is from
[the deep study](../reference/ride-a-dino-deep.md) (seen, said or fit, marked in the tables). The tables:
[economy-draft-2-tables](../attachments/economy-draft-2-tables.md).

```
python tools/balance/rad_economy.py               the tables and a free player's play-through
python tools/balance/rad_economy.py --no-index    the same player with no Index rewards
python tools/balance/rad_economy.py --sit 0.25    a player who sits on the seahorse less
python tools/balance/rad_economy.py --step 6      a gentler need ladder
```

### How it copies theirs
- **Our Oxygen = their Stamina x 8.** Their first wild dino needs 10, our Clownfish 80. So their last zone's 700M to
  1.6B is our land 10's 5B to 13B.
- **Our coins = their dollars.** A fish still earns its need / 40 a second (`Aquarium.PerRequired` 0.025, unchanged):
  our Clownfish earns $2 like their first earner. **Early on we earn less than they do:** when the played-through player
  passes 15K max Oxygen (about 10 minutes in) the tank earns $560 to $715 a second (five seeds, measured 2026-11-23),
  where their user's account at 1.9K Stamina (x8: 15K) earned $2.2K to $5K: 3 to 9 times under. The pace below is run
  with our own lower earnings, so **their price
  ladders are our prices as they stand**, coin for dollar. Income rising with the need, as theirs does, is what
  carries the money into the trillions and beyond.
- **Their late Stamina comes from the Index, not the machine.** Their AFK players on the machine look to come to a
  few hundred Stamina a second before Robux multipliers (inferred from two recordings), while their last zone needs a
  billion; the free player who finished did it with "Claim All". So our Index (accepted 2026-11-16, not built) pays
  Oxygen for each new kind and each finished land. Without it the same player reaches land 10 at 58 hours instead of
  31.

### The aura prices (2026-11-24, in `Config.Aura.Prices`)
Hugo, 2026-11-24: "Prices should be consistent across different parts like the seahorses, make sure the scaling is
cohesive." **Claude's reading and numbers (task a1), the tuning chat's to change; modelled, not played.** One ladder: $100
(the first, decided 2026-11-23), then x20 a tier, the step of the seahorse's own last levels:
**$100, $2K, $40K, $800K, $15M, $300M, $6B, $120B, $2.5T, $50T, $1Qa, $20Qa.**

The one scale that fits them all is how long a thing is saved for: **income** is its price in minutes of what the tank earns
as it is bought, **share** is those minutes over the time played so far (medians of 5 seeds, 90 h;
`python tools/balance/rad_economy.py --prices --hours 90`, which reads the auras' and subs' prices from `Config`):

| Aura | Price | Step | Bought at | Income | Share | Seahorse, same number | Bought at | Income | Share | Aura / it | Sub, same number | Bought at | Income | Share | Aura / it |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 1 Bubble x1.5 | $100 |  | 1 min | 1.7 min | 250% |  |  |  |  |  | $75K | 10 min | 2.2 min | 23% | 0.001 |
| 2 Shell x2 | $2,000 | x20.0 | 2 min | 1.9 min | 92% | $15K | 5 min | 2.2 min | 43% | 0.13 | $500K | 17 min | 3.3 min | 19% | 0.004 |
| 3 Tide x2.5 | $40K | x20.0 | 8 min | 2.9 min | 37% | $250K | 13 min | 3.5 min | 26% | 0.16 | $5M | 30 min | 3.3 min | 11% | 0.008 |
| 4 Current x3 | $800K | x20.0 | 20 min | 2.6 min | 13% | $4M | 27 min | 4.0 min | 15% | 0.20 | $50M | 55 min | 5.7 min | 10% | 0.016 |
| 5 Reef x3.5 | $15M | x18.8 | 38 min | 5.8 min | 15% | $80M | 62 min | 6.1 min | 10% | 0.19 | $500M | 89 min | 10 min | 12% | 0.030 |
| 6 Storm x4 | $300M | x20.0 | 75 min | 9.5 min | 13% | $2.5B | 2.2 h | 26 min | 19% | 0.12 | $5B | 2.7 h | 17 min | 11% | 0.060 |
| 7 Moon x5 | $6B | x20.0 | 3.0 h | 18 min | 10% | $75B | 4.6 h | 29 min | 11% | 0.08 | $75B | 5.1 h | 27 min | 9% | 0.080 |
| 8 Lantern x6 | $120B | x20.0 | 5.7 h | 41 min | 12% | $3T | 14.7 h | 110 min | 13% | 0.04 | $1T | 10.8 h | 51 min | 8% | 0.120 |
| 9 Ember x7 | $2.5T | x20.8 | 12.7 h | 101 min | 13% | $60T | 30.1 h | 188 min | 10% | 0.04 | $15T | 21.8 h | 117 min | 9% | 0.167 |
| 10 Urchin x8 | $50T | x20.0 | 26.4 h | 239 min | 15% | $1.2Qa | 78.5 h | 1,007 min | 21% | 0.04 |  |  |  |  |  |
| 11 Abyss x10 | $1Qa | x20.0 | 61.9 h | 1,114 min | 30% | $25Qa | later |  |  | 0.04 |  |  |  |  |  |
| 12 Leviathan x12 | $20Qa | x20.0 | later |  |  | $500Qa | later |  |  | 0.04 |  |  |  |  |  |

| Tank stage | Price | Bought at | Income | Share |
|---|---|---|---|---|
| 1 | $1M | 22 min | 2.3 min | 10% |
| 2 | $30M | 48 min | 9.6 min | 20% |
| 3 | $1B | 1.8 h | 15 min | 14% |
| 4 | $30B | 3.8 h | 29 min | 13% |
| 5 | $1T | 9.8 h | 67 min | 11% |

- **Cohesive now:** from tier 4 to 10 an aura asks 10 to 15% of the time played, a seahorse level 10 to 21%, a sub (4 to 9) 8 to
  12%, a tank stage 10 to 20%. Tier 11 asks 30%; tier 12 is not reached in 90 h.
- **Draft 2's ladder** ($100, $5K, $75K, $1.5M, $30M, $750M, $20B, $500B, $12.5T, $300T, $5Qa, $100Qa; steps x15 to x50), the same
  run with `--draft2-auras`: tiers 1 to 10 asked 250%, 117%, 35%, 12%, 25%, 13%, 14%, 31%, 29%, 29%; tiers 11 and 12 were not
  reached. Beside tiers 8 to 10 the seahorse levels asked 15%, 13% and 26%, subs 8 and 9 7% each, the tank's last stage 9%.
  The seahorse, sub and stage shares differ between the two runs too (stage 4: 8% then, 13% now): the auras move when each is bought.
- **Tiers 1 to 3 read high** (250%, 92%, 37%) because the first minutes are the whole time played: 1.7 to 2.9 minutes of
  income each, as the seahorse's first two levels (2.2 and 3.5).
- **An aura is always the cheaper buy** of the same number: a fifth to an eighth of the seahorse level up to tier 6, 8% at
  tier 7, 4% from tier 8. Against the sub of the same number its price climbs from 0.1% to 17%: a sub's price steps x6.7 to x15, an
  aura's about x20, and a sub is a faster way down, not Oxygen, so the shares are what keep the two level.
  Tier n is bought before seahorse level n all the way up.
- **The pace moves a little:** land 9 at 9.7 h (10.0 before), land 10 at 21.2 h (21.9 before), with the Index and the aura on
  the seahorse only. Tier 11 comes at about 62 h, tier 12 past 90.
- **Not re-run:** the Robux packs' tables. The $75T pack was fitted to Royal, Ember and Golden ($3T + $12.5T + $60T): Ember is
  now $2.5T, so it buys those three with $9.5T over.

### The short of it
1. **What a fish needs grows x7.3 a land** (theirs x5 to x8 a zone): each land's commonest fish 82, 588, 4,250, 35K,
   225K, 1.7M, 12M, 89M, 645M, **4.65B**. Every kind's base is today's times its land's factor, rounded to two
   figures and then nudged up until no two kinds need the same (e1's rule), so Hugo's order inside each land stays
   (checked: no land's order changes, all 78 needs and bases differ; land 1 is left as it was, so the Clownfish still needs 80). The top: The Devourer 58.5B, a Colossal Rainbow one
   **351B**.
2. **The seahorse, 12 levels** (Hugo's names): +16, 40, 120, 290, 760, 1,900, 4,800, 12,000, 30K, 75K, 190K, 470K a
   second (their +2, 5, 15, 36, 95 x 8, then x2.5). Prices theirs where seen: free, $15K, $250K, $4M, $80M, $2.5B,
   $75B, $3T, then x20 to $500Qa.
3. **Hugo's twelve auras, x1.5 to x12, at their prices:** $100, $5K, $75K, $1.5M, $30M, $750M, $20B, $500B, $12.5T,
   $300T, $5Qa, $100Qa *(replaced 2026-11-24 by one x20 ladder: "The aura prices", above)*. **An aura multiplies the seahorse only**, as theirs multiplies the machine only. Hugo's
   `Auras.luau` says "all Oxygen gained": if the aura multiplied the Index too, land 10 came at 7 hours.
4. **The tank's five stages at their pen's prices:** $1M, $30M, $1B, $30B, $1T (500 to 5M today).
5. **The Index:** a first catch pays 20% of the kind's need in Oxygen (at least 100) and 100 seconds of its coins; a
   land's every kind caught pays half the land's commonest need and 600 seconds of its coins. **Both numbers are fit
   to land the pace near their 30 hours, not seen:** their seen first-catch reward is about 10 to 12% of the need. A
   land's set counts only the kinds that spawn there; the Secrets have no spawn share yet, so they are left out of
   the sets (if they come into the mix later, they join their land's set).
6. **The pace it gives a free player** (35% on the seahorse, a fish home every 25 s of diving; five seeds, which
   agree within a few minutes):

| Land | Needs | Reached | Theirs, for comparison |
|---|---|---|---|
| 3 Kelp Forest | 4,250 | 5 to 6 min | the lesson is 2.5 min, two purchases |
| 5 Open Blue | 230K | 27 to 30 min | their typical player sees about an hour in all, and sticks at zones 5 to 7 |
| 6 Twilight | 1.7M | 65 to 70 min | |
| 7 Midnight | 12M | 2.4 to 2.6 h | "2 hours": 37M Stamina (x8: 300M), with some Robux; **ours has 6.8M at 2 h, about 44 times less** (no Robux in ours) |
| 8 Vents | 89M | 5.0 h | |
| 9 Bone Graveyard | 645M | 13.7 to 13.9 h | |
| 10 The Underworld | 4.65B | 31.2 h | "30 hours", free: 971M (x8: 7.8B), just taming in the last zone; ours has 4.4B at 30 h, a little over half |
| its Mythics, Secrets | 15B to 351B | 45 h at 10B, 60 h at 14B, then weeks | their top pens are Robux players' |

Bought on the way: an aura at 1 min, the second seahorse at 6, the first tank stage at 19, the x3 aura at 23; the
seahorse's 8th level at 16 hours, the 9th at 36. Coins at 30 hours: $12T to $16T (theirs $20T).

### Red fish in a row (the user's rule, 2026-11-22)
*"if you jump back on its still red. The more you jump back on the less and less time on the red you have. until its
pretty much impossible to hop off in time."* **Proposed:** the first red fish gives `Oxygen.StrainTime` (2.5 s) as
today; each red fish after it in a row gives 0.7 times the one before: 2.5, 1.75, 1.2, 0.86, 0.6, 0.42, 0.29, 0.2,
0.14, 0.1 s, with no floor, so past about the eighth it is under the hop's own lock (`Jump.StrainLock` 0.08 s) and
nobody gets off. A fish you can hold, or the surface, starts the count again. Measured in the model
(`python tools/balance/model.py --redchain 40`), a new player with 100 max Oxygen:

| Red time, each after the first | Into land 2 | Land 3 or deeper | Longest run of reds |
|---|---|---|---|
| Today (2.5 s every time), Space held | 18% | 15% reach land 10 | 725 |
| x0.75, floor 0.3 s, Space held | 20% | 2.5% reach land 10 | 736 (the floor is above the lock) |
| **x0.7, no floor, at ease** | 62% | none | 5 |
| **x0.7, no floor, Space held** | 20% | none | 11 |
| x0.5, no floor, Space held | 32% | none | 6 |

It is a `RideService` change (a count of reds in a row and the shorter strain), for the game-code chat; then a
feel check by hand.

**Built 2026-11-22 (the game-code chat):** `Oxygen.RedShrink` 0.7 (in the N panel), `Config.strainSeconds`, and
`RideService`'s `RedRun`: counted at each mount on a fish too strong, set to 0 by a fish you can hold or the Dock state (any way home),
kept through the hop and floating between. The landing's refill and the 2/3 break-off are unchanged: only the time the
rest takes shrinks (with nothing back, the second red fish would empty at once). The client is told the seconds (the
player's `StrainSeconds` attribute) for the shake and the ring's countdown. Checked in Studio with every fish red
(`TestMaxOxygen` 5, endless air off, no fail on): ten red landings in a row gave 2.5, 1.75, 1.22, 0.86, 0.60, 0.42,
0.29, 0.21, 0.14, 0.10 s; the eighth ran out before the hop; after a sandbox reset and hops at the normal max, a red
fish was back at 2.5.
No errors. Not played by hand. In a published game the press comes a round trip late, so the red fish nobody gets off
comes about the fifth or sixth, not the eighth. With endless air on no fish is too strong, so nothing shrinks.

### What else it needs (not in the play-through)
- **Selling and earning while away**, theirs: a fish sells for 200 seconds of what it earns (ours 60); away, half an
  hour of the tank's coins a day (ours none). Proposed as theirs.
- **Robux:** their late game is where Robux multipliers (x2 to x4096 on the machine) and Stamina packs sell. Our
  shop's Oxygen multiplier should sit on the seahorse the same way. **The packs are fixed amounts fitted to these
  needs and prices** (Oxygen 50K to 10B, Cash $1M to $75T, all shown to everyone: the user, 2026-11-23, "Yes, show
  all"; `Shared/Products`, [Money](money.md)). So a change to a land's needs, a seahorse or an aura price has to be
  checked against them: the Oxygen packs hold lands 4, 5, 6, 7, 9 and 10 for a new player, and $75T is the price of
  Royal, Ember and Golden less what a land 9 player has.
- **Submarine prices** (the user, 2026-11-24, to the game-code chat: "Price subs with the tuning chat, they should be
  fairly pricey"; numbers the two chats', not picked by the user one by one): $75K, $500K, $5M, $50M, $500M, $5B, $75B,
  $1T, $15T, tiers 1 to 9. Modelled (`work/hunt/v3.py` with auras added, cash spent on the cheapest thing first): each
  costs 23 to 41 min of income when its land opens (tiers 1 to 6), 45 to 90 min at tier 7, 70 to 115 at 8, 130 to 175 at 9; the
  game-code chat's first draft ($25M at tier 4 to $75B at 9) was down to 1 to 3 min from tier 6. Theirs (Jurassic
  Airlines: Desert $25M, Snow $1B, Extinction $50T, seen or said) cost hours to days of our income, so not copied.
- **Colours rarer, paying more** (the user, 2026-11-24: "Colours should be rarer and pay more. Especially rainbows"):
  Silver 1 in 20, Gold 1 in 100, Rainbow 1 in 600, an income-only x1.2, x2, x6 on top (game-code's numbers).
  Modelled: lands come within about 5% of the same times with the Index's set reward as it is, and up to 13% later
  (land 8) with it ten times larger; income within about 13% for the first hour, x1.2 to 1.8 at 10 to 20 h. A Rainbow earns x12 for x2 the need, more than the next land's plain fish (x7.3).
- **The land-set reward x10** (`Config.Index.SetOxygen` 0.5 -> 5, `SetCoinSeconds` 600 -> 2500, in the game since
  `03fa0df`, DRAFT; the user told the game-code chat to make the changes it had listed, not these numbers one by one).
  Re-run 2026-11-24 with the colours and priced subs in, medians of 5 (`rad_economy.py` now reads all three from
  `Config`). It is the set reward that moves the lands; colours and subs alone move land 10 by 0.1 h with auras:

  | | Land 7 | Land 8 | Land 9 | Land 10 | 10B Oxygen |
  |---|---|---|---|---|---|
  | With auras, before | 2.5 h | 5.0 h | 13.7 h | 31.3 h | 44 h |
  | With auras, now | 2.5 h | 4.0 h | 10.0 h | 21.9 h | 22.8 h |
  | Index, no auras (the game today), before | 4.5 h | 11.5 h | 42 h | 105 h | 176 h |
  | Index, no auras, now | 4.2 h | 7.3 h | 29 h | 67 h | 70 h |

  Theirs: 7.8B (x8) at "30 hours", so ours with auras is now a little ahead, where draft 2 was a little behind. Their
  own sets paid about 12 of the commonest's need in Plains and 2 to 8 in Extinction, so 5 is in their range.
  Nothing in the needs has to change. **The packs, checked:** none plainly wrong. $75T takes land 9 to 10 from 11.7 to
  4.6 h (was 17.6 to 6.1 h), and 38.5 to 22.8 h with no auras. The Oxygen packs hold the same lands as before.
- **Numbers past a trillion:** cash labels read Qa and Qi since `a72c1ff` (the UI chat, 2026-11-23). Full Oxygen
  figures fit by measured text width, the Oxygen row and the seahorse sign shrinking to do it, **except the player's
  own Oxygen row (`UI/StatRows`, bottom left) at 351,000,000,000**: in Studio 153 px of text in a 126 px box (the
  game-code chat, 2026-11-23). The UI chat took out the line that stopped it shrinking (`TextWrapped` false); a
  test label in Edit then fits (116 of 126), not played since. Past 9 quadrillion a Luau number is no longer exact to the coin, which only the prices reach.
- **The thresholds set in Oxygen, moved 2026-11-23:** `Oxygen.Cap` (500K would have been passed inside the first
  hour, making every tame 1.5 times slower) is 50B; `Oxygen.Grow` 0.1 (which would have hit `GrowMost` 4 at land 8)
  is 0.035: Common to Rare fish last within about 6% of before, the rarer ones less, land 1's too (Epics up to 12%,
  Legendaries 19%, Mythics 20%, Secrets 16% to 29% shorter; found by the game-code chat, 2026-11-23). Kept
  so for now (the user, 2026-11-23: "keep as is for now"); if it comes back, the way is `Config.grow` on the need
  divided by its land's factor. D5 below is not re-run.
- **The x7.3 step is between each land's most usual rarity, not within one rarity.** Where the usual rarity changes
  the same rarity steps less: Legendaries x1.6 from land 6 to 7, x2.5 from 2 to 3, x3.4 from 4 to 5.
- **The top of the seahorse is out of reach.** Full design, modelled to 1,500 h: level 10 at 101 h, 11 at 587 h, 12
  not reached. 17 of the best spawning fish (Colossal Rainbow) earn $47B a second, so $500Qa is 123 days of earning.
- **The admin panel** (Hugo's) can't give enough Oxygen or coins to test the new numbers; the game-code chat is
  putting it to the user.

### What the user and Hugo pick
| | Choice | Draft 2 | Other way |
|---|---|---|---|
| 1 | The need ladder | x7.3 a land (land 10 at 4.65B, top 351B) | x6 (`--step 6`: land 10 at 810M, reached at 16 h; top 59B; the end comes sooner) |
| 2 | Does an aura multiply the Index? | No (theirs) | Yes (Hugo's text): needs a much slower Index |
| 3 | The Index pays Oxygen | 20% of a new kind's need, half a land's for a full land (fit) | it is the late game: without it, 58 h to land 10 |
| 4 | The red rule | x0.7 a red fish in a row, no floor | x0.5 (sharper), x0.8 (softer) |
| 5 | Prices | theirs, coin for dollar | |

## The economy, draft 1 (2026-11-19): superseded by draft 2 (2026-11-22)
Hugo, 2026-11-19: *"seahorse oxygen generator, why does it go up in decimals? it should always give the same amount
then be upgradeable ... seahorse always same oxygen amount only going up on upgrades or multipliers."* The decimals
come from `Train.Share`: the pad gives 4 a second **plus 0.4% of your max**, so the number on screen is never round
and grows by itself. This draft replaces that. **A draft: no number in `Config` is changed.** Worked the same way as
B below (stretches, the tank's coins over each, a play-through); the one page of it:
[economy-draft-1.png](../attachments/economy-draft-1.png).

```
python tools/balance/model.py --economy                      the tables (--md for markdown)
python tools/balance/model.py --economy --colour B           colours that raise the need less
python tools/balance/model.py --economy --sheet docs/attachments/economy-draft-1.png
python tools/balance/model.py --economy --sit 0.25           a player who sits less (every rate x1.4)
```

### The short of it
1. **The seahorse has 12 levels, each a fixed whole number of Oxygen a tick** (a tick is a second): 6, 12, 25, 60,
   100, 600, 1,000, 2,500, 6,000, 15,000, 40,000, 80,000 on the pick (pace C). No share of max: the number on the
   sign is what you get, and it changes only when you buy a level or an aura. Prices go up 6 to 17 times a level
   early, 4 to 6 times late: $3,000 for level 2, $25M for level 6, $600B for level 12.
2. **12 auras with Hugo's multipliers**, x1.5, 2, 2.5, 3, 3.5, 4, 5, 6, 7, 8, 10, 12, bought one after another at the
   aura stand (each replaces the one before). An aura multiplies every Oxygen you gain, so the seahorse's 600 with
   the x3.5 aura is 2,100 a tick. About one aura a land, at about a third of the price of the level beside it.
3. **What a fish needs stays `Config.required`** (land x rarity: a Shallows Common 80, an Underworld Legendary 120M),
   now **times its size and colour** (D2). Being "at home" in a land here means you can tame its commonest fish.
4. **A fish earns its tag / 40 a second** (`Aquarium.PerRequired` 0.025, as now). Since size and colour scale the
   tag, a bigger or rarer-coloured fish is both harder to tame and worth exactly that much more. Every price is set
   from what the tank earns, so the prices are always reachable: a level costs under a minute to 3 minutes of the tank early,
   10 to 35 late, an hour and a half for the last level.
5. **Taming gets much slower with the need** (D5): 2 s on a Shallows Common, 10 s on a Midnight Legendary, 20 on an
   Underworld Legendary, 24 on a Mythic (today: 2, 8, 12, 12). To keep every fish tameable at its need, the deep rides
   get longer too (B).
6. **Three paces.** A = the 2026-11-16 "twice as fast", B = its "old plan", C (the pick) = A's start with B's long tail.
   The model plays each through: it lands within a tenth of the plan, a little ahead.

### D1. What a fish needs (unchanged): `Config.required`, a Normal plain fish's tag
The land's commonest rarity is in bold: the "at home" mark the paces count by.

| Land | Common | Uncommon | Rare | Epic | Legendary | Mythic | Secret |
|---|---|---|---|---|---|---|---|
| 1 Shallows | **80** | 100 | 200 | 360 | 1,200 |  |  |
| 2 Coral Reef | 320 | **400** | 800 | 1,440 | 4,800 |  |  |
| 3 Kelp Forest |  | 1,200 | **2,400** | 4,320 | 14.4K |  |  |
| 4 Shipwrecks |  | 5,000 | **10K** | 18K | 60K |  |  |
| 5 Open Blue |  | 15K | 30K | **54K** | 180K | 600K |  |
| 6 Twilight |  |  | 120K | **216K** | 720K | 2.4M |  |
| 7 Midnight |  |  | 300K | 540K | **1.8M** | 6M |  |
| 8 Vents |  |  |  | 2.16M | **7.2M** | 24M |  |
| 9 Bone Graveyard |  |  |  | 9M | **30M** | 100M |  |
| 10 The Underworld |  |  |  |  | **120M** | 400M | 1.2B |

- Being at home costs 4 to 8 times more each land, so the seahorse's rate x the aura has to grow about that much a
  land. The auras give 1.1 to 1.5 times a land; the levels the rest (1.7 to 2.7 times, and 6 at the Midnight, where
  the commonest fish turns Legendary).
- I kept these numbers: they are the riding, the tags and the coins all at once. If the deep end's billions read
  badly, that is a separate pass (it would move everything here in proportion).

### D2. Size and colour: times the need and times the coins
Sizes are `Config.SizeWorth` as it is, now read for the need as well. Colours' coins are `Aquarium.Silver/Gold/Rainbow`
as they are; for the need there is a real choice:

| | Tiny | Normal | Big | Giant | Huge | Colossal | Silver | Gold | Rainbow |
|---|---|---|---|---|---|---|---|---|---|
| Need and coins, times | 0.8 | 1 | 1.2 | 1.5 | 2 | 3 | | | |
| Coins, times | | | | | | | 1.5 | 3 | 10 |
| **Need A** (the same as the coins) | | | | | | | 1.5 | 3 | 10 |
| Need B (gentler) | | | | | | | 1.25 | 2 | 4 |
| A Common's chance | 21% | 70% | 6% | 1.9% | 0.6% | 0.14% | 1 in 12 | 1 in 50 | 1 in 250 |

| Fish | Tiny | Normal | Big | Giant | Huge | Colossal | Gold, A | Gold, B | Rainbow Colossal, A | Rainbow Colossal, B |
|---|---|---|---|---|---|---|---|---|---|---|
| Shallows Common | 64 | 80 | 96 | 120 | 160 | 240 | 240 | 160 | 2,400 | 960 |
| Kelp Forest Rare | 1,920 | 2,400 | 2,880 | 3,600 | 4,800 | 7,200 | 7,200 | 4,800 | 72K | 28.8K |
| Underworld Legendary | 96M | 120M | 144M | 180M | 240M | 360M | 360M | 240M | 3.6B | 1.44B |

- **My pick: A.** One rule a player can read off the tag: "x3 Gold" is x3 the Oxygen and x3 the coins, and a fish
  always earns its tag / 40. A Rainbow Colossal Shallows Common (2,400) is then a Kelp Forest-level catch: a trophy to
  come back for. B lets players keep a lucky colour sooner; it breaks "tag / 40".
- **It barely moves the economy** (the tank earns about 1% more on B): colours are too rare to matter to the average. The
  choice is about how the trophies feel.
- A Gold fish no longer swims faster for free: it is harder to keep, so its speed (x1.1) is now a reward, not a gift.

### D3. What a fish earns: its tag / 40 a second (`Aquarium.PerRequired` 0.025, as now)
A tank of seven: the best seven of 30 catches by a player who has just reached that land's need (sizes and colours as
far as their max lets them tame).

| Land | Commonest | Its need | One fish /s | A tank of 7 /s | A tank, a minute |
|---|---|---|---|---|---|
| 1 Shallows | Common | 80 | 2.0 | 18 | 1,050 |
| 2 Coral Reef | Uncommon | 400 | 10 | 70 | 4,200 |
| 3 Kelp Forest | Rare | 2,400 | 60 | 420 | 25.2K |
| 4 Shipwrecks | Rare | 10K | 250 | 1,750 | 105K |
| 5 Open Blue | Epic | 54K | 1,350 | 9,450 | 567K |
| 6 Twilight | Epic | 216K | 5,400 | 37.8K | 2.27M |
| 7 Midnight | Legendary | 1.8M | 45,000 | 315K | 18.9M |
| 8 Vents | Legendary | 7.2M | 180,000 | 1.26M | 75.6M |
| 9 Bone Graveyard | Legendary | 30M | 750,000 | 5.25M | 315M |
| 10 The Underworld | Legendary | 120M | 3,000,000 | 21M | 1.26B |

- **The income is not changed; the prices are set from it.** Raising `PerRequired` would only make every price
  bigger by as much. What decides "reachable but not rushed" is the price in minutes of the tank (D4): 1 to 3
  minutes early so the first buys come fast, 10 to 35 minutes late, about an hour for the last level.
- The reference's first dino earns $2 a second and so does ours.

### D4. The seahorse and the auras, on three paces
Minutes of play to tame each land's commonest fish (lands 2 to 10), then its Mythics, a Secret and a Rainbow Mythic.
Sitting on the seahorse 35% of the time (the biggest guess, as in B: at 25% every rate wants x1.4). Level n is for
stretch n; at its start a player on the plan buys level n and the next aura. A level costs 85% of what the tank earned
over the stretch before it, the aura 30%.

| Pace | Land 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | Mythics | Played through: land 10 / Mythics |
|---|---|---|---|---|---|---|---|---|---|---|---|
| A Quick (2026-11-16's "twice as fast") | 2.5 | 7.5 | 15 | 27.5 | 45 | 75 | 120 | 180 | 270 | 360 | 247 / 338 |
| B Steady (2026-11-16's "old plan") | 5 | 15 | 30 | 55 | 90 | 150 | 240 | 360 | 540 | 720 | 494 / 678 |
| **C Quick start, long tail** | 2.5 | 7.5 | 15 | 30 | 55 | 90 | 150 | 240 | 360 | 480 | 342 / 464 |

**Pace C, the pick.** The first three lands are A's (the reference's typical player sees about an hour, and lands 1
to 3 are the game for them: Findings, rank 1), so a new player buys something every few minutes. From the Open Blue it
slows to B's spacing, so the deep lands last: six hours to the Underworld, eight to its Mythics.

| Level | Seahorse | Minutes | Max Oxygen | Then tames | Oxygen a tick | x before | Aura bought with it | With the aura, a tick | Level's price | In minutes of the tank | Aura's price | Played through (min) |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 1 | Pip | 0 to 2.5 | 100 to 400 | Uncommons of land 2 | 6 |  | none | 6 | free |  |  | 2 |
| 2 | Sprout | 2.5 to 7.5 | 400 to 2,400 | Rares of land 3 | 12 | x2.0 | Bubble x1.5 | 18 | $3,000 | 0.7 | $1,000 | 7 |
| 3 | Coral Colt | 7.5 to 15 | 2,400 to 10K | Rares of land 4 | 25 | x2.1 | Foam x2 | 50 | $50K | 2.0 | $15K | 14 |
| 4 | Kelp Runner | 15 to 30 | 10K to 54K | Epics of land 5 | 60 | x2.4 | Tide x2.5 | 150 | $300K | 2.9 | $100K | 27 |
| 5 | Wreck Racer | 30 to 55 | 54K to 216K | Epics of land 6 | 100 | x1.7 | Current x3 | 300 | $4M | 7.1 | $1.5M | 52 |
| 6 | Blue Charger | 55 to 90 | 216K to 1.8M | Legendaries of land 7 | 600 | x6.0 | Reef x3.5 | 2,100 | $25M | 11.0 | $10M | 89 |
| 7 | Twilight Mare | 90 to 150 | 1.8M to 7.2M | Legendaries of land 8 | 1,000 | x1.7 | Storm x4 | 4,000 | $250M | 13.2 | $80M | 147 |
| 8 | Midnight Steed | 150 to 240 | 7.2M to 30M | Legendaries of land 9 | 2,500 | x2.5 | Moon x5 | 12,500 | $1.5B | 19.8 | $500M | 228 |
| 9 | Vent Stallion | 240 to 360 | 30M to 120M | Legendaries of land 10 | 6,000 | x2.4 | Lantern x6 | 36,000 | $8B | 25.4 | $3B | 342 |
| 10 | Bone Destrier | 360 to 480 | 120M to 400M | Mythics of land 10 | 15,000 | x2.5 | Ember x7 | 105,000 | $40B | 31.7 | $15B | 464 |
| 11 | Hellhorse | 480 to 600 | 400M to 1.2B | a Secret of land 10 | 40,000 | x2.7 | Phantom x8 | 320,000 | $150B | 35.7 | $60B | 571 |
| 12 | Abyss King | 600 to 780 | 1.2B to 4B | a Rainbow Mythic | 80,000 | x2.0 | Abyss x10 | 800,000 | $600B | 92.4 | $200B | 759 |
| | | | | | | | Leviathan x12, the last trophy | | | | $400B | |

Played through (buying the cheapest thing not yet owned as soon as the coins are there): levels 2 at 3 min, 3 at 8,
4 at 14, 5 at 31, 6 at 56, 7 at 93, 8 at 152, 9 at 238, 10 at 350, 11 at 469, 12 at 668; auras x1.5 at 2, x2 at 5,
x2.5 at 10, x3 at 22, x3.5 at 42, x4 at 72, x5 at 113, x6 at 185, x7 at 277, x8 at 391, x10 at 510, x12 at 578.

**Paces A and B** (the same twelve names and auras; only the ticks and prices differ):

| Level | A: a tick | A: price | A: aura's price | B: a tick | B: price | B: aura's price |
|---|---|---|---|---|---|---|
| 1 | 6 | free | | 3 | free | |
| 2 | 12 | $3,000 | $1,000 | 6 | $8,000 | $2,500 |
| 3 | 25 | $50K | $15K | 12 | $100K | $30K |
| 4 | 60 | $300K | $100K | 30 | $600K | $250K |
| 5 | 150 | $3M | $1M | 80 | $6M | $2M |
| 6 | 800 | $20M | $6M | 400 | $40M | $15M |
| 7 | 1,500 | $200M | $60M | 800 | $400M | $150M |
| 8 | 4,000 | $1B | $400M | 2,000 | $2B | $800M |
| 9 | 8,000 | $5B | $2B | 4,000 | $10B | $4B |
| 10 | 20,000 | $30B | $10B | 10,000 | $60B | $25B |
| 11 | 50,000 | $150B | $50B | 25,000 | $250B | $100B |
| 12 | 100,000 | $400B | $150B | 50,000 | $800B | $300B |
| Leviathan x12 | | | $250B | | | $500B |

(An aura's price is on the row of the level it is bought with: Bubble with level 2, and so on.)

- **Against 2026-11-16's B section:** the same paces give the same order of prices (level 2 $2,500 then, $3,000 now
  on A), but there are 12 levels and 12 auras where there were 10 and 4, and nothing grows by itself.
- **Why the ticks must differ by pace:** with a fixed tick, Oxygen is what sets the pace and the prices only decide
  when you can buy. A slow pace with fast ticks would let a player sit past two lands on one level.
- **The names are cooler stand-ins, by land** (Pip the starter, Coral Colt, Kelp Runner ... Hellhorse, Abyss King),
  so each level could be its own seahorse look on the plot. The auras follow the panel's Bubble, Foam, Tide.
- **What it needs to be true:** the pad's `Train.Share` goes (0) and `Train.Rate` becomes the level's tick; the
  aura multiplies the seahorse's Oxygen (and any other Oxygen gained later, such as the Index); the tank is saved.

### D5. Taming: much slower the more a fish needs
Today a tame is `Tame.Time` 2 s x the ride's grow, at most x4, and x1.5 once your max is past 500K (`Tame.CapSlow`).
The limit: a fish must last longer than its tame for a rider with exactly its need, or it can never be tamed. Both
versions make the tame a growing share of the seconds on the fish (by the log of its need, from a Shallows Common to
an Underworld Mythic), so it always fits; `Tame.CapSlow` is folded in.

- **A:** the rides as they are; the tame from 0.4 of the ride to 0.85.
- **B (the pick):** `Oxygen.Grow` 0.1 -> 0.13 and `GrowMost` 4 -> 10, so a deep fish is ridden longer; the tame
  from 0.4 of the ride to 0.65.

| Fish | Need | Ride today | Tame today | Tame A | Ride, B | Tame B |
|---|---|---|---|---|---|---|
| 1 Shallows Common | 80 | 5.0 | 2.0 | 2.0 | 5.0 | 2.0 |
| 2 Coral Reef Uncommon | 400 | 5.9 | 2.3 | 2.6 | 6.2 | 2.6 |
| 3 Kelp Forest Rare | 2,400 | 7.0 | 2.8 | 3.5 | 7.8 | 3.5 |
| 4 Shipwrecks Rare | 10K | 8.1 | 3.2 | 4.4 | 9.4 | 4.5 |
| 5 Open Blue Epic | 54K | 9.6 | 3.8 | 5.7 | 11.7 | 5.9 |
| 6 Twilight Epic | 216K | 11.0 | 4.4 | 6.9 | 14.0 | 7.4 |
| 7 Midnight Legendary | 1.8M | 13.6 | 8.2 | 9.4 | 18.4 | 10.3 |
| 8 Vents Legendary | 7.2M | 15.6 | 9.4 | 11.5 | 22.0 | 12.9 |
| 9 Bone Graveyard Legendary | 30M | 18.0 | 10.8 | 14.0 | 26.5 | 16.1 |
| 10 The Underworld Legendary | 120M | 20.0 | 12.0 | 16.3 | 31.8 | 20.0 |
| 10 The Underworld Mythic | 400M | 20.0 | 12.0 | 17.0 | 37.1 | 24.1 |

- "Today" is at the max shown; the x1.5 past 500K is in it from the Midnight on.
- **A** is only 1.15 to 1.4 times today at depth: the rides cap it. "Much slower" needs longer rides, so **B**: 1.3 to 2
  times today's tame in the deep lands, a Mythic 24 s. The price: a deep fish lasts 30 to 37 s at its need, so a dive
  there is fewer, longer rides (the 50 ticks come about 0.7 s apart). Having more than a fish needs still gives a
  little more time on it (`MaxShare`), so overtraining makes taming comfortable.
- A size or colour raises the need and so the tame: a Colossal Underworld Legendary (360M) takes about as long as a
  Mythic.

### Hugo's picks
| | Choice | Options | My pick |
|---|---|---|---|
| 1 | The pace | A quick, B steady, C quick start and long tail | C |
| 2 | Colour in the need | A as the coins (x1.5, 3, 10), B gentler (x1.25, 2, 4) | A |
| 3 | Taming | A within today's rides, B much slower with longer deep rides | B |
| 4 | Names | the twelve seahorses and auras above | stand-ins: rename freely |
| 5 | How much of the time a player sits on the seahorse | 35% assumed | check in a playtest |

## Today's rules: the fourth pass (2026-11-16)
For the refinement ([the plan](../Refinement.md), stream 9). The game changed under this note in six ways since
2026-11-12, and the model is written again for them (`tools/balance/model.py`). **Everything under this section is
the note as it stood on 2026-11-12.** Where a part no longer holds, a line under its heading says so. Nothing in
`Config` was changed in this pass: the numbers here are proposals for the game-code chat to put in with the code.

| What changed | Whose word | What it does here |
|---|---|---|
| A fish too strong gives a second and can be hopped off (`Oxygen.StrainTime` 1, `Jump.StrainLock` 0.08) | The user, 2026-11-16 | "A land is a wall" is gone. A landing on a red fish still gives the whole meter back, so red fish can be chained |
| The hop is longer (`Jump.FloatTime` 1.8, `Window` 3.5, `Launch` 1.25, `HopBoost` 30) | The user, 2026-11-16 | Off a 46 fish it is 155 studs on when the pull-in starts |
| Every fish has its own ridden speed (`Config.FishStats`) | Hugo, 2026-11-12 | Speed by rarity is gone, and my proposal of 54 to 90 with it |
| The herd swims at a share of its land's pace (`Config.LandPace`), 44 fish to 1,000 studs | Built 2026-11-16 | A rider gains more on the herd; a land's seconds move |
| A catch earns in the tank (`Config.Aquarium`) | The user, 2026-11-16 | There is something to set prices against |
| A landing no longer dips (`Ride.StartleSlow` 1, `RampTime` 0.4) | Built 2026-11-16 | A fish is at its own speed 0.4 seconds after you land |

```
python tools/balance/model.py                    the tables and the prices
python tools/balance/model.py --sim 24 --dives   the dives (about ten minutes)
python tools/balance/model.py --prices --sit 0.25 --plan 0,3,8,15,28,45,75,120,180,270
python tools/balance/model.py --sim 24 --dives --set Oxygen.RedRefill=0     try a rule that is not in the game
```

### The short of it
1. **Max Oxygen no longer decides how far down you get. It decides what you can tame, and so what you earn.** Every
   fish gives the whole meter back, red or not, and a red one gives a second to hop off. The model's new player, at
   ease and never late, chains 24 red fish and is in the Kelp Forest a minute and a half in. Holding Space they
   are in the Twilight zone, and at the end of the tenth land in 4 dives of 10. Nothing is caught past the Shallows.
2. **A first dive** is 32 seconds and three Commons for a player who stays on each fish for the ring. For one who
   rides on it is as long as they keep finding a fish inside each second: 36 seconds if they are late off one red
   fish in ten, 88 if never.
3. **A dive at home**, choosing green fish and taming: 73 seconds in the Coral Reef, 104 in the Kelp Forest, 138 in
   the Shipwrecks, 181 in the Open Blue. It ends a little past the player's own land.
4. **The bag is the first seven fish, 30 seconds in, whatever land the player is at home in.** A player at home in
   the Open Blue brings home 19 coins a second from a dive. With a bag that keeps its best seven: 2,300. The prices
   below stand on that rule (it is in the plan, stream 2).
5. **The trainer: ten levels, each 2.3 to 4 times the last, and four auras** (x1.5, x2, x2.5, x3 from lands 4, 6, 8
   and 10). A level costs about what the tank earns between two lands: 8 times the level before on average. Worked
   for the old plan and for one twice as fast.
6. **The numbers whose reasons were undone** are in the table under C. The one that matters most is not a
   number: what a landing on a red fish gives back.

### A. What a dive is now
**The lane.** 30,155 studs to ride over 10 lands (art/map/greybox/path.json); 1100 wild fish in all (Spawn.PerThousand 44, fewer where the water is narrow; Max 170 a land, MaxTotal 1100). The herd swims at 0.7 of the land's pace, plodders at 0.45, the fast ones at 1.3 (hunters at 0.75 of their own speed, high over the herd). "Ridden": the ridden speeds of the land's fish, weighted by how often each spawns.

| Land | Studs | Fish | To 1,000 studs | Land pace | The herd | Plodders | The fast | Ridden, mean | Ridden, range |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 1 Shallows | 1,001 | 29 | 29.0 | 46 | 32.2 | 20.7 | 59.8 | 45.1 | 40 to 70 |
| 2 Coral Reef | 2,844 | 91 | 32.0 | 55 | 38.5 | 24.8 | 71.5 | 50.1 | 40 to 76 |
| 3 Kelp Forest | 2,807 | 90 | 32.1 | 60 | 42.0 | 27.0 | 78.0 | 57.2 | 42 to 88 |
| 4 Shipwrecks | 3,160 | 104 | 32.9 | 65 | 45.5 | 29.2 | 84.5 | 64.0 | 46 to 96 |
| 5 Open Blue | 3,168 | 104 | 32.8 | 82 | 57.4 | 36.9 | 106.6 | 77.6 | 52 to 96 |
| 6 Twilight | 3,295 | 108 | 32.8 | 90 | 63.0 | 40.5 | 117.0 | 83.4 | 60 to 108 |
| 7 Midnight | 3,581 | 144 | 40.2 | 100 | 70.0 | 45.0 | 130.0 | 91.5 | 70 to 110 |
| 8 Vents | 3,120 | 130 | 41.7 | 104 | 72.8 | 46.8 | 135.2 | 98.8 | 72 to 122 |
| 9 Bone Graveyard | 3,837 | 160 | 41.7 | 112 | 78.4 | 50.4 | 145.6 | 103.2 | 72 to 126 |
| 10 The Underworld | 3,342 | 140 | 41.9 | 116 | 81.2 | 52.2 | 150.8 | 109.9 | 92 to 130 |

- **The sea holds 1,100 fish, not 44 to every 1,000 studs.** `Spawn.PerThousand` 44 wants 1,262; `Spawn.MaxTotal`
  1,100 trims the rest from the fullest stretches, so lands 2 to 6 have 32 or 33 to 1,000 studs. The Shallows have
  29: their water is narrow (`Spawn.ThinLeast`).
- **`Config.LandPace` holds:** a land's fish are ridden at 0.91 to 0.98 of its pace on average. Inside a land they
  run wide: 40 to 76 in the Coral Reef, 72 to 126 in the Bone Graveyard.

**The hop today.** Off a fish at its ridden speed: it leaves at speed x Jump.Launch 1.25 + HopBoost 30; the locked fish pulls you in by itself when the glide ends (LaunchTime 0.4 + FloatTime 1.8 + the air its speed adds); the window is Jump.Window 3.5 s + the same. The reach runs from GrabRange 150 at 120 studs a second down to GrabNear 60. "Gains on the herd": the studs it has made on a fish of the herd in a land of that pace when the glide ends. The last line of each pair: the same fish angry (red, or the meter low), at 0.65 of its speed.

| Fish going | Leaves at | Glide ends (s) | Studs by then | Speed then | Reach then | Gains on the herd | Window (s) | Studs at the window's end | Reach then |
|---|---|---|---|---|---|---|---|---|---|
| 40 | 80 | 1.88 | 139 | 49 | 97 | 86 | 3.18 | 165 | 60 |
| 40, angry | 62 | 1.75 | 101 | 41 | 91 | 52 | 3.05 | 124 | 60 |
| 46 | 88 | 1.94 | 155 | 53 | 100 | 93 | 3.24 | 183 | 60 |
| 46, angry | 67 | 1.79 | 111 | 43 | 93 | 54 | 3.09 | 135 | 60 |
| 60 | 105 | 2.06 | 195 | 62 | 107 | 108 | 3.36 | 228 | 60 |
| 60, angry | 79 | 1.87 | 134 | 51 | 98 | 55 | 3.17 | 162 | 60 |
| 82 | 132 | 2.26 | 267 | 73 | 115 | 137 | 3.56 | 305 | 60 |
| 82, angry | 97 | 2.00 | 175 | 58 | 104 | 61 | 3.30 | 206 | 60 |
| 100 | 155 | 2.43 | 334 | 77 | 118 | 164 | 3.73 | 373 | 60 |
| 100, angry | 111 | 2.11 | 211 | 65 | 109 | 63 | 3.41 | 245 | 60 |
| 116 | 175 | 2.57 | 393 | 87 | 125 | 184 | 3.87 | 437 | 60 |
| 116, angry | 124 | 2.20 | 245 | 69 | 112 | 66 | 3.50 | 281 | 60 |

- A hop gains 86 to 184 studs on the herd before the pull-in starts. Before the longer hop and the slower herd,
  a hop off a 46 fish gained about 50 where it gains 93 now.
- **A hop off an angry fish is a quarter to two fifths shorter.** A fish is angry when the meter is in its last 0.3, and
  from the touch when it is red. So every hop off a red fish is the short one, and so is leaving a fish late.

**A ride down the whole lane with endless air.** 6 rides, 1.8 s on each fish. Seconds in each land and the ground made a second (riding and hopping together), against the land's pace. Only rides that crossed the whole land are counted in its line.

| Land | Seconds in it | Studs a second | The land's pace | Rides that crossed it |
|---|---|---|---|---|
| 1 Shallows | 15 | 69 | 46 | 6 of 6 |
| 2 Coral Reef | 43 | 66 | 55 | 6 of 6 |
| 3 Kelp Forest | 35 | 80 | 60 | 5 of 6 |
| 4 Shipwrecks | 43 | 73 | 65 | 4 of 6 |
| 5 Open Blue | 36 | 87 | 82 | 4 of 6 |
| 6 Twilight | 32 | 104 | 90 | 4 of 6 |
| 7 Midnight | 33 | 109 | 100 | 4 of 6 |
| 8 Vents | 27 | 115 | 104 | 4 of 6 |
| 9 Bone Graveyard | 31 | 126 | 112 | 4 of 6 |
| 10 The Underworld | 25 | 132 | 116 | 4 of 6 |
| All ten | 320 | 94 |  |  |

Hops landed a ride: 52. Ended: the lane's end 4, missed every fish in a hop 2.

- All ten lands take 5 minutes 20 seconds at ease: it was about 6. The game's own log of 2026-11-16 made 76 studs a
  second through the first two lands; the model makes 66 to 69 there.

**How a dive goes today.** Endless air off. "At ease": on each fish they hold until 0.7 s are left (1.8 s at most), never hopping sooner than 0.7 s after a landing; off a red fish at 0.7 s. "Chooses green fish and tames": turns the hop to a fish they hold when one will be in reach, takes a red one only when none is, and stays on each fish they hold until it is theirs (Tame.Time 2 s) while a slot is free (Tame.Carry 7). "A bag that keeps its best seven": not built; they go on taming whatever beats the cheapest fish carried. "Space held": a hop the moment it is allowed and a grab 0.15 s in. 24 dives each. The model's rider never presses late and never misses an aim, so a dive here ends only for want of a fish. "Studs" and "Ends in land": the middle dive, the best of ten, the best. "Red landings": on a fish too strong, a dive. "Catch earns": the coins a second the dive's catch adds to a tank, sizes and colours averaged.

| Player | Max Oxygen | Rider | Lasts (s) | Studs | Ends in land | Hops landed | Red landings | Caught | Catch earns /s | Slots full | How it ended |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| a new player | 100 | at ease, takes what the lock gives | 88 | 5,870 / 10,067 / 14,335 | 3 / 5 / 6 | 27 | 23.8 | 0.0 | 0.0 | 0 of 24 | ran out on a red fish 23, rode over the next land's border and ran out 1 |
| a new player | 100 | chooses green fish and tames | 32 | 1,835 / 2,444 / 15,457 | 2 / 2 / 6 | 12 | 8.5 | 2.9 (to Common) | 6.5 | 0 of 24 | ran out on a red fish 20, missed every fish in a hop 3, rode over the next land's border and ran out 1 |
| a new player | 100 | the same, with a bag that keeps its best seven | 32 | 1,835 / 2,444 / 15,457 | 2 / 2 / 6 | 12 | 8.5 | 2.9 (to Common) | 6.5 | 0 of 24 | ran out on a red fish 20, missed every fish in a hop 3, rode over the next land's border and ran out 1 |
| a new player | 100 | Space held | 186 | 13,613 / 30,207 / 30,330 | 6 / 10 / 10 | 180 | 169.8 | 0.4 (to Common) | 0.8 | 0 of 24 | missed every fish in a hop 15, the lane's end 9 |
| at home in land 2 | 500 | at ease, takes what the lock gives | 103 | 6,894 / 11,776 / 30,152 | 4 / 5 / 10 | 34 | 24.1 | 0.0 (to Common) | 0.1 | 0 of 24 | ran out on a red fish 22, ran out waiting for a fish in reach 1, the lane's end 1 |
| at home in land 2 | 500 | chooses green fish and tames | 73 | 4,686 / 5,559 / 6,771 | 3 / 3 / 4 | 16 | 5.2 | 6.8 (to Rare) | 17.5 | 22 of 24, 30 s in | ran out on a red fish 18, missed every fish in a hop 4, ran out waiting for a fish in reach 2 |
| at home in land 2 | 500 | the same, with a bag that keeps its best seven | 80 | 4,994 / 6,880 / 9,161 | 3 / 4 / 4 | 20 | 8.2 | 7.0 (to Rare) | 42.1 | 24 of 24, 30 s in | ran out on a red fish 17, missed every fish in a hop 6, ran out waiting for a fish in reach 1 |
| at home in land 2 | 500 | Space held | 234 | 22,055 / 30,257 / 30,300 | 8 / 10 / 10 | 182 | 150.9 | 1.2 (to Uncommon) | 4.9 | 0 of 24 | missed every fish in a hop 13, the lane's end 11 |
| at home in land 3 | 3,000 | at ease, takes what the lock gives | 127 | 8,944 / 14,111 / 30,151 | 4 / 6 / 10 | 38 | 18.4 | 0.2 (to Rare) | 4.8 | 0 of 24 | ran out on a red fish 17, ran out waiting for a fish in reach 3, missed every fish in a hop 2, rode over the next land's border and ran out 1, the lane's end 1 |
| at home in land 3 | 3,000 | chooses green fish and tames | 104 | 7,275 / 8,962 / 19,576 | 4 / 4 / 7 | 25 | 6.0 | 7.0 (to Legendary) | 20.3 | 24 of 24, 30 s in | ran out on a red fish 12, missed every fish in a hop 9, ran out waiting for a fish in reach 3 |
| at home in land 3 | 3,000 | the same, with a bag that keeps its best seven | 109 | 7,357 / 9,773 / 17,765 | 4 / 4 / 7 | 29 | 9.7 | 7.0 (to Legendary) | 204 | 24 of 24, 30 s in | ran out on a red fish 17, missed every fish in a hop 5, ran out waiting for a fish in reach 2 |
| at home in land 3 | 3,000 | Space held | 260 | 30,172 / 30,257 / 30,324 | 10 / 10 / 10 | 192 | 135.8 | 3.3 (to Rare) | 60.6 | 2 of 24, 97 s in | the lane's end 15, missed every fish in a hop 9 |
| at home in land 4 | 12.5K | at ease, takes what the lock gives | 151 | 11,108 / 15,614 / 26,246 | 5 / 6 / 9 | 39 | 12.5 | 0.5 (to Rare) | 29.2 | 0 of 24 | ran out on a red fish 17, ran out waiting for a fish in reach 5, missed every fish in a hop 2 |
| at home in land 4 | 12.5K | chooses green fish and tames | 138 | 9,817 / 10,384 / 13,866 | 5 / 5 / 6 | 29 | 1.8 | 7.0 (to Rare) | 16.4 | 24 of 24, 29 s in | missed every fish in a hop 11, ran out on a red fish 9, ran out waiting for a fish in reach 4 |
| at home in land 4 | 12.5K | the same, with a bag that keeps its best seven | 144 | 10,069 / 13,792 / 16,827 | 5 / 6 / 7 | 33 | 5.9 | 6.8 (to Epic) | 470 | 23 of 24, 30 s in | ran out on a red fish 11, missed every fish in a hop 10, ran out waiting for a fish in reach 3 |
| at home in land 4 | 12.5K | Space held | 224 | 30,166 / 30,331 / 30,338 | 10 / 10 / 10 | 182 | 103.8 | 4.0 (to Epic) | 178 | 3 of 24, 101 s in | the lane's end 15, missed every fish in a hop 9 |
| at home in land 5 | 67.5K | at ease, takes what the lock gives | 203 | 15,546 / 29,893 / 30,154 | 6 / 10 / 10 | 54 | 18.0 | 0.6 (to Epic) | 105 | 0 of 24 | ran out on a red fish 15, missed every fish in a hop 3, the lane's end 3, ran out waiting for a fish in reach 2, rode over the next land's border and ran out 1 |
| at home in land 5 | 67.5K | chooses green fish and tames | 181 | 13,422 / 16,381 / 21,525 | 6 / 7 / 8 | 39 | 2.5 | 7.0 (to Rare) | 19.2 | 24 of 24, 30 s in | missed every fish in a hop 11, ran out on a red fish 9, ran out waiting for a fish in reach 3, rode over the next land's border and ran out 1 |
| at home in land 5 | 67.5K | the same, with a bag that keeps its best seven | 181 | 13,550 / 17,218 / 22,820 | 6 / 7 / 8 | 39 | 4.8 | 7.0 (to Epic) | 2,299 | 24 of 24, 30 s in | missed every fish in a hop 11, ran out on a red fish 11, ran out waiting for a fish in reach 1, rode over the next land's border and ran out 1 |
| at home in land 5 | 67.5K | Space held | 231 | 30,211 / 30,261 / 30,327 | 10 / 10 / 10 | 201 | 97.1 | 5.1 (to Epic) | 777 | 7 of 24, 111 s in | the lane's end 20, missed every fish in a hop 4 |

- **Read the "at ease" lines as an upper limit.** That rider is never late off a red fish and never aims badly. What
  ends their dive is a red fish with no other fish to reach inside its second.
- **At ease, a dive runs one or two lands past the player's own.** A new player to the Kelp Forest, a player at
  home in the Coral Reef to the Shipwrecks, one at home in the Open Blue to the Twilight zone.
- **Holding Space, anyone reaches the tenth land** in 4 to 8 dives of 10, in about four minutes.
- **Taming keeps a dive near home.** Staying 2 seconds on each fish they hold, a player's dive ends a little past
  their own land.
- **What the catch is worth depends on one rule.** The seven slots are full 30 seconds in, in the first two lands.
  As built, a tame past seven is not kept, so the dive of a player at home in the Kelp Forest adds 20 coins a
  second and one at home in the Open Blue 19. With a bag that keeps its best seven: 204 and 2,299.

**How far down a new player gets by chaining red fish.** 100 max Oxygen: every fish past the Shallows is red, gives 1 s, and today the landing gives the whole meter back. The share of 24 dives that got into each land. Nothing is caught past the Shallows. The last lines try a rule that is not in the game: a landing on a red fish gives back less (Oxygen.RedRefill in the model).

| Rider | Land 2 | Land 3 | Land 4 | Land 5 | Land 6 | Land 8 | Land 10 | The lane's end | Studs, the middle dive | Red landings | Lasts (s), mean |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Today: at ease | 100% | 58% | 38% | 25% | 4.2% | 0% | 0% | 0% | 5,870 | 23.8 | 89 |
| Today: at ease, too slow off one red fish in ten | 96% | 17% | 0% | 0% | 0% | 0% | 0% | 0% | 1,572 | 7.0 | 36 |
| Today: at ease, too slow off one in four | 96% | 4.2% | 0% | 0% | 0% | 0% | 0% | 0% | 1,504 | 4.1 | 27 |
| Today: Space held | 100% | 79% | 79% | 62% | 50% | 46% | 38% | 38% | 13,613 | 169.8 | 187 |
| If a red landing gave half the meter back: at ease | 100% | 0% | 0% | 0% | 0% | 0% | 0% | 0% | 1,402 | 2.1 | 20 |
| If a red landing gave half the meter back: Space held | 100% | 96% | 96% | 79% | 62% | 58% | 54% | 50% | 30,152 | 213.1 | 230 |
| If a red landing gave nothing back: at ease | 96% | 0% | 0% | 0% | 0% | 0% | 0% | 0% | 1,216 | 1.0 | 16 |
| If a red landing gave nothing back: Space held | 100% | 0% | 0% | 0% | 0% | 0% | 0% | 0% | 1,423 | 6.4 | 17 |

- **Today there is no end to it but a slip.** At ease and never late: 24 red fish, the Kelp Forest. Late off one red
  fish in ten: 7 red fish, 1,570 studs, 36 seconds. Holding Space: the Twilight zone in the middle dive, the lane's
  end in 4 of 10.
- **The user's words** (2026-11-16): "This allows players to sometimes get further than they can handle but they
  can't get anything real out of it still." The second half holds: nothing is tamed. Whether "sometimes" should be
  "as far as you like" is question 9.
- **If it should have an end, the rule that gives one is: a landing on a red fish gives no Oxygen back.** Then a
  player at ease gets one red fish, and one holding Space about six, 400 studs past their own land. Half the meter
  back does not do it: it stops the player at ease after two and lets the one holding Space run on, because a hop
  taken at once has spent almost nothing. It is one line in `RideService`, and not mine.
- "Best depth" measures nerve now, not Oxygen. A gate at a land's border with its Oxygen written on it (stream 7)
  would be showing a number that stops nobody.

### B. What the trainer and the auras should cost
For what the game-code chat builds next: the toy ride on each plot (Oxygen a second while you sit on it, in levels
bought with coins) and auras (a multiplier on Oxygen gained).

**How it is worked out.**
- **The pace:** minutes of play by which a player is at home in each land (2.5 seconds on its commonest fish). It is
  the user's to set (the plan's question 4). Two are worked here: the old one (5, 15, 30, 55, 90, 150, 240, 360,
  540 minutes for lands 2 to 10) and one twice as fast.
- **Sitting:** a player sits on the trainer for 35% of their play time. This is the biggest guess. Every rate is in
  proportion to one over it: at 25% the same rates take 1.4 times as long.
- **A level's rate** is what a seated second has to give over the stretch from one land to the next, with the aura
  a player on the plan has by then.
- **The tank:** a player just at home in a land has seven of the dearest fish they hold in numbers there, earning
  1.3 times the plain fish for sizes and colours. (The best seven of 14 catches earn 1.35 times; of 60, 2.1 times.)
  Between two lands the tank grows with the max Oxygen.
- **A level's price** is 1.15 times what that tank earns over the stretch before the one the level is for. Where
  an aura comes with it, the aura takes a quarter of that and the level that much less. Nothing is gated by land:
  the price is the gate.
- **Checked by playing it through** in the model: buying the cheapest thing not yet owned as soon as the coins
  are there lands within a tenth of the plan, a little ahead.

**The old plan.** At home in lands 2 to 10 by 5, 15, 30, 55, 90, 150, 240, 360 and 540 minutes.

| Stretch | Minutes | Seated (min) | Max Oxygen | Trainer | Its rate /s | x the level before | Aura | Coins /s then | Coins over the stretch | The level's price | In minutes of the tank then | The aura's price |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 1 Shallows to Coral Reef | 0 to 5 | 1.8 | 100 to 500 | Level 1 | 4 |  | x1 | 22.8 | 5,460 | free |  |  |
| 2 Coral Reef to Kelp Forest | 5 to 15 | 3.5 | 500 to 3,000 | Level 2 | 12 | x3.0 | x1 | 91 | 103K | $6,000 | 1.1 |  |
| 3 Kelp Forest to Shipwrecks | 15 to 30 | 5.2 | 3,000 to 12.5K | Level 3 | 30 | x2.5 | x1 | 546 | 829K | $100K | 3.1 |  |
| 4 Shipwrecks to Open Blue | 30 to 55 | 8.8 | 12.5K to 67.5K | Level 4 | 70 | x2.3 | x1.5 | 2,275 | 5.87M | $800K | 5.9 | $200K |
| 5 Open Blue to Twilight | 55 to 90 | 12.2 | 67.5K to 270K | Level 5 | 200 | x2.9 | x1.5 | 12.3K | 52.6M | $6M | 8.1 |  |
| 6 Twilight to Midnight | 90 to 150 | 21.0 | 270K to 2.25M | Level 6 | 800 | x4.0 | x2 | 49.1K | 497M | $50M | 17.0 | $15M |
| 7 Midnight to Vents | 150 to 240 | 31.5 | 2.25M to 9M | Level 7 | 2,000 | x2.5 | x2 | 410K | 2.21B | $600M | 24.4 |  |
| 8 Vents to Bone Graveyard | 240 to 360 | 42.0 | 9M to 37.5M | Level 8 | 5,000 | x2.5 | x2.5 | 1.64M | 11.8B | $2B | 20.4 | $600M |
| 9 Bone Graveyard to The Underworld | 360 to 540 | 63.0 | 37.5M to 150M | Level 9 | 12K | x2.4 | x2.5 | 6.83M | 73.7B | $15B | 36.6 |  |
| 10 The Underworld to its Mythics | 540 to 720 | 63.0 | 150M to 500M | Level 10 | 30K | x2.5 | x3 | 27.3M | 491B | $60B | 36.6 | $20B |

Played through, buying the cheapest thing not yet owned as soon as the coins are there: at home in land 2 at 5 min, land 3 at 15 min, land 4 at 26 min, land 5 at 53 min, land 6 at 82 min, land 7 at 147 min, land 8 at 229 min, land 9 at 342 min, land 10 at 506 min; its Mythics at 698 min. Level bought at (min): 2 at 5, 3 at 15, 4 at 29, 5 at 53, 6 at 90, 7 at 176, 8 at 236, 9 at 353, 10 at 517.

**Twice as fast.** At home in lands 2 to 10 by 2.5, 7.5, 15, 27.5, 45, 75, 120, 180 and 270 minutes. The rates
double and the prices halve (the tank earns the same a second, for half as long).

| Stretch | Minutes | Seated (min) | Max Oxygen | Trainer | Its rate /s | x the level before | Aura | Coins /s then | Coins over the stretch | The level's price | In minutes of the tank then | The aura's price |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 1 Shallows to Coral Reef | 0 to 2.5 | 0.9 | 100 to 500 | Level 1 | 8 |  | x1 | 22.8 | 2,047 | free |  |  |
| 2 Coral Reef to Kelp Forest | 2.5 to 7.5 | 1.8 | 500 to 3,000 | Level 2 | 25 | x3.1 | x1 | 91 | 51.3K | $2,500 | 0.5 |  |
| 3 Kelp Forest to Shipwrecks | 7.5 to 15 | 2.6 | 3,000 to 12.5K | Level 3 | 60 | x2.4 | x1 | 546 | 415K | $60K | 1.8 |  |
| 4 Shipwrecks to Open Blue | 15 to 27.5 | 4.4 | 12.5K to 67.5K | Level 4 | 150 | x2.5 | x1.5 | 2,275 | 2.93M | $400K | 2.9 | $100K |
| 5 Open Blue to Twilight | 27.5 to 45 | 6.1 | 67.5K to 270K | Level 5 | 350 | x2.3 | x1.5 | 12.3K | 26.3M | $3M | 4.1 |  |
| 6 Twilight to Midnight | 45 to 75 | 10.5 | 270K to 2.25M | Level 6 | 1,500 | x4.3 | x2 | 49.1K | 248M | $25M | 8.5 | $6M |
| 7 Midnight to Vents | 75 to 120 | 15.7 | 2.25M to 9M | Level 7 | 3,500 | x2.3 | x2 | 410K | 1.11B | $300M | 12.2 |  |
| 8 Vents to Bone Graveyard | 120 to 180 | 21.0 | 9M to 37.5M | Level 8 | 10K | x2.9 | x2.5 | 1.64M | 5.9B | $1B | 10.2 | $300M |
| 9 Bone Graveyard to The Underworld | 180 to 270 | 31.5 | 37.5M to 150M | Level 9 | 25K | x2.5 | x2.5 | 6.83M | 36.9B | $6B | 14.7 |  |
| 10 The Underworld to its Mythics | 270 to 360 | 31.5 | 150M to 500M | Level 10 | 60K | x2.4 | x3 | 27.3M | 245B | $30B | 18.3 | $10B |

Played through, buying the cheapest thing not yet owned as soon as the coins are there: at home in land 2 at 2 min, land 3 at 7 min, land 4 at 13 min, land 5 at 26 min, land 6 at 42 min, land 7 at 76 min, land 8 at 120 min, land 9 at 176 min, land 10 at 253 min; its Mythics at 349 min. Level bought at (min): 2 at 2, 3 at 8, 4 at 15, 5 at 26, 6 at 45, 7 at 90, 8 at 123, 9 at 178, 10 at 259.

- **Against the reference:** its first machine gives +15 a second, the next (+36) costs $4M, the one after $80M.
  The steps are alike: 2.4 times the rate for 20 times the price there, 2.3 to 4 times for 3 to 17 times here. Its
  numbers are bigger and its levels fewer: +15 a second would carry our player past the Kelp Forest by itself. We
  need a level a land because being at home costs 4 to 8 times more each land.
- **Its first dino earns $2 a second and so does ours** (a Shallows Common). Our seven-fish tank earns 23 a second
  for a new player, 550 in the Kelp Forest, 12,300 in the Open Blue, 27 million in the Underworld.
- **What it needs to be true:** the bag keeps its best seven (or players learn to hop off early fish); the tank is
  saved; the training pad is switched off (`Train.On` 0) once the trainer is in, or it undercuts every price: it
  gives 4 a second and 0.4% of your max for nothing.
- **To put in Config** (the old plan; the fast one is in the table):

| | Level 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 |
|---|---|---|---|---|---|---|---|---|---|---|
| Oxygen a second, seated | 4 | 12 | 30 | 70 | 200 | 800 | 2,000 | 5,000 | 12,000 | 30,000 |
| Price | free | 6,000 | 100K | 800K | 6M | 50M | 600M | 2B | 15B | 60B |

| Aura | x1.5 | x2 | x2.5 | x3 |
|---|---|---|---|---|
| Price | 200K | 15M | 600M | 20B |

- An aura replaces the one before it (x2 is the whole multiplier, not x1.5 times x2).
- **Not priced here:** selling, the Index's Oxygen for each new fish, earning while away, Robux. Each of them
  moves the pace and wants its own row when it is built.

### C. The numbers that are guesses again
Every number in `Config` whose reason was undone by the six changes, and three found on the way.

| Number | Today | Whose | What undid it | What I would do |
|---|---|---|---|---|
| `Oxygen.Refill` on a red landing | 1 | A rule, the game-code chat's | A red fish can be hopped off: with the whole meter back each time, red fish chain without end | The user's call (question 9). If it should end: nothing back on a red landing |
| `Oxygen.StrainTime` | 1 | Mine; the user's number | Nothing: it is the reference's second | Keep |
| `Jump.StrainLock` | 0.08 | Hugo's | It was 0.3 so a red fish could not be a stepping stone. It is one on purpose now | Keep |
| `Train.Rate`, `Train.Share` | 4, 0.004 | Mine | Coins exist: the pad gives for nothing what the trainer will sell | Replace with the trainer's levels (B). `Train.On` 0 then |
| `Aquarium.PerRequired`; `Silver`, `Gold`, `Rainbow`; `SizeWorth` | 0.025; 1.5, 3, 10; 0.8 to 3 | First numbers, mine to tune | Never set against a price | Keep. B stands on them: if one moves, the prices move in proportion |
| `Tame.Carry`, and "a tame past seven is not kept" | 7 | A rule | A catch earns now: the first seven fish of a dive are the first lands' | The bag keeps its best seven (in the plan) |
| `Tame.Time` | 2 | Mine | A fish at your bar is tamed as it throws you off | Keep, with "a fish that is yours never drowns you" (in the plan) |
| `Spawn.MaxTotal` | 1,100 | The game-code chat's | 44 to 1,000 studs wants 1,262 fish | Raise it to 1,300 if the frame time allows, or call the sea 33 to 1,000 |
| `Jump.GrabRange`, `GrabNear`, `GrabFullSpeed`; `Launch`, `HopBoost` | 150, 60, 120; 1.25, 30 | Hugo's | Tuned to a herd at 0.85 of each fish's speed. With the longer hop, a hop off a 46 fish gains 93 studs on the herd where it gained about 50 | Hugo and the user, by hand |
| `Oxygen.AngryAt` | 0.3 | Hugo's | The longer hop leans on the fish's speed as you leave: off an angry fish it is 40 to 150 studs shorter | Know it. It is a fair price for leaving late; on a red fish it is one more reason they are hard to chain |
| The speeds by rarity (`TierSpeed`, my 54 to 90) | Gone | Mine | Every fish has its own speed | Withdrawn, and question 4 with it |
| `fish.IdleSpeed` (set in `Config.refresh` as the ridden speed x `Herd.SpeedShare`) | 0.7 of its own speed | The game-code chat's | The herd swims by the land's pace now. `RideController` still eases a left fish to this number | Check what reads it |
| `Oxygen.FreeDrain` | 4 a second | Mine | Found on the way: it does not grow. A player at home in the Underworld floats for a year | A share of max each second (one line of code), about a twenty-fifth |
| `Config.SizeWorth`'s comment | "Nothing reads SizeWorth yet" | The game-code chat's | `Config.incomeOf` reads it | Fix the comment |
| "At home": 2.5 seconds on a land's commonest fish | My guess | Mine | Nothing: it still means you hold 65 to 97% of a land's fish | Keep, as the unit the pace and the prices are counted in |

**Still true from the earlier passes:** the Oxygen numbers (`ZoneDrain`, `RarityDrain`, `KeepUp`), the bar (the
number on a tag), the table of what max Oxygen means, the taming table, and each land's shares by rarity.

### Questions for the user, as they stand
| | Question | Stands |
|---|---|---|
| 1 | What is "the level"? | Open |
| 2 | The pace: how long to be at home in each land? | Open: it is the plan's question 4. B is worked for two paces. With it: how much of the time should a player sit on the trainer? |
| 3 | The training spot | Built as a stand-in; the trainer replaces it |
| 4 | Speed: 54 to 90, or 45 to 100? | Gone: every fish has its own speed |
| 5 | Holding Space | Bigger than it was: see 9 |
| 6 | A fish too strong | Answered twice: 2026-11-12 (drains at once), 2026-11-16 (a second, and you can hop off) |
| 7 | Which traits? | Built by Hugo as archetypes: Tank, Predator, Leaper, Fast, Breaker |
| 8 | A full bag keeps the best seven? | In the plan (stream 2), not built. B needs it |
| 9 | **New: should red fish chain without end?** Today a new player who holds Space reaches the tenth land in about four minutes, in 4 dives of 10. If not: a landing on a red fish gives no Oxygen back, and it is one fish at ease, about six holding Space | Settled 2026-11-22 (Decisions): red stays red, each red in a row gives less time (draft: x0.7, no floor) |

## The short version
**As it stood on 2026-11-12. Superseded 2026-11-16** by "Today's rules" above: a land is no longer a wall, the first dive is longer, speeds are by fish, and reading the tags saves a catch, not a dive.

1. **The unit is seconds on a fish, and every fish starts with the whole meter.** A new player has 2.5 seconds on a
   Shallows Common and 2 on an Uncommon. You hop or you are thrown off.
2. **A fish is held or it is not** (the user, 2026-11-12). The number on a fish's tag is the max Oxygen for 2 seconds
   on it. With less you still land, but the meter empties in a quarter of a second and the fish throws you off. So a
   land is a wall now, not a slope: a player at home in one land holds nothing in the next.
   **(Changed 2026-11-16, the user: a fish too strong gives a second and can be hopped off, so a player can go
   further than they can hold, and keep nothing from it. The numbers here were worked out for the wall.)**
3. **A new player's dive is about 15 seconds:** the Shallows, five fish long. It ends at the Coral Reef, where 100
   Oxygen holds no fish (played before the new rule: 15.6 seconds, 1,141 studs). Being at home in a land takes 4 to
   8 times the Oxygen of the land before; the training pad in the hub is what grows it.
4. **Reading the tags is the game now.** In the model a player who takes whatever fish the lock gives ends nearly
   every dive on a red one. A player who hops only to green ones almost never does.
5. **Taming is in:** 2 seconds on a fish you hold makes it yours, seven a dive. The numbers are kept. Two things
   about it want a rule, not a number: a fish right at your bar is tamed only as it throws you off, and the seven
   slots fill in the first half minute of a dive ("Taming").
6. **Hopping is faster than riding, so a fish's speed is worth less than it looks.** A rider who hops every 2
   seconds covers about one and a half times the ground the fish alone would. Holding Space covers 2 to 3 times, but
   it can no longer carry a player past their own land. Speed alone won't make fish feel different; the list under
   "What else makes a fish different" is for that.

## The Oxygen model
### How the meter behaves between fish
**Superseded in part, 2026-11-16:** a landing still refills the whole meter. What ends a dive is no longer a fish too strong: it gives a second and can be hopped off.

The user's picture: almost no time on a fish, 2 to 3 seconds on the first, so you jump from fish to fish. The
reference draws a green ring that is the time left on this dino. Three ways the meter could go when you land:

| A landing | What a new player gets | What it does to "2 to 3 seconds, then hop" |
|---|---|---|
| **refills it all** (picked) | 2.5 s on every Shallows Common, every time | Exactly that, on every fish. One number means one thing: your Oxygen is your seconds on this kind of fish. The fish's tag can show it. |
| refills a quarter (until today) | 2.5 s on the first fish, then about 0.6 s on each one after | Only the first fish is as the user describes. From the second on you are scrabbling, and how long you have depends on your last few hops, so no tag or HUD number can say it. |
| a hop also costs something | less than 2.5 s, and less each hop | It charges for the one thing the game is about. It also turns back Hugo's decision that a hop costs nothing. |

- **Picked: a landing on another fish refills the whole meter** (`Oxygen.Refill` 1). It needed no code.
- **What ends a dive then:** landing on a fish that is too strong for you, a hop that finds no fish you can hold
  before the time on your fish runs out, or missing every fish in a hop. Oxygen no longer runs down over a dive. In
  the lands you hold you ride until one of those happens; the next land stops you at its border.
- **Seconds on a fish** = your max Oxygen / (the land's number x the rarity's number): `ZoneDrain` x `RarityDrain`.
- **What the game shows as "needs":** the Oxygen for 2 seconds on the fish (`Oxygen.KeepUp` 2). Since 2026-11-12
  that number is also the bar: with less, the fish is too strong ("Hold or not").

### The numbers, applied 2026-11-11
| Number | Was | Now | Why |
|---|---|---|---|
| `Oxygen.Refill` | 0.25 | 1 | Every fish starts with the whole meter (above) |
| `Oxygen.KeepUp` | 6 | 2 | It was the seconds between landings. Now it is the seconds on a fish that count as enough, so "needs" means 2 seconds on it |
| `Oxygen.StartMax` | 100 | 100 | Kept |
| `ZoneDrain`, lands 1 to 10 | 1, 4, 14, 48, 160, 500, 1,500, 4,500, 13,000, 36,000 | 40, 160, 480, 2,000, 6,000, 24,000, 60,000, 240,000, 1,000,000, 4,000,000 | 100 Oxygen lasts 2.5 s on a Shallows Common. Each land takes 2.5 to 4 times the land before: the land is the main cost. The three smaller steps (lands 3, 5 and 7) are where the land's commonest fish also goes up a rarity |
| `RarityDrain`, Common to Secret | 1, 1.15, 1.3, 1.45, 1.6, 1.75, 1.9 | 1, 1.25, 2.5, 4.5, 15, 50, 150 | Gentle to Epic, steep from Legendary. Rare to Legendary follow the reference's required stamina in one zone (Uncommon 50, Rare 130, Epic 230, Legendary 752). Mythic and Secret are guesses |
| `Oxygen.FreeDrain` | 4 | 4 | Kept: 25 seconds afloat for a new player |

- **Checked against [Decisions](../Decisions.md):** one number a land, a steep curve, a hop never refused and free,
  out of Oxygen on a fish you are thrown off and drown. All still true.
- **The land's step was 4 falling to 2.8** (Hugo's numbers) and is 2.5 to 4 now. The reference: 5 times a zone for
  the same rarity, from one pair of readings. With the rarer fish of each deeper land, ours comes to 4 to 8 times.
  A guess to play.
- Studio starts with Endless air on, so none of this is felt until it is switched off on the N panel.

### Hold or not: a fish too strong (2026-11-12)
**Superseded 2026-11-16.** The rule is the reference's now (the user): a red fish gives one second and can be hopped off. In every table below read "too strong" as: red, one second. "The next land is a wall", "it can't be hopped off" and the dives' table no longer hold; the bar, the doors and "at home" do.

The user: "A fish shouldn't refuse landing, the landing should just drain all stamina / oxygen insanely quickly.
Stamina bar goes red etc." Built by the game-code chat ([Decisions](../Decisions.md)).

- **The rule:** a fish needs the number on its tag (`Config.required`: 2 seconds on it, by the land you land on it
  in). With that much max Oxygen you hold it. With less it is too strong: you land, the whole meter empties in
  `Oxygen.StrainTime` (0.25 seconds) and it throws you off.
- **It can't be hopped off:** the wait before the next hop is 0.3 seconds (`Jump.Cooldown`).
- **A fish you hold is not judged again at a border.** Ridden into the next land it only costs that land's drain:
  0.6 to 1 second, and then it throws you off there.
- **What it changes:** every fish gives 2 seconds or more, or a quarter of a second. The times in between are gone
  (a new player's 1 second on a Shallows Rare, half a second on a Coral Reef Common). The tags are green or red.

| Number | Value | Verdict | Why |
|---|---|---|---|
| `Oxygen.StrainTime` | 0.25 | Keep | It has to stay under `Jump.Cooldown` (0.3). In the model at 0.5, a rider holding Space hops off every red fish with the whole meter back: a new player gets 2,300 studs down in place of 900, and a player at home in the Kelp Forest can reach the Vents. If a quarter of a second reads as dying for no reason in play, the fix is a rule (no hop off a fish that is too strong); then the time can be longer |
| `Tame.Time` | 2 | Keep for now | Under "Taming" |
| `Tame.Carry` | 7 | Keep | Under "Taming" |

All three are this chat's since 2026-11-12, and rows on the N panel. No number was changed in this pass.

**Seconds on a fish with 100 max Oxygen (a new player).** Max Oxygen / (ZoneDrain x RarityDrain): how long a full meter lasts on a fish of that rarity, landed on in that land. A landing on another fish gives back the whole meter. Blank: that rarity doesn't spawn there. "Too strong": the fish needs more max Oxygen than this (the number on its tag: 2 s on it), so a landing on it empties the whole meter in Oxygen.StrainTime 0.25 s and throws you off. The hop's cooldown is 0.3 s, so it can't be hopped off. The last column: the share of the land's fish this player can hold.

| Land | Oxygen a second (Common) | Common | Uncommon | Rare | Epic | Legendary | Mythic | Secret | Fish they can hold |
|---|---|---|---|---|---|---|---|---|---|
| 1 Shallows | 40 | 2.5 | 2.0 | too strong | too strong | too strong |  |  | 96% |
| 2 Coral Reef | 160 | too strong | too strong | too strong | too strong | too strong |  |  | none |
| 3 Kelp Forest | 480 |  | too strong | too strong | too strong | too strong |  |  | none |
| 4 Shipwrecks | 2,000 |  | too strong | too strong | too strong | too strong |  |  | none |
| 5 Open Blue | 6,000 |  | too strong | too strong | too strong | too strong | too strong |  | none |
| 6 Twilight | 24K |  |  | too strong | too strong | too strong | too strong |  | none |
| 7 Midnight | 60K |  |  | too strong | too strong | too strong | too strong |  | none |
| 8 Vents | 240K |  |  |  | too strong | too strong | too strong |  | none |
| 9 Bone Graveyard | 1M |  |  |  | too strong | too strong | too strong |  | none |
| 10 The Underworld | 4M |  |  |  |  | too strong | too strong |  | none |

- A new player holds the Shallows' Commons and Uncommons: 96% of its fish. The other 4% (the Seahorse, the Reef
  Shark, Archelon) are red. Nothing past the Shallows is held.
- **The Uncommon is exactly on the bar:** 100 Oxygen against the 100 it needs. One Oxygen less (`StartMax` on the
  panel) and every Uncommon turns red.

**The bar: the max Oxygen that holds a fish.** Config.required, the number on a fish's tag: 2 s on it, by the land you land on it in. In brackets: the share of the land's fish you hold with exactly that much (that rarity and every commoner one). With less, the fish is too strong for you; with it, the fish can be tamed.

| Land | Common | Uncommon | Rare | Epic | Legendary | Mythic | Secret |
|---|---|---|---|---|---|---|---|
| 1 Shallows | 80 (74%) | 100 (96%) | 200 (99%) | 360 (100%) | 1,200 (100%) |  |  |
| 2 Coral Reef | 320 (10%) | 400 (70%) | 800 (95%) | 1,440 (99%) | 4,800 (100%) |  |  |
| 3 Kelp Forest |  | 1,200 (40%) | 2,400 (85%) | 4,320 (97%) | 14.4K (100%) |  |  |
| 4 Shipwrecks |  | 5,000 (15%) | 10K (65%) | 18K (95%) | 60K (100%) |  |  |
| 5 Open Blue |  | 15K (3.0%) | 30K (43%) | 54K (88%) | 180K (99%) | 600K (100%) |  |
| 6 Twilight |  |  | 120K (20%) | 216K (70%) | 720K (98%) | 2.4M (100%) |  |
| 7 Midnight |  |  | 300K (5.0%) | 540K (47%) | 1.8M (97%) | 6M (100%) |  |
| 8 Vents |  |  |  | 2.16M (25%) | 7.2M (95%) | 24M (100%) |  |
| 9 Bone Graveyard |  |  |  | 9M (5.0%) | 30M (92%) | 100M (100%) |  |
| 10 The Underworld |  |  |  |  | 120M (88%) | 400M (100%) |  |

- Read along a line: what each step of Oxygen opens in that land.
- **Some doors are thin.** The first fish a land lets you hold is a tenth of the Coral Reef's fish, 3% of the Open
  Blue's, 5% of the Midnight zone's and the Bone Graveyard's. A player just through such a door finds nearly every
  fish red. The number that matters is the land's commonest fish (next table).

**What max Oxygen means, land by land.** "The door": the max Oxygen that holds the land's cheapest fish, and the share of its fish that is. "Holds its commonest": the number on the commonest fish's tag (2 s on it). "At home": 2.5 s on the commonest fish (a new player's time on a Shallows Common; a guess), and the share of the land's fish held then. "HUD" is what the game shows as the land's need: the tag of a Common there. The last two: the max Oxygen that holds (and so tames) the land's Legendary and Mythic.

| Land | Commonest fish | It takes /s | The door | Holds its commonest | At home (2.5 s on it) | x the land before | Fish held at home | HUD | Its Legendary | Its Mythic |
|---|---|---|---|---|---|---|---|---|---|---|
| 1 Shallows | Common | 40 | 80 (Common, 74%) | 80 | 100 |  | 96% | 80 | 1,200 |  |
| 2 Coral Reef | Uncommon | 200 | 320 (Common, 10%) | 400 | 500 | x5.0 | 70% | 320 | 4,800 |  |
| 3 Kelp Forest | Rare | 1,200 | 1,200 (Uncommon, 40%) | 2,400 | 3,000 | x6.0 | 85% | 960 | 14.4K |  |
| 4 Shipwrecks | Rare | 5,000 | 5,000 (Uncommon, 15%) | 10K | 12.5K | x4.2 | 65% | 4,000 | 60K |  |
| 5 Open Blue | Epic | 27K | 15K (Uncommon, 3.0%) | 54K | 67.5K | x5.4 | 88% | 12K | 180K | 600K |
| 6 Twilight | Epic | 108K | 120K (Rare, 20%) | 216K | 270K | x4.0 | 70% | 48K | 720K | 2.4M |
| 7 Midnight | Legendary | 900K | 300K (Rare, 5.0%) | 1.8M | 2.25M | x8.3 | 97% | 120K | 1.8M | 6M |
| 8 Vents | Legendary | 3.6M | 2.16M (Epic, 25%) | 7.2M | 9M | x4.0 | 95% | 480K | 7.2M | 24M |
| 9 Bone Graveyard | Legendary | 15M | 9M (Epic, 5.0%) | 30M | 37.5M | x4.2 | 92% | 2M | 30M | 100M |
| 10 The Underworld | Legendary | 60M | 120M (Legendary, 88%) | 120M | 150M | x4.0 | 88% | 8M | 120M | 400M |

- **"At home" is still my guess:** 2.5 seconds on a land's commonest fish, the feel a new player has in the
  Shallows. It now also means something the game draws itself: you hold the commonest fish and every commoner one,
  65 to 97% of the land's fish, with half a second over the bar.
- Being at home takes 4 to 6 times the land before, and 8 times at the Midnight zone, where Legendaries become the
  common fish.
- **Where "at home" is thin:** the Coral Reef (70% of its fish held), the Shipwrecks (65%) and the Twilight zone
  (70%). A third of the fish there are red, and a dive is cut short for want of a green one (the dives, below).
- **The HUD's number for a land** counts a Common there. No Common swims past the Coral Reef, so from the Kelp
  Forest on it is less than the door: 960 for the Kelp Forest, where nothing is held under 1,200.
- To try a land in Studio: set Workspace's `TestMaxOxygen` to the "at home" number (500, 3,000, 12,500 ...).

**Seconds on a fish for a player at home in each land.** A player whose max Oxygen gives 2.5 s on that land's commonest fish: their time on each rarity there, the share of the fish they hold in the land before and the land after, and their time on the fish they rode in on once it is over the next land's border (a fish you hold is not judged again at a border: it only costs the new land's drain).

| At home in | Max Oxygen | Common | Uncommon | Rare | Epic | Legendary | Mythic | Secret | Held in the land before | Held in the land after | Over the border on their commonest (s) |
|---|---|---|---|---|---|---|---|---|---|---|---|
| 1 Shallows | 100 | 2.5 | 2.0 | too strong | too strong | too strong |  |  |  | none | 0.62 |
| 2 Coral Reef | 500 | 3.1 | 2.5 | too strong | too strong | too strong |  |  | 100% | none | 0.83 |
| 3 Kelp Forest | 3,000 |  | 5.0 | 2.5 | too strong | too strong |  |  | 99% | none | 0.60 |
| 4 Shipwrecks | 12.5K |  | 5.0 | 2.5 | too strong | too strong |  |  | 97% | none | 0.83 |
| 5 Open Blue | 67.5K |  | 9.0 | 4.5 | 2.5 | too strong | too strong |  | 100% | none | 0.62 |
| 6 Twilight | 270K |  |  | 4.5 | 2.5 | too strong | too strong |  | 99% | none | 1.0 |
| 7 Midnight | 2.25M |  |  | 15 | 8.3 | 2.5 | too strong |  | 98% | 25% | 0.62 |
| 8 Vents | 9M |  |  |  | 8.3 | 2.5 | too strong |  | 100% | 5.0% | 0.60 |
| 9 Bone Graveyard | 37.5M |  |  |  | 8.3 | 2.5 | too strong |  | 100% | none | 0.62 |
| 10 The Underworld | 150M |  |  |  |  | 2.5 | too strong |  | 100% |  |  |

- **The next land is a wall.** At home in a land you hold nothing in the next one. (Two exceptions, by the numbers'
  luck: a quarter of the Vents' fish from the Midnight zone, a twentieth of the Bone Graveyard's from the Vents.)
  Before the new rule you had half a second on its fish and could scramble in.
- The lands before are a rest: you hold 97% or more of their fish, for 10 seconds or more each.
- **The chase is still in every land:** at home there, its rarer fish are red (a Legendary in the first six lands, a
  Mythic from the fifth on). You come back for them from a land or two further on (the table under "Taming").

**How far a max Oxygen gets** (the model's dives). Endless air off. Each line is a player and a way of riding. "At ease": on each fish until 0.7 s are left (1.8 s at most), never hopping sooner than 0.7 s after a landing, onto the fish the lock gives (about 60 studs ahead). "Reads the tags": only fish they can hold (the green tags), waiting on their fish for one. "And tames": stays on each fish they hold until it is theirs (Tame.Time 2 s), while a slot is free (Tame.Carry 7). "Space held": a hop the moment the cooldown ends and a grab at once, only fish that give 0.4 s or more. 40 dives each. "On a fish too strong": dives that ended by landing on one, and how many of those were before the next land's door (in the lands the player can hold). "Caught": fish brought home a dive, and the rarest of them in any dive. "Slots full": dives that filled every slot, and the seconds into the dive when they did.

| Player | Max Oxygen | Rider | Lasts (s) | Studs | Ends in land | On a fish too strong | Hops landed | Caught | Slots full | How it ended |
|---|---|---|---|---|---|---|---|---|---|---|
| a new player | 100 | at ease | 16 | 1,020 | 1 to 2 | 35 of 40, 2 before the door | 4 | 0.1 (to Common) | 0 of 40 | landed on a fish too strong for them 35, no fish in reach before the time ran out 5 |
| a new player | 100 | at ease, reads the tags | 15 | 956 | 1 to 2 | 9 of 40, 0 before the door | 3 | 0.6 (to Uncommon) | 0 of 40 | no fish in reach before the time ran out 20, rode over the next land's border and ran out there 11, landed on a fish too strong for them 9 |
| a new player | 100 | reads the tags and tames | 12 | 758 | 1 to 2 | 2 of 40, 0 before the door | 2 | 3.2 (to Uncommon) | 0 of 40 | thrown off the fish they had just made theirs 32, rode over the next land's border and ran out there 6, landed on a fish too strong for them 2 |
| a new player | 100 | Space held | 9 | 911 | 1 to 2 | 17 of 40, 0 before the door | 7 | 0.3 (to Uncommon) | 0 of 40 | landed on a fish too strong for them 17, rode over the next land's border and ran out there 14, no fish in reach before the time ran out 9 |
| at home in land 2 | 500 | at ease | 36 | 2,349 | 2 to 3 | 38 of 40, 36 before the door | 9 | 0.2 (to Uncommon) | 0 of 40 | landed on a fish too strong for them 38, no fish in reach before the time ran out 1, rode over the next land's border and ran out there 1 |
| at home in land 2 | 500 | at ease, reads the tags | 45 | 2,937 | 2 to 3 | 0 of 40, 0 before the door | 10 | 1.1 (to Uncommon) | 0 of 40 | no fish in reach before the time ran out 35, rode over the next land's border and ran out there 5 |
| at home in land 2 | 500 | reads the tags and tames | 45 | 2,875 | 2 to 3 | 2 of 40, 1 before the door | 10 | 6.8 (to Rare) | 38 of 40, 28 s in | no fish in reach before the time ran out 29, rode over the next land's border and ran out there 6, thrown off the fish they had just made theirs 3, landed on a fish too strong for them 2 |
| at home in land 2 | 500 | Space held | 22 | 2,091 | 2 to 3 | 4 of 40, 2 before the door | 15 | 1.3 (to Uncommon) | 0 of 40 | no fish in reach before the time ran out 34, landed on a fish too strong for them 4, rode over the next land's border and ran out there 2 |
| at home in land 3 | 3,000 | at ease | 74 | 5,012 | 2 to 4 | 29 of 40, 23 before the door | 17 | 1.1 (to Epic) | 0 of 40 | landed on a fish too strong for them 29, no fish in reach before the time ran out 9, rode over the next land's border and ran out there 2 |
| at home in land 3 | 3,000 | at ease, reads the tags | 88 | 5,923 | 3 to 4 | 1 of 40, 0 before the door | 20 | 1.9 (to Epic) | 0 of 40 | no fish in reach before the time ran out 27, rode over the next land's border and ran out there 12, landed on a fish too strong for them 1 |
| at home in land 3 | 3,000 | reads the tags and tames | 83 | 5,580 | 3 to 4 | 3 of 40, 0 before the door | 19 | 7.0 (to Rare) | 40 of 40, 28 s in | no fish in reach before the time ran out 27, rode over the next land's border and ran out there 10, landed on a fish too strong for them 3 |
| at home in land 3 | 3,000 | Space held | 55 | 5,251 | 2 to 4 | 3 of 40, 1 before the door | 37 | 2.8 (to Epic) | 0 of 40 | no fish in reach before the time ran out 31, rode over the next land's border and ran out there 6, landed on a fish too strong for them 3 |
| at home in land 5 | 67.5K | at ease | 151 | 10,841 | 4 to 6 | 16 of 40, 10 before the door | 34 | 3.2 (to Legendary) | 1 of 40, 140 s in | no fish in reach before the time ran out 24, landed on a fish too strong for them 16 |
| at home in land 5 | 67.5K | at ease, reads the tags | 157 | 11,226 | 4 to 6 | 1 of 40, 0 before the door | 35 | 3.6 (to Legendary) | 1 of 40, 154 s in | no fish in reach before the time ran out 33, rode over the next land's border and ran out there 6, landed on a fish too strong for them 1 |
| at home in land 5 | 67.5K | reads the tags and tames | 166 | 11,872 | 4 to 6 | 1 of 40, 0 before the door | 37 | 7.0 (to Legendary) | 40 of 40, 28 s in | no fish in reach before the time ran out 29, rode over the next land's border and ran out there 10, landed on a fish too strong for them 1 |
| at home in land 5 | 67.5K | Space held | 115 | 11,261 | 4 to 6 | 6 of 40, 1 before the door | 75 | 4.7 (to Epic) | 10 of 40, 94 s in | no fish in reach before the time ran out 26, rode over the next land's border and ran out there 8, landed on a fish too strong for them 6 |

- **A new player: about 15 seconds,** as before. The Shallows in four or five hops, and the first landing in the
  Coral Reef throws them off. About one first dive in twenty ends sooner, on one of the Shallows' red fish.
- **Taking what the lock gives ends on a red fish.** At home in the Coral Reef: 38 dives of 40, 36 of them inside
  the lands the player holds. At home in the Kelp Forest 29 of 40, in the Open Blue 16 of 40. Before the new rule it
  was about a quarter of dives, and a quick hop could save you.
- **Reading the tags, it almost never happens** (0 or 1 dive of 40 for a trained player). What ends a dive then is a hop that finds no
  green fish in reach before the time on the fish runs out: about one hop in twelve at home in the Coral Reef, one
  in thirty to forty in the Kelp Forest and the Open Blue. So a dive at home lasts 45 seconds in the Coral Reef, a
  minute and a half in the Kelp Forest and two and a half minutes in the Open Blue, and the number of fish in the
  lane (`Spawn.PerThousand`, the game-code chat's) sets it.
- **Nobody gets past their wall.** Some dives ride a held fish over the next land's border (5 to 12 of 40) and end
  a second later.
- **Holding Space** is the fast way down and no longer the far way: it gets no further than a rider at ease, only
  there sooner.

### The first dive, played, and what it means
**Superseded 2026-11-16:** played on the rules of 2026-11-11. A first dive today is under "Today's rules", A.

The game-code chat rode it with the real rules on 100 Oxygen (2026-11-11): 2.5 seconds on a Common and 2.0 on an
Uncommon, as the table says; each landing refilled the meter; a hop took 2.4 seconds and carried about 180 studs; the
dive ended 15.6 seconds in, 1,141 studs down, on a Common 100 studs into the Coral Reef.

- **The first version of this note said 35 to 45 seconds. That was the model's fault, in two places.** Its rider
  hopped again 0.3 seconds after every landing in the Coral Reef, where a fish gives half a second: no player at ease
  does that. And its hop was 20 studs short (the pop holds its speed longer than I had it). Both are corrected: a
  rider at ease now needs 0.7 seconds on a fish before hopping, and the model's hop is 176 studs in 2.4 seconds.
- **What 15 seconds means.** The Shallows are 1,009 studs and a hop covers 180, so the whole first land is five
  fish, about 7 seconds of it on a fish. A new player sees the Shallows' fish and nothing else: a Rare within reach
  every other dive, an Epic or a Legendary almost never.
- **Since the hold-or-not rule (2026-11-12)** the first dive is the same length for a new reason: 100 Oxygen holds
  no fish in the Coral Reef, so the first landing there ends it.
- **That is short, and it can work, if each of those dives gives something.** Taming exists now: in the model a new
  player who stays on each fish until the ring fills brings home about three fish from a first dive, Commons mostly.
  And the first training step has to come in the first two or three minutes, so the 15-second dive is the first few
  dives and not the first half hour.
- **If the user wants a longer first dive, there are two places left to get it,** neither touching the 2.5 seconds
  on the first fish: a longer first land (the map's: the other lands are 2,800 to 3,800 studs), or the pace of the
  first training. The third, a softer step into the Coral Reef, no longer works: under the hold-or-not rule a new
  player gets into the Reef only if its Commons need 100 Oxygen or less, and then the Reef costs hardly more than
  the Shallows. No number is changed for this: it waits for the user's answer on the pace (question 2).

## What the HUD should show
**2026-11-16:** the strain lasts a second now, not a quarter. The rest stands.

For the UI chat. The unit a player should read is **seconds on a fish**; max Oxygen is the one big number they train.

| On screen | The number | Unit | In the game, or proposed |
|---|---|---|---|
| The meter while riding | The time left on this fish: Oxygen left / what this fish takes a second here (`Config.drain` of the land you are in and the fish's rarity) | A ring or bar that empties; seconds beside it if there is room (2.5, then 0.8) | In the game: it is full at every landing on another fish, and empties at the fish's rate. A crash takes a tenth of it, a prop 3%. On a fish too strong it empties in a quarter of a second (the player's `Strained` attribute): the user's red bar |
| In the hop | Nothing drains | The meter holds still | In the game |
| Your max Oxygen | The stat you train | One number, short past 10,000 (12.5K, 2.25M, 150M) | In the game (the short form is proposed) |
| A wild fish's tag | The Oxygen for 2 seconds on it (`Config.required` of its land and rarity) | Oxygen, in the same short form, so it compares with your max | In the game. Since the UI chat's piece 3 (2026-11-12) the tag shows `Config.required` of the land the fish swims in now, which is the bar the server judges by. Before that it showed the fish's home land's number, 2.5 to 17 times too little on a fish that had swum a land or two on |
| A fish you can't hold | Whether your max is under its tag's number (`State.tooStrong(fish)`) | Red on its tag; green on one you hold | Built by the UI chat, 2026-11-12: tags on the nearest wild fish, and "holds N s" on the locked fish in the hop. Since the hold-or-not rule a fish gives 2 seconds or more, or a quarter of a second, so the yellow (half a second to 2) is never shown. Nothing is marked while you ride (`Lock.Preview` 0, as the reference). A landing is never stopped (the user, 2026-11-12) |
| The land's line | The Oxygen that holds the land's commonest fish, shown while yours is under it | Oxygen, short form | Proposed. Today it counts a Common, and no Common swims past the Coral Reef |
| Oxygen a second | Not needed | | Today's HUD shows it. Seconds left says the same thing in the unit the player feels |

- "Enough" is 2 seconds (`Oxygen.KeepUp`), and since 2026-11-12 it is the bar: under it a fish is too strong. "At
  home" in a land, 2.5 seconds on its commonest fish, is my guess and not a rule of the game.
- The numbers get large: the tenth land's common fish takes 60 million a second. Seconds stay small at every depth,
  which is one more reason to show them.

## Speed, for a rider who hops all the time
**Superseded 2026-11-16,** all of it. Every fish has its own speed (`Config.FishStats`), the hop and the herd are different, and the proposal of 54 to 90 is withdrawn. Today's speeds, hop and pace are under "Today's rules", A.

**By rarity.** A wild fish swims at Herd.SpeedShare 0.85 of its ridden speed. The hop off a fish: the pop at Jump.Launch 1.6 times the ridden speed, the glide at AirShare 0.85 of it, and the pull-in begins 1.7 s after the press.

| Rarity | Ridden | Step up | Wild (herd) | Pop | Glide | Hop carries (studs) | and gains on its own herd | Drain x | View widens (deg) | Turn circle (studs across) | Lands |
|---|---|---|---|---|---|---|---|---|---|---|---|
| Common | 45 |  | 38.2 | 72 | 38.2 | 89 | 24 | 1 | 4.4 | 54 | 1, 2 |
| Uncommon | 52 | +16% | 44.2 | 83 | 44.2 | 103 | 28 | 1.25 | 5.6 | 63 | 1, 2, 3, 4, 5 |
| Rare | 60 | +15% | 51.0 | 96 | 51.0 | 119 | 32 | 2.5 | 7.0 | 72 | 1, 2, 3, 4, 5, 6, 7 |
| Epic | 68 | +13% | 57.8 | 109 | 57.8 | 135 | 36 | 4.5 | 8.4 | 82 | 1, 2, 3, 4, 5, 6, 7, 8, 9 |
| Legendary | 78 | +15% | 66.3 | 125 | 66.3 | 154 | 42 | 15 | 10.2 | 94 | 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 |
| Mythic | 90 | +15% | 76.5 | 144 | 76.5 | 178 | 48 | 50 | 12.2 | 109 | 5, 6, 7, 8, 9, 10 |
| Secret | 100 | +11% | 85.0 | 160 | 85.0 | 198 | 53 | 150 | 14.0 | 121 | nowhere |

**The pace.** Studs a second all told, sitting 1.8 s on each fish. "Near": pulled onto a fish 60 studs ahead when the glide ends (what the lock gives); "far": 110 studs ahead (reach is Jump.GrabRange 130). "Space held": 0.3 s on each fish and a grab 0.15 s into the hop, onto a fish 110 ahead. The target is a fish of the same rarity.

| Riding | Ridden speed | Hopping, near | Hopping, far | x riding | Space held, far | x riding | Share of the time on a fish |
|---|---|---|---|---|---|---|---|
| Common | 45 | 62 | 74 | x1.64 | 141 | x3.14 | 43% |
| Uncommon | 52 | 69 | 81 | x1.56 | 148 | x2.85 | 43% |
| Rare | 60 | 78 | 89 | x1.49 | 156 | x2.61 | 43% |
| Epic | 68 | 86 | 98 | x1.44 | 165 | x2.42 | 43% |
| Legendary | 78 | 97 | 108 | x1.39 | 175 | x2.24 | 43% |
| Mythic | 90 | 109 | 121 | x1.35 | 187 | x2.08 | 43% |
| Secret | 100 | 120 | 132 | x1.32 | 197 | x1.97 | 43% |

- **Hopping is faster than riding.** The pop is 1.6 times the ridden speed, and the pull-in covers up to 130 studs in
  0.7 seconds. Under half a hopping rider's time is on a fish; the rest moves faster.
- **Holding Space is 2 to 3 times any fish's speed.** Until 2026-11-12 it also carried a player a land past their
  Oxygen, on 0.3 seconds a fish. The hold-or-not rule ended that: a fish gives 2 seconds or more, or it throws you
  off. Holding Space is now only the fast way down, so question 5 is smaller than it was. The number is
  `Jump.Cooldown`, not mine.

**The ladder.** Studs a second gained on a wild fish ahead. First number: hopping to near fish; second: to far ones. Negative: the wild fish pulls away, and can only be caught if it starts within reach or comes up from behind. (Only riding, never hopping: the ridden speed minus the wild pace, which is +1 or +2 on the next rarity up and negative beyond.)

| Riding a \ wild | Common | Uncommon | Rare | Epic | Legendary | Mythic | Secret |
|---|---|---|---|---|---|---|---|
| Common | +23 / +35 | +18 / +29 | +11 / +23 | +4 / +16 | -5 / +7 | -15 / -3 | -23 / -11 |
| Uncommon | +31 / +43 | +25 / +37 | +18 / +30 | +11 / +23 | +3 / +15 | -7 / +5 | -16 / -4 |
| Rare | +39 / +51 | +33 / +45 | +27 / +38 | +20 / +32 | +11 / +23 | +1 / +13 | -7 / +4 |
| Epic | +48 / +60 | +42 / +54 | +35 / +47 | +28 / +40 | +20 / +32 | +9 / +21 | +1 / +13 |
| Legendary | +58 / +70 | +52 / +64 | +46 / +57 | +39 / +51 | +30 / +42 | +20 / +32 | +12 / +23 |
| Mythic | +71 / +83 | +65 / +77 | +58 / +70 | +51 / +63 | +43 / +55 | +33 / +45 | +24 / +36 |
| Secret | +81 / +93 | +76 / +87 | +69 / +81 | +62 / +74 | +53 / +65 | +43 / +55 | +35 / +47 |

- Riding only, the next rarity up could never be caught. Hopping as the lock gives, a rider on Commons gains 11
  studs a second on a Rare and 4 on an Epic; aiming the hop far, 23 and 16. **Rarer fish ahead can be caught now.**
  Catching one is only worth it if you hold it.

**The lane.** 30,164 studs to ride over 10 lands (art/map/greybox/path.json); 720 wild fish in all (Spawn.PerThousand 24, MaxTotal 800). "Hopping" is a rider on the land's commonest fish who sits 1.8 s on each and hops to one about 60 studs ahead.

| Land | Studs | Width | Fish | Commonest fish | s riding it | s hopping | s at Common (45) | s at Uncommon (52) | s at Rare (60) | s at Epic (68) | s at Legendary (78) | s at Mythic (90) | s at Secret (100) |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 1 Shallows | 1,009 | 143 to 248 | 24 | Common | 22 | 16 | 22 | 19 | 17 | 15 | 13 | 11 | 10 |
| 2 Coral Reef | 2,846 | 156 to 432 | 68 | Uncommon | 55 | 41 | 63 | 55 | 47 | 42 | 36 | 32 | 28 |
| 3 Kelp Forest | 2,807 | 203 to 520 | 67 | Rare | 47 | 36 | 62 | 54 | 47 | 41 | 36 | 31 | 28 |
| 4 Shipwrecks | 3,160 | 243 to 585 | 75 | Rare | 53 | 41 | 70 | 61 | 53 | 46 | 41 | 35 | 32 |
| 5 Open Blue | 3,168 | 279 to 621 | 76 | Epic | 47 | 37 | 70 | 61 | 53 | 47 | 41 | 35 | 32 |
| 6 Twilight | 3,295 | 279 to 691 | 79 | Epic | 48 | 38 | 73 | 63 | 55 | 48 | 42 | 37 | 33 |
| 7 Midnight | 3,581 | 354 to 859 | 85 | Legendary | 46 | 37 | 80 | 69 | 60 | 53 | 46 | 40 | 36 |
| 8 Vents | 3,120 | 354 to 866 | 74 | Legendary | 40 | 32 | 69 | 60 | 52 | 46 | 40 | 35 | 31 |
| 9 Bone Graveyard | 3,837 | 394 to 940 | 92 | Legendary | 49 | 40 | 85 | 74 | 64 | 56 | 49 | 43 | 38 |
| 10 The Underworld | 3,342 | 478 to 966 | 80 | Legendary | 43 | 35 | 74 | 64 | 56 | 49 | 43 | 37 | 33 |
| All ten | 30,164 |  | 720 |  | 450 | 353 | 670 | 580 | 503 | 444 | 387 | 335 | 302 |

- All ten lands take about 6 minutes hopping, 7.5 only riding. A land is 35 to 40 seconds; the Shallows 16.

### What a rarity's speed is worth, and the proposal
- **Worth:** a rider's pace follows the fish under them, so a Legendary still gets you down about 1.5 times as fast
  as a Common. But the hop adds 17 to 30 studs a second to everyone, so the gap is smaller than the ridden
  speeds say (45 against 78 becomes 62 against 97).
- **Felt:** with 2.5 seconds on a fish, 1.2 of them are the fish coming up to speed. The ridden speed is felt mostly
  in the hop it gives: a Common throws you 89 studs before the pull-in, a Legendary 154.

| Rarity | Today | Proposed | Why |
|---|---|---|---|
| Common | 45 | 54 | The reference's ride, measured through one jump: 54 riding, 46 floating. Our glide is 0.85 of the ridden speed, so it goes from 38 to 46. Hugo found the air too slow at 38 |
| Uncommon | 52 | 58 | Small steps at the bottom: a new player's herd stays together, so there is always a fish to hop to |
| Rare | 60 | 62 | |
| Epic | 68 | 67 | |
| Legendary | 78 | 74 | Bigger steps at the top, where the thrill belongs |
| Mythic | 90 | 82 | |
| Secret | 100 | 90 | No Secret spawns yet |

- **What changes:** the Shallows go from 16 to 14 seconds, the deep lands slow a little, the whole lane stays about
  6 minutes. The first Epic comes within reach after about 37 seconds in place of 49 (the model, 30 dives each way).
- **A guess to play.** The reference's 54 is one jump, and it takes one of its metres for one of our studs.
- **Status:** not applied. The seven speeds are rows on the N panel (`TierSpeed`).
- **Withdrawn from the first pass:** "rarer fish can't be caught" (true only for a rider who never hops), and "the
  hop off a Secret overshoots" (it gains 28 studs on its own herd, which is fine).

## What else makes a fish different
The user: "different things we could also add that would make them different. That's not just speed." Eight traits a
fish could have, each using something the game already has.

| Trait | What the player feels | To build | In the reference? |
|---|---|---|---|
| **Staying power** | Some fish are calm and you sit long; some buck and you get a second | One number a creature beside its rarity; three lines of code | Its sizes do it: a Tiny dino needs 0.8 of the stamina, a Giant 1.5 |
| **Speed by kind** | A shark is quick, a turtle is slow, whatever their rarity | A number: each fish can already carry its own speed (`RiddenSpeed`) | Not seen |
| **The hop it gives** | A flying fish throws you high and far; a ray gives a long flat glide | One or two numbers a creature; small code in the hop | Not seen |
| **Smash or crash** | A big creature ploughs through coral and wrecks; a small one bounces off and loses speed | One number today (`Props.MinLength`): nothing to build | Its props are built to collapse when a big dino hits them |
| **How it turns** | An eel snaps round; a whale needs room | One number a creature; small code in the steering | Not seen |
| **Where it swims** | Rays low over the sand, flying fish near the top, sharks through the middle | Two numbers a creature; small code in the spawner | Not seen (its ground is flat) |
| **How it behaves wild** | A school of the same fish to hop along; a loner that darts | Schools: small code (spawn a few together). Darting: a new piece | It has herds of one kind |
| **What a landing gives** | Landing on some fish gives a burst of speed | One number a creature (`Ride.Surge` is one number for all today); small code | Not seen |

Later, with their own systems: how long a fish takes to tame, and what it earns.

**Recommended, for the most difference and the least building:**
1. **Smash or crash, by size.** Set `Props.MinLength` to about 15 studs. Small reef fish bounce off props; sharks,
   rays, eels and every giant go through them. Nothing to build, and it makes a big fish feel big at once.
2. **Fast and short against slow and long, by kind.** Speed by kind and staying power together. Sharks and the
   torpedo fish (Barracuda, Swordfish, Flying Fish): faster, and they take more Oxygen. Turtles, rays, whales and
   the puffers: slower, and you sit longer. So a Sea Turtle is the fish a new player rests on, and a Reef Shark is a
   sprint. This is the note in [the dive](the-dive.md): "a small creature lasts but crawls; a Megalodon tears down
   but burns through your Oxygen".
3. **The hop it gives, for a few leapers.** Flying Fish, Dolphin, Swordfish, Manta Ray: a higher, longer hop. The
   hop is most of a dive now, so this is the trait a player feels most.
4. **Schools, for Commons and Uncommons.** Three to five of one kind together. It reads as a living sea and gives a
   new player a row of safe fish.

**Who gets what:** a Common has no trait (it is the plain fish). An Uncommon has one mild one. A Rare has one strong
one. An Epic and up has two, and always smashes. Each Legendary keeps one thing only it does.

## How often each rarity spawns
**2026-11-16:** the shares by rarity stand. The counts of fish and "what a rider meets" are from a sea of 24 to 1,000 studs with the old herd; today's are under "Today's rules", A.

No share was changed.

**Wild fish by land and rarity.** The share each rarity really gets (a rarity with no creature in the land is skipped and the others share it out), and the fish of it standing in the land at once. "1 in" is how many crossings of the land it takes to have one of that rarity in it.

| Land | Fish | Common | Uncommon | Rare | Epic | Legendary | Mythic | Secret |
|---|---|---|---|---|---|---|---|---|
| 1 Shallows | 24 | 74%, 17.8 | 22%, 5.3 | 3.2%, 0.8 | 0.6%, 0.1 (1 in 7) | 0.2%, 0.0 (1 in 21) |  |  |
| 2 Coral Reef | 68 | 10%, 6.8 | 60%, 40.8 | 25%, 17.0 | 4.0%, 2.7 | 1.0%, 0.7 |  |  |
| 3 Kelp Forest | 67 |  | 40%, 26.8 | 45%, 30.2 | 12%, 8.0 | 3.0%, 2.0 |  |  |
| 4 Shipwrecks | 75 |  | 15%, 11.2 | 50%, 37.5 | 30%, 22.5 | 5.0%, 3.8 |  |  |
| 5 Open Blue | 76 |  | 3.0%, 2.3 | 40%, 30.4 | 45%, 34.2 | 11%, 8.4 | 1.0%, 0.8 |  |
| 6 Twilight | 79 |  |  | 20%, 15.8 | 50%, 39.5 | 28%, 22.1 | 2.0%, 1.6 |  |
| 7 Midnight | 85 |  |  | 5.0%, 4.2 | 42%, 35.7 | 50%, 42.5 | 3.0%, 2.5 |  |
| 8 Vents | 74 |  |  |  | 25%, 18.5 | 70%, 51.8 | 5.0%, 3.7 |  |
| 9 Bone Graveyard | 92 |  |  |  | 5.0%, 4.6 | 87%, 80.0 | 8.0%, 7.4 |  |
| 10 The Underworld | 80 |  |  |  |  | 88%, 70.4 | 12%, 9.6 |  |

**What a rider meets.** 40 dives. Fish of each rarity that came within reach (Jump.GrabRange) a minute, by land; then the seconds into the dive at which the first of each rarity did.

| Land | Seconds in it | Common | Uncommon | Rare | Epic | Legendary | Mythic | Secret | All |
|---|---|---|---|---|---|---|---|---|---|
| 1 Shallows | 16 | 48.1 | 14.2 | 2.3 | 0.5 | 0.1 |  |  | 65.2 |
| 2 Coral Reef | 42 | 9.8 | 33.0 | 11.5 | 1.5 | 0.1 |  |  | 55.8 |
| 3 Kelp Forest | 39 | 0.1 | 24.1 | 19.3 | 4.8 | 0.7 |  |  | 49.1 |
| 4 Shipwrecks | 42 |  | 11.4 | 24.3 | 10.5 | 1.8 |  |  | 48.0 |
| 5 Open Blue | 41 |  | 2.7 | 21.9 | 18.3 | 3.7 | 0.3 |  | 46.8 |
| 6 Twilight | 40 |  | 0.2 | 13.9 | 22.2 | 8.6 | 0.6 |  | 45.6 |
| 7 Midnight | 42 |  |  | 3.8 | 22.5 | 18.1 | 1.3 |  | 45.8 |
| 8 Vents | 35 |  |  | 0.1 | 14.8 | 28.4 | 1.5 |  | 44.7 |
| 9 Bone Graveyard | 42 |  |  |  | 4.1 | 38.1 | 2.7 |  | 44.9 |
| 10 The Underworld | 36 |  |  |  | 0.3 | 39.9 | 3.7 |  | 43.9 |

First within reach (the middle dive): Common 0 s (40 of 40 dives); Uncommon 0 s (40 of 40 dives); Rare 21 s (40 of 40 dives); Epic 42 s (40 of 40 dives); Legendary 106 s (40 of 40 dives); Mythic 220 s (40 of 40 dives).
Time ridden by rarity: Common 6%, Uncommon 16%, Rare 21%, Epic 24%, Legendary 32%, Mythic 2%. The dive took 6.2 minutes on average, at 81 studs a second; ended: the lane's end 40.

- **Lands 1 and 2 match the reference** and stay. In its first zone the recording shows Commons and Uncommons and
  nothing rarer; in its second, mostly Uncommons, Rares often, an Epic now and then, one Legendary in two runs.
- **A new player's dive** is the Shallows only: a Rare within reach about every other dive, an Epic or a Legendary
  almost never. Rares and up are a sight for the first trained dives into the Coral Reef.
- **Something to chase in every land:** each land has a rarity that is 1 to 5% of its fish, and it costs 3 to 10
  times the land's common fish. A player at home there can't hold it yet.
- **Lands 3 to 10 are still the roster's guess.** Nothing measured to move them with. The shares are on the N panel.
- **Small thing:** the roster says Commons only reach the start of the Coral Reef. The game spreads them over all of it.

### Every land has its creatures now
All 82 creatures are in the game since 2026-11-12 (the user's word; [Decisions](../Decisions.md)). Every rarity a
land's mix asks for has a creature there, so no share is skipped any more. Kept out: the Bobbit Worm (not in the
roster) and the ten Secrets (no land's mix has a Secret; they are meant as server events, and no rule for them
exists).

- The smallest pools are the Shallows' rare ones, on purpose: one Rare (the Seahorse), one Epic (the Reef Shark),
  one Legendary (Archelon).
- From the Kelp Forest on, a land's own creatures are about two thirds of its fish and the rest swim in from the
  two lands before.

**Which creatures turn up.** By land: each creature that can spawn there and its share of all spawns in that land. A star marks a creature with no model in the place yet (it spawns as a placeholder body).

| Land | Creatures (share of the land's spawns) |
|---|---|
| 1 Shallows | Common: Sergeant Major 11%, Yellow Tang 11%, Clownfish 11%, Pufferfish 11%, Blue Chromis 11%, Boxfish 11%, Butterflyfish 11%; Uncommon: Stingray 5.5%, Cuttlefish 5.5%, Flying Fish 5.5%, Sea Turtle 5.5%; Rare: Seahorse 3.2%; Epic: Reef Shark 0.6%; Legendary: Archelon 0.2% |
| 2 Coral Reef | Common: Sergeant Major 1.4%, Yellow Tang 1.4%, Clownfish 1.4%, Pufferfish 1.4%, Blue Chromis 1.4%, Boxfish 1.4%, Butterflyfish 1.4%; Uncommon: Parrotfish 14%, Lionfish 14%, Angelfish 14%, Stingray 4.6%, Cuttlefish 4.6%, Flying Fish 4.6%, Sea Turtle 4.6%; Rare: Moray Eel 11%, Octopus 11%, Seahorse 3.6%; Epic: Humphead Wrasse 3.0%, Reef Shark 1.0%; Legendary: Dunkleosteus 0.8%, Archelon 0.2% |
| 3 Kelp Forest | Uncommon: Garibaldi 12%, Sea Lion 12%, Parrotfish 3.9%, Lionfish 3.9%, Angelfish 3.9%, Stingray 1.2%, Cuttlefish 1.2%, Flying Fish 1.2%, Sea Turtle 1.2%; Rare: Giant Sea Bass 16%, Leopard Shark 16%, Moray Eel 5.4%, Octopus 5.4%, Seahorse 1.6%; Epic: Great White 4.9%, Steller's Sea Cow 4.9%, Humphead Wrasse 1.6%, Reef Shark 0.5%; Legendary: Dakosaurus 2.1%, Dunkleosteus 0.7%, Archelon 0.2% |
| 4 Shipwrecks | Uncommon: Barracuda 7.6%, Garibaldi 2.5%, Sea Lion 2.5%, Parrotfish 0.8%, Lionfish 0.8%, Angelfish 0.8%; Rare: Hammerhead Shark 17%, Sawfish 17%, Giant Sea Bass 5.8%, Leopard Shark 5.8%, Moray Eel 1.7%, Octopus 1.7%; Epic: Electric Ray 11%, Goliath Grouper 11%, Great White 3.6%, Steller's Sea Cow 3.6%, Humphead Wrasse 1.1%; Legendary: Xiphactinus 3.5%, Dakosaurus 1.2%, Dunkleosteus 0.3% |
| 5 Open Blue | Uncommon: Barracuda 1.9%, Garibaldi 0.6%, Sea Lion 0.6%; Rare: Dolphin 14%, Swordfish 14%, Hammerhead Shark 4.7%, Sawfish 4.7%, Giant Sea Bass 1.4%, Leopard Shark 1.4%; Epic: Manta Ray 16%, Orca 16%, Electric Ray 5.2%, Goliath Grouper 5.2%, Great White 1.6%, Steller's Sea Cow 1.6%; Legendary: Elasmosaurus 4.5%, Helicoprion 4.5%, Xiphactinus 1.5%, Dakosaurus 0.5%; Mythic: Blue Whale 1.0% |
| 6 Twilight | Rare: Viperfish 11%, Dolphin 3.6%, Swordfish 3.6%, Hammerhead Shark 1.1%, Sawfish 1.1%; Epic: Giant Squid 17%, Goblin Shark 17%, Manta Ray 5.8%, Orca 5.8%, Electric Ray 1.7%, Goliath Grouper 1.7%; Legendary: Liopleurodon 10%, Shonisaurus 10%, Elasmosaurus 3.4%, Helicoprion 3.4%, Xiphactinus 1.0%; Mythic: Lantern Leviathan 1.5%, Blue Whale 0.5% |
| 7 Midnight | Rare: Viperfish 3.1%, Dolphin 0.9%, Swordfish 0.9%; Epic: Anglerfish 15%, Frilled Shark 15%, Giant Squid 4.9%, Goblin Shark 4.9%, Manta Ray 1.5%, Orca 1.5%; Legendary: Basilosaurus 13%, Livyatan 13%, Mosasaurus 13%, Liopleurodon 4.3%, Shonisaurus 4.3%, Elasmosaurus 1.3%, Helicoprion 1.3%; Mythic: Kraken 2.1%, Lantern Leviathan 0.7%, Blue Whale 0.2% |
| 8 Vents | Epic: Giant Isopod 8.7%, Sea Scorpion 8.7%, Anglerfish 2.9%, Frilled Shark 2.9%, Giant Squid 0.9%, Goblin Shark 0.9%; Legendary: Anomalocaris 17%, Kronosaurus 17%, Megalodon 17%, Basilosaurus 5.6%, Livyatan 5.6%, Mosasaurus 5.6%, Liopleurodon 1.7%, Shonisaurus 1.7%; Mythic: Molten Megalodon 3.5%, Kraken 1.2%, Lantern Leviathan 0.3% |
| 9 Bone Graveyard | Epic: Giant Isopod 1.9%, Sea Scorpion 1.9%, Anglerfish 0.6%, Frilled Shark 0.6%; Legendary: Grave Ray 16%, Grave Turtle 16%, Skull Angler 16%, Wraith Eel 16%, Anomalocaris 5.5%, Kronosaurus 5.5%, Megalodon 5.5%, Basilosaurus 1.6%, Livyatan 1.6%, Mosasaurus 1.6%; Mythic: Bone Leviathan 3.3%, Halfbone Megalodon 3.3%, Molten Megalodon 1.1%, Kraken 0.3% |
| 10 The Underworld | Legendary: Brimstone Eel 16%, Cinder Ray 16%, Hellfin Shark 16%, Infernal Angler 16%, Grave Ray 5.2%, Grave Turtle 5.2%, Skull Angler 5.2%, Wraith Eel 5.2%, Anomalocaris 1.6%, Kronosaurus 1.6%, Megalodon 1.6%; Mythic: Abyssal Watcher 4.3%, Hellmaw 4.3%, Bone Leviathan 1.4%, Halfbone Megalodon 1.4%, Molten Megalodon 0.4% |

Nothing here asks to change a creature's rarity or land.

## What changed
- **2026-11-16, fourth pass:** no number changed. The model is written again for the game as it is (a red fish that
  can be hopped off, the longer hop, a speed for every fish, the herd by the land's pace, the tank), with the
  trainer's and the auras' prices worked for two paces. It is all under "Today's rules" at the top.
- **2026-11-12, third pass:** no number changed. The model knows the hold-or-not rule (`Oxygen.StrainTime`) and
  taming (`Config.Tame`). Every table from "Seconds on a fish" to the dives is made again, with two new ones: the
  bar, and the rarest fish a player can tame. `StrainTime`, `Tame.Time` and `Tame.Carry` are this chat's now, and
  are kept as built.
- **2026-11-12, later:** a Common that isn't in Config's own table (Blue Chromis, Boxfish, Butterflyfish) now swims
  one land on, like the other four, not two. It changes nothing that spawns.
- **2026-11-12:** no number changed. The model reads all 82 creatures, the creatures kept out of the herd and
  `Config.Train`; the tables below "How often each rarity spawns" and the training table are made again.
- **2026-11-11, second pass:** the Oxygen numbers in the table under "The numbers, applied". The `ZoneDrain` rows'
  steps on the N panel were made to fit the new sizes, and `KeepUp`'s step is 0.25.
- **2026-11-11, first pass:** rows on the N panel for the ridden speed of each rarity (`TierSpeed`),
  `Oxygen.StartMax` and each land's shares by rarity (`MixShallows` to `MixUnderworld`), with `Config.TierSpeed` and
  ten names for `Config.ZoneMix`'s rows to carry them.
- **By the game-code chat:** `Config.RarityDrain` (a number a rarity, in place of `Oxygen.TierDrain`) with its rows,
  `Oxygen.StartMax` live from the panel, the training spot (`Config.Train`, with `Rate` and `Radius` on the panel),
  for the HUD the player's `Drain` attribute and `State.secondsOn(fish)`, the hold-or-not rule (`Oxygen.StrainTime`,
  `Config.strained`, `Config.secondsOn`) and taming (`Config.Tame`).
- StyLua, selene and `rojo build` pass. Not type-checked (no luau-lsp on this PC).

### The panel
**2026-11-16:** the `TierSpeed` rows are gone with the speeds by rarity. The rest are still there.

| Number | Row | Live? |
|---|---|---|
| Ridden speed by rarity | `TierSpeed` Common to Secret | Yes, on fish already swimming too |
| Oxygen a second by land | `ZoneDrain` land 1 to 10 | Yes |
| Times a Common's Oxygen, by rarity | `RarityDrain` Common to Secret | Yes |
| `Oxygen.Refill`, `KeepUp`, `FreeDrain`, `StartMax` | | Yes. Workspace's `TestMaxOxygen`, when above 0, wins over `StartMax` |
| `Oxygen.StrainTime` | | Yes. Keep it under `Jump.Cooldown` (0.3), or the bar can be hopped over. 0 turns the rule off |
| `Tame.On`, `Time`, `Carry` | | Yes |
| `Train.Rate`, `Share`, `Radius` | | Yes |
| Share of spawns by rarity | `MixShallows` ... `MixUnderworld` | For fish spawned from then on |
| `ReachWeight` | not on the panel | The game works out who can spawn where once, at the start |

"Copy changes" lists a changed speed as `Config.TierSpeed.Common = 54`. It is written into `Config.Tiers`.

### Checked in play
By the game-code chat in Studio, 2026-11-11, hands off, **with the first pass's numbers**:
- **The speed rows work:** the Common set to 70 put wild Commons at 59 to 60 at once.
- **The Shallows:** crossed in 20 seconds at 42 to 45 studs a second, with one crash. The model said 22.
- **The drain added up:** 31 Oxygen left where the numbers of the time gave 31.
- **Not checked:** a dive with hops, and anything with the new Oxygen numbers.

### For the game-code chat (its files)
**2026-11-16, where each stands:** 1 is with the user; 2 is done; 4 and 5 are in the plan (stream 2); 6 no longer applies (a red fish is meant to be hopped off).

Things the model wants that are not numbers of mine. The first five follow from the hold-or-not rule and taming.
1. **The lock gives red fish.** Taking what it gives ends 36 dives of 40 on a red fish, at home in the Coral Reef.
   Proposed: the lock takes a fish you can hold when one is about as near the aim, so a red fish is locked only
   when you aim at it. The tags stay as the warning.
2. Done 2026-11-12 by the UI chat: a fish's tag shows the number for the land it swims in, which is the bar. It
   showed its home land's number before.
3. **The HUD's "needs N OXYGEN" counts a Common,** and no Common swims past the Coral Reef. It should count the
   land's commonest fish.
4. **A full bag keeps nothing more** (under "Taming"). Proposed: it keeps the best seven. It is question 8.
5. **A fish right at your bar is tamed only as it throws you off** (under "Taming"). [The dive](the-dive.md) already
   decides it: out of Oxygen on a fish that is yours, you fall off and float; only a wild fish eats you. Today both
   drown you.
6. **`Oxygen.StrainTime` and `Jump.Cooldown` are tied.** If the cooldown ever goes to 0.25 or under, the bar can be
   hopped over.
7. `Props.Cost` can stay 0.03: a prop costs 0.08 of a second on a fish. The first pass's proposal is withdrawn.

## Not built yet
Proposals, apart from the training spot and taming, which are built as stand-ins. Nothing more is built until the
user says so.

### Training: built as a stand-in, and where it stops
**2026-11-16:** still as built. The trainer's levels under "Today's rules", B, are to replace it.

**Built 2026-11-12 by the game-code chat:** stand on the pad in the hub and max Oxygen grows by `Train.Rate` a
second (4) plus `Train.Share` of your max a second (0.004), for the session only. Both are this chat's to tune, and
both are rows on the N panel. Not played yet.

**What training would have to give.** The plan is a guess (PLAN_MINUTES in the model, --plan to change it): the minutes of play at which a player should first be at home in each land (2.5 s on its commonest fish). From it, the max Oxygen wanted by then and the gain a second of ALL play time between two lands that gets there. The last two columns are the training spot as it is (Train.Rate 4 a second plus Train.Share 0.004 of your max a second): seconds standing on it from the land before, and from the start.

| Land | At home by (min) | Max Oxygen then | Gain over the stretch | A second of play | x the stretch before | Standing, from the land before | Standing, from the start |
|---|---|---|---|---|---|---|---|
| 1 Shallows | 0 | 100 | none |  |  | 0 s | 0 s |
| 2 Coral Reef | 5 | 500 | 400 | 1.3 |  | 78 s | 78 s |
| 3 Kelp Forest | 15 | 3,000 | 2,500 | 4.2 | x3.1 | 4 min | 5 min |
| 4 Shipwrecks | 30 | 12.5K | 9,500 | 10.6 | x2.5 | 5 min | 10 min |
| 5 Open Blue | 55 | 67.5K | 55K | 36.7 | x3.5 | 7 min | 17 min |
| 6 Twilight | 90 | 270K | 202K | 96.4 | x2.6 | 6 min | 23 min |
| 7 Midnight | 150 | 2.25M | 1.98M | 550 | x5.7 | 9 min | 32 min |
| 8 Vents | 240 | 9M | 6.75M | 1,250 | x2.3 | 6 min | 38 min |
| 9 Bone Graveyard | 360 | 37.5M | 28.5M | 3,958 | x3.2 | 6 min | 43 min |
| 10 The Underworld | 540 | 150M | 112M | 10.4K | x2.6 | 6 min | 49 min |

- The plan in the second column is my guess at a pace (question 2). The gain has to grow about 3 times from each land
  to the next.
- **With the share** (the last two columns): the Coral Reef after 78 seconds of standing, the Kelp Forest after 5
  minutes, the Shipwrecks after 10, the Open Blue after 17, the last land after 49. It stands in for machine levels
  until they exist. A guess to play.
- **Why a share:** at a steady 4 a second alone the Shipwrecks took 52 minutes of standing, the Open Blue 5 hours
  and the lands after it days. A steady rate can't follow a cost that grows 4 to 8 times a land.
- **Later, the real thing:** one machine level a land, each about 3 times the last. The reference's goes from +15 to
  +36 a second for 20 times the price, with auras of 1.5 to 3 times on top.
- To jump straight to a land in Studio, Workspace's `TestMaxOxygen` still works.

### Taming: built, and what the numbers say
**2026-11-16:** the two rules asked for here are in the plan (stream 2). The numbers are made again under "Today's rules", A: the slots fill 30 seconds in.

**Built 2026-11-12 by the game-code chat** (`Config.Tame`): ride a fish you hold for `Tame.Time` (2 seconds) and it
is yours, up to `Tame.Carry` (7) a dive. One fish once a dive. A fish too strong is never tamed. The catch is
counted at the dock, however the dive ended. For the session only, and nothing earns yet.

- **The tag's number is the Oxygen that tames it.** The bar and the tame are both 2 seconds, so a fish you hold is a
  fish you can tame, and no other.

**The rarest fish a player can make theirs, land by land.** Tame.Time 2 s on a fish you hold makes it yours, up to Tame.Carry 7 a dive; a fish too strong for you is never tamed. A fish right at your bar gives 2 s, so the tame leaves 0 s to hop off it (none: it is tamed as you are thrown off, if at all). Each line is a player at home in a land; each cell the rarest rarity they hold in that land, and so can tame.

| At home in | Max Oxygen | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 |
|---|---|---|---|---|---|---|---|---|---|---|---|
| 1 Shallows | 100 | Uncommon | none | none | none | none | none | none | none | none | none |
| 2 Coral Reef | 500 | Epic | Uncommon | none | none | none | none | none | none | none | none |
| 3 Kelp Forest | 3,000 | Legendary | Epic | Rare | none | none | none | none | none | none | none |
| 4 Shipwrecks | 12.5K | Legendary | Legendary | Epic | Rare | none | none | none | none | none | none |
| 5 Open Blue | 67.5K | Legendary | Legendary | Legendary | Legendary | Epic | none | none | none | none | none |
| 6 Twilight | 270K | Legendary | Legendary | Legendary | Legendary | Legendary | Epic | none | none | none | none |
| 7 Midnight | 2.25M | Legendary | Legendary | Legendary | Legendary | Mythic | Legendary | Legendary | Epic | none | none |
| 8 Vents | 9M | Legendary | Legendary | Legendary | Legendary | Mythic | Mythic | Mythic | Legendary | Epic | none |
| 9 Bone Graveyard | 37.5M | Legendary | Legendary | Legendary | Legendary | Mythic | Mythic | Mythic | Mythic | Legendary | none |
| 10 The Underworld | 150M | Legendary | Legendary | Legendary | Legendary | Mythic | Mythic | Mythic | Mythic | Mythic | Legendary |

- **Read down a column:** a land's rarest fish are tamed by coming back from further on. The Shallows' Legendary
  (Archelon) needs 1,200 Oxygen: a player between the Coral Reef and the Kelp Forest. That is a reason to dive the
  early lands again.
- **A new player** can tame the Shallows' Commons, with half a second left to hop. In the model one who stays for
  the ring on every fish brings home about 3 a dive; one who hops at ease (1.8 seconds on a fish) almost none.

**Two rules I'd ask for** (not numbers of mine):

1. **A fish right at your bar is tamed only as it throws you off.** It gives 2 seconds and the tame takes 2. That
   is every new player's Uncommon (a fifth of the Shallows' fish, with green tags), and any fish at the moment your
   training turns it green. In the model 32 first dives of 40 end on a fish just tamed: an Uncommon leaves no
   time at all, and a Common's half second is often too short to find the next fish.
   - [The dive](the-dive.md) already decides the fix: on a fish that is yours, out of Oxygen means you fall off
     and float, with a few seconds to reach another fish; only a wild fish eats you. It is not built: today both
     drown you. With it, `Tame.Time` 2 is right as it is.
   - The number alone doesn't fix it well. At `Tame.Time` 1.5 a held fish always leaves half a second, but a rider
     at ease then tames every fish without choosing to, and the slots are full 26 seconds into every dive.
2. **The seven slots fill in the first half minute.** A player who tames what they ride has seven fish 28 seconds
   in: the Shallows and the first third of the Coral Reef, whatever land they are at home in. A tame past seven is
   not kept, so the fish of their own land, two minutes later, are lost. To keep them the player has to hop off
   every early fish before the ring fills.
   - Proposed: a full bag keeps the best seven. A new catch takes the place of the cheapest one carried. Then
     `Tame.Carry` 7 (the reference's seven slots) is fine. It is question 8.
   - A bigger `Carry` doesn't fix it: the first fish are still the cheapest.

- **Kept:** `Tame.Time` 2 and `Tame.Carry` 7. Longer tames for rarer fish are possible, but the cost already rises
  steeply.

### What income and prices would need
**Superseded 2026-11-16:** a catch earns by what it takes to hold (`Config.Aquarium`), and the prices are under "Today's rules", B.

- **Income by how cool a creature is** (decided). Proposed: a creature earns in line with what it costs to hold: the
  land's number times the rarity's.
- **Prices** follow from the pace: a machine level costs so many minutes of a full base's income from the land it
  opens (guess: 10 minutes). The reference keeps 7 creatures earning at once.
- From here it needs: the pace (question 2), then one table of prices.
- Sizes and mutations multiply both the cost and the income (the reference: 0.8, 1.2 and 1.5 times by size).

## Questions for the user
**2026-11-16:** how each stands today, and a new one, is at the end of "Today's rules". The list below is as it stood on 2026-11-12.

1. **"The level":** do you mean a level on each fish (it grows as you ride or keep it), a level on the player, or
   simply the land you have reached? No note defines one.
2. **The pace:** how long should a new player take to be at home in land 2, land 5 and land 10? (My guess: 5
   minutes, an hour, 9 hours.) And does the first version still ship lands 1 to 4 only?
3. No longer a question: the training spot is built as a stand-in (4 Oxygen a second plus 0.4% of your max a
   second while you stand on the pad). The numbering is kept so the other questions keep theirs.
4. **Speed:** try the Common at 54 (the reference's ride; ours is 45) with smaller steps up to 90, or keep 45 to
   100? Both can be played from the N panel.
5. **Holding Space** moves you 2 to 3 times as fast as any fish. Since the hold-or-not rule it can't take you past
   your own land, so this is smaller than it was. Is the fast way down fine, or should there be a longer wait on a
   fish before the next hop (0.3 seconds today)?
6. Answered 2026-11-12 ([Decisions](../Decisions.md)): a landing is never refused; a fish too strong empties the
   meter at once and throws you off. The numbering is kept.
7. **Which traits?** Of the four recommended (smash or crash by size; fast and short against slow and long; a
   higher hop for a few leapers; schools), which should be built first, and is any of the eight wrong for the game?
8. **A full bag:** you carry seven tamed fish a dive, and they fill in the first half minute, before a trained
   player reaches their own land. Should a full bag keep the best seven (a better catch takes the place of the
   cheapest), or is hopping off before the ring fills the skill?
