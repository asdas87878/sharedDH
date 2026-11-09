"""A creature's turnaround sheet in the same layout as the ChatGPT concept sheets (hero view, side, front, top, palette), from
the transparent renders of tools/blender/fish_kit.py, so the two can be compared side by side.

usage: python tools/art/creature_sheet.py <spec.json> <renders folder> <sheet.png> [<concept image> <compare.jpg>]
"""
import json
import sys

from PIL import Image, ImageDraw, ImageFilter, ImageFont

spec = json.load(open(sys.argv[1]))
renders = sys.argv[2]
out = sys.argv[3]

BG = (254, 248, 241)
INK = (40, 40, 40)
W, H = 1536, 1024
FONT = "C:/Windows/Fonts/"


def font(name, size):
    return ImageFont.truetype(FONT + name, size)


def placed(name, box_w, box_h):
    """a render cropped to its contents and scaled to fit the box"""
    im = Image.open(f"{renders}/{name}.png").convert("RGBA")
    im = im.crop(im.getbbox())
    scale = min(box_w / im.width, box_h / im.height)
    return im.resize((int(im.width * scale), int(im.height * scale)), Image.LANCZOS)


def shadow(sheet, x, y, w, h):
    """a soft contact shadow under a render's footprint"""
    layer = Image.new("RGBA", sheet.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    d.ellipse((x + w * 0.15, y + h - h * 0.02, x + w * 0.85, y + h + h * 0.07), fill=(60, 50, 40, 70))
    sheet.alpha_composite(layer.filter(ImageFilter.GaussianBlur(12)))


def put(sheet, im, cx, top, with_shadow=True):
    x = int(cx - im.width / 2)
    if with_shadow:
        shadow(sheet, x, top, im.width, im.height)
    sheet.alpha_composite(im, (x, int(top)))


sheet = Image.new("RGBA", (W, H), BG + (255,))
d = ImageDraw.Draw(sheet)
d.text((44, 18), "RIDE A FISH", font=font("ariblk.ttf", 40), fill=INK)
d.text((40, 58), spec["name"].upper(), font=font("ariblk.ttf", 72), fill=INK)
tag_font = font("arialbd.ttf", 28)
zone = spec.get("zone", "")
zw = d.textlength(zone, font=tag_font)
d.polygon([(44, 150), (60 + zw + 40, 150), (44 + zw + 40, 196), (44, 196)], fill=INK)
d.text((62, 156), zone, font=tag_font, fill=(255, 255, 255))
rarity = spec.get("rarity", "")
rx = 44 + zw + 70
rw = d.textlength(rarity, font=tag_font)
d.polygon([(rx + 12, 150), (rx + rw + 52, 150), (rx + rw + 40, 196), (rx, 196)], outline=INK, width=3)
d.text((rx + 26, 156), rarity, font=tag_font, fill=INK)
d.text((44, 210), "built from the creature kit (Claude)", font=font("arialbd.ttf", 22), fill=(130, 120, 105))

hero = placed("hero", 880, 620)
put(sheet, hero, 470, 260)
label = font("arialbd.ttf", 26)
for name, top, box in (("side", 70, (560, 250)), ("front", 400, (330, 250)), ("top", 720, (560, 200))):
    d.text((960, top + 20), name.upper(), font=label, fill=INK)
    im = placed(name, *box)
    put(sheet, im, 1250, top + 50 + (box[1] - im.height) / 2, with_shadow=(name != "top"))

# the palette, the colours the kit actually used
x = 40
seen = []
for key in ("top", "body", "bars", "eye"):
    c = spec["colours"][key]
    if c in seen:
        continue
    seen.append(c)
    rgb = tuple(int(c.lstrip("#")[i : i + 2], 16) for i in (0, 2, 4))
    d.rectangle((x, 920, x + 86, 1000), fill=rgb)
    x += 104

sheet.convert("RGB").save(out)
print("sheet", out)

if len(sys.argv) > 5:
    concept = Image.open(sys.argv[4]).convert("RGB").resize((W, H), Image.LANCZOS)
    pair = Image.new("RGB", (W * 2 + 24, H + 70), (255, 255, 255))
    pair.paste(concept, (0, 70))
    pair.paste(sheet.convert("RGB"), (W + 24, 70))
    pd = ImageDraw.Draw(pair)
    big = font("ariblk.ttf", 44)
    pd.text((24, 10), "ChatGPT concept", font=big, fill=INK)
    pd.text((W + 48, 10), "Our kit, from the concept's rules", font=big, fill=INK)
    pair = pair.resize((pair.width * 2 // 3, pair.height * 2 // 3), Image.LANCZOS)
    pair.save(sys.argv[5], quality=90)
    print("compare", sys.argv[5])
