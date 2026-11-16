"""Pictures of one of the hub's models (tools/map/hub_kit.py: art/map/greybox/hub.json), to judge its outline and its
blocks before Studio: in colour, in grey, or as a flat black shape (the building brief's rule 1). The game's own fish
(Kit.fish) are read from art/creatures/<Name>/game/<Name>.glb. Not Roblox: no studs, no words, a stand-in light.

usage: blender --background --python tools/blender/hub_view.py -- <model> <out folder> <shot> [<shot> ...] [--figure x,z]
    <model>   a path under Dock: Stations/Sell, Plots/Plot3
    <shot>    name:style:ex,ey,ez:ax,ay,az    style is colour, grey or black; the eye and what it looks at are in
              the model's own frame (x to its right seen from behind, y up from its foot, z out of its front)
    --figure  a player-sized figure (5.2 studs) standing at x,z in that frame"""
import json
import math
import os
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
argv = sys.argv[sys.argv.index("--") + 1:]
figures = []
while "--figure" in argv:
    i = argv.index("--figure")
    figures.append([float(v) for v in argv[i + 1].split(",")])
    del argv[i:i + 2]
MODEL, OUT, SHOTS = argv[0], argv[1], argv[2:]
OUT = OUT if os.path.isabs(OUT) else os.path.join(ROOT, OUT)  # Blender resolves a relative path against the drive
hub = json.load(open(os.path.join(ROOT, "art", "map", "greybox", os.environ.get("HUB_JSON") or "hub.json")))
parts = [p for p in hub["parts"] if p["m"] == MODEL or p["m"].startswith(MODEL + "/")]
foot, fx, fy = (Vector(v) for v in hub["feet"][MODEL])
fz = fx.cross(fy)
os.makedirs(OUT, exist_ok=True)


def r2b(v):
    return Vector((v[0], -v[2], v[1]))


def local(v):
    """a point in the model's own frame, in Roblox's world"""
    return foot + fx * v[0] + fy * v[1] + fz * v[2]


def lin(c):
    out = []
    for v in c:
        v /= 255.0
        out.append(v / 12.92 if v <= 0.04045 else ((v + 0.055) / 1.055) ** 2.4)
    return (*out, 1.0)


bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
materials = {}


def material(colour, see=0.0):
    key = (tuple(colour), see)
    if key in materials:
        return materials[key]
    mat = bpy.data.materials.new("c%d_%d_%d" % tuple(colour))
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value = lin(colour)
    bsdf.inputs["Roughness"].default_value = 0.9
    if see > 0:
        bsdf.inputs["Alpha"].default_value = 1 - see
        mat.surface_render_method = "BLENDED"
    materials[key] = mat
    return mat


def mesh_of(kind):
    bm = bmesh.new()
    if kind == "Ball":
        bmesh.ops.create_uvsphere(bm, u_segments=20, v_segments=12, radius=0.5)
    elif kind == "Cylinder":
        bmesh.ops.create_cone(bm, cap_ends=True, segments=28, radius1=0.5, radius2=0.5, depth=1.0)
    else:
        bmesh.ops.create_cube(bm, size=1.0)
    me = bpy.data.meshes.new(kind or "Box")
    bm.to_mesh(me)
    bm.free()
    return me


meshes = {kind: mesh_of(kind) for kind in (None, "Ball", "Cylinder")}
made, fish_objects = [], []


def frame(p):
    x, y = Vector(p["x"]), Vector(p["y"])
    return x, y, x.cross(y)


def add(name, kind, centre, ax, size, colour, see=0.0):
    obj = bpy.data.objects.new(name, meshes[kind])
    x, y, z = (r2b(a) for a in ax)
    if kind == "Cylinder":  # the mesh's round axis is its z; a Roblox cylinder's is its x
        cols = (y * size[1], z * size[2], x * size[0])
    else:
        cols = (x * size[0], y * size[1], z * size[2])
    m = Matrix.Identity(4)
    for c in range(3):
        for r in range(3):
            m[r][c] = cols[c][r]
    m.translation = r2b(centre)
    obj.matrix_world = m
    obj.color = lin(colour)
    obj["colour"], obj["see"] = list(colour), see
    scene.collection.objects.link(obj)
    made.append(obj)
    return obj


for p in parts:
    if "fish" in p:
        path = os.path.join(ROOT, "art", "creatures", p["fish"], "game", p["fish"] + ".glb")
        if not os.path.exists(path):
            print("no model for", p["fish"])
            continue
        before = set(bpy.data.objects)
        bpy.ops.import_scene.gltf(filepath=path)
        new = [o for o in bpy.data.objects if o not in before]
        bpy.context.view_layer.update()
        pts = [o.matrix_world @ Vector(c) for o in new if o.type == "MESH" for c in o.bound_box]
        lo = Vector([min(q[i] for q in pts) for i in range(3)])
        hi = Vector([max(q[i] for q in pts) for i in range(3)])
        centre = (lo + hi) / 2
        head = next((o for o in new if o.type == "MESH" and o.name.split(".")[0] == "Head"), None)
        nose = 1.0
        if head:
            hc = sum((head.matrix_world @ Vector(c) for c in head.bound_box), Vector()) / 8
            nose = -1.0 if -(hc.y - centre.y) < 0 else 1.0  # Roblox z is Blender -y
        x, y, z = frame(p)
        target = Matrix.Identity(4)
        for c, a in enumerate((r2b(x), r2b(y), r2b(z))):
            for r in range(3):
                target[r][c] = a[r]
        target.translation = r2b(p["p"])
        b2r = Matrix(((nose, 0, 0, 0), (0, 0, 1, 0), (0, -nose, 0, 0), (0, 0, 0, 1)))  # Blender -> the fish's own Roblox frame
        whole = target @ Matrix.Scale(p["k"], 4) @ b2r @ Matrix.Translation(-centre)
        for o in new:
            if o.parent is None:
                o.matrix_world = whole @ o.matrix_world
        fish_objects += [o for o in new if o.type == "MESH"]
        print("fish", p["fish"], "glb box", tuple(round(v, 1) for v in (hi - lo)), "nose", nose, "head", bool(head))
        continue
    if p.get("t") == 1:
        continue
    add(p["n"], p.get("sh"), p["p"], frame(p), p["s"], p["c"], p.get("t", 0.0))

for fx_, fz_ in figures:  # a player: 5.2 studs
    for name, (x, y, z), size, colour in (("Legs", (0, 1, 0), (2, 2, 1), (75, 151, 75)), ("Torso", (0, 3, 0), (2, 2, 1), (13, 105, 172)),
                                          ("Arms", (0, 3, 0), (4, 2, 0.98), (245, 205, 48)), ("Head", (0, 4.6, 0), (1.2, 1.2, 1.2), (245, 205, 48))):
        add("Figure" + name, None, local((fx_ + x, y, fz_ + z)), (fx, fy, fz), size, colour)
ground = add("Ground", None, local((0, -0.5, 0)), (Vector((1, 0, 0)), Vector((0, 1, 0)), Vector((0, 0, 1))), (900, 1, 900), (105, 185, 85))

for engine in ("BLENDER_EEVEE", "BLENDER_EEVEE_NEXT"):
    try:
        scene.render.engine = engine
        break
    except TypeError:
        pass
scene.render.resolution_x, scene.render.resolution_y = [int(v) for v in (os.environ.get("HUB_SIZE") or "1280x800").split("x")]
scene.render.image_settings.file_format = "PNG"
scene.eevee.taa_render_samples = 24
scene.view_settings.view_transform = "Standard"
world = bpy.data.worlds.new("World")
world.use_nodes = True
scene.world = world
back = world.node_tree.nodes["Background"]
sun = bpy.data.objects.new("Sun", bpy.data.lights.new("Sun", "SUN"))
sun.data.energy = 3.2
sun.data.angle = math.radians(2)
scene.collection.objects.link(sun)
sun_dir = r2b(local((-0.45, 1.0, 0.75)) - foot)  # from the front, over the left shoulder
sun.rotation_euler = sun_dir.to_track_quat("Z", "Y").to_euler()
cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
cam.data.sensor_fit = "VERTICAL"
cam.data.angle_y = math.radians(70)
cam.data.clip_end = 3000
scene.collection.objects.link(cam)
scene.camera = cam
black = bpy.data.materials.new("Black")
black.use_nodes = True
black.node_tree.nodes.clear()
em = black.node_tree.nodes.new("ShaderNodeEmission")
em.inputs["Color"].default_value = (0, 0, 0, 1)
black.node_tree.links.new(em.outputs[0], black.node_tree.nodes.new("ShaderNodeOutputMaterial").inputs["Surface"])
fish_materials = {o: [s.material for s in o.material_slots] for o in fish_objects}


def dress(style):
    for o in made:
        o.hide_render = False
        if style == "black":
            mat = black
            o.hide_render = o is ground or o.name.startswith("Figure") or o["see"] > 0.5
        elif style == "grey":
            mat = material((196, 196, 200) if o is not ground else (150, 150, 150), o["see"])
        else:
            mat = material(o["colour"], o["see"])
        o.data = o.data.copy() if o.data.users > 1 else o.data
        o.data.materials.clear()
        o.data.materials.append(mat)
    for o in fish_objects:
        for i, slot in enumerate(o.material_slots):
            slot.material = black if style == "black" else (material((196, 196, 200)) if style == "grey" else fish_materials[o][i])
    back.inputs["Color"].default_value = (1, 1, 1, 1) if style == "black" else (0.45, 0.62, 0.9, 1)
    back.inputs["Strength"].default_value = 1.0 if style == "black" else 0.9


for shot in SHOTS:
    name, style, eye, at = shot.split(":")
    eye, at = (local([float(v) for v in t.split(",")]) for t in (eye, at))
    dress(style)
    cam.location = r2b(eye)
    cam.rotation_euler = (r2b(at) - r2b(eye)).to_track_quat("-Z", "Y").to_euler()
    scene.render.filepath = os.path.join(OUT, name + ".png")
    bpy.ops.render.render(write_still=True)
    print("rendered", scene.render.filepath)
