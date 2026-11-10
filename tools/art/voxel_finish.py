"""Finish a voxel creature: the gate, the close views, the swim, its sheet and its swim GIF.
usage: python tools/art/voxel_finish.py <Name> ["one line under the first picture"]
Writes docs/attachments/voxel-<name>.jpg and voxel-<name>-swim.gif. Run voxel_preview.py <Name> first (it makes the main views)."""
import glob
import os
import re
import subprocess
import sys

from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageFont

from voxel_paths import BLENDER as B, ROOT as R, WORK as S, font as face

A = R + "docs/attachments/"
BG = (254, 248, 241)
name = sys.argv[1]
note = sys.argv[2] if len(sys.argv) > 2 else ""
model, out = R + f"art/creatures/{name}/voxel.py", f"{S}hand/{name}"


def run(*flags, where=out):
    r = subprocess.run([B, "--background", "--python", R + "tools/blender/voxel_kit.py", "--", model, where, *flags], capture_output=True, text=True)
    return r.stdout + r.stderr


log = run("--check", where=f"{S}check_{name}")
faults = [ln for ln in log.splitlines() if ln.startswith("  !") or "Traceback" in ln or "Error" in ln]
facts = re.search(r"voxel kit: .*?: (\d+) parts, \d+ cubes of ([\d.]+) studs, (\d+) triangles, ([\d.]+) x ([\d.]+) x ([\d.]+) studs", log)
if faults or not facts:
    print("\n".join(faults[:20]) or log[-1500:])
    sys.exit("finish: the gate did not pass; nothing written")
parts, cube, tris, lx, ly, lz = facts.groups()
run("--inspect")
run("--swim")
big = face("ariblk.ttf", 30)
font = face("arialbd.ttf", 22)
small = face("arial.ttf", 18)


def flat(p, crop=True):
    im = Image.open(p).convert("RGBA")
    if crop:
        im = im.crop(im.getbbox())
    b = Image.new("RGBA", im.size, BG + (255,))
    b.alpha_composite(im)
    return b.convert("RGB")


def bloom(im, radius=9, amount=0.38):
    r, g, b = im.split()
    hot = ImageChops.multiply(ImageChops.multiply(r.point(lambda v: 255 if v > 205 else 0), b.point(lambda v: 255 if v < 115 else 0)),
                              g.point(lambda v: 255 if 80 < v < 200 else 0))
    cold = ImageChops.multiply(ImageChops.multiply(b.point(lambda v: 255 if v > 180 else 0), r.point(lambda v: 255 if v < 150 else 0)),
                               g.point(lambda v: 255 if v > 200 else 0))
    glow = Image.composite(im, Image.new("RGB", im.size, (0, 0, 0)), ImageChops.lighter(hot, cold)).filter(ImageFilter.GaussianBlur(radius))
    return ImageChops.screen(im, glow.point(lambda v: min(255, int(v * amount * 2.2))))


def cell(im, w, h, label, text=""):
    c = Image.new("RGB", (w, h), BG)
    k = min((w - 30) / im.width, (h - 84) / im.height)
    im = im.resize((int(im.width * k), int(im.height * k)), Image.LANCZOS)
    c.paste(im, ((w - im.width) // 2, 50 + (h - 84 - im.height) // 2))
    d = ImageDraw.Draw(c)
    d.text((14, 10), label, font=font, fill=(40, 40, 40))
    if text:
        d.text((14, h - 30), text, font=small, fill=(110, 100, 90))
    return c


spec = open(model, encoding="utf-8").read()
glows = "GLOW" in spec
look = bloom if glows else (lambda im: im)
rarity = re.search(r'NAME, ZONE, RARITY = "([^"]*)", "([^"]*)", "([^"]*)"', spec)
title = f"{rarity.group(1)}  /  {rarity.group(2).title()}  /  {rarity.group(3).title()}" if rarity else name
W, H = 900, 480
rows = [[cell(look(flat(out + "/hero.png")), W, H, "Three-quarter", note), cell(look(flat(out + "/side.png")), W, H, "Side", f"{lx} studs long, {lz} tall, {ly} across")],
        [cell(look(flat(out + "/front.png")), W, H, "Front"), cell(look(flat(out + "/top.png")), W, H, "Top")],
        [cell(look(flat(out + "/inspect/head_side.png")), W, H, "The head"), cell(look(flat(out + "/inspect/under.png")), W, H, "Underneath")]]
sheet = Image.new("RGB", (2 * (W + 10) + 10, 3 * (H + 10) + 64), (255, 255, 255))
ImageDraw.Draw(sheet).text((14, 12), f"{title}  /  {int(tris):,} triangles, {parts} parts", font=big, fill=(40, 40, 40))
for j, row in enumerate(rows):
    for i, c in enumerate(row):
        sheet.paste(c, (10 + i * (W + 10), 60 + j * (H + 10)))
low = name.lower()
sheet.save(f"{A}voxel-{low}.jpg", quality=90)
frames = []
for p in sorted(glob.glob(out + "/swim_voxel/hero_*.png")):
    f = flat(p, crop=False)
    frames.append(f.resize((640, int(f.height * 640 / f.width)), Image.LANCZOS).quantize(96))
if frames:
    frames[0].save(f"{A}voxel-{low}-swim.gif", save_all=True, append_images=frames[1:], duration=70, loop=0)
    strip = Image.new("RGB", (640 * 3, frames[0].height), BG)
    for i, k in enumerate((0, 8, 16)):
        strip.paste(frames[min(k, len(frames) - 1)].convert("RGB"), (640 * i, 0))
    strip.save(f"{S}{name}_swim_strip.png")
print(f"finish: {name}: {parts} parts, cube {cube}, {tris} triangles, {lx} x {ly} x {lz} studs; sheet and swim written; check {S}{name}_swim_strip.png")
