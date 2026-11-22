"""Keeper of the Light, a COSMIC (docs/design/cosmic.md, concept 15) for tools/blender/voxel_kit.py. Its body starts from
the Anglerfish's (art/creatures/Anglerfish, not changed), at twice the size.
Its idea: a deep-sea angler whose lure grew into a lighthouse. Everything else is the calmest navy, so the one red and white
tower, its blazing lantern and the sweeping beam are all you see.
- The body is the angler's ball, mouth and needle teeth, in one deep navy with a slightly lighter belly. No marks.
- The set piece: the rod grows from the forehead and arches forward like a crane's boom, past the mouth, and ends in a lump
  of barnacled rock. On the rock stands a lighthouse: a tapering tower in red and white bands with a door and two lit
  windows facing the rider, a gallery with a railing, a lantern room that blazes, and a red cap. It hangs ahead of and
  above the rider, in the upper middle of the riding camera.
- The beam, on its own joint ("Beam"): two long glowing wedges out of the lantern, leaning down a little, turning once
  every swim: the lighthouse sweep, crossing the rider's view.
- The eyes are small and milky; the tail's needles echo the teeth.
The lighthouse is built from cubes a third of the body's (part.fine = 3), so its bands, rail and windows can be small.
The rider sits astride the crown of the ball."""
import math

NAME, ZONE, RARITY = "Keeper of the Light", "UNPLACED", "COSMIC"
U = 1.16
PALETTE = {"skin": "#1D2747", "belly": "#2C3A63", "tooth": "#F3EEDC", "mouth": "#1A0A12", "black": "#0B0B10", "eye": "#C9D2E0",
           "stone": "#3A4252", "barnacle": "#D9D3C2", "red": "#C7313A", "white": "#F1ECE2", "iron": "#20242E",
           "door": "#4A2C22", "lamp": "#FFF1B8", "beam": "#FFE48A"}
DZ = -9  # see lower(): the whole model sits this many cubes lower than the numbers below
SEAT = (-3, 8 + DZ, 2.96)
GLOW = {"lamp": 1.0, "beam": 0.8}  # the lantern, the windows and the beam: nothing else shines
F = 3  # the lighthouse's cubes: a third of the body's
CX = -47.5  # the lighthouse's middle, in its small cubes (x); y = 0
ROCK, TOWER = (28, 41), (41, 59)  # small-cube layers: [from, to)
GALLERY, LANTERN, CAP = 59, (60, 67), 67
LAMP = (CX / F, 0.0, (LANTERN[0] + LANTERN[1]) / 2 / F)  # the lamp's middle, in the body's cubes
PORCH = (CX / F + 2.9, 0.0, (TOWER[0] + 6) / F)  # the porch lamp over the door, a little out from the tower, toward the rider
LIGHTS = [("Lighthouse", (LAMP[0], 0.0, LAMP[2] + DZ), "#FFE7A0", 320, 1.0),
          ("Lighthouse", (PORCH[0], 0.0, PORCH[2] + DZ), "#FFD98A", 160, 0.4)]  # it lights the bands the rider sees
FRAME, ORTHO, ORTHO_SWIM = 3.9, 46.0, 50.0

# the corner steps of a slab, by how far out it reaches: (cubes in from the side, cubes tall), from the top down
STEPS = {5: [(3, 1), (1, 2)], 4: [(2, 1), (1, 1)], 3: [(2, 1), (1, 1)]}
EDGE = -4  # the belly's colour stops at this height the whole way along, so its edge is one line
SWEEP = math.radians(55)  # where the beam points at the start of the swim: out to the right and forward


def pose(parts, phase):
    """the angler's slow waddle; the boom sways a little and late, so the lighthouse nods but stays upright; the beam
    turns once a swim"""
    s = math.sin
    parts["Body"].rotation_euler.x = math.radians(4) * s(phase)
    parts["Body"].rotation_euler.z = math.radians(3) * s(phase + math.pi)
    for name, amp, lag in (("B2", 6, 0.7), ("B3", 10, 1.4), ("Tail", 18, 2.1)):
        parts[name].rotation_euler.z = math.radians(amp) * s(phase - lag)
    parts["Jaw"].rotation_euler.y = -math.radians(9) * (0.5 + 0.5 * s(phase - 0.6))
    for name, side in (("FinR", 1), ("FinL", -1)):
        parts[name].rotation_euler.z = side * math.radians(14) * s(2 * phase)
        parts[name].rotation_euler.x = side * math.radians(8) * s(2 * phase - 1.0)
    parts["Rod1"].rotation_euler.x = math.radians(3) * s(phase - 1.2)
    parts["Rod1"].rotation_euler.y = math.radians(2) * s(phase - 1.0)
    parts["Rod2"].rotation_euler.x = math.radians(3) * s(phase - 2.0)
    parts["Rod2"].rotation_euler.y = math.radians(2) * s(phase - 1.8)
    parts["Lighthouse"].rotation_euler.x = -math.radians(5) * s(phase - 2.9)  # it rights itself against the boom's sway
    parts["Lighthouse"].rotation_euler.y = -math.radians(3) * s(phase - 2.6)
    parts["Beam"].rotation_euler.z = SWEEP + phase  # one whole turn a swim


def slab(p, x0, x1, n, bot, top, steps=None, under=None):
    """a slice of the ball: stepped corners above and below (under: the steps below, [] for a flat underside), lighter
    on the top row, the belly below the line"""
    steps = STEPS[n] if steps is None else steps
    under = steps if under is None else under
    p.hull(x0, x1, n, bot, top, "skin", steps, under)
    p.paint_sym(x0, x1, n, top - 1, top, "skin+")
    if under:
        p.paint_sym(x0, x1, n, bot, EDGE, "belly")
        p.paint_sym(x0, x1, n, bot, bot + len(under) - 1, "belly-")


def needle(p, end, d, length, colour):
    """a pale needle on the end of a fin ray (end: the ray's end in the side view, d: its direction there)"""
    (ex, ez), (dx, dz) = end, d
    cx, cz, px, pz = ex - 0.5 * dx, ez - 0.5 * dz, -0.45 * dz, 0.45 * dx
    base = [(cx - px, -0.3, cz - pz), (cx + px, -0.3, cz + pz), (cx + px, 0.3, cz + pz), (cx - px, 0.3, cz - pz)]
    p.spike(base, (ex + length * dx, 0.0, ez + length * dz), colour)


def ring_cells(r_out, r_in=-1.0):
    """the small-cube columns (dx, y) of a disc (or a ring, from r_in out) round the lighthouse's middle"""
    n = int(math.ceil(r_out))
    return [(dx, y) for dx in range(-n, n + 1) for y in range(-n, n + 1) if r_in * r_in < dx * dx + y * y <= r_out * r_out]


def put(p, dx, y, k, colour):
    """a small cube at (dx, y) from the lighthouse's middle, in layer k: cube i spans x [i, i + 1), so its middle is i + 0.5"""
    p.cells[(int(CX - 0.5) + dx, y, k)] = colour


def lighthouse(m):
    """the lure: a rock, the tower in bands, the gallery and its rail, the lantern, the cap. All small cubes"""
    p = m.part("Lighthouse", (-14.6, 0, 12.3), "Rod2")
    p.fine = F
    # the rock: a lumpy mound, wider in the middle, darker underneath, barnacles where it shows
    for k in range(*ROCK):  # the old bulb of the lure, turned to rock: a drop that hangs to a blunt point under the tower
        f = (k - ROCK[0]) / (ROCK[1] - ROCK[0] - 1)
        base = 1.5 + 5.0 * math.sin(math.pi * min(1.0, 0.12 + 0.75 * f)) ** 0.7
        for dx, y in ring_cells(base + 1.4):
            a = math.atan2(y, dx)
            if math.hypot(dx, y) <= base + 0.8 * math.sin(3 * a + 1.3 * k) + 0.45 * math.cos(5 * a - 2 * k):
                put(p, dx, y, k, "stone-" if k < ROCK[0] + 4 else "stone")
    for (i, y, k), c in list(p.cells.items()):  # barnacles: a pale cube here and there on the rock's shown faces
        if c == "stone" and (i * 7 + y * 13 + k * 5) % 11 == 0:
            p.cells[(i, y, k)] = "barnacle"
    for (i, y, k), c in list(p.cells.items()):  # the rock's top, under the tower's foot, a little lighter
        if c == "stone" and k == ROCK[1] - 1:
            p.cells[(i, y, k)] = "stone+"
    # the tower: five bands, white at the foot, each a little narrower, so it steps in where the colour changes
    bands = ((4.6, "white"), (4.3, "red"), (4.0, "white"), (3.7, "red"), (3.5, "white"))
    tall = (TOWER[1] - TOWER[0]) / len(bands)
    for k in range(*TOWER):
        r, colour = bands[min(int((k - TOWER[0]) / tall), len(bands) - 1)]
        for dx, y in ring_cells(r):
            put(p, dx, y, k, colour)
    # the door at the foot and two lit windows, all facing back toward the rider (+x); one more window each side
    for k in range(TOWER[0], TOWER[0] + 3):
        for y in (-1, 0, 1):
            put(p, 4, y, k, "door")
    put(p, 4, 0, TOWER[0] + 3, "door")
    put(p, 5, 0, TOWER[0] + 4, "lamp")  # the porch lamp over the door
    for k0, r in ((TOWER[0] + 7, 4), (TOWER[0] + 14, 3)):
        for k in (k0, k0 + 1):
            put(p, r, 0, k, "lamp")
    for s in (-1, 1):
        for k in (TOWER[0] + 10, TOWER[0] + 11):
            put(p, 0, s * 4, k, "lamp")
    # the gallery: a dark platform wider than the tower's top, a railing of posts and a top rail
    for dx, y in ring_cells(5.6):
        put(p, dx, y, GALLERY, "iron")
    for dx, y in ring_cells(5.6, 4.6):
        if (dx + y) % 2 == 0:
            put(p, dx, y, GALLERY + 1, "iron")
        put(p, dx, y, GALLERY + 2, "iron")
    # the lantern: a blazing drum with eight dark glazing bars, a dark ring above it
    for k in range(*LANTERN):
        for dx, y in ring_cells(3.2):
            a = math.degrees(math.atan2(y, dx)) % 45
            bar = math.hypot(dx, y) > 2.3 and (a < 9 or a > 36)
            put(p, dx, y, k, "iron" if bar else "lamp")
    for dx, y in ring_cells(3.6):
        put(p, dx, y, CAP, "iron")
    # the cap: a red dome in steps, a finial on top
    for k, r in ((CAP + 1, 3.3), (CAP + 2, 2.6), (CAP + 3, 1.8), (CAP + 4, 1.0)):
        for dx, y in ring_cells(r):
            put(p, dx, y, k, "red")
    for k in (CAP + 5, CAP + 6):
        put(p, 0, 0, k, "iron")


def beam(m):
    """the sweep: two long wedges out of the lantern, opposite ways, widening and leaning a little down"""
    b = m.part("Beam", LAMP, "Lighthouse")
    lx, _, lz = LAMP
    for s in (1, -1):
        inner, outer, drop = 0.9, 11.5, 1.6
        b.block(lx + s * inner, (-0.35, 0.35, lz - 0.3, lz + 0.3), lx + s * outer, (-1.7, 1.7, lz - drop - 0.9, lz - drop + 0.9),
                "beam")


def build(m):
    body = m.part("Body", (-2.5, 0, 0))
    # the snout: two slabs that overhang the mouth, each a step lower and narrower; their flat underside is the mouth's roof
    slab(body, -11, -9, 4, 2, 6, under=[])
    slab(body, -9, -6, 5, 1, 7, under=[])
    # the ball itself: sixteen cubes tall and thirteen wide, with a narrow crown two cubes tall that the rider sits astride
    slab(body, -6, 1, 6, -8, 8, [(4, 2), (2, 1), (1, 2)], [(4, 1), (2, 1), (1, 2)])
    body.pair(-5, 0, 7, 8, -2, 2, "skin")  # and one step more at the middle of each flank, so it is round from above too
    body.paint(-6, -5, -5, 6, -3, 1, "mouth")
    inside = (-4.3, 4.3, -3.6, 1.5)
    body.block(-8.8, inside, -5.6, inside, "mouth")
    inside = (-3.3, 3.3, -3.3, 2.3)
    body.block(-10.15, inside, -8.5, inside, "mouth")
    # the upper teeth: long needles hanging from the snout, leaning inward. A row across the front, then down each side
    for y, long in ((0.0, 2.4), (1.4, 2.8), (2.8, 2.5)):
        body.tooth(-10.55, y, 2.12, 0.5, long, "tooth", mirror=y > 0, lean=(0.35, -0.12 * y))
    for x, y, z, long in ((-9.75, 4.0, 2.12, 2.7), (-8.5, 5.0, 1.12, 2.7), (-7.2, 5.0, 1.12, 2.2)):
        body.tooth(x, y, z, 0.5, long, "tooth", lean=(0.2, -0.55))
    # the eyes: tiny and milky, a dark pupil, high on the shoulder of the snout
    ring = (4.2, 4.8, 3.8, 5.4)
    body.block(-8.7, ring, -7.3, ring, "eye", mirror=True)
    pupil = (4.6, 5.0, 4.35, 5.05)
    body.block(-8.35, pupil, -7.65, pupil, "black", mirror=True)
    body.dent(-4, -2, 2, 6, 7, "skin-")  # the seat: legs in a shallow slot either side of the crown

    # the jaw, on its own joint: a scoop in three slabs that step up and forward, past the snout
    jaw = m.part("Jaw", (-6, 0, -3), "Body")
    for x0, x1, n, bot in ((-9, -6, 5, -7), (-11, -9, 4, -6), (-13, -11, 3, -5)):
        jaw.hull(x0, x1, n, bot, bot + 4, "skin", [], [(3, 1), (1, 1)] if n == 5 else [(2, 1), (1, 1)])
        jaw.paint_sym(x0, x1, n, bot, EDGE, "belly")
        jaw.paint_sym(x0, x1, n, bot, bot + 1, "belly-")
    jaw.paint(-11, -9, -3, 4, -3, -2, "mouth")
    for y, long in ((0.95, 3.1), (2.6, 2.6)):
        jaw.tooth(-12.15, y, -1.12, 0.6, -long, "tooth", lean=(0.55, -0.15 * y))
    for x, y, z, long in ((-10.4, 3.9, -2.12, 2.7), (-7.85, 4.9, -3.12, 2.6), (-6.65, 4.9, -3.12, 2.0)):
        jaw.tooth(x, y, z, 0.5, -long, "tooth", lean=(0.2, -0.5))

    # the boom: the angler's rod, thick, from the forehead up and then forward past the mouth, in two pieces on joints,
    # each with a darker collar where it grows from the last; it ends buried in the lighthouse's rock
    rod1 = m.part("Rod1", (-7.3, 0, 6.6), "Body")
    rod1.beam((-7.1, 0, 5.4), (-9.0, 0, 10.6), 1.5, 1.4, "skin")
    rod1.beam((-7.25, 0, 5.8), (-7.75, 0, 7.2), 2.1, 2.0, "skin-")
    rod2 = m.part("Rod2", (-8.9, 0, 10.2), "Rod1")
    rod2.beam((-8.6, 0, 9.9), (-14.9, 0, 12.6), 1.1, 1.0, "skin")
    rod2.beam((-8.8, 0, 10.05), (-10.0, 0, 10.6), 1.6, 1.5, "skin-")
    lighthouse(m)
    beam(m)

    # the back of the ball: four more slabs, each one step smaller, in two parts so the back end swings
    b2 = m.part("B2", (1, 0, 0), "Body")
    slab(b2, 1, 3, 5, -7, 7)
    b2.sym(0, 1, 3, -5, 5, "skin-")
    b3 = m.part("B3", (3, 0, 0), "B2")
    slab(b3, 3, 5, 4, -6, 6)
    slab(b3, 5, 6, 3, -5, 5)
    slab(b3, 6, 7, 3, -4, 4)
    b3.sym(2, 3, 2, -4, 4, "skin-")
    for up in (1, -1):
        b3.beam((4.0, 0, up * 4.8), (5.6, 0, up * 7.0), 2.2, 0.9, "skin-")
        b3.beam((5.2, 0, up * 6.45), (6.3, 0, up * 7.9), 1.4, 0.6, "skin")

    for name, side in (("FinR", 1), ("FinL", -1)):
        fin = m.part(name, (2.2, side * 5.0, -1.6), "B2")
        fin.beam((2.0, side * 4.4, -1.5), (4.6, side * 7.0, -2.2), 2.6, 0.9, "skin-", flat="z")
        fin.beam((4.0, side * 6.4, -2.04), (5.5, side * 7.9, -2.45), 1.8, 0.6, "skin", flat="z")

    tail = m.part("Tail", (7, 0, 0), "B3")
    tail.beam((6.4, 0, 0), (9.8, 0, 0), 5.0, 3.2, "skin")
    tail.prism([(9.0, -2.0), (12.5, -3.6), (12.5, 3.6), (9.0, 2.0)], -0.25, 0.25, "skin")
    for up in (1, -1):
        tail.beam((8.8, 0, up * 1.2), (12.6, 0, up * 4.2), 2.0, 1.4, "skin-")
        needle(tail, (12.6, up * 4.2), (0.785, up * 0.62), 2.2, "tooth-")
    tail.beam((9.0, 0, 0), (13.6, 0, 0), 1.8, 1.0, "skin-")
    needle(tail, (13.6, 0.0), (1.0, 0.0), 2.4, "tooth-")
    lower(m)


def lower(m):
    """moves everything DZ cubes down: the kit's cameras aim at height 0, and this one is tall (the export centres it
    anyway, so the game doesn't see this)"""
    for part in m.parts.values():
        part.cells = {(i, j, k + DZ * part.fine): c for (i, j, k), c in part.cells.items()}
        part.shapes = [([(x, y, z + DZ) for x, y, z in verts], faces, c) for verts, faces, c in part.shapes]
        part.pivot = (part.pivot[0], part.pivot[1], part.pivot[2] + DZ)


FLOATING = ["Beam"]
