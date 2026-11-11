"""The Infernal Angler (zone 10's Legendary: the Anglerfish of the Underworld) for tools/blender/voxel_kit.py
(docs/style/04-voxel-style.md), dressed as a Legendary by docs/style/05-rarity-look.md. A variant of
art/creatures/Anglerfish: the same animal, bigger and built from more cubes (about 28 studs).
Its idea: a burnt-out ball of mouth that carries a live coal. The skin is charred plum-charcoal and plain; the one bright
thing is the ember on the rod, and everything else that glows is the same fire showing through.
- The body is the Anglerfish's ball, in more slices: a dome that climbs in three broad steps from the snout to a narrow
  crest, and closes in five to the tail; the belly curves the same way, from the chin down and up again. It tapers in
  plan too.
- The focal point: the lure, an ember ball (a core of cubes with a hotter plate on each face) on a two-jointed rod.
- The echo: lava in the body's own joints. Where two slices meet behind the head, behind the ball and on the tail stock,
  a seam one cube wide lies a third of a cube deep and glows, from the crest down the flank.
- Ember teeth, more of them, hanging from a thin dark gum plate set inside the lip and standing on a gum rim on the jaw.
- A glowing ember eye with a dark pupil, under a heavy brow that comes past it in front, and a short horn stub on each
  corner of the head, in front of the first seam.
The rider sits astride the crest on top of the ball, legs in a shallow slot either side, well behind the horns."""
import math

NAME, ZONE, RARITY = "Infernal Angler", "ZONE 10 / THE UNDERWORLD", "LEGENDARY"
U = 0.45
SHADE = 0.74
PALETTE = {"char": "#43333F", "belly": "#63383F", "ember": "#FFC93C", "lava": "#FF6A1C", "tooth": "#FFC27A", "gum": "#7C1F25",
           "mouth": "#2A0E14", "black": "#141216", "horn": "#8A7672"}
SEAT = (-2.5, 16, 3.6)
GLOW = {"ember": 1.0, "lava": 0.8, "tooth": 0.3}
LIGHTS = [("Lure", (-27.5, 0, 14.5), "#FF9A2A", 70, 0.6), ("Body", (-18.3, 9.6, 6.0), "#FFB030", 18, 0.4)]
KEEP = ["tooth", "gum", "mouth", "black", "ember", "lava"]
TEXTURES = [{"tile": "stud", "on": "top", "colours": ["char"]}]
FRAME, ORTHO, ORTHO_SWIM = 2.5, 36.0, 42.0
RIDE_FOG = "#3A1420"

EDGE = -8  # the belly's colour stops at this height the whole way along, so its edge is one line

# the slices of the body: (from, to, cubes out either side, underside, top, top corner steps, bottom corner steps). Steps
# are (cubes in from the side, cubes tall), from the top down or the bottom up. Each slice lies inside the one nearer the
# ball, so every change shows as a step. Seen from the side the back is a dome: a plateau twelve cubes long, then down
# by two, three and three cubes to the snout and by two, three, three, three and two to the tail; the belly does the same
H1 = (-25, -21, 6, 5, 9, [(3, 1), (1, 1)], [])
H2 = (-21, -15, 8, 3, 12, [(5, 2), (2, 2)], [])
H3 = (-15, -9, 10, 1, 14, [(7, 2), (2, 3)], [])
BALL = (-9, 3, 12, -15, 16, [(9, 3), (4, 3), (1, 3)], [(8, 1), (4, 3), (1, 3)])
B2 = (3, 8, 10, -13, 14, [(7, 2), (2, 3)], [(6, 1), (2, 3)])
B3 = (8, 13, 8, -10, 11, [(5, 2), (2, 2)], [(4, 1), (2, 2)])
B4 = (13, 17, 6, -7, 8, [(3, 1), (1, 2)], [(3, 1), (1, 2)])
B5 = (17, 20, 4, -4, 5, [(2, 1), (1, 1)], [(2, 1), (1, 1)])
B6 = (20, 22, 3, -2, 3, [(1, 1)], [(1, 1)])


def pose(parts, phase):
    """the Anglerfish's slow waddle: the ball rolls and yaws a little and the back end swings wide behind it; the fins
    flutter, weakly, twice a beat; the jaw gulps once a beat; the lure sways late, each joint later than the one before"""
    s = math.sin
    parts["Body"].rotation_euler.x = math.radians(3) * s(phase)
    parts["Body"].rotation_euler.z = math.radians(2.5) * s(phase + math.pi)
    for name, amp, lag in (("B2", 5, 0.6), ("B3", 8, 1.2), ("B4", 11, 1.8), ("Tail", 18, 2.5)):
        parts[name].rotation_euler.z = math.radians(amp) * s(phase - lag)
    parts["Jaw"].rotation_euler.y = -math.radians(8) * (0.5 + 0.5 * s(phase - 0.6))
    for name, side in (("FinR", 1), ("FinL", -1)):
        parts[name].rotation_euler.z = side * math.radians(14) * s(2 * phase)
        parts[name].rotation_euler.x = side * math.radians(8) * s(2 * phase - 1.0)
    parts["Rod1"].rotation_euler.x = math.radians(6) * s(phase - 1.2)
    parts["Rod1"].rotation_euler.y = math.radians(4) * s(phase - 1.0)
    parts["Rod2"].rotation_euler.x = math.radians(8) * s(phase - 2.0)
    parts["Rod2"].rotation_euler.y = math.radians(5) * s(phase - 1.8)
    parts["Lure"].rotation_euler.x = math.radians(15) * s(phase - 2.9)
    parts["Lure"].rotation_euler.y = math.radians(9) * s(phase - 2.6)


def slab(p, spec):
    """a slice of the body: stepped corners, lighter on the top row, the duller belly below the line"""
    x0, x1, n, bot, top, steps, under = spec
    p.hull(x0, x1, n, bot, top, "char", steps, under)
    p.paint_sym(x0, x1, n, top - 1, top, "char+")
    if under:
        p.paint_sym(x0, x1, n, bot, EDGE, "belly")
        p.paint_sym(x0, x1, n, bot, bot + under[0][1], "belly-")


def seam(p, x, spec, low, back=1.5, front=0.0, core=None):
    """lava in a joint: the slice's cubes in column x are cut away from height `low` up, and the gap filled again to a
    third of a cube short of the surface all round, in the lava's colour: a glowing line drawn round the body, not a
    trench. `low` lies a row inside the flat of the flank, so the filling's foot is buried in the cubes left under it.
    core: (cubes out, top) of a core of cubes left inside the filling, as big as the part's sleeve, so the sleeve's end
    is not a face in the plane of the part in front"""
    _, _, n, bot, top, steps, under = spec
    d = 0.3
    runs, z = [], bot
    for inset, tall in under:
        runs.append((z, z + tall, n + 0.5 - inset))
        z += tall
    flat_from, z, tops = z, top, []
    for inset, tall in steps:
        tops.append((z - tall, z, n + 0.5 - inset))
        z -= tall
    runs.append((flat_from, z, n + 0.5))
    runs += reversed(tops)
    runs = [(max(a, low), b, hw) for a, b, hw in runs if b > low]
    p.carve(x, x + 1, -n, n + 1, low, top)
    if core:
        p.sym(x, x + 1, core[0], low, core[1], "lava-")
    cuts = [low - 0.5]
    for (_, b, hw), (_, _, hw2) in zip(runs, runs[1:]):
        cuts.append(b - d if hw2 < hw else b + d)  # a ledge moves a third of a cube in with the faces beside it
    cuts.append(runs[-1][1] - d)
    for (_, _, hw), za, zb in zip(runs, cuts, cuts[1:]):
        section = (-(hw - d), hw - d, za, zb)
        p.block(x - front, section, x + back, section, "lava")


def needle(p, end, d, length, colour, half=0.6):
    """an ember needle on the end of a fin ray: a spike whose base sits half a cube inside the ray's end (end: the ray's
    end in the side view, d: its direction there)"""
    (ex, ez), (dx, dz) = end, d
    cx, cz, px, pz = ex - 0.5 * dx, ez - 0.5 * dz, -half * dz, half * dx
    base = [(cx - px, -0.4, cz - pz), (cx + px, -0.4, cz + pz), (cx + px, 0.4, cz + pz), (cx - px, 0.4, cz - pz)]
    p.spike(base, (ex + length * dx, 0.0, ez + length * dz), colour)


def build(m):
    body = m.part("Body", (-3, 0, 0))
    # the head: three slabs that overhang the mouth, each a step lower and narrower toward the snout; their flat underside
    # is the mouth's roof. Then the ball: thirty-one cubes tall and twenty-five wide, with a narrow crest three cubes tall
    # that runs on down the head, and that the rider sits astride
    for spec in (H1, H2, H3, BALL):
        slab(body, spec)
    body.pair(-7, 1, 13, 14, -4, 5, "char")  # one step more at the middle of each flank, so it is round from above too
    seam(body, -10, H3, 3, back=1.5, front=0.5)  # the first seam: behind the head, down to the lip
    # the back of the mouth, seen past the teeth: the wall behind it is dark
    body.paint(-9, -8, -9, 10, -6, 1, "mouth")
    # the dark inside of the mouth: three blocks, each narrower than the teeth beside it, ending inside the head, the jaw
    # and the ball
    for x0, x1, half, za, zb in ((-23.5, -20.0, 4.5, -2.6, 5.5), (-20.3, -14.0, 6.5, -4.6, 3.5), (-14.3, -8.6, 8.5, -6.6, 1.5)):
        body.block(x0, (-half, half, za, zb), x1, (-half, half, za, zb), "mouth")
    # the gums: a thin dark plate under each slab of the head, set in from its edge; the teeth hang from it
    for x0, x1, half, z in ((-24.7, -20.8, 6.0, 5), (-20.7, -14.8, 8.0, 3), (-14.7, -8.8, 10.0, 1)):
        body.block(x0, (-half, half, z - 0.3, z + 0.3), x1, (-half, half, z - 0.3, z + 0.3), "gum")
    # the upper teeth: long ember needles leaning inward. A row across the front, then down each side, shorter toward
    # the corner of the mouth
    for y, long in ((0.0, 4.2), (2.3, 5.0), (4.6, 4.2)):
        body.tooth(-24.1, y, 4.82, 1.0, long, "tooth", mirror=y > 0, lean=(0.7, -0.12 * y))
    for x, y, z, long in ((-22.4, 5.4, 5, 4.6), (-19.9, 7.4, 3, 5.0), (-17.9, 7.4, 3, 4.6), (-15.9, 7.4, 3, 4.2),
                          (-13.7, 9.4, 1, 4.2), (-11.7, 9.4, 1, 3.6), (-9.9, 9.4, 1, 2.8)):
        body.tooth(x, y, z - 0.18, 1.0, long, "tooth", lean=(0.35, -1.0))
    # the eye: a glowing ember square with a dark pupil, low on the side of the head, under a heavy brow box that slants
    # down to the front, cuts the top of the eye and comes past it; a slimmer block carries the line on in front. The
    # brow's back end is buried in the wider slab behind
    eye = (8.2, 8.95, 4.6, 7.6)
    body.block(-19.8, eye, -16.8, eye, "ember", mirror=True)
    pupil = (8.7, 9.25, 5.0, 6.4)
    body.block(-19.3, pupil, -17.9, pupil, "black", mirror=True)
    body.beam((-20.9, 8.75, 6.95), (-14.6, 8.75, 9.2), 1.9, 2.2, "char", mirror=True)
    body.beam((-22.5, 8.6, 6.35), (-20.3, 8.6, 7.15), 1.3, 1.5, "char-", mirror=True)
    # the horn stubs: two short boxes on each corner of the head, in front of the seam and far from the seat
    body.beam((-12.7, 7.3, 10.4), (-11.9, 8.7, 14.4), 2.4, 2.1, "horn-", mirror=True)
    body.beam((-12.1, 8.3, 13.4), (-11.3, 9.5, 16.2), 1.5, 1.3, "horn", mirror=True)
    # the seat: the rider sits astride the crest, legs in a shallow slot either side of it
    body.dent(-4, -1, 3, 13, 15, "char-")

    # the jaw, on its own joint: a scoop in four slabs that step up and forward, past the snout. Its rim is dark, its
    # underside the belly's colour; the floor of the mouth is dark, inside a gum rim that the lower teeth stand on
    jaw = m.part("Jaw", (-9, 0, -6), "Body")
    for x0, x1, n, bot, under in ((-15, -9, 10, -13, [(6, 1), (2, 3)]), (-21, -15, 8, -11, [(4, 1), (2, 2)]),
                                  (-25, -21, 6, -9, [(3, 1), (1, 2)]), (-28, -25, 4, -7, [(2, 1), (1, 1)])):
        top = bot + 7
        jaw.hull(x0, x1, n, bot, top, "char", [], under)
        jaw.paint_sym(x0, x1, n, bot, EDGE, "belly")
        jaw.paint_sym(x0, x1, n, bot, bot + under[0][1], "belly-")
        jaw.paint_sym(x0, x1, n - 2, top - 1, top, "mouth")
        rim = (n - 1.4, n, top - 0.3, top + 0.3)
        jaw.block(x0 - 0.2 if n > 4 else x0 + 1.0, rim, x1 - 0.2, rim, "gum", mirror=True)
    front = (-4.2, 4.2, -0.3, 0.45)
    jaw.block(-27.6, front, -26.2, front, "gum")  # the rim goes round the chin
    # the lower teeth: four long fangs on the chin, standing in front of the face, and shorter needles along each side,
    # set between the upper ones
    for y, long in ((1.2, 5.6), (3.1, 4.4)):
        jaw.tooth(-26.9, y, 0.33, 1.1, -long, "tooth", lean=(0.9, -0.15 * y))
    for x, y, z, long in ((-23.6, 5.3, -2, 4.4), (-21.8, 5.3, -2, 4.0), (-18.9, 7.3, -4, 4.4), (-16.9, 7.3, -4, 4.0),
                          (-14.75, 9.3, -6, 3.8), (-12.7, 9.3, -6, 3.2), (-10.8, 9.3, -6, 2.6)):
        jaw.tooth(x, y, z + 0.18, 1.0, -long, "tooth", lean=(0.3, -0.9))

    # the lure: a rod from the forehead in two thin boxes, each on its own joint, then a line and the ember on a third,
    # hanging in front of the face, over the mouth. The ember is a ball the way cubes make one: a core of cubes with a
    # plate on each face, the hotter colour on the plates
    rod1 = m.part("Rod1", (-12.6, 0, 13.6), "Body")
    rod1.beam((-12.4, 0, 12.2), (-16.8, 0, 21.0), 1.8, 1.6, "char")
    rod2 = m.part("Rod2", (-16.8, 0, 21.0), "Rod1")
    rod2.beam((-16.4, 0, 20.1), (-24.6, 0, 24.6), 1.2, 1.0, "char")
    lure = m.part("Lure", (-24.6, 0, 24.6), "Rod2")
    lure.beam((-24.2, 0, 24.3), (-27.4, 0, 16.4), 0.6, 0.6, "char")
    lure.box(-29, -26, -1, 2, 13, 16, "lava")  # the core: three cubes each way
    cx, cz, a, b, out = -27.5, 14.5, 1.15, 1.0, 2.2
    for s in (1, -1):  # a hotter plate on each of its six faces, its back sunk in the core
        lure.block(cx + s * 1.2, (-a, a, cz - b, cz + b), cx + s * out, (-a, a, cz - b, cz + b), "ember")
        ya, yb = sorted((s * 1.2, s * out))
        lure.block(cx - b, (ya, yb, cz - a, cz + a), cx + b, (ya, yb, cz - a, cz + a), "ember")
        za, zb = sorted((cz + s * 1.2, cz + s * out))
        lure.block(cx - a, (-b, b, za, zb), cx + a, (-b, b, za, zb), "ember")

    # the back of the ball: five more slabs in three parts, each a step smaller, so the ball closes into the tail and the
    # back end swings. A lava seam behind the ball and one on the tail stock; the hidden sleeves are lava too, so a joint
    # glows when it opens
    b2 = m.part("B2", (3, 0, 0), "Body")
    slab(b2, B2)
    seam(b2, 3, B2, EDGE, core=(7, 8))
    b2.sym(2, 3, 7, -10, 8, "lava-")
    b3 = m.part("B3", (8, 0, 0), "B2")
    slab(b3, B3)
    b3.sym(7, 8, 5, -8, 7, "lava-")
    b4 = m.part("B4", (13, 0, 0), "B3")
    for spec in (B4, B5, B6):
        slab(b4, spec)
    seam(b4, 13, B4, -3, core=(4, 5))
    b4.sym(12, 13, 4, -5, 5, "lava-")
    # the low fins, far back: one above and one below, two small boxes each
    for up in (1, -1):
        b3.beam((10.2, 0, 0.5 + up * 9.2), (13.4, 0, 0.5 + up * 14.4), 4.2, 1.6, "char-")
        b3.beam((12.6, 0, 0.5 + up * 13.2), (15.0, 0, 0.5 + up * 16.8), 2.7, 1.0, "char")

    # the side fins: weak little paddles on their own joints, behind the widest part, swept back
    for name, side in (("FinR", 1), ("FinL", -1)):
        fin = m.part(name, (5.0, side * 10.0, -3.0), "B2")
        fin.beam((4.4, side * 8.6, -2.8), (9.8, side * 14.4, -4.3), 5.2, 1.8, "char-", flat="z")
        fin.beam((8.6, side * 13.2, -4.0), (11.8, side * 16.6, -4.9), 3.6, 1.2, "char", flat="z")

    # the tail, on its own joint: a short stalk and a small fan: a thin web with three rays on it, each ending in an ember
    # needle that stands out past the web: the teeth's echo
    tail = m.part("Tail", (22, 0, 0.5), "B4")
    tail.beam((21.2, 0, 0.5), (24.6, 0, 0.5), 4.4, 2.8, "char")
    tail.prism([(23.8, -1.6), (28.0, -5.2), (28.0, 6.2), (23.8, 2.6)], -0.3, 0.3, "char")
    for up in (1, -1):
        tail.beam((23.4, 0, 0.5 + up * 1.4), (28.2, 0, 0.5 + up * 5.6), 2.2, 1.5, "char-")
        needle(tail, (28.2, 0.5 + up * 5.6), (0.753, up * 0.659), 2.6, "tooth")
    tail.beam((23.8, 0, 0.5), (29.0, 0, 0.5), 2.0, 1.1, "char-")
    needle(tail, (29.0, 0.5), (1.0, 0.0), 2.8, "tooth")
