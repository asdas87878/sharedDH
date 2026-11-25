--!strict
-- Who has a trail of haze and bubbles behind it, and how much of one (docs/design/fish-trails.md; the numbers:
-- Shared/FishTrails; what one is made of: Lib/FishTrailRig). Drawn on this player's own machine, for the fish near the
-- camera, with a few rigs made at the start and moved from fish to fish. A fish with a trail has its old white wake
-- (Config.Wake) see-through on this machine; the far ones keep it. Nothing here writes to a fish but that: the wake's own
-- Enabled belongs to the angry look and the fails, and is only read (a fish whose wake they have put out has no trail).
-- Measured: workspace attribute "FishTrailsMeasure" true (Studio) writes FishTrailsMs, FishTrailsRigs, FishTrailsAlive,
-- FishTrailsDraws and FishTrailsLevelNow.
-- In this file: the level, a fish's look, who gets one, and each frame.
local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)
local FishTrailColours = require(ReplicatedStorage.Shared.FishTrailColours)
local FishTrails = require(ReplicatedStorage.Shared.FishTrails)
local FishTrailRig = require(script.Parent.Parent.Lib.FishTrailRig)
local Kit = require(script.Parent.Parent.UI.Kit)
local State = require(script.Parent.Parent.Lib.State)

local FishTrailController = {}

local STUDIO = RunService:IsStudio()

type Look = { Step: number, Size: Vector3, Main: Color3, Glow: Color3, Variant: string, Archetypes: { string } }
-- A rig and the fish it is on
type Slot = {
	Rig: FishTrailRig.Rig,
	Fish: Model?,
	Root: BasePart?,
	Wake: Trail?,
	Own: boolean,
	At: Vector3, -- last frame's place, for the speed
	Velocity: Vector3,
	Speed: number, -- smoothed
	Slow: number, -- smoothed more: a gain over it is a burst
	BurstAt: number,
	Frenzy: number,
	Hold: number, -- frames left before anything is thrown (the rig has just moved here)
}
type Pick = { Model: Model, Root: BasePart, Look: Look, Score: number, Step: number, Own: boolean }

local folder: Folder
local slots: { Slot } = {}
local looks: { [Model]: Look } = setmetatable({}, { __mode = "k" }) :: any
local slowSince: number? = nil
local fastSince: number? = nil
local slow = false
local nextLook = 0
local fps = 60
local waterSet = Color3.new(1, 1, 1)
local parts: { BasePart } = {}
local frames: { CFrame } = {}
local ms = 0

----------------------------------------------------------------------------------------------------------------------
-- The level

local function isOn(): boolean
	if STUDIO then
		local forced = workspace:GetAttribute("FishTrails")
		if type(forced) == "number" then
			return forced > 0
		end
	end
	return FishTrails.On > 0
end

local function levelOf(now: number): FishTrails.Level
	if STUDIO then
		local forced = workspace:GetAttribute("FishTrailsLevel")
		if type(forced) == "string" and FishTrails.Levels[forced] then
			return FishTrails.Levels[forced]
		end
	end
	local saved = UserSettings().GameSettings.SavedQualityLevel.Value -- 0 Automatic, else 1 to 10
	if saved >= 1 and saved <= FishTrails.LiteLevel then
		return FishTrails.Levels.Lite
	end
	if FishTrails.LiteTouch > 0 and Kit.touch() then
		return FishTrails.Levels.Lite
	end
	if fps < FishTrails.SlowFps then
		fastSince = nil
		local since = slowSince or now
		slowSince = since
		slow = slow or now - since >= FishTrails.SlowFor
	elseif fps > FishTrails.FastFps then
		slowSince = nil
		local since = fastSince or now
		fastSince = since
		slow = slow and now - since < FishTrails.FastFor
	else
		slowSince, fastSince = nil, nil
	end
	return if slow then FishTrails.Levels.Lite else FishTrails.Levels.Full
end

----------------------------------------------------------------------------------------------------------------------
-- A fish's look

local function lookOf(model: Model): Look?
	local fish = Config.FishById[model:GetAttribute("FishType") :: string]
	if not fish then
		return nil
	end
	local variant = Config.variantOf(model)
	local size = Config.bodyOf(model, fish)
	local known = looks[model]
	if known and known.Variant == variant and known.Size == size then
		return known
	end
	local own = FishTrailColours[fish.Id]
	local over = FishTrails.Variants[variant]
	local archetype = model:GetAttribute("Archetype")
	local list: { string } = {}
	if type(archetype) == "string" then
		for id in string.gmatch(archetype, "%a+") do
			table.insert(list, id)
		end
	end
	local look: Look = {
		Step = FishTrails.step(FishTrails.points(Config.sizeTierOf(model), fish.Tier, size.Z)),
		Size = size,
		Main = if over then over.Main elseif own then own.Main else fish.Body,
		Glow = if over then over.Glow elseif own then own.Glow else fish.Fin,
		Variant = variant,
		Archetypes = list,
	}
	looks[model] = look
	return look
end

----------------------------------------------------------------------------------------------------------------------
-- Who gets one

local function wakeOf(root: BasePart): Trail?
	local wake = root:FindFirstChild("Wake")
	return if wake and wake:IsA("Trail") then wake else nil
end

local function letGo(slot: Slot)
	if slot.Wake then
		slot.Wake.LocalTransparencyModifier = 0
	end
	FishTrailRig.strength(slot.Rig, 0)
	slot.Fish, slot.Root, slot.Wake = nil, nil, nil
end

local function give(slot: Slot, model: Model, root: BasePart, now: number)
	slot.Fish, slot.Root, slot.Wake = model, root, wakeOf(root)
	slot.At, slot.Velocity, slot.Speed, slot.Slow = root.Position, Vector3.zero, 0, 0
	slot.BurstAt = now
	slot.Frenzy = (model:GetAttribute("Frenzy") :: number?) or 0
	slot.Hold = 2
	slot.Rig.Dress = nil
end

-- How far behind a fish's middle the camera is, along the fish
local function backOf(root: BasePart, camera: Camera): number
	return math.max(4, root.CFrame:PointToObjectSpace(camera.CFrame.Position).Z)
end

local function dress(slot: Slot, pick: Pick, level: FishTrails.Level, camera: Camera)
	local look, rig = pick.Look, slot.Rig
	local mark = table.concat({ pick.Step, look.Variant, tostring(pick.Own), level.Rate, tostring(look.Size) }, " ")
	local back = backOf(pick.Root, camera)
	local now = rig.Dress
	slot.Own = pick.Own
	-- (our own fish is dressed again when the camera comes or goes by much: where its haze starts depends on it)
	if now and now.Mark == mark and not (pick.Own and math.abs(now.Back - back) > 8) then
		return
	end
	FishTrailRig.dress(rig, {
		Step = pick.Step,
		Size = look.Size,
		Main = look.Main,
		Glow = look.Glow,
		Variant = look.Variant,
		Own = pick.Own,
		Back = back,
		Rate = level.Rate,
		Water = waterSet,
		Archetypes = look.Archetypes,
		Mark = mark,
	})
end

local function makeSlot()
	local home = Instance.new("Folder")
	home.Name = "Trail" .. (#slots + 1)
	home.Parent = folder
	table.insert(slots, {
		Rig = FishTrailRig.new(home),
		Fish = nil,
		Root = nil,
		Wake = nil,
		Own = false,
		At = Vector3.zero,
		Velocity = Vector3.zero,
		Speed = 0,
		Slow = 0,
		BurstAt = 0,
		Frenzy = 0,
		Hold = 0,
	})
end

-- Every fish that could have one, the surest first
local function candidates(level: FishTrails.Level, camera: Camera, held: { [Model]: Slot }): { Pick }
	local picks: { Pick } = {}
	local eye, facing = camera.CFrame.Position, camera.CFrame.LookVector
	local home = workspace:FindFirstChild("Fish")
	local userId = Players.LocalPlayer.UserId
	for _, model in CollectionService:GetTagged("Fish") do
		local root = if model:IsA("Model") then model.PrimaryPart else nil
		if not root or (model.Parent ~= home and model ~= State.Fish) then
			continue
		end
		local away = root.Position - eye
		local distance = away.Magnitude
		local own = model == State.Fish or model:GetAttribute("Rider") == userId
		if not own and distance > level.Far then
			continue
		end
		local look = lookOf(model)
		if look then
			local score = -math.huge
			if not own then
				if
					distance > FishTrails.OffNear + look.Size.Z / 2
					and away:Dot(facing) < distance * FishTrails.OffScreen
				then
					continue
				end
				score = distance - FishTrails.StepNear * (look.Step - 1) - (if held[model] then FishTrails.Keep else 0)
			end
			table.insert(picks, {
				Model = model,
				Root = root,
				Look = look,
				Score = score,
				Step = math.min(look.Step, level.Most),
				Own = own,
			})
		end
	end
	table.sort(picks, function(a, b)
		return a.Score < b.Score
	end)
	for i = #picks, level.Rigs + 1, -1 do
		picks[i] = nil
	end
	return picks
end

-- What all of them cost: steps come off the last ones first until it fits
local function fit(picks: { Pick }, level: FishTrails.Level): (number, number)
	local alive, draws = 0, 0
	for _, pick in picks do
		local a, d = FishTrails.cost(pick.Step)
		alive += a * level.Rate
		draws += d
	end
	for i = #picks, 1, -1 do
		local pick = picks[i]
		while pick.Step > 1 and (alive > level.Particles or draws > level.Draws) do
			local a, d = FishTrails.cost(pick.Step)
			pick.Step -= 1
			local a2, d2 = FishTrails.cost(pick.Step)
			alive += (a2 - a) * level.Rate
			draws += d2 - d
		end
	end
	return alive, draws
end

local function lookRound(now: number)
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	local level = levelOf(now)
	while #slots < level.Rigs and isOn() do
		makeSlot()
	end

	-- the land's water
	local fog = Lighting.FogColor
	if math.abs(fog.R - waterSet.R) + math.abs(fog.G - waterSet.G) + math.abs(fog.B - waterSet.B) > 0.12 then
		waterSet = fog
		for _, slot in slots do
			if slot.Rig.Dress then
				slot.Rig.Dress.Water = fog
				FishTrailRig.colour(slot.Rig)
			end
		end
	end

	local held: { [Model]: Slot } = {}
	for _, slot in slots do
		if slot.Fish then
			held[slot.Fish] = slot
		end
	end
	local picks: { Pick } = if isOn() then candidates(level, camera, held) else {}
	local alive, draws = fit(picks, level)

	local wanted: { [Model]: boolean } = {}
	for _, pick in picks do
		wanted[pick.Model] = true
	end
	local free: { Slot } = {}
	for _, slot in slots do
		if slot.Fish and not wanted[slot.Fish] then
			letGo(slot)
		end
		if not slot.Fish then
			table.insert(free, slot)
		end
	end
	for _, pick in picks do
		local slot = held[pick.Model]
		if not slot then
			slot = table.remove(free) :: Slot
			give(slot, pick.Model, pick.Root, now)
		elseif slot.Root ~= pick.Root then
			slot.Root, slot.Wake = pick.Root, wakeOf(pick.Root)
		end
		dress(slot, pick, level, camera)
		if pick.Own then
			FishTrailRig.own(slot.Rig, slot.Speed, backOf(pick.Root, camera))
		end
		local frenzy = (pick.Model:GetAttribute("Frenzy") :: number?) or 0
		if frenzy > slot.Frenzy and slot.Rig.On then
			FishTrailRig.burst(slot.Rig)
		end
		slot.Frenzy = frenzy
	end

	if STUDIO and workspace:GetAttribute("FishTrailsMeasure") then
		workspace:SetAttribute("FishTrailsRigs", #picks)
		workspace:SetAttribute("FishTrailsAlive", math.round(alive))
		workspace:SetAttribute("FishTrailsDraws", draws)
		workspace:SetAttribute("FishTrailsMs", math.round(ms * 1000) / 1000)
		workspace:SetAttribute("FishTrailsLevelNow", if level == FishTrails.Levels.Lite then "Lite" else "Full")
	end
end

----------------------------------------------------------------------------------------------------------------------
-- Each frame

-- How far a point is from the line a trail lives along (from the tail, back along the way it came)
local function gapOf(point: Vector3, tail: Vector3, run: Vector3): number
	local long = run.Magnitude
	if long < 0.1 then
		return (point - tail).Magnitude
	end
	local dir = run / long
	local t = math.clamp((point - tail):Dot(dir), 0, long)
	return (point - tail - dir * t).Magnitude
end

-- One fish's: where it is, how fast, and so how much trail
local function follow(slot: Slot, dt: number, now: number, eye: Vector3)
	local model, root = slot.Fish, slot.Root
	if not model or not root then
		return
	end
	if not root.Parent or not model.Parent then
		letGo(slot)
		return
	end
	local rig = slot.Rig
	local dressed = rig.Dress
	if not dressed then
		return
	end
	local at = root.CFrame
	table.insert(parts, rig.Body)
	table.insert(frames, at)
	table.insert(parts, rig.Low)
	table.insert(frames, at * rig.LowAt)

	local moved = at.Position - slot.At
	slot.At = at.Position
	if moved.Magnitude > math.max(30, 400 * dt) then -- put somewhere else: no streak across
		slot.Hold = 2
		moved = Vector3.zero
	end
	slot.Velocity = slot.Velocity:Lerp(moved / math.max(dt, 1 / 1000), 1 - math.exp(-8 * dt))
	slot.Speed = slot.Velocity.Magnitude
	slot.Slow += (slot.Speed - slot.Slow) * (1 - math.exp(-2.5 * dt))
	local wake = slot.Wake
	if wake and wake.LocalTransparencyModifier ~= 1 then
		wake.LocalTransparencyModifier = 1
	end
	if slot.Hold > 0 then
		slot.Hold -= 1
		slot.BurstAt = now
		FishTrailRig.strength(rig, 0)
		FishTrailRig.wipe(rig)
		return
	end

	local out = model:GetAttribute("Angry") == true or (wake ~= nil and not wake.Enabled)
	local under = at.Position.Y < Config.Depth.SurfaceY - FishTrails.SurfaceGap
	local share = 0
	if not out and under and slot.Speed > FishTrails.SpeedNone then
		local t = (slot.Speed - FishTrails.SpeedNone) / (FishTrails.SpeedFull - FishTrails.SpeedNone)
		share = FishTrails.SpeedLeast + (1 - FishTrails.SpeedLeast) * math.clamp(t, 0, 1)
	end
	FishTrailRig.strength(rig, share)
	if share <= 0 then
		return
	end
	local recipe = FishTrails.Recipes[dressed.Step]
	if recipe.Curl and recipe.Curl.Twist > 0 then
		FishTrailRig.twist(rig, now)
	end
	-- (a steady gain of a studs a second a second stands a / 2.5 over the slower average)
	if (slot.Speed - slot.Slow) * 2.5 > FishTrails.BurstAt and now - slot.BurstAt > FishTrails.BurstEvery then
		slot.BurstAt = now
		FishTrailRig.burst(rig)
	end
	-- near the camera another fish's goes (our own is cut to end before it)
	local gone = 0
	if not slot.Own then
		local tail = at.Position - at.LookVector * (dressed.Size.Z / 2)
		local life = if recipe.Haze then recipe.Haze.Life else recipe.Ribbon.Life
		local gap = gapOf(eye, tail, -slot.Velocity * life)
		gone = math.clamp((FishTrails.NearFade - gap) / (FishTrails.NearFade - FishTrails.NearGone), 0, 1)
	end
	FishTrailRig.fade(rig, gone)
end

local function step(dt: number)
	local start = os.clock()
	fps += (1 / math.max(dt, 1 / 1000) - fps) * math.min(1, dt)
	if start >= nextLook then
		nextLook = start + FishTrails.Look
		lookRound(start)
	end
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	table.clear(parts)
	table.clear(frames)
	local eye = camera.CFrame.Position
	for _, slot in slots do
		follow(slot, dt, start, eye)
	end
	if #parts > 0 then
		workspace:BulkMoveTo(parts, frames, Enum.BulkMoveMode.FireCFrameChanged)
	end
	ms += ((os.clock() - start) * 1000 - ms) * 0.05
end

----------------------------------------------------------------------------------------------------------------------
-- Init and Start

function FishTrailController.Init()
	folder = Instance.new("Folder")
	folder.Name = "FishTrails"
	folder.Parent = workspace
end

function FishTrailController.Start()
	RunService:BindToRenderStep("FishTrails", Enum.RenderPriority.Camera.Value + 4, step)
	if STUDIO then
		UserInputService.InputBegan:Connect(function(input, processed)
			if not processed and input.KeyCode == Enum.KeyCode.T then
				workspace:SetAttribute("FishTrails", if isOn() then 0 else 1)
			end
		end)
	end
end

return FishTrailController
