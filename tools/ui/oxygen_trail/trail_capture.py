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


if __name__ == "__main__":
    cmd = sys.argv[1]
    if cmd == "install":
        print(install())
    elif cmd == "remove":
        print(install(remove=True))
        print(server("local RS = game:GetService('ReplicatedStorage') RS:SetAttribute('TrailRun', 0) return 'off'"))
    elif cmd == "probe":
        attrs(Run=time.time() % 100000, Mode=2, Script=json.dumps(PLAN), T=0.5)
        time.sleep(1)
        shot(OUT / "probe.png")
        print(OUT / "probe.png")
    elif cmd == "gif":
        crop = tuple(int(x) for x in sys.argv[4].split(",")) if len(sys.argv) > 4 else None
        print(gif(int(sys.argv[2]), int(sys.argv[3]) if len(sys.argv) > 3 else 30, crop))
