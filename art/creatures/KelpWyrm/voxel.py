"""The Kelp Wyrm (zone 3's Secret: an invented serpent the kelp has grown round) for tools/blender/voxel_kit.py
(docs/style/04-voxel-style.md), dressed by docs/style/05-rarity-look.md ("Ways to feel Mythic": age, the kelp grown
into it; light, the amber bladders; scale, a mane and ribbons stretched far past the animal).
Its idea, in its name: a wyrm that is half kelp. One kelp stem runs down its whole flank; where the stem winds round
the body a broad blade leaves it, with an amber gas bladder at the join, as on real giant kelp.

- The body is seventeen slices, each on its own joint, each one cube different from the last in width, back or belly.
  The belly rises to a slim neck in front and to the tail behind, and the back humps under the rider.
- Olive back, gold belly, and between them the stem: one dark green row, level from the neck to the tail.
- The head is carried high and is wider than the neck: a short skull, a snout of three blocks stepping down to a blunt
  nose that overhangs a gold jaw, a slit pupil in an amber eye under a brow that comes past it.
- A kelp collar where the head meets the neck, and from under it the mane: seven broad blades swept back all round.
- Three wraps (raised bands of kelp) on the rear half, none near the seat. Their blades turn round the body from wrap to
  wrap: up in a V, out to the sides, up again: the winding. Each blade is two boxes, the second smaller and lighter.
- The tail ends in one big bladder and three long flat ribbons, each a chain of boxes on joints of their own.
- It swims as a sea serpent does: the wave runs down the body up and down, and the ribbons trail it.
The rider sits on the hump, behind the mane and in front of the first V, legs in a slot either side."""
import math

NAME, ZONE, RARITY = "Kelp Wyrm", "ZONE 3 / KELP FOREST", "SECRET"
U = 0.45
PALETTE = {"olive": "#7C8732", "gold": "#E3B446", "kelp": "#2C5F3F", "amber": "#FFB13B", "black": "#1E2420"}
SEAT = (-6.5, 6, 5.5)
GLOW = {"amber": 0.5}  # the gas bladders and the eyes: a soft light with a source
TEXTURES = [{"tile": "stud", "on": "top", "colours": ["olive"]}]
FRAME, ORTHO, ORTHO_SWIM = 3.0, 44.0, 48.0

# the body: each slice is (length, cubes out, bottom, top). One number changes from slice to slice, never two. A slim
# neck dips behind the head, the body swells in all three outlines to a broad hump under the rider, then one long
# taper: the back arches, the belly curves, and from above it is a spindle, not a bar
SLICES = ((3, 3, -1, 4), (3, 3, -2, 4), (3, 3, -2, 5), (4, 4, -2, 5), (4, 4, -3, 5), (4, 5, -3, 5), (5, 5, -3, 6), (4, 4, -3, 6),
          (4, 4, -3, 5), (4, 3, -3, 5), (4, 3, -3, 4), (3, 3, -2, 4), (3, 2, -2, 4), (3, 2, -2, 3), (3, 2, -1, 3), (3, 1, -1, 3),
          (3, 1, -1, 2))
BODY_FROM = -30
HZ = 3  # the head is carried this much higher than the body's line
STEM = 0  # the row the kelp stem runs along, on every slice
CHAIN = [f"S{i + 1}" for i in range(len(SLICES))]
AMPLITUDES = [1.5, 2, 2, 2.5, 2.5, 3, 3, 3.5, 4, 4.5, 5, 5.5, 6, 6.5, 7, 8, 9]
STEP = 0.43


def pose(parts, phase):
    """a sea serpent's swim: the wave runs down the chain up and down and grows toward the tail. The ribbons trail it,
    each joint later and wider than the one before; the two side ribbons also open and close a little"""
    parts["Head"].rotation_euler.y = math.radians(2) * math.sin(phase + math.pi)
    for k, name in enumerate(CHAIN):
        parts[name].rotation_euler.y = math.radians(AMPLITUDES[k]) * math.sin(phase - STEP * (k + 1))
    lag = STEP * (len(CHAIN) + 1)
    for k, name in enumerate(("RibC1", "RibC2", "RibC3")):
        parts[name].rotation_euler.y = math.radians((12, 16, 20)[k]) * math.sin(phase - lag - 0.6 * k)
    for tag, side in (("R", 1), ("L", -1)):
        for k in range(2):
            part = parts[f"Rib{tag}{k + 1}"]
            part.rotation_euler.y = math.radians((10, 15)[k]) * math.sin(phase - lag - 0.5 - 0.6 * k)
            part.rotation_euler.z = side * math.radians((6, 9)[k]) * math.sin(phase - lag - 1.2 - 0.6 * k)


def leaf(p, p0, p1, face, width, thick, colour, mirror=False):
    """a kelp blade: a flat box from p0 to p1 whose broad side looks toward `face` (as near as the box's line allows)"""
    d = [b - a for a, b in zip(p0, p1)]
    length = math.sqrt(sum(v * v for v in d))
    along = [v / length for v in d]
    dot = sum(a * f for a, f in zip(along, face))
    thin = [f - dot * a for a, f in zip(along, face)]
    n = math.sqrt(sum(v * v for v in thin))
    thin = [v / n for v in thin]
    wide = [along[1] * thin[2] - along[2] * thin[1], along[2] * thin[0] - along[0] * thin[2], along[0] * thin[1] - along[1] * thin[0]]
    centre = [(a + b) / 2 for a, b in zip(p0, p1)]
    verts = []
    for sa in (-1, 1):
        for sw, st in ((-1, -1), (1, -1), (1, 1), (-1, 1)):
            verts.append(tuple(c + sa * a * length / 2 + sw * w * width / 2 + st * t * thick / 2
                               for c, a, w, t in zip(centre, along, wide, thin)))
    p.solid(verts, [(0, 1, 2, 3), (4, 5, 6, 7), (0, 1, 5, 4), (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7)], colour, mirror)


def blade(p, root, mid, tip, face, wide, thick, mirror=True):
    """a blade in two boxes: the second smaller, thinner and lighter, starting inside the first"""
    leaf(p, root, mid, face, wide, thick, "kelp", mirror)
    back = [m + (r - m) * 0.14 for r, m in zip(root, mid)]
    leaf(p, back, tip, face, wide * 0.7, thick * 0.55, "kelp+", mirror)


def top_steps(n):
    return [(2, 1), (1, 1)] if n >= 3 else [(1, 1)]


def bottom_steps(n, bot):
    return [(2, 1), (1, 1)] if n >= 3 else ([(1, 1)] if n == 2 else [])


def slab(p, x0, x1, n, bot, top):
    """a slice of body: stepped corners, an olive back (lighter on the top row), a gold belly, and between them the stem:
    one dark green row at the same height on every slice"""
    p.hull(x0, x1, n, bot, top, "olive", top_steps(n), bottom_steps(n, bot))
    p.paint_sym(x0, x1, n, top - 1, top, "olive+")
    p.paint_sym(x0, x1, n, bot, STEM, "gold")
    p.paint_sym(x0, x1, n, STEM, STEM + 1, "kelp")
    p.paint_sym(x0, x1, n, bot, bot + 1, "gold-")


def build(m):
    head = m.part("Head", (BODY_FROM, 0, HZ - 1))
    # the skull: short and broad, wider than the neck behind it, its corners cut in two steps above and below; gold
    # under the mouth's line
    skull = (5, -4 + HZ, 4 + HZ)
    head.hull(-38, BODY_FROM, 5, skull[1], skull[2], "olive", [(2, 1), (1, 1)], [(2, 1), (1, 1)])
    head.paint_sym(-38, BODY_FROM, 5, skull[2] - 1, skull[2], "olive+")
    head.paint_sym(-38, BODY_FROM, 5, skull[1], HZ - 1, "gold")
    head.paint_sym(-38, BODY_FROM, 5, skull[1], skull[1] + 1, "gold-")
    # the snout: three blocks in a chain, each tilted nose-down, lower and narrower than the last; a lighter plate on the
    # first two. The last one overhangs the jaw: a blunt nose
    blocks = ((-37.4, -41.6, 1.2, 0.6, 8.4, 3.6, 5.2, -37.4), (-40.9, -44.4, 0.5, 0.0, 6.4, 2.8, 3.6, -41.9),
              (-43.8, -46.2, -0.05, -0.35, 4.4, 2.0, 0.0, 0.0))

    def middle(k, x):
        x0, x1, z0, z1 = blocks[k][:4]
        return z0 + (z1 - z0) * (x - x0) / (x1 - x0) + HZ

    for k, (x0, x1, z0, z1, wide, thick, plate, plate_from) in enumerate(blocks):
        head.beam((x0, 0, z0 + HZ), (x1, 0, z1 + HZ), wide, thick, "olive", flat="z")
        if plate:
            rise = thick / 2 + 0.2
            head.beam((plate_from, 0, middle(k, plate_from) + rise), (x1 + 0.7, 0, middle(k, x1 + 0.7) + rise), plate, 0.5, "olive+",
                      flat="z")
    # the jaw: two gold boxes under the first two blocks, shut, a little narrower and shorter than what is above them
    for k, x0, x1, wide, thick in ((0, -37.4, -41.6, 7.8, 2.2), (1, -40.9, -44.0, 5.8, 1.6)):
        def under(x):
            return middle(k, x) - blocks[k][5] / 2 + 0.15 - thick / 2

        head.beam((x0, 0, under(x0)), (x1, 0, under(x1)), wide, thick, "gold", flat="z")
    nostril = (2.0, 2.45, HZ, 0.45 + HZ)
    head.block(-45.7, nostril, -45.1, nostril, "black", mirror=True)
    # the eye: an amber block on the skull's side, a dark slit of a pupil standing out of it, and a brow box that lies on
    # the skull's corner step above it, slants down to the front and comes past it
    eye = (5.2, 6.15, 0.3 + HZ, 2.3 + HZ)
    head.block(-37.0, eye, -34.6, eye, "amber", mirror=True)
    pupil = (6.0, 6.45, 0.55 + HZ, 2.05 + HZ)
    head.block(-36.15, pupil, -35.45, pupil, "black", mirror=True)
    head.beam((-38.3, 5.0, 2.1 + HZ), (-33.6, 5.0, 3.0 + HZ), 1.2, 3.6, "olive", mirror=True)
    # the collar: a wrap of kelp where the head meets the neck, and the mane from under it: seven broad blades swept
    # back all round the neck, each in two boxes. A bladder on the collar at the foot of the upper and lower blades (the
    # eyes are the lights at its sides)
    head.band(-32.8, -30.3, 5, skull[1], skull[2], "kelp", [(2, 1), (1, 1)], [(2, 1), (1, 1)])
    for angle in (0, 51, 103, 154):
        u = (0.0, math.sin(math.radians(angle)), math.cos(math.radians(angle)))

        def out(x, r):
            return (x, r * u[1], HZ + r * u[2])

        blade(head, out(-32.5, 2.8), out(-27.5, 8.8), out(-21.5, 10.5), u, 4.6, 1.0, mirror=angle != 0)
    for y0, y1, z0, z1 in ((-0.8, 0.8, 3.6, 5.3), (3.7, 5.3, 1.9, 3.5), (1.5, 3.1, -4.9, -3.3)):
        knob = (y0, y1, z0 + HZ, z1 + HZ)
        head.block(-33.4, knob, -31.8, knob, "amber", mirror=y0 > 0)

    # the body: seventeen slices, each on its own joint
    segs, spans, x = [], [], BODY_FROM
    for i, (length, n, bot, top) in enumerate(SLICES):
        segs.append(m.part(f"S{i + 1}", (x, 0, (bot + top) / 2), "Head" if i == 0 else f"S{i}"))
        spans.append((x, x + length, n, bot, top))
        x += length
    end = x
    for i, (seg, (x0, x1, n, bot, top)) in enumerate(zip(segs, spans)):
        slab(seg, x0, x1, n, bot, top)
        # a sleeve into the piece in front, sized from the smaller of the two and clear of both pieces' steps
        fn, fbot, ftop = spans[i - 1][2:5] if i else skull
        up = max(len(top_steps(n)), len(top_steps(fn)) if i else 2)
        down = max(len(bottom_steps(n, bot)), len(bottom_steps(fn, fbot)) if i else 2, 1)
        seg.sym(x0 - 1, x0, max(min(n, fn) - 2, 0), max(bot, fbot) + down, min(top, ftop) - up, "olive-")
    # the seat: on the hump, a shallow slot either side for the rider's legs
    segs[6].dent(-8, -5, 5, 1, 4, "olive-")

    def wrap(i, a, b):
        """a raised band of kelp round slice i, between a and b: the stem wound once round the body"""
        _, _, n, bot, top = spans[i]
        segs[i].band(a, b, n, bot, top, "kelp", top_steps(n), bottom_steps(n, bot))

    def bulb(p, x0, x1, y0, y1, z0, z1):
        """a gas bladder: an amber block half sunk in the wrap, where a blade leaves it"""
        p.block(x0, (y0, y1, z0, z1), x1, (y0, y1, z0, z1), "amber", mirror=True)

    up, side = (0.0, 0.0, 1.0), (0.0, 1.0, 0.0)
    # behind the rider: two tall broad blades up in a V
    wrap(8, 0.7, 3.3)
    bulb(segs[8], 1.0, 3.0, 1.5, 3.2, 3.6, 6.0)
    blade(segs[8], (2.0, 2.0, 3.2), (7.5, 4.6, 8.4), (12.5, 5.8, 10.6), side, 4.4, 1.0)
    # the next wrap's blades have turned round the body: out to the sides, low and wide
    wrap(11, 12.4, 14.6)
    bulb(segs[11], 12.7, 14.3, 2.0, 4.2, 0.8, 2.6)
    blade(segs[11], (13.5, 2.2, 1.6), (17.5, 6.0, 3.8), (21.0, 7.8, 4.8), up, 3.4, 0.9)
    # and up again, small
    wrap(14, 21.6, 23.4)
    bulb(segs[14], 21.8, 23.2, 0.6, 2.1, 1.6, 3.6)
    blade(segs[14], (22.5, 1.0, 1.8), (26.0, 2.9, 5.0), (29.2, 3.8, 6.6), side, 2.8, 0.8)

    # the tail: one big bladder of cubes on the last slice, and three long flat ribbons out of it, each a chain of boxes
    # on joints of their own
    last = segs[-1]
    last.hull(end - 2, end + 1, 2, -2, 3, "amber", [(1, 1)], [(1, 1)])
    for name, pivot, parent, p0, p1, wide, thick, colour in (
            ("RibC1", (end + 0.4, 0, 0.5), last.name, (end - 0.6, 0, 0.5), (end + 5.2, 0, 0.2), 4.0, 0.9, "kelp"),
            ("RibC2", (end + 4.6, 0, 0.23), "RibC1", (end + 4.4, 0, 0.24), (end + 9.6, 0, 0.0), 3.0, 0.6, "kelp"),
            ("RibC3", (end + 9.0, 0, 0.03), "RibC2", (end + 8.8, 0, 0.04), (end + 12.2, 0, -0.1), 2.1, 0.3, "kelp+")):
        leaf(m.part(name, pivot, parent), p0, p1, up, wide, thick, colour)
    for tag, s in (("R", 1), ("L", -1)):
        first = m.part(f"Rib{tag}1", (end + 0.3, 1.4 * s, 1.2), last.name)
        leaf(first, (end - 0.7, 0.8 * s, 0.8), (end + 4.4, 4.2 * s, 2.8), up, 3.0, 0.7, "kelp")
        second = m.part(f"Rib{tag}2", (end + 3.9, 3.87 * s, 2.6), f"Rib{tag}1")
        leaf(second, (end + 3.7, 3.73 * s, 2.52), (end + 9.0, 6.2 * s, 4.0), up, 2.1, 0.4, "kelp+")
