"""Builds creatures from their specs: the fish kit's renders and game mesh, the turnaround sheet, then shrinks the PNGs to
256-colour palettes (flat-coloured renders lose nothing visible, and the vault syncs through Git).

usage: python art/creatures/build.py [Name ...]   (no names: every folder here with a spec.json)
Blender: $BLENDER, else the Windows install path from CLAUDE.md, else `blender` on the PATH.
Outputs per creature: renders/ (hero, side, front, top, ride), sheet.png, <Name>.obj/.mtl/_palette.png/.mesh.json.
"""
import os
import runpy
import shutil
import subprocess
import sys

from PIL import Image, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
HERE = os.path.join(ROOT, "art", "creatures")
WINDOWS_BLENDER = r"C:\Program Files\Blender Foundation\Blender 5.2\blender.exe"
BLENDER = os.environ.get("BLENDER") or (WINDOWS_BLENDER if os.path.exists(WINDOWS_BLENDER) else shutil.which("blender"))

# creature_sheet.py loads Arial from C:/Windows/Fonts; elsewhere fall back to DejaVu Sans Bold
_truetype = ImageFont.truetype
FALLBACK = "/usr/share/fonts/TTF/DejaVuSans-Bold.ttf"


def _font(path, size):
    if not os.path.exists(path) and os.path.exists(FALLBACK):
        path = FALLBACK
    return _truetype(path, size)


ImageFont.truetype = _font


def shrink(path):
    im = Image.open(path)
    if im.mode == "RGBA":
        q = im.quantize(256, method=Image.Quantize.FASTOCTREE, dither=Image.Dither.NONE)
    else:
        q = im.convert("RGB").quantize(256, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE)
    q.save(path, optimize=True)


def build(name):
    folder = os.path.join(HERE, name)
    spec = os.path.join(folder, "spec.json")
    renders = os.path.join(folder, "renders")
    subprocess.run([BLENDER, "--background", "--python", os.path.join(ROOT, "tools", "blender", "fish_kit.py"), "--", spec,
                    renders, "--export", os.path.join(folder, f"{name}.obj")], check=True, stdout=subprocess.DEVNULL)
    sheet = os.path.join(folder, "sheet.png")
    sys.argv = ["creature_sheet.py", spec, renders, sheet]
    runpy.run_path(os.path.join(ROOT, "tools", "art", "creature_sheet.py"), run_name="__main__")
    for f in os.listdir(renders):
        if f.endswith(".png"):
            shrink(os.path.join(renders, f))
    shrink(sheet)
    print("built", name)


names = sys.argv[1:] or sorted(n for n in os.listdir(HERE) if os.path.exists(os.path.join(HERE, n, "spec.json")))
for n in names:
    build(n)
