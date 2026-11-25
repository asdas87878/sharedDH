"""Ginsu Shark (Cretoxyrhina; in the game from 2026-11-25 under this name, an earlier shark).
Built as Megalodon V2, the second trial of docs/style/10-sharks-round-2.md (zone 8's Legendary: the giant prehistoric shark), for
tools/blender/voxel_kit.py. It stands beside the game's Megalodon (art/creatures/Megalodon) and replaces nothing; the
first trial (art/creatures/TrialMegalodon) read as a crocodile, so this is a separate try. Designed from the real animal.
Its idea: the titan. A long, heavy, powerful shark, not a mouth on a tail.
- The body is a torpedo in slices, about 85 cubes long, 22 deep (0.26 of the length) and 19 wide, deepest a third of
  the way back from the nose. From one slice to the next ONE thing changes by one cube: the back climbs in a long even
  line from the snout's tip to the back fin, the belly sags under the side fins, and both close in to a slim stalk.
- A pointed cone of a snout in four tilted blocks, each smaller and starting inside the last, two lighter forehead
  blocks on top: it overhangs the mouth, as a shark's does.
- The mouth: a long grin under the snout that runs level and then curves up toward the eye, slightly open. The upper
  lip is three bone plates under the snout and a fourth that climbs to the corner; the lower jaw is its own part in three
  blocks (chin, front, a ramus climbing to the same corner), shorter than the snout, with a throat block under it. Pink
  gums set inside both lips, big white triangles top and bottom.
- A small dark eye on the side of the head over the grin's rise, under a heavy brow that comes past it.
- Olive khaki over bone white; the line between them is a hard jagged sawtooth from the mouth's corner to the tail,
  kept on the flank's flat side.
- A tall sickle back fin, a huge crescent tail, long wing-like side fins.
- The one mark is history: ragged torn edges on the back fin, the tail and the left side fin, and one big pale X scar on
  the left flank.
The rider sits on the back in front of the back fin, where the body is deepest; the back is far too wide for leg slots."""
import math

NAME, ZONE, RARITY = "Ginsu Shark", "ZONE 5 / OPEN BLUE", "LEGENDARY"
U = 0.5
PALETTE = {"olive": "#7F7C4A", "bone": "#EEE7D3", "black": "#16181A", "mouth": "#5E1A26", "tooth": "#FFFFFF", "gum": "#EE8C9C"}
SHADE = 0.9
SEAT = (-9, 11, 9.6)
FRAME, ORTHO, ORTHO_SWIM = 3.7, 50.0, 58.0
TEXTURES = [{"tile": "stud", "on": "top", "colours": ["olive"]}]  # round studs on the top of the back only
DROP = 0.3  # how far a gum plate shows past its lip

# ---- the body in slices (from, to, cubes out, bottom, top). One number changes from slice to slice, never two.
# The head above the mouth first (its bottom is hidden by the lip that climbs under it), then the jowls behind the
# mouth's corner, then the front of the body to the deepest slice
BROWS = ((-32, -30, 6, -3, 6), (-30, -28, 6, -2, 6), (-28, -26, 6, -2, 7), (-26, -25, 6, -1, 7), (-25, -24, 6, 0, 7))
SKULL = ((-24, -22, 7, -8, 7), (-22, -21, 7, -9, 7), (-21, -19, 7, -9, 8))
FRONT = (("S1", ((-19, -18, 8, -9, 8), (-18, -16, 8, -10, 8), (-16, -15, 8, -10, 9), (-15, -13, 8, -11, 9),
                 (-13, -12, 9, -11, 9), (-12, -11, 9, -11, 10), (-11, -5, 9, -11, 11))),)
# behind the deepest slice the body closes in one cube at a time: where it gets narrower, where the back comes down and
# where the belly comes up (never two at one place), and where the joints are
NARROWER, LOWER, SHALLOWER = (2, 8, 13, 18, 23, 28), (0, 5, 10, 15, 20, 24, 29), (-3, 1, 6, 11, 16, 21, 26, 30)
JOINTS, END = (("S2", -5), ("S3", 7), ("S4", 14), ("S5", 20), ("S6", 26)), 31


def rear():
    """the slices behind the deepest one, part by part"""
    assert len(set(NARROWER + LOWER + SHALLOWER)) == len(NARROWER + LOWER + SHALLOWER)
    cuts = sorted(set(NARROWER + LOWER + SHALLOWER + tuple(x for _, x in JOINTS)) | {END})
    out, (n, bot, top) = [], FRONT[-1][1][-1][2:]
    for x0, x1 in zip(cuts, cuts[1:]):
        n, top, bot = n - (x0 in NARROWER), top - (x0 in LOWER), bot + (x0 in SHALLOWER)
        name = [part for part, x in JOINTS if x <= x0][-1]
        if not out or out[-1][0] != name:
            out.append((name, []))
        out[-1][1].append((x0, x1, n, bot, top))
    return tuple((name, tuple(slices)) for name, slices in out)


BODY = FRONT + rear()
CHAIN = ["Head"] + [name for name, _ in BODY] + ["Tail"]
AMPLITUDES = [1, 2, 3.5, 5.5, 8, 11, 15]


def steps(n):
    """the corners of the back and the belly: three steps where the body is thick, fewer as it thins"""
    return [(3, 1), (2, 1), (1, 1)] if n >= 8 else ([(2, 1), (1, 1)] if n >= 4 else [(1, 1)])


def flat_side(bot, top, n):
    """the rows of the flank between the corner steps"""
    k = len(steps(n))
    return bot + k, top - k


# the line between the olive and the bone: bone below this height at each x. A hard sawtooth: it climbs a cube at a time
# every two columns toward the tail and drops at once, in broad teeth of six to eight. It leaves the mouth's corner, drops to the lower
# flank under the side fins and climbs again along the stalk
TEETH = (6, 8, 6, 7, 8, 6, 8, 7, 6, 8, 6, 7, 6)


def base(x):
    if x < -18:
        return -(x + 24) // 2
    return -3 if x <= 14 else -3 + round((x - 14) * 3 / 17)


LINE = {}
_x = -24
for _t in TEETH:
    for _i in range(_t):
        LINE[_x] = base(_x) + min(_i // 2, 3)
        _x += 1


def pose(parts, phase):
    """a heavy, powerful swim: a slow wave side to side that grows toward the great tail, the head turning a little
    against it. The jaw hangs slightly open at rest and closes a little once a beat"""
    parts["Head"].rotation_euler.z = math.radians(1.2) * math.sin(phase + math.pi)
    for k, name in enumerate(CHAIN[1:]):
        parts[name].rotation_euler.z = math.radians(AMPLITUDES[k]) * math.sin(phase - 0.75 * (k + 1))
    parts["Jaw"].rotation_euler.y = math.radians(4) * (0.5 + 0.5 * math.sin(phase))


def slab(p, x0, x1, n, bot, top):
    """a slice of body: stepped corners, olive with a lighter top row, bone below the jagged line with a darker bottom row"""
    p.hull(x0, x1, n, bot, top, "olive", steps(n), steps(n))
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
    for x0, x1, n, bot, top in BROWS:  # the head above the mouth: two-step corners on top, flat underneath (the lip covers it)
        head.hull(x0, x1, n, bot, top, "olive", [(2, 1), (1, 1)], [])
        head.paint_sym(x0, x1, n, top - 1, top, "olive+")
    for s in SKULL:  # the jowls behind the mouth's corner, a step wider
        slab(head, *s)

    # the snout, a pointed cone: four blocks in a chain, each tilted nose-down, smaller than the last and starting inside
    # it, and two lighter forehead blocks on the first two, so its section steps in like the body's corners.
    # (from, to, the middle's height at each end, width, thickness)
    cone = ((-30.8, -35.6, 1.0, 0.5, 10.6, 6.0), (-35.0, -38.6, 0.5, 0.0, 8.0, 5.0), (-38.0, -40.8, 0.0, -0.5, 5.0, 3.8),
            (-40.3, -42.4, -0.5, -0.8, 2.4, 2.2))
    cones = [Plate(x0, z0, x1, z1, wide, thick) for x0, x1, z0, z1, wide, thick in cone]
    for c in cones:
        c.add(head, "olive")
    for c, x0, x1, wide, thick in ((cones[0], -31.0, -35.2, 7.6, 1.9), (cones[1], -34.6, -38.2, 5.4, 1.4)):
        sink = 0.05
        head.beam((x0, 0, c.top(x0) + thick / 2 - sink), (x1, 0, c.top(x1) + thick / 2 - sink), wide, thick, "olive+", flat="z")

    # THE MOUTH. The upper lip: three bone plates under the snout, each narrower, then a wider one that climbs to the
    # corner behind the eye
    def under(c, x0, x1, thick, wide):
        """a lip plate lying under snout block c from x0 to x1, its top a little inside the block"""
        return Plate(x0, c.bottom(x0) - thick / 2 + 0.12, x1, c.bottom(x1) - thick / 2 + 0.12, wide, thick)

    lip1 = under(cones[0], -30.8, -35.6, 1.5, 11.4)
    lip2 = under(cones[1], -35.0, -38.6, 1.3, 8.8)
    lip3 = under(cones[2], -38.0, -39.7, 1.1, 6.0)
    rise = Plate(-31.4, lip1.mid(-31.4) - 0.1, -23.6, 0.9, 13.4, 1.6)
    for plate in (lip1, lip2, lip3, rise):
        plate.add(head, "bone")
    # the dark inside: blocks that stay behind the teeth and end inside the lips and the jaw
    head.block(-39.2, (-2.6, 2.6, -6.9, -3.0), -35.0, (-3.6, 3.6, -7.1, -3.0), "mouth")
    head.block(-35.4, (-3.8, 3.8, -7.3, -3.0), -29.0, (-5.2, 5.2, -7.3, -2.2), "mouth")
    head.block(-29.4, (-5.2, 5.2, -7.2, -2.4), -24.2, (-5.2, 5.2, -3.0, 0.4), "mouth")
    rise.gum(head, -24.2, -30.4, -1)
    lip1.gum(head, -30.5, -35.4, -1)
    lip2.gum(head, -35.2, -38.2, -1)
    lip3.gum(head, -38.2, -39.45, -1)
    # the upper teeth: big triangles, bases sunk in the gums, nine a side and five across the front
    for plate, sink, xs, size, longs in ((rise, 0.35, (-25.8, -27.1, -28.4, -29.6), 1.2, (1.1, 1.4, 1.7, 1.9)),
                                         (lip1, 0.15, (-32.0, -33.4, -34.7), 1.3, (2.0, 2.0, 2.0)),
                                         (lip2, 0.15, (-36.3, -37.5), 1.2, (1.8, 1.7))):
        for x, length in zip(xs, longs):
            head.tooth(x, plate.teeth_y(size), plate.gum_edge(x, -1) + sink, size, length, "tooth", long=1.2)
    front = lip3.gum_edge(-39.0, -1) + 0.15
    head.tooth(-39.0, 0.0, front, 1.0, 1.6, "tooth", mirror=False, long=0.9)
    for y in (1.05, 2.1):
        head.tooth(-39.0, y, front, 1.0, 1.5, "tooth", long=0.9)

    # the eye: a small black block on the side of the head over the grin's rise, under a heavy brow that slants down to
    # the front, cuts across the top of the eye and comes past it: it is mean
    pupil = (6.4, 6.95, 1.4, 3.4)
    head.block(-29.6, pupil, -27.6, pupil, "black", mirror=True)
    head.beam((-31.4, 6.3, 3.3), (-26.4, 6.3, 4.6), 1.7, 2.0, "olive-", mirror=True)

    # the lower jaw, on its own joint at the corner, hanging slightly open: a ramus that climbs to the corner, a level
    # front and a chin, shorter than the snout; a throat block under the ramus
    jaw = m.part("Jaw", (-24.2, 0, -1.2), "Head")
    ramus = Plate(-29.6, -8.0, -24.0, -1.0, 12.2, 2.6)
    jaw1 = Plate(-28.0, -7.9, -36.0, -8.3, 11.8, 2.0)
    jaw0 = Plate(-35.4, -8.25, -38.2, -8.6, 8.6, 1.6)
    for plate in (ramus, jaw1, jaw0):
        plate.add(jaw, "bone")
    jaw.beam((-23.6, 0, -6.6), (-28.4, 0, -7.2), 9.8, 3.0, "bone", flat="z")  # the throat
    ramus.gum(jaw, -24.8, -29.2, 1)
    jaw1.gum(jaw, -28.6, -35.8, 1)
    jaw0.gum(jaw, -35.6, -37.9, 1)
    for plate, xs, size, length in ((jaw1, (-30.0, -31.5, -33.0, -34.5), 1.2, 1.5), (jaw0, (-36.0,), 1.1, 1.3)):
        for x in xs:
            jaw.tooth(x, plate.teeth_y(size), plate.gum_edge(x, 1) - 0.15, size, -length, "tooth", long=1.1)
    front = jaw0.gum_edge(-37.45, 1) - 0.15
    jaw.tooth(-37.45, 0.0, front, 1.0, -1.3, "tooth", mirror=False, long=0.7)
    jaw.tooth(-37.45, 1.3, front, 1.0, -1.2, "tooth", long=0.7)

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

    for x, j in ((-19, 8), (-17, 8), (-15, 8), (-13, 9), (-11, 9)):  # five long gill slits, shallow dents across the line
        s1.dent(x, x + 1, j, -5, LINE[x], "bone-")
        s1.dent(x, x + 1, j, LINE[x], 3, "olive-")

    # THE MARK, the scar: one big pale X on the left flank, under the back fin, in whole cubes
    for d in range(6):
        for x, z in ((-5 + d, 6 - d), (-5 + d, 1 + d)):
            j = min(j for (i, j, k) in s2.cells if i == x and k == z)  # the outermost cube of the left flank there
            s2.cells[(x, j, z)] = "bone"

    # the back fin: a tall sickle of three boxes, each smaller, thinner and leaning further back than the one before.
    # THE MARK's torn edge: two bites out of its trailing edge, where a narrower box leaves the rear edge set in
    s2.beam((0.5, 0, 8.5), (2.5, 0, 14.0), 10.0, 2.4, "olive")
    s2.beam((0.4, 0, 13.4), (1.4, 0, 16.0), 5.6, 2.0, "olive")  # set forward, off the rear edge: the bite
    s2.beam((2.4, 0, 15.2), (6.0, 0, 21.0), 6.4, 1.6, "olive")
    s2.beam((5.4, 0, 20.2), (10.0, 0, 24.6), 3.6, 1.0, "olive-")
    # the side fins: long and wing-like, swept back and down, from low on the flank under the gills. The left one torn:
    # its tip split in two ragged points
    s1.beam((-17.0, 6.5, -6.0), (-10.0, 16.0, -9.0), 9.0, 2.2, "olive", flat="z", mirror=True)
    s1.beam((-11.5, 14.5, -8.6), (-5.0, 23.0, -11.2), 6.4, 1.5, "olive", flat="z", mirror=True)
    s1.beam((-6.2, 21.6, -10.8), (-1.0, 28.0, -13.0), 4.0, 0.9, "olive-", flat="z")
    s1.beam((-6.6, -23.2, -10.95), (-2.6, -28.4, -12.7), 2.6, 0.8, "olive-", flat="z")
    s1.beam((-3.8, -21.4, -11.0), (-1.0, -24.0, -11.9), 2.0, 0.5, "olive-", flat="z")
    s3.beam((9.0, 3.5, -6.0), (13.0, 7.5, -9.6), 3.4, 1.0, "bone-", flat="z", mirror=True)  # the belly fins
    s5.beam((21.0, 0, 3.8), (23.4, 0, 7.2), 2.8, 1.2, "olive")  # the second back fin: small
    s5.beam((21.6, 0, -2.6), (23.6, 0, -5.6), 2.6, 1.1, "bone-")  # the anal fin, as small

    # the tail, on its own joint: a short square stock that carries on from the stalk's flat end, then a huge crescent
    # of two lobes, each in three boxes that sweep back more toward the tip. THE MARK's last torn edges: both lobes end
    # in a ragged tip split in two
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
