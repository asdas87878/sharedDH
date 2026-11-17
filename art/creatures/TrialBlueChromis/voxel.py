"""The Blue Chromis, a trial of docs/style/09-early-remodels.md, for tools/blender/voxel_kit.py. It stands beside the
game's Blue Chromis (art/creatures/BlueChromis) and replaces nothing. Designed from the real animal.
Its idea: the dart. A teardrop that tapers the whole way to a thin stalk and a scissor tail.
- The body idea in numbers: about 29 cubes long; the body alone is 10 deep (0.35 of the length) from the back of the
  head to the end of the chest (its middle a quarter of the way back) and 7 wide at the chest only. From there every
  slice loses one cube, of the back, the belly or the width in turn, down to a stalk 2 cubes deep and 1 wide.
- A scissor tail on its own joint: two long thin lobes in a deep V, as tall tip to tip as the body is deep.
- One tall pointed back fin, swept back, behind the rider. Small side fins under the rider's feet.
- The face: a big round eye, a cream ring 3 by 3 cubes and a dark pupil, on a short blunt head. A tiny mouth at the tip
  of the snout, turned up: a notch one cube deep between a lip and a jaw that both tilt up to the front. No brow.
- Electric cyan over a silver-blue belly; the line between them is straight and low.
- The one mark: deep blue on the leading edge of the back fin and the outer edge of both tail lobes.
The rider sits on the chest, the widest and highest place, in front of the back fin, legs in a shallow slot either side."""
NAME, ZONE, RARITY = "Blue Chromis (trial)", "ZONE 1 / SHALLOWS", "COMMON"
U = 0.35
PALETTE = {"cyan": "#19B4F2", "silver": "#CFEAF7", "deep": "#1B4FC4", "white": "#F4F1E4", "black": "#1E2024"}
SHADE = 0.9
SEAT = (-6, 5, 3.5)
TEXTURES = [{"tile": "stud", "on": "top", "colours": ["cyan"]}]
SWIM = {"chain": ["Head", "S1", "S2", "S3", "Tail"], "amplitudes": [4, 8, 13, 22], "phaseStep": 0.9, "headCounter": 2}
BELLY = -2  # the silver belly's edge: one level line, low on the flank

# the body in slices (from, to, cubes out, bottom, top). One number changes from slice to slice, never two
HEAD = ((-12, -11, 2, -3, 4), (-11, -10, 2, -4, 4), (-10, -9, 2, -4, 5), (-9, -8, 2, -5, 5))
BODY = (("S1", ((-8, -5, 3, -5, 5), (-5, -4, 3, -4, 5), (-4, -3, 2, -4, 5))),  # the chest: the widest slice, the seat
        ("S2", ((-3, -2, 2, -4, 4), (-2, -1, 2, -3, 4), (-1, 0, 2, -3, 3), (0, 1, 2, -2, 3), (1, 2, 2, -2, 2), (2, 3, 1, -2, 2))),  # the back fin
        ("S3", ((3, 4, 1, -1, 2), (4, 5, 0, -1, 2), (5, 7, 0, -1, 1))))  # down to the stalk


def slab(p, x0, x1, n, bot, top):
    """a slice of body: one step cut from each corner, a lighter top row, silver from the belly line down"""
    steps = [(1, 1)] if n >= 1 else []
    p.hull(x0, x1, n, bot, top, "cyan", steps, steps)
    p.paint_sym(x0, x1, n, top - 1, top, "cyan+")
    p.paint_sym(x0, x1, n, bot, BELLY, "silver")


def build(m):
    head = m.part("Head", (-8, 0, 0))
    for s in HEAD:
        slab(head, *s)
    # the face: a short blunt cone. One big block tilted a little nose-down, then the snout in two smaller blocks that
    # both tilt UP to the front, the nose and the jaw under it, with a notch a cube deep between them (the mouth) and deep
    # blue at its back
    head.beam((-11.2, 0, 0.7), (-13.2, 0, 0.4), 4.2, 5.0, "cyan", flat="z")
    head.beam((-12.5, 0, 0.72), (-14.15, 0, 1.16), 2.8, 1.7, "cyan", flat="z")  # the nose
    head.beam((-12.5, 0, -1.36), (-14.3, 0, -0.88), 2.4, 1.3, "cyan", flat="z")  # the jaw, a little past the nose
    head.beam((-12.6, 0, -0.396), (-13.3, 0, -0.208), 2.0, 0.9, "deep", flat="z")  # the back of the mouth
    # the eye: big and round, a cream ring sunk in the side of the head and a dark pupil, each a little proud of the last
    ring = (1.4, 2.9, 0.2, 3.2)
    head.block(-12.2, ring, -9.2, ring, "white", mirror=True)
    pupil = (2.5, 3.2, 0.9, 2.5)
    head.block(-11.5, pupil, -9.9, pupil, "black", mirror=True)

    segs, before = {}, HEAD[-1]
    for i, (name, slices) in enumerate(BODY):
        seg = segs[name] = m.part(name, (slices[0][0], 0, 0), "Head" if i == 0 else BODY[i - 1][0])
        for s in slices:
            slab(seg, *s)
        # a sleeve into the piece in front, so a bending joint shows body: a cube in from the smaller of the two all round
        x0, _, n, bot, top = slices[0]
        _, _, fn, fbot, ftop = before
        seg.sym(x0 - 1, x0, max(min(n, fn) - 1, 0), max(bot, fbot) + 1, min(top, ftop) - 1, "cyan-")
        before = slices[-1]
    s1, s2, s3 = (segs[name] for name, _ in BODY)

    s1.dent(-7, -5, 3, 1, 4, "cyan")  # the seat's leg slots
    # the side fins: small, two boxes swept back and a little down, under the rider's feet
    s1.beam((-7.4, 2.6, -1.5), (-5.2, 4.7, -2.1), 2.0, 0.8, "cyan", flat="z", mirror=True)
    s1.beam((-5.9, 4.1, -1.95), (-4.4, 5.5, -2.4), 1.3, 0.4, "cyan", flat="z", mirror=True)

    # the back fin, behind the rider: tall, pointed and swept back. Its boxes line up on the leading edge, which is one
    # straight deep-blue bar from the back to the point (THE MARK), and step in at the rear
    ux, uz, wx, wz, ox, oz = 0.574, 0.819, -0.819, 0.574, -2.9, 3.6  # up the fin; toward its front; the foot of its leading edge

    def fin(s_from, s_to, front, rear, thick, colour):
        w = -(front + rear) / 2
        s2.beam((ox + s_from * ux + w * wx, 0, oz + s_from * uz + w * wz), (ox + s_to * ux + w * wx, 0, oz + s_to * uz + w * wz),
                rear - front, thick, colour)

    fin(0.0, 7.4, 0.0, 0.9, 1.4, "deep")
    fin(-0.6, 4.2, 0.7, 4.6, 1.0, "cyan")
    fin(3.6, 5.9, 0.7, 3.2, 0.6, "cyan")
    fin(5.4, 6.9, 0.7, 2.0, 0.3, "cyan")

    # the tail, on its own joint: a short block round the end of the stalk, then two long thin lobes in a deep V. Each lobe
    # is a deep-blue bar along its outer edge from the root to the tip (THE MARK) and two thinner cyan boxes inside it
    tail = m.part("Tail", (7, 0, 0), "S3")
    tail.beam((6.6, 0, 0), (8.4, 0, 0), 2.4, 1.6, "cyan")
    dx, dz, nx, nz, ex, ez = 0.850, 0.526, -0.526, 0.850, 7.7, 1.1  # along a lobe; out from it; the root of its outer edge

    def lobe(side, s_from, s_to, outer, inner, thick, colour):
        w = -(outer + inner) / 2
        p0 = (ex + s_from * dx + w * nx, 0, side * (ez + s_from * dz + w * nz))
        p1 = (ex + s_to * dx + w * nx, 0, side * (ez + s_to * dz + w * nz))
        tail.beam(p0, p1, inner - outer, thick, colour)

    for side, thick in ((1, 0.9), (-1, 0.6)):  # the two lobes cross at the root: never the same thickness there
        lobe(side, 0.0, 7.4, 0.0, 0.8, 1.2, "deep")
        lobe(side, -0.6, 4.4, 0.6, 2.2, thick, "cyan")
        lobe(side, 3.8, 6.7, 0.6, 1.6, 0.3, "cyan")
