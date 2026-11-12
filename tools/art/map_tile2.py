"""The map's surface picture, drawn again (docs/design/map-structure.md, "The picture, second drawing"): a see-through
overlay that goes on every part as a Texture, over the part's own colour. Two squares by two; 8 round studs across a
square, so at 16 studs to a tile a stud is one Roblox stud, the classic size.

Why again: the first one (tile.png) lightened the whole surface by about 40% (a white veil: the "washed out" look) and
its two squares were 6% apart. In the reference the squares are 13 to 15% apart and the studs are quiet rings.
Here a square is either left alone or shaded; a stud is a thin dark ring with a small light on its upper left and a
shade on its lower right. Nothing lightens the surface as a whole.

usage: python tools/art/map_tile2.py     writes art/style/map_tiles/roblox/tile2.png and _tile2_preview.jpg
Not uploaded by this script; the id, once uploaded, goes in art/map/textures.json as "tile2"."""
import os

import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT = os.path.join(ROOT, "art", "style", "map_tiles", "roblox")
SIZE, STUDS = 1024, 16  # pixels; studs across the picture
SQUARE = 0.14  # how much darker every other square is
RADIUS = 0.33  # a stud's radius, in studs
RING = 0.2  # the ring's darkness
LIGHT, SHADE = 0.26, 0.2  # the light on a stud's upper left and the shade on its lower right
TOP = 0.05  # how much lighter a stud's top is than the floor round it


def draw():
    px = SIZE / STUDS
    y, x = np.mgrid[0:SIZE, 0:SIZE]
    u, v = (x + 0.5) / px % 1.0 - 0.5, (y + 0.5) / px % 1.0 - 0.5  # place inside a stud's cell, -0.5 to 0.5
    r = np.hypot(u, v)
    soft = 1.2 / px  # a pixel or so of softness at edges
    disc = np.clip((RADIUS - r) / soft, 0, 1)
    ring = np.clip(1 - np.abs(r - RADIUS) / (0.035 + soft), 0, 1)
    # light comes from the upper left: the ring's lower right is in shade, its upper left catches the light
    facing = (-(u + v) / np.maximum(r, 1e-6)) / np.sqrt(2)  # 1 toward the upper left, -1 toward the lower right
    black = np.zeros((SIZE, SIZE))
    white = np.zeros((SIZE, SIZE))
    black += ring * RING * np.clip(0.55 - 0.45 * facing, 0, 1) * 1.6
    black += ring * SHADE * np.clip(-facing, 0, 1)
    white += ring * LIGHT * np.clip(facing, 0, 1)
    white += disc * TOP
    half = SIZE // 2
    dark_square = ((x < half) == (y < half)).astype(float)
    black = 1 - (1 - np.clip(black, 0, 1)) * (1 - SQUARE * dark_square)
    # one layer of white and black with alpha: white where it lifts, black where it shades
    net = white - black
    out = np.zeros((SIZE, SIZE, 4), np.uint8)
    out[..., :3] = np.where(net > 0, 255, 0)[..., None]
    out[..., 3] = (np.clip(np.abs(net), 0, 1) * 255).astype(np.uint8)
    return out


def shown(picture, colour, repeat=1):
    p = np.tile(picture, (repeat, repeat, 1)).astype(float)
    a = p[..., 3:4] / 255.0
    return Image.fromarray((np.array(colour, float)[None, None, :] * (1 - a) + p[..., :3] * a).astype(np.uint8))


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    tile = draw()
    Image.fromarray(tile, "RGBA").save(os.path.join(OUT, "tile2.png"))
    old = np.array(Image.open(os.path.join(OUT, "tile.png")).convert("RGBA"))
    colours = [(86, 213, 96), (199, 207, 179), (136, 220, 67), (222, 217, 174)]  # the hub's floor, wall, grass, sand
    sheet = Image.new("RGB", (4 * 520 + 20, 2 * 520 + 60), (254, 248, 241))
    for k, colour in enumerate(colours):
        sheet.paste(shown(old, colour).resize((512, 512), Image.LANCZOS), (10 + k * 520, 30))
        sheet.paste(shown(tile, colour).resize((512, 512), Image.LANCZOS), (10 + k * 520, 30 + 530))
    sheet.save(os.path.join(OUT, "_tile2_preview.jpg"), quality=90)
    a = tile[..., 3].astype(float) / 255
    print("written", OUT, "| share of the picture left alone:", round(float((a < 0.02).mean()), 2))
