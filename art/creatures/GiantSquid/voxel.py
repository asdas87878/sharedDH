"""The Giant Squid (zone 6's Epic: Architeuthis, the real one) for tools/blender/voxel_kit.py (docs/style/04-voxel-style.md).
Designed from the animal, not from the Kraken: slim, plain and red.
Its idea: the eye in the twilight. A slim red spear that swims point first, two eyes the size of plates on its head, and two
long clubs trailing far behind everything else.
- It swims as squid do: backwards. The mantle leads (to -X), the head follows, the arms trail in a tight bundle and the
  two tentacles trail far past them.
- The mantle is a long tube in slices, round in section: a rim at its opening, a back that rises a cube behind it, a
  belly that sags a cube under the middle, then a long taper, one cube at a time, to a point. A pale belly that thins
  out toward the tail. Two small paddle fins at the very end, each on its own joint, each in two flat boxes.
- The head is small and nearly all eye: a round eye on each side (a cross of blocks, so it reads as a disc), a pale iris,
  a big black pupil. A funnel under it, pointing back.
- Eight slim arms leave the head's end: three boxes on three joints each, every box a step slimmer, and a thin point.
  Some tips curl out and some back in, no two alike. The arms underneath are the longest, the ones on top the shortest,
  as on the animal.
- Two tentacles come out of the middle of the arms: four thin boxes on four joints, bowing out and down and back, and a
  flat club with a pale pad of suckers on a joint of its own. They are more than twice as long as the arms.
Epic by its reach (the tentacles) and its eyes. No glow. The rider sits on the fullest part of the mantle, legs in a
shallow slot either side."""
import math

NAME, ZONE, RARITY = "Giant Squid", "ZONE 6 / TWILIGHT", "EPIC"
U = 0.45
PALETTE = {"red": "#C43C2E", "arm": "#B2362F", "blush": "#F2CDBD", "iris": "#F6ECD0", "black": "#1A1A20"}
SEAT = (-14, 5, 4.6)
FRAME, ORTHO, ORTHO_SWIM = 2.9, 38.0, 42.0
TEXTURES = [{"tile": "stud", "on": "all", "colours": ["red"]}]  # the mantle's colour only: the arms have their own

AXIS_Z = 0.5  # the height of the axis the arms sit round
BELLY = -2  # the pale belly comes up to here: one level line, so it thins out as the tail rises
# the mantle, from its opening to its point: (from, to, cubes out, bottom, top). One number changes from slice to slice
MANTLE = ((-6, -4, 3, -3, 4), (-8, -6, 4, -3, 4), (-10, -8, 4, -4, 4), (-18, -10, 4, -4, 5), (-20, -18, 4, -3, 5), (-22, -20, 4, -3, 4),
          (-25, -22, 3, -3, 4), (-27, -25, 3, -2, 4), (-29, -27, 3, -2, 3), (-31, -29, 2, -2, 3), (-33, -31, 2, -1, 3), (-35, -33, 2, -1, 2),
          (-36, -35, 1, -1, 2))

ANGLES = [math.radians(22.5 + 45 * k) for k in range(8)]  # where each arm sits round the axis, from the right, going up
# an arm's boxes, root to tip: (length, how far it leans out from the axis in degrees, width, thickness, colour)
BOXES = ((7.0, 9, 1.6, 1.4, "arm"), (7.0, 5, 1.2, 1.05, "arm"), (5.5, 14, 0.8, 0.65, "arm-"))
# no two arms alike: each arm's (length, extra lean, how far its tip curls: out, or back in toward the axis). The pair
# underneath is the longest, the pair on top the shortest
VARY = ((0.95, 0, 5), (0.86, 2, -12), (0.88, -1, 6), (0.93, 2, -8), (1.0, -1, 7), (1.07, 1, -14), (1.04, -2, 3), (0.98, 2, -11))
SWING = ((5, 0.0), (7, 0.9), (10, 1.8))  # each arm joint's swing in degrees, and how late it is
# a tentacle's stalk: (length, degrees out from the axis, degrees up, width, thickness), then its club and the club's tip
STALK = ((8.0, 4, -3, 1.15, 0.95), (8.0, 11, -10, 1.1, 0.9), (8.0, -1, -1, 1.05, 0.85), (7.0, -7, 8, 1.0, 0.8))
CLUB = ((5.5, 5, 13, 2.2, 0.95), (3.2, 11, 19, 1.3, 0.6))
SWAY = ((3, 0.5), (5, 1.2), (7, 1.9), (8, 2.6), (10, 3.3))  # each tentacle joint's sway, and how late it is


def pose(parts, phase):
    """a jet: the arms open a little and shut, a wave running down each; the tentacles snake behind, late; the fins beat
    twice to a jet; the head nods a little"""
    parts["Head"].rotation_euler.y = math.radians(1.0) * math.sin(phase + 0.5)
    for name, side in (("FinR", 1), ("FinL", -1)):
        parts[name].rotation_euler.x = side * math.radians(13) * math.sin(2 * phase)
    for k, angle in enumerate(ANGLES):
        axis = (0.0, -math.sin(angle), math.cos(angle))
        for j, (swing, late) in enumerate(SWING):
            ob = parts[f"A{k + 1}{'abc'[j]}"]
            beat = math.sin(phase - late) + 0.3 * math.sin(2 * (phase - late))  # opens slowly, shuts fast
            ob.rotation_mode = "AXIS_ANGLE"
            ob.rotation_axis_angle = (math.radians(swing) * beat, *axis)
    for name, side in (("TR", 1), ("TL", -1)):
        for j, (sway, late) in enumerate(SWAY):
            ob = parts[f"{name}{'abcde'[j]}"]
            ob.rotation_euler.z = side * math.radians(sway) * math.sin(phase - late)
            ob.rotation_euler.y = math.radians(sway * 0.6) * math.sin(phase - late - 1.0)


def steps(n, tall):
    """a slice's corner steps, top and bottom: two where the mantle is full, one where it thins, a ridge at the tail"""
    if n >= 4:
        return [(2, 1), (1, 1)], [(2, 1), (1, 1)]
    if n >= 2:
        return [(1, 1)], [(1, 1)]
    return [], []


def slab(p, x0, x1, n, bot, top):
    """a slice of the mantle: stepped corners, red, lighter on the top row, a pale belly below the belly line"""
    up, down = steps(n, top - bot)
    p.hull(x0, x1, n, bot, top, "red", up, down)
    p.paint_sym(x0, x1, n, top - 1, top, "red+")
    if bot < BELLY:
        p.paint_sym(x0, x1, n, bot, BELLY, "blush")


def frame(angle, lean):
    """the three directions of an arm's box at `angle` round the axis, leaning out by `lean` degrees: along it, across it
    (sideways), and through it (outward from the axis)"""
    c, s, f = math.cos(angle), math.sin(angle), math.radians(lean)
    along = (math.cos(f), math.sin(f) * c, math.sin(f) * s)
    through = (-math.sin(f), math.cos(f) * c, math.cos(f) * s)
    across = (0.0, -s, c)
    return along, across, through


def heading(side, out, up):
    """the three directions of a tentacle's box that turns `out` degrees from the axis (on `side`) and `up` degrees: along
    it, across it, and through it (its thin side, facing up)"""
    w, p = math.radians(out), math.radians(up)
    along = (math.cos(p) * math.cos(w), side * math.cos(p) * math.sin(w), math.sin(p))
    thin = (-along[2] * along[0], -along[2] * along[1], 1 - along[2] * along[2])
    n = math.sqrt(sum(v * v for v in thin))
    thin = tuple(v / n for v in thin)
    wide = (along[1] * thin[2] - along[2] * thin[1], along[2] * thin[0] - along[0] * thin[2], along[0] * thin[1] - along[1] * thin[0])
    return along, wide, thin


def at(p, v, d):
    return tuple(a + b * d for a, b in zip(p, v))


def arm(m, k, angle):
    """one arm, at `angle` round the axis: three boxes on three joints, each slimmer, each starting inside the last, and a
    thin point on the last box that carries its curl on"""
    c, s = math.cos(angle), math.sin(angle)
    start = (1.0, 1.15 * c, AXIS_Z + 1.15 * s)  # a cube inside the head's end
    parent = "Head"
    scale, more, curl = VARY[k]
    for j, (length, lean, wide, thick, colour) in enumerate(BOXES):
        length, lean = length * scale, lean + more + (curl if j == 2 else 0)
        along, across, through = frame(angle, lean)
        part = m.part(f"A{k + 1}{'abc'[j]}", at(start, along, 1.0 if j == 0 else 0.4), parent)
        part._oriented(at(start, along, length / 2), along, across, through, (length, wide, thick), colour, False)
        start = at(start, along, length - 0.8)  # the next box starts inside this one
        parent = part.name
        if j == 2:  # the point
            along, across, through = frame(angle, lean + (12 if curl > 0 else -12))
            part._oriented(at(start, along, 1.7), along, across, through, (3.4, 0.5, 0.38), colour, False)


def tentacle(m, name, side):
    """one tentacle: a thin stalk of four boxes on four joints, bowing out and down and back in, then a flat club and its
    tip on a joint of their own, with a pale pad of suckers on the club"""
    start = (0.8, side * 0.6, AXIS_Z - 0.2)  # in the middle of the arms
    parent = "Head"
    for j, (length, out, up, wide, thick) in enumerate(STALK):
        along, across, through = heading(side, out, up)
        part = m.part(f"{name}{'abcd'[j]}", at(start, along, 0.8 if j == 0 else 0.3), parent)
        part._oriented(at(start, along, length / 2), along, across, through, (length, wide, thick), "arm", False)
        start = at(start, along, length - 0.6)
        parent = part.name
    club = m.part(f"{name}e", at(start, along, 0.3), parent)
    for j, (length, out, up, wide, thick) in enumerate(CLUB):
        along, across, through = heading(side, out, up)
        club._oriented(at(start, along, length / 2), along, across, through, (length, wide, thick), "arm" if j == 0 else "arm-", False)
        if j == 0:  # the suckers: a pale pad lying on the club, a little proud of it
            club._oriented(at(at(start, along, length / 2 + 0.2), through, thick / 2 + 0.05), along, across, through,
                           (length - 0.9, wide - 0.3, 0.4), "blush", False)
        start = at(start, along, length - 0.8)


def build(m):
    # the mantle: one rigid tube, leading. Round in section; the back rises a cube behind the opening and the belly sags a
    # cube under it, then it tapers a cube at a time to the point
    mantle = m.part("Mantle", (-13, 0, 0))
    for x0, x1, n, bot, top in MANTLE:
        slab(mantle, x0, x1, n, bot, top)
    mantle.sym(-4, -3, 1, 3, 4, "red")  # the rim comes forward to a lobe over the head, in the middle of the back
    mantle.paint_sym(-5, -3, 3, -3, 4, "red-")  # the rim of the opening: one dark ring
    # the point: a pyramid out of the last slice, a tone darker
    mantle.spike([(-35.5, -1.2, -0.7), (-35.5, 1.2, -0.7), (-35.5, 1.2, 1.7), (-35.5, -1.2, 1.7)], (-39.2, 0.0, 0.5), "red-")
    # the seat: on the fullest slice, with a shallow slot either side for the rider's legs
    mantle.dent(-16, -13, 4, 0, 3, "red-")

    # the fins: two small paddles at the very end of the mantle, lying flat, each on its own joint. Three boxes each, every
    # one shorter and thinner than the last and starting inside it, so the fin's edge is a round lobe; they rise a little
    for name, side in (("FinR", 1), ("FinL", -1)):
        fin = m.part(name, (-31.6, 1.6 * side, 1.0), "Mantle")
        fin.beam((-31.6, 0.8 * side, 1.0), (-31.6, 4.4 * side, 1.25), 8.4, 0.9, "red", flat="z")
        fin.beam((-31.4, 3.6 * side, 1.2), (-31.3, 6.0 * side, 1.45), 5.8, 0.55, "red", flat="z")
        fin.beam((-31.2, 5.3 * side, 1.4), (-31.1, 7.0 * side, 1.6), 3.2, 0.25, "red-", flat="z")

    # the head: small, a cube slimmer than the mantle's opening all round, and nearly all eye
    head = m.part("Head", (-4, 0, 0.5), "Mantle")
    head.hull(-4, 2, 2, -2, 3, "red", [(1, 1)], [(1, 1)])
    head.paint_sym(-4, 2, 2, 2, 3, "red+")
    head.paint_sym(-4, 2, 2, -2, -1, "blush")
    head.sym(-5, -4, 1, -1, 2, "red-")  # a sleeve into the mantle, clear of its steps
    # the eyes: huge and round. Each is a disc drawn in blocks: a dark socket (a cross of two blocks), a pale iris (a
    # smaller cross) and a big black pupil, each a step prouder than the last, so the eye bulges
    ex, ez = -1.1, 0.5
    for hx, hz, inner, outer, colour in ((1.45, 2.2, 1.9, 2.7, "red-"), (2.2, 1.3, 2.05, 2.95, "red-"), (1.05, 1.75, 2.25, 3.2, "iris"),
                                         (1.75, 1.15, 2.4, 3.45, "iris"), (0.9, 0.9, 2.9, 3.75, "black")):
        section = (inner, outer, ez - hz, ez + hz)
        head.block(ex - hx, section, ex + hx, section, colour, mirror=True)
    # the funnel: a short tube under the head, pointing back and down, dark inside
    head.beam((-3.0, 0, -1.3), (0.3, 0, -2.9), 1.7, 1.1, "blush", flat="z")
    head.beam((-0.45, 0, -2.57), (0.55, 0, -3.05), 1.1, 0.6, "arm-", flat="z")

    for k, angle in enumerate(ANGLES):
        arm(m, k, angle)
    tentacle(m, "TR", 1)
    tentacle(m, "TL", -1)
