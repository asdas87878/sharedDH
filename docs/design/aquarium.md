# The aquarium: where a catch goes, and what it earns

> **Studies, 2026-11-16.** Three numbers here were read wrong from the reference: what a size earns, what a colour earns, and income against what a fish needs (theirs rises about as the square). And every trending game shows what a player owns in the open, not behind glass. [Findings](../Findings.md), "What we had wrong" and rank 1, point 7.

Up: [core loop](core-loop.md), [the dock](the-dock.md). Why it came first: [the loop review](loop-review.md).
Built 2026-11-16 on the user's word: "catches are for depositing in your aquarium, in which they then earn money".
The code: `src/server/Services/AquariumService.luau`, `src/client/Controllers/AquariumController.luau`. The numbers:
`Config.Aquarium`. **For the session only: nothing is saved yet.**

## What happens
1. **A tank each.** A player takes the first free plot on the dock as they join, the nearest to the dock's spawn
   first, and gives it up as they leave. Its sign shows their name and what the tank earns.
2. **The catch comes home in your hands.** What you tamed on a dive is still carried at the dock (it was only
   counted before). The seven slots stay filled until it is put away.
3. **You wake at your own tank.** With fish in hand, a dive that ends puts you on the pad in front of your tank,
   not at the dock's spawn. The view turns to the tank.
4. **Standing on your plot puts them in.** A line rises over the tank: how many went in, and what they add a
   second. The slots empty.
5. **They swim there and earn.** The best seven earn coins every second. The coin row on the HUD shows itself.
   The rest are kept (up to 60) and take a place when they are among the best.

## What a fish earns
Coins a second = what it takes to hold at home (its land and rarity: the number on its tag there) x 0.025 x its
size's worth x its colour's.

| | Times |
|---|---|
| Tiny, Normal, Big, Giant, Huge, Colossal | 0.8, 1, 1.2, 1.5, 2, 3 (`Config.SizeWorth`: the reference's first four) |
| Normal, Silver, Gold, Rainbow | 1, 1.5, 3, 10 |

- A Shallows Common earns 2 a second, as the reference's first dino does. An Uncommon 2.5.
- **This is what size and colour are for now.** A Giant Gold Common earns 9 a second where a Normal one earns 2.
- The numbers are Claude's first go. Nothing is bought with coins yet, so there is no price to set them against.

## Measured
In the user's Studio on grey-box 15, by script.
- **A whole dive, ended the way a player's does** (the sandbox's safeties off, the Oxygen ran out): Riding →
  Drowning → Dock in 7 to 8 seconds; the player woke on their own plot's pad; three fish went in at once; the tank
  earned 5.6 to 7.75 a second; the coins rose every second.
- **Seen in two pictures:** the view on the tank with three fish swimming in it, the coin row at the lower left,
  the seven slots empty.
- **The sign:** the player's name and "$7.2 a second".
- No errors.
- **Not checked:** two players and two tanks; a full tank of 60; a phone; the line over the tank by eye (it had
  gone by the time the picture was taken).

## What it is not yet
- **Not saved.** Leave and it is gone. Saving is next ([the loop review](loop-review.md), change 1).
- **Nothing to spend coins on.** Oxygen bought with coins (the machine, auras) is change 4. Each plot already has
  a `TrainerSpot` and a `TrainerRide` from the map chat; the training stand-in still uses its own pad.
- **No summary of the dive.** The existing "great dive" banner still shows; it does not list values.
- **The tank's fish don't beat their tails.** They move round their laps as they are. The swim animation only
  runs on fish in the sea.
- **No earning while away,** no selling, no choosing which fish to keep, no fusing.
- **The walk.** From your tank to the gate is 150 to 330 studs: 5 to 12 seconds at the dock's 28 studs a second,
  after every dive. The reference's is 4 seconds. That is the hub's size, for the map chat and the user.
- **More players than plots** (eight): the rest have no tank, and their catch is only counted, as before.

## The numbers
`Config.Aquarium`.

| Number | Now | What |
|---|---|---|
| `On` | 1 | 0: no aquariums, a catch is only counted |
| `Earning` | 7 | How many of a tank's fish earn at once (the reference's pen: 7) |
| `Hold` | 60 | The most a tank keeps; past it the poorest are let go |
| `PerRequired` | 0.025 | Coins a second for each Oxygen the fish needs at home |
| `Silver`, `Gold`, `Rainbow` | 1.5, 3, 10 | A colour's worth |
| `Every` | 1 | Seconds between payments |
| `HomeAtTank` | 1 | Wake at your tank when carrying fish (0: at the dock's spawn) |
| `Show`, `ShowShare`, `ShowLeast`, `ShowMost` | 7, 0.7, 7, 28 | The fish shown in the tank, and how long each is drawn |
| `SwimPace`, `SeeFrom` | 5, 450 | How fast they lap, and from how far a client moves them |

## For the other chats
- **Player attributes, new:** `Coins` (whole coins; the HUD's coin row was waiting for it), `Income` (coins a
  second), `TankFish` (how many the tank holds), `Plot` (the plot's name). `Owned` now counts at the deposit.
- **Ride "Deposited", count, gained, income:** sent to the player as their catch goes in.
- **The map's names it leans on:** `Dock.Plots.PlotN` with `TankWater`, `Pad`, `CollectPad`, `SignBoard`. A plot
  gets an `Owner` attribute (the user id) and a `TankFish` folder while it is someone's.
- **Tank fish** carry the tag `TankFish`. They are not in `Workspace.Fish`, so tags, the lock and the ride never
  see them.
