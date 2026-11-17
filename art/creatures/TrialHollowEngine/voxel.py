"""The Hollow with its black hole standing upright on the back behind the rider, its disc facing the riding
camera like a wheel (option 3 of docs/design/cosmic.md). The lower half sits in a round slot cut down into the back,
so the ball and the inner ring show into the body. Face on, bent light is a ring all round the ball, not an arc.
Built from art/creatures/TrialHollow by a script; the black hole is art/creatures/TrialBlackHole's."""
import math
import importlib.util
import os

_spec = importlib.util.spec_from_file_location("black_hole_parts", os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "TrialBlackHole", "voxel.py"))
BH = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(BH)

NAME, ZONE, RARITY = "The Hollow, engine (trial)", "UNPLACED", "COSMIC"
U = 0.5
PALETTE = {"slate": "#2F6FAE", "pale": "#C9DCE8", "iron": "#232A3B", "eye": "#FF9A3C", "dark": "#10141F",
           **{k: c for k, c in BH.PALETTE.items()}}
SEAT = (-10, 12, 1.6)
GLOW = {"eye": 0.8, **BH.GLOW}
LIGHTS = [("Chest", (1.0, 0, 13.0), "#FFB060", 170, 1.0)]  # the disc lights the back
FRAME, ORTHO, ORTHO_SWIM = 3.7, 52.0, 58.0
TEXTURES = [{"tile": "stud", "on": "top", "colours": ["slate"]}]

LINE = 7  # the height of the pale line along the flank: it is the hall's lintel
SKULL_X, SKULL = (-31, -23), (7, -8, 8)  # cubes out, bottom, top
SHOULDER_X, SHOULDER = (-23, -19), (8, -10, 11)
CAGE_X, CAGE = (-19, 12), (9, -12, 12)  # a long chest: room for the rider and the set piece
HOLE = (-1, 11)  # the black hole's middle (x, z), in the model's cubes
FLOATING = ["Core", "DiscA", "DiscB", "Rim", "JetUp", "JetDown"]
TILT = 0  # degrees the disc leans toward the riding camera
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
    for name, turns in (("DiscA", 3), ("DiscB", 2), ("Rim", 1), ("JetUp", -2), ("JetDown", 2)):
        if name in parts:
            parts[name].rotation_euler.x = turns * phase  # the upright disc turns facing the camera


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
    # the eye: a hollow socket low on the skull, by the corner of the mouth, with the teal light deep in it. No pupil
    head.dent(-30, -27, 7, -1, 2, "dark", depth=0.5)
    light = (6.8, 7.25, -0.3, 1.3)
    head.block(-29.3, light, -27.7, light, "eye", mirror=True)
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
    # ---- the black hole on the back, in smaller cubes than the whale's (Part.fine)
    # the slot: a round cut down into the back, two cubes either side of the disc's plane, dark inside, an iron lip
    hx, hz = HOLE
    for i in range(hx - 4, hx + 4):
        for j in range(-10, 11):
            for kk in range(hz - 6, top):
                d = math.hypot(j, kk + 0.5 - hz)
                if abs(i + 0.5 - hx) <= 1.5 and d <= 5:
                    chest.carve(i, i + 1, j, j + 1, kk, kk + 1)
                elif abs(i + 0.5 - hx) <= 2.5 and d <= 6:
                    chest.paint(i, i + 1, j, j + 1, kk, kk + 1, "iron" if kk >= top - 1 else "dark")
    BH.black_hole(m, "Chest", 3 * hx, 3 * hz, 0, rim=False, fine=3, axis="x", face="front")

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
