"""The tank's popup (task p1, docs/design/aquarium.md, "The tank's popup"): checked and pictured in a Studio playtest.
    python tools/studio/tank_panel_check.py install | remove   (in Edit, before Play: a server Script and a LocalScript)
    python tools/studio/tank_panel_check.py run                (in a playtest: the checks, then the desktop and phone stills)
How: the server Script sends the player home, fills their tank (AquariumService.give: seven poor fish first, so they are
the ones equipped, then better ones that are stored) and puts two fish in their hands (RideService.giveCarried). The
LocalScript holds the camera behind the player looking at the tank, clicks the tank's middle through UI.TankPanel.click
(the same path a real click takes) and fires the popup's asks (Action "Tank", ...) as its buttons do. Each step reports
back through a RemoteEvent into ReplicatedStorage's "P1Client". Shots go to work/p1/, the stills to docs/attachments/.
Needs Studio open with the studio-runner plugin and Rojo serving this repo.
"""
import json
import subprocess
import sys
import tempfile
import time
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "work/p1"
OUT.mkdir(parents=True, exist_ok=True)
ATTACH = ROOT / "docs/attachments"
RUN = str(Path.home() / "Projects/studio-runner/studio-run.mjs")
# The Studio window on Hugo's PC (2026-11-19) is larger than the screen: the shot (2400 x 1280) holds the game view's
# left part, one shot pixel to a view pixel, the view's top at y 138 (measured with the "probe" step: the panel's
# AbsolutePosition against where it lands in the shot). VIEW is the game view's size in pixels, read by "probe".
OFFSET = (0, 138)
VIEW = [3023, 1226]
SHOT = (2400, 1280)
TOP = 124  # the toolbar's foot

TANK = [  # id, size, variant: the first seven are equipped as they go in (poor ones), the rest stored
    ["BlueChromis", "Normal", ""],
    ["Clownfish", "Tiny", ""],
    ["Pufferfish", "Normal", ""],
    ["Boxfish", "Normal", ""],
    ["Butterflyfish", "Normal", ""],
    ["Stingray", "Big", ""],
    ["Parrotfish", "Normal", ""],
    ["Archelon", "Huge", "Rainbow"],
    ["ReefShark", "Colossal", ""],
    ["YellowTang", "Big", "Gold"],
    ["Seahorse", "Normal", "Silver"],
    ["PearlSerpent", "Normal", ""],
    ["Dunkleosteus", "Giant", ""],
    ["SeaTurtle", "Giant", ""],
]
HANDS = [["Octopus", "Big", ""], ["GreatWhite", "Normal", "Gold"]]

SERVER = r'''
local RS = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Services = game:GetService("ServerScriptService"):WaitForChild("Server"):WaitForChild("Services")
local RideService = require(Services:WaitForChild("RideService"))
local AquariumService = require(Services:WaitForChild("AquariumService"))
local report = Instance.new("RemoteEvent")
report.Name = "ZZP1Report"
report.Parent = RS
report.OnServerEvent:Connect(function(_, text)
	RS:SetAttribute("P1Client", tostring(text))
end)
local function plotOf(player)
	return workspace.ClaudeBlockout.Dock.Plots:FindFirstChild(player:GetAttribute("Plot"))
end
local function stand(player, away)
	local plot = plotOf(player)
	local water, pad = plot.TankWater, plot.CollectPad
	local out = Vector3.new(pad.Position.X - water.Position.X, 0, pad.Position.Z - water.Position.Z).Unit
	local at = pad.Position + out * away + Vector3.new(0, 3.5, 0)
	local cf = CFrame.lookAt(at, Vector3.new(water.Position.X, at.Y, water.Position.Z))
	player.Character:PivotTo(cf)
	-- (the client owns its character: it moves it too, or the server's move can be undone)
	workspace:SetAttribute("P1Stand", cf)
	local eye = at + out * 34 + Vector3.new(0, 20, 0)
	workspace:SetAttribute("P1Cam", CFrame.lookAt(eye, water.Position + Vector3.new(0, 2, 0)))
	workspace:SetAttribute("P1Water", water.Position)
end
RS:GetAttributeChangedSignal("P1Cmd"):Connect(function()
	local cmd = tostring(RS:GetAttribute("P1Cmd") or "")
	local verb, arg = string.match(cmd, "^(%w+)|?([^|]*)")
	local player = Players:GetPlayers()[1]
	local ok, said = pcall(function()
		if verb == "setup" then
			RideService.sendHome(player)
			task.wait(0.5)
			local spec = game:GetService("HttpService"):JSONDecode(arg)
			AquariumService.give(player, 1000, spec.tank)
			for _, f in spec.hands do
				RideService.giveCarried(player, { Id = f[1], Size = f[2], Variant = f[3] })
			end
			stand(player, 0)
			return "set"
		elseif verb == "stand" then
			stand(player, tonumber(arg) or 0)
			return "stood " .. arg
		elseif verb == "state" then
			return game:GetService("HttpService"):JSONEncode({
				list = player:GetAttribute("TankList"),
				hands = player:GetAttribute("Hands"),
				income = player:GetAttribute("Income"),
				state = RideService.stateOf(player),
			})
		end
		return "?"
	end)
	RS:SetAttribute("P1Said", tostring(said) .. " " .. tostring(ok))
end)
'''

CLIENT = r'''
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local player = Players.LocalPlayer
local Client = player:WaitForChild("PlayerScripts"):WaitForChild("Client")
local TankPanel = require(Client:WaitForChild("UI"):WaitForChild("TankPanel"))
local Net = require(RS:WaitForChild("Shared"):WaitForChild("Net"))
local report = RS:WaitForChild("ZZP1Report", 60)
local denied = ""
Net.Ride.OnClientEvent:Connect(function(kind, reason)
	if kind == "TankDenied" then
		denied = tostring(reason)
	end
end)
workspace:GetAttributeChangedSignal("P1Do"):Connect(function()
	local cmd = tostring(workspace:GetAttribute("P1Do") or "")
	local verb, a, b = string.match(cmd, "^(%w+)|?([^|]*)|?([^|]*)")
	local said = ""
	if verb == "click" then
		local water = workspace:GetAttribute("P1Water")
		local p = workspace.CurrentCamera:WorldToScreenPoint(water)
		local hit = TankPanel.click(p.X, p.Y)
		task.wait(0.2)
		said = "hit=" .. tostring(hit) .. " open=" .. tostring(TankPanel.isOpen())
	elseif verb == "fire" then
		denied = ""
		Net.Action:FireServer("Tank", a, b)
		task.wait(0.5)
		said = "denied=" .. denied .. " open=" .. tostring(TankPanel.isOpen())
	elseif verb == "putin" then
		denied = ""
		Net.Action:FireServer("Tank", "PutIn", tonumber(a), b)
		task.wait(0.5)
		said = "denied=" .. denied
	elseif verb == "scroll" then
		local list = player.PlayerGui.TankPanel:FindFirstChild("List", true)
		list.CanvasPosition = Vector2.new(0, tonumber(a) or 0)
		said = "scrolled " .. a
	elseif verb == "probe" then
		local g = player.PlayerGui.TankPanel
		local root = g:FindFirstChild("Root")
		local panel = root and root:FindFirstChild("Panel")
		said = string.format("view=%s root=%s/%s scale=%s panel=%s/%s inset=%s", tostring(workspace.CurrentCamera.ViewportSize),
			tostring(root.AbsolutePosition), tostring(root.AbsoluteSize), tostring(root:FindFirstChildOfClass("UIScale").Scale),
			tostring(panel.AbsolutePosition), tostring(panel.AbsoluteSize), tostring(game:GetService("GuiService"):GetGuiInset()))
	elseif verb == "open" then
		said = "open=" .. tostring(TankPanel.isOpen()) .. " mode=" .. tostring(require(Client.Lib.State).Mode)
	end
	report:FireServer(said .. " @" .. cmd)
end)
workspace:GetAttributeChangedSignal("P1Stand"):Connect(function()
	local cf = workspace:GetAttribute("P1Stand")
	if typeof(cf) == "CFrame" and player.Character then
		player.Character:PivotTo(cf)
	end
end)
RunService.RenderStepped:Connect(function()
	local cam = workspace:GetAttribute("P1Cam")
	local camera = workspace.CurrentCamera
	if typeof(cam) == "CFrame" then
		camera.CameraType = Enum.CameraType.Scriptable
		camera.CFrame = cam
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
	local old = at:FindFirstChild("ZZP1Check")
	if old then old:Destroy() end
end
workspace:SetAttribute("PanelPhone", nil)
workspace:SetAttribute("HudTouch", nil)
workspace:SetAttribute("P1Cam", nil)
workspace:SetAttribute("P1Stand", nil)
if {lua(remove)} then
	game:GetService("UserInputService").MouseBehavior = Enum.MouseBehavior.Default
	return "removed"
end
local s = Instance.new("Script")
s.Name = "ZZP1Check"
s.Source = {lua(SERVER)}
s.Parent = sss
local c = Instance.new("LocalScript")
c.Name = "ZZP1Check"
c.Source = {lua(CLIENT)}
c.Parent = sps
return "installed"
"""
    with tempfile.NamedTemporaryFile("w", suffix=".luau", delete=False) as f:
        f.write(job)
    return run([f.name])


def cmd(c, wait=0.8):
    return server(
        f"local RS = game:GetService('ReplicatedStorage') RS:SetAttribute('P1Cmd', {lua(c + '|' + str(time.time()))}) "
        f"task.wait({wait}) return RS:GetAttribute('P1Said')"
    )


def do(c, wait=1.2):
    return server(
        f"local RS = game:GetService('ReplicatedStorage') RS:SetAttribute('P1Client', '') "
        f"workspace:SetAttribute('P1Do', {lua(c + '|' + str(time.time()))}) "
        f"task.wait({wait}) return RS:GetAttribute('P1Client')"
    )


def setw(**kw):
    code = ""
    for k, v in kw.items():
        val = "nil" if v is None else (f"Vector2.new({v[0]}, {v[1]})" if isinstance(v, tuple) else lua(v))
        code += f"workspace:SetAttribute({lua(k)}, {val}) "
    return server(code + "return 'ok'")


def state():
    out = cmd("state")
    text = out[out.find("{") : out.rfind("}") + 1]
    s = json.loads(text)
    s["list"] = json.loads(s["list"] or "[]")
    s["hands"] = json.loads(s["hands"] or "[]")
    return s


def shot(path, box=None):
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
    # the view's middle in the shot
    cx, cy = OFFSET[0] + VIEW[0] // 2, OFFSET[1] + VIEW[1] // 2
    if box:
        bw, bh = box
        return im.crop((cx - bw // 2, cy - bh // 2, cx + bw // 2, cy + bh // 2))
    # as wide either side of the middle as the shot allows, the whole visible height
    half = min(cx, SHOT[0] - cx)
    return im.crop((cx - half, TOP, cx + half, SHOT[1]))


def equipped(s):
    return [r for r in s["list"] if r[4] == 1]


def check():
    log = []

    def note(text):
        print(text)
        log.append(text)

    import re

    spec = json.dumps({"tank": TANK, "hands": HANDS})
    note("setup: " + cmd("setup|" + spec, 2.5))
    s = state()
    note(f"state {s['state']}; {len(s['list'])} in tank, {len(equipped(s))} equipped, {len(s['hands'])} in hands, income {s['income']}")
    note("click from the pad: " + do("click"))
    probe = do("probe")
    m = re.search(r"view=(\d+), (\d+)", probe)
    if m:
        VIEW[0], VIEW[1] = int(m.group(1)), int(m.group(2))
    note("probe: " + probe)
    time.sleep(1)
    shot(OUT / "raw_before_best.png").save(OUT / "desktop_before_best.png")
    before = s["income"]
    note("EQUIP BEST: " + do("fire|Best"))
    s = state()
    names = [r[1] for r in equipped(s)]
    note(f"  equipped now {names}; income {before} -> {s['income']}")
    # unequip the best, then equip a stored one, then a second (the tank is full: refused)
    best = equipped(s)[0]
    note(f"UNEQUIP {best[1]}: " + do(f"fire|Unequip|{best[0]}"))
    s = state()
    note(f"  {len(equipped(s))} equipped, income {s['income']}")
    stored = [r for r in s["list"] if r[4] == 0]
    note(f"EQUIP {stored[0][1]}: " + do(f"fire|Equip|{stored[0][0]}"))
    s = state()
    stored = [r for r in s["list"] if r[4] == 0]
    note(f"EQUIP {stored[0][1]} with a full tank: " + do(f"fire|Equip|{stored[0][0]}"))
    note(f"PUT IN hand 1 ({s['hands'][0][0]}): " + do(f"putin|1|{s['hands'][0][0]}"))
    s = state()
    note(f"  {len(s['list'])} in tank, {len(s['hands'])} in hands")
    note("EQUIP BEST again: " + do("fire|Best"))
    time.sleep(0.8)
    shot(OUT / "raw_desktop.png").save(ATTACH / "tank-popup-desktop.png")
    # the best one out: EQUIP BEST lights up; scrolled down to the earning and stored fish
    s = state()
    note(f"UNEQUIP {equipped(s)[0][1]} (for the second still): " + do(f"fire|Unequip|{equipped(s)[0][0]}"))
    do("scroll|330")
    time.sleep(0.8)
    shot(OUT / "raw_desktop2.png").save(ATTACH / "tank-popup-desktop-2.png")
    # phone: a 2x phone's screen (844 x 390 points) in the middle of the window
    setw(HudTouch=True, PanelPhone=(1688, 780))
    do("click")  # (shut)
    do("click")  # (open again, laid out for the phone)
    time.sleep(1)
    shot(OUT / "raw_phone.png").save(OUT / "phone_full.png")
    shot(OUT / "raw_phone.png", box=(1688, 780)).save(ATTACH / "tank-popup-phone.png")
    setw(HudTouch=None, PanelPhone=None)
    # too far: the popup shuts, a click opens nothing, an ask is refused
    note("walk 70 studs off: " + cmd("stand|70", 1.0))
    note("  " + do("open"))
    note("click from 70 studs: " + do("click"))
    note("EQUIP BEST from 70 studs: " + do("fire|Best"))
    (OUT / "check.log").write_text("\n".join(log) + "\n")


if __name__ == "__main__":
    what = sys.argv[1] if len(sys.argv) > 1 else "run"
    if what == "install":
        print(install())
    elif what == "remove":
        print(install(remove=True))
    else:
        check()
