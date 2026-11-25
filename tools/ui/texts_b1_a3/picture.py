"""The sheet of Hugo's picks of 2026-11-25 (text-options: B1 for the dock's lines, A3 for "Required" with a thinner outline),
before and after, drawn from the trees the game's own modules build (check.luau), over real captures of the game.

    python tools/ui/texts_b1_a3/picture.py [commit before, default the branch's parent: origin/main]

Builds both places with rojo, runs check.luau on each (its checks print), compares what must not have changed, and writes
docs/attachments/texts-b1-a3.png. Letters are Roblox's own font files (the Studio install), each label's em as measured on
Hugo's picture of the goal line (tools/ui/text_options, 2026-11-25). Not Roblox's renderer: Studio has the last word.
"""
import itertools
import json
import re
import shutil
import subprocess
import sys
import tempfile
from html import escape
from pathlib import Path

from PIL import Image, ImageFont

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / "tools/index"))
import panel_picture as pp  # noqa: E402

OUT = ROOT / "docs/attachments/texts-b1-a3.png"
TMP = Path(tempfile.gettempdir()) / "rideafish_texts_b1_a3"
BIN = Path.home() / ".rokit/bin"
LUNE = next(iter(sorted((Path.home() / ".rokit/tool-storage/lune-org/lune").glob("*/lune"))), None) or BIN / "lune"
FONTS = next(f for f in reversed(pp.FONTS) if (f / "LuckiestGuy-Regular.ttf").exists())
FILES = {"FredokaOne": "FredokaOne-Regular.ttf", "LuckiestGuy": "LuckiestGuy-Regular.ttf",
         "GothamBlack": "Montserrat-Black.ttf", "GothamBold": "Montserrat-Bold.ttf"}
FACE = {k: ImageFont.truetype(str(FONTS / v), 1000) for k, v in FILES.items() if (FONTS / v).exists()}
LINE = {k: sum(f.getmetrics()) / 1000 for k, f in FACE.items()}
A = ROOT / "docs/attachments"
BG = {"spawn": (A / "ui7-hub-spawn.jpg", None),
      "blue": (A / "land-icons/land01j.jpg", None), "dark": (A / "land-icons/land07j.jpg", None)}
FLAT = re.compile(r"calc\(\(0(?:\.0)?% \+ ([-\d.e]+)px\) \* ([\d.]+)\)")
_ids = itertools.count()


def em(font, size):
    return size / LINE[font] * (.98 if font == "FredokaOne" else 1)


def wide(text, font, size):
    return FACE[font].getlength(text) / 1000 * em(font, size)


class Page(pp.Page):
    """panel_picture's layout, with letters drawn as SVG (Roblox's em, round joins, the outline under the face), a
    gradient over the whole label, and the RichText colour the old lines used"""

    def __init__(self):
        super().__init__({})
        self.high = [0]

    def node(self, n, k, layout=None):
        p = n["Props"]
        s = pp.child(n, "UIScale")
        own = s["Props"].get("Scale", 1) if s else 1
        size = p.get("Size", [0, 0, 0, 0]) if n["Class"] in pp.GUI else [0, 0, 0, 0]
        self.high.append(size[2] * self.high[-1] * own + size[3] * k * own)
        out = super().node(n, k, layout)
        self.high.pop()
        # (a height with a share of an auto-sized parent's in it is no height to a browser, even a share of 0)
        out = FLAT.sub(lambda m: f"{float(m[1]) * float(m[2]):.3f}px", out)
        return out

    def text(self, n, k, fill, stroke):
        p = n["Props"]
        font = p.get("Font", "FredokaOne")
        size = p.get("TextSize", 14) * k
        runs, at = [], p["Text"]
        base = "rgb(%d,%d,%d)" % tuple(p.get("TextColor3", [255, 255, 255]))
        while '<font color="' in at:
            a, rest = at.split('<font color="', 1)
            colour, rest = rest.split('">', 1)
            mid, at = rest.split("</font>", 1)
            runs += [(a, base), (mid, colour)]
        runs.append((at, base))
        runs = [r for r in runs if r[0]]
        total = sum(wide(t, font, size) for t, _ in runs)
        face = FACE[font]
        asc, desc = (m / 1000 for m in face.getmetrics())
        e = em(font, size)
        mid = e * (asc - desc) / 2  # the baseline under the line's middle
        see = 1 - p.get("TextTransparency", 0)
        defs, over = "", ""
        ink = ""
        if stroke and stroke["Props"].get("Enabled", True) and stroke["Props"].get("Thickness", 1) > 0:
            q = stroke["Props"]
            ink = (f'fill="none" stroke="rgb({q["Color"][0]},{q["Color"][1]},{q["Color"][2]})" '
                   f'stroke-width="{q["Thickness"] * k * 2:.3f}" stroke-linejoin="round" '
                   f'stroke-opacity="{1 - q.get("Transparency", 0):.3f}"')
        paint = None
        if fill:
            i = f"t{next(_ids)}"
            g = fill["Props"]
            h = self.high[-1]
            turn = g.get("Rotation", 0)
            axis = (f'x1="0" y1="{-h / 2}" x2="0" y2="{h / 2}"' if abs(turn) > 45 else
                    f'x1="0" y1="0" x2="{total}" y2="0"')
            stops = "".join(f'<stop offset="{t}" stop-color="rgb({c[0]},{c[1]},{c[2]})"/>'
                            for t, c in g.get("Color", []))
            clear = g.get("Transparency") or []
            if any(v for _, v in clear):
                stops = "".join(f'<stop offset="{t}" stop-color="#fff" stop-opacity="{1 - v}"/>' for t, v in clear)
            defs = f'<defs><linearGradient id="{i}" gradientUnits="userSpaceOnUse" {axis}>{stops}</linearGradient></defs>'
            paint = f"url(#{i})"
        for look in ("stroke", "fill"):
            x = 0
            for t, c in runs:
                if look == "fill" or ink:
                    style = ink if look == "stroke" else f'fill="{paint or c}" fill-opacity="{see:.3f}"'
                    over += (f'<text xml:space="preserve" x="{x:.2f}" y="{mid:.2f}" font-family="{font}" '
                             f'font-size="{e:.3f}" {style}>{escape(t)}</text>')
                x += wide(t, font, size)
        ends = {"Left": "flex-start", "Center": "center", "Right": "flex-end"}
        auto = p.get("AutomaticSize", "None") != "None"
        box = ("" if auto else "position:absolute;inset:0;") + (
            f"justify-content:{ends[p.get('TextXAlignment', 'Center')]};align-items:center")
        return (f'<div class="t" style="{box}"><svg width="{total:.2f}" height="1" style="overflow:visible;flex:none">'
                f'{defs}{over}</svg></div>')


def run(*a, **k):
    return subprocess.run([str(x) for x in a], check=True, **k)


def places(before):
    TMP.mkdir(parents=True, exist_ok=True)
    old = TMP / "before"
    shutil.rmtree(old, ignore_errors=True)
    old.mkdir()
    tar = subprocess.run(["git", "archive", before, "src", "default.project.json", "rokit.toml"], cwd=ROOT, check=True,
                         capture_output=True).stdout
    subprocess.run(["tar", "x", "-C", str(old)], input=tar, check=True)
    run(BIN / "rojo", "build", "-o", TMP / "after.rbxl", cwd=ROOT, capture_output=True)
    run(BIN / "rojo", "build", "-o", TMP / "before.rbxl", cwd=old, capture_output=True)


def trees():
    out = {}
    (TMP / "widths.json").write_text(json.dumps({
        k: {"Em": em(k, 1), "Wide": {chr(c): f.getlength(chr(c)) / 1000 for c in range(32, 127)}}
        for k, f in FACE.items()}))
    dump = TMP / "dump"
    shutil.rmtree(dump, ignore_errors=True)
    dump.mkdir()
    for which in ("before", "after"):
        r = subprocess.run([str(LUNE), "run", str(Path(__file__).with_name("check.luau")), str(TMP / f"{which}.rbxl"),
                            str(TMP / "widths.json"), str(dump), which], capture_output=True, text=True)
        print(r.stdout + r.stderr)
        if r.returncode:
            sys.exit(1)
    def drop(n):  # (an outline that is off is no outline)
        n["Children"] = [drop(c) for c in n["Children"]
                         if not (c["Class"] == "UIStroke" and c["Props"].get("Enabled") is False)]
        return n
    for f in dump.glob("*.json"):
        out[f.stem] = json.loads(f.read_text())
        drop(out[f.stem]["Tree"])
    return out


def find(n, name):
    if n["Props"].get("Name") == name:
        return n
    return next((hit for c in n["Children"] if (hit := find(c, name))), None)


def same(T):
    """the tag's "TOO STRONG!" label, before and after"""
    def hold(n):
        if n["Props"].get("Text") == "TOO STRONG!":
            return n
        return next((h for c in n["Children"] if (h := hold(c))), None)
    a, b = hold(T["before-tag-locked"]["Tree"]), hold(T["after-tag-locked"]["Tree"])
    assert a == b, "the tag's TOO STRONG! changed"
    print("  ok    the tag's TOO STRONG! is the same label, property by property")
    assert not subprocess.run(["git", "diff", "--stat", BEFORE, "--", "src/client/UI/Rings.luau",
                               "src/client/UI/Banners.luau", "src/client/Controllers/HudController.luau"],
                              cwd=ROOT, capture_output=True, text=True).stdout
    print("  ok    Rings (Too strong, needs n), Banners and HudController are untouched")


_crops = {}


def crop(name, high, x, y, w, h, dpr=2):
    key = (name, high, x, y, w, h)
    if key not in _crops:
        path, box = BG[name]
        im = Image.open(path).convert("RGB")
        if box:
            im = im.crop(box)
        k = high / im.height
        p = TMP / f"bg{len(_crops)}.png"
        im.resize((w * dpr, h * dpr), Image.LANCZOS, (x / k, y / k, (x + w) / k, (y + h) / k)).save(p)
        _crops[key] = p
    return _crops[key]


def scene(w, h, bg, body, tag=""):
    t = f'<div class="tag">{tag}</div>' if tag else ""
    return (f'<div class="scene" style="width:{w}px;height:{h}px;background:url({bg.as_uri()}) 0 0/100% 100%">'
            f'{body}{t}</div>')


def screen(T, name, w, h, x, y):
    """the whole screen's tree, moved so that (x, y) is the scene's corner"""
    d = T[name]
    W, H = d["View"]
    page = Page()
    page.high = [H]
    body = "".join(page.node(c, 1) for c in d["Tree"]["Children"])
    return f'<div style="position:absolute;left:{-x}px;top:{-y}px;width:{W}px;height:{H}px">{body}</div>'


def tag(T, name, cx, bottom, k):
    d = T[name]
    page = Page()
    body = page.node(d["Tree"], 1)
    return (f'<div style="position:absolute;left:{cx}px;top:{bottom}px;width:400px;height:140px;'
            f'transform-origin:0 0;transform:scale({k}) translate(-200px,-136px)">{body}</div>')


CSS = "".join(f"@font-face{{font-family:'{k}';src:url('{(FONTS / v).as_uri()}')}}" for k, v in FILES.items()) + """
*{box-sizing:border-box}svg text{font-variant-ligatures:none}
body{margin:0;background:#12151f;color:#fff;font-family:'DejaVu Sans',sans-serif}
.page{padding:24px;width:max-content}
h1{font:34px GothamBlack;margin:0 0 6px}h2{font:20px GothamBlack;margin:22px 0 8px;color:#ffd23f}
p{margin:0 0 4px;font-size:16px;line-height:1.4;color:#c8d2e6;max-width:1720px}p b{color:#fff}
.row{display:flex;gap:12px;align-items:flex-start;margin-bottom:12px}
.col{display:flex;flex-direction:column;gap:8px}
.scene{position:relative;overflow:hidden;border-radius:6px;flex:none}
.tag{position:absolute;left:6px;top:6px;font-size:12px;background:#000b;color:#dfe8fa;padding:2px 6px;border-radius:4px;z-index:99}
.s{position:absolute;pointer-events:none;-webkit-mask:linear-gradient(#000 0 0) content-box,linear-gradient(#000 0 0);
-webkit-mask-composite:xor;mask-composite:exclude}.i{position:absolute;inset:0}.t{display:flex;position:relative;width:100%;height:100%}
"""
TAG = 1080 / 560  # a tag's points at 1080p (HudController's scale)


def sheet(T):
    b = ""
    b += "<h2>1  Tutorial line and 2  money line, PC 1080p, real size</h2>"
    for what, name in (("tutorial", "lesson"), ("money", "goal"), ("a catch carried home", "carry"),
                       ("something to buy", "gold")):
        y = int(1080 * (.686 if name in ("lesson", "carry") else .755)) - 70
        b += '<div class="row">' + "".join(
            scene(850, 140, crop("spawn", 1080, 498, y, 850, 140, 1), screen(T, f"{w}-pc-{name}", 850, 140, 535, y),
                  f"{w.upper()}: {what}") for w in ("before", "after")) + "</div>"
    b += "<h2>The same on a phone held sideways, 375 high (812 x 375), true size</h2>"
    for what, name in (("tutorial", "lesson"), ("money", "goal")):
        b += '<div class="row">' + "".join(
            scene(812, 375, crop("spawn", 475, 0, 72, 812, 375, 1), screen(T, f"{w}-phone-{name}", 812, 375, 0, 0),
                  f"{w.upper()}: {what}") for w in ("before", "after")) + "</div>"
    b += "<h2>3  Required, PC 1080p, real size (a player with 100 Oxygen)</h2>"
    for bg, at, names in (("blue", (900, 60), ("hold", "strong", "shark")), ("dark", (600, 330), ("hold", "strong", "manta"))):
        b += '<div class="row">' + "".join(
            scene(850, 200, crop(bg, 1080, *at, 850, 200, 1),
                  "".join(tag(T, f"{w}-tag-{n}", 850 * (i + .5) / 3, 170, TAG) for i, n in enumerate(names)),
                  f"{w.upper()}: {'blue' if bg == 'blue' else 'dark'} water") for w in ("before", "after")) + "</div>"
    b += '<div class="row">' + "".join(
        scene(850, 190, crop("blue", 1080, 900, 260, 850, 190, 1),
              tag(T, f"{w}-tag-farhold", 130, 130, TAG * .86) + tag(T, f"{w}-tag-far", 340, 130, TAG * .86)
              + tag(T, f"{w}-tag-locked", 640, 178, TAG * 1.0),
              f"{w.upper()}: far fish; locked on one too strong (TOO STRONG! unchanged)") for w in ("before", "after")) + "</div>"
    b += "<h2>The outline: A3 as on the options sheet, and as built (60% of it), 3x</h2>"
    b += '<div class="row">' + "".join(
        scene(419, 190, crop(bg, 1080, *at, 419, 190, 1), tag(T, n, 210, 178, 3), t)
        for bg, at in (("blue", (1000, 60)), ("dark", (700, 330)))
        for n, t in (("full-tag-shark", "A3's outline"), ("after-tag-shark", "BUILT: 60%"))) + "</div>"
    b += "<h2>3 on a phone, 375 wide, true size</h2>"
    b += '<div class="row">' + "".join(
        scene(375, 130, crop(bg, 475, *at, 375, 130, 1),
              tag(T, f"{w}-tag-hold", 95, 110, 1) + tag(T, f"{w}-tag-{n}", 270, 110, 1),
              f"{w.upper()}: {bg} water")
        for bg, at, n in (("blue", (430, 60), "shark"), ("dark", (330, 150), "manta")) for w in ("before", "after")) + "</div>"
    head = ("<h1>Texts: sticker B1 on the dock, A3 for Required</h1>"
            "<p>Drawn from the trees the game's own code builds, before (main) and after (branch texts-b1-a3), in Roblox's "
            "own fonts over captures of the game; not seen in Studio. <b>The dock's lines now come only after a respawn</b> "
            "(the first spawn too), 0.25 s slapped on, up 2.5 s, faded in 0.5 s, once.</p>")
    html = f'<!doctype html><meta charset=utf8><style>{CSS}</style><div class=page>{head}{b}</div>'
    f = TMP / "sheet.html"
    f.write_text(html)
    png = TMP / "sheet.png"
    run(pp.CHROME, "--headless=new", "--no-sandbox", "--disable-gpu", "--hide-scrollbars", "--allow-file-access-from-files",
        "--window-size=1780,3400", f"--screenshot={png}", f.as_uri(), capture_output=True, timeout=180)
    im = Image.open(png).convert("RGB")
    last = max(y for y in range(0, im.height, 4) if len(set(im.crop((0, y, im.width, y + 1)).resize((64, 1)).getdata())) > 1)
    im.crop((0, 0, im.width, min(last + 30, im.height))).save(OUT, optimize=True)
    print(OUT, im.width, last + 30)


if __name__ == "__main__":
    BEFORE = sys.argv[1] if len(sys.argv) > 1 else subprocess.run(
        ["git", "merge-base", "HEAD", "origin/main"], cwd=ROOT, check=True, capture_output=True, text=True).stdout.strip()
    places(BEFORE)
    trees_ = trees()
    same(trees_)
    sheet(trees_)
