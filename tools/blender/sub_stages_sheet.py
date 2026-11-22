"""The sheet of all nine submarines (plain Python with Pillow, not a Blender script):

    python tools/blender/sub_stages_sheet.py <renders folder> <out.png>

<renders folder>/<1-9>/ holds what tools/blender/sub_stages.py wrote: hero, side, back and stats.json. One cell a
tier: its number and name, the hero view, the side view and the riding side (from behind and above, with a rider)."""
import json
import os
import sys

from PIL import Image, ImageDraw, ImageFilter, ImageFont

SRC, OUT = sys.argv[1], sys.argv[2]
BOLD = next((p for p in ("/usr/share/fonts/TTF/DejaVuSans-Bold.ttf", "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",
                         "/usr/share/fonts/dejavu/DejaVuSans-Bold.ttf") if os.path.exists(p)), None)


def font(size):
    try:
        return ImageFont.truetype(BOLD, size)
    except (OSError, TypeError):
        return ImageFont.load_default(size)


INK, SOFT, CREAM, WELL = (38, 38, 38), (122, 114, 106), (254, 248, 241), (244, 236, 226)
CW, CH, HEAD, PAD = 1180, 1010, 190, 30
sheet = Image.new("RGB", (PAD + 3 * (CW + PAD), HEAD + 3 * (CH + PAD)), CREAM)
d = ImageDraw.Draw(sheet)
d.text((50, 26), "RIDE A FISH", font=font(40), fill=INK)
d.text((50, 74), "THE NINE SUBMARINES (voxel style)", font=font(72), fill=INK)
d.text((1900, 60), "one a tier; the seat, the tower and the deck are the same on every one,", font=font(30), fill=SOFT)
d.text((1900, 100), "so the ride doesn't change with the look. Studs are in the render only.", font=font(30), fill=SOFT)


def fit(im, w, h):
    box = im.getbbox()
    if box:
        im = im.crop(box)
    k = min(w / im.width, h / im.height)
    return im.resize((max(1, int(im.width * k)), max(1, int(im.height * k))), Image.LANCZOS)


def lay(im, x, y, w, h, shadow=True):
    im = fit(im, w, h)
    at = (x + (w - im.width) // 2, y + (h - im.height) // 2)
    if shadow:
        sh = Image.new("RGBA", im.size, (0, 0, 0, 0))
        sh.putalpha(im.getchannel("A").point(lambda a: a // 5))
        sheet.paste((60, 40, 30), (at[0] + 8, at[1] + 12), sh.filter(ImageFilter.GaussianBlur(10)).getchannel("A"))
    sheet.paste(im, at, im)


for n in range(1, 10):
    folder = os.path.join(SRC, str(n))
    stats = json.load(open(os.path.join(folder, "stats.json")))
    x = PAD + ((n - 1) % 3) * (CW + PAD)
    y = HEAD + ((n - 1) // 3) * (CH + PAD)
    d.rounded_rectangle((x, y, x + CW, y + CH), 26, fill=WELL)
    d.rounded_rectangle((x + 24, y + 22, x + 110, y + 108), 16, fill=INK)
    d.text((x + 67, y + 65), str(n), font=font(60), fill=CREAM, anchor="mm")
    d.text((x + 134, y + 22), stats["name"].upper(), font=font(50), fill=INK)
    d.text((x + 136, y + 82), "%d triangles  /  %d parts  /  %d studs long, %d across" % (
        stats["triangles"], stats["parts"], stats["length"], stats["width"]), font=font(24), fill=SOFT)
    lay(Image.open(os.path.join(folder, "hero.png")).convert("RGBA"), x + 30, y + 130, CW - 60, 520)
    d.text((x + 40, y + 664), "SIDE", font=font(22), fill=SOFT)
    lay(Image.open(os.path.join(folder, "side.png")).convert("RGBA"), x + 30, y + 690, CW // 2 - 40, 290)
    d.text((x + CW // 2 + 20, y + 664), "RIDING SIDE", font=font(22), fill=SOFT)
    lay(Image.open(os.path.join(folder, "back.png")).convert("RGBA"), x + CW // 2 + 10, y + 690, CW // 2 - 40, 290)
os.makedirs(os.path.dirname(os.path.abspath(OUT)), exist_ok=True)
sheet.save(OUT)
print("sheet:", OUT, sheet.size)
