"""The land strip after Hugo's fixes of task m1 (BEST always centred on its diamond, the metres drawn over a bigger
face with the oval under it), from real Studio captures of the game's own strip code (LandStrip.preview):
    python tools/ui/land_icons/m1_sheets.py
Writes docs/attachments/land-strip-m1-1.png (and a copy in ~/Pictures/ride-a-fish/sheets/).
Needs a playtest with l1_client.luau installed (l1_capture.py install, then play, then l1_capture.py listen).
"""
from PIL import Image, ImageDraw

import l1_capture as cap
from options_sheets import BG, GREY, WHITE, header, save, text

CW, CH = 310, 110
STATES = [
    ({"land": 1, "along": 0.12, "metres": 5, "best": 0.05, "bestMetres": 5}, "a short best at the left end (5 m; you 5 m)"),
    ({"land": 3, "along": 0.5, "metres": 210, "best": 0.3, "bestMetres": 12}, "a short best at the left end, you away from it"),
    ({"land": 6, "along": 0.5, "metres": 600, "best": 7.4, "bestMetres": 1300}, "mid-dive, best ahead (600 m; best 1,300 m)"),
    ({"land": 7, "along": 0.42, "metres": 1290, "best": 6.42, "bestMetres": 1290}, "on a new best (you and BEST together)"),
    ({"land": 3, "along": 0.5, "metres": 214, "best": 9.98, "bestMetres": 12480}, "a long best at the right end (12,480 m)"),
    ({"land": 10, "along": 0.99, "metres": 99999, "best": 9.99, "bestMetres": 99999}, "the longest: 99,999 m, both at the right end"),
]
METRES = [5, 42, 999, 1290, 12480, 99999]


def label(im, xy, s, px=19, fill=GREY):
    text(ImageDraw.Draw(im), xy, s, px, fill)


def main():
    big = []
    for part in (STATES[:3], STATES[3:]):
        items = [{"x": 20, "y": 30 + k * 345, "s": 3, "o": {"Intro": 0}, "st": st} for k, (st, _) in enumerate(part)]
        cap.cells(items)
        view = cap.shot("m1_3x", 3)
        big += [cap.crop(view, it, CW, CH) for it in items]
    items1 = [{"x": 20 + k * 325, "y": 60, "s": 1, "o": {"Intro": 0}, "st": st} for k, (st, _) in enumerate(STATES)]
    cap.cells(items1)
    view = cap.shot("m1_1x", 2.5)
    real = [cap.crop(view, it, CW, CH) for it in items1]
    # the marker alone at 5x, through the metres (land 5 half through: the marker's centre at x 140 of the holder)
    marks = []
    for m in METRES:
        it = {"x": -400, "y": 20, "s": 5, "o": {"Intro": 0},
              "st": {"land": 5, "along": 0.5, "metres": m, "best": 8.5, "bestMetres": 50000}}
        cap.cells([it])
        view = cap.shot(f"m1_5x_{m}", 2)
        marks.append(view.crop((it["x"] + 95 * 5, it["y"] + 36 * 5, it["x"] + 185 * 5, it["y"] + 86 * 5)))

    W = 1960
    lines = [
        "BEST is always centred on its gold diamond; near an end the two stop together (at most 10 px past the strip).",
        "Your face is 20 px (was 18). The black oval is drawn under the face, the metres over it, covering only its",
        "lower edge; the oval grows with the metres up to 60 px, then the metres shrink to fit (99,999 m fits).",
    ]
    rowh = CH * 3 + 50
    mw, mh = marks[0].size
    H = 150 + 6 * rowh + 60 + 2 * (mh + 12) + 70
    im = Image.new("RGB", (W, H), BG)
    im.paste(header(W, "Land strip: Hugo's fixes (task m1)", lines), (0, 0))
    y = 150
    for k, (_, name) in enumerate(STATES):
        label(im, (30, y), f"3x: {name}", 19, WHITE)
        im.paste(big[k], (30, y + 28))
        label(im, (30 + big[k].width + 40, y + 28), "real size (1:1, HUD scale 1)", 17)
        im.paste(real[k], (30 + big[k].width + 40, y + 56))
        y += rowh
    label(im, (30, y), "Your marker at 5x, through the metres: " + ", ".join(f"{m:,} m" for m in METRES), 19, WHITE)
    for k, m in enumerate(marks):
        im.paste(m, (30 + (k % 3) * (mw + 12), y + 30 + (k // 3) * (mh + 12)))
    im = im.crop((0, 0, W, y + 30 + 2 * (mh + 12) + 30))
    save(im, "land-strip-m1-1.png")


if __name__ == "__main__":
    main()
    print(cap.log()[-400:])
