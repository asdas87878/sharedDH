"""Draws the pictures for the shopkeepers' design sheet: plain boxes, balls and cylinders in Roblox's frame, as
tools/keepers/sheet.py lays them out from the game's own tables. Not Roblox: no studs, a stand-in light.

usage: blender --background --python tools/blender/keeper_view.py -- <job.json>
    the job: {"scenes": {name: {"boxes": [...], "ground": [r, g, b] or null}},
              "shots": [{"scene", "eye", "at", "fov", "w", "h", "out"}]}
    a box: {"shape", "size", "m" (4 rows of 4, Roblox's frame), "colour", "see", "neon"}"""
import json
import math
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector

job = json.load(open(sys.argv[sys.argv.index("--") + 1]))


def r2b(v):
    return Vector((v[0], -v[2], v[1]))


def lin(c):
    out = []
    for v in c:
        v /= 255.0
        out.append(v / 12.92 if v <= 0.04045 else ((v + 0.055) / 1.055) ** 2.4)
    return (*out, 1.0)


bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
materials = {}


def material(colour, see, neon):
    key = (tuple(colour), see, neon)
    if key in materials:
        return materials[key]
    mat = bpy.data.materials.new("c%d_%d_%d" % tuple(colour))
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value = lin(colour)
    bsdf.inputs["Roughness"].default_value = 0.9
    if neon:
        bsdf.inputs["Emission Color"].default_value = lin(colour)
        bsdf.inputs["Emission Strength"].default_value = 1.6
    if see > 0:
        bsdf.inputs["Alpha"].default_value = 1 - see
        mat.surface_render_method = "BLENDED"
    materials[key] = mat
    return mat


def mesh_of(kind):
    bm = bmesh.new()
    if kind == "Ball":
        bmesh.ops.create_uvsphere(bm, u_segments=24, v_segments=14, radius=0.5)
    elif kind == "Cylinder":
        bmesh.ops.create_cone(bm, cap_ends=True, segments=28, radius1=0.5, radius2=0.5, depth=1.0)
    else:
        bmesh.ops.create_cube(bm, size=1.0)
    for f in bm.faces:
        f.smooth = kind == "Ball"
    me = bpy.data.meshes.new(kind)
    bm.to_mesh(me)
    bm.free()
    return me


meshes = {kind: mesh_of(kind) for kind in ("Block", "Ball", "Cylinder")}
groups = {}
for name, sc in job["scenes"].items():
    col = bpy.data.collections.new(name)
    scene.collection.children.link(col)
    boxes = list(sc["boxes"])
    if sc.get("ground"):
        boxes.append({"shape": "Block", "size": [600, 1, 600], "m": [[1, 0, 0, 0], [0, 1, 0, sc.get("floor", 0.0) - 0.5], [0, 0, 1, 0], [0, 0, 0, 1]],
                      "colour": sc["ground"], "see": 0, "neon": False})
    for b in boxes:
        obj = bpy.data.objects.new(name, meshes[b["shape"]].copy())
        m, s = b["m"], b["size"]
        x, y, z = (r2b([m[r][c] for r in range(3)]) for c in range(3))
        if b["shape"] == "Ball":
            s = [min(s)] * 3
        if b["shape"] == "Cylinder":  # the mesh's round axis is its z; a Roblox cylinder's is its x
            cols = (y * s[1], z * s[2], x * s[0])
        else:
            cols = (x * s[0], y * s[1], z * s[2])
        mw = Matrix.Identity(4)
        for c in range(3):
            for r in range(3):
                mw[r][c] = cols[c][r]
        mw.translation = r2b([m[0][3], m[1][3], m[2][3]])
        obj.matrix_world = mw
        obj.data.materials.append(material(b["colour"], b.get("see", 0), b.get("neon", False)))
        col.objects.link(obj)
    groups[name] = col

for engine in ("BLENDER_EEVEE", "BLENDER_EEVEE_NEXT"):
    try:
        scene.render.engine = engine
        break
    except TypeError:
        pass
scene.render.image_settings.file_format = "PNG"
scene.eevee.taa_render_samples = 24
scene.view_settings.view_transform = "Standard"
world = bpy.data.worlds.new("World")
world.use_nodes = True
scene.world = world
back = world.node_tree.nodes["Background"]
back.inputs["Color"].default_value = (0.55, 0.7, 0.92, 1)
back.inputs["Strength"].default_value = 0.95
sun = bpy.data.objects.new("Sun", bpy.data.lights.new("Sun", "SUN"))
sun.data.energy = 3.0
sun.data.angle = math.radians(2)
scene.collection.objects.link(sun)
cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
cam.data.sensor_fit = "VERTICAL"
cam.data.clip_end = 3000
scene.collection.objects.link(cam)
scene.camera = cam

for shot in job["shots"]:
    for name, col in groups.items():
        col.hide_render = name != shot["scene"]
    eye, at = r2b(shot["eye"]), r2b(shot["at"])
    cam.location = eye
    look = at - eye
    cam.rotation_euler = look.to_track_quat("-Z", "Y").to_euler()
    cam.data.angle_y = math.radians(shot["fov"])
    # the light from over the viewer's left shoulder, so every picture is lit from its front
    side = look.cross(Vector((0, 0, 1))).normalized()
    sun_dir = (-look.normalized() * 0.75 - side * 0.5 + Vector((0, 0, 1.0)))
    sun.rotation_euler = sun_dir.to_track_quat("Z", "Y").to_euler()
    scene.render.resolution_x, scene.render.resolution_y = shot["w"], shot["h"]
    scene.render.filepath = shot["out"]
    bpy.ops.render.render(write_still=True)
    print("rendered", shot["out"])
