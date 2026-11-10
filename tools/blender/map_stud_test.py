"""Map stud look, test 1 (docs/map-state.md): a piece of the Shallows at the Reef Gate, and a piece of the dock, rebuilt
from the blockout script's own numbers (tools/studio/claude_blockout.luau: the seabed and its two bank tiers, the Reef
Gate, lagoon clusters from art/props) with the grey tiles laid over the parts' colours the way Roblox would do it: a
tile per face, in studs, starting at the face's corner; studs on faces that look up, a material tile on the sides.

usage: blender --background --python tools/blender/map_stud_test.py [-- <out folder>]
writes ride_flat, ride_1, ride_2, ride_4, bank_2 and dock_2 (.png) into art/style/map_tiles/test;
`python tools/art/map_tiles.py --test` lays them out as docs/attachments/map-stud-test.jpg.

Not Roblox: the light, the fog (classic fog to the Shallows' colour, 1,000 studs) and the tile maths are stand-ins.
Everything is written in Roblox axes (y up, the lane runs along +z, the gate stands at z = 0) and turned for Blender."""
import json
import math
import os
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
OUT = os.path.abspath(argv[0]) if argv else os.path.join(ROOT, "art", "style", "map_tiles", "test")
TILE_DIRS = [os.path.join(ROOT, "art", "style", "map_tiles"), os.path.join(ROOT, "art", "style", "tiles")]
PROPS_DIR = os.path.join(ROOT, "art", "props")
KIT = json.load(open(os.path.join(PROPS_DIR, "props.json")))
PROPS = {p["name"]: p for p in KIT["props"]}
CLUSTERS = {c["name"]: c for c in KIT["clusters"]}

# the blockout's numbers for the Shallows (ZONES[1], LAGOON_Y, SIGNATURES.ReefGate)
FLOOR_Y = -38.0
LANE = 260.0
TIERS = [(120.0, 8.0), (200.0, 20.0)]
SAND, ROCK, GATE_ROCK = (236, 222, 172), (214, 196, 150), (150, 140, 120)
FOG, FOG_END = (64, 200, 205), 1000.0
SLAB = 40.0
WATER_LIGHT, SKY, SUN = (120, 185, 185), (150, 205, 240), 2.6  # the Shallows' ambient a little up; the sky over the dock
DOCK_X = 5000.0  # the dock piece stands well away from the Shallows piece

STRENGTH = {"stud": 0.5, "stud_square": 0.5, "strata": 0.4, "plank": 0.5, "deck": 0.5}
controls = []  # (strength node, mapping node, tile name, strength, size): set per render
fades = []  # every material's fog node: the dock is rendered above water, without fog


def lin(c):
    """sRGB 0-255 to Blender's linear colour"""
    out = []
    for v in c:
        v /= 255.0
        out.append(v / 12.92 if v <= 0.04045 else ((v + 0.055) / 1.055) ** 2.4)
    return (*out, 1.0)


def r2b(v):
    """a Roblox point or direction (x, y up, z) in Blender's axes (x, y, z up)"""
    return Vector((v[0], -v[2], v[1]))


_images = {}


def tile_image(name):
    if name not in _images:
        for folder in TILE_DIRS:
            path = os.path.join(folder, name + ".png")
            if os.path.exists(path):
                im = bpy.data.images.load(path)
                im.colorspace_settings.name = "Non-Color"
                _images[name] = im
                break
    return _images[name]


def finish(nt, colour_socket, emission=None):
    """colour -> a matt surface, faded to the water's colour with distance from the camera (Roblox's classic fog)"""
    n, link = nt.nodes, nt.links.new
    if emission is None:
        surf = n.new("ShaderNodeBsdfDiffuse")
        link(colour_socket, surf.inputs["Color"])
    else:
        surf = n.new("ShaderNodeEmission")
        surf.inputs["Strength"].default_value = emission
        link(colour_socket, surf.inputs["Color"])
    cam = n.new("ShaderNodeCameraData")
    fade = n.new("ShaderNodeMath")
    fade.operation, fade.use_clamp = "DIVIDE", True
    fade.inputs[1].default_value = FOG_END
    fades.append(fade)
    link(cam.outputs["View Distance"], fade.inputs[0])
    fog = n.new("ShaderNodeEmission")
    fog.inputs["Color"].default_value = lin(FOG)
    fog.inputs["Strength"].default_value = 1.0
    mix = n.new("ShaderNodeMixShader")
    link(fade.outputs[0], mix.inputs[0])
    link(surf.outputs[0], mix.inputs[1])
    link(fog.outputs[0], mix.inputs[2])
    out = n.new("ShaderNodeOutputMaterial")
    link(mix.outputs[0], out.inputs["Surface"])


def tiled(nt, colour_socket, tile, size, coords):
    """colour x (1 + 2 x strength x (grey - 0.5)): the creature kit's formula. Returns the shaded colour's socket"""
    n, link = nt.nodes, nt.links.new
    mapping = n.new("ShaderNodeMapping")
    mapping.inputs["Scale"].default_value = (1.0 / size, 1.0 / size, 1.0)
    link(coords, mapping.inputs["Vector"])
    tex = n.new("ShaderNodeTexImage")
    tex.image = tile_image(tile)
    link(mapping.outputs[0], tex.inputs["Vector"])
    shade = n.new("ShaderNodeMath")
    shade.operation = "MULTIPLY_ADD"
    link(tex.outputs["Color"], shade.inputs[0])
    strength = STRENGTH[tile]
    shade.inputs[1].default_value, shade.inputs[2].default_value = 2.0 * strength, 1.0 - strength
    controls.append((shade, mapping, tile, strength, size))
    mul = n.new("ShaderNodeVectorMath")
    mul.operation = "SCALE"
    link(colour_socket, mul.inputs[0])
    link(shade.outputs[0], mul.inputs["Scale"])
    return mul.outputs[0]


_mats = {}


def material(colour, tile=None, size=2.0, emission=None):
    key = (colour, tile, size, emission)
    if key in _mats:
        return _mats[key]
    mat = bpy.data.materials.new(f"{tile or 'plain'}_{colour[0]}_{colour[1]}_{colour[2]}")
    mat.use_nodes = True
    nt = mat.node_tree
    nt.nodes.clear()
    rgb = nt.nodes.new("ShaderNodeRGB")
    rgb.outputs[0].default_value = lin(colour)
    socket = rgb.outputs[0]
    if tile:
        uv = nt.nodes.new("ShaderNodeUVMap")
        socket = tiled(nt, socket, tile, size, uv.outputs[0])
    finish(nt, socket, emission)
    _mats[key] = mat
    return mat


def box(name, size, centre, colour, top=None, side=None, rot=None, sizes=None, emission=None):
    """A Roblox Part: size and centre in Roblox axes, rot a 3x3 (Roblox axes) or None. top and side are tile names for
    the face that looks up in the part's own frame and for its four sides (None: plain). Each face's texture runs in
    studs from the face's corner, as a Roblox Texture does; on the sides, up the part is up the tile."""
    rot = rot or Matrix.Identity(3)
    sizes = sizes or {}
    hx, hy, hz = size[0] / 2, size[1] / 2, size[2] / 2
    faces = [  # (the face's corner, its u edge, its v edge, in the part's frame), which material slot
        ((-hx, hy, -hz), (size[0], 0, 0), (0, 0, size[2]), 0),  # top
        ((-hx, -hy, hz), (size[0], 0, 0), (0, 0, -size[2]), 2),  # bottom
        ((-hx, -hy, hz), (size[0], 0, 0), (0, size[1], 0), 1),  # +z
        ((hx, -hy, -hz), (-size[0], 0, 0), (0, size[1], 0), 1),  # -z
        ((hx, -hy, hz), (0, 0, -size[2]), (0, size[1], 0), 1),  # +x
        ((-hx, -hy, -hz), (0, 0, size[2]), (0, size[1], 0), 1),  # -x
    ]
    bm = bmesh.new()
    uv_layer = bm.loops.layers.uv.new("UVMap")
    for corner, u, v, slot in faces:
        corner, u, v = Vector(corner), Vector(u), Vector(v)
        quad = [(corner, (0, 0)), (corner + u, (u.length, 0)), (corner + u + v, (u.length, v.length)), (corner + v, (0, v.length))]
        verts = [bm.verts.new(r2b(rot @ p + Vector(centre))) for p, _ in quad]
        face = bm.faces.new(verts)
        face.material_index = slot
        for loop, (_, st) in zip(face.loops, quad):
            loop[uv_layer].uv = st
    bm.normal_update()
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    mesh.materials.append(material(colour, top, sizes.get(top, 2.0), emission))
    mesh.materials.append(material(colour, side, sizes.get(side, 2.0), emission))
    mesh.materials.append(material(colour, None, 2.0, emission))
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    return obj


def yaw(deg):
    return Matrix.Rotation(math.radians(deg), 3, "Y")


def roll(deg):
    return Matrix.Rotation(math.radians(deg), 3, "Z")


def bank_height(d):
    x0, h0 = LANE / 2, 0.0
    if d <= x0:
        return 0.0
    for width, height in TIERS:
        if d <= x0 + width:
            return h0 + (height - h0) * (d - x0) / width
        x0, h0 = x0 + width, height
    return h0


SIZES = {"stud": 2.0, "stud_square": 2.0, "strata": 8.0, "plank": 4.0, "deck": 4.0}


# ---------------------------------------------------------------- the Shallows piece
def seabed(z0, z1):
    """one segment of the script's seabed(): the lane's sand, and a tilted slab per bank tier either side"""
    mid, length = (z0 + z1) / 2, z1 - z0
    box("Seabed", (LANE + 8, 6, length), (0, FLOOR_Y - 3, mid), SAND, "stud", None, sizes=SIZES)
    x0, h0 = LANE / 2, 0.0
    for k, (width, height) in enumerate(TIERS):
        x1 = x0 + width
        colour = tuple(round(c + (255 - c) * k * 0.08) for c in ROCK)
        run = math.hypot(width, height - h0)
        tilt = math.degrees(math.atan2(height - h0, width))
        for side in (-1, 1):
            rot = roll(side * tilt)
            centre = Vector((side * (x0 + x1) / 2, FLOOR_Y + (h0 + height) / 2, mid)) - rot @ Vector((0, SLAB / 2, 0))
            box(f"Bank{k + 1}", (run + 2, SLAB, length), centre, colour, "stud", "strata", rot, SIZES)
        x0, h0 = x1, height


def reef_gate():
    """SIGNATURES.ReefGate at z = 0: two sea stacks breaking the surface, and the arch whose span hangs 2 studs over it"""
    half, c = LANE / 2, FLOOR_Y
    for k, side in enumerate((-1, 1)):
        x = side * (half + 30)
        h = 22 - c
        box("Stack", (58, h + 10, 50), (x, c - 5 + (h + 10) / 2, 0), GATE_ROCK, "stud", "strata", yaw(12 - 30 * k) @ roll(2 * side), SIZES)
        box("Top", (40, 16, 36), (x, 26, 0), GATE_ROCK, "stud", "strata", yaw(-20 + 35 * k) @ roll(-4 * side), SIZES)
    span, height, thick = half * 2 + 60, 2 - c, 14.0
    top_y = c + height + thick
    for side in (-1, 1):
        g = c + bank_height(span / 2)
        h = top_y - g + 12
        box("Leg", (thick * 1.4, h, thick * 1.15), (side * span / 2, g - 12 + h / 2, 0), GATE_ROCK, "stud", "strata", roll(side * 3), SIZES)
        box("Shoulder", (thick * 1.2,) * 3, (side * (span / 2 - thick * 0.3), c + height - thick * 0.05, 0), GATE_ROCK, "stud", "strata", roll(45), SIZES)
    box("Span", (span + thick * 1.4, thick, thick * 1.15), (0, c + height + thick / 2, 0), GATE_ROCK, "stud", "strata", None, SIZES)


_prop_meshes = {}


def prop_mesh(name):
    """a prop's mesh from its FBX, once: turned and scaled into Blender's axes, its base at the origin"""
    if name in _prop_meshes:
        return _prop_meshes[name]
    before = set(bpy.data.objects)
    bpy.ops.import_scene.fbx(filepath=os.path.join(PROPS_DIR, PROPS[name]["file"]))
    made = [o for o in bpy.data.objects if o not in before and o.type == "MESH"]
    bpy.ops.object.select_all(action="DESELECT")
    for o in made:
        o.select_set(True)
    bpy.context.view_layer.objects.active = made[0]
    if len(made) > 1:
        bpy.ops.object.join()
    obj = bpy.context.view_layer.objects.active
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    want = PROPS[name]["sizeStuds"]
    factor = want["y"] / max(obj.dimensions.z, 1e-6)
    if abs(factor - 1) > 0.02:
        obj.data.transform(Matrix.Scale(factor, 4))
    mesh = obj.data
    for mat in mesh.materials:  # its palette colours, with studs on whatever looks straight up, and the same fog
        nt = mat.node_tree
        image = next((nd.image for nd in nt.nodes if nd.type == "TEX_IMAGE"), None)
        nt.nodes.clear()
        if image:
            tex = nt.nodes.new("ShaderNodeTexImage")
            tex.image, tex.interpolation = image, "Closest"
            socket = tex.outputs["Color"]
        else:
            rgb = nt.nodes.new("ShaderNodeRGB")
            rgb.outputs[0].default_value = lin((200, 200, 200))
            socket = rgb.outputs[0]
        if name.startswith("rock") or name.startswith("crate"):
            geo = nt.nodes.new("ShaderNodeNewGeometry")
            sep = nt.nodes.new("ShaderNodeSeparateXYZ")
            nt.links.new(geo.outputs["Normal"], sep.inputs[0])
            up = nt.nodes.new("ShaderNodeMath")
            up.operation = "GREATER_THAN"
            up.inputs[1].default_value = 0.97
            nt.links.new(sep.outputs["Z"], up.inputs[0])
            studded = tiled(nt, socket, "stud_square" if name.startswith("crate") else "stud", 2.0, geo.outputs["Position"])
            mix = nt.nodes.new("ShaderNodeMix")
            mix.data_type = "RGBA"
            nt.links.new(up.outputs[0], mix.inputs[0])
            nt.links.new(socket, mix.inputs[6])
            nt.links.new(studded, mix.inputs[7])
            socket = mix.outputs[2]
        finish(nt, socket)
    bpy.context.collection.objects.unlink(obj)
    _prop_meshes[name] = mesh
    return mesh


def place_prop(name, at, turn_deg, scale):
    obj = bpy.data.objects.new(name, prop_mesh(name))
    obj.matrix_world = Matrix.Translation(r2b(at)) @ Matrix.Rotation(math.radians(turn_deg), 4, "Z") @ Matrix.Scale(scale, 4)
    bpy.context.collection.objects.link(obj)


def cluster(name, x, z, scale, jitter=0.0, floor=None):
    """the script's laneCluster() and cluster(): the preset's pieces from the cluster's point on the bank, its front
    turned to the lane, each piece set on the slope under it"""
    side = -1 if x < 0 else 1
    base_turn = side * 90 + jitter
    turn = yaw(base_turn)
    for piece in CLUSTERS[name]["pieces"]:
        row = PROPS[piece["prop"]]
        s = piece["scale"] * scale
        offset = turn @ Vector((piece["pos"]["x"] * scale, 0, piece["pos"]["z"] * scale))
        wx, wz = x + offset.x, z + offset.z
        y = floor if floor is not None else FLOOR_Y + bank_height(abs(wx))
        steep = 0.0 if floor is not None else abs(bank_height(abs(wx) + 3) - bank_height(abs(wx) - 3)) / 6
        sink = steep * max(row["sizeStuds"]["x"], row["sizeStuds"]["z"]) * s * 0.5 - piece["pos"]["y"] * scale + row["sizeStuds"]["y"] * s * 0.04
        place_prop(piece["prop"], (wx, y - sink, wz), base_turn + piece["yawDeg"], s)


def stand_in_fish(at):
    """a block fish and its rider, for scale only (not a creature model): 13 studs long, cubes of 0.45, studs on top
    at one to a cube, as the creatures have them"""
    orange, cream, dark = (245, 130, 42), (250, 236, 200), (40, 44, 60)
    sizes = {"stud": 0.45}
    x, y, z = at
    box("FishBody", (3.15, 3.6, 8.1), (x, y, z), orange, "stud", None, sizes=sizes)
    box("FishBelly", (2.7, 0.9, 7.2), (x, y - 2.0, z), cream, None, None)
    box("FishHead", (2.7, 2.7, 2.25), (x, y - 0.2, z + 4.9), orange, "stud", None, sizes=sizes)
    box("FishTailStock", (1.8, 2.25, 2.25), (x, y, z - 5.0), orange, "stud", None, sizes=sizes)
    box("FishTail", (0.9, 3.6, 1.8), (x, y, z - 6.8), (205, 100, 30), None, None)
    box("FishFin", (0.9, 1.8, 2.7), (x, y + 2.6, z - 0.5), dark, None, None)
    for side in (-1, 1):
        box("FishEye", (0.2, 0.9, 0.9), (x + side * 1.4, y + 0.3, z + 5.2), dark, None, None)
    box("RiderLegs", (2.0, 2.0, 1.0), (x, y + 2.8, z + 1.2), (60, 90, 160), None, None)
    box("RiderBody", (2.0, 2.0, 1.0), (x, y + 4.8, z + 1.2), (90, 170, 230), None, None)
    box("RiderHead", (1.2, 1.2, 1.2), (x, y + 6.4, z + 1.2), (245, 205, 150), None, None)


def shallows():
    for z0 in range(-450, 450, 150):
        seabed(z0, z0 + 150)
    reef_gate()
    # lineLane(): a huge cluster either side of the landmark, then medium and small ones alternating sides
    cluster("cluster_lagoon_huge", -(LANE / 2 + 45), -35, 1.8, 8)
    cluster("cluster_lagoon_huge", LANE / 2 + 45, 35, 1.7, -10)
    cluster("cluster_lagoon_medium", LANE / 2 + 22 * 1.7, -215, 1.7, 6)
    cluster("cluster_lagoon_small", -(LANE / 2 + 12 * 1.6), -330, 1.6, -12)
    cluster("cluster_lagoon_small", LANE / 2 + TIERS[0][0] * 0.85, -170, 1.9, 14)
    cluster("cluster_lagoon_medium", -(LANE / 2 + 22 * 1.6), 250, 1.6, 0)
    stand_in_fish((6, FLOOR_Y + 12, -248))
    # the sea's surface from below, and a far wall of water colour so nothing ends in black
    box("Surface", (2400, 1, 2400), (0, 0.5, 0), (150, 235, 232), None, None, emission=1.0).visible_shadow = False


# ---------------------------------------------------------------- the dock piece
def dock():
    """a stretch of buildDock(): the deck (2 thick, its top at y = 4) on stilts down to the lagoon floor, the island's
    sand behind it, a board out over the water, and dock props from the kit"""
    x = DOCK_X
    deck, stilt, sand = (170, 128, 85), (110, 80, 55), (240, 226, 178)
    box("DockDeck", (140, 2, 70), (x, 3, 15), deck, "deck", "plank", sizes=SIZES)
    box("Island", (140, 6, 80), (x, 0, -60), sand, "stud", None, sizes=SIZES)
    box("Plaza", (60, 1, 40), (x - 20, 3.5, -40), (160, 120, 80), "deck", "plank", sizes=SIZES)
    for px_ in range(-60, 61, 58):
        for z in (18, 47):
            box("Stilt", (3, 43, 3), (x + px_, 4 - 21.5, z), stilt, None, "plank", sizes=SIZES)
    box("DiveBoard", (10, 1.5, 24), (x, 4.75, 60), (245, 245, 245), "stud_square", None, sizes=SIZES)
    box("LagoonFloor", (600, 4, 600), (x, -41, 150), SAND, "stud", None, sizes=SIZES)
    box("Sea", (900, 1, 900), (x, -0.5, 250), (70, 190, 215), None, None)
    place_prop("crate_stack", (x - 40, 4, 30), 20, 1.3)
    place_prop("crate", (x - 28, 4, 38), -15, 1.2)
    place_prop("barrel", (x + 32, 4, 34), 0, 1.4)
    place_prop("dock_post", (x + 44, 4, 46), 0, 1.3)
    place_prop("rope_coil", (x + 24, 4, 42), 40, 1.4)
    box("Figure", (2, 5, 1), (x + 8, 6.5, 30), (90, 170, 230), None, None)


# ---------------------------------------------------------------- the scene, the light, the cameras
def scene_setup():
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
    world = bpy.data.worlds.new("Water")
    world.use_nodes = True
    bg = world.node_tree.nodes["Background"]
    bg.inputs["Color"].default_value = lin(WATER_LIGHT)
    bg.inputs["Strength"].default_value = 1.0
    scene.world = world
    sun = bpy.data.objects.new("Sun", bpy.data.lights.new("Sun", "SUN"))
    sun.data.energy, sun.data.angle = SUN, math.radians(4)
    sun.rotation_euler = (math.radians(38), math.radians(-12), math.radians(25))
    scene.collection.objects.link(sun)
    return scene


def camera(scene, name, eye, target, fov=70.0):
    cam = bpy.data.objects.new(name, bpy.data.cameras.new(name))
    cam.data.sensor_fit = "VERTICAL"
    cam.data.angle_y = math.radians(fov)  # Roblox's FieldOfView is the vertical angle
    cam.data.clip_start, cam.data.clip_end = 0.5, 4000
    eye_b, target_b = r2b(eye), r2b(target)
    cam.location = eye_b
    cam.rotation_euler = (target_b - eye_b).to_track_quat("-Z", "Y").to_euler()
    scene.collection.objects.link(cam)
    return cam


def render(scene, cam, name, floor_stud=2.0, flat=False, above=False):
    for fade in fades:
        fade.inputs[1].default_value = 1e9 if above else FOG_END
    scene.world.node_tree.nodes["Background"].inputs["Color"].default_value = lin(SKY if above else WATER_LIGHT)
    for shade, mapping, tile, strength, size in controls:
        k = 0.0 if flat else strength
        shade.inputs[1].default_value, shade.inputs[2].default_value = 2.0 * k, 1.0 - k
        s = floor_stud if (tile == "stud" and size == 2.0) else size  # only the map's round stud changes size
        mapping.inputs["Scale"].default_value = (1.0 / s, 1.0 / s, 1.0)
    scene.camera = cam
    scene.render.filepath = os.path.join(OUT, name + ".png")
    bpy.ops.render.render(write_still=True)
    print("rendered", scene.render.filepath)


scene = scene_setup()
os.makedirs(OUT, exist_ok=True)
shallows()
dock()
ride = camera(scene, "Ride", (20, FLOOR_Y + 25, -278), (0, FLOOR_Y + 8, -200))
bank = camera(scene, "Bank", (-78, FLOOR_Y + 17, -92), (-160, FLOOR_Y + 6, -8), fov=60)
quay = camera(scene, "Dock", (DOCK_X + 44, 24, 84), (DOCK_X - 6, 2, 24), fov=55)
only = argv[1].split(",") if len(argv) > 1 else None
for cam, name, stud, flat in ((ride, "ride_flat", 2.0, True), (ride, "ride_2", 2.0, False), (ride, "ride_1", 1.0, False),
                              (ride, "ride_4", 4.0, False), (bank, "bank_2", 2.0, False), (quay, "dock_2", 2.0, False)):
    if only is None or name in only:
        render(scene, cam, name, stud, flat, above=cam is quay)
