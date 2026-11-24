"""The sheet for subs 8 and 9, the screw and the bubble trail: docs/attachments/subs-8a-9a-screw-trail.png.

usage:  python tools/blender/sub_trail_sheet.py all <work folder> <sheet.png>      everything (Blender must be on PATH,
                                                                                    or BLENDER set to it)
        blender --background --python tools/blender/sub_trail_sheet.py -- <tier> <out folder> --bubble <ring.png>
        python tools/blender/sub_trail_sheet.py sheet <work folder> <sheet.png>     the sheet from pictures made before

What is drawn is THE GAME'S MESHES (art/subs/<Id>/<Id>.glb, read by tools/creatures/glb_meshes.py: what
tools/subs/install.py puts in the place), not the builder's pieces, with their own colours and shading.
- The screw rows use the cameras, the light and the tile sizes of the propeller sheet Hugo picked option 4 from
  (tools/blender/sub_props_options.py, `stills`), so they lie beside that sheet's option 4 angle for angle.
- The bubble trail is DRAWN FROM THE EMITTER'S NUMBERS (Config.Sub's Wake numbers, read from src/shared/Config.luau;
  the emitter is Shared/SubModels' `dress`): one frozen moment of the bubbles the emitter would have alive, each at
  its place, size and fade, as rings facing the camera, added to the picture as Roblox adds them. The ring is the
  picture Roblox ships (content/textures/particles/explosion01_shockwave_main.dds), found in Studio's own folder. It
  is a sum, not Roblox: the brightness against real water, and the order it is drawn in, are Studio's to show.
- The game's cameras are SubController.cameraFor's, in the sub's own frame: 30 back and 10 up looking 25 ahead at 70
  degrees as a run begins, 38 back and 7 up looking 45 ahead at 88 degrees at full speed, 30 back and 9 up looking 10
  ahead at 74 degrees as it lets you go.
It also writes numbers (stats.json a tier): how much of the rider shows from each camera (rays, as
sub_creature_options.py counts it), how near the trail comes to the rider in the picture, where the trail lies in the
picture, how big its biggest bubble is there and how much of the picture the bubbles cover.
Axes here are the kit's: x to the tail, z up, the sub's middle at the origin (the game's (x, y, z) is (y, z, x)).
"""
import glob
import json
import math
import os
import random
import re
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, "..", ".."))
sys.path.insert(0, os.path.join(ROOT, "tools", "creatures"))
sys.path.insert(0, os.path.join(ROOT, "tools", "subs"))
sys.path.insert(0, HERE)

NAMES = {1: "Bathtub", 8: "Vent Crawler", 9: "Abyss King"}
WAS = {8: "option 8A, from our Sea Scorpion", 9: "option 9A, the kraken's grip"}
# SubController.cameraFor: where it stands, what it looks at, degrees tall; and the sub's speed there, studs a second
CAMS = {
    "start": ((30.0, 0, 10.0), (-25.0, 0, 0.0), 70.0, 90.0),
    "fast": ((38.0, 0, 7.0), (-45.0, 0, 0.0), 88.0, 620.0),
    "drop": ((30.0, 0, 9.0), (-10.0, 0, 0.0), 74.0, 90.0),
}
ASPECT = 16 / 9
RING = 0.30  # the ring's outer edge in its picture, of the picture's width from its middle (measured: its light is under
# a quarter of its most past 0.31, strongest at 0.19)
WATER = (20, 72, 122)  # a stand-in for the water behind: the bubbles add light, so they cannot be shown on the sheet's cream
WAKE_COLOUR = (225, 248, 255)


def wake_numbers():
    text = open(os.path.join(ROOT, "src", "shared", "Config.luau"), encoding="utf-8").read()
    return {k: float(v) for k, v in re.findall(r"^\t(Wake\w+) = ([-0-9.]+),", text, re.M)}


def lerp_keys(keys, t):
    for (t0, v0), (t1, v1) in zip(keys, keys[1:]):
        if t <= t1:
            return v0 + (v1 - v0) * (t - t0) / (t1 - t0)
    return keys[-1][1]


def stream(c, at, rate, seed, every=None):
    """the bubbles alive at one moment: [(place, size, how see-through)]. As SubModels' emitter makes them: straight
    back from `at` within WakeSpread, at WakeSpeed (15% either way) for WakeLife (0.8 to 1.15 of it), rising by
    WakeRise, swelling to WakeSize (a quarter either way) and shrinking to WakeSizeEnd, fading out.
    every: that many bubbles of every age instead (the whole space the trail can fill)"""
    rnd = random.Random(seed)
    size = [(0, c["WakeSize"] * 0.4), (0.12, c["WakeSize"]), (1, c["WakeSizeEnd"])]
    odd = [(0, 0.0), (0.12, c["WakeSize"] * 0.25), (1, c["WakeSizeEnd"] * 0.25)]
    fade = [(0, 0.7), (0.15, c["WakeSee"]), (0.6, (1 + c["WakeSee"]) / 2), (1, 1.0)]
    out = []
    count = every or int(math.ceil(rate * c["WakeLife"] * 1.15)) + 1
    for i in range(count):
        life = c["WakeLife"] * rnd.uniform(0.8, 1.15)
        age = rnd.uniform(0, life) if every else (i + rnd.random()) / rate
        speed = c["WakeSpeed"] * rnd.uniform(0.85, 1.15)
        ax, az = (math.radians(rnd.uniform(-c["WakeSpread"], c["WakeSpread"])) for _ in range(2))
        chance = rnd.uniform(-1, 1)
        if age >= life:
            continue
        t = age / life
        way = (math.cos(ax) * math.cos(az), math.sin(ax) * math.cos(az), math.sin(az))
        place = (at[0] + way[0] * speed * age, at[1] + way[1] * speed * age, at[2] + way[2] * speed * age + 0.5 * c["WakeRise"] * age * age)
        out.append((place, lerp_keys(size, t) + chance * lerp_keys(odd, t), lerp_keys(fade, t)))
    return out


def rate_at(c, speed):
    return min(c["WakeLeast"] + speed * c["WakePerSpeed"], c["WakeMost"])


# ------------------------------------------------------------------------------------------------ Blender
def blender_part():
    import bpy
    from mathutils import Vector
    from mathutils.bvhtree import BVHTree

    import glb_meshes
    import screw_check

    argv = sys.argv[sys.argv.index("--") + 1:]
    tier, out = int(argv[0]), argv[1]
    ring_png = argv[argv.index("--bubble") + 1]
    name, tx, ring, _ = screw_check.TAILS[tier - 1]
    az = screw_check.AZ
    c = wake_numbers()
    os.makedirs(out, exist_ok=True)

    def lin(v):
        return v / 12.92 if v <= 0.04045 else ((v + 0.055) / 1.055) ** 2.4

    def rgba(col):
        return tuple(lin(v / 255) for v in col) + (1.0,)

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
        scene.eevee.taa_render_samples = 48
    except AttributeError:
        pass

    # the game's meshes, each part one object, in the kit's axes
    objects = {}
    for part in glb_meshes.parts(os.path.join(ROOT, "art", "subs", name, name + ".glb")):
        o = part["origin"]
        pts = [(p[2] + o[2], p[0] + o[0], p[1] + o[1]) for p in part["positions"]]
        me = bpy.data.meshes.new(part["name"])
        me.from_pydata(pts, [], [tuple(t) for t in part["triangles"]])
        me.update()
        col = me.color_attributes.new("Col", "FLOAT_COLOR", "POINT")
        for i, v in enumerate(part["colours"]):  # (stored as plain 0..1 of the 0..255 colour)
            col.data[i].color = (lin(v[0]), lin(v[1]), lin(v[2]), 1.0)
        for poly in me.polygons:
            poly.use_smooth = True
        me.normals_split_custom_set_from_vertices([(n[2], n[0], n[1]) for n in part["normals"]])
        m = bpy.data.materials.new(part["name"])
        m.use_nodes = True
        nt = m.node_tree
        bs = nt.nodes.get("Principled BSDF")
        at = nt.nodes.new("ShaderNodeVertexColor")
        at.layer_name = "Col"
        nt.links.new(at.outputs["Color"], bs.inputs["Base Color"])
        bs.inputs["Roughness"].default_value = 0.65
        bs.inputs["Specular IOR Level"].default_value = 0.25
        glow = 3.0 if part["name"] == "Light" else 1.5 if part["name"].endswith("_Glow") else 0.0
        if glow:  # (the game turns these to Neon)
            nt.links.new(at.outputs["Color"], bs.inputs["Emission Color"])
            bs.inputs["Emission Strength"].default_value = glow
        me.materials.append(m)
        ob = bpy.data.objects.new(part["name"], me)
        scene.collection.objects.link(ob)
        objects[part["name"]] = ob

    # a blocky rider on the seat, as the other sheets draw one
    import bmesh
    from mathutils import Euler, Matrix

    riders = []
    rider_mats = {}
    for key, col in (("skin", (242, 201, 76)), ("shirt", (45, 127, 211)), ("legs", (92, 168, 74))):
        m = bpy.data.materials.new("Rider_" + key)
        m.use_nodes = True
        m.node_tree.nodes.get("Principled BSDF").inputs["Base Color"].default_value = rgba(col)
        rider_mats[key] = m

    def rbox(mid, size, key, r=(0, 0, 0)):
        bm = bmesh.new()
        turn = Euler([math.radians(a) for a in r], "XYZ").to_matrix().to_4x4()
        bmesh.ops.create_cube(bm, size=1.0, matrix=Matrix.Translation(mid) @ turn @ Matrix.Diagonal((*size, 1.0)))
        me = bpy.data.meshes.new("Rider")
        bm.to_mesh(me)
        bm.free()
        me.materials.append(rider_mats[key])
        ob = bpy.data.objects.new("Rider", me)
        scene.collection.objects.link(ob)
        riders.append(ob)

    SX, SZ = 5.0, 5.7
    rbox((SX, 0, SZ + 1.7), (1.0, 2.0, 2.0), "shirt", r=(0, -8, 0))
    rbox((SX - 0.3, 0, SZ + 3.4), (1.25, 1.25, 1.25), "skin")
    for s in (-1, 1):
        rbox((SX - 1.0, s * 0.55, SZ + 0.5), (2.0, 0.95, 0.95), "legs")
        rbox((SX - 2.0, s * 0.55, SZ - 0.1), (0.95, 0.95, 1.6), "legs", r=(0, 20, 0))
        rbox((SX - 1.2, s * 1.5, SZ + 1.75), (2.3, 0.9, 0.9), "skin", r=(0, 22, 0))

    # where the emitter stands: SubModels' `prop.Position + Vector3.new(0, 0, prop.Size.Z / 2)`, the propeller's box's
    # middle moved to its back end
    prop = [v.co for v in objects["Prop"].data.vertices]
    lo = [min(p[a] for p in prop) for a in range(3)]
    hi = [max(p[a] for p in prop) for a in range(3)]
    emit = (hi[0], (lo[1] + hi[1]) / 2, (lo[2] + hi[2]) / 2)
    drawn = [ob.matrix_world @ v.co for ob in objects.values() for v in ob.data.vertices]
    x_lo, x_hi = min(p.x for p in drawn), max(p.x for p in drawn)
    mid = (x_lo + x_hi) / 2

    # the bubbles: one square a bubble, turned to each camera, its light added to the picture
    ring_image = bpy.data.images.load(os.path.abspath(ring_png))
    bm_ = bpy.data.materials.new("Bubble")
    bm_.use_nodes = True
    bm_.surface_render_method = "BLENDED"
    bm_.use_backface_culling = False
    nt = bm_.node_tree
    for node in list(nt.nodes):
        if node.type != "OUTPUT_MATERIAL":
            nt.nodes.remove(node)
    tex = nt.nodes.new("ShaderNodeTexImage")
    tex.image = ring_image
    info = nt.nodes.new("ShaderNodeObjectInfo")
    mul = nt.nodes.new("ShaderNodeMath")
    mul.operation = "MULTIPLY"
    gain = nt.nodes.new("ShaderNodeMath")
    gain.operation = "MULTIPLY"
    gain.inputs[1].default_value = c["WakeBright"]
    light = nt.nodes.new("ShaderNodeEmission")
    light.inputs["Color"].default_value = rgba(WAKE_COLOUR)
    clear = nt.nodes.new("ShaderNodeBsdfTransparent")
    add = nt.nodes.new("ShaderNodeAddShader")
    nt.links.new(tex.outputs["Alpha"], mul.inputs[0])
    nt.links.new(info.outputs["Alpha"], mul.inputs[1])
    nt.links.new(mul.outputs[0], gain.inputs[0])
    nt.links.new(gain.outputs[0], light.inputs["Strength"])
    nt.links.new(clear.outputs[0], add.inputs[0])
    nt.links.new(light.outputs[0], add.inputs[1])
    nt.links.new(add.outputs[0], nt.nodes.get("Material Output").inputs["Surface"])
    square = bpy.data.meshes.new("Bubble")
    square.from_pydata([(-0.5, -0.5, 0), (0.5, -0.5, 0), (0.5, 0.5, 0), (-0.5, 0.5, 0)], [], [(0, 1, 2, 3)])
    uv = square.uv_layers.new(name="UVMap")
    for i, co in enumerate(((0, 0), (1, 0), (1, 1), (0, 1))):
        uv.data[i].uv = co
    square.materials.append(bm_)
    bubbles = []

    def blow(rate):
        for ob in bubbles:
            bpy.data.objects.remove(ob)
        bubbles.clear()
        for place, size, see in (stream(c, emit, rate, 7 + tier) if rate > 0 else []):
            ob = bpy.data.objects.new("Bubble", square)
            ob.location, ob.scale = place, (size, size, size)
            ob.color = (1, 1, 1, 1 - see)
            ob.visible_shadow = False
            scene.collection.objects.link(ob)
            bubbles.append(ob)

    def look_from(ob, source, target):
        ob.location = source
        ob.rotation_euler = (Vector(target) - Vector(source)).to_track_quat("-Z", "Y").to_euler()

    def camera(name_, ortho=None, lens=50, fov=None):
        cam = bpy.data.cameras.new(name_)
        if ortho:
            cam.type, cam.ortho_scale = "ORTHO", ortho
        elif fov:
            cam.sensor_fit = "VERTICAL"  # Roblox's FieldOfView is the picture's height
            cam.angle = math.radians(fov)
        else:
            cam.lens = lens
        cam.clip_start, cam.clip_end = 0.5, 2000
        ob = bpy.data.objects.new(name_, cam)
        scene.collection.objects.link(ob)
        return ob

    world = bpy.data.worlds.new("World")
    world.use_nodes = True
    wt = world.node_tree
    bg = wt.nodes.get("Background")
    bg.inputs["Color"].default_value = rgba((254, 248, 241))
    bg.inputs["Strength"].default_value = 0.6
    water = wt.nodes.new("ShaderNodeBackground")  # what the camera sees behind, when the film is not see-through
    water.inputs["Color"].default_value = rgba(WATER)
    path = wt.nodes.new("ShaderNodeLightPath")
    mix = wt.nodes.new("ShaderNodeMixShader")
    wt.links.new(path.outputs["Is Camera Ray"], mix.inputs[0])
    wt.links.new(bg.outputs[0], mix.inputs[1])
    wt.links.new(water.outputs[0], mix.inputs[2])
    wt.links.new(mix.outputs[0], wt.nodes.get("World Output").inputs["Surface"])
    scene.world = world
    sun_data = bpy.data.lights.new("Key", "SUN")
    sun_data.energy, sun_data.angle = 2.3, math.radians(14)
    sun = bpy.data.objects.new("Key", sun_data)
    scene.collection.objects.link(sun)
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGBA"

    def render(cam, file, w, h, clear_film):
        scene.camera = cam
        scene.render.film_transparent = clear_film
        scene.render.resolution_x, scene.render.resolution_y, scene.render.resolution_percentage = w, h, 100
        scene.render.filepath = os.path.join(out, file)
        bpy.context.view_layer.update()
        for ob in bubbles:
            ob.rotation_euler = cam.rotation_euler
        bpy.ops.render.render(write_still=True)

    # ---- the screw, as the propeller sheet shot its options (no bubbles: the screw is what is compared)
    blow(0)
    behind = camera("Behind", ortho=2.75 * ring)
    look_from(behind, (tx + 80, 0, az), (tx, 0, az))
    rear = camera("Rear", ortho=2.7 * ring)
    look_from(rear, (tx + 66, -50, az + 30), (tx + 0.4, -0.5, az - 0.2))
    look_from(sun, (tx + 9, -11, 11), (tx, 0, az))
    render(behind, "screw_behind.png", 1200, 1200, True)
    render(rear, "screw_rear.png", 1200, 1200, True)
    look_from(sun, (4, -5, 12), (0, 0, 0))
    cams = {}
    for key, (source, target, fov, _) in CAMS.items():
        cams[key] = camera(key, fov=fov)
        look_from(cams[key], source, target)
    render(cams["fast"], "screw_ride.png", 3840, 2160, True)

    # ---- the sub with its trail, on the water's blue
    top = rate_at(c, CAMS["fast"][3])
    blow(top)
    look_from(sun, (-5.0, -7.0, 9.0), (0, 0, 0))
    F = 1.0 + 0.008 * max(0.0, (x_hi - x_lo) - 46)
    whole = camera("Whole", lens=75)
    look_from(whole, (mid + 4 + 70 * 1.46, -59 * 1.46, 38 * 1.46), (mid + 3.5, 0, 1.0))
    whole.data.lens = 75 / max(1.0, (x_hi - x_lo + 12) / 62)
    render(whole, "trail_rear.png", 1400, 1000, False)
    close = camera("Close", ortho=6.4 * ring)
    look_from(close, (tx + 6 + 66, -50, az + 30), (tx + 6, 0, az))
    look_from(sun, (tx + 9, -11, 11), (tx, 0, az))
    render(close, "trail_close.png", 1400, 1000, False)
    look_from(sun, (-5.0, -7.0, 9.0), (0, 0, 0))
    span = (x_hi - x_lo) + 20
    side = camera("Side", ortho=span)
    z_lo, z_hi = min(p.z for p in drawn), max(p.z for p in drawn)
    look_from(side, (mid + 7, -300, (z_lo + z_hi) / 2), (mid + 7, 0, (z_lo + z_hi) / 2))
    render(side, "trail_side.png", 2000, int(2000 * (z_hi - z_lo + 6) / span), False)
    look_from(sun, (4, -5, 12), (0, 0, 0))
    render(cams["fast"], "trail_fast.png", 1920, 1080, False)
    blow(rate_at(c, CAMS["start"][3]))
    render(cams["start"], "trail_start.png", 1920, 1080, False)
    render(cams["drop"], "trail_drop.png", 1920, 1080, False)
    blow(0)

    # ---- the numbers
    bpy.context.view_layer.update()
    dg = bpy.context.evaluated_depsgraph_get()
    t_rider = [BVHTree.FromObject(o, dg) for o in riders]
    t_seat = [BVHTree.FromObject(objects["Seat"], dg)]
    t_rest = [BVHTree.FromObject(o, dg) for k, o in objects.items() if k != "Seat"]
    cloud = stream(c, emit, 1, 99, every=6000)  # every place and size a bubble can have
    stats = {"tier": tier, "id": name, "name": NAMES.get(tier, name), "emit": [round(v, 2) for v in emit],
             "long": round(x_hi - x_lo, 1), "stern": round(x_hi, 2), "top_rate": top,
             "trail_long": round(max(p[0][0] for p in cloud) - emit[0], 1),
             "trail_top": round(max(p[0][2] + RING * p[1] for p in cloud), 2),
             "trail_wide": round(2 * max(abs(p[0][1]) + RING * p[1] for p in cloud), 1), "cams": {}}
    for key, (source, target, fov, speed) in CAMS.items():
        eye = Vector(source)
        f = (Vector(target) - eye).normalized()
        r = f.cross(Vector((0, 0, 1))).normalized()
        u = r.cross(f)
        tan = math.tan(math.radians(fov) / 2)

        def spot(p):
            d = Vector(p) - eye
            return d.dot(r) / d.dot(f), d.dot(u) / d.dot(f), d.dot(f)

        # the rider, by rays (sub_creature_options.py's `seen_from`)
        spots = [spot(ob.matrix_world @ v.co) for ob in riders for v in ob.data.vertices]
        rx0, rx1 = min(q[0] for q in spots), max(q[0] for q in spots)
        ry0, ry1 = min(q[1] for q in spots), max(q[1] for q in spots)

        def first(trees, d):
            best = 1e9
            for t_ in trees:
                hit = t_.ray_cast(eye, d)
                if hit[0] is not None and hit[3] < best:
                    best = hit[3]
            return best

        n, there, seen = 140, 0, 0
        for i in range(n):
            for j in range(n):
                d = (f + r * (rx0 + (rx1 - rx0) * (i + 0.5) / n) + u * (ry0 + (ry1 - ry0) * (j + 0.5) / n)).normalized()
                dr = first(t_rider, d)
                if dr > 1e8:
                    continue
                there += 1
                if dr < first(t_seat, d) and dr < first(t_rest, d):
                    seen += 1
        # the trail in the picture (heights of the picture: 0 its middle, 1 its top edge, -1 its bottom edge)
        gap, big, cover, inside = 1e9, 0.0, 0.0, 0
        ys, xs = [], []
        for place, size, see in cloud:
            x, y, deep = spot(place)
            if deep <= 0.5:
                continue  # level with the camera or behind it
            rad = RING * size / deep
            # how far this ring is from the rider's box in the picture
            gap = min(gap, math.hypot(max(rx0 - x, 0, x - rx1), max(ry0 - y, 0, y - ry1)) - rad)
            sx, sy, sr = x / (tan * ASPECT), y / tan, rad / tan
            if abs(sx) - sr / ASPECT < 1 and abs(sy) - sr < 1:
                inside += 1
                if see < 0.8:  # (a ring's width as a share of the picture's height is its radius in half heights)
                    big = max(big, sr)
                cover += math.pi * sr * sr / (4 * ASPECT) * (1 - see)
                ys.append(sy)
                xs.append(sx)
        alive = rate_at(c, speed) * c["WakeLife"] * 0.975
        stats["cams"][key] = {
            "rider_seen": round(seen / max(1, there), 3),
            "trail_to_rider": round(gap / tan / 2, 3),  # of the picture's height; over 0: no bubble ever crosses the rider
            "in_picture": round(inside / len(cloud), 3), "bubbles": round(alive * inside / len(cloud), 1),
            "rows": [round((1 - max(ys)) / 2, 3), round((1 - min(ys)) / 2, 3)] if ys else None,  # from the top, 0 to 1
            "across": round((max(xs) - min(xs)) / 2, 3) if xs else 0,  # of the picture's width
            "biggest": round(big, 3),  # the biggest ring's width that is not yet four fifths faded, of the picture's height
            "covered": round(cover / max(1, len(cloud)) * alive, 4),  # of the picture, rings counted solid and by their fade
            "screw": [round((1 - spot((tx + 1.0, 0, az + s * (ring - 0.6)))[1] / tan) / 2, 3) for s in (1, -1)],
        }
        row = stats["cams"][key]
        print("trail: tier %d %-5s rider seen %.0f%%; trail %s of the picture's height from the rider; %.0f%% of it in the picture "
              "(%.0f bubbles), rows %s, %.1f%% across, biggest ring %.1f%% of the height, covers %.2f%% of the picture" % (
                  tier, key, 100 * row["rider_seen"], "%.1f%%" % (100 * row["trail_to_rider"]), 100 * row["in_picture"], row["bubbles"],
                  row["rows"], 100 * row["across"], 100 * row["biggest"], 100 * row["covered"]))
    json.dump(stats, open(os.path.join(out, "stats.json"), "w"), indent=1)


# ------------------------------------------------------------------------------------------------ the sheet (Pillow)
def ring_picture(work):
    """Roblox's own bubble ring as a PNG (Studio's content folder; under Vinegar on Linux)"""
    from PIL import Image

    out = os.path.join(work, "ring.png")
    found = os.environ.get("RING_DDS") or next(iter(sorted(
        glob.glob(os.path.expanduser("~/.var/app/org.vinegarhq.Vinegar/data/vinegar/versions/*/content/textures/particles/explosion01_shockwave_main.dds"))
        + glob.glob(os.path.expandvars("$LOCALAPPDATA/Roblox/Versions/*/content/textures/particles/explosion01_shockwave_main.dds")))), None)
    assert found, "explosion01_shockwave_main.dds not found: set RING_DDS to it (Studio's content/textures/particles)"
    Image.open(found).convert("RGBA").save(out)
    return out


def sheet(work, out):
    import sub_props_options as props

    Image, ImageDraw, font = props.pillow()
    from PIL import ImageFilter

    INK, SOFT, CREAM, WELL = (38, 38, 38), (122, 114, 106), (254, 248, 241), (244, 236, 226)
    c = wake_numbers()
    stats = {n: json.load(open(os.path.join(work, "t%d" % n, "stats.json"))) for n in (1, 8, 9)}
    PAD, W = 24, 2160
    old = Image.open(os.path.join(ROOT, "docs", "attachments", "sub-props-options-2026-11-23.png")).convert("RGB")
    # option 4's block on that sheet (its `sheet`: the fifth block of five)
    COL = 688
    ROWS = (("behind", "STRAIGHT BEHIND", COL), ("rear", "THREE-QUARTER REAR", COL),
            ("ride", "FROM THE RIDING CAMERA at 620 studs a second (38 studs behind, 7 up, 88°), cut to the sub", 500))
    BLOCK = 150 + sum(h + 52 for _, _, h in ROWS) + 20
    option4 = old.crop((0, 430 + 4 * (BLOCK + PAD), W, 430 + 4 * (BLOCK + PAD) + BLOCK))

    def tile(name, w):
        im = Image.open(name).convert("RGB")
        return im.resize((w, round(im.height * w / im.width)), Image.LANCZOS)

    SUB = {}
    for n in (8, 9):
        t = os.path.join(work, "t%d" % n)
        half = (W - 3 * PAD - 2 * PAD) // 2
        SUB[n] = dict(rear=tile(os.path.join(t, "trail_rear.png"), half), close=tile(os.path.join(t, "trail_close.png"), half),
                      side=tile(os.path.join(t, "trail_side.png"), W - 4 * PAD), fast=tile(os.path.join(t, "trail_fast.png"), half),
                      start=tile(os.path.join(t, "trail_start.png"), half))
        SUB[n]["h"] = 130 + max(SUB[n]["rear"].height, SUB[n]["close"].height) + 62 + SUB[n]["side"].height + 62 + SUB[n]["fast"].height + 126
    HEAD = 470
    total = HEAD + sum(SUB[n]["h"] + PAD for n in (8, 9)) + 170 + BLOCK + PAD + 110 + BLOCK + PAD + 20
    sh = Image.new("RGB", (W, total), CREAM)
    d = ImageDraw.Draw(sh)
    d.text((PAD + 6, 22), "RIDE A FISH", font=font(34), fill=INK)
    d.text((PAD + 6, 64), "SUBS 8 AND 9, THE SCREW, THE BUBBLE TRAIL", font=font(72), fill=INK)
    d.text((PAD + 6, 152), "2026-11-24, for Hugo's “use 8a, and 9a ... a bubble trail right behind the propeller ... the screw type”", font=font(31), fill=SOFT)
    notes = ["Drawn in Blender from the game's own meshes (art/subs). NOTHING HERE HAS BEEN SEEN IN STUDIO.",
             "The bubbles are drawn from the emitter's numbers (Config.Sub) with Roblox's own bubble ring: a sum, not the game.",
             "They travel with the sub and stream %.0f studs back from the screw's end; %d a second at speed, %d standing." % (
                 c["WakeSpeed"] * c["WakeLife"], c["WakeMost"], c["WakeLeast"]),
             "The blue is a stand-in for the water: the bubbles add light, so they cannot be shown on cream.",
             "The screw (bottom): the game's meshes are option 4 point for point on all nine subs (tools/subs/screw_check.py)."]
    for i, line in enumerate(notes):
        d.text((PAD + 6, 214 + i * 46), line, font=font(30), fill=INK if i == 0 else SOFT)

    def label(x, y, text, size=27):
        d.text((x, y), text, font=font(size), fill=SOFT)

    def put(im, x, y):
        mask = Image.new("L", im.size, 0)
        ImageDraw.Draw(mask).rounded_rectangle((0, 0, im.width - 1, im.height - 1), 18, fill=255)
        sh.paste(im, (x, y), mask)

    y = HEAD
    for n in (8, 9):
        s, st = SUB[n], stats[n]
        d.rounded_rectangle((PAD, y, W - PAD, y + s["h"]), 28, fill=WELL)
        bw = 60 + int(d.textlength(str(n), font=font(70)))
        d.rounded_rectangle((PAD + 22, y + 22, PAD + 22 + bw, y + 116), 20, fill=INK)
        d.text((PAD + 22 + bw // 2, y + 69), str(n), font=font(70), fill=CREAM, anchor="mm")
        d.text((PAD + 46 + bw, y + 16), st["name"].upper(), font=font(58), fill=INK)
        label(PAD + 48 + bw, y + 84, "%s  /  %.0f studs long  /  with the screw and the trail at full speed" % (WAS[n], st["long"]), 29)
        x0, x1 = PAD * 2, PAD * 3 + s["rear"].width
        yy = y + 130
        put(s["rear"], x0, yy)
        put(s["close"], x1, yy)
        yy += max(s["rear"].height, s["close"].height)
        label(x0 + 4, yy + 12, "THREE-QUARTER REAR")
        label(x1 + 4, yy + 12, "THE SCREW AND ITS TRAIL, close (%d bubbles a second)" % st["top_rate"])
        yy += 62
        put(s["side"], x0, yy)
        yy += s["side"].height
        label(x0 + 4, yy + 12, "FROM THE SIDE: the trail is %.0f studs long (its farthest bubble %.0f), its top %.1f studs under the seat's top" % (
            c["WakeSpeed"] * c["WakeLife"], st["trail_long"], 5.7 - st["trail_top"]))
        yy += 62
        put(s["fast"], x0, yy)
        put(s["start"], x1, yy)
        yy += s["fast"].height
        for x, key, text in ((x0, "fast", "THE GAME'S CAMERA AT FULL SPEED (38 behind, 7 up, 88°)"),
                             (x1, "start", "THE GAME'S CAMERA AS A RUN BEGINS (30 behind, 10 up, 70°)")):
            k = st["cams"][key]
            label(x + 4, yy + 10, text)
            if k["in_picture"] < 0.1:
                label(x + 4, yy + 46, "rider seen %d%%  /  the screw's end is at the picture's bottom edge here:" % round(100 * k["rider_seen"]), 23)
                label(x + 4, yy + 76, "the trail runs out under the picture", 23)
            else:
                label(x + 4, yy + 46, "rider seen %d%%, the same as without bubbles  /  %d bubbles in the picture" % (
                    round(100 * k["rider_seen"]), round(k["bubbles"])), 23)
                label(x + 4, yy + 76, "biggest bubble %.1f%% of the screen's height  /  bubbles cover %.1f%% of it" % (
                    100 * k["biggest"], 100 * k["covered"]), 23)
        y += s["h"] + PAD

    d.text((PAD + 6, y + 14), "THE SCREW: THE SHEET HUGO PICKED FROM, THEN THE GAME", font=font(58), fill=INK)
    label(PAD + 8, y + 92, "Above: option 4 as it stands on the propeller sheet (2026-11-23), on tiers 1, 6 and 9 as they were then.", 30)
    label(PAD + 8, y + 130, "Below: the game's meshes now, tiers 1, 8 and 9, same cameras, same light. Tier 9's glow is the kraken's cyan now, not pink.", 30)
    y += 170
    sh.paste(option4, (0, y))
    y += BLOCK + PAD
    d.text((PAD + 6, y + 20), "IN THE GAME'S MESHES NOW", font=font(58), fill=INK)
    y += 110
    d.rounded_rectangle((PAD, y, W - PAD, y + BLOCK), 28, fill=WELL)
    d.rounded_rectangle((PAD + 22, y + 22, PAD + 22 + 104, y + 126), 20, fill=INK)
    d.text((PAD + 22 + 52, y + 74), "4", font=font(70), fill=CREAM, anchor="mm")
    d.text((PAD + 46 + 104, y + 18), "SCREW, AS EXPORTED", font=font(62), fill=INK)
    label(PAD + 48 + 104, y + 90, "132 triangles a sub (144 with the glowing ball's part apart)  /  reaches 3.2 of the ring's 3.7 studs", 29)

    def lay(im, x, yy, w, h, grow=1.0):
        box = im.getchannel("A").point(lambda a: 255 if a > 8 else 0).getbbox()
        if grow != 1.0 and box:
            mx, my = int((box[2] - box[0]) * 0.07), int((box[3] - box[1]) * 0.07)
            im = im.crop((max(0, box[0] - mx), max(0, box[1] - my), min(im.width, box[2] + mx), min(im.height, box[3] + my)))
        kf = min(w / im.width, h / im.height)
        im = im.resize((max(1, int(im.width * kf)), max(1, int(im.height * kf))), Image.LANCZOS)
        at = (x + (w - im.width) // 2, yy + (h - im.height) // 2)
        shade = Image.new("RGBA", im.size, (0, 0, 0, 0))
        shade.putalpha(im.getchannel("A").point(lambda a: a // 5))
        sh.paste((60, 40, 30), (at[0] + 6, at[1] + 10), shade.filter(ImageFilter.GaussianBlur(8)).getchannel("A"))
        sh.paste(im, at, im)

    yy = y + 150
    for view, text, h in ROWS:
        label(PAD + 26, yy + 6, text)
        for col, n in enumerate((1, 8, 9)):
            x = PAD + PAD // 2 + col * (COL + PAD // 2)
            w = COL - PAD // 2
            d.rounded_rectangle((x, yy + 44, x + w, yy + 44 + h), 18, fill=CREAM)
            im = Image.open(os.path.join(work, "t%d" % n, "screw_%s.png" % view)).convert("RGBA")
            if view == "ride":
                lay(im, x + 8, yy + 52, w - 16, h - 16, grow=1.07)
                k = stats[n]["cams"]["fast"]["screw"]
                d.text((x + w - 14, yy + 44 + h - 12), "%d%% of the screen's height at 620" % round(100 * abs(k[1] - k[0])),
                       font=font(25), fill=SOFT, anchor="rd")
            else:
                lay(im, x, yy + 44, w, h)
            tag = "TIER %d  %s" % (n, stats[n]["name"].upper())
            d.rounded_rectangle((x + 12, yy + 56, x + 12 + 30 + int(d.textlength(tag, font=font(24))), yy + 96), 10, fill=INK)
            d.text((x + 27, yy + 62), tag, font=font(24), fill=CREAM)
        yy += h + 52
    os.makedirs(os.path.dirname(os.path.abspath(out)), exist_ok=True)
    sh.save(out, optimize=True)
    print("trail sheet: %s %s, %.1f MB" % (out, sh.size, os.path.getsize(out) / 1e6))


if __name__ == "__main__" and "--" in sys.argv:
    blender_part()
elif __name__ == "__main__" and len(sys.argv) > 3:
    work, out = sys.argv[2], sys.argv[3]
    if sys.argv[1] == "all":
        os.makedirs(work, exist_ok=True)
        ring = ring_picture(work)
        for n in (1, 8, 9):
            subprocess.run([os.environ.get("BLENDER", "blender"), "--background", "--python", os.path.abspath(__file__), "--",
                            str(n), os.path.join(work, "t%d" % n), "--bubble", ring], check=True, stdout=subprocess.DEVNULL)
            print("trail sheet: tier %d drawn" % n)
    sheet(work, out)
