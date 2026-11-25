"""Works out each creature's trail colours from its own palette (art/creatures/<Id>/game) and writes
src/shared/FishTrailColours.luau: Main (the biggest area of it that has a colour) and Glow (what glows on it, else its
strongest accent). usage: python tools/trails/fish_colours.py [--sheet work/trails/colours.png]
Run again after a recolour or a new creature. Only creatures the game has (src/shared/Creatures/<Id>.json)."""
import colorsys, glob, json, os, sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))


def rgb(h):
    return tuple(int(h[i : i + 2], 16) for i in (1, 3, 5))


def base(name):
    return name.rstrip("+-")


def areas(obj, order):
    """Each palette cell's share of the surface (the OBJ's vt u names the cell)."""
    vs, vts, out = [], [], {}
    for line in open(obj, encoding="utf-8"):
        p = line.split()
        if not p:
            continue
        if p[0] == "v":
            vs.append(tuple(map(float, p[1:4])))
        elif p[0] == "vt":
            vts.append(float(p[1]))
        elif p[0] == "f":
            c = [q.split("/") for q in p[1:]]
            a = [vs[int(q[0]) - 1] for q in c]
            u = vts[int(c[0][1]) - 1]
            cell = order[min(len(order) - 1, int(u * len(order)))]
            s = 0.0
            for i in range(1, len(a) - 1):
                x = [a[i][k] - a[0][k] for k in range(3)]
                y = [a[i + 1][k] - a[0][k] for k in range(3)]
                n = (x[1] * y[2] - x[2] * y[1], x[2] * y[0] - x[0] * y[2], x[0] * y[1] - x[1] * y[0])
                s += 0.5 * sum(q * q for q in n) ** 0.5
            out[base(cell)] = out.get(base(cell), 0) + s
    return out


def vivid(c):
    h, s, v = colorsys.rgb_to_hsv(*[x / 255 for x in c])
    return s * v


def lift(c, sat, val):
    h, s, v = colorsys.rgb_to_hsv(*[x / 255 for x in c])
    s = min(1, max(s, sat)) if s > 0.12 else s
    r = colorsys.hsv_to_rgb(h, s, max(v, val))
    return tuple(round(x * 255) for x in r)


rows = []
for f in sorted(glob.glob(os.path.join(ROOT, "art/creatures/*/game/*.mesh.json"))):
    id = os.path.basename(os.path.dirname(os.path.dirname(f)))
    if not os.path.exists(os.path.join(ROOT, "src/shared/Creatures", id + ".json")):
        continue
    d = json.load(open(f, encoding="utf-8"))
    cells = d["paletteCells"]
    share = areas(os.path.join(os.path.dirname(f), d["mesh"]), list(cells))
    total = sum(share.values()) or 1
    share = {k: v / total for k, v in share.items()}
    skip = {"mouth", "gum", "tooth", "tongue", "eye", "white", "black", "pupil"}
    body = [k for k in share if k in cells and k not in skip]
    glow = [k for k in (d.get("glow") or {}) if k in cells]
    main = max(body, key=lambda k: share[k] * (0.15 + vivid(rgb(cells[k]))), default=None)
    if main is None:
        main = max(share, key=lambda k: share[k])
    if glow:
        g = max(glow, key=lambda k: (0.02 + share.get(k, 0)) * (0.1 + vivid(rgb(cells[k]))))
    else:
        g = max(body or [main], key=lambda k: vivid(rgb(cells[k])) * min(1, share[k] / 0.04 + 0.2))
    rows.append((id, lift(rgb(cells[main]), 0.3, 0.6), lift(rgb(cells[g]), 0.55, 0.95), main, g, bool(glow)))

out = [
    "--!strict",
    "-- Each creature's own trail colours, from its palette. Written by tools/trails/fish_colours.py: don't edit by hand.",
    "-- Main: the colour its haze leans to; Glow: what glows on it, or its strongest accent.",
    "-- stylua: ignore",
    "return {",
]
for id, m, g, mn, gn, gl in rows:
    out.append(
        f"\t{id} = {{ Main = Color3.fromRGB({m[0]}, {m[1]}, {m[2]}), Glow = Color3.fromRGB({g[0]}, {g[1]}, {g[2]}) }}, -- {mn}, {gn}{' (glows)' if gl else ''}"
    )
out.append("} :: { [string]: { Main: Color3, Glow: Color3 } }")
open(os.path.join(ROOT, "src/shared/FishTrailColours.luau"), "w", encoding="utf-8", newline="\n").write("\n".join(out) + "\n")
print(len(rows), "creatures")
if len(sys.argv) > 2:
    from PIL import Image, ImageDraw

    W = 6
    im = Image.new("RGB", (W * 200, (len(rows) // W + 1) * 34), (40, 60, 80))
    dr = ImageDraw.Draw(im)
    for i, (id, m, g, *_r) in enumerate(rows):
        x, y = (i % W) * 200, (i // W) * 34
        dr.rectangle((x, y, x + 40, y + 30), fill=m)
        dr.rectangle((x + 42, y, x + 82, y + 30), fill=g)
        dr.text((x + 86, y + 8), id[:18], fill="white")
    os.makedirs(os.path.dirname(sys.argv[2]) or ".", exist_ok=True)
    im.save(sys.argv[2])
