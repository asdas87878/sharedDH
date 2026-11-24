--!strict
-- Keeping a drowning body under the water (Config.Death.UnderWater; the user, 2026-11-23: "make sure theres no errors
-- where the player floats above the water"). Shared by the loose body (FailController) and the drown after it
-- (DeathController). Client visuals only: the server has already decided the fail.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Ease = require(ReplicatedStorage.Shared.Ease)
local Net = require(ReplicatedStorage.Shared.Net)

local Underwater = {}

local LOOK_FROM = 40 -- studs over the surface the ground is looked for from (higher than anything on the strip)

local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Exclude
params.RespectCanCollide = true
params.IgnoreWater = true

-- (the skip list, the camera and every character, made again at most every REFRESH seconds, not on every ray)
local REFRESH = 0.5
local madeAt = -math.huge
local function rays(): RaycastParams
	local now = os.clock()
	if now - madeAt < REFRESH then
		return params
	end
	madeAt = now
	local skip: { Instance } = {}
	local camera = workspace.CurrentCamera
	if camera then
		table.insert(skip, camera)
	end
	for _, player in Players:GetPlayers() do
		if player.Character then
			table.insert(skip, player.Character)
		end
	end
	params.FilterDescendantsInstances = skip
	return params
end

-- Test hook: only the Studio checks call this (tools/studio/fail_eat_check.py). What groundAbove has taken for
-- ground standing above the water, by the part's full name: how many times (nil: not keeping count).
Underwater.Seen = nil :: { [string]: number }?

function Underwater.on(): boolean
	return Config.Death.UnderWater ~= 0
end

-- The top of ground that stands above the water at `at`'s x and z (the strip, the dock), or nil: open water there
function Underwater.groundAbove(at: Vector3): number?
	local surface = Config.Depth.SurfaceY
	local from = Vector3.new(at.X, surface + LOOK_FROM, at.Z)
	local hit = workspace:Raycast(from, Vector3.new(0, -(LOOK_FROM + 0.05), 0), rays())
	local seen = Underwater.Seen
	if hit and seen then
		local name = hit.Instance:GetFullName()
		seen[name] = (seen[name] or 0) + 1
	end
	return if hit then hit.Position.Y else nil
end

-- The way from the dock out to the open water (flat), or nil without a dock
function Underwater.outward(): Vector3?
	local dock = Net.Folder:GetAttribute("Dock")
	if typeof(dock) ~= "CFrame" then
		return nil
	end
	local look = dock.LookVector * Vector3.new(1, 0, 1)
	return if look.Magnitude > 0.01 then look.Unit else nil
end

-- A throw near the surface goes less up and more back: `v` at `at`, its up share eased away over Death.ThrowShape
-- studs under Depth.SurfaceY, leaving flat and a little down (Death.ThrowDown) at the surface. Its speed is kept.
function Underwater.shapeThrow(v: Vector3, at: Vector3?): Vector3
	if not Underwater.on() or not at or v.Y <= 0 then
		return v
	end
	local d = Config.Death
	local k = math.clamp((Config.Depth.SurfaceY - at.Y) / math.max(d.ThrowShape, 1), 0, 1)
	if k >= 1 then
		return v
	end
	local speed = v.Magnitude
	local across = v * Vector3.new(1, 0, 1)
	local way = if across.Magnitude > 0.01 then across.Unit else nil
	local up = Ease.lerp(-d.ThrowDown * speed, v.Y, k)
	if not way then
		return Vector3.new(0, up, 0)
	end
	return way * math.sqrt(math.max(0, speed * speed - up * up)) + Vector3.new(0, up, 0)
end

-- The strip: `parts` (a loose body; `main` its middle) over ground that stands above the water are moved out along
-- the dock's way at Death.StripOut; heading onto it within Death.StripLook seconds, the part of their flat speed toward
-- it is taken off (the rest kept). Deeper than Death.StripDepth under the surface it is never near the strip.
function Underwater.strip(parts: { BasePart }, main: BasePart)
	local d = Config.Death
	if main.Position.Y < Config.Depth.SurfaceY - d.StripDepth then
		return
	end
	local v = main.AssemblyLinearVelocity
	local across = v * Vector3.new(1, 0, 1)
	if Underwater.groundAbove(main.Position) then
		local out = Underwater.outward() or (if across.Magnitude > 0.01 then -across.Unit else nil)
		if not out then
			return
		end
		for _, p in parts do
			if p.AssemblyRootPart == p then
				p.AssemblyLinearVelocity = out * d.StripOut + Vector3.new(0, p.AssemblyLinearVelocity.Y, 0)
			end
		end
		return
	end
	if across.Magnitude < 1 or not Underwater.groundAbove(main.Position + across * d.StripLook) then
		return
	end
	local way = across.Unit
	for _, p in parts do
		if p.AssemblyRootPart == p then
			local w = p.AssemblyLinearVelocity
			local toward = w:Dot(way)
			if toward > 0 then
				p.AssemblyLinearVelocity = w - way * toward
			end
		end
	end
end

-- The highest a drowning body's root may be: Death.UnderBy under Oxygen.SurfaceY
function Underwater.top(): number
	return Config.Oxygen.SurfaceY - Config.Death.UnderBy
end

return Underwater
