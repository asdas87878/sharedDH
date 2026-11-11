"""The Frilled Shark (zone 7's Epic: the eel-like primitive shark of the deep) for tools/blender/voxel_kit.py
(docs/style/04-voxel-style.md). Designed from the real animal.
Its idea: a ruffled collar. Six gill flaps a side stand out behind the head like louvres, each with a dull red frill at
its trailing edge.
- The head is a lizard's, not a shark's: flat on top, wider than the neck, blunt, with the mouth at the very front. The
  snout is two blocks in a chain and the lower jaw is as long as the snout. Needle teeth, a thin dark gum line set
  inside the lips, a big eye under a low lid of a brow.
- The body is a long round eel's, with a deep throat and a tuck behind it: ten slices, each on its own joint, each one step smaller than the last in width or
  back or belly, never two at once. Three-step corners where it is thick.
- One pale line runs the whole animal: the upper lip, under the eye, and down every slice to the tail.
- The fins are small and set far back: low side fins behind the collar, belly fins, one small back fin over a bigger
  anal fin, and a long low tail blade with a lower lobe, on two joints.
The rider sits behind the collar, legs in a slot either side."""
NAME, ZONE, RARITY = "Frilled Shark", "ZONE 7 / MIDNIGHT", "EPIC"
U = 0.4
PALETTE = {"hide": "#5E4A43", "belly": "#917B6E", "line": "#C4AE98", "frill": "#A2423E", "mouth": "#58222A", "gum": "#8A4048",
           "tooth": "#F6F1E6", "black": "#1E2126"}
SEAT = (-7.5, 4, 3.5)
FRAME, ORTHO, ORTHO_SWIM = 2.05, 29.0, 31.0
TEXTURES = [{"tile": "stud", "on": "top", "colours": ["hide"], "parts": ["Head", "Collar"]}]

# the body behind the head: (length, cubes out, bottom, top). The first is the collar. One number changes at a time
# after the collar. The belly makes its own line: a deep throat, a tuck behind it, the belly, then the long rise to the tail
SLICES = ((6, 4, -4, 4), (4, 3, -3, 4), (5, 3, -4, 4), (5, 3, -4, 4), (4, 3, -3, 4), (4, 3, -3, 3), (4, 2, -3, 3), (4, 2, -2, 3),
          (3, 2, -2, 2), (3, 1, -2, 2))
BODY_FROM = -20
NAMES = ["Collar"] + [f"S{i}" for i in range(1, len(SLICES))]
SWIM = {"chain": ["Head"] + NAMES + ["Tail", "TailTip"], "amplitudes": [2, 3, 4, 5, 6, 6, 7, 8, 9, 10, 12, 14], "phaseStep": 0.5,
        "headCounter": 2}
DROP = 0.15  # how far a gum plate shows past its lip


def top_steps(n):
    return [(2, 1), (1, 1)] if n == 3 else ([(2, 1)] if n >= 4 else [(1, 1)])


def bottom_steps(n):
    return [(2, 1), (1, 1)] if n == 3 else [(1, 1)]


def slab(p, x0, x1, n, bot, top):
    """a slice of body: stepped corners, a lighter top row, the pale line, a paler belly under it"""
    p.hull(x0, x1, n, bot, top, "hide", top_steps(n), bottom_steps(n))
    p.paint_sym(x0, x1, n, top - 1, top, "hide+")
    if bot <= -2:
        p.paint_sym(x0, x1, n, bot, -1, "belly")
        if n >= 4:
            p.paint_sym(x0, x1, n, bot, bot + 1, "belly-")
        p.paint_sym(x0, x1, n, -1, 0, "line")


def frill(p, p0, p1, width, flat, mirror):
    """a gill flap: a plate leaning out and back from the body, and a thinner, smaller red plate that starts inside it
    and comes out past its trailing edge"""
    d = [b - a for a, b in zip(p0, p1)]
    length = sum(v * v for v in d) ** 0.5
    p.beam(p0, p1, width, 0.5, "hide", flat=flat, mirror=mirror)
    mid = tuple(a + 0.5 * v for a, v in zip(p0, d))
    end = tuple(b + 0.5 * v / length for b, v in zip(p1, d))
    p.beam(mid, end, width - 0.6, 0.2, "frill", flat=flat, mirror=mirror)


def build(m):
    head = m.part("Head", (BODY_FROM, 0, 0))
    # the skull: wide and flat, one broad step at the top corners, so the eye has a whole wall to sit on
    head.hull(-26, BODY_FROM, 4, -4, 3, "hide", [(2, 1)], [(1, 1)])
    head.paint_sym(-26, BODY_FROM, 4, 2, 3, "hide+")
    head.paint_sym(-26, BODY_FROM, 4, -4, -1, "belly")
    head.paint_sym(-26, BODY_FROM, 4, -4, -3, "belly-")
    head.paint_sym(-26, BODY_FROM, 4, -1, 0, "line")
    # the snout: two blocks in a chain, short and blunt, each a step lower and narrower. Each has a pale lip plate
    # underneath (the line's start) and a thin gum plate set in from the lip's edge
    blocks = ((-25.4, -28.4, 0.6, 0.35, 7.6, 2.4, -25.4), (-27.8, -30.0, 0.28, 0.1, 5.6, 1.8, -28.7))

    def middle(k, x):
        x0, x1, z0, z1 = blocks[k][:4]
        return z0 + (z1 - z0) * (x - x0) / (x1 - x0)

    def lip_bottom(k, x):
        return middle(k, x) - blocks[k][5] / 2 - 0.8

    for k, (x0, x1, z0, z1, wide, thick, gum_from) in enumerate(blocks):
        head.beam((x0, 0, z0), (x1, 0, z1), wide, thick, "hide", flat="z")
        lip = thick / 2 + 0.4
        head.beam((x0, 0, z0 - lip), (x1, 0, z1 - lip), wide - 0.4, 0.8, "line", flat="z")
        mid = 0.025 - DROP / 2
        head.beam((gum_from, 0, lip_bottom(k, gum_from) + mid), (x1 + 0.3, 0, lip_bottom(k, x1 + 0.3) + mid), wide - 1.0, DROP + 0.05,
                  "gum", flat="z")
    rise = blocks[0][5] / 2 + 0.2  # a lighter plate on top of the first block, running into the skull's top row
    head.beam((-25.4, 0, middle(0, -25.4) + rise), (-27.7, 0, middle(0, -27.7) + rise), 4.4, 0.5, "hide+", flat="z")
    # the mouth, at the very front and a little open. Its dark inside stays behind the teeth and ends inside lips and jaw
    mouth = (-2.2, 2.2, -2.75, -1.25)
    head.block(-28.0, mouth, -25.5, mouth, "mouth")
    mouth = (-1.2, 1.2, -2.9, -1.3)
    head.block(-28.8, mouth, -27.9, mouth, "mouth")
    # the lower jaw: two boxes, as long as the snout
    jaws = ((-25.2, -28.2, -2.95, -3.1, 6.6, 1.1, -25.2), (-27.6, -29.7, -3.08, -3.12, 4.6, 0.7, -28.5))

    def jaw_top(k, x):
        x0, x1, z0, z1, _, thick = jaws[k][:6]
        return z0 + (z1 - z0) * (x - x0) / (x1 - x0) + thick / 2

    for k, (x0, x1, z0, z1, wide, thick, gum_from) in enumerate(jaws):
        head.beam((x0, 0, z0), (x1, 0, z1), wide, thick, "belly", flat="z")
        mid = DROP / 2 - 0.025
        head.beam((gum_from, 0, jaw_top(k, gum_from) + mid), (x1 + 0.35, 0, jaw_top(k, x1 + 0.35) + mid), wide - 1.0, DROP + 0.05, "gum",
                  flat="z")
    # needle teeth, bases sunk in the gums: down along each side and across the front, up from the lower jaw
    for k, x in ((0, -26.5), (0, -27.3), (0, -27.9), (1, -29.0)):
        head.tooth(x, (2.95, 1.95)[k], lip_bottom(k, x) - DROP + 0.1, 0.5, 0.7, "tooth")
    front = lip_bottom(1, -29.4) - DROP + 0.1
    head.tooth(-29.4, 0.0, front, 0.5, 0.7, "tooth", mirror=False)
    head.tooth(-29.4, 1.0, front, 0.5, 0.65, "tooth")
    for k, x in ((0, -26.9), (0, -27.6), (1, -28.7)):
        head.tooth(x, (2.5, 1.5)[k], jaw_top(k, x) + DROP - 0.1, 0.45, -0.5, "tooth")
    head.tooth(-29.1, 0.55, jaw_top(1, -29.1) + DROP - 0.1, 0.45, -0.5, "tooth")
    # the eye: a big dark block on the side of the skull, over the pale line. The brow is a low lid: it sits on the eye,
    # cuts its top and comes a little past it in front
    eye = (4.4, 5.3, -0.1, 1.5)
    head.block(-25.0, eye, -23.1, eye, "black", mirror=True)
    head.beam((-25.5, 4.9, 1.35), (-22.5, 4.9, 1.5), 0.6, 1.6, "hide", mirror=True)

    # the body: the collar and nine slices, each on its own joint
    segs, spans, x = [], [], BODY_FROM
    for i, (length, n, bot, top) in enumerate(SLICES):
        segs.append(m.part(NAMES[i], (x, 0, 0), "Head" if i == 0 else NAMES[i - 1]))
        spans.append((x, x + length, n, bot, top))
        x += length
    end = x
    for i, (seg, (x0, x1, n, bot, top)) in enumerate(zip(segs, spans)):
        slab(seg, x0, x1, n, bot, top)
        # a sleeve into the piece in front, sized from the smaller of the two and clear of both pieces' steps
        fn, fbot, ftop = spans[i - 1][2:5] if i else (4, -4, 3)
        small = min(n, fn)
        up = max(len(top_steps(n)), len(top_steps(fn)) if i else 1)
        down = max(len(bottom_steps(n)), len(bottom_steps(fn)) if i else 1)
        seg.sym(x0 - 1, x0, max(small - 2, 0), max(bot, fbot) + down, min(top, ftop) - up, "hide-")

    # the collar: six gill flaps a side, like louvres, each shorter than the one before
    collar = segs[0]
    for i in range(6):
        xs, top, bot = -19.9 + 0.9 * i, 2.4 - 0.22 * i, -2.8 + 0.13 * i
        zc = (top + bot) / 2
        frill(collar, (xs, 4.0, zc), (xs + 1.2, 5.0, zc), top - bot, "y", True)

    # the seat: behind the collar, a shallow slot either side for the rider's legs
    segs[2].dent(-9, -6, 3, 0, 2, "hide-")

    # the fins, small and far back. The side fins sit low, just behind the collar
    segs[1].beam((-12.4, 1.4, -1.5), (-9.9, 5.0, -2.3), 2.8, 0.8, "hide", flat="z", mirror=True)
    segs[1].beam((-10.525, 4.1, -2.1), (-8.9, 6.2, -2.55), 2.0, 0.4, "hide-", flat="z", mirror=True)
    segs[6].beam((9.2, 0.9, -1.5), (11.8, 3.6, -3.1), 2.6, 0.6, "hide-", flat="z", mirror=True)  # the belly fins
    segs[7].beam((12.8, 0, 1.9), (15.6, 0, 3.9), 2.6, 0.9, "hide")  # the one small back fin
    segs[7].beam((15.0, 0, 3.45), (16.8, 0, 4.3), 1.6, 0.6, "hide-")
    segs[7].beam((13.0, 0, -0.6), (16.0, 0, -2.9), 3.2, 0.9, "hide")  # the anal fin, bigger than the back fin
    segs[7].beam((15.1, 0, -2.21), (17.4, 0, -3.5), 2.0, 0.6, "hide-")

    # the tail: a short stub of spine, a long low blade and a lower lobe; the blade's tip on a joint of its own
    tail = m.part("Tail", (end, 0, 0), NAMES[-1])
    slab(tail, end, end + 2, 1, -1, 2)
    tail.sym(end - 1, end, 0, 0, 1, "hide-")
    tail.beam((end + 0.6, 0, 0.5), (end + 6.4, 0, 1.2), 3.0, 0.7, "hide")
    tail.beam((end + 1.0, 0, 0.2), (end + 5.2, 0, -1.4), 2.2, 0.4, "hide-")
    tip = m.part("TailTip", (end + 5.6, 0, 1.1), "Tail")
    tip.beam((end + 5.4, 0, 1.08), (end + 9.6, 0, 1.9), 1.9, 0.4, "hide-")
