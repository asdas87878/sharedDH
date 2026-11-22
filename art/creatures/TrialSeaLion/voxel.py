"""The Sea Lion, a trial of docs/style/09-early-remodels.md, for tools/blender/voxel_kit.py. It stands beside the game's
Sea Lion (art/creatures/SeaLion) and replaces nothing. Designed from the real animal, a California sea lion.
Its idea: the acrobat. Chest up and head lifted in one arc.
- The body idea in numbers: about 40 cubes long; the chest is the deepest and lowest part, 12 cubes (0.3 of the length),
  a third of the way back. In front of it a thick neck rises steeply in two turned slices to a head held up, the nose
  well above the back's line; behind it the body tapers and lifts in three turned slices to the rear flippers, held
  together and fanned like a tail.
- The face: a dog's head. A rounded skull, a muzzle one step narrower that tapers, a big dark nose block at its tip, a
  cream whisker pad with three dark dots a side, a mouth line that turns up at its corner. Big glossy eyes, 3 by 3, dark
  with one white block of shine. A small ear flap behind each eye.
- Caramel gold with a cream bib: from the chin down the throat and the chest to the belly, widest at the chest. The
  bib's edge is the colour line.
- The one mark: all four flippers in chocolate.
The rider sits on the chest's back behind the neck, legs in a slot either side."""
import math

NAME, ZONE, RARITY = "Sea Lion (trial)", "ZONE 3 / KELP FOREST", "UNCOMMON"
U = 0.4
PALETTE = {"gold": "#D9953B", "cream": "#F6E7C6", "choc": "#6B4630", "nose": "#2E2420", "black": "#161212",
           "white": "#FFFFFF"}
SHADE = 0.9
SEAT = (-3, 5, 5)
FRAME, ORTHO = 1.5, 22.0
TEXTURES = [{"tile": "stud", "on": "top", "colours": ["gold"]}]

# the chest, the root: grid slices (from, to, cubes out, bottom, top)
CHEST = ((-14, -13, 4, -4, 3), (-13, -10, 5, -6, 5), (-10, -5, 5, -7, 5), (-5, -2, 5, -6, 5))
# the bib's edge on the chest: cream below this height at each x (it climbs to the front, widest at the chest)
BIB = dict(zip(range(-14, -2), (4, 3, 2, 1, 1, 0, 0, -1, -1, -2, -2, -3)))
# the turned slices: (name, parent, start (x, z), degrees up from level toward the front (+) or the back (-), length,
# half depth of the core, half width of the core, how deep the cream runs up the throat or belly from the core's bottom)
NECK = (("Neck1", "Chest", (-8.5, -0.5), 58, 6.6, 4.0, 4.0, 3.0),
        ("Neck2", "Neck1", None, 72, 5.4, 3.3, 3.2, 2.2))
HIND = (("Hind1", "Chest", (-3.0, -0.5), 8, 7.0, 4.0, 4.8, 2.0),
        ("Hind2", "Hind1", None, 16, 6.0, 3.0, 3.6, 0.0),
        ("Hind3", "Hind2", None, 25, 4.6, 2.0, 2.4, 0.0))
CHAIN_F = ["Neck1", "Neck2", "Head"]
CHAIN_B = ["Hind1", "Hind2", "Hind3", "Rear"]
AMP_B = [3, 5, 8, 16]


def pose(parts, phase):
    """a sea lion's swim: a wave runs from the chest back to the rear flippers, growing; the neck and head ride against it,
    and the long front flippers row"""
    for k, name in enumerate(CHAIN_B):
        parts[name].rotation_euler.y = math.radians(AMP_B[k]) * math.sin(phase - 0.6 * (k + 1))
    for k, name in enumerate(CHAIN_F):
        parts[name].rotation_euler.y = math.radians(2.0) * math.sin(phase + math.pi - 0.4 * k)
    for name, side in (("FlipperR", 1), ("FlipperL", -1)):
        parts[name].rotation_euler.x = side * math.radians(14) * math.sin(phase - 0.8)
        parts[name].rotation_euler.z = side * math.radians(10) * math.sin(phase - 1.8)


def steps(n):
    return [(2, 1), (1, 1)] if n >= 4 else [(1, 1)]


def turned(part, a, deg, length, d, h, cream, back):
    """a slice of body turned in the side view: a core box from a, `length` long at `deg`, 2d deep and 2h wide, with a
    narrower plate on its top and under its bottom (one cube proud, one cube in from each side, set back 0.3 at each end)
    so its corners step like the grid's. Cream from its bottom up `cream` cubes (the bib). back: the slice runs to +x.
    Returns its end point"""
    rad = math.radians(deg)
    ux, uz = (math.cos(rad), math.sin(rad)) if back else (-math.cos(rad), math.sin(rad))
    px, pz = (-uz, ux) if back else (uz, -ux)  # the perpendicular that points up (to the back or the top)
    if pz < 0:
        px, pz = -px, -pz
    b = (a[0] + ux * length, a[1] + uz * length)

    def at(p, off, inset=0.0):
        return (p[0] + px * off + ux * inset, 0, p[1] + pz * off + uz * inset)

    def run(lo, hi, wide, colour, inset=0.0):
        mid = (lo + hi) / 2
        part.beam(at(a, mid, inset), at(b, mid, -inset), hi - lo, wide, colour, flat="y")

    if cream > 0:
        run(-d, -d + cream, 2 * h, "cream")
        run(-d + cream, d, 2 * h, "gold")
        run(-d - 1, -d + 1, 2 * h - 2, "cream", 0.3)
    else:
        run(-d, d, 2 * h, "gold")
        run(-d - 1, -d + 1, 2 * h - 2, "gold", 0.3)
    run(d - 1, d + 1, 2 * h - 2, "gold+", 0.3)
    return b


def build(m):
    chest = m.part("Chest", (-6, 0, 0))
    for x0, x1, n, bot, top in CHEST:
        chest.hull(x0, x1, n, bot, top, "gold", steps(n), steps(n))
        chest.paint_sym(x0, x1, n, top - 1, top, "gold+")
        for x in range(x0, x1):
            chest.paint_sym(x, x + 1, n, bot, BIB[x], "cream")
    chest.paint_sym(-14, -12, 5, -6, 4, "cream")  # the chest's prow: the bib across it
    chest.dent(-5, -3, 5, 0, 3, "gold-")  # the rider's leg slots

    # the neck and the hind body: turned slices on joints, each starting a cube inside the one before
    for chain, back in ((NECK, False), (HIND, True)):
        end = None
        for name, parent, start, deg, length, d, h, cream in chain:
            if start is None:
                rad = math.radians(prev)
                ux, uz = (math.cos(rad), math.sin(rad)) if back else (-math.cos(rad), math.sin(rad))
                start = (end[0] - ux, end[1] - uz)
            seg = m.part(name, (start[0], 0, start[1]), parent)
            end, prev = turned(seg, start, deg, length, d, h, cream, back), deg

    # THE HEAD, held up on the neck: a rounded skull of cubes
    head = m.part("Head", (-13.5, 0, 9), "Neck2")
    head.hull(-18, -11, 3, 8, 14, "gold", [(1, 1)], [(1, 1)])
    head.carve(-18, -17, -3, 4, 13, 14)  # the forehead and the back of the skull rounded off by a step
    head.carve(-12, -11, -3, 4, 13, 14)
    head.paint_sym(-18, -11, 3, 12, 14, "gold+")
    head.paint_sym(-17, -12, 3, 12, 13, "gold")
    head.paint_sym(-18, -14, 3, 8, 9, "cream")  # the chin's underside: the bib starts here
    # the eyes: big and glossy, 3 by 3, dark with one white block of shine at the top front
    head.paint_pair(-17, -14, 3, 4, 10, 13, "black")
    head.paint_pair(-17, -16, 3, 4, 12, 13, "white")
    head.pair(-13, -12, 4, 5, 11, 12, "gold")  # the ear flaps, one block each, behind the eyes
    # the muzzle: one step narrower, tapering, tilted a little up; a cream whisker pad under it, wider (the cheeks)
    head.beam((-17.5, 0, 12.0), (-21.4, 0, 12.6), 4.6, 2.4, "gold", flat="z")
    head.beam((-17.6, 0, 10.4), (-22.0, 0, 11.0), 5.4, 2.4, "cream", flat="z")
    head.beam((-21.0, 0, 12.7), (-22.6, 0, 12.95), 2.6, 1.8, "nose", flat="z")  # the big dark nose
    # the mouth: a thin dark line under the pad, turning up at its corner, over a cream chin
    head.beam((-21.6, 0, 9.35), (-19.0, 0, 9.2), 5.0, 0.35, "nose", flat="z")
    head.beam((-19.2, 0, 9.2), (-17.4, 0, 10.0), 4.6, 0.35, "nose", flat="z")
    head.beam((-16.0, 0, 8.8), (-21.4, 0, 8.7), 4.2, 1.2, "cream", flat="z")
    # three whisker dots a side on the pad
    for x, z in ((-21.2, 11.0), (-20.0, 11.2), (-20.6, 10.2)):
        head.beam((x - 0.3, 2.7, z), (x + 0.3, 2.7, z), 0.6, 0.6, "nose", flat="y", mirror=True)

    # THE MARK: the long front flippers, chocolate, two blocks each, swept back and down from the chest
    for name, side in (("FlipperR", 1), ("FlipperL", -1)):
        part = m.part(name, (-9.0, 4.0 * side, -3.5), "Chest")
        part.beam((-9.5, 3.4 * side, -3.2), (-4.0, 8.6 * side, -5.8), 4.4, 1.2, "choc", flat="z")
        part.beam((-4.8, 7.8 * side, -5.4), (0.8, 12.6 * side, -7.4), 3.6, 0.7, "choc", flat="z")

    # the rear flippers: held together at the end and fanned like a tail, chocolate
    rear = m.part("Rear", (11.5, 0, 3.4), "Hind3")
    rear.beam((10.6, 1.1, 3.0), (15.4, 1.25, 4.5), 2.0, 1.1, "choc", flat="z", mirror=True)
    # each fans out from its root: wider and thinner toward the tip
    rear.block(14.6, (0.5, 2.0, 4.0, 4.5), 19.0, (0.7, 4.4, 5.05, 5.4), "choc", mirror=True)
