# Pace: how fast wild fish swim, and how

Up: [the herd](herd.md). Sizes: [sizes](sizes.md). Built 2026-11-13 on the user's word: "we need it to feel like some
zoom past, some go slow, some huge predators come in from above and dart past you, some are slow and clunky,
animations countered in and more". The numbers: `Config.Pace`, `Config.FishPace`, `Config.SizePace` in
`src/shared/Config.luau`. The code: `paceShare` and `steer` in `src/server/Services/FishService.luau`.

## Before
Every wild fish swam at 0.85 of its own ridden speed, and nothing else. In the first land that is 34 to 41 studs a
second for nearly every fish: the herd moved as one block, and a rider on a Common slid past all of it at 5 to 10.

## Now: each kind has a character
A wild fish's speed is its own ridden speed, times its character's share, times its own little difference (6%
either way), times its size's. **Only wild fish:** a ridden fish goes at its ridden speed, as ever.

| Character | What it does | Share of its ridden speed | Kinds |
|---|---|---|---|
| **Cruise** | The herd's pace: the reference's, measured | 0.85 | 30, any not named below |
| **Plod** | Slow and clunky, in lurches. You ride past it | 0.58, 12% either way every 2.6 s | 15 |
| **Zoom** | Faster than it is ridden. Comes past from behind and goes on | 1.12 | 13 |
| **Dart** | Slower than the herd, then a burst of about a second | 0.78, bursts at 1.55 every 3.5 to 8 s | 12 |
| **Hunt** | A great predator, high over the herd. With a player near it stoops into the herd, runs through it, climbs away | 0.75 high, 1.6 on the run | 12 |

- **A hunter's round.** It cruises 46 studs over its place in the herd (and half its own height; never out of the
  water). With a player within 450 studs it comes down at 42 studs a second, runs through the herd for 3.5 seconds,
  then climbs back at 20. Then 8 to 16 seconds before it may stoop again. **One at a time:** not while another
  hunter within 900 studs is in the herd.
- **Size** (wild only): Tiny 1.08, Normal 1, Big 0.97, Giant 0.92, Huge 0.88, Colossal 0.82. The small are a little
  quicker, the grand heavy.
- **The animation needs nothing told.** A fish's beat already goes by its speed, and its swing by how hard it is
  speeding up (`AnimController`), so a dart's burst and a plodder's lurch show as what they are, and a hunter noses
  down as it stoops.

## The visit: a predator past you early, as a rare thing
The user, the same day: hunters are rare where the game starts, by rarity; "somewhere in between, some predators
can come past early as a rarer event".
- **When:** a player who is in the water, with no hunter anywhere in sight (700 studs), is sent one every 70 to 150
  seconds. If a hunter is already in sight the visit waits and looks again in 20 seconds. In the deep lands a
  hunter is nearly always in sight, so this is a thing of the first lands without a rule saying so.
- **What:** a hunter of the land the player is in, chosen by the land's own share of each one's rarity, so the
  commoner hunter is the usual visitor and a Legendary one the odd time. Its size and colour are rolled as any
  fish's.
- **How:** it is put in the water 260 studs behind the player, high up, on a line that passes within 45 studs of
  theirs. It stoops at once, runs past, and climbs away ahead.
- **It is a real fish.** It can be hooked by anyone who can hold it, and it stays in the sea afterwards as any
  hunter does. So this does put a few more Epics into the first lands: about one a visit.
- **A hunter's run now lasts until it is past the player** (60 studs ahead of them), up to 9 seconds, not a flat
  3.5: a slow shark behind a fast rider used to climb away before it got there.

## Who is what
`Config.FishPace`. Claude's go, by what the animal is.

| Land | Plod | Dart | Zoom | Hunt |
|---|---|---|---|---|
| 1 | Boxfish, Pufferfish, Sea Turtle, Seahorse, Archelon | Blue Chromis, Clownfish, Cuttlefish | Flying Fish, Pearl Serpent | Reef Shark |
| 2 | | Moray Eel, Octopus | Coral Dragon | Dunkleosteus |
| 3 | Giant Sea Bass, Steller's Sea Cow | Garibaldi | Sea Lion, Kelp Wyrm, Dakosaurus | Great White |
| 4 | Goliath Grouper, Galleon Whale | | Barracuda, Xiphactinus | Hammerhead |
| 5 | Blue Whale | | Dolphin, Swordfish, Storm Serpent | Orca |
| 6 | Aurora Jelly | Viperfish, Giant Squid | | Liopleurodon |
| 7 | Anglerfish | | | Mosasaurus |
| 8 | Giant Isopod | Sea Scorpion, Bobbit Worm | Ember Serpent | Megalodon, Molten Megalodon |
| 9 | Grave Turtle | Wraith Eel | | Halfbone Megalodon |
| 10 | Infernal Angler | Brimstone Eel | Hellmaw | Hellfin Shark, The Devourer |

Everything else cruises.

## Measured
In Studio on grey-box 15, by script, riding a Common at 44 to 45 in the first two lands.
- **Plod:** Pufferfish, Sea Turtle and Seahorse at 20 to 29 (their ridden speeds: 40 to 44).
- **Cruise:** 42 to 47.
- **Zoom:** Flying Fish at 64 to 70 (ridden 58).
- **Dart:** Blue Chromis 40 to 82, Clownfish 32 to 64, Octopus 40 to 79.
- **Hunt** (every fish forced a Reef Shark, ridden 70): cruising at 50 to 53, 65 to 75 studs over the seabed; the
  stoop down to 17 over it at 99, at 20 degrees; never nearer the surface than 12 studs.
- **Round the rider, in 15 seconds:** fish came past from behind (darters, and once a hunter) while the rider went
  past 4 to 7. Wild speeds in sight ran from 20 to 115.
- **The whole sea by character:** Cruise 45%, Plod 15%, Dart 15%, Zoom 8%, Hunt 17% (measured before hunters were
  held to one at a time). By land the hunters run from 4% of the first two lands' fish to 28% of the fifth's.
- **A visit** (forced with `TestVisit`), three of them: a Reef Shark and a Dunkleosteus appeared 230 to 250 studs
  behind the rider, came past 2.8 to 3.4 seconds later, 16 to 19 studs off, at 126 to 133, and were 220 to 325
  studs ahead and back up high after 12 seconds. With a hunter in sight no second visitor came. (One run before the
  "until it is past" rule: a Big Reef Shark had not passed after 6 seconds.)
- Rides with hops on each build, no errors.
- **Not checked:** anything by eye. Hooking a hunter in its run. Phones.

## To look at one kind
In Studio, on `Workspace`, before Play: the attribute `TestKind` (a fish's Id, such as `ReefShark`) makes every new
fish that kind. Take it off after. While playing, setting `TestVisit` to true on the server's `Workspace` sends a
visit at the next top-up (it clears itself). The sandbox panel has the `Pace` rows.

## Open, for the user
- **How often the visit comes** (70 to 150 seconds), and whether a visitor should be hookable at all.
- **A Zoom fish is faster wild than ridden** (1.12): you hop on and it slows a little. The other way to make it zoom
  is a higher ridden speed for those kinds (`Config.FishStats`, Hugo's table). Not touched.
- **Ridden speeds** are as Hugo set them. Nothing here changes how fast you ride.
- The shares, who is what, and how often a hunter stoops: all for the user's eye.
