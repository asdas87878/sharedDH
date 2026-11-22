"""The Goblin Shark, a trial of docs/style/10-sharks-round-2.md, for tools/blender/voxel_kit.py. It stands beside the
game's Goblin Shark (art/creatures/GoblinShark) and replaces nothing. Designed from the real animal.
Its idea: the slingshot. A soft, flabby body that sags, a long flat blade of a snout, and under the blade the jaws already
shot out forward and hanging open.
- The body in numbers: about 57 cubes long nose to tail; the back stays nearly level (it never arches) while the belly
  hangs: 11 cubes deep at the sag, just past the middle of the body, and rising steeply behind it to a thin low stock.
  Width 11 at the sag, a soft wide hammock of a belly; the head is low and narrow (7).
- The blade: three flat wide blocks in a chain from the forehead, each thinner and narrower and starting inside the last,
  tilted a little nose-down, with a lighter plate on top. A fifth of the length.
- The jaws: their own part, out in front of the skull under the blade, with a gap between them and the blade. A pale
  corner block at the hinge, a rose membrane reaching back into the throat, an upper jaw in two blocks, and the lower
  jaw (its own part, the Chin) hanging open about 28 degrees in two blocks. A comb of long needle teeth on thin gum lines,
  splayed forward. Once a beat the jaws snap shut and draw back a little, then shoot out again.
- Tiny dark eyes under a short brow. Fins as the animal has them: small rounded side fins, two small rounded back fins
  set well back, big rounded belly and anal fins, and a long low tail with almost no lower lobe.
- Colour: bubblegum pink over pale pink, a straight line low on the flank, so the sag shows pale.
- The one mark: slate-blue edges on every fin, in whole blocks: the outer block of each fin, the tail's tip and its
  lower edge.
The rider sits on the level back in front of the first back fin, legs in a slot either side."""
import math

NAME, ZONE, RARITY = "Goblin Shark (trial)", "ZONE 6 / TWILIGHT", "EPIC"
U = 0.45
SHADE = 0.9
PALETTE = {"pink": "#F58BB6", "belly": "#FCDCE6", "slate": "#5A7BA3", "black": "#2A2530", "mouth": "#6E2440", "gum": "#C9557A",
           "tooth": "#FFFFFF"}
SEAT = (-5, 4, 4.6)
FRAME, ORTHO = 2.1, 31.0
TEXTURES = [{"tile": "stud", "on": "top", "colours": ["pink"]}]

LINE = -1  # pale pink below this height, everywhere: low and straight, so the sagging belly shows as the pale shape
# the body in slices (from, to, cubes out, bottom, top). One number changes from one slice to the next
SKULL = ((-19, -17, 3, -2, 2), (-17, -15, 3, -2, 3), (-15, -12, 3, -3, 3))
BODY = (("S1", ((-12, -10, 4, -3, 3), (-10, -8, 4, -4, 3), (-8, -6, 4, -4, 4))),
        ("S2", ((-6, -4, 4, -5, 4), (-4, -2, 5, -5, 4), (-2, 0, 5, -6, 4))),
        ("S3", ((0, 4, 5, -7, 4), (4, 6, 5, -6, 4))),  # the sag: the deepest slice
        ("S4", ((6, 8, 5, -6, 3), (8, 10, 5, -5, 3), (10, 12, 4, -5, 3))),
        ("S5", ((12, 13, 4, -4, 3), (13, 14, 3, -4, 3), (14, 15, 3, -3, 3), (15, 16, 3, -3, 2), (16, 17, 2, -3, 2))))
STOCK = (17, 19, 1, -2, 2)  # the tail's stock
CHAIN = ["Head", "S1", "S2", "S3", "S4", "S5", "Tail"]
AMPLITUDES = [2, 3.5, 5.5, 8, 12, 17]
JAW_PIVOT = (-17.0, 0.0, -38.0)  # far below the jaw: a small turn about it is a slide
JAW_BACK = 1.6  # cubes the jaws draw back when they snap
HINGE = (-16.9, 0.0, -3.9)  # the chin's hinge, in the corner block
SNAP = 10  # degrees the chin closes
DROP = 0.25  # how far a gum line shows past its lip


def pose(parts, phase):
    """a shark's swim, side to side down the chain; once a beat the jaws snap shut and draw back, then shoot out again"""
    parts["Head"].rotation_euler.z = math.radians(2) * math.sin(phase + math.pi)
    for k, name in enumerate(CHAIN[1:]):
        parts[name].rotation_euler.z = math.radians(AMPLITUDES[k]) * math.sin(phase - 0.9 * (k + 1))
    snap = (0.5 + 0.5 * math.sin(phase)) ** 3
    parts["Jaw"].rotation_euler.y = math.asin(JAW_BACK / (-2.4 - JAW_PIVOT[2])) * snap
    parts["Chin"].rotation_euler.y = math.radians(SNAP) * snap


def steps(n):
    """the corners: two broad steps where the body is thick, one where it is thin, none on the tail's stock"""
    if n >= 5:
        return [(3, 1), (1, 1)]
    return [(2, 1), (1, 1)] if n >= 4 else ([(1, 1)] if n >= 2 else [])


def clear(n):
    return sum(tall for _, tall in steps(n))


def slab(p, x0, x1, n, bot, top):
    """a length of body: stepped corners, a lighter top row, pale pink below the line with a darker bottom row"""
    p.hull(x0, x1, n, bot, top, "pink", steps(n), steps(n))
    p.paint_sym(x0, x1, n, top - 1, top, "pink+")
    p.paint_sym(x0, x1, n, bot, LINE, "belly")
    if bot <= -3:
        p.paint_sym(x0, x1, n, bot, bot + 1, "belly-")


class Jaw:
    """a jaw block lying flat, from (x0, z0) to (x1, z1) in the side view"""

    def __init__(self, x0, z0, x1, z1, wide, thick):
        self.x0, self.z0, self.x1, self.z1, self.wide, self.thick = x0, z0, x1, z1, wide, thick
        self.up = math.sqrt(1 + ((z1 - z0) / (x1 - x0)) ** 2)  # one cube across the block, measured straight up

    def mid(self, x):
        return self.z0 + (self.z1 - self.z0) * (x - self.x0) / (self.x1 - self.x0)

    def edge(self, x, side):
        """the underside (side -1) or the top (side 1) at x"""
        return self.mid(x) + side * self.thick / 2 * self.up

    def add(self, part, colour):
        part.beam((self.x0, 0, self.z0), (self.x1, 0, self.z1), self.wide, self.thick, colour, flat="z")

    def gum(self, part, side, a, b):
        """a thin rose line set inside the lip's edge, showing DROP past it on the mouth's side of the jaw"""
        shift = side * (self.thick / 2 + DROP / 2 - 0.05) * self.up
        part.beam((a, 0, self.mid(a) + shift), (b, 0, self.mid(b) + shift), self.wide - 0.7, DROP + 0.1, "gum", flat="z")

    def gum_edge(self, x, side):
        return self.edge(x, side) + side * DROP * self.up


def fin(part, p0, p1, wide, thick, q1, edge_wide, edge_thick, flat="y", mirror=False):
    """a fin: a pink box from p0 to p1, and its slate edge, a smaller, thinner box that starts inside it and runs on to q1"""
    part.beam(p0, p1, wide, thick, "pink", flat=flat, mirror=mirror)
    start = tuple(a + 0.72 * (b - a) for a, b in zip(p0, p1))
    part.beam(start, q1, edge_wide, edge_thick, "slate", flat=flat, mirror=mirror)


def build(m):
    head = m.part("Head", (-12, 0, 0))
    for s in SKULL:
        slab(head, *s)
    # the blade: three flat wide blocks in a chain from the forehead, each tilted a little nose-down, thinner and narrower
    # than the last and starting inside it. A lighter plate runs along the top of the first two
    blades = ((-18.4, -24.4, 1.05, 0.55, 5.4, 1.8, 3.0, -18.9), (-23.6, -27.6, 0.6, 0.3, 4.0, 1.25, 2.2, -23.2),
              (-27.0, -29.6, 0.32, 0.12, 2.8, 0.8, 0.0, 0.0))
    for x0, x1, z0, z1, wide, thick, plate, plate_from in blades:
        head.beam((x0, 0, z0), (x1, 0, z1), wide, thick, "pink", flat="z")
        if plate:
            def top(x):
                return z0 + (z1 - z0) * (x - x0) / (x1 - x0) + thick / 2 + 0.2

            head.beam((plate_from, 0, top(plate_from)), (x1 + 0.6, 0, top(x1 + 0.6)), plate, 0.5, "pink+", flat="z")
    # the eye: tiny and dark, on the side of the skull behind the blade's root, under a short level brow that comes past it
    head.block(-17.1, (3.3, 3.8, 0.1, 1.0), -16.2, (3.3, 3.8, 0.1, 1.0), "black", mirror=True)
    head.beam((-17.6, 3.6, 1.0), (-15.7, 3.6, 1.3), 0.6, 0.8, "pink", mirror=True)
    for x in (-15, -13):  # gill slits, low on the skull
        head.dent(x, x + 1, 3, -2, 1, "pink-")

    # THE JAWS, out in front of the skull under the blade. A pale corner block at the hinge; a rose membrane behind it,
    # reaching back into the throat and showing under the skull; the upper jaw in two blocks
    jaw = m.part("Jaw", JAW_PIVOT, "Head")
    jaw.block(-18.3, (-2.7, 2.7, -4.4, -2.1), -15.7, (-2.7, 2.7, -4.2, -1.8), "belly")
    jaw.block(-16.1, (-2.2, 2.2, -3.75, -2.25), -12.4, (-2.0, 2.0, -3.55, -2.45), "gum")
    up1, up2 = Jaw(-17.2, -2.65, -21.9, -2.95, 4.7, 0.85), Jaw(-21.3, -2.92, -23.9, -3.08, 3.0, 0.5)
    for j in (up1, up2):
        j.add(jaw, "belly")
    up1.gum(jaw, -1, -18.0, -21.6)
    up2.gum(jaw, -1, -22.05, -23.6)
    # the lower jaw, its own part: hinged in the corner block, hanging open, in two blocks
    chin = m.part("Chin", HINGE, "Jaw")
    chin.block(-17.9, (-2.45, 2.45, -4.75, -3.3), -16.0, (-2.45, 2.45, -4.55, -3.3), "belly")
    lo1, lo2 = Jaw(-17.2, -4.15, -21.6, -6.45, 4.5, 0.85), Jaw(-21.0, -6.2, -23.3, -7.25, 2.9, 0.5)
    for j in (lo1, lo2):
        j.add(chin, "belly")
    lo1.gum(chin, 1, -18.0, -21.3)
    lo2.gum(chin, 1, -21.3, -23.0)
    # the dark inside: a wedge between the jaws whose edges end inside them, so the gape shows dark from the side and the
    # front. In two halves that overlap, one on each jaw, so neither shows outside the mouth when the chin snaps up
    jaw.block(-18.5, (-2.0, 2.0, -3.9, -2.8), -22.4, (-1.25, 1.25, -4.9, -3.0), "mouth")
    chin.block(-18.25, (-1.85, 1.85, -4.65, -3.6), -22.25, (-1.1, 1.1, -6.65, -4.6), "mouth")
    # a comb of needle teeth, long and thin, splayed a little forward, their bases sunk in the gums. Longer where the gape
    # is wide; a pair across the front of each jaw
    for j, x, y, long in ((up1, -18.3, 1.65, 0.75), (up1, -19.2, 1.65, 0.95), (up1, -20.1, 1.65, 1.1), (up1, -21.0, 1.65, 1.25),
                          (up2, -22.3, 0.85, 1.3), (up2, -22.95, 0.8, 1.35), (up2, -23.35, 0.33, 1.35)):
        jaw.tooth(x, y, j.gum_edge(x, -1) + 0.17, 0.42, long, "tooth", lean=(-0.35, 0.1))
    for j, x, y, long in ((lo1, -18.75, 1.55, 0.6), (lo1, -19.65, 1.55, 0.8), (lo1, -20.55, 1.55, 0.95), (lo2, -21.75, 0.8, 1.05),
                          (lo2, -22.4, 0.8, 1.1), (lo2, -22.8, 0.3, 1.1)):
        chin.tooth(x, y, j.gum_edge(x, 1) - 0.17, 0.42, -long, "tooth", lean=(-0.35, 0.1))

    # the body
    front, parent, segs = SKULL[-1], "Head", {}
    for name, lengths in BODY:
        seg = segs[name] = m.part(name, (lengths[0][0], 0, 0), parent)
        for span in lengths:
            slab(seg, *span)
        # a sleeve one cube into the piece in front, sized from the smaller of the two and clear of both pieces' steps
        x0, _, n, bot, top = lengths[0]
        fn, fbot, ftop = front[2:]
        gap = max(clear(n), clear(fn))
        seg.sym(x0 - 1, x0, max(min(n, fn) - 2, 0), max(bot, fbot) + gap, min(top, ftop) - gap, "pink-")
        front, parent = lengths[-1], name
    s1, s2, s3, s4, s5 = (segs[name] for name, _ in BODY)
    s2.dent(-6, -4, 4, 0, 2, "pink-")  # the rider's leg slots

    # the fins, each a pink box and its slate edge (THE MARK)
    fin(s1, (-10.4, 3.0, -2.6), (-7.6, 6.4, -3.6), 3.0, 0.9, (-6.0, 7.9, -4.2), 2.2, 0.55, flat="z", mirror=True)  # side fins: small
    fin(s3, (2.6, 0, 3.4), (5.0, 0, 5.4), 3.0, 1.1, (6.4, 0, 6.2), 2.0, 0.7)  # the first back fin: small, rounded, set back
    fin(s5, (12.2, 0, 2.4), (14.2, 0, 4.2), 2.6, 0.95, (15.4, 0, 4.9), 1.7, 0.6)  # the second, as small
    fin(s3, (3.6, 2.2, -5.6), (6.6, 4.6, -7.6), 3.4, 0.9, (8.2, 5.8, -8.4), 2.4, 0.55, flat="z", mirror=True)  # belly fins: big
    fin(s4, (9.4, 0, -4.4), (12.8, 0, -6.2), 3.4, 1.1, (14.6, 0, -6.8), 2.4, 0.7)  # the anal fin: big and low

    # the tail, on its own joint: a thin stock, a long low upper lobe in three boxes (the last slate), and under it only a
    # thin slate fringe for a lower lobe
    tail = m.part("Tail", (STOCK[0], 0, 0), "S5")
    slab(tail, *STOCK)
    tail.sym(STOCK[0] - 1, STOCK[0], 0, -1, 1, "pink-")
    tail.beam((18.0, 0, 0.6), (22.6, 0, 2.2), 3.4, 1.3, "pink")
    tail.beam((21.9, 0, 1.95), (25.6, 0, 3.3), 2.6, 0.9, "pink")
    tail.beam((25.0, 0, 3.05), (27.6, 0, 4.1), 1.8, 0.55, "slate")
    tail.beam((18.6, 0, -0.9), (24.4, 0, 1.25), 1.0, 0.65, "slate")
