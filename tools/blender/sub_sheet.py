"""The comparison sheet of the submarine's style options (plain Python with Pillow, not a Blender script):

    python tools/blender/sub_sheet.py <renders folder> <out.png>

<renders folder>/<A|B|C|D>/ holds what tools/blender/sub_kit.py wrote: hero, side, front, top, ride and stats.txt.
One row an option: its letter and style, the turnaround (hero, side, top, front) and the riding view laid in water."""
import os
import random
import sys

from PIL import Image, ImageDraw, ImageFilter, ImageFont

SRC, OUT = sys.argv[1], sys.argv[2]
STYLES = {
    "A": ("CHUNKY TOY", "fat rounded forms, smooth shaded, thick rims"),
    "B": ("SLEEK FACETED", "flat planes, a pointed nose, swept fins"),
    "C": ("RETRO RIVETED", "a boiler: hoops, rivets, brass rims, a lantern"),
    "D": ("VOXEL (the creatures' style)", "big boxes, turned blocks for slopes, studs on top"),
}
BOLD = "/usr/share/fonts/TTF/DejaVuSans-Bold.ttf"
for cand in (BOLD, "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", "/usr/share/fonts/dejavu/DejaVuSans-Bold.ttf"):
    if os.path.exists(cand):
        BOLD = cand
        break


def font(size):
    try:
        return ImageFont.truetype(BOLD, size)
    except OSError:
        return ImageFont.load_default(size)


INK, SOFT, CREAM = (38, 38, 38), (122, 114, 106), (254, 248, 241)
W, HEAD, ROW = 3200, 190, 700
sheet = Image.new("RGB", (W, HEAD + ROW * len(STYLES) + 30), CREAM)
d = ImageDraw.Draw(sheet)
d.text((50, 26), "RIDE A FISH", font=font(40), fill=INK)
d.text((50, 74), "THE SUBMARINE: FOUR STYLES OF ONE SUB", font=font(72), fill=INK)
d.text((1960, 60), 'tier 1, "The Bathtub": the same hull, tower, seat, ports, wings, fins,', font=font(30), fill=SOFT)
d.text((1960, 100), "propeller and lamp in every row. Pick a style; the other 8 tiers follow it.", font=font(30), fill=SOFT)


def fit(im, w, h):
    box = im.getbbox()
    if box:
        im = im.crop(box)
    k = min(w / im.width, h / im.height)
    return im.resize((max(1, int(im.width * k)), max(1, int(im.height * k))), Image.LANCZOS)


def put(im, x, y, w, h, shadow=True):
    im = fit(im, w, h)
    px, py = x + (w - im.width) // 2, y + (h - im.height) // 2
    if shadow:  # the soft ground shadow of the creature sheets
        sh = Image.new("RGBA", (im.width, 40), (0, 0, 0, 0))
        ImageDraw.Draw(sh).ellipse((im.width * 0.12, 8, im.width * 0.88, 32), fill=(120, 105, 95, 70))
        sh = sh.filter(ImageFilter.GaussianBlur(9))
        sheet.paste(sh, (px, py + im.height - 14), sh)
    sheet.paste(im, (px, py), im)


def water(w, h, seed):
    """a panel of the Shallows' water: bright at the top, shafts of light, bubbles"""
    rnd = random.Random(seed)
    im = Image.new("RGB", (w, h))
    px = im.load()
    top, bot = (126, 226, 240), (38, 150, 205)
    for y in range(h):
        t = (y / h) ** 0.9
        c = tuple(int(top[i] + (bot[i] - top[i]) * t) for i in range(3))
        for x in range(w):
            px[x, y] = c
    rays = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    rd = ImageDraw.Draw(rays)
    for _ in range(7):
        x0, wd = rnd.uniform(-0.1, 1.0) * w, rnd.uniform(30, 110)
        rd.polygon([(x0, -10), (x0 + wd, -10), (x0 + wd * 1.6 - 220, h), (x0 - 260, h)], fill=(255, 255, 255, 26))
    rays = rays.filter(ImageFilter.GaussianBlur(14))
    im.paste(rays, (0, 0), rays)
    return im


def bubbles(im, x, y, seed):
    rnd = random.Random(seed)
    dr = ImageDraw.Draw(im, "RGBA")
    for i in range(26):
        t = rnd.random()
        bx, by = x + t * 230 + rnd.uniform(-20, 20), y - t * 150 + rnd.uniform(-40, 40)
        r = 4 + t * 13 * rnd.uniform(0.5, 1)
        a = int(210 * (1 - t) + 30)
        dr.ellipse((bx - r, by - r, bx + r, by + r), outline=(255, 255, 255, a), width=3, fill=(255, 255, 255, a // 5))


for i, (key, (name, what)) in enumerate(STYLES.items()):
    y = HEAD + i * ROW
    folder = os.path.join(SRC, key)
    stats = open(os.path.join(folder, "stats.txt")).read().split()
    d.line((40, y, W - 40, y), fill=(225, 216, 205), width=3)
    d.rounded_rectangle((50, y + 30, 170, y + 150), 18, fill=INK)
    d.text((110, y + 90), key, font=font(92), fill=CREAM, anchor="mm")
    d.text((200, y + 34), name, font=font(46), fill=INK)
    d.text((200, y + 94), what, font=font(25), fill=SOFT)
    d.text((200, y + 128), f"{int(stats[2]):,} triangles  /  {stats[1]} parts  /  {stats[3]} flat colours", font=font(25), fill=INK)
    load = lambda n: Image.open(os.path.join(folder, n + ".png")).convert("RGBA")
    put(load("hero"), 40, y + 175, 960, 500)
    for label, n, bx, by, bw, bh in (("SIDE", "side", 1050, 40, 600, 290), ("TOP", "top", 1050, 370, 600, 290), ("FRONT", "front", 1700, 150, 380, 420)):
        d.text((bx, y + by - 6), label, font=font(24), fill=INK)
        put(load(n), bx, y + by + 26, bw, bh - 26, shadow=n != "top")
    pw, ph = 1030, 640
    panel = water(pw, ph, i)
    ride = fit(load("ride"), pw - 60, ph - 50)
    rx, ry = (pw - ride.width) // 2 - 40, (ph - ride.height) // 2
    panel.paste(ride, (rx, ry), ride)
    bubbles(panel, rx + int(ride.width * 0.86), ry + int(ride.height * 0.8), i + 10)
    veil = Image.new("RGBA", (pw, ph), (90, 200, 230, 22))  # a little of the water over everything
    panel.paste(veil, (0, 0), veil)
    mask = Image.new("L", (pw, ph), 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, pw, ph), 26, fill=255)
    sheet.paste(panel, (2120, y + 30), mask)
    ImageDraw.Draw(sheet).text((2146, y + 46), "RIDING, IN THE WATER", font=font(24), fill=(255, 255, 255))

os.makedirs(os.path.dirname(os.path.abspath(OUT)), exist_ok=True)
sheet.save(OUT)
print("sub sheet:", OUT, sheet.size)
