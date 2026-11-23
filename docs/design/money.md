# Money and Robux

> **Studies, 2026-11-16.** Everything the reference sells, where it puts each offer, and what creators said as they paid: [Ride a Dino](../reference/ride-a-dino-deep.md), section 3. The rules to work by: [findings](../Findings.md), rank 4, "Money".

## Decided
- **Income** comes from the creatures in your base and buys stamina boosts.
- **The budget (the user, 2026-11-16):** about 500 dollars on the Robux to publish, and 100 to 150 dollars or
  more on adverts. "A very big expense for us ... quite a big risk." So the game keeps its money in mind from the
  start, and **the aim is to break even on the spending.**

- **Cash and Oxygen go on sale for Robux now, with saving (the user, 2026-11-23: "yes.").** See "Selling".

## Selling (started 2026-11-23)
- **Saving:** `SaveService`, on ProfileStore (`src/server/Lib/ProfileStore`, commit 45c9847, kept as it came: outside
  StyLua and selene; its licence in `docs/licenses/`). What is kept is `Lib/SaveParts`: the tank (coins, stage, fish), the trained Oxygen,
  the trainer's level, the subs and the best depth, all taken together or none, with a version from the first save.
  **Its switch (`ON` there) is off**, and without every function it needs in the services it joins nothing.
  The game-code chat writes those functions (2026-11-23, its word), reviews the two services, and they are played with
  Roblox's real store before the switch goes on.
- **The payout:** `PurchaseService`, the one `ProcessReceipt`. A receipt is given once and Roblox is told so only when
  the profile is seen saved. Coins by `AquariumService.give`, Oxygen by `RideService.grantOxygen` (theirs to write).
  **Oxygen that arrives in the water waits for the dock (the user, 2026-11-23: "At the dock"), with no refill ("Yes, no
  refill")**: it is saved at once (`Banked` in RideService) and joins the max there. A max raised mid-dive would put the meter in the red.
- **On sale** is an offer in `Products` with an `Id`, `Gives` and `Amount` (`Products.onSale`). The Shop then shows the
  amount as the card's name and Roblox's own price, and asks for the prompt only once the player's save is in.
- **Wanted from the user:** the six developer products made on Roblox (their ids; their prices are read from Roblox), and
  the six amounts (the tuning chat is drafting them).
- **Carried fish are kept (2026-11-23, this chat with the game-code chat).** They are saved with the tank and come back
  stored in it. A catch comes home on a death too, so leaving mid-dive gains nothing. Built in `SaveParts`, not run yet.
- **The packs are fixed amounts, with bulk deals that are very good for mid and late players (the user, 2026-11-23: "fixed
  amounts, bundle deals are just very good for mid-late game players still tho", then "bulk deals i mean").** So the
  bigger the pack, the far better its rate. The amounts are open; a fixed draft is asked of the tuning chat.
- **The fixed ladder, the tuning chat's draft 2 (2026-11-23; proposed, not agreed).** Modelled, not played: medians of 5
  seeds, one pack, once. FULL: with auras and the Index (neither built, the Index's payouts a fit); OFF: the same model
  without them, the nearest to the game now. Which land a fresh account holds at once is the same in both. Robux prices
  are a guess beside theirs (59 to 2,249; 45 to 720).

  | Robux | Oxygen | rate | for a player holding | time to the next land, FULL; OFF | a fresh account holds at once (free, FULL; OFF) | land 10 at (free 31.3; 199.5 h) |
  |---|---|---|---|---|---|---|
  | 59 | 50K | x1 | 3 to 4 | 14 to 9 min; 39 to 30 | land 4 (15; 28 min) | 31.1; 199.1 h |
  | 149 | 500K | x4 | 5 | 40 to 18 min; 112 to 76 | land 5 (28; 67 min) | 30.5; 198.3 |
  | 349 | 5M | x17 | 6 | 82 to 9 min; 5.1 to 2.7 h | land 6 (69 min; 3 h) | 29.4; 195.0 |
  | 699 | 60M | x101 | 7 | 150 to 2 min; 15.1 to 3.4 h | land 7 (2.5; 8.1 h) | 26.2; 184.1 |
  | 1,199 | 800M | x787 | 8, 9 | land 8: 8.7 h to 0; 48.6 h to 0. Land 9: 17.6 to 9.4 h; 127.6 to 100.4 | land 9 (13.7; 71.9 h) | 14.0; 130.0 |
  | 2,249 | 10B | x5,250 | 9, 10 | land 9: 17.6 h to 0; 127.6 h to 0. Land 10 to 20B: 38.4 h to 42 min; 219 to 91 h | land 10 (31.3; 199.5 h) | at once |

  | Robux | Cash | rate | for a player holding | time to the next land, FULL; OFF | a fresh account: land 7 / land 10, FULL; OFF (free 152 min / 31.3 h; 8.1 / 199.5 h) |
  |---|---|---|---|---|---|
  | 49 | $1M | x1 | 3 | 10 to 4 min; 18 to 12 | 142 min / 31.1 h; 7.9 / 199.3 h |
  | 99 | $25M | x12 | 4 | 14 to 7 min; 39 to 31 | 125 min / 30.9; 7.6 / 199.0 |
  | 199 | $1B | x246 | 5 | 40 to 17 min; 112 to 93 | 94 min / 30.4; 6.7 / 198.1 |
  | 399 | $50B | x6,100 | 6 | 82 to 32 min; 5.1 to 4.4 h | 36 min / 29.0; 5.1 / 194.9 |
  | 699 | $2T | x140K | 7 | 150 to 58 min; 15.1 to 12.6 h | 15 min / 25.3; 2.0 / 184.8 |
  | 1,299 | $75T | x2.8M | 8, 9 | land 8: 8.7 to 2.8 h; 48.6 to 14.7 h. Land 9: 17.6 to 6.1 h; 127.6 to 106 h | 7 min / 10.0 h; 20 min / 123 h |

  - *Plainly:* the last three Oxygen packs each skip a whole land for the player they are for, and 10B bought in the first
    minute skips the whole climb (it holds 91% of land 10's plain spawns; two hold all). The reference's do too.
  - *At land 10 no cash pack here is very good* ($75T: 38.4 to 35.2 h; 219 to 215). $10Qa would be, but puts a fresh account in
    land 10 at 2.2 h (49 h OFF): left out, Oxygen is the land 10 pack.
  - *Other choices:* theirs x8 (1.2M, 8M, 80M, 400M, 4B, 8B: top rate x175, far stronger small packs). Its proposal: 800M
    from land 7, $75T from land 8, 10B from land 9 only, the amounts still fixed; the server gives any receipt it gets.
  - *Past 50B of max Oxygen tames take 1.5 times longer* (`Tame.CapSlow`): from the fifth top pack.
- **Not picked: the tuning chat's first draft (2026-11-23), kept for its measurements.**
  They grow with the player, in steps: by the deepest land whose commonest fish their max Oxygen can hold. Oxygen S / M /
  L is 0.25 / 0.5 / 1.5 times that land's need; Cash is 1 / 3 / 8 hours of what the modelled tank earns on arriving.

  | Land held | Oxygen S / M / L | Cash S / M / L |
  |---|---|---|
  | Robux (a guess) | 79 / 149 / 399 | 49 / 129 / 299 |
  | 1 to 3 | 8,800 / 17,500 / 52,000 | 500K / 1.5M / 4M |
  | 4 | 8,800 / 17,500 / 52,000 | 5M / 15M / 40M |
  | 5 | 56,000 / 110,000 / 340,000 | 63M / 190M / 500M |
  | 6 | 430,000 / 860,000 / 2.6M | 700M / 2.1B / 5.6B |
  | 7 | 3.1M / 6.1M / 18M | 6.6B / 20B / 53B |
  | 8 | 22M / 44M / 130M | 55B / 165B / 440B |
  | 9 | 160M / 320M / 970M | 660B / 2T / 5.3T |
  | 10 | 1.2B / 2.3B / 7B | 5.9T / 18T / 47T |
  | 34B Oxygen | 8.5B / 17B / 51B | 30T / 90T / 235T (a fit) |
  | 250B Oxygen | 63B / 125B / 375B | 150T / 450T / 1.2Qa (a fit) |

  - *Modelled, not played, with auras and the Index (neither is built):* minutes to the next land with no pack, then
    Oxygen S / M / L, then Cash S / M / L: land 4: 14; 14 / 12 / 6; 9 / 6 / 6. Land 6: 81; 74 / 64 / 46; 73 / 60 / 41.
    Land 7: 150; 133 / 117 / 60; 147 / 136 / 136. Land 8: 520; 488 / 447 / 300; 504 / 493 / 478. Land 9: 1,054;
    954 / 860 / 456; 1,028 / 986 / 952. The set was not run on the game as it is now, where the lands take far longer.
  - *Wrong, corrected by the tuning chat the same day: "cash is weak from land 7" (2 to 10% of the time).* Its test stopped
    just short of the next seahorse level. Cash works in rungs: $75T takes land 9 from 17.6 to 6.1 h. *A bigger L is
    dangerous:* 3 times the need took land 9 from 17.6 h to 22 minutes. The tuning chat would fix the amounts only once
    auras and the Index are decided. Whether an aura multiplies a bought pack is Hugo's (draft 2: no; his Auras text:
    "all Oxygen gained").
  - *The build:* fixed amounts are what the code has (one `Amount` an offer).
- **Not run in Studio yet** (2026-11-23: another chat had it); StyLua, selene and the Rojo build pass.

## What breaking even takes
Worked out 2026-11-16 from Roblox's own pages (read that day). The 30% is from memory; check it.

| | |
|---|---|
| Spent | About 600 to 650 dollars |
| What a Robux earned in the game is worth | 0.0038 dollars (30,000 earned Robux = 114 dollars) |
| Earned Robux to get the money back | About 158,000 to 171,000 |
| What players must spend for that | About 225,000 to 245,000 Robux, since Roblox keeps about 30% of a sale |
| As one product | About 1,130 to 1,230 sales of a 199-Robux pass |
| The least that can be cashed out | 30,000 earned Robux |

- **Only earned Robux can be turned into money.** Robux that were bought can't. So if the 50,000-Robux fee comes
  back, it comes back as Robux to spend on Roblox, not as dollars.
- **So Robux can't be last any more.** A small shop belongs in the first public version: see
  [the refinement](../Refinement.md), "What the studies change". What the reference teaches about selling:
  [findings](../Findings.md), rank 4, "Money".

## Ideas not agreed
- **Spending income on:** auras (stamina multipliers), training machine upgrades, tank upgrades, the sub to deeper zones.
- **Robux, after the reference's set:** a timed 2x money boost, a limited-time starter pack, a 2x stamina pass, + buttons to buy
  stamina or cash, revives after the free ones, auras and machine upgrades for Robux as well as cash, the sub.
- **Selling** creatures you don't keep, for cash.

## Open
- Prices and the curve: how long from the first creature to a Megalodon.

## What Roblox's public lists say about the odds (2026-11-16)
A trial the user asked for, "just for my curiosity": 23,014 games found through Roblox's public search across 111
kinds of game, with each one's date, visits and players. Scripts: `C:\Users\blast\ConceptScout\odds.py` and
`odds_report.py`.

- **It can't give a true base rate.** Search shows only games that already found players: of games made this
  month, 2% have under 1,000 visits. The failures are not in it. So every figure below is "of the games that got
  off the ground", and the real chance is lower.
- **Of those, made June to mid-October by a maker with no earlier hit:**

| | Games | Passed 100,000 visits | 300,000 | 1 million | Still 200 or more players |
|---|---|---|---|---|---|
| Owned by one user | 771 | 46% | 30% | 16% | 12.5% |
| Owned by a group | 6,212 | 63% | 47% | 31% | 17% |

- **Our kind is the most crowded and does worst.** Half of everything found is "Incremental Simulator" or
  "Tycoon". For a single new maker those reach 1 million 7 to 8 times in 100. Vehicle games (46 in 100, only 24
  games), fighting (29) and escape games (24) do far better.
- **Being late costs most.** Followers of a verb ("steal a", "throw", "kick a" and seven more), by how long after
  the family's biggest game they were made: within 60 days, 39 to 49 in 100 reach 1 million; after 120 days, 17.
  "Ride a" followers made over 90 days after their leader: 14 in 100.
- **Claude's reading, a judgement and not a measurement:** Ride a Fish as planned has about one chance in ten of
  earning the spending back. The best case found (a kind that does well, launched within two months of a rising
  leader, with the spending staged so little is at risk) is about one in four.
