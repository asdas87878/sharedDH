"""The land pictures to choose from, round two (task l1): per land the six new captures (h to m, plan2.py) big, each
with how it reads as a style-A tile (the new frame, no inner band) at 3x and at real size, and round one's (a to g)
small under them.
    python tools/ui/land_icons/selection.py
writes docs/attachments/land-icons-selection-1.jpg (lands 1 to 5) and -2.jpg (lands 6 to 10).
Each tile is cut from the middle of its capture (cx 0.5, cy 0.5, 80 % of the height); the chosen crop can be moved
in picks.json after the pick.
"""
from pathlib import Path

from PIL import Image, ImageDraw

import icons

ROOT = icons.ROOT
ATT = ROOT / "docs/attachments"
LI = ATT / "land-icons"
BG = (22, 24, 30)
CARD = (34, 37, 46)
WHITE = (236, 238, 242)
GREY = (160, 166, 178)
GOLD = (255, 220, 90)
NEW = "hijklm"
OLD = "abcdefg"
NOTE = {
    "h": "first asset, other side",
    "i": "second asset, low",
    "j": "third asset",
    "k": "from above",
    "l": "from the floor",
    "m": "across the lane",
}
TW, TH = 420, 226  # a new capture's thumbnail
SW, SH = 150, 81  # an old one's


def tile_A(pic, px):
    """Style A without the inner band, drawn at px pixels: ink frame, the picture, the top shine."""
    ss = 6
    n = px * ss
    im = Image.new("RGBA", (n, n), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    u = n / 28
    d.rounded_rectangle((0, 0, n - 1, n - 1), 6 * u, fill=icons.INK)
    f = round(2.5 * u)
    inner = pic.resize((n - 2 * f, n - 2 * f), Image.LANCZOS)
    im.paste(inner, (f, f), icons.rr_mask(inner.size, (0, 0, inner.size[0] - 1, inner.size[1] - 1), 3.5 * u))
    d.line((f + 3 * u, f + u, n - f - 3 * u, f + u), fill=(255, 255, 255, 128), width=max(1, round(1.2 * u)))
    return im.resize((px, px), Image.LANCZOS)


def candidate(land, letter):
    path = LI / f"land{land:02d}{letter}.jpg"
    return path if path.exists() else None


def sheet(lands, out, page):
    head = 120
    row_h = TH + SH + 92
    W = 250 + 6 * (TW + 14) + 20
    img = Image.new("RGB", (W, head + len(lands) * row_h + 20), BG)
    d = ImageDraw.Draw(img)
    d.text((24, 18), f"Ride a Fish: pictures for the land strip, round two ({page} of 2). Answer e.g. \"3k, 7h\"", font=icons.font(36), fill=GOLD)
    d.text((24, 66), "Big: six new captures a land (h to m), each with its style-A tile (no inner band) at 3x and real size. "
           "Small: round one's (a to g; 1b and 9b were dropped then). "
           "2l, 5l, 6l, 7i, 7l and 10i were retaken from the lane's middle (the first try faced a wall). Captured in Play, 2026-11-17.", font=icons.font(19), fill=GREY)
    y = head
    for land in lands:
        d.rounded_rectangle((12, y, W - 12, y + row_h - 12), 14, fill=CARD)
        d.text((28, y + 14), str(land), font=icons.font(58), fill=icons.LANDS[land - 1])
        d.text((28, y + 84), icons.NAMES[land - 1], font=icons.font(24), fill=WHITE)
        cur = icons.picks().get(str(land))
        if cur:
            d.text((28, y + 118), f"now: {land}{cur[0]}", font=icons.font(18), fill=GREY)
        x = 250
        for letter in NEW:
            p = candidate(land, letter)
            d.rounded_rectangle((x - 4, y + 10, x + TW + 4, y + TH + 18), 8, fill=(44, 48, 60))
            if p:
                src = Image.open(p).convert("RGB")
                img.paste(src.resize((TW, TH), Image.LANCZOS), (x, y + 14))
                pic = icons.picture(land, 120, 120, [letter, 0.5, 0.5, 0.8])
                big, small = tile_A(pic, 84), tile_A(pic, 28)
                img.paste(big, (x + TW - 92, y + TH - 80), big)
                img.paste(small, (x + TW - 128, y + TH - 24), small)
            else:
                d.text((x + TW / 2, y + TH / 2), "not captured", font=icons.font(22), fill=GREY, anchor="mm")
            d.rounded_rectangle((x + 6, y + 20, x + 58, y + 52), 6, fill=(0, 0, 0))
            d.text((x + 32, y + 36), f"{land}{letter}", font=icons.font(22), fill=WHITE, anchor="mm")
            d.text((x + 2, y + TH + 22), NOTE[letter], font=icons.font(17), fill=GREY)
            x += TW + 14
        x = 250
        yy = y + TH + 50
        d.text((x - 120, yy + 30), "round one", font=icons.font(17), fill=GREY)
        for letter in OLD:
            p = candidate(land, letter)
            if not p:
                continue
            img.paste(Image.open(p).convert("RGB").resize((SW, SH), Image.LANCZOS), (x, yy))
            d.rectangle((x, yy, x + 34, yy + 22), fill=(0, 0, 0))
            d.text((x + 17, yy + 11), f"{land}{letter}", font=icons.font(15), fill=WHITE, anchor="mm")
            x += SW + 10
        y += row_h
    img.save(out, quality=88)
    print("wrote", out)


if __name__ == "__main__":
    sheet(range(1, 6), ATT / "land-icons-selection-1.jpg", 1)
    sheet(range(6, 11), ATT / "land-icons-selection-2.jpg", 2)
