"""Fish kit (the creature method, docs/style/creature-method.md): builds a blocky, faceted fish from a spec JSON as a chain of
rigid segments along the spine (each turning at its front joint, like a Motor6D chain in Roblox, so every fish swims the same
way), with the long fins cut at the same joints, a jointed tail fin, square eyes and a lip block, in 3 or 4 flat colour areas.

usage: blender --background --python tools/blender/fish_kit.py -- <spec.json> <out folder> [--swim] [--joints sleeve|flat] [--wire]
  default: renders the turnaround views (transparent, for tools/art/creature_sheet.py) and a riding view in shallow water with a
           5-stud rider for scale, as the riding camera sees it
  --wire:  also a head close-up (head.png) and the same with every mesh edge drawn in red (head_wire.png, front_wire.png), to
           check the topology
  --swim:  renders a looping swim cycle (3/4 and top views) into <out>/swim_<joints>/ for tools/art/swim_gif.py
  --voxel S: every part turned into cubes S studs across, for the voxel style test (use with --joints flat)
  --joints sleeve (default when the spec has "sleeve"): each segment carries a short inset sleeve forward into the one in front,
           so a bending joint shows body, not a gap; flat: plain cut joints
Units are studs. The head points to -X; the snout sits at x = -length/2. The shared pieces (materials, mesh helpers, the
views every creature is judged in) are in kit_common.py, which the shell and disc plans use too.
"""
import json
import math
import os
import sys

import bmesh
import bpy
from mathutils import Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import kit_common as kc  # noqa: E402
from kit_common import box_bm, clip_half, clip_x, plate_bm, ray_exit  # noqa: E402

argv = sys.argv[sys.argv.index("--") + 1 :]
SPEC = json.load(open(argv[0]))
OUT = os.path.abspath(argv[1])
SWIM = "--swim" in argv
WIRE = "--wire" in argv
VOXEL = float(argv[argv.index("--voxel") + 1]) if "--voxel" in argv else None  # cubes of this size (workout 4)
JOINTS = argv[argv.index("--joints") + 1] if "--joints" in argv else ("sleeve" if SPEC.get("sleeve") else "flat")

L = SPEC["length"]
ST = SPEC["stations"]
CH, CV = SPEC["chamfer"]  # the top corners: fraction of the half width, fraction of the height
CHB, CVB = SPEC.get("chamferBottom", SPEC["chamfer"])  # the bottom corners
TOPLINE = SPEC["topLine"]
TOPLINE_Z = SPEC.get("topLineZ")  # where the top colour ends: one height along the whole fish, or "chamfer" (with the top chamfers)
PANEL = SPEC.get("facePanel")  # the face: a flat panel at t = 0, the head's planes run back from its edges
MAT_NAMES = ["top", "body", "bars", "fins", "eye", "pupil", "lips", "spine"]


# ---------------------------------------------------------------- the body's shape
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
    if TOPLINE_Z == "chamfer":  # the top colour ends with the top chamfers: that point doubles the chamfer's, welded later
        zs = top - cv
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

    # the mouth is pushed out of the face, one mesh with it (the user, 2026-11-09). The face gets a line across at the mouth's
    # top and one at its bottom, running edge to edge, and the mouth takes the face's whole width there: its back corners are
    # the points where those lines meet the face's edges, shared with the eye faces. Its sides follow the eye faces' angle
    # (sideFollow 1: flush on the eye faces' planes, 0: straight back), so the front comes out narrower than the back.
    m = SPEC["lips"]
    mzt, mzb = m["z"] + m["size"][2] / 2, m["z"] - m["size"][2] / 2
    follow = m.get("sideFollow", 1.0)
    FT, FB, slope = g["FT"], g["FB"], g["slope"]

    def edge_at(z):
        """the face's right edge (where it meets the eye face) at height z"""
        return FT + (FB - FT) * ((FT.z - z) / (FT.z - FB.z))

    if HEAD.get("faceFold"):  # the face folds at the mouth: the face above and the chin below lean back from the mouth's back
        xf = xat(0.0)
        P, Q = Vector((xf, g["wall_y"](xf), mzt)), Vector((xf, g["wall_y"](xf), mzb))
        x_front = xf - m["protrude"]
    else:  # one face plane, the mouth's back corners on its edges
        P, Q = edge_at(mzt), edge_at(mzb)
        x_front = face_x(m["z"]) - m["protrude"]
    # the front can be smaller than the back (a snout tapering to its end)
    fz, fh = m.get("frontZ", m["z"]), m.get("frontHeight", m["size"][2])
    pts = {
        "P": P, "Q": Q,  # the mouth's back corners: top, bottom
        "MF": Vector((x_front, P.y - follow * slope * (P.x - x_front), fz + fh / 2)),  # its front corners, the sides angled in
        "MG": Vector((x_front, Q.y - follow * slope * (Q.x - x_front), fz - fh / 2)),
    }
    if not (FB.z < mzb < mzt < FT.z and min(pts["MF"].y, pts["MG"].y) > 0.1):
        raise ValueError("the mouth must sit inside the face (between its top and the jaw line) and stay wider than its angle")
    slit = m.get("slit")
    if slit:  # a dark band across the front, pushed in: the front gets a frame of four faces round it
        sw = slit.get("width", 0.8) * min(pts["MF"].y, pts["MG"].y)
        s1, s0 = fz + slit["height"] / 2, fz - slit["height"] / 2

        def front_edge(z):
            """the front's right edge at height z"""
            return pts["MG"] + (pts["MF"] - pts["MG"]) * ((z - pts["MG"].z) / (pts["MF"].z - pts["MG"].z))

        pts.update({
            "R1": front_edge(s1), "R0": front_edge(s0),  # the frame's corners on the front's edges
            "S1": Vector((x_front, sw, s1)), "S0": Vector((x_front, sw, s0)),  # the slit's corners
            "D1": Vector((x_front + slit["inset"], sw, s1)), "D0": Vector((x_front + slit["inset"], sw, s0)),  # pushed in
        })
    for name, p in pts.items():
        v[name + "r"] = bm.verts.new((p.x, p.y, p.z))
        v[name + "l"] = bm.verts.new((p.x, -p.y, p.z))
    fc = HEAD.get("faceColour", "body")
    face([v["FTl"], v["FTr"], v["Pr"], v["Pl"]], fc)  # the face, down to the mouth
    face([v["Ql"], v["Qr"], v["FBr"], v["FBl"]], fc)  # under the mouth, down to the jaw line
    face([v["Pl"], v["Pr"], v["MFr"], v["MFl"]], "lips")  # the mouth: top, bottom
    face([v["Ql"], v["MGl"], v["MGr"], v["Qr"]], "lips")
    if slit:
        sc = slit.get("colour", "pupil")
        face([v["MFl"], v["MFr"], v["R1r"], v["S1r"], v["S1l"], v["R1l"]], "lips")  # the frame round the slit
        face([v["R0l"], v["S0l"], v["S0r"], v["R0r"], v["MGr"], v["MGl"]], "lips")
        face([v["R1l"], v["S1l"], v["S0l"], v["R0l"]], "lips")
        face([v["S1r"], v["R1r"], v["R0r"], v["S0r"]], "lips")
        face([v["D1l"], v["D1r"], v["D0r"], v["D0l"]], sc)  # the slit: its back, then its four walls
        face([v["S1l"], v["S1r"], v["D1r"], v["D1l"]], sc)
        face([v["S0l"], v["D0l"], v["D0r"], v["S0r"]], sc)
        face([v["S1l"], v["D1l"], v["D0l"], v["S0l"]], sc)
        face([v["S1r"], v["S0r"], v["D0r"], v["D1r"]], sc)
        face([v["Pr"], v["Qr"], v["MGr"], v["R0r"], v["R1r"], v["MFr"]], "lips")  # the sides, the frame's corners on them
        face([v["Pl"], v["MFl"], v["R1l"], v["R0l"], v["MGl"], v["Ql"]], "lips")
    else:
        face([v["MFl"], v["MFr"], v["MGr"], v["MGl"]], "lips")  # the front, then the sides
        face([v["Pr"], v["Qr"], v["MGr"], v["MFr"]], "lips")
        face([v["Pl"], v["MFl"], v["MGl"], v["Ql"]], "lips")
    face([v["FTl"], B[0], B[1], v["FTr"]], "top")  # the forehead
    face([v["FTr"], B[1], B[2]], "top")  # the corner facets
    face([v["FTl"], B[9], B[0]], "top")
    face([v["FTr"], B[2], B[3], B[4], v["FBr"], v["Qr"], v["Pr"]], "body")  # the eye faces: flat, grey, the mouth's corners
    face([v["FTl"], v["Pl"], v["Ql"], v["FBl"], B[7], B[8], B[9]], "body")  # on their front edges
    face([v["FBl"], v["FBr"], v["JBr"], v["JBl"]], "body")  # the chin
    face([v["JBl"], v["JBr"], B[5], B[6]], "body")
    face([v["FBr"], B[4], v["JBr"]], "body")  # the jaw, split by the diagonal from the eye face's back corner
    face([B[4], B[5], v["JBr"]], "body")
    face([v["FBl"], v["JBl"], B[7]], "body")
    face([B[7], v["JBl"], B[6]], "body")
    cap(bm, B, cuts[1], 0.0)


# ---------------------------------------------------------------- the scene (kit_common)
K = kc.Kit(SPEC, OUT, MAT_NAMES, 32 if SWIM else 64)
scene, MATS, fish, WORLD = K.scene, K.mats, K.collection, K.world_pos
new_object, mesh_object, attach = K.new_object, K.mesh_object, K.attach


# ---------------------------------------------------------------- the body: a chain of rigid segments
cuts = [0.0] + SPEC["segments"] + [1.0]
ts = {s[0] for s in ST} | set(cuts)
for b0, b1 in SPEC.get("bars", []):
    ts |= {b0, b1}
SPINE = SPEC.get("spine")  # a spine pushed out of each flank (the tang's "scalpel"): rings at its ends
if SPINE:
    ts |= set(SPINE["t"])
ts = sorted(ts)
sleeve_t = SPEC.get("sleeve", 0.0) / L if JOINTS == "sleeve" else 0.0


def spine_verts(bm, seg_ts, rings):
    """the spine's corners on the flank (F) and pushed out (E), top (1) and bottom (0), per side and ring"""
    js = [j for j, t in enumerate(seg_ts) if SPINE["t"][0] - 1e-9 <= t <= SPINE["t"][1] + 1e-9]
    z1, z0 = SPINE["z"] + SPINE["height"] / 2, SPINE["z"] - SPINE["height"] / 2
    sp = {"first": js[0], "last": js[-1]}
    for j in js:
        flank_top, flank_bottom = rings[j][3].co, rings[j][4].co
        if not (flank_bottom.z < z0 and z1 < flank_top.z):
            raise ValueError("the spine must sit on the flank, between the top and bottom chamfers")
        for sgn in (1, -1):
            for key, y, z in (("F1", 0.0, z1), ("F0", 0.0, z0), ("E1", SPINE["proud"], z1), ("E0", SPINE["proud"], z0)):
                sp[(key, sgn, j)] = bm.verts.new((flank_top.x, sgn * (flank_top.y + y), z))
    return sp


def flank_faces(bm, sp, sgn, r, T_r, B_r, T_r1, B_r1, colour):
    """one flank quad between rings r and r+1 (top and bottom corners), split round the spine where it stands"""
    first, last = sp["first"], sp["last"]

    def F(key, j):
        return sp[(key, sgn, j)]

    if first <= r and r + 1 <= last:  # where it stands: the flank above and below, the spine's face, top and bottom
        faces = [
            ((T_r, F("F1", r), F("F1", r + 1), T_r1), colour),
            ((F("F0", r), B_r, B_r1, F("F0", r + 1)), colour),
            ((F("E1", r), F("E0", r), F("E0", r + 1), F("E1", r + 1)), "spine"),
            ((F("F1", r), F("E1", r), F("E1", r + 1), F("F1", r + 1)), "spine"),
            ((F("E0", r), F("F0", r), F("F0", r + 1), F("E0", r + 1)), "spine"),
        ]
        if r == first:
            faces.append(((F("F1", r), F("F0", r), F("E0", r), F("E1", r)), "spine"))  # its front end
        if r + 1 == last:
            faces.append(((F("F1", r + 1), F("E1", r + 1), F("E0", r + 1), F("F0", r + 1)), "spine"))  # its back end
    elif r + 1 == first:  # just in front: the spine's corners sit on this face's back edge
        faces = [((T_r, B_r, B_r1, F("F0", r + 1), F("F1", r + 1), T_r1), colour)]
    elif r == last:  # just behind: on its front edge
        faces = [((T_r, F("F1", r), F("F0", r), B_r, B_r1, T_r1), colour)]
    else:
        faces = [((T_r, B_r, B_r1, T_r1), colour)]
    for verts, c in faces:
        f = bm.faces.new(verts)
        f.material_index = MAT_NAMES.index(c)

segments = []
for i, (s0, s1) in enumerate(zip(cuts, cuts[1:])):
    seg_ts = [t for t in ts if s0 - 1e-9 <= t <= s1 + 1e-9]
    bm = bmesh.new()
    if i == 0 and HEAD:
        build_head(bm)
        bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-4)  # weld ring points that coincide (a top line on the chamfer)
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        segments.append(mesh_object("Seg0", bm, (xat(s1), 0.0, 0.0), MAT_NAMES))
        continue
    rings = [[bm.verts.new(p) for p in ring(t)] for t in seg_ts]
    sp = None
    if SPINE and s0 + 1e-9 < SPINE["t"][0] and SPINE["t"][1] < s1 - 1e-9:  # the spine stands inside this segment
        sp = spine_verts(bm, seg_ts, rings)
    for r in range(len(rings) - 1):
        bar = in_bar(seg_ts[r], seg_ts[r + 1])
        for k in range(10):
            k2 = (k + 1) % 10
            quad = (rings[r][k], rings[r][k2], rings[r + 1][k2], rings[r + 1][k])
            if sp and k == 3:  # the right flank: top, bottom at ring r, bottom, top at r+1
                flank_faces(bm, sp, 1, r, quad[0], quad[1], quad[3], quad[2], face_colour(REGION[k], bar))
                continue
            if sp and k == 7:  # the left flank: bottom, top at ring r, top, bottom at r+1
                flank_faces(bm, sp, -1, r, quad[1], quad[0], quad[2], quad[3], face_colour(REGION[k], bar))
                continue
            f = bm.faces.new(quad)
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
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-4)  # weld ring points that coincide (a top line on the chamfer)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    pivot = (xat(cuts[1]) if i == 0 else xat(s0), 0.0, 0.0)  # the head turns at the first joint, the rest at their front
    segments.append(mesh_object(f"Seg{i}", bm, pivot, MAT_NAMES))


def segment_index(t):
    for i, (s0, s1) in enumerate(zip(cuts, cuts[1:])):
        if s0 <= t <= s1:
            return i
    return len(segments) - 1


# ---------------------------------------------------------------- fins, eyes, lips
F = SPEC["fins"]


def split_fin(name, pts, thickness):
    """a long fin cut at the segment joints, each piece riding its own segment"""
    for i, (s0, s1) in enumerate(zip(cuts, cuts[1:])):
        piece = clip_x(clip_x(pts, xat(s0), True), xat(s1), False)
        if len(piece) >= 3 and max(p[0] for p in piece) - min(p[0] for p in piece) > 0.05:
            ob = mesh_object(f"{name}{i}", plate_bm(piece, thickness), WORLD[segments[i].name], ["fins"])
            attach(ob, segments[i])


def slat_fin(name, pts, thickness, slats, base_z, down):
    """a fin of separate ray slats (the Yellow Tang's comb): each segment's share of the fin's base is split into whole slats
    about `spacing` apart, cut by lines leaning back `lean` degrees with `gap` between neighbours, so a joint always falls in a
    gap and each slat rides its segment whole"""
    lean = math.radians(slats["lean"])
    sn, cs = math.sin(lean), math.cos(lean)
    back = (cs, sn) if down else (cs, -sn)  # across a cut line, toward the tail (the line leans back away from the body)
    fx0, fx1 = min(p[0] for p in pts), max(p[0] for p in pts)
    gap = slats["gap"]
    for i, (s0, s1) in enumerate(zip(cuts, cuts[1:])):
        a, b = max(xat(s0), fx0), min(xat(s1), fx1)
        if b - a < 0.3 * slats["spacing"]:
            continue
        count = max(1, round((b - a) / slats["spacing"]))
        width = (b - a) / count
        for k in range(count):
            x0, x1 = a + k * width, a + (k + 1) * width
            if slats.get("stepped"):  # a leaning parallelogram, its flat top at the fin's height through its middle
                b0 = x0 + gap / 2 if x0 > fx0 + 1e-6 else x0
                b1 = x1 - gap / 2 if x1 < fx1 - 1e-6 else x1
                d = (sn, -cs) if down else (sn, cs)  # along the slat, away from the body
                reach = ray_exit(pts, ((b0 + b1) / 2, base_z((b0 + b1) / 2)), d)
                sink = 0.3 if down else -0.3  # the base sits inside the body
                piece = [(b0, base_z(b0) + sink), (b1, base_z(b1) + sink),
                         (b1 + d[0] * reach, base_z(b1) + d[1] * reach), (b0 + d[0] * reach, base_z(b0) + d[1] * reach)]
            else:  # cut from the fin's outline
                piece = pts
                if x0 > fx0 + 1e-6:  # cut the front (the fin's own leading edge stays)
                    piece = clip_half(piece, (x0 + gap / 2, base_z(x0 + gap / 2)), back)
                if x1 < fx1 - 1e-6:  # cut the back (the fin's own trailing edge stays)
                    piece = clip_half(piece, (x1 - gap / 2, base_z(x1 - gap / 2)), (-back[0], -back[1]))
            if len(piece) >= 3:
                ob = mesh_object(f"{name}{i}_{k}", plate_bm(piece, thickness), WORLD[segments[i].name], ["fins"])
                attach(ob, segments[i])


def t_at(x):
    return (x + L / 2) / L


for name, side, down in (("Dorsal", 0, False), ("Anal", 1, True)):
    fin_spec = F[name.lower()]
    outline = [(xat(t), profile(t)[side] + dz) for t, dz in fin_spec["points"]]
    if fin_spec.get("slats"):
        slat_fin(name, outline, fin_spec["thickness"], fin_spec["slats"], lambda x, side=side: profile(t_at(x))[side], down)
    else:
        split_fin(name, outline, fin_spec["thickness"])
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
    q = F.get("pelvic")
    if q:  # a pair of pelvic fins, when the fish has them
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
    if e.get("socket", True):  # the cream square with a black square in it; socket false: one plain square, the eye colour
        pupil = mesh_object(f"Pupil{s:+d}", box_bm((e["pupil"], e.get("pupilThickness", 0.08), e["pupil"])), (0.0, 0.0, 0.0), ["pupil"])
        pupil.location = (0.0 if (e.get("onFace") or e.get("onWall")) else -0.08, s * e.get("pupilOut", 0.1), 0.0)
        pupil.parent = eye
    attach(eye, segments[0])

if not HEAD:  # a head built from planes has its mouth in the head mesh; the older faces get a separate lip block
    if "protrude" in SPEC["lips"]:
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


# ---------------------------------------------------------------- the views (kit_common)
if VOXEL:
    print("fish kit: voxel triangles", K.voxelize(VOXEL))
K.studio()
front_x = xat(0.0) - (SPEC["lips"].get("protrude", 0.0) if (PANEL or HEAD) else (FACE["depth"] if FACE else 0.25)) - 0.3
mid_x = (front_x + xat(1.0) + max(dx for dx, _ in F["tail"]["points"])) / 2

if SWIM:  # a looping swim: one wave down the chain, the head countering
    sw = SPEC.get("swim", {"amplitudes": [3, 6, 9, 12, 18], "phaseStep": 0.9, "headCounter": 2})

    def pose(phase):
        segments[0].rotation_euler.z = math.radians(sw["headCounter"]) * math.sin(phase + math.pi)
        for k, ob in enumerate(JOINT_CHAIN):
            ob.rotation_euler.z = math.radians(sw["amplitudes"][k]) * math.sin(phase - sw["phaseStep"] * (k + 1))

    folder = os.path.join(OUT, f"swim_{JOINTS}")
    K.swim(folder, 24, pose, mid_x)
    print("fish kit: swim", folder)
    sys.exit(0)

K.turnaround(front_x, mid_x)
if WIRE:
    K.wire(front_x)
seat_t = SPEC.get("seat", 0.23)
K.ride(xat(seat_t), profile(seat_t)[0], profile(seat_t)[2])
print("fish kit: done", OUT)
