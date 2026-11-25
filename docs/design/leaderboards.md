# The leaderboards

Three boards in the hub: **TOP OXYGEN**, **TOP COLLECTORS**, **TOP EARNERS**. Hugo, 2026-11-25 (NULLROOM task l1):
"Make stylised leaderboards in this style, but fitting the aquatic theme", with a picture of three tall boards on a
plinth. Taken from it: the function, the layout, the readability. The look is ours.

**State: built on branch `leaderboards`, the second round of changes on `leaderboards-2` (from it); checked offline only. Not seen in
Studio, not merged.**

![the boards](../attachments/leaderboards-3.jpg)

## The look (Hugo, 2026-11-25)
Hugo picked frame 3 of [three](../attachments/leaderboards-options-1.png) (sunken brass), then: "make models on top of the
leaderboard simpler and easier on the eye, placed right on the top/front of the leaderboard like a sign hanging these
should be somewhat flat. remove a little more visual clutter on them [...] Dont overdo it. Fit the reference better in
terms of how the leaderboard is structured from the inside, make it more stylised and simplistic. Dont make everything
look too "childish"".

Then, the same day, of [that](../attachments/leaderboards-2.png): "add valves and some lights and details back around the
border, make each "TOP" text stylised, make icons a little smaller remove the border around them and make sure that the top
shrinks to a way smaller bar". So now:
- **The top:** a bar 1.6 studs high with a brass edge and six small lamps (was 7 studs of board and beam). "The top" is read as
  the frame's head; the panel's heading is as tall as it was (156 of its 848 pixels, was 154).
- **The icons:** the bare shape on the front of the bar, no roundel, no straps; about 2 studs high (Oxygen a bubble, Collectors the
  Index open with a fish on each page, Earners a shut chest; an anchor for the fourth). They do not move.
- **The border:** up each pillar a pipe in collars and bolted straps to a barred ship's lamp; a red valve on the right one, a
  gauge on the left one; in the foot a valve between two lit portholes. Still out: weed, caged lanterns on top.
  78 to 86 parts a board (24 to 33 before it, about 110 at first). Two of the lamps a board are real lights, the rest only glow.
- **The title:** its first word (TOP) small in brass between two fading lines, the rest big under it in Denk One, shaded in the
  board's own colour (sea, coral, gold), on a dark edge and drop. Who it lists and what it counts share one line under it (who was above the title before).
- **The list**, laid out as the reference's is: one dark face; rows of place, face, name over user name, number over its unit; only
  first place is gold; your own line edged in white; a centred foot. The colours and words are ours. No outlines on
  letters but the title's; the rest is Builder Sans.

The two frames not picked, and the signs before, are in git (`35a8781`; the roundels `d469a7f`).

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
- **Names and faces:** Roblox's own display and user names (filtered by Roblox) and headshots; the store holds a user id and a
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
`LeaderboardService` (who is on them), `Lib/BoardSums` (the sums), `Shared/Boards` (the frame and signs, plain parts),
`BoardController` (builds them on each player's own machine, in `workspace.Boards`), `UI/BoardPanel` (the list),
`SaveService.keeps`, remote `Boards`, player attributes `Board` + Id. Off: `Config.Boards.On` 0 (the old slate comes back).

## Checks (lune, offline)
`rojo build default.project.json -o /tmp/p.rbxl`, then `lune run tools/boards/...`:
- `board_test.luau /tmp/p.rbxl`: order, ties, rounding, past 2^53, the store off, down and back, budget, hidden ids, closing (89).
  Sixteen rules broken on purpose, one at a time: each made this or the next one fail.
- `panel_test.luau /tmp/p.rbxl [dump folder]`: the list as drawn, and that row and foot read the same (67).
- `place_test.luau /tmp/p.rbxl <saved place>`: every part against the hub (9). `slim.luau` leaves out
  the properties it does not need, so it takes about 0.85 GB; it says nothing and ends with 137 if the PC kills it (under about 1.8 GB free).
- The picture: `panel_test` with a folder, `picture.py <folder> panels`, `view.py` in Blender, `picture.py <folder> sheet <png>`.

## Not done, not sure
- **Not run in Studio:** scrolling by finger and mouse, the real headshots, the real letters and lamps, the store itself.
- **The title's size in Roblox:** a font's size there can come out smaller than Chromium draws it; it is fitted to its box both ways.
- Titles and values read at 60 studs; long names shrink and read only from nearer.
- The boards have no shadows and two small lights each. Not measured on a phone.
