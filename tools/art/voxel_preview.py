"""Build voxel models and lay each one's views out in one picture. usage: python tools/art/voxel_preview.py <Name> [<Name> ...]   (writes work/voxel/<Name>_preview.png)"""
import os
import subprocess
import sys

from PIL import Image

from voxel_paths import BLENDER as B, ROOT as R, WORK

S = WORK.rstrip("/")
BG = (254, 248, 241)


def flat(p):
    im = Image.open(p).convert("RGBA")
    b = Image.new("RGBA", im.size, BG + (255,))
    b.alpha_composite(im)
    return b.convert("RGB")


for name in sys.argv[1:]:
    out = f"{S}/hand/{name}"
    r = subprocess.run([B, "--background", "--python", R + "tools/blender/voxel_kit.py", "--", R + f"art/creatures/{name}/voxel.py", out, "--wire"],
                       capture_output=True, text=True)
    lines = [line for line in (r.stdout + r.stderr).splitlines() if any(w in line for w in ("Error", "Traceback", "voxel kit", "line ", "cubes,")) or line.startswith("  !")]
    print("\n".join(lines[-30:]))
    if not os.path.exists(out + "/ride.png"):
        continue
    hero, side, front, top, head = (flat(f"{out}/{n}.png") for n in ("hero", "side", "front", "top", "head"))
    ride = Image.open(f"{out}/ride.png").convert("RGB").resize((640, 360))
    sheet = Image.new("RGB", (2000, 1220), (255, 255, 255))
    sheet.paste(hero, (0, 0))
    sheet.paste(side, (1100, 0))
    sheet.paste(front.resize((420, 420)), (1100, 560))
    sheet.paste(ride, (1100 + 440, 580))
    sheet.paste(top, (0, 800))
    sheet.paste(head.resize((450, 400)), (920, 810))
    sheet = sheet.resize((1400, 854), Image.LANCZOS)
    sheet.save(f"{S}/{name}_preview.png")
    print("preview", f"{S}/{name}_preview.png")
