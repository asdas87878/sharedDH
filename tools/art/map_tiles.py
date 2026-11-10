"""The map's own surface tiles (docs/map-state.md), drawn by code like the creatures' (tools/art/creature_tiles.py): the
same grey levels and the same drawing helpers, so the map and the creatures are one look. No image generator.
usage: python tools/art/map_tiles.py            writes art/style/map_tiles/<name>.png and _sheet.jpg (each of the
                                                 map's surfaces in its own colour, the borrowed creature tiles included)
       python tools/art/map_tiles.py --test     lays out tools/blender/map_stud_test.py's renders as
                                                 docs/attachments/map-stud-test.jpg

A tile is a square grey picture that repeats. Mid grey (128) leaves the part's colour alone, lighter lifts it, darker
shades it: colour x (1 + 2 x strength x (grey - 0.5)), the creature kit's formula. The map borrows the creatures' stud,
stud_square, pore, crackle, rivet and brick as they are, and adds only what a map has and a creature hasn't:
  strata  the side of a rock: uneven beds with a lit lip and a shadow under it, a joint here and there
  plank   boards: the side of the dock, posts, crates, a wreck's hull
  deck    boards with square studs on them: the top of anything built that you walk on
One tile is TILE_STUDS studs of map (a creature's tile is one of its cubes, about 0.4 studs)."""
import os
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFont

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from creature_tiles import FACE, GROOVE, LIT, MID, S, SHADOW, SHIFTS, done, new, px, rrect  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
CREATURE = os.path.join(ROOT, "art", "style", "tiles")
OUT = os.path.join(ROOT, "art", "style", "map_tiles")
TEST = os.path.join(OUT, "test")
# the map's in-between greys, taken from the creatures' levels so they move with them
LIP, FOOT, EDGE, WOOD = (FACE + LIT) // 2, (MID + SHADOW) // 2, (MID + LIT) // 2, MID + 6

# studs of map to one tile, as the test picture uses them (the floor's is the open question: 1, 2 or 4)
TILE_STUDS = {"stud": 2, "stud_square": 2, "strata": 8, "plank": 4, "deck": 4, "pore": 4, "crackle": 8, "rivet": 6, "brick": 8}


def bar(d, x0, y0, x1, y1, value):
    """a rectangle that wraps round the tile's edges"""
    for dx, dy in SHIFTS:
        d.rectangle([px(x0 + dx), px(y0 + dy), px(x1 + dx), px(y1 + dy)], fill=value)


def strata():
    """the side of a rock: two beds of uneven height to the tile. Each bed has a lit lip along its top and the shadow of
    the bed above it; a joint cuts each bed once, at a different place, so it reads as big blocks stacked"""
    im, d = new(MID)
    for top, bottom, joint in ((0.0, 0.6, 0.31), (0.6, 1.0, 0.78)):
        bar(d, 0, top, 1, top + 0.035, GROOVE)  # the seam between two beds
        bar(d, 0, top + 0.035, 1, top + 0.085, LIP)  # the lip of this bed, catching the light
        bar(d, 0, bottom - 0.07, 1, bottom, FOOT)  # and the shadow at its foot, under... the next bed's lip overhangs
        bar(d, joint, top + 0.035, joint + 0.03, bottom, GROOVE)
        bar(d, joint + 0.03, top + 0.085, joint + 0.06, bottom - 0.07, EDGE)
    return done(im)


def plank(nails=True):
    """two boards to the tile, running along it: a gap between them, a lit edge, a butt joint in each with two nails"""
    im, d = new(WOOD)
    for top, joint in ((0.0, 0.3), (0.5, 0.8)):
        bar(d, 0, top, 1, top + 0.035, GROOVE)
        bar(d, 0, top + 0.035, 1, top + 0.08, LIP)
        bar(d, joint, top + 0.035, joint + 0.025, top + 0.5, GROOVE)
        for side in (-0.06, 0.085) if nails else ():
            for y in (0.17, 0.37):
                bar(d, joint + side - 0.016, top + y - 0.016, joint + side + 0.016, top + y + 0.016, SHADOW)
    return done(im)


def deck():
    """the plank tile with two square studs on each board (the creatures' square stud, at half its size): a built
    floor. The studs sit clear of the joints"""
    im = plank(nails=False).resize((S, S), Image.NEAREST)
    d = ImageDraw.Draw(im)
    for top, xs in ((0.0, (0.455, 0.955)), (0.5, (0.455, 0.955))):  # a quarter tile clear of each board's joint
        for x in xs:
            y = top + 0.14
            rrect(d, x + 0.017, y + 0.025, x + 0.212, y + 0.22, 0.05, SHADOW)
            rrect(d, x, y, x + 0.195, y + 0.195, 0.05, FACE)
            rrect(d, x + 0.02, y + 0.02, x + 0.145, y + 0.145, 0.035, LIT)
            rrect(d, x + 0.045, y + 0.045, x + 0.17, y + 0.17, 0.035, FACE)
    return done(im)


TILES = {"strata": strata, "plank": plank, "deck": deck}

# the map's surfaces: (label, tile, where the tile comes from, the part's colour in the blockout)
SURFACES = [
    ("sand floor: stud", "stud", CREATURE, (236, 222, 172)),
    ("bank and rock tops: stud", "stud", CREATURE, (214, 196, 150)),
    ("rock sides: strata (new)", "strata", OUT, (150, 140, 120)),
    ("reef rock sides: pore", "pore", CREATURE, (235, 140, 150)),
    ("dock deck, boardwalks: deck (new)", "deck", OUT, (170, 128, 85)),
    ("posts, crates, hull sides: plank (new)", "plank", OUT, (120, 85, 55)),
    ("wreck plating: rivet", "rivet", CREATURE, (120, 110, 100)),
    ("deep rock, vents: crackle", "crackle", CREATURE, (55, 50, 95)),
]


def font(size, bold=True):
    return ImageFont.truetype("C:/Windows/Fonts/arialbd.ttf" if bold else "C:/Windows/Fonts/arial.ttf", size)


def swatch(tile, colour, repeat, strength, cell):
    grey = np.tile(np.asarray(tile, dtype=float), (repeat, repeat)) / 255.0
    shade = 1.0 + 2.0 * strength * (grey - 0.5)
    rgb = np.clip(shade[..., None] * np.array(colour, dtype=float)[None, None, :], 0, 255).astype(np.uint8)
    return Image.fromarray(rgb).resize((cell, cell), Image.LANCZOS)


def tile_sheet():
    os.makedirs(OUT, exist_ok=True)
    for name, draw in TILES.items():
        draw().save(os.path.join(OUT, name + ".png"))
    cols, cell, pad = 4, 300, 16
    rows = (len(SURFACES) + cols - 1) // cols
    sheet = Image.new("RGB", (cols * (cell + pad) + pad, rows * (cell + 44 + pad) + pad), (254, 248, 241))
    d = ImageDraw.Draw(sheet)
    for k, (label, name, folder, colour) in enumerate(SURFACES):
        tile = Image.open(os.path.join(folder, name + ".png")).convert("L")
        x, y = pad + (k % cols) * (cell + pad), pad + (k // cols) * (cell + 44 + pad)
        sheet.paste(swatch(tile, colour, 3, 0.5, cell), (x, y))
        d.text((x + 2, y + cell + 8), label, font=font(17), fill=(40, 40, 40))
    sheet.save(os.path.join(OUT, "_sheet.jpg"), quality=90)
    print("map tiles:", ", ".join(TILES), "->", OUT)


def test_sheet():
    """the Blender renders, laid out: the ride view before and after, the bank close up, the dock, and the floor's stud
    at three sizes"""
    def load(name):
        return Image.open(os.path.join(TEST, name + ".png")).convert("RGB")

    big = [("ride_flat", "The Shallows as the blockout is: flat colour"), ("ride_2", "The same view with the stud look (floor stud: 2 studs)"),
           ("bank_2", "A bank and a sea stack's foot: studs on what looks up, strata on rock sides"), ("dock_2", "The dock: deck boards with square studs, plank sides and posts")]
    small = [("ride_1", "floor stud 1 stud wide (Roblox's classic size)"), ("ride_2", "2 studs (the picture above)"), ("ride_4", "4 studs")]
    w, h, pad, cap = 960, 540, 14, 34
    sw = (2 * w + pad - 2 * pad) // 3
    sh = sw * h // w
    sheet = Image.new("RGB", (2 * w + 3 * pad, 2 * (h + cap) + (sh + cap) + 4 * pad + 46), (254, 248, 241))
    d = ImageDraw.Draw(sheet)
    d.text((pad, 10), "Map stud look, test 1 (2026-11-10): a piece of the Shallows at the Reef Gate. Rendered in Blender, not in Roblox.", font=font(22), fill=(30, 30, 30))
    y0 = 46
    for k, (name, label) in enumerate(big):
        x, y = pad + (k % 2) * (w + pad), y0 + (k // 2) * (h + cap + pad)
        sheet.paste(load(name).resize((w, h), Image.LANCZOS), (x, y))
        d.text((x + 2, y + h + 6), label, font=font(18), fill=(40, 40, 40))
    y = y0 + 2 * (h + cap + pad)
    for k, (name, label) in enumerate(small):
        x = pad + k * (sw + pad)
        im = load(name)
        cw, ch = im.width * 2 // 3, im.height * 2 // 3  # the middle of the view, so the studs can be compared
        left, top = (im.width - cw) // 2, im.height - ch
        sheet.paste(im.crop((left, top, left + cw, top + ch)).resize((sw, sh), Image.LANCZOS), (x, y))
        d.text((x + 2, y + sh + 6), label, font=font(18), fill=(40, 40, 40))
    out = os.path.join(ROOT, "docs", "attachments", "map-stud-test.jpg")
    sheet.save(out, quality=88)
    print(out)


if __name__ == "__main__":
    if "--test" in sys.argv:
        test_sheet()
    else:
        tile_sheet()
