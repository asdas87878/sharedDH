"""The texture sheets of docs/style/06-textures.md, from the renders voxel_looks.py makes. usage: python tools/art/voxel_look_sheets.py <placement|shape|directions|variants|spread> ..."""
import os
import sys

from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageFont

from voxel_paths import ROOT as R, WORK as S, font as face
A = R + "docs/attachments/"
BG = (254, 248, 241)
big = face("ariblk.ttf", 30)
font = face("arialbd.ttf", 22)
small = face("arial.ttf", 18)


def flat(p):
    im = Image.open(p).convert("RGBA")
    im = im.crop(im.getbbox())
    b = Image.new("RGBA", im.size, BG + (255,))
    b.alpha_composite(im)
    return b.convert("RGB")


def bloom(im, radius=9, amount=0.38):
    r, g, b = im.split()
    hot = ImageChops.multiply(ImageChops.multiply(r.point(lambda v: 255 if v > 205 else 0), b.point(lambda v: 255 if v < 115 else 0)),
                              g.point(lambda v: 255 if 80 < v < 200 else 0))
    cold = ImageChops.multiply(ImageChops.multiply(b.point(lambda v: 255 if v > 180 else 0), r.point(lambda v: 255 if v < 150 else 0)),
                               g.point(lambda v: 255 if v > 200 else 0))
    mask = ImageChops.lighter(hot, cold)
    glow = Image.composite(im, Image.new("RGB", im.size, (0, 0, 0)), mask).filter(ImageFilter.GaussianBlur(radius))
    glow = glow.point(lambda v: min(255, int(v * amount * 2.2)))
    return ImageChops.screen(im, glow)


def cell(im, w, h, label, note=""):
    c = Image.new("RGB", (w, h), BG)
    s = min((w - 30) / im.width, (h - 84) / im.height)
    im = im.resize((int(im.width * s), int(im.height * s)), Image.LANCZOS)
    c.paste(im, ((w - im.width) // 2, 50 + (h - 84 - im.height) // 2))
    d = ImageDraw.Draw(c)
    d.text((14, 10), label, font=font, fill=(40, 40, 40))
    if note:
        d.text((14, h - 30), note, font=small, fill=(110, 100, 90))
    return c


def hero(tag, view="hero"):
    return flat(f"{S}tex/{tag}/{view}.png")


def sheet(title, rows, name, w, h):
    cols = max(len(r) for r in rows)
    out = Image.new("RGB", (cols * (w + 10) + 10, len(rows) * (h + 10) + 64), (255, 255, 255))
    ImageDraw.Draw(out).text((14, 12), title, font=big, fill=(40, 40, 40))
    for j, row in enumerate(rows):
        for i, c in enumerate(row):
            out.paste(c, (10 + i * (w + 10), 60 + j * (h + 10)))
    out.save(A + name, quality=90)
    print(name, out.size)


for which in sys.argv[1:]:
    if which == "placement":
        W, H = 900, 560
        looks = (("top", "1. From the top only", "the usual: studs on faces that look up, the sides plain"),
                 ("topsides", "2. Top and sides", "for some: the flanks carry them too"),
                 ("sel_dark", "3. Selective", "one part of the body carries them, and only that part: here the dark back"),
                 ("all", "4. The whole thing", "rare: every face, belly and fins too"))
        rows = [[cell(hero(f"ReefShark_{k}"), W, H, label, note), cell(hero(f"ReefShark_{k}", "top" if k != "all" else "side"), W, H, "from above" if k != "all" else "from the side")]
                for k, label, note in looks]
        sheet("Where the studs go (round studs, one to a cube)", rows, "texture-stud-placement.jpg", W, H)
    if which == "selective":
        W, H = 900, 500
        pairs = (("ReefShark", "Reef Shark", "sel_dark", "only the dark back", "sel_light", "only the pale belly"),
                 ("Mosasaurus", "Mosasaurus", "sel_hide", "only the hide", "sel_belly", "only the belly"),
                 ("Archelon", "Archelon", "sel_shell", "only the shell (square studs)", "sel_frame", "only the dark frame and the skin"),
                 ("Dunkleosteus", "Dunkleosteus", "sel_bone", "only the bone armour (square studs)", "sel_body", "only the body behind it"))
        rows = [[cell(bloom(hero(f"{c}_{a}")), W, H, f"{n}: {la}"), cell(bloom(hero(f"{c}_{b}")), W, H, f"{n}: {lb}")] for c, n, a, la, b, lb in pairs]
        sheet("Selective: whole parts carry the studs, and only those parts", rows, "texture-stud-selective.jpg", W, H)
    if which == "shape":
        W, H = 900, 560
        rows = [[cell(hero("ReefShark_top"), W, H, "Round, one to a cube"), cell(hero("ReefShark_square"), W, H, "Square, one to a cube")],
                [cell(hero("ReefShark_round_big"), W, H, "Round, one to two cubes", "bigger and fewer: calmer"),
                 cell(hero("ReefShark_square_big"), W, H, "Square, one to two cubes")]]
        sheet("Round studs or square, small or big (top only)", rows, "texture-stud-shapes.jpg", W, H)
    if which == "directions":
        W, H = 640, 470
        names = (("ReefShark", "Reef Shark"), ("Archelon", "Archelon"), ("Dunkleosteus", "Dunkleosteus"))
        notes = {"d1": ("A. Studs only", "round or square studs, from the top: one language for every creature"),
                 "d2": ("B. A tile for each material", "scales, scutes, plates, pleats: each surface says what it is"),
                 "d3": ("C. Studs, plus one material tile", "studs on top as the base; one other tile where the animal calls for it")}
        rows = []
        for key in ("d1", "d2", "d3"):
            row = []
            for k, (creature, nice) in enumerate(names):
                tag = f"{creature}_{key}" if not (creature == "ReefShark" and key == "d1") else "ReefShark_top"
                row.append(cell(bloom(hero(tag)), W, H, notes[key][0] if k == 0 else nice, notes[key][1] if k == 0 else ""))
            rows.append(row)
        sheet("Three directions for the textures", rows, "texture-directions.jpg", W, H)
    if which == "variants":
        W, H = 640, 470
        rows = []
        for key, label, note in (("gold", "Gold", "yellow gold, never brown; the band of light turns violet"),
                                 ("rainbow", "Rainbow", "vivid hues, mixed in very small pixels; the light turns white")):
            rows.append([cell(hero(f"{c}_{key}"), W, H, label if k == 0 else n, note if k == 0 else "")
                         for k, (c, n) in enumerate((("ReefShark", "Reef Shark"), ("Archelon", "Archelon"), ("Mosasaurus", "Mosasaurus")))])
        sheet("The rare variants: gold and rainbow (same models, no new geometry)", rows, "texture-variants.jpg", W, H)
    if which == "spread":
        W, H = 640, 470
        items = (("Mosasaurus", "Mosasaurus", "round studs on top; scales on the belly's sides"),
                 ("Basilosaurus", "Basilosaurus", "square studs on top; waves on the flank"),
                 ("SergeantMajor", "Sergeant Major", "scales on the sides only"),
                 ("Anglerfish", "Anglerfish", "pores on the skin; pleats on the belly"),
                 ("MantaRay", "Manta Ray", "spots on the back"),
                 ("Hellmaw", "Hellmaw", "a cracked crust, all over the charcoal"),
                 ("Anomalocaris", "Anomalocaris", "plates on the back; pleats on the flaps"),
                 ("BobbitWorm", "Bobbit Worm", "round studs on top of every ring"),
                 ("BlueWhale", "Blue Whale", "pleats on the throat; spots on the back"),
                 ("Kraken", "Kraken", "spots, top and sides"))
        cells = [cell(bloom(hero(f"{c}_fit")), W, H, n, note) for c, n, note in items if os.path.exists(f"{S}tex/{c}_fit/hero.png")]
        rows = [cells[i:i + 3] for i in range(0, len(cells), 3)]
        sheet("One fitting look each (a first guess per creature)", rows, "texture-spread.jpg", W, H)
