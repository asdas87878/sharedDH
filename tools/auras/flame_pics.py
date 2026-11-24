"""The aura flame's six pictures (art/ui/aura_flame): checks them and copies them into every Studio on this PC, where
AuraController reads them until they are uploaded (Auras.Pictures). Nothing is uploaded.

usage: python tools/auras/flame_pics.py [check]     the check only with "check"

The three Beam pictures are copied four times, turned by 0 to 3 quarter turns (aura_flame_f1_t0.png ..): which way a Beam
runs its picture could not be checked offline, so Config.Aura.Turn picks one in Studio."""
import sys
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
ART = ROOT / "art/ui/aura_flame"
SET = "f1"  # Shared/Auras.PictureSet: a new one when a picture changes (Studio caches)
SIZES = {"flame": (512, 512), "streaks": (512, 512), "tip": (192, 384), "lick": (128, 128), "bubble": (128, 128), "arc": (128, 128)}
BEAMS = ("flame", "streaks", "tip")


def check():
    faults = []
    for name, size in SIZES.items():
        path = ART / f"aura_{name}.png"
        if not path.exists():
            faults.append(f"{path.name}: missing")
            continue
        im = Image.open(path)
        if im.mode != "RGBA" or im.size != size:
            faults.append(f"{path.name}: {im.mode} {im.size}, not RGBA {size}")
            continue
        red, green, blue, alpha = im.split()
        if any(c.getextrema() != (255, 255) for c in (red, green, blue)):
            faults.append(f"{path.name}: not white (the game tints it)")
        w, h = size
        edges = [(0, 0, 1, h), (w - 1, 0, w, h)]
        if name not in ("flame", "streaks"):  # (those two repeat top to bottom)
            edges += [(0, 0, w, 1), (0, h - 1, w, h)]
        for box in edges:
            top = alpha.crop(box).getextrema()[1]
            if top > 8:
                faults.append(f"{path.name}: alpha {top} on its border {box}, a line would show")
    return faults


def studio():
    home = Path.home() / ".var/app/org.vinegarhq.Vinegar/data/vinegar/versions"
    windows = Path.home() / "AppData/Local/Roblox/Versions"
    for versions in (home, windows):
        for version in versions.iterdir() if versions.is_dir() else []:
            if not (version / "content").is_dir():
                continue
            dest = version / "content/textures/ridefish"
            dest.mkdir(parents=True, exist_ok=True)
            for name in SIZES:
                im = Image.open(ART / f"aura_{name}.png")
                if name in BEAMS:
                    for turn in range(4):
                        im.rotate(-90 * turn, expand=True).save(dest / f"aura_{name}_{SET}_t{turn}.png")
                else:
                    im.save(dest / f"aura_{name}_{SET}.png")
            print("copied to", dest)


if __name__ == "__main__":
    found = check()
    for f in found:
        print("FAULT", f)
    print(f"{len(SIZES)} pictures, {len(found)} faults")
    if found:
        sys.exit(1)
    if sys.argv[1:] != ["check"]:
        studio()
