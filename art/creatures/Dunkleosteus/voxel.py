"""Dunkleosteus (zone 2's Legendary: the armoured prehistoric fish with blade jaws) for tools/blender/voxel_kit.py
(docs/style/04-voxel-style.md), dressed as a Legendary by docs/style/05-rarity-look.md.
Its idea: an armoured relic. The bone of its skull runs on down its spine in plates, and an old amber light shows in the
seams of the armour.
- The back shield is a stepped bone slab. The skull is two big blocks in a chain, each tilted nose-down and a step lower
  and narrower, each with a lighter roof plate. A heavy brow box slants over a ringed, glowing amber eye. A darker cheek
  plate hangs either side of the mouth, and a bone spike points back from each corner of the shield.
- The jaw is its own part and chomps: two boxes, tucked between the cheek plates. The blades are pyramids.
- The body is six short slices, so it bends smoothly. Each carries a bone plate over its back with a low spike on it, and
  a thin line of amber light in the seam behind the plate. The last slice wears a bone ring: the head's echo at the tail.
- The side fins have a bone spar along the leading edge, ending in a claw. The eel tail's boxes turn upward one by one.
- Old scars cross the shield (its flaw). The flank is left plain.
The rider sits on the shield, legs in a slot each side."""
import math

NAME, ZONE, RARITY = "Dunkleosteus", "ZONE 2 / CORAL REEF", "LEGENDARY"
U = 0.54
PALETTE = {"bone": "#C9B994", "body": "#56788A", "belly": "#B4C4C0", "blade": "#F1EAD6", "black": "#2B2B2E", "mouth": "#4A1F24",
           "amber": "#FFB23E", "soft": "#F2A93F", "iris": "#C98A2E"}
SEAT = (-9, 7, 6.5)
EYE = "halo"  # the eye (docs/style/05-rarity-look.md): "full", "ring", "halo", "slit", "gradient" or "matte"
GLOW = {"amber": 0.9, "soft": 0.4}  # amber: the seams, and a full glowing eye; soft: a faint glow, for part of an eye
LIGHTS = [("Head", (-16.4, 7.2, 1.9), "#FFB23E", 45, 0.5)] if EYE == "full" else []  # only a full glowing eye casts light
FRAME, ORTHO = 2.15, 31.5
CHAIN = ["Head", "S1", "S2", "S3", "S4", "S5", "S6", "Tail"]
AMPLITUDES = [2, 4, 6, 8, 10, 13, 17]


def pose(parts, phase):
    """the fish swim down the chain, and the jaw opens and shuts once a beat"""
    parts["Head"].rotation_euler.z = math.radians(1.5) * math.sin(phase + math.pi)
    for k, name in enumerate(CHAIN[1:]):
        parts[name].rotation_euler.z = math.radians(AMPLITUDES[k]) * math.sin(phase - 0.8 * (k + 1))
    parts["Jaw"].rotation_euler.y = -math.radians(9) * (0.5 + 0.5 * math.sin(phase))


def steps_for(n):
    return [(2, 1), (1, 1)] if n >= 4 else ([(1, 1)] if n >= 2 else [])


def slab(p, x0, x1, n, bot, top):
    """a length of body: stepped corners, lighter on top, the shoulder step darker, a pale belly"""
    steps = steps_for(n)
    p.hull(x0, x1, n, bot, top, "body", steps, steps)
    if steps:
        p.paint_sym(x0, x1, n, top - len(steps), top - 1, "body-")
    p.paint_sym(x0, x1, n, top - 1, top, "body+")
    p.paint_sym(x0, x1, n, bot, bot + max(2, (top - bot) // 3), "belly")
    p.paint_sym(x0, x1, n, bot, bot + len(steps), "belly-")


def build(m):
    head = m.part("Head", (-8, 0, 0))
    # the back shield: a stepped bone slab, proud of the body behind, with a low crest and a darker seam at its front
    head.hull(-14, -8, 6, -6, 7, "bone", [(3, 1), (1, 2)], [(3, 1), (1, 2)])
    head.paint_sym(-14, -8, 6, -6, -3, "bone-")
    head.paint_sym(-14, -8, 6, 6, 7, "bone+")
    head.paint_sym(-14, -13, 6, -6, 7, "bone-")
    head.sym(-13, -9, 1, 7, 8, "bone")
    # the skull: two big blocks in a chain, each tilted nose-down and a step lower and narrower, each with a lighter roof
    # plate on top (the second plate starts past the end of the first block)
    for x0, x1, z0, z1, wide, thick, plate, plate_from in ((-13.4, -18.2, 1.9, 1.2, 10.6, 7.8, 6.6, -13.4),
                                                           (-17.4, -21.4, 0.6, -0.2, 8.0, 5.6, 4.6, -18.5)):
        head.beam((x0, 0, z0), (x1, 0, z1), wide, thick, "bone", flat="z")

        def top(x):
            return z0 + (z1 - z0) * (x - x0) / (x1 - x0) + thick / 2 + 0.2

        head.beam((plate_from, 0, top(plate_from)), (x1 + 0.6, 0, top(x1 + 0.6)), plate, 0.5, "bone+", flat="z")
    # a darker cheek plate hanging either side of the mouth
    cheek = (3.9, 5.1, -4.4, -1.6)
    head.block(-17.8, cheek, -13.6, cheek, "bone-", mirror=True)
    # the dark inside of the mouth: a block behind the blades, between the cheeks, ending inside the skull and the jaw
    mouth = (-3.0, 3.0, -4.6, -1.8)
    head.block(-19.8, mouth, -13.6, mouth, "mouth")
    # the upper blades: two fangs at the front, hanging forward of the lower jaw
    head.spike([(-20.6, 1.3, -2.4), (-18.6, 1.3, -2.4), (-18.6, 3.6, -2.4), (-20.6, 3.6, -2.4)], (-21.3, 2.4, -5.8), "blade", mirror=True)
    # the eye, under a heavy brow that slants down to the front. How much of it glows is a choice (EYE): a Legendary's
    # eye should keep its dark pupil, so it still reads as an eye
    ring = (5.2, 5.75, 0.4, 3.4)
    pupil = (5.6, 6.0, 1.1, 2.7)

    def eye(section, colour, x0=-17.0, x1=-15.8):
        head.block(x0, section, x1, section, colour, mirror=True)

    if EYE == "full":  # the whole pupil glows: for a few Mythics. It hides the eye's shape and casts light
        eye(ring, "blade", -17.6, -15.2)
        eye(pupil, "amber")
    elif EYE == "ring":  # the ring round the eye glows softly; the pupil stays dark
        eye(ring, "soft", -17.6, -15.2)
        eye(pupil, "black")
    elif EYE == "halo":  # a thin line of soft light round a dark pupil, in a pale ring: the glow leaves room for the eye
        eye(ring, "blade", -17.6, -15.2)
        eye((5.6, 5.88, 0.85, 2.95), "soft", -17.25, -15.55)
        eye((5.7, 6.05, 1.1, 2.7), "black")
    elif EYE == "slit":  # a dark eye with one narrow slit of light in it
        eye(ring, "blade", -17.6, -15.2)
        eye(pupil, "black")
        eye((5.9, 6.15, 1.35, 2.45), "amber", -16.55, -16.25)
    elif EYE == "gradient":  # dark at the top, a matte amber iris, and only the lowest band glowing
        eye(ring, "blade", -17.6, -15.2)
        eye((5.6, 6.0, 2.2, 2.7), "black")
        eye((5.6, 6.0, 1.65, 2.2), "iris")
        eye((5.6, 6.0, 1.1, 1.65), "soft")
    else:  # "matte": colour without light: an amber iris that doesn't glow, and a dark pupil standing out of it
        eye(ring, "blade", -17.6, -15.2)
        eye(pupil, "iris")
        eye((5.9, 6.15, 1.5, 2.3), "black", -16.7, -16.1)
    head.beam((-18.0, 5.55, 3.2), (-14.0, 5.55, 4.6), 1.6, 1.5, "bone", mirror=True)
    # a bone spike pointing back and out from each lower corner of the shield
    head.spike([(-9.4, 6.35, -2.4), (-8.1, 6.35, -2.4), (-8.1, 6.35, -0.8), (-9.4, 6.35, -0.8)], (-5.6, 9.2, -1.4), "bone+", mirror=True)
    # old scars across the shield's left side: two slashes, cut shallow so they read as lines, not missing blocks
    for x, z in ((-13, 3), (-12, 2), (-11, 1), (-13, 0), (-12, -1), (-11, -2)):
        head.dent(x, x + 1, -6, z, z + 1, "bone-", pair=False)
    # the seat on the shield: a slot either side for the rider's legs
    head.dent(-10, -8, 6, 1, 4, "bone-")

    # the jaw, on its own joint: two boxes, the smaller in front, tucked between the cheek plates, a darker chin plate
    jaw = m.part("Jaw", (-13, 0, -4), "Head")
    jaw.beam((-13.8, 0, -5.1), (-18.4, 0, -5.1), 6.6, 1.6, "bone", flat="z")
    jaw.beam((-17.8, 0, -4.95), (-20.0, 0, -4.82), 5.4, 1.2, "bone", flat="z")
    jaw.beam((-14.4, 0, -6.0), (-17.6, 0, -6.0), 4.6, 0.5, "bone-", flat="z")
    # the lower blades: one cusp that closes between the two fangs, and a small one each side behind it
    jaw.spike([(-19.8, -1.0, -4.45), (-18.3, -1.0, -4.45), (-18.3, 1.0, -4.45), (-19.8, 1.0, -4.45)], (-19.6, 0.0, -2.2), "blade")
    jaw.spike([(-18.6, 1.9, -4.45), (-17.2, 1.9, -4.45), (-17.2, 2.9, -4.45), (-18.6, 2.9, -4.45)], (-18.0, 2.4, -3.2), "blade", mirror=True)

    # the body: six short slices (a long creature bends better in more pieces), tapering to the tail
    slices = ((-8, -3, 5, -5, 6), (-3, 2, 5, -5, 6), (2, 6, 4, -4, 5), (6, 10, 4, -4, 5), (10, 14, 3, -3, 4), (14, 18, 2, -2, 3))
    segs = [m.part(f"S{i + 1}", (sl[0], 0, 0), "Head" if i == 0 else f"S{i}") for i, sl in enumerate(slices)]
    for i, (seg, (x0, x1, n, bot, top)) in enumerate(zip(segs, slices)):
        slab(seg, x0, x1, n, bot, top)
        seg.sym(x0 - 1, x0, max(n - 2, 0), bot + 2, top - 2, "body-")  # a sleeve into the piece in front, clear of its steps
        st = steps_for(n)
        last = i == len(slices) - 1
        # the armour: a bone plate over the back of each slice, half a cube proud (the last slice wears a whole ring),
        # and a thin line of amber light in the seam behind it
        a, b = x0 + 0.6, x1 - 1.1
        if last:
            a, b = x0 + 0.8, x0 + 2.4
        seg.band(a, b, n, bot, top, "bone", st, st, 0.5, stop=None if last else top - 3.5)
        seg.band(b, b + 0.35, n, bot, top, "amber", st, st, 0.18, stop=None if last else top - 3.2)
        if i not in (2, 5):  # a low spike on the plate, leaning back (the third slice carries the back fin instead)
            mid, half = (a + b) / 2, (0.9 if n >= 4 else 0.7)
            seg.spike([(mid - half, -0.7, top + 0.35), (mid + half, -0.7, top + 0.35), (mid + half, 0.7, top + 0.35), (mid - half, 0.7, top + 0.35)],
                      (mid + 1.0, 0.0, top + 2.3 * half / 0.9), "bone+")
    # light leaking from under the shield: a thin amber line where the first slice meets it
    st = steps_for(5)
    segs[0].band(-7.95, -7.6, 5, -5, 6, "amber", st, st, 0.18, stop=2.8)

    # the back fin, on the third slice, coming up through its plate: two boxes
    segs[2].beam((3.0, 0, 3.6), (4.8, 0, 7.6), 3.2, 1.2, "body-")
    segs[2].beam((4.2, 0, 6.6), (5.6, 0, 9.0), 2.2, 0.9, "body")
    # the side fins: two boxes swept back, with a bone spar along the leading edge that ends in a claw
    segs[0].beam((-6.4, 3.9, -2.3), (-2.9, 8.4, -3.05), 4.2, 1.0, "body", flat="z", mirror=True)
    segs[0].beam((-7.9, 5.0, -2.3), (-4.855, 8.915, -2.95), 1.0, 1.7, "bone-", flat="z", mirror=True)
    segs[0].beam((-5.3, 8.35, -2.89), (-3.7, 10.4, -3.2), 0.7, 1.28, "blade", flat="z", mirror=True)
    segs[0].beam((-3.7, 7.5, -2.9), (-1.3, 10.2, -3.4), 3.0, 0.7, "body-", flat="z", mirror=True)
    segs[3].beam((7.0, 1.4, -3.2), (9.4, 2.6, -5.6), 2.0, 0.7, "body-", flat="z", mirror=True)  # the belly fins

    # the tail, on its own joint: long and eel-like, a chain of boxes that turns upward box by box, with a low lobe
    # underneath
    tail = m.part("Tail", (18, 0, 0), "S6")
    tail.beam((17.6, 0, 0.5), (20.6, 0, 0.9), 3.4, 1.6, "body")
    tail.beam((19.8, 0, 0.9), (23.0, 0, 3.4), 3.0, 1.3, "body")
    tail.beam((22.2, 0, 2.8), (24.8, 0, 6.6), 2.6, 1.0, "body-")
    tail.beam((24.2, 0, 5.8), (25.6, 0, 9.0), 2.0, 0.7, "body-")
    tail.beam((19.4, 0, 0.3), (22.4, 0, -1.6), 2.4, 1.0, "body-")
