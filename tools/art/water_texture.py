"""The water's picture (docs/design/water.md): pale lines round rounded cells, like light on a pool's floor, on a clear
background, repeating without a seam. Drawn from shapes (cell borders), not from filtered noise. Our own drawing: the
tutorial's picture comes from someone else's pack and isn't used.

usage: python tools/art/water_texture.py        writes art/style/water/cells.png (1024, for Roblox) and
                                                 art/style/water/cells_preview.png (four tiles on water blue)
Roblox: one Texture on the water layer's top, white, slid slowly by a script; a second copy at another size and
direction gives the moving, crossing look."""
import os

import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT = os.path.join(ROOT, "art", "style", "water")
SIZE = 1024
CELLS = 4  # cells across a tile
LINE = 0.026  # a line's half width, in cells
SOFT = 0.022  # how soft its edge is
WOBBLE = 0.22  # how far the borders are bent, in cells
SEED = 11


def points(rng):
    """one point in each square of a grid, jittered, so cells are even in size but never regular"""
    p = []
    for j in range(CELLS):
        for i in range(CELLS):
            p.append(((i + 0.5 + rng.uniform(-0.36, 0.36)) / CELLS, (j + 0.5 + rng.uniform(-0.36, 0.36)) / CELLS))
    return np.array(p)


def draw():
    rng = np.random.default_rng(SEED)
    pts = points(rng)
    y, x = np.mgrid[0:SIZE, 0:SIZE] / SIZE
    # bend the plane a little with a few whole waves, so borders curve (whole waves keep the tile seamless)
    for k in range(1, 4):
        ax, ay, px, py = rng.uniform(0.4, 1.0, 2).tolist() + rng.uniform(0, 6.28, 2).tolist()
        x = x + WOBBLE / CELLS / k * ax * np.sin(2 * np.pi * k * y + px)
        y = y + WOBBLE / CELLS / k * ay * np.sin(2 * np.pi * k * x + py)
    d1 = np.full((SIZE, SIZE), 9.0)
    d2 = np.full((SIZE, SIZE), 9.0)
    for px, py in pts:
        dx = np.abs(x - px) % 1.0
        dy = np.abs(y - py) % 1.0
        d = np.hypot(np.minimum(dx, 1 - dx), np.minimum(dy, 1 - dy)) * CELLS
        nearer = d < d1
        d2 = np.where(nearer, d1, np.minimum(d2, d))
        d1 = np.where(nearer, d, d1)
    edge = (d2 - d1) / 2  # distance to the border between the two nearest cells, about
    line = np.clip((LINE + SOFT - edge) / SOFT, 0.0, 1.0)
    glow = np.clip(1.0 - edge / 0.28, 0.0, 1.0) ** 2 * 0.16  # a faint lightening beside each line
    alpha = np.clip(line * 0.85 + glow, 0.0, 1.0)
    rgba = np.zeros((SIZE, SIZE, 4), np.uint8)
    rgba[..., :3] = 255
    rgba[..., 3] = (alpha * 255).astype(np.uint8)
    return Image.fromarray(rgba, "RGBA")


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    im = draw()
    im.save(os.path.join(OUT, "cells.png"))
    back = Image.new("RGBA", (SIZE * 2, SIZE * 2), (40, 120, 235, 255))
    for i in range(2):
        for j in range(2):
            back.alpha_composite(im, (i * SIZE, j * SIZE))
    back.convert("RGB").resize((1024, 1024), Image.LANCZOS).save(os.path.join(OUT, "cells_preview.png"))
    print("written", OUT)
