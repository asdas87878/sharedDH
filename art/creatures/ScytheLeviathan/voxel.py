"""Scythe Leviathan (a Mythic, zone not set; docs/style/12-leviathans.md, leviathan 1) for tools/blender/voxel_kit.py.
Our own animal: an armoured lobster's body (a thorax, a tapering abdomen of plates, a tail fan) with a shark's head.
Another game's creature was looked at once, for six qualities only; no proportion, plate shape, pattern or pose is taken.
Its idea: a grinning shark's head on an armoured lobster, four scythe limbs streaming behind it.
- The head is the hero: 30 long, 19 wide, 16 deep at the back. A shark's grin 21 long from under the snout to past the
  eye, open more than 5 at the front and 2 at its corner, the corner turned up; few big ivory teeth top and bottom on a
  dark gum line, lit lime inside; a heavy lower jaw 4 deep in two blocks that juts a cube past the upper teeth. The
  snout is two turned blocks. A gold halo eye four cubes across under the helmet's front edge.
- One hot pink horn on the snout, leaning forward. Nothing else on the animal is pink.
- Armour over flesh: seven slate plates. A helmet with cheek and neck guards and two swept-back crest blades; a shoulder
  plate, the hump the rider sits on, three cubes higher than the helmet and two wider than the body each side; and five
  shingles down the abdomen, each two cubes lower than the one in front and overhung by it one cube, each a cube
  narrower than its slice each side so the crimson flank shows from above. A thin gold line along every plate's lower
  edge. A bare crimson neck three cubes long parts the helmet from the shoulder plate.
- Mass: the thorax 22 deep, its belly below the chin; the side outline a wedge, tallest at the shoulders, falling to
  the fan.
- Two heavy clawed arms from low on the front of the thorax, folded down and forward under the jaw and outside it: an
  upper arm, a forearm, a palm, and a pincer of two fingers with indigo talons.
- Four scythes from the flanks at the rear of the thorax: a root up, out and back, a long shaft sweeping back in two boxes
  with a bend, a blade hooking down with an ivory edge; four gold lamps under each shaft, a small stud of each on top.
  The lower pair is 0.7 of the upper, lower and further out.
- Lit from below: a lime belly plate under the thorax and every slice, two rows deep, seen from the side.
- The one flaw: the lower left scythe is snapped short, its blade gone, the shaft ending in a ragged stump.
The rider sits on the shoulder plate's plateau (far too wide for leg slots), the helmet's rear lip and crest blades in
front and to the sides, the abdomen falling away behind, and is seen from behind between the upper scythes."""
import math

NAME, ZONE, RARITY = "Scythe Leviathan", "ZONE 9 / NOT SET", "MYTHIC"
U = 0.45
PALETTE = {"crimson": "#D9202E", "slate": "#3F5E8C", "indigo": "#2A2466", "gold": "#FFB52E", "lamp": "#FFB52E",
           "lime": "#C8F03C", "pink": "#FF4FA0", "ivory": "#F6EED8", "black": "#15121C"}
SHADE = 0.9
GLOW = {"lime": 0.8, "lamp": 1.0}  # the belly plates and the mouth; the scythes' lamps and the eye's ring (gold lines don't)
TEXTURES = [{"tile": "stud", "on": "top", "colours": ["slate"]}]
FRAME, ORTHO, ORTHO_SWIM = 4.5, 57.0, 70.0
LIGHTS = [("Thorax", (0.0, 0, -14.0), "#C8F03C", 300, 1.5), ("Head", (-29.0, 0, -3.0), "#C8F03C", 170, 1.0)]

# ---- the numbers as built, in cubes (the creature points to -X). Widths are odd: n cubes out either side is 2n + 1
HEAD = (-40, -10)  # 30 long: the jaw's tip to the neck
HEAD_N, HELMET_N = 9, 10  # the head 19 wide, 21 over the helmet
HEAD_Z = (-8, 8)  # 16 deep at the back, 18 with the helmet's rear lip
THORAX = (-10, 10)  # 20 long
NECK = (-10, -7)  # its first three cubes: a bare neck, lower than the helmet and five lower than the shoulder plate
THORAX_N, SHOULDER_N = 9, 11  # the body 19 wide, the shoulder plate 23: it overhangs two cubes a side
THORAX_Z = (-11, 11)  # 22 deep: three over the helmet, the belly a cube or two under the chin
BELLY_STEP = 7  # behind this the belly steps up three cubes to meet the abdomen
# the abdomen: (from, to, the body's cubes out, bottom, top, the plate's rows). The plate is a cube narrower each side.
# Widths 17, 15, 13, 11, 9; depths 14, 12, 10, 8, 6; each top two cubes lower: five shingles
SLICES = ((10, 16, 8, -6, 8, 3), (16, 22, 7, -6, 6, 3), (22, 28, 6, -6, 4, 3), (28, 34, 5, -6, 2, 2), (34, 40, 4, -6, 0, 2))
FAN = (40, 48)  # the tail fan: 8 long, 15 across, 2 deep
SEAT = (2, 11, 9.5)


class Plate:
    """a snout block, a lip or a jaw: a flat block lying across the head from (x0, z0) to (x1, z1) in the side view"""

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


def along_line(line, x0, x1, offset, wide, thick):
    """a plate from x0 to x1 whose middle runs `offset` above the line (a function of x)"""
    return Plate(x0, line(x0) + offset, x1, line(x1) + offset, wide, thick)


def strip(plate, xa, xb, side, wide, show=0.45, thick=0.8):
    """the thin dark gum line along a lip's inner edge: narrower than the lip, showing `show` past it below the lip
    (side -1) or above it (+1); the teeth stand on it"""
    shift = side * (plate.thick / 2 + show - thick / 2) * plate.up
    return Plate(xa, plate.mid(xa) + shift, xb, plate.mid(xb) + shift, wide, thick)


def edge_line(part, x0, x1, n, z, ledge=False):
    """the thin gold line along a plate's lower edge: a strip a third of a cube proud of the plate's side, its inner face
    inside the plate's cubes, every face clear of the cubes' planes. ledge: the body under the plate is wider than the
    plate, and the strip lies in the corner, sunk into the ledge"""
    section = (n + 0.15, n + 0.8, z - 0.3, z + 0.5) if ledge else (n + 0.15, n + 0.8, z + 0.2, z + 0.75)
    part.block(x0 + 0.3, section, x1 - 0.3, section, "gold", mirror=True)


def segment(part, x0, x1, n, bot, top, rows, last):
    """a slice of the abdomen: the crimson body, a lit lime belly plate two rows deep under it, and on top a slate
    shingle a cube narrower each side (the flank shows from above): a plateau and one step. It runs a cube out over the
    next slice, whose top is two cubes lower"""
    part.hull(x0, x1, n, bot, top - rows, "crimson", [], [(2, 2)])
    part.paint_sym(x0, x1, n, bot, bot + 2, "lime")
    part.hull(x0, x1, n - 1, top - rows, top, "slate", [(1, 1)], [])
    if not last:
        part.hull(x1, x1 + 1, n - 1, top - 2, top, "slate", [(1, 1)], [])
    edge_line(part, x0, x1, n - 1, top - rows, ledge=True)


def sub(a, b):
    return tuple(x - y for x, y in zip(a, b))


def unit(v):
    n = math.sqrt(sum(x * x for x in v))
    return tuple(x / n for x in v)


def at(p, v, d):
    return tuple(a + b * d for a, b in zip(p, v))


def dist(a, b):
    return math.sqrt(sum(x * x for x in sub(b, a)))


def frame(p0, p1):
    """the three directions of a limb's box from p0 to p1, as beam(flat="y") lays it: along it, across it (up, for a
    level limb) and through it (sideways)"""
    along = unit(sub(p1, p0))
    thin = unit(tuple(r - along[1] * a for a, r in zip(along, (0.0, 1.0, 0.0))))
    wide = (along[1] * thin[2] - along[2] * thin[1], along[2] * thin[0] - along[0] * thin[2], along[0] * thin[1] - along[1] * thin[0])
    return along, wide, thin


def limb(part, p0, p1, wide, thick, colour):
    """a box from p0 to p1, `wide` up and down and `thick` through"""
    along, w, t = frame(p0, p1)
    length = dist(p0, p1)
    part._oriented(at(p0, along, length / 2), along, w, t, (length, wide, thick), colour, False)


def talon(part, tip, fr, half, length, hook, colour):
    """a pointed claw on the end of a finger: its base inside the finger's tip, its point `length` on and `hook` across"""
    c = at(tip, fr[0], -0.5)
    base = [at(at(c, fr[1], a * half), fr[2], b * half) for a, b in ((-1, -1), (1, -1), (1, 1), (-1, 1))]
    part.spike(base, at(at(tip, fr[0], length), fr[1], hook), colour)


# a scythe, right side (the left is mirrored): where its root starts inside the thorax, the root's end, the shaft's bend,
# the shaft's end, the blade's knee, the blade's end; then each box's (width, thickness): root, the shaft's two boxes,
# the blade's two; then a lamp's size, the ivory edge's depth under the two blade boxes, and the point's length
UPPER = {"points": ((2.5, 6.5, -2.0), (12.0, 18.0, 6.5), (30.0, 19.5, 13.5), (48.5, 21.5, 14.5), (56.3, 22.0, 10.5), (59.5, 22.3, 4.2)),
         "boxes": ((3.4, 3.4), (2.6, 2.4), (2.1, 1.8), (1.6, 1.4), (1.3, 1.1)), "lamp": 2.2, "edge": (2.0, 1.4), "tip": 3.4}
LOWER = {"points": ((6.5, 6.5, -4.0), (12.5, 16.5, -2.0), (26.0, 20.5, -2.0), (39.5, 23.3, -5.5), (45.3, 23.7, -8.5), (47.8, 23.9, -13.0)),
         "boxes": ((2.6, 2.6), (1.9, 1.7), (1.5, 1.3), (1.25, 1.1), (1.0, 0.85)), "lamp": 1.6, "edge": (1.5, 1.0), "tip": 2.4}
LAMPS = (0.32, 0.78)  # where the two lamps sit along each of a shaft's two boxes: four to a shaft
SNAP = 0.3  # THE FLAW: the lower left scythe's shaft ends here along its second box, its blade gone
SCYTHES = (("SUR", UPPER, 1, False), ("SUL", UPPER, -1, False), ("SLR", LOWER, 1, False), ("SLL", LOWER, -1, True))


def scythe(m, name, spec, side, snapped):
    """one scythe: a root up, out and back from the flank; a long shaft sweeping back in two boxes with a bend between
    them, four gold lamps hanging under it, each with a small stud on top; a blade hooking down in two boxes with an
    ivory edge on its inner side and a point. Three parts on three joints, each box starting inside the one before and
    thinner. snapped: the shaft is broken off short after its bend, a ragged stump, and there is no blade"""
    p0, p1, pm, p2, p3, p4 = ((x, y * side, z) for x, y, z in spec["points"])
    (rw, rt), box1, box2, (aw, a_t), (bw, bt) = spec["boxes"]
    r_along = unit(sub(p1, p0))
    root = m.part(name + "1", at(p0, r_along, 3.6), "Thorax")
    limb(root, p0, p1, rw, rt, "indigo")
    s0 = at(p1, r_along, -rw / 2 - 0.2)
    shaft = m.part(name + "2", s0, root.name)
    m0 = at(pm, unit(sub(pm, s0)), -1.2)
    if snapped:
        p2 = at(m0, sub(p2, m0), SNAP)
    size = spec["lamp"]
    for start, end, (w, t), lit in ((s0, pm, box1, True), (m0, p2, box2, not snapped)):
        limb(shaft, start, end, w, t, "indigo")
        along, wide, thin = frame(start, end)
        for f in LAMPS if lit else ():
            c = at(start, along, dist(start, end) * f)
            shaft._oriented(at(c, wide, -(w / 2 + (size - 0.5) / 2)), along, wide, thin, (size, size + 0.5, t - 0.6), "lamp", False)
            shaft._oriented(at(c, wide, w / 2 + 0.05), along, wide, thin, (size * 0.6, 0.9, t - 0.6), "lamp", False)
    if snapped:  # the stump: two splinters of different lengths, side by side, the pale core showing
        for dw, dt, far, half, sunk, colour in ((0.3, 0.25, 2.8, 0.4, 0.3, "ivory"), (-0.4, -0.3, 1.6, 0.35, 0.5, "indigo")):
            c = at(at(at(p2, along, -sunk), wide, dw), thin, dt)
            base = [at(at(c, wide, a * half), thin, b * half) for a, b in ((-1, -1), (1, -1), (1, 1), (-1, 1))]
            shaft.spike(base, at(at(at(c, along, far + sunk), wide, dw * 0.6), thin, dt * 0.6), colour)
        return
    blade = m.part(name + "3", p2, shaft.name)
    a0 = at(p2, along, -1.0)
    limb(blade, a0, p3, aw, a_t, "indigo")
    a_frame = frame(a0, p3)
    b0 = at(p3, a_frame[0], -0.8)
    limb(blade, b0, p4, bw, bt, "indigo")
    b_frame = frame(b0, p4)
    # the ivory edge: a thin plate under each blade box, on the hook's inner side, its top inside the box
    for start, end, fr, w, depth, thick, lead in ((a0, p3, a_frame, aw, spec["edge"][0], 0.8, 1.3), (b0, p4, b_frame, bw, spec["edge"][1], 0.3, 0.9)):
        run = dist(start, end) - lead - 0.3
        centre = at(at(start, fr[0], lead + run / 2), fr[1], -(w / 2 + (depth - 0.3) / 2))
        blade._oriented(centre, fr[0], fr[1], fr[2], (run, depth + 0.3, thick), "ivory", False)
    c = at(p4, b_frame[0], -0.3)  # the point: the hook's last turn
    base = [at(at(c, b_frame[1], a * (bw / 2 - 0.15)), b_frame[2], b * (bt / 2 - 0.15)) for a, b in ((-1, -1), (1, -1), (1, 1), (-1, 1))]
    blade.spike(base, at(at(p4, b_frame[0], spec["tip"] * 0.8), b_frame[1], -spec["tip"] * 0.6), "indigo")


def pose(parts, phase):
    """a lobster's swim: the abdomen waves up and down, a little more at each joint, and the tail fan follows; the
    scythes trail with a slow wave that runs out along each one, late, the two pairs out of step; the claw arms lift a
    little and their pincers open and close; the jaw drops a little once a beat. The head and the thorax are still"""
    for k, amp in enumerate((2.0, 3.0, 4.0, 5.0, 6.0)):
        parts[f"A{k + 1}"].rotation_euler.y = math.radians(amp) * math.sin(phase - 0.8 * (k + 1))
    parts["Tail"].rotation_euler.y = math.radians(10) * math.sin(phase - 4.8)
    parts["Jaw"].rotation_euler.y = -math.radians(3) * (0.5 + 0.5 * math.sin(phase))
    for (name, _, side, snapped), lag in zip(SCYTHES, (0.0, 0.5, 1.9, 2.4)):
        for j, (amp, late) in enumerate(((1.0, 0.0), (5.0, 0.9), (8.0, 1.8))):
            ob = parts.get(f"{name}{j + 1}")
            if ob is not None:
                ob.rotation_euler.y = math.radians(amp) * math.sin(phase - lag - late)
                ob.rotation_euler.z = side * math.radians(amp * 0.4) * math.sin(phase - lag - late - 0.6)
    for side, lag in (("R", 0.0), ("L", 2.0)):
        parts[f"Arm{side}"].rotation_euler.y = math.radians(3) * math.sin(phase + lag)
        parts[f"Pincer{side}"].rotation_euler.y = -math.radians(9) * (0.5 + 0.5 * math.sin(phase + lag + 1.0))


def build(m):
    # the thorax: the biggest mass. A bare crimson neck, then a crimson body 22 deep whose lime belly hangs below the
    # chin and steps up at the rear to meet the abdomen, and the shoulder plate over it: a hump three cubes higher than
    # the helmet, a plateau 19 wide (the seat), one broad step, a lip that overhangs the body two cubes a side, and a
    # rear lip a cube out over the first shingle
    thorax = m.part("Thorax", (0, 0, 0))
    thorax.hull(NECK[0], NECK[1], THORAX_N - 1, -9, 6, "crimson", [(2, 2)], [(2, 2)])
    thorax.hull(NECK[1], BELLY_STEP, THORAX_N, THORAX_Z[0], 5, "crimson", [], [(3, 2)])
    thorax.hull(BELLY_STEP, THORAX[1], THORAX_N, -8, 5, "crimson", [], [(3, 2)])
    thorax.paint_sym(NECK[0], NECK[1], THORAX_N, -9, -7, "lime")
    thorax.paint_sym(NECK[1], BELLY_STEP, THORAX_N, THORAX_Z[0], THORAX_Z[0] + 2, "lime")
    thorax.paint_sym(BELLY_STEP, THORAX[1], THORAX_N, -8, -6, "lime")
    thorax.hull(NECK[1], THORAX[1], SHOULDER_N, 5, THORAX_Z[1], "slate", [(2, 2)], [])
    thorax.sym(THORAX[1], THORAX[1] + 1, SHOULDER_N - 2, SLICES[0][4], THORAX_Z[1], "slate")
    edge_line(thorax, NECK[1], THORAX[1], SHOULDER_N, 5)

    # the abdomen: five slices, each on its own joint at the middle of its front face, each with a sleeve into the piece
    # in front (sized from the smaller of the two, clear of the belly's step and the plate's)
    before, parent = (THORAX[0], THORAX[1], THORAX_N, -8, 9, 3), "Thorax"
    for i, s in enumerate(SLICES):
        x0, x1, n, bot, top, rows = s
        seg = m.part(f"A{i + 1}", (x0, 0, (bot + top) // 2), parent)
        segment(seg, *s, last=i == len(SLICES) - 1)
        seg.sym(x0 - 1, x0, min(n, before[2]) - 3, max(bot, before[3]) + 2, min(top, before[4]) - 3, "crimson-")
        before, parent = s, seg.name

    # the tail fan, on its own joint: three flat blades, one in the middle and two angled out, each starting inside the
    # last slice
    tail = m.part("Tail", (FAN[0], 0, -3), parent)
    tail.beam((39.2, 0, -2.8), (FAN[1], 0, -3.2), 5.0, 2.0, "slate", flat="z")
    for side in (1, -1):
        tail.beam((39.0, 1.8 * side, -2.79), (46.6, 5.6 * side, -3.14), 3.6, 1.3, "slate", flat="z")

    # the head's masses: the jowls behind the mouth's corner, the head above the mouth, and the helmet: over the top of
    # the head, down over the back of it as a neck guard, and down in front of the eye as a cheek guard
    head = m.part("Head", (HEAD[1], 0, 1), "Thorax")
    head.hull(-18, HEAD[1], HEAD_N, HEAD_Z[0], 7, "crimson", [], [(2, 2)])
    head.hull(-28, -18, HEAD_N, 0, 7, "crimson")
    head.hull(-28, HEAD[1], HELMET_N, 5, HEAD_Z[1], "slate", [(2, 1)], [])
    head.pair(-28, -26, HEAD_N, HELMET_N + 1, 2, 5, "slate")
    head.pair(-15, HEAD[1], HEAD_N, HELMET_N + 1, -1, 5, "slate")
    head.sym(-15, HEAD[1], HELMET_N - 2, HEAD_Z[1], HEAD_Z[1] + 2, "slate")  # its rear lip, two cubes up, over the neck
    edge_line(head, -26, -15, HELMET_N, 5)
    edge_line(head, -15, HEAD[1], HELMET_N, -1)

    # the snout: two whole blocks turned nose-down, the second smaller, starting inside the first and a clear step
    # lower: from the horn's base to the tip the top is one block, a step and one block
    s1 = Plate(-25.5, 4.648, -35.0, 2.748, 15.6, 5.2)
    s2 = Plate(-33.3, 3.256, -39.0, 1.261, 11.2, 3.0)
    s1.add(head, "crimson")
    s2.add(head, "crimson")

    # the grin: its upper line runs nearly level from the mouth's corner behind the eye (x -18) to the snout's tip; the
    # jaw's top line falls away from it, 2 cubes under it at the corner and more than 5 at the tip
    def grin(x):
        return 0.3 + 0.05 * (x + 18)

    def bite(x):
        return -1.7 + 0.19 * (x + 17)

    # the upper lip: a darker ridge under the snout along the grin's line, and a shorter one under the tip
    lip_a = along_line(grin, -17.6, -35.4, 1.1, 16.4, 2.2)
    lip_b = along_line(grin, -34.6, -39.4, 1.1, 12.0, 1.6)
    lip_a.add(head, "crimson-")
    lip_b.add(head, "crimson-")
    gum_a = strip(lip_a, -19.5, -35.0, -1, lip_a.wide - 0.8)
    gum_b = strip(lip_b, -34.8, -39.0, -1, lip_b.wide - 1.2)
    gum_a.add(head, "indigo")
    gum_b.add(head, "indigo")
    # the grin's corner, turned up: a short ridge on the cheek behind the eye, carried up under the neck guard
    head.beam((-18.4, 9.3, 0.75), (-14.4, 9.3, 3.6), 1.1, 1.1, "crimson-", flat="z", mirror=True)

    # the lower jaw, on its own joint at the corner, hanging open: one heavy straight block 4 deep and a narrower one
    # for the chin, which juts a cube past the upper teeth
    jaw = m.part("Jaw", (-17, 0, -1.5), "Head")
    j1 = along_line(bite, -15.5, -33.5, -2.04, 14.4, 4.0)
    j0 = along_line(bite, -32.5, -40.4, -2.03, 10.6, 3.4)
    j1.add(jaw, "crimson")
    j0.add(jaw, "crimson")
    gum_1 = strip(j1, -20.0, -33.2, 1, j1.wide - 0.8)
    gum_0 = strip(j0, -32.9, -40.1, 1, j0.wide - 0.8)
    gum_1.add(jaw, "indigo")
    gum_0.add(jaw, "indigo")

    # the inside of the mouth, lit: two blocks that stay inside the teeth and end inside the lips and the jaw
    head.block(-36.6, (-1.8, 1.8, bite(-36.6) - 1.0, grin(-36.6) + 0.8), -28.2, (-3.8, 3.8, bite(-28.2) - 1.0, grin(-28.2) + 0.8), "lime")
    head.block(-28.6, (-4.3, 4.3, bite(-28.6) - 1.2, grin(-28.6) + 1.0), -17.6, (-4.3, 4.3, bite(-17.6) - 1.2, grin(-17.6) + 1.0), "lime")

    # the teeth: few and big, ivory, 3 tall at the front down to 1.5 at the corner, bases sunk in the gum. The lower
    # ones stand between the upper ones and a little inside them, so the grin zigzags
    for x, size, length in ((-31.6, 3.0, 3.2), (-26.6, 2.6, 2.6), (-21.8, 2.0, 1.8)):
        head.tooth(x, gum_a.wide / 2 - 0.2 - size / 2, gum_a.bottom(x) + 0.25, size, length, "ivory", long=size)
    head.tooth(-36.4, gum_b.wide / 2 - 0.2 - 1.4, gum_b.bottom(-36.4) + 0.25, 2.8, 3.3, "ivory", long=2.8)
    head.tooth(-37.9, 1.3, gum_b.bottom(-37.9) + 0.25, 2.0, 3.2, "ivory", long=1.6)
    for x, size, length in ((-29.1, 2.8, 2.8), (-24.2, 2.2, 2.0)):
        jaw.tooth(x, gum_1.wide / 2 - 0.2 - size / 2, gum_1.top(x) - 0.4, size, -length, "ivory", long=size)
    jaw.tooth(-34.4, gum_0.wide / 2 - 0.2 - 1.4, gum_0.top(-34.4) - 0.4, 2.8, -3.0, "ivory", long=2.8)
    jaw.tooth(-39.2, 1.3, gum_0.top(-39.2) - 0.35, 2.0, -3.0, "ivory", long=1.6)

    # the horn: one hot pink spike on the top of the snout, a third of the way back from its tip, leaning forward
    base = s1.top(-30.5) - 0.5
    head.spike([(-32.6, -2.1, base), (-32.6, 2.1, base), (-28.4, 2.1, base), (-28.4, -2.1, base)], (-33.9, 0.0, base + 9.5), "pink")

    # the eye: a gold halo (a lit ring four cubes square) round a dark pupil, under the helmet's edge, which overhangs
    # it by a cube as the brow and comes down in front of it as the cheek guard
    head.paint_pair(-25, -21, HEAD_N, HEAD_N + 1, 1, 5, "lamp")
    pupil = (HEAD_N + 0.3, HEAD_N + 0.85, 1.55, 4.45)
    head.block(-24.45, pupil, -21.55, pupil, "black", mirror=True)

    # the crest: two blades at the helmet's rear corners, swept back at 45 degrees and leaning out a little, two boxes
    # each: 5 wide and 3 thick at the root, 8 tall. They stand either side of the rider's view forward
    for side in (1, -1):
        root0, root1 = (-17.0, 6.9 * side, 5.2), (-11.0, 7.7 * side, 11.2)
        head.beam(root0, root1, 5.0, 3.0, "slate")
        sweep = unit(sub(root1, root0))
        head.beam(at(root1, sweep, -1.6), (-6.2, 8.7 * side, 15.8), 3.6, 2.0, "slate-")

    # the claw arms, one each side on a shoulder joint low on the front of the thorax: an upper arm down, out and a
    # little forward, a forearm forward, a palm, and a pincer of two fingers with dark talons, the lower finger on its
    # own joint. Folded, so the claws hang under the jaw and outside it, clear of the teeth
    for side, tag in ((1, "R"), (-1, "L")):
        arm = m.part("Arm" + tag, (-4.5, 8.5 * side, -6.0), "Thorax")
        shoulder, elbow = (-3.0, 5.5 * side, -4.0), (-9.0, 12.5 * side, -14.5)
        limb(arm, shoulder, elbow, 5.4, 5.4, "crimson")
        f0 = at(elbow, unit(sub(elbow, shoulder)), -2.4)
        wrist = (-20.5, 11.6 * side, -14.0)
        limb(arm, f0, wrist, 4.6, 4.6, "crimson")
        fr = frame(f0, wrist)
        up = fr[1] if fr[1][2] > 0 else tuple(-v for v in fr[1])
        palm = at(wrist, fr[0], 5.0)
        limb(arm, at(wrist, fr[0], -1.0), palm, 5.4, 5.4, "crimson-")
        knuckle = at(at(palm, fr[0], -2.4), up, 1.05)
        tip = at(knuckle, unit(at(fr[0], up, 0.22)), 10.4)
        limb(arm, knuckle, tip, 3.0, 3.0, "crimson-")
        talon(arm, tip, frame(knuckle, tip), 1.2, 3.6, -1.6 if fr[1] is up else 1.6, "indigo")
        knuckle = at(at(palm, fr[0], -2.4), up, -1.05)
        pincer = m.part("Pincer" + tag, at(knuckle, fr[0], 0.9), arm.name)
        tip = at(knuckle, unit(at(fr[0], up, -0.36)), 10.2)
        limb(pincer, knuckle, tip, 3.0, 2.6, "crimson-")
        talon(pincer, tip, frame(knuckle, tip), 1.1, 3.6, 1.4 if fr[1] is up else -1.4, "indigo")

    # the legs: two pairs of short thick legs tucked under the thorax, two boxes each, leaving the body outside the
    # belly plate
    for x in (0.0, 4.5):
        for side in (1, -1):
            knee = (x + 0.8, 10.8 * side, -13.2)
            limb(thorax, (x, 7.0 * side, -6.6), knee, 2.7, 2.5, "crimson-")
            limb(thorax, (x + 0.55, 10.2 * side, -12.3), (x + 3.2, 9.6 * side, -16.0), 1.9, 1.7, "crimson-")

    # the scythes
    for name, spec, side, snapped in SCYTHES:
        scythe(m, name, spec, side, snapped)
