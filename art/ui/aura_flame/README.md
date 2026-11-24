# The aura flame's pictures

The six pictures the flame auras are drawn with (draft 4, [the note](../../../docs/design/auras.md), "The pictures"):
white with a see-through background, tinted in the game by each Beam's and emitter's colour. Drawn by the mock's own
script (`flame.py tex`, worktree `sharedDH-auras`, `work/auras4/`, copied here on 2026-11-24 unchanged).

- `aura_flame.png` (512 x 512, repeats top to bottom): the body. `aura_streaks.png`: the same, the thin dashes.
- `aura_tip.png` (192 x 384, used once): one pointed tongue of the flame's top.
- `aura_lick.png`, `aura_bubble.png`, `aura_arc.png` (128 x 128): the particles.

**Not uploaded to Roblox** (that needs Hugo's yes). Studio reads a local copy: `python tools/auras/flame_pics.py` checks
them and copies them (with the Beam pictures' quarter turns, `Config.Aura.Turn`) into every Studio on this PC. Uploaded
ids go in `Auras.Pictures` (`src/shared/Auras.luau`). With no id in a live game, or no local copy in Studio, the old look
(the draft 2 particles) is drawn instead.
