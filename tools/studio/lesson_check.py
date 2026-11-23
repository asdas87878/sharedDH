"""The first minutes' lesson (docs/design/first-minutes.md; LessonService, LessonController): checked in a Studio playtest.
On Windows, through the direct client (C:/Users/blast/RpgGame/tools/studio/studio_mcp.py).
    python tools/studio/lesson_check.py install | remove   (in Edit, before Play: LessonTest on, a server Script, a LocalScript)
    python tools/studio/lesson_check.py play | stop        (stop also gives the mouse and the camera back)
    python tools/studio/lesson_check.py do VERB [A]        (the LocalScript: dive, walk tank/trainer/strip, stay, press on/off,
                                                            one, log, where, rects, panel on/off, shop on/off)
    python tools/studio/lesson_check.py cmd VERB [A]       (the server: home, train N, give ID, tamed ID, sold, at x,y,z, state)
    python tools/studio/lesson_check.py shot NAME          (a capture, work/lesson/NAME.jpeg)
The LocalScript writes a line each time what the lesson shows changes: mode, step, hold, line, goal bar, marker, trail,
plate, hop button, caption, locked fish.
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
	local lesson = gui:FindFirstChild("Lesson")
	local root = lesson and lesson:FindFirstChild("Root")
	if root then
		if shown(root.Line) then table.insert(bits, "line=" .. root.Line.ContentText) end
		if shown(root.Goal) then
			table.insert(bits, "goal=" .. root.Goal.Words.Text .. (root.Goal.Done.Visible and " TICK" or ""))
		end
	end
	local f = workspace:FindFirstChild("LessonPointer")
	if f then
		local heads = 0
		for _, p in f:GetChildren() do
			if p.Name == "Arm" and p.Position.Y > -5000 then heads += 1 end
		end
		local m = gui:FindFirstChild("LessonMarker")
		if m and m.Marker.Visible then table.insert(bits, "marker" .. (if m.Marker.Arrow.Rotation ~= 0 then " side" else "")) end
		if heads > 0 then table.insert(bits, "trail") end
	end
	local hop = gui:FindFirstChild("HopButton", true)
	if hop and shown(hop) then
		local note = hop:FindFirstChild("LessonNote")
		table.insert(bits, "hop" .. (note and note.Visible and ("[" .. note:FindFirstChildOfClass("TextLabel").Text .. "]") or ""))
	end
	local notes = gui:FindFirstChild("DockNotes")
	if notes and shown(notes.Root.Carry) then table.insert(bits, "caption=" .. notes.Root.Carry.Text) end
	local put = gui:FindFirstChild("PutAll", true)
	if put and shown(put) then
		local a = put:FindFirstChild("LessonArrow")
		table.insert(bits, "putall" .. (a and a.Visible and "+arrow" or ""))
	end
	if State.JumpTarget then table.insert(bits, "lock=" .. tostring(State.JumpTarget:GetAttribute("FishType"))) end
	if State.Strained then table.insert(bits, "STRAINED") end
	return table.concat(bits, " | ")
end
RunService.Heartbeat:Connect(function()
	local l = line()
	if l ~= last then
		last = l
		table.insert(log, string.format("%.2f ox=%s %s", os.clock() - started, tostring(player:GetAttribute("Oxygen")), l))
	end
	if autopress then
		presses += 1
		if Actions.jump() then took += 1 end
	end
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
		for _, name in { "Line", "Goal", "Marker", "HopButton", "LessonNote", "LessonArrow", "PutAll", "Carry", "LandStrip", "Banner", "Banners", "Strip" } do
			for _, o in gui:GetDescendants() do
				if o.Name == name and o:IsA("GuiObject") and shown(o) then
					table.insert(out, name .. " " .. rect(o) .. " in " .. o.Parent.Name)
				end
			end
		end
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
