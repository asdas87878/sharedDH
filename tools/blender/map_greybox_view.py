"""Pictures of the grey-box (tools/map/greybox.py): reads art/map/greybox/parts.json and path.json and renders a few
views into art/map/greybox/renders. `python tools/map/greybox_sheet.py` lays them out for the vault.

usage: blender --background --python tools/blender/map_greybox_view.py [-- view,view]
Not Roblox: the light and the fog (classic fog to a water colour) are stand-ins. Roblox axes in, turned for Blender."""
import json
import math
import os
import sys

import bmesh
import bpy
from mathutils import Vector

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
KIT = "--kit" in argv  # the asset sheet (tools/map/props.py) instead of the lane
argv = [a for a in argv if a != "--kit"]
only = argv[0].split(",") if argv else None
BOX = os.environ.get("GREYBOX_OUT") or os.path.join(ROOT, "art", "map", "props" if KIT else "greybox")
OUT = os.path.join(BOX, "renders")
if KIT:
    kit = json.load(open(os.path.join(BOX, "kit.json")))
    parts, info, path = kit["parts"], {}, []
else:
    parts = json.load(open(os.path.join(BOX, "parts.json")))["parts"]
    info = json.load(open(os.path.join(BOX, "path.json")))
    path = info["Path"]
fades, fogs, waters = [], [], []


def lin(c):
    out = []
    for v in c:
        v /= 255.0
        out.append(v / 12.92 if v <= 0.04045 else ((v + 0.055) / 1.055) ** 2.4)
    return (*out, 1.0)


def r2b(v):
    return Vector((v[0], -v[2], v[1]))


def along(s):
    """the lane's centre on the floor at s, and its direction there, from the path's samples"""
    for a, b in zip(path, path[1:]):
        if s <= b[0] and b[0] - a[0] > 1.5:
            f = (s - a[0]) / (b[0] - a[0])
            p = Vector((a[1] + (b[1] - a[1]) * f, a[2] + (b[2] - a[2]) * f, a[3] + (b[3] - a[3]) * f))
            d = Vector((b[1] - a[1], 0, b[3] - a[3])).normalized()
            return p, d
    return Vector(path[-1][1:4]), Vector((0, 0, 1))


def material(colour, kind):
    mat = bpy.data.materials.new(f"{kind}_{colour[0]}_{colour[1]}_{colour[2]}")
    mat.use_nodes = True
    nt = mat.node_tree
    nt.nodes.clear()
    n, link = nt.nodes, nt.links.new
    if kind == "glass":  # a tank's water: see-through, not part of the sea
        surf = n.new("ShaderNodeBsdfDiffuse")
        surf.inputs["Color"].default_value = lin(colour)
        clear = n.new("ShaderNodeBsdfTransparent")
        see = n.new("ShaderNodeMixShader")
        see.inputs[0].default_value = 0.5
        link(clear.outputs[0], see.inputs[1])
        link(surf.outputs[0], see.inputs[2])
        out = n.new("ShaderNodeOutputMaterial")
        link(see.outputs[0], out.inputs["Surface"])
        mat.surface_render_method = "BLENDED"
        return mat
    if kind == "water":
        surf = n.new("ShaderNodeEmission")
        surf.inputs["Color"].default_value = lin(colour)
        clear = n.new("ShaderNodeBsdfTransparent")
        see = n.new("ShaderNodeMixShader")
        see.inputs[0].default_value = 0.62
        waters.append(see)
        link(clear.outputs[0], see.inputs[1])
        link(surf.outputs[0], see.inputs[2])
        out = n.new("ShaderNodeOutputMaterial")
        link(see.outputs[0], out.inputs["Surface"])
        mat.surface_render_method = "BLENDED"
        return mat
    surf = n.new("ShaderNodeBsdfDiffuse")
    surf.inputs["Color"].default_value = lin(colour)
    if kind in ("ground", "plain", "hub", "grass", "fill"):  # squares of two close shades on everything that is ground (the user: everywhere)
        geo = n.new("ShaderNodeNewGeometry")
        check = n.new("ShaderNodeTexChecker")
        check.inputs["Scale"].default_value = 1.0 / 8.0  # squares of 8 studs
        check.inputs["Color1"].default_value = lin(colour)
        check.inputs["Color2"].default_value = lin(tuple(int(c * 0.93) for c in colour))
        flat = n.new("ShaderNodeVectorMath")  # by x and z only, so walls' tops and the floor share one grid
        flat.operation = "MULTIPLY"
        flat.inputs[1].default_value = (1.0, 1.0, 0.0)
        link(geo.outputs["Position"], flat.inputs[0])
        link(flat.outputs[0], check.inputs["Vector"])
        link(check.outputs["Color"], surf.inputs["Color"])
    cam = n.new("ShaderNodeCameraData")
    fade = n.new("ShaderNodeMath")
    fade.operation, fade.use_clamp = "DIVIDE", True
    link(cam.outputs["View Distance"], fade.inputs[0])
    fog = n.new("ShaderNodeEmission")
    mix = n.new("ShaderNodeMixShader")
    link(fade.outputs[0], mix.inputs[0])
    link(surf.outputs[0], mix.inputs[1])
    link(fog.outputs[0], mix.inputs[2])
    out = n.new("ShaderNodeOutputMaterial")
    link(mix.outputs[0], out.inputs["Surface"])
    fades.append(fade)
    fogs.append(fog)
    return mat


bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
for engine in ("BLENDER_EEVEE", "BLENDER_EEVEE_NEXT"):
    try:
        scene.render.engine = engine
        break
    except TypeError:
        continue
scene.render.resolution_x, scene.render.resolution_y = 1280, 720
scene.render.image_settings.file_format = "PNG"
scene.view_settings.view_transform = "Standard"
scene.eevee.taa_render_samples = 32
try:
    scene.eevee.shadow_pool_size = "1024"  # the scene is 10,000 studs long
except (AttributeError, TypeError):
    pass
world = bpy.data.worlds.new("World")
world.use_nodes = True
scene.world = world
sun = bpy.data.objects.new("Sun", bpy.data.lights.new("Sun", "SUN"))
sun.data.energy, sun.data.angle = 2.6, math.radians(4)
sun.rotation_euler = (math.radians(40), math.radians(-14), math.radians(35))
scene.collection.objects.link(sun)

groups = {}
for p in parts:
    if p["k"] == "barrier":
        continue  # unseen in the game
    groups.setdefault((p["k"], tuple(p["c"])), []).append(p)
water_objects = []
for (kind, colour), boxes in groups.items():
    bm = bmesh.new()
    for p in boxes:
        c, ax, ay, az = Vector(p["p"]), Vector(p["x"]), Vector(p["y"]), Vector(p["z"])
        hx, hy, hz = (v / 2 for v in p["s"])
        corner = {}
        for sx in (-1, 1):
            for sy in (-1, 1):
                for sz in (-1, 1):
                    corner[(sx, sy, sz)] = bm.verts.new(r2b(c + ax * hx * sx + ay * hy * sy + az * hz * sz))
        for axis in range(3):
            for sign in (-1, 1):
                quad = []
                for u, v in ((-1, -1), (1, -1), (1, 1), (-1, 1)):
                    key = [0, 0, 0]
                    key[axis] = sign
                    key[(axis + 1) % 3], key[(axis + 2) % 3] = u, v
                    quad.append(corner[tuple(key)])
                bm.faces.new(quad)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    mesh = bpy.data.meshes.new(kind)
    bm.to_mesh(mesh)
    bm.free()
    mesh.materials.append(material(colour, kind))
    obj = bpy.data.objects.new(kind, mesh)
    scene.collection.objects.link(obj)
    if kind in ("water", "glass"):
        obj.visible_shadow = False
    if kind == "water":
        water_objects.append(obj)


def camera(name, eye, target, fov=70.0):
    cam = bpy.data.objects.new(name, bpy.data.cameras.new(name))
    cam.data.sensor_fit = "VERTICAL"
    cam.data.angle_y = math.radians(fov)
    cam.data.clip_start, cam.data.clip_end = 0.5, 80000
    e, t = r2b(eye), r2b(target)
    cam.location = e
    cam.rotation_euler = (t - e).to_track_quat("-Z", "Y").to_euler()
    scene.collection.objects.link(cam)
    return cam


def lane_view(s, back, up, look_ahead, look_up, sideways=0.0, look_side=0.0):
    p, d = along(s)
    rt = Vector((d.z, 0, -d.x))
    q, _ = along(s + look_ahead)
    return p - d * back + Vector((0, up, 0)) + rt * sideways, q + Vector((0, look_up, 0)) + rt * look_side


SKY, HAZE = (150, 205, 240), (214, 232, 236)
SEA, SEA_LIGHT = (64, 200, 205), (120, 185, 185)
if KIT:
    views = {name: (Vector(v["eye"]), Vector(v["target"]), HAZE, 1e7, (205, 225, 240), v["fov"], 0.0) for name, v in kit["views"].items()}
else:
    necks = info["Necks"]
    opens = [(side, sp) for side, name in ((-1, "Left"), (1, "Right")) for sp in info["Sides"][name] if sp["Kind"] in ("open", "rim") and sp["S0"] > 300]
    open_side, open_span = opens[0]
    def clear_view(s0, up, look_ahead, look_up):
        """a rider's view from the first place at or after s0 where no big asset stands on the camera or just ahead"""
        for k in range(60):
            eye, target = lane_view(s0 + k * 12.0, 0, up, look_ahead, look_up)
            d = Vector((target.x - eye.x, 0, target.z - eye.z)).normalized()
            spots = [eye + d * step for step in (0, 25, 50, 75)]
            if all(math.hypot(q.x - bx, q.z - bz) > br + 12 for q in spots for bx, bz, br in info["BigWorld"]):
                return eye, target
        return eye, target
    views = {  # name: (eye, target, fog colour, fog distance, sky colour, field of view, how solid the water looks)
        "hub": (Vector((0, 9, -166)), Vector((0, 4, 60)), HAZE, 6000, SKY, 70, 0.8),  # from the spawn, at the start
        "hub_back": (Vector((0, 9, -40)), Vector((0, 8, -352)), HAZE, 6000, SKY, 70, 0.8),  # from the start, at the plots
        "hub_above": (Vector((-220, 270, -520)), Vector((10, -10, 20)), HAZE, 12000, SKY, 55, 0.25),
        "probe": (*lane_view(float(os.environ.get("PROBE_S", "950")), 0, float(os.environ.get("PROBE_UP", "50")), 60, -20, float(os.environ.get("PROBE_SIDE", "0")), float(os.environ.get("PROBE_LOOK", "-110"))), HAZE, 6000, SKY, 70, 0.0),
        "hub_look": (Vector((120, 70, -250)), Vector((-60, 0, 10)), HAZE, 12000, SKY, 70, 0.6),  # for judging the hub's colours
        "hub_top": (Vector((0, 640, -164)), Vector((0, 0, -160)), HAZE, 12000, SKY, 45, 0.6),
        # the reference's own flight views, for laying side by side: no water, daylight
        "fly_ahead": (*lane_view(necks[1] - 60, 60, 62, 300, 0), HAZE, 5200, SKY, 80, 0.0),
        "fly_down": (*lane_view(necks[2] + 40, 110, 215, 250, -10), HAZE, 5200, SKY, 70, 0.0),
        "fly_far": (*lane_view(necks[3], 260, 420, 700, -30), HAZE, 9000, SKY, 60, 0.0),
        "fly_open": (*lane_view(open_span["S0"] + 60, 90, 190, 260, -10, -open_side * 40, open_side * 40), HAZE, 5200, SKY, 70, 0.0),
        # and as the game shows it: under water, from a rider's height
        "ride": (*clear_view(necks[1] + 40, 24, 170, 12), SEA, 1000, SEA_LIGHT, 70, 0.62),
        "ride_assets": (*clear_view(560, 22, 160, 14), SEA, 1000, SEA_LIGHT, 70, 0.62),
        "ride_reef": (*clear_view(necks[4] + 30, 24, 170, 14), SEA, 1000, SEA_LIGHT, 70, 0.62),
        "ride_kelp": (*clear_view(3700, 26, 190, 26), (50, 150, 120), 800, (80, 140, 105), 70, 0.62),
    }
    # one rider's view in each land, in a water colour for that land (lightened so the deep lands can be seen), and
    # the whole dive from high up
    WATERS = [(64, 200, 205), (40, 170, 200), (50, 140, 110), (35, 105, 120), (20, 85, 170), (40, 50, 130), (30, 36, 90), (70, 36, 40), (50, 60, 90), (80, 20, 30)]
    for k, land in enumerate(info["Lands"]):
        if land["S0"] < info["BuiltTo"]:
            water = WATERS[min(k, len(WATERS) - 1)]
            views[f"land{k + 1:02d}"] = (*clear_view(land["S0"] + 500, 30, 260, 14), water, 1500, tuple(min(255, c + 70) for c in water), 70, 0.0)
    mid, _d = along(info["BuiltTo"] * 0.5)
    views["whole"] = (Vector((mid.x - 9000, 9000, mid.z - 2000)), Vector((mid.x, -1000, mid.z)), HAZE, 90000, SKY, 50, 0.0)
os.makedirs(OUT, exist_ok=True)
for name, (eye, target, fog, far, sky, fov, solid) in views.items():
    if only and name not in only:
        continue
    for fade in fades:
        fade.inputs[1].default_value = far
    for node in waters:
        node.inputs[0].default_value = solid
    for obj in water_objects:
        obj.hide_render = solid <= 0
    for node in fogs:
        node.inputs["Color"].default_value = lin(fog)
    world.node_tree.nodes["Background"].inputs["Color"].default_value = lin(sky)
    scene.camera = camera(name, eye, target, fov)
    scene.render.filepath = os.path.join(OUT, name + ".png")
    bpy.ops.render.render(write_still=True)
    print("rendered", name)
