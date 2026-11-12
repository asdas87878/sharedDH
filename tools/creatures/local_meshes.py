"""Writes every creature's parts as Roblox mesh files into Studio's own content folder, so a place can show them as
rbxasset://ridefish/<Id>/<Part>.mesh with nothing uploaded (install.py --local; why: docs/Handoff.md, 2026-11-12).
Each part three times: its own colours, gold (<Part>.gold.mesh) and rainbow (<Part>.rainbow.mesh). The variants'
colour rules are the ones in src/shared/Variants.luau (keep the two alike): gold by how light each colour is, the
rainbow by where each corner is along the body (the faces are cut across the body first, so the gradient stays
smooth on a long box), the creature's glowing parts in the variant's accent.

usage: python tools/creatures/local_meshes.py [Id ...]      (no Ids: all; prints the folder it wrote to)
  write(ids) -> {Id: [{"name", "centre" [x, y, z], "size" [x, y, z]}...]}   (what install.py places)
The content folder belongs to one Studio version: after Studio updates itself the files are gone and the fish show
as nothing, until this is run again (the place needs no new install).
"""
import glob
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import glb_meshes  # noqa: E402
import rbxmesh  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
FOLDER = "ridefish"  # under content: rbxasset://ridefish/...
VARIANTS = ("", "gold", "rainbow")

GOLD = ((232, 174, 22), (255, 206, 43), (255, 241, 168))
STOPS = ((255, 47, 74), (255, 122, 20), (255, 214, 10), (47, 212, 82), (18, 198, 240), (50, 102, 255), (154, 61, 255),
         (255, 61, 203))
ACCENT = {"gold": (178, 92, 255), "rainbow": (255, 255, 255)}
PASTEL, DARK, SLICES = 0.1, 0.1, 24
DETAIL_DARK, DETAIL_SHARE = 0.25, 0.22


def content_folder():
    """Studio's content folder: STUDIO_CONTENT, or the newest version Vinegar has."""
    found = os.environ.get("STUDIO_CONTENT")
    if found:
        return found
    versions = glob.glob(os.path.expanduser("~/.var/app/org.vinegarhq.Vinegar/data/vinegar/versions/*/content"))
    if not versions:
        sys.exit("no Studio content folder found: set STUDIO_CONTENT to it")
    return max(versions, key=os.path.getmtime)


def mix(a, b, t):
    return [a[i] + (b[i] - a[i]) * t for i in range(3)]


def light(c):
    return 0.2126 * c[0] + 0.7152 * c[1] + 0.0722 * c[2]


def gold(c, low, high):
    v = light(c)
    if v < DARK:
        return c
    low = max(low, DARK)
    t = 0.5 if high - low < 1e-3 else min(max((v - low) / (high - low), 0), 1)
    ramp = [[x / 255 for x in g] for g in GOLD]
    return mix(ramp[0], ramp[1], t * 2) if t <= 0.5 else mix(ramp[1], ramp[2], t * 2 - 1)


def hue(along):
    at = (along % 1) * (len(STOPS) - 1)
    i = int(at)
    a, b = STOPS[i], STOPS[min(i + 1, len(STOPS) - 1)]
    return mix(mix([x / 255 for x in a], [x / 255 for x in b], at - i), [1, 1, 1], PASTEL)


def rainbow(c, along):
    v = light(c)
    if v < DARK:
        return c
    h = hue(min(max(along, 0), 0.9999))
    if v > 0.8:
        return mix(h, [1, 1, 1], 0.45)
    if v < 0.3:
        return mix(h, [0, 0, 0], 0.22)
    return h


def lit(variant, c):
    return mix([0, 0, 0], [x / 255 for x in ACCENT[variant]], min(max(0.55 + light(c) * 0.6, 0.55), 1))


def cut(corners, lo, step):
    """A triangle cut by the planes z = lo + k * step: the pieces, each a list of corners in the triangle's own turn."""
    zs = [p[2] for p in corners]
    first = int((min(zs) - lo) // step)
    last = int((max(zs) - lo) / step - 1e-6)
    if last <= first:
        return [corners]
    pieces = []
    for slab in range(first, last + 1):
        a, b = lo + slab * step, lo + (slab + 1) * step
        poly = corners
        for side in (0, 1):
            kept = []
            for i, p in enumerate(poly):
                q = poly[(i + 1) % len(poly)]
                pin = p[2] >= a - 1e-6 if side == 0 else p[2] <= b + 1e-6
                qin = q[2] >= a - 1e-6 if side == 0 else q[2] <= b + 1e-6
                if pin:
                    kept.append(p)
                if pin != qin:
                    edge = a if side == 0 else b
                    kept.append(mix(p, q, (edge - p[2]) / (q[2] - p[2])))
            poly = kept
        if len(poly) >= 3:
            pieces.append(poly)
    return pieces


def write(ids=None, quiet=False):
    out_root = os.path.join(content_folder(), FOLDER)
    glbs = {}
    for path in glob.glob(os.path.join(ROOT, "art", "creatures", "*", "game", "*.glb")):
        glbs[os.path.basename(os.path.dirname(os.path.dirname(path)))] = path
    boxes = {}
    for cid in ids or sorted(glbs):
        parts = [p for p in glb_meshes.parts(glbs[cid]) if p["triangles"]]
        rig = os.path.join(ROOT, "src", "shared", "Creatures", cid + ".json")
        glow = set(json.load(open(rig, encoding="utf-8"))["Glow"]) if os.path.exists(rig) else set()
        # the body's length (z, the nose at the low end) and how light its colours are
        zlo = min(p["origin"][2] + v[2] for p in parts for v in p["positions"])
        zhi = max(p["origin"][2] + v[2] for p in parts for v in p["positions"])
        length = max(zhi - zlo, 0.01)
        # dark colours that are only details (pupils, a line round a band) stay as they are: by the share of the
        # creature's surface each colour covers (a dark body still turns)
        area, total = {}, 0.0
        for p in parts:
            for a, b, c in p["triangles"]:
                u = [p["positions"][b][i] - p["positions"][a][i] for i in range(3)]
                w = [p["positions"][c][i] - p["positions"][a][i] for i in range(3)]
                size = 0.5 * sum(x * x for x in (u[1] * w[2] - u[2] * w[1], u[2] * w[0] - u[0] * w[2],
                                                 u[0] * w[1] - u[1] * w[0])) ** 0.5
                key = tuple(p["colours"][a])
                area[key] = area.get(key, 0.0) + size
                total += size
        keep = {k for k, v in area.items() if light(k) < DETAIL_DARK and v < DETAIL_SHARE * total}
        lights = [light(c) for p in parts if p["name"] not in glow for c in p["colours"]
                  if light(c) >= DARK and tuple(c) not in keep]
        low, high = (min(lights), max(lights)) if lights else (0, 1)
        folder = os.path.join(out_root, cid)
        os.makedirs(folder, exist_ok=True)
        rows = []
        for p in parts:
            pos = p["positions"]
            lo = [min(v[i] for v in pos) for i in range(3)]
            hi = [max(v[i] for v in pos) for i in range(3)]
            mid = [(lo[i] + hi[i]) / 2 for i in range(3)]
            centred = [[v[i] - mid[i] for i in range(3)] for v in pos]
            lit_part = p["name"] in glow
            for variant in VARIANTS:
                name = p["name"] + ("." + variant if variant else "") + ".mesh"
                if variant == "":
                    rbxmesh.write(os.path.join(folder, name), centred, p["normals"], p["colours"], p["triangles"])
                elif lit_part or variant == "gold":
                    colours = [lit(variant, c) if lit_part else c if tuple(c) in keep else gold(c, low, high)
                               for c in p["colours"]]
                    rbxmesh.write(os.path.join(folder, name), centred, p["normals"], colours, p["triangles"])
                else:
                    # the rainbow: cut across the body, each corner the hue of its place
                    z0 = p["origin"][2] + mid[2]  # the part's middle along the body
                    vs, ns, cs, ts = [], [], [], []
                    for a, b, c in p["triangles"]:
                        base, normal = p["colours"][a], p["normals"][a]
                        for poly in cut([centred[a], centred[b], centred[c]], zlo - z0, length / SLICES):
                            start = len(vs)
                            for v in poly:
                                vs.append(v)
                                ns.append(normal)
                                cs.append(base if tuple(base) in keep else rainbow(base, (z0 + v[2] - zlo) / length))
                            for k in range(1, len(poly) - 1):
                                ts.append([start, start + k, start + k + 1])
                    rbxmesh.write(os.path.join(folder, name), vs, ns, cs, ts)
            rows.append({
                "name": p["name"],
                "centre": [p["origin"][i] + mid[i] for i in range(3)],
                "size": [max(hi[i] - lo[i], 0.01) for i in range(3)],
            })
        boxes[cid] = rows
    if not quiet:
        print("%d creatures' meshes written to %s" % (len(boxes), out_root))
    return boxes


if __name__ == "__main__":
    write(sys.argv[1:] or None)
