#!/usr/bin/env python3
"""The smaller auras (Config.Aura.Small: A, B, C) beside today's: how much of the rider and of the screen each covers, the
sheet and the moving version. The same mock as volume_shots.py, not a Studio capture.

    for i in 0 1 2 3: lune run tools/auras/volume_dump.luau /tmp/place.rbxl W/d$i.json 4,4.37,... $i
    blender -b --python tools/auras/volume_scene.py -- W/shots <repo> W/d0.json
    python tools/auras/volume_small.py measure W W/measure.json
    python tools/auras/volume_small.py sheet W W/measure.json out.png
    python tools/auras/volume_small.py frames W outdir          (d0..d3 dumped at the film's times; then ffmpeg)
"""
import json
import os
import sys
from concurrent.futures import ProcessPoolExecutor

import numpy as np
from PIL import Image, ImageDraw

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from volume_shots import font, render  # noqa: E402

TIERS = (1, 6, 12)
FISH = (("Clownfish", "small fish"), ("Livyatan", "big fish"))
NAMES = {0: "Before", 1: "A small", 2: "B smaller", 3: "C tiniest"}
TIER = {1: "Bubble", 6: "Storm", 12: "Leviathan"}
ANY, SOLID = 0.08, 0.5  # any of it on a pixel; enough to hide what is behind


def load(work, i):
    return {s["Name"]: s for s in json.load(open(f"{work}/d{i}.json"))}


def one(args):
    work, scene, view, frame, scale = args
    V = render(f"{work}/shots", scene, view, scale, frame)
    m, c = V.masks, V.cover
    out = {"any": float((c >= ANY).mean()), "solid": float((c >= SOLID).mean())}
    for k in m:
        n = max(int(m[k].sum()), 1)
        out[k + "_any"] = float(((c >= ANY) & m[k]).sum() / n)
        out[k + "_solid"] = float(((c >= SOLID) & m[k]).sum() / n)
        out[k + "_mean"] = float(c[m[k]].sum() / n)
    return out


def measure(work, out):
    jobs, keys = [], []
    for i in range(4):
        scenes = load(work, i)
        for tier in TIERS:
            for fish, _ in FISH:
                for how in ("own", "other"):
                    s = scenes[f"{fish}{tier}" + ("own" if how == "own" else "")]
                    for f in range(len(s["Frames"])):
                        jobs.append((work, s, f"{fish}_{how}", f, 0.5))
                        keys.append(f"{i} {fish} {tier} {how}")
            s = scenes[f"foot{tier}"]
            for f in range(len(s["Frames"])):
                jobs.append((work, s, "foot_front", f, 0.5))
                keys.append(f"{i} foot {tier} front")
    table = {}
    with ProcessPoolExecutor(11) as ex:
        for k, r in zip(keys, ex.map(one, jobs, chunksize=4)):
            table.setdefault(k, []).append(r)
    table = {k: {n: float(np.mean([r[n] for r in v])) for n in v[0]} | {
        "wearer_solid_worst": max(r["wearer_solid"] for r in v)} for k, v in table.items()}
    json.dump(table, open(out, "w"), indent=1)
    for k, v in table.items():
        print(f"{k:28}", "  ".join(f"{n} {100 * x:6.2f}" for n, x in v.items()))


def cell(args):
    """One picture: a scene in a view, a box of it (in the view's own pixels), as big as asked."""
    work, scene, view, box, w, h, frame, scale = args
    V = render(f"{work}/shots", scene, view, scale, frame)
    im = Image.fromarray((np.clip(V.img, 0, 1) * 255).astype(np.uint8))
    return im.crop([int(v * scale) for v in box]).resize((w, h), Image.LANCZOS)


def pct(x):
    x *= 100
    return "0%" if x < 0.005 else f"{x:.2f}%" if x < 1 else f"{x:.0f}%" if x >= 10 else f"{x:.1f}%"


FULL = (0, 0, 1280, 720)
NEAR = (400, 130, 880, 400)  # a 16:9 piece of it round the rider


def sheet(work, table, out):
    m = json.load(open(table))
    rows = [("standing", "foot", "foot_front", (0, 170, 560, 485 + 170)), ("riding a small fish, your own camera", "Clownfish", "own", FULL),
            ("riding a big fish, your own camera", "Livyatan", "own", FULL),
            ("small fish, another player's view (close up)", "Clownfish", "other", NEAR),
            ("big fish, another player's view (close up)", "Livyatan", "other", NEAR)]
    w, h, gap, top, bar, head = 480, 270, 6, 170, 46, 40
    th = {"foot": 416}
    tall = sum(th.get(r[1], h) + bar for r in rows) + head
    W, H = 4 * w + 3 * gap, top + 3 * tall
    S = Image.new("RGB", (W, H), (12, 16, 26))
    d = ImageDraw.Draw(S)
    d.text((14, 10), "Auras, smaller and less apparent: pick A, B or C", font=font(34), fill=(255, 255, 255))
    d.text((14, 56), "An offline mock from the game's own numbers, not a Studio capture. Under each picture: how much of the player's body is",
           font=font(19), fill=(200, 210, 225))
    d.text((14, 80), "hidden (half covered or more), and how much of the whole screen has any aura on it. Mean of 12 moments.", font=font(19),
           fill=(200, 210, 225))
    for i in range(4):
        d.text((i * (w + gap) + 14, 118), NAMES[i], font=font(32), fill=(255, 222, 120) if i else (255, 150, 140))
    jobs, where = [], []
    y = top
    for tier in TIERS:
        d.text((14, y + 4), f"Tier {tier}, {TIER[tier]}", font=font(26), fill=(160, 220, 255))
        y += head
        for text, what, view, box in rows:
            ch = th.get(what, h)
            for i in range(4):
                x = i * (w + gap)
                scene = f"foot{tier}" if what == "foot" else f"{what}{tier}" + ("own" if view == "own" else "")
                jobs.append((work, SC[i][scene], view if what == "foot" else f"{what}_{view}", box, w, ch, 3, 1.5 if box != NEAR else 2))
                where.append((x, y))
                k = m[f"{i} {what} {tier} " + ("front" if what == "foot" else view)]
                d.text((x + 8, y + ch + 2), text, font=font(15), fill=(170, 182, 200))
                d.text((x + 8, y + ch + 20), f"player hidden {pct(k['wearer_solid'])}   {'picture' if what == 'foot' else 'screen'} {pct(k['any'])}", font=font(18), fill=(255, 255, 255))
            y += ch + bar
    with ProcessPoolExecutor(11) as ex:
        for im, at in zip(ex.map(cell, jobs), where):
            S.paste(im, at)
    S.save(out, optimize=True)


def frames(work, out):
    """The film: A, B and C side by side, riding."""
    os.makedirs(out, exist_ok=True)
    rows = [("Livyatan", 1, "own"), ("Livyatan", 6, "own"), ("Livyatan", 12, "own"), ("Clownfish", 12, "other")]
    w, h, top = 426, 240, 44
    box = (320, 90, 960, 450)
    n = len(SC[1]["foot1"]["Frames"])
    jobs = [(work, SC[i][f"{f}{t}" + ("own" if v == "own" else "")], f"{f}_{v}", box if v == "own" else NEAR, w, h, k, 1.0)
            for k in range(n) for f, t, v in rows for i in (1, 2, 3)]
    with ProcessPoolExecutor(11) as ex:
        made = ex.map(cell, jobs, chunksize=6)
        for k in range(n):
            S = Image.new("RGB", (w * 3, top + h * 4), (12, 16, 26))
            d = ImageDraw.Draw(S)
            for i in (1, 2, 3):
                d.text(((i - 1) * w + 12, 8), NAMES[i], font=font(24), fill=(255, 222, 120))
            for r, (f, t, v) in enumerate(rows):
                for i in range(3):
                    S.paste(next(made), (i * w, top + r * h))
                    d.text((i * w + 10, top + r * h + 8), f"tier {t}, " + ("your own camera" if v == "own" else "another player's view"),
                           font=font(15), fill=(255, 255, 255), stroke_width=2, stroke_fill=(0, 0, 0))
            S.save(f"{out}/{k:03d}.png")


SC = {}


def main():
    how, work = sys.argv[1:3]
    if how == "measure":
        measure(work, sys.argv[3])
        return
    for i in range(4):
        SC[i] = load(work, i)
    if how == "sheet":
        sheet(work, sys.argv[3], sys.argv[4])
    else:
        frames(work, sys.argv[3])


if __name__ == "__main__":
    main()
