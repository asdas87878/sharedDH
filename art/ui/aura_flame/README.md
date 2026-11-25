# The aura flame's pictures

The six pictures the flame auras are drawn with (draft 4, [the note](../../../docs/design/auras.md), "The pictures"):
white with a see-through background, tinted in the game by each Beam's and emitter's colour. Drawn by the mock's own
script (`flame.py tex`, worktree `sharedDH-auras`, `work/auras4/`, copied here on 2026-11-24 unchanged).

- `aura_flame.png` (512 x 512, repeats top to bottom): the body. `aura_streaks.png`: the same, the thin dashes.
- `aura_tip.png` (192 x 384, used once): one pointed tongue of the flame's top.
- `aura_lick.png`, `aura_bubble.png`, `aura_arc.png` (128 x 128): the particles.

**Not uploaded to Roblox** (that needs Hugo's yes). **The files to upload are the six in `upload/`, not the ones here:**
`aura_flame_f1_t2.png`, `aura_tip_f1_t2.png`, `aura_streaks_f1_t2.png` (each turned 180 degrees, as `Config.Aura.Turn` 2 picks
in Studio), `aura_lick_f1.png`, `aura_bubble_f1.png`, `aura_arc_f1.png`. Once all six ids are filled in, a picture is drawn as it
was uploaded and **`Config.Aura.Turn` does nothing**: the plain Flame, Tip and Streaks would be upside down and broken at the
joints. `python tools/auras/flame_pics.py upload` writes the folder again.

Studio reads a local copy: `python tools/auras/flame_pics.py` checks
them and copies them (with the Beam pictures' quarter turns, `Config.Aura.Turn`) into every Studio on this PC. Uploaded
ids go in `Auras.Pictures` (`src/shared/Auras.luau`). With no id in a live game, or no local copy in Studio, the old look
(the draft 2 particles) is drawn instead.
