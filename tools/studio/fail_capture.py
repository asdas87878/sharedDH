"""The fail outcomes at 0 Oxygen (task e1, Config.Fail): GIFs from the real game in a Studio playtest, frame by frame.
    python tools/studio/fail_capture.py install | remove          (in Edit, before Play: a server Script that takes commands)
    python tools/studio/fail_capture.py gif <Fish> <Outcome> [fps]   (in a playtest: ride that fish, fail, capture)
    python tools/studio/fail_capture.py sheet <name> <gif> ...        (several GIFs side by side, in a grid)
    python tools/studio/fail_capture.py restore                       (in a playtest: clears every switch a capture set)
How: the game's own Studio-only switches hold the clocks (workspace FailClock for FailController, DeathClock for the drown,
FailSlow for the server's waits), so each frame is set, then shot (studio-run.mjs shot, about 1 s each). The fish's own
swim and the camera's easing still run on real time between frames, so the motion is the outcome's, slightly smoothed.
Frames go to work/fail_capture/, GIFs to docs/attachments/fail-<outcome>-<fish>.gif and ~/Pictures/ride-a-fish/sheets/.
Needs Studio open with the studio-runner plugin and Rojo serving this repo.
"""
import json
import shutil
import signal
import subprocess
import sys
import tempfile
import time
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "work/fail_capture"
OUT.mkdir(parents=True, exist_ok=True)
SHEETS = Path.home() / "Pictures/ride-a-fish/sheets"
RUN = str(Path.home() / "Projects/studio-runner/studio-run.mjs")
# the game view inside the Studio window's shot (2400 x 1280, panels on the right)
CROP = (4, 142, 1984, 1205)
WIDTH = 560

SERVER = r'''
local RS = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RideService = require(game:GetService("ServerScriptService"):WaitForChild("Server"):WaitForChild("Services"):WaitForChild("RideService"))
RS:SetAttribute("E1Ready", true)
RS:GetAttributeChangedSignal("E1Cmd"):Connect(function()
	local cmd = tostring(RS:GetAttribute("E1Cmd") or "")
	local verb, arg = string.match(cmd, "^(%w+)|?([%w]*)")
	local player = Players:GetPlayers()[1]
	if not player then
		RS:SetAttribute("E1Said", "no player")
		return
	end
	local ok, said = pcall(function()
		if verb == "ride" then
			-- (further down than the sandbox's start, which faces the lane's wall: open water round the fish)
			local at, along = RideService.sandboxStart()
			RideService.sandboxReset(player, nil, arg, nil, { At = at + along * (tonumber(RS:GetAttribute("E1Ahead")) or 160), Along = along })
			return "ride " .. arg
		elseif verb == "fail" then
			return "fail " .. tostring(RideService.forceFail(player, if arg ~= "" then arg else nil))
		elseif verb == "home" then
			RideService.sendHome(player)
			return "home"
		end
		return "?"
	end)
	RS:SetAttribute("E1Said", tostring(said) .. " " .. tostring(ok) .. " " .. tostring(os.clock()))
end)
'''


def run(args, timeout=120):
    r = subprocess.run(["node", RUN, *args], capture_output=True, text=True, timeout=timeout)
    return (r.stdout + r.stderr).strip()


def lua(v):
    if v is None:
        return "nil"
    if isinstance(v, bool):
        return "true" if v else "false"
    if isinstance(v, (int, float)):
        return repr(v)
    return "[==[" + str(v) + "]==]"


def server(code):
    return run(["--ctx", "server", "--code", code])


def install(remove=False):
    job = f"""local sss = game:GetService("ServerScriptService")
local old = sss:FindFirstChild("ZZFailCapture")
if old then old:Destroy() end
if {lua(remove)} then return "removed" end
local s = Instance.new("Script")
s.Name = "ZZFailCapture"
s.Source = {lua(SERVER)}
s.Parent = sss
return "installed"
"""
    with tempfile.NamedTemporaryFile("w", suffix=".luau", delete=False) as f:
        f.write(job)
    return run([f.name])


def setw(**kw):
    code = ""
    for k, v in kw.items():
        code += f"workspace:SetAttribute({lua(k)}, {lua(v)}) "
    return server(code + "return 'ok'")


# What a capture holds on the playtest's workspace. Left set, they change every later dive of that playtest: CatchLook 0
# is the old plain GREAT DIVE banner, TestMaxOxygen endless breath, the clocks a frozen fail (Hugo saw the plain banner,
# 2026-11-23). So every capture clears them in a `finally`, and a killed run (SIGTERM, SIGHUP, Ctrl+C) still gets there.
HELD = ("CatchLook", "TestMaxOxygen", "FailSlow", "FailClock", "DeathClock")


def playing():
    """Whether a playtest's server is there to take a job (asking one that is not waits 30 s). None: could not tell."""
    try:
        return json.loads(run(["status"], timeout=20)).get("connected", {}).get("server", 0) > 0
    except Exception:
        return None


def restore(*more):
    """Clears the capture's switches (and `more`) off the playtest's workspace: the game as it is played."""
    if playing() is False:
        return "no playtest (its workspace went with it)"
    # (also when the status could not be read: better a 30 s wait for nothing than a switch left on)
    return setw(**{k: None for k in HELD + more})


def _killed(sig, _frame):
    raise SystemExit(128 + sig)


for _sig in (signal.SIGTERM, signal.SIGHUP):
    signal.signal(_sig, _killed)


def cmd(c):
    return server(
        f"local RS = game:GetService('ReplicatedStorage') RS:SetAttribute('E1Cmd', {lua(c + '|' + str(time.time()))}) "
        "task.wait(0.3) return RS:GetAttribute('E1Said')"
    )


def state():
    return server("local p = game:GetService('Players'):GetPlayers()[1] return p and p:GetAttribute('State') or 'none'")


def wait_state(want, timeout=30):
    end = time.time() + timeout
    s = None
    while time.time() < end:
        s = state()
        if s.strip().splitlines()[-1] in want:
            return s
        time.sleep(0.4)
    raise SystemExit(f"state stayed {s}, wanted {want}")


def shot(path):
    # (the shot is written after studio-run returns: an old file at the path was read as the new frame, so it is
    # removed first and the new one waited for until its size holds)
    path = Path(path)
    path.unlink(missing_ok=True)
    out = run(["shot", str(path)], timeout=60)
    size, end = -1, time.time() + 10
    while time.time() < end:
        now = path.stat().st_size if path.exists() else -1
        if now > 0 and now == size:
            break
        size = now
        time.sleep(0.15)
    else:
        raise SystemExit("no shot: " + out)
    im = Image.open(path).convert("RGB")
    c = im.crop(CROP)
    return c.resize((WIDTH, round(c.height * WIDTH / c.width)), Image.LANCZOS)


def label(im, text):
    d = ImageDraw.Draw(im)
    d.text((10, 8), text, fill="white", font=ImageFont.load_default(size=18), stroke_width=2, stroke_fill="black")
    return im


def save(frames, dest, fps, colours=128):
    pal = [f.quantize(colors=colours, method=Image.MEDIANCUT, dither=Image.NONE) for f in frames]
    durations = [int(1000 / fps)] * len(pal)
    durations[-1] = 900
    pal[0].save(dest, save_all=True, append_images=pal[1:], duration=durations, loop=0, optimize=True)
    SHEETS.mkdir(parents=True, exist_ok=True)
    shutil.copy(dest, SHEETS / dest.name)
    print(dest)


def gif(fish, outcome, fps=12):
    times = {"Throw": 0, "Chomp": 1.3, "Gulp": 1.5, "Wrap": 1.4, "Roll": 1.2, "Flip": 0.9, "Shell": 1.1, "Coil": 1.3, "Pin": 1.3}
    taken = outcome in ("Chomp", "Gulp", "Wrap", "Pin")
    T = times[outcome]
    n_out = int(round(T * fps)) + 1 if T > 0 else 0
    n_tail = int(round((0.7 if taken else 1.0) * fps)) + 1
    # the server's waits stretched past the capture (about 1.2 s a frame)
    slow = max(2, (n_out + 4) * 1.3 / max(T, 0.1)) if T > 0 else 60
    # (CatchLook 0: the dock's plain banner, which goes by itself, not the catch screen that waits for a press)
    setw(TestMaxOxygen=10000000, FailSlow=slow, FailClock=0, DeathClock=0, CatchLook=0)
    try:
        print(cmd("ride|" + fish))
        wait_state({"Riding"})
        time.sleep(3)
        frames = []
        # a moment of riding first (the clocks only hold the fail)
        for i in range(2):
            frames.append(label(shot(OUT / f"{outcome}_ride{i}.png"), f"{fish}: riding, Oxygen hits 0"))
        print(cmd("fail|" + outcome))
        for i in range(n_out):
            t = i / fps
            setw(FailClock=t)
            time.sleep(0.1)
            frames.append(label(shot(OUT / f"{outcome}_{i:03d}.png"), f"{fish}: {outcome}   t {t:4.2f} s"))
            print(f"\r{outcome} {i + 1}/{n_out}", end="", flush=True)
        print()
        if taken:
            for i in range(1, n_tail):
                t = T + i / fps
                setw(FailClock=t)
                time.sleep(0.1)
                frames.append(label(shot(OUT / f"{outcome}_f{i:03d}.png"), f"{fish}: {outcome}   t {t:4.2f} s"))
        else:
            if T > 0:
                setw(FailClock=T + 0.2)
            wait_state({"Drowning"}, timeout=max(40, slow * T + 10))
            for i in range(n_tail):
                t = i / fps
                setw(DeathClock=t)
                time.sleep(0.1)
                frames.append(label(shot(OUT / f"{outcome}_d{i:03d}.png"), f"{fish}: {outcome}, thrown off   +{t:4.2f} s"))
        setw(FailClock=-1, DeathClock=-1, FailSlow=1)
        print(cmd("home"))
    finally:
        print("restore:", restore())
    dest = ROOT / "docs/attachments" / f"fail-{outcome.lower()}-{fish.lower()}.gif"
    save(frames, dest, fps)
    return dest


def sheet(name, gifs, cols=3, scale=0.62):
    seqs = []
    for g in gifs:
        im = Image.open(g)
        fr = []
        try:
            while True:
                f = im.convert("RGB")
                fr.append(f.resize((round(f.width * scale), round(f.height * scale)), Image.LANCZOS))
                im.seek(im.tell() + 1)
        except EOFError:
            pass
        seqs.append(fr)
    n = max(len(s) for s in seqs)
    w, h = seqs[0][0].size
    rows = (len(seqs) + cols - 1) // cols
    frames = []
    for i in range(n):
        canvas = Image.new("RGB", (w * min(cols, len(seqs)), h * rows), "black")
        for k, s in enumerate(seqs):
            canvas.paste(s[min(i, len(s) - 1)], ((k % cols) * w, (k // cols) * h))
        frames.append(canvas)
    dest = ROOT / "docs/attachments" / name
    save(frames, dest, 10, 64)


if __name__ == "__main__":
    a = sys.argv[1:]
    if a[0] == "install":
        print(install())
    elif a[0] == "remove":
        print(install(True))
    elif a[0] == "restore":
        print(restore("FailRecord", "FailReplay", "SandboxEndlessAir"))
    elif a[0] == "gif":
        gif(a[1], a[2], int(a[3]) if len(a) > 3 else 12)
    elif a[0] == "sheet":
        sheet(a[1], a[2:])
