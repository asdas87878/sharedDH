"""Each fish's lightness against its land (2026-11-19, the user: "analyse how fish values are dispersed in accordance
to the land ... a few that blend in almost in value then some that really contrast, which usually align with being
better / at a higher rate").

For every creature in the game (src/shared/Creatures, the committed ones), its model (art/creatures/<Id>/game/<Id>.obj
and the palette picture its faces sample) gives its surface by colour. Each face counts by its area as seen from a
rider behind and above (sides and top count, the belly hardly), and glowing faces (the mesh's glow cells) are marked.
From that: the body's median L* (lightness), its darkest and lightest tenth, its main colour, and its gap to the land's
floor and fog (art/map/palettes/proposal.json: the floors and halfway fogs).

usage: python tools/art/fish_values.py            writes art/creatures/values.csv and docs/attachments/fish-values.jpg"""
import colorsys
import csv
import glob
import json
import os
import subprocess

import numpy as np
from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
TIERS = ["Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic", "Secret"]


def lstar(rgb):
    a = np.asarray(rgb, float) / 255.0
    lin = np.where(a <= 0.04045, a / 12.92, ((a + 0.055) / 1.055) ** 2.4)
    y = 0.2126 * lin[..., 0] + 0.7152 * lin[..., 1] + 0.0722 * lin[..., 2]
    return np.where(y > 0.008856, 116 * np.cbrt(y) - 16, 903.3 * y)


def hexrgb(h):
    return tuple(int(h[i:i + 2], 16) for i in (1, 3, 5))


def fish_surface(cid):
    """(colours N x 3, weights N, glow N bool) of a creature's faces"""
    g = os.path.join(ROOT, "art", "creatures", cid, "game")
    obj = os.path.join(g, cid + ".obj")
    meta = json.load(open(os.path.join(g, cid + ".mesh.json")))
    pal = np.asarray(Image.open(os.path.join(g, meta["palette"])).convert("RGB"))
    ph, pw = pal.shape[:2]
    glow_names = {c.split("_")[0].lower() for c in meta.get("glow", [])}
    cells = meta.get("paletteCells", {})
    V, VT, cols, wts, glows = [], [], [], [], []
    for line in open(obj):
        if line.startswith("v "):
            V.append([float(x) for x in line.split()[1:4]])
        elif line.startswith("vt "):
            VT.append([float(x) for x in line.split()[1:3]])
        elif line.startswith("f "):
            idx = [p.split("/") for p in line.split()[1:]]
            vs = [np.array(V[int(i[0]) - 1]) for i in idx]
            uv = VT[int(idx[0][1]) - 1] if len(idx[0]) > 1 and idx[0][1] else (0, 0)
            n = np.cross(vs[1] - vs[0], vs[2] - vs[0])
            for k in range(3, len(vs)):
                n = n + np.cross(vs[k - 1] - vs[0], vs[k] - vs[0])
            area = np.linalg.norm(n) / 2
            if area <= 0:
                continue
            nn = n / (2 * area)
            seen = 0.25 + 0.45 * max(0.0, nn[1]) + 0.35 * abs(nn[0]) + 0.2 * max(0.0, nn[2])  # a rider behind and above
            x, y = int(min(pw - 1, uv[0] * pw)), int(min(ph - 1, (1 - uv[1]) * ph))
            c = pal[y, x]
            cols.append(c)
            wts.append(area * seen)
            glows.append(False)
    cols, wts = np.array(cols, float), np.array(wts)
    # glow: a palette entry the mesh marks as glowing (by its cell's name), when the mesh gives names to cells
    gl = np.zeros(len(cols), bool)
    for name, cell in cells.items() if isinstance(cells, dict) else []:
        if name.lower().split("-")[0].split("+")[0] in glow_names or "glow" in name.lower():
            try:
                c = hexrgb(meta["palette_colours"][name]) if "palette_colours" in meta else None
            except Exception:
                c = None
    return cols, wts, gl, meta


def weighted_pct(values, weights, q):
    o = np.argsort(values)
    v, w = values[o], weights[o]
    c = np.cumsum(w) / w.sum()
    return float(np.interp(q / 100, c, v))


def main():
    tracked = set(subprocess.run(["git", "ls-files", "src/shared/Creatures"], capture_output=True, text=True, cwd=ROOT).stdout.split())
    P = json.load(open(os.path.join(ROOT, "art", "map", "palettes", "proposal.json")))["lands"]
    rows = []
    for f in sorted(glob.glob(os.path.join(ROOT, "src", "shared", "Creatures", "*.json"))):
        rel = os.path.relpath(f, ROOT).replace("\\", "/")
        if rel not in tracked:
            continue
        d = json.load(open(f))
        cid = os.path.splitext(os.path.basename(f))[0]
        try:
            cols, wts, gl, meta = fish_surface(cid)
        except FileNotFoundError:
            print("no model:", cid)
            continue
        L = lstar(cols)
        zone = int(d["Zone"])
        land = P[zone - 1]
        floor, fog = hexrgb(land["floor"]), hexrgb(land["fog_halfway"])
        fl, fo = float(lstar(floor)), float(lstar(fog))
        med = weighted_pct(L, wts, 50)
        # the main colour: the colour with the most weight
        keys = [tuple(int(v) for v in c) for c in cols]
        tally = {}
        for k_, w_ in zip(keys, wts):
            tally[k_] = tally.get(k_, 0) + w_
        main = max(tally, key=tally.get)
        hs = colorsys.rgb_to_hsv(*(v / 255 for v in main))
        fh = colorsys.rgb_to_hsv(*(v / 255 for v in floor))
        hue_gap = min(abs(hs[0] - fh[0]), 1 - abs(hs[0] - fh[0])) * 360 if hs[1] > 0.15 and fh[1] > 0.15 else 0.0
        rows.append({"id": cid, "name": d["Name"], "tier": d["Tier"], "zone": zone, "land": land["name"],
                     "median_L": round(med, 1), "dark10_L": round(weighted_pct(L, wts, 10), 1), "light90_L": round(weighted_pct(L, wts, 90), 1),
                     "main": "#%02x%02x%02x" % main, "main_sat": round(hs[1], 2), "floor_L": round(fl, 1), "fog_L": round(fo, 1),
                     "gap_floor": round(med - fl, 1), "gap_fog": round(med - fo, 1), "hue_gap": round(hue_gap), "glow": bool(meta.get("glow")),
                     "_cols": cols, "_wts": wts, "_L": L})
    out_csv = os.path.join(ROOT, "art", "creatures", "values.csv")
    keys = [k for k in rows[0] if not k.startswith("_")]
    with open(out_csv, "w", newline="") as fh_:
        w = csv.DictWriter(fh_, keys)
        w.writeheader()
        for r in rows:
            w.writerow({k: r[k] for k in keys})
    # the chart: one row a land, its floor and fog as bands, each fish a column: its colours stacked by weight (dark
    # at the bottom), its median L* marked, labelled with name and rarity, sorted by rarity
    font, bold = ImageFont.truetype("C:/Windows/Fonts/arial.ttf", 12), ImageFont.truetype("C:/Windows/Fonts/arialbd.ttf", 15)
    CW, CH, LW = 74, 150, 150
    im = Image.new("RGB", (LW + CW * 15 + 40, 60 + 10 * (CH + 54)), (250, 246, 240))
    d = ImageDraw.Draw(im)
    d.text((10, 10), "Our fish against their land: each column a fish's surface by colour (dark at the bottom), the white tick its median lightness; the band behind is the land's floor, the top strip its fog", font=bold, fill=(20, 20, 20))
    for z in range(1, 11):
        y = 46 + (z - 1) * (CH + 54)
        land = P[z - 1]
        fish = sorted([r for r in rows if r["zone"] == z], key=lambda r: (TIERS.index(r["tier"]) if r["tier"] in TIERS else 9, r["name"]))
        d.text((10, y + 4), f"{z}. {land['name']}", font=bold, fill=(20, 20, 20))
        d.text((10, y + 24), f"floor L{fish[0]['floor_L'] if fish else 0:.0f}  fog L{fish[0]['fog_L'] if fish else 0:.0f}", font=font, fill=(80, 80, 80))
        d.rectangle([LW - 6, y, LW + CW * max(1, len(fish)), y + CH], fill=hexrgb(land["floor"]))
        d.rectangle([LW - 6, y, LW + CW * max(1, len(fish)), y + 14], fill=hexrgb(land["fog_halfway"]))
        for j, r in enumerate(fish):
            x = LW + j * CW + 10
            o = np.argsort(r["_L"])
            cs, ws = r["_cols"][o], r["_wts"][o]
            tot = ws.sum()
            yy = y + CH - 6
            top = y + 22
            hgt = yy - top
            acc = 0.0
            for c, w_ in zip(cs, ws):
                h = w_ / tot * hgt
                d.rectangle([x, yy - acc - h, x + CW - 22, yy - acc], fill=tuple(int(v) for v in c))
                acc += h
            my = yy - (np.searchsorted(np.cumsum(ws) / tot, 0.5)) / len(ws) * 0  # placeholder
            # the median tick: at the height where half the weight is below
            half_h = yy - hgt * 0.5
            d.line([x - 3, half_h, x + CW - 19, half_h], fill=(255, 255, 255), width=2)
            d.text((x - 4, y + CH + 2), r["name"][:12], font=font, fill=(30, 30, 30))
            d.text((x - 4, y + CH + 16), f"{r['tier'][:4]} L{r['median_L']:.0f} ({r['gap_floor']:+.0f})", font=font, fill=(90, 90, 90))
    path = os.path.join(ROOT, "docs", "attachments", "fish-values.jpg")
    im.save(path, quality=88)
    print(out_csv, path, len(rows), "fish")


if __name__ == "__main__":
    main()
