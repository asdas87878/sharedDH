"""Blender's half of tools/boards/picture.py: the hub as saved, the boards as Shared/Boards draws them, the panels as
pictures on their glass. usage: blender -b --factory-startup -P tools/boards/view.py -- <work folder> [only]"""
import json
import math
import sys
from pathlib import Path

import bpy
from mathutils import Matrix, Vector

WORK = Path(sys.argv[sys.argv.index("--") + 1])
ONLY = sys.argv[sys.argv.index("--") + 2:]
HUB = json.loads((WORK / "hub.json").read_text())
DATA = json.loads((WORK / "parts.json").read_text())
O = Vector((2922, 0.5, -39))
C = Matrix(((1, 0, 0, 0), (0, 0, -1, 0), (0, 1, 0, 0), (0, 0, 0, 1)))  # Roblox (x, y, z) to Blender (x, -z, y)

bpy.ops.wm.read_factory_settings(use_empty=True)
sc = bpy.context.scene
sc.render.engine = "BLENDER_EEVEE"
sc.eevee.taa_render_samples = 24
sc.render.film_transparent = True
sc.render.image_settings.color_mode = "RGBA"
sc.view_settings.view_transform = "Standard"
world = bpy.data.worlds.new("sky")
sc.world = world
world.use_nodes = True
world.node_tree.nodes["Background"].inputs[0].default_value = (0.62, 0.66, 0.72, 1)
world.node_tree.nodes["Background"].inputs[1].default_value = 0.62
sun = bpy.data.objects.new("sun", bpy.data.lights.new("sun", "SUN"))
sun.data.energy = 2.2
sun.data.use_shadow = False  # (the place's GlobalShadows are off)
sun.data.angle = 0.02
sun.rotation_euler = (math.radians(-34), math.radians(-20), 0)
sc.collection.objects.link(sun)

bpy.ops.mesh.primitive_cube_add(size=1)
cube = bpy.context.object.data
bpy.ops.mesh.primitive_uv_sphere_add(radius=0.5, segments=28, ring_count=16)
ball = bpy.context.object.data
bpy.ops.mesh.primitive_cylinder_add(radius=0.5, depth=1, vertices=32, rotation=(0, math.pi / 2, 0))
bpy.ops.object.transform_apply(rotation=True)
cyl = bpy.context.object.data
bpy.ops.mesh.primitive_plane_add(size=1)
plane = bpy.context.object.data
for mesh in (ball, cyl):
    for p in mesh.polygons:
        p.use_smooth = len(p.vertices) <= 4
for o in list(bpy.data.objects):
    if o.type == "MESH":
        bpy.data.objects.remove(o)
SHAPES = {"Ball": ball, "Cylinder": cyl}


def lin(v):
    return v / 12.92 if v <= 0.04045 else ((v + 0.055) / 1.055) ** 2.4


mats = {}


def material(color, glow=False, clear=0.0):
    key = (tuple(round(c, 3) for c in color), glow, round(clear, 2))
    if key not in mats:
        m = bpy.data.materials.new("m")
        m.use_nodes = True
        b = m.node_tree.nodes["Principled BSDF"]
        rgb = (*[lin(c) for c in color], 1)
        b.inputs["Base Color"].default_value = rgb
        b.inputs["Roughness"].default_value = 0.65
        if glow:
            b.inputs["Emission Color"].default_value = rgb
            b.inputs["Emission Strength"].default_value = 1.1
        if clear:
            b.inputs["Alpha"].default_value = 1 - clear
            m.surface_render_method = "BLENDED"
        mats[key] = m
    return mats[key]


def matrix(m):
    x, y, z = m[:3]
    r = m[3:]
    return Matrix(((r[0], r[1], r[2], x - O.x), (r[3], r[4], r[5], y - O.y), (r[6], r[7], r[8], z - O.z),
                   (0, 0, 0, 1)))


meshes = {}


def add(shape, size, m, mat, into):
    key = (shape, mat.name)
    if key not in meshes:
        mesh = SHAPES.get(shape, cube).copy()
        mesh.materials.clear()
        mesh.materials.append(mat)
        meshes[key] = mesh
    o = bpy.data.objects.new("p", meshes[key])
    o.matrix_world = C @ matrix(m) @ Matrix.Diagonal((*size, 1))
    into.objects.link(o)
    return o


hub = bpy.data.collections.new("hub")
sc.collection.children.link(hub)
shown, kept = [], []
for p in HUB:
    if p["sh"] == "MeshPart" or p["t"] > 0.85 or p["n"].startswith("Dock.Stations.Earners"):
        continue
    shown.append(add(p["sh"], p["s"], p["m"], material(p["col"], p["mat"] == "Neon", p["t"]), hub))
    kept.append(p)

rows = []
for i, row in enumerate(DATA["Rows"], 1):
    col = bpy.data.collections.new(f"row{i}")
    sc.collection.children.link(col)
    rows.append(col)
    for p in row["parts"]:
        add(p["shape"], p["size"], p["m"], material(p["color"], p["glow"], p["clear"]), col)
        if p["glow"]:
            lamp = bpy.data.objects.new("l", bpy.data.lights.new("l", "POINT"))
            lamp.data.energy = 25
            lamp.data.color = p["color"]
            lamp.data.shadow_soft_size = 0.8
            lamp.data.use_shadow = False
            lamp.location = (C @ matrix(p["m"])).translation
            col.objects.link(lamp)
    for g in row["glasses"]:
        m = bpy.data.materials.new("panel")
        m.use_nodes = True
        t = m.node_tree
        image = t.nodes.new("ShaderNodeTexImage")
        image.image = bpy.data.images.load(str(WORK / f"panel-{g['id']}-all.png"))
        e = t.nodes.new("ShaderNodeEmission")
        t.links.new(image.outputs["Color"], e.inputs["Color"])
        t.links.new(e.outputs[0], t.nodes["Material Output"].inputs["Surface"])
        mesh = plane.copy()
        mesh.materials.clear()
        mesh.materials.append(m)
        o = bpy.data.objects.new("panel", mesh)
        size = DATA["Panel"]
        # (a plane lies in its own X and Y: the same X and Y as the glass, its normal towards the reader)
        o.matrix_world = C @ matrix(g["m"]) @ Matrix.Translation((0, 0, 0.02)) @ Matrix.Diagonal(
            (size["Width"], size["Height"], 1, 1))
        col.objects.link(o)

cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
cam.data.clip_end = 3000
sc.collection.objects.link(cam)
sc.camera = cam


def shot(name, eye, at, fov, wide, high):
    """fov: the picture's height, degrees, as Roblox has it"""
    sc.render.resolution_x, sc.render.resolution_y = wide, high
    cam.data.sensor_fit = "VERTICAL"
    cam.data.angle = math.radians(fov)
    e = Vector((eye[0] - O.x, -(eye[2] - O.z), eye[1] - O.y))
    t = Vector((at[0] - O.x, -(at[2] - O.z), at[1] - O.y))
    cam.matrix_world = Matrix.Translation(e) @ (t - e).to_track_quat("-Z", "Y").to_matrix().to_4x4()
    sc.render.filepath = str(WORK / f"shot-{name}.png")
    bpy.ops.render.render(write_still=True)


def only(i):
    for k, col in enumerate(rows, 1):
        col.hide_render = k != i


pen6 = [o for o, p in zip(shown, kept) if p["n"].startswith("Dock.Plots.Plot6")]


def pens(on):
    for o in pen6:
        o.hide_render = not on


near, far = math.radians(20), math.radians(40)  # along the boards' own facing; towards the hub's middle
X, Z = O.x, O.z
only(1)
pens(False)
if not ONLY or "close" in ONLY:
    shot("close", (X + math.sin(near) * 50, 12, Z - math.cos(near) * 50), (X + 0.4, 15.6, Z), 43, 2400, 1500)
if not ONLY or "sign" in ONLY:
    shot("sign", (X + math.sin(near) * 26, 22, Z - math.cos(near) * 26), (X + 0.2, 26.3, Z), 26, 2400, 760)
pens(True)
if not ONLY or "phone" in ONLY:
    shot("phone", (X + math.sin(far) * 60, 9, Z - math.cos(far) * 60), (X, 14, Z), 70, 1688, 780)
if not ONLY or "spawn" in ONLY:
    shot("spawn", (3000, 9, -100), (2955, 12, -38), 70, 1688, 780)
