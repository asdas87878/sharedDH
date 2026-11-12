--!strict
-- Riding on the client: steering the fish we own (the server hands us its network ownership on mount), the speed-up,
-- coasting the fish we just left (it stays ours for Switch.HandBack seconds, so it swims off without a hitch), floating
-- while off a fish, and the camera for everything underwater.
-- Steering: we always go forward. A and D (or the stick's sideways) turn the way we go directly, and the view by as
-- much; a look (a drag, a stick, the mouse in the hop) is followed by the way we go (Ride.CameraSteer). The same on a
-- fish, in the hop off it (JumpController) and floating: RideController.steer. W and S do nothing; a ridden fish
-- follows the lane down at the herd's height above the floor by itself.
-- The camera follows our own character (so leaving a fish and landing on one never cut), behind the way we are going.
-- Everything it does goes through a critically damped spring (Lib/Spring): where it looks from, its turn and tilt, its
-- distance, its field of view; so riding, the hop, the pull-in and the landing run into each other with no snap. The
-- player's look wins (Hugo, 2026-11-11): a right mouse drag, a touch drag or a gamepad's right stick looks round, in
-- the hop the mouse aims freely (that look is the lock-on's aim, Lib/Lock), and the view stays where it is put: nothing
-- pulls it behind the fish after a landing or tilts it in the hop. Left alone for Camera.LookBack seconds it drifts
-- back behind us, gently (Camera.AutoRecentre). The field of view widens with speed; the pull-in's zoom, the landing's
-- snap, its jolt and its shake (RideController.shake) sit on top, and the drowning's shot is eased to.
-- Fish don't collide with the map: Lib/Course keeps the one we ride out of the floor, the walls and the air. Running
-- into something solid is the server's call ("Crashed": Config.Crash, Config.Props): we lose speed for a moment.
-- The landing's slow-down (Config.Ride.Startle...; Hugo, 2026-11-12): a fish we LAND on slows for a
-- moment, never stopping, then eases back to its speed. It is this fish's speed curve, nothing else: no force is
-- added, and the limits on its force and torque (Lib/FishModel) are what they were.
-- Angry mode (Config.Angry; Hugo, 2026-11-12): while the server says the fish under us is angry (its "Angry"
-- attribute: the meter in its red part, or a fish too strong), its speed is also times its angry style's curve
-- (Shared/AngryStyles: a steady drag, a stutter, a surge and stall, ...), eased in and out. Only the speed: A and D,
-- the look and the hop are what they were. The style's stand-in motion is one marked block in `drive`.
-- Every fish has its own speed (Config.speedOf: its species' own number in Config.FishStats, and its variant).
-- The camera stays underwater once we have dived (Config.Camera.Submerge...), until the dock or a respawn.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local AngryStyles = require(ReplicatedStorage.Shared.AngryStyles)
local Config = require(ReplicatedStorage.Shared.Config)
local Ease = require(ReplicatedStorage.Shared.Ease)
local Net = require(ReplicatedStorage.Shared.Net)
local Zones = require(ReplicatedStorage.Shared.Zones)
local Course = require(script.Parent.Parent.Lib.Course)
local Feel = require(script.Parent.Parent.Lib.Feel)
local Spring = require(script.Parent.Parent.Lib.Spring)
local State = require(script.Parent.Parent.Lib.State)

local RideController = {}

local controls: any = nil
local camera = workspace.CurrentCamera

-- riding
local yaw, pitch, roll = 0, 0, 0
local turnNow = 0 -- how fast A and D are turning us now, radians a second (eased in and out)
local turned = 0 -- and by how much this frame: the camera turns by as much
local steerRate = 0 -- how fast the way we are going is really turning, radians a second (eased): the bank follows it
local lastMode = "Dock"
local startSpeed = 0
local rideType: Config.FishType? = nil
local startled = false -- this ride began with a landing: the fish slows for a moment (Ride.Startle)
local bolted = false -- and it is picking its speed up again (its kick to the view is given once)
local angry = false -- the server says the fish under us is angry (Config.Angry),
local angryAt = 0 -- since this os.clock(),
local angryIn = 0 -- and how far its slow-down is in, 0 to 1 (eased in and out)
local crashAt = -math.huge -- os.clock() of the last crash or smashed prop,
local crashSlow = 1 -- and the share of our speed it left us (it comes back over Crash.Recover)

-- the fish we just left, coasting on its heading to idle until the server takes it back
type Coast = { Fish: Model, At: number, Speed: number, Look: Vector3, Idle: number }
local coasting: Coast? = nil

-- the sandbox's reset is seating us: the fish we hold ourselves on until the server joins us to it, and since when
local seating: Model? = nil
local seatingAt = 0
local seatingTold = false
-- seconds we sit on the saddle ourselves before telling the server: long enough for the server to have seen us arrive
-- there (at 0.15 it had not, and refused 14 seats of 16; at 0.6 none)
local SEAT_HOLD = 0.4

-- floating
local floatVelocity: LinearVelocity? = nil
local floatTurn: AlignOrientation? = nil

-- the fish a jump has just left, and its weld (switched off here at once; the server takes it away a moment later)
local leftFish: Model? = nil
local leftWeld: Weld? = nil

-- camera: what it is asked for (camYaw, camPitch, the zoom), and what it shows, each on a spring
local camYaw, camPitch = 0, math.rad(Config.Camera.RestPitch)
local shownYaw, shownPitch = 0, math.rad(Config.Camera.RestPitch)
local yawSpeed, pitchSpeed = 0, 0
local camPosition: Vector3? = nil
local camFocus: Vector3? = nil
local focusSpeed = Vector3.zero
local zoom = Config.Camera.Distance
local zoomScale, zoomSpeed = 1, 0 -- the hop sits a little further back
local reach, reachSpeed = 1, 0 -- how much of its distance the camera has, with a wall behind it
local fovEased, fovSpeed = Config.Camera.Fov, 0 -- the field of view before the punch
local kickAt, kickSpeed = 0, 0 -- the landing's jolt: the camera's height off true, on a spring
local shakeAt = -math.huge -- os.clock() of the landing's shake,
local shakeSize = 0 -- how far it throws the camera, studs,
local shakeSeed = 0 -- and which way: a new pattern each time
local airAt = -math.huge -- os.clock() the hop began
local lookedAt = -math.huge -- os.clock() the player last looked round themselves
local rightHeld = false
local stick = Vector2.zero -- a gamepad's right stick
local wasScripted = false
local cameraParams = RaycastParams.new() -- for keeping the camera out of the floor and walls
cameraParams.FilterType = Enum.RaycastFilterType.Exclude
cameraParams.RespectCanCollide = true
local cameraFor: Model? = nil -- the character those rays skip
local deathBlend = 0 -- 0 to 1, how far the camera has turned to look at a death shot's focus
local submerged = false -- we have dived: the camera stays under the surface until the dock or a respawn
local ceiling = 0 -- the highest the camera may be now (it comes down to the surface's line from where the camera was)

-- The move stick or keys: X is right, Z is back (W is -Z)
function RideController.moveVector(): Vector3
	if UserInputService:GetFocusedTextBox() then
		return Vector3.zero
	end
	-- Read the lateral keys before PlayerModule can normalize W+A into a weaker turn.
	if UserInputService.KeyboardEnabled then
		local x = (if UserInputService:IsKeyDown(Enum.KeyCode.D) then 1 else 0)
			- (if UserInputService:IsKeyDown(Enum.KeyCode.A) then 1 else 0)
		if x ~= 0 or UserInputService:GetLastInputType() == Enum.UserInputType.Keyboard then
			return Vector3.new(x, 0, 0)
		end
	end
	local lastInput = UserInputService:GetLastInputType()
	if controls and (lastInput == Enum.UserInputType.Touch or string.match(lastInput.Name, "^Gamepad")) then
		local ok, v = pcall(controls.GetMoveVector, controls)
		if ok and typeof(v) == "Vector3" then
			return Vector3.new(v.X, 0, 0)
		end
	end
	return Vector3.zero
end

-- A and D, this frame: the turn to add to the way we are going (radians), the same on a fish, in the swim and
-- floating. It comes in and stops over a moment (Ride.TurnEase), and the camera turns by as much.
function RideController.turn(dt: number): number
	local r = Config.Ride
	local want = -RideController.moveVector().X * math.rad(r.YawRate)
	turnNow = Ease.lerp(turnNow, want, Ease.alpha(r.TurnEase, dt))
	turned += turnNow * dt
	return turnNow * dt
end

-- The way we are going, a frame on: `now` is it this frame (radians), and the new one comes back. A and D turn it
-- directly, and the view by as much (Hugo, 2026-11-12: until then they turned only the view and the way we go chased
-- it, a second lag on top of the key's own ease, so a turn began late and ran on after the key was let go). With
-- Ride.CameraSteer on (the reference, and the user after playing, 2026-11-11) it also comes round to where the camera
-- looks, no faster than Ride.SteerRate: a drag, a stick or the mouse in the hop turn the view, and the fish, the hop
-- and the float all follow it. With it off, only A and D turn us (Movement v3.1).
function RideController.steer(now: number, dt: number): number
	local r = Config.Ride
	local by = RideController.turn(dt)
	local after = now + by
	if r.CameraSteer <= 0 then
		steerRate = turnNow
		return after
	end
	local view = camYaw + turned -- (this frame's A and D reach camYaw in cameraStep, a moment later)
	local gap = math.atan2(math.sin(view - after), math.cos(view - after))
	local most = math.rad(r.SteerRate) * dt
	local delta = math.clamp(gap * Ease.alpha(r.SteerEase, dt), -most, most)
	-- just landed: the fish swims on the way it swam, and comes round to our look gently (Ride.LandSteerTime)
	if State.Mode == "Riding" and r.LandSteerTime > 0 then
		delta *= Ease.smoothstep(0, r.LandSteerTime, os.clock() - State.MountedAt)
	end
	steerRate = Ease.lerp(steerRate, (by + delta) / math.max(dt, 1e-4), Ease.alpha(r.TurnEase, dt))
	return after + delta
end

-- Turns the view to a yaw and a pitch (radians), as a drag of the mouse would: for the sandbox and for tests driven by
-- script, which have no mouse. It counts as the player looking round.
function RideController.look(toYaw: number, toPitch: number)
	camYaw = toYaw
	camPitch = math.clamp(toPitch, math.rad(Config.Camera.PitchMin), math.rad(Config.Camera.PitchMax))
	lookedAt = os.clock()
end

-- This fish's own ridden speed now (its species, rarity, home land and variant; read live, so the sandbox's panel shows)
local function riddenSpeed(): number
	local fish = State.Fish
	if fish and rideType then
		return Config.riddenOf(fish, rideType)
	end
	return if rideType then rideType.RiddenSpeed else Config.Speed.Base
end

-- The landing's shake (Config.Jump.LandShake...): `size` is how far the camera is thrown, studs
function RideController.shake(size: number)
	shakeAt = os.clock()
	shakeSize = size
	shakeSeed = math.random() * 100
end

-- How hard we are turning, -1 to 1, for banking into it
function RideController.lean(): number
	return math.clamp(steerRate / math.rad(math.max(Config.Ride.YawRate, 1)), -1, 1)
end

local function clearFloat()
	if floatVelocity then
		floatVelocity:Destroy()
		floatVelocity = nil
	end
	if floatTurn then
		floatTurn:Destroy()
		floatTurn = nil
	end
end

local function ensureFloat(root: BasePart)
	if floatVelocity and floatVelocity.Parent == root then
		return
	end
	clearFloat()
	local attachment = root:FindFirstChild("RootAttachment") or root:FindFirstChild("RootRigAttachment")
	if not attachment or not attachment:IsA("Attachment") then
		local a = Instance.new("Attachment")
		a.Name = "FloatAttachment"
		a.Parent = root
		attachment = a
	end
	local v = Instance.new("LinearVelocity")
	v.Name = "Float"
	v.Attachment0 = attachment :: Attachment
	v.RelativeTo = Enum.ActuatorRelativeTo.World
	-- (a few times the character's weight, no more: a force in the millions is never needed, and forces without a
	-- sensible limit are what threw riders about at a mount: Lib/FishModel, 2026-11-12)
	v.MaxForce = root.AssemblyMass * workspace.Gravity * 4
	v.Parent = root
	local t = Instance.new("AlignOrientation")
	t.Name = "FloatTurn"
	t.Mode = Enum.OrientationAlignmentMode.OneAttachment
	t.Attachment0 = attachment :: Attachment
	t.MaxTorque = 2e4
	t.Responsiveness = 12
	t.Parent = root
	floatVelocity = v
	floatTurn = t
end

-- the yaw and pitch of a look vector, for CFrame.fromOrientation(pitch, yaw, 0)
local function anglesOf(look: Vector3): (number, number)
	return math.atan2(-look.X, -look.Z), math.asin(math.clamp(look.Y, -1, 1))
end

local function onMounted(fish: Model, landing: boolean?)
	if typeof(fish) ~= "Instance" or not fish:IsA("Model") then
		-- the fish hasn't reached us yet (the server's word came first): look for the one marked as ours
		task.spawn(function()
			for _ = 1, 30 do
				task.wait(0.1)
				if State.Fish or State.Player:GetAttribute("State") ~= "Riding" then
					return
				end
				local folder = workspace:FindFirstChild("Fish")
				for _, model in if folder then folder:GetChildren() else {} do
					if
						model:IsA("Model")
						and model.PrimaryPart
						and model:GetAttribute("Rider") == State.Player.UserId
					then
						RideController.mounted(model, landing)
						return
					end
				end
			end
		end)
		return
	end
	State.Fish = fish
	State.MountedAt = os.clock()
	local root = fish.PrimaryPart
	rideType = Config.FishById[fish:GetAttribute("FishType") :: string]
	if root then
		-- carry on exactly as it swam: no turn, no drop in speed, then the speed-up
		yaw, pitch = anglesOf(root.CFrame.LookVector)
		pitch = math.clamp(pitch, -math.rad(35), math.rad(35)) -- (a wild fish never noses further than this)
		-- (never more than the fish can swim: in the frame its body joins ours the engine can report a speed in the
		-- thousands, and the ride then carried on at that speed: riders were thrown 10,000 studs, 2026-11-12)
		local most = if rideType then Config.riddenOf(fish, rideType) else 100
		startSpeed = math.min(root.AssemblyLinearVelocity.Magnitude, most)
		if startSpeed ~= startSpeed then
			startSpeed = 0
		end
	end
	if coasting and coasting.Fish == fish then
		coasting = nil
	end
	leftFish = nil
	leftWeld = nil
	roll = 0
	startled = landing == true and Config.Ride.Startle > 0
	bolted = false
	angry = false
	angryIn = 0
	clearFloat()
	-- (a fish that breaks props swims through them: the server knocks their boxes loose as it does)
	Course.begin(rideType ~= nil and Config.smashes(rideType))
	State.setMode("Riding")
end

-- A startled fish's speed, `t` seconds after the landing: it never stops. It comes down to StartleSlow of its ridden
-- speed at the touch (a fish that was slower than that, a wild one at the herd's pace, comes up to it), stays there for
-- StartleHold, then eases back to full over StartleRecover.
local function startleSpeed(from: number, ridden: number, t: number): number
	local r = Config.Ride
	local slow = ridden * math.clamp(r.StartleSlow, 0, 1)
	if t < r.StartleHold then
		return Ease.lerp(from, slow, Ease.outQuad(t / math.max(r.StartleBrake, 0.01)))
	end
	return Ease.lerp(slow, ridden, Ease.smoothstep(0, math.max(r.StartleRecover, 0.01), t - r.StartleHold))
end

-- Angry mode, this frame: the share of its speed the fish under us keeps (1 when calm), and its style's stand-in
-- motion (nose, turn and roll, radians; zeros when calm or with Angry.Motion 0). The server's word is the fish's
-- "Angry" attribute; how far through its red part the meter is comes from our own Oxygen, as the server last said it.
local function angrySpeed(fish: Model, kind: Config.FishType, dt: number): (number, number, number, number)
	local a = Config.Angry
	local now = os.clock()
	local on = a.On ~= 0 and fish:GetAttribute("Angry") == true
	if on and not angry then
		angryAt = now
	end
	angry = on
	local step = dt / math.max(if on then a.EaseIn else a.EaseOut, 0.01)
	angryIn = math.clamp(angryIn + (if on then step else -step), 0, 1)
	if angryIn <= 0 then
		return 1, 0, 0, 0
	end
	local player = State.Player
	local heat = 1
	if RunService:IsStudio() and a.Test > 0 then
		heat = a.Test
	elseif player:GetAttribute("Strained") ~= true then
		local oxygen = player:GetAttribute("Oxygen")
		local max = player:GetAttribute("MaxOxygen")
		if type(oxygen) == "number" and type(max) == "number" then
			heat = Config.heat(oxygen, max)
		end
	end
	local style = AngryStyles.of(kind)
	local t = now - angryAt
	local blend = Ease.smoothstep(0, 1, angryIn)
	local share = Ease.lerp(1, AngryStyles.speed(style, t, heat, kind.Tier), blend)
	-- THE STAND-IN MOTION (Angry.Motion; see Shared/AngryStyles): a sine on the nose, the turn and the roll. Take this
	-- out, or set Angry.Motion to 0, when authored animations play by the fish's "AngryStyle" attribute instead.
	local nod, wag, rock = 0, 0, 0
	if a.Motion > 0 then
		local size = math.rad(math.min(a.Motion, 2) * blend)
		nod, wag, rock = AngryStyles.motion(style, t)
		nod, wag, rock = nod * size, wag * size, rock * size
	end
	return share, nod, wag, rock
end

local function drive(dt: number)
	local fish = State.Fish
	local root = fish and fish.PrimaryPart
	if not fish or not root or not rideType then
		return
	end
	local swim = root:FindFirstChild("Swim") :: LinearVelocity?
	local turn = root:FindFirstChild("Turn") :: AlignOrientation?
	if not swim or not turn then
		return
	end
	local r = Config.Ride
	-- always forward, turning to where the camera looks (A and D turn the camera); with Ride.CameraSteer off, A and D only
	yaw = RideController.steer(yaw, dt)
	State.Heading = yaw
	local at = root.Position
	local floorY = Course.floor(at)
	local height = if floorY then at.Y - floorY else nil
	-- the herd's height here: lower in the shallows, where it leaves room above it for a jump
	local level = if floorY then math.min(Config.Herd.RideHeight, Config.herdTop(floorY)) else Config.Herd.RideHeight
	if height then
		-- it follows the lane down by itself, settling at the herd's height above the floor
		local h = Config.Herd
		local want = math.clamp((level - height) * h.RideHeightGain, -h.RideHeightPitch, h.RideHeightPitch)
		pitch = Ease.lerp(pitch, math.rad(want), Ease.alpha(2.5, dt))
	else
		-- no floor known (off the map): level, never down
		pitch = Ease.lerp(pitch, 0, Ease.alpha(2, dt))
	end
	-- keep off the floor and under the surface
	if height and height < math.min(r.FloorClearance + 4, level - 1) and pitch < math.rad(6) then
		pitch = Ease.lerp(pitch, math.rad(10), Ease.alpha(6, dt))
	end
	if at.Y > Config.Oxygen.SurfaceY - r.Ceiling and pitch > 0 then
		pitch = Ease.lerp(pitch, math.rad(-6), Ease.alpha(6, dt))
	end
	pitch = math.clamp(pitch, -math.rad(r.MaxPitch), math.rad(r.MaxPitch))
	-- banking into the turn
	roll = Ease.lerp(roll, RideController.lean() * math.rad(r.Bank), Ease.alpha(r.BankEase, dt))

	local since = os.clock() - State.MountedAt
	local ridden = riddenSpeed()
	local speed = if startled
		then startleSpeed(startSpeed, ridden, since)
		else Ease.rideSpeed(startSpeed, ridden, since, r.RampTime, r.Surge, r.SurgeTime)
	if startled and since >= r.StartleHold then
		-- it picks its speed up again: the view kicks a little wider once, and speed lines while it gathers speed
		if not bolted then
			bolted = true
			State.FovPunch = Config.Feel.BoltFov
			Feel.sound("Whoosh", Config.Feel.Whoosh * 0.7, Config.Feel.WhooshPitch * 0.8, 0.45)
		end
		local gathering =
			math.sin(math.clamp((since - r.StartleHold) / math.max(r.StartleRecover, 0.01), 0, 1) * math.pi)
		if gathering > 0.05 then
			Feel.rush(Config.Feel.BoltLines * gathering)
		end
	end
	-- just run into something: slowed at once, picking up again
	local crashed = os.clock() - crashAt
	speed *= Ease.lerp(crashSlow, 1, Ease.smoothstep(0, math.max(Config.Crash.Recover, 0.01), crashed))
	-- angry (the meter in its red part, or a fish too strong): slowed in its own style's way
	local angryShare, nod, wag, rock = angrySpeed(fish, rideType, dt)
	speed *= angryShare
	local heading = CFrame.fromOrientation(pitch, yaw, 0)
	-- the easing above is the soft part; this is the hard one: the fish can't be steered into the floor, a wall, a roof,
	-- the air or out of the lane, however the keys are held
	local wanted = heading.LookVector * speed
	local velocity = Course.clearVelocity(at, wanted, r.FloorClearance, Config.bodyOf(fish, rideType).Z / 2 + 1)
	swim.VectorVelocity = velocity
	if math.abs(velocity.Y - wanted.Y) > 1 then
		-- stopped from diving or climbing: the nose comes round to the way it is really going
		local truePitch = math.asin(math.clamp(velocity.Y / math.max(speed, 1), -1, 1))
		pitch = Ease.lerp(pitch, truePitch, Ease.alpha(8, dt))
	end
	-- (how tightly its body follows: ours while we drive it; the server's own copy, the herd's, is untouched)
	if turn.Responsiveness ~= r.Response then
		turn.Responsiveness = math.clamp(r.Response, 5, 200)
	end
	turn.CFrame = heading * CFrame.Angles(0, 0, roll)
	if nod ~= 0 or wag ~= 0 or rock ~= 0 then
		-- (the stand-in motion: the body only; the way we go, `heading`, is untouched)
		turn.CFrame *= CFrame.fromOrientation(nod, wag, rock)
	end
	State.Speed = speed
end

RideController.mounted = onMounted

-- Leaving a fish (a jump, the throw-off): it carries on along its heading, slowing to idle
function RideController.coast(fish: Model?)
	local root = fish and fish.PrimaryPart
	if not fish or not root then
		return
	end
	local kind = Config.FishById[fish:GetAttribute("FishType") :: string]
	coasting = {
		Fish = fish,
		At = os.clock(),
		Speed = root.AssemblyLinearVelocity.Magnitude,
		Look = root.CFrame.LookVector,
		Idle = if kind then Config.riddenOf(fish, kind) * Config.Herd.SpeedShare else 14,
	}
end

local function coast()
	local c = coasting
	if not c then
		return
	end
	local root = c.Fish.PrimaryPart
	local t = os.clock() - c.At
	local rider = c.Fish:GetAttribute("Rider")
	local taken = rider ~= 0 and rider ~= State.Player.UserId -- someone else is on it now
	if not root or not c.Fish.Parent or t > Config.Switch.HandBack or taken then
		coasting = nil
		return
	end
	local swim = root:FindFirstChild("Swim") :: LinearVelocity?
	local turn = root:FindFirstChild("Turn") :: AlignOrientation?
	if swim and turn then
		local level = Vector3.new(c.Look.X, c.Look.Y * (1 - Ease.smoothstep(0, 1.2, t)), c.Look.Z)
		local look = if level.Magnitude > 0.01 then level.Unit else c.Look
		local speed = Ease.lerp(c.Speed, c.Idle, Ease.smoothstep(0, Config.Ride.SlowDownTime, t))
		-- (kept out of the floor like the fish we ride: left in a dive, it would sink into it)
		Course.floor(root.Position)
		swim.VectorVelocity = Course.clearVelocity(root.Position, look * speed, Config.Ride.FloorClearance, 2)
		turn.CFrame = CFrame.lookAt(Vector3.zero, look)
	end
end

-- A jump leaves the fish at once on our side: it coasts, and its weld to us is switched off here, ahead of the server
function RideController.leave()
	local fish = State.Fish
	local root = fish and fish.PrimaryPart
	local weld = root and root:FindFirstChild("RideWeld")
	RideController.coast(fish)
	leftFish = fish
	leftWeld = nil
	if weld and weld:IsA("Weld") then
		weld.Enabled = false
		leftWeld = weld
	end
	State.Fish = nil
end

-- The server refused the jump: back on the fish we left, if it is still ours
function RideController.rejoin(): boolean
	local fish, weld = leftFish, leftWeld
	leftFish = nil
	leftWeld = nil
	if fish and weld and weld.Parent and fish.Parent and fish:GetAttribute("Rider") == State.Player.UserId then
		weld.Enabled = true
		coasting = nil
		State.Fish = fish
		State.setMode("Riding")
		return true
	end
	return false
end

local function float(root: BasePart, dt: number)
	-- Already joined to a fish (the server's weld can reach us a frame before its word that we are mounted): our own
	-- push comes off, so it never pulls against the fish's.
	for _, joint in root:GetJoints() do
		if joint.Name == "RideWeld" then
			clearFloat()
			return
		end
	end
	ensureFloat(root)
	local o = Config.Oxygen
	local rise = o.FloatSpeed
	if root.Position.Y > o.SurfaceY then
		rise = math.min(rise, (o.SurfaceY - root.Position.Y) * 4)
	end
	-- left under the floor (a landing lost on a fish that was), we would float up against its underside for good
	-- (against the lane's own floor, not a ray from above: that would find the top of an arch we are under)
	local laneY = Course.laneFloor(root.Position)
	if laneY and root.Position.Y < laneY - 1 then
		root.CFrame += Vector3.new(0, laneY + 4 - root.Position.Y, 0)
		root.AssemblyLinearVelocity = Vector3.zero
	end
	-- drifting forward, steered as on a fish (never W and S)
	yaw = RideController.steer(yaw, dt)
	State.Heading = yaw
	local heading = CFrame.fromOrientation(0, yaw, 0)
	local v = floatVelocity :: LinearVelocity
	v.VectorVelocity = Vector3.new(0, rise, 0) + heading.LookVector * o.SwimSpeed
	local t = floatTurn :: AlignOrientation
	t.CFrame = heading
	State.Speed = root.AssemblyLinearVelocity.Magnitude
end

-- The camera takes up from wherever the view is now (entering the water, after the drowning's shot): the springs start
-- there, at rest, so it never jumps
local function adopt()
	local view = camera.CFrame
	camYaw, camPitch = anglesOf(view.LookVector)
	shownYaw, shownPitch = camYaw, camPitch
	yawSpeed, pitchSpeed = 0, 0
	camPosition = view.Position
	-- (the focus that puts the camera where it is)
	camFocus = view.Position
		+ view.LookVector * (zoom * zoomScale)
		- Vector3.new(0, Config.Camera.Height * Config.Camera.ArmHeight, 0)
	focusSpeed = Vector3.zero
	reach, reachSpeed = 1, 0
	fovEased, fovSpeed = camera.FieldOfView, 0
end

local function cameraStep(dt: number)
	local character, root = State.character()
	if not State.inWater() or not character or not root then
		submerged = false
		if wasScripted then
			camera.CameraType = Enum.CameraType.Custom
			camera.FieldOfView = Config.Camera.Fov
			UserInputService.MouseBehavior = Enum.MouseBehavior.Default
			wasScripted = false
		end
		camPosition = nil
		turned = 0
		return
	end
	if not wasScripted or not camFocus then
		adopt()
		wasScripted = true
	end
	camera.CameraType = Enum.CameraType.Scriptable
	local c = Config.Camera
	local mode = State.Mode
	-- the camera always follows our own character (it sits on the saddle while riding), so a jump never cuts

	-- the drowning's shot: ease there, no cut, turning to look at the shot's focus
	local shot = State.DeathCam
	if shot then
		deathBlend = math.min(1, deathBlend + dt / 0.5)
		camFocus = (camFocus or shot.Focus):Lerp(shot.Focus, Ease.alpha(5, dt))
		camPosition = (camPosition or shot.Position):Lerp(shot.Position, Ease.alpha(3, dt))
		local at = camPosition :: Vector3
		if submerged and at.Y > ceiling then
			-- (the drowning's shot stays under the surface too)
			at = Vector3.new(at.X, ceiling, at.Z)
			camPosition = at
		end
		local towards = (camFocus :: Vector3) - at
		local free = CFrame.fromOrientation(shownPitch, shownYaw, 0).LookVector
		local look = if towards.Magnitude > 0.1
			then free:Lerp(towards.Unit, Ease.smoothstep(0, 1, deathBlend))
			else free
		camera.CFrame = CFrame.lookAt(at, at + look)
		camera.FieldOfView = Ease.lerp(camera.FieldOfView, c.Fov, Ease.alpha(3, dt))
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
		turned = 0
		return
	end
	if deathBlend > 0 then
		deathBlend = 0
		adopt()
	end

	-- Where the camera is asked to look. It turns with us (A and D turn the way we are going, and the camera by as
	-- much); beyond that the player's look wins. A gamepad's right stick looks round at any time. Nothing brings the
	-- view round after a landing or tilts it in the hop (Camera.AirRest gives that tilt back, until the view is
	-- touched). Only left alone for LookBack seconds, on a fish or floating, does it drift back behind us, gently.
	camYaw += turned
	turned = 0
	if stick.Magnitude > 0 then
		camYaw -= stick.X * c.StickSensitivity * dt
		camPitch += stick.Y * c.StickSensitivity * dt
		lookedAt = os.clock()
	elseif rightHeld then
		lookedAt = os.clock()
	end
	local heading = State.Heading
	if mode == "Jumping" then
		if c.AirRest > 0 and lookedAt < airAt then
			camPitch = Ease.lerp(camPitch, math.rad(Config.Jump.CameraPitch), Ease.alpha(c.AirPitchFollow, dt))
		end
	elseif c.AutoRecentre > 0 and os.clock() - math.max(lookedAt, airAt, State.MountedAt) >= c.LookBack then
		-- (a hop and a landing count as looking: the view is never brought round sooner than LookBack after one)
		local rest = if mode == "Riding" then pitch * 0.5 + math.rad(c.RestPitch) else math.rad(c.RestPitch)
		camYaw = Ease.lerpAngle(camYaw, heading, Ease.alpha(c.Recentre, dt))
		camPitch = Ease.lerp(camPitch, rest, Ease.alpha(c.PitchFollow, dt))
	end
	if mode ~= "Jumping" and c.AirRest > 0 and lookedAt < airAt then
		-- the hop tilted the view down and we never touched it: back up to the riding view as soon as we are down
		local rest = if mode == "Riding" then pitch * 0.5 + math.rad(c.RestPitch) else math.rad(c.RestPitch)
		camPitch = Ease.lerp(camPitch, rest, Ease.alpha(c.AirPitchFollow, dt))
	end
	camPitch = math.clamp(camPitch, math.rad(c.PitchMin), math.rad(c.PitchMax))
	State.CamYaw = camYaw

	-- in the hop the mouse aims with no button held
	UserInputService.MouseBehavior = if mode == "Jumping" and c.AirMouseLook > 0
		then Enum.MouseBehavior.LockCenter
		elseif rightHeld then Enum.MouseBehavior.LockCurrentPosition
		else Enum.MouseBehavior.Default

	-- what it shows: each on its spring
	shownYaw, yawSpeed = Spring.angle(shownYaw, camYaw, yawSpeed, c.TurnTime, dt)
	shownPitch, pitchSpeed = Spring.number(shownPitch, camPitch, pitchSpeed, c.TurnTime, dt)
	local zoomGoal = if mode == "Jumping" then Config.Jump.CameraZoom else 1
	zoomScale, zoomSpeed = Spring.number(zoomScale, zoomGoal, zoomSpeed, c.ZoomTime, dt)
	local distance = zoom * zoomScale
	local rotation = CFrame.fromOrientation(shownPitch, shownYaw, 0)
	if State.SideCam then
		-- the sandbox's side view: square on to the way we are headed, far enough to see a whole jump
		distance = math.max(distance, 70)
		rotation = CFrame.fromOrientation(math.rad(-4), shownYaw + math.pi / 2, 0)
	end
	local focusGoal = root.Position + Vector3.new(0, c.Height * c.FocusHeight, 0)
	local focus: Vector3
	focus, focusSpeed = Spring.vector(camFocus :: Vector3, focusGoal, focusSpeed, c.FocusTime, dt)
	camFocus = focus
	local lift = c.Height * c.ArmHeight
	-- Under the surface, once we have dived (Camera.Submerge): where the arm would lift the camera past the line, it
	-- swings down behind us instead, as far as it must, and the view gives up a share of that tilt (SurfaceTilt).
	local line = c.WaterTop - c.SurfaceMargin
	local armRotation = rotation
	if c.Submerge <= 0 then
		submerged = false
	elseif not submerged then
		-- dived: the camera is under by itself, or we are well under (it is then brought down, not snapped)
		local wantedY = focus.Y + lift - rotation.LookVector.Y * distance
		if wantedY <= line or root.Position.Y < line - 6 then
			submerged = true
			ceiling = math.max(line, wantedY, (camPosition or focus).Y)
		end
	end
	if submerged then
		ceiling = Ease.lerp(ceiling, line, Ease.alpha(5, dt))
		if ceiling - line < 0.01 then
			ceiling = line
		end
		if not State.SideCam then
			local rise = -rotation.LookVector.Y -- the sine of how far the camera sits above our level
			local most = math.clamp((ceiling - focus.Y - lift) / math.max(distance, 0.1), -0.5, 1)
			if rise > most then
				local lost = math.asin(math.clamp(rise, -1, 1)) - math.asin(most)
				armRotation = CFrame.fromOrientation(-math.asin(most), shownYaw, 0)
				rotation = CFrame.fromOrientation(shownPitch + lost * math.clamp(c.SurfaceTilt, 0, 1), shownYaw, 0)
			end
		end
	end
	local arm = -armRotation.LookVector * distance + Vector3.new(0, lift, 0)

	-- keep the camera out of the floor and walls: it comes in at once (never inside one), and eases back out
	if cameraFor ~= character then
		cameraFor = character
		cameraParams.FilterDescendantsInstances = { character, camera }
	end
	local hit = workspace:Raycast(focus, arm, cameraParams)
	local free = if hit
		then math.max(0, (hit.Position - focus).Magnitude - c.WallGap) / math.max(arm.Magnitude, 0.1)
		else 1
	if free < reach then
		reach, reachSpeed = free, 0
	else
		reach, reachSpeed = Spring.number(reach, free, reachSpeed, c.ZoomTime, dt)
	end
	local position = focus + arm * reach
	camPosition = position
	-- the landing's jolt: knocked down, springing back
	local j = Config.Jump
	if State.KickVelocity ~= 0 then
		kickSpeed -= State.KickVelocity
		State.KickVelocity = 0
	end
	local w = 2 * math.pi * j.LandKickRate
	-- in small steps, so a slow frame can't throw the spring
	local steps = math.max(math.ceil(dt * 240), 1)
	local h = dt / steps
	for _ = 1, steps do
		kickSpeed += (-w * w * kickAt - 2 * j.LandKickDamp * w * kickSpeed) * h
		kickAt += kickSpeed * h
	end
	-- and its shake: thrown about for a moment, dying away
	local shake = CFrame.identity
	local shaken = (os.clock() - shakeAt) / math.max(j.LandShakeTime, 0.01)
	if shaken < 1 and shakeSize > 0 then
		local size = shakeSize * (1 - shaken) ^ 2
		local t = shakeSeed + (os.clock() - shakeAt) * j.LandShakeRate
		shake = CFrame.new(math.noise(t, 1.5) * 2 * size, math.noise(t, 7.5) * 2 * size, 0)
			* CFrame.Angles(
				0,
				0,
				math.noise(t, 13.5) * 2 * math.rad(j.LandShakeRoll) * size / math.max(j.LandShake, 0.01)
			)
	end
	local view = CFrame.lookAt(position, position + rotation.LookVector) * CFrame.new(0, kickAt, 0) * shake
	if submerged and view.Position.Y > ceiling then
		-- whatever is left (the jolt, the shake, the side view, a camera that had nowhere lower to go): held under
		view -= Vector3.new(0, view.Position.Y - ceiling, 0)
	end
	camera.CFrame = view

	-- field of view: wider with speed
	local speedT = Ease.smoothstep(c.SpeedFovFrom, c.SpeedFovTo, State.Speed)
	local fovGoal = c.Fov + c.SpeedFov * speedT
	fovEased, fovSpeed = Spring.number(fovEased, fovGoal, fovSpeed, c.FovTime, dt)
	-- the punch goes on top at once (the pull-in's zoom in, the landing's snap out), and runs down by itself
	camera.FieldOfView = math.clamp(fovEased + State.FovPunch, 30, 120)
	local run = math.abs(j.LandFov) / math.max(j.LandFovTime, 0.01) * dt
	State.FovPunch = if State.FovPunch > 0 then math.max(0, State.FovPunch - run) else math.min(0, State.FovPunch + run)
end

-- On the dock Roblox's own camera is used, and it keeps looking the way it did before the server stood us on the dock's
-- spawn: a new player looked at the hub with the water behind them, face to face with their own character (seen
-- 2026-11-11 on grey-box 9). So each time we are put on the dock, the view is brought round behind the character,
-- looking the way the dock's spawn faces (the server's "Dock" attribute), which is toward the water.
local facing = 0
local function faceWater()
	facing += 1
	local mine = facing
	task.spawn(function()
		-- the server moves the character a moment after it appears: wait until it is standing at the spawn
		local began = os.clock()
		while os.clock() - began < 5 do
			if mine ~= facing or State.Mode ~= "Dock" then
				return
			end
			local dock = Net.Folder:GetAttribute("Dock")
			local _, root = State.character()
			if typeof(dock) == "CFrame" and root then
				local away = (root.Position - dock.Position) * Vector3.new(1, 0, 1)
				if away.Magnitude < 12 then
					local look = dock.LookVector * Vector3.new(1, 0, 1)
					if look.Magnitude > 0.1 then
						look = look.Unit
						local head = root.Position + Vector3.new(0, 2, 0)
						camera.CFrame = CFrame.lookAt(head - look * 14 + Vector3.new(0, 5, 0), head + look * 8)
					end
					return
				end
			end
			task.wait(0.1)
		end
	end)
end

local function step(dt: number)
	local mode = State.Mode
	if mode ~= lastMode then
		if mode == "Dock" then
			faceWater()
		elseif mode == "Free" then
			-- floating carries on the way we were going; off the dock, the way the camera looks
			yaw = if lastMode == "Dock" then (anglesOf(camera.CFrame.LookVector)) else State.Heading
			State.Heading = yaw
		elseif mode == "Jumping" then
			airAt = os.clock()
		end
		lastMode = mode
	end
	local _, root, humanoid = State.character()
	if root and humanoid then
		if State.inWater() then
			if not humanoid.PlatformStand then
				humanoid.PlatformStand = true
			end
			if mode == "Riding" then
				seating = nil
				drive(dt)
			elseif mode == "Free" and seating then
				-- The sandbox's reset: we sit ourselves on the fish, as a pull-in does, before the server welds us to
				-- it. Held on the saddle and moving with it for a few frames, then the server is told.
				local fishRoot = seating.PrimaryPart
				local saddle = fishRoot and fishRoot:FindFirstChild("Saddle")
				if not fishRoot or not saddle or not saddle:IsA("Attachment") or os.clock() - seatingAt > 2.5 then
					seating = nil
				else
					clearFloat()
					root.CFrame = saddle.WorldCFrame
					root.AssemblyLinearVelocity = fishRoot.AssemblyLinearVelocity
					root.AssemblyAngularVelocity = Vector3.zero
					if not seatingTold and os.clock() - seatingAt > SEAT_HOLD then
						seatingTold = true
						Net.Action:FireServer("SandboxSit", seating)
					end
				end
			elseif mode == "Free" then
				float(root, dt)
			else
				clearFloat()
			end
		else
			clearFloat()
			if mode == "Dock" and humanoid.PlatformStand then
				humanoid.PlatformStand = false
			end
			State.Speed = root.AssemblyLinearVelocity.Magnitude
		end
	end
	coast()
	cameraStep(dt)
end

-- The server's State, where our own prediction doesn't already cover it
local function fromServerState()
	local state = State.Player:GetAttribute("State")
	if state == "Dock" or state == "Drowning" then
		State.Fish = nil
		State.setMode(state)
	elseif state == "Free" then
		-- also the end of a jump that missed from floating, or lost its fish
		State.Fish = nil
		State.setMode("Free")
	end
end

function RideController.Init()
	Net.Ride.OnClientEvent:Connect(function(kind: string, a: any, b: any)
		if kind == "Mounted" then
			-- (`b`: whether it is a landing, which startles the fish, or the sandbox's reset, which doesn't)
			onMounted(a, b == true)
		elseif kind == "SandboxMount" then
			-- the sandbox's reset has kept this fish for us: sit on it (step), then say so
			-- (only a fish that is near us as we see it. Otherwise it is left alone: the server gives the seat up
			-- after a moment and offers another.)
			local _, root = State.character()
			local fishRoot = if typeof(a) == "Instance" and a:IsA("Model") then a.PrimaryPart else nil
			if root and fishRoot and (fishRoot.Position - root.Position).Magnitude < 400 then
				submerged = false -- (the sandbox's reset counts as a respawn: the camera dives again from where it is)
				seating = a
				seatingAt = os.clock()
				seatingTold = false
			end
		elseif kind == "Crashed" then
			-- the server saw our fish run into something (a wall, or a prop it broke): `a` is the share of speed left
			if type(a) == "number" then
				crashAt = os.clock()
				crashSlow = math.clamp(a, 0, 1)
				State.CrashAt = crashAt
				State.KickVelocity = Config.Crash.Kick * 2 * math.pi * Config.Jump.LandKickRate
			end
		elseif kind == "Dismounted" then
			if a == "Jump" or a == "OutOfOxygen" then
				-- the jump or the throw-off takes over; the fish swims on without us
				if State.Fish then
					RideController.coast(State.Fish)
				end
				State.Fish = nil
				if a == "Jump" and State.Mode == "Riding" then
					-- the server took a jump we aren't flying (a press that crossed with a mount): float, don't
					-- sit in Riding with no fish
					State.setMode("Free")
				end
				return
			end
			State.Fish = nil
			if a == "Lost" then
				State.setMode("Free")
			end
		end
	end)
	State.Player:GetAttributeChangedSignal("State"):Connect(fromServerState)
	State.Player.CharacterAdded:Connect(function()
		submerged = false
		State.Fish = nil
		coasting = nil
		clearFloat()
		camFocus = nil
		fromServerState()
		faceWater()
	end)

	UserInputService.InputChanged:Connect(function(input: InputObject, processed: boolean)
		if not State.inWater() then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseMovement then
			if rightHeld or (State.Mode == "Jumping" and Config.Camera.AirMouseLook > 0) then
				camYaw -= input.Delta.X * Config.Camera.MouseSensitivity
				camPitch -= input.Delta.Y * Config.Camera.MouseSensitivity
				lookedAt = os.clock()
			end
		elseif input.UserInputType == Enum.UserInputType.Touch and not processed then
			camYaw -= input.Delta.X * Config.Camera.TouchSensitivity
			camPitch -= input.Delta.Y * Config.Camera.TouchSensitivity
			lookedAt = os.clock()
		elseif input.KeyCode == Enum.KeyCode.Thumbstick2 then
			-- (read every frame in cameraStep; a dead zone, so a stick at rest never counts as looking)
			local v = Vector2.new(input.Position.X, input.Position.Y)
			stick = if v.Magnitude > 0.2 then v else Vector2.zero
		elseif input.UserInputType == Enum.UserInputType.MouseWheel then
			zoom = math.clamp(
				zoom - input.Position.Z * Config.Camera.WheelStep,
				Config.Camera.ZoomMin,
				Config.Camera.ZoomMax
			)
		end
	end)
	UserInputService.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton2 then
			rightHeld = true
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton2 then
			rightHeld = false
		end
	end)
end

function RideController.Start()
	-- Roblox's own controls, for the move stick on a phone or gamepad: looked for on the side, never waited on. In
	-- Studio on 2026-11-10 PlayerScripts had no PlayerModule at all, and waiting 10 s for it here held back everything
	-- below: no camera, floating or steering for the first 10 seconds of a session. The keys are read directly anyway
	-- (moveVector).
	task.spawn(function()
		local playerModule = State.Player:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule", 30)
		if playerModule and playerModule:IsA("ModuleScript") then
			local ok, module = pcall(require, playerModule)
			if ok then
				controls = (module :: any):GetControls()
			end
		end
	end)
	local zonesJson = Net.Folder:GetAttribute("Zones")
	if type(zonesJson) == "string" then
		State.Zones = Zones.decode(zonesJson)
	end
	faceWater() -- our first character may have appeared before we were listening
	Net.Folder:GetAttributeChangedSignal("Zones"):Connect(function()
		local json = Net.Folder:GetAttribute("Zones")
		if type(json) == "string" then
			State.Zones = Zones.decode(json)
		end
	end)
	fromServerState()
	RunService:BindToRenderStep("RideFish", Enum.RenderPriority.Camera.Value + 1, step)
	-- Just before each physics step, after the frame's news from the server is in: if a fish's weld has joined us while
	-- our floating push is still on, the push goes now (see ensureFloat). The step above runs too early in the frame
	-- to see a weld that arrived in it.
	RunService.PreSimulation:Connect(function()
		if not floatVelocity then
			return
		end
		local _, root = State.character()
		if not root then
			return
		end
		for _, joint in root:GetJoints() do
			if joint.Name == "RideWeld" then
				clearFloat()
				return
			end
		end
	end)
end

return RideController
