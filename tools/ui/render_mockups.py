"""Draws the HUD mock-ups for docs/design/ui.md: runs tools/ui/mockups.html through headless Chrome, one frame a
state, and lays the frames out as sheets in docs/attachments/ui-*.png. Nothing here is game code, and nothing is
uploaded or generated: the pictures are drawn by the page's own code with Roblox's built-in fonts.

    python tools/ui/render_mockups.py            every sheet
    python tools/ui/render_mockups.py phone      only sheets whose name has "phone" in it
"""
import glob
import os
import subprocess
import sys
import tempfile
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[2]
PAGE = ROOT / "tools" / "ui" / "mockups.html"
OUT = ROOT / "docs" / "attachments"
WORK = Path(tempfile.gettempdir()) / "rideafish_ui_mockups"

CHROME = [p for p in (r"C:\Program Files\Google\Chrome\Application\chrome.exe",
                      r"C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe") if os.path.exists(p)]
FONT_DIRS = sorted(glob.glob(os.path.expandvars(r"%LOCALAPPDATA%\Roblox\Versions\*\content\fonts")),
                   key=os.path.getmtime)

PHONE = (844, 390, 2, 1)  # width, height, pixels per point when drawn, touch
DESK = (1920, 1080, 1, 0)


def sprites():
    """small see-through pictures of the creatures for the mock-ups' tiles, cut from the creature chat's previews
    (work/voxel, not kept in the repo): the three-quarter view, its plain background keyed out"""
    out = WORK / "sprites"
    out.mkdir(parents=True, exist_ok=True)
    for src in glob.glob(str(ROOT / "work" / "voxel" / "*_preview.png")):
        name = os.path.basename(src)[:-len("_preview.png")]
        dst = out / (name + ".png")
        if dst.exists():
            continue
        im = Image.open(src).convert("RGB").crop((0, 0, 690, 470))
        bg = Image.new("RGB", im.size, im.getpixel((4, 4)))
        diff = ImageChops.difference(im, bg).convert("L")
        alpha = diff.point(lambda v: 0 if v < 10 else min(255, (v - 10) * 12))
        box = alpha.getbbox()
        if not box:
            continue
        cut = im.convert("RGBA")
        cut.putalpha(alpha)
        cut = cut.crop(box)
        cut.thumbnail((320, 320), Image.LANCZOS)
        cut.save(dst)
    return out


def frame(state, skin, size):
    """one state drawn to a PNG; returns the image"""
    w, h, dpr, touch = size
    WORK.mkdir(exist_ok=True)
    png = WORK / f"{state}-{skin.replace('&', '_').replace('=', '_')}-{w}.png"
    fonts = Path(FONT_DIRS[-1]).as_uri() if FONT_DIRS else ""
    url = f"{PAGE.as_uri()}?state={state}&skin={skin}&w={w}&h={h}&touch={touch}&fonts={fonts}&sprites={sprites().as_uri()}"
    subprocess.run([CHROME[0], "--headless=new", "--disable-gpu", "--hide-scrollbars", "--allow-file-access-from-files",
                    f"--force-device-scale-factor={dpr}", f"--window-size={w},{h}", "--virtual-time-budget=3000",
                    f"--screenshot={png}", url], check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    return Image.open(png).convert("RGB")


def font(size, bold=True):
    return ImageFont.truetype(r"C:\Windows\Fonts\arialbd.ttf" if bold else r"C:\Windows\Fonts\arial.ttf", size)


def sheet(name, title, cells, columns, cell_width, notes=None):
    """cells: (caption, state, skin, size). Each frame is scaled to cell_width; captions sit under the frames"""
    pad, cap = 18, 34
    images = []
    for caption, state, skin, size in cells:
        im = frame(state, skin, size)
        im = im.resize((cell_width, round(im.height * cell_width / im.width)), Image.LANCZOS)
        images.append((caption, im))
    rows = [images[i:i + columns] for i in range(0, len(images), columns)]
    width = pad + columns * (cell_width + pad)
    note_h = (len(notes) * 24 + 12) if notes else 0
    height = 58 + sum(max(im.height for _, im in row) + cap + pad for row in rows) + note_h
    out = Image.new("RGB", (width, height), (252, 248, 240))
    d = ImageDraw.Draw(out)
    d.text((pad, 16), title, font=font(24), fill=(20, 30, 50))
    y = 58
    for row in rows:
        row_h = max(im.height for _, im in row)
        for i, (caption, im) in enumerate(row):
            x = pad + i * (cell_width + pad)
            out.paste(im, (x, y))
            d.rectangle([x - 1, y - 1, x + im.width, y + im.height], outline=(20, 30, 50), width=2)
            d.text((x, y + row_h + 7), caption, font=font(17), fill=(20, 30, 50))
        y += row_h + cap + pad
    for i, line in enumerate(notes or []):
        d.text((pad, y + i * 24), line, font=font(16, False), fill=(20, 30, 50))
    if name.endswith(".jpg"):  # the big pass-2 sheets: a tenth of the size, colours kept
        out.save(OUT / name, quality=80, subsampling=1, optimize=True)
        print("wrote", OUT / name, out.size)
        return
    # 256 colours, to keep the vault light to sync: the 90 most used exact colours (the HUD's flat colours, which
    # must not drift) and 166 picked for the rest (the scene, dithered). Full colour if a colour still drifts.
    counts = sorted(out.getcolors(maxcolors=out.width * out.height), reverse=True)
    keep = [c for _, c in counts[:90]]
    rest = out.quantize(colors=166, method=Image.Quantize.MEDIANCUT).getpalette()[:166 * 3]
    pal = Image.new("P", (1, 1))
    pal.putpalette([v for c in keep for v in c] + rest)
    small = out.quantize(palette=pal, dither=Image.Dither.FLOYDSTEINBERG)
    hist = ImageChops.difference(out, small.convert("RGB")).convert("L").histogram()
    drift = sum(hist[40:]) / (out.width * out.height)  # the share of the picture that is clearly off
    (small if drift < 0.002 else out).save(OUT / name, optimize=True)
    print("  share off %.4f" % drift, "(256 colours)" if drift < 0.002 else "(kept in full colour)")
    print("wrote", OUT / name, out.size)


SHEETS = {
    "ui-dive-phone-brick.png": lambda: sheet(
        "ui-dive-phone-brick.png",
        "The dive HUD on a phone (844 x 390), style A \"Brick\" (recommended). Mock-ups drawn by code, not the game.",
        [("1. Riding: 2.4 seconds left on this fish; the next fish is marked", "riding", "brick", PHONE),
         ("2. The last second: the ring and the HOP button call for the hop", "low", "brick", PHONE),
         ("3. In the hop, a fish locked: what it is and how long you would hold it", "hop", "brick", PHONE),
         ("4. Locked on a fish you can't hold yet", "strong", "brick", PHONE),
         ("5. In the hop with no fish, the window nearly gone", "nofish", "brick", PHONE),
         ("6. A tame finished: the banner, and the caught count goes up", "tamed", "brick", PHONE),
         ("7. A miss (or out of air): the screen closes in", "miss", "brick", PHONE),
         ("8. The end of a dive", "summary", "brick", PHONE)],
        2, 1100),
    "ui-dive-desktop-brick.png": lambda: sheet(
        "ui-dive-desktop-brick.png",
        "The dive HUD on a desktop (1920 x 1080), style A \"Brick\": the same pieces, a key hint in place of the button.",
        [("Riding", "riding", "brick", DESK), ("In the hop, a fish locked", "hop", "brick", DESK),
         ("A tame finished", "tamed", "brick", DESK), ("The end of a dive", "summary", "brick", DESK)],
        2, 1100),
    "ui-dive-phone-bubble.png": lambda: sheet(
        "ui-dive-phone-bubble.png",
        "The alternative, style B \"Bubble\", on a phone (844 x 390): the same pieces in glass.",
        [("Riding", "riding", "bubble", PHONE), ("The last second", "low", "bubble", PHONE),
         ("In the hop, a fish locked", "hop", "bubble", PHONE), ("A fish you can't hold yet", "strong", "bubble", PHONE),
         ("A tame finished", "tamed", "bubble", PHONE), ("The end of a dive", "summary", "bubble", PHONE)],
        2, 1100),
    "ui-dive-desktop-bubble.png": lambda: sheet(
        "ui-dive-desktop-bubble.png",
        "Style B \"Bubble\" on a desktop (1920 x 1080).",
        [("Riding", "riding", "bubble", DESK), ("In the hop, a fish locked", "hop", "bubble", DESK)],
        2, 1100),
    "ui-today-phone.png": lambda: sheet(
        "ui-today-phone.png",
        "Today's HUD on a phone (844 x 390), drawn from the sizes in HudController.luau (not a capture). Numbers: see the note.",
        [("Riding", "today-ride", "brick", PHONE), ("In the hop", "today-hop", "brick", PHONE)],
        2, 1100),
    "ui-phone-zones.png": lambda: sheet(
        "ui-phone-zones.png",
        "Where things can go on a phone held sideways (844 x 390). Orange: Roblox's. Blue: the look thumb. Green: ours.",
        [("", "zones", "brick", PHONE)], 1, 1688),
    "ui-first-hop.png": lambda: sheet(
        "ui-first-hop.png",
        "The first minute: the one thing a new player is told. Phone and desktop.",
        [("Phone: the first fish is running out", "teach", "brick", PHONE), ("Desktop", "teach", "brick", DESK)],
        2, 1100),
    "ui-style-directions.png": lambda: sheet(
        "ui-style-directions.png",
        "Three directions, the same pieces in each: the ride ring with the tame ring, the seven rarities, a banner, "
        "the depth ladder, a fish's tag, the buttons.",
        [("A. Brick (recommended)", "styles", "brick", (540, 560, 2, 1)),
         ("B. Bubble", "styles", "bubble", (540, 560, 2, 1)),
         ("C. Sticker", "styles", "sticker", (540, 560, 2, 1))],
        3, 720),
}

SKINS2 = [("brick", "A. Brick"), ("bubble", "B. Bubble"), ("mix", "C. Brick and Bubble"), ("over", "D. Bubble over Brick"),
          ("pick", "E. C, with glass on what holds things (the pick)")]
FRAMES2 = [("Riding", "v2-riding"), ("The last second", "v2-low"), ("In the hop, a fish locked", "v2-hop"),
           ("A tame finished", "v2-tamed"), ("A miss", "v2-miss"), ("The end of a dive", "v2-great"),
           ("On the dock", "v2-dock"), ("A shop panel", "v2-auras")]


def _v2(skin, label):
    return lambda: sheet(f"ui2-phone-{skin}.jpg", f"Pass 2, {label}, on a phone (844 x 390). Mock-ups drawn by code, not the game.",
                         [(f"{i + 1}. {cap}", st, skin, PHONE) for i, (cap, st) in enumerate(FRAMES2)], 2, 1100)


for _skin, _label in SKINS2:
    SHEETS[f"ui2-phone-{_skin}.jpg"] = _v2(_skin, _label)
SHEETS["ui2-riding-variants.jpg"] = lambda: sheet(
    "ui2-riding-variants.jpg", "Pass 2: the riding screen in each variant, on a phone (844 x 390).",
    [(label, "v2-riding", skin, PHONE) for skin, label in SKINS2], 2, 1100)
SHEETS["ui2-desktop-variants.jpg"] = lambda: sheet(
    "ui2-desktop-variants.jpg", "Pass 2: the riding screen in each variant, on a desktop (1920 x 1080).",
    [(label, "v2-riding", skin, DESK) for skin, label in SKINS2], 2, 1100)
SHEETS["ui2-pieces.jpg"] = lambda: sheet(
    "ui2-pieces.jpg", "Pass 2: the same pieces in each variant.",
    [(label, "v2-pieces", skin, (640, 560, 2, 1)) for skin, label in SKINS2], 2, 1100)

# pass 3 (the user, 2026-11-11): A's build, E's pattern, nearer the reference
SHEETS["ui3-phone.jpg"] = lambda: sheet(
    "ui3-phone.jpg", "Pass 3: A's simple build with E's pattern, nearer the reference. On a phone (844 x 390). Mock-ups, not the game.",
    [(f"{i + 1}. {cap}", st, "dino", PHONE) for i, (cap, st) in enumerate(FRAMES2)], 2, 1100)
SHEETS["ui3-desktop.jpg"] = lambda: sheet(
    "ui3-desktop.jpg", "Pass 3 on a desktop (1920 x 1080).",
    [("Riding", "v2-riding", "dino", DESK), ("A tame finished", "v2-tamed", "dino", DESK),
     ("The end of a dive", "v2-great", "dino", DESK), ("A shop panel", "v2-auras", "dino", DESK)], 2, 1100)
SHEETS["ui3-pattern.jpg"] = lambda: sheet(
    "ui3-pattern.jpg", "Pass 3: which pattern goes on the bricks. The same pieces three ways.",
    [("1. Studs and a diagonal shine (A as it was)", "v2-pieces", "dino&tex=stud", (640, 560, 2, 1)),
     ("2. Bubbles and a diagonal shine (drawn in pass 3)", "v2-pieces", "dino", (640, 560, 2, 1)),
     ("3. Bubbles and E's round shine", "v2-pieces", "dino&tex=dome", (640, 560, 2, 1))], 3, 740)

if __name__ == "__main__":
    if not CHROME:
        sys.exit("no Chrome or Edge found")
    if not FONT_DIRS:
        print("Roblox's fonts not found: the pictures fall back to the browser's own font")
    want = sys.argv[1:]
    for name, make in SHEETS.items():
        if not want or any(w in name for w in want):
            make()
