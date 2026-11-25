--!strict
-- The trailer mode (Studio only; Config.Trailer.On; docs/design/trailer.md): J plays every shot of the game-page video,
-- one after another, for a screen recorder. Between shots the screen is a plain slate (pink, with the shot's number as
-- a row of black and white squares), which tools/trailer/cut.py finds in the recording, so the recording can be cut by
-- script. The fish, the rider, the herd and the screens are the game's own; only the camera and the steering are ours.
-- The workspace attribute TrailerRun ("all", or "3" or "3,5") does the same as J, for checks; TrailerNow says what is on.
--   A shot's camera goes from one place to another round its subject (the fish ridden, or the rider's head): Az degrees
--   round it (0 behind, 90 its right, 180 ahead of it), El degrees up, Far in fish lengths, Ahead and Up where it looks,
--   in fish lengths from its middle. Cam = "Game" leaves the game's own camera. Hud = true leaves the game's screens on.
local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)
local Actions = require(script.Parent.Parent.Lib.Actions)
local State = require(script.Parent.Parent.Lib.State)
local FusePanel = require(script.Parent.Parent.UI.FusePanel)
local Shop = require(script.Parent.Parent.UI.Shop)
local SubPanel = require(script.Parent.Parent.UI.SubPanel)
local RideController = require(script.Parent.RideController)

local TrailerController = {}

type Key = { Az: number, El: number, Far: number, Ahead: number?, Up: number?, Fov: number? }
type Shot = { [string]: any }

-- Screens of ours that are never in a shot (the sandbox's, the admin's, the lesson's)
local NEVER = { "Sandbox", "Admin", "Lesson", "FeelLog", "Offline" }

local player = Players.LocalPlayer
local remote: RemoteFunction
local running = false

-- what the frame step does now
local path: { Vector3 }? = nil
local aim: Model? = nil
local shotNow: Shot? = nil
local shotAt = 0
local hudOn = true
local sideOf = 1
local place: (() -> CFrame)? = nil -- a shot of something that stays where it is: its middle, facing the way it faces
local placeSize = 30
local far = 0
local slow = 1 -- (checks: the workspace attribute TrailerSlow makes each shot last this many times longer)

----------------------------------------------------------------------------------------------------------------------
-- The slate

local slate: ScreenGui
local cells: { Frame } = {}

local function makeSlate()
	slate = Instance.new("ScreenGui")
	slate.Name = "TrailerSlate"
	slate.IgnoreGuiInset = true
	slate.DisplayOrder = 100000
	slate.ResetOnSpawn = false
	slate.Enabled = false
	local face = Instance.new("Frame")
	face.Size = UDim2.fromScale(1, 1)
	face.BackgroundColor3 = Color3.fromRGB(255, 0, 255)
	face.BorderSizePixel = 0
	face.Parent = slate
	for i = 1, 6 do
		local cell = Instance.new("Frame")
		cell.AnchorPoint = Vector2.new(0.5, 0.5)
		cell.Position = UDim2.fromScale(0.5 + (i - 3.5) * 0.08, 0.5)
		cell.Size = UDim2.fromScale(0.06, 0.1)
		cell.BorderSizePixel = 0
		cell.Parent = face
		cells[i] = cell
	end
	slate.Parent = player:WaitForChild("PlayerGui")
end

local function showSlate(number: number)
	for i, cell in cells do
		local bit = bit32.extract(number, 6 - i)
		cell.BackgroundColor3 = if bit == 1 then Color3.new(1, 1, 1) else Color3.new(0, 0, 0)
	end
	slate.Enabled = true
end

----------------------------------------------------------------------------------------------------------------------
-- The frame: steering before the ride's own step, the camera and the screens after everything

local hidden: { [LayerCollector]: boolean } = {}

local function screens()
	local gui = player:FindFirstChildOfClass("PlayerGui")
	if not gui then
		return
	end
	local pointer = gui:FindFirstChild("LessonPointer", true)
	if pointer and pointer:IsA("GuiObject") then
		pointer.Visible = false
	end
	for _, g in gui:GetChildren() do
		if g:IsA("LayerCollector") and g ~= slate then
			local never = false
			for _, name in NEVER do
				never = never or string.find(g.Name, name, 1, true) ~= nil
			end
			if not hudOn or never then
				if g.Enabled then
					hidden[g] = true
					g.Enabled = false
				end
			elseif hidden[g] then
				hidden[g] = nil
				g.Enabled = true
			end
		end
	end
end

local function steer()
	if not running or not path then
		return
	end
	local _, root = State.character()
	if not root then
		return
	end
	local target: Vector3? = nil
	local model = aim
	if model and model.PrimaryPart and model.Parent then
		target = model.PrimaryPart.Position
	else
		local best, bestAt = math.huge, 1
		for i, p in path do
			local d = ((p - root.Position) * Vector3.new(1, 0, 1)).Magnitude
			if d < best then
				best, bestAt = d, i
			end
		end
		target = path[math.min(bestAt + 6, #path)]
	end
	local to = (target :: Vector3) - root.Position
	local flat = (to * Vector3.new(1, 0, 1)).Magnitude
	if flat > 4 then
		local pitch = if model then math.atan2(to.Y, flat) else math.rad(-12)
		RideController.look(math.atan2(-to.X, -to.Z), pitch)
	end
end

local function blend(a: number?, b: number?, u: number, default: number): number
	local from = a or default
	return from + ((b or from) - from) * u
end

local function lengthOf(model: Model): number
	local size = model:GetExtentsSize()
	return math.max(size.X, size.Y, size.Z)
end

local function rayFree(from: Vector3, to: Vector3): number
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local out: { Instance } = {}
	if player.Character then
		table.insert(out, player.Character)
	end
	if State.Fish then
		table.insert(out, State.Fish)
	end
	local herd = workspace:FindFirstChild("Fish")
	if herd then
		table.insert(out, herd)
	end
	params.FilterDescendantsInstances = out
	params.IgnoreWater = true
	local hit = workspace:Raycast(from, to - from, params)
	if hit and hit.Instance.CanCollide and hit.Instance.Transparency < 0.9 then
		return hit.Distance - 3
	end
	return (to - from).Magnitude
end

-- where the camera looks, the frame it goes round, and the length it counts in
local length = 30
local function subject(shot: Shot): (Vector3, CFrame)
	if place then
		local at = (place :: () -> CFrame)()
		length = placeSize
		return at.Position, at.Rotation
	end
	local character, root = State.character()
	local heading = CFrame.fromOrientation(0, State.Heading, 0)
	local fish = State.Fish
	if fish and fish.PrimaryPart and not shot.OnRider then
		length = lengthOf(fish)
		return fish.PrimaryPart.Position, heading
	end
	local head = character and character:FindFirstChild("Head")
	if fish and shot.OnRider ~= "Head" then
		length = lengthOf(fish)
	end
	local at = if head and head:IsA("BasePart")
		then head.Position
		elseif root then root.Position
		else workspace.CurrentCamera.CFrame.Position
	return at, heading
end

local smooth: Vector3? = nil
local function view(shot: Shot, t: number): (CFrame, number)
	local u = math.clamp(t / shot.Time, 0, 1)
	if shot.Ease == "Out" then
		u = 1 - (1 - u) ^ 3
	elseif shot.Ease == "InOut" then
		u = u * u * (3 - 2 * u)
	end
	local a: Key, b: Key = shot.From, shot.To or shot.From
	local at, frame = subject(shot)
	local size = if shot.OnRider == "Head" then 6 else length
	-- (the fish's own bob and bucking stay in the picture: the camera follows a smoothed middle)
	local s = if smooth then smooth:Lerp(at, 0.5) else at
	smooth = s
	local az, el = blend(a.Az, b.Az, u, 0) * sideOf, blend(a.El, b.El, u, 0)
	if workspace:GetAttribute("TrailerSweep") then
		az = u * 360 -- (checks: all the way round, to find a clear side)
	end
	local dist = blend(a.Far, b.Far, u, 1) * size
	local target = s
		+ frame.LookVector * blend(a.Ahead, b.Ahead, u, 0) * size
		+ Vector3.yAxis * blend(a.Up, b.Up, u, 0) * size
	local back = (frame * CFrame.Angles(0, math.rad(az), 0) * CFrame.Angles(-math.rad(el), 0, 0)):VectorToWorldSpace(
		Vector3.zAxis
	)
	far = dist
	local free = rayFree(target, target + back * dist)
	if not shot.Through then
		dist = math.min(dist, math.max(free, size * 0.3))
	end
	return CFrame.lookAt(target + back * dist, target) * CFrame.Angles(0, 0, math.rad(blend(a.Roll, b.Roll, u, 0))),
		blend(a.Fov, b.Fov, u, 60)
end

-- a fish of the herd between the camera and what it looks at (or on the camera) is not drawn, on this screen only
local faded: { [Model]: { [Instance]: boolean } } = {}
local function fade(model: Model, on: boolean)
	if on == (faded[model] ~= nil) then
		return
	end
	local was = faded[model] or {}
	if on then
		faded[model] = was
	else
		faded[model] = nil
	end
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.LocalTransparencyModifier = if on then 1 else 0
		elseif d:IsA("Trail") or d:IsA("Beam") or d:IsA("ParticleEmitter") then
			if on and d.Enabled then
				was[d] = true
				d.Enabled = false
			elseif not on and was[d] then
				d.Enabled = true
			end
		end
	end
end

local function clearView(from: Vector3?, to: Vector3)
	local herd = workspace:FindFirstChild("Fish")
	if not herd then
		return
	end
	for _, m in herd:GetChildren() do
		if m:IsA("Model") and m.PrimaryPart and m ~= State.Fish and not m:HasTag("TrailerTarget") then
			local on = false
			if from then
				local way = to - from
				local at = m.PrimaryPart.Position
				local u = math.clamp((at - from):Dot(way) / math.max(way:Dot(way), 1), 0, 1)
				local half = lengthOf(m) * 0.5
				on = (at - (from + way * u)).Magnitude < half + length * 0.3
					or (at - to).Magnitude < half + length * 0.6
			end
			fade(m, on)
		elseif m:IsA("Model") and faded[m] then
			fade(m, false)
		end
	end
end

local function frame()
	if not running then
		return
	end
	screens()
	local shot = shotNow
	local camera = workspace.CurrentCamera
	if Config.Trailer.Fog ~= 1 and not slate.Enabled then
		Lighting.FogEnd *= Config.Trailer.Fog
	end
	if shot and shot.Cam ~= "Game" then
		camera.CameraType = Enum.CameraType.Scriptable
		local cf, fov = view(shot, (os.clock() - shotAt) / slow)
		camera.CFrame = cf
		if shot.Ride then
			clearView(cf.Position, cf.Position + cf.LookVector * far)
		end
		camera.FieldOfView = fov
	end
end

----------------------------------------------------------------------------------------------------------------------
-- The shots

local function ask(kind: string, a: any?): any
	return remote:InvokeServer(kind, a)
end

local function until_(seconds: number, test: () -> boolean): boolean
	local since = os.clock()
	while os.clock() - since < seconds do
		if test() then
			return true
		end
		task.wait()
	end
	return test()
end

local function home()
	path, aim = nil, nil
	Shop.go(nil)
	SubPanel.open(false)
	if State.Mode ~= "Dock" then
		ask("Home")
		until_(6, function()
			return State.Mode == "Dock"
		end)
		task.wait(0.6)
	end
end

local function plot(): Model?
	local dock = workspace:FindFirstChild("Dock", true)
	local plots = dock and dock:FindFirstChild("Plots")
	local name = player:GetAttribute("Plot")
	local found = plots and type(name) == "string" and plots:FindFirstChild(name)
	return if found and found:IsA("Model") then found else found :: any
end

-- beside a station of the dock (or a place), facing it
local function stand(at: Vector3, toward: Vector3)
	ask("Pivot", CFrame.lookAt(at, Vector3.new(toward.X, at.Y, toward.Z)))
	task.wait(0.4)
end

local function station(name: string)
	local dock = workspace:FindFirstChild("Dock", true)
	local folder = dock and dock:FindFirstChild("Stations")
	local s = folder and folder:FindFirstChild(name)
	if s then
		local at = if s:IsA("BasePart") then s.Position else (s :: Model):GetPivot().Position
		stand(at + Vector3.new(0, 4, 0), at + Vector3.new(0, 0, -10))
	end
end

-- the window's list slid from its start to its end
local function slide(window: string, t: number, time: number)
	local gui = (player :: any).PlayerGui:FindFirstChild(window, true)
	if not gui then
		return
	end
	local best: ScrollingFrame? = nil
	for _, d in gui:GetDescendants() do
		if d:IsA("ScrollingFrame") then
			local room = (d.AbsoluteCanvasSize - d.AbsoluteWindowSize).Magnitude
			if not best or room > (best.AbsoluteCanvasSize - best.AbsoluteWindowSize).Magnitude then
				best = d
			end
		end
	end
	if best then
		local u = math.clamp(t / time, 0, 1)
		u = u * u * (3 - 2 * u)
		local room = best.AbsoluteCanvasSize - best.AbsoluteWindowSize
		best.CanvasPosition = Vector2.new(math.max(room.X, 0), math.max(room.Y, 0)) * u
	end
end

-- a hop at `at` seconds, onto the nearest fish put there for it
local function hop(at: number): (number) -> ()
	local left, grabbed, pressedAt = false, false, 0
	return function(t: number)
		if t < at then
			return
		end
		if not left then
			left = true
			pressedAt = os.clock()
			local _, root = State.character()
			local best = math.huge
			for _, m in CollectionService:GetTagged("TrailerTarget") do
				if m:IsA("Model") and m.PrimaryPart and root and State.isFreeFish(m) then
					local d = (m.PrimaryPart.Position - root.Position).Magnitude
					if d < best then
						best, aim = d, m
					end
				end
			end
			Actions.jump()
		elseif State.Mode == "Jumping" and not grabbed then
			if
				State.JumpTarget
				and (State.JumpTarget == aim or os.clock() - pressedAt > 0.9)
				and os.clock() - pressedAt > 0.3
			then
				grabbed = true
				Actions.jump()
			end
		elseif grabbed and State.Mode == "Riding" then
			aim = nil
		end
	end
end

local function tankPlace()
	local p = plot()
	local water = p and p:FindFirstChild("TankWater", true)
	if water and water:IsA("BasePart") then
		local w = water
		place = function()
			return w.CFrame
		end
		placeSize = 57
	end
end

local function trainer(level: number)
	home()
	ask("Level", level)
	local info = ask("Trainer")
	if type(info) == "table" then
		local axis: Vector3 = info.Axis
		local seat: CFrame = info.Seat
		if not (type(player:GetAttribute("TrainerRide")) == "string") then
			stand(axis + seat.LookVector * -22 + Vector3.new(0, 5, 0), axis)
			stand(axis + seat.LookVector * -5 + Vector3.new(0, 4, 0), axis)
			until_(3, function()
				return type(player:GetAttribute("TrainerRide")) == "string"
			end)
		end
		place = function()
			return CFrame.lookAlong(seat.Position, seat.LookVector)
		end
		placeSize = 10
	end
end

local TANK = {
	{ "Clownfish" },
	{ "YellowTang" },
	{ "SeaTurtle" },
	{ "ReefShark" },
	{ "HammerheadShark" },
	{ "MantaRay" },
	{ "GreatWhite" },
	{ "Orca" },
	{ "Megalodon" },
	{ "MoltenMegalodon", "Normal", "Gold" },
}

local function stepped(every: number, first: number, count: number, act: (number) -> ()): (number) -> ()
	local done = 0
	return function(t: number)
		while done < count and t >= first + done * every do
			done += 1
			task.spawn(act, done)
		end
	end
end

-- Every shot, in order. Ride: what TrailerService.asks.Ride takes. Prep: before the slate lifts. Live: each frame.
local SHOTS: { Shot } = {
	-- the animals, no screens: weak to strong, each bigger in the picture
	{
		Name = "Rider close up",
		Time = 1.5,
		Ease = "Out",
		OnRider = "Head",
		Through = true,
		Ride = { Land = 1, Along = 300, Fish = "Clownfish" },
		From = { Az = 215, El = 4, Far = 0.75, Fov = 80 },
		To = { Az = 20, El = 14, Far = 4.2, Ahead = 0.4, Fov = 72 },
	},
	{
		Name = "Reef shark",
		Time = 0.9,
		Ride = { Land = 1, Along = 700, Fish = "ReefShark" },
		From = { Az = 100, El = 3, Far = 1.0, Ahead = -0.1 },
		To = { Az = 84, El = 2, Far = 0.9, Ahead = 0.1 },
	},
	{
		Name = "Hammerhead",
		Time = 0.9,
		Ride = { Land = 4, Along = 400, Fish = "HammerheadShark", Size = "Big" },
		From = { Az = 130, El = -6, Far = 0.95 },
		To = { Az = 105, El = -4, Far = 0.85 },
	},
	{
		Name = "Great white",
		Time = 1.0,
		Ride = { Land = 3, Along = 500, Fish = "GreatWhite", Size = "Big" },
		From = { Az = 160, El = -8, Far = 0.9, Ahead = 0.1 },
		To = { Az = 120, El = -5, Far = 0.75, Ahead = 0.1 },
	},
	{
		Name = "Megalodon",
		Time = 1.1,
		Ride = { Land = 8, Along = 500, Fish = "Megalodon" },
		From = { Az = 75, El = -10, Far = 0.8, Ahead = -0.1 },
		To = { Az = 95, El = -8, Far = 0.75, Ahead = 0.15 },
	},
	{
		Name = "Molten megalodon",
		Time = 1.3,
		Ease = "Out",
		Ride = { Land = 8, Along = 1000, Fish = "MoltenMegalodon", Size = "Big" },
		From = { Az = 170, El = 3, Far = 0.95, Ahead = 0.1 },
		To = { Az = 138, El = -5, Far = 0.85, Ahead = 0.12 },
	},
	-- the hop, from behind, still no screens
	{
		Name = "Hop chain",
		Time = 2.6,
		Cam = "Game",
		Ride = {
			Land = 3,
			Along = 900,
			Fish = "LeopardShark",
			Herd = {
				{ Id = "GreatWhite", Ahead = 330, Share = 0.15, Target = true },
				{ Id = "StellersSeaCow", Ahead = 420, Share = -0.5 },
				{ Id = "GiantSeaBass", Ahead = 260, Share = -0.35 },
				{ Id = "LeopardShark", Ahead = 480, Share = 0.5 },
				{ Id = "GiantSeaBass", Ahead = 560, Share = 0.1 },
			},
		},
		Hop = 0.4,
	},
	{
		Name = "Hop from the side",
		Time = 2.6,
		Ease = "InOut",
		OnRider = true,
		Ride = {
			Land = 5,
			Along = 700,
			Fish = "Orca",
			Herd = {
				{ Id = "BlueWhale", Ahead = 420, Share = 0.1, Target = true },
				{ Id = "MantaRay", Ahead = 480, Share = -0.5 },
			},
		},
		Hop = 0.3,
		From = { Az = 60, El = 8, Far = 0.9, Ahead = 0.3 },
		To = { Az = 100, El = 4, Far = 1.0 },
	},
	-- home: the tank filling, the seahorse, the auras
	{
		Name = "Tank fills",
		Time = 2.4,
		Hud = true,
		Prep = function()
			home()
			tankPlace()
			task.wait(8) -- (the dive's own banner, after the rides before)
		end,
		Live = stepped(0.19, 0.15, #TANK, function(i)
			ask("Give", { TANK[i] })
			Net.Action:FireServer("Tank", "Best")
		end),
		Through = true,
		From = { Az = -14, El = 14, Far = 1.15 },
		To = { Az = 12, El = 10, Far = 0.95 },
	},
	{
		Name = "Seahorse 1",
		Time = 1.6,
		Hud = true,
		Prep = function()
			trainer(1)
			task.wait(1)
		end,
		From = { Az = 25, El = 14, Far = 1.7, Up = 0.1 },
		To = { Az = -10, El = 10, Far = 1.5, Up = 0.1 },
	},
	{
		Name = "Seahorse levels",
		Time = 5.2,
		Prep = function()
			trainer(1)
			task.wait(0.5)
		end,
		Live = stepped(0.4, 0.4, 11, function(i)
			ask("Level", i + 1)
		end),
		From = { Az = 120, El = 4, Far = 1.9 },
		To = { Az = 220, El = 8, Far = 1.7 },
	},
	{
		Name = "Auras",
		Time = 1.5,
		Hud = true,
		Cam = "Game",
		Prep = function()
			home()
			station("Auras")
			Shop.go("Auras")
			task.wait(1)
		end,
		Live = function(t)
			slide("AuraShop", t, 1.4)
		end,
	},
	-- the lands, a stronger mount in each
	{
		Name = "Kelp",
		Time = 1.1,
		Ride = { Land = 3, Along = 700, Fish = "KelpWyrm" },
		From = { Az = 10, El = 16, Far = 0.75, Ahead = 0.3 },
		To = { Az = -8, El = 13, Far = 0.65, Ahead = 0.3 },
	},
	{
		Name = "Fire",
		Time = 1.1,
		Ride = { Land = 10, Along = 600, Fish = "Hellmaw" },
		From = { Az = -12, El = 16, Far = 0.8, Ahead = 0.3 },
		To = { Az = 8, El = 13, Far = 0.7, Ahead = 0.3 },
	},
	{
		Name = "Bones",
		Time = 1.2,
		Ride = { Land = 9, Along = 600, Fish = "HalfboneMegalodon" },
		From = { Az = 14, El = 16, Far = 0.8, Ahead = 0.3 },
		To = { Az = -6, El = 12, Far = 0.7, Ahead = 0.3 },
	},
	{
		Name = "Fuse",
		Time = 5,
		Hud = true,
		Cam = "Game",
		Prep = function()
			home()
			ask("Give", { { "GreatWhite" }, { "GreatWhite" }, { "GreatWhite" } })
			station("Fuse")
			Shop.go("Fuse")
			task.wait(1.2)
		end,
		Live = stepped(0.25, 0.2, 4, function(i)
			if i <= 3 then
				FusePanel.press("Card", i)
			else
				FusePanel.press("Fuse")
			end
		end),
	},
	{
		Name = "Submarines",
		Time = 1.6,
		Hud = true,
		Cam = "Game",
		Prep = function()
			home()
			station("Sub")
			Shop.go(nil)
			SubPanel.open(true)
			task.wait(1)
		end,
		Live = function(t)
			slide("SubShop", t, 1.5)
		end,
	},
	-- the last giants
	{
		Name = "Void whale",
		Time = 1.6,
		Ease = "InOut",
		Ride = { Land = 7, Along = 700, Fish = "VoidWhale" },
		From = { Az = 200, El = -6, Far = 0.75, Ahead = 0.2 },
		To = { Az = 130, El = -12, Far = 0.8 },
	},
	{
		Name = "Devourer",
		Time = 1.4,
		Ride = { Land = 10, Along = 1200, Fish = "TheDevourer" },
		From = { Az = 165, El = 0, Far = 0.7, Ahead = 0.2 },
		To = { Az = 115, El = -8, Far = 0.7 },
	},
	{
		Name = "Last hop",
		Time = 4.2,
		Cam = "Game",
		Ride = {
			Land = 8,
			Along = 1600,
			Fish = "Megalodon",
			Herd = {
				{ Id = "MoltenMegalodon", Ahead = 420, Share = 0.1, Target = true },
				{ Id = "Kronosaurus", Ahead = 500, Share = -0.5 },
			},
		},
		Hop = 0.3,
	},
}

local function play(number: number, shot: Shot)
	slow = if shot.Hop then 1 else workspace:GetAttribute("TrailerSlow") or 1
	showSlate(number)
	workspace:SetAttribute("TrailerNow", `{number} {shot.Name} prep`)
	place, aim, smooth, shotNow, hudOn = nil, nil, nil, nil, shot.Hud == true
	local live = shot.Live
	local function settle()
		if shot.Ride then
			Shop.go(nil)
			for try = 1, 2 do
				local asked = os.clock()
				path = ask("Ride", shot.Ride)
				task.wait(0.8)
				if
					until_(8, function()
						local fish = State.Fish
						local root = fish and fish.PrimaryPart
						-- (on a fish mounted since, and where the shot is: not still on the one before)
						return State.Mode == "Riding"
							and root ~= nil
							and State.MountedAt > asked
							and path ~= nil
							and (root.Position - path[1]).Magnitude < 700
					end)
				then
					break
				end
				warn(`[Trailer] {shot.Name}: not on the fish, try {try}`)
			end
			local fish = State.Fish
			State.RideLift = if fish then math.max(0, fish:GetExtentsSize().Y / 2 + 4) else 0
			task.wait(shot.Settle or Config.Trailer.Settle)
		end
		if shot.Prep then
			shot.Prep()
		end
	end
	settle()
	-- (the side with room, for a shot from a side)
	sideOf = 1
	if shot.From and shot.Ride then
		smooth = nil
		local a = view(shot, shot.Time * 0.5)
		local at = subject(shot)
		local room = rayFree(at, a.Position)
		sideOf = -1
		smooth = nil
		local b = view(shot, shot.Time * 0.5)
		if room >= far * 0.95 or room >= rayFree(at, b.Position) then
			sideOf = 1
		end
		smooth = nil
	end
	clearView(nil, Vector3.zero)
	local jump = if shot.Hop then hop(shot.Hop) else nil
	shotAt = os.clock()
	shotNow = shot
	task.wait(0.15)
	shotAt = os.clock()
	slate.Enabled = false
	workspace:SetAttribute("TrailerNow", `{number} {shot.Name}`)
	-- (a moment longer than the shot: the cut takes what it needs)
	while os.clock() - shotAt < shot.Time * slow + 0.3 do
		local t = (os.clock() - shotAt) / slow
		if jump then
			jump(t)
		end
		if live then
			live(t)
		end
		RunService.Heartbeat:Wait()
	end
	showSlate(number)
	shotNow = nil
end

local function run(which: string)
	if running then
		return
	end
	running = true
	pcall(function()
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All, false)
	end)
	ask("Setup", { Max = Config.Trailer.Oxygen, Coins = if which == "all" then 25000 else 0 })
	for i, shot in SHOTS do
		if which == "all" or table.find(string.split(which, ","), tostring(i)) then
			local ok, problem = xpcall(play, debug.traceback, i, shot)
			if not ok then
				warn(`[Trailer] {shot.Name}: {problem}`)
			end
		end
	end
	showSlate(0)
	task.wait(1)
	home()
	place, path, shotNow, hudOn = nil, nil, nil, true
	State.RideLift = 0
	screens()
	running = false
	slate.Enabled = false
	workspace:SetAttribute("TrailerNow", "done")
	pcall(function()
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All, true)
	end)
end

function TrailerController.Start()
	if not RunService:IsStudio() or Config.Trailer.On == 0 then
		return
	end
	local found = Net.Folder:WaitForChild("Trailer", 30)
	if not found or not found:IsA("RemoteFunction") then
		return
	end
	remote = found
	makeSlate()
	RunService:BindToRenderStep("TrailerSteer", Enum.RenderPriority.Camera.Value - 1, steer)
	RunService:BindToRenderStep("TrailerCamera", Enum.RenderPriority.Last.Value + 10, frame)
	UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
		if not processed and input.KeyCode == Enum.KeyCode.J then
			run("all")
		end
	end)
	workspace:GetAttributeChangedSignal("TrailerRun"):Connect(function()
		local which = workspace:GetAttribute("TrailerRun")
		if type(which) == "string" and which ~= "" then
			run(which)
		end
	end)
end

return TrailerController
