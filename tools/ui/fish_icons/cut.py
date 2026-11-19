"""The fish icons from the partner's renders (task r1, Hugo 2026-11-19: "wasnt there other icons of the fishes that my
partner made? check and replace if there is, just the renders though").

Each fish's picture is the "Three-quarter" panel of its render sheet, docs/attachments/voxel-<fish>.jpg (the top-left
panel on a cream ground). art/creatures/<Fish>/renders/hero.png is NOT used: those are the older faceted kit's renders
(2026-11-09), not the voxel models in the game. The cream ground is taken off by a flood from the panel's edge (so a
cream eye inside the fish stays), the panel's own words are dropped (small pieces in its top and bottom bands), the edge
is softened by how far each edge pixel is from cream, and the picture is trimmed. A long creature (more than LONG times
as wide as tall) is cut to its front end, head at the left, the rest running off the right edge, as the live portraits
show a bust.

    work/.venv/bin/python tools/ui/fish_icons/cut.py [--studio]

writes docs/attachments/fish-icons/fish_icons_<page>.png (the pages to upload, 1024 square, CELL-pixel cells),
docs/attachments/fish-icons/contact.png (every icon on a mid grey, to check by eye), and src/client/UI/FishIcons.luau
(where each fish is in which page). --studio also copies the pages into Studio's own content folder
(rbxasset://textures/ridefish/fish_icons_<page>.png), which the game reads in Studio until the pages are uploaded.
"""
import json
import re
import shutil
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage

ROOT = Path(__file__).resolve().parents[3]
SHEETS = ROOT / "docs/attachments"
OUT = ROOT / "docs/attachments/fish-icons"
LUAU = ROOT / "src/client/UI/FishIcons.luau"
VERSIONS = Path.home() / ".var/app/org.vinegarhq.Vinegar/data/vinegar/versions"
CELL = 170  # pixels: 6 by 6 cells on a 1024 page (Roblox shrinks anything bigger to 1024)
PER_ROW = 6
PER_PAGE = PER_ROW * PER_ROW
PAD = 4  # clear pixels round each cell's picture, so neighbours never bleed in
LONG = 2.15  # wider than tall by this: shown by its front end
BUST = 1.55  # a bust's width over its height
# a fish whose own sheet has another name (the base fish's newest sheet)
SHEET = {
    "Dunkleosteus": "dunkleosteus-legendary",
    "Hellmaw": "hellmaw-mythic",
    "BlueWhale": "bluewhale-old-one",
}
# a sheet drawn before the model was last changed (voxel.py edited after the sheet): the icon may not match the game
STALE = {
    "BlueWhale": "the sheet is the old Blue Whale; voxel.py was rebuilt 2026-11-12",
    "Dunkleosteus": "voxel.py edited 44 min after the sheet (2026-11-10)",
    "Hellmaw": "voxel.py edited after the Mythic sheet (2026-11-10)",
}


def fish_ids():
    src = (ROOT / "src/shared/Config.luau").read_text()
    block = src[src.index("Config.FishStats = {") :]
    block = block[: block.index("\n}\n")]
    return re.findall(r"^\t(\w+) = \{", block, re.M)


def sheet_for(fish):
    path = SHEETS / f"voxel-{SHEET.get(fish, fish.lower())}.jpg"
    return path if path.exists() else None


def panel(a):
    """The Three-quarter panel's box and its cream: the cream area met first going down the sheet's left side."""
    h, w = a.shape[:2]
    x = int(w * 0.03)
    for y in range(int(h * 0.02), h // 2):
        px = a[y, x]
        if px.min() > 235 and px[0] - px[2] > 4:  # cream, not the white page
            cream = a[y : y + 6, x : x + 6].reshape(-1, 3).mean(axis=0)
            near = np.abs(a - cream).max(axis=2) < 10
            labels, _ = ndimage.label(near)
            ys, xs = np.where(labels == labels[y, x])
            return (ys.min(), ys.max() + 1, xs.min(), xs.max() + 1), cream
    raise ValueError("no cream panel")


def cut(path):
    a = np.asarray(Image.open(path).convert("RGB")).astype(np.float32)
    (y0, y1, x0, x1), cream = panel(a)
    p = a[y0:y1, x0:x1]
    ph, pw = p.shape[:2]
    dist = np.abs(p - cream).max(axis=2)
    # the ground: near-cream pixels joined to the panel's edge
    pale = dist < 26
    labels, _ = ndimage.label(pale)
    edge = np.unique(np.concatenate([labels[0], labels[-1], labels[:, 0], labels[:, -1]]))
    ground = np.isin(labels, edge[edge > 0])
    fg = ~ground
    # the words: pieces of the foreground in the panel's top and bottom bands that are small next to the fish
    parts, n = ndimage.label(fg)
    sizes = ndimage.sum(fg, parts, range(1, n + 1))
    biggest = sizes.max()
    boxes = ndimage.find_objects(parts)
    keep = np.zeros(n + 1, bool)
    band = ph * 0.11
    for i, (box, size) in enumerate(zip(boxes, sizes), start=1):
        top, bottom = box[0].start, box[0].stop
        in_band = bottom < band or top > ph - band
        if size >= biggest * 0.04 or (size >= 12 and not in_band):
            keep[i] = True
    fg = keep[parts]
    fg = ndimage.binary_fill_holes(fg) & (fg | ~ground)  # pale holes not joined to the edge are the fish's own
    # soft edge: a ring two pixels deep gets its alpha by how far from cream it is, and its colour un-mixed from cream
    ring = fg & ~ndimage.binary_erosion(fg, iterations=2)
    alpha = np.where(fg, 1.0, 0.0)
    alpha = np.where(ring, np.clip(dist / 60, 0.25, 1.0), alpha)
    rgb = np.where(
        ring[..., None], (p - (1 - alpha[..., None]) * cream) / np.maximum(alpha[..., None], 0.25), p
    ).clip(0, 255)
    ys, xs = np.where(alpha > 0)
    t, b, l, r = ys.min(), ys.max() + 1, xs.min(), xs.max() + 1
    rgba = np.dstack([rgb, alpha * 255])[t:b, l:r]
    h, w = rgba.shape[:2]
    bust = w > h * LONG
    if bust:  # its front end: the head is at the panel's left
        rgba = rgba[:, : int(h * BUST)]
        ys, _ = np.where(rgba[..., 3] > 0)
        rgba = rgba[ys.min() : ys.max() + 1]
    return rgba, bust


def shrink(rgba, size):
    """Resized to fit a size-pixel square with its colour weighted by alpha, then the colour bled under clear pixels
    (Roblox blends neighbouring pixels, and a cream or black clear pixel shows as a fringe)."""
    h, w = rgba.shape[:2]
    k = (size - 2 * PAD) / max(h, w)
    nw, nh = max(1, round(w * k)), max(1, round(h * k))
    pre = rgba.copy()
    pre[..., :3] *= pre[..., 3:4] / 255
    small = np.asarray(Image.fromarray(pre.clip(0, 255).astype(np.uint8), "RGBA").resize((nw, nh), Image.LANCZOS))
    small = small.astype(np.float32)
    al = small[..., 3]
    col = small[..., :3] / np.maximum(al[..., None], 1) * 255
    solid = al > 24
    # bleed: each clear pixel takes the colour of the nearest solid one
    _, (iy, ix) = ndimage.distance_transform_edt(~solid, return_indices=True)
    col = np.where(solid[..., None], col, col[iy, ix])
    return np.dstack([col, al]).clip(0, 255).astype(np.uint8)


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    ids = fish_ids()
    found, missing = [], []
    for fish in ids:
        (found if sheet_for(fish) else missing).append(fish)
    pages = [Image.new("RGBA", (1024, 1024), (0, 0, 0, 0)) for _ in range((len(found) + PER_PAGE - 1) // PER_PAGE)]
    rows = []
    contact = Image.new("RGB", (12 * 130, ((len(found) + 11) // 12) * 150), (120, 124, 132))
    draw = ImageDraw.Draw(contact)
    for i, fish in enumerate(found):
        rgba, bust = cut(sheet_for(fish))
        icon = shrink(rgba, CELL)
        page, at = divmod(i, PER_PAGE)
        cy, cx = divmod(at, PER_ROW)
        h, w = icon.shape[:2]
        ox, oy = cx * CELL + (CELL - w) // 2, cy * CELL + (CELL - h) // 2
        pages[page].paste(Image.fromarray(icon, "RGBA"), (ox, oy))
        rows.append((fish, page + 1, ox, oy, w, h, bust))
        thumb = Image.fromarray(icon, "RGBA")
        thumb.thumbnail((120, 120))
        tx, ty = (i % 12) * 130 + 5, (i // 12) * 150 + 5
        contact.paste(thumb, (tx + (120 - thumb.width) // 2, ty + (120 - thumb.height) // 2), thumb)
        draw.text((tx, ty + 124), fish + (" *" if fish in STALE else "") + (" [bust]" if bust else ""), fill=(255, 255, 255))
    for k, page in enumerate(pages, start=1):
        page.save(OUT / f"fish_icons_{k}.png")
    contact.save(OUT / "contact.png")
    (OUT / "map.json").write_text(
        json.dumps(
            {
                "fish": {f: {"sheet": sheet_for(f).name, "page": p, "rect": [x, y, w, h], "bust": b} for f, p, x, y, w, h, b in rows},
                "missing": missing,
                "stale": STALE,
                "heroNotUsed": "art/creatures/*/renders/hero.png are the old faceted kit (2026-11-09), not the game's voxel models",
            },
            indent=1,
        )
    )
    lines = [
        "--!strict",
        "-- Made by tools/ui/fish_icons/cut.py: do not edit by hand. Where each fish's render (the partner's Three-quarter",
        "-- view, docs/attachments/voxel-<fish>.jpg) sits in the icon pages: Page, and X, Y, W, H in that page's pixels.",
        "-- Bust: a long creature cut to its front end (head at the left, the rest off the right edge).",
        "-- Fish not here have no render and keep the live model picture (UI.Portrait).",
        "local FishIcons = {}",
        "",
        "-- The uploaded pages' asset ids (rbxassetid://...), one per page. While a page's id is \"\" the game uses the",
        "-- live model picture, except in Studio, which reads the local copy (Studio below).",
        "FishIcons.Pages = { " + ", ".join('""' for _ in pages) + " }",
        "FishIcons.Studio = { "
        + ", ".join(f'"rbxasset://textures/ridefish/fish_icons_{k}.png"' for k in range(1, len(pages) + 1))
        + " }",
        "",
        "export type Icon = { Page: number, X: number, Y: number, W: number, H: number, Bust: boolean }",
        "FishIcons.Icons = {",
    ]
    for f, p, x, y, w, h, b in rows:
        lines.append(f"\t{f} = {{ Page = {p}, X = {x}, Y = {y}, W = {w}, H = {h}, Bust = {str(b).lower()} }},")
    lines += ["} :: { [string]: Icon }", "", "return FishIcons", ""]
    LUAU.write_text("\n".join(lines))
    print(f"{len(found)} icons on {len(pages)} pages; missing {missing}")
    if "--studio" in sys.argv:
        for version in VERSIONS.glob("version-*"):
            studio = version / "content/textures/ridefish"
            studio.mkdir(parents=True, exist_ok=True)
            for k in range(1, len(pages) + 1):
                shutil.copy(OUT / f"fish_icons_{k}.png", studio / f"fish_icons_{k}.png")
            print("copied to", studio)


if __name__ == "__main__":
    main()
