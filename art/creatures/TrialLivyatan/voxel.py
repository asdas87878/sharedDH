"""Livyatan, a trial of docs/style/11-rare-wow-study.md (remodels, round 1), for tools/blender/voxel_kit.py. It stands beside
the game's Livyatan (art/creatures/Livyatan) and replaces nothing. Designed from the real animal: a sperm whale's
outline with a killer's mouth.
Its idea, kept: a battering ram with tusks. A third of it is one blunt box of a head, and under that box hangs a narrow
ivory jaw full of tusks.
- One hero hue at full strength: ultramarine in three values. The given hex is the back; a lighter ultramarine flank
  runs nose to tail as one big shape; a deep ultramarine for the brow, flippers, fluke tips and the knuckle ridge. A
  pale ice-blue belly. The tusks and the jaw ivory.
- Glow, about 5%, as two shapes: the open mouth lit inside in hot coral (the throat, the tongue and both gums), seen
  through the tusks; and a molten gold halo two cubes wide round the dark pupil of the low eye.
- The back line breaks upward: behind the seat a ridge of knuckle humps runs down to the flukes, one blunt faceted
  knuckle on every slice, 3 cubes high at the front and 2 at the tail, each leaning back.
- The head: a forehead cap one cube smaller all round and undercut, the long high case, a deeper cheek that holds the
  eye and the jaw's hinge. The upper lip is a whole block tilted nose-up with tusks hanging from it; the lower jaw is two
  slim boxes in a chain, tilted nose-down, so the mouth stands open in a wedge.
- The body is sixteen slices on joints, the same plan as the game's model; small paddle flippers; broad flat flukes.
The rider sits on the widest slice, on a saddle of back between two wells for the legs, well in front of the ridge."""
import math

NAME, ZONE, RARITY = "Livyatan (trial)", "ZONE 7 / MIDNIGHT", "LEGENDARY"
U = 0.5
PALETTE = {"hide": "#2747C9", "flank": "#4F74EA", "deep": "#182C8E", "belly": "#CFE3F7", "jaw": "#EDE2C4", "tooth": "#FFF7DE",
           "coral": "#FF5A4A", "gold": "#FFB327", "black": "#0E1430"}
SHADE = 0.9
SEAT = (10.5, 8, 1.5)
GLOW = {"coral": 1.0, "gold": 1.0}
LIGHTS = [("Head", (-18.0, 0.0, -5.0), "#FF6A50", 40, 7.0)]
TEXTURES = [{"tile": "stud", "on": "top", "colours": ["hide"]}]
FRAME, ORTHO, ORTHO_SWIM = 3.2, 46.0, 52.0

# the body: each slice is (length, cubes out, bottom, top), as the game's model
SLICES = ((3, 7, -7, 7), (3, 7, -8, 7), (4, 7, -8, 8), (4, 8, -8, 8), (3, 8, -8, 8), (3, 7, -8, 8), (3, 7, -7, 8), (4, 6, -7, 8),
          (3, 6, -6, 7), (3, 5, -6, 7), (3, 5, -5, 6), (2, 4, -5, 5), (2, 3, -4, 5), (2, 3, -4, 4), (2, 2, -3, 4), (2, 2, -3, 3))
BODY_FROM = -2
LINE = -1  # the flank runs from the belly up to this height (exclusive)
CHAIN = ["Head"] + [f"S{i + 1}" for i in range(len(SLICES))] + ["Tail", "Fluke"]
AMPLITUDES = [0.4, 0.5, 0.6, 0.8, 1.0, 1.2, 1.5, 1.8, 2.2, 2.6, 3.0, 3.5, 4.0, 4.5, 5.0, 5.5, 6.5, 11.0]
# the knuckle ridge, from slice 7 back: (height, base half width, top half width)
KNUCKLES = ((3.0, 1.8, 0.8), (3.0, 1.7, 0.8), (2.8, 1.6, 0.75), (2.6, 1.5, 0.7), (2.5, 1.4, 0.65), (2.3, 1.3, 0.6),
            (2.2, 1.2, 0.55), (2.1, 1.1, 0.5), (2.0, 1.0, 0.5), (2.0, 0.95, 0.45))


def pose(parts, phase):
    """a whale's swim: the front half is stiff, the wave grows down the tail stock, up and down, and the flukes beat at
    the end of it. The jaw opens and shuts once a beat; the flippers row a little"""
    parts["Head"].rotation_euler.y = math.radians(1.0) * math.sin(phase + math.pi)
    for k, name in enumerate(CHAIN[1:]):
        parts[name].rotation_euler.y = math.radians(AMPLITUDES[k]) * math.sin(phase - 0.26 * (k + 1))
    parts["Jaw"].rotation_euler.y = -math.radians(9) * (0.5 + 0.5 * math.sin(phase))
    for name, side in (("FlipperR", 1), ("FlipperL", -1)):
        parts[name].rotation_euler.x = side * math.radians(12) * math.sin(phase - 0.8)
        parts[name].rotation_euler.z = side * math.radians(7) * math.sin(phase - 1.8)


def top_steps(n):
    return [(3, 1), (2, 1), (1, 1)] if n >= 6 else ([(2, 1), (1, 1)] if n >= 4 else [(1, 1)])


def bottom_steps(n):
    return [(2, 1), (1, 1)] if n >= 5 else [(1, 1)]


def belly_edge(bot):
    """how high the ice belly comes: deepest under the shoulders, rising to the tail in one line"""
    return bot + (3 if bot <= -7 else (2 if bot <= -5 else 1))


def slab(p, x0, x1, n, bot, top, belly=True):
    """a slice of body: stepped corners, ultramarine back (lighter on the top row), the lighter flank, the ice belly"""
    steps = top_steps(n)
    p.hull(x0, x1, n, bot, top, "hide", steps, bottom_steps(n))
    p.paint_sym(x0, x1, n, top - 1, top, "hide+")
    p.paint_sym(x0, x1, n, bot, LINE, "flank")
    if belly:
        p.paint_sym(x0, x1, n, bot, belly_edge(bot), "belly")
        p.paint_sym(x0, x1, n, bot, bot + 1, "belly-")


def knuckle(p, x0, x1, base_z, height, hw0, hw1, colour):
    """one blunt faceted knuckle: a frustum, its base buried in the back, its smaller top leaning back"""
    mid, half = (x0 + x1) / 2, (x1 - x0) / 2
    top_half, lean = half * 0.7, half * 0.22
    zb, zt = base_z, base_z + height
    verts = [(x0, -hw0, zb), (x1, -hw0, zb), (x1, hw0, zb), (x0, hw0, zb),
             (mid - top_half + lean, -hw1, zt), (mid + top_half + lean, -hw1, zt), (mid + top_half + lean, hw1, zt),
             (mid - top_half + lean, hw1, zt)]
    faces = [(3, 2, 1, 0), (4, 5, 6, 7), (0, 1, 5, 4), (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7)]
    p.solid(verts, faces, colour)


def build(m):
    head = m.part("Head", (BODY_FROM, 0, 0))
    three, two = [(3, 1), (2, 1), (1, 1)], [(2, 1), (1, 1)]
    head.hull(-28, -26, 5, -2, 7, "hide", three, two)
    head.paint_sym(-28, -26, 5, 6, 7, "hide+")
    head.paint_sym(-28, -26, 5, -2, LINE, "flank")
    head.carve(-28, -27, -5, 6, -2, 0)  # the forehead is undercut: its lower front corner steps back to the lip
    slab(head, -26, -13, 6, -3, 8, belly=False)
    slab(head, -13, -8, 6, -5, 8)
    slab(head, -8, BODY_FROM, 6, -7, 7)
    skull = (6, -7, 7)
    hole = (-2.5, -1.2, 7.85, 8.14)  # the blowhole, left of the middle as a sperm whale's is
    head.block(-25.3, hole, -23.7, hole, "deep")

    # the upper lip: one ivory block under the forehead, tilted nose-up, with a lit gum inside its edge and the tusks
    lx0, lx1, lz0, lz1, lthick = -11.5, -26.9, -3.8, -2.73, 1.6

    def lip_bottom(x):
        return lz0 + (lz1 - lz0) * (x - lx0) / (lx1 - lx0) - lthick / 2

    head.beam((lx0, 0, lz0), (lx1, 0, lz1), 8.0, lthick, "jaw", flat="z")
    head.beam((-12.6, 0, lip_bottom(-12.6) - 0.05), (-26.5, 0, lip_bottom(-26.5) - 0.05), 7.0, 0.3, "coral", flat="z")
    for x, long in ((-25.5, 2.8), (-22.9, 2.7), (-20.3, 2.5), (-17.7, 2.3), (-15.1, 2.0)):
        head.tooth(x, 2.8, lip_bottom(x) - 0.05, 1.3, long, "tooth")
    head.tooth(-25.8, 1.0, lip_bottom(-25.8) - 0.05, 1.1, 2.4, "tooth")
    # the lit throat: hot coral filling the mouth behind the tusks, from the hinge to the front, buried in lip and jaw
    head.block(-11.8, (-1.55, 1.55, -6.0, -3.9), -24.2, (-1.3, 1.3, -7.9, -3.2), "coral")

    # the eye, low and far back: a deep socket, a molten gold halo two cubes wide, a dark pupil standing out of it; the
    # brow slants down to the front and comes past it
    ring = (6.38, 6.72, -3.9, 0.5)
    head.block(-9.0, ring, -3.4, ring, "deep", mirror=True)
    # the halo is two crossed gold blocks, a wide one and a tall one, so its corners are cut and it reads round
    wide = (6.5, 7.0, -2.9, -0.1)
    head.block(-8.6, wide, -3.8, wide, "gold", mirror=True)
    tall = (6.5, 6.88, -3.5, 0.4)
    head.block(-8.0, tall, -4.4, tall, "gold", mirror=True)
    pupil = (6.85, 7.35, -2.3, -0.7)
    head.block(-7.2, pupil, -5.2, pupil, "black", mirror=True)
    head.beam((-10.0, 6.81, 0.1), (-3.2, 6.81, 1.0), 1.6, 1.34, "deep", mirror=True)

    # the lower jaw, on its own joint: two slim ivory boxes in a chain, tilted nose-down, a lit tongue and its tusks
    jaw = m.part("Jaw", (-8, 0, -5.8), "Head")
    jaws = ((-7.4, -16.0, -5.9, -7.0, 5.0, 1.6), (-15.2, -24.6, -6.95, -8.2, 3.6, 1.2))

    def jaw_top(k, x):
        x0, x1, z0, z1, _, thick = jaws[k]
        return z0 + (z1 - z0) * (x - x0) / (x1 - x0) + thick / 2

    for x0, x1, z0, z1, wide, thick in jaws:
        jaw.beam((x0, 0, z0), (x1, 0, z1), wide, thick, "jaw", flat="z")
    jaw.beam((-16.2, 0, jaw_top(1, -16.2) + 0.05), (-24.3, 0, jaw_top(1, -24.3) + 0.05), 2.0, 0.3, "coral", flat="z")
    for x in (-23.8, -21.6, -19.0, -16.9):
        jaw.tooth(x, 1.0, jaw_top(1, x) + 0.05, 1.1, -2.0, "tooth", lean=(0.0, 0.2))

    # the body: sixteen slices, each on its own joint
    segs, spans, x = [], [], BODY_FROM
    for i, (length, n, bot, top) in enumerate(SLICES):
        segs.append(m.part(f"S{i + 1}", (x, 0, 0), "Head" if i == 0 else f"S{i}"))
        spans.append((x, x + length, n, bot, top))
        x += length
    end = x
    first = len(SLICES) - len(KNUCKLES)
    for i, (seg, (x0, x1, n, bot, top)) in enumerate(zip(segs, spans)):
        slab(seg, x0, x1, n, bot, top)
        fn, fbot, ftop = spans[i - 1][2:5] if i else skull
        small = min(n, fn)
        up = max(len(top_steps(n)), len(top_steps(fn)))
        down = max(len(bottom_steps(n)), len(bottom_steps(fn)))
        seg.sym(x0 - 1, x0, max(small - 2, 0), max(bot, fbot) + down, min(top, ftop) - up, "hide-")
        if i >= first:  # the knuckle ridge, one on each slice behind the seat
            tall, hw0, hw1 = KNUCKLES[i - first]
            knuckle(seg, x0 + 0.25, x1 - 0.25, top - 0.3, tall + 0.3, hw0, hw1, "deep")

    # the seat: on the widest slice, a saddle of back between two wells for the legs
    segs[3].carve_pair(9, 12, 2, 4, 6, 8)

    # the flippers: small paddles low behind the head, each on its own joint, in two boxes swept back
    for name, side in (("FlipperR", 1), ("FlipperL", -1)):
        part = m.part(name, (0.5, 6.8 * side, -4.5), "S1")
        part.beam((-0.2, 6.3 * side, -4.3), (3.0, 10.0 * side, -5.6), 3.4, 1.1, "hide", flat="z")
        part.beam((2.2, 9.1 * side, -5.3), (5.6, 11.6 * side, -6.4), 2.6, 0.6, "deep", flat="z")

    # the tail: a short stock, then broad flat flukes on a joint of their own, each lobe ending in a deep tip
    tail = m.part("Tail", (end, 0, 0), f"S{len(SLICES)}")
    tail.beam((end - 0.6, 0, 0), (end + 3.2, 0, 0), 2.4, 3.8, "hide", flat="z")
    fluke = m.part("Fluke", (end + 2.4, 0, 0), "Tail")
    fluke.beam((end + 1.4, 0, 0), (end + 5.8, 0, 0), 8.4, 1.5, "hide", flat="z")
    fluke.beam((end + 3.5, 2.2, 0), (end + 6.6, 9.4, 0), 4.2, 1.0, "hide", flat="z", mirror=True)
    fluke.beam((end + 6.0, 8.2, 0), (end + 7.4, 11.4, 0), 2.8, 0.55, "deep", flat="z", mirror=True)
