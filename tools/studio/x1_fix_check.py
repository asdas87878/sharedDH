"""The fixes from the E1-E4 grade (task x1, docs/plans/2026-11-20-grade.md): checked in a Studio playtest.
    python tools/studio/x1_fix_check.py install | remove   (in Edit, before Play: a server Script and a LocalScript)
    node ~/Projects/studio-runner/studio-run.mjs play
    python tools/studio/x1_fix_check.py run                (in the playtest; log work/x1/check.log)
    python tools/studio/x1_fix_check.py shot <name>         (a still of the game view, work/x1/<name>.png)
Each check names the grade issue it covers:
  1  the Oxygen row shows 2,925 and 3,285,000 whole, and the number fits its bar
  2  seahorse trainer: whole seconds settled at an upgrade between two looks, at getting off, at death; never counted
     from before the seat (exact expected Oxygen from the server's own timings)
  3  a stocked tank's Income follows a live retune (sandbox Tune of Aquarium.PerRequired) without a new fish
  4  the hotbar (Q slot, its words, slot 7) inside a 320- and a 375-wide phone screen, and the keyboard layout unchanged
  5  a number key is not passed to the hotbar while the feel log's pick has the numbers, nor the press it answered
  6  no hold while seated on the trainer; seating puts a held fish away; no sit track under the land motion
  7  on a 10-degree slope the land fish tilts to it; a jump of 90 studs on the land fish is put back by the server
  8  a Colossal land fish holds the camera back (CameraMinZoomDistance), and getting off gives the old zoom back
 10  the land fish carries the server's LandEpoch
Issue 9 (a remote rider's seat on throttled frames) needs a second client: read in the code, not checked here.
Needs Studio open with the studio-runner plugin and Rojo serving this repo.
"""
import json
import subprocess
import sys
import tempfile
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "work/x1"
OUT.mkdir(parents=True, exist_ok=True)
RUN = str(Path.home() / "Projects/studio-runner/studio-run.mjs")

SERVER = r'''
local RS = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local SS = game:GetService("ServerStorage")
local Services = game:GetService("ServerScriptService"):WaitForChild("Server"):WaitForChild("Services")
local RideService = require(Services:WaitForChild("RideService"))
local AquariumService = require(Services:WaitForChild("AquariumService"))
local Config = require(RS:WaitForChild("Shared"):WaitForChild("Config"))
local report = Instance.new("RemoteEvent")
report.Name = "ZZX1Report"
report.Parent = RS
report.OnServerEvent:Connect(function(_, text)
	RS:SetAttribute("X1Client", tostring(text))
end)
local function player()
	return Players:GetPlayers()[1]
end
local function rootOf(p)
	return p.Character and p.Character:FindFirstChild("HumanoidRootPart")
end
local function trainer(op, a)
	return SS:WaitForChild("TrainerTest"):Invoke(op, player().UserId, a)
end
local function spawnAt()
	return workspace.ClaudeBlockout.Dock.DockSpawn.Position + Vector3.new(0, 4, 0)
end
local function waitFor(f, most)
	local t0 = os.clock()
	while os.clock() - t0 < most do
		if f() then
			return true
		end
		task.wait()
	end
	return false
end
local function seat()
	local p = player()
	p.Character:PivotTo(CFrame.new(spawnAt()))
	task.wait(0.4)
	local info = trainer("info")
	if type(info) ~= "table" then
		return nil, "no ride: " .. tostring(info)
	end
	p.Character:PivotTo(CFrame.new(info.Seat.Position + Vector3.new(0, 1, 0)))
	if not waitFor(function() return p:GetAttribute("TrainerRide") ~= nil end, 5) then
		return nil, "not seated"
	end
	return os.clock()
end
local function gainAt(level)
	return Config.Train.Levels[level].Oxygen
end
local wedge = nil
local function cmd(verb, a, b, c)
	local p = player()
	if verb == "max" then
		return tostring(p:GetAttribute("MaxOxygen"))
	elseif verb == "train" then
		RideService.train(p, tonumber(a))
		return tostring(p:GetAttribute("MaxOxygen"))
	elseif verb == "stand" then
		p.Character:PivotTo(CFrame.new(spawnAt()))
		return "stood"
	elseif verb == "give" then
		local spec = game:GetService("HttpService"):JSONDecode(a)
		while #RideService.carried(p) > 0 do
			RideService.takeCarried(p, 1)
		end
		for _, f in spec do
			RideService.giveCarried(p, { Id = f[1], Size = f[2], Variant = f[3] })
		end
		return "hands " .. #RideService.carried(p)
	elseif verb == "trial" then
		-- seated a+ seconds at level 1, an upgrade, b seconds at level 2, then getting off (c: "asked" or "died")
		trainer("level", 1)
		task.wait(0.6)
		local before = p:GetAttribute("MaxOxygen")
		local seated, why = seat()
		if not seated then
			return "FAIL " .. why
		end
		task.wait(tonumber(a))
		local upAt = os.clock()
		trainer("up")
		local level = p:GetAttribute("TrainerLevel")
		task.wait(tonumber(b))
		local offAt
		if c == "died" then
			offAt = os.clock()
			p.Character:FindFirstChildOfClass("Humanoid").Health = 0
		else
			RS:SetAttribute("X1Off", os.clock())
			waitFor(function() return p:GetAttribute("TrainerRide") == nil end, 3)
			offAt = os.clock()
		end
		waitFor(function() return p:GetAttribute("TrainerRide") == nil end, 3)
		task.wait(0.3)
		local after = p:GetAttribute("MaxOxygen")
		local t1, t2 = upAt - seated, offAt - upAt
		local want = math.floor(t1) * gainAt(1) + math.floor(t2) * gainAt(2)
		return string.format("gained=%d want=%d t1=%.3f t2=%.3f level=%s", after - before, want, t1, t2, tostring(level))
	elseif verb == "unseat" then
		if p:GetAttribute("TrainerRide") ~= nil then
			RS:SetAttribute("X1Off", os.clock())
			waitFor(function() return p:GetAttribute("TrainerRide") == nil end, 3)
		end
		task.wait(0.3)
		p.Character:PivotTo(CFrame.new(spawnAt()))
		return "trainer=" .. tostring(p:GetAttribute("TrainerRide"))
	elseif verb == "seat" then
		local seated, why = seat()
		return if seated then "seated" else "FAIL " .. why
	elseif verb == "state" then
		local held = workspace:FindFirstChild("HeldFish")
		return string.format("held=%s heldModels=%d trainer=%s land=%s state=%s",
			tostring(p:GetAttribute("HeldFish")), if held then #held:GetChildren() else 0,
			tostring(p:GetAttribute("TrainerRide")), tostring(p:GetAttribute("LandMounted")),
			tostring(RideService.stateOf(p)))
	elseif verb == "tank" then
		AquariumService.give(p, 0, { { "Clownfish", "Normal", "" }, { "ReefShark", "Big", "Gold" } })
		task.wait(0.2)
		return tostring(p:GetAttribute("Income"))
	elseif verb == "income" then
		return tostring(p:GetAttribute("Income")) .. " per=" .. tostring(Config.Aquarium.PerRequired)
	elseif verb == "touch" then
		workspace:SetAttribute("HudTouch", if a == "on" then true elseif a == "off" then false else nil)
		return "touch " .. a
	elseif verb == "slope" then
		-- a 10-degree ramp on the dock by its spawn, rising toward +Z; the player on its middle facing up it
		if wedge then
			wedge:Destroy()
		end
		local base = spawnAt() - Vector3.new(0, 4, 0)
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = { p.Character, workspace:FindFirstChild("LandFish") }
		local hit = workspace:Raycast(base + Vector3.new(0, 20, 0), Vector3.new(0, -60, 0), params)
		local floor = if hit then hit.Position.Y else base.Y
		local long = 80
		local high = long * math.tan(math.rad(10))
		wedge = Instance.new("WedgePart")
		wedge.Name = "ZZX1Ramp"
		wedge.Anchored = true
		wedge.Size = Vector3.new(40, high, long)
		wedge.CFrame = CFrame.new(base.X + 50, floor + high / 2, base.Z)
		wedge.Parent = workspace
		local mid = wedge.CFrame.Position + Vector3.new(0, high / 2 + 8, 0)
		p.Character:PivotTo(CFrame.lookAt(mid, mid + Vector3.new(0, 0, 1)))
		return string.format("ramp at %.1f, floor %.1f", base.X + 50, floor)
	elseif verb == "unslope" then
		if wedge then
			wedge:Destroy()
			wedge = nil
		end
		return "gone"
	elseif verb == "where" then
		local root = rootOf(p)
		return string.format("%.2f,%.2f,%.2f", root.Position.X, root.Position.Y, root.Position.Z)
	elseif verb == "epoch" then
		local m = workspace:FindFirstChild("LandFish") and workspace.LandFish:FindFirstChild(p.Name)
		return tostring(m and m:GetAttribute("LandEpoch"))
	end
	return "unknown " .. tostring(verb)
end
RS:GetAttributeChangedSignal("X1Cmd"):Connect(function()
	local line = tostring(RS:GetAttribute("X1Cmd") or "")
	local verb, a, b, c, token = string.match(line, "^(%w*)|([^|]*)|([^|]*)|([^|]*)|(.*)$")
	local ok, said = pcall(cmd, verb, a, b, c)
	RS:SetAttribute("X1Said", token .. "=" .. (if ok then tostring(said) else "ERROR " .. tostring(said)))
end)
'''

CLIENT = r'''
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local player = Players.LocalPlayer
local Net = require(RS:WaitForChild("Shared"):WaitForChild("Net"))
local Client = player:WaitForChild("PlayerScripts"):WaitForChild("Client")
local EquipController = require(Client.Controllers:WaitForChild("EquipController"))
local AnimController = require(Client.Controllers:WaitForChild("AnimController"))
local FeelLog = require(Client.Lib:WaitForChild("FeelLog"))
local Slots = require(Client.UI:WaitForChild("Slots"))
local report = RS:WaitForChild("ZZX1Report", 60)
local denied = ""
Net.Ride.OnClientEvent:Connect(function(kind, a, b)
	if kind == "Denied" then
		denied = tostring(a) .. ":" .. tostring(b)
	end
end)
RS:GetAttributeChangedSignal("X1Off"):Connect(function()
	Net.Folder:WaitForChild("Trainer"):FireServer("Off")
end)
local function hudScale()
	local root = player.PlayerGui:FindFirstChild("Root", true)
	local s = root and root.Parent and root.Parent:FindFirstChildOfClass("UIScale")
	if not s and root then
		s = root:FindFirstChildOfClass("UIScale")
	end
	return if s then s.Scale else 1
end
local function cmd(verb, a, b)
	if verb == "stat" then
		local rows = player.PlayerGui:FindFirstChild("StatRows", true)
		local label = rows and rows:FindFirstChild("Oxygen") and rows.Oxygen:FindFirstChildWhichIsA("TextLabel")
		if not label then
			return "no label"
		end
		task.wait(0.3)
		return string.format("text=%s fits=%s bounds=%.1f box=%.1f", label.Text, tostring(label.TextFits),
			label.TextBounds.X, label.AbsoluteSize.X)
	elseif verb == "fit" then
		-- the hotbar laid out for a screen `a` HUD units wide: its extents from the screen's middle, in HUD units
		local w = tonumber(a)
		Slots.fit(w)
		task.wait(0.2)
		local gui = player.PlayerGui:FindFirstChild("Slots", true)
		local eq = gui:FindFirstChild("Equipped", true)
		local hint = gui:FindFirstChild("Hint")
		local fitS = gui:FindFirstChild("Fit")
		local f = if fitS then fitS.Scale else 1
		-- (screen pixels to HUD units: the equipped slot's drawn size against its own size, under the fit)
		local scale = eq.AbsoluteSize.X / (eq.Size.X.Offset * f)
		local mid = workspace.CurrentCamera.ViewportSize.X / 2
		local left = math.min(eq.AbsolutePosition.X, hint.AbsolutePosition.X)
		local right = -math.huge
		local smallest = math.huge
		for _, d in gui:GetDescendants() do
			if d:IsA("GuiObject") and d.Visible and d.AbsoluteSize.X > 20 and d.AbsoluteSize.X < 80 and d.Name ~= "Hint" then
				right = math.max(right, d.AbsolutePosition.X + d.AbsoluteSize.X)
				smallest = math.min(smallest, d.AbsoluteSize.X)
			end
		end
		return string.format("left=%.1f right=%.1f half=%.1f fit=%.3f slot=%.1f",
			(left - mid) / scale, (right - mid) / scale, w / 2, f, eq.Size.X.Offset * f)
	elseif verb == "keys" then
		-- the hotbar's key gate (EquipController.input) with the feel log's pick up, and after it answered a press
		local out = {}
		local one = { KeyCode = Enum.KeyCode.One }
		FeelLog.TakesNumbers = true
		table.insert(out, "pickUp=" .. tostring(EquipController.input(one :: any, false)))
		local q = { KeyCode = Enum.KeyCode.Q }
		table.insert(out, "pickUpQ=" .. tostring(EquipController.input(q :: any, false)))
		FeelLog.TakesNumbers = false
		FeelLog.TakenInput = one :: any
		table.insert(out, "answered=" .. tostring(EquipController.input(one :: any, false)))
		FeelLog.TakenInput = nil
		table.insert(out, "processed=" .. tostring(EquipController.input({ KeyCode = Enum.KeyCode.Two } :: any, true)))
		table.insert(out, "free=" .. tostring(EquipController.input({ KeyCode = Enum.KeyCode.Two } :: any, false)))
		task.wait(0.5)
		EquipController.press(Enum.KeyCode.Two) -- (put it away again)
		return table.concat(out, " ")
	elseif verb == "key" then
		EquipController.press(Enum.KeyCode[a])
		task.wait(0.8)
		return "pressed " .. a .. " " .. denied
	elseif verb == "hold" then
		denied = ""
		Net.Action:FireServer("Hold", tonumber(a), b)
		task.wait(0.6)
		return "denied=" .. denied
	elseif verb == "ride" then
		Net.Action:FireServer("RideMount")
		task.wait(0.8)
		return "mount " .. tostring(player:GetAttribute("LandMounted"))
	elseif verb == "unequip" then
		Net.Action:FireServer("RideUnequip")
		task.wait(0.8)
		return "unequip " .. tostring(player:GetAttribute("EquippedFish"))
	elseif verb == "zoom" then
		task.wait(0.5)
		return string.format("min=%.1f max=%.1f", player.CameraMinZoomDistance, player.CameraMaxZoomDistance)
	elseif verb == "land" then
		local m = workspace:FindFirstChild("LandFish") and workspace.LandFish:FindFirstChild(player.Name)
		local info = m and AnimController.landInfo(m)
		if not info then
			return "no land info"
		end
		local x = 0
		if info.shift then
			x = select(1, info.shift:ToEulerAnglesXYZ())
		end
		local hum = player.Character:FindFirstChildOfClass("Humanoid")
		local sits = 0
		for _, t in hum:FindFirstChildOfClass("Animator"):GetPlayingAnimationTracks() do
			if string.find(string.lower(t.Animation and t.Animation.Name or t.Name), "sit") then
				sits += 1
			end
		end
		return string.format("pitch=%.2f up=%.2f sitTracks=%d style=%s", math.deg(x),
			if info.shift then info.shift.Position.Y else 0, sits, tostring(info.style))
	elseif verb == "nose" then
		-- as drawn on this machine: the fish's front half against its back half (Root space: -Z is ahead), and which
		-- way the floor rises under it (+: higher ahead)
		local m = workspace.LandFish:FindFirstChild(player.Name)
		local root = m.PrimaryPart
		local fy, fn, by, bn = 0, 0, 0, 0
		for _, d in m:GetDescendants() do
			if d:IsA("BasePart") and d ~= root then
				local at = root.CFrame:PointToObjectSpace(d.Position)
				local y = d.Position.Y
				if at.Z < -0.5 then
					fy += y
					fn += 1
				elseif at.Z > 0.5 then
					by += y
					bn += 1
				end
			end
		end
		local look = root.CFrame.LookVector * Vector3.new(1, 0, 1)
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = { player.Character, workspace.LandFish }
		local function floor(at)
			local hit = workspace:Raycast(at + Vector3.new(0, 30, 0), Vector3.new(0, -80, 0), params)
			return if hit then hit.Position.Y else 0
		end
		local rise = floor(root.Position + look.Unit * 5) - floor(root.Position - look.Unit * 5)
		return string.format("frontMinusBack=%.2f floorRise=%.2f", fy / math.max(fn, 1) - by / math.max(bn, 1), rise)
	elseif verb == "side" then
		-- the camera beside the land fish, square on (for a still); "back" gives it back
		local cam = workspace.CurrentCamera
		if a == "back" then
			cam.CameraType = Enum.CameraType.Custom
			return "camera back"
		end
		local m = workspace.LandFish:FindFirstChild(player.Name)
		local cf, size = m:GetBoundingBox()
		cam.CameraType = Enum.CameraType.Scriptable
		local at = cf.Position
		cam.CFrame = CFrame.lookAt(at + Vector3.new(math.max(size.Z, 10) * 1.6, 2, 0), at)
		return "camera at the side"
	elseif verb == "tune" then
		Net.Sandbox:FireServer("Tune", a, tonumber(b))
		task.wait(0.4)
		return "tuned"
	elseif verb == "jump" then
		-- the player's own machine moves the body a long way at once (a cheat's teleport) over the dock
		local root = player.Character.HumanoidRootPart
		local dir = Vector3.new(tonumber(a) or 1, 0, tonumber(b) or 0).Unit
		local from = root.Position
		root.CFrame = root.CFrame + dir * 90
		task.wait(2.2)
		local moved = ((root.Position - from) * Vector3.new(1, 0, 1)).Magnitude
		return string.format("movedAfter=%.1f", moved)
	end
	return "unknown " .. tostring(verb)
end
workspace:GetAttributeChangedSignal("X1Do"):Connect(function()
	local line = tostring(workspace:GetAttribute("X1Do") or "")
	local verb, a, b, token = string.match(line, "^(%w*)|([^|]*)|([^|]*)|(.*)$")
	local ok, said = pcall(cmd, verb, a, b)
	report:FireServer(token .. "=" .. (if ok then tostring(said) else "ERROR " .. tostring(said)))
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


def server(code, timeout=120):
    out = run(["--ctx", "server", "--code", code], timeout=timeout)
    try:
        data = json.loads(out)
        if isinstance(data, dict) and "result" in data:
            return str(data["result"])
    except ValueError:
        pass
    return out


def install(remove=False):
    job = f"""local sss = game:GetService("ServerScriptService")
local sps = game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts")
for _, at in {{ sss, sps }} do
	local old = at:FindFirstChild("ZZX1Check")
	if old then old:Destroy() end
end
local ramp = workspace:FindFirstChild("ZZX1Ramp")
if ramp then ramp:Destroy() end
workspace:SetAttribute("X1Do", nil)
workspace:SetAttribute("HudTouch", nil)
if {lua(remove)} then
	return "removed"
end
local s = Instance.new("Script")
s.Name = "ZZX1Check"
s.Source = {lua(SERVER)}
s.Parent = sss
local c = Instance.new("LocalScript")
c.Name = "ZZX1Check"
c.Source = {lua(CLIENT)}
c.Parent = sps
return "installed"
"""
    with tempfile.NamedTemporaryFile("w", suffix=".luau", delete=False) as f:
        f.write(job)
    return run([f.name])


def _wait(attr, where, token, most):
    return server(
        f"local RS = game:GetService('ReplicatedStorage') local t0 = os.clock() "
        f"while os.clock() - t0 < {most} do local v = tostring(RS:GetAttribute({lua(attr)}) or '') "
        f"if string.sub(v, 1, {len(token) + 1}) == {lua(token + '=')} then return string.sub(v, {len(token) + 2}) end "
        f"task.wait(0.05) end return 'TIMEOUT'",
        timeout=most + 60,
    )


def cmd(verb, a="", b="", c="", most=20):
    token = str(time.time())
    server(f"game:GetService('ReplicatedStorage'):SetAttribute('X1Cmd', {lua('|'.join([verb, a, b, c, token]))}) return 'ok'")
    return _wait("X1Said", "server", token, most)


def do(verb, a="", b="", most=20):
    token = str(time.time())
    server(f"workspace:SetAttribute('X1Do', {lua('|'.join([verb, a, b, token]))}) return 'ok'")
    return _wait("X1Client", "client", token, most)


def field(text, key):
    for part in text.split():
        if part.startswith(key + "="):
            return part[len(key) + 1:]
    return None


def check():
    log = []
    results = []

    def say(line):
        print(line, flush=True)
        log.append(line)

    def ok(name, passed, detail):
        results.append(passed)
        say(f"{'PASS' if passed else 'FAIL'}  {name}: {detail}")

    say(f"x1 fix check, {time.strftime('%Y-%m-%d %H:%M:%S')}")
    cmd("stand")
    cmd("touch", "off")
    time.sleep(1)

    # 1: the Oxygen row, whole and fitting
    start = int(float(cmd("max")))
    for want in (2925, 3285000):
        cmd("train", str(want - int(float(cmd("max")))))
        s = do("stat")
        ok(f"1 Oxygen row {want:,}", field(s, "text") == f"{want:,}" and field(s, "fits") == "true", s)

    # 2: the trainer's whole seconds at its boundaries
    for a, b, how in (("3.04", "2.06", "asked"), ("2.53", "1.48", "asked"), ("1.95", "2.97", "asked"), ("2.07", "1.05", "died")):
        s = cmd("trial", a, b, how, most=40)
        ok(f"2 trainer {a}s + upgrade + {b}s, then {how}", field(s, "gained") is not None and field(s, "gained") == field(s, "want"), s)
        if how == "died":
            time.sleep(6)
    cmd("stand")
    time.sleep(1)

    # 6: no hold while seated; seating puts a held fish away
    cmd("give", json.dumps([["Clownfish", "Normal", ""], ["ReefShark", "Colossal", "Gold"]]))
    do("key", "One")
    s1 = cmd("state")
    cmd("seat")
    s2 = cmd("state")
    ok("6 seating on the trainer puts the held fish away", field(s1, "held") == "Clownfish" and field(s2, "held") == "nil" and field(s2, "heldModels") == "0", f"before: {s1} | seated: {s2}")
    h = do("hold", "1", "Clownfish")
    s3 = cmd("state")
    ok("6 no hold while seated", "Hold:Seated" in h and field(s3, "held") == "nil", f"{h} | {s3}")
    say("  unseat: " + cmd("unseat"))
    time.sleep(1.5)

    # 5: the key gate
    s = do("keys")
    ok("5 numbers left to the feel log's pick", s == "pickUp=false pickUpQ=true answered=false processed=false free=true", s)

    # 3: a stocked tank follows a live retune (the sandbox panel's Tune, from the client, as it sends it)
    before = cmd("tank")
    per = field(cmd("income"), "per") or "0.025"
    do("tune", "Aquarium.PerRequired", str(float(per) * 2))
    time.sleep(0.5)
    after = cmd("income").split()[0]
    do("tune", "Aquarium.PerRequired", per)
    time.sleep(0.5)
    back = cmd("income").split()[0]
    try:
        doubled = abs(float(after) - 2 * float(before)) < 0.01 and abs(float(back) - float(before)) < 0.01 and float(before) > 0
    except ValueError:
        doubled = False
    ok("3 stocked tank pays by a live retune", doubled, f"income {before} -> PerRequired x2 -> {after} -> back {back}")

    # 4: the hotbar on narrow phones, and the keyboard layout as it was
    cmd("touch", "on")
    time.sleep(1.2)
    for w in (320, 375):
        s = do("fit", str(w))
        left, right, half = (float(field(s, k)) for k in ("left", "right", "half"))
        ok(f"4 hotbar inside a {w}-wide phone", left >= -half and right <= half and float(field(s, "slot")) >= 26, s)
    cmd("touch", "off")
    time.sleep(1.2)
    s = do("fit", "1400")
    ok("4 keyboard: row unshrunk, unmoved on a wide screen", field(s, "fit") == "1.000" and 185 <= float(field(s, "right")) <= 205, s)
    do("fit", "100000")

    # 8 and 10: a Colossal land fish
    cmd("stand")
    time.sleep(0.8)
    z0 = do("zoom")
    do("key", "Two")
    do("key", "Q")
    time.sleep(1.5)
    st = cmd("state")
    z1 = do("zoom")
    ok("8 Colossal land fish holds the camera back", field(st, "land") == "true" and float(field(z1, "min")) > float(field(z0, "min")) + 10, f"{st} | before {z0} | on {z1}")
    ep = cmd("epoch")
    ok("10 land fish carries LandEpoch", ep not in ("nil", "", "TIMEOUT"), ep)
    s = do("land")
    ok("6 no sit track under the land motion", field(s, "sitTracks") == "0", s)
    do("ride")
    z2 = do("zoom")
    ok("8 off the fish, the zoom comes back", z2 == z0, f"before {z0} | off {z2}")

    # 7: a slope, and the server's pace check, on the small fish
    do("key", "One")
    do("key", "Q")
    time.sleep(1)
    r = cmd("slope")
    time.sleep(2.5)
    s = do("land")
    pitch = float(field(s, "pitch") or 0)
    ok("7 land fish tilts to a 10-degree slope", 6 <= abs(pitch) <= 14, f"{r} | {s}")
    n = do("nose")
    ok("7 the tilt goes the floor's way (front higher going up)", float(field(n, "floorRise") or 0) > 0 and float(field(n, "frontMinusBack") or 0) > 0, n)
    cmd("unslope")
    cmd("stand")
    time.sleep(1.5)
    for dx, dz in (("1", "0"), ("-1", "0"), ("0", "1"), ("0", "-1")):
        s = do("jump", dx, dz)
        if "movedAfter" in s:
            break
    moved = float(field(s, "movedAfter") or 999)
    st = cmd("state")
    ok("7 a 90-stud jump on the land fish is put back", moved < 15 and field(st, "land") == "true", s + " | " + st)
    cmd("stand")
    do("unequip")
    return log, results


def finish(log, results):
    passed = sum(1 for r in results if r)
    log.append(f"RESULT {passed}/{len(results)} pass")
    print(log[-1])
    (OUT / "check.log").write_text("\n".join(log) + "\n")


if __name__ == "__main__":
    verb = sys.argv[1] if len(sys.argv) > 1 else "run"
    if verb == "install":
        print(install())
    elif verb == "remove":
        print(install(remove=True))
    elif verb == "shot":
        path = OUT / f"{sys.argv[2]}.png"
        path.unlink(missing_ok=True)
        print(run(["shot", str(path)], timeout=60))
    else:
        log, results = check()
        finish(log, results)
