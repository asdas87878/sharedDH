"""The Moray Eel, a trial of docs/style/09-early-remodels.md, for tools/blender/voxel_kit.py. It stands beside the game's
Moray Eel (art/creatures/MorayEel) and replaces nothing. Designed from the real animal, a ribbon eel (a moray).
Its idea: the ribbon with the jaws.
- The body is a tall thin ribbon: 5 cubes deep and 3 wide for most of its length, in short slices on joints so it bends
  in an S, thinning only in the last fifth to a blade. Flat-sided and flat-backed, a stepped belly.
- The head is bigger than the body: 7 cubes deep at the jaw's hinge and a sixth of the length; behind it the neck steps
  down to the ribbon, one cube at a time.
- The face: the jaws hang open. A long upper jaw in two blocks, and a lower jaw dropped about 25 degrees below it, also in
  two blocks, on its own joint. Needle teeth, seven a side top and bottom, on a thin gum line set inside the lips; the
  inside of the mouth dark red. Two leaf-shaped nostril flaps standing up at the snout's tip. A small pale eye with a dark
  pupil under a brow that comes past it in front.
- Electric blue all over. The one mark, yellow: a crest fin one cube thick and about 2 high running unbroken from behind
  the head to the tail's tip (only a low line under the rider), and the whole lower jaw.
The rider sits on the neck just behind the head, legs in a shallow slot either side."""
import math

NAME, ZONE, RARITY = "Moray Eel (trial)", "ZONE 2 / CORAL REEF", "RARE"
U = 0.4
PALETTE = {"blue": "#1E6BF0", "yellow": "#FFD426", "mouth": "#5A1420", "gum": "#A8324A", "tooth": "#FFFFFF",
           "white": "#EEF2F5", "black": "#14171C"}
SHADE = 0.9
SEAT = (-16.5, 4, 2.5)
FRAME, ORTHO, ORTHO_SWIM = 1.9, 26.0, 28.0
TEXTURES = [{"tile": "stud", "on": "top", "colours": ["blue"]}]
DROP = 0.3  # how far a gum plate shows past its lip

SKULL = (-21, -18, 2, -3, 4)  # (from, to, cubes out, bottom, top): 7 deep at the hinge, 5 wide
# the body: each slice is (from, to, cubes out, bottom, top). One number changes from slice to slice, never two
SLICES = ((-18, -15, 2, -2, 4),  # the neck, the seat
          (-15, -12, 1, -2, 4),
          (-12, -8, 1, -2, 3),  # the ribbon: 5 deep, 3 wide
          (-8, -4, 1, -2, 3), (-4, 0, 1, -2, 3), (0, 4, 1, -2, 3), (4, 8, 1, -2, 3), (8, 12, 1, -2, 3), (12, 16, 1, -2, 3),
          (16, 19, 1, -1, 3),  # the last fifth thins
          (19, 22, 1, -1, 2))
SEAT_SLICE = 0
CHAIN = [f"S{i + 1}" for i in range(len(SLICES))] + ["Tail"]
AMPLITUDES = [2, 3, 4, 6, 8, 10, 11, 12, 13, 14, 16, 19]
STEP = 0.6
# the crest's top line (x, z): low under the rider, rising behind him, level along the ribbon, falling to the tail
CREST = ((-15, 4.3), (-13.8, 5.6), (-10, 5.0), (19, 5.0), (22, 4.0))


def crest_top(x):
    for (xa, za), (xb, zb) in zip(CREST, CREST[1:]):
        if xa <= x <= xb:
            return za + (zb - za) * (x - xa) / (xb - xa)
    return CREST[-1][1]


def pose(parts, phase):
    """an eel's swim: one wave runs down the whole chain side to side, small at the neck and wide at the tail. The head
    turns a little against the body's mean, so the animal keeps its line. The jaw closes a little once a beat"""
    run, total = 0.0, 0.0
    for k, name in enumerate(CHAIN):
        turn = math.radians(AMPLITUDES[k]) * math.sin(phase - STEP * (k + 1))
        parts[name].rotation_euler.z = turn
        run += turn
        total += run
    parts["Head"].rotation_euler.z = -0.7 * total / len(CHAIN)
    parts["Jaw"].rotation_euler.y = math.radians(4) * (0.5 + 0.5 * math.sin(phase))


class Plate:
    """a jaw block: a flat block lying across the head from (x0, z0) to (x1, z1) in the side view"""

    def __init__(self, x0, z0, x1, z1, wide, thick):
        self.x0, self.z0, self.x1, self.z1, self.wide, self.thick = x0, z0, x1, z1, wide, thick
        self.slope = (z1 - z0) / (x1 - x0)
        self.up = math.sqrt(1 + self.slope ** 2)

    @classmethod
    def from_top(cls, x, ztop, degrees, length, wide, thick):
        """a block whose top edge starts at (x, ztop) and runs forward, falling at this angle"""
        slope = math.tan(math.radians(degrees))
        z0 = ztop - thick / 2 * math.sqrt(1 + slope ** 2)
        a = math.radians(degrees)
        return cls(x, z0, x - length * math.cos(a), z0 - length * math.sin(a), wide, thick)

    def mid(self, x):
        return self.z0 + (x - self.x0) * self.slope

    def top(self, x):
        return self.mid(x) + self.thick / 2 * self.up

    def bottom(self, x):
        return self.mid(x) - self.thick / 2 * self.up

    def add(self, part, colour):
        part.beam((self.x0, 0, self.z0), (self.x1, 0, self.z1), self.wide, self.thick, colour, flat="z")

    def gum(self, part, xa, xb, side):
        """a thin dark plate set in from the lip's edge, showing DROP past it: below the lip (side -1) or above (+1)"""
        shift = side * (self.thick / 2 + DROP / 2 - 0.05) * self.up
        part.beam((xa, 0, self.mid(xa) + shift), (xb, 0, self.mid(xb) + shift), self.wide - 0.8, DROP + 0.1, "gum", flat="z")

    def gum_edge(self, x, side):
        return (self.bottom(x) - DROP * self.up) if side < 0 else (self.top(x) + DROP * self.up)

    def teeth_y(self, size):
        return self.wide / 2 - 0.4 - size / 2


def slab(p, x0, x1, n, bot, top):
    """a slice of body: a flat back (the crest stands on it) with stepped corners only where it is wide, a stepped belly,
    a lighter top row and a slightly darker bottom row"""
    p.hull(x0, x1, n, bot, top, "blue", [(1, 1)] if n >= 2 else [], [(1, 1)])
    p.paint_sym(x0, x1, n, top - 1, top, "blue+")
    p.paint_sym(x0, x1, n, bot, bot + 1, "blue-")


def build(m):
    head = m.part("Head", (SKULL[1], 0, 0))
    slab(head, *SKULL)
    head.paint(-21, -20, -1, 2, -2, 0, "mouth")  # the back of the gape, between the jaws

    # the upper jaw: two blocks in a chain, each tilted nose-down, the second smaller and starting inside the first, and a
    # ridge of forehead sloping from the skull's top onto it
    up1 = Plate(-20.4, 1.5, -24.6, 1.0, 4.6, 3.2)
    up2 = Plate(-24.0, 0.58, -27.2, -0.02, 3.2, 2.2)
    up1.add(head, "blue")
    up2.add(head, "blue")
    head.beam((-19.6, 0, 3.28), (-23.4, 0, 2.5), 2.6, 1.3, "blue+", flat="z")

    # the lower jaw, on its own joint at the hinge and drawn open: two yellow blocks, the second smaller, starting inside
    # the first and turning up a little at the chin, like a moray's
    jaw = m.part("Jaw", (-19.8, 0, -1.0), "Head")
    lo1 = Plate.from_top(-19.4, -0.75, 33, 4.8, 4.4, 1.7)
    lo2 = Plate.from_top(-22.9, lo1.top(-22.9) - 0.15, 26, 3.8, 3.2, 1.3)
    lo1.add(jaw, "yellow")
    lo2.add(jaw, "yellow")

    # the dark inside of the mouth: a block over each jaw block, behind the teeth, ending inside the lips
    def inside(part, xa, xb, upper, lower, ya, yb):
        part.block(xa, (-ya, ya, lower.top(xa) - 0.3, upper.bottom(xa) + 0.3), xb,
                   (-yb, yb, lower.top(xb) - 0.3, upper.bottom(xb) + 0.3), "mouth")

    inside(head, -22.8, -20.6, up1, lo1, 1.5, 1.6)
    inside(head, -25.6, -22.6, up2, lo2, 0.9, 1.3)

    # the gums: a thin dark line inside both lips
    up1.gum(head, -20.6, -24.0, -1)
    up2.gum(head, -24.1, -26.6, -1)
    lo1.gum(jaw, -20.6, -23.4, 1)
    lo2.gum(jaw, -23.1, -26.1, 1)
    # needle teeth, seven a side above and below, bases sunk in the gums; the moray's point back a little
    for plate, xs in ((up1, (-21.0, -21.9, -22.8, -23.7)), (up2, (-24.55, -25.4, -26.25))):
        for x in xs:
            head.tooth(x, plate.teeth_y(0.42), plate.gum_edge(x, -1) + 0.15, 0.42, 1.0, "tooth", lean=(0.15, 0.0))
    for plate, xs in ((lo1, (-21.5, -22.3, -23.0)), (lo2, (-23.7, -24.45, -25.2, -25.85))):
        for x in xs:
            jaw.tooth(x, plate.teeth_y(0.42), plate.gum_edge(x, 1) - 0.15, 0.42, -0.9, "tooth", lean=(0.15, 0.0))

    # the nostrils: two leaf-shaped flaps standing up at the snout's tip, leaning forward
    base = lambda x: up2.top(x) - 0.3  # noqa: E731
    head.prism([(-26.0, base(-26.0)), (-26.9, base(-26.9)), (-27.7, 2.5), (-27.5, 3.2), (-26.7, 2.6)], 0.6, 1.0, "blue+",
               mirror=True)

    # the eye: small and pale with a dark pupil, high on the upper jaw over the gape. The brow sits on it, slants down to
    # the front, cuts the top of the eye and comes past it
    head.block(-23.7, (2.0, 2.6, 0.9, 2.3), -22.3, (2.0, 2.6, 0.9, 2.3), "white", mirror=True)
    head.block(-23.4, (2.3, 2.85, 1.15, 1.95), -22.7, (2.3, 2.85, 1.15, 1.95), "black", mirror=True)
    head.beam((-21.4, 2.55, 2.75), (-24.3, 2.55, 2.05), 1.1, 0.9, "blue-", flat="z", mirror=True)

    # the body: slices, each on its own joint
    segs, before = [], SKULL
    for i, (x0, x1, n, bot, top) in enumerate(SLICES):
        seg = m.part(f"S{i + 1}", (x0, 0, 0), "Head" if i == 0 else f"S{i}")
        segs.append(seg)
        slab(seg, x0, x1, n, bot, top)
        # a sleeve into the piece in front, so a bending joint shows body: sized from the smaller of the two pieces and
        # kept a cube inside both pieces' corner steps
        _, _, fn, fbot, ftop = before
        seg.sym(x0 - 1, x0, min(n, fn) - 1, max(bot, fbot) + 1, min(top, ftop) - 1, "blue-")
        before = (x0, x1, n, bot, top)
        # THE MARK: the crest, one cube thick, standing on every slice; its foot sunk into the back in a shallow V
        mid = (x0 + x1) / 2
        if i == SEAT_SLICE:  # under the rider only a low yellow line, so the seat is clear
            outline = [(x0, top), (mid, top - 0.15), (x1, top), (x1, crest_top(x1)), (x0, top + 0.3)]
        else:
            outline = [(x0, top), (mid, top - 0.15), (x1, top), (x1, crest_top(x1))]
            outline += [(x, z) for x, z in CREST if x0 < x < x1][::-1]
            outline.append((x0, crest_top(x0)))
        seg.prism(outline, -0.5, 0.5, "yellow")
    # the seat: on the neck, a shallow slot either side for the rider's legs
    segs[SEAT_SLICE].dent(-17, -15, 2, 1, 3, "blue")

    # the tail, on its own joint: a blade in two tapered blocks, each smaller and starting inside the last, with the crest
    # running on along its top to the very tip
    end = SLICES[-1][1]
    tail = m.part("Tail", (end, 0, 0.5), f"S{len(SLICES)}")
    tail.taper(end - 0.6, (1.1, -0.1, 1.85), end + 3.0, (0.6, 0.1, 1.6), "blue")
    tail.taper(end + 2.4, (0.45, 0.25, 1.45), end + 5.6, (0.2, 0.6, 1.0), "blue")
    tail.prism([(end, 1.6), (end + 5.4, 0.85), (end + 6.0, 1.1), (end, crest_top(end))], -0.5, 0.5, "yellow")
