"""Disc kit (the disc body plan of docs/style/03-creature-set.md; the Stingray in docs/style/creatures/Stingray.md): builds a
ray from a spec JSON as rigid parts, each a mesh object whose pivot is its joint (one MeshPart and one Motor6D each in Roblox):

  Root            invisible: the creature's position (the camera follows it while the Body bobs)
  Body            the ridge with its plateau (the saddle), the head sloping to the snout with the eye mounds pushed out of
                  it, the hips and the belly
  WingR1..3, L1..3  each wing in hinged pieces cut parallel to the spine, each riding the one inside it, the pivot on the top
                  surface so the top folds and a joint opens only underneath (a cream web fills that)
  Tail1..4        a thin chain of diamond pieces tapering to a needle, the barb pushed out of the ridge of the second, each
                  carrying a sleeve forward into the piece in front

usage: blender --background --python tools/blender/disc_kit.py -- <spec.json> <out folder> [--swim] [--wire] [--checks <folder>]
  default:  the turnaround views (transparent, for tools/art/creature_sheet.py) and the riding view with a 5-stud rider on the
            plateau
  --wire:   also the kit's head close-up and front view with every mesh edge in red, plus the 3/4, top and underside views
            the same way (hero_wire.png, top_wire.png, under_wire.png)
  --swim:   the looping swim into <out>/swim_flap/ for tools/art/swim_gif.py: the wing beat (flap root to tip, each piece
            feathering as it rises), the bob and bank, and the tail swaying at half the rate; the loop holds two beats so the
            tail's sway loops too. With the spec's `hero`, the 3/4 panel uses that camera and the riding panel the riding
            view's camera with the rider on the plateau
  --checks: close-ups of the wing joints at four moments of the beat (the leading edge, the trailing edge, the top, the
            underside) into the folder given
The spec's `hero` ({"from": [x, y, z] from mid_x, scaled by `frame`; "lens"; "light"}) re-renders the 3/4 view at the concept's
angle: kit_common's sits low, which suits a fish but shows a flat creature mostly edge-on.
Units are studs. The ray points to -X, up is +Z, its right side is +Y. The spec's lengths are in S, the span (wing tip to wing
tip, `span` studs), as measured on the concept: u back from the snout, v out from the spine, w up from the belly's bottom. The
world origin is the seat (the plateau's middle) at the height of the ridge's foot: the Root's and the Body's pivot.

The hinged plate piece (plate_piece with its web, and hinge_pose) is the part meant to be shared: rays, mantas, turtles' and
plesiosaurs' flippers (docs/style/creatures/Stingray.md, section 4). The views come from kit_common.py.
"""
import cmath
import json
import math
import os
import sys

import bmesh
import bpy
from mathutils import Matrix, Quaternion, Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import kit_common as kc  # noqa: E402

argv = sys.argv[sys.argv.index("--") + 1 :]
SPEC = json.load(open(argv[0]))
OUT = os.path.abspath(argv[1])
SWIM = "--swim" in argv
WIRE = "--wire" in argv
CHECKS = os.path.abspath(argv[argv.index("--checks") + 1]) if "--checks" in argv else None

S = SPEC["span"]
OL = SPEC["outline"]
HT = SPEC["heights"]
PLAT = SPEC["plateau"]  # [front, back, half width]
BELLY = SPEC["belly"]  # the flat bottom: [front, back, half width]
HINGES = SPEC["hinges"]  # the cuts between the Body and the wing pieces, root first (v out from the spine)
RIM = SPEC["rim"] * S  # the colour line's depth under the top edge, in studs
TAIL = SPEC["tail"]
BARB = SPEC.get("barb")
EYE = SPEC["eye"]
FLAP = SPEC["flap"]
WEB = SPEC.get("web")
HERO = SPEC.get("hero")  # the 3/4 camera at the concept's angle (the kit's sits low, as for a fish)
MAT_NAMES = ["top", "body", "eye"]  # the brown top, the cream underside and band, the dark eyes

A0 = OL["snout"]  # the snout's half width
TF, TB, HIP, UR = OL["tipFront"], OL["tipBack"], OL["hip"], OL["tailRoot"]
U0 = (PLAT[0] + PLAT[1]) / 2  # the seat: the plateau's middle
W0 = HT["ridgeFoot"]


# ---------------------------------------------------------------- measuring
def P(u, v, w):
    """a point measured on the concept (in S: u back from the snout, v out from the spine, w up from the belly's bottom) in
    world studs"""
    return Vector(((u - U0) * S, v * S, (w - W0) * S))


def mirror(p):
    return Vector((p.x, -p.y, p.z))


def plane(a, b, c):
    """the plane through three points: (unit normal, a point on it)"""
    return (b - a).cross(c - a).normalized(), a.copy()


def meet(p1, p2, p3):
    """the point where three planes meet"""
    m = Matrix((p1[0], p2[0], p3[0]))
    return m.inverted() @ Vector((p1[0].dot(p1[1]), p2[0].dot(p2[1]), p3[0].dot(p3[1])))


def on_plane(pl, u, v):
    """the point of the plane pl over the spot (u, v), in world studs"""
    n, q = pl
    x, y = (u - U0) * S, v * S
    return Vector((x, y, q.z - (n.x * (x - q.x) + n.y * (y - q.y)) / n.z))


def u_lead(v):
    """how far back the leading edge is, v out from the spine (snout corner to tip)"""
    return TF[0] * (v - A0) / (TF[1] - A0)


def u_trail(v):
    """how far back the trailing edge is, v out (tip to hip)"""
    return TB[0] + (HIP[0] - TB[0]) * (TB[1] - v) / (TB[1] - HIP[1])


# the wing's top: one flat face per piece, falling outward from the ridge's foot to the tip, each piece restFold steeper than
# the one inside it (the outer hinges fold down a little at rest, so the steps read as a drooping wing's facets)
CUTS_V = HINGES + [TF[1]]  # each wing piece runs from one cut to the next; the last one is the tip
FOLD = math.radians(SPEC.get("restFold", 3.0))


def wing_slopes():
    drop = HT["ridgeFoot"] - HT["tipTop"]

    def fall(a):
        return sum((CUTS_V[k + 1] - CUTS_V[k]) * math.tan(a + k * FOLD) for k in range(len(HINGES)))

    lo, hi = -0.5, 1.0
    for _ in range(60):
        mid = (lo + hi) / 2
        lo, hi = (mid, hi) if fall(mid) < drop else (lo, mid)
    return [lo + k * FOLD for k in range(len(HINGES))]


SLOPES = wing_slopes()
CUT_TOPS = [HT["ridgeFoot"]]  # the top's height at each cut
for _k in range(len(HINGES)):
    CUT_TOPS.append(CUT_TOPS[-1] - (CUTS_V[_k + 1] - CUTS_V[_k]) * math.tan(SLOPES[_k]))


def wing_top(v, k):
    """the top of wing piece k, v out (in S)"""
    return CUT_TOPS[k] - (v - CUTS_V[k]) * math.tan(SLOPES[k])


# ---------------------------------------------------------------- the scene (kit_common)
K = kc.Kit(SPEC, OUT, MAT_NAMES, 32 if (SWIM or CHECKS) else 64)


# ---------------------------------------------------------------- the hinged plate piece (shared: wings, flippers)
def plate_piece(name, corners, top, bottom, pivot, web=None):
    """One rigid piece of a hinged plate (a ray's wing piece; a flipper piece later). corners: its outline in plan (world x, y)
    in order round; top(x, y) and bottom(x, y): the heights of its flat top and flat underside. Every side face is split at the
    colour line, RIM under the top edge: the rim in the top colour, the band under it in the under colour. A joint's face is
    built and coloured the same way, so a joint that opens shows the colours beside it. web: (i, inward, angle) adds the cream
    web on the joint edge from corner i to the next (see add_web). The pivot sits on the top surface, on the hinge."""
    bm = bmesh.new()
    T = [bm.verts.new((x, y, top(x, y))) for x, y in corners]
    R = [bm.verts.new((x, y, top(x, y) - RIM)) for x, y in corners]
    B = [bm.verts.new((x, y, bottom(x, y))) for x, y in corners]
    K.face(bm, T, "top")
    K.face(bm, B[::-1], "body")
    for i in range(len(corners)):
        j = (i + 1) % len(corners)
        K.face(bm, [T[i], T[j], R[j], R[i]], "top")  # the rim
        K.face(bm, [R[i], R[j], B[j], B[i]], "body")  # the band under it
    if web:
        add_web(bm, corners, top, bottom, *web)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-4)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return K.mesh_object(name, bm, pivot)


def add_web(bm, corners, top, bottom, i, inward, angle):
    """The cream web under a joint: a wedge reaching `inward` (a unit vector, toward the piece inside) from the joint face,
    from just under the hinge down to just above the underside. At rest it hides inside the piece inside; when this piece bends
    up by up to `angle` degrees, the wedge the joint opens underneath shows the web's cream underside instead of a gap (the
    fish's sleeve, for a hinge). Its bottom sits far enough above the underside that it never pokes out below."""
    j = (i + 1) % len(corners)
    a, b = Vector((corners[i][0], corners[i][1], 0.0)), Vector((corners[j][0], corners[j][1], 0.0))
    along = (b - a).normalized()
    inward = Vector(inward)
    ang = math.radians(angle)
    ends = []
    for end, sgn in ((a, 1.0), (b, -1.0)):
        c = end + along * (sgn * 0.06) - inward * 0.02  # in from the joint's ends, and a hair inside this piece
        zt, zb = top(c.x, c.y), bottom(c.x, c.y)
        d = zt - zb
        lift = d * (1.0 - math.cos(ang)) / math.cos(ang) ** 2 + 0.01  # clear of the piece inside's underside at full bend
        reach = c + inward * (0.02 + d * math.tan(ang))
        ends.append((
            bm.verts.new((c.x, c.y, zt - 0.05)),
            bm.verts.new((c.x, c.y, zb + lift)),
            bm.verts.new((reach.x, reach.y, zb + lift)),
        ))
    (t0, b0, i0), (t1, b1, i1) = ends
    for verts in ((t0, b0, i0), (t1, i1, b1), (t0, t1, b1, b0), (b0, b1, i1, i0), (i0, i1, t1, t0)):
        K.face(bm, list(verts), "body")


def hinge_pose(ob, axis, flap, span, feather):
    """turn a hinged piece: flap (radians) about its hinge's axis, then feather (radians) about `span`, the axis across the
    piece through the hinge's middle; both relative to the piece inside it"""
    ob.rotation_mode = "QUATERNION"
    ob.rotation_quaternion = Quaternion(Vector(span), feather) @ Quaternion(Vector(axis), flap)


# ---------------------------------------------------------------- the Body
def body_points():
    """the Body's corners on the right side (the left mirrors them), in world studs"""
    h1 = HINGES[0]
    p = {
        "N0": P(0.0, A0, HT["snoutTop"]),  # the snout's top corner
        "C0": P(0.0, A0, HT["snoutBottom"]),  # and its bottom corner
        "P0": P(PLAT[0], PLAT[2], HT["plateau"]),  # the plateau's front and back corners
        "P1": P(PLAT[1], PLAT[2], HT["plateau"]),
        "H0": P(u_lead(h1), h1, HT["ridgeFoot"]),  # the first hinge's ends on the top surface: the ridge's foot
        "H1": P(u_trail(h1), h1, HT["ridgeFoot"]),
        "G0": P(u_lead(h1), h1, HT["under"]),  # the same under the wing
        "G1": P(u_trail(h1), h1, HT["under"]),
        "Q0": P(BELLY[0], BELLY[2], 0.0),  # the belly's flat bottom
        "Q1": P(BELLY[1], BELLY[2], 0.0),
        "TRt": P(UR, 0.0, TAIL["top"]),  # the tail root's top and bottom, on the spine
        "TRb": P(UR, 0.0, TAIL["top"] - TAIL["root"][0]),
    }
    hip = plane(p["P1"], p["H1"], p["TRt"])  # the hip face: one flat face from the plateau's back corner out to the hips
    p["TRs"] = on_plane(hip, UR, TAIL["root"][1] / 2)  # the tail root's side corner
    p["Hp"] = on_plane(hip, HIP[0], HIP[1])  # the hip's corner on the outline
    behind = plane(p["Q1"], p["G1"], p["TRs"])  # the underside behind the belly, out to the hips: one flat face
    p["Hb"] = on_plane(behind, HIP[0], HIP[1])
    for name in ("N0", "H0", "H1", "Hp"):  # the colour line, RIM under the top edge
        p["R" + name] = p[name] - Vector((0.0, 0.0, RIM))

    # the eye mound stands on the band of the eye face between two lines across it, each running from the forehead's side to
    # the eye face's back edge, so its foot shares those edges' vertices with the forehead and the flank
    N0, H0, P0 = p["N0"], p["H0"], p["P0"]
    n = (H0 - N0).cross(P0 - N0).normalized()  # the eye face's normal, outward
    if n.z < 0:
        n = -n
    cuts = []
    for tag, f in zip("12", EYE["lines"]):
        a = N0 + (P0 - N0) * f  # on the forehead's side
        b = H0 + (P0 - H0) * f  # on the eye face's back edge
        p["Ma" + tag], p["Mb" + tag] = a, b
        cuts.append(((b - a).cross(n).normalized(), a))  # square to the eye face, through the line
    if EYE.get("style", "block") == "corner":
        # the note's first plan: the band pushed out along the eye face's normal, its top parallel to the eye face, its inner
        # side on the forehead's plane and its outer side on the flank's (the head's corner left less cut). Those planes meet
        # (the uncut corner) only 0.1 to 0.35 studs above this eye face, so the lift is capped short of that
        forehead = plane(N0, mirror(N0), P0)
        flank = plane(P0, p["P1"], p["H1"])
        corner = min((meet(forehead, flank, cut) - cut[1]).dot(n) for cut in cuts)
        raised = (n, N0 + n * min(EYE["lift"] * S, 0.8 * corner))
        for tag, cut in zip("12", cuts):
            p["MA" + tag] = meet(forehead, raised, cut)
            p["MB" + tag] = meet(flank, raised, cut)
    else:
        # a block pushed straight up out of the band, like the concept's dark boxes: walls standing on the band's four edges,
        # a level top `stand` above its highest corner
        top = max(p[k].z for k in ("Ma1", "Mb1", "Ma2", "Mb2")) + EYE["stand"] * S
        for k in ("a1", "b1", "a2", "b2"):
            p["M" + k.upper()] = Vector((p["M" + k].x, p["M" + k].y, top))
    return p


def build_body():
    p = body_points()
    bm = bmesh.new()
    vr, vl = {}, {}
    for name, q in p.items():
        vr[name] = bm.verts.new(q)
        vl[name] = vr[name] if abs(q.y) < 1e-9 else bm.verts.new(mirror(q))

    def face(names_sides, colour):
        K.face(bm, [(vr if s > 0 else vl)[n] for n, s in names_sides], colour)

    def both(names, colour):
        """a face on the right side and its mirror on the left"""
        face([(n, 1) for n in names], colour)
        face([(n, -1) for n in names[::-1]], colour)

    # across the spine
    face([("N0", -1), ("N0", 1), ("Ma1", 1), ("Ma2", 1), ("P0", 1), ("P0", -1), ("Ma2", -1), ("Ma1", -1)], "top")  # forehead
    face([("P0", -1), ("P0", 1), ("P1", 1), ("P1", -1)], "top")  # the plateau: the seat
    face([("P1", -1), ("P1", 1), ("TRt", 1)], "top")  # the back slope, down to the tail's ridge
    face([("N0", -1), ("N0", 1), ("RN0", 1), ("RN0", -1)], "top")  # the snout's front: the rim
    face([("RN0", -1), ("RN0", 1), ("C0", 1), ("C0", -1)], "body")  # and the band under it
    face([("C0", -1), ("C0", 1), ("Q0", 1), ("Q0", -1)], "body")  # the chin
    face([("Q0", -1), ("Q0", 1), ("Q1", 1), ("Q1", -1)], "body")  # the belly's flat bottom
    face([("Q1", -1), ("Q1", 1), ("TRb", 1)], "body")  # the belly's back slope, up to the tail root
    face([("TRt", 1), ("TRs", 1), ("TRb", 1), ("TRs", -1)], "top")  # the tail joint's cap
    # either side
    both(["Ma1", "MA1", "MA2", "Ma2"], "eye")  # the eye mound, all dark: its inner side, standing on the forehead's edge
    both(["MA1", "MB1", "MB2", "MA2"], "eye")  # its top
    both(["Mb1", "Mb2", "MB2", "MB1"], "eye")  # its outer side, standing on the flank's edge
    both(["Ma1", "Mb1", "MB1", "MA1"], "eye")  # its front and back
    both(["Ma2", "MA2", "MB2", "Mb2"], "eye")
    both(["N0", "H0", "Mb1", "Ma1"], "top")  # the eye face, in front of the mound
    both(["Ma2", "Mb2", "P0"], "top")  # and behind it
    both(["P0", "P1", "H1", "H0", "Mb1", "Mb2"], "top")  # the flank, down to the first hinge
    both(["P1", "H1", "Hp", "TRs", "TRt"], "top")  # the hip face
    both(["N0", "H0", "RH0", "RN0"], "top")  # the edge from the snout's corner to the first hinge: rim, band
    both(["RN0", "RH0", "G0", "C0"], "body")
    both(["H1", "Hp", "RHp", "RH1"], "top")  # the trailing edge's last bit, inside the first hinge: rim, band
    both(["RH1", "RHp", "Hb", "G1"], "body")
    both(["Hp", "TRs", "RHp"], "top")  # the hip's edge to the tail root: the rim and the band run out at the tail
    both(["RHp", "TRs", "Hb"], "body")
    both(["C0", "G0", "Q0"], "body")  # the underside: beside the chin
    both(["Q0", "Q1", "G1", "G0"], "body")  # the chamfer up to the wing
    both(["Q1", "G1", "Hb", "TRs"], "body")  # behind it, out to the hips
    both(["Q1", "TRs", "TRb"], "body")
    both(["H0", "H1", "RH1", "RH0"], "top")  # the first hinge's cap: rim, then under it
    both(["RH0", "RH1", "G1", "G0"], "body")
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-4)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return bm, p


# ---------------------------------------------------------------- the tail: a pyramid of diamonds to the needle
def tail_frame(p):
    """the tail's root diamond (top, right, bottom, left), its centre and the needle"""
    ring = [p["TRt"], p["TRs"], p["TRb"], mirror(p["TRs"])]
    return ring, (p["TRt"] + p["TRb"]) / 2, P(UR + TAIL["length"], 0.0, TAIL["tip"])


def tail_point(q, s, inset=1.0):
    """the root diamond's corner q at s along the tail (0 the root, 1 the needle): the tail is a pyramid, so every facet is
    one flat face; inset shrinks the ring about the tail's centre line (the sleeves)"""
    k = 1.0 - s
    c = TIP + (ROOT_C - TIP) * k
    return c + (q - ROOT_C) * (k * inset)


def add_barb(bm, front, back):
    """the barb, pushed out of the tail's ridge: a swept blade whose sides rise from lines on the two top facets (shared
    vertices; the facets are cut round its foot), its front and back swept back, its top level with the ridge"""
    ys = Vector((0.0, 1.0, 0.0))
    ridge = (TIP - ROOT_RING[0]).normalized()
    Ra, Rb = tail_point(ROOT_RING[0], BARB["from"]), tail_point(ROOT_RING[0], BARB["to"])
    h = BARB["height"] * S
    Tf = Ra + ridge * (h / math.tan(math.radians(BARB["sweep"]))) + Vector((0.0, 0.0, h))
    Tb = Tf + ridge * (BARB["top"] * S)
    t0, t1 = BARB["thickness"][0] * S / 2, BARB["thickness"][1] * S / 2
    front_pl = ((Tf - Ra).cross(ys).normalized(), Ra)
    back_pl = ((Tb - Rb).cross(ys).normalized(), Rb)
    top_pl = (ridge.cross(ys).normalized(), Tf)
    facet = {1: plane(ROOT_RING[0], ROOT_RING[1], TIP), -1: plane(ROOT_RING[0], ROOT_RING[3], TIP)}
    v = {"Ra": bm.verts.new(Ra), "Rb": bm.verts.new(Rb)}
    for sg in (1, -1):
        a, b = Ra + ys * (sg * t0), Tf + ys * (sg * t1)
        side = (ridge.cross(b - a).normalized(), a)
        v[("Ff", sg)] = bm.verts.new(meet(facet[sg], front_pl, side))  # its foot on the facet
        v[("Fb", sg)] = bm.verts.new(meet(facet[sg], back_pl, side))
        v[("Tf", sg)] = bm.verts.new(meet(top_pl, front_pl, side))  # its top
        v[("Tb", sg)] = bm.verts.new(meet(top_pl, back_pl, side))
    t = "top"
    K.face(bm, [v[("Tf", -1)], v[("Tf", 1)], v[("Tb", 1)], v[("Tb", -1)]], t)  # the top edge's face
    K.face(bm, [v[("Ff", -1)], v["Ra"], v[("Ff", 1)], v[("Tf", 1)], v[("Tf", -1)]], t)  # front, swept back
    K.face(bm, [v[("Fb", 1)], v["Rb"], v[("Fb", -1)], v[("Tb", -1)], v[("Tb", 1)]], t)  # back
    K.face(bm, [v[("Ff", 1)], v[("Fb", 1)], v[("Tb", 1)], v[("Tf", 1)]], t)  # the sides
    K.face(bm, [v[("Fb", -1)], v[("Ff", -1)], v[("Tf", -1)], v[("Tb", -1)]], t)
    # the two top facets, cut round the barb's foot: in front of it, beside it, behind it
    for sg, side_k in ((1, 1), (-1, 3)):
        K.face(bm, [front[0], front[side_k], v[("Ff", sg)], v["Ra"]], t)
        K.face(bm, [v[("Ff", sg)], front[side_k], back[side_k], v[("Fb", sg)]], t)
        K.face(bm, [v["Rb"], v[("Fb", sg)], back[side_k], back[0]], t)


def build_tail():
    cuts = [0.0] + TAIL["cuts"] + [1.0]
    sleeve = TAIL.get("sleeve", 0.0) / (TAIL["length"] * S)  # as a share of the tail
    pieces = []
    for i, (s0, s1) in enumerate(zip(cuts, cuts[1:])):
        bm = bmesh.new()
        front = [bm.verts.new(tail_point(q, s0)) for q in ROOT_RING]
        last = s1 >= 1.0 - 1e-9
        back = [bm.verts.new(TIP)] * 4 if last else [bm.verts.new(tail_point(q, s1)) for q in ROOT_RING]
        barb = BARB and s0 < BARB["from"] and BARB["to"] < s1
        for k in range(4):
            k2 = (k + 1) % 4
            if barb and k in (0, 3):  # the top facets: cut round the barb
                continue
            K.face(bm, [front[k], front[k2], back[k2]] if last else [front[k], front[k2], back[k2], back[k]], "top")
        if barb:
            add_barb(bm, front, back)
        K.face(bm, front[::-1], "top")  # the joint's cap, coloured like the tail
        if not last:
            K.face(bm, back, "top")
        if sleeve:  # a short inset tube reaching forward into the piece in front (the Body, for the first), as the fish's
            a = [bm.verts.new(tail_point(q, s0 - sleeve, 0.93)) for q in ROOT_RING]
            b = [bm.verts.new(tail_point(q, s0 + 0.01, 0.93)) for q in ROOT_RING]
            for k in range(4):
                k2 = (k + 1) % 4
                K.face(bm, [a[k], a[k2], b[k2], b[k]], "top")
        bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-4)
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        pieces.append(K.mesh_object(f"Tail{i + 1}", bm, tail_point(ROOT_C, s0)))
    return pieces


# ---------------------------------------------------------------- the parts
body_bm, BODY_PTS = build_body()
body = K.mesh_object("Body", body_bm, (0.0, 0.0, 0.0))
root = K.new_object("Root")  # invisible: an empty here, a plain invisible part in Roblox
root.empty_display_type = "CUBE"
root.empty_display_size = 0.5
K.world_pos["Root"] = Vector((0.0, 0.0, 0.0))
K.attach(body, root)

wings = {1: [], -1: []}  # root to tip, each riding the one inside it
for side in (1, -1):
    parent = body
    for k in range(len(HINGES)):
        v0, v1 = CUTS_V[k], CUTS_V[k + 1]
        plan = [(u_lead(v0), v0), (u_lead(v1), v1), (u_trail(v1), v1), (u_trail(v0), v0)]
        corners = [((u - U0) * S, side * v * S) for u, v in plan]
        pivot = (((u_lead(v0) + u_trail(v0)) / 2 - U0) * S, side * v0 * S, (CUT_TOPS[k] - W0) * S)
        web = (3, (0.0, -side, 0.0), WEB["angle"]) if WEB else None  # the inner joint: from the trailing end to the leading
        ob = plate_piece(
            f"Wing{'R' if side > 0 else 'L'}{k + 1}",
            corners,
            lambda x, y, k=k: (wing_top(abs(y) / S, k) - W0) * S,
            lambda x, y: (HT["under"] - W0) * S,
            pivot,
            web,
        )
        K.attach(ob, parent)
        wings[side].append(ob)
        parent = ob

ROOT_RING, ROOT_C, TIP = tail_frame(BODY_PTS)
tail = build_tail()
K.attach(tail[0], body)
for a, b in zip(tail, tail[1:]):
    K.attach(b, a)


def report():
    """the parts, their joints and triangles, and any face that isn't flat"""
    total = 0
    for ob in sorted(K.collection.objects, key=lambda o: o.name):
        if ob.type != "MESH":
            print(f"  {ob.name:8s} (empty) pivot {tuple(round(c, 2) for c in K.world_pos[ob.name])}")
            continue
        me = ob.data
        tris = sum(len(poly.vertices) - 2 for poly in me.polygons)
        total += tris
        bent = 0.0
        for poly in me.polygons:
            if len(poly.vertices) > 3:
                bent = max(bent, max(abs((me.vertices[i].co - poly.center).dot(poly.normal)) for i in poly.vertices))
        parent = ob.parent.name if ob.parent else "-"
        print(f"  {ob.name:8s} on {parent:7s} pivot {tuple(round(c, 2) for c in K.world_pos[ob.name])}  {tris:4d} tris"
              f"{'  NOT FLAT %.4f' % bent if bent > 1e-3 else ''}")
    print(f"disc kit: {total} triangles")


report()


# ---------------------------------------------------------------- the swim
def wing_phasors():
    """each wing piece's roll from the Body as a phasor (roll_k(p) = Im(ph_k e^ip)): the hinges' rolls added up"""
    out, acc = [], 0j
    for j, a in enumerate(FLAP["hinges"]):
        acc += math.radians(a) * cmath.exp(-1j * FLAP["phaseStep"] * j)
        out.append(acc)
    return out


PH = wing_phasors()
TIP_PHASE = cmath.phase(PH[-1])


def pose(phase):
    """the swim at phase 0 to 2 pi of the loop: `beats` wing beats and one tail sway (half the rate)"""
    beats = FLAP.get("beats", 2)
    p, q = phase * beats, phase * beats / 2
    step = FLAP["phaseStep"]
    e = cmath.exp(1j * p)
    # each piece feathers in step with how fast it rises (nose up on the way up), relative to the piece inside it
    feather = [math.radians(f) * (PH[k] * e).real / abs(PH[k]) for k, f in enumerate(FLAP["feather"])]
    for side in (1, -1):
        for k, ob in enumerate(wings[side]):
            flap = math.radians(FLAP["hinges"][k]) * math.sin(p - step * k)  # a step behind the hinge inside it
            hinge_pose(ob, (1.0, 0.0, 0.0), side * flap, (0.0, 1.0, 0.0), feather[k] - (feather[k - 1] if k else 0.0))
    # the Body rises on each downstroke (the tip's), nose up while it rises, and banks a little with the tail's sway
    body.location = (0.0, 0.0, -FLAP["bob"] * S / 2 * math.sin(p + TIP_PHASE))
    body.rotation_euler = (math.radians(FLAP["bank"]) * math.sin(q), -math.radians(FLAP["pitch"]) * math.cos(p + TIP_PHASE), 0.0)
    # the tail: a lazy wave at half the rate, and a pitch half a beat behind the bob, so the whip follows the heave
    for k, ob in enumerate(tail):
        yaw = math.radians(FLAP["tailYaw"][k]) * math.sin(q - FLAP["tailStep"] * k)
        pitch = -math.radians(FLAP["tailPitch"][k]) * math.sin(p + TIP_PHASE - FLAP["tailStep"] * k)
        ob.rotation_euler = (0.0, pitch, yaw)


def rider(seat_x, seat_top, seat_hw):
    """the kit's 5-stud block rider (as in kit_common's riding view), sitting on the Body so it rides the bob"""
    blocks = [K.solid("RiderTorso", (1.0, 2.0, 2.0), "#3C78D8", (seat_x, 0.0, seat_top + 1.3)),
              K.solid("RiderHead", (1.2, 1.2, 1.2), "#F2C9A0", (seat_x, 0.0, seat_top + 2.9))]
    for s in (-1, 1):
        blocks.append(K.solid(f"RiderLeg{s:+d}", (1.0, 1.0, 2.0), "#2B2B33", (seat_x, s * (seat_hw + 0.35), seat_top - 0.4),
                              (s * math.radians(12), 0.0, 0.0)))
        blocks.append(K.solid(f"RiderArm{s:+d}", (1.6, 0.8, 0.8), "#3C78D8", (seat_x - 0.9, s * 1.25, seat_top + 1.6),
                              (0.0, math.radians(25), 0.0)))
    for b in blocks:
        b.parent = body  # the Body's pivot is the world origin and it's at rest, so nothing moves
    return blocks


def swim_views(folder, frames):
    """the looping swim, framed for a flat creature (kit_common's swim frames a fish: low, and centred on mid_x, which the long
    tail pulls back): the 3/4 from the spec's hero camera, the top as the kit's, and the riding camera of the riding view with
    the rider on the plateau. Same files as kit_common's swim, for tools/art/swim_gif.py"""
    scene = K.scene
    scene.render.film_transparent = True
    scene.render.image_settings.color_mode = "RGBA"
    os.makedirs(folder, exist_ok=True)
    f = K.frame
    hero = K.camera("SwimHero", lens=HERO.get("lens", 75))
    kc.look_from(hero, Vector(HERO["from"]) * f + Vector((mid_x, 0.0, 0.0)), (mid_x + 0.3, 0.0, 0.1))
    top = K.camera("SwimTop", ortho=SPEC.get("orthoSwimTop", 12.4))
    top.location = (mid_x, 0.0, 30.0)
    ride = K.camera("SwimRide")
    ride.data.sensor_fit = "VERTICAL"
    ride.data.angle_y = math.radians(70)  # Roblox's default field of view
    kc.look_from(ride, (14.0 * f, 3.0 * f, 6.5 * f), (-6.0 * f, 0.0, 1.0))  # where kit_common's riding view stands
    blocks = rider(0.0, (HT["plateau"] - W0) * S, PLAT[2] * S)
    for i in range(frames):
        pose(2 * math.pi * i / frames)
        for name, cam, size in (("hero", hero, (560, 410)), ("top", top, (560, 260)), ("ride", ride, (560, 410))):
            light = HERO.get("light") if name == "hero" else None
            kc.look_from(K.sun, light or (-5.0, -7.0, 9.0), (0.0, 0.0, 0.0))
            for b in blocks:  # the rider only in the riding view
                b.hide_render = name != "ride"
            K.render(cam, os.path.join(folder, f"{name}_{i:03d}.png"), *size)


def checks(folder):
    """close-ups of the wing joints at four moments of the beat, on a blue-grey ground so the cream reads"""
    os.makedirs(folder, exist_ok=True)
    K.scene.render.film_transparent = False
    K.world("#8FA9BC", 0.55)
    w = S / 12.0  # framed for a ray 12 studs across
    views = {  # the left wing's leading edge from in front, the right wing's trailing edge from behind, the top, the underside
        "lead": ((-11.0 * w, -8.5 * w, 1.6 * w), (-1.6 * w, -3.8 * w, -0.4 * w)),
        "trail": ((10.5 * w, 10.0 * w, 2.8 * w), (1.6 * w, 3.8 * w, -0.4 * w)),
        "top": ((-0.6 * w, -3.9 * w, 13.0 * w), (-0.6 * w, -3.9 * w, 0.0)),
        "under": ((-2.5 * w, -5.5 * w, -9.0 * w), (-0.4 * w, -3.6 * w, -0.8 * w)),
    }
    cams = {}
    for name, (src, dst) in views.items():
        cams[name] = K.camera("Check" + name, lens=50)
        kc.look_from(cams[name], src, dst)
    beats = FLAP.get("beats", 2)
    for k in range(4):
        pose(2 * math.pi * k / 4 / beats)  # the beat at 0, a quarter, a half, three quarters
        for name, cam in cams.items():
            K.render(cam, os.path.join(folder, f"{name}_{k}.png"), 640, 440)
    print("disc kit: checks", folder)


# ---------------------------------------------------------------- the views (kit_common)
if "--voxel" in argv:  # every part turned into cubes this size (workout 4)
    print("voxel triangles", K.voxelize(float(argv[argv.index("--voxel") + 1])))
K.studio()
front_x = P(0.0, 0.0, 0.0).x - 0.3
mid_x = (front_x + TIP.x) / 2

if CHECKS:
    checks(CHECKS)
    sys.exit(0)

if SWIM:
    folder = os.path.join(OUT, "swim_flap")
    if HERO:
        swim_views(folder, FLAP.get("frames", 48))
    else:
        K.swim(folder, FLAP.get("frames", 48), pose, mid_x)
    print("disc kit: swim", folder)
    sys.exit(0)

K.turnaround(front_x, mid_x)
if HERO:  # the kit's 3/4 camera sits low, as for a fish; a flat creature is matched at the concept's own angle and light
    cam = bpy.data.objects["Hero"]
    cam.data.lens = HERO.get("lens", 75)
    kc.look_from(cam, Vector(HERO["from"]) * K.frame + Vector((mid_x, 0.0, 0.0)), (mid_x + 0.3, 0.0, 0.1))
    if HERO.get("light"):
        kc.look_from(K.sun, HERO["light"], (0.0, 0.0, 0.0))
    K.render(cam, os.path.join(OUT, "hero.png"), 1100, 800)
    kc.look_from(K.sun, (-5.0, -7.0, 9.0), (0.0, 0.0, 0.0))  # the kit's light, for the views after
if WIRE:
    K.wire(front_x)
    wires = [ob for ob in bpy.data.objects if ob.name.endswith("Wire")]
    for w in wires:
        w.hide_render = False
        w.modifiers["Wire"].thickness = 0.05  # the ray is big: a little thicker so the edges show at these sizes
    under = K.camera("Under", ortho=SPEC.get("orthoSide", 14.5))
    kc.look_from(under, (mid_x, 0.0, -30.0), (mid_x, 0.0, 0.0))
    for name, cam, size in (
        ("hero_wire", bpy.data.objects["Hero"], (1100, 800)),
        ("top_wire", bpy.data.objects["Top"], (900, 420)),
        ("under_wire", under, (900, 420)),
    ):
        light = HERO.get("light") if (HERO and name == "hero_wire") else None
        kc.look_from(K.sun, light or (-5.0, -7.0, 9.0), (0.0, 0.0, 0.0))
        K.render(cam, os.path.join(OUT, name + ".png"), *size)
    kc.look_from(K.sun, (-5.0, -7.0, 9.0), (0.0, 0.0, 0.0))
    for w in wires:
        w.hide_render = True
K.ride(0.0, (HT["plateau"] - W0) * S, PLAT[2] * S)
print("disc kit: done", OUT)
