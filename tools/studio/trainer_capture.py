"""The seahorse trainer (task h1, docs/design/trainer.md): a GIF and a still from the real game in a Studio playtest.
    python tools/studio/trainer_capture.py install | remove   (in Edit, before Play: a server Script and a LocalScript)
    python tools/studio/trainer_capture.py still               (in a playtest: the coil and the pad, no rider)
    python tools/studio/trainer_capture.py gif [fps]           (in a playtest: walk up, hop on, rock with the pops, hop off)
How: TrainerController runs on workspace "TrainerClock" when it is a number (Studio only), so each frame is set, then
shot (studio-run.mjs shot, about 1 s each), as tools/studio/fail_capture.py does. The LocalScript holds the camera
(workspace H1Cam), walks the player along H1Walk on the same clock, and asks to get off (H1Off) the way a jump does
(Remotes.Trainer "Off"). The server's gains come in real time; under a held clock the pops show the last one on the
clock's own half-second beat. Frames go to work/trainer_capture/, the GIF and still to docs/attachments/ and
~/Pictures/ride-a-fish/sheets/. Needs Studio open with the studio-runner plugin and Rojo serving this repo.
"""
import shutil
import subprocess
import sys
import tempfile
import time
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "work/trainer_capture"
OUT.mkdir(parents=True, exist_ok=True)
SHEETS = Path.home() / "Pictures/ride-a-fish/sheets"
RUN = str(Path.home() / "Projects/studio-runner/studio-run.mjs")
# the game view inside the Studio window's shot (2400 x 1280, panels on the right)
CROP = (4, 142, 1984, 1205)
WIDTH = 720

SERVER = r'''
local RS = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RideService = require(game:GetService("ServerScriptService"):WaitForChild("Server"):WaitForChild("Services"):WaitForChild("RideService"))
local function ride(player)
	local plots = workspace.ClaudeBlockout.Dock.Plots
	local name = player:GetAttribute("Plot")
	local plot = (type(name) == "string" and plots:FindFirstChild(name)) or plots:GetChildren()[1]
	return plot:FindFirstChild("TrainerRide")
end
RS:GetAttributeChangedSignal("H1Cmd"):Connect(function()
	local cmd = tostring(RS:GetAttribute("H1Cmd") or "")
	local verb, arg = string.match(cmd, "^(%w+)|?([%w%.%-]*)")
	local player = Players:GetPlayers()[1]
	if not player then
		RS:SetAttribute("H1Said", "no player")
		return
	end
	local ok, said = pcall(function()
		if verb == "home" then
			RideService.sendHome(player)
			return "home"
		elseif verb == "place" then
			-- the player off the toy's right side, `arg` studs from the coil, facing it; the camera at the toy's
			-- front right
			local m = ride(player)
			local base = m:GetAttribute("SpringBase")
			local away = tonumber(arg) or 8
			local at = base.Position + base.RightVector * away + Vector3.new(0, 3.2, 0)
			player.Character:PivotTo(CFrame.lookAt(at, Vector3.new(base.Position.X, at.Y, base.Position.Z)))
			local look = base.Position + Vector3.new(0, 6.5, 0)
			local eye = look + base.LookVector * 9 + base.RightVector * 12 + Vector3.new(0, 2.5, 0)
			workspace:SetAttribute("H1Cam", CFrame.lookAt(eye, look))
			local to = base.Position + base.RightVector * 4.6 + Vector3.new(0, 3.2, 0)
			workspace:SetAttribute("H1From", at)
			workspace:SetAttribute("H1To", to)
			return "placed " .. tostring(base.Position)
		elseif verb == "close" then
			local m = ride(player)
			local base = m:GetAttribute("SpringBase")
			local look = base.Position + Vector3.new(0, 3.2, 0)
			local eye = look + base.LookVector * 7 + base.RightVector * 8.5 + Vector3.new(0, 2.2, 0)
			workspace:SetAttribute("H1Cam", CFrame.lookAt(eye, look))
			return "close"
		elseif verb == "who" then
			return tostring(player:GetAttribute("TrainerRide")) .. " " .. tostring(player:GetAttribute("MaxOxygen")) .. " " .. tostring(player:GetAttribute("State"))
		end
		return "?"
	end)
	RS:SetAttribute("H1Said", tostring(said) .. " " .. tostring(ok) .. " " .. tostring(os.clock()))
end)
'''

CLIENT = r'''
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local player = Players.LocalPlayer
local remote = RS:WaitForChild("Remotes"):WaitForChild("Trainer", 60)
workspace:GetAttributeChangedSignal("H1Off"):Connect(function()
	remote:FireServer("Off")
end)
RunService.RenderStepped:Connect(function()
	local cam = workspace:GetAttribute("H1Cam")
	local camera = workspace.CurrentCamera
	if typeof(cam) == "CFrame" then
		camera.CameraType = Enum.CameraType.Scriptable
		camera.CFrame = cam
	elseif camera.CameraType == Enum.CameraType.Scriptable then
		camera.CameraType = Enum.CameraType.Custom
	end
end)
RunService.Heartbeat:Connect(function()
	local now = workspace:GetAttribute("TrainerClock")
	local t0, t1 = workspace:GetAttribute("H1WalkFrom"), workspace:GetAttribute("H1WalkTo")
	local from, to = workspace:GetAttribute("H1From"), workspace:GetAttribute("H1To")
	if type(now) ~= "number" or type(t0) ~= "number" or typeof(from) ~= "Vector3" or player:GetAttribute("TrainerRide") then
		return
	end
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not root or now < t0 or now > t1 + 0.05 then
		return
	end
	local s = math.clamp((now - t0) / (t1 - t0), 0, 1)
	local at = from:Lerp(to, s)
	local dir = (to - from).Unit
	root.CFrame = CFrame.lookAt(at, at + dir)
	root.AssemblyLinearVelocity = if s < 1 then dir * 9 else Vector3.zero
end)
'''


def run(args, timeout=120):
    r = subprocess.run(["node", RUN, *args], capture_output=True, text=True, timeout=timeout)
    return (r.stdout + r.stderr).strip()


def lua(v):
    if isinstance(v, bool):
        return "true" if v else "false"
    if isinstance(v, (int, float)):
        return repr(v)
    if v is None:
        return "nil"
    return "[==[" + str(v) + "]==]"


def server(code):
    return run(["--ctx", "server", "--code", code])


def install(remove=False):
    job = f"""local sss = game:GetService("ServerScriptService")
local sps = game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts")
for _, at in {{ sss, sps }} do
	local old = at:FindFirstChild("ZZTrainerCapture")
	if old then old:Destroy() end
end
if {lua(remove)} then return "removed" end
local s = Instance.new("Script")
s.Name = "ZZTrainerCapture"
s.Source = {lua(SERVER)}
s.Parent = sss
local c = Instance.new("LocalScript")
c.Name = "ZZTrainerCapture"
c.Source = {lua(CLIENT)}
c.Parent = sps
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


def cmd(c):
    return server(
        f"local RS = game:GetService('ReplicatedStorage') RS:SetAttribute('H1Cmd', {lua(c + '|' + str(time.time()))}) "
        "task.wait(0.3) return RS:GetAttribute('H1Said')"
    )


def shot(path):
    # (the shot is written after studio-run returns: remove the old one first and wait until the new one's size holds)
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
    d.text((10, 8), text, fill="white", font=ImageFont.load_default(size=20), stroke_width=2, stroke_fill="black")
    return im


def save(frames, dest, fps, colours=160):
    pal = [f.quantize(colors=colours, method=Image.MEDIANCUT, dither=Image.NONE) for f in frames]
    durations = [int(1000 / fps)] * len(pal)
    durations[-1] = 900
    pal[0].save(dest, save_all=True, append_images=pal[1:], duration=durations, loop=0, optimize=True)
    SHEETS.mkdir(parents=True, exist_ok=True)
    shutil.copy(dest, SHEETS / dest.name)
    print(dest)


def home():
    print(cmd("home"))
    time.sleep(2)


def still():
    setw(TrainerClock=None, H1WalkFrom=None, H1Off=None)
    home()
    print(cmd("place|14"))
    print(cmd("close"))
    time.sleep(1.5)
    dest = ROOT / "docs/attachments/seahorse-trainer-still.png"
    im = shot(OUT / "still.png")
    im.save(dest)
    SHEETS.mkdir(parents=True, exist_ok=True)
    shutil.copy(dest, SHEETS / dest.name)
    setw(H1Cam=None)
    print(dest)
    return dest


def gif(fps=12):
    home()
    clock = 1000.0
    setw(TrainerClock=clock, H1WalkFrom=None, H1Off=None)
    print(cmd("place|8.5"))
    time.sleep(1.5)
    frames = []
    t = clock

    def frame(tag, text):
        nonlocal t
        setw(TrainerClock=t)
        time.sleep(0.12)
        frames.append(label(shot(OUT / f"{len(frames):03d}.png"), text))
        print(f"\r{tag} {len(frames)}", end="", flush=True)
        t += 1 / fps

    for _ in range(4):
        frame("idle", "walk up to it...")
    setw(H1WalkFrom=t, H1WalkTo=t + 0.45)
    for _ in range(int(0.45 * fps) + 1):
        frame("walk", "walk up to it...")
    # the server seats us in real time (every 0.1 s): wait for it, then play the hop on the clock
    for _ in range(30):
        said = cmd("who")
        if said.startswith("Plot"):
            break
        time.sleep(0.3)
    print("\n", said)
    for _ in range(int(0.5 * fps) + 1):
        frame("hop", "...and you hop on")
    time.sleep(1.0)  # (a real gain or two has come in for the pops to show)
    for _ in range(int(4.0 * fps)):
        frame("rock", "rock with it: +Oxygen every 0.5 s")
    setw(H1Off=time.time())
    for _ in range(30):
        said = cmd("who")
        if not said.startswith("Plot"):
            break
        time.sleep(0.3)
    for _ in range(int(1.1 * fps)):
        frame("off", "jump or walk off: hop off")
    print()
    setw(TrainerClock=None, H1Cam=None, H1WalkFrom=None)
    dest = ROOT / "docs/attachments/seahorse-trainer-1.gif"
    save(frames, dest, fps)
    return dest


if __name__ == "__main__":
    a = sys.argv[1:]
    if a[0] == "install":
        print(install())
    elif a[0] == "remove":
        print(install(True))
    elif a[0] == "still":
        still()
    elif a[0] == "gif":
        gif(int(a[1]) if len(a) > 1 else 12)
