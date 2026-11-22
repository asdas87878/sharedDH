"""Turns the fish renders (tools/ui/export_portraits.py) into reference sheets for an image model to redraw as icons, and
cuts the redrawn sheets back into one transparent PNG per fish (the user, 2026-11-19: "we could use the icons to
chatgpt generate the icons from those").
usage: python tools/ui/icon_sheets.py make [renders] [out]     3x3 sheets, nine fish each in rarity order, + sheets.json
       python tools/ui/icon_sheets.py cut <generated sheet> <sheet number> [out] [--plan <sheets.json>]
           (a trial sheet: --plan art/ui/fish_icons/trials/trial_sheet.json, sheet number "trial")
           cuts a generated sheet (any size, the same 3x3 grid) into <Id>.png each, the white ground made see-through,
           and a check picture beside the render it came from
       python tools/ui/icon_sheets.py align <results folder> [out]
           ChatGPT's one-icon-per-render results (research/fish_icons_chatgpt/3_results/<1_test | batch_NN>/NN*.png,
           numbered as the inputs were, or named with the fish's Id): white made see-through, then each icon scaled
           and moved so its shape sits exactly where its render's did, so every icon keeps the game's framing
Defaults: art/ui/fish_icons/renders -> art/ui/fish_icons/sheets; cut and align -> art/ui/fish_icons/drawn.
"""
import json
import os
import sys

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
BASE = os.path.join(ROOT, "art", "ui", "fish_icons")
ORDER = ["Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic", "Secret"]
GRID = 3
CELL = 512  # each fish's square on a sheet: 1536 x 1536 in all


def tiers():
    found = {}
    folder = os.path.join(ROOT, "src", "shared", "Creatures")
    for name in os.listdir(folder):
        if name.endswith(".json"):
            with open(os.path.join(folder, name), encoding="utf-8") as f:
                found[name[:-5]] = json.load(f).get("Tier", "Common")
    return found


def make(renders, out):
    os.makedirs(out, exist_ok=True)
    tier = tiers()
    names = sorted((n[:-4] for n in os.listdir(renders) if n.endswith(".png")),
                   key=lambda n: (ORDER.index(tier.get(n, "Secret")) if tier.get(n, "Secret") in ORDER else 9, n))
    plan = []
    for s in range(0, len(names), GRID * GRID):
        chunk = names[s:s + GRID * GRID]
        sheet = Image.new("RGB", (GRID * CELL, GRID * CELL), (255, 255, 255))
        for k, name in enumerate(chunk):
            im = Image.open(os.path.join(renders, name + ".png")).convert("RGB").resize((CELL, CELL), Image.LANCZOS)
            sheet.paste(im, ((k % GRID) * CELL, (k // GRID) * CELL))
        number = len(plan) + 1
        sheet.save(os.path.join(out, "sheet_%02d.png" % number))
        plan.append({"Sheet": number, "Fish": chunk})
    with open(os.path.join(out, "sheets.json"), "w", encoding="utf-8") as f:
        json.dump(plan, f, indent=1)
    print("%d sheets in %s" % (len(plan), out))


def cut(generated, number, out, plan_path=None):
    os.makedirs(out, exist_ok=True)
    with open(plan_path or os.path.join(BASE, "sheets", "sheets.json"), encoding="utf-8") as f:
        plan = json.load(f)
    chunk = next(p["Fish"] for p in plan if str(p["Sheet"]) == str(number))
    im = Image.open(generated).convert("RGB")
    side = min(im.size)
    im = im.crop(((im.width - side) // 2, (im.height - side) // 2, (im.width + side) // 2, (im.height + side) // 2))
    step = side / GRID
    checks = []
    for k, name in enumerate(chunk):
        x, y = (k % GRID) * step, (k // GRID) * step
        cell = im.crop((round(x), round(y), round(x + step), round(y + step))).resize((512, 512), Image.LANCZOS)
        # the white ground made see-through: anything near white that touches the edge (flood from the corners), so
        # white inside the creature (teeth, bellies) stays
        rgba = cell.convert("RGBA")
        mask = Image.new("L", cell.size, 0)
        near = cell.convert("L").point(lambda v: 255 if v >= 236 else 0)
        flood = near.copy()
        for corner in [(0, 0), (511, 0), (0, 511), (511, 511)]:
            if flood.getpixel(corner) == 255:
                ImageDraw.floodfill(flood, corner, 128)
        mask = flood.point(lambda v: 0 if v == 128 else 255).filter(ImageFilter.GaussianBlur(0.7))
        rgba.putalpha(mask)
        rgba.save(os.path.join(out, name + ".png"))
        checks.append(name)
    # a check picture: each render beside its drawing, on a mid grey
    font = ImageFont.truetype(r"C:\Windows\Fonts\arialbd.ttf", 16)
    check = Image.new("RGB", (len(checks) * 260, 540), (120, 128, 140))
    draw = ImageDraw.Draw(check)
    for k, name in enumerate(checks):
        render = Image.open(os.path.join(BASE, "renders", name + ".png")).convert("RGB").resize((256, 256))
        drawn = Image.open(os.path.join(out, name + ".png")).resize((256, 256), Image.LANCZOS)
        check.paste(render, (k * 260, 0))
        check.paste(drawn, (k * 260, 262), drawn)
        draw.text((k * 260 + 4, 522), name, font=font, fill=(255, 255, 255))
    check.save(os.path.join(out, "check_%s.jpg" % number), quality=88)
    print("%d icons from sheet %d into %s" % (len(checks), number, out))


def see_through(cell):
    """the white ground made see-through (flooded in from the edges, so white inside the creature stays)"""
    cell = cell.convert("RGBA")
    if cell.getextrema()[3][0] < 250:
        return cell  # it came with its own see-through ground
    rgb = cell.convert("RGB")
    near = rgb.convert("L").point(lambda v: 255 if v >= 236 else 0)
    w, h = near.size
    for corner in [(0, 0), (w - 1, 0), (0, h - 1), (w - 1, h - 1)]:
        if near.getpixel(corner) == 255:
            ImageDraw.floodfill(near, corner, 128)
    mask = near.point(lambda v: 0 if v == 128 else 255).filter(ImageFilter.GaussianBlur(0.7))
    cell.putalpha(mask)
    return cell


def shape_box(im):
    """the box round what is not see-through or white, in shares of the picture"""
    a = see_through(im).getchannel("A")
    box = a.point(lambda v: 255 if v > 128 else 0).getbbox()
    w, h = im.size
    return (box[0] / w, box[1] / h, box[2] / w, box[3] / h) if box else (0, 0, 1, 1)


def align(results, out):
    os.makedirs(out, exist_ok=True)
    with open(os.path.join(ROOT, "research", "fish_icons_chatgpt", "plan.json"), encoding="utf-8") as f:
        plan = json.load(f)
    groups = {"1_test": plan["test"]}
    for k, names in enumerate(plan["batches"]):
        groups["batch_%02d" % (k + 1)] = names
    known = {n for names in groups.values() for n in names}
    done = []
    for base, _dirs, files in os.walk(results):
        group = os.path.basename(base)
        for f in sorted(files):
            if not f.lower().endswith((".png", ".jpg", ".jpeg", ".webp")):
                continue
            stem = os.path.splitext(f)[0]
            name = next((n for n in known if n.lower() in stem.lower()), None)
            if not name and group in groups and stem[:2].isdigit():
                k = int(stem[:2]) - 1
                if 0 <= k < len(groups[group]):
                    name = groups[group][k]
            if not name:
                print("skipped (no fish to match):", os.path.join(base, f))
                continue
            drawn = see_through(Image.open(os.path.join(base, f)))
            render = Image.open(os.path.join(BASE, "renders", name + ".png"))
            want, got = shape_box(render), shape_box(drawn)
            size = 512
            # one scale, the mean of the two that would match width and height, so nothing is stretched
            sx = (want[2] - want[0]) / max(got[2] - got[0], 1e-3)
            sy = (want[3] - want[1]) / max(got[3] - got[1], 1e-3)
            scale = (sx + sy) / 2 * size / drawn.width
            big = drawn.resize((max(1, round(drawn.width * scale)), max(1, round(drawn.height * scale))), Image.LANCZOS)
            gx, gy = (got[0] + got[2]) / 2 * big.width, (got[1] + got[3]) / 2 * big.height
            wx, wy = (want[0] + want[2]) / 2 * size, (want[1] + want[3]) / 2 * size
            canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))
            canvas.paste(big, (round(wx - gx), round(wy - gy)), big)
            canvas.save(os.path.join(out, name + ".png"))
            done.append(name)
    # a check picture: each render above its drawn icon, on a mid grey
    if done:
        font = ImageFont.truetype(r"C:\Windows\Fonts\arialbd.ttf", 14)
        per = 10
        rows = (len(done) + per - 1) // per
        check = Image.new("RGB", (per * 200, rows * 420), (120, 128, 140))
        draw = ImageDraw.Draw(check)
        for k, name in enumerate(done):
            x, y = (k % per) * 200, (k // per) * 420
            check.paste(Image.open(os.path.join(BASE, "renders", name + ".png")).convert("RGB").resize((196, 196)), (x, y))
            icon = Image.open(os.path.join(out, name + ".png")).resize((196, 196), Image.LANCZOS)
            check.paste(icon, (x, y + 200), icon)
            draw.text((x + 4, y + 400), name, font=font, fill=(255, 255, 255))
        check.save(os.path.join(out, "check_aligned.jpg"), quality=88)
    print("%d icons aligned into %s" % (len(done), out))


def main():
    args = sys.argv[1:]
    if args[0] == "make":
        make(args[1] if len(args) > 1 else os.path.join(BASE, "renders"),
             args[2] if len(args) > 2 else os.path.join(BASE, "sheets"))
    elif args[0] == "align":
        align(args[1], args[2] if len(args) > 2 else os.path.join(BASE, "drawn"))
    elif args[0] == "cut":
        plan = None
        if "--plan" in args:
            at = args.index("--plan")
            plan = args[at + 1]
            args = args[:at] + args[at + 2:]
        cut(args[1], args[2], args[3] if len(args) > 3 else os.path.join(BASE, "drawn"), plan)


if __name__ == "__main__":
    main()
