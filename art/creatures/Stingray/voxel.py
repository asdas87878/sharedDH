"""The Stingray (zone 1's Uncommon) for tools/blender/voxel_kit.py (docs/style/04-voxel-style.md). The small cousin of the
Manta Ray, designed from the real animal: a sand-coloured kite that lies flat.
Its idea: a flat diamond with a whip. Nearly all of it is one wide, thin diamond; the body is only a low rise down its
middle, and the two things that stand out of the flat are small: the eyes on top in front, the barb on the tail behind.
- The body is a low slab nine cubes wide with a narrower back on top and a narrower belly underneath. In front it steps
  in to a short snout that ends in a turned block, the diamond's point; behind the shoulders it narrows a step at a time
  to the root of the tail.
- Each wing is two flat plates in a chain, turned blocks on joints of their own: the leading edge sweeps back to a blunt
  tip, the trailing edge sweeps forward to it, and both bend a little at the joint, so the diamond's sides are full.
- Sandy brown above, pale below. Its one pattern is a thin pale stripe round the wing's edge: each plate is a sandwich,
  and the middle layer shows all round the edge where the sandy top stops short of it.
- The eyes are on top of the head, as a ray's are: each a small bump with a dark pupil in a pale ring, looking sideways.
- A long thin whip of a tail in three lengths, each on its own joint, with a pale barb lying back along the second.
The rider sits on the flat back, legs down either side of it onto the wings' roots."""
import math

NAME, ZONE, RARITY = "Stingray", "ZONE 1 / SHALLOWS", "UNCOMMON"
U = 0.4
PALETTE = {"sand": "#B48E5E", "belly": "#F1E7D0", "stripe": "#F4D9A0", "black": "#1A1614", "mouth": "#6B4636"}
SEAT = (-2, 2, 2.5)
FRAME, ORTHO, ORTHO_SWIM = 1.9, 38.0, 40.0
TEXTURES = [{"tile": "stud", "on": "top", "colours": ["sand"], "parts": ["Body"]}]  # round studs, on the body's middle only
SIDES = (("R", 1), ("L", -1))
RIM = 0.7  # how far the sandy top stops short of the wing's edge: the width of the pale stripe
FACES = [(0, 1, 2, 3), (4, 5, 6, 7), (0, 1, 5, 4), (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7)]


def pose(parts, phase):
    """the wings rise and fall slowly, the outer plate a little after the inner one; the body rides against them; the tail
    trails behind, each length a little later and a little further than the one before"""
    for name, side in SIDES:
        parts["Wing" + name + "1"].rotation_euler.x = side * math.radians(11) * math.sin(phase)
        parts["Wing" + name + "2"].rotation_euler.x = side * math.radians(16) * math.sin(phase - 1.0)
    parts["Body"].rotation_euler.y = math.radians(1.5) * math.sin(phase - 1.2)
    parts["Tail1"].rotation_euler.z = math.radians(5) * math.sin(phase - 0.6)
    parts["Tail2"].rotation_euler.z = math.radians(8) * math.sin(phase - 1.4)
    parts["Tail3"].rotation_euler.z = math.radians(11) * math.sin(phase - 2.2)
    parts["Tail1"].rotation_euler.y = math.radians(3) * math.sin(phase - 1.4)
    parts["Tail2"].rotation_euler.y = math.radians(5) * math.sin(phase - 2.2)
    parts["Tail3"].rotation_euler.y = math.radians(7) * math.sin(phase - 3.0)


def line(a, b):
    """an edge of the wing in the top view: x at y, through two (y, x) points"""
    (ya, xa), (yb, xb) = a, b
    return lambda y: xa + (xb - xa) * (y - ya) / (yb - ya)


def plate(part, side, lead, trail, y0, y1, low, high, colour, inset=0.0):
    """a flat wing plate from y0 out to y1, between the leading and the trailing edge (set in from both by `inset`), from
    its underside to its top. side: 1 right, -1 left"""
    verts = []
    for y in (y0, y1):
        a, b = lead(y) + inset, trail(y) - inset
        verts += [(a, side * y, low), (b, side * y, low), (b, side * y, high), (a, side * y, high)]
    part.solid(verts, FACES, colour)


def wing(part, side, lead, trail, y0, y1, low, mid0, mid1, high, tip=False):
    """a length of wing, a sandwich of three plates: the pale stripe in the middle is the wing's whole outline; the sandy
    top stops short of the edge, so the stripe shows all round it; the pale underside is set in a little too"""
    plate(part, side, lead, trail, y0, y1, mid0, mid1, "stripe")
    plate(part, side, lead, trail, y0 + 0.2, y1 - RIM if tip else y1 + 0.15, mid1 - 0.05, high, "sand", RIM)
    plate(part, side, lead, trail, y0 + 0.4, y1 - (0.3 if tip else 0.15), low, mid0 + 0.05, "belly", 0.3)


def build(m):
    body = m.part("Body", (0, 0, 0))
    # the body: a low slab the wings go into, stepping in to a blunt snout in front and to the tail's root behind; a
    # narrower back on top, running out to a ridge over the tail; a narrower belly underneath
    body.sym(-18, -16, 2, -1, 1, "sand")  # the snout
    body.sym(-16, 4, 4, -1, 1, "sand")
    body.sym(4, 9, 3, -1, 1, "sand")  # behind the shoulders it narrows a step at a time to the tail's root
    body.sym(9, 13, 2, -1, 1, "sand")
    body.sym(13, 15, 1, -1, 1, "sand")
    body.sym(-15, 5, 2, 1, 2, "sand+")  # the back: where the rider sits
    body.sym(5, 10, 1, 1, 2, "sand+")
    body.sym(-14, 5, 2, -2, -1, "belly")
    body.sym(5, 9, 1, -2, -1, "belly")
    body.paint(-18, 15, -4, 5, -1, 0, "belly")  # pale below the wings' line
    body.paint(-14, -13, -1, 2, -2, -1, "mouth")  # the mouth: a short dark line underneath
    # the snout's tip: a turned block that brings the diamond to its point, sandy above and pale below like the rest
    body.taper(-17.5, (2.3, -0.15, 0.8), -19.6, (0.8, -0.15, 0.5), "sand")
    body.taper(-17.5, (2.1, -0.8, -0.1), -19.4, (0.6, -0.5, -0.1), "belly")
    # the eyes, on top of the head: each a small bump at the edge of the back, a dark pupil in a pale ring on its outer side
    bump = (0.8, 2.3, 1.7, 3.3)
    body.block(-14.3, bump, -11.9, bump, "sand", mirror=True)
    ring = (2.15, 2.47, 2.15, 3.1)
    body.block(-14.0, ring, -12.2, ring, "belly", mirror=True)
    pupil = (2.35, 2.72, 2.35, 2.9)
    body.block(-13.6, pupil, -12.5, pupil, "black", mirror=True)

    for name, side in SIDES:
        # the wing: two plates in a chain, each on its own joint. The first starts inside the body; the second starts
        # inside the first, a step shorter and thinner, and ends in a blunt tip
        one = m.part("Wing" + name + "1", (0, 3.5 * side, 0.15), "Body")
        wing(one, side, line((2.2, -17.8), (12.0, -11.0)), line((2.2, 12.8), (12.0, 6.6)), 2.2, 12.0, -0.5, 0.0, 0.45, 0.8)
        two = m.part("Wing" + name + "2", (0, 11.5 * side, 0.15), "Wing" + name + "1")
        wing(two, side, line((11.0, -11.4), (20.0, -3.9)), line((11.0, 6.9), (20.0, -1.5)), 11.0, 20.0, -0.35, 0.15, 0.3, 0.65, tip=True)

    # the tail: a long thin whip in three lengths, each thinner than the last and starting inside it, each on its own joint
    tail = m.part("Tail1", (15, 0, 0), "Body")
    tail.beam((14.5, 0, 0), (23.0, 0, 0), 1.5, 1.3, "sand-")
    tail = m.part("Tail2", (22.6, 0, 0), "Tail1")
    tail.beam((22.2, 0, 0), (31.0, 0, 0), 1.0, 0.85, "sand-")
    # the barb: a pale spine lying back along the tail, its base sunk into it
    tail.spike([(23.8, -0.3, 0.2), (25.8, -0.3, 0.2), (25.8, 0.3, 0.2), (23.8, 0.3, 0.2)], (30.2, 0, 1.5), "stripe")
    tail = m.part("Tail3", (30.6, 0, 0), "Tail2")
    tail.beam((30.2, 0, 0), (39.0, 0, 0), 0.55, 0.45, "sand-")
