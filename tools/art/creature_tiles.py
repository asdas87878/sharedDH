"""Cartoon surface tiles for the voxel creatures (docs/style/06-textures.md), drawn by code: no image generator.
usage: python tools/art/creature_tiles.py            (writes art/style/tiles/<name>.png and a contact sheet)

Each tile is a square grey picture that repeats. Mid grey (128) leaves a creature's colour as it is; lighter grey lifts
it, darker grey shades it. So one tile works on any colour, and the colours stay in the model. The shapes are flat and
hard-edged, in three or four tones (a face, a lit edge, a drop shadow), like a cartoon, not like a photo.
One tile covers one cube unless a model says otherwise."""
import math
import os
import random

import numpy as np
from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT = os.path.join(ROOT, "art", "style", "tiles")
N, SS = 128, 4  # a tile's size in pixels, and how much bigger it is drawn before being shrunk (for smooth edges)
S = N * SS
MID, FACE, LIT, SHADOW, GROOVE = 128, 154, 186, 80, 92
SHIFTS = [(dx, dy) for dx in (-1, 0, 1) for dy in (-1, 0, 1)]  # shapes are drawn nine times so they wrap round the edges


def new(value=MID):
    im = Image.new("L", (S, S), value)
    return im, ImageDraw.Draw(im)


def px(v):
    return v * S


def disc(d, cx, cy, r, value):
    for dx, dy in SHIFTS:
        d.ellipse([px(cx + dx - r), px(cy + dy - r), px(cx + dx + r), px(cy + dy + r)], fill=value)


def rrect(d, x0, y0, x1, y1, r, value):
    for dx, dy in SHIFTS:
        d.rounded_rectangle([px(x0 + dx), px(y0 + dy), px(x1 + dx), px(y1 + dy)], radius=px(r), fill=value)


def done(im):
    return im.resize((N, N), Image.LANCZOS)


def stud():
    """a round stud, like a toy brick's: a drop shadow down and to the right, a face, a lit crescent up and to the left"""
    im, d = new()
    disc(d, 0.54, 0.555, 0.31, SHADOW)
    disc(d, 0.5, 0.5, 0.31, FACE)
    disc(d, 0.47, 0.465, 0.22, LIT)
    disc(d, 0.5, 0.5, 0.2, FACE)
    return done(im)


def stud_square():
    """a square stud with rounded corners"""
    im, d = new()
    rrect(d, 0.235, 0.25, 0.845, 0.86, 0.11, SHADOW)
    rrect(d, 0.2, 0.2, 0.8, 0.8, 0.11, FACE)
    rrect(d, 0.24, 0.24, 0.7, 0.7, 0.08, LIT)
    rrect(d, 0.29, 0.29, 0.75, 0.75, 0.08, FACE)
    return done(im)


def plate():
    """a rounded plate that nearly fills the cube: armour, a scute. The gaps between plates are the dark part"""
    im, d = new(GROOVE)
    rrect(d, 0.06, 0.06, 0.94, 0.94, 0.16, 142)
    rrect(d, 0.1, 0.1, 0.84, 0.84, 0.13, 164)
    rrect(d, 0.15, 0.15, 0.9, 0.9, 0.13, 142)
    return done(im)


def scale():
    """fish scales: two rows of rounded scales to the cube, each row lapping over the one before"""
    im, d = new(MID)
    for row, y in enumerate((-0.5, 0.0, 0.5, 1.0)):
        for x in (-0.5, 0.0, 0.5, 1.0, 1.5):
            cx = x + (0.25 if row % 2 else 0.0)
            d.ellipse([px(cx - 0.27), px(y - 0.1), px(cx + 0.27), px(y + 0.5)], fill=GROOVE)
            d.ellipse([px(cx - 0.24), px(y - 0.14), px(cx + 0.24), px(y + 0.44)], fill=140)
            d.ellipse([px(cx - 0.2), px(y - 0.14), px(cx + 0.2), px(y + 0.33)], fill=132)
    return done(im)


def pleat():
    """two rounded ridges to the cube, running along the body: a whale's throat, a fin's rays"""
    im, d = new(GROOVE)
    for y in (0.0, 0.5, 1.0):
        d.rectangle([0, px(y - 0.19), S, px(y + 0.19)], fill=142)
        d.rectangle([0, px(y - 0.19), S, px(y - 0.1)], fill=166)
    return done(im)


def rivet():
    """a plain panel with a seam on two sides and a rivet in each corner: plate armour"""
    im, d = new(MID)
    d.rectangle([0, 0, S, px(0.045)], fill=GROOVE)
    d.rectangle([0, 0, px(0.045), S], fill=GROOVE)
    d.rectangle([0, px(0.045), S, px(0.085)], fill=160)
    d.rectangle([px(0.045), 0, px(0.085), S], fill=160)
    for cx, cy in ((0.22, 0.22), (0.86, 0.22), (0.22, 0.86), (0.86, 0.86)):
        disc(d, cx + 0.018, cy + 0.022, 0.07, SHADOW)
        disc(d, cx, cy, 0.07, LIT)
    return done(im)


def cells(points, stretch=1.0, line=0.035, face=140, edge=GROOVE):
    """a tile of cells round the given points (it wraps): each pixel belongs to its nearest point, and the borders between
    cells are drawn dark"""
    ys, xs = np.mgrid[0:S, 0:S] / S
    best = np.full((S, S), 9.0)
    second = np.full((S, S), 9.0)
    for x, y in points:
        for dx, dy in SHIFTS:
            dist = np.hypot(xs - x - dx, (ys - y - dy) * stretch)
            second = np.where(dist < best, best, np.minimum(second, dist))
            best = np.minimum(best, dist)
    return Image.fromarray(np.where(second - best < line, edge, face).astype(np.uint8))


def scute():
    """six-sided scutes, two rows to the cube: a turtle's shell, a boxfish"""
    return done(cells([(0.0, 0.0), (0.5, 0.5)], stretch=1 / math.sqrt(3), line=0.05))


def crackle():
    """cracks in a dried or burnt surface: lava crust, old stone, mud"""
    rnd = random.Random(7)
    return done(cells([(rnd.random(), rnd.random()) for _ in range(7)], line=0.03, face=MID, edge=70))


def spots():
    """soft round spots of different sizes, a little lighter: a whale shark, a ray"""
    rnd = random.Random(3)
    im, d = new(MID)
    for _ in range(9):
        disc(d, rnd.random(), rnd.random(), rnd.uniform(0.05, 0.12), 172)
    return done(im)


def brick():
    """bricks in two courses: stone and ruin creatures"""
    im, d = new(GROOVE)
    for row, y in enumerate((0.0, 0.5)):
        for x in (-0.5, 0.5):
            x0 = x + (0.5 if row else 0.0)
            for dx in (-1, 0, 1):
                d.rectangle([px(x0 + dx + 0.03), px(y + 0.03), px(x0 + dx + 0.97), px(y + 0.47)], fill=140)
                d.rectangle([px(x0 + dx + 0.03), px(y + 0.03), px(x0 + dx + 0.97), px(y + 0.1)], fill=162)
    return done(im)


def bubble():
    """rings with a glint: jelly, soft bodies"""
    rnd = random.Random(11)
    im, d = new(MID)
    for _ in range(5):
        cx, cy, r = rnd.random(), rnd.random(), rnd.uniform(0.08, 0.16)
        disc(d, cx, cy, r, 166)
        disc(d, cx, cy, r - 0.03, MID)
        disc(d, cx - r * 0.35, cy - r * 0.35, r * 0.18, 190)
    return done(im)


def pore():
    """small pits: bone, coral, old shell"""
    rnd = random.Random(5)
    im, d = new(MID)
    for _ in range(14):
        cx, cy, r = rnd.random(), rnd.random(), rnd.uniform(0.018, 0.04)
        disc(d, cx, cy, r, 84)
        disc(d, cx + r * 0.5, cy + r * 0.5, r * 0.7, 150)
        disc(d, cx, cy, r * 0.75, 84)
    return done(im)


def wave():
    """two wavy bands to the cube: water, a current, an eel's skin"""
    ys, xs = np.mgrid[0:S, 0:S] / S
    band = np.sin(2 * math.pi * (2 * ys + 0.12 * np.sin(2 * math.pi * xs)))
    return done(Image.fromarray(np.where(band > 0.45, 160, np.where(band < -0.6, GROOVE + 14, MID)).astype(np.uint8)))


def sparkle():
    """the gold tile: a slanting band of shine and a few four-pointed stars"""
    ys, xs = np.mgrid[0:S, 0:S] / S
    slant = (xs + ys) % 1.0
    im = Image.fromarray(np.where((slant > 0.1) & (slant < 0.24), 168, np.where((slant > 0.3) & (slant < 0.34), 156, MID)).astype(np.uint8))
    d = ImageDraw.Draw(im)
    for cx, cy, r in ((0.7, 0.3, 0.17), (0.25, 0.72, 0.1)):
        for dx, dy in SHIFTS:
            x, y = px(cx + dx), px(cy + dy)
            a, b = px(r), px(r * 0.22)
            d.polygon([(x, y - a), (x + b, y - b), (x + a, y), (x + b, y + b), (x, y + a), (x - b, y + b), (x - a, y), (x - b, y - b)], fill=232)
    return done(im)


def chevron():
    """arrowheads pointing back along the body: speed, a marlin, a rare racer"""
    im, d = new(MID)
    for y in (0.0, 0.5, 1.0):
        for dx in (-1, 0, 1):
            d.line([(px(dx + 0.08), px(y + 0.15)), (px(dx + 0.5), px(y - 0.15)), (px(dx + 0.92), px(y + 0.15))], fill=GROOVE, width=int(px(0.07)), joint="curve")
            d.line([(px(dx + 0.08), px(y + 0.215)), (px(dx + 0.5), px(y - 0.085)), (px(dx + 0.92), px(y + 0.215))], fill=162, width=int(px(0.03)), joint="curve")
    return done(im)


TILES = {"stud": stud, "stud_square": stud_square, "plate": plate, "scale": scale, "pleat": pleat, "rivet": rivet, "scute": scute,
         "crackle": crackle, "spots": spots, "brick": brick, "bubble": bubble, "pore": pore, "wave": wave, "chevron": chevron,
         "sparkle": sparkle}

if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    made = {}
    for name, draw in TILES.items():
        made[name] = draw()
        made[name].save(os.path.join(OUT, name + ".png"))
    # a contact sheet: each tile three by three, on a creature's colour
    font = ImageFont.truetype("C:/Windows/Fonts/arialbd.ttf", 20)
    cols, cell, pad = 5, 300, 16
    rows = (len(made) + cols - 1) // cols
    sheet = Image.new("RGB", (cols * (cell + pad) + pad, rows * (cell + 44 + pad) + pad), (254, 248, 241))
    d = ImageDraw.Draw(sheet)
    colours = ((0x4C, 0x58, 0x6A), (0x1C, 0x82, 0x72), (0x63, 0x23, 0x3A), (0xF5, 0x82, 0x2A), (0x3B, 0x3F, 0x86))
    for k, (name, tile) in enumerate(made.items()):
        base = np.array(colours[k % len(colours)], dtype=float)
        grey = np.tile(np.asarray(tile, dtype=float), (3, 3)) / 255.0
        shade = 1.0 + 1.0 * (grey - 0.5)
        rgb = np.clip(shade[..., None] * base[None, None, :], 0, 255).astype(np.uint8)
        im = Image.fromarray(rgb).resize((cell, cell), Image.LANCZOS)
        x, y = pad + (k % cols) * (cell + pad), pad + (k // cols) * (cell + 44 + pad)
        sheet.paste(im, (x, y))
        d.text((x + 2, y + cell + 8), name, font=font, fill=(40, 40, 40))
    sheet.save(os.path.join(OUT, "_sheet.jpg"), quality=90)
    print("tiles:", ", ".join(made), "->", OUT)
