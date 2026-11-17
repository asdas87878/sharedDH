"""Our coins and Oxygen rows beside the reference's, at the same size (a row 80 pixels tall), for a close look.
    python tools/ui/rows_compare.py <reference.png> <our capture.jpg> <out.png>
The reference's picture is private: the output goes where you say, not into docs/attachments.
"""
import sys
from PIL import Image, ImageDraw, ImageFont

ref = Image.open(sys.argv[1]).convert("RGB")
ours = Image.open(sys.argv[2]).convert("RGB")
ROW = float(sys.argv[5]) if len(sys.argv) > 5 else 55.9  # our row's height in the capture (40 units)
TOP = float(sys.argv[4]) if len(sys.argv) > 4 else 665  # the upper row's top edge in the capture
s = 80 / ROW
# our rows start 14 px from the left, the upper row's top at 607; the reference's at 18 and 88
x0, y0 = 14 - 18 / s, TOP - 88 / s
crop = ours.crop((round(x0), round(y0), round(x0 + ref.width / s), round(y0 + ref.height / s)))
crop = crop.resize(ref.size, Image.LANCZOS)
Z = 3
font = ImageFont.truetype(r"C:\Windows\Fonts\arialbd.ttf", 24)
sheet = Image.new("RGB", (ref.width * Z * 2 + 48, ref.height * Z + 64), (24, 28, 38))
d = ImageDraw.Draw(sheet)
for i, (label, im) in enumerate((("Ride a Dino", ref), ("Ours", crop))):
    x = 16 + i * (ref.width * Z + 16)
    d.text((x, 14), label, font=font, fill=(255, 226, 120))
    sheet.paste(im.resize((im.width * Z, im.height * Z), Image.LANCZOS), (x, 52))
sheet.save(sys.argv[3])
print(sheet.size)
