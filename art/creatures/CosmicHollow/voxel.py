"""The Hollow, Cosmic, the second design (docs/design/cosmic.md, "The Hollow, Cosmic"): the whale that harbors a
black hole. The hole itself is not in this mesh: it is the live one (src/client/Lib/BlackHole.luau), whose light bends
by where the camera stands. It floats over a CRATER torn in the back ahead of the rider, its lower jet running into the
crater's white-hot floor, and the creature is built round it:
- the crater: a bowl in the back, white-hot at the bottom, ember and raw magenta up its walls, a swollen rim round it;
- the cradle: eight bone ribs rising from the rim, leaning out then curling in at the tips like fingers holding a star;
  tall at the front and sides, low at the back so the rider looks into the bowl;
- the pull: chunks of hide torn loose and orbiting over the crater (the Drift part turns once a swim);
- the eyes: two small black holes, a void pupil in an ember ring;
- the hide: indigo over violet with a lavender belly, constellations on the flanks and the head (white stars, pale blue
  lines), a hot seam on the spine from under the rider into the crater, the fluke's tips dissolving into stars.
The riding camera (17 studs back, 12 degrees down) sees only a few studs of back behind the rider, so all of this is
ahead of the seat. The body is the Hollow's (art/creatures/TrialHollow) with a longer chest."""
import math

NAME, ZONE, RARITY = "The Hollow", "UNPLACED", "COSMIC"
U = 0.5
PALETTE = {"slate": "#3A3FA8", "pale": "#DCD3F7", "iron": "#1E1B4B", "dark": "#10141F", "void": "#040409",
           "bone": "#EFE7D3", "ember": "#FF7A2E", "core": "#FFE6B0", "heat": "#D2365E", "flesh": "#7A1E4A",
           "star": "#F6F3FF", "starline": "#8FBFFF", "dusk": "#6B4FD0"}
SEAT = (0, 12, 1.6)
GLOW = {"ember": 0.85, "core": 1.0, "heat": 0.45, "star": 1.0, "starline": 0.55}
KEEP = ["void", "star", "starline", "ember", "core", "heat", "flesh", "bone"]
LIGHTS = [("Chest", (-13.0, 0, 10.0), "#FF9A50", 160, 1.2)]  # the crater lights the ribs
FRAME, ORTHO, ORTHO_SWIM = 3.7, 52.0, 58.0
TEXTURES = [{"tile": "stud", "on": "top", "colours": ["slate"]}]
# the lower flank shades from indigo to violet in flat steps
PAINT = [{"on": {"colours": ["slate", "slate+", "slate-"], "height": [0.12, 0.32]}, "to": {"hex": "#6B4FD0"}},
         {"on": {"colours": ["slate", "slate+", "slate-"], "height": [0.32, 0.5]}, "to": {"hex": "#5247BE"}}]

LINE = 7  # the pale line along the flank
SKULL_X, SKULL = (-31, -23), (7, -8, 8)  # cubes out, bottom, top
SHOULDER_X, SHOULDER = (-23, -19), (8, -10, 11)
CAGE_X, CAGE = (-19, 14), (9, -12, 12)  # a long chest: the crater ahead, the rider behind it
CRATER, RIM = (-13, 6.0), 2.6  # the crater's middle along the body and its radius; the swollen rim's width, in cubes
# the ribs: (degrees round from straight ahead, height in cubes above the back, how far out they lean); each has a twin
RIBS = ((18, 11.0, 1.6), (60, 10.0, 1.6), (105, 8.0, 1.5), (148, 6.0, 0.8))
TAIL = ((5, 8, -10, 11), (6, 7, -8, 9), (5, 6, -6, 8), (4, 5, -5, 7), (4, 4, -4, 6), (3, 3, -3, 5), (3, 2, -2, 4))
CHAIN = ["Chest"] + [f"T{i + 1}" for i in range(len(TAIL))] + ["Fluke"]
AMPLITUDES = [1.5, 2.5, 3.5, 4.5, 5.5, 6.5, 7.5, 8.5, 13]
FLOATING = ["Drift", "Dust"]
# constellations, as (along, up) on the chest's flank and (along, across) on the top of the head
FLANK_STARS = ((-16, 3), (-11, 6), (-6, 4), (-1, 7), (5, 5), (10, 2))
HEAD_STARS = ((-30, -3), (-27, 2), (-24, -2), (-21, 3))


def pose(parts, phase):
    """a whale's swim: a slow wave runs down the body up and down and ends in the fluke; the flippers row a little;
    the torn hide orbits the crater once a swim (whole turns: the game blends the last key back to the first)"""
    parts["Head"].rotation_euler.y = math.radians(1.5) * math.sin(phase + math.pi)
    for k, name in enumerate(CHAIN):
        parts[name].rotation_euler.y = math.radians(AMPLITUDES[k]) * math.sin(phase - 0.5 * (k + 1))
    for name, side in (("FlipperR", 1), ("FlipperL", -1)):
        parts[name].rotation_euler.x = side * math.radians(10) * math.sin(phase - 0.8)
        parts[name].rotation_euler.z = side * math.radians(5) * math.sin(phase - 1.8)
    parts["Drift"].rotation_euler.z = phase


def column_top(p, i, j):
    ks = [k for (a, b, k) in p.cells if a == i and b == j]
    return max(ks) if ks else None


def stamp_top(p, i, j, colour):
    """colour the top cube of a column (whatever has been built or carved there)"""
    k = column_top(p, i, j)
    if k is not None:
        p.cells[(i, j, k)] = colour


def stamp_side(p, i, k, colour):
    """colour the outermost cube of a row, on both flanks"""
    js = [b for (a, b, c) in p.cells if a == i and c == k]
    if js:
        p.cells[(i, max(js), k)] = colour
        p.cells[(i, min(js), k)] = colour


def line(a, b):
    """the cubes on a straight line between two cells (both ends left out)"""
    (x0, y0), (x1, y1) = a, b
    n = max(abs(x1 - x0), abs(y1 - y0))
    return [(round(x0 + (x1 - x0) * t / n), round(y0 + (y1 - y0) * t / n)) for t in range(1, n)]


def constellation(points, put):
    for a, b in zip(points, points[1:]):
        for c in line(a, b):
            put(c, "starline")
    for x, y in points:  # each star a plus: it twinkles at a distance where one cube is lost
        for dx, dy in ((0, 0), (1, 0), (-1, 0), (0, 1), (0, -1)):
            put((x + dx, y + dy), "star")

def top_steps(n):
    """the corners of the back: a plateau, a broad step and a wall where the body is thick, fewer steps as it thins"""
    return [(4, 1), (2, 1), (1, 2)] if n >= 8 else ([(3, 1), (2, 1), (1, 1)] if n >= 6 else ([(2, 1), (1, 1)] if n >= 4 else [(1, 1)]))


def bottom_steps(n):
    return [(4, 1), (2, 1), (1, 1)] if n >= 8 else ([(3, 1), (1, 1)] if n >= 6 else ([(2, 1), (1, 1)] if n >= 4 else [(1, 1)]))


def rows(steps):
    return sum(tall for _, tall in steps)


def slab(p, x0, x1, n, bot, top, belly=None, bottom=None):
    """a slice of body: stepped corners, slate hide, a lighter top row with a dark seam down its middle, the
    pale line along the flank, a paler belly from `belly` down (left out: the stepped rows of the belly)"""
    bottom = bottom_steps(n) if bottom is None else bottom
    p.hull(x0, x1, n, bot, top, "slate", top_steps(n), bottom)
    p.paint_sym(x0, x1, n, top - 1, top, "slate+")
    p.paint_sym(x0, x1, 0, top - 1, top, "iron")
    if top >= LINE + 2:
        p.paint_sym(x0, x1, n, LINE, LINE + 1, "pale")
    p.paint_sym(x0, x1, n, bot, bot + rows(bottom) if belly is None else belly, "pale")
    p.paint_sym(x0, x1, n, bot, bot + 1, "pale-")


def sleeve(p, x0, mine, front, front_bottom=None):
    """a sleeve one cube into the piece in front, sized from the smaller of the two and clear of both pieces' steps"""
    (n, bot, top), (fn, fbot, ftop) = mine, front
    small = min(n, fn)
    up = max(rows(top_steps(n)), rows(top_steps(fn)))
    down = max(rows(bottom_steps(n)), rows(front_bottom if front_bottom is not None else bottom_steps(fn)))
    p.sym(x0 - 1, x0, max(small - 2, 0), max(bot, fbot) + down, min(top, ftop) - up, "slate-")




def build(m):
    # ---- the head: a short skull and two jaws that taper to the front, each three tilted blocks in a chain
    head = m.part("Head", (SKULL_X[1], 0, 0))
    slab(head, *SKULL_X, *SKULL, belly=-1, bottom=[(1, 1)])  # a deep, square throat: the jaw's root is buried in it
    head.paint_sym(-27, SKULL_X[1], 7, -3, -1, "slate")  # the belly's edge steps down toward the chest
    # the upper jaw: narrow, each block tilted nose-down, lower and narrower than the last and starting inside it
    for x0, x1, z0, z1, wide, thick in ((-29.5, -35.5, 3.6, 3.1, 8.6, 7.4), (-34.3, -40.2, 2.8, 2.3, 6.8, 5.0),
                                        (-39.2, -43.8, 2.2, 1.8, 4.8, 3.2)):
        head.beam((x0, 0, z0), (x1, 0, z1), wide, thick, "slate", flat="z")
    # the lower jaw: wider than the upper, pale, its lip standing either side of the upper jaw as a baleen whale's does.
    # Its blocks tilt nose-up, so the mouth's line climbs to the tip, where the lip closes over the upper jaw. A dark
    # plate lies on each lip, set in from its edge: the mouth's line
    jaws = ((-29.5, -36.5, -4.4, -4.0, 12.6, 6.6, -31.3), (-35.3, -41.5, -3.4, -2.4, 9.8, 5.2, -35.6), (-40.5, -44.6, -2.0, -1.2, 6.8, 3.6, -40.6))
    for x0, x1, z0, z1, wide, thick, line_from in jaws:
        head.beam((x0, 0, z0), (x1, 0, z1), wide, thick, "pale", flat="z")
        if line_from:
            def lip(x):
                return z0 + (z1 - z0) * (x - x0) / (x1 - x0) + thick / 2 + 0.2

            head.beam((line_from, 0, lip(line_from)), (x1 + 1.0, 0, lip(x1 + 1.0)), wide - 1.2, 0.8, "dark", flat="z")
    # ---- the eyes: two small black holes, a void pupil in an ember ring, sunk in a dark socket
    head.dent(-30, -26, 7, -2, 2, "dark", depth=0.5)
    ring = (6.75, 7.3, -1.4, 1.6)
    head.block(-29.6, ring, -26.6, ring, "ember", mirror=True)
    pupil = (6.9, 7.42, -0.7, 0.9)
    head.block(-28.9, pupil, -27.3, pupil, "void", mirror=True)
    blow = (0.6, 1.3, 7.8, 8.2)  # the blowholes
    head.block(-27.4, blow, -26.2, blow, "dark", mirror=True)
    constellation(HEAD_STARS, lambda c, col: stamp_top(head, c[0], c[1], col))

    # ---- the chest: one rigid piece, a shoulder and the long back
    chest = m.part("Chest", (SHOULDER_X[0], 0, 0), "Head")
    slab(chest, *SHOULDER_X, *SHOULDER, belly=-5)
    slab(chest, *CAGE_X, *CAGE)
    sleeve(chest, SHOULDER_X[0], SHOULDER, SKULL, [(1, 1)])
    top = CAGE[2]
    # the seat: on the spine's line, a slot either side for the rider's legs
    chest.carve_pair(SEAT[0] - 2, SEAT[0] + 2, 2, 4, top - 3, top)
    chest.paint_pair(SEAT[0] - 2, SEAT[0] + 2, 2, 4, top - 4, top - 3, "slate-")

    # ---- the crater: a swollen rim, then a bowl five cubes deep, hottest at the bottom
    cx, r = CRATER
    mid = cx + 0.5
    reach = int(r + RIM) + 2
    for i in range(cx - reach, cx + reach + 1):
        for j in range(-reach, reach + 1):
            d = math.hypot(i + 0.5 - mid, j)
            if r <= d < r + RIM:  # the rim: two cubes up near the bowl, one further out, filled down to the body
                high = top + 1 if d < r + 1.3 else top
                k = high
                while k >= top - 6 and (i, j, k) not in chest.cells:
                    chest.cells[(i, j, k)] = "dusk" if k == top + 1 or d <= r + 0.9 else "slate"
                    k -= 1
    for i in range(cx - reach, cx + reach + 1):
        for j in range(-reach, reach + 1):
            d = math.hypot(i + 0.5 - mid, j)
            if d < r:
                depth = round(1 + 4 * (1 - (d / r) ** 2))
                floor = top - depth
                for k in range(floor, top + 2):
                    chest.cells.pop((i, j, k), None)
                if (i, j, floor - 1) in chest.cells:
                    chest.cells[(i, j, floor - 1)] = "core" if d < 1.8 else "ember" if d < 3.2 else "heat" if d < 4.6 else "flesh"
    # the hot seam: the spine's line glows from under the rider into the crater
    for i in range(int(cx + r + RIM), CAGE_X[1]):
        stamp_top(chest, i, 0, "ember")
    # constellations on both flanks
    constellation(FLANK_STARS, lambda c, col: stamp_side(chest, c[0], c[1], col))

    # ---- the cradle: eight bone ribs from the rim, out and up, then curling in, an ember tip on each
    for angle, h, lean in RIBS:
        a = math.radians(angle)

        def at(rad, up, a=a):
            return (mid - rad * math.cos(a), rad * math.sin(a), top + up)

        # each block starts 80% of the way along the one below it, so its root is buried in it
        joints = [at(r + 1.1, 0.4), at(r + 1.1 + lean, 0.45 * h), at(r + 0.7 + lean, 0.8 * h), at(r + 0.5, h), at(r - 0.7, h - 0.05)]
        sizes = ((1.6, "bone"), (1.3, "bone"), (1.05, "bone"), (0.75, "ember"))
        start = joints[0]
        for n, (size, colour) in enumerate(sizes):
            end = joints[n + 1]
            chest.beam(start, end, size, size, colour, mirror=True)
            start = tuple(start[q] + 0.8 * (end[q] - start[q]) for q in range(3))

    # ---- the pull: hide torn loose, orbiting over the crater (its own part; it turns once a swim)
    drift = m.part("Drift", (mid, 0, top), "Chest")
    for n, (rad, up, size) in enumerate(((4.2, 3.5, 1.6), (5.0, 5.5, 1.2), (3.4, 7.0, 1.0), (4.6, 2.6, 0.9), (2.8, 5.0, 0.7))):
        a = math.radians(n * 137.5)
        x, y = mid + rad * math.cos(a), rad * math.sin(a)
        tilt = 0.6 * size
        colour = "slate" if n % 2 == 0 else "heat"  # hide, or the raw underside showing
        drift.beam((x - tilt, y, top + up - 0.3), (x + tilt, y + 0.4, top + up + 0.3), size * 1.4, size * 0.6, colour, flat="z")

    # ---- the flippers, each on its own joint: long, three boxes thinning to the tip
    for name, s in (("FlipperR", 1), ("FlipperL", -1)):
        f = m.part(name, (-20.0, 9.5 * s, -7.8), "Chest")  # forward of the hall and under the disc
        f.beam((-20.6, 6.2 * s, -7.6), (-16.6, 12.6 * s, -8.9), 4.8, 1.5, "slate", flat="z")
        f.beam((-17.4, 11.5 * s, -8.65), (-11.0, 15.6 * s, -9.8), 3.9, 1.0, "slate", flat="z")
        f.beam((-12.0, 14.9 * s, -9.6), (-7.4, 17.2 * s, -10.4), 2.7, 0.6, "slate+", flat="z")

    # ---- the tail: slices on joints, each a cube smaller all round, to a tall thin stock
    x, front, parent, segs = CAGE_X[1], CAGE, "Chest", []
    for i, (length, n, bot, top) in enumerate(TAIL):
        seg = m.part(f"T{i + 1}", (x, 0, 0), parent)
        slab(seg, x, x + length, n, bot, top)
        sleeve(seg, x, (n, bot, top), front)
        segs.append((seg, x, x + length, n))
        x, front, parent = x + length, (n, bot, top), f"T{i + 1}"
    end = x
    # a small back fin, far behind the rider: two boxes
    fin, fx, _, _ = segs[2]
    fin.beam((fx + 1.2, 0, 6.8), (fx + 4.0, 0, 9.8), 3.2, 1.3, "slate")
    fin.beam((fx + 3.4, 0, 9.1), (fx + 5.3, 0, 11.2), 2.0, 0.7, "slate+")

    # ---- the fluke, on its own joint: it lies flat. A hub, then each lobe in two boxes that thin and droop
    fluke = m.part("Fluke", (end, 0, 0.5), f"T{len(TAIL)}")
    fluke.beam((end - 1.0, 0, 0.5), (end + 5.5, 0, 0.5), 4.6, 2.2, "slate", flat="z")
    fluke.beam((end + 2.6, 0.3, 0.5), (end + 6.0, 8.5, 0.2), 5.0, 1.4, "slate", flat="z", mirror=True)
    fluke.beam((end + 5.2, 6.6, 0.25), (end + 8.6, 11.6, -0.4), 3.6, 0.9, "slate+", flat="z", mirror=True)

    # the fluke's tips dissolve into stars: loose glowing cubes drifting off behind each lobe
    dust = m.part("Dust", (end, 0, 0.5), "Fluke")
    for n, (dx, dy, dz) in enumerate(((9.6, 12.3, 0), (10.8, 13.4, 1), (12.3, 12.8, 0), (11.7, 14.9, -1), (13.9, 14.2, 0), (9.2, 9.6, -1))):
        colour = "star" if n % 2 == 0 else "starline"
        for side in (1, -1):
            dust.cells[(int(end + dx), side * int(dy), int(dz))] = colour
