"""The Reef Shark (zone 1's Epic: a blacktip reef shark) for tools/blender/voxel_kit.py (docs/style/04-voxel-style.md).
Third pass, built the way the reference builds: from big blocks, each one a body part, some of them tilted.
- The body is a chain of slabs, each with one plate on top and one underneath.
- Every fin is two or three boxes at an angle, each smaller than the one before and starting inside it, ending in a
  black tip. The tail is a root block and two lobes.
- The head keeps its shark shape, but no face of it is squeezed to a slope: the snout is three big blocks in a chain, each
  tilted nose-down and a step lower and narrower, so its slope is made the way the fins are. The jaw is two boxes.
- Teeth are pyramids. The gum line is a choice (`GUM`). The eye is a dark block under a slanting brow box.
- Touches: a lighter side line where the grey meets the white, a darker collar round the root of each big fin, and an
  old scar on the left flank.
The rider sits behind the gills, legs in a slot either side."""
NAME, ZONE, RARITY = "Reef Shark", "ZONE 1 / SHALLOWS", "EPIC"
U = 0.4
PALETTE = {"grey": "#8C979E", "white": "#EFEEE8", "black": "#33363A", "mouth": "#7A2E33", "tooth": "#FFFFFF"}
SEAT = (-3, 5, 4.6)
FRAME, ORTHO = 1.45, 21.0
GUM = "thin"  # the gum line (docs/style/04-voxel-style.md): "both", "top", "thin", "behind" or "none"
PALETTE["gum"] = {"thin": "#9A4F58", "behind": "#A85A62"}.get(GUM, "#C8727C")
UPPER, LOWER = GUM in ("both", "top", "thin"), GUM in ("both", "thin")  # a gum plate under the lips, on the jaw
DROP = {"both": 0.3, "top": 0.3, "thin": 0.15}.get(GUM, 0.0)  # how far a gum plate shows past its lip
SWIM = {"chain": ["Head", "S1", "S2", "S3", "S4", "Tail"], "amplitudes": [2, 5, 9, 13, 20], "phaseStep": 0.9, "headCounter": 2}


def slab(p, x0, x1, n, bot, top, belly):
    """a length of body: a core block with one lighter plate on top and one darker plate underneath, white from `belly` down"""
    inset = 2 if n >= 4 else (1 if n >= 2 else 0)
    steps = [(inset, 1)] if inset else []
    p.hull(x0, x1, n, bot, top, "grey", steps, steps)
    p.paint_sym(x0, x1, n, top - 1, top, "grey+")
    p.paint_sym(x0, x1, n, belly, belly + 1, "grey+")  # the side line: one lighter row where the grey meets the white
    p.paint_sym(x0, x1, n, bot, belly, "white")
    if steps:
        p.paint_sym(x0, x1, n, bot, bot + 1, "white-")


def build(m):
    head = m.part("Head", (-9, 0, 0))
    slab(head, -13, -9, 4, -4, 4, -1)  # the back of the head: the eye sits on its side
    head.sym(-13, -11, 3, -4, -3, "white-")  # the jaw's hinge: the bottom row is wider here, so the jaw's root is buried
    # the snout: three big blocks in a chain, each tilted nose-down and a step lower and narrower than the last. Each has
    # a white lip plate underneath; the first two have a lighter plate on top, like the body's slabs, which starts past the
    # end of the block before (so no two tops lie close together)
    blocks = ((-12.5, -16.0, 1.25, 0.85, 7.8, 3.3, 4.6, -12.5, -12.5), (-15.4, -18.8, 0.75, 0.35, 5.8, 2.5, 3.2, -16.2, -16.3),
              (-18.2, -20.9, 0.25, -0.05, 4.0, 1.8, 0.0, 0.0, 0.0))

    def lip_bottom(k, x):
        """the underside of block k's lip plate at x"""
        x0, x1, z0, z1, _, thick = blocks[k][:6]
        return z0 + (z1 - z0) * (x - x0) / (x1 - x0) - thick / 2 - 0.8

    for k, (x0, x1, z0, z1, wide, thick, plate, plate_from, gum_from) in enumerate(blocks):
        head.beam((x0, 0, z0), (x1, 0, z1), wide, thick, "grey", flat="z")
        lip = thick / 2 + 0.4
        head.beam((x0, 0, z0 - lip), (x1, 0, z1 - lip), wide - 0.4, 0.8, "white", flat="z")
        if plate:
            def top(x):
                return z0 + (z1 - z0) * (x - x0) / (x1 - x0) + thick / 2 + 0.2

            head.beam((plate_from, 0, top(plate_from)), (x1 + 0.7, 0, top(x1 + 0.7)), plate, 0.5, "grey+", flat="z")
        if plate and UPPER:  # a gum plate under the lip, set in from its edge, that the teeth hang from
            mid = 0.025 - DROP / 2  # its top is just inside the lip, its underside DROP below it
            head.beam((gum_from, 0, lip_bottom(k, gum_from) + mid), (x1 + 0.3, 0, lip_bottom(k, x1 + 0.3) + mid), wide - 1.0, DROP + 0.05,
                      "gum", flat="z")
    # the mouth, set back under the snout and open. Its dark inside is two blocks that stay behind the teeth and end
    # inside the lips and the jaw, so nothing of it pokes out. The lower jaw is two boxes, the smaller in front
    mouth = (-2.0, 2.0, -3.2, -1.1)
    head.block(-15.7, mouth, -12.8, mouth, "mouth")
    mouth = (-1.1, 1.1, -3.3, -1.2)
    head.block(-17.6, mouth, -15.8, mouth, "mouth")
    jaws = ((-12.9, -15.9, -3.3, -3.45, 6.7, 1.2, -12.9), (-15.4, -18.6, -3.45, -3.6, 4.4, 0.7, -16.2))

    def jaw_top(k, x):
        x0, x1, z0, z1, _, thick = jaws[k][:6]
        return z0 + (z1 - z0) * (x - x0) / (x1 - x0) + thick / 2

    for k, (x0, x1, z0, z1, wide, thick, gum_from) in enumerate(jaws):
        head.beam((x0, 0, z0), (x1, 0, z1), wide, thick, "white", flat="z")
        if LOWER:
            mid = DROP / 2 - 0.025
            head.beam((gum_from, 0, jaw_top(k, gum_from) + mid), (x1 - 0.3, 0, jaw_top(k, x1 - 0.3) + mid), wide - 0.6, DROP + 0.05, "gum",
                      flat="z")
    head.beam((-13.0, 0, -4.05), (-16.4, 0, -4.1), 4.0, 0.5, "white-", flat="z")  # a chin plate under it
    if GUM == "behind":  # the gums as a band inside the mouth, behind the teeth: seen between them, not round the lips
        for x0, x1, half, za, zb in ((-15.5, -12.8, 2.55, -1.9, -1.15), (-17.4, -15.5, 1.55, -2.0, -1.25),
                                     (-15.4, -12.9, 2.4, -2.95, -2.35), (-17.4, -15.4, 1.35, -3.3, -2.75)):
            head.block(x0, (-half, half, za, zb), x1, (-half, half, za, zb), "gum")
    # pointed teeth, each with its base sunk a little into a gum or a lip: down along each side and across the front, up
    # from the lower jaw. With a gum plate they stand a little further in and are a little shorter
    out, up = (0.2 if UPPER else 0.0), (0.2 if LOWER else 0.0)
    for k, x in ((0, -13.4), (0, -14.3), (0, -15.2), (1, -16.85), (1, -17.6)):
        head.tooth(x, (3.2, 2.2)[k] - out, lip_bottom(k, x) - DROP * UPPER + 0.1, 0.75, 0.85 - 0.8 * DROP * UPPER, "tooth")
    front = lip_bottom(1, -18.1) - DROP * UPPER + 0.1
    head.tooth(-18.1, 0.0, front, 0.75, 0.9 - 0.8 * DROP * UPPER, "tooth", mirror=False)
    head.tooth(-18.1, 1.15, front, 0.75, 0.85 - 0.8 * DROP * UPPER, "tooth")
    for k, x in ((0, -13.9), (0, -15.1), (1, -16.75), (1, -17.6)):
        head.tooth(x, (2.85, 1.75)[k] - up, jaw_top(k, x) + DROP * LOWER - 0.1, 0.65, -(0.65 - 0.67 * DROP * LOWER), "tooth")
    # the eye: a dark block under a brow box that slants down to the front and stands a little proud of it
    head.pair(-13, -11, 5, 6, 0, 2, "black")
    head.beam((-12.9, 4.95, 2.0), (-10.1, 4.95, 2.4), 1.0, 1.5, "grey", mirror=True)
    head.block(-20.3, (1.7, 2.15, 0.0, 0.5), -19.6, (1.7, 2.15, 0.0, 0.5), "black", mirror=True)  # nostrils

    cuts = [-9, -2, 5, 9, 14]
    segs = [m.part(f"S{i + 1}", (cuts[i], 0, 0), "Head" if i == 0 else f"S{i}") for i in range(4)]
    slab(segs[0], -9, -2, 4, -4, 5, -1)
    slab(segs[1], -2, 5, 4, -4, 5, -1)
    slab(segs[2], 5, 9, 3, -3, 4, -1)
    slab(segs[3], 9, 12, 2, -2, 3, -1)
    slab(segs[3], 12, 14, 1, -1, 2, 0)
    for x in (-8, -6):  # gill slits: shallow lines in the side
        segs[0].dent(x, x + 1, 4, -1, 2, "grey-")
    # the seat: behind the gills, in front of the fin, with a slot either side for the rider's legs
    segs[0].dent(-4, -2, 4, 0, 3, "grey-")
    segs[0].sym(-10, -9, 3, -3, 3, "grey-")  # sleeves, one cube into the piece in front
    segs[1].sym(-3, -2, 3, -3, 4, "grey-")
    segs[2].sym(4, 5, 3, -3, 4, "grey-")
    segs[3].sym(8, 9, 2, -2, 3, "grey-")

    # an old scar on the left flank: two short slanting lines, a tone darker (an Epic has one flaw)
    for x, z in ((0, 3), (1, 2), (2, 1), (3, 3), (4, 2)):
        segs[1].paint(x, x + 1, -4, -3, z, z + 1, "grey-")

    # the fins: each a few boxes at an angle, every box smaller and thinner than the one before and starting inside it. The
    # first box of a fin starts deep enough in the body that its whole end is buried: no wedge of air under a leaning fin.
    # The big fins have a darker collar round the root, a little wider and thicker than the fin
    segs[1].beam((-0.05, 0, 3.0), (2.13, 0, 5.74), 5.3, 1.6, "grey-")  # the dorsal's collar
    segs[1].beam((-0.05, 0, 3.0), (3.6, 0, 7.6), 4.8, 1.2, "grey")  # the dorsal: the shark's mark from the riding camera
    segs[1].beam((2.9, 0, 6.8), (5.0, 0, 10.2), 3.3, 0.9, "grey")
    segs[1].beam((4.3, 0, 9.4), (5.7, 0, 11.9), 2.5, 0.6, "black")
    segs[0].beam((-7.2, 3.05, -2.23), (-5.47, 5.23, -2.55), 4.7, 1.4, "grey-", flat="z", mirror=True)  # the side fins' collars
    segs[0].beam((-7.2, 3.05, -2.23), (-3.6, 7.6, -2.9), 4.2, 1.1, "grey", flat="z", mirror=True)  # the side fins
    segs[0].beam((-4.2, 6.8, -2.8), (-1.8, 10.0, -3.3), 3.0, 0.7, "grey", flat="z", mirror=True)
    segs[0].beam((-2.6, 9.0, -3.15), (-0.8, 11.6, -3.55), 2.4, 0.4, "black", flat="z", mirror=True)
    segs[3].beam((9.8, 0, 2.3), (11.4, 0, 4.4), 1.8, 0.9, "grey")  # the second dorsal
    segs[3].beam((10.7, 0, 3.6), (12.0, 0, 5.3), 1.3, 0.6, "black")
    segs[3].beam((9.8, 0, -1.3), (11.4, 0, -3.4), 1.8, 0.9, "white-")  # the anal fin
    segs[3].beam((10.7, 0, -2.6), (12.0, 0, -4.3), 1.3, 0.6, "black")
    segs[2].beam((5.9, 1.4, -2.3), (8.1, 3.4, -4.6), 2.0, 0.6, "white-", flat="z", mirror=True)  # the belly fins

    # the tail, on its own joint: a root block, a long upper lobe in two boxes and a short lower one, black tips
    tail = m.part("Tail", (14, 0, 0), "S4")
    tail.beam((13.6, 0, 0.5), (15.8, 0, 0.5), 2.5, 1.4, "grey")
    tail.beam((14.8, 0, 1.0), (17.8, 0, 5.8), 3.5, 1.1, "grey")
    tail.beam((17.1, 0, 4.9), (20.1, 0, 9.7), 2.7, 0.8, "grey")
    tail.beam((19.3, 0, 8.7), (21.3, 0, 12.0), 2.1, 0.5, "black")
    tail.beam((14.8, 0, -0.1), (17.3, 0, -3.6), 3.1, 0.8, "grey")
    tail.beam((16.6, 0, -2.8), (18.6, 0, -5.8), 2.4, 0.5, "black")
