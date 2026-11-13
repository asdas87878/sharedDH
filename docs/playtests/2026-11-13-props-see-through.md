# Playtest 2026-11-13: seeing through props (solid until the touch, the shake, beside, the loose boxes)

The check of the rework Hugo asked for after playing the first fade ([Decisions](../Decisions.md), 2026-11-13,
"Seeing through props"). Run by script on Hugo's PC through the studio runner, on grey-box 15, with
`tools/studio/props_b1` (command `suite3`: the real controllers and the server's mounts; one player).
**Not played by hand, and nobody has looked at it:** the numbers say it does what was asked, not that it feels or
looks right. No picture was taken. No number in `Config.Props` changed, and no game code: the run showed no bug.

The suite was run four times while the test itself was being put right (see "What was wrong in the test"); the
numbers below are the last run, 20 passes, **no failed check and no error from the game's scripts** (only the old
warning about asset `203785492`, twice on each side at the start). The earlier note,
[props](2026-11-13-props.md), is the first fade (from 80 studs off) and the breaking; its "who breaks" table still
holds, its "see-through" column is the old look.

"See-through" below is the extra transparency the player's own machine puts on a box
(`LocalTransparencyModifier`): 0 is as the map made it, 0.65 is `Props.FadeTo`.

## 1. In the way: solid until the fish touches it, one shake, see-through while inside
Straight at the middle of a pillar coral (12 boxes, 32 x 52 x 25 studs) from 240 to 360 studs off.

| Fish | See-through before the touch (most) | The body's gap when it first turned | Touches, shakes | Shake's size | Most while inside | Changes of direction (2 = one fade and back) | The engine's speed at the touch, least inside | Worst frame, 2 s before, inside |
|---|---|---|---|---|---|---|---|---|
| Clownfish | 0.00 | -1.0 (inside it) | 1, 1 | 0.38 | 0.65 | 2 | 43, 43 | 21 ms, 19 ms |
| Reef Shark | 0.00 | -1.9 | 1, 0 (1) | - | 0.65 | 2 | 70, 70 | 21 ms, 20 ms |
| Reef Shark, three more passes | 0.00 | -1.6, -3.2, -2.0 | 1 and 1, 1 and 1, 1 and 0 (1) | 0.45, 0.52 | 0.65 | 2 | not slowed | |

- The prop was fully shown again by the time the fish was 141 studs past it (it eases back, `Props.FadeEase`).
- The shake's size follows the speed (`ShakeBySpeed`): 0.38 at 43 studs a second, 0.45 to 0.52 on the shark, of
  `Props.Shake` 0.5; `ShakeTime` 0.25 s.
- No fish was slowed, nothing was taken, nothing broke (0 boxes out, no "Crashed" from the server).

1. **To know: a touch gives no shake when another prop shook less than `Props.ShakeGap` (0.7 s) before.** That is
   the rule as built, so a cluster doesn't rattle the camera. On the shark's line to this coral it touches
   another big prop 0.52 to 0.64 s earlier, which shakes: in six of the afternoon's eight passes the coral itself
   then gave no shake (it still turned see-through at the touch); in the two where the earlier prop did not come
   so close before, it shook. The slower Clownfish got its shake at the coral every time. If Hugo wants every big
   prop to shake, `ShakeGap` is the number (0.4 would do it here).

**Four pillars in a row, 22 studs apart** (the test's own, on the test's machine only): all four entered and
turned see-through on both fish; 2 shakes each, 1.02 s apart on the Clownfish (a pillar every 0.51 s) and 0.93 s
apart on the Reef Shark (one every 0.31 s). Never two shakes inside `ShakeGap`.

## 2. Beside, and between the camera and the player
A Clownfish past the side of the same coral, its body the given distance clear (`Props.SideNear` 12, back at 18):

| Aimed at | The body's least gap | See-through, most | First turned at gap | Touches, shakes | Changes of direction |
|---|---|---|---|---|---|
| 2 | 4.1 | 0.65 | 11.5 | 0, 0 | 2 |
| 6 | 8.0 | 0.65 | 11.2 | 0, 0 | 2 |
| 10 | 11.9 | 0.64 | 11.9 | 0, 0 | 2 |
| 16 | 17.3 | 0.00 | never | 0, 0 | 0 |
| 24 | 25.3 | 0.00 | never | 0, 0 | 0 |
| 40 | 41.9 | 0.00 | never | 0, 0 | 0 |
| Reef Shark, 10 | 11.2 | 0.65 | 11.7 | 0, 0 | 2 |

So: see-through inside 12 studs, solid past it, no shake without a touch, no flicker.

**Between the camera and the player** (`Props.ViewNear` 5), on its own: a 3-stud box of the test's kept on the
line from the camera to the fish, 4 studs in front of the camera, for 1.5 s; then 20 studs off that line; then
back on it.

| Where the box was | See-through after 1.5 s | The body's least gap to it |
|---|---|---|
| On the line | 0.65 | 9.3 |
| 20 studs off the line | 0.00 | 18.4 |
| On the line again | 0.65 | 9.1 |

The camera sits 21.8 studs from a Clownfish's middle, so a box near the camera is 10 studs from the fish, inside
the side rule's 12. For this test only `SideNear` was pulled in to 7, so that the view rule alone decided; with
the game's 12 the same box is see-through by the side rule anyway. Also seen in the hop runs: the prop the rider
had just gone through stayed at 0.65 with the body more than 18 studs clear of it while it was still on the
camera's line (3 frames).

## 3. The loose boxes of a broken prop
How see-through each flying copy was against how far it was from the line camera to player (as the game counts
it, less half the box), while it hung in the water. With the game's `Props.Hang` 0.5 s the boxes are only seen
close; the second table lets them hang 3 s so every distance is filled. `DebrisNear` 12, `DebrisFar` 30.

| Studs from us | touching | 0-6 | 6-12 | 12-18 | 18-24 | 24-30 | 30-45 | 45+ |
|---|---|---|---|---|---|---|---|---|
| Humphead Wrasse, `Hang` 0.5 | 0.65 | 0.65 | 0.64 | 0.53 | 0.31 | 0.07 | 0.00 | |
| Steller's Sea Cow, `Hang` 0.5 | | 0.65 | 0.65 | 0.52 | 0.26 | 0.05 | 0.00 | 0.00 |
| Molten Megalodon, `Hang` 0.5 | | | 0.57 (2 samples) | 0.43 | 0.12 | 0.01 | 0.00 | 0.00 |
| Humphead Wrasse, `Hang` 3 | 0.65 | 0.65 | 0.65 | 0.55 | 0.33 | 0.10 | 0.01 | 0.00 |
| Steller's Sea Cow, `Hang` 3 | 0.65 | 0.65 | 0.65 | 0.56 | 0.32 | 0.10 | 0.00 | 0.00 |
| Molten Megalodon, `Hang` 3 | 0.65 | 0.65 | 0.63 | 0.53 | 0.30 | 0.07 | 0.01 | 0.00 |

Fully see-through inside 12 studs, easing to solid by 30, on all three. (The megalodon at 122 studs a second is
past its boxes in a quarter of a second, so few are ever near it with the game's `Hang`.) After that they fade
out as before (`FadeOut` 0.8 s).

## 4. Who breaks, who goes through
| Fish | Why | Went through its box | Boxes out | Copies flying (most) | Server said | Speed | The prop looked | Back |
|---|---|---|---|---|---|---|---|---|
| Clownfish | plain | yes | 0 of 12 | 0 | nothing | 43 before, 43 inside | 0.65 from the touch | shown |
| Reef Shark | Predator | yes | 0 of 12 | 0 | nothing (an Eat in other passes) | 70, 70 | 0.65 from the touch | shown |
| Humphead Wrasse | Breaker | yes | 12 of 12 | 25 | Smash x1.12, no crash | not slowed | solid until it broke | 4.6 s after we left its 300 studs |
| Steller's Sea Cow | Tank | yes | 12 of 12 | 24 | Crashed 0.80 | 0.79 of 56 | solid until it broke | 4.3 s; with a player "near" for 8 s all 12 stayed out |
| Molten Megalodon | giant, no archetype | yes | 14 of 14 (a reef wall) | 35 | Crashed 0.80 | 0.79 of 122 | solid until it broke | 4.8 s |
| Clownfish, hopped off 48 studs before | the rider in the hop | yes, in "Jumping" | 0 of 12 | 0 | nothing | 1.03 of the hop's own curve before the prop, 1.03 in it | 0.65 from the touch, one shake (0.39) | shown |
| Sea Cow, hopped off 52 studs before | the rider in the hop | yes, in "Jumping" | 0 of 12 | 12 (2) | (2) | 1.03 before, 1.03 in it | 0.65 from the touch, one shake (0.40) | shown |

- The hop slows by itself (one curve to a stop), so "not slowed by the prop" is read against that curve
  (`Config.hopSpeed`, the speed across the water): the rider flew 1.03 of it before the prop and 1.03 inside.
- `tools/creatures/check_breaks.py`: 16 of the 82 kinds break props (`GiantVolume` 12,000), as listed in
  [archetypes](../design/archetypes.md).
2. As in the first note: the Sea Cow had crashed through sea grass before the hop, and the copies flying are from
   that and from the riderless Sea Cow swimming on. The coral the rider went through lost no box.

## 5. Only on that player's screen
What could be measured with one player: while the suite ran, a script in the **server** looked at all 14,111
boxes of the 1,915 props twice a second (643 looks, `tools/studio/props_b1/server_watch.luau`). In every look:
0 boxes whose `Transparency` was not the map's, 0 boxes with a `LocalTransparencyModifier`, nothing added to or
taken from the props folder, nothing under the server's camera (the flying copies live under each player's own
camera). At the same moments the player's machine had props at 0.65 and up to 43 copies flying. What the server
did hold, and every player gets: which boxes are out (the tag `PropOut`, up to 92 at once, sea grass and stones
included). The see-through is also decided from the player's own body and camera, in a client script.

**Not done: two players in one server.** The runner starts a one-player playtest, and a second client is a second
Studio window on a PC whose memory was full (150 to 300 MB free during these runs). So "another player does not
see my see-through" rests on the server never holding it, not on a second screen.

## What was wrong in the test (not in the game)
- Shakes were counted over the whole approach, so another prop's shake on the way read as this prop's. Now a
  shake counts for the prop only if the body is at it; the others are listed apart.
- The hop's speed was read with the jump's rise in it (77 to 88 studs a second "just after leaving" off a 43
  fish). The hop's speed across the water is 44 at the touch, the curve says 42.
- A speed worked out from where the fish's tail was a frame ago dropped when the fish turned inside the prop (the
  test turns it there): 45 to 37 on a Clownfish that the engine had at 43 throughout. The check uses the engine's
  speed now.
- A Reef Shark coming in on a bite's burst (88) and settling to its own 70 inside the prop read as slowed. It is
  compared with its own speed now.
- Once the megalodon's usual reef wall was not whole (a wild fish had broken it) and the test picked a coral tree
  the megalodon could not be steered to in 25 s (never nearer than 92 studs): a miss of the test's steering. Such
  a run is now done again at another prop; it did not happen again.

## Not covered
- Played by hand; how it looks and feels (the shake's size, the 0.65, how quickly it turns).
- Two players (above). A prop broken by one player while another is inside it.
- Phones, and the frame rate with many props see-through at once. Here the worst frame while inside a prop was
  15 to 33 ms, against 20 to 36 ms in the 2 s before it, on this PC with its memory full: no long frame at a
  touch.
- The other fish that go through (only a Clownfish and a Reef Shark were ridden) and the other 13 that break.
