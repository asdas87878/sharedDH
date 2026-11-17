"""The Hollow, a trial (docs/design/cosmic.md, a COSMIC: the whale with a black hole in its belly) for
tools/blender/voxel_kit.py. Built on the Phantom Whale's model (art/creatures/PhantomWhale), which is not changed.
Its idea: a huge plain whale with a hall cut right through its chest, and in the hall a black hole.
- The body is the calmest we have: slate blue, a pale belly, one pale line along the flank, one dark seam down the back.
  No tatters, no marks.
- The hall: an eight-sided hole clean through the chest from flank to flank, dark inside, with an iron arch at each end
  like the ribs of a hall, and an iron axis from roof to floor.
- The set piece, on its own joint ("Core"): a matte black ball on the axis, and through it a tilted disc: white-hot near
  the ball, orange at its edge. The Core turns once every beat of the swim, so the tilted disc wobbles like a top.
- The eye is a dark socket with the same orange light in it.
The rider sits on the roof of the hall, legs in two slots either side of the seam."""
import math

NAME, ZONE, RARITY = "The Hollow (trial)", "UNPLACED", "COSMIC"
U = 0.5
PALETTE = {"slate": "#2F6FAE", "pale": "#C9DCE8", "iron": "#232A3B", "ember": "#FF9A3C", "dark": "#10141F", "void": "#07070B",
           "ring": "#FFF1D6"}
SEAT = (-5, 12, 1.6)
GLOW = {"ember": 0.8, "ring": 1.0}  # the disc round the black hole, and the eye
LIGHTS = [("Chest", (-5.0, 5.6, 3.2), "#FFB060", 170, 0.8)]  # the disc lights the hall from inside
FRAME, ORTHO, ORTHO_SWIM = 3.7, 52.0, 58.0
TEXTURES = [{"tile": "stud", "on": "top", "colours": ["slate"]}]

LINE = 7  # the height of the pale line along the flank: it is the hall's lintel
SKULL_X, SKULL = (-31, -23), (7, -8, 8)  # cubes out, bottom, top
SHOULDER_X, SHOULDER = (-23, -19), (8, -10, 11)
CAGE_X, CAGE = (-19, 9), (9, -12, 12)  # the chest swells round the hall
WINDOW = (-17, 7, -8, LINE)  # the hall: x from, x to, z from, z to, cut through the whole body
ARCHES = ((-17, -15), (5, 7))  # an iron arch at each end of the hall
RAFTERS = (-11, -8, -3, 0)  # iron beams across its roof and floor
CORE = (-5, 0, -0.5)  # the black hole's middle
TILT = 24  # degrees: how far the disc leans
# the tail: each slice is (length, cubes out, bottom, top), a cube smaller all round than the one before
TAIL = ((5, 8, -10, 11), (6, 7, -8, 9), (5, 6, -6, 8), (4, 5, -5, 7), (4, 4, -4, 6), (3, 3, -3, 5), (3, 2, -2, 4))
CHAIN = ["Chest"] + [f"T{i + 1}" for i in range(len(TAIL))] + ["Fluke"]
AMPLITUDES = [1.5, 2.5, 3.5, 4.5, 5.5, 6.5, 7.5, 8.5, 13]


def pose(parts, phase):
    """a whale's swim: a slow wave runs down the body up and down and ends in the fluke; the flippers row a little"""
    parts["Head"].rotation_euler.y = math.radians(1.5) * math.sin(phase + math.pi)
    for k, name in enumerate(CHAIN):
        parts[name].rotation_euler.y = math.radians(AMPLITUDES[k]) * math.sin(phase - 0.5 * (k + 1))
    for name, side in (("FlipperR", 1), ("FlipperL", -1)):
        parts[name].rotation_euler.x = side * math.radians(10) * math.sin(phase - 0.8)
        parts[name].rotation_euler.z = side * math.radians(5) * math.sin(phase - 1.8)
    parts["Core"].rotation_euler.z = phase  # one turn a beat: the tilted disc wobbles


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


def hall(p, x0, x1, n, z0, z1, arches=()):
    """an eight-sided hole cut clean through a slice from flank to flank: the hall. Dark inside; an iron arch a cube inside
    the skin at each end, right round (walls, roof and floor); an iron axis from floor to roof at the middle"""
    p.paint(x0 - 1, x1 + 1, 1 - n, n, z0 - 1, z1 + 1, "dark")
    for k in (2, 1, 0):  # an iron frame on the skin, one cube wide all round the hole
        for j in (-n, n):
            p.paint(x0 + k - 1, x1 - k + 1, j, j + 1, z0 + 1 - k, z1 - 1 + k, "iron")
    for k in (2, 1, 0):  # the corners cut in two steps: an octagon
        p.carve(x0 + k, x1 - k, -n, n + 1, z0 + 2 - k, z1 - 2 + k)
    for r0, r1 in arches:
        p.pair(r0, r1, n - 1, n, z0, z1, "iron")
        p.sym(r0, r1, n - 1, z1 - 1, z1, "iron")
        p.sym(r0, r1, n - 1, z0, z0 + 1, "iron")
    for x in RAFTERS:
        p.sym(x, x + 1, n - 1, z1 - 1, z1, "iron")
        p.sym(x, x + 1, n - 1, z0, z0 + 1, "iron")
    p.box(CORE[0] - 1, CORE[0] + 1, 0, 1, z0, z1, "iron")


def disc(p, radius, thick, colour):
    """an eight-sided plate round the Core's middle, leaning TILT degrees. It is eight wedges, each with its inner end
    inside the ball: a free piece needs a buried root"""
    a, inner = math.radians(TILT), 1.4

    def at(r, t, half):
        x, y = r * math.cos(t), r * math.sin(t)
        return (CORE[0] + x, CORE[1] + y * math.cos(a) - half * math.sin(a), CORE[2] + y * math.sin(a) + half * math.cos(a))

    for k in range(8):
        t0, t1 = math.radians(22.5 + 45 * k), math.radians(67.5 + 45 * k)
        verts = [at(r, t, h) for h in (-thick / 2, thick / 2) for r, t in ((inner, t0), (inner, t1), (radius, t1), (radius, t0))]
        p.solid(verts, [(0, 1, 2, 3), (4, 5, 6, 7), (0, 1, 5, 4), (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7)], colour)


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
    # the eye: a hollow socket low on the skull, by the corner of the mouth, with the teal light deep in it. No pupil
    head.dent(-30, -27, 7, -1, 2, "dark", depth=0.5)
    light = (6.8, 7.25, -0.3, 1.3)
    head.block(-29.3, light, -27.7, light, "ember", mirror=True)
    blow = (0.6, 1.3, 7.8, 8.2)  # the blowholes
    head.block(-27.4, blow, -26.2, blow, "dark", mirror=True)

    # ---- the chest: one rigid piece, a shoulder and the hollow cage with a window through both flanks
    chest = m.part("Chest", (SHOULDER_X[0], 0, 0), "Head")
    slab(chest, *SHOULDER_X, *SHOULDER, belly=-5)
    slab(chest, *CAGE_X, *CAGE)
    sleeve(chest, SHOULDER_X[0], SHOULDER, SKULL, [(1, 1)])
    # the seat: on the spine's line, a slot either side for the rider's legs
    top = CAGE[2]
    chest.carve_pair(SEAT[0] - 2, SEAT[0] + 2, 2, 4, top - 3, top)
    chest.paint_pair(SEAT[0] - 2, SEAT[0] + 2, 2, 4, top - 4, top - 3, "slate-")
    hall(chest, WINDOW[0], WINDOW[1], CAGE[0], WINDOW[2], WINDOW[3], ARCHES)

    # ---- the black hole, on its own joint so it can turn: a matte black ball on the axis, and through it the tilted disc
    core = m.part("Core", CORE, "Chest")
    cx = CORE[0]
    core.box(cx - 4, cx + 4, -2, 3, -3, 2, "void")
    core.box(cx - 3, cx + 3, -3, 4, -3, 2, "void")
    core.box(cx - 3, cx + 3, -2, 3, -4, 3, "void")
    disc(core, 11.4, 0.6, "ember")  # it reaches a cube past the skin either side: the ring shows from above and behind
    disc(core, 7.0, 1.2, "ring")

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
