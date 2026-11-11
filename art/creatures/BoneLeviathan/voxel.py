"""The Bone Leviathan (zone 9's Mythic: a whole sea-serpent skeleton, swimming) for tools/blender/voxel_kit.py
(docs/style/04-voxel-style.md).
Its idea: nothing but bone and a cold light. A big horned skull, a backbone of chunky vertebrae, a rib cage, a tail blade,
and a blue-green glow where the life used to be: in the sockets, the nostrils and the mouth, and down the inside of the ribs.
- The backbone is thirteen vertebrae, each its own part on its own joint. A vertebra is a block of ivory with stepped
  corners and, in front of it, a narrower, darker joint that runs one cube into the piece before (its sleeve). One number
  changes from one vertebra to the next: width, back or belly. The back rises to the rider and falls again.
- The side outline is made by what hangs off the backbone: the ribs grow and shrink again (the belly's curve), short
  spines hang under the tail after them, and tall spines stand along the back, highest behind the rider. No spine on the
  seat's vertebra.
- A rib is three broad blocks in a chain, each smaller and starting inside the last: out and down, down, and in again.
  Every rib starts inside its vertebra's side. The cage is widest and deepest under the rider, in plan view too.
- The skull: a wide back of the head (the horns start in it), a narrower front with the sockets, a snout of three blocks
  in a chain, each tilted nose-down, a lower jaw on its own joint. Fangs at the front, a row of teeth behind, a thin
  darker line set inside the jaw's edge where gums would be. The brow sits on the socket and comes past it.
- The tail blade: a stock and two bony lobes, the upper one long.
It swims like a snake, side to side; the jaw works slowly. The rider sits on the fifth vertebra, legs between two ribs."""
import math

NAME, ZONE, RARITY = "Bone Leviathan", "ZONE 9 / BONE GRAVEYARD", "MYTHIC"
U = 0.45
PALETTE = {"bone": "#E4D9BC", "joint": "#8B7A63", "deep": "#26343C", "glow": "#5FE9D2", "tooth": "#FBF7EA"}
GLOW = {"glow": 0.9}  # the cold light inside: sockets, nostrils, mouth, and the core between the ribs
SEAT = (26.5, 5, 3.5)
FRAME, ORTHO, ORTHO_SWIM = 3.7, 55.0, 60.0
TEXTURES = [{"tile": "stud", "on": "top", "colours": ["bone"], "parts": ["Head"]}]  # studs on the skull's crown only
K = 1.25  # the skull's free pieces are drawn on a coarser grid: a big head on a slim backbone

# the backbone: each vertebra is (length with its joint, cubes out, bottom, top). One number changes at a time; the back
# rises to the rider and falls again to the tail
VERTS = ((5, 2, -2, 3), (5, 2, -2, 4), (6, 3, -2, 4), (6, 3, -2, 5), (7, 3, -2, 5), (7, 3, -2, 5), (6, 3, -2, 5), (6, 3, -2, 4),
         (5, 2, -2, 4), (5, 2, -2, 3), (5, 2, -1, 3), (5, 1, -1, 3), (4, 1, -1, 2))
SKULL = (6, -5, 7)
SPINES = (0, 2.5, 3.5, 4.5, 0, 6.0, 6.0, 5.5, 4.5, 4.0, 3.0, 2.5, 2.0)  # how tall each back spine stands (0: none)
# the vertebrae with ribs: how far down each rib's tip hangs, and how far out the rib stands. The cage swells and shrinks
RIBS = {1: (4.5, 1.8), 2: (7.0, 2.4), 3: (10.0, 3.2), 4: (12.0, 3.8), 5: (12.0, 3.8), 6: (10.0, 3.2), 7: (7.5, 2.4), 8: (5.0, 1.8)}
CORE = {2: (1.0, 1.6), 3: (1.4, 2.4), 4: (1.8, 3.2), 5: (1.8, 3.2), 6: (1.4, 2.4), 7: (1.0, 1.6)}  # half width, depth
UNDER = {9: 3.0, 10: 2.5, 11: 2.0, 12: 1.5}  # the short spines under the tail
CHAIN = [f"V{i + 1}" for i in range(len(VERTS))] + ["Blade"]
AMPLITUDES = [2, 2, 3, 3, 3, 3, 4, 4, 5, 5, 6, 7, 8, 11]


def pose(parts, phase):
    """a snake's swim: the wave runs down the backbone side to side, growing toward the tail. The skull turns a little
    against it; the jaw opens and shuts slowly, once a beat"""
    parts["Head"].rotation_euler.z = math.radians(2.0) * math.sin(phase + math.pi)
    for k, name in enumerate(CHAIN):
        parts[name].rotation_euler.z = math.radians(AMPLITUDES[k]) * math.sin(phase - 0.45 * (k + 1))
    parts["Jaw"].rotation_euler.y = -math.radians(9) * (0.5 + 0.5 * math.sin(phase))


def steps(n, top=False):
    """a vertebra's corners: two steps on the back of the thick ones, one elsewhere, none on the thin tail"""
    return [(2, 1), (1, 1)] if n >= 3 and top else ([(1, 1)] if n >= 2 else [])


class Big:
    """free pieces drawn at the size of a smaller skull and built K times bigger"""

    def __init__(self, part):
        self.p = part

    def beam(self, p0, p1, wide, thick, colour, **kw):
        self.p.beam(tuple(v * K for v in p0), tuple(v * K for v in p1), wide * K, thick * K, colour, **kw)

    def block(self, x0, s0, x1, s1, colour, **kw):
        self.p.block(x0 * K, tuple(v * K for v in s0), x1 * K, tuple(v * K for v in s1), colour, **kw)

    def tooth(self, x, y, z, size, length, colour, lean=(0.0, 0.0)):
        self.p.tooth(x * K, y * K, z * K, size * K, length * K, colour, lean=(lean[0] * K, lean[1] * K))


def build(m):
    head = m.part("Head", (0, 0, 0))
    h = Big(head)
    # the skull: a wide back of the head, then a narrower, lower front where the sockets sit
    head.hull(-6, 0, 6, -5, 7, "bone", [(2, 1), (1, 1)], [(1, 1)])
    head.hull(-12, -6, 5, -5, 6, "bone", [(1, 1)], [(1, 1)])
    head.paint_sym(-6, 0, 6, 6, 7, "bone+")
    head.paint_sym(-12, -6, 5, 5, 6, "bone+")
    head.paint_sym(-12, 0, 6, -5, -4, "bone-")
    # the snout: three blocks in a chain, each tilted nose-down, lower and narrower than the last. Under each a thin
    # darker plate set inside its edge (the gum line of a thing with no gums), which the teeth hang from
    blocks = ((-8.5, -13.5, 1.5, 0.8, 8.2, 5.2), (-12.7, -17.6, 0.6, -0.1, 6.4, 4.0), (-16.8, -21.5, -0.2, -0.8, 4.8, 3.0))

    def middle(k, x):
        x0, x1, z0, z1 = blocks[k][:4]
        return z0 + (z1 - z0) * (x - x0) / (x1 - x0)

    def gum_bottom(k, x):
        return middle(k, x) - blocks[k][5] / 2 - 0.3

    for k, (x0, x1, z0, z1, wide, thick) in enumerate(blocks):
        h.beam((x0, 0, z0), (x1, 0, z1), wide, thick, "bone", flat="z")
        drop = thick / 2 + 0.125
        start, stop = (-10.3, -13.7, -17.8)[k], x1 + (0.65, 0.55, 0.45)[k]  # from past the block before to short of its own end
        h.beam((start, 0, middle(k, start) - drop), (stop, 0, middle(k, stop) - drop), wide - 1.0, 0.35, "joint", flat="z")
    # the cold light inside the skull, seen through its holes: the nostrils, the sockets, and the mouth behind the teeth
    nostril = (0.45, 1.35, 0.25, 0.95)
    h.block(-20.4, nostril, -18.9, nostril, "glow", mirror=True)
    h.block(-18.6, (-0.9, 0.9, -3.3, -1.75), -9.5, (-2.3, 2.3, -3.5, -1.0), "glow")
    head.dent(-11, -7, 5, 0, 4, "deep", depth=0.8)
    light = (4.6, 5.0, 1.0, 2.6)  # a small light deep in a dark socket, not a lit window
    head.block(-9.9, light, -8.2, light, "glow", mirror=True)
    # the brow: a box that sits on the socket, cuts its top, slants down to the front and comes past it
    head.beam((-13.6, 5.0, 2.7), (-5.4, 5.0, 4.4), 1.6, 2.5, "bone", mirror=True)
    cheek = (5.3, 6.0, -1.6, -0.4)  # the cheekbone: a bar under the socket, running back into the wide back of the skull
    head.block(-11.7, cheek, -5.5, cheek, "bone", mirror=True)
    # the horns: three boxes each, sweeping back, out and up from inside the back of the skull, darker to the tip
    h.beam((-3.5, 3.0, 3.2), (2.0, 6.0, 8.0), 2.6, 2.2, "bone", mirror=True)
    h.beam((1.3, 5.6, 7.4), (6.0, 7.3, 11.6), 1.9, 1.6, "bone-", mirror=True)
    h.beam((5.4, 7.1, 11.0), (8.6, 7.8, 15.2), 1.3, 1.0, "joint", mirror=True)
    # a short cheek spike each side, low on the back of the skull: the horns' echo
    h.beam((-2.6, 3.9, -1.4), (1.6, 6.3, -1.0), 1.8, 1.4, "bone-", flat="z", mirror=True)
    h.beam((0.9, 5.9, -1.05), (3.6, 7.4, -0.7), 1.2, 0.9, "joint", flat="z", mirror=True)
    # the upper teeth, bases sunk in the dark plate: a row down each side, and two long fangs at the front
    for k, x, long in ((0, -10.9, 1.1), (0, -12.3, 1.2), (1, -14.3, 1.3), (1, -15.4, 1.2), (1, -16.5, 1.3), (2, -18.4, 1.3)):
        h.tooth(x, blocks[k][4] / 2 - 1.0, gum_bottom(k, x) + 0.1, 0.9, long, "tooth")
    h.tooth(-20.2, 1.35, gum_bottom(2, -20.2) + 0.1, 1.1, 2.6, "tooth", lean=(-0.3, 0.0))

    # the lower jaw, on its own joint: three slim boxes in a chain, sloping down from the hinge and up again to the chin.
    # It stops short of the snout's tip, so the fangs hang in front of it
    jaw = m.part("Jaw", (-3 * K, 0, -3 * K), "Head")
    j = Big(jaw)
    jaws = ((-3.0, -11.5, -3.0, -4.7, 8.0, 1.6), (-10.8, -16.6, -4.65, -4.35, 6.0, 1.3), (-16.0, -19.4, -4.4, -4.1, 4.2, 1.0))

    def jaw_top(k, x):
        x0, x1, z0, z1, _, thick = jaws[k]
        return z0 + (z1 - z0) * (x - x0) / (x1 - x0) + thick / 2

    for k, (x0, x1, z0, z1, wide, thick) in enumerate(jaws):
        j.beam((x0, 0, z0), (x1, 0, z1), wide, thick, "bone", flat="z")
        start = -10.4 if k == 0 else x0 - 0.9
        j.beam((start, 0, jaw_top(k, start) + 0.05), (x1 + 0.3, 0, jaw_top(k, x1 + 0.3) + 0.05), wide - 1.0, 0.3, "joint", flat="z")
    for k, x, long in ((1, -13.3, 0.9), (1, -14.85, 1.0), (1, -15.9, 1.0), (2, -17.45, 1.0), (2, -18.65, 1.5)):
        j.tooth(x, jaws[k][4] / 2 - 1.05, jaw_top(k, x) + 0.1, 0.8, -long, "tooth")

    # the backbone
    segs, spans, x = [], [], 0
    for i, (length, n, bot, top) in enumerate(VERTS):
        segs.append(m.part(f"V{i + 1}", (x, 0, 0), "Head" if i == 0 else f"V{i}"))
        spans.append((x, x + length, n, bot, top))
        x += length
    end = x
    for i, (seg, (x0, x1, n, bot, top)) in enumerate(zip(segs, spans)):
        fn, fbot, ftop = spans[i - 1][2:5] if i else SKULL
        gap = 2 if x1 - x0 >= 6 else 1
        # the joint: narrower and darker, in front of the vertebra and one cube into the piece before
        clear = 2 if min(n, fn) >= 3 else 1  # it stays under the lowest corner step of both pieces
        seg.sym(x0 - 1, x0 + gap, min(n, fn) - 1, max(bot, fbot) + 1, min(top, ftop) - clear, "joint")
        # the vertebra: an ivory block with stepped corners, lighter on its top row, darker on its lowest
        c0 = x0 + gap
        seg.hull(c0, x1, n, bot, top, "bone", steps(n, True), steps(n))
        seg.paint_sym(c0, x1, n, top - 1, top, "bone+")
        seg.paint_sym(c0, x1, n, bot, bot + 1, "bone-")
        mid = (c0 + x1) / 2
        wide, thick = ((2.6, 1.1) if n == 3 else ((2.1, 0.9) if n == 2 else (1.6, 0.7)))
        tall = SPINES[i]
        if tall:  # a spine on the back, leaning back; the tall ones end in a smaller, darker tip
            lean = 0.3 * tall
            seg.beam((mid - 0.3, 0, top - 1.0), (mid - 0.3 + lean, 0, top + tall), wide, thick, "bone")
            if tall >= 3.5:
                f = (tall + 0.3) / (tall + 1.0)
                seg.beam((mid - 0.3 + lean * f, 0, top + tall - 0.7), (mid + lean + 0.5, 0, top + tall + 1.8), wide - 0.9, thick - 0.4, "joint")
        if i in UNDER:  # a short spine under the tail's vertebrae, where the ribs have ended
            tall = UNDER[i]
            seg.beam((mid - 0.3, 0, bot + 1.0), (mid - 0.3 + 0.35 * tall, 0, bot - tall), wide - 0.4, thick - 0.2, "bone-")
        if i in RIBS:
            down, out = RIBS[i]
            out += n
            s = 1.0 if down > 6 else 0.8
            # a rib: out and down from inside the vertebra's side, then down, then (the long ones) in again at the tip
            seg.beam((mid, n - 1.0, -0.5), (mid + 0.4, out, -3.0), 3.4 * s, 1.3 * s, "bone", mirror=True)
            if down > 6:
                seg.beam((mid + 0.3, out - 0.45, -2.4), (mid + 1.5, out - 0.3, -down + 1.6), 2.8, 1.0, "bone", mirror=True)
                seg.beam((mid + 1.35, out - 0.25, -down + 2.3), (mid + 2.5, out - 2.4, -down - 0.6), 2.0, 0.7, "bone-", mirror=True)
            else:
                seg.beam((mid + 0.3, out - 0.4, -2.4), (mid + 0.9, out - 0.9, -down), 2.0, 0.7, "bone-", mirror=True)
        if i in CORE:
            # the cold core hanging under the backbone, seen between the ribs: thickest under the rider, and thinner
            # under each joint, like the backbone above it
            half, deep = CORE[i]
            core = (-half, half, bot - deep, bot + 0.3)
            seg.block(c0 + 0.2, core, x1 - 0.3, core, "glow")
            link = (-half + 0.4, half - 0.4, bot - deep + 0.4, bot - 0.4)
            seg.block(x0 + 0.2, link, c0 + 0.6, link, "glow")

    # the tail blade, on its own joint: a dark stock, a long upper lobe in three boxes and a short lower one in two
    blade = m.part("Blade", (end, 0, 0.5), f"V{len(VERTS)}")
    blade.beam((end - 0.8, 0, 0.5), (end + 2.4, 0, 0.5), 2.0, 1.3, "joint")
    blade.beam((end + 0.8, 0, 0.9), (end + 5.2, 0, 6.2), 3.8, 1.0, "bone")
    blade.beam((end + 4.4, 0, 5.3), (end + 8.6, 0, 10.6), 2.9, 0.7, "bone")
    blade.beam((end + 7.8, 0, 9.7), (end + 10.6, 0, 13.6), 1.9, 0.4, "bone-")
    blade.beam((end + 0.8, 0, 0.1), (end + 4.4, 0, -3.9), 3.3, 0.7, "bone")
    blade.beam((end + 3.7, 0, -3.1), (end + 6.4, 0, -6.4), 2.2, 0.4, "bone-")
