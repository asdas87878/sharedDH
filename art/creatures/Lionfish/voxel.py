"""The Lionfish (zone 2's Uncommon) for tools/blender/voxel_kit.py (docs/style/04-voxel-style.md).
Its idea: a small striped fish dressed as a threat. Thin cream stripes ring a red-brown body from lips to tail, a row of
long separate spines stands on its back, and two wide fans of fin open at its sides.
- The body is deep and narrow, as the real fish is: five cubes wide, nine tall. A big head (a third of the fish), a back
  that arches behind it, a belly that rises to a short tail stock.
- The stripes are one cube column in three, painted right round every slice, so they run on from piece to piece. The
  forehead block carries one more as a thin raised ring.
- The dorsal spines are thin tall boxes with cream tips, each on its own, taller towards the middle. There is a gap in
  the row where the rider sits.
- Each pectoral fin is its own part on a shoulder joint: a short arm and three blades spread like a fan, each thinner
  than the last, each with a thin cream ray down it that runs on past the tip.
- A small fleshy tab stands over each eye.
The rider sits in the gap in the spines, legs in a shallow slot either side."""
import math

NAME, ZONE, RARITY = "Lionfish", "ZONE 2 / CORAL REEF", "UNCOMMON"
U = 0.4
PALETTE = {"rust": "#A2452F", "cream": "#F3E6C8", "black": "#231F1E", "mouth": "#57211F"}
SEAT = (-2, 5, 2.5)
TEXTURES = [{"tile": "stud", "on": "top", "colours": ["rust"]}]
FRAME = 1.1

PEC = (-4.0, 2.0, -1.6)  # the shoulder: the pectoral fins' joint, just inside the body's side
DROOP = 30  # degrees the fans slope down, away from the body


def pose(parts, phase):
    """a fish's swim, gently: the wave runs down the body side to side and the tail ends it; the two fans beat slowly"""
    parts["Head"].rotation_euler.z = math.radians(2) * math.sin(phase + math.pi)
    for k, (name, amp) in enumerate((("S1", 3), ("S2", 6), ("S3", 9), ("Tail", 16))):
        parts[name].rotation_euler.z = math.radians(amp) * math.sin(phase - 0.9 * (k + 1))
    for name, side in (("PecR", 1), ("PecL", -1)):
        parts[name].rotation_euler.x = side * math.radians(9) * math.sin(phase - 0.6)


def slab(p, x0, x1, n, bot, top, steps=True):
    """a slice of body: red-brown, its corners stepped once, with every third cube column cream right round it"""
    s = [(1, 1)] if steps else []
    p.hull(x0, x1, n, bot, top, "rust", s, s)
    for x in range(x0, x1):
        if x % 3 == 2:
            p.paint_sym(x, x + 1, n, bot, top, "cream")


def spine(p, x, top, tall, lean):
    """a dorsal spine: a thin tall box, its foot sunk in the back, and a thinner cream tip that starts inside it"""
    foot, tip = (x, 0.0, top - 0.8), (x + lean, 0.0, top + tall)

    def at(f):
        return tuple(a + (b - a) * f for a, b in zip(foot, tip))

    p.beam(at(0.0), at(0.62), 0.7, 0.6, "rust")
    p.beam(at(0.5), at(1.0), 0.4, 0.3, "cream")


def fan(p, side):
    """a pectoral fin: a short arm out of the shoulder and three blades spread from it in one sloping plane, each
    thinner than the last, each with a thin cream ray that runs on past its tip"""
    d = math.radians(DROOP)
    out, back, up = (0.0, side * math.cos(d), -math.sin(d)), (1.0, 0.0, 0.0), (0.0, side * math.sin(d), math.cos(d))
    origin = (PEC[0], side * PEC[1], PEC[2])

    def bar(angle, r0, r1, wide, thick, colour):
        t = math.radians(angle)
        along = tuple(math.cos(t) * a + math.sin(t) * b for a, b in zip(out, back))
        across = tuple(-math.sin(t) * a + math.cos(t) * b for a, b in zip(out, back))
        centre = tuple(o + (r0 + r1) / 2 * a for o, a in zip(origin, along))
        p._oriented(centre, along, across, up, (r1 - r0, wide, thick), colour, False)

    bar(38, -1.3, 2.6, 3.0, 1.6, "rust-")
    for angle, length, wide, thick in ((12, 7.0, 2.6, 0.9), (38, 8.0, 2.6, 0.6), (64, 7.0, 2.4, 0.3)):
        bar(angle, 0.3, length, wide, thick, "rust")
        bar(angle, 1.4, length + 1.2, 0.5, 1.2, "cream")  # the rays start inside the arm, where they are clear of each other


def build(m):
    head = m.part("Head", (-6, 0, 0))
    slab(head, -10, -6, 2, -4, 4)
    head.sym(-10, -8, 2, -4, -3, "rust")  # the throat: the bottom row is full width here, so the jaw's root is buried
    # the face: a big forehead block tilted nose-down, a smaller snout block that starts inside it, and a pale lower jaw
    a0, a1 = (-8.8, 0.0, 0.3), (-12.3, 0.0, -0.2)
    head.beam(a0, a1, 4.2, 5.4, "rust", flat="z")
    r0, r1 = (tuple(a + (b - a) * f for a, b in zip(a0, a1)) for f in (0.68, 0.86))
    head.beam(r0, r1, 4.6, 5.8, "cream", flat="z")  # one more stripe, as a thin raised ring
    head.beam((-11.3, 0, -0.2), (-14.0, 0, -0.75), 3.6, 2.8, "rust", flat="z")
    head.beam((-9.4, 0, -3.15), (-13.9, 0, -3.05), 3.2, 1.2, "cream", flat="z")
    mouth = (-1.4, 1.4, -2.7, -1.7)
    head.block(-13.5, mouth, -10.8, mouth, "mouth")  # the dark line of the mouth, set in from the lips
    # the eye: a cream ring on the side of the head and a dark pupil standing out of it; a small fleshy tab over it
    ring, pupil = (2.0, 2.8, 0.95, 2.65), (2.6, 3.05, 1.25, 2.35)
    head.block(-10.2, ring, -8.5, ring, "cream", mirror=True)
    head.block(-9.9, pupil, -8.8, pupil, "black", mirror=True)
    head.beam((-9.2, 2.0, 2.6), (-9.6, 2.35, 5.3), 1.0, 0.5, "rust-", mirror=True)
    spine(head, -8.6, 4, 3.0, 0.3)
    spine(head, -7.0, 4, 4.5, 0.4)

    s1 = m.part("S1", (-6, 0, 0), "Head")
    slab(s1, -6, -1, 2, -4, 5)
    s1.sym(-7, -6, 1, -2, 2, "rust-")  # sleeves: one cube into the piece in front, inside its steps
    s1.dent(-3, -1, 2, 1, 4, "rust-")  # the rider's legs
    spine(s1, -5.4, 5, 5.0, 0.5)
    s1.beam((-3.4, 1.2, -3.3), (-1.2, 2.0, -6.0), 1.8, 0.5, "rust-", mirror=True)  # the belly fins

    s2 = m.part("S2", (-1, 0, 0), "S1")
    slab(s2, -1, 3, 2, -3, 5)
    s2.sym(-2, -1, 0, -1, 3, "rust-")  # narrower: the leg slot is cut into the side here
    spine(s2, 0.4, 5, 6.5, 1.2)
    spine(s2, 1.9, 5, 6.5, 1.3)

    s3 = m.part("S3", (3, 0, 0), "S2")
    slab(s3, 3, 6, 2, -3, 4)
    slab(s3, 6, 8, 1, -2, 3)
    s3.sym(2, 3, 1, -1, 2, "rust-")
    spine(s3, 3.4, 4, 6.5, 1.4)
    spine(s3, 4.9, 4, 5.0, 1.4)
    # the soft fins before the tail, above and below: a pale box and a smaller, thinner tip
    s3.beam((6.3, 0, 2.3), (8.3, 0, 5.0), 2.2, 0.6, "cream")
    s3.beam((7.7, 0, 4.2), (9.0, 0, 6.0), 1.5, 0.3, "rust")
    s3.beam((6.3, 0, -1.3), (8.1, 0, -3.8), 2.0, 0.6, "cream")
    s3.beam((7.6, 0, -3.1), (8.7, 0, -4.7), 1.4, 0.3, "rust")

    # the tail, on its own joint: a short stock, a root block, and a rounded pale fin in two boxes with thin rays
    tail = m.part("Tail", (8, 0, 0), "S3")
    slab(tail, 8, 10, 1, -1, 2, steps=False)
    tail.sym(7, 8, 0, 0, 1, "rust-")
    tail.beam((9.2, 0, 0.5), (11.2, 0, 0.5), 2.6, 1.6, "rust")
    tail.beam((10.4, 0, 0.5), (14.0, 0, 0.5), 5.8, 0.9, "cream")
    tail.beam((13.4, 0, 0.5), (15.4, 0, 0.5), 3.8, 0.5, "cream")
    for z0, x1, z1 in ((1.4, 14.7, 3.0), (0.5, 15.9, 0.5), (-0.4, 14.7, -2.0)):  # the rays fan out of the root block
        tail.beam((10.6, 0, z0), (x1, 0, z1), 0.4, 1.2, "rust")

    for name, side in (("PecR", 1), ("PecL", -1)):
        fan(m.part(name, (PEC[0], side * PEC[1], PEC[2]), "S1"), side)
