"""Lays pictures side by side with a label under each, for the user to pick from.
usage: python tools/art/look_sheet.py <out.jpg> <columns> "<title>" <image>=<label> ... [--width 760] [--crop x0,y0,x1,y1]
--crop cuts every picture to that box first (fractions of its width and height).
"""
import sys

from PIL import Image, ImageDraw, ImageFont

args = sys.argv[1:]
width, crop = 760, None
if "--width" in args:
    i = args.index("--width")
    width = int(args[i + 1])
    del args[i:i + 2]
if "--crop" in args:
    i = args.index("--crop")
    crop = [float(v) for v in args[i + 1].split(",")]
    del args[i:i + 2]
out, columns, title = args[0], int(args[1]), args[2]
items = [a.split("=", 1) for a in args[3:]]


def font(size):
    for name in ("arialbd.ttf", "arial.ttf"):
        try:
            return ImageFont.truetype(name, size)
        except OSError:
            pass
    return ImageFont.load_default()


cells = []
for path, label in items:
    im = Image.open(path).convert("RGB")
    if crop:
        w, h = im.size
        im = im.crop((int(crop[0] * w), int(crop[1] * h), int(crop[2] * w), int(crop[3] * h)))
    im = im.resize((width, round(im.size[1] * width / im.size[0])), Image.LANCZOS)
    cells.append((im, label))
gap, bar, head = 10, 34, 54 if title else 10
rows = (len(cells) + columns - 1) // columns
high = max(c[0].size[1] for c in cells)
sheet = Image.new("RGB", (columns * width + (columns + 1) * gap, head + rows * (high + bar + gap)), (24, 28, 36))
draw = ImageDraw.Draw(sheet)
if title:
    draw.text((gap, 12), title, font=font(26), fill=(255, 255, 255))
for n, (im, label) in enumerate(cells):
    x = gap + (n % columns) * (width + gap)
    y = head + (n // columns) * (high + bar + gap)
    sheet.paste(im, (x, y))
    draw.text((x + 4, y + high + 6), label, font=font(20), fill=(235, 238, 245))
sheet.save(out, quality=88)
print(out, sheet.size)
