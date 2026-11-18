# Props break by size, scripted playtests (2026-11-18)

Of [who breaks props](../design/archetypes.md) (Hugo, 2026-11-18). **Run by script in Hugo's Studio, not played by
hand.** The driver (`tools/studio/props_p1/`: `install.py` writes the install and remove scripts for the runner;
logger and commands as in `props_b1`) gets on a chosen fish in the sandbox (rerolled until it is Normal size), aims
at the nearest whole prop of a chosen kind, swims through it and on, level, and writes one line per run. For the
test: `TestMaxOxygen` 1,000,000 (so no fish was too strong), `Oxygen.KeepUp` 60 (so the meter lasted the swim),
the sandbox's no-fail on. All three were taken out afterwards.

"Server slow" is the share of speed the server sent (`Crashed`): the rule's own number. "Speed kept" is the least
speed the engine measured in the 0.8 s after the touch against the speed just before; it drops further than the
share because the crash's own feel (the kick and the speed curve, `Config.Crash`) and the steering come on top.

| Fish (size) | Prop (size) | Ratio | Rule | Boxes out | Server slow | Speed kept | Oxygen | Stun |
|---|---|---|---|---|---|---|---|---|
| Clownfish (8.0) | sea grass (8.2) | 0.98 | breaks (small), keeps 1 | 3/3 | none | 77-91% | the ride's drain only | 0 |
| Blue Chromis (5.6) | sea grass (5.4 / 7.8) | 1.03 / 0.72 | breaks (small), keeps 1 | 3/3, 2/3 | none | 93-94% | drain only | 0 |
| Clownfish (8.0) | fan coral (28.2) | 0.28 | goes through | 0/6 | none | 19-44% (the stun) | drain only | **1** |
| Reef Shark (22.9) | table coral (20.3) | 1.13 | breaks, keeps 0.56 | 3/3 | **0.56** | 6-15% | -3% of max | 0 |
| Reef Shark (22.9) | fan coral (27.5) | 0.83 | goes through | 0/6 | none | 81% | drain only | 0 |
| Megalodon (52.4) | fan coral (26.8) | 1.96 | breaks, keeps 0.89 | 3/6 | **0.89** | 87% | drain only | 0 |
| Megalodon (52.4) | fan coral (29.0) | 1.81 | breaks, keeps 0.84 | 5/6 | 0.71 (a bigger prop in the same hit) | 29% | | 0 |
| Megalodon (52.4) | table coral (17.4) | 3.01 | breaks, keeps 1 | 3/3 | 0.80 (a sea stack, 30.9, in the same hit) | 22% | | 0 |
| Sawfish, Breaker (17.3) | fan coral (28.2) | 0.61 | breaks (Breaker), keeps 1 | 6/6 | **none** | (a wall after) | **+4% of max**, the meter went up | 0 |
| Sawfish, Breaker (17.3) | sea grass (6.8 / 5.4) | 2.56 / 3.19 | breaks, keeps 1 | 3/3 | none | 93-98% | **+1% of max** | 0 |

- **The server and the rule agree every time.** When one hit broke several props, the slow it sent was the rule's
  number for the biggest of them: the Megalodon's wide body also took out a sea stack (30.9: 0.80) beside a table
  coral, and in another run a reef wall, a tube cluster and two sea stacks with a fan coral; the Reef Shark clipped
  a table coral (19.3: 0.59) on its way to a bigger fan coral it went through.
- **Grass, stones and tiles** broke for every fish, with no slow-down message and no stun. A big fish takes out
  whole patches of them as it goes (16 small props in one Reef Shark run).
- **The Breaker** broke a coral bigger than itself, was not slowed, and its meter went up while riding (988,593 to
  992,395 over the run, against the drain); the small props gave 1% each.
- **A fish smaller than the prop** went through it, unbroken, and was stunned once when it ran square into it (the
  Clownfish). The Reef Shark's pass at a fan coral gave no stun: it touched it while already passing beside it,
  which the stun leaves out (`Props.Stun`).
- Prop sizes as measured in Studio, and what that means for which fish break what: [archetypes](../design/archetypes.md),
  "Who breaks props". `Props.SmallSize` was set to 12 after the measuring (16 at first), so the table corals (15-21)
  count as real props and only grass, stones and tiles are free for everyone.

To judge by hand: the Slow at 0.5 for a fish just bigger, and how quickly it eases (`ClearRatio` 2.5,
`SlowCurve` 1.5). The engine's dip on a hard break (to 6-15% for a moment on the Reef Shark) is the crash's own feel
on top of the share; if a hard break feels too much like a wall, raise `Props.Slow`.
