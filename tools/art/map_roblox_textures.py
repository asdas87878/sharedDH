"""The map's two pictures for Roblox (docs/design/map-method.md, "Studs and squares in Roblox"): see-through overlays
that go on a part as a Texture, over the part's own colour. White lifts, black shades, clear leaves the colour alone,
so one picture works on every land's colour.

usage: python tools/art/map_roblox_textures.py   writes art/style/map_tiles/roblox/
    stud.png    256 px, 4 x 4 round studs: one tile = 4 studs of map (a stud to a stud, Roblox's classic size)
    floor.png   1024 px, 20 x 20 studs with the grid under them: one tile = 20 studs = 2 x 2 squares of 10
    _preview.jpg  both laid over the lands' colours, as Roblox would show them

The stud is the creatures' own (art/style/tiles/stud.png, tools/art/creature_tiles.py), read here, not changed.
Nothing is uploaded by this script. The asset ids, once uploaded, go in art/map/textures.json."""
import os

import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SRC = os.path.join(ROOT, "art", "style", "tiles", "stud.png")
OUT = os.path.join(ROOT, "art", "style", "map_tiles", "roblox")
STUD_STRENGTH = 0.5  # quieter than on the creatures: a fish has to stand out against the floor
SQUARE_SHADE = 0.08  # how much darker every other square of the grid is


def overlay(grey, strength):
    """a grey tile (128 = no change) as white and black with alpha"""
    g = grey.astype(float)
    alpha = np.clip(np.abs(g - 128.0) / 128.0 * strength, 0, 1)
    out = np.zeros(g.shape + (4,), np.uint8)
    out[..., :3] = np.where(g > 128, 255, 0)[..., None]
    out[..., 3] = (alpha * 255).astype(np.uint8)
    return out


def over(a, b):
    """picture b laid over picture a, both white or black with alpha (straight alpha, kept as colour and alpha)"""
    aa, ba = a[..., 3:4] / 255.0, b[..., 3:4] / 255.0
    alpha = ba + aa * (1 - ba)
    colour = np.where(alpha > 0, (b[..., :3] * ba + a[..., :3] * aa * (1 - ba)) / np.maximum(alpha, 1e-6), 0)
    return np.concatenate([colour, alpha * 255], axis=-1).astype(np.uint8)


def shown(picture, colour, repeat):
    """how a part of this colour looks under the picture, repeated"""
    p = np.tile(picture, (repeat, repeat, 1)).astype(float)
    a = p[..., 3:4] / 255.0
    return Image.fromarray((np.array(colour, float)[None, None, :] * (1 - a) + p[..., :3] * a).astype(np.uint8))


os.makedirs(OUT, exist_ok=True)
one = Image.open(SRC).convert("L")
stud64 = np.asarray(one.resize((64, 64), Image.LANCZOS))
stud = overlay(np.tile(stud64, (4, 4)), STUD_STRENGTH)
Image.fromarray(stud, "RGBA").save(os.path.join(OUT, "stud.png"))

px = 1024 // 20  # 51 pixels to a stud, 20 studs to the picture
stud51 = np.asarray(one.resize((px, px), Image.LANCZOS))
field = np.full((1024, 1024), 128, np.uint8)
field[: px * 20, : px * 20] = np.tile(stud51, (20, 20))
field = np.asarray(Image.fromarray(field[: px * 20, : px * 20]).resize((1024, 1024), Image.LANCZOS))
studs = overlay(field, STUD_STRENGTH)
grid = np.zeros((1024, 1024, 4), np.uint8)
grid[:512, :512, 3] = grid[512:, 512:, 3] = int(SQUARE_SHADE * 255)  # two of the four squares a shade darker
floor = over(grid, studs)
Image.fromarray(floor, "RGBA").save(os.path.join(OUT, "floor.png"))

# ---- tile.png (2026-11-11, docs/design/map-structure.md): the one picture for every surface. Two squares by two
# (a square is 5 studs, so the picture is 10 studs), 8 round studs across a square as the reference has, darker than
# the first try, and the squares soft. It replaces stud.png and floor.png.
TILE_STUD, TILE_SQUARE = 0.85, 0.06
one64 = np.asarray(one.resize((64, 64), Image.LANCZOS))
tile_studs = overlay(np.tile(one64, (16, 16)), TILE_STUD)
tile_grid = np.zeros((1024, 1024, 4), np.uint8)
tile_grid[:512, :512, 3] = tile_grid[512:, 512:, 3] = int(TILE_SQUARE * 255)
tile = over(tile_grid, tile_studs)
Image.fromarray(tile, "RGBA").save(os.path.join(OUT, "tile.png"))
look = Image.new("RGB", (4 * 520 + 20, 540), (254, 248, 241))
for k, colour in enumerate([(150, 176, 160), (70, 150, 60), (40, 120, 70), (242, 214, 128)]):
    look.paste(shown(tile, colour, 1).resize((512, 512), Image.LANCZOS), (10 + k * 520, 14))  # 10 studs across
look.save(os.path.join(OUT, "_tile_preview.jpg"), quality=90)

lands = [(242, 214, 128), (244, 148, 152), (120, 172, 92), (160, 148, 124)]
sheet = Image.new("RGB", (4 * 520 + 20, 2 * 520 + 20), (254, 248, 241))
for k, colour in enumerate(lands):
    sheet.paste(shown(floor, colour, 1).resize((512, 512), Image.LANCZOS), (10 + k * 520, 10))  # 20 studs across
    sheet.paste(shown(stud, colour, 2).resize((512, 512), Image.LANCZOS), (10 + k * 520, 530))  # 8 studs across
sheet.save(os.path.join(OUT, "_preview.jpg"), quality=90)
print("stud.png", stud.shape, "floor.png", floor.shape, "->", OUT)
