"""Xiphactinus (zone 4's Legendary: the "bulldog fish", a prehistoric predator as long as a boat) for
tools/blender/voxel_kit.py (docs/style/creature-brief.md).
Its idea: a bulldog's face on a torpedo. The lower jaw juts out past the snout and turns up, with long fangs standing in
front of the upper lip; everything behind the head is plain, fast fish.
- The body is twenty slices on twelve joints. Each slice is one step bigger or smaller than the last (width, or back, or
  belly), so the back arches to a peak a third of the way down and the belly curves under it.
- Steel blue over silver. One thin amber stripe runs the whole flank where the two meet, from the gill cover to the
  tail: the echo of the eye.
- The head: a skull block, a snout of two blocks tilted nose-down, a steel upper lip of two blocks tilted nose-UP under it
  (so the mouth line climbs to the front, as the real one's does), and the lower jaw on its own joint: a level block and
  an upturned chin that ends in front of the lip. A thin dark gum line inside both lips. Long fangs at the front of both
  jaws (the upper ones hang outside the lower jaw), smaller teeth behind.
- The eye: a dark pupil in a thin halo of soft light (the only glow), under a dark brow that slants down to the front and
  comes past the eye.
- Big pectoral fins on joints of their own, small belly fins, a dorsal and an anal fin far back, and a deeply forked tail
  of long narrow lobes on its own joint.
The rider sits on the peak of the back, legs in a shallow slot either side."""
import math

NAME, ZONE, RARITY = "Xiphactinus", "ZONE 4 / SHIPWRECKS", "LEGENDARY"
U = 0.45
PALETTE = {"steel": "#4F6C8C", "silver": "#C9D2D6", "amber": "#E9A23B", "soft": "#F6CB6E", "black": "#1F2328",
           "tooth": "#FFFFFF", "mouth": "#6A2630", "gum": "#8E4A54"}
SEAT = (-7.5, 8, 5.5)
GLOW = {"soft": 0.4}  # only the thin halo of the eye
TEXTURES = [{"tile": "stud", "on": "top", "colours": ["steel"]}]
FRAME, ORTHO, ORTHO_SWIM = 2.6, 40.0, 44.0

# the body: each slice is (length, cubes out, bottom, top). One number changes from slice to slice
SLICES = ((2, 4, -5, 6), (2, 4, -6, 6), (3, 5, -6, 6), (3, 5, -6, 7), (3, 5, -7, 7), (4, 5, -7, 8), (3, 5, -7, 8), (3, 5, -7, 7),
          (3, 5, -6, 7), (3, 4, -6, 7), (3, 4, -6, 6), (3, 4, -5, 6), (3, 4, -5, 5), (2, 3, -5, 5), (2, 3, -4, 5), (2, 3, -4, 4),
          (2, 3, -3, 4), (2, 2, -3, 4), (2, 2, -3, 3), (2, 2, -2, 3))
GROUPS = ((0, 1), (2, 3, 4), (5, 6), (7, 8), (9,), (10,), (11,), (12,), (13, 14), (15, 16), (17,), (18, 19))  # the slices that share a joint
BODY_FROM = -24
STRIPE = 0  # the height of the flank stripe: steel above it, silver below
SKULL = (4, -5, 5)
CHAIN = ["Head"] + [f"B{i + 1}" for i in range(len(GROUPS))] + ["Tail"]
AMPLITUDES = [1, 1.5, 2, 2.5, 3, 3, 3.5, 4, 5.5, 7, 8, 9, 15]


def pose(parts, phase):
    """a fish's swim: the wave runs down the chain side to side and grows to the tail; the head turns a little against
    it. The jaw opens and shuts once a beat; the pectoral fins row a little"""
    parts["Head"].rotation_euler.z = math.radians(2.0) * math.sin(phase + math.pi)
    for k, name in enumerate(CHAIN[1:]):
        parts[name].rotation_euler.z = math.radians(AMPLITUDES[k]) * math.sin(phase - 0.42 * (k + 1))
    parts["Jaw"].rotation_euler.y = -math.radians(8) * (0.5 + 0.5 * math.sin(phase))
    for name, side in (("FinR", 1), ("FinL", -1)):
        parts[name].rotation_euler.x = side * math.radians(10) * math.sin(phase - 0.8)


def top_steps(n):
    """the corners of the back: three steps where the body is thick, fewer as it thins"""
    return [(3, 1), (2, 1), (1, 1)] if n >= 5 else ([(2, 1), (1, 1)] if n == 4 else [(1, 1)])


def bottom_steps(n):
    return [(2, 1), (1, 1)] if n >= 4 else [(1, 1)]


def slab(p, x0, x1, n, bot, top):
    """a slice of body: stepped corners, steel back (lighter on the top row), the amber stripe on the side's outer
    column, a silver belly (darker on the bottom row)"""
    p.hull(x0, x1, n, bot, top, "steel", top_steps(n), bottom_steps(n))
    p.paint_sym(x0, x1, n, top - 1, top, "steel+")
    p.paint_sym(x0, x1, n, bot, STRIPE, "silver")
    p.paint_sym(x0, x1, n, bot, bot + 1, "silver-")
    p.paint_pair(x0, x1, n, n + 1, STRIPE, STRIPE + 1, "amber")


class Ramp:
    """a turned block seen from the side: its middle line from (x0, z0) to (x1, z1), `wide` across, `thick` through"""

    def __init__(self, x0, z0, x1, z1, wide, thick):
        self.x0, self.z0, self.x1, self.z1, self.wide, self.thick = x0, z0, x1, z1, wide, thick
        self.cos = abs(x1 - x0) / math.hypot(x1 - x0, z1 - z0)

    def mid(self, x):
        return self.z0 + (self.z1 - self.z0) * (x - self.x0) / (self.x1 - self.x0)

    def top(self, x):
        return self.mid(x) + self.thick / 2 / self.cos

    def bottom(self, x):
        return self.mid(x) - self.thick / 2 / self.cos

    def add(self, part, colour):
        part.beam((self.x0, 0, self.z0), (self.x1, 0, self.z1), self.wide, self.thick, colour, flat="z")

    def plate(self, part, xa, xb, rise, wide, thick, colour):
        """a thin plate on the same slope from xa to xb, its middle `rise` above the block's middle line"""
        part.beam((xa, 0, self.mid(xa) + rise / self.cos), (xb, 0, self.mid(xb) + rise / self.cos), wide, thick, colour, flat="z")


def build(m):
    head = m.part("Head", (BODY_FROM, 0, 0))
    # the skull: a block with two-step corners on top, steel over silver. Everything else on the head starts inside it
    head.hull(-30, BODY_FROM, 4, -5, 5, "steel", [(2, 1), (1, 1)], [(1, 1)])
    head.paint_sym(-30, BODY_FROM, 4, 4, 5, "steel+")
    head.paint_sym(-30, BODY_FROM, 4, -5, STRIPE, "silver")
    head.paint_sym(-30, BODY_FROM, 4, -5, -4, "silver-")
    head.paint_pair(-27, BODY_FROM, 4, 5, STRIPE, STRIPE + 1, "amber")  # the stripe starts on the gill cover, behind the eye
    # the snout: two blocks in a chain, tilted nose-down, the second lower and narrower: a short, blunt face
    snout = (Ramp(-29.3, 2.0, -32.8, 1.05, 6.4, 3.8), Ramp(-32.0, 1.2, -34.3, 0.8, 4.8, 3.4))
    for block in snout:
        block.add(head, "steel")
    snout[0].plate(head, -30.4, -32.1, 3.8 / 2 + 0.2, 4.2, 0.5, "steel+")  # the back's lighter top carried onto the snout
    # the upper lip: two blocks tilted the other way, nose-UP, under the snout, so the mouth line climbs to the front. They
    # are wider than the snout (jowls) and the front one stands a little past the snout's end
    lips = (Ramp(-28.8, -1.4, -33.4, -0.135, 7.0, 2.2), Ramp(-32.2, -0.45, -34.9, 0.31, 5.4, 1.4))
    for block in lips:
        block.add(head, "steel")
    for block, xa, xb in ((lips[0], -29.4, -33.1), (lips[1], -33.5, -34.6)):  # the gum line, set inside the lip's edge
        block.plate(head, xa, xb, -(block.thick / 2 + 0.075), block.wide - 1.0, 0.25, "gum")
    # the dark inside of the mouth: two blocks that stay behind the teeth and end inside the lips and the jaw
    Ramp(-29.2, -2.6, -32.6, -2.05, 3.2, 1.5).add(head, "mouth")
    Ramp(-32.2, -2.1, -34.2, -1.42, 2.2, 1.7).add(head, "mouth")
    # the upper teeth hang OUTSIDE the lower jaw, which is narrower than the lip: small ones at the back, two long fangs
    # a side toward the front
    for block, x, y, size, length in ((lips[0], -30.8, 2.95, 0.6, 0.8), (lips[0], -31.8, 2.95, 0.6, 1.1), (lips[0], -32.85, 2.95, 0.65, 1.4),
                                      (lips[1], -33.6, 2.25, 0.65, 1.6), (lips[1], -34.3, 2.25, 0.7, 2.0)):
        head.tooth(x, y, block.bottom(x) + 0.1, size, length, "tooth")
    # the eye: a dark socket on the skull's side, a thin halo of soft light, a dark pupil standing out of it. The brow is
    # one dark box that slants down to the front: it cuts the top of the eye's square and comes past it onto the snout
    socket = (4.38, 4.97, 0.3, 2.9)
    head.block(-29.75, socket, -27.05, socket, "steel-", mirror=True)
    halo = (4.85, 5.15, 0.6, 2.6)
    head.block(-29.45, halo, -27.35, halo, "soft", mirror=True)
    pupil = (4.97, 5.33, 0.9, 2.3)
    head.block(-29.1, pupil, -27.7, pupil, "black", mirror=True)
    head.beam((-31.4, 4.3, 2.3), (-26.3, 4.3, 3.35), 1.3, 2.6, "steel-", mirror=True)

    # the lower jaw, on its own joint: a level block, then the chin, turned up, which ends in front of the upper lip. Its
    # own gum line; small teeth along the sides, inside the upper row, and four long fangs standing up at the tip, in front of the lip
    jaw = m.part("Jaw", (-28.8, 0, -3.2), "Head")
    jaws = (Ramp(-28.4, -3.75, -33.0, -3.75, 5.0, 2.2), Ramp(-32.3, -3.7, -36.9, -1.7, 3.8, 2.2))
    for block in jaws:
        block.add(jaw, "silver-")
    for block, xa, xb in ((jaws[0], -29.6, -32.65), (jaws[1], -33.4, -36.3)):
        block.plate(jaw, xa, xb, block.thick / 2 + 0.075, block.wide - 0.6, 0.25, "gum")
    for block, x, y, size, length in ((jaws[0], -31.4, 2.05, 0.55, 0.65), (jaws[0], -32.6, 2.05, 0.6, 0.9), (jaws[1], -34.0, 1.5, 0.6, 1.0),
                                      (jaws[1], -35.35, 1.4, 0.6, 1.7), (jaws[1], -35.9, 0.6, 0.75, 2.2)):
        jaw.tooth(x, y, block.top(x) - 0.1, size, -length, "tooth")

    # the body: twenty slices on twelve joints
    spans, x = [], BODY_FROM
    for length, n, bot, top in SLICES:
        spans.append((x, x + length, n, bot, top))
        x += length
    end = x
    body, seg = [], {}
    for g, group in enumerate(GROUPS):
        part = m.part(f"B{g + 1}", (spans[group[0]][0], 0, 0), "Head" if g == 0 else f"B{g}")
        body.append(part)
        for i in group:
            slab(part, *spans[i])
            seg[i] = part
        # a sleeve into the piece in front, so a bending joint shows body. It is sized from the smaller of the two pieces
        # and stays clear of both pieces' steps
        x0, _, n, bot, top = spans[group[0]]
        fn, fbot, ftop = spans[group[0] - 1][2:5] if g else SKULL
        up = max(len(top_steps(n)), len(top_steps(fn)) if g else 2)
        down = max(len(bottom_steps(n)), len(bottom_steps(fn)) if g else 1)
        part.sym(x0 - 1, x0, max(min(n, fn) - 2, 0), max(bot, fbot) + down, min(top, ftop) - up, "steel-")
    seg[0].dent(-23, -22, 4, 1, 4, "steel-")  # the gill slit
    seg[5].dent(-9, -6, 5, 2, 5, "steel-")  # the seat: on the peak of the back, a shallow slot either side for the legs

    # the pectoral fins, each on its own joint: three boxes swept out, back and a little down, every one smaller and
    # thinner than the last and starting inside it, the last one darker
    for name, side in (("FinR", 1), ("FinL", -1)):
        fin = m.part(name, (-19.2, 4.0 * side, -3.4), "B1")
        for (ax, ay, az), (bx, by, bz), wide, thick, colour in (((-19.4, 2.8, -3.4), (-15.6, 7.6, -5.2), 5.0, 1.2, "steel"),
                                                                ((-16.3, 6.7, -4.85), (-12.7, 10.4, -6.37), 3.6, 0.8, "steel"),
                                                                ((-13.5, 9.6, -6.05), (-10.6, 12.1, -7.18), 2.4, 0.45, "steel-")):
            fin.beam((ax, ay * side, az), (bx, by * side, bz), wide, thick, colour, flat="z")
    seg[10].beam((5.4, 1.4, -4.9), (8.0, 3.2, -7.6), 2.2, 0.6, "silver-", flat="z", mirror=True)  # the belly fins
    seg[13].beam((14.4, 0, 3.4), (17.8, 0, 7.4), 4.2, 1.1, "steel")  # the dorsal fin, far back
    seg[13].beam((17.1, 0, 6.6), (19.4, 0, 9.4), 2.8, 0.7, "steel-")
    seg[15].beam((18.4, 0, -2.2), (21.4, 0, -5.6), 3.4, 0.9, "silver-")  # the anal fin, under it
    seg[15].beam((20.7, 0, -4.9), (22.6, 0, -7.2), 2.2, 0.6, "silver-")

    # the tail, on its own joint: a root block and a deep fork of two long, narrow lobes, three boxes each, dark tips
    tail = m.part("Tail", (end, 0, 0.5), f"B{len(GROUPS)}")
    tail.beam((end - 0.5, 0, 0.5), (end + 2.0, 0, 0.5), 3.6, 1.7, "steel")
    tail.beam((end + 1.0, 0, 1.3), (end + 5.2, 0, 5.9), 3.2, 1.4, "steel")
    tail.beam((end + 4.4, 0, 5.0), (end + 7.8, 0, 9.0), 2.4, 1.0, "steel")
    tail.beam((end + 7.1, 0, 8.2), (end + 9.4, 0, 11.0), 1.7, 0.6, "steel-")
    tail.beam((end + 1.0, 0, -0.3), (end + 5.2, 0, -4.9), 3.2, 1.1, "steel")
    tail.beam((end + 4.4, 0, -4.0), (end + 7.8, 0, -8.0), 2.4, 0.8, "steel")
    tail.beam((end + 7.1, 0, -7.2), (end + 9.4, 0, -10.0), 1.7, 0.5, "steel-")
