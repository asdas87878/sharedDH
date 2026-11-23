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
  StyLua and selene; its licence in `docs/licenses/`). Each service gives what it keeps (`SaveService.part`); all of it
  is taken together or none. **No service is joined yet, so it does nothing:** it needs the tank (coins, stage, fish),
  the trained Oxygen, the trainer's level and the subs, or what was bought with a pack would be gone on leaving.
- **The payout:** `PurchaseService`, the one `ProcessReceipt`. A receipt is given once and Roblox is told so only when
  the profile is seen saved. It needs `AquariumService.give` to say true when given, and a `RideService.grant` that
  works off the dock (asked of the game-code chat).
- **On sale** is an offer in `Products` with an `Id`, `Gives` and `Amount` (`Products.onSale`). The Shop then shows the
  amount as the card's name and Roblox's own price, and asks for the prompt only once the player's save is in.
- **Wanted from the user:** the six developer products made on Roblox (their ids; their prices are read from Roblox), and
  the six amounts (the tuning chat is drafting them).
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
