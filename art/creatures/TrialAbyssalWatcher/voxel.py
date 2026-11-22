"""The Abyssal Watcher, remodel trial (docs/style/11-rare-wow-study.md, round 1) for tools/blender/voxel_kit.py.
Its idea, kept: a vast, swollen, slow bulk that is all eyes. One great halo eye fills its face; smaller eyes of every size
are scattered over the flanks and the back, each looking ahead.
What the study changes:
- One hero hue at full strength: magenta-violet in three values (a lighter top step, the violet flanks, a deep violet
  belly), black-violet for the shadows (lids, sockets, the spines, the pupils' pits).
- Glow as shapes, about 15% of what you see: every eye is a molten gold iris 2 to 4 cubes across in a lit ember socket
  ring, with a slit pupil; the great eye is a 15-cube disc of the same. A lit ember seam, two cubes tall, runs round the
  whole body where the violet meets the belly; at the face it opens into a down-turned grin with dark teeth.
- The back line rises: a crest of tall dark spines down the ridge, swept back, the tallest (a third of the body's height)
  in front of the rider, lower ones behind falling to the tail. The seat between them is clear.
The body, the fins, the tendrils and the slow swim are the old model's."""
import math

NAME, ZONE, RARITY = "Abyssal Watcher (trial)", "ZONE 10 / THE UNDERWORLD", "MYTHIC"
U = 0.5
PALETTE = {"hide": "#8E1FD9", "deep": "#5B1399", "shadow": "#26093A", "black": "#0E0414", "gold": "#FFB21E",
           "ember": "#FF6414"}
SHADE = 0.9
SEAT = (-3, 20, 2.5)
GLOW = {"gold": 0.9, "ember": 0.6}
LIGHTS = [("Body", (-37.5, 0, 1.5), "#FFB21E", 200, 1.0)]  # the great eye's light on its own lid and grin
FRAME, ORTHO, ORTHO_SWIM = 3.8, 48.0, 52.0
TEXTURES = [{"tile": "stud", "on": "top", "colours": ["hide"]}]

# the corners of a slice by its half width: (cubes in from the side, cubes tall), from the top down (and the bottom up)
STEPS = {17: [(8, 2), (5, 2), (2, 3)], 16: [(7, 2), (4, 2), (2, 3)], 15: [(7, 2), (4, 2), (2, 3)], 13: [(6, 2), (3, 2), (1, 2)],
         11: [(5, 2), (2, 2)], 9: [(4, 2), (2, 2)], 7: [(3, 1), (1, 2)], 5: [(2, 1), (1, 1)]}
# the body: (part, from, to, cubes out, bottom, top, the ridge's height on it, the seam's lowest row)
SLICES = (("Body", -34, -30, 9, -13, 10, 0, -9), ("Body", -30, -26, 11, -14, 12, 2, -9), ("Body", -26, -21, 13, -15, 14, 2, -9),
          ("Body", -21, -15, 15, -16, 15, 3, -10), ("Body", -15, -8, 16, -17, 16, 3, -10), ("Body", -8, 3, 17, -18, 17, 3, -11),
          ("Body", 3, 10, 16, -17, 17, 3, -10), ("Body", 10, 16, 15, -16, 16, 3, -10), ("R1", 16, 21, 13, -13, 14, 3, -8),
          ("R2", 21, 25, 11, -10, 12, 2, -6), ("R3", 25, 28, 9, -7, 9, 2, -4), ("R4", 28, 31, 7, -5, 7, 1, -2),
          ("R4", 31, 33, 5, -3, 5, 0, -1))
REAR = ["R1", "R2", "R3", "R4"]
# the small eyes: (slice number, from x, from z, iris size); the socket ring adds a cube all round
EYES_RIGHT = ((1, -30, 1, 2), (2, -26, -6, 3), (3, -21, 1, 4), (4, -14, -6, 3), (5, -7, 1, 4), (6, 4, 3, 3), (7, 11, -6, 2),
              (8, 16, 2, 3), (9, 21, 0, 2))
EYES_LEFT = ((1, -30, -5, 2), (2, -26, 1, 3), (3, -21, -6, 4), (4, -15, 2, 4), (5, -6, -7, 4), (6, 3, -6, 4), (7, 10, 2, 3),
             (8, 17, 2, 2), (9, 21, -3, 2))
# the eyes on the back: (slice number, from x, from column, iris size); none near the seat or the ridge
EYES_TOP = ((2, -26, -7, 3), (3, -21, 3, 4), (4, -15, -9, 4), (4, -14, 4, 2), (6, 4, 3, 4), (6, 4, -7, 2), (7, 10, -8, 3),
            (8, 16, 3, 3))
# the crest: (part, x, its foot's height (the ridge's top), height); the front ones tallest, a gap at the seat
SPINES = (("Body", -23.5, 16, 7), ("Body", -18, 18, 10), ("Body", -12.5, 19, 12), ("Body", 7, 20, 8), ("Body", 13, 19, 7),
          ("R1", 18.5, 17, 6), ("R2", 23, 14, 4.5), ("R3", 26.5, 11, 3.5))


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


def slab(p, x0, x1, n, bot, top, ridge, seam):
    """a slice of the bulk: stepped corners, a lighter top step, the deep belly up to the lit seam, the ridge on its back"""
    steps = STEPS[n]
    p.hull(x0, x1, n, bot, top, "hide", steps, steps)
    p.paint_sym(x0, x1, n, top - steps[0][1], top, "hide+")
    p.paint_sym(x0, x1, n, bot, seam, "deep")
    p.paint_sym(x0, x1, n, bot, bot + steps[0][1], "deep-")
    p.paint_sym(x0, x1, n, seam, seam + 2, "ember")
    if ridge:
        p.sym(x0, x1, 2, top, top + ridge, "deep")


def slit(cx, cz, size):
    """a slit pupil's box (x from, x to, z from, z to), a little forward of the iris's middle, so every eye looks ahead"""
    w, h = 0.3 * size + 0.2, 0.75 * size
    cx -= 0.12 * size
    return cx - w / 2, cx + w / 2, cz - h / 2, cz + h / 2


def side_eye(p, x0, z0, size, n, side, sx0, sx1):
    """an eye bulging from the flank: a lit ember socket ring a cube wider all round, standing a little proud, a gold
    iris standing out of it, a dark slit pupil on the iris. Ring and iris are each two crossed blocks, so their corners
    are cut and they read round. The bigger ones have a dark brow that slants down to the front over the ring's top"""
    ring = size + 2

    def ys(a, b):
        return tuple(sorted((side * (n + a), side * (n + b))))

    cut = 0.6
    socket = ys(-0.3, 0.85) + (z0 + 0.2 + cut, z0 + ring - 0.2 - cut)
    p.block(x0 + 0.2, socket, x0 + ring - 0.2, socket, "ember")
    socket = ys(-0.2, 0.7) + (z0 + 0.2, z0 + ring - 0.2)
    p.block(x0 + 0.2 + cut, socket, x0 + ring - 0.2 - cut, socket, "ember")
    if size >= 3:
        iris = ys(0.3, 1.15) + (z0 + 1.5, z0 + 0.5 + size)
        p.block(x0 + 1, iris, x0 + 1 + size, iris, "gold")
        iris = ys(0.4, 1.0) + (z0 + 1, z0 + 1 + size)
        p.block(x0 + 1.5, iris, x0 + 0.5 + size, iris, "gold")
        za, zb = z0 + 1.8, z0 + size + 0.2
    else:
        iris = ys(0.3, 1.15) + (z0 + 1, z0 + 1 + size)
        p.block(x0 + 1, iris, x0 + 1 + size, iris, "gold")
        za, zb = z0 + 1.3, z0 + 2.7
    cx, w = x0 + 1 + size / 2 - 0.12 * size, 0.25 * size + 0.2
    dark = ys(1.05, 1.3) + (za, zb)
    p.block(cx - w / 2, dark, cx + w / 2, dark, "black")
    if size >= 3:
        xa, xb = max(x0 - 0.5, sx0 + 0.6), min(x0 + ring + 0.3, sx1 - 0.6)
        y = side * (n + 0.65)
        p.beam((xb, y, z0 + ring + 0.25), (xa, y, z0 + ring - 0.55), 1.1, 1.5, "shadow")


def top_eye(p, x0, j0, size, top):
    """the same eye, bulging up out of the back: the slit runs nose to tail"""
    ring = size + 2
    socket = (j0 - 0.3 + 0.6, j0 + ring - 1.3, top - 0.3, top + 0.3)  # crossed, as on the flanks
    p.block(x0 + 0.2, socket, x0 + ring - 0.2, socket, "ember")
    socket = (j0 - 0.3, j0 + ring - 0.7, top - 0.2, top + 0.15)
    p.block(x0 + 0.8, socket, x0 + ring - 0.8, socket, "ember")
    iris = (j0 + 0.5, j0 + 0.5 + size, top, top + 0.55)
    p.block(x0 + 1, iris, x0 + 1 + size, iris, "gold")
    cx, cy, w = x0 + 1 + size / 2, j0 + 0.5 + size / 2, 0.15 * size + 0.1
    dark = (cy - w, cy + w, top + 0.3, top + 0.7)
    p.block(cx - 0.42 * size, dark, cx + 0.3 * size, dark, "black")


def spine(p, x, foot, h, lean=28):
    """a spine of the crest: a root beam buried in the ridge, a thinner one starting inside it, a point; swept back"""
    t = math.tan(math.radians(lean))
    w, th = 2.2 + 0.2 * h, 1.2 + 0.07 * h
    p.beam((x, 0, foot - 1.4), (x + t * 0.5 * h, 0, foot + 0.5 * h), w, th, "shadow")
    p.beam((x + t * 0.4 * h, 0, foot + 0.4 * h), (x + t * 0.85 * h, 0, foot + 0.85 * h), 0.65 * w, 0.7 * th, "shadow")
    cx, cz, hx, hy = x + t * 0.66 * h, foot + 0.66 * h, 0.25 * w, 0.3 * th
    p.spike([(cx - hx, -hy, cz), (cx + hx, -hy, cz), (cx + hx, hy, cz), (cx - hx, hy, cz)], (x + t * h, 0, foot + h), "shadow+")


def build(m):
    parts = {"Body": m.part("Body", (-4, 0, 0))}
    for k, name in enumerate(REAR):
        x = next(s[1] for s in SLICES if s[0] == name)
        parts[name] = m.part(name, (x, 0, 0), "Body" if k == 0 else REAR[k - 1])
    for i, (name, x0, x1, n, bot, top, ridge, seam) in enumerate(SLICES):
        slab(parts[name], x0, x1, n, bot, top, ridge, seam)
        if i and SLICES[i - 1][0] != name:  # a sleeve into the piece in front, inside both pieces' steps
            fn, fbot, ftop = SLICES[i - 1][3:6]
            clear = max(sum(t for _, t in STEPS[n]), sum(t for _, t in STEPS[fn])) + 1
            parts[name].sym(x0 - 1, x0, min(n, fn) - 2, max(bot, fbot) + clear, min(top, ftop) - clear, "hide-")
    body = parts["Body"]

    # the great eye: a boss one cube proud of the face, a broad lit socket ring, a gold iris inside it, and a tall slit
    # pupil, a dark pit one cube deep
    body.sym(-35, -34, 7, -3, 6, "ember")
    body.sym(-35, -34, 6, -5, 8, "ember")
    body.sym(-35, -34, 5, -6, 9, "ember")
    body.paint(-35, -34, -5, 6, -1, 4, "gold")
    body.paint(-35, -34, -4, 5, -3, 6, "gold")
    body.paint(-35, -34, -3, 4, -4, 7, "gold")
    body.carve(-35, -34, -1, 2, -2, 5)
    body.carve(-35, -34, -2, 3, 0, 3)
    body.paint(-34, -33, -1, 2, -2, 5, "black")
    body.paint(-34, -33, -2, 3, 0, 3, "black")
    # the lid: one heavy dark block that slants down to the front, sits on the eye's rim and cuts its top
    body.beam((-28.5, 0, 10.6), (-37.0, 0, 8.75), 12.4, 2.0, "deep", flat="z")
    # the grin: the seam opens across the face under the eye, its ends turned down, lit inside, with dark teeth hanging
    for j0, j1, z0, z1, back in ((-4, 5, -9, -7, -33.4), (5, 7, -10, -8, -33.6), (-6, -4, -10, -8, -33.6)):
        body.carve(-34, -33, j0, j1, z0, z1)
        section = (j0 - 0.7, j1 - 0.3, z0 - 0.2, z1 + 0.2)
        body.block(back, section, -32.8, section, "ember")
    body.tooth(-33.7, 0.0, -6.9, 0.7, 1.1, "shadow", mirror=False, long=0.5)
    for y in (2.0, 3.9):
        body.tooth(-33.7, y, -6.9, 0.7, 1.0, "shadow", long=0.5)

    # the small eyes
    for eyes, side in ((EYES_RIGHT, 1), (EYES_LEFT, -1)):
        for i, x0, z0, size in eyes:
            sl = SLICES[i]
            side_eye(parts[sl[0]], x0, z0, size, sl[3], side, sl[1], sl[2])
    for i, x0, j0, size in EYES_TOP:
        top_eye(parts[SLICES[i][0]], x0, j0, size, SLICES[i][5])

    # the crest
    for name, x, foot, h in SPINES:
        spine(parts[name], x, foot, h)

    # the stubby fins on the first swaying flank, each on its own joint: a broad thin paddle that starts inside the body, a
    # thicker collar round its root, a smaller dark tip
    for name, s in (("FinR", 1), ("FinL", -1)):
        fin = m.part(name, (18.5, 13 * s, -3), "R1")
        fin.beam((18.3, 10.6 * s, -3.1), (20.1, 14.3 * s, -3.98), 4.2, 2.6, "hide", flat="z")
        fin.beam((18.5, 11 * s, -3.2), (22.2, 18.6 * s, -5.0), 5.6, 1.4, "hide", flat="z")
        fin.beam((21.4, 17.2 * s, -4.7), (23.2, 20.4 * s, -5.5), 3.8, 0.8, "deep", flat="z")

    # three short tendrils behind, each on its own joint: three boxes in a chain, each smaller, drooping
    mid = m.part("TendrilM", (32, 0, 2.2), "R4")
    mid.beam((31, 0, 2.2), (35.0, 0, 1.6), 4.0, 3.4, "hide", flat="z")
    mid.beam((34.2, 0, 1.7), (37.6, 0, 0.6), 2.8, 2.4, "hide", flat="z")
    mid.beam((36.8, 0, 0.8), (39.5, 0, -0.7), 1.8, 1.5, "deep", flat="z")
    for name, s in (("TendrilR", 1), ("TendrilL", -1)):
        t = m.part(name, (32, 3 * s, -0.4), "R4")
        t.beam((31, 3 * s, -0.4), (34.4, 4.6 * s, -1.6), 2.8, 2.6, "hide", flat="z")
        t.beam((33.7, 4.3 * s, -1.4), (36.6, 5.8 * s, -3.0), 2.0, 1.7, "hide", flat="z")
        t.beam((35.9, 5.5 * s, -2.7), (38.2, 6.8 * s, -4.5), 1.3, 1.1, "deep", flat="z")
