"""One sheet: the reference's rings (crops of the user's recording, private) over the HUD's rings as built
(drawn here with the numbers of src/client/UI/Rings.luau and Kit.luau; a drawing, not a capture of the game).
    python tools/ui/ring_sheet.py docs/attachments/ui4-ring.jpg
"""
import sys
import cv2
from PIL import Image, ImageDraw, ImageFont

VIDEO = r"D:\program files for me\videos\2026-11-09 02-30-32.mkv"
S = 4  # supersampling
U = 3.2  # screen pixels a HUD unit on the sheet

AQUA = (51, 214, 240)
CORAL = (255, 90, 95)
PINK = (240, 96, 200)
INK = (16, 36, 63)
TRACK = (10, 28, 52)
WHITE = (255, 255, 255)
BIG, BIG_THICK, SMALL, SMALL_THICK, OUTER = 50, 16, 28, 9, 63


def font(size, bold=True):
    return ImageFont.truetype(r"C:\Windows\Fonts\arialbd.ttf" if bold else r"C:\Windows\Fonts\arial.ttf", round(size))


def donut(tile, cx, cy, d, thick, frac, colour, lag=0.0, spent=False, track=True):
    """A ring that empties, clockwise from the top, on an RGBA tile (supersampled coordinates)."""
    r = d / 2 * U * S
    layer = Image.new("RGBA", tile.size, (0, 0, 0, 0))
    g = ImageDraw.Draw(layer)
    box = (cx - r, cy - r, cx + r, cy + r)
    if track:
        g.ellipse(box, fill=(CORAL + (216,)) if spent else (TRACK + (128,)))
    if lag > 0:
        g.pieslice(box, -90, -90 + 360 * lag, fill=CORAL + (255,))
    if frac >= 1:
        g.ellipse(box, fill=colour + (255,))
    elif frac > 0:
        g.pieslice(box, -90, -90 + 360 * frac, fill=colour + (255,))
    hole = r - thick * U * S
    g.ellipse((cx - hole, cy - hole, cx + hole, cy + hole), fill=(0, 0, 0, 0))
    w = round(1.2 * U * S)
    g.ellipse(box, outline=INK + (150,), width=w)
    g.ellipse((cx - hole - w, cy - hole - w, cx + hole + w, cy + hole + w), outline=INK + (140,), width=w)
    tile.alpha_composite(layer)


def words(g, cx, y, text, size, fill):
    f = font(size * U * S)
    g.text((cx, y), text, font=f, fill=fill, anchor="ma", stroke_width=round(2.2 * U * S * 0.6), stroke_fill=INK)


def ours(label, frac, colour=AQUA, lag=0.0, spent=False, tame=None, ready=1.0, size=1.0, note="", sub=""):
    w, h = 150, 118
    tile = Image.new("RGBA", (round(w * U * S), round(h * U * S)), (0, 0, 0, 255))
    g = ImageDraw.Draw(tile)
    for y in range(tile.height):  # the sea
        t = y / tile.height
        g.line((0, y, tile.width, y), fill=(round(46 - 14 * t), round(128 - 40 * t), round(186 - 40 * t), 255))
    cx, cy = (w / 2 + 22) * U * S, 44 * U * S
    # the hop's arc
    ro = OUTER / 2 * U * S
    share = 75 * (0.35 + 0.65 * ready)
    arc = Image.new("RGBA", tile.size, (0, 0, 0, 0))
    ImageDraw.Draw(arc).arc(
        (cx - ro, cy - ro, cx + ro, cy + ro), -90, -90 + share,
        fill=(TRACK + (153,)) if ready >= 1 else (WHITE + (230,)), width=round(2.6 * U * S),
    )
    tile.alpha_composite(arc)
    donut(tile, cx, cy, BIG * size, BIG_THICK * size, frac, colour, lag, spent)
    if tame is not None:
        donut(tile, cx - (BIG / 2 + 21 + SMALL / 2) * U * S, cy + U * S, SMALL, SMALL_THICK, tame, PINK)
    if note:
        words(g, cx, cy + (BIG / 2 + 5) * U * S, note, 12.5, (255, 120, 124) if sub or note == "Out of air" else WHITE)
    if sub:
        words(g, cx, cy + (BIG / 2 + 19) * U * S, sub, 10.5, (255, 150, 150))
    tile = tile.resize((round(w * U), round(h * U)), Image.LANCZOS).convert("RGB")
    return label, tile


def theirs(cap, label, t, box=(730, 262, 900, 382), zoom=2.9):
    cap.set(cv2.CAP_PROP_POS_MSEC, t * 1000)
    ok, img = cap.read()
    im = Image.fromarray(cv2.cvtColor(img, cv2.COLOR_BGR2RGB)).crop(box)
    return label, im.resize((round(im.width * zoom), round(im.height * zoom)), Image.LANCZOS)


def main():
    cap = cv2.VideoCapture(VIDEO)
    rows = [
        ("The reference (Ride a Dino, the user's recording)", [
            theirs(cap, "riding: a red line at the edge of what is left", 108.0),
            theirs(cap, "the used part is dark; the tame fills pink", 117.6),
            theirs(cap, "just landed: the ring comes in white", 119.4, (730, 300, 900, 420)),
            theirs(cap, "the tame is full and stays pink", 118.3, (720, 262, 890, 382)),
        ]),
        ("Ours, as built (a drawing from the code's numbers, not a capture)", [
            ours("riding", 1.0, tame=0.35),
            ours("draining: a red line at the edge", 0.72, lag=0.732, tame=0.8),
            ours("just landed: white, a little small", 0.95, colour=(236, 250, 255), size=0.86, ready=0.2, tame=0.0),
            ours("a crash: the piece lost shows red", 0.5, lag=0.72, tame=0.5),
        ]),
        ("", [
            ours("the last second: red", 0.16, colour=CORAL, lag=0.172, tame=1.0),
            ours("too strong: red, bigger, shaking", 0.45, colour=CORAL, lag=0.92, size=1.18, note="Too strong!", sub="needs 800"),
            ours("thrown off it, drowning", 0.0, spent=True, note="Too strong!", sub="needs 800"),
            ours("out of air", 0.0, spent=True, note="Out of air"),
        ]),
    ]
    pad, gap, head = 16, 12, 30
    f = font(15)
    fh = font(18)
    width = pad * 2 + sum(im.width for _, im in rows[1][1]) + gap * 3
    height = pad
    for title, tiles in rows:
        height += (head if title else 0) + max(im.height for _, im in tiles) + 26 + gap
    sheet = Image.new("RGB", (width, height + pad - gap), (24, 26, 32))
    d = ImageDraw.Draw(sheet)
    y = pad
    for title, tiles in rows:
        if title:
            d.text((pad, y), title, font=fh, fill=(255, 220, 90))
            y += head
        x = pad
        tall = max(im.height for _, im in tiles)
        for label, im in tiles:
            sheet.paste(im, (x, y))
            d.text((x + 2, y + tall + 4), label, font=f, fill=(230, 230, 230))
            x += im.width + gap
        y += tall + 26 + gap
    sheet.save(sys.argv[1], quality=92)
    print(sheet.size)


if __name__ == "__main__":
    main()
