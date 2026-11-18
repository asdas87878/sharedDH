"""The land strip's pictures as one atlas (task l1, rows reworked in s2): ten cells of 96 px across, six rows: 0 the
colour pictures, 1 their plain grey copies (the game lays the colour over the grey at Kit.LandLocked.Saturation and
darkens both, so a locked land is its own picture, desaturated and darker), 2 and 3 the same softly blurred, 4 and 5
very blurred (Kit.LandLocked.Blur 1 and 2: a Roblox ImageLabel cannot blur, so the blur is baked in here).
    python tools/ui/land_icons/atlas.py [--studio] [--picks picks.json] [--gen 1-4]
writes docs/attachments/land-icons/land_atlas.png (the file to upload once Hugo has picked the pictures) and, with --studio, a copy in
Studio's own content folder (rbxasset://textures/ridefish/land_atlas.png), for tests in Studio without an upload.
"""
import json
import shutil
import sys
from pathlib import Path

from PIL import Image, ImageFilter, ImageOps

import icons

CELL = 96
BLURS = (0, 4, 8)  # Gaussian radius in atlas pixels for Blur 0, 1, 2 (a cell shows at about 23 GUI px: 1 and 2 px)
ROOT = icons.ROOT
OUT = ROOT / "docs/attachments/land-icons/land_atlas.png"
# every Studio version Vinegar has (the one that runs changes with Studio's updates)
VERSIONS = Path.home() / ".var/app/org.vinegarhq.Vinegar/data/vinegar/versions"


def build(picks=None, gen=None):
    atlas = Image.new("RGB", (CELL * 10, CELL * 2 * len(BLURS)))
    for land in range(1, 11):
        pick = (picks or {}).get(str(land))
        if gen:  # a generated set (gen_sheet.py): docs/attachments/land-icons/gen/G<k>_land<NN>.png
            src = ROOT / f"docs/attachments/land-icons/gen/G{gen}_land{land:02d}.png"
            pic = Image.open(src).convert("RGB").resize((CELL, CELL), Image.LANCZOS)
        else:
            pic = icons.picture(land, CELL, CELL, pick)
        for k, radius in enumerate(BLURS):
            soft = pic
            if radius:  # blurred inside its own cell: padded with its own edge so no neighbour bleeds in
                pad = radius * 3
                big = ImageOps.expand(pic, pad)
                big.paste(pic.resize((CELL + 2 * pad, CELL + 2 * pad)), (0, 0))
                big.paste(pic, (pad, pad))
                soft = big.filter(ImageFilter.GaussianBlur(radius)).crop((pad, pad, pad + CELL, pad + CELL))
            atlas.paste(soft, ((land - 1) * CELL, 2 * k * CELL))
            atlas.paste(ImageOps.grayscale(soft).convert("RGB"), ((land - 1) * CELL, (2 * k + 1) * CELL))
    return atlas


if __name__ == "__main__":
    picks = None
    if "--picks" in sys.argv:
        picks = json.loads(Path(sys.argv[sys.argv.index("--picks") + 1]).read_text())
    OUT.parent.mkdir(parents=True, exist_ok=True)
    gen = sys.argv[sys.argv.index("--gen") + 1] if "--gen" in sys.argv else None
    build(picks, gen).save(OUT)
    print("wrote", OUT)
    if "--studio" in sys.argv:
        for version in VERSIONS.glob("version-*"):
            studio = version / "content/textures/ridefish"
            studio.mkdir(parents=True, exist_ok=True)
            shutil.copy(OUT, studio / "land_atlas.png")
            print("copied to", studio)
