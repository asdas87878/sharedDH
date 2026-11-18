"""The Oxygen ring's damage trail (task t1): GIFs of each Kit.RingLook.TickTrail, frame by frame, in a Studio playtest
while riding, through trail_client.luau (a copy of the game's own UI/Rings on its own clock; the real ring hidden).
    python tools/ui/oxygen_trail/trail_capture.py install | remove | probe | gif <mode> [fps] | all
Needs Studio open with the studio-runner plugin, Rojo serving this repo, a playtest running and the player on a fish.
Frames go to work/oxygen_trail/, GIFs to docs/attachments/oxygen-trail-<a|b|c|d>.gif and ~/Pictures/ride-a-fish/sheets/.
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
OUT = ROOT / "work/oxygen_trail"
OUT.mkdir(parents=True, exist_ok=True)
SHEETS = Path.home() / "Pictures/ride-a-fish/sheets"
RUN = str(Path.home() / "Projects/studio-runner/studio-run.mjs")
CROP = None  # set by probe: (x0, y0, x1, y1) round the ring in the Studio window's shot
NAMES = {0: "old fade", 1: "straight draw-in", 2: "hold, then ease in", 3: "draw and melt"}
LETTER = {0: "0", 1: "a", 2: "b", 3: "c"}

# Max 4500 (the big ring 2000 and the extra ring past it), 30 ticks of 150, 0.35 s apart: three on the extra ring,
# three on the big one; a pause; the 2/3 break-off as one piece; two red ticks 0.5 s apart (RedTick)
TICK = 150
PLAN = {"max": 4500, "start": 2450, "events": []}
t, a = 0.4, 2450
for _ in range(6):
    PLAN["events"].append([round(t, 3), a, a - TICK])
    a -= TICK
    t += 0.35
PLAN["events"].append([3.0, a, round(a / 3)])
a = round(a / 3)
for t in (3.5, 4.0):
    PLAN["events"].append([t, a, a - TICK])
    a -= TICK
END = 4.8
PLAN["finish"] = END


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
        code += f"RS:SetAttribute('Trail{k}', {lua(v)}) "
    return server(code + "return 'ok'")


def install(remove=False):
    src = (HERE / "trail_client.luau").read_text()
    job = f"""local sps = game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts")
local old = sps:FindFirstChild("ZZTrailCapture")
if old then old:Destroy() end
if {lua(remove)} then return "removed" end
local s = Instance.new("LocalScript")
s.Name = "ZZTrailCapture"
s.Source = {lua(src)}
s.Parent = sps
return "installed " .. #s.Source
"""
    with tempfile.NamedTemporaryFile("w", suffix=".luau", delete=False) as f:
        f.write(job)
    return run([f.name])


LISTEN = """local RS = game:GetService('ReplicatedStorage')
local SS = game:GetService('ServerStorage')
local log = SS:FindFirstChild('ZZTrailLog') or Instance.new('StringValue')
log.Name = 'ZZTrailLog' log.Parent = SS
if not RS:FindFirstChild('ZZTrailReport') then
	local r = Instance.new('RemoteEvent') r.Name = 'ZZTrailReport' r.Parent = RS
	r.OnServerEvent:Connect(function(_, text) log.Value = string.sub(log.Value .. '\\n' .. tostring(text), -3000) end)
end
return 'listening'"""


def log():
    return server("local v = game:GetService('ServerStorage'):FindFirstChild('ZZTrailLog') return v and v.Value or 'none'")


def shot(path):
    out = run(["shot", str(path)], timeout=60)
    if not Path(path).exists():
        raise SystemExit("no shot: " + out)
    return Image.open(path).convert("RGB")


def gif(mode, fps=30, crop=None, zoom=3):
    crop = crop or CROP
    frames = []
    attrs(Run=time.time() % 100000, Mode=mode, Script=json.dumps(PLAN), T=0)
    time.sleep(0.6)
    n = int(END * fps) + 1
    font = ImageFont.load_default(size=22)
    for i in range(n):
        t = i / fps
        attrs(T=t)
        time.sleep(0.12)
        im = shot(OUT / f"m{mode}_{i:03d}.png")
        c = im.crop(crop)
        c = c.resize((c.width * zoom, c.height * zoom), Image.NEAREST)
        d = ImageDraw.Draw(c)
        d.text((10, 8), f"{LETTER[mode]}: {NAMES[mode]}   t {t:4.2f} s   (x{zoom})", fill="white", font=font,
               stroke_width=2, stroke_fill="black")
        frames.append(c)
        print(f"\r{mode} {i + 1}/{n}", end="", flush=True)
    print()
    name = f"oxygen-trail-{LETTER[mode]}.gif"
    dest = ROOT / "docs/attachments" / name
    pal = [f.quantize(colors=128, method=Image.MEDIANCUT, dither=Image.NONE) for f in frames]
    pal[0].save(dest, save_all=True, append_images=pal[1:], duration=int(1000 / fps), loop=0, optimize=True)
    SHEETS.mkdir(parents=True, exist_ok=True)
    shutil.copy(dest, SHEETS / name)
    return dest


def studio_window():
    wins = json.loads(subprocess.check_output(["niri", "msg", "--json", "windows"], text=True))
    studio = [w for w in wins if "robloxstudio" in (w.get("app_id") or "").lower() or "ride-a-fish" in (w.get("title") or "")]
    return max(studio, key=lambda w: w["layout"]["window_size"][0] * w["layout"]["window_size"][1])["id"]


def moment(im):
    """The bar's length along the bottom, in pixels (the client's clock as a magenta bar)"""
    px = im.load()
    best = 0
    for y in range(im.height - 1, im.height // 2, -1):
        n = 0
        x = 0
        while x < im.width:
            r, g, b = px[x, y][:3]
            if r > 230 and g < 40 and b > 230:
                n += 1
            x += 1
        best = max(best, n)
        if best and n == 0:
            break
    return best


def small(frames, side=420):
    """Frames made small for the vault (b was 10 MB at 600 px and 96 colours): 420 px, one palette of 62 colours taken
    from eight frames, plus pure white and black so the white piece and the outline stay true"""
    frames = [f.resize((side, side), Image.LANCZOS) if f.width != side else f for f in frames]
    pick = frames[:: max(1, len(frames) // 8)]
    sheet = Image.new("RGB", (side * len(pick), side))
    for i, f in enumerate(pick):
        sheet.paste(f, (side * i, 0))
    p = sheet.quantize(colors=62, method=Image.MEDIANCUT, dither=Image.NONE).getpalette()[: 62 * 3]
    p += [255, 255, 255, 0, 0, 0]
    base = Image.new("P", (1, 1))
    base.putpalette(p + [0] * (768 - len(p)))
    return [f.quantize(palette=base, dither=Image.NONE) for f in frames]


def live(mode, slow=0.12, crop=None, zoom=1.5, fps=25):
    """Shots as fast as niri takes them while the copy runs on a slowed clock; each frame's moment read off the bar"""
    crop = crop or CROP
    win = studio_window()
    try:
        clip = subprocess.run(["wl-paste", "-n", "-t", "text/plain"], capture_output=True, text=True, timeout=2).stdout
    except Exception:
        clip = None
    attrs(Run=time.time() % 100000, Mode=mode, Script=json.dumps(PLAN), T=0, Slow=0, HoldCam=True)
    time.sleep(0.8)
    attrs(Slow=slow, Go=time.time() % 100000)
    files = []
    stop = time.time() + END / slow + 1.5
    i = 0
    while time.time() < stop:
        f = OUT / f"l{mode}_{i:04d}.png"
        if f.exists():
            f.unlink()
        subprocess.run(["niri", "msg", "action", "screenshot-window", "--id", str(win), "--path", str(f)], check=True)
        files.append(f)
        i += 1
    attrs(HoldCam=False)
    if clip:
        subprocess.run(["wl-copy"], input=clip, text=True, timeout=2)
    time.sleep(0.5)
    shots = []
    for f in files:
        for _ in range(30):
            if f.exists():
                break
            time.sleep(0.1)
        im = Image.open(f).convert("RGB")
        shots.append((moment(im), im))
    full = max(m for m, _ in shots)
    print(f"{len(shots)} shots, bar full {full} px")
    # one frame per 1/fps of the clock: the shot nearest each moment
    timed = [(m / full * END, im) for m, im in shots if m > 0]
    font = ImageFont.load_default(size=20)
    frames = []
    for k in range(int(END * fps) + 1):
        t = k / fps
        tt, im = min(timed, key=lambda p: abs(p[0] - t))
        c = im.crop(crop)
        c = c.resize((int(c.width * zoom), int(c.height * zoom)), Image.LANCZOS)
        d = ImageDraw.Draw(c)
        d.text((8, 6), f"{LETTER[mode]}: {NAMES[mode]}", fill="white", font=font, stroke_width=2, stroke_fill="black")
        d.text((8, c.height - 28), f"t {tt:4.2f} s", fill="white", font=font, stroke_width=2, stroke_fill="black")
        frames.append(c)
    name = f"oxygen-trail-{LETTER[mode]}.gif"
    dest = ROOT / "docs/attachments" / name
    pal = small(frames)
    pal[0].save(dest, save_all=True, append_images=pal[1:], duration=int(1000 / fps), loop=0, optimize=True)
    print(f"{dest.stat().st_size // 1024} KB")
    SHEETS.mkdir(parents=True, exist_ok=True)
    shutil.copy(dest, SHEETS / name)
    return dest


if __name__ == "__main__":
    cmd = sys.argv[1]
    if cmd == "install":
        print(install())
    elif cmd == "remove":
        print(install(remove=True))
        print(server("local RS = game:GetService('ReplicatedStorage') RS:SetAttribute('TrailRun', 0) return 'off'"))
    elif cmd == "listen":
        print(server(LISTEN))
    elif cmd == "log":
        print(log())
    elif cmd == "probe":
        attrs(Run=time.time() % 100000, Mode=2, Script=json.dumps(PLAN), T=0.5)
        time.sleep(1)
        shot(OUT / "probe.png")
        print(OUT / "probe.png")
    elif cmd == "live":
        crop = tuple(int(x) for x in sys.argv[4].split(",")) if len(sys.argv) > 4 else None
        print(live(int(sys.argv[2]), float(sys.argv[3]), crop))
    elif cmd == "gif":
        crop = tuple(int(x) for x in sys.argv[4].split(",")) if len(sys.argv) > 4 else None
        print(gif(int(sys.argv[2]), int(sys.argv[3]) if len(sys.argv) > 3 else 30, crop))
