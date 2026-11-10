"""Basilosaurus (zone 7's Legendary: the prehistoric whale as long and thin as a sea serpent) for
tools/blender/voxel_kit.py (docs/style/04-voxel-style.md), dressed as a Legendary by docs/style/05-rarity-look.md.
Designed from the real animal, not from another creature's build.
Its idea: a whale that is still half a serpent. A small toothy head on an endless body, and two tiny hind legs it no
longer needs, far back, as the only bright thing on it.

It is a huge animal in its base form, and the model shows that in its build, not only in its size (workout 5, "Scale
shows in form"): its cubes are finer than a smaller creature's would be at this length, so the body takes more of them
across, and every curve is made of more, gentler steps.
- The body is twenty slices. Each is one step bigger or smaller than the last, in width or in the back or in the belly,
  never two at once, so the three outlines each make their own staircase and the eye reads one long line. A slice is about
  as long as it is thick: long in the middle, short at the tail, like a backbone.
- The corners are cut in three steps where the body is thick, two where it is thinner, one at the tail.
- Four lines run the whole length and tie the slices together: the pale belly's edge, which dips under the middle and
  rises to the tail; a paler flank above it, whose top is one level line from neck to tail; a dark line under the back;
  and the backbone, one small knuckle on each slice, each smaller than the
  one before.
- The head is small for the body: a short skull and a long, narrow snout of three blocks in a chain. The nostrils sit
  halfway up the snout, on their way to becoming a blowhole. Pointed teeth at the front; broad blade teeth in pairs at the
  back, like a saw. The thin dark gum line. The jaw is its own part and opens.
- The front flippers have an elbow: an upper arm that goes out, a paddle that turns back from it.
- The hind legs are two tiny bent limbs far down the body, with amber feet: the one accent, and the head's echo.
- A small flat tail fluke, on a joint of its own. It swims by bending up and down, as whales do.
- The eye is small, with a dark pupil and a thin halo of soft light, under a brow that sits on it.
The rider sits behind the flippers, legs in a shallow slot either side."""
import math

NAME, ZONE, RARITY = "Basilosaurus", "ZONE 7 / MIDNIGHT", "LEGENDARY"
U = 0.44
PALETTE = {"hide": "#4C586A", "belly": "#DDD5B8", "tooth": "#FFFFFF", "mouth": "#6A2630", "gum": "#9A4F58", "black": "#22262B",
           "amber": "#E2A03C", "soft": "#F2C46A", "flank": "#7A8797"}
SEAT = (9.5, 6, 6.5)
GLOW = {"soft": 0.4}  # only the thin halo of the eye
FRAME, ORTHO, ORTHO_SWIM = 3.4, 50.0, 55.0
K = 0.52 / 0.44  # the head, the flippers and the fluke are laid out on a coarser grid: K of the body's cubes to the unit

# the body: each slice is (length, cubes out, bottom, top). One number changes from slice to slice, never two
SLICES = ((3, 4, -5, 5), (3, 5, -5, 5), (4, 5, -5, 6), (4, 6, -5, 6), (5, 6, -6, 6), (5, 6, -6, 6), (5, 6, -6, 6), (4, 6, -5, 6),
          (4, 5, -5, 6), (4, 5, -5, 5), (4, 5, -4, 5), (3, 4, -4, 5), (3, 4, -4, 4), (3, 4, -3, 4), (3, 3, -3, 4), (3, 3, -3, 3),
          (3, 3, -2, 3), (2, 2, -2, 3), (2, 2, -2, 2), (2, 2, -1, 2))
BODY_FROM = -7
FLANK = 1  # the height of the flank line
CHAIN = ["Head"] + [f"S{i + 1}" for i in range(len(SLICES))] + ["Tail", "Fluke"]
AMPLITUDES = [2, 2, 2, 3, 3, 3, 4, 4, 4, 5, 5, 5, 6, 6, 7, 7, 8, 8, 9, 10, 11, 14]


def pose(parts, phase):
    """a whale's swim on a serpent's body: the wave runs down the long chain up and down, not side to side. The jaw opens
    and shuts once a beat; the flippers row a little; the fluke beats at the end of the wave"""
    parts["Head"].rotation_euler.y = math.radians(1.5) * math.sin(phase + math.pi)
    for k, name in enumerate(CHAIN[1:]):
        parts[name].rotation_euler.y = math.radians(AMPLITUDES[k]) * math.sin(phase - 0.43 * (k + 1))
    parts["Jaw"].rotation_euler.y = -math.radians(10) * (0.5 + 0.5 * math.sin(phase))
    for name, side in (("FlipperR", 1), ("FlipperL", -1)):
        parts[name].rotation_euler.x = side * math.radians(12) * math.sin(phase - 0.8)
        parts[name].rotation_euler.z = side * math.radians(7) * math.sin(phase - 1.8)


class Coarse:
    """free pieces laid out on the coarser grid (K cubes to the unit) and moved by `off`, so the head, the flippers and
    the fluke keep the size they were drawn at while the body's cubes are finer"""

    def __init__(self, part, off=(0.0, 0.0, 0.0)):
        self.p, self.off = part, off

    def at(self, p):
        return tuple(o + v * K for o, v in zip(self.off, p))

    def section(self, s):
        oy, oz = self.off[1], self.off[2]
        return (oy + s[0] * K, oy + s[1] * K, oz + s[2] * K, oz + s[3] * K)

    def beam(self, p0, p1, wide, thick, colour, **kw):
        self.p.beam(self.at(p0), self.at(p1), wide * K, thick * K, colour, **kw)

    def block(self, x0, s0, x1, s1, colour, **kw):
        self.p.block(self.off[0] + x0 * K, self.section(s0), self.off[0] + x1 * K, self.section(s1), colour, **kw)

    def tooth(self, x, y, z, size, length, colour, long=None):
        x, y, z = self.at((x, y, z))
        self.p.tooth(x, y, z, size * K, length * K, colour, long=long * K if long else None)


def top_steps(n):
    """the corners of the back: three steps where the body is thick, fewer as it thins"""
    return [(3, 1), (2, 1), (1, 1)] if n >= 5 else ([(2, 1), (1, 1)] if n == 4 else [(1, 1)])


def bottom_steps(n):
    return [(2, 1), (1, 1)] if n >= 4 else [(1, 1)]


def belly_edge(bot):
    """how high the pale belly comes: it dips under the deep middle and rises to the tail, in one line"""
    return bot + (4 if bot <= -5 else (3 if bot <= -3 else (2 if bot == -2 else 1)))


def slab(p, x0, x1, n, bot, top):
    """a slice of body: stepped corners, dark hide (lighter on the top row, a darker line on the lowest step of the back),
    a pale belly"""
    steps = top_steps(n)
    p.hull(x0, x1, n, bot, top, "hide", steps, bottom_steps(n))
    if len(steps) > 1:
        p.paint_sym(x0, x1, n, top - len(steps), top - len(steps) + 1, "hide-")
    p.paint_sym(x0, x1, n, top - 1, top, "hide+")
    edge = belly_edge(bot)
    p.paint_sym(x0, x1, n, bot, edge, "belly")
    p.paint_sym(x0, x1, n, bot, bot + 1, "belly-")
    if top >= 3:  # a paler flank between the dark back and the belly. Its top is one level line down the whole body; its
        p.paint_sym(x0, x1, n, edge, FLANK, "flank")  # bottom follows the belly, so it is broad in the middle, thin at the tail


def build(m):
    head = m.part("Head", (BODY_FROM, 0, 0))
    h = Coarse(head)
    # the skull: a small box with two-step corners, pale under the jaw line. The snout and the jaw start inside its front
    skull = (4, -5, 4)
    head.hull(-13, BODY_FROM, 4, -5, 4, "hide", [(2, 1), (1, 1)], [(1, 1)])
    head.paint_sym(-13, BODY_FROM, 4, 3, 4, "hide+")
    head.paint_sym(-13, BODY_FROM, 4, -5, -1, "belly")
    head.paint_sym(-13, BODY_FROM, 4, -5, -4, "belly-")
    head.paint_sym(-13, BODY_FROM, 4, -1, 0, "flank")
    # the snout: three long, narrow blocks in a chain, each tilted a little nose-down, lower and narrower than the last.
    # Each has a pale lip plate underneath with a thin dark gum line; the first two have a lighter plate on top, which
    # starts past the end of the block before
    blocks = ((-10.5, -14.5, 0.55, 0.3, 5.4, 2.8, 3.0, -10.5, -10.5), (-13.9, -18.3, 0.25, 0.0, 4.0, 2.2, 2.0, -14.9, -14.8),
              (-17.7, -22.0, -0.05, -0.25, 2.8, 1.7, 0.0, 0.0, -18.6))

    def middle(k, x):
        x0, x1, z0, z1 = blocks[k][:4]
        return z0 + (z1 - z0) * (x - x0) / (x1 - x0)

    def lip_bottom(k, x):
        return middle(k, x) - blocks[k][5] / 2 - 0.6

    for k, (x0, x1, z0, z1, wide, thick, plate, plate_from, gum_from) in enumerate(blocks):
        h.beam((x0, 0, z0), (x1, 0, z1), wide, thick, "hide", flat="z")
        lip = thick / 2 + 0.3
        h.beam((x0, 0, z0 - lip), (x1, 0, z1 - lip), wide - 0.4, 0.6, "belly", flat="z")
        if plate:
            rise = thick / 2 + 0.175
            h.beam((plate_from, 0, middle(k, plate_from) + rise), (x1 + 0.7, 0, middle(k, x1 + 0.7) + rise), plate, 0.45, "hide+", flat="z")
        h.beam((gum_from, 0, lip_bottom(k, gum_from) - 0.05), (x1 + 0.3, 0, lip_bottom(k, x1 + 0.3) - 0.05), wide - 1.0, 0.2, "gum",
               flat="z")
    # the nostrils: halfway up the snout, on top, not at its tip (a whale in the making)
    nostril = (0.35, 0.85, 1.5, 1.75)
    h.block(-16.6, nostril, -16.0, nostril, "black", mirror=True)
    # the dark inside of the mouth: two blocks that stay behind the teeth and end inside the lips and the jaw
    for x0, x1, half in ((-14.0, -10.8, 1.3), (-17.9, -14.0, 0.6)):
        h.block(x0, (-half, half, -2.85, -1.2), x1, (-half, half, -2.85, -1.2), "mouth")
    # the upper teeth, each with its base sunk into the gum: broad blades in pairs at the back, like a saw; pointed ones
    # along the front of the snout
    for x in (-11.7, -13.1):
        h.tooth(x, 1.9, lip_bottom(0, x) - 0.05, 0.55, 0.75, "tooth", long=1.2)
    for k, x in ((1, -15.4), (1, -16.5), (1, -17.6), (2, -19.2), (2, -20.3), (2, -21.3)):
        h.tooth(x, (0.0, 1.2, 0.6)[k], lip_bottom(k, x) - 0.05, 0.5, 1.0 if k == 1 else 0.85, "tooth")
    # the eye: small, a dark socket on the skull's side, a thin halo of soft light, a dark pupil standing out of it. The brow
    # sits on the eye: it covers the top of the eye's square, slanting, and stands only a little proud of the pupil
    ring = (4.38, 4.97, 0.0, 1.9)
    head.block(-11.35, ring, -9.2, ring, "hide-", mirror=True)
    halo = (4.85, 5.15, 0.3, 1.65)
    head.block(-11.05, halo, -9.5, halo, "soft", mirror=True)
    pupil = (4.97, 5.33, 0.53, 1.42)
    head.block(-10.8, pupil, -9.75, pupil, "black", mirror=True)
    head.beam((-11.7, 4.81, 1.54), (-8.85, 4.81, 1.77), 1.06, 1.32, "hide", mirror=True)

    # the lower jaw, on its own joint: three slim boxes in a chain like the snout, with its own gum line and teeth
    jaw = m.part("Jaw", (-10.5 * K, 0, -2.6 * K), "Head")
    j = Coarse(jaw)
    jaws = ((-10.7, -14.7, -3.05, -3.1, 4.6, 1.2, -10.9), (-14.1, -18.4, -3.1, -3.05, 3.2, 0.9, -15.0),
            (-17.8, -21.2, -3.05, -2.95, 2.0, 0.6, -18.7))

    def jaw_top(k, x):
        x0, x1, z0, z1, _, thick = jaws[k][:6]
        return z0 + (z1 - z0) * (x - x0) / (x1 - x0) + thick / 2

    for k, (x0, x1, z0, z1, wide, thick, gum_from) in enumerate(jaws):
        j.beam((x0, 0, z0), (x1, 0, z1), wide, thick, "belly", flat="z")
        j.beam((gum_from, 0, jaw_top(k, gum_from) + 0.05), (x1 + 0.3, 0, jaw_top(k, x1 + 0.3) + 0.05), wide - 0.6, 0.2, "gum", flat="z")
    for x in (-12.3, -13.7):
        j.tooth(x, 1.7, jaw_top(0, x) + 0.05, 0.5, -0.55, "tooth", long=1.1)
    for k, x in ((1, -15.6), (1, -16.8), (1, -17.7), (2, -19.3), (2, -20.4)):
        j.tooth(x, (0.0, 1.0, 0.45)[k], jaw_top(k, x) + 0.05, 0.45, -0.55, "tooth")

    # the body: twenty slices, each on its own joint
    segs, spans, x = [], [], BODY_FROM
    for i, (length, n, bot, top) in enumerate(SLICES):
        segs.append(m.part(f"S{i + 1}", (x, 0, 0), "Head" if i == 0 else f"S{i}"))
        spans.append((x, x + length, n, bot, top))
        x += length
    end = x
    for i, (seg, (x0, x1, n, bot, top)) in enumerate(zip(segs, spans)):
        slab(seg, x0, x1, n, bot, top)
        # a sleeve into the piece in front, so a bending joint shows body. It is sized from the smaller of the two pieces
        # and stays clear of both pieces' steps, so none of its faces lies in the plane of a face that shows
        fn, fbot, ftop = spans[i - 1][2:5] if i else skull
        small = min(n, fn)
        up = max(len(top_steps(n)), len(top_steps(fn)) if i else 2)
        down = max(len(bottom_steps(n)), len(bottom_steps(fn)) if i else 1)
        seg.sym(x0 - 1, x0, max(small - 2, 0), max(bot, fbot) + down, min(top, ftop) - up, "hide-")
        # the backbone: one small knuckle on the back of each slice, smaller as the body thins (none under the rider)
        if 1 <= i <= 18 and i != 4:
            half, tall, long = (0.7, 0.7, 1.0) if n >= 5 else ((0.6, 0.6, 0.9) if n == 4 else ((0.5, 0.5, 0.75) if n == 3 else (0.4, 0.35, 0.6)))
            mid = (x0 + x1) / 2
            knuckle = (-half, half, top - 0.12, top + tall)
            seg.block(mid - long, knuckle, mid + long, knuckle, "hide")
    # the seat: behind the flippers, a shallow slot either side for the rider's legs
    segs[4].dent(8, 11, 6, 0, 3, "hide-")

    # the front flippers, each on its own joint, with an elbow: an upper arm that goes out from the shoulder, then a
    # paddle that turns back from it, in two boxes
    for name, side in (("FlipperR", 1), ("FlipperL", -1)):
        part = m.part(name, (5.1, 5.7 * side, -2.0), "S4")
        for (ax, ay, az), (bx, by, bz), wide, thick, colour in (((1.6, 3.6, -1.3), (4.05, 9.1, -2.82), 3.0, 1.2, "hide"),
                                                                ((3.4, 7.65, -2.42), (9.8, 10.25, -3.82), 3.6, 0.8, "hide"),
                                                                ((8.5, 9.72, -3.54), (12.0, 11.2, -4.3), 2.4, 0.45, "hide-")):
            p0 = (3.2 + ax * K, side * (1.25 + ay * K), -0.45 + az * K)
            p1 = (3.2 + bx * K, side * (1.25 + by * K), -0.45 + bz * K)
            part.beam(p0, p1, wide * K, thick * K, colour, flat="z")

    # the hind legs: two tiny bent limbs far down the body, left over from when it walked. A thigh, and an amber foot:
    # the one accent on the animal
    segs[14].beam((48.0, 2.9, -0.8), (50.0, 5.4, -2.3), 1.4, 0.95, "hide-", flat="z", mirror=True)
    segs[14].beam((49.5, 4.75, -1.9), (51.8, 5.75, -3.5), 0.95, 0.55, "amber", flat="z", mirror=True)

    # the tail: a short stock, taller than the fluke is thick (a whale's keel), then a flat fluke on a joint of its own: a
    # hub and two lobes swept back, each ending in a darker tip. It lies flat, as a whale's does
    off = (end - 51 * K, 0.0, 0.5 - 0.5 * K)
    tail = m.part("Tail", (end, 0, 0.5), f"S{len(SLICES)}")
    Coarse(tail, off).beam((50.6, 0, 0.5), (53.6, 0, 0.5), 2.3, 2.2, "hide", flat="z")
    fluke = m.part("Fluke", (end + 2 * K, 0, 0.5), "Tail")
    f = Coarse(fluke, off)
    f.beam((52.6, 0, 0.5), (55.9, 0, 0.5), 6.8, 1.8, "hide", flat="z")
    f.beam((54.2, 1.8, 0.5), (59.0, 7.0, 0.5), 4.0, 1.0, "hide", flat="z", mirror=True)
    f.beam((57.8, 5.7, 0.5), (60.4, 8.7, 0.5), 2.6, 0.6, "hide-", flat="z", mirror=True)
