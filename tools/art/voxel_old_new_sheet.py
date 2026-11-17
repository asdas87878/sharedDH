"""One sheet of creatures, each old model beside its trial remodel (docs/style/09-early-remodels.md).
usage: python tools/art/voxel_old_new_sheet.py <out name.jpg> "<title>" Folder=Nice ...
Folder is the OLD model's folder; its trial is Trial<Folder>. Both must have been previewed (work/voxel/hand/<Folder>/hero.png).
A trial that isn't built yet is left as an empty cell."""
import os
import sys

from PIL import Image, ImageDraw

from voxel_paths import ROOT as R, WORK as S, font as face

BG = (254, 248, 241)
out_name, title, names = sys.argv[1], sys.argv[2], [a.split("=") for a in sys.argv[3:]]
W, H, PAD, PAIRS = 420, 300, 8, 2  # a cell; pairs across
label, big, small = face("arialbd.ttf", 20), face("ariblk.ttf", 30), face("arial.ttf", 15)


def cell(folder, tag):
    c = Image.new("RGB", (W, H), BG)
    path = f"{S}hand/{folder}/hero.png"
    if os.path.exists(path):
        im = Image.open(path).convert("RGBA")
        im = im.crop(im.getbbox())
        im.thumbnail((W - 20, H - 44), Image.LANCZOS)
        c.paste(im, ((W - im.width) // 2, 34 + (H - 44 - im.height) // 2), im)
    ImageDraw.Draw(c).text((8, 8), tag, font=small, fill=(110, 110, 110))
    return c


rows = (len(names) + PAIRS - 1) // PAIRS
pair_w = 2 * W + PAD
out = Image.new("RGB", (PAD + PAIRS * (pair_w + 3 * PAD), 64 + rows * (H + 34 + PAD)), (255, 255, 255))
d = ImageDraw.Draw(out)
d.text((PAD + 4, 12), title, font=big, fill=(30, 30, 30))
for k, (folder, nice) in enumerate(names):
    x, y = PAD + (k % PAIRS) * (pair_w + 3 * PAD), 64 + (k // PAIRS) * (H + 34 + PAD)
    d.text((x + 4, y + 4), nice, font=label, fill=(30, 30, 30))
    out.paste(cell(folder, "in the game now"), (x, y + 32))
    out.paste(cell("Trial" + folder, "remodel"), (x + W + PAD, y + 32))
out.save(R + "docs/attachments/" + out_name, quality=88)
print(out_name, out.size)
