"""The submarine in several styles, for the user to pick one (docs/design/sub-models.md).

    blender --background --python tools/blender/sub_kit.py -- <A|B|C|D> <out folder> [--export <folder>] [--frame 1.4] [--px 2]

Every option is the SAME sub, tier 1 "The Bathtub" (Shared/SubModels: yellow hull, navy trim, cyan glass), on the
placeholder's own measures, so the ride doesn't change with the look: about 36 studs long and 10 across, the tower in
front of the middle, the seat's top 5.7 studs over the middle and 5 behind it, a bar for the hands, two ports a side,
wings by the nose, a cross of fins and a propeller at the tail, a lamp under the nose.
  A  chunky toy      fat rounded forms, few sides, smooth shaded, thick rims
  B  sleek faceted   flat planes, a pointed nose, swept fins (the old creature kit's look)
  C  retro riveted   a boiler with hoops, rivets, brass rims, a lantern and a rail
  D  voxel           the creatures' block style: few big boxes on a grid, slopes are turned blocks, studs on top
Here: X runs nose (-X) to tail, Z is up. One mesh object to a part (Hull, Tower, Window, Ports, Seat, Bar, Wings, Fins,
Prop, Light, plus a style's own); Seat, Light and Prop are the names SubController needs. Colours are plain materials,
one a colour; glowing ones are named *_Glow. Renders: hero, side, front, top (transparent) and ride (with a rider).
--export writes <folder>/Sub_<style>.glb in Roblox's axes (+Y up, nose to -Z), 1 unit = 1 stud.
--frame <k> stands the hero and side cameras where tools/blender/sub_stages.py stands them for a tier whose stats.json
says "frame": k, so the two can be laid side by side at one scale (sub_stages.py compare); --px <k> scales the renders.
(The side view is 1000 px for 46 x k studs in both; sub_stages.py makes a tier's taller when a tall add-on needs it,
which leaves the scale alone. This model fits the 480 px at every k from 1 up.)"""
import math
import os
import sys

import bmesh
import bpy
from mathutils import Euler, Matrix, Vector

argv = sys.argv[sys.argv.index("--") + 1 :]
STYLE, OUT = argv[0].upper(), argv[1]
EXPORT = argv[argv.index("--export") + 1] if "--export" in argv else None
FRAME = float(argv[argv.index("--frame") + 1]) if "--frame" in argv else None
PX = float(argv[argv.index("--px") + 1]) if "--px" in argv else 1.0
HERE = os.path.dirname(os.path.abspath(__file__))
STUD = os.path.join(HERE, "..", "..", "art", "style", "tiles", "stud.png")

PALETTE = {
    "hull": "#FFC426", "hull+": "#FFD75E", "hull-": "#E3A30F", "trim": "#28364E", "trim+": "#3D5173", "glass": "#78DCFF",
    "lamp": "#FFFAD2", "white": "#F4F1E6", "red": "#E8503A", "brass": "#C98A2B", "brass+": "#E8B44C", "copper": "#B5653A",
    "iron": "#4A5560", "seat": "#7A4B2E",
}
GLOW = {"glass": 1.6, "lamp": 4.0}
STUDDED = ("hull", "hull+", "trim")  # voxel style: these colours carry studs on faces that look up
U = 1.0  # the voxel style's cube, in studs


def lin(c):
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def rgba(h):
    h = h.lstrip("#")
    return tuple(lin(int(h[i : i + 2], 16) / 255) for i in (0, 2, 4)) + (1.0,)


bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
for engine in ("BLENDER_EEVEE", "BLENDER_EEVEE_NEXT"):
    try:
        scene.render.engine = engine
        break
    except TypeError:
        pass
scene.view_settings.view_transform = "Standard"
try:
    scene.eevee.taa_render_samples = 64
except AttributeError:
    pass
os.makedirs(OUT, exist_ok=True)

MATS, ORDER = {}, []


def mat(name):
    """the material of a colour; "<colour>*" is that colour with the stud tile on it (the voxel style's tops)"""
    if name in MATS:
        return ORDER.index(name)
    base = name.rstrip("*")
    m = bpy.data.materials.new(base + ("_Stud" if name.endswith("*") else "") + ("_Glow" if base in GLOW else ""))
    m.use_nodes = True
    nt = m.node_tree
    b = nt.nodes.get("Principled BSDF")
    b.inputs["Base Color"].default_value = rgba(PALETTE[base])
    b.inputs["Roughness"].default_value = 0.4 if base.startswith("brass") or base == "copper" else 0.65
    if "Specular IOR Level" in b.inputs:
        b.inputs["Specular IOR Level"].default_value = 0.25
    if base.startswith("brass") or base == "copper":
        b.inputs["Metallic"].default_value = 0.55
    if base in GLOW:
        b.inputs["Emission Color"].default_value = rgba(PALETTE[base])
        b.inputs["Emission Strength"].default_value = GLOW[base]
    if name.endswith("*"):  # the grey tile times the colour (mid grey leaves it), one tile to a cube, laid on the world's grid
        geo = nt.nodes.new("ShaderNodeNewGeometry")
        mp = nt.nodes.new("ShaderNodeMapping")
        mp.inputs["Scale"].default_value = (1 / U, 1 / U, 1 / U)
        tex = nt.nodes.new("ShaderNodeTexImage")
        tex.image = bpy.data.images.load(os.path.abspath(STUD))
        tex.image.colorspace_settings.name = "Non-Color"
        mul = nt.nodes.new("ShaderNodeMixRGB")
        mul.blend_type = "MULTIPLY"
        mul.inputs["Fac"].default_value = 1.0
        mul.inputs["Color1"].default_value = rgba(PALETTE[base])
        gain = nt.nodes.new("ShaderNodeMath")
        gain.operation = "MULTIPLY"
        gain.inputs[1].default_value = 255 / 128
        nt.links.new(geo.outputs["Position"], mp.inputs["Vector"])
        nt.links.new(mp.outputs["Vector"], tex.inputs["Vector"])
        nt.links.new(tex.outputs["Color"], gain.inputs[0])
        nt.links.new(gain.outputs[0], mul.inputs["Color2"])
        nt.links.new(mul.outputs["Color"], b.inputs["Base Color"])
    MATS[name] = m
    ORDER.append(name)
    return len(ORDER) - 1


PARTS = {}  # name -> {"bm", "smooth", "origin"}


def part(name, origin=(0, 0, 0), smooth=False):
    if name not in PARTS:
        PARTS[name] = {"bm": bmesh.new(), "smooth": smooth, "origin": Vector(origin)}
        PARTS[name]["bm"].faces.layers.int.new("done")
    return PARTS[name]["bm"]


def paint(bm, before, colour, stud=False):
    done = bm.faces.layers.int.get("done") or bm.faces.layers.int.new("done")
    for f in bm.faces:  # the new faces are the unmarked ones (a table's order isn't the order they were made in)
        if f[done]:
            continue
        f[done] = 1
        f.normal_update()
        f.material_index = mat(colour + "*") if stud and colour in STUDDED and f.normal.z > 0.95 else mat(colour)


def fresh(bm):
    done = bm.faces.layers.int.get("done") or bm.faces.layers.int.new("done")
    return [f for f in bm.faces if not f[done]]


def rot(r):
    return Euler([math.radians(a) for a in r]).to_matrix().to_4x4()


def box(p, c, size, colour, r=(0, 0, 0), stud=False):
    """a box centred on c, turned by r (degrees about X, Y, Z)"""
    bm = part(p)
    n = len(bm.faces)
    bmesh.ops.create_cube(bm, size=1.0, matrix=Matrix.Translation(c) @ rot(r) @ Matrix.Diagonal((*size, 1.0)))
    paint(bm, n, colour, stud)


AXIS = {"x": (0, 90, 0), "y": (90, 0, 0), "z": (0, 0, 0)}


def cyl(p, c, radius, depth, colour, axis="x", n=12, r2=None, r=None, spin=0.0):
    """a cylinder (or a cone: r2 is the radius at its +axis end... for x: the tail end) centred on c"""
    bm = part(p)
    k = len(bm.faces)
    m = Matrix.Translation(c) @ rot(r if r is not None else AXIS[axis]) @ Matrix.Rotation(spin, 4, "Z")
    bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=n, radius1=radius,
                          radius2=radius if r2 is None else r2, depth=depth, matrix=m)
    paint(bm, k, colour)


def ball(p, c, radius, colour, u=10, v=6, scale=(1, 1, 1), r=(0, 90, 0)):
    bm = part(p)
    k = len(bm.faces)
    bmesh.ops.create_uvsphere(bm, u_segments=u, v_segments=v, radius=radius,
                              matrix=Matrix.Translation(c) @ Matrix.Diagonal((*scale, 1.0)) @ rot(r))
    paint(bm, k, colour)


def loft(p, stations, n, colour, phase=0.0, power=1.0):
    """a body along X: at each station (x, half width, half height, middle z) a ring of n points; power under 1 squares
    the ring's corners (a superellipse). Closed at both ends."""
    bm = part(p)
    k = len(bm.faces)
    rings = []
    for x, hw, hh, zc in stations:
        ring = []
        for i in range(n):
            a = phase + 2 * math.pi * i / n
            ca, sa = math.cos(a), math.sin(a)
            ring.append(bm.verts.new((x, hw * math.copysign(abs(ca) ** power, ca), zc + hh * math.copysign(abs(sa) ** power, sa))))
        rings.append(ring)
    for a, b in zip(rings, rings[1:]):
        for i in range(n):
            j = (i + 1) % n
            bm.faces.new((a[i], b[i], b[j], a[j]))
    bm.faces.new(rings[0])
    bm.faces.new(list(reversed(rings[-1])))
    bmesh.ops.recalc_face_normals(bm, faces=fresh(bm))
    paint(bm, k, colour)


def ring(p, x, zc, r_out, r_in, width, n, colour):
    """a hoop with thickness round the X axis (closed, so nothing is seen from behind)"""
    bm = part(p)
    rows = []
    for dx, r in ((-width / 2, r_out), (width / 2, r_out), (width / 2, r_in), (-width / 2, r_in)):
        rows.append([bm.verts.new((x + dx, r * math.cos(2 * math.pi * i / n), zc + r * math.sin(2 * math.pi * i / n))) for i in range(n)])
    new = []
    for a, b in zip(rows, rows[1:] + rows[:1]):
        for i in range(n):
            j = (i + 1) % n
            new.append(bm.faces.new((a[i], b[i], b[j], a[j])))
    bmesh.ops.recalc_face_normals(bm, faces=new)
    paint(bm, 0, colour)


def plate(p, pts, thick, colour, plane="xz", at=0.0, r=(0, 0, 0), c=(0, 0, 0)):
    """a flat polygon with thickness: pts in the plane ("xz": a fin standing up, at y = at; "xy": a wing lying flat, at
    z = at), then turned by r about c"""
    bm = part(p)
    k = len(bm.faces)
    h = thick / 2
    def v(a, b, o):
        return (a, at + o, b) if plane == "xz" else (a, b, at + o)
    m = Matrix.Translation(c) @ rot(r) @ Matrix.Translation([-q for q in c])
    lo = [bm.verts.new(m @ Vector(v(a, b, -h))) for a, b in pts]
    hi = [bm.verts.new(m @ Vector(v(a, b, h))) for a, b in pts]
    bm.faces.new(lo)
    bm.faces.new(list(reversed(hi)))
    for i in range(len(pts)):
        j = (i + 1) % len(pts)
        bm.faces.new((lo[i], hi[i], hi[j], lo[j]))
    bmesh.ops.recalc_face_normals(bm, faces=fresh(bm))
    paint(bm, k, colour)


# ------------------------------------------------------------------------------------------------ A: chunky toy
def style_a():
    part("Hull", smooth=True), part("Tower", smooth=True), part("Light", smooth=True), part("Ports", smooth=True)
    n = 12
    loft("Hull", [(-18.0, 1.2, 1.2, -0.6), (-17.0, 3.2, 3.0, -0.3), (-14.5, 4.9, 4.7, 0), (-9, 5.6, 5.3, 0), (4, 5.6, 5.3, 0),
                  (10, 4.9, 4.7, 0.2), (14, 3.3, 3.2, 0.5), (16.2, 1.6, 1.6, 0.7)], n, "hull", phase=math.pi / n)
    # a fat belt round the middle and a white belly stripe: the toy's two-tone
    loft("Hull", [(-9.2, 5.85, 5.55, 0), (-7.6, 5.85, 5.55, 0)], n, "trim", phase=math.pi / n)
    loft("Hull", [(4.4, 5.85, 5.55, 0), (6.0, 5.85, 5.55, 0)], n, "trim", phase=math.pi / n)
    # the tower: a fat rounded block with a navy cap and a bubble window
    loft("Tower", [(-7.0, 2.2, 2.0, 5.6), (-6.2, 3.0, 3.4, 6.4), (1.6, 3.0, 3.4, 6.4), (2.6, 2.4, 2.6, 6.0)], 8, "hull",
         phase=math.pi / 8, power=0.75)
    cyl("Tower", (-2, 0, 10.0), 3.5, 0.9, "trim", axis="z", n=10)
    cyl("Tower", (-2, 0, 10.8), 2.2, 0.8, "trim+", axis="z", n=10)
    part("Window", smooth=True)
    ball("Window", (-6.6, 0, 7.2), 2.0, "glass", u=10, v=6, scale=(0.55, 1, 1))
    cyl("Tower", (-6.5, 0, 7.2), 2.5, 0.7, "trim", axis="x", n=10)
    for s in (-1, 1):
        for x in (-11.5, 0.5):
            cyl("Ports", (x, s * 5.35, 0.6), 1.9, 0.9, "trim", axis="y", n=10)
            cyl("Ports", (x, s * 5.7, 0.6), 1.3, 0.5, "glass", axis="y", n=10)
        # stubby wings, fat as a bar of soap
        box("Wings", (-7, s * 7.4, -1.2), (4.2, 4.6, 1.3), "trim", r=(s * -8, 0, s * -10))
        box("Wings", (-7.2, s * 9.6, -1.5), (3.2, 1.0, 1.7), "red", r=(s * -8, 0, s * -10))
    box("Seat", (5, 0, 5.2), (3.6, 3.6, 1.0), "seat")
    box("Seat", (7.0, 0, 6.1), (0.8, 3.6, 2.2), "seat", r=(0, 12, 0))
    for s in (-1, 1):
        cyl("Bar", (2.6, s * 1.9, 5.9), 0.35, 2.2, "trim", axis="z", n=6)
    cyl("Bar", (2.6, 0, 6.9), 0.4, 4.6, "trim", axis="y", n=6)
    # the tail: four fat paddles and a big three-blade propeller in a ring
    box("Fins", (13.4, 0, 0.5), (3.6, 1.1, 11.5), "trim")
    box("Fins", (13.4, 0, 0.5), (3.6, 12.5, 1.1), "trim")
    cyl("Fins", (16.6, 0, 0.7), 4.3, 1.6, "red", axis="x", n=12)
    cyl("Fins", (16.6, 0, 0.7), 3.7, 1.7, "trim", axis="x", n=12)
    part("Prop", origin=(17.6, 0, 0.7))
    cyl("Prop", (17.4, 0, 0.7), 1.2, 1.8, "trim+", axis="x", n=8, r2=0.6)
    for a in (0, 60, 120):
        box("Prop", (17.7, 0, 0.7), (0.5, 1.7, 6.6), "white", r=(a, 0, 0))
    ball("Light", (-16.6, 0, -2.6), 1.7, "lamp", u=8, v=6)
    cyl("Hull", (-16.0, 0, -2.6), 2.1, 1.4, "trim", axis="x", n=10)
    # a wind-up key on the back: the toy's joke
    cyl("Key", (11.2, 0, 5.4), 0.4, 2.6, "red", axis="z", n=6)
    box("Key", (11.2, 0, 7.4), (2.6, 0.6, 1.6), "red")


# ------------------------------------------------------------------------------------------------ B: sleek faceted
def style_b():
    n = 6  # a six-sided hull with an edge along each side, so it reads as a blade
    loft("Hull", [(-19.5, 0.3, 0.25, -0.9), (-15.5, 2.9, 2.4, -0.4), (-9.5, 4.7, 4.3, 0), (0, 5.0, 4.9, 0.1), (8, 4.0, 4.0, 0.4),
                  (14, 2.2, 2.3, 0.8), (17, 0.9, 1.0, 1.0)], n, "hull")
    # a darker belly keel and a light spine plate: two tones by plane, like the faceted creatures
    loft("Hull", [(-14.5, 1.9, 1.0, -3.0), (-9, 3.0, 1.4, -3.9), (2, 3.1, 1.5, -4.2), (12, 1.4, 1.0, -2.2)], 4, "trim")
    # the tower: a swept canopy, leaning back
    plate("Tower", [(-8.5, 3.6), (-4.5, 9.4), (1.2, 9.9), (3.0, 3.8)], 3.6, "hull+", plane="xz")
    plate("Tower", [(-4.9, 9.3), (1.6, 9.9), (2.2, 10.5), (-3.6, 10.5)], 4.2, "trim", plane="xz")
    plate("Window", [(-8.0, 4.9), (-5.4, 8.6), (-4.2, 8.6), (-5.6, 4.9)], 3.9, "glass", plane="xz")
    for s in (-1, 1):
        for x in (-11, -1):
            plate("Ports", [(x - 1.6, -0.3), (x - 0.6, 1.5), (x + 1.8, 1.5), (x + 0.8, -0.3)], 0.5, "glass", plane="xz",
                  at=s * (4.45 if x == -11 else 4.75), r=(s * -8, 0, 0), c=(x, s * 4.6, 0.6))
        # swept wings with a dark tip, bent down a little
        plate("Wings", [(-10.5, 3.6), (-3.0, 10.5), (-0.8, 10.5), (-4.5, 3.6)], 0.7, "trim", plane="xy", at=-1.0,
              r=(s * -14, 0, 0), c=(-7, 3.6, -1)) if s == 1 else plate(
            "Wings", [(-10.5, -3.6), (-4.5, -3.6), (-0.8, -10.5), (-3.0, -10.5)], 0.7, "trim", plane="xy", at=-1.0,
            r=(14, 0, 0), c=(-7, -3.6, -1))
        # tail planes
        plate("Fins", [(10.5, s * 1.5), (15.5, s * 7.5), (17.5, s * 7.5), (15.5, s * 1.0)][:: s], 0.6, "trim", plane="xy", at=0.9)
        # a racing stripe on the upper side plane
        plate("Hull", [(-12.5, 2.0), (-11.0, 2.9), (9.0, 2.9), (9.6, 2.0)], 0.3, "white", plane="xz",
              at=s * 4.35, r=(s * -30, 0, 0), c=(0, s * 4.3, 2.4))
    plate("Fins", [(9.5, 2.0), (15.8, 8.8), (17.8, 8.8), (15.8, 1.6)], 0.7, "trim", plane="xz")
    plate("Fins", [(11.5, -0.4), (15.4, -4.6), (17.0, -4.6), (15.6, 0.0)], 0.7, "trim", plane="xz")
    box("Seat", (5, 0, 5.15), (3.6, 3.2, 1.1), "trim+")
    plate("Seat", [(6.4, 5.0), (7.0, 7.6), (7.8, 7.6), (8.2, 5.0)], 3.2, "trim+", plane="xz")
    for s in (-1, 1):
        box("Bar", (2.9, s * 1.8, 5.8), (0.5, 0.5, 2.4), "trim", r=(0, 14, 0))
    box("Bar", (2.6, 0, 6.9), (0.6, 4.6, 0.6), "trim")
    part("Prop", origin=(17.6, 0, 1.0))
    cyl("Prop", (17.5, 0, 1.0), 0.9, 1.6, "trim+", axis="x", n=6, r2=0.25)
    for a in (0, 90):
        plate("Prop", [(17.3, -2.4), (17.9, -2.4), (18.2, 1.0), (17.9, 4.4), (17.3, 4.4)], 1.1, "white", plane="xz",
              at=0.0, r=(a, 0, 0), c=(17.6, 0, 1.0))
    # the lamp: a slit under the nose
    plate("Light", [(-17.2, -2.4), (-15.6, -3.6), (-14.2, -3.6), (-14.6, -2.4)], 2.2, "lamp", plane="xz")


# ------------------------------------------------------------------------------------------------ C: retro riveted
def style_c():
    part("Hull", smooth=True), part("Tower", smooth=True), part("Light", smooth=True), part("Window", smooth=True)
    n = 14
    ph = math.pi / n
    # a boiler: a straight barrel, a domed nose, a cone for a tail
    loft("Hull", [(-17.6, 1.5, 1.5, 0), (-16.6, 3.3, 3.3, 0), (-14.6, 4.6, 4.6, 0), (-12, 5.0, 5.0, 0), (8, 5.0, 5.0, 0),
                  (12, 3.9, 3.9, 0.2), (16.4, 1.7, 1.7, 0.5)], n, "hull", phase=ph)
    for x in (-12, -5.4, 1.2, 8):  # hoops, each with a ring of rivets
        loft("Hoops", [(x - 0.55, 5.3, 5.3, 0), (x + 0.55, 5.3, 5.3, 0)], n, "brass", phase=ph)
    for x in (-12, -5.4, 1.2, 8):
        for i in range(n):
            a = ph + 2 * math.pi * (i + 0.5) / n
            if math.sin(a) > 0.93 and -7 < x < 3:
                continue  # under the tower
            box("Rivets", (x, 5.3 * math.cos(a) * 0.985, 5.3 * math.sin(a) * 0.985), (0.55, 0.55, 0.55), "brass+",
                r=(math.degrees(a) - 90, 0, 0))
    # plates: a darker panel along each flank between the hoops
    # the tower: a round turret with a brass collar, a hatch wheel on top
    cyl("Tower", (-2, 0, 6.6), 3.0, 5.4, "hull", axis="z", n=12)
    cyl("Tower", (-2, 0, 4.9), 3.5, 0.9, "brass", axis="z", n=12)
    cyl("Tower", (-2, 0, 9.5), 3.3, 0.7, "brass", axis="z", n=12)
    ball("Tower", (-2, 0, 9.8), 2.9, "copper", u=12, v=6, scale=(1, 1, 0.35), r=(0, 0, 0))
    cyl("Window", (-4.9, 0, 7.2), 1.5, 0.7, "glass", axis="x", n=10)
    cyl("Tower", (-4.75, 0, 7.2), 2.0, 0.6, "brass", axis="x", n=10)
    for i in range(6):
        a = math.pi / 3 * i
        box("Rivets", (-5.05, 1.75 * math.cos(a), 7.2 + 1.75 * math.sin(a)), (0.3, 0.4, 0.4), "brass+")
    for s in (-1, 1):
        for x in (-8.7, -2.1):
            cyl("Ports", (x, s * 5.0, 0.6), 1.9, 0.8, "brass", axis="y", n=10)
            cyl("Ports", (x, s * 5.25, 0.6), 1.3, 0.6, "glass", axis="y", n=10)
        # dive planes: riveted iron paddles on an axle
        cyl("Wings", (-14.2, s * 5.2, -0.6), 0.45, 3.0, "iron", axis="y", n=6)
        box("Wings", (-14.2, s * 7.6, -0.6), (3.6, 3.4, 0.6), "copper", r=(0, 8, 0))
        # a rail along the deck on posts
        for x in (-9.5, 9.5):
            cyl("Rail", (x, s * 2.6, 5.6), 0.22, 2.6, "iron", axis="z", n=5)
        cyl("Rail", (9.0, s * 2.6, 6.8), 0.22, 1.4, "iron", axis="x", n=5)
        cyl("Rail", (-8.0, s * 2.6, 6.8), 0.22, 3.2, "iron", axis="x", n=5)
    # a deck plank under the seat
    box("Seat", (5.0, 0, 4.95), (9.5, 4.6, 0.5), "seat")
    box("Seat", (5, 0, 5.45), (3.4, 3.4, 0.5), "copper")
    for s in (-1, 1):
        cyl("Bar", (2.6, s * 1.9, 6.0), 0.3, 1.9, "brass", axis="z", n=6)
    cyl("Bar", (2.6, 0, 6.9), 0.35, 4.6, "brass", axis="y", n=6)
    # the tail: a cross of plate fins inside a brass guard ring, a two-blade screw
    box("Fins", (13.6, 0, 0.4), (3.6, 0.6, 11.0), "copper")
    box("Fins", (13.6, 0, 0.4), (3.6, 11.0, 0.6), "copper")
    part("Guard", smooth=True)
    ring("Guard", 14.6, 0.4, 5.7, 5.2, 1.2, 14, "brass")
    part("Prop", origin=(17.3, 0, 0.5))
    cyl("Prop", (17.2, 0, 0.5), 0.9, 1.8, "brass+", axis="x", n=8, r2=0.5)
    for a in (0, 90):
        box("Prop", (17.4, 0, 0.5), (0.5, 1.9, 7.4), "brass", r=(a, 0, 0))
    # the lantern: a caged lamp on a bracket under the nose
    cyl("Hull", (-15.6, 0, -4.4), 0.35, 2.2, "iron", axis="z", n=5)
    cyl("Hull", (-16.4, 0, -5.4), 1.5, 0.5, "brass", axis="x", n=8)
    ball("Light", (-16.8, 0, -5.4), 1.2, "lamp", u=8, v=6)
    # a bent pipe: the snorkel
    cyl("Pipe", (0.4, 1.6, 10.6), 0.45, 3.4, "copper", axis="z", n=6)
    cyl("Pipe", (-0.3, 1.6, 12.3), 0.45, 1.9, "copper", axis="x", n=6)
    cyl("Pipe", (-1.3, 1.6, 12.3), 0.7, 0.5, "brass", axis="x", n=6)


# ------------------------------------------------------------------------------------------------ D: voxel
def style_d():
    def b(p, x0, x1, hw, z0, z1, colour, y=0.0):
        """a block on the grid: from x0 to x1, hw either side of y, z0 to z1 (cubes)"""
        box(p, ((x0 + x1) / 2 * U, y * U, (z0 + z1) / 2 * U), ((x1 - x0) * U, 2 * hw * U, (z1 - z0) * U), colour, stud=True)

    def band(p, x0, x1, hw, z0, z1, colour, y=0.0):
        """a touch of colour, a third of a cube proud of the block it is on"""
        b(p, x0, x1, hw, z0, z1, colour, y)

    T = 1 / 3
    # the hull: three big blocks, each a body part, a step narrower fore and aft; the belly one row of darker cubes
    b("Hull", -10, 9, 5, -4, 5, "hull")  # the tub
    b("Hull", -14, -10 + 1, 4, -3, 4, "hull")  # the shoulder (its root one cube inside the tub)
    b("Hull", 9 - 1, 13, 4, -3, 4, "hull")  # the haunch
    b("Hull", 13 - 1, 16, 2.5, -1.5, 3, "hull")  # the tail block
    b("Hull", -9, 8, 4, -5, -4 + 0.5, "hull-")  # the keel plate
    # the nose: two turned blocks in a chain, each tilted nose-down, a step smaller (a slope is a whole block turned)
    box("Hull", (-15.2, 0, 0.1), (4.6, 6.4, 5.6), "hull", r=(0, -14, 0), stud=False)
    box("Hull", (-17.3, 0, -0.9), (3.2, 4.4, 3.6), "hull+", r=(0, -24, 0))
    # the rim of the tub: a navy lip all round the top, a third proud (the tier's name is the Bathtub)
    for s in (-1, 1):
        band("Hull", -10 - T, 9 + T, 0.5, 4, 5 + T, "trim", y=s * (4.5 + T))
        band("Hull", -8, 7, T / 2, -2, -1, "hull+", y=s * (5 + T / 2))  # a lighter side line
    band("Hull", -10 - T, -9, 5, 4, 5 + T, "trim")
    band("Hull", 8, 9 + T, 5, 4, 5 + T, "trim")
    # the tower: one tall block, a cap, a window set in its face
    b("Tower", -6, 2, 3, 4, 9, "hull")
    b("Tower", -6 - T, 2 + T, 3 + T, 9, 10, "trim")
    b("Tower", -3, 0, 1, 10 - 0.5, 11, "trim+")  # the hatch
    b("Window", -6 - T, -5, 2, 6, 8, "glass")
    b("Tower", -6 - T * 0.6, -5, 2.5, 5.5, 6, "trim")  # the sill
    for s in (-1, 1):
        for x in (-8, -1):
            b("Ports", x - 1, x + 1, T / 2, -0.5, 1.5, "glass", y=s * (5 + T / 2))
            b("Ports", x - 1.5, x + 1.5, T / 4, -1, 2, "trim", y=s * (5 + T / 4))
        # wings: two boxes, the second smaller, starting inside the first, tipped down
        box("Wings", (-7, s * 6.4, -1.0), (4, 3.6, 1.0), "trim", r=(s * -10, 0, 0))
        box("Wings", (-6.6, s * 8.6, -1.45), (3, 2.6, 0.7), "trim+", r=(s * -18, 0, 0))
    # the seat behind the tower: a cushion on the deck, a slot either side for the legs (the rim stops them sliding)
    b("Seat", 3, 7, 2, 5 - 0.3, 5.7, "seat")
    b("Seat", 7 - 0.5, 8, 2, 5 - 0.3, 7.5, "seat")
    for s in (-1, 1):
        b("Bar", 2.2, 3.0, 0.3, 5 - 0.3, 7.2, "trim", y=s * 2)
    b("Bar", 2.1, 3.1, 2.4, 6.5, 7.2, "trim+")
    # the tail: a cross of fins, each two boxes; a block propeller
    b("Fins", 12, 15.5, 0.5, -5, 7, "trim")
    b("Fins", 13, 16, 0.3, 6, 9, "trim+")
    b("Fins", 12.5, 15, 6.5, 0.2, 1.2, "trim")
    for s in (-1, 1):
        b("Fins", 13.5, 15.5, 1.2, 0.4, 1.0, "trim+", y=s * 7)
    part("Prop", origin=(17.0, 0, 0.75))
    b("Prop", 15.5, 17, 0.8, 0, 1.5, "trim+")
    b("Prop", 16.6, 17.4, 0.7, -2.8, 4.3, "white")
    b("Prop", 16.7, 17.3, 3.5, 0.1, 1.4, "white")
    # the lamp: a glowing block in a dark housing under the nose
    b("Hull", -15.5, -13, 1.5, -5, -3 + 0.5, "trim")
    b("Light", -16, -15.5 + 0.3, 1, -4.6, -2.9, "lamp")
    # one flaw, as each rarer creature has: a patch plate on the left flank
    b("Hull", 3, 6, T / 2, 0, 3, "hull-", y=-(5 + T / 2))
    b("Hull", 3.3, 3.8, T / 4, 2.2, 2.7, "trim", y=-(5 + T * 0.75))
    b("Hull", 5.2, 5.7, T / 4, 0.3, 0.8, "trim", y=-(5 + T * 0.75))


{"A": style_a, "B": style_b, "C": style_c, "D": style_d}[STYLE]()

# ------------------------------------------------------------------------------------------------ objects
col = bpy.data.collections.new("Sub")
scene.collection.children.link(col)
tris, objects = 0, []
for name, p in PARTS.items():
    bm = p["bm"]
    if not bm.faces:
        continue
    for e in bm.edges:  # smooth parts keep their hard corners
        if p["smooth"] and len(e.link_faces) == 2:
            e.smooth = e.calc_face_angle(0.0) < math.radians(50) and e.link_faces[0].material_index == e.link_faces[1].material_index
    for f in bm.faces:
        f.smooth = p["smooth"]
    for v in bm.verts:
        v.co -= p["origin"]
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    tris += sum(len(f.verts) - 2 for f in bm.faces)
    bm.free()
    used = sorted({poly.material_index for poly in me.polygons})
    for i in used:
        me.materials.append(MATS[ORDER[i]])
    for poly in me.polygons:
        poly.material_index = used.index(poly.material_index)
    ob = bpy.data.objects.new(name, me)
    ob.location = p["origin"]
    col.objects.link(ob)
    objects.append(ob)
print(f"sub kit: style {STYLE}: {len(objects)} parts, {tris} triangles, {len(ORDER)} colours")
with open(os.path.join(OUT, "stats.txt"), "w") as fh:
    fh.write(f"{STYLE} {len(objects)} {tris} {len(ORDER)}\n")

if EXPORT:  # the game mesh: Roblox's axes come from the glTF exporter's +Y up; the nose is turned to -Z first
    os.makedirs(EXPORT, exist_ok=True)
    root = bpy.data.objects.new("Submarine", None)
    col.objects.link(root)
    for ob in objects:
        ob.parent = root
    root.rotation_euler = (0, 0, math.radians(-90))  # nose from -X to +Y here, which exports as -Z
    bpy.context.view_layer.update()
    bpy.ops.export_scene.gltf(filepath=os.path.join(EXPORT, f"Sub_{STYLE}.glb"), export_format="GLB", export_apply=True,
                              export_yup=True)
    root.rotation_euler = (0, 0, 0)
    bpy.context.view_layer.update()


# ------------------------------------------------------------------------------------------------ cameras and light
def look_from(ob, source, target):
    ob.location = source
    ob.rotation_euler = (Vector(target) - Vector(source)).to_track_quat("-Z", "Y").to_euler()


def camera(name, ortho=None, lens=50):
    cam = bpy.data.cameras.new(name)
    if ortho:
        cam.type, cam.ortho_scale = "ORTHO", ortho
    else:
        cam.lens = lens
    cam.clip_end = 1000
    ob = bpy.data.objects.new(name, cam)
    scene.collection.objects.link(ob)
    return ob


def render(cam, name, w, h):
    scene.camera = cam
    scene.render.resolution_x, scene.render.resolution_y = w, h
    scene.render.resolution_percentage = int(100 * PX)
    scene.render.filepath = os.path.join(OUT, name)
    bpy.ops.render.render(write_still=True)


world = bpy.data.worlds.new("World")
world.use_nodes = True
bg = world.node_tree.nodes.get("Background")
bg.inputs["Color"].default_value = rgba("#FEF8F1")
bg.inputs["Strength"].default_value = 0.6
scene.world = world
sun_data = bpy.data.lights.new("Key", "SUN")
sun_data.energy, sun_data.angle = 2.3, math.radians(14)
sun = bpy.data.objects.new("Key", sun_data)
scene.collection.objects.link(sun)
look_from(sun, (-5.0, -7.0, 9.0), (0, 0, 0))
scene.render.image_settings.file_format = "PNG"
scene.render.film_transparent = True
scene.render.image_settings.color_mode = "RGBA"

hero = camera("Hero", lens=75)
look_from(hero, (-62 * (FRAME or 1), -70 * (FRAME or 1), 30 * (FRAME or 1)), (0.5, 0, 1.5))
render(hero, "hero.png", 1200, 820)
side = camera("Side", ortho=46 * FRAME if FRAME else 44)
look_from(side, (0, -200 if FRAME else -90, 2), (0, 0, 2))
render(side, "side.png", 1000, 480 if FRAME else 520)
front = camera("Front", lens=85)
look_from(front, (-95, 0, 12), (0, 0, 2))
look_from(sun, (-10, -1.5, 8), (0, 0, 0))
render(front, "front.png", 560, 560)
look_from(sun, (-5.0, -7.0, 9.0), (0, 0, 0))
top = camera("Top", ortho=44)
top.location = (0, 0, 90)
top.rotation_euler = (0, 0, 0)
render(top, "top.png", 1000, 520)

# ------------------------------------------------------------------------------------------------ the riding view
# a blocky rider on the seat (root 1.7 over the seat's top, as SubController's SEAT), seen from behind and above in the
# Shallows' water colour; the sheet lays bubbles over it
RIDER = {"skin": "#F2C94C", "shirt": "#2D7FD3", "legs": "#5CA84A"}
rm = {}
for k, h in RIDER.items():
    m = bpy.data.materials.new("Rider_" + k)
    m.use_nodes = True
    m.node_tree.nodes.get("Principled BSDF").inputs["Base Color"].default_value = rgba(h)
    rm[k] = m


def rbox(c, size, k, r=(0, 0, 0)):
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0, matrix=Matrix.Translation(c) @ rot(r) @ Matrix.Diagonal((*size, 1.0)))
    me = bpy.data.meshes.new("Rider")
    bm.to_mesh(me)
    bm.free()
    me.materials.append(rm[k])
    ob = bpy.data.objects.new("Rider", me)
    scene.collection.objects.link(ob)


SX, SZ = 5.0, 5.7  # the seat's top
rbox((SX, 0, SZ + 1.7), (1.0, 2.0, 2.0), "shirt", r=(0, -8, 0))
rbox((SX - 0.3, 0, SZ + 3.4), (1.25, 1.25, 1.25), "skin")
for s in (-1, 1):
    rbox((SX - 1.0, s * 0.55, SZ + 0.5), (2.0, 0.95, 0.95), "legs")  # thighs along the seat
    rbox((SX - 2.0, s * 0.55, SZ - 0.1), (0.95, 0.95, 1.6), "legs", r=(0, 20, 0))
    rbox((SX - 1.2, s * 1.5, SZ + 1.75), (2.3, 0.9, 0.9), "skin", r=(0, 22, 0))  # arms out to the bar

bg.inputs["Color"].default_value = rgba("#E4F7FA")
bg.inputs["Strength"].default_value = 0.7
sun_data.energy = 2.6
look_from(sun, (4, -5, 12), (0, 0, 0))
ride = camera("Ride", lens=32)
look_from(ride, (37, -15, 18), (-3, 0, 3.5))
render(ride, "ride.png", 1100, 760)
