"""Level 1 stays the seahorse in the game now (the user, 2026-11-25): this only loads Hugo's model, tiers/trainer.py at its
level 1, so the line-up picture shows it, on a spring as the game draws it. It is not exported: the game keeps its own."""
import math
import os
import types

HERE = os.path.dirname(os.path.abspath(__file__))
import sys  # noqa: E402

sys.path.insert(0, os.path.dirname(HERE))
import common as c  # noqa: E402

LEVEL = 1
_old = types.ModuleType("trainer")
with open(os.path.join(HERE, "..", "..", "tiers", "trainer.py"), encoding="utf-8") as f:
    exec(f.read().replace("\nGAME = False", "\nGAME = True"), _old.__dict__)
globals().update({k: v for k, v in _old.__dict__.items() if not k.startswith("__") and k not in ("math",)})
GLOW, FLOATING = _old.__dict__.get("GLOW", {}), ["Coil"]
# cubes: the stand's foot to x 0, floor 0; the toy over the spring, as TrainService places it (its SpringAt on the axis, 5.2 studs)
SHIFT = {"Stand": (-4.5, 27), "Body": (5.5, -4.7)}
SEAT = (2, 30.3, 4.6)
SWING = 11


def build(m):
    _old.build(m)
    coil, n, per = m.part("Coil", (4.5, 0, -23), "Stand"), 40, 10

    def at(k):
        a = 2 * math.pi * k / per
        return (4.5 + 2.6 * math.cos(a), 2.6 * math.sin(a), -23.1 + 15.3 * k / n)

    for k in range(n):
        a, b = at(k), at(k + 1)
        d = [(j - i) * 0.12 for i, j in zip(a, b)]
        w = 1.2 - 0.13 * (k % 2) - 0.02 * (k // per)
        coil.beam(tuple(i - v for i, v in zip(a, d)), tuple(i + v for i, v in zip(b, d)), w, w, "s_coil", flat="z")
