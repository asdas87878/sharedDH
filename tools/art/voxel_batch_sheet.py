"""usage: python tools/art/voxel_batch_sheet.py <out name> "<title>" Folder=Nice ... : one sheet of first drafts, three across"""
import sys
from PIL import Image, ImageDraw

from voxel_paths import ROOT as R, WORK as S, font as face
BG = (254, 248, 241)
font = face("arialbd.ttf", 22)
big = face("ariblk.ttf", 30)
def flat(p):
    im = Image.open(p).convert("RGBA"); im = im.crop(im.getbbox())
    b = Image.new("RGBA", im.size, BG + (255,)); b.alpha_composite(im); return b.convert("RGB")
out_name, title, names = sys.argv[1], sys.argv[2], [a.split("=") for a in sys.argv[3:]]
W, H = 620, 430
rows = (len(names) + 2) // 3
out = Image.new("RGB", (3 * (W + 10) + 10, rows * (H + 10) + 64), (255, 255, 255))
ImageDraw.Draw(out).text((14, 12), title, font=big, fill=(40, 40, 40))
for k, (n, nice) in enumerate(names):
    c = Image.new("RGB", (W, H), BG); im = flat(f"{S}hand/{n}/hero.png")
    s = min((W - 20) / im.width, (H - 60) / im.height); im = im.resize((int(im.width * s), int(im.height * s)), Image.LANCZOS)
    c.paste(im, ((W - im.width) // 2, 46 + (H - 60 - im.height) // 2)); ImageDraw.Draw(c).text((12, 8), nice, font=font, fill=(40, 40, 40))
    out.paste(c, (10 + (k % 3) * (W + 10), 60 + (k // 3) * (H + 10)))
out.save(R + "docs/attachments/" + out_name, quality=88)
print(out.size)
