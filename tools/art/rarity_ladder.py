"""The rarity ladder sheets (docs/style/05-rarity-look.md): builds art/style/rarity_ladder/ladder.py at each of its tiers,
and at tier 6 in each of its Mythic kinds, with tools/blender/voxel_kit.py. Lays out two sheets:
  docs/attachments/rarity-ladder.jpg         the six tiers: 3/4 views at equal size, side views, and side views at their
                                             true relative size (tier 6 is the model's first Mythic kind)
  docs/attachments/rarity-mythic-routes.jpg  the Mythic kinds side by side: 3/4 view, side view, name, idea

usage: python tools/art/rarity_ladder.py <scratch folder> [--check] [--sheet-only] [--only tier4,mythic_regal]
  <scratch folder>  where the copies of the model and the renders go (not in the vault: it syncs)
  --check           run the gate on each build and stop (a few seconds each, no renders)
  --sheet-only      lay the sheets out from renders already there
  --only            build only these (tier1 to tier5, mythic_<kind>)
"""
import io
import os
import re
import runpy
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
MODEL = os.path.join(ROOT, "art", "style", "rarity_ladder", "ladder.py")
KIT = os.path.join(ROOT, "tools", "blender", "voxel_kit.py")
SHEET = os.path.join(ROOT, "docs", "attachments", "rarity-ladder.jpg")
ROUTES = os.path.join(ROOT, "docs", "attachments", "rarity-mythic-routes.jpg")
BLENDER = r"C:\Program Files\Blender Foundation\Blender 5.2\blender.exe"
TIERS = ("Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic")
BG = (254, 248, 241)

args = sys.argv[1:]
out = os.path.abspath(args[0])
check, sheet_only = "--check" in args, "--sheet-only" in args
os.makedirs(out, exist_ok=True)

source = io.open(MODEL, encoding="utf-8").read()
tier_line = next(ln for ln in source.splitlines() if ln.startswith("TIER = "))
kind_line = next(ln for ln in source.splitlines() if ln.startswith("MYTHIC = "))
KINDS = list(runpy.run_path(MODEL)["MYTHICS"])
builds = [(f"tier{t}", t, None) for t in range(1, 6)] + [(f"mythic_{k}", 6, k) for k in KINDS]  # (folder, tier, kind)
if "--only" in args:
    wanted = args[args.index("--only") + 1].split(",")
    builds_now = [b for b in builds if b[0] in wanted]
else:
    builds_now = builds


def model_of(name):
    return os.path.join(out, f"ladder_{name}.py")


# ---------------------------------------------------------------- build
if not sheet_only:
    for name, tier, kind in builds_now:
        text = source.replace(tier_line, f"TIER = {tier}")
        if kind:
            text = text.replace(kind_line, f'MYTHIC = "{kind}"')
        io.open(model_of(name), "w", encoding="utf-8", newline="\n").write(text)
        run = subprocess.run([BLENDER, "--background", "--python", KIT, "--", model_of(name), os.path.join(out, name)] + (["--check"] if check else []),
                             capture_output=True, text=True)
        log = run.stdout + run.stderr
        keep = [ln for ln in log.splitlines() if any(w in ln for w in ("Error", "Traceback", "  !", "faults", 'File "', "voxel kit: Ladder"))]
        print(f"{name}:", " | ".join(keep) or "no output")
        found = re.search(r"voxel kit: .*?(\d+) triangles, ([\d.]+) x ([\d.]+) x ([\d.]+) studs", log)
        if found:
            io.open(os.path.join(out, f"{name}.txt"), "w").write(" ".join(found.groups()))
if check:
    sys.exit(0)

# ---------------------------------------------------------------- the sheets
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
    """how Roblox's Neon material blooms: the glowing colours (strong orange and yellow, strong cyan, strong violet) spread
    a soft halo"""
    r, g, b = im.split()

    def over(band, level):
        return band.point(lambda v: 255 if v > level else 0)

    def under(band, level):
        return band.point(lambda v: 255 if v < level else 0)

    hot = ImageChops.multiply(ImageChops.multiply(over(r, 205), under(b, 115)), over(g, 80))
    cool = ImageChops.multiply(ImageChops.multiply(over(b, 205), under(r, 150)), over(g, 170))
    violet = ImageChops.multiply(ImageChops.multiply(over(b, 215), over(r, 140)), over(ImageChops.subtract(b, g), 40))
    mask = ImageChops.lighter(ImageChops.lighter(hot, cool), violet)
    glow = Image.composite(im, Image.new("RGB", im.size, (0, 0, 0)), mask).filter(ImageFilter.GaussianBlur(radius))
    glow = glow.point(lambda v: min(255, int(v * amount * 2.2)))
    return ImageChops.screen(im, glow)


facts = {}
for name, tier, kind in builds:
    model = runpy.run_path(model_of(name))
    triangles, length, _, _ = io.open(os.path.join(out, f"{name}.txt")).read().split()
    facts[name] = {"triangles": int(triangles), "length": float(length), "ortho": model["ORTHO"],
                   "glows": any(v >= 0.55 for v in model.get("GLOW", {}).values()), "model": model}


def view(name, which):
    im = flat(os.path.join(out, name, which + ".png"))
    return bloom(im) if facts[name]["glows"] else im  # a halo only where something really glows


def wrap(draw, text, fnt, width):
    lines, line = [], ""
    for word in text.split():
        trial = (line + " " + word).strip()
        if draw.textlength(trial, font=fnt) > width and line:
            lines.append(line)
            line = word
        else:
            line = trial
    return lines + [line]


def cell(im, w, h, label, note="", text=""):
    c = Image.new("RGB", (w, h), BG)
    d = ImageDraw.Draw(c)
    lines = wrap(d, text, small, w - 28) if text else []
    top = 50 + 24 * len(lines)
    s = min((w - 24) / im.width, (h - top - 34) / im.height)
    im = im.resize((int(im.width * s), int(im.height * s)), Image.LANCZOS)
    c.paste(im, ((w - im.width) // 2, top + (h - top - 34 - im.height) // 2))
    d.text((14, 10), label, font=font, fill=(40, 40, 40))
    for k, ln in enumerate(lines):
        d.text((14, 42 + 24 * k), ln, font=small, fill=(70, 66, 60))
    if note:
        d.text((14, h - 30), note, font=small, fill=(110, 100, 90))
    return c


# 1: the ladder
ladder = [f"tier{t}" for t in range(1, 6)] + [f"mythic_{KINDS[0]}"]
W, H = 430, 380
heroes = [cell(view(n, "hero"), W, H, f"{k + 1}: {TIERS[k]}", f"{facts[n]['triangles']:,} triangles, {facts[n]['length']:.0f} studs long")
          for k, n in enumerate(ladder)]
sides = [cell(view(n, "side"), W, H, "") for n in ladder]
# the side views at one scale: each side render is 900 px across its ORTHO studs
widest = max(facts[n]["ortho"] for n in ladder)
scaled = []
for n in ladder:
    im = view(n, "side")
    k = facts[n]["ortho"] / widest
    scaled.append(im.resize((max(1, int(im.width * k)), max(1, int(im.height * k))), Image.LANCZOS))
strip_w = 6 * (W + 10) - 10
fit = min(1.0, (strip_w - 7 * 8) / sum(im.width for im in scaled))
scaled = [im.resize((max(1, int(im.width * fit)), max(1, int(im.height * fit))), Image.LANCZOS) for im in scaled]
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

# 2: the Mythic kinds
W, H = 640, 520
names = [f"mythic_{k}" for k in KINDS]
titles = facts[names[0]]["model"]["MYTHICS"]
top = [cell(view(n, "hero"), W, H, titles[k][0], f"{facts[n]['triangles']:,} triangles, {facts[n]['length']:.0f} studs long", titles[k][1])
       for k, n in zip(KINDS, names)]
low = [cell(view(n, "side"), W, H - 110, "") for n in names]
routes = Image.new("RGB", (len(names) * (W + 10) + 10, 64 + H + 10 + H - 110 + 10), (255, 255, 255))
ImageDraw.Draw(routes).text((14, 12), "Four ways to be Mythic, on the same fish", font=big, fill=(40, 40, 40))
for i in range(len(names)):
    routes.paste(top[i], (10 + i * (W + 10), 60))
    routes.paste(low[i], (10 + i * (W + 10), 60 + H + 10))
routes.save(ROUTES, quality=90)
print(ROUTES, routes.size)
