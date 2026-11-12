# Progression: speed, rarity and Oxygen

How long you can stay on a fish, how fast each fish is, how often each rarity turns up, and so how a player gets from
the Shallows to the tenth land. By the tuning chat ([Sessions](../Sessions.md)); second pass 2026-11-11, after the
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
python tools/balance/model.py --set Tiers.Common=54 --set RarityDrain.Legendary=10     try numbers without changing the game
```

It reads [Config](../../src/shared/Config.luau), the creature files in `src/shared/Creatures` and the map's path
(`art/map/greybox/path.json`). The dives are a model of the herd's rules, not a play test: they leave out steering,
walls and other players. Where a number matters, it should be checked in play.

## The short version
1. **The unit is seconds on a fish, and every fish starts with the whole meter.** A new player has 2.5 seconds on a
   Shallows Common and 2 on an Uncommon. You hop or you are thrown off.
2. **A fish is held or it is not** (the user, 2026-11-12). The number on a fish's tag is the max Oxygen for 2 seconds
   on it. With less you still land, but the meter empties in a quarter of a second and the fish throws you off. So a
   land is a wall now, not a slope: a player at home in one land holds nothing in the next.
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
- **Income by how cool a creature is** (decided). Proposed: a creature earns in line with what it costs to hold: the
  land's number times the rarity's.
- **Prices** follow from the pace: a machine level costs so many minutes of a full base's income from the land it
  opens (guess: 10 minutes). The reference keeps 7 creatures earning at once.
- From here it needs: the pace (question 2), then one table of prices.
- Sizes and mutations multiply both the cost and the income (the reference: 0.8, 1.2 and 1.5 times by size).

## Questions for the user
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
