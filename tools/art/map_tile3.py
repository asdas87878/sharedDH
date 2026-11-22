"""The map's surface picture with Roblox's own square studs (2026-11-22; the user: "the current system we have for
circular studs, could we change that to square studs ... use the roblox stud textures and apply them more evenly. Make
sure they flow and follow as they have been"). Option B of the stud bench (docs/design/map-structure.md, "Square
studs"): the same picture as tile2 (two squares by two, every other square 14% darker, 16 studs to a tile), with each
round ring swapped for Roblox's own stud, taken from the engine's stud surface (PlatformContent/pc/textures/studs.dds:
64 pixels to a stud, grey 128 = no change). Being part of the one picture, the studs are laid by the same per-piece
numbers as now, so they flow round the curves and straddle the joints exactly as the squares do.

usage: python tools/art/map_tile3.py [path to studs.dds]   writes art/style/map_tiles/roblox/tile3.png and _tile3_preview.jpg
Not uploaded by this script (uploads are permanent: only on the user's word); the id would go in textures.json as "tile3"."""
import glob
import os
import sys

import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import map_tile2  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT = map_tile2.OUT
SIZE, STUDS = 1024, 16  # as tile2: at 16 studs to a tile, a stud of the picture is one Roblox stud
CELL = SIZE // STUDS  # 64 pixels to a stud: the engine's own stud is drawn at exactly this size
SQUARE = map_tile2.SQUARE
DARK, LIGHT = 1.0, 0.8  # how much of the engine's shade and light the overlay keeps


def roblox_stud(path=None):
    """one stud of the engine's Studs surface, as grey (128 = the part's own colour)"""
    if path is None:
        found = sorted(glob.glob(os.path.expandvars(r"%LOCALAPPDATA%\Roblox\Versions\*\PlatformContent\pc\textures\studs.dds")))
        if not found:
            raise SystemExit("studs.dds not found: give its path")
        path = found[-1]
    a = np.array(Image.open(path).convert("RGB")).astype(float).mean(axis=2)
    return a[0:CELL, 0:CELL]


def draw(path=None):
    stud = np.tile(roblox_stud(path), (STUDS, STUDS))
    black = np.clip((128.0 - stud) / 128.0, 0, 1) * DARK
    white = np.clip((stud - 128.0) / 128.0, 0, 1) * LIGHT
    y, x = np.mgrid[0:SIZE, 0:SIZE]
    half = SIZE // 2
    dark_square = ((x < half) == (y < half)).astype(float)
    black = 1 - (1 - black) * (1 - SQUARE * dark_square)
    net = white - black
    out = np.zeros((SIZE, SIZE, 4), np.uint8)
    out[..., :3] = np.where(net > 0, 255, 0)[..., None]
    out[..., 3] = (np.clip(np.abs(net), 0, 1) * 255).astype(np.uint8)
    return out


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    tile = draw(sys.argv[1] if len(sys.argv) > 1 else None)
    Image.fromarray(tile, "RGBA").save(os.path.join(OUT, "tile3.png"))
    now = np.array(Image.open(os.path.join(OUT, "tile2.png")).convert("RGBA"))
    colours = [(86, 213, 96), (199, 207, 179), (136, 220, 67), (222, 217, 174)]  # the hub's floor, wall, grass, sand
    sheet = Image.new("RGB", (4 * 520 + 20, 2 * 520 + 60), (254, 248, 241))
    for k, colour in enumerate(colours):
        sheet.paste(map_tile2.shown(now, colour).resize((512, 512), Image.LANCZOS), (10 + k * 520, 30))
        sheet.paste(map_tile2.shown(tile, colour).resize((512, 512), Image.LANCZOS), (10 + k * 520, 30 + 530))
    sheet.save(os.path.join(OUT, "_tile3_preview.jpg"), quality=90)
    # the stretch both pictures get on real pieces: a piece's StudsPerTileU over V (parts.json, 2026-11-22: 69% of faces
    # within 5% of even; 5% of faces at 0.76 or less, 5% at 1.28 or more). One stud of the picture shown 64 px tall.
    wall = colours[1]
    stretch = [0.76, 1.0, 1.28]
    st = Image.new("RGB", (len(stretch) * 400 + 20, 2 * 400 + 30), (254, 248, 241))
    for k, a in enumerate(stretch):
        for j, pic in enumerate((now, tile)):
            im = map_tile2.shown(pic, wall).resize((round(1024 * a), 1024), Image.LANCZOS)
            big = Image.new("RGB", (im.width * 2, 1024))
            big.paste(im, (0, 0))
            big.paste(im, (im.width, 0))
            st.paste(big.crop((0, 0, 512, 512)).resize((390, 390), Image.LANCZOS), (10 + k * 400, 10 + j * 400))
    st.save(os.path.join(OUT, "_tile3_stretch.jpg"), quality=90)
    print("written", os.path.join(OUT, "tile3.png"), "and the previews (top: tile2 now, bottom: tile3; stretch 0.76, 1, 1.28)")
