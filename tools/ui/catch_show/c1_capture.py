"""Captures of the catch screen in the real game (task c1): the real end of a dive (Banners.greatDive) in a Studio
playtest, shot frame by frame on a stopped clock, the press logic spammed, and the catch slots while riding.
    python tools/ui/catch_show/c1_capture.py install | remove | listen | log
    python tools/ui/catch_show/c1_capture.py still <t> [name]   # one shot at t seconds
    python tools/ui/catch_show/c1_capture.py final              # docs/attachments/catch-ui-final.gif
    python tools/ui/catch_show/c1_capture.py skip               # catch-ui-skip.gif: clicks while it plays
    python tools/ui/catch_show/c1_capture.py spam               # the press logic, spammed, logged
    python tools/ui/catch_show/c1_capture.py ride               # on a fish: catch-inventory.png once one is tamed
Needs Studio with the studio-runner plugin, Rojo serving this repo, and a playtest running (after `install`).
"""
import json
import shutil
import sys
import tempfile
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import capture as C  # noqa: E402

HERE = Path(__file__).resolve().parent
OUT = C.OUT
ATT = C.ATT
PICS = C.PICS
FPS = 12
T0 = 1000.0  # the stopped clock's start


def install(remove=False):
    src = (HERE / "c1_client.luau").read_text()
    job = f"""local sps = game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts")
local old = sps:FindFirstChild("ZZCatchC1")
if old then old:Destroy() end
if {C.lua(remove)} then return "removed" end
local s = Instance.new("LocalScript")
s.Name = "ZZCatchC1"
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


def crop(im):
    # the middle of the game view: the screen and a little round it
    W, H = im.size
    half = int(H * 0.7)
    return im.crop((W // 2 - half, 0, W // 2 + half, H))


def start_show(count=None, best=True):
    set_attrs(C1Clock=T0, C1Count=count, C1Best=best)
    set_attrs(C1Show=time.time())
    time.sleep(2.0)  # (the fish pictures load)


def at(t, name):
    set_attrs(C1Clock=T0 + t)
    return C.shot(name, 0.35)


def save_gif(pics, path, fps=FPS, hold_last=8):
    pics = pics + [pics[-1]] * hold_last
    small = [p.resize((p.width * 560 // p.height, 560)) for p in pics]
    pal = [p.convert("P", palette=1, colors=255) for p in small]
    pal[0].save(path, save_all=True, append_images=pal[1:], duration=int(1000 / fps), loop=0, disposal=1)


def final():
    start_show()
    ts = [i / FPS for i in range(int(4.4 * FPS))]
    pics = [crop(at(t, f"final_{i:03d}")) for i, t in enumerate(ts)]
    pics[-1].save(ATT / "catch-ui-final.png")
    save_gif(pics, ATT / "catch-ui-final.gif")
    # and its close: a click, the fade
    set_attrs(C1Press=f"f{int(time.time())}:1:0")
    time.sleep(0.5)
    out = [crop(at(4.4 + i / FPS, f"close_{i:02d}")) for i in range(6)]
    save_gif(pics + out, ATT / "catch-ui-final.gif", hold_last=4)
    print("final", len(pics) + len(out))


def skip():
    """Clicks while it plays: at 0.8 s (skips to the end), at 1.3 s (closes), more after (nothing)."""
    start_show()
    pics = []
    t = 0.0
    step = 1 / FPS
    plan = {round(0.8, 3): "skip", round(1.3, 3): "close", round(1.4, 3): "spam"}
    i = 0
    while t < 2.0:
        key = round(t, 3)
        for when, what in plan.items():
            if abs(key - when) < step / 2:
                set_attrs(C1Clock=T0 + t)
                time.sleep(0.2)
                n = 1 if what != "spam" else 8
                set_attrs(C1Press=f"{what}{i}:{n}:0")
                time.sleep(0.4)
        pics.append(crop(at(t, f"skip_{i:03d}")))
        t += step
        i += 1
    save_gif(pics, ATT / "catch-ui-skip.gif", hold_last=3)
    print("skip", len(pics))


def spam():
    """The real clock: presses in one frame, and at 30 ms apart, at different moments."""
    for label, wait, n, gap in [("burst", 0.4, 12, 0), ("rapid", 0.4, 10, 30), ("late", 5.0, 6, 25)]:
        set_attrs(C1Clock=None, C1Count=None, C1Best=True)
        set_attrs(C1Show=time.time())
        time.sleep(wait)
        set_attrs(C1Press=f"{label}:{n}:{gap}")
        time.sleep(1.8)
    print(C.log())


def ride():
    set_attrs(C1Clock=None)
    set_attrs(C1Ride=time.time())
    for k in range(40):
        time.sleep(1)
        lg = C.log()
        last = [ln for ln in lg.splitlines() if ln.startswith("caught")]
        if last and last[-1].count("Id") >= 1:
            time.sleep(0.6)
            im = C.shot("inventory", 0.1)
            im.save(ATT / "catch-inventory.png")
            print("caught after", k, "s:", last[-1])
            print(C.server("local RideService = require(game.ServerScriptService.Server.Services.RideService) "
                           "local p = game.Players:GetPlayers()[1] local s = {} "
                           "for _, f in RideService.carried(p) do table.insert(s, f.Id) end "
                           "return RideService.stateOf and RideService.stateOf(p) or '?', table.concat(s, ',')"))
            return
    print("no catch in 40 s", C.log())


def copy_out():
    PICS.mkdir(parents=True, exist_ok=True)
    for name in ["catch-ui-final.gif", "catch-ui-skip.gif", "catch-inventory.png", "catch-ui-final.png"]:
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
        t = float(sys.argv[2])
        if len(sys.argv) > 4:
            start_show()
        crop(at(t, sys.argv[3] if len(sys.argv) > 3 else "still")).save(OUT / f"{sys.argv[3] if len(sys.argv) > 3 else 'still'}.png")
    elif what == "show":
        start_show()
    elif what == "final":
        final()
    elif what == "skip":
        skip()
    elif what == "spam":
        spam()
    elif what == "ride":
        ride()
    elif what == "copy":
        copy_out()
    print(json.dumps("done"))
