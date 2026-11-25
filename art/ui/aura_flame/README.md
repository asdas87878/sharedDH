# The aura flame's pictures

The six pictures the flame auras are drawn with (draft 4, [the note](../../../docs/design/auras.md), "The pictures"):
white with a see-through background, tinted in the game by each Beam's and emitter's colour. Drawn by the mock's own
script (`flame.py tex`, worktree `sharedDH-auras`, `work/auras4/`, copied here on 2026-11-24 unchanged).

- `aura_flame.png` (512 x 512, repeats top to bottom): the body. `aura_streaks.png`: the same, the thin dashes.
- `aura_tip.png` (192 x 384, used once): one pointed tongue of the flame's top.
- `aura_lick.png`, `aura_bubble.png`, `aura_arc.png` (128 x 128): the particles.

All six runtime pictures were uploaded on 2026-11-25. Their IDs are in `Auras.Pictures` in
`src/shared/Auras.luau` (commit `258e3cf3`). Look 1 uses these files from `upload/`:

- `aura_flame_f1_t2.png`, `aura_tip_f1_t2.png`, `aura_streaks_f1_t2.png` (the 180-degree rotation is baked in).
- `aura_lick_f1.png`, `aura_bubble_f1.png`, `aura_arc_f1.png`.

The PNGs beside this README are the source images. Look 2 uses the [3D aura sheets](../aura_volume/README.md).
