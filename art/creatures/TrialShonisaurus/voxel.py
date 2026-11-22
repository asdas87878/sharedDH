"""Shonisaurus, a trial of docs/style/10-sharks-round-2.md, for tools/blender/voxel_kit.py. It stands beside the game's
Shonisaurus (art/creatures/Shonisaurus) and replaces nothing. Designed from the real animal: an ichthyosaur, not a shark.
Its idea: the leviathan dolphin. A huge deep round body on a short beak, and a face that is all eye.
- The body in numbers: about 80 cubes long; 23 cubes deep (0.29 of the length) and 19 wide, a barrel that is rounder
  than the old model's log. It swells fast behind the head, holds its depth over the chest and tapers through a long
  narrow stock to a big crescent tail. The belly hangs further below the middle than the back rises above it.
- The slices change one thing by one cube at a time (width, belly or back), worked out from three smooth outlines, so
  the side, top and front views each make their own broad staircase.
- The face: an ichthyosaur's huge eye, a third of the head's height: a dark socket, a cream bony ring, a soft gold iris
  (the only glow) and a big dark pupil with a light in it. Under it a long thin mouth, a dark line between a peach upper
  jaw and a cream lower one, running from the corner under the eye to the tip of a short beak. No teeth: a calm giant.
- Four long paddle flippers, each three boxes swept back and down, the hind pair nearly as long as the front (as in the
  real animal). A small back fin behind the rider. A tall crescent tail whose lower lobe (the backbone's) is the longer.
- Colour: sandstone peach over cream, the line coming out of the mouth, dipping under the chest and rising to the tail.
- The one mark: three long claw scars raked down the flank, behind the rider, in dark red-brown.
The rider sits on the highest, widest part of the back, its legs over the broad steps either side."""
import math

NAME, ZONE, RARITY = "Shonisaurus (trial)", "ZONE 6 / TWILIGHT", "LEGENDARY"
U = 0.5
PALETTE = {"peach": "#EBA373", "cream": "#F8EDD6", "scar": "#7A372B", "black": "#1D1A1F", "iris": "#FFD48A"}
SHADE = 0.9
SEAT = (0, 12, 9.5)
GLOW = {"iris": 0.4}  # only the eye's iris
TEXTURES = [{"tile": "stud", "on": "top", "colours": ["peach"]}]
FRAME, ORTHO, ORTHO_SWIM = 3.2, 46.0, 50.0

BODY_FROM, BODY_TO = -16, 30
SKULL_END = (6, -8, 7)  # the skull's last slice: (cubes out, bottom, top)
# three smooth outlines (x, value): the body's slices follow them, one cube of one of them at a time
TOP = ((-16, 7), (-10, 10), (-3, 11.8), (3, 11.8), (10, 10), (18, 7), (25, 4.4), (30, 2.5))
BOT = ((-16, -8), (-10, -12.6), (-4, -15.3), (4, -15.3), (10, -13), (17, -9), (24, -5.6), (30, -3))
OUT = ((-16, 6), (-10, 8.3), (-5, 9), (5, 9), (12, 7.6), (20, 5), (30, 2))
# the pieces the body is cut into, (name, from x): the chest is stiff, the joints come closer toward the tail
PIECES = (("Chest", -16), ("S2", 9), ("S3", 14), ("S4", 18), ("S5", 22), ("Tail", 26))
CHAIN = ["Head"] + [name for name, _ in PIECES]
AMPLITUDES = [1.5, 2.5, 4.0, 6.0, 9.0, 13.0]


def curve(keys, x):
    """the outline's value at x: straight between its keys, eased at each end so it swells and tapers smoothly"""
    for (xa, va), (xb, vb) in zip(keys, keys[1:]):
        if xa <= x <= xb:
            t = (x - xa) / (xb - xa)
            return va + (vb - va) * (0.5 - 0.5 * math.cos(math.pi * t))
    return keys[-1][1]


def body_columns():
    """one (n, bottom, top) per cube column: each column changes at most one of them by one cube, the one furthest from
    its outline, and only every second column unless one has fallen a whole cube behind (so the steps stay broad)"""
    n, bot, top = SKULL_END
    cols, since = [], 2
    for x in range(BODY_FROM, BODY_TO):
        want = (curve(OUT, x + 0.5), curve(BOT, x + 0.5), curve(TOP, x + 0.5))
        have = [n, bot, top]
        gaps = [w - h for w, h in zip(want, have)]
        k = max(range(3), key=lambda i: abs(gaps[i]))
        since += 1
        if abs(gaps[k]) >= 1.0 or (abs(gaps[k]) >= 0.5 and since >= 2):
            have[k] += 1 if gaps[k] > 0 else -1
            since = 0
        n, bot, top = have
        cols.append((x, n, bot, top))
    return cols


def body_slices():
    """the columns merged into slices (x0, x1, n, bottom, top), cut where a piece starts"""
    starts = {x for _, x in PIECES}
    out = []
    for x, n, bot, top in body_columns():
        if out and out[-1][2:] == (n, bot, top) and x not in starts:
            out[-1] = (out[-1][0], x + 1, n, bot, top)
        else:
            out.append((x, x + 1, n, bot, top))
    return out


# the line between the peach back and the cream belly: cream below this height. It leaves the mouth, dips under the
# chest and rises to the tail in broad steps
LINE = {}
for _x in range(-30, 32):
    LINE[_x] = (-3 if _x < -16 else -4 if _x < -12 else -5 if _x < -8 else -6 if _x < 8 else -5 if _x < 12 else -4 if _x < 16
                else -3 if _x < 20 else -2 if _x < 24 else -1)


def steps(n):
    """the corners of the back and the belly: a barrel's broad steps where the body is thick, fewer as it thins"""
    if n >= 8:
        return [(4, 1), (2, 1), (1, 2)]
    return [(3, 1), (2, 1), (1, 1)] if n >= 6 else ([(2, 1), (1, 1)] if n >= 4 else [(1, 1)])


def clear(st):
    return sum(tall for _, tall in st)


def slab(p, x0, x1, n, bot, top, top_st=None, bot_st=None):
    """a slice of body: stepped corners, peach with a lighter top row, cream below the line with a darker bottom row"""
    top_st = steps(n) if top_st is None else top_st
    bot_st = steps(n) if bot_st is None else bot_st
    p.hull(x0, x1, n, bot, top, "peach", top_st, bot_st)
    p.paint_sym(x0, x1, n, top - 1, top, "peach+")
    for x in range(x0, x1):
        p.paint_sym(x, x + 1, n, bot, LINE[x], "cream")
    if bot_st:
        p.paint_sym(x0, x1, n, bot, bot + 1, "cream-")


class Plate:
    """a jaw block lying across the head from (x0, z0) to (x1, z1) in the side view (from TrialGreatWhite)"""

    def __init__(self, x0, z0, x1, z1, wide, thick):
        self.x0, self.z0, self.x1, self.z1, self.wide, self.thick = x0, z0, x1, z1, wide, thick
        self.slope = (z1 - z0) / (x1 - x0)
        self.up = math.sqrt(1 + self.slope ** 2)

    def add(self, part, colour):
        part.beam((self.x0, 0, self.z0), (self.x1, 0, self.z1), self.wide, self.thick, colour, flat="z")


def mouth_z(x):
    """the mouth's line: it climbs gently from the beak's tip to the corner under the eye, a calm smile"""
    return -3.6 + (x + 38.6) * 0.8 / 17.6


def edge_plate(x0, x1, wide, thick, side):
    """a jaw block whose edge runs along the mouth's line: an upper one (side 1) has its underside there, a lower one
    (side -1) its top. Each closes toward the line along its length (0.5 off it at the back, 0.3 at the front), so the
    next block, starting inside it, starts a little further off and its root is buried in this one"""
    za, zb = mouth_z(x0) + side * 0.5, mouth_z(x1) + side * 0.3
    slope = (zb - za) / (x1 - x0)
    lift = side * thick / 2 * math.sqrt(1 + slope ** 2)
    return Plate(x0, za + lift, x1, zb + lift, wide, thick)


def upper(x0, x1, wide, thick):
    return edge_plate(x0, x1, wide, thick, 1)


def lower(x0, x1, wide, thick):
    return edge_plate(x0, x1, wide, thick, -1)


def build(m):
    head = m.part("Head", (BODY_FROM, 0, 0))
    # the skull behind the mouth's corner: deep, flat on the flank where the eye sits
    head_top = [(2, 1), (1, 1)]
    slab(head, -23, -21, 6, -7, 7, head_top)
    slab(head, -21, BODY_FROM, 6, -8, 7, head_top)
    # the head above the mouth: flat underneath (the upper jaw covers it), the forehead stepping down to the beak
    for x0, x1, n, top in ((-25, -23, 6, 7), (-27, -25, 6, 6), (-29, -27, 5, 6)):
        head.hull(x0, x1, n, -2, top, "peach", head_top, [])
        head.paint_sym(x0, x1, n, top - 1, top, "peach+")
    # the forehead: one block sloping from the brow down onto the beak
    head.beam((-25.0, 0, 4.4), (-31.0, 0, 2.0), 8.0, 2.4, "peach+", flat="z")

    # THE MOUTH: a short beak of upper blocks over cream lower ones, each smaller than the one behind it and starting
    # inside it, closing to a point; a dark line between them from the tip to the corner under the eye
    for plate in (upper(-21.4, -28.6, 12.4, 1.6), upper(-28.0, -33.6, 8.6, 4.4), upper(-33.0, -37.0, 6.4, 3.2),
                  upper(-36.4, -38.6, 4.4, 2.2)):
        plate.add(head, "peach")
    for plate in (lower(-20.4, -28.0, 10.6, 2.8), lower(-27.4, -33.8, 7.8, 2.4), lower(-33.2, -37.4, 5.6, 1.7),
                  lower(-36.8, -38.3, 3.6, 1.1)):
        plate.add(head, "cream")
    zb, zf = mouth_z(-21.0), mouth_z(-38.2)
    head.block(-21.0, (-5.0, 5.0, zb - 0.75, zb + 0.75), -38.2, (-1.3, 1.3, zf - 0.6, zf + 0.6), "scar")
    head.paint(-23, -22, -6, 7, -3, -2, "scar")  # the corner of the mouth, one cube into the cheek

    # THE EYE: huge, a third of the head's height. A dark socket, a cream bony ring, a soft gold iris and a big pupil,
    # each standing a little out of the last, and a light in the pupil
    for (xa, xb, za, zb2), (ya, yb), colour in (((-22.9, -16.3, -2.3, 4.6), (6.3, 6.75), "peach-"),
                                                 ((-22.4, -16.9, -1.7, 4.0), (6.6, 7.0), "cream"),
                                                 ((-21.8, -17.5, -1.1, 3.4), (6.85, 7.2), "iris"),
                                                 ((-21.2, -18.1, -0.5, 2.8), (7.05, 7.45), "black"),
                                                 ((-20.9, -19.9, 1.6, 2.6), (7.3, 7.6), "cream")):
        head.block(xa, (ya, yb, za, zb2), xb, (ya, yb, za, zb2), colour, mirror=True)

    # the body: slices on the outlines, in pieces on their own joints
    segs, before = {}, SKULL_END
    slices = body_slices()
    starts = [x for _, x in PIECES] + [BODY_TO]
    for i, (name, x_from) in enumerate(PIECES):
        seg = segs[name] = m.part(name, (x_from, 0, 0), CHAIN[i])
        mine = [s for s in slices if x_from <= s[0] < starts[i + 1]]
        for s in mine:
            slab(seg, *s)
        # a sleeve into the piece in front, so a bending joint shows body: sized from the smaller of the two pieces and
        # kept clear of both pieces' corner steps
        _, _, n, bot, top = mine[0]
        fn, fbot, ftop = before
        gap = max(clear(steps(n)), clear(steps(fn)))
        seg.sym(x_from - 1, x_from, max(min(n, fn) - 2, 0), max(bot, fbot) + gap, min(top, ftop) - gap, "peach-")
        before = mine[-1][2:]
    chest, s2, tail = segs["Chest"], segs["S2"], segs["Tail"]

    # the seat: on the highest, widest slice; the back is broad enough that the legs need no slot

    # THE MARK: three long claw scars raked down the flank behind the rider, standing a little proud of it
    for x_top in (-1.3, 1.5, 4.3):
        chest.beam((x_top, 9.55, 5.4), (x_top + 4.0, 9.55, -6.8), 1.1, 0.5, "scar", mirror=True)

    # the small back fin, behind the rider: two boxes leaning back, the second smaller, thinner and darker
    s2.beam((9.6, 0, 9.4), (12.8, 0, 13.0), 4.0, 1.4, "peach")
    s2.beam((12.1, 0, 12.4), (14.1, 0, 14.2), 2.2, 0.9, "peach-")

    # the four paddle flippers: long, each on its own joint, three boxes swept out, down and back, each smaller and
    # thinner than the last and starting inside it. The hind pair is nearly as long as the front
    front = (((-12.6, 5.6, -8.2), (-7.6, 11.2, -11.4), 4.6, 1.6, "peach"), ((-8.4, 10.3, -10.9), (-2.4, 15.6, -13.8), 4.0, 1.1, "peach"),
             ((-3.2, 14.9, -13.4), (0.6, 17.8, -15.0), 2.8, 0.65, "peach-"))
    hind = (((9.8, 4.2, -8.3), (13.6, 8.8, -11.0), 3.9, 1.4, "peach"), ((13.0, 8.1, -10.6), (17.8, 12.4, -13.0), 3.4, 1.0, "peach"),
            ((17.2, 11.8, -12.7), (20.4, 14.2, -14.0), 2.4, 0.6, "peach-"))
    for tag, boxes, parent, pivot in (("F", front, "Chest", (-11.6, 6.4, -8.8)), ("H", hind, "S2", (10.6, 5.0, -8.8))):
        for letter, side in (("R", 1), ("L", -1)):
            part = m.part(f"Flipper{tag}{letter}", (pivot[0], pivot[1] * side, pivot[2]), parent)
            for p0, p1, wide, thick, colour in boxes:
                part.beam((p0[0], p0[1] * side, p0[2]), (p1[0], p1[1] * side, p1[2]), wide, thick, colour, flat="z")

    # the tail: a crescent of two lobes off the stock, each three boxes sweeping back. The lower lobe carries the
    # backbone and is the longer
    tail.sym(29, 32, 1, -2, 2, "peach")
    tail.beam((30.0, 0, 0.8), (34.4, 0, 6.2), 4.4, 1.4, "peach")
    tail.beam((33.7, 0, 5.3), (37.4, 0, 9.8), 3.2, 1.0, "peach")
    tail.beam((36.9, 0, 9.0), (39.2, 0, 12.0), 2.0, 0.6, "peach-")
    tail.beam((30.0, 0, -1.2), (35.0, 0, -7.2), 4.6, 1.8, "peach")
    tail.beam((34.2, 0, -6.3), (38.6, 0, -11.2), 3.3, 1.1, "peach")
    tail.beam((38.1, 0, -10.5), (40.8, 0, -13.8), 2.1, 0.6, "peach-")


def pose(parts, phase):
    """a slow wave from side to side that grows toward the tail, the head turning a little against it; the four
    flippers row gently, the hind pair half a beat after the front"""
    parts["Head"].rotation_euler.z = math.radians(1.5) * math.sin(phase + math.pi)
    for k, name in enumerate(CHAIN[1:]):
        parts[name].rotation_euler.z = math.radians(AMPLITUDES[k]) * math.sin(phase - 0.6 * (k + 1))
    for name, side, late in (("FlipperFR", 1, 0.0), ("FlipperFL", -1, 0.0), ("FlipperHR", 1, 1.6), ("FlipperHL", -1, 1.6)):
        parts[name].rotation_euler.x = side * math.radians(10) * math.sin(phase - 0.8 - late)
        parts[name].rotation_euler.z = side * math.radians(6) * math.sin(phase - 1.8 - late)


if __name__ == "__main__":
    for s in body_slices():
        print(s)
