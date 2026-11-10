"""The rarity ladder sheet (docs/style/05-rarity-look.md): builds art/style/rarity_ladder/ladder.py at each of its six
tiers with tools/blender/voxel_kit.py and lays the six out in docs/attachments/rarity-ladder.jpg: the 3/4 views at equal
size, the side views at equal size, and the side views at their true relative size.

usage: python tools/art/rarity_ladder.py <scratch folder> [--check] [--sheet-only] [--tiers 4,5,6]
  <scratch folder>  where the tier copies of the model and the renders go (not in the vault: it syncs)
  --check           run the gate on each tier and stop (a few seconds each, no renders)
  --sheet-only      lay the sheet out from renders already there
  --tiers           build only these tiers
"""
import io
import os
import re
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
MODEL = os.path.join(ROOT, "art", "style", "rarity_ladder", "ladder.py")
KIT = os.path.join(ROOT, "tools", "blender", "voxel_kit.py")
SHEET = os.path.join(ROOT, "docs", "attachments", "rarity-ladder.jpg")
BLENDER = r"C:\Program Files\Blender Foundation\Blender 5.2\blender.exe"
TIERS = ("Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic")
BG = (254, 248, 241)

args = sys.argv[1:]
out = os.path.abspath(args[0])
check, sheet_only = "--check" in args, "--sheet-only" in args
wanted = [int(t) for t in args[args.index("--tiers") + 1].split(",")] if "--tiers" in args else list(range(1, 7))
os.makedirs(out, exist_ok=True)

# ---------------------------------------------------------------- build
source = io.open(MODEL, encoding="utf-8").read()
line = next(ln for ln in source.splitlines() if ln.startswith("TIER = "))
if not sheet_only:
    for tier in wanted:
        model = os.path.join(out, f"ladder_tier{tier}.py")
        io.open(model, "w", encoding="utf-8", newline="\n").write(source.replace(line, f"TIER = {tier}"))
        folder = os.path.join(out, f"tier{tier}")
        run = subprocess.run([BLENDER, "--background", "--python", KIT, "--", model, folder] + (["--check"] if check else []),
                             capture_output=True, text=True)
        text = run.stdout + run.stderr
        keep = [ln for ln in text.splitlines() if any(w in ln for w in ("Error", "Traceback", "  !", "faults", 'File "', "voxel kit: Ladder"))]
        print(f"tier {tier} ({TIERS[tier - 1]}):", " | ".join(keep) or "no output")
        found = re.search(r"voxel kit: .*?(\d+) triangles, ([\d.]+) x ([\d.]+) x ([\d.]+) studs", text)
        if found:
            io.open(os.path.join(out, f"tier{tier}.txt"), "w").write(" ".join(found.groups()))
if check:
    sys.exit(0)

# ---------------------------------------------------------------- the sheet
from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageFont  # noqa: E402

big = ImageFont.truetype("C:/Windows/Fonts/ariblk.ttf", 30)
font = ImageFont.truetype("C:/Windows/Fonts/arialbd.ttf", 22)
small = ImageFont.truetype("C:/Windows/Fonts/arial.ttf", 18)


def flat(path):
    im = Image.open(path).convert("RGBA")
    im = im.crop(im.getbbox())
    back = Image.new("RGBA", im.size, BG + (255,))
    back.alpha_composite(im)
    return back.convert("RGB")


def bloom(im, radius=9, amount=0.38):
    """how Roblox's Neon material blooms: the glowing colours (strong orange and yellow, strong cyan) spread a soft halo"""
    r, g, b = im.split()
    hot = ImageChops.multiply(ImageChops.multiply(r.point(lambda v: 255 if v > 205 else 0), b.point(lambda v: 255 if v < 115 else 0)),
                              g.point(lambda v: 255 if v > 80 else 0))
    cool = ImageChops.multiply(ImageChops.multiply(b.point(lambda v: 255 if v > 205 else 0), r.point(lambda v: 255 if v < 150 else 0)),
                               g.point(lambda v: 255 if v > 170 else 0))
    mask = ImageChops.lighter(hot, cool)
    glow = Image.composite(im, Image.new("RGB", im.size, (0, 0, 0)), mask).filter(ImageFilter.GaussianBlur(radius))
    glow = glow.point(lambda v: min(255, int(v * amount * 2.2)))
    return ImageChops.screen(im, glow)


def view(tier, which):
    im = flat(os.path.join(out, f"tier{tier}", which + ".png"))
    return bloom(im) if tier >= 5 else im  # the tiers whose colours glow as a body feature


def cell(im, w, h, label, note=""):
    c = Image.new("RGB", (w, h), BG)
    s = min((w - 24) / im.width, (h - 84) / im.height)
    im = im.resize((int(im.width * s), int(im.height * s)), Image.LANCZOS)
    c.paste(im, ((w - im.width) // 2, 50 + (h - 84 - im.height) // 2))
    d = ImageDraw.Draw(c)
    d.text((14, 10), label, font=font, fill=(40, 40, 40))
    if note:
        d.text((14, h - 30), note, font=small, fill=(110, 100, 90))
    return c


stats = {}
for tier in range(1, 7):
    triangles, length, _, _ = io.open(os.path.join(out, f"tier{tier}.txt")).read().split()
    stats[tier] = (int(triangles), float(length))

W, H = 430, 380
heroes = [cell(view(t, "hero"), W, H, f"{t}: {TIERS[t - 1]}", f"{stats[t][0]:,} triangles, {stats[t][1]:.0f} studs long") for t in range(1, 7)]
sides = [cell(view(t, "side"), W, H, "") for t in range(1, 7)]
# the side views at one scale: each side render is 900 px across ORTHO studs, and ORTHO = 1.3 x the tier's length
ortho = {t: (11, 13, 15, 19, 25, 31)[t - 1] * 1.3 for t in range(1, 7)}
scaled = []
for tier in range(1, 7):
    im = view(tier, "side")
    per_stud = 900 / ortho[tier]
    target = 900 / ortho[6] * 1.0  # pixels a stud at the Mythic's scale
    k = target / per_stud
    scaled.append(im.resize((max(1, int(im.width * k)), max(1, int(im.height * k))), Image.LANCZOS))
strip_w = 6 * (W + 10) - 10
gap = (strip_w - sum(im.width for im in scaled)) // 7
strip_h = max(im.height for im in scaled) + 70
strip = Image.new("RGB", (strip_w, strip_h), BG)
ImageDraw.Draw(strip).text((14, 10), "At their true relative size", font=font, fill=(40, 40, 40))
x = max(gap, 4)
for im in scaled:
    strip.paste(im, (x, 50 + (strip_h - 70 - im.height) // 2))
    x += im.width + max(gap, 4)

sheet = Image.new("RGB", (6 * (W + 10) + 10, 64 + 2 * (H + 10) + strip_h + 10), (255, 255, 255))
ImageDraw.Draw(sheet).text((14, 12), "The rarity ladder: one fish, dressed at each tier", font=big, fill=(40, 40, 40))
for i in range(6):
    sheet.paste(heroes[i], (10 + i * (W + 10), 60))
    sheet.paste(sides[i], (10 + i * (W + 10), 60 + H + 10))
sheet.paste(strip, (10, 60 + 2 * (H + 10)))
sheet.save(SHEET, quality=90)
print(SHEET, sheet.size)
