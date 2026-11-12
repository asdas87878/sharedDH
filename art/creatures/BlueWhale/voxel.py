"""The Blue Whale as "the old one" (zone 5's Mythic) for tools/blender/voxel_kit.py (docs/style/04-voxel-style.md), dressed as
a Mythic by docs/style/05-rarity-look.md. The giant: the biggest creature made, about 45 studs.
Its idea: a whale so old that a reef has grown on it. Age and scale, with a little living light.
- The body is nine short slices behind a broad flat head, so it bends smoothly. A whale swims up and down: `pose` bends the
  slices about the side-to-side axis.
- The lower jaw is huge, pale and on its own joint: it drops slowly and shows a comb of baleen. Shallow grooves run along
  the throat; the underside is striped with them.
- The growth sits in clusters along the back and leaves the flanks plain: a crust of barnacles on the head (the focal
  point), a piece of a ship's hull behind it that the rider sits on, sponges, a tall coral tree, anemones, a table coral,
  a smaller coral, and a small coral and barnacles at the tail (the echo). An old chain goes round it, with an anchor still hanging.
- Only living things glow, a little: the ends of the coral, the anemones, a few specks in the algae. The whale doesn't.
- The eye is small and old under a heavy lid, with a dark pupil. The flippers are stacks of boxes on their own joints.
The rider sits on the piece of hull, behind the head."""
import math

NAME, ZONE, RARITY = "Blue Whale", "ZONE 5 / OPEN BLUE", "MYTHIC"
U = 0.7
PALETTE = {"body": "#47708F", "throat": "#C4D3D9", "mouth": "#7A3B46", "baleen": "#E6DDC2", "black": "#24262B",
           "coral": "#E86F5C", "crust": "#D8CDB4", "weed": "#5F8F58", "lume": "#7FF0D8", "iron": "#3B3F46", "sponge": "#E2B84A",
           "wood": "#7A5A3C"}
SEAT = (-15.8, 8.0, 1.5)
GLOW = {"lume": 0.7}
LIGHTS = [("S3", (-2.0, 0.9, 18.4), "#7FF0D8", 110, 0.8),  # the coral's ends
          ("S4", (-1.0, 2.7, 8.6), "#7FF0D8", 55, 0.5),  # the anemones
          ("S6", (12.4, 0.6, 12.6), "#7FF0D8", 60, 0.6),  # the second coral
          ("S8", (19.2, 0, 7.0), "#7FF0D8", 40, 0.5)]  # the small coral at the tail
FRAME, ORTHO, ORTHO_SWIM = 3.7, 52.0, 58.0
CHAIN = ["Head", "S1", "S2", "S3", "S4", "S5", "S6", "S7", "S8", "S9", "Tail"]
AMPLITUDES = [1.5, 2, 3, 4, 5, 6, 7, 9, 11, 14]


def pose(parts, phase):
    """a whale's swim: the wave runs down the body up and down, not side to side; the jaw drops slowly and shuts once a
    beat; the flippers rise and fall a little"""
    parts["Head"].rotation_euler.y = math.radians(1.2) * math.sin(phase + math.pi)
    for k, name in enumerate(CHAIN[1:]):
        parts[name].rotation_euler.y = math.radians(AMPLITUDES[k]) * math.sin(phase - 0.55 * (k + 1))
    parts["Jaw"].rotation_euler.y = -math.radians(6) * (0.5 + 0.5 * math.sin(phase - 1.0))
    for name, side in (("FlipR", 1), ("FlipL", -1)):
        parts[name].rotation_euler.x = side * math.radians(7) * math.sin(phase - 0.8)


def steps_for(n):
    return [(3, 1), (1, 2)] if n >= 6 else ([(2, 1), (1, 1)] if n >= 4 else ([(1, 1)] if n >= 2 else []))


def slab(p, x0, x1, n, bot, top, pale_to):
    """a length of body: stepped corners, lighter on the top row, pale from `pale_to` down, the belly steps darker"""
    st = steps_for(n)
    p.hull(x0, x1, n, bot, top, "body", st, st)
    p.paint_sym(x0, x1, n, top - 1, top, "body+")
    p.paint_sym(x0, x1, n, bot, pale_to, "throat")
    p.paint_sym(x0, x1, n, bot, bot + 1, "throat-")


def pleats(p, x0, x1, n, bot):
    """the throat's grooves seen from below: every other row of the underside a tone darker"""
    p.paint_sym(x0, x1, n, bot, bot + 1, "throat")
    for j in range(-(n - 3), n - 2, 2):
        p.paint(x0, x1, j, j + 1, bot, bot + 1, "throat-")
    for j in (-(n - 1), n - 1):
        p.paint(x0, x1, j, j + 1, bot + 1, bot + 2, "throat-")


def knob(p, x0, x1, y0, y1, z0, z1, colour="crust+"):
    """a barnacle: a small block sunk a little into what it sits on"""
    p.block(x0, (y0, y1, z0, z1), x1, (y0, y1, z0, z1), colour)


def build(m):
    head = m.part("Head", (-18, 0, 0))
    # the upper jaw: a broad flat slab, narrower toward the nose, darker along the lip
    head.hull(-30, -27, 4, 0, 4, "body", [(1, 1)])
    head.hull(-27, -23, 5, 0, 5, "body", [(2, 1)])
    head.hull(-23, -18, 6, 0, 5, "body", [(2, 1)])
    head.paint_sym(-30, -27, 4, 3, 4, "body+")
    head.paint_sym(-27, -18, 6, 4, 5, "body+")
    head.paint_sym(-30, -18, 6, 0, 1, "body-")
    head.sym(-21, -19, 1, 5, 6, "body-")  # the blowhole's ridge
    # a comb of baleen under each side of the upper jaw: it shows when the lower jaw drops
    baleen = (4.6, 5.2, -1.3, 0.2)
    head.block(-26.8, baleen, -19.2, baleen, "baleen", mirror=True)
    # the eye: small and old, a dark pupil in a pale ring, under a heavy lid
    ring = (6.3, 6.85, 1.0, 3.0)
    head.block(-21.6, ring, -19.6, ring, "baleen", mirror=True)
    pupil = (6.7, 7.1, 1.5, 2.3)
    head.block(-21.0, pupil, -20.2, pupil, "black", mirror=True)
    head.beam((-21.9, 6.6, 2.9), (-19.3, 6.6, 3.15), 1.4, 1.4, "body-", mirror=True)
    # the focal point: a crust of barnacles over the top of the head, with big ones standing on it
    head.band(-26.6, -23.4, 5, 0, 5, "crust", [(2, 1)], [], 0.3, stop=3.6)
    knob(head, -26.0, -24.9, -1.8, -0.6, 5.2, 6.1)
    knob(head, -24.6, -23.7, 0.5, 1.6, 5.2, 5.9)
    knob(head, -25.7, -25.0, 1.9, 2.6, 5.2, 5.7, "crust")
    knob(head, -23.9, -23.5, -2.4, -1.7, 5.2, 5.6, "crust")

    # the lower jaw, on its own joint: a huge pale scoop, a little longer than the upper jaw, grooved along its sides
    jaw = m.part("Jaw", (-18, 0, -0.5), "Head")
    jaw.hull(-31, -28, 5, -5, 0, "throat", (), [(2, 1), (1, 1)])
    jaw.hull(-28, -18, 7, -7, 0, "throat", (), [(3, 1), (1, 2)])
    jaw.paint_sym(-31, -28, 5, -5, -4, "throat-")
    pleats(jaw, -28, -18, 7, -7)
    # the inside of the mouth, seen when it opens: only under the upper jaw, so none of it shows from above
    jaw.paint(-23, -18, -5, 6, -1, 0, "mouth")
    jaw.paint(-27, -23, -4, 5, -1, 0, "mouth")
    jaw.paint(-30, -27, -3, 4, -1, 0, "mouth")
    jaw.dent(-27, -19, 7, -4, -3, "throat-")
    jaw.dent(-27, -19, 7, -2, -1, "throat-")
    knob(jaw, -24.6, -23.4, 7.4, 8.1, -2.8, -2.2, "crust")  # a barnacle on each cheek
    knob(jaw, -24.6, -23.4, -8.1, -7.4, -2.8, -2.2, "crust")

    # the body: nine short slices, tapering to the tail; pale underneath, the pale rising to the throat at the front
    slices = ((-18, -13, 7, -7, 6, 0), (-13, -8, 7, -7, 6, -1), (-8, -3, 7, -6, 6, -2), (-3, 2, 6, -5, 6, -3), (2, 7, 6, -5, 5, -3),
              (7, 12, 5, -4, 5, -3), (12, 17, 4, -3, 4, -2), (17, 21, 3, -2, 3, -1), (21, 25, 2, -1, 2, 0))
    segs = [m.part(f"S{i + 1}", (sl[0], 0, 0), "Head" if i == 0 else f"S{i}") for i, sl in enumerate(slices)]
    front = (6, -7, 5)  # the piece in front of the first slice: the head (6 out, 5 high) and the jaw (down to -7)
    for i, (seg, (x0, x1, n, bot, top, pale_to)) in enumerate(zip(segs, slices)):
        slab(seg, x0, x1, n, bot, top, pale_to)
        # a sleeve, one cube into the piece in front, so a bending joint shows body. It stays a clear cube inside that
        # piece's stepped outline everywhere, so none of its faces lies in the plane of a face that shows
        seg.sym(x0 - 1, x0, min(n - 1, front[0] - 2), max(bot + 1, front[1] + 2), min(top - 1, front[2] - 2), "body-")
        front = (n, bot, top)
        if i < 3:
            pleats(seg, x0, x1, n, bot)
    segs[0].dent(-18, -13, 7, -4, -3, "throat-")  # the throat's grooves run on a little way behind the jaw
    segs[0].dent(-18, -13, 7, -2, -1, "throat-")

    # a piece of a ship's hull grown onto its back behind the head: the rider's seat. Planks, and two ribs across them
    planks = (-1.5, 1.5, 5.8, 8.0)
    segs[0].block(-17.4, planks, -13.8, planks, "wood")
    rib = (-1.75, 1.75, 5.9, 8.25)
    segs[0].block(-17.25, rib, -16.8, rib, "wood-")
    segs[0].block(-14.8, rib, -14.35, rib, "wood-")
    segs[0].beam((-14.4, -0.9, 7.0), (-13.6, -1.1, 11.2), 0.9, 0.8, "wood-")  # a broken spar still standing behind the seat
    # tube sponges on the left shoulder: three yellow tubes of uneven height
    for x, y, tall in ((-11.6, -4.2, 3.2), (-10.5, -3.5, 2.2), (-11.4, -2.6, 1.4)):
        knob(segs[1], x, x + 1.0, y, y + 1.0, 5.8, 5.8 + tall, "sponge")
    knob(segs[1], -9.6, -8.5, 1.4, 2.6, 5.9, 6.7)  # a barnacle
    # algae in a few patches, a speck of living light in each: paint only
    for part, (x0, x1, j0, j1, z0, z1), (x, j, z) in ((segs[1], (-12, -10, 1, 4, 5, 6), (-11, 2, 5)), (segs[2], (-7, -5, 7, 8, 0, 3), (-6, 7, 1)),
                                                      (segs[4], (5, 7, -3, 0, 4, 5), (6, -2, 4)), (segs[5], (8, 10, -5, -4, 0, 3), (9, -5, 1))):
        part.paint(x0, x1, j0, j1, z0, z1, "weed-")
        part.paint(x, x + 1, j, j + 1, z, z + 1, "lume")

    # the coral tree, where a fin might have been: a trunk, two big branches and a spike whose ends glow a little, and a
    # spur each side
    tree = segs[2]
    tree.beam((-6.4, 0, 4.6), (-5.6, 0, 11.6), 3.2, 2.4, "coral")
    tree.beam((-5.7, 0.2, 10.4), (-2.2, 0.9, 17.4), 2.1, 1.7, "coral")
    tree.beam((-2.85, 0.77, 16.1), (-1.4, 1.05, 19.0), 1.4, 1.0, "lume")
    tree.beam((-5.8, -0.2, 10.2), (-9.2, -1.1, 15.4), 1.8, 1.3, "coral")
    tree.beam((-8.55, -0.93, 14.4), (-10.0, -1.3, 16.8), 1.1, 0.7, "lume")
    tree.beam((-5.75, 0.0, 10.8), (-5.2, 0.0, 15.0), 1.3, 0.9, "coral")
    tree.beam((-5.9, 0.6, 9.2), (-5.0, 5.4, 12.6), 1.5, 1.0, "coral", flat="z")
    tree.beam((-5.9, -0.6, 8.4), (-6.5, -4.2, 11.0), 1.3, 0.8, "coral", flat="z")
    # anemones behind the tree, on both shoulders: a stalk and a crown that glows a little
    for part, x, tall, big in ((segs[2], -4.3, 1.2, 0.15), (segs[3], -1.6, 1.6, 0.3), (segs[3], 0.6, 0.9, 0.0)):
        stalk = (2.2, 3.1, 5.9, 5.9 + tall)
        part.block(x + 0.15, stalk, x + 0.75, stalk, "coral-", mirror=True)
        crown = (1.95 - big, 3.35 + big, 5.7 + tall, 6.3 + tall + big)
        part.block(x - 0.15 - big, crown, x + 1.05 + big, crown, "lume", mirror=True)

    # an old chain round it, and a ship's anchor still hanging from the chain on its left side
    st = steps_for(6)
    segs[3].band(-0.9, -0.3, 6, -5, 6, "iron", st, st, 0.3)
    segs[3].beam((-0.6, -6.2, 0.5), (0.3, -8.6, -8.4), 1.0, 1.0, "iron")
    segs[3].beam((0.25, -8.45, -7.9), (-2.4, -9.1, -9.6), 0.8, 0.7, "iron")
    segs[3].beam((0.25, -8.45, -7.9), (2.9, -9.0, -9.4), 0.8, 0.7, "iron")

    # a table coral further back: two plates on stems; barnacles beyond it
    table = segs[4]
    stem = (-0.5, 0.5, 3.6, 5.9)
    table.block(4.0, stem, 4.9, stem, "coral-")
    plate = (-2.4, 2.4, 5.7, 6.2)
    table.block(3.0, plate, 6.0, plate, "crust")
    stem = (-0.4, 0.4, 6.1, 7.0)
    table.block(4.1, stem, 4.8, stem, "coral-")
    plate = (-1.6, 1.6, 6.8, 7.2)
    table.block(3.5, plate, 5.5, plate, "crust+")
    # a second, smaller coral behind it, so the back steps down from the tall tree to the tail; a barnacle each side
    segs[5].beam((9.6, 0, 3.6), (10.0, 0, 8.6), 2.0, 1.6, "coral")
    segs[5].beam((9.9, 0.1, 7.8), (12.0, 0.5, 11.6), 1.4, 1.1, "coral")
    segs[5].beam((11.55, 0.41, 10.8), (12.5, 0.6, 12.6), 0.9, 0.7, "lume")
    segs[5].beam((9.8, -0.1, 7.6), (8.0, -0.6, 10.4), 1.2, 0.9, "coral")
    knob(segs[5], 7.6, 8.5, 1.3, 2.4, 4.9, 5.7)
    knob(segs[5], 10.9, 11.7, -2.3, -1.4, 4.9, 5.5, "crust")

    # weed hanging from the belly
    segs[2].beam((-6.4, 1.2, -5.2), (-4.6, 1.6, -11.0), 0.8, 0.5, "weed")
    segs[3].beam((-1.4, -1.0, -4.2), (0.8, -1.4, -10.8), 0.8, 0.5, "weed")
    segs[4].beam((3.4, 0.9, -4.2), (5.0, 1.2, -8.6), 0.6, 0.4, "weed-")
    segs[5].beam((8.4, -0.8, -3.2), (10.0, -1.1, -7.0), 0.6, 0.4, "weed")

    # the small back fin, far back
    segs[6].beam((14.0, 0, 2.6), (15.8, 0, 5.6), 2.2, 0.9, "body-")
    # the echo at the tail: a small coral with a glowing end
    segs[7].beam((18.4, 0, 1.8), (18.9, 0, 5.6), 1.4, 1.1, "coral")
    segs[7].beam((18.75, 0, 4.8), (19.4, 0, 6.8), 0.9, 0.7, "lume")

    # the flippers, each on its own joint: three boxes stacked along it, smaller toward the tip, swept back and down
    for name, s in (("FlipR", 1), ("FlipL", -1)):
        flip = m.part(name, (-11.6, 6.5 * s, -3.3), "S2")
        flip.beam((-11.6, 6.1 * s, -3.3), (-7.4, 10.3 * s, -4.9), 3.4, 1.0, "body", flat="z")
        flip.beam((-8.3, 9.4 * s, -4.55), (-5.0, 12.5 * s, -5.8), 2.5, 0.7, "body-", flat="z")
        flip.beam((-5.6, 11.9 * s, -5.55), (-3.6, 13.7 * s, -6.3), 1.6, 0.4, "body-", flat="z")

    # the tail, on its own joint: a stock, a broad hub, and two flukes lying flat, two boxes each; barnacles on the hub
    tail = m.part("Tail", (25, 0, 0.5), "S9")
    tail.beam((24.6, 0, 0.5), (28.0, 0, 0.5), 2.6, 1.8, "body", flat="z")
    hub = (-2.7, 2.7, -0.6, 1.6)
    tail.block(26.2, hub, 30.4, hub, "body")
    tail.beam((28.3, 1.5, 0.5), (32.0, 8.5, 0.5), 4.4, 1.0, "body", flat="z", mirror=True)
    tail.beam((31.0, 6.9, 0.5), (33.4, 11.4, 0.5), 3.0, 0.7, "body-", flat="z", mirror=True)
    knob(tail, 27.2, 28.2, -1.2, -0.2, 1.5, 2.2)
    knob(tail, 28.6, 29.4, 0.5, 1.4, 1.5, 2.0, "crust")
