"""The Seahorse (zone 1's Rare: a big friendly seahorse, ridden like a horse) for tools/blender/voxel_kit.py
(docs/style/04-voxel-style.md).
Its idea: a seahorse leaning forward until its back is a saddle. The neck arches up in front of the rider like a horse's,
the round pale belly hangs under the chest, and the tail curls under in a chain of shrinking blocks.
- The trunk is five slices of cubes, one rigid piece: a chest bulge, the deep belly, the seat, and two that taper to the tail.
- The neck is two turned blocks, the upper leaning further forward: an arch. The head is a box with a long tube snout of
  three blocks in a chain, pointing a little down, a small crest leaning back, and a friendly eye (a dark pupil on cream).
- The armour rings are its one pattern: a thin raised band round each slice of the trunk, and a collar on every joint of
  the neck and the tail.
- A small fan fin of three rays stands on the back behind the seat, on its own joint (it flutters).
- The tail is six blocks on joints, each smaller than the last and starting inside it, curling down, forward and up.
The rider sits behind the neck, legs in a shallow slot either side. It swims upright, bobbing."""
import math

NAME, ZONE, RARITY = "Seahorse", "ZONE 1 / SHALLOWS", "RARE"
U = 0.4
PALETTE = {"coral": "#F07A3E", "belly": "#FBDDA6", "rust": "#C9502A", "cream": "#FFF0CC", "black": "#22262B"}
SEAT = (1, 8, 4.6)
FRAME, ORTHO = 1.9, 30.0
TEXTURES = [{"tile": "stud", "on": "all", "colours": ["belly"]}]

# the trunk: (from, to, cubes out, bottom, top, the pale belly comes up to here, where its ring is)
SLICES = ((-9, -6, 3, 0, 8, 6, -7.8), (-6, -2, 4, -2, 10, 4, -4.3), (-2, 4, 4, -3, 8, 1, 3.0), (4, 8, 3, -2, 7, 0, 6.6),
          (8, 11, 2, 0, 5, 0, 9.2))
# the tail: (from, to, how thick), each block starting inside the one before
TAIL = (((9.0, 2.5), (13.0, -1.5), 4.2), ((11.9, -0.3), (12.5, -6.4), 3.6), ((12.4, -5.4), (9.8, -10.4), 3.0),
        ((10.6, -9.7), (5.4, -11.5), 2.4), ((6.5, -11.2), (3.6, -8.4), 1.8), ((4.2, -9.0), (5.6, -6.9), 1.2))
_rest = {}


def pose(parts, phase):
    """a seahorse's swim: it hangs upright and bobs, rocking a little; the head nods against the rock, the fan fin
    flutters fast, and the tail's curl tightens and loosens down the chain"""
    body = parts["Body"]
    if "z" not in _rest:
        _rest["z"] = body.location.z
    body.location.z = _rest["z"] + 0.9 * U * math.sin(phase)
    body.rotation_euler.y = math.radians(2.5) * math.sin(phase - 1.2)
    parts["Head"].rotation_euler.y = math.radians(4) * math.sin(phase - 1.2 + math.pi)
    parts["Fin"].rotation_euler.x = math.radians(16) * math.sin(3 * phase)
    for k, amp in enumerate((2, 3, 4, 6, 8, 10)):
        parts[f"T{k + 1}"].rotation_euler.y = math.radians(amp) * math.sin(phase - 0.6 * (k + 1))


def steps(n):
    """the corners of a slice: (the back's, the belly's). The belly is rounder: two steps where the body is wide"""
    return ([(2, 1)], [(2, 1), (1, 1)]) if n >= 4 else ([(1, 1)], [(1, 1)])


def collar(p, a, b, size, colour="rust", back=0.5, past=0.15, grow=0.5):
    """an armour ring on a joint: a short, slightly bigger block that caps the end of the block from a to b"""
    d = [q - r for q, r in zip(b, a)]
    length = math.sqrt(sum(v * v for v in d))
    d = [v / length for v in d]
    p.beam(tuple(q - back * v for q, v in zip(b, d)), tuple(q + past * v for q, v in zip(b, d)), size + grow, size + grow, colour)


def build(m):
    body = m.part("Body", (0, 0, 3))
    for x0, x1, n, bot, top, belly, ring in SLICES:
        ts, bs = steps(n)
        body.hull(x0, x1, n, bot, top, "coral", ts, bs)
        body.paint_sym(x0, x1, n, top - 1, top, "coral+")
        if belly > bot:
            body.paint_sym(x0, x1, n, bot, belly, "belly")
            body.paint_sym(x0, x1, n, bot, bot + 1, "belly-")
        body.band(ring, ring + 0.6, n, bot, top, "rust", ts, bs)
    body.dent(0, 2, 4, 3, 6, "coral-")  # the rider's leg slots
    # the neck: two turned blocks, the upper one thinner and leaning further forward, with a ring where they meet
    low = ((-2.6, 0, 6.5), (-3.8, 0, 12.0))
    body.beam(low[0], low[1], 4.6, 4.6, "coral")
    collar(body, low[0], low[1], 4.6, grow=0.6)
    body.beam((-3.6, 0, 11.0), (-5.6, 0, 16.2), 4.0, 4.0, "coral")

    head = m.part("Head", (-5, 0, 15), "Body")
    head.hull(-9, -3, 2, 14, 20, "coral", [(1, 1)], [(1, 1)])
    head.paint_sym(-9, -3, 2, 19, 20, "coral+")
    # the snout: a muzzle, a long tube and a lip, in a chain, pointing a little down
    head.beam((-7.5, 0, 16.6), (-11.5, 0, 15.3), 3.4, 3.6, "coral", flat="z")
    tube = ((-10.8, 0, 15.6), (-16.0, 0, 13.9))
    head.beam(tube[0], tube[1], 2.0, 2.0, "coral", flat="z")
    collar(head, tube[0], tube[1], 2.0, back=0.7, past=0.25, grow=0.6)
    # the eye: a dark pupil on a cream ring (a friendly animal: no brow)
    ring = (2.3, 2.8, 16.2, 18.8)
    head.block(-8.0, ring, -5.4, ring, "cream", mirror=True)
    pupil = (2.6, 3.1, 16.7, 18.1)
    head.block(-7.5, pupil, -6.1, pupil, "black", mirror=True)
    # the crest: two small blocks leaning back, the second smaller and starting inside the first
    head.beam((-5.0, 0, 19.5), (-4.4, 0, 21.2), 2.6, 2.0, "coral")
    head.beam((-4.6, 0, 20.7), (-3.9, 0, 22.3), 1.6, 1.2, "rust")

    # the fan fin on the back, behind the seat: three rays from one root, the middle one longest
    fin = m.part("Fin", (5.8, 0, 7), "Body")
    fin.beam((5.8, 0, 6.0), (8.2, 0, 11.8), 2.2, 1.2, "cream")
    fin.beam((5.8, 0, 6.0), (5.2, 0, 11.0), 1.9, 0.8, "cream")
    fin.beam((5.8, 0, 6.0), (10.4, 0, 9.6), 1.9, 0.4, "cream")

    # the tail: six blocks on joints, each smaller than the last, curling down, forward and up; a ring on each joint
    for k, ((ax, az), (bx, bz), size) in enumerate(TAIL):
        part = m.part(f"T{k + 1}", (ax, 0, az), f"T{k}" if k else "Body")
        part.beam((ax, 0, az), (bx, 0, bz), size, size, "coral")
        if k < len(TAIL) - 2:  # the last two are the curl's tip: plain
            collar(part, (ax, 0, az), (bx, 0, bz), size)
