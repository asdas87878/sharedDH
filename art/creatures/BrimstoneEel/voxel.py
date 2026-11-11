"""The Brimstone Eel (zone 10's Legendary: a burnt eel of the underworld) for tools/blender/voxel_kit.py
(docs/style/04-voxel-style.md), dressed as a Legendary by docs/style/05-rarity-look.md.
Its idea: an eel that has burnt through. The skin is charred and the fire shows wherever the body bends: in every joint,
and in one line down each flank.
- The body is seventeen slices on joints, each one step different from the last (width, or back, or belly), deepest under
  the rider and thinning to a ribbon of a tail. It swims as an eel does, a wave running side to side down the chain.
- The lava: one row along each flank from the cheek to the tail (orange, cooling to red), a crack climbing from it at
  every joint to its own height, and glowing sleeves inside the joints, which show when the body bends.
- The head is the focal point: a sloping snout of three blocks, a heavy lower jaw (its own part) that juts past the
  snout, ember teeth standing in a thin dark gum line, and a dark pupil in a thin ember halo under a brow that comes past it.
- A low ragged crest, burnt to tatters: on the nape and from behind the rider to the tail, where it wraps the tip.
The rider sits where the body is biggest, legs in a shallow slot either side; nothing stands on the back there."""
import math

NAME, ZONE, RARITY = "Brimstone Eel", "ZONE 10 / THE UNDERWORLD", "LEGENDARY"
U = 0.45
PALETTE = {"char": "#44333F", "belly": "#8C727A", "cinder": "#7C2A36", "lava": "#FF8A1E", "blaze": "#F05E1A", "red": "#CC3418",
           "tooth": "#FFC44A", "halo": "#FFB43A", "gum": "#3C1218", "mouth": "#5E161C", "black": "#1C161A"}
SEAT = (5.5, 7, 5.5)
GLOW = {"lava": 0.85, "blaze": 0.75, "red": 0.6, "tooth": 0.6, "halo": 0.5}
TEXTURES = [{"tile": "stud", "on": "top", "colours": ["char"]}]
FRAME, ORTHO, ORTHO_SWIM = 2.5, 38.0, 44.0
RIDE_FOG = "#3A1420"

# the body: each slice is (length, cubes out, bottom, top). One number changes from slice to slice, never two
SLICES = ((4, 4, -5, 6), (4, 5, -5, 6), (4, 5, -5, 7), (5, 5, -6, 7), (4, 5, -6, 6), (4, 5, -5, 6), (4, 4, -5, 6), (3, 4, -5, 5),
          (3, 4, -4, 5), (3, 3, -4, 5), (3, 3, -4, 4), (3, 3, -3, 4), (3, 2, -3, 4), (3, 2, -3, 3), (2, 2, -2, 3), (2, 1, -2, 3),
          (2, 1, -2, 2))
BODY_FROM = -9
SKULL = (4, -5, 5)
LINE = -1  # the row of the flank line
CRACK_UP = (3, 1, 2, 1, 1, 3, 1, 2, 1, 3, 1, 2, 1, 2, 1, 1, 1)  # how many rows each joint's crack climbs above the flank line
CRACK_DOWN = (0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0)  # and how far below the line it runs
CHAIN = ["Head"] + [f"S{i + 1}" for i in range(len(SLICES))] + ["Tail"]
AMPLITUDES = [2, 2.5, 3, 3, 3.5, 4, 4, 4.5, 5, 5, 5.5, 6, 6.5, 7, 7.5, 8, 8.5, 9]
STEP = 0.5


def pose(parts, phase):
    """an eel's swim: a wave runs down the long chain side to side, growing toward the tail. The head turns against the
    body's mean heading, so the animal stays on its line instead of swinging as a whole. The jaw opens and shuts once a beat"""
    turns = [math.radians(a) * math.sin(phase - STEP * (k + 1)) for k, a in enumerate(AMPLITUDES)]
    heading, total = 0.0, 0.0
    for t in turns:
        heading += t
        total += heading
    parts["Head"].rotation_euler.z = -total / len(turns)
    for name, t in zip(CHAIN[1:], turns):
        parts[name].rotation_euler.z = t
    parts["Jaw"].rotation_euler.y = -math.radians(9) * (0.5 + 0.5 * math.sin(phase))


def top_steps(n):
    """the corners of the back: three steps where the body is thick, fewer as it thins"""
    return [(3, 1), (2, 1), (1, 1)] if n >= 5 else ([(2, 1), (1, 1)] if n == 4 else [(1, 1)])


def bottom_steps(n):
    return [(2, 1), (1, 1)] if n >= 4 else [(1, 1)]


def belly_edge(bot):
    """how high the ashen belly comes: it dips under the deep middle and rises to the tail"""
    return bot + (3 if bot <= -5 else (2 if bot <= -3 else 1))


def fire(i):
    """the lava cools along the body: orange, then a deeper orange, then red at the tail"""
    return "lava" if i < 6 else ("blaze" if i < 12 else "red")


def slab(p, x0, x1, n, bot, top, glow, bottom=None):
    """a slice of body: stepped corners, charred skin (lighter on the top row), an ashen belly, and the flank line"""
    p.hull(x0, x1, n, bot, top, "char", top_steps(n), bottom or bottom_steps(n))
    p.paint_sym(x0, x1, n, top - 1, top, "char+")
    p.paint_sym(x0, x1, n, bot, belly_edge(bot), "belly")
    p.paint_sym(x0, x1, n, LINE, LINE + 1, glow)


def tatter(p, x, top, tall, wide, thick, lean):
    """one rag of the burnt crest: a box standing on the back, leaning tailward, its root a cube deep in the body"""
    p.beam((x, 0, top - 1.1), (x + lean * (tall + 1.1), 0, top + tall), wide, thick, "cinder")


def build(m):
    head = m.part("Head", (BODY_FROM, 0, 0))
    # the skull: a short box. Its bottom row is wider than the body's behind it: the hinge of the heavy jaw
    slab(head, -15, BODY_FROM, *SKULL, "lava", [(1, 1)])
    head.sym(-15, -10, 3, -6, -5, "belly")  # the jowl: the jaw's root is buried in it
    head.paint_sym(-15, -14, 4, LINE, LINE + 1, "char")  # the flank line starts a cube back, so the face's front stays dark
    head.paint(-15, -14, -3, 4, -3, -1, "mouth")  # the back of the mouth, seen between the lips
    # the snout: three blocks in a chain, each tilted nose-down, lower and narrower than the last. Each has an ashen lip
    # plate underneath with a thin dark gum line set inside its edge; the first two have a lighter plate on top
    blocks = ((-13.5, -18.0, 1.5, 0.9, 6.6, 4.4, 4.6, -13.5, -14.6), (-17.2, -20.8, 0.85, 0.35, 5.0, 3.3, 3.2, -18.2, -18.3),
              (-20.2, -22.8, 0.3, 0.0, 3.6, 2.3, 0.0, 0.0, -21.1))

    def middle(k, x):
        x0, x1, z0, z1 = blocks[k][:4]
        return z0 + (z1 - z0) * (x - x0) / (x1 - x0)

    def lip_bottom(k, x):
        return middle(k, x) - blocks[k][5] / 2 - 0.6

    for k, (x0, x1, z0, z1, wide, thick, plate, plate_from, gum_from) in enumerate(blocks):
        head.beam((x0, 0, z0), (x1, 0, z1), wide, thick, "char", flat="z")
        lip = thick / 2 + 0.3
        head.beam((x0, 0, z0 - lip), (x1, 0, z1 - lip), wide - 0.4, 0.6, "belly", flat="z")
        if plate:
            rise = thick / 2 + 0.2
            head.beam((plate_from, 0, middle(k, plate_from) + rise), (x1 + 0.7, 0, middle(k, x1 + 0.7) + rise), plate, 0.5, "char+", flat="z")
        head.beam((gum_from, 0, lip_bottom(k, gum_from) - 0.05), (x1 + 0.3, 0, lip_bottom(k, x1 + 0.3) - 0.05), wide - 1.0, 0.2, "gum",
                  flat="z")
    # the dark inside of the mouth: two blocks that stay behind the teeth and end inside the lips and the jaw
    head.block(-17.5, (-2.0, 2.0, -3.0, -1.4), -14.9, (-2.0, 2.0, -3.0, -1.4), "mouth")
    head.block(-20.3, (-1.2, 1.2, -2.9, -1.45), -17.5, (-1.2, 1.2, -2.9, -1.45), "mouth")
    # the upper teeth: embers, each with its base sunk into the gum. Two long fangs at the tip of the snout
    for k, x, length in ((0, -15.5, 0.9), (0, -16.5, 1.0), (0, -17.45, 0.9), (1, -18.75, 1.0), (1, -20.1, 0.95), (2, -21.5, 0.85), (2, -22.3, 0.85)):
        head.tooth(x, (2.45, 1.65, 0.95)[k], lip_bottom(k, x) - 0.05, 0.65, length, "tooth")
    # the eye: a dark socket on the skull's side, a thin ember halo, a dark pupil standing out of it. The brow sits on the
    # eye, slanting down to the front, covers the top of its square and comes past it in front
    ring = (4.38, 4.97, 0.4, 2.8)
    head.block(-14.6, ring, -11.8, ring, "char-", mirror=True)
    halo = (4.85, 5.15, 0.7, 2.5)
    head.block(-14.3, halo, -12.1, halo, "halo", mirror=True)
    pupil = (4.97, 5.33, 1.0, 2.15)
    head.block(-13.9, pupil, -12.5, pupil, "black", mirror=True)
    head.beam((-15.6, 4.81, 2.15), (-11.2, 4.81, 2.8), 1.2, 1.35, "char", mirror=True)

    # the lower jaw, on its own joint: heavy, three boxes in a chain rising to the chin, which juts past the snout. Its own
    # gum line and ember teeth; two fangs stand up in front of the snout
    jaw = m.part("Jaw", (-13, 0, -3.2), "Head")
    jaws = ((-12.6, -18.2, -4.1, -3.95, 6.4, 2.6, -14.6), (-17.4, -21.4, -3.9, -3.5, 5.0, 2.0, -18.5), (-20.7, -23.5, -3.5, -3.05, 3.8, 1.4, -21.7))

    def jaw_top(k, x):
        x0, x1, z0, z1, _, thick = jaws[k][:6]
        return z0 + (z1 - z0) * (x - x0) / (x1 - x0) + thick / 2

    for k, (x0, x1, z0, z1, wide, thick, gum_from) in enumerate(jaws):
        jaw.beam((x0, 0, z0), (x1, 0, z1), wide, thick, "belly", flat="z")
        jaw.beam((gum_from, 0, jaw_top(k, gum_from) + 0.05), (x1 + 0.3, 0, jaw_top(k, x1 + 0.3) + 0.05), wide - 0.6, 0.2, "gum", flat="z")
    for k, x, length in ((0, -16.0, 0.8), (0, -17.0, 0.8), (1, -19.4, 0.85), (1, -20.7, 0.8), (2, -22.15, 0.8), (2, -23.0, 1.3)):
        jaw.tooth(x, (2.55, 1.85, 1.25)[k], jaw_top(k, x) + 0.05, 0.6, -length, "tooth")

    # the body: seventeen slices, each on its own joint
    segs, spans, x = [], [], BODY_FROM
    for i, (length, n, bot, top) in enumerate(SLICES):
        segs.append(m.part(f"S{i + 1}", (x, 0, 0), "Head" if i == 0 else f"S{i}"))
        spans.append((x, x + length, n, bot, top))
        x += length
    end = x
    for i, (seg, (x0, x1, n, bot, top)) in enumerate(zip(segs, spans)):
        slab(seg, x0, x1, n, bot, top, fire(i))
        # the crack at the joint: the first row of the slice glows from the flank line up to its own height
        seg.paint_sym(x0, x0 + 1, n, max(LINE - CRACK_DOWN[i], bot + 1), min(LINE + 1 + CRACK_UP[i], top - 1), fire(i))
        # a glowing sleeve into the piece in front, so a bending joint shows fire. It is sized from the smaller of the two
        # pieces and stays clear of both pieces' steps
        fn, fbot, ftop = spans[i - 1][2:5] if i else SKULL
        small = min(n, fn)
        up = max(len(top_steps(n)), len(top_steps(fn)))
        down = max(len(bottom_steps(n)), len(bottom_steps(fn)) if i else 1)
        seg.sym(x0 - 1, x0, max(small - 2, 0), max(bot, fbot) + down, min(top, ftop) - up, fire(i))
        # the crest: on the nape, then from behind the rider to the tail. One rag to a slice, a tall one and a short one in
        # turn; smaller as the body thins, the thin ones thinner so no two sides lie in one plane
        if i in (0, 1) or i >= 5:
            s = 1.0 if n >= 4 else (0.85 if n == 3 else (0.72 if n == 2 else 0.55))
            length = x1 - x0
            if i % 2:
                tatter(seg, x0 + length / 2 - 0.3, top, 2.2 * s, 1.7 * s, 0.6 if n == 1 else 0.9, 0.5)
            else:
                tatter(seg, x0 + length / 2 - 0.1, top, 1.4 * s, 1.4 * s, 0.6, 0.3)
    # the seat: where the body is biggest, a shallow slot either side for the rider's legs
    segs[3].dent(4, 7, 5, 1, 4, "char-")

    # the tail, on its own joint: a short stock, then the burnt fin wrapping the tip in two boxes
    tail = m.part("Tail", (end, 0, -0.5), f"S{len(SLICES)}")
    tail.beam((end - 0.8, 0, -0.1), (end + 2.4, 0, -0.3), 1.8, 1.5, "char")
    tail.beam((end + 1.0, 0, -0.2), (end + 4.6, 0, -0.6), 3.0, 0.8, "cinder")
    tail.beam((end + 3.6, 0, -0.5), (end + 5.4, 0, -0.95), 1.6, 0.45, "cinder-")
