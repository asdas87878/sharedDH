"""The Clownfish for tools/blender/voxel_kit.py (docs/style/04-voxel-style.md). Third pass, in big blocks, by the same rules
as the Sergeant Major.
- The body is a chain of orange slabs. The three white bands are touches of colour: bands a third of a cube proud, each
  with a thin black edge either side. None sits where the body changes size.
- The fins are big boxes with a black tip box: a small front lobe and a tall main lobe on the back, a plate behind it, one
  underneath, a paddle each side, and a square tail paddle with a black rim on a thick stock.
- The face is a muzzle box with a lighter slab leaning down it for the forehead, a jaw box and a lip block.
- A big framed eye, the pupil low and forward: a friendly Common.
The rider sits in the orange gap between the first two bands, legs in a shallow slot either side."""
NAME, ZONE, RARITY = "Clownfish", "ZONE 1 / SHALLOWS", "COMMON"
U = 0.35
PALETTE = {"orange": "#F5822A", "white": "#F7F1E6", "black": "#353534"}
SEAT = (-0.5, 7, 5.6)
SWIM = {"chain": ["Head", "S1", "S2", "S3", "S4", "Tail"], "amplitudes": [3, 6, 9, 12, 18], "phaseStep": 0.9, "headCounter": 2}
PROUD = 0.3  # how far a band stands off the body, in cubes
EDGE = 0.4  # how long a band's black edge is


def steps(n):
    """the corner steps of a body slab n cubes out: (top, bottom)"""
    if n >= 5:
        return [(3, 1), (1, 1)], [(3, 1), (1, 2)]
    if n >= 4:
        return [(2, 1), (1, 1)], [(2, 1), (1, 1)]
    if n >= 3:
        return [(1, 1)], [(1, 1)]
    return [], []


def slab(p, x0, x1, n, bot, top):
    """a length of orange body with stepped corners: lighter on the top row, darker on the belly steps"""
    steps_top, steps_bottom = steps(n)
    p.hull(x0, x1, n, bot, top, "orange", steps_top, steps_bottom)
    p.paint_sym(x0, x1, n, bot, bot + sum(t for _, t in steps_bottom), "orange-")
    if steps_top:
        p.paint_sym(x0, x1, n, top - 1, top, "orange+")


def band(p, x0, x1, n, bot, top):
    """a white band round the body from x0 to x1, with a thin black edge in front of it and behind it"""
    steps_top, steps_bottom = steps(n)
    for a, b, colour in ((x0 - EDGE, x0, "black"), (x0, x1, "white"), (x1, x1 + EDGE, "black")):
        p.band(a, b, n, bot, top, colour, steps_top, steps_bottom, PROUD)


def build(m):
    head = m.part("Head", (-5, 0, 0))
    slab(head, -9, -5, 4, -5, 6)
    # the face: a muzzle box; a lighter slab leaning down it for the forehead, its upper end inside the head and its
    # underside inside the muzzle; a jaw box under it; a darker lip block
    muzzle = (-3.2, 3.2, -2.8, 2.7)
    head.block(-11.0, muzzle, -8.8, muzzle, "orange")
    head.beam((-8.397, 0, 4.216), (-10.95, 0, 2.074), 6.7, 1.7, "orange+", flat="z")
    jaw = (-2.3, 2.3, -3.9, -2.7)
    head.block(-10.4, jaw, -8.9, jaw, "orange-")
    lip = (-1.5, 1.5, -1.3, -0.1)
    head.block(-11.9, lip, -10.9, lip, "orange-")
    # the eye: a white frame one cube proud, a dark square pupil low and forward in it
    head.pair(-9, -6, 5, 6, 1, 4, "white")
    head.paint_pair(-9, -7, 5, 6, 1, 3, "black")

    cuts = [-5, 1, 6, 10, 12]
    segs = [m.part(f"S{i + 1}", (cuts[i], 0, 0), "Head" if i == 0 else f"S{i}") for i in range(4)]
    slab(segs[0], -5, 1, 5, -6, 7)
    slab(segs[1], 1, 6, 5, -6, 7)
    slab(segs[2], 6, 7, 5, -6, 7)
    slab(segs[2], 7, 9, 4, -4, 5)
    slab(segs[2], 9, 10, 3, -3, 4)
    slab(segs[3], 10, 12, 2, -2, 3)
    band(segs[0], -3.9, -2.55, 5, -6, 7)  # behind the eye, most of a cube back from the step up from the head
    band(segs[1], 2.55, 4.25, 5, -6, 7)  # the middle band
    band(segs[3], 10.55, 11.45, 2, -2, 3)  # the tail band
    segs[0].sym(-6, -5, 3, -3, 4, "orange-")  # sleeves, one cube into the piece in front
    segs[1].sym(0, 1, 3, -4, 5, "orange-")
    segs[2].sym(5, 6, 3, -4, 5, "orange-")
    segs[3].sym(9, 10, 2, -2, 3, "orange-")
    # the seat: between the first two bands, with a shallow slot either side for the rider's legs
    segs[0].dent(-2, 1, 5, 1, 4, "orange-")

    # the back fin: a small front lobe, a tall main lobe behind the rider, a plate behind that; each with a black tip box
    segs[0].beam((-3.7, 0, 6.3), (-2.9, 0, 8.8), 2.4, 1.2, "orange")
    segs[0].beam((-3.25, 0, 8.0), (-2.8, 0, 9.6), 1.8, 0.9, "black")
    segs[1].beam((3.2, 0, 6.3), (4.4, 0, 10.6), 3.6, 1.2, "orange")
    segs[1].beam((4.0, 0, 9.6), (4.6, 0, 11.8), 2.8, 0.9, "black")
    segs[2].beam((7.6, 0, 4.3), (8.5, 0, 7.4), 2.2, 1.2, "orange")
    segs[2].beam((8.2, 0, 6.6), (8.6, 0, 8.4), 1.6, 0.9, "black")
    # the fin underneath
    segs[1].beam((4.2, 0, -5.4), (5.2, 0, -8.4), 2.8, 1.2, "orange")
    segs[1].beam((4.85, 0, -7.6), (5.35, 0, -9.4), 2.0, 0.9, "black")
    # the side fins: one paddle each, starting inside the body's side under the seat and swept back; small belly fins
    segs[0].beam((-1.2, 5.0, -1.2), (1.8, 7.4, -2.2), 2.8, 0.9, "orange", mirror=True)
    segs[0].beam((1.1, 6.85, -1.97), (2.5, 7.95, -2.43), 2.2, 0.5, "black", mirror=True)
    segs[0].beam((-3.0, 2.0, -5.3), (-1.6, 2.4, -8.0), 1.6, 0.8, "orange", mirror=True)
    segs[0].beam((-2.05, 2.27, -7.13), (-1.3, 2.49, -8.6), 1.2, 0.5, "black", mirror=True)

    # the tail, on its own joint: a thick stock that starts inside the body, a square paddle, a black rim box
    tail = m.part("Tail", (12, 0, 0), "S4")
    tail.beam((11.6, 0, 0.5), (13.4, 0, 0.5), 4.5, 2.0, "orange")
    tail.beam((12.8, 0, 0.5), (16.2, 0, 0.5), 8.4, 1.1, "orange")
    tail.beam((15.8, 0, 0.5), (17.0, 0, 0.5), 7.4, 0.8, "black")
