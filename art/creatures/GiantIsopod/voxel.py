"""The Giant Isopod (zone 8's Epic: the giant deep-sea woodlouse, Bathynomus) for tools/blender/voxel_kit.py
(docs/style/04-voxel-style.md). Designed from the real animal.
Its idea: an armoured dome of a few big overlapping plates, with two big triangular eyes that shine back at you.
- The back is five big plates and a short narrow pleon. Every plate has the same section: a wide flat crown, one broad
  step (the shoulder), a wall (the skirt), a pale belly set in underneath. The crown rises a cube a plate to the middle
  and falls again, and narrows with it; the middle plate is also a cube deeper in the shoulder and the belly. So the back
  and the belly curve from the side and the animal is an oval from above. The last row of each plate is a darker seam:
  the overlap.
- One thin rose line runs the whole length under the shoulder (the accent).
- The head is a small shield tucked under the first plate, with a sloping front. The eyes are pale triangles on dark
  slabs set across its front corners, so they show from the front and the side; they shine (the animal's eyes reflect).
- Two pairs of antennae: a short pair up front, a long pair that sweeps out and back, on joints of their own.
- Six pairs of short legs tucked under the skirt: the front three lean forward, the back three lean back.
- The tail is a fan: a telson of three plates, each smaller, three small spines on its edge, a paddle either side.
The rider sits on the crown of the biggest plate; a shallow slot in the shoulder either side takes the legs."""
import math

NAME, ZONE, RARITY = "Giant Isopod", "ZONE 8 / VENTS", "EPIC"
U = 0.4
PALETTE = {"shell": "#B9B1CB", "belly": "#E7E0EC", "plum": "#4A4059", "shine": "#E9F6F1", "rose": "#C77FA6"}
SEAT = (-3.5, 8, 4.5)
GLOW = {"shine": 0.4}  # the eyes only: they reflect
FRAME, ORTHO = 1.45, 21.0
TEXTURES = [{"tile": "stud", "on": "top", "colours": ["shell"]}]

# the plates: (part, parent, from, to, cubes out, the crown's height, the shoulder's, the skirt's hem). The first is the
# root: the seat
PLATES = (("Body", None, -7, -1, 9, 8, 5, -1), ("P2", "Body", -11, -7, 8, 7, 4, 0), ("P1", "P2", -15, -11, 7, 6, 4, 1),
          ("P4", "Body", -1, 4, 9, 7, 4, 0), ("P5", "P4", 4, 8, 8, 6, 4, 0), ("Pleon", "P5", 8, 12, 6, 5, 4, 1))
# the swim: each joint's turn in degrees and how far behind the seat's beat it is
WAVE = (("P2", 2.0, -0.6), ("P1", 2.5, -1.2), ("Head", 3.0, -1.8), ("P4", 2.5, 0.6), ("P5", 3.5, 1.2), ("Pleon", 5.0, 1.8),
        ("Tail", 8.0, 2.4))


def pose(parts, phase):
    """a slow wave up and down the armour, from the head to the tail fan, which beats widest; the long antennae sway"""
    for name, degrees, lag in WAVE:
        parts[name].rotation_euler.y = math.radians(degrees) * math.sin(phase - lag)
    for name, side in (("AntennaR", 1), ("AntennaL", -1)):
        parts[name].rotation_euler.z = side * math.radians(7) * math.sin(phase - 1.0)


def plate(p, x0, x1, n, top, shoulder, hem):
    """one plate of the back: a crown (a wide plateau), a broad step down to the shoulder, the skirt's wall (its top is at
    2 on every plate), a pale belly set in underneath"""
    p.hull(x0, x1, n, hem - 1, top, "shell", [(5, top - shoulder), (2, shoulder - 2)], [(2, 1)])
    p.paint_sym(x0, x1, n, top - 1, top, "shell+")
    p.paint_sym(x1 - 1, x1, n, hem, top, "shell-")  # the seam: the plate's back edge, over the next one
    p.paint_sym(x0, x1, n, 2, 3, "rose")  # the thin line under the shoulder, the whole length
    p.paint_sym(x0, x1, n, hem - 1, hem, "belly")


def sleeve(p, x0, x1, half, z0, z1):
    """a hidden block from inside this piece into its parent, clear of both pieces' steps, so a bending joint shows body"""
    section = (-half, half, z0, z1)
    p.block(x0, section, x1, section, "shell-")


def leg(p, x, n, hem, lean):
    """a short leg tucked under the skirt: out and down from the belly, its tip just inside the body's edge"""
    p.beam((x, n - 3.5, hem + 0.4), (x + lean, n - 0.7, hem - 2.5), 1.1, 0.9, "belly", mirror=True)


def build(m):
    parts = {}
    for name, parent, x0, x1, n, top, shoulder, hem in PLATES:
        pivot = (x1 if x1 <= -7 else x0, 0, 2.5)
        parts[name] = m.part(name, pivot if parent else (-4, 0, 2.5), parent)
        plate(parts[name], x0, x1, n, top, shoulder, hem)
    body, pleon = parts["Body"], parts["Pleon"]
    pleon.paint_sym(9, 10, 6, 1, 5, "shell-")  # the pleon is short segments: one more seam
    pleon.paint_sym(9, 10, 6, 2, 3, "rose")
    # the oval from above: the outer corner is cut off the first plate's front and the last plates' backs
    parts["P1"].carve_pair(-15, -13, 7, 8, 0, 6)
    parts["P5"].carve_pair(6, 8, 8, 9, -1, 6)
    pleon.carve_pair(11, 12, 6, 7, 0, 5)
    sleeve(parts["P2"], -7.6, -6.0, 5.2, 0.3, 3.6)
    sleeve(parts["P1"], -11.6, -10.0, 4.2, 1.3, 3.6)
    sleeve(parts["P4"], -1.7, -0.4, 6.2, 0.3, 3.6)
    sleeve(parts["P5"], 3.0, 4.6, 5.2, 0.3, 3.6)
    sleeve(pleon, 7.0, 8.6, 3.2, 1.3, 3.6)

    # the seat: a shallow slot in the shoulder either side of the crown, for the rider's legs
    body.carve_pair(-5, -2, 5, 7, 4, 5)
    slot = (4.45, 6.5, 3.9, 4.5)
    body.block(-5.0, slot, -2.0, slot, "shell-", mirror=True)

    # the legs: six pairs, the front three leaning forward, the back three leaning back
    for name, x, lean in (("P1", -13.0, -0.9), ("P2", -9.2, -0.9), ("Body", -5.7, -0.9), ("Body", -2.3, 0.9), ("P4", 1.4, 0.9),
                          ("P5", 5.6, 0.9)):
        n, hem = next((row[4], row[7]) for row in PLATES if row[0] == name)
        leg(parts[name], x, n, hem, lean)

    # the head: a small shield tucked under the first plate, its front a block that slopes down
    head = m.part("Head", (-15, 0, 2.5), "P1")
    head.sym(-18, -15, 4, 1, 4, "shell")
    head.paint_sym(-18, -15, 4, 3, 4, "shell+")
    head.paint_sym(-18, -15, 4, 1, 2, "belly")
    head.carve_pair(-18, -17, 4, 5, 1, 4)  # the front corners are cut: the eyes lie across them
    sleeve(head, -15.6, -14.0, 3.2, 1.4, 3.5)
    head.beam((-17.4, 0, 2.9), (-19.8, 0, 1.9), 6.0, 1.7, "shell", flat="z")
    # the eyes: a dark slab across each front corner, and on it a big pale triangle, wide at the outside, its point
    # toward the middle. It shines
    head.beam((-18.3, 2.2, 2.5), (-16.1, 4.4, 2.5), 2.6, 1.8, "plum", flat="y", mirror=True)

    def on_slab(u, z, out):
        return (-18.3 + 0.7071 * (u - out), 2.2 + 0.7071 * (u + out), z)

    corners = ((0.3, 2.0), (2.85, 1.5), (2.85, 3.55))
    eye = [on_slab(u, z, 1.25) for u, z in corners] + [on_slab(u, z, 0.6) for u, z in corners]
    head.solid(eye, [(0, 1, 2), (3, 5, 4), (0, 1, 4, 3), (1, 2, 5, 4), (2, 0, 3, 5)], "shine", mirror=True)
    # the short antennae: up and forward from the front
    head.beam((-18.2, 1.0, 2.7), (-20.6, 1.9, 4.0), 0.7, 0.7, "shell-", flat="z", mirror=True)
    # the long antennae, each on its own joint: a stalk out and forward under the eye, then a whip that sweeps back
    for name, side in (("AntennaR", 1), ("AntennaL", -1)):
        whip = m.part(name, (-17.6, 1.2 * side, 1.6), "Head")
        whip.beam((-17.6, 1.2 * side, 1.6), (-20.2, 3.4 * side, 1.2), 0.9, 0.9, "shell", flat="z")
        whip.beam((-19.9, 3.1 * side, 1.2), (-14.5, 9.8 * side, 1.6), 0.6, 0.6, "shell-", flat="z")

    # the tail fan, on its own joint: a telson of three plates, each smaller and thinner and starting inside the last,
    # three small spines on its edge, and a paddle either side in two boxes
    tail = m.part("Tail", (12, 0, 2.5), "Pleon")
    tail.beam((11.2, 0, 2.6), (15.5, 0, 2.3), 8.4, 1.8, "shell", flat="z")
    tail.beam((14.6, 0, 2.35), (18.2, 0, 2.0), 6.6, 1.2, "shell", flat="z")
    tail.beam((17.6, 0, 2.05), (19.2, 0, 1.9), 4.2, 0.7, "shell-", flat="z")
    for y in (0.0, 1.4):
        base = [(18.9, y - 0.45, 1.7), (18.9, y + 0.45, 1.7), (18.9, y + 0.45, 2.2), (18.9, y - 0.45, 2.2)]
        tail.spike(base, (20.1, y, 1.9), "belly", mirror=y > 0)
    tail.beam((12.2, 2.6, 2.3), (17.4, 7.0, 1.8), 3.0, 0.9, "shell", flat="z", mirror=True)
    tail.beam((16.3, 6.1, 1.9), (18.7, 7.9, 1.65), 2.0, 0.5, "shell-", flat="z", mirror=True)
