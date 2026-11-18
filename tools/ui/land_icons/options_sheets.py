"""The land strip's option sheets (task s2), each from real Studio captures of the game's own strip code:
    python tools/ui/land_icons/options_sheets.py A B C D E mix
A your best, B you and your metres, C the lock, D a locked land's picture (darkness x saturation, blur), E the line
under the pictures; mix: three combined suggestions, in the game. Writes docs/attachments/land-strip-<X>-1.png (the
mixes: land-strip-mixes-1.png) and copies them to ~/Pictures/ride-a-fish/sheets/.
Needs a Studio playtest with options_client.luau installed (options_capture.py install, then play) and the workspace
attribute LandAtlas pointing at a copy of the atlas Studio can read (atlas.py --studio).
"""
import shutil
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

import icons
import options_capture as cap

ROOT = cap.ROOT
DOCS = ROOT / "docs/attachments"
PICS = Path.home() / "Pictures/ride-a-fish/sheets"
BG = (22, 24, 30)
WHITE = (255, 255, 255)
GREY = (170, 176, 190)
SUN = (255, 210, 63)

# the states each sheet shows (LandStrip.update's arguments)
AHEAD = {"land": 6, "along": 0.5, "metres": 600, "best": 7.4, "bestMetres": 1300}
AT = {"land": 7, "along": 0.42, "metres": 1290, "best": 6.4, "bestMetres": 1280}
EARLY = {"land": 2, "along": 0.6, "metres": 42, "best": 4.4, "bestMetres": 108}
START = {"land": 3, "along": 0.5, "metres": 30, "best": 0, "bestMetres": 0}  # no best line: D is about the pictures

STATE_NAMES = {
    id(AHEAD): "mid-dive, best ahead (Twilight, 600 m; best 1,300 m)",
    id(AT): "setting a new best (Midnight, 1,290 m)",
    id(EARLY): "early in a dive (Coral Reef, 42 m; best 108 m)",
}

FAMILIES = {
    "A": {
        "key": "Best",
        "kit": "Kit.LandBestLook",
        "title": "A · your BEST: the marker and its line",
        "states": (AHEAD, AT),
        "looks": [
            "Yellow dashed line, tag hanging aside (now)",
            "Solid gold bar, tag centred under it",
            "Thin pole flying a gold BEST pennant",
            "No line over the pictures: a gold notch under them",
            "Column of gold light, gold tag",
            "Gold star on the top edge, thin dashes down",
        ],
    },
    "B": {
        "key": "You",
        "kit": "Kit.LandYouLook",
        "title": "B · you: the icon and the metre count",
        "states": (AHEAD, AT),
        "looks": [
            "Your face, the metres on a bar under it (now)",
            "The metres bar beside your face",
            "Pin: face ringed in the land's colour, big metres, no bar",
            "Face and metres in one pill",
            "No face: an arrow in the land's colour",
            "Bigger face in a gold ring, the land's name always shown",
        ],
    },
    "C": {
        "key": "Lock",
        "kit": "Kit.LandLockLook",
        "title": "C · the lock on a land not reached (centred, under the number)",
        "states": (EARLY, AHEAD),
        "looks": [
            "White padlock, ink edge (now's padlock, centred)",
            "Gold padlock",
            "Small padlock on a dark disc",
            "Quiet: see-through white, no ink",
            "Question mark",
            "Keyhole in a white disc",
        ],
    },
    "E": {
        "key": "Line",
        "kit": "Kit.LandLineLook",
        "title": "E · the line under the pictures, and what sits under it",
        "states": (AHEAD, EARLY),
        "looks": [
            "Nothing: the pictures alone, you hang under them (now)",
            "A rail, filled in each land's own colour as you go",
            "A dark tray behind the whole strip",
            "A thin line, a dot at each land's border",
            "A rail: white up to you, gold on to your best",
            "A ruler: a tick each half land",
        ],
    },
}

# D: darkness (Kit.LandLocked.Dark) by saturation (Kit.LandLocked.Saturation)
DARKS = [0.8, 0.62, 0.48, 0.35]
SATS = [0.6, 0.3, 0.15, 0.0]
NOW_D = (0.62, 0.3)

# three suggested mixes: (name, why, options)
MIXES = [
    ("Mix 1 · Clean (Claude's pick)", "Today's look tidied: a solid bar instead of dashes, and a rail that shows how far is left to your best.", {"Best": 2, "You": 1, "Lock": 1, "Line": 5, "Dark": 0.62, "Saturation": 0.3, "Blur": 0}),
    ("Mix 2 · Bold", "Loud and chunky: a pennant, your face in gold, gold locks on a tray, darker softer locked lands.", {"Best": 3, "You": 6, "Lock": 2, "Line": 3, "Dark": 0.48, "Saturation": 0.15, "Blur": 1}),
    ("Mix 3 · Quiet", "Keeps the pictures clear: nothing crosses them, small see-through locks, one pill for you.", {"Best": 4, "You": 4, "Lock": 4, "Line": 4, "Dark": 0.62, "Saturation": 0.15, "Blur": 0}),
]


VERSIONS = Path.home() / ".var/app/org.vinegarhq.Vinegar/data/vinegar/versions"
FREDOKA = sorted(VERSIONS.glob("version-*/content/fonts/FredokaOne-Regular.ttf"))
_fonts = {}


def font(px):
    if px not in _fonts:
        if FREDOKA:
            _fonts[px] = ImageFont.truetype(str(FREDOKA[0]), px)
        else:
            f = icons.font(px)
            try:
                f.set_variation_by_name("Black")
            except Exception:
                pass
            _fonts[px] = f
    return _fonts[px]


def text(d, xy, s, px, fill=WHITE, anchor="la"):
    d.text(xy, s, font=font(px), fill=fill, anchor=anchor)


def header(width, title, lines, height=None):
    h = height or 70 + 26 * len(lines)
    im = Image.new("RGB", (width, h), BG)
    d = ImageDraw.Draw(im)
    text(d, (30, 18), title, 34, SUN)
    for i, line in enumerate(lines):
        text(d, (30, 64 + 26 * i), line, 19, GREY)
    return im


def save(im, name):
    out = DOCS / name
    im.save(out)
    PICS.mkdir(parents=True, exist_ok=True)
    shutil.copy(out, PICS / name)
    print("wrote", out)


# ---------------------------------------------------------------- A, B, C, E
def family(code):
    fam = FAMILIES[code]
    crops = {}
    for half in (0, 1):
        items = []
        for row in range(3):
            k = half * 3 + row + 1
            o = {fam["key"]: k}
            y = 60 + row * 205
            for col, st in enumerate(fam["states"]):
                items.append({"x": col * 650, "y": y, "s": 2, "o": o, "st": st, "k": k, "c": col})
            items.append({"x": 1310, "y": y, "s": 1, "o": o, "st": fam["states"][0], "k": k, "c": 2})
        _, got = cap.grab(f"{code}_{half}", items, wait=2.5)
        for it, im in zip(items, got):
            crops[(it["k"], it["c"])] = im
    W = 40 + 620 + 30 + 620 + 30 + 310 + 40
    ROW = 52 + 200 + 18
    lines = [
        f"Real Studio captures of the game's strip code (LandStrip.luau). Switch: {fam['kit']} = 1 to 6; 1 is today's look.",
        "Left: " + STATE_NAMES[id(fam["states"][0])] + ", 2x.   Middle: " + STATE_NAMES[id(fam["states"][1])] + ", 2x.",
        "Right: the left one at real size (1x, a 1920-wide desktop shows it at about 2x).",
    ]
    head = header(W, fam["title"], lines)
    sheet = Image.new("RGB", (W, head.height + 6 * ROW + 20), BG)
    sheet.paste(head, (0, 0))
    d = ImageDraw.Draw(sheet)
    for k in range(1, 7):
        y = head.height + (k - 1) * ROW
        d.line((30, y + 4, W - 30, y + 4), fill=(48, 52, 64), width=2)
        text(d, (40, y + 14), f"{code}{k}", 28, SUN)
        text(d, (40 + 70, y + 18), fam["looks"][k - 1], 22, WHITE)
        sheet.paste(crops[(k, 0)], (40, y + 52))
        sheet.paste(crops[(k, 1)], (40 + 620 + 30, y + 52))
        sheet.paste(crops[(k, 2)], (40 + 1240 + 60, y + 52 + 50))
    save(sheet, f"land-strip-{code}-1.png")


# ---------------------------------------------------------------- D
def locked():
    TOP = 52  # the strip's tiles inside a holder, before scale
    items = []
    for r, dark in enumerate(DARKS):
        for c, sat in enumerate(SATS):
            n = r * 4 + c
            items.append({"x": (n % 3) * 650, "y": 60 + (n // 3) * 165, "s": 2, "o": {"Dark": dark, "Saturation": sat}, "st": START, "rc": (r, c)})
    for n, it in enumerate(items[12:]):
        it["y"] = 60 + (n // 3) * 165
        it["x"] = (n % 3) * 650
    _, got = cap.grab("D_grid", items[:12], wait=2.5)
    _, got2 = cap.grab("D_grid2", items[12:], wait=2.5)
    grid = {it["rc"]: im.crop((0, 0, 620, TOP * 2)) for it, im in zip(items, got + got2)}
    blurs = []
    for z in range(3):
        blurs.append({"x": 0, "y": 60 + z * 235, "s": 3, "o": {"Blur": z}, "st": START, "z": z})
        blurs.append({"x": 960, "y": 60 + z * 235, "s": 3, "o": {"Blur": z, "Dark": 0.48, "Saturation": 0.15}, "st": START, "z": z + 3})
    _, gotb = cap.grab("D_blur", blurs, wait=2.5)
    blur = {it["z"]: im.crop((0, 0, 930, TOP * 3)) for it, im in zip(blurs, gotb)}

    CW, CH = 620, TOP * 2
    LEFT = 150
    W = LEFT + 4 * (CW + 24) + 30
    lines = [
        "A land not reached is its own picture, desaturated and darkened in the game: the atlas has a grey copy under each",
        "colour picture; the colour one lies over it at the saturation, both are darkened (Kit.LandLocked.Dark, .Saturation).",
        "Land 3 half through, so lands 4 to 10 are locked (the best line left out); 2x. Codes: D<row><column>, e.g. D2b = today's (darkness 0.62,",
        "saturation 0.3). Blur: Roblox cannot blur one picture, so the atlas carries blurred copies (Kit.LandLocked.Blur 0 to 2).",
    ]
    head = header(W, "D · locked lands: darkness x saturation, and blur", lines)
    grid_h = 50 + 4 * (CH + 50)
    blur_h = 60 + 3 * (TOP * 3 + 56)
    sheet = Image.new("RGB", (W, head.height + grid_h + blur_h + 30), BG)
    sheet.paste(head, (0, 0))
    d = ImageDraw.Draw(sheet)
    y0 = head.height + 10
    for c, sat in enumerate(SATS):
        text(d, (LEFT + c * (CW + 24), y0), f"{'abcd'[c]} · saturation {sat:g}", 24, SUN)
    for r, dark in enumerate(DARKS):
        y = y0 + 40 + r * (CH + 50)
        text(d, (20, y + 20), f"{r + 1}", 34, SUN)
        text(d, (20, y + 62), f"dark {dark:g}", 18, GREY)
        for c, sat in enumerate(SATS):
            x = LEFT + c * (CW + 24)
            sheet.paste(grid[(r, c)], (x, y))
            now = (dark, sat) == NOW_D
            text(d, (x, y + CH + 6), f"D{r + 1}{'abcd'[c]}" + ("  (live default)" if now else ""), 19, SUN if now else WHITE)
            if now:
                d.rectangle((x - 4, y - 4, x + CW + 4, y + CH + 4), outline=SUN, width=3)
    y = y0 + grid_h
    d.line((30, y - 10, W - 30, y - 10), fill=(48, 52, 64), width=2)
    text(d, (30, y), "Blur (3x): left at today's D2b, right at D3c", 26, SUN)
    names = ["Z0 · sharp (now)", "Z1 · soft (Blur 1)", "Z2 · very soft (Blur 2)"]
    for z in range(3):
        yy = y + 46 + z * (TOP * 3 + 56)
        text(d, (30, yy), names[z], 22, WHITE)
        sheet.paste(blur[z], (30, yy + 30))
        sheet.paste(blur[z + 3], (30 + 930 + 40, yy + 30))
    save(sheet, "land-strip-D-1.png")


# ---------------------------------------------------------------- mixes
def mixes():
    cap.attrs(Ride=__import__("time").time())
    __import__("time").sleep(6)
    rows = []
    for name, why, o in MIXES:
        items = [
            {"x": 0, "y": 60, "s": 3, "o": o, "st": AHEAD},
            {"x": 0, "y": 380, "s": 3, "o": o, "st": AT},
            {"x": 0, "y": 700, "s": 3, "o": o, "st": EARLY},
        ]
        _, got = cap.grab("mix_" + name[4], items, wait=2.5)
        game_view, _ = cap.grab("mixgame_" + name[4], [{"game": True, "o": o, "st": AHEAD, "x": 0, "y": 0}], back=1, hide=False, wait=3)
        spots = [line.split()[1] for line in cap.log().splitlines() if line.startswith("spot ")]
        sx, _, sw, _ = (int(v) for v in spots[-1].split(",")) if spots else (700, 0, 570, 0)
        spot = (sx, sw)
        rows.append((name, why, o, [g.crop((0, 0, 930, 300)) for g in got], game_view, spot))
    W = 40 + 930 + 40 + 1000 + 40
    lines = [
        "Three of the many ways to combine the sheets' codes; any other mix works the same (each letter is its own switch).",
        "Left: the mix at 3x, mid-dive, setting a new best, and early. Right: in a real playtest over the game, at its real size.",
    ]
    head = header(W, "Example mixes", lines)
    RH = 70 + 3 * 310
    sheet = Image.new("RGB", (W, head.height + 3 * RH + 20), BG)
    sheet.paste(head, (0, 0))
    d = ImageDraw.Draw(sheet)
    for i, (name, why, o, crops, game_view, spot) in enumerate(rows):
        y = head.height + i * RH
        d.line((30, y, W - 30, y), fill=(48, 52, 64), width=2)
        codes = f"A{o['Best']} B{o['You']} C{o['Lock']} E{o['Line']} D{DARKS.index(o['Dark']) + 1}{'abcd'[SATS.index(o['Saturation'])]} Z{o['Blur']}"
        text(d, (40, y + 12), name, 30, SUN)
        text(d, (40 + d.textlength(name, font=font(30)) + 30, y + 16), codes, 26, WHITE)
        if why:
            text(d, (40, y + 50), why, 19, GREY)
        for k, c in enumerate(crops):
            sheet.paste(c, (40, y + 80 + k * 310))
        g = game_view.resize((1000, round(1000 * game_view.height / game_view.width)), Image.LANCZOS)
        sheet.paste(g, (40 + 930 + 40, y + 80))
        # the strip itself out of that frame, at its real size (no scaling)
        sx, sw = spot
        close = game_view.crop((max(sx - 30, 0), 0, min(sx + sw + 30, game_view.width), 190))
        text(d, (40 + 930 + 40, y + 80 + g.height + 14), "The strip in that frame, real size (1:1 pixels):", 19, GREY)
        sheet.paste(close, (40 + 930 + 40, y + 80 + g.height + 44))
    save(sheet, "land-strip-mixes-1.png")


if __name__ == "__main__":
    for what in sys.argv[1:]:
        if what in FAMILIES:
            family(what)
        elif what == "D":
            locked()
        elif what == "mix":
            mixes()
