# Ride a Dino breakdown

From the user's 5-minute recording (2026-11-09). The recording and frames are private, in `research/ride-a-dino/` (gitignored).
The contact sheets there show a frame every 3 seconds. Copy the loop and the feel; never the look, models or layout.

The game: [[☄️] Ride a Dino](https://rowatcher.com/games/10758824872/ride-a-dino), published August 2026, peaked around 110K
players at once in October 2026, lower by November.

## The run
- A long, wide track of zones with a progress bar across the top in metres: Plains, Forest, Desert, Jungle, Snow, Giant Forest,
  Abyss Ocean, Volcano, Extinction, Cosmic, with a BEST marker. Wild herds run along it.
- **Every wild dino's tag:** mutation (Silver, Golden), size (Tiny, Big, Huge, Giant, with "new!"), rarity (Common to Legendary,
  Mythic, Secret, Eternal), name, "Required ⚡12".
- **Stamina is a permanent stat:** it stayed at 1.9K through the whole run.
- **Riding HUD:** a green ring is the time left on this dino, a pink ring the tame progress. A lasso circle marks the dino you'll
  jump to; Space jumps; a yellow ring flashes on landing. "IT'S YOURS!" when a tame finishes; tamed dinos go into an "N SECURED"
  list you carry.
- **The end:** fall with nothing to ride → "Keep riding! Revive FREE (1 of 3 free revives)" → "GREAT RUN! You caught 6 dinos" →
  back at the hub, carrying each dino over your head to the pen ("GO TO YOUR PEN TO DEPOSIT").

![Riding](../../research/ride-a-dino/f_0108.jpg)
![Tamed](../../research/ride-a-dino/f_0120.jpg)
![Revive](../../research/ride-a-dino/f_0168.jpg)

## The jump, frame by frame
Read 2026-11-10 from the user's two recordings (30 frames a second, 1280 x 720): the first run of 2026-11-09, and a
35-second ride of 2026-11-10 with nine jumps and one miss. This is the move our fish-to-fish jump copies
([Decisions](../Decisions.md), [riding feel](../design/riding-feel.md)). The second recording corrected the first
reading: the ring marks where you come down, not a locked target, and the thin hoop by the rider is the lasso in their
hand.

1. **Riding:** the rider holds a lasso hoop up in one hand. Beside them, the green ring (time left on this dino) and the
   pink ring (tame progress). The Space button shows an up arrow.
2. **Space:** the rider is thrown up off the dino at once. A white ring pops where they left. The button's arrow turns to
   point down. The old dino runs on.
3. **The flight:** the rider goes up high and travels on at about the herd's pace, and the camera lifts to look down from
   behind. A dashed yellow ring lies on the ground under the rider and travels with them.
4. **The dino inside the ring turns solid glowing yellow.** That is the one you come down on. The ring and the glow stay
   on it while the rider floats down over it.
5. **Landing:** a white ring pops at the saddle, a wide soft yellow fan spreads on the ground behind the dino and lasts
   about a second as it runs, and the dino fades from yellow back to its colours over about 0.3 s.
6. **How long:** from the press to the landing, 1.8 to 2.4 s in the second recording, 0.9 to 1.0 s in the first. The
   down arrow suggests a second press drops you early, which would be the short ones; not confirmed.
7. **A miss** (28.6 to 31 s in the second recording): the ring passes over empty ground, the rider comes down on it
   about 2 s after the press, a white dust cloud, then "Keep taming!" with the revive offer, then the hub.

**Speed through one jump,** read off the distance counter every 0.1 s (second recording, the jump pressed at 21.95 s):

| Part | When | Metres a second | Against riding |
|---|---|---|---|
| Riding before | 21.4 to 21.9 s | 54 | 1.0 |
| The launch | 22.0 to 22.7 s | 72 on average, up to 100 | 1.3 to 1.8 |
| Floating over the glowing dino | 22.8 to 23.8 s | 46 | 0.85 |
| The pull-in | 23.9 to 24.3 s | 90 on average, up to 130 | 1.7 to 2.4 |
| Riding after | 24.4 to 25.0 s | 57 | 1.05 |

- While floating, the rider keeps pace with the glowing dino, so **the herd runs at about 0.85 of riding speed**, all one
  way. A wild dino is almost as fast as a ridden one.
- **The landing is a pull-in:** for the last 0.3 to 0.5 s the rider moves at about twice riding speed onto the dino. The
  first recording's jump shows the same (up to 130 m a second for 0.3 s).
- One jump only for the table; the first recording's jump agrees in shape.

**The pull-in, frame by frame** (2026-11-10: the counter read on every frame, 30 a second, through two pull-ins of the
second recording; "ahead" is how far the rider has gained on the herd's steady pace):

| Pull-in | Time | Gained | How it goes |
|---|---|---|---|
| Landing at 24.3 s | 0.47 s | 22 m | 3 m in the first 0.2 s (a creep), then 19 m in 0.27 s; the last frames are the fastest (about 70 m a second faster than the herd); then it stops dead on the dino |
| Landing at 5.0 s | 0.33 s | 15 m | the same shape, a little straighter |

- **The shape:** the distance gained goes as time to a power: about 2.5 for the first, about 1.5 for the second. A plain
  "ease in": slow, then faster and faster, **no slowing at the end**. The stop is the landing itself.
- **The time grows with the distance:** both come to about 46 m a second on average over the gap.
- **Through the creep the rider is still moving at the herd's pace,** not hanging still.
- The counter is in whole metres, so each reading is good to about a metre; two pull-ins only.

**From the side** (the user's third recording, 2026-11-10, 30 s, the camera turned side-on):
- **The shape of the flight:** a quick pop up, at full height about 0.3 s after the press; then a long, flat glide,
  hardly sinking; then the pull-in in a straight line down onto the dino. It is not an arc that rises and falls.
- **The height:** about two rider-lengths above the dino's back (roughly 8 to 12 studs), judged by eye.
- **The rider lies flat, face down,** from just after the pop to the pull-in, the lasso hoop held out ahead.
- **The timing of one jump:** pressed at 9.85 s, the pull-in begins about 11.55 s (1.7 s later) and lands at 12.0 s. The
  next jump is pressed 0.2 s after landing.
- **Through the pull-in a row of yellow dots is left behind the rider** (11.57 to 11.97 s). A thin line, the lasso,
  seems to run from the rider to the dino through it (looked at again 2026-11-10; not built).
- **At the launch there is no ring, ribbon or burst** in this recording (9.87 to 10.03 s): the rider just leaves.
- **At the landing:** the dino flashes white, then yellow, fading over about 0.3 s; a white ring at its feet; the yellow
  fan behind it for about a second.

**The camera through a landing,** measured between every pair of frames (how much the whole picture grew or shrank, and
how far it shifted), at four landings of the side-on recording:

| What | Measured |
|---|---|
| Through the pull-in | the picture grows 6 to 8% a frame for 4 to 8 frames: the camera rushes in with the rider, and perhaps zooms |
| The landing frame | in ONE frame the picture shrinks to 0.79, 0.79, 0.80 and 0.81 of its size: the view snaps wider (from a 70 degree view, to about 82) |
| After | it comes back to full size over 0.3 to 0.4 s, steadily |
| The jolt | with the snap, the picture jumps 10 to 17 pixels (of 720) up or down, back the other way the next frame, and is still within about 0.13 s |

- This is the "zooms in and out" at a landing: in through the pull, out in a snap, then settling.
- Shakes while riding or at the launch: none that stand clear of the recording's own unevenness at 30 frames a second.

**What sits on the ground, and so needs another answer under a floating fish:** the dashed yellow ring, the yellow fan on
landing, and the dust the dinos kick up as they run.

**Not readable from the recordings:** the outline round the glowing dino (too small on screen), whether the flight is
pulled toward a dino or only steered, what the second press does exactly, and whether an untamed dino can be steered.

## The herd
Read 2026-11-13 from the flight over the first two lands (frames a quarter second apart, from above) and the 35-second
ride. What we took from it is in [the herd](../design/herd.md).
- **Every dino runs dead straight.** Each leaves a dust trail; the trails are long straight lines, all parallel to the
  track. Nothing weaves or swerves.
- **Nothing is avoided.** Dinos and the rider pass straight through trees and rocks. The prop turns see-through while
  something is in it, or breaks apart if the dino is big.
- **A loose scatter, not a line.** From above the dinos fill about the middle half of a room, five or six abreast, at
  uneven distances along it. No two overlap for long.
- **They funnel at a neck** and spread again in the next room.
- **All one way, at about one pace** (0.85 of riding speed, measured above).
- **Big dinos run among the small ones.**
- **Not readable:** whether dinos of different kinds run at different speeds, and how new ones appear.

## Rarity and spawns
Measured 2026-11-09 from every creature tag in the recording's two runs, one frame a second (read with Windows' text reader,
checked by eye). The runs reached 3,546 m and 2,215 m, so only the first two zones were seen.

| Stretch of the run | What spawned (required stamina) |
|---|---|
| Plains, 0 to about 935 m | Common Pachycephalosaur, Doedicurus, Dodo (8 to 12); Uncommon Terror Bird, Dilophosaurus (10). Nothing rarer. |
| Forest's first 200 m or so | the Plains herds carry on (a Common Pachycephalosaur at 1,155 m) while the Forest herds start |
| Forest, to about 3,450 m | mostly Uncommon Ankylosaurus (50 to 60); often Rare Triceratops (104 to 156) and Velociraptor (128 to 160); now and then Epic Carnotaurus (203 to 253) and Suzhousaurus; one Legendary Brachiosaurus (752), around 2,450 to 2,790 m, in one of the two runs |
| Desert, from about 3,450 m | not reached |

- **Each species has one rarity, each zone its own species,** so the zone sets the mix. It moves up a step per zone at the start:
  Commons and Uncommons, then mostly Uncommons with Rares, the odd Epic and a rare Legendary. Commons never come back.
- **Long tails:** the user, from playing it, adds that the Plains also has a really small chance of an Epic or a Legendary.
  Rarer tiers are always possible, just far less likely, and become common a few zones on.
- **Required stamina** rises with rarity (in the Forest: Uncommon 50, Rare about 130, Epic about 230, Legendary 752) and about
  5 times per zone (Uncommon: 10 in the Plains, 50 in the Forest). A guide says Cosmic's top dinos need millions, which fits:
  10 x 5 to the 9th is about 20 million by zone 10.
- **Size scales it:** Tiny x0.8, Big x1.2, Giant x1.5 (Velociraptor 160, Tiny 128; Triceratops 130, Big 156; Ankylosaurus 50,
  Giant 75).
- **Secret and Eternal spawns are zone events announced in chat to the whole server,** each zone with its own: "A Secret King
  Yeti spawned in Snow", "A Secret King Gorilla spawned in Volcano", "A Secret GIANT Barosaurus Fossil spawned in Extinction",
  "An Eternal BIG DRex spawned in Giant Forest", "An Eternal GIANT Lunar Dragon spawned in Cosmic". Eternal sits above Secret.
  "ALL HERDS RESET!" respawns everything.
- **Not known from this recording:** the mix in zones 3 to 10, how the end looks, the Mythic odds, and whether early zones have
  Secrets. The in-game Index (every dino with its rarity) and a run through the later zones would answer all of it.

## The hub
- **Pen:** 7 dinos earning at once ("7/7 Active"), the rest stored, Equip Best, Upgrade Pen, offline earnings
  ("$9.1M/Day offline").
- **Upgrade Machine:** a rocking toy dino. Raptor gives +15 stamina/s; upgrading to +36 costs $4M or 69 Robux. Next: Triceratops,
  $80M.
- **Auras:** x1.5, x2, x2.5, x3 stamina and up, for cash or Robux.
- **Other stations:** Sell Dinos, Fuse Machine (0/3), Jurassic Airlines (a pterodactyl: buy once, fly to a later zone; Zone 7 Abyss
  Ocean $500B, Zone 9 Extinction $50T), Index, Top Earners board, a START ZONE strip.

![Pen](../../research/ride-a-dino/f_0012.jpg)
![Upgrade machine](../../research/ride-a-dino/f_0285.jpg)
![Auras](../../research/ride-a-dino/f_0081.jpg)

## Live
- A day/night timer; dinos sleep at night.
- "ALL HERDS RESET!" and server-wide messages ("A Secret King Yeti spawned in Snow").

## Robux
A timed x2 Money boost, a 99 R$ limited starter pack, x2 Stamina, + buttons to buy stamina and cash, revives, auras, machine
upgrades, airlines.

## The look
Cheap: blocky voxel dinos on a plain green studded baseplate. The loop and the feel carry it, not the art.

## Contact sheets
![](../../research/ride-a-dino/sheet_00.jpg)
![](../../research/ride-a-dino/sheet_01.jpg)
![](../../research/ride-a-dino/sheet_02.jpg)
![](../../research/ride-a-dino/sheet_03.jpg)
![](../../research/ride-a-dino/sheet_04.jpg)
![](../../research/ride-a-dino/sheet_05.jpg)
![](../../research/ride-a-dino/sheet_06.jpg)
![](../../research/ride-a-dino/sheet_07.jpg)
![](../../research/ride-a-dino/sheet_08.jpg)
![](../../research/ride-a-dino/sheet_09.jpg)
![](../../research/ride-a-dino/sheet_10.jpg)
![](../../research/ride-a-dino/sheet_11.jpg)
