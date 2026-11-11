"""The Abyssal Watcher (zone 10's Mythic: an invented animal) for tools/blender/voxel_kit.py (docs/style/04-voxel-style.md).
Its idea: a vast, swollen, slow bulk that is all eyes. One great halo eye fills its face; smaller eyes of every size are
scattered over the flanks and the back, each in a shallow socket, each looking ahead.
- The body is eleven slices that swell from the face to the middle and thin to the rear, in width, back and belly, so
  the side, the top and the front are each an egg. The corners are cut in three broad steps where it is thick.
- The head has its own shape: the great eye stands out of the face as a boss (a dark rim, a groove of light, a dark
  pupil), a heavy lid slants down over it and comes past it, and the chin falls away under it to a small down-turned mouth.
- A low ridge runs along the back from the lid to the rear: the rider sits astride it, legs either side, feet on the back.
- Two thin lines run the whole length: one at the great eye's height round the flanks, one along the top of the ridge.
- Stubby fins on the last flank and three short tendrils behind sway slowly.
Deep bruise purple, a paler belly, the eyes a sickly yellow-green light (the only glow)."""
import math

NAME, ZONE, RARITY = "Abyssal Watcher", "ZONE 10 / THE UNDERWORLD", "MYTHIC"
U = 0.5
PALETTE = {"hide": "#4B2F63", "belly": "#7E5C8A", "glow": "#C6E548", "black": "#17111C", "vein": "#8A9440"}
SEAT = (-3, 20, 2.5)
GLOW = {"glow": 0.7}  # the eyes, nothing else
LIGHTS = [("Body", (-37.5, 0, 0.5), "#C6E548", 200, 1.0)]  # the great eye's light on its own lid and chin
FRAME, ORTHO, ORTHO_SWIM = 3.7, 46.0, 50.0
TEXTURES = [{"tile": "stud", "on": "top", "colours": ["hide"]}]

# the corners of a slice by its half width: (cubes in from the side, cubes tall), from the top down (and the bottom up)
STEPS = {17: [(8, 2), (5, 2), (2, 3)], 16: [(7, 2), (4, 2), (2, 3)], 15: [(7, 2), (4, 2), (2, 3)], 13: [(6, 2), (3, 2), (1, 2)],
         11: [(5, 2), (2, 2)], 9: [(4, 2), (2, 2)], 7: [(3, 1), (1, 2)], 5: [(2, 1), (1, 1)]}
# the body: (part, from, to, cubes out, bottom, top, the ridge's height on it). The belly sinks a cube a slice from the
# chin to the middle and rises faster behind it; the back arches; the width swells and thins with them
SLICES = (("Body", -34, -30, 9, -13, 10, 0), ("Body", -30, -26, 11, -14, 12, 2), ("Body", -26, -21, 13, -15, 14, 2),
          ("Body", -21, -15, 15, -16, 15, 3), ("Body", -15, -8, 16, -17, 16, 3), ("Body", -8, 3, 17, -18, 17, 3),
          ("Body", 3, 10, 16, -17, 17, 3), ("Body", 10, 16, 15, -16, 16, 3), ("R1", 16, 21, 13, -13, 14, 3),
          ("R2", 21, 25, 11, -10, 12, 2), ("R3", 25, 28, 9, -7, 9, 2), ("R4", 28, 31, 7, -5, 7, 1), ("R4", 31, 33, 5, -3, 5, 0))
REAR = ["R1", "R2", "R3", "R4"]
# the small eyes: (slice number, from x, from z, size), in the slice's outermost column, right side and left side
EYES_RIGHT = ((5, -6, 2, 5), (5, -3, -8, 3), (4, -13, -6, 3), (3, -20, 3, 3), (2, -25, -5, 2), (6, 5, -6, 4), (6, 6, 5, 2),
              (7, 11, 3, 3), (9, 22, 2, 2), (1, -29, 3, 2))
EYES_LEFT = ((5, -5, -9, 5), (5, -7, 4, 3), (4, -13, 2, 4), (3, -20, -5, 2), (2, -25, 2, 3), (6, 4, 3, 4), (7, 11, -7, 3),
             (8, 17, 4, 3), (9, 22, -3, 2), (1, -29, -5, 2))
# the eyes on the back: (slice number, from x, from column, size); none near the seat
EYES_TOP = ((3, -20, 4, 3), (6, 5, -8, 3), (4, -13, 5, 2), (7, 12, 4, 2), (2, -25, -5, 2))


def pose(parts, phase):
    """a slow, heavy swim: the bulk barely turns, the rear sways side to side behind it, the tendrils trail the sway and
    the stubby fins row"""
    parts["Body"].rotation_euler.z = math.radians(1.0) * math.sin(phase + math.pi)
    for k, name in enumerate(REAR):
        parts[name].rotation_euler.z = math.radians((2, 3, 4, 5)[k]) * math.sin(phase - 0.6 * (k + 1))
    parts["TendrilM"].rotation_euler.z = math.radians(14) * math.sin(phase - 3.2)
    parts["TendrilM"].rotation_euler.y = math.radians(6) * math.sin(phase - 2.0)
    for name, side in (("TendrilR", 1), ("TendrilL", -1)):
        parts[name].rotation_euler.z = math.radians(16) * math.sin(phase - 3.6)
        parts[name].rotation_euler.y = math.radians(7) * math.sin(phase - 2.6 + side * 0.8)
    for name, side in (("FinR", 1), ("FinL", -1)):
        parts[name].rotation_euler.x = side * math.radians(13) * math.sin(phase - 0.6)
        parts[name].rotation_euler.z = side * math.radians(6) * math.sin(phase - 1.6)


def slab(p, x0, x1, n, bot, top, ridge):
    """a slice of the bulk: stepped corners, a lighter top row, a pale stepped belly, the thin line at the great eye's
    height, and the ridge on its back with the second thin line along it"""
    steps = STEPS[n]
    p.hull(x0, x1, n, bot, top, "hide", steps, steps)
    p.paint_sym(x0, x1, n, top - steps[0][1], top, "hide+")  # the whole top step, and the whole bottom one: no thin rows
    tall = sum(t for _, t in steps)
    p.paint_sym(x0, x1, n, bot, bot + tall, "belly")
    p.paint_sym(x0, x1, n, bot, bot + steps[0][1], "belly-")
    p.paint_sym(x0, x1, n, 0, 1, "vein")
    if ridge:
        p.sym(x0, x1, 2, top, top + ridge, "hide+")
        p.paint(x0, x1, 0, 1, top, top + ridge, "vein")
    else:
        p.paint(x0, x1, 0, 1, top - 1, top, "vein")


def pupil_at(x0, z0, size):
    """a small eye's pupil: it fills the eye but for a thin ring of light (the great eye's halo again), and sits a little
    forward of the middle, so every eye looks ahead"""
    ring = 0.3 + 0.12 * size
    q = size - 2 * ring
    cx, cz = x0 + size / 2 - 0.3 * ring, z0 + size / 2
    return cx - q / 2, cx + q / 2, cz - q / 2, cz + q / 2


def side_eye(p, x0, z0, size, n, side):
    """an eye in the flank: a shallow socket filled with light, a dark pupil standing in it (still under the skin's line).
    The bigger ones have a lid: a darker bar that sits on the eye, cuts its top and comes past it in front"""
    p.dent(x0, x0 + size, n * side, z0, z0 + size, "glow", depth=0.4, pair=False)
    xa, xb, za, zb = pupil_at(x0, z0, size)
    face = n + 0.1
    ya, yb = sorted((side * (face - 0.1), side * (face + 0.25)))
    p.block(xa, (ya, yb, za, zb), xb, (ya, yb, za, zb), "black")
    if size >= 3:
        ya, yb = sorted((side * (n - 0.2), side * (n + 0.8)))  # its back is in the skin above the eye and in the eye's light
        lid = (ya, yb, z0 + size - 0.4, z0 + size + 0.5)
        p.block(x0 - 0.7, lid, x0 + size + 0.3, lid, "hide-")


def top_eye(p, x0, j0, size, top):
    """the same eye, looking up out of the back"""
    p.carve(x0, x0 + size, j0, j0 + size, top - 1, top)
    lens = (j0 - 0.5, j0 + size - 0.5, top - 1.05, top - 0.4)
    p.block(x0, lens, x0 + size, lens, "glow")
    xa, xb, ya, yb = pupil_at(x0, j0 - 0.5, size)
    dark = (ya, yb, top - 0.5, top - 0.15)
    p.block(xa, dark, xb, dark, "black")


def front_dent(p, x, j0, j1, z0, z1, colour):
    """a shallow recess in a face that looks forward: the cubes cut out and filled again 0.3 short of the surface"""
    p.carve(x, x + 1, j0, j1, z0, z1)
    section = (j0 - 0.5, j1 - 0.5, z0, z1)
    p.block(x + 0.3, section, x + 1.05, section, colour)


def build(m):
    parts = {"Body": m.part("Body", (-4, 0, 0))}
    for k, name in enumerate(REAR):
        x = next(s[1] for s in SLICES if s[0] == name)
        parts[name] = m.part(name, (x, 0, 0), "Body" if k == 0 else REAR[k - 1])
    for i, (name, x0, x1, n, bot, top, ridge) in enumerate(SLICES):
        slab(parts[name], x0, x1, n, bot, top, ridge)
        if i and SLICES[i - 1][0] != name:  # a sleeve into the piece in front, inside both pieces' steps
            _, _, _, fn, fbot, ftop, _ = SLICES[i - 1]
            clear = max(sum(t for _, t in STEPS[n]), sum(t for _, t in STEPS[fn])) + 1
            parts[name].sym(x0 - 1, x0, min(n, fn) - 2, max(bot, fbot) + clear, min(top, ftop) - clear, "hide-")
    body = parts["Body"]

    # the great eye: a boss one cube proud of the face. A rim, a broad ring of light flush with it (the halo), and the
    # pupil a dark pit in the middle, one cube deep
    body.sym(-35, -34, 7, -4, 5, "hide")
    body.sym(-35, -34, 5, -7, 8, "hide")
    body.paint(-35, -34, -5, 6, -2, 3, "glow")
    body.paint(-35, -34, -3, 4, -5, 6, "glow")
    body.carve(-35, -34, -3, 4, -2, 3)
    body.carve(-35, -34, -2, 3, -3, 4)
    body.paint(-34, -33, -3, 4, -3, 4, "black")
    # the lid: one heavy block that slants down to the front, sits on the eye's rim and comes past it
    body.beam((-29.5, 0, 10.4), (-37.0, 0, 7.75), 12.4, 2.0, "hide", flat="z")
    # the mouth, on the pale chin under the eye: a small line, its ends turned down
    front_dent(body, -34, -2, 3, -11, -10, "black")
    front_dent(body, -34, 3, 5, -12, -11, "black")
    front_dent(body, -34, -4, -2, -12, -11, "black")

    # the small eyes
    for eyes, side in ((EYES_RIGHT, 1), (EYES_LEFT, -1)):
        for i, x0, z0, size in eyes:
            side_eye(parts[SLICES[i][0]], x0, z0, size, SLICES[i][3], side)
    for i, x0, j0, size in EYES_TOP:
        top_eye(parts[SLICES[i][0]], x0, j0, size, SLICES[i][5])

    # the stubby fins on the first swaying flank, each on its own joint: a broad thin paddle that starts inside the body, a
    # thicker collar round its root, a smaller tip
    for name, s in (("FinR", 1), ("FinL", -1)):
        fin = m.part(name, (18.5, 13 * s, -3), "R1")
        fin.beam((18.3, 10.6 * s, -3.1), (20.1, 14.3 * s, -3.98), 4.2, 2.6, "hide", flat="z")  # on the paddle's own line
        fin.beam((18.5, 11 * s, -3.2), (22.2, 18.6 * s, -5.0), 5.6, 1.4, "hide", flat="z")
        fin.beam((21.4, 17.2 * s, -4.7), (23.2, 20.4 * s, -5.5), 3.8, 0.8, "hide-", flat="z")

    # three short tendrils behind, each on its own joint: three boxes in a chain, each smaller, drooping
    mid = m.part("TendrilM", (32, 0, 2.2), "R4")
    mid.beam((31, 0, 2.2), (35.0, 0, 1.6), 4.0, 3.4, "hide", flat="z")
    mid.beam((34.2, 0, 1.7), (37.6, 0, 0.6), 2.8, 2.4, "hide", flat="z")
    mid.beam((36.8, 0, 0.8), (39.5, 0, -0.7), 1.8, 1.5, "belly", flat="z")
    for name, s in (("TendrilR", 1), ("TendrilL", -1)):
        t = m.part(name, (32, 3 * s, -0.4), "R4")
        t.beam((31, 3 * s, -0.4), (34.4, 4.6 * s, -1.6), 2.8, 2.6, "hide", flat="z")
        t.beam((33.7, 4.3 * s, -1.4), (36.6, 5.8 * s, -3.0), 2.0, 1.7, "hide", flat="z")
        t.beam((35.9, 5.5 * s, -2.7), (38.2, 6.8 * s, -4.5), 1.3, 1.1, "belly", flat="z")
