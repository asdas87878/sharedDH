"""The Phantom Whale (zone 9's SECRET: a ghost whale you can see through) for tools/blender/voxel_kit.py
(docs/style/04-voxel-style.md), dressed by docs/style/05-rarity-look.md.
Its idea, which is its name: a whale that is only half there. The kit has no transparency, so the ghost is shown in form:
- The chest is hollow. Each flank has one long window cut clean through the body, so the water shows through the whale.
  In the window stand three ivory ribs, a cube inside the skin; each hooks over to the ivory spine that runs under the
  roof. Under the spine lies one thin bar of teal light, and a second along the keel: the only thing left alive in it,
  and it lights the cage.
- The echo: a second, small window through the tail, where the same spine and light pass.
- The spine shows through the back too, as one thin ivory line from the head to the tail. It is flat: the rider sits on
  it, legs in two slots either side.
- The eye is a hollow socket with the same teal light deep in it, no pupil.
- The flippers, the back fin and the flukes thin out to pale stepped tips, with loose tatters trailing off their edges.
The whale itself is a deep-chested baleen whale built from big blocks: the back climbs from the snout to the chest and
falls to the tail a cube a slice, the belly does the same underneath, and from above it is a spindle, widest at the cage.
A narrow upper jaw of three tilted blocks lies in a wider pale lower jaw. Pale ice blue, a paler belly, and one pale line
along the flank that is also the window's lintel. It swims by bending up and down."""
import math

NAME, ZONE, RARITY = "Phantom Whale", "ZONE 9 / BONE GRAVEYARD", "SECRET"
U = 0.5
PALETTE = {"ice": "#A6D2E8", "frost": "#E7F4F9", "ivory": "#F3E9CC", "teal": "#4FE6D0", "deep": "#1F5266"}
SEAT = (-8, 11, 1.6)
GLOW = {"teal": 0.6}  # the bar of light under the spine, and the eye
LIGHTS = [("Chest", (-8.0, 0, -2.0), "#5FEBD8", 140, 1.0)]  # the cage is lit from inside
FRAME, ORTHO, ORTHO_SWIM = 3.7, 52.0, 58.0

LINE = 5  # the height of the pale line along the flank
SKULL_X, SKULL = (-31, -23), (7, -8, 8)  # cubes out, bottom, top
SHOULDER_X, SHOULDER = (-23, -19), (8, -9, 10)
CAGE_X, CAGE = (-19, 3), (9, -10, 11)
WINDOW = (-17, 1, -5, LINE)  # x from, x to, z from, z to: cut through the whole body
RIBS = ((-14, -12), (-9, -7), (-4, -2))
# the tail: each slice is (length, cubes out, bottom, top), a cube smaller all round than the one before
TAIL = ((5, 8, -9, 10), (6, 7, -8, 9), (5, 6, -6, 8), (4, 5, -5, 7), (4, 4, -4, 6), (3, 3, -3, 5), (3, 2, -2, 4))
ECHO = 1  # the slice with the small window
CHAIN = ["Chest"] + [f"T{i + 1}" for i in range(len(TAIL))] + ["Fluke"]
AMPLITUDES = [1.5, 2.5, 3.5, 4.5, 5.5, 6.5, 7.5, 8.5, 13]


def pose(parts, phase):
    """a whale's swim: a slow wave runs down the body up and down and ends in the fluke; the flippers row a little"""
    parts["Head"].rotation_euler.y = math.radians(1.5) * math.sin(phase + math.pi)
    for k, name in enumerate(CHAIN):
        parts[name].rotation_euler.y = math.radians(AMPLITUDES[k]) * math.sin(phase - 0.5 * (k + 1))
    for name, side in (("FlipperR", 1), ("FlipperL", -1)):
        parts[name].rotation_euler.x = side * math.radians(10) * math.sin(phase - 0.8)
        parts[name].rotation_euler.z = side * math.radians(5) * math.sin(phase - 1.8)


def top_steps(n):
    """the corners of the back: a plateau, a broad step and a wall where the body is thick, fewer steps as it thins"""
    return [(4, 1), (2, 1), (1, 2)] if n >= 8 else ([(3, 1), (2, 1), (1, 1)] if n >= 6 else ([(2, 1), (1, 1)] if n >= 4 else [(1, 1)]))


def bottom_steps(n):
    return [(4, 1), (2, 1), (1, 1)] if n >= 8 else ([(3, 1), (1, 1)] if n >= 6 else ([(2, 1), (1, 1)] if n >= 4 else [(1, 1)]))


def rows(steps):
    return sum(tall for _, tall in steps)


def slab(p, x0, x1, n, bot, top, belly=None, bottom=None):
    """a slice of body: stepped corners, ice-blue hide, a lighter top row with the spine's ivory line down its middle, the
    pale line along the flank, a paler belly from `belly` down (left out: the stepped rows of the belly)"""
    bottom = bottom_steps(n) if bottom is None else bottom
    p.hull(x0, x1, n, bot, top, "ice", top_steps(n), bottom)
    p.paint_sym(x0, x1, n, top - 1, top, "ice+")
    p.paint_sym(x0, x1, 0, top - 1, top, "ivory")
    if top >= LINE + 2:
        p.paint_sym(x0, x1, n, LINE, LINE + 1, "frost")
    p.paint_sym(x0, x1, n, bot, bot + rows(bottom) if belly is None else belly, "frost")
    p.paint_sym(x0, x1, n, bot, bot + 1, "frost-")


def sleeve(p, x0, mine, front, front_bottom=None):
    """a sleeve one cube into the piece in front, sized from the smaller of the two and clear of both pieces' steps"""
    (n, bot, top), (fn, fbot, ftop) = mine, front
    small = min(n, fn)
    up = max(rows(top_steps(n)), rows(top_steps(fn)))
    down = max(rows(bottom_steps(n)), rows(front_bottom if front_bottom is not None else bottom_steps(fn)))
    p.sym(x0 - 1, x0, max(small - 2, 0), max(bot, fbot) + down, min(top, ftop) - up, "ice-")


def hollow(p, x0, x1, n, z0, z1, ribs=()):
    """a window cut clean through a slice from flank to flank. The spine runs under its roof with the bar of light under
    it and a second bar of light along the keel; each rib stands a cube inside the skin and hooks over to the spine. The
    inside is dark"""
    p.carve(x0, x1, -n, n + 1, z0, z1)
    p.sym(x0, x1, 1, z1 - 2, z1, "ivory")
    p.sym(x0, x1, 1, z1 - 3, z1 - 2, "teal")
    p.sym(x0, x1, 1, z0, z0 + 1, "teal")  # and a second bar along the keel, which is the one seen from above
    for r0, r1 in ribs:
        p.pair(r0, r1, n - 1, n, z0, z1, "ivory")
        p.pair(r0, r1, 2, n - 1, z1 - 1, z1, "ivory")
    p.paint(x0, x1, 1 - n, n, z0 - 1, z0, "deep")
    p.paint(x0, x1, 1 - n, n, z1, z1 + 1, "deep")
    p.paint(x0 - 1, x0, 1 - n, n, z0, z1, "deep")
    p.paint(x1, x1 + 1, 1 - n, n, z0, z1, "deep")


def build(m):
    # ---- the head: a short skull and two jaws that taper to the front, each three tilted blocks in a chain
    head = m.part("Head", (SKULL_X[1], 0, 0))
    slab(head, *SKULL_X, *SKULL, belly=-1, bottom=[(1, 1)])  # a deep, square throat: the jaw's root is buried in it
    head.paint_sym(-27, SKULL_X[1], 7, -3, -1, "ice")  # the belly's edge steps down toward the chest
    # the upper jaw: narrow, each block tilted nose-down, lower and narrower than the last and starting inside it
    for x0, x1, z0, z1, wide, thick in ((-29.5, -35.5, 3.6, 3.1, 8.6, 7.4), (-34.3, -40.2, 2.8, 2.3, 6.8, 5.0),
                                        (-39.2, -43.8, 2.2, 1.8, 4.8, 3.2)):
        head.beam((x0, 0, z0), (x1, 0, z1), wide, thick, "ice", flat="z")
    # the lower jaw: wider than the upper, pale, its lip standing either side of the upper jaw as a baleen whale's does.
    # Its blocks tilt nose-up, so the mouth's line climbs to the tip, where the lip closes over the upper jaw. A dark
    # plate lies on each lip, set in from its edge: the mouth's line
    jaws = ((-29.5, -36.5, -4.4, -4.0, 12.6, 6.6, -31.3), (-35.3, -41.5, -3.4, -2.4, 9.8, 5.2, -35.6), (-40.5, -44.6, -2.0, -1.2, 6.8, 3.6, -40.6))
    for x0, x1, z0, z1, wide, thick, line_from in jaws:
        head.beam((x0, 0, z0), (x1, 0, z1), wide, thick, "frost", flat="z")
        if line_from:
            def lip(x):
                return z0 + (z1 - z0) * (x - x0) / (x1 - x0) + thick / 2 + 0.2

            head.beam((line_from, 0, lip(line_from)), (x1 + 1.0, 0, lip(x1 + 1.0)), wide - 1.2, 0.8, "deep", flat="z")
    # the eye: a hollow socket low on the skull, by the corner of the mouth, with the teal light deep in it. No pupil
    head.dent(-30, -27, 7, -1, 2, "deep", depth=0.5)
    light = (6.8, 7.25, -0.3, 1.3)
    head.block(-29.3, light, -27.7, light, "teal", mirror=True)
    blow = (0.6, 1.3, 7.8, 8.2)  # the blowholes
    head.block(-27.4, blow, -26.2, blow, "deep", mirror=True)

    # ---- the chest: one rigid piece, a shoulder and the hollow cage with a window through both flanks
    chest = m.part("Chest", (SHOULDER_X[0], 0, 0), "Head")
    slab(chest, *SHOULDER_X, *SHOULDER, belly=-5)
    slab(chest, *CAGE_X, *CAGE)
    sleeve(chest, SHOULDER_X[0], SHOULDER, SKULL, [(1, 1)])
    # the seat: on the spine's line, a slot either side for the rider's legs
    top = CAGE[2]
    chest.carve_pair(SEAT[0] - 2, SEAT[0] + 2, 2, 4, top - 3, top)
    chest.paint_pair(SEAT[0] - 2, SEAT[0] + 2, 2, 4, top - 4, top - 3, "ice-")
    hollow(chest, WINDOW[0], WINDOW[1], CAGE[0], WINDOW[2], WINDOW[3], RIBS)

    # ---- the flippers, each on its own joint: long, four boxes thinning to a pale tip, two loose tatters off the back edge
    for name, s in (("FlipperR", 1), ("FlipperL", -1)):
        f = m.part(name, (-16.0, 9.5 * s, -6.5), "Chest")
        f.beam((-16.6, 6.2 * s, -6.3), (-12.6, 12.6 * s, -7.6), 4.8, 1.5, "ice", flat="z")
        f.beam((-13.4, 11.5 * s, -7.35), (-7.0, 15.6 * s, -8.5), 3.9, 1.0, "ice", flat="z")
        f.beam((-8.0, 14.9 * s, -8.3), (-3.4, 17.2 * s, -9.1), 2.7, 0.6, "ice+", flat="z")
        f.beam((-4.3, 16.7 * s, -8.95), (-1.4, 17.9 * s, -9.4), 1.7, 0.35, "frost", flat="z")
        f.beam((-12.8, 9.4 * s, -7.2), (-8.6, 8.4 * s, -8.6), 1.6, 0.6, "ice+", flat="z")
        f.beam((-9.6, 12.5 * s, -7.9), (-3.8, 11.6 * s, -9.6), 1.4, 0.5, "frost", flat="z")

    # ---- the tail: slices on joints, each a cube smaller all round, to a tall thin stock
    x, front, parent, segs = CAGE_X[1], CAGE, "Chest", []
    for i, (length, n, bot, top) in enumerate(TAIL):
        seg = m.part(f"T{i + 1}", (x, 0, 0), parent)
        slab(seg, x, x + length, n, bot, top)
        sleeve(seg, x, (n, bot, top), front)
        segs.append((seg, x, x + length, n))
        x, front, parent = x + length, (n, bot, top), f"T{i + 1}"
    end = x
    seg, x0, x1, n = segs[ECHO]  # the echo: a small window through the tail, the spine and the light passing through it
    hollow(seg, x0 + 1, x1 - 2, n, -3, LINE)  # two cubes of wall behind it: the next slice's sleeve is in there
    # a small back fin, far behind the rider: two boxes, the tip pale, a tatter off its back edge
    fin, fx, _, _ = segs[2]
    fin.beam((fx + 1.2, 0, 6.8), (fx + 4.0, 0, 9.8), 3.2, 1.3, "ice")
    fin.beam((fx + 3.4, 0, 9.1), (fx + 5.3, 0, 11.2), 2.0, 0.7, "frost")
    fin.beam((fx + 3.6, 0, 8.4), (fx + 5.8, 0, 7.9), 0.9, 0.4, "frost")

    # ---- the fluke, on its own joint: it lies flat. A hub, then each lobe in three boxes that thin, droop and pale to the
    # tip, with loose tatters of uneven length trailing off its back edge and hanging down
    fluke = m.part("Fluke", (end, 0, 0.5), f"T{len(TAIL)}")
    fluke.beam((end - 1.0, 0, 0.5), (end + 5.5, 0, 0.5), 4.6, 2.2, "ice", flat="z")
    fluke.beam((end + 2.6, 0.3, 0.5), (end + 6.0, 8.5, 0.2), 5.0, 1.4, "ice", flat="z", mirror=True)
    fluke.beam((end + 5.2, 6.6, 0.25), (end + 8.6, 11.6, -0.4), 3.6, 0.9, "ice+", flat="z", mirror=True)
    fluke.beam((end + 7.8, 10.5, -0.25), (end + 10.2, 13.6, -1.0), 2.0, 0.5, "frost", flat="z", mirror=True)
    fluke.beam((end + 4.4, 1.5, 0.5), (end + 8.0, 1.9, -1.2), 1.4, 0.6, "ice+", flat="z", mirror=True)
    fluke.beam((end + 4.6, 3.8, 0.4), (end + 10.6, 4.6, -2.4), 1.8, 0.7, "ice+", flat="z", mirror=True)
    fluke.beam((end + 6.6, 8.0, 0.1), (end + 12.2, 9.0, -2.8), 1.5, 0.5, "frost", flat="z", mirror=True)
