"""Heartstar, a Cosmic (docs/design/cosmic.md, concept 20: a ribbed leviathan with a small sun caged in its ribs for a
heart) for tools/blender/voxel_kit.py. Its body is drawn after the Bone Leviathan's plan (art/creatures/BoneLeviathan,
not changed), but it is alive: a whole hide over the bones, and only the ribs break through.
- The set piece, ahead of the rider: five pairs of bone ribs burst out of the back and arch over it like fingers, tall at
  the front and the middle, low at the back so the rider looks in. In the cage hangs the heart: a small sun (a ball of
  yellow with orange spots and white-hot patches, flame tongues standing out of it), on its own joint ("Sun"), turning
  once a swim, and loose flares orbiting it the other way ("Flares"). Under it the back is burnt into a glowing pit.
- The beat: each side of the cage is its own joint (CageR, CageL); the ribs spread a little once a swim, like a chest
  breathing round the heart.
- The light: the heart's glow runs out of the pit along veins: down the flanks, along the tail to the blade, out along
  each flipper. Its eyes are small stars, and the mouth glows from inside.
- The body is the calm part: one deep teal hide, a pale belly, bone bands down the flanks where the ribs lie under the
  skin, a row of small bone spines down the tail.
It swims like a serpent, side to side. The riding camera sees only a few studs of back behind the rider, so the whole
show is ahead of the seat."""
import math

NAME, ZONE, RARITY = "Heartstar", "UNPLACED", "COSMIC"
U = 0.5
PALETTE = {"hide": "#1C5566", "pale": "#CFE2D8", "dark": "#0D1C24", "bone": "#EEE3C6", "vein": "#FFB13A",
           "heat": "#FF6224", "core": "#FFF7DC", "sun": "#FFD545", "flare": "#FF8E2B", "ember": "#C2381E"}
GLOW = {"vein": 0.75, "heat": 0.9, "core": 1.0, "sun": 1.0, "flare": 0.95}
KEEP = ["dark", "bone", "vein", "heat", "core", "sun", "flare", "ember"]
SEAT = (9, 10, 1.6)
FRAME, ORTHO, ORTHO_SWIM = 3.9, 56.0, 62.0
TEXTURES = [{"tile": "stud", "on": "top", "colours": ["hide"]}]
# the lower flank a step lighter, so the hide isn't flat
PAINT = [{"on": {"colours": ["hide", "hide+", "hide-"], "height": [0.14, 0.36]}, "to": {"hex": "#246A79"}}]
FLOATING = ["Sun", "Flares"]

SKULL_X, SKULL = (-27, -20), (6, -6, 7)  # cubes out, bottom, top
SHOULDER_X, SHOULDER = (-20, -15), (7, -8, 9)
CHEST_X, CHEST = (-15, 18), (8, -10, 10)
TOP = CHEST[2]
SUN = (-5.5, 0.0, TOP + 10.5)  # the heart's middle
SUN_R = 4.8
PIT = 4.6  # the burnt pit's radius under the heart
# the cage: (x along the body, height above the back, how far the tip leans along the body)
RIBS = ((-14.5, 15.0, 2.6), (-9.0, 19.5, 1.0), (-3.0, 18.5, -1.2), (2.5, 11.0, -0.6))
TAIL = ((6, 7, -8, 8), (6, 6, -7, 7), (5, 5, -6, 6), (5, 4, -5, 5), (4, 3, -4, 4), (4, 2, -3, 3), (4, 2, -2, 3))
CHAIN = ["Chest"] + [f"T{i + 1}" for i in range(len(TAIL))] + ["Blade"]
AMPLITUDES = [1.5, 2.5, 3.5, 4.5, 5.5, 6.5, 7.5, 8.5, 12]
VEIN = 3  # the main vein's row along the flank


def pose(parts, phase):
    """a serpent's swim, side to side, growing to the tail; the head turns a little against it. Once a swim the heart
    turns, the flares go round it the other way, and the cage spreads and closes (whole turns: the game blends the last
    key back to the first)"""
    parts["Head"].rotation_euler.z = math.radians(2.0) * math.sin(phase + math.pi)
    for k, name in enumerate(CHAIN):
        parts[name].rotation_euler.z = math.radians(AMPLITUDES[k]) * math.sin(phase - 0.5 * (k + 1))
    for name, side in (("FlipperR", 1), ("FlipperL", -1)):
        parts[name].rotation_euler.x = side * math.radians(10) * math.sin(phase - 0.8)
        parts[name].rotation_euler.z = side * math.radians(6) * math.sin(phase - 1.8)
    parts["Sun"].rotation_euler.z = phase
    parts["Flares"].rotation_euler.z = -phase
    spread = math.radians(7) * (0.5 - 0.5 * math.cos(phase))
    parts["CageR"].rotation_euler.x = -spread
    parts["CageL"].rotation_euler.x = spread


def top_steps(n):
    return [(4, 1), (2, 1), (1, 2)] if n >= 8 else ([(3, 1), (2, 1), (1, 1)] if n >= 6 else ([(2, 1), (1, 1)] if n >= 4 else [(1, 1)]))


def bottom_steps(n):
    return [(4, 1), (2, 1), (1, 1)] if n >= 8 else ([(3, 1), (1, 1)] if n >= 6 else ([(2, 1), (1, 1)] if n >= 4 else [(1, 1)]))


def rows(steps):
    return sum(tall for _, tall in steps)


def slab(p, x0, x1, n, bot, top, belly=None, bottom=None):
    """a slice of body: stepped corners, teal hide, a lighter top row, a paler belly"""
    bottom = bottom_steps(n) if bottom is None else bottom
    p.hull(x0, x1, n, bot, top, "hide", top_steps(n), bottom)
    p.paint_sym(x0, x1, n, top - 1, top, "hide+")
    p.paint_sym(x0, x1, n, bot, bot + rows(bottom) if belly is None else belly, "pale")
    p.paint_sym(x0, x1, n, bot, bot + 1, "pale-")


def sleeve(p, x0, mine, front, front_bottom=None):
    (n, bot, top), (fn, fbot, ftop) = mine, front
    small = min(n, fn)
    up = max(rows(top_steps(n)), rows(top_steps(fn)))
    down = max(rows(bottom_steps(n)), rows(front_bottom if front_bottom is not None else bottom_steps(fn)))
    p.sym(x0 - 1, x0, max(small - 2, 0), max(bot, fbot) + down, min(top, ftop) - up, "hide-")


def column_top(p, i, j):
    ks = [k for (a, b, k) in p.cells if a == i and b == j]
    return max(ks) if ks else None


def stamp_top(p, i, j, colour):
    k = column_top(p, i, j)
    if k is not None:
        p.cells[(i, j, k)] = colour


def stamp_side(p, i, k, colour, only=None):
    """colour the outermost cube of a row, on both flanks (only: if it is one of these colours)"""
    js = [b for (a, b, c) in p.cells if a == i and c == k]
    if js:
        for j in (max(js), min(js)):
            if only is None or p.cells[(i, j, k)] in only:
                p.cells[(i, j, k)] = colour


def vein_path(p, points, only=("hide", "hide+", "hide-", "pale")):
    """a glowing vein on both flanks through (x, row) points, a cube wide"""
    for (x0, z0), (x1, z1) in zip(points, points[1:]):
        n = max(abs(x1 - x0), abs(z1 - z0), 1)
        for t in range(n + 1):
            stamp_side(p, round(x0 + (x1 - x0) * t / n), round(z0 + (z1 - z0) * t / n), "vein", only)


def build(m):
    # ---- the head: a long, low skull, the snout and the lower jaw tapering to the front, a hot mouth between them
    head = m.part("Head", (SKULL_X[1], 0, 0))
    slab(head, *SKULL_X, *SKULL, belly=-2, bottom=[(1, 1)])
    for x0, x1, z0, z1, wide, thick in ((-26.5, -32.5, 3.0, 2.5, 9.0, 6.6), (-31.5, -37.0, 2.3, 1.8, 7.0, 4.8),
                                        (-36.2, -40.0, 1.6, 1.2, 5.0, 3.0)):
        head.beam((x0, 0, z0), (x1, 0, z1), wide, thick, "hide", flat="z")
    jaws = ((-26.5, -33.0, -3.4, -3.0, 10.2, 5.0, -27.5), (-32.3, -37.6, -2.7, -2.0, 7.6, 3.8, -32.6),
            (-37.0, -40.4, -1.7, -1.1, 5.2, 2.4, -37.2))
    for x0, x1, z0, z1, wide, thick, line_from in jaws:
        head.beam((x0, 0, z0), (x1, 0, z1), wide, thick, "pale", flat="z")

        def lip(x, x0=x0, x1=x1, z0=z0, z1=z1, thick=thick):
            return z0 + (z1 - z0) * (x - x0) / (x1 - x0) + thick / 2 + 0.2

        # the mouth's line: a glowing plate on the lip, the heart's light showing through the closed mouth
        head.beam((line_from, 0, lip(line_from)), (x1 + 0.9, 0, lip(x1 + 0.9)), wide - 1.6, 0.8, "heat", flat="z")
    # the eyes: small stars in dark sockets, a yellow ring round a white-hot middle
    head.dent(-26, -23, 6, -1, 3, "dark", depth=0.5)
    ring = (5.75, 6.3, -0.6, 2.4)
    head.block(-25.7, ring, -23.3, ring, "sun", mirror=True)
    middle = (5.9, 6.42, 0.1, 1.7)
    head.block(-25.0, middle, -24.0, middle, "core", mirror=True)
    # a bone brow over each eye, sweeping back into a short horn
    head.beam((-27.5, 4.6, 3.6), (-20.5, 5.2, 5.6), 1.8, 1.6, "bone", mirror=True)
    head.beam((-21.4, 5.0, 5.2), (-16.6, 6.4, 8.6), 1.5, 1.3, "bone", mirror=True)
    head.beam((-17.2, 6.2, 8.1), (-14.6, 6.9, 10.6), 1.0, 0.9, "bone-", mirror=True)

    # ---- the chest: a shoulder and the long back that holds the cage and the seat
    chest = m.part("Chest", (SHOULDER_X[0], 0, 0), "Head")
    slab(chest, *SHOULDER_X, *SHOULDER, belly=-5)
    slab(chest, *CHEST_X, *CHEST)
    sleeve(chest, SHOULDER_X[0], SHOULDER, SKULL, [(1, 1)])
    chest.carve_pair(SEAT[0] - 2, SEAT[0] + 2, 2, 4, TOP - 3, TOP)
    chest.paint_pair(SEAT[0] - 2, SEAT[0] + 2, 2, 4, TOP - 4, TOP - 3, "hide-")

    # the veins: from the pit's sides down each flank and back along it, branching up and down between the bands
    vein_path(chest, [(-9, TOP - 3), (-5, VEIN), (17, VEIN)])  # from under the heart, down and back to the tail
    vein_path(chest, [(-2, TOP - 3), (1, VEIN + 2)])  # a second root from the heart's back
    vein_path(chest, [(-5, VEIN), (-12, VEIN - 3), (-19, VEIN - 6)])  # forward and down to the flipper's root

    # ---- the pit: the back burnt in under the heart, white-hot at the bottom
    cx = SUN[0]
    reach = int(PIT) + 2
    for i in range(int(cx) - reach, int(cx) + reach + 1):
        for j in range(-reach, reach + 1):
            d = math.hypot(i + 0.5 - cx, j)
            if d < PIT:
                depth = round(1 + 3 * (1 - (d / PIT) ** 2))
                floor = TOP - depth
                for k in range(floor, TOP + 1):
                    chest.cells.pop((i, j, k), None)
                if (i, j, floor - 1) in chest.cells:
                    chest.cells[(i, j, floor - 1)] = "core" if d < 1.8 else "sun" if d < 3.0 else "heat"
            elif d < PIT + 1.0:
                stamp_top(chest, i, j, "ember")
    # the spine's line glows from the pit back to the seat
    for i in range(int(cx + PIT + 1), SEAT[0] - 2):
        stamp_top(chest, i, 0, "vein")

    # ---- the cage: each side its own joint, so the ribs can spread on the beat. A rib bursts out of the back's
    # shoulder, goes out and up, then curls in over the heart; an ember tip on each
    for name, s in (("CageR", 1), ("CageL", -1)):
        cage = m.part(name, (cx, 6.0 * s, TOP - 2), "Chest")
        for x, h, lean in RIBS:
            def at(t, y, up, x=x, lean=lean):
                return (x + lean * t, s * y, TOP + up)

            joints = [at(0.0, 6.0, -2.5), at(0.15, 8.6, 0.30 * h), at(0.45, 8.9, 0.62 * h), at(0.75, 6.6, 0.9 * h),
                      at(0.95, 3.0, h), at(1.0, 1.6, h - 0.6)]
            # wide (along the body) and thick (across) shrink at different rates, so a leaning rib's blocks never
            # end up with two faces nearly in one plane
            sizes = ((2.0, 1.5, "bone"), (1.6, 1.25, "bone"), (1.2, 1.0, "bone"), (0.9, 0.85, "bone"), (0.7, 0.7, "heat"))
            start = joints[0]
            for n, (wide, thick, colour) in enumerate(sizes):
                end = joints[n + 1]
                cage.beam(start, end, wide, thick, colour)
                start = tuple(start[q] + 0.8 * (end[q] - start[q]) for q in range(3))

    # ---- the heart: a small sun, on its own joint, turning once a swim
    sun = m.part("Sun", SUN, "Chest")
    r = SUN_R
    lo = int(math.floor(-r - 1))
    for di in range(lo, -lo + 1):
        for j in range(lo, -lo + 1):
            for dk in range(lo, -lo + 1):
                i, k = int(cx - 0.5) + di, int(SUN[2] - 0.5) + dk
                d = math.sqrt((i + 0.5 - cx) ** 2 + j ** 2 + (k + 0.5 - SUN[2]) ** 2)
                if d < r:
                    h = (i * 73 + j * 151 + k * 37) % 11  # spots on the surface: orange patches, white-hot granules
                    sun.cells[(i, j, k)] = "flare" if h in (0, 4) else "core" if h in (2, 7) else "sun"
    # flame tongues standing out of it, in a spiral round the ball (each rooted in the ball)
    for n in range(9):
        z = 1 - 2 * (n + 0.5) / 9
        a = n * 2.39996
        rad = math.sqrt(1 - z * z)
        d = (rad * math.cos(a), rad * math.sin(a), z * 0.8)
        length = 7.0 if n % 2 == 0 else 6.2

        def pt(t, d=d):
            return tuple(SUN[q] + d[q] * t for q in range(3))

        sun.beam(pt(3.0), pt(length - 0.9), 1.7, 1.7, "flare", flat="z")
        sun.beam(pt(length - 1.3), pt(length), 0.9, 0.9, "heat", flat="z")

    # loose flares orbiting the heart the other way
    flares = m.part("Flares", SUN, "Chest")
    for n, (rad, up, size) in enumerate(((7.1, 1.6, 0.9), (7.4, -1.4, 0.7), (6.9, 3.4, 0.6), (7.5, 0.3, 0.8), (7.2, -3.2, 0.6))):
        a = math.radians(n * 72 + 20)
        x, y = cx + rad * math.cos(a), rad * math.sin(a)
        colour = "sun" if n % 2 == 0 else "flare"
        tang = (-math.sin(a) * size, math.cos(a) * size)
        flares.beam((x - tang[0], y - tang[1], SUN[2] + up), (x + tang[0], y + tang[1], SUN[2] + up + 0.3 * size), size * 0.9,
                    size * 0.9, colour)

    # ---- the flippers: long, three boxes thinning to the tip, a vein down each
    for name, s in (("FlipperR", 1), ("FlipperL", -1)):
        f = m.part(name, (-18.0, 7.5 * s, -6.6), "Chest")
        blocks = (((-18.6, 5.2, -6.4), (-14.6, 11.6, -7.7), 4.8, 1.5, "hide"), ((-15.4, 10.5, -7.45), (-9.0, 14.8, -8.6), 3.9, 1.0, "hide"),
                  ((-10.0, 14.1, -8.4), (-5.4, 16.6, -9.2), 2.7, 0.6, "hide+"))
        for p0, p1, wide, thick, colour in blocks:
            f.beam((p0[0], p0[1] * s, p0[2]), (p1[0], p1[1] * s, p1[2]), wide, thick, colour, flat="z")
        for (p0, p1, wide, thick, _), proud in zip(blocks, (0.35, 0.3, 0.7)):
            vt = thick / 2 + proud  # from the block's middle to just proud of its top
            lift = vt / 2
            f.beam((p0[0], p0[1] * s, p0[2] + lift), (p1[0] - 0.4, p1[1] * s, p1[2] + lift), 0.7, vt, "vein", flat="z")

    # ---- the tail: slices on joints, each a cube smaller all round, a vein down each flank, small bone spines on top
    x, front, parent, segs = CHEST_X[1], CHEST, "Chest", []
    for i, (length, n, bot, top) in enumerate(TAIL):
        seg = m.part(f"T{i + 1}", (x, 0, 0), parent)
        slab(seg, x, x + length, n, bot, top)
        sleeve(seg, x, (n, bot, top), front)
        row = max(bot + 3, min(VEIN - i, top - 3))
        for c in range(x, x + length):
            stamp_side(seg, c, row, "vein", ("hide", "hide+", "hide-", "pale"))
        mid = x + length / 2
        tall = max(1.2, 3.0 - 0.3 * i)
        seg.beam((mid - 0.3, 0, top - 1.0), (mid + 0.35 * tall, 0, top + tall), 1.6 - 0.1 * i, 0.9, "bone")
        segs.append(seg)
        x, front, parent = x + length, (n, bot, top), f"T{i + 1}"
    end = x

    # ---- the blade: a tall tail fin, the upper lobe long, edged in bone, the vein running out into it
    blade = m.part("Blade", (end, 0, 0.5), f"T{len(TAIL)}")
    blade.beam((end - 0.8, 0, 0.5), (end + 2.6, 0, 0.5), 2.4, 1.6, "hide")
    blade.beam((end + 0.8, 0, 1.0), (end + 5.4, 0, 6.4), 4.2, 1.1, "hide")
    blade.beam((end + 4.6, 0, 5.5), (end + 8.8, 0, 10.8), 3.1, 0.8, "hide")
    blade.beam((end + 8.0, 0, 9.9), (end + 10.6, 0, 13.6), 1.9, 0.5, "bone")
    blade.beam((end + 0.8, 0, 0.0), (end + 4.6, 0, -4.0), 3.6, 0.8, "hide")
    blade.beam((end + 3.9, 0, -3.2), (end + 6.6, 0, -6.6), 2.2, 0.5, "bone")
    blade.beam((end + 1.0, 0, 1.3), (end + 7.6, 0, 8.6), 0.7, 1.35, "vein")
