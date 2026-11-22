"""Star Chart, Cosmic (docs/design/cosmic.md, concept 3): a sea serpent with no body. What swims is a constellation:
bright stars at its joints and round its outline, joined by thin lines of light, and inside the figure only a dark mist
where the flesh would be, in clouds with open sea round them. The body plan and the side-to-side swim are the Storm
Serpent's (art/creatures/StormSerpent, not changed), with a longer neck that rears up.
- The figure: a line of stars down the spine and another down the keel, a star at every joint, so the outline of the
  creature IS the constellation. The lines stand clear of the mist, with sea between, as lines drawn between stars do.
  They stretch and break at the joints as it swims.
- The mist: deep indigo clouds inside the figure, a lighter row along their tops, faint specks of far stars in them. One
  cloud to a joint, rounded at its ends, open sea between them.
- The neck rears up ahead of the rider, so the riding camera sees the figure rising: a crest of rays from each neck star
  up to a fin line, the head high with its jaw open (the mouth a gap between two lines of stars), a white crown star
  with the cold light in it, two big pale blue eye stars either side of it.
- Fins drawn as fans: a pair of side fins spreading wide just ahead of the seat, a small fin on the back behind it, and
  a forked tail fin of stars with no mist at all, loose stars drifting off behind it (the Dust part, turning once a swim).
- The seat: a plate of mist on the shoulders between two stars, a gold one in front (the only gold star: the rider's
  own) and a white one behind.
Coordinates in cubes: head toward -x, up +z. Stars and lines glow; the mist does not."""
import math

NAME, ZONE, RARITY = "Star Chart", "UNPLACED", "COSMIC"
U = 0.45
PALETTE = {"mist": "#20275F", "mist2": "#2E3586", "speck": "#7C93E6", "star": "#D2E3FF", "blue": "#86B6FF",
           "gold": "#FFD15C", "line": "#7DB3FF"}
GLOW = {"star": 1.0, "blue": 0.9, "gold": 1.0, "line": 0.6, "speck": 0.35}
KEEP = ["star", "blue", "gold", "line", "speck"]
SEAT = (-19.5, 5, 4)
FRAME, ORTHO, ORTHO_SWIM = 3.4, 60.0, 66.0
FLOATING = ["Dust"]

# the body: S1 to S17, each from x0 to the next; a star at every joint, in the column just in front of it
X0 = (-38, -34, -30, -26, -22, -16, -11, -6, -1, 4, 9, 13, 17, 21, 25, 29, 33)
END = 36
SEAT_SLICE = 4  # S5: the plate the rider sits on, between the gold star (its joint) and the white one (the next)
# the rows of the spine's stars and of the keel's stars at each joint (their cube's z), then at the tail's root
SPINE = (19, 16, 12, 8, 5, 5, 5, 4, 4, 5, 5, 6, 6, 6, 7, 7, 7, 8)
KEEL = (13, 10, 6, 2, -1, -2, -2, -3, -3, -2, -2, -1, 0, 1, 2, 3, 4, 5)
WIDE = (3, 3, 3, 3, 4, 4, 4, 4, 4, 4, 3, 3, 3, 3, 2, 2, 2)  # the mist's half width, in cubes either side of the middle
SOLID = {4, 5}  # joints where the mist does not part: either end of the seat
BIG = {0, 1, 2, 3, 4, 5, 8, 11, 14}  # joints whose spine star is a big four-pointed one
INSET = 0  # how many cubes the mist stays inside the figure's lines, beyond their own width (the head: 0)
CHAIN = ["Head"] + [f"S{i + 1}" for i in range(len(X0))] + ["Tail"]
AMPLITUDES = [1, 1, 1.5, 2, 2, 3, 3.5, 4, 4.5, 5, 5.5, 6, 6.5, 7, 7.5, 8, 8.5, 12]
LINE_W, LINE_T = 0.55, 0.4  # a line's width and thickness, in cubes
IN = 0.35  # how far a line reaches into the cube of a star it ends at, short of its middle
MODEL = []


def pose(parts, phase):
    """a sea snake's swim, from the Storm Serpent: a wave runs down the chain from side to side, smallest in the raised
    neck and under the rider, widest at the tail; the head turns a little against it. The loose stars behind the tail
    turn once a swim round its line (whole turns: the game blends the last key back to the first)"""
    parts["Head"].rotation_euler.z = math.radians(2) * math.sin(phase + math.pi)
    for k, name in enumerate(CHAIN[1:]):
        parts[name].rotation_euler.z = math.radians(AMPLITUDES[k]) * math.sin(phase - 0.5 * (k + 1))
    parts["Dust"].rotation_euler.x = phase


def interp(points, x):
    """a polyline (x, z) sorted by x, read at x (held flat past its ends)"""
    if x <= points[0][0]:
        return points[0][1]
    for (xa, za), (xb, zb) in zip(points, points[1:]):
        if x <= xb:
            return za + (zb - za) * (x - xa) / (xb - xa)
    return points[-1][1]


def below(points, i, inset):
    """the top of the mist (exclusive) in column i under a line through these points: half the line's width, stretched
    by its slope, a margin, and the inset"""
    za, zb = interp(points, i), interp(points, i + 1)
    clear = (LINE_W / 2) * math.sqrt(1 + (zb - za) ** 2) + 0.12
    return math.floor(min(za, zb) - clear) - inset


def above(points, i, inset):
    """the bottom of the mist in column i over a line through these points"""
    za, zb = interp(points, i), interp(points, i + 1)
    clear = (LINE_W / 2) * math.sqrt(1 + (zb - za) ** 2) + 0.12
    return math.ceil(max(za, zb) + clear) + inset


def star(p, i, j, k, size, colour, plane="xz"):
    """a star round cube (i, j, k): size 0 one cube, 1 a plus of seven cubes, 2 a four-pointed star (arms two cubes long
    in `plane`, one cube across it). An arm never goes into another part's cubes (they would lie face on face)"""
    cells = [(0, 0, 0)]
    if size >= 1:
        cells += [(1, 0, 0), (-1, 0, 0), (0, 1, 0), (0, -1, 0), (0, 0, 1), (0, 0, -1)]
    if size >= 2:
        cells += [(2, 0, 0), (-2, 0, 0), (0, 0, 2), (0, 0, -2)] if plane == "xz" else [(0, 2, 0), (0, -2, 0), (0, 0, 2), (0, 0, -2)]
    for a, b, c in cells:
        cell = (i + a, j + b, k + c)
        if (a or b or c) and any(cell in other.cells for other in MODEL[0].parts.values() if other is not p):
            continue
        p.cells[cell] = colour


def star_pair(p, i, j, k, size, colour, plane="xz"):
    star(p, i, j, k, size, colour, plane)
    star(p, i, -j, k, size, colour, plane)


def line(p, a, b, mirror=False):
    """a thin line of light from the middle of star cube a to the middle of star cube b, each end reaching IN short of
    the middle, so both ends are buried in the stars and the line shows only between them"""
    pa = (a[0] + 0.5, a[1], a[2] + 0.5)
    pb = (b[0] + 0.5, b[1], b[2] + 0.5)
    d = [v - u for u, v in zip(pa, pb)]
    length = math.sqrt(sum(v * v for v in d))
    u = [v / length for v in d]
    p0 = tuple(c + IN * w for c, w in zip(pa, u))
    p1 = tuple(c - IN * w for c, w in zip(pb, u))
    p.beam(p0, p1, LINE_W, LINE_T, "line", flat="z" if abs(u[1]) > 0.7 else "y", mirror=mirror)


def mist_column(p, i, top, bottom, n):
    """one column of mist from z bottom to top - 1, n out either side, its corners stepped in where it is big enough,
    faint specks of far stars on its surface"""
    if top <= bottom or n < 0:
        return
    p.sym(i, i + 1, n, bottom, top, "mist")
    if n >= 2 and top - bottom >= 3:
        p.carve_pair(i, i + 1, n, n + 1, top - 1, top)
        p.carve_pair(i, i + 1, n, n + 1, bottom, bottom + 1)
    for (a, b, c) in list(p.cells):
        if a == i and p.cells[(a, b, c)] in ("mist", "mist2"):
            h = (a * 73856093) ^ ((b + 7) * 19349663) ^ ((c + 11) * 83492791)
            if h % 29 == 0 and abs(b) >= n - 1:
                p.cells[(a, b, c)] = "speck"


def build(m):
    MODEL[:] = [m]
    spine = [(x - 0.5, k + 0.5) for x, k in zip(X0, SPINE)] + [(END - 0.5, SPINE[-1] + 0.5)]
    keel = [(x - 0.5, k + 0.5) for x, k in zip(X0, KEEL)] + [(END - 0.5, KEEL[-1] + 0.5)]

    # ---- the head, carried high: an upper jaw and a lower one with the open mouth between them, each edged in stars
    head = m.part("Head", (X0[0], 0, SPINE[0]), None)
    crown, brow, nose = (-42, 0, 21), (-47, 0, 20), (-54, 0, 17)
    corner, chin, throat = (-45, 0, 15), (-52, 0, 13), (-42, 0, 11)

    def mid(c):
        return (c[0] + 0.5, c[2] + 0.5)

    top = [mid(nose), mid(brow), mid(crown), spine[0]]
    upper_lip = [mid(nose), (corner[0] + 0.5, corner[2] + 1.5)]
    lower_lip = [mid(chin), mid(corner)]
    under = [mid(chin), mid(throat), keel[0]]
    for i in range(nose[0] + 1, X0[0] - 1):
        n = 3 if i >= -50 else 2
        t = below(top, i, 0)
        if i < corner[0]:  # in front of the mouth's corner: the upper jaw above the mouth, the lower one below it
            mist_column(head, i, t, above(upper_lip, i, 0), n)
            if i > chin[0]:
                mist_column(head, i, below(lower_lip, i, 0), above(under, i, 0), n - 1)
        else:
            mist_column(head, i, t, above(under, i, 0), n)
    star(head, *crown, 2, "star")  # the crown: the brightest star, with the cold light in it
    star(head, *brow, 1, "blue")
    star(head, *nose, 2, "star")
    star(head, *corner, 1, "blue")
    star(head, *chin, 1, "blue")
    star(head, *throat, 1, "blue")
    star_pair(head, -46, 4, 18, 2, "blue")  # the eyes, on the flanks of the skull
    line(head, crown, brow)
    line(head, brow, nose)
    line(head, (nose[0], 0, nose[2] - 1), (corner[0], 0, corner[2] + 1))  # the upper lip
    line(head, chin, corner)
    line(head, (chin[0], 0, chin[2] - 1), throat)
    crest_tip = (-39, 0, 25)  # the crest begins on the crown
    star(head, *crest_tip, 1, "star")
    line(head, (crown[0], 0, crown[2] + 2), (crest_tip[0], 0, crest_tip[2] - 1))

    # ---- the body: seventeen slices on joints, each a cloud of mist inside the figure, its joint's stars in front of it
    parts = []
    for s, x0 in enumerate(X0):
        x1 = X0[s + 1] if s + 1 < len(X0) else END
        p = m.part(f"S{s + 1}", (x0, 0, 0), "Head" if s == 0 else f"S{s}")
        parts.append(p)
        gap_before, gap_after = s not in SOLID, (s + 1) not in SOLID
        cols = list(range(x0, x1 - 1 if gap_after else x1))
        for i in cols:
            t, b, n = below(spine, i, INSET), above(keel, i, INSET), WIDE[s]
            if s == SEAT_SLICE:  # the seat: a level plate up to the stars either side of it
                t = SPINE[SEAT_SLICE]
            elif (i == cols[0] and gap_before) or (i == cols[-1] and gap_after):  # a cloud's rounded end
                t, b, n = t - 1, b + 1, n - 1
            mist_column(p, i, t, b, n)
        sx = x0 - 1
        if s == SEAT_SLICE:
            star(p, sx, 0, SPINE[s], 2, "gold")  # the rider's star, in front of the seat
        else:
            star(p, sx, 0, SPINE[s], 2 if s in BIG else 1, "star")
        star(p, sx, 0, KEEL[s], 1 if s in (2, 6, 10, 14) else 0, "blue")
    tail = m.part("Tail", (END, 0, SPINE[-1]), f"S{len(X0)}")
    star(tail, END - 1, 0, SPINE[-1], 1, "star")
    star(tail, END - 1, 0, KEEL[-1], 0, "blue")
    # the lines along the spine and the keel, each in the slice it runs over; none along the seat itself
    for s, p in enumerate(parts):
        a, b = X0[s] - 1, (X0[s + 1] if s + 1 < len(X0) else END) - 1
        if s != SEAT_SLICE:
            line(p, (a, 0, SPINE[s]), (b, 0, SPINE[s + 1]))
        line(p, (a, 0, KEEL[s]), (b, 0, KEEL[s + 1]))
    line(head, crown, (X0[0] - 1, 0, SPINE[0]))
    line(head, throat, (X0[0] - 1, 0, KEEL[0]))

    def joined(p, a, b):  # fin tip to fin tip: out of a's back point, into b's front point
        line(p, (a[0] + 1, 0, a[2]), (b[0] - 1, 0, b[2]))

    # ---- the crest on the raised neck: a ray up and back from each neck star's top point, the tips joined in a line
    # that runs from the crown's ray down to the gold star in front of the seat
    tips = [crest_tip]
    for s in range(4):
        sx, k = X0[s] - 1, SPINE[s]
        tip = (sx + 4, 0, k + 4)
        star(parts[s], *tip, 1, "blue" if s % 2 else "star")
        line(parts[s], (sx, 0, k + 2), (tip[0], 0, tip[2] - 1))
        tips.append(tip)
    joined(head, tips[0], tips[1])
    for s in range(1, 4):
        joined(parts[s], tips[s], tips[s + 1])
    line(parts[3], (tips[4][0] + 1, 0, tips[4][2]), (X0[SEAT_SLICE] - 1, 0, SPINE[SEAT_SLICE] + 2))

    # ---- a line of small stars down each flank, from the seat to the tail's start, so the figure has width as well
    flank = []
    for s in range(SEAT_SLICE, 14):
        y = max(WIDE[s - 1], WIDE[s]) + 1
        z = (SPINE[s] + KEEL[s]) // 2
        star_pair(parts[s], X0[s] - 1, y, z, 1 if s in (SEAT_SLICE, 10) else 0, "blue" if s % 2 else "star")
        flank.append((s, (X0[s] - 1, y, z)))
    for (s, a), (_, b) in zip(flank, flank[1:]):
        line(parts[s], a, b, mirror=True)

    # ---- the side fins, just ahead of the seat: from a star on each flank, a fan of two rays and an edge of three stars
    fin = parts[3]
    root = (-25, 4, 4)
    fa, fb, fc = (-24, 11, 3), (-21, 11, 1), (-18, 8, 0)
    star_pair(fin, *root, 1, "star")
    star_pair(fin, *fa, 1, "blue")
    star_pair(fin, *fb, 0, "star")
    star_pair(fin, *fc, 1, "blue")
    line(fin, (root[0], root[1] + 1, root[2]), fa, mirror=True)
    line(fin, (root[0] + 1, root[1], root[2]), fc, mirror=True)
    line(fin, fa, fb, mirror=True)
    line(fin, fb, fc, mirror=True)

    # ---- a small fin on the back behind the seat: rays from three spine stars, the tips joined, down to a fourth
    rear = []
    for s in (9, 10, 11):
        sx, k = X0[s] - 1, SPINE[s]
        tip = (sx + 2, 0, k + 6 - (s - 9))
        star(parts[s], *tip, 1, "star" if s == 10 else "blue")
        line(parts[s], (sx, 0, k + 2 if s in BIG else k + 1), (tip[0], 0, tip[2] - 1))
        rear.append((s, tip))
    for (s, a), (_, b) in zip(rear, rear[1:]):
        joined(parts[s], a, b)
    line(parts[11], (rear[-1][1][0] + 1, 0, rear[-1][1][2]), (X0[12] - 1, 0, SPINE[12] + 1))

    # ---- the tail fin: no mist, only stars. A forked outline from the spine's last star round to the keel's
    d, k = (END - 1, 0, SPINE[-1]), (END - 1, 0, KEEL[-1])
    u1, u2, notch, l1, l2 = (40, 0, 13), (47, 0, 16), (43, 0, 9), (47, 0, 1), (41, 0, 2)
    star(tail, *u1, 1, "blue")
    star(tail, *u2, 2, "star")
    star(tail, *notch, 0, "blue")
    star(tail, *l1, 2, "star")
    star(tail, *l2, 1, "blue")
    line(tail, (d[0], 0, d[2] + 1), u1)
    line(tail, u1, (u2[0] - 2, 0, u2[2]))
    line(tail, (u2[0], 0, u2[2] - 2), notch)
    line(tail, notch, (l1[0], 0, l1[2] + 2))
    line(tail, (l1[0] - 2, 0, l1[2]), l2)
    line(tail, l2, k)

    # ---- loose stars drifting off behind the tail, turning round its line once a swim
    dust = m.part("Dust", (END, 0, SPINE[-1]), "Tail")
    for n, (x, y, z, size) in enumerate(((51, 0, 18, 1), (53, 2, 12, 0), (50, -2, 6, 0), (52, 0, -1, 1), (56, 0, 9, 0),
                                         (55, -1, 15, 0), (49, 2, 21, 0), (58, 1, 4, 0))):
        star(dust, x, y, z, size, "star" if n % 2 == 0 else "blue")


LIGHTS = [("Head", (-41.5, 0, 21.5), "#DCE8FF", 150, 0.8)]  # the crown star's cold light
