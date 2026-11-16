"""The Reef Shark, trial (docs/style/07-shape-variety.md): a blacktip reef shark rebuilt as "the quick one", for
tools/blender/voxel_kit.py. Set beside art/creatures/ReefShark, which the game still uses.
- The body idea: a slim dart. The body is 7 cubes deep and 7 wide where it is biggest, in the middle, and tapers both ways
  in both views. The head is short and comes to a narrow tip: three blocks in a chain, each a clear step smaller.
- The mouth: small, UNDER the snout, shut. A thin dark line between an upper lip and a narrower lower jaw, turning up at
  the corner in a smirk; six small teeth just showing over the line.
- A large eye set forward on a cream plate, under a thin level brow of the lighter tone (alert, not angry).
- Colour: warm sand-gold over cream. The line between them runs low, then behind the gills the cream sweeps up the flank
  in a wedge of three steps and drops back.
- The one mark: black tips on every fin (the tall swept back fin, the long side fins, both tail lobes, the small rear ones).
The rider sits in the middle, in front of the back fin, legs in a slot either side (inside the top of the pale wedge)."""
NAME, ZONE, RARITY = "Reef Shark (trial)", "ZONE 1 / SHALLOWS", "EPIC"
U = 0.4
PALETTE = {"gold": "#D2A256", "cream": "#F6EBD0", "black": "#25252A", "mouth": "#5E2B30", "tooth": "#FFFFFF"}
SEAT = (-2, 4, 3.6)
FRAME, ORTHO = 1.45, 21.0
SHADE = 0.9  # the darker tones stay close: quiet gill slits, a warm underside
SWIM = {"chain": ["Head", "S1", "S2", "S3", "S4", "Tail"], "amplitudes": [2, 5, 9, 13, 20], "phaseStep": 0.9, "headCounter": 2}
TEXTURES = [{"tile": "stud", "on": "top", "colours": ["gold"]}]


def slab(p, x0, x1, n, bot, top, line, bottom_step=True):
    """a length of body: gold with a lighter top row, cream below `line`; stepped corners when it is wide enough"""
    steps = [(1, 1)] if n >= 2 else []
    under = steps if bottom_step else []
    p.hull(x0, x1, n, bot, top, "gold", steps, under)
    p.paint_sym(x0, x1, n, top - 1, top, "gold+")
    p.paint_sym(x0, x1, n, bot, line, "cream")
    if under:
        p.paint_sym(x0, x1, n, bot, bot + 1, "cream-")


def fin(p, boxes, colour, flat="y", mirror=False):
    """a fin: boxes at an angle, each smaller and thinner than the last and starting inside it; the last one is the black tip"""
    for k, (p0, p1, width, thick) in enumerate(boxes):
        p.beam(p0, p1, width, thick, "black" if k == len(boxes) - 1 else colour, flat=flat, mirror=mirror)


def build(m):
    head = m.part("Head", (-11, 0, 0))
    slab(head, -14, -11, 2, -2, 3, -1, bottom_step=False)  # the back of the head; its underside is whole, so the jaw is buried
    # the snout: three blocks in a chain, each a clear step lower and narrower, the last two nose-down. Cream underneath,
    # a lighter plate on top of the first two
    head.beam((-13.4, 0, 0.55), (-17.0, 0, 0.55), 4.4, 2.5, "gold", flat="z")
    head.beam((-13.6, 0, 2.0), (-16.7, 0, 2.0), 2.6, 0.4, "gold+", flat="z")
    head.beam((-16.3, 0, 0.45), (-19.0, 0, 0.2), 3.0, 1.8, "gold", flat="z")
    head.beam((-16.3, 0, -0.65), (-18.85, 0, -0.886), 2.7, 0.4, "cream", flat="z")
    head.beam((-16.6, 0, 1.472), (-18.7, 0, 1.278), 1.9, 0.3, "gold+", flat="z")
    head.beam((-18.4, 0, 0.15), (-20.6, 0, -0.05), 1.6, 1.1, "gold", flat="z")
    head.beam((-18.4, 0, -0.625), (-20.45, 0, -0.811), 1.3, 0.45, "cream", flat="z")
    # the mouth, shut, under the first block: an upper lip, a thin dark line set in from it, and a narrower lower jaw
    head.beam((-13.4, 0, -0.925), (-16.75, 0, -0.925), 4.0, 0.45, "cream", flat="z")
    head.beam((-13.2, 0, -1.325), (-16.15, 0, -1.325), 3.3, 0.35, "mouth", flat="z")
    head.beam((-12.6, 0, -1.85), (-16.55, 0, -1.85), 3.7, 0.7, "cream", flat="z")
    # the smirk: the line turns up at the corner, on the side of the head
    head.beam((-13.8, 2.45, -1.33), (-12.8, 2.45, -0.62), 0.4, 0.4, "mouth", mirror=True)
    # a few small teeth hanging from the lip over the line: two a side, two in front
    for x in (-14.7, -15.7):
        head.tooth(x, 1.72, -1.05, 0.5, 0.55, "tooth", lean=(0.0, 0.18))
    head.tooth(-16.4, 0.55, -1.05, 0.5, 0.55, "tooth", lean=(-0.1, 0.0))
    # the eye, large and set forward: a cream plate, a dark pupil proud of it, and a thin level brow that cuts its top
    plate = (2.2, 2.8, -0.3, 1.5)
    head.block(-14.5, plate, -12.4, plate, "cream", mirror=True)
    pupil = (2.6, 3.05, 0.0, 1.2)
    head.block(-14.1, pupil, -12.8, pupil, "black", mirror=True)
    head.beam((-14.75, 2.55, 1.35), (-12.15, 2.55, 1.35), 0.6, 1.5, "gold+", mirror=True)

    cuts = [-11, -6, 4, 9, 14]
    segs = [m.part(f"S{i + 1}", (cuts[i], 0, 0), "Head" if i == 0 else f"S{i}") for i in range(4)]
    slab(segs[0], -11, -6, 3, -3, 3, -1)
    slab(segs[1], -6, 1, 3, -3, 4, -1)  # the middle: the deepest and widest slice
    slab(segs[1], 1, 4, 2, -3, 4, -1)  # under the back fin it is already narrower: from above the body tapers from here
    slab(segs[2], 4, 9, 2, -2, 3, 0)
    slab(segs[3], 9, 12, 1, -1, 2, 0)
    slab(segs[3], 12, 14, 1, 0, 2, 1)
    # the pale wedge: behind the gills the belly colour sweeps up the flank in three steps, then drops back
    segs[0].paint_sym(-9, -6, 3, -1, 0, "cream")
    segs[0].paint_sym(-7, -6, 3, 0, 1, "cream")
    segs[1].paint_sym(-6, 0, 3, -1, 1, "cream")
    segs[1].paint_sym(-4, 0, 3, 1, 2, "cream")
    for x in (-10, -8):  # gill slits: two short quiet lines
        segs[0].dent(x, x + 1, 3, 0, 2, "gold-")
    segs[1].dent(-3, -1, 3, -1, 2, "cream-")  # the rider's leg slot, inside the top of the wedge
    segs[0].sym(-12, -11, 1, -1, 2, "gold-")  # sleeves, one cube into the piece in front and inside its steps
    segs[1].sym(-7, -6, 2, -2, 2, "gold-")
    segs[2].sym(3, 4, 1, -1, 2, "gold-")
    segs[3].sym(8, 9, 1, -1, 2, "gold-")

    # the back fin: tall, narrow, swept back like a sickle, behind the seat
    fin(segs[1], (((1.4, 0, 3.0), (4.2, 0, 8.4), 3.6, 1.1), ((3.7, 0, 7.5), (6.2, 0, 10.6), 2.5, 0.8),
                  ((5.65, 0, 9.9), (8.0, 0, 12.0), 1.6, 0.5)), "gold")
    # the side fins: long, pointed, held out like wings
    fin(segs[0], (((-8.2, 2.4, -1.3), (-6.4, 7.4, -2.4), 3.2, 1.0), ((-6.69, 6.6, -2.225), (-4.9, 10.8, -3.15), 2.3, 0.7),
                  ((-5.241, 10.0, -2.973), (-3.6, 13.0, -3.633), 1.5, 0.35)), "gold", flat="z", mirror=True)
    # the small rear fins, each a box and a black tip
    fin(segs[3], (((9.8, 0, 1.3), (11.1, 0, 3.3), 1.6, 0.8), ((10.7, 0, 2.7), (11.8, 0, 4.2), 1.1, 0.5)), "gold")
    fin(segs[3], (((9.8, 0, -0.3), (11.1, 0, -2.3), 1.6, 0.8), ((10.7, 0, -1.7), (11.8, 0, -3.2), 1.1, 0.5)), "cream")
    fin(segs[2], (((5.4, 0.8, -1.0), (7.2, 2.4, -2.8), 1.7, 0.6), ((6.7, 2.0, -2.3), (7.8, 3.0, -3.5), 1.2, 0.3)), "cream",
        flat="z", mirror=True)

    # the tail, on its own joint: a big crescent, the upper lobe much the longer, both tips black
    tail = m.part("Tail", (14, 0, 0), "S4")
    tail.beam((13.4, 0, 1.0), (15.6, 0, 1.0), 1.5, 1.3, "gold")
    fin(tail, (((14.6, 0, 1.3), (17.0, 0, 5.6), 2.8, 1.0), ((16.4, 0, 4.8), (19.2, 0, 8.6), 2.1, 0.7),
               ((18.6, 0, 7.9), (21.0, 0, 10.6), 1.5, 0.4)), "gold")
    fin(tail, (((14.6, 0, 0.7), (16.6, 0, -2.4), 2.4, 0.7), ((16.1, 0, -1.8), (17.9, 0, -4.4), 1.7, 0.4)), "gold")
