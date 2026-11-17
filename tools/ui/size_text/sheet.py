"""The size text options sheets (task u2) from the Studio captures in work/size_text/ (capture.py):
    python tools/ui/size_text/sheet.py
Writes docs/attachments/fish-tags-size-text-options-1.png (the one to answer from), ...-1-scenes.jpg (crowd and
far at real size), ...-1-all-sizes.jpg (every size and four rarities, half size) and ...-1-S7.gif.
"""
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[3]
SRC = ROOT / "work/size_text"
OUT = ROOT / "docs/attachments"
BG = (14, 18, 26)
GOLD = (255, 214, 92)
WHITE = (236, 240, 248)
GREY = (160, 170, 186)
RED = (255, 120, 120)


def font(size, bold=False):
    for name in (
        "/usr/share/fonts/TTF/DejaVuSans-Bold.ttf" if bold else "/usr/share/fonts/TTF/DejaVuSans.ttf",
        "/usr/share/fonts/dejavu/DejaVuSans-Bold.ttf" if bold else "/usr/share/fonts/dejavu/DejaVuSans.ttf",
    ):
        if Path(name).exists():
            return ImageFont.truetype(name, size)
    return ImageFont.load_default()


F_TITLE, F_SUB, F_CODE, F_TEXT, F_SMALL = font(40, True), font(22), font(34, True), font(21), font(17)

VERSIONS = [
    ("Now", "Glass chip (live today)",
     "What is wrong: a dark pill edged in the size's colour is a button, not lettering, so it reads as a sticker from "
     "another UI. Its colours (steel, mint, sky, amber, red) have nothing to do with the rarity's. The letters are tiny "
     "inside the box. The amber Huge chip fights the Legendary gold, and Colossal's gems compete with the stars."),
    ("S1", "Echo",
     "The size in the rarity word's own metal, paler and smaller: Gotham Black, ink edge, one step of depth. A glow "
     "from Giant on rarities that glow, a shine line from Huge that sweeps with the word on Legendary and up. "
     "Every size of one rarity has the same colour; only the word changes."),
    ("S2", "Size ladder",
     "The size word in its own colours, cool to hot (steel, mint, sky, amber, red), but built exactly like the rarity "
     "word: metal split at the middle, ink edge, depth. Grows from Tiny to Colossal: a shine from Giant, a glow from "
     "Huge, a sweep on Colossal. No pill."),
    ("S3", "One line: HUGE LEGENDARY",
     "The size first on the rarity's line, a step smaller, in the ladder's colours; the row under it keeps only the "
     "icons, so the tag is a line shorter. The size stays on far and crowded tags too. Long pairs "
     "(COLOSSAL LEGENDARY) make line 1 wide."),
    ("S4", "Ribbon",
     "Under the word, the size sits between two slim bars in the rarity's own metal, inside the rarity's glow, like a "
     "subtitle of the word. The bars thicken with the size; Huge and Colossal get diamond caps. Adds a thin line."),
    ("S5", "Spaced capitals",
     "Small capitals spread to the rarity word's width, like the subtitle under a logo. White up to Big, the "
     "rarity's tint from Giant, and short rules either side plus a glow on Huge and Colossal. Adds a thin line."),
    ("S6", "Soft plate",
     "The ladder word (S2) on a soft dark plate with no edge, fading out at its ends: it reads on any water, but it "
     "is still a shape behind the word."),
    ("S7", "Big two (animated)",
     "Tiny to Giant: a quiet small word in the rarity's pale tint. Huge and Colossal: a full treatment of their own "
     "(their metal, a glow, two stars, a shine that sweeps in step with the rarity word). See the GIF."),
    ("S8", "Sticker",
     "The size in the ladder's colours, tilted on the rarity word's top-left corner like a stamp. Nothing under the "
     "word; the size stays on far and crowded tags."),
]

# the real-size crops of each scene (pixels of the 1983 x 1065 game view)
NEAR = (860, 280, 1760, 600)
DARK = (900, 380, 1760, 690)
CROWD = (420, 270, 1260, 790)
FAR = (100, 120, 1480, 560)


def img(name):
    return Image.open(SRC / f"{name}.png").convert("RGB")


def wrap(draw, text, f, width):
    words, lines, line = text.split(), [], ""
    for w in words:
        t = (line + " " + w).strip()
        if draw.textlength(t, font=f) > width:
            lines.append(line)
            line = w
        else:
            line = t
    lines.append(line)
    return lines


def caption(draw, x, y, text, colour=GREY):
    draw.text((x, y), text, font=F_SMALL, fill=colour)


ZOOM_BANDS = ((170, 530), (630, 1050))  # Common and Legendary rows of a zoomA capture
ZOOM_SHOW = 0.8  # the capture is 3.6 / 1.9 = 1.9x the game; shown at 0.8, about 1.5x


def zoom_panel(code):
    z = img(f"zoomA_{code}")
    bands = [z.crop((0, t, z.width, bt)) for t, bt in ZOOM_BANDS]
    h = sum(x.height for x in bands)
    panel = Image.new("RGB", (z.width, h), BG)
    y = 0
    for x in bands:
        panel.paste(x, (0, y))
        y += x.height
    return panel.resize((round(panel.width * ZOOM_SHOW), round(h * ZOOM_SHOW)), Image.LANCZOS)


def main_sheet():
    gap = 24
    zw = round(1983 * ZOOM_SHOW)
    width = 40 + zw + gap + (NEAR[2] - NEAR[0]) + 40
    blocks = []
    for code, name, text in VERSIONS:
        za = zoom_panel(code)
        near = img(f"near_{code}").crop(NEAR)
        dark = img(f"dark_{code}").crop(DARK)
        probe = ImageDraw.Draw(Image.new("RGB", (10, 10)))
        lines = wrap(probe, text, F_TEXT, width - 80)
        head = 56 + 28 * len(lines) + 10
        body = max(za.height + 26, near.height + dark.height + 26 * 2 + 10)
        b = Image.new("RGB", (width, head + body + 30), BG)
        d = ImageDraw.Draw(b)
        d.text((40, 10), code, font=F_CODE, fill=GOLD if code != "Now" else RED)
        d.text((40 + d.textlength(code, font=F_CODE) + 18, 18), name, font=font(26, True), fill=WHITE)
        for i, l in enumerate(lines):
            d.text((40, 56 + 28 * i), l, font=F_TEXT, fill=GREY if code != "Now" else (255, 190, 190))
        y = head
        caption(d, 40, y, "Zoomed, about 1.5x the game: Common and Legendary at Tiny, Huge, Colossal")
        b.paste(za, (40, y + 24))
        x = 40 + zw + gap
        caption(d, x, y, "Real size, riding in the Shallows (Rare Huge, Legendary Colossal)")
        b.paste(near, (x, y + 24))
        y2 = y + 24 + near.height + 10
        caption(d, x, y2, "Real size, Midnight's dark water (Mythic Huge; far tags show no size)")
        b.paste(dark, (x, y2 + 24))
        blocks.append(b)
    header = Image.new("RGB", (width, 250), BG)
    d = ImageDraw.Draw(header)
    d.text((40, 24), "Fish tags: the size text in the rarity word's style (options 1, task u2)", font=F_TITLE, fill=WHITE)
    d.text((40, 84), 'Hugo, 2026-11-17: "The size text still looks really bad, give me some versions that match the rarity '
           'style more."', font=F_SUB, fill=GREY)
    d.text((40, 118), "Answer with a code (Now, S1 ... S8). A Normal fish has no size text in every version, as today. "
           "Nothing in the game changed.", font=F_SUB, fill=GREY)
    d.text((40, 152), "Rendered in Studio in Play: real fish, real HUD, the tags drawn by a mock (tools/ui/size_text). "
           "Rarities, sizes and names given to the fish for the pictures.", font=F_SUB, fill=GREY)
    d.text((40, 186), "Also: ...-1-scenes.jpg (Rare and Secret, a crowd, further off), ...-1-all-sizes.jpg (every size "
           "on four rarities), ...-1-S7.gif (S7 moving).", font=F_SUB, fill=GREY)
    total = header.height + sum(b.height for b in blocks)
    sheet = Image.new("RGB", (width, total), BG)
    sheet.paste(header, (0, 0))
    y = header.height
    for b in blocks:
        sheet.paste(b, (0, y))
        ImageDraw.Draw(sheet).line((40, y + 2, width - 40, y + 2), fill=(40, 48, 62), width=2)
        y += b.height
    sheet.save(OUT / "fish-tags-size-text-options-1.png", optimize=True)
    print("main", sheet.size)


def scenes_sheet():
    zb_w = 1090
    gap = 24
    cw, fw = CROWD[2] - CROWD[0], FAR[2] - FAR[0]
    width = 40 + zb_w + gap + cw + gap + fw + 40
    rows = []
    for code, name, _ in VERSIONS:
        zb = img(f"zoomB_{code}").resize((zb_w, round(1065 * zb_w / 1983)), Image.LANCZOS)
        crowd = img(f"crowd_{code}").crop(CROWD)
        far = img(f"far_{code}").crop(FAR)
        h = 50 + max(zb.height, crowd.height, far.height) + 24
        r = Image.new("RGB", (width, h), BG)
        d = ImageDraw.Draw(r)
        d.text((40, 8), f"{code}  {name}", font=font(28, True), fill=GOLD if code != "Now" else RED)
        x = 40
        caption(d, x, 46 - 18, "Rare and Secret at Big, Giant, Colossal (about the game's size)")
        r.paste(zb, (x, 50))
        x += zb_w + gap
        caption(d, x, 46 - 18, "Real size: a crowd in the Shallows (overlapping tags drop to the word and number)")
        r.paste(crowd, (x, 50))
        x += cw + gap
        caption(d, x, 46 - 18, "Real size: further off (tags at the game's far size)")
        r.paste(far, (x, 50))
        rows.append(r)
    head = Image.new("RGB", (width, 90), BG)
    ImageDraw.Draw(head).text((40, 24), "Size text options 1: more rarities, a crowd and further off (same codes as the "
                              "main sheet)", font=F_TITLE, fill=WHITE)
    sheet = Image.new("RGB", (width, head.height + sum(r.height for r in rows)), BG)
    sheet.paste(head, (0, 0))
    y = head.height
    for r in rows:
        sheet.paste(r, (0, y))
        y += r.height
    sheet.save(OUT / "fish-tags-size-text-options-1-scenes.jpg", quality=90)
    print("scenes", sheet.size)


def all_sizes_sheet():
    w = 991
    rows = [VERSIONS[i:i + 3] for i in range(0, 9, 3)]
    cell_h = 532 + 44
    sheet = Image.new("RGB", (40 + 3 * (w + 16) + 24, 100 + 3 * cell_h), BG)
    d = ImageDraw.Draw(sheet)
    d.text((40, 24), "Every size (columns Tiny, Normal, Big, Giant, Huge, Colossal) on Common, Rare, Legendary, "
           "Secret, half the game's size", font=font(30, True), fill=WHITE)
    for ri, row in enumerate(rows):
        for ci, (code, name, _) in enumerate(row):
            x, y = 40 + ci * (w + 16), 90 + ri * cell_h
            d.text((x, y), f"{code}  {name}", font=font(24, True), fill=GOLD if code != "Now" else RED)
            sheet.paste(img(f"grid_{code}").resize((w, 532), Image.LANCZOS), (x, y + 38))
    sheet.save(OUT / "fish-tags-size-text-options-1-all-sizes.jpg", quality=90)
    print("all sizes", sheet.size)


def gif():
    frames = []
    for i in range(27):
        p = SRC / f"gif_S7_{i:02d}.png"
        if not p.exists():
            break
        frames.append(Image.open(p).convert("RGB").crop((0, 150, 1983, 1065)).resize((793, 366), Image.LANCZOS))
    if frames:
        frames[0].save(OUT / "fish-tags-size-text-options-1-S7.gif", save_all=True, append_images=frames[1:],
                       duration=100, loop=0, optimize=True)
        print("gif", len(frames))


if __name__ == "__main__":
    main_sheet()
    scenes_sheet()
    all_sizes_sheet()
    gif()
