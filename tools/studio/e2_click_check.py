"""Clicks, not E (task e2, docs/plans/2026-11-20-oxygen-equip-landride.md, E2): checked and pictured in a Studio playtest.
    python tools/studio/e2_click_check.py install | remove   (in Edit, before Play: a server Script and a LocalScript)
    python tools/studio/e2_click_check.py run                (in a playtest: the checks, then the stills)
How: the server Script sends the player home, puts fish in their hands (RideService.giveCarried) and counts every
Trainer "Up" and Action "Place" it hears. The LocalScript presses the seahorse sign's cash block and the tank's control
through UI.UpgradeSign.press and UI.TankPrompt.press: the same functions their buttons' Activated runs (a script can't
make a real mouse click on Hugo's PC without taking the window). It also looks for any ProximityPrompt left on the
plots, reads where the sign's cash and Robux blocks are, and holds the camera for the stills. Reports go back through
a RemoteEvent into ReplicatedStorage's "E2Client". Shots go to work/e2/, the stills to docs/attachments/.
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
OUT = ROOT / "work/e2"
OUT.mkdir(parents=True, exist_ok=True)
ATTACH = ROOT / "docs/attachments"
RUN = str(Path.home() / "Projects/studio-runner/studio-run.mjs")
OFFSET = (0, 138)  # (as tank_panel_check.py: the game view's top in the shot)
VIEW = [3023, 1226]
SHOT = (2400, 1280)
TOP = 124

HANDS = [["Clownfish", "Big", ""], ["ReefShark", "Normal", "Gold"], ["YellowTang", "Normal", ""]]

SERVER = r'''
local RS = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local Services = game:GetService("ServerScriptService"):WaitForChild("Server"):WaitForChild("Services")
local RideService = require(Services:WaitForChild("RideService"))
local AquariumService = require(Services:WaitForChild("AquariumService"))
local Config = require(RS:WaitForChild("Shared"):WaitForChild("Config"))
local Net = require(RS:WaitForChild("Shared"):WaitForChild("Net"))
local report = Instance.new("RemoteEvent")
report.Name = "ZZE2Report"
report.Parent = RS
report.OnServerEvent:Connect(function(_, text)
	RS:SetAttribute("E2Client", tostring(text))
end)
local ups, places, answers = 0, 0, {}
task.spawn(function()
	local trainer = RS:WaitForChild("Remotes"):WaitForChild("Trainer", 60)
	trainer.OnServerEvent:Connect(function(_, what)
		if what == "Up" then
			ups += 1
		end
	end)
end)
Net.Action.OnServerEvent:Connect(function(_, action)
	if action == "Place" then
		places += 1
	end
end)
local function plotOf(player)
	return workspace.ClaudeBlockout.Dock.Plots:FindFirstChild(player:GetAttribute("Plot"))
end
local function put(player, cf)
	player.Character:PivotTo(cf)
	workspace:SetAttribute("E2Stand", cf) -- (the client owns its character: it moves it too)
end
-- in front of the tank's glass, `away` studs out from the control
local function standTank(player, away)
	local plot = plotOf(player)
	local water, pad = plot.TankWater, plot:FindFirstChild("Pad") or plot:FindFirstChild("CollectPad")
	local out = Vector3.new(pad.Position.X - water.Position.X, 0, pad.Position.Z - water.Position.Z).Unit
	local half = math.max(water.Size.X, water.Size.Z) / 2
	local front = water.Position + out * half
	local at = Vector3.new(front.X, pad.Position.Y + 3.5, front.Z) + out * (6 + away)
	put(player, CFrame.lookAt(at, Vector3.new(water.Position.X, at.Y, water.Position.Z)))
	local eye = at + out * 16 + Vector3.new(0, 7, 0)
	workspace:SetAttribute("E2Cam", CFrame.lookAt(eye, Vector3.new(front.X, at.Y + 1, front.Z)))
end
-- in front of the upgrade sign, `away` studs further back from it than the seahorse
local function standSign(player, away, plotName)
	local plot = workspace.ClaudeBlockout.Dock.Plots:FindFirstChild(plotName or "") or plotOf(player)
	local board, spot = plot.UpgradeBoard, plot.TrainerSpot
	local face = board.CFrame.LookVector * Vector3.new(1, 0, 1)
	local at = Vector3.new(board.Position.X, spot.Position.Y + 3.5, board.Position.Z) + face.Unit * (6 + away)
	put(player, CFrame.lookAt(at, Vector3.new(board.Position.X, at.Y, board.Position.Z)))
	local eye = board.Position + face.Unit * 15 + Vector3.new(0, 0.5, 0)
	workspace:SetAttribute("E2Cam", CFrame.lookAt(eye, board.Position))
end
RS:GetAttributeChangedSignal("E2Cmd"):Connect(function()
	local cmd = tostring(RS:GetAttribute("E2Cmd") or "")
	local verb, a, b = string.match(cmd, "^(%w+)|?([^|]*)|?([^|]*)")
	local player = Players:GetPlayers()[1]
	local ok, said = pcall(function()
		if verb == "setup" then
			RideService.sendHome(player)
			task.wait(0.5)
			local hands = HttpService:JSONDecode(a)
			for _, f in hands do
				RideService.giveCarried(player, { Id = f[1], Size = f[2], Variant = f[3] })
			end
			game:GetService("ServerStorage").TrainerTest:Invoke("level", player.UserId, 1)
			return "set"
		elseif verb == "tank" then
			standTank(player, tonumber(a) or 0)
			return "at tank " .. a
		elseif verb == "sign" then
			standSign(player, tonumber(a) or 0, b)
			return "at sign " .. a .. " " .. b
		elseif verb == "free" then
			Config.Train.Free = tonumber(a)
			return "Free=" .. a
		elseif verb == "coins" then
			local have = AquariumService.coinsOf(player)
			AquariumService.give(player, (tonumber(a) or 0) - have)
			return "coins " .. AquariumService.coinsOf(player)
		elseif verb == "level" then
			game:GetService("ServerStorage").TrainerTest:Invoke("level", player.UserId, tonumber(a))
			return "level " .. a
		elseif verb == "still" then
			-- for the pictures: the player beside (not in front of) the thing, the camera square on to it
			local plot = plotOf(player)
			if a == "sign" then
				local board = plot.UpgradeBoard
				local face = (board.CFrame.LookVector * Vector3.new(1, 0, 1)).Unit
				local side = board.CFrame.RightVector
				local at = Vector3.new(board.Position.X, plot.TrainerSpot.Position.Y + 3.5, board.Position.Z) + face * 5 - side * 8
				put(player, CFrame.lookAt(at, Vector3.new(board.Position.X, at.Y, board.Position.Z)))
				local eye = board.Position + face * 12.5 - side * 2 + Vector3.new(0, 0.6, 0)
				workspace:SetAttribute("E2Cam", CFrame.lookAt(eye, board.Position + Vector3.new(0, -1.2, 0)))
			else
				standTank(player, 0)
				local water, pad = plot.TankWater, plot:FindFirstChild("Pad") or plot:FindFirstChild("CollectPad")
				local out = Vector3.new(pad.Position.X - water.Position.X, 0, pad.Position.Z - water.Position.Z).Unit
				local side = out:Cross(Vector3.yAxis)
				-- (the control's attachment is the client's: the front glass worked out the same way, a little over the sand)
				local half = math.max(water.Size.X, water.Size.Z) / 2
				local front = water.Position + out * half
				front = Vector3.new(front.X, water.Position.Y - water.Size.Y / 2 + 4, front.Z)
				local eye = front + out * 20 + side * 9 + Vector3.new(0, 6, 0)
				workspace:SetAttribute("E2Cam", CFrame.lookAt(eye, front + Vector3.new(0, 3, 0)))
			end
			return "still " .. a
		elseif verb == "kill" then
			player.Character.Humanoid.Health = 0
			return "killed"
		elseif verb == "home" then
			RideService.sendHome(player)
			return "home"
		elseif verb == "state" then
			local plots = {}
			for _, p in workspace.ClaudeBlockout.Dock.Plots:GetChildren() do
				table.insert(plots, p.Name)
			end
			table.sort(plots)
			return HttpService:JSONEncode({
				level = player:GetAttribute("TrainerLevel"),
				coins = AquariumService.coinsOf(player),
				hands = #RideService.carried(player),
				handIds = (function()
					local t = {}
					for _, c in RideService.carried(player) do
						table.insert(t, c.Id)
					end
					return t
				end)(),
				list = player:GetAttribute("TankList"),
				ups = ups,
				places = places,
				state = RideService.stateOf(player),
				plot = player:GetAttribute("Plot"),
				plots = plots,
				free = Config.Train.Free,
			})
		end
		return "?"
	end)
	RS:SetAttribute("E2Said", tostring(said) .. " " .. tostring(ok))
end)
'''

CLIENT = r'''
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local player = Players.LocalPlayer
local Client = player:WaitForChild("PlayerScripts"):WaitForChild("Client")
local UpgradeSign = require(Client:WaitForChild("UI"):WaitForChild("UpgradeSign"))
local TankPrompt = require(Client.UI:WaitForChild("TankPrompt"))
local TankPanel = require(Client.UI:WaitForChild("TankPanel"))
local Config = require(RS:WaitForChild("Shared"):WaitForChild("Config"))
local Net = require(RS.Shared:WaitForChild("Net"))
local report = RS:WaitForChild("ZZE2Report", 60)
local said = {}
RS:WaitForChild("Remotes"):WaitForChild("Trainer", 60).OnClientEvent:Connect(function(what, a)
	if what == "Up" or what == "UpNo" then
		table.insert(said, what .. ":" .. tostring(a))
	end
end)
Net.Ride.OnClientEvent:Connect(function(what, a, b)
	if what == "Denied" or what == "Deposited" then
		table.insert(said, what .. ":" .. tostring(a) .. ":" .. tostring(b))
	end
end)
local function ownSign()
	return player.PlayerGui:FindFirstChild("UpgradeSign_" .. tostring(player:GetAttribute("Plot")))
end
local function cashText(gui)
	gui = gui or ownSign()
	local cash = gui and gui:FindFirstChild("Cash", true)
	local label = cash and cash:FindFirstChild("Label", true)
	return label and label.Text or "?"
end
local function handle(cmd)
	local verb, a, b = string.match(cmd, "^(%w+)|?([^|]*)|?([^|]*)")
	local out = ""
	if verb == "prompts" then
		-- every ProximityPrompt on the dock and on us: none should be left (no E anywhere at the tank or the ride)
		local found = {}
		for _, d in workspace:GetDescendants() do
			-- (the sub stand's E is another station's, outside this task: Dock.Stations)
			if d:IsA("ProximityPrompt") and not d:IsDescendantOf(workspace.ClaudeBlockout.Dock.Stations) then
				table.insert(found, d:GetFullName() .. "(" .. d.KeyboardKeyCode.Name .. ")")
			end
		end
		local guis = {}
		for _, g in player.PlayerGui:GetChildren() do
			if g:IsA("BillboardGui") or g:IsA("SurfaceGui") then
				local words = {}
				for _, t in g:GetDescendants() do
					if t:IsA("TextLabel") and (t.Text == "E" or t.Text == "Upgrade" or t.Text == "Put in tank") then
						table.insert(words, t:GetFullName())
					end
				end
				if #words > 0 then
					table.insert(guis, table.concat(words, ","))
				end
			end
		end
		out = "prompts=" .. #found .. " [" .. table.concat(found, "; ") .. "] staleE=" .. #guis
	elseif verb == "sign" then
		-- press our own sign's cash block `a` times, `b` seconds apart, then wait for the answer
		local n, gap = tonumber(a) or 1, tonumber(b) or 0
		local seen = {}
		for i = 1, n do
			UpgradeSign.press()
			table.insert(seen, cashText())
			if gap > 0 then
				task.wait(gap)
			end
		end
		task.wait(0.15)
		local mid = cashText()
		task.wait(1.2)
		local plot = workspace.ClaudeBlockout.Dock.Plots:FindFirstChild(tostring(player:GetAttribute("Plot")))
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		local gap = if plot and root then ((plot.UpgradeBoard.Position - root.Position) * Vector3.new(1, 0, 1)).Magnitude else -1
		out = "texts=" .. table.concat(seen, ",") .. " mid=" .. mid .. " after=" .. cashText() .. string.format(" gap=%.1f", gap)
	elseif verb == "other" then
		local hit = UpgradeSign.press(a)
		task.wait(1)
		out = "pressed=" .. tostring(hit) .. " text=" .. cashText(player.PlayerGui:FindFirstChild("UpgradeSign_" .. a))
	elseif verb == "rawup" then
		-- the remote itself, `a` times at once (past the sign's own one-at-a-time)
		for i = 1, math.clamp(tonumber(a) or 1, 1, 5) do
			RS.Remotes.Trainer:FireServer("Up")
		end
		task.wait(0.8)
	elseif verb == "geom" then
		local gui = ownSign()
		local cash, robux = gui:FindFirstChild("Cash", true), gui:FindFirstChild("Robux", true)
		local press = cash:FindFirstChild("Press")
		local buttons = {}
		for _, d in robux:GetDescendants() do
			if d:IsA("GuiButton") then
				table.insert(buttons, d.Name)
			end
		end
		local c0, c1 = press.AbsolutePosition, press.AbsolutePosition + press.AbsoluteSize
		local r0, r1 = robux.AbsolutePosition, robux.AbsolutePosition + robux.AbsoluteSize
		local overlap = c0.X < r1.X and r0.X < c1.X and c0.Y < r1.Y and r0.Y < c1.Y
		out = string.format(
			"surfaceActive=%s press=%s..%s active=%s robux=%s..%s visible=%s robuxButtons=%d overlap=%s",
			tostring(gui.Active), tostring(c0), tostring(c1), tostring(press.Active), tostring(r0), tostring(r1),
			tostring(robux.Visible), #buttons, tostring(overlap))
		-- other signs' presses are dead
		local live = 0
		for _, g in player.PlayerGui:GetChildren() do
			if g:IsA("SurfaceGui") and string.match(g.Name, "^UpgradeSign_") and g ~= gui then
				local p = g:FindFirstChild("Press", true)
				if p and p.Active then
					live += 1
				end
			end
		end
		out ..= " otherLive=" .. live
	elseif verb == "tank" then
		local c = TankPrompt.control()
		local shown = c and c.Gui.Enabled
		local function words()
			local g = c and c.Gui
			local act = g and g:FindFirstChild("Action", true)
			local obj = g and g:FindFirstChild("Object", true)
			local key = g and g:FindFirstChild("Key", true)
			local cap = key and key:FindFirstChild("Label", true)
			return (cap and cap.Text or "?") .. "/" .. (act and act.Text or "?") .. "/" .. (obj and obj.Visible and obj.Text or "")
		end
		local before = words()
		local n = tonumber(a) or 1
		local did = {}
		for i = 1, n do
			table.insert(did, tostring(TankPrompt.press()))
			if (tonumber(b) or 0) > 0 then
				task.wait(tonumber(b))
			end
		end
		task.wait(0.15)
		local mid = words()
		task.wait(0.9)
		out = "shown=" .. tostring(shown) .. " before=" .. before .. " pressed=" .. table.concat(did, ",") .. " mid=" .. mid .. " open=" .. tostring(TankPanel.isOpen())
	elseif verb == "shown" then
		local c = TankPrompt.control()
		out = "shown=" .. tostring(c and c.Gui.Enabled)
	elseif verb == "hold" then
		-- what a slot click does on the dock (AquariumController's Slots.Picked): hold, never put in
		Net.Action:FireServer("Hold", tonumber(a), b)
		task.wait(0.6)
		out = "held=" .. tostring(player:GetAttribute("HeldFish"))
	elseif verb == "free" then
		Config.Train.Free = tonumber(a)
		UpgradeSign.refresh()
		out = "client Free=" .. a .. " text=" .. cashText()
	elseif verb == "refresh" then
		UpgradeSign.refresh()
	end
	return out
end
workspace:GetAttributeChangedSignal("E2Do"):Connect(function()
	local cmd = tostring(workspace:GetAttribute("E2Do") or "")
	said = {}
	local ok, out = pcall(handle, cmd)
	report:FireServer((if ok then out else "ERROR " .. tostring(out)) .. " said=[" .. table.concat(said, ",") .. "] @" .. cmd)
end)
workspace:GetAttributeChangedSignal("E2Stand"):Connect(function()
	local cf = workspace:GetAttribute("E2Stand")
	if typeof(cf) == "CFrame" and player.Character then
		player.Character:PivotTo(cf)
	end
end)
RunService.RenderStepped:Connect(function()
	local cam = workspace:GetAttribute("E2Cam")
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
	local old = at:FindFirstChild("ZZE2Check")
	if old then old:Destroy() end
end
for _, k in {{ "E2Cam", "E2Stand", "HudTouch", "E2Do" }} do
	workspace:SetAttribute(k, nil)
end
if {lua(remove)} then
	return "removed"
end
local s = Instance.new("Script")
s.Name = "ZZE2Check"
s.Source = {lua(SERVER)}
s.Parent = sss
local c = Instance.new("LocalScript")
c.Name = "ZZE2Check"
c.Source = {lua(CLIENT)}
c.Parent = sps
return "installed"
"""
    with tempfile.NamedTemporaryFile("w", suffix=".luau", delete=False) as f:
        f.write(job)
    return run([f.name])


def cmd(c, wait=0.8):
    return server(
        f"local RS = game:GetService('ReplicatedStorage') RS:SetAttribute('E2Cmd', {lua(c + '|' + str(time.time()))}) "
        f"task.wait({wait}) return RS:GetAttribute('E2Said')"
    )


def do(c, wait=2.5):
    return server(
        f"local RS = game:GetService('ReplicatedStorage') RS:SetAttribute('E2Client', '') "
        f"workspace:SetAttribute('E2Do', {lua(c + '|' + str(time.time()))}) "
        f"local t = os.clock() repeat task.wait(0.1) until RS:GetAttribute('E2Client') ~= '' or os.clock() - t > {wait + 3} "
        f"return RS:GetAttribute('E2Client')"
    )


def setw(**kw):
    code = ""
    for k, v in kw.items():
        code += f"workspace:SetAttribute({lua(k)}, {'nil' if v is None else lua(v)}) "
    return server(code + "return 'ok'")


def state():
    out = cmd("state")
    s = json.loads(out[out.find("{") : out.rfind("}") + 1])
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
    cx, cy = OFFSET[0] + VIEW[0] // 2, OFFSET[1] + VIEW[1] // 2
    if box:
        bw, bh = box
        return im.crop((cx - bw // 2, cy - bh // 2, cx + bw // 2, cy + bh // 2))
    half = min(cx, SHOT[0] - cx)
    return im.crop((cx - half, TOP, cx + half, SHOT[1]))


def still(path):
    """The game view alone (the Studio window's shot holds the view at its left, the panels at its right)."""
    raw = OUT / ("raw_" + Path(path).name)
    raw.unlink(missing_ok=True)
    run(["shot", str(raw)], timeout=60)
    size, end = -1, time.time() + 10
    while time.time() < end:
        now = raw.stat().st_size if raw.exists() else -1
        if now > 0 and now == size:
            break
        size = now
        time.sleep(0.15)
    im = Image.open(raw).convert("RGB")
    # (the view: from the left edge to the explorer's border, the toolbar's foot to the command bar)
    w, h = im.size
    right = next((x for x in range(w - 1, w // 2, -1) if im.getpixel((x, h // 2))[2] > 200 and im.getpixel((x, h // 2))[0] < 120), w)
    # (the view's top: under Studio's ribbon and tabs, the first row from the top whose middle is not light grey)
    top = next((y for y in range(10, h // 3) if sum(im.getpixel((right // 2, y))) < 600 and y > 100), 124)
    im.crop((0, top, right, h - 4)).save(path)


def stills():
    """Pictures only, in a playtest after `run` (or alone): the tank's control, the sign free, paid and maxed."""
    cmd("setup|" + json.dumps(HANDS), 2.5)
    do("hold|0|", 1)
    cmd("still|tank", 1.5)
    time.sleep(1.2)
    still(ATTACH / "e2-tank-click.png")
    setw(HudTouch=True)
    time.sleep(0.8)
    still(OUT / "tank_phone.png")
    setw(HudTouch=None)
    cmd("level|3")
    cmd("free|1")
    do("free|1")
    cmd("still|sign", 1.5)
    time.sleep(1.2)
    still(ATTACH / "e2-sign-free.png")
    cmd("free|0")
    do("free|0")
    time.sleep(0.8)
    still(ATTACH / "e2-sign-paid.png")
    cmd("sign|30", 1.2)
    do("sign|1|0", 0.2)
    cmd("still|sign", 0.4)  # (back in view while it still says WALK CLOSER)
    still(OUT / "sign_walk_closer.png")
    cmd("free|1")
    do("free|1")
    cmd("level|12")
    time.sleep(1.2)
    still(OUT / "sign_max.png")
    cmd("level|3")


def check():
    log = []
    fails = []

    def note(text):
        print(text, flush=True)
        log.append(text)

    def expect(name, ok, detail=""):
        note(("PASS " if ok else "FAIL ") + name + (("  (" + detail + ")") if detail else ""))
        if not ok:
            fails.append(name)

    note("setup: " + cmd("setup|" + json.dumps(HANDS), 2.5))
    s = state()
    note(f"state: {s}")
    plot = s["plot"]
    other = next(p for p in s["plots"] if p != plot)

    # 1. no E anywhere
    note("at the tank: " + cmd("tank|0", 1.2))
    time.sleep(0.6)
    r = do("prompts")
    note("  " + r)
    expect("no ProximityPrompt on the dock (no E at tank or ride), no stale E label", "prompts=0 " in r and "staleE=0" in r, r)

    # 2. tank: one click puts exactly the chosen (newest) fish in
    s0 = state()
    r = do("tank|1|0")
    note("  " + r)
    s1 = state()
    expect("tank control shown with CLICK and PUT IN TANK", "shown=true" in r and "before=CLICK/PUT IN TANK/" in r, r)
    expect("one click put one fish in", s1["hands"] == s0["hands"] - 1 and s1["places"] == s0["places"] + 1,
           f"hands {s0['hands']}->{s1['hands']} places {s0['places']}->{s1['places']} {s0['handIds']}->{s1['handIds']}")
    expect("the shown fish went in (the newest)", s1["handIds"] == s0["handIds"][:-1], f"{s0['handIds']} -> {s1['handIds']}")
    expect("the tank's popup did not open from the control's click", "open=false" in r, r)
    time.sleep(0.4)
    shot(OUT / "raw_tank.png").save(OUT / "tank_after.png")
    # a double click: two presses in 0.05 s put one fish in
    s0 = state()
    r = do("tank|2|0.05")
    note("  " + r)
    s1 = state()
    expect("a double click puts one fish in", s1["hands"] == s0["hands"] - 1, f"{s0['hands']}->{s1['hands']} {r}")
    # a slot click at the tank holds (the server's Hold), never puts in
    s0 = state()
    r = do(f"hold|1|{s0['handIds'][0]}")
    s1 = state()
    note("  " + r)
    expect("a slot pick at the tank holds, not deposits", s1["hands"] == s0["hands"] and s1["places"] == s0["places"]
           and f"held={s0['handIds'][0]}" in r, r)
    time.sleep(0.6)
    shot(OUT / "raw_tank_held.png").save(ATTACH / "e2-tank-click.png")
    # too far: the control hides
    cmd("tank|30", 1.2)
    time.sleep(0.5)
    r = do("shown")
    expect("tank control hidden 36 studs from the glass", "shown=false" in r, r)
    cmd("tank|0", 1.2)
    time.sleep(0.5)
    # phone: TAP
    setw(HudTouch=True)
    r = do("tank|0|0")  # (no press: n=0)
    expect("phone: the cap says TAP", "mid=TAP/" in r, r)
    shot(OUT / "raw_tank_phone.png").save(OUT / "tank_phone.png")
    setw(HudTouch=None)

    # 3. the sign, free (Train.Free is 0 in Config since 2026-11-23: made free here, as stills() does)
    cmd("free|1")
    do("free|1")
    note("at the sign: " + cmd("sign|0", 1.2))
    time.sleep(0.8)
    r = do("geom")
    note("  " + r)
    expect("sign SurfaceGui active, cash press live, Robux has no button", "surfaceActive=true" in r and "active=true" in r
           and "robuxButtons=0" in r, r)
    expect("cash and Robux targets do not overlap", "overlap=false" in r, r)
    expect("other plots' cash presses are dead", "otherLive=0" in r, r)
    shot(OUT / "raw_sign_free.png").save(ATTACH / "e2-sign-free.png")
    s0 = state()
    r = do("sign|1|0")
    s1 = state()
    note("  " + r)
    expect("free click: one level up, no coins spent", s1["level"] == s0["level"] + 1 and s1["coins"] >= s0["coins"]
           and s1["ups"] == s0["ups"] + 1, f"level {s0['level']}->{s1['level']} coins {s0['coins']}->{s1['coins']} {r}")
    expect("the block said ... while pending", "texts=..." in r, r)
    # a double click: one ask, one level
    s0 = state()
    r = do("sign|3|0.05")
    s1 = state()
    note("  " + r)
    expect("triple click: one ask, one level", s1["level"] == s0["level"] + 1 and s1["ups"] == s0["ups"] + 1,
           f"level {s0['level']}->{s1['level']} ups {s0['ups']}->{s1['ups']}")
    # the server's own guard: two raw asks at once buy one level
    time.sleep(0.6)
    s0 = state()
    r = do("rawup|2")
    s1 = state()
    expect("server: two Up asks at once buy one level", s1["level"] == s0["level"] + 1 and s1["ups"] == s0["ups"] + 2,
           f"level {s0['level']}->{s1['level']} ups {s0['ups']}->{s1['ups']} {r}")

    # 4. paid
    cmd("level|2")
    cmd("free|0")
    do("free|0")
    cmd("coins|20")
    time.sleep(0.6)
    r = do("refresh")
    s0 = state()
    shot(OUT / "raw_sign_paid.png").save(ATTACH / "e2-sign-paid.png")
    r = do("sign|1|0")
    s1 = state()
    note("  " + r)
    expect("paid, too few coins: refused, no level, no coins taken", s1["level"] == s0["level"] and s1["coins"] >= s0["coins"]
           and "UpNo:Coins" in r, f"{s0['coins']}->{s1['coins']} {r}")
    price = 250000  # (Train.Levels[3].Price)
    cmd("coins|1000000")  # (enough for level 3, not for 3 and 4: a double charge would show)
    time.sleep(0.6)
    s0 = state()
    r = do("sign|2|0.05")
    s1 = state()
    note("  " + r)
    expect("paid: one level for its price exactly, double click charged once",
           # (the tank earns a few coins a second meanwhile: the drop is the price less under 120 of income)
           s1["level"] == s0["level"] + 1 and price - 120 < s0["coins"] - s1["coins"] <= price,
           f"level {s0['level']}->{s1['level']} coins {s0['coins']}->{s1['coins']}")
    cmd("free|1")
    do("free|1")

    # 5. refusals: too far, another's sign, dead, maxed
    cmd("sign|30", 1.2)
    s0 = state()
    r = do("sign|1|0")
    s1 = state()
    note("  " + r)
    expect("too far: WALK CLOSER, no ask sent", "texts=WALK CLOSER!" in r and s1["ups"] == s0["ups"], r)
    cmd(f"sign|0|{other}", 1.2)
    s0 = state()
    r = do(f"other|{other}")
    s1 = state()
    note("  " + r)
    expect("another plot's sign: no ask", s1["ups"] == s0["ups"] and s1["level"] == s0["level"], r)
    cmd("sign|0", 1.2)
    cmd("level|12")
    time.sleep(0.8)
    s0 = state()
    r = do("sign|1|0")
    s1 = state()
    note("  " + r)
    expect("maxed: MAX LEVEL, no ask", "MAX LEVEL" in r and s1["ups"] == s0["ups"], r)
    shot(OUT / "raw_sign_max.png").save(OUT / "sign_max.png")
    cmd("level|3")
    time.sleep(0.6)
    cmd("kill", 0.3)
    s0 = state()
    r = do("rawup|1")
    s1 = state()
    note("  " + r)
    expect("dead: refused", "UpNo:Dead" in r and s1["level"] == s0["level"], r)
    (OUT / "check.log").write_text("\n".join(log) + "\n")
    note(f"{len(fails)} failed: {fails}" if fails else "all passed")


if __name__ == "__main__":
    what = sys.argv[1] if len(sys.argv) > 1 else "run"
    if what == "install":
        print(install())
    elif what == "remove":
        print(install(remove=True))
    elif what == "stills":
        stills()
    else:
        check()
