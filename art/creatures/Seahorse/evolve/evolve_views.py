"""Renders one evolved rocker whole, whatever its size: voxel_kit.py builds it (its gate and all), this only replaces the
kit's cameras, which look at a low swimming fish. Every view is fitted to the model's own box and shows a 5-stud player
standing beside it and one on its seat.

usage (evolve_preview.py calls it): blender --background --python evolve_views.py -- <voxel.py> <out> --hero
       ... --swim    the rock, 24 frames at two views, in <out>/rock
Writes hero, rear, side, front, top, face .png, and line.png: the 3/4 view at one scale for every level (PX pixels a game
stud), for the line-up sheet."""
import math
import os
import runpy
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(HERE))))
sys.path.insert(0, os.path.join(ROOT, "tools", "blender"))
sys.path.insert(0, HERE)
import bpy  # noqa: E402
import kit_common as kc  # noqa: E402
from mathutils import Vector  # noqa: E402

SHOWN = 0.85  # the game shows the models at 0.85: a player is that much bigger beside them here
PX = 15.0  # pixels a game stud on line.png
MODEL = runpy.run_path([a for a in sys.argv[sys.argv.index("--") + 1:] if a.endswith(".py")][0])


def box_of(objects):
    bpy.context.view_layer.update()
    pts = [ob.matrix_world @ v.co for ob in objects if ob.type == "MESH" for v in ob.data.vertices]
    return [min(p[a] for p in pts) for a in range(3)], [max(p[a] for p in pts) for a in range(3)]


def players(kit):
    """one standing by the stand (toward the camera), one on the seat"""
    k = 1 / SHOWN
    blocks = []

    def solid(name, size, colour, at, rot=(0, 0, 0)):
        blocks.append(kit.solid(name, tuple(s * k for s in size), colour, at, rot))

    lo, hi = box_of(kit.collection.objects)
    u = MODEL["U"]
    pad = max(abs(v) for v in (lo[0], 1)) if False else MODEL["c"].SIZES[MODEL["LEVEL"]]["pad"] * u
    x, y = -pad - 2.0 * k, -pad - 1.5 * k
    for s in (-1, 1):
        solid(f"StandLeg{s}", (0.98, 0.98, 2.0), "#2B2B33", (x, y + s * 0.5 * k, 1.0 * k))
        solid(f"StandArm{s}", (0.96, 0.96, 2.0), "#F2C9A0", (x, y + s * 1.5 * k, 3.0 * k))
    solid("StandTorso", (1.0, 2.0, 2.0), "#E8503C", (x, y, 3.0 * k))
    solid("StandHead", (1.2, 1.2, 1.2), "#F2C9A0", (x, y, 4.6 * k))
    sx, sz, hw = (v * u for v in MODEL["SEAT"])
    solid("RiderTorso", (1.0, 2.0, 2.0), "#E8503C", (sx, 0, sz + 1.2 * k))
    solid("RiderHead", (1.2, 1.2, 1.2), "#F2C9A0", (sx, 0, sz + 2.8 * k))
    for s in (-1, 1):
        solid(f"RiderLeg{s}", (2.0, 0.98, 0.98), "#2B2B33", (sx - 0.7 * k, s * 0.75 * k, sz + 0.1 * k), (0, 0, -s * math.radians(22)))
        solid(f"RiderArm{s}", (1.7, 0.8, 0.8), "#F2C9A0", (sx - 0.8 * k, s * 1.35 * k, sz + 1.5 * k), (0, math.radians(20), 0))
    return blocks


def fit(kit, name, direction, pts, w, h, path, lens=70, ortho=None, margin=1.06):
    """a camera along `direction` (from the model to the camera) that holds every point of `pts`"""
    cam = kit.camera(name, lens=lens)
    d = Vector(direction).normalized()
    quat = (-d).to_track_quat("-Z", "Y")
    inv = quat.to_matrix().transposed()
    local = [inv @ p for p in pts]
    lo = [min(p[a] for p in local) for a in range(3)]
    hi = [max(p[a] for p in local) for a in range(3)]
    mid = quat.to_matrix() @ Vector(((lo[0] + hi[0]) / 2, (lo[1] + hi[1]) / 2, (lo[2] + hi[2]) / 2))
    cam.rotation_euler = quat.to_euler()
    cam.data.clip_end = 2000
    wide, tall = (hi[0] - lo[0]) * margin, (hi[1] - lo[1]) * margin
    if ortho:
        cam.data.type = "ORTHO"
        if ortho == "fit":
            cam.data.ortho_scale = max(wide, tall * w / h)
        else:  # a fixed number of pixels a stud: the picture is as big as it needs to be
            w, h = int(wide * ortho), int(tall * ortho)
            cam.data.ortho_scale = max(w, h) / ortho
        cam.location = mid + d * 300
    else:
        cam.data.sensor_width = 36
        half_w, half_h = 18 / lens, 18 / lens * h / w
        dist = max(abs(p[2] - (lo[2] + hi[2]) / 2) + max(abs(p[0] - (lo[0] + hi[0]) / 2) / half_w,
                                                           abs(p[1] - (lo[1] + hi[1]) / 2) / half_h) for p in local)
        cam.location = mid + d * dist * margin
    kit.render(cam, path, w, h)
    return cam


def points(objects):
    bpy.context.view_layer.update()
    return [ob.matrix_world @ v.co for ob in objects if ob.type == "MESH" and not ob.hide_render for v in ob.data.vertices]


HERO, REAR = (-0.62, -0.72, 0.16), (0.66, -0.66, 0.36)


def turnaround(kit, front_x, mid_x):
    scene = kit.scene
    scene.render.film_transparent = True
    scene.render.image_settings.color_mode = "RGBA"
    for ob in kit.collection.objects:  # level 1 is today's seahorse: its own frame, set on the game's spring here
        dx, dz = MODEL.get("SHIFT", {}).get(ob.name, (0, 0))
        ob.location += Vector((dx, 0, dz)) * MODEL["U"]
    blocks = players(kit)
    objects = [o for o in kit.collection.objects if o.type == "MESH"]
    everything = points(objects + blocks)
    out = lambda n: os.path.join(kit.out, n + ".png")  # noqa: E731
    fit(kit, "Hero", HERO, everything, 1100, 900, out("hero"))
    kc.look_from(kit.sun, (7.0, -7.0, 9.0), (0, 0, 0))
    fit(kit, "Rear", REAR, everything, 900, 740, out("rear"))
    kc.look_from(kit.sun, (-5.0, -7.0, 9.0), (0, 0, 0))
    fit(kit, "Side", (0, -1, 0), everything, 900, 740, out("side"), ortho="fit")
    fit(kit, "Top", (0, -0.001, 1), everything, 900, 560, out("top"), ortho="fit")
    kc.look_from(kit.sun, (-10.0, -1.5, 8.0), (0, 0, 0))
    fit(kit, "Front", (-1, 0, 0.08), everything, 740, 740, out("front"))
    kc.look_from(kit.sun, (-5.0, -7.0, 9.0), (0, 0, 0))
    heads = [o for o in objects if o.name.startswith(("Head", "Jaw"))]
    if heads:
        fit(kit, "Face", (-0.72, -0.68, 0.12), points(heads), 740, 600, out("face"))
    fit(kit, "Line", (-0.62, -0.72, 0.12), everything, 0, 0, out("line"), ortho=PX * SHOWN, margin=1.02)


def rock(kit, folder, frames, pose, mid_x):
    """the rock: the toy swings about the spring's foot, as the game does it, with the model's own pose on top"""
    scene = kit.scene
    scene.render.film_transparent = True
    scene.render.image_settings.color_mode = "RGBA"
    folder = os.path.join(kit.out, "rock")
    os.makedirs(folder, exist_ok=True)
    objects = [o for o in kit.collection.objects if o.type == "MESH"]
    body = next(o for o in objects if o.name == "Body")
    coil = next((o for o in objects if o.name == "Coil"), None)
    size = MODEL["c"].SIZES[MODEL["LEVEL"]]
    foot = Vector((0, 0, size["top"] * MODEL["U"]))
    swing = math.radians(MODEL.get("SWING", 8))
    rest = body.location.copy()
    base = kit.world_pos["Stand"]
    blocks = players(kit)
    riders = [b for b in blocks if b.name.startswith("Rider")]
    for b in riders:  # the rider rides the body
        b.parent = body
        b.matrix_parent_inverse = body.matrix_world.inverted()
    views = []
    for phase in (0, math.pi / 2, math.pi * 1.5):
        pose(phase)
        bpy.context.view_layer.update()
        views += points(objects + blocks)
    for f in range(frames):
        phase = 2 * math.pi * f / frames
        pose(phase)
        a = swing * math.sin(phase)
        arm = (rest + base) - foot
        c, s = math.cos(a), math.sin(a)
        dip = 0.35 * abs(math.sin(phase)) * 0.4
        body.location = foot + Vector((arm.x * c + arm.z * s, arm.y, -arm.x * s + arm.z * c - dip)) - base
        body.rotation_euler.y = a
        if coil:
            coil.rotation_euler.y = a * 0.8
        for name, way, w, h in (("hero", HERO, 620, 510), ("front", (-1, -0.25, 0.1), 510, 510)):
            cam = fit(kit, "Rock", way, views, w, h, os.path.join(folder, f"{name}_{f:03d}.png"), margin=1.1)
            bpy.data.objects.remove(cam)


kc.Kit.turnaround = turnaround
kc.Kit.swim = rock
sys.argv = [sys.argv[0]] + sys.argv[sys.argv.index("--"):]
runpy.run_path(os.path.join(ROOT, "tools", "blender", "voxel_kit.py"), run_name="__main__")
