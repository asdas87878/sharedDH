"""The whole loop once, on real time, in one Studio playtest: the last check before a push (NULLROOM m5, 2026-11-24).
On Hugo's PC (studio-runner); Studio open on the place, in Edit, nobody playing in it.
    python tools/studio/full_check.py place             (in Edit: the place against the repo, see below)
    python tools/studio/full_check.py install | remove  (in Edit, before Play / after the stop: a Script, a LocalScript)
    python tools/studio/full_check.py run               (in a playtest: every step below; exit code 1 on a miss)
    python tools/studio/full_check.py all               (place, install, Play, run, stop, remove, the mouse and camera
                                                         put back, place again; exit code 1 on a miss)
What `place` checks: every script in the place is a file of src/ with the same bytes (through Rojo's sourcemap), a
creature data module that returns what its src/shared/Creatures/*.json holds, or one of the map's two own scripts as
its loader file installs it (Surface.WaterLook, Dock.HubLife); every script file of src/ is in the place; nothing named
ZZ* is left, no switch is left on the workspace, ReplicatedStorage or ServerStorage, and Studio is in Edit with the
mouse free and the camera Fixed.
What `run` plays, with no clock held and no look switch set (so the black lifts on its own 1.3 s):
  boot      a plot handed out, on the dock; all 8 pens show the level 1 seahorse from its meshes;
  seahorse  walking up seats you, Oxygen comes once a second at the level's number, getting off stops it;
  sub trip  tier 1 to land 2 through SubService's own test door, in by walking off the dock's lip: Carried, the phases
            in order, let go at the drop; sent home off it: no black, the end-of-dive screen (GREAT DIVE) comes up;
  dive      walking off the lip with no sub: into the water and onto a fish by itself (Riding);
  fail      RideService.forceFail from that fish (as running out of Oxygen): the words, the black whole and over the
            HUD (RideBlack's order above RideHud's), home with the black still up, the end-of-dive screen only once
            the black is gone;
  no errors every error line of the server's and the client's log counts, from boot on; warnings are listed.
Log: work/full_check/run.log.
"""
import glob
import json
import os
import subprocess
import sys
import tempfile
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
RUN = str(Path.home() / "Projects/studio-runner/studio-run.mjs")
ROJO = str(Path.home() / ".rokit/bin/rojo")
NAME = "ZZFullCheck"
OUT = ROOT / "work/full_check"
# a warning Studio gives on every play of this place, not ours (m1, 2026-11-23)
KNOWN = ("203785492",)

SERVER = r'''
local RS = game:GetService("ReplicatedStorage")
local SS = game:GetService("ServerStorage")
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local LogService = game:GetService("LogService")
local Services = game:GetService("ServerScriptService"):WaitForChild("Server"):WaitForChild("Services")
local RideService = require(Services:WaitForChild("RideService"))
local AquariumService = require(Services:WaitForChild("AquariumService"))
local Config = require(RS:WaitForChild("Shared"):WaitForChild("Config"))
local RideStyles = require(RS:WaitForChild("Shared"):WaitForChild("RideStyles"))
local report = Instance.new("RemoteEvent")
report.Name = "ZZFullReport"
report.Parent = RS
local out = Instance.new("StringValue")
out.Name = "ZZFullOut"
out.Parent = SS
local heard, events = {}, {}
report.OnServerEvent:Connect(function(_, kind, text)
	if kind == "log" then
		if #heard < 200 then
			table.insert(heard, tostring(text))
		end
	elseif #events < 2000 then
		table.insert(events, tostring(text))
	end
end)
local function v3(v)
	return { math.floor(v.X * 10 + 0.5) / 10, math.floor(v.Y * 10 + 0.5) / 10, math.floor(v.Z * 10 + 0.5) / 10 }
end
local function plots()
	return workspace.ClaudeBlockout.Dock.Plots
end
local function rideOf(plot)
	local ride = plot:FindFirstChild("TrainerRide")
	local toy = ride and ride:FindFirstChild("Toy")
	local body = toy and toy:FindFirstChild("Body")
	return ride, toy, body
end
local function answer(player, what, arg)
	local plot = plots():FindFirstChild(tostring(player:GetAttribute("Plot")))
	if what == "state" then
		local ride, _, body
		if plot then
			ride, _, body = rideOf(plot)
		end
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local level = player:GetAttribute("TrainerLevel") or 0
		local row = Config.Train.Levels[math.clamp(level, 1, #Config.Train.Levels)]
		return {
			plot = plot and plot.Name,
			state = RideService.stateOf(player),
			level = level,
			rideLevel = ride and ride:GetAttribute("Level"),
			max = player:GetAttribute("MaxOxygen"),
			training = player:GetAttribute("Training"),
			onRide = player:GetAttribute("TrainerRide"),
			welded = body ~= nil and body:FindFirstChild("TrainerWeld") ~= nil,
			each = row.Oxygen,
			phase = player:GetAttribute("SubPhase"),
			equip = player:GetAttribute("SubEquip"),
			dest = player:GetAttribute("SubDest"),
			root = root and v3(root.Position),
			leap = Config.Dive.Leap,
		}
	elseif what == "near" or what == "far" then
		-- beside the ride (inside the walk-up reach) or well away from it, on the hub's side (as trainer_check.py)
		local ride = rideOf(plot)
		local base = ride:GetAttribute("SpringBase")
		local away = if what == "near" then RideStyles.Trainer.Reach - 1.5 else 16
		local at = base.Position + base.LookVector * away + Vector3.new(0, 4, 0)
		player.Character:PivotTo(CFrame.lookAt(at, at - base.LookVector))
		return { at = v3(at) }
	elseif what == "rides" then
		local got = {}
		for i = 1, 8 do
			local p = plots():FindFirstChild("Plot" .. i)
			local ride, toy, body
			if p then
				ride, toy, body = rideOf(p)
			end
			local old, preview, meshes = {}, 0, 0
			if p then
				for _, c in p:GetChildren() do
					if c:IsA("BasePart") and (c.Name == "TrainerBase" or c.Name == "TrainerSpring" or c.Name == "SpringCoil") then
						table.insert(old, c.Name)
					end
					if c:GetAttribute("EditPreview") == true then
						preview += 1
					end
				end
			end
			if toy then
				for _, d in toy:GetDescendants() do
					if d:IsA("MeshPart") then
						meshes += 1
					end
				end
			end
			got["Plot" .. i] = {
				level = ride and ride:GetAttribute("Level"),
				mesh = body and body:IsA("MeshPart") and body.MeshId or (body and body.ClassName),
				meshes = meshes,
				old = old,
				preview = preview,
			}
		end
		return got
	elseif what == "sub" then -- "tier,land": bought up to that tier, equipped, the land picked (SubService's test door)
		local t = SS:WaitForChild("SubTest")
		local tier, land = string.match(arg, "(%d+),(%d+)")
		t:Invoke("give", player.UserId, 1e13)
		for _ = 1, tonumber(tier) do
			t:Invoke("buy", player.UserId)
		end
		t:Invoke("equip", player.UserId, tonumber(tier))
		return HttpService:JSONDecode(t:Invoke("pick", player.UserId, tonumber(land), ""))
	elseif what == "subhome" then
		local t = SS:WaitForChild("SubTest")
		t:Invoke("equip", player.UserId, 0)
		return HttpService:JSONDecode(t:Invoke("pick", player.UserId, 0, ""))
	elseif what == "fail" then
		return { failed = RideService.forceFail(player, if arg ~= "" then arg else nil) }
	elseif what == "home" then
		RideService.sendHome(player)
		return { state = RideService.stateOf(player) }
	elseif what == "events" then
		return { events = events }
	elseif what == "logs" then
		local server = {}
		for _, m in LogService:GetLogHistory() do
			if m.messageType == Enum.MessageType.MessageWarning or m.messageType == Enum.MessageType.MessageError then
				table.insert(server, m.messageType.Name .. ": " .. string.sub(m.message, 1, 300))
			end
		end
		return { server = server, client = heard }
	end
	return { error = "no such command" }
end
RS:GetAttributeChangedSignal("FullCmd"):Connect(function()
	local cmd = RS:GetAttribute("FullCmd")
	if type(cmd) ~= "string" then
		return
	end
	local what, arg = string.match(cmd, "^([^|]*)|([^|]*)|")
	local player = Players:GetPlayers()[1]
	local ok, got = pcall(function()
		return if player then answer(player, what, arg) else { error = "no player" }
	end)
	out.Value = cmd .. "\n" .. HttpService:JSONEncode(if ok then got else { error = tostring(got) })
end)
'''

CLIENT = r'''
local RS = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local LogService = game:GetService("LogService")
local report = RS:WaitForChild("ZZFullReport")
local player = Players.LocalPlayer
local gui = player:WaitForChild("PlayerGui")
local t0 = os.clock()
-- the log from boot on: every warning and error
local sent = 0
local function log(message, kind)
	if (kind == Enum.MessageType.MessageWarning or kind == Enum.MessageType.MessageError) and sent < 150 then
		sent += 1
		report:FireServer("log", kind.Name .. ": " .. string.sub(message, 1, 300))
	end
end
for _, m in LogService:GetLogHistory() do
	log(m.message, m.messageType)
end
LogService.MessageOut:Connect(log)
local function ev(text)
	report:FireServer("ev", string.format("%.2f|%s", os.clock() - t0, text))
end
local Client = player:WaitForChild("PlayerScripts"):WaitForChild("Client")
local State = require(Client:WaitForChild("Lib"):WaitForChild("State"))
local CatchShow = require(Client:WaitForChild("UI"):WaitForChild("CatchShow"))
local Net = require(RS:WaitForChild("Shared"):WaitForChild("Net"))
local UP = Vector3.yAxis
local FLAT = Vector3.new(1, 0, 1)

local function controls(on)
	local ok, module = pcall(function()
		return require(player.PlayerScripts:WaitForChild("PlayerModule", 5)):GetControls()
	end)
	if ok and module then
		if on then
			module:Enable()
		else
			module:Disable()
		end
	end
end
local function params()
	local p = RaycastParams.new()
	p.FilterType = Enum.RaycastFilterType.Exclude
	local list = { workspace.CurrentCamera }
	for _, other in Players:GetPlayers() do
		if other.Character then
			table.insert(list, other.Character)
		end
	end
	p.FilterDescendantsInstances = list
	p.RespectCanCollide = true
	p.IgnoreWater = true
	return p
end
-- The lip (as dive_leap_check.py): out from the dock spawn along its look until there is no ground under
local function lip()
	local dock = Net.Folder:GetAttribute("Dock")
	if typeof(dock) ~= "CFrame" then
		return nil
	end
	local out = (dock.LookVector * FLAT).Unit
	local from = dock.Position + UP * 4
	local floor = nil
	for step = 0, 800 do
		local at = from + out * (step * 0.5)
		local hit = workspace:Raycast(at, -UP * 40, params())
		if not hit then
			if not floor then
				return nil
			end
			local edge = from + out * math.max(step * 0.5 - 0.5, 0)
			return Vector3.new(edge.X, floor, edge.Z), out
		end
		floor = hit.Position.Y
	end
	return nil
end
-- Stood a run-up behind the lip and walked off it, as a player would, until we are in the water (or 12 s are up)
local walking = false
local function walk()
	if walking then
		return
	end
	local lipAt, out = lip()
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not lipAt or not root or not humanoid then
		ev("walk|none|" .. (if lipAt then "no character" else "no lip found"))
		return
	end
	walking = true
	local height = if humanoid.RigType == Enum.HumanoidRigType.R15 then humanoid.HipHeight + root.Size.Y / 2 else 3
	local stand = lipAt - out * 16 + UP * (height + 0.2)
	controls(false)
	humanoid:Move(Vector3.zero)
	character:PivotTo(CFrame.lookAt(stand, stand + out))
	root.AssemblyLinearVelocity = Vector3.zero
	task.wait(1.0)
	ev(string.format("walk|start|lip=(%.1f,%.1f,%.1f) mode=%s", lipAt.X, lipAt.Y, lipAt.Z, State.Mode))
	local started = os.clock()
	while os.clock() - started < 12 and State.Mode == "Dock" do
		humanoid:Move(if State.Leaping then Vector3.zero else out)
		RunService.RenderStepped:Wait()
	end
	humanoid:Move(Vector3.zero)
	controls(true)
	ev(string.format("walk|end|%.2f s mode=%s", os.clock() - started, State.Mode))
	walking = false
end
workspace:GetAttributeChangedSignal("FullDo"):Connect(function()
	local what = string.match(tostring(workspace:GetAttribute("FullDo")), "^([^|]*)|")
	if what == "off" then
		RS:WaitForChild("Remotes"):WaitForChild("Trainer"):FireServer("Off")
	elseif what == "walk" then
		task.spawn(walk)
	end
end)
-- what the screen does, as it happens: the mode, the sub's phase, the fail's words, the black, the end-of-dive screen
local mode, phase, words = State.Mode, nil, ""
local whole, showing = false, false
local function screens()
	local black = gui:FindFirstChild("RideBlack")
	local hud = gui:FindFirstChild("RideHud")
	local over = {}
	for _, s in gui:GetChildren() do
		if s:IsA("ScreenGui") and s.Enabled and black and s ~= black and s.DisplayOrder >= black.DisplayOrder then
			table.insert(over, s.Name .. ":" .. s.DisplayOrder)
		end
	end
	table.sort(over)
	local frame = black and black:FindFirstChildOfClass("Frame")
	return string.format("order=%s hud=%s see=%.2f over=%s", tostring(black and black.DisplayOrder), tostring(hud and hud.DisplayOrder),
		if frame then frame.BackgroundTransparency else -1, table.concat(over, ","))
end
ev(string.format("ready|look=%s mode=%s", tostring(CatchShow.look()), State.Mode))
RunService.RenderStepped:Connect(function()
	if State.Mode ~= mode then
		ev(string.format("mode|%s>%s|fade=%.2f %s", mode, State.Mode, State.Fade, if State.Mode == "Dock" then screens() else ""))
		mode = State.Mode
	end
	local p = player:GetAttribute("SubPhase")
	if p ~= phase then
		ev("sub|" .. tostring(p))
		phase = p
	end
	if State.FadeText ~= words then
		words = State.FadeText
		ev("words|" .. (if words == "" then "-" else words))
	end
	if not whole and State.Fade >= 0.98 then
		whole = true
		ev("black|whole|mode=" .. State.Mode .. " " .. screens())
	elseif whole and State.Fade <= 0.02 then
		whole = false
		ev("black|gone|mode=" .. State.Mode)
	end
	local s = CatchShow.showing()
	if s ~= showing then
		showing = s
		ev(string.format("great|%s|fade=%.2f words=%s mode=%s", if s then "shown" else "closed", State.Fade,
			if State.FadeText == "" then "-" else State.FadeText, State.Mode))
	end
end)
'''

# ---------------------------------------------------------------------------------------------------------------------
# the place against the repo

PLACE_READ = r'''
local function hash(s)
	local h = 7
	for i = 1, #s, 4096 do
		for _, b in { string.byte(s, i, math.min(i + 4095, #s)) } do
			h = (h * 31 + b) % 4294967296
		end
	end
	return h
end
local P = 67108859
local function sh(s, h)
	for i = 1, #s do
		h = (h * 31 + string.byte(s, i)) % P
	end
	return h
end
local function walk(v, ph, acc)
	local t = typeof(v)
	if t == "table" then
		for k, c in v do
			walk(c, sh(if typeof(k) == "number" then "#" .. tostring(k) else "." .. tostring(k), ph), acc)
		end
	else
		local vs = if t == "number" then string.format("%.6f", v) elseif t == "string" then "s" .. v else tostring(v)
		acc.n += 1
		acc.sum = (acc.sum + (ph * sh(vs, 7)) % P) % P
	end
end
local out = {}
local roots = { workspace, game.ReplicatedStorage, game.ServerStorage, game.ServerScriptService, game.StarterPlayer, game.StarterGui,
	game.ReplicatedFirst, game.Lighting, game.StarterPack, game:GetService("SoundService") }
local creatures = game.ReplicatedStorage:FindFirstChild("Shared") and game.ReplicatedStorage.Shared:FindFirstChild("Creatures")
for _, root in roots do
	for _, d in root:GetDescendants() do
		if d:IsA("LuaSourceContainer") then
			table.insert(out, string.format("S\t%s\t%s\t%d\t%d", d:GetFullName(), d.ClassName, #d.Source, hash(d.Source)))
			if d.Parent == creatures and d:IsA("ModuleScript") then
				local ok, data = pcall(require, d)
				local acc = { n = 0, sum = 0 }
				if ok and typeof(data) == "table" then
					walk(data, 7, acc)
				else
					acc.n = -1
				end
				table.insert(out, string.format("C\t%s\t%d\t%d", d.Name, acc.n, acc.sum))
			end
		end
		if string.sub(d.Name, 1, 2) == "ZZ" then
			table.insert(out, "Z\t" .. d:GetFullName())
		end
	end
end
-- switches: the checks put theirs on these three (the map's own are on ClaudeBlockout, Roblox's on Lighting)
for _, at in { workspace, game.ReplicatedStorage, game.ServerStorage } do
	for k, v in at:GetAttributes() do
		table.insert(out, "A\t" .. at.Name .. "." .. k .. " = " .. tostring(v))
	end
end
for _, c in game.ServerStorage:GetChildren() do
	table.insert(out, "X\tServerStorage." .. c.Name .. " (" .. c.ClassName .. ")")
end
local UIS = game:GetService("UserInputService")
table.insert(out, "E\t" .. tostring(game:GetService("RunService"):IsRunning()) .. "\t" .. tostring(UIS.MouseBehavior) .. "\t"
	.. tostring(workspace.CurrentCamera.CameraType))
return table.concat(out, "\n")
'''

RESET = r'''
local UserInputService = game:GetService("UserInputService")
task.delay(0.2, function()
	UserInputService.MouseBehavior = Enum.MouseBehavior.Default
	local cam = workspace.CurrentCamera
	if cam then
		cam.CameraType = Enum.CameraType.Fixed
	end
end)
task.wait(0.6)
return tostring(UserInputService.MouseBehavior) .. " " .. tostring(workspace.CurrentCamera.CameraType)
'''


def run(args, timeout=180):
    r = subprocess.run(["node", RUN, *args], capture_output=True, text=True, timeout=timeout)
    return (r.stdout + r.stderr).strip()


def edit(code):
    with tempfile.NamedTemporaryFile("w", suffix=".luau", delete=False) as f:
        f.write(code)
    try:
        return run([f.name])
    finally:
        os.unlink(f.name)


def lua(v):
    return "[==[" + str(v) + "]==]"


def _hash(b):
    v = 7
    for x in b:
        v = (v * 31 + x) % 4294967296
    return v


_P = 67108859


def _sh(s, hv):
    for x in s.encode("utf-8"):
        hv = (hv * 31 + x) % _P
    return hv


def _walk(v, ph, acc):
    if isinstance(v, dict):
        for k, c in v.items():
            _walk(c, _sh("." + k, ph), acc)
    elif isinstance(v, list):
        for i, c in enumerate(v):
            _walk(c, _sh("#%d" % (i + 1), ph), acc)
    elif v is not None:
        vs = ("true" if v else "false") if isinstance(v, bool) else ("%.6f" % v) if isinstance(v, (int, float)) else "s" + v
        acc[0] += 1
        acc[1] = (acc[1] + (ph * _sh(vs, 7)) % _P) % _P


def _literal(path, marker):
    """the source a loader file gives a script: the long string after `marker`"""
    src = (ROOT / path).read_text(encoding="utf-8")
    a = src.index("[==[", src.index(marker)) + 4
    return src[a:src.index("]==]", a)].encode("utf-8")


def place():
    """The place against the repo (see the top). Returns the number of problems."""
    sm = json.loads(subprocess.run([ROJO, "sourcemap", "default.project.json"], capture_output=True, text=True, cwd=ROOT).stdout)
    repo = {}

    def walk(node, path):
        name = path + [node["name"]]
        files = [f for f in node.get("filePaths", []) if f.endswith((".luau", ".lua"))]
        if node["className"] in ("Script", "LocalScript", "ModuleScript") and files:
            b = (ROOT / files[0]).read_bytes()
            repo[".".join(name[1:])] = (node["className"], len(b), _hash(b), files[0])
        for c in node.get("children", []):
            walk(c, name)

    walk(sm, [])
    data = {}
    for f in glob.glob(str(ROOT / "src/shared/Creatures/*.json")):
        acc = [0, 0]
        _walk(json.loads(Path(f).read_text(encoding="utf-8")), 7, acc)
        data[Path(f).stem] = tuple(acc)
    maps = {
        "Workspace.ClaudeBlockout.Surface.WaterLook": _literal("tools/studio/greybox/98_water.luau", 's.Name = "WaterLook"'),
        "Workspace.ClaudeBlockout.Dock.HubLife": _literal("tools/studio/greybox/97_hub.luau", 'life.Name = "HubLife"'),
    }
    said = edit(PLACE_READ)
    scripts, creatures, bad, edit_line = {}, {}, [], None
    for row in said.splitlines():
        p = row.split("\t")
        if p[0] == "S" and len(p) == 5:
            scripts[p[1]] = (p[2], int(p[3]), int(p[4]))
        elif p[0] == "C" and len(p) == 4:
            creatures[p[1]] = (int(p[2]), int(p[3]))
        elif p[0] == "Z":
            bad.append("a helper left in the place: " + p[1])
        elif p[0] == "A":
            bad.append("a switch left on: " + p[1])
        elif p[0] == "X":
            bad.append("left in ServerStorage: " + p[1])
        elif p[0] == "E":
            edit_line = p[1:]
    if not scripts or not edit_line:
        print("the place gave no answer (is Studio open, in Edit, the runner's plugin on?):", said[-300:])
        return 1
    same = datas = mapsame = 0
    for k, (cls, n, hv) in sorted(scripts.items()):
        name = k.split(".")[-1]
        if k in repo:
            if (cls, n, hv) == repo[k][:3]:
                same += 1
            else:
                bad.append(f"DIFFERENT from {repo[k][3]}: {k} (place {n} bytes, repo {repo[k][1]})")
        elif k in maps:
            if (n, hv) == (len(maps[k]), _hash(maps[k])):
                mapsame += 1
            else:
                bad.append(f"the map's script differs from its loader file: {k} (place {n} bytes, loader {len(maps[k])})")
        elif k == "ReplicatedStorage.Shared.Creatures." + name and name in data:
            if creatures.get(name) == data[name]:
                datas += 1
            else:
                bad.append(f"creature data differs from its json: {name} (place {creatures.get(name)}, repo {data[name]})")
        else:
            bad.append(f"a script that is not in the repo: {k} ({cls}, {n} bytes)")
    for k in sorted(repo):
        if k not in scripts:
            bad.append(f"missing in the place: {k} ({repo[k][3]})")
    for name in sorted(data):
        if "ReplicatedStorage.Shared.Creatures." + name not in scripts:
            bad.append(f"creature data missing in the place: {name}")
    if edit_line != ["false", "Enum.MouseBehavior.Default", "Enum.CameraType.Fixed"]:
        bad.append("not in Edit with the mouse free and the camera Fixed: " + " ".join(edit_line))
    print(f"place: {len(scripts)} scripts; {same} of the repo's {len(repo)} script files the same bytes, {datas} of {len(data)} creature "
          f"data the same contents, {mapsame} of 2 map scripts as their loader files; in Edit, mouse {edit_line[1]}, camera {edit_line[2]}")
    for b in bad:
        print("  ! " + b)
    print("place: " + ("all good" if not bad else f"{len(bad)} problem(s)"))
    return len(bad)


# ---------------------------------------------------------------------------------------------------------------------
# the playtest

def install(remove=False):
    return edit(f"""local sss = game:GetService("ServerScriptService")
local sps = game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts")
for _, at in {{ sss, sps }} do
	local old = at:FindFirstChild("{NAME}")
	if old then old:Destroy() end
end
workspace:SetAttribute("FullDo", nil)
game:GetService("ReplicatedStorage"):SetAttribute("FullCmd", nil)
if {"true" if remove else "false"} then
	return "removed"
end
local s = Instance.new("Script")
s.Name = "{NAME}"
s.Source = {lua(SERVER)}
s.Parent = sss
local c = Instance.new("LocalScript")
c.Name = "{NAME}"
c.Source = {lua(CLIENT)}
c.Parent = sps
return "installed " .. #s.Source .. " " .. #c.Source
""")


def cmd(what, arg="", wait=8.0):
    """a command to our own server Script in the playtest; its answer"""
    stamp = f"{what}|{arg}|{time.time()}"
    out = run(["--ctx", "server", "--code",
               f"local RS = game:GetService('ReplicatedStorage') local o = game:GetService('ServerStorage'):WaitForChild('ZZFullOut', 5) "
               f"if not o then return 'no helper' end RS:SetAttribute('FullCmd', {lua(stamp)}) local t = os.clock() "
               f"repeat task.wait(0.05) until string.sub(o.Value, 1, #{lua(stamp)}) == {lua(stamp)} or os.clock() - t > {wait} return o.Value"])
    at = out.find(stamp + "\n")
    if at < 0:
        raise SystemExit(f"no answer to {what}: {out[-400:]}")
    return json.JSONDecoder().raw_decode(out[at + len(stamp) + 1:])[0]


def do(what):
    run(["--ctx", "server", "--code", f"workspace:SetAttribute('FullDo', {lua(what + '|' + str(time.time()))}) return 'ok'"])


def until(test, seconds=6.0, every=0.3):
    """the state once `test` holds (or the last one read)"""
    end = time.time() + seconds
    while True:
        s = cmd("state")
        if test(s) or time.time() > end:
            return s
        time.sleep(every)


def events(since=0):
    """the client's lines from number `since` on, as (seconds, kind, rest)"""
    got = []
    for row in cmd("events").get("events", [])[since:]:
        p = row.split("|", 2)
        got.append((float(p[0]), p[1], p[2] if len(p) > 2 else ""))
    return got


def wait_event(since, test, seconds):
    """the client's lines from `since` on, once one of them passes `test` (or the time is up)"""
    end = time.time() + seconds
    while True:
        got = events(since)
        if any(test(e) for e in got) or time.time() > end:
            return got
        time.sleep(0.5)


def playing():
    try:
        return json.loads(run(["status"]))["connected"]["server"]
    except (ValueError, KeyError):
        return -1


def checks():
    OUT.mkdir(parents=True, exist_ok=True)
    lines, fails = [], []

    def say(text):
        lines.append(text)
        print(text, flush=True)

    def expect(name, ok, detail=""):
        say(("ok    " if ok else "FAIL  ") + name + (f"   [{detail}]" if detail else ""))
        if not ok:
            fails.append(name)

    def told(got):
        return "; ".join(f"{t:.1f} {k} {r}".strip() for t, k, r in got)

    say(time.strftime("full check, %Y-%m-%d %H:%M:%S") + ", git " + subprocess.run(["git", "rev-parse", "--short", "HEAD"], capture_output=True, text=True, cwd=ROOT).stdout.strip())
    # boot
    s = until(lambda s: s.get("plot") and s.get("state") == "Dock", 60, 1.0)
    expect("boot: a plot handed out, on the dock", bool(s.get("plot")) and s.get("state") == "Dock", f"{s.get('plot')} {s.get('state')}")
    got = wait_event(0, lambda e: e[1] == "ready", 30)
    ready = [e for e in got if e[1] == "ready"]
    expect("boot: the client is up", bool(ready), told(ready))
    rides = cmd("rides")
    good = [n for n in sorted(rides) if rides[n]["level"] == 1 and "ridefish/Trainer1/" in str(rides[n]["mesh"]) and rides[n]["meshes"] >= 5
            and not rides[n]["old"] and rides[n]["preview"] == 0]
    expect("boot: all 8 pens show the level 1 seahorse from its meshes, no old machine, no Edit preview", len(good) == 8 and len(rides) == 8,
           "" if len(good) == 8 else json.dumps({n: rides[n] for n in rides if n not in good}))

    # the seahorse
    cmd("far")
    time.sleep(0.6)
    cmd("near")
    s = until(lambda s: s.get("onRide"), 6)
    expect("seahorse: walking up seats you on your own pen's ride", s.get("onRide") == s.get("plot") and bool(s.get("welded")), f"{s.get('onRide')} welded {s.get('welded')}")
    until(lambda s: s.get("training"), 3)
    a = cmd("state")
    t0 = time.time()
    time.sleep(5)
    b = cmd("state")
    took = time.time() - t0
    each = a["each"]
    gained = (b["max"] or 0) - (a["max"] or 0)
    ticks = gained / each if each else 0
    expect(f"seahorse: seated, +{each} Oxygen once a second", bool(b.get("training")) and gained > 0 and gained % each == 0 and took - 1.6 <= ticks <= took + 0.6,
           f"{a['max']} to {b['max']} in {took:.1f} s: {ticks:g} ticks")
    do("off")
    s = until(lambda s: not s.get("onRide"), 6)
    time.sleep(1.2)
    a = cmd("state")
    time.sleep(2.5)
    b = cmd("state")
    expect("seahorse: getting off stops it", not s.get("onRide") and not b.get("training") and a["max"] == b["max"] and b.get("state") == "Dock",
           f"on {s.get('onRide')}, training {b.get('training')}, {a['max']} to {b['max']}, {b.get('state')}")

    # the sub trip: tier 1 to land 2, in by walking off the lip
    n0 = len(events())
    picked = cmd("sub", "1,2")
    expect("sub trip: sub 1 bought, equipped, land 2 picked (SubService's test door)", picked.get("Equip") == 1 and picked.get("Dest") == 2, json.dumps(picked))
    do("walk")
    got = wait_event(n0, lambda e: e[1] == "mode" and e[2].startswith("Carried>"), 60)
    if any(e[1] == "mode" and e[2].startswith("Carried>") for e in got):
        # the sub lets go at the drop and its phase ends Config.Sub.Drop (0.8 s) later: read on until it has, or
        # the phases stop at "Drop" whenever this read falls inside that time (h4, 2026-11-24: one run did)
        got = wait_event(n0, lambda e: e[1] == "sub" and e[2] == "nil", 5)
    phases = [e[2] for e in got if e[1] == "sub"]
    modes = [e[2].split("|")[0] for e in got if e[1] == "mode"]
    walked = [e for e in got if e[1] == "walk"]
    expect("sub trip: walking off the lip the sub takes you (Carried)", any(m.endswith(">Carried") for m in modes), told(walked) + " | " + " ".join(modes))
    order = [p for p in phases if p != "nil"]
    expect("sub trip: its phases run in order to the drop, and it lets you go", "Ride" in order and phases[-1:] == ["nil"] and any(m.startswith("Carried>") for m in modes),
           " ".join(phases) + " | " + " ".join(modes))
    time.sleep(2.5)
    n1 = len(events())
    before = cmd("state")
    cmd("home")
    got = wait_event(n1, lambda e: e[1] == "great" and e[2].startswith("shown"), 10)
    s = cmd("state")
    shown = [e for e in got if e[1] == "great" and e[2].startswith("shown")]
    black = [e for e in events(n0) if e[1] == "black"]
    expect("sub trip: sent home off it, no black, GREAT DIVE comes up", s.get("state") == "Dock" and bool(shown) and not black,
           f"from {before.get('state')} at {before.get('root')}; " + told(got))
    back = cmd("subhome")
    expect("sub trip: the sub put away again", back.get("Equip") == 0 and back.get("Dest") == 0, json.dumps(back))
    wait_event(n1, lambda e: e[1] == "great" and e[2].startswith("closed"), 12)
    time.sleep(1.0)

    # the dive, with no sub: off the lip, onto a fish
    n2 = len(events())
    do("walk")
    got = wait_event(n2, lambda e: e[1] == "mode" and e[2].split("|")[0].endswith(">Riding"), 30)
    modes = [e[2].split("|")[0] for e in got if e[1] == "mode"]
    s = cmd("state")
    expect("dive: off the lip into the water and onto a fish (Riding)", s.get("state") == "Riding" and any(m.endswith(">Riding") for m in modes),
           f"{s.get('state')} at {s.get('root')}, Dive.Leap {s.get('leap')}; " + " ".join(modes))
    time.sleep(3.0)
    s = cmd("state")
    expect("dive: still riding three seconds on", s.get("state") == "Riding", f"{s.get('state')} at {s.get('root')}")

    # the fail, on real time
    n3 = len(events())
    failed = cmd("fail")
    expect("fail: forced from the fish (as out of Oxygen)", failed.get("failed") is True, json.dumps(failed))
    got = wait_event(n3, lambda e: e[1] == "great" and e[2].startswith("shown"), 40)
    s = cmd("state")
    modes = [e for e in got if e[1] == "mode"]
    words = [e[2] for e in got if e[1] == "words" and e[2] != "-"]
    whole = [e for e in got if e[1] == "black" and e[2].startswith("whole")]
    gone = [e for e in got if e[1] == "black" and e[2].startswith("gone")]
    docked = [e for e in modes if e[2].split("|")[0].endswith(">Dock")]
    shown = [e for e in got if e[1] == "great" and e[2].startswith("shown")]
    say("      the fail as the client saw it: " + told(got))
    expect("fail: the fail plays and takes you home", s.get("state") == "Dock" and bool(docked) and len(modes) >= 2, " ".join(e[2].split("|")[0] for e in modes))
    expect("fail: its words come up", bool(words), " ".join(words))

    def field(text, key):
        for part in text.replace("|", " ").split():
            if part.startswith(key + "="):
                return part[len(key) + 1:]
        return ""

    over = whole and field(whole[0][2], "order").isdigit() and field(whole[0][2], "hud").isdigit() and int(field(whole[0][2], "order")) > int(field(whole[0][2], "hud"))
    expect("fail: the black goes whole, drawn over the HUD", bool(over), whole[0][2] if whole else "no black")
    fade = float(field(docked[0][2], "fade") or -1) if docked else -1
    expect("fail: home with the black still up (the HUD is under it)", fade >= 0.5, f"fade {fade:g} as the mode turned Dock" + (": " + docked[0][2] if docked else ""))
    late = bool(shown and gone) and gone[0][0] <= shown[0][0] and float(field(shown[0][2], "fade") or 9) <= 0.02
    expect("fail: GREAT DIVE comes up only once the black is gone", late,
           (f"black gone at {gone[0][0]:.2f}, " if gone else "the black never went, ") + (f"shown at {shown[0][0]:.2f} {shown[0][2]}" if shown else "never shown"))
    if docked and gone:
        say(f"      the black lifted {gone[0][0] - docked[0][0]:.2f} s after home (Config.Death: HoldBlack + FadeIn = 1.3)")
    time.sleep(4)

    # the logs, from boot on
    logs = cmd("logs", "", 12)
    for side in ("server", "client"):
        rows = logs.get(side) or []
        errors = [r for r in rows if r.startswith("MessageError")]
        warnings = [r for r in rows if not r.startswith("MessageError")]
        ours = [w for w in warnings if "[TrainService]" in w or "[Trainer]" in w]
        other = [w for w in warnings if not any(k in w for k in KNOWN)]
        expect(f"no errors on the {side}", not errors, " || ".join(errors[:6]))
        expect(f"no warning from the trainer on the {side}", not ours, " || ".join(ours[:4]))
        say(f"      {side}: {len(warnings)} warning(s), {len(warnings) - len(other)} of them the known asset one" + ("".join("\n        " + w for w in other[:12])))
    s = cmd("state")
    expect("at the end: on the dock, no sub equipped", s.get("state") == "Dock" and not s.get("equip"), f"{s.get('state')} equip {s.get('equip')}")
    say(f"{len(fails)} failed" if fails else "all good")
    (OUT / "run.log").write_text("\n".join(lines) + "\n")
    print(OUT / "run.log")
    return len(fails)


def everything():
    """place, install, Play, run, stop, remove, the mouse and camera, place again. Returns the number of problems."""
    if playing() != 0:
        print("a playtest is up (or the runner gave no status): not started")
        return 1
    bad = place()
    print(install())
    print(run(["play"]).splitlines()[-1:])
    for _ in range(60):
        time.sleep(2)
        if playing() == 1:
            break
    else:
        print("the playtest did not come up")
        return bad + 1
    time.sleep(8)
    try:
        bad += checks()
    finally:
        print(run(["stop"]).splitlines()[-1:])
        for _ in range(40):
            time.sleep(2)
            if playing() == 0:
                break
        time.sleep(6)
        print(install(remove=True))
        print("mouse and camera:", edit(RESET).splitlines()[-1:])
    bad += place()
    return bad


if __name__ == "__main__":
    what = sys.argv[1] if len(sys.argv) > 1 else ""
    if what == "place":
        sys.exit(1 if place() else 0)
    elif what == "install":
        print(install())
    elif what == "remove":
        print(install(remove=True))
        print("mouse and camera:", edit(RESET).splitlines()[-1:])
    elif what == "run":
        sys.exit(1 if checks() else 0)
    elif what == "all":
        sys.exit(1 if everything() else 0)
    else:
        print(__doc__)
