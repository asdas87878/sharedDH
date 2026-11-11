# Progression: speed, rarity and Oxygen

How fast each fish is, how often each rarity turns up, what each land costs in Oxygen, and so how a player gets from the
Shallows to the tenth land. Written 2026-11-11 by the tuning chat ([Sessions](../Sessions.md)).

**Everything under "What is off" is proposed, not decided.** No number in the game was changed for this note. What the
user decides goes in [Decisions](../Decisions.md).

The tables come from a model that reads the game's own numbers, so they can be made again after any change:

```
python tools/balance/model.py              the tables
python tools/balance/model.py --sim 8      and 8 dives per rider played through the herd
python tools/balance/model.py --set Tiers.Common=54 --set Oxygen.TierDrain=1     try numbers without changing the game
```

It reads [Config](../../src/shared/Config.luau), the creature files in `src/shared/Creatures` and the map's path
(`art/map/greybox/path.json`). The dives are a model of the herd's rules, not a play test: they leave out steering,
walls and other players. Where a number matters, it should be checked in play.

## The short version
1. **A new player's dive is 75 seconds and ends at the door of the third land, and nothing can change that yet.** The
   starting 100 Oxygen rides the Shallows (20 seconds) and the Coral Reef (50 seconds), then runs dry in the Kelp
   Forest. There is no way to grow max Oxygen, so today that is the whole game.
2. **Rarity costs almost nothing, so there is nothing to chase.** A Legendary takes 1.6 times a Common's Oxygen and is
   1.7 times as fast, so for each stud it is cheaper than a Common. A new player has a Rare within reach in the first
   25 seconds, an Epic in most dives and a Legendary about one dive in six, and can ride each of them at once. In Ride
   a Dino a Legendary needs 15 times the stamina of the Uncommon beside it: you see it long before you can keep it.
3. **Mashing Space beats the Oxygen curve.** A hop drains nothing and every landing gives a quarter back. A rider who
   hops again the moment they land needs a twentieth of the Oxygen the game says a land needs, and reaches the fourth
   or fifth land on the starting 100.

Two smaller ones: our Common is slower than the reference's ride (45 against 54), which is why the glide felt slow; and
a wild fish one rarity above yours swims exactly as fast as you ride, so you can't catch it up.

## Today's numbers
From the model on 2026-11-11, with grey-box 8's path. The map is being reworked, so the lengths may move a little.

**The lane.** 30,164 studs to ride over 10 lands (art/map/greybox/path.json); 720 wild fish in all (Spawn.PerThousand 24, MaxTotal 800).

| Land | Studs | Width | Fish | Studs between | s at Common (45) | s at Uncommon (52) | s at Rare (60) | s at Epic (68) | s at Legendary (78) | s at Mythic (90) | s at Secret (100) |
|---|---|---|---|---|---|---|---|---|---|---|---|
| 1 Shallows | 1,009 | 143 to 248 | 24 | 42 | 22 | 19 | 17 | 15 | 13 | 11 | 10 |
| 2 Coral Reef | 2,846 | 156 to 432 | 68 | 42 | 63 | 55 | 47 | 42 | 36 | 32 | 28 |
| 3 Kelp Forest | 2,807 | 203 to 520 | 67 | 42 | 62 | 54 | 47 | 41 | 36 | 31 | 28 |
| 4 Shipwrecks | 3,160 | 243 to 585 | 75 | 42 | 70 | 61 | 53 | 46 | 41 | 35 | 32 |
| 5 Open Blue | 3,168 | 279 to 621 | 76 | 42 | 70 | 61 | 53 | 47 | 41 | 35 | 32 |
| 6 Twilight | 3,295 | 279 to 691 | 79 | 42 | 73 | 63 | 55 | 48 | 42 | 37 | 33 |
| 7 Midnight | 3,581 | 354 to 859 | 85 | 42 | 80 | 69 | 60 | 53 | 46 | 40 | 36 |
| 8 Vents | 3,120 | 354 to 866 | 74 | 42 | 69 | 60 | 52 | 46 | 40 | 35 | 31 |
| 9 Bone Graveyard | 3,837 | 394 to 940 | 92 | 42 | 85 | 74 | 64 | 56 | 49 | 43 | 38 |
| 10 The Underworld | 3,342 | 478 to 966 | 80 | 42 | 74 | 64 | 56 | 49 | 43 | 37 | 33 |
| All ten | 30,164 |  | 720 |  | 670 | 580 | 503 | 444 | 387 | 335 | 302 |

- The Shallows are short: 22 seconds on a Common. Every other land is about a minute on a Common and 40 seconds on a
  Legendary.
- The whole lane is 11 minutes on Commons, 6.5 on Legendaries. Riding what each land mostly holds, about 7 minutes.

**Oxygen by land.** Drain a second on a Common, and the max Oxygen that keeps up (drain x KeepUp 6 / Refill 0.25). "Usual fish" is the land's own mix, weighted. Hop-hop is a rider who hops again the moment the cooldown ends (0.3 s on each fish): the hop itself drains nothing. Start max is 100.

| Land | Drain /s | x the land before | Needs (Common) | Needs (usual fish) | Needs (rarest there) | Needs hopping every 3 s | Needs hop-hop | Seconds a full 100 lasts, no hops |
|---|---|---|---|---|---|---|---|---|
| 1 Shallows | 1.0 |  | 24 | 26 | 39 (Legendary) | 12 | 2 | 100.0 |
| 2 Coral Reef | 4.0 | x4.0 | 96 | 115 | 154 (Legendary) | 48 | 5 | 25.0 |
| 3 Kelp Forest | 14 | x3.5 | 336 | 426 | 538 (Legendary) | 168 | 17 | 7.1 |
| 4 Shipwrecks | 48 | x3.4 | 1,152 | 1,541 | 1,844 (Legendary) | 576 | 58 | 2.1 |
| 5 Open Blue | 160 | x3.3 | 3,840 | 5,378 | 6,720 (Mythic) | 1,920 | 192 | 0.6 |
| 6 Twilight | 500 | x3.1 | 12,000 | 17,616 | 21,000 (Mythic) | 6,000 | 600 | 0.2 |
| 7 Midnight | 1,500 | x3.0 | 36,000 | 55,384 | 63,000 (Mythic) | 18,000 | 1,800 | 0.1 |
| 8 Vents | 4,500 | x3.0 | 108,000 | 169,560 | 189,000 (Mythic) | 54,000 | 5,400 | 0.0 |
| 9 Bone Graveyard | 13,000 | x2.9 | 312,000 | 500,605 | 546,000 (Mythic) | 156,000 | 15,600 | 0.0 |
| 10 The Underworld | 36,000 | x2.8 | 864,000 | 1,397,952 | 1,512,000 (Mythic) | 432,000 | 43,200 | 0.0 |

- "Needs" is the max Oxygen that just holds level if you land a hop every 6 seconds. It is what the HUD shows.
- The last two columns are the same land for a rider who hops more often. This is finding 3.

**By rarity.** A wild fish swims at Herd.SpeedShare 0.85 of its ridden speed. The hop off a fish: the pop at Jump.Launch 1.6 times the ridden speed, the glide at AirShare 0.85 of it, and the pull-in begins 1.7 s after the press.

| Rarity | Ridden | Step up | Wild (herd) | Pop | Glide | Hop carries (studs) | Drain x | Oxygen per 1,000 studs (Common = 1) | View widens (deg) | Turn circle (studs across) | Lands |
|---|---|---|---|---|---|---|---|---|---|---|---|
| Common | 45 |  | 38.2 | 72 | 38.2 | 78 | 1.00 | 1.00 | 4.4 | 54 | 1, 2 |
| Uncommon | 52 | +16% | 44.2 | 83 | 44.2 | 90 | 1.15 | 1.00 | 5.6 | 63 | 1, 2, 3, 4, 5 |
| Rare | 60 | +15% | 51.0 | 96 | 51.0 | 104 | 1.30 | 0.97 | 7.0 | 72 | 1, 2, 3, 4, 5, 6 (the mix asks for 1, 2, 3, 4, 5, 6, 7) |
| Epic | 68 | +13% | 57.8 | 109 | 57.8 | 117 | 1.45 | 0.96 | 8.4 | 82 | 1, 2, 3, 4, 5, 6, 7, 8, 9 |
| Legendary | 78 | +15% | 66.3 | 125 | 66.3 | 135 | 1.60 | 0.92 | 10.2 | 94 | 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 |
| Mythic | 90 | +15% | 76.5 | 144 | 76.5 | 155 | 1.75 | 0.88 | 12.2 | 109 | 5, 6, 7, 8, 9, 10 |
| Secret | 100 | +11% | 85.0 | 160 | 85.0 | 173 | 1.90 | 0.85 | 14.0 | 121 | nowhere |

**The ladder: closing speed.** Studs a second a rider gains on a wild fish ahead (ridden speed minus the wild fish's pace). Negative: the wild fish pulls away, and can only be caught if it starts within reach or comes up from behind. Reach is Jump.GrabRange 130 studs.

| Riding a \ wild | Common | Uncommon | Rare | Epic | Legendary | Mythic | Secret |
|---|---|---|---|---|---|---|---|
| Common | +7 | +1 | -6 | -13 | -21 | -32 | -40 |
| Uncommon | +14 | +8 | +1 | -6 | -14 | -24 | -33 |
| Rare | +22 | +16 | +9 | +2 | -6 | -16 | -25 |
| Epic | +30 | +24 | +17 | +10 | +2 | -8 | -17 |
| Legendary | +40 | +34 | +27 | +20 | +12 | +2 | -7 |
| Mythic | +52 | +46 | +39 | +32 | +24 | +14 | +5 |
| Secret | +62 | +56 | +49 | +42 | +34 | +24 | +15 |

- Read a row: riding a Common, you gain 7 studs a second on a wild Common, 1 on an Uncommon, and a Rare pulls away.
- So a fish one rarity up never comes closer, and anything rarer leaves you behind. You only get onto a rarer fish
  when it starts within reach or comes up from behind.

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

### What a rider meets
Played through the herd by the model, with endless air, all ten lands.

**Played through the herd, endless air: nearest fish, a hop every 6 s.** 40 dives. Fish of each rarity that came within reach (Jump.GrabRange) a minute, by land; then the seconds into the dive at which the first of each rarity did.

| Land | Seconds in it | Common | Uncommon | Rare | Epic | Legendary | Mythic | Secret | All |
|---|---|---|---|---|---|---|---|---|---|
| 1 Shallows | 19 | 36.0 | 10.4 | 1.2 | 0.1 | 0.1 |  |  | 47.8 |
| 2 Coral Reef | 53 | 5.9 | 16.7 | 4.5 | 0.4 | 0.2 |  |  | 27.7 |
| 3 Kelp Forest | 46 | 0.2 | 16.7 | 14.5 | 1.9 | 0.3 |  |  | 33.7 |
| 4 Shipwrecks | 49 |  | 7.8 | 19.0 | 7.4 | 0.6 |  |  | 34.9 |
| 5 Open Blue | 46 |  | 2.4 | 18.5 | 13.4 | 1.9 | 0.1 |  | 36.4 |
| 6 Twilight | 46 |  | 0.2 | 9.9 | 17.3 | 6.2 | 0.3 |  | 33.9 |
| 7 Midnight | 47 |  |  | 0.6 | 19.0 | 15.3 | 0.6 |  | 35.5 |
| 8 Vents | 39 |  |  |  | 12.9 | 23.2 | 0.9 |  | 37.0 |
| 9 Bone Graveyard | 45 |  |  |  | 3.3 | 33.8 | 2.4 |  | 39.4 |
| 10 The Underworld | 38 |  |  |  | 0.1 | 38.8 | 3.3 |  | 42.3 |

First within reach (the middle dive): Common 0 s (40 of 40 dives); Uncommon 2 s (40 of 40 dives); Rare 26 s (40 of 40 dives); Epic 93 s (40 of 40 dives); Legendary 144 s (40 of 40 dives); Mythic 303 s (39 of 40 dives).
Time ridden by rarity: Common 8%, Uncommon 14%, Rare 21%, Epic 23%, Legendary 30%, Mythic 3%. The dive took 7.1 minutes on average; ended: the lane's end 38, missed every fish 2.

**Played through the herd, endless air: rarest fish in reach, a hop every 6 s.** 40 dives. Fish of each rarity that came within reach (Jump.GrabRange) a minute, by land; then the seconds into the dive at which the first of each rarity did.

| Land | Seconds in it | Common | Uncommon | Rare | Epic | Legendary | Mythic | Secret | All |
|---|---|---|---|---|---|---|---|---|---|
| 1 Shallows | 18 | 42.2 | 10.6 | 1.8 | 0.1 | 0.1 |  |  | 54.7 |
| 2 Coral Reef | 47 | 8.1 | 24.8 | 8.6 | 1.0 | 0.1 |  |  | 42.5 |
| 3 Kelp Forest | 42 | 0.3 | 22.5 | 17.4 | 4.1 | 0.6 |  |  | 45.0 |
| 4 Shipwrecks | 43 |  | 10.3 | 23.3 | 11.7 | 1.3 |  |  | 46.7 |
| 5 Open Blue | 42 |  | 2.7 | 23.3 | 18.2 | 3.4 | 0.2 |  | 47.7 |
| 6 Twilight | 42 |  | 0.1 | 12.2 | 20.7 | 9.4 | 0.5 |  | 43.0 |
| 7 Midnight | 44 |  |  | 0.5 | 21.2 | 18.8 | 0.6 |  | 41.2 |
| 8 Vents | 37 |  |  |  | 14.9 | 25.4 | 1.5 |  | 41.9 |
| 9 Bone Graveyard | 43 |  |  |  | 3.9 | 36.7 | 2.2 |  | 42.8 |
| 10 The Underworld | 37 |  |  |  | 0.2 | 38.0 | 2.8 |  | 41.1 |

First within reach (the middle dive): Common 0 s (40 of 40 dives); Uncommon 2 s (40 of 40 dives); Rare 19 s (40 of 40 dives); Epic 71 s (40 of 40 dives); Legendary 123 s (40 of 40 dives); Mythic 265 s (40 of 40 dives).
Time ridden by rarity: Common 3%, Uncommon 10%, Rare 17%, Epic 22%, Legendary 40%, Mythic 7%. The dive took 6.6 minutes on average; ended: the lane's end 38, missed every fish 2.

- About 30 to 50 fish a minute come within reach in every land. There is always something to hop to.
- A rider who takes whatever is nearest still spends half the dive on Epics and Legendaries, because the deep lands
  hold little else.

**A new player's dive: how far the starting Oxygen goes.** Start max 100, Endless air off. Each line is a rider and how often small props are hit (each takes Props.Cost 0.03 of max). 40 dives each. The last columns: fish of that rarity that came within reach in one dive, on average.

| Rider | Props | Lasts (s) | Studs | Ends in land | Hops landed | How it ended | Rare in reach | Epic in reach | Legendary in reach | Mythic in reach |
|---|---|---|---|---|---|---|---|---|---|---|
| nearest fish, a hop every 6 s | none | 79 | 4,235 | 3 | 9 | out of Oxygen 40 | 5.5 | 0.6 | 0.2 | 0.0 |
| nearest fish, a hop every 6 s | one every 2.5 s | 74 | 3,989 | 2 to 3 | 8 | out of Oxygen 40 | 4.8 | 0.5 | 0.1 | 0.0 |
| rarest fish in reach, a hop every 6 s | none | 69 | 4,212 | 3 | 8 | out of Oxygen 40 | 7.9 | 0.9 | 0.2 | 0.0 |
| rarest fish in reach, a hop every 6 s | one every 2.5 s | 66 | 3,976 | 2 to 3 | 7 | out of Oxygen 40 | 6.7 | 0.8 | 0.1 | 0.0 |
| rarest fish in reach, a hop every 2 s | none | 82 | 5,479 | 2 to 3 | 18 | out of Oxygen 38, missed every fish 2 | 15.7 | 2.6 | 0.4 | 0.0 |
| rarest fish in reach, a hop every 2 s | one every 2.5 s | 78 | 5,132 | 2 to 3 | 17 | out of Oxygen 39, missed every fish 1 | 13.3 | 2.4 | 0.5 | 0.0 |
| nearest fish, hop-hop (0.3 s on each fish) | none | 109 | 7,286 | 3 to 5 | 40 | out of Oxygen 39, missed every fish 1 | 21.6 | 5.2 | 1.0 | 0.0 |
| nearest fish, hop-hop (0.3 s on each fish) | one every 2.5 s | 105 | 6,935 | 2 to 5 | 38 | out of Oxygen 38, missed every fish 2 | 20.7 | 4.1 | 0.9 | 0.0 |

- The Kelp Forest begins 3,855 studs down. Every rider who hops at an easy pace dies just inside it.
- The rider who never stops hopping gets to about 7,300 studs: into the Shipwrecks, sometimes the Open Blue.
- In one such dive at an easy pace: 5 to 8 Rares within reach, an Epic in most dives, a Legendary in one dive of six.
- Props hit every 2.5 seconds shorten the dive by about 5 seconds: the third land's door ends it either way.

## What is off, and what I would change
Each line is old to new, then why. "Guess" marks a number with nothing measured behind it.

### Speed
Ride a Dino's ride, measured off its distance counter through one jump: 54 riding, 46 floating over the herd
([the reference](../reference/ride-a-dino.md), "Speed through one jump"). That is one jump, and it takes one of its
metres for one of our studs, which is a guess.

| Rarity | Today | Proposed | Why |
|---|---|---|---|
| Common | 45 | 54 | The reference's ride. Our glide is 0.85 of the ridden speed, so it goes from 38 to 46: the reference's float. Hugo found the air too slow at 38. |
| Uncommon | 52 | 58 | Steps of about 8% in place of 15% |
| Rare | 60 | 63 | |
| Epic | 68 | 68 | |
| Legendary | 78 | 74 | |
| Mythic | 90 | 81 | |
| Secret | 100 | 88 | No Secret spawns yet. At 100 the hop carries you 173 studs before the pull-in begins, past the 130 you can grab from; at 88 it is 152. |

- **Why smaller steps.** Wild fish swim at 0.85 of their ridden speed, and 0.85 times a 15% step is 0.98. So the next
  rarity up swims as fast as you ride. With 8% steps you gain 4 or 5 studs a second on it, a fish two rarities up
  keeps pace, and three up pulls away. In the model (8 dives each way, so rough) the first Epic comes within reach
  after about 60 seconds in place of 90, and the first Legendary a little sooner too.
- **What it costs.** A step of 8% is hard to feel by itself (guess). The view widens by 14 degrees between speed 20
  and 100, so one step of rarity is about 1 degree either way. The feeling of speed would come from two or three
  steps, and from the deeper lands being faster as a whole: the usual ride goes from 55 in the Shallows to 75 in the
  Underworld.
- **The other way,** if the user wants big steps that are felt: keep 45 to 100 and let every wild fish in a land swim
  at one pace, whatever its rarity. Then any fish ahead can be caught. That is code (the herd and the glide), not a
  number, so it is the overseeing chat's.
- **A whole dive hardly changes:** about 6.5 minutes down all ten lands, against 7.
- **To check in play:** the model's rider missed every fish a little more often with the new speeds (1 to 3 dives of
  8, against 0 or 1). Fish closer in speed may bunch up. Worth a look.
- **Status:** not applied. The seven speeds are rows on the N panel (`TierSpeed`), to play both ways.

### Rarer means faster and dearer: is that the right trade?
The idea is right. The numbers don't make it a trade.

| What | Today | Proposed | Why |
|---|---|---|---|
| A rarity's Oxygen a second, against a Common | 1, 1.15, 1.3, 1.45, 1.6, 1.75, 1.9 | 1, 1.8, 3.3, 6, 11, 20, 36 | In the reference one step of rarity is worth about half a zone: in its second zone an Uncommon needs 50 stamina, a Rare 130, an Epic 230, a Legendary 752, and the same rarity needs 5 times more a zone on. Ours is worth a seventh of a land. |
| `ZoneDrain`, lands 1 to 10 | 1, 4, 14, 48, 160, 500, 1,500, 4,500, 13,000, 36,000 | 0.8, 2, 5.5, 15, 40, 100, 250, 700, 1,800, 4,800 | Only if the line above is taken. It keeps what each land needs on its usual fish where Hugo put it (26, 114, 430, 1,540, 5,300 ... 1.4 million), because the deep lands' usual fish are Legendaries. |

- **What it does for a new player.** In the Coral Reef on 100: a Common needs 48 and an Uncommon 87, so those hold. A
  Rare needs 159, an Epic 288, a Legendary 528. The Reef is full of fish you can see and can't keep yet, and each is a
  reason to train. Today the only wall is the third land's door.
- **The first line needs three lines of code:** today the drain is a straight line (`Oxygen.TierDrain` for each
  step), which can't make that shape. It wants a table with one number a rarity. The overseeing chat's.
- **To feel it today with no code:** on the N panel set `Oxygen.TierDrain` from 0.15 to 1. A Legendary then takes 5
  times a Common. The model with that: the first dive ends in the Coral Reef, not the Kelp Forest, since the Reef's
  usual fish then need 217.
- **Status:** not applied. It changes the shape of the game, so it waits for the user (question 2).

### The Oxygen curve
- **The need assumes a hop every 6 seconds** (`Oxygen.KeepUp`). The hop itself drains nothing, and every landing on
  another fish gives a quarter of max back. So hopping every 3 seconds halves what a land needs, and hopping the
  moment the cooldown ends (0.3 seconds on each fish) cuts it to a twentieth: 2, 5, 17, 58, 192 for the first five
  lands. With the pull-in starting by itself, that is just holding a rhythm on Space. The HUD's "needs N OXYGEN" is
  then wrong by up to 20 times, and training is worth less than fast fingers.
- **Proposed (code, the overseeing chat's):** the refill is for the time you rode. A landing gives back
  `Refill` x max x (seconds ridden on the fish you left / `KeepUp`), at most `Refill` x max. Then a land needs the
  same max Oxygen however often you hop, the HUD's number is true, and a hop still always gives something. Otherwise:
  leave it as the game's skill, and fit the curve to players who hop without stopping. The user's call (question 3).
- **Start 100 against the lands' 24, 96, 336:** right as it is. Two lands on the first dive, a wall at the third.
- **The steps between lands** (4 times, then 3.5, down to 2.8): keep. On each land's usual fish the last land needs
  1.4 million. The reference: 5 times a zone, and "millions" at the end.
- **Floating off a fish, `Oxygen.FreeDrain` 4 a second:** a fixed amount, so 25 seconds on the starting 100 and three
  days on a million. It should be a share of max (4% a second is the same 25 seconds for everyone). Code, small, later.

### Props
- **A small prop costs 3% of max Oxygen** (`Props.Cost`), and the play tests hit one every 2 or 3 seconds in the
  Shallows. That is 1.2% of max a second. The Shallows themselves take 1% a second from a new player and far less from
  a trained one. So props cost more than the land, at every level, for ever: a share of max never gets cheaper.
- At a hop every 6 seconds, props eat 7 of the 25 points a landing gives. Every land then needs 1.4 times what the
  HUD says. On 100, the Coral Reef goes from just holding to running dry.
- **Proposed:** `Props.Cost` 0.03 to 0.01. Breaking things is the fun part and gives nothing, so it should cost
  little. The number is the overseeing chat's and Hugo's ("running into something costs stamina" is his decision), so
  this is a proposal to them.

### How often each rarity spawns
- **Lands 1 and 2 match the reference** and stay. In its first zone the recording shows Commons and Uncommons and
  nothing rarer; in its second, mostly Uncommons, Rares often, an Epic now and then, one Legendary in two runs. Ours:
  0.7 of a Legendary standing in the Coral Reef. It swims faster than a new player rides, so it is seen ahead more
  often than it is reached.
- **The first ten minutes** (about six dives of 75 seconds): the first Rare within reach after about 25 seconds; an
  Epic in most dives; a Legendary within reach in about one dive of six, so about once. That is close to the
  reference's pace for seeing them. What is missing is the reason to come back for them (the trade above, and taming).
- **Something to chase in every land:** yes for seeing. Each land has a rarity that is 1 to 5% of its fish. From the
  Vents on, the Legendary is the common fish and the Mythic (5 to 12%) is the chase. Secrets never spawn: they are
  meant as server events, and no rule for them exists.
- **Lands 3 to 10 are still the roster's guess.** I have nothing measured to move them with, so I leave them. The
  shares are on the N panel now (one group a land).
- **Small thing:** the roster says Commons only reach the start of the Coral Reef. The game spreads them over all of
  it (7 of its 68 fish).

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

The creature import is already planned ([creature import](creature-import.md)) and waits for the user's picks.
Nothing here asks to change a creature's rarity or land.

## What changed with this note
- **No tuning number changed.** Speeds are a matter of feel, and the Oxygen changes above alter the shape of the game.
  Both wait for the user.
- **New rows on the N panel** (`SandboxController`): the ridden speed of each rarity (`TierSpeed`), `Oxygen.StartMax`,
  and the share of each rarity in each land (`MixShallows` to `MixUnderworld`).
- **Config, to carry those rows:** `Config.TierSpeed` (the speeds again as plain numbers, filled from `Config.Tiers`)
  and ten names for the ten rows of `Config.ZoneMix`. `Config.refresh` now puts a changed speed into every fish of
  that rarity, so wild fish, the glide and the server's speed check follow at once.
- StyLua, selene and `rojo build` pass. Not played, and not type-checked (no luau-lsp on this PC).

### The panel
| Number | Row | Live? |
|---|---|---|
| Ridden speed by rarity | `TierSpeed` Common to Secret | Yes, on fish already swimming too |
| Oxygen a second by land | `ZoneDrain` land 1 to 10 (was there) | Yes |
| `Oxygen.Refill`, `KeepUp`, `TierDrain`, `FreeDrain` | were there | Yes |
| `Oxygen.StartMax` | new | Not yet for a player already in the game: the server reads a player's max only when they join. Until `SandboxService` asks `RideService` to read it again, use Workspace's `TestMaxOxygen` |
| Share of spawns by rarity | `MixShallows` ... `MixUnderworld` | For fish spawned from then on. Fish already swimming stay until the herd replaces them |
| `ReachWeight` | not on the panel | The game works out who can spawn where once, at the start |

"Copy changes" lists a changed speed as `Config.TierSpeed.Common = 54`. It is written into `Config.Tiers`.

## Not built yet
Proposals. None of it is built until the user says so.

### The smallest thing that lets the progression be played
**Max Oxygen has to grow.** The smallest version: a training spot on the dock (the machine's place). Standing on it
adds to your max Oxygen every second. The server keeps it for the session; no saves yet. One number, `Train.Rate`.

**What training would have to give.** The plan is a guess (PLAN_MINUTES in the model, --plan to change it): the minutes of play at which a player should first be able to ride each land on its usual fish. From it, the max Oxygen wanted by then and the gain a second of ALL play time between two lands that gets there.

| Land | Wanted by (min) | Max Oxygen needed | Gain needed over the stretch | A second of play | x the stretch before |
|---|---|---|---|---|---|
| 1 Shallows | 0 | 26 | none |  |  |
| 2 Coral Reef | 0 | 115 | 15 |  |  |
| 3 Kelp Forest | 10 | 426 | 311 | 0.52 |  |
| 4 Shipwrecks | 25 | 1,541 | 1,115 | 1.24 | x2.4 |
| 5 Open Blue | 50 | 5,378 | 3,837 | 2.56 | x2.1 |
| 6 Twilight | 90 | 17,616 | 12,238 | 5.10 | x2.0 |
| 7 Midnight | 150 | 55,384 | 37,768 | 10.49 | x2.1 |
| 8 Vents | 240 | 169,560 | 114,176 | 21.14 | x2.0 |
| 9 Bone Graveyard | 360 | 500,605 | 331,045 | 45.98 | x2.2 |
| 10 The Underworld | 540 | 1,397,952 | 897,347 | 83.09 | x1.8 |

- The plan in the second column is my guess at a pace (question 5). The last columns are what follows from it: the
  gain has to about double from each land to the next, from half a point a second to 80.
- If a third of play is spent training, the machine has to give three times that: 1.5 a second at first.
- **Proposed start:** `Train.Rate` 1.5 a second. Then machine levels that each give 2.2 times the last (the
  reference's goes from +15 to +36 a second, 2.4 times, for 20 times the price), about one level a land. Auras (the
  reference's 1.5, 2, 2.5 and 3 times) on top. All guesses until it is played.

### What taming would need from these numbers
- Decided already: stay on a wild fish long enough and it is yours ([the dive](the-dive.md)).
- **Proposed:** a time to tame for each rarity, and the fish's tag shows the Oxygen that takes: its drain a second
  times its tame time. That gives "Required" the meaning the reference's tag has: a number you train toward for
  that one fish. With the dearer rarities above and tame times of 3, 4, 6, 8, 12 and 16 seconds (guess), a Reef
  Uncommon would need 14 Oxygen and a Reef Legendary 264.
- From here it needs: the drain by rarity (question 2) and the tame times.

### What income and prices would need
- **Income by how cool a creature is** (decided). Proposed: a creature earns in line with what it costs to hold, so
  the same steps as the drain: by rarity (1, 1.8, 3.3, 6, 11, 20, 36) and by land (about 2.6 times a land).
- **Prices** follow from the pace: a machine level costs so many minutes of a full base's income from the land it
  opens (guess: 10 minutes). The reference keeps 7 creatures earning at once.
- From here it needs: the pace (question 5), then one table of prices.
- Sizes and mutations multiply both the cost and the income (the reference: 0.8, 1.2 and 1.5 times by size).

## Questions for the user
1. **"The level":** do you mean a level on each fish (it grows as you ride or keep it), a level on the player, or
   simply the land you have reached? No note defines one.
2. **Should a rarer fish cost clearly more Oxygen to hold,** so you see a Legendary early but can't keep it until you
   have trained? (Ride a Dino: 15 times an Uncommon's in the same zone. Ours: 1.4 times.)
3. **Hopping without stopping makes every land 20 times cheaper in Oxygen.** Keep that as the skill of the game, or
   should a landing give back Oxygen for the time you rode, so the rhythm stops mattering?
4. **Speed:** try the Common at 54 (the reference's ride; ours is 45) with smaller steps up to 88, or keep 45 to 100?
   Both can be played from the N panel.
5. **The pace:** how long should a new player take to first ride land 3, land 5 and land 10? (My guess: 10 minutes,
   50 minutes, 9 hours.) And does the first version still ship lands 1 to 4 only?
6. **May the game-code chat build the training spot** (max Oxygen grows while you stand on it), so the progression
   can be played at all?
