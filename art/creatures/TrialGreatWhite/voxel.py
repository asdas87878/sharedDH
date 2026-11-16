"""The Great White, a trial of docs/style/07-shape-variety.md, for tools/blender/voxel_kit.py. It stands beside the
game's Great White (art/creatures/GreatWhite) and replaces nothing. Designed from the real animal.
Its idea: the bruiser. All chest and head.
- The body idea in numbers: about 59 cubes long; the body alone is 20 deep (0.34 of the length) and 15 wide; the deepest
  slice is a third of the way back from the nose; the head to the first gill is three tenths of the length. Behind the
  chest the belly tucks up fast to a narrow stalk and a tall crescent tail.
- The mouth is its own design: a huge open grin. The upper lip runs level from the tip of the snout and then climbs to a
  corner behind the eye; the lower jaw hangs open under it, a level front on a ramus that climbs to the same corner. A
  thin pink gum line is set inside both lips, with big triangular teeth: eight a side and five across on top, six a
  side and three across below.
- A small black eye set forward under a heavy dark brow that comes past it.
- One hue: steel blue over a bright white belly. The line between them is a ragged sawtooth set high on the flank's flat
  side (never on the corner steps).
- The one mark: a pale scar on the left of the snout, and a notch out of the back fin's rear edge.
The rider sits on the hump of the chest, in front of the back fin, legs in a slot either side."""
import math

NAME, ZONE, RARITY = "Great White (trial)", "ZONE 3 / KELP FOREST", "EPIC"
U = 0.45
PALETTE = {"blue": "#3F74AD", "white": "#F8F7F2", "black": "#14171C", "mouth": "#5E1A26", "tooth": "#FFFFFF", "gum": "#F08A9E"}
SEAT = (-6, 9, 6.6)
FRAME, ORTHO = 2.5, 32.0
TEXTURES = [{"tile": "stud", "on": "top", "colours": ["blue"]}]  # round studs on the top of the back only
SWIM = {"chain": ["Head", "S1", "S2", "S3", "S4", "S5", "Tail"], "amplitudes": [1.5, 3, 5, 8, 12, 18], "phaseStep": 0.8,
        "headCounter": 2}
DROP = 0.3  # how far a gum plate shows past its lip

# the body in slices (from, to, cubes out, bottom, top). One number changes from slice to slice, never two.
# The head above the mouth first (its bottom is the lip's line), then the head behind the mouth's corner, then the parts
BROWS = ((-22, -20, 6, -1, 6), (-20, -19, 6, 0, 6), (-19, -18, 6, 0, 7), (-18, -15, 6, 1, 7))
SKULL = ((-15, -14, 7, -9, 7), (-14, -13, 7, -9, 8), (-13, -12, 7, -10, 8), (-12, -11, 7, -10, 9))
BODY = (("S1", ((-11, -7, 7, -11, 9), (-7, -5, 7, -10, 9), (-5, -3, 7, -9, 9))),  # the chest: the deepest slice, the gills, the seat
        ("S2", ((-3, -2, 7, -9, 9), (-2, -1, 6, -9, 9), (-1, 0, 6, -8, 9), (0, 1, 6, -7, 9), (1, 2, 5, -7, 9), (2, 3, 5, -6, 9),
                (3, 4, 5, -6, 8), (4, 5, 5, -5, 8), (5, 6, 4, -5, 8), (6, 7, 4, -5, 7), (7, 8, 4, -4, 7))),  # the back fin
        ("S3", ((8, 9, 4, -4, 6), (9, 10, 3, -4, 6), (10, 11, 3, -4, 5), (11, 12, 3, -3, 5), (12, 14, 3, -3, 4))),
        ("S4", ((14, 15, 2, -3, 4), (15, 16, 2, -3, 3), (16, 17, 2, -2, 3))),
        ("S5", ((17, 19, 2, -2, 2), (19, 21, 2, -1, 2))))  # the stalk, ending in the tail's stock
# the line between the blue back and the white belly: white below this height at each x. A ragged sawtooth: it climbs a
# cube at a time toward the tail and drops at once, in teeth of two, three and four, and stays on the flank's flat side
LINE = dict(zip(range(-15, 21), (2, 3, 4, 2, 3, 4, 5, 2, 3, 4, 2, 3, 4, 5, 3, 4, 2, 3, 4, 5, 2, 3, 4, 2, 3, 1, 2, 3, 1, 2, 0, 1, 0,
                                 1, 0, 1)))


def steps(n):
    """the corners of the back and the belly: a barrel's broad steps where the body is thick, fewer as it thins"""
    if n >= 7:
        return [(4, 1), (2, 1), (1, 2)]
    return [(3, 1), (2, 1), (1, 1)] if n == 6 else ([(2, 1), (1, 1)] if n >= 4 else [(1, 1)])


def clear(n):
    return sum(tall for _, tall in steps(n))


def slab(p, x0, x1, n, bot, top):
    """a slice of body: stepped corners, blue with a lighter top row, white below the ragged line with a darker bottom row"""
    p.hull(x0, x1, n, bot, top, "blue", steps(n), steps(n))
    p.paint_sym(x0, x1, n, top - 1, top, "blue+")
    for x in range(x0, x1):
        p.paint_sym(x, x + 1, n, bot, LINE[x], "white")
    p.paint_sym(x0, x1, n, bot, bot + 1, "white-")


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
        """a thin pink plate set in from the lip's edge, showing DROP past it: below the lip (side -1) or above (+1)"""
        shift = side * (self.thick / 2 + DROP / 2 - 0.05) * self.up
        part.beam((xa, 0, self.mid(xa) + shift), (xb, 0, self.mid(xb) + shift), self.wide - 0.8, DROP + 0.1, "gum", flat="z")

    def gum_edge(self, x, side):
        return (self.bottom(x) - DROP * self.up) if side < 0 else (self.top(x) + DROP * self.up)

    def teeth_y(self, size):
        return self.wide / 2 - 0.4 - size / 2


def build(m):
    head = m.part("Head", (SKULL[-1][1], 0, 0))
    for x0, x1, n, bot, top in BROWS:  # the head above the mouth: boxy, two-step corners, flat underneath (the lip covers it)
        head.hull(x0, x1, n, bot, top, "blue", [(2, 1), (1, 1)], [])
        head.paint_sym(x0, x1, n, top - 1, top, "blue+")
    for s in SKULL:  # the head behind the mouth's corner: the jowls, a step wider
        slab(head, *s)
    head.paint(-15, -14, -7, 8, 0, 1, "mouth")  # the corner of the mouth, one cube into the cheek

    # the snout, a blunt heavy cone: three low wide blocks in a chain, each tilted nose-down, narrower and lower than the
    # last and starting inside it, and two narrower blocks on top of the first two, so its section steps in like the body
    head.beam((-21.4, 0, 1.75), (-25.6, 0, 1.35), 12.6, 4.4, "blue", flat="z")
    head.beam((-24.8, 0, 1.1), (-27.8, 0, 0.75), 10.0, 3.6, "blue", flat="z")
    head.beam((-27.2, 0, 0.4), (-28.8, 0, 0.22), 7.0, 2.9, "blue", flat="z")
    head.beam((-21.4, 0, 4.75), (-24.9, 0, 4.15), 8.4, 2.2, "blue+", flat="z")
    head.beam((-24.3, 0, 3.5), (-26.9, 0, 2.9), 6.6, 1.7, "blue+", flat="z")

    # THE MOUTH. The upper lip: three white plates under the snout on one line, each thinner, then a wider one that climbs
    # to the corner behind the eye. The lower jaw: a chin and a level front, then the ramus that climbs to the same corner
    # (its lower end is the angle of the jaw), with the throat set back under it
    lip1, lip2, lip3 = Plate(-22.3, -1.15, -25.7, -1.35, 13.3, 1.6), Plate(-25.1, -1.32, -27.9, -1.49, 10.4, 1.3), Plate(-27.3, -1.45, -28.55, -1.53, 7.4, 1.0)
    rise = Plate(-22.6, -1.35, -14.6, 1.85, 13.7, 1.6)
    jaw1, jaw0 = Plate(-18.8, -6.3, -25.6, -7.1, 12.0, 1.9), Plate(-25.0, -7.0, -27.6, -7.6, 9.2, 1.5)
    ramus = Plate(-20.2, -7.0, -14.4, -1.3, 13.3, 2.8)
    for plate in (lip1, lip2, lip3, rise, jaw1, jaw0, ramus):
        plate.add(head, "white")
    head.beam((-14.2, 0, -5.8), (-18.2, 0, -5.44), 10.4, 4.0, "white-", flat="z")  # the throat
    # the dark inside: blocks that stay behind the teeth and end inside the lips and the jaw
    head.block(-27.7, (-2.9, 2.9, -3.8, -1.35), -26.4, (-2.9, 2.9, -3.8, -1.35), "mouth")
    head.block(-26.7, (-3.6, 3.6, -6.6, -1.45), -20.4, (-4.8, 4.8, -5.9, -1.0), "mouth")
    head.block(-21.0, (-5.2, 5.2, -6.2, -1.1), -14.8, (-5.2, 5.2, -0.6, 1.3), "mouth")
    # the gums: a thin pink line set inside both lips
    lip1.gum(head, -22.0, -25.4, -1)
    lip2.gum(head, -25.3, -27.6, -1)
    lip3.gum(head, -27.5, -28.25, -1)
    rise.gum(head, -22.0, -15.6, -1)
    jaw1.gum(head, -20.6, -25.3, 1)
    jaw0.gum(head, -25.75, -27.3, 1)
    ramus.gum(head, -20.4, -15.6, 1)
    # the teeth: big triangles, bases sunk in the gums. On top eight a side and five across the front
    for plate, sink, xs, long in ((rise, 0.3, (-17.4, -18.65, -19.9, -21.15), 1.4), (lip1, 0.15, (-23.0, -24.3), 1.5), (lip2, 0.15, (-25.9, -27.1), 1.4)):
        for x in xs:
            head.tooth(x, plate.teeth_y(1.1), plate.gum_edge(x, -1) + sink, 1.1, long - (0.2 if x > -18 else 0.0), "tooth", long=1.0)
    front = lip3.gum_edge(-27.85, -1) + 0.15
    head.tooth(-27.85, 0.0, front, 1.1, 1.4, "tooth", mirror=False, long=0.9)
    for y in (1.2, 2.4):
        head.tooth(-27.85, y, front, 1.1, 1.3, "tooth", long=0.9)
    # below, six a side and three across the front
    for plate, xs, long in ((jaw1, (-21.4, -22.5, -23.6, -24.7), 0.9), (jaw0, (-26.2, -26.95), 0.7)):
        for x in xs:
            head.tooth(x, plate.teeth_y(1.0), plate.gum_edge(x, 1) - 0.15, 1.0, -1.1, "tooth", long=long)
    front = jaw0.gum_edge(-27.0, 1) - 0.15
    head.tooth(-27.0, 0.0, front, 1.0, -1.1, "tooth", mirror=False, long=0.7)
    head.tooth(-27.0, 1.5, front, 1.0, -1.1, "tooth", long=0.7)

    # the eye: a small black block set forward on the side of the head, under a heavy brow that slants down to the front,
    # cuts across the top of the eye and comes past it: it is mean
    head.pair(-21, -19, 6, 7, 2, 4, "black")
    head.beam((-22.3, 5.7, 3.5), (-18.4, 5.7, 4.3), 1.5, 3.2, "blue-", mirror=True)
    # THE MARK: one pale scar on the left of the snout, a long slash and a short cut across it, standing a little proud
    head.beam((-25.0, -6.3, 3.3), (-22.8, -6.3, 0.4), 0.5, 0.6, "white")
    head.beam((-24.7, -6.3, 1.1), (-23.3, -6.3, 2.5), 0.4, 0.3, "white")

    segs, before = {}, SKULL[-1]
    for i, (name, slices) in enumerate(BODY):
        seg = segs[name] = m.part(name, (slices[0][0], 0, 0), "Head" if i == 0 else BODY[i - 1][0])
        for s in slices:
            slab(seg, *s)
        # a sleeve into the piece in front, so a bending joint shows body: sized from the smaller of the two pieces and
        # kept clear of both pieces' corner steps
        x0, _, n, bot, top = slices[0]
        _, _, fn, fbot, ftop = before
        gap = max(clear(n), clear(fn))
        seg.sym(x0 - 1, x0, max(min(n, fn) - 2, 0), max(bot, fbot) + gap, min(top, ftop) - gap, "blue-")
        before = slices[-1]
    s1, s2, s3, s4, s5 = (segs[name] for name, _ in BODY)

    for part, x in ((s1, -11), (s1, -9), (s1, -7), (s1, -5), (s2, -3)):  # five gill slits: quiet darker dents in the white
        part.dent(x, x + 1, 7, -3, 2, "white-")
    # the seat: on the hump of the chest, in front of the back fin, with a slot either side for the rider's legs
    s1.dent(-7, -5, 6, 5, 7, "blue")

    # the fins: each a few boxes at an angle, every box smaller and thinner than the one before and starting inside it.
    # The back fin: a big triangle, leaning back. Its boxes line up at the rear and step back at the front. THE MARK's other
    # half: a notch in the rear edge, the blocks left out between the first box and the third (the second is the web in
    # front of the notch)
    ux, uz, wx, wz, ox, oz = 0.272, 0.962, 0.962, -0.272, 1.8, 7.6

    def fin(s_from, s_to, front, rear, thick, colour):
        w = (front + rear) / 2
        s2.beam((ox + s_from * ux + w * wx, 0, oz + s_from * uz + w * wz), (ox + s_to * ux + w * wx, 0, oz + s_to * uz + w * wz),
                rear - front, thick, colour)

    fin(0.0, 5.4, -4.2, 4.2, 1.6, "blue")
    fin(4.7, 7.6, -1.2, 2.0, 1.0, "blue")
    fin(7.4, 10.2, -1.35, 4.2, 1.3, "blue")
    s2.beam((6.53, 0, 16.24), (7.75, 0, 18.87), 3.0, 0.7, "blue-")
    # the side fins: thick and broad, swept back and a little down, from low on the flank under the gills
    s1.beam((-8.0, 4.2, -5.6), (-3.2, 11.2, -7.4), 6.6, 1.8, "blue", flat="z", mirror=True)
    s1.beam((-4.3, 9.9, -7.07), (-1.0, 13.8, -8.1), 4.6, 1.2, "blue", flat="z", mirror=True)
    s1.beam((-1.8, 12.85, -7.85), (0.6, 15.4, -8.6), 3.0, 0.7, "blue-", flat="z", mirror=True)
    s3.beam((9.6, 1.2, -2.8), (11.8, 3.4, -5.0), 2.2, 0.7, "white-", flat="z", mirror=True)  # the belly fins
    s4.beam((15.6, 0, 2.3), (17.0, 0, 4.7), 1.9, 0.8, "blue")  # the second back fin: tiny on a great white
    s4.beam((16.0, 0, -1.2), (17.2, 0, -3.4), 1.7, 0.7, "white-")  # the anal fin, as small

    # the tail, on its own joint: a short narrow stock that carries on from the stalk's flat end, then a tall crescent of
    # two lobes, nearly equal, each in three boxes that sweep back more toward the tip
    tail = m.part("Tail", (21, 0, 0.5), "S5")
    tail.sym(21, 26, 1, -1, 2, "blue")
    tail.sym(20, 21, 0, 0, 1, "blue-")  # its sleeve
    tail.beam((23.2, 0, 1.0), (25.2, 0, 6.6), 5.4, 1.4, "blue")
    tail.beam((24.7, 0, 5.6), (26.8, 0, 9.8), 4.0, 1.0, "blue")
    tail.beam((26.4, 0, 9.0), (27.75, 0, 11.8), 2.6, 0.6, "blue-")
    tail.beam((23.2, 0, 0.0), (25.0, 0, -5.0), 5.0, 1.1, "blue")
    tail.beam((24.5, 0, -4.0), (26.4, 0, -7.8), 3.7, 0.8, "blue")
    tail.beam((26.0, 0, -7.0), (27.6, 0, -9.6), 2.5, 0.45, "blue-")
