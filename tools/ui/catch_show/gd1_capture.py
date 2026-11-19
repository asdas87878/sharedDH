"""Captures of GREAT DIVE on caught text 5's banner (task gd1, CatchShow look 5 = DiveScreen) in the real game: the
real end of a dive (Banners.greatDive) in a Studio playtest, shot frame by frame on a stopped clock.
    python tools/ui/catch_show/gd1_capture.py install | remove | listen | log
    python tools/ui/catch_show/gd1_capture.py still <variant> <t>   # one shot
    python tools/ui/catch_show/gd1_capture.py variant <n>           # work/catch_show/gd1_<n>_*.png + great-dive-option-<n>.gif
    python tools/ui/catch_show/gd1_capture.py final                 # variant 1 with a click to close: great-dive-final.gif
    python tools/ui/catch_show/gd1_capture.py skip                  # a click while it comes in, a click to close, spam
    python tools/ui/catch_show/gd1_capture.py sheet                 # great-dive-options-1.png from the variants' frames
    python tools/ui/catch_show/gd1_capture.py copy                  # to ~/Pictures/ride-a-fish/sheets/
Needs Studio with the studio-runner plugin, the repo's code in the place, and a playtest running (after `install`).
"""
import shutil
import sys
import tempfile
import time
from pathlib import Path

from PIL import Image, ImageDraw

sys.path.insert(0, str(Path(__file__).resolve().parent))
import capture as C  # noqa: E402
import c1_capture as K  # noqa: E402

HERE = Path(__file__).resolve().parent
OUT, ATT, PICS = C.OUT, C.ATT, C.PICS
FPS = 12
T0 = 1000.0
LENGTH = 4.4  # seconds shot per variant (settled at about 3.8)
NAMES = {1: "Slam", 2: "Drop", 3: "Pop", 4: "Stamp"}
WHAT = {
    1: "band slashes open, fish slam down from the camera, the number shimmers gold",
    2: "band drops and bounces, fish drop and bounce, the number in each fish's rarity colours",
    3: "band unrolls, fish pop and overshoot, the number bursts on every count",
    4: "band and fish stamp down with dust, the number shimmers and bursts",
}
STRIP = [0.14, 0.34, 0.72, 1.3, 1.9, 2.6, 3.2, 4.3]


def install(remove=False):
    src = (HERE / "gd1_client.luau").read_text()
    job = f"""local sps = game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts")
local old = sps:FindFirstChild("ZZCatchGD1")
if old then old:Destroy() end
if {C.lua(remove)} then return "removed" end
local s = Instance.new("LocalScript")
s.Name = "ZZCatchGD1"
s.Source = {C.lua(src)}
s.Parent = sps
return "installed " .. #s.Source
"""
    with tempfile.NamedTemporaryFile("w", suffix=".luau", delete=False) as f:
        f.write(job)
    return C.run([f.name])


def set_attrs(**kw):
    code = "local RS = game:GetService('ReplicatedStorage') "
    for k, v in kw.items():
        code += f"RS:SetAttribute('{k}', {'nil' if v is None else C.lua(v)}) "
    return C.server(code + "return 'ok'")


def start(variant, count=None, best=True):
    set_attrs(GD1Clock=T0, GD1Look=variant, GD1Count=count, GD1Best=best)
    set_attrs(GD1Show=time.time())
    time.sleep(2.0)  # (the fish pictures load)


def at(t, name):
    set_attrs(GD1Clock=T0 + t)
    return K.crop(K.vshot(name))


def times():
    return [i / FPS for i in range(int(LENGTH * FPS) + 1)]


def variant(n):
    start(n)
    pics = [at(t, f"gd1_{n}_{i:03d}") for i, t in enumerate(times())]
    K.save_gif(pics, ATT / f"great-dive-option-{n}.gif", fps=FPS)
    print("variant", n, len(pics))
    return pics


def final():
    pics = variant(1)
    pics[-1].save(ATT / "great-dive-final.png")
    set_attrs(GD1Press=f"close{int(time.time())}:1")
    time.sleep(0.5)
    out = [at(LENGTH + i / 24, f"gd1_close_{i:02d}") for i in range(9)]
    K.save_gif(pics + out, ATT / "great-dive-final.gif", fps=FPS, hold_last=4)
    print("final", len(pics) + len(out))


def skip():
    """On the real clock: a click at 0.9 s skips to the end, the next closes, 8 more in one frame do nothing."""
    set_attrs(GD1Clock=None, GD1Look=1, GD1Count=None, GD1Best=True)
    set_attrs(GD1Show=time.time())
    time.sleep(0.9)
    set_attrs(GD1Press=f"skip{int(time.time())}:1")
    time.sleep(0.4)
    a = K.crop(K.vshot("gd1_skip_a", 0.1))
    set_attrs(GD1Press=f"close{int(time.time())}:1")
    set_attrs(GD1Press=f"spam{int(time.time())}:8")
    time.sleep(0.8)
    b = K.crop(K.vshot("gd1_skip_b", 0.1))
    print(C.log()[-800:])
    return a, b


def sheet():
    pics = {}
    for n in NAMES:
        frames = []
        for t in STRIP:
            i = min(int(round(t * FPS)), len(times()) - 1)
            p = OUT / f"gd1_{n}_{i:03d}.png"
            frames.append(Image.open(p).convert("RGB"))
        pics[n] = frames
    cw = 300
    ch = int(frames[0].height * cw / frames[0].width)
    head = 40
    W = 20 + len(STRIP) * (cw + 6)
    H = 90 + len(NAMES) * (ch + head + 16)
    im = Image.new("RGB", (W, H), (22, 26, 36))
    d = ImageDraw.Draw(im)
    d.text((20, 18), "GREAT DIVE on caught text 5's banner: four variants (Kit.DiveLook), frames at "
           + ", ".join(f"{t:g}" for t in STRIP) + " s", font=C.font(26), fill="white")
    d.text((20, 54), "In the real game (Studio playtest, the dock after a dive): 7 fish, 312 m, a new best. "
           "A click skips to the end, the next closes.", font=C.font(18), fill=(190, 200, 220))
    y = 90
    for n, frames in pics.items():
        d.text((20, y + 6), f"{n} {NAMES[n]}" + ("  (default)" if n == 1 else "") + f": {WHAT[n]}",
               font=C.font(22), fill=(255, 210, 63))
        y += head
        for k, f in enumerate(frames):
            im.paste(f.resize((cw, ch)), (20 + k * (cw + 6), y))
            d.text((24 + k * (cw + 6), y + ch - 22), f"{STRIP[k]:g} s", font=C.font(16), fill="white")
        y += ch + 16
    im.save(ATT / "great-dive-options-1.png")
    print("sheet", im.size)


def copy_out():
    PICS.mkdir(parents=True, exist_ok=True)
    names = ["great-dive-final.gif", "great-dive-final.png", "great-dive-options-1.png"]
    names += [f"great-dive-option-{n}.gif" for n in NAMES]
    for name in names:
        p = ATT / name
        if p.exists():
            shutil.copy(p, PICS / name)
    print("copied to", PICS)


if __name__ == "__main__":
    what = sys.argv[1]
    if what == "install":
        print(install())
    elif what == "remove":
        print(install(remove=True))
    elif what == "listen":
        print(C.server(C.LISTEN))
    elif what == "log":
        print(C.log())
    elif what == "still":
        start(int(sys.argv[2]))
        at(float(sys.argv[3]), "gd1_still").save(OUT / "gd1_still.png")
    elif what == "variant":
        variant(int(sys.argv[2]))
    elif what == "final":
        final()
    elif what == "skip":
        skip()
    elif what == "sheet":
        sheet()
    elif what == "copy":
        copy_out()
