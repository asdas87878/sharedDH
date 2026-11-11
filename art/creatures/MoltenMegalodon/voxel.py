"""Molten Megalodon (zone 8's Mythic) for tools/blender/voxel_kit.py (docs/style/04-voxel-style.md), a variant of
art/creatures/Megalodon: the same animal, size and seat, cracked with glowing lava.
Its idea: the heat comes out of the throat. A white-hot mouth, and the fire cooling as it runs back along the animal.
Its ways to be Mythic (docs/style/05-rarity-look.md): light with a source, material (basalt and cooled rock), size.
- Basalt-dark body with an ash underside (the rows of the belly's corner steps: it follows the belly's curve), ash lips
  and jaw.
- The lava follows the model's own lines and nothing else: the five gill slits (hot orange), then one seam at every joint
  of the body, the first cube of each piece, from the back down to the belly: orange behind the gills, orange-red in the
  middle, deep red at the tail. No two patterns cross; the flanks between the seams stay plain.
- The inside of the mouth glows: hot orange, white-hot behind the front teeth, with small lights on the teeth.
- A keel of cooled-rock plates along the spine, five cubes wide, broken at each seam so the lava shows between them. It
  climbs in two broad steps from the nape to the saddle plate the rider sits on (legs in a slot either side of it), is a
  low collar round the back fin, and thins out toward the tail. Two more plates lie on the forehead.
- The same deep red sits in the joints of the tail's boxes: the head's echo.
- Teeth of dark obsidian, so they stand against the glow of the mouth.
- An ember eye, no pupil (its idea is fire), under the brow box that comes past it.
Changed from the first draft besides: the body is widest at the shoulders and narrows from behind the seat (it was one width for
thirty cubes: square from above), in slices that change one thing by one cube; the lower jaw has a deeper block under its
hinge half, so it is a wedge from the side and not a tray; the old scars are gone (the seams are its marks)."""
import math

NAME, ZONE, RARITY = "Molten Megalodon", "ZONE 8 / VENTS", "MYTHIC"
U = 0.5
PALETTE = {"back": "#2D2B35", "ash": "#74665F", "rock": "#57525F", "black": "#14171B", "tooth": "#30282E", "gum": "#5A1B16",
           "throat": "#FFF2B8", "lava": "#FF9A22", "magma": "#F2561B", "ember": "#C42A1A"}
SEAT = (-11, 14, 2.5)  # on the saddle plate
GLOW = {"throat": 1.0, "lava": 0.85, "magma": 0.75, "ember": 0.65}  # the heat: strongest in the throat, weakest at the tail
LIGHTS = [("Head", (-39.3, 0, -5.3), "#FFC766", 60, 0.8), ("Head", (-34.0, 6.2, -5.2), "#FF9A3C", 30, 0.6)]  # the throat's light on the teeth
FRAME, ORTHO, ORTHO_SWIM = 3.7, 50.0, 58.0
TEXTURES = [{"tile": "stud", "on": "top", "colours": ["back", "rock"]}]  # round studs on the faces that look up
DROP = 0.25  # how far a gum plate shows past its lip
LIP = 1.2  # the thickness of the ash lip plate under the snout

# the body in slices (from, to, cubes out, bottom, top). One number changes from slice to slice, never two. The head's two
# slices first; then, from the gills back, where each number changes by one cube, and where the joints are
SKULL = ((-31, -29, 9, -9, 9), (-29, -27, 9, -9, 10))  # short: the head is mostly snout and jaw
START = (10, -9, 10)  # cubes out, bottom, top at the first gill
WIDER, HIGHER, DEEPER = (-17,), (-14,), (-21, -12)  # the shoulders are the widest; the back climbs to the seat, the belly sags
NARROWER, LOWER, SHALLOWER = (-6, -2, 2, 6, 12, 15, 19, 23), (5, 9, 13, 17, 21, 25, 27), (-4, 0, 4, 8, 11, 16, 20, 24)
JOINTS, END = (("S1", -27), ("S2", -14), ("S3", 3), ("S4", 10), ("S5", 17), ("S6", 24)), 31
SEAMS = {"S2": "lava", "S3": "magma", "S4": "magma", "S5": "ember", "S6": "ember"}  # the lava at each joint, cooling


def body():
    """the slices from the gills to the tail, part by part"""
    events = WIDER + HIGHER + DEEPER + NARROWER + LOWER + SHALLOWER
    assert len(set(events)) == len(events)
    cuts = sorted(set(events) | {x for _, x in JOINTS} | {END})
    out, (n, bot, top) = [], START
    for x0, x1 in zip(cuts, cuts[1:]):
        n, top, bot = n + (x0 in WIDER) - (x0 in NARROWER), top + (x0 in HIGHER) - (x0 in LOWER), bot + (x0 in SHALLOWER) - (x0 in DEEPER)
        name = [part for part, x in JOINTS if x <= x0][-1]
        if not out or out[-1][0] != name:
            out.append((name, []))
        out[-1][1].append((x0, x1, n, bot, top))
    return tuple((name, tuple(slices)) for name, slices in out)


BODY = body()
CHAIN = ["Head"] + [name for name, _ in BODY] + ["Tail"]
AMPLITUDES = [1, 2, 3.5, 5.5, 8, 11, 16]


def pose(parts, phase):
    """a shark's swim, heavy: a slow wave side to side that grows toward the tail, the head turning a little against it.
    The jaw hangs open at rest and bites up a little once a beat"""
    parts["Head"].rotation_euler.z = math.radians(1.5) * math.sin(phase + math.pi)
    for k, name in enumerate(CHAIN[1:]):
        parts[name].rotation_euler.z = math.radians(AMPLITUDES[k]) * math.sin(phase - 0.75 * (k + 1))
    parts["Jaw"].rotation_euler.y = math.radians(5) * (0.5 + 0.5 * math.sin(phase))


def steps(n):
    """the corners of the back and the belly: three steps where the body is thick, fewer as it thins"""
    return [(3, 1), (2, 1), (1, 1)] if n >= 9 else ([(2, 1), (1, 1)] if n >= 4 else [(1, 1)])


def slab(p, x0, x1, n, bot, top):
    """a slice of body: stepped corners, basalt with a lighter top row; the rows of the belly's steps are ash"""
    p.hull(x0, x1, n, bot, top, "back", steps(n), steps(n))
    p.paint_sym(x0, x1, n, top - 1, top, "back+")
    p.paint_sym(x0, x1, n, bot, bot + len(steps(n)), "ash")
    p.paint_sym(x0, x1, n, bot, bot + 1, "ash-")


def seam(p, x, n, bot, top, colour):
    """a lava seam: one cube of the body, from the back down to the belly's steps. Flush over the back and its corner
    steps; on the flank it is a shallow dent, like a gill slit"""
    k = len(steps(n))
    p.paint_sym(x, x + 1, n, bot + k, top, colour)
    p.dent(x, x + 1, n, bot + k, top - k, colour)


def fin_seam(p, p0, p1, t0, t1, width, thick, colour):
    """lava in the joint of two of a fin's boxes: a short band round the box that runs from p0 to p1, from t0 to t1 along
    it (where it leaves the box before), a little wider and thicker than it"""
    d = [b - a for a, b in zip(p0, p1)]
    length = math.sqrt(sum(v * v for v in d))
    p.beam([a + v / length * t0 for a, v in zip(p0, d)], [a + v / length * t1 for a, v in zip(p0, d)], width, thick, colour)


def plate(p, x0, x1, n, z0, z1):
    """a plate of cooled rock on the spine, its top row lighter"""
    p.sym(x0, x1, n, z0, z1, "rock")
    p.paint_sym(x0, x1, n, z1 - 1, z1, "rock+")


def build(m):
    head = m.part("Head", (SKULL[-1][1], 0, 0))
    for s in SKULL:  # the back of the head: the eye sits on its side
        slab(head, *s)
    head.sym(-31, -29, 8, -9, -7, "ash")  # the jaw's hinge: the bottom rows are wider here, so the jaw's root is buried
    head.paint_sym(-31, -29, 8, -9, -8, "ash-")
    # the snout, a blunt cone as long as the mouth: three low, wide blocks in a chain, each tilted nose-down and narrower
    # than the last, with a pale lip plate underneath; the underside rises a little to the tip. (from, to, the middle's
    # height at each end, width, thickness, where its gum starts)
    blocks = ((-30.5, -37.2, 1.6, 1.1, 17.4, 5.2, -30.5), (-36.4, -40.4, 1.2, 0.8, 13.6, 4.2, -37.5), (-39.6, -41.8, 1.45, 1.27, 9.4, 3.9, 0.0))

    def middle(k, x):
        x0, x1, z0, z1 = blocks[k][:4]
        return z0 + (z1 - z0) * (x - x0) / (x1 - x0)

    def lip_bottom(k, x):
        """the underside of block k's lip plate at x"""
        return middle(k, x) - blocks[k][5] / 2 - LIP

    for k, (x0, x1, z0, z1, wide, thick, gum_from) in enumerate(blocks):
        head.beam((x0, 0, z0), (x1, 0, z1), wide, thick, "back", flat="z")
        lip = thick / 2 + LIP / 2
        head.beam((x0, 0, z0 - lip), (x1, 0, z1 - lip), wide - 0.4, LIP, "ash", flat="z")
        if gum_from:  # a thin gum plate under the lip, set in from its edge, that the teeth hang from
            mid = 0.025 - DROP / 2
            head.beam((gum_from, 0, lip_bottom(k, gum_from) + mid), (x1 + 0.3, 0, lip_bottom(k, x1 + 0.3) + mid), wide - 1.0, DROP + 0.05,
                      "gum", flat="z")
    # the forehead: two narrower, lighter blocks lying on the first two, each starting inside the one behind, so the
    # snout's section steps in like the body's corners and its top comes down to the nose in three steps
    for k, x0, x1, wide, thick in ((0, -30.5, -36.6, 12.4, 4.2), (1, -35.8, -39.8, 8.6, 2.8)):
        rise = blocks[k][5] / 2 + thick / 2 - 0.05
        head.beam((x0, 0, middle(k, x0) + rise), (x1, 0, middle(k, x1) + rise), wide, thick, "rock", flat="z")
    nostril = (4.4, 4.95, 0.3, 1.2)
    head.block(-41.4, nostril, -40.5, nostril, "black", mirror=True)
    # the dark inside of the mouth: two blocks that stay behind the teeth and end inside the lips and the jaw
    mouth = (-5.4, 5.4, -8.2, -1.8)
    head.block(-37.0, mouth, -30.0, mouth, "lava")
    mouth = (-3.9, 3.9, -8.6, -1.7)
    head.block(-38.8, mouth, -36.9, mouth, "throat")
    # the upper teeth, big triangles with their bases sunk a little into the gum: blades down each side, a row across the front
    for k, x in ((0, -31.7), (0, -33.2), (0, -34.7), (0, -36.15), (1, -38.3)):
        head.tooth(x, (7.7, 5.8)[k], lip_bottom(k, x) - DROP + 0.1, 1.0, 2.2, "tooth", long=1.4)
    front = lip_bottom(1, -39.6) - DROP + 0.1
    head.tooth(-39.6, 0.0, front, 1.35, 2.3, "tooth", mirror=False, long=0.9)
    for y in (1.45, 2.9, 4.35):
        head.tooth(-39.6, y, front, 1.35, 2.2, "tooth", long=0.9)
    # the eye: small, on the side of the head over the corner of the mouth. A dark socket, a thin halo of soft light, a
    # dark pupil standing out of it. The brow box slants down to the front, cuts across the top of the eye and comes past it
    # in front and behind, so the shark scowls; a slimmer block carries its line on along the snout
    socket = (9.38, 9.97, 2.6, 5.4)
    head.block(-30.6, socket, -27.8, socket, "back-", mirror=True)
    halo = (9.85, 10.15, 3.0, 5.0)
    head.block(-30.25, halo, -28.15, halo, "ember", mirror=True)
    pupil = (9.97, 10.35, 3.4, 4.6)
    head.block(-29.9, pupil, -28.5, pupil, "lava", mirror=True)
    head.beam((-32.4, 9.85, 4.5), (-27.6, 9.85, 5.75), 1.7, 2.2, "back", mirror=True)
    head.beam((-35.0, 9.3, 3.74), (-30.6, 9.3, 4.89), 1.2, 1.7, "back", mirror=True)

    # the lower jaw, on its own joint, hanging open: two deep boxes, the smaller in front, ending short of the nose,
    # with a chin plate under them, a gum line inside their edge and a row of teeth that stands a little inside the upper row
    jaw = m.part("Jaw", (-29.5, 0, -6.6), "Head")
    jaws = ((-29.6, -37.4, -6.59, -9.4, 15.4, 3.0, -31.3), (-36.6, -40.1, -9.05, -9.2, 11.6, 2.2, -37.7))

    def jaw_mid(k, x):
        x0, x1, z0, z1 = jaws[k][:4]
        return z0 + (z1 - z0) * (x - x0) / (x1 - x0)

    def jaw_top(k, x):
        return jaw_mid(k, x) + jaws[k][5] / 2

    for k, (x0, x1, z0, z1, wide, thick, gum_from) in enumerate(jaws):
        jaw.beam((x0, 0, z0), (x1, 0, z1), wide, thick, "ash", flat="z")
        mid = DROP / 2 - 0.025  # the lower gum lies inside the jaw's own edge all round
        jaw.beam((gum_from, 0, jaw_top(k, gum_from) + mid), (x1 + 0.35, 0, jaw_top(k, x1 + 0.35) + mid), wide - 1.0, DROP + 0.05, "gum",
                 flat="z")
    # a deeper, narrower block under the hinge half: from the side the jaw is a wedge, from the front a stepped U
    under = jaws[0][5] / 2 + 1.1 - 0.1
    jaw.beam((-30.4, 0, jaw_mid(0, -30.4) - under), (-35.8, 0, jaw_mid(0, -35.8) - under), 10.6, 2.2, "ash-", flat="z")
    for x in (-32.45, -33.95, -35.45):  # sunk deeper than the others: the jaw slopes, and the whole base must lie in it
        jaw.tooth(x, 6.7, jaw_top(0, x) + DROP - 0.45, 1.0, -2.05, "tooth", long=1.4)
    jaw.tooth(-38.3, 4.8, jaw_top(1, -38.3) + DROP - 0.1, 1.0, -1.6, "tooth", long=1.4)
    front = jaw_top(1, -39.35) + DROP - 0.1
    jaw.tooth(-39.35, 0.0, front, 1.15, -1.7, "tooth", mirror=False, long=0.8)
    for y in (1.25, 2.5, 3.75):
        jaw.tooth(-39.35, y, front, 1.15, -1.6, "tooth", long=0.8)

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
        seg.sym(x0 - 1, x0, max(min(n, fn) - 2, 0), max(bot, fbot) + clear, min(top, ftop) - clear, "back-")
        if name in SEAMS:  # the lava seam: the first cube of the piece
            seam(seg, x0, n, bot, top, SEAMS[name])
        before = slices[-1]
    s1, s2, s3, s4, s5, s6 = (segs[name] for name, _ in BODY)

    for x in (-26, -24, -22, -20, -18):  # five long gill slits, shallow dents: the hottest lava after the throat
        s1.dent(x, x + 1, 10, -3, 3, "lava")

    # the keel of cooled-rock plates on the spine, broken at every seam. It climbs from the nape in two broad steps to
    # the saddle, is a low collar round the back fin, and thins out toward the tail
    plate(s1, -25, -20, 2, 10, 12)
    plate(s1, -20, -14, 2, 10, 13)
    plate(s2, -13, -8, 2, 11, 14)  # the saddle: the rider sits on it
    s2.dent(-12, -10, 2, 11, 13.7, "rock-")  # a slot either side for the rider's legs
    plate(s2, -8, 3, 2, 11, 12)  # the back fin's collar
    plate(s3, 4, 9, 2, 10, 12)
    plate(s4, 11, 16, 1, 8, 10)
    plate(s5, 18, 21, 1, 7, 8)

    # the fins: each a few boxes at an angle, every box smaller and thinner than the one before and starting inside it,
    # the first starting deep enough in the body that its whole end is buried.
    # The back fin: an upright base, then a blade swept back in two boxes. The blade leaves the base's top edge in front of
    # its rear corner and leans back past it, which leaves a notch in the rear edge: an old bite
    s2.beam((-2.7, 0, 9.0), (-1.1, 0, 16.5), 10.6, 2.4, "back")
    s2.beam((-2.8, 0, 14.6), (0.8, 0, 20.6), 6.4, 1.6, "back")
    s2.beam((0.51, 0, 17.98), (3.59, 0, 23.12), 3.6, 1.0, "back-")
    # the side fins: huge, swept back and a little down, from low on the flank under the last gill slits
    s1.beam((-19.5, 6.5, -4.2), (-12.5, 16.8, -6.2), 9.0, 2.2, "back", flat="z", mirror=True)
    s1.beam((-13.8, 15.2, -5.9), (-9.0, 22.0, -7.2), 6.6, 1.5, "back", flat="z", mirror=True)
    s1.beam((-10.0, 20.6, -6.95), (-6.6, 25.6, -7.9), 4.4, 0.9, "back-", flat="z", mirror=True)
    s3.beam((7.4, 3.4, -6.4), (11.0, 7.4, -9.6), 3.6, 1.0, "ash-", flat="z", mirror=True)  # the belly fins
    s5.beam((21.0, 0, 4.8), (23.6, 0, 8.5), 3.0, 1.3, "back")  # the second back fin: small
    s5.beam((21.6, 0, -3.2), (23.8, 0, -6.4), 2.8, 1.2, "ash-")  # the anal fin, as small

    # the tail, on its own joint: a short square stock that carries on from the body's flat end, all dark (the belly's
    # edge stops at the tail's root), then a tall crescent of two lobes, each in three boxes that sweep back more toward
    # the tip. The lobes' roots and the fork between them lie inside the stock
    tail = m.part("Tail", (END, 0, 0.5), "S6")
    tail.sym(END, END + 6, 2, -2, 3, "back")
    tail.sym(END - 1, END, 1, -1, 2, "back-")  # its sleeve
    tail.paint_sym(END, END + 1, 2, -1, 3, "ember")  # the last seam, the coolest
    tail.dent(END, END + 1, 2, -1, 2, "ember")
    tail.beam((34.0, 0, 1.0), (36.6, 0, 8.1), 6.4, 2.0, "back")
    tail.beam((36.0, 0, 6.8), (39.0, 0, 12.6), 4.8, 1.4, "back")
    tail.beam((38.4, 0, 11.5), (40.5, 0, 15.9), 3.2, 0.8, "back-")
    tail.beam((34.0, 0, 0.0), (36.2, 0, -6.1), 6.0, 1.7, "back")
    tail.beam((35.7, 0, -5.0), (38.2, 0, -9.8), 4.4, 1.1, "back")
    tail.beam((37.6, 0, -8.9), (39.8, 0, -12.4), 3.0, 0.6, "back-")
    # the head's echo: the same deep red in the joints of the tail's own boxes
    fin_seam(tail, (36.0, 0, 6.8), (39.0, 0, 12.6), 0.8, 2.0, 5.3, 1.7, "ember")
    fin_seam(tail, (38.4, 0, 11.5), (40.5, 0, 15.9), 1.0, 1.7, 3.7, 1.1, "ember")
    fin_seam(tail, (35.7, 0, -5.0), (38.2, 0, -9.8), 0.6, 1.7, 4.9, 1.4, "ember")
    fin_seam(tail, (37.6, 0, -8.9), (39.8, 0, -12.4), 0.9, 1.5, 3.5, 0.86, "ember")
