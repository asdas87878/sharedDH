"""A looping GIF of fish_kit.py's swim cycles: one row per joint variant, the 3/4 and top views side by side, plus a still of
one frame for quick checks.

usage: python tools/art/swim_gif.py <renders folder> <out.gif> <variant> [<variant> ...] [--still N]
"""
import os
import sys

from PIL import Image, ImageDraw, ImageFont

args = sys.argv[1:]
still = int(args[args.index("--still") + 1]) if "--still" in args else None
if still is not None:
    i = args.index("--still")
    args = args[:i] + args[i + 2 :]
renders, out, variants = args[0], args[1], args[2:]
LABELS = {"flat": "plain joints", "sleeve": "sleeved joints"}
font = ImageFont.truetype("C:/Windows/Fonts/arialbd.ttf", 22)
frames_n = len([n for n in os.listdir(os.path.join(renders, f"swim_{variants[0]}")) if n.startswith("hero_")])


def frame(f):
    rows = []
    for v in variants:
        views = []
        for name in ("hero", "top", "ride"):
            path = os.path.join(renders, f"swim_{v}", f"{name}_{f:03d}.png")
            if os.path.exists(path):
                im = Image.open(path).convert("RGBA")
                base = Image.new("RGBA", im.size, (254, 248, 241, 255))
                base.alpha_composite(im)
                views.append(base.convert("RGB"))
        height = max(im.height for im in views)
        row = Image.new("RGB", (sum(im.width for im in views), height + 34), (254, 248, 241))
        x = 0
        for im in views:
            row.paste(im, (x, 34 + (height - im.height) // 2))
            x += im.width
        ImageDraw.Draw(row).text((12, 6), LABELS.get(v, v), font=font, fill=(40, 40, 40))
        rows.append(row)
    sheet = Image.new("RGB", (rows[0].width, sum(r.height for r in rows)), (254, 248, 241))
    y = 0
    for r in rows:
        sheet.paste(r, (0, y))
        y += r.height
    return sheet


images = [frame(f) for f in range(frames_n)]
images[0].save(out, save_all=True, append_images=images[1:], duration=42, loop=0, optimize=True)
print("gif", out, images[0].size, frames_n, "frames")
if still is not None:
    path = os.path.splitext(out)[0] + f"_still{still}.png"
    images[still].save(path)
    print("still", path)
