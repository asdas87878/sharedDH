# The leaderboards

Three boards in the hub: **TOP OXYGEN**, **TOP COLLECTORS**, **TOP EARNERS**. Hugo, 2026-11-25 (NULLROOM task l1):
"Make stylised leaderboards in this style, but fitting the aquatic theme", with a picture of three tall boards on a
plinth. Taken from it: the function, the layout, the readability. The look is ours.

**State: built on branch `leaderboards`, checked offline only. Not seen in Studio, not merged. The frame is Hugo's pick.**

![three frames to choose from](../attachments/leaderboards-options-1.png)

## To choose
| `Config.Boards.Style` | Frame | Parts in the row |
|---|---|---|
| 1 | driftwood and rope: logs, glass floats for lamps, starfish; nearest to the hub's own wood | 282 (the cheapest) |
| 2 | coral reef and shell: coral pillars, a scallop crown, pearls, lit anemones; the most colourful | 397 |
| 3 | sunken brass: green copper, brass bands, caged lamps, portholes, a valve. **Claude's pick, the file's value** | 338 |

Why 3: the calmest round the numbers, its warm lamps stand out against the grey wall, and the hub has nothing like it.
The emblems are the same on all: a big air bubble with a tank in it, our Index book with a fish jumping out, a treasure
chest with a gold fish (and an anchor for the fourth board). In Studio, the workspace attribute `BoardStyle` (1 to 3)
shows another while playing.

## Where they stand
Along the front wall, **right of the dive gate as you face the sea**, in place of the blank "Earners" slate, facing into
the hub and turned a little to its middle. Left to right: Oxygen (by the gate), Collectors, Earners; feet at about
(2936, -37), (2922, -39), (2908, -41). All in `Config.Boards`: `X`, `Z`, `Face`, `Pitch`, `Turn`, `Scale`.

Found in the saved place (2026-11-25 00:11) read offline: the row touches nothing, is 49 studs from the spawn, 33 from
the Sell ring, 66 or more from the other rings, and 1 stud from a fence post of Plot 6. The old slate is moved out of the
**running game** only (`Replaces`); the place is not changed.

**Plot 6 stands partly in front.** From the spawn and the gate all three boards show. From 60 studs straight across, its
post, sign and seahorse cover the edge of Earners and part of Collectors. The seahorse is a mesh, so it is in no picture here.

## Who is on them
- **Oxygen:** the max Oxygen. **Collectors:** fish looks found in the Index (a kind in one size and one colour is one look, as the
  Index records them). **Earners:** the tank's coins a second. A fourth, **DEEPEST DIVERS**, is in the list with `On` 0:
  a client moves its own character, so that number is the easiest to cheat.
- **Everyone, or this server.** A board lists every player only while its number is really saved between visits and
  Roblox's store answers. Otherwise it lists this server's players under a **THIS SERVER** label (the other label is ALL
  PLAYERS). **Saving is off in the live game, so today all three say THIS SERVER.** The Index is not a saved part, so
  Collectors stays that way after saving is turned on, until the Index is saved.
- **Places:** biggest first; equal numbers share a place (1, 2, 2, 4), the lower user id first. 50 kept, 8 seen, the rest
  scrolled to from within 24 studs. Your own place and number are at the foot, with the seconds to the next look.
- **Names and faces:** Roblox's own display names (filtered by Roblox) and headshots; the store holds a user id and a
  number, nothing else. `HideUsers` (empty) leaves ids out of the store and the lists.
- Everything is the server's own number. The client sends only "send me the lists", no oftener than every 2 s.

## How a number is kept
Roblox's sorted store takes whole numbers only, and past 2^53 a number loses its units. `Lib/BoardSums`:
- **up to 1e15 steps: exactly**, rounded **down** to a step. A step is 1, or a tenth for Earners (`Scale` 10), so nobody
  is shown more than they have: 12.39 a second is kept as 123 and shown as 12.3. Your own number at the foot is cut the
  same way (`BoardPanel.number`), so it reads as your row does. The rest of the game's signs round to the nearest tenth
  (`Config.rate`: 12.4).
- **past that: by its logarithm**, `1e15 + round((log10(n) - 15) x 1e13)`, always under 2^53. Read back it is off by less
  than one part in 1e12, far finer than the four figures shown. Order is kept, across the join too. Two numbers
  closer together than that count as a tie.

## What it costs Roblox's store
One list asked for per board per minute (`Refresh` 60). A player's number is written when it has changed, at most every
120 s and as they leave; one write per 0.5 s per server; nothing while the game's own budget has 5 or fewer left.
A server that closes spends up to 20 s on what is left: the writes still queued, those Roblox has not answered yet, and
a failed one again after 2 s. After an error a board waits 30 s, doubling to 600 s, with **one** line in the output. A list older than 600 s gives way
to this server's players and comes back by itself. Nothing is written before a player's save has loaded, so a joining
player never overwrites their own number with a fresh one.

## Where it is
`LeaderboardService` (who is on them), `Lib/BoardSums` (the sums), `Shared/Boards` (the frames and emblems, plain parts),
`BoardController` (builds and moves them on each player's own machine, in `workspace.Boards`), `UI/BoardPanel` (the list),
`SaveService.keeps`, remote `Boards`, player attributes `Board` + Id. Off: `Config.Boards.On` 0 (the old slate comes back).

## Checks (lune, offline)
`rojo build default.project.json -o /tmp/p.rbxl`, then `lune run tools/boards/...`:
- `board_test.luau /tmp/p.rbxl`: order, ties, rounding, past 2^53, the store off, down and back, budget, hidden ids, closing (88).
  Sixteen rules broken on purpose, one at a time: each made this or the next one fail.
- `panel_test.luau /tmp/p.rbxl [dump folder]`: the list as drawn, and that row and foot read the same (67).
- `place_test.luau /tmp/p.rbxl <saved place>`: every part of every style against the hub (11). `slim.luau` leaves out
  the properties it does not need, so it takes 0.7 GB and not several.
- The picture: `panel_test` with a folder, `picture.py <folder> panels`, `view.py` in Blender, `picture.py <folder> sheet <png>`.

## Not done, not sure
- **Not run in Studio:** scrolling by finger and mouse, the real headshots, the real letters and lamps, the store itself.
- Titles and values read at 60 studs; long names shrink and read only from nearer.
- The boards have no shadows and two small lights each. Not measured on a phone.
