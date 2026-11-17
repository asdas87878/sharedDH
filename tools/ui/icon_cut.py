"""Readies an icon the user supplied for the HUD: takes off the pale sticker halo round its dark outline, trims it,
makes it square and small, and bleeds the outline's colour into the clear pixels (Roblox blends neighbours, and a
white clear pixel shows as a pale fringe).
    python -P tools/ui/icon_cut.py <in image> <out.png> [--size 256]
Also writes <out>_preview.png: the icon on a dark bar and on bright green, at the HUD's size and four times it.
"""
import sys
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage

src, out = Path(sys.argv[1]), Path(sys.argv[2])
size = int(sys.argv[sys.argv.index("--size") + 1]) if "--size" in sys.argv else 256

a = np.asarray(Image.open(src).convert("RGBA")).astype(np.float32)
rgb, alpha = a[..., :3], a[..., 3]
lum = rgb.mean(axis=2)
# the halo: pale pixels joined to the clear outside. Whites inside the dark outline are not joined to it, and stay
pale = (alpha < 10) | (lum > 120)
labels, _ = ndimage.label(pale)
edge = np.unique(np.concatenate([labels[0], labels[-1], labels[:, 0], labels[:, -1]]))
outside = np.isin(labels, edge[edge > 0])
keep = ~outside
# the outline's own colour: the darkest tenth of what is kept
dark = rgb[keep & (lum < np.percentile(lum[keep], 10))].mean(axis=0)
# the kept pixels next to the outside are the outline's soft edge, mixed with the halo: give them the outline's colour
# and an alpha by how dark they are
near = ndimage.binary_dilation(outside, iterations=3) & keep
soft = np.clip((150 - lum) / 90, 0, 1)
new_alpha = np.where(outside, 0, alpha)
new_alpha = np.where(near, np.minimum(new_alpha, soft * 255), new_alpha)
new_rgb = np.where(near[..., None] | outside[..., None], dark, rgb)
img = np.dstack([new_rgb, new_alpha]).clip(0, 255).astype(np.uint8)

ys, xs = np.where(new_alpha > 8)
img = img[ys.min() : ys.max() + 1, xs.min() : xs.max() + 1]
h, w = img.shape[:2]
side = int(max(h, w) * 1.04)
square = np.zeros((side, side, 4), np.uint8)
square[..., :3] = dark.astype(np.uint8)
y0, x0 = (side - h) // 2, (side - w) // 2
square[y0 : y0 + h, x0 : x0 + w] = img
# shrink with the colour weighted by its alpha, then put the outline's colour under what is clear
big = square.astype(np.float32)
pre = big.copy()
pre[..., :3] *= big[..., 3:4] / 255
small = np.asarray(Image.fromarray(pre.clip(0, 255).astype(np.uint8), "RGBA").resize((size, size), Image.LANCZOS)).astype(
    np.float32
)
al = small[..., 3:4]
col = np.where(al > 0, small[..., :3] / np.maximum(al, 1) * 255, dark)
col = np.where(al < 24, dark, col)
final = Image.fromarray(np.dstack([col, al]).clip(0, 255).astype(np.uint8), "RGBA")
out.parent.mkdir(parents=True, exist_ok=True)
final.save(out)

sheet = Image.new("RGB", (4 * 150 + 20, 170), (0, 0, 0))
for i, (back, px) in enumerate((((28, 60, 34), 39), ((90, 200, 80), 39), ((28, 60, 34), 140), ((240, 240, 240), 140))):
    tile = Image.new("RGBA", (150, 150), back + (255,))
    icon = final.resize((px, px), Image.LANCZOS)
    tile.alpha_composite(icon, ((150 - px) // 2, (150 - px) // 2))
    sheet.paste(tile.convert("RGB"), (10 + i * 150, 10))
sheet.save(out.with_name(out.stem + "_preview.png"))
print(out, final.size, "outline", dark.round().tolist(), "kept share", round(float(keep.mean()), 3))
