# Playtest 2026-11-20: the held fish after the sub, and the faster sub (task f2)

Scripted, in a one-player Studio playtest on Hugo's PC; **not played by hand**. Design: [the submarine](../design/submarine.md),
"The held fish, and a faster sub". Driver: `tools/studio/held_sub_check.py` (`install`, then in Play
`run [timing] [held] [plain]`, then `remove`). Full log: [2026-11-20-held-fish-sub.log](2026-11-20-held-fish-sub.log).

Setup each time: two fish in the hands (a Big Gold Reef Shark, a Pufferfish), a Small Clownfish in the tank, every sub
bought. The player is stood in the water past the start strip, as the dive's step off the dock.

## What was checked
| Check | Result |
|---|---|
| Hold the Reef Shark, sub to land 5, the tank's Clownfish ALSO picked under RIDE WITH | The trip is made with a fish; at the drop the Reef Shark swims up and the kick seats the rider: `RIDING ReefShark size=Big variant=Gold`, 9.1 s from the water. The held fish wins over the tank pick |
| Back home after that ride | `Dock`, still `HeldFish=ReefShark`, hands unchanged `[ReefShark/Big/Gold, Pufferfish/Normal]`: borrowed, not lost |
| Plain dive-in (NO SUB equipped), holding the Reef Shark | `Riding` 0.06 s after going in, on `ReefShark Big Gold`; hands unchanged |
| Plain dive-in, nothing held | As before: `Free`, the dive-in's hop (`Jumping`), then a herd fish (`Riding` at 1.1 s) |
| Sub to lands 2, 5, 10, nothing held (the fling) | Each run as planned (table below); land 2's first fling missed (left floating, forgiven), two more runs to land 2 each hooked a fish |

The ridden Reef Shark breaks off the meter on landing (Oxygen 13.3 of 20) and turns angry (red pulse, seen in
`held-dive-plain.png`'s run): an Epic is too strong for the starting Oxygen, the usual rule for any fish.

## Timing
The run is the pick-up's end to NOW ARRIVING; "in to drop" from the water to the drop. Before is the old plan on the
same distances (it matches the 2026-11-17 logs: land 5 and 10 dropped about 14 s in, land 2 about 8 s).

| Land | Run distance | Before: run, top speed | Before: in to drop | After: run, top speed | After: in to drop |
|---|---|---|---|---|---|
| 2 Coral Reef | 1,294 studs | 4.0 s, 520 | 8.0 s | 3.2 s, 507 | 6.4 s |
| 5 Open Blue | 8,822 studs | 10.0 s, 1,017 | 14.0 s | 5.3 s, 2,120 | 8.5 s |
| 10 The Underworld | 21,365 studs | 10.0 s, 2,476 | 14.0 s | 6.5 s, 4,252 | 9.7 s |

Phases after: approach 1.6 s, pick-up 0.96, arrive 0.64, fling 0.8, the fish's swim-in 1.12, the kick 0.48 (all
about a fifth shorter). Measured phase changes on the land 5 run with the held fish: Pickup at 1.64 s, Ride 2.59, Arrive
7.93, Drop 8.59, riding at 9.15.

## Pictures
- [held-sub-ride.gif](../attachments/held-sub-ride.gif): the whole trip, a frame about every 0.8 s (the fish held on
  the dock, the pick-up, the run, NOW ARRIVING with the gold Reef Shark beside the sub, the kick, riding it).
- [held-sub-1-hold.png](../attachments/held-sub-1-hold.png), [held-sub-2-beside.png](../attachments/held-sub-2-beside.png),
  [held-sub-3-kick.png](../attachments/held-sub-3-kick.png), [held-sub-4-riding.png](../attachments/held-sub-4-riding.png),
  [held-dive-plain.png](../attachments/held-dive-plain.png) (the plain dive-in, on the held fish under water).
- The shots were taken with the end-of-dive screen (left up by the script's quick trips home) hidden on the test
  client only. The run's land titles are task t1's, synced in the same session.

## Not done
- Not played by hand; one player only.
- The FOV on a far run (`Sub.FovFar`) is only seen in the frames, not measured.
