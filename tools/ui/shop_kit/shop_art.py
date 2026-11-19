"""The shop kit's pictures (NULLROOM task s1, 2026-11-19): drawn by code, ours, nothing traced.

    ~/.cache/sharedDH-venv/bin/python tools/ui/shop_kit/shop_art.py [--studio]

Writes to art/ui/shop/:
  shop_body.png   - 128x128: the body's pattern (fine bubble dots in a staggered grid, a faint fish-scale arc between)
  shop_head.png   - 128x128: the header's and buttons' pattern (rows of fish scales with a lit fleck)
                    Both white on clear: the game tints them with ImageColor3 and fades them with ImageTransparency,
                    so one picture serves every colour (a tiled picture can't use an image rect, so two files).
  shop_icons.png  - 640x128: five 128 px header icons in the icon pack's rules (one thick ink outline round the
                    silhouette, flat faces lit from the top left, a pale lip, white four-point glints):
                    0 submarine, 1 shell, 2 seahorse, 3 bubble, 4 an arrow
                    pointing right (turned for left and down).
--studio also copies both into Studio's own content folder (rbxasset://textures/ridefish/...), as the other UI tools
do: nothing is uploaded. A live game falls back to an uploaded picture until Shop.Textures hold upload ids.
"""

import math
import shutil
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parents[3]
OUT = ROOT / "art/ui/shop"
SS = 4  # supersampling

INK = (4, 4, 53, 255)
WHITE = (255, 255, 255, 255)


def down(img: Image.Image, size) -> Image.Image:
    return img.resize(size, Image.LANCZOS)


# ---------------------------------------------------------------- the tiles
def body_tile(n=128) -> Image.Image:
    big = n * SS
    img = Image.new("RGBA", (big, big), (255, 255, 255, 0))
    d = ImageDraw.Draw(img)
    step = n // 4  # 32 px cells
    for row in range(5):
        for col in range(5):
            x = (col * step + (step // 2 if row % 2 else 0)) * SS
            y = row * step * SS
            for ox in (-big, 0, big):
                for oy in (-big, 0, big):
                    cx, cy = x + ox, y + oy
                    r = 4.2 * SS
                    # a ring with a lit dot: a tiny bubble
                    d.ellipse((cx - r, cy - r, cx + r, cy + r), outline=(255, 255, 255, 200), width=int(1.3 * SS))
                    s = 1.3 * SS
                    d.ellipse((cx - r * 0.45 - s, cy - r * 0.45 - s, cx - r * 0.45 + s, cy - r * 0.45 + s),
                              fill=(255, 255, 255, 230))
    # faint scale arcs between the bubble rows
    for row in range(5):
        y = (row * step + step // 2) * SS
        for col in range(5):
            x = (col * step + (0 if row % 2 else step // 2)) * SS
            for ox in (-big, 0, big):
                for oy in (-big, 0, big):
                    cx, cy = x + ox, y + oy
                    r = 9 * SS
                    d.arc((cx - r, cy - r, cx + r, cy + r), 200, 340, fill=(255, 255, 255, 90), width=int(1.1 * SS))
    return down(img, (n, n))


def head_tile(n=128) -> Image.Image:
    big = n * SS
    img = Image.new("RGBA", (big, big), (255, 255, 255, 0))
    d = ImageDraw.Draw(img)
    w = n // 4  # four scales across
    h = w // 2
    for row in range(-1, n // h + 2):
        for col in range(-1, 5):
            cx = (col * w + (w // 2 if row % 2 else 0)) * SS
            cy = row * h * SS
            r = w / 2 * SS
            d.arc((cx - r, cy - r, cx + r, cy + r), 0, 180, fill=(255, 255, 255, 210), width=int(2 * SS))
            # a lit fleck on each scale
            fx, fy = cx - r * 0.35, cy + r * 0.35
            s = 1.6 * SS
            d.ellipse((fx - s, fy - s, fx + s, fy + s), fill=(255, 255, 255, 150))
    return down(img, (n, n))


# ---------------------------------------------------------------- the icons
def glint(d, x, y, r):
    d.polygon([(x, y - r), (x + r * 0.28, y - r * 0.28), (x + r, y), (x + r * 0.28, y + r * 0.28), (x, y + r),
               (x - r * 0.28, y + r * 0.28), (x - r, y), (x - r * 0.28, y - r * 0.28)], fill=WHITE)


def outlined(shapes, size, edge):
    """shapes: a function drawing filled silhouettes on a mask draw; returns the ink layer (dilated mask)."""
    mask = Image.new("L", (size, size), 0)
    shapes(ImageDraw.Draw(mask))
    ink = mask.filter(ImageFilter.MaxFilter(edge * 2 + 1))
    layer = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    layer.paste(Image.new("RGBA", (size, size), INK), (0, 0), ink)
    return layer


def icon_sub(n=128) -> Image.Image:
    S = n * SS
    u = S / 128
    edge = int(9 * u)

    def sil(d):
        d.rounded_rectangle((14 * u, 50 * u, 108 * u, 98 * u), radius=24 * u, fill=255)  # hull
        d.rounded_rectangle((46 * u, 30 * u, 80 * u, 60 * u), radius=8 * u, fill=255)  # tower
        d.rectangle((62 * u, 16 * u, 68 * u, 34 * u), fill=255)  # periscope
        d.rectangle((62 * u, 14 * u, 78 * u, 21 * u), fill=255)
        d.polygon([(104 * u, 62 * u), (122 * u, 52 * u), (122 * u, 96 * u), (104 * u, 86 * u)], fill=255)  # tail

    img = outlined(sil, S, edge)
    d = ImageDraw.Draw(img)
    yel, yel_l, yel_d = (255, 206, 48, 255), (255, 236, 130, 255), (222, 140, 20, 255)
    d.rounded_rectangle((14 * u, 50 * u, 108 * u, 98 * u), radius=24 * u, fill=yel_d)
    d.rounded_rectangle((14 * u, 50 * u, 108 * u, 84 * u), radius=22 * u, fill=yel)
    d.rounded_rectangle((26 * u, 54 * u, 96 * u, 62 * u), radius=4 * u, fill=yel_l)  # the pale lip
    d.rounded_rectangle((46 * u, 30 * u, 80 * u, 60 * u), radius=8 * u, fill=yel)
    d.rectangle((46 * u, 30 * u, 80 * u, 36 * u), fill=yel_l)
    d.rectangle((62 * u, 16 * u, 68 * u, 34 * u), fill=(150, 160, 180, 255))
    d.rectangle((62 * u, 14 * u, 78 * u, 21 * u), fill=(150, 160, 180, 255))
    d.polygon([(104 * u, 62 * u), (122 * u, 52 * u), (122 * u, 96 * u), (104 * u, 86 * u)], fill=yel_d)
    for cx in (40, 62, 84):  # portholes
        r = 9 * u
        d.ellipse((cx * u - r - 3 * u, 72 * u - r - 3 * u, cx * u + r + 3 * u, 72 * u + r + 3 * u), fill=INK)
        d.ellipse((cx * u - r, 72 * u - r, cx * u + r, 72 * u + r), fill=(90, 210, 255, 255))
        d.ellipse((cx * u - r * 0.6, 72 * u - r * 0.7, cx * u - r * 0.05, 72 * u - r * 0.15), fill=WHITE)
    glint(d, 30 * u, 50 * u, 9 * u)
    return down(img, (n, n))


def icon_shell(n=128) -> Image.Image:
    S = n * SS
    u = S / 128
    edge = int(9 * u)
    cx, base = 64 * u, 104 * u

    def fan(d, fill, r_out=52):
        d.pieslice((cx - r_out * u, base - r_out * u * 1.55, cx + r_out * u, base + r_out * u * 0.45), 180, 360,
                   fill=fill)

    def sil(d):
        fan(d, 255)
        d.polygon([(cx - 16 * u, base - 4 * u), (cx + 16 * u, base - 4 * u), (cx + 10 * u, base + 14 * u),
                   (cx - 10 * u, base + 14 * u)], fill=255)

    img = outlined(sil, S, edge)
    d = ImageDraw.Draw(img)
    pink, pink_l, pink_d = (255, 128, 160, 255), (255, 200, 214, 255), (210, 70, 112, 255)
    fan(d, pink_d)
    fan(d, pink, 50)
    # ribs: dark lines fanning from the hinge
    for k in range(-3, 4):
        a = math.radians(-90 + k * 22)
        x2 = cx + math.cos(a) * 50 * u
        y2 = (base + 9 * u) + math.sin(a) * 74 * u
        d.line((cx, base + 6 * u, x2, y2), fill=pink_d, width=int(5 * u))
    d.pieslice((cx - 30 * u, base - 74 * u, cx + 30 * u, base - 30 * u), 200, 340, fill=pink_l)
    d.polygon([(cx - 16 * u, base - 4 * u), (cx + 16 * u, base - 4 * u), (cx + 10 * u, base + 14 * u),
               (cx - 10 * u, base + 14 * u)], fill=pink_d)
    glint(d, 46 * u, 46 * u, 9 * u)
    return down(img, (n, n))


def icon_seahorse(n=128) -> Image.Image:
    S = n * SS
    u = S / 128
    edge = int(8 * u)

    def body(d, fill, inset=0.0):
        i = inset * u
        d.ellipse((40 * u + i, 14 * u + i, 76 * u - i, 46 * u - i), fill=fill)  # head
        d.polygon([(70 * u, 24 * u), (100 * u, 30 * u - i * 0.3), (100 * u, 40 * u + i * 0.3), (70 * u, 40 * u)],
                  fill=fill)  # snout
        d.ellipse((34 * u + i, 38 * u + i, 74 * u - i, 86 * u - i), fill=fill)  # belly
        d.ellipse((40 * u + i, 76 * u + i, 66 * u - i, 102 * u - i), fill=fill)  # tail top
        d.arc((26 * u, 86 * u, 62 * u, 120 * u), 270, 180, fill=fill, width=int(max(4, 12 - inset * 1.4) * u))

    def sil(d):
        body(d, 255)
        d.polygon([(34 * u, 30 * u), (44 * u, 10 * u), (52 * u, 26 * u)], fill=255)  # crest
        d.polygon([(30 * u, 56 * u), (14 * u, 50 * u), (20 * u, 70 * u), (34 * u, 68 * u)], fill=255)  # fin

    img = outlined(sil, S, edge)
    d = ImageDraw.Draw(img)
    org, org_l, org_d = (255, 160, 60, 255), (255, 214, 140, 255), (214, 96, 30, 255)
    d.polygon([(34 * u, 30 * u), (44 * u, 10 * u), (52 * u, 26 * u)], fill=org_d)
    d.polygon([(30 * u, 56 * u), (14 * u, 50 * u), (20 * u, 70 * u), (34 * u, 68 * u)], fill=(120, 210, 255, 255))
    body(d, org_d)
    body(d, org, 3)
    d.ellipse((44 * u, 46 * u, 62 * u, 80 * u), fill=org_l)  # the pale belly
    for y in (50, 60, 70):  # belly rings
        d.line((46 * u, y * u, 60 * u, y * u), fill=org_d, width=int(3 * u))
    r = 6 * u
    d.ellipse((58 * u - r, 26 * u - r, 58 * u + r, 26 * u + r), fill=INK)
    d.ellipse((56 * u - 2 * u, 24 * u - 2 * u, 56 * u + 2 * u, 24 * u + 2 * u), fill=WHITE)
    glint(d, 46 * u, 20 * u, 8 * u)
    return down(img, (n, n))


def icon_bubble(n=128) -> Image.Image:
    S = n * SS
    u = S / 128
    edge = int(9 * u)
    spots = [(58, 68, 40), (98, 36, 16), (100, 98, 12)]

    def sil(d):
        for x, y, r in spots:
            d.ellipse(((x - r) * u, (y - r) * u, (x + r) * u, (y + r) * u), fill=255)

    img = outlined(sil, S, edge)
    d = ImageDraw.Draw(img)
    for x, y, r in spots:
        d.ellipse(((x - r) * u, (y - r) * u, (x + r) * u, (y + r) * u), fill=(60, 170, 245, 255))
        d.ellipse(((x - r * 0.92) * u, (y - r * 0.95) * u, (x + r * 0.85) * u, (y + r * 0.6) * u),
                  fill=(150, 228, 255, 255))
        d.ellipse(((x - r * 0.6) * u, (y - r * 0.62) * u, (x - r * 0.1) * u, (y - r * 0.22) * u), fill=WHITE)
    glint(d, 84 * u, 60 * u, 9 * u)
    return down(img, (n, n))


def icon_arrow(n=128) -> Image.Image:
    """A fat arrow pointing right (turned in the game for left and down): white over pale aqua, one ink outline."""
    S = n * SS
    u = S / 128
    edge = int(10 * u)
    pts = [(14, 46), (64, 46), (64, 18), (116, 64), (64, 110), (64, 82), (14, 82)]
    poly = [(x * u, y * u) for x, y in pts]

    def sil(d):
        d.polygon(poly, fill=255)

    img = outlined(sil, S, edge)
    body = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    db = ImageDraw.Draw(body)
    db.polygon(poly, fill=(150, 220, 255, 255))
    top = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    ImageDraw.Draw(top).polygon(poly, fill=WHITE)
    cut = Image.new("L", (S, S), 0)
    ImageDraw.Draw(cut).rectangle((0, 0, S, 66 * u), fill=255)
    body.paste(top, (0, 0), Image.composite(top.getchannel("A"), Image.new("L", (S, S), 0), cut))
    img.alpha_composite(body)
    glint(ImageDraw.Draw(img), 30 * u, 52 * u, 6 * u)
    return down(img, (n, n))


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    tiles = Image.new("RGBA", (256, 128), (0, 0, 0, 0))
    tiles.paste(body_tile(), (0, 0))
    tiles.paste(head_tile(), (128, 0))
    tiles.crop((0, 0, 128, 128)).save(OUT / "shop_body.png")
    tiles.crop((128, 0, 256, 128)).save(OUT / "shop_head.png")
    icons = Image.new("RGBA", (640, 128), (0, 0, 0, 0))
    for i, f in enumerate((icon_sub, icon_shell, icon_seahorse, icon_bubble, icon_arrow)):
        icons.paste(f(), (i * 128, 0))
    icons.save(OUT / "shop_icons.png")
    # a preview on the shop's colours
    prev = Image.new("RGBA", (640, 300), (34, 40, 52, 255))
    for x in range(0, 640, 128):
        for y in range(0, 300, 128):
            prev.alpha_composite(Image.eval(tiles.crop((0, 0, 128, 128)), lambda v: v).copy(), (x, y))
    prev.alpha_composite(icons, (64, 160))
    prev.save(ROOT / "work/shop_art_preview.png") if (ROOT / "work").is_dir() else None
    print("wrote", OUT)
    if "--studio" in sys.argv:
        versions = Path.home() / ".var/app/org.vinegarhq.Vinegar/data/vinegar/versions"
        for version in versions.iterdir():
            if (version / "content").is_dir():
                dest = version / "content/textures/ridefish"
                dest.mkdir(parents=True, exist_ok=True)
                shutil.copy(OUT / "shop_body.png", dest / "shop_body_s1.png")
                shutil.copy(OUT / "shop_head.png", dest / "shop_head_s1.png")
                shutil.copy(OUT / "shop_icons.png", dest / "shop_icons_s1b.png")
                print("copied to", dest)


if __name__ == "__main__":
    main()
