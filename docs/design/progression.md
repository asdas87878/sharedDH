# Progression: speed, rarity and Oxygen

How long you can stay on a fish, how fast each fish is, how often each rarity turns up, and so how a player gets from
the Shallows to the tenth land. By the tuning chat ([Sessions](../Sessions.md)); second pass 2026-11-11, after the
user's answer on how the Oxygen cost works ([Decisions](../Decisions.md), top row).

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
   Shallows Common, 2 on an Uncommon, 1 on a Rare, half a second on an Epic, nothing to speak of on a Legendary. You
   hop or you are thrown off. That is in the game now.
2. **A new player's dive is about 15 seconds:** the Shallows, five fish long, and it ends on the first fish of the
   Coral Reef, where a full meter lasts half a second (played: 15.6 seconds, 1,141 studs). Each land takes 4 to 8 times the Oxygen of the land before. Nothing grows max Oxygen
   yet, so the training spot is the next thing the game needs.
3. **Hopping is faster than riding, so a fish's speed is worth less than it looks.** A rider who hops every 2
   seconds covers about one and a half times the ground the fish alone would. Holding Space covers 2 to 3 times. Rarer fish
   ahead can now be caught by hopping to far fish. Speed alone won't make fish feel different; the list under
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
- **What ends a dive then:** missing every fish in a hop, or landing on a fish that gives you less time than it takes
  to hop again (0.3 seconds, `Jump.Cooldown`). Oxygen no longer runs down over a dive. In a land you are at home in,
  you ride until you miss; the next land or the one after throws you off.
- **Seconds on a fish** = your max Oxygen / (the land's number x the rarity's number): `ZoneDrain` x `RarityDrain`.
- **What the game shows as "needs":** the Oxygen for 2 seconds on the fish (`Oxygen.KeepUp` 2).

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

**Seconds on a fish with 100 max Oxygen (a new player).** Max Oxygen / (ZoneDrain x RarityDrain): how long a full meter lasts on a fish of that rarity in that land. A landing on another fish gives back the whole meter. Blank: that rarity doesn't spawn there. The game's "enough" is Oxygen.KeepUp 2 s; under the hop's cooldown (0.3 s) you are thrown off before you can hop.

| Land | Oxygen a second (Common) | Common | Uncommon | Rare | Epic | Legendary | Mythic | Secret |
|---|---|---|---|---|---|---|---|---|
| 1 Shallows | 40 | 2.5 | 2.0 | 1.0 | 0.56 | 0.17 |  |  |
| 2 Coral Reef | 160 | 0.62 | 0.50 | 0.25 | 0.14 | 0.04 |  |  |
| 3 Kelp Forest | 480 |  | 0.17 | 0.08 | 0.05 | 0.01 |  |  |
| 4 Shipwrecks | 2,000 |  | 0.04 | 0.02 | 0.01 | 0.00 |  |  |
| 5 Open Blue | 6,000 |  | 0.01 | 0.01 | 0.00 | 0.00 | 0.00 |  |
| 6 Twilight | 24K |  |  | 0.00 | 0.00 | 0.00 | 0.00 |  |
| 7 Midnight | 60K |  |  |  | 0.00 | 0.00 | 0.00 |  |
| 8 Vents | 240K |  |  |  | 0.00 | 0.00 | 0.00 |  |
| 9 Bone Graveyard | 1M |  |  |  | 0.00 | 0.00 | 0.00 |  |
| 10 The Underworld | 4M |  |  |  |  | 0.00 | 0.00 |  |

- Under 0.3 seconds you are thrown off before you can hop again.

**What max Oxygen means, land by land.** The land's commonest fish, what it takes a second, and the max Oxygen for 1 s on it (you get through, hopping all the time), 2 s (the game's "enough": Oxygen.KeepUp), 2.5 s (at home: a new player's time on a Shallows Common; a guess) and for 2 s on the land's rarer fish (the chase). "HUD" is what the game shows today as the land's need: 2 s on a Common.

| Land | Commonest fish | It takes /s | 1 s on it | 2 s on it | 2.5 s on it (at home) | x the land before | HUD | 2 s on its Legendary | 2 s on its Mythic |
|---|---|---|---|---|---|---|---|---|---|
| 1 Shallows | Common | 40 | 40 | 80 | 100 |  | 80 | 1,200 |  |
| 2 Coral Reef | Uncommon | 200 | 200 | 400 | 500 | x5.0 | 320 | 4,800 |  |
| 3 Kelp Forest | Rare | 1,200 | 1,200 | 2,400 | 3,000 | x6.0 | 960 | 14.4K |  |
| 4 Shipwrecks | Rare | 5,000 | 5,000 | 10K | 12.5K | x4.2 | 4,000 | 60K |  |
| 5 Open Blue | Epic | 27K | 27K | 54K | 67.5K | x5.4 | 12K | 180K | 600K |
| 6 Twilight | Epic | 108K | 108K | 216K | 270K | x4.0 | 48K | 720K | 2.4M |
| 7 Midnight | Legendary | 900K | 900K | 1.8M | 2.25M | x8.3 | 120K | 1.8M | 6M |
| 8 Vents | Legendary | 3.6M | 3.6M | 7.2M | 9M | x4.0 | 480K | 7.2M | 24M |
| 9 Bone Graveyard | Legendary | 15M | 15M | 30M | 37.5M | x4.2 | 2M | 30M | 100M |
| 10 The Underworld | Legendary | 60M | 60M | 120M | 150M | x4.0 | 8M | 120M | 400M |

- **Proposed meaning (a guess):** you are at home in a land when you have 2.5 seconds on its commonest fish, the same
  feel a new player has in the Shallows. With 1 second you get through if you never stop hopping.
- Being at home takes 4 to 6 times the land before, and 8 times at the Midnight zone, where Legendaries become the
  common fish.
- To try a land in Studio: set Workspace's `TestMaxOxygen` to the "at home" number (500, 3,000, 12,500 ...).

**Seconds on a fish for a player at home in each land.** A player whose max Oxygen gives 2.5 s on that land's commonest fish: their time on each rarity there, and on the commonest fish of the land before and the land after.

| At home in | Max Oxygen | Common | Uncommon | Rare | Epic | Legendary | Mythic | Secret | The land before | The land after |
|---|---|---|---|---|---|---|---|---|---|---|
| 1 Shallows | 100 | 2.5 | 2.0 | 1.0 | 0.56 | 0.17 |  |  |  | 0.50 |
| 2 Coral Reef | 500 | 3.1 | 2.5 | 1.2 | 0.69 | 0.21 |  |  | 12 | 0.42 |
| 3 Kelp Forest | 3,000 |  | 5.0 | 2.5 | 1.4 | 0.42 |  |  | 15 | 0.60 |
| 4 Shipwrecks | 12.5K |  | 5.0 | 2.5 | 1.4 | 0.42 |  |  | 10 | 0.46 |
| 5 Open Blue | 67.5K |  | 9.0 | 4.5 | 2.5 | 0.75 | 0.23 |  | 14 | 0.62 |
| 6 Twilight | 270K |  |  | 4.5 | 2.5 | 0.75 | 0.23 |  | 10 | 0.30 |
| 7 Midnight | 2.25M |  |  |  | 8.3 | 2.5 | 0.75 |  | 21 | 0.62 |
| 8 Vents | 9M |  |  |  | 8.3 | 2.5 | 0.75 |  | 10 | 0.60 |
| 9 Bone Graveyard | 37.5M |  |  |  | 8.3 | 2.5 | 0.75 |  | 10 | 0.62 |
| 10 The Underworld | 150M |  |  |  |  | 2.5 | 0.75 |  | 10 |  |

- At home in a land, the land before is a rest (10 seconds or more on a fish) and the land after is a scramble (half
  a second).
- The chase is in every land: at home there, its rarer fish still give under a second (a Legendary in the first six
  lands, a Mythic from the fifth on).

**How far a max Oxygen gets** (the model's dives). Endless air off. Each line is a player and a way of riding. "At ease": on each fish until 0.7 s are left (1.8 s at most), never hopping sooner than 0.7 s after a landing, onto the fish the lock gives (about 60 studs ahead). "Reads the tags": only fish that give 1 s or more, when one is in reach. "Space held": a hop the moment the cooldown ends and a grab at once, only fish that give 0.4 s or more. 30 dives each. The last columns: fish of that rarity that came within reach in one dive, on average.

| Player | Max Oxygen | Rider | Lasts (s) | Studs | Ends in land | Hops landed | How it ended | Rare in reach | Epic in reach | Legendary in reach | Mythic in reach |
|---|---|---|---|---|---|---|---|---|---|---|---|
| a new player | 100 | at ease | 16 | 1,021 | 1 to 2 | 4 | out of Oxygen 30 | 0.6 | 0.0 | 0.0 | 0.0 |
| a new player | 100 | at ease, reads the tags | 16 | 1,021 | 1 to 2 | 4 | out of Oxygen 30 | 0.6 | 0.0 | 0.0 | 0.0 |
| a new player | 100 | Space held, reads the tags | 15 | 1,533 | 1 to 3 | 12 | out of Oxygen 30 | 2.9 | 0.4 | 0.1 | 0.0 |
| at home in land 2 | 500 | at ease | 48 | 3,185 | 2 to 3 | 12 | out of Oxygen 30 | 6.0 | 1.0 | 0.3 | 0.0 |
| at home in land 2 | 500 | at ease, reads the tags | 52 | 3,443 | 2 to 3 | 13 | out of Oxygen 30 | 6.4 | 1.2 | 0.4 | 0.0 |
| at home in land 2 | 500 | Space held, reads the tags | 27 | 2,656 | 2 to 4 | 20 | out of Oxygen 30 | 6.5 | 1.0 | 0.2 | 0.0 |
| at home in land 3 | 3,000 | at ease | 84 | 5,759 | 3 to 4 | 20 | out of Oxygen 30 | 16.6 | 3.1 | 0.6 | 0.0 |
| at home in land 3 | 3,000 | at ease, reads the tags | 89 | 6,058 | 2 to 4 | 21 | out of Oxygen 30 | 18.1 | 4.1 | 0.7 | 0.0 |
| at home in land 3 | 3,000 | Space held, reads the tags | 60 | 6,066 | 2 to 5 | 44 | out of Oxygen 28, missed every fish 2 | 27.5 | 7.3 | 1.4 | 0.0 |
| at home in land 5 | 67.5K | at ease | 168 | 12,168 | 4 to 6 | 38 | out of Oxygen 30 | 50.4 | 20.6 | 3.8 | 0.1 |
| at home in land 5 | 67.5K | at ease, reads the tags | 169 | 12,192 | 4 to 6 | 38 | out of Oxygen 30 | 48.0 | 20.3 | 3.1 | 0.2 |
| at home in land 5 | 67.5K | Space held, reads the tags | 117 | 11,793 | 3 to 6 | 80 | out of Oxygen 29, missed every fish 1 | 67.5 | 33.8 | 7.4 | 0.4 |

- **A new player: about 15 seconds.** The Shallows in four or five hops, then thrown off the first Coral Reef fish.
  Holding Space and choosing fish by their tags gets about 500 studs into the Reef in the same time.
- A player at home in a land gets into the next land, sometimes the one after.

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
- **That is short, and it can work, if each of those dives gives something.** Five fish ridden for 2 seconds each
  is five Commons caught, once taming exists. And the first training step has to come in the first two or three
  minutes, so the 15-second dive is the first few dives and not the first half hour.
- **If the user wants a longer first dive, there are three places to get it,** none of them touching the 2.5
  seconds on the first fish: a longer first land (the map's: the other lands are 2,800 to 3,800 studs); a softer
  step into the Coral Reef (`ZoneDrain` land 2 at 100 in place of 160 gives a new player a second on a Reef Common,
  and the model's first dive goes to 27 seconds and 900 studs of Reef); or the pace of the first training. No number
  is changed for this: it waits for the user's answer on the pace (question 2).

## What the HUD should show
For the UI chat. The unit a player should read is **seconds on a fish**; max Oxygen is the one big number they train.

| On screen | The number | Unit | In the game, or proposed |
|---|---|---|---|
| The meter while riding | The time left on this fish: Oxygen left / what this fish takes a second here (`Config.drain` of the land you are in and the fish's rarity) | A ring or bar that empties; seconds beside it if there is room (2.5, then 0.8) | In the game: it is full at every landing on another fish, and empties at the fish's rate. A crash takes a tenth of it, a prop 3% |
| In the hop | Nothing drains | The meter holds still | In the game |
| Your max Oxygen | The stat you train | One number, short past 10,000 (12.5K, 2.25M, 150M) | In the game (the short form is proposed) |
| A wild fish's tag | The Oxygen for 2 seconds on it (`Config.required` of its land and rarity) | Oxygen, in the same short form, so it compares with your max | In the game, but the tag counts the fish's home land; one or two lands on it costs more (proposed: count the land it is in) |
| A fish you can't hold yet | Whether your max gives 2 seconds on it, less, or under half a second | A colour on its tag and on the lock's mark: fine, short, too much | Proposed. Whether the game also stops you landing on a "too much" fish is question 6 |
| The land's line | The Oxygen for 2 seconds on the land's commonest fish, shown while yours is under it | Oxygen, short form | Proposed. Today it counts a Common, and no Common swims past the Coral Reef |
| Oxygen a second | Not needed | | Today's HUD shows it. Seconds left says the same thing in the unit the player feels |

- "Enough" is 2 seconds (`Oxygen.KeepUp`). "At home" in a land, 2.5 seconds on its commonest fish, is my guess and
  not a rule of the game.
- The numbers get large: the tenth land's common fish takes 60 million a second. Seconds stay small at every depth,
  which is one more reason to show them.

## Speed, for a rider who hops all the time
**By rarity.** A wild fish swims at Herd.SpeedShare 0.85 of its ridden speed. The hop off a fish: the pop at Jump.Launch 1.6 times the ridden speed, the glide at AirShare 0.85 of it, and the pull-in begins 1.7 s after the press.

| Rarity | Ridden | Step up | Wild (herd) | Pop | Glide | Hop carries (studs) | and gains on its own herd | Drain x | View widens (deg) | Turn circle (studs across) | Lands |
|---|---|---|---|---|---|---|---|---|---|---|---|
| Common | 45 |  | 38.2 | 72 | 38.2 | 89 | 24 | 1 | 4.4 | 54 | 1, 2 |
| Uncommon | 52 | +16% | 44.2 | 83 | 44.2 | 103 | 28 | 1.25 | 5.6 | 63 | 1, 2, 3, 4, 5 |
| Rare | 60 | +15% | 51.0 | 96 | 51.0 | 119 | 32 | 2.5 | 7.0 | 72 | 1, 2, 3, 4, 5, 6 (the mix asks for 1, 2, 3, 4, 5, 6, 7) |
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
- **Holding Space is 2 to 3 times any fish's speed.** With the whole meter back at each landing it also needs only
  0.3 seconds on each fish where an easy rider wants 2.5: about one land's worth of Oxygen. Whether that is the
  skill of the game or too much is the user's call (question 5). The number is `Jump.Cooldown`, not mine.

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
| 7 Midnight | 85 |  |  | asks 5%: no creature | 44%, 37.6 | 53%, 44.7 | 3.2%, 2.7 |  |
| 8 Vents | 74 |  |  |  | 25%, 18.5 | 70%, 51.8 | 5.0%, 3.7 |  |
| 9 Bone Graveyard | 92 |  |  |  | 5.0%, 4.6 | 87%, 80.0 | 8.0%, 7.4 |  |
| 10 The Underworld | 80 |  |  |  |  | 88%, 70.4 | 12%, 9.6 |  |

**What a rider meets.** 30 dives. Fish of each rarity that came within reach (Jump.GrabRange) a minute, by land; then the seconds into the dive at which the first of each rarity did.

| Land | Seconds in it | Common | Uncommon | Rare | Epic | Legendary | Mythic | Secret | All |
|---|---|---|---|---|---|---|---|---|---|
| 1 Shallows | 16 | 54.3 | 12.6 | 2.3 | 0.4 |  |  |  | 69.6 |
| 2 Coral Reef | 42 | 10.2 | 33.1 | 9.8 | 1.2 | 0.2 |  |  | 54.6 |
| 3 Kelp Forest | 39 | 0.3 | 23.8 | 19.3 | 4.7 | 0.8 |  |  | 48.9 |
| 4 Shipwrecks | 42 |  | 10.5 | 26.5 | 11.2 | 1.5 |  |  | 49.7 |
| 5 Open Blue | 40 |  | 2.8 | 23.3 | 17.5 | 3.5 | 0.1 |  | 47.3 |
| 6 Twilight | 40 |  | 0.0 | 12.1 | 23.3 | 8.7 | 0.2 |  | 44.4 |
| 7 Midnight | 41 |  |  | 0.4 | 25.2 | 20.3 | 1.0 |  | 46.9 |
| 8 Vents | 35 |  |  |  | 15.9 | 28.3 | 1.4 |  | 45.6 |
| 9 Bone Graveyard | 42 |  |  |  | 3.8 | 38.2 | 2.3 |  | 44.3 |
| 10 The Underworld | 36 |  |  |  | 0.2 | 40.9 | 3.6 |  | 44.7 |

First within reach (the middle dive): Common 0 s (30 of 30 dives); Uncommon 4 s (30 of 30 dives); Rare 20 s (30 of 30 dives); Epic 49 s (30 of 30 dives); Legendary 85 s (30 of 30 dives); Mythic 256 s (30 of 30 dives).
Time ridden by rarity: Common 6%, Uncommon 14%, Rare 21%, Epic 25%, Legendary 33%, Mythic 2%. The dive took 6.2 minutes on average, at 81 studs a second; ended: the lane's end 30.

- **Lands 1 and 2 match the reference** and stay. In its first zone the recording shows Commons and Uncommons and
  nothing rarer; in its second, mostly Uncommons, Rares often, an Epic now and then, one Legendary in two runs.
- **A new player's dive** is the Shallows only: a Rare within reach about every other dive, an Epic or a Legendary
  almost never. Rares and up are a sight for the first trained dives into the Coral Reef.
- **Something to chase in every land:** each land has a rarity that is 1 to 5% of its fish, and it costs 3 to 10
  times the land's common fish.
- **Lands 3 to 10 are still the roster's guess.** Nothing measured to move them with. The shares are on the N panel.
- **Small thing:** the roster says Commons only reach the start of the Coral Reef. The game spreads them over all of it.

### Lands whose rarities have no creature yet
33 of the roster's 82 creatures are in the place. A rarity with no creature in a land is skipped and the others share
its place, so nothing breaks, but some lands are thin:

| Land | What is missing |
|---|---|
| 3 Kelp Forest | Half its fish are grey placeholder bodies: Garibaldi, Leopard Shark, Great White (no model in the place) |
| 4 Shipwrecks | Half again: Barracuda, Goliath Grouper, and the three above swimming on from land 3 |
| 6 Twilight | Six creatures in all, none of its own. Every Legendary there is an Elasmosaurus (28% of the land) |
| 7 Midnight | The mix asks for 5% Rares and there is no Rare within two lands (the Viperfish isn't in the place) |
| 9 Bone Graveyard | None of its own: five creatures from lands 7 and 8 |
| 10 The Underworld | Three creatures: Anomalocaris and the Bobbit Worm from land 8 at 44% each, and the Hellmaw |

**Which creatures turn up.** By land: each creature that can spawn there and its share of all spawns in that land. A star marks a creature with no model in the place yet (it spawns as a placeholder body).

| Land | Creatures (share of the land's spawns) |
|---|---|
| 1 Shallows | Common: Sergeant Major 11%, Yellow Tang 11%, Clownfish 11%, Pufferfish 11%, Blue Chromis 11%, Boxfish 11%, Butterflyfish 11%; Uncommon: Stingray 5.5%, Cuttlefish 5.5%, Flying Fish 5.5%, Sea Turtle 5.5%; Rare: Seahorse 3.2%; Epic: Reef Shark 0.6%; Legendary: Archelon 0.2% |
| 2 Coral Reef | Common: Sergeant Major 1.4%, Yellow Tang 1.4%, Clownfish 1.4%, Pufferfish 1.4%, Blue Chromis 1.4%, Boxfish 1.4%, Butterflyfish 1.4%; Uncommon: Parrotfish 14%, Lionfish 14%, Angelfish 14%, Stingray 4.6%, Cuttlefish 4.6%, Flying Fish 4.6%, Sea Turtle 4.6%; Rare: Moray Eel 11%, Octopus 11%, Seahorse 3.6%; Epic: Humphead Wrasse 3.0%, Reef Shark 1.0%; Legendary: Dunkleosteus 0.8%, Archelon 0.2% |
| 3 Kelp Forest | Uncommon: Garibaldi* 17%, Parrotfish 5.6%, Lionfish 5.6%, Angelfish 5.6%, Stingray 1.7%, Cuttlefish 1.7%, Flying Fish 1.7%, Sea Turtle 1.7%; Rare: Leopard Shark* 25%, Moray Eel 8.5%, Octopus 8.5%, Seahorse 2.5%; Epic: Great White* 8.4%, Humphead Wrasse 2.8%, Reef Shark 0.8%; Legendary: Dunkleosteus 2.3%, Archelon 0.7% |
| 4 Shipwrecks | Uncommon: Barracuda* 9.2%, Garibaldi* 3.1%, Parrotfish 0.9%, Lionfish 0.9%, Angelfish 0.9%; Rare: Hammerhead Shark 33%, Leopard Shark* 11%, Moray Eel 3.3%, Octopus 3.3%; Epic: Goliath Grouper* 21%, Great White* 7.0%, Humphead Wrasse 2.1%; Legendary: Dunkleosteus 5.0% |
| 5 Open Blue | Uncommon: Barracuda* 2.3%, Garibaldi* 0.7%; Rare: Hammerhead Shark 31%, Leopard Shark* 9.2%; Epic: Manta Ray 18%, Orca 18%, Goliath Grouper* 6.2%, Great White* 1.8%; Legendary: Elasmosaurus 11%; Mythic: Blue Whale 1.0% |
| 6 Twilight | Rare: Hammerhead Shark 20%; Epic: Manta Ray 22%, Orca 22%, Goliath Grouper* 6.5%; Legendary: Elasmosaurus 28%; Mythic: Blue Whale 2.0% |
| 7 Midnight | Epic: Anglerfish 37%, Manta Ray 3.7%, Orca 3.7%; Legendary: Basilosaurus 25%, Mosasaurus 25%, Elasmosaurus 2.5%; Mythic: Kraken 2.9%, Blue Whale 0.3% |
| 8 Vents | Epic: Anglerfish 25%; Legendary: Anomalocaris 26%, Bobbit Worm 26%, Basilosaurus 8.8%, Mosasaurus 8.8%; Mythic: Kraken 5.0% |
| 9 Bone Graveyard | Epic: Anglerfish 5.0%; Legendary: Anomalocaris 33%, Bobbit Worm 33%, Basilosaurus 10%, Mosasaurus 10%; Mythic: Kraken 8.0% |
| 10 The Underworld | Legendary: Anomalocaris 44%, Bobbit Worm 44%; Mythic: Hellmaw 12% |

The creature import is already planned ([creature import](creature-import.md)) and waits for the user's picks.
Nothing here asks to change a creature's rarity or land.

## What changed
- **2026-11-11, second pass:** the Oxygen numbers in the table under "The numbers, applied". The `ZoneDrain` rows'
  steps on the N panel were made to fit the new sizes, and `KeepUp`'s step is 0.25.
- **2026-11-11, first pass:** rows on the N panel for the ridden speed of each rarity (`TierSpeed`),
  `Oxygen.StartMax` and each land's shares by rarity (`MixShallows` to `MixUnderworld`), with `Config.TierSpeed` and
  ten names for `Config.ZoneMix`'s rows to carry them.
- **By the game-code chat:** `Config.RarityDrain` (a number a rarity, in place of `Oxygen.TierDrain`) with its rows,
  and `Oxygen.StartMax` live from the panel.
- StyLua, selene and `rojo build` pass. Not type-checked (no luau-lsp on this PC).

### The panel
| Number | Row | Live? |
|---|---|---|
| Ridden speed by rarity | `TierSpeed` Common to Secret | Yes, on fish already swimming too |
| Oxygen a second by land | `ZoneDrain` land 1 to 10 | Yes |
| Times a Common's Oxygen, by rarity | `RarityDrain` Common to Secret | Yes |
| `Oxygen.Refill`, `KeepUp`, `FreeDrain`, `StartMax` | | Yes. Workspace's `TestMaxOxygen`, when above 0, wins over `StartMax` |
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
Things the new model wants that are not numbers of mine:
1. **A fish you can't sit on shouldn't take the lock,** or should show red. A new player who lands on the Shallows'
   Legendary has 0.17 seconds and is thrown off before the hop's cooldown ends. With the lock choosing for you, that
   is a death you didn't pick.
2. **The HUD's "needs N OXYGEN" counts a Common,** and no Common swims past the Coral Reef. It should count the
   land's commonest fish. The numbers also want short forms (120K, 2.25M).
3. **A fish's tag shows what it needs in its home land.** One or two lands on, it costs that land's price.
4. `Props.Cost` can stay 0.03: a prop now costs 0.08 of a second on a fish. The first pass's proposal is withdrawn.

## Not built yet
Proposals. None of it is built until the user says so.

### The smallest thing that lets the progression be played
**Max Oxygen has to grow.** The smallest version: a training spot on the dock (the machine's place). Standing on it
adds to your max Oxygen every second. The server keeps it for the session; no saves yet. One number, `Train.Rate`.

**What training would have to give.** The plan is a guess (PLAN_MINUTES in the model, --plan to change it): the minutes of play at which a player should first be at home in each land (2.5 s on its commonest fish). From it, the max Oxygen wanted by then and the gain a second of ALL play time between two lands that gets there.

| Land | At home by (min) | Max Oxygen then | Gain over the stretch | A second of play | x the stretch before |
|---|---|---|---|---|---|
| 1 Shallows | 0 | 100 | none |  |  |
| 2 Coral Reef | 5 | 500 | 400 | 1.3 |  |
| 3 Kelp Forest | 15 | 3,000 | 2,500 | 4.2 | x3.1 |
| 4 Shipwrecks | 30 | 12.5K | 9,500 | 10.6 | x2.5 |
| 5 Open Blue | 55 | 67.5K | 55K | 36.7 | x3.5 |
| 6 Twilight | 90 | 270K | 202K | 96.4 | x2.6 |
| 7 Midnight | 150 | 2.25M | 1.98M | 550 | x5.7 |
| 8 Vents | 240 | 9M | 6.75M | 1,250 | x2.3 |
| 9 Bone Graveyard | 360 | 37.5M | 28.5M | 3,958 | x3.2 |
| 10 The Underworld | 540 | 150M | 112M | 10.4K | x2.6 |

- The plan in the second column is my guess at a pace (question 2). The gain has to grow about 3 times from each land
  to the next.
- If a third of play is spent training, the machine has to give three times these: about 4 a second at first.
- **Proposed start:** `Train.Rate` 4 a second (the Coral Reef in two minutes of standing). Then one machine level a
  land, each 3 times the last. The reference's goes from +15 to +36 a second for 20 times the price, with auras of
  1.5 to 3 times on top. All guesses until it is played.

### What taming would need from these numbers
- Decided already: stay on a wild fish long enough and it is yours ([the dive](the-dive.md)).
- **Proposed:** the time to tame is the 2 seconds the game already calls enough (`Oxygen.KeepUp`). Then the number on
  a fish's tag is exactly the Oxygen that tames it, as in the reference. A new player can tame a Shallows Common (80)
  and just an Uncommon (100), which is the user's "enough for a Common, and a little more".
- From here it needs nothing new. Longer tame times for rarer fish are possible but the cost already rises steeply.

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
3. **May the game-code chat build the training spot** (max Oxygen grows while you stand on it)? Without it a dive is
   15 seconds and nothing changes that.
4. **Speed:** try the Common at 54 (the reference's ride; ours is 45) with smaller steps up to 90, or keep 45 to
   100? Both can be played from the N panel.
5. **Holding Space** moves you 2 to 3 times as fast as any fish and needs an eighth of the Oxygen. Is that the skill
   of the game, or should there be a longer wait on a fish before the next hop (0.3 seconds today)?
6. **A fish that is too much for you** (under about half a second): should the game stop you landing on it, or let
   you land and be thrown off to drown, as today?
7. **Which traits?** Of the four recommended (smash or crash by size; fast and short against slow and long; a
   higher hop for a few leapers; schools), which should be built first, and is any of the eight wrong for the game?
