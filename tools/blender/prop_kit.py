"""Prop kit: builds the world's props (rocks, coral, kelp and sea grass, shells, dock props) as chunky, faceted, low-poly meshes in
the creature look (flat colours, hard edges, toy proportions; Ride a Dino's broad style, never its models), exports each as its
own FBX, renders a contact sheet and writes props.json (name, file, size in studs, tris, suggested zones).

usage: blender --background --python tools/blender/prop_kit.py -- [out folder] [--only name,name] [--no-sheet]
  out folder defaults to art/props. A full run (no --only) also writes the clusters into props.json and clusters-sheet.png.
Round 2 (Subnautica's big readable alien-reef shapes, in our faceted look, never its models): layered mesas, pillars and cliff
walls in three rock sets, giant pillar and mushroom corals, fan plants, creeper vines, glow bulbs and mushrooms, vent chimneys,
a ribcage, floor patches; per-zone palettes; and CLUSTERS: matching set pieces (anchor, mid, filler and floor props) in small,
medium and huge, written as placements of the props so the map reuses the same meshes. Glowing faces export as <name>_glow.fbx.
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
    # round 2: sand floors, rock strata, the vents, deep coral, alien plants, glow, bone
    "sand": "#F2DFA7",
    "sand_dark": "#D9BF7E",
    "rock_band": "#A4B0C2",
    "deep_band": "#6A6597",
    "vent_rock": "#4A3A4C",
    "vent_rock_dark": "#33283A",
    "vent_top": "#6E5468",
    "glow_orange": "#FF8A3D",
    "teal": "#3FB8B0",
    "teal_tip": "#9FF2E4",
    "teal_dark": "#23807F",
    "fan_red": "#F0645A",
    "fan_red_light": "#FFB07A",
    "fan_red_dark": "#B83E45",
    "glow_pink": "#FF6FD8",
    "glow_yellow": "#FFE66B",
    "bone": "#EDE3CC",
    "bone_dark": "#BFAF8E",
    "vine": "#4E9A52",
    "vine_light": "#86CF62",
}
CELLS = 8  # palette.png is CELLS x CELLS cells
CELL_PX = 8
COLOUR_INDEX = {name: i for i, name in enumerate(PALETTE)}
assert len(PALETTE) <= CELLS * CELLS

ROCK_SETS = {
    "reef": {"rock": "rock", "dark": "rock_dark", "top": "rock_top", "band": "rock_band", "accent": "moss", "accentShare": 0.2},
    "deep": {"rock": "deep_rock", "dark": "deep_rock_dark", "top": "deep_top", "band": "deep_band", "accent": "glow",
             "accentShare": 0.15},
    "vent": {"rock": "vent_rock", "dark": "vent_rock_dark", "top": "vent_top", "band": "deep_rock_dark", "accent": "glow_orange",
             "accentShare": 0.12},
}
CORAL_SETS = {name: {"main": name, "tip": name + "_tip", "dark": name + "_dark"} for name in ("pink", "orange", "purple")}
CORAL_SETS["teal"] = {"main": "teal", "tip": "teal_tip", "dark": "teal_dark", "glow": "glow"}  # the deep set: glowing rims
PLANT_SETS = {
    "green": {"main": "vine", "light": "vine_light", "dark": "kelp_stipe", "tip": "kelp_light"},
    "red": {"main": "fan_red", "light": "fan_red_light", "dark": "fan_red_dark", "tip": "orange_tip"},
    "teal": {"main": "teal", "light": "teal_tip", "dark": "teal_dark", "tip": "glow"},
}
# glowing colours: props built with glow=True export these faces as a second mesh (<name>_glow.fbx) for a Neon MeshPart
GLOW_COLOURS = ("glow", "glow_pink", "glow_yellow", "glow_orange")

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


# ---------------------------------------------------------------- round 2: alien-reef set pieces
# Subnautica's lesson, in our own faceted look (never its models): big readable shapes, layered rock, tall pillars and giant
# mushroom corals, vines that sway, glow in the deep. Fronts face +Y here (-Z in Roblox, the LookVector).
def strata_rule(rs, rng, side):
    """a rock layer's colour: sand or moss on top, dark underneath, the layer's own band colour round the sides"""

    def pick(n, c):
        if n.z > 0.72:
            return rs["accent"] if rng.random() < rs["accentShare"] else rs["top"]
        if n.z < -0.4:
            return rs["dark"]
        return rs["dark"] if rng.random() < 0.18 else side

    return Rule(pick)


def strata_layer(rng, rule, r_bot, r_top, z, h, sides, jitter=0.25):
    """one layer of a layered rock, wider at its lip than its foot so the stack reads as ledges"""
    spokes = [rng.uniform(0.82, 1.16) for _ in range(sides)]
    profile = [(r_bot, z), (r_top * 1.04, z + h * 0.78), (r_top * 0.9, z + h)]
    return lathe(profile, sides, rule, bottom=rule, top=rule, phase=rng.uniform(0, TAU), jitter=jitter, rng=rng,
                 radial=lambda j: spokes[j])


def rock_layers(rs, seed, layers, sides, squash, drift):
    rng = random.Random(seed)
    g, z, x, y = Geo(), 0.0, 0.0, 0.0
    for i, (rb, rt, h) in enumerate(layers):
        rule = strata_rule(rs, rng, rs["band"] if i % 2 else rs["rock"])
        g.add(strata_layer(rng, rule, rb, rt, z, h, sides), T(x, y, 0) @ S(squash[0], squash[1], 1.0))
        z += h - 0.25
        x += rng.uniform(-drift, drift)
        y += rng.uniform(-drift, drift)
    return g


def rock_mesa(rs, seed):
    """a layered table rock: four strata, the middle one overhanging"""
    return rock_layers(rs, seed, ((8.6, 9.6, 3.2), (8.2, 10.0, 3.0), (7.4, 8.8, 2.8), (5.6, 7.0, 2.4)), 8, (1.25, 0.85), 0.7)


def rock_pillar(rs, seed):
    """a tall leaning column of strata with a wide flat cap: a hoodoo, for skylines and the lane's sides"""
    layers = ((5.0, 4.6, 4.2), (4.3, 4.1, 4.0), (3.8, 4.3, 3.6), (3.6, 3.5, 4.0), (3.3, 3.9, 3.4), (3.4, 7.2, 2.6), (6.2, 5.4, 1.6))
    return rock_layers(rs, seed, layers, 6, (1.0, 1.0), 0.6)


def strata_block(sx, sy, h, z, rule, rng, taper=0.92, jitter=0.35):
    rings = [cut_rect(sx, sy, 1.6, z), cut_rect(sx * taper, sy * taper, 1.4, z + h)]
    rings = [[jittered(v, rng, jitter) for v in ring] for ring in rings]
    return loft(rings, rule, rule, rule)


def rock_wall(rs, seed):
    """a stepped cliff of three strata columns, flat at the back: lines the lane's sides, its face to the front (+Y)"""
    rng = random.Random(seed)
    g = Geo()
    depth = 11.0
    for cx, w, n in ((-11.5, 14.0, 3), (0.5, 13.0, 5), (11.5, 12.0, 4)):
        z, sy = 0.0, depth
        for i in range(n):
            h = rng.uniform(3.2, 4.2)
            rule = strata_rule(rs, rng, rs["band"] if i % 2 else rs["rock"])
            m = T(cx + rng.uniform(-0.6, 0.6), -(depth - sy) / 2 + rng.uniform(-0.3, 0.3), 0) @ R(rng.uniform(-3, 3), "Z")
            g.add(strata_block(w, sy, h, z, rule, rng), m)
            z += h - 0.2
            sy -= rng.uniform(1.0, 1.6)
            w -= rng.uniform(0.4, 1.0)
    return g


def coral_pillar(cs, seed):
    """giant tube coral: ringed pillars up to 20 studs, open at the top (glowing inside in the deep set)"""
    rng = random.Random(seed)
    g = Geo()
    inner = cs.get("glow", cs["dark"])
    for x, y, r, segs, sh, sides in ((0.0, 0.0, 1.0, 5, 4.0, 6), (2.3, 0.8, 0.8, 3, 3.8, 6), (-2.0, 1.1, 0.75, 3, 3.0, 5),
                                     (0.7, -2.1, 0.6, 2, 2.8, 5)):
        sh *= rng.uniform(0.9, 1.1)
        profile, z = [(r, 0.0)], 0.0
        for _ in range(segs):
            profile += [(r * 0.86, z + sh * 0.78), (r * 1.2, z + sh)]
            z += sh
        profile += [(r * 0.74, z + 0.1), (r * 0.7, z - 0.9)]
        cols = [cs["main"], cs["tip"]] * segs + [cs["tip"], inner]
        part = lathe(profile, sides, cols, bottom=cs["main"], top=inner, phase=rng.uniform(0, 1), jitter=0.06, rng=rng)
        tilt = rng.uniform(-7, 7)
        g.add(part, T(x, y, 0) @ R(tilt, "X") @ R(-tilt * 0.7, "Y"))
    return g


def mushroom_cap(rng, cs, rad, h, neck, sides, rim):
    k = min(max(rad / 7.0, 0.45), 1.2)  # small caps are thinner
    spokes = [rng.uniform(0.86, 1.12) for _ in range(sides)]
    profile = [(neck, h - 0.7 * k), (rad * 0.9, h + 0.15 * k), (rad, h + 0.75 * k), (rad * 0.84, h + 1.35 * k), (rad * 0.4, h + 1.8 * k),
               (0.0, h + 1.95 * k)]
    return lathe(profile, sides, [cs["dark"], rim, cs["main"], cs["main"], cs["tip"]], bottom=cs["dark"], phase=rng.uniform(0, TAU),
                 jitter=0.12, rng=rng, radial=lambda j: spokes[j])


def coral_mushroom(cs, seed):
    """a giant mushroom coral: three domed tiers on a thick stalk, a little one beside it; ride under the big cap"""
    rng = random.Random(seed)
    g = Geo()
    rim = cs.get("glow", cs["tip"])
    g.add(lathe([(1.9, 0.0), (1.3, 2.8), (1.1, 5.6), (1.4, 8.4)], 7, cs["dark"], bottom=cs["dark"], top=cs["dark"], jitter=0.12, rng=rng))
    for i, (rad, h, x, y, sides) in enumerate(((9.0, 8.4, 0.0, 0.0, 10), (5.8, 10.6, 1.8, -1.2, 8), (3.6, 12.6, -1.2, 0.9, 7))):
        if i:
            g.add(lathe([(0.8, h - 2.6), (0.65, h)], 5, cs["dark"], bottom=cs["dark"], top=cs["dark"]), T(x, y, 0))
        g.add(mushroom_cap(rng, cs, rad, h, 1.4 if i == 0 else 0.75, sides, rim), T(x, y, 0) @ R(rng.uniform(-5, 5), "X"))
    g.add(lathe([(0.7, 0.0), (0.5, 2.4)], 5, cs["dark"], bottom=cs["dark"], top=cs["dark"]), T(8.5, 5.5, 0))
    g.add(mushroom_cap(rng, cs, 2.4, 2.4, 0.5, 7, rim), T(8.5, 5.5, 0))
    return g


def plant_fan(ps, seed):
    """a fan plant: seven broad paddle leaves curling out of a bulb, banded light across the middle"""
    rng = random.Random(seed)
    g = Geo()
    g.add(lathe([(1.1, 0.0), (0.9, 0.6), (0.0, 1.0)], 6, ps["dark"], bottom=ps["dark"]))
    n = 7
    for i in range(n):
        az = TAU * i / n + rng.uniform(-0.25, 0.25)
        out = Vector((math.cos(az), math.sin(az), 0.0))
        L, rise = rng.uniform(0.8, 1.15), rng.uniform(0.85, 1.2)
        b = out * 0.4 + UP * 0.5
        path = [b] + [b + (out * o + UP * u * rise) * L for o, u in ((0.5, 1.9), (1.8, 3.9), (3.4, 4.9), (4.6, 4.5))]
        main = ps["main"] if i % 2 else ps["dark"]
        g.add(ribbon(path, [0.35, 2.0 * L, 3.2 * L, 2.6 * L, 0.0], UP, 0.16,
                     lambda j, main=main: ps["light"] if j == 2 else (ps["tip"] if j == 3 else main)))
    return g


def kelp_vine(seed, height, nodes, bulbs):
    """creepvine-like: a thick vine twisting up, pairs of leaves drooping off it, glowing seed bulbs under the top"""
    rng = random.Random(seed)
    g = Geo()
    ph = rng.uniform(0, TAU)
    path = [Vector((1.6 * math.sin(k * 0.55 + ph) * k / nodes, 1.2 * math.sin(k * 0.4 + ph * 0.7) * k / nodes, height * k / nodes))
            for k in range(nodes + 1)]
    g.add(tube(path, [1.0 - 0.5 * k / nodes for k in range(nodes + 1)], 5, "vine", start="vine", end="vine", phase=0.3))
    g.add(lathe([(1.4, 0.0), (1.0, 0.8), (0.0, 1.4)], 6, "kelp_stipe", bottom="kelp_stipe"))
    for k in range(1, nodes + 1):
        p = path[k]
        for s in (0, 1):
            az = k * 2.2 + s * math.pi + ph
            out = Vector((math.cos(az), math.sin(az), 0.0))
            L = rng.uniform(5.0, 6.5) * (1.0 - 0.3 * k / nodes)
            leaf = [p, p + out * L * 0.55 + UP * L * 0.25, p + out * L - UP * L * 0.35]
            g.add(ribbon(leaf, [0.5, 0.62 * L, 0.0], UP, 0.16, "vine_light" if (k + s) % 2 else "kelp"))
    for i in range(bulbs):
        k = nodes - 1 - i % 3
        az = i * 2.0 + ph
        out = Vector((math.cos(az), math.sin(az), 0.0))
        g.add(icosphere(1, rng.uniform(0.8, 1.0), "glow_yellow", 0.1, rng), T(*(path[k] + out * 1.3 - UP * 0.9)))
    top, d = path[-1], (path[-1] - path[-2]).normalized()
    g.add(ribbon([top, top + d * 2.0 + UP * 0.5, top + d * 3.6 + UP * 0.6], [0.4, 1.6, 0.0], UP, 0.14, "vine_light"))
    return g


def plant_bulb_glow(glow, seed):
    """a bioluminescent bulb plant: five curved stalks, each holding a glowing bulb in a little cup"""
    rng = random.Random(seed)
    g = Geo()
    g.add(lathe([(1.3, 0.0), (1.0, 0.7), (0.0, 1.1)], 6, "teal_dark", bottom="teal_dark"))
    for i in range(5):
        az = TAU * i / 5 + rng.uniform(-0.3, 0.3)
        out = Vector((math.cos(az), math.sin(az), 0.0))
        h, lean = (8.0, 0.3) if i == 0 else (rng.uniform(3.0, 6.5), rng.uniform(0.8, 2.2))
        top = out * lean + UP * h
        g.add(tube([out * 0.3 + UP * 0.6, out * lean * 0.3 + UP * h * 0.55, top], [0.28, 0.2, 0.16], 4, "teal", start="teal", end="teal",
                   phase=math.pi / 4))
        g.add(lathe([(0.15, 0.0), (0.85, 0.55), (0.6, 0.7)], 4, "teal_tip", bottom="teal", top="teal_dark"), T(*top))
        g.add(icosphere(1, rng.uniform(0.75, 1.0) * (1.25 if i == 0 else 1.0), glow, 0.08, rng), T(*(top + UP * 0.9)))
    return g


def plant_glow_shroom(glow, seed):
    """a ring of glowing mushrooms with spotted caps, for the deep floor"""
    rng = random.Random(seed)
    g = Geo()
    for x, y, s in ((0.0, 0.0, 1.0), (1.9, 0.9, 0.7), (-1.6, 1.2, 0.6), (0.9, -1.7, 0.55), (-1.2, -1.3, 0.45)):
        h, r = 3.2 * s * rng.uniform(0.9, 1.1), 1.6 * s
        stalk = lathe([(0.45 * s, 0.0), (0.3 * s, h)], 5, "deep_top", bottom="deep_top", top="deep_top")
        cap = lathe([(0.3 * s, h - 0.2 * s), (r, h + 0.15 * s), (r * 0.65, h + 0.75 * s), (0.0, h + 1.0 * s)], 6,
                    [glow, glow, lambda j: glow if j % 2 else "teal_dark"], bottom=glow, jitter=0.05 * s, rng=rng)
        m = T(x, y, 0) @ R(rng.uniform(-10, 10), "X") @ R(rng.uniform(-10, 10), "Y")
        g.add(stalk, m).add(cap, m)
    return g


def vent_chimney(seed):
    """a hydrothermal chimney and two small ones, lumpy and banded, glowing orange in the mouth"""
    rng = random.Random(seed)
    g = Geo()
    cols = ["vent_rock", "vent_rock_dark", "vent_rock", "vent_rock_dark", "vent_rock", "vent_top", "glow_orange"]
    base = ((3.2, 0.0), (2.6, 3.0), (2.5, 5.8), (1.9, 8.6), (1.8, 11.4), (2.0, 12.6), (1.25, 12.9), (1.1, 12.1))
    for x, y, s, sides in ((0.0, 0.0, 1.0, 7), (3.8, 1.6, 0.55, 6), (-3.2, 2.0, 0.42, 6)):
        hs = 1.0 if s == 1.0 else 1.3 * s
        profile = [(r * s * (rng.uniform(0.9, 1.1) if i < 5 else 1.0), z * hs) for i, (r, z) in enumerate(base)]
        part = lathe(profile, sides, cols, bottom="vent_rock_dark", top="glow_orange", phase=rng.uniform(0, TAU), jitter=0.25 * s, rng=rng)
        g.add(part, T(x, y, 0) @ R(rng.uniform(-6, 6), "X"))
    rule = rock_rule(ROCK_SETS["vent"], rng)
    for x, y, sz in ((2.4, -2.4, 2.6), (-2.6, -1.6, 2.0)):
        g.add(boulder_part(rng, rule, (sz, sz * 0.9, sz * 0.7), 1, 0.15), T(x, y, 0))
    return g


def bone_ribs(seed):
    """a giant ribcage half sunk in the sand: ribs arching over a spine, a tunnel to ride through along X"""
    rng = random.Random(seed)
    g = Geo()
    spine = [Vector((x, rng.uniform(-0.3, 0.3), 0.4 + 0.2 * math.sin(x))) for x in (-14.0, -9.0, -4.0, 1.0, 6.0, 11.0, 15.0)]
    g.add(tube(spine, [1.3, 1.4, 1.35, 1.25, 1.1, 0.8, 0.0], 5, ["bone", "bone_dark"] * 3, start="bone_dark", phase=0.2))
    arc = ((1.0, 0.8), (6.5, 5.5), (8.0, 11.0), (6.0, 16.5), (2.0, 19.5))
    for i, (x, k) in enumerate(((-9.0, 0.9), (-4.5, 1.0), (0.0, 1.0), (4.5, 0.85), (9.0, 0.65))):
        for side in (1, -1):
            broken = (i, side) in ((3, 1), (1, -1))
            pts = arc[:3] if broken else arc
            path = [Vector((x + 0.5 * j, side * w * (0.8 + 0.2 * k), z * k)) for j, (w, z) in enumerate(pts)]
            radii = [r * k ** 0.5 for r in (0.9, 0.85, 0.7, 0.55, 0.0)[: len(pts) - 1]] + [0.0]
            g.add(tube(path, radii, 4, ["bone_dark"] + ["bone"] * (len(pts) - 2), start="bone_dark", phase=math.pi / 4))
    return g


def blades(g, rng, centre, count, spread, hmin, hmax, cols, tip=None):
    """sea-grass blades round a centre; tip colours the top third"""
    for i in range(count):
        a, r = rng.uniform(0, TAU), spread * math.sqrt(rng.random())
        p = centre + Vector((r * math.cos(a), r * math.sin(a), 0.0))
        lean = Vector((math.cos(a + rng.uniform(-0.8, 0.8)), math.sin(a + rng.uniform(-0.8, 0.8)), 0.0))
        h = rng.uniform(hmin, hmax)
        path = [p, p + UP * h * 0.4 + lean * h * 0.06, p + UP * h * 0.75 + lean * h * 0.22, p + UP * h + lean * h * 0.42]
        c = cols[i % len(cols)]
        g.add(ribbon(path, [0.42, 0.36, 0.24, 0.0], lean, 0.07, (lambda j, c=c: tip if j == 2 else c) if tip else c))


def floor_patch(seed, ground, blade_cols, tip=None, radius=10.0):
    """a low mound of floor with tufts of grass in it, to break up the terrain: sand and grass, or the deep's glowing grass"""
    rng = random.Random(seed)
    g = Geo()
    top, side = ground
    spokes = [rng.uniform(0.75, 1.2) for _ in range(9)]
    rule = Rule(lambda n, c: side if rng.random() < 0.3 else top)
    mound = lathe([(radius, 0.0), (radius * 0.82, 0.35), (radius * 0.45, 0.62), (0.0, 0.7)], 9, rule, bottom=side,
                  radial=lambda j: spokes[j], phase=rng.uniform(0, TAU), jitter=0.08, rng=rng)
    g.add(mound, S(1.0, 0.75, 1.0))
    for cx, cy, n, sp in ((-4.5, -1.0, 8, 2.2), (3.8, 1.6, 7, 1.8), (0.5, -3.6, 5, 1.4), (6.4, -2.2, 4, 1.0)):
        d = math.hypot(cx, cy) / radius
        blades(g, rng, Vector((cx, cy * 0.75, max(0.05, 0.7 * (1 - d ** 1.6)) - 0.12)), n, sp, 1.6, 3.4, blade_cols, tip)
    return g


# ---------------------------------------------------------------- the list
PROPS = []


def prop(name, category, build, zones, note, colour_set=None, view=28, glow=False, sway=None):
    PROPS.append({"name": name, "category": category, "build": build, "zones": zones, "note": note, "colourSet": colour_set,
                  "view": view, "glow": glow, "sway": sway})


for rs_name in ("reef", "deep"):
    rs = ROCK_SETS[rs_name]
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
for cs_name in ("pink", "orange", "purple"):
    cs, z = CORAL_SETS[cs_name], CORAL_ZONES[cs_name]
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

# round 2: the alien-reef set (sway: rock the whole part about its base on the client, never on the server)
ROCK_ZONES = {"reef": SHALLOW, "deep": ["Twilight", "Midnight", "Bone Graveyard"], "vent": ["Vents", "The Underworld"]}
for rs_name, rs in ROCK_SETS.items():
    z = ROCK_ZONES[rs_name]
    prop(f"rock_mesa_{rs_name}", "rock", lambda rs=rs: rock_mesa(rs, 503), z, "a layered table rock with an overhanging ledge",
         rs_name, view=24)
    prop(f"rock_pillar_{rs_name}", "rock", lambda rs=rs: rock_pillar(rs, 509), z, "a leaning strata column with a flat cap; "
         "scale 1-3x for skylines", rs_name, view=18)
    prop(f"rock_wall_{rs_name}", "rock", lambda rs=rs: rock_wall(rs, 521), z, "a stepped cliff, flat at the back: line the "
         "lane's sides with it, face (-Z) to the lane", rs_name, view=22)

CORAL2_ZONES = {"pink": ["Shallows", "Coral Reef"], "orange": ["Coral Reef", "Shipwrecks"],
                "purple": ["Coral Reef", "Shipwrecks", "Open Blue"], "teal": ["Twilight", "Midnight", "Bone Graveyard"]}
for cs_name, cs in CORAL_SETS.items():
    z, glow = CORAL2_ZONES[cs_name], cs_name == "teal"
    prop(f"coral_pillar_{cs_name}", "coral", lambda cs=cs: coral_pillar(cs, 601), z,
         "giant ringed tube coral, 20 studs" + (", glowing inside" if glow else ""), cs_name, view=20, glow=glow)
    prop(f"coral_mushroom_{cs_name}", "coral", lambda cs=cs: coral_mushroom(cs, 607), z,
         "a giant tiered mushroom coral; ride under the cap" + (", glowing rims" if glow else ""), cs_name, view=22, glow=glow)

PLANT_ZONES = {"green": ["Shallows", "Kelp Forest", "Shipwrecks"], "red": ["Shallows", "Coral Reef", "Open Blue"],
               "teal": ["Twilight", "Midnight", "Bone Graveyard"]}
for ps_name, ps in PLANT_SETS.items():
    prop(f"plant_fan_{ps_name}", "plant", lambda ps=ps: plant_fan(ps, 701), PLANT_ZONES[ps_name],
         "a fan plant of broad leaves" + (", glowing tips" if ps_name == "teal" else ""), ps_name, glow=ps_name == "teal",
         sway={"deg": 4, "periodS": 4.5})
prop("kelp_vine_tall", "kelp", lambda: kelp_vine(709, 44.0, 11, 4), ["Kelp Forest"],
     "a creeper vine, 45 studs, glowing seed bulbs near the top: the forest's columns", glow=True, view=16,
     sway={"deg": 3, "periodS": 7})
prop("kelp_vine_short", "kelp", lambda: kelp_vine(711, 21.0, 6, 2), ["Kelp Forest", "Shipwrecks", "Open Blue"],
     "a short creeper vine for the undergrowth", glow=True, view=18, sway={"deg": 4, "periodS": 6})
prop("plant_bulb_glow_cyan", "glow", lambda: plant_bulb_glow("glow", 801), ["Twilight", "Midnight"],
     "five glowing bulbs on stalks: light the deep's paths", glow=True, sway={"deg": 3, "periodS": 5})
prop("plant_bulb_glow_pink", "glow", lambda: plant_bulb_glow("glow_pink", 803), ["Midnight", "Bone Graveyard", "The Underworld"],
     "five glowing bulbs on stalks, pink", glow=True, sway={"deg": 3, "periodS": 5})
prop("plant_glow_shroom_cyan", "glow", lambda: plant_glow_shroom("glow", 811), ["Twilight", "Midnight", "Bone Graveyard"],
     "a ring of glowing mushrooms", glow=True, view=32)
prop("plant_glow_shroom_yellow", "glow", lambda: plant_glow_shroom("glow_yellow", 813), ["Vents", "The Underworld"],
     "a ring of glowing mushrooms, yellow", glow=True, view=32)
prop("vent_chimney", "landmark", lambda: vent_chimney(901), ["Vents", "The Underworld"],
     "a vent chimney and two small ones, glowing mouths: add bubbles and an orange PointLight", glow=True, view=20)
prop("bone_ribs", "landmark", lambda: bone_ribs(907), ["Bone Graveyard"],
     "a giant ribcage half sunk; the tunnel runs along X, 15+ studs clear", view=24)
prop("floor_sand_grass", "floor", lambda: floor_patch(951, ("sand", "sand_dark"), ("grass", "grass_light")), SHALLOW + ["Dock"],
     "a low sand mound with grass tufts: carpets the floor, under clusters", view=38)
prop("floor_glow_grass", "floor", lambda: floor_patch(953, ("deep_top", "deep_rock"), ("teal", "teal_dark"), "glow"),
     ["Twilight", "Midnight", "Bone Graveyard"], "a deep mound with glowing-tipped grass", glow=True, view=38)
prop("floor_vent_ash", "floor", lambda: floor_patch(957, ("vent_top", "vent_rock"), ("vent_rock_dark", "deep_rock"), "glow_orange"),
     ["Vents", "The Underworld"], "an ash mound with ember-tipped grass", glow=True, view=38)

# ---------------------------------------------------------------- zone families and clusters
# A family is the look of one or more zones: its colour sets and a cluster recipe (which props play anchor, mid, filler and floor).
# A cluster is a set piece of matching props placed as one: anchors (the tall ones) at the back, mids round them, fillers in front,
# floor patches under it all. Clusters are placements of the props above (no new meshes), so the map reuses the same uploads.
FAMILIES = {
    "lagoon": {"zones": ["Dock", "Shallows"], "floor": "sand", "rockSet": "reef", "coralSets": ["pink", "orange"],
               "plantSets": ["red", "green"], "accents": ["pink", "orange", "fan_red", "grass"], "glow": None,
               "floorProps": ["floor_sand_grass"],
               "anchor": ["rock_mesa_reef", "rock_boulder_a_reef", "coral_mushroom_pink"],
               "mid": ["coral_brain_pink", "coral_brain_orange", "plant_fan_red", "coral_table_orange", "rock_boulder_b_reef",
                       "coral_branch_pink"],
               "filler": ["sea_grass_clump", "sea_grass_patch", "shell_scallop", "starfish", "shell_conch", "rock_cluster_reef"]},
    "reef": {"zones": ["Coral Reef"], "floor": "sand", "rockSet": "reef", "coralSets": ["pink", "orange", "purple"],
             "plantSets": ["red"], "accents": ["pink", "orange", "purple", "fan_red"], "glow": None,
             "floorProps": ["floor_sand_grass"],
             "anchor": ["coral_mushroom_pink", "rock_mesa_reef", "coral_pillar_orange", "coral_mushroom_purple", "coral_pillar_pink"],
             "mid": ["coral_table_pink", "coral_fan_purple", "coral_brain_orange", "coral_branch_orange", "plant_fan_red",
                     "coral_tube_pink", "rock_slab_stack_reef", "coral_fan_pink"],
             "filler": ["sea_grass_clump", "coral_branch_pink", "rock_cluster_reef", "sea_urchin", "starfish", "coral_brain_pink"]},
    "kelp": {"zones": ["Kelp Forest"], "floor": "sand", "rockSet": "reef", "coralSets": [], "plantSets": ["green"],
             "accents": ["vine", "kelp", "glow_yellow"], "glow": "glow_yellow", "floorProps": ["floor_sand_grass"],
             "anchor": ["kelp_vine_tall", "rock_pillar_reef", "kelp_vine_tall", "kelp_tall"],
             "mid": ["kelp_vine_short", "rock_boulder_a_reef", "plant_fan_green", "kelp_short", "rock_mesa_reef", "kelp_vine_short"],
             "filler": ["sea_grass_patch", "sea_grass_clump", "rock_cluster_reef", "plant_fan_green", "sea_urchin"]},
    "wreck": {"zones": ["Shipwrecks", "Open Blue"], "floor": "sand", "rockSet": "reef", "coralSets": ["purple", "orange"],
              "plantSets": ["red", "green"], "accents": ["purple", "orange", "wood"], "glow": None, "floorProps": ["floor_sand_grass"],
              "anchor": ["rock_wall_reef", "rock_pillar_reef", "coral_mushroom_purple", "rock_spire_reef"],
              "mid": ["coral_table_purple", "coral_pillar_purple", "rock_slab_stack_reef", "crate_stack", "barrel", "coral_fan_orange",
                      "plant_fan_red", "kelp_vine_short"],
              "filler": ["rock_cluster_reef", "crate", "coral_tube_purple", "sea_grass_clump", "shell_conch"]},
    "twilight": {"zones": ["Twilight", "Midnight"], "floor": "deep_top", "rockSet": "deep", "coralSets": ["teal", "purple"],
                 "plantSets": ["teal"], "accents": ["teal", "purple", "glow"], "glow": "glow", "floorProps": ["floor_glow_grass"],
                 "anchor": ["coral_pillar_teal", "rock_mesa_deep", "coral_mushroom_teal", "rock_pillar_deep"],
                 "mid": ["plant_bulb_glow_cyan", "plant_fan_teal", "rock_boulder_a_deep", "plant_glow_shroom_cyan",
                         "rock_slab_stack_deep", "coral_pillar_teal"],
                 "filler": ["plant_glow_shroom_cyan", "rock_cluster_deep", "plant_bulb_glow_pink", "sea_urchin"]},
    "vents": {"zones": ["Vents", "The Underworld"], "floor": "vent_top", "rockSet": "vent", "coralSets": [], "plantSets": [],
              "accents": ["vent_top", "glow_orange", "glow_yellow"], "glow": "glow_orange", "floorProps": ["floor_vent_ash"],
              "anchor": ["vent_chimney", "rock_pillar_vent", "rock_wall_vent", "rock_mesa_vent"],
              "mid": ["vent_chimney", "rock_mesa_vent", "plant_glow_shroom_yellow", "rock_boulder_a_deep", "rock_spire_deep"],
              "filler": ["plant_glow_shroom_yellow", "rock_cluster_deep", "sea_urchin", "plant_bulb_glow_pink"]},
    "bones": {"zones": ["Bone Graveyard"], "floor": "deep_top", "rockSet": "deep", "coralSets": ["teal"], "plantSets": ["teal"],
              "accents": ["bone", "teal", "glow_pink"], "glow": "glow_pink", "floorProps": ["floor_glow_grass"],
              "anchor": ["bone_ribs", "rock_pillar_deep", "rock_wall_deep"],
              "mid": ["plant_bulb_glow_pink", "rock_mesa_deep", "rock_boulder_b_deep", "plant_fan_teal", "coral_pillar_teal"],
              "filler": ["plant_glow_shroom_cyan", "rock_cluster_deep", "plant_bulb_glow_pink", "rock_boulder_a_deep"]},
}
# the most a cluster may scale a prop, by category (crates stay crate-sized, kelp doesn't tower past the fog)
MAX_SCALE = {"dock": 1.0, "kelp": 1.4, "shell": 1.5, "plant": 1.6, "glow": 1.6, "coral": 2.2, "floor": 2.3}
# w, d: the footprint's ellipse (studs, w along the lane); counts: anchors, mids, fillers, floor patches; scales: per role
CLUSTER_SIZES = {
    "small": {"w": 26.0, "d": 14.0, "counts": (1, 2, 5, 1),
              "scale": {"anchor": (0.8, 1.0), "mid": (0.8, 1.1), "filler": (0.8, 1.2), "floor": (1.0, 1.2)}},
    "medium": {"w": 56.0, "d": 30.0, "counts": (2, 5, 10, 2),
               "scale": {"anchor": (1.1, 1.5), "mid": (1.0, 1.4), "filler": (1.0, 1.4), "floor": (1.3, 1.6)}},
    "huge": {"w": 120.0, "d": 60.0, "counts": (4, 10, 18, 4),
             "scale": {"anchor": (1.8, 2.8), "mid": (1.3, 2.0), "filler": (1.2, 1.8), "floor": (1.8, 2.3)}},
}


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


def glow_material():
    """the palette again, but emissive: only for the renders (in Roblox the glow part is Neon)"""
    m = palette_material()
    m.name = "PropGlow"
    nt = m.node_tree
    bsdf, tex = nt.nodes.get("Principled BSDF"), next(n for n in nt.nodes if n.type == "TEX_IMAGE")
    nt.links.new(tex.outputs["Color"], bsdf.inputs["Emission Color"])
    bsdf.inputs["Emission Strength"].default_value = 1.6
    return m


MAT_GLOW = glow_material()
GLOW_UVS = [cell_uv(c) for c in GLOW_COLOURS]


def is_glow(f, uv):
    u = f.loops[0][uv].uv
    return any(abs(u.x - g[0]) < 1e-4 and abs(u.y - g[1]) < 1e-4 for g in GLOW_UVS)


def mesh_object(name, bm, mat):
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    me.materials.append(mat)
    for poly in me.polygons:
        poly.use_smooth = False
    ob = bpy.data.objects.new(name, me)
    scene.collection.objects.link(ob)
    return ob


def build_object(name, geo, split_glow=False):
    """the prop's object, and with split_glow its glowing faces as a second object sharing the same pivot (or None)"""
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
    glow_count = {}
    for f, c in zip(faces, cols):
        if isinstance(c, Rule):
            c = c.fn(f.normal, f.calc_center_median())
        if c in GLOW_COLOURS:
            glow_count[c] = glow_count.get(c, 0) + 1
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
    glow_ob = None
    if split_glow and glow_count:
        gbm = bm.copy()
        guv = gbm.loops.layers.uv["UVMap"]
        bmesh.ops.delete(gbm, geom=[f for f in gbm.faces if not is_glow(f, guv)], context="FACES")
        bmesh.ops.delete(bm, geom=[f for f in bm.faces if is_glow(f, uv)], context="FACES")
        glow_ob = mesh_object(name + "_glow", gbm, MAT_GLOW)
        glow_ob["glowColour"] = max(glow_count, key=glow_count.get)
    return mesh_object(name, bm, MAT), glow_ob


def export_fbx(ob, path):
    bpy.ops.object.select_all(action="DESELECT")
    ob.select_set(True)
    bpy.context.view_layer.objects.active = ob
    bpy.ops.export_scene.fbx(filepath=path, use_selection=True, object_types={"MESH"}, apply_unit_scale=True,
                             apply_scale_options="FBX_SCALE_NONE", axis_forward="-Z", axis_up="Y", mesh_smooth_type="FACE",
                             use_mesh_modifiers=False, add_leaf_bones=False, bake_anim=False, path_mode="COPY",
                             embed_textures=True)


def r2(v):
    return round(v, 2)


def mesh_stats(ob):
    """size and bounding-box centre (from the pivot) in Roblox axes: x, y up, z = -Blender y"""
    vs = [v.co for v in ob.data.vertices]
    lo = Vector((min(v.x for v in vs), min(v.y for v in vs), min(v.z for v in vs)))
    hi = Vector((max(v.x for v in vs), max(v.y for v in vs), max(v.z for v in vs)))
    c = (lo + hi) / 2
    size = {"x": r2(hi.x - lo.x), "y": r2(hi.z - lo.z), "z": r2(hi.y - lo.y)}
    return size, {"x": r2(c.x), "y": r2(c.z), "z": r2(-c.y)}, sum(len(p.vertices) - 2 for p in ob.data.polygons)


# ---------------------------------------------------------------- build, export, record
built = []
for p in PROPS:
    if ONLY and p["name"] not in ONLY:
        continue
    ob, glow_ob = build_object(p["name"], p["build"](), p["glow"])
    path = os.path.join(OUT, p["name"] + ".fbx")
    export_fbx(ob, path)
    size, centre, tris = mesh_stats(ob)
    rec = {
        "name": p["name"],
        "file": os.path.basename(path),
        "category": p["category"],
        "colourSet": p["colourSet"],
        "sizeStuds": size,  # Roblox axes: Y is up
        "centreStuds": centre,  # the bounding box's centre from the base pivot: a MeshPart's Position = pivot + this
        "tris": tris,
        "kb": round(os.path.getsize(path) / 1024, 1),
        "zones": p["zones"],
        "note": p["note"],
    }
    if glow_ob:
        gpath = os.path.join(OUT, glow_ob.name + ".fbx")
        export_fbx(glow_ob, gpath)
        gsize, gcentre, gtris = mesh_stats(glow_ob)
        rec["glow"] = {"file": os.path.basename(gpath), "colour": PALETTE[glow_ob["glowColour"]], "sizeStuds": gsize,
                       "centreStuds": gcentre, "tris": gtris, "kb": round(os.path.getsize(gpath) / 1024, 1)}
    if p["sway"]:
        rec["sway"] = p["sway"]
    built.append((p, ob, glow_ob, rec))
    extra = f" + glow {rec['glow']['tris']}" if glow_ob else ""
    print(f"prop_kit: {p['name']:<26} {tris:>4} tris{extra}  {rec['sizeStuds']}  {rec['kb']} KB")

RECS = {rec["name"]: rec for _, _, _, rec in built}


# ---------------------------------------------------------------- clusters
def make_cluster(fam_name, fam, size_name, seed):
    rng = random.Random(seed)
    sz = CLUSTER_SIZES[size_name]
    hw, hd = sz["w"] / 2, sz["d"] / 2
    placed, pieces = [], []  # placed: (x, y, radius) in Blender's plane, +y = the front

    def foot(name, s):
        r = RECS[name]["sizeStuds"]
        return 0.5 * max(r["x"], r["z"]) * s * 0.8

    def place(name, role, region, spacing):
        lo, hi = sz["scale"][role]
        for attempt in range(500):
            s = min(rng.uniform(lo, hi) * (0.85 if attempt > 250 else 1.0), MAX_SCALE.get(RECS[name]["category"], 3.0))
            x, y = rng.uniform(-hw, hw), rng.uniform(-hd, hd)
            if (x / hw) ** 2 + (y / hd) ** 2 > 1 or not region(x, y):
                continue
            rad = foot(name, s)
            if role != "floor" and any(math.hypot(x - px, y - py) < (rad + pr) * spacing for px, py, pr in placed):
                continue
            if role != "floor":
                placed.append((x, y, rad))
            rec = RECS[name]
            sink = -0.1 * s if role == "floor" else (-0.5 * s if rec["category"] == "rock" else -0.15 * s)
            yaw = rng.uniform(-20, 20) if name.startswith("rock_wall") else rng.uniform(0, 360)
            pieces.append({"prop": name, "role": role, "pos": {"x": r2(x), "y": r2(sink), "z": r2(-y)}, "yawDeg": round(yaw),
                           "scale": r2(s), "_r": rad, "_xy": (x, y)})
            return True
        return False

    na, nm, nf, nfl = sz["counts"]
    for i in range(nfl):
        place(fam["floorProps"][i % len(fam["floorProps"])], "floor",
              (lambda x, y: abs(x) < hw * 0.25 and abs(y) < hd * 0.25) if i == 0 else (lambda x, y: True), 0)
    for i in range(na):
        name = fam["anchor"][0] if i == 0 else rng.choice(fam["anchor"])
        region = (lambda x, y: abs(x) < hw * 0.35 and y < -hd * 0.2) if i == 0 else (lambda x, y: y < -hd * 0.1)
        place(name, "anchor", region, 0.9)
    for _ in range(nm):
        place(rng.choice(fam["mid"]), "mid", lambda x, y: y < hd * 0.55, 0.75)
    for _ in range(nf):
        place(rng.choice(fam["filler"]), "filler", lambda x, y: True, 0.55)

    xs = [(pc["_xy"][0] - pc["_r"], pc["_xy"][0] + pc["_r"]) for pc in pieces if pc["role"] != "floor"]
    ys = [(pc["_xy"][1] - pc["_r"], pc["_xy"][1] + pc["_r"]) for pc in pieces if pc["role"] != "floor"]
    height = max(RECS[pc["prop"]]["sizeStuds"]["y"] * pc["scale"] + pc["pos"]["y"] for pc in pieces)
    tris = sum(RECS[pc["prop"]]["tris"] + RECS[pc["prop"]].get("glow", {}).get("tris", 0) for pc in pieces)
    for pc in pieces:
        del pc["_r"], pc["_xy"]
    return {
        "name": f"cluster_{fam_name}_{size_name}",
        "family": fam_name,
        "size": size_name,
        "zones": fam["zones"],
        "footprintStuds": {"x": r2(max(b for _, b in xs) - min(a for a, _ in xs)), "z": r2(max(b for _, b in ys) - min(a for a, _ in ys))},
        "heightStuds": r2(height),
        "pieceCount": len(pieces),
        "tris": tris,
        "pieces": pieces,
    }


CLUSTERS = []
if not ONLY:
    for fi, (fam_name, fam) in enumerate(FAMILIES.items()):
        for si, size_name in enumerate(CLUSTER_SIZES):
            CLUSTERS.append(make_cluster(fam_name, fam, size_name, 1000 + 37 * fi + si))
    for c in CLUSTERS:
        print(f"prop_kit: {c['name']:<26} {c['pieceCount']:>3} pieces {c['tris']:>6} tris  {c['footprintStuds']}  h {c['heightStuds']}")


def zone_palette(zone):
    fam_name, fam = next((n, f) for n, f in FAMILIES.items() if zone in f["zones"])
    rs = ROCK_SETS[fam["rockSet"]]
    return {
        "family": fam_name,
        "floor": PALETTE[fam["floor"]],
        "rock": PALETTE[rs["rock"]],
        "rockTop": PALETTE[rs["top"]],
        "rockBand": PALETTE[rs["band"]],
        "accents": [PALETTE[c] for c in fam["accents"]],
        "glow": PALETTE[fam["glow"]] if fam["glow"] else None,
        "rockSet": fam["rockSet"],
        "coralSets": fam["coralSets"],
        "plantSets": fam["plantSets"],
        "props": [r["name"] for r in RECS.values() if zone in r["zones"]],
        "clusters": [c["name"] for c in CLUSTERS if c["family"] == fam_name],
    }


if not ONLY:
    manifest = {
        "about": "Ride a Fish world props, built by tools/blender/prop_kit.py. Do not edit by hand: rerun the kit.",
        "units": "1 unit = 1 stud (a player is about 5 studs tall). sizeStuds is in Roblox axes (y is up). In Studio's 3D "
                 "Importer check the size against sizeStuds (File Dimensions: Studs) before placing.",
        "pivot": "the base: the bottom sits at y = 0, centred on the footprint. centreStuds is the bounding box's centre from "
                 "that pivot (Roblox centres a MeshPart on its box): part.CFrame = basePivot * CFrame.new(centreStuds)",
        "texture": "palette.png (each FBX embeds it): one flat colour cell per colour; one material per prop",
        "glow": "a prop with 'glow' has its glowing faces in a second FBX sharing the pivot: import it as its own MeshPart, "
                "Material Neon, Color = glow.colour, placed at basePivot * CFrame.new(glow.centreStuds); a PointLight in the "
                "biggest ones (Range 12-20, Brightness 1) if the budget allows",
        "sway": "props with 'sway' rock about their base on the client: deg each way, periodS a full swing (never on the server)",
        "front": "walls and clusters face -Z (the CFrame's LookVector): turn them so it points at the lane",
        "zones": ["Dock"] + SHALLOW + DEEP,
        "zonePalette": {z: zone_palette(z) for z in ["Dock"] + SHALLOW + DEEP},
        "clusterHowTo": "a cluster is placements of the props, in studs from the cluster's origin (on the floor, the footprint's "
                        "middle), Roblox axes. For each piece: origin * CFrame.new(pos) * CFrame.Angles(0, rad(yawDeg), 0), "
                        "scale the MeshPart's Size by scale, and its offsets (centreStuds, glow.centreStuds) by scale too. Set "
                        "the whole cluster on the floor; sink a little more on slopes. Roles: anchor (tall, at the back), mid, "
                        "filler (front), floor (flat patches under it all).",
        "clusterSizes": {k: {"w": v["w"], "d": v["d"]} for k, v in CLUSTER_SIZES.items()},
        "props": [rec for _, _, _, rec in built],
        "clusters": CLUSTERS,
    }
    with open(os.path.join(OUT, "props.json"), "w") as f:
        json.dump(manifest, f, indent=2)
        f.write("\n")


# ---------------------------------------------------------------- the contact sheet and the cluster sheet
def compose(tiles, cols, tile, out_path):
    """tiles: (render path, background hex), laid out in rows"""
    rows = (len(tiles) + cols - 1) // cols
    W, H, gap = cols * tile, rows * tile, 3
    sheet = np.ones((H, W, 4), np.float32)
    for i, (path, bg) in enumerate(tiles):
        img = bpy.data.images.load(path)
        px = np.empty(tile * tile * 4, np.float32)
        img.pixels.foreach_get(px)
        px = px.reshape(tile, tile, 4)
        bgc = np.array([c / 255 for c in hex_srgb(bg)], np.float32)
        a = px[:, :, 3:4]
        rgb = px[:, :, :3] * a + bgc * (1 - a)
        r, c = divmod(i, cols)
        y0 = H - (r + 1) * tile  # Blender images start at the bottom row
        sheet[y0 + gap : y0 + tile - gap, c * tile + gap : (c + 1) * tile - gap, :3] = rgb[gap:-gap, gap:-gap]
        bpy.data.images.remove(img)
    out_img = bpy.data.images.new(os.path.basename(out_path), W, H, alpha=False)
    out_img.pixels.foreach_set(sheet.ravel())
    out_img.filepath_raw = out_path
    out_img.file_format = "PNG"
    out_img.save()
    print("prop_kit: sheet", out_path)


if SHEET:
    TILE, COLS = 300, 10
    BG = {"rock": "#E3ECF1", "coral": "#FCEAF0", "kelp": "#E6F4E2", "shell": "#FBF0E1", "dock": "#F1EAE1", "plant": "#E9F6EE",
          "glow": "#2E3558", "landmark": "#E6E1EC", "floor": "#F5EEDC"}

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
    lb.inputs["Emission Strength"].default_value = 1.0
    label_data = bpy.data.curves.new("Label", "FONT")
    label_data.align_x = "CENTER"
    label_data.materials.append(label_mat)
    label = bpy.data.objects.new("Label", label_data)
    scene.collection.objects.link(label)
    label.parent = cam

    def is_dark(hexcol):
        return sum(hex_srgb(hexcol)) < 3 * 110

    def shoot(obs, view_el, view_az, text, bg, path, fill=1.12):
        """frames the objects from one side (orthographic), labels the tile and renders it"""
        bpy.context.view_layer.update()
        el, az = math.radians(view_el), math.radians(view_az)
        d = Vector((math.cos(az) * math.cos(el), math.sin(az) * math.cos(el), math.sin(el)))  # towards the camera
        rot = (-d).to_track_quat("-Z", "Y")
        right, up = rot @ Vector((1, 0, 0)), rot @ Vector((0, 1, 0))
        corners = [o.matrix_world @ Vector(c) for o in obs for c in o.bound_box]
        rs = [c.dot(right) for c in corners]
        us = [c.dot(up) for c in corners]
        w, h = max(rs) - min(rs), max(us) - min(us)
        size = max(w * fill, h * fill / 0.78)
        mid = right * (max(rs) + min(rs)) / 2 + up * ((max(us) + min(us)) / 2 - size * 0.09)
        cam.location = mid + d * 1500.0
        cam.rotation_euler = rot.to_euler()
        cam_data.ortho_scale = size
        lb.inputs["Emission Color"].default_value = tuple(srgb_to_linear(c / 255) for c in hex_srgb(
            "#EEF2F8" if is_dark(bg) else "#2B3442")) + (1.0,)
        label_data.body = text
        label_data.size = size * 0.047
        label.location = (0.0, -size * 0.405, -1.0)
        scene.render.filepath = path
        bpy.ops.render.render(write_still=True)

    scene.render.film_transparent = True
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGBA"
    scene.render.resolution_percentage = 100
    tiles_dir = tempfile.mkdtemp(prefix="prop_kit_")
    for _, ob, glow_ob, _ in built:
        for o in (ob, glow_ob):
            if o:
                o.hide_render = True

    scene.render.resolution_x = scene.render.resolution_y = TILE
    tiles = []
    for p, ob, glow_ob, rec in built:
        obs = [o for o in (ob, glow_ob) if o]
        for o in obs:
            o.hide_render = False
        s = rec["sizeStuds"]
        glow_note = ", glow" if glow_ob else ""
        path = os.path.join(tiles_dir, p["name"] + ".png")
        shoot(obs, p["view"], -125, f"{p['name']}\n{s['x']:g} x {s['y']:g} x {s['z']:g} studs, {rec['tris']} tris{glow_note}",
              BG[p["category"]], path)
        for o in obs:
            o.hide_render = True
        tiles.append((path, BG[p["category"]]))
    compose(tiles, COLS, TILE, os.path.join(OUT, "props-sheet.png"))

    # the clusters, from the front, each on a disc of its floor colour, on its zone's water colour
    if CLUSTERS:
        CTILE = 520
        WATER = {"lagoon": "#BDEDE6", "reef": "#AEE3EE", "kelp": "#B9DFC6", "wreck": "#A3C6E0", "twilight": "#41527F",
                 "vents": "#3E3149", "bones": "#3C4368"}
        scene.render.resolution_x = scene.render.resolution_y = CTILE
        by_name = {p["name"]: (ob, glow_ob) for p, ob, glow_ob, _ in built}
        floor_mats = {}
        ctiles = []
        for c in CLUSTERS:
            fam = FAMILIES[c["family"]]
            temp = []
            for pc in c["pieces"]:
                for src in by_name[pc["prop"]]:
                    if not src:
                        continue
                    o = bpy.data.objects.new(src.name + "_i", src.data)
                    scene.collection.objects.link(o)
                    o.location = (pc["pos"]["x"], -pc["pos"]["z"], pc["pos"]["y"])
                    o.rotation_euler = (0.0, 0.0, math.radians(pc["yawDeg"]))
                    o.scale = (pc["scale"],) * 3
                    temp.append(o)
            hw, hd = CLUSTER_SIZES[c["size"]]["w"] / 2, CLUSTER_SIZES[c["size"]]["d"] / 2
            n = 24
            disc = bpy.data.meshes.new("disc")
            disc.from_pydata([(0, 0, -0.05)] + [(hw * 1.15 * math.cos(TAU * i / n), hd * 1.3 * math.sin(TAU * i / n), -0.05)
                                                for i in range(n)], [], [(0, 1 + i, 1 + (i + 1) % n) for i in range(n)])
            if fam["floor"] not in floor_mats:
                fm = bpy.data.materials.new("Floor_" + fam["floor"])
                fm.use_nodes = True
                fm.node_tree.nodes.get("Principled BSDF").inputs["Base Color"].default_value = tuple(
                    srgb_to_linear(v / 255) for v in hex_srgb(PALETTE[fam["floor"]])) + (1.0,)
                floor_mats[fam["floor"]] = fm
            disc.materials.append(floor_mats[fam["floor"]])
            disc_ob = bpy.data.objects.new("disc", disc)
            scene.collection.objects.link(disc_ob)
            fp = c["footprintStuds"]
            path = os.path.join(tiles_dir, c["name"] + ".png")
            shoot(temp + [disc_ob], 26, 62, f"{c['name']}\n{fp['x']:g} x {c['heightStuds']:g} x {fp['z']:g} studs, "
                  f"{c['pieceCount']} pieces, {c['tris']} tris", WATER[c["family"]], path, fill=1.05)
            for o in temp + [disc_ob]:
                bpy.data.objects.remove(o)
            ctiles.append((list(CLUSTER_SIZES).index(c["size"]), path, WATER[c["family"]]))
        ctiles.sort(key=lambda t: t[0])  # stable: a row per size, a column per family
        compose([t[1:] for t in ctiles], len(FAMILIES), CTILE, os.path.join(OUT, "clusters-sheet.png"))
