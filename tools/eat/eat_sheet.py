"""The contact sheet and the GIFs of the eating moves, from tools/blender/eat_frames.py's pictures:
python3 tools/eat/eat_sheet.py work/eat/shots docs/attachments"""
import glob
import sys

from PIL import Image, ImageDraw, ImageFont

shots, out = sys.argv[1:3]


def font(size, bold=True):
    for f in (
        f"/usr/share/fonts/TTF/DejaVuSans{'-Bold' if bold else ''}.ttf",
        f"/usr/share/fonts/truetype/dejavu/DejaVuSans{'-Bold' if bold else ''}.ttf",
    ):
        try:
            return ImageFont.truetype(f, size)
        except OSError:
            pass
    hits = glob.glob(f"/usr/share/fonts/**/*Sans{'-Bold' if bold else '-Regular'}.ttf", recursive=True)
    return ImageFont.truetype(hits[0], size) if hits else ImageFont.load_default(size)


NEW = {
    "Wrap": (
        "The octopus drags you down (new)",
        [
            "0.03  riding",
            "0.3  brakes, flares, tosses you",
            "0.5  open like a flower",
            "0.7  tips back, you at the top",
            "0.9  first arm takes you",
            "1.1  second arm",
            "1.3  third; drawn in",
            "1.6  the beat of stillness",
            "2.0  the jet, and ink",
            "2.35  down into the dark",
        ],
    ),
    "Chomp": (
        "Kronosaurus eats you (new)",
        [
            "0.03  riding",
            "0.25  brakes, flippers out",
            "0.45  bucks you up and ahead",
            "0.65  nose down, you sail past",
            "0.9  rises behind you, jaw open",
            "1.1  wound up: the hold",
            "1.27  the lunge",
            "1.35  has you, mid water",
            "1.42  snap",
            "1.8  the gulp, the settle",
        ],
    ),
}
OLD = {"Wrap": "Today (it turns round on you)", "Chomp": "Today (it turns round on you)"}
W, H, PAD = 400, 225, 6
CROP = 1.0
cols = 5
rowh = H + 26
sheet_w = cols * (W + PAD) + PAD
rows = []
for kind in ("Wrap", "Chomp"):
    rows.append(("title", NEW[kind][0] + ": the game's camera"))
    for part in range(2):
        rows.append(("new", kind, part))
    rows.append(("title", "The same ten moments from the side"))
    rows.append(("side", kind, 0))
    rows.append(("side", kind, 1))
    rows.append(("title", OLD[kind]))
    rows.append(("old", kind, 0))
    rows.append(("old", kind, 1))
height = {"title": 46, "new": rowh, "side": 150, "old": 150}
total = sum(height[r[0]] for r in rows) + 40
im = Image.new("RGB", (sheet_w, total), (18, 26, 38))
d = ImageDraw.Draw(im)
y = 6
for r in rows:
    if r[0] == "title":
        d.text((PAD + 4, y + 10), r[1], font=font(22), fill=(255, 255, 255))
    else:
        what, kind, part = r
        tag = f"{kind}_{'old' if what == 'old' else 'new'}"
        for c in range(cols):
            i = part * cols + c
            x = PAD + c * (W + PAD)
            p = Image.open(f"{shots}/{tag}_{i:02d}_{'side' if what == 'side' else 'game'}.png").convert("RGB")
            if what == "new":
                im.paste(p.resize((W, H), Image.LANCZOS), (x, y))
                d.text((x + 4, y + H + 3), NEW[kind][1][i], font=font(15), fill=(220, 235, 245))
            else:
                w2, h2 = p.size
                ch = int(w2 * 142 / W)
                p = p.crop((0, (h2 - ch) // 2, w2, (h2 - ch) // 2 + ch))
                im.paste(p.resize((W, 142), Image.LANCZOS), (x, y))
    y += height[r[0]]
d.text(
    (PAD + 4, y + 6),
    "Drawn offline from the game's own code and models (Normal size). The rider is a stiff stand-in for the loose body; "
    "the ink is a sketch; the game's dark water is left out so the moves can be seen.",
    font=font(15, False),
    fill=(170, 190, 205),
)
im.save(f"{out}/eat-anim-frames.png")

# side by side: today, new
for kind, name in (("Wrap", "octopus"), ("Chomp", "kronosaurus")):
    a = sorted(glob.glob(f"{shots}/{kind}_old_g*.png"))
    b = sorted(glob.glob(f"{shots}/{kind}_new_g*.png"))
    if not a:
        continue
    frames = []
    for i in range(max(len(a), len(b))):
        f = Image.new("RGB", (480 * 2 + 6, 270 + 28), (18, 26, 38))
        g = ImageDraw.Draw(f)
        f.paste(Image.open(a[min(i, len(a) - 1)]).convert("RGB"), (0, 28))
        f.paste(Image.open(b[min(i, len(b) - 1)]).convert("RGB"), (486, 28))
        g.text((8, 5), "today", font=font(16), fill=(255, 255, 255))
        g.text((494, 5), "new", font=font(16), fill=(255, 255, 255))
        frames.append(f.quantize(96))
    frames[0].save(
        f"{out}/eat-anim-{name}.gif", save_all=True, append_images=frames[1:] + [frames[-1]] * 10, duration=50, loop=0
    )
