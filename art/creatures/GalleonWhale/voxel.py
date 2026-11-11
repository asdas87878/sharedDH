"""The Galleon Whale (zone 4's Secret) for tools/blender/voxel_kit.py (docs/style/04-voxel-style.md), dressed by
docs/style/05-rarity-look.md (age, scale, an impossible part, one light).
Its idea: a whale that carries a sunken galleon. The ship is what you see: a bow that comes to a point with a broken
bowsprit, a low waist where the rider sits, a tall sterncastle in two steps with a lantern still burning.
- The whale is a sperm whale, a weathered grey-green: a tall blunt head that narrows to a nose button, a thin toothy jaw
  slung under it on its own joint, a small old eye low on the head. One lighter line runs from the lip to the tail.
- The front of the body is one stiff piece, as a whale's is, and the hull is grown onto it: timber sides one cube proud of
  the flanks (a ledge where wood meets hide), a faded red strake from bow to stern, a row of gunports, a broken rail.
- Behind the seat: the stump of the main mast with an iron band, then the sterncastle and the stern lantern, the one
  light. An anchor chain goes over the broken rail and down the left flank, the anchor still on it.
- Barnacles sit in the ledge under the timber, on the brow and on the tail. The tail is seven slices on their own
  joints and a flat fluke: it swims up and down.
The rider sits on a sea chest in the waist, legs either side of it, feet on the deck."""
import math

NAME, ZONE, RARITY = "Galleon Whale", "ZONE 4 / SHIPWRECKS", "SECRET"
U = 0.5
PALETTE = {"hide": "#5F7669", "belly": "#CDD2BC", "wood": "#80603F", "trim": "#A9503F", "iron": "#30343B", "lamp": "#FFC45A",
           "crust": "#D9CFB4", "black": "#1E2024", "tooth": "#F4F0E2", "gum": "#9A4F58", "mouth": "#5E2A32"}
SEAT = (-6.5, 12, 1.5)
GLOW = {"lamp": 1.0}  # the stern lantern only
LIGHTS = [("Hull", (13.5, 0, 22.8), "#FFB24A", 160, 1.0)]
FRAME, ORTHO, ORTHO_SWIM = 3.7, 52.0, 58.0
TEXTURES = [{"tile": "stud_square", "on": "top+sides", "colours": ["wood", "trim"]}]  # the timber only

# the tail behind the ship: (from, to, cubes out, bottom, top), each slice on its own joint
TAIL = ((14, 18, 7, -6, 8), (18, 22, 6, -5, 7), (22, 25, 5, -4, 6), (25, 28, 4, -4, 5), (28, 31, 4, -3, 4), (31, 34, 3, -2, 3),
        (34, 36, 2, -1, 2))
CHAIN = [f"T{i + 1}" for i in range(len(TAIL))] + ["Tail"]
AMPLITUDES = [2, 3, 4, 5, 7, 9, 11, 14]


def pose(parts, phase):
    """a whale's swim: the stiff front (and the ship on it) pitches a little, the wave runs down the tail up and down, the
    jaw drops and shuts once a beat, the flippers rise and fall"""
    parts["Hull"].rotation_euler.y = math.radians(1.0) * math.sin(phase)
    for k, name in enumerate(CHAIN):
        parts[name].rotation_euler.y = math.radians(AMPLITUDES[k]) * math.sin(phase - 0.55 * (k + 1))
    parts["Jaw"].rotation_euler.y = -math.radians(7) * (0.5 + 0.5 * math.sin(phase - 1.0))
    for name, side in (("FlipR", 1), ("FlipL", -1)):
        parts[name].rotation_euler.x = side * math.radians(8) * math.sin(phase - 0.8)


def count(n):
    """how many steps a corner is cut in: three where the body is thick, fewer as it thins"""
    return 3 if n >= 8 else (2 if n >= 5 else 1)


def steps(n):
    return [(3, 1), (2, 1), (1, 1)][3 - count(n):]


def belly_edge(bot):
    """how high the pale belly comes: level under the body, rising to the tail"""
    return max(-5, bot + 2) if bot <= -2 else bot + 1


def slab(p, x0, x1, n, bot, top, open_top=True, edge=None):
    """a length of whale: stepped corners, a pale belly, one lighter line where the hide meets it, lighter on the top row.
    open_top False: the back is under the ship, so it is left square"""
    p.hull(x0, x1, n, bot, top, "hide", steps(n) if open_top else (), steps(n))
    if open_top:
        p.paint_sym(x0, x1, n, top - 1, top, "hide+")
    edge = belly_edge(bot) if edge is None else edge
    p.paint_sym(x0, x1, n, bot, edge, "belly")
    p.paint_sym(x0, x1, n, bot, bot + 1, "belly-")
    p.paint_sym(x0, x1, n, edge, edge + 1, "hide+")


def sleeve(p, x0, piece, front):
    """one cube into the piece in front, so a bending joint shows body: sized from the smaller of the two and kept inside
    both pieces' corner steps"""
    (n, bot, top), (fn, fbot, ftop) = piece, front
    cut = max(count(n), count(fn))
    p.sym(x0 - 1, x0, max(min(n, fn) - 2, 0), max(bot, fbot) + cut, min(top, ftop) - cut, "hide-")


def cube(p, x0, x1, y0, y1, z0, z1, colour):
    """a small block sunk a little into what it sits on (a barnacle, a link of chain)"""
    p.block(x0, (y0, y1, z0, z1), x1, (y0, y1, z0, z1), colour)


def build(m):
    # ------------------------------------------------------------------ the head: a sperm whale's, tall and blunt
    head = m.part("Head", (-24, 0, 0))
    slab(head, -43, -40, 6, -3, 7, edge=-2)
    slab(head, -40, -32, 7, -4, 8, edge=-3)
    slab(head, -32, -24, 8, -5, 8, edge=-4)
    head.sym(-44, -43, 4, -1, 6, "hide")  # the nose button
    head.hull(-29, -24, 5, -7, -5, "belly", (), [(2, 1), (1, 1)])  # the throat, where the jaw hinges
    head.paint_sym(-29, -24, 5, -7, -6, "belly-")
    head.paint(-39, -32, -2, 3, -4, -3, "mouth")  # the roof of the mouth, seen when the jaw drops
    cube(head, -39.4, -38.0, -3.0, -1.8, 7.9, 8.35, "hide-")  # the blowhole: on the left, as a sperm whale's is
    # the eye: small and old, low on the head: a dark pupil in a pale ring under a heavy lid that comes past it
    ring = (8.3, 8.85, -1.8, 0.3)
    head.block(-30.7, ring, -28.3, ring, "belly", mirror=True)
    pupil = (8.7, 9.1, -1.5, -0.4)
    head.block(-30.1, pupil, -28.9, pupil, "black", mirror=True)
    head.beam((-31.4, 8.6, 0.1), (-27.7, 8.6, 0.65), 1.4, 1.5, "hide-", mirror=True)
    # barnacles on the brow
    cube(head, -37.6, -36.2, 2.3, 3.7, 7.8, 8.8, "crust")
    cube(head, -36.0, -35.0, 3.9, 4.8, 7.6, 8.4, "crust+")
    cube(head, -35.6, -34.8, 1.8, 2.6, 7.8, 8.4, "crust+")

    # the lower jaw, on its own joint: thin and long under the big head, a gum line inside its edge, a row of teeth
    jaw = m.part("Jaw", (-26, 0, -5.8), "Head")
    jaws = ((-25.0, -33.0, -6.0, -5.5, 5.5, 1.4), (-32.0, -42.0, -5.55, -4.9, 3.6, 1.1))

    def jaw_top(k, x):
        x0, x1, z0, z1, _, thick = jaws[k]
        return z0 + (z1 - z0) * (x - x0) / (x1 - x0) + thick / 2

    for x0, x1, z0, z1, wide, thick in jaws:
        jaw.beam((x0, 0, z0), (x1, 0, z1), wide, thick, "belly", flat="z")
    jaw.beam((-33.4, 0, jaw_top(1, -33.4) + 0.05), (-41.7, 0, jaw_top(1, -41.7) + 0.05), 2.9, 0.2, "gum", flat="z")
    for x in (-34.4, -35.9, -37.4, -38.9, -40.4):
        jaw.tooth(x, 1.05, jaw_top(1, x) + 0.05, 0.65, -0.85, "tooth")

    # ------------------------------------------------------------------ the stiff front of the body, and the ship on it
    hull = m.part("Hull", (-24, 0, 0), "Head")
    slab(hull, -24, -19, 9, -8, 9)
    slab(hull, -19, -14, 10, -8, 9)
    for x0, x1, n, bot in ((-14, -10, 10, -9), (-10, -1, 10, -10), (-1, 4, 10, -9), (4, 9, 9, -8), (9, 14, 8, -7)):
        slab(hull, x0, x1, n, bot, 9, open_top=False)
    sleeve(hull, -24, (9, -8, 9), (8, -5, 8))
    whale = set(hull.cells)
    # the galleon. From above it is a boat: the bow comes to a point in five steps, the waist is widest, the stern a
    # little narrower. From the side: a forecastle, the low waist with its bulwarks, the sterncastle in two steps
    hull.sym(-24, -23, 1, 8, 15, "wood")
    hull.sym(-23, -21, 3, 8, 14, "wood")
    hull.sym(-21, -19, 5, 8, 14, "wood")
    hull.sym(-19, -17, 7, 8, 14, "wood")
    hull.sym(-17, -14, 9, 6, 14, "wood")
    hull.pair(-14, 4, 11, 12, 5, 12, "wood")
    hull.sym(4, 9, 10, 5, 16, "wood")
    hull.sym(9, 14, 9, 5, 16, "wood")
    hull.sym(9, 14, 7, 16, 19, "wood")
    # its paint: a dark lowest strake, a faded red one from bow to stern, every top row (rails, decks) lighter
    for c, colour in list(hull.cells.items()):
        if colour != "wood":
            continue
        i, j, k = c
        if k == 5 and c not in whale:
            hull.cells[c] = "wood-"
        elif k == 8:
            hull.cells[c] = "trim"
        elif (i, j, k + 1) not in hull.cells:
            hull.cells[c] = "wood+"
    hull.paint_sym(-24, -23, 1, 8, 15, "wood-")  # the stem post
    hull.paint_sym(-14, 4, 10, 8, 9, "wood+")  # the deck of the waist
    # planks hanging loose under the hull, and the rail broken on the left where the chain goes over
    hull.box(-11, -5, 11, 12, 4, 5, "wood-")
    hull.box(-10, -8, 11, 12, 3, 4, "wood-")
    hull.box(5, 9, -10, -9, 4, 5, "wood-")
    hull.box(6, 8, -10, -9, 3, 4, "wood-")
    hull.carve(-6, -1, -11, -10, 11, 12)
    hull.carve(-5, -2, -11, -10, 10, 11)
    # the gunports: a row of shallow dark squares
    for x in (-12, -7, -2):
        hull.dent(x, x + 2, 11, 6, 8, "iron")
    hull.dent(5, 7, 10, 6, 8, "iron")
    hull.dent(10, 12, 9, 6, 8, "iron")
    # the stern windows
    for j0, j1 in ((-6, -4), (-1, 2), (5, 7)):
        hull.paint(13, 14, j0, j1, 12, 14, "iron")
    # the sea chest the rider sits on
    hull.sym(-9, -4, 1, 9, 12, "wood-")
    hull.paint_sym(-9, -4, 1, 11, 12, "trim")
    # the broken bowsprit
    hull.beam((-21.5, 0, 13.0), (-33.0, 0, 18.0), 1.8, 1.8, "wood-")
    hull.spike([(-32.39, -0.6, 18.39), (-32.39, 0.6, 18.39), (-32.87, 0.6, 17.29), (-32.87, -0.6, 17.29)], (-34.44, 0.2, 18.96), "wood-")
    # the stump of the main mast behind the seat: a lower piece, an iron band that caps it, a thinner upper piece that
    # starts inside the band, a splintered top
    hull.beam((-0.9, 0, 8.4), (-0.4, 0, 14.2), 2.8, 2.8, "wood-")
    hull.beam((-0.46, 0, 13.5), (-0.34, 0, 14.9), 3.5, 3.5, "iron")
    hull.beam((-0.42, 0, 13.9), (0.2, 0, 20.2), 2.2, 2.2, "wood-")
    hull.spike([(-0.8, -0.95, 19.7), (-0.8, 0.05, 19.7), (0.2, 0.05, 19.7), (0.2, -0.95, 19.7)], (-0.35, -0.5, 23.4), "wood-")
    hull.spike([(0.2, 0.0, 19.5), (0.2, 0.95, 19.5), (1.15, 0.95, 19.5), (1.15, 0.0, 19.5)], (0.75, 0.55, 21.6), "wood-")
    # the stern lantern, on a post at the back of the poop: the one light
    hull.sym(13, 14, 0, 19, 21, "iron")
    cube(hull, 12.0, 15.0, -1.7, 1.7, 20.8, 21.3, "iron")
    cube(hull, 12.2, 14.8, -1.4, 1.4, 21.2, 24.4, "lamp")
    cube(hull, 11.8, 15.2, -1.8, 1.8, 24.3, 25.0, "iron")
    cube(hull, 13.15, 13.85, -0.35, 0.35, 24.9, 25.9, "iron")
    # the anchor chain: over the broken rail and down the left flank, the anchor still hanging on it. Each link caps the
    # end of the thin piece above it, and the next thin piece starts inside it
    cx, cy = -3.5, -12.3
    cube(hull, cx - 0.5, cx + 0.5, -11.2, -10.8, 9.7, 10.5, "iron+")  # a link lying on the broken rail
    cube(hull, cx - 0.2, cx + 0.2, cy - 0.3, -11.0, 9.95, 10.3, "iron")
    z = 10.6
    for k in range(5):  # links turned a quarter turn in turn
        hx, hy = ((0.35, 0.6), (0.65, 0.35))[k % 2]
        tall = 1.7 if k == 0 else 1.2
        cube(hull, cx - hx, cx + hx, cy - hy, cy + hy, z - tall, z, "iron+")
        cube(hull, cx - 0.2, cx + 0.2, cy - 0.2, cy + 0.2, z - tall - 1.3, z - tall + 0.2, "iron")
        z -= tall + 1.1
    cube(hull, cx - 0.6, cx + 0.6, cy - 0.6, cy + 0.6, -9.6, z + 0.2, "iron")  # the shank
    cube(hull, cx - 2.2, cx - 0.3, cy - 0.35, cy + 0.35, z - 1.6, z - 0.7, "iron")  # the stock, in two halves that start inside it
    cube(hull, cx + 0.3, cx + 2.2, cy - 0.35, cy + 0.35, z - 1.6, z - 0.7, "iron")
    hull.beam((cx, cy, -9.0), (cx - 3.0, cy - 0.25, -6.7), 1.1, 0.8, "iron")  # the arms
    hull.beam((cx, cy, -9.0), (cx + 3.0, cy + 0.25, -6.7), 1.1, 0.8, "iron")
    # barnacles in the ledge under the timber
    cube(hull, -13.4, -12.0, 10.2, 11.35, 3.8, 5.2, "crust")
    cube(hull, -11.8, -10.9, 10.3, 11.2, 4.3, 5.15, "crust+")
    cube(hull, 1.4, 2.7, 10.2, 11.3, 3.9, 5.2, "crust")
    cube(hull, -10.6, -9.4, -11.3, -10.2, 3.9, 5.2, "crust")
    cube(hull, -9.1, -8.3, -11.15, -10.3, 4.35, 5.15, "crust+")
    cube(hull, 11.6, 12.9, 8.2, 9.3, 3.9, 5.2, "crust")

    # the flippers, each on its own joint: two boxes, swept back and down
    for name, s in (("FlipR", 1), ("FlipL", -1)):
        flip = m.part(name, (-20.5, 8.5 * s, -4.5), "Hull")
        flip.beam((-21.0, 6.6 * s, -4.4), (-15.0, 13.6 * s, -6.6), 4.4, 1.2, "hide", flat="z")
        flip.beam((-16.2, 12.3 * s, -6.2), (-12.0, 16.2 * s, -7.7), 3.0, 0.8, "hide-", flat="z")

    # ------------------------------------------------------------------ the tail: slices on their own joints
    front = (8, -7, 9)
    for i, (x0, x1, n, bot, top) in enumerate(TAIL):
        seg = m.part(f"T{i + 1}", (x0, 0, 0), "Hull" if i == 0 else f"T{i}")
        slab(seg, x0, x1, n, bot, top)
        sleeve(seg, x0, (n, bot, top), front)
        front = (n, bot, top)
        if 1 <= i <= 4:  # the knuckles of a sperm whale's tail, smaller toward the fluke
            half, tall = ((0.9, 0.8), (0.8, 0.65), (0.65, 0.5), (0.5, 0.4))[i - 1]
            mid = (x0 + x1) / 2
            knuckle = (-half, half, top - 0.12, top + tall)
            seg.block(mid - 1.1, knuckle, mid + 1.1, knuckle, "hide")
        if i == 0:  # the echo: barnacles behind the ship
            cube(seg, 15.0, 16.2, 2.4, 3.6, 7.8, 8.6, "crust")
            cube(seg, 16.5, 17.3, 1.3, 2.1, 7.8, 8.3, "crust+")
    # the fluke, on its own joint: a stock, a hub and two lobes lying flat, two boxes each
    tail = m.part("Tail", (36, 0, 0.5), f"T{len(TAIL)}")
    tail.beam((35.6, 0, 0.5), (39.0, 0, 0.5), 2.6, 1.6, "hide", flat="z")
    hub = (-3.2, 3.2, -0.5, 1.5)
    tail.block(37.6, hub, 41.0, hub, "hide")
    tail.beam((39.2, 1.8, 0.5), (42.8, 9.3, 0.5), 5.0, 1.1, "hide", flat="z", mirror=True)
    tail.beam((41.8, 7.7, 0.5), (44.0, 12.2, 0.5), 3.3, 0.7, "hide-", flat="z", mirror=True)
