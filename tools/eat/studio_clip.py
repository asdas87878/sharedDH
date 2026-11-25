"""The new eating moves filmed in Studio from a REAL fail (Config.Fail.NewEat; Hugo judges the clip).
    python tools/eat/studio_clip.py check FISH SIZE [PLACE] [--new 0|1] [--times N]   (live fails, numbers only)
    python tools/eat/studio_clip.py film  FISH SIZE [PLACE] [--new 0|1] [--fps 30] [--from S] [--to S] [--out NAME]
    python tools/eat/studio_clip.py play | stop | remove
        FISH: Octopus, Kronosaurus ...; SIZE: Config.SizeOrder; PLACE: open (default), floor, surface
How: plays the place (the branch synced into it with tools/ui/catch_show/sync_src.py first), seats the player on that fish
through the sandbox's reset, and fails it with RideService.forceFail, at full speed, 60 fps. A LocalScript keeps every
rendered frame: the camera, every part of the fish and of the loose body. `film` then fails the same fish at the same
place again, held by the game's own FailClock, hides that fish and rider, puts still copies where the recording had
them, the camera too, and shoots the Studio window frame by frame (studio-run.mjs shot). The ink is recorded too; the shade and the
bubbles are the game's own, let off at their moments with their particles slowed to the shooting. Other fish are hidden
(they would race). NewEat is switched on in the client's own copy of Config at run time: the file is not touched.
Needs Studio open through studio-runner, at 40 fps or more. Nothing is saved; `stop` puts the Edit mouse and camera back.
"""
import json
import shutil
import subprocess
import sys
import tempfile
import time
from pathlib import Path

from PIL import Image, ImageChops

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools/studio"))
import fail_eat_check as E  # noqa: E402  (the transport: edit, server, play, capture)

OUT = ROOT / "work/eat"
FRAMES = OUT / "frames"
FFMPEG = shutil.which("ffmpeg") or str(Path.home() / "Applications/ffmpeg/bin/ffmpeg")
CROP = (4, 184, 1986, 1206)  # the game view in Studio's 2400 x 1280 window

SERVER = r'''
local RS = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RideService = require(game:GetService("ServerScriptService"):WaitForChild("Server"):WaitForChild("Services"):WaitForChild("RideService"))
local FishService = require(game:GetService("ServerScriptService").Server.Services:WaitForChild("FishService"))
local Config = require(RS:WaitForChild("Shared"):WaitForChild("Config"))
local report = Instance.new("RemoteEvent")
report.Name = "ZZEatReport"
report.Parent = RS
report.OnServerEvent:Connect(function(_, key, text)
	RS:SetAttribute("Eat" .. key, text)
end)
RS:SetAttribute("EatReady", true)
local function place(case)
	local at, along = RideService.sandboxStart()
	local p = at + along * (tonumber(RS:GetAttribute("EatAhead")) or 160)
	-- (land8, land8floor ...: where the admin panel's land jump goes, so a fish is filmed at its own depth; land8@300: 300 on)
	local land = tonumber(string.match(case, "^land(%d+)"))
	if land then
		local s = FishService.landStart(land) + 150 + (tonumber(string.match(case, "@(%d+)")) or 0)
		p = FishService.streamPoint(s, Config.Herd.RideHeight + 6, 8)
		local way = (FishService.streamPoint(s + 30, Config.Herd.RideHeight + 6, 8) - p) * Vector3.new(1, 0, 1)
		along = if way.Magnitude > 0.01 then way.Unit else Vector3.zAxis
		case = string.match(case, "%a+$") or ""
	end
	if case == "surface" then
		p = Vector3.new(p.X, Config.Depth.SurfaceY - 7, p.Z)
	elseif case == "floor" then
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.IgnoreWater = true
		local skip = {}
		for _, m in workspace:GetDescendants() do
			if m:IsA("Model") and (m:GetAttribute("Rig") or m:FindFirstChildOfClass("Humanoid")) then
				table.insert(skip, m)
			end
		end
		params.FilterDescendantsInstances = skip
		local hit = workspace:Raycast(p + along * 30, Vector3.new(0, -400, 0), params)
		if hit then
			p = Vector3.new(p.X, hit.Position.Y + (tonumber(RS:GetAttribute("EatOver")) or 10), p.Z)
		end
	end
	return p, along
end
RS:GetAttributeChangedSignal("EatCmd"):Connect(function()
	local cmd = tostring(RS:GetAttribute("EatCmd") or "")
	local verb, a, b = string.match(cmd, "^(%w+)|?([^|]*)|?([^|]*)")
	local player = Players:GetPlayers()[1]
	local ok, said = pcall(function()
		if verb == "ride" then
			local at, along = place(b)
			pcall(function()
				player:RequestStreamAroundAsync(at, 5)
			end)
			RideService.sandboxReset(player, nil, a, nil, { At = at, Along = along })
			return string.format("ride %s at %.0f %.0f %.0f", a, at.X, at.Y, at.Z)
		elseif verb == "fail" then
			return "fail " .. tostring(RideService.forceFail(player, if a ~= "" then a else nil)) .. " " .. tostring(player:GetAttribute("FailKind") or "none")
		elseif verb == "home" then
			RideService.sendHome(player)
			return "home"
		elseif verb == "state" then
			return tostring(player:GetAttribute("State"))
		end
		return "?"
	end)
	RS:SetAttribute("EatSaid", tostring(said) .. (if ok then "" else " (error)"))
end)
'''

CLIENT = r'''
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Http = game:GetService("HttpService")
local LogService = game:GetService("LogService")
local player = Players.LocalPlayer
local Client = player:WaitForChild("PlayerScripts"):WaitForChild("Client")
local FailController = require(Client:WaitForChild("Controllers"):WaitForChild("FailController"))
local Fx = require(Client:WaitForChild("Lib"):WaitForChild("Fx"))
local Config = require(RS:WaitForChild("Shared"):WaitForChild("Config"))
local report = RS:WaitForChild("ZZEatReport", 60)
local camera = workspace.CurrentCamera

local errors = {}
LogService.MessageOut:Connect(function(text, kind)
	if kind == Enum.MessageType.MessageError and #errors < 12 then
		table.insert(errors, string.sub(text, 1, 220))
	end
end)

local take = nil -- the last recording
local armed = false

local function ridden()
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	local best, far = nil, math.huge
	for _, m in workspace:GetDescendants() do
		if m:IsA("Model") and m:GetAttribute("Rig") and m.PrimaryPart and root then
			local d = (m.PrimaryPart.Position - root.Position).Magnitude
			if d < far then
				best, far = m, d
			end
		end
	end
	return best
end
local function partsOf(model)
	local list = {}
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			table.insert(list, d)
		end
	end
	return list
end
local function copyOf(model)
	local was = {}
	for _, d in model:GetDescendants() do
		was[d] = d.Archivable
		d.Archivable = true
	end
	local a = model.Archivable
	model.Archivable = true
	local c = model:Clone()
	model.Archivable = a
	for d, w in was do
		d.Archivable = w
	end
	return c
end

local function arm()
	local fish = ridden()
	local character = player.Character
	if not fish or not character then
		return "nothing to record"
	end
	take = {
		Frames = {},
		Fish = copyOf(fish),
		Body = copyOf(character),
		FishParts = partsOf(fish),
		BodyParts = partsOf(character),
		Model = fish,
		Zero = nil,
		Beats = {},
	}
	errors = {}
	armed = true
	return string.format("armed on %s %s, %d and %d parts", tostring(fish:GetAttribute("Rig")), tostring(fish:GetAttribute("SizeTier")), #take.FishParts, #take.BodyParts)
end

-- (the bursts of a recorded run, to be let off again in the playback)
local realBurst = Fx.burst
Fx.burst = function(position, amount, time, reach)
	if take and armed and take.Zero then
		table.insert(take.Beats, { T = os.clock() - take.Zero, At = position, N = amount, Reach = reach })
	end
	if workspace:GetAttribute("EatT") ~= nil then
		return -- (the playback lets its own off)
	end
	return realBurst(position, amount, time, reach)
end

RunService:BindToRenderStep("ZZEatRec", Enum.RenderPriority.Last.Value + 5, function()
	if not armed or not take then
		return
	end
	local p = FailController.probe(player)
	local now = os.clock()
	if p and not take.Zero then
		take.Zero = now - p.T
	end
	local f = { C = now, Cam = camera.CFrame, Fov = camera.FieldOfView, P = p, Fish = {}, Size = {}, Body = {}, Gone = {} }
	for i, part in take.FishParts do
		f.Fish[i] = part.CFrame
		f.Size[i] = part.Size
	end
	for i, part in take.BodyParts do
		f.Body[i] = part.CFrame
		f.Gone[i] = math.max(part.LocalTransparencyModifier, if p and p.Hidden then 1 else 0)
	end
	f.Ink = {}
	for _, d in camera:GetChildren() do
		if d.Name == "Ink" and d:IsA("BasePart") and d.Transparency < 1 then
			table.insert(f.Ink, { d.CFrame, d.Size, d.Color })
		end
	end
	local state = player:GetAttribute("State")
	if take.Zero and not p and state ~= "Failing" then
		armed = false
	else
		table.insert(take.Frames, f)
	end
	-- (before the fail: only the last second is kept)
	if not take.Zero and #take.Frames > 60 then
		table.remove(take.Frames, 1)
	end
end)

local function torsoIndex()
	for i, part in take.BodyParts do
		if part.Name == "UpperTorso" or part.Name == "Torso" then
			return i
		end
	end
	return 1
end

local function angle(a, b)
	return math.deg(math.acos(math.clamp(a:Dot(b), -1, 1)))
end

-- The numbers of the recording: the fish's and the camera's turning, the rider's jolts, whether the rider is in the picture
local function numbers()
	local ti = torsoIndex()
	local rootI = 1
	for i, part in take.FishParts do
		if part == take.Model.PrimaryPart then
			rootI = i
		end
	end
	local out = { Frames = #take.Frames, Errors = errors, Rows = {} }
	local prev, vPrev, camPrev
	local maxTurn, camTurn, camStep, jolt, offscreen, n, worstDt = 0, 0, 0, 0, 0, 0, 0
	local joltAt, camAt, turnAt, offAt = 0, 0, 0, {}
	local view = camera.ViewportSize
	for i, f in take.Frames do
		local t = f.C - (take.Zero or f.C)
		if t >= 0 then
			n += 1
			local torso = f.Body[ti].Position
			local c = f.Cam:PointToObjectSpace(torso)
			local tan = math.tan(math.rad(f.Fov / 2))
			local sx, sy = 0, 0
			local inside = false
			if c.Z < -0.5 then
				sy = c.Y / (-c.Z * tan)
				sx = c.X / (-c.Z * tan * view.X / view.Y)
				inside = math.abs(sx) < 0.97 and math.abs(sy) < 0.97
			end
			local hidden = f.P and f.P.Hidden
			if not inside and not hidden then
				offscreen += 1
				if #offAt < 12 then
					table.insert(offAt, math.floor(t * 100) / 100)
				end
			end
			if prev then
				local dt = f.C - prev.C
				worstDt = math.max(worstDt, dt)
				local turn = angle(f.Fish[rootI].LookVector * Vector3.new(1, 0, 1), prev.Fish[rootI].LookVector * Vector3.new(1, 0, 1)) / dt
				local a = f.Fish[rootI].LookVector * Vector3.new(1, 0, 1)
				local b = prev.Fish[rootI].LookVector * Vector3.new(1, 0, 1)
				turn = if a.Magnitude > 0.3 and b.Magnitude > 0.3 then angle(a.Unit, b.Unit) / dt else 0
				if turn > maxTurn then
					maxTurn, turnAt = turn, t
				end
				local ct = angle(f.Cam.LookVector, prev.Cam.LookVector) / dt
				if ct > camTurn then
					camTurn, camAt = ct, t
				end
				camStep = math.max(camStep, (f.Cam.Position - prev.Cam.Position).Magnitude)
				local v = (torso - prev.Body[ti].Position) / dt
				if vPrev and not hidden and (v - vPrev).Magnitude > jolt then
					jolt, joltAt = (v - vPrev).Magnitude, t
				end
				vPrev = v
			end
			prev = f
			if f.P then
				local far = f.P.Far
				table.insert(out.Rows, string.format("t %.2f u %.2f wait %.2f screen %.2f %.2f far %.1f mouth %.1f hid %s", t, f.P.U, f.P.Wait, sx, sy, (f.Cam.Position - torso).Magnitude, far or -1, tostring(hidden)))
			end
		end
	end
	out.Seen = n
	out.WorstDt = math.floor(worstDt * 1000)
	out.HeadingTurn = { math.floor(maxTurn), math.floor(turnAt * 100) / 100 }
	out.CamTurn = { math.floor(camTurn), math.floor(camAt * 100) / 100 }
	out.CamStep = math.floor(camStep * 100) / 100
	out.Jolt = { math.floor(jolt), math.floor(joltAt * 100) / 100 }
	-- the tail's own pitch against the root (the part furthest back as it began), and the highest water under the root
	local tailI, most = 1, -math.huge
	local f0 = take.Frames[1]
	for i in take.FishParts do
		local z = f0.Fish[rootI]:PointToObjectSpace(f0.Fish[i].Position).Z
		if z > most then
			tailI, most = i, z
		end
	end
	local bend = {}
	for i, f in take.Frames do
		local t = f.C - (take.Zero or f.C)
		if t >= 0 and t < 2.4 and i % 6 == 0 then
			local look = f.Fish[rootI]:VectorToObjectSpace(f.Fish[tailI].LookVector)
			local rest = f0.Fish[rootI]:VectorToObjectSpace(f0.Fish[tailI].LookVector)
			local _, y0 = 0, math.deg(math.asin(math.clamp(rest.Y, -1, 1)))
			table.insert(bend, string.format("%.2f:%d", t, math.deg(math.asin(math.clamp(look.Y, -1, 1))) - y0))
		end
	end
	out.Tail = take.FishParts[tailI].Name .. " " .. table.concat(bend, " ")
	out.Off = { offscreen, offAt }
	local last = take.Frames[#take.Frames]
	out.Last = last and last.C - (take.Zero or last.C)
	local p = nil
	for _, f in take.Frames do
		p = f.P or p
	end
	if p then
		out.Probe = { GrabAt = p.GrabAt, BiteAt = p.BiteAt, BiteFar = p.BiteFar, HideAt = p.HideAt, HideFar = p.HideFar, Wait = p.Wait, Length = p.Length, Kind = p.Kind }
	end
	return out
end

-- how deep the arms' and the rider's boxes go into each other (each link as EatMoves.linkOf sees it is tighter: this is
-- the parts' own boxes, so a lean part reads deep while its mesh is clear: for where to look, not a verdict)

----------------------------------------------------------------------------------------------------------------------
-- the playback
local stage, fishParts, bodyParts, hiddenGuis
local beatsDone = {}
local function pick(list, t)
	local a, b = list[1], list[#list]
	for i = 1, #list - 1 do
		if list[i].C - take.Zero <= t and list[i + 1].C - take.Zero > t then
			a, b = list[i], list[i + 1]
			local k = (t - (a.C - take.Zero)) / math.max(b.C - a.C, 1e-4)
			return a, b, math.clamp(k, 0, 1)
		end
	end
	if t >= list[#list].C - take.Zero then
		return list[#list], list[#list], 0
	end
	return list[1], list[1], 0
end

local function strip(model)
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
		elseif d:IsA("Highlight") or d:IsA("Trail") or d:IsA("JointInstance") or d:IsA("Constraint") or d:IsA("LuaSourceContainer") or d:IsA("Sound") or d:IsA("BodyMover") or d:IsA("Animator") or d:IsA("NoCollisionConstraint") then
			d:Destroy()
		elseif d:IsA("Humanoid") then
			d.BreakJointsOnDeath = false
			d.RequiresNeck = false
			d.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
			d.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
			d.EvaluateStateMachine = false
		end
	end
end

local function unstage()
	if stage then
		stage:Destroy()
		stage = nil
	end
	for gui in hiddenGuis or {} do
		gui.Enabled = true
	end
	hiddenGuis = nil
	for _, list in { workspace:GetDescendants(), player.Character and player.Character:GetDescendants() or {} } do
		for _, d in list do
			if d:IsA("BasePart") and d.LocalTransparencyModifier == 1 then
				d.LocalTransparencyModifier = 0
			end
		end
	end
	pcall(function()
		game:GetService("StarterGui"):SetCore("TopbarEnabled", true)
	end)
end

local function setStage()
	unstage()
	stage = Instance.new("Folder")
	stage.Name = "ZZEatStage"
	local fish, body = take.Fish:Clone(), take.Body:Clone()
	fishParts, bodyParts = partsOf(fish), partsOf(body)
	fish.Name, body.Name = "EatFish", "EatBody"
	fish:SetAttribute("Rig", nil)
	for _, tag in fish:GetTags() do
		fish:RemoveTag(tag)
	end
	strip(fish)
	strip(body)
	local h = Instance.new("Highlight")
	h.Name = "EatLine"
	h.Adornee = body
	h.FillTransparency = 1
	h.OutlineColor = Color3.fromRGB(255, 250, 235)
	h.OutlineTransparency = 0.15
	h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	h.Parent = body
	fish.Parent = stage
	body.Parent = stage
	stage.Parent = workspace
	beatsDone = {}
	hiddenGuis = {}
	for _, gui in player.PlayerGui:GetChildren() do
		if gui:IsA("ScreenGui") and gui.Enabled and gui.Name ~= "FailShade" and not string.find(gui.Name, "Fade") then
			hiddenGuis[gui] = true
			gui.Enabled = false
		end
	end
	pcall(function()
		game:GetService("StarterGui"):SetCore("TopbarEnabled", false)
	end)
	return string.format("stage: %d of %d and %d of %d parts, %d frames", #fishParts, #take.FishParts, #bodyParts, #take.BodyParts, #take.Frames)
end

local function puff(part, n, scale)
	for _, e in part:GetDescendants() do
		if e:IsA("ParticleEmitter") then
			e.TimeScale = scale
			e:Emit(n)
		end
	end
end

local shown = nil
RunService:BindToRenderStep("ZZEatPlay", Enum.RenderPriority.Last.Value + 6, function()
	local t = workspace:GetAttribute("EatT")
	if type(t) ~= "number" or not stage or not take then
		return
	end
	local a, b, k = pick(take.Frames, t)
	camera.CameraType = Enum.CameraType.Scriptable
	camera.CFrame = a.Cam:Lerp(b.Cam, k)
	camera.FieldOfView = a.Fov + (b.Fov - a.Fov) * k
	camera.Focus = camera.CFrame * CFrame.new(0, 0, -20)
	for i, part in fishParts do
		part.CFrame = a.Fish[i]:Lerp(b.Fish[i], k)
		part.Size = a.Size[i]:Lerp(b.Size[i], k)
	end
	local gone = false
	for i, part in bodyParts do
		part.CFrame = a.Body[i]:Lerp(b.Body[i], k)
		part.LocalTransparencyModifier = a.Gone[i]
		if a.Gone[i] > 0.9 then
			gone = true
		end
	end
	local line = stage.EatBody:FindFirstChild("EatLine")
	if line then
		line.Enabled = t >= 0 and not gone
	end
	-- everything else that swims, and the real two, out of sight
	for _, m in workspace:GetDescendants() do
		if m:IsA("Model") and m:GetAttribute("Rig") and not m:IsDescendantOf(stage) then
			for _, d in m:GetDescendants() do
				if d:IsA("BasePart") then
					d.LocalTransparencyModifier = 1
				elseif d:IsA("Highlight") or d:IsA("Trail") or d:IsA("ParticleEmitter") or d:IsA("Beam") or d:IsA("BillboardGui") then
					d.Enabled = false
				end
			end
		end
	end
	for _, d in player.Character:GetDescendants() do
		if d:IsA("BasePart") then
			d.LocalTransparencyModifier = 1
		elseif d:IsA("Highlight") or d:IsA("ParticleEmitter") or d:IsA("Trail") then
			d.Enabled = false
		end
	end
	for _, d in camera:GetChildren() do
		if d.Name == "Ink" and d:IsA("BasePart") then
			d.LocalTransparencyModifier = 1
		end
	end
	local scale = workspace:GetAttribute("EatScale") or 0.05
	local inks = stage:FindFirstChild("EatInk")
	if not inks then
		inks = Instance.new("Folder")
		inks.Name = "EatInk"
		inks.Parent = stage
	end
	local have = inks:GetChildren()
	for i = 1, math.max(#have, #a.Ink) do
		local part, row = have[i], a.Ink[i]
		if row and not part then
			part = Instance.new("Part")
			part.Anchored, part.CanCollide, part.CanQuery, part.CastShadow = true, false, false, false
			part.Material = Enum.Material.SmoothPlastic
			part.Parent = inks
		end
		part.Transparency = if row then 0 else 1
		if row then
			part.CFrame, part.Size, part.Color = row[1], row[2], row[3]
		end
	end
	for i, beat in take.Beats do
		if t >= beat.T and t < beat.T + 1.5 and not beatsDone[i] then
			beatsDone[i] = true
			realBurst(beat.At, 0, nil, beat.Reach)
			local p = Instance.new("Part")
			p.Anchored, p.CanCollide, p.CanQuery, p.Transparency = true, false, false, 1
			p.Size = Vector3.one
			p.CFrame = CFrame.new(beat.At)
			local e = Instance.new("ParticleEmitter")
			e.Rate = 0
			e.Lifetime = NumberRange.new(0.8, 1.4)
			e.SpreadAngle = Vector2.new(180, 180)
			e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(0.3, 0.45), NumberSequenceKeypoint.new(1, 0.6) })
			e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(0.75, 0.3), NumberSequenceKeypoint.new(1, 1) })
			e.LightEmission = 0.3
			e.Color = ColorSequence.new(Color3.fromRGB(225, 248, 255))
			local speed = (beat.Reach or 3) * 3
			e.Drag = 3
			e.Speed = NumberRange.new(speed * 0.7, speed * 1.2)
			e.Acceleration = Vector3.new(0, 7, 0)
			e.Parent = p
			p.Parent = stage
			puff(p, beat.N, scale)
		end
	end
	if shown ~= t then
		shown = t
		task.delay(0.15, function()
			report:FireServer("Shown", t)
		end)
	end
end)

workspace:GetAttributeChangedSignal("EatDo"):Connect(function()
	local cmd = tostring(workspace:GetAttribute("EatDo") or "")
	local verb, a = string.match(cmd, "^(%w+)|?([^|]*)")
	local ok, said = pcall(function()
		if verb == "new" then
			for id in Config.Fail.NewEat do
				Config.Fail.NewEat[id] = tonumber(a) or 0
			end
			return "NewEat " .. a
		elseif verb == "arm" then
			return arm()
		elseif verb == "armed" then
			return tostring(armed)
		elseif verb == "numbers" then
			return Http:JSONEncode(numbers())
		elseif verb == "stage" then
			return setStage()
		elseif verb == "unstage" then
			unstage()
			return "unstaged"
		elseif verb == "fps" then
			local n, total = 0, 0
			local c = RunService.RenderStepped:Connect(function(dt)
				n += 1
				total += dt
			end)
			task.wait(1)
			c:Disconnect()
			return tostring(math.floor(n / math.max(total, 0.01) + 0.5))
		end
		return "?"
	end)
	report:FireServer("Client", if ok then said else "error: " .. tostring(said))
end)
report:FireServer("Up", true)
'''

HELD = ("FailSlow", "FailClock", "DeathClock", "CatchLook", "TestSize", "EatT", "EatDo", "EatScale", "SandboxEndlessAir")


def install(remove=False):
    job = f"""local sss = game:GetService("ServerScriptService")
local sps = game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts")
for _, at in {{ sss, sps }} do
	local old = at:FindFirstChild("ZZEatClip")
	if old then old:Destroy() end
end
local RS = game:GetService("ReplicatedStorage")
for _, name in {{ "EatCmd", "EatSaid", "EatClient", "EatReady", "EatUp", "EatShown", "EatAhead", "EatOver" }} do RS:SetAttribute(name, nil) end
if {E.lua(remove)} then return "removed" end
local s = Instance.new("Script")
s.Name = "ZZEatClip"
s.Source = {E.lua(SERVER)}
s.Parent = sss
local c = Instance.new("LocalScript")
c.Name = "ZZEatClip"
c.Source = {E.lua(CLIENT)}
c.Parent = sps
return "installed"
"""
    with tempfile.NamedTemporaryFile("w", suffix=".luau", delete=False) as f:
        f.write(job)
    return E.run([f.name])


def cmd(c, wait=0.4):
    return E.last_line(E.server(
        f"local RS = game:GetService('ReplicatedStorage') RS:SetAttribute('EatCmd', {E.lua(c + '|' + str(time.time()))}) "
        f"task.wait({wait}) return RS:GetAttribute('EatSaid')"))


def do(c, wait=0.5):
    return E.last_line(E.server(
        f"local RS = game:GetService('ReplicatedStorage') RS:SetAttribute('EatClient', '') "
        f"workspace:SetAttribute('EatDo', {E.lua(c + '|' + str(time.time()))}) "
        f"local till = os.clock() + {wait} + 6 task.wait({wait}) "
        "while os.clock() < till and RS:GetAttribute('EatClient') == '' do task.wait(0.1) end "
        "return RS:GetAttribute('EatClient')"))


def wait_state(want, timeout=40):
    end, s = time.time() + timeout, ""
    while time.time() < end:
        s = cmd("state", 0.15)
        if s in want:
            return s
        time.sleep(0.3)
    raise SystemExit(f"state stayed {s}, wanted {want}")


def play():
    if E.playing() is not False:
        # (our own, left up by a run before: its helper is the one installed)
        said = E.last_line(E.server("return tostring(game:GetService('ReplicatedStorage'):GetAttribute('EatUp'))"))
        if "true" in said:
            return "already up (ours)"
        raise SystemExit("refused: a playtest that is not ours is running")
    print("install:", install())
    print(E.last_line(E.play(True)))
    end = time.time() + 120
    while time.time() < end:
        if E.playing() and "true" in E.last_line(
                E.server("return tostring(game:GetService('ReplicatedStorage'):GetAttribute('EatUp'))")):
            time.sleep(3)
            return "up, fps " + do("fps", 1.4)
        time.sleep(1.5)
    raise SystemExit("the playtest never came up")


def stop():
    if E.playing() is False:
        print(install(True))
        return
    print(E.setw(**{k: None for k in HELD}))
    print(E.last_line(E.play(False)))
    end = time.time() + 120  # (the runner lists the old server for up to two minutes)
    time.sleep(5)
    while E.playing() is not False and time.time() < end:
        time.sleep(3)
    print(install(True))


def ride(fish, size, place, new):
    E.setw(Sandbox=True, SandboxEndlessAir=True, TestMaxOxygen=None, CatchLook=0, FailSlow=1, FailClock=-1, DeathClock=-1,
           TestSize=size, EatT=None)
    do(f"new|{new}", 0.1)
    print(cmd(f"ride|{fish}|{place}", 1.0))
    wait_state({"Riding"})
    E.setw(TestSize=None)
    time.sleep(1.2)


def live(fish, size, place, new):
    """One live fail, recorded; its numbers"""
    for _ in range(40):  # (just started it is still loading; or the PC is busy with something else)
        fps = do("fps", 1.2)
        if int(fps or 0) >= 55:
            break
        time.sleep(4)
    if int(fps or 0) < 52:
        raise SystemExit(f"refused: {fps} fps")
    ride(fish, size, place, new)
    print(do("arm", 0.2))
    time.sleep(0.6)
    print(cmd("fail|", 0.2))
    wait_state({"Dock"}, 60)
    time.sleep(0.5)
    n = json.loads(do("numbers", 0.5))
    rows = n.pop("Rows")
    OUT.mkdir(parents=True, exist_ok=True)
    (OUT / f"live_{fish}_{size}_{place}_{new}.txt").write_text(json.dumps(n) + "\n" + "\n".join(rows))
    print(f"{fish} {size} {place} new {new} fps {fps}:", json.dumps(n))
    return n


def moved(a, b):
    """How much two pictures differ (mean grey levels), over their lower part: the water's top moves by itself"""
    d = ImageChops.difference(*(im.convert("L").resize((330, 170)).crop((0, 110, 330, 170)) for im in (a, b))).histogram()
    return sum(i * n for i, n in enumerate(d)) / (330 * 60)


def film(fish, size, place, new, fps, a, b, out):
    n = live(fish, size, place, new)
    kind = (n.get("Probe") or {}).get("Kind")
    E.setw(FailSlow=200, FailClock=0, DeathClock=0)
    E.setw(TestSize=size)
    print(cmd(f"ride|{fish}|{place}", 1.0))
    wait_state({"Riding"})
    E.setw(TestSize=None)
    time.sleep(1.0)
    print(cmd(f"fail|{kind or ''}", 0.3))
    print(do("stage", 0.3))
    E.setw(EatScale=round(1 / fps / 0.85, 4), EatT=a)
    time.sleep(2.0)
    folder = FRAMES / out
    shutil.rmtree(folder, ignore_errors=True)
    folder.mkdir(parents=True)
    count = int(round((b - a) * fps)) + 1
    began, last, again = time.time(), None, 0
    try:
        for i in range(count):
            t = a + i / fps
            E.server(f"local RS = game:GetService('ReplicatedStorage') workspace:SetAttribute('FailClock', {max(t, 0)}) "
                     f"workspace:SetAttribute('EatT', {t}) local till = os.clock() + 2 "
                     f"while os.clock() < till and math.abs((RS:GetAttribute('EatShown') or -9) - {t}) > 1e-3 do task.wait() end")
            for _ in range(4):  # (now and then the picture is still the one before: taken again)
                got = E.capture(OUT / "_shot.png")
                if not got:
                    raise SystemExit(f"no capture at frame {i}")
                shot = Image.open(got).convert("RGB").crop(CROP)
                if last is None or moved(shot, last) > 0.25:
                    break
                again += 1
                time.sleep(0.4)
            last = shot
            shot.save(folder / f"{i:04d}.jpg", quality=94)
        print(f"{count} frames, {(time.time() - began) / count:.2f} s each, {again} taken again")
    finally:
        print(do("unstage", 0.2))
        E.setw(FailClock=-1, DeathClock=-1, FailSlow=1, EatT=None, SandboxEndlessAir=None)
        print(cmd("home", 1.0))
    return encode(out, fps)


def encode(out, fps):
    dest = OUT / f"{out}.mp4"
    subprocess.run([FFMPEG, "-y", "-loglevel", "error", "-framerate", str(fps), "-i", str(FRAMES / out / "%04d.jpg"), "-vf",
                    "scale=1280:-2:flags=lanczos", "-c:v", "libx264", "-crf", "18", "-pix_fmt", "yuv420p", "-movflags",
                    "+faststart", str(dest)], check=True)
    print(dest)
    return dest


def sheet(out, times, dest, a=0.0, fps=30, cols=4, width=640):
    cells = []
    for t in times:
        im = Image.open(FRAMES / out / f"{int(round((t - a) * fps)):04d}.jpg")
        cells.append(im.resize((width, round(im.height * width / im.width)), Image.LANCZOS))
    w, h = cells[0].size
    rows = (len(cells) + cols - 1) // cols
    page = Image.new("RGB", (w * cols, h * rows))
    from PIL import ImageDraw, ImageFont
    d = ImageDraw.Draw(page)
    for i, (im, t) in enumerate(zip(cells, times)):
        at = (i % cols * w, i // cols * h)
        page.paste(im, at)
        d.text((at[0] + 10, at[1] + 8), f"{t:.2f} s", fill="white", font=ImageFont.load_default(size=22), stroke_width=2,
               stroke_fill="black")
    page.save(dest, quality=90)
    return dest


if __name__ == "__main__":
    args = sys.argv[1:]
    opts = {"new": "1", "fps": "30", "from": "-0.3", "to": "", "out": "", "times": "1"}
    while any(x.startswith("--") for x in args):
        i = next(i for i, x in enumerate(args) if x.startswith("--"))
        opts[args[i][2:]] = args[i + 1]
        del args[i : i + 2]
    if not args:
        raise SystemExit(__doc__)
    what, rest = args[0], args[1:] + ["open"] * 3
    if what == "play":
        print(play())
    elif what == "stop":
        stop()
    elif what == "remove":
        print(install(True))
    elif what in ("check", "film"):
        print(play())
        fish, size, place = rest[0], rest[1], rest[2]
        new = int(opts["new"])
        if what == "check":
            for _ in range(int(opts["times"])):
                live(fish, size, place, new)
        else:
            to = float(opts["to"]) if opts["to"] else (3.0 if fish == "Octopus" else 2.3)
            film(fish, size, place, new, int(opts["fps"]), float(opts["from"]), to,
                 opts["out"] or f"{fish}_{size}_{place}_{new}".lower())
