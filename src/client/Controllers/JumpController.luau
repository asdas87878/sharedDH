--!strict
-- The jump, fish to fish (Config.Jump): the reference's, read and measured from the user's recordings
-- (docs/reference/ride-a-dino.md), laid over our water. Space throws us off the fish (or up from floating) at once on
-- our side; the server is told and follows. The flight, placed by CFrame every frame:
--   the pop: up, above the fish in front of us, and forward faster than we rode;
--   the glide: flat at the top, at about the herd's pace;
--   the drop: sinking, faster and faster (only with no fish to land on).
-- We are going one way, and A and D steer that (the camera turns by as much; a drag only looks round). W and S speed the
-- flight up and slow it. The fish we are making for is the nearest one in front; it glows, and with no turn held the
-- flight makes for it. A dashed yellow ring lies flat in the water under us.
-- We come down on that fish when the glide ends, or at once on a second press: the pull-in, onto its saddle on the
-- reference's curve (a creep, then faster and faster, arriving at top speed), the view narrowing and yellow dots left
-- behind us; at the landing the view snaps wide and the camera is jolted. With no fish in front it takes the nearest
-- any way round (Jump.AutoGrab), and with none of those the drop ends in a miss: we tell the server.
-- The flight doesn't collide with anything: Lib/Course keeps it out of the floor, the walls and the lane's edge.
-- The ring's dashes, the dots and the glow are made once here and reused: nothing is created per jump.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Ease = require(ReplicatedStorage.Shared.Ease)
local Net = require(ReplicatedStorage.Shared.Net)
local Actions = require(script.Parent.Parent.Lib.Actions)
local Course = require(script.Parent.Parent.Lib.Course)
local Fx = require(script.Parent.Parent.Lib.Fx)
local State = require(script.Parent.Parent.Lib.State)
local RideController = require(script.Parent.RideController)

local JumpController = {}

local DASHES = 16
local WHITE = Color3.new(1, 1, 1)

local flying = false
local clock = 0 -- seconds into the flight (a second press with no fish skips it on to the drop)
local position = Vector3.zero
local yaw = 0 -- where the flight is headed: A and D turn it
local bodyYaw = 0 -- where the body faces: the way it is actually going
local launchSpeed = 0
local baseY, topY = 0, 0 -- where we left, and the top of the float
local left: Model? = nil -- the fish this jump left: not one to land on
local locked: Model? = nil -- the fish we are making for: the nearest in front of us; it glows
local targetFlat = math.huge -- how far it is, across the water
local overAt: number? = nil -- the flight's clock when we came over it (inside the ring)
local highY = -math.huge -- how high the fish in front of us swim: the jump rises above them

-- the reel-in: from where we were, onto the saddle
local reeling = false
local reelClock = 0
local reelFrom = CFrame.identity -- our turn when it began
local reelOffset = Vector3.zero -- and where we were from the saddle: the gap that closes
local reelTime = 0

-- the dots left behind us through the pull-in, as the reference leaves them (made once, reused)
local TRAIL_DOTS = 18
local TRAIL_EVERY = 0.025
local TRAIL_LIFE = 0.4
local trailFolder: Folder
local trailDots: { Part } = {}
local trailBorn: { number } = {}
local trailNext = 0
local trailAt = 0
local trailLive = false
local asked = false -- the landing has been sent; we hold on the saddle for the server's word
local askedAt = 0

local ringFolder: Folder
local dashes: { Part } = {}
local ringY = 0
local ringLevel = 0 -- the level the ring wants to lie at
local ringShown = false

local glow: Highlight
local glowLandedAt: number? = nil -- os.clock() of the landing, while the glow fades off the fish

-- Where we sit on a fish: nil once it has gone (put away by the server, or destroyed)
local function saddleOf(fish: Model?): CFrame?
	local root = fish and fish.Parent and fish.PrimaryPart
	local saddle = root and root:FindFirstChild("Saddle")
	if saddle and saddle:IsA("Attachment") then
		return saddle.WorldCFrame
	end
	return nil
end

local function yawOf(look: Vector3): number
	return math.atan2(-look.X, -look.Z)
end

local function showRing(show: boolean)
	if show ~= ringShown then
		ringShown = show
		ringFolder.Parent = if show then workspace.CurrentCamera else nil
	end
end

local function dropDot(at: Vector3)
	local t = os.clock()
	if t - trailAt < TRAIL_EVERY then
		return
	end
	trailAt = t
	trailNext = trailNext % TRAIL_DOTS + 1
	trailDots[trailNext].Position = at
	trailBorn[trailNext] = t
	if not trailLive then
		trailLive = true
		trailFolder.Parent = workspace.CurrentCamera
	end
end

-- the dots shrink and fade; with none left the folder is put away
local function fadeDots()
	if not trailLive then
		return
	end
	local t = os.clock()
	local any = false
	for i, dot in trailDots do
		local age = (t - trailBorn[i]) / TRAIL_LIFE
		if age < 1 then
			any = true
			dot.Transparency = 0.1 + 0.9 * age
			local size = 1.1 * (1 - 0.6 * age)
			dot.Size = Vector3.new(size, size, size)
		else
			dot.Transparency = 1
		end
	end
	if not any then
		trailLive = false
		trailFolder.Parent = nil
	end
end

local function placeRing(centre: Vector3)
	local radius = Config.Jump.RingRadius
	for i, dash in dashes do
		local angle = (i - 1) / DASHES * math.pi * 2
		local at = centre + Vector3.new(math.cos(angle), 0, math.sin(angle)) * radius
		-- each dash lies along the circle
		dash.CFrame = CFrame.new(at) * CFrame.Angles(0, -angle + math.pi / 2, 0)
	end
end

local function setGlow(fish: Model?)
	if glow.Adornee ~= fish then
		glow.Adornee = fish
	end
	glow.Enabled = fish ~= nil
	glow.FillColor = Config.Jump.Glow
	glow.FillTransparency = 0.25
	glow.OutlineTransparency = 0
	glowLandedAt = nil
end

-- The fish we are making for: the nearest one in front of us (within Jump.AheadCone of where the flight is headed, or
-- right under us) and in reach, never the fish we just left. It glows from the moment it is picked, and keeps the glow
-- until it leaves the reach or falls well behind, or another fish in front is clearly nearer. Also found: how high the
-- fish in front swim (the jump rises above them), and the level the ring lies at.
local function pick()
	local j = Config.Jump
	local best: Model? = nil
	local bestFlat = math.huge
	local lockedFlat: number? = nil
	local nearLevel: number? = nil
	local nearFlat = 80
	local high = -math.huge
	local heading = CFrame.fromOrientation(0, yaw, 0).LookVector
	local cone = math.cos(math.rad(j.AheadCone / 2))
	local keep = math.cos(math.rad(math.min(j.AheadCone / 2 + 25, 175)))
	local folder = workspace:FindFirstChild("Fish")
	if folder then
		for _, model in folder:GetChildren() do
			if model:IsA("Model") and model ~= left and State.isFreeFish(model) then
				local at = (model.PrimaryPart :: BasePart).Position
				local dy = at.Y - position.Y
				if dy >= -j.ReachDown and dy <= j.ReachUp then
					local dx, dz = at.X - position.X, at.Z - position.Z
					local flat = math.sqrt(dx * dx + dz * dz)
					local ahead = if flat > 0.5 then (dx * heading.X + dz * heading.Z) / flat else 1
					local under = flat <= j.RingRadius * 0.5
					if flat <= j.GrabRange then
						if ahead >= cone or under then
							high = math.max(high, at.Y)
							if flat < bestFlat then
								best = model
								bestFlat = flat
							end
						end
						if model == locked and (ahead >= keep or flat <= j.RingRadius) then
							lockedFlat = flat
						end
					end
					if flat < nearFlat and dy < 0 then
						nearFlat = flat
						nearLevel = at.Y
					end
				end
			end
		end
	end
	if locked and lockedFlat and (not best or bestFlat > lockedFlat * j.TargetKeep) then
		best = locked
		bestFlat = lockedFlat
	end
	if best ~= locked then
		locked = best
		overAt = nil
		setGlow(best)
	end
	targetFlat = if locked then bestFlat else math.huge
	highY = high
	State.JumpTarget = locked
	local root = locked and locked.PrimaryPart
	ringLevel = if root and targetFlat <= j.RingRadius then root.Position.Y else (nearLevel or position.Y - 12)
end

local function stop()
	flying = false
	reeling = false
	State.Reeling = false
	asked = false
	left = nil
	locked = nil
	State.JumpTarget = nil
	showRing(false)
	if not glowLandedAt then
		setGlow(nil)
	end
end

-- With no fish in front: the nearest fish any way round within `range`, and only with none of those the fish we just left
local function fallback(range: number): Model?
	local j = Config.Jump
	local best: Model? = nil
	local bestFlat = range
	local old: Model? = nil
	local folder = workspace:FindFirstChild("Fish")
	if folder then
		for _, model in folder:GetChildren() do
			if model:IsA("Model") and State.isFreeFish(model) then
				local at = (model.PrimaryPart :: BasePart).Position
				local dy = at.Y - position.Y
				local dx, dz = at.X - position.X, at.Z - position.Z
				local flat = math.sqrt(dx * dx + dz * dz)
				if flat <= range and dy >= -j.ReachDown and dy <= j.ReachUp then
					if model == left then
						old = model
					elseif flat < bestFlat then
						best = model
						bestFlat = flat
					end
				end
			end
		end
	end
	return best or old
end

local function lock(fish: Model)
	locked = fish
	overAt = nil
	State.JumpTarget = fish
	setGlow(fish)
end

local function startReel(root: BasePart)
	local saddle = saddleOf(locked)
	local gap = if saddle then root.Position - saddle.Position else Vector3.zero
	local away = gap.Magnitude
	reeling = true
	State.Reeling = true
	reelOffset = gap
	reelClock = 0
	local j = Config.Jump
	reelTime = math.max(0.05, math.min(j.ReelTime + away / math.max(j.GrabSpeed, 1), j.ReelMax))
	reelFrom = root.CFrame
	showRing(false)
end

-- Space: into the flight. In the flight: onto the fish we are making for at once, or with none, into the drop.
local function request(): boolean
	local j = Config.Jump
	if flying then
		local _, root = State.character()
		if clock >= j.MinFlight and not reeling and not asked and root then
			if locked then
				startReel(root)
			else
				-- no fish in front: the nearest any way round, or with none, start the drop
				local fish = fallback(j.AutoGrab)
				if fish then
					lock(fish)
					startReel(root)
				else
					clock = math.max(clock, j.LaunchTime + j.FloatTime)
				end
			end
		end
		return true
	end
	local mode = State.Mode
	local _, root = State.character()
	if (mode ~= "Riding" and mode ~= "Free") or not root or os.clock() < State.JumpReadyAt then
		return false
	end
	local fish = State.Fish
	local fishRoot = fish and fish.PrimaryPart
	if mode == "Riding" and fishRoot then
		yaw = yawOf(fishRoot.CFrame.LookVector)
		launchSpeed = fishRoot.AssemblyLinearVelocity.Magnitude * j.Launch
		left = fish
		RideController.leave()
	else
		yaw = yawOf(workspace.CurrentCamera.CFrame.LookVector)
		launchSpeed = j.FreeLaunch
		left = nil
	end
	launchSpeed = math.max(launchSpeed, j.AirSpeed)
	Course.begin()
	position = root.Position
	baseY = position.Y
	-- the top of the float, kept under the surface
	topY = math.max(baseY, math.min(baseY + j.Apex + j.FloatRise, Config.Oxygen.SurfaceY - j.Ceiling))
	ringY = baseY - 8
	ringLevel = ringY
	clock = 0
	reeling = false
	asked = false
	locked = nil
	overAt = nil
	targetFlat = math.huge
	highY = -math.huge
	flying = true
	bodyYaw = yaw
	Net.Action:FireServer("Jump")
	State.setMode("Jumping")
	return true
end

-- The flight's height at its clock: up through the pop, the last of the rise through the glide, then sinking
local function heightAt(t: number): number
	local j = Config.Jump
	local rise = topY - baseY
	local whole = j.Apex + j.FloatRise
	local popShare = if whole > 0 then j.Apex / whole else 1
	if t < j.LaunchTime then
		return baseY + rise * popShare * Ease.outQuad(t / j.LaunchTime)
	end
	local glide = t - j.LaunchTime
	if glide < j.FloatTime then
		return baseY + rise * (popShare + (1 - popShare) * Ease.outQuad(glide / j.FloatTime))
	end
	local dropT = math.clamp((glide - j.FloatTime) / math.max(j.DropTime, 0.01), 0, 1)
	return topY - (rise + j.Drop) * dropT * dropT
end

local function step(dt: number)
	-- the glow leaving the fish we landed on
	local landedAt = glowLandedAt
	if landedAt then
		local u = (os.clock() - landedAt) / Config.Jump.GlowFade
		if u >= 1 then
			setGlow(nil)
		else
			-- a white flash at the landing, through yellow, and off
			glow.FillColor = WHITE:Lerp(Config.Jump.Glow, math.min(1, u * 3))
			glow.FillTransparency = Ease.lerp(0.1, 1, u)
			glow.OutlineTransparency = u
		end
	end
	fadeDots()
	if not flying then
		return
	end
	local _, root = State.character()
	if not root then
		stop()
		if State.Mode == "Jumping" then
			State.setMode("Free")
		end
		return
	end
	-- a hitch is flown as a short frame: one long step could carry us through what the checks would have stopped
	dt = math.min(dt, 0.05)
	local j = Config.Jump
	local saddle: CFrame? = saddleOf(locked)

	if asked then
		-- holding on the saddle until the server mounts us (or doesn't answer)
		if saddle then
			root.CFrame = saddle
			local fishRoot = (locked :: Model).PrimaryPart
			root.AssemblyLinearVelocity = if fishRoot then fishRoot.AssemblyLinearVelocity else Vector3.zero
			root.AssemblyAngularVelocity = Vector3.zero
		end
		if os.clock() - askedAt > 1 or not saddle then
			stop()
			State.setMode("Free")
		end
		return
	end

	if reeling then
		local taken = locked and locked:GetAttribute("Rider") ~= 0
		if not saddle or taken then
			-- the fish went from under us, or someone else got on it: back to the flight, at the drop
			reeling = false
			State.Reeling = false
			State.FovPunch = 0
			clock = math.max(clock, j.LaunchTime + j.FloatTime)
		else
			-- Pulled in, as the reference does it: the gap to the saddle closes as time ^ ReelCurve, so it creeps, then
			-- accelerates all the way in and arrives at its fastest. The gap is kept from the saddle as it moves, so
			-- the fish's own travel carries us through the creep: we never hang still in the water.
			reelClock += dt
			local u = math.clamp(reelClock / reelTime, 0, 1)
			local closed = u ^ j.ReelCurve
			-- the height closes later than the rest (ReelSwoop): we hold our height, then swoop down onto it
			local sunk = u ^ (j.ReelCurve + j.ReelSwoop)
			local at = saddle.Position
				+ Vector3.new(reelOffset.X * (1 - closed), reelOffset.Y * (1 - sunk), reelOffset.Z * (1 - closed))
			-- head first along the line, turning to sit as we arrive
			local toSaddle = saddle.Position - at
			local headFirst = if toSaddle.Magnitude > 0.5
				then CFrame.lookAt(at, at + toSaddle) * CFrame.Angles(-math.rad(80), 0, 0)
				else CFrame.new(at) * saddle.Rotation
			local turned = (CFrame.new(at) * reelFrom.Rotation):Lerp(headFirst, Ease.smoothstep(0, 0.25, u))
			local body = turned:Lerp(CFrame.new(at) * saddle.Rotation, Ease.smoothstep(0.8, 1, u))
			-- our speed from where we put ourselves last frame (the physics moves the root a little in between)
			local was = position
			root.CFrame = body
			-- the view narrows as it speeds up (the reference's zoom in), and dots are left behind us
			State.FovPunch = j.ReelFov * u ^ 1.5
			dropDot(at)
			root.AssemblyLinearVelocity = (body.Position - was) / math.max(dt, 1 / 240)
			root.AssemblyAngularVelocity = Vector3.zero
			position = body.Position
			State.Speed = root.AssemblyLinearVelocity.Magnitude
			if u >= 1 then
				asked = true
				askedAt = os.clock()
				State.Reeling = false
				-- the landing, at once on our side: the view snaps wider and settles, the camera is knocked down and
				-- springs back
				State.FovPunch = j.LandFov
				State.KickVelocity = j.LandKick * 2 * math.pi * j.LandKickRate
				Net.Action:FireServer("Land", locked)
			end
			return
		end
	end

	clock += dt
	local dropAt = j.LaunchTime + j.FloatTime

	-- we are going one way and A and D steer that (the camera turns by as much: RideController); the fish we are making
	-- for is the nearest in front of where we are headed
	local mv = RideController.moveVector()
	if j.CameraSteer > 0 then
		yaw = Ease.lerpAngle(yaw, State.CamYaw, Ease.alpha(j.TurnFollow, dt))
	else
		yaw -= mv.X * math.rad(j.YawRate) * dt
	end
	pick()
	saddle = saddleOf(locked)
	-- the jump rises above the fish in front of us (and above where we left), kept under the surface
	local over = math.max(baseY, highY, if saddle then saddle.Position.Y else -math.huge)
	local top = math.max(baseY, math.min(over + j.Apex + j.FloatRise, Config.Oxygen.SurfaceY - j.Ceiling))
	if top > topY then
		topY = Ease.lerp(topY, top, Ease.alpha(6, dt))
	end
	-- fast off the fish, easing to the float's pace
	local cruise = Ease.lerp(launchSpeed, j.AirSpeed, Ease.smoothstep(j.BoostTime * 0.5, j.BoostTime + 0.3, clock))
	local speed = cruise * (1 - mv.Z * j.SpeedTrim)
	local velocity = CFrame.fromOrientation(0, yaw, 0).LookVector * speed

	local fishRoot = locked and locked.PrimaryPart
	local hands = 1 - math.min(1, math.abs(mv.X) * 2)
	if fishRoot and targetFlat <= j.RingRadius * j.Sticky and j.Magnet > 0 then
		-- over it: held there (its own speed, plus closing the gap), more the longer we are, leaving a little to the
		-- steering
		overAt = overAt or clock
		local to = fishRoot.Position - position
		local fishVelocity = fishRoot.AssemblyLinearVelocity
		local hold = Vector3.new(fishVelocity.X + to.X * j.Magnet, 0, fishVelocity.Z + to.Z * j.Magnet)
		velocity = velocity:Lerp(
			hold,
			Ease.lerp(j.MagnetHold, j.MagnetFull, Ease.smoothstep(0, 1, clock - (overAt :: number)))
		)
	elseif fishRoot and j.Assist and hands > 0 then
		-- not over it yet, and no turn held: the flight makes for it, at its speed plus closing the gap (not in the
		-- launch, which is ours)
		overAt = nil
		local to = fishRoot.Position - position
		local flat = Vector3.new(to.X, 0, to.Z)
		local fishVelocity = fishRoot.AssemblyLinearVelocity
		local close = if flat.Magnitude > 1 then flat.Unit * j.AssistClose else Vector3.zero
		local want = Vector3.new(fishVelocity.X + close.X, 0, fishVelocity.Z + close.Z)
		local pull = j.AssistPull * hands * Ease.smoothstep(j.BoostTime * 0.4, j.BoostTime, clock)
		velocity = velocity:Lerp(want, pull)
	end

	-- never into the sea floor, a rock or a bank, nor out of the lane: stopped at walls, skimming over what is under it
	local want = Vector3.new(position.X + velocity.X * dt, heightAt(clock), position.Z + velocity.Z * dt)
	position = Course.clearMove(position, want, j.FloorClearance)

	-- upright off the fish for a moment, then lying flat, face down, through the glide (as the reference's rider
	-- does), and head first in the drop
	local tip = math.rad(78) * Ease.smoothstep(j.LaunchTime * 0.2, j.LaunchTime * 1.2, clock)
		+ math.rad(12) * Ease.smoothstep(dropAt, dropAt + 0.4, clock)
	-- facing the way we are going (the pull toward a fish bends that away from where we are headed)
	if velocity.Magnitude > 1 then
		bodyYaw = Ease.lerpAngle(bodyYaw, yawOf(velocity), Ease.alpha(8, dt))
	end
	root.CFrame = CFrame.new(position) * CFrame.fromOrientation(0, bodyYaw, 0) * CFrame.Angles(-tip, 0, 0)
	root.AssemblyLinearVelocity = velocity
	root.AssemblyAngularVelocity = Vector3.zero
	State.Speed = speed

	-- the ring, flat in the water under us
	ringY = Ease.lerp(ringY, math.min(ringLevel, position.Y - 2), Ease.alpha(10, dt))
	placeRing(Vector3.new(position.X, ringY, position.Z))
	showRing(true)

	if clock >= dropAt and not locked then
		-- the glide is over with no fish in front: the nearest any way round is grabbed without a press
		local fish = fallback(j.AutoGrab)
		if fish then
			lock(fish)
		end
	end
	if clock >= dropAt and locked and saddleOf(locked) then
		-- the drop, with a fish under us or near by: onto it
		startReel(root)
	elseif clock >= dropAt + j.DropTime then
		-- sunk
		Net.Action:FireServer("Miss")
		stop()
		State.setMode("Free") -- for the moment until the server's word (the drown)
	end
end

function JumpController.Init()
	Actions.jump = request

	ringFolder = Instance.new("Folder")
	ringFolder.Name = "JumpRing"
	local arc = 2 * math.pi * Config.Jump.RingRadius / DASHES
	for _ = 1, DASHES do
		local dash = Instance.new("Part")
		dash.Anchored = true
		dash.CanCollide = false
		dash.CanQuery = false
		dash.CanTouch = false
		dash.CastShadow = false
		dash.Material = Enum.Material.Neon
		dash.Color = Config.Jump.Glow
		dash.Size = Vector3.new(arc * 0.6, 0.3, 0.8)
		dash.Parent = ringFolder
		table.insert(dashes, dash)
	end

	trailFolder = Instance.new("Folder")
	trailFolder.Name = "JumpTrail"
	for i = 1, TRAIL_DOTS do
		local dot = Instance.new("Part")
		dot.Shape = Enum.PartType.Ball
		dot.Anchored = true
		dot.CanCollide = false
		dot.CanQuery = false
		dot.CanTouch = false
		dot.CastShadow = false
		dot.Material = Enum.Material.Neon
		dot.Color = Config.Jump.Glow
		dot.Transparency = 1
		dot.Size = Vector3.new(1.1, 1.1, 1.1)
		dot.Parent = trailFolder
		trailDots[i] = dot
		trailBorn[i] = -math.huge
	end

	glow = Instance.new("Highlight")
	glow.Name = "JumpGlow"
	glow.FillColor = Config.Jump.Glow
	glow.OutlineColor = Color3.fromRGB(255, 246, 170)
	glow.DepthMode = Enum.HighlightDepthMode.Occluded
	glow.Enabled = false
	glow.Parent = workspace.CurrentCamera

	Net.Ride.OnClientEvent:Connect(function(kind: string, a: any)
		if kind == "Mounted" then
			if flying then
				local fish = locked
				stop()
				if fish and fish == a then
					-- the glow stays on the fish we landed on and fades off it
					glow.Adornee = fish
					glow.Enabled = true
					glowLandedAt = os.clock()
				end
			end
			State.JumpReadyAt = os.clock() + Config.Jump.Cooldown
		elseif kind == "Denied" and a == "Jump" then
			if flying then
				stop()
				if not RideController.rejoin() then
					State.setMode("Free")
				end
			end
		elseif kind == "Dismounted" and flying and a == "Lost" then
			stop()
		end
	end)
	Net.Fx.OnClientEvent:Connect(function(kind: string, player: Player, fish: Model)
		if typeof(player) ~= "Instance" or not player:IsA("Player") then
			return
		end
		if kind == "Land" and typeof(fish) == "Instance" and fish:IsA("Model") then
			-- (our own camera's snap and jolt were played already, as the pull-in ended)
			local tier = Config.Tiers[fish:GetAttribute("Tier") :: string]
			Fx.landing(player.Character, fish, State.Squash, if tier then tier.Colour else WHITE)
		end
	end)
	State.ModeChanged.Event:Connect(function(mode: string)
		if flying and mode ~= "Jumping" and mode ~= "Riding" then
			stop()
		end
	end)
end

function JumpController.Start()
	RunService:BindToRenderStep("RideJump", Enum.RenderPriority.Camera.Value - 5, step)
end

return JumpController
