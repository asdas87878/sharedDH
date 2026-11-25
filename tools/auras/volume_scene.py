# Blender, for tools/auras/volume_shots.py: a grey blocky avatar standing on sand, and sat on a fish in deep water, seen from
# the front and the side, each with a depth picture and masks (the wearer; on the ride also a fish ahead of them). Roblox's (x, y, z) is Blender's (x, -z, y); feet at 0, facing -z.
# Run: blender -b --python tools/auras/volume_scene.py -- <outdir> <repo> <dump.json>
import json
import math
import sys

import bpy
import numpy as np
from mathutils import Euler, Matrix, Vector

out, repo, dump = sys.argv[sys.argv.index("--") + 1:][:3]
bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
scene.render.engine = "CYCLES"
scene.cycles.samples = 32
scene.cycles.use_denoising = True
scene.view_settings.view_transform = "Standard"
scene.render.image_settings.color_mode = "RGB"


def mat(name, rgb, rough=0.8):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = (*[(c / 255) ** 2.2 for c in rgb], 1)
    b.inputs["Roughness"].default_value = rough
    return m


SKIN, SHIRT, LEGS, INK, SAND = (mat("skin", (205, 198, 186)), mat("shirt", (150, 156, 166)), mat("legs", (84, 90, 104)),
                                mat("ink", (24, 24, 28)), mat("sand", (206, 190, 150)))


def box(size, loc, material, parent, bevel=0.07, rot=None):
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc)
    o = bpy.context.object
    o.scale = size
    bpy.ops.object.transform_apply(scale=True)
    if bevel:
        b = o.modifiers.new("b", "BEVEL")
        b.width = bevel
        b.segments = 2
    if rot:
        o.rotation_euler = Euler(rot)
    o.data.materials.append(material)
    o.parent = parent
    return o


def avatar(name, seated=False):
    """Feet at z = 0, facing +Y (Roblox -z). Its root (the torso's middle) is at 3."""
    root = bpy.data.objects.new(name, None)
    scene.collection.objects.link(root)
    box((2, 1, 2), (0, 0, 3), SHIRT, root)
    box((1.2, 1.2, 1.2), (0, 0, 4.6), SKIN, root, 0.16)
    for sx in (-1, 1):
        box((1, 1, 2), (sx * 1.5, 0, 3), SKIN, root, rot=(0, sx * -0.09, 0))
        if seated:
            box((0.98, 1, 2), (sx * 0.95, 0.55, 1.75), LEGS, root, rot=(math.radians(62), sx * math.radians(24), 0))
        else:
            box((0.98, 1, 2), (sx * 0.5, 0, 1), LEGS, root)
        box((0.15, 0.04, 0.26), (sx * 0.26, 0.6, 4.72), INK, root, 0)
    box((0.5, 0.04, 0.09), (0, 0.6, 4.32), INK, root, 0)
    return root


sets = {}
figures = {}  # a set's wearer,
aheads = {}  # and the fish ahead of the rider (their own camera's view only)
stand = avatar("stand")
figures["foot"] = [stand, *stand.children_recursive]
bpy.ops.mesh.primitive_plane_add(size=400, location=(0, 0, 0))
ground = bpy.context.object
ground.data.materials.append(SAND)
ground.parent = stand
sets["foot"] = stand
mounts = {s["Mount"]["Id"]: s["Mount"] for s in json.load(open(dump)) if s.get("Mount")}
for name, m in mounts.items():
    root = bpy.data.objects.new(name, None)
    scene.collection.objects.link(root)
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=f"{repo}/art/creatures/{name}/game/{name}.glb")
    made = [o for o in bpy.data.objects if o not in before]
    holder = bpy.data.objects.new(name + "_f", None)
    scene.collection.objects.link(holder)
    for o in made:
        if o.parent is None:
            o.parent = holder
    bpy.context.view_layer.update()

    def bounds():
        lo, hi = Vector((1e9,) * 3), Vector((-1e9,) * 3)
        for o in made:
            if o.type == "MESH":
                for c in o.bound_box:
                    w = o.matrix_world @ Vector(c)
                    lo, hi = Vector(map(min, lo, w)), Vector(map(max, hi, w))
        return lo, hi

    lo, hi = bounds()
    d = hi - lo
    print(name, "as made", tuple(round(v, 2) for v in d), "wanted", m["Body"])
    along = 0 if d.x > d.y else 1
    k = m["Body"][2] / d[along]
    holder.scale = (k, k, k)
    # (as exported a fish lies along Y, its head toward +Y: Roblox -z, the way the rider looks)
    holder.rotation_euler = Euler((0, 0, math.radians(90 if along == 0 else 0)))
    bpy.context.view_layer.update()
    lo, hi = bounds()
    holder.location = -(lo + hi) / 2
    holder.parent = root
    rider = avatar(name + "_r", seated=True)
    sx, sy, sz = m["Seat"]
    rider.location = (sx, -sz, sy - 3)
    rider.parent = root
    figures[name] = [rider, *rider.children_recursive]
    sets[name] = root
# the next fish to hop to, 28 studs ahead of the rider, a little to the left and up
for name, m in mounts.items():
    ahead = bpy.data.objects.new(name + "_a", None)
    scene.collection.objects.link(ahead)
    for o in sets["Clownfish"].children_recursive:
        if o.type == "MESH" and o not in figures["Clownfish"]:
            bpy.context.view_layer.update()
            c = o.copy()
            scene.collection.objects.link(c)
            c.parent = None
            c.matrix_world = o.matrix_world
            c.parent = ahead
    s = m["Seat"]
    ahead.location = (s[0] - 6, -s[2] + 28, s[1] + 3)
    aheads[name] = [ahead, *ahead.children_recursive]

world = bpy.data.worlds.new("w")
scene.world = world
world.use_nodes = True
bg = world.node_tree.nodes["Background"]
bpy.ops.object.light_add(type="SUN", location=(0, 0, 10))
sun = bpy.context.object
sun.data.angle = math.radians(4)


def light(deep):
    if deep:
        bg.inputs["Color"].default_value = (0.03, 0.10, 0.30, 1)
        bg.inputs["Strength"].default_value = 0.8
        sun.data.energy = 1.3
        sun.data.color = (0.5, 0.75, 1.0)
        sun.rotation_euler = Euler((math.radians(15), 0, math.radians(-20)))
    else:
        bg.inputs["Color"].default_value = (0.30, 0.52, 0.80, 1)
        bg.inputs["Strength"].default_value = 0.75
        sun.data.energy = 2.0
        sun.data.color = (1.0, 0.96, 0.88)
        sun.rotation_euler = Euler((math.radians(48), 0, math.radians(38)))


cam_data = bpy.data.cameras.new("cam")
cam = bpy.data.objects.new("cam", cam_data)
scene.collection.objects.link(cam)
scene.camera = cam
cam_data.sensor_fit = "VERTICAL"
cam_data.clip_end = 600

dm = bpy.data.materials.new("depth")
dm.use_nodes = True
nt = dm.node_tree
nt.nodes.clear()
cd, mul, em, o_ = (nt.nodes.new(n) for n in ("ShaderNodeCameraData", "ShaderNodeMath", "ShaderNodeEmission",
                                            "ShaderNodeOutputMaterial"))
mul.operation = "MULTIPLY"
mul.inputs[1].default_value = 1 / 256
nt.links.new(cd.outputs["View Z Depth"], mul.inputs[0])
nt.links.new(mul.outputs[0], em.inputs["Color"])
nt.links.new(em.outputs[0], o_.inputs["Surface"])

# name: (set, look-at (Roblox), how far round from the front (degrees), distance, pitch down, vertical fov, w, h)
VIEWS = {
    "foot_front": ("foot", (0, 6.6, 0), 14, 27, 13, 38, 560, 760),
    "foot_side": ("foot", (0, 6.6, 0), 90, 27, 13, 38, 560, 760),
    "foot_close": ("foot", (0, 3.0, 0), 25, 14, 12, 38, 760, 560),
}
for name, m in mounts.items():
    L = m["Body"][2]
    y = m["Seat"][1] * 0.45
    VIEWS[f"{name}_front"] = (name, (0, y + 2, m["Seat"][2] * 0.7), 40, 14 + L * 1.05, 10, 38, 1000, 760)
    VIEWS[f"{name}_side"] = (name, (0, y + 2, m["Seat"][2] * 0.7), 90, 14 + L * 1.05, 6, 38, 1000, 760)
    VIEWS[f"{name}_own"] = (name, None, 180, 17.7, 0, 70, 1280, 720)
    # (another player beside them: 22 studs from the rider, with the game's own lens)
    VIEWS[f"{name}_other"] = (name, (m["Seat"][0], m["Seat"][1], m["Seat"][2]), 40, 22, 12, 70, 1280, 720)
meta = {}
for name, (which, at, yaw, dist, pitch, fov, w, h) in VIEWS.items():
    for k, o in sets.items():
        for c in [o, *o.children_recursive]:
            c.hide_render = k != which
    for k, o in aheads.items():
        for c in o:
            c.hide_render = k != which or at is not None
    if at is None:  # the game's own riding camera: 17 behind the rider, 5 up, at 70 degrees
        s = mounts[which]["Seat"]
        focus = Vector((s[0], -s[2], s[1]))
        cam.location = focus + Vector((0, -17, 5))
        cam.rotation_euler = (focus - cam.location).to_track_quat("-Z", "Y").to_euler()
    else:
        a, p = math.radians(yaw), math.radians(pitch)
        focus = Vector((at[0], -at[2], at[1]))
        cam.location = focus + Vector((math.sin(a) * math.cos(p), math.cos(a) * math.cos(p), math.sin(p))) * dist
        cam.rotation_euler = (focus - cam.location).to_track_quat("-Z", "Y").to_euler()
    cam_data.angle_y = math.radians(fov)
    cam_data.angle = math.radians(fov)
    scene.render.resolution_x, scene.render.resolution_y = w, h
    bpy.context.view_layer.update()
    mw = cam.matrix_world

    def rbx(v):
        return [v[0], v[2], -v[1]]

    meta[name] = {"w": w, "h": h, "f": (h / 2) / math.tan(math.radians(fov) / 2), "pos": rbx(mw.translation),
                  "right": rbx(mw.to_3x3() @ Vector((1, 0, 0))), "up": rbx(mw.to_3x3() @ Vector((0, 1, 0))),
                  "fwd": rbx(mw.to_3x3() @ Vector((0, 0, -1))), "deep": which != "foot"}
    bpy.context.view_layer.material_override = None
    scene.render.film_transparent = False
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_depth = "8"
    light(which != "foot")
    scene.render.filepath = f"{out}/{name}.png"
    bpy.ops.render.render(write_still=True)
    bpy.context.view_layer.material_override = dm
    scene.render.film_transparent = True
    scene.render.image_settings.file_format = "OPEN_EXR"
    scene.render.image_settings.color_mode = "RGBA"
    scene.render.image_settings.color_depth = "32"
    scene.cycles.samples, scene.cycles.use_denoising = 1, False

    def depth(file):
        scene.render.filepath = f"{out}/{file}.exr"
        bpy.ops.render.render(write_still=True)
        img = bpy.data.images.load(f"{out}/{file}.exr")
        px = np.array(img.pixels[:], dtype=np.float32).reshape(h, w, 4)[::-1]
        a = px[..., 3]
        bpy.data.images.remove(img)
        return np.where(a > 0.5, px[..., 0] / np.maximum(a, 1e-6) * 256, np.inf).astype(np.float32)

    z = depth(f"{name}_depth")
    np.save(f"{out}/{name}_depth.npy", z)
    # who is seen where: the pixels whose nearest thing is the wearer (or the fish ahead)
    for mask, only in (("wearer", figures[which]), ("ahead", aheads.get(which, []) if at is None else [])):
        if only:
            for c in scene.objects:
                if c.type == "MESH":
                    c.hide_render = c not in only
            np.save(f"{out}/{name}_{mask}.npy", np.isfinite(z) & (np.abs(depth(f"{name}_{mask}") - z) < 0.02))
    scene.cycles.samples, scene.cycles.use_denoising = 32, True
    scene.render.image_settings.color_mode = "RGB"
json.dump(meta, open(f"{out}/views.json", "w"), indent=1)
print("DONE")
