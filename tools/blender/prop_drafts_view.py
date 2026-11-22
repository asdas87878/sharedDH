"""Renders the breakable-prop drafts (tools/map/prop_drafts.py): each option's tree and rock, whole and just after a
hit, side by side, and the colourway row. Studs are drawn by the shader from per-face UVs in studs (one round stud a
stud, as our floor), on the bricks flagged for them; the rest is plain. Not Roblox: the light is a stand-in.

usage: blender --background --python tools/blender/prop_drafts_view.py"""
import json
import math
import os

import bmesh
import bpy
from mathutils import Vector

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
BOX = os.path.join(ROOT, "art", "map", "prop_drafts")
OUT = os.path.join(BOX, "renders")
data = json.load(open(os.path.join(BOX, os.environ.get("DRAFTS", "drafts") + ".json")))


def lin(c):
    out = []
    for v in c:
        v /= 255.0
        out.append(v / 12.92 if v <= 0.04045 else ((v + 0.055) / 1.055) ** 2.4)
    return (*out, 1.0)


def r2b(v):
    return Vector((v[0], -v[2], v[1]))


MATS = {}


def material(colour, studs):
    key = (tuple(colour), studs)
    if key in MATS:
        return MATS[key]
    mat = bpy.data.materials.new(f"m_{colour}_{studs}")
    mat.use_nodes = True
    nt = mat.node_tree
    n, link = nt.nodes, nt.links.new
    bsdf = n["Principled BSDF"]
    bsdf.inputs["Roughness"].default_value = 0.75
    base = lin(colour)
    if not studs:
        bsdf.inputs["Base Color"].default_value = base
    else:
        uv = n.new("ShaderNodeUVMap")
        sep = n.new("ShaderNodeSeparateXYZ")
        link(uv.outputs[0], sep.inputs[0])
        d2 = []
        for i in (0, 1):  # fract(u) - 0.5, squared
            fr = n.new("ShaderNodeMath")
            fr.operation = "FRACT"
            link(sep.outputs[i], fr.inputs[0])
            sub = n.new("ShaderNodeMath")
            sub.operation = "SUBTRACT"
            sub.inputs[1].default_value = 0.5
            link(fr.outputs[0], sub.inputs[0])
            sq = n.new("ShaderNodeMath")
            sq.operation = "MULTIPLY"
            link(sub.outputs[0], sq.inputs[0])
            link(sub.outputs[0], sq.inputs[1])
            d2.append(sq)
        add = n.new("ShaderNodeMath")
        link(d2[0].outputs[0], add.inputs[0])
        link(d2[1].outputs[0], add.inputs[1])
        dist = n.new("ShaderNodeMath")
        dist.operation = "SQRT"
        link(add.outputs[0], dist.inputs[0])
        ramp = n.new("ShaderNodeValToRGB")  # the stud: a light top, a dark rim, the plain face between
        link(dist.outputs[0], ramp.inputs[0])
        cr = ramp.color_ramp
        cr.interpolation = "CONSTANT"
        light = tuple(min(1.0, v * 1.22) for v in base[:3]) + (1.0,)
        dark = tuple(v * 0.72 for v in base[:3]) + (1.0,)
        cr.elements[0].position, cr.elements[0].color = 0.0, light
        cr.elements[1].position, cr.elements[1].color = 0.27, dark
        e = cr.elements.new(0.33)
        e.color = base
        link(ramp.outputs[0], bsdf.inputs["Base Color"])
    MATS[key] = mat
    return mat


def add_bricks(bricks, offset, objs):
    by = {}
    for b in bricks:
        by.setdefault((tuple(b["c"]), b["studs"]), []).append(b)
    for (colour, studs), group in by.items():
        bm = bmesh.new()
        uvl = bm.loops.layers.uv.new("UVMap")
        for b in group:
            c = Vector(b["p"]) + Vector(offset)
            ax = [Vector(a) for a in b["ax"]]
            hs = [v / 2 for v in b["s"]]
            corner = {}
            for sx in (-1, 1):
                for sy in (-1, 1):
                    for sz in (-1, 1):
                        corner[(sx, sy, sz)] = bm.verts.new(r2b(c + ax[0] * hs[0] * sx + ax[1] * hs[1] * sy + ax[2] * hs[2] * sz))
            for axis in range(3):
                for sign in (-1, 1):
                    quad, uvs = [], []
                    a1, a2 = (axis + 1) % 3, (axis + 2) % 3
                    for u, v in ((-1, -1), (1, -1), (1, 1), (-1, 1)):
                        key = [0, 0, 0]
                        key[axis], key[a1], key[a2] = sign, u, v
                        quad.append(corner[tuple(key)])
                        uvs.append((u * hs[a1] + 0.5, v * hs[a2] + 0.5))  # in studs, a stud centred on the face
                    f = bm.faces.new(quad)
                    for loop, t in zip(f.loops, uvs):
                        loop[uvl].uv = t
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        mesh = bpy.data.meshes.new("b")
        bm.to_mesh(mesh)
        bm.free()
        mesh.materials.append(material(list(colour), studs))
        obj = bpy.data.objects.new("b", mesh)
        bpy.context.scene.collection.objects.link(obj)
        objs.append(obj)


def scale_figure(offset, objs):
    """a rider on a 13-stud fish, 10 off the floor, for scale"""
    add_bricks([{"p": [0, 11, 0], "s": [3.2, 3.6, 13], "c": [245, 130, 42], "ax": [[1, 0, 0], [0, 1, 0], [0, 0, 1]], "studs": False},
                {"p": [0, 15.3, 1], "s": [2, 5, 1], "c": [90, 170, 230], "ax": [[1, 0, 0], [0, 1, 0], [0, 0, 1]], "studs": False}], offset, objs)


bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
for engine in ("BLENDER_EEVEE", "BLENDER_EEVEE_NEXT"):
    try:
        scene.render.engine = engine
        break
    except TypeError:
        continue
scene.render.resolution_x, scene.render.resolution_y = 1600, 900
scene.render.image_settings.file_format = "PNG"
scene.view_settings.view_transform = "Standard"
scene.eevee.taa_render_samples = 32
world = bpy.data.worlds.new("w")
scene.world = world
world.use_nodes = True
world.node_tree.nodes["Background"].inputs["Color"].default_value = lin((176, 220, 236))
world.node_tree.nodes["Background"].inputs["Strength"].default_value = 1.0
sun = bpy.data.objects.new("sun", bpy.data.lights.new("sun", "SUN"))
sun.data.energy = 3.2
sun.data.angle = math.radians(8)
sun.rotation_euler = (math.radians(50), math.radians(10), math.radians(35))
scene.collection.objects.link(sun)
floor = {"p": [0, -1, 0], "s": [2000, 2, 2000], "c": data["floor"], "ax": [[1, 0, 0], [0, 1, 0], [0, 0, 1]], "studs": True}


def camera(eye, target, fov=34):
    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
    cam.data.angle = math.radians(fov)
    cam.data.clip_start, cam.data.clip_end = 0.5, 20000
    e, t = r2b(eye), r2b(target)
    cam.location = e
    cam.rotation_euler = (t - e).to_track_quat("-Z", "Y").to_euler()
    scene.collection.objects.link(cam)
    return cam


os.makedirs(OUT, exist_ok=True)


def shot(name, layout, eye, target, fov=34, figure=(-42, 0, 18), floor_c=None):
    objs = []
    add_bricks([dict(floor, c=floor_c) if floor_c else floor], (0, 0, 0), objs)
    for bricks, off in layout:
        add_bricks(bricks, off, objs)
    scale_figure(figure, objs)
    scene.camera = camera(eye, target, fov)
    scene.render.filepath = os.path.join(OUT, name + ".png")
    bpy.ops.render.render(write_still=True)
    for o in objs + [scene.camera]:
        bpy.data.objects.remove(o, do_unlink=True)
    print("rendered", name)


if "shots" in data:
    for sh in data["shots"]:
        scene.render.resolution_x, scene.render.resolution_y = sh["res"]
        shot(sh["name"], [(b, tuple(o)) for b, o in sh["layout"]], tuple(sh["eye"]), tuple(sh["target"]), sh["fov"], tuple(sh["figure"]), sh.get("floor"))
else:
    for c in data["cells"]:
        tall = 70 if c["row"] == 0 else 66
        shot(f"{c['key']}_{c['row']}", [(c["intact"], (-30, 0, 0)), (c["hit"], (42, 0, 0))], (6, tall * 0.75, 330), (6, tall * 0.42, 0), 28)
    ways = [(w["bricks"], (-120 + i * 80, 0, 0)) for i, w in enumerate(data["ways"])]
    scene.render.resolution_x, scene.render.resolution_y = 1800, 560
    shot("ways", ways, (0, 60, 520), (0, 30, 0), 30)
