"""The Flying Fish (zone 1's Uncommon) for tools/blender/voxel_kit.py (docs/style/04-voxel-style.md).
Its idea: a slim blue dart with wings. The one odd feature is the pair of very long pectoral fins, spread wide like a
glider's, as wide across as the fish is long.
- The body is a slim cigar in six slices: blue above, silver-white below, and one thin pale stripe along the flank from
  the eye to the tail, where the two meet.
- A blunt head: a blue snout block under a sloping forehead plate, a silver lower jaw, a big friendly eye.
- Each wing is its own part on a shoulder joint: two flat boxes, the outer one smaller, thinner and swept further
  back, with thin pale ray lines running along both.
- Smaller pelvic fins under the middle, a small dorsal and anal fin far back, and a forked tail whose lower lobe is
  the longer one (it is the one that sculls the water at take-off).
The rider sits behind the wings."""
import math

NAME, ZONE, RARITY = "Flying Fish", "ZONE 1 / SHALLOWS", "UNCOMMON"
U = 0.35
PALETTE = {"blue": "#2C62BC", "silver": "#E8EEF2", "pale": "#F3E4A0", "fin": "#4E9ADF", "black": "#1E2228"}
SEAT = (-3, 3, 2.5)
TEXTURES = [{"tile": "stud", "on": "top", "colours": ["blue"]}]
CHAIN = ["Head", "S1", "S2", "S3", "S4", "S5", "Tail"]
AMPLITUDES = [3, 5, 8, 11, 14, 20]

# the body: (part, from, to, cubes out, bottom, top, a step on the top corners, a step on the bottom corners). One number
# changes from slice to slice. The stripe is the row z = 0 on every one of them
SLICES = (("S1", -11, -6, 2, -3, 3, True, True), ("S2", -6, -1, 2, -3, 3, True, True), ("S3", -1, 4, 2, -2, 3, True, True),
          ("S4", 4, 8, 1, -2, 3, True, True), ("S5", 8, 11, 1, -1, 3, True, False), ("S5", 11, 13, 1, -1, 2, False, False))
SKULL = (2, -2, 3)


def pose(parts, phase):
    """a fish's swim, side to side down the chain, the wings held out stiff and rocking a little, as when it glides"""
    parts["Head"].rotation_euler.z = math.radians(2) * math.sin(phase + math.pi)
    for k, name in enumerate(CHAIN[1:]):
        parts[name].rotation_euler.z = math.radians(AMPLITUDES[k]) * math.sin(phase - 0.9 * (k + 1))
    for name, side in (("WingR", 1), ("WingL", -1)):
        parts[name].rotation_euler.x = side * (math.radians(3) + math.radians(8) * math.sin(phase - 0.6))


def slab(p, x0, x1, n, bot, top, step_top=True, step_bottom=True):
    """a slice of body: blue with a lighter top row, silver below the stripe, the pale stripe one cube row on the flank"""
    p.hull(x0, x1, n, bot, top, "blue", [(1, 1)] if step_top else [], [(1, 1)] if step_bottom else [])
    p.paint_sym(x0, x1, n, top - 1, top, "blue+")
    p.paint_sym(x0, x1, n, bot, 0, "silver")
    if step_bottom:
        p.paint_sym(x0, x1, n, bot, bot + 1, "silver-")
    p.paint_pair(x0, x1, n, n + 1, 0, 1, "pale")


def frame(p0, p1):
    """a flat box's length, its direction and the direction across it (in its own plane), as `beam` lays them"""
    d = [b - a for a, b in zip(p0, p1)]
    length = math.sqrt(sum(v * v for v in d))
    along = [v / length for v in d]
    thin = [-along[2] * along[0], -along[2] * along[1], 1 - along[2] * along[2]]
    n = math.sqrt(sum(v * v for v in thin))
    thin = [v / n for v in thin]
    across = [along[1] * thin[2] - along[2] * thin[1], along[2] * thin[0] - along[0] * thin[2], along[0] * thin[1] - along[1] * thin[0]]
    return length, along, across


def at(p0, along, across, t, c):
    return tuple(p + al * t + ac * c for p, al, ac in zip(p0, along, across))


def build(m):
    head = m.part("Head", (-11, 0, 0))
    slab(head, -15, -11, *SKULL)
    head.paint_pair(-15, -12, 2, 3, 0, 1, "blue")  # the stripe starts behind the eye
    # the face: a blue snout block tilted nose-down, a sloping forehead plate on it, a silver lower jaw tilted up to meet
    # it. Each starts inside the skull and is narrower than it
    head.beam((-14.0, 0, 0.8), (-16.3, 0, 0.65), 3.6, 1.8, "blue", flat="z")
    head.beam((-13.6, 0, 2.25), (-15.9, 0, 1.55), 2.4, 1.3, "blue+", flat="z")
    head.beam((-14.0, 0, -0.9), (-16.1, 0, -0.55), 2.6, 1.6, "silver", flat="z")
    # the eye: big and friendly, a dark pupil on a cream ring
    ring = (2.3, 2.8, 0.2, 1.8)
    head.block(-13.8, ring, -12.2, ring, "pale", mirror=True)
    pupil = (2.7, 3.05, 0.5, 1.5)
    head.block(-13.55, pupil, -12.55, pupil, "black", mirror=True)

    # the body, each slice on its own joint (the last two share one), with a sleeve into the piece in front
    parts, before = {}, SKULL
    for name, x0, x1, n, bot, top, step_top, step_bottom in SLICES:
        if name not in parts:
            parts[name] = m.part(name, (x0, 0, 0), "Head" if not parts else list(parts)[-1])
            parts[name].sym(x0 - 1, x0, 0, max(bot, before[1]) + 1, min(top, before[2]) - 1, "blue-")
        slab(parts[name], x0, x1, n, bot, top, step_top, step_bottom)
        before = (n, bot, top)
    parts["S2"].dent(-4, -2, 2, 1, 2, "blue-")  # the seat's leg slots, above the stripe

    # the wings: each on a shoulder joint just behind the head, two flat boxes with pale rays. The second is smaller,
    # thinner and swept further back, and starts inside the first
    for name, s in (("WingR", 1), ("WingL", -1)):
        wing = m.part(name, (-8.6, 2.5 * s, 1.2), "S1")
        a0, a1, b0, b1 = (-8.6, 1.2 * s, 1.2), (-6.6, 9.6 * s, 1.9), (-7.0, 8.8 * s, 1.83), (-2.6, 16.6 * s, 2.53)
        wing.beam(a0, a1, 4.8, 1.0, "fin", flat="z")
        wing.beam(b0, b1, 3.6, 0.5, "fin", flat="z")
        # the rays: three thin pale lines from the shoulder to the tip, each a slim box through the wing that stands a
        # little proud above and below. They bend where the wing does: the outer length of a ray is slimmer and starts
        # inside the end of the inner one, which runs just past the end of the first box
        (la, along_a, across_a), (lb, along_b, across_b) = frame(a0, a1), frame(b0, b1)
        for ca, cb in ((-1.4, -1.1), (0.0, 0.0), (1.4, 1.1)):
            wing.beam(at(a0, along_a, across_a, 0.8, ca), at(a0, along_a, across_a, la + 0.3, ca), 0.3, 1.3, "pale", flat="z")
            wing.beam(at(a0, along_a, across_a, la + 0.1, ca), at(b0, along_b, across_b, lb - 0.3, cb), 0.2, 0.85, "pale", flat="z")

    # the pelvic fins: a small pair under the middle, out of the silver flank, two boxes each
    parts["S3"].beam((0.6, 1.2, -0.6), (3.4, 5.2, -1.6), 2.4, 0.7, "fin", flat="z", mirror=True)
    parts["S3"].beam((2.7, 4.3, -1.375), (5.2, 7.0, -2.13), 1.6, 0.3, "fin-", flat="z", mirror=True)
    # a small dorsal fin and anal fin, far back and opposite each other
    parts["S4"].beam((5.0, 0, 1.9), (7.8, 0, 3.2), 1.6, 0.6, "blue-")
    parts["S4"].beam((5.2, 0, -0.7), (7.7, 0, -2.5), 1.5, 0.6, "silver-")

    # the tail, on its own joint: a root block and a fork. The lower lobe is the longer and the thicker one
    tail = m.part("Tail", (13, 0, 0.5), "S5")
    tail.beam((12.5, 0, 0.5), (14.3, 0, 0.5), 2.2, 1.6, "blue")
    tail.beam((13.6, 0, 0.9), (16.0, 0, 3.4), 2.0, 0.9, "blue")
    tail.beam((15.3, 0, 2.7), (17.0, 0, 4.6), 1.4, 0.5, "blue-")
    tail.beam((13.6, 0, 0.2), (16.6, 0, -3.4), 2.2, 1.3, "blue")
    tail.beam((15.8, 0, -2.5), (18.3, 0, -5.6), 1.5, 0.7, "blue-")
