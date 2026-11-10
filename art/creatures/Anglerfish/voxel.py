"""Anglerfish (zone 7's Epic: the deep-sea angler) for tools/blender/voxel_kit.py (docs/style/04-voxel-style.md), dressed
as an Epic by docs/style/05-rarity-look.md. The first bulbous body.
Its idea: a dark ball of mouth that carries its own lamp. Everything on it is dull and plain, so the one light and the cage
of needle teeth under it are all you see.
- The body is a ball: stacks of stepped slabs, widest and tallest in the middle, one step in at a time to the front and
  the back. It is mostly head. Dark skin, a duller belly below one line.
- The mouth takes the whole front: the snout overhangs it, and the lower jaw (its own part) is a scoop that steps up and
  forward past the snout, an underbite. Long needle teeth hang from the snout and stand on the jaw, leaning inward; the
  longest stand on the chin, in front of the face.
- The rod grows from the forehead in two thin boxes, each on its own joint, and a bulb hangs from its end in front of the
  face on a third. The bulb is the only thing that glows.
- The eyes are tiny and milky, with a dark pupil, high on the shoulder of the snout.
- The fins are small and weak and set far back: a paddle each side on its own joint, a low fin above and below, and a
  short fan of a tail whose rays end in pale needles: the teeth's echo.
The rider sits astride the narrow crown of the ball, legs in a shallow slot either side."""
import math

NAME, ZONE, RARITY = "Anglerfish", "ZONE 7 / MIDNIGHT", "EPIC"
U = 0.58
PALETTE = {"skin": "#43354A", "belly": "#6B4A57", "tooth": "#F3EEDC", "mouth": "#2B0E15", "black": "#141216", "eye": "#A9ADB8",
           "lure": "#A6F53A"}
SEAT = (-3, 8, 2.96)
GLOW = {"lure": 0.9}  # the one glowing thing: the bulb of the lure
LIGHTS = [("Lure", (-13.4, 0, 7.0), "#A6F53A", 45, 0.5)]
FRAME, ORTHO = 1.75, 23.0

# the corner steps of a slab, by how far out it reaches: (cubes in from the side, cubes tall), from the top down
STEPS = {5: [(3, 1), (1, 2)], 4: [(2, 1), (1, 1)], 3: [(2, 1), (1, 1)]}
EDGE = -4  # the belly's colour stops at this height the whole way along, so its edge is one line


def pose(parts, phase):
    """a slow waddle: the ball rolls and yaws a little and the short back end swings wide behind it; the fins flutter,
    weakly, twice a beat; the jaw gulps once a beat; the lure sways late, each joint later than the one before"""
    s = math.sin
    parts["Body"].rotation_euler.x = math.radians(4) * s(phase)
    parts["Body"].rotation_euler.z = math.radians(3) * s(phase + math.pi)
    for name, amp, lag in (("B2", 6, 0.7), ("B3", 10, 1.4), ("Tail", 18, 2.1)):
        parts[name].rotation_euler.z = math.radians(amp) * s(phase - lag)
    parts["Jaw"].rotation_euler.y = -math.radians(9) * (0.5 + 0.5 * s(phase - 0.6))
    for name, side in (("FinR", 1), ("FinL", -1)):
        parts[name].rotation_euler.z = side * math.radians(14) * s(2 * phase)
        parts[name].rotation_euler.x = side * math.radians(8) * s(2 * phase - 1.0)
    parts["Rod1"].rotation_euler.x = math.radians(7) * s(phase - 1.2)
    parts["Rod1"].rotation_euler.y = math.radians(4) * s(phase - 1.0)
    parts["Rod2"].rotation_euler.x = math.radians(9) * s(phase - 2.0)
    parts["Rod2"].rotation_euler.y = math.radians(5) * s(phase - 1.8)
    parts["Lure"].rotation_euler.x = math.radians(16) * s(phase - 2.9)
    parts["Lure"].rotation_euler.y = math.radians(9) * s(phase - 2.6)


def slab(p, x0, x1, n, bot, top, steps=None, under=None):
    """a slice of the ball: stepped corners above and below (under: the steps below, [] for a flat underside), lighter
    on the top row, the duller belly below the line"""
    steps = STEPS[n] if steps is None else steps
    under = steps if under is None else under
    p.hull(x0, x1, n, bot, top, "skin", steps, under)
    p.paint_sym(x0, x1, n, top - 1, top, "skin+")
    if under:
        p.paint_sym(x0, x1, n, bot, EDGE, "belly")
        p.paint_sym(x0, x1, n, bot, bot + len(under) - 1, "belly-")


def needle(p, end, d, length, colour):
    """a pale needle on the end of a fin ray: a spike whose base sits half a cube inside the ray's end (end: the ray's
    end in the side view, d: its direction there)"""
    (ex, ez), (dx, dz) = end, d
    cx, cz, px, pz = ex - 0.5 * dx, ez - 0.5 * dz, -0.45 * dz, 0.45 * dx
    base = [(cx - px, -0.3, cz - pz), (cx + px, -0.3, cz + pz), (cx + px, 0.3, cz + pz), (cx - px, 0.3, cz - pz)]
    p.spike(base, (ex + length * dx, 0.0, ez + length * dz), colour)


def build(m):
    body = m.part("Body", (-2.5, 0, 0))
    # the snout: two slabs that overhang the mouth, each a step lower and narrower; their flat underside is the mouth's roof
    slab(body, -11, -9, 4, 2, 6, under=[])
    slab(body, -9, -6, 5, 1, 7, under=[])
    # the ball itself: sixteen cubes tall and thirteen wide, with a narrow crown two cubes tall that the rider sits astride
    slab(body, -6, 1, 6, -8, 8, [(4, 2), (2, 1), (1, 2)], [(4, 1), (2, 1), (1, 2)])
    body.pair(-5, 0, 7, 8, -2, 2, "skin")  # and one step more at the middle of each flank, so it is round from above too
    # the back of the mouth, seen past the teeth: the wall behind it is dark
    body.paint(-6, -5, -5, 6, -3, 1, "mouth")
    # the dark inside of the mouth: two blocks, narrower than the teeth, ending inside the snout, the jaw and the ball
    inside = (-4.3, 4.3, -3.6, 1.5)
    body.block(-8.8, inside, -5.6, inside, "mouth")
    inside = (-3.3, 3.3, -3.3, 2.3)
    body.block(-10.15, inside, -8.5, inside, "mouth")
    # the upper teeth: long needles hanging from the snout, leaning inward. A row across the front, then down each side
    for y, long in ((0.0, 2.4), (1.4, 2.8), (2.8, 2.5)):
        body.tooth(-10.55, y, 2.12, 0.5, long, "tooth", mirror=y > 0, lean=(0.35, -0.12 * y))
    for x, y, z, long in ((-9.75, 4.0, 2.12, 2.7), (-8.5, 5.0, 1.12, 2.7), (-7.2, 5.0, 1.12, 2.2)):
        body.tooth(x, y, z, 0.5, long, "tooth", lean=(0.2, -0.55))
    # the eyes: tiny and milky, a dark pupil, high on the shoulder of the snout
    ring = (4.2, 4.8, 3.8, 5.4)
    body.block(-8.7, ring, -7.3, ring, "eye", mirror=True)
    pupil = (4.6, 5.0, 4.35, 5.05)
    body.block(-8.35, pupil, -7.65, pupil, "black", mirror=True)
    # the seat: the rider sits astride the crown, legs in a shallow slot either side of it
    body.dent(-4, -2, 2, 6, 7, "skin-")

    # the jaw, on its own joint: a scoop in three slabs that step up and forward, past the snout. Its rim is dark, its
    # underside the belly's colour; the floor of the mouth is dark where it shows
    jaw = m.part("Jaw", (-6, 0, -3), "Body")
    for x0, x1, n, bot in ((-9, -6, 5, -7), (-11, -9, 4, -6), (-13, -11, 3, -5)):
        jaw.hull(x0, x1, n, bot, bot + 4, "skin", [], [(3, 1), (1, 1)] if n == 5 else [(2, 1), (1, 1)])
        jaw.paint_sym(x0, x1, n, bot, EDGE, "belly")
        jaw.paint_sym(x0, x1, n, bot, bot + 1, "belly-")
    jaw.paint(-11, -9, -3, 4, -3, -2, "mouth")
    # the lower teeth: four long fangs on the chin, standing in front of the face, and shorter needles along each side,
    # set between the upper ones
    for y, long in ((0.95, 3.1), (2.6, 2.6)):
        jaw.tooth(-12.15, y, -1.12, 0.6, -long, "tooth", lean=(0.55, -0.15 * y))
    for x, y, z, long in ((-10.4, 3.9, -2.12, 2.7), (-7.85, 4.9, -3.12, 2.6), (-6.65, 4.9, -3.12, 2.0)):
        jaw.tooth(x, y, z, 0.5, -long, "tooth", lean=(0.2, -0.5))

    # the lure: a rod from the forehead in two thin boxes, each on its own joint, then a line and the bulb on a third,
    # hanging in front of the face, over the mouth
    rod1 = m.part("Rod1", (-7.3, 0, 6.6), "Body")
    rod1.beam((-7.2, 0, 5.6), (-9.2, 0, 10.4), 0.9, 0.8, "skin")
    rod2 = m.part("Rod2", (-9.2, 0, 10.4), "Rod1")
    rod2.beam((-9.0, 0, 9.9), (-12.6, 0, 12.2), 0.6, 0.5, "skin")
    lure = m.part("Lure", (-12.6, 0, 12.2), "Rod2")
    lure.beam((-12.35, 0, 12.04), (-13.4, 0, 7.5), 0.3, 0.3, "skin")
    bulb = (-0.9, 0.9, 6.1, 7.9)
    lure.block(-14.3, bulb, -12.5, bulb, "lure")
    tip = (-0.5, 0.5, 5.55, 6.3)
    lure.block(-13.9, tip, -12.9, tip, "lure")

    # the back of the ball: four more slabs, each one step smaller and the last two short, so the ball closes quickly
    # into the tail. In two parts, so the back end swings
    b2 = m.part("B2", (1, 0, 0), "Body")
    slab(b2, 1, 3, 5, -7, 7)
    b2.sym(0, 1, 3, -5, 5, "skin-")  # a sleeve into the ball, clear of its steps
    b3 = m.part("B3", (3, 0, 0), "B2")
    slab(b3, 3, 5, 4, -6, 6)
    slab(b3, 5, 6, 3, -5, 5)
    slab(b3, 6, 7, 3, -4, 4)
    b3.sym(2, 3, 2, -4, 4, "skin-")
    # the low fins, far back: one above and one below, two small boxes each
    for up in (1, -1):
        b3.beam((4.0, 0, up * 4.8), (5.6, 0, up * 7.0), 2.2, 0.9, "skin-")
        b3.beam((5.2, 0, up * 6.45), (6.3, 0, up * 7.9), 1.4, 0.6, "skin")

    # the side fins: weak little paddles on their own joints, behind the widest part, swept back
    for name, side in (("FinR", 1), ("FinL", -1)):
        fin = m.part(name, (2.2, side * 5.0, -1.6), "B2")
        fin.beam((2.0, side * 4.4, -1.5), (4.6, side * 7.0, -2.2), 2.6, 0.9, "skin-", flat="z")
        fin.beam((4.0, side * 6.4, -2.04), (5.5, side * 7.9, -2.45), 1.8, 0.6, "skin", flat="z")

    # the tail, on its own joint: a short stalk and a small fan: a thin web with three rays on it, each ending in a pale
    # needle that stands out past the web: the teeth's echo
    tail = m.part("Tail", (7, 0, 0), "B3")
    tail.beam((6.4, 0, 0), (9.8, 0, 0), 5.0, 3.2, "skin")
    tail.prism([(9.0, -2.0), (12.5, -3.6), (12.5, 3.6), (9.0, 2.0)], -0.25, 0.25, "skin")
    for up in (1, -1):
        tail.beam((8.8, 0, up * 1.2), (12.6, 0, up * 4.2), 2.0, 1.4, "skin-")
        needle(tail, (12.6, up * 4.2), (0.785, up * 0.62), 2.2, "tooth-")
    tail.beam((9.0, 0, 0), (13.6, 0, 0), 1.8, 1.0, "skin-")
    needle(tail, (13.6, 0.0), (1.0, 0.0), 2.4, "tooth-")
