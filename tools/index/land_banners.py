"""The Index's land pictures, made ready (NULLROOM task i1). From the painted lands (art/ui/lands, task g1):

    python tools/index/land_banners.py          the ten files to upload: art/ui/lands/upload/land_banner_NN.png
    python tools/index/land_banners.py studio   the same into Studio's own content folder, to see them in Studio before
                                                the upload (rbxasset://textures/ridefish; a live game never reads those)

480 x 800 is twice what a 1080p screen draws a banner at, and 1.5 MB in memory for each where the source is 3.9.
After Hugo's yes and the upload: the ids go in LandBanners.Ids (src/client/UI/LandBanners.luau), by land.
"""
import sys
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
LANDS = ROOT / "art/ui/lands"
SIZE = (480, 800)


def sources():
    found = sorted(LANDS.glob("land_[0-9][0-9]_*.png"))
    if len(found) != 10:
        sys.exit(f"{len(found)} lands in {LANDS}, not 10")
    return found


def studio_folders():
    home = Path.home()
    found = list(home.glob(".var/app/org.vinegarhq.Vinegar/data/vinegar/versions/*/content/textures"))
    found += list(home.glob("AppData/Local/Roblox/Versions/*/content/textures"))
    return [f / "ridefish" for f in found]


def main():
    out = studio_folders() if sys.argv[1:] == ["studio"] else [LANDS / "upload"]
    if not out:
        sys.exit("no Studio content folder found")
    for folder in out:
        folder.mkdir(parents=True, exist_ok=True)
        for source in sources():
            file = folder / f"land_banner_{source.name[5:7]}.png"
            Image.open(source).convert("RGB").resize(SIZE, Image.LANCZOS).save(file, optimize=True)
            print(file)


if __name__ == "__main__":
    main()
