"""The Sea Turtle (zone 1's Uncommon: a green sea turtle) for tools/blender/voxel_kit.py (docs/style/04-voxel-style.md).
Its idea: a calm, friendly turtle whose shell is five plain plates with pale seams drawn between its scutes.
- The shell is five big blocks, front to back (the Archelon's way, made small): a wide flat plateau, one broad shoulder
  step, a wall, and a darker lip a cube proud all the way round. From the side the blocks make a low dome; from above
  an oval that is widest just ahead of the middle and narrows to the tail.
- The one pattern (an Uncommon has one): thin pale seams drawn the way a turtle's scutes lie. One runs along the foot
  of each plateau and one across it at the foot of the next, taller block, so the five plateaus are the five plates
  down the spine, each plain inside its outline; between them one runs down each side of the three big blocks to the
  lip, between the plates of the flank.
- Under the lip the body turns in to a cream underside.
- A small head on a short neck, on its own joint: a blunt beak (a green upper beak over a shorter cream jaw), a cream
  throat, a dark eye in a cream ring.
- Long front flippers, each on a joint: an arm that goes out, a blade and a tip that sweep back, each smaller and
  thinner. Short back flippers, each on a joint. A short tail.
The rider sits on the crown."""
import math

NAME, ZONE, RARITY = "Sea Turtle", "ZONE 1 / SHALLOWS", "UNCOMMON"
U = 0.4
PALETTE = {"shell": "#6F8A3C", "seam": "#CDD494", "skin": "#8DB06A", "belly": "#F3E9C8", "black": "#1E2226"}
SEAT = (0, 5, 2.0)
FRAME, ORTHO = 1.5, 19.0
TEXTURES = [{"tile": "stud_square", "on": "all", "colours": ["shell"]}]

# the shell, front to back, in five big blocks: (from, to, cubes out either side, bottom, the height of its crown, its
# shoulder step as (cubes in, cubes tall), the corners of the underside)
SLICES = ((-12, -9, 6, -2, 3, (2, 1), [(1, 1)]),
          (-9, -3, 8, -3, 4, (3, 1), [(2, 1), (1, 1)]),
          (-3, 3, 9, -3, 5, (3, 2), [(2, 1), (1, 1)]),
          (3, 8, 7, -3, 4, (3, 1), [(2, 1), (1, 1)]),
          (8, 11, 5, -2, 3, (2, 1), [(1, 1)]))
SEAMS = (1, 2, 3)  # the blocks that carry a seam down the middle of each side
LIP = 1  # the height of the lip's top
PROUD, WIDE = 0.2, 0.44  # a seam stands this far out of the shell, and is this wide


def seams(p, k):
    """the pale lines of block k, both sides. One lies along the foot of the plateau, on the shoulder: it runs into a
    taller neighbour and stops just short of a lower one. Where a neighbour is taller, one crosses the plateau at the
    foot of that neighbour and comes down the plateau's walls onto the first. On a big block another leaves the first in
    the middle and runs out over the shoulder and down the wall to the lip. They touch and never overlap; each stands
    PROUD of the cubes"""
    x0, x1, n, _, high, (inset, tall), _ = SLICES[k]
    plateau, wall, shoulder = n + 0.5 - inset, n + 0.5, high - tall
    front = k > 0 and SLICES[k - 1][4] > high
    rear = k + 1 < len(SLICES) and SLICES[k + 1][4] > high
    along = (plateau - 0.3, plateau + WIDE, shoulder - 0.3, shoulder + PROUD)
    p.block(x0 if front else x0 + 0.2, along, x1 if rear else x1 - 0.2, along, "seam", mirror=True)
    across = (-(plateau + PROUD), plateau + PROUD, shoulder + PROUD, high + PROUD)
    if front:
        p.block(x0 - 0.2, across, x0 + WIDE, across, "seam")
    if rear:
        p.block(x1 - WIDE, across, x1 + 0.2, across, "seam")
    if k in SEAMS:
        x = (x0 + x1) / 2
        down = (plateau + WIDE, wall + PROUD, LIP - 0.3, shoulder + PROUD)
        p.block(x - WIDE / 2, down, x + WIDE / 2, down, "seam", mirror=True)


def pose(parts, phase):
    """it flies under water: the front flippers beat like wings and sweep back a little on the way down, the back
    flippers steer, the shell rocks with each beat and the head nods"""
    for tag, side in (("R", 1), ("L", -1)):
        parts[f"FlipF{tag}"].rotation_euler.x = side * math.radians(18) * math.sin(phase)
        parts[f"FlipF{tag}"].rotation_euler.z = side * math.radians(7) * math.sin(phase - 1.3)
        parts[f"FlipB{tag}"].rotation_euler.z = math.radians(9) * math.sin(phase + 1.2)
        parts[f"FlipB{tag}"].rotation_euler.x = side * math.radians(6) * math.sin(phase + math.pi)
    parts["Shell"].rotation_euler.y = math.radians(2) * math.sin(phase + math.pi / 2)
    parts["Head"].rotation_euler.y = math.radians(5) * math.sin(phase - 0.5)


def build(m):
    shell = m.part("Shell", (0, 0, 0))
    for k, (x0, x1, n, bot, high, step, under) in enumerate(SLICES):
        shell.hull(x0, x1, n, bot, high, "shell", [step], under)
        shell.paint_sym(x0, x1, n, high - 1, high, "shell+")  # the plateau catches the light
        shell.paint_sym(x0, x1, n, bot, 0, "belly")  # the cream underside
        shell.sym(x0, x1, n + 1, 0, LIP, "shell-")  # the lip: a cube proud all the way round
        seams(shell, k)
    shell.sym(-13, -12, SLICES[0][2] - 1, 0, LIP, "shell-")  # the lip round the front and the back
    shell.sym(11, 12, SLICES[-1][2] - 1, 0, LIP, "shell-")
    # the collar: the thick root of the neck, coming out under the front of the shell
    shell.hull(-14, -12, 2, -2, 2, "skin-", [(1, 1)], [(1, 1)])
    # where the front flippers leave the body the skin shows under the lip
    shell.paint_pair(-11, -7, 5, 10, -1, 0, "skin-")
    # the tail: short, two boxes, the second a point
    shell.beam((10.3, 0, -1.0), (12.8, 0, -1.15), 1.8, 1.0, "skin", flat="z")
    shell.beam((12.2, 0, -1.1), (13.7, 0, -1.25), 1.0, 0.6, "skin-", flat="z")

    # the head, on its own joint: a short neck, a small skull, a blunt beak
    head = m.part("Head", (-14, 0, 0), "Shell")
    head.sym(-16, -14, 1, -2, 1, "skin")
    head.sym(-14, -13, 1, -1, 0, "skin-")  # a sleeve into the collar, clear of its steps
    head.hull(-20, -16, 2, -2, 2, "skin", [(1, 1)])
    head.paint_sym(-20, -14, 2, -2, -1, "belly")  # a cream throat
    # the beak: a green upper block that narrows and slopes down from the brow, over a shorter, narrower cream jaw
    head.block(-19.6, (-2.2, 2.2, -1.0, 0.9), -21.5, (-1.4, 1.4, -0.9, 0.0), "skin")
    head.block(-19.6, (-1.9, 1.9, -1.8, -0.8), -21.0, (-1.1, 1.1, -1.6, -0.8), "belly")
    # the eye: a cream ring on the side of the skull, a dark pupil standing out of it
    ring = (2.3, 2.8, -0.8, 0.85)
    head.block(-19.3, ring, -17.5, ring, "belly", mirror=True)
    pupil = (2.7, 3.1, -0.4, 0.55)
    head.block(-18.95, pupil, -17.95, pupil, "black", mirror=True)

    for s, tag in ((1, "R"), (-1, "L")):
        # the front flippers: an arm that goes out from under the lip, a blade that sweeps back from the elbow, a tip
        # that sweeps back again. Each is smaller and thinner than the one before and starts inside it
        front = m.part(f"FlipF{tag}", (-9.0, 7.0 * s, -1.0), "Shell")
        front.beam((-9.0, 5.2 * s, -1.0), (-10.0, 12.0 * s, -1.2), 3.8, 1.2, "skin", flat="z")
        front.beam((-9.8, 10.5 * s, -1.15), (-4.5, 16.8 * s, -1.45), 3.4, 0.8, "skin", flat="z")
        front.beam((-5.3, 15.9 * s, -1.4), (-1.0, 18.8 * s, -1.65), 2.4, 0.45, "skin-", flat="z")
        # the back flippers: short, two boxes
        back = m.part(f"FlipB{tag}", (9.5, 4.5 * s, -0.9), "Shell")
        back.beam((8.6, 3.2 * s, -0.9), (12.2, 6.6 * s, -1.1), 2.8, 1.0, "skin", flat="z")
        back.beam((11.5, 6.0 * s, -1.05), (13.6, 7.9 * s, -1.3), 2.0, 0.6, "skin-", flat="z")
