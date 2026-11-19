"""Holding a fish over the head (task f1, docs/design/holding.md): checked and pictured in a Studio playtest.
    python tools/studio/hold_check.py install | remove   (in Edit, before Play: a server Script and a LocalScript)
    python tools/studio/hold_check.py run                (in a playtest: the checks, then the stills)
How: the server Script puts two fish in the player's hands (RideService.giveCarried: a Tiny Clownfish and a Colossal
Reef Shark) and stands them in the open on the dock. The LocalScript fires the same asks a slot's click does
(Action "Hold", index, id; AquariumController) and holds the camera on the player, front or side. Each step reports
back into ReplicatedStorage's "HoldClient". Raw shots go to work/hold/, the stills to docs/attachments/hold-*.png.
Needs Studio open with the studio-runner plugin and Rojo serving this repo.
"""
import subprocess
import sys
import tempfile
import time
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "work/hold"
OUT.mkdir(parents=True, exist_ok=True)
ATTACH = ROOT / "docs/attachments"
RUN = str(Path.home() / "Projects/studio-runner/studio-run.mjs")
# the game view in the shot (2026-11-20, Studio window 2400 x 1280 with the Explorer docked right)
OFFSET = (0, 125)
VIEW = [1985, 1085]
SHOT = (2400, 1280)

HANDS = [["Clownfish", "Tiny", ""], ["ReefShark", "Colossal", "Gold"], ["Pufferfish", "Normal", ""]]

SERVER = r'''
local RS = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Services = game:GetService("ServerScriptService"):WaitForChild("Server"):WaitForChild("Services")
local RideService = require(Services:WaitForChild("RideService"))
local report = Instance.new("RemoteEvent")
report.Name = "ZZHoldReport"
report.Parent = RS
report.OnServerEvent:Connect(function(_, text)
	RS:SetAttribute("HoldClient", tostring(text))
end)
RS:GetAttributeChangedSignal("HoldCmd"):Connect(function()
	local cmd = tostring(RS:GetAttribute("HoldCmd") or "")
	local verb, arg = string.match(cmd, "^(%w+)|?([^|]*)")
	local player = Players:GetPlayers()[1]
	local ok, said = pcall(function()
		if verb == "setup" then
			local spec = game:GetService("HttpService"):JSONDecode(arg)
			for _, f in spec do
				RideService.giveCarried(player, { Id = f[1], Size = f[2], Variant = f[3] })
			end
			local spawn = workspace.ClaudeBlockout.Dock.DockSpawn
			local at = spawn.Position + Vector3.new(0, 4, 0)
			workspace:SetAttribute("HoldStand", CFrame.new(at) * CFrame.Angles(0, math.rad(tonumber(workspace:GetAttribute("HoldYaw")) or 0), 0))
			return "set " .. #RideService.carried(player)
		elseif verb == "state" then
			local folder = workspace:FindFirstChild("HeldFish")
			local model = folder and folder:FindFirstChildWhichIsA("Model")
			local size = model and model:GetExtentsSize()
			return string.format("state=%s held=%s idx=%s size=%s hands=%d model=%s",
				tostring(RideService.stateOf(player)), tostring(player:GetAttribute("HeldFish")),
				tostring(player:GetAttribute("HeldIndex")), tostring(player:GetAttribute("HeldSize")),
				#RideService.carried(player), if size then string.format("%.1fx%.1fx%.1f", size.X, size.Y, size.Z) else "none")
		elseif verb == "take" then
			RideService.takeCarried(player, tonumber(arg) or 1)
			return "took " .. arg
		elseif verb == "respawn" then
			player:LoadCharacter()
			return "respawned"
		end
		return "?"
	end)
	RS:SetAttribute("HoldSaid", tostring(said) .. " " .. tostring(ok))
end)
'''

CLIENT = r'''
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local player = Players.LocalPlayer
local Net = require(RS:WaitForChild("Shared"):WaitForChild("Net"))
local report = RS:WaitForChild("ZZHoldReport", 60)
local denied = ""
Net.Ride.OnClientEvent:Connect(function(kind, a, b)
	if kind == "Denied" and a == "Hold" then
		denied = tostring(b)
	end
end)
workspace:GetAttributeChangedSignal("HoldDo"):Connect(function()
	local cmd = tostring(workspace:GetAttribute("HoldDo") or "")
	local verb, a, b = string.match(cmd, "^(%w+)|?([^|]*)|?([^|]*)")
	local said = ""
	if verb == "hold" then
		denied = ""
		Net.Action:FireServer("Hold", tonumber(a), b)
		task.wait(0.6)
		said = "denied=" .. denied .. " held=" .. tostring(player:GetAttribute("HeldFish"))
	end
	report:FireServer(said .. " @" .. cmd)
end)
local function stand()
	local cf = workspace:GetAttribute("HoldStand")
	if typeof(cf) == "CFrame" and player.Character then
		player.Character:PivotTo(cf)
	end
end
workspace:GetAttributeChangedSignal("HoldStand"):Connect(stand)
RunService.RenderStepped:Connect(function()
	local view = workspace:GetAttribute("HoldView")
	local camera = workspace.CurrentCamera
	local character = player.Character
	local head = character and character:FindFirstChild("Head")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if type(view) == "string" and view ~= "" and head and root then
		camera.CameraType = Enum.CameraType.Scriptable
		local look = root.CFrame
		local dir = if view == "side" then look.RightVector else look.LookVector
		local dist = tonumber(workspace:GetAttribute("HoldDist")) or 16
		local aim = head.Position + Vector3.new(0, 1, 0)
		camera.CFrame = CFrame.lookAt(aim + dir * dist + Vector3.new(0, 2.5, 0), aim)
	elseif camera.CameraType == Enum.CameraType.Scriptable then
		camera.CameraType = Enum.CameraType.Custom
	end
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
	local old = at:FindFirstChild("ZZHoldCheck")
	if old then old:Destroy() end
end
for _, k in {{ "HoldView", "HoldStand", "HoldDo", "HoldDist", "HoldYaw" }} do
	workspace:SetAttribute(k, nil)
end
if {lua(remove)} then
	game:GetService("UserInputService").MouseBehavior = Enum.MouseBehavior.Default
	return "removed"
end
local s = Instance.new("Script")
s.Name = "ZZHoldCheck"
s.Source = {lua(SERVER)}
s.Parent = sss
local c = Instance.new("LocalScript")
c.Name = "ZZHoldCheck"
c.Source = {lua(CLIENT)}
c.Parent = sps
return "installed"
"""
    with tempfile.NamedTemporaryFile("w", suffix=".luau", delete=False) as f:
        f.write(job)
    return run([f.name])


def cmd(c, wait=0.8):
    return server(
        f"local RS = game:GetService('ReplicatedStorage') RS:SetAttribute('HoldCmd', {lua(c + '|' + str(time.time()))}) "
        f"task.wait({wait}) return RS:GetAttribute('HoldSaid')"
    )


def do(c, wait=1.2):
    return server(
        f"local RS = game:GetService('ReplicatedStorage') RS:SetAttribute('HoldClient', '') "
        f"workspace:SetAttribute('HoldDo', {lua(c + '|' + str(time.time()))}) "
        f"task.wait({wait}) return RS:GetAttribute('HoldClient')"
    )


def setw(**kw):
    code = ""
    for k, v in kw.items():
        code += f"workspace:SetAttribute({lua(k)}, {lua(v)}) "
    return server(code + "return 'ok'")


def shot(path, box=(1100, 1000)):
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
    cx, cy = OFFSET[0] + VIEW[0] // 2, OFFSET[1] + VIEW[1] // 2
    cx = min(cx, SHOT[0] - box[0] // 2)
    bw, bh = box
    crop = im.crop((cx - bw // 2, max(cy - bh // 2, 0), cx + bw // 2, min(cy + bh // 2, SHOT[1])))
    im.close()
    return crop


def pair(name):
    for view in ("front", "side"):
        setw(HoldView=view)
        time.sleep(0.9)
        img = shot(OUT / f"raw_{name}_{view}.png")
        img.save(ATTACH / f"hold-{name}-{view}.png")
        img.close()


def check():
    import json

    log = []

    def note(text):
        print(text)
        log.append(text)

    note("setup: " + cmd("setup|" + json.dumps(HANDS), 1.5))
    note("  " + cmd("state"))
    setw(HoldView="front")
    time.sleep(1)
    img = shot(OUT / "raw_empty.png")
    img.save(ATTACH / "hold-empty-front.png")
    img.close()
    note("HOLD 1 (Clownfish Tiny): " + do("hold|1|Clownfish"))
    note("  " + cmd("state"))
    pair("small")
    note("HOLD 2 (Reef Shark Colossal, gold): " + do("hold|2|ReefShark"))
    note("  " + cmd("state"))
    pair("big")
    note("HOLD 2 with the wrong id: " + do("hold|2|Clownfish"))
    note("HOLD 0 (put away): " + do("hold|0|"))
    note("  " + cmd("state"))
    note("HOLD 3 (Pufferfish): " + do("hold|3|Pufferfish"))
    note("  " + cmd("state"))
    note("take hand 1 (Clownfish) out: held stays, its place moves: " + cmd("take|1"))
    note("  " + cmd("state"))
    note("take hand 2 (the held Pufferfish) out: " + cmd("take|2"))
    time.sleep(0.4)
    note("  " + cmd("state"))
    note("HOLD 1 (Reef Shark) then respawn: " + do("hold|1|ReefShark"))
    note("  " + cmd("respawn", 3))
    note("  " + cmd("state"))
    setw(HoldView="")
    (OUT / "check.log").write_text("\n".join(log) + "\n")


if __name__ == "__main__":
    what = sys.argv[1] if len(sys.argv) > 1 else "run"
    if what == "install":
        print(install())
    elif what == "remove":
        print(install(remove=True))
    else:
        check()
