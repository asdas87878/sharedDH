"""The twelve aura icons of the Auras stall (Hugo, 2026-11-24: "fish rider", option E of
docs/attachments/aura-icons-options-1.png): frames each picture, checks the set, packs the atlas UI/AuraShop shows.

usage: python tools/ui/aura_icons/build.py frame <folder>     art/ui/auras/aura_NN.png from <folder>/<tier>.png
       python tools/ui/aura_icons/build.py [--studio]         the check, then art/ui/auras/aura_icons.png (4 x 3 of 256);
                                                              --studio also copies it into every Studio's content folder
       python tools/ui/aura_icons/build.py sheet <out.png>    all twelve at the shop's size, on the well's cream and on dark

The pictures come from the built-in ChatGPT image tool with real transparency (art/ui/auras/README.md). Framing only
resizes and places: tier 1 is 820 pixels wide, 6 is 880, 12 is 940 (as on the options sheet), the others evenly between,
all standing on one line. Nothing is painted, recoloured or cut out."""
import os
import shutil
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[3]
ART = ROOT / "art/ui/auras"
CELL, COLS, ROWS = 256, 4, 3
NAME = "aura_icons_e1.png"  # UI/AuraShop's Studio name: a new letter or number when the pictures change (Studio caches)
BASE = 974  # the line the pictures stand on


# a picture whose flame came out taller than the next tier's is framed this much smaller (1, 6 and 12 are as picked)
SMALLER = {5: 0.985, 10: 0.966, 11: 0.96}


def wide(tier):
    return round((820 + (tier - 1) * 12 if tier <= 6 else 880 + (tier - 6) * 10) * SMALLER.get(tier, 1))


def frame(folder):
    for tier in range(1, 13):
        src = Image.open(Path(folder) / f"{tier}.png").convert("RGBA")
        src.thumbnail((wide(tier), wide(tier)), Image.Resampling.LANCZOS)
        out = Image.new("RGBA", (1024, 1024), (0, 0, 0, 0))
        out.alpha_composite(src, ((1024 - src.width) // 2, BASE - src.height))
        out.save(ART / f"aura_{tier:02d}.png")


def icon(tier):
    return Image.open(ART / f"aura_{tier:02d}.png")


def check():
    faults, last = [], 0
    for tier in range(1, 13):
        im = icon(tier)
        a = im.getchannel("A") if im.mode == "RGBA" else None
        if a is None or im.size != (1024, 1024) or a.getextrema() != (0, 255):
            faults.append(f"tier {tier}: not a see-through 1024 picture ({im.mode}, {im.size})")
            continue
        inner = Image.new("L", im.size, 0)
        inner.paste(255, (32, 32, 992, 992))
        edge = Image.composite(Image.new("L", im.size, 0), a, inner)
        if edge.getextrema()[1] > 0:
            faults.append(f"tier {tier}: something within 32 pixels of the edge (alpha {edge.getextrema()[1]})")
        solid = a.point(lambda v: 255 if v > 32 else 0)
        box = solid.getbbox()
        share = solid.histogram()[255] / 1024 ** 2
        if box[3] - box[1] <= last:
            faults.append(f"tier {tier}: no taller than the tier before ({box[3] - box[1]}, {last})")
        last = box[3] - box[1]
        print(f"tier {tier:2}: {box}, {box[2] - box[0]} x {box[3] - box[1]}, {share:.0%} of the square")
    return faults


def atlas():
    out = Image.new("RGBA", (CELL * COLS, CELL * ROWS), (0, 0, 0, 0))
    for tier in range(1, 13):
        # colour under see-through pixels: the picture's own, so no dark line at the edges when the game scales it
        im = icon(tier).resize((CELL, CELL), Image.Resampling.LANCZOS)
        out.paste(im, ((tier - 1) % COLS * CELL, (tier - 1) // COLS * CELL))
    out.save(ART / "aura_icons.png")
    print("wrote", ART / "aura_icons.png", out.size, os.path.getsize(ART / "aura_icons.png"), "bytes")


def studio():
    for version in (Path.home() / ".var/app/org.vinegarhq.Vinegar/data/vinegar/versions").iterdir():
        if (version / "content").is_dir():
            dest = version / "content/textures/ridefish"
            dest.mkdir(parents=True, exist_ok=True)
            shutil.copy(ART / "aura_icons.png", dest / NAME)
            print("copied to", dest / NAME)


def sheet(dest):
    names = ["Bubble", "Shell", "Tide", "Current", "Reef", "Storm", "Moon", "Lantern", "Ember", "Urchin", "Abyss", "Leviathan"]
    font = ImageFont.truetype("/usr/share/fonts/TTF/DejaVuSans-Bold.ttf", 20)
    W = 12 * 190 + 10
    out = Image.new("RGB", (W, 2 * 226 + 10), "#101d32")
    d = ImageDraw.Draw(out)
    for tier in range(1, 13):
        for row, back in enumerate(("#f5e6c9", "#16324f")):
            x, y = 10 + (tier - 1) * 190, 10 + row * 226
            tile = Image.new("RGBA", (180, 180), back)
            tile.alpha_composite(icon(tier).resize((180, 180), Image.Resampling.LANCZOS))
            out.paste(tile.convert("RGB"), (x, y))
            if row == 0:
                d.text((x, y + 186), f"{tier} {names[tier - 1]}", font=font, fill="white")
    out.save(dest)
    print("sheet", dest, out.size)


if __name__ == "__main__":
    if len(sys.argv) > 2 and sys.argv[1] == "frame":
        frame(sys.argv[2])
    elif len(sys.argv) > 2 and sys.argv[1] == "sheet":
        sheet(sys.argv[2])
    else:
        bad = check()
        for line in bad:
            print("  !", line)
        if bad:
            sys.exit(1)
        atlas()
        if "--studio" in sys.argv:
            studio()
