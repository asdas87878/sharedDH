"""The land strip's padlock, drawn in the style of the HUD's icon pack (gvesster's Free Icon Pack: the Index's book, the
Shop's basket, the cash; task k1, Hugo 2026-11-19: "just as stylised as the text ... the same style as the icons").
The pack's rules, read off our three copies in art/ui/icons_src/: one thick ink outline round the whole silhouette and
none inside (ink 4,4,53, about 6 % of the icon; heavier here, 8 %, so it holds at the strip's 20 px); flat faces in a
3/4 view, light top, mid front, dark side; a pale strip on the front's top edge; white four-point glints on corners.
The gold is the cash band's, the steel the basket handle's.

    ~/.cache/sharedDH-venv/bin/python tools/ui/lock_icon/lock_art.py [--studio]

Writes art/ui/icons/lock.png (the whole lock, 256 px), art/ui/icons/lock_atlas.png (the whole lock and its break
pieces: shackle, two body halves along a zigzag crack, three chips, the white glint) with lock_atlas.json (each piece's
rect in the atlas and its box in the lock's square, as fractions), and work/locks2/lock_preview.png (at the strip's real
size on the darkened tiles, and big). With --studio also a copy of the atlas in Studio's own content folder
(rbxasset://textures/ridefish/lock_atlas_k1.png), as atlas.py does for the land pictures.
"""

import json
import shutil
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[3]
S = 1024  # drawing square; the cell is S / 4 = 256
CELL = 256
INK = (4, 4, 53)
GOLD_TOP = (255, 226, 120)
GOLD_FRONT = (255, 190, 30)
GOLD_LIP = (255, 214, 90)
GOLD_SIDE = (255, 140, 31)
GOLD_DEEP = (236, 110, 30)
STEEL_LIGHT = (196, 226, 240)
STEEL = (129, 176, 201)
STEEL_DARK = (92, 130, 160)
WHITE = (255, 255, 255)
OUTLINE = 82  # ink round each piece, in drawing pixels (8 % of the cell)

# the body: a front face, a side face to the right and a top face, the depth going up and right
FX0, FX1, FY0, FY1 = 190, 700, 470, 905
DX, DY = 120, -78
CRACK = [(452, FY0 + DY // 2), (420, 560), (486, 640), (430, 720), (494, 800), (448, FY1 + 6)]


def layer():
    return Image.new("RGBA", (S, S), (0, 0, 0, 0))


def body(img):
    d = ImageDraw.Draw(img)
    # side, top, then the front over both
    d.polygon([(FX1, FY0), (FX1 + DX, FY0 + DY), (FX1 + DX, FY1 + DY), (FX1, FY1)], fill=GOLD_SIDE)
    d.polygon([(FX1 + DX - 30, FY1 + DY + 20), (FX1 + DX, FY1 + DY), (FX1, FY1), (FX1 - 10, FY1)], fill=GOLD_DEEP)
    d.polygon([(FX0, FY0), (FX0 + DX, FY0 + DY), (FX1 + DX, FY0 + DY), (FX1, FY0)], fill=GOLD_TOP)
    d.rounded_rectangle([FX0, FY0, FX1, FY1], radius=26, fill=GOLD_FRONT)
    d.rectangle([FX0, FY0, FX1, FY0 + 20], fill=GOLD_FRONT)
    # the pale lip along the front's top, and a darker foot
    d.rectangle([FX0, FY0, FX1, FY0 + 56], fill=GOLD_LIP)
    d.rounded_rectangle([FX0, FY1 - 70, FX1, FY1], radius=26, fill=GOLD_SIDE)
    d.rectangle([FX0, FY1 - 70, FX1, FY1 - 40], fill=GOLD_SIDE)
    # the keyhole: a round head and a wedge, ink
    cx, cy = (FX0 + FX1) // 2, 650
    d.ellipse([cx - 52, cy - 52, cx + 52, cy + 52], fill=INK)
    d.polygon([(cx - 30, cy + 10), (cx + 30, cy + 10), (cx + 44, cy + 150), (cx - 44, cy + 150)], fill=INK)
    # the glint's long stroke down the front's left edge
    d.polygon([(FX0 + 26, FY0 + 80), (FX0 + 56, FY0 + 80), (FX0 + 50, FY1 - 110), (FX0 + 26, FY1 - 96)], fill=GOLD_LIP)


def shackle(img):
    d = ImageDraw.Draw(img)
    # a thick U, its legs going down into the top face's middle
    cx = (FX0 + FX1) // 2 + DX // 2
    foot = FY0 + DY // 2 + 30
    r_out, w = 220, 112
    top = 120
    box = [cx - r_out, top, cx + r_out, top + 2 * r_out]
    d.arc(box, 180, 360, fill=STEEL, width=w)
    d.rectangle([cx - r_out, top + r_out, cx - r_out + w, foot], fill=STEEL)
    d.rectangle([cx + r_out - w, top + r_out, cx + r_out, foot], fill=STEEL_DARK)
    # the far half of the arch darker, as the right leg
    d.arc(box, 300, 360, fill=STEEL_DARK, width=w)
    # light stripe along the outside of the left leg and over the top
    inner = [cx - r_out + 22, top + 22, cx + r_out - 22, top + 2 * r_out - 22]
    d.arc(inner, 185, 285, fill=STEEL_LIGHT, width=30)
    d.rectangle([cx - r_out + 22, top + r_out - 6, cx - r_out + 52, foot - 30], fill=STEEL_LIGHT)


def glint(img, x, y, r, thin=0.22):
    """The pack's white four-point star"""
    d = ImageDraw.Draw(img)
    t = r * thin
    d.polygon([(x, y - r), (x + t, y - t), (x + r, y), (x + t, y + t), (x, y + r), (x - t, y + t), (x - r, y), (x - t, y - t)], fill=WHITE)


def arr(img):
    return np.asarray(img).astype(np.float32)


def dilate(mask, r):
    """A round dilation, as the union of the mask shifted over a disc of radius r (in steps of 4 px)"""
    out = mask.copy()
    step = 4
    for dy in range(-r, r + 1, step):
        for dx in range(-r, r + 1, step):
            if dx * dx + dy * dy > r * r:
                continue
            sh = np.roll(np.roll(mask, dy, axis=0), dx, axis=1)
            out |= sh
    return out


def outlined(fill_img):
    """The piece over its own ink outline"""
    a = arr(fill_img)
    mask = a[..., 3] > 127
    ink = dilate(mask, OUTLINE // 2)
    out = np.zeros((S, S, 4), np.float32)
    out[ink] = (*INK, 255)
    keep = a[..., 3] > 0
    alpha = a[..., 3:4] / 255
    out[..., :3] = np.where(keep[..., None], a[..., :3] * alpha + out[..., :3] * (1 - alpha), out[..., :3])
    out[..., 3] = np.where(keep | ink, 255, 0)
    return out


def cut(img, side):
    """The body cut along the zigzag crack: side -1 the left half, 1 the right"""
    m = Image.new("L", (S, S), 0)
    d = ImageDraw.Draw(m)
    edge = [(-10, -10)] + CRACK + [(-10, S + 10)] if side < 0 else [(S + 10, -10)] + CRACK + [(S + 10, S + 10)]
    d.polygon(edge, fill=255)
    out = layer()
    out.paste(img, (0, 0), m)
    return out


def small(a):
    """Down to the cell, the colour weighted by alpha, ink under what is clear (no pale fringe in Roblox)"""
    pre = a.copy()
    pre[..., :3] *= pre[..., 3:4] / 255
    im = Image.fromarray(pre.clip(0, 255).astype(np.uint8), "RGBA").resize((CELL, CELL), Image.LANCZOS)
    s = np.asarray(im).astype(np.float32)
    al = s[..., 3:4]
    col = np.where(al > 0, s[..., :3] / np.maximum(al, 1) * 255, INK)
    col = np.where(al < 24, INK, col)
    return np.dstack([col, al]).clip(0, 255).astype(np.uint8)


def build():
    b = layer()
    body(b)
    sh = layer()
    shackle(sh)
    # the whole lock: shackle behind the body, one outline round both, then the glints
    whole = layer()
    whole.alpha_composite(sh)
    whole.alpha_composite(b)
    whole_a = outlined(whole)
    g = layer()
    glint(g, FX0 + 40, FY0 + 66, 74)
    glint(g, FX1 + DX - 20, FY0 + DY + 20, 46)
    glint(g, (FX0 + FX1) // 2 + DX // 2 - 220 + 56, 300, 50)
    ga = arr(g)
    whole_a = np.where(ga[..., 3:4] > 0, ga, whole_a)

    pieces = {"Whole": whole_a}
    shp = outlined(sh)
    sg = layer()
    glint(sg, (FX0 + FX1) // 2 + DX // 2 - 220 + 56, 300, 50)
    sga = arr(sg)
    pieces["Shackle"] = np.where(sga[..., 3:4] > 0, sga, shp)
    left = outlined(cut(b, -1))
    lg = layer()
    glint(lg, FX0 + 40, FY0 + 66, 74)
    lga = arr(lg)
    pieces["Left"] = np.where(lga[..., 3:4] > 0, lga, left)
    pieces["Right"] = outlined(cut(b, 1))
    # three chips off the crack: small gold triangles
    for k, tri in enumerate(
        [
            [(0, 0), (90, 20), (30, 100)],
            [(0, 30), (70, 0), (60, 80)],
            [(10, 0), (80, 50), (0, 70)],
        ]
    ):
        c = layer()
        d = ImageDraw.Draw(c)
        ox, oy = S // 2 - 40, S // 2 - 40
        pts = [(ox + x, oy + y) for x, y in tri]
        d.polygon(pts, fill=GOLD_FRONT if k != 1 else GOLD_SIDE)
        d.polygon(pts[:2] + [((pts[0][0] + pts[2][0]) / 2, (pts[0][1] + pts[2][1]) / 2)], fill=GOLD_LIP)
        pieces[f"Chip{k + 1}"] = outlined(c)
    star = layer()
    glint(star, S // 2, S // 2, S // 2 - 8, thin=0.16)
    pieces["Glint"] = arr(star)
    return pieces


def pack(pieces):
    """One atlas: each piece cropped to its own box, in a row; the box is kept as fractions of the lock's square"""
    smalls = {k: small(v) for k, v in pieces.items()}
    rects, crops = {}, {}
    for k, a in smalls.items():
        ys, xs = np.where(a[..., 3] > 8)
        x0, y0, x1, y1 = max(xs.min() - 2, 0), max(ys.min() - 2, 0), min(xs.max() + 3, CELL), min(ys.max() + 3, CELL)
        crops[k] = a[y0:y1, x0:x1]
        rects[k] = {"box": [x0 / CELL, y0 / CELL, (x1 - x0) / CELL, (y1 - y0) / CELL]}
    pad = 4
    width = sum(c.shape[1] + pad for c in crops.values()) + pad
    height = max(c.shape[0] for c in crops.values()) + 2 * pad
    atlas = np.zeros((height, width, 4), np.uint8)
    atlas[..., :3] = INK
    x = pad
    for k, c in crops.items():
        h, w = c.shape[:2]
        atlas[pad : pad + h, x : x + w] = c
        rects[k]["rect"] = [x, pad, w, h]
        x += w + pad
    return smalls, Image.fromarray(atlas, "RGBA"), rects


def preview(smalls, atlas):
    """The lock at the strip's size (20 px in a 28 px tile) on a few darkened lands, at 1x and 4x, and big"""
    tiles = [(52, 74, 96), (40, 58, 70), (70, 66, 88), (30, 40, 60)]
    sheet = Image.new("RGB", (900, 330), (20, 24, 40))
    whole = Image.fromarray(smalls["Whole"], "RGBA")
    for i, col in enumerate(tiles):
        t = Image.new("RGBA", (28, 28), (*col, 255))
        t.alpha_composite(whole.resize((20, 20), Image.LANCZOS), (4, 4))
        sheet.paste(t.convert("RGB"), (20 + i * 34, 20))
        sheet.paste(t.convert("RGB").resize((112, 112), Image.NEAREST), (20 + i * 120, 70))
    sheet.paste(Image.new("RGB", (260, 260), (60, 70, 90)), (620, 20))
    big = Image.new("RGBA", (256, 256), (60, 70, 90, 255))
    big.alpha_composite(whole)
    sheet.paste(big.convert("RGB"), (622, 22))
    a = Image.new("RGBA", atlas.size, (60, 70, 90, 255))
    a.alpha_composite(atlas)
    a = a.convert("RGB")
    a.thumbnail((580, 120))
    sheet.paste(a, (20, 200))
    return sheet


def main():
    pieces = build()
    smalls, atlas, rects = pack(pieces)
    icons = ROOT / "art/ui/icons"
    Image.fromarray(smalls["Whole"], "RGBA").save(icons / "lock.png")
    atlas.save(icons / "lock_atlas.png")
    (icons / "lock_atlas.json").write_text(json.dumps({"size": list(atlas.size), "pieces": rects}, indent=1) + "\n")
    work = ROOT / "work/locks2"
    work.mkdir(parents=True, exist_ok=True)
    preview(smalls, atlas).save(work / "lock_preview.png")
    for k, r in rects.items():
        bx = ", ".join(f"{v:.3f}" for v in r["box"])
        rc = ", ".join(str(v) for v in r["rect"])
        print(f"\t{k} = {{ rect = {{ {rc} }}, box = {{ {bx} }} }},")
    print("atlas", atlas.size)
    if "--studio" in sys.argv:
        versions = Path.home() / ".var/app/org.vinegarhq.Vinegar/data/vinegar/versions"
        for version in versions.iterdir():
            if (version / "content").is_dir():
                dest = version / "content/textures/ridefish"
                dest.mkdir(parents=True, exist_ok=True)
                shutil.copy(icons / "lock_atlas.png", dest / "lock_atlas_k1.png")
                print("copied to", dest)


if __name__ == "__main__":
    main()
