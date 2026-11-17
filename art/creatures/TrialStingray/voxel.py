"""The Stingray, a trial of docs/style/09-early-remodels.md, for tools/blender/voxel_kit.py. It stands beside the game's
Stingray (art/creatures/Stingray) and replaces nothing. Designed from the real animal, a bluespotted ribbontail ray.
Its idea: the kite. A rounded diamond as wide as it is long, with a hump down its middle and its wingtips turned up.
- The body idea in numbers: the disc is about 28 cubes long and 32 across; from the front it is a shallow W: the middle
  is a hump 3 cubes high (a plateau 7 wide on shoulders 11 wide), the wings thin out from it, and the last quarter of
  each wing is a block turned up. The tail is as long as the disc, thick at the root and thin at the end, in four
  lengths, with a low fin fold along its last third.
- A raised head at the front of the hump. The eyes stand up on top of it, each on its own block one cube high, a black
  pupil in a cream ring looking sideways, with a spiracle dent behind each and a thin level brow ridge joining them.
- Caramel above, cream below: each wing is two plates, and the cream one shows as a thin rim all round the disc's edge
  where the caramel stops short of it.
- The one mark: electric blue spots, each one block (four of 2 by 2 on the hump), fourteen in all, mirrored, and one
  thin blue line down each side of the tail.
The rider sits on the hump's plateau, legs down either side onto the shoulders."""
import math

NAME, ZONE, RARITY = "Stingray (trial)", "ZONE 1 / SHALLOWS", "UNCOMMON"
U = 0.4
PALETTE = {"caramel": "#D08A3E", "cream": "#F4E9D2", "blue": "#2D8CFF", "black": "#14171C", "mouth": "#A9735C"}
SHADE = 0.9
SEAT = (-1, 3, 3.5)
FRAME, ORTHO, ORTHO_SWIM = 1.9, 38.0, 40.0
TEXTURES = [{"tile": "stud", "on": "top", "colours": ["caramel"], "parts": ["Body"]}]  # round studs, on the body only
SIDES = (("R", 1), ("L", -1))
RIM = 0.7  # how far the caramel top stops short of the disc's edge: the width of the cream rim

# the disc in the top view, the right half (x, y). The inner wing from the shoulder out to three quarters of the span,
# then the tip, the block that is turned up. Both bulge a little, so the diamond is rounded
# (the inner wing's root, its last edge, lies wholly inside the body's cubes; its first and seventh edges are hidden too)
INNER = [(-7.8, 4.3), (-11.6, 4.45), (-9.5, 8.5), (-6.0, 12.0), (6.05, 12.0), (8.5, 9.0), (11.1, 4.45), (6.8, 4.3)]
TIP = [(-6.0, 11.6), (-4.5, 13.5), (-1.0, 15.8), (1.5, 16.0), (4.0, 14.5), (5.95, 11.6)]  # the last edge is its root
NOSE = [(-7.6, 5.3), (-11.9, 4.9), (-13.2, 2.9), (-14.1, 1.3), (-14.1, -1.3), (-13.2, -2.9), (-11.9, -4.9), (-7.6, -5.3)]
REAR = [(6.6, 5.3), (11.4, 4.9), (12.6, 3.1), (13.6, 1.4), (13.6, -1.4), (12.6, -3.1), (11.4, -4.9), (6.6, -5.3)]
ENDS = [0.15] + [RIM] * 5 + [0.15, 0.2]  # how far the caramel stops short of each edge of those two (the first and seventh lie under the wings)
# the blue spots on each wing: three and two, staggered
SPOTS = ((-5.8, 7.6), (-0.3, 7.6), (5.2, 7.6), (-3.0, 10.6), (2.5, 10.6))


def pose(parts, phase):
    """the wings rise and fall slowly, the turned-up tips a little after them; the body rides against them; the tail
    trails behind, each length a little later and a little further than the one before"""
    for name, side in SIDES:
        parts["Wing" + name + "1"].rotation_euler.x = side * math.radians(8) * math.sin(phase)
        parts["Wing" + name + "2"].rotation_euler.x = side * math.radians(13) * math.sin(phase - 1.0)
    parts["Body"].rotation_euler.y = math.radians(1.5) * math.sin(phase - 1.2)
    for i, name in enumerate(("Tail1", "Tail2", "Tail3", "Tail4")):
        parts[name].rotation_euler.z = math.radians(4 + 2.5 * i) * math.sin(phase - 0.6 - 0.8 * i)
        parts[name].rotation_euler.y = math.radians(2 + 1.5 * i) * math.sin(phase - 1.4 - 0.8 * i)


def inset(poly, by):
    """a convex outline with each edge moved in by its own distance (edge i runs from corner i to the next)"""
    n = len(poly)
    turn = 1 if sum(poly[i][0] * poly[(i + 1) % n][1] - poly[(i + 1) % n][0] * poly[i][1] for i in range(n)) > 0 else -1
    lines = []
    for i in range(n):
        (x0, y0), (x1, y1) = poly[i], poly[(i + 1) % n]
        dx, dy = x1 - x0, y1 - y0
        length = math.hypot(dx, dy)
        lines.append(((x0 - dy / length * turn * by[i], y0 + dx / length * turn * by[i]), (dx, dy)))
    out = []
    for i in range(n):
        (p, d), (q, e) = lines[i - 1], lines[i]
        t = ((q[0] - p[0]) * e[1] - (q[1] - p[1]) * e[0]) / (d[0] * e[1] - d[1] * e[0])
        out.append((p[0] + t * d[0], p[1] + t * d[1]))
    return out


def slab(part, poly, low, high, colour, side=1):
    """a flat plate with the outline `poly` in the top view, from low(x, y) up to high(x, y): both are planes, so a plate
    can thin toward its edge or be turned up. side -1: the left wing"""
    n = len(poly)
    verts = [(x, side * y, low(x, y)) for x, y in poly] + [(x, side * y, high(x, y)) for x, y in poly]
    faces = [tuple(range(n)), tuple(range(n, 2 * n))] + [(i, (i + 1) % n, n + (i + 1) % n, n + i) for i in range(n)]
    part.solid(verts, faces, colour)


def along(a, b, at0, at1, axis):
    """a height that runs from a where the axis (0: x, 1: y) is at0 to b where it is at1"""
    return lambda x, y: a + (b - a) * ((x, y)[axis] - at0) / (at1 - at0)


def sandwich(part, poly, short, cream_low, cream_top, top):
    """an end of the disc: the cream plate is its whole outline; the caramel plate on it stops short of each edge by
    `short`, RIM on the open edges, so the cream shows as a thin rim all round"""
    slab(part, poly, cream_low, cream_top, "cream")
    slab(part, inset(poly, short), lambda x, y: cream_top(x, y) - 0.05, top, "caramel")


def build(m):
    body = m.part("Body", (0, 0, 0))
    # the belly: a low cream slab under the middle
    body.sym(-11, -8, 2, -1, 0, "cream")
    body.sym(-8, 7, 4, -1, 0, "cream")
    body.sym(7, 10, 2, -1, 0, "cream")
    body.paint(-10, -9, -1, 2, -1, 0, "mouth")  # the mouth: a short line underneath
    # the head in front, then the shoulders the wings go into, then the ridge that narrows in two broad steps to the
    # tail's root
    for x0, x1, n in ((-12, -8, 3), (-8, 7, 5), (7, 10, 3), (10, 14, 2)):
        body.sym(x0, x1, n, 0, 2, "caramel")
    body.sym(-6, 5, 3, 2, 3, "caramel")  # the hump's plateau: where the rider sits

    # the snout and the disc's rear end: plates with the wings' cream rim; the snout thins to its blunt tip
    nose = lambda a, b: along(a, b, -7.6, -14.1, 0)  # noqa: E731
    sandwich(body, NOSE, ENDS, nose(-0.35, -0.25), nose(0.0, 0.0), nose(0.6, 0.4))
    flat = lambda z: (lambda x, y: z)  # noqa: E731
    sandwich(body, REAR, ENDS, flat(-0.35), flat(0.0), flat(0.6))

    # THE FACE. Each eye stands on its own block, one cube high, on top of the head: a cream ring on its outer side with
    # a black pupil in it; a thin level brow ridge joins the two blocks; a spiracle dent behind each
    body.pair(-11, -8, 2, 4, 2, 3, "caramel")
    ring = (3.0, 3.75, 1.2, 3.25)
    body.block(-10.8, ring, -8.2, ring, "cream", mirror=True)
    pupil = (3.6, 4.0, 1.6, 2.95)
    body.block(-10.3, pupil, -8.7, pupil, "black", mirror=True)
    brow = (-1.8, 1.8, 1.8, 2.75)
    body.block(-10.8, brow, -10.1, brow, "caramel")
    body.carve_pair(-8, -7, 2, 4, 1, 2)
    hole = (1.5, 3.5, 0.9, 1.6)
    body.block(-8, hole, -7, hole, "caramel-", mirror=True)

    # THE MARK on the hump: four blue spots of 2 by 2, in front of the rider and behind
    body.paint_pair(-5, -3, 2, 4, 2, 3, "blue")
    body.paint_pair(2, 4, 2, 4, 2, 3, "blue")

    for name, side in SIDES:
        # the wing: it starts inside the shoulder and thins out to three quarters of the span, on its own joint
        one = m.part("Wing" + name + "1", (0, 5.5 * side, 0.4), "Body")
        wing = lambda a, b: along(a, b, 4.45, 12.0, 1)  # noqa: E731
        top = wing(0.8, 0.45)
        slab(one, inset(INNER, [0, 0, 0, 0.2, 0, 0, 0, 0]), wing(-0.55, -0.3), wing(0.25, 0.1), "cream", side)
        slab(one, inset(INNER, [0.3, RIM, RIM, 0, RIM, RIM, 0.3, 0.3]), wing(0.2, 0.05), top, "caramel", side)
        for x, y in SPOTS:  # THE MARK: blue spots, each one block, standing a little proud of the wing
            corners = [(x - 0.5, y - 0.5), (x + 0.5, y - 0.5), (x + 0.5, y + 0.5), (x - 0.5, y + 0.5)]
            slab(one, corners, lambda px, py: top(px, py) - 0.2, lambda px, py: top(px, py) + 0.2, "blue", side)
        # the tip: the last quarter of the wing, one block turned up; it starts inside the wing, on a joint of its own
        two = m.part("Wing" + name + "2", (0, 12.0 * side, 0.1), "Wing" + name + "1")
        tip = lambda a, slope: (lambda x, y: a + slope * (y - 11.6))  # noqa: E731
        slab(two, TIP, tip(-0.22, 0.455), tip(0.08, 0.445), "cream", side)
        slab(two, inset(TIP, [RIM] * 5 + [0.2]), tip(0.03, 0.445), tip(0.4, 0.43), "caramel", side)

    # the tail: as long as the disc, in four lengths, each thinner than the last and starting inside it, each on its own
    # joint. THE MARK's other half: one thin blue line down each side (a thin blue plate through each length)
    lengths = ((12.6, 1.0, 20.0, 0.85, 1.7, 3.8, 0.4), (19.6, 0.85, 27.0, 0.7, 1.4, 2.6, 0.4), (26.6, 0.7, 34.0, 0.55, 1.0, 1.6, 0.3),
               (33.6, 0.55, 43.0, 0.4, 0.6, 0.8, 0.25))
    parent = "Body"
    for i, (x0, z0, x1, z1, tall, wide, line) in enumerate(lengths):
        tail = m.part("Tail%d" % (i + 1), (x0 + 0.4, 0, z0), parent)
        tail.beam((x0, 0, z0), (x1, 0, z1), tall, wide, "caramel")
        start = 13.5 if i == 0 else x0 + 0.2  # the line starts inside the piece in front and stops short of the next
        dz = (z1 - z0) / (x1 - x0)
        tail.beam((start, 0, z0 + dz * (start - x0)), (x1 - 0.25, 0, z1 - dz * 0.25), line, wide + 0.3, "blue")
        parent = "Tail%d" % (i + 1)
    # the fin fold: a low leaf along the tail's last third, above and below it
    tail.prism([(34.4, 0.8), (36.6, 1.5), (41.8, 1.2), (42.8, 0.45), (41.8, -0.4), (36.6, -0.65), (34.4, 0.2)], -0.15, 0.15,
               "caramel")
