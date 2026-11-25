--!strict
-- Fish leaping out of the sea past the gate, as seen from the hub (Config.HubLeap; the play passes, 2026-11-24: nothing in
-- a new player's first view was a fish, in a game about riding them). Redone 2026-11-25 on the user's word: mostly small
-- common fish, in little schools, some middling, now and then a great one; all over the sea seen from the hub; a small one
-- is quick and hardly splashes.
-- Copies of the creatures' own models (ReplicatedStorage.FishModels), still and anchored, moved along arcs with a splash
-- going out and coming in. Only on this machine, only while we are on the dock: nothing is a fish anyone can ride, nothing
-- is sent.
local ContentProvider = game:GetService("ContentProvider")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Feel = require(script.Parent.Parent.Lib.Feel)
local Splash = require(script.Parent.Parent.Lib.Splash)
local State = require(script.Parent.Parent.Lib.State)

local HubLeapController = {}

type Leap = {
	Kind: Config.Leaper,
	Model: Model,
	From: Vector3,
	To: Vector3,
	Rise: number, -- how far it goes up, from under the water, studs
	Time: number,
	At: number,
	Roll: number,
	Heard: boolean, -- it makes the sound (one of a school does)
	Out: boolean,
	In: boolean,
}

local leaps: { Leap } = {}
local nextAt = 0
local ready: { [string]: { Model } } = {} -- copies of each kind, not up now
local picked: Config.Leaper? = nil -- the next one, its model loading
local recent: { Vector3 } = {} -- where the last few went

local HEAD = CFrame.Angles(0, math.pi, 0) -- (the models' heads are at their +Z; lookAt's way is -Z)
local RECENT = 4
local TRIES = 14
local NOSE = 0.4 -- its nose is this much of its length ahead of its middle: what meets the water
local HEARD_NEAR = 120 -- its sound is full this near, studs

-- What's in the way of a leap is asked of the map alone
local seaParams = RaycastParams.new()
seaParams.FilterType = Enum.RaycastFilterType.Include
seaParams.IgnoreWater = true

local function copyOf(kind: Config.Leaper): Model?
	local kept = ready[kind.Id]
	local model = if kept then table.remove(kept) else nil
	if model then
		return model
	end
	local folder = ReplicatedStorage:FindFirstChild("FishModels")
	local found = folder and folder:FindFirstChild(kind.Id)
	if not found or not found:IsA("Model") then
		return nil
	end
	local made = found:Clone()
	for _, d in made:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			d.CanTouch = false
			d.CanQuery = false
			d.CastShadow = false
		elseif d:IsA("Script") or d:IsA("Motor6D") or d:IsA("Trail") then
			d:Destroy()
		end
	end
	made:ScaleTo(kind.Long / math.max(select(2, made:GetBoundingBox()).Z, 1))
	return made
end

local function keep(kind: Config.Leaper, model: Model)
	model.Parent = nil
	local kept = ready[kind.Id] or {}
	ready[kind.Id] = kept
	if #kept < kind.School then
		table.insert(kept, model)
	else
		model:Destroy()
	end
end

-- The gate's spot: the dock's spawn looks at it (nil: no such map)
local function gate(): CFrame?
	local blockout = workspace:FindFirstChild("ClaudeBlockout")
	local dock = blockout and blockout:FindFirstChild("Dock")
	local spawn = dock and dock:FindFirstChild("DockSpawn")
	local strip = dock and dock:FindFirstChild("StartStrip")
	if not spawn or not spawn:IsA("BasePart") or not strip or not strip:IsA("BasePart") then
		return nil
	end
	local to = Vector3.new(strip.Position.X, 0, strip.Position.Z)
	local from = Vector3.new(spawn.Position.X, 0, spawn.Position.Z)
	seaParams.FilterDescendantsInstances = { blockout :: any }
	return CFrame.lookAt(to, to + (to - from))
end

-- The kind that goes next, by the weights (the ones the game has a model of), its model made and loading
local function pick(): Config.Leaper?
	local folder = ReplicatedStorage:FindFirstChild("FishModels")
	if not folder then
		return nil
	end
	local total = 0
	for _, kind in Config.HubLeap.Kinds do
		total += if folder:FindFirstChild(kind.Id) then kind.Weight else 0
	end
	local left = math.random() * total
	for _, kind in Config.HubLeap.Kinds do
		if folder:FindFirstChild(kind.Id) then
			left -= kind.Weight
			if left <= 0 then
				local kept = ready[kind.Id]
				if not kept or #kept == 0 then
					local model = copyOf(kind)
					if model then
						keep(kind, model)
						task.spawn(function()
							pcall(ContentProvider.PreloadAsync, ContentProvider, { model })
						end)
					end
				end
				return kind
			end
		end
	end
	return nil
end

-- Whether it is open sea here: the first thing down from the air is the sea's own see-through top, or nothing
local function sea(x: number, z: number, high: number): boolean
	local y = Config.Depth.SurfaceY
	local hit = workspace:Raycast(Vector3.new(x, y + high, z), Vector3.new(0, -high - 1, 0), seaParams)
	return not hit or (hit.Instance :: BasePart).Transparency > 0.9
end

-- Where a leap this long goes from and to: open sea all along, clear of the last few if it can be
local function path(at: CFrame, kind: Config.Leaper): (Vector3?, Vector3?)
	local c = Config.HubLeap
	local long = kind.Long
	local across = math.max(c.Across * long, c.AcrossLeast)
	local nearest = c.OutNear + across
	local furthest = math.max(math.min(c.OutFar + c.OutLong * long, c.OutMost), nearest + 20)
	local bestFrom: Vector3?, bestTo: Vector3?
	local bestGap = -1
	for _ = 1, TRIES do
		local middle = (at * CFrame.new(
			(math.random() * 2 - 1) * c.Side,
			0,
			-(nearest + (furthest - nearest) * math.random())
		)).Position
		-- (mostly across the view, so the leap is seen from its side)
		local turn = (math.random() * 2 - 1) * math.rad(50)
		local way = at.RightVector * math.cos(turn) + at.LookVector * math.sin(turn)
		way *= if math.random() < 0.5 then 1 else -1
		local side = Vector3.new(-way.Z, 0, way.X) * (long * 0.3)
		local open = true
		for _, share in { -0.65, -0.5, -0.25, 0, 0.25, 0.5, 0.65 } do
			local p = middle + way * (across * share)
			if
				not sea(p.X, p.Z, long * 1.6)
				or not sea(p.X + side.X, p.Z + side.Z, long * 1.6)
				or not sea(p.X - side.X, p.Z - side.Z, long * 1.6)
			then
				open = false
				break
			end
		end
		if open then
			local gap = math.huge
			for _, was in recent do
				gap = math.min(gap, (was - middle).Magnitude)
			end
			if gap > bestGap then
				bestGap = gap
				bestFrom, bestTo = middle - way * (across / 2), middle + way * (across / 2)
			end
			if gap >= c.Apart then
				break
			end
		end
	end
	return bestFrom, bestTo
end

local function start(now: number)
	local c = Config.HubLeap
	nextAt = now + c.EveryLeast + math.random() * (c.EveryMost - c.EveryLeast)
	local at = gate()
	local kind = picked or pick()
	if not at or not kind then
		nextAt = now + 1 -- (the dock or the models have not come in yet)
		return
	end
	if #leaps >= c.Most then
		picked = kind
		return
	end
	local from, to = path(at, kind)
	if from and to then
		local middle = (from + to) / 2
		table.insert(recent, middle)
		if #recent > RECENT then
			table.remove(recent, 1)
		end
		local way = (to - from).Unit
		local right = Vector3.new(-way.Z, 0, way.X)
		local many = math.min(math.random(1, kind.School), c.Most - #leaps)
		for i = 1, many do
			local model = copyOf(kind)
			if model then
				-- (a school's fish go side by side, each a little behind the last, none quite alike)
				local off = if i == 1
					then Vector3.zero
					else right * (kind.Long * 0.8 * (if i % 2 == 0 then 1 else -1) * (i // 2))
						- way * (kind.Long * 0.5 * math.random())
				local size = if i == 1 then 1 else 0.85 + 0.2 * math.random()
				local y = Vector3.new(0, Config.Depth.SurfaceY - c.Under * kind.Long, 0)
				table.insert(leaps, {
					Kind = kind,
					Model = model,
					From = (from + off) * Vector3.new(1, 0, 1) + y,
					To = (to + off) * Vector3.new(1, 0, 1) + y,
					Rise = (c.High + c.Under) * kind.Long * size,
					Time = c.TimeBase + c.TimeLong * kind.Long,
					At = now + (i - 1) * c.Stagger * (0.7 + 0.6 * math.random()),
					Roll = math.rad(c.Roll) * (if math.random() < 0.5 then 1 else -1),
					Heard = i == 1,
					Out = false,
					In = false,
				})
			end
		end
	end
	picked = pick()
end

-- Through the surface, out or in: the splash and its sound (softer and higher the smaller it is, softer the further off)
local function through(l: Leap, p: Vector3)
	local c = Config.HubLeap
	local long = l.Kind.Long
	local scale = c.Splash * (long / 44) ^ c.SplashPower
	local at = Vector3.new(p.X, Config.Depth.SurfaceY, p.Z)
	Splash.scenery(at, (l.To - l.From).Unit, scale)
	if l.Heard then
		local far = (workspace.CurrentCamera.CFrame.Position - at).Magnitude
		local volume = c.Volume * math.clamp(scale, 0.2, 1) * math.clamp(HEARD_NEAR / far, 0.2, 1)
		Feel.sound("Splash", volume, math.clamp(1.65 - 0.025 * long, 0.55, 1.4), 2)
	end
end

local function step()
	local now = os.clock()
	local here = State.Mode == "Dock" and Config.HubLeap.On ~= 0
	if here and now >= nextAt then
		start(now)
	end
	local surface = Config.Depth.SurfaceY
	for i = #leaps, 1, -1 do
		local l = leaps[i]
		local t = (now - l.At) / l.Time
		if t >= 1 or not here then
			table.remove(leaps, i)
			keep(l.Kind, l.Model)
		elseif t >= 0 then
			-- an arc, its nose along the way it is going
			local p = l.From:Lerp(l.To, t) + Vector3.new(0, 4 * t * (1 - t) * l.Rise, 0)
			local way = (l.To - l.From + Vector3.new(0, 4 * (1 - 2 * t) * l.Rise, 0)).Unit
			local model = l.Model
			model:PivotTo(CFrame.lookAt(p, p + way) * CFrame.Angles(0, 0, l.Roll * math.sin(math.pi * t)) * HEAD)
			if not model.Parent then
				model.Parent = workspace.CurrentCamera
			end
			local nose = p + way * (l.Kind.Long * NOSE)
			local over = nose.Y > surface
			if over and not l.Out then
				l.Out = true
				through(l, nose)
			elseif l.Out and not over and not l.In then
				l.In = true
				through(l, nose)
			end
		end
	end
end

function HubLeapController.Start()
	nextAt = os.clock() + Config.HubLeap.First
	RunService.RenderStepped:Connect(step)
end

return HubLeapController
