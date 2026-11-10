"""Archelon (zone 1's Legendary: the biggest turtle that ever lived) for tools/blender/voxel_kit.py
(docs/style/04-voxel-style.md), dressed as a Legendary by docs/style/05-rarity-look.md. The shelled body.
Its idea: the first giant. A great leathery kite of a turtle that flies through the shallows on wings wider than itself.
- The shell is a low dome of stepped slabs, one part. It is leather, not plates: plain, with the ribs of its frame showing
  through as thin pale bands across it, and a gold knob where each rib meets the spine.
- The front flippers are the animal: wings, each in two jointed lengths. Each length is built like a wing: a leading spar
  in the shell's leather with paler plates behind it, each shorter than the one in front, so the trailing edge steps in
  to a tip, which ends in a horn claw. They beat like wings, the outer length a little behind the inner. The back
  flippers are the same thing made small, and steer.
- A narrow head on a short neck, a cap of the shell's leather on the skull. The beak is dark horn: it narrows and turns
  down into a strong hook (the focal point),
  and the lower jaw, on its own joint, closes inside the hook. An old dark eye in a gold ring, under a heavy lid.
- The short tail ends in a horn point: the beak's echo.
- Warm and sunlit, for the Shallows: sunlit green leather, sand skin, a cream underside and ribs. Gold is its signature
  colour, used only on the knobs and the ring of the eye. Nothing glows: it is a Legendary by size and shape.
The rider sits on the crown of the dome between two ribs, legs in a shallow notch either side."""
import math

NAME, ZONE, RARITY = "Archelon", "ZONE 1 / SHALLOWS", "LEGENDARY"
U = 0.5
PALETTE = {"shell": "#44855A", "skin": "#DDBD7E", "belly": "#F3E8C8", "gold": "#F5B83D", "horn": "#6E4E2E", "black": "#2A2B2E"}
SEAT = (0, 6, 3.6)
FRAME, ORTHO, ORTHO_SWIM = 3.1, 72.0, 76.0

# the shell, front to back: (from, to, cubes out either side, the dome's height). From one slice to the next either the
# width changes by a cube or the height does, never both
SLICES = ((-14, -13, 7, 3), (-13, -12, 8, 3), (-12, -10, 8, 4), (-10, -8, 9, 4), (-8, -6, 10, 4), (-6, -4, 10, 5), (-4, -2, 11, 5),
          (-2, 3, 11, 6), (3, 5, 11, 5), (5, 7, 10, 5), (7, 9, 10, 4), (9, 11, 9, 4), (11, 13, 8, 4), (13, 14, 8, 3), (14, 15, 7, 3),
          (15, 16, 6, 3), (16, 17, 6, 2), (17, 18, 5, 2), (18, 19, 4, 2))
RIBS = (-11.0, -7.0, -3.0, 2.0, 6.0, 10.0)  # where a rib of the frame shows across the shell (the rider sits between two)
# how far in each row of the dome steps, from the top down, by the number of rows above the rim
DOME = {5: (0.73, 0.45, 0.32, 0.18, 0.07), 4: (0.73, 0.45, 0.27, 0.09), 3: (0.6, 0.32, 0.1), 2: (0.45, 0.14), 1: (0.25,)}


def pose(parts, phase):
    """it flies: the front flippers beat like wings, the outer length following a little late; the back flippers steer;
    the shell rocks with each beat; the head nods and the beak works"""
    for name, side in (("WingR1", 1), ("WingL1", -1)):
        parts[name].rotation_euler.x = side * math.radians(22) * math.sin(phase)
    for name, side in (("WingR2", 1), ("WingL2", -1)):
        parts[name].rotation_euler.x = side * math.radians(14) * math.sin(phase - 1.0)
    for name, side in (("FlipBR", 1), ("FlipBL", -1)):
        parts[name].rotation_euler.z = math.radians(9) * math.sin(phase + 1.2)
        parts[name].rotation_euler.x = side * math.radians(6) * math.sin(phase + math.pi)
    parts["Shell"].rotation_euler.y = math.radians(2) * math.sin(phase + math.pi / 2)
    parts["Head"].rotation_euler.y = math.radians(4) * math.sin(phase - 0.5)
    parts["Jaw"].rotation_euler.y = -math.radians(7) * (0.5 + 0.5 * math.sin(phase + 2.0))
    parts["Tail"].rotation_euler.z = math.radians(7) * math.sin(phase - 1.5)


def dome(n, high):
    """the steps of the dome over the rim, from the top down, for a slice n cubes out and `high` cubes tall"""
    return [(max(1, round(n * f)), 1) for f in DOME[high - 1]]


def under(n):
    """the steps of the underside, from the bottom up"""
    steps = []
    for f in (0.36, 0.18):
        inset = max(1, round(n * f))
        if not steps or inset < steps[-1][0]:
            steps.append((inset, 1))
    return steps


def wing(part, s, a, b, rows, claw=0.0):
    """a flipper built like a wing, on the side s (1 right, -1 left): boxes lying flat along the line from a to b, each
    row (from, to, how far behind the line, width, thickness, colour) with distances in cubes. The first is the leading
    spar; the rows behind are shorter and thinner, and each starts a little inside the one in front. claw: a horn point
    this long on the end of the line"""
    (ax, ay, az), (bx, by, bz) = a, b
    length = math.hypot(bx - ax, by - ay)
    dx, dy, slope = (bx - ax) / length, (by - ay) / length, (bz - az) / length
    qx, qy = dy, -dx  # across the line, toward the trailing edge

    def at(t, back, lift=0.0):
        return (ax + dx * t + qx * back, s * (ay + dy * t + qy * back), az + slope * t + lift)

    for t0, t1, back, wide, thick, colour in rows:
        part.beam(at(t0, back), at(t1, back), wide, thick, colour, flat="z")
    if claw:
        t = length - 0.2
        part.spike([at(t, -0.9, -0.45), at(t, 0.9, -0.45), at(t, 0.9, 0.45), at(t, -0.9, 0.45)], at(length + claw, 0.5), "horn")


def build(m):
    shell = m.part("Shell", (0, 0, 0))
    for x0, x1, n, high in SLICES:
        top, bottom = dome(n, high), under(n)
        low = -1 - len(bottom)
        shell.hull(x0, x1, n, low, high, "shell", top, bottom)
        shell.paint_sym(x0, x1, n, high - 1, high, "shell+")  # the crown of the dome catches the light
        shell.paint_sym(x0, x1, n, -1, 1, "shell-")  # the rim: the leather's thick edge
        shell.paint_sym(x0, x1, n, low, -1, "belly")
        shell.paint_sym(x0, x1, n, low, low + 1, "belly-")
    # the frame under the leather: a thin pale band across the dome at each rib, from one side to the other (it stops
    # short of the rim), and a gold knob, leaning back, where it meets the spine
    for x in RIBS:
        x0, x1, n, high = next(sl for sl in SLICES if sl[0] <= x - 0.3 and x + 0.3 <= sl[1])
        bottom = under(n)
        shell.band(x - 0.25, x + 0.25, n, -1 - len(bottom), high, "belly", dome(n, high), bottom, 0.3, stop=1.3)
        z = high - 0.1
        shell.spike([(x - 0.95, -0.85, z), (x + 0.95, -0.85, z), (x + 0.95, 0.85, z), (x - 0.95, 0.85, z)], (x + 0.7, 0.0, high + 1.7), "gold")
    # the seat: on the crown of the dome between two ribs, a shallow notch either side for the rider's legs (0.3 in and
    # 0.3 down, so no face of it lies in the plane of the crown)
    shell.carve_pair(-1, 1, 3, 4, 5, 6)
    notch = (2.45, 3.2, 4.95, 5.7)
    shell.block(-1, notch, 1, notch, "shell-", mirror=True)

    # the head, on its own joint: a short neck, a narrow skull, a strongly hooked beak of dark horn
    head = m.part("Head", (-14, 0, -0.5), "Shell")
    head.sym(-17, -14, 2, -2, 1, "skin")
    head.paint_sym(-17, -14, 2, -2, -1, "skin-")
    head.sym(-14, -12, 1, -1, 1, "skin-")  # a sleeve into the shell, clear of its steps
    head.hull(-22, -17, 3, -2, 2, "skin", [(1, 1)], [(1, 1)])
    head.paint_sym(-22, -17, 3, -2, -1, "skin-")
    head.paint_sym(-22, -17, 3, 1, 2, "shell")  # a cap of the shell's leather on the skull
    # the beak: one block that narrows and slopes nose-down from the skull, then the hook: a point turned down and back
    head.block(-21.6, (-2.4, 2.4, -0.9, 1.7), -25.6, (-1.1, 1.1, -1.3, 0.6), "horn")
    head.spike([(-25.5, -0.95, -1.0), (-24.2, -0.95, -1.0), (-24.2, 0.95, -1.0), (-25.5, 0.95, -1.0)], (-24.5, 0.0, -3.4), "horn")
    # the eye: a gold ring on the skull's side, an old dark pupil standing out of it. The heavy lid sits on the eye: it
    # covers the top of the ring and of the pupil, more at the front, and stands only a little proud of the pupil
    ring = (3.4, 3.9, -0.4, 1.4)
    head.block(-20.6, ring, -18.8, ring, "gold", mirror=True)
    pupil = (3.8, 4.15, 0.0, 1.0)
    head.block(-20.2, pupil, -19.2, pupil, "black", mirror=True)
    head.beam((-20.9, 3.785, 1.05), (-18.5, 3.785, 1.45), 1.0, 0.97, "skin-", mirror=True)

    # the lower jaw, on its own joint: a horn wedge that closes inside the hook
    jaw = m.part("Jaw", (-21.5, 0, -1.5), "Head")
    jaw.block(-21.6, (-2.0, 2.0, -1.8, -1.05), -24.0, (-0.9, 0.9, -1.95, -1.45), "horn-")

    for s, tag in ((1, "R"), (-1, "L")):
        # the front flippers, in two jointed lengths, each built like a wing: a leading spar in the shell's leather with
        # paler plates behind it. The arm is rooted in the shell's rim; the outer length has two plates, each shorter than
        # the one in front, and a horn claw on the tip
        arm = m.part(f"Wing{tag}1", (-10.5, 8.5 * s, -0.2), "Shell")
        wing(arm, s, (-11.3, 7.0, -0.2), (-10.6, 15.6, -0.5), ((0.0, 8.63, 0.0, 2.8, 1.7, "shell"), (0.4, 8.2, 3.0, 3.8, 1.1, "skin")))
        blade = m.part(f"Wing{tag}2", (-10.7, 15.0 * s, -0.47), f"Wing{tag}1")
        wing(blade, s, (-10.85, 14.6, -0.47), (-0.9, 31.0, -1.0),
             ((0.0, 19.18, 0.0, 2.4, 1.4, "shell"), (0.6, 15.0, 2.4, 3.0, 0.7, "skin"), (1.0, 10.0, 5.0, 2.8, 0.4, "skin")), claw=2.6)
        # the back flippers: the same wing, small, one joint each
        back = m.part(f"FlipB{tag}", (14.0, 6.0 * s, -0.45), "Shell")
        wing(back, s, (13.5, 5.0, -0.4), (20.5, 10.0, -0.9), ((0.0, 8.6, 0.0, 3.0, 1.0, "shell"), (2.5, 6.6, 1.9, 1.6, 0.6, "skin")))

    # the tail: short, ending in a horn point (the echo of the beak)
    tail = m.part("Tail", (18.5, 0, -0.3), "Shell")
    tail.beam((18.4, 0, -0.3), (22.0, 0, -0.7), 2.2, 1.4, "skin", flat="z")
    tail.spike([(21.4, -0.7, -1.13), (21.4, 0.7, -1.13), (21.4, 0.7, -0.13), (21.4, -0.7, -0.13)], (24.6, 0.0, -1.0), "horn")
