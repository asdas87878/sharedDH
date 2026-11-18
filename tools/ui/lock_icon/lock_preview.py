"""An offline preview of the pictured lock (task k1) until Studio can draw again: the lock on two locked land tiles
beside the l1 capture of today's lock, and the break as a GIF, played with LandStrip.luau's own numbers (PIECES, FLY,
the glint's tween, BREAK_TIME). Not a capture of the game: the tiles are the land atlas's grey row darkened by hand,
without their numbers.

    ~/.cache/sharedDH-venv/bin/python tools/ui/lock_icon/lock_preview.py

Writes docs/attachments/land-strip-locks-2-preview.png and .gif.
"""

import json
from pathlib import Path

from PIL import Image, ImageDraw, ImageEnhance

ROOT = Path(__file__).resolve().parents[3]
K = 4  # drawn at four times the strip's size, as the l1 captures
TILE, LOCK = 28, 20
INK = (4, 4, 53)
BACK = (24, 28, 44)
ATLAS = Image.open(ROOT / "art/ui/icons/lock_atlas.png").convert("RGBA")
META = json.loads((ROOT / "art/ui/icons/lock_atlas.json").read_text())["pieces"]
LANDS = Image.open(ROOT / "docs/attachments/land-icons/land_atlas.png").convert("RGB")
FLY = {
    "Shackle": (-3, -9, -55),
    "Left": (-6, 14, -38),
    "Right": (6, 15, 42),
    "Chip1": (-9, -5, -120),
    "Chip2": (10, -3, 140),
    "Chip3": (2, 10, 200),
}
DEPTH = {"Shackle": 0, "Left": 1, "Right": 1, "Chip1": 2, "Chip2": 2, "Chip3": 2}
BREAK = 0.5


def piece(name):
    x, y, w, h = META[name]["rect"]
    return ATLAS.crop((x, y, x + w, y + h))


def tile(land):
    """A locked land tile at K times: the grey picture, darkened, an ink border with round corners"""
    cell = LANDS.crop(((land - 1) * 96, 96, land * 96, 192)).resize((TILE * K, TILE * K), Image.LANCZOS)
    cell = ImageEnhance.Brightness(cell).enhance(0.55)
    out = Image.new("RGBA", (TILE * K, TILE * K), (0, 0, 0, 0))
    mask = Image.new("L", out.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, TILE * K - 1, TILE * K - 1], radius=5 * K, fill=255)
    out.paste(cell, (0, 0), mask)
    ImageDraw.Draw(out).rounded_rectangle([0, 0, TILE * K - 1, TILE * K - 1], radius=5 * K, outline=INK, width=2 * K)
    return out


def put(img, name, cx, cy, size_scale=1.0, rot=0.0, fade=0.0, box=None):
    """A piece centred at (cx, cy) in K-pixels, sized from its box in the lock's square"""
    bx = box or META[name]["box"]
    w, h = max(1, round(bx[2] * LOCK * K * size_scale)), max(1, round(bx[3] * LOCK * K * size_scale))
    p = piece(name).resize((w, h), Image.LANCZOS)
    if fade > 0:
        a = p.getchannel("A").point(lambda v: round(v * (1 - fade)))
        p.putalpha(a)
    if rot:
        p = p.rotate(-rot, resample=Image.BICUBIC, expand=True)  # Roblox turns clockwise
    img.alpha_composite(p, (round(cx - p.width / 2), round(cy - p.height / 2)))


def lock_at(img, ox, oy, t=None):
    """The lock in a tile whose top left is (ox, oy); t = seconds into the break, None = whole"""
    rx = ox + (TILE / 2 + 1 - LOCK / 2) * K
    ry = oy + (TILE / 2 - 1 - LOCK / 2) * K

    def centre(name):
        b = META[name]["box"]
        return rx + (b[0] + b[2] / 2) * LOCK * K, ry + (b[1] + b[3] / 2) * LOCK * K

    if t is None:
        put(img, "Whole", *centre("Whole"))
        return
    if t >= 0.07 + BREAK:
        return
    k = max(0.0, min(1.0, (t - 0.07) / (BREAK - 0.07)))
    out_, in_ = 1 - (1 - k) ** 2, k * k
    for name in sorted(FLY, key=lambda n: DEPTH[n]):
        cx, cy = centre(name)
        if name in ("Left", "Right"):
            cx += (-1 if name == "Left" else 1) * K
        fx, fy, fr = FLY[name]
        put(img, name, cx + fx * K * out_, cy + fy * K * out_, rot=fr * out_, fade=in_)
    g = max(0.0, min(1.0, t / 0.26))
    go = 1 - (1 - g) ** 2
    if g < 1:
        cx, cy = rx + LOCK * K / 2, ry + LOCK * K / 2
        put(img, "Glint", cx, cy, size_scale=0.3 + 1.6 * go, rot=45 * go, fade=go)


def strip(lands, t=None, broken=()):
    w = len(lands) * TILE * K + (len(lands) - 1) * 2 * K
    img = Image.new("RGBA", (w + 16 * K, (TILE + 16) * K), (*BACK, 255))
    for i, land in enumerate(lands):
        ox, oy = 8 * K + i * (TILE + 2) * K, 8 * K
        img.alpha_composite(tile(land), (ox, oy))
        if land in broken:
            lock_at(img, ox, oy, t)
        else:
            lock_at(img, ox, oy)
    return img


def label(img, text):
    out = Image.new("RGB", (img.width, img.height + 26), BACK)
    out.paste(img.convert("RGB"), (0, 26))
    ImageDraw.Draw(out).text((8, 7), text, fill=(235, 235, 245))
    return out


def main():
    before = Image.open(ROOT / "docs/attachments/land-strip-l1-locks-1.gif")
    before.seek(0)
    before = before.convert("RGB")
    after = strip([4, 5])
    real = strip([4, 5, 6, 7]).resize(((4 * TILE + 3 * 2 + 16), TILE + 16), Image.LANCZOS)
    sheet = Image.new("RGB", (before.width + after.width + 60, max(before.height, after.height) + 150), BACK)
    sheet.paste(label(before, "before: today's lock (l1 capture, 4x)"), (10, 10))
    sheet.paste(label(after, "after: the pictured lock (preview, 4x)"), (before.width + 40, 10))
    sheet.paste(label(real.resize((real.width * 2, real.height * 2), Image.NEAREST), "real size, 2x"), (10, before.height + 50))
    sheet.paste(real, (before.width + 40, before.height + 90))
    ImageDraw.Draw(sheet).text(
        (before.width + 40, before.height + 70), "real size (phone and desktop)", fill=(235, 235, 245)
    )
    out = ROOT / "docs/attachments/land-strip-locks-2-preview.png"
    sheet.save(out)
    frames = []
    for f in range(0, 30):
        t = f / 40 - 0.1  # 40 frames a second from a tenth before the break
        img = strip([4, 5], t=t if t >= 0 else None, broken=(4,) if t >= 0 else ())
        frames.append(img.convert("RGB"))
    for _ in range(12):
        frames.append(frames[-1])
    frames[0].save(
        ROOT / "docs/attachments/land-strip-locks-2-preview.gif",
        save_all=True,
        append_images=frames[1:],
        duration=[25] * 30 + [80] * 12,
        loop=0,
    )
    print(out)


if __name__ == "__main__":
    main()
