"""Megalodon, the third trial of docs/style/10-sharks-round-2.md ("The huge shark, third try"; zone 8's Legendary: the
giant prehistoric shark), for tools/blender/voxel_kit.py. It stands beside the game's Megalodon (art/creatures/Megalodon)
and the second trial (art/creatures/TrialMegalodonV2) and replaces nothing. Designed from the real animal; a close-up of
another game's giant was read for qualities only (the hump, the taper, the overhang, the grin), nothing copied.
Its idea: the hump. A wedge leaning forward: heavy shoulders and a thick neck just behind the head, then one long
smooth fall to a thin stalk and a great torn crescent tail.
- The body in slices, 89 cubes long. Deepest at the shoulders, 25 deep (0.28 of the length) and 21 wide; the
  chest bulges three cubes below the jaw line. From there the back and the belly fall in BROAD steps of two cubes,
  each a plateau seven or eight long (never runs of one-cube terraces), to a stalk 7 deep (0.08). The width closes in
  steps of two at other places; only the hump's front face (behind the jowls) changes all three at once. The belly
  corners are two broad steps, so nothing terraces under the jaw.
- A long pointed cone of a snout, four tilted blocks in a chain and two forehead blocks on top, overhanging the mouth
  in front by a quarter of the head's length.
- The grin: a long mouth from under the snout back past the eye, its corners turned up, built of shapes, not paint.
  The jaws' edges are skin: a darker olive ridge under the snout that climbs to the corner, a bone ridge along the
  lower jaw. A muted rose gum strip sits a cube inside each edge, the teeth standing on it, a dark throat behind; the
  corner folds back into the cheek as a crease. Teeth big at the front, smaller toward the corner. Slightly open. The
  lower jaw is its own part: a ramus, a level front and a heavy chin with two broad steps under it.
- A small eye set high, under a heavy brow that slants down to the front and comes past it.
- Olive khaki over bone white; the line between them is torn and ragged, from the mouth's corner down and back to the
  tail, kept on the flank's flat side.
- Long side fins swept back like wings, as long as the head, growing like arms from shoulder blades: a raised shoulder
  mass low on each flank behind the gills, sloping down and back, then a thick root (on its own joint buried in the
  shoulder, so its small beat opens no gap) narrowing into the blade; a tall back fin swept back with a ragged trailing edge; a
  big crescent tail, the upper lobe longer; a small second back fin and an anal fin near the tail; small belly fins.
- The one mark, our own: a ring of pale bite punctures on the left flank behind the rider (a bigger animal's bite),
  and torn fins: the back fin's trailing edge, the left side fin's tip and both tail tips.
The rider sits on the hump's back slope, on a plateau two cubes below the crest, so the crest shows ahead;
the back is far too wide for leg slots."""
import math

NAME, ZONE, RARITY = "Megalodon (trial)", "ZONE 8 / VENTS", "LEGENDARY"
U = 0.5
PALETTE = {"olive": "#7F7C4A", "bone": "#EEE7D3", "black": "#16181A", "mouth": "#5E1A26", "tooth": "#FFFFFF", "gum": "#B4646E"}
SHADE = 0.9
SEAT = (-8, 11, 10.4)
FRAME, ORTHO, ORTHO_SWIM = 3.7, 50.0, 58.0
TEXTURES = [{"tile": "stud", "on": "top", "colours": ["olive"]}]  # round studs on the top of the back only

# ---- the body's side and top outlines: (from x on, the value). The back and the belly fall in steps of two cubes; the
# width closes in steps of two; the three never change at one x
TOP = ((-20, 13), (-13, 11), (-4, 9), (5, 7), (13, 5), (21, 4))
BOT = ((-20, -12), (-7, -10), (1, -8), (10, -6), (16, -4), (23, -3))
WIDE = ((-20, 9), (-16, 10), (-1, 8), (9, 6), (17, 4), (24, 3))
JOINTS, START, END = (("S1", -20), ("S2", -5), ("S3", 7), ("S4", 14), ("S5", 20), ("S6", 26)), -20, 31
# the head behind the mouth's corner (from, to, cubes out, bottom, top): the jowls, a step wider than the brows
SKULL = ((-24, -22, 8, -9, 11), (-22, -20, 8, -9, 11))
# the head above the mouth (from, to, cubes out, top): its bottom follows the lip that climbs under it (worked out in build)
BROWS = ((-32, -30, 7, 8), (-30, -28, 7, 8), (-28, -26, 7, 10), (-26, -25, 7, 10), (-25, -24, 7, 10))


def at(table, x):
    return [v for x0, v in table if x0 <= x][-1]


def body():
    cuts = sorted({x for x, _ in TOP + BOT + WIDE} | {x for _, x in JOINTS} | {END})
    assert len({x for x, _ in TOP} & {x for x, _ in BOT} - {START}) == 0
    out = []
    for x0, x1 in zip(cuts, cuts[1:]):
        name = [part for part, x in JOINTS if x <= x0][-1]
        if not out or out[-1][0] != name:
            out.append((name, []))
        out[-1][1].append((x0, x1, at(WIDE, x0), at(BOT, x0), at(TOP, x0)))
    return tuple((name, tuple(slices)) for name, slices in out)


BODY = body()
CHAIN = ["Head"] + [name for name, _ in BODY] + ["Tail"]
AMPLITUDES = [1, 2, 3.5, 5.5, 8, 11, 15]
PITS = ((-1, 1), (0, 3), (2, 4), (4, 4), (6, 3), (7, 1), (6, -1), (4, -2), (2, -2), (0, -1))  # an oval, every other cube
DEPTH = {"shoulders": (at(TOP, -14) - at(BOT, -14)), "stalk": (at(TOP, 28) - at(BOT, 28))}


def steps(n):
    """the corners of the back and the belly: three steps where the body is thick, fewer as it thins"""
    return [(3, 1), (2, 1), (1, 1)] if n >= 8 else ([(2, 1), (1, 1)] if n >= 4 else [(1, 1)])


def belly(n):
    """the belly's corners: two broad steps where the body is thick (no terraces under the jaw and the chest), as many
    rows as the back's"""
    return [(4, 2), (2, 1)] if n >= 8 else steps(n)


def flat_side(bot, top, n):
    """the rows of the flank between the corner steps"""
    k = len(steps(n))
    return bot + k, top - k


# the line between the olive and the bone: bone below this height at each x. It leaves the mouth's corner, falls to the
# lower flank under the side fins and runs back along it to the stalk. Torn and ragged: flaps of uneven width and height
# that climb toward the tail and drop at once, and here and there a deep tear
FALL = ((-24, 0), (-18, -3), (-10, -6), (-2, -7), (6, -6), (14, -4), (22, -2), (31, -1))
FLAPS = ((4, 2), (6, 3), (3, 1), (7, 4), (4, 2), (5, 1), (8, 3), (3, 2), (6, 4), (4, 1), (7, 3), (3, 1), (5, 2))


def fall(x):
    for (xa, za), (xb, zb) in zip(FALL, FALL[1:]):
        if xa <= x <= xb:
            return za + (zb - za) * (x - xa) / (xb - xa)
    return FALL[-1][1]


LINE = {}
_x = -24
for _w, _h in FLAPS * 2:
    for _i in range(_w):
        if _x < END:
            LINE[_x] = round(fall(_x)) + round(_h * _i / max(_w - 1, 1))
        _x += 1


def pose(parts, phase):
    """a heavy, powerful swim: a slow wave side to side that grows toward the great tail, the head turning a little
    against it. The jaw hangs slightly open at rest and closes a little once a beat"""
    parts["Head"].rotation_euler.z = math.radians(1.2) * math.sin(phase + math.pi)
    for k, name in enumerate(CHAIN[1:]):
        parts[name].rotation_euler.z = math.radians(AMPLITUDES[k]) * math.sin(phase - 0.75 * (k + 1))
    parts["Jaw"].rotation_euler.y = math.radians(4) * (0.5 + 0.5 * math.sin(phase))
    beat = math.radians(4) * math.sin(phase + 0.6)  # the side fins lift and dip a little on their shoulder joints
    parts["FinR"].rotation_euler.x = beat
    parts["FinL"].rotation_euler.x = -beat


def slab(p, x0, x1, n, bot, top):
    """a slice of body: stepped corners, olive with a lighter top row, bone below the torn line with a darker bottom row"""
    p.hull(x0, x1, n, bot, top, "olive", steps(n), belly(n))
    p.paint_sym(x0, x1, n, top - 1, top, "olive+")
    lo, hi = flat_side(bot, top, n)
    for x in range(x0, x1):
        p.paint_sym(x, x + 1, n, bot, max(lo, min(hi, LINE[x])), "bone")
    p.paint_sym(x0, x1, n, bot, bot + 1, "bone-")


class Plate:
    """a lip or a jaw: a flat block lying across the head from (x0, z0) to (x1, z1) in the side view"""

    def __init__(self, x0, z0, x1, z1, wide, thick):
        self.x0, self.z0, self.x1, self.z1, self.wide, self.thick = x0, z0, x1, z1, wide, thick
        self.slope = (z1 - z0) / (x1 - x0)
        self.up = math.sqrt(1 + self.slope ** 2)  # one cube across the plate, measured straight up

    def mid(self, x):
        return self.z0 + (x - self.x0) * self.slope

    def top(self, x):
        return self.mid(x) + self.thick / 2 * self.up

    def bottom(self, x):
        return self.mid(x) - self.thick / 2 * self.up

    def add(self, part, colour):
        part.beam((self.x0, 0, self.z0), (self.x1, 0, self.z1), self.wide, self.thick, colour, flat="z")

    def teeth_y(self, size):
        return self.wide / 2 - 0.5 - size / 2


def under(c, x0, x1, thick, wide):
    """a lip plate lying under snout block c from x0 to x1, its top a little inside the block"""
    return Plate(x0, c.bottom(x0) - thick / 2 + 0.12, x1, c.bottom(x1) - thick / 2 + 0.12, wide, thick)


def over(j, x0, x1, thick, wide):
    """a lip plate lying on jaw block j from x0 to x1, its bottom a little inside the block"""
    return Plate(x0, j.top(x0) + thick / 2 - 0.12, x1, j.top(x1) + thick / 2 - 0.12, wide, thick)


def strip(plate, xa, xb, side, wide, show=0.5, thick=0.8):
    """a gum strip along a lip's inner edge: narrower than the lip (set in a cube each side), showing `show` past it
    below the lip (side -1) or above it (+1)"""
    shift = side * (plate.thick / 2 + show - thick / 2) * plate.up
    return Plate(xa, plate.mid(xa) + shift, xb, plate.mid(xb) + shift, wide, thick)


def limb(part, p0, p1, w0, t0, w1, t1, colour):
    """a box lying flat from p0 to p1 that tapers: w0 across and t0 through at p0, w1 and t1 at p1 (a fin's root)"""
    d = [b - a for a, b in zip(p0, p1)]
    length = math.sqrt(sum(v * v for v in d))
    along = [v / length for v in d]
    thin = [r - along[2] * a for a, r in zip(along, (0.0, 0.0, 1.0))]
    n = math.sqrt(sum(v * v for v in thin))
    thin = [v / n for v in thin]
    wide = [along[1] * thin[2] - along[2] * thin[1], along[2] * thin[0] - along[0] * thin[2], along[0] * thin[1] - along[1] * thin[0]]
    verts = []
    for p, w, t in ((p0, w0, t0), (p1, w1, t1)):
        for sw, st in ((-1, -1), (1, -1), (1, 1), (-1, 1)):
            verts.append(tuple(c + sw * a * w / 2 + st * b * t / 2 for c, a, b in zip(p, wide, thin)))
    part.solid(verts, [(0, 1, 2, 3), (4, 5, 6, 7), (0, 1, 5, 4), (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7)], colour)


def build(m):
    # the snout, a long pointed cone: four blocks in a chain, each tilted nose-down, smaller than the last and starting
    # inside it, and two lighter forehead blocks on the first two, so its section steps in like the body's corners.
    # (from, to, the middle's height at each end, width, thickness)
    cone = ((-30.8, -36.0, 1.5, 1.0, 12.0, 7.0), (-35.4, -39.6, 0.9, 0.2, 8.8, 5.8), (-39.0, -42.4, 0.2, -0.5, 5.6, 4.0),
            (-41.9, -44.4, -0.5, -0.9, 2.6, 2.4))
    cones = [Plate(x0, z0, x1, z1, wide, thick) for x0, x1, z0, z1, wide, thick in cone]
    # the upper lip is skin: a ridge of darker olive a little wider than the snout, under it, then a wider one that climbs to the
    # corner behind the eye
    lip1 = under(cones[0], -30.8, -36.0, 1.4, 12.6)
    lip2 = under(cones[1], -35.4, -38.7, 1.3, 9.4)
    rise = Plate(-31.4, lip1.mid(-31.4) - 0.1, -23.6, 1.2, 15.4, 2.4)

    head = m.part("Head", (SKULL[-1][1], 0, 0))
    for x0, x1, n, top in BROWS:  # the head above the mouth: flat underneath, its bottom just inside the climbing lip
        bot = math.floor(rise.top(max(x0, rise.x0)))
        head.hull(x0, x1, n, bot, top, "olive", [(2, 1), (1, 1)], [])
        head.paint_sym(x0, x1, n, top - 1, top, "olive+")
    for s in SKULL:  # the jowls behind the mouth's corner
        slab(head, *s)

    for c in cones:
        c.add(head, "olive")
    for c, x0, x1, wide, thick in ((cones[0], -31.0, -35.6, 9.0, 2.2), (cones[1], -35.0, -39.2, 6.0, 1.6)):
        sink = 0.05
        head.beam((x0, 0, c.top(x0) + thick / 2 - sink), (x1, 0, c.top(x1) + thick / 2 - sink), wide, thick, "olive+", flat="z")

    for plate in (lip1, lip2, rise):  # a tone darker, so the grin's line and its upturn read as a ridge of skin
        plate.add(head, "olive-")
    # the gum: a muted rose strip set a cube inside the skin's edge, the teeth standing on it
    gums = (strip(rise, -24.4, -31.0, -1, 13.6), strip(lip1, -30.6, -35.8, -1, 10.4), strip(lip2, -35.6, -38.2, -1, 7.2))
    for plate in gums:
        plate.add(head, "gum")
    # the dark throat: blocks that stay behind the teeth and end inside the gums and the jaw
    head.block(-38.4, (-2.6, 2.6, -7.6, -3.4), -35.0, (-3.4, 3.4, -7.8, -3.4), "mouth")
    head.block(-35.4, (-3.6, 3.6, -8.0, -3.4), -29.0, (-4.7, 4.7, -8.0, -2.6), "mouth")
    head.block(-29.4, (-4.7, 4.7, -7.9, -2.8), -24.2, (-4.7, 4.7, -3.4, 0.4), "mouth")
    # the upper teeth: big triangles at the front, smaller toward the corner, hanging from the gum, bases sunk in it
    for plate, xs, sizes, longs in ((gums[0], (-25.9, -27.2, -28.5, -29.8), (0.8, 0.9, 1.0, 1.1), (0.8, 1.0, 1.2, 1.4)),
                                    (gums[1], (-31.4, -32.8, -34.3), (1.15, 1.25, 1.35), (1.55, 1.7, 1.9)),
                                    (gums[2], (-35.9, -37.3), (1.4, 1.45), (2.1, 2.2))):
        for x, size, length in zip(xs, sizes, longs):
            head.tooth(x, plate.wide / 2 - 0.35 - size / 2, plate.bottom(x) + 0.25, size, length, "tooth", long=size)
    front = gums[2].bottom(-38.15) + 0.25
    head.tooth(-38.15, 0.0, front, 1.1, 2.3, "tooth", mirror=False, long=0.9)
    head.tooth(-38.15, 1.15, front, 1.1, 2.2, "tooth", long=0.9)
    head.tooth(-38.0, 2.3, front - 0.05, 1.0, 2.0, "tooth", long=0.9)
    # the corner folds in: a dark crease running back from it into the cheek
    head.dent(-23, -21, SKULL[0][2], 0, 1, "olive-")

    # the eye: small and set high on the side of the head, over the grin's rise, under a heavy brow that slants down to
    # the front, cuts across the top of the eye and comes past it: it is mean
    pupil = (7.4, 7.95, 3.4, 5.4)
    head.block(-30.4, pupil, -28.4, pupil, "black", mirror=True)
    head.beam((-32.8, 7.3, 4.8), (-27.4, 7.3, 6.4), 1.8, 2.0, "olive-", mirror=True)

    # the lower jaw, on its own joint at the corner, hanging slightly open: a ramus that climbs to the corner, a level
    # front and a heavy chin, shorter than the snout, with two broad steps under it; a bone lip ridge along its top, the
    # gum strip set inside it; a throat block under the ramus
    jaw = m.part("Jaw", (-24.2, 0, -1.2), "Head")
    ramus = Plate(-29.6, -8.8, -24.0, -1.0, 12.2, 2.6)
    jaw1 = Plate(-28.0, -8.7, -36.0, -9.1, 11.8, 2.0)
    jaw0 = Plate(-35.4, -8.95, -38.0, -9.3, 8.6, 2.6)
    for plate in (ramus, jaw1, jaw0):
        plate.add(jaw, "bone")
    jaw.beam((-29.0, 0, -10.0), (-37.0, 0, -10.5), 9.0, 1.2, "bone", flat="z")  # the chin's two broad steps
    jaw.beam((-30.5, 0, -10.9), (-36.4, 0, -11.3), 5.6, 1.0, "bone-", flat="z")
    jaw.beam((-23.6, 0, -7.4), (-28.4, 0, -8.0), 9.8, 3.0, "bone", flat="z")  # the throat
    lips = (over(ramus, -24.8, -29.2, 1.0, 13.0), over(jaw1, -27.8, -36.2, 1.0, 12.6), over(jaw0, -35.6, -37.8, 0.9, 9.4))
    for plate in lips:
        plate.add(jaw, "bone")
    lgums = (strip(lips[0], -25.0, -29.0, 1, 11.0), strip(lips[1], -28.8, -35.6, 1, 10.6), strip(lips[2], -35.8, -37.6, 1, 7.4))
    for plate in lgums:
        plate.add(jaw, "gum")
    for plate, xs, sizes, longs in ((lgums[1], (-29.6, -31.1, -32.6, -34.1), (0.9, 1.0, 1.1, 1.2), (1.0, 1.2, 1.4, 1.55)),
                                    (lgums[2], (-35.9,), (1.25,), (1.7,))):
        for x, size, length in zip(xs, sizes, longs):
            jaw.tooth(x, plate.wide / 2 - 0.35 - size / 2, plate.top(x) - 0.25, size, -length, "tooth", long=size)
    front = lgums[2].top(-37.15) - 0.25
    jaw.tooth(-37.15, 0.0, front, 1.1, -1.8, "tooth", mirror=False, long=0.75)
    jaw.tooth(-37.15, 1.3, front, 1.1, -1.7, "tooth", long=0.75)

    # the body
    segs, before = {}, SKULL[-1]
    for i, (name, slices) in enumerate(BODY):
        seg = segs[name] = m.part(name, (slices[0][0], 0, 0), "Head" if i == 0 else BODY[i - 1][0])
        for s in slices:
            slab(seg, *s)
        # a sleeve into the piece in front, so a bending joint shows body: sized from the smaller of the two pieces and
        # kept clear of both pieces' corner steps
        x0, _, n, bot, top = slices[0]
        _, _, fn, fbot, ftop = before
        clear = max(len(steps(n)), len(steps(fn)))
        seg.sym(x0 - 1, x0, max(min(n, fn) - 2, 0), max(bot, fbot) + clear, min(top, ftop) - clear, "olive-")
        before = slices[-1]
    s1, s2, s3, s4, s5, s6 = (segs[name] for name, _ in BODY)

    for x in (-19, -17, -15, -13, -11):  # five long gill slits, shallow dents across the line
        j = at(WIDE, x)
        s1.dent(x, x + 1, j, -6, LINE[x], "bone-")
        s1.dent(x, x + 1, j, LINE[x], 5, "olive-")

    # THE MARK, the bite: a ring of pale punctures on the left flank behind the rider, in whole cubes, as shallow pits
    for x, z in PITS:
        seg = s2 if x < 7 else s3
        seg.dent(x, x + 1, -at(WIDE, x), z, z + 1, "bone", pair=False)

    # the back fin: tall, swept back, a base and three boxes, each smaller, thinner and leaning further back. THE MARK's
    # torn trailing edge: each box leaves the one below in front of its rear corner, so the rear edge is notched
    s2.beam((1.2, 0, 7.4), (3.0, 0, 12.4), 8.0, 2.4, "olive")
    s2.beam((2.4, 0, 11.8), (5.0, 0, 15.4), 5.8, 2.0, "olive")
    s2.beam((4.11, 0, 15.25), (6.71, 0, 18.85), 4.2, 1.6, "olive")  # its rear edge set in: a bite out of the trailing edge
    s2.beam((6.0, 0, 18.0), (10.6, 0, 20.8), 3.2, 1.2, "olive")
    s2.beam((10.1, 0, 20.4), (14.0, 0, 21.8), 1.8, 0.9, "olive-")  # the tip split in two ragged points
    s2.beam((10.0, 0, 19.8), (12.8, 0, 20.0), 1.1, 0.6, "olive-")
    # the side fins grow like arms from shoulder blades: a raised shoulder mass low on each flank behind the gills, two
    # blocks lying on the flank and sloping down and back, the outer one prouder
    s1.beam((-10.4, 10.4, -3.0), (-6.0, 10.4, -8.4), 4.6, 2.2, "olive", mirror=True)
    s1.beam((-9.6, 11.0, -4.6), (-6.4, 11.0, -8.2), 3.0, 1.6, "olive", mirror=True)
    # each fin on its own joint, buried in the shoulder: a thick root (three and a half cubes deep where it leaves the
    # shoulder) that narrows into the swept blade, then a thinner blade and the tip. The left one torn: its tip split in
    # two ragged points
    for side, name in ((1, "FinR"), (-1, "FinL")):
        fin = m.part(name, (-8.2, 9.6 * side, -7.0), "S1")
        limb(fin, (-9.4, 8.6 * side, -6.8), (-3.4, 14.8 * side, -10.2), 5.6, 3.6, 4.4, 1.8, "olive")
        fin.beam((-4.4, 13.8 * side, -9.7), (2.6, 19.8 * side, -12.7), 5.2, 1.2, "olive", flat="z")
        if side > 0:
            fin.beam((1.6, 19.0, -12.3), (8.2, 24.0, -14.7), 3.4, 0.7, "olive-", flat="z")
        else:
            fin.beam((1.0, -18.8, -12.1), (5.8, -22.8, -14.2), 2.2, 0.7, "olive-", flat="z")
            fin.beam((2.8, -18.4, -12.5), (6.4, -20.8, -13.7), 1.6, 0.45, "olive-", flat="z")
    # the belly fins, small and swept, two boxes each
    s3.beam((9.0, 3.5, -5.0), (14.0, 7.5, -8.6), 4.2, 1.0, "bone-", flat="z", mirror=True)
    s3.beam((13.2, 7.0, -8.2), (16.4, 9.0, -9.8), 2.4, 0.7, "bone-", flat="z", mirror=True)
    s5.beam((21.0, 0, 2.4), (23.6, 0, 7.0), 3.0, 1.2, "olive")  # the second back fin: small
    s5.beam((21.6, 0, -2.4), (23.8, 0, -5.6), 2.8, 1.1, "bone-")  # the anal fin, as small

    # the tail, on its own joint: a short square stock that carries on from the stalk's flat end, then a huge crescent
    # of two lobes, each in three boxes that sweep back more toward the tip, the upper lobe longer. THE MARK's last torn
    # edges: both lobes end in a ragged tip split in two
    tail = m.part("Tail", (END, 0, 0.5), "S6")
    tail.sym(END, END + 6, 2, -2, 3, "olive")
    tail.sym(END - 1, END, 1, -1, 2, "olive-")  # its sleeve
    tail.beam((34.0, 0, 1.5), (37.0, 0, 9.5), 7.0, 2.2, "olive")
    tail.beam((36.6, 0, 8.6), (39.6, 0, 14.6), 3.8, 1.5, "olive")
    tail.beam((38.58, 0, 13.87), (42.18, 0, 19.47), 2.0, 1.0, "olive-")  # the upper tip split in two ragged points
    tail.beam((39.96, 0, 12.91), (42.36, 0, 16.11), 1.6, 0.7, "olive-")
    tail.beam((34.0, 0, 0.0), (36.8, 0, -6.8), 6.6, 2.0, "olive")
    tail.beam((36.3, 0, -5.8), (39.2, 0, -11.2), 4.6, 1.3, "olive")
    tail.beam((38.7, 0, -10.4), (41.4, 0, -14.4), 2.0, 0.7, "olive-")
    tail.beam((38.4, 0, -10.6), (40.2, 0, -12.6), 1.6, 0.5, "olive-")
