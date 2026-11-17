"""Land-strip icon treatments (task u1, options only): each land's tile filled with a capture of that land.
    python tools/ui/land_icons/icons.py            builds docs/attachments/land-icons/icons/<code>/... and the sheets
Pictures: docs/attachments/land-icons/land<NN><letter>.png (a capture of the game's view, see shots.md). Which picture
and which part of it each land uses: picks.json beside this file ({"1": ["b", cx, cy, side]}, cx/cy/side as shares of
the picture; side of its height).
An icon is drawn at SS times its size and shrunk, so its edges are smooth at the real 28-ish GUI pixels.
"""
import json
import math
from pathlib import Path

from PIL import Image, ImageDraw, ImageEnhance, ImageFilter, ImageFont, ImageOps

ROOT = Path(__file__).resolve().parents[3]
import os
SHOTS = Path(os.environ.get("LAND_SHOTS", ROOT / "docs" / "attachments" / "land-icons"))
HERE = Path(__file__).resolve().parent
SS = 6

INK = (16, 36, 63)
DEEP = (10, 24, 44)
NAVY = (24, 52, 92)
WHITE = (255, 255, 255)
SUN = (255, 210, 63)
GOOD = (141, 240, 106)
# Kit.Lands: the map's colour for each land
LANDS = [(242, 214, 128), (244, 148, 152), (120, 172, 92), (160, 148, 124), (90, 124, 176),
         (104, 96, 170), (62, 66, 120), (120, 72, 64), (150, 150, 168), (110, 44, 60)]
SHORT = ["Shallows", "Reef", "Kelp", "Wrecks", "Blue", "Twilight", "Midnight", "Vents", "Bones", "Under"]
NAMES = ["Shallows", "Coral Reef", "Kelp Forest", "Shipwrecks", "Open Blue", "Twilight", "Midnight", "Vents",
         "Bone Graveyard", "The Underworld"]
# where each land starts on the depth gauge (src/shared/Zones.luau, the fallback list; the map's own may differ)
METRES = [0, 10, 40, 80, 150, 200, 1000, 2000, 4000, 6000]
FONT_PATHS = [
    "/home/hugo/.var/app/org.vinegarhq.Vinegar/data/vinegar/versions/version-63eb6055af4e4688/content/fonts/FredokaOne-Regular.ttf",
    "/home/hugo/.local/share/fonts/rice/snowfall/Nunito[wght].ttf",
]


def font(px):
    for p in FONT_PATHS:
        if Path(p).exists():
            return ImageFont.truetype(p, max(1, round(px)))
    return ImageFont.load_default()


def mix(a, b, t):
    return tuple(round(a[i] + (b[i] - a[i]) * t) for i in range(3))


def darker(c, t):
    return mix(c, (0, 0, 0), t)


def lighter(c, t):
    return mix(c, (255, 255, 255), t)


# ---------- the picture ----------
_pics = {}


def picks():
    p = HERE / "picks.json"
    return json.loads(p.read_text()) if p.exists() else {}


def picture(land, w, h, pick=None):
    """The land's picture cropped to w:h about its focus, punched up (colour, contrast) so it survives 28 px."""
    choice = pick or picks().get(str(land), ["a", 0.5, 0.5, 0.8])
    letter, cx, cy, side = choice
    path = SHOTS / f"land{land:02d}{letter}.png"
    if path not in _pics:
        _pics[path] = Image.open(path).convert("RGB")
    src = _pics[path]
    ch = side * src.height
    cw = ch * w / h
    x0 = min(max(cx * src.width - cw / 2, 0), src.width - cw)
    y0 = min(max(cy * src.height - ch / 2, 0), src.height - ch)
    im = src.crop((round(x0), round(y0), round(x0 + cw), round(y0 + ch)))
    # punch at a middle size first (so the boost works on shapes, not on pixels), then up to the drawing size
    mid = im.resize((max(8, w // SS * 2), max(8, h // SS * 2)), Image.LANCZOS)
    mid = ImageOps.autocontrast(mid, cutoff=1)
    mid = ImageEnhance.Color(mid).enhance(1.5)
    mid = ImageEnhance.Contrast(mid).enhance(1.25)
    mid = mid.filter(ImageFilter.UnsharpMask(radius=1.2, percent=90, threshold=2))
    return mid.resize((w, h), Image.BICUBIC)


def state_picture(pic, state):
    if state == "locked":
        g = ImageOps.grayscale(pic).convert("RGB")
        g = ImageEnhance.Brightness(g).enhance(0.55)
        tint = Image.new("RGB", pic.size, (30, 44, 74))
        return Image.blend(g, tint, 0.45)
    return pic


# ---------- shapes ----------
def rr_mask(size, box, r):
    m = Image.new("L", size, 0)
    ImageDraw.Draw(m).rounded_rectangle(box, r, fill=255)
    return m


def poly_mask(size, pts):
    m = Image.new("L", size, 0)
    ImageDraw.Draw(m).polygon(pts, fill=255)
    return m


def hexagon(cx, cy, r):
    return [(cx + r * math.cos(math.radians(a)), cy + r * math.sin(math.radians(a))) for a in range(-90, 270, 60)]


def text_outlined(d, xy, s, px, fill=WHITE, stroke=INK, anchor="mm", sw=None):
    sw = sw if sw is not None else max(1, round(px * 0.16))
    d.text(xy, s, font=font(px), fill=fill, stroke_width=sw, stroke_fill=stroke, anchor=anchor)


def lock_glyph(im, cx, cy, u):
    """A small padlock, u = the size of one GUI pixel in this drawing."""
    d = ImageDraw.Draw(im)
    w, h = 9 * u, 7 * u
    d.rounded_rectangle((cx - w / 2 - 3 * u / 2, cy - 5 * u - u, cx + w / 2 + 3 * u / 2, cy + h / 2 + u), 2 * u, fill=None)
    # the shackle
    d.arc((cx - 3.6 * u, cy - 8.2 * u, cx + 3.6 * u, cy - 0.5 * u), 180, 360, fill=INK, width=round(3.4 * u))
    d.arc((cx - 3.6 * u, cy - 8.2 * u, cx + 3.6 * u, cy - 0.5 * u), 180, 360, fill=WHITE, width=round(1.6 * u))
    d.line((cx - 2.8 * u, cy - 4.3 * u, cx - 2.8 * u, cy - 1 * u), fill=WHITE, width=round(1.6 * u))
    d.line((cx + 2.8 * u, cy - 4.3 * u, cx + 2.8 * u, cy - 1 * u), fill=WHITE, width=round(1.6 * u))
    d.rounded_rectangle((cx - w / 2, cy - 2 * u, cx + w / 2, cy - 2 * u + h), 1.5 * u, fill=WHITE, outline=INK, width=round(1.2 * u))
    d.rectangle((cx - 0.6 * u, cy + 0.2 * u, cx + 0.6 * u, cy + 2.6 * u), fill=INK)


def check_glyph(im, cx, cy, u, r=4.6):
    d = ImageDraw.Draw(im)
    d.ellipse((cx - r * u, cy - r * u, cx + r * u, cy + r * u), fill=(60, 190, 70), outline=INK, width=round(1.2 * u))
    pts = [(cx - 2.2 * u, cy + 0.1 * u), (cx - 0.6 * u, cy + 1.7 * u), (cx + 2.4 * u, cy - 1.6 * u)]
    d.line(pts, fill=WHITE, width=round(1.5 * u), joint="curve")


def finish(big, scale):
    """Shrink the SS drawing to the shown size."""
    w, h = big.size
    out = big.resize((round(w / SS), round(h / SS)), Image.LANCZOS)
    return out


# ---------- the treatments ----------
# Each returns an RGBA image at `scale` (1 = real GUI pixels). Size in GUI pixels is in SIZES, with the room the
# current tile may grow into (`pop`).
SIZES = {"A": (28, 28), "B": (30, 30), "C": (28, 34), "D": (30, 32), "E": (44, 24), "F": (30, 30)}
GAPS = {"A": 2, "B": 1, "C": 2, "D": -1, "E": 2, "F": 1}
POP = {"A": 1.18, "B": 1.2, "C": 1.18, "D": 1.18, "E": 1.12, "F": 1.18}


def canvas(code, scale):
    w, h = SIZES[code]
    u = scale * SS
    pad = round(6 * u)
    return Image.new("RGBA", (round(w * u) + 2 * pad, round(h * u) + 2 * pad), (0, 0, 0, 0)), u, pad


def draw_A(land, state, scale, pick=None):
    """Framed square: rounded square, thick dark outline, a band of the land's colour, the picture; the number."""
    im, u, p = canvas("A", scale)
    w, h = SIZES["A"]
    col = LANDS[land - 1]
    d = ImageDraw.Draw(im)
    box = (p, p, p + w * u, p + h * u)
    ring = WHITE if state == "current" else (col if state == "done" else (96, 104, 124))
    d.rounded_rectangle(box, 6 * u, fill=INK)
    d.rounded_rectangle((box[0] + 2 * u, box[1] + 2 * u, box[2] - 2 * u, box[3] - 2 * u), 4.5 * u, fill=ring)
    inner = (round(box[0] + 4 * u), round(box[1] + 4 * u), round(box[2] - 4 * u), round(box[3] - 4 * u))
    pic = state_picture(picture(land, inner[2] - inner[0], inner[3] - inner[1], pick), state)
    im.paste(pic, inner[:2], rr_mask(pic.size, (0, 0, pic.size[0] - 1, pic.size[1] - 1), 3 * u))
    # a pale shine on the top edge
    d.line((inner[0] + 3 * u, inner[1] + 1 * u, inner[2] - 3 * u, inner[1] + 1 * u), fill=(255, 255, 255, 120), width=round(1.2 * u))
    marks(im, d, land, state, u, box)
    return finish(im, scale)


def marks(im, d, land, state, u, box, num_at=None, lock_at=None, check_at=None):
    """The number (bottom left), and the lock or the tick."""
    x0, y0, x1, y1 = box
    nx, ny = num_at or (x0 + 6.5 * u, y1 - 6.5 * u)
    text_outlined(d, (nx, ny), str(land), 9.5 * u, fill=WHITE if state != "locked" else (200, 206, 220), sw=round(1.6 * u))
    if state == "locked":
        lx, ly = lock_at or ((x0 + x1) / 2, (y0 + y1) / 2)
        lock_glyph(im, lx, ly, u)
    elif state == "done":
        cx, cy = check_at or (x1 - 3 * u, y0 + 3 * u)
        check_glyph(im, cx, cy, u)


def draw_B(land, state, scale, pick=None):
    """Round badge: the picture in a disc, a thick ring in the land's colour, the dark outline."""
    im, u, p = canvas("B", scale)
    w, h = SIZES["B"]
    col = LANDS[land - 1]
    d = ImageDraw.Draw(im)
    box = (p, p, p + w * u, p + h * u)
    d.ellipse(box, fill=INK)
    ring = WHITE if state == "current" else (col if state == "done" else (96, 104, 124))
    d.ellipse((box[0] + 2 * u, box[1] + 2 * u, box[2] - 2 * u, box[3] - 2 * u), fill=ring)
    if state != "locked":
        # the ring's lower half a step darker: a rim with a little depth
        d.chord((box[0] + 2 * u, box[1] + 2 * u, box[2] - 2 * u, box[3] - 2 * u), 20, 160, fill=darker(ring, 0.22))
    inner = (round(box[0] + 5 * u), round(box[1] + 5 * u), round(box[2] - 5 * u), round(box[3] - 5 * u))
    pic = state_picture(picture(land, inner[2] - inner[0], inner[3] - inner[1], pick), state)
    m = Image.new("L", pic.size, 0)
    ImageDraw.Draw(m).ellipse((0, 0, pic.size[0] - 1, pic.size[1] - 1), fill=255)
    im.paste(pic, inner[:2], m)
    d.ellipse(inner, outline=INK, width=round(1 * u))
    marks(im, d, land, state, u, box, num_at=(box[0] + 5 * u, box[3] - 5 * u), check_at=(box[2] - 4 * u, box[1] + 4 * u))
    return finish(im, scale)


def draw_C(land, state, scale, pick=None):
    """Tilted card: a white photo card, the picture, a ribbon in the land's colour with the land's short name."""
    w, h = SIZES["C"]
    u = scale * SS
    flat = Image.new("RGBA", (round(w * u), round(h * u)), (0, 0, 0, 0))
    d = ImageDraw.Draw(flat)
    col = LANDS[land - 1]
    card = (245, 242, 232) if state != "locked" else (150, 156, 170)
    d.rounded_rectangle((0, 0, w * u - 1, h * u - 1), 3 * u, fill=INK)
    d.rounded_rectangle((1.6 * u, 1.6 * u, w * u - 1.6 * u, h * u - 1.6 * u), 2 * u, fill=card)
    inner = (round(3.5 * u), round(3.5 * u), round(w * u - 3.5 * u), round(24 * u))
    pic = state_picture(picture(land, inner[2] - inner[0], inner[3] - inner[1], pick), state)
    flat.paste(pic, inner[:2])
    d.rectangle(inner, outline=INK, width=round(0.8 * u))
    # the ribbon across the card's foot, wider than the card, its ends folded
    rib = col if state != "locked" else (100, 108, 128)
    ry0, ry1 = 23 * u, 31 * u
    d.rectangle((0.8 * u, ry0, w * u - 0.8 * u, ry1), fill=rib, outline=INK, width=round(1 * u))
    name = SHORT[land - 1]
    px = 6.6 if len(name) <= 6 else (5.6 if len(name) <= 7 else 5.0)
    text_outlined(d, (w * u / 2, (ry0 + ry1) / 2), name.upper(), px * u, sw=round(1.1 * u))
    if state == "locked":
        lock_glyph(flat, w * u / 2, 13.5 * u, u)
    elif state == "done":
        check_glyph(flat, w * u - 4.5 * u, 4.5 * u, u)
    if state == "current":
        glow = Image.new("RGBA", flat.size, (0, 0, 0, 0))
        ImageDraw.Draw(glow).rounded_rectangle((0, 0, w * u - 1, h * u - 1), 3 * u, outline=WHITE, width=round(2 * u))
        flat = Image.alpha_composite(flat, glow)
    angle = 0 if state == "current" else (5 if land % 2 else -5)
    rot = flat.rotate(angle, resample=Image.BICUBIC, expand=True)
    im, _, p = canvas("C", scale)
    im.alpha_composite(rot, ((im.width - rot.width) // 2, (im.height - rot.height) // 2))
    return finish(im, scale)


def draw_D(land, state, scale, pick=None):
    """Stud hex: a hexagon tile with the HUD kit's bevel (light top, dark foot) in the land's colour, two studs."""
    im, u, p = canvas("D", scale)
    w, h = SIZES["D"]
    col = LANDS[land - 1] if state != "locked" else (110, 118, 138)
    if state == "current":
        col = lighter(col, 0.25)
    d = ImageDraw.Draw(im)
    cx, cy = p + w * u / 2, p + h * u / 2
    R = h * u / 2
    d.polygon(hexagon(cx, cy, R), fill=INK)
    # the bevel: the upper half lighter, the lower darker, the face between
    rim = hexagon(cx, cy, R - 1.6 * u)
    top = Image.new("L", im.size, 0)
    ImageDraw.Draw(top).rectangle((0, 0, im.width, cy), fill=255)
    rimmask = poly_mask(im.size, rim)
    im.paste(Image.new("RGBA", im.size, darker(col, 0.3) + (255,)), (0, 0), rimmask)
    up = Image.new("L", im.size, 0)
    up.paste(rimmask, (0, 0), top)
    im.paste(Image.new("RGBA", im.size, lighter(col, 0.35) + (255,)), (0, 0), up)
    face = hexagon(cx, cy, R - 3.4 * u)
    im.paste(Image.new("RGBA", im.size, col + (255,)), (0, 0), poly_mask(im.size, face))
    if state == "current":
        d.polygon(hexagon(cx, cy, R - 0.4 * u), outline=WHITE, width=round(1.6 * u))
    inner = hexagon(cx, cy, R - 5 * u)
    xs, ys = [q[0] for q in inner], [q[1] for q in inner]
    bb = (round(min(xs)), round(min(ys)), round(max(xs)), round(max(ys)))
    pic = state_picture(picture(land, bb[2] - bb[0], bb[3] - bb[1], pick), state)
    m = poly_mask(pic.size, [(x - bb[0], y - bb[1]) for x, y in inner])
    im.paste(pic, bb[:2], m)
    d.polygon(inner, outline=INK, width=round(0.9 * u))
    # two round studs on the rim, upper left and upper right (the map's own stud, small)
    for sx in (-1, 1):
        x, y = cx + sx * (R - 2.6 * u) * math.cos(math.radians(30)), cy - (R - 2.6 * u) * 0.5
        rr = 1.2 * u
        d.ellipse((x - rr, y - rr, x + rr, y + rr), fill=lighter(col, 0.55), outline=darker(col, 0.35), width=max(1, round(0.5 * u)))
    marks(im, d, land, state, u, (cx - R * 0.87, cy - R, cx + R * 0.87, cy + R),
          num_at=(cx, cy + R - 5.5 * u), lock_at=(cx, cy - 1 * u), check_at=(cx + R * 0.62, cy - R * 0.62))
    return finish(im, scale)


def draw_E(land, state, scale, pick=None):
    """Wide banner chip: the picture fills a wide chip; a tab in the land's colour holds the number; the depth below."""
    im, u, p = canvas("E", scale)
    w, h = SIZES["E"]
    col = LANDS[land - 1] if state != "locked" else (100, 108, 128)
    d = ImageDraw.Draw(im)
    box = (p, p, p + w * u, p + h * u)
    d.rounded_rectangle(box, 6 * u, fill=INK)
    edge = WHITE if state == "current" else col
    d.rounded_rectangle((box[0] + 1.6 * u, box[1] + 1.6 * u, box[2] - 1.6 * u, box[3] - 1.6 * u), 5 * u, fill=edge)
    inner = (round(box[0] + 3.4 * u), round(box[1] + 3.4 * u), round(box[2] - 3.4 * u), round(box[3] - 3.4 * u))
    pic = state_picture(picture(land, inner[2] - inner[0], inner[3] - inner[1], pick), state)
    im.paste(pic, inner[:2], rr_mask(pic.size, (0, 0, pic.size[0] - 1, pic.size[1] - 1), 3.5 * u))
    # the tab: a slanted block in the land's colour on the left with the number
    tab = [(inner[0], inner[1]), (inner[0] + 12 * u, inner[1]), (inner[0] + 9 * u, inner[3]), (inner[0], inner[3])]
    tm = poly_mask(im.size, tab)
    clip = rr_mask(im.size, inner, 3.5 * u)
    tm = Image.composite(tm, Image.new("L", im.size, 0), clip)
    im.paste(Image.new("RGBA", im.size, darker(col, 0.25) + (255,)), (0, 0), tm)
    d.line((tab[1], tab[2]), fill=INK, width=round(1 * u))
    text_outlined(d, (inner[0] + 5.2 * u, (inner[1] + inner[3]) / 2), str(land), 10.5 * u, sw=round(1.6 * u))
    # the depth where the land starts, bottom right on a dark pill
    s = f"{METRES[land - 1]:,} m"
    f = font(6.4 * u)
    tw = d.textlength(s, font=f)
    pr = (inner[2] - tw - 4 * u, inner[3] - 8 * u, inner[2] - 0.5 * u, inner[3] - 0.5 * u)
    d.rounded_rectangle(pr, 3.5 * u, fill=DEEP + (210,))
    d.text(((pr[0] + pr[2]) / 2, (pr[1] + pr[3]) / 2), s, font=f, fill=SUN if state != "locked" else (170, 176, 190), anchor="mm")
    if state == "locked":
        lock_glyph(im, (inner[0] + 12 * u + inner[2]) / 2 - 5 * u, inner[1] + 9 * u, u)
    elif state == "done":
        check_glyph(im, box[2] - 3 * u, box[1] + 3 * u, u)
    return finish(im, scale)


def draw_F(land, state, scale, pick=None):
    """Name cap: a square with a thick border in the land's colour and the land's name across its top (the genre's
    own way of telling lands), the picture under it."""
    im, u, p = canvas("F", scale)
    w, h = SIZES["F"]
    col = LANDS[land - 1] if state != "locked" else (100, 108, 128)
    d = ImageDraw.Draw(im)
    box = (p, p, p + w * u, p + h * u)
    d.rounded_rectangle(box, 4 * u, fill=INK)
    edge = WHITE if state == "current" else col
    d.rounded_rectangle((box[0] + 1.4 * u, box[1] + 1.4 * u, box[2] - 1.4 * u, box[3] - 1.4 * u), 3 * u, fill=edge)
    inner = (round(box[0] + 3.4 * u), round(box[1] + 3.4 * u), round(box[2] - 3.4 * u), round(box[3] - 3.4 * u))
    pic = state_picture(picture(land, inner[2] - inner[0], inner[3] - inner[1], pick), state)
    im.paste(pic, inner[:2])
    cap = (inner[0], inner[1], inner[2], inner[1] + 8.5 * u)
    d.rectangle(cap, fill=darker(col, 0.35) + (235,))
    d.line((cap[0], cap[3], cap[2], cap[3]), fill=INK, width=round(0.8 * u))
    name = SHORT[land - 1].upper()
    px = 6.4 if len(name) <= 6 else 5.0
    text_outlined(d, ((cap[0] + cap[2]) / 2, (cap[1] + cap[3]) / 2 + 0.3 * u), name, px * u, sw=round(1.1 * u))
    marks(im, d, land, state, u, box, num_at=(box[0] + 7 * u, box[3] - 7 * u), lock_at=((box[0] + box[2]) / 2, (box[1] + box[3]) / 2 + 3.5 * u),
          check_at=(box[2] - 4 * u, box[3] - 4 * u))
    return finish(im, scale)


DRAW = {"A": draw_A, "B": draw_B, "C": draw_C, "D": draw_D, "E": draw_E, "F": draw_F}
TITLES = {
    "A": "Framed square: thick dark outline, a band of the land's colour (white on the land you're in)",
    "B": "Round badge: the picture in a disc, a ring in the land's colour",
    "C": "Tilted photo card: white card, the land's name on a ribbon, cards lean left and right",
    "D": "Stud hex: hexagon tiles with the HUD's bevel and two map studs on the rim",
    "E": "Wide chip: a wide picture, the number on a slanted tab, the depth the land starts at",
    "F": "Name cap: the land's name across the top of each picture (the genre's usual way)",
}


def icon(code, land, state, scale=1, pick=None):
    img = DRAW[code](land, state, scale, pick)
    return img


def pad_of(code, scale):
    return round(6 * scale)


def strip(code, current, scale=1, picks_override=None):
    """The ten in a row: lands before `current` done, `current` current, after locked. The current one a size up."""
    w, h = SIZES[code]
    gap = GAPS[code]
    pad = pad_of(code, scale)
    step = (w + gap) * scale
    total_w = round(10 * w * scale + 9 * gap * scale) + 2 * pad + round(w * scale)
    out = Image.new("RGBA", (total_w, round(h * scale * POP[code]) + 2 * pad + 4), (0, 0, 0, 0))
    cy = out.height // 2
    later = []
    for i in range(1, 11):
        st = "done" if i < current else ("current" if i == current else "locked")
        im = icon(code, i, st, scale, (picks_override or {}).get(i))
        x = round(pad + (i - 1) * step + w * scale / 2) + round(w * scale / 2)
        if st == "current":
            big = im.resize((round(im.width * POP[code]), round(im.height * POP[code])), Image.LANCZOS)
            later.append((big, x, cy))
        else:
            out.alpha_composite(im, (x - im.width // 2, cy - im.height // 2))
    for big, x, y in later:
        out.alpha_composite(big, (x - big.width // 2, y - big.height // 2))
    return out.crop(out.getbbox())
