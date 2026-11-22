"""The Kelp Wyrm, a trial of docs/style/11-rare-wow-study.md ("Remodels, round 1"), for tools/blender/voxel_kit.py. It
stands beside the game's Kelp Wyrm (art/creatures/KelpWyrm) and replaces nothing. The calmer second pass (the first is
in work/voxel/before_calm/).
Its idea, kept: a wyrm that is half kelp. One kelp stem winds the whole body; at each turn a broad blade leaves it with
a gas bladder at the join, as on real giant kelp.
- The body is the old one's seventeen slices on joints (slim neck, a hump under the rider, one long taper).
- One hero hue at full strength: emerald in three values (an emerald back, a dark emerald stem, a jade belly); the blades
  solid lime, a tone darker at the tip.
- The stem is a dark band about two and a half cubes thick that winds round the body: from under the neck it climbs the
  flanks and crosses over the back, down and under the belly beneath the seat, over the back again behind the rider,
  under the belly, over the tail, and into the tail's bladder.
- The focal lights are six big round amber bladders, four to five cubes, one at each turn of the stem: on the back where
  it crosses over, under the belly where it crosses under, and the tail's. Each wears a pale gold cap, faceted: on the
  back the caps are the shell, rising over the back line. Each blade has one wide lit vein down its middle; the eyes and
  the open mouth glow amber too. About a quarter of what you see.
The rider sits on the hump where the stem runs under the belly, legs in a slot either side."""
import math

NAME, ZONE, RARITY = "Kelp Wyrm (trial)", "ZONE 3 / KELP FOREST", "SECRET"
U = 0.45
PALETTE = {"emerald": "#16B35A", "deep": "#075329", "jade": "#7DDBA2", "lime": "#8FDF2E", "vein": "#EEFF80",
           "amber": "#FFB13B", "pale": "#F3E2A2", "black": "#14201A"}
SHADE = 0.9
SEAT = (-6.5, 6, 5.5)
GLOW = {"amber": 0.8, "vein": 0.75}
TEXTURES = [{"tile": "stud", "on": "top", "colours": ["emerald"]}]
FRAME, ORTHO, ORTHO_SWIM = 3.0, 44.0, 48.0

# the body: each slice is (length, cubes out, bottom, top). One number changes from slice to slice, never two
SLICES = ((3, 3, -1, 4), (3, 3, -2, 4), (3, 3, -2, 5), (4, 4, -2, 5), (4, 4, -3, 5), (4, 5, -3, 5), (5, 5, -3, 6), (4, 4, -3, 6),
          (4, 4, -3, 5), (4, 3, -3, 5), (4, 3, -3, 4), (3, 3, -2, 4), (3, 2, -2, 4), (3, 2, -2, 3), (3, 2, -1, 3), (3, 1, -1, 3),
          (3, 1, -1, 2))
# the stem's turns: (x, where it is round the body: 0 under the belly, 1 over the back). Between them it winds smoothly
TURNS = ((-30.0, 0.0), (-15.0, 1.0), (-6.5, 0.0), (6.0, 1.0), (13.5, 0.0), (22.5, 1.0), (31.0, 0.5))
STEM_HALF = 1.55  # half its thickness, in cubes across the surface
BODY_FROM = -30
HZ = 3  # the head is carried this much higher than the body's line
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
    """a flat box from p0 to p1 whose broad side looks toward `face` (as near as the box's line allows)"""
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


def veined(p, p0, p1, face, width, thick, colour, mirror=False, lead=None, vein=True):
    """a kelp blade's box, solid lime, with one wide lit vein down its middle (the middle third, about two cubes on a
    big blade), standing 0.3 proud of both faces; the blade's edges stay plain. The vein stops short of the box's tip;
    lead: it starts this far before p0, inside the vein of the box it grows from"""
    leaf(p, p0, p1, face, width, thick, colour, mirror)
    if not vein:
        return
    d = [b - a for a, b in zip(p0, p1)]
    length = math.sqrt(sum(v * v for v in d))
    cut = min(0.45, length * 0.1) / length
    q0 = [a + v * (cut if lead is None else -lead / length) for a, v in zip(p0, d)]
    q1 = [b - v * cut for b, v in zip(p1, d)]
    leaf(p, q0, q1, face, max(width / 3, min(2.2, width * 0.45)), thick + 0.6, "vein", mirror)


def blade(p, root, mid, tip, face, wide, thick, mirror=True):
    """a blade in two boxes, the second smaller, thinner and a tone darker, starting inside the first; one lit vein down
    the first, the tip plain"""
    veined(p, root, mid, face, wide, thick, "lime", mirror)
    back = [m + (r - m) * 0.14 for r, m in zip(root, mid)]
    veined(p, back, tip, face, wide * 0.7, thick * 0.55, "lime-", mirror, vein=False)


def frustum(p, cx, z0, r0, z1, r1, colour, cy=0.0):
    """an upright block, (half length, half width) r0 at height z0 and r1 at z1"""
    verts = [(cx + sx * r[0], cy + sy * r[1], z) for z, r in ((z0, r0), (z1, r1)) for sx, sy in ((-1, -1), (1, -1), (1, 1), (-1, 1))]
    p.solid(verts, [(0, 1, 2, 3), (4, 5, 6, 7), (0, 1, 5, 4), (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7)], colour)


def bladder(p, cx, cz, size, wide, up):
    """a big round amber bladder: two crossed blocks (long and low, short and tall) so its side outline is a rounded
    octagon, centred at (cx, 0, cz), `size` across and `wide` through; a faceted pale gold cap on its outer end (up: on
    top; not up: underneath)"""
    r, c, h = size / 2, size / 2 * 0.62, wide / 2
    p.prism([(cx - c, cz - r), (cx + c, cz - r), (cx + r, cz - c), (cx + r, cz + c), (cx + c, cz + r), (cx - c, cz + r),
             (cx - r, cz + c), (cx - r, cz - c)], -h, h, "amber")
    s = 1 if up else -1
    rim = cz + s * (r - 0.35)
    frustum(p, cx, rim, (c + 0.1, h * 0.75), rim + s * size * 0.42, (c * 0.45, h * 0.35), "pale")


def top_steps(n):
    return [(2, 1), (1, 1)] if n >= 3 else [(1, 1)]


def bottom_steps(n, bot):
    return [(2, 1), (1, 1)] if n >= 3 else ([(1, 1)] if n == 2 else [])


def stem_at(x):
    """where the stem is round the body at x: 0 under the belly, 1 over the back, eased between the turns"""
    for (xa, a), (xb, b) in zip(TURNS, TURNS[1:]):
        if xa <= x <= xb:
            f = (x - xa) / (xb - xa)
            return a + (b - a) * (1 - math.cos(math.pi * f)) / 2
    return TURNS[-1][1]


def slab(p, x0, x1, n, bot, top):
    """a slice of body: stepped corners, an emerald back (lighter on the top row), a jade belly, and the stem: every
    cube within STEM_HALF of its line, measured across the surface from the belly's middle up the side to the back's"""
    p.hull(x0, x1, n, bot, top, "emerald", top_steps(n), bottom_steps(n, bot))
    p.paint_sym(x0, x1, n, top - 1, top, "emerald+")
    p.paint_sym(x0, x1, n, bot, 0, "jade")
    p.paint_sym(x0, x1, n, bot, bot + 1, "jade-")
    a, b, zc = n + 0.5, (top - bot) / 2, (bot + top) / 2
    half_round = math.pi * (a + b) / 2  # the surface's length from the belly's middle to the back's, on one side
    line = [(x0 - 2 + 0.2 * k, stem_at(x0 - 2 + 0.2 * k) * half_round) for k in range(int((x1 - x0 + 4) / 0.2) + 1)]
    for (i, j, k) in list(p.cells):
        psi = math.atan2(abs(j) / a, -(k + 0.5 - zc) / b) / math.pi
        xc, sc = i + 0.5, psi * half_round
        if min((xc - lx) ** 2 + (sc - ls) ** 2 for lx, ls in line) < STEM_HALF ** 2:
            p.cells[(i, j, k)] = "deep"


def build(m):
    head = m.part("Head", (BODY_FROM, 0, HZ - 1))
    # the skull: short and broad, wider than the neck, its corners cut in two steps; jade under the mouth's line
    skull = (5, -4 + HZ, 4 + HZ)
    head.hull(-38, BODY_FROM, 5, skull[1], skull[2], "emerald", [(2, 1), (1, 1)], [(2, 1), (1, 1)])
    head.paint_sym(-38, BODY_FROM, 5, skull[2] - 1, skull[2], "emerald+")
    head.paint_sym(-38, BODY_FROM, 5, skull[1], HZ - 1, "jade")
    head.paint_sym(-38, BODY_FROM, 5, skull[1], skull[1] + 1, "jade-")
    # the snout: three blocks in a chain, each tilted nose-down, lower and narrower than the last; a lighter plate on the
    # first two. The last overhangs the jaw: a blunt nose
    blocks = ((-37.4, -41.6, 1.2, 0.6, 8.4, 3.6, 5.2, -37.4), (-40.9, -44.4, 0.5, 0.0, 6.4, 2.8, 3.6, -41.9),
              (-43.8, -46.2, -0.05, -0.35, 4.4, 2.0, 0.0, 0.0))

    def middle(k, x):
        x0, x1, z0, z1 = blocks[k][:4]
        return z0 + (z1 - z0) * (x - x0) / (x1 - x0) + HZ

    for k, (x0, x1, z0, z1, wide, thick, plate, plate_from) in enumerate(blocks):
        head.beam((x0, 0, z0 + HZ), (x1, 0, z1 + HZ), wide, thick, "emerald", flat="z")
        if plate:
            rise = thick / 2 + 0.2
            head.beam((plate_from, 0, middle(k, plate_from) + rise), (x1 + 0.7, 0, middle(k, x1 + 0.7) + rise), plate, 0.5,
                      "emerald+", flat="z")
    # the jaw: two jade boxes, a little narrower than the snout, dropped open more toward the front; between them and
    # the snout the mouth, lit amber inside and set back from both lips
    def lip(x):
        return blocks[0][2] + HZ - blocks[0][5] / 2 - 0.3 + 0.32 * (x + 37.4)

    for x0, x1, wide, thick, drop in ((-37.4, -41.6, 7.8, 2.2, 0.0), (-40.9, -44.0, 5.8, 1.6, 0.2)):
        head.beam((x0, 0, lip(x0) - drop - thick / 2), (x1, 0, lip(x1) - drop - thick / 2), wide, thick, "jade", flat="z")
    head.block(-37.2, (-3.5, 3.5, lip(-37.2) - 0.3, middle(0, -37.2) - 1.5), -43.6,
               (-2.2, 2.2, lip(-43.6) - 0.3, middle(1, -43.6) - 1.1), "amber")
    nostril = (2.0, 2.45, HZ, 0.45 + HZ)
    head.block(-45.7, nostril, -45.1, nostril, "black", mirror=True)
    # the eye: a glowing amber block on the skull's side, a dark slit of a pupil standing out of it, and a brow box that
    # lies on the skull's corner step above it, slants down to the front and comes past it
    eye = (5.2, 6.15, 0.3 + HZ, 2.3 + HZ)
    head.block(-37.0, eye, -34.6, eye, "amber", mirror=True)
    pupil = (6.0, 6.45, 0.55 + HZ, 2.05 + HZ)
    head.block(-36.15, pupil, -35.45, pupil, "black", mirror=True)
    head.beam((-38.3, 5.0, 2.1 + HZ), (-33.6, 5.0, 3.0 + HZ), 1.2, 3.6, "emerald", mirror=True)
    # the collar: a wrap of kelp where the head meets the neck, and the mane from under it: five broad blades swept
    # back, the top one climbing high
    head.band(-32.8, -30.3, 5, skull[1], skull[2], "deep", [(2, 1), (1, 1)], [(2, 1), (1, 1)])
    for angle, reach, rise, wide in ((0, 9.8, 14.5, 5.0), (58, 8.6, 11.0, 4.4), (128, 8.4, 10.0, 4.0)):
        u = (0.0, math.sin(math.radians(angle)), math.cos(math.radians(angle)))

        def out(x, r):
            return (x, r * u[1], HZ + r * u[2])

        blade(head, out(-32.5, 2.8), out(-28.0, reach), out(-22.0, rise), u, wide, 1.0, mirror=angle != 0)

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
        seg.sym(x0 - 1, x0, max(min(n, fn) - 2, 0), max(bot, fbot) + down, min(top, ftop) - up, "deep")
    # the seat: on the hump, a shallow slot either side for the rider's legs
    segs[6].dent(-8, -5, 5, 1, 4, "emerald-")

    up, side = (0.0, 0.0, 1.0), (0.0, 1.0, 0.0)
    # turn one, over the back in front of the seat: a bladder on the spine, two blades splayed out and up, short of
    # the rider
    bladder(segs[4], -15.0, 6.6, 5.0, 5.6, True)
    blade(segs[4], (-15.0, 0.8, 5.8), (-13.6, 6.4, 8.6), (-12.4, 8.8, 10.2), side, 3.4, 0.9)
    # turn two, under the belly beneath the seat: a bladder hanging under it, two blades out to the sides and down
    bladder(segs[6], -6.6, -4.3, 4.6, 5.4, False)
    blade(segs[6], (-6.2, 0.6, -4.2), (-2.8, 6.2, -6.4), (0.4, 8.0, -7.4), up, 3.4, 0.9)
    # turn three, over the back behind the rider: the biggest bladder and two tall blades up in a V
    bladder(segs[9], 6.0, 6.8, 5.4, 5.4, True)
    blade(segs[9], (6.2, 0.6, 5.6), (9.8, 4.6, 10.6), (13.6, 5.8, 13.6), side, 4.4, 1.0)
    # turn four, under the belly on the tail: a bladder under it and two blades out to the sides
    bladder(segs[11], 13.5, -3.4, 4.6, 4.2, False)
    blade(segs[11], (13.6, 0.6, -3.0), (17.2, 5.4, -4.2), (20.6, 7.0, -4.8), up, 3.0, 0.8)
    # turn five, over the tail: a smaller bladder, its blades the tail's ribbons
    bladder(segs[14], 22.5, 3.8, 4.2, 4.6, True)

    # the tail: the sixth bladder, of cubes, round the last slice with a pale cap, and three long flat ribbons out of
    # it, each a chain of veined boxes on joints of their own
    last = segs[-1]
    last.hull(end - 3, end + 1, 2, -2, 3, "amber", [(1, 1)], [(1, 1)])
    frustum(last, end - 1.0, 2.7, (1.6, 1.3), 4.4, (0.7, 0.55), "pale")
    for name, pivot, parent, p0, p1, wide, thick, colour in (
            ("RibC1", (end + 0.4, 0, 0.5), last.name, (end - 0.6, 0, 0.5), (end + 5.2, 0, 0.2), 4.0, 0.9, "lime"),
            ("RibC2", (end + 4.6, 0, 0.23), "RibC1", (end + 4.4, 0, 0.24), (end + 9.6, 0, 0.0), 3.0, 0.6, "lime"),
            ("RibC3", (end + 9.0, 0, 0.03), "RibC2", (end + 8.8, 0, 0.04), (end + 12.2, 0, -0.1), 2.1, 0.3, "lime-")):
        veined(m.part(name, pivot, parent), p0, p1, up, wide, thick, colour, lead=None if name == "RibC1" else 0.2,
               vein=name == "RibC1")
    for tag, s in (("R", 1), ("L", -1)):
        first = m.part(f"Rib{tag}1", (end + 0.3, 1.4 * s, 1.2), last.name)
        veined(first, (end - 0.7, 0.8 * s, 0.8), (end + 4.4, 4.2 * s, 2.8), up, 3.0, 0.7, "lime")
        second = m.part(f"Rib{tag}2", (end + 3.9, 3.87 * s, 2.6), f"Rib{tag}1")
        veined(second, (end + 3.7, 3.73 * s, 2.52), (end + 9.0, 6.2 * s, 4.0), up, 2.1, 0.4, "lime-", vein=False)
