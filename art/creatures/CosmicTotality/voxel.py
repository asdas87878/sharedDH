"""Totality, a COSMIC (docs/design/cosmic.md, concept 4: the manta ray that carries an eclipse) for tools/blender/voxel_kit.py.
Its body starts from the Manta Ray's model (art/creatures/MantaRay, not changed), at half as big again.
Its idea: a living kite that holds up a dead sun. Everything is built round the eclipse.
- The set piece, ahead of the rider and high over the head: a black moon edge on to nothing, a thin white-hot ring
  hugging it, and round that a ragged corona of pale gold, long streamers to the sides and short plumes up and down,
  drawn in small pixels. One bright bead on the rim, up and to the right: the diamond ring.
- The manta holds it up: its two horns, which a manta keeps at its mouth, rise from the corners of the mouth and curl
  back over the moon's lower rim like two hands lifting a plate. Their tips are lit gold where they touch the light.
- The body is the calmest in the game: night navy above, pale below, no bars and no blotches. The only picture on it is
  a few small stars scattered over the wings.
- The eyes are small eclipses: a black pupil in a thin gold ring.
Moving: the wings flap in a wave; the moon leans back toward the rider and rocks a little; the corona turns once a swim
behind the moon (its own part, "Corona"), so the streamers wheel round it."""
import math

NAME, ZONE, RARITY = "Totality", "UNPLACED", "COSMIC"
U = 0.6
PALETTE = {"back": "#1B2140", "belly": "#D8DBEA", "pale": "#9AA3C7", "black": "#0B0C12", "mouth": "#0E1018", "gill": "#5C6382",
           "void": "#040409", "ring": "#FFFDF4", "flare": "#FFE38E", "corona": "#FFB13F", "haze": "#F07A34", "star": "#F4F1FF",
           "gold": "#FFC75E"}
SEAT = (0, 5, 2.58)
GLOW = {"ring": 1.0, "flare": 0.9, "corona": 0.75, "haze": 0.5, "star": 0.35, "gold": 0.8}
FRAME, ORTHO, ORTHO_SWIM = 3.5, 64.0, 66.0
FLOATING = ["Corona"]
SIDES = (("R", 1), ("L", -1))

# the eclipse, in the model's cubes: its middle, and the joint it leans on (the horns' grip, under the moon)
EC = (-8.0, 0.0, 18.0)
FINE = 2  # the eclipse's cubes are half the body's (0.3 studs), so the moon is round
R_MOON, R_RING = 13, 15  # in small cubes: the black moon's radius, the white ring's outer edge
LEAN = 10  # degrees: the moon leans back toward the rider
LIGHTS = [("Eclipse", (-6.8, 0.0, 25.4), "#FFE9C4", 260, 0.9)]


def pose(parts, phase):
    """the wings flap slowly in a wave from root to tip; the body rises and dips a little against them; the horns hold the
    moon (they barely move); the moon leans back and rocks; the corona turns once a swim; the tail trails"""
    for name, side in SIDES:
        parts["Wing" + name + "1"].rotation_euler.x = side * math.radians(14) * math.sin(phase)
        parts["Wing" + name + "2"].rotation_euler.x = side * math.radians(14) * math.sin(phase - 0.9)
        parts["Wing" + name + "3"].rotation_euler.x = side * math.radians(15) * math.sin(phase - 1.8)
        parts["Horn" + name].rotation_euler.z = side * math.radians(1.2) * math.sin(phase - 0.6)
    parts["Body"].rotation_euler.y = math.radians(1.5) * math.sin(phase - 1.2)
    parts["Eclipse"].rotation_euler.y = math.radians(LEAN) + math.radians(2.5) * math.sin(phase - 1.6)
    parts["Corona"].rotation_euler.x = -phase  # one whole turn a swim
    parts["Tail1"].rotation_euler.y = math.radians(5) * math.sin(phase - 1.4)
    parts["Tail2"].rotation_euler.y = math.radians(8) * math.sin(phase - 2.2)
    parts["Tail3"].rotation_euler.y = math.radians(11) * math.sin(phase - 3.0)
    parts["Tail2"].rotation_euler.z = math.radians(4) * math.sin(phase - 0.4)
    parts["Tail3"].rotation_euler.z = math.radians(6) * math.sin(phase - 1.2)


def plate(part, side, inner, outer, colour):
    """a flat wing plate between two cross-sections (y, leading x, trailing x, underside z, top z). side: 1 right, -1 left"""
    verts = []
    for y, lead, trail, low, high in (inner, outer):
        verts += [(lead, side * y, low), (trail, side * y, low), (trail, side * y, high), (lead, side * y, high)]
    part.solid(verts, [(0, 1, 2, 3), (4, 5, 6, 7), (0, 1, 5, 4), (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7)], colour)


def wing_plate(part, side, inner, outer, white, inset=0.3):
    """a navy wing plate with its pale underside: a thinner plate set in from the edges, its top just inside the navy"""
    plate(part, side, inner, outer, "back")
    (ya, la, ta, za, _), (yb, lb, tb, zb, _) = inner, outer
    plate(part, side, (ya + 0.2, la + inset, ta - inset, za - white, za + 0.05), (yb - 0.2, lb + inset, tb - inset, zb - white, zb + 0.05), "belly")


def stars(part, side, inner, outer, spots):
    """small stars lying on a wing plate's top: spots are (share of the way out, share of the way back, size). The top is
    flat across x and slopes along y, so each star is a little block sunk into the plate at its low side"""
    (ya, la, ta, _, za), (yb, lb, tb, _, zb) = inner, outer
    slope = (zb - za) / (yb - ya)
    for s, t, size in spots:
        y = ya + (yb - ya) * s
        lead, trail = la + (lb - la) * s, ta + (tb - ta) * s
        x = lead + (trail - lead) * t
        z = za + slope * (y - ya)
        h = size / 2
        sink = abs(slope) * h + 0.08
        section = (side * y - h, side * y + h, z - sink, z + 0.12) if side > 0 else (side * y - h, side * y + h, z - sink, z + 0.12)
        part.block(x - h, section, x + h, section, "star")


def hashed(k):
    """a fixed pseudo-random number in [0, 1) for an integer: the corona's raggedness, the same every build"""
    v = math.sin(k * 127.1 + 311.7) * 43758.5453
    return v - math.floor(v)


def corona_reach(theta):
    """how far the corona reaches at this angle, in small cubes: long streamers to the sides (the moon's equator), short
    plumes up and down, sixteen ragged lobes, and five narrow streamers that run on far past the rest"""
    reach = 17.5 + 9.0 * abs(math.cos(theta)) ** 3 + 2.0 * abs(math.sin(theta)) ** 6
    bins = 16
    f = (theta / (2 * math.pi)) % 1.0 * bins
    k0 = int(f)
    w = f - k0
    reach += 6.0 * ((1 - w) * hashed(k0) + w * hashed((k0 + 1) % bins)) - 2.0
    for angle, extra, width in ((8, 15, 3.5), (172, 16, 3.5), (196, 10, 2.5), (-22, 9, 2.5), (35, 7, 2.0), (140, 6, 2.0), (97, 5, 2.0), (262, 5, 2.0)):
        d = math.degrees(math.atan2(math.sin(theta - math.radians(angle)), math.cos(theta - math.radians(angle))))
        if abs(d) < width:
            reach += extra * (1 - abs(d) / width)
    return reach


def build(m):
    body = m.part("Body", (0, 0, 0))
    # the body: the manta's flat lens, a wide slab with a narrower step on top and underneath, a ridge down the middle
    body.hull(-13, -10, 5, -2, 3, "back", [(2, 1)], [(2, 1)])  # the head
    body.hull(-10, 5, 6, -2, 4, "back", [(4, 1), (2, 1)], [(2, 1)])  # between the wings
    body.sym(-4, 3, 2, 4, 5, "back+")  # the ridge, where the rider sits
    body.sym(-6, -4, 1, 4, 5, "back+")
    body.sym(3, 5, 1, 4, 5, "back+")
    body.hull(5, 8, 5, -2, 3, "back", [(3, 1)], [(2, 1)])
    body.hull(8, 10, 4, -2, 3, "back", [(2, 1)], [(2, 1)])
    body.hull(10, 12, 3, -1, 2, "back", [(1, 1)])
    body.sym(12, 14, 2, -1, 1, "back")
    body.sym(14, 15, 1, -1, 1, "back")
    body.paint(-13, 15, -8, 9, -2, 0, "belly")
    body.paint_sym(-13, -10, 3, 2, 3, "back+")
    body.paint_sym(-10, 5, 2, 3, 4, "back+")
    body.paint_sym(5, 10, 2, 2, 3, "back+")
    body.paint_sym(10, 12, 2, 1, 2, "back+")
    for x in (-9, -7, -5, -3, -1):  # five gill slits a side underneath: no blotches, the belly is plain
        body.paint_pair(x, x + 1, 1, 4, -2, -1, "gill")
    # the mouth: a wide dark slot across the very front
    body.carve(-13, -12, -3, 4, -1, 1)
    mouth = (-3.5, 3.5, -1, 1)
    body.block(-12.25, mouth, -11.95, mouth, "mouth")
    # the eyes are small eclipses: a gold ring, a black pupil standing out of it
    ring = (5.45, 5.8, 0.2, 1.6)
    body.block(-12.55, ring, -11.05, ring, "gold", mirror=True)
    pupil = (5.7, 6.05, 0.5, 1.3)
    body.block(-12.25, pupil, -11.35, pupil, "black", mirror=True)
    body.beam((10.3, 0, 1.2), (12.0, 0, 3.2), 1.5, 0.7, "back")  # a small fin at the root of the tail
    body.dent(-1, 1, 2, 3, 4, "back-")  # the seat: a shallow slot either side for the rider's legs

    for name, side in SIDES:
        # the horns: from the corners of the mouth they rise, lean out, then curl back and in over the moon's lower rim,
        # gold at the tips where the light falls on them
        horn = m.part("Horn" + name, (-12.5, 4.5 * side, 0.6), "Body")
        # a chain: each length starts 80% along the one before, so its root is buried in it
        joints = [(-11.4, 4.3, -0.2), (-13.6, 5.6, 5.6), (-12.4, 6.8, 10.4), (-9.6, 6.6, 13.6), (-6.4, 5.3, 14.0)]
        sizes = [(2.6, 1.3, "back"), (2.2, 1.1, "back"), (1.8, 0.95, "back+"), (1.4, 0.8, "gold")]
        start = joints[0]
        for (a, b), (wide, thick, colour) in zip(zip(joints, joints[1:]), sizes):
            horn.beam((start[0], start[1] * side, start[2]), (b[0], b[1] * side, b[2]), wide, thick, colour)
            start = tuple(sa + 0.8 * (sb - sa) for sa, sb in zip(start, b))

        # the wing: three plates in a chain on their own joints, rising toward a curled tip; a few stars on each
        one = m.part("Wing" + name + "1", (0, 6.0 * side, 0.6), "Body")
        w1 = ((4.0, -10.0, 9.0, 0.0, 1.7), (14.6, -7.3, 5.4, 0.0, 1.7))
        wing_plate(one, side, *w1, 0.55)
        stars(one, side, *w1, ((0.35, 0.3, 0.45), (0.7, 0.62, 0.3), (0.85, 0.2, 0.3)))
        two = m.part("Wing" + name + "2", (0, 14.0 * side, 0.8), "Wing" + name + "1")
        w2 = ((13.4, -7.2, 5.2, 0.2, 1.4), (23.6, -2.5, 4.6, 1.4, 2.6))
        wing_plate(two, side, *w2, 0.45)
        stars(two, side, *w2, ((0.25, 0.5, 0.3), (0.55, 0.22, 0.45), (0.8, 0.6, 0.3)))
        three = m.part("Wing" + name + "3", (0, 22.5 * side, 1.9), "Wing" + name + "2")
        w3 = ((22.6, -2.5, 4.3, 1.5, 2.25), (30.0, 4.6, 6.0, 3.1, 3.85))
        wing_plate(three, side, *w3, 0.35, inset=0.25)
        stars(three, side, *w3, ((0.4, 0.45, 0.3),))

    # ---- the eclipse, on its own joint at the horns' grip, so it leans and rocks. Small cubes (FINE). Three layers across
    # x: the moon and its white ring in front and behind, and between them the corona, which turns on a joint of its own
    cx, cz = round(EC[0] * FINE), round(EC[2] * FINE)
    ecl = m.part("Eclipse", (EC[0], 0.0, EC[2] - 6.0), "Body")
    ecl.fine = FINE
    for j in range(-R_RING - 1, R_RING + 2):
        for k in range(-R_RING - 1, R_RING + 2):
            r = math.hypot(j, k + 0.5)
            if r < R_MOON:
                colour = "void"
            elif r < R_RING:
                colour = "ring"
            else:
                continue
            for i in (cx, cx + 1):  # in front: two small cubes thick
                ecl.cells[(i, j, cz + k)] = colour
            ecl.cells[(cx - 2, j, cz + k)] = colour  # behind: one
    # the diamond ring: a bright bead swelling out of the rim up and to the right, a cross of light through it
    bead = (math.cos(math.radians(55)) * (R_RING + 0.5), math.sin(math.radians(55)) * (R_RING + 0.5))
    bj, bk = round(bead[0]), round(bead[1])
    for dj in range(-3, 4):
        for dk in range(-3, 4):
            if abs(dj) + abs(dk) <= 4 and math.hypot(dj, dk) < 3.2:
                for i in range(cx - 2, cx + 3):
                    ecl.cells[(i, bj + dj, cz + bk + dk)] = "ring"
    for d in range(4, 11):  # the cross: four thin rays in front of the corona, the outer ones fading to gold
        for dj, dk in ((d, 0), (-d, 0), (0, d), (0, -d)):
            if math.hypot(bj + dj, bk + dk + 0.5) >= R_RING:
                for i in (cx, cx + 1):
                    ecl.cells[(i, bj + dj, cz + bk + dk)] = "ring" if d < 7 else "flare"

    corona = m.part("Corona", (EC[0], 0.0, EC[2]), "Eclipse")
    corona.fine = FINE
    reach = 46
    for j in range(-reach, reach + 1):
        for k in range(-reach, reach + 1):
            r = math.hypot(j, k + 0.5)
            if r < R_MOON - 3:
                continue  # hidden behind the moon: left out
            theta = math.atan2(k + 0.5, j)
            edge = corona_reach(theta)
            if r >= edge:
                continue
            share = (r - R_RING) / max(edge - R_RING, 1.0)
            # the colour steps outward, its borders ragged by a fixed dither
            share += 0.18 * (hashed(j * 73 + k * 151) - 0.5)
            colour = "flare" if share < 0.22 else ("corona" if share < 0.62 else "haze")
            corona.cells[(cx - 1, j, cz + k)] = colour

    # ---- the tail: a thin whip in three lengths, each on its own joint
    tail = m.part("Tail1", (15, 0, 0), "Body")
    tail.beam((14.6, 0, 0), (22.0, 0, 0), 1.4, 1.2, "back")
    tail = m.part("Tail2", (21.6, 0, 0), "Tail1")
    tail.beam((21.2, 0, 0), (29.0, 0, 0), 1.0, 0.85, "back")
    tail = m.part("Tail3", (28.6, 0, 0), "Tail2")
    tail.beam((28.2, 0, 0), (35.0, 0, 0), 0.6, 0.5, "back")
    tail.beam((34.6, 0, 0), (35.6, 0, 0), 0.9, 0.9, "star")  # a star at the end of the whip
