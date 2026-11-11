"""The Barracuda (zone 4's Uncommon) for tools/blender/voxel_kit.py (docs/style/creature-brief.md).
Its idea: a long silver torpedo with an underbite. Everything is slim and straight but the mouth: the lower jaw juts
out past the snout and carries two fangs that stand in front of it.
- The body is ten slices on six joints (a barracuda swims stiff, from the tail). One number changes from slice to slice
  (width, back or belly), so the back arches a little, the belly dips under the rider and both run out to a thin stock.
- The pattern (an Uncommon has one): a dark blue-grey back, a row of thin dark bars hanging from it onto the silver
  flank, and one thin blue-grey line the whole length of the body, where the silver meets the white belly.
- The head is a short skull and a long wedge: three snout blocks in a chain, each tilted nose-down, lower and narrower,
  over a lower jaw of two boxes that is longer than the snout. A dark mouth between them, a thin gum line, a few long
  teeth. The eye is a dark block under a brow that slants down and comes past it in front.
- Two small back fins far apart, the rider between them; a small fin under each; side fins behind the gills; a forked
  tail on its own joint.
The rider sits where the back is biggest, legs in a slot either side (the slot takes the place of one bar)."""
NAME, ZONE, RARITY = "Barracuda", "ZONE 4 / SHIPWRECKS", "UNCOMMON"
U = 0.4
PALETTE = {"back": "#51697F", "silver": "#BCC8CF", "white": "#ECEFEA", "bar": "#35465A", "black": "#1E2226", "tooth": "#FFFFFF",
           "mouth": "#5E2630", "gum": "#8E4650", "line": "#8496A8"}
SEAT = (3, 4, 3.5)
FRAME, ORTHO = 1.75, 25.0
TEXTURES = [{"tile": "stud", "on": "top", "colours": ["back"]}]

# the body: each slice is (length, cubes out, bottom, top). One number changes from slice to slice, never two
SKULL = (2, -2, 3)
BODY_FROM = -11
SLICES = ((4, 2, -3, 3), (4, 2, -3, 4), (4, 3, -3, 4), (4, 3, -4, 4), (3, 3, -3, 4), (3, 2, -3, 4), (3, 2, -3, 3), (3, 2, -2, 3),
          (2, 1, -2, 3), (2, 1, -2, 2))
GROUPS = ((0, 1), (2,), (3,), (4, 5), (6, 7), (8, 9))  # the slices of each rigid piece
LINE = -1  # the row of the thin line down the body
BARS = (-6, -3, 0, 6, 9)  # the dark bars; the rider's leg slot stands where the one at 3 would be
SWIM = {"chain": ["Head"] + [f"S{i + 1}" for i in range(len(GROUPS))] + ["Tail"],
        "amplitudes": [1, 2, 4, 7, 10, 13, 18], "phaseStep": 0.7, "headCounter": 2}


def slab(p, x0, x1, n, bot, top):
    """a slice of body: one-step corners; the back's colour on the top two rows (lighter on top), silver under it, the
    thin line, a white belly (darker on the bottom row)"""
    p.hull(x0, x1, n, bot, top, "silver", [(1, 1)], [(1, 1)])
    p.paint_sym(x0, x1, n, top - 2, top, "back")
    p.paint_sym(x0, x1, n, top - 1, top, "back+")
    p.paint_sym(x0, x1, n, LINE, LINE + 1, "line")
    p.paint_sym(x0, x1, n, bot, LINE, "white")
    p.paint_sym(x0, x1, n, bot, bot + 1, "white-")


def build(m):
    head = m.part("Head", (BODY_FROM, 0, 0))
    # the skull: a short block with a stepped top. Its underside is left square, so the jaw's root is buried in it
    head.hull(-16, BODY_FROM, 2, -2, 3, "silver", [(1, 1)], [])
    head.paint_sym(-16, BODY_FROM, 2, 1, 3, "back")
    head.paint_sym(-16, BODY_FROM, 2, 2, 3, "back+")
    head.paint_sym(-16, BODY_FROM, 2, -2, -1, "white")
    head.dent(-13, -12, 2, -1, 2, "bar")  # the gill cover's edge

    # the snout: three blocks in a chain, each tilted nose-down, a step lower and narrower than the last and starting
    # inside it. Each is the back's colour over a silver lip; the first two carry a lighter plate on top, narrower, like
    # the body's top row. (from, to, top at its start, top at its end, width, block, lip, plate's width, plate from)
    blocks = ((-14.8, -19.5, 1.95, 1.70, 4.2, 1.0, 1.10, 2.4, -14.8), (-18.8, -22.6, 1.30, 1.10, 3.0, 0.8, 0.65, 1.6, -19.8),
              (-22.0, -24.3, 0.72, 0.60, 2.0, 0.6, 0.25, 0.0, 0.0))

    def top(k, x):
        x0, x1, z0, z1 = blocks[k][:4]
        return z0 + (z1 - z0) * (x - x0) / (x1 - x0)

    def lip_bottom(k, x):
        return top(k, x) - blocks[k][5] - blocks[k][6]

    for k, (x0, x1, z0, z1, wide, thick, lip, plate, plate_from) in enumerate(blocks):
        head.beam((x0, 0, z0 - thick / 2), (x1, 0, z1 - thick / 2), wide, thick, "back", flat="z")
        head.beam((x0, 0, z0 - thick - lip / 2), (x1, 0, z1 - thick - lip / 2), wide - 0.4, lip, "silver", flat="z")
        if plate:
            tall = 0.6 if k == 0 else 0.5
            rise = tall / 2 - 0.05
            head.beam((plate_from, 0, top(k, plate_from) + rise), (x1 + 0.7, 0, top(k, x1 + 0.7) + rise), plate, tall, "back+", flat="z")
            # a thin gum line under the lip, set in from its edge: the teeth hang from it
            head.beam((x0 - 1.0, 0, lip_bottom(k, x0 - 1.0) - 0.05), (x1 + 0.3, 0, lip_bottom(k, x1 + 0.3) - 0.05), wide - 1.0, 0.2, "gum",
                      flat="z")

    # the lower jaw: two boxes, the second slimmer and turned up at the tip, which stands out past the snout. A chin
    # plate under the first. (from, to, middle at its start, at its end, width, thickness)
    jaws = ((-14.6, -20.5, -1.40, -1.65, 3.8, 0.9), (-19.8, -25.4, -1.68, -1.30, 2.6, 0.7))

    def jaw_top(k, x):
        x0, x1, z0, z1, _, thick = jaws[k]
        return z0 + (z1 - z0) * (x - x0) / (x1 - x0) + thick / 2

    for k, (x0, x1, z0, z1, wide, thick) in enumerate(jaws):
        head.beam((x0, 0, z0), (x1, 0, z1), wide, thick, "white", flat="z")
        g0, g1 = x0 - (1.2 if k == 0 else 1.0), x1 + 0.4
        head.beam((g0, 0, jaw_top(k, g0) + 0.05), (g1, 0, jaw_top(k, g1) + 0.05), wide - 0.6, 0.2, "gum", flat="z")
    head.beam((-15.2, 0, -2.05), (-19.4, 0, -2.2), 2.4, 0.5, "white-", flat="z")
    # the dark inside of the mouth: one block that stays behind the teeth and ends inside the lips and the jaw
    head.block(-22.6, (-0.35, 0.35, -1.5, -0.15), -15.5, (-1.2, 1.2, -1.45, 0.25), "mouth")
    # a few long teeth, their bases sunk in the gums: three a side under the snout and a pair at its tip; one a side on
    # the jaw, and the two fangs on its tip, which stand in front of the snout
    for k, x, y, size, length in ((0, -17.6, 1.25, 0.6, 0.7), (1, -20.1, 0.7, 0.55, 0.85), (1, -21.7, 0.7, 0.55, 0.75)):
        head.tooth(x, y, lip_bottom(k, x) - 0.05, size, length, "tooth")
    head.tooth(-23.5, 0.45, lip_bottom(2, -23.5) + 0.1, 0.5, 0.6, "tooth")
    head.tooth(-18.7, 1.25, jaw_top(0, -18.7) + 0.05, 0.55, -0.6, "tooth")
    head.tooth(-24.75, 0.7, jaw_top(1, -24.75) + 0.05, 0.6, -1.05, "tooth")

    # the eye: a dark block on the side of the skull, under a brow box that slants down to the front, cuts the top of
    # its square and comes past it in front
    eye = (2.3, 2.9, -0.3, 1.3)
    head.block(-15.8, eye, -14.2, eye, "black", mirror=True)
    head.beam((-16.7, 2.5, 1.0), (-13.5, 2.5, 1.45), 0.75, 1.2, "back", mirror=True)

    # the body: ten slices in six rigid pieces, each with a sleeve into the piece in front so a bending joint shows body
    spans, x = [], BODY_FROM
    for length, n, bot, top_ in SLICES:
        spans.append((x, x + length, n, bot, top_))
        x += length
    end = x
    segs, of = [], {}
    for g, group in enumerate(GROUPS):
        seg = m.part(f"S{g + 1}", (spans[group[0]][0], 0, 0), "Head" if g == 0 else f"S{g}")
        segs.append(seg)
        for i in group:
            of[i] = seg
            x0, x1, n, bot, top_ = spans[i]
            slab(seg, x0, x1, n, bot, top_)
            for bx in BARS:  # the bars: thin raised strips from the back down onto the silver, a clear row above the line
                if x0 <= bx < x1:
                    bar = (n + 0.2, n + 0.8, top_ - 2.85, top_ - 1.15)
                    seg.block(bx + 0.15, bar, bx + 0.85, bar, "bar", mirror=True)
        x0, _, n, bot, top_ = spans[group[0]]
        fn, fbot, ftop = spans[group[0] - 1][2:5] if g else SKULL
        seg.sym(x0 - 1, x0, min(n, fn) - 1, max(bot, fbot) + 1, min(top_, ftop) - 1, "silver-")
    of[3].dent(2, 4, 3, 0, 3, "back")  # the seat's leg slots

    # the fins: small, each one or two boxes at an angle, the second smaller and thinner and starting inside the first
    of[2].beam((-2.0, 0, 3.3), (-0.6, 0, 5.4), 1.8, 0.9, "back")  # the first back fin, in front of the rider
    of[2].beam((-1.1, 0, 4.7), (-0.1, 0, 6.1), 1.2, 0.6, "bar")
    of[5].beam((9.0, 0, 3.3), (10.4, 0, 5.2), 1.7, 0.8, "back")  # the second, far behind
    of[5].beam((9.9, 0, 4.5), (10.9, 0, 5.8), 1.1, 0.5, "bar")
    of[5].beam((9.0, 0, -2.3), (10.4, 0, -4.2), 1.7, 0.8, "silver")  # the fin under it
    of[5].beam((9.9, 0, -3.5), (10.9, 0, -4.8), 1.1, 0.5, "silver-")
    of[0].beam((-9.6, 1.5, -1.3), (-7.4, 3.6, -1.9), 1.6, 0.5, "silver-", flat="z", mirror=True)  # the side fins
    of[2].beam((-1.6, 0.7, -2.5), (0.2, 1.7, -4.1), 1.3, 0.5, "white-", flat="z", mirror=True)  # the belly fins

    # the tail, on its own joint: a root block and a fork of two lobes, each two boxes with a dark tip. The lower lobe is
    # a little thinner than the upper, so their sides never lie in one plane where they meet
    tail = m.part("Tail", (end, 0, 0), f"S{len(GROUPS)}")
    tail.beam((end - 0.5, 0, 0), (end + 2.4, 0, 0), 2.6, 1.3, "back")
    for s, thick, tip in ((1, 1.0, 0.65), (-1, 0.7, 0.4)):
        tail.beam((end + 1.1, 0, 0.6 * s), (end + 3.0, 0, 3.7 * s), 2.3, thick, "back")
        tail.beam((end + 2.5, 0, 3.0 * s), (end + 3.8, 0, 5.2 * s), 1.6, tip, "bar")
