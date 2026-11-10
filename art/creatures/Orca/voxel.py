"""The Orca (zone 5's Epic: a killer whale) for tools/blender/voxel_kit.py (docs/style/04-voxel-style.md).
Its idea: the tall fin and the bold dark and white. A heavy round body in very dark navy over a white belly, one very
tall straight dorsal fin, and three marks: a white oval behind each eye, a pale saddle behind the fin, and the white
flank lobe that climbs the side behind it.
- The body is a chain of slices on joints. From one slice to the next one thing changes by one cube. The corners are
  one broad step and a narrow top, so the body reads round.
- The head is a short skull and two big tilted blocks (the melon and the beak) over a white lower jaw in two boxes: the
  mouth is the line where the dark meets the white.
- The dorsal fin is three boxes, each smaller and thinner, nearly upright. The flippers are broad paddles on their own
  joints. The fluke lies flat on a joint of its own. It swims by bending up and down.
The rider sits in front of the fin, where the back is biggest."""
import math

NAME, ZONE, RARITY = "Orca", "ZONE 5 / OPEN BLUE", "EPIC"
U = 0.45
PALETTE = {"back": "#1B2233", "white": "#F1F0EA", "saddle": "#7E889B", "black": "#07080B"}
SEAT = (-12, 6, 6.5)
FRAME, ORTHO, ORTHO_SWIM = 2.5, 36.0, 40.0
TEXTURES = [{"tile": "stud", "on": "top", "colours": ["back"]}]

# the body: each part is one or more slices (x from, x to, cubes out, bottom, top, how high the white comes). One number
# changes from slice to slice. The tail narrows faster than it thins: an orca's tail stock is tall and slim
HEAD = ((-28, -25, 5, -5, 5, -2), (-25, -22, 5, -6, 5, -2))
BODY = (
    ("S1", ((-22, -18, 6, -6, 5, -2),)),  # the flippers
    ("S2", ((-18, -14, 6, -6, 6, -2),)),
    ("S3", ((-14, -10, 6, -7, 6, -2),)),  # the seat
    ("S4", ((-10, -3, 6, -7, 6, -2),)),  # the dorsal fin
    ("T1", ((-3, 2, 6, -6, 6, -2),)),  # the saddle
    ("T2", ((2, 5, 5, -6, 6, -2), (5, 8, 5, -5, 6, -1))),
    ("T3", ((8, 11, 5, -5, 5, 1), (11, 13, 4, -5, 5, 1))),  # the flank lobe
    ("T4", ((13, 15, 4, -4, 5, -1), (15, 17, 3, -4, 5, -1))),
    ("T5", ((17, 19, 3, -4, 4, -1), (19, 21, 3, -3, 4, -1))),
    ("T6", ((21, 23, 2, -3, 4, -1), (23, 24, 2, -3, 3, -1))),
)
CHAIN = [name for name, _ in BODY] + ["Tail", "Fluke"]
AMPLITUDES = [1, 1.5, 2, 2.5, 3.5, 4.5, 5.5, 6.5, 7.5, 8.5, 9, 14]


def pose(parts, phase):
    """a whale's swim: the wave runs down the body up and down, small in the heavy front, big at the tail stock and
    the fluke. The flippers row a little"""
    parts["Head"].rotation_euler.y = math.radians(1.5) * math.sin(phase + math.pi)
    for k, name in enumerate(CHAIN):
        parts[name].rotation_euler.y = math.radians(AMPLITUDES[k]) * math.sin(phase - 0.5 * (k + 1))
    for name, side in (("FlipperR", 1), ("FlipperL", -1)):
        parts[name].rotation_euler.x = side * math.radians(10) * math.sin(phase - 0.8)
        parts[name].rotation_euler.z = side * math.radians(6) * math.sin(phase - 1.8)


def steps(n):
    """the corners: a narrow top row and one broad step where the body is thick, fewer as it thins"""
    return [(3, 1), (1, 2)] if n >= 5 else ([(2, 1), (1, 1)] if n == 4 else [(1, 1)])


def tall(n):
    return sum(t for _, t in steps(n))


def slab(p, x0, x1, n, bot, top, edge):
    """a slice of body: stepped corners, dark back (a tone lighter on the top row), white from `edge` down"""
    p.hull(x0, x1, n, bot, top, "back", steps(n), steps(n))
    p.paint_sym(x0, x1, n, top - 1, top, "back+")
    p.paint_sym(x0, x1, n, bot, edge, "white")
    p.paint_sym(x0, x1, n, bot, bot + 1, "white-")


def build(m):
    head = m.part("Head", (HEAD[-1][1], 0, 0))
    for h in HEAD:
        slab(head, *h)
    # the melon and the beak: two big blocks in a chain, each tilted nose-down, the second lower and narrower and
    # starting inside the first. Under each a white jaw box, set in a little from the dark lip above it
    head.beam((-26.8, 0, 1.2), (-30.4, 0, 0.6), 8.6, 5.6, "back", flat="z")
    head.beam((-29.6, 0, 0.0), (-32.2, 0, -0.5), 6.2, 3.8, "back", flat="z")
    head.beam((-27.0, 0, -2.5), (-30.2, 0, -3.03), 8.2, 2.0, "white", flat="z")
    head.beam((-29.5, 0, -2.555), (-31.9, 0, -3.015), 5.8, 1.6, "white", flat="z")
    # the eye: just above the corner of the mouth. A dark pupil on a thin pale socket, or it is lost in the dark head
    socket = (5.3, 5.75, -1.4, 0.0)
    head.block(-27.2, socket, -25.8, socket, "saddle", mirror=True)
    pupil = (5.6, 6.1, -1.2, -0.2)
    head.block(-27.0, pupil, -26.0, pupil, "black", mirror=True)
    # the white oval behind the eye: a raised patch, and a smaller, thinner one behind it that narrows
    patch = (5.4, 5.8, 0.25, 1.85)
    head.block(-26.6, patch, -23.5, patch, "white", mirror=True)
    head.block(-23.8, (5.4, 5.65, 0.45, 1.65), -22.4, (5.4, 5.65, 0.75, 1.35), "white", mirror=True)

    segs, last = {}, HEAD[-1]
    for i, (name, slices) in enumerate(BODY):
        seg = m.part(name, (slices[0][0], 0, 0), "Head" if i == 0 else BODY[i - 1][0])
        segs[name] = seg
        for s in slices:
            slab(seg, *s)
        # a sleeve into the piece in front, so a bending joint shows body: sized from the smaller of the two pieces and
        # kept clear of both pieces' corner steps
        x0, _, n, bot, top, _ = slices[0]
        _, _, pn, pbot, ptop, _ = last
        reach = max(tall(n), tall(pn))
        seg.sym(x0 - 1, x0, max(min(n, pn) - 2, 0), max(bot, pbot) + reach, min(top, ptop) - reach, "back-")
        last = slices[-1]

    # the seat: in front of the fin, a shallow slot either side for the rider's legs
    segs["S3"].dent(-13, -11, 6, 0, 3, "back-")

    # the dorsal fin: the orca's mark. Three boxes leaning back a little, each smaller and thinner than the last and
    # starting inside it. Their back edges are almost in one line and the front steps back, so it reads as one tall
    # triangle; the first starts deep in the back
    segs["S4"].beam((-6.57, 0, 4.86), (-5.68, 0, 11.20), 6.6, 1.7, "back")
    segs["S4"].beam((-5.02, 0, 10.09), (-4.30, 0, 15.24), 4.5, 1.15, "back")
    segs["S4"].beam((-3.77, 0, 14.36), (-3.24, 0, 18.12), 2.7, 0.6, "back-")

    # the saddle: a pale band over the back just behind the fin, raised a little; it stops at the top of the flank
    segs["T1"].band(-2.5, 1.5, 6, -6, 6, "saddle", steps(6), steps(6), stop=3)

    # the flippers, each on its own joint: a root that goes out and back, a broad paddle, a thin round end
    for name, side in (("FlipperR", 1), ("FlipperL", -1)):
        part = m.part(name, (-19.2, 6.2 * side, -4.0), "S1")
        for (ax, ay, az), (bx, by, bz), wide, thick, colour in (((-20.0, 3.8, -3.4), (-17.6, 8.4, -4.9), 4.0, 1.3, "back"),
                                                                ((-18.3, 7.4, -4.6), (-14.2, 11.6, -6.0), 5.0, 0.9, "back"),
                                                                ((-15.2, 10.6, -5.7), (-13.0, 12.8, -6.4), 3.4, 0.5, "back-")):
            part.beam((ax, side * ay, az), (bx, side * by, bz), wide, thick, colour, flat="z")

    # the tail: a short stock taller than it is wide, then the flat fluke on a joint of its own: a hub and two lobes
    # swept back, each ending in a darker tip, with a notch between them
    tail = m.part("Tail", (24, 0, 0), "T6")
    tail.beam((23.5, 0, 0), (25.8, 0, 0), 2.8, 3.8, "back", flat="z")
    fluke = m.part("Fluke", (25.2, 0, 0), "Tail")
    fluke.beam((24.8, 0, 0), (28.6, 0, 0), 7.2, 1.9, "back", flat="z")
    fluke.beam((26.8, 2.2, 0), (30.4, 7.0, 0), 4.0, 1.0, "back", flat="z", mirror=True)
    fluke.beam((29.5, 5.8, 0), (31.3, 8.2, 0), 2.8, 0.5, "back-", flat="z", mirror=True)
