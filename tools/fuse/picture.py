"""The Fuse machine's window in pictures, drawn offline from the trees the game's own code builds (NULLROOM task u1).

    python tools/fuse/picture.py      builds the place, runs panel_test.luau (its checks print), draws the sheet
                                      docs/attachments/fuse-window.png

The sheet: no fish, picking, what comes out with a warning, the swirl and the result on a PC; the warning on a phone,
lying and standing, at true size, over a capture of the hub. Laid out by tools/index/panel_picture.py with Roblox's own
font files (the Studio install); it is not Roblox's renderer, the open spring and the shine do not show, and the fish are
the partner's renders (in the game, until the icon pages are uploaded, the live models): Studio has the last word.
"""
import itertools
import json
import shutil
import subprocess
import sys
import tempfile
from html import escape
from pathlib import Path

from PIL import Image, ImageChops, ImageFont

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools/index"))
import panel_picture as pp  # noqa: E402

OUT = ROOT / "docs/attachments/fuse-window.png"
TMP = Path(tempfile.gettempdir()) / "rideafish_fuse"
BIN = Path.home() / ".rokit/bin"
LUNE = next(iter(sorted((Path.home() / ".rokit/tool-storage/lune-org/lune").glob("*/lune"))), BIN / "lune")
HUB = ROOT / "docs/attachments/ui7-hub-spawn.jpg"
DIM = 0.5  # UI/Anim's DimTo
_ids = itertools.count()


def clean(node):
    """without the gradients that are switched off"""
    node["Children"] = [clean(c) for c in node["Children"]
                        if not (c["Class"] == "UIGradient" and c["Props"].get("Enabled") is False)]
    return node


class Page(pp.Page):
    """panel_picture's layout, with letters as SVG: Roblox's em for the font, round joins, the outline under the face, and
    a gradient over the whole label"""
    def __init__(self, icons, font):
        super().__init__(icons)
        self.face = ImageFont.truetype(str(font), 1000)
        self.line = sum(self.face.getmetrics()) / 1000

    def text(self, n, k, fill, stroke):
        p = n["Props"]
        em = p.get("TextSize", 14) * k / self.line * .98
        asc, desc = (m / 1000 for m in self.face.getmetrics())
        mid = em * (asc - desc) / 2
        colour = "rgb(%d,%d,%d)" % tuple(p.get("TextColor3", [255, 255, 255]))
        defs = ""
        wide = max(self.face.getlength(w) / 1000 * em for w in p["Text"].split("\n"))
        if fill:
            i = f"t{next(_ids)}"
            across = fill["Props"].get("Rotation", 0) == 0
            box = f'x1="0" y1="0" x2="{wide}" y2="0"' if across else f'x1="0" y1="{-em / 2}" x2="0" y2="{em / 2}"'
            stops = "".join(f'<stop offset="{t}" stop-color="rgb({c[0]},{c[1]},{c[2]})"/>'
                            for t, c in fill["Props"].get("Color", []))
            defs = f'<defs><linearGradient id="{i}" gradientUnits="userSpaceOnUse" {box}>{stops}</linearGradient></defs>'
            colour = f"url(#{i})"
        ends = {"Left": "flex-start", "Center": "center", "Right": "flex-end"}
        align = ends[p.get("TextXAlignment", "Center")]
        rows = ""
        for words in p["Text"].split("\n"):
            total = self.face.getlength(words) / 1000 * em
            head = f'<text xml:space="preserve" x="0" y="{mid:.2f}" font-family="F" font-size="{em:.3f}" '
            out = ""
            if stroke and stroke["Props"].get("Thickness", 1) > 0:
                q = stroke["Props"]
                out += (head + f'fill="none" stroke="rgb({q["Color"][0]},{q["Color"][1]},{q["Color"][2]})" '
                        f'stroke-width="{q["Thickness"] * k * 2:.3f}" stroke-linejoin="round">{escape(words)}</text>')
            out += head + f'fill="{colour}">{escape(words)}</text>'
            high = p.get("TextSize", 14) * k
            rows += (f'<svg width="{total:.2f}" height="{high:.2f}" viewBox="0 {-high / 2:.2f} {max(total, 1):.2f} '
                     f'{high:.2f}" style="overflow:visible;flex:none">{defs}{out}</svg>')
        # (a label as wide as its words holds its own place in a row; any other fills its box)
        place = "position:relative;height:100%" if p.get("AutomaticSize") == "X" else "position:absolute;inset:0"
        return (f'<div class="t" style="{place};flex-direction:column;align-items:{align};'
                f'justify-content:center">{rows}</div>')


def back(name, w, h):
    im = Image.open(HUB).convert("RGB").crop((180, 95, 1190, 665))
    k = max(w / im.width, h / im.height)
    cw, ch = w / k, h / k
    x, y = (im.width - cw) / 2, (im.height - ch) / 2
    p = TMP / f"bg-{name}.png"
    im.resize((w, h), Image.LANCZOS, (x, y, x + cw, y + ch)).save(p)
    return p


def scene(name, icons, font, tag, crop=None):
    d = json.loads((TMP / "dump" / f"{name}.json").read_text())
    w, h = d["View"]
    page = Page(icons, font)
    body = "".join(page.node(c, 1) for c in clean(d["Tree"])["Children"])
    x, y, cw, ch = crop or (0, 0, w, h)
    return (f'<div><div class="tag">{tag}</div><div class="scene" style="width:{cw}px;height:{ch}px">'
            f'<div style="position:absolute;left:{-x}px;top:{-y}px;width:{w}px;height:{h}px;'
            f'background:url({back(name, w, h).as_uri()})"><div style="position:absolute;inset:0;'
            f'background:rgba(0,0,0,{1 - DIM})"></div>{body}</div></div></div>')


def main():
    shutil.rmtree(TMP, ignore_errors=True)
    (TMP / "dump").mkdir(parents=True)
    place = TMP / "place.rbxl"
    subprocess.run([str(BIN / "rojo"), "build", "-o", str(place)], cwd=ROOT, check=True, capture_output=True)
    r = subprocess.run([str(LUNE), "run", "tools/fuse/panel_test.luau", str(place), str(TMP / "dump")], cwd=ROOT,
                       capture_output=True, text=True)
    print(r.stdout + r.stderr)
    if r.returncode:
        sys.exit(1)
    font = next(f / "FredokaOne-Regular.ttf" for f in reversed(pp.FONTS) if (f / "FredokaOne-Regular.ttf").exists())
    icons = pp.fish_icons()
    pc = (190, 70, 900, 580)

    def s(name, tag, crop=None):
        return scene(name, icons, font, tag, crop)

    html = f"""<!doctype html><meta charset="utf-8"><style>@font-face{{font-family:F;src:url('{font.as_uri()}')}}
*{{box-sizing:border-box}}body{{margin:0;background:#12151f;color:#dfe8fa;font-family:'DejaVu Sans',sans-serif}}
.page{{padding:20px;width:max-content}}.row{{display:flex;gap:18px;align-items:flex-start;margin-bottom:18px}}
.col{{display:flex;flex-direction:column;gap:18px}}
.tag{{font-size:17px;margin-bottom:6px}}.scene{{position:relative;overflow:hidden;border-radius:6px}}
h1{{font:30px F;margin:0 0 14px}}
.s{{position:absolute;pointer-events:none;-webkit-mask:linear-gradient(#000 0 0) content-box,linear-gradient(#000 0 0);
-webkit-mask-composite:xor;mask-composite:exclude}}.i{{position:absolute;inset:0}}
.t{{display:flex}}</style><div class=page><h1>Fusing: the window, drawn from the game's own code (not Studio)</h1>
<div class=row>{s("pc-warn", "PC: three in. The biggest stays and grows, a Gold one would be used up", pc)}
{s("pc-list", "PC: on opening. Only kinds with three that can be fused", pc)}</div>
<div class=row>{s("pc-picking", "PC: picking. After the first fish only its kind is listed", pc)}
{s("pc-sure", "PC: the question, when a special one would be used up", pc)}</div>
<div class=row>{s("pc-swirl", "PC: the show, half a second in (a press skips it)", pc)}
{s("pc-result", "PC: the bigger one is out", pc)}</div>
<div class=row>{s("pc-empty", "PC: no three of a kind", pc)}
<div class=col>{s("phone-warn", "Phone lying, 812 x 375")}</div></div>
<div class=row>{s("phone-tall", "Phone standing, 375 x 812 (as every dock window of ours)", (0, 240, 375, 330))}</div></div>"""
    f = TMP / "sheet.html"
    f.write_text(html)
    png = TMP / "sheet.png"
    subprocess.run([pp.CHROME, "--headless=new", "--no-sandbox", "--disable-gpu", "--hide-scrollbars",
                    "--allow-file-access-from-files", "--window-size=1900,2900", f"--screenshot={png}", f.as_uri()],
                   check=True, capture_output=True, timeout=180)
    im = Image.open(png).convert("RGB")
    ground = im.getpixel((2, 2))
    edge = ImageChops.difference(im, Image.new("RGB", im.size, ground)).getbbox()
    im = im.crop((0, 0, min(edge[2] + 20, im.width), min(edge[3] + 20, im.height)))
    im.save(OUT, optimize=True)
    print(OUT, im.size)


if __name__ == "__main__":
    main()
