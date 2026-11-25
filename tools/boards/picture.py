"""The leaderboards' picture, offline (NULLROOM task l1): the panels as the real UI.BoardPanel builds them
(tools/boards/panel_test.luau's trees, drawn by headless Chromium as tools/index/panel_picture.py does), on the frames
as Shared/Boards draws them, in the hub as the saved place has it (Blender). Not Roblox's renderer: the letters are a
hair different, the light is Blender's, there are no studs on the ground, and the faces are made-up samples.

    rojo build -o /tmp/b/place.rbxl
    lune run tools/boards/panel_test.luau /tmp/b/place.rbxl /tmp/b
    lune run tools/boards/hub_parts.luau <saved place.rbxl> /tmp/b/hub.json
    python tools/boards/picture.py /tmp/b panels     the panels' pictures
    blender -b --factory-startup -P tools/boards/view.py -- /tmp/b
    python tools/boards/picture.py /tmp/b sheet docs/attachments/leaderboards-2.png
"""
import hashlib
import json
import subprocess
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools/index"))
import panel_picture as base  # noqa: E402

WORK = Path(sys.argv[1]).resolve()
STUDIO = [f.parents[1] / "StudioFonts" for f in base.FONTS]
PLAIN = {"BuilderSansBold": "BuilderSans-Bold.otf", "BuilderSansExtraBold": "BuilderSans-ExtraBold.otf"}
FONT = next((f / "FredokaOne-Regular.ttf" for f in reversed(base.FONTS) if (f / "FredokaOne-Regular.ttf").exists()), None)


def file_of(name):
    """the file of one of Roblox's fonts; the HUD's own for any other"""
    return next((f / PLAIN[name] for f in reversed(STUDIO) if name in PLAIN and (f / PLAIN[name]).exists()), FONT)


def font(size, name="FredokaOne"):
    file = file_of(name)
    return ImageFont.truetype(str(file), int(size)) if file else ImageFont.load_default(size)


def named(p):
    return str(p.get("Font", "FredokaOne")).split(".")[-1]


def face(user):
    """a made-up blocky head for a sample player"""
    file = WORK / f"face-{user}.png"
    if not file.exists():
        h = hashlib.md5(str(user).encode()).digest()
        skin = [(255, 214, 170), (232, 178, 128), (170, 112, 74), (120, 80, 56), (255, 226, 120), (160, 214, 255)][h[0] % 6]
        hair = [(60, 40, 30), (240, 190, 70), (200, 70, 60), (40, 60, 120), (110, 60, 160), (30, 150, 140)][h[1] % 6]
        image = Image.new("RGBA", (150, 150), (*[(150, 222, 244), (255, 214, 224), (206, 240, 190)][h[2] % 3], 255))
        d = ImageDraw.Draw(image)
        d.rounded_rectangle((40, 118, 110, 170), 12, fill=tuple(hair))
        d.rounded_rectangle((38, 34, 112, 120), 22, fill=skin)
        d.rounded_rectangle((32, 22, 118, 60), 18, fill=hair)
        for x in (58, 86):
            d.ellipse((x, 70, x + 9, 86), fill=(20, 24, 34))
        d.arc((58, 78, 92, 106), 20, 160, fill=(20, 24, 34), width=4)
        image.save(file)
    return file


class Page(base.Page):
    def picture(self, image):
        if image.startswith("rbxthumb"):
            return face(image.split("id=")[1].split("&")[0])
        return super().picture(image)

    def image(self, n, k, fill):
        body = super().image(n, k, fill)
        return body.replace('class="i" style="', 'class="i" style="border-radius:inherit;')

    def text(self, n, k, fill, stroke):
        p = n["Props"]
        if p.get("TextScaled"):
            # the biggest whole size that fits its box, as TextScaled with its limits
            wide, high = p["_box"]
            size = int(p.get("MaxTextSize", 100))
            least = int(p.get("MinTextSize", 1))
            while size > least:
                f = font(size, named(p))
                lines = p["Text"].split("\n")
                if max(f.getlength(t) for t in lines) <= wide and size * 1.12 * len(lines) <= high + 2:
                    break
                size -= 1
            p["TextSize"] = size
            f = font(size, named(p))
            if p.get("_cut") and f.getlength(p["Text"]) > wide:
                t = p["Text"]
                while f.getlength(t + "...") > wide:
                    t = t[:-1]
                p["Text"] = t + "..."
        body = super().text(n, k, fill, stroke)
        return body.replace('class="t" style="', f'class="t" style="font-family:{named(p)},F;')


def prepare(n, wide, high):
    p = n["Props"]
    size = p.get("Size")
    if size:
        wide, high = size[0] * wide + size[1], size[2] * high + size[3]
        p["_box"] = (wide, high)
        p["_cut"] = p.get("Name") in ("Name", "User")
    n["Children"] = [c for c in n["Children"] if not (c["Class"] == "UIStroke" and c["Props"].get("Enabled") is False)]
    for c in n["Children"]:
        prepare(c, wide, high)


def panels():
    for dump in sorted(WORK.glob("panel-*.json")):
        data = json.loads(dump.read_text())
        wide, high = (int(round(v)) for v in data["View"])
        for c in data["Tree"]["Children"]:
            prepare(c, wide, high)
        page = Page({})
        body = "".join(page.node(c, 1) for c in data["Tree"]["Children"])
        plain = "".join(f"@font-face{{font-family:{k};src:url({file_of(k).as_uri()})}}" for k in PLAIN)
        doc = f"""<!doctype html><meta charset="utf-8"><style>{plain}@font-face{{font-family:F;src:url({FONT.as_uri()})}}
html,body{{margin:0;width:{wide}px;height:{high}px;overflow:hidden}}
body{{position:relative;font-family:F;line-height:1.12}}div{{box-sizing:border-box}}
.s{{position:absolute;-webkit-mask:linear-gradient(#000 0 0) content-box,linear-gradient(#000 0 0);
-webkit-mask-composite:xor;mask-composite:exclude}}.i{{position:absolute;inset:0}}
.t{{display:flex;position:relative;width:100%;height:100%}}.w{{display:inline-grid}}.w>span{{grid-area:1/1}}
</style>{body}"""
        file = dump.with_suffix(".html")
        file.write_text(doc)
        png = dump.with_suffix(".png")
        subprocess.run([base.CHROME, "--headless=new", "--no-sandbox", "--disable-gpu", "--hide-scrollbars",
                        "--allow-file-access-from-files", "--force-device-scale-factor=2",
                        f"--window-size={wide},{high}", f"--screenshot={png}", file.as_uri()],
                       check=True, capture_output=True, timeout=120)
        print(png)


if __name__ == "__main__":
    if sys.argv[2] == "panels":
        panels()
    else:
        import sheet

        sheet.make(WORK, Path(sys.argv[3]), font)
