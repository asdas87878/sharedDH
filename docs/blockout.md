# Blockout

Claude's script-built blockout of the dock and the dive, `tools/studio/claude_blockout.luau`, built into
`Workspace.ClaudeBlockout`, 3,000 studs along X from the baseplate so the baseplate doesn't hide the underwater part. Every number
is at the top of the script. A player is about 5 studs tall.

The plan was two blockouts made separately and compared. The user's verdict on v1 (2026-11-09): theirs would look pretty much
the same, except that the elevation changed far too soon. The descent has to be gradual and the dive much longer, or the depth is
used up early and there's little left to progress through. That made v2.

## v2 (2026-11-09): long and gradual, with the world round it
895 parts. Sized after the reference's measured run (from the user's recording: riding about 55 a second, the first zone about
1,000, the second about 2,500, the player's best run 7,590):

- **10 zones, 23,760 studs, 1,612 studs deep,** about 7 minutes end to end at riding speed, 45 seconds a zone. Inside a zone the
  floor slopes 2 degrees; most borders have a drop-off (20 to 200 studs). The first four zones, the first version's, stay in
  the bright upper ocean (down to 418).
- **Zones** (the [roster](design/roster.md)'s variant C), with the real-ocean depth the gauge would show: Shallows 0 m, Coral
  Reef 10 m, Kelp Forest 40 m, Shipwrecks 80 m, Open Blue 150 m (after the big shelf-break drop), Twilight 200 m, Midnight
  1,000 m, Vents 2,000 m, Bone Graveyard 4,000 m (whale skeletons), The Underworld 6,000 m down to the Challenger Deep, 10,935 m
  (red cracks; the blockout's Megalodon stand-in sits at its end).
- **The world round it** ([workout 1](style/01-going-down.md)): terraces stepping up either side of the lane, built
  differently per zone; huge silhouettes far off (seamounts, kelp towers, whales); light shafts in the shallows; glowing things in
  the deep (jellies, vent chimneys, red cracks).
- **The dock** as in v1, now in a **lagoon ringed by reef**, some rocks breaking the surface with surf. The dive leaves through a gap
  in the ring. The open sea outside reads deep blue from above (a dark plane 300 down).
- `tools/art/depth_profile.py art/blockout/v2_zones.json docs/attachments/blockout-v2-profile.png` draws the side view.

![Side view, v2 against v1](attachments/blockout-v2-profile.png)

## v1 (2026-11-09): kept for the record
302 parts. The same dock, then a trench sloping 30 degrees through four 500-stud zones (Reef, Kelp Forest, Open Blue, Twilight)
and a 60-degree drop into the deep: 1,800 studs deep within 2,600. Far too fast.

- **The dock** floats on the sea at the surface: a round plaza with the spawn in the middle, eight player tanks in a horseshoe
  round it (glass boxes of water, each with its owner's sign), the stations along the open side (kiddie-ride training machines,
  aura stall, sell stand, sub dock), and a long pier out to the **dive board**, where every dive starts.

![The dock](attachments/claude-blockout-dock.jpg)
![v1 from the side](attachments/claude-blockout-side.jpg)
![A rider at the top of v1's reef](attachments/claude-blockout-reef.jpg)
![v1, leaving the kelp into the open blue](attachments/claude-blockout-openblue.jpg)
