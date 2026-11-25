"""The Index's window (UI.IndexWindow) in pictures, drawn offline from the trees the game's own code builds (NULLROOM i1).

    python tools/index/look_picture.py [states]     builds the place, runs the checks of both looks (they print), and
                                                    draws the sheet docs/attachments/index-look.png; with "states",
                                                    one picture a state in the temp folder too (its path prints)

panel_picture.py's layout, with the letters at Roblox's own size for the font (TextSize is the line's height, not the em),
pictures that crop, tint and keep their corners, and the fish pictures' black outline. It is not Roblox's renderer: the
shines, the springs and the live fish models do not show. Studio has the last word. The banners are drawn as if
uploaded; the "not uploaded" state shows a live game before that.
"""
import json
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

from PIL import Image, ImageFont

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools/index"))
import panel_picture as pp  # noqa: E402

OUT = ROOT / "docs/attachments/index-look.png"
TMP = Path(tempfile.gettempdir()) / "rideafish_index_look"
BIN = Path.home() / ".rokit/bin"
LUNE = next(iter(sorted((Path.home() / ".rokit/tool-storage/lune-org/lune").glob("*/lune"))), BIN / "lune")
HUB = ROOT / "docs/attachments/ui7-hub-spawn.jpg"
BEFORE = ROOT / "docs/attachments/index-panel-offline-4_set.jpg"
OUTLINE = 2  # px at scale 1: about what UI.Portrait's black copies show


class Page(pp.Page):
    def __init__(self, icons, font):
        super().__init__(icons)
        self.line = sum(ImageFont.truetype(str(font), 1000).getmetrics()) / 1000

    def picture(self, image):
        if image.startswith("land:"):
            return next((ROOT / "art/ui/lands/upload").glob(f"land_banner_{int(image[5:]):02d}.png"))
        return super().picture(image)

    def node(self, n, k, layout=None):
        # (a list scrolled down: CanvasPosition is in the screen's pixels, so it is drawn as it is. A grid's cards move by it)
        place = n["Props"].get("CanvasPosition")
        if n["Class"] == "ScrollingFrame" and place and place[1]:
            kids = [dict(c, Props=dict(c["Props"], ScrolledBy=place[1])) if c["Class"] in pp.GUI else c
                    for c in n["Children"]]
            n = dict(n, Children=kids)
        out = super().node(n, k, layout)
        by = n["Props"].get("ScrolledBy")
        return out.replace('style="', f'style="top:{-by}px;', 1) if by else out

    def image(self, n, k, fill):
        p = n["Props"]
        file = self.picture(p["Image"])
        if not file:
            return ""
        colour = p.get("ImageColor3", [255, 255, 255])
        if p.get("ScaleType") == "Tile":
            return super().image(n, k, fill)
        url = file.as_uri()
        fit = "cover" if p.get("ScaleType") == "Crop" else "contain"
        style = [f"opacity:{1 - p.get('ImageTransparency', 0):.3f}", "border-radius:inherit"]
        fish = p["Image"].startswith("fish:")
        if colour == [0, 0, 0] and fish:
            return ""  # (the black copy under a fish: drawn as its outline below)
        if colour != [255, 255, 255]:
            style.append(f"background:url({url}) center/{fit} no-repeat,{pp.rgba(colour)};"
                         f"background-blend-mode:multiply;-webkit-mask:url({url}) center/{fit} no-repeat")
        else:
            style.append(f"background:url({url}) center/{fit} no-repeat")
            if fish:
                t = OUTLINE * k
                style.append("filter:" + " ".join(f"drop-shadow({x * t * .7}px {y * t * .7}px 0 #000)" for x, y in (
                    (1, 0), (-1, 0), (0, 1), (0, -1))))
        return f'<div class="i" style="{";".join(style)}"></div>'

    def text(self, n, k, fill, stroke):
        size = n["Props"].get("TextSize", 14)
        out = super().text(n, k, fill, stroke)
        return out.replace(f"font-size:{size * k}px", f"font-size:{size * k / self.line:.3f}px;line-height:{size * k}px", 1)


def build():
    shutil.rmtree(TMP, ignore_errors=True)
    (TMP / "dump").mkdir(parents=True)
    place = TMP / "place.rbxl"
    subprocess.run([str(BIN / "rojo"), "build", "-o", str(place)], cwd=ROOT, check=True, capture_output=True)
    for args in (["tools/index/index_test.luau", place], ["tools/index/panel_test.luau", place, "-", "0"],
                 ["tools/index/panel_test.luau", place], ["tools/index/panel_test.luau", place, TMP / "dump"]):
        r = subprocess.run([str(LUNE), "run", *map(str, args)], cwd=ROOT, capture_output=True, text=True)
        lines = (r.stdout + r.stderr).strip().splitlines()
        print("\n".join([f"{args[0]} {' '.join(map(str, args[2:]))}"] + [x for x in lines if "  ok  " not in x]))
        if r.returncode:
            sys.exit(1)


class Sheet:
    def __init__(self):
        self.icons = pp.fish_icons()
        self.font = next(f / "FredokaOne-Regular.ttf" for f in reversed(pp.FONTS)
                         if (f / "FredokaOne-Regular.ttf").exists())

    def css(self):
        return (f"@font-face{{font-family:F;src:url('{self.font.as_uri()}')}}"
                "*{box-sizing:border-box}"
                ".s{position:absolute;pointer-events:none;-webkit-mask:linear-gradient(#000 0 0) content-box,"
                "linear-gradient(#000 0 0);-webkit-mask-composite:xor;mask-composite:exclude}"
                ".i{position:absolute;inset:0}.t{display:flex;position:relative;width:100%;height:100%}"
                ".w{display:inline-grid}.w>span{grid-area:1/1}")

    def scene(self, state, crop=None):
        """one state over the hub; crop: how much of the screen round its middle is kept (width, height)"""
        d = json.loads((TMP / "dump" / f"{state}.json").read_text())
        w, h = d["View"]
        page = Page(self.icons, self.font)
        body = "".join(page.node(c, 1) for c in d["Tree"]["Children"])
        cw, ch = crop or (w, h)
        x, y = (w - cw) / 2, (h - ch) / 2
        return (f'<div style="position:relative;overflow:hidden;width:{cw}px;height:{ch}px;border-radius:6px">'
                f'<div style="position:absolute;left:{-x}px;top:{-y}px;width:{w}px;height:{h}px;font-family:F;'
                f"background:url({HUB.as_uri()}) center/cover\">{body}</div></div>")

    def shoot(self, html, out, wide, high, dpr=1):
        file = TMP / (out.stem + ".html")
        file.write_text(f'<!doctype html><meta charset="utf-8"><style>{self.css()}</style>'
                        f'<body style="margin:0;background:#12151f">{html}</body>')
        subprocess.run([pp.CHROME, "--headless=new", "--no-sandbox", "--disable-gpu", "--hide-scrollbars",
                        "--allow-file-access-from-files", f"--force-device-scale-factor={dpr}",
                        f"--window-size={wide},{high}", f"--screenshot={out}", file.as_uri()],
                       check=True, capture_output=True, timeout=180)
        return out


def main():
    build()
    sheet = Sheet()
    if "states" in sys.argv[1:]:
        for dump in sorted((TMP / "dump").glob("look_*.json")):
            w, h = json.loads(dump.read_text())["View"]
            dpr = 2 if min(w, h) < 600 else 1
            print(sheet.shoot(sheet.scene(dump.stem), TMP / f"{dump.stem}.png", w, h, dpr))
    draw(sheet)


def draw(sheet):
    def tag(text):
        return f'<div style="font:600 19px DejaVu Sans;color:#dfe8fa;margin:0 0 8px">{text}</div>'

    def block(text, inner):
        return f"<div>{tag(text)}{inner}</div>"

    pc = (1440, 912)

    def small(state, width):
        z = width / pc[0]
        return (f'<div style="width:{width}px;height:{pc[1] * z:.0f}px;overflow:hidden">'
                f'<div style="zoom:{z:.4f}">{sheet.scene(state, pc)}</div></div>')

    def phone(state, z):
        return f'<div style="zoom:{z}">{sheet.scene(state)}</div>'

    before = (f'<div style="width:700px;height:443px;border-radius:6px;background:url({BEFORE.as_uri()}) '
              f'center/{700 * 1920 / 1300:.0f}px no-repeat"></div>')
    html = f"""<div style="width:2240px;padding:24px;display:flex;flex-direction:column;gap:26px">
<div style="display:flex;gap:26px">{block("PC, 1920 x 1080: the Shallows, 9 of 11 found, the Sea Turtle's reward waiting (our own code, drawn offline)",
        sheet.scene("look_pc", pc))}
<div style="display:flex;flex-direction:column;gap:26px">
{block("Before (its picture of 24 Nov; Config.Index.Look 0)", before)}
{block("A whole land: its CLAIM! in the banner", small("look_pc_whole", 700))}</div></div>
<div style="display:flex;gap:26px">
{block("Phone upright, 375 x 812 (at 1.4)", phone("look_phone_tall", 1.4))}
<div style="display:flex;flex-direction:column;gap:26px">
{block("Phone sideways, 667 x 375 (at 1.4)", phone("look_phone_wide", 1.4))}
{block("The same, a whole land", phone("look_phone_whole", 1.4))}</div>
<div style="display:flex;flex-direction:column;gap:26px">
{block("A Secret chosen: dark till caught", small("look_pc_secret", 660))}
{block("A live game before the banners are uploaded", small("look_pc_plain", 660))}</div></div></div>"""
    wide, high = 2288, 2180
    sheet.shoot(html, OUT, wide, high)
    im = Image.open(OUT).convert("RGB")
    # (cut the empty foot)
    bg = im.getpixel((2, high - 2))
    foot = next(y for y in range(high - 1, 0, -1) if any(im.getpixel((x, y)) != bg for x in range(0, wide, 8)))
    im.crop((0, 0, wide, foot + 24)).save(OUT, optimize=True)
    print(OUT, f"{OUT.stat().st_size / 1e6:.1f} MB")


if __name__ == "__main__":
    main()
