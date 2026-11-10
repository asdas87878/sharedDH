--!strict
-- The jump, fish to fish (Config.Jump): the reference's, read and measured from the user's recordings
-- (docs/reference/ride-a-dino.md), laid over our water. Space throws us off the fish (or up from floating) at once on
-- our side, into a flight in three parts:
--   the launch: up and forward, faster than we rode;
--   the float: at the top, still rising a little, swimming, at about the herd's pace;
--   the drop: sinking, faster and faster.
-- We steer all of it: it turns to where the camera looks (A and D turn the camera), W and S speed it up and slow it. A dashed yellow ring lies flat in the water
-- under us, at the level of the fish below; the fish whose middle is inside it glows yellow, and the flight is drawn
-- over it. We come down on the glowing fish when the drop begins, or at once on a second press: the reel-in, pulled
-- onto its saddle on the reference's curve (a creep, then faster and faster, arriving at top speed), on a line. A second press with no fish glowing grabs the best fish near by (Jump.GrabRange; the fish we
-- left counts too), and with none near starts the drop early. In the drop a fish close by is grabbed without a press. A drop that ends with no fish in the
-- ring has sunk: we tell the server, and it drowns us.
-- With no fish in the ring and no turn held, the flight makes for the nearest fish (Jump.Assist).
-- The ring's dashes and the glow are made once here and reused: nothing is created per jump.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Ease = require(ReplicatedStorage.Shared.Ease)
local Net = require(ReplicatedStorage.Shared.Net)
local Actions = require(script.Parent.Parent.Lib.Actions)
local Fx = require(script.Parent.Parent.Lib.Fx)
local State = require(script.Parent.Parent.Lib.State)
local RideController = require(script.Parent.RideController)

local JumpController = {}

local DASHES = 16
local WHITE = Color3.new(1, 1, 1)

local flying = false
local clock = 0 -- seconds into the flight (a second press with no fish skips it on to the drop)
local position = Vector3.zero
local yaw = 0 -- where the flight is headed: it turns to where the camera looks
local bodyYaw = 0 -- where the body faces: the way it is actually going
local launchSpeed = 0
local baseY, topY = 0, 0 -- where we left, and the top of the float
local left: Model? = nil -- the fish this jump left: not one to land on
local locked: Model? = nil -- the fish in the ring
local lockedAt = 0 -- the flight's clock when it began to glow
local hint: Model? = nil -- with nothing in the ring: the nearest fish ahead, which the flight turns toward

-- the reel-in: from where we were, onto the saddle
local reeling = false
local reelClock = 0
local reelFrom = CFrame.identity -- our turn when it began
local reelOffset = Vector3.zero -- and where we were from the saddle: the gap that closes
local reelTime = 0

-- the line from our hand to the fish while we are pulled in (made once)
local lineFolder: Folder
local lineFrom: Part
local lineTo: Part
local asked = false -- the landing has been sent; we hold on the saddle for the server's word
local askedAt = 0

local ringFolder: Folder
local dashes: { Part } = {}
local ringY = 0
local ringLevel = 0 -- the level the ring wants to lie at
local ringShown = false

local floorParams = RaycastParams.new()
floorParams.FilterType = Enum.RaycastFilterType.Exclude

local glow: Highlight
local glowLandedAt: number? = nil -- os.clock() of the landing, while the glow fades off the fish

local function saddleOf(fish: Model?): CFrame?
	local root = fish and fish.PrimaryPart
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

local function showLine(show: boolean)
	lineFolder.Parent = if show then workspace.CurrentCamera else nil
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
	glow.FillTransparency = 0.25
	glow.OutlineTransparency = 0
	glowLandedAt = nil
end

-- The fish in the ring (the glowing one keeps the glow while it is still under us; else the nearest to the ring's
-- middle), the nearest fish ahead for the flight to turn toward, and the level the ring lies at: the glowing fish's,
-- else the nearest fish's below us, else a little under us
local function pick()
	local j = Config.Jump
	local best: Model? = nil
	local bestFlat = math.huge
	local nearLevel: number? = nil
	local nearFlat = 80
	local ahead: Model? = nil
	local aheadScore = math.huge
	local heading = CFrame.fromOrientation(0, yaw, 0).LookVector
	local folder = workspace:FindFirstChild("Fish")
	if folder then
		for _, model in folder:GetChildren() do
			-- the fish we left counts again once the launch has carried us off it
			local mine = model ~= left or clock >= j.LaunchTime
			if model:IsA("Model") and mine and State.isFreeFish(model) then
				local at = (model.PrimaryPart :: BasePart).Position
				local dy = at.Y - position.Y
				if dy >= -j.ReachDown and dy <= j.ReachUp then
					local dx, dz = at.X - position.X, at.Z - position.Z
					local flat = math.sqrt(dx * dx + dz * dz)
					if model == locked and flat <= j.RingRadius * j.Sticky then
						best = model
						bestFlat = -1
					elseif flat <= j.RingRadius and flat < bestFlat then
						best = model
						bestFlat = flat
					end
					if flat < nearFlat and dy < 0 then
						nearFlat = flat
						nearLevel = at.Y
					end
					-- the fish to make for: the nearest, one ahead of us counting as nearer than one behind
					if flat < j.AssistRange and flat > 0.5 then
						local score = flat - j.AssistAhead * (dx * heading.X + dz * heading.Z) / flat
						if score < aheadScore then
							ahead = model
							aheadScore = score
						end
					end
				end
			end
		end
	end
	if best ~= locked then
		locked = best
		lockedAt = clock
		setGlow(best)
	end
	hint = if locked then nil else ahead
	State.JumpTarget = locked
	local root = locked and locked.PrimaryPart
	ringLevel = if root then root.Position.Y else (nearLevel or position.Y - 12)
end

local function stop()
	flying = false
	reeling = false
	State.Reeling = false
	showLine(false)
	asked = false
	left = nil
	locked = nil
	hint = nil
	State.JumpTarget = nil
	showRing(false)
	if not glowLandedAt then
		setGlow(nil)
	end
end

-- The fish a grab would take, within `range`: the nearest, a fish where the camera looks counting as nearer and the
-- fish we just left as further
local function grabTarget(range: number): Model?
	local j = Config.Jump
	local look = workspace.CurrentCamera.CFrame.LookVector
	local lookX, lookZ = look.X, look.Z
	local length = math.sqrt(lookX * lookX + lookZ * lookZ)
	if length > 0.01 then
		lookX, lookZ = lookX / length, lookZ / length
	end
	local best: Model? = nil
	local bestScore = math.huge
	local folder = workspace:FindFirstChild("Fish")
	if folder then
		for _, model in folder:GetChildren() do
			if model:IsA("Model") and State.isFreeFish(model) then
				local at = (model.PrimaryPart :: BasePart).Position
				local dy = at.Y - position.Y
				local dx, dz = at.X - position.X, at.Z - position.Z
				local flat = math.sqrt(dx * dx + dz * dz)
				if flat <= range and dy >= -j.ReachDown and dy <= j.ReachUp then
					local score = flat
						- j.GrabAim * (dx * lookX + dz * lookZ) / math.max(flat, 1)
						+ (if model == left then j.GrabLeft else 0)
					if score < bestScore then
						best = model
						bestScore = score
					end
				end
			end
		end
	end
	return best
end

local function lock(fish: Model)
	locked = fish
	lockedAt = clock
	hint = nil
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
	reelTime = Config.Jump.ReelTime + away / Config.Jump.GrabSpeed
	reelFrom = root.CFrame
	showRing(false)
	State.FovKick += 5
end

-- Space: into the flight. In the flight: onto the glowing fish at once, or with none, into the drop.
local function request(): boolean
	local j = Config.Jump
	if flying then
		local _, root = State.character()
		if clock >= j.MinFlight and not reeling and not asked and root then
			if locked then
				startReel(root)
			else
				-- nothing in the ring: grab the best fish near by, or with none, start the drop
				local fish = grabTarget(j.GrabRange)
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
	-- the floor check sees the map, not us, the fish or the sheet of water at the surface
	local blockout = workspace:FindFirstChild("ClaudeBlockout")
	floorParams.FilterDescendantsInstances = {
		State.Player.Character :: Instance,
		workspace:FindFirstChild("Fish") :: Instance,
		workspace.CurrentCamera,
		(blockout and blockout:FindFirstChild("Surface")) :: Instance,
	}
	position = root.Position
	baseY = position.Y
	-- the top of the float, kept under the surface
	topY = math.max(baseY, math.min(baseY + j.Apex + j.FloatRise, Config.Oxygen.SurfaceY - 3))
	ringY = baseY - 8
	ringLevel = ringY
	clock = 0
	reeling = false
	asked = false
	locked = nil
	hint = nil
	flying = true
	bodyYaw = yaw
	State.FovKick = 7
	Net.Action:FireServer("Jump")
	State.setMode("Jumping")
	-- the white ring where we left
	Fx.ring(root.CFrame, WHITE)
	return true
end

-- The flight's height at its clock: up through the launch, a little more through the float, then sinking
local function heightAt(t: number): number
	local j = Config.Jump
	local rise = topY - baseY
	local launchShare = j.Apex / (j.Apex + j.FloatRise)
	if t < j.LaunchTime then
		return baseY + rise * launchShare * Ease.outQuad(t / j.LaunchTime)
	end
	local floatT = (t - j.LaunchTime) / j.FloatTime
	if floatT < 1 then
		-- easing up to the top, with a small swimmer's bob
		return baseY + rise * (launchShare + (1 - launchShare) * Ease.outQuad(floatT)) + math.sin(t * 5) * 0.35
	end
	local dropT = math.clamp((t - j.LaunchTime - j.FloatTime) / j.DropTime, 0, 1)
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
			glow.FillTransparency = Ease.lerp(0.25, 1, u)
			glow.OutlineTransparency = u
		end
	end
	if not flying then
		return
	end
	local _, root = State.character()
	if not root then
		stop()
		return
	end
	local j = Config.Jump
	local saddle = saddleOf(locked)

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
		if not saddle then
			-- the fish went from under us: back to the flight, at the drop
			reeling = false
			State.Reeling = false
			showLine(false)
			clock = math.max(clock, j.LaunchTime + j.FloatTime)
		else
			-- Pulled in, as the reference does it: the gap to the saddle closes as time ^ ReelCurve, so it creeps, then
			-- accelerates all the way in and arrives at its fastest. The gap is kept from the saddle as it moves, so
			-- the fish's own travel carries us through the creep: we never hang still in the water.
			reelClock += dt
			local u = math.clamp(reelClock / reelTime, 0, 1)
			local closed = u ^ j.ReelCurve
			local at = saddle.Position + reelOffset * (1 - closed)
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
			-- the view opens as it speeds up; the line runs from the hand to the fish
			State.FovKick = math.max(State.FovKick, j.ReelFov * u ^ 1.5)
			lineFrom.Position = at + body.UpVector * 2.5
			lineTo.Position = saddle.Position
			showLine(u < 0.97)
			root.AssemblyLinearVelocity = (body.Position - was) / math.max(dt, 1 / 240)
			root.AssemblyAngularVelocity = Vector3.zero
			position = body.Position
			State.Speed = root.AssemblyLinearVelocity.Magnitude
			if u >= 1 then
				asked = true
				askedAt = os.clock()
				State.Reeling = false
				showLine(false)
				Net.Action:FireServer("Land", locked)
			end
			return
		end
	end

	clock += dt
	local dropAt = j.LaunchTime + j.FloatTime

	-- steering, and with none held and nothing in the ring, turning toward the nearest fish ahead
	local mv = RideController.moveVector()
	yaw = Ease.lerpAngle(yaw, State.CamYaw, Ease.alpha(j.TurnFollow, dt))
	pick()
	-- fast off the fish, easing to the float's pace
	local cruise = Ease.lerp(launchSpeed, j.AirSpeed, Ease.smoothstep(j.LaunchTime * 0.5, j.LaunchTime + 0.3, clock))
	local speed = cruise * (1 - mv.Z * j.SpeedTrim)
	local velocity = CFrame.fromOrientation(0, yaw, 0).LookVector * speed

	-- with nothing in the ring and no turn held, the flight makes for the nearest fish: its speed, plus closing the gap
	-- (not in the launch, which is ours)
	local hintRoot = hint and hint.PrimaryPart
	local hands = 1 - math.min(1, math.abs(mv.X) * 2)
	if j.Assist and hintRoot and hands > 0 then
		local to = hintRoot.Position - position
		local flat = Vector3.new(to.X, 0, to.Z)
		local fishVelocity = hintRoot.AssemblyLinearVelocity
		local close = if flat.Magnitude > 1 then flat.Unit * j.AssistClose else Vector3.zero
		local want = Vector3.new(fishVelocity.X + close.X, 0, fishVelocity.Z + close.Z)
		local pull = j.AssistPull * hands * Ease.smoothstep(j.LaunchTime * 0.4, j.LaunchTime, clock)
		velocity = velocity:Lerp(want, pull)
	end

	local fishRoot = locked and locked.PrimaryPart
	if fishRoot and j.Magnet > 0 then
		-- drawn over the glowing fish (its own speed, plus closing the gap): at once enough to stay with it, and more
		-- the longer it glows, leaving a little to the steering
		local to = fishRoot.Position - position
		local fishVelocity = fishRoot.AssemblyLinearVelocity
		local over = Vector3.new(fishVelocity.X + to.X * j.Magnet, 0, fishVelocity.Z + to.Z * j.Magnet)
		velocity = velocity:Lerp(over, Ease.lerp(j.MagnetHold, j.MagnetFull, Ease.smoothstep(0, 1, clock - lockedAt)))
	end

	local y = heightAt(clock)
	local x, z = position.X + velocity.X * dt, position.Z + velocity.Z * dt
	-- never into the sea floor or a rock: the flight skims over what is under it
	local ground = workspace:Raycast(Vector3.new(x, y + 3, z), Vector3.new(0, -3 - j.FloorClearance, 0), floorParams)
	if ground then
		y = math.max(y, ground.Position.Y + j.FloorClearance)
	end
	position = Vector3.new(x, y, z)

	-- upright off the fish, tipped forward to swim through the float, head first in the drop
	local tip = math.rad(55) * Ease.smoothstep(j.LaunchTime * 0.4, j.LaunchTime, clock)
		+ math.rad(30) * Ease.smoothstep(dropAt, dropAt + 0.4, clock)
	-- facing the way we are going (the pull toward a fish bends that away from where the camera looks)
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
		-- the drop: a fish near by is grabbed without a press
		local fish = grabTarget(j.AutoGrab)
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

	-- the line: two unseen parts, a beam between them
	lineFolder = Instance.new("Folder")
	lineFolder.Name = "JumpLine"
	local function linePart(): (Part, Attachment)
		local part = Instance.new("Part")
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.Transparency = 1
		part.Size = Vector3.new(0.2, 0.2, 0.2)
		part.Parent = lineFolder
		local attachment = Instance.new("Attachment")
		attachment.Parent = part
		return part, attachment
	end
	local fromAttachment, toAttachment
	lineFrom, fromAttachment = linePart()
	lineTo, toAttachment = linePart()
	local beam = Instance.new("Beam")
	beam.Attachment0 = fromAttachment
	beam.Attachment1 = toAttachment
	beam.Width0 = 0.35
	beam.Width1 = 0.2
	beam.FaceCamera = true
	beam.LightEmission = 0.5
	beam.Color = ColorSequence.new(Config.Jump.Glow)
	beam.Transparency = NumberSequence.new(0.1)
	beam.Parent = lineFolder

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
		local character = player.Character
		if kind == "Jump" and character then
			Fx.trail(character, Config.Jump.LaunchTime + Config.Jump.FloatTime, Config.Jump.Glow)
		elseif kind == "Land" and typeof(fish) == "Instance" then
			local tier = Config.Tiers[fish:GetAttribute("Tier") :: string]
			Fx.landing(character, fish, State.Squash, if tier then tier.Colour else WHITE)
			if player == State.Player then
				-- the small camera kick on our own landing
				State.shake(Config.Burst.Kick, 0.3)
				State.FovKick += 3
			end
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
