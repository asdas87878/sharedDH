"""How the lightness of a whole view is spread, ours against the reference (2026-11-19, the user: "how does our value
distribution compare to ride a dinos"). For each of our lands and the reference land it copies (docs/design/colour.md):
the CIE L* of every pixel of the middle of the frame (the reference's UI cropped off), as a histogram and as numbers:
the median, the spread (10th to 90th percentile), and how much of the frame is dark (L* < 35), mid (35 to 70) and light
(over 70). Also each view in grey, side by side, which shows the value pattern without the colour.

usage: python tools/art/value_compare.py <our renders folder> <out.jpg>"""
import glob
import os
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
REF = os.path.join(ROOT, "research", "ride-a-dino", "colour", "frames")
OURS = ["Shallows", "Coral Reef", "Kelp Forest", "Shipwrecks", "Open Blue", "Twilight", "Midnight", "Vents", "Bone Graveyard", "The Underworld"]
REF_OF = ["desert", "jungle", "forest", "extinction", "ocean", "snow", "snow", "volcano", "extinction", "cosmic"]


def lstar(im):
    a = np.asarray(im.convert("RGB")).astype(float) / 255.0
    lin = np.where(a <= 0.04045, a / 12.92, ((a + 0.055) / 1.055) ** 2.4)
    y = 0.2126 * lin[..., 0] + 0.7152 * lin[..., 1] + 0.0722 * lin[..., 2]
    return np.where(y > 0.008856, 116 * np.cbrt(y) - 16, 903.3 * y)


def middle(im, ui=True):
    w, h = im.size
    return im.crop((int(w * 0.12), int(h * (0.16 if ui else 0.0)), int(w * 0.88), int(h * (0.80 if ui else 1.0))))


def stats(L):
    v = L.ravel()
    return {"med": np.median(v), "p10": np.percentile(v, 10), "p90": np.percentile(v, 90), "dark": (v < 35).mean(), "mid": ((v >= 35) & (v <= 70)).mean(), "light": (v > 70).mean(), "hist": np.histogram(v, bins=20, range=(0, 100))[0] / v.size}


def ref_frames(name):
    fs = [f for f in glob.glob(os.path.join(REF, f"{name}_*.png")) + glob.glob(os.path.join(REF, "rec", f"rec_{name}_*.png"))
          if "_boxes" not in f and "night" not in f and "meteor" not in f]
    return sorted(fs)


ours_dir, out = sys.argv[1], sys.argv[2]
font, bold = ImageFont.truetype("C:/Windows/Fonts/arial.ttf", 15), ImageFont.truetype("C:/Windows/Fonts/arialbd.ttf", 17)
TW, TH, HW = 300, 170, 260
rows, lines = [], []
for i, (land, ref) in enumerate(zip(OURS, REF_OF)):
    ours = Image.open(os.path.join(ours_dir, f"land{i + 1:02d}.png"))
    o = stats(lstar(middle(ours, ui=False)))
    rfs = ref_frames(ref)
    rL = np.concatenate([lstar(middle(Image.open(f))).ravel() for f in rfs]) if rfs else None
    r = stats(rL) if rL is not None else None
    rows.append((land, ref, ours, Image.open(rfs[0]) if rfs else None, o, r))
    lines.append(f"{land} vs {ref} ({len(rfs)} frames): median {o['med']:.0f} vs {r['med']:.0f}; spread {o['p10']:.0f}-{o['p90']:.0f} vs {r['p10']:.0f}-{r['p90']:.0f}; "
                 f"dark/mid/light {o['dark']:.0%}/{o['mid']:.0%}/{o['light']:.0%} vs {r['dark']:.0%}/{r['mid']:.0%}/{r['light']:.0%}" if r else f"{land}: no reference frames")
    print(lines[-1])

im = Image.new("RGB", (40 + 2 * TW + 2 * HW + 60, 60 + len(rows) * (TH + 30)), (250, 246, 240))
d = ImageDraw.Draw(im)
d.text((10, 10), "Value: each of our lands (left, in grey) against the reference land it copies (right, in grey), with both lightness histograms (ours dark, theirs orange)", font=bold, fill=(20, 20, 20))
for k, (land, ref, ours, rimg, o, r) in enumerate(rows):
    y = 50 + k * (TH + 30)
    d.text((10, y), f"{land}  /  their {ref}", font=bold, fill=(30, 30, 30))
    g = middle(ours, ui=False).convert("L").resize((TW, TH))
    im.paste(g.convert("RGB"), (10, y + 22))
    if rimg is not None:
        im.paste(middle(rimg).convert("L").resize((TW, TH)).convert("RGB"), (20 + TW, y + 22))
    hx = 40 + 2 * TW
    d.rectangle([hx, y + 22, hx + 2 * HW, y + 22 + TH], fill=(255, 255, 255))
    peak = max(o["hist"].max(), r["hist"].max() if r else 0)
    bw = 2 * HW / 20
    for b in range(20):
        h1 = o["hist"][b] / peak * (TH - 20)
        d.rectangle([hx + b * bw + 1, y + 22 + TH - h1, hx + b * bw + bw / 2, y + 22 + TH], fill=(40, 40, 60))
        if r:
            h2 = r["hist"][b] / peak * (TH - 20)
            d.rectangle([hx + b * bw + bw / 2, y + 22 + TH - h2, hx + (b + 1) * bw - 1, y + 22 + TH], fill=(240, 140, 40))
    d.text((hx + 4, y + 24), f"ours: median {o['med']:.0f}, 10-90% {o['p10']:.0f}-{o['p90']:.0f}", font=font, fill=(40, 40, 60))
    if r:
        d.text((hx + 4, y + 42), f"theirs: median {r['med']:.0f}, 10-90% {r['p10']:.0f}-{r['p90']:.0f}", font=font, fill=(200, 100, 20))
    d.text((hx + 2 * HW - 150, y + 24), "L* 0 ... 100 ->", font=font, fill=(120, 120, 120))
im.save(out, quality=88)
open(os.path.splitext(out)[0] + ".txt", "w").write("\n".join(lines) + "\n")
print(out)
