"""The Hellfin Shark, a trial of docs/style/10-sharks-round-2.md, for tools/blender/voxel_kit.py. It stands beside the
game's Hellfin Shark (art/creatures/HellfinShark) and replaces nothing. Designed from the real tiger shark.
Its idea: the tiger. A broad, blunt, square snout; a deep head and shoulders; a thick body that holds its depth well
past the back fin; a long sickle of an upper tail lobe over a short lower one.
- The body in numbers: about 74 cubes long; the body alone is 19 deep at the shoulders (0.26 of the length) and 17 wide
  (0.23), deepest from the back of the head to the back fin, a quarter of the way back; the upper tail lobe is 21 cubes
  along, the lower one 8.
- The snout is three wide flat blocks in a chain, barely narrowing, so seen from above the head ends square; a lighter
  plate rides on the first two so its top is rounded in a broad step.
- The mouth is a wide jagged grin: an upper lip that runs level under the snout and then climbs to a corner under the
  eye, a lower jaw close under it (the mouth only slightly open), a thin red gum line set inside both, and uneven teeth:
  long and short in turn, leaning back toward the corners, like a tiger shark's cockscombs.
- A small dark pupil in a thin ember ring under a heavy brow that comes past it.
- Colour: charcoal over a pale ash grey, the line straight and low along the flank's flat side, rising with the belly
  toward the tail. The upper lip and the lower jaw are ash, so the grin is drawn in pale.
- The one mark: glowing ember tiger stripes across the back, each a bar that streams back at the spine and thins down
  the flank, long and short in turn, closer together toward the tail; they run out onto the fins as burning trailing
  edges that step like a flame (the last box of the big fins is all ember).
The rider sits on the flat of the shoulders in front of the back fin, in a gap between two stripes; the back is
wide enough that it needs no leg slots."""
import math

NAME, ZONE, RARITY = "Hellfin Shark (trial)", "ZONE 10 / THE UNDERWORLD", "LEGENDARY"
U = 0.45
PALETTE = {"char": "#3B3741", "ash": "#B4AAA8", "ember": "#FF7A1E", "black": "#16141A", "mouth": "#6E1E24", "gum": "#D8505A",
           "tooth": "#F6EFE2"}
SHADE = 0.9
SEAT = (-6, 10, 8.5)
GLOW = {"ember": 0.9}  # the stripes, the burning fin edges and the ring of the eye
TEXTURES = [{"tile": "stud", "on": "top", "colours": ["char"]}]  # studs on the dark back only
FRAME, ORTHO, ORTHO_SWIM = 2.8, 41.0, 47.0
SWIM = {"chain": ["Head", "S1", "S2", "S3", "S4", "S5", "Tail"], "amplitudes": [1.5, 3, 5, 8, 12, 18], "phaseStep": 0.8,
        "headCounter": 2}
DROP = 0.25  # how far a gum plate shows past its lip

# the head above the mouth (its bottom is the lip's line, climbing to the corner), then the head behind the corner
BROWS = ((-22, -20, 7, -1, 7), (-20, -18, 7, 0, 7), (-18, -16, 7, 1, 7))
SKULL = ((-16, -14, 7, -8, 8), (-14, -12, 8, -9, 9))
# the body in slabs (from, to, cubes out, bottom, top): deep and thick to the back fin, then a steady taper
BODY = (("S1", ((-12, -9, 8, -10, 9), (-9, -3, 8, -10, 10))),  # the shoulders and the seat, the back arching up
        ("S2", ((-3, 3, 8, -10, 10), (3, 6, 8, -9, 9), (6, 9, 7, -9, 8))),  # the back fin
        ("S3", ((9, 12, 7, -8, 8), (12, 15, 6, -7, 7))),
        ("S4", ((15, 18, 5, -6, 6), (18, 21, 4, -5, 5))),
        ("S5", ((21, 24, 3, -4, 4), (24, 26, 2, -3, 3))))  # the stalk
# the stripes: (front column, how many rows down from the top the stripe reaches). Long and short in turn, closer
# toward the tail. None on the seat (x -9 to -4)
STRIPES = ((-11, 12), (-2, 9), (4, 12), (9, 9), (13, 10), (17, 6), (21, 5))


def steps(n):
    """the corners of the back and the belly: three broad steps where the body is thick, fewer as it thins"""
    if n >= 8:
        return [(4, 1), (2, 1), (1, 1)]
    if n == 7:
        return [(3, 1), (2, 1), (1, 1)]
    return [(2, 1), (1, 1)] if n >= 4 else [(1, 1)]


def clear(n):
    return sum(tall for _, tall in steps(n))


def line(x, bot):
    """the top of the ash at column x: low and level on the flank's flat side, rising with the belly to the tail"""
    if x < -14:
        return -2
    return max(-4, bot + 2)


def slab(p, x0, x1, n, bot, top):
    """a slice of body: stepped corners, charcoal with a lighter top row, ash below the line with a darker bottom row"""
    p.hull(x0, x1, n, bot, top, "char", steps(n), steps(n))
    p.paint_sym(x0, x1, n, top - 1, top, "char+")
    for x in range(x0, x1):
        p.paint_sym(x, x + 1, n, bot, line(x, bot), "ash")
    p.paint_sym(x0, x1, n, bot, bot + 1, "ash-")


def stripe(p, slabs, x0, reach):
    """one ember tiger stripe on the cubes of this piece: a bar two cubes wide that streams one cube back over the spine
    and ends in a point one cube wide for its last two rows, `reach` rows under the top, never into the ash"""
    tops = {x: (top, bot) for a, b, _, bot, top in slabs for x in range(a, b)}
    for (i, j, k), colour in list(p.cells.items()):
        if i not in tops or not colour.startswith("char"):
            continue
        top, bot = tops[i]
        if k < max(top - reach, line(i, bot) + 1):
            continue
        if k >= top - 2:
            ok = x0 + 1 <= i <= x0 + 2
        elif k >= top - reach + 2:
            ok = x0 <= i <= x0 + 1
        else:
            ok = i == x0
        if ok:
            p.cells[(i, j, k)] = "ember"


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

    def gum(self, part, xa, xb, side):
        """a thin red plate set in from the lip's edge, showing DROP past it: below the lip (side -1) or above (+1)"""
        shift = side * (self.thick / 2 + DROP / 2 - 0.05) * self.up
        part.beam((xa, 0, self.mid(xa) + shift), (xb, 0, self.mid(xb) + shift), self.wide - 0.8, DROP + 0.1, "gum", flat="z")

    def gum_edge(self, x, side):
        return (self.bottom(x) - DROP * self.up) if side < 0 else (self.top(x) + DROP * self.up)

    def teeth_y(self, size):
        return self.wide / 2 - 0.4 - size / 2


def under(beam, thick, x0, x1, wide, plate_thick, sink=0.3):
    """a plate lying under a snout block (its axis from beam[0] to beam[1] as (x, z), `thick` through), sunk into it"""
    (bx0, bz0), (bx1, bz1) = beam
    slope = (bz1 - bz0) / (bx1 - bx0)
    up = math.sqrt(1 + slope ** 2)

    def mid(x):
        return bz0 + (x - bx0) * slope - (thick / 2 + plate_thick / 2 - sink) * up

    return Plate(x0, mid(x0), x1, mid(x1), wide, plate_thick)


def fin(p, a, b, wide, thick, colour, edge=0.0, split=0.0, flat="y", mirror=False):
    """one box of a fin from a to b. edge: an ember blade lies in its trailing side and shows `edge` behind it; it is
    thinner than the box and stops short of the box's end. split: from that share of the box's length on, the blade shows
    only half as far. So a fin's burning edge goes up in steps, like a flame"""
    p.beam(a, b, wide, thick, colour, flat=flat, mirror=mirror)
    if not edge:
        return
    d = [q - s for s, q in zip(a, b)]
    length = math.sqrt(sum(v * v for v in d))
    along = [v / length for v in d]
    ref = (0.0, 1.0, 0.0) if flat == "y" else (0.0, 0.0, 1.0)
    dot = sum(s * r for s, r in zip(along, ref))
    thin = [r - dot * s for s, r in zip(along, ref)]
    size = math.sqrt(sum(v * v for v in thin))
    thin = [v / size for v in thin]
    back = [x - along[0] * s - thin[0] * t for x, s, t in zip((1.0, 0.0, 0.0), along, thin)]  # toward the tail, across the box
    size = math.sqrt(sum(v * v for v in back))
    back = [v / size for v in back]
    runs = [(0.3, split * length, edge), (split * length, length - 0.5, edge / 2)] if split else [(0.3, length - 0.5, edge)]
    for t0, t1, show in runs:
        across = show + 0.8
        off = wide / 2 + show - across / 2
        p0 = tuple(s + t0 * al + off * bk for s, al, bk in zip(a, along, back))
        p1 = tuple(s + t1 * al + off * bk for s, al, bk in zip(a, along, back))
        p.beam(p0, p1, across, thick - 0.3, "ember", flat=flat, mirror=mirror)


def build(m):
    head = m.part("Head", (-12, 0, 0))
    for x0, x1, n, bot, top in BROWS:  # the head above the mouth: flat underneath, where the lip covers it
        head.hull(x0, x1, n, bot, top, "char", steps(n), [])
        head.paint_sym(x0, x1, n, top - 1, top, "char+")
    for s in SKULL:  # the head behind the mouth's corner: the jowls, as deep as the body
        slab(head, *s)

    # THE SNOUT: broad, blunt and square. Three wide flat blocks in a chain, each tilted a little nose-down, a step lower
    # and only a little narrower than the last, the last a short blunt cap; a lighter plate on the first two rounds the top
    snout = (((-21.0, 2.2), (-26.6, 1.6), 12.6, 7.0), ((-25.9, 1.45), (-29.2, 0.95), 11.2, 5.6), ((-28.8, 0.8), (-30.2, 0.65), 9.2, 4.4))
    for (a, b, wide, thick) in snout:
        head.beam((a[0], 0, a[1]), (b[0], 0, b[1]), wide, thick, "char", flat="z")
    head.beam((-21.0, 0, 5.85), (-25.8, 0, 5.15), 10.2, 1.6, "char+", flat="z")
    head.beam((-25.3, 0, 4.4), (-28.6, 0, 3.7), 8.6, 1.4, "char+", flat="z")

    # THE MOUTH. The upper lip: three ash plates under the snout blocks, then a wider one that climbs to the corner under
    # the eye. The lower jaw sits close under it: a chin and a level front, and the ramus that climbs to the same corner
    lip1 = under(snout[0][:2], 7.0, -21.6, -26.4, 12.1, 1.4)
    lip2 = under(snout[1][:2], 5.6, -25.9, -28.9, 10.7, 1.2)
    lip3 = under(snout[2][:2], 4.4, -28.5, -29.7, 8.0, 1.0)
    rise = Plate(-22.6, -1.9, -15.8, 1.6, 14.4, 1.6)
    jaw1, jaw0 = Plate(-19.6, -5.55, -26.4, -5.85, 11.7, 1.8), Plate(-25.8, -6.2, -28.7, -6.4, 9.5, 1.5)
    ramus = Plate(-21.0, -6.1, -15.6, -0.6, 13.9, 2.6)
    for plate in (lip1, lip2, lip3, rise, jaw1, jaw0, ramus):
        plate.add(head, "ash")
    head.beam((-12.8, 0, -5.6), (-19.5, 0, -6.3), 12.4, 4.6, "ash", flat="z")  # the throat: one broad step under the jaw, over the skull's corner steps
    # the dark inside: blocks that stay behind the teeth and end inside the lips and the jaw
    head.block(-28.4, (-2.8, 2.8, -5.0, -2.6), -26.0, (-3.4, 3.4, -5.1, -2.6), "mouth")
    head.block(-26.3, (-3.7, 3.7, -5.2, -2.5), -20.6, (-4.6, 4.6, -5.2, -2.0), "mouth")
    head.block(-21.0, (-4.9, 4.9, -5.0, -1.7), -16.6, (-4.9, 4.9, -1.0, 0.9), "mouth")
    # the gums: a thin red line set inside both lips
    lip1.gum(head, -21.8, -26.1, -1)
    lip2.gum(head, -26.0, -28.4, -1)
    lip3.gum(head, -28.45, -29.45, -1)
    rise.gum(head, -21.9, -16.8, -1)
    jaw1.gum(head, -20.0, -26.1, 1)
    jaw0.gum(head, -26.0, -28.4, 1)
    ramus.gum(head, -20.6, -16.8, 1)
    # the teeth: uneven, long and short in turn, leaning back toward the corners, bases sunk in the gums
    lean = (0.3, 0.0)
    for plate, sink, row in ((rise, 0.3, ((-17.9, 0.8, 0.7), (-19.0, 1.1, 1.15), (-20.2, 0.9, 0.8), (-21.4, 1.15, 1.2))),
                             (lip1, 0.15, ((-22.7, 0.9, 0.75), (-23.9, 1.15, 1.2), (-25.1, 0.85, 0.8))),
                             (lip2, 0.15, ((-26.3, 1.1, 1.1), (-27.5, 0.85, 0.75)))):
        for x, size, long in row:
            head.tooth(x, plate.teeth_y(size), plate.gum_edge(x, -1) + sink, size, long, "tooth", lean=lean, long=0.95)
    front = lip3.gum_edge(-28.95, -1) + 0.15
    head.tooth(-28.95, 0.0, front, 1.0, 1.1, "tooth", mirror=False, long=0.8)
    head.tooth(-28.95, 1.1, front, 0.85, 0.75, "tooth", long=0.8)
    head.tooth(-28.95, 2.2, front, 1.05, 1.15, "tooth", long=0.8)
    # below, set between the upper ones
    for plate, row in ((jaw1, ((-20.4, 0.8, 0.65), (-21.6, 1.0, 1.0), (-22.8, 0.8, 0.65), (-24.0, 1.05, 1.05), (-25.2, 0.8, 0.7))),
                       (jaw0, ((-26.5, 1.0, 0.95), (-27.6, 0.8, 0.65)))):
        for x, size, long in row:
            head.tooth(x, plate.teeth_y(size), plate.gum_edge(x, 1) - 0.15, size, -long, "tooth", lean=lean, long=0.9)
    front = jaw0.gum_edge(-27.95, 1) - 0.15
    head.tooth(-27.95, 0.55, front, 0.9, -0.9, "tooth", long=0.8)
    head.tooth(-27.95, 1.65, front, 0.8, -0.65, "tooth", long=0.8)

    # the eye: a thin ember ring on the side of the head over the lip, a dark pupil standing out of it, under a heavy brow
    # that slants down to the front, cuts the top of the eye and comes past it
    ring = (7.3, 7.8, 1.0, 3.4)
    head.block(-21.2, ring, -18.4, ring, "ember", mirror=True)
    pupil = (7.55, 8.05, 1.55, 2.95)
    head.block(-20.4, pupil, -19.0, pupil, "black", mirror=True)
    head.beam((-22.6, 7.3, 3.15), (-17.8, 7.3, 4.15), 1.8, 1.8, "char", mirror=True)

    segs, before = {}, SKULL[-1]
    for i, (name, slabs) in enumerate(BODY):
        seg = segs[name] = m.part(name, (slabs[0][0], 0, 0), "Head" if i == 0 else BODY[i - 1][0])
        for s in slabs:
            slab(seg, *s)
        for x0, reach in STRIPES:
            stripe(seg, slabs, x0, reach)
        # a sleeve into the piece in front, so a bending joint shows body: sized from the smaller of the two pieces and
        # kept clear of both pieces' corner steps
        x0, _, n, bot, top = slabs[0]
        _, _, fn, fbot, ftop = before
        gap = max(clear(n), clear(fn))
        seg.sym(x0 - 1, x0, max(min(n, fn) - 2, 0), max(bot, fbot) + gap, min(top, ftop) - gap, "char-")
        before = slabs[-1]
    s1, s2, s3, s4, s5 = (segs[name] for name, _ in BODY)

    # the fins: each a few boxes at an angle, every box smaller and thinner than the one before and starting inside it,
    # with a darker collar round the root of the big ones. The trailing edges burn; the last box of the big ones is ember
    s2.beam((-0.78, 0, 8.18), (2.64, 0, 12.36), 8.0, 2.8, "char-")  # the back fin: on the shoulders, behind the seat
    fin(s2, (-0.6, 0, 8.4), (4.8, 0, 15.0), 7.4, 2.2, "char", edge=1.1, split=0.78)
    fin(s2, (3.7, 0, 13.8), (6.9, 0, 18.6), 5.0, 1.5, "char", edge=0.9, split=0.62)
    s2.beam((5.8, 0, 17.4), (8.0, 0, 20.6), 3.4, 0.8, "ember")
    s1.beam((-10.69, 5.37, -5.96), (-7.41, 9.32, -6.69), 7.4, 2.0, "char-", flat="z", mirror=True)  # the side fins: broad sickles
    fin(s1, (-10.5, 5.6, -6.0), (-4.2, 13.2, -7.4), 7.0, 1.6, "char", edge=1.1, split=0.85, flat="z", mirror=True)
    fin(s1, (-5.1, 11.9, -7.2), (-1.0, 17.4, -8.1), 5.0, 1.0, "char", edge=1.1, split=0.62, flat="z", mirror=True)
    s1.beam((-2.2, 16.0, -7.95), (0.8, 20.0, -8.6), 3.4, 0.4, "ember", flat="z", mirror=True)
    fin(s3, (11.6, 2.8, -6.2), (15.0, 5.6, -9.2), 3.0, 0.9, "char", edge=0.6, flat="z", mirror=True)  # the belly fins
    fin(s5, (21.4, 0, 3.0), (23.8, 0, 6.1), 2.7, 1.3, "char", edge=0.6)  # the second back fin
    s5.beam((22.7, 0, 5.0), (24.6, 0, 7.4), 2.0, 0.7, "ember")
    fin(s5, (21.4, 0, -3.0), (23.8, 0, -6.1), 2.7, 1.3, "char", edge=0.6)  # the anal fin
    s5.beam((22.7, 0, -5.0), (24.6, 0, -7.4), 2.0, 0.7, "ember")

    # the tail, on its own joint: a root block, a long upper lobe in three boxes that sweep back flatter toward a long
    # pointed tip, and a short lower lobe in two
    tail = m.part("Tail", (26, 0, 0.5), "S5")
    tail.beam((25.4, 0, 0.3), (29.4, 0, 0.9), 4.0, 2.6, "char")
    fin(tail, (27.8, 0, 1.2), (33.0, 0, 7.6), 5.4, 2.0, "char", edge=1.0, split=0.68)
    fin(tail, (32.0, 0, 6.6), (37.6, 0, 11.6), 4.0, 1.4, "char", edge=0.9, split=0.62)
    tail.beam((36.6, 0, 10.9), (42.2, 0, 14.2), 2.8, 0.8, "char")
    tail.beam((41.3, 0, 13.6), (44.0, 0, 15.0), 1.8, 0.4, "ember")
    fin(tail, (27.8, 0, -0.2), (31.4, 0, -5.0), 4.6, 1.4, "char", edge=0.9, split=0.66)
    tail.beam((30.5, 0, -4.0), (32.8, 0, -7.4), 3.0, 0.6, "ember")
