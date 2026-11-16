# The loop, reviewed

> **Studies, 2026-11-16.** The Index is the active way to the stat, and it was put in the last wave here. The reference has no cap of seven. Its weakness is that nothing waits for tomorrow, which is where ours can be better. [Findings](../Findings.md), rank 1.

Up: [core loop](core-loop.md). Written 2026-11-16 by the game-code chat on the user's word: understand the game as a
whole, find where its mechanics don't connect, and say what to change so it feels better, flows, and keeps players.
From the code and notes as they stand, the user's Ride a Dino material, a survey of
[Roblox repos](../reference/roblox-repos.md) and of [Roblox development videos](../reference/roblox-videos.md).
**Everything under "Changes" is a proposal. Only the hop was changed.**

## The short version
1. **The game is half a loop.** The dive is built and good: ride, hop, read tags, tame. The other half is not
   there: a catch earns nothing, nothing is bought, nothing is saved. A player has no reason for a second dive that
   the first did not give.
2. **Progress comes from standing still.** Max Oxygen, the stat that opens every land, grows only on a pad in the
   hub: 78 seconds of standing for the second land, 5 minutes for the third. The fun part of the game does not move
   the player forward at all.
3. **The first five minutes are about 45 seconds of play.** A first dive is 15 seconds and ends on a wall with no
   warning. Then the pad.
4. **Several good mechanics pull against each other:** hopping beats riding, so the fish you ride hardly matters;
   taming wants you to stay and the wall wants you gone; the bag fills with the worst fish first; a tame at your
   limit is paid with a drowning.
5. **What was built this week has nothing to plug into yet:** 24 sizes and colours of every fish, grand fish,
   predators that come past. None is worth anything to a player until a catch has a value and a book to go in.
6. **The order to fix it:** save, then pay for catches, then spend on Oxygen, then script the first two minutes.
   Then the smaller rules that make the minute flow. Then the reasons to come back tomorrow.

**Since this was written, the same day:** the user said what a catch is for, and the aquarium was built: a tank
each, the deposit, the earning. That is changes 2 and 3 in part: [the aquarium](aquarium.md). The rest stands.

## The loop, designed and built
The design ([core loop](core-loop.md)): train Oxygen → dive and tame deeper fish → they earn in your base → the
income buys Oxygen → deeper.

| Step | Built? | What a player gets today |
|---|---|---|
| Ride a fish, steer, Oxygen draining | Yes | The meter, the fish's own speed, crashes, the wall ride |
| Hop fish to fish | Yes, tuned many times | The best thing in the game |
| Read a fish before landing | Yes | Tags: rarity, size, what it needs, red when too strong |
| A fish too strong throws you | Yes | A land is a wall: at home in one, nothing held in the next |
| Tame: 2 seconds on a fish you hold | Yes, for the session | A slot filled, an "it's yours" banner. Up to 7 |
| Abilities: bite, smash, tank, leap, burst | Yes, on 31 of 82 fish | A burst of speed or Oxygen |
| The sea: sizes, colours, paces, grand fish, predators | Yes | Looks and movement only |
| The dive ends | Partly | You drown and wake at the dock. A count of catches. No summary, no revive |
| Catches go to your base and earn | **No** | Nothing. The eight aquarium plots are scenery |
| Income buys Oxygen (machine, auras) | **No** | A pad: stand on it |
| Sell, fuse, the Index, the sub | **No** | |
| Saving | **No** | Everything is gone when you leave |
| The first minute (being shown what to do) | **No** | |
| Reasons to come back (offline income, daily, events) | **No** | |
| Robux | **No** | |

## Where the mechanics don't connect
Each with why it hurts and what would join it up.

1. **A catch is worth nothing.** Taming is the dive's goal and its reward is a number on the dock.
   - *Join:* every catch has a value: its land and rarity, times its size, times its colour. The numbers for size
     are already in `Config.SizeWorth` and nothing reads them.
2. **Oxygen grows on a pad.** The stat that gates everything is earned by not playing.
   - *Join:* Oxygen is bought with what the dive earns (the machine's levels, auras), and given by the Index for
     each new fish, size and colour. The reference's Index pays stamina for every new variant: in the user's
     screenshot one Bronto variant gives +73K. That is what makes a Silver Tiny worth chasing.
3. **The wall kills without warning.** A new player's dive ends 100 studs into the second land, on the first fish
   they touch, by a rule nobody has told them.
   - *Join:* show the wall. A gate at each land's border with the number it needs beside the player's own; red
     tags are already there but arrive mid-hop. And the first landing on a fish too strong could throw the player
     back to a fish they can hold, once, with a line of text, instead of ending the dive.
4. **Hopping beats riding.** Holding Space covers 2 to 3 times the ground of any fish. So the fish under you, its
   speed, its size, its ability, matter for 2 seconds at most, and "Ride a Fish" is mostly "leave a fish".
   - *Join:* make the seconds on a fish pay the hop. Proposed: **the hop off a fish you have just tamed is the big
     one** (more push and air than off one you only touched). Then staying for the ring, the thing taming already
     asks, is also how you travel furthest. One rule ties riding, taming and the hop together.
5. **Taming at your limit drowns you.** A fish right at your bar gives 2 seconds and the tame takes 2. In the
   tuning chat's model 32 first dives of 40 end on a fish just tamed.
   - *Join:* already decided in [the dive](the-dive.md) and not built: on a fish that is yours you fall off and
     float, with a few seconds to reach another.
6. **The bag fills with the worst fish.** Seven slots are full 28 seconds into a dive, before a trained player
   reaches their own land.
   - *Join:* a full bag keeps the best seven. With values (1) this needs no question: the cheapest is dropped.
7. **The dive has no end, only a death.** No "great dive", no best depth, no "so close".
   - *Join:* a summary: each catch with its size, colour and value, the depth against your best, what is new in
     the Index, and one button, dive again. This is also where a revive is offered.
8. **Size, colour, grand fish and predators mean nothing yet.** Built 2026-11-13 to 16, all looks.
   - *Join:* values and the Index (1, 2). A predator's visit could carry a mark and a sound so the player knows
     something worth catching is coming.
9. **Abilities end with the fish.** A bite gives a burst now and nothing after.
   - *Join:* later, once catches have value: a fish's ability could show on its card in the base and matter when
     it is the fish you start a dive on.
10. **Nothing is measured.** Nobody knows where a new player stops.
    - *Join:* Roblox's own analytics events on the steps of the first session (below).

## The first five minutes, as they play now
Worked out from the tuning chat's played dive and its training numbers ([progression](progression.md)).

| Time | What happens |
|---|---|
| 0:00 | Spawn on the dock. Nothing says what to do |
| 0:10 | Find the gate, dive in, land on a fish |
| 0:25 | Four or five fish later, the first landing in the Coral Reef throws you off. Drown. Dock |
| 0:30 | "3 caught", perhaps. Nothing to do with them |
| 0:30 to 1:50 | Stand on the pad until the Reef's fish can be held: 78 seconds |
| 1:50 to 5:00 | Dives of about a minute each, each ending at the third land's wall. Then 4 more minutes on the pad |

About 45 seconds of play in the first two minutes, and the longest single thing a new player does is stand still.

**What it should be** (the pattern of the reference, and of what the videos say about first sessions):

| Time | What happens |
|---|---|
| 0:00 | Spawn facing the gate, the herd in view through it, one line: dive in |
| 0:05 | On a fish. The first one is always one you can hold |
| 0:15 | First tame: "it's yours". A marker on the next fish |
| 0:35 | The dive ends at the Reef's gate, which shows the number it needs. Summary: 3 caught, coins, "new in your book: 3" |
| 0:45 | The fish are in your tank, earning. The machine's first level costs what the first dive paid |
| 1:00 | Second dive, with more Oxygen. It gets into the Reef |
| 2:00 | Third dive. The first Uncommon, or a Silver. A goal on screen: the next land, and what it takes |

## What keeps a player, and what we have of it
| Loop | Length | What it needs | We have |
|---|---|---|---|
| The hop | 2 to 3 seconds | A choice, a risk, a payoff | **Yes.** The lock, the tags, the meter, the pull-in |
| The dive | 15 seconds to a few minutes | A goal, a rising stake, an end that pays | Half: the stake rises, the end pays nothing |
| The session | 10 to 30 minutes | A next thing to buy, always in sight | **No** |
| Tomorrow | Days | Something that grew while away, something unfinished, something new | **No** |

## Changes, in order
Sizes are rough, in days of work for this chat.

### First: close the loop (nothing else counts until this is in)
| # | Change | Size |
|---|---|---|
| 1 | **Saving**, with ProfileStore: Oxygen, coins, the fish you own, the Index, the best depth | 1 to 2 |
| 2 | **A catch has a value** and the dive ends on a **summary** that pays it | 1 to 2 |
| 3 | **The tank:** your best fish swim in your plot and earn every second, and while you are away (capped) | 2 to 3 |
| 4 | **Oxygen is bought:** the machine's levels and auras replace standing on the pad. Selling what you don't keep | 1 to 2 |
| 5 | **The first two minutes, scripted,** with analytics on every step | 1 to 2 |

### Second: make the minute flow
| # | Change | Size |
|---|---|---|
| 6 | A fish that is yours never drowns you: fall off, float, a few seconds of grace | half |
| 7 | A full bag keeps the best seven | half |
| 8 | The tamed hop: the big push comes off a fish you have tamed | half, then play it |
| 9 | Each land's border is a visible gate with its number | 1, with the map chat |
| 10 | The Index: every fish in its 24, paying coins and Oxygen for each new one | 2 to 3 |
| 11 | A revive, the first one free | half |

### Third: reasons to come back
Daily reward with a streak; a rare fish announced to the whole server; "the current shifts" (the herd respawns);
a best-depth board; rebirth; friends in the same server earning a little more. Robux last, on top of things that
already work: the reference's set is in [money](money.md).

## The hop, changed today
The user: "a bit more air time and be pushed further by the hop off the fish". 0.3 seconds more air and about a
third more ground before the pull-in. Numbers and the played check: [riding feel](riding-feel.md), "More air, more
push".

**One thing to know:** a longer hop makes the Shallows four fish long instead of five. The first dive was already
short. This is one more reason for change 5 and for a gate (9) rather than a silent wall.

## What to measure
The user asked for little room for error. That needs numbers from real players, and there are none yet.
- **The first session's steps,** each as an onboarding funnel step in Roblox's analytics: spawned, in the water,
  first landing, first tame, first dive ended, first purchase, second dive, reached land 2.
- **Per dive:** length, fish landed on, how it ended (too strong, missed, out of Oxygen), depth.
- **Economy:** coins earned and spent, by source.
- Then the creator dashboard's own: day-1 and day-7 retention, session length.
- A soft launch to a small audience before any advertising, to read those.

## From the repo survey
The game needs almost no outside code. Take ProfileStore for saving now. Copy its way of saving, and the way idle
income should be worked out from a stored time, not ticked. The rest waits:
[Roblox repos](../reference/roblox-repos.md).

## From the videos
Ten were read in full: [Roblox videos](../reference/roblox-videos.md). What they add to the list above:
- **They back the order.** The two things with tests behind them are measuring every first-session step, and an
  on-rails first ride on an easy fish with a goal list after it (+10% day 7 in Voldex's test). Those are changes 5
  and "What to measure".
- **A new-player goal list, with a reward that takes more than one session.** Not in the list above: add it to
  change 5. For us: tame 3 fish, reach the Reef, catch a Silver, catch a Big, fill the tank.
- **The hub should be wanted.** Spawn facing other players' tanks and earning fish, with the deeper gates in
  sight. Our dock already has the plots in a row by the gate; the tank (change 3) should be built to be seen from
  the spawn.
- **Returns should unlock, not pay.** So before a daily coin reward: earnings to collect, a deepest-dive benchmark
  with tiers, the Index.
- **New players are for keeping, not selling to:** most revenue comes from players over 90 days old. Robux goes
  last, as planned.
- **Feel:** every payoff wants a sound and a burst at the exact moment, and a split-second freeze at a hit. The
  landing has its shake and flash already; the tame, the summary and a new Index entry will need theirs.
- **Phones are a real risk here.** Many players have 2 GB phones with about 600 MB for the game, and each part
  costs about 1 KB. The map is 59,000 parts with nearly 50,000 pictures on them, and nothing has been run on a
  phone. That is for the map chat and a test on a real old phone, before launch.
- **What Roblox's recommendations count:** days played, time played, days played with friends, days spent on.
  Retention first. That is the case for closing the loop before anything else.

## Open, for the user
1. **Is the order right?** Saving, value, tank, buying Oxygen, the first two minutes: about a week and a half of
   work before the game is a whole loop.
2. **The tamed hop** (change 8): try it?
3. **How long should a first dive be?** 15 seconds can work if it pays. Or the first land can be longer (the
   map chat) so it is 30.
4. **Does standing on the pad stay at all,** once Oxygen is bought?
