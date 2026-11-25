"""The offline rewards' window in pictures, drawn offline from the trees the game's own code builds (NULLROOM task o1).

    python tools/offline/picture.py             builds the place, runs panel_test.luau (its checks print), draws the sheet
                                                docs/attachments/offline-window-2.png
    python tools/offline/picture.py studio      copies the chest into Studio's own content folder, so Studio shows it before
                                                it is uploaded (rbxasset://textures/ridefish/offline_chest_o1.png)

The sheet (o2): the reference, the window on a PC, the window with each chest to pick from (art/ui/offline/options, a letter
each: none is the game's until Hugo picks one), its header alone, a phone held upright and sideways, and the small Claim
after the X, over captures of the hub. The reference is Hugo's own paste: a PC that has no such file gets a sheet without. Laid out by tools/index/panel_picture.py with Roblox's own font files (the Studio install); it is not
Roblox's renderer, the shines and the open spring do not show, and the hotbar and land strip are left out: Studio has the
last word.
"""
import itertools
import json
import os
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

CHEST = ROOT / "art/ui/offline/chest.png"
OPTIONS = ROOT / "art/ui/offline/options"
REFERENCE = Path(os.environ.get("OFFLINE_REFERENCE", Path.home()
                                / "Projects/nullroom/data/uploads/2026-11-25/123037-pasted-123037.png"))
OUT = ROOT / "docs/attachments/offline-window-2.png"
TMP = Path(tempfile.gettempdir()) / "rideafish_offline"
BIN = Path.home() / ".rokit/bin"
LUNE = next(iter(sorted((Path.home() / ".rokit/tool-storage/lune-org/lune").glob("*/lune"))), BIN / "lune")
HUB = ROOT / "docs/attachments/ui7-hub-spawn.jpg"
DIM = 0.5  # UI/Anim's DimTo
pp.LOCAL["777000777"] = CHEST  # (the id panel_test.luau gives the chest)
_ids = itertools.count()


def studio():
    homes = list((Path.home() / ".var/app/org.vinegarhq.Vinegar/data/vinegar/versions").glob("*/content"))
    homes += list((Path.home() / "AppData/Local/Roblox/Versions").glob("*/content"))
    for content in homes:
        dest = content / "textures/ridefish"
        dest.mkdir(parents=True, exist_ok=True)
        shutil.copy(CHEST, dest / "offline_chest_o1.png")
        print(dest / "offline_chest_o1.png")


class Page(pp.Page):
    """panel_picture's layout, with letters as SVG: Roblox's em for the font, round joins, the outline under the face, and a
    gradient over the whole label"""
    def __init__(self, font):
        super().__init__({})
        self.face = ImageFont.truetype(str(font), 1000)
        self.line = sum(self.face.getmetrics()) / 1000
        self.high = [0]

    def node(self, n, k, layout=None):
        p = n["Props"]
        s = pp.child(n, "UIScale")
        own = s["Props"].get("Scale", 1) if s else 1
        size = p.get("Size", [0, 0, 0, 0]) if n["Class"] in pp.GUI else [0, 0, 0, 0]
        self.high.append(size[2] * self.high[-1] + size[3] * k * own)
        out = super().node(n, k, layout)
        self.high.pop()
        return out

    def text(self, n, k, fill, stroke):
        p = n["Props"]
        em = p.get("TextSize", 14) * k / self.line * .98
        words = p["Text"]
        total = self.face.getlength(words) / 1000 * em
        asc, desc = (m / 1000 for m in self.face.getmetrics())
        mid = em * (asc - desc) / 2
        colour = "rgb(%d,%d,%d)" % tuple(p.get("TextColor3", [255, 255, 255]))
        defs = ""
        if fill:
            i, h = f"t{next(_ids)}", self.high[-1]
            stops = "".join(f'<stop offset="{t}" stop-color="rgb({c[0]},{c[1]},{c[2]})"/>'
                            for t, c in fill["Props"].get("Color", []))
            defs = (f'<defs><linearGradient id="{i}" gradientUnits="userSpaceOnUse" x1="0" y1="{-h / 2}" x2="0" '
                    f'y2="{h / 2}">{stops}</linearGradient></defs>')
            colour = f"url(#{i})"
        head = f'<text xml:space="preserve" x="0" y="{mid:.2f}" font-family="F" font-size="{em:.3f}" '
        out = ""
        if stroke and stroke["Props"].get("Thickness", 1) > 0:
            q = stroke["Props"]
            out += (head + f'fill="none" stroke="rgb({q["Color"][0]},{q["Color"][1]},{q["Color"][2]})" '
                    f'stroke-width="{q["Thickness"] * k * 2:.3f}" stroke-linejoin="round">{escape(words)}</text>')
        out += head + f'fill="{colour}">{escape(words)}</text>'
        ends = {"Left": "flex-start", "Center": "center", "Right": "flex-end"}
        # (a label as wide as its words has that width, as in Roblox)
        box = f"position:relative;width:{total:.2f}px;height:100%" if p.get("AutomaticSize") == "X" else "position:absolute;inset:0"
        return (f'<div class="t" style="{box};align-items:center;'
                f'justify-content:{ends[p.get("TextXAlignment", "Center")]}">'
                f'<svg width="{total:.2f}" height="1" style="overflow:visible;flex:none">{defs}{out}</svg></div>')


def back(name, w, h):
    """the hub behind it: a part of a capture with no HUD of its own in it"""
    im = Image.open(HUB).convert("RGB").crop((180, 95, 1190, 665))
    k = max(w / im.width, h / im.height)
    cw, ch = w / k, h / k
    x, y = (im.width - cw) / 2, (im.height - ch) / 2
    p = TMP / f"bg-{name}.png"
    im.resize((w, h), Image.LANCZOS, (x, y, x + cw, y + ch)).save(p)
    return p


def scene(name, font, tag, crop=None, chest="B", zoom=1.0, letter=""):
    pp.LOCAL["777000777"] = OPTIONS / f"chest_{chest}.png"
    d = json.loads((TMP / "dump" / f"{name}.json").read_text())
    w, h = d["View"]
    body = ""
    for gui in d["Tree"]["Children"]:
        if gui["Props"].get("Name") == "OfflinePanel":
            body += f'<div style="position:absolute;inset:0;background:rgba(0,0,0,{1 - DIM})"></div>'
        page = Page(font)
        page.high = [h]
        body += '<div style="position:absolute;inset:0">' + "".join(page.node(c, 1) for c in gui["Children"]) + "</div>"
    x, y, cw, ch = crop or (0, 0, w, h)
    mark = f'<div class="letter">{letter}</div>' if letter else ""
    return (f'<div style="zoom:{zoom}"><div class="tag" style="font-size:{15 / zoom}px">{tag}</div>'
            f'<div class="scene" style="width:{cw}px;height:{ch}px">{mark}'
            f'<div style="position:absolute;left:{-x}px;top:{-y}px;width:{w}px;height:{h}px;'
            f'background:url({back(name, w, h).as_uri()})">{body}</div></div></div>')


def main():
    if sys.argv[1:] == ["studio"]:
        return studio()
    shutil.rmtree(TMP, ignore_errors=True)
    (TMP / "dump").mkdir(parents=True)
    place = TMP / "place.rbxl"
    subprocess.run([str(BIN / "rojo"), "build", "-o", str(place)], cwd=ROOT, check=True, capture_output=True)
    r = subprocess.run([str(LUNE), "run", "tools/offline/panel_test.luau", str(place), str(TMP / "dump")], cwd=ROOT,
                       capture_output=True, text=True)
    print(r.stdout + r.stderr)
    if r.returncode:
        sys.exit(1)
    font = next(f / "FredokaOne-Regular.ttf" for f in reversed(pp.FONTS) if (f / "FredokaOne-Regular.ttf").exists())
    ref = ""
    if REFERENCE.exists():
        ref = (f'<div><div class="tag">The reference (Hugo\'s picture: its layout only)</div>'
               f'<img src="{REFERENCE.as_uri()}" style="height:490px;display:block;border-radius:6px"></div>')
    picks = "".join(scene("pc720", font, f"Chest {c}", (240, 102, 800, 516), c, .69, c) for c in "ABC")
    heads = "".join(scene("pc720", font, f"{c}: the header on a PC", (254, 114, 540, 100), c) for c in "ABC")
    heads += '</div><div class=row>'
    heads += "".join(scene("phone", font, f"{c}: the header on a phone", (0, 252, 375, 70), c) for c in "ABC")
    html = f"""<!doctype html><meta charset="utf-8"><style>@font-face{{font-family:F;src:url('{font.as_uri()}')}}
*{{box-sizing:border-box}}body{{margin:0;background:#12151f;color:#dfe8fa;font-family:'DejaVu Sans',sans-serif}}
.page{{padding:20px;width:max-content}}.row{{display:flex;gap:18px;align-items:flex-start;margin-bottom:18px}}
.col{{display:flex;flex-direction:column;gap:18px}}
.tag{{font-size:15px;margin-bottom:6px}}.scene{{position:relative;overflow:hidden;border-radius:6px}}
h1{{font:30px F;margin:0 0 14px}}
.s{{position:absolute;pointer-events:none;-webkit-mask:linear-gradient(#000 0 0) content-box,linear-gradient(#000 0 0);
-webkit-mask-composite:xor;mask-composite:exclude}}.i{{position:absolute;inset:0}}
.t{{display:flex}}.letter{{position:absolute;z-index:99;left:56px;top:150px;font:110px F;color:#fff;-webkit-text-stroke:14px
#10131c;paint-order:stroke fill}}p{{margin:0 0 14px;max-width:1700px;font-size:15px;line-height:1.5}}</style><div class=page>
<h1>Welcome back, laid out like the reference: drawn from the game's own code (not Studio)</h1>
<div class=row>{ref}{scene("pc720", font, "Ours, PC, 1280 x 720, $364.2M owed (the game writes $364M) (chest B)", zoom=.68)}</div>
<h1>Pick a chest: A, B or C</h1><div class=row>{picks}</div>
<div class=row>{heads}</div>
<h1>Phones, at true size (chest B)</h1>
<div class=row>{scene("phone", font, "Phone, 375 x 812")}
{scene("phone-long", font, "Phone, the longest amount")}
<div class=col>{scene("phone-side", font, "Phone sideways, 812 x 375")}
{scene("pc-long", font, "PC, the longest amount", (240, 102, 800, 516), zoom=.6)}</div></div>
<h1>After the X: the small Claim</h1>
<div class=row>{scene("pc720-chip", font, "PC (left of the screen)", (0, 180, 440, 200))}
{scene("phone-side-chip", font, "Phone sideways", (0, 110, 440, 200))}
{scene("phone-chip", font, "Phone", (0, 335, 375, 200))}</div></div>"""
    f = TMP / "sheet.html"
    f.write_text(html)
    png = TMP / "sheet.png"
    subprocess.run([pp.CHROME, "--headless=new", "--no-sandbox", "--disable-gpu", "--hide-scrollbars",
                    "--allow-file-access-from-files", "--window-size=1800,3000", f"--screenshot={png}", f.as_uri()],
                   check=True, capture_output=True, timeout=180)
    im = Image.open(png).convert("RGB")
    ground = im.getpixel((2, 2))
    edge = ImageChops.difference(im, Image.new("RGB", im.size, ground)).getbbox()
    im = im.crop((0, 0, min(edge[2] + 20, im.width), min(edge[3] + 20, im.height)))
    im.save(OUT, optimize=True)
    print(OUT, im.size)


if __name__ == "__main__":
    main()
