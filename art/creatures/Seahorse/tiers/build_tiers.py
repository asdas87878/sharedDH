"""DRAFT (m1, 2026-11-19): builds trainer.py at TIER 1 to 12 with tools/blender/voxel_kit.py and lays out
docs/attachments/seahorse-tiers-draft-1.png: the twelve three-quarter views at one scale, labelled, and a close-up of
levels 10 to 12.

usage: python art/creatures/Seahorse/tiers/build_tiers.py [--check] [--sheet-only] [--only 3,7]
  renders go to work/voxel/seahorse_tiers/ (not kept in the repo)
  --check       run the gate on each level and stop
  --sheet-only  lay the sheet out from renders already there
  --export      the game's meshes (GAME = True: no draft coil or plate): voxel_kit.py --export for each level into
                art/creatures/Seahorse/tiers/game/T<n>/ (SeahorseTrainer<n>.glb and .mesh.json), then
                tiers.json (each level's name, seat, lights); install_tiers.py puts them in Studio
"""
import io
import os
import re
import runpy
import shutil
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(HERE))))
MODEL = os.path.join(HERE, "trainer.py")
KIT = os.path.join(ROOT, "tools", "blender", "voxel_kit.py")
OUT = os.path.join(ROOT, "work", "voxel", "seahorse_tiers")
SHEET = os.path.join(ROOT, "docs", "attachments", "seahorse-tiers-draft-1.png")
BLENDER = os.environ.get("BLENDER") or shutil.which("blender") or r"C:\Program Files\Blender Foundation\Blender 5.2\blender.exe"
BG = (250, 246, 240)
NOTES = {
    1: "the game's seahorse on an iron coil",
    2: "teal rings, fin tips, a white trim",
    3: "saddle, blanket, bridle; a rimmed pad",
    4: "bigger fan, cheek fins; a stepped base",
    5: "silver plates and chest plate; steel",
    6: "a spiked mane; corner posts",
    7: "glowing eye, visor, plume; a lit coil",
    8: "gold crown, gems, velvet saddle",
    9: "yellow gold, violet halo eye",
    10: "glowing ribbon, wings, halo eye, crystals",
    11: "two glows, floating crown, shards",
    12: "rainbow, white light, pearl stand",
}

args = sys.argv[1:]
check, sheet_only, export = "--check" in args, "--sheet-only" in args, "--export" in args
tiers = [int(t) for t in args[args.index("--only") + 1].split(",")] if "--only" in args else list(range(1, 13))
os.makedirs(OUT, exist_ok=True)
source = io.open(MODEL, encoding="utf-8").read()
tier_line = next(ln for ln in source.splitlines() if ln.startswith("TIER = "))


def model_of(t):
    return os.path.join(OUT, f"trainer_{t}.py")


if export:
    import json

    game_line = next(ln for ln in source.splitlines() if ln.startswith("GAME = "))
    rows, bad = {}, 0
    for t in tiers:
        path = os.path.join(OUT, f"game_{t}.py")
        io.open(path, "w", encoding="utf-8", newline="\n").write(
            source.replace(tier_line, f"TIER = {t}").replace(game_line, "GAME = True"))
        folder = os.path.join(HERE, "game", f"T{t}")
        run = subprocess.run([BLENDER, "--background", "--python", KIT, "--", path, folder, "--export", folder],
                             capture_output=True, text=True)
        log = run.stdout + run.stderr
        keep = [ln for ln in log.splitlines() if any(w in ln for w in ("Error", "Traceback", "  !", "voxel kit: export"))]
        print(f"level {t}:", " | ".join(keep) or "no output", flush=True)
        if not os.path.exists(os.path.join(folder, f"SeahorseTrainer{t}.glb")) or any("  !" in k or "Error" in k for k in keep):
            bad += 1
        model = runpy.run_path(path)
        rows[str(t)] = {"name": model["NAMES"][t], "lights": [[n, list(at), c, rng, b] for n, at, c, rng, b in model["LIGHTS"]],
                        "rainbow": model.get("VARIANT") == "rainbow", "keep": sorted(model.get("KEEP", []))}
    if tiers == list(range(1, 13)):
        json.dump(rows, open(os.path.join(HERE, "game", "tiers.json"), "w"), indent=1)
    sys.exit(1 if bad else 0)


if not sheet_only:
    for t in tiers:
        io.open(model_of(t), "w", encoding="utf-8", newline="\n").write(source.replace(tier_line, f"TIER = {t}"))
        run = subprocess.run([BLENDER, "--background", "--python", KIT, "--", model_of(t), os.path.join(OUT, f"t{t}"),
                              "--check" if check else "--hero"], capture_output=True, text=True)
        log = run.stdout + run.stderr
        keep = [ln for ln in log.splitlines() if any(w in ln for w in ("Error", "Traceback", "  !", "voxel kit: Seahorse:"))]
        print(f"level {t}:", " | ".join(keep) or "no output")
        found = re.search(r"voxel kit: Seahorse: .*?(\d+) triangles", log)
        if found:
            io.open(os.path.join(OUT, f"t{t}.txt"), "w").write(found.group(1))
if check:
    sys.exit(0)

# ---------------------------------------------------------------- the sheet
from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageFont  # noqa: E402


def font(size, bold=True):
    names = (["C:/Windows/Fonts/arialbd.ttf", "/usr/share/fonts/TTF/DejaVuSans-Bold.ttf",
              "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"] if bold else
             ["C:/Windows/Fonts/arial.ttf", "/usr/share/fonts/TTF/DejaVuSans.ttf",
              "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"])
    for path in names:
        try:
            return ImageFont.truetype(path, size)
        except OSError:
            pass
    return ImageFont.load_default()


big, label, small = font(34), font(24), font(17, False)


def bloom(im, glow_hexes, alpha, radius=10, amount=0.5):
    """Roblox's Neon blooms: pixels near a glowing colour spread a soft halo (only on the model, never the backdrop)"""
    rgb = im.convert("RGB")
    mask = Image.new("L", im.size, 0)
    for hx in glow_hexes:
        c = tuple(int(hx[i:i + 2], 16) for i in (1, 3, 5))
        diff = ImageChops.difference(rgb, Image.new("RGB", im.size, c)).convert("L")
        mask = ImageChops.lighter(mask, diff.point(lambda v: 255 if v < 40 else 0))
    mask = ImageChops.multiply(mask, alpha.point(lambda v: 255 if v > 200 else 0))
    glow = Image.composite(rgb, Image.new("RGB", im.size, (0, 0, 0)), mask).filter(ImageFilter.GaussianBlur(radius))
    glow = glow.point(lambda v: min(255, int(v * amount * 2.2)))
    return ImageChops.screen(rgb, glow)


def render(t):
    im = Image.open(os.path.join(OUT, f"t{t}", "hero.png")).convert("RGBA")
    back = Image.new("RGBA", im.size, BG + (255,))
    back.alpha_composite(im)
    model = runpy.run_path(model_of(t))
    hexes = [model["PALETTE"][n] for n in model.get("GLOW", {}) if n in model["PALETTE"]]
    if model.get("VARIANT"):
        hexes.append(model.get("ACCENT", "#FFFFFF"))
    white = all(h.upper() == "#FFFFFF" for h in hexes)
    out = bloom(back, hexes, im.split()[3], amount=0.3 if white else 0.5) if hexes else back.convert("RGB")
    return out, im.getbbox(), model


renders = {t: render(t) for t in range(1, 13)}
# one crop box for all twelve, so they share a scale (the stand is the same size on every level)
boxes = [r[1] for r in renders.values()]
box = (min(b[0] for b in boxes) - 10, min(b[1] for b in boxes) - 10, max(b[2] for b in boxes) + 10, max(b[3] for b in boxes) + 10)
W, H = 360, 470
cols, rows = 6, 2


def cell(t, w, h, crop, title=True):
    im, _, model = renders[t]
    im = im.crop(crop)
    c = Image.new("RGB", (w, h), BG)
    d = ImageDraw.Draw(c)
    top = 74 if title else 10
    s = min((w - 16) / im.width, (h - top - 8) / im.height)
    im = im.resize((int(im.width * s), int(im.height * s)), Image.LANCZOS)
    c.paste(im, ((w - im.width) // 2, top + (h - top - 8 - im.height) // 2))
    if title:
        d.text((14, 10), f"{t}  {model['NAMES'][t]}", font=label, fill=(40, 40, 40))
        d.text((14, 44), NOTES[t], font=small, fill=(95, 88, 80))
    return c


grid_w = cols * (W + 10) + 10
close_h = 640
sheet = Image.new("RGB", (grid_w, 70 + rows * (H + 10) + 60 + close_h + 10), (255, 255, 255))
d = ImageDraw.Draw(sheet)
d.text((14, 14), "The seahorse trainer, levels 1 to 12 (draft 1, for Hugo's pick)", font=big, fill=(40, 40, 40))
for i, t in enumerate(range(1, 13)):
    sheet.paste(cell(t, W, H, box), (10 + (i % cols) * (W + 10), 70 + (i // cols) * (H + 10)))
y = 70 + rows * (H + 10)
d.text((14, y + 14), "Close up: levels 10 to 12 (the seahorse and the top of the spring)", font=label, fill=(40, 40, 40))
# the close-up: the upper 70% of the shared box
close = (box[0], box[1], box[2], box[1] + int((box[3] - box[1]) * 0.7))
cw = (grid_w - 40) // 3
for k, t in enumerate((10, 11, 12)):
    c = cell(t, cw, close_h, close, title=False)
    ImageDraw.Draw(c).text((14, 10), f"{t}  {renders[t][2]['NAMES'][t]}", font=label, fill=(40, 40, 40))
    sheet.paste(c, (10 + k * (cw + 10), y + 56))
sheet.save(SHEET, optimize=True)
print(SHEET, sheet.size)
