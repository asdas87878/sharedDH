"""The leap off the dock (Config.Dive.Leap, src/client/Controllers/DiveController.luau): checked in a Studio playtest.
    python tools/studio/dive_leap_check.py install | remove   (in Edit, before Play: a server Script and a LocalScript)
    node ~/Projects/studio-runner/studio-run.mjs play
    python tools/studio/dive_leap_check.py run                (in the playtest: Leap on, then Leap 0 for the cost;
                                                               log work/dive_leap/check.log)
    python tools/studio/dive_leap_check.py run fish [ID]      (the same, with a fish equipped before each run: the
                                                               seated ride, so lip to Riding is measured)
    python tools/studio/dive_leap_check.py run sub [LAND]     (the same with a sub trip picked (land 2 by default),
                                                               recorded up to 30 s, to Riding + 3 or Drowning + 2:
                                                               the lowest point and the modes, Leap 1 and Leap 0)
    python tools/studio/dive_leap_check.py run look [T]       (Leap 1 only, the mouse pretended to look round at dive
                                                               time T (1.1 by default): when the film let the view
                                                               go, and how smoothly)
    python tools/studio/dive_leap_check.py hold T [own|director] [NAME]
                                                              (the whole dive held at dive time T, seconds, or at a
                                                               moment: crouch, takeoff, rise, top, entry, splash,
                                                               splash2 (entry + 0.3), under;
                                                               begun at the lip; "own": the dive's own camera, "director": a fixed
                                                               camera beside the arc; NAME: also a shot,
                                                               work/dive_leap/NAME.png)
    python tools/studio/dive_leap_check.py holds [own|director]  (held at each of those moments: shots)
    python tools/studio/dive_leap_check.py letgo              (lets a hold go and sends the player home)
How: Config.Dive.Leap is switched on at runtime on both machines (the place's Config is left as it ships, 0). The
server Script sends the player home (RideService.sendHome) before each run. The LocalScript finds the strip's lip itself
(from the dock spawn, Net.Folder's Dock attribute, out along its look until there is no ground under), stands the
player a run-up behind it facing the water, disables the controls and walks them off with Humanoid:Move, as a player
running at the water would. It records every render frame (after every camera step): the root, the camera, our mode;
and reads DiveController.log() (its events: start, top, entry, hop, release, handover) and Lib/Splash.stats().
For a hold the server's hooks RideService.Diving and RideService.DiveFish are stubbed (no sub trip, no seated fish:
the held body under the surface turns the server's state to Free only) and the client's Config.Dive.AutoHop is 0 (no
hop), both put back by letgo.
Reported, per run: where the dive began and how fast, seconds in the air, the top above the starting root and above the
lip's floor, the entry point, angle (degrees below level) and speed, the depth when the hop began, the seconds from
crossing the lip to the water, to the hop and to Riding (and the same with Leap 0: what the leap costs), the biggest
camera jump between two frames (studs and degrees) and when, the longest run of frames it stood still while the
diver moved, the frames the camera was inside a part, out of sight of the diver (a wall or floor between), under the
dock's floor, or in the water's lit layers (between its top and the riding camera's line), how far off the middle of
the view the diver got while the film was the view, the nearest splash block to the camera and the most of the view
one filled, the underwater look (Lighting's fog, the Atmosphere) as the camera went under and after, the splash parts
run, the mode changes, the lowest point, and errors. Each frame (frames_NAME.txt) also has the riding camera's view as
the film read it and the hand-over's blend, the fog, and the nearest splash block / its cover. DiveController's log is
emptied before each run.
Needs Studio open with the studio-runner plugin and this repo's code in the place.
"""
import json
import subprocess
import sys
import tempfile
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "work/dive_leap"
OUT.mkdir(parents=True, exist_ok=True)
RUN = str(Path.home() / "Projects/studio-runner/studio-run.mjs")

SERVER = r'''
local RS = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Services = game:GetService("ServerScriptService"):WaitForChild("Server"):WaitForChild("Services")
local RideService = require(Services:WaitForChild("RideService"))
local Config = require(RS:WaitForChild("Shared"):WaitForChild("Config"))
local report = Instance.new("RemoteEvent")
report.Name = "ZZDiveLeapReport"
report.Parent = RS
report.OnServerEvent:Connect(function(_, text)
	RS:SetAttribute("DLClient", tostring(text))
end)
local stubbed = false
local keptDiving, keptDiveFish = nil, nil
RS:GetAttributeChangedSignal("DLCmd"):Connect(function()
	local cmd = tostring(RS:GetAttribute("DLCmd") or "")
	local verb, arg = string.match(cmd, "^(%w+)|?([^|]*)")
	local player = Players:GetPlayers()[1]
	local ok, said = pcall(function()
		if verb == "leap" then
			Config.Dive.Leap = tonumber(arg) or 0
			return "server Leap=" .. tostring(Config.Dive.Leap)
		elseif verb == "home" then
			RideService.sendHome(player)
			return "home"
		elseif verb == "stub" then
			if not stubbed then
				keptDiving, keptDiveFish = RideService.Diving, RideService.DiveFish
				stubbed = true
			end
			RideService.Diving = function()
				return false
			end
			RideService.DiveFish = function()
				return nil
			end
			return "stubbed"
		elseif verb == "unstub" then
			if stubbed then
				RideService.Diving, RideService.DiveFish = keptDiving, keptDiveFish
				stubbed = false
			end
			return "unstubbed"
		elseif verb == "fish" then
			-- a fish in hand (the client equips it): the sub's hook seats it as we go under
			local id = if arg ~= "" then arg else (Config.Fish[1] and Config.Fish[1].Id)
			RideService.giveCarried(player, { Id = id, Size = "Normal", Variant = "" })
			return "hands " .. #RideService.carried(player) .. " (" .. tostring(id) .. ")"
		elseif verb == "sub" then
			-- a sub trip to land `arg` (0: none) picked for the next dive: coins, every sub bought, the land picked
			local test = game:GetService("ServerStorage"):WaitForChild("SubTest", 5)
			if not test then
				return "no SubTest (not Studio?)"
			end
			local land = tonumber(arg) or 0
			if land > 0 then
				test:Invoke("give", player.UserId, 1e12, {})
				for _ = 1, 9 do
					test:Invoke("buy", player.UserId)
				end
			end
			return "sub " .. tostring(test:Invoke("pick", player.UserId, land, ""))
		elseif verb == "state" then
			local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
			return string.format("state=%s attr=%s y=%s land=%s equipped=%s hands=%d", tostring(RideService.stateOf(player)),
				tostring(player:GetAttribute("State")), root and string.format("%.1f", root.Position.Y) or "?",
				tostring(player:GetAttribute("LandMounted")), tostring(RideService.equippedOf(player) ~= nil),
				#RideService.carried(player))
		end
		return "?"
	end)
	RS:SetAttribute("DLSaid", tostring(said) .. (if ok then "" else " (error)"))
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
local Dive = require(Client:WaitForChild("Controllers"):WaitForChild("DiveController"))
local Ride = require(Client.Controllers:WaitForChild("RideController"))
local Splash = require(Client:WaitForChild("Lib"):WaitForChild("Splash"))
local Lighting = game:GetService("Lighting")
local State = require(Client.Lib:WaitForChild("State"))
local Config = require(RS:WaitForChild("Shared"):WaitForChild("Config"))
local Net = require(RS.Shared:WaitForChild("Net"))
local report = RS:WaitForChild("ZZDiveLeapReport", 60)
local UP = Vector3.yAxis
local FLAT = Vector3.new(1, 0, 1)
local camera = workspace.CurrentCamera

local errors = {}
LogService.MessageOut:Connect(function(text, kind)
	if kind == Enum.MessageType.MessageError or (kind == Enum.MessageType.MessageWarning
		and (string.find(text, "Dive") or string.find(text, "Splash") or string.find(text, "Anim")
			or string.find(text, "Ride") or string.find(text, "Jump"))) then
		if #errors < 20 then
			table.insert(errors, string.sub(text, 1, 200))
		end
	end
end)

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

local function params(extra)
	local p = RaycastParams.new()
	p.FilterType = Enum.RaycastFilterType.Exclude
	local list = { camera }
	for _, other in Players:GetPlayers() do
		if other.Character then
			table.insert(list, other.Character)
		end
	end
	for _, e in extra or {} do
		table.insert(list, e)
	end
	p.FilterDescendantsInstances = list
	p.RespectCanCollide = true
	p.IgnoreWater = true
	return p
end

local function groundUnder(at)
	local hit = workspace:Raycast(at, -UP * 40, params())
	return hit and hit.Position.Y or nil
end

-- The lip: out from the dock spawn along its look until there is no ground under. The lip point (on the floor), the
-- floor's top, the way out.
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
		local top = groundUnder(at)
		if not top then
			if not floor then
				return nil
			end
			local edge = from + out * math.max(step * 0.5 - 0.5, 0)
			return Vector3.new(edge.X, floor, edge.Z), floor, out
		end
		floor = top
	end
	return nil
end

local function v3(v)
	return { math.floor(v.X * 10 + 0.5) / 10, math.floor(v.Y * 10 + 0.5) / 10, math.floor(v.Z * 10 + 0.5) / 10 }
end

local function clean(t)
	-- a table JSON can carry: Vector3s to lists, CFrames to their positions
	if typeof(t) == "Vector3" then
		return v3(t)
	elseif typeof(t) == "CFrame" then
		return v3(t.Position)
	elseif type(t) == "table" then
		local out = {}
		for k, v in t do
			out[k] = clean(v)
		end
		return out
	elseif type(t) == "number" then
		return math.floor(t * 1000 + 0.5) / 1000
	end
	return t
end

local function eventsOf(log)
	local out = {}
	for _, e in log.events or {} do
		out[e.kind] = out[e.kind] or clean(e)
	end
	return out
end

-- The splash's blocks seen from the camera: the nearest one showing (its distance from the eye, less its half size),
-- and the most of the view any one in front fills (its angular size over the view's half height, times how opaque)
local function splashSeen()
	local folder = camera:FindFirstChild("LeapSplash")
	if not folder then
		return math.huge, 0
	end
	local eye = camera.CFrame.Position
	local look = camera.CFrame.LookVector
	local half = math.tan(math.rad(camera.FieldOfView) / 2)
	local nearest, cover = math.huge, 0
	for _, part in folder:GetChildren() do
		if part:IsA("BasePart") and part.Transparency < 0.98 then
			local d = part.Position - eye
			local r = part.Size.Magnitude / 2
			nearest = math.min(nearest, math.max(d.Magnitude - r, 0))
			local along = d:Dot(look)
			if along > 0.05 then
				local side = (d - look * along).Magnitude
				if side < r + along * half then
					cover = math.max(cover, math.min(r / (along * half), 1) * (1 - part.Transparency))
				end
			elseif d.Magnitude < r then
				cover = math.max(cover, 1 - part.Transparency)
			end
		end
	end
	return nearest, cover
end

local function lookNow()
	return {
		fogStart = math.floor(Lighting.FogStart + 0.5),
		fogEnd = math.floor(Lighting.FogEnd + 0.5),
		fogColor = tostring(Lighting.FogColor),
		atmosphere = Lighting:FindFirstChildOfClass("Atmosphere") ~= nil,
	}
end

-- One run: stood a run-up behind the lip, walked off it, recorded until riding (or the time is up). `lookAt`: at this
-- dive time the mouse is pretended to look round (DiveController.pretendLook), nil for none. `seconds`: the longest it
-- records. `sub`: a sub trip is picked (it ends on Riding + 3 or Drowning + 2, not on Carried)
local lastFrames = {}
local function walk(leap, runup, lookAt, seconds, sub)
	table.clear(errors)
	Config.Dive.Leap = leap
	seconds = seconds or 14
	if Dive.clearLog then
		Dive.clearLog()
	end
	local lipAt, floor, out = lip()
	if not lipAt then
		return { error = "no lip found (no Dock attribute, or no ground out from the spawn)" }
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid then
		return { error = "no character" }
	end
	local height = if humanoid.RigType == Enum.HumanoidRigType.R15 then humanoid.HipHeight + root.Size.Y / 2 else 3
	local stand = lipAt - out * runup + UP * (height + 0.2)
	controls(false)
	humanoid:Move(Vector3.zero)
	character:PivotTo(CFrame.lookAt(stand, stand + out))
	root.AssemblyLinearVelocity = Vector3.zero
	task.wait(1.0)
	local before = Splash.stats()
	local started = os.clock()
	local rec = {
		leap = leap,
		lip = v3(lipAt),
		runup = runup,
		modeAtStart = State.Mode,
		attrAtStart = player:GetAttribute("State"),
	}
	local frames = {}
	local modes = {}
	local lastMode = State.Mode
	local lipT, waterT, jumpT, rideT, carriedT, leapT, drownT = nil, nil, nil, nil, nil, nil, nil
	local maxY, lowY = -math.huge, math.huge
	local prevPos = nil
	local stillRun, stillMost, stillAt = 0, 0, nil
	local bandFrames, bandFilmFrames, bandFirst, bandLast = 0, 0, nil, nil
	local nearMin, nearAt, coverMost, coverAt = math.huge, nil, 0, nil
	local frameX, frameY, frameYAt, framed = 0, 0, nil, 0
	local backUnder, backUnderAt = math.huge, nil -- the camera's least distance from the diver, both under water, filming
	local fogs = {}
	local underSince = nil
	local looked = nil
	local line = Ride.waterLine()
	local top = Config.Camera.WaterTop
	local maxParts = 0
	local plan = nil
	local prevCam = nil
	local jumpStuds, jumpDeg, jumpAtT, jumpMode = 0, 0, nil, nil
	local blocked, inside, underFloor, camFrames = 0, 0, 0, 0
	local firstBlocked = nil
	local done = false
	-- the frame times: each frame's own, and the worst from the root going under to 1.5 s after (Leap 1 and 0 alike)
	local inT = nil
	local worstDt, worstAt, worstMode, windowDts = 0, nil, nil, {}
	RunService:BindToRenderStep("ZZDiveLeapRecord", Enum.RenderPriority.Camera.Value + 20, function(dt: number)
		local now = os.clock() - started
		local r = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if not r then
			return
		end
		local pos = r.Position
		if not inT and pos.Y < Config.Camera.WaterTop then
			inT = now
		end
		if inT and now - inT <= 1.5 then
			table.insert(windowDts, dt)
			if dt > worstDt then
				worstDt, worstAt, worstMode = dt, now - inT, State.Mode
			end
		end
		local cam = camera.CFrame
		maxY = math.max(maxY, pos.Y)
		lowY = math.min(lowY, pos.Y)
		if not lipT and (pos - lipAt):Dot(out) > 0 then
			lipT = now
		end
		if State.Mode ~= lastMode then
			table.insert(modes, string.format("%.2f %s>%s", now, lastMode, State.Mode))
			lastMode = State.Mode
		end
		if not waterT and State.Mode ~= "Dock" then
			waterT = now
		end
		if not jumpT and State.Mode == "Jumping" then
			jumpT = now
		end
		if not rideT and State.Mode == "Riding" then
			rideT = now
		end
		if not carriedT and State.Mode == "Carried" then
			carriedT = now
		end
		if not drownT and State.Mode == "Drowning" then
			drownT = now
		end
		if not leapT and State.Leaping then
			leapT = now
		end
		local log = Dive.log()
		if log.plan then
			plan = log.plan
		end
		-- the mouse pretended to look round at dive time lookAt
		if lookAt and leapT and not looked and now - leapT >= lookAt and log.filming then
			Dive.pretendLook(Vector2.new(60, 0))
			looked = now - leapT
		end
		local stats = Splash.stats()
		maxParts = math.max(maxParts, stats.parts)
		local last = log.frames and log.frames[#log.frames]
		local liveText = ""
		if log.filming and last and last.live then
			liveText = string.format(" live=(%.1f,%.1f,%.1f) blend=%.2f", last.live.X, last.live.Y, last.live.Z, last.blend)
		elseif log.filming and last then
			liveText = string.format(" blend=%.2f", last.blend)
		end
		local nearest, cover = splashSeen()
		-- the camera: from the dive's start on, while it moves
		if leapT or (leap <= 0 and lipT) then
			camFrames += 1
			if prevCam then
				local d = (cam.Position - prevCam.Position).Magnitude
				local _, angle = (prevCam.Rotation:Inverse() * cam.Rotation):ToAxisAngle()
				local deg = math.deg(math.abs(angle))
				if d > jumpStuds then
					jumpStuds, jumpAtT, jumpMode = d, now, State.Mode
				end
				jumpDeg = math.max(jumpDeg, deg)
				-- still while the diver moves away
				if d < 0.05 and prevPos and (pos - prevPos).Magnitude > 0.3 then
					stillRun += 1
					if stillRun > stillMost then
						stillMost, stillAt = stillRun, now
					end
				else
					stillRun = 0
				end
			end
			prevCam = cam
			-- in the water's lit layers (between the surface and the riding camera's line)
			if cam.Position.Y < top and cam.Position.Y > line then
				bandFrames += 1
				bandFirst = bandFirst or now
				bandLast = now
				if log.filming then
					bandFilmFrames += 1
				end
			end
			if nearest < nearMin then
				nearMin, nearAt = nearest, now
			end
			if cover > coverMost then
				coverMost, coverAt = cover, now
			end
			-- where the diver is in the view while the film is the view
			if log.filming and last and last.blend < 0.5 then
				local vp = camera:WorldToViewportPoint(pos + UP * 0.6)
				local size = camera.ViewportSize
				local x, y = vp.X / size.X * 2 - 1, vp.Y / size.Y * 2 - 1
				if vp.Z > 0 then
					framed += 1
					frameX = math.max(frameX, math.abs(x))
					if math.abs(y) > frameY then
						frameY, frameYAt = math.abs(y), now
					end
				end
				if cam.Position.Y < top and pos.Y < top and (cam.Position - pos).Magnitude < backUnder then
					backUnder, backUnderAt = (cam.Position - pos).Magnitude, now
				end
			end
			-- the underwater look as the camera goes under, and on
			if cam.Position.Y < top then
				underSince = underSince or now
				for _, after in { 0, 0.25, 1 } do
					local key = string.format("%.2f", after)
					if not fogs[key] and now - underSince >= after then
						local l = lookNow()
						l.camY = math.floor(cam.Position.Y * 10 + 0.5) / 10
						l.at = math.floor(now * 100 + 0.5) / 100
						fogs[key] = l
					end
				end
			elseif not fogs.above then
				fogs.above = lookNow()
			end
			local p = params()
			local head = pos + UP * 1.5
			local sight = workspace:Raycast(head, cam.Position - head, p)
			if sight then
				blocked += 1
				firstBlocked = firstBlocked or string.format("%.2f %s by %s", now, State.Mode, sight.Instance:GetFullName())
			end
			local touching = workspace:GetPartBoundsInRadius(cam.Position, 0.2)
			for _, part in touching do
				if part.CanCollide and not part:IsDescendantOf(camera)
					and not (player.Character and part:IsDescendantOf(player.Character)) then
					inside += 1
					break
				end
			end
			-- under the dock's floor while the diver is still above it
			if cam.Position.Y < floor and pos.Y > floor then
				local over = workspace:Raycast(cam.Position, UP * 30, p)
				if over then
					underFloor += 1
				end
			end
		end
		if #frames < 2400 then
			table.insert(frames, string.format(
				"%.3f dt=%.1fms %s pos=(%.1f,%.1f,%.1f) cam=(%.1f,%.1f,%.1f) fov=%.1f leaping=%s ls=%s%s fog=%d-%d atm=%s splash=%s",
				now, dt * 1000, State.Mode, pos.X, pos.Y, pos.Z, cam.Position.X, cam.Position.Y, cam.Position.Z,
				camera.FieldOfView, tostring(State.Leaping), tostring(State.LeapSplashed), liveText, math.floor(Lighting.FogStart), math.floor(Lighting.FogEnd),
				tostring(Lighting:FindFirstChildOfClass("Atmosphere") ~= nil),
				if nearest < math.huge then string.format("%.1f/%.2f", nearest, cover) else "-"))
		end
		prevPos = pos
		humanoid:Move(if State.Mode == "Dock" and not State.Leaping then out else Vector3.zero)
		if now > seconds or (rideT and now > rideT + 3) or (drownT and now > drownT + 2)
			or (not sub and carriedT and now > carriedT + 3) then
			done = true
		end
	end)
	while not done do
		task.wait(0.1)
	end
	RunService:UnbindFromRenderStep("ZZDiveLeapRecord")
	humanoid:Move(Vector3.zero)
	controls(true)
	lastFrames = frames
	local log = Dive.log()
	local ev = eventsOf(log)
	local after = Splash.stats()
	local function since(t)
		return if t and lipT then math.floor((t - lipT) * 100 + 0.5) / 100 else nil
	end
	rec.lipCrossedAt = lipT and math.floor(lipT * 100) / 100
	rec.lipToWater = since(waterT)
	rec.lipToHop = since(jumpT)
	rec.lipToRiding = since(rideT)
	rec.lipToCarried = since(carriedT)
	rec.lipToDrowning = since(drownT)
	rec.lowestY = math.floor(lowY * 10 + 0.5) / 10
	table.sort(windowDts)
	rec.frameTime = {
		-- from the root going under to 1.5 s after: the worst single frame (ms, seconds after going under, the mode)
		-- and the median
		worstMs = math.floor(worstDt * 10000 + 0.5) / 10,
		worstAfterIn = worstAt and math.floor(worstAt * 1000 + 0.5) / 1000,
		worstMode = worstMode,
		medianMs = if #windowDts > 0
			then math.floor(windowDts[math.ceil(#windowDts / 2)] * 10000 + 0.5) / 10
			else nil,
		frames = #windowDts,
	}
	rec.leapBegan = leapT ~= nil
	rec.lookPretendedAt = looked and math.floor(looked * 1000 + 0.5) / 1000
	local function r2(v)
		return v and math.floor(v * 100 + 0.5) / 100
	end
	rec.framing = {
		-- the diver's root (0.6 up) in the view while the film was the view: -1 to 1 from the middle (1/3: the
		-- middle third's edge)
		frames = framed,
		mostAcross = r2(frameX),
		mostUpDown = r2(frameY),
		upDownAt = r2(frameYAt),
		-- the least camera-to-diver distance with both under water (the bar: 10 studs or more)
		leastBackUnder = if backUnder < math.huge then r2(backUnder) else nil,
		leastBackAt = r2(backUnderAt),
	}
	rec.layers = {
		-- frames the camera spent between the water's top and the riding camera's line (the lit layers)
		frames = bandFrames,
		whileFilming = bandFilmFrames,
		from = r2(bandFirst),
		to = r2(bandLast),
		line = r2(line),
	}
	rec.splashNear = {
		nearest = if nearMin < math.huge then r2(nearMin) else nil,
		at = r2(nearAt),
		mostCover = r2(coverMost),
		coverAt = r2(coverAt),
	}
	rec.look = fogs
	rec.trigger = ev.start
	rec.top = ev.top
	rec.entry = ev.entry
	rec.hop = ev.hop
	rec.release = ev.release
	rec.handover = ev.handover
	rec.cameraLetGo = ev.camera
	rec.took = ev.took
	rec.plan = clean(plan)
	if plan and ev.start then
		rec.secondsInAir = math.floor((plan.tEntry - (ev.start.crouch or 0)) * 1000 + 0.5) / 1000
	end
	rec.topAboveLipFloor = math.floor((maxY - floor) * 10 + 0.5) / 10
	rec.standingRootAboveFloor = math.floor(height * 10 + 0.5) / 10
	rec.camera = {
		frames = camFrames,
		biggestJumpStuds = math.floor(jumpStuds * 100 + 0.5) / 100,
		biggestTurnDegrees = math.floor(jumpDeg * 10 + 0.5) / 10,
		jumpAt = jumpAtT and string.format("%.2f %s", jumpAtT, tostring(jumpMode)),
		outOfSightFrames = blocked,
		firstOutOfSight = firstBlocked,
		insidePartFrames = inside,
		underDockFloorFrames = underFloor,
		-- the longest run of frames it stood still (under 0.05 studs) while the diver moved over 0.3
		stillWhileDiverMoved = stillMost,
		stillAt = stillAt and string.format("%.2f", stillAt),
	}
	rec.splash = { played = after.played - before.played, mostParts = maxParts, runningAtEnd = after.running }
	rec.modes = modes
	rec.broken = log.broken
	rec.landMounted = player:GetAttribute("LandMounted")
	rec.errors = table.clone(errors)
	return rec
end

-- The director's camera for holds: beside the arc, fixed
local director = nil
local function directorOn(on)
	director = nil
	RunService:UnbindFromRenderStep("ZZDiveLeapDirector")
	if not on then
		director = nil
		camera.CameraType = Enum.CameraType.Custom
		return
	end
	RunService:BindToRenderStep("ZZDiveLeapDirector", Enum.RenderPriority.Camera.Value + 10, function()
		local plan = Dive.log().plan
		if plan and not director then
			local s, e = plan.start, plan.entry
			local way = ((e - s) * FLAT).Unit
			local right = way:Cross(UP)
			local mid = (s + e) / 2
			local at = mid + right * 30 + UP * 4 - way * 2
			director = CFrame.lookAt(at, mid + UP * 2)
		end
		if director then
			camera.CameraType = Enum.CameraType.Scriptable
			camera.CFrame = director
			camera.FieldOfView = 70
		end
	end)
end

local keptAutoHop = nil
workspace:GetAttributeChangedSignal("DLDo"):Connect(function()
	local cmd = tostring(workspace:GetAttribute("DLDo") or "")
	local verb, a, b, c, e, f = string.match(cmd, "^(%w+)|?([^|]*)|?([^|]*)|?([^|]*)|?([^|]*)|?([^|]*)")
	local ok, said = pcall(function()
		if verb == "walk" then
			-- walk|leap|runup|lookAt|seconds|sub (empty: none)
			report:FireServer("running")
			task.spawn(function()
				local ok2, rec = pcall(walk, tonumber(a) or 1, tonumber(b) or 16, tonumber(c), tonumber(e), f == "1")
				if not ok2 then
					controls(true)
					rec = { error = tostring(rec) }
				end
				report:FireServer(Http:JSONEncode(rec))
			end)
			return nil
		elseif verb == "frames" then
			-- the last run's frames, every nth
			local every = tonumber(a) or 1
			local out = {}
			for i = 1, #lastFrames, every do
				table.insert(out, lastFrames[i])
			end
			return table.concat(out, "\n")
		elseif verb == "hold" then
			if keptAutoHop == nil then
				keptAutoHop = Config.Dive.AutoHop
			end
			Config.Dive.AutoHop = 0
			Config.Dive.Leap = 1
			local view = if b ~= "" then b else "own"
			if view == "director" then
				directorOn(true)
			else
				directorOn(false)
			end
			-- a time, or a moment by name (from the plan: crouch, takeoff, rise, top, entry, splash, splash2, under)
			local t = tonumber(a)
			if not t then
				Dive.hold(0, view == "director")
				local first = Dive.log()
				local p = first.plan
				local crouch = (eventsOf(first).start or {}).crouch or 0
				if not p then
					return "no plan at the lip"
				end
				t = ({
					crouch = crouch * 0.6,
					takeoff = crouch + 0.04,
					-- (the low look up from beside the lip: the camera's first key)
					rise = crouch + 0.28 * (p.tEntry - crouch),
					top = p.tTop,
					entry = p.tEntry - 0.02,
					splash = p.tEntry + 0.15,
					splash2 = p.tEntry + 0.3,
					under = p.tEntry + 0.5,
				})[a] or 0
			end
			local held = Dive.hold(t, view == "director")
			local log = Dive.log()
			return Http:JSONEncode({ held = held, t = t, name = a, view = view, plan = clean(log.plan),
				splash = log.splash, mode = State.Mode, events = eventsOf(log) })
		elseif verb == "letgo" then
			Dive.hold(nil)
			directorOn(false)
			if keptAutoHop ~= nil then
				Config.Dive.AutoHop = keptAutoHop
				keptAutoHop = nil
			end
			return "let go"
		elseif verb == "equip" then
			local Equip = require(Client.Controllers:WaitForChild("EquipController"))
			-- 1 holds the slot's fish, Q makes the held fish the ride fish (EquipController: two presses, no chord)
			Equip.press(Enum.KeyCode.One)
			task.wait(0.4)
			Equip.press(Enum.KeyCode.Q)
			task.wait(0.6)
			return "equipped=" .. tostring(player:GetAttribute("EquippedFish")) .. "; LandMounted="
				.. tostring(player:GetAttribute("LandMounted"))
		elseif verb == "status" then
			-- after a dive: is everything given back?
			local character = player.Character
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			local fx = camera:FindFirstChild("RideFx")
			local stats = Splash.stats()
			return Http:JSONEncode({ mode = State.Mode, leaping = State.Leaping, leapSplashed = State.LeapSplashed,
				camera = camera.CameraType.Name,
				platformStand = humanoid and humanoid.PlatformStand, humanoid = humanoid and humanoid:GetState().Name,
				attr = player:GetAttribute("State"), rideFx = fx and #fx:GetChildren() or -1, splash = stats })
		elseif verb == "leap" then
			Config.Dive.Leap = tonumber(a) or 0
			return "client Leap=" .. tostring(Config.Dive.Leap)
		elseif verb == "set" then
			-- any Config.Dive number on this machine, for a look (set|Flip|1); put it back yourself
			if Config.Dive[a] == nil or not tonumber(b) then
				return "no Config.Dive." .. tostring(a)
			end
			local was = Config.Dive[a]
			Config.Dive[a] = tonumber(b)
			return "client Config.Dive." .. a .. "=" .. tostring(Config.Dive[a]) .. " (was " .. tostring(was) .. ")"
		end
		return "?"
	end)
	if not ok then
		report:FireServer("error: " .. tostring(said))
	elseif said ~= nil then
		report:FireServer(said)
	end
end)
'''


def run(args, timeout=120):
    r = subprocess.run(["node", RUN, *args], capture_output=True, text=True, timeout=timeout)
    return (r.stdout + r.stderr).strip()


def lua(v):
    if isinstance(v, bool):
        return "true" if v else "false"
    return "[==[" + str(v) + "]==]"


def server(code):
    return run(["--ctx", "server", "--code", code])


def install(remove=False):
    job = f"""local sss = game:GetService("ServerScriptService")
local sps = game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts")
for _, at in {{ sss, sps }} do
	local old = at:FindFirstChild("ZZDiveLeapCheck")
	if old then old:Destroy() end
end
workspace:SetAttribute("DLDo", nil)
if {lua(remove)} then
	return "removed"
end
local s = Instance.new("Script")
s.Name = "ZZDiveLeapCheck"
s.Source = {lua(SERVER)}
s.Parent = sss
local c = Instance.new("LocalScript")
c.Name = "ZZDiveLeapCheck"
c.Source = {lua(CLIENT)}
c.Parent = sps
return "installed"
"""
    with tempfile.NamedTemporaryFile("w", suffix=".luau", delete=False) as f:
        f.write(job)
    return run([f.name])


def cmd(c, wait=0.8):
    """A verb for the server Script"""
    return server(
        f"local RS = game:GetService('ReplicatedStorage') RS:SetAttribute('DLCmd', {lua(c + '|' + str(time.time()))}) "
        f"task.wait({wait}) return RS:GetAttribute('DLSaid')"
    )


def do(c, wait=1.0):
    """A verb for the LocalScript; its answer comes back through the server"""
    return server(
        f"local RS = game:GetService('ReplicatedStorage') RS:SetAttribute('DLClient', '') "
        f"workspace:SetAttribute('DLDo', {lua(c + '|' + str(time.time()))}) "
        f"task.wait({wait}) return RS:GetAttribute('DLClient')"
    )


def client_now():
    return server("return game:GetService('ReplicatedStorage'):GetAttribute('DLClient')")


def shot(name):
    path = OUT / f"{name}.png"
    path.unlink(missing_ok=True)
    out = run(["shot", str(path)], timeout=60)
    end = time.time() + 10
    while time.time() < end and not path.exists():
        time.sleep(0.2)
    return str(path) if path.exists() else "no shot: " + out


LOG = []


def say(*parts):
    line = " ".join(str(p) for p in parts)
    print(line, flush=True)
    LOG.append(line)


def strip_runner(text):
    """The runner's answer may carry its own lines round the returned value: the JSON part"""
    start, end = text.find("{"), text.rfind("}")
    return text[start : end + 1] if start >= 0 and end > start else text


def home():
    say("home:", cmd("home", 2.5))
    for _ in range(20):
        s = cmd("state", 0.3)
        if "state=Dock" in s:
            return s
        time.sleep(0.5)
    return cmd("state", 0.3)


def walk(leap, runup=16, name="leap", fish=None, look=None, seconds=14, sub=None):
    """One run off the lip; the record, and the frames saved to work/dive_leap/frames_NAME.txt. `fish`: a fish id
    ("" for the first kind) to have equipped first (the seated ride as we go under). `look`: the dive time to pretend
    the mouse looks round at. `sub`: a land to pick a sub trip to"""
    say(cmd(f"leap|{leap}"))
    say("before:", home())
    if sub is not None:
        say("sub:", cmd(f"sub|{sub}", 2.0))
    if fish is not None:
        s = cmd("state", 0.3)
        if "equipped=true" not in s:
            if "hands=0" in s:
                say("fish:", cmd("fish|" + fish, 1.0))
            say("equip:", do("equip", 1.2))
            say("now:", cmd("state", 0.3))
    time.sleep(1.0)
    do(f"walk|{leap}|{runup}|{'' if look is None else look}|{seconds}|{'1' if sub is not None else ''}", 0.5)
    end = time.time() + seconds + 26
    text = ""
    while time.time() < end:
        time.sleep(1.5)
        text = client_now()
        if "{" in text:
            break
    rec = {}
    try:
        rec = json.loads(strip_runner(text))
    except ValueError:
        say(f"{name}: no record:", text[:400])
        return {}
    # (the runner's answer is cut at about 20,000 characters: a long run is sampled more thinly)
    frames = do(f"frames|{3 if seconds <= 14 else 8}", 1.0)
    (OUT / f"frames_{name}.txt").write_text(frames + "\n")
    (OUT / f"run_{name}.json").write_text(json.dumps(rec, indent=1))
    return rec


def summary(name, rec):
    if not rec:
        return
    if rec.get("error"):
        say(f"[{name}] error:", rec["error"])
        return
    say(f"[{name}] Leap={rec.get('leap')} lip={rec.get('lip')} run-up={rec.get('runup')} start mode={rec.get('modeAtStart')}")
    t = rec.get("trigger") or {}
    say(f"  trigger: began={rec.get('leapBegan')} at={t.get('pos')} speed={t.get('speed')} crouch={t.get('crouch')}"
        f" planned high={t.get('high')} far={t.get('far')}")
    say(f"  in the air: {rec.get('secondsInAir')} s; top above start root={ (rec.get('top') or {}).get('height')}"
        f"; root's top above the lip's floor={rec.get('topAboveLipFloor')} (standing: {rec.get('standingRootAboveFloor')})")
    e = rec.get("entry") or {}
    say(f"  entry: at={e.get('pos')} angle={e.get('angle')} deg below level, speed={e.get('speed')}")
    say(f"  hop began at depth={(rec.get('hop') or {}).get('depth')}; body let go: {rec.get('release')}")
    say(f"  lip to water={rec.get('lipToWater')} s, to hop={rec.get('lipToHop')} s, to Riding={rec.get('lipToRiding')} s,"
        f" to Carried={rec.get('lipToCarried')} s, to Drowning={rec.get('lipToDrowning')} s; lowest y={rec.get('lowestY')}")
    c = rec.get("camera") or {}
    say(f"  camera: biggest jump {c.get('biggestJumpStuds')} studs at {c.get('jumpAt')}, biggest turn"
        f" {c.get('biggestTurnDegrees')} deg; still while the diver moved {c.get('stillWhileDiverMoved')} frames"
        f" (at {c.get('stillAt')}); out of sight {c.get('outOfSightFrames')}/{c.get('frames')} frames"
        f" (first: {c.get('firstOutOfSight')}), inside a part {c.get('insidePartFrames')}, under the dock floor"
        f" {c.get('underDockFloorFrames')}")
    say(f"  hand-over: began={rec.get('handover')} let go={rec.get('cameraLetGo')} took={rec.get('took')}"
        f" look pretended at={rec.get('lookPretendedAt')}")
    say(f"  framing (diver off the middle, 1/3 = the middle third's edge): {rec.get('framing')}")
    say(f"  in the lit layers: {rec.get('layers')}")
    say(f"  splash near the camera: {rec.get('splashNear')}")
    say(f"  frame time, under to +1.5 s: {rec.get('frameTime')}")
    say(f"  underwater look: {rec.get('look')}")
    say(f"  splash: {rec.get('splash')}")
    say(f"  modes: {rec.get('modes')}")
    say(f"  broken={rec.get('broken')} landMounted={rec.get('landMounted')} errors={rec.get('errors')}")


HOLDS = ["crouch", "takeoff", "rise", "top", "entry", "splash", "splash2", "under"]


def hold(t, view="own", name=None):
    say("stub:", cmd("stub"))
    said = do(f"hold|{t}|{view}", 1.2)
    say(f"hold {t} {view}:", said)
    if name:
        say("shot:", shot(name))


def letgo():
    say(do("letgo", 0.6))
    say("unstub:", cmd("unstub"))
    say(home())


def main():
    what = sys.argv[1] if len(sys.argv) > 1 else "run"
    if what == "install":
        print(install())
        return
    if what == "remove":
        print(install(True))
        return
    if what == "cmd":
        print(cmd(sys.argv[2], float(sys.argv[3]) if len(sys.argv) > 3 else 0.8))
        return
    if what == "do":
        print(do(sys.argv[2], float(sys.argv[3]) if len(sys.argv) > 3 else 1.0))
        return
    if what == "hold":
        t = sys.argv[2] if len(sys.argv) > 2 else "top"
        view = sys.argv[3] if len(sys.argv) > 3 else "own"
        name = sys.argv[4] if len(sys.argv) > 4 else None
        say(cmd("leap|1"))
        say("before:", home())
        hold(t, view, name)
        return
    if what == "holds":
        view = sys.argv[2] if len(sys.argv) > 2 else "own"
        say(cmd("leap|1"))
        say("before:", home())
        for name in HOLDS:
            hold(name, view, f"hold_{view}_{name}")
        letgo()
        (OUT / f"holds_{view}.log").write_text("\n".join(LOG) + "\n")
        return
    if what == "letgo":
        letgo()
        return
    kind = sys.argv[2] if len(sys.argv) > 2 else ""
    if kind == "look":
        # the mouse taking the view back: Leap 1 only
        at = float(sys.argv[3]) if len(sys.argv) > 3 else 1.1
        rec = walk(1, 16, "look", look=at)
        summary("look", rec)
        say(cmd("leap|0"))
        do("leap|0", 0.4)
        say("after:", home())
        (OUT / "check_look.log").write_text("\n".join(LOG) + "\n")
        return
    if kind == "sub":
        # a sub trip from the dive, Leap 1 then Leap 0 (the baseline), each recorded to Riding or Drowning
        land = sys.argv[3] if len(sys.argv) > 3 else "2"
        on = walk(1, 16, "leap_sub", seconds=30, sub=land)
        summary("leap_sub", on)
        off = walk(0, 16, "noleap_sub", seconds=30, sub=land)
        summary("noleap_sub", off)
        say("unsub:", cmd("sub|0", 1.0))
        say(cmd("leap|0"))
        do("leap|0", 0.4)
        say("after:", home())
        (OUT / "check_sub.log").write_text("\n".join(LOG) + "\n")
        return
    # run: the leap, then Leap 0 (the cost), each from the same run-up
    fish = (sys.argv[3] if len(sys.argv) > 3 else "") if kind == "fish" else None
    tag = "_fish" if fish is not None else ""
    on = walk(1, 16, "leap" + tag, fish)
    summary("leap" + tag, on)
    off = walk(0, 16, "noleap" + tag, fish)
    summary("noleap" + tag, off)
    if on.get("lipToRiding") is None and fish is None:
        say("(no Riding without a fish in hand: nobody presses grab in this run; `run fish` measures lip to Riding)")
    if on.get("lipToRiding") is not None and off.get("lipToRiding") is not None:
        say(f"cost: the leap adds {round(on['lipToRiding'] - off['lipToRiding'], 2)} s from the lip to Riding")
    if on.get("lipToHop") is not None and off.get("lipToHop") is not None:
        say(f"cost: the leap adds {round(on['lipToHop'] - off['lipToHop'], 2)} s from the lip to the hop")
    say(cmd("leap|0"))
    do("leap|0", 0.4)
    say("after:", home())
    (OUT / f"check{tag}.log").write_text("\n".join(LOG) + "\n")


if __name__ == "__main__":
    main()
