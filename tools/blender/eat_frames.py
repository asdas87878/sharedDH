"""Pictures of the eating moves from tools/eat/eat_frames.luau's JSON: the real models, posed joint by joint as the game
poses them. blender --background --python tools/blender/eat_frames.py -- <frames.json> <out folder> [--stills] [--gif]
--stills: the key frames from the game's camera and from the side; --gif: every third frame from the game's camera.
The rider is a plain R15 block figure held stiff (in the game it is a loose ragdoll). The ink is a sketch."""
import json
import math
import os
import random
import sys

import bpy
from mathutils import Matrix, Vector

args = sys.argv[sys.argv.index("--") + 1 :]
runs = json.load(open(args[0]))
out = args[1]
os.makedirs(out, exist_ok=True)
C = Matrix(((1, 0, 0, 0), (0, 0, -1, 0), (0, 1, 0, 0), (0, 0, 0, 1)))
CI = C.inverted()


def game(c):
    x, y, z, a, b, d, e, f, g, h, i, j = c
    return Matrix(((a, b, d, x), (e, f, g, y), (h, i, j, z), (0, 0, 0, 1)))


def world(c):
    return C @ game(c) @ CI


# the key frames: (seconds, what it shows)
KEYS = {
    ("Chomp", True): [0.03, 0.25, 0.45, 0.65, 0.9, 1.1, 1.27, 1.35, 1.42, 1.8],
    ("Chomp", False): [0.03, 0.25, 0.45, 0.65, 0.9, 1.1, 1.27, 1.47, 1.6, 1.8],
    ("Wrap", True): [0.03, 0.3, 0.5, 0.7, 0.9, 1.1, 1.3, 1.6, 2.0, 2.35],
    ("Wrap", False): [0.03, 0.3, 0.5, 0.7, 0.9, 1.1, 1.3, 1.6, 2.0, 2.35],
}

bpy.ops.wm.read_factory_settings(use_empty=True)
sc = bpy.context.scene
engines = [e.identifier for e in bpy.types.RenderSettings.bl_rna.properties["engine"].enum_items]
sc.render.engine = "BLENDER_EEVEE" if "BLENDER_EEVEE" in engines else "BLENDER_EEVEE_NEXT"
sc.eevee.taa_render_samples = 8
sc.view_settings.view_transform = "Standard"
w = bpy.data.worlds.new("w")
sc.world = w
w.use_nodes = True
w.node_tree.nodes["Background"].inputs[0].default_value = (0.1, 0.33, 0.5, 1)
w.node_tree.nodes["Background"].inputs[1].default_value = 1
sun = bpy.data.lights.new("s", "SUN")
sun.energy = 2.6
so = bpy.data.objects.new("s", sun)
bpy.context.collection.objects.link(so)
so.rotation_euler = (0.5, 0.35, 0)
cam = bpy.data.cameras.new("c")
co = bpy.data.objects.new("c", cam)
bpy.context.collection.objects.link(co)
sc.camera = co
cam.clip_end = 4000
cam.sensor_fit = "VERTICAL"


def flat(name, rgb, alpha=1.0, glow=False):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = (*rgb, 1)
    b.inputs["Roughness"].default_value = 0.8
    b.inputs["Alpha"].default_value = alpha
    if glow:
        b.inputs["Emission Color"].default_value = (*rgb, 1)
        b.inputs["Emission Strength"].default_value = 0.6
    if alpha < 1:
        m.surface_render_method = "BLENDED"
    return m


SKIN = flat("skin", (0.95, 0.7, 0.2))
SHIRT = flat("shirt", (0.9, 0.12, 0.1))
LEGS = flat("legs", (0.08, 0.1, 0.3))
MOTE = flat("mote", (0.6, 0.85, 0.95), 1, True)
INK = flat("ink", (0.01, 0.01, 0.02), 0.55)
CUBE = bpy.data.meshes.new("cube")
CUBE.from_pydata(
    [(x, y, z) for x in (-0.5, 0.5) for y in (-0.5, 0.5) for z in (-0.5, 0.5)],
    [],
    [(0, 1, 3, 2), (4, 6, 7, 5), (0, 4, 5, 1), (2, 3, 7, 6), (0, 2, 6, 4), (1, 5, 7, 3)],
)


def block(name, mat):
    o = bpy.data.objects.new(name, CUBE.copy())
    o.data.materials.append(mat)
    bpy.context.collection.objects.link(o)
    return o


def ball(name, mat):
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=2, radius=1)
    o = bpy.context.object
    o.data.materials.append(mat)
    return o


rider = {}
for name, _, _ in runs[0]["frames"][0]["rider"]:
    low = name.lower()
    rider[name] = block("r_" + name, LEGS if "leg" in low or name == "LowerTorso" else SHIRT if "torso" in low else SKIN)
random.seed(4)
motes = []
for i in range(260):
    o = block("mote", MOTE)
    s = random.uniform(0.12, 0.3)
    o.matrix_world = Matrix.Translation((random.uniform(-130, 130), random.uniform(-60, 240), random.uniform(-500, -340))) @ Matrix.Scale(s, 4)
    motes.append(o)
inks = [ball("ink", INK) for _ in range(9)]
spots = [Vector((random.uniform(-1, 1), random.uniform(-1, 1), random.uniform(-1, 1))) for _ in inks]
parts = {}


def load(name):
    for o in parts.values():
        for p in o:
            bpy.data.objects.remove(p)
    parts.clear()
    had = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=f"art/creatures/{name}/game/{name}.glb")
    mat = bpy.data.materials.new("v")
    mat.use_nodes = True
    nt = mat.node_tree
    b = nt.nodes["Principled BSDF"]
    b.inputs["Roughness"].default_value = 0.85
    a = nt.nodes.new("ShaderNodeVertexColor")
    nt.links.new(a.outputs[0], b.inputs["Base Color"])
    nt.links.new(a.outputs[0], b.inputs["Emission Color"])
    b.inputs["Emission Strength"].default_value = 0.12
    for o in set(bpy.data.objects) - had:
        if o.parent:
            o.parent = None
        if o.type == "MESH":
            if o.data.color_attributes:
                a.layer_name = o.data.color_attributes[0].name
            o.data.materials.clear()
            o.data.materials.append(mat)
            part = o.name.split(".")[0].replace("_Glow", "")
            parts.setdefault(part, []).append(o)


def pose(run, fr):
    k = run["k"]
    for name, c in fr["pose"].items():
        for o in parts.get(name, []):
            o.matrix_world = world(c) @ Matrix.Scale(k, 4)
    for name, c, size in fr["rider"]:
        o = rider[name]
        x, y, z = size
        o.hide_render = fr["hidden"]
        o.matrix_world = world(c) @ Matrix.Diagonal((x, z, y, 1))
    # the ink, where it jets from
    t = fr["u"] - run["jet"]
    on = run["kind"] == "Wrap" and run["new"] and t > 0
    for i, o in enumerate(inks):
        o.hide_render = not on
        if on:
            near = min(run["frames"], key=lambda f: abs(f["u"] - run["jet"]))
            L = run["length"]
            g = 1 - math.exp(-3.2 * t)
            p = world(near["fish"]) @ Vector((0, -L * 0.06, 0))
            o.matrix_world = Matrix.Translation(p + spots[i] * L * 0.2 * g) @ Matrix.Scale(L * (0.04 + 0.1 * g), 4)


def shoot(fr, path, side=None, size=(640, 360)):
    if side:
        centre, wide = side
        cam.type = "ORTHO"
        cam.sensor_fit = "HORIZONTAL"
        cam.ortho_scale = wide
        d = Vector((1, 0, 0.12)).normalized()
        co.matrix_world = Matrix.Translation(Vector(centre) + d * 900) @ (-d).to_track_quat("-Z", "Y").to_matrix().to_4x4()
    else:
        cam.type = "PERSP"
        cam.sensor_fit = "VERTICAL"
        cam.angle = math.radians(70)
        co.matrix_world = C @ game(fr["camera"])
    sc.render.resolution_x, sc.render.resolution_y = size
    sc.render.filepath = path
    bpy.ops.render.render(write_still=True)


index = []
for run in runs:
    load(run["creature"])
    tag = f"{run['kind']}_{'new' if run['new'] else 'old'}"
    F = run["frames"]
    if "--stills" in args:
        shown = [min(F, key=lambda f: abs(f["t"] - t)) for t in KEYS[(run["kind"], run["new"])]]
        pts = [world(f["fish"]).translation for f in shown] + [world(f["rider"][0][1]).translation for f in shown]
        lo = [min(p[i] for p in pts) for i in range(3)]
        hi = [max(p[i] for p in pts) for i in range(3)]
        centre = [(lo[i] + hi[i]) / 2 for i in range(3)]
        for i, fr in enumerate(shown):
            pose(run, fr)
            shoot(fr, f"{out}/{tag}_{i:02d}_game.png")
            mid = (world(fr["fish"]).translation * 0.6 + world(fr["rider"][0][1]).translation * 0.4)
            shoot(fr, f"{out}/{tag}_{i:02d}_side.png", ([centre[0], mid[1], mid[2]], run["length"] * (2.0 if run["kind"] == "Chomp" else 4.4)))
    if "--gif" in args:
        for n, fr in enumerate(F[::3]):
            pose(run, fr)
            shoot(fr, f"{out}/{tag}_g{n:03d}.png", None, (480, 270))
