"""The first minutes' lesson (docs/design/first-minutes.md; LessonService, LessonController): checked in a Studio playtest.
On Windows, through the direct client (C:/Users/blast/RpgGame/tools/studio/studio_mcp.py).
    python tools/studio/lesson_check.py install | remove   (in Edit, before Play: LessonTest on, a server Script, a LocalScript)
    python tools/studio/lesson_check.py play | stop        (stop also gives the mouse and the camera back)
    python tools/studio/lesson_check.py do VERB [A]        (the LocalScript: dive, walk tank/trainer/strip, stay, press on/off,
                                                            one, log, where, rects, panel on/off, shop on/off,
                                                            overlaps: each lesson piece and other drawn thing that met
                                                            on the screen since last asked)
    python tools/studio/lesson_check.py cmd VERB [A]       (the server: home, train N, give ID, tamed ID, sold, at x,y,z, state)
    python tools/studio/lesson_check.py shot NAME          (a capture, work/lesson/NAME.jpeg)
The LocalScript writes a line each time what the lesson shows changes: mode, step, hold, the arrow, the trail, the hop
button's words, the dock's line, the ring, the locked fish; and looks for overlaps all the time.
"""
import json
import os
import subprocess
import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "work/lesson"
OUT.mkdir(parents=True, exist_ok=True)
CLIENT = "C:/Users/blast/RpgGame/tools/studio/studio_mcp.py"
ID = os.environ.get("STUDIO_ID", "3b999aa2-7b9c-4390-8231-1c7119b5cc57")

SERVER = r'''
local RS = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Services = game:GetService("ServerScriptService"):WaitForChild("Server"):WaitForChild("Services")
local RideService = require(Services:WaitForChild("RideService"))
workspace:SetAttribute("Sandbox", false)
local function cmd(verb, a)
	local p = Players:GetPlayers()[1]
	if verb == "home" then
		RideService.sendHome(p)
	elseif verb == "train" then
		RideService.train(p, tonumber(a))
	elseif verb == "give" then
		RideService.giveCarried(p, { Id = a, Size = "Normal", Variant = "" })
	elseif verb == "tamed" then
		RideService.OnTamed(p, { Type = require(RS.Shared.Config).FishById[a] } :: any)
	elseif verb == "sold" then
		while #RideService.carried(p) > 0 do
			RideService.takeCarried(p, 1)
		end
	elseif verb == "at" then
		local x, y, z = string.match(a, "([^,]+),([^,]+),([^,]+)")
		p.Character:PivotTo(CFrame.new(tonumber(x), tonumber(y), tonumber(z)))
	end
	return string.format("state=%s lesson=%s hold=%s max=%s carried=%d tank=%s", tostring(RideService.stateOf(p)),
		tostring(p:GetAttribute("Lesson")), tostring(p:GetAttribute("LessonHold")), tostring(p:GetAttribute("MaxOxygen")),
		#RideService.carried(p), tostring(p:GetAttribute("TankFish")))
end
RS:GetAttributeChangedSignal("LCCmd"):Connect(function()
	local line = tostring(RS:GetAttribute("LCCmd"))
	local verb, a = string.match(line, "^(%w*)|([^|]*)|")
	local ok, said = pcall(cmd, verb, a)
	RS:SetAttribute("LCSaid", tostring(said))
end)
'''

CLIENT_LUA = r'''
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local player = game:GetService("Players").LocalPlayer
local Client = player:WaitForChild("PlayerScripts"):WaitForChild("Client")
local Actions = require(Client:WaitForChild("Lib"):WaitForChild("Actions"))
local State = require(Client.Lib:WaitForChild("State"))
local gui = player:WaitForChild("PlayerGui")
local started = os.clock()
local log, last = {}, ""
local walking, dir = false, nil
local autopress, presses, took = false, 0, 0
local function shown(o)
	while o and o:IsA("GuiObject") do
		if not o.Visible then return false end
		o = o.Parent
	end
	return o ~= nil and (not o:IsA("ScreenGui") or o.Enabled)
end
local function rect(o)
	local p, s = o.AbsolutePosition, o.AbsoluteSize
	return string.format("%d,%d %dx%d", p.X, p.Y, s.X, s.Y)
end
local function line()
	local bits = { State.Mode, tostring(player:GetAttribute("Lesson")), player:GetAttribute("LessonHold") and "HOLD" or "-" }
	local f = workspace:FindFirstChild("LessonPointer")
	if f then
		local heads = 0
		for _, p in f:GetDescendants() do
			if p:IsA("BasePart") and p.Name == "Yellow" and p.Position.Y > -5000 then
				if p:IsA("Part") and p.Size.Y > 0.6 then table.insert(bits, "marker") end
				if p:IsA("Part") and p.Size.Y < 0.5 then heads += 1 end
			end
		end
		if heads > 0 then table.insert(bits, "trail") end
	end
	local hop = gui:FindFirstChild("HopButton", true)
	if hop and shown(hop) then
		local note = hop:FindFirstChild("LessonWords")
		table.insert(bits, "hop" .. (note and note.Visible and ("[" .. tostring(note:GetAttribute("Words")) .. "]") or ""))
	end
	local notes = gui:FindFirstChild("DockNotes")
	if notes and shown(notes.Root.Carry) then table.insert(bits, "line=" .. tostring(notes.Root.Carry:GetAttribute("Words"))) end
	local put = gui:FindFirstChild("PutAll", true)
	if put and shown(put) then
		local a = put:FindFirstChild("LessonRing")
		table.insert(bits, "putall" .. (a and a.Visible and "+ring" or ""))
	end
	if State.JumpTarget then table.insert(bits, "lock=" .. tostring(State.JumpTarget:GetAttribute("FishType"))) end
	if State.Strained then table.insert(bits, "STRAINED") end
	return table.concat(bits, " | ")
end
-- What is drawn where (points of the screen's inset space), and what of the lesson's meets what else
local boards = {}
local met, metOrder, looked = {}, {}, 0
local function drawn(o)
	local p, s = o.AbsolutePosition, o.AbsoluteSize
	if o:GetAttribute("Words") then return p.X, p.Y, p.X + s.X, p.Y + s.Y end -- (a sticker line, UI/Sticker)
	if (o:IsA("TextLabel") or o:IsA("TextButton")) and o.Text ~= "" and o.TextTransparency < 0.95 then
		local b = o.TextBounds
		local x = if o.TextXAlignment == Enum.TextXAlignment.Left then p.X
			elseif o.TextXAlignment == Enum.TextXAlignment.Right then p.X + s.X - b.X else p.X + (s.X - b.X) / 2
		local y = if o.TextYAlignment == Enum.TextYAlignment.Top then p.Y
			elseif o.TextYAlignment == Enum.TextYAlignment.Bottom then p.Y + s.Y - b.Y else p.Y + (s.Y - b.Y) / 2
		if o.BackgroundTransparency < 0.95 then
			return math.min(x, p.X), math.min(y, p.Y), math.max(x + b.X, p.X + s.X), math.max(y + b.Y, p.Y + s.Y)
		end
		return x, y, x + b.X, y + b.Y
	end
	local image = (o:IsA("ImageLabel") or o:IsA("ImageButton")) and o.Image ~= "" and o.ImageTransparency < 0.95
	if image or o:IsA("ViewportFrame") or o.BackgroundTransparency < 0.95 then
		return p.X, p.Y, p.X + s.X, p.Y + s.Y
	end
	return nil
end
local function hitTest(list, name, x0, y0, x1, y1, view)
	if x1 <= x0 or y1 <= y0 or (x1 - x0) * (y1 - y0) > view.X * view.Y * 0.5 then return end
	for _, l in list do
		if not l.Skip[name] then
			local w = math.min(x1, l.X1) - math.max(x0, l.X0)
			local h = math.min(y1, l.Y1) - math.max(y0, l.Y0)
			if w > 1 and h > 1 then
				local key = l.Name .. " x " .. name
				local m = met[key]
				if not m then
					m = { N = 0, Most = 0, At = "" }
					met[key] = m
					table.insert(metOrder, key)
				end
				m.N += 1
				if w * h > m.Most then
					m.Most = w * h
					m.At = string.format("%dx%d px, %.1f s, %s/%s", w, h, os.clock() - started, State.Mode,
						tostring(player:GetAttribute("Lesson")))
				end
			end
		end
	end
end
local OURS = { LessonWords = true, LessonArrow = true, LessonRing = true }
local seen = {} -- how many looks each lesson piece was on the screen for (a check of the check)
local function overlaps()
	local camera = workspace.CurrentCamera
	local view = camera.ViewportSize
	local inset = game:GetService("GuiService"):GetGuiInset()
	local list = {}
	local function ours(o, name)
		if not shown(o) then return end
		local x0, y0, x1, y1
		if o:IsA("TextLabel") then x0, y0, x1, y1 = drawn(o)
		else
			local p, s = o.AbsolutePosition, o.AbsoluteSize
			x0, y0, x1, y1 = p.X, p.Y, p.X + s.X, p.Y + s.Y
		end
		if not x0 then return end
		seen[name] = (seen[name] or 0) + 1
		table.insert(list, { Name = name, X0 = x0, Y0 = y0, X1 = x1, Y1 = y1, Skip = {}, Own = o.Parent })
		if x0 < -1 or x1 > view.X + 1 or y0 < -inset.Y - 1 or y1 > view.Y - inset.Y + 1 then
			hitTest({ { Name = name, X0 = 0, Y0 = 0, X1 = 9, Y1 = 9, Skip = {} } }, "SCREEN EDGE", 0, 0, 9, 9, view)
		end
	end
	for _, n in { "HopButton", "PutAll" } do
		local b = gui:FindFirstChild(n, true)
		if b then for _, c in b:GetChildren() do if OURS[c.Name] then ours(c, c.Name) end end end
	end
	local notes = gui:FindFirstChild("DockNotes")
	if notes then ours(notes.Root.Carry, "DockLine") end
	local f = workspace:FindFirstChild("LessonPointer")
	if f then
		local x0, y0, x1, y1 = math.huge, math.huge, -math.huge, -math.huge
		local any = false
		for _, p in f:GetDescendants() do
			local up = p:IsA("BasePart") and p:IsA("Part") and p.Position.Y > -5000 and p.Size.Y > 0.6
			if p:IsA("WedgePart") then up = p.Position.Y > -5000 and math.abs(p.CFrame.ZVector.Y) > 0.9 end
			if up then
				for _, sx in { -0.5, 0.5 } do for _, sy in { -0.5, 0.5 } do for _, sz in { -0.5, 0.5 } do
					local at = camera:WorldToViewportPoint(p.CFrame * (p.Size * Vector3.new(sx, sy, sz)))
					if at.Z > 0 then
						any = true
						x0, y0 = math.min(x0, at.X), math.min(y0, at.Y - inset.Y)
						x1, y1 = math.max(x1, at.X), math.max(y1, at.Y - inset.Y)
					end
				end end end
			end
		end
		if any and x1 > 0 and x0 < view.X and y1 > -inset.Y and y0 < view.Y - inset.Y then
			seen.Arrow3D = (seen.Arrow3D or 0) + 1
			table.insert(list, { Name = "Arrow3D", X0 = x0, Y0 = y0, X1 = x1, Y1 = y1, Skip = {} })
		end
	end
	-- (the trail, part by part: it lies on the floor, so it goes under the HUD wherever the floor does)
	if f then
		for _, p in f:GetDescendants() do
			local flat = p:IsA("BasePart") and p.Position.Y > -5000 and p.Size.X > 0.05
				and (p:IsA("WedgePart") and math.abs(p.CFrame.ZVector.Y) < 0.1 and math.abs(p.CFrame.YVector.Y) < 0.1
					or p:IsA("Part") and p.Size.Y < 0.5)
			local at = flat and camera:WorldToViewportPoint(p.Position)
			if at and at.Z > 0 then
				local per = view.Y / (2 * math.tan(math.rad(camera.FieldOfView / 2)) * at.Z)
				local w = math.max(p.Size.X, p.Size.Z) * per * 0.5
				seen.Trail = (seen.Trail or 0) + 1
				table.insert(list, { Name = "Trail", X0 = at.X - w / 2, Y0 = at.Y - inset.Y - w / 8, X1 = at.X + w / 2,
					Y1 = at.Y - inset.Y + w / 8, Skip = {} })
			end
		end
	end
	if #list == 0 then return end
	local function walk(o, path)
		for _, c in o:GetChildren() do
			if c:IsA("GuiObject") then
				if c.Visible and not OURS[c.Name] and c.Name ~= "Carry" then
					local x0, y0, x1, y1 = drawn(c)
					local name = path .. "." .. c.Name
					for _, l in list do
						-- (a piece is on its own button, inside the window that button stands in)
						l.Skip[name] = l.Own ~= nil and (l.Own == c or l.Own:IsDescendantOf(c) or c:IsDescendantOf(l.Own))
					end
					if x0 then hitTest(list, name, x0, y0, x1, y1, view) end
					walk(c, name)
				end
			elseif c:IsA("ScreenGui") then
				if c.Enabled then walk(c, c.Name) end
			elseif c:IsA("Folder") then
				walk(c, path .. "." .. c.Name)
			end
		end
	end
	walk(gui, "")
	for _, b in boards do
		if b.Parent and b.Enabled then
			local at = b.Adornee or b.Parent
			local pos = at and (at:IsA("BasePart") and at.Position or at:IsA("Attachment") and at.WorldPosition
				or at:IsA("Model") and at:GetPivot().Position)
			if pos then
				pos += b.StudsOffsetWorldSpace + camera.CFrame:VectorToWorldSpace(b.StudsOffset)
				local v, on = camera:WorldToViewportPoint(pos)
				local far = b.MaxDistance
				if on and v.Z > 0 and (far == 0 or far == math.huge or (pos - camera.CFrame.Position).Magnitude < far) then
					local per = view.Y / (2 * math.tan(math.rad(camera.FieldOfView / 2)) * v.Z)
					local w = b.Size.X.Scale * per + b.Size.X.Offset
					local h = b.Size.Y.Scale * per + b.Size.Y.Offset
					hitTest(list, "world:" .. b.Name .. " on " .. (at.Parent and at.Parent.Name or "?"),
						v.X - w / 2, v.Y - inset.Y - h / 2, v.X + w / 2, v.Y - inset.Y + h / 2, view)
				end
			end
		end
	end
end
RunService.Heartbeat:Connect(function()
	looked += 1
	if looked % 120 == 1 then
		table.clear(boards)
		for _, root in { workspace, gui } do
			for _, o in root:GetDescendants() do if o:IsA("BillboardGui") then table.insert(boards, o) end end
		end
	end
	if looked % 2 == 0 then
		local ok, problem = pcall(overlaps)
		if not ok then met["CHECK FAILED " .. tostring(problem)] = met["CHECK FAILED " .. tostring(problem)] or { N = 1, Most = 0, At = "" }
			if not table.find(metOrder, "CHECK FAILED " .. tostring(problem)) then table.insert(metOrder, "CHECK FAILED " .. tostring(problem)) end
		end
	end
	local l = line()
	if l ~= last then
		last = l
		table.insert(log, string.format("%.2f ox=%s %s", os.clock() - started, tostring(player:GetAttribute("Oxygen")), l))
	end
	if autopress then
		presses += 1
		if Actions.jump() then took += 1 end
	end
end)
-- (just before the physics: after the game's own controls, which give a still stick every frame once anyone has pressed a key)
RunService.PreSimulation:Connect(function()
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if walking and humanoid then
		humanoid:Move(if State.Mode == "Dock" then dir else Vector3.zero)
	end
end)
local function controls(on)
	local module = player.PlayerScripts:FindFirstChild("PlayerModule")
	if not module then return end
	local m = require(module):GetControls()
	if on then m:Enable() else m:Disable() end
end
local function place(name)
	local dock = workspace.ClaudeBlockout.Dock
	if name == "strip" or name == "" then return dock:FindFirstChild("StartStrip", true).Position end
	local plot = dock.Plots[player:GetAttribute("Plot")]
	if name == "tank" then return plot.TankWater.Position end
	return plot.TrainerRide:GetPivot().Position
end
local function verb(v, a)
	if v == "log" then
		local out = table.concat(log, "\n")
		table.clear(log)
		return out
	elseif v == "walk" or v == "dive" then
		local to = place(if v == "dive" then "strip" else a)
		local _, root = State.character()
		dir = ((to - root.Position) * Vector3.new(1, 0, 1)).Unit
		controls(false)
		walking = true
		return "walking " .. tostring(dir)
	elseif v == "stay" then
		walking = false
		controls(true)
		return "stay"
	elseif v == "press" then
		autopress = a == "on"
		local s = string.format("presses=%d took=%d", presses, took)
		presses, took = 0, 0
		return s
	elseif v == "one" then
		return tostring(Actions.jump())
	elseif v == "where" then
		local _, root = State.character()
		return string.format("%s to %s %.0f", tostring(root.Position), a,
			((place(a) - root.Position) * Vector3.new(1, 0, 1)).Magnitude)
	elseif v == "rects" then
		local out = { "view " .. tostring(workspace.CurrentCamera.ViewportSize) }
		for _, name in { "HopButton", "LessonWords", "LessonArrow", "LessonRing", "PutAll", "Carry", "LandStrip", "Banner", "Banners", "Strip" } do
			for _, o in gui:GetDescendants() do
				if o.Name == name and o:IsA("GuiObject") and shown(o) then
					table.insert(out, name .. " " .. rect(o) .. " in " .. o.Parent.Name)
				end
			end
		end
		return table.concat(out, "\n")
	elseif v == "overlaps" then
		local out = { "frames " .. looked }
		for name, n in seen do table.insert(out, "seen " .. name .. " " .. n) end
		for _, key in metOrder do
			table.insert(out, string.format("%s: %d looks, most %s", key, met[key].N, met[key].At))
		end
		table.clear(met)
		table.clear(metOrder)
		table.clear(seen)
		return table.concat(out, "\n")
	elseif v == "panel" then
		require(Client:WaitForChild("UI"):WaitForChild("TankPanel")).toggle(a == "on")
		return "panel " .. a
	elseif v == "shop" then
		require(Client:WaitForChild("UI"):WaitForChild("Shop")).go(if a == "on" then "Shop" else nil)
		return "shop " .. a
	end
	return "?"
end
workspace:GetAttributeChangedSignal("LCDo"):Connect(function()
	local v, a = string.match(tostring(workspace:GetAttribute("LCDo")), "^(%w*)|([^|]*)|")
	local ok, said = pcall(verb, v, a)
	workspace:SetAttribute("LCClient", tostring(said))
end)
'''


def call(tool, args, timeout=120):
    path = OUT / "_args.json"
    path.write_text(json.dumps({"studio_id": ID, **args}), encoding="utf-8")
    r = subprocess.run(
        [sys.executable, CLIENT, "call", tool, "@" + str(path), str(timeout)],
        capture_output=True,
        text=True,
        encoding="utf-8",
    )
    for line in r.stdout.splitlines():
        if line.startswith('{"content"'):
            return json.loads(line)
    return {"content": [{"type": "text", "text": "ERR " + r.stdout[-800:] + r.stderr[-400:]}]}


def text(result):
    return "\n".join(c.get("text", "") for c in result["content"])


def luau(code, where):
    return text(call("execute_luau", {"datamodel_type": where, "code": code}))


def lua(v):
    return "[==[" + str(v) + "]==]"


def install(remove=False):
    return luau(
        f"""local sss = game:GetService("ServerScriptService")
local sps = game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts")
for _, at in {{ sss, sps }} do
	local old = at:FindFirstChild("ZZLessonCheck")
	if old then old:Destroy() end
end
if {"true" if remove else "false"} then
	workspace:SetAttribute("LessonTest", nil)
	return "removed"
end
workspace:SetAttribute("LessonTest", true)
local s = Instance.new("Script")
s.Name = "ZZLessonCheck"
s.Source = {lua(SERVER)}
s.Parent = sss
local c = Instance.new("LocalScript")
c.Name = "ZZLessonCheck"
c.Source = {lua(CLIENT_LUA)}
c.Parent = sps
return "installed"
""",
        "Edit",
    )


def cmd(v, a=""):
    return luau(
        f"local RS = game:GetService('ReplicatedStorage') RS:SetAttribute('LCCmd', {lua(f'{v}|{a}|{time.time()}')}) "
        f"task.wait(0.4) return RS:GetAttribute('LCSaid')",
        "Server",
    )


def do(v, a=""):
    return luau(
        f"workspace:SetAttribute('LCDo', {lua(f'{v}|{a}|{time.time()}')}) task.wait(0.3) "
        f"return workspace:GetAttribute('LCClient')",
        "Client",
    )


def main():
    verb, rest = sys.argv[1], sys.argv[2:]
    if verb in ("install", "remove"):
        print(install(verb == "remove"))
    elif verb == "play":
        print(text(call("start_stop_play", {"is_start": True})))
    elif verb == "stop":
        print(text(call("start_stop_play", {"is_start": False})))
        time.sleep(4)
        print(
            luau(
                "task.delay(0.5, function() game:GetService('UserInputService').MouseBehavior = Enum.MouseBehavior.Default "
                "workspace.CurrentCamera.CameraType = Enum.CameraType.Fixed end) return 'ok'",
                "Edit",
            )
        )
    elif verb == "cmd":
        print(cmd(*rest))
    elif verb == "do":
        print(do(*rest))
    elif verb == "shot":
        # (the direct client saves the picture itself, where MCP_IMG says)
        path = OUT / f"{rest[0]}.jpeg"
        os.environ["MCP_IMG"] = str(path.with_suffix(".png"))
        print(text(call("screen_capture", {"capture_id": rest[0]}, 60)), path, path.exists())


main()
