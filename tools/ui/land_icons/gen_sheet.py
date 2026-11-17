"""The land pictures redrawn by OpenAI's gpt-image-2 (Hugo, 2026-11-17: "take selected icons and run through chatgpt
image generation to make a visually pretty and cohesive version"; task l1). Four variations G1 to G4 of one run
(ElevenLabs connector, image edit from the ten picks laid out 5 x 2: work/land_icons/gen/input_grid.png).
    python tools/ui/land_icons/gen_sheet.py
slices each generated sheet (docs/attachments/land-icons/gen/G<k>.jpg) into ten squares (docs/attachments/land-icons/
gen/G<k>_land<NN>.png, 256 px) and writes docs/attachments/land-icons-gen-1.png: the picks today against G1 to G4,
each as style-A tiles (one ink frame, no inner band) at 3x and as the strip at real size.
"""
from pathlib import Path

from PIL import Image, ImageDraw

import icons
from selection import tile_A

ROOT = icons.ROOT
GEN = ROOT / "docs/attachments/land-icons/gen"
OUT = ROOT / "docs/attachments/land-icons-gen-1.png"
BG = (22, 24, 30)
CARD = (34, 37, 46)
WHITE = (236, 238, 242)
GREY = (165, 170, 182)
GOLD = (255, 220, 90)


def runs(v, minlen=40):
    out, start = [], None
    for i, x in enumerate(v + [False]):
        if x and start is None:
            start = i
        if not x and start is not None:
            if i - start > minlen:
                out.append((start, i))
            start = None
    return out


def slice_sheet(k):
    im = Image.open(GEN / f"G{k}.jpg").convert("RGB")
    W, H = im.size
    px = im.convert("L").point(lambda p: 255 if p < 232 else 0).load()
    rowf = [sum(1 for x in range(0, W, 2) if px[x, y]) / (W / 2) for y in range(H)]
    colf = [sum(1 for y in range(0, H, 2) if px[x, y]) / (H / 2) for x in range(W)]
    rows, cols = runs([r > 0.3 for r in rowf]), runs([c > 0.15 for c in colf])
    assert len(rows) == 2 and len(cols) == 5, (k, rows, cols)
    n = 0
    for r0, r1 in rows:
        for c0, c1 in cols:
            n += 1
            s = min(c1 - c0, r1 - r0) - 6
            cx, cy = (c0 + c1) // 2, (r0 + r1) // 2
            sq = im.crop((cx - s // 2, cy - s // 2, cx + s // 2, cy + s // 2)).resize((256, 256), Image.LANCZOS)
            sq.save(GEN / f"G{k}_land{n:02d}.png")


def strip(pics, px):
    gap = round(px * 2 / 28)
    out = Image.new("RGBA", (10 * px + 9 * gap, px), (0, 0, 0, 0))
    for i, p in enumerate(pics):
        t = tile_A(p, px)
        out.alpha_composite(t, (i * (px + gap), 0))
    return out


def main():
    for k in range(1, 5):
        slice_sheet(k)
    sets = [("Now", "the captures", [icons.picture(l, 120, 120) for l in range(1, 11)])]
    for k in range(1, 5):
        sets.append((f"G{k}", "gpt-image-2",
                     [Image.open(GEN / f"G{k}_land{l:02d}.png").convert("RGB") for l in range(1, 11)]))
    W = 2000
    row_h = 330
    img = Image.new("RGB", (W, 150 + row_h * len(sets) + 20), BG)
    d = ImageDraw.Draw(img)
    d.text((28, 20), "Ride a Fish: the land pictures redrawn as one set (gpt-image-2). Pick G1 to G4, or Now", font=icons.font(38), fill=GOLD)
    d.text((28, 72), "Hugo: \"take selected icons and run through chatgpt image generation to make a visually pretty and cohesive version\". "
           "Input: the ten picks of the framings sheet (1d 2d 3d 4d 5e 6d 7e 8d 9e 10d).", font=icons.font(18), fill=GREY)
    d.text((28, 96), "Each row: the ten in the strip's style A as built (one ink frame, NO inner band) at 3x, and the strip at real size (28 px "
           "tiles). One run, four variations; nothing uploaded.", font=icons.font(18), fill=GREY)
    y = 140
    for name, note, pics in sets:
        d.rounded_rectangle((16, y, W - 16, y + row_h - 14), 14, fill=CARD)
        d.text((36, y + 14), name, font=icons.font(44), fill=GOLD)
        d.text((36, y + 70), note, font=icons.font(16), fill=GREY)
        big = strip(pics, 84)
        img.paste(big, (200, y + 20), big)
        small = strip(pics, 28)
        img.paste(small, (200, y + 20 + 84 + 30), small)
        d.text((200, y + 20 + 84 + 8), "real size", font=icons.font(15), fill=GREY)
        x = 200 + small.width + 40
        for i in (0, 4, 9):
            p = pics[i].resize((150, 150), Image.LANCZOS)
            img.paste(p, (x, y + 134))
            x += 160
        y += row_h
    img.save(OUT)
    print("wrote", OUT)


if __name__ == "__main__":
    main()
