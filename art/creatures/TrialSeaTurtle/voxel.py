"""The Sea Turtle, a trial of docs/style/09-early-remodels.md, for tools/blender/voxel_kit.py. It stands beside the
game's Sea Turtle (art/creatures/SeaTurtle) and replaces nothing. Designed from a green sea turtle.
Its idea: the dome. A high stepped shell on long swept-back wings, with a big friendly head out in front.
- The shell: 26 cubes long, 21 wide, 12 high from the belly to the top (0.46 of its length). Three tiers: a wall 4
  high, a step 2 high and a wide flat top 3 high (18 by 11), each stepping in two or three cubes. A thin cream rim
  plate runs all round the foot of the wall, half a cube proud. Under it a cream belly, rounded in two steps.
- The front flippers are wings, two turned blocks each, swept back; tip to tip they span more than the animal's
  length. The back flippers are small paddles. A short pointed tail.
- The head is a quarter of the shell's length, held up and forward on a short neck: a blunt green beak over a cream
  jaw, a dark mouth line that turns up at the back (a smile), a big 3 by 3 eye in a cream ring on each side.
- The one mark: the shell's plates. Five down the middle and four each side, parted by flush cream seams one cube wide.
The rider sits on the middle plate of the flat top."""
import math

NAME, ZONE, RARITY = "Sea Turtle (trial)", "ZONE 1 / SHALLOWS", "UNCOMMON"
U = 0.4
PALETTE = {"shell": "#C9782E", "skin": "#9CC46A", "cream": "#F4EBCB", "mouth": "#5A4A2A", "black": "#1E2226"}
SHADE = 0.9
SEAT = (0, 9, 5.5)
FRAME, ORTHO = 1.7, 22.0
TEXTURES = [{"tile": "stud_square", "on": "all", "colours": ["shell"]}]

# the shell in three tiers, each a list of slices (from, to, cubes out either side), and its heights
WALL = ((-13, -11, 6), (-11, -8, 8), (-8, -4, 9), (-4, 4, 10), (4, 8, 9), (8, 11, 7), (11, 13, 4))  # z 0 to 4
STEP = ((-11, -8, 5), (-8, -4, 7), (-4, 4, 8), (4, 8, 7), (8, 11, 5))  # z 4 to 6
TOP = ((-9, -5, 4), (-5, 5, 5), (5, 9, 4))  # z 6 to 9: the flat top
TIERS = ((WALL, 0, 4), (STEP, 4, 6), (TOP, 6, 9))
# the mark: the seams between the plates (x of a seam one cube wide)
MIDDLE = 4  # the seams between the middle plates and the side plates run along this column, either side
ACROSS_MIDDLE = (-8, -3, 2, 7)  # five middle plates: 5, 4, 4, 4, 5 long
ACROSS_SIDES = (-5, 0, 5)  # four side plates, their seams meeting the middle plates halfway along


def rim(p):
    """the thin cream plate round the foot of the wall, half a cube proud of it. Each slice's plate runs on half a cube
    past its slice where it is the wider neighbour (it comes round the corner) and starts half a cube in where it is the
    narrower, so two plates never lie over each other"""
    for k, (x0, x1, n) in enumerate(WALL):
        before = WALL[k - 1][2] if k > 0 else -1
        after = WALL[k + 1][2] if k + 1 < len(WALL) else -1
        a = x0 - 0.5 if n > before else x0 + 0.5
        b = x1 + 0.5 if n > after else x1 - 0.5
        section = (-(n + 1.0), n + 1.0, -0.3, 0.4)
        p.block(a, section, b, section, "cream")


def pose(parts, phase):
    """it flies under water: the front flippers beat like wings and sweep back a little on the way down, the back
    flippers steer, the shell rocks with each beat and the head nods"""
    for tag, side in (("R", 1), ("L", -1)):
        parts[f"FlipF{tag}"].rotation_euler.x = side * math.radians(20) * math.sin(phase)
        parts[f"FlipF{tag}"].rotation_euler.z = side * math.radians(7) * math.sin(phase - 1.3)
        parts[f"FlipB{tag}"].rotation_euler.z = math.radians(9) * math.sin(phase + 1.2)
        parts[f"FlipB{tag}"].rotation_euler.x = side * math.radians(6) * math.sin(phase + math.pi)
    parts["Shell"].rotation_euler.y = math.radians(2) * math.sin(phase + math.pi / 2)
    parts["Head"].rotation_euler.y = math.radians(5) * math.sin(phase - 0.5)


def build(m):
    shell = m.part("Shell", (0, 0, 0))
    # the collar: the thick root of the neck, coming out under the front of the shell (the wall covers its top behind)
    shell.hull(-15, -12, 2, -2, 2, "skin", [(1, 1)], [(1, 1)])
    shell.paint_sym(-15, -12, 2, -2, -1, "cream")
    # the belly: cream, rounded underneath in two steps, set well in under the rim
    shell.hull(-12, -10, 5, -3, 0, "cream", [], [(1, 1)])
    shell.hull(-10, 9, 7, -3, 0, "cream", [], [(2, 1), (1, 1)])
    shell.hull(9, 12, 5, -3, 0, "cream", [], [(1, 1)])
    # the dome: three tiers, each stepping in
    for slices, z0, z1 in TIERS:
        for x0, x1, n in slices:
            shell.sym(x0, x1, n, z0, z1, "shell")
    # THE MARK: flush cream seams one cube wide. Painting the whole column colours its top and every wall it shows on
    # along: only where the column has shell outside it, so a tier's own outer wall stays plain (there the edge parts them)
    for x, y, z in [c for c in shell.cells if abs(c[1]) == MIDDLE and c[2] >= 0]:
        if (x, y + (1 if y > 0 else -1), z) in shell.cells:
            shell.cells[(x, y, z)] = "cream"
    for x in ACROSS_MIDDLE:
        shell.paint_sym(x, x + 1, MIDDLE - 1, 0, 9, "cream")
    for x in ACROSS_SIDES:
        shell.paint_pair(x, x + 1, MIDDLE, 11, 0, 9, "cream")
    rim(shell)
    # the tail: short and pointed, a box and a point
    shell.beam((11.4, 0, -1.2), (15.4, 0, -1.4), 2.2, 1.3, "skin", flat="z")
    shell.spike([(14.9, -0.8, -1.85), (14.9, 0.8, -1.85), (14.9, 0.8, -0.95), (14.9, -0.8, -0.95)], (17.6, 0, -1.55), "skin")

    # the head, on its own joint: a short neck, a big round skull held up, a blunt beak over a cream jaw
    head = m.part("Head", (-15, 0, 0), "Shell")
    head.hull(-17, -15, 2, -1, 5, "skin", [(1, 1)], [(1, 1)])
    head.paint_sym(-17, -15, 2, -1, 0, "cream")
    head.sym(-15, -14, 1, -1, 1, "skin")  # a sleeve into the collar, clear of its steps
    head.hull(-20, -16, 3, 1, 9, "skin", [(1, 1)], [(1, 1)])
    head.paint_sym(-20, -16, 3, 1, 2, "cream")  # the throat
    head.block(-19.5, (-2.8, 2.8, 3.6, 7.4), -22.6, (-1.8, 1.8, 3.4, 5.8), "skin")  # the upper beak, sloping down
    head.block(-19.5, (-2.6, 2.6, 1.6, 3.8), -22.0, (-1.6, 1.6, 2.2, 3.6), "cream")  # the lower jaw, shorter
    # the mouth line: along the foot of the upper beak, then turning up at the back into a smile
    head.beam((-22.35, 1.95, 3.5), (-19.7, 2.82, 3.66), 0.45, 0.35, "mouth", mirror=True)
    head.beam((-19.95, 3.6, 3.7), (-17.9, 3.6, 4.35), 0.45, 0.3, "mouth", mirror=True)
    # the eyes: a cream ring 3 by 3 on each side of the skull, a dark pupil 2 by 2 standing out of it, looking forward
    ring = (3.35, 3.8, 4.8, 7.8)
    head.block(-19.5, ring, -16.5, ring, "cream", mirror=True)
    pupil = (3.65, 4.1, 5.3, 7.3)
    head.block(-19.3, pupil, -17.3, pupil, "black", mirror=True)

    for s, tag in ((1, "R"), (-1, "L")):
        # the front flippers: wings in two turned blocks, an arm out from under the rim and a long blade swept back
        front = m.part(f"FlipF{tag}", (-9.0, 6.5 * s, -1.0), "Shell")
        front.beam((-9.5, 5.5 * s, -1.1), (-7.0, 15.0 * s, -1.35), 4.6, 1.2, "skin", flat="z")
        front.beam((-8.0, 14.0 * s, -1.3), (0.5, 22.5 * s, -1.65), 3.6, 0.8, "skin", flat="z")
        # the back flippers: small paddles
        back = m.part(f"FlipB{tag}", (9.0, 5.5 * s, -1.0), "Shell")
        back.beam((8.4, 5.0 * s, -1.0), (12.0, 9.0 * s, -1.2), 3.0, 1.0, "skin", flat="z")
        back.beam((11.4, 8.4 * s, -1.15), (13.4, 10.4 * s, -1.4), 2.0, 0.6, "skin", flat="z")
