"""Where the voxel creature scripts find things, on anyone's PC (docs/style/creature-brief.md).
ROOT is the project folder, WORK a folder for renders and checks that is not kept in the repo (work/voxel/), BLENDER the
Blender program: the BLENDER environment variable if it is set, else `blender` on the path, else the newest one installed
in the usual place."""
import glob
import os
import shutil

from PIL import ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))).replace("\\", "/") + "/"
WORK = ROOT + "work/voxel/"
os.makedirs(WORK, exist_ok=True)


def _blender():
    found = os.environ.get("BLENDER") or shutil.which("blender")
    if found:
        return found
    for pattern in ("C:/Program Files/Blender Foundation/*/blender.exe", "/Applications/Blender*.app/Contents/MacOS/Blender"):
        hits = sorted(glob.glob(pattern))
        if hits:
            return hits[-1]
    return "blender"


BLENDER = _blender()


def font(name, size):
    """a font for the sheets: the Windows one asked for, or the nearest thing this PC has"""
    for path in ("C:/Windows/Fonts/" + name, "/Library/Fonts/Arial Bold.ttf", "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"):
        try:
            return ImageFont.truetype(path, size)
        except OSError:
            pass
    return ImageFont.load_default()
