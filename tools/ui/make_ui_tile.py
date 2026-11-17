"""Draws the tile for the faint block pattern on a button's face, as the reference's UI has it, measured off the
user's recording (docs/design/ui.md, "How the reference does its stud pattern"): one raised square in a square tile,
lit from the upper right. All of it is white or black at a low alpha on a clear ground, so one picture works over
any colour.
    python tools/ui/make_ui_tile.py            writes art/ui/tiles/emboss_square.png and a preview beside the reference
The measures, in a tile 36 across (the reference's at 720 high): the square is 20, its top and right edges are pale
lines, its left and bottom edges dark lines, each about 3 thick and inside the square, and its face a touch paler
than the plate.
"""
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "art" / "ui" / "tiles"
TILE, SQUARE, LINE = 36, 20, 3.0
SCALE = 4  # the picture is 144 across
TOP, RIGHT, DARK, FACE = 0.13, 0.18, 0.08, 0.05  # how strong the top line, the right line, the dark lines, the face


def tile() -> Image.Image:
    n = TILE * SCALE
    over = 4  # drawn four times bigger, then shrunk, for soft edges
    big = n * over
    white = Image.new("L", (big, big), 0)
    black = Image.new("L", (big, big), 0)
    k = SCALE * over
    a = (TILE - SQUARE) / 2 * k
    b = a + SQUARE * k
    t = LINE * k
    ImageDraw.Draw(white).rounded_rectangle((a, a, b, b), radius=1.5 * k, fill=round(FACE * 255))
    dw, db = ImageDraw.Draw(white), ImageDraw.Draw(black)
    # the top and right edges catch the light; the left and bottom edges are in shade
    dw.rounded_rectangle((a, a, b, a + t), radius=t / 2, fill=round(TOP * 255))
    dw.rounded_rectangle((b - t, a, b, b), radius=t / 2, fill=round(RIGHT * 255))
    db.rounded_rectangle((a, a + t, a + t, b), radius=t / 2, fill=round(DARK * 255))
    db.rounded_rectangle((a, b - t, b - t, b), radius=t / 2, fill=round(DARK * 255))
    white = np.asarray(white.resize((n, n), Image.LANCZOS)).astype(np.float32)
    black = np.asarray(black.resize((n, n), Image.LANCZOS)).astype(np.float32)
    alpha = np.maximum(white, black)
    grey = np.where(white >= black, 255, 0)
    return Image.fromarray(np.dstack([grey, grey, grey, alpha]).clip(0, 255).astype(np.uint8), "RGBA")


def button(tl: Image.Image, top, bottom, px_per_tile: float, size) -> Image.Image:
    """A plate with a top-to-bottom gradient and the tile laid over it from its upper left corner."""
    w, h = size
    grad = np.linspace(0, 1, h)[:, None, None]
    face = (np.array(top) * (1 - grad) + np.array(bottom) * grad) * np.ones((h, w, 3))
    plate = Image.fromarray(face.astype(np.uint8), "RGB").convert("RGBA")
    t = tl.resize((round(px_per_tile), round(px_per_tile)), Image.LANCZOS)
    # the reference's first square is flush with the button's left edge and 6.5 down from its top, where a
    # centred square would be 8 in and 8 down: the same shift here
    ox, oy = round(-8 / 36 * px_per_tile), round(-1.5 / 36 * px_per_tile)
    for y in range(oy, h, t.height):
        for x in range(ox, w, t.width):
            plate.alpha_composite(t, (max(x, 0), max(y, 0)), (max(-x, 0), max(-y, 0)))
    return plate.convert("RGB")


if __name__ == "__main__":
    OUT.mkdir(parents=True, exist_ok=True)
    tl = tile()
    tl.save(OUT / "emboss_square.png")
    zoom = 6
    ours = button(tl, (244, 148, 162), (230, 91, 117), 36 * zoom, (189 * zoom, 62 * zoom))
    ours_blue = button(tl, (164, 199, 247), (117, 161, 224), 36 * zoom, (189 * zoom, 62 * zoom))
    sheet = Image.new("RGB", (ours.width * 2 + 48, ours.height * 2 + 48), (24, 28, 38))
    sheet.paste(ours, (ours.width + 32, 16))
    sheet.paste(ours_blue, (ours.width + 32, ours.height + 32))
    ref = ROOT / "research" / "ride-a-dino" / "ui" / "buttons_avg.png"
    if ref.exists():
        r = Image.open(ref).convert("RGB")
        sheet.paste(r.crop((4, 4, 193, 66)).resize(ours.size, Image.LANCZOS), (16, 16))
        sheet.paste(r.crop((4, 78, 193, 140)).resize(ours.size, Image.LANCZOS), (16, ours.height + 32))
    sheet.save(ROOT / "research" / "ride-a-dino" / "ui" / "compare-stud-tile.png")
    print(OUT / "emboss_square.png", tl.size)
