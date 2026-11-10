"""The Angelfish (zone 2's Uncommon: a queen angelfish) for tools/blender/voxel_kit.py (docs/style/04-voxel-style.md).
Its idea: a tall gold coin of a fish wearing a blue crown, with two long streamers trailing behind it.
- The body is a thin, tall disc: one big plateau slab, five cubes wide and sixteen tall. Seen from above it is a lens:
  the face is three cubes wide, the body five, the tail root three.
- The head is a wedge. Its forehead and its chest are whole planks laid at an angle over a stepped core, so the two
  slopes are clean; the gold ones run from the mouth, the blue ones (the nape and the chest) start behind the eye and
  end inside the body.
- The crown: a dark spot ringed in bright blue, saddled over the nape so it shows from both sides and from above.
- The back and belly fins are two planks each, swept back, each smaller and thinner than the last, with a thin
  bright-blue line along the outer edge, and end in a long gold streamer on a joint of its own.
- One thin bright-blue line runs along the body from behind the eye to the tail.
- The tail is a small gold fan of three fingers. The side fins scull on their own joints.
The rider sits on the gold back in front of the back fin, legs in a shallow slot either side."""
import math

NAME, ZONE, RARITY = "Angelfish", "ZONE 2 / CORAL REEF", "UNCOMMON"
U = 0.4
PALETTE = {"gold": "#F2B632", "blue": "#2F56B8", "bright": "#3FD0FF", "navy": "#1B2350", "black": "#1A1C22", "cream": "#FFF4D6"}
SEAT = (-2, 8, 2.6)
FRAME, ORTHO = 1.25, 20.0
TEXTURES = [{"tile": "stud", "on": "top", "colours": ["gold"]}]

# the head's two slopes, in the side view (x, z): the forehead from the mouth up to the back, and the chest (drawn
# mirrored, as if it were on top) from the mouth down to the belly
BROW_A, BROW_B = (-13.4, 0.8), (-6.6, 6.6)
CHEST_A, CHEST_B = (-13.2, 2.4), (-6.5, 6.6)
# the back fin's outer edges (the belly fin is the same, mirrored): the big plank, the swept one, the streamer in two
FIN1 = ((0.9, 7.3), (5.8, 11.0))
FIN2 = ((5.52, 10.64), (9.6, 12.3))
TIP1 = ((9.28, 12.01), (12.4, 12.3))
TIP2 = ((11.6, 11.93), (15.4, 12.25))


def pose(parts, phase):
    """a disc fish's swim: the front two thirds stay stiff, the rear and the tail fan beat, the streamers trail after
    them, and the side fins scull twice a beat"""
    parts["Body"].rotation_euler.z = math.radians(2.5) * math.sin(phase + math.pi)
    parts["Rear"].rotation_euler.z = math.radians(8) * math.sin(phase - 0.7)
    parts["Tail"].rotation_euler.z = math.radians(16) * math.sin(phase - 1.5)
    for name in ("DorsalTip", "AnalTip"):
        parts[name].rotation_euler.z = math.radians(13) * math.sin(phase - 2.3)
    for name, side in (("FinR", 1), ("FinL", -1)):
        parts[name].rotation_euler.z = side * math.radians(16) * (0.5 + 0.5 * math.sin(2 * phase))


def plank(p, a, b, wide, thick, colour, s=1, out=0.0, s0=0.0, e1=0.0, y=0.0, mirror=False):
    """a whole box laid along a slope: its outer edge runs from a to b in the side view (x, z) and it hangs `wide`
    inward from that line, less `out` (how far it stands proud of the line). It starts s0 along the line and ends e1
    past b. s = -1 builds it mirrored below the body"""
    dx, dz = b[0] - a[0], b[1] - a[1]
    length = math.hypot(dx, dz)
    ux, uz = dx / length, dz / length
    off = wide / 2 - out
    cx, cz = a[0] + uz * off, a[1] - ux * off
    s1 = length + e1
    p.beam((cx + ux * s0, y, s * (cz + uz * s0)), (cx + ux * s1, y, s * (cz + uz * s1)), wide, thick, colour, flat="y", mirror=mirror)


def build(m):
    body = m.part("Body", (-4, 0, 0))
    # the head's core: a stepped wedge three cubes wide. Its steps are hidden under the planks
    for x, z0, z1 in ((-13, -2, 1), (-12, -3, 1), (-11, -3, 2), (-10, -4, 3), (-9, -5, 4), (-8, -5, 4)):
        body.sym(x, x + 1, 1, z0, z1, "gold")
    # the body: one big plateau slab, lighter on top, darker underneath
    # (a shoulder slab a cube lower in front of it, so the disc's corner is rounded; the same behind it, on the rear)
    body.sym(-7, -5, 2, -7, 7, "gold")
    body.hull(-5, 2, 2, -8, 8, "gold", [(1, 1)], [(1, 1)])
    body.paint_sym(-5, 2, 2, 7, 8, "gold+")
    body.paint_sym(-5, 2, 2, -8, -7, "gold-")
    body.paint_sym(-9, 2, 2, 0, 1, "bright")  # the thin line along the body
    body.dent(-3, -1, 2, 4, 7, "gold-")  # the rider's leg slots

    # the forehead and the chest: gold planks from the mouth, blue ones (wider, a step proud) from behind the eye
    plank(body, BROW_A, BROW_B, 1.5, 3.4, "gold", s0=-0.1, e1=-4.04)
    plank(body, BROW_A, BROW_B, 2.6, 3.8, "blue", out=0.3, s0=3.6)
    plank(body, CHEST_A, CHEST_B, 1.5, 3.4, "gold", s=-1, s0=-0.1, e1=-3.5)
    plank(body, CHEST_A, CHEST_B, 2.6, 3.8, "blue", s=-1, out=0.3, s0=3.2)
    # the crown, saddled over the nape: a bright ring, a dark spot on each side and on top
    plank(body, BROW_A, BROW_B, 2.5, 4.2, "bright", out=0.6, s0=4.7, e1=-1.64)
    plank(body, BROW_A, BROW_B, 1.2, 0.9, "navy", out=-0.15, s0=5.3, e1=-2.24, y=1.85, mirror=True)
    plank(body, BROW_A, BROW_B, 0.7, 2.6, "navy", out=0.9, s0=5.45, e1=-2.39)
    # the small mouth: a snout block and blue lips
    snout = (-1.1, 1.1, -1.8, 0.6)
    body.block(-14.4, snout, -12.6, snout, "gold")
    lips = (-0.75, 0.75, -1.35, 0.05)
    body.block(-14.8, lips, -14.2, lips, "blue")
    # the eye: a cream ring and a dark pupil standing out of it
    ring = (1.2, 2.05, -1.0, 1.3)
    body.block(-11.9, ring, -9.9, ring, "cream", mirror=True)
    pupil = (1.9, 2.35, -0.6, 0.8)
    body.block(-11.55, pupil, -10.25, pupil, "black", mirror=True)
    # the belly fins: one long gold blade each, pointing down and back
    body.beam((-4.2, 0.9, -7.0), (-1.6, 1.4, -11.2), 1.5, 0.6, "gold", mirror=True)

    # the side fins, each on its own joint: a blue collar at the root, a gold paddle standing out from the flank
    for name, side in (("FinR", 1), ("FinL", -1)):
        fin = m.part(name, (-6.2, 2.5 * side, -1.8), "Body")
        fin.beam((-6.5, 1.9 * side, -1.75), (-5.3, 2.7 * side, -2.05), 2.9, 1.0, "blue")
        fin.beam((-6.3, 2.0 * side, -1.8), (-3.2, 4.0 * side, -2.6), 2.3, 0.6, "gold")

    # the rear: the last of the plateau, then the body steps in to the tail root
    rear = m.part("Rear", (2, 0, 0), "Body")
    rear.sym(2, 4, 2, -7, 7, "gold")
    rear.sym(4, 6, 1, -5, 5, "gold")
    rear.sym(6, 9, 1, -2, 2, "gold")
    rear.paint_sym(2, 9, 2, 0, 1, "bright")
    rear.sym(1, 2, 1, -5, 5, "gold-")  # the sleeve into the body
    # the back fin and the belly fin: two planks each, a bright line along the outer edge, then a gold streamer
    for name, s in (("DorsalTip", 1), ("AnalTip", -1)):
        plank(rear, *FIN1, 4.6, 1.5, "blue", s)
        plank(rear, *FIN1, 0.6, 1.9, "bright", s, out=0.3, s0=0.4, e1=-0.3)
        plank(rear, *FIN2, 2.8, 0.9, "blue", s)
        plank(rear, *FIN2, 0.6, 1.2, "bright", s, out=0.3, s0=-0.4, e1=0.3)
        tip = m.part(name, (TIP1[0][0], 0, s * (TIP1[0][1] - 0.6)), "Rear")
        plank(tip, *TIP1, 1.3, 0.6, "gold", s)
        plank(tip, *TIP2, 0.8, 0.3, "gold+", s)

    # the tail, on its own joint: a root block and a fan of three fingers
    tail = m.part("Tail", (9, 0, 0), "Rear")
    tail.beam((8.4, 0, 0), (10.4, 0, 0), 3.0, 1.3, "gold")
    tail.beam((9.4, 0, 0.4), (13.6, 0, 3.2), 3.0, 1.0, "gold")
    tail.beam((9.4, 0, -0.4), (13.6, 0, -3.2), 3.0, 0.7, "gold")
    tail.beam((10.0, 0, 0), (14.0, 0, 0), 2.4, 0.4, "gold+")
