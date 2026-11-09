"""Prop kit: builds the world's props (rocks, coral, kelp and sea grass, shells, dock props) as chunky, faceted, low-poly meshes in
the creature look (flat colours, hard edges, toy proportions; Ride a Dino's broad style, never its models), exports each as its
own FBX, renders a contact sheet and writes props.json (name, file, size in studs, tris, suggested zones).

usage: blender --background --python tools/blender/prop_kit.py -- [out folder] [--only name,name] [--no-sheet]
  out folder defaults to art/props
Units are studs: 1 Blender unit = 1 stud (a player is about 5 studs tall). Z is up while building; the FBX is written Y-up for
Roblox. Every prop's pivot is at its base: the bottom sits at height 0, centred on its footprint.
Colour: every prop has one material whose colour comes from palette.png (one flat cell per colour, the UVs point at the cells),
so in Roblox each prop is one MeshPart with one texture and colour sets are separate meshes. Tris are kept low for phones.
"""
import json
import math
import os
import random
import struct
import sys
import tempfile
import zlib

import bmesh
import bpy
import numpy as np
from mathutils import Matrix, Vector

argv = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
OUT = os.path.abspath(argv[0] if argv and not argv[0].startswith("--") else "art/props")
ONLY = set(argv[argv.index("--only") + 1].split(",")) if "--only" in argv else None
SHEET = "--no-sheet" not in argv
os.makedirs(OUT, exist_ok=True)

UP = Vector((0.0, 0.0, 1.0))
TAU = 2 * math.pi

# ---------------------------------------------------------------- the palette (order = cell in palette.png: only append)
PALETTE = {
    # rocks, the reef set (warm blue-grey, sand on top, moss)
    "rock": "#8A97AB",
    "rock_dark": "#6C7891",
    "rock_top": "#E7D6A2",
    "moss": "#7FC66A",
    # rocks, the deep set (violet, look A's deep, with glowing specks)
    "deep_rock": "#55517E",
    "deep_rock_dark": "#3E3B63",
    "deep_top": "#7A74AC",
    "glow": "#5FF0E0",
    # coral sets
    "pink": "#FF7DA6",
    "pink_tip": "#FFD0DF",
    "pink_dark": "#D54F7D",
    "orange": "#FF9A4A",
    "orange_tip": "#FFE08A",
    "orange_dark": "#DE6428",
    "purple": "#A77BFF",
    "purple_tip": "#E3CCFF",
    "purple_dark": "#7550D6",
    # kelp, sea grass
    "kelp": "#8CCB45",
    "kelp_light": "#B6E35C",
    "kelp_stipe": "#5E9436",
    "kelp_bladder": "#E0BE48",
    "grass": "#5FCF7E",
    "grass_light": "#A6EB72",
    # shells
    "shell": "#FFB088",
    "shell_light": "#FFE6D2",
    "conch": "#F7D8AE",
    "conch_pink": "#F48CA2",
    "star": "#FF7A3C",
    "star_light": "#FFB86B",
    "urchin": "#5A3D8E",
    "urchin_spike": "#9C78DE",
    # dock
    "wood": "#C98A4B",
    "wood_dark": "#8E5A2C",
    "wood_light": "#E6B477",
    "rope": "#E9D39A",
    "buoy_red": "#F0473B",
    "buoy_white": "#F6F1E6",
    "metal": "#6F7B88",
    "lamp": "#FFE35A",
}
CELLS = 8  # palette.png is CELLS x CELLS cells
CELL_PX = 8
COLOUR_INDEX = {name: i for i, name in enumerate(PALETTE)}
assert len(PALETTE) <= CELLS * CELLS

ROCK_SETS = {
    "reef": {"rock": "rock", "dark": "rock_dark", "top": "rock_top", "accent": "moss", "accentShare": 0.2},
    "deep": {"rock": "deep_rock", "dark": "deep_rock_dark", "top": "deep_top", "accent": "glow", "accentShare": 0.15},
}
CORAL_SETS = {name: {"main": name, "tip": name + "_tip", "dark": name + "_dark"} for name in ("pink", "orange", "purple")}

SHALLOW = ["Shallows", "Coral Reef", "Kelp Forest", "Shipwrecks", "Open Blue"]
DEEP = ["Twilight", "Midnight", "Vents", "Bone Graveyard", "The Underworld"]


def hex_srgb(h):
    h = h.lstrip("#")
    return [int(h[i : i + 2], 16) for i in (0, 2, 4)]


def srgb_to_linear(c):
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def write_png(path, w, h, rgb_rows):
    """a plain RGB PNG; rgb_rows top row first, each a list of (r, g, b) bytes"""
    raw = b"".join(b"\x00" + bytes(c for px in row for c in px) for row in rgb_rows)

    def chunk(kind, data):
        return struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data) & 0xFFFFFFFF)

    with open(path, "wb") as f:
        f.write(b"\x89PNG\r\n\x1a\n")
        f.write(chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 2, 0, 0, 0)))
        f.write(chunk(b"IDAT", zlib.compress(raw, 9)))
        f.write(chunk(b"IEND", b""))


def write_palette(path):
    size = CELLS * CELL_PX
    cols = list(PALETTE.values())
    rows = []
    for y in range(size):
        row = []
        for x in range(size):
            i = (y // CELL_PX) * CELLS + x // CELL_PX
            row.append(hex_srgb(cols[i]) if i < len(cols) else (255, 0, 255))
        rows.append(row)
    write_png(path, size, size, rows)


def cell_uv(name):
    """the centre of a colour's cell; the PNG's top row is v = 1"""
    i = COLOUR_INDEX[name]
    cx, cy = i % CELLS, i // CELLS
    return ((cx + 0.5) / CELLS, 1.0 - (cy + 0.5) / CELLS)


# ---------------------------------------------------------------- geometry: parts and the prop they go into
class Rule:
    """a face colour picked from the face's outward normal and centre, after the normals are fixed"""

    def __init__(self, fn):
        self.fn = fn


class Part:
    def __init__(self, verts, faces, cols, closed=True):
        self.verts = [Vector(v) for v in verts]
        self.faces = faces
        self.cols = cols
        self.closed = closed  # closed parts get their normals recalculated; open ones (ribbons) are wound by hand

    def transform(self, m):
        self.verts = [m @ v for v in self.verts]
        return self

    def warp(self, fn):
        self.verts = [Vector(fn(v)) for v in self.verts]
        return self


class Geo:
    def __init__(self):
        self.verts, self.faces, self.cols, self.closed = [], [], [], []

    def add(self, part, m=None):
        o = len(self.verts)
        self.verts += [(m @ v) if m else v.copy() for v in part.verts]
        for f, c in zip(part.faces, part.cols):
            self.faces.append([o + i for i in f])
            self.cols.append(c)
            self.closed.append(part.closed)
        return self


def colour_at(entry, k, j):
    """a band's colour entry: a name, a Rule, or a function of the segment round the ring"""
    if isinstance(entry, (str, Rule)):
        return entry
    return entry(j)


def loft(rings, cols, bottom=None, top=None, loop=False):
    """joins rings of points (each the same count, or a single point for a tip) into bands; cols: one entry per band"""
    verts, faces, fc, idx = [], [], [], []
    for ring in rings:
        idx.append(list(range(len(verts), len(verts) + len(ring))))
        verts += ring
    bands = len(rings) if loop else len(rings) - 1
    for k in range(bands):
        a, b = idx[k], idx[(k + 1) % len(rings)]
        n = max(len(a), len(b))
        for j in range(n):
            j2 = (j + 1) % n
            if len(a) == 1:
                f = (a[0], b[j], b[j2])
            elif len(b) == 1:
                f = (a[j], a[j2], b[0])
            else:
                f = (a[j], a[j2], b[j2], b[j])
            faces.append(f)
            fc.append(colour_at(cols[k] if isinstance(cols, list) else cols, k, j))
    closed = loop
    if not loop:
        ends = [(idx[0], bottom, True), (idx[-1], top, False)]
        closed = True
        for ring, colour, flip in ends:
            if len(ring) == 1:
                continue
            if colour is None:
                closed = False
                continue
            faces.append(tuple(reversed(ring)) if flip else tuple(ring))
            fc.append(colour)
    return Part(verts, faces, fc, closed)


def jittered(v, rng, amount, vertical=0.6):
    if not amount:
        return v
    return v + Vector((rng.uniform(-1, 1) * amount, rng.uniform(-1, 1) * amount, rng.uniform(-1, 1) * amount * vertical))


def lathe(profile, sides, cols, bottom=None, top=None, phase=0.0, twist=0.0, jitter=0.0, rng=None, radial=None):
    """turns a profile of (radius, height) from the bottom up; radius 0 at either end makes a point; radial(j) scales each spoke"""
    rings = []
    for k, (r, z) in enumerate(profile):
        if r == 0:
            rings.append([Vector((0.0, 0.0, z))])
            continue
        ring = []
        for j in range(sides):
            a = TAU * j / sides + phase + twist * k
            rr = r * (radial(j) if radial else 1.0)
            ring.append(jittered(Vector((rr * math.cos(a), rr * math.sin(a), z)), rng, jitter))
        rings.append(ring)
    return loft(rings, cols, bottom, top)


def frames(path, loop):
    """tangents and parallel-transported normals along a path"""
    n = len(path)
    tangents = []
    for i in range(n):
        if loop:
            t = path[(i + 1) % n] - path[i - 1]
        else:
            t = path[min(i + 1, n - 1)] - path[max(i - 1, 0)]
        tangents.append(t.normalized())
    ref = UP if abs(tangents[0].z) < 0.9 else Vector((1.0, 0.0, 0.0))
    normals = [(ref - tangents[0] * ref.dot(tangents[0])).normalized()]
    for t in tangents[1:]:
        m = normals[-1] - t * normals[-1].dot(t)
        normals.append(m.normalized())
    return tangents, normals


def tube(path, radii, sides, cols, start=None, end=None, loop=False, phase=0.0, jitter=0.0, rng=None):
    path = [Vector(p) for p in path]
    tangents, normals = frames(path, loop)
    rings = []
    for p, r, t, nrm in zip(path, radii, tangents, normals):
        if r == 0:
            rings.append([p.copy()])
            continue
        b = t.cross(nrm)
        ring = []
        for j in range(sides):
            a = TAU * j / sides + phase
            ring.append(jittered(p + (nrm * math.cos(a) + b * math.sin(a)) * r, rng, jitter))
        rings.append(ring)
    return loft(rings, cols, start, end, loop)


def ico(subdivisions, radius=1.0):
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=subdivisions, radius=radius)
    bm.verts.index_update()
    verts = [v.co.copy() for v in bm.verts]
    faces = [tuple(v.index for v in f.verts) for f in bm.faces]
    bm.free()
    return verts, faces


def icosphere(subdivisions, radius, colour, jitter=0.0, rng=None):
    verts, faces = ico(subdivisions, radius)
    if jitter:
        verts = [v * (1.0 + rng.uniform(-jitter, jitter)) for v in verts]
    return Part(verts, faces, [colour] * len(faces))


def cut_rect(sx, sy, cut, z):
    """a rectangle with its corners cut off, anticlockwise from above"""
    hx, hy = sx / 2, sy / 2
    c = min(cut, hx * 0.9, hy * 0.9)
    pts = [(hx, -hy + c), (hx, hy - c), (hx - c, hy), (-hx + c, hy), (-hx, hy - c), (-hx, -hy + c), (-hx + c, -hy), (hx - c, -hy)]
    return [Vector((x, y, z)) for x, y in pts]


def slab(sx, sy, h, bevel, cut, cols, top, bottom, jitter=0.0, rng=None):
    """a block with cut corners and a bevelled top edge"""
    rings = [cut_rect(sx, sy, cut, 0.0), cut_rect(sx, sy, cut, h - bevel), cut_rect(sx - 2 * bevel, sy - 2 * bevel, cut, h)]
    rings = [[jittered(v, rng, jitter) for v in ring] for ring in rings]
    return loft(rings, cols, bottom, top)


def plate(outline, thickness, front, side, hub=None):
    """a flat plate in the XZ plane, thickness along Y; the faces fan from a hub point (default: the outline's middle);
    front(i) colours sector i"""
    o = [Vector((x, 0.0, z)) for x, z in outline]
    hub = Vector((hub[0], 0.0, hub[1])) if hub else sum(o, Vector()) / len(o)
    n = len(o)
    half = Vector((0.0, thickness / 2, 0.0))
    verts = [p - half for p in o] + [p + half for p in o] + [hub - half, hub + half]
    hf, hb = 2 * n, 2 * n + 1
    faces, cols = [], []
    for i in range(n):
        i2 = (i + 1) % n
        faces.append((hf, i, i2))  # the -Y side
        cols.append(front(i))
        faces.append((hb, n + i2, n + i))  # the +Y side
        cols.append(front(i))
        faces.append((i, n + i, n + i2, i2))
        cols.append(side)
    return Part(verts, faces, cols)


def ribbon(path, widths, hint, thickness, cols):
    """a thin two-layer strip along a path (leaves, blades): its breadth is across path x hint; open, wound by hand"""
    path = [Vector(p) for p in path]
    tangents, _ = frames(path, False)
    verts, faces, fc = [], [], []
    layers = {1: [], -1: []}
    for p, w, t in zip(path, widths, tangents):
        s = t.cross(hint).normalized()
        fn = s.cross(t).normalized()
        for sign in (1, -1):
            off = fn * (thickness / 2) * sign
            if w == 0:
                layers[sign].append([len(verts)])
                verts.append(p + off)
            else:
                layers[sign].append([len(verts), len(verts) + 1])
                verts += [p - s * w / 2 + off, p + s * w / 2 + off]
    for sign in (1, -1):
        rows = layers[sign]
        for k in range(len(rows) - 1):
            a, b = rows[k], rows[k + 1]
            f = (a[0], a[1], b[0]) if len(b) == 1 else (a[0], a[1], b[1], b[0])
            faces.append(f if sign == 1 else tuple(reversed(f)))
            fc.append(colour_at(cols, k, k))
    return Part(verts, faces, fc, closed=False)


def box(sx, sy, sz, colour):
    hx, hy, hz = sx / 2, sy / 2, sz / 2
    verts = [(x, y, z) for z in (-hz, hz) for y in (-hy, hy) for x in (-hx, hx)]
    faces = [(0, 2, 3, 1), (4, 5, 7, 6), (0, 1, 5, 4), (2, 6, 7, 3), (0, 4, 6, 2), (1, 3, 7, 5)]
    return Part(verts, faces, [colour] * 6)


def T(x=0.0, y=0.0, z=0.0):
    return Matrix.Translation((x, y, z))


def R(angle_deg, axis):
    return Matrix.Rotation(math.radians(angle_deg), 4, axis)


def S(x, y, z):
    return Matrix.Diagonal((x, y, z, 1.0))


def rot_towards(v):
    """a rotation taking +Z to v"""
    return UP.rotation_difference(Vector(v).normalized()).to_matrix().to_4x4()


# ---------------------------------------------------------------- rocks
def rock_rule(rs, rng):
    def pick(n, c):
        if n.z > 0.72:
            return rs["accent"] if rng.random() < rs["accentShare"] else rs["top"]
        if n.z < -0.4:
            return rs["dark"]
        return rs["dark"] if rng.random() < 0.3 else rs["rock"]

    return Rule(pick)


def boulder_part(rng, rule, size, subdivisions=2, jitter=0.2):
    verts, faces = ico(subdivisions, 1.0)
    verts = [v * (1.0 + rng.uniform(-jitter, jitter)) for v in verts]
    verts = [Vector((v.x * size[0] / 2, v.y * size[1] / 2, (max(v.z, -0.45) + 0.45) * size[2] / 1.45)) for v in verts]
    return Part(verts, faces, [rule] * len(faces))


def rock_boulder(rs, seed, size):
    rng = random.Random(seed)
    return Geo().add(boulder_part(rng, rock_rule(rs, rng), size), R(rng.uniform(0, 360), "Z"))


def rock_cluster(rs, seed):
    """a handful of chunky stones (bare icosahedra): scatter round bigger rocks"""
    rng = random.Random(seed)
    rule, g = rock_rule(rs, rng), Geo()
    for size, x, y in ((3.6, 0.0, 0.0), (2.6, 2.7, 1.0), (2.2, -2.3, 1.4), (1.6, 0.8, -2.4), (1.3, -1.6, -1.9)):
        p = boulder_part(rng, rule, (size, size * rng.uniform(0.8, 1.0), size * rng.uniform(0.7, 0.9)), 1, 0.15)
        g.add(p, T(x, y, 0) @ R(rng.uniform(0, 360), "Z") @ R(rng.uniform(-15, 15), "X"))
    return g


def rock_arch(rs, seed):
    rng = random.Random(seed)
    rule, g = rock_rule(rs, rng), Geo()
    steps = 9
    path, radii = [Vector((-11.0, 0.0, -1.5))], [4.4]
    for i in range(steps + 1):
        a = math.pi * (1 - i / steps)
        path.append(Vector((11.0 * math.cos(a), rng.uniform(-0.6, 0.6), 15.0 * math.sin(a))))
        radii.append(2.6 + 1.5 * abs(math.cos(a)) ** 2)
    path.append(Vector((11.0, 0.0, -1.5)))
    radii.append(4.4)
    g.add(tube(path, radii, 6, rule, start=rule, end=rule, phase=0.3, jitter=0.45, rng=rng))
    return g


def rock_slab_stack(rs, seed):
    rng = random.Random(seed)
    rule, g, z = rock_rule(rs, rng), Geo(), 0.0
    for sx, sy, h in ((12.0, 9.0, 2.4), (10.0, 7.5, 2.1), (7.6, 6.0, 1.9), (5.2, 4.2, 1.6)):
        part = slab(sx, sy, h, 0.5, 1.4, rule, rule, rule, 0.22, rng)
        m = T(rng.uniform(-0.8, 0.8), rng.uniform(-0.8, 0.8), z) @ R(rng.uniform(-22, 22), "Z") @ R(rng.uniform(-3, 3), "X")
        g.add(part, m)
        z += h - 0.15
    return g


def rock_spire(rs, seed):
    rng = random.Random(seed)
    rule = rock_rule(rs, rng)
    profile = [(4.6, 0.0), (4.3, 3.5), (3.5, 8.0), (3.2, 12.0), (2.2, 17.0), (1.2, 21.0), (0.0, 23.5)]
    part = lathe(profile, 6, rule, bottom=rule, twist=0.35, jitter=0.55, rng=rng, radial=lambda j: rng.uniform(0.85, 1.12))
    return Geo().add(part)


# ---------------------------------------------------------------- coral
def coral_branch(cs, seed):
    """staghorn: three arms from a knob, each splitting, with pale tips"""
    rng = random.Random(seed)
    g = Geo()

    def branch(p, d, length, r, depth):
        end = p + d * length
        if depth == 0:
            g.add(tube([p, end, end + d * r * 1.6], [r, r * 0.8, 0.0], 5, [cs["main"], cs["tip"]], start=cs["main"], rng=rng))
            return
        g.add(tube([p, end], [r, r * 0.82], 5, cs["main"], start=cs["main"], end=cs["main"], phase=rng.uniform(0, 1)))
        kids = 2 if depth == 2 else rng.choice((1, 2))
        for k in range(kids):
            side = d.cross(UP if abs(d.z) < 0.95 else Vector((1.0, 0.0, 0.0))).normalized()
            side.rotate(Matrix.Rotation(rng.uniform(0, TAU) if kids == 1 else k * math.pi + rng.uniform(-0.4, 0.4), 3, d))
            nd = (d + side * math.tan(math.radians(rng.uniform(25, 38))) + UP * 0.25).normalized()
            branch(end - d * r * 0.4, nd, length * rng.uniform(0.62, 0.78), r * 0.74, depth - 1)

    g.add(icosphere(1, 1.0, cs["dark"], 0.15, rng), S(1.3, 1.3, 0.55))
    for i in range(3):
        az = TAU * i / 3 + rng.uniform(-0.3, 0.3)
        tilt = math.radians(rng.uniform(18, 32))
        d = Vector((math.cos(az) * math.sin(tilt), math.sin(az) * math.sin(tilt), math.cos(tilt)))
        branch(Vector((math.cos(az) * 0.3, math.sin(az) * 0.3, 0.2)), d, rng.uniform(2.2, 2.8), 0.42, 2)
    return g


def coral_brain(cs, seed):
    rng = random.Random(seed)
    profile = [(2.7, 0.0), (3.0, 0.9), (2.7, 2.0), (1.9, 2.8), (0.9, 3.25), (0.0, 3.4)]
    sides = 10

    def band(k):
        return lambda j: cs["dark"] if (j + 2 * k) % 3 == 0 else cs["main"]  # dark grooves winding round the dome

    part = lathe(profile, sides, [band(k) for k in range(len(profile) - 1)], bottom=cs["dark"], jitter=0.12, rng=rng)
    return Geo().add(part, S(1.0, 0.85, 1.0))


def coral_fan(cs, seed):
    """sea fans: a big fan and a small one behind it, ribbed in two colours, on short stalks"""
    rng = random.Random(seed)
    g = Geo()
    for scale, ang, x in ((1.0, 0.0, 0.0), (0.62, 38.0, 1.6)):
        w, h, base = 4.6 * scale, 6.6 * scale, 1.2 * scale
        arc = [(w * math.cos(a) * rng.uniform(0.92, 1.05), base + h * math.sin(a) * rng.uniform(0.92, 1.05))
               for a in (math.radians(d) for d in range(5, 180, 17))]
        outline = [(0.35 * scale, base * 0.9)] + arc + [(-0.35 * scale, base * 0.9)]
        fan = plate(outline, 0.32 * scale, lambda i: cs["tip"] if i % 2 else cs["main"], cs["dark"], hub=(0.0, base))
        fan.warp(lambda v: (v.x, v.y + 0.07 * v.x * v.x, v.z))  # a gentle cup
        stalk = tube([(0, 0, 0), (0, 0, base + 0.4)], [0.4 * scale, 0.3 * scale], 5, cs["dark"], start=cs["dark"], end=cs["dark"])
        m = T(x, 0.9 * scale - 0.9, 0) @ R(ang, "Z")
        g.add(fan, m).add(stalk, m)
    return g


def coral_tube(cs, seed):
    """organ-pipe tubes of different heights, open at the top"""
    rng = random.Random(seed)
    g = Geo()
    for x, y, r, h in ((0.0, 0.0, 0.85, 5.6), (1.5, 0.5, 0.7, 4.0), (-1.3, 0.7, 0.75, 3.4), (0.4, -1.4, 0.6, 2.6), (-0.8, -1.1, 0.5, 1.9)):
        h *= rng.uniform(0.9, 1.1)
        profile = [(r, 0.0), (r * 1.08, h), (r * 0.62, h), (r * 0.62, h - 0.6)]
        part = lathe(profile, 6, [cs["main"], cs["tip"], cs["dark"]], bottom=cs["main"], top=cs["dark"], phase=rng.uniform(0, 1))
        tilt = rng.uniform(-9, 9)
        g.add(part, T(x, y, 0) @ R(tilt, "X") @ R(-tilt * 0.6, "Y"))
    return g


def coral_table(cs, seed):
    """a flat-topped table on a stalk, a smaller one tucked below"""
    rng = random.Random(seed)
    g = Geo()
    for scale, x, y, z in ((1.0, 0.0, 0.0, 0.0), (0.55, 3.0, 2.0, -1.0)):
        st = 2.6 * scale + z
        stalk = lathe([(0.9 * scale, 0.0), (0.55 * scale, st)], 6, cs["dark"], bottom=cs["dark"])
        spokes = [rng.uniform(0.82, 1.12) for _ in range(9)]
        profile = [(0.9 * scale, st - 0.3), (5.4 * scale, st + 0.5 * scale), (5.8 * scale, st + 1.0 * scale),
                   (4.6 * scale, st + 1.35 * scale), (0.0, st + 1.5 * scale)]
        top = lathe(profile, 9, [cs["dark"], cs["tip"], cs["main"], cs["main"]], bottom=cs["dark"], rng=rng, jitter=0.1,
                    radial=lambda j: spokes[j])
        g.add(stalk, T(x, y, 0)).add(top, T(x, y, 0) @ R(rng.uniform(-4, 4), "X"))
    return g


# ---------------------------------------------------------------- kelp and sea grass
def kelp(seed, height, blades, blade_length):
    """a stipe swaying up from a holdfast, leaves spiralling off it with gas bladders at their bases, a leaf on top"""
    rng = random.Random(seed)
    g = Geo()
    n = blades + 2
    ph = rng.uniform(0, TAU)
    path = [Vector((1.1 * math.sin(k * 0.9 + ph) * k / n, 0.7 * math.cos(k * 0.7 + ph) * k / n, height * k / (n - 1)))
            for k in range(n)]
    radii = [0.5 - 0.25 * k / (n - 1) for k in range(n)]
    g.add(tube(path, radii, 4, "kelp_stipe", start="kelp_stipe", end="kelp_stipe", phase=math.pi / 4))
    g.add(icosphere(1, 1.0, "kelp_stipe", 0.2, rng), S(1.2, 1.2, 0.5))
    for k in range(1, blades + 1):
        base = path[k] + (path[k + 1] - path[k]) * 0.3
        az = k * 2.4 + ph
        out = Vector((math.cos(az), math.sin(az), 0.0))
        d = (out * 0.5 + UP).normalized()
        L = blade_length * rng.uniform(0.85, 1.1)
        leaf = [base, base + d * L * 0.3, base + d * L * 0.7 + out * L * 0.08, base + d * L + out * L * 0.2 - UP * L * 0.06]
        g.add(ribbon(leaf, [0.4, 2.8, 2.2, 0.0], out, 0.14, "kelp" if k % 2 else "kelp_light"))
        g.add(icosphere(1, 0.36, "kelp_bladder"), T(*(base + d * 0.25)))
    top = path[-1]
    tip_out = (path[-1] - path[-2]).normalized()
    side = tip_out.cross(UP).normalized() if abs(tip_out.z) < 0.99 else Vector((1.0, 0.0, 0.0))
    g.add(ribbon([top, top + tip_out * blade_length * 0.5, top + tip_out * blade_length], [0.4, 2.4, 0.0], side, 0.14, "kelp_light"))
    return g


def sea_grass(seed, count, spread, hmin, hmax):
    rng = random.Random(seed)
    g = Geo()
    for i in range(count):
        a, r = rng.uniform(0, TAU), spread * math.sqrt(rng.random())
        p = Vector((r * math.cos(a), r * math.sin(a), 0.0))
        lean = Vector((math.cos(a + rng.uniform(-0.8, 0.8)), math.sin(a + rng.uniform(-0.8, 0.8)), 0.0))
        h = rng.uniform(hmin, hmax)
        path = [p, p + UP * h * 0.4 + lean * h * 0.06, p + UP * h * 0.75 + lean * h * 0.22, p + UP * h + lean * h * 0.42]
        g.add(ribbon(path, [0.42, 0.36, 0.24, 0.0], lean, 0.07, "grass" if i % 3 else "grass_light"))
    return g


# ---------------------------------------------------------------- shells and starfish
def shell_scallop(seed):
    """a ribbed fan shell lying on the sand"""
    n = 9
    arc = [Vector((1.05 * math.cos(a), 1.0 * math.sin(a) - 0.35, 0.0)) for a in (math.radians(15 + 150 * i / (n - 1)) for i in range(n))]
    hinge = Vector((0.0, -0.45, 0.12))
    mid = [hinge.lerp(p, 0.55) + Vector((0, 0, 0.42 + (0.07 if i % 2 else -0.04))) for i, p in enumerate(arc)]
    verts = [hinge] + arc + mid
    faces, cols = [], []
    for i in range(n - 1):
        c = "shell" if i % 2 else "shell_light"
        faces += [(0, 1 + n + i, 1 + n + i + 1), (1 + n + i, 1 + i, 2 + i, 1 + n + i + 1)]
        cols += [c, c]
    faces += [(0, n, 2 * n), (0, 1 + n, 1)]  # the closing sides
    cols += ["shell", "shell"]
    faces.append(tuple([0] + list(range(n, 0, -1))))  # the flat underside
    cols.append("shell")
    g = Geo().add(Part(verts, faces, cols))
    g.add(box(0.7, 0.32, 0.2, "shell"), T(0, -0.5, 0.1))  # the hinge's ears
    return g


def shell_conch(seed):
    """a spiral shell on its side: a tube winding to a point, the pink mouth open"""
    rng = random.Random(seed)
    n = 7
    path, radii = [], []
    for i in range(n):
        t = i / (n - 1)
        a = 2.6 * math.pi * t
        path.append(Vector((2.6 * t - 1.0, 0.55 * (1 - t) * math.cos(a), 0.55 * (1 - t) * math.sin(a))))
        radii.append(0.0 if i == n - 1 else 0.85 * (1 - t) ** 0.8 + 0.08)
    radii[0] = 1.0
    cols = ["conch_pink"] + [("conch" if i % 2 else "shell_light") for i in range(n - 2)]
    return Geo().add(tube(path, radii, 6, cols, start="conch_pink", phase=rng.uniform(0, 1)))


def starfish(seed):
    rng = random.Random(seed)
    pts = []
    for i in range(10):
        a = TAU * i / 10 + math.pi / 2
        r = 1.35 * rng.uniform(0.92, 1.05) if i % 2 == 0 else 0.5
        pts.append(Vector((r * math.cos(a), r * math.sin(a), 0.1 if i % 2 == 0 else 0.22)))
    top = Vector((0.0, 0.0, 0.42))
    base = [Vector((p.x * 0.96, p.y * 0.96, 0.0)) for p in pts]
    verts = [top] + pts + base + [Vector()]
    faces, cols = [], []
    for i in range(10):
        i2 = (i + 1) % 10
        faces.append((0, 1 + i, 1 + i2))
        cols.append("star" if i % 2 else "star_light")  # a pale ridge down each arm
        faces.append((1 + i, 11 + i, 11 + i2, 1 + i2))
        cols.append("star")
        faces.append((21, 11 + i2, 11 + i))
        cols.append("star")
    return Geo().add(Part(verts, faces, cols))


def sea_urchin(seed):
    rng = random.Random(seed)
    g = Geo()
    verts, faces = ico(1, 0.8)
    g.add(Part(verts, faces, ["urchin"] * len(faces)), T(0, 0, 0.75))
    for v in verts:
        d = v.normalized()
        if d.z < -0.5:
            continue
        spike = lathe([(0.2, 0.0), (0.0, rng.uniform(1.0, 1.4))], 3, "urchin_spike", phase=rng.uniform(0, 1))
        g.add(spike, T(0, 0, 0.75) @ T(*(d * 0.6)) @ rot_towards(d))
    return g


# ---------------------------------------------------------------- dock props
def crate_part(size, frame_cols=("wood_dark", "wood")):
    """a box whose faces are a frame of planks round a recessed panel"""
    h, f, rec = size / 2, size * 0.13, size * 0.04
    verts, faces, cols = [], [], []
    for n in (Vector((1, 0, 0)), Vector((-1, 0, 0)), Vector((0, 1, 0)), Vector((0, -1, 0)), UP, -UP):
        v = UP if abs(n.z) < 0.5 else Vector((0, 1, 0))
        u = v.cross(n)
        c = n * h
        corners = [(-1, -1), (1, -1), (1, 1), (-1, 1)]
        o = len(verts)
        verts += [c + u * a * h + v * b * h for a, b in corners]
        verts += [c + u * a * (h - f) + v * b * (h - f) for a, b in corners]
        verts += [c - n * rec + u * a * (h - f) + v * b * (h - f) for a, b in corners]
        for i in range(4):
            i2 = (i + 1) % 4
            faces.append((o + i, o + i2, o + 4 + i2, o + 4 + i))
            cols.append(frame_cols[0])
            faces.append((o + 4 + i, o + 4 + i2, o + 8 + i2, o + 8 + i))
            cols.append(frame_cols[0])
        faces.append((o + 8, o + 9, o + 10, o + 11))
        cols.append(frame_cols[1])
    return Part(verts, faces, cols, closed=False)


def crate(seed):
    return Geo().add(crate_part(4.0), T(0, 0, 2.0))


def crate_stack(seed):
    rng = random.Random(seed)
    g = Geo()
    g.add(crate_part(4.0), T(-2.1, 0, 2.0) @ R(rng.uniform(-6, 6), "Z"))
    g.add(crate_part(4.0), T(2.1, 0.3, 2.0) @ R(rng.uniform(-8, 8), "Z"))
    g.add(crate_part(3.2), T(0.2, 0.1, 5.6) @ R(rng.uniform(10, 20), "Z"))
    return g


def dock_post(seed):
    """a piling: an octagonal post with a chamfered top and a rope wrapped round it"""
    g = Geo()
    profile = [(0.85, 0.0), (0.85, 3.0), (0.85, 9.4), (0.62, 9.85), (0.0, 10.0)]
    g.add(lathe(profile, 8, ["wood_dark", "wood", "wood", "wood_light"], bottom="wood_dark", phase=math.pi / 8))
    for z in (7.2, 7.75):
        g.add(lathe([(0.98, z), (1.02, z + 0.25), (0.98, z + 0.5)], 8, "rope", bottom="rope", top="rope"))
    return g


def buoy(seed):
    """a striped channel buoy with a lamp on a mast"""
    g = Geo()
    profile = [(0.7, 0.0), (1.5, 0.35), (1.8, 1.0), (1.75, 1.6), (1.35, 2.2), (0.9, 2.55), (0.4, 2.7)]
    g.add(lathe(profile, 8, ["buoy_red", "buoy_red", "buoy_white", "buoy_red", "buoy_white", "buoy_red"], bottom="metal", top="buoy_red"))
    g.add(lathe([(0.16, 2.6), (0.16, 4.3)], 6, "metal", top="metal"))
    g.add(lathe([(0.32, 4.2), (0.32, 4.75), (0.18, 4.95)], 6, ["lamp", "metal"], bottom="metal", top="metal"))
    return g


def rope_coil(seed):
    rng = random.Random(seed)
    g = Geo()
    for r, z in ((1.15, 0.25), (1.05, 0.72), (0.85, 1.17)):
        ring = [(r * math.cos(TAU * i / 9), r * math.sin(TAU * i / 9), z + 0.03 * math.sin(i)) for i in range(9)]
        g.add(tube(ring, [0.26] * 9, 4, "rope", loop=True, phase=math.pi / 4))
    end = [(0.85, 0.0, 1.2), (1.3, 0.5, 1.0), (1.9, 0.9, 0.3), (2.5, 1.1, 0.25)]
    g.add(tube(end, [0.24] * 4, 4, "rope", start="rope", end="wood_light", phase=math.pi / 4))
    return g


def barrel(seed):
    g = Geo()
    profile = [(1.3, 0.0), (1.36, 0.35), (1.38, 0.6), (1.5, 1.2), (1.55, 1.75), (1.5, 2.3), (1.38, 2.9), (1.36, 3.15), (1.3, 3.5)]
    bands = ["wood", "metal", "wood", "wood_dark", "wood_dark", "wood", "metal", "wood"]
    g.add(lathe(profile, 8, bands, bottom="wood_dark", top="wood_light", phase=math.pi / 8))
    return g


def lifebuoy(seed):
    """a ring buoy standing on its edge, for hanging on the dock's rails"""
    ring = [(1.4 * math.cos(TAU * i / 8), 0.0, 1.8 + 1.4 * math.sin(TAU * i / 8)) for i in range(8)]
    cols = ["buoy_red" if (i // 2) % 2 else "buoy_white" for i in range(8)]
    return Geo().add(tube(ring, [0.42] * 8, 6, cols, loop=True))


# ---------------------------------------------------------------- the list
PROPS = []


def prop(name, category, build, zones, note, colour_set=None, view=28):
    PROPS.append({"name": name, "category": category, "build": build, "zones": zones, "note": note, "colourSet": colour_set,
                  "view": view})


for rs_name, rs in ROCK_SETS.items():
    deep = rs_name == "deep"
    prop(f"rock_boulder_a_{rs_name}", "rock", lambda rs=rs: rock_boulder(rs, 11, (10.0, 8.0, 7.0)),
         DEEP if deep else ["Dock", "Shallows", "Coral Reef", "Kelp Forest", "Shipwrecks"],
         "a round boulder; scale 0.5-3x, any turn", rs_name)
    prop(f"rock_boulder_b_{rs_name}", "rock", lambda rs=rs: rock_boulder(rs, 23, (14.0, 11.0, 5.5)),
         DEEP if deep else SHALLOW, "a wide, low boulder: terrace edges, the lane's sides", rs_name)
    prop(f"rock_cluster_{rs_name}", "rock", lambda rs=rs: rock_cluster(rs, 31), DEEP if deep else SHALLOW + ["Dock"],
         "small stones to scatter round the big rocks", rs_name)
    prop(f"rock_arch_{rs_name}", "rock", lambda rs=rs: rock_arch(rs, 41),
         ["Midnight", "Vents", "Bone Graveyard"] if deep else ["Coral Reef", "Kelp Forest", "Open Blue"],
         "an arch to ride through: 16 studs clear under the top", rs_name)
    prop(f"rock_slab_stack_{rs_name}", "rock", lambda rs=rs: rock_slab_stack(rs, 53),
         ["Twilight", "Midnight", "The Underworld"] if deep else ["Shallows", "Coral Reef", "Shipwrecks", "Open Blue"],
         "stacked flat slabs: ledges and steps", rs_name)
    prop(f"rock_spire_{rs_name}", "rock", lambda rs=rs: rock_spire(rs, 67),
         ["Vents", "Bone Graveyard", "The Underworld"] if deep else ["Kelp Forest", "Shipwrecks", "Open Blue"],
         "a tall spire; scale up for far-off silhouettes", rs_name)

CORAL_ZONES = {"pink": ["Shallows", "Coral Reef"], "orange": ["Shallows", "Coral Reef", "Shipwrecks"],
               "purple": ["Coral Reef", "Shipwrecks", "Open Blue", "Twilight"]}
for cs_name, cs in CORAL_SETS.items():
    z = CORAL_ZONES[cs_name]
    prop(f"coral_branch_{cs_name}", "coral", lambda cs=cs: coral_branch(cs, 101), z, "staghorn, pale tips", cs_name)
    prop(f"coral_brain_{cs_name}", "coral", lambda cs=cs: coral_brain(cs, 103), z, "a grooved dome", cs_name)
    prop(f"coral_fan_{cs_name}", "coral", lambda cs=cs: coral_fan(cs, 107), z, "two sea fans; face them across the current",
         cs_name)
    prop(f"coral_tube_{cs_name}", "coral", lambda cs=cs: coral_tube(cs, 109), z, "organ-pipe tubes, open tops", cs_name)
    prop(f"coral_table_{cs_name}", "coral", lambda cs=cs: coral_table(cs, 113), z + (["Open Blue"] if "Open Blue" not in z else []),
         "table coral; big ones make shelves", cs_name)

prop("kelp_tall", "kelp", lambda: kelp(201, 33.0, 8, 8.0), ["Kelp Forest"], "a 40-stud strand: the forest's trees")
prop("kelp_short", "kelp", lambda: kelp(203, 14.0, 5, 6.0), ["Kelp Forest", "Coral Reef", "Shipwrecks"],
     "undergrowth and edges")
prop("sea_grass_clump", "kelp", lambda: sea_grass(211, 9, 1.0, 2.2, 3.6), ["Dock", "Shallows", "Coral Reef"],
     "a tuft of sea grass")
prop("sea_grass_patch", "kelp", lambda: sea_grass(213, 16, 3.0, 1.6, 3.0), ["Dock", "Shallows", "Kelp Forest"],
     "a wider patch to carpet the sand")
prop("shell_scallop", "shell", lambda: shell_scallop(301), ["Dock", "Shallows", "Coral Reef"], "lies flat", view=50)
prop("shell_conch", "shell", lambda: shell_conch(303), ["Shallows", "Coral Reef", "Shipwrecks"], "a spiral shell on its side",
     view=40)
prop("starfish", "shell", lambda: starfish(307), ["Dock", "Shallows", "Coral Reef", "Shipwrecks"], "lies flat", view=55)
prop("sea_urchin", "shell", lambda: sea_urchin(311), ["Coral Reef", "Kelp Forest", "Twilight"], "a spiky ball", view=35)
prop("crate", "dock", lambda: crate(401), ["Dock", "Shipwrecks"], "a 4-stud crate; sunk ones for the wrecks")
prop("crate_stack", "dock", lambda: crate_stack(403), ["Dock", "Shipwrecks"], "two crates and a small one on top")
prop("dock_post", "dock", lambda: dock_post(405), ["Dock"], "a piling with a rope wrap; 10 studs, sink its foot")
prop("buoy", "dock", lambda: buoy(407), ["Dock"], "a striped buoy with a lamp: the lagoon's gap, the dive board")
prop("rope_coil", "dock", lambda: rope_coil(409), ["Dock", "Shipwrecks"], "a coil with a loose end")
prop("barrel", "dock", lambda: barrel(411), ["Dock", "Shipwrecks"], "a banded barrel")
prop("lifebuoy", "dock", lambda: lifebuoy(413), ["Dock"], "a ring buoy on its edge, for the rails")


# ---------------------------------------------------------------- scene, material, meshes
bpy.ops.wm.read_factory_settings(use_empty=True)
try:
    bpy.ops.preferences.addon_enable(module="io_scene_fbx")
except Exception:
    pass
scene = bpy.context.scene
scene.unit_settings.system = "METRIC"
scene.unit_settings.scale_length = 1.0
for engine in ("BLENDER_EEVEE", "BLENDER_EEVEE_NEXT"):
    try:
        scene.render.engine = engine
        break
    except TypeError:
        pass
scene.view_settings.view_transform = "Standard"
try:
    scene.eevee.taa_render_samples = 32
except AttributeError:
    pass

PALETTE_PATH = os.path.join(OUT, "palette.png")
write_palette(PALETTE_PATH)


def palette_material():
    m = bpy.data.materials.new("PropPalette")
    try:
        m.use_nodes = True
    except Exception:
        pass
    nt = m.node_tree
    bsdf = nt.nodes.get("Principled BSDF")
    tex = nt.nodes.new("ShaderNodeTexImage")
    tex.image = bpy.data.images.load(PALETTE_PATH)
    tex.interpolation = "Closest"
    nt.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = 0.7
    if "Specular IOR Level" in bsdf.inputs:
        bsdf.inputs["Specular IOR Level"].default_value = 0.2
    return m


MAT = palette_material()


def build_object(name, geo):
    bm = bmesh.new()
    bverts = [bm.verts.new(v) for v in geo.verts]
    faces, cols, closed = [], [], []
    for f, c, cl in zip(geo.faces, geo.cols, geo.closed):
        try:
            faces.append(bm.faces.new([bverts[i] for i in f]))
        except ValueError:
            continue  # a duplicate or degenerate face
        cols.append(c)
        closed.append(cl)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
    bmesh.ops.recalc_face_normals(bm, faces=[f for f, cl in zip(faces, closed) if cl])
    uv = bm.loops.layers.uv.new("UVMap")
    for f, c in zip(faces, cols):
        if isinstance(c, Rule):
            c = c.fn(f.normal, f.calc_center_median())
        u = cell_uv(c)
        for loop in f.loops:
            loop[uv].uv = u
    bmesh.ops.triangulate(bm, faces=bm.faces, quad_method="BEAUTY", ngon_method="BEAUTY")
    # the pivot: bottom at 0, centred on the footprint (the lowest 0.4 studs)
    zmin = min(v.co.z for v in bm.verts)
    foot = [v.co for v in bm.verts if v.co.z < zmin + 0.4]
    cx = (min(p.x for p in foot) + max(p.x for p in foot)) / 2
    cy = (min(p.y for p in foot) + max(p.y for p in foot)) / 2
    for v in bm.verts:
        v.co -= Vector((cx, cy, zmin))
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    me.materials.append(MAT)
    for poly in me.polygons:
        poly.use_smooth = False
    ob = bpy.data.objects.new(name, me)
    scene.collection.objects.link(ob)
    return ob


def export_fbx(ob, path):
    bpy.ops.object.select_all(action="DESELECT")
    ob.select_set(True)
    bpy.context.view_layer.objects.active = ob
    bpy.ops.export_scene.fbx(filepath=path, use_selection=True, object_types={"MESH"}, apply_unit_scale=True,
                             apply_scale_options="FBX_SCALE_NONE", axis_forward="-Z", axis_up="Y", mesh_smooth_type="FACE",
                             use_mesh_modifiers=False, add_leaf_bones=False, bake_anim=False, path_mode="COPY",
                             embed_textures=True)


# ---------------------------------------------------------------- build, export, record
built = []
for p in PROPS:
    if ONLY and p["name"] not in ONLY:
        continue
    ob = build_object(p["name"], p["build"]())
    path = os.path.join(OUT, p["name"] + ".fbx")
    export_fbx(ob, path)
    xs = [v.co.x for v in ob.data.vertices]
    ys = [v.co.y for v in ob.data.vertices]
    zs = [v.co.z for v in ob.data.vertices]
    tris = sum(len(poly.vertices) - 2 for poly in ob.data.polygons)
    rec = {
        "name": p["name"],
        "file": os.path.basename(path),
        "category": p["category"],
        "colourSet": p["colourSet"],
        # Roblox axes: Y is up
        "sizeStuds": {"x": round(max(xs) - min(xs), 2), "y": round(max(zs) - min(zs), 2), "z": round(max(ys) - min(ys), 2)},
        "tris": tris,
        "kb": round(os.path.getsize(path) / 1024, 1),
        "zones": p["zones"],
        "note": p["note"],
    }
    built.append((p, ob, rec))
    print(f"prop_kit: {p['name']:<26} {tris:>4} tris  {rec['sizeStuds']}  {rec['kb']} KB")

if not ONLY:
    manifest = {
        "about": "Ride a Fish world props, built by tools/blender/prop_kit.py. Do not edit by hand: rerun the kit.",
        "units": "1 unit = 1 stud (a player is about 5 studs tall). sizeStuds is in Roblox axes (y is up). In Studio's 3D "
                 "Importer check the size against sizeStuds (File Dimensions: Studs) before placing.",
        "pivot": "the base: the bottom sits at y = 0, centred on the footprint",
        "texture": "palette.png (each FBX embeds it): one flat colour cell per colour; one material per prop",
        "zones": ["Dock"] + SHALLOW + DEEP,
        "props": [rec for _, _, rec in built],
    }
    with open(os.path.join(OUT, "props.json"), "w") as f:
        json.dump(manifest, f, indent=2)
        f.write("\n")

# ---------------------------------------------------------------- the contact sheet
if SHEET:
    TILE, COLS = 300, 7
    BG = {"rock": "#E3ECF1", "coral": "#FCEAF0", "kelp": "#E6F4E2", "shell": "#FBF0E1", "dock": "#F1EAE1"}

    world = bpy.data.worlds.new("World")
    try:
        world.use_nodes = True
    except Exception:
        pass
    bg_node = world.node_tree.nodes.get("Background")
    bg_node.inputs["Color"].default_value = tuple(srgb_to_linear(c / 255) for c in hex_srgb("#FEF8F1")) + (1.0,)
    bg_node.inputs["Strength"].default_value = 0.6
    scene.world = world
    sun_data = bpy.data.lights.new("Key", "SUN")
    sun_data.energy = 2.4
    sun_data.angle = math.radians(14)
    sun = bpy.data.objects.new("Key", sun_data)
    scene.collection.objects.link(sun)
    sun.rotation_euler = Vector((5.0, 7.0, 9.0)).to_track_quat("Z", "Y").to_euler()

    cam_data = bpy.data.cameras.new("Cam")
    cam_data.type = "ORTHO"
    cam_data.clip_start = 0.05
    cam_data.clip_end = 4000.0
    cam = bpy.data.objects.new("Cam", cam_data)
    scene.collection.objects.link(cam)
    scene.camera = cam

    label_mat = bpy.data.materials.new("Label")
    try:
        label_mat.use_nodes = True
    except Exception:
        pass
    lb = label_mat.node_tree.nodes.get("Principled BSDF")
    lb.inputs["Base Color"].default_value = (0.0, 0.0, 0.0, 1.0)
    lb.inputs["Emission Color"].default_value = tuple(srgb_to_linear(c / 255) for c in hex_srgb("#2B3442")) + (1.0,)
    lb.inputs["Emission Strength"].default_value = 1.0
    label_data = bpy.data.curves.new("Label", "FONT")
    label_data.align_x = "CENTER"
    label_data.materials.append(label_mat)
    label = bpy.data.objects.new("Label", label_data)
    scene.collection.objects.link(label)
    label.parent = cam

    scene.render.film_transparent = True
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGBA"
    scene.render.resolution_x = scene.render.resolution_y = TILE
    scene.render.resolution_percentage = 100
    tiles_dir = tempfile.mkdtemp(prefix="prop_kit_")
    tiles = []
    for _, ob, _ in built:
        ob.hide_render = True
    for p, ob, rec in built:
        ob.hide_render = False
        el = math.radians(p["view"])
        az = math.radians(-125)
        d = Vector((math.cos(az) * math.cos(el), math.sin(az) * math.cos(el), math.sin(el)))  # towards the camera
        rot = (-d).to_track_quat("-Z", "Y")
        right, up = rot @ Vector((1, 0, 0)), rot @ Vector((0, 1, 0))
        corners = [Vector(c) for c in ob.bound_box]
        rs = [c.dot(right) for c in corners]
        us = [c.dot(up) for c in corners]
        w, h = max(rs) - min(rs), max(us) - min(us)
        size = max(w * 1.12, h * 1.12 / 0.78)
        mid = right * (max(rs) + min(rs)) / 2 + up * ((max(us) + min(us)) / 2 - size * 0.09)
        cam.location = mid + d * 600.0
        cam.rotation_euler = rot.to_euler()
        cam_data.ortho_scale = size
        s = rec["sizeStuds"]
        label_data.body = f"{p['name']}\n{s['x']:g} x {s['y']:g} x {s['z']:g} studs, {rec['tris']} tris"
        label_data.size = size * 0.047
        label.location = (0.0, -size * 0.405, -1.0)
        path = os.path.join(tiles_dir, p["name"] + ".png")
        scene.render.filepath = path
        bpy.ops.render.render(write_still=True)
        ob.hide_render = True
        tiles.append((path, BG[p["category"]]))

    rows = (len(tiles) + COLS - 1) // COLS
    W, H, gap = COLS * TILE, rows * TILE, 3
    sheet = np.ones((H, W, 4), np.float32)
    for i, (path, bg) in enumerate(tiles):
        img = bpy.data.images.load(path)
        px = np.empty(TILE * TILE * 4, np.float32)
        img.pixels.foreach_get(px)
        px = px.reshape(TILE, TILE, 4)
        bgc = np.array([c / 255 for c in hex_srgb(bg)], np.float32)
        a = px[:, :, 3:4]
        rgb = px[:, :, :3] * a + bgc * (1 - a)
        r, c = divmod(i, COLS)
        y0 = H - (r + 1) * TILE  # Blender images start at the bottom row
        sheet[y0 + gap : y0 + TILE - gap, c * TILE + gap : (c + 1) * TILE - gap, :3] = rgb[gap:-gap, gap:-gap]
        bpy.data.images.remove(img)
    out_img = bpy.data.images.new("props-sheet", W, H, alpha=False)
    out_img.pixels.foreach_set(sheet.ravel())
    out_img.filepath_raw = os.path.join(OUT, "props-sheet.png")
    out_img.file_format = "PNG"
    out_img.save()
    print("prop_kit: sheet", out_img.filepath_raw)
