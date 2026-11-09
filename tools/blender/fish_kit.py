"""Fish kit (the creature method, docs/style/creature-method.md): builds a blocky, faceted fish from a spec JSON as a chain of
rigid segments along the spine (each turning at its front joint, like a Motor6D chain in Roblox, so every fish swims the same
way), with the long fins cut at the same joints, a jointed tail fin, square eyes and a lip block, in 3 or 4 flat colour areas.

usage: blender --background --python tools/blender/fish_kit.py -- <spec.json> <out folder> [--swim] [--joints sleeve|flat]
  default: renders the turnaround views (transparent, for tools/art/creature_sheet.py) and a riding view in shallow water with a
           5-stud rider for scale, as the riding camera sees it
  --swim:  renders a looping swim cycle (3/4 and top views) into <out>/swim_<joints>/ for tools/art/swim_gif.py
  --joints sleeve (default when the spec has "sleeve"): each segment carries a short inset sleeve forward into the one in front,
           so a bending joint shows body, not a gap; flat: plain cut joints
Units are studs. The head points to -X; the snout sits at x = -length/2.
"""
import json
import math
import os
import sys

import bmesh
import bpy
from mathutils import Vector

argv = sys.argv[sys.argv.index("--") + 1 :]
SPEC = json.load(open(argv[0]))
OUT = os.path.abspath(argv[1])
SWIM = "--swim" in argv
JOINTS = argv[argv.index("--joints") + 1] if "--joints" in argv else ("sleeve" if SPEC.get("sleeve") else "flat")
os.makedirs(OUT, exist_ok=True)

L = SPEC["length"]
ST = SPEC["stations"]
CH, CV = SPEC["chamfer"]  # the top corners: fraction of the half width, fraction of the height
CHB, CVB = SPEC.get("chamferBottom", SPEC["chamfer"])  # the bottom corners
TOPLINE = SPEC["topLine"]
TOPLINE_Z = SPEC.get("topLineZ")  # where the top colour ends: one height along the whole fish, or "chamfer" (with the top chamfers)
PANEL = SPEC.get("facePanel")  # the face: a flat panel at t = 0, the head's planes run back from its edges
MAT_NAMES = ["top", "body", "bars", "fins", "eye", "pupil", "lips"]


# ---------------------------------------------------------------- helpers
def srgb_to_linear(c):
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def hex_rgba(h):
    h = h.lstrip("#")
    return tuple(srgb_to_linear(int(h[i : i + 2], 16) / 255) for i in (0, 2, 4)) + (1.0,)


def material(name, hex_colour, roughness=0.7):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    bsdf = m.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = hex_rgba(hex_colour)
    bsdf.inputs["Roughness"].default_value = roughness
    if "Specular IOR Level" in bsdf.inputs:
        bsdf.inputs["Specular IOR Level"].default_value = 0.2
    return m


def profile(t):
    """top, bottom, half width of the body at t (0 snout, 1 tail base), straight between stations: the facets."""
    if t <= ST[0][0]:
        return ST[0][1:4]
    for a, b in zip(ST, ST[1:]):
        if a[0] <= t <= b[0]:
            f = (t - a[0]) / (b[0] - a[0])
            return [a[i] + (b[i] - a[i]) * f for i in (1, 2, 3)]
    return ST[-1][1:4]


def xat(t):
    return -L / 2 + t * L


# a ring of 10 points round the body: an octagon with two extra points on each side where the top colour ends
REGION = ["top", "top", "top", "side", "low", "bottom", "low", "side", "top", "top"]


def ring(t, inset=1.0):
    if PANEL and t <= 1e-9:  # the face panel: a rectangle, its points placed where the head's planes meet it
        w, zt, zb, inner = PANEL["halfWidth"], PANEL["top"], PANEL["bottom"], PANEL["inner"]
        pts = [(-inner, zt), (inner, zt), (w, zt), (w, zt - 0.04), (w, zb), (inner, zb), (-inner, zb), (-w, zb), (-w, zt - 0.04), (-w, zt)]
        return [(xat(0.0), y, z) for y, z in pts]
    top, bot, a = profile(t)
    h = top - bot
    ch, cv = CH * a, CV * h
    chb, cvb = CHB * a, CVB * h
    if TOPLINE_Z == "chamfer":  # the top colour ends with the top chamfers (a hair under, so the ring keeps all 10 points)
        zs = top - cv - 0.03
    elif TOPLINE_Z is not None:
        zs = min(max(TOPLINE_Z, bot + cvb + 0.05), top - cv - 0.05)
    else:
        zs = top - TOPLINE * h
    mid = (top + bot) / 2
    pts = [
        (-a + ch, top), (a - ch, top), (a, top - cv), (a, zs), (a, bot + cvb),
        (a - chb, bot), (-a + chb, bot), (-a, bot + cvb), (-a, zs), (-a, top - cv),
    ]
    return [(xat(t), y * inset, mid + (z - mid) * inset) for y, z in pts]


def in_bar(t0, t1):
    tm = (t0 + t1) / 2
    return any(b0 <= tm <= b1 for b0, b1 in SPEC.get("bars", []))


def face_colour(region, bar):
    if region == "bottom":
        return "body"
    if bar:
        return "bars"
    return "top" if region == "top" else "body"


FACE = SPEC.get("face")


def face_ring():
    """the face panel's outline: the head ring at t = 0, shrunk about its middle and moved forward by the face's depth"""
    top, bot, _ = profile(0.0)
    mid = (top + bot) / 2
    iw, ih = FACE["inset"]
    reach = FACE.get("reach", [1.0] * 10)  # how far each point comes forward: under 1 slopes the chin back
    return [(x - FACE["depth"] * reach[k], y * iw, mid + (z - mid) * ih) for k, (x, y, z) in enumerate(ring(0.0))]


def cap(bm, ring_verts, t, bulge):
    """close a ring with a fan coloured like the faces round it (so an opening joint shows the same colours)"""
    top, bot, _ = profile(t)
    centre = bm.verts.new((xat(t) + bulge, 0.0, (top + bot) / 2))
    bar = in_bar(t, t)
    for k in range(10):
        f = bm.faces.new((ring_verts[(k + 1) % 10], ring_verts[k], centre))
        f.material_index = MAT_NAMES.index(face_colour(REGION[k], bar))


HEAD = SPEC.get("head")


def head_geometry():
    """The head's corner points (right side; the left mirrors in y), built the way the concept builds it (the user's drawing,
    2026-11-09). From the front: a face plane narrowing to the jaw, and either side one big eye face running from the face's
    edge out to the head's outline, grey up to its slanted top edge, with a yellow corner facet above it. Below: a chin, and a
    jaw split by a diagonal. The eye face is the vertical plane through the face's top corner and the body ring's side at the
    first joint, so the face's bottom corner is put on it: its half width follows from how far the face leans."""
    xf = xat(0.0)
    back = ring(cuts[1])  # the head is the first segment: it meets the body ring at the first joint
    bx, by = back[2][0], back[2][1]
    ftd, ftw, zt = HEAD["faceTop"]
    fbd, zb = HEAD["faceBottom"]
    jbd, jbw, jz = HEAD["chin"]
    FT = Vector((xf + ftd, ftw, zt))
    slope = (by - ftw) / (bx - FT.x)

    def wall_y(x):
        return ftw + (x - FT.x) * slope

    FB = Vector((xf + fbd, wall_y(xf + fbd), zb))
    JB = Vector((xf + jbd, jbw, jz))
    return {"FT": FT, "FB": FB, "JB": JB, "slope": slope, "wall_y": wall_y, "back": back}


def face_x(z):
    """where the face plane is at height z (it leans back toward the top)"""
    ftd, _, zt = HEAD["faceTop"]
    fbd, zb = HEAD["faceBottom"]
    return xat(0.0) + fbd + (ftd - fbd) * (z - zb) / (zt - zb)


def build_head(bm):
    g = head_geometry()
    B = [bm.verts.new(p) for p in g["back"]]
    v = {}
    for name in ("FT", "FB", "JB"):
        p = g[name]
        v[name + "r"] = bm.verts.new((p.x, p.y, p.z))
        v[name + "l"] = bm.verts.new((p.x, -p.y, p.z))

    def face(verts, colour):
        f = bm.faces.new(verts)
        f.material_index = MAT_NAMES.index(colour)

    face([v["FTl"], v["FTr"], v["FBr"], v["FBl"]], HEAD.get("faceColour", "body"))  # the face
    face([v["FTl"], B[0], B[1], v["FTr"]], "top")  # the forehead
    face([v["FTr"], B[1], B[2]], "top")  # the corner facets
    face([v["FTl"], B[9], B[0]], "top")
    face([v["FTr"], B[2], B[3], B[4], v["FBr"]], "body")  # the eye faces: one flat face each, grey all over
    face([v["FTl"], v["FBl"], B[7], B[8], B[9]], "body")
    face([v["FBl"], v["FBr"], v["JBr"], v["JBl"]], "body")  # the chin
    face([v["JBl"], v["JBr"], B[5], B[6]], "body")
    face([v["FBr"], B[4], v["JBr"]], "body")  # the jaw, split by the diagonal from the eye face's back corner
    face([B[4], B[5], v["JBr"]], "body")
    face([v["FBl"], v["JBl"], B[7]], "body")
    face([B[7], v["JBl"], B[6]], "body")
    cap(bm, B, cuts[1], 0.0)


def clip_x(pts, x, keep_greater):
    """Sutherland-Hodgman against the line x = const"""
    out = []
    for i in range(len(pts)):
        cur, prev = pts[i], pts[i - 1]
        cin = cur[0] >= x if keep_greater else cur[0] <= x
        pin = prev[0] >= x if keep_greater else prev[0] <= x
        if cin != pin:
            f = (x - prev[0]) / (cur[0] - prev[0])
            out.append((x, prev[1] + f * (cur[1] - prev[1])))
        if cin:
            out.append(cur)
    return out


# ---------------------------------------------------------------- scene
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
    scene.eevee.taa_render_samples = 32 if SWIM else 64
except AttributeError:
    pass

MATS = {name: material(name, SPEC["colours"][name]) for name in MAT_NAMES}
fish = bpy.data.collections.new("Fish")
scene.collection.children.link(fish)
WORLD = {}  # each object's pivot in world space, before parenting


def new_object(name, me=None):
    ob = bpy.data.objects.new(name, me)
    fish.objects.link(ob)
    return ob


def mesh_object(name, bm, origin, mats):
    """a mesh object whose pivot is at origin; bm is in world space"""
    for v in bm.verts:
        v.co -= Vector(origin)
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    for m in mats:
        me.materials.append(MATS[m])
    for poly in me.polygons:
        poly.use_smooth = False
    ob = new_object(name, me)
    ob.location = origin
    WORLD[name] = Vector(origin)
    return ob


def attach(child, parent):
    """parent without moving: the child's location becomes relative to the parent's pivot (nothing is rotated yet)"""
    world = WORLD.get(child.name, Vector(child.location))
    child.parent = parent
    child.location = world - WORLD[parent.name]


# ---------------------------------------------------------------- the body: a chain of rigid segments
cuts = [0.0] + SPEC["segments"] + [1.0]
ts = {s[0] for s in ST} | set(cuts)
for b0, b1 in SPEC.get("bars", []):
    ts |= {b0, b1}
ts = sorted(ts)
sleeve_t = SPEC.get("sleeve", 0.0) / L if JOINTS == "sleeve" else 0.0

segments = []
for i, (s0, s1) in enumerate(zip(cuts, cuts[1:])):
    seg_ts = [t for t in ts if s0 - 1e-9 <= t <= s1 + 1e-9]
    bm = bmesh.new()
    if i == 0 and HEAD:
        build_head(bm)
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        segments.append(mesh_object("Seg0", bm, (xat(s1), 0.0, 0.0), MAT_NAMES))
        continue
    rings = [[bm.verts.new(p) for p in ring(t)] for t in seg_ts]
    for r in range(len(rings) - 1):
        bar = in_bar(seg_ts[r], seg_ts[r + 1])
        for k in range(10):
            k2 = (k + 1) % 10
            f = bm.faces.new((rings[r][k], rings[r][k2], rings[r + 1][k2], rings[r + 1][k]))
            f.material_index = MAT_NAMES.index(face_colour(REGION[k], bar))
    if s0 == 0.0 and PANEL:  # the face panel closes the front: flat, pale, the head's planes already run back from it
        f = bm.faces.new(rings[0])
        f.material_index = MAT_NAMES.index(PANEL.get("colour", "body"))
    elif s0 == 0.0 and FACE:  # the face: the head bevels in to a flat panel, like a chamfered block
        d = FACE["depth"]
        front = [bm.verts.new(p) for p in face_ring()]
        for k in range(10):
            k2 = (k + 1) % 10
            f = bm.faces.new((front[k], front[k2], rings[0][k2], rings[0][k]))
            f.material_index = MAT_NAMES.index(face_colour(REGION[k], False))
        for quad in ((0, 1, 2, 9), (9, 2, 3, 8), (8, 3, 4, 7), (7, 4, 5, 6)):  # flat bands, top to chin
            f = bm.faces.new([front[q] for q in quad])
            f.material_index = MAT_NAMES.index(FACE.get("panel", "body"))
    elif s0 == 0.0:  # the snout: a low point, coloured like the ring it closes
        top, bot, _ = profile(0.0)
        tip = bm.verts.new((xat(0.0) - 0.25, 0.0, (top + bot) / 2 - 0.1))
        for k in range(10):
            f = bm.faces.new((rings[0][(k + 1) % 10], rings[0][k], tip))
            f.material_index = MAT_NAMES.index(face_colour(REGION[k], False))
    else:
        cap(bm, rings[0], s0, 0.0)
        if sleeve_t:  # a short inset tube reaching forward into the segment in front, so a bending joint shows body
            front = [bm.verts.new(p) for p in ring(max(s0 - sleeve_t, 0.0), 0.93)]
            back = [bm.verts.new(p) for p in ring(s0 + 0.01, 0.93)]
            for k in range(10):
                k2 = (k + 1) % 10
                f = bm.faces.new((front[k], front[k2], back[k2], back[k]))
                f.material_index = MAT_NAMES.index(face_colour(REGION[k], in_bar(s0 - sleeve_t, s0)))
    cap(bm, rings[-1], s1, 0.0)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    pivot = (xat(cuts[1]) if i == 0 else xat(s0), 0.0, 0.0)  # the head turns at the first joint, the rest at their front
    segments.append(mesh_object(f"Seg{i}", bm, pivot, MAT_NAMES))


def segment_index(t):
    for i, (s0, s1) in enumerate(zip(cuts, cuts[1:])):
        if s0 <= t <= s1:
            return i
    return len(segments) - 1


# ---------------------------------------------------------------- fins, eyes, lips
def plate_bm(pts, thickness):
    """a flat plate: the polygon pts (x, z) extruded along Y"""
    bm = bmesh.new()
    h = thickness / 2
    a = [bm.verts.new((x, -h, z)) for x, z in pts]
    b = [bm.verts.new((x, h, z)) for x, z in pts]
    bm.faces.new(a)
    bm.faces.new(b[::-1])
    for i in range(len(pts)):
        j = (i + 1) % len(pts)
        bm.faces.new((a[i], b[i], b[j], a[j]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return bm


def box_bm(size):
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    for v in bm.verts:
        v.co = Vector((v.co.x * size[0], v.co.y * size[1], v.co.z * size[2]))
    return bm


F = SPEC["fins"]


def split_fin(name, pts, thickness):
    """a long fin cut at the segment joints, each piece riding its own segment"""
    for i, (s0, s1) in enumerate(zip(cuts, cuts[1:])):
        piece = clip_x(clip_x(pts, xat(s0), True), xat(s1), False)
        if len(piece) >= 3 and max(p[0] for p in piece) - min(p[0] for p in piece) > 0.05:
            ob = mesh_object(f"{name}{i}", plate_bm(piece, thickness), WORLD[segments[i].name], ["fins"])
            attach(ob, segments[i])


split_fin("Dorsal", [(xat(t), profile(t)[0] + dz) for t, dz in F["dorsal"]["points"]], F["dorsal"]["thickness"])
split_fin("Anal", [(xat(t), profile(t)[1] + dz) for t, dz in F["anal"]["points"]], F["anal"]["thickness"])
tail = mesh_object(
    "Tail",
    plate_bm([(xat(1.0) + dx, z) for dx, z in F["tail"]["points"]], F["tail"]["thickness"]),
    (xat(1.0) - 0.1, 0.0, 0.0),
    ["fins"],
)

for s in (-1, 1):
    p = F["pectoral"]
    origin = (xat(p["t"]), s * (profile(p["t"])[2] + 0.05), p["z"])
    fin = mesh_object(f"Pectoral{s:+d}", plate_bm(p["points"], p["thickness"]), (0.0, 0.0, 0.0), ["fins"])
    fin.location = origin
    WORLD[fin.name] = Vector(origin)
    fin.rotation_euler = (0.0, math.radians(-p["tilt"]), s * math.radians(p["yaw"]))
    attach(fin, segments[segment_index(p["t"])])
    q = F["pelvic"]
    origin = (xat(q["t"]), s * q["y"], profile(q["t"])[1] + q["zAboveBottom"])
    fin = mesh_object(f"Pelvic{s:+d}", plate_bm(q["points"], q["thickness"]), (0.0, 0.0, 0.0), ["fins"])
    fin.location = origin
    WORLD[fin.name] = Vector(origin)
    fin.rotation_euler = (s * math.radians(q["roll"]), 0.0, s * math.radians(q["yaw"]))
    attach(fin, segments[segment_index(q["t"])])

    # the eye: a square plate flush with the side of the head, a square pupil looking a little forward
    e = SPEC["eye"]
    eye = new_object(f"Eye{s:+d}")
    if HEAD and e.get("onWall"):
        g = head_geometry()
        x = xat(0.0) + e["dx"]
        yaw = math.atan(g["slope"])
        out = e.get("thickness", 0.14) / 2 - 0.03  # sit on the wall, sunk a little
        eye.location = (x - out * math.sin(yaw), s * (g["wall_y"](x) + out * math.cos(yaw)), e["z"])
        eye.rotation_euler = (0.0, 0.0, s * yaw)
    elif FACE and e.get("onFace"):
        a = profile(0.0)[2]
        a_front = a * FACE["inset"][0]
        d = FACE["depth"]
        beta = math.atan2(a - a_front, d)  # how far the corner facet turns to face forward
        eye.location = (xat(0.0) - d / 2 - 0.04 * math.sin(beta), s * ((a + a_front) / 2 + 0.04 * math.cos(beta)), e["z"])
        eye.rotation_euler = (0.0, 0.0, s * beta)
    else:
        t = e["t"]
        slope = (profile(t + 0.01)[2] - profile(t - 0.01)[2]) / (0.02 * L)
        eye.location = (xat(t), s * (profile(t)[2] + 0.04), e["z"])
        eye.rotation_euler = (0.0, 0.0, s * (math.atan(slope) + math.radians(e.get("turn", 0.0))))
    WORLD[eye.name] = Vector(eye.location)
    socket = mesh_object(f"EyeSocket{s:+d}", box_bm((e["size"], e.get("thickness", 0.14), e["size"])), (0.0, 0.0, 0.0), ["eye"])
    socket.parent = eye
    pupil = mesh_object(f"Pupil{s:+d}", box_bm((e["pupil"], e.get("pupilThickness", 0.08), e["pupil"])), (0.0, 0.0, 0.0), ["pupil"])
    pupil.location = (0.0 if (e.get("onFace") or e.get("onWall")) else -0.08, s * e.get("pupilOut", 0.1), 0.0)
    pupil.parent = eye
    attach(eye, segments[0])

if HEAD:
    lips_x = face_x(SPEC["lips"]["z"]) - SPEC["lips"]["protrude"] + SPEC["lips"]["size"][0] / 2
elif "protrude" in SPEC["lips"]:
    lips_x = xat(0.0) - SPEC["lips"]["protrude"] + SPEC["lips"]["size"][0] / 2
else:
    lips_x = xat(0.0) - (FACE["depth"] if FACE else 0.0) - SPEC["lips"]["size"][0] / 2 + SPEC["lips"].get("sink", 0.05)
lips = mesh_object("Lips", box_bm(SPEC["lips"]["size"]), (0.0, 0.0, 0.0), ["lips"])  # a local box: placed after
lips.location = (lips_x, 0.0, SPEC["lips"]["z"])
WORLD[lips.name] = Vector(lips.location)
attach(lips, segments[0])

# the chain: each segment hangs off the one in front, the tail fin off the last
for i in range(1, len(segments)):
    attach(segments[i], segments[i - 1])
attach(tail, segments[-1])
JOINT_CHAIN = segments[1:] + [tail]


# ---------------------------------------------------------------- views and lights
def look_from(ob, source, target):
    d = Vector(target) - Vector(source)
    ob.location = source
    ob.rotation_euler = d.to_track_quat("-Z", "Y").to_euler()


def camera(name, ortho=None, lens=50):
    cam = bpy.data.cameras.new(name)
    if ortho:
        cam.type = "ORTHO"
        cam.ortho_scale = ortho
    else:
        cam.lens = lens
    ob = bpy.data.objects.new(name, cam)
    scene.collection.objects.link(ob)
    return ob


def world(hex_colour, strength):
    w = bpy.data.worlds.new("World")
    w.use_nodes = True
    bg = w.node_tree.nodes.get("Background")
    bg.inputs["Color"].default_value = hex_rgba(hex_colour)
    bg.inputs["Strength"].default_value = strength
    scene.world = w
    return w


def render(cam, path, w, h):
    scene.camera = cam
    scene.render.resolution_x = w
    scene.render.resolution_y = h
    scene.render.filepath = path
    bpy.ops.render.render(write_still=True)


world("#FEF8F1", 0.55)
sun_data = bpy.data.lights.new("Key", "SUN")
sun_data.energy = 2.2
sun_data.angle = math.radians(14)
sun = bpy.data.objects.new("Key", sun_data)
scene.collection.objects.link(sun)
look_from(sun, (-5.0, -7.0, 9.0), (0.0, 0.0, 0.0))
scene.render.image_settings.file_format = "PNG"
front_x = xat(0.0) - (SPEC["lips"].get("protrude", 0.0) if (PANEL or HEAD) else (FACE["depth"] if FACE else 0.25)) - 0.3
mid_x = (front_x + xat(1.0) + max(dx for dx, _ in F["tail"]["points"])) / 2


# ---------------------------------------------------------------- the swim cycle
if SWIM:
    sw = SPEC.get("swim", {"amplitudes": [3, 6, 9, 12, 18], "phaseStep": 0.9, "headCounter": 2})
    frames = 24
    scene.render.film_transparent = True
    scene.render.image_settings.color_mode = "RGBA"
    folder = os.path.join(OUT, f"swim_{JOINTS}")
    os.makedirs(folder, exist_ok=True)
    hero = camera("Hero", lens=46)  # wide enough for the whole fish, face to tail
    look_from(hero, (mid_x - 10.5, -14.5, 4.4), (mid_x + 0.3, 0.0, 0.2))
    top = camera("Top", ortho=12.4)
    top.location = (mid_x, 0.0, 30.0)
    rider_cam = camera("Ride")
    rider_cam.data.sensor_fit = "VERTICAL"
    rider_cam.data.angle_y = math.radians(70)
    look_from(rider_cam, (mid_x + 16.0, 3.0, 8.0), (mid_x - 6.0, 0.0, 0.5))
    for f in range(frames):
        phase = 2 * math.pi * f / frames
        segments[0].rotation_euler.z = math.radians(sw["headCounter"]) * math.sin(phase + math.pi)
        for k, ob in enumerate(JOINT_CHAIN):
            ob.rotation_euler.z = math.radians(sw["amplitudes"][k]) * math.sin(phase - sw["phaseStep"] * (k + 1))
        for name, cam, size in (("hero", hero, (560, 410)), ("top", top, (560, 260)), ("ride", rider_cam, (560, 410))):
            render(cam, os.path.join(folder, f"{name}_{f:03d}.png"), *size)
    print("fish kit: swim", folder)
    sys.exit(0)


# ---------------------------------------------------------------- the turnaround views
scene.render.film_transparent = True
scene.render.image_settings.color_mode = "RGBA"
hero = camera("Hero", lens=75)  # a long lens from further off, so the 3/4 view doesn't bulge
look_from(hero, (mid_x - 19.5, -22.5, 7.0), (mid_x + 0.3, 0.0, 0.1))
render(hero, os.path.join(OUT, "hero.png"), 1100, 800)
side = camera("Side", ortho=SPEC.get("orthoSide", 14.5))
look_from(side, (mid_x, -30.0, 0.5), (mid_x, 0.0, 0.5))
render(side, os.path.join(OUT, "side.png"), 900, 560)
front = camera("Front", lens=85)  # a perspective front view like the concept's: the body behind the face shrinks away
look_from(front, (front_x - 30.0, 0.0, 3.2), (front_x + 2.0, 0.0, 0.2))
look_from(sun, (-10.0, -1.5, 8.0), (0.0, 0.0, 0.0))  # lit from in front and above, like the concept's front view, so the face's planes read
render(front, os.path.join(OUT, "front.png"), 560, 560)
look_from(sun, (-5.0, -7.0, 9.0), (0.0, 0.0, 0.0))
top = camera("Top", ortho=SPEC.get("orthoSide", 14.5))
top.location = (mid_x, 0.0, 30.0)
render(top, os.path.join(OUT, "top.png"), 900, 420)


# ---------------------------------------------------------------- the riding view: shallow water, a rider, a few more
def solid(name, size, hex_colour, location, rotation=(0.0, 0.0, 0.0)):
    me = bpy.data.meshes.new(name)
    bm = box_bm(size)
    bm.to_mesh(me)
    bm.free()
    me.materials.append(material(name, hex_colour))
    ob = bpy.data.objects.new(name, me)
    scene.collection.objects.link(ob)
    ob.location = location
    ob.rotation_euler = rotation
    return ob


def blob(name, radius, hex_colour, location, squash=0.8):
    me = bpy.data.meshes.new(name)
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=1, radius=radius)
    bm.to_mesh(me)
    bm.free()
    me.materials.append(material(name, hex_colour))
    ob = bpy.data.objects.new(name, me)
    scene.collection.objects.link(ob)
    ob.location = location
    ob.scale = (1.0, 1.0, squash)
    return ob


def add_fog(m, fog_hex, fog_end):
    """Roblox-style linear fog: the surface fades to the fog colour by its distance from the camera, gone at fog_end"""
    nt = m.node_tree
    out = nt.nodes.get("Material Output")
    surface = out.inputs["Surface"].links[0].from_socket
    cam = nt.nodes.new("ShaderNodeCameraData")
    ramp = nt.nodes.new("ShaderNodeMath")
    ramp.operation = "DIVIDE"
    ramp.use_clamp = True
    ramp.inputs[1].default_value = fog_end
    nt.links.new(cam.outputs["View Distance"], ramp.inputs[0])
    glow = nt.nodes.new("ShaderNodeEmission")
    glow.inputs["Color"].default_value = hex_rgba(fog_hex)
    mix = nt.nodes.new("ShaderNodeMixShader")
    nt.links.new(ramp.outputs[0], mix.inputs["Fac"])
    nt.links.new(surface, mix.inputs[1])
    nt.links.new(glow.outputs["Emission"], mix.inputs[2])
    nt.links.new(mix.outputs["Shader"], out.inputs["Surface"])


scene.render.film_transparent = False
fog = SPEC.get("rideFog", "#3CBED2")
world(fog, 1.0)
look_from(sun, (-3.0, 2.0, 10.0), (0.0, 0.0, 0.0))
sun_data.energy = 3.0

floor_z = -7.0
solid("Sand", (600.0, 600.0, 1.0), "#E9DCB0", (0.0, 0.0, floor_z - 0.5))
for i, (x, y, r, c) in enumerate(
    [(-30, -14, 3.0, "#FF7A8C"), (-46, 10, 4.0, "#FFAA50"), (-62, -6, 3.5, "#B46EE6"), (-20, 16, 2.5, "#5ADCC8"),
     (-80, 18, 5.0, "#FF7A8C"), (-12, -22, 3.0, "#B46EE6"), (-95, -16, 4.5, "#FFAA50")]
):
    blob(f"Coral{i}", r, c, (x, y, floor_z + r * 0.4))

# the rider: a 5-stud block figure sitting on the shoulders, in front of the dorsal fin
seat_t = SPEC.get("seat", 0.23)
seat_x, seat_top, seat_hw = xat(seat_t), profile(seat_t)[0], profile(seat_t)[2]
solid("RiderTorso", (1.0, 2.0, 2.0), "#3C78D8", (seat_x, 0.0, seat_top + 1.3))
solid("RiderHead", (1.2, 1.2, 1.2), "#F2C9A0", (seat_x, 0.0, seat_top + 2.9))
for s in (-1, 1):
    solid(f"RiderLeg{s:+d}", (1.0, 1.0, 2.0), "#2B2B33", (seat_x, s * (seat_hw + 0.35), seat_top - 0.4), (s * math.radians(12), 0.0, 0.0))
    solid(f"RiderArm{s:+d}", (1.6, 0.8, 0.8), "#3C78D8", (seat_x - 0.9, s * 1.25, seat_top + 1.6), (0.0, math.radians(25), 0.0))

# more of the same fish nearby, a Tiny and a Big one: the size variants
for name, scale, loc, yaw in (("Tiny", 0.55, (-16.0, -7.0, 0.5), 8), ("Big", 1.35, (-34.0, 9.0, 3.0), -6)):
    inst = bpy.data.objects.new(name, None)
    inst.instance_type = "COLLECTION"
    inst.instance_collection = fish
    inst.location = loc
    inst.scale = (scale, scale, scale)
    inst.rotation_euler = (0.0, 0.0, math.radians(yaw))
    scene.collection.objects.link(inst)

for m in bpy.data.materials:
    add_fog(m, fog, SPEC.get("rideFogEnd", 900.0))

ride = camera("Ride")
ride.data.sensor_fit = "VERTICAL"
ride.data.angle_y = math.radians(70)  # Roblox's default field of view
look_from(ride, (14.0, 3.0, 6.5), (-6.0, 0.0, 1.0))
render(ride, os.path.join(OUT, "ride.png"), 1280, 720)
print("fish kit: done", OUT)
