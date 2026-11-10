"""Shell kit: the shell body plan (docs/style/03-creature-set.md), first used for the Sea Turtle
(docs/style/creatures/SeaTurtle.md); Archelon and the Grave Turtle are meant to come from it too. It builds a blocky, faceted
turtle from a spec JSON as rigid parts, each a mesh object whose pivot is its joint (one MeshPart and one Motor6D each in Roblox):

  Shell           the root (Body joint): raised plates pushed out of a dome, the pale rim rising into an arch over the neck,
                  the cream belly dish
  Head            Neck joint, under the arch: flat planes (face, forehead, cheeks turned toward the front, side walls, chamfers),
                  the cream jaw pushed out below the mouth line, plain black eyes parallel on the cheeks, the neck stub
  FlipperF+1/-1   the front flippers (Shoulder joints)        } one shared piece, flipper_bm(): a thick plate with a kinked
  FlipperR+1/-1   the rear flippers (Hip joints)              } leading edge and a pale tip as a colour line across it
  Tail            Tail joint

usage: blender --background --python tools/blender/shell_kit.py -- <spec.json> <out folder> [--swim] [--wire] [--check]
  default: the turnaround views (transparent, for tools/art/creature_sheet.py) and the riding view with a 5-stud rider
  --wire:  also a head close-up and the same with every edge in red (head.png, head_wire.png, front_wire.png)
  --swim:  the stroke, 24 frames from the 3/4, top and riding cameras, into <out>/swim_stroke/ for tools/art/swim_gif.py
  --phase N: the turnaround posed at frame N of the stroke (0 the top of the upstroke, 13 about the bottom)
  --check: build only, render nothing: print the parts, the triangle counts, the dome, and which visible faces of the shell
           the limbs, head and tail cut in each frame of the stroke
Spec positions are in studs: x back from the rim's front edge, y out (the right side +), z up from the belly's bottom. In
Blender the Body joint is the origin, the head points to -X, up is +Z, the right side is +Y (kit_common's conventions).
"""
import json
import math
import os
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import kit_common as kc  # noqa: E402
from kit_common import clip_half  # noqa: E402

argv = sys.argv[sys.argv.index("--") + 1 :]
SPEC = json.load(open(argv[0]))
OUT = os.path.abspath(argv[1])
SWIM = "--swim" in argv
WIRE = "--wire" in argv
CHECK = "--check" in argv
MAT_NAMES = ["plates", "groove", "rim", "belly", "skin", "tips", "jaw", "pupil"]

SH = SPEC["shell"]
PIVOT = Vector(SH["pivot"])  # the Body joint, in spec coordinates: the world origin


def world(p):
    """spec coordinates (x back from the rim's front, y out, z up from the belly's bottom) -> Blender world"""
    return Vector((p[0], p[1], p[2])) - PIVOT


# ---------------------------------------------------------------- 2D and plane geometry
def V2(p):
    return Vector((p[0], p[1]))


def area(pts):
    return 0.5 * sum(pts[i - 1][0] * pts[i][1] - pts[i][0] * pts[i - 1][1] for i in range(len(pts)))


def mirrored(half):
    """the right half's corners [[x, y], ...] front to back -> the whole outline: down the right side, back up the left"""
    return [Vector((x, y)) for x, y in half] + [Vector((x, -y)) for x, y in reversed(half)]


def cross2(a, b):
    return a.x * b.y - a.y * b.x


def meet(p1, t1, p2, t2):
    """where the line p1 + a t1 meets the line p2 + b t2"""
    return p1 + t1 * (cross2(p2 - p1, t2) / cross2(t1, t2))


def inset(pts, d):
    """a convex polygon with every edge moved in by d (each corner where its two moved edges meet)"""
    sgn = 1.0 if area(pts) > 0 else -1.0
    lines = []
    for i in range(len(pts)):
        a, b = pts[i], pts[(i + 1) % len(pts)]
        t = (b - a).normalized()
        lines.append((a + Vector((-t.y, t.x)) * sgn * d, t))
    return [meet(*lines[i - 1], *lines[i]) for i in range(len(pts))]


def clean(pts):
    """Vectors, with repeated corners (from clipping) dropped"""
    out = []
    for p in pts:
        p = V2(p)
        if not out or (p - out[-1]).length > 1e-7:
            out.append(p)
    if len(out) > 1 and (out[0] - out[-1]).length <= 1e-7:
        out.pop()
    return out


def clip(pts, p0, n):
    return clean(clip_half([tuple(p) for p in pts], tuple(p0), tuple(n)))


def on_segment(a, b, p, tol=1e-6):
    ab = b - a
    t = (p - a).dot(ab) / ab.length_squared
    return -1e-9 <= t <= 1 + 1e-9 and abs(cross2(ab, p - a)) / ab.length <= tol, t


class Plane:
    """n . p = d, n a unit normal"""

    def __init__(self, n, d):
        k = n.length
        self.n, self.d = n / k, d / k

    def shifted(self, h):
        return Plane(self.n, self.d + h)

    def z(self, p):
        return (self.d - self.n.x * p[0] - self.n.y * p[1]) / self.n.z

    def lift(self, p):
        return Vector((p[0], p[1], self.z(p)))

    def dist(self, p):
        return self.n.dot(p) - self.d


def solve3(a, b, c):
    """the point on three planes"""
    den = a.n.dot(b.n.cross(c.n))
    return (b.n.cross(c.n) * a.d + c.n.cross(a.n) * b.d + a.n.cross(b.n) * c.d) / den


# ---------------------------------------------------------------- building faces
class Builder:
    """one part's bmesh, in spec coordinates: corners shared by position, faces coloured by colour area"""

    def __init__(self):
        self.bm = bmesh.new()
        self.verts = {}

    def v(self, p):
        key = tuple(round(c, 5) for c in p)
        vert = self.verts.get(key)
        if vert is None:
            vert = self.verts[key] = self.bm.verts.new(Vector((p[0], p[1], p[2])))
        return vert

    def face(self, pts, colour):
        vs = []
        for p in pts:
            v = self.v(p)
            if not vs or vs[-1] is not v:
                vs.append(v)
        if len(vs) > 2 and vs[0] is vs[-1]:
            vs.pop()
        if len(vs) < 3 or len(set(vs)) < len(vs):
            return None
        try:
            f = self.bm.faces.new(vs)
        except ValueError:  # the face exists already
            return None
        f.material_index = MAT_NAMES.index(colour)
        return f

    def face_flat(self, pts, colour, tol=2e-4):
        """a face that may be twisted: kept whole when flat, else split into a triangle and a flat fan (the first corner
        stays, so the split runs from it)"""
        if len(pts) <= 3 or flatness(pts) <= tol:
            return self.face(pts, colour)
        self.face([pts[0], pts[1], pts[2]], colour)
        self.face([pts[0]] + list(pts[2:]), colour)

    def mirror_of(self, pts):
        return [Vector((p[0], -p[1], p[2])) for p in pts]

    def both(self, pts, colour):
        """a face on the right side and its mirror on the left"""
        self.face(pts, colour)
        self.face(self.mirror_of(pts)[::-1], colour)

    def finish(self):
        bmesh.ops.remove_doubles(self.bm, verts=self.bm.verts, dist=1e-5)
        bmesh.ops.recalc_face_normals(self.bm, faces=self.bm.faces)
        return self.bm


def flatness(pts):
    """the largest distance of a polygon's corners from its best plane (Newell's normal through the centroid)"""
    n = Vector((0.0, 0.0, 0.0))
    for i in range(len(pts)):
        a, b = Vector(pts[i - 1]), Vector(pts[i])
        n += Vector(((a.y - b.y) * (a.z + b.z), (a.z - b.z) * (a.x + b.x), (a.x - b.x) * (a.y + b.y)))
    if n.length < 1e-12:
        return 0.0
    n.normalize()
    c = sum((Vector(p) for p in pts), Vector()) / len(pts)
    return max(abs(n.dot(Vector(p) - c)) for p in pts)


def P3(p, z):
    return Vector((p[0], p[1], z))


def centroid(pts):
    return sum((V2(p) for p in pts), Vector((0.0, 0.0))) / len(pts)


def zip_loops(B, outer, inner, z, colour):
    """the flat ring between two convex loops at height z, in triangles: walk both loops round by angle"""
    c = centroid(inner)

    def prep(loop):
        loop = list(loop) if area(loop) > 0 else list(loop)[::-1]  # counter-clockwise from above
        ang = [math.atan2(p.y - c.y, p.x - c.x) % (2 * math.pi) for p in loop]
        k0 = min(range(len(loop)), key=lambda k: ang[k])
        return loop[k0:] + loop[:k0], ang[k0:] + ang[:k0]

    A, aa = prep(outer)
    Bl, bb = prep(inner)
    na, nb = len(A), len(Bl)

    def angle(lst, k, n):
        return lst[k] if k < n else lst[k - n] + 2 * math.pi

    i = j = 0
    while i < na or j < nb:
        ai = angle(aa, i + 1, na) if i < na else math.inf
        bj = angle(bb, j + 1, nb) if j < nb else math.inf
        if ai <= bj:
            B.face([P3(A[i % na], z), P3(A[(i + 1) % na], z), P3(Bl[j % nb], z)], colour)
            i += 1
        else:
            B.face([P3(A[i % na], z), P3(Bl[(j + 1) % nb], z), P3(Bl[j % nb], z)], colour)
            j += 1


# ---------------------------------------------------------------- the shell: the dome and its plates
OUTLINE = mirrored(SH["outline"])  # the rim's outer edge from above: the right side's corners, front to back, then the left's
N_OUT = len(OUTLINE)
FRONT_EDGE = N_OUT - 1  # the edge from the left front corner to the right one, over the neck
RIM = SH["rim"]
INNER = inset(OUTLINE, RIM["band"])  # the rim's inner line, corner k inset from outline corner k
Z_UNDER = RIM["face"][0]  # the rim's underside: the outer face's bottom and the belly's top
DROP = RIM["top"] - RIM["face"][1]  # the rim's top band rises this much from its outer edge to its inner line
TOPS = RIM.get("tops")  # the outer face's top at each corner of the right half, front to back: the arch over the neck
THROAT = RIM["throat"]  # under the arch, over the neck: the throat (the neck's skin going in) up to here, the arch above


def rim_top(k):
    """the outer face's top at outline corner k"""
    if TOPS is None:
        return RIM["face"][1]
    return TOPS[k if k < N_OUT // 2 else N_OUT - 1 - k]


PL = SPEC["plates"]
C = PL["centre"]  # the top plate: an octagon, 45-degree corners
_k = C["halfWidth"] - C["ends"]
OCT = mirrored([[C["front"], C["ends"]], [C["front"] + _k, C["halfWidth"]],
                [C["rear"] - _k, C["halfWidth"]], [C["rear"], C["ends"]]])
# the octagon's edges in order: front-right diagonal, right side, rear-right diagonal, rear, then the left's, the front edge
KINDS = ["frontSide", "side", "rearSide", "rear", "rearSide", "side", "frontSide", "front"]
Z_DOME = SH["dome"]["top"]  # the dome under the top plate
TOP_PLANE = Plane(Vector((0.0, 0.0, 1.0)), Z_DOME)

# One flat dome face per octagon edge, sloping down from it to the rim (a hip roof: neighbours meet along straight hips, the
# grooves run along the hips). Each face's slope is set by plates.reach: the height it reaches at the rim's inner line, straight
# out from its edge's middle. The rim's inner line then takes its heights from the faces, so every plate is flat by build.
SLOPES, NORMALS, DOME = [], [], []
_oc = centroid(OCT)
for _i in range(8):
    _a, _b = OCT[_i], OCT[(_i + 1) % 8]
    _t = (_b - _a).normalized()
    _n = Vector((_t.y, -_t.x))
    if _n.dot((_a + _b) / 2 - _oc) < 0:
        _n = -_n
    _run = kc.ray_exit(INNER, (_a + _b) / 2, _n)
    _s = (Z_DOME - PL["reach"][KINDS[_i]]) / _run
    SLOPES.append(_s)
    NORMALS.append(_n)
    DOME.append(Plane(Vector((_s * _n.x, _s * _n.y, 1.0)), Z_DOME + _s * _n.dot(_a)))


def dome_z(p):
    return min([Z_DOME] + [pl.z(p) for pl in DOME])


def region(i):
    """where dome face i is the lowest (the hip roof is the lowest of its faces), inside the rim's inner line"""
    poly = clip(INNER, OCT[i], NORMALS[i])
    for j in range(8):
        if j == i:
            continue
        m = SLOPES[i] * NORMALS[i] - SLOPES[j] * NORMALS[j]
        if m.length < 1e-9:
            continue
        rhs = SLOPES[i] * NORMALS[i].dot(OCT[i]) - SLOPES[j] * NORMALS[j].dot(OCT[j])
        poly = clip(poly, m * (rhs / m.length_squared), m)
    if len(poly) < 3:
        raise ValueError(f"dome face {i} ({KINDS[i]}) vanished: its reach makes it steeper than its neighbours allow")
    return poly


def rim_inner_z(p):
    """the height of the rim's inner line at p, if p is on it"""
    for k in range(N_OUT):
        ok, t = on_segment(INNER[k], INNER[(k + 1) % N_OUT], p)
        if ok:
            return rim_top(k) + DROP + (rim_top((k + 1) % N_OUT) - rim_top(k)) * t
    return None


# A face that would rise past the rim's inner line is made steeper until it passes under it by plates.lip (the rim's inner
# wall), then the hips are found again: reach is the most a face reaches, the rim's heights win.
LIP_MIN = PL.get("lip", 0.07)
for _round in range(20):
    REGIONS = [region(i) for i in range(8)]
    _changed = False
    for _i in range(8):
        for _p in REGIONS[_i]:
            _zr = rim_inner_z(_p)
            if _zr is not None and DOME[_i].z(_p) > _zr - LIP_MIN + 1e-6:
                SLOPES[_i] = (Z_DOME - (_zr - LIP_MIN)) / NORMALS[_i].dot(_p - OCT[_i])
                _n = NORMALS[_i]
                DOME[_i] = Plane(Vector((SLOPES[_i] * _n.x, SLOPES[_i] * _n.y, 1.0)), Z_DOME + SLOPES[_i] * _n.dot(OCT[_i]))
                _changed = True
    if not _changed:
        break
# The plates: the top plate, the one over the neck and three a side. Each is one dome face, except the rear pair: each takes its
# side's rear diagonal and half the rear face (the centre groove splits it), so it is two flat faces folded along the hip from
# the octagon's rear corner, the line chosen on purpose (the note's rule: a plate that can't be one plane is split on a line).
PLATES = [("PlateTop", [(OCT, TOP_PLANE)]), ("PlateNeck", [(REGIONS[7], DOME[7])])]
for _side, (_fd, _sd, _rd) in ((1, (0, 1, 2)), (-1, (6, 5, 4))):
    _half = clip(REGIONS[3], Vector((0.0, 0.0)), Vector((0.0, float(_side))))
    PLATES += [
        (f"PlateFront{_side:+d}", [(REGIONS[_fd], DOME[_fd])]),
        (f"PlateSide{_side:+d}", [(REGIONS[_sd], DOME[_sd])]),
        (f"PlateRear{_side:+d}", [(REGIONS[_rd], DOME[_rd]), (_half, DOME[3])]),
    ]


def merge(p1, p2):
    """two convex faces sharing one edge -> one outline [(corner, face of the edge from it)]"""

    def idx(p, q):
        for k, r in enumerate(p):
            if (r - q).length < 1e-6:
                return k
        return None

    shared = [k for k, q in enumerate(p1) if idx(p2, q) is not None]
    if len(shared) != 2:
        raise ValueError("a folded plate's two faces must share exactly one edge")
    a, b = shared if (shared[0] + 1) % len(p1) == shared[1] else shared[::-1]
    out, k = [], b
    while k != a:
        out.append((p1[k], 0))
        k = (k + 1) % len(p1)
    j, jb = idx(p2, p1[a]), idx(p2, p1[b])
    while j != jb:
        out.append((p2[j], 1))
        j = (j + 1) % len(p2)
    return out


def build_plate(B, facets):
    """a plate pushed out of the dome: its outline moved in by half a groove (the groove floor is the dome face left round it),
    a wall raised along the face's normal, then the bevel in to the flat top. Corners are where the moved planes meet."""
    entries = [(p, 0) for p in facets[0][0]] if len(facets) == 1 else merge(facets[0][0], facets[1][0])
    planes = [f[1] for f in facets]
    n = len(entries)
    walls = []
    for k in range(n):
        f = entries[k][1]
        a3, b3 = planes[f].lift(entries[k][0]), planes[f].lift(entries[(k + 1) % n][0])
        w = planes[f].n.cross((b3 - a3).normalized())
        if w.dot(planes[f].lift(centroid(facets[f][0])) - a3) < 0:
            w = -w
        walls.append(Plane(w, w.dot(a3)))

    def corner(k, h, o):
        fi, fo = entries[k - 1][1], entries[k][1]
        wi, wo = walls[k - 1].shifted(o), walls[k].shifted(o)
        if fi == fo:
            return solve3(planes[fo].shifted(h), wi, wo)
        a, b = planes[fi].shifted(h), planes[fo].shifted(h)  # on the fold: on both faces
        return (solve3(a, b, wi) + solve3(a, b, wo)) / 2

    g, rise, bev = PL["groove"] / 2, PL["rise"], PL["bevel"]
    floor = [planes[e[1]].lift(e[0]) for e in entries]
    base = [corner(k, 0.0, g) for k in range(n)]
    shoulder = [corner(k, rise - bev, g) for k in range(n)]
    top = [corner(k, rise, g + bev) for k in range(n)]
    for k in range(n):
        k2 = (k + 1) % n
        B.face([floor[k], floor[k2], base[k2], base[k]], "groove")
        B.face([base[k], base[k2], shoulder[k2], shoulder[k]], "plates")
        B.face([shoulder[k], shoulder[k2], top[k2], top[k]], "plates")
    for f in range(len(facets)):
        ks = [k for k in range(n) if entries[k][1] == f]
        if len(facets) > 1:
            ks.append((ks[-1] + 1) % n)  # the fold's far end closes this face
        B.face([top[k] for k in ks], "plates")
    return base, top


# ---------------------------------------------------------------- the shell: the rim and the belly
def inner_points(k):
    """the rim's inner line from inner corner k to k+1, with every plate corner on it, as (point, rim height, dome height)"""
    a, b = INNER[k], INNER[(k + 1) % N_OUT]
    za, zb = rim_top(k) + DROP, rim_top((k + 1) % N_OUT) + DROP
    found = {0.0: a, 1.0: b}
    for _name, facets in PLATES[1:]:
        for poly, _pl in facets:
            for p in poly:
                ok, t = on_segment(a, b, p)
                if ok and 1e-6 < t < 1 - 1e-6:
                    found[round(t, 7)] = p
    return [(found[t], za + (zb - za) * t, dome_z(found[t])) for t in sorted(found)]


def build_rim(B):
    lips = []
    for k in range(N_OUT):
        k2 = (k + 1) % N_OUT
        o1, o2 = OUTLINE[k], OUTLINE[k2]
        t1, t2 = rim_top(k), rim_top(k2)
        if k == FRONT_EDGE:  # over the neck: the throat (the neck's skin) under the arch's outer face
            B.face([P3(o1, Z_UNDER), P3(o2, Z_UNDER), P3(o2, THROAT), P3(o1, THROAT)], "skin")
            B.face([P3(o1, THROAT), P3(o2, THROAT), P3(o2, t2), P3(o1, t1)], "rim")
        elif k == 0 or k2 == FRONT_EDGE:  # a corner face beside the arch: the band slopes down from the arch's foot to the
            front, back = (o1, o2) if k == 0 else (o2, o1)  # rim's underside, the belly's cream below it (the concept's front)
            tf, tb = (t1, t2) if k == 0 else (t2, t1)
            B.face([P3(front, Z_UNDER), P3(back, Z_UNDER), P3(front, THROAT)], "belly")
            B.face([P3(back, Z_UNDER), P3(back, tb), P3(front, tf), P3(front, THROAT)], "rim")
        else:
            B.face([P3(o1, Z_UNDER), P3(o2, Z_UNDER), P3(o2, t2), P3(o1, t1)], "rim")
        line = inner_points(k)
        B.face_flat([P3(o1, t1), P3(o2, t2)] + [P3(p, zr) for p, zr, _zd in reversed(line)], "rim")
        for (p, zr, zd), (q, qr, qd) in zip(line, line[1:]):  # the rim's inner wall, down to the plates' groove floor
            lips += [(zr - zd, k, tuple(round(c, 2) for c in p)), (qr - qd, k, tuple(round(c, 2) for c in q))]
            if max(zr - zd, qr - qd) > 1e-4:
                B.face([P3(p, zr), P3(q, qr), P3(q, qd), P3(p, zd)], "rim")
    return min(lips), max(lips)  # (height, outline edge, where): the lowest must stay above 0 (the plates under the rim's top)


def oct_box(cx, a, b, c):
    """an octagon centred at x = cx: a half length, b half width, 45-degree corners c"""
    return mirrored([[cx - a, b - c], [cx - a + c, b], [cx + a - c, b], [cx + a, b - c]])


def build_belly(B):
    """the cream dish under the rim: the rim's underside, sloping sides, a flat bottom (parallel edges, so every side is flat)"""
    be = SH["belly"]
    top, bot = oct_box(*be["top"]), oct_box(*be["bottom"])
    zip_loops(B, OUTLINE, top, Z_UNDER, "belly")
    for k in range(8):
        k2 = (k + 1) % 8
        B.face([P3(top[k], Z_UNDER), P3(top[k2], Z_UNDER), P3(bot[k2], 0.0), P3(bot[k], 0.0)], "belly")
    B.face([P3(p, 0.0) for p in bot], "belly")


# ---------------------------------------------------------------- the head
HD = SPEC["head"]


def head_points():
    """The head's corners on the right side (the left mirrors them), the concept's construction (docs/style/creatures/SeaTurtle.md
    section 3): a face leaning back above the mouth line, a forehead strip over it; either side a cheek, a vertical plane turned
    cheekAngle toward the front, from the face's edge back to the side wall, carrying the eye; the jaw pushed out below the mouth
    line, its top edge the most forward point, its sides flush on the cheeks, its front leaning back to the chin; lower chamfers
    folding the side walls in to the bottom; a back chamfer narrowing the head into the neck. The mouth line runs on across each
    side wall as a diagonal down to the bottom edge: green above, cream below."""
    m, fc, lc = HD["mouth"], HD["face"], HD["lowerChamfer"]
    zm, fw, w = m["z"], fc["halfWidth"], HD["halfWidth"]
    zl, bw, zb, zt = lc["z"], lc["halfWidth"], HD["bottom"], HD["top"]
    front, chin = HD["front"], HD["chinX"]
    xf = front + m["protrude"]  # the face at the mouth line
    tan_c = math.tan(math.radians(HD["cheekAngle"]))

    def cheek_y(x):
        return fw + (x - xf) * tan_c

    def chamfer_y(z):  # the lower chamfer: from the side wall's bottom (w, zl) down to the bottom's edge (bw, zb)
        return bw + (w - bw) * (z - zb) / (zl - zb)

    def jaw_x(z):  # the jaw's front leans back from its top edge to the chin
        return front + (chin - front) * (zm - z) / (zm - zb)

    P = {"FM": Vector((xf, fw, zm))}
    x = xf + fc["lean"]
    P["FT"] = Vector((x, cheek_y(x), fc["top"]))
    x = P["FT"].x + HD["forehead"]
    P["HT"] = Vector((x, cheek_y(x), zt))
    xc = xf + (w - fw) / tan_c  # the cheek's back edge
    P["CT"], P["MC"], P["CB"] = Vector((xc, w, zt)), Vector((xc, w, zm)), Vector((xc, w, zl))
    P["JT"] = Vector((front, cheek_y(front), zm))
    f0, f1 = cheek_y(jaw_x(0.0)) - chamfer_y(0.0), cheek_y(jaw_x(1.0)) - chamfer_y(1.0)
    zk = -f0 / (f1 - f0)  # where the jaw's front, the cheek and the lower chamfer meet
    if not zb <= zk <= zl:
        raise ValueError("the jaw's front must meet the cheek above the bottom: lean it back less (head.chinX)")
    P["K"] = Vector((jaw_x(zk), chamfer_y(zk), zk))
    P["B"] = Vector((chin, bw, zb))
    P["D3"] = Vector((HD["diagonalTo"], bw, zb))  # the mouth line's diagonal ends on the bottom edge...
    s = (zm - zl) / (zm - zb)
    P["D2"] = Vector((P["MC"].x + (P["D3"].x - P["MC"].x) * s, w, zl))  # ...crossing the side wall's bottom edge on the way
    bc, back = HD["backChamfer"], HD["back"]
    P["BT"], P["BB"] = Vector((back - bc["depth"], w, zt)), Vector((back - bc["depth"], w, zl))
    wn = bc["halfWidth"]
    P["NT"] = Vector((back, wn, zt))
    P["NB"] = Vector((back, wn, zb + (wn - bw) * (zl - zb) / (w - bw)))  # the back chamfer meets the lower chamfer
    P["BK"] = Vector((back, bw, zb))
    return P


def eye_centre(P, s):
    """the eye's centre on the cheek: at eye.z, halfway across the cheek, raised so its face stands eye.raise off it"""
    e, ang = SPEC["eye"], math.radians(HD["cheekAngle"])
    f = (e["z"] - P["FM"].z) / (P["FT"].z - P["FM"].z)
    front = P["FM"].lerp(P["FT"], f)
    mid = (front + Vector((P["CT"].x, P["CT"].y, e["z"]))) / 2
    normal = Vector((-math.sin(ang), math.cos(ang), 0.0))
    c = mid + normal * (e["raise"] - e["thickness"] / 2)
    return Vector((c.x, s * c.y, c.z))


def build_head():
    P = head_points()
    B = Builder()

    def R(n):
        return P[n]

    def L(n):
        return Vector((P[n].x, -P[n].y, P[n].z))

    B.face([L("FT"), R("FT"), R("FM"), L("FM")], "skin")  # the face
    B.face([L("FT"), L("HT"), R("HT"), R("FT")], "skin")  # the forehead
    B.face([L("HT"), R("HT"), R("CT"), R("BT"), R("NT"), L("NT"), L("BT"), L("CT")], "skin")  # the top
    B.face([L("FM"), R("FM"), R("JT"), L("JT")], "jaw")  # the jaw's top ledge (it stands out past the face)
    B.face([L("JT"), R("JT"), R("K"), R("B"), L("B"), L("K")], "jaw")  # the jaw's front
    B.face([L("B"), R("B"), R("D3"), L("D3")], "jaw")  # the bottom: cream as far back as the diagonal
    B.face([L("D3"), R("D3"), R("BK"), L("BK")], "skin")
    B.face([L("NT"), R("NT"), R("NB"), R("BK"), L("BK"), L("NB")], "skin")  # the back, where the neck goes in
    for names, colour in (
        (["FT", "HT", "CT", "MC", "FM"], "skin"),  # the cheek above the mouth line (the eye's face)
        (["FM", "MC", "CB", "K", "JT"], "jaw"),  # the cheek below it, one plane with the jaw's side
        (["CT", "BT", "BB", "D2", "MC"], "skin"),  # the side wall above the diagonal
        (["MC", "D2", "CB"], "jaw"),  # and below it
        (["CB", "D2", "D3", "B", "K"], "jaw"),  # the lower chamfer, cream ahead of the diagonal
        (["D2", "BB", "NB", "BK", "D3"], "skin"),
        (["BT", "NT", "NB", "BB"], "skin"),  # the back chamfer
    ):
        B.both([P[n] for n in names], colour)
    # the neck stub: from the head's back in through the throat to neck.to, inside the shell under the arch; its top stays
    # under the plate over the neck even with the head turned (the head's turning room is the back chamfer)
    nk = HD["neck"]
    x0, x1, hw, (z0, z1) = HD["back"], nk["to"], nk["halfWidth"], nk["z"]

    def c(x, y, z):
        return Vector((x, y, z))

    B.face([c(x0, -hw, z1), c(x0, hw, z1), c(x1, hw, z1), c(x1, -hw, z1)], "skin")
    B.face([c(x0, -hw, z0), c(x1, -hw, z0), c(x1, hw, z0), c(x0, hw, z0)], "skin")
    B.face([c(x0, hw, z0), c(x1, hw, z0), c(x1, hw, z1), c(x0, hw, z1)], "skin")
    B.face([c(x0, -hw, z0), c(x0, -hw, z1), c(x1, -hw, z1), c(x1, -hw, z0)], "skin")
    B.face([c(x1, -hw, z0), c(x1, -hw, z1), c(x1, hw, z1), c(x1, hw, z0)], "skin")
    # the eyes: plain black squares parallel on the cheeks (the concept's eye, decided 2026-11-09), standing eye.raise proud
    e, ang = SPEC["eye"], math.radians(HD["cheekAngle"])
    if e.get("style", "plain") != "plain":
        raise NotImplementedError("the shell kit has only the plain eye so far (eye.style \"plain\")")
    t, n, up = Vector((math.cos(ang), math.sin(ang), 0.0)), Vector((-math.sin(ang), math.cos(ang), 0.0)), Vector((0, 0, 1.0))
    hs, ht = e["size"] / 2, e["thickness"] / 2
    ctr = eye_centre(P, 1)
    q = {(i, j, k): ctr + t * (i * hs) + n * (j * ht) + up * (k * hs) for i in (-1, 1) for j in (-1, 1) for k in (-1, 1)}
    for quad in (
        [(-1, 1, -1), (1, 1, -1), (1, 1, 1), (-1, 1, 1)], [(-1, -1, -1), (-1, -1, 1), (1, -1, 1), (1, -1, -1)],
        [(-1, -1, -1), (1, -1, -1), (1, 1, -1), (-1, 1, -1)], [(-1, -1, 1), (-1, 1, 1), (1, 1, 1), (1, -1, 1)],
        [(-1, -1, -1), (-1, 1, -1), (-1, 1, 1), (-1, -1, 1)], [(1, -1, -1), (1, -1, 1), (1, 1, 1), (1, 1, -1)],
    ):
        B.both([q[c_] for c_ in quad], "pupil")
    return B


# ---------------------------------------------------------------- the flipper: the shared limb piece
def hinge_outline(lim):
    """the outline turned into the hinge's frame: [(u out from the hinge, v along it)]. The spec draws it as seen from above at
    rest (u out, v back, from the joint); `hinge` is the hinge's turn from fore-and-aft in degrees, its back end out (+)"""
    a = math.radians(lim.get("hinge", 0.0))
    return [(-v * math.sin(a) + u * math.cos(a), v * math.cos(a) + u * math.sin(a)) for u, v in lim["outline"]]


def limb_axis(lim):
    """the limb's long axis in its local frame (x along the hinge, y out): from the hinge's middle to the middle of its tip
    edge (the two corners furthest out), and its length"""
    far = sorted(hinge_outline(lim), key=lambda p: -p[0])[:2]
    tip = Vector(((far[0][1] + far[1][1]) / 2, (far[0][0] + far[1][0]) / 2, 0.0))
    return tip.normalized(), tip.length


def flipper_bm(lim):
    """The kit's limb piece (flippers now; the plesiosaurs, the sea lion, Archelon later): one thick plate, the same thickness
    all the way. outline [[u, v], ...] is the plate seen from above at rest, from the joint: u out, v back; its first and last
    corners are the root, on the hinge line, which turns `hinge` degrees from fore-and-aft (put it along the body's edge, so a
    rising flipper never cuts the body). The sweep back is drawn into the outline (a kink is just a corner). The root is pushed
    `sleeve` in past the hinge, so a moving flipper never opens a gap at the body. The two tip corners are cut at 45 degrees
    (`tipCut`), and a straight line across the plate at `tipAt` of its length, square to its long axis, is the colour line to
    the pale tip: faces of the same mesh, never a cap. Local axes: +X along the hinge (back), +Y out from it, +Z up."""
    pts = hinge_outline(lim)
    lead, trail = lim["sleeve"] if isinstance(lim["sleeve"], list) else (lim["sleeve"], lim["sleeve"])
    pts[0] = (pts[0][0] - lead, pts[0][1])  # [leading, trailing]: a root corner already on the body's edge needs none
    pts[-1] = (pts[-1][0] - trail, pts[-1][1])
    cut = lim.get("tipCut", 0.0)
    if cut > 0:  # cut the tip edge's two corners (the two corners furthest out)
        far = sorted(range(len(pts)), key=lambda i: -pts[i][0])[:2]
        out = []
        for i, p in enumerate(pts):
            if i not in far:
                out.append(p)
                continue
            P_ = Vector(p)
            for nb in (pts[i - 1], pts[(i + 1) % len(pts)]):
                out.append(tuple(P_ + (Vector(nb) - P_).normalized() * cut))
        pts = out
    axis, length = limb_axis(lim)
    a2 = (axis.y, axis.x)  # the axis in (u, v)
    at = (a2[0] * lim["tipAt"] * length, a2[1] * lim["tipAt"] * length)
    B = Builder()
    h = lim["thickness"] / 2

    def on_line(p):
        return abs((p[0] - at[0]) * a2[0] + (p[1] - at[1]) * a2[1]) < 1e-7

    for poly, colour in ((clip_half(pts, at, (-a2[0], -a2[1])), "plates"), (clip_half(pts, at, a2), "tips")):
        top = [Vector((v, u, h)) for u, v in poly]
        bot = [Vector((v, u, -h)) for u, v in poly]
        B.face(top, colour)
        B.face(bot[::-1], colour)
        for i in range(len(poly)):
            j = (i + 1) % len(poly)
            if on_line(poly[i]) and on_line(poly[j]):
                continue  # the colour line runs across the plate: no wall there
            B.face([bot[i], bot[j], top[j], top[i]], colour)
    return B.finish()


def limb_rotation(s, lim, axis, sweep, elevation, twist):
    """a limb's turn at its joint: twisted about its own long axis (leading edge up +), raised about its hinge, turned to the
    hinge's direction, then swept back by `sweep` about the vertical (the stroke's forward and back); the left mirrors the
    right"""
    R = (Matrix.Rotation(-math.radians(sweep), 3, "Z") @ Matrix.Rotation(math.radians(lim.get("hinge", 0.0)), 3, "Z")
         @ Matrix.Rotation(math.radians(elevation), 3, "X") @ Matrix.Rotation(math.radians(twist), 3, axis))
    if s < 0:
        M = Matrix.Diagonal((1.0, -1.0, 1.0))
        R = M @ R @ M
    return R.to_quaternion()


def build_tail():
    """a wedge from its hinge inside the rim's rear: flat top and bottom, closing to a blunt tip"""
    t = SPEC["tail"]
    px, _py, pz = t["pivot"]
    (bw, bh), (tw, th), x1 = t["base"], t["tip"], t["pivot"][0] + t["length"]
    B = Builder()
    q = {}
    for s in (1, -1):
        for k in (1, -1):
            q[("b", s, k)] = Vector((px, s * bw / 2, pz + k * bh / 2))
            q[("t", s, k)] = Vector((x1, s * tw / 2, pz + k * th / 2))
    for names in (
        [("b", -1, 1), ("b", 1, 1), ("t", 1, 1), ("t", -1, 1)], [("b", -1, -1), ("t", -1, -1), ("t", 1, -1), ("b", 1, -1)],
        [("b", 1, -1), ("t", 1, -1), ("t", 1, 1), ("b", 1, 1)], [("b", -1, -1), ("b", -1, 1), ("t", -1, 1), ("t", -1, -1)],
        [("t", -1, -1), ("t", -1, 1), ("t", 1, 1), ("t", 1, -1)], [("b", -1, -1), ("b", 1, -1), ("b", 1, 1), ("b", -1, 1)],
    ):
        B.face([q[n] for n in names], "skin")
    return B


# ---------------------------------------------------------------- the parts, in kit_common's scene
K = kc.Kit(SPEC, OUT, MAT_NAMES, 32 if SWIM else 64)


def part(name, B, pivot):
    """a part from a Builder in spec coordinates, its pivot (its joint) given in spec coordinates"""
    bm = B.finish()
    for v in bm.verts:
        v.co = world(v.co)
    return K.mesh_object(name, bm, world(pivot))


def limbs(key, name):
    """a pair of limbs from the shared flipper piece, hinged on the shell: [(object, side)]"""
    lim, out = SPEC["limbs"][key], []
    for s in (1, -1):
        bm = flipper_bm(lim)
        if s < 0:
            for v in bm.verts:
                v.co.y = -v.co.y
            bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        ob = K.mesh_object(f"{name}{s:+d}", bm, (0.0, 0.0, 0.0))
        ob.location = world((lim["pivot"][0], s * lim["pivot"][1], lim["pivot"][2]))
        K.world_pos[ob.name] = Vector(ob.location)
        ob.rotation_mode = "QUATERNION"
        K.attach(ob, shell)
        out.append((ob, s))
    return out


SB = Builder()
for _name, _facets in PLATES:
    build_plate(SB, _facets)
LIP = build_rim(SB)
build_belly(SB)
shell = part("Shell", SB, PIVOT)
NK = HD["neck"]
head = part("Head", build_head(), (NK["pivot"][0], 0.0, NK["pivot"][1]))
tail = part("Tail", build_tail(), SPEC["tail"]["pivot"])
K.attach(head, shell)
K.attach(tail, shell)
FRONT = limbs("front", "FlipperF")
REAR = limbs("rear", "FlipperR")
AXIS = {key: limb_axis(SPEC["limbs"][key])[0] for key in ("front", "rear")}


# ---------------------------------------------------------------- the stroke (docs/style/creatures/SeaTurtle.md section 5)
SW = SPEC["swim"]


def stroke(u):
    """the front pair's beat at u (0 to 1, from the top of the upstroke): (elevation, its speed) in -1..1. A cosine warped so
    the downstroke takes `down` of the cycle; the speed is 0 at the top and the bottom, -1 mid-downstroke, +1 mid-upstroke"""
    d = SW["front"]["down"]
    u %= 1.0
    if u < d:
        return math.cos(math.pi * u / d), -math.sin(math.pi * u / d)
    return math.cos(math.pi + math.pi * (u - d) / (1 - d)), math.sin(math.pi * (u - d) / (1 - d))


def pose(phase):
    """every joint at one moment of the stroke (phase 0 to 2 pi), added to the rest pose. In the game the phase is added up
    each frame (phase += dt / cycle), so a change of speed changes the beat smoothly and never makes the pose jump."""
    u = phase / (2 * math.pi)
    fr, rest = SW["front"], SPEC["limbs"]["front"]["rest"]
    e, speed = stroke(u)
    sweep = -fr["sweep"] * stroke(u - fr["sweepLag"])[0]  # forward at the top, back at the bottom, a little behind the beat
    for ob, s in FRONT:
        ob.rotation_quaternion = limb_rotation(
            s, SPEC["limbs"]["front"], AXIS["front"], sweep,
            rest["elevation"] + fr["elevation"] * e, rest["twist"] + fr["twist"] * speed)
    rr, rest = SW["rear"], SPEC["limbs"]["rear"]["rest"]
    c, sn = math.cos(2 * math.pi * (u - rr["lag"])), math.sin(2 * math.pi * (u - rr["lag"]))
    for ob, s in REAR:  # a gentle paddle, half a beat behind; the leading edge down on the way down
        ob.rotation_quaternion = limb_rotation(
            s, SPEC["limbs"]["rear"], AXIS["rear"], 0.0,
            rest["elevation"] + rr["elevation"] * c, rest["twist"] - rr["twist"] * sn)
    sh = SW["shell"]
    k = math.cos(2 * math.pi * (u - fr["down"]))  # highest and nose up as the downstroke ends
    shell.location.z = sh["heave"] * k
    shell.rotation_euler.y = math.radians(sh["pitch"]) * k  # + is nose up (the head is at -X)
    hd = SW["head"]
    head.rotation_euler.y = -math.radians(hd["pitch"]) * math.cos(2 * math.pi * (u - fr["down"] - hd["lag"]))
    tail.rotation_euler.z = math.radians(SW["tail"]["yaw"]) * sn


def rest_pose():
    for group, key in ((FRONT, "front"), (REAR, "rear")):
        r = SPEC["limbs"][key]["rest"]
        for ob, s in group:
            ob.rotation_quaternion = limb_rotation(s, SPEC["limbs"][key], AXIS[key], 0.0, r["elevation"], r["twist"])
    shell.location.z = 0.0
    shell.rotation_euler.y = head.rotation_euler.y = tail.rotation_euler.z = 0.0


FRAMES = 24


def world_tree(ob):
    from mathutils.bvhtree import BVHTree

    verts = [ob.matrix_world @ v.co for v in ob.data.vertices]
    return BVHTree.FromPolygons(verts, [tuple(p.vertices) for p in ob.data.polygons])


def clearance():
    """the limbs, head and tail against the shell through one stroke, then the head turned 20 degrees either way: which of
    the shell's visible faces they cut (not the rim's underside and the belly dish, where the roots go in on purpose, nor the
    joints' own way in: the neck through the throat, the tail through the rim's rear face)"""
    names = {i: n for i, n in enumerate(MAT_NAMES)}
    rows = []
    for f in range(FRAMES):
        pose(2 * math.pi * f / FRAMES)
        bpy.context.view_layer.update()
        shell_tree = world_tree(shell)
        row = []
        for group in ([ob for ob, _s in FRONT], [ob for ob, _s in REAR], [head, tail]):
            hits = set()
            for ob in group:
                for i, _j in shell_tree.overlap(world_tree(ob)):
                    poly = shell.data.polygons[i]
                    colour = names[poly.material_index]
                    c = poly.center + PIVOT
                    joint = (ob is head and colour == "skin" and c.x < 0.05) or (  # the neck stub into the throat
                        ob is tail and colour == "rim" and c.x > OUTLINE[N_OUT // 2].x - 0.05)  # the tail's root into the rim
                    hidden = colour == "belly" and c.z <= Z_UNDER + 1e-3  # the rim's underside and the belly dish
                    if not hidden and not joint:
                        hits.add(f"{ob.name}:{colour}@{c.x:.1f},{c.y:.1f},{c.z:.1f}")
            row.append(sorted(hits))
        rows.append(row)
    for yaw in (-20, 20):  # the idle look-around turns the head up to 20 degrees either way
        rest_pose()
        head.rotation_euler.z = math.radians(yaw)
        bpy.context.view_layer.update()
        shell_tree, hits = world_tree(shell), set()
        for i, _j in shell_tree.overlap(world_tree(head)):
            poly = shell.data.polygons[i]
            colour, c = names[poly.material_index], poly.center + PIVOT
            if colour != "skin" and not (colour == "belly" and c.z <= Z_UNDER + 1e-3):
                hits.add(f"head turned {yaw}:{colour}@{c.x:.1f},{c.y:.1f},{c.z:.1f}")
        rows.append([[], [], sorted(hits)])
    rest_pose()
    bpy.context.view_layer.update()
    return rows


def triangles(ob):
    return sum(len(p.vertices) - 2 for p in ob.data.polygons)


def report():
    parts = [shell, head, tail] + [ob for ob, _s in FRONT + REAR]
    total = 0
    for ob in parts:
        t = triangles(ob)
        total += t
        print(f"  {ob.name:12s} {t:4d} triangles, pivot {tuple(round(c, 3) for c in K.world_pos[ob.name])}")
    print(f"  total {total} triangles")
    print("  dome slopes:", ", ".join(f"{KINDS[i]} {math.degrees(math.atan(SLOPES[i])):.0f}" for i in range(4)), "+ the mirror;",
          f"the front {math.degrees(math.atan(SLOPES[7])):.0f} degrees")
    print(f"  the rim's inner wall over the plates: {LIP[0][0]:.3f} (edge {LIP[0][1]} at {LIP[0][2]}) to {LIP[1][0]:.3f} studs")
    return total


# ---------------------------------------------------------------- the views (kit_common)
if "--voxel" in argv:  # every part turned into cubes this size (workout 4)
    print("voxel triangles", K.voxelize(float(argv[argv.index("--voxel") + 1])))
K.studio()
rest_pose()
front_x = world((HD["front"], 0.0, 0.0)).x - 0.3
tail_end = world((SPEC["tail"]["pivot"][0] + SPEC["tail"]["length"], 0.0, 0.0)).x
mid_x = (front_x + tail_end) / 2

if CHECK:
    report()
    rows = clearance()
    for f, (a, b, c) in enumerate(rows):
        if a or b or c:
            print(f"  frame {f:2d} cuts the shell's visible faces: front flippers {a}, rear {b}, head/tail {c}")
    print("  clearance:", "clear through the stroke and with the head turned 20 degrees either way"
          if not any(a or b or c for a, b, c in rows) else "see the frames above (24 and 25: the head turned)")
    sys.exit(0)

if SWIM:
    folder = os.path.join(OUT, "swim_stroke")
    K.swim(folder, FRAMES, pose, mid_x)
    print("shell kit: swim", folder)
    sys.exit(0)

if "--phase" in argv:  # a still of the stroke instead of the rest pose: frame N of 24
    pose(2 * math.pi * int(argv[argv.index("--phase") + 1]) / FRAMES)
K.turnaround(front_x, mid_x)
# the kit's top view is framed for a narrow fish: render it again tall enough for the flippers
top_cam = K.camera("TopWide", ortho=SPEC.get("orthoTop", 15.0))
top_cam.location = (mid_x, 0.0, 30.0)
K.render(top_cam, os.path.join(OUT, "top.png"), 900, SPEC.get("topHeight", 760))
if WIRE:
    K.wire(front_x)
seat = SPEC["seat"]
K.ride(world((seat[0], 0.0, 0.0)).x, world((0.0, 0.0, seat[1])).z, seat[2])
report()
print("shell kit: done", OUT)
