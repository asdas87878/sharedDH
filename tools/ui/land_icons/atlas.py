"""The land strip's pictures as one atlas (task l1): ten cells of 96 px across, the colour pictures on the top row and
the grey locked look under them (the game's LandStrip style 1 reads cells from it: Kit.LandAtlas, LAND_CELL).
    python tools/ui/land_icons/atlas.py [--studio] [--picks picks.json]
writes docs/attachments/land-icons/land_atlas.png (the file to upload once Hugo has picked the pictures) and, with --studio, a copy in
Studio's own content folder (rbxasset://textures/ridefish/land_atlas.png), for tests in Studio without an upload.
"""
import json
import shutil
import sys
from pathlib import Path

from PIL import Image

import icons

CELL = 96
ROOT = icons.ROOT
OUT = ROOT / "docs/attachments/land-icons/land_atlas.png"
STUDIO = Path.home() / ".var/app/org.vinegarhq.Vinegar/data/vinegar/versions/version-63eb6055af4e4688/content/textures/ridefish"


def build(picks=None):
    atlas = Image.new("RGB", (CELL * 10, CELL * 2))
    for land in range(1, 11):
        pick = (picks or {}).get(str(land))
        pic = icons.picture(land, CELL, CELL, pick)
        atlas.paste(pic, ((land - 1) * CELL, 0))
        atlas.paste(icons.state_picture(pic, "locked"), ((land - 1) * CELL, CELL))
    return atlas


if __name__ == "__main__":
    picks = None
    if "--picks" in sys.argv:
        picks = json.loads(Path(sys.argv[sys.argv.index("--picks") + 1]).read_text())
    OUT.parent.mkdir(parents=True, exist_ok=True)
    build(picks).save(OUT)
    print("wrote", OUT)
    if "--studio" in sys.argv:
        STUDIO.mkdir(parents=True, exist_ok=True)
        shutil.copy(OUT, STUDIO / "land_atlas.png")
        print("copied to", STUDIO)
