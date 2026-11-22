"""The Frilled Shark, a trial of docs/style/10-sharks-round-2.md, for tools/blender/voxel_kit.py. It stands beside the
game's Frilled Shark (art/creatures/FrilledShark) and replaces nothing. Designed from the real animal.
Its idea: the serpent with a collar.
- The body idea in numbers: about 64 cubes long. The body behind the collar is one even tube, 7 wide and 7 deep (0.11 of
  the length), with no taper at all until the back third; then it narrows a cube at a time to the tail. All the fins
  but the small side paddles sit in the back third: belly fins, a big anal fin and a small back fin over it, and a long
  low tail with a broad lower lobe.
- The head is a lizard's, a sixth of the length: flat on top, wider than the neck (11 cubes across the jaw hinges against
  the body's 7), a spade seen from above. The mouth is at the very front and wide: the upper and lower jaws reach the
  same tip, hanging slightly open, the gape running straight back past the eye. Rows of small three-pointed teeth top
  and bottom, a second row inside the front, a pink gum line inside both lips. A big dark eye under a low brow that
  comes past it.
- Colour: cocoa brown over sand. The line between them is low and straight, the same height from the lip to the tail.
- The one mark: a bright red collar of six gill frills that wraps right round the throat, each ring standing out and
  leaning back like a ruff, each smaller than the one before.
The rider sits on the even back behind the collar, legs in a slot either side."""
import math

NAME, ZONE, RARITY = "Frilled Shark (trial)", "ZONE 7 / MIDNIGHT", "EPIC"
U = 0.4
PALETTE = {"cocoa": "#7E4B32", "sand": "#E8CE9C", "frill": "#EE3428", "mouth": "#561820", "gum": "#B4485C", "tooth": "#FFFDF4",
           "black": "#16181C"}
SHADE = 0.9
SEAT = (-8.5, 4, 3.5)
FRAME, ORTHO, ORTHO_SWIM = 2.05, 29.0, 31.0
TEXTURES = [{"tile": "stud", "on": "top", "colours": ["cocoa"], "parts": ["Head", "Collar"]}]

# the body behind the head: (name, from, to, cubes out, bottom, top). One number changes from slice to slice. The collar,
# the deep throat, then one even tube to x = 10, then the back third narrows to the tail
SLICES = (("Collar", -21, -16, 4, -4, 4), ("S1", -16, -11, 3, -4, 4), ("S2", -11, -6, 3, -3, 4), ("S3", -6, -1, 3, -3, 4),
          ("S4", -1, 4, 3, -3, 4), ("S5", 4, 10, 3, -3, 4), ("S6", 10, 14, 3, -3, 3), ("S7", 14, 17, 2, -3, 3),
          ("S8", 17, 20, 2, -2, 3), ("S9", 20, 23, 2, -2, 2))
NAMES = [s[0] for s in SLICES]
SWIM = {"chain": ["Head"] + NAMES + ["Tail", "TailTip"], "amplitudes": [2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 13, 15],
        "phaseStep": 0.55, "headCounter": 2}
DROP = 0.25  # how far a gum plate shows past its lip


def steps(n):
    """(top, bottom) corner steps: the head has one broad step on top (a flat lizard's skull), the tube two, thin ones one"""
    if n >= 5:
        return [(2, 1)], [(2, 1), (1, 1)]
    if n >= 3:
        return [(2, 1), (1, 1)], [(2, 1), (1, 1)]
    return [(1, 1)], [(1, 1)]


def slab(p, x0, x1, n, bot, top):
    """a slice of body: stepped corners, a lighter top row, sand below the low straight line (z = 0)"""
    up, down = steps(n)
    p.hull(x0, x1, n, bot, top, "cocoa", up, down)
    p.paint_sym(x0, x1, n, top - 1, top, "cocoa+")
    p.paint_sym(x0, x1, n, bot, 0, "sand")


def trident(p, x, y, z, size, length, spread="x", mirror=True):
    """a three-pointed tooth: a long middle point and two short side points along the jaw (spread "x") or across the
    front ("y"). The side points' bases sit 0.2 deeper in the gum so no two bases share a plane"""
    p.tooth(x, y, z, size, length, "tooth", mirror)
    sgn = 1 if length > 0 else -1
    small, d = 0.6 * size, 0.5 * size + 0.1
    for k in (-1, 1):
        if spread == "x":
            p.tooth(x + k * d, y, z + 0.2 * sgn, small, 0.5 * length + 0.2 * sgn, "tooth", mirror)
        else:
            p.tooth(x, y + k * d, z + 0.2 * sgn, small, 0.5 * length + 0.2 * sgn, "tooth", mirror)


def frill_ring(p, xs, ztop, out, back, thick):
    """one gill frill: plates standing out of the collar and leaning back, down each flank, round the corners and under
    the throat, so the ring wraps the throat. Each plate's root is buried 1.2 inside the collar"""
    segs = (((4.5, ztop), (4.5, -2.0), True), ((4.5, -2.0), (2.5, -4.0), True), ((2.5, -4.0), (-2.5, -4.0), False))
    for (ya, za), (yb, zb), mirror in segs:
        ty, tz = yb - ya, zb - za
        span = math.hypot(ty, tz)
        ty, tz = ty / span, tz / span
        ny, nz = -tz, ty  # the outward normal (the path runs clockwise seen from the front)
        if ya == 4.5 and yb == 4.5:
            ny, nz = 1.0, 0.0
        my, mz = (ya + yb) / 2, (za + zb) / 2
        root = (xs, my - 1.2 * ny, mz - 1.2 * nz)
        tip = (xs + back, my + out * ny, mz + out * nz)
        along = [b - a for a, b in zip(root, tip)]
        length = math.sqrt(sum(v * v for v in along))
        along = [v / length for v in along]
        wide = (0.0, ty, tz)
        thin = (along[1] * wide[2] - along[2] * wide[1], along[2] * wide[0] - along[0] * wide[2], along[0] * wide[1] - along[1] * wide[0])
        centre = [(a + b) / 2 for a, b in zip(root, tip)]
        p._oriented(centre, along, wide, thin, (length, span + 0.85 * out, thick), "frill", mirror)


def build(m):
    head = m.part("Head", (-21, 0, 0))
    # the jaw hinges: the widest part of the head, a flat plateau on top with one broad step, so the head reads as a spade
    # from above. The gape runs straight back into it, past the eye
    slab(head, -25, -21, 5, -4, 4)
    head.paint(-25, -24, -5, 6, -3, -1, "mouth")
    head.paint(-24, -23, -5, 6, -2, -1, "mouth")

    # the snout: three blocks in a chain, each a step lower and narrower and starting inside the last, so from above the
    # head narrows to a rounded spade's tip. Each has a sand lip plate underneath and a thin pink gum plate set in from
    # the lip's edge (each gum starts in front of the lip before it)
    blocks = ((-24.6, -27.6, 1.6, 1.2, 9.4, 3.6, -24.8), (-27.0, -29.6, 1.1, 0.7, 7.4, 2.8, -27.75), (-29.0, -31.0, 0.3, 0.1, 5.2, 2.2, -29.75))

    def middle(b, x):
        x0, x1, z0, z1 = b[:4]
        return z0 + (z1 - z0) * (x - x0) / (x1 - x0)

    def lip_bottom(b, x):
        return middle(b, x) - b[5] / 2 - 0.8

    for b in blocks:
        x0, x1, z0, z1, wide, thick, gum_from = b
        head.beam((x0, 0, z0), (x1, 0, z1), wide, thick, "cocoa", flat="z")
        lip = thick / 2 + 0.4
        head.beam((x0, 0, z0 - lip), (x1, 0, z1 - lip), wide - 0.4, 0.8, "sand", flat="z")
        mid = 0.025 - DROP / 2
        head.beam((gum_from, 0, lip_bottom(b, gum_from) + mid), (x1 + 0.3, 0, lip_bottom(b, x1 + 0.3) + mid), wide - 1.4, DROP + 0.05,
                  "gum", flat="z")
    rise = blocks[0][5] / 2 + 0.2  # a lighter plate on top of the first block: the flat crown of the skull runs forward
    head.beam((-24.6, 0, middle(blocks[0], -24.6) + rise), (-27.3, 0, middle(blocks[0], -27.3) + rise), 6.2, 0.5, "cocoa+", flat="z")

    # the lower jaw: three sand blocks reaching as far forward as the snout, dropped a little so the mouth hangs open
    jaws = ((-23.5, -27.8, -2.8, -3.8, 8.6, 1.6, -24.9), (-27.2, -29.8, -3.75, -4.0, 6.6, 1.1, -27.95),
            (-29.2, -31.0, -3.95, -4.15, 4.4, 0.7, -29.95))

    def jaw_top(b, x):
        return middle(b, x) + b[5] / 2

    for b in jaws:
        x0, x1, z0, z1, wide, thick, gum_from = b
        head.beam((x0, 0, z0), (x1, 0, z1), wide, thick, "sand", flat="z")
        mid = DROP / 2 - 0.025
        head.beam((gum_from, 0, jaw_top(b, gum_from) + mid), (x1 + 0.35, 0, jaw_top(b, x1 + 0.35) + mid), wide - 1.4, DROP + 0.05,
                  "gum", flat="z")
    # the dark inside: blocks that stay behind the teeth and end inside the lips and the jaw
    head.block(-30.5, (-1.2, 1.2, -3.8, -1.7), -28.6, (-1.2, 1.2, -3.7, -1.5), "mouth")
    head.block(-29.0, (-2.3, 2.3, -3.6, -1.3), -25.1, (-3.4, 3.4, -2.7, -0.8), "mouth")

    # the teeth: small tridents, bases sunk in the gums. Along each side and across the front, and a second row inside
    # the front; the lower ones stand between the upper ones
    up, low = blocks, jaws
    for b, xs in ((up[0], (-25.5, -26.65)), (up[1], (-28.3,))):
        y = (b[4] - 1.4) / 2 - 0.45
        for x in xs:
            trident(head, x, y, lip_bottom(b, x) - DROP + 0.1, 0.55, 0.75)
    front = lip_bottom(up[2], -30.4) - DROP + 0.1
    trident(head, -30.4, 0.0, front, 0.55, 0.75, "y", mirror=False)
    trident(head, -30.4, 1.1, front, 0.55, 0.75, "y")
    inner = lip_bottom(up[1], -29.0) - DROP + 0.1
    for y in (0.55, 1.65):
        trident(head, -29.0, y, inner, 0.4, 0.55, "y")
    for b, xs in ((low[0], (-25.5, -26.65)), (low[1], (-28.6,))):
        y = (b[4] - 1.4) / 2 - 0.45
        for x in xs:
            trident(head, x, y, jaw_top(b, x) + DROP - 0.1, 0.55, -0.65)
    front = jaw_top(low[2], -30.3) + DROP - 0.1
    trident(head, -30.3, 0.55, front, 0.5, -0.6, "y")
    inner = jaw_top(low[1], -29.2) + DROP - 0.1
    trident(head, -29.2, 0.0, inner, 0.4, -0.45, "y", mirror=False)
    trident(head, -29.2, 1.1, inner, 0.4, -0.45, "y")

    # the eye: a big dark block on the side of the snout, over the lip. The brow is a low lid that cuts its top and comes
    # past it in front
    eye = (4.5, 5.2, 0.3, 2.1)
    head.block(-27.6, eye, -25.4, eye, "black", mirror=True)
    head.beam((-28.2, 4.9, 2.05), (-25.0, 4.9, 2.3), 0.8, 1.4, "cocoa", mirror=True)

    # the body: the collar and nine slices, each on its own joint
    segs, before = {}, (-25, -21, 5, -4, 4)
    for i, (name, x0, x1, n, bot, top) in enumerate(SLICES):
        seg = segs[name] = m.part(name, (x0, 0, 0), "Head" if i == 0 else NAMES[i - 1])
        slab(seg, x0, x1, n, bot, top)
        # a sleeve into the piece in front, sized from the smaller of the two and clear of both pieces' steps
        _, _, fn, fbot, ftop = before
        up_n, down_n = steps(n)
        up_f, down_f = steps(fn)
        clear_up = max(sum(t for _, t in up_n), sum(t for _, t in up_f))
        clear_down = max(sum(t for _, t in down_n), sum(t for _, t in down_f))
        seg.sym(x0 - 1, x0, max(min(n, fn) - 2, 0), max(bot, fbot) + clear_down, min(top, ftop) - clear_up, "cocoa-")
        before = (x0, x1, n, bot, top)

    # THE MARK: the collar, six red gill frills wrapping the throat, each ring smaller than the one before
    for i, reach in enumerate((2.8, 2.6, 2.4, 2.2, 1.8, 1.6)):  # how high each ring's top edge reaches on the flank
        out = 1.6 - 0.12 * i
        frill_ring(segs["Collar"], -20.7 + 0.88 * i, reach - 0.425 * out, out, 0.7, 0.35)

    # the seat: on the even back behind the collar, a shallow slot either side for the rider's legs
    segs["S2"].dent(-10, -7, 3, 0, 2, "cocoa")

    # the fins. Small rounded side paddles low behind the collar; everything else far back in the last third
    s1, s5, s6, s7 = segs["S1"], segs["S5"], segs["S6"], segs["S7"]
    s1.beam((-15.0, 2.4, -2.3), (-12.8, 4.8, -3.0), 3.2, 0.7, "cocoa", flat="z", mirror=True)
    s1.beam((-13.5, 4.2, -2.84), (-12.0, 5.8, -3.3), 2.2, 0.35, "cocoa-", flat="z", mirror=True)
    s5.beam((6.6, 1.8, -2.4), (9.8, 4.4, -3.7), 3.2, 0.7, "cocoa", flat="z", mirror=True)  # the belly fins
    s5.beam((9.0, 3.8, -3.38), (10.8, 5.4, -4.1), 2.0, 0.35, "cocoa-", flat="z", mirror=True)
    s6.beam((11.0, 0, -2.0), (15.4, 0, -4.4), 3.6, 1.0, "cocoa")  # the anal fin, the biggest of them
    s6.beam((14.6, 0, -3.95), (17.4, 0, -5.1), 2.0, 0.6, "cocoa-")
    s7.beam((14.3, 0, 2.2), (17.0, 0, 4.0), 2.4, 0.9, "cocoa")  # the one small back fin, over the anal fin
    s7.beam((16.4, 0, 3.6), (18.3, 0, 4.5), 1.4, 0.6, "cocoa-")

    # the tail: a short stock, a long low blade and a broad lower lobe; the blade's tip on a joint of its own
    tail = m.part("Tail", (23, 0, 0), "S9")
    slab(tail, 23, 26, 1, -2, 2)
    tail.sym(22, 23, 0, -1, 1, "cocoa-")
    tail.beam((23.6, 0, 0.5), (30.2, 0, 1.9), 2.6, 0.7, "cocoa")
    tail.beam((24.2, 0, -0.5), (29.6, 0, -1.6), 3.0, 0.4, "cocoa-")
    tip = m.part("TailTip", (29.6, 0, 1.8), "Tail")
    tip.beam((29.4, 0, 1.82), (33.2, 0, 2.5), 2.0, 0.4, "cocoa-")
