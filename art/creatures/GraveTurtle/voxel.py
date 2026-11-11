"""The Grave Turtle (zone 9's Legendary: the Archelon again, undead) for tools/blender/voxel_kit.py
(docs/style/04-voxel-style.md), dressed as a Legendary by docs/style/05-rarity-look.md. A variant of
art/creatures/Archelon/voxel.py: the same animal, the same eight-block shell, the same size and seat.
Its idea: the first giant, long dead and still swimming. What was a frame showing through the leather is now bare bone.
- The shell is dead grey-green leather over the same eight blocks. The spine is a bare bone line down the whole animal
  (neck, shell, tail), with a low bone knob at each rib. The six ribs are bare bone bands from lip to lip, their tips
  standing out past the dark lip.
- Three shell plates are gone and a dark hollow shows: a big one front right, a big one behind the seat on the left
  (a bare rib crosses each), a small one at the back on the right. None is at the seat.
- The head is a skull: bone-ivory, a heavy brow that slants down to the front and comes past the socket, a cheekbone
  under it, a nostril hole, a dark line between beak and jaw. The socket is a real hollow, a cube deep, and a small cold
  teal light sits in it: the focal point, and the only thing that glows. The hollows of the shell are its echo.
- The flippers keep the Archelon's three jointed lengths and dark leading spars, but the trailing edge is tattered:
  the last finger of the blade, the tip and the back flipper is torn into tabs of uneven length. On the tip the skin
  stops short and the spar is bare bone to the claw.
- Grey-green, bone-ivory, a dark slate lip and underbody, deep navy hollows, one teal light.
The rider sits on the spine between the two middle ribs, as on the Archelon."""
import math

NAME, ZONE, RARITY = "Grave Turtle", "ZONE 9 / BONE GRAVEYARD", "LEGENDARY"
U = 0.45
PALETTE = {"shell": "#6F8A7A", "rim": "#28363E", "skin": "#8FA391", "bone": "#EEE6CC", "hollow": "#18212E", "teal": "#58E6D2"}
SEAT = (1.5, 12, 1.85)
GLOW = {"teal": 0.8}  # only the small cold light in the socket
KEEP = ["hollow", "teal"]
FRAME, ORTHO, ORTHO_SWIM = 3.1, 72.0, 76.0
TEXTURES = [{"tile": "stud", "on": "top", "colours": ["shell"]}]

# the shell, front to back, in eight big blocks: (from, to, cubes out either side, the height of its crown). From the side
# the crowns make a dome: a quick rise from the neck, the crown, a slower fall to the tail
SLICES = ((-17, -14, 9, 6), (-14, -9, 11, 8), (-9, -4, 12, 10), (-4, 7, 13, 11), (7, 12, 12, 10), (12, 17, 11, 8), (17, 22, 9, 6),
          (22, 26, 7, 4))
RIBS = (-11.5, -6.5, -1.5, 4.5, 9.5, 14.5)  # where a rib of the frame crosses the shell, each in the middle of a block
LIP = 1  # the height of the lip's top
# the missing plates: (from, to, side, the cube columns of the ribs at its ends, which stay). The leather between two
# ribs is gone from the spine's side to the foot of the shell: two cubes down from the top and one in from the side,
# the dark inside shows, and the two ribs stand bare either side of it
HOLES = ((-12, -6, 1, (-12, -7)), (9, 15, -1, (9, 14)), (18, 21, 1, ()))


def shoulders(n, high):
    """a block's corners from the top down, as (cubes in from the side, cubes tall): a wide flat plateau, then one broad
    shoulder step and a small one under it. Big steps, so the block stays a block"""
    if n >= 12:
        return [(4, 2), (1, 3)]
    if n >= 10:
        return [(3, 2), (1, 2)]
    if n >= 8:
        return [(3, 1), (1, 2)]
    return [(2, 1), (1, 1)]


def pose(parts, phase):
    """it flies: the front flippers beat like wings, each length following the one before a little late; the back
    flippers steer; the shell rocks with each beat; the head nods and the jaw works"""
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
# five inside the body's outline, so the dark leather shows round it. Bare bone now
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
    under = [(2, 1), (1, 1)]  # under the lip the body turns in, in two steps, to the plastron
    for x0, x1, n, high in SLICES:
        shell.hull(x0, x1, n, -3, high, "shell", shoulders(n, high), under)
        shell.paint_sym(x0, x1, n, high - 1, high, "shell+")  # the plateau catches the light
        shell.paint_sym(x0, x1, n, LIP, LIP + 1, "shell-")  # the foot of the shell, in the lip's shadow
        shell.paint_sym(x0, x1, n, -3, LIP, "rim")  # the underbody: dark leather
        shell.sym(x0, x1, n + 1, 0, LIP, "rim")  # the lip: the leather's thick dark edge, a cube proud all the way round
        shell.sym(x0, x1, 0, high, high + 1, "bone")  # the spine: a bare bone line down the whole shell
    for x0, x1 in PLASTRON:
        n = min(sl[2] for sl in SLICES if sl[0] < x1 and x0 < sl[1])
        shell.sym(x0, x1, n - 3, -4, -3, "bone")
        shell.sym(x0, x1, n - 5, -5, -4, "bone-")
    shell.sym(-18, -17, SLICES[0][2], 0, LIP, "rim")  # the lip round the front and the back
    shell.sym(26, 27, SLICES[-1][2] - 1, 0, LIP, "rim")
    # the missing plates: the leather is cut away and what is left under it is dark. The ribs at the hole's ends stay
    # at their full height, as bare bone walls
    whole = set(shell.cells)
    for x0, x1, side, ribs in HOLES:
        for i, j, k in sorted(whole):
            if not (x0 <= i < x1 and j * side >= 2 and k > LIP):
                continue
            if i in ribs:
                shell.cells[(i, j, k)] = "bone"
            elif (i, j + side, k) in whole and (i, j, k + 2) in whole:
                shell.cells[(i, j, k)] = "hollow"
            else:
                del shell.cells[(i, j, k)]
    # the frame, bare: a bone band across the shell at each rib, from lip to lip over the plateau; the rib's tip stands
    # out past the lip as a bone point, and a low bone knob, leaning back, sits where it crosses the spine
    for x in RIBS:
        x0, x1, n, high = next(sl for sl in SLICES if sl[0] <= x - 0.35 and x + 0.35 <= sl[1])
        shell.band(x - 0.35, x + 0.35, n, -3, high, "bone", shoulders(n, high), under, 0.3, stop=0.9)
        shell.spike([(x - 0.6, n + 1.1, 0.12), (x + 0.6, n + 1.1, 0.12), (x + 0.6, n + 1.1, 0.88), (x - 0.6, n + 1.1, 0.88)],
                    (x + 0.8, n + 3.7, 0.3), "bone", mirror=True)
        z = high - 0.1
        shell.spike([(x - 0.9, -0.9, z), (x + 0.9, -0.9, z), (x + 0.9, 0.9, z), (x - 0.9, 0.9, z)], (x + 0.7, 0.0, high + 2.2), "bone-")
    # the collar: the thick dark ring of leather the neck comes out through
    shell.hull(-19, -17, 5, -3, 3, "rim", [(2, 1), (1, 1)], [(1, 1)])
    # where the flippers leave the shell the skin shows under the lip
    shell.paint_pair(-14, -9, 8, 12, -1, 0, "skin")
    shell.paint_pair(16, 20, 6, 10, -1, 0, "skin")

    # the head, on its own joint: a short neck of dead skin with the spine's bone line on it, and a skull
    head = m.part("Head", (-19, 0, -0.5), "Shell")
    head.sym(-22, -19, 2, -3, 2, "skin")
    head.paint_sym(-22, -19, 2, -3, -1, "skin-")
    head.paint_sym(-22, -19, 2, 1, 2, "rim")  # the dark cap runs back down the neck into the collar
    head.paint_sym(-22, -19, 0, 1, 2, "bone")  # and the spine runs up it to the skull
    head.sym(-19, -17, 1, -1, 1, "skin-")  # a sleeve into the collar, clear of its steps
    head.hull(-28, -22, 3, -3, 3, "bone", [(1, 1)], [(1, 1)])
    head.sym(-27, -22, 4, -2, 0, "bone")  # the cheekbone, under the socket
    head.paint_sym(-28, -22, 4, -3, -1, "bone-")  # the underside of the skull, in shadow
    head.paint_sym(-28, -22, 3, 2, 3, "bone+")
    # the beak: one block that narrows and slopes nose-down from the skull, then the hook: a point turned down and back
    head.block(-27.6, (-2.6, 2.6, -0.9, 2.4), -32.4, (-1.2, 1.2, -1.6, 0.6), "bone")
    head.spike([(-32.3, -1.05, -1.2), (-30.7, -1.05, -1.2), (-30.7, 1.05, -1.2), (-32.3, 1.05, -1.2)], (-31.0, 0.0, -4.3), "bone-")
    nostril = (1.15, 2.2, 0.5, 1.1)  # a nostril hole, as a skull has
    head.block(-30.5, nostril, -29.7, nostril, "hollow", mirror=True)
    # the dark of the mouth, between the beak and the jaw and set in from the edges of both: a thin dark line
    head.block(-27.6, (-1.9, 1.9, -1.75, -0.7), -30.0, (-0.8, 0.8, -2.05, -1.15), "hollow")
    # the socket: a real hollow in the skull's side, a cube deep, and a small cold light far in. The heavy brow roofs it:
    # it slants down to the front, cuts the socket's top and comes past it
    head.carve_pair(-26, -23, 3, 4, 0, 2)
    head.paint_pair(-26, -23, 2, 3, 0, 2, "hollow")
    light = (2.3, 2.95, 0.45, 1.25)
    head.block(-25.0, light, -24.15, light, "teal", mirror=True)
    head.beam((-26.9, 3.3, 1.55), (-22.4, 3.3, 2.38), 1.1, 2.0, "bone", mirror=True)

    # the lower jaw, on its own joint: a bone wedge that closes inside the hook
    jaw = m.part("Jaw", (-27.5, 0, -1.6), "Head")
    jaw.block(-27.6, (-2.2, 2.2, -2.15, -1.35), -30.4, (-1.0, 1.0, -2.35, -1.8), "bone-")

    for s, tag in ((1, "R"), (-1, "L")):
        # the front flippers, in three jointed lengths, as the Archelon's. Behind the leading spar the fingers of dead
        # skin; the last finger of the blade and the tip is torn into tabs of uneven length, with gaps. The tip's spar
        # is bare bone and its skin stops short
        arm = m.part(f"Wing{tag}1", (-11.5, 10.5 * s, -1.0), "Shell")
        at = fan(arm, s, (-11.5, 9.0, -1.0), 0.04,
                 ((-8, 0.0, 10.0, -1.6, 1.6, 2.6, "rim"), (-8, 0.4, 9.8, 0.3, 3.6, 2.1, "skin"), (2, 0.3, 8.6, 2.9, 2.6, 1.3, "skin-")))
        ex, ey, ez = at(-8, 9.6)
        blade = m.part(f"Wing{tag}2", (ex, ey, ez), f"Wing{tag}1")
        at = fan(blade, s, (ex, ey * s, ez), 0.04,
                 ((27, -1.0, 10.6, -1.0, 1.5, 1.8, "rim"), (33, -1.6, 10.2, 0.6, 3.0, 1.5, "skin"), (45, -1.4, 7.4, 1.5, 2.8, 1.0, "skin"),
                  (59, -1.2, 2.4, 2.1, 2.6, 0.55, "skin-"), (59, 3.9, 6.6, 1.8, 2.0, 0.4, "skin-")))
        wx, wy, wz = at(27, 10.3)
        tip = m.part(f"Wing{tag}3", (wx, wy, wz), f"Wing{tag}2")
        at = fan(tip, s, (wx, wy * s, wz), 0.04,
                 ((46, -1.0, 10.0, -0.8, 1.2, 1.25, "bone"), (53, -1.4, 5.6, 0.4, 2.4, 0.8, "skin"), (68, -1.2, 1.8, 1.0, 2.2, 0.35, "skin-"),
                  (62, 2.9, 4.6, 1.0, 1.4, 0.35, "skin-")))
        end = 9.8
        tip.spike([at(46, end, -1.2, -0.45), at(46, end, -0.4, -0.45), at(46, end, -0.4, 0.45), at(46, end, -1.2, 0.45)],
                  at(46, end + 2.4, -0.5), "bone-")
        # the back flippers: the same hand, small, one joint each
        back = m.part(f"FlipB{tag}", (18.0, 7.0 * s, -1.0), "Shell")
        fan(back, s, (18.0, 5.5, -1.0), 0.05,
            ((50, -1.5, 9.4, -0.9, 1.4, 1.5, "rim"), (58, -1.2, 7.4, 0.5, 2.8, 1.1, "skin"), (73, -0.6, 2.4, 1.3, 2.4, 0.6, "skin-"),
             (73, 3.8, 5.8, 1.1, 1.8, 0.45, "skin-")))

    # the tail: short, in two boxes, the second bare bone, ending in a bone point (the echo of the beak)
    tail = m.part("Tail", (26.0, 0, -0.4), "Shell")
    tail.beam((25.4, 0, -0.4), (29.6, 0, -0.8), 2.6, 1.6, "skin", flat="z")
    tail.beam((28.6, 0, -0.7), (31.4, 0, -1.0), 1.7, 1.1, "bone", flat="z")
    tail.spike([(30.9, -0.6, -1.4), (30.9, 0.6, -1.4), (30.9, 0.6, -0.5), (30.9, -0.6, -0.5)], (34.0, 0.0, -1.2), "bone-")
