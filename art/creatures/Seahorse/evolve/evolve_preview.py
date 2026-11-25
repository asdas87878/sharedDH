"""Builds evolved rockers (T01 to T12 beside this file), checks them and lays out a picture.

usage: python art/creatures/Seahorse/evolve/evolve_preview.py 7 [8 9 ...]   one sheet to a level: work/voxel/evolve/T07_preview.png
       ... --check     the kit's gate and the numbers only (no renders)
       ... --rock      docs/attachments/seahorse-rocker-<n>.gif, the rock
       ... --line      the line-up of all the levels rendered so far, at one scale: docs/attachments/seahorse-evolution.jpg
"""
import json
import os
import re
import runpy
import subprocess
import sys

from PIL import Image, ImageChops, ImageDraw, ImageFilter

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(HERE))))
sys.path.insert(0, os.path.join(ROOT, "tools", "art"))
sys.path.insert(0, HERE)
import common  # noqa: E402
from voxel_paths import BLENDER, WORK, font  # noqa: E402

KIT = os.path.join(ROOT, "tools", "blender", "voxel_kit.py")
VIEWS = os.path.join(HERE, "evolve_views.py")
OUT = os.path.join(WORK, "evolve")
ATT = os.path.join(ROOT, "docs", "attachments")
BG = (254, 248, 241)
os.makedirs(OUT, exist_ok=True)


def flat(path, size=None, bg=BG):
    im = Image.open(path).convert("RGBA")
    b = Image.new("RGBA", im.size, bg + (255,))
    b.alpha_composite(im)
    b = b.convert("RGB")
    return b.resize(size, Image.LANCZOS) if size else b


def blender(script, level, *extra):
    model, out = os.path.join(HERE, f"T{level:02d}", "voxel.py"), os.path.join(OUT, f"T{level:02d}")
    run = subprocess.run([BLENDER, "--background", "--python", script, "--", model, out, *extra], capture_output=True, text=True)
    keep = [ln for ln in (run.stdout + run.stderr).splitlines()
            if any(w in ln for w in ("Error", "Traceback", "voxel kit", 'line ')) or ln.startswith("  !")]
    return out, keep


def numbers(level, lines):
    """what the kit measured against what was asked"""
    s = common.SIZES[level]
    found = next((re.search(r"(\d+) triangles, ([\d.]+) x ([\d.]+) x ([\d.]+) studs", ln) for ln in lines if "cubes of" in ln), None)
    if not found:
        return "no build"
    k = 1 / common.U
    tri, l, w, h = int(found[1]), *(float(found[i]) * k for i in (2, 3, 4))
    coil = 480  # the draft coil's triangles
    return (f"level {level}: {tri - coil} triangles of {s['tris']} (the draft coil not counted); "
            f"{l:.0f} long, {w:.0f} wide, {h:.0f} tall cubes with the stand; asked {s['size'][0]}, {s['size'][1]}, {s['size'][2]}; "
            f"in the game {l * .34:.1f} x {w * .34:.1f} x {h * .34:.1f} studs")


def sheet(level):
    out, lines = blender(VIEWS, level, "--hero")
    print("\n".join(lines[-30:]))
    print(numbers(level, lines))
    if any(ln.startswith("  !") or "Error" in ln for ln in lines):
        return False
    v = lambda n, size: flat(os.path.join(out, n + ".png"), size)  # noqa: E731
    im = Image.new("RGB", (1640, 1300), (255, 255, 255))
    im.paste(v("hero", (880, 720)), (0, 0))
    im.paste(v("side", (740, 608)), (900, 0))
    im.paste(v("rear", (680, 559)), (0, 730))
    im.paste(v("front", (440, 440)), (690, 730))
    if os.path.exists(os.path.join(out, "face.png")):
        im.paste(v("face", (480, 389)), (1150, 620))
    im.paste(v("top", (480, 299)), (1150, 1000))
    d = ImageDraw.Draw(im)
    d.text((14, 10), f"{level}  {common.NAMES[level].upper()}", fill=(30, 34, 46), font=font("arialbd.ttf", 30))
    path = os.path.join(OUT, f"T{level:02d}_preview.png")
    im.save(path)
    print("preview", path)
    return True


def rock(level):
    out, lines = blender(VIEWS, level, "--swim")
    folder = os.path.join(out, "rock")
    frames = []
    for f in range(24):
        a, b = flat(os.path.join(folder, f"hero_{f:03d}.png")), flat(os.path.join(folder, f"front_{f:03d}.png"))
        im = Image.new("RGB", (a.width + b.width, a.height), BG)
        im.paste(a, (0, 0))
        im.paste(b, (a.width, 0))
        frames.append(im.quantize(96))
    path = os.path.join(ATT, f"seahorse-rocker-{level}.gif")
    frames[0].save(path, save_all=True, append_images=frames[1:], duration=50, loop=0)
    print("rock", path)


def glows(level, im):
    """(the picture with the game's Neon bloom drawn in, the share of the model that glows); the bloom is build_tiers.py's"""
    model = runpy.run_path(os.path.join(HERE, f"T{level:02d}", "voxel.py"))
    hexes = [model["PALETTE"][n] for n in model.get("GLOW", {}) if n in model["PALETTE"] and not n.startswith("s_")]
    if model.get("VARIANT") and hexes:
        hexes = [model["ACCENT"]]
    back = Image.new("RGBA", im.size, BG + (255,))
    back.alpha_composite(im)
    rgb, alpha = back.convert("RGB"), im.split()[3].point(lambda v: 255 if v > 200 else 0)
    if not hexes:
        return rgb, 0.0
    mask = Image.new("L", im.size, 0)
    for hx in hexes:
        c = tuple(int(hx[i:i + 2], 16) for i in (1, 3, 5))
        diff = ImageChops.difference(rgb, Image.new("RGB", im.size, c)).convert("L")
        mask = ImageChops.lighter(mask, diff.point(lambda v: 255 if v < 12 else 0))
    mask = ImageChops.multiply(mask, alpha)
    lit = Image.composite(rgb, Image.new("RGB", im.size, (0, 0, 0)), mask).filter(ImageFilter.GaussianBlur(10))
    lit = lit.point(lambda v: min(255, int(v * 1.1)))
    return ImageChops.screen(rgb, lit), mask.histogram()[255] / max(1, alpha.histogram()[255])


def line():
    """every level at one scale, two rows"""
    got = {n: os.path.join(OUT, f"T{n:02d}", "line.png") for n in range(1, 13)}
    got = {n: Image.open(p).convert("RGBA") for n, p in got.items() if os.path.exists(p)}
    got = {n: im.crop(im.getbbox()) for n, im in got.items()}
    lit = {n: glows(n, im) for n, im in got.items()}
    print("glow share of each picture:", ", ".join(f"{n}: {v[1]:.0%}" for n, v in lit.items()))
    got = {n: v[0] for n, v in lit.items()}
    rows = [[n for n in (1, 2, 3, 4, 5, 6, 7, 8) if n in got], [n for n in (9, 10, 11, 12) if n in got]]
    gap, head = 26, 46
    widths = [sum(got[n].width + gap for n in row) + gap for row in rows if row]
    talls = [max(got[n].height for n in row) + head + 24 for row in rows if row]
    im = Image.new("RGB", (max(widths), sum(talls)), BG)
    d = ImageDraw.Draw(im)
    y = 0
    for row, wide, tall in zip([r for r in rows if r], widths, talls):
        x = gap + (im.width - wide) // 2
        for n in row:
            g = got[n]
            im.paste(g, (x, y + tall - head - g.height))
            d.text((x + g.width // 2, y + tall - head + 22), f"{n}  {common.NAMES[n]}", fill=(30, 34, 46),
                   font=font("arialbd.ttf", 26), anchor="mm")
            x += g.width + gap
        y += tall
    path = os.path.join(OUT if "--draft" in sys.argv else ATT, "seahorse-evolution.jpg")
    if im.width > 2600:
        im = im.resize((2600, im.height * 2600 // im.width), Image.LANCZOS)
    im.save(path, quality=90)
    print("line", path, im.size)


args = sys.argv[1:]
levels = [int(a) for a in args if a.isdigit()]
bad = 0
for n in levels:
    if "--check" in args:
        _, got_lines = blender(KIT, n, "--check")
        print("\n".join(got_lines[-30:]))
        print(numbers(n, got_lines))
        bad += any(ln.startswith("  !") or "Error" in ln for ln in got_lines)
    elif "--rock" in args:
        rock(n)
    else:
        bad += not sheet(n)
if "--line" in args:
    line()
sys.exit(1 if bad else 0)
