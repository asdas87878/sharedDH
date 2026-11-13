--!strict
-- Going fish to fish, Movement v3.1 (Config.Jump, Config.Lock; docs/design/riding-feel.md): the reference's hop, read
-- and measured from the user's recordings (docs/reference/ride-a-dino.md), with a lock-on and a window. Space throws us
-- off the fish (or up from floating) at once on our side; the server is told and follows. The hop, placed by CFrame
-- every frame:
--   the pop: up, above where we left and the fish we look at, with most of the fish's speed and a kick on top;
--   the glide: flat at the top, lying face down, the speed easing off slowly;
--   the drop: the speed runs out in a long gentle tail to a stop, and the more of it is gone the faster we fall.
-- The speed is one curve with no knee and the fall is blended in along it (Config.hopSpeed, Config.hopSink; Hugo,
-- 2026-11-13).
-- We always go forward, and A and D steer that exactly as they steer a fish (RideController.turn); nothing else moves us.
-- The whole hop is the window (Jump.Window seconds, shown by the HUD) to grab the next fish. The lock-on (Lib/Lock) holds
-- the fish we are looking at, along the camera's aim, lenient, far fish as easy as near, sticky so it doesn't flicker,
-- and only ever a fish inside the reach we have right now, which is by our speed across the water (Config.reachOf). A
-- dashed yellow ring lies in the water round that fish (the partner's ring of 2026-11-10, a quarter smaller: it lay
-- under us then) and the fish glows a little. While we still ride or float the lock shows too, fainter, so we see what
-- we could reach before leaving.
-- A second press (Space, a click, E) grabs the locked fish: the server is told ("Grab": it checks the range and keeps
-- the fish for us) and we are pulled onto its saddle on the reference's curve (a creep, then faster and faster, easing
-- onto the saddle), the view narrowing and yellow dots left behind us; at the landing the view snaps wide and the camera
-- is jolted and shaken (harder after a faster pull-in). A press with nothing locked only flashes the reticle. The window gone with no fish grabbed, we have sunk: a
-- miss, and we tell the server.
-- The hop doesn't collide with anything: Lib/Course keeps it out of the floor, the walls and the lane's edge.
-- The ring's dashes, the dots and the glow are made once here and reused: nothing is created per hop.
-- The juice (Config.Feel, Lib/Feel; Hugo, 2026-11-12): the pop kicks the view wider, with a burst of bubbles where we
-- left, a swish, and speed lines and a bubble trail through its extra speed; the pull-in has a whoosh, lines that grow
-- as it speeds up and the trail; our own landing throws bubbles out round the fish, with a splash.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Ease = require(ReplicatedStorage.Shared.Ease)
local Net = require(ReplicatedStorage.Shared.Net)
local Actions = require(script.Parent.Parent.Lib.Actions)
local Course = require(script.Parent.Parent.Lib.Course)
local Feel = require(script.Parent.Parent.Lib.Feel)
local Fx = require(script.Parent.Parent.Lib.Fx)
local Lock = require(script.Parent.Parent.Lib.Lock)
local State = require(script.Parent.Parent.Lib.State)
local WallRide = require(script.Parent.Parent.Lib.WallRide)
local RideController = require(script.Parent.RideController)

local JumpController = {}

local WHITE = Color3.new(1, 1, 1)
local DASHES = 16
local RUSH_KEEP = 0.7 -- the hop's speed lines last while this share of the leaving speed is still there

local flying = false
local clock = 0 -- wall-clock seconds since leaving
local startedAt = 0
local resumeHeight = 0 -- keeps a failed pull-in from snapping us back onto the hop's arc
local position = Vector3.zero
local yaw = 0 -- the way we are going: A and D turn it
local roll = 0 -- banking into a turn
local launchSpeed = 0
local flatSpeed = 0 -- the speed we really have across the water this frame (walls and all): the hook's reach is by it
local reach = 0 -- the hook's reach right now (Config.reachOf)
local touchedAt = -math.huge -- os.clock() our last pull-in ended on the saddle (the touch): Jump.Cooldown runs from it
-- this hop off a Leaper (Config.hopOf; 1 and 0 off any other fish and from floating):
local leapApex = 1 -- Jump.Apex, times,
local leapTime = 0 -- and seconds more glide, window and run-out (with the airtime by speed: Config.airOf)
local wall = WallRide.new() -- the hop's wall ride (Config.Wall)
local faced = 0 -- the way the body faces: the way we steer, or along a wall we ride (eased)
local autoAt = 0 -- os.clock() before which the hands-off pull-in holds off (Jump.RehookGuard, after a refused one)
local mashing = false -- Space was pressed again during the pull-in: that run of presses can't hop us off the fish we land on
local pressedAt = -math.huge -- os.clock() of the last press of any kind
local baseY, topY = 0, 0 -- where we left, and the top of the glide
local left: Model? = nil -- the fish this hop left
local locked: Model? = nil -- the locked fish: the one a grab takes; it glows
local refused: Model? = nil -- a fish the server just refused us: not locked again for a moment
local refusedUntil = 0

-- the reel-in: from where we were, onto the saddle
local reeling = false
local reelStartedAt = 0
local reelFrom = CFrame.identity -- our turn when it began
local reelOffset = Vector3.zero -- and where we were from the saddle: the gap that closes
local reelTime = 0

-- the dots left behind us through the pull-in, as the reference leaves them (made once, reused)
local TRAIL_DOTS = Config.Jump.TrailDots
local trailFolder: Folder
local trailDots: { Part } = {}
local trailBorn: { number } = {}
local trailNext = 0
local trailAt = 0
local trailLive = false
local asked = false -- the landing has been sent; we hold on the saddle for the server's word
local askedAt = 0

-- the ring round the locked fish
local ringFolder: Folder
local dashes: { Part } = {}
local ringShown = false
local ringOffset = Vector3.zero -- how far the ring still is from its fish (it glides from one locked fish to the next)
local ringCentre = Vector3.zero
local ringTurn = 0 -- the dashes go round
local ringArc, ringThick = 0, 0 -- the size the dashes were last given

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

local function dropDot(at: Vector3)
	local t = os.clock()
	if t - trailAt < Config.Jump.TrailEvery then
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
		local age = (t - trailBorn[i]) / math.max(Config.Jump.TrailLife, 0.01)
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

local function showRing(show: boolean)
	if show ~= ringShown then
		ringShown = show
		ringFolder.Parent = if show then workspace.CurrentCamera else nil
	end
end

-- The ring round the locked fish: flat in the water at the fish's level (tipped toward the camera by Jump.RingFace),
-- each dash lying along the circle. Fainter while we still ride or float.
local function placeRing(dt: number)
	local j = Config.Jump
	local fish = locked
	local root = fish and fish.Parent and fish.PrimaryPart
	if not fish or not root or glowLandedAt then
		showRing(false)
		return
	end
	local at = root.Position
	if ringShown then
		-- from another fish: it glides over
		ringOffset = (ringCentre - at) * (1 - Ease.alpha(j.RingFollow, dt))
	else
		ringOffset = Vector3.zero
	end
	ringCentre = at + ringOffset
	local kind = Config.FishById[fish:GetAttribute("FishType") :: string]
	local eye = workspace.CurrentCamera.CFrame.Position
	local away = (eye - ringCentre).Magnitude
	-- a far fish's ring is wider and turned to the camera (and its dashes thicker, below), so it shows at the full range
	local far = math.clamp((away - j.RingGrow) / math.max(j.GrabRange - j.RingGrow, 1), 0, 1)
	local radius = math.max(j.RingRadius, if kind then Config.bodyOf(fish, kind).Z / 2 + 2 else 0)
		* Ease.lerp(1, j.RingFar, far)
	local face = math.clamp(Ease.lerp(j.RingFace, j.RingFarFace, far), 0, 1)
	local normal = Vector3.new(0, 1 - face, 0) + (eye - ringCentre) / math.max(away, 0.01) * face
	normal = if normal.Magnitude > 0.01 then normal.Unit else Vector3.yAxis
	local right = (if math.abs(normal.Y) > 0.99 then Vector3.xAxis else Vector3.yAxis):Cross(normal).Unit
	local up = normal:Cross(right)
	local arc = 2 * math.pi * radius / DASHES
	local thick = math.max(1, away / math.max(j.RingGrow, 1))
	if math.abs(arc - ringArc) > 0.02 or math.abs(thick - ringThick) > 0.02 then
		ringArc, ringThick = arc, thick
		for _, dash in dashes do
			dash.Size = Vector3.new(arc * 0.6, 0.3 * thick, 0.8 * thick)
		end
	end
	ringTurn = (ringTurn + math.rad(j.RingSpin) * dt) % (2 * math.pi)
	local faint = if flying then 0 else j.RingPreview
	-- (the ring shows the reach we really have: it thins out as its fish nears the edge of it)
	local _, me = State.character()
	if me and flying and not reeling and not asked and j.RingEdge < 1 then
		local share = (at - me.Position).Magnitude / math.max(reach, 1)
		faint = Ease.lerp(faint, 0.85, Ease.smoothstep(j.RingEdge, 1, share))
	end
	for i, dash in dashes do
		local angle = ringTurn + (i - 1) / DASHES * math.pi * 2
		local out = right * math.cos(angle) + up * math.sin(angle)
		local along = up * math.cos(angle) - right * math.sin(angle)
		dash.CFrame = CFrame.fromMatrix(ringCentre + out * radius, along, out:Cross(along), out)
		dash.Transparency = faint
	end
	showRing(true)
end

local function setGlow(fish: Model?)
	if glow.Adornee ~= fish then
		glow.Adornee = fish
	end
	glow.Enabled = fish ~= nil
	glow.FillColor = Config.Jump.GlowFill
	glow.OutlineColor = Config.Jump.GlowOutline
	glow.FillTransparency = if flying then Config.Jump.FlyGlow else Config.Jump.PreviewGlow
	glow.OutlineTransparency = if flying then 0 else 0.4
	glowLandedAt = nil
end

-- The lock-on: the fish along the camera's aim (Lib/Lock), from where we are. It glows from the moment it is picked.
local function pick(from: Vector3)
	local view = workspace.CurrentCamera.CFrame
	local skip = if os.clock() < refusedUntil then refused else nil
	-- (the last chance, Lock.LastChance: the glide over, any fish in reach ahead will do; the one nearest the
	-- aim still wins, and a fish already locked keeps the lock as it always does)
	local j = Config.Jump
	local wide = flying and Config.Lock.LastChance > 0 and clock >= j.LaunchTime + j.FloatTime + leapTime
	local best = Lock.pick(from, view.Position, view.LookVector, locked, left, skip, reach, wide)
	if best ~= locked then
		locked = best
		setGlow(best)
	end
	State.JumpTarget = locked
end

local function stop()
	flying = false
	reeling = false
	State.Reeling = false
	State.WindowLeft = nil
	State.JumpPhase = nil
	State.Reach = nil
	asked = false
	left = nil
	locked = nil
	State.JumpTarget = nil
	Feel.trail(nil, false)
	if State.Wall then
		State.Wall = nil
		State.WallSide = 0
	end
	if not glowLandedAt then
		setGlow(nil)
	end
end

-- How far through the pull-in we are, 0 to 1 (nil when not in one), and how long it takes in all: the dash's pose
-- follows it (AnimController)
function JumpController.reel(): (number?, number)
	if not flying or not (reeling or asked) then
		return nil, reelTime
	end
	local u = if asked then 1 else math.clamp((os.clock() - reelStartedAt) / math.max(reelTime, 0.01), 0, 1)
	return u, reelTime
end

local function startReel(root: BasePart)
	local saddle = saddleOf(locked)
	local gap = if saddle then root.Position - saddle.Position else Vector3.zero
	local away = gap.Magnitude
	reeling = true
	State.Reeling = true
	reelOffset = gap
	reelStartedAt = os.clock()
	local j = Config.Jump
	reelTime = math.max(j.ReelMin, math.min(j.ReelTime + away / math.max(j.GrabSpeed, 1), j.ReelMax))
	reelFrom = root.CFrame
	Feel.sound("Whoosh", Config.Feel.Whoosh, Config.Feel.WhooshPitch, reelTime)
	-- the server checks the range from here and keeps the fish for us
	Net.Action:FireServer("Grab", locked)
end

-- Space: off the fish (or from floating) into the hop. In the hop: onto the locked fish; with none, nothing.
local function request(): boolean
	local j = Config.Jump
	if flying then
		local _, root = State.character()
		if
			os.clock() - startedAt < j.Window + leapTime
			and clock >= j.MinFlight
			and not reeling
			and not asked
			and root
		then
			if
				locked
				and saddleOf(locked)
				and ((locked.PrimaryPart :: BasePart).Position - root.Position).Magnitude <= reach
			then
				startReel(root)
			else
				State.NoTargetAt = os.clock()
			end
		elseif reeling or asked then
			mashing = true
		end
		pressedAt = os.clock()
		return true
	end
	local pressedBefore = pressedAt
	pressedAt = os.clock()
	local mode = State.Mode
	local _, root = State.character()
	if (mode ~= "Riding" and mode ~= "Free") or not root then
		return false
	end
	if os.clock() < State.JumpReadyAt then
		return false
	end
	-- The second hook (Hugo, 2026-11-12; reproduced by script, docs/design/riding-feel.md): Space mashed through a
	-- landing threw us off the fish we had just reached (the first press after Cooldown) and onto the next one (the
	-- press after that). So a run of presses that began DURING the pull-in (where a press can do nothing) can't hop:
	-- it ends at the first gap of Jump.HopGuard between presses (or Jump.MashMost after the landing, whatever the
	-- keys do). A chain of hops made on purpose, one press to grab and the next after the landing, never starts such
	-- a run, and leaves at Cooldown exactly as before.
	if mashing and mode == "Riding" and j.HopGuard > 0 then
		if os.clock() - pressedBefore < j.HopGuard and os.clock() - State.MountedAt < j.MashMost then
			return false
		end
	end
	mashing = false
	local fish = State.Fish
	local fishRoot = fish and fish.PrimaryPart
	local leaping = false
	if mode == "Riding" and fish and fishRoot then
		yaw = yawOf(fishRoot.CFrame.LookVector)
		-- the hop's numbers by the speed the fish had as we left it and by its kind (Config.hopFrom: the share
		-- of that speed kept and the kick, airtime by speed, a Leaper's higher and longer hop; the server counts the same)
		local kind = Config.FishById[fish:GetAttribute("FishType") :: string]
		launchSpeed, leapTime, leapApex = Config.hopFrom(
			fishRoot.AssemblyLinearVelocity.Magnitude,
			kind,
			if kind then Config.riddenOf(fish, kind) else nil
		)
		local higher, _, longer = Config.hopOf(kind)
		leaping = higher > 1 or longer > 0
		left = fish
		RideController.leave()
	else
		yaw = State.Heading
		launchSpeed, leapTime, leapApex = Config.hopFrom(nil, nil, nil)
		left = nil
	end
	flatSpeed = launchSpeed
	reach = Config.reachOf(flatSpeed)
	State.Reach = reach
	WallRide.reset(wall)
	faced = yaw
	autoAt = 0
	Course.begin()
	position = root.Position
	baseY = position.Y
	-- the top of the glide, kept under the surface
	topY = math.max(baseY, math.min(baseY + j.Apex * leapApex + j.FloatRise, Config.Oxygen.SurfaceY - j.Ceiling))
	clock = 0
	startedAt = os.clock()
	resumeHeight = 0
	roll = 0
	reeling = false
	asked = false
	flying = true
	State.Heading = yaw
	State.WindowLeft = j.Window + leapTime
	State.JumpPhase = "Pop"
	-- (the fish locked while we rode stays locked: now with the full glow)
	setGlow(locked)
	-- the push off: the view kicks wider, bubbles are kicked off where we left, a swish
	local f = Config.Feel
	local leap = leaping
	local af = Config.ArchetypeFeel
	State.FovPunch = f.PopFov + (if leap then af.LeapFov else 0)
	local bubbles = f.PopBurst + (if leap then af.LeapBubbles else 0)
	if bubbles > 0 then
		Fx.burst(position - Vector3.new(0, 1.5, 0), bubbles, 0, if leap then 7 else 4)
	end
	Feel.sound("Swish", f.Swish * (if leap then 1.4 else 1), if leap then 1.15 else 1.5, 0.35)
	if leap then
		State.Leapt:Fire()
	end
	Net.Action:FireServer("Jump")
	State.setMode("Jumping")
	return true
end

-- The hop's height at its clock: up through the pop, the last of the rise through the glide, and all the while less
-- what we have fallen, which is by the speed lost (Config.hopSink: Jump.FallSpeed, SinkCurve): next to nothing while
-- we are fast, a fall once the speed has nearly gone. One curve: nothing is switched on
local function heightAt(t: number): number
	local j = Config.Jump
	local rise = topY - baseY
	local apex = j.Apex * leapApex
	local floatTime = j.FloatTime + leapTime
	local whole = apex + j.FloatRise
	local popShare = if whole > 0 then apex / whole else 1
	local sunk = Config.hopSink(t, leapTime)
	if t < j.LaunchTime then
		return baseY + rise * popShare * Ease.outQuad(t / math.max(j.LaunchTime, 0.01)) - sunk
	end
	local glide = math.min(t - j.LaunchTime, floatTime)
	return baseY + rise * (popShare + (1 - popShare) * Ease.outQuad(glide / math.max(floatTime, 0.01))) - sunk
end

-- And its speed forward: most of the fish's speed and a kick as we leave, easing off slowly, then running out in a
-- long gentle tail to a stop: Config.hopSpeed, the curve the server counts the hook's reach by
local function speedAt(t: number): number
	return Config.hopSpeed(t, launchSpeed, leapTime)
end

local function resumeSwim(root: BasePart)
	Net.Action:FireServer("CancelGrab")
	reeling = false
	asked = false
	State.Reeling = false
	State.FovPunch = 0
	Feel.trail(root, false)
	clock = os.clock() - startedAt
	position = root.Position
	resumeHeight = position.Y - heightAt(clock)
	refused = locked
	refusedUntil = os.clock() + Config.Jump.RefusedTime
	-- (and the hands-off pull-in doesn't take ANOTHER fish the very next frame: the second hook. A press still does.)
	autoAt = os.clock() + Config.Jump.RehookGuard
	locked = nil
	State.JumpTarget = nil
	setGlow(nil)
end

local function hop(dt: number)
	-- the glow leaving the fish we landed on
	local landedAt = glowLandedAt
	if landedAt then
		local u = (os.clock() - landedAt) / Config.Jump.GlowFade
		if u >= 1 then
			setGlow(nil)
		else
			-- a white flash at the landing, through yellow, and off
			glow.FillColor = WHITE:Lerp(Config.Jump.GlowFill, math.min(1, u * 3))
			glow.FillTransparency = Ease.lerp(0.1, 1, u)
			glow.OutlineTransparency = u
		end
	end
	fadeDots()
	local _, root = State.character()
	if not flying then
		-- still on a fish, or floating: the lock shows already (fainter), so we see what we could reach before leaving
		local mode = State.Mode
		if root and Config.Lock.Preview > 0 and (mode == "Riding" or mode == "Free") then
			if not glowLandedAt then
				-- (the reach a hop from here would begin with)
				local fish = State.Fish
				local fishRoot = if mode == "Riding" and fish then fish.PrimaryPart else nil
				if fish and fishRoot then
					local kind = Config.FishById[fish:GetAttribute("FishType") :: string]
					local launch = Config.hopFrom(
						fishRoot.AssemblyLinearVelocity.Magnitude,
						kind,
						if kind then Config.riddenOf(fish, kind) else nil
					)
					reach = Config.reachOf(launch)
				else
					reach = Config.reachOf((Config.hopFrom(nil, nil, nil)))
				end
				pick(root.Position)
			end
		elseif locked then
			locked = nil
			State.JumpTarget = nil
			if not glowLandedAt then
				setGlow(nil)
			end
		end
		return
	end
	if not root then
		stop()
		if State.Mode == "Jumping" then
			State.setMode("Free")
		end
		return
	end
	local j = Config.Jump
	local saddle: CFrame? = saddleOf(locked)

	clock = os.clock() - startedAt
	local window = j.Window + leapTime
	State.WindowLeft = math.max(0, window - clock)
	local dropAt = j.LaunchTime + j.FloatTime + leapTime
	State.JumpPhase = if clock < j.LaunchTime then "Pop" elseif clock < dropAt then "Glide" else "Drop"

	if asked then
		-- holding on the saddle until the server mounts us (or doesn't answer)
		if saddle then
			root.CFrame = saddle
			local fishRoot = (locked :: Model).PrimaryPart
			root.AssemblyLinearVelocity = if fishRoot then fishRoot.AssemblyLinearVelocity else Vector3.zero
			root.AssemblyAngularVelocity = Vector3.zero
		end
		if os.clock() - askedAt > j.AckTime or not saddle then
			resumeSwim(root)
		end
		return
	end

	if reeling then
		local me = State.Player.UserId
		local keptFor = locked and locked:GetAttribute("Reserved")
		local taken = locked and (locked:GetAttribute("Rider") ~= 0 or (keptFor ~= 0 and keptFor ~= me))
		if not saddle or taken then
			-- the fish went from under us, or someone else got it: back to the hop, with what is left of the window
			resumeSwim(root)
		else
			-- Ease the normalized pull before shaping its acceleration: creep, pull, then soften onto the saddle.
			-- Keeping the offset relative to the moving saddle carries us forward throughout the pull.
			local u = math.clamp((os.clock() - reelStartedAt) / reelTime, 0, 1)
			local progress = Ease.inOutSine(u)
			local closed = progress ^ j.ReelCurve
			-- the height closes later than the rest (ReelSwoop): we hold our height, then swoop down onto it
			local sunk = progress ^ (j.ReelCurve + j.ReelSwoop)
			local at = saddle.Position
				+ Vector3.new(reelOffset.X * (1 - closed), reelOffset.Y * (1 - sunk), reelOffset.Z * (1 - closed))
			-- head first along the line, turning to sit as we arrive
			local toSaddle = saddle.Position - at
			local headFirst = if toSaddle.Magnitude > 0.5
				then CFrame.lookAt(at, at + toSaddle) * CFrame.Angles(-math.rad(j.ReelTip), 0, 0)
				else CFrame.new(at) * saddle.Rotation
			local turned = (CFrame.new(at) * reelFrom.Rotation):Lerp(headFirst, Ease.smoothstep(0, j.ReelTurnEnd, u))
			local body = turned:Lerp(CFrame.new(at) * saddle.Rotation, Ease.smoothstep(j.ReelSitStart, 1, u))
			-- our speed from where we put ourselves last frame (the physics moves the root a little in between)
			local was = position
			root.CFrame = body
			-- the view narrows as it speeds up (the reference's zoom in), and dots are left behind us
			State.FovPunch = j.ReelFov * u ^ j.ReelFovCurve
			dropDot(at)
			-- speed lines, more of them as it speeds up, and bubbles left behind us
			Feel.rush(Config.Feel.ReelLines * u ^ 1.5)
			Feel.trail(root, true)
			root.AssemblyLinearVelocity = (body.Position - was) / math.max(dt, 1e-6)
			root.AssemblyAngularVelocity = Vector3.zero
			position = body.Position
			State.Speed = root.AssemblyLinearVelocity.Magnitude
			if u >= 1 then
				asked = true
				askedAt = os.clock()
				touchedAt = askedAt
				State.Reeling = false
				-- the landing, at once on our side: the view snaps wider and settles, the camera is knocked down and
				-- springs back, and it is shaken, a little harder after a faster pull-in
				State.FovPunch = j.LandFov
				State.KickVelocity = j.LandKick * 2 * math.pi * j.LandKickRate
				local pull = reelOffset.Magnitude / math.max(reelTime, 0.01)
				local by = 1 + j.LandShakeBySpeed * (pull - j.LandShakeAt) / math.max(j.LandShakeAt, 1)
				RideController.shake(j.LandShake * math.clamp(by, 0.5, 1.6))
				-- and bubbles thrown out round the fish, with a splash
				local f = Config.Feel
				Feel.trail(root, false)
				Feel.sound("Splash", f.Splash, 1.1, 0.6)
				if f.SplashCount > 0 then
					Fx.burst(saddle.Position, f.SplashCount, 0, f.SplashReach)
				end
				Net.Action:FireServer("Land", locked)
			end
			return
		end
	end

	-- the hop rises above the fish we look at, if that is higher than where we left: there is always a swoop down
	local over = math.max(baseY, if saddle then saddle.Position.Y else -math.huge)
	local top = math.max(baseY, math.min(over + j.Apex * leapApex + j.FloatRise, Config.Oxygen.SurfaceY - j.Ceiling))
	if top > topY then
		topY = Ease.lerp(topY, top, Ease.alpha(6, dt))
	end

	-- we always go forward, steered exactly as a fish is (RideController.steer: to where the camera looks, which A and D
	-- turn; with Ride.CameraSteer off, A and D only); the lock is the fish we are looking at
	-- never into the sea floor, a rock or a bank, nor out of the lane: stopped at walls, skimming over what is under
	-- us. Substep the whole elapsed frame: dropping time makes low-FPS players fly and steer slower while their
	-- window keeps running at wall-clock speed.
	local was = position
	local steps = math.max(1, math.ceil(dt / 0.05))
	local h = dt / steps
	for i = 1, steps do
		local t = math.max(0, clock - dt + i * h)
		local before = yaw
		yaw = RideController.steer(yaw, h)
		local from = position
		-- the wall ride (Config.Wall, Lib/WallRide): steered at a wall or the lane's edge we are turned along it from
		-- Wall.Look seconds ahead, keeping our speed but for a share by how square on; dead straight in, we slow
		-- into it and the swing lifts us and lets us down again
		local pace = speedAt(math.max(0, t - h / 2))
		local way, kept = WallRide.step(wall, position, (before + yaw) / 2, pace, 3, 1.5, h)
		local velocity = way * (pace * kept)
		local height = heightAt(t) + resumeHeight
		if wall.Lift ~= 0 then
			height = math.min(height + wall.Lift, math.max(height, Config.Oxygen.SurfaceY - j.Ceiling))
		end
		local want = Vector3.new(position.X + velocity.X * h, height, position.Z + velocity.Z * h)
		position = Course.clearMove(position, want, j.FloorClearance)
		if i == steps then
			-- the speed we really have across the water (a wall takes some; the fall adds none): the hook's reach
			flatSpeed = ((position - from) * Vector3.new(1, 0, 1)).Magnitude / math.max(h, 1e-6)
			faced = Ease.lerpAngle(faced, Ease.lerpAngle(yaw, yawOf(way), wall.Slide), Ease.alpha(12, dt))
		end
	end
	State.Heading = yaw
	State.Wall = WallRide.state(wall)
	State.WallSide = if wall.Touch then (if wall.Lean >= 0 then 1 else -1) else 0
	-- the hook's reach, by that speed: longest as we leave, shrinking as we slow to the stop
	reach = Config.reachOf(flatSpeed)
	State.Reach = reach
	pick(position)

	-- upright off the fish for a moment, then lying flat, face down, swimming through the glide (as the reference's
	-- rider does), nosing down in the drop, and rolling into a turn as a fish does
	local tip = math.rad(j.Tilt) * Ease.smoothstep(j.LaunchTime * j.TiltFrom, j.LaunchTime * j.TiltTo, clock)
		+ math.rad(j.DropTilt) * Ease.smoothstep(dropAt, dropAt + math.max(j.DropTiltTime, 0.01), clock)
	roll = Ease.lerp(roll, RideController.lean() * math.rad(j.Bank), Ease.alpha(Config.Ride.BankEase, dt))
	root.CFrame = CFrame.new(position)
		* CFrame.fromOrientation(0, faced, 0)
		* CFrame.Angles(0, 0, roll + wall.Lean * math.rad(Config.Wall.Lean))
		* CFrame.Angles(-tip, 0, 0)
	root.AssemblyLinearVelocity = (position - was) / math.max(dt, 1e-6)
	root.AssemblyAngularVelocity = Vector3.zero
	State.Speed = speedAt(clock) * wall.Kept * wall.Slide
	-- while most of the leaving speed is still there: speed lines that thin out as it goes (none under RUSH_KEEP of
	-- it), and bubbles left behind us
	local boost = math.clamp((Config.hopKept(clock, leapTime) - RUSH_KEEP) / (1 - RUSH_KEEP), 0, 1)
	if boost > 0.05 then
		Feel.rush(Config.Feel.PopLines * boost)
	end
	Feel.trail(root, boost > 0.05)

	-- The reference's hands-off landing (Jump.AutoGrab 2): when the glide is over the locked fish pulls us in by
	-- itself, about 1.7 s after the press; with none locked then, the first fish locked in the drop does. A press still
	-- grabs sooner.
	if j.AutoGrab >= 2 and clock >= dropAt and clock < window and os.clock() >= autoAt then
		local targetRoot = locked and locked.PrimaryPart
		if targetRoot and saddleOf(locked) and (targetRoot.Position - position).Magnitude <= reach then
			startReel(root)
			return
		end
	end

	if clock >= window then
		if j.AutoGrab > 0 and locked and saddleOf(locked) then
			-- (the old hands-off landing, when switched on: the locked fish is grabbed without a press)
			startReel(root)
		else
			-- the drop is over, the window gone with no fish grabbed: sunk
			Net.Action:FireServer("Miss")
			stop()
			State.setMode("Free") -- for the moment until the server's word (the drown)
		end
	end
end

local function step(dt: number)
	hop(dt)
	placeRing(dt)
	Feel.step(dt)
end

function JumpController.Init()
	Actions.jump = request

	ringFolder = Instance.new("Folder")
	ringFolder.Name = "JumpRing"
	for _ = 1, DASHES do
		local dash = Instance.new("Part")
		dash.Anchored = true
		dash.CanCollide = false
		dash.CanQuery = false
		dash.CanTouch = false
		dash.CastShadow = false
		dash.Material = Enum.Material.Neon
		dash.Color = Config.Jump.Glow
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
		dot.Color = Config.Jump.DotGlow
		dot.Transparency = 1
		dot.Size = Vector3.new(1.1, 1.1, 1.1)
		dot.Parent = trailFolder
		trailDots[i] = dot
		trailBorn[i] = -math.huge
	end

	glow = Instance.new("Highlight")
	glow.Name = "JumpGlow"
	glow.FillColor = Config.Jump.GlowFill
	glow.OutlineColor = Config.Jump.GlowOutline
	glow.DepthMode = Enum.HighlightDepthMode.Occluded
	glow.Enabled = false
	glow.Parent = workspace.CurrentCamera

	Net.Ride.OnClientEvent:Connect(function(kind: string, a: any, _reason: any, about: any)
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
			-- The wait between fish: only the gap from the touch to this word, with which the landing animation starts
			-- on every machine (Jump.Cooldown is the least it counts as, from the touch). From here a fresh press hops
			-- at once, cutting the landing short. A mount that was no landing of ours (the sandbox's seat) has no touch.
			State.JumpReadyAt = math.max(os.clock(), touchedAt + Config.Jump.Cooldown)
			-- (but not off a fish too strong for us: the server holds that hop back for Jump.StrainLock, the bar)
			-- (the sandbox's endless air: no fish is too strong there, as the server has it)
			local endless = workspace:GetAttribute("SandboxEndlessAir") == true
			if not endless and typeof(a) == "Instance" and a:IsA("Model") and State.tooStrong(a) then
				State.JumpReadyAt = os.clock() + Config.Jump.StrainLock
			end
		elseif kind == "Denied" and a == "Jump" then
			if flying then
				stop()
				if not RideController.rejoin() then
					State.setMode("Free")
				end
			end
		elseif kind == "Denied" and a == "Grab" then
			-- the server wouldn't give us that fish (too far, or taken): back to the hop, with what is left of the
			-- window, and that fish isn't locked again for a moment
			-- (unless it is about another fish: a late refusal for the last fish we asked for must not stop a pull-in
			-- already begun on the next)
			local _, root = State.character()
			local other = typeof(about) == "Instance" and locked ~= nil and about ~= locked
			if flying and (reeling or asked) and root and not other then
				resumeSwim(root)
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
