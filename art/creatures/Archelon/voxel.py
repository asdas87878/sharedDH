"""Archelon (zone 1's Legendary: the biggest turtle that ever lived) for tools/blender/voxel_kit.py
(docs/style/04-voxel-style.md), dressed as a Legendary by docs/style/05-rarity-look.md. The shelled body.
Designed from the real animal: a leathery shell stretched over a frame of ribs whose pointed ends stood out round its
edge like a star, a narrow head with a hooked beak, and front flippers longer than the shell.
Its idea: the first giant, and its frame shows through the leather. A spine, the ribs that leave it, and the tips of
those ribs standing out past the shell's dark edge.
- The carapace is a shell, not a dome of steps: one cross-section, scaled along the body. A short wall above the lip, a
  steep lower shoulder, a gentle upper shoulder, and a wide flat plateau across half its width. Each stretch between two
  ribs is one faceted block, so the slopes are whole turned faces (the style's rule: a slope is a block turned).
- It is a thick animal, as a turtle this size is: the body is about a third as deep as the shell is long. Under the lip
  there is a real underbody, dark leather that turns in to the plastron. The lip and the underbody are cubes.
- The shell is deep jade leather, one part. A near-black lip runs all the way round its edge and frames it. A low dark
  keel runs down the spine. Six thin bone ribs cross the shell from lip to lip; each ends in a bone point past the lip,
  and carries a gold knob where it crosses the spine. Between the ribs the leather is plain.
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
SEAT = (1.5, 12.5, 1.85)
GLOW = {"soft": 0.4}  # only the thin halo of the eye
FRAME, ORTHO, ORTHO_SWIM = 3.1, 72.0, 76.0

# the carapace's cross-section at full size, from the lip up: (cubes out, cubes above the lip). A short wall, a steep
# lower shoulder, a gentle upper shoulder, then the plateau: flat, and half the shell's width
PROFILE = ((13.5, 1.8), (11.5, 6.0), (7.0, 8.5))
LIP = 1  # the height of the lip's top: the carapace stands on it
# along the body: (x, the cross-section's scale, whether a rib of the frame crosses here). The first and last stretches
# are the blunt ends over the front and back lips
STATIONS = ((-17.7, 0.45, False), (-17, 0.68, False), (-12, 0.84, True), (-7, 0.96, True), (-2, 1.0, True), (5, 1.0, True),
            (10, 0.92, True), (15, 0.80, True), (20.5, 0.64, False), (26, 0.44, False), (26.7, 0.24, False))
BODY = (-17, 26)  # the lip and the underbody run between these


def scale_at(x):
    for (xa, sa, _), (xb, sb, _) in zip(STATIONS, STATIONS[1:]):
        if xa <= x <= xb:
            return sa + (sb - sa) * (x - xa) / (xb - xa)
    return STATIONS[-1][1]


def crown(x):
    """the height of the plateau at x"""
    return LIP + PROFILE[-1][1] * scale_at(x)


def out_at(x):
    """how many cubes out the body's cubes go in the column from x to x + 1: enough to carry the carapace's wall"""
    return math.ceil(PROFILE[0][0] * max(scale_at(x), scale_at(x + 1)) - 0.5)


def section(x, scale, wide=1.0, tall=1.0, base=0.5):
    """the corners of the cross-section at x, right round: its foot is sunk into the lip"""
    half = [(PROFILE[0][0] * scale * wide, LIP - base)] + [(y * scale * wide, LIP + h * scale * tall) for y, h in PROFILE]
    return [(x, y, z) for y, z in half] + [(x, -y, z) for y, z in reversed(half)]


def stretch(part, xa, sa, xb, sb, colour, **how):
    """one faceted block of the carapace between two cross-sections"""
    a, b = section(xa, sa, **how), section(xb, sb, **how)
    n = len(a)
    part.solid(a + b, [tuple(range(n)), tuple(range(n, 2 * n))] + [(i, (i + 1) % n, n + (i + 1) % n, n + i) for i in range(n)], colour)


RIBS = tuple(x for x, _, rib in STATIONS if rib)


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


# the plastron, the plate of the underside, in six plates front to back: (from, to). Each is two rows, three cubes and
# five inside the body's outline, so the dark leather shows round it
PLASTRON = ((-16, -12), (-12, -6), (-6, 10), (10, 15), (15, 20), (20, 24))


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
    # the lip and the underbody, in cubes: dark leather. The lip stands a cube proud all the way round and frames the
    # shell; under it the body turns in, in two steps, to the plastron
    outs = {x: out_at(x) for x in range(BODY[0], BODY[1])}
    for x, n in outs.items():
        shell.hull(x, x + 1, n, -3, LIP, "rim", (), [(2, 1), (1, 1)])
        shell.sym(x, x + 1, n + 1, 0, LIP, "rim")
    for x0, x1 in PLASTRON:
        n = min(outs[x] for x in range(x0, x1))
        shell.sym(x0, x1, n - 3, -4, -3, "belly")
        shell.sym(x0, x1, n - 5, -5, -4, "belly-")
    shell.sym(BODY[0] - 1, BODY[0], outs[BODY[0]], 0, LIP, "rim")  # the lip round the front and the back
    shell.sym(BODY[1], BODY[1] + 1, outs[BODY[1] - 1], 0, LIP, "rim")
    # the carapace: a faceted block between each pair of cross-sections, and a dark keel down the spine on each
    for (xa, sa, rib_a), (xb, sb, rib_b) in zip(STATIONS, STATIONS[1:]):
        stretch(shell, xa, sa, xb, sb, "shell")
        if BODY[0] <= xa and xb <= BODY[1]:
            ka, kb = xa + (0.25 if rib_a else 0.0), xb - (0.25 if rib_b else 0.0)  # it ends inside a rib, where there is one
            za, zb = crown(ka), crown(kb)
            shell.solid([(ka, -0.5, za - 0.3), (ka, 0.5, za - 0.3), (ka, 0.5, za + 0.25), (ka, -0.5, za + 0.25),
                         (kb, -0.5, zb - 0.3), (kb, 0.5, zb - 0.3), (kb, 0.5, zb + 0.25), (kb, -0.5, zb + 0.25)],
                        [(0, 1, 2, 3), (4, 5, 6, 7), (0, 1, 5, 4), (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7)], "rim")
    # the frame under the leather: a thin bone rib across the shell at each station, a little proud of it; its tip stands
    # out past the lip as a bone point, and a gold knob, leaning back, sits where it crosses the spine
    for x in RIBS:
        sc = scale_at(x)
        stretch(shell, x - 0.3, sc, x + 0.3, sc, "bone", wide=1.035, tall=1.07, base=0.25)
        n = min(outs[int(math.floor(x - 0.6))], outs[int(math.floor(x + 0.6))])
        shell.spike([(x - 0.6, n + 1.1, 0.12), (x + 0.6, n + 1.1, 0.12), (x + 0.6, n + 1.1, 0.88), (x - 0.6, n + 1.1, 0.88)],
                    (x + 0.8, n + 3.7, 0.3), "bone", mirror=True)
        z = crown(x) - 0.35
        shell.spike([(x - 1.0, -1.0, z), (x + 1.0, -1.0, z), (x + 1.0, 1.0, z), (x - 1.0, 1.0, z)], (x + 0.8, 0.0, crown(x) + 2.9), "gold")
    # the seat: a low saddle on the plateau between the two middle ribs, narrow enough to sit astride, the keel over it
    top = crown(1.5)
    saddle = (-1.5, 1.5, top - 0.2, top + 1.1)
    shell.block(-0.5, saddle, 3.5, saddle, "shell+")
    pommel = (-1.2, 1.2, top + 0.9, top + 2.2)
    shell.block(0.2, pommel, 2.8, pommel, "shell+")
    cap = (-0.5, 0.5, top + 2.0, top + 3.0)
    shell.block(0.5, cap, 2.5, cap, "rim")
    # the collar: the thick dark ring of leather the neck comes out through
    shell.hull(-19, -17, 5, -3, 3, "rim", [(2, 1), (1, 1)], [(1, 1)])
    # where the flippers leave the shell the skin shows under the lip
    shell.paint_pair(-14, -9, 8, 12, -1, 0, "skin")
    shell.paint_pair(16, 20, 6, 10, -1, 0, "skin")

    # the head, on its own joint: a short neck, a narrow skull, a strongly hooked beak of amber horn
    head = m.part("Head", (-19, 0, -0.5), "Shell")
    head.sym(-22, -19, 3, -2, 2, "skin")
    head.paint_sym(-22, -19, 3, -2, -1, "belly")
    head.paint_sym(-22, -19, 3, 1, 2, "rim")  # the dark cap runs back down the neck into the collar
    head.sym(-19, -17, 2, -1, 1, "skin-")  # a sleeve into the collar, clear of its steps
    head.hull(-28, -22, 4, -3, 3, "skin", [(2, 1), (1, 1)], [(1, 1)])
    head.paint_sym(-28, -22, 4, -3, -1, "belly")  # a pale throat
    head.paint_sym(-28, -22, 4, 2, 3, "rim")  # a dark cap on the skull
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
