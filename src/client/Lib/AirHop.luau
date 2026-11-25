--!strict
-- The air hop on the screen (Hugo, 2026-11-25; docs/design/submarine.md, "The air hop"; Config.Sub's Air numbers). Where
-- everything is comes from the trip alone (Shared/SubAir); this is the rest, for SubController, which has the trips:
--   the swap: until the jump the land fish is the one seen (the dive's own, welded to its rider) and the trip's fish is
--     out of sight; at the jump the trip's fish takes its place in the same pose, and the land one is out of sight until
--     the server has taken it away. Never both, never neither;
--   someone else's trip: their body reaches us a moment late, so the whole of their trip is shown that much later;
--   the moments: the splashes of the sub and the fish, on every machine;
--   the rider's pose and our own camera's view.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Ease = require(ReplicatedStorage.Shared.Ease)
local SubAir = require(ReplicatedStorage.Shared.SubAir)
local SubTrip = require(ReplicatedStorage.Shared.SubTrip)
local Feel = require(script.Parent.Feel)
local Fx = require(script.Parent.Fx)
local Shake = require(script.Parent.Shake)
local Splash = require(script.Parent.Splash)
local State = require(script.Parent.State)

local AirHop = {}

local UP = Vector3.yAxis
local LAG_MOST = 0.5 -- someone else's body is at most this late, seconds

export type Flight = {
	Player: Player,
	Trip: SubTrip.Trip,
	Air: SubAir.Air,
	Lag: number, -- someone else's: how late we see their body
	From: CFrame?, -- our own: where we left the saddle,
	Velocity: Vector3, -- how fast,
	Began: number, -- and when
	View: CFrame?, -- our own camera as the trip came, against us,
	ViewFov: number,
	ViewAt: number, -- and when
	Eye: Vector3?, -- where it was last, against the sub, and what it looked at
	Look: Vector3?,
	Fov: number,
	Hidden: { [Instance]: any }, -- what is out of sight or held still on our screen, and how it was
	Fish: Model?, -- the trip's fish as last hidden
	Shown: boolean, -- it has been shown
	Land: Model?, -- the land fish as last hidden
	Pose: { [string]: CFrame }?, -- the land fish's joints as the jump began
	Motors: { [string]: any }?, -- and the trip's fish's
	SubNose: number, -- when the sub's nose touches the water, and the fish's
	FishNose: number,
	Said: { [string]: boolean },
}

local flights: { [Player]: Flight } = {}

local function surface(): number
	return Config.Depth.SurfaceY
end

-- The first moment after `from` that `height` is under the water (or `last`)
local function under(from: number, last: number, height: (number) -> number): number
	local t = from
	while t < last and height(t) > surface() do
		t += 0.01
	end
	return t
end

function AirHop.new(player: Player, trip: SubTrip.Trip): Flight?
	local air = trip.Air
	local e = trip.Escort
	if not air or not e then
		return nil
	end
	local f: Flight = {
		Player = player,
		Trip = trip,
		Air = air,
		Lag = 0,
		From = nil,
		Velocity = Vector3.zero,
		Began = 0,
		View = nil,
		ViewFov = 70,
		ViewAt = 0,
		Eye = nil,
		Look = nil,
		Fov = 70,
		Hidden = {},
		Fish = nil,
		Shown = false,
		Land = nil,
		Pose = nil,
		Motors = nil,
		SubNose = under(air.SeatAt, air.RideAt, function(t)
			return (SubAir.sub(air, t) * CFrame.new(0, 0, -e.Nose)).Y
		end),
		FishNose = under(air.Leap.Crouch, SubAir.entry(air), function(t)
			return (SubAir.fish(air, t) * CFrame.new(0, 0, -e.Half.Z)).Y
		end),
		Said = {},
	}
	flights[player] = f
	return f
end

local function once(f: Flight, key: string): boolean
	if f.Said[key] then
		return false
	end
	f.Said[key] = true
	return true
end

----------------------------------------------------------------------------------------------------------------------
-- What is seen

-- Out of sight on our screen; how it was is kept
local function hide(f: Flight, model: Model)
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") or d:IsA("Decal") then
			if f.Hidden[d] == nil then
				f.Hidden[d] = (d :: any).LocalTransparencyModifier
			end
			(d :: any).LocalTransparencyModifier = 1
		elseif
			d:IsA("ParticleEmitter")
			or d:IsA("Trail")
			or d:IsA("Beam")
			or d:IsA("BillboardGui")
			or d:IsA("Highlight")
			or d:IsA("Light")
		then
			local any = d :: any
			if f.Hidden[d] == nil then
				f.Hidden[d] = any.Enabled
			end
			any.Enabled = false
		end
	end
end

local function show(f: Flight, model: Model)
	for _, d in model:GetDescendants() do
		local was = f.Hidden[d]
		if was ~= nil then
			f.Hidden[d] = nil
			if d:IsA("BasePart") or d:IsA("Decal") then
				(d :: any).LocalTransparencyModifier = 0
			else
				(d :: any).Enabled = was
			end
		end
	end
end

-- The land fish a player rides (RideService's), if it is here
function AirHop.landFish(player: Player): Model?
	local folder = workspace:FindFirstChild("LandFish")
	if folder then
		for _, model in folder:GetChildren() do
			if model:IsA("Model") and model:GetAttribute("LandRider") == player.UserId then
				return model
			end
		end
	end
	return nil
end

local function motorsOf(model: Model): { [string]: any }
	local found = {}
	for _, d in model:GetDescendants() do
		if (d:IsA("Motor6D") or d:IsA("AnimationConstraint")) and string.sub(d.Name, 1, 4) == "Rig_" then
			found[d.Name] = d
		end
	end
	return found
end

-- Which of the two fish is seen, each frame. `fish`: the trip's, as SubController found it (nil: not here yet)
function AirHop.fish(f: Flight, fish: Model?, t: number)
	if t < f.Air.HopAt then
		if fish and fish.Parent then
			f.Fish = fish
			hide(f, fish)
		end
		return
	end
	local land = AirHop.landFish(f.Player)
	if fish and fish.Parent then
		if not f.Shown then
			f.Shown = true
			if land and t < f.Air.HopAt + 0.5 then
				-- (in the land fish's own pose, let go of bit by bit: AirHop.pose)
				local pose = {}
				for name, motor in motorsOf(land) do
					pose[name] = motor.Transform
				end
				f.Pose, f.Motors = pose, motorsOf(fish)
			end
			show(f, fish)
		end
		if land then
			f.Land = land
			hide(f, land)
		end
	elseif land and f.Player == State.Player then
		-- (not here yet, hardly ever: the land fish goes on in its place, off its rider)
		local root = land.PrimaryPart
		local weld = root and root:FindFirstChild("LandWeld")
		local cf = SubTrip.escort(f.Trip, t)
		if root and weld and cf then
			if f.Hidden[weld] == nil then
				f.Hidden[weld] = true
				f.Hidden[root] = root.Anchored
			end
			(weld :: any).Enabled = false
			root.Anchored = true
			root.CFrame = cf
		end
	end
end

-- The trip's fish's joints, after its own swim has been put in them
function AirHop.pose()
	for _, f in flights do
		local pose, motors = f.Pose, f.Motors
		if pose and motors then
			local t = workspace:GetServerTimeNow() - f.Trip.Start - f.Lag
			local w = Ease.smoothstep(f.Air.HopAt, f.Air.HopAt + 0.3, t)
			if w >= 1 then
				f.Pose, f.Motors = nil, nil
			else
				for name, motor in motors do
					local from = pose[name]
					if from then
						motor.Transform = from:Lerp(motor.Transform, w)
					end
				end
			end
		end
	end
end

-- Over, or given up: whatever is still here is seen again
function AirHop.remove(player: Player)
	local f = flights[player]
	flights[player] = nil
	if not f then
		return
	end
	for d, was in f.Hidden do
		if d.Parent then
			if d:IsA("WeldConstraint") or d:IsA("Weld") then
				(d :: any).Enabled = true
			elseif d:IsA("BasePart") then
				d.LocalTransparencyModifier = 0
				if type(was) == "boolean" then
					-- (the land fish held still for want of the other)
					d.Anchored = was
				end
			elseif d:IsA("Decal") then
				(d :: any).LocalTransparencyModifier = 0
			else
				(d :: any).Enabled = was
			end
		end
	end
	table.clear(f.Hidden)
end

----------------------------------------------------------------------------------------------------------------------
-- Someone else's trip

-- How late we see it: by where their body is on the fish's arc, until they jump
function AirHop.lag(f: Flight, t: number): number
	if t - f.Lag >= f.Air.HopAt then
		return f.Lag
	end
	local body = f.Player.Character
	local root = body and body:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return f.Lag
	end
	local best, at = 20, f.Lag
	for i = 0, 25 do
		local lag = LAG_MOST * i / 25
		local off = (SubAir.saddle(f.Air.Leap, t - lag) - root.Position).Magnitude
		if off < best then
			best, at = off, lag
		end
	end
	-- (eased: never back in time by more than it goes on)
	f.Lag = if f.Lag == 0 then at else Ease.lerp(f.Lag, at, 0.2)
	return f.Lag
end

----------------------------------------------------------------------------------------------------------------------
-- The moments, on every machine

local function powerOf(speed: number, size: number): number
	local d = Config.Dive
	local power = 0.25
		+ 0.75 * math.clamp((speed - d.LeapSplashFrom) / math.max(d.LeapSplashFull - d.LeapSplashFrom, 1), 0, 1)
	return math.min(power * size, 1)
end

local function splash(at: Vector3, way: Vector3, power: number, seed: number)
	local d = Config.Dive
	local eye = workspace.CurrentCamera.CFrame.Position
	local spot = Vector3.new(at.X, surface(), at.Z)
	if power <= 0 or (spot - eye).Magnitude > d.LeapSplashFar then
		return
	end
	Splash.play(spot, way, power, seed)
	if d.Splash > 0 then
		Fx.burstKept(spot - UP, math.ceil(d.Splash * power), d.SplashReach * power)
	end
end

-- The splashes, and our own sounds and shakes
function AirHop.moments(f: Flight, t: number)
	local c = Config.Sub
	local air = f.Air
	local e = f.Trip.Escort
	if not e then
		return
	end
	local own = f.Player == State.Player
	local seed = f.Player.UserId
	if t >= air.HopAt and t < air.RideAt and once(f, "hop") and own then
		Feel.sound("Swish", 0.8, 1.25, 0.5)
		Shake.play("Land", c.AirShake * 0.4)
	end
	if t >= air.SeatAt - 0.16 and t < air.RideAt and once(f, "by") and own then
		-- (it goes by overhead)
		Feel.sound("Whoosh", 0.7, 1.5, 0.6)
	end
	if t >= air.SeatAt and t < air.RideAt and once(f, "seat") then
		local character = f.Player.Character
		if character and c.AirSquash > 0 then
			State.Squash[character] = os.clock()
		end
		if own then
			Feel.sound("Swish", 0.6, 0.7, 0.4)
			Shake.play("LandBig", c.AirShake * 0.8)
		end
	end
	local sub = SubAir.sub(air, math.min(t, air.RideAt))
	if t >= f.SubNose and t < air.RideAt + 0.2 and once(f, "nose") then
		splash(
			(SubAir.sub(air, f.SubNose) * CFrame.new(0, 0, -e.Nose)).Position,
			sub.LookVector * 60,
			c.AirSplash * 0.8,
			seed + 1
		)
	end
	if t >= air.SplashAt and t < air.RideAt + 0.2 and once(f, "splash") then
		splash(SubAir.middle(air, air.SplashAt), sub.LookVector * 60, c.AirSplash, seed + 2)
		if own then
			Feel.sound("Splash", 0.9, 0.85, 2)
			Feel.sound("Whoosh", 0.5, 0.8, 0.8)
			Shake.play("LandBig", c.AirShake)
		end
	end
	-- the fish's own (its nose before the jump is the dive's: DiveController)
	local entry = SubAir.entry(air)
	local speed = SubAir.velocity(air.Leap, entry)
	local d = Config.Dive
	local size = math.clamp(e.Half.Z * 2 / math.max(d.LeapMountedSize, 1), d.LeapMountedLeast, d.LeapMountedMost)
	if t >= f.FishNose and f.FishNose > air.HopAt and t < entry + 0.3 and once(f, "fish nose") then
		splash(
			(SubAir.fish(air, f.FishNose) * CFrame.new(0, 0, -e.Half.Z)).Position,
			speed,
			powerOf(speed.Magnitude, size) * 0.8,
			seed + 3
		)
	end
	if t >= entry and t < entry + 0.3 and once(f, "fish") then
		splash(SubAir.fish(air, entry).Position, speed, powerOf(speed.Magnitude, size), seed + 4)
		if own then
			Feel.sound("Splash", 0.45, 0.75, 1.2)
		end
	end
end

-- Their own crossing of the surface is the sub's splash, not a diver's (DiveController.Quiet)
function AirHop.quiet(player: Player): boolean
	local f = flights[player]
	if not f then
		return false
	end
	local t = workspace:GetServerTimeNow() - f.Trip.Start - f.Lag
	return t >= f.Air.HopAt and t < f.Air.RideAt + 1
end

----------------------------------------------------------------------------------------------------------------------
-- The rider

-- State.AirPose
function AirHop.riderPose(player: Player): number?
	local f = flights[player]
	if not f then
		return nil
	end
	local c = Config.Sub
	local air = f.Air
	local t = workspace:GetServerTimeNow() - f.Trip.Start - f.Lag
	local hopAt = if f.From then f.Began else air.HopAt
	if player == State.Player and t >= air.HopAt and not f.From then
		return nil
	end
	local crouch = math.max(c.AirCrouch, 0.01)
	if t < hopAt - crouch or t > air.RideAt then
		return nil
	elseif t < hopAt then
		return (t - hopAt) / crouch
	end
	local ends = math.max(air.SeatAt, hopAt + c.AirLate)
	return math.clamp((t - hopAt) / math.max(ends - hopAt, 0.05), 0, 1)
end

-- Our own body, off the saddle at `t` (where it is now: `root`) and at any time after
function AirHop.begin(f: Flight, root: CFrame, t: number)
	f.From = root
	f.Began = t
	f.Velocity = SubAir.velocity(f.Air.Leap, t)
end

function AirHop.rider(f: Flight, t: number): CFrame
	return SubAir.hop(f.Air, f.From :: CFrame, f.Velocity, f.Began, t)
end

-- Someone else's body, put where their trip has it (theirs reaches us unevenly)
function AirHop.place(f: Flight, sub: CFrame, t: number)
	local air = f.Air
	local _, _, _, dropAt = SubTrip.times(f.Trip)
	if t < air.HopAt or t > dropAt - 0.2 then
		return
	end
	local body = f.Player.Character
	local root = body and body:FindFirstChild("HumanoidRootPart")
	local humanoid = body and body:FindFirstChildOfClass("Humanoid")
	if
		not root
		or not root:IsA("BasePart")
		or not humanoid
		or humanoid.Health <= 0
		or f.Player:GetAttribute("State") ~= "Carried"
	then
		return
	end
	local cf = if t < air.RideAt then SubAir.rider(air, t) else sub * SubTrip.Seat
	root.CFrame = root.CFrame:Lerp(cf, Ease.smoothstep(air.HopAt, air.HopAt + 0.12, t))
end

----------------------------------------------------------------------------------------------------------------------
-- Our own camera

local function angles(look: Vector3): (number, number)
	local l = if look.Magnitude > 1e-3 then look.Unit else Vector3.new(0, 0, -1)
	return math.atan2(-l.X, -l.Z), math.asin(math.clamp(l.Y, -1, 1))
end

-- The view at `t`, with us at `rider`: from the player's own view as the trip came, round to behind us and on by the trip
function AirHop.view(f: Flight, rider: Vector3, t: number): (CFrame, number)
	local c = Config.Sub
	local air = f.Air
	local camera = workspace.CurrentCamera
	local eye, look = SubAir.eye(air, t)
	-- (with us, wherever we really are)
	local plan = SubAir.rider(air, t).Position
	local off = (rider - plan) * (1 - Ease.smoothstep(air.SeatAt, air.RideAt, t))
	eye += off
	look += off
	if not f.View then
		f.View = CFrame.new(camera.CFrame.Position - rider) * camera.CFrame.Rotation
		f.ViewFov = camera.FieldOfView
		f.ViewAt = t
	end
	local from = f.View :: CFrame
	local w = Ease.smoothstep(f.ViewAt, f.ViewAt + math.max(c.AirCamIn, 0.05), t)
	local at = eye
	local yaw, pitch = angles(look - eye)
	if w < 1 then
		-- (round us, not through us: by the way it stands from us, how far, and how high)
		local a, b = from.Position, eye - rider
		local turn = Ease.lerpAngle(math.atan2(a.X, a.Z), math.atan2(b.X, b.Z), w)
		local far = Ease.lerp(Vector3.new(a.X, 0, a.Z).Magnitude, Vector3.new(b.X, 0, b.Z).Magnitude, w)
		at = rider + Vector3.new(math.sin(turn) * far, Ease.lerp(a.Y, b.Y, w), math.cos(turn) * far)
		local yaw0, pitch0 = angles(from.LookVector)
		-- (looking at what it will, from where it is)
		local yaw1, pitch1 = angles(look - at)
		yaw, pitch = Ease.lerpAngle(yaw0, yaw1, w), Ease.lerp(pitch0, pitch1, w)
	end
	local rush = Ease.smoothstep(air.HopAt, air.SeatAt, t) * 6
	local kick = c.AirFov
		* Ease.smoothstep(air.SplashAt - 0.1, air.SplashAt, t)
		* (1 - 0.6 * Ease.smoothstep(air.SplashAt, air.RideAt, t))
	local fov = Ease.lerp(f.ViewFov, 70, w) + rush + kick
	local view = CFrame.new(at) * CFrame.fromOrientation(pitch, yaw, 0)
	local sub = SubAir.middle(air, math.min(t, air.RideAt))
	f.Eye, f.Look, f.Fov = at - sub, at + view.LookVector * math.max((look - at).Magnitude, 10) - sub, fov
	return view, fov
end

return AirHop
