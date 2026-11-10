"""Archelon (zone 1's Legendary: the biggest turtle that ever lived) for tools/blender/voxel_kit.py
(docs/style/04-voxel-style.md), dressed as a Legendary by docs/style/05-rarity-look.md. The shelled body.
Designed from the real animal: a leathery shell stretched over a frame of ribs whose pointed ends stood out round its
edge like a star, a narrow head with a hooked beak, and front flippers longer than the shell.
Its idea: the first giant, and its frame shows through the leather. A spine, the ribs that leave it, and the tips of
those ribs standing out past the shell's dark edge.
- A large animal in its base form, so it is built from small cubes and more of them: the dome falls in six gentle steps
  on the arc of a circle, and from one slice to the next either the width changes by a cube or the height does.
- The shell is deep jade leather, one part. A near-black lip runs all the way round its edge and frames it. A low dark
  ridge runs down the spine. Six thin bone ribs cross the dome from the ridge to the lip; each ends in a bone point past
  the lip, and carries a gold knob where it leaves the spine. Between the ribs the leather is plain.
- The front flippers are wings in three jointed lengths (arm, blade, tip), the bend at the elbow. Each length has a dark
  leading spar and, behind it, fingers fanned like the bones of a hand, each shorter and thinner than the one in front,
  so the trailing edge is feathered, not a plank's. A horn claw on the tip. They beat like wings, each length a little
  behind the one before. The back flippers are the same thing made small, and steer.
- The neck leaves the shell through a dark collar. A narrow head: a dark cap that runs back down the neck, a pale
  throat, a hooked beak of amber horn (the focal point) with the jaw closing inside the hook. An old dark eye with a thin
  halo of soft gold light, under a heavy dark lid.
- The short tail ends in a horn point: the beak's echo.
- Jade, ink, bone and gold. Gold is the signature colour: the knobs and the halo of the eye, nothing else. Only the
  halo glows.
The rider sits on a low hump of the spine's ridge between the two middle ribs, legs either side of it."""
import math

NAME, ZONE, RARITY = "Archelon", "ZONE 1 / SHALLOWS", "LEGENDARY"
U = 0.45
PALETTE = {"shell": "#1C8272", "rim": "#10222A", "skin": "#5B8E88", "belly": "#F1E7C9", "bone": "#F4EBD2", "gold": "#F6BC3F",
           "horn": "#D08B32", "black": "#15171A", "soft": "#F8CF6E"}
SEAT = (1.5, 10, 1.85)
GLOW = {"soft": 0.4}  # only the thin halo of the eye
FRAME, ORTHO, ORTHO_SWIM = 3.1, 72.0, 76.0

# the shell, front to back: (from, to, cubes out either side, the dome's height). From one slice to the next either the
# width changes by a cube or the height does, never both
SLICES = ((-17, -16, 9, 3), (-16, -15, 10, 3), (-15, -13, 10, 4), (-13, -11, 11, 4), (-11, -9, 11, 5), (-9, -8, 12, 5),
          (-8, -6, 12, 6), (-6, -4, 13, 6), (-4, 7, 13, 7), (7, 9, 13, 6), (9, 11, 12, 6), (11, 13, 12, 5), (13, 14, 11, 5),
          (14, 16, 10, 5), (16, 18, 10, 4), (18, 20, 9, 4), (20, 21, 8, 4), (21, 22, 8, 3), (22, 23, 7, 3), (23, 24, 6, 3),
          (24, 25, 6, 2), (25, 26, 5, 2))
RIBS = (-12.0, -7.0, -2.0, 5.0, 10.0, 15.0)  # where a rib of the frame crosses the shell (the rider sits between the middle two)


def pose(parts, phase):
    """it flies: the front flippers beat like wings, each length following the one before a little late; the back
    flippers steer; the shell rocks with each beat; the head nods and the beak works"""
    for tag, side in (("R", 1), ("L", -1)):
        parts[f"Wing{tag}1"].rotation_euler.x = side * math.radians(20) * math.sin(phase)
        parts[f"Wing{tag}2"].rotation_euler.x = side * math.radians(13) * math.sin(phase - 0.9)
        parts[f"Wing{tag}3"].rotation_euler.x = side * math.radians(11) * math.sin(phase - 1.8)
        parts[f"FlipB{tag}"].rotation_euler.z = math.radians(9) * math.sin(phase + 1.2)
        parts[f"FlipB{tag}"].rotation_euler.x = side * math.radians(6) * math.sin(phase + math.pi)
    parts["Shell"].rotation_euler.y = math.radians(2) * math.sin(phase + math.pi / 2)
    parts["Head"].rotation_euler.y = math.radians(4) * math.sin(phase - 0.5)
    parts["Jaw"].rotation_euler.y = -math.radians(7) * (0.5 + 0.5 * math.sin(phase + 2.0))
    parts["Tail"].rotation_euler.z = math.radians(7) * math.sin(phase - 1.5)


def dome(n, high):
    """the steps of the dome over the lip, from the top down, for a slice n cubes out and `high` cubes tall: the rows lie
    on the arc of a circle through the shell's edge and its crown, so each step is a little wider than the one below"""
    rows = high - 1
    rise = rows + 0.3
    radius = (n * n + rise * rise) / (2 * rise)
    steps = []
    for k in range(rows):
        h = rows - k - 0.5
        steps.append((n - round(math.sqrt(max(radius * radius - (radius - rise + h) ** 2, 0.0))), 1))
    return steps


# the plastron, the plate of the underside, in six plates front to back: (from, to, cubes out of its upper row, of its lower
# row). It is its own outline, a cube or more inside the shell's all the way round, so the dark leather shows round it
PLASTRON = ((-16, -12, 7, 5), (-12, -6, 9, 7), (-6, 10, 10, 8), (10, 15, 8, 6), (15, 20, 6, 4), (20, 24, 4, 2))


def fan(part, s, root, droop, rows):
    """boxes lying flat, fanned from `root` like the bones of a hand, on the side s (1 right, -1 left). Each row is
    (angle, from, to, across, width, thickness, colour): the angle is in degrees back from straight out; from and to are
    distances along it; across shifts it toward the trailing edge (negative: the leading edge). It sinks by `droop` a
    cube. Returns a function giving the point at (angle, distance, across)"""
    rx, ry, rz = root

    def at(angle, t, across=0.0, lift=0.0):
        a = math.radians(angle)
        dx, dy = math.sin(a), math.cos(a)
        return (rx + dx * t + dy * across, s * (ry + dy * t - dx * across), rz - droop * t + lift)

    for angle, t0, t1, across, wide, thick, colour in rows:
        part.beam(at(angle, t0, across), at(angle, t1, across), wide, thick, colour, flat="z")
    return at


def build(m):
    shell = m.part("Shell", (0, 0, 0))
    for x0, x1, n, high in SLICES:
        shell.hull(x0, x1, n, -1, high, "shell", dome(n, high))
        shell.paint_sym(x0, x1, n, high - 1, high, "shell+")  # the crown of the dome catches the light
        shell.paint_sym(x0, x1, n, 1, 2, "shell-")  # the foot of the dome, in the lip's shadow
        shell.paint_sym(x0, x1, n, -1, 1, "rim")
        shell.sym(x0, x1, n + 1, 0, 1, "rim")  # the lip: the leather's thick dark edge, a cube proud all the way round
        shell.sym(x0, x1, 0, high, high + 1, "rim")  # the ridge of the spine: a thin dark line
    for x0, x1, upper, lower in PLASTRON:
        shell.sym(x0, x1, upper, -2, -1, "belly")
        shell.sym(x0, x1, lower, -3, -2, "belly-")
    shell.sym(-18, -17, 9, 0, 1, "rim")  # the lip round the front and the back
    shell.sym(26, 27, 5, 0, 1, "rim")
    # the frame under the leather: a thin bone band across the dome at each rib, from the spine's ridge to the lip; the
    # rib's tip stands out past the lip as a bone point, and a gold knob, leaning back, sits where it leaves the spine
    for x in RIBS:
        x0, x1, n, high = next(sl for sl in SLICES if sl[0] <= x - 0.35 and x + 0.35 <= sl[1])
        shell.band(x - 0.3, x + 0.3, n, -1, high, "bone", dome(n, high), (), 0.3, stop=0.9)
        shell.spike([(x - 0.6, n + 1.1, 0.12), (x + 0.6, n + 1.1, 0.12), (x + 0.6, n + 1.1, 0.88), (x - 0.6, n + 1.1, 0.88)],
                    (x + 0.8, n + 3.7, 0.3), "bone", mirror=True)
        z = high - 0.1
        shell.spike([(x - 1.0, -1.0, z), (x + 1.0, -1.0, z), (x + 1.0, 1.0, z), (x - 1.0, 1.0, z)], (x + 0.8, 0.0, high + 2.7), "gold")
    # the seat: the dome rises into a low hump under the ridge between the two middle ribs, narrow enough to sit astride
    shell.sym(-1, 4, 1, 7, 8, "shell+")
    shell.sym(0, 3, 1, 8, 9, "shell+")
    shell.sym(-1, 4, 0, 8, 9, "rim")
    shell.sym(0, 3, 0, 9, 10, "rim")
    # the collar: the thick dark ring of leather the neck comes out through
    shell.hull(-19, -17, 4, -2, 2, "rim", [(1, 1)], [(1, 1)])
    # where the flippers leave the shell the skin shows under the lip
    shell.paint_pair(-14, -9, 8, 12, -1, 0, "skin")
    shell.paint_pair(16, 20, 6, 10, -1, 0, "skin")

    # the head, on its own joint: a short neck, a narrow skull, a strongly hooked beak of amber horn
    head = m.part("Head", (-19, 0, -0.5), "Shell")
    head.sym(-22, -19, 2, -2, 2, "skin")
    head.paint_sym(-22, -19, 2, -2, -1, "belly")
    head.paint_sym(-22, -19, 2, 1, 2, "rim")  # the dark cap runs back down the neck into the collar
    head.sym(-19, -17, 1, -1, 1, "skin-")  # a sleeve into the collar, clear of its steps
    head.hull(-28, -22, 3, -2, 3, "skin", [(1, 1)], [(1, 1)])
    head.paint_sym(-28, -22, 3, -2, -1, "belly")  # a pale throat
    head.paint_sym(-28, -22, 3, 2, 3, "rim")  # a dark cap on the skull
    # the beak: one block that narrows and slopes nose-down from the skull, then the hook: a point turned down and back
    head.block(-27.6, (-2.6, 2.6, -0.9, 2.4), -32.4, (-1.2, 1.2, -1.6, 0.6), "horn")
    head.spike([(-32.3, -1.05, -1.2), (-30.7, -1.05, -1.2), (-30.7, 1.05, -1.2), (-32.3, 1.05, -1.2)], (-31.0, 0.0, -4.3), "horn")
    # the eye: a dark socket on the skull's side, a thin halo of soft gold light, an old dark pupil standing out of it.
    # The heavy lid sits on the eye: it covers the top of the socket and of the pupil, more at the front, and stands
    # only a little proud of the pupil
    socket = (3.4, 3.85, -0.2, 2.0)
    head.block(-25.9, socket, -23.7, socket, "rim", mirror=True)
    halo = (3.75, 4.0, 0.15, 1.65)
    head.block(-25.55, halo, -24.05, halo, "soft", mirror=True)
    pupil = (3.9, 4.2, 0.45, 1.35)
    head.block(-25.25, pupil, -24.35, pupil, "black", mirror=True)
    head.beam((-26.2, 3.76, 1.55), (-23.4, 3.76, 1.95), 1.0, 1.12, "rim", mirror=True)

    # the lower jaw, on its own joint: a horn wedge that closes inside the hook
    jaw = m.part("Jaw", (-27.5, 0, -1.6), "Head")
    jaw.block(-27.6, (-2.2, 2.2, -1.85, -1.05), -30.4, (-1.0, 1.0, -2.05, -1.5), "horn-")

    for s, tag in ((1, "R"), (-1, "L")):
        # the front flippers, in three jointed lengths. The arm goes out and a little forward from under the lip; the
        # blade turns back from the elbow; the tip turns back again. Each has a dark leading spar and fingers fanned
        # behind it, each shorter and thinner than the one in front and starting inside it
        arm = m.part(f"Wing{tag}1", (-11.5, 10.5 * s, -1.0), "Shell")
        at = fan(arm, s, (-11.5, 9.0, -1.0), 0.04,
                 ((-8, 0.0, 10.0, -1.6, 1.6, 2.6, "rim"), (-8, 0.4, 9.8, 0.3, 3.6, 2.1, "skin"), (2, 0.3, 8.6, 2.9, 2.6, 1.3, "skin")))
        ex, ey, ez = at(-8, 9.6)
        blade = m.part(f"Wing{tag}2", (ex, ey, ez), f"Wing{tag}1")
        at = fan(blade, s, (ex, ey * s, ez), 0.04,
                 ((27, -1.0, 10.6, -1.0, 1.5, 1.8, "rim"), (33, -1.6, 10.2, 0.6, 3.0, 1.5, "skin"), (45, -1.4, 9.0, 1.5, 2.8, 1.0, "skin"),
                  (59, -1.2, 7.2, 2.1, 2.6, 0.55, "skin-")))
        wx, wy, wz = at(27, 10.3)
        tip = m.part(f"Wing{tag}3", (wx, wy, wz), f"Wing{tag}2")
        at = fan(tip, s, (wx, wy * s, wz), 0.04,
                 ((46, -1.0, 10.0, -0.8, 1.2, 1.25, "rim"), (53, -1.4, 7.8, 0.4, 2.4, 0.8, "skin"), (68, -1.2, 5.6, 1.0, 2.2, 0.35, "skin-")))
        end = 9.8
        tip.spike([at(46, end, -1.2, -0.45), at(46, end, -0.4, -0.45), at(46, end, -0.4, 0.45), at(46, end, -1.2, 0.45)],
                  at(46, end + 2.4, -0.5), "horn")
        # the back flippers: the same hand, small, one joint each
        back = m.part(f"FlipB{tag}", (18.0, 7.0 * s, -1.0), "Shell")
        fan(back, s, (18.0, 5.5, -1.0), 0.05,
            ((50, -1.5, 9.4, -0.9, 1.4, 1.5, "rim"), (58, -1.2, 8.6, 0.5, 2.8, 1.1, "skin"), (73, -0.6, 6.4, 1.3, 2.4, 0.6, "skin-")))

    # the tail: short, in two boxes, ending in a horn point (the echo of the beak)
    tail = m.part("Tail", (26.0, 0, -0.4), "Shell")
    tail.beam((25.4, 0, -0.4), (29.6, 0, -0.8), 2.6, 1.6, "skin", flat="z")
    tail.beam((28.6, 0, -0.7), (31.4, 0, -1.0), 1.7, 1.1, "skin-", flat="z")
    tail.spike([(30.9, -0.6, -1.4), (30.9, 0.6, -1.4), (30.9, 0.6, -0.5), (30.9, -0.6, -0.5)], (34.0, 0.0, -1.2), "horn")
