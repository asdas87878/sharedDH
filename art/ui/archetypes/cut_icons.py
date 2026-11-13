"""Cuts the six archetype icons Hugo picked (Discord, 2026-11-13) out of the draft sheet
docs/attachments/archetype-icons-draft-1.png (6 rows x 3 columns A/B/C) into square PNGs with a clear background.

    FAST = A, PREDATOR = B, FRENZY = C, BREAKER = B, TANK = A, LEAPER = B

usage: python art/ui/archetypes/cut_icons.py [--install]
    writes art/ui/archetypes/<id>.png        256 px, the round dark badge kept (the one the game shows)
           art/ui/archetypes/plain/<id>.png  256 px, the badge keyed out (for comparison only)
    --install  also copies the badge pictures into Studio's content folder as
               rbxasset://ridefish/ui/archetypes/<id>.png (Studio-only, like tools/creatures/local_meshes.py)

Pillow only. These are the draft's own pixels: a stand-in until the icons are redrawn clean.
"""
import glob
import os
import shutil
import sys

from PIL import Image, ImageChops, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(HERE)))
SHEET = os.path.join(ROOT, "docs", "attachments", "archetype-icons-draft-1.png")
SIZE = 256
RADIUS = 77  # a badge's radius on the sheet, measured (156 px across); a pixel inside it, so no sheet shows at the rim
COLUMNS = {"A": 643.5, "B": 907.5, "C": 1171}
ROWS = {"Fast": 143, "Predator": 304, "Frenzy": 461.5, "Breaker": 617.5, "Tank": 772.5, "Leaper": 929}
PICKS = {"Fast": "A", "Predator": "B", "Frenzy": "C", "Breaker": "B", "Tank": "A", "Leaper": "B"}


def cut(sheet, ident):
    cx, cy = COLUMNS[PICKS[ident]], ROWS[ident]
    box = (round(cx - RADIUS), round(cy - RADIUS), round(cx + RADIUS), round(cy + RADIUS))
    face = sheet.crop(box).resize((SIZE, SIZE), Image.LANCZOS)
    # the round mask, drawn four times larger and shrunk, for a smooth rim
    big = Image.new("L", (SIZE * 4, SIZE * 4), 0)
    ImageDraw.Draw(big).ellipse((2, 2, SIZE * 4 - 3, SIZE * 4 - 3), fill=255)
    mask = big.resize((SIZE, SIZE), Image.LANCZOS)
    badge = face.convert("RGBA")
    badge.putalpha(mask)
    # no badge: the icon is bright, the badge dark, so alpha follows the brightest channel
    r, g, b = face.split()
    bright = ImageChops.lighter(ImageChops.lighter(r, g), b)
    key = bright.point(lambda v: max(0, min(255, (v - 55) * 255 // 70)))
    plain = face.convert("RGBA")
    plain.putalpha(ImageChops.multiply(key, mask))
    return badge, plain


def content_folder():
    found = os.environ.get("STUDIO_CONTENT")
    if found:
        return found
    versions = glob.glob(os.path.expanduser("~/.var/app/org.vinegarhq.Vinegar/data/vinegar/versions/*/content"))
    return max(versions, key=os.path.getmtime) if versions else None


def main():
    sheet = Image.open(SHEET).convert("RGB")
    os.makedirs(os.path.join(HERE, "plain"), exist_ok=True)
    for ident in ROWS:
        badge, plain = cut(sheet, ident)
        badge.save(os.path.join(HERE, ident.lower() + ".png"))
        plain.save(os.path.join(HERE, "plain", ident.lower() + ".png"))
    print("wrote", len(ROWS), "icons to", HERE)
    if "--install" in sys.argv:
        content = content_folder()
        if not content:
            sys.exit("no Studio content folder found (set STUDIO_CONTENT)")
        out = os.path.join(content, "ridefish", "ui", "archetypes")
        os.makedirs(out, exist_ok=True)
        for ident in ROWS:
            shutil.copy(os.path.join(HERE, ident.lower() + ".png"), out)
        print("installed in", out)


if __name__ == "__main__":
    main()
