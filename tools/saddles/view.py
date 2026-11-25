"""Draws the saddle pictures: fish meshes with their own vertex colours, and Roblox parts (box, wedge, cylinder, ball).
usage: blender --background --python tools/saddles/view.py -- <job.json>
    the job: {"scenes": {name: {"fish": [{"npz", "m"}], "parts": [{"shape", "size", "m", "colour", "neon"}], "ground": null}},
              "shots": [{"scene", "eye", "at", "fov" or "ortho", "w", "h", "out"}]}
    an npz: verts (n, 3), tris, colours (linear, per vertex), glow (per triangle), all in Roblox's axes"""
import json
import math
import sys

import bmesh
import bpy
import numpy as np
from mathutils import Matrix, Vector

job = json.load(open(sys.argv[sys.argv.index("--") + 1]))
FLIP = Matrix(((1, 0, 0, 0), (0, 0, -1, 0), (0, 1, 0, 0), (0, 0, 0, 1)))  # Roblox -> Blender


def lin(c):
    return [v / 12.92 if v <= 0.04045 else ((v + 0.055) / 1.055) ** 2.4 for v in (x / 255 for x in c)] + [1.0]


bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
mats = {}


def material(colour, neon):
    key = (tuple(colour), neon)
    if key not in mats:
        mat = bpy.data.materials.new("m")
        mat.use_nodes = True
        b = mat.node_tree.nodes["Principled BSDF"]
        b.inputs["Base Color"].default_value = lin(colour)
        b.inputs["Roughness"].default_value = 0.85
        b.inputs["Specular IOR Level"].default_value = 0.2
        if neon:
            b.inputs["Emission Color"].default_value = lin(colour)
            b.inputs["Emission Strength"].default_value = 1.1
        mats[key] = mat
    return mats[key]


def fish_material(glow):
    key = ("fish", glow)
    if key not in mats:
        mat = bpy.data.materials.new("fish")
        mat.use_nodes = True
        nt = mat.node_tree
        b = nt.nodes["Principled BSDF"]
        a = nt.nodes.new("ShaderNodeVertexColor")
        a.layer_name = "Col"
        nt.links.new(a.outputs["Color"], b.inputs["Base Color"])
        b.inputs["Roughness"].default_value = 0.85
        b.inputs["Specular IOR Level"].default_value = 0.2
        if glow:
            nt.links.new(a.outputs["Color"], b.inputs["Emission Color"])
            b.inputs["Emission Strength"].default_value = 0.9
        mats[key] = mat
    return mats[key]


def solid(shape):
    bm = bmesh.new()
    if shape == "ball":
        bmesh.ops.create_icosphere(bm, subdivisions=2, radius=0.5)
    elif shape == "cylinder":  # Roblox's lies along X
        bmesh.ops.create_cone(bm, cap_ends=True, segments=14, radius1=0.5, radius2=0.5, depth=1, matrix=Matrix.Rotation(math.pi / 2, 4, "Y"))
    elif shape == "wedge":  # Roblox's: full height at +Z, the slope down toward -Z
        v = [bm.verts.new(p) for p in ((-.5, -.5, -.5), (.5, -.5, -.5), (-.5, -.5, .5), (.5, -.5, .5), (-.5, .5, .5), (.5, .5, .5))]
        for f in ((0, 1, 3, 2), (2, 3, 5, 4), (0, 4, 5, 1), (0, 2, 4), (1, 5, 3)):
            bm.faces.new([v[i] for i in f])
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    else:
        bmesh.ops.create_cube(bm, size=1)
    me = bpy.data.meshes.new(shape)
    bm.to_mesh(me)
    bm.free()
    if shape == "ball":
        for p in me.polygons:
            p.use_smooth = True
    return me


SOLIDS = {}
colls = {}
for name, sc in job["scenes"].items():
    coll = bpy.data.collections.new(name)
    scene.collection.children.link(coll)
    colls[name] = coll
    for f in sc.get("fish", []):
        d = np.load(f["npz"])
        me = bpy.data.meshes.new("fish")
        me.from_pydata([tuple(v) for v in d["verts"]], [], [tuple(int(i) for i in t) for t in d["tris"]])
        col = me.color_attributes.new("Col", "FLOAT_COLOR", "POINT")
        for i, c in enumerate(d["colours"]):
            col.data[i].color = (*[float(x) for x in c], 1.0)
        me.materials.append(fish_material(False))
        me.materials.append(fish_material(True))
        me.polygons.foreach_set("material_index", [int(g) for g in d["glow"]])
        ob = bpy.data.objects.new("fish", me)
        ob.matrix_world = FLIP @ Matrix(f.get("m") or [[1, 0, 0, 0], [0, 1, 0, 0], [0, 0, 1, 0], [0, 0, 0, 1]])
        coll.objects.link(ob)
    for p in sc.get("parts", []):
        if p["shape"] not in SOLIDS:
            SOLIDS[p["shape"]] = solid(p["shape"])
        ob = bpy.data.objects.new("p", SOLIDS[p["shape"]].copy())
        ob.data.materials.append(material(p["colour"], bool(p.get("neon"))))
        ob.matrix_world = FLIP @ Matrix(p["m"]) @ Matrix.Diagonal((*p["size"], 1.0))
        coll.objects.link(ob)

try:
    scene.render.engine = "BLENDER_EEVEE"
except TypeError:
    scene.render.engine = "BLENDER_EEVEE_NEXT"
scene.eevee.taa_render_samples = 24
scene.render.film_transparent = True
scene.render.image_settings.file_format = "PNG"
scene.render.image_settings.color_mode = "RGBA"
scene.view_settings.view_transform = "Standard"
world = bpy.data.worlds.new("w")
scene.world = world
world.use_nodes = True
world.node_tree.nodes["Background"].inputs[0].default_value = (0.80, 0.88, 1.0, 1)
world.node_tree.nodes["Background"].inputs[1].default_value = 0.5
for direction, power in (((-0.5, 0.45, -0.9), 2.0), ((0.7, -0.4, -0.5), 0.6)):
    sun = bpy.data.lights.new("sun", "SUN")
    sun.energy = power
    sun.angle = 0.05
    so = bpy.data.objects.new("sun", sun)
    so.rotation_euler = Vector(direction).to_track_quat("-Z", "Y").to_euler()
    scene.collection.objects.link(so)
cam = bpy.data.cameras.new("c")
cam.clip_end = 2000
cam.clip_start = 0.05
co = bpy.data.objects.new("c", cam)
scene.collection.objects.link(co)
scene.camera = co
for sh in job["shots"]:
    for name, coll in colls.items():
        coll.hide_render = name != sh["scene"]
    eye, at = (FLIP @ Vector((*sh["eye"], 1)))[:3], (FLIP @ Vector((*sh["at"], 1)))[:3]
    co.location = eye
    co.rotation_euler = (Vector(at) - Vector(eye)).to_track_quat("-Z", "Y").to_euler()
    cam.sensor_fit = "VERTICAL"
    if sh.get("ortho"):
        cam.type, cam.ortho_scale = "ORTHO", sh["ortho"]
    else:
        cam.type, cam.angle_y = "PERSP", math.radians(sh["fov"])
    scene.render.resolution_x, scene.render.resolution_y = sh["w"], sh["h"]
    scene.render.filepath = sh["out"]
    bpy.ops.render.render(write_still=True)
