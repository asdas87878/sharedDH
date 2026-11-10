"""The rarity ladder (docs/style/05-rarity-look.md): ONE invented reef fish dressed at each of the six tiers, for
tools/blender/voxel_kit.py. Set TIER (1 Common to 6 Mythic); tools/art/rarity_ladder.py builds all six and lays them out.

The base body is the same cubes at every tier. Each tier spends its allowance on top of the tier below:
  1 Common     two colours, body and fins. Nothing else.
  2 Uncommon   a third colour; one mark (a tall crest with a coloured tip); one simple pattern (two pale bands).
  3 Rare       a second mark (long tail tips); a third band; coloured tips on every fin; the jaw on its own joint.
  4 Epic       darker, sharper colours; a weapon at one end (a bill); scattered thin stripes in place of the bands; a
               glowing eye under a brow; teeth; the side fins on their own joints.
  5 Legendary  a signature colour (amber) that glows: a ribbon along each side, a lure, the eye, the tips. The outline
               broken all along: a bone helmet, a row of back plates, cheek spikes. Tail streamers on their own joints.
  6 Mythic     a near-black body and two glowing colours (amber and a cool cyan): the stripes glow. Impossible parts: a
               crown of shards floating round the lure, fins as wide as wings, a split jaw, trailing whiskers, a glowing
               shard out of every back plate, lanterns on the streamers.
It grows with its tier through U, the size of a cube: about 11, 13, 15, 19, 25 and 31 studs long."""
TIER = 1  # 1 Common, 2 Uncommon, 3 Rare, 4 Epic, 5 Legendary, 6 Mythic

T = TIER - 1
RARITY = ("COMMON", "UNCOMMON", "RARE", "EPIC", "LEGENDARY", "MYTHIC")[T]
NAME, ZONE = "Ladder fish", "RARITY LADDER"
U = (0.36, 0.425, 0.455, 0.47, 0.585, 0.72)[T]
LENGTH = (11, 13, 15, 19, 25, 31)[T]
FRAME, ORTHO = LENGTH / 12 * 1.12, LENGTH * 1.3
PALETTE = {"body": ("#6FA8C8", "#62A0C8", "#4A8CBC", "#2C5F93", "#1E3E6B", "#141B33")[T],
           "belly": ("#EAF0F2", "#EAF0F2", "#E6EEF1", "#DDE7EC", "#CBD7DE", "#3A4763")[T],
           "white": "#FFFFFF", "black": "#2B2D33", "mouth": "#3A1420", "tooth": "#FFFFFF"}
if TIER >= 2:
    PALETTE["accent"] = ("", "#F4B24A", "#F4B24A", "#FF9A2E", "#FFB21E", "#FF8A1E")[T]  # fin tips
    PALETTE["stripe"] = PALETTE["belly"] if TIER < 6 else "#5FE8FF"  # bands, then scattered stripes
if TIER >= 4:
    PALETTE["eye"] = ("", "", "", "#FFD23E", "#FFB21E", "#5FE8FF")[T]
    GLOW = {"eye": 1.0}
if TIER >= 5:
    PALETTE["sig"] = "#FFB21E" if TIER == 5 else "#FF8A1E"  # the signature colour: ribbons, the lure, the streamers
    PALETTE["bone"] = "#D9CDB0" if TIER == 5 else "#2A3350"  # armour: bone on the Legendary, dark rock on the Mythic
    GLOW = {"eye": 1.0, "sig": 0.85, "accent": 0.5}
if TIER >= 6:
    PALETTE["cool"] = "#5FE8FF"
    GLOW = {"eye": 1.0, "sig": 0.9, "accent": 0.6, "cool": 1.0, "stripe": 0.9}
    FLOATING = ["Crown"]
    LIGHTS = [("Head", (-9.5, 0, 9.0), "#FF9A2E", 90, 0.6), ("S1", (-3, 7.5, 0.6), "#5FE8FF", 40, 0.6),
              ("S2", (3, 7.5, 0.6), "#5FE8FF", 40, 0.6)]
SEAT = (-0.5, 7, 5.6)
SWIM = {"chain": ["Head", "S1", "S2", "S3", "S4", "Tail"], "amplitudes": [3, 6, 9, 12, 18], "phaseStep": 0.9, "headCounter": 2}
PROUD = 0.3  # how far a band or a stripe stands off the body, in cubes


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
    """a length of body with stepped corners: lighter on the top row, a pale belly, its steps darker"""
    steps_top, steps_bottom = steps(n)
    p.hull(x0, x1, n, bot, top, "body", steps_top, steps_bottom)
    p.paint_sym(x0, x1, n, bot, bot + max(1, round((top - bot) * 0.3)), "belly")
    p.paint_sym(x0, x1, n, bot, bot + sum(t for _, t in steps_bottom), "belly-")
    if steps_top:
        p.paint_sym(x0, x1, n, top - 1, top, "body+")


def stripe(p, x0, x1, n, bot, top, stop, colour="stripe"):
    """a band of colour over the back from x0 to x1, a third of a cube proud, stopping at height `stop`"""
    steps_top, steps_bottom = steps(n)
    p.band(x0, x1, n, bot, top, colour, steps_top, steps_bottom, PROUD, stop=stop)


def build(m):
    head = m.part("Head", (-5, 0, 0))
    slab(head, -9, -5, 4, -5, 6)
    # the face: a muzzle box, a lighter slab leaning down it for the forehead, a pale lip block
    muzzle = (-3.2, 3.2, -2.8, 2.7)
    head.block(-11.0, muzzle, -8.8, muzzle, "body")
    head.beam((-8.397, 0, 4.216), (-10.95, 0, 2.074), 6.7, 1.7, "body+", flat="z")
    lip = (-1.5, 1.5, -1.3, -0.1)
    head.block(-11.9, lip, -10.9, lip, "belly")
    # the jaw: shut and part of the head on the plain tiers; on its own joint from Rare; open, with teeth, from Epic;
    # split in two on the Mythic
    if TIER <= 3:
        jaw_part = head if TIER <= 2 else m.part("Jaw", (-8.9, 0, -3.3), "Head")
        jaw = (-2.3, 2.3, -3.9, -2.7)
        jaw_part.block(-10.4, jaw, -8.9, jaw, "belly-")
    else:
        mouth = (-1.6, 1.6, -3.5, -2.7)
        head.block(-10.4, mouth, -8.9, mouth, "mouth")
        for x in (-10.5, -9.7):
            head.tooth(x, 2.6, -2.7, 0.55, 0.5, "tooth")
        halves = (("Jaw", -2.3, 2.3),) if TIER <= 5 else (("JawR", 0.3, 2.3), ("JawL", -2.3, -0.3))
        for name, ya, yb in halves:
            jaw_part = m.part(name, (-8.9, 0, -4.0), "Head")
            jaw = (ya, yb, -4.6, -3.4)
            jaw_part.block(-10.6, jaw, -8.9, jaw, "belly-")
            for x in (-10.1, -9.3):
                for y in (2.0, -2.0):
                    if ya < y < yb:
                        jaw_part.tooth(x, y, -3.5, 0.5, -0.4, "tooth", mirror=False)
    # the eye: a white frame one cube proud, a dark pupil low and forward. From Epic the pupil glows under a brow box
    head.pair(-9, -6, 5, 6, 1, 4, "white")
    head.paint_pair(-9, -7, 5, 6, 1, 3, "black" if TIER < 4 else "eye")
    if TIER >= 4:
        head.beam((-8.9, 4.95, 3.2), (-6.2, 4.95, 3.45), 1.0, 1.5, "body", mirror=True)
        # the weapon: a bill out of the muzzle, two boxes and a point
        head.beam((-10.4, 0, 0.9), (-14.6, 0, 0.5), 2.6, 1.4, "body", flat="z")
        head.beam((-14.0, 0, 0.56), (-17.6, 0, 0.25), 1.8, 1.0, "belly", flat="z")
        head.spike([(-17.2, -0.7, -0.05), (-17.2, 0.7, -0.05), (-17.2, 0.7, 0.6), (-17.2, -0.7, 0.6)], (-19.8, 0.0, 0.15), "belly+")
    if TIER >= 5:
        # armour: a helmet over the top of the head, and a spike on each cheek
        stripe(head, -8.6, -5.4, 4, -5, 6, 4.3, "bone")
        head.spike([(-7.6, 4.3, -1.6), (-6.2, 4.3, -1.6), (-6.2, 4.3, -0.4), (-7.6, 4.3, -0.4)], (-5.6, 6.6, -1.4), "bone", mirror=True)
        # the lure: a rod off the top of the head with a glowing bulb
        head.beam((-7.4, 0, 5.4), (-9.4, 0, 8.8), 0.8, 0.8, "body-")
        bulb = (-0.65, 0.65, 8.3, 9.6)
        head.block(-10.1, bulb, -8.9, bulb, "sig")
    if TIER >= 6:
        # a crown of shards floating round the lure: dark rock, each with a glowing point
        crown = m.part("Crown", (-9.5, 0, 10.5), "Head")
        for cx, cy, z0, size, tall, both in ((-13.4, 0.0, 9.4, 1.5, 2.6, False), (-5.6, 0.0, 10.0, 1.8, 3.2, False),
                                             (-11.6, 3.4, 10.3, 1.3, 2.2, True), (-7.6, 3.6, 9.6, 1.6, 2.8, True)):
            h, top = size / 2, z0 + size * 1.2
            section = (cy - h, cy + h, z0, top)
            crown.block(cx - h, section, cx + h, section, "bone", mirror=both)
            k = h - 0.15
            crown.spike([(cx - k, cy - k, top - 0.1), (cx + k, cy - k, top - 0.1), (cx + k, cy + k, top - 0.1), (cx - k, cy + k, top - 0.1)],
                        (cx, cy, top + tall), "cool", mirror=both)
        # whiskers trailing from under the head: two boxes each, the second glowing
        whiskers = m.part("Whiskers", (-8.2, 0, -4.4), "Head")
        whiskers.beam((-8.2, 1.9, -4.4), (-5.4, 2.6, -7.0), 0.8, 0.8, "body-", mirror=True)
        whiskers.beam((-5.9, 2.48, -6.54), (-2.4, 3.2, -8.4), 0.5, 0.5, "cool", mirror=True)

    cuts = [-5, 1, 6, 10, 12]
    segs = [m.part(f"S{i + 1}", (cuts[i], 0, 0), "Head" if i == 0 else f"S{i}") for i in range(4)]
    slab(segs[0], -5, 1, 5, -6, 7)
    slab(segs[1], 1, 6, 5, -6, 7)
    slab(segs[2], 6, 7, 5, -6, 7)
    slab(segs[2], 7, 9, 4, -4, 5)
    slab(segs[2], 9, 10, 3, -3, 4)
    slab(segs[3], 10, 12, 2, -2, 3)
    segs[0].sym(-6, -5, 3, -3, 4, "body-")  # sleeves, one cube into the piece in front
    segs[1].sym(0, 1, 3, -4, 5, "body-")
    segs[2].sym(5, 6, 3, -4, 5, "body-")
    segs[3].sym(9, 10, 2, -2, 3, "body-")
    segs[0].dent(-2, 1, 5, 1, 4, "body-")  # the seat: a shallow slot either side for the rider's legs

    # the pattern: two pale bands (Uncommon), three (Rare), then thin stripes scattered at uneven lengths (Epic up)
    if TIER in (2, 3):
        stripe(segs[0], -3.9, -2.55, 5, -6, 7, -1.7)
        stripe(segs[1], 2.55, 3.9, 5, -6, 7, -1.7)
    if TIER == 3:
        stripe(segs[2], 7.3, 8.6, 4, -4, 5, -0.7)
    if TIER >= 4:
        for x, stop in ((-4.6, -1.7), (-3.7, 1.4), (-2.9, -0.5)):
            stripe(segs[0], x, x + 0.5, 5, -6, 7, stop)
        for x, stop in ((1.3, 1.6), (2.2, -1.7), (3.0, 2.3), (3.9, -0.7), (4.8, 1.5)):
            stripe(segs[1], x, x + 0.5, 5, -6, 7, stop)
        stripe(segs[2], 6.35, 6.65, 5, -6, 7, -1.7)
        for x, stop in ((7.4, -0.6), (8.2, 1.3)):
            stripe(segs[2], x, x + 0.5, 4, -4, 5, stop)
    if TIER >= 5:
        # the signature ribbon: one glowing line along each side, half a cube proud so it rides over the stripes
        for p, x0, x1, half in ((segs[0], -4.85, 0.85, 5.5), (segs[1], 1.15, 5.85, 5.5), (segs[2], 6.15, 6.85, 5.5), (segs[2], 7.15, 8.85, 4.5),
                                (segs[2], 9.15, 9.85, 3.5), (segs[3], 10.15, 11.85, 2.5)):
            ribbon = (half - 0.05, half + 0.5, 0.2, 0.8)
            p.block(x0, ribbon, x1, ribbon, "sig", mirror=True)
        # a row of armour plates down the back
        for p, (ax, az), (bx, bz), wide, thick in ((segs[0], (-4.0, 6.2), (-3.5, 8.6), 1.8, 0.9), (segs[2], (7.6, 4.2), (8.2, 6.6), 1.8, 0.9),
                                                   (segs[2], (9.35, 3.3), (9.8, 5.0), 1.2, 0.9), (segs[3], (10.9, 2.3), (11.3, 3.9), 1.1, 0.8)):
            p.beam((ax, 0, az), (bx, 0, bz), wide, thick, "bone")
            if TIER >= 6:  # a glowing shard out of each plate
                dx, dz = bx - ax, bz - az
                p.beam((ax + 0.7 * dx, 0, az + 0.7 * dz), (ax + 1.7 * dx, 0, az + 1.7 * dz), wide * 0.6, thick - 0.4, "cool")

    # the back fin: a low lobe on the Common; from Uncommon a tall crest with a coloured tip
    if TIER == 1:
        segs[1].beam((3.2, 0, 6.3), (4.2, 0, 9.6), 3.6, 1.2, "body-")
    else:
        segs[1].beam((3.2, 0, 6.3), (4.6, 0, 11.4), 3.6, 1.2, "body-")
        segs[1].beam((4.2, 0, 10.2), (5.0, 0, 13.2), 2.6, 0.9, "accent")
    # the fin underneath, and the small belly fins
    segs[1].beam((4.2, 0, -5.4), (5.2, 0, -8.4), 2.8, 1.2, "body-")
    if TIER >= 3:
        segs[1].beam((4.85, 0, -7.6), (5.35, 0, -9.4), 2.0, 0.9, "accent")
    segs[0].beam((-3.0, 2.0, -5.3), (-1.6, 2.4, -8.0), 1.6, 0.8, "body-", mirror=True)
    # the side fins: a paddle each; on their own joints from Epic; as wide as wings on the Mythic
    for sign, name in ((1, "FinR"), (-1, "FinL")):
        fin = segs[0] if TIER <= 3 else m.part(name, (-1.2, sign * 5.0, -1.2), "S1")
        if TIER <= 5:
            fin.beam((-1.2, sign * 5.0, -1.2), (1.8, sign * 7.4, -2.2), 2.8, 0.9, "body-")
            if TIER >= 3:
                fin.beam((1.1, sign * 6.85, -1.97), (2.5, sign * 7.95, -2.43), 2.2, 0.5, "accent")
        else:
            fin.beam((-2.2, sign * 4.0, -0.9), (1.0, sign * 8.6, 1.3), 5.2, 1.1, "body-", flat="z")
            fin.beam((0.2, sign * 7.45, 0.75), (3.2, sign * 12.4, 4.0), 3.8, 0.8, "body-", flat="z")
            fin.beam((2.45, sign * 11.16, 3.19), (4.9, sign * 15.6, 6.4), 2.4, 0.5, "cool", flat="z")

    # the tail, on its own joint: a stock that starts inside the body and two lobes; coloured tips from Rare; glowing
    # streamers on their own joints from Legendary
    tail = m.part("Tail", (12, 0, 0), "S4")
    tail.beam((11.6, 0, 0.5), (15.2, 0, 0.5), 4.5, 2.0, "body")
    tail.beam((13.3, 0, 1.1), (17.3, 0, 5.1), 4.0, 1.2, "body-")
    tail.beam((13.3, 0, -0.1), (17.3, 0, -4.1), 4.0, 0.9, "body-")
    if TIER >= 3:
        tail.beam((16.4, 0, 4.2), (19.4, 0, 7.6), 3.0, 0.9, "accent")
        tail.beam((16.4, 0, -3.2), (19.4, 0, -6.6), 3.0, 0.6, "accent")
    if TIER >= 5:
        upper = m.part("StreamU", (18.8, 0, 6.9), "Tail")
        upper.beam((18.8, 0, 6.9), (22.8, 0, 9.3), 1.4, 0.6, "sig")
        lower = m.part("StreamL", (18.8, 0, -5.9), "Tail")
        lower.beam((18.8, 0, -5.9), (22.8, 0, -8.3), 1.4, 0.3, "sig")
        if TIER >= 6:  # a glowing knob on the end of each, swallowing it
            knob = (-0.55, 0.55, 8.5, 10.3)
            upper.block(22.2, knob, 24.0, knob, "cool")
            knob = (-0.55, 0.55, -9.3, -7.5)
            lower.block(22.2, knob, 24.0, knob, "cool")
