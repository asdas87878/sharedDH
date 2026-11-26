"""Draws the icons for the Roblox store: one 512 px PNG per developer product and game pass in src/shared/Products.luau,
named by the offer's Key, in art/ui/store/. Made from the game's own art (the O2 and cash icons, the clam chest, the Great
White's render), in the Shop cards' colours (Products.Looks) and the game's font (Fredoka One). Nothing is generated or
uploaded. Everything sits inside the middle circle, since Roblox shows a game pass's icon cut to a circle.

    python3 tools/ui/store_icons.py            writes art/ui/store/*.png and the sheet docs/attachments/store-icons.png
"""
import glob
import math
import os
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "art" / "ui" / "store"
S = 512
INK = (12, 10, 48)  # the icons' own outline navy

LOOKS = {
    "Gold": ((255, 214, 72), (255, 132, 24)),
    "Sky": ((96, 214, 255), (36, 116, 236)),
    "Lime": ((150, 245, 80), (40, 176, 60)),
    "Sea": ((70, 236, 214), (16, 150, 170)),
}


def font(size: int) -> ImageFont.FreeTypeFont:
    found = sorted(glob.glob(os.path.expanduser("~/.var/app/org.vinegarhq.Vinegar/data/vinegar/versions/*/content/fonts/FredokaOne-Regular.ttf")))
    found += sorted(glob.glob(os.path.expandvars(r"%LOCALAPPDATA%\Roblox\Versions\*\content\fonts\FredokaOne-Regular.ttf")))
    return ImageFont.truetype(found[-1], size)


def trimmed(path: Path) -> Image.Image:
    im = Image.open(path).convert("RGBA")
    return im.crop(im.getchannel("A").getbbox())


def cut_white(path: Path) -> Image.Image:
    """A render on white: the white joined to the corners goes clear."""
    im = Image.open(path).convert("RGBA")
    mask = Image.new("L", im.size, 0)
    rgb = im.convert("RGB")
    seen = Image.new("L", im.size, 0)
    w, h = im.size
    stack = [(0, 0), (w - 1, 0), (0, h - 1), (w - 1, h - 1)]
    px, sp = rgb.load(), seen.load()
    while stack:
        x, y = stack.pop()
        if x < 0 or y < 0 or x >= w or y >= h or sp[x, y]:
            continue
        r, g, b = px[x, y]
        if min(r, g, b) < 235:
            continue
        sp[x, y] = 255
        stack += [(x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)]
    mask = seen.point(lambda v: 0 if v else 255)
    im.putalpha(mask)
    return im.crop(mask.getbbox())


def fit(im: Image.Image, size: int) -> Image.Image:
    k = size / max(im.size)
    return im.resize((max(1, round(im.width * k)), max(1, round(im.height * k))), Image.LANCZOS)


def background(look: str, rays: float) -> Image.Image:
    top, bottom = LOOKS[look]
    bg = Image.new("RGBA", (S, S))
    d = ImageDraw.Draw(bg)
    for y in range(S):
        t = y / (S - 1)
        d.line([(0, y), (S, y)], fill=tuple(round(top[i] + (bottom[i] - top[i]) * t) for i in range(3)) + (255,))
    # a sunburst behind the art, stronger for bigger packs
    burst = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    bd = ImageDraw.Draw(burst)
    c, n = S / 2, 16
    for i in range(n):
        a0 = (i / n) * 2 * math.pi
        a1 = a0 + math.pi / n
        bd.polygon([(c, c - 20), (c + 400 * math.cos(a0), c - 20 + 400 * math.sin(a0)),
                    (c + 400 * math.cos(a1), c - 20 + 400 * math.sin(a1))], fill=(255, 255, 255, round(38 * rays)))
    glow = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    ImageDraw.Draw(glow).ellipse([c - 150, c - 170, c + 150, c + 130], fill=(255, 255, 255, round(110 * rays)))
    glow = glow.filter(ImageFilter.GaussianBlur(60))
    bg.alpha_composite(burst)
    bg.alpha_composite(glow)
    return bg


def shadowed(canvas: Image.Image, im: Image.Image, x: float, y: float) -> None:
    """Pastes im with its centre at x, y and a soft drop shadow."""
    px, py = round(x - im.width / 2), round(y - im.height / 2)
    sh = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    a = im.getchannel("A").point(lambda v: v * 0.35)
    sh.paste((0, 0, 30, 255), (px + 6, py + 10), a)
    canvas.alpha_composite(sh.filter(ImageFilter.GaussianBlur(8)))
    canvas.alpha_composite(im, (px, py))


def label(canvas: Image.Image, text: str, y: float, size: int, fill=(255, 255, 255)) -> None:
    f = font(size)
    d = ImageDraw.Draw(canvas)
    stroke = max(6, size // 7)
    w = d.textlength(text, font=f)
    while w + 2 * stroke > 400:  # inside the circle
        size -= 4
        f, stroke = font(size), max(6, size // 7)
        w = d.textlength(text, font=f)
    sh = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    ImageDraw.Draw(sh).text((S / 2 + 4, y + 8), text, font=f, anchor="mm", fill=INK + (150,), stroke_width=stroke,
                            stroke_fill=INK + (150,))
    canvas.alpha_composite(sh.filter(ImageFilter.GaussianBlur(4)))
    d.text((S / 2, y), text, font=f, anchor="mm", fill=fill, stroke_width=stroke, stroke_fill=INK)


def sparkle(canvas: Image.Image, x: float, y: float, r: float) -> None:
    d = ImageDraw.Draw(canvas)
    pts = []
    for i in range(8):
        a = i * math.pi / 4 - math.pi / 2
        rr = r if i % 2 == 0 else r * 0.28
        pts.append((x + rr * math.cos(a), y + rr * math.sin(a)))
    d.polygon(pts, fill=(255, 255, 255, 235))


# Where the copies of an item go for each tier of a ladder: (x, y, size), drawn back to front, centred in the art area
PILES = [
    [(256, 205, 250)],
    [(196, 215, 200), (316, 195, 200)],
    [(176, 230, 175), (336, 230, 175), (256, 175, 195)],
    [(160, 240, 150), (352, 240, 150), (210, 170, 150), (302, 170, 150), (256, 245, 165)],
]


def ladder(art: Image.Image, tier: int, look: str, text: str, big: Image.Image | None = None) -> Image.Image:
    """Tiers 1 to 4: piles of 1, 2, 3, 5 copies. Tiers 5 and 6: the big piece (or a big pile), with copies round it."""
    rays = 0.35 + 0.13 * tier
    im = background(look, rays)
    if tier <= 4:
        for x, y, s in PILES[tier - 1]:
            shadowed(im, fit(art, s), x, y)
    elif big is not None:
        if tier == 6:
            for x, y, s in [(140, 225, 140), (372, 225, 140)]:
                shadowed(im, fit(art, s), x, y)
        shadowed(im, fit(big, 250 if tier == 5 else 270), 256, 200)
    else:
        # no big piece: a wider pile round one big copy
        ring = [(190, 140, 130), (322, 140, 130), (142, 235, 135), (370, 235, 135), (112, 140, 110), (400, 140, 110)]
        for x, y, s in ring[: 4 if tier == 5 else 6]:
            shadowed(im, fit(art, s), x, y)
        shadowed(im, fit(art, 220 if tier == 5 else 240), 256, 210)
    for i, (x, y, r) in enumerate([(120, 120, 22), (396, 110, 18), (410, 300, 14), (100, 300, 12), (330, 70, 12),
                                   (180, 70, 10)]):
        if i < tier:
            sparkle(im, x, y, r)
    label(im, text, 395, 104)
    return im


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    o2 = trimmed(ROOT / "art/ui/icons_src/o2_user_v2.webp")
    cash = trimmed(ROOT / "art/ui/icons/cash.png")
    chest = trimmed(ROOT / "art/ui/offline/chest.png")
    shark = cut_white(ROOT / "art/ui/fish_icons/renders/GreatWhite.png")
    bubbles = trimmed(ROOT / "art/ui/shop/shop_icons.png").crop((388, 0, 512, 128))
    bubbles = bubbles.crop(bubbles.getchannel("A").getbbox())

    icons: dict[str, Image.Image] = {}
    for tier, text in enumerate(["50K", "500K", "5M", "60M", "800M", "10B"], 1):
        icons[f"Oxygen{tier}"] = ladder(o2, tier, "Sea", text)
    for tier, text in enumerate(["$1M", "$25M", "$1B", "$50B", "$2T", "$75T"], 1):
        icons[f"Cash{tier}"] = ladder(cash, tier, "Lime", text, big=chest)

    # The Great White Pack: the shark, with the O2 and the cash it comes with
    im = background("Gold", 1.0)
    shadowed(im, fit(shark, 370), 262, 200)
    for x, y, r in [(110, 110, 24), (400, 95, 18), (330, 330, 12)]:
        sparkle(im, x, y, r)
    label(im, "PACK", 400, 104)
    icons["Starter"] = im

    # Double Oxygen, the game pass
    im = background("Sky", 0.9)
    shadowed(im, fit(o2, 270), 256, 200)
    for x, y, r in [(110, 120, 22), (405, 115, 18), (400, 290, 12)]:
        sparkle(im, x, y, r)
    label(im, "x2", 395, 130)
    icons["DoubleOxygen"] = im

    # Claim x3 in the Welcome back window
    im = background("Gold", 0.9)
    shadowed(im, fit(chest, 290), 256, 200)
    label(im, "x3", 395, 130)
    icons["OfflineTriple"] = im

    for key, icon in icons.items():
        icon.convert("RGB").save(OUT / f"{key}.png")

    # One sheet of them all, each with the circle a game pass is cut to drawn faintly over a copy
    cols, tile, pad = 5, 256, 16
    keys = list(icons)
    rows = math.ceil(len(keys) / cols)
    sheet = Image.new("RGB", (cols * (tile + pad) + pad, rows * (tile + pad + 26) + pad), (32, 32, 40))
    d = ImageDraw.Draw(sheet)
    for i, key in enumerate(keys):
        x, y = pad + (i % cols) * (tile + pad), pad + (i // cols) * (tile + pad + 26)
        sheet.paste(icons[key].convert("RGB").resize((tile, tile), Image.LANCZOS), (x, y))
        d.ellipse([x, y, x + tile - 1, y + tile - 1], outline=(255, 60, 60), width=1)
        d.text((x + tile / 2, y + tile + 13), key, font=font(18), anchor="mm", fill=(230, 230, 230))
    sheet.save(ROOT / "docs" / "attachments" / "store-icons.png")
    print(f"{len(icons)} icons in {OUT}")


if __name__ == "__main__":
    main()
