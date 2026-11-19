"""Captures of the caught-text looks (task t2): the game's own UI/CaughtText in the HUD of a Studio playtest, posed
frame by frame through client.luau.
    python tools/ui/caught_text/capture.py install | remove | listen | log
    python tools/ui/caught_text/capture.py probe [look] [t]   # one whole shot, to set VIEW
    python tools/ui/caught_text/capture.py gif <look> [fps]   # docs/attachments/caught-text-<look>.gif
    python tools/ui/caught_text/capture.py sheet              # key frames of every look + rest frames by rarity
Needs Studio open with the studio-runner plugin, Rojo serving this repo (or tools/ui/catch_show/sync_src.py), a
playtest running and the player on a fish. Frames go to work/caught_text/; GIFs and the sheet also to
~/Pictures/ride-a-fish/sheets/.
"""
import shutil
import subprocess
import sys
import tempfile
import time
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
OUT = ROOT / "work/caught_text"
OUT.mkdir(parents=True, exist_ok=True)
ATT = ROOT / "docs/attachments"
PICS = Path.home() / "Pictures/ride-a-fish/sheets"
RUN = str(Path.home() / "Projects/studio-runner/studio-run.mjs")
VIEW = (3, 141, 3024, 1368)  # the game view inside the Studio shot (set from a probe)
NAMES = {1: "Punch", 2: "Stamp", 3: "Banner", 4: "Burst", 5: "Slam"}
WHAT = {
    1: "a ring closes in, CAUGHT! punches through it and rings out a wave; rarity + name rise, earnings pop",
    2: "the stamp hovers and lifts, slams down with a flash, dust and a shake; the name unrolls on a ribbon",
    3: "the old left plate redone: whips in past its place, the portrait pops, CAUGHT! drops onto it",
    4: "a point draws in, the portrait bursts out with rays, a shock ring and confetti; CAUGHT! pops over it",
    5: "a hairline streaks across and opens into a rarity band; CAUGHT! slams down, flash, screen (and camera) shake",
}
LENGTH = {1: 2.75, 2: 2.8, 3: 2.9, 4: 2.8, 5: 2.7}
KEYS = {
    1: [0.1, 0.18, 0.24, 0.4, 0.6, 1.4, 2.5, 2.62],
    2: [0.08, 0.2, 0.27, 0.36, 0.55, 1.4, 2.55, 2.68],
    3: [0.12, 0.24, 0.32, 0.45, 0.7, 1.4, 2.66, 2.8],
    4: [0.1, 0.18, 0.26, 0.38, 0.6, 1.4, 2.5, 2.64],
    5: [0.06, 0.16, 0.26, 0.32, 0.6, 1.4, 2.45, 2.56],
}
FISH = ("ReefShark", 4.2, True)  # the GIFs' catch: an Epic, its first, earning 4.2 a second
RESTS = [("Clownfish", "Common"), ("MorayEel", "Rare"), ("Megalodon", "Legendary")]
# the part of the view each GIF shows: (left, top, right, bottom) as shares of the view
CROP = {1: (0.2, 0.0, 0.8, 0.6), 2: (0.2, 0.0, 0.8, 0.6), 3: (0.0, 0.0, 0.6, 0.6), 4: (0.2, 0.0, 0.8, 0.6),
        5: (0.2, 0.0, 0.8, 0.6)}


def run(args, timeout=120):
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
        code += f"RS:SetAttribute('Caught{k}', {lua(v)}) "
    return server(code + "return 'ok'")


def install(remove=False):
    src = (HERE / "client.luau").read_text()
    job = f"""local sps = game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts")
local old = sps:FindFirstChild("ZZCaughtText")
if old then old:Destroy() end
if {lua(remove)} then return "removed" end
local s = Instance.new("LocalScript")
s.Name = "ZZCaughtText"
s.Source = {lua(src)}
s.Parent = sps
return "installed " .. #s.Source
"""
    with tempfile.NamedTemporaryFile("w", suffix=".luau", delete=False) as f:
        f.write(job)
    return run([f.name])


LISTEN = """local RS = game:GetService('ReplicatedStorage')
local SS = game:GetService('ServerStorage')
local log = SS:FindFirstChild('ZZCaughtLog') or Instance.new('StringValue')
log.Name = 'ZZCaughtLog' log.Parent = SS
if not RS:FindFirstChild('ZZCaughtReport') then
	local r = Instance.new('RemoteEvent') r.Name = 'ZZCaughtReport' r.Parent = RS
	r.OnServerEvent:Connect(function(_, text) log.Value = string.sub(log.Value .. '\\n' .. tostring(text), -3000) end)
end
return 'listening'"""


def log():
    return server("local v = game:GetService('ServerStorage'):FindFirstChild('ZZCaughtLog') return v and v.Value or 'none'")


def shot(name):
    """One shot of the view (the runner returns before the file is written: wait for it to be whole)"""
    raw = OUT / "raw.png"
    if raw.exists():
        raw.unlink()
    run(["shot", str(raw)], timeout=60)
    last = -1
    for _ in range(60):
        if raw.exists():
            size = raw.stat().st_size
            if size > 0 and size == last:
                try:
                    im = Image.open(raw).convert("RGB")
                    break
                except OSError:
                    pass
            last = size
        time.sleep(0.1)
    else:
        raise RuntimeError("no shot")
    view = im.crop(VIEW)
    view.save(OUT / f"{name}.png")
    return view


def cut(view, look):
    l, t, r, b = CROP[look]
    W, H = view.size
    return view.crop((int(W * l), int(H * t), int(W * r), int(H * b)))


def start(look, fish=FISH):
    attrs(On=True, Look=look, Fish=fish[0], Earns=fish[1], New=fish[2], T=0, Run=time.time() % 100000)
    time.sleep(1.5)  # (the portrait's model loads)


def pose(look, t, name):
    attrs(T=t)
    time.sleep(0.15)
    return cut(shot(name), look)


def font(size):
    for p in ["/usr/share/fonts/TTF/DejaVuSans-Bold.ttf", "/usr/share/fonts/dejavu/DejaVuSans-Bold.ttf"]:
        if Path(p).exists():
            return ImageFont.truetype(p, size)
    return ImageFont.load_default(size=size)


def small(frames, width=720, colours=126):
    """Frames made small: one palette from a spread of frames, plus white and black"""
    frames = [f.resize((width, int(f.height * width / f.width)), Image.LANCZOS) for f in frames]
    pick = frames[:: max(1, len(frames) // 10)]
    strip = Image.new("RGB", (width * len(pick), frames[0].height))
    for i, f in enumerate(pick):
        strip.paste(f, (width * i, 0))
    p = strip.quantize(colors=colours, method=Image.MEDIANCUT, dither=Image.NONE).getpalette()[: colours * 3]
    p += [255, 255, 255, 0, 0, 0]
    base = Image.new("P", (1, 1))
    base.putpalette(p + [0] * (768 - len(p)))
    return [f.quantize(palette=base, dither=Image.NONE) for f in frames]


def gif(look, fps=20):
    start(look)
    n = int(LENGTH[look] * fps) + 2
    frames = []
    f = font(22)
    for i in range(n):
        t = i / fps
        c = pose(look, t, f"g{look}_{i:03d}")
        d = ImageDraw.Draw(c)
        d.text((12, c.height - 34), f"{look} {NAMES[look]}   t {t:4.2f} s", fill="white", font=f, stroke_width=2,
               stroke_fill="black")
        frames.append(c)
        print(f"\r{look} {i + 1}/{n}", end="", flush=True)
    print()
    # a beat of nothing after, so the loop reads as a new catch
    frames += [frames[-1]] * 6
    dest = ATT / f"caught-text-{look}.gif"
    pal = small(frames)
    pal[0].save(dest, save_all=True, append_images=pal[1:], duration=int(1000 / fps), loop=0, optimize=True)
    PICS.mkdir(parents=True, exist_ok=True)
    shutil.copy(dest, PICS / dest.name)
    print(dest, dest.stat().st_size // 1024, "KB")
    return dest


def sheet():
    keys, rests = {}, {}
    for look in NAMES:
        start(look)
        keys[look] = [(t, pose(look, t, f"k{look}_{i}")) for i, t in enumerate(KEYS[look])]
        rests[look] = []
        for fish, tier in RESTS:
            start(look, (fish, 1.5, False))
            rests[look].append((tier, pose(look, 1.4, f"r{look}_{tier}")))
    attrs(On=False)
    F, f, s = font(34), font(20), font(17)
    tw = 300
    th = int(keys[1][0][1].height * tw / keys[1][0][1].width)
    cols = len(KEYS[1])
    pad = 12
    width = pad + (cols + 3) * (tw + pad) + 20
    row_h = 46 + th + 30
    img = Image.new("RGB", (width, 120 + 5 * (row_h + pad)), (24, 26, 34))
    d = ImageDraw.Draw(img)
    d.text((pad, 16), "Caught text options: the moment a fish becomes yours (task t2)", font=F, fill="white")
    d.text((pad, 62), "Each row: the look's key frames (seconds since the catch) for an Epic Reef Shark, the first of its "
           "kind (NEW!) earning $4.2 a second; then the look at rest for a Common, a Rare and a Legendary.", font=s,
           fill=(190, 200, 215))
    d.text((pad, 84), "Switch: Kit.CaughtLook (1 to 5; 0 = today's TAMED! plate). In Studio: workspace attribute "
           "CaughtLook. GIFs: caught-text-<n>.gif.", font=s, fill=(190, 200, 215))
    y = 120
    for look in NAMES:
        d.text((pad, y), f"{look}  {NAMES[look]}", font=F, fill=(255, 210, 63))
        d.text((pad + 230, y + 12), WHAT[look], font=s, fill=(200, 210, 225))
        yy = y + 46
        items = [(f"{t:.2f} s", p) for t, p in keys[look]] + [(f"rest: {tier}", p) for tier, p in rests[look]]
        for i, (label, p) in enumerate(items):
            x = pad + i * (tw + pad) + (20 if i >= cols else 0)
            img.paste(p.resize((tw, th), Image.LANCZOS), (x, yy))
            d.text((x, yy + th + 4), label, font=f, fill=(220, 225, 235))
        y += row_h + pad
    out = ATT / "caught-text-options-1.png"
    img.save(out)
    PICS.mkdir(parents=True, exist_ok=True)
    shutil.copy(out, PICS / out.name)
    print(out)


if __name__ == "__main__":
    what = sys.argv[1]
    if what == "install":
        print(install())
    elif what == "remove":
        print(install(remove=True))
        print(attrs(On=False))
    elif what == "listen":
        print(server(LISTEN))
    elif what == "log":
        print(log())
    elif what == "probe":
        look = int(sys.argv[2]) if len(sys.argv) > 2 else 1
        start(look)
        attrs(T=float(sys.argv[3]) if len(sys.argv) > 3 else 1.2)
        time.sleep(0.3)
        raw = OUT / "raw.png"
        shot("probe")
        print(raw, log())
    elif what == "gif":
        gif(int(sys.argv[2]), int(sys.argv[3]) if len(sys.argv) > 3 else 20)
    elif what == "sheet":
        sheet()
