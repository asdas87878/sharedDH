"""The hub's leaderboards (docs/design/leaderboards.md), checked in one Studio playtest on Hugo's PC (studio-runner).
NULLROOM s1, 2026-11-25.
IT MOVES THE PLAYER, GIVES THEM FISH AND HOLDS THE CAMERA: only in a playtest you started, with nobody playing in it.
    python tools/studio/boards_check.py install            (in Edit, before Play: a Script, a LocalScript)
    node ~/Projects/studio-runner/studio-run.mjs play
    python tools/studio/boards_check.py run                (the checks; exit code 1 on a miss)
    python tools/studio/boards_check.py shots              (the stills, to work/boards/)
    python tools/studio/boards_check.py do VERB [A] | cmd VERB [A]
    node ~/Projects/studio-runner/studio-run.mjs stop
    python tools/studio/boards_check.py remove             (in Edit, after the stop)
What it can't do: turn a real mouse wheel or move a finger (a script may not). It scrolls by CanvasPosition and reads
what a finger's ray would hit on the way to the list.
"""
import json
import os
import subprocess
import sys
import tempfile
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
RUN = str(Path.home() / "Projects/studio-runner/studio-run.mjs")
NAME = "ZZBoards"
OUT = ROOT / "work/boards"
OUT.mkdir(parents=True, exist_ok=True)

SERVER = r'''
local RS = game:GetService("ReplicatedStorage")
local SS = game:GetService("ServerStorage")
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local LogService = game:GetService("LogService")
local Services = game:GetService("ServerScriptService"):WaitForChild("Server"):WaitForChild("Services")
local RideService = require(Services:WaitForChild("RideService"))
local AquariumService = require(Services:WaitForChild("AquariumService"))
local IndexService = require(Services:WaitForChild("IndexService"))
local LeaderboardService = require(Services:WaitForChild("LeaderboardService"))
local Net = require(RS:WaitForChild("Shared"):WaitForChild("Net"))
local report = Instance.new("RemoteEvent")
report.Name = "ZZBoardsReport"
report.Parent = RS
local out = Instance.new("StringValue")
out.Name = "ZZBoardsOut"
out.Parent = SS
local said = Instance.new("StringValue")
said.Name = "ZZBoardsSaid"
said.Parent = SS
local heard = {}
report.OnServerEvent:Connect(function(_, kind, text)
	if kind == "log" then
		if #heard < 200 then table.insert(heard, tostring(text)) end
	else
		said.Value = tostring(kind) .. "\n" .. tostring(text)
	end
end)
-- made-up lists: n rows each, the player somewhere in them (test data: the ids are Roblox's own oldest accounts)
local IDS = { 1, 156, 261, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28 }
local faking = 0
local function fake(player, n)
	local boards = {}
	for b, id in { "Oxygen", "Collectors", "Earners" } do
		local rows = {}
		for i = 1, n do
			local mine = i == 3 + b
			local value = if id == "Oxygen" then math.floor(4.2e9 / i ^ 2.4) elseif id == "Collectors" then 320 - i * 9 else math.floor(88000000 / i ^ 3) / 10
			table.insert(rows, {
				Id = if mine then player.UserId else IDS[(i - 1) % #IDS + 1],
				Name = if mine then player.DisplayName elseif i % 5 == 2 then "AVeryLongTestName2026" else "Test diver " .. i,
				User = if mine then player.Name else "testdiver_" .. i,
				Value = value,
				Rank = if i == 6 then 5 else i, -- (a shared place)
			})
		end
		table.insert(boards, { Id = id, Global = b == 2, Rows = rows })
	end
	Net.Folder.Boards:FireClient(player, "State", { Next = workspace:GetServerTimeNow() + 42, Boards = boards })
end
local function answer(player, what, arg)
	local character = player and player.Character
	if what == "logs" then
		local server = {}
		for _, m in LogService:GetLogHistory() do
			if m.messageType == Enum.MessageType.MessageWarning or m.messageType == Enum.MessageType.MessageError then
				table.insert(server, m.messageType.Name .. ": " .. string.sub(m.message, 1, 300))
			end
		end
		return { server = server, client = heard }
	elseif what == "state" then
		local attrs = {}
		for k, v in player:GetAttributes() do
			if string.sub(k, 1, 5) == "Board" or k == "MaxOxygen" or k == "Income" or k == "IndexFound" or k == "Mode" then attrs[k] = v end
		end
		local stations = {}
		for _, s in workspace.ClaudeBlockout.Dock.Stations:GetChildren() do table.insert(stations, s.Name) end
		local looks = 0
		for _, n in IndexService.foundOf(player) or {} do looks += n end
		local sent = LeaderboardService.Test.state()
		return { attrs = attrs, stations = stations, old = SS:FindFirstChild("Earners") ~= nil, looks = looks, id = player.UserId, name = player.Name,
			sent = sent and sent.Boards, left = sent and sent.Next - workspace:GetServerTimeNow(), pos = character and { character:GetPivot().X, character:GetPivot().Y, character:GetPivot().Z } }
	elseif what == "give" then
		local a = HttpService:JSONDecode(arg)
		return { ok = AquariumService.give(player, a[1], a[2]) }
	elseif what == "hand" then
		return { ok = RideService.giveCarried(player, { Id = arg, Size = "Normal", Variant = "" }) }
	elseif what == "train" then
		return { ok = RideService.train(player, tonumber(arg)) }
	elseif what == "at" then
		local x, y, z = string.match(arg, "([^,]+),([^,]+),([^,]+)")
		character:PivotTo(CFrame.new(tonumber(x), tonumber(y), tonumber(z)))
		return { ok = true }
	elseif what == "look" then -- the service's own turn, now
		LeaderboardService.Test.step()
		return { ok = true }
	elseif what == "fake" then -- n rows on every board, sent again each half second till "fake 0"
		faking += 1
		local now, n = faking, tonumber(arg)
		if n > 0 then
			task.spawn(function()
				while faking == now and player.Parent do
					fake(player, n)
					task.wait(0.5)
				end
			end)
		else
			Net.Folder.Boards:FireClient(player, "State", LeaderboardService.Test.state())
		end
		return { ok = true }
	elseif what == "config" then
		local k, v = string.match(arg, "([^=]+)=(.*)")
		require(RS.Shared.Config).Boards[k] = tonumber(v)
		return { ok = true }
	end
	return { error = "no such command" }
end
RS:GetAttributeChangedSignal("BoardsCmd"):Connect(function()
	local c = RS:GetAttribute("BoardsCmd")
	if type(c) ~= "string" then return end
	local what, arg = string.match(c, "^([^|]*)|([^|]*)|")
	local player = Players:GetPlayers()[1]
	local ok, got = pcall(answer, player, what, arg)
	out.Value = c .. "\n" .. HttpService:JSONEncode(if ok then got else { error = tostring(got) })
end)
'''

CLIENT = r'''
local RS = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local LogService = game:GetService("LogService")
local HttpService = game:GetService("HttpService")
local report = RS:WaitForChild("ZZBoardsReport")
local player = Players.LocalPlayer
local gui = player:WaitForChild("PlayerGui")
local sent = 0
local function log(message, kind)
	if (kind == Enum.MessageType.MessageWarning or kind == Enum.MessageType.MessageError) and sent < 150 then
		sent += 1
		report:FireServer("log", kind.Name .. ": " .. string.sub(message, 1, 300))
	end
end
for _, m in LogService:GetLogHistory() do log(m.message, m.messageType) end
LogService.MessageOut:Connect(log)
local Client = player:WaitForChild("PlayerScripts"):WaitForChild("Client")
local State = require(Client:WaitForChild("Lib"):WaitForChild("State"))
local BoardController = require(Client:WaitForChild("Controllers"):WaitForChild("BoardController"))
local Config = require(RS:WaitForChild("Shared"):WaitForChild("Config"))
local held, hidden = nil, {}
RunService:BindToRenderStep("ZZBoardsCam", Enum.RenderPriority.Last.Value + 10, function()
	if held then
		local cam = workspace.CurrentCamera
		cam.CameraType = Enum.CameraType.Scriptable
		cam.CFrame = held[1]
		cam.FieldOfView = held[2]
	end
end)
local function shownOf(id)
	for _, s in BoardController.Test.shown() do
		if s.Def.Id == id then return s end
	end
	error("no board " .. tostring(id))
end
local function v3(v) return { v.X, v.Y, v.Z } end
local verbs = {}
function verbs.ping() return "pong " .. State.Mode end
function verbs.cam(a) -- "x,y,z,tx,ty,tz,fov" | "off"
	if a == "off" then
		held = nil
		workspace.CurrentCamera.CameraType = Enum.CameraType.Custom
		workspace.CurrentCamera.FieldOfView = 70
		return "off"
	end
	local n = string.split(a, ",")
	for i, v in n do n[i] = tonumber(v) end
	held = { CFrame.lookAt(Vector3.new(n[1], n[2], n[3]), Vector3.new(n[4], n[5], n[6])), n[7] or 70 }
	return "held"
end
function verbs.turn(a) -- the game's own camera, turned to look the way of x,y,z from the player
	local n = string.split(a, ",")
	local cam = workspace.CurrentCamera
	local focus = cam.Focus.Position
	local back = (cam.CFrame.Position - focus).Magnitude
	local d = (Vector3.new(tonumber(n[1]), tonumber(n[2]), tonumber(n[3])) - focus).Unit
	cam.CFrame = CFrame.lookAt(focus - d * back, focus)
	return cam.CameraType.Name .. string.format(" back %.1f at %.0f,%.0f,%.0f", back, cam.CFrame.X, cam.CFrame.Y, cam.CFrame.Z)
end
function verbs.hud(a) -- the screen's windows off or on
	if a == "off" then
		for _, g in gui:GetChildren() do
			if g:IsA("ScreenGui") and g.Enabled then g.Enabled = false table.insert(hidden, g) end
		end
	else
		for _, g in hidden do g.Enabled = true end
		hidden = {}
	end
	return a
end
function verbs.row() -- the wall, as it is in the world
	local folder = workspace:FindFirstChild("Boards")
	local row = folder and folder:FindFirstChild("Row")
	if not row then return HttpService:JSONEncode({ none = true }) end
	local out = { parts = 0, lights = 0, guis = 0, glasses = {}, solids = {}, shadow = 0, touch = 0 }
	for _, p in row:GetDescendants() do
		if p:IsA("BasePart") then
			out.parts += 1
			if p.CastShadow then out.shadow += 1 end
			if p.CanTouch then out.touch += 1 end
			if string.sub(p.Name, 1, 5) == "Glass" then
				table.insert(out.glasses, { name = p.Name, pos = v3(p.Position), right = v3(p.CFrame.RightVector), face = v3(-p.CFrame.LookVector), up = v3(p.CFrame.UpVector), size = v3(p.Size) })
			elseif p.Name == "Solid" then
				table.insert(out.solids, { pos = v3(p.Position), size = v3(p.Size), query = p.CanQuery })
			end
		elseif p:IsA("Light") then out.lights += 1 end
	end
	for _, g in gui:GetChildren() do if g:IsA("SurfaceGui") and string.sub(g.Name, 1, 5) == "Board" then out.guis += 1 end end
	return HttpService:JSONEncode(out)
end
function verbs.list(a) -- what a board says
	local p = shownOf(a).Panel
	local rows = {}
	for _, l in p.Lines do
		if l.Frame.Visible then
			table.insert(rows, { y = l.Frame.Position.Y.Offset, rank = l.Rank.Text, name = l.Name.Text, user = l.User.Text, value = l.Value.Text, unit = l.Unit.Text,
				face = l.Face.IsLoaded, image = l.Face.Image, fits = l.Name.TextFits and l.Value.TextFits and l.Rank.TextFits, nameSize = l.Name.TextBounds.Y, valueSize = l.Value.TextBounds.Y })
		end
	end
	table.sort(rows, function(x, y) return x.y < y.y end)
	local titles = {}
	for _, d in p.Gui:GetDescendants() do
		if d:IsA("TextLabel") and (d.Name == "Title" or d.Name == "Small") then
			table.insert(titles, { name = d.Name, text = d.Text, fits = d.TextFits, w = d.TextBounds.X, h = d.TextBounds.Y })
		end
	end
	return HttpService:JSONEncode({ rows = rows, who = p.Who.Text, own = p.Own.Text, next = p.Next.Text, near = p.Near, empty = p.Empty.Visible and p.Empty.Text,
		scrolling = p.List.ScrollingEnabled, active = p.List.Active, guiActive = p.Gui.Active, bar = p.List.ScrollBarThickness, y = p.List.CanvasPosition.Y,
		most = p.List.AbsoluteCanvasSize.Y - p.List.AbsoluteWindowSize.Y, window = p.List.AbsoluteWindowSize.Y, total = #p.Rows, titles = titles })
end
function verbs.scroll(a)
	local id, y = string.match(a, "(%a+),(%-?[%d%.]+)")
	local p = shownOf(id).Panel
	p.List.CanvasPosition = Vector2.new(0, tonumber(y))
	RunService.RenderStepped:Wait()
	return string.format("%.0f", p.List.CanvasPosition.Y)
end
function verbs.ray(a) -- what a finger's ray to the middle, the top and the foot of a list hits, from x,y,z
	local id, x, y, z = string.match(a, "(%a+),([^,]+),([^,]+),([^,]+)")
	local glass = shownOf(id).Panel.Gui.Adornee
	local from = Vector3.new(tonumber(x), tonumber(y), tonumber(z))
	local out = {}
	local params = RaycastParams.new()
	params.FilterDescendantsInstances = { player.Character }
	for _, at in { 0, 0.3, -0.3 } do
		for _, side in { 0, 0.45, -0.45 } do
			local to = glass.CFrame * Vector3.new(side * glass.Size.X, at * glass.Size.Y, 0)
			local hit = workspace:Raycast(from, (to - from).Unit * 200, params)
			table.insert(out, if hit then hit.Instance.Name else "nothing")
		end
	end
	return table.concat(out, " ")
end
function verbs.walk(a)
	local x, z, most = string.match(a, "([^,]+),([^,]+),?(.*)")
	x, z = tonumber(x), tonumber(z)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid then return "no body" end
	local controls = require(player.PlayerScripts:WaitForChild("PlayerModule", 5)):GetControls()
	controls:Disable()
	local from = os.clock()
	local d = Vector3.new(x - root.Position.X, 0, z - root.Position.Z)
	while os.clock() - from < (tonumber(most) or 10) and d.Magnitude > 1 and root.Parent do
		humanoid:Move(d.Unit)
		RunService.RenderStepped:Wait()
		d = Vector3.new(x - root.Position.X, 0, z - root.Position.Z)
	end
	humanoid:Move(Vector3.zero)
	controls:Enable()
	return string.format("%.2f,%.2f,%.2f", root.Position.X, root.Position.Y, root.Position.Z)
end
function verbs.fps(a)
	local n, from, worst = 0, os.clock(), 0
	local last = from
	while os.clock() - from < (tonumber(a) or 3) do
		RunService.RenderStepped:Wait()
		local now = os.clock()
		worst = math.max(worst, now - last)
		last = now
		n += 1
	end
	return string.format("%.1f a second, worst frame %.0f ms", n / (os.clock() - from), worst * 1000)
end
function verbs.config(a)
	local k, v = string.match(a, "([^=]+)=(.*)")
	Config.Boards[k] = tonumber(v)
	return "set"
end
function verbs.scale(a) -- how big a board's title is drawn on the screen now, pixels
	local out = {}
	for _, s in BoardController.Test.shown() do
		local g = s.Panel.Gui.Adornee
		local cam = workspace.CurrentCamera
		local l = cam:WorldToViewportPoint((g.CFrame * CFrame.new(-g.Size.X / 2, 0, 0)).Position)
		local r = cam:WorldToViewportPoint((g.CFrame * CFrame.new(g.Size.X / 2, 0, 0)).Position)
		table.insert(out, string.format("%s %.0f..%.0f", s.Def.Id, l.X, r.X))
	end
	return table.concat(out, " ") .. " of " .. tostring(workspace.CurrentCamera.ViewportSize)
end
workspace:GetAttributeChangedSignal("BoardsDo"):Connect(function()
	local stamp = tostring(workspace:GetAttribute("BoardsDo"))
	local what, arg = string.match(stamp, "^([^|]*)|([^|]*)|")
	if not what then return end
	task.spawn(function()
		local f = verbs[what]
		local ok, got = pcall(f or function() return "no such verb" end, arg)
		report:FireServer(stamp, tostring(got))
	end)
end)
'''

RESET = r'''
local U = game:GetService("UserInputService")
task.delay(0.2, function()
	U.MouseBehavior = Enum.MouseBehavior.Default
	if workspace.CurrentCamera then workspace.CurrentCamera.CameraType = Enum.CameraType.Fixed end
end)
task.wait(0.6)
return tostring(U.MouseBehavior) .. " " .. tostring(workspace.CurrentCamera.CameraType)
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


def install(remove=False):
    return edit(f"""local sss = game:GetService("ServerScriptService")
local sps = game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts")
for _, at in {{ sss, sps }} do
	local old = at:FindFirstChild("{NAME}")
	if old then old:Destroy() end
end
workspace:SetAttribute("BoardsDo", nil)
game:GetService("ReplicatedStorage"):SetAttribute("BoardsCmd", nil)
if {"true" if remove else "false"} then return "removed" end
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
    """a command to our own server Script; its answer"""
    if not isinstance(arg, str):
        arg = json.dumps(arg)
    stamp = f"{what}|{arg}|{time.time()}"
    out = run(["--ctx", "server", "--code",
               f"local RS = game:GetService('ReplicatedStorage') local o = game:GetService('ServerStorage'):WaitForChild('ZZBoardsOut', 5) "
               f"if not o then return 'no helper' end RS:SetAttribute('BoardsCmd', {lua(stamp)}) local t = os.clock() "
               f"repeat task.wait(0.05) until string.sub(o.Value, 1, #{lua(stamp)}) == {lua(stamp)} or os.clock() - t > {wait} return o.Value"])
    at = out.find(stamp + "\n")
    if at < 0:
        raise SystemExit(f"no answer to {what}: {out[-400:]}")
    return json.JSONDecoder().raw_decode(out[at + len(stamp) + 1:])[0]


def do(what, arg="", wait=8.0):
    """a verb on the player's own machine; what it said"""
    if not isinstance(arg, str):
        arg = json.dumps(arg)
    stamp = f"{what}|{arg}|{time.time()}"
    out = run(["--ctx", "server", "--code",
               f"local o = game:GetService('ServerStorage'):WaitForChild('ZZBoardsSaid', 5) if not o then return 'no helper' end "
               f"workspace:SetAttribute('BoardsDo', {lua(stamp)}) local t = os.clock() "
               f"repeat task.wait(0.05) until string.sub(o.Value, 1, #{lua(stamp)}) == {lua(stamp)} or os.clock() - t > {wait} return o.Value"])
    at = out.find(stamp + "\n")
    if at < 0:
        return "no answer: " + out[-300:]
    return out[at + len(stamp) + 1:].strip()




class Log:
    def __init__(self, name):
        self.lines, self.fails, self.file = [], [], OUT / f"{name}.log"
        self.say(f"{name}, {time.strftime('%Y-%m-%d %H:%M:%S')}")

    def say(self, text):
        self.lines.append(text)
        print(text, flush=True)

    def expect(self, name, ok, detail=""):
        self.say(("ok    " if ok else "FAIL  ") + name + (f"   [{detail}]" if detail != "" else ""))
        if not ok:
            self.fails.append(name)

    def end(self):
        self.say(f"{len(self.fails)} failed" if self.fails else "all good")
        self.file.write_text("\n".join(self.lines) + "\n")
        print(self.file)
        return len(self.fails)


IDS = ("Oxygen", "Collectors", "Earners")
X, Z, EYE = 2922.0, -39.0, 13.0  # the row's middle, and a reader's eye as the dock's camera has it


def board(i):
    return json.loads(do("list", i))


def checks():
    log = Log("run")
    until = time.time() + 40
    while time.time() < until and not do("ping").startswith("pong"):
        time.sleep(1)
    time.sleep(8)
    # the wall
    row = json.loads(do("row"))
    g = sorted(row.get("glasses", []), key=lambda v: -v["pos"][0])
    log.expect("three boards stand", [v["name"] for v in g] == ["GlassOxygen", "GlassCollectors", "GlassEarners"], str([v["name"] for v in g]))
    log.expect("in one plane and at one height", all(abs(v["pos"][k] - g[0]["pos"][k]) < 0.001 for v in g for k in (1, 2)), str([v["pos"] for v in g]))
    log.expect("none turned, all square to the hub", all(abs(v["face"][2] + 1) < 1e-5 and abs(v["up"][1] - 1) < 1e-5 for v in g), str([v["face"] for v in g]))
    steps = [round(g[i]["pos"][0] - g[i + 1]["pos"][0], 3) for i in range(2)]
    log.expect("12.9 studs apart", steps == [12.9, 12.9], str(steps))
    log.expect("212 pieces and the glasses and blocks, 4 lights, 3 lists, no shadows, nothing that touches",
               row["lights"] == 4 and row["guis"] == 3 and row["shadow"] == 0 and row["touch"] == 0, f"{row['parts']} parts, {row['lights']} lights")
    st = cmd("state")
    log.expect("the blank Earners slate is out of the running game", "Earners" not in st["stations"] and st["old"], str(st["stations"]))
    # the lists as they are
    time.sleep(6)

    def real(when):
        st = cmd("state")
        for i in IDS:
            b = board(i)
            log.expect(f"{i}, {when}: one row, the player's own, under THIS SERVER",
                       len(b["rows"]) == 1 and b["rows"][0]["user"] == "@" + st["name"] and b["who"] == "THIS SERVER" and not b["empty"],
                       json.dumps(b["rows"]) + " " + b["own"] + " | " + b["next"])
            if b["rows"]:
                log.expect(f"{i}, {when}: the row and the foot read the same", b["own"].replace(" ", "") == f"YOU#1{b['rows'][0]['value']}", b["own"])
        return st

    st = real("at first")
    log.expect("Oxygen is the server's max Oxygen", st["attrs"].get("BoardOxygen") == st["attrs"].get("MaxOxygen"), str(st["attrs"]))
    before = st["attrs"]
    log.say("train " + str(cmd("train", "54321")) + " give " + str(cmd("give", [100000, [["Clownfish", "Big", "Gold"], ["ReefShark", "Normal", ""]]])) +
            " hand " + str(cmd("hand", "YellowTang")))
    time.sleep(13)
    st = real("after training, two tank fish and one in the hands")
    a = st["attrs"]
    log.expect("each number grew", a["BoardOxygen"] > before["BoardOxygen"], f"{before} -> {a}")
    log.expect("Earners is the tank's coins a second", a.get("BoardEarners") == a.get("Income") and a.get("Income", 0) >= 0, str(a))
    log.expect("Collectors is the Index's looks", a.get("BoardCollectors") == st["looks"], f"{a.get('BoardCollectors')} of {st['looks']}")
    for i in IDS:
        for t in board(i)["titles"]:
            log.expect(f"{i}: {t['text']} fits its box", t["fits"] and t["h"] > 20, str(t))
    # full lists
    cmd("fake", "25")
    cmd("at", f"{X},4,{Z - 62}")
    time.sleep(3)
    for i in IDS:
        b = board(i)
        log.expect(f"{i}, 25 on the list, read from 62 studs: 8 rows or 9 written, no scrolling", 8 <= len(b["rows"]) <= 10 and not b["scrolling"] and b["total"] == 25 and b["bar"] == 0,
                   f"{len(b['rows'])} rows, near {b['near']}")
        log.expect(f"{i}: every name and number fits", all(r["fits"] for r in b["rows"]), str([r["name"] for r in b["rows"] if not r["fits"]]))
        log.expect(f"{i}: the faces came", sum(r["face"] and r["image"] != "" for r in b["rows"]) >= 7, str([(r["name"], r["face"]) for r in b["rows"] if not r["face"]]))
    cmd("at", f"{X},4,{Z - 16}")
    time.sleep(3)
    for i in IDS:
        b = board(i)
        log.expect(f"{i}, from 16 studs: can be scrolled", b["near"] and b["scrolling"] and b["active"] and b["guiActive"] and b["bar"] == 6 and b["most"] > 100,
                   f"{b['total']} rows, {b['window']:.0f} px of {b['most']:.0f} more")
        for y in (0, 34, 68, 500, b["most"] / 2, b["most"], 99999):
            do("scroll", f"{i},{y}")
            c = board(i)
            top, foot = c["y"], c["y"] + c["window"]
            seen = [r for r in c["rows"] if r["y"] + 62 > top and r["y"] < foot]
            gaps = [seen[k + 1]["y"] - seen[k]["y"] for k in range(len(seen) - 1)]
            whole = bool(seen) and seen[0]["y"] <= top + 9 and seen[-1]["y"] + 62 >= foot - 9 and all(abs(d - 68) < 0.5 for d in gaps)
            ranks = [int(r["rank"]) for r in seen]
            log.expect(f"{i} scrolled to {y:.0f}: the rows that show are written, in order, no gap", whole and ranks == sorted(ranks), f"at {top:.0f}, places {ranks}")
        end = board(i)
        log.expect(f"{i}: the last place (25) can be reached", end["rows"][-1]["rank"] == "25" and abs(end["y"] - end["most"]) < 1.5, f"{end['y']:.0f} of {end['most']:.0f}")
        time.sleep(1.4)
        log.expect(f"{i}: a new list does not throw the reader back", abs(board(i)["y"] - end["y"]) < 1, str(board(i)["y"]))
        hits = do("ray", f"{i},{X},{EYE},{Z - 30}")
        log.expect(f"{i}: a finger's ray finds the list, nothing unseen in front of it", set(hits.split()) == {"Glass" + i}, hits)
    cmd("at", f"{X},4,{Z - 45}")
    time.sleep(2.5)
    log.expect("walked off: back at the top, no scrolling", all(board(i)["y"] == 0 and not board(i)["scrolling"] for i in IDS))
    cmd("fake", "5")
    cmd("at", f"{X},4,{Z - 16}")
    time.sleep(2.5)
    log.expect("5 on the list: nothing to scroll, near or not", all(not board(i)["scrolling"] and len(board(i)["rows"]) == 5 for i in IDS))
    cmd("fake", "0")
    time.sleep(1.5)
    real("the server's own list again")
    # players stop at it
    for x, name in ((X + 12.9, "Oxygen"), (X + 6.45, "the joint"), (X, "Collectors"), (X - 6.45, "the second joint"), (X - 12.9, "Earners")):
        cmd("at", f"{x},4,{Z - 14}")
        time.sleep(0.8)
        at = do("walk", f"{x},{Z + 8},3")
        try:
            z = float(at.split(",")[2])
        except (IndexError, ValueError):
            z = 999
        log.expect(f"walking into {name}: stopped in front", Z - 6 < z < Z - 0.9, at)
    cmd("at", f"{X},4,{Z - 30}")
    log.say("frames, 30 studs in front: " + do("fps", "4"))
    logs = cmd("logs")
    for side in ("server", "client"):
        bad = [r for r in logs[side] if r.startswith("MessageError")]
        log.expect(f"no errors on the {side}", not bad, " || ".join(bad[:4]))
        ours = [r for r in logs[side] if "Board" in r or "Infinite yield" in r]
        log.expect(f"no warning of the boards on the {side}", not ours, " || ".join(ours[:4]))
        log.say(f"{side} warnings: " + (" || ".join(sorted(set(r[:120] for r in logs[side]))) or "none"))
    return log.end()


def shot(name):
    path = OUT / f"{name}.png"
    path.unlink(missing_ok=True)
    run(["shot", str(path)])
    until, size = time.time() + 10, -1
    while time.time() < until:
        now = path.stat().st_size if path.exists() else 0
        if now > 0 and now == size:
            break
        size = now
        time.sleep(0.3)
    print(path, size, flush=True)


# where the camera stands and looks, against the row's middle: right of a reader is -x, the hub is -z
VIEWS = {
    "front": (0, 14, -40, 0, 13, 0, 50),
    "left45": (30, 12, -30, 0, 13, 0, 55),
    "right45": (-30, 12, -30, 0, 13, 0, 55),
    "left70": (38, 10, -14, 0, 12, 0, 60),
    "right70": (-38, 10, -14, 0, 12, 0, 60),
    "joint1": (6.45, 13, -15, 6.45, 13, 0, 70),
    "joint2": (-6.45, 13, -15, -6.45, 13, 0, 70),
    "joint1left": (18, 13, -11, 6.45, 13, 0, 70),
    "joint2right": (-18, 13, -11, -6.45, 13, 0, 70),
    "foot": (6, 4, -14, 0, 2, 0, 70),
    "above": (0, 40, -24, 0, 22, 0, 60),
    "far": (40, 14, -130, 0, 12, 0, 50),
    "behind": (0, 14, 34, 0, 13, 0, 60),
}


def shots(names):
    cmd("fake", "25")
    cmd("at", f"{X + 40},4,{Z - 60}")
    do("hud", "off")
    time.sleep(3)
    for n in names or VIEWS:
        v = VIEWS[n]
        do("cam", f"{X + v[0]},{v[1]},{Z + v[2]},{X + v[3]},{v[4]},{Z + v[5]},{v[6]}")
        time.sleep(1.2)
        shot(n)
    do("cam", "off")
    do("hud", "on")
    cmd("fake", "0")


if __name__ == "__main__":
    what = sys.argv[1] if len(sys.argv) > 1 else ""
    if what == "install":
        print(install())
    elif what == "remove":
        print(install(True))
        print(edit(RESET))
    elif what == "run":
        sys.exit(1 if checks() else 0)
    elif what == "shots":
        shots(sys.argv[2:])
    elif what == "shot":
        shot(sys.argv[2])
    elif what == "do":
        print(do(sys.argv[2], sys.argv[3] if len(sys.argv) > 3 else ""))
    elif what == "cmd":
        print(json.dumps(cmd(sys.argv[2], sys.argv[3] if len(sys.argv) > 3 else "")))
    else:
        print(__doc__)
