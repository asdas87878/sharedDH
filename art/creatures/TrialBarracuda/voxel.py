"""The Barracuda, a trial of docs/style/09-early-remodels.md, for tools/blender/voxel_kit.py. It stands beside the game's
Barracuda (art/creatures/Barracuda) and replaces nothing. Designed from the real animal.
Its idea: the spear. The thinnest body in the game for its length, a pike's head a third of it, an underbite of fangs.
- The body in numbers: about 52 cubes (21 studs) nose to tail tip; the body alone is 6 deep (0.11) and 5 wide (0.10),
  the same depth from the gills to the second back fin, then a short narrowing stalk. The head is a third of the length:
  a skull and a long flat-topped wedge (tapered blocks in a chain) coming to a point.
- Two small back fins far apart, the rider between them; the second over a matching fin below; small side and belly
  fins; a forked tail of thin pointed lobes, nearly twice as tall as the body is deep.
- The face: the lower jaw runs a cube and a half past the upper and ends in a knob. The mouth is slightly open along its
  whole length, a thin gum line inside each lip, two long fangs standing up in front of the upper jaw's point and five
  uneven needles a side behind them, top and bottom. A big round eye with a pale ring, under a brow that comes past it.
- Colour: bright silver sides and belly, a jade back on the top third, the line straight.
- The one mark: ten dark jade chevrons, slanted bars leaning back, along the upper side from the gills to the tail.
The rider sits mid-back between the two back fins, legs in a slot either side (the slot takes the place of one bar)."""
NAME, ZONE, RARITY = "Barracuda (trial)", "ZONE 4 / SHIPWRECKS", "UNCOMMON"
U = 0.4
PALETTE = {"silver": "#DCE6EA", "jade": "#1F9E8F", "chev": "#146B66", "ring": "#F6F2DE", "black": "#14181C",
           "tooth": "#FFFFFF", "mouth": "#5A2433", "gum": "#D9707F"}
SHADE = 0.9
SEAT = (5, 3, 2.5)
FRAME, ORTHO = 1.75, 25.0
TEXTURES = [{"tile": "stud", "on": "top", "colours": ["jade"]}]

# the body: (part, from, to, cubes out, bottom, top). One number changes from slice to slice, never two
BODY = (("S1", -9, -4, 2, -3, 3), ("S2", -4, 2, 2, -3, 3), ("S3", 2, 8, 2, -3, 3), ("S4", 8, 13, 2, -3, 3),
        ("S5", 13, 16, 2, -2, 3), ("S6", 16, 19, 1, -2, 3))
GILLS = (-13, -9, 2, -3, 3)  # the back of the head: the body's own section
CHEVRONS = (-7.8, -5.1, -2.4, 0.6, 3.0, 7.0, 9.4, 12.0, 14.5, 17.4)  # the middle of each bar; the seat's slot is at 4 to 6
SWIM = {"chain": ["Head", "S1", "S2", "S3", "S4", "S5", "S6", "Tail"], "amplitudes": [1, 1.5, 3, 5, 8, 12, 18],
        "phaseStep": 0.7, "headCounter": 1.5}


def slab(p, x0, x1, n, bot, top):
    """a slice of body: one-step corners; jade on the top two rows (lighter on top), silver below (a shade on the bottom row)"""
    p.hull(x0, x1, n, bot, top, "silver", [(1, 1)], [(1, 1)])
    p.paint_sym(x0, x1, n, top - 2, top, "jade")
    p.paint_sym(x0, x1, n, top - 1, top, "jade+")
    p.paint_sym(x0, x1, n, bot, bot + 1, "silver-")


class Wedge:
    """a tapered block from x0 to x1: at each end (half width, z from, z to). It answers where it is at any x"""

    def __init__(self, x0, s0, x1, s1):
        self.x0, self.s0, self.x1, self.s1 = x0, s0, x1, s1

    def at(self, x):
        f = (x - self.x0) / (self.x1 - self.x0)
        return tuple(a + (b - a) * f for a, b in zip(self.s0, self.s1))

    def add(self, part, colour):
        (h0, a0, b0), (h1, a1, b1) = self.s0, self.s1
        part.block(self.x0, (-h0, h0, a0, b0), self.x1, (-h1, h1, a1, b1), colour)


def build(m):
    head = m.part("Head", (GILLS[1], 0, 0))
    slab(head, *GILLS)
    head.dent(-12, -11, 2, -2, 1, "silver-")  # the gill cover's edge, on the silver only
    # the skull above the mouth: the body's top half carried forward, flat on top
    head.hull(-18, -13, 2, 0, 3, "silver", [(1, 1)], [])
    head.paint_sym(-18, -13, 2, 1, 3, "jade")
    head.paint_sym(-18, -13, 2, 2, 3, "jade+")
    head.box(-15, -13, -2, 3, -1, 0, "silver")  # the corner of the mouth, under the front of the eye

    # THE UPPER JAW: a long flat-topped wedge in two links, each a silver lip under a jade cheek and a lighter jade plate
    # on top (the body's top row carried on), each link starting inside the last and coming to a point
    lip1, cheek1, plate1 = (Wedge(-17.6, (2.05, 0.05, 1.0), -22.2, (1.38, 0.29, 0.95)), Wedge(-17.6, (2.2, 0.95, 1.95), -22.6, (1.5, 0.9, 1.6)),
                            Wedge(-17.6, (1.3, 1.85, 2.95), -22.0, (0.85, 1.5, 2.0)))
    lip2, cheek2, plate2 = (Wedge(-22.0, (1.2, 0.45, 0.8), -25.6, (0.3, 0.62, 0.78)), Wedge(-22.0, (1.35, 0.75, 1.5), -25.8, (0.5, 0.7, 1.15)),
                            Wedge(-22.0, (0.7, 1.4, 1.95), -24.6, (0.35, 1.2, 1.4)))
    for w, colour in ((lip1, "silver"), (cheek1, "jade"), (plate1, "jade+"), (lip2, "silver"), (cheek2, "jade"), (plate2, "jade+")):
        w.add(head, colour)

    # THE LOWER JAW: two links, longer than the upper, ending in a knob a cube and a half past the upper jaw's point
    jaw1 = Wedge(-12.5, (2.0, -2.6, -0.7), -21.0, (1.45, -2.0, -0.35))
    jaw2 = Wedge(-20.5, (1.25, -1.9, -0.55), -26.3, (0.75, -1.5, -0.15))
    jaw1.add(head, "silver")
    jaw2.add(head, "silver")
    head.block(-27.3, (-0.6, 0.6, -1.75, -0.05), -25.9, (-0.6, 0.6, -1.85, 0.05), "silver")  # the knob, a little taller than the jaw

    # the gums: thin plates set in from each lip's edge, showing 0.2 past it. (from, to, bottom at each end, half widths)
    def gum(x0, x1, z0, z1, h0, h1, up):
        a0, a1 = (z0 - 0.45, z1 - 0.45) if up else (z0, z1)  # up: z is the gum's top edge, else its bottom edge
        head.block(x0, (-h0, h0, a0, a0 + 0.45), x1, (-h1, h1, a1, a1 + 0.45), "gum")

    upper = {}  # x -> (the gum's lower edge, its half width): the upper teeth hang from it

    def upper_gum(x0, x1, z0, z1, h0, h1):
        gum(x0, x1, z0, z1, h0, h1, False)
        upper[(x0, x1)] = (z0, z1, h0, h1)

    upper_gum(-15.0, -17.8, -0.2, -0.2, 2.0, 2.0)
    upper_gum(-17.8, -22.35, lip1.at(-17.8)[1] - 0.2, lip1.at(-22.35)[1] - 0.2, 1.7, 0.95)
    upper_gum(-22.35, -25.4, lip2.at(-22.35)[1] - 0.2, lip2.at(-25.4)[1] - 0.2, 0.8, lip2.at(-25.4)[0] - 0.13)
    lower = {}

    def lower_gum(x0, x1, w):
        z0, z1 = w.at(x0)[2] + 0.2, w.at(x1)[2] + 0.2
        h0, h1 = w.at(x0)[0] - 0.45, w.at(x1)[0] - 0.38
        gum(x0, x1, z0, z1, h0, h1, True)
        lower[(x0, x1)] = (z0, z1, h0, h1)

    lower_gum(-15.0, -21.15, jaw1)
    lower_gum(-21.15, -25.9, jaw2)

    def edge(gums, x):
        for (x0, x1), (z0, z1, h0, h1) in gums.items():
            if x1 <= x <= x0:
                f = (x - x0) / (x1 - x0)
                return z0 + (z1 - z0) * f, h0 + (h1 - h0) * f

    # the dark inside of the mouth: one block that stays behind the teeth and ends inside the lips and the jaw
    head.block(-25.0, (-0.2, 0.2, -0.3, 0.67), -15.0, (-1.0, 1.0, -1.0, 0.1), "mouth")
    # the teeth: few and big. Two long fangs on the knob, standing up in front of the upper jaw's point, then five uneven
    # needles a side, top and bottom, their bases sunk in the gums
    head.tooth(-26.55, 0.32, -0.1, 0.5, -1.8, "tooth", lean=(0.4, 0.15))
    for x, size, length in ((-24.6, 0.42, 0.55), (-23.2, 0.5, 0.85), (-21.4, 0.45, 0.5), (-19.6, 0.5, 0.8), (-17.4, 0.45, 0.55)):
        z, h = edge(upper, x)
        head.tooth(x, max(h - 0.25, size / 2 + 0.05), z + 0.1, size, length, "tooth")
    for x, size, length in ((-25.0, 0.42, 0.6), (-23.9, 0.4, 0.45), (-22.3, 0.5, 0.8), (-20.4, 0.45, 0.5), (-18.3, 0.5, 0.7)):
        z, h = edge(lower, x)
        head.tooth(x, max(h - 0.25, size / 2 + 0.05), z - 0.1, size, -length, "tooth")

    # the eye: big and round, a pale ring (a wide block and a tall one crossed) round a dark pupil, high on the skull,
    # under a jade brow that slants down to the front, cuts the top of the ring and comes past it
    head.block(-17.0, (2.2, 2.8, 0.5, 1.75), -14.5, (2.2, 2.8, 0.5, 1.75), "ring", mirror=True)
    head.block(-16.6, (2.05, 2.95, 0.15, 2.35), -14.9, (2.05, 2.95, 0.15, 2.35), "ring", mirror=True)
    head.block(-16.35, (1.9, 3.15, 0.7, 1.6), -15.15, (1.9, 3.15, 0.7, 1.6), "black", mirror=True)
    head.beam((-17.9, 2.5, 2.15), (-14.3, 2.5, 2.75), 0.8, 1.3, "jade", mirror=True)

    # the body: six rigid pieces, each with a sleeve into the piece in front so a bending joint shows body
    segs, before = {}, GILLS
    for i, (name, x0, x1, n, bot, top) in enumerate(BODY):
        seg = segs[name] = m.part(name, (x0, 0, 0), "Head" if i == 0 else BODY[i - 1][0])
        slab(seg, x0, x1, n, bot, top)
        _, _, fn, fbot, ftop = before
        seg.sym(x0 - 1, x0, min(n, fn) - 1, max(bot, fbot) + 1, min(top, ftop) - 1, "silver-")
        before = (x0, x1, n, bot, top)
        # THE MARK: dark jade chevrons, slanted bars 1 cube wide leaning back, 0.3 proud, from mid flank up into the jade
        for c in CHEVRONS:
            if x0 < c < x1:
                seg.beam((c - 0.4, n + 0.5, -0.45), (c + 0.4, n + 0.5, 1.75), 1.0, 0.6, "chev", mirror=True)
    s1, s2, s3, s4 = segs["S1"], segs["S2"], segs["S3"], segs["S4"]
    s3.dent(4, 6, 2, 1, 2, "jade")  # the seat's leg slots
    s3.dent(4, 6, 2, 0, 1, "silver")

    # the fins: small, each two boxes at an angle, the second smaller and thinner and starting inside the first
    s2.beam((-1.6, 0, 2.6), (-0.4, 0, 4.8), 1.7, 0.7, "jade")  # the first back fin, in front of the rider
    s2.beam((-0.9, 0, 4.2), (0.1, 0, 5.5), 1.0, 0.4, "jade")
    s4.beam((10.6, 0, 2.6), (11.8, 0, 4.6), 1.6, 0.6, "jade")  # the second, far behind
    s4.beam((11.3, 0, 4.0), (12.2, 0, 5.2), 0.9, 0.3, "jade")
    s4.beam((10.6, 0, -2.6), (11.8, 0, -4.6), 1.6, 0.6, "silver")  # the matching fin under it
    s4.beam((11.3, 0, -4.0), (12.2, 0, -5.2), 0.9, 0.3, "silver-")
    s1.beam((-8.6, 2.0, -1.6), (-6.4, 3.4, -2.2), 1.2, 0.4, "silver-", flat="z", mirror=True)  # the side fins
    s2.beam((-1.4, 0.8, -2.6), (0.4, 1.7, -3.7), 1.0, 0.4, "silver-", flat="z", mirror=True)  # the belly fins

    # the tail, on its own joint: a narrow stock and a fork of two thin lobes, each two boxes, the second thinner, ending
    # in a point
    tail = m.part("Tail", (19, 0, 0.5), "S6")
    tail.sym(18, 22, 0, -1, 2, "jade")  # the stock, and its sleeve into the stalk
    tail.paint_sym(18, 19, 0, -1, 2, "silver-")
    for s in (1, -1):
        tail.beam((20.4, 0, 0.5 + 0.6 * s), (22.6, 0, 0.5 + 3.4 * s), 1.6, 0.6, "jade")
        tail.beam((22.1, 0, 0.5 + 2.8 * s), (23.9, 0, 0.5 + 5.0 * s), 1.0, 0.3, "jade")
        # the point: a pyramid on the end of the second box, along its line
        d = (1.8, 2.2 * s)
        k = (d[0] ** 2 + d[1] ** 2) ** 0.5
        ax, az = d[0] / k, d[1] / k
        wx, wz = az, -ax  # across the lobe, in the side view
        cx, cz = 23.9 - ax * 0.4, 0.5 + 5.0 * s - az * 0.4
        base = [(cx + wx * a * 0.4, b * 0.1, cz + wz * a * 0.4) for a, b in ((-1, -1), (1, -1), (1, 1), (-1, 1))]
        tail.spike(base, (cx + ax * 1.7, 0.0, cz + az * 1.7), "jade")
