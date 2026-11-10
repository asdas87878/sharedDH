"""Voxel kit (docs/style/04-voxel-style.md): builds a creature designed block by block on a grid, the way a voxel editor works,
from a model file (art/creatures/<Name>/voxel.py), and renders the same views as the other body plans (kit_common.py).

usage: blender --background --python tools/blender/voxel_kit.py -- <voxel.py> <out folder> [--swim] [--wire] [--inspect] [--check] [--force] [--weld] [--all-faces]
--inspect renders close views from below, behind and above into <out>/inspect, for finding gaps and overlaps by eye.
Every build also checks each part and prints a line starting "  !" for a free piece that touches nothing (a gap) and for two
faces that face the same way, overlap and lie in one plane or under 0.05 studs apart (they would flicker or shimmer in
Roblox), and for a piece with no face buried in
something else (its root shows, with a wedge of air under it). --check stops after those lines, without rendering.
The check is a gate: with any such line the build stops before it renders, unless --force is given.
Faces that nothing can ever see are left out of the mesh (a fin's buried root, a tooth's base): a piece's face is dropped
when every point just outside it is inside the same part's cubes or pieces. The look and the swim are unchanged.
--all-faces keeps them, for comparing renders.
--weld goes further and unions each part into one closed shell (Blender's exact boolean). That removes every hidden
surface, but it cuts each face a piece passes through, and measured about a third MORE triangles, so it is not the
default. What stops flicker is the gate: no two faces in one plane, none under 0.05 studs apart.

A model file is Python. It sets:
  NAME, ZONE, RARITY   for the sheet
  U                    the size of one cube, in studs
  PALETTE              {colour name: "#hex"}; "name-" and "name+" are its darker and lighter tones, made automatically
  SEAT                 the rider's seat: (x, the back's height, the back's half width), in cubes
  FRAME, ORTHO         optional: how far the cameras stand back (1 = a 12-stud fish), the side view's width in studs
  build(m)             makes the parts: p = m.part(name, pivot, parent), then p.box(...) and the rest (see Part)
  GLOW                 optional: {colour name: strength}: colours that shine by themselves (Roblox's Neon)
  LIGHTS               optional: [(part, (x, y, z), "#hex", watts, radius)]: small lights; y not 0 makes a pair
  SHADE, LIFT          optional: how dark the "name-" tone is (0.8) and how light the "name+" tone is (1.12)
  FLOATING             optional: names of parts whose pieces float on purpose (a crown of shards, orbiting rocks): the
                       gate doesn't ask them to touch anything or to have a buried root
  SWIM                 a fish swim: {"chain": [part names, head first], "amplitudes": [degrees per joint], "phaseStep", "headCounter"}
  pose(parts, phase)   or its own swim: turns the parts (a dict of objects by name) for phase 0 to 2 pi
  TEXTURES             optional: a list of rules that lay a cartoon tile (tools/art/creature_tiles.py) over the colours
                       (docs/style/06-textures.md). The first rule that fits a face wins. A rule is a dict:
                         "tile"     which tile: "stud", "stud_square", "plate", "scale", ...
                         "on"       which faces: "top" (only those facing up: the usual), "sides", "top+sides", "all"
                         "colours"  only these colour names (and their tones); left out: every colour but KEEP and GLOW
                         "parts"    only these parts; "x": [from, to] only faces between these, in cubes
                         "size"     cubes to a tile (1); "strength" how strong (0.5); "turned": True also on turned blocks
  VARIANT              optional: "gold" (every colour but KEEP and GLOW becomes a tone of gold) or "rainbow" (a rainbow
                       runs along the body in their place, its hues stepped and mixed at their edges in very small
                       pixels, like a gradient in pixel art)
  KEEP                 optional: the colours a variant and the textures leave alone (eyes, teeth, mouths by default)
  ACCENT               optional: on a variant, the colour the GLOW colours take, so a creature's line of light contrasts
                       with its new body (violet on gold, white on a rainbow, by default)
  RAINBOW              optional: {"steps": how many hues (14), "pixels": small pixels to a cube (9), "pastel": how much white
                       is mixed in (0.1: midway between vivid and pastel), "dither": how far
                       two neighbouring hues are mixed pixel by pixel (1 = the whole way, a smooth gradient),
                       "wobble": how far the edge between two hues wanders (0: straight across the body),
                       "grain": "bayer" (an ordered pattern) or "noise"}
--look <file.json> lays TEXTURES, VARIANT or KEEP from a file over the model's own, to try looks without editing it.

The grid: the creature points to -X, up is +Z. A cube (i, j, k) spans x [i, i + 1) and z [k, k + 1), and is centred on
y = j, so a model is symmetric about y = 0 and an odd number of cubes wide. Ranges are half open: box(0, 3, ...) fills
x = 0, 1, 2. Each part is one rigid piece (one MeshPart and one Motor6D in Roblox), its pivot at its joint. Only the faces that
show are built, and touching faces of one colour are merged, so the triangle count stays low.
"""
import importlib.util
import json
import math
import os
import sys

import bmesh
import bpy

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import kit_common as kc  # noqa: E402

argv = sys.argv[sys.argv.index("--") + 1 :]
MODEL_PATH = os.path.abspath(argv[0])
OUT = os.path.abspath(argv[1])
SWIM, WIRE, INSPECT, CHECK = "--swim" in argv, "--wire" in argv, "--inspect" in argv, "--check" in argv
FORCE, WELD, ALL_FACES = "--force" in argv, "--weld" in argv, "--all-faces" in argv

module_spec = importlib.util.spec_from_file_location("voxel_model", MODEL_PATH)
M = importlib.util.module_from_spec(module_spec)
module_spec.loader.exec_module(M)
if "--look" in argv:  # a look laid over the model, to try textures and variants without touching its file
    for key, value in json.load(open(argv[argv.index("--look") + 1])).items():
        setattr(M, key, value)
U = M.U


class Part:
    """One rigid piece: a set of coloured cubes. Coordinates are in cubes, in the creature's frame."""

    def __init__(self, name, pivot, parent):
        self.name, self.pivot, self.parent, self.cells, self.shapes = name, pivot, parent, {}, []

    # ---- free pieces: the grid isn't law. Where a slope or a point looks better than steps (a snout, a tooth, a horn tip),
    # these add plain solids to the part. Their coordinates are real numbers in cubes, y measured from the middle (a cube
    # column j spans y from j - 0.5 to j + 0.5).
    def solid(self, verts, faces, colour, mirror=False):
        """a closed solid from its corners and faces (lists of corner numbers)"""
        self.shapes.append(([tuple(v) for v in verts], faces, colour))
        if mirror:
            self.shapes.append(([(v[0], -v[1], v[2]) for v in verts], faces, colour))

    def block(self, x0, s0, x1, s1, colour, mirror=False):
        """a tapered block between two cross-sections: at x0 it spans s0 = (y from, y to, z from, z to), at x1 it spans s1"""
        verts = []
        for x, (ya, yb, za, zb) in ((x0, s0), (x1, s1)):
            verts += [(x, ya, za), (x, yb, za), (x, yb, zb), (x, ya, zb)]
        faces = [(0, 1, 2, 3), (4, 5, 6, 7), (0, 1, 5, 4), (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7)]
        self.solid(verts, faces, colour, mirror)

    def taper(self, x0, s0, x1, s1, colour):
        """a tapered block centred on y = 0: at x0 it is s0 = (half width, z from, z to), at x1 it is s1"""
        self.block(x0, (-s0[0], s0[0], s0[1], s0[2]), x1, (-s1[0], s1[0], s1[1], s1[2]), colour)

    def spike(self, base, apex, colour, mirror=False):
        """a pyramid: four base corners and a point (a tooth, a horn tip, a claw)"""
        verts = list(base) + [apex]
        self.solid(verts, [(0, 1, 2, 3), (0, 1, 4), (1, 2, 4), (2, 3, 4), (3, 0, 4)], colour, mirror)

    def tooth(self, x, y, z, size, length, colour, mirror=True, lean=(0.0, 0.0), long=None):
        """a pointed tooth: a base `size` across (`long` along x, if different) centred on (x, y) at height z, its point
        `length` below (negative: above), leaning by `lean` in x and y"""
        hx, hy = (long or size) / 2, size / 2
        base = [(x - hx, y - hy, z), (x + hx, y - hy, z), (x + hx, y + hy, z), (x - hx, y + hy, z)]
        self.spike(base, (x + lean[0], y + lean[1], z - length), colour, mirror)

    def prism(self, outline, y0, y1, colour, mirror=False):
        """a flat shape drawn in the side view (x, z corners) and given thickness from y0 to y1: a blade, a fin"""
        n = len(outline)
        verts = [(x, y0, z) for x, z in outline] + [(x, y1, z) for x, z in outline]
        faces = [tuple(range(n)), tuple(range(n, 2 * n))] + [(i, (i + 1) % n, n + (i + 1) % n, n + i) for i in range(n)]
        self.solid(verts, faces, colour, mirror)

    # ---- big blocks at any angle: what the reference is really made of. A slope is a whole box tilted, a fin is two or three
    # boxes, and a sloping surface is dressed in plates that step down it, so it belongs with the stepped body.
    def _oriented(self, centre, along, wide, thin, size, colour, mirror):
        cx, cy, cz = centre
        verts = []
        for sa in (-1, 1):
            for sw, st in ((-1, -1), (1, -1), (1, 1), (-1, 1)):
                verts.append(tuple(c + sa * a * size[0] / 2 + sw * w * size[1] / 2 + st * t * size[2] / 2
                                   for c, a, w, t in zip((cx, cy, cz), along, wide, thin)))
        faces = [(0, 1, 2, 3), (4, 5, 6, 7), (0, 1, 5, 4), (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7)]
        self.solid(verts, faces, colour, mirror)

    def beam(self, p0, p1, width, thick, colour, flat="y", mirror=False):
        """a box running from p0 to p1 (a fin, a tail lobe, a limb): `width` across, `thick` through. flat: the direction its
        thin side faces, "y" (it lies in the side view, like a tail fin) or "z" (it lies flat, like a side fin)"""
        d = [b - a for a, b in zip(p0, p1)]
        length = math.sqrt(sum(v * v for v in d))
        along = [v / length for v in d]
        ref = (0.0, 1.0, 0.0) if flat == "y" else (0.0, 0.0, 1.0)
        dot = sum(a * r for a, r in zip(along, ref))
        thin = [r - dot * a for a, r in zip(along, ref)]
        n = math.sqrt(sum(v * v for v in thin))
        thin = [v / n for v in thin]
        wide = [along[1] * thin[2] - along[2] * thin[1], along[2] * thin[0] - along[0] * thin[2], along[0] * thin[1] - along[1] * thin[0]]
        centre = [(a + b) / 2 for a, b in zip(p0, p1)]
        self._oriented(centre, along, wide, thin, (length, width, thick), colour, mirror)

    def shingles(self, p0, p1, hw0, hw1, count, thick, colours, lay=0.5, overlap=1.3, y=0.0):
        """plates stepping down a slope, like shingles: from p0 = (x, z) to p1 on the surface, `count` plates, each lying
        flatter than the slope (lay 1: along it, 0: level) so its back edge stands proud of the next one. Half widths hw0 to
        hw1; colours are used in turn"""
        dx, dz = p1[0] - p0[0], p1[1] - p0[1]
        length = math.hypot(dx, dz)
        angle = math.atan2(dz, dx)
        level = 0.0 if dx > 0 else math.pi
        turn = level + (angle - level) * lay if abs(angle - level) <= math.pi else angle
        along = (math.cos(turn), 0.0, math.sin(turn))
        thin = (-math.sin(turn), 0.0, math.cos(turn)) if math.cos(turn) > 0 else (math.sin(turn), 0.0, -math.cos(turn))
        if thin[2] < 0:
            thin = tuple(-v for v in thin)
        for i in range(count):
            f = (i + 0.5) / count
            hw = hw0 + (hw1 - hw0) * f
            centre = (p0[0] + dx * f + thin[0] * thick / 2, y, p0[1] + dz * f + thin[2] * thick / 2)
            self._oriented(centre, along, (0.0, 1.0, 0.0), thin, (length / count * overlap, 2 * hw, thick),
                           colours[i % len(colours)], False)

    def band(self, x0, x1, n, z0, z1, colour, top=(), bottom=(), proud=0.3, stop=None):
        """a band of colour round a hull of the same numbers (n, z0, z1, top, bottom), standing `proud` of it: a fraction of
        a cube, so a stripe is raised a little, not a whole cube. In three tones, like a body slab: lighter on the top row,
        darker on the corner steps. x0 and x1 are real numbers: a band may start a little in front of its piece.
        stop: the band stops at this height and leaves the belly bare, as a painted bar does on a real fish"""
        layers, z = [], z0
        for inset, tall in bottom:
            layers.append((z, z + tall, n + 0.5 - inset, colour + "-"))
            z += tall
        low, z, tops = z, z1, []
        for k, (inset, tall) in enumerate(top):
            tops.append((z - tall, z, n + 0.5 - inset, colour + ("+" if k == 0 else "-")))
            z -= tall
        layers.append((low, z, n + 0.5, colour))
        layers += tops
        cuts = sorted({v for a, b, _, _ in layers for v in (a - proud, b + proud)})
        runs = []
        for a, b in zip(cuts, cuts[1:]):
            mid = (a + b) / 2
            hw, tone = max((h, t) for la, lb, h, t in layers if la - proud < mid < lb + proud)
            if runs and runs[-1][2:] == (hw, tone):
                runs[-1] = (runs[-1][0], b, hw, tone)
            else:
                runs.append((a, b, hw, tone))
        for a, b, hw, tone in runs:
            if stop is not None:
                if b <= stop + 1e-6:
                    continue
                a = max(a, stop)
            section = (-(hw + proud), hw + proud, a, b)
            self.block(x0, section, x1, section, tone)

    def box(self, x0, x1, y0, y1, z0, z1, colour):
        """fill x [x0, x1), y [y0, y1), z [z0, z1)"""
        for i in range(x0, x1):
            for j in range(y0, y1):
                for k in range(z0, z1):
                    self.cells[(i, j, k)] = colour

    def sym(self, x0, x1, n, z0, z1, colour):
        """a box centred on y = 0, n cubes out either side (2n + 1 wide)"""
        self.box(x0, x1, -n, n + 1, z0, z1, colour)

    def pair(self, x0, x1, y0, y1, z0, z1, colour):
        """a box on the right side, y [y0, y1), and its mirror on the left"""
        self.box(x0, x1, y0, y1, z0, z1, colour)
        self.box(x0, x1, 1 - y1, 1 - y0, z0, z1, colour)

    def paint(self, x0, x1, y0, y1, z0, z1, colour):
        """recolour the cubes already there"""
        for c in self.cells:
            if x0 <= c[0] < x1 and y0 <= c[1] < y1 and z0 <= c[2] < z1:
                self.cells[c] = colour

    def paint_sym(self, x0, x1, n, z0, z1, colour):
        self.paint(x0, x1, -n, n + 1, z0, z1, colour)

    def paint_pair(self, x0, x1, y0, y1, z0, z1, colour):
        self.paint(x0, x1, y0, y1, z0, z1, colour)
        self.paint(x0, x1, 1 - y1, 1 - y0, z0, z1, colour)

    def carve(self, x0, x1, y0, y1, z0, z1):
        """remove cubes"""
        for c in [c for c in self.cells if x0 <= c[0] < x1 and y0 <= c[1] < y1 and z0 <= c[2] < z1]:
            del self.cells[c]

    def carve_pair(self, x0, x1, y0, y1, z0, z1):
        self.carve(x0, x1, y0, y1, z0, z1)
        self.carve(x0, x1, 1 - y1, 1 - y0, z0, z1)

    def dent(self, x0, x1, j, z0, z1, colour, depth=0.3, pair=True):
        """a shallow recess in the side of the body, in column j (the outermost one there): a gill slit, a scar, a leg slot.
        The cubes are cut out and the hole filled again to `depth` short of the surface, in `colour`. A hole a whole cube
        deep reads as a missing block; a third of a cube reads as a line drawn on the body. pair: on both sides; if not,
        on the side j says (negative: the left)"""
        for side in ((1, -1) if pair else ((1,) if j > 0 else (-1,))):
            col = abs(j) * side
            self.carve(x0, x1, col, col + 1, z0, z1)
            inner, outer = abs(j) - 0.55, abs(j) + 0.5 - depth  # it reaches a little into the cubes behind, so it is joined
            section = (inner, outer, z0, z1) if side > 0 else (-outer, -inner, z0, z1)
            self.block(x0, section, x1, section, colour)

    def hull(self, x0, x1, n, z0, z1, colour, top=(), bottom=()):
        """a body slab with stepped corners: a box n out either side from z0 to z1, its top corners cut in steps listed from
        the top down as (cubes in from the side, cubes tall), its bottom corners the same from the bottom up"""
        self.sym(x0, x1, n, z0, z1, colour)
        z = z1
        for inset, tall in top:
            self.carve_pair(x0, x1, n - inset + 1, n + 1, z - tall, z)
            z -= tall
        z = z0
        for inset, tall in bottom:
            self.carve_pair(x0, x1, n - inset + 1, n + 1, z, z + tall)
            z += tall


class Model:
    def __init__(self):
        self.parts = {}

    def part(self, name, pivot=(0, 0, 0), parent=None):
        p = Part(name, pivot, parent)
        self.parts[name] = p
        return p


model = Model()
M.build(model)

# ---------------------------------------------------------------- checks: gaps, hidden faces, faces too close
MIN_GAP = 0.05 / U  # in cubes: two faces that face the same way and overlap must be at least 0.05 studs apart. In one plane
# they flicker in Roblox; closer than this they shimmer at a distance
_SOLIDS, _HIDDEN = {}, {}


def solids(part):
    """a part's free pieces, measured: each face's plane (pointing out), its corners and points spread over it, and points
    spread through the piece. Free pieces are taken as convex"""
    if part.name in _SOLIDS:
        return _SOLIDS[part.name]
    import random

    rnd = random.Random(7)
    out = []
    for verts, faces, colour in part.shapes:
        cx, cy, cz = (sum(v[a] for v in verts) / len(verts) for a in range(3))
        planes = []
        for f in faces:
            a, b, c = (verts[i] for i in f[:3])
            u, w = [b[i] - a[i] for i in range(3)], [c[i] - a[i] for i in range(3)]
            n = [u[1] * w[2] - u[2] * w[1], u[2] * w[0] - u[0] * w[2], u[0] * w[1] - u[1] * w[0]]
            length = math.sqrt(sum(v * v for v in n)) or 1.0
            n = [v / length for v in n]
            d = sum(n[i] * a[i] for i in range(3))
            if n[0] * cx + n[1] * cy + n[2] * cz > d:  # point the normal away from the middle
                n, d = [-v for v in n], -d
            poly = [verts[i] for i in f]
            mid = [sum(v[k] for v in poly) / len(poly) for k in range(3)]
            pts = [tuple(v[k] + 0.03 * (mid[k] - v[k]) for k in range(3)) for v in poly]  # just inside each corner
            pts += [tuple((poly[i][k] + poly[i - 1][k]) / 2 * 0.97 + 0.03 * mid[k] for k in range(3)) for i in range(len(poly))]
            pts.append(tuple(mid))
            for _ in range(60):
                w = [rnd.random() ** 3 + 0.02 for _ in poly]
                total = sum(w)
                pts.append(tuple(sum(w[i] * poly[i][k] for i in range(len(poly))) / total for k in range(3)))
            planes.append((n, d, poly, pts))
        samples = list(verts)
        for _ in range(160):
            w = [rnd.random() ** 2 for _ in verts]
            total = sum(w)
            samples.append(tuple(sum(w[i] * verts[i][a] for i in range(len(verts))) / total for a in range(3)))
        out.append({"planes": planes, "samples": samples, "colour": colour})
    _SOLIDS[part.name] = out
    return out


def in_shape(pt, shape, margin):
    """inside a piece by at least margin (negative: or up to that far outside)"""
    return all(n[0] * pt[0] + n[1] * pt[1] + n[2] * pt[2] - d < -margin for n, d, _, _ in shape["planes"])


def cell_of(pt):
    return (math.floor(pt[0]), math.floor(pt[1] + 0.5), math.floor(pt[2]))


def hidden_faces(part):
    """for each free piece, the faces nothing can ever see: every point just outside the face is inside the part's own
    cubes or another of its own pieces. Only its own: another part swings away when a joint bends. These faces are left
    out of the mesh"""
    if part.name in _HIDDEN:
        return _HIDDEN[part.name]
    own = solids(part)
    out = []
    for i, a in enumerate(own):
        gone = set()
        for k, (n, d, poly, pts) in enumerate(a["planes"]):
            def covered(pt):
                q = tuple(pt[c] + 0.02 * n[c] for c in range(3))
                return cell_of(q) in part.cells or any(j != i and in_shape(q, b, 0.0) for j, b in enumerate(own))
            if all(covered(pt) for pt in pts):
                gone.add(k)
        out.append(gone)
    _HIDDEN[part.name] = out
    return out


def check_part(part):
    """finds, by measurement, what would show as a fault. Returns a list of lines:
    1. a free piece that reaches into nothing else in its part: it floats (a gap);
    2. two faces that face the same way, overlap and are in one plane or under 0.05 studs apart: they flicker or shimmer;
    3. a piece with no face buried in something else: it only crosses a surface, and a wedge of air shows under it.
    What it does not find: a piece that pokes out through another where it should not (use --inspect for that)."""
    shapes, hidden = solids(part), hidden_faces(part)
    every_cell = [other.cells for other in model.parts.values()]
    everything = [(other, j, sh) for other in model.parts.values() for j, sh in enumerate(solids(other))]

    def in_cells(pt, margin=0.02):
        return all(cell_of((pt[0] + dx, pt[1] + dy, pt[2] + dz)) in part.cells
                   for dx in (-margin, margin) for dy in (-margin, margin) for dz in (-margin, margin))

    def where(i):
        verts = part.shapes[i][0]
        return ", ".join(f"{sum(v[k] for v in verts) / len(verts):.1f}" for k in range(3))

    notes = []
    floating = part.name in getattr(M, "FLOATING", ())
    # 1: what touches what. A piece counts as joined when it reaches at least a little way into another piece
    count = len(shapes)
    link = list(range(count + 1))  # the last one stands for the cubes

    def find(i):
        while link[i] != i:
            link[i] = link[link[i]]
            i = link[i]
        return i

    for i, a in enumerate(shapes):
        if any(in_cells(pt) for pt in a["samples"]):
            link[find(i)] = find(count)
        for j in range(i + 1, count):
            b = shapes[j]
            if any(in_shape(pt, b, 0.02) for pt in a["samples"]) or any(in_shape(pt, a, 0.02) for pt in b["samples"]):
                link[find(i)] = find(j)
    groups = {}
    for i in range(count):
        groups.setdefault(find(i), []).append(i)
    main = find(count) if part.cells else max(groups, key=lambda g: len(groups[g]), default=None)
    def reaches_another_part(i):
        """a piece of this part that sits in another part's cubes or pieces (a whisker's root in the head)"""
        return any(cell_of(pt) in other.cells or any(in_shape(pt, sh, 0.02) for sh in solids(other))
                   for other in model.parts.values() if other is not part for pt in shapes[i]["samples"])

    for g, members in groups.items():
        if g != main and not floating and not any(reaches_another_part(i) for i in members):
            for i in members:
                notes.append(f"  ! {part.name}: piece {i} ({shapes[i]['colour']}, middle {where(i)}) touches nothing: a gap")

    # 2: faces that face the same way, overlap, and are in one plane or too close (within the part and against the others)
    def nearest(pts, shape, skip):
        """how close these points of one face come to face `skip` of another piece, where they lie over it (else None)"""
        m2, e2 = shape["planes"][skip][0], shape["planes"][skip][1]
        gaps = [abs(m2[0] * pt[0] + m2[1] * pt[1] + m2[2] * pt[2] - e2) for pt in pts
                if all(m[0] * pt[0] + m[1] * pt[1] + m[2] * pt[2] - e < -0.01 for k, (m, e, _, _) in enumerate(shape["planes"]) if k != skip)]
        return min(gaps) if gaps else None

    seen = set()
    for i, a in enumerate(shapes):
        for fk, (n, d, poly, pts) in enumerate(a["planes"]):
            if fk in hidden[i]:
                continue
            for other, j, b in everything:
                if b is a or (other is part and j < i) or (i, other.name, j) in seen:
                    continue
                gone = hidden_faces(other)[j]
                for k2, (n2, d2, _, pts2) in enumerate(b["planes"]):
                    if k2 in gone or sum(n[k] * n2[k] for k in range(3)) <= 0.999:
                        continue
                    found = [g for g in (nearest(pts, b, k2), nearest(pts2, a, fk)) if g is not None]
                    gap = min(found) if found else MIN_GAP
                    if gap < MIN_GAP:
                        seen.add((i, other.name, j))
                        who = f"piece {j} ({b['colour']})" if other is part else f"piece {j} of {other.name} ({b['colour']})"
                        how = "have faces lying on each other" if gap < 2e-3 else f"have faces only {gap * U:.3f} studs apart"
                        notes.append(f"  ! {part.name}: piece {i} ({a['colour']}, middle {where(i)}) and {who} {how} "
                                     f"(facing {n[0]:+.1f}, {n[1]:+.1f}, {n[2]:+.1f})")
                        break
            # against the cubes (any part's): a face along the grid, on or near a cube face that shows
            axis = max(range(3), key=lambda k: abs(n[k]))
            if abs(n[axis]) > 0.9999:
                at = poly[0][axis] + (0.5 if axis == 1 else 0.0)
                level, sign, hits = round(at), (1 if n[axis] > 0 else -1), 0
                if abs(at - level) < MIN_GAP:
                    for pt in pts:
                        cell = list(cell_of(pt))
                        cell[axis] = level - 1 if sign > 0 else level
                        beyond = list(cell)
                        beyond[axis] += sign
                        if any(tuple(cell) in cells for cells in every_cell) and not any(tuple(beyond) in cells for cells in every_cell):
                            hits += 1
                    if hits:
                        how = "lying on" if abs(at - level) < 2e-3 else f"only {abs(at - level) * U:.3f} studs from"
                        notes.append(f"  ! {part.name}: piece {i} ({a['colour']}, middle {where(i)}) has a face {how} a face of the cubes "
                                     f"({'xyz'[axis]} = {level - (0.5 if axis == 1 else 0)}, {hits} of {len(pts)} points)")

    # 2b: cube faces of this part lying on cube faces of another part, facing the same way (a joint's sleeve in the
    # plane of the stepped corner in front of it): they flicker too
    for other in model.parts.values():
        if other is part or other.name < part.name:
            continue
        hits, where_at = 0, None
        for (i, j, k) in part.cells:
            if (i, j, k) not in other.cells:
                continue
            for d in ((1, 0, 0), (-1, 0, 0), (0, 1, 0), (0, -1, 0), (0, 0, 1), (0, 0, -1)):
                beyond = (i + d[0], j + d[1], k + d[2])
                if beyond not in part.cells and beyond not in other.cells:
                    hits += 1
                    where_at = where_at or (i, j, k)
        if hits:
            notes.append(f"  ! {part.name}: {hits} cube faces lie on cube faces of {other.name} (first at cube {where_at}): "
                         f"a sleeve in the plane of the body in front")

    # 3: its root. A piece should have one face wholly inside something else, or flat against it (any part: a tail's root
    # sits in the body), or cap another piece's end. If not, it only crosses a surface at an angle: air shows under it
    def held(pt, me):
        for dx in (-0.04, 0.04):
            for dy in (-0.04, 0.04):
                for dz in (-0.04, 0.04):
                    key = cell_of((pt[0] + dx, pt[1] + dy, pt[2] + dz))
                    if any(key in cells for cells in every_cell):
                        return True
        return any(sh is not me and in_shape(pt, sh, -0.04) for _, _, sh in everything)

    for i, a in enumerate(shapes):
        if floating:
            break
        rooted = any(all(held(pt, a) for pt in pts[: len(poly) * 2 + 12]) for _, _, poly, pts in a["planes"])
        if not rooted:
            rooted = any(j != i and any(all(in_shape(v, a, -0.04) for v in poly) for _, _, poly, _ in b["planes"])
                         for j, b in enumerate(shapes))
        if not rooted:
            notes.append(f"  ! {part.name}: piece {i} ({a['colour']}, middle {where(i)}) has no face buried in another: its root shows")
    return notes


# ---------------------------------------------------------------- colours: each with its darker tone
palette = dict(M.PALETTE)
VARIANT = getattr(M, "VARIANT", None)
KEEP = set(getattr(M, "KEEP", ("black", "tooth", "mouth", "gum", "white")))
PLAIN = KEEP | set(getattr(M, "GLOW", {}))  # the colours a variant and the textures leave alone


def light_of(colour):
    r, g, b = (int(colour.lstrip("#")[i : i + 2], 16) / 255 for i in (0, 2, 4))
    return 0.2126 * r + 0.7152 * g + 0.0722 * b


if VARIANT == "gold":  # every colour becomes a tone of gold, the dark ones deep gold, the pale ones pale gold
    changed = [n for n in palette if n.rstrip("+-") not in PLAIN]
    lights = [light_of(palette[n]) for n in changed]
    low, high = min(lights), max(lights)
    ramp = ((0.0, (0xE8, 0xAE, 0x16)), (0.5, (0xFF, 0xCE, 0x2B)), (1.0, (0xFF, 0xF1, 0xA8)))  # yellow golds, never brown
    for n in changed:
        t = 0.5 if high - low < 1e-6 else (light_of(palette[n]) - low) / (high - low)
        (ta, ca), (tb, cb) = (ramp[0], ramp[1]) if t <= 0.5 else (ramp[1], ramp[2])
        f = (t - ta) / (tb - ta)
        palette[n] = "#%02X%02X%02X" % tuple(round(a + (b - a) * f) for a, b in zip(ca, cb))
if VARIANT:  # the creature's own light takes a colour that stands against its new body
    accent = getattr(M, "ACCENT", {"gold": "#B25CFF", "rainbow": "#FFFFFF"}.get(VARIANT))
    for n in list(palette):
        if n.rstrip("+-") in getattr(M, "GLOW", {}):
            if n.endswith(("+", "-")):
                del palette[n]  # its tones are made again from the new colour
            else:
                palette[n] = accent
SHADE = getattr(M, "SHADE", 0.86 if VARIANT == "gold" else 0.8)  # gold's darker tone stays gold
LIFT = getattr(M, "LIFT", 1.12)
for name, colour in list(palette.items()):
    if name.endswith(("-", "+")):
        continue
    rgb = [int(colour.lstrip("#")[i : i + 2], 16) for i in (0, 2, 4)]
    if name + "-" not in palette:  # the darker tone: steps below, recesses
        palette[name + "-"] = "#%02X%02X%02X" % tuple(round(c * SHADE) for c in rgb)
    if name + "+" not in palette:  # the lighter tone: plates that face up
        palette[name + "+"] = "#%02X%02X%02X" % tuple(min(255, round(c * LIFT + 8)) for c in rgb)
names = list(palette)
spec = {"name": M.NAME, "zone": getattr(M, "ZONE", ""), "rarity": getattr(M, "RARITY", ""), "colours": palette,
        "frame": getattr(M, "FRAME", 1.0), "orthoSide": getattr(M, "ORTHO", 14.5),
        "orthoSwimTop": getattr(M, "ORTHO_SWIM", 12.4 * getattr(M, "FRAME", 1.0)),
        "rideFog": getattr(M, "RIDE_FOG", "#3CBED2"), "rideFogEnd": 900}
K = kc.Kit(spec, OUT, names, 32 if SWIM else 64)
json.dump({"name": spec["name"], "zone": spec["zone"], "rarity": spec["rarity"],
           "colours": {k: v for k, v in M.PALETTE.items() if not k.endswith(("-", "+"))}},
          open(os.path.join(OUT, "spec.json"), "w"), indent=2)  # for tools/art/creature_sheet.py

# ---------------------------------------------------------------- the weld: one closed shell per part
def cells_shell(cells):
    """the cubes' outer faces as one mesh with shared corners, a quad per cube face (the weld merges the flat ones after)"""
    bm = bmesh.new()
    corners = {}

    def corner(i, j2, k):  # j2: y in half cubes
        if (i, j2, k) not in corners:
            corners[(i, j2, k)] = bm.verts.new((i * U, j2 * U / 2, k * U))
        return corners[(i, j2, k)]

    for (i, j, k), mat in cells.items():
        a, b = 2 * j - 1, 2 * j + 1
        sides = (((i - 1, j, k), ((i, a, k), (i, a, k + 1), (i, b, k + 1), (i, b, k))),
                 ((i + 1, j, k), ((i + 1, a, k), (i + 1, b, k), (i + 1, b, k + 1), (i + 1, a, k + 1))),
                 ((i, j - 1, k), ((i, a, k), (i + 1, a, k), (i + 1, a, k + 1), (i, a, k + 1))),
                 ((i, j + 1, k), ((i, b, k), (i, b, k + 1), (i + 1, b, k + 1), (i + 1, b, k))),
                 ((i, j, k - 1), ((i, a, k), (i, b, k), (i + 1, b, k), (i + 1, a, k))),
                 ((i, j, k + 1), ((i, a, k + 1), (i + 1, a, k + 1), (i + 1, b, k + 1), (i, b, k + 1))))
        for neighbour, quad in sides:
            if neighbour not in cells:
                bm.faces.new([corner(*c) for c in quad]).material_index = mat
    return bm


def weld(name, pieces):
    """the union of a part's pieces (bmeshes: its cubes' shell and each free piece) as one bmesh: a single closed surface
    with nothing inside it. Coloured by each piece's own material slots. Flat neighbours of one colour are merged"""
    obs = []
    for k, piece in enumerate(pieces):
        me = bpy.data.meshes.new(f"{name}_piece{k}")
        piece.to_mesh(me)
        piece.free()
        for mat_name in names:
            me.materials.append(K.mats[mat_name])
        obs.append(bpy.data.objects.new(me.name, me))
    base, group = obs[0], None
    K.scene.collection.objects.link(base)
    if len(obs) > 1:
        group = bpy.data.collections.new(name + "_pieces")
        K.scene.collection.children.link(group)
        for ob in obs[1:]:
            group.objects.link(ob)
        mod = base.modifiers.new("Weld", "BOOLEAN")
        mod.operation, mod.operand_type, mod.collection, mod.solver = "UNION", "COLLECTION", group, "EXACT"
        if hasattr(mod, "material_mode"):
            mod.material_mode = "INDEX"
    bpy.context.view_layer.update()
    out = bmesh.new()
    out.from_object(base, bpy.context.evaluated_depsgraph_get())
    for ob in obs:
        me = ob.data
        bpy.data.objects.remove(ob)
        bpy.data.meshes.remove(me)
    if group:
        bpy.data.collections.remove(group)
    bmesh.ops.remove_doubles(out, verts=out.verts, dist=1e-5)
    bmesh.ops.dissolve_degenerate(out, dist=1e-5, edges=out.edges)
    bmesh.ops.dissolve_limit(out, angle_limit=math.radians(0.2), use_dissolve_boundaries=False, verts=out.verts, edges=out.edges,
                             delimit={"MATERIAL"})
    return out


def islands(bm):
    """how many separate pieces a mesh is in"""
    seen, count = set(), 0
    for v in bm.verts:
        if v.index in seen:
            continue
        count += 1
        stack = [v]
        seen.add(v.index)
        while stack:
            for e in stack.pop().link_edges:
                for w in e.verts:
                    if w.index not in seen:
                        seen.add(w.index)
                        stack.append(w)
    return count


# ---------------------------------------------------------------- the parts
objects, triangles, cubes, all_triangles, faults = {}, 0, 0, 0, []
lo, hi = [10**9] * 3, [-(10**9)] * 3
for part in model.parts.values():
    cells = {c: names.index(colour) for c, colour in part.cells.items()}
    for c in cells:
        for a in range(3):
            lo[a], hi[a] = min(lo[a], c[a]), max(hi[a], c[a] + 1)
    for verts, _, _ in part.shapes:
        for x, y, z in verts:
            for a, v in enumerate((x, y, z)):
                lo[a], hi[a] = min(lo[a], math.floor(v)), max(hi[a], math.ceil(v))
    bm, quads = kc.cells_to_bm(cells, U)
    part_triangles = everything = 2 * quads + sum(len(f) - 2 for _, faces, _ in part.shapes for f in faces)
    note = ""
    if WELD and (cells or part.shapes):  # one closed shell: nothing hidden at all, but more triangles (every pierced face is cut)
        bm.free()
        pieces = [cells_shell(cells)] if cells else []
        for verts, faces, colour in part.shapes:
            piece = bmesh.new()
            vs = [piece.verts.new((x * U, y * U, z * U)) for x, y, z in verts]
            for f in faces:
                piece.faces.new([vs[i] for i in f]).material_index = names.index(colour)
            bmesh.ops.recalc_face_normals(piece, faces=piece.faces)
            pieces.append(piece)
        bm = weld(part.name, pieces)
        bm.verts.index_update()
        open_edges = sum(1 for e in bm.edges if len(e.link_faces) != 2)
        shells = islands(bm)
        # each flat face on its own corners: a corner of one face may sit on a neighbour's straight edge (as the cubes'
        # merged faces always did), which saves the triangles a shared corner would cost
        lean = bmesh.new()
        for f in bm.faces:
            ring = [loop.vert.co.copy() for loop in f.loops]
            keep = [co for k, co in enumerate(ring) if (co - ring[k - 1]).cross(ring[(k + 1) % len(ring)] - co).length > 1e-7]
            if len(keep) >= 3:
                lean.faces.new([lean.verts.new(co) for co in keep]).material_index = f.material_index
        bm.free()
        bm = lean
        part_triangles = sum(len(f.verts) - 2 for f in bm.faces)
        note = f", welded into {shells} shell" + ("s" if shells != 1 else "") + f" (the loose pieces: {everything})"
        if open_edges:
            faults.append(f"  ! {part.name}: the welded shell is not closed ({open_edges} open edges)")
        if shells != 1:
            faults.append(f"  ! {part.name}: the weld left {shells} separate shells: something floats")
    else:  # the loose pieces, without the faces nothing can see
        gone = [set() for _ in part.shapes] if ALL_FACES else hidden_faces(part)
        measured = solids(part)
        for i, (verts, faces, colour) in enumerate(part.shapes):
            vs = [bm.verts.new((x * U, y * U, z * U)) for x, y, z in verts]
            for k, f in enumerate(faces):
                if k in gone[i]:
                    part_triangles -= len(f) - 2
                    continue
                face = bm.faces.new([vs[j] for j in f])
                face.material_index = names.index(colour)
                face.normal_update()
                if face.normal.dot(measured[i]["planes"][k][0]) < 0:
                    face.normal_flip()
        bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
        if everything != part_triangles:
            note = f" ({everything - part_triangles} hidden ones left out)"
    triangles += part_triangles
    all_triangles += everything
    cubes += len(cells)
    px, py, pz = part.pivot
    objects[part.name] = K.mesh_object(part.name, bm, (px * U, py * U, pz * U))
    print(f"  {part.name}: {len(cells)} cubes, {part_triangles} triangles{note}")
    faults += check_part(part)
for part in model.parts.values():
    if part.parent:
        K.attach(objects[part.name], objects[part.parent])

# glow: colours that shine by themselves (Roblox: the Neon material), and small lights that spill onto the creature
for name, strength in getattr(M, "GLOW", {}).items():
    for key in (name, name + "-", name + "+"):
        if key in K.mats:
            bsdf = K.mats[key].node_tree.nodes.get("Principled BSDF")
            bsdf.inputs["Emission Color"].default_value = bsdf.inputs["Base Color"].default_value
            bsdf.inputs["Emission Strength"].default_value = strength
for i, (part_name, (lx, ly, lz), colour, watts, radius) in enumerate(getattr(M, "LIGHTS", [])):
    for side in ((1, -1) if ly else (1,)):
        data = bpy.data.lights.new(f"Glow{i}", "POINT")
        data.color = kc.hex_rgba(colour)[:3]
        data.energy = watts
        data.shadow_soft_size = radius * U
        light = bpy.data.objects.new(f"Glow{i}{side:+d}", data)
        K.scene.collection.objects.link(light)
        light.location = (lx * U, side * ly * U, lz * U)
        K.world_pos[light.name] = light.location.copy()
        K.attach(light, objects[part_name])
# ---------------------------------------------------------------- variants and textures (docs/style/06-textures.md)
if VARIANT == "gold":
    for name, mat in K.mats.items():
        if name.rstrip("+-") not in PLAIN:
            bsdf = mat.node_tree.nodes.get("Principled BSDF")
            bsdf.inputs["Roughness"].default_value = 0.35
            if "Specular IOR Level" in bsdf.inputs:
                bsdf.inputs["Specular IOR Level"].default_value = 0.6
if VARIANT == "rainbow":
    # one smooth rainbow from nose to tail, straight across the body. It is made of flat hues, and each hue is mixed into
    # the next pixel by pixel in an ordered pattern (very small pixels, several to a cube), as a gradient is dithered in
    # pixel art: smooth from a distance, crisp pixels close up. Every body colour takes the same vivid rainbow; only the
    # pale colours (a belly) take it paler, and a colour's darker tone takes it a little darker
    stops = ("#FF2F4A", "#FF7A14", "#FFD60A", "#2FD452", "#12C6F0", "#3266FF", "#9A3DFF", "#FF3DCB")
    opts = {"steps": 14, "pixels": 9, "dither": 1.0, "wobble": 0.0, "grain": "bayer", "pastel": 0.1}
    opts.update(getattr(M, "RAINBOW", {}))
    size = U / opts["pixels"]  # one small pixel, in studs
    span = max((hi[0] - lo[0]) * U / size, 1.0)  # the body's length, in pixels
    order = bpy.data.images.new("Dither", 4, 4, float_buffer=True, is_data=True)  # the ordered pattern, four by four
    order.pixels = [c for v in (0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5) for c in ((v + 0.5) / 16,) * 3 + (1.0,)]
    for name, mat in K.mats.items():
        if name.rstrip("+-") in PLAIN:
            continue
        nt = mat.node_tree
        bsdf = nt.nodes.get("Principled BSDF")
        light = light_of(palette.get(name.rstrip("+-"), palette[name]))

        def node(kind, **settings):
            made = nt.nodes.new(kind)
            for key, value in settings.items():
                setattr(made, key, value)
            return made

        def maths(operation, a, b=None, c=None):
            made = node("ShaderNodeMath", operation=operation)
            for socket, value in zip(made.inputs, (a, b, c)):
                if value is None:
                    continue
                if isinstance(value, (int, float)):
                    socket.default_value = value
                else:
                    nt.links.new(value, socket)
            return made.outputs[0]

        where = node("ShaderNodeNewGeometry")
        inward = node("ShaderNodeVectorMath", operation="SCALE")  # step a little inside the surface
        inward.inputs["Scale"].default_value = -0.004
        nt.links.new(where.outputs["True Normal"], inward.inputs[0])
        inside = node("ShaderNodeVectorMath", operation="ADD")
        nt.links.new(where.outputs["Position"], inside.inputs[0])
        nt.links.new(inward.outputs[0], inside.inputs[1])
        scaled = node("ShaderNodeVectorMath", operation="SCALE")
        scaled.inputs["Scale"].default_value = 1.0 / size
        nt.links.new(inside.outputs[0], scaled.inputs[0])
        pixel = node("ShaderNodeVectorMath", operation="FLOOR")  # which small pixel this point is in
        nt.links.new(scaled.outputs[0], pixel.inputs[0])
        split = node("ShaderNodeSeparateXYZ")
        nt.links.new(pixel.outputs[0], split.inputs[0])
        px, py, pz = split.outputs["X"], split.outputs["Y"], split.outputs["Z"]
        if opts["grain"] == "noise":
            grain_node = node("ShaderNodeTexWhiteNoise", noise_dimensions="3D")
            nt.links.new(pixel.outputs[0], grain_node.inputs["Vector"])
            grain = grain_node.outputs["Value"]
        else:  # the ordered pattern, looked up by the pixel's place on the face: the two numbers that change across it
            face = node("ShaderNodeVectorMath", operation="ABSOLUTE")
            nt.links.new(where.outputs["True Normal"], face.inputs[0])
            axes = node("ShaderNodeSeparateXYZ")
            nt.links.new(face.outputs[0], axes.inputs[0])
            ax, ay, az = axes.outputs["X"], axes.outputs["Y"], axes.outputs["Z"]
            ends = maths("MULTIPLY", maths("GREATER_THAN", ax, ay), maths("GREATER_THAN", ax, az))  # a face that looks along the body
            tops = maths("MULTIPLY", maths("GREATER_THAN", az, ay), maths("SUBTRACT", 1.0, ends))  # a face that looks up or down
            u = maths("ADD", px, maths("MULTIPLY", ends, maths("SUBTRACT", py, px)))
            v = maths("ADD", pz, maths("MULTIPLY", tops, maths("SUBTRACT", py, pz)))
            look = node("ShaderNodeCombineXYZ")
            nt.links.new(maths("DIVIDE", maths("ADD", u, 0.5), 4.0), look.inputs["X"])
            nt.links.new(maths("DIVIDE", maths("ADD", v, 0.5), 4.0), look.inputs["Y"])
            grain_node = node("ShaderNodeTexImage", interpolation="Closest", image=order)
            nt.links.new(look.outputs[0], grain_node.inputs["Vector"])
            grain = grain_node.outputs["Color"]
        drift = node("ShaderNodeTexNoise", noise_dimensions="3D")  # a slow wander, so the edge between hues isn't ruled
        drift.inputs["Scale"].default_value = 0.11 * opts["pixels"] / max(U, 0.01) * size
        drift.inputs["Detail"].default_value = 0.0
        nt.links.new(pixel.outputs[0], drift.inputs["Vector"])
        along = maths("DIVIDE", maths("SUBTRACT", maths("ADD", px, 0.5), lo[0] * U / size), span)
        mixed = maths("ADD", maths("MULTIPLY_ADD", grain, opts["dither"], -opts["dither"] / 2),
                      maths("MULTIPLY_ADD", drift.outputs[0], 2 * opts["wobble"], -opts["wobble"]))
        stepped = maths("DIVIDE", maths("FLOOR", maths("ADD", maths("MULTIPLY", along, opts["steps"]), mixed)), opts["steps"] - 1)
        bow = node("ShaderNodeValToRGB")
        bow.color_ramp.elements[0].position, bow.color_ramp.elements[0].color = 0.0, kc.hex_rgba(stops[0])
        bow.color_ramp.elements[1].position, bow.color_ramp.elements[1].color = 1.0, kc.hex_rgba(stops[-1])
        for k, stop in enumerate(stops[1:-1]):
            bow.color_ramp.elements.new((k + 1) / (len(stops) - 1)).color = kc.hex_rgba(stop)
        pale = node("ShaderNodeMix", data_type="RGBA", blend_type="MIX")
        pale.inputs[0].default_value = (0.5 if light > 0.7 else opts["pastel"]) + (0.08 if name.endswith("+") else 0.0)
        pale.inputs[7].default_value = (1.0, 1.0, 1.0, 1.0)
        deep = node("ShaderNodeMix", data_type="RGBA", blend_type="MULTIPLY")
        deep.inputs[0].default_value = 1.0
        tone = 0.74 if name.endswith("-") else 1.0
        deep.inputs[7].default_value = (tone, tone, tone, 1.0)
        nt.links.new(stepped, bow.inputs["Fac"])
        nt.links.new(bow.outputs["Color"], pale.inputs[6])
        nt.links.new(pale.outputs[2], deep.inputs[6])
        nt.links.new(deep.outputs[2], bsdf.inputs["Base Color"])

TILES = os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))), "art", "style", "tiles")
rules = list(getattr(M, "TEXTURES", []))
if VARIANT == "gold" and not rules:
    rules = [{"tile": "sparkle", "on": "top+sides", "size": 4, "strength": 0.45}]


def textured(colour, tile, strength):
    """the colour's material with a tile laid over it: mid grey leaves the colour, lighter lifts it, darker shades it"""
    key = f"{colour}|{tile}|{strength}"
    if key not in K.mats:
        mat = K.mats[colour].copy()
        mat.name = key
        nt = mat.node_tree
        bsdf = nt.nodes.get("Principled BSDF")
        picture = nt.nodes.new("ShaderNodeTexImage")
        picture.image = bpy.data.images.load(os.path.join(TILES, tile + ".png"), check_existing=True)
        picture.image.colorspace_settings.name = "Non-Color"
        shade = nt.nodes.new("ShaderNodeMath")
        shade.operation = "MULTIPLY_ADD"  # 1 + 2 x strength x (grey - 0.5)
        shade.inputs[1].default_value, shade.inputs[2].default_value = 2.0 * strength, 1.0 - strength
        mix = nt.nodes.new("ShaderNodeMix")
        mix.data_type, mix.blend_type = "RGBA", "MULTIPLY"
        mix.inputs[0].default_value = 1.0
        base = bsdf.inputs["Base Color"]
        if base.is_linked:
            nt.links.new(base.links[0].from_socket, mix.inputs[6])
        else:
            mix.inputs[6].default_value = base.default_value
        nt.links.new(picture.outputs["Color"], shade.inputs[0])
        nt.links.new(shade.outputs[0], mix.inputs[7])
        nt.links.new(mix.outputs[2], base)
        if bsdf.inputs["Emission Strength"].default_value > 0:
            nt.links.new(mix.outputs[2], bsdf.inputs["Emission Color"])
        K.mats[key] = mat
    return K.mats[key]


if rules:
    bpy.context.view_layer.update()
    colour_of = {mat.name: name for name, mat in K.mats.items()}
    covered = 0
    for part_name, ob in objects.items():
        me = ob.data
        uv = me.uv_layers.new(name="tile")
        turn = ob.matrix_world.to_3x3()
        for poly in me.polygons:
            colour = colour_of.get(me.materials[poly.material_index].name)
            if colour is None:
                continue
            n = turn @ poly.normal
            axis = max(range(3), key=lambda a: abs(n[a]))
            square = abs(n[axis]) > 0.985
            mid = ob.matrix_world @ poly.center
            for rule in rules:
                if "parts" in rule and part_name not in rule["parts"]:
                    continue
                if "colours" in rule:
                    if colour.rstrip("+-") not in rule["colours"]:
                        continue
                elif colour.rstrip("+-") in PLAIN:
                    continue
                if "x" in rule and not rule["x"][0] <= mid.x / U <= rule["x"][1]:
                    continue
                if not square and not rule.get("turned"):
                    continue
                on = rule.get("on", "top")
                if not (on == "all" or (axis == 2 and n.z > 0 and "top" in on) or (axis == 1 and "sides" in on)):
                    continue
                mat = textured(colour, rule["tile"], rule.get("strength", 0.5))
                if mat.name not in me.materials:
                    me.materials.append(mat)
                poly.material_index = list(me.materials).index(mat)
                size = rule.get("size", 1)
                for loop in poly.loop_indices:
                    c = (ob.matrix_world @ me.vertices[me.loops[loop].vertex_index].co) / U
                    uv.data[loop].uv = ((c.x / size, (c.y + 0.5) / size) if axis == 2 else
                                        (c.x / size, c.z / size) if axis == 1 else ((c.y + 0.5) / size, c.z / size))
                covered += 1
                break
    print(f"voxel kit: textures on {covered} faces")
print(f"voxel kit: {M.NAME}: {len(objects)} parts, {cubes} cubes of {U} studs, {triangles} triangles, "
      f"{(hi[0] - lo[0]) * U:.1f} x {(hi[1] - lo[1] - 1) * U:.1f} x {(hi[2] - lo[2]) * U:.1f} studs")
print(f"voxel kit: {triangles} triangles drawn, of {all_triangles} with every face of every piece" + (" (welded)" if WELD else ""))
for line in faults:
    print(line)
if faults and not FORCE:
    print(f"voxel kit: {len(faults)} faults: stopped before rendering. Fix them (or pass --force to render anyway)")
    sys.exit(2)
if CHECK:
    sys.exit(0)

# ---------------------------------------------------------------- the views (kit_common)
K.studio()
front_x = lo[0] * U - 0.3
mid_x = (front_x + hi[0] * U) / 2

if SWIM:
    if hasattr(M, "pose"):
        def pose(phase):
            M.pose(objects, phase)
    else:
        sw = M.SWIM
        chain = [objects[n] for n in sw["chain"]]

        def pose(phase):
            chain[0].rotation_euler.z = math.radians(sw.get("headCounter", 2)) * math.sin(phase + math.pi)
            for k, ob in enumerate(chain[1:]):
                ob.rotation_euler.z = math.radians(sw["amplitudes"][k]) * math.sin(phase - sw.get("phaseStep", 0.9) * (k + 1))

    folder = os.path.join(OUT, "swim_voxel")
    K.swim(folder, 24, pose, mid_x)
    print("voxel kit: swim", folder)
    sys.exit(0)

if INSPECT:  # close views from the sides nobody draws: below, behind, above, and the head from low and high
    K.scene.render.film_transparent = True
    K.scene.render.image_settings.color_mode = "RGBA"
    os.makedirs(os.path.join(OUT, "inspect"), exist_ok=True)
    f, back_x = K.frame, hi[0] * U
    views = {"head_low": ((front_x - 5.5 * f, -8.0 * f, -4.5 * f), (front_x + 3.0 * f, 0.0, 0.0), 70),
             "head_high": ((front_x - 4.0 * f, -6.5 * f, 8.0 * f), (front_x + 3.0 * f, 0.0, 0.5), 70),
             "head_side": ((front_x + 2.5 * f, -14.0 * f, 0.5), (front_x + 2.5 * f, 0.0, 0.3), 110),
             "under": ((mid_x - 6.0 * f, -9.0 * f, -15.0 * f), (mid_x, 0.0, 0.0), 60),
             "rear": ((back_x + 13.0 * f, -12.0 * f, 7.0 * f), (mid_x + 2.0 * f, 0.0, 0.5), 60),
             "rear_low": ((back_x + 9.0 * f, -11.0 * f, -8.0 * f), (mid_x + 2.0 * f, 0.0, 0.0), 60),
             "above": ((mid_x - 4.0 * f, -5.0 * f, 22.0 * f), (mid_x, 0.0, 0.0), 60)}
    for name, (where, at, lens) in views.items():
        cam = K.camera("Inspect_" + name, lens=lens)
        kc.look_from(cam, where, at)
        K.render(cam, os.path.join(OUT, "inspect", name + ".png"), 1000, 760)
    print("voxel kit: inspect", os.path.join(OUT, "inspect"))
    sys.exit(0)

K.turnaround(front_x, mid_x)
if WIRE:
    K.wire(front_x)
sx, sz, sw_ = M.SEAT
K.seat_view(sx * U, sz * U, sw_ * U)
K.ride(sx * U, sz * U, sw_ * U)
print("voxel kit: done", OUT)
