# The 3D auras' pictures

The twelve pictures of the auras' 3D look (`Config.Aura.Look` 2, [the note](../../../docs/design/auras.md), "Around the body"): our
own, drawn by sums (`python tools/auras/volume_sheets.py`), white on clear, tinted in the game.

**Not uploaded to Roblox** (that needs Hugo's yes). To upload: these twelve as they are, each id into `Auras.Sheets`
(`src/shared/Auras.luau`) under the same name.

| File | `Auras.Sheets` | Frames | Used by |
|---|---|---|---|
| `wisp.png` | Wisp | 8x8 flipbook | wisps at the feet, from tier 1 |
| `flame.png` | Flame | 8x8 | the ring of flames, the crown |
| `ring.png` | Ring | 4x4 | the turning ring on the ground |
| `sweep.png` | Sweep | 4x4 | the strokes over the ground |
| `shock.png` | Shock | 4x4 | the shock rings |
| `jet.png` | Jet | 4x4 | the spray at the foot |
| `haze.png` | Haze | 4x4 | the inner glow |
| `shaft.png` | Shaft | 4x4 | the shafts and the pillar |
| `mote.png` | Mote | 4x4 | embers |
| `arc.png` | Arc | 4x4 | the arcs |
| `ribbon.png` | Ribbon | none, repeats upward | the ribbons and serpents (Beams) |
| `glow.png` | Glow | a still | the pool of light on the ground |

In a live game, wisp, flame, glow, haze, mote and ring use engine textures. Ribbon draws plain beams.
Arc, jet, shaft, shock and sweep have no stand-in and their emitters stay off.

Studio reads local copies: `python tools/auras/volume_sheets.py --local`, then reopen Studio. A picture that changes needs a new
`Auras.SheetSet`, because Studio keeps the old one under its name.
