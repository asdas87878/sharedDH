"""Captures for the catch-UI option sheets (task s3): the game's own looks (Client.UI.CatchShow.preview) in a Studio
playtest, stopped at chosen times, many cells a shot.
    python tools/ui/catch_show/capture.py install | remove | listen | log | probe
    python tools/ui/catch_show/capture.py back            # the backdrop: a shot of the dock with the HUD hidden
    python tools/ui/catch_show/capture.py sheet [looks]   # key frames + GIF per look, then the sheet
Needs Studio open with the studio-runner plugin, Rojo serving this repo, and a playtest running (after `install`).
Frames go to work/catch_show/, the sheet to docs/attachments/catch-ui-options-1.png and the GIFs beside it.
"""
import json
import shutil
import subprocess
import sys
import tempfile
import time
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
OUT = ROOT / "work/catch_show"
OUT.mkdir(parents=True, exist_ok=True)
ATT = ROOT / "docs/attachments"
PICS = Path.home() / "Pictures/ride-a-fish/sheets"
RUN = str(Path.home() / "Projects/studio-runner/studio-run.mjs")
VIEW = (3, 142, 1986, 1207)  # the game view inside the Studio window's screenshot (as the land strip's captures)
BACK_NAME = "catch_back_s3.png"
VERSIONS = Path.home() / ".var/app/org.vinegarhq.Vinegar/data/vinegar/versions"  # Studio (Vinegar)

# the catch shown on every sheet: the reference's full seven, one of each rarity up to a Legendary
LIST = [
    {"Id": "Clownfish", "Tier": "Common"},
    {"Id": "YellowTang", "Tier": "Common"},
    {"Id": "Lionfish", "Tier": "Uncommon"},
    {"Id": "Dolphin", "Tier": "Rare"},
    {"Id": "ReefShark", "Tier": "Epic"},
    {"Id": "MantaRay", "Tier": "Epic"},
    {"Id": "Megalodon", "Tier": "Legendary"},
]
METRES = 312
# a cell's size (HUD units) by look
CELL = {1: (480, 250), 2: (300, 370), 3: (460, 310), 4: (600, 130)}
NAMES = {1: "Cards", 2: "Stack", 3: "Big number", 4: "Toast"}
WHAT = {
    1: "the title pops over a streak; each fish drops in face down, flips over with a burst, the count ticks; then the metres",
    2: "a list at the left: each fish slides in as a row (name, rarity), a gold badge counts them; the metres at its foot",
    3: "rays turn behind one big number that rolls up a fish at a time; each fish bursts out of it to an arc",
    4: "a compact pill drops in under the strip and widens as each fish pops in, the count, then the metres",
}
FPS = 12.5
TOP = 64  # clear of Roblox's own buttons at the top left


def run(args, timeout=180):
    r = subprocess.run(["node", RUN, *args], capture_output=True, text=True, timeout=timeout)
    return (r.stdout + r.stderr).strip()


def server(code):
    return run(["--ctx", "server", "--code", code])


def lua(v):
    if isinstance(v, bool):
        return "true" if v else "false"
    if isinstance(v, (int, float)):
        return str(v)
    return "[==[" + str(v) + "]==]"


def attrs(**kw):
    code = "local RS = game:GetService('ReplicatedStorage') "
    for k, v in kw.items():
        code += f"RS:SetAttribute('Catch{k}', {lua(v)}) "
    return server(code + "return 'ok'")


def install(remove=False):
    src = (HERE / "capture_client.luau").read_text()
    job = f"""local sps = game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts")
local old = sps:FindFirstChild("ZZCatchShow")
if old then old:Destroy() end
if {lua(remove)} then return "removed" end
local s = Instance.new("LocalScript")
s.Name = "ZZCatchShow"
s.Source = {lua(src)}
s.Parent = sps
return "installed " .. #s.Source
"""
    with tempfile.NamedTemporaryFile("w", suffix=".luau", delete=False) as f:
        f.write(job)
    return run([f.name])


LISTEN = """local RS = game:GetService('ReplicatedStorage')
local SS = game:GetService('ServerStorage')
local log = SS:FindFirstChild('ZZCatchLog') or Instance.new('StringValue')
log.Name = 'ZZCatchLog' log.Parent = SS
if not RS:FindFirstChild('ZZCatchReport') then
	local r = Instance.new('RemoteEvent') r.Name = 'ZZCatchReport' r.Parent = RS
	r.OnServerEvent:Connect(function(_, text) log.Value = string.sub(log.Value .. '\\n' .. tostring(text), -3000) end)
end
return 'listening'"""


def log():
    return server("local v = game:GetService('ServerStorage'):FindFirstChild('ZZCatchLog') return v and v.Value or 'none'")


def shot(name, wait=1.2):
    time.sleep(wait)
    raw = OUT / "raw.png"
    if raw.exists():
        raw.unlink()
    run(["shot", str(raw)])
    for _ in range(10):
        try:
            im = Image.open(raw).convert("RGB").crop(VIEW)
            im.save(OUT / f"{name}.png")
            return im
        except OSError:
            time.sleep(0.5)
    raise RuntimeError("no shot")


def layout(look, count, scale=1.0, gap=6):
    """Cells of one look in a grid over the view; returns the cells (positions in view pixels)."""
    w, h = CELL[look]
    W, H = VIEW[2] - VIEW[0], VIEW[3] - VIEW[1] - TOP
    cw, ch = int(w * scale), int(h * scale)
    per_row = max(1, (W + gap) // (cw + gap))
    rows = max(1, (H + gap) // (ch + gap))
    cells = []
    for i in range(min(count, per_row * rows)):
        r, c = divmod(i, per_row)
        cells.append({"x": c * (cw + gap), "y": TOP + r * (ch + gap), "w": w, "h": h, "s": scale, "look": look,
                      "metres": METRES, "best": True, "list": LIST})
    return cells


def frames(look, ts, scale=1.0, tag="f"):
    """Pictures of one look at each time in ts (as many shots as it takes)."""
    out = []
    per = len(layout(look, 999, scale))
    cells = layout(look, min(per, len(ts)), scale)
    attrs(Cells=json.dumps(cells), On=True, HideHud=True)
    time.sleep(2.5)  # (the models load into the pictures)
    for start in range(0, len(ts), per):
        chunk = ts[start:start + per]
        attrs(Times=json.dumps(chunk + [0] * (len(cells) - len(chunk))))
        view = shot(f"{tag}{look}_{start}")
        for i, _ in enumerate(chunk):
            c = cells[i]
            out.append(view.crop((c["x"], c["y"], c["x"] + int(c["w"] * scale), c["y"] + int(c["h"] * scale))))
    return out


def lengths():
    """Each look's length in seconds, worked out as CatchShow does (7 fish)."""
    n = len(LIST)
    hold, out = 2.2, 0.32
    cards = 0.62 + (n - 1) * 0.3 + 0.26 + 0.3 + 0.7 + hold + out
    stack = 0.42 + (n - 1) * 0.24 + 0.18 + 0.22 + 0.7 + hold + out + 0.05 * n
    big = 0.7 + (n - 1) * 0.3 + 0.24 + 0.32 + 0.7 + hold + out
    toast = 0.42 + (n - 1) * 0.22 + 0.1 + 0.2 + 0.7 + hold + 0.2 + out
    return {1: cards, 2: stack, 3: big, 4: toast}


def keytimes(look):
    """The key frames of a look: its moves, not even steps."""
    n = len(LIST)
    if look == 1:
        c = lambda i: 0.62 + i * 0.3  # noqa: E731
        return [0.12, 0.3, c(0) + 0.08, c(0) + 0.24, c(0) + 0.42, c(2) + 0.3, c(4) + 0.3, c(6) + 0.3,
                c(6) + 0.75, c(6) + 1.3, lengths()[1] - 0.2]
    if look == 2:
        r = lambda i: 0.42 + i * 0.24  # noqa: E731
        return [0.1, 0.3, r(0) + 0.15, r(1) + 0.15, r(3) + 0.15, r(5) + 0.15, r(6) + 0.3, r(6) + 0.75,
                r(6) + 1.3, lengths()[2] - 0.45, lengths()[2] - 0.15]
    if look == 3:
        b = lambda i: 0.7 + i * 0.3  # noqa: E731
        return [0.1, 0.32, b(0) + 0.1, b(0) + 0.3, b(2) + 0.3, b(4) + 0.3, b(6) + 0.1, b(6) + 0.36,
                b(6) + 0.9, b(6) + 1.5, lengths()[3] - 0.2]
    t = lambda i: 0.42 + i * 0.22  # noqa: E731
    return [0.1, 0.3, t(0) + 0.12, t(2) + 0.12, t(4) + 0.12, t(6) + 0.12, t(6) + 0.5, t(6) + 0.9,
            t(6) + 1.3, lengths()[4] - 0.2, lengths()[4] - 0.08]


def font(size):
    for p in ["/usr/share/fonts/TTF/DejaVuSans-Bold.ttf", "/usr/share/fonts/dejavu/DejaVuSans-Bold.ttf",
              "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"]:
        if Path(p).exists():
            return ImageFont.truetype(p, size)
    return ImageFont.load_default()


def make_gif(look, pics, path):
    pal = [p.convert("P", palette=Image.ADAPTIVE, colors=255) for p in pics]
    pal[0].save(path, save_all=True, append_images=pal[1:], duration=int(1000 / FPS), loop=0, optimize=False,
                disposal=1)


def sheet(looks, keys, ingame):
    """One sheet: a row per look, its key frames left to right with their times, and the look in the game."""
    F, f, s = font(30), font(20), font(16)
    thumb_h = 200
    rows = []
    for look in looks:
        pics = [p for _, p in keys[look]]
        scale = thumb_h / pics[0].height
        tw = int(pics[0].width * scale)
        if tw > 330:  # the toast is wide and low: shrink to width instead
            scale = 330 / pics[0].width
            tw = 330
        th = int(pics[0].height * scale)
        rows.append((look, tw, th, scale))
    cols = 6
    pad = 14
    width = pad + cols * (330 + pad) + 420
    height = 110
    for look, tw, th, _ in rows:
        n = len(keys[look])
        height += 60 + ((n + cols - 1) // cols) * (th + 34) + pad
    img = Image.new("RGB", (width, height), (24, 26, 34))
    d = ImageDraw.Draw(img)
    d.text((pad, 18), "Catch UI options: the end of a dive, counting every fish home (task s3)", font=F, fill="white")
    d.text((pad, 60), "Each row: the look's key frames in order (seconds since it began), 7 fish caught, a new best, "
           "312 m. Right: the look in the game at its own place. Switch: Kit.CatchLook (0 = today's, unchanged).",
           font=s, fill=(190, 200, 215))
    y = 100
    for look, tw, th, scale in rows:
        d.text((pad, y), f"{look}  {NAMES[look]}", font=F, fill=(255, 210, 63))
        d.text((pad + 230, y + 9), WHAT[look], font=s, fill=(200, 210, 225))
        y += 48
        top = y
        for i, (t, p) in enumerate(keys[look]):
            r, c = divmod(i, cols)
            x = pad + c * (330 + pad)
            yy = y + r * (th + 34)
            q = p.resize((tw, th), Image.LANCZOS)
            img.paste(q, (x + (330 - tw) // 2, yy))
            d.text((x, yy + th + 4), f"{t:.2f} s", font=f, fill=(220, 225, 235))
        n = len(keys[look])
        y += ((n + cols - 1) // cols) * (th + 34)
        g = ingame.get(look)
        if g:
            gw = 400
            gh = int(g.height * gw / g.width)
            img.paste(g.resize((gw, gh), Image.LANCZOS), (width - gw - pad, top))
            d.text((width - gw - pad, top + gh + 4), "in the game", font=f, fill=(220, 225, 235))
            y = max(y, top + gh + 30)
        y += pad
    return img


def back():
    """The backdrop: the game view with the HUD hidden, put in Studio's content folder for the cells."""
    attrs(On=True, HideHud=True, Cells="[]")
    view = shot("back", 1.5)
    W, H = view.size
    crop = view.crop((int(W * 0.25), int(H * 0.12), int(W * 0.75), int(H * 0.62)))
    p = OUT / BACK_NAME
    crop.save(p)
    copied = 0
    for version in VERSIONS.glob("version-*"):
        dst = version / "content/textures/ridefish"
        dst.mkdir(parents=True, exist_ok=True)
        shutil.copy(p, dst / BACK_NAME)
        copied += 1
    print("backdrop copied to", copied, "version folders")
    attrs(Back=f"rbxasset://textures/ridefish/{BACK_NAME}")


def do_sheet(looks):
    keys, ingame = {}, {}
    L = lengths()
    for look in looks:
        kt = keytimes(look)
        pics = frames(look, kt, 1.0, "k")
        keys[look] = list(zip(kt, pics))
        n = int(L[look] * FPS) + 1
        ts = [i / FPS for i in range(n)]
        gpics = frames(look, ts, 1.0, "g")
        make_gif(look, gpics, ATT / f"catch-ui-option-{look}.gif")
        print("gif", look, len(gpics))
        # in the game: the HUD up, the look at its own place, near the end of its count
        attrs(Cells=json.dumps([{"game": True, "look": look, "metres": METRES, "best": True, "list": LIST}]),
              HideHud=False, Times=json.dumps([kt[-3]]))
        time.sleep(2.5)
        ingame[look] = shot(f"game{look}")
    img = sheet(looks, keys, ingame)
    out = ATT / "catch-ui-options-1.png"
    img.save(out)
    PICS.mkdir(parents=True, exist_ok=True)
    shutil.copy(out, PICS / out.name)
    for look in looks:
        g = ATT / f"catch-ui-option-{look}.gif"
        if g.exists():
            shutil.copy(g, PICS / g.name)
    attrs(On=False, Cells="[]", HideHud=False)
    print("sheet", out)


if __name__ == "__main__":
    what = sys.argv[1]
    if what == "install":
        print(install())
    elif what == "remove":
        print(install(remove=True))
    elif what == "listen":
        print(server(LISTEN))
    elif what == "log":
        print(log())
    elif what == "back":
        back()
    elif what == "probe":
        look = int(sys.argv[2]) if len(sys.argv) > 2 else 1
        ts = [float(x) for x in sys.argv[3:]] or [0.3, 1.0, 2.0, 4.0]
        for i, p in enumerate(frames(look, ts, 1.0, "probe")):
            p.save(OUT / f"probe_{look}_{i}.png")
        print(log())
    elif what == "sheet":
        looks = [int(x) for x in sys.argv[2:]] or [1, 2, 3, 4]
        do_sheet(looks)
