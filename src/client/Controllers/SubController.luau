--!strict
-- The submarine on every machine (docs/design/submarine.md). The server writes a trip on the player it carries
-- ("SubTrip", Shared/SubTrip) and its phase ("SubPhase"); each machine builds its own placeholder sub for each trip and
-- moves it by the clock, so it costs no traffic. For our own trip we also move ourselves (the server has us "Carried":
-- our machine owns the character) and the camera:
--   Approach: we swim on just under the surface while the sub comes up from behind and below, its light on us. The
--     camera sits behind us on our own line, tipping down as the sub comes in under us.
--   Pickup: it rises under us; we are scooped up in a tumble and set on the seat behind its tower. A splash, a bump.
--     The camera stays behind us and draws back to where the run's view begins.
--   Ride: it noses down and runs the herd's line at up to its trip's top speed (Shared/SubTrip.plan). The camera is behind it, wider with speed, with
--     speed lines and a rumble. Each land crossed shows its title (UI/LandStrip), handing off fast (task t1).
--   Arrive: "NOW ARRIVING" in the land title's look, in place of that land's own title, at the drop speed; the
--     camera stays behind the sub, a little further back when our fish swims up beside it.
--   Drop: on the server's word, flung forward into an ordinary hop (JumpController.fling), or, with our fish swum up
--     beside the sub ("SubFish", driven here), kicked off in an arc onto its saddle; we tell the server ("SubLand").
--   Then the sub peels away, up and to the side, and fades.
--   The escort (Hugo, 2026-11-24; Config.Sub.Escort): a rider who went in on their ride fish rides it out to the sub
--   instead of swimming, and hops off its saddle onto the seat; the fish sweeps left and right with the sub for the run
--   and is back beside it for the kick. Every machine moves it by the trip (SubTrip.escort) while the server has it
--   anchored (the fish of Workspace.Fish whose SubFor is that player), and while its rider sits on it keeps it under them.
--   The air hop (Hugo, 2026-11-25; Config.Sub.AirHop; Lib/AirHop, Shared/SubAir): a leap on the ride fish off the lip with
--   a trip set is told to the server as it begins ("SubLeap"), and its trip comes back while we are in the air: we jump
--   off the saddle by ourselves (HopAt, by the clock, before the server's "Carried" may have come), the sub flies in under
--   us, and it splashes into its run. Until the run everything here is `flight`; without the word in time the dive goes
--   on and the trip is the escort's, under water.
-- The camera is behind in every phase, on the middle line of what it follows, and never at the side or on its way
-- round one (Hugo, 2026-11-23: "make sure it doesnt implement the camera on the side ever").
-- The sub is the model of the tier the player has equipped (Shared/SubModels: a model a tier from the place's
-- templates, since 2026-11-23 in the toy style, else the old placeholder of plain parts); the motion is still by code
-- (the *Pose functions) until the partner's animations (the note's "Animation hooks").
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)
local Ease = require(ReplicatedStorage.Shared.Ease)
local Net = require(ReplicatedStorage.Shared.Net)
local SubAir = require(ReplicatedStorage.Shared.SubAir)
local SubModels = require(ReplicatedStorage.Shared.SubModels)
local SubTrip = require(ReplicatedStorage.Shared.SubTrip)
local AirHop = require(script.Parent.Parent.Lib.AirHop)
local Feel = require(script.Parent.Parent.Lib.Feel)
local Fx = require(script.Parent.Parent.Lib.Fx)
local Shake = require(script.Parent.Parent.Lib.Shake)
local State = require(script.Parent.Parent.Lib.State)
local LandStrip = require(script.Parent.Parent.UI.LandStrip)
local SubPanel = require(script.Parent.Parent.UI.SubPanel)
local DiveController = require(script.Parent.DiveController)
local JumpController = require(script.Parent.JumpController)

local SubController = {}

local SEAT = SubTrip.Seat
local UP = Vector3.yAxis

type Visual = {
	Player: Player,
	Trip: SubTrip.Trip,
	Model: Model,
	Parts: { BasePart },
	Prop: BasePart,
	Bubbles: ParticleEmitter,
	Spin: number,
	Last: CFrame?,
	Faded: boolean,
	-- our own trip only
	Entry: CFrame?, -- where we were as it began
	Cue: string?, -- the server's word at the drop: "Fling" or "Kick"
	CuedAt: number,
	Kicking: boolean, -- the kick was under way when that word came (the fish given up in the middle of it)
	Fish: Model?, -- our fish, beside the sub
	FishFrom: Vector3?,
	FishGot: number,
	Told: boolean, -- "SubLand" sent
	Seated: boolean, -- the server has put us on our fish (State.Mode's word comes a moment after)
	Said: { [string]: boolean }, -- the moments already played (sounds, bursts, banners)
	RiderLast: Vector3?,
	-- a trip with an escort, every machine
	LookAt: number, -- os.clock() the fish was last looked for
	Carry: CFrame?, -- our own trip: where the fish really was as it began, against where the trip has it (eased away)
	HopFrom: CFrame?, -- where we left the saddle
	Thin: number, -- our own trip: how see-through the fish is on our screen (the camera is in its body)
	ThinParts: { Instance }, -- the parts of it that takes
	Lost: CFrame?, -- where we were as the fish was given up under us,
	LostAt: number, -- and when, seconds into the trip
	Flight: AirHop.Flight?, -- the air hop's
	Held: boolean, -- our own: the camera has been handed on to the run's
}

local visuals: { [Player]: Visual } = {}
local mine: Visual? = nil
local camPos: Vector3? = nil
local camFocus: Vector3? = nil
local camKind = "" -- what the camera's offsets are from: "rider" or "sub"
local camParams: RaycastParams? = nil
local camAnchor = Vector3.zero -- and where that was last frame (zero: the offsets are places in the world)
local fov = 70
local kelpOut = false -- the gate's kelp is see-through for us now (gateKelp)
local gui: ScreenGui

local function now(): number
	return workspace:GetServerTimeNow()
end

local function flat(v: Vector3): Vector3
	local f = Vector3.new(v.X, 0, v.Z)
	return if f.Magnitude > 0.01 then f.Unit else Vector3.new(0, 0, -1)
end

local function yawOf(look: Vector3): number
	return math.atan2(-look.X, -look.Z)
end

local function landName(index: number): string
	local zone = State.Zones[index]
	return if zone then string.upper(zone.Name) else ("LAND " .. index)
end

local function makeVisual(player: Player, trip: SubTrip.Trip): Visual
	-- (the sub the player has equipped at the stand: SubService's SubEquip)
	local equip = player:GetAttribute("SubEquip")
	local model, parts, prop, bubbles = SubModels.build(if type(equip) == "number" and equip >= 1 then equip else 1)
	-- every part's place against the hull's own frame
	local hull = model.PrimaryPart :: BasePart
	local offsets: { [BasePart]: CFrame } = {}
	for _, p in parts do
		offsets[p] = hull.CFrame:ToObjectSpace(p.CFrame)
	end
	model:SetAttribute("For", player.UserId)
	model.Parent = workspace.CurrentCamera
	local v: Visual = {
		Player = player,
		Trip = trip,
		Model = model,
		Parts = parts,
		Prop = prop,
		Bubbles = bubbles,
		Spin = 0,
		Last = nil,
		Faded = false,
		Entry = nil,
		Cue = nil,
		CuedAt = 0,
		Kicking = false,
		Fish = nil,
		FishFrom = nil,
		FishGot = 0,
		Told = false,
		Seated = false,
		Said = {},
		RiderLast = nil,
		LookAt = 0,
		Carry = nil,
		HopFrom = nil,
		Thin = 0,
		ThinParts = {},
		Lost = nil,
		LostAt = 0,
		Flight = AirHop.new(player, trip),
		Held = false,
	}
	local more = v :: any
	more.Offsets = offsets
	more.HullRest = hull.CFrame -- the hull part against the sub's middle (a model is built at the origin)
	return v
end

local function place(v: Visual, cf: CFrame, speed: number, dt: number)
	local offsets = (v :: any).Offsets :: { [BasePart]: CFrame }
	-- (never so far in one frame that the two flights read as standing still or turning backwards: the screw looks the
	-- same every half turn. docs/design/sub-props.md, "The turn rule")
	local c = Config.Sub
	v.Spin += math.min(dt * (c.PropIdle + speed * c.PropPerSpeed), math.rad(c.PropStepMost))
	local spun = CFrame.Angles(0, 0, v.Spin)
	-- the hull part's own place and turn in the sub (the placeholder's is a cylinder lying along X; a model's hull
	-- is a mesh whose middle isn't the sub's)
	local hull = v.Model.PrimaryPart :: BasePart
	local hullFrame = cf * ((v :: any).HullRest :: CFrame)
	for p, offset in offsets do
		if p == hull then
			p.CFrame = hullFrame
		elseif p == v.Prop or p.Name == "Prop_Glow" then
			p.CFrame = hullFrame * offset * spun
		else
			p.CFrame = hullFrame * offset
			if p.Name == "Blur" then
				-- the blur disc shows with the speed
				p.Transparency = 1 - c.PropBlurMost * Ease.smoothstep(c.PropBlurFrom, c.PropBlurFull, speed)
			end
		end
	end
	-- the bubble trail: more with the speed, and none once the sub is fading out (its bubbles do not fade with it)
	-- (and none in the air)
	local dry = v.Trip.Air ~= nil and cf.Y > Config.Depth.SurfaceY
	v.Bubbles.Rate = if v.Faded or dry then 0 else math.min(c.WakeLeast + speed * c.WakePerSpeed, c.WakeMost)
	v.Last = cf
end

-- The gate's kelp (the curtain hanging under the dock's lip), see-through on our own screen or back as the map made
-- it. With the camera behind us (cameraFor) the curtain hangs between it and us from the moment we go in until the
-- sub has carried us off, and the pull-in cannot keep the camera out of it: the kelp is not a thing a ray can hit
-- (CanQuery off). Without this, the view was a wall of green as we were thrown onto the seat. Only the plates under
-- the water, only for us (LocalTransparencyModifier, on each plate and its pictures, as PropController does for the
-- lane's props), and only while our own trip's camera is back there: it looks away from the dock, so the kelp going
-- and coming back is never in the picture.
local function gateKelp(out: boolean)
	if out == kelpOut then
		return
	end
	kelpOut = out
	local map = workspace:FindFirstChild("ClaudeBlockout")
	local dock = map and map:FindFirstChild("Dock")
	local gate = dock and dock:FindFirstChild("Gate")
	if not gate then
		return
	end
	local by = if out then 1 else 0
	for _, part in gate:GetChildren() do
		if part:IsA("BasePart") and part.Name == "Kelp" and part.Position.Y < Config.Oxygen.SurfaceY then
			part.LocalTransparencyModifier = by
			for _, picture in part:GetChildren() do
				if picture:IsA("Decal") then
					picture.LocalTransparencyModifier = by
				end
			end
		end
	end
end

local function remove(player: Player)
	local v = visuals[player]
	if v then
		v.Model:Destroy()
		visuals[player] = nil
		AirHop.remove(player)
	end
	if v and v == mine then
		mine = nil
		State.SubAloft = false
		local flight = v.Flight
		if flight and flight.From and not v.Held then
			-- (given up in the air, off the fish's back: let go of; on its back the dive just goes on)
			State.Leaping = false
			if State.Mode == "Dock" then
				local _, _, humanoid = State.character()
				if humanoid then
					humanoid.PlatformStand = false
				end
				workspace.CurrentCamera.CameraType = Enum.CameraType.Custom
				workspace.CurrentCamera.FieldOfView = Config.Camera.Fov
			end
		end
		gateKelp(false)
		Shake.rumble("Sub", "Speed", 0)
		-- given up before the drop: the land titles go back to normal, the arrival land's own included
		if not v.Said.dropped then
			LandStrip.subEnd(false)
		end
	end
end

-- A banner over the middle of the screen, for a moment (NOW ARRIVING's own, only when there is no land strip to give
-- it the land title's look)
local function banner(top: string, big: string, colour: Color3, time: number)
	local frame = Instance.new("Frame")
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = UDim2.fromScale(0.5, 0.24)
	frame.Size = UDim2.fromOffset(560, 110)
	frame.BackgroundTransparency = 1
	frame.Parent = gui
	local function line(text: string, y: number, h: number, c: Color3)
		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.Position = UDim2.fromOffset(0, y)
		label.Size = UDim2.new(1, 0, 0, h)
		label.Font = Enum.Font.LuckiestGuy
		label.TextScaled = true
		label.Text = text
		label.TextColor3 = c
		label.Parent = frame
		local edge = Instance.new("UIStroke")
		edge.Thickness = 3
		edge.Color = Color3.fromRGB(16, 36, 63)
		edge.Parent = label
		return label
	end
	line(top, 0, 34, Color3.new(1, 1, 1))
	line(big, 36, 64, colour)
	local scale = Instance.new("UIScale")
	scale.Scale = 0.4
	scale.Parent = frame
	local born = os.clock()
	local conn: RBXScriptConnection
	conn = RunService.RenderStepped:Connect(function()
		local age = os.clock() - born
		if age > time or not frame.Parent then
			conn:Disconnect()
			frame:Destroy()
			return
		end
		-- a pop in with an overshoot, a fade out
		scale.Scale = if age < 0.25
			then Ease.lerp(0.4, 1.12, age / 0.25)
			elseif age < 0.4 then Ease.lerp(1.12, 1, (age - 0.25) / 0.15)
			else 1
		local fade = math.clamp((age - (time - 0.4)) / 0.4, 0, 1)
		for _, label in frame:GetChildren() do
			if label:IsA("TextLabel") then
				label.TextTransparency = fade
				local stroke = label:FindFirstChildOfClass("UIStroke")
				if stroke then
					stroke.Transparency = fade
				end
			end
		end
	end)
end

local function once(v: Visual, key: string): boolean
	if v.Said[key] then
		return false
	end
	v.Said[key] = true
	return true
end

-- Where the trip has the escort's root, on our own machine with the pose the dive left it in eased away
local function escortAt(v: Visual, t: number): CFrame?
	local cf = SubTrip.escort(v.Trip, t)
	local air = v.Trip.Air
	if cf and v.Carry and air then
		return cf * CFrame.new():Lerp(v.Carry, 1 - Ease.smoothstep(air.HopAt, air.HopAt + 0.3, t))
	elseif cf and v.Carry then
		local pickupAt = SubTrip.times(v.Trip)
		return cf * CFrame.new():Lerp(v.Carry, 1 - Ease.smoothstep(0, 0.6 * pickupAt, t))
	end
	return cf
end

-- The escort given up on (its SubLeave, SubService): it veers off and fades. True while it is leaving
local function leaving(v: Visual, fish: Model, root: BasePart): boolean
	local at = fish:GetAttribute("SubLeave")
	if type(at) ~= "number" then
		return false
	end
	local k = math.clamp((now() - at) / math.max(Config.Sub.EscortFade, 0.05), 0, 1)
	local cf = escortAt(v, now() - v.Trip.Start)
	if cf and root.Anchored then
		root.CFrame = cf * CFrame.Angles(0, -0.7 * k, 0) + cf.RightVector * (40 * k * k) - UP * (10 * k * k)
	end
	for _, d in fish:GetDescendants() do
		if d:IsA("BasePart") or d:IsA("Decal") then
			(d :: any).LocalTransparencyModifier = k
		end
	end
	return true
end

-- The escort, each frame, on every machine: found (the server made it as the trip began), and put where the trip has it
-- while the server has it anchored. Our own once the server has let go of it is driveFish's
local function escort(v: Visual, t: number)
	local trip = v.Trip
	local e = trip.Escort
	if not e then
		return
	end
	local pickupAt, _, _, _, endAt = SubTrip.times(trip)
	if (not v.Fish or not v.Fish.Parent) and t < endAt and os.clock() - v.LookAt > 0.05 then
		v.LookAt = os.clock()
		v.Fish = nil
		local folder = workspace:FindFirstChild("Fish")
		if folder then
			for _, model in folder:GetChildren() do
				if model:IsA("Model") and model:GetAttribute("SubFor") == v.Player.UserId then
					v.Fish = model
					break
				end
			end
		end
	end
	local fish = v.Fish
	local root = fish and fish.PrimaryPart
	if not fish or not root or leaving(v, fish, root) or not root.Anchored then
		return
	end
	local cf = escortAt(v, t)
	if not cf then
		return
	end
	-- someone else's: while they sit on it, under where we see them (their body reaches us a moment late)
	local hopAt = pickupAt + Config.Sub.EscortHopFrom * trip.Pickup
	if v ~= mine and t < hopAt + 0.25 and not trip.Air then
		local body = v.Player.Character
		local rider = body and body:FindFirstChild("HumanoidRootPart")
		if rider and rider:IsA("BasePart") and (rider.Position - cf.Position).Magnitude < 80 + e.Half.Z then
			local under = rider.CFrame * CFrame.new(-e.Saddle)
			cf = under:Lerp(cf, Ease.smoothstep(hopAt - 0.15, hopAt + 0.2, t))
		end
	end
	root.CFrame = cf
	-- (its swim beats to this, AnimController: not to the sub's thousands of studs a second)
	root.AssemblyLinearVelocity = cf.LookVector * Config.Sub.EscortPace
end

-- Our own fish see-through on our screen while the camera is in its body (a fish taller than the water under the camera's
-- own ceiling, or the camera pulled in off the gate), and back as the camera comes out of it: on the way out to the sub
-- only, all of it back by the run
local function thin(v: Visual, t: number, dt: number)
	local e = v.Trip.Escort
	local fish = v.Fish
	local root = fish and fish.PrimaryPart
	if not e or not fish or not root or fish:GetAttribute("SubLeave") ~= nil then
		return
	end
	local _, rideAt = SubTrip.times(v.Trip)
	local want = 0
	local air = v.Trip.Air
	-- (after the air hop: until it has swum up to its place)
	if t < (if air then SubAir.entry(air) + SubAir.joining(e.Half) else rideAt + 0.5) then
		local o = root.CFrame:PointToObjectSpace(workspace.CurrentCamera.CFrame.Position)
		local room = Config.Sub.EscortThinRoom
		if math.abs(o.X) < e.Half.X + room and math.abs(o.Y) < e.Half.Y + room and math.abs(o.Z) < e.Half.Z + room then
			want = Config.Sub.EscortThin
		end
	end
	if want == 0 and v.Thin == 0 then
		return
	end
	if #v.ThinParts == 0 then
		for _, d in fish:GetDescendants() do
			if d:IsA("BasePart") or d:IsA("Decal") then
				table.insert(v.ThinParts, d)
			end
		end
	end
	v.Thin += (want - v.Thin) * Ease.alpha(14, dt)
	if want == 0 and v.Thin < 0.02 then
		v.Thin = 0
	end
	for _, d in v.ThinParts do
		(d :: any).LocalTransparencyModifier = v.Thin
	end
end

-- A fish's own movers, kept in step with where we put it
local function steerFish(root: BasePart, way: Vector3, speed: number)
	local swim = root:FindFirstChild("Swim")
	if swim and swim:IsA("LinearVelocity") then
		swim.VectorVelocity = way * speed
	end
	local turn = root:FindFirstChild("Turn")
	if turn and turn:IsA("AlignOrientation") then
		turn.CFrame = CFrame.lookAt(Vector3.zero, way)
	end
end

-- Our fish beside the sub: from where it was made, up alongside on the right, matching the sub
local function driveFish(v: Visual, sub: CFrame, speed: number, t: number)
	local fish = v.Fish
	local root = fish and fish.PrimaryPart
	if not fish or not root or not fish.Parent then
		return
	end
	if fish:GetAttribute("Rider") ~= 0 and fish:GetAttribute("Rider") ~= nil then
		-- (we are on it: RideController drives it now)
		v.Fish = nil
		v.Seated = v.Seated or (v == mine and fish:GetAttribute("Rider") == State.Player.UserId)
		return
	end
	if v.Trip.Escort then
		-- (the fish we came on: beside the sub by the trip, and ours to move since the server let go of it)
		local cf = SubTrip.escort(v.Trip, t)
		if cf and not root.Anchored and fish:GetAttribute("SubLeave") == nil then
			root.CFrame = cf
			root.AssemblyLinearVelocity = sub.LookVector * speed
			root.AssemblyAngularVelocity = Vector3.zero
			steerFish(root, sub.LookVector, speed)
		end
		return
	end
	local _, _, _, dropAt = SubTrip.times(v.Trip)
	local c = Config.Sub
	local way = sub.LookVector
	local side = flat(way):Cross(UP)
	local beside = sub.Position + side * c.FishSide - UP * 2
	local from = (v.FishFrom or root.Position) + way * speed * math.max(0, os.clock() - v.FishGot)
	local e = Ease.smoothstep(dropAt - c.FishIn, dropAt - c.FishIn * 0.1, t)
	local at = from:Lerp(beside, e)
	local wiggle = math.sin(os.clock() * 9) * 0.12
	root.CFrame = CFrame.lookAt(at, at + way) * CFrame.Angles(0, wiggle, 0)
	root.AssemblyLinearVelocity = way * speed
	root.AssemblyAngularVelocity = Vector3.zero
	steerFish(root, way, speed)
end

-- Where we are on our own trip: swimming, scooped up, on the seat, kicked onto our fish
local function riderAt(v: Visual, sub: CFrame, t: number): CFrame?
	local trip = v.Trip
	local pickupAt, rideAt = SubTrip.times(trip)
	local seat = sub * SEAT
	local way0 = flat(SubTrip.way(trip, 30, 30))
	local swimTo = trip.Points[1] + SEAT.Position + Vector3.new(0, 0.5, 0)
	local entry = v.Entry
	local escorted = trip.Escort
	if escorted and v.Lost and t < rideAt then
		-- (the fish was given up under us: up onto the seat from where we were)
		return v.Lost:Lerp(seat, Ease.smoothstep(v.LostAt, rideAt, t))
	elseif escorted and t < rideAt then
		local c = Config.Sub
		local u = (t - pickupAt) / math.max(rideAt - pickupAt, 0.01)
		local saddle = (escortAt(v, t) or seat) * CFrame.new(escorted.Saddle)
		if u <= c.EscortHopFrom then
			-- (saddlePose) on its back, out to the sub
			return saddle
		end
		-- (hopPose) off its back in an arc across onto the seat, facing down the lane all the way
		local from = v.HopFrom or saddle
		v.HopFrom = from
		local k = Ease.smoothstep(c.EscortHopFrom, c.EscortHopTo, u)
		local at = from.Position:Lerp(seat.Position, k) + UP * (c.EscortHopUp * math.sin(k * math.pi))
		local lean = CFrame.Angles(math.rad(-22) * math.sin(k * math.pi), 0, 0)
		return CFrame.new(at) * from.Rotation:Lerp(seat.Rotation, k) * lean
	end
	if t < pickupAt and entry then
		-- (approachPose) swimming on toward the pick-up, bobbing
		local u = math.clamp(t / math.max(pickupAt, 0.01), 0, 1)
		local at = entry.Position:Lerp(swimTo, Ease.smoothstep(0, 1, u)) + UP * math.sin(t * 5) * 0.4
		return CFrame.lookAt(at, at + way0) * CFrame.Angles(math.rad(-70), 0, 0)
	elseif t < rideAt then
		-- (pickupPose) held until the sub is under us, then tumbled up and over onto the seat
		local u = (t - pickupAt) / math.max(rideAt - pickupAt, 0.01)
		local from = CFrame.lookAt(swimTo, swimTo + way0) * CFrame.Angles(math.rad(-70), 0, 0)
		if u < 0.3 then
			return from
		end
		local k = Ease.smoothstep(0.3, 0.82, u)
		local at = from.Position:Lerp(seat.Position, k) + UP * (6 * math.sin(k * math.pi))
		local flip = CFrame.Angles(-math.pi * 2 * Ease.inOutSine(k), 0, 0)
		local turned = from.Rotation:Lerp(seat.Rotation, k)
		return CFrame.new(at) * turned * flip
	elseif v.Cue == "Kick" then
		-- (kickPose) off the seat in an arc onto our fish's saddle, rolling over
		local fish = v.Fish
		local root = fish and fish.PrimaryPart
		local saddle = root and root:FindFirstChild("Saddle")
		if not saddle or not saddle:IsA("Attachment") then
			return seat
		end
		local k = math.clamp((os.clock() - v.CuedAt) / math.max(Config.Sub.Kick, 0.05), 0, 1)
		local e = Ease.inOutSine(k)
		local target = saddle.WorldCFrame
		local at = seat.Position:Lerp(target.Position, e) + UP * (9 * math.sin(k * math.pi))
		local roll = CFrame.Angles(0, 0, -math.pi * 2 * e)
		return CFrame.new(at) * seat.Rotation:Lerp(target.Rotation, e) * roll
	end
	return seat
end

-- The camera on our own trip: behind in every phase, on the middle line of what it follows (us, then the sub), and
-- looking down that line. No part of `goal` or `focus` goes to the side, and no phase swings round from the front:
-- Hugo, 2026-11-23, "make sure it doesnt implement the camera on the side ever".
local function cameraFor(v: Visual, sub: CFrame, speed: number, rider: Vector3, t: number, dt: number)
	local camera = workspace.CurrentCamera
	local trip = v.Trip
	local c = Config.Sub
	local pickupAt, rideAt, arriveAt = SubTrip.times(trip)
	local way0 = flat(SubTrip.way(trip, 30, 30))
	-- how far under us the sub is: the view tips down by a share of it, so the sub shows as it comes in under us
	-- (only its depth: its place behind us and off to one side never turns the view)
	local under = math.max(0, rider.Y - sub.Position.Y)
	local goal: Vector3
	local focus: Vector3
	local rate = 4
	local wide = 70
	-- (on the fish's back: behind its tail, and over the top of it)
	local e = trip.Escort
	local over = if e then math.max(3, e.Half.Y - e.Saddle.Y + 3) else 0
	local tail = if e then math.clamp(e.Half.Z - e.Saddle.Z + 5, 10, c.EscortBack) else 0
	-- (the swim's and the pick-up's easing go by those phases' own lengths, so the camera makes the same move however
	-- long they are: 4 and 5 a second when they were 1.6 and 0.96 s)
	if t < pickupAt then
		rate = 6.4 / math.max(trip.Approach, 0.1)
		-- behind us on our own line, close at first (the dock and the gate's posts are just behind where we went in),
		-- drawing back as we swim on; tipping down to the sub as it comes
		-- (looking at a point ahead of us, so the view stays down the lane even pulled right in against a wall)
		local u = math.clamp(t / math.max(pickupAt, 0.01), 0, 1)
		goal = rider - way0 * math.max(10 + 8 * u, tail) + UP * (if e then over else 1)
		focus = rider + way0 * 12 - UP * (0.4 * under * Ease.smoothstep(0.3, 1, u))
	elseif t < rideAt then
		-- still behind, to see us thrown onto the seat: back and up to where the run's view begins, levelling out
		local u = (t - pickupAt) / math.max(rideAt - pickupAt, 0.01)
		goal = rider
			- way0 * (if e then Ease.lerp(math.max(18, tail), 24, u) else 18 + 6 * u)
			+ UP * (if e then over + (9 - over) * u else 1 + 8 * u)
		focus = rider + way0 * 12 - UP * (0.4 * under * (1 - u))
		rate = 4.8 / math.max(trip.Pickup, 0.1)
	elseif t < arriveAt then
		-- behind it, wider with speed
		local way = sub.LookVector
		local share = math.clamp(speed / math.max(c.Speed, 1), 0, 1)
		goal = sub.Position - way * (c.Distance + 8 * share) + UP * (10 - 3 * share)
		focus = sub.Position + way * (25 + 20 * share)
		rate = 7
		-- (and wider still on a far land's faster run: Sub.FovFar more at Sub.FovFarAt studs a second)
		local far = math.clamp((speed - c.Speed) / math.max(c.FovFarAt - c.Speed, 1), 0, 1)
		wide = 70 + c.Fov * share + c.FovFar * far
	else
		-- still behind it for the drop, looking straight down its way. Our fish swims up Sub.FishSide beside it: the
		-- camera keeps it in view by standing a little further back, not by moving or turning to that side
		local way = flat(sub.LookVector)
		goal = sub.Position - way * (30 + (if trip.Fish then 6 else 0)) + UP * 9
		focus = sub.Position + way * 10
		rate = 4
		wide = 74
	end
	-- Eased as offsets from what it follows (us, then the sub), never as places in the world: eased in the world, a
	-- camera falls far behind a sub doing a thousand studs a second. Switching what it follows keeps where it is.
	local anchor = if t < rideAt then rider else sub.Position
	local kind = if t < rideAt then "rider" else "sub"
	if kind ~= camKind or not camPos or not camFocus then
		-- (the trip's first frame cuts to its first framing, under the splash: eased from the dock's view, the camera
		-- went down through the hub's floor and the gate's posts)
		local first = camKind == "" or not camPos or not camFocus
		if first and e then
			-- (on a fish's back the dive's film has us behind it already, or beside a big one, under the water: on from its
			-- last view and width, no cut. Its own word for them: letting go, it gave the camera back to Roblox's own,
			-- which has put it somewhere else by now)
			local hand = DiveController.handOver()
			local said = if hand and hand.mounted and os.clock() - hand.at < 0.5 then hand else nil
			local from = if said then said.view else camera.CFrame
			local back = rider - from.Position
			local level = Vector3.new(back.X, 0, back.Z)
			if
				from.Position.Y < Config.Oxygen.SurfaceY
				and back:Dot(way0) > 5
				and back.Magnitude < 100 + e.Half.Z
				and (level - way0 * level:Dot(way0)).Magnitude < 60 + e.Half.X
				and from.LookVector:Dot(way0) > 0
			then
				if said then
					fov = said.fov
				end
				camPos = from.Position - anchor
				camFocus = from.Position + from.LookVector * (back:Dot(way0) + 12) - anchor
				first = false
				camAnchor = anchor
			end
		end
		camPos = if first then goal - anchor else camAnchor + (camPos :: Vector3) - anchor
		camFocus = if first then focus - anchor else camAnchor + (camFocus :: Vector3) - anchor
		camKind = kind
		if first then
			fov = 70
		end
	end
	camAnchor = anchor
	local a = Ease.alpha(rate, dt)
	camPos = (camPos :: Vector3):Lerp(goal - anchor, a)
	camFocus = (camFocus :: Vector3):Lerp(focus - anchor, Ease.alpha(rate * 1.4, dt))
	local look = anchor + (camFocus :: Vector3)
	local at = anchor + (camPos :: Vector3)
	-- kept out of the walls and the floor: pulled in toward what it follows (not for the lane's props, which go
	-- see-through, PropController)
	if not camParams then
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.IgnoreWater = true
		camParams = params
	end
	local params = camParams :: RaycastParams
	local map = workspace:FindFirstChild("ClaudeBlockout")
	local lane = map and map:FindFirstChild("Lane")
	local props = lane and lane:FindFirstChild("Props")
	local surface = map and map:FindFirstChild("Surface")
	local skip: { Instance } = { camera, v.Model }
	if State.Player.Character then
		table.insert(skip, State.Player.Character)
	end
	if props then
		table.insert(skip, props)
	end
	if surface then
		table.insert(skip, surface)
	end
	if v.Fish then
		table.insert(skip, v.Fish)
	end
	params.FilterDescendantsInstances = skip
	local from = anchor + UP * 2
	local hit = workspace:Raycast(from, at - from, params)
	if hit then
		at = from + (at - from).Unit * math.max(0, (hit.Position - from).Magnitude - 2)
	end
	-- (never up in the water's surface layers)
	local top = Config.Oxygen.SurfaceY - 7
	if at.Y > top then
		at = Vector3.new(at.X, top, at.Z)
	end
	fov = Ease.lerp(fov, wide, Ease.alpha(3, dt))
	camera.CameraType = Enum.CameraType.Scriptable
	camera.FieldOfView = fov
	camera.CFrame = CFrame.lookAt(at, look) * Shake.update(dt)
	UserInputService.MouseBehavior = Enum.MouseBehavior.Default
end

-- The sub in the air is in sight from where it comes into its way in (further back it would be in the hub's stalls)
local function flyIn(v: Visual, t: number)
	local air = v.Trip.Air
	if not air or v.Said.here then
		return
	end
	v.Said.here = t >= air.SeatAt
	local back = (air.Meet - SubAir.middle(air, math.min(t, air.SeatAt))).Magnitude
	local hidden = Ease.smoothstep(Config.Sub.AirFrom * 0.75, Config.Sub.AirFrom, back)
	for _, p in v.Parts do
		p.LocalTransparencyModifier = hidden
	end
end

-- Our own air hop, each frame until the run: our body from the jump on (by the clock: the server's "Carried" may still be
-- on its way), and the camera all along. True: all of this frame
local function flight(v: Visual, sub: CFrame, t: number, dt: number, root: BasePart, humanoid: Humanoid): boolean
	local air, f = v.Trip.Air, v.Flight
	if not air or not f then
		return false
	end
	if t >= air.RideAt then
		State.SubAloft = false
		if State.Mode == "Carried" then
			State.Leaping = false
		end
		if not v.Held and camKind ~= "sub" and f.Eye and f.Look then
			-- (the run's camera goes on from this one)
			camKind, camAnchor, camPos, camFocus, fov = "sub", sub.Position, f.Eye, f.Look, f.Fov
		end
		v.Held = true
		return State.Mode == "Dock"
	end
	-- (no bubbles or tumble under water: SubController's other trips)
	v.Entry = v.Entry or root.CFrame
	v.Said.scoop, v.Said.seat = true, true
	local mode = State.Mode
	if humanoid.Health <= 0 or (mode ~= "Dock" and mode ~= "Carried") then
		return true
	end
	if not f.From and (t >= air.HopAt or mode == "Carried") then
		local e = v.Trip.Escort
		local planned = SubTrip.escort(v.Trip, t)
		if e and planned then
			v.Carry = planned:ToObjectSpace(root.CFrame * CFrame.new(-e.Saddle))
		end
		AirHop.begin(f, root.CFrame, t)
		DiveController.letGo("Carried")
	end
	escort(v, t)
	AirHop.fish(f, v.Fish, t)
	AirHop.moments(f, t)
	gateKelp(true)
	State.SubAloft = t < air.SplashAt
	if f.From then
		local cf = AirHop.rider(f, t)
		humanoid.PlatformStand = true
		-- (until the server has us carried this keeps the dock's own rules off us: RideController)
		State.Leaping = mode ~= "Carried"
		local was = v.RiderLast or cf.Position
		root.CFrame = cf
		root.AssemblyLinearVelocity = (cf.Position - was) / math.max(dt, 1e-3)
		root.AssemblyAngularVelocity = Vector3.zero
		v.RiderLast = cf.Position
		State.Heading = yawOf(air.Out)
		Feel.rush(0.7 * Ease.smoothstep(air.SeatAt, air.SplashAt, t))
		thin(v, t, dt)
	end
	local view, wide = AirHop.view(f, root.Position, t)
	local camera = workspace.CurrentCamera
	camera.CameraType = Enum.CameraType.Scriptable
	camera.FieldOfView = wide
	-- (before the jump the dive's camera runs the shakes on)
	camera.CFrame = view * Shake.update(if f.From then dt else 0)
	UserInputService.MouseBehavior = Enum.MouseBehavior.Default
	return true
end

-- Our own trip, each frame: the moments (sounds, bursts, banners), where we are, our fish, the camera
local function ours(v: Visual, sub: CFrame, speed: number, t: number, dt: number)
	local trip = v.Trip
	local c = Config.Sub
	local pickupAt, rideAt, arriveAt, dropAt = SubTrip.times(trip)
	local _, root, humanoid = State.character()
	if not root or not humanoid then
		return
	end
	if flight(v, sub, t, dt, root, humanoid) then
		return
	end
	if not v.Entry then
		v.Entry = root.CFrame
		local e = trip.Escort
		local begun = SubTrip.escort(trip, t)
		if e and begun then
			-- (the fish goes on from the very pose the dive left us in: where we sit is where we were. The dive has made
			-- its splash)
			v.Carry = begun:ToObjectSpace(root.CFrame * CFrame.new(-e.Saddle))
		else
			Fx.burst(root.Position + UP * 2, 30, 0, 9)
			Feel.sound("Splash", 0.7, 0.9, 0.9)
		end
	end
	if v.Flight then
		AirHop.fish(v.Flight, v.Fish, t)
		AirHop.moments(v.Flight, t)
	end
	if trip.Escort then
		if not v.Lost and t < rideAt and v.Fish and v.Fish:GetAttribute("SubLeave") ~= nil then
			v.Lost, v.LostAt = root.CFrame, t
		end
		escort(v, t)
	end
	-- the gate's kelp out of the camera's way until the sub is a second into its run, and well away from the dock
	gateKelp(t < rideAt + 1)
	-- the moments
	local hops = trip.Escort ~= nil
	if t >= pickupAt + (if hops then c.EscortHopFrom else 0.3) * trip.Pickup and once(v, "scoop") then
		if hops then
			Fx.burst(root.Position, 18, 0, 6)
			Feel.sound("Swish", 0.7, 1.1, 0.5)
		else
			Fx.burst(root.Position, 40, 0, 10)
			Feel.sound("Splash", 0.8, 1.15, 0.8)
			Shake.play("Land", c.Shake)
		end
	end
	-- (as the tumble lands on the seat: riderAt's 0.82 of the pick-up, and a moment; the hop's EscortHopTo)
	if t >= pickupAt + (if hops then c.EscortHopTo else 0.84) * trip.Pickup and once(v, "seat") then
		Shake.play("LandBig", c.Shake * 0.8)
	end
	if t >= rideAt and once(v, "go") then
		Feel.sound("Whoosh", 0.9, 0.55, 2.5)
		Fx.burst(sub.Position - sub.LookVector * 14, 50, 0, 12)
		-- (no banner here: Hugo, task t1, "let the intro text for submarines begone")
	end
	if t >= arriveAt and once(v, "arrive") then
		-- the arrival land's title, in the land titles' look, handing off from the title still up
		local zone = State.Zones[trip.Land]
		if not LandStrip.arriving(trip.Land, if zone then zone.Name else ("Land " .. trip.Land)) then
			banner("NOW ARRIVING", landName(trip.Land), Color3.fromRGB(120, 230, 255), 2.2)
		end
		Feel.sound("Swish", 0.6, 0.7, 0.6)
	end
	-- the drop: titles go back to their own pace (the arrival land's own title stays held back, LandStrip)
	if t >= dropAt and once(v, "dropped") then
		LandStrip.subEnd(true)
	end
	if t >= arriveAt and t < dropAt then
		if trip.Fish then
			SubPanel.hint(if trip.Escort then "Back on your fish!" else "Here comes your fish!")
		else
			SubPanel.hint("Get ready to hook a fish!")
		end
	end
	-- the run's feel: speed lines and a rumble
	local share = math.clamp(speed / math.max(c.Speed, 1), 0, 1)
	if t >= rideAt and t < arriveAt then
		Feel.rush(share)
	end
	Shake.rumble("Sub", "Speed", if t >= rideAt and t < arriveAt then share * 1.4 else 0)
	-- our fish beside it
	driveFish(v, sub, speed, t)
	-- the fling: as soon as the server says
	if v.Cue == "Fling" then
		if State.Mode == "Carried" and once(v, "fling") then
			-- (off the seat; given up in the middle of the kick, from where we are in its arc)
			local seat = if v.Kicking then root.Position else (sub * SEAT).Position
			root.CFrame = CFrame.lookAt(seat, seat + flat(sub.LookVector))
			root.AssemblyLinearVelocity = flat(sub.LookVector) * speed
			JumpController.fling(yawOf(flat(sub.LookVector)))
		end
		return
	end
	if State.Mode ~= "Carried" then
		return
	end
	humanoid.PlatformStand = true
	-- (welded to our fish and State.Mode not yet Riding, a frame or so: put anywhere now, and given that jump's speed, the
	-- fish went with us. Back to the sub's seat for that frame, both were thrown up to 480 studs: task v1)
	local cf = if v.Seated then nil else riderAt(v, sub, t)
	if cf then
		local was = v.RiderLast or cf.Position
		root.CFrame = cf
		root.AssemblyLinearVelocity = (cf.Position - was) / math.max(dt, 1e-3)
		root.AssemblyAngularVelocity = Vector3.zero
		v.RiderLast = cf.Position
		State.Heading = yawOf(flat(sub.LookVector))
		State.Speed = speed
		-- the kick's end: on the saddle, and the server is told
		if v.Cue == "Kick" and not v.Told and os.clock() - v.CuedAt >= c.Kick then
			v.Told = true
			Shake.play("Land", c.Shake)
			Net.Action:FireServer("SubLand", v.Fish)
		end
	end
	cameraFor(v, sub, speed, root.Position, t, dt)
	thin(v, t, dt)
end

local function step(dt: number)
	local clock = now()
	for player, v in visuals do
		local trip = v.Trip
		local t = clock - trip.Start
		local air = v.Flight
		if air and v ~= mine then
			-- (someone else's air hop: as late as their body reaches us)
			t -= AirHop.lag(air, t)
		end
		local _, _, _, _, endAt = SubTrip.times(trip)
		if t > endAt + 4 then
			remove(player)
		else
			local cf, speed = SubTrip.sub(trip, t)
			place(v, cf, speed, dt)
			flyIn(v, t)
			if v ~= mine then
				escort(v, t)
				if air then
					AirHop.fish(air, v.Fish, t)
					AirHop.moments(air, t)
					AirHop.place(air, cf, t)
				end
			end
			if t > endAt and not v.Faded then
				v.Faded = true
				local label = v.Model:FindFirstChild("Label", true)
				if label and label:IsA("BillboardGui") then
					label.Enabled = false
				end
			end
			if v.Faded then
				local fade = math.clamp((t - endAt) / 3, 0, 1)
				for _, p in v.Parts do
					-- (the blur disc goes from as much as it shows: `place` has just set it)
					p.Transparency = if p.Name == "Blur" then math.max(p.Transparency, fade) else fade
				end
			end
			if v == mine then
				ours(v, cf, speed, t, dt)
			end
		end
	end
end

local function watch(player: Player)
	local function read()
		local json = player:GetAttribute("SubTrip")
		local trip = if type(json) == "string" then SubTrip.decode(json) else nil
		local had = visuals[player]
		if not trip then
			-- cleared: kept on to its end if the drop is done, gone at once if it was given up before it
			if had then
				local _, _, _, dropAt = SubTrip.times(had.Trip)
				if now() - had.Trip.Start < dropAt then
					remove(player)
				end
			end
			return
		end
		if had and had.Trip.Start == trip.Start then
			-- (the trip we have, written again: the fish was given up on the way, so the drop-off is the fling)
			had.Trip.Fish = trip.Fish
			had.Trip.DropTime = trip.DropTime
			return
		end
		remove(player)
		local v = makeVisual(player, trip)
		visuals[player] = v
		if player == State.Player then
			mine = v
			LandStrip.subRun(trip.Land)
			camPos, camFocus = workspace.CurrentCamera.CFrame.Position, nil
			camKind = ""
			camAnchor = Vector3.zero
			fov = workspace.CurrentCamera.FieldOfView
		end
	end
	player:GetAttributeChangedSignal("SubTrip"):Connect(read)
	read()
end

function SubController.Init()
	gui = Instance.new("ScreenGui")
	gui.Name = "SubBanners"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 6
	gui.Parent = State.Player:WaitForChild("PlayerGui")
	SubPanel.init()
	Net.Ride.OnClientEvent:Connect(function(kind: string, a: any, b: any)
		local v = mine
		if kind == "SubFish" and v and typeof(a) == "Instance" and a:IsA("Model") then
			v.Fish = a
			v.FishFrom = if a.PrimaryPart then a.PrimaryPart.Position else nil
			v.FishGot = os.clock()
		elseif kind == "SubDrop" and v then
			v.Kicking = v.Cue == "Kick"
			v.Cue = a
			v.CuedAt = os.clock()
			if a == "Kick" and typeof(b) == "Instance" and b:IsA("Model") then
				v.Fish = b
			end
		end
	end)
end

-- Our ride fish has leapt off the lip: told to the server if there is a sub to come for us (SubService, SubLeap)
local function leapt(leap: { [string]: any })
	local c = Config.Sub
	local me = State.Player
	local equip, dest = me:GetAttribute("SubEquip"), me:GetAttribute("SubDest")
	if
		c.On == 0
		or c.AirHop == 0
		or c.Escort == 0
		or type(equip) ~= "number"
		or equip < 1
		or type(dest) ~= "number"
		or dest < 2
	then
		return
	end
	leap.Start = now()
	Net.Action:FireServer("SubLeap", leap)
end

function SubController.Start()
	DiveController.Began = leapt
	DiveController.Quiet = AirHop.quiet
	State.AirPose = AirHop.riderPose
	State.AfterPose = AirHop.pose
	Players.PlayerAdded:Connect(watch)
	Players.PlayerRemoving:Connect(remove)
	for _, player in Players:GetPlayers() do
		task.spawn(watch, player)
	end
	-- after the ride camera (RideFish, Camera + 1): ours wins while we are carried
	RunService:BindToRenderStep("SubTrip", Enum.RenderPriority.Camera.Value + 3, step)
end

return SubController
