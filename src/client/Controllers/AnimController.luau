--!strict
-- Procedural animation, no uploaded animations: every fish's swim (a modelled creature's keyed cycle, or a
-- placeholder's tail beat, sway and fin flaps), faster the faster it swims, and the buck when it throws its rider off;
-- and every rider's pose by their State (astride while riding, the pop, the strokes of the glide and the drop, the
-- pull-in, treading water while floating, flailing, weakening and going limp as they drown), with a squash on landing.
-- On top of a modelled creature's keyed cycle sit the layers of Config.Animation, all seen only: they turn or shift
-- joints, never the Root, so the Saddle, the lock, the pull-in and the server's checks are untouched. First built
-- 2026-11-11 (docs/design/animation-study.md), then worked over with the user in the Swim Lab preview and carried
-- here 2026-11-12:
--   effort: the swing rises when the fish speeds up or fights, and eases when it coasts; the beat hardly changes;
--   the turn layer: the head leads into a turn, the tail joints trail and come round late, wild fish bank, and the
--     side fins tilt, sweep and row, each body type in its own mix (Shared/RideStyles.Fins);
--   the body layer: one shift of the whole body about the Root (the first joint carries it): the heave, nod, sway and
--     rock of its style each beat (less on a small fish and a quick beat), the buck, a crash's flinch;
--   the slow wave (RideStyles.Waves): every few seconds the stroke widens, the body rises, drifts to a side and
--     leans, all on one rhythm that swells and fades. Nothing starts or stops;
--   the landing: the dip at the touch, then a wild reaction (startle, buck, thrash, bolt, wobble, shudder, barrel
--     roll; RideStyles.Landings, Animation.LandingMix) that builds quickly from the touch and falls off over two
--     seconds. Each client picks it from the rider's id and their count of landings, so all see the same one;
--   a jaw that hangs and opens now and then instead of chomping every beat.
-- The rider sits on the body's shift EASED and in part (Animation.RiderCalm), so they ride the slow motions and are
-- spared the quick ones; they brace at a landing, are thrown off the seat by a buck, and flail while the animal fights.
-- Not here, because they need the Root to move (RideController, the server): the wave's small change of speed, the
-- bolt's burst of speed, the surge waiting for the build-up. Not here, because FishModel welds them: eyes that look
-- about.
-- The startle (Config.Ride.Startle...; Hugo, 2026-11-12): with it on, every landing gets ONE reaction, on every
-- creature and on a stand-in: the fish rears like a horse (nose up in a jerk, shaking, its tail thrashing, a "!" over
-- its head: Lib/Feel), the rider braced against its back; then its nose dips and it bolts, the rider thrown back. The
-- stall and the burst of speed are RideController's, on the same clock. With it off, the mix above.
-- The rider (Config.Pose; Hugo, 2026-11-12): a front crawl through a hop's glide and drop and a slow breaststroke while
-- floating, the body flat; the dash: a crouch and a push off the fish, streamlined with the arms ahead through the
-- pull-in, then a tuck and a forward flip into the seat; riding: astride, leaning forward with speed and into turns.
-- Poses are written once, in the body's own directions, and carried into each joint's own (R15's joints have no turn
-- of their own, R6's do), so they work on any avatar; R6 has no knees, elbows or waist and simply lacks those bends.
-- Set in PreSimulation, after the Animator, so the poses win: every joint of the avatar is written each frame (those a
-- pose doesn't name are held at rest), and our own character's animation tracks are stopped as they start while we are
-- in the water, so Roblox's Animate script never shows through. No tables are made per frame for the fish.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Config = require(game:GetService("ReplicatedStorage").Shared.Config)
local Creatures = require(game:GetService("ReplicatedStorage").Shared.Creatures)
local Ease = require(game:GetService("ReplicatedStorage").Shared.Ease)
local Net = require(game:GetService("ReplicatedStorage").Shared.Net)
local RideStyles = require(game:GetService("ReplicatedStorage").Shared.RideStyles)
local Feel = require(script.Parent.Parent.Lib.Feel)
local State = require(script.Parent.Parent.Lib.State)
local JumpController = require(script.Parent.JumpController)
local RideController = require(script.Parent.RideController)

local AnimController = {}

-- A modelled creature's joints (FishModel's "Rig_<part>"), each with its turns through one swim cycle. `bend` is its
-- place in the turn layer: 1 on the chain to the head, -1 on the chain to the tail, 0 elsewhere.
-- `side` marks a side fin (the first part off the centre line: a fin, a flipper, a wing, a leg): -1 left, 1 right.
type RigJoint = { motor: Motor6D, frames: { CFrame }, bend: number, jaw: boolean, side: number }
type FishJoints = {
	at: number, -- os.clock() it was last moved: its own step is the time since (a far fish is moved less often)
	turn: number, -- which frame of two or three it is moved on
	sway: Motor6D?,
	tail: Motor6D?,
	finL: Motor6D?,
	finR: Motor6D?,
	phase: number,
	rig: { RigJoint }?,
	body: Motor6D?, -- the first part's joint: the whole body hangs from it
	bodyKeyed: boolean, -- and whether the keyed cycle turns it too
	bodyC0: CFrame,
	bodyC0Inverse: CFrame,
	pace: number,
	style: RideStyles.Style?,
	effort: number,
	speedWas: number,
	gain: number, -- how fast it is speeding up, studs a second each second, smoothed
	turnFast: number, -- its turn rate, radians a second, smoothed a little (the head) and a lot (the tail)
	turnSlow: number,
	headJoints: number,
	tailJoints: number,
	seed: number,
	shift: CFrame?, -- this frame's shift of the whole body, in the Root's space
	beatPace: number, -- the beat's size rule, which stops sooner than `pace` so small fish don't buzz
	rate: number, -- beats a second now (it changes over a moment, never at once)
	length: number,
	small: number, -- how much of the wave a fish this size shows (a small one about half)
	girth: number, -- its length against a mid-sized animal's, for moves measured in studs
	wave: RideStyles.Wave?,
	wavePhase: number,
	liftWas: number,
	noseWave: number,
	fins: RideStyles.Fins?,
	-- what the animal is doing to its rider this frame, and the eased shift the rider sits on
	air: number,
	flail: number,
	leanBack: number,
	brace: number, -- the startle: how hard the rider holds on, 0 to 1,
	thrown: number, -- and how far the bolt throws them back, degrees
	riderUp: number,
	riderNose: number,
	riderSwing: number,
	riderRoll: number,
	mount: CFrame?,
}
local fishJoints: { [Model]: FishJoints } = setmetatable({}, { __mode = "k" }) :: any
local landedOn: { [Model]: number } = setmetatable({}, { __mode = "k" }) :: any -- fish -> os.clock() a rider landed on it
local ridden: { [number]: Model } = {} -- this frame: UserId -> the fish they ride (only fish near the camera)
local spines: { [string]: { [string]: number } } = {} -- creature Id -> part -> its place in the turn layer
-- a landing's reaction: which, to which side, how far through its jolts
type Landing = { kind: string, sign: number, phase: number }
local reactOn: { [Model]: Landing } = setmetatable({}, { __mode = "k" }) :: any
local landings: { [number]: number } = {} -- UserId -> landings counted here (it seeds the pick)
local TAU = math.pi * 2
local REST = CFrame.new()
local rad = math.rad
-- a rider's root part is never further than this from the Root of the fish under them (the biggest creature's seat is
-- well inside it): further, and the fish is not the one we sit on
local MOUNT_REACH = 40
local JOLTS = { startle = 2.4, buck = 1.5, thrash = 2.2, bolt = 2.8, wobble = 1.4, shudder = 0.9, barrel = 1.6 }

-- A reaction through time: 0 until `start`, up to 1 at `peak` (quickly, from the first moment: the user wanted no
-- wait and no jolt), held for `hold`, and down to 0 at `finish`, dropping fast and leaving a thin tail
local function shape(t: number, start: number, peak: number, hold: number, finish: number): number
	local rise = math.clamp((t - start) / (peak - start), 0, 1)
	local fall = math.clamp((t - peak - hold) / (finish - peak - hold), 0, 1)
	return rise ^ 1.25 * (1 - fall) ^ 2
end

-- The startle (Config.Ride.Startle...): what a fish does about a landing, `t` seconds after the touch. It rears (the
-- nose up in a jerk, past its mark and back, the body lifted and pulled back so it turns about its tail, not its
-- middle), shakes while it is up, comes down and dips its nose just before StartleTime, and lunges as it bolts.
-- Fills `startled`; false once it is all over. Seen only: the stall and the burst of speed are RideController's.
local startled = {
	up = 0,
	fore = 0,
	nose = 0,
	roll = 0,
	swing = 0,
	whip = 0,
	effort = 0,
	brace = 0,
	thrown = 0,
}
local function startle(t: number, length: number, girth: number): boolean
	local r = Config.Ride
	local hold = math.max(r.StartleTime, 0.1)
	local b = t - hold
	if b > 1.3 then
		return false
	end
	local q = t / hold
	-- (a big creature rears a little less far)
	local most = r.StartleRear * Ease.lerp(1, 0.6, math.clamp((length - 12) / 40, 0, 1))
	local jerk = math.clamp((q - 0.06) / 0.16, 0, 1)
	local reared = (1 - (1 - jerk) ^ 3) * (1 + 0.22 * math.sin(jerk * math.pi)) * (1 - Ease.smoothstep(0.74, 1, q))
	local coil = Ease.smoothstep(0.8, 1, q) * (1 - Ease.smoothstep(0, 0.12, b))
	local lunge = if b > 0 then shape(b, 0, 0.1, 0.08, 0.9) else 0
	local shaking = reared * (1 - 0.45 * math.min(q, 1))
	local beat = t * TAU * r.StartleShakeRate
	startled.nose = most * reared - r.StartleCoil * coil + 5 * lunge
	startled.roll = r.StartleShake * shaking * math.sin(beat)
	startled.swing = r.StartleShake * 0.6 * shaking * math.sin(beat * 0.5 + 1)
	startled.up = math.sin(rad(most * reared)) * length * 0.16 - 0.03 * length * coil
	startled.fore = -0.05 * length * reared + r.StartleLunge * girth * lunge
	startled.whip = rad(8) * shaking * math.sin(beat * 0.5)
	startled.effort = 1.1 * shaking + (if b > 0 then 1.4 * shape(b, 0, 0.08, 0.3, 1.2) else 0)
	startled.brace = math.max(math.min(reared, 1), coil)
	startled.thrown = 30 * lunge
	return true
end

local JOINTS = {
	"Root",
	"LeftHip",
	"RightHip",
	"LeftKnee",
	"RightKnee",
	"LeftShoulder",
	"RightShoulder",
	"LeftElbow",
	"RightElbow",
	"Waist",
	"Neck",
}
-- the same joints on an R6 avatar (it has no knees, elbows or waist)
local R6: { [string]: string } = {
	Root = "RootJoint",
	LeftHip = "Left Hip",
	RightHip = "Right Hip",
	LeftShoulder = "Left Shoulder",
	RightShoulder = "Right Shoulder",
}
type RiderJoints = {
	motors: { [string]: Motor6D },
	turns: { [string]: CFrame }, -- a joint's own turn at rest, where it has one: poses are carried into it
	rest: { Motor6D }, -- the avatar's other joints
	current: { [string]: CFrame },
	state: string, -- the state it is posed for, and since when
	since: number,
	phase: number, -- the swimming stroke's clock, radians
	lean: number,
}
local riderJoints: { [Model]: RiderJoints } = setmetatable({}, { __mode = "k" }) :: any

local function rot(x: number, y: number, z: number): CFrame
	return CFrame.Angles(rad(x), rad(y), rad(z))
end

-- A joint by its name: a Motor6D, or on an avatar with Roblox's newer joints an AnimationConstraint, which stands in
-- for one (the same Transform, C0 and Part0), so it is handed back as one. (Found 2026-11-12: Hugo's avatar has only
-- AnimationConstraints, and with Motor6Ds alone looked for, no rider pose had ever shown on it.)
local function joint(model: Model, name: string): Motor6D?
	local found = model:FindFirstChild(name, true)
	if found and (found:IsA("Motor6D") or found:IsA("AnimationConstraint")) then
		return (found :: any) :: Motor6D
	end
	return nil
end

-- Which of a creature's parts bend in a turn (worked out once a kind): the chain from its first part back to the
-- rearmost part on the centre line bends against the turn (-1), the chain forward to the frontmost leads into it (1).
-- Jaws are left out: they hang from the head and go with it.
local function spineOf(id: string, rig: Creatures.Rig): { [string]: number }
	local made = spines[id]
	if made then
		return made
	end
	local out: { [string]: number } = {}
	local parentOf: { [string]: string } = {}
	local alongOf: { [string]: number } = {}
	local first = rig.Parts[1][1] :: string
	local centre = 0.05 * rig.Size[1] + 0.05
	local rear: string? = nil
	local front: string? = nil
	for _, row in rig.Parts do
		local name = row[1] :: string
		parentOf[name] = row[2] :: string
		alongOf[name] = row[5] :: number
		if name ~= first and math.abs(row[3] :: number) < centre and not string.find(name, "Jaw") then
			if not rear or alongOf[name] > alongOf[rear] then
				rear = name
			end
			if not front or alongOf[name] < alongOf[front] then
				front = name
			end
		end
	end
	local function mark(from: string, sign: number)
		local name = from
		for _ = 1, 64 do
			if name == "" or name == first or not parentOf[name] then
				break
			end
			if out[name] == nil then
				out[name] = sign
			end
			name = parentOf[name]
		end
	end
	-- (the head is toward -Z: a part behind the first one has the larger z)
	if rear and alongOf[rear] > alongOf[first] then
		mark(rear, -1)
	end
	if front and alongOf[front] < alongOf[first] then
		mark(front, 1)
	end
	spines[id] = out
	return out
end

-- The fish to animate: kept from the folder's ChildAdded and ChildRemoved, not read from it every frame
local fishSeen: { [Model]: boolean } = {}
local fishFolder: Instance? = nil
-- a model whose joints had not all arrived: when it was first tried, and when to try again
local arrivingSince: { [Model]: number } = setmetatable({}, { __mode = "k" }) :: any
local retryAt: { [Model]: number } = setmetatable({}, { __mode = "k" }) :: any

local function watch(folder: Instance)
	fishFolder = folder
	table.clear(fishSeen)
	for _, child in folder:GetChildren() do
		if child:IsA("Model") then
			fishSeen[child] = true
		end
	end
	folder.ChildAdded:Connect(function(child)
		if child:IsA("Model") then
			fishSeen[child] = true
		end
	end)
	folder.ChildRemoved:Connect(function(child)
		fishSeen[child :: any] = nil
	end)
end

-- Whether a fish is moved this frame. What it costs is a write to every joint, so: never beyond 450 studs; never
-- behind the camera (with its own length of grace); and a far one only every second frame (past 150 studs) or third
-- (past 300), which its own clock makes up for. The fish we ride is always moved.
local function due(model: Model, j: FishJoints?, offset: Vector3, away: number, look: Vector3): boolean
	if away >= 450 then
		return false
	end
	if model == State.Fish then
		return true
	end
	if offset:Dot(look) < -(if j then j.length else 20) then
		return false
	end
	if j then
		local every = if away > 300 then 3 elseif away > 150 then 2 else 1
		j.turn = (j.turn + 1) % every
		return j.turn == 0
	end
	return true
end

-- The rider's mount on a fish: the body's shift eased and in part, so they ride the slow motions (the wave, the dip, a
-- buck) and are spared the quick ones. RiderCalm 0 follows the body exactly; a braced rider (the startle) goes with
-- the rearing whole. A barrel roll carries them round whole.
local function seat(
	j: FishJoints,
	isRidden: boolean,
	up: number,
	nose: number,
	yaw: number,
	roll: number,
	fore: number,
	spin: number,
	dt: number
)
	local a = Config.Animation
	if isRidden and a.RiderFollow > 0 then
		local calm = math.clamp(a.RiderCalm, 0, 1)
		local share = Ease.lerp(Ease.lerp(1, 0.5, calm), 1, j.brace)
		local ease = Ease.alpha(if j.brace > 0.05 then 30 else Ease.lerp(60, 7, calm), dt)
		j.riderUp = Ease.lerp(j.riderUp, up, Ease.alpha(Ease.lerp(60, 12, calm), dt))
		j.riderNose = Ease.lerp(j.riderNose, nose * share, ease)
		j.riderSwing = Ease.lerp(j.riderSwing, yaw * share, ease)
		j.riderRoll = Ease.lerp(j.riderRoll, roll * share, ease)
		j.mount = CFrame.new(0, j.riderUp + j.air, -fore) * rot(j.riderNose, j.riderSwing, j.riderRoll + spin)
	else
		j.riderUp, j.riderNose, j.riderSwing, j.riderRoll = 0, 0, 0, 0
		j.mount = nil
	end
end

local function animateFish()
	local folder = workspace:FindFirstChild("Fish")
	if not folder then
		return
	end
	if folder ~= fishFolder then
		watch(folder)
	end
	table.clear(ridden)
	local now = os.clock()
	local a = Config.Animation
	local view = workspace.CurrentCamera.CFrame
	local cameraAt, look = view.Position, view.LookVector
	for model in fishSeen do
		local root = model.PrimaryPart
		if root then
			local offset = root.Position - cameraAt
			local away = offset.Magnitude
			local j = fishJoints[model]
			if due(model, j, offset, away, look) then
				if not j then
					local again = retryAt[model]
					if again and now < again then
						continue
					end
					j = {
						sway = joint(model, "SwayJoint"),
						tail = joint(model, "TailJoint"),
						finL = joint(model, "FinL"),
						finR = joint(model, "FinR"),
						phase = math.random() * 10,
						rig = nil,
						body = nil,
						bodyKeyed = false,
						bodyC0 = CFrame.identity,
						bodyC0Inverse = CFrame.identity,
						pace = 1,
						style = nil,
						effort = 1,
						speedWas = root.AssemblyLinearVelocity.Magnitude,
						gain = 0,
						turnFast = 0,
						turnSlow = 0,
						headJoints = 0,
						tailJoints = 0,
						seed = math.random() * 100,
						shift = nil,
						beatPace = 1,
						rate = 0,
						length = 14,
						small = 1,
						girth = 1,
						wave = nil,
						wavePhase = math.random() * 50,
						liftWas = 0,
						noseWave = 0,
						fins = nil,
						air = 0,
						flail = 0,
						leanBack = 0,
						brace = 0,
						thrown = 0,
						riderUp = 0,
						riderNose = 0,
						riderSwing = 0,
						riderRoll = 0,
						mount = nil,
						at = now,
						turn = math.random(0, 2),
					}
					local id = model:GetAttribute("Rig")
					local rig = if type(id) == "string" then Creatures.get(id) else nil
					local swim = if rig then Creatures.swim(id :: string) else nil
					if rig and swim then
						local spine = spineOf(id :: string, rig)
						-- the side fins: the first part off the centre line on each side, not its own tips
						local across: { [string]: number } = {}
						local parentOf: { [string]: string } = {}
						local centre = 0.05 * rig.Size[1] + 0.05
						for _, row in rig.Parts do
							across[row[1] :: string] = row[3] :: number
							parentOf[row[1] :: string] = row[2] :: string
						end
						local function sideOf(part: string): number
							local x = across[part] or 0
							if math.abs(x) > centre and math.abs(across[parentOf[part]] or 0) <= centre then
								return math.sign(x)
							end
							return 0
						end
						local first = rig.Parts[1][1] :: string
						local list: { RigJoint } = {}
						for part, frames in swim do
							local motor = joint(model, "Rig_" .. part)
							if motor then
								local bend = spine[part] or 0
								if bend > 0 then
									j.headJoints += 1
								elseif bend < 0 then
									j.tailJoints += 1
								end
								table.insert(list, {
									motor = motor,
									frames = frames,
									bend = bend,
									jaw = string.find(part, "Jaw") ~= nil,
									side = sideOf(part),
								})
								if part == first then
									j.bodyKeyed = true
								end
							end
						end
						local found, keyed = #list, 0
						for _ in swim do
							keyed += 1
						end
						-- side fins the keyed swim never moves still answer a turn
						for _, row in rig.Parts do
							local part = row[1] :: string
							if not swim[part] and sideOf(part) ~= 0 then
								local motor = joint(model, "Rig_" .. part)
								if motor then
									table.insert(list, {
										motor = motor,
										frames = { CFrame.identity },
										bend = 0,
										jaw = false,
										side = sideOf(part),
									})
								end
							end
						end
						j.rig = list
						local body = joint(model, "Rig_" .. first)
						j.body = body
						if not body or found < keyed then
							-- The model is still arriving: its parts can come over more than one frame, and a set of joints found
							-- too soon was kept for good (a fish that swam stiff, or without the landing's dip). Don't keep it:
							-- try again shortly, for five seconds; after that make do, and say so.
							local since = arrivingSince[model] or now
							arrivingSince[model] = since
							if now - since < 5 then
								retryAt[model] = now + 0.2
								continue
							end
							warn(
								string.format(
									"[AnimController] %s: %d of %d swim joints found%s",
									id :: string,
									found,
									keyed,
									if body then "" else ", and no body joint"
								)
							)
						end
						arrivingSince[model] = nil
						retryAt[model] = nil
						if body then
							j.bodyC0 = body.C0
							j.bodyC0Inverse = body.C0:Inverse()
						end
						j.style = RideStyles.of(id :: string)
						j.wave = RideStyles.waveOf(id :: string)
						j.fins = RideStyles.finsOf(id :: string)
						-- a big creature beats slower than a small one
						local kind = Config.FishById[id :: string]
						local length = if kind then Config.bodyOf(model, kind).Z else 14
						j.pace = math.clamp(14 / length, 0.4, 1.3)
						j.beatPace = math.clamp(14 / length, 0.4, 1.1)
						j.length = length
						j.small = Ease.lerp(0.55, 1, math.clamp((length - 10) / 25, 0, 1))
						j.girth = math.clamp(length / 14, 0.6, 2.2)
					else
						-- a stand-in: its whole body hangs from the sway joint, which takes the startle's shift
						local kind = Config.FishById[model:GetAttribute("FishType") :: string]
						j.length = if kind then Config.bodyOf(model, kind).Z else 14
						j.girth = math.clamp(j.length / 14, 0.6, 2.2)
						if j.sway then
							j.bodyC0 = j.sway.C0
							j.bodyC0Inverse = j.sway.C0:Inverse()
						end
					end
					fishJoints[model] = j
				end
				-- this fish's own step: the time since it was last moved. One that was out of view starts afresh, so the time
				-- away doesn't read as a burst of speed.
				local gap = now - j.at
				j.at = now
				local dt = math.min(gap, 0.1)
				local speed = root.AssemblyLinearVelocity.Magnitude
				if gap > 0.3 then
					j.speedWas = speed
					j.gain = 0
				end
				-- the buck: nose up hard, down, up again, rolling, the tail thrashing
				local buck = 0
				local bucked = State.Buck[model]
				if bucked then
					local u = (os.clock() - bucked) / Config.Death.Throw
					if u >= 1.4 then
						State.Buck[model] = nil
					else
						buck = math.clamp(1.4 - u, 0, 1)
					end
				end
				local rig = j.rig
				if rig then
					local style = j.style
					local wave, fins = j.wave, j.fins
					local length = j.length
					local riderId = model:GetAttribute("Rider")
					local isRidden = type(riderId) == "number" and riderId ~= 0
					if isRidden then
						ridden[riderId :: number] = model
					end
					local landedAt = landedOn[model]
					local sinceLand = if landedAt then now - landedAt else math.huge
					local yawRate = rad(math.max(Config.Ride.YawRate, 1))

					-- its turn, quick for the head and the fins' tilt, late for the tail and the fins' sweep
					local turning = root.AssemblyAngularVelocity.Y
					j.turnFast = Ease.lerp(j.turnFast, turning, Ease.alpha(8, dt))
					j.turnSlow = Ease.lerp(j.turnSlow, turning, Ease.alpha(2.5, dt))

					-- The landing's reaction: what a wild animal does when a rider drops onto it. It builds from the touch (quickly,
					-- not at once), jolts, and falls off; the tail starts first, the body peaks next, the rider flails last and
					-- longest; the jolts quicken toward the peak. A big animal takes longer over it.
					local rxUp, rxNose, rxSwing, rxRoll, rxSpin, rxEffort, rxWhip, rxFore = 0, 0, 0, 0, 0, 0, 0, 0
					local air, flail, leanBack = 0, 0, 0
					local react = reactOn[model]
					j.brace, j.thrown = 0, 0
					if react and landedAt and react.kind == "rear" then
						if startle(sinceLand, length, j.girth) then
							rxUp, rxNose, rxSwing, rxRoll = startled.up, startled.nose, startled.swing, startled.roll
							rxFore, rxWhip, rxEffort = startled.fore, startled.whip, startled.effort
							j.brace, j.thrown = startled.brace, startled.thrown
						else
							reactOn[model] = nil
						end
					elseif react and landedAt and a.Wild > 0 then
						local slow = Ease.lerp(1.25, 1.1, math.clamp((j.pace - 0.4) / 0.9, 0, 1))
						local t = sinceLand / slow
						if t > 3.3 then
							reactOn[model] = nil
						else
							-- a small fish fights less hard, a mid-sized one hardest, a giant slowly and less
							local w = a.Wild
								* (
									if length < 25
										then Ease.lerp(0.7, 0.9, math.clamp((length - 10) / 15, 0, 1))
										else Ease.lerp(0.9, 0.7, math.clamp((length - 25) / 20, 0, 1))
								)
							local kind, s = react.kind, react.sign
							local long = if kind == "shudder"
								then 2.4
								elseif kind == "wobble" then 2.2
								elseif kind == "startle" then 1.5
								else 1.9
							local bodyNow = shape(t, 0, 0.26, 0.08, long)
							local tailNow = shape(t, 0, 0.18, 0.15, long - 0.3)
							local riderNow = shape(t, 0.02, 0.34, 0.15, long + 0.2)
							react.phase += dt * TAU * (JOLTS[kind] or 2) * (0.8 + 0.2 * bodyNow) / slow
							local b = react.phase
							if kind == "startle" then
								rxNose = 18 * w * bodyNow * math.sin(b)
								rxRoll = s * 14 * w * bodyNow * math.sin(b * 0.8 + 1)
								rxUp = 0.6 * w * bodyNow * math.sin(b * 0.9)
								rxEffort = 0.9 * w * tailNow
								flail = 0.55 * w * riderNow
							elseif kind == "buck" then
								rxNose = 32 * w * bodyNow * math.sin(b - 0.5)
								rxUp = 1.2 * w * bodyNow * math.sin(b - 1.1)
								rxRoll = s * 8 * w * bodyNow * math.sin(b * 0.65)
								rxEffort = 0.6 * w * tailNow
								air = 1.3 * w * bodyNow * math.max(0, math.sin(b - 1.9)) ^ 1.5
								flail = w * riderNow
							elseif kind == "thrash" then
								rxSwing = 26 * w * bodyNow * math.sin(b)
								rxRoll = s * 13 * w * bodyNow * math.cos(b)
								rxWhip = rad(7) * w * tailNow * math.sin(b + 1.6)
								rxEffort = w * tailNow
								flail = 0.8 * w * riderNow
								leanBack = 10 * w * bodyNow * math.sin(b)
							elseif kind == "bolt" then
								-- (seen only: the body lunges ahead of its Root; the real burst of speed would be RideController's)
								rxFore = 1.0 * w * j.girth * shape(t, 0, 0.28, 0.12, 1.8)
								rxNose = 7 * w * bodyNow
								rxSwing = 5 * w * bodyNow * math.sin(b)
								rxEffort = 1.3 * w * tailNow
								leanBack = 36 * w * shape(t, 0, 0.26, 0.1, 1.5)
								flail = 0.6 * w * riderNow
							elseif kind == "wobble" then
								rxRoll = s * 30 * w * bodyNow * math.sin(b)
								rxUp = -0.9 * w * bodyNow * math.cos(b)
								rxSwing = 6 * w * bodyNow * math.sin(b * 0.5)
								rxEffort = 0.4 * w * tailNow
								flail = 0.6 * w * riderNow
							elseif kind == "shudder" then
								local heavy = shape(t, 0, 0.38, 0.15, long)
								rxRoll = s * 8 * w * heavy * math.sin(b)
								rxUp = -1.3 * w * heavy * math.cos(b * 0.9)
								rxNose = -5 * w * heavy * math.sin(b)
								rxEffort = 0.5 * w * tailNow
								flail = 0.35 * w * riderNow
							elseif kind == "barrel" then
								-- it winds up the other way, rolls right over in a second, and rocks as it settles
								local u = math.clamp((t - 0.15) / 0.9, 0, 1)
								local over = if u < 0.5 then 2 * u * u else 1 - (-2 * u + 2) ^ 2 / 2
								local wind = Ease.smoothstep(0, 0.12, t) * (1 - Ease.smoothstep(0.12, 0.28, t))
								local after = shape(t, 1.05, 1.17, 0.05, 2.0)
								rxSpin = if u < 1 then s * 360 * over else 0
								rxRoll = s * (-12 * w * wind + 7 * w * after * math.sin((t - 1.05) * TAU * 1.6))
								rxUp = -0.6 * w * bodyNow
								rxEffort = 0.8 * w * tailNow
								flail = w * riderNow
							end
						end
					end
					j.air, j.flail, j.leanBack = air, flail, leanBack

					-- The slow wave: one rhythm, every part of it a fixed step behind the last. Quiet while a landing plays out on a
					-- ridden fish and while it turns hard, so it never fights the rider.
					local waveEffort, waveBeat, lift, drift, lean = 0, 1, 0, 0, 0
					if wave and a.Wave > 0 then
						local slow = Ease.lerp(1.3, 0.9, math.clamp((j.pace - 0.4) / 0.9, 0, 1))
						j.wavePhase += dt * TAU / (wave.T * slow) * (1 + 0.08 * math.sin(now * 0.11 + j.seed))
						local calm = 1 - 0.7 * math.min(1, math.abs(j.turnFast) / yawRate)
						if isRidden then
							calm *= Ease.smoothstep(0.9, 2.0, sinceLand)
						end
						local ph = j.wavePhase
						local amount = a.Wave * calm * j.small * (0.75 + 0.25 * math.sin(ph / 4))
						local push = math.sin(ph + wave.Skew * math.sin(ph))
						waveEffort = wave.Effort * amount * push
						waveBeat = 1 + wave.Beat * amount * push
						lift = wave.Lift * j.girth * amount * math.sin(ph - 1.5)
						drift = wave.Side * amount * math.sin(ph / 2)
						lean = wave.Lean * amount * math.sin(ph / 2 + 0.6)
					end
					-- the nose follows the way the body is really going, up or down
					local climb = (lift - j.liftWas) / math.max(dt, 1e-3)
					j.liftWas = lift
					j.noseWave =
						Ease.lerp(j.noseWave, math.deg(math.atan2(climb, math.max(speed, 8))), Ease.alpha(10, dt))

					-- effort: working harder as it speeds up, takes a rider or fights, easing as it coasts
					j.gain = Ease.lerp(j.gain, (speed - j.speedWas) / math.max(dt, 1e-3), Ease.alpha(4, dt))
					j.speedWas = speed
					local want = 1
					if a.Effort > 0 then
						want = math.clamp(1 + j.gain * a.EffortAccel, 0.6, 1.5)
						if sinceLand < a.LandEffortTime then
							-- (with a wild landing most of the kick comes in the build-up: only some at the touch)
							want += a.LandEffort * (if react then 0.5 else 1) * (1 - sinceLand / math.max(
								a.LandEffortTime,
								0.01
							))
						end
						want = Ease.lerp(1, want, math.min(a.Effort, 1))
					end
					want = math.max(0.5, want + rxEffort + waveEffort)
					j.effort = Ease.lerp(j.effort, want, Ease.alpha(if rxEffort > 0 then 10 else 8, dt))
					local effort = j.effort

					-- the beat: by speed and length, by the style's cadence, a little with effort and the wave, and never changing at once
					local cadence = if style then Ease.lerp(1, style.Cadence, math.clamp(a.Cadence, 0, 1)) else 1
					local rate = math.max(
						0,
						(0.5 + speed * 0.03 + buck * 2)
							* j.beatPace
							* cadence
							* (1 + (effort - 1) * a.EffortBeat)
							* waveBeat
					)
					j.rate = if j.rate > 0
						then Ease.lerp(j.rate, rate, Ease.alpha(if buck > 0 then 12 else 4, dt))
						else rate
					j.phase += dt * TAU * j.rate
					local u = (j.phase / TAU) % 1

					-- the turn layer: the head leads, the tail trails
					local headBend, tailBend, lead = 0, 0, 0
					if a.Turn > 0 then
						local most, total = rad(a.TurnMax), rad(a.TurnTotal)
						if j.headJoints > 0 then
							local cap = math.min(most, total / j.headJoints)
							headBend = math.clamp(j.turnFast * a.TurnLead, -cap, cap) * a.Turn
						else
							-- most creatures' first part IS the head, with no joint of its own to lead with: the whole body is turned a
							-- little ahead instead (in the body's shift, below), and the tail bends back
							lead = math.clamp(j.turnFast * a.TurnLead, -most, most) * a.Turn
						end
						if j.tailJoints > 0 then
							local cap = math.min(most, total / j.tailJoints)
							tailBend = -math.clamp(j.turnSlow * a.TurnBend, -cap, cap) * a.Turn
						end
					end
					if rxWhip ~= 0 then
						tailBend += rxWhip
						headBend -= rxWhip
					end
					-- the side fins in a turn (a left turn is positive; the right side is +1)
					local finTurn = if fins then a.FinTurn * math.min(a.Turn, 1) else 0
					local turnQuick = math.clamp(j.turnFast / yawRate, -1, 1) * finTurn
					local turnLate = math.clamp(j.turnSlow / yawRate, -1, 1) * finTurn
					-- a jaw hangs nearly shut and opens now and then (and at a landing or a buck), not every beat
					local jawOpen = 1
					if a.Jaw > 0 and buck <= 0 and sinceLand > 1 then
						jawOpen = 0.15 + 0.85 * math.max(0, math.sin(now * 0.8 + j.seed)) ^ 4
					end

					-- every joint through its keyed turns, between the two nearest moments, with the layers on top
					local swing = math.min(effort, 2.3)
					for _, r in rig do
						local count = #r.frames
						local at = u * count
						local i = math.floor(at)
						local turn = if count > 1
							then r.frames[i % count + 1]:Lerp(r.frames[(i + 1) % count + 1], at - i)
							else r.frames[1]
						local scale = if r.jaw then jawOpen else swing
						if fins and r.side ~= 0 and finTurn > 0 then
							-- the outer fin strokes wider, the inner one less
							scale *= 1 + fins.Row * turnQuick * r.side
						end
						if count > 1 and math.abs(scale - 1) > 0.03 then
							local axis, angle = turn:ToAxisAngle()
							turn = CFrame.fromAxisAngle(axis, angle * scale)
						end
						if r.bend ~= 0 then
							local bend = if r.bend > 0 then headBend else tailBend
							if math.abs(bend) > 0.002 then
								turn = CFrame.Angles(0, bend, 0) * turn
							end
						end
						if fins and r.side ~= 0 and finTurn > 0 then
							-- both fins tilt the way the body banks (the inner one down) and swing round: the inner one back, the
							-- outer one forward
							if math.abs(turnQuick) > 0.01 then
								turn = CFrame.Angles(0, 0, rad(fins.Tilt) * turnQuick) * turn
							end
							if math.abs(turnLate) > 0.01 then
								turn = CFrame.Angles(0, rad(fins.Sweep) * turnLate, 0) * turn
							end
						end
						r.motor.Transform = turn
					end

					-- the body layer: one shift of the whole body about the Root (up, forward, nose, yaw, roll)
					local up, nose, yaw, roll =
						lift + rxUp, j.noseWave + rxNose, math.deg(lead) + drift + rxSwing, lean + rxRoll
					if style and a.Body > 0 then
						-- (a quick beat with a full sway is a shake: the faster the beat and the smaller the fish, the less of it)
						local amount = a.Body
							* math.clamp(1.6 / math.max(j.rate, 0.1), 0.45, 1)
							* Ease.lerp(0.45, 1, math.clamp((length - 10) / 25, 0, 1))
						local s = math.sin(j.phase)
						up += style.Heave * s * amount
						nose += style.Nod * math.cos(j.phase) * amount
						yaw += style.Sway * s * amount
						roll += style.Rock * math.sin(j.phase + 1) * amount
					end
					if bucked and buck > 0 then
						-- the buck: nose up hard, down, up again, rolling
						local t = (now - bucked) / Config.Death.Throw
						nose += 40 * math.sin(t * math.pi * 3) * buck
						roll += 18 * math.sin(t * math.pi * 4.5) * buck
					end
					if a.LandDip > 0 and sinceLand < a.LandDipTime then
						-- the landing's touch: it sinks under the rider and springs back. It swings in from where it was (deepest at
						-- 0.09 s), and never goes deeper than a tenth of its length
						local spring = 1.86 * math.exp(-sinceLand * 6) * math.sin(sinceLand * 13)
						local deep = (if style then style.Dip else 1) * j.pace
						up -= math.min(a.LandDip * deep, 0.09 * length) * spring
						nose -= a.LandNod * math.min(deep, 1) * spring
					end
					if a.CrashFlinch > 0 and model == State.Fish then
						local since = now - State.CrashAt
						if since < 0.5 then
							local k = (1 - since / 0.5) * a.CrashFlinch
							nose += 40 * math.sin(since * math.pi * 6) * k
							roll += 18 * math.sin(since * math.pi * 9) * k
						end
					end
					if a.WildBank > 0 and not isRidden then
						local most = rad(a.WildBankMax)
						roll += math.deg(math.clamp(j.turnFast * a.WildBank, -most, most))
					end
					local body = j.body
					local shift: CFrame? = nil
					if
						math.abs(up) > 0.005
						or math.abs(rxFore) > 0.005
						or math.abs(nose) + math.abs(yaw) + math.abs(roll) + math.abs(rxSpin) > 0.05
					then
						shift = CFrame.new(0, up, -rxFore) * rot(nose, yaw, roll + rxSpin)
					end
					j.shift = shift
					if body then
						-- (written afresh every frame, keyed or not: the buck used to pile up on a first part with no keys)
						local keyed = if j.bodyKeyed then body.Transform else CFrame.identity
						body.Transform = if shift then j.bodyC0Inverse * shift * j.bodyC0 * keyed else keyed
					end
					seat(j, isRidden, up, nose, yaw, roll, rxFore, rxSpin, dt)
					continue
				end
				-- A stand-in (no modelled creature here): the tail beat, the sway and the fin flaps; and the landing: the
				-- touch's dip, then the startle, as one shift of its whole body about the Root
				local riderId = model:GetAttribute("Rider")
				local isRidden = type(riderId) == "number" and riderId ~= 0
				if isRidden then
					ridden[riderId :: number] = model
				end
				local landedAt = landedOn[model]
				local sinceLand = if landedAt then now - landedAt else math.huge
				local up, fore, nose, roll, swing, whip, effort = 0, 0, 0, 0, 0, 0, 0
				j.brace, j.thrown = 0, 0
				local react = reactOn[model]
				if react and landedAt and react.kind == "rear" then
					if startle(sinceLand, j.length, j.girth) then
						up, fore, nose, roll, swing =
							startled.up, startled.fore, startled.nose, startled.roll, startled.swing
						whip, effort = math.deg(startled.whip), startled.effort
						j.brace, j.thrown = startled.brace, startled.thrown
					else
						reactOn[model] = nil
					end
				end
				if a.LandDip > 0 and sinceLand < a.LandDipTime then
					local spring = 1.86 * math.exp(-sinceLand * 6) * math.sin(sinceLand * 13)
					up -= math.min(a.LandDip, 0.09 * j.length) * spring
					nose -= a.LandNod * spring
				end
				j.phase += dt * math.pi * 2 * (0.7 + speed * 0.045 + buck * 2.5 + effort * 1.6)
				local beat = math.sin(j.phase)
				local amount = 18 + math.min(speed, 80) * 0.12 + buck * 14 + effort * 12
				if j.tail then
					j.tail.Transform = rot(0, beat * amount + whip * 2, 0)
				end
				if j.sway then
					local sway = rot(0, math.sin(j.phase - 1.2) * amount * 0.22, 0)
					if bucked and buck > 0 then
						local u = (os.clock() - bucked) / Config.Death.Throw
						nose += 40 * math.sin(u * math.pi * 3) * buck
						roll += 18 * math.sin(u * math.pi * 4.5) * buck
					end
					if
						math.abs(up) + math.abs(fore) > 0.005
						or math.abs(nose) + math.abs(roll) + math.abs(swing) > 0.05
					then
						sway = j.bodyC0Inverse * CFrame.new(0, up, -fore) * rot(nose, swing, roll) * j.bodyC0 * sway
					end
					j.sway.Transform = sway
				end
				seat(j, isRidden, up, nose, swing, roll, fore, 0, dt)
				local flap = math.sin(j.phase * 0.5) * 18
				if j.finL then
					j.finL.Transform = rot(0, 0, -flap)
				end
				if j.finR then
					j.finR.Transform = rot(0, 0, flap)
				end
			end
		end
	end
end

-- Drowning by its phases (DeathController's timings): the throw, struggling, weaker, still
local function drowning(since: number, thrown: boolean, struggle: number, t: number): { [string]: CFrame }
	local c = Config.Death
	local tt = since - (if thrown then c.Throw else 0)
	if tt < 0 then
		-- flung: splayed out, arms and legs wide
		return {
			LeftShoulder = rot(40, 0, -110),
			RightShoulder = rot(40, 0, 110),
			LeftHip = rot(-20, 0, -35),
			RightHip = rot(-20, 0, 35),
			LeftKnee = rot(-30, 0, 0),
			RightKnee = rot(-30, 0, 0),
			Neck = rot(-25, 0, 0),
		}
	end
	local weak = Ease.smoothstep(struggle, struggle + c.Weak, tt)
	local limp = Ease.smoothstep(struggle + c.Weak * 0.5, struggle + c.Weak + c.Still, tt)
	local energy = (1 - weak * 0.7) * (1 - limp)
	local f = Ease.lerp(9, 3, weak) -- flailing slows as they weaken
	local a = math.sin(t * f)
	local b = math.sin(t * f * 1.3 + 1)
	-- limp: arms float up and out, legs hang, head back
	local floatArm = 70 * limp
	return {
		LeftShoulder = rot(60 + a * 70 * energy + floatArm, 0, -60 - b * 40 * energy - 30 * limp),
		RightShoulder = rot(60 - a * 70 * energy + floatArm, 0, 60 + b * 40 * energy + 30 * limp),
		LeftElbow = rot(30 + b * 40 * energy, 0, 0),
		RightElbow = rot(30 - b * 40 * energy, 0, 0),
		LeftHip = rot(20 + b * 45 * energy, 0, -8),
		RightHip = rot(20 - b * 45 * energy, 0, 8),
		LeftKnee = rot(-30 - math.abs(a) * 40 * energy - 15 * limp, 0, 0),
		RightKnee = rot(-30 - math.abs(b) * 40 * energy - 15 * limp, 0, 0),
		Waist = rot(-10 * limp + a * 8 * energy, 0, 0),
		Neck = rot(-20 - 25 * limp + b * 15 * energy, 0, 0),
	}
end

-- A pose: a turn for each joint it names, in the body's own directions (x: forward and back, + is back or up; y: the
-- twist; z: sideways). Joints it doesn't name stay at rest.
type Pose = { [string]: CFrame }

-- Two poses run together: `w` of `b` over `a`
local function blend(a: Pose, b: Pose, w: number): Pose
	if w <= 0 then
		return a
	elseif w >= 1 then
		return b
	end
	local out: Pose = {}
	for name, turn in a do
		out[name] = turn:Lerp(b[name] or CFrame.identity, w)
	end
	for name, turn in b do
		if not a[name] then
			out[name] = REST:Lerp(turn, w)
		end
	end
	return out
end

-- Streamlined: arms together out ahead, legs straight behind with a quick small kick, head up to look where we go
local function streamlined(t: number, flutter: number): Pose
	local kick = math.sin(t * 30) * flutter
	return {
		LeftShoulder = rot(172, 0, -6),
		RightShoulder = rot(172, 0, 6),
		LeftElbow = rot(4, 0, 0),
		RightElbow = rot(4, 0, 0),
		LeftHip = rot(-8 + kick, 0, -3),
		RightHip = rot(-8 - kick, 0, 3),
		LeftKnee = rot(-6 - math.max(0, kick), 0, 0),
		RightKnee = rot(-6 - math.max(0, -kick), 0, 0),
		Waist = rot(4, 0, 0),
		Neck = rot(30, 0, 0),
	}
end

-- The crouch before the push off a fish: knees up, curled forward, arms swung back
local function crouched(): Pose
	return {
		LeftHip = rot(85, 0, -12),
		RightHip = rot(85, 0, 12),
		LeftKnee = rot(-115, 0, 0),
		RightKnee = rot(-115, 0, 0),
		LeftShoulder = rot(-35, 0, -12),
		RightShoulder = rot(-35, 0, 12),
		LeftElbow = rot(20, 0, 0),
		RightElbow = rot(20, 0, 0),
		Waist = rot(-22, 0, 0),
		Neck = rot(10, 0, 0),
	}
end

-- The tuck of the flip: knees to the chest, arms round them, chin in
local function tucked(): Pose
	return {
		LeftHip = rot(110, 0, -8),
		RightHip = rot(110, 0, 8),
		LeftKnee = rot(-125, 0, 0),
		RightKnee = rot(-125, 0, 0),
		LeftShoulder = rot(70, 0, 10),
		RightShoulder = rot(70, 0, -10),
		LeftElbow = rot(80, 0, 0),
		RightElbow = rot(80, 0, 0),
		Waist = rot(-28, 0, 0),
		Neck = rot(-18, 0, 0),
	}
end

-- A front crawl, the body flat (the hop's own tilt lays it down): each arm reaches ahead, pulls down under the body
-- and back, and comes forward again over the top with the elbow bent, one half a stroke behind the other; the body
-- rolls to each stroke; the legs kick in turn. `phase` is the stroke's, `kicks` the kick's, both in radians.
local function crawl(phase: number, kicks: number, hard: boolean): Pose
	local function arm(at: number): (number, number)
		local a = at % TAU
		return 180 - math.deg(a), if a > math.pi then 12 + 65 * math.sin(a - math.pi) else 12 + 18 * math.sin(a)
	end
	local leftArm, leftElbow = arm(phase)
	local rightArm, rightElbow = arm(phase + math.pi)
	local roll = Config.Pose.CrawlRoll * math.sin(phase)
	local kick = math.sin(kicks) * (if hard then 26 else 20)
	return {
		Root = rot(0, roll, 0),
		LeftShoulder = rot(leftArm, 0, -6),
		RightShoulder = rot(rightArm, 0, 6),
		LeftElbow = rot(leftElbow, 0, 0),
		RightElbow = rot(rightElbow, 0, 0),
		LeftHip = rot(-4 + kick, 0, -4),
		RightHip = rot(-4 - kick, 0, 4),
		LeftKnee = rot(-8 - math.max(0, kick) * 0.9, 0, 0),
		RightKnee = rot(-8 - math.max(0, -kick) * 0.9, 0, 0),
		Waist = rot(3, 0, 0),
		Neck = rot(26, -roll * 0.7, 0),
	}
end

-- A slow breaststroke for floating, the body laid forward by Pose.FloatTilt: a glide with the arms out ahead, the pull
-- (arms sweeping out to the sides and back), the tuck (hands in under the chest, knees drawn up and out), and the
-- thrust (arms shot forward, legs snapped straight). `cycle` is 0 to 1 through one stroke.
local function breaststroke(cycle: number): Pose
	local pull = Ease.smoothstep(0.3, 0.55, cycle) * (1 - Ease.smoothstep(0.55, 0.76, cycle))
	local tuck = Ease.smoothstep(0.5, 0.74, cycle) * (1 - Ease.smoothstep(0.78, 0.98, cycle))
	local arm = 170 - 90 * pull - 110 * tuck
	local out = 6 + 70 * pull + 4 * tuck
	local elbow = 5 + 35 * pull + 115 * tuck
	local knee = -(8 + 95 * tuck)
	return {
		Root = CFrame.new(0, 0.2 * math.sin(cycle * TAU), 0) * rot(-Config.Pose.FloatTilt + 6 * tuck, 0, 0),
		LeftShoulder = rot(arm, 0, -out),
		RightShoulder = rot(arm, 0, out),
		LeftElbow = rot(elbow, 0, 0),
		RightElbow = rot(elbow, 0, 0),
		LeftHip = rot(-5 + 50 * tuck, 0, -4 - 28 * tuck),
		RightHip = rot(-5 + 50 * tuck, 0, 4 + 28 * tuck),
		LeftKnee = rot(knee, 0, 0),
		RightKnee = rot(knee, 0, 0),
		Waist = rot(4 - 8 * tuck, 0, 0),
		Neck = rot(Config.Pose.FloatTilt * 0.45 - 10 * tuck, 0, 0),
	}
end

-- Astride the fish. `pace` is its speed as a share of its ridden speed (the rider leans forward over it as it goes
-- faster), `lean` how hard it turns, -1 to 1 (they lean into the turn), `brace` the startle's hold (curled forward
-- against the rearing, arms round its back, trembling), `thrown` how far the bolt throws them back, degrees.
local function astride(t: number, pace: number, lean: number, brace: number, thrown: number): Pose
	local p = Config.Pose
	local bob = math.sin(t * 6) * 3
	local crouch = Ease.smoothstep(0.55, 1.3, pace) * (1 - brace)
	local forward = p.RideCrouch * crouch + p.BraceLean * brace
	local torso = 12 * (1 - crouch) * (1 - brace) + thrown - forward -- (+ is leaning back)
	local side = p.RideLean * lean
	local tremble = brace * math.sin(t * 38) * 2.5
	local arm = 52 + bob + 0.8 * forward - 0.5 * thrown
	local elbow = math.max(4, 30 + 25 * brace - thrown)
	local knee = -85 - 10 * crouch - 15 * brace
	return {
		LeftHip = rot(72, 0, -30),
		RightHip = rot(72, 0, 30),
		LeftKnee = rot(knee, 0, 0),
		RightKnee = rot(knee, 0, 0),
		LeftShoulder = rot(arm + tremble, 0, 10),
		RightShoulder = rot(arm - tremble, 0, -10),
		LeftElbow = rot(elbow, 0, 0),
		RightElbow = rot(elbow, 0, 0),
		Waist = rot(torso, 0, side),
		Neck = rot(-torso * 0.8, 0, -side * 0.5),
	}
end

-- The dash onto a fish, `u` of the way through a pull-in that takes `time` seconds: streamlined, then (from
-- Pose.FlipStart) a tuck and a forward flip that ends, the right way up, in the seat
local function dash(t: number, u: number, time: number): Pose
	local p = Config.Pose
	local from = math.clamp(p.FlipStart, 0, 0.9)
	local out = blend(streamlined(t, 7), astride(t, 0, 0, 0, 0), Ease.smoothstep(0.82, 1, u))
	local turns = math.floor(p.Flip + 0.5)
	if turns <= 0 or time < p.FlipMin then
		return out
	end
	out = blend(out, tucked(), Ease.smoothstep(from, from + 0.2, u) * (1 - Ease.smoothstep(0.86, 1, u)))
	out.Root = rot(-360 * turns * Ease.smoothstep(from, 0.97, u), 0, 0)
	return out
end

-- The pose for a state at a time
local function pose(j: RiderJoints, state: string, t: number, dt: number, player: Player): Pose
	local p = Config.Pose
	local mine = player == State.Player
	local since = os.clock() - j.since
	if state == "Riding" then
		local fish = ridden[player.UserId]
		local fj = if fish then fishJoints[fish] else nil
		local fishRoot = fish and fish.PrimaryPart
		local pace, lean = 1, 0
		if fish and fishRoot then
			local kind = Config.FishById[fish:GetAttribute("FishType") :: string]
			pace = fishRoot.AssemblyLinearVelocity.Magnitude
				/ math.max(if kind then Config.riddenOf(fish, kind) else 45, 1)
			lean = if mine
				then RideController.lean()
				else math.clamp(fishRoot.AssemblyAngularVelocity.Y / rad(math.max(Config.Ride.YawRate, 1)), -1, 1)
		end
		j.lean = Ease.lerp(j.lean, lean, Ease.alpha(6, dt))
		return astride(t, pace, j.lean, if fj then fj.brace else 0, if fj then fj.thrown else 0)
	elseif state == "Jumping" then
		-- our own hop says which part of it this is; another player's is told from how long ago it began and how fast
		-- they are going (a pull-in is far faster than a glide)
		local phase: string? = nil
		if mine then
			phase = State.JumpPhase
		else
			local _, root = nil, player.Character and player.Character:FindFirstChild("HumanoidRootPart")
			local speed = if root and root:IsA("BasePart") then root.AssemblyLinearVelocity.Magnitude else 0
			phase = if since < Config.Jump.LaunchTime then "Pop" elseif speed > 115 then "Dash" else "Glide"
		end
		if phase == "Pop" then
			-- off the fish: a crouch for a moment, then the push, arms thrown out ahead
			return if since < p.PopTuck then crouched() else streamlined(t, 0)
		elseif phase == "Dash" then
			return streamlined(t, 7)
		end
		j.phase += dt * TAU * p.CrawlRate
		return crawl(j.phase, t * TAU * p.CrawlKick, phase == "Drop")
	elseif state == "Reeling" then
		local u, time = JumpController.reel()
		return dash(t, u or 1, time)
	elseif state == "Drowning" then
		local started = State.DeathStart[player]
		return drowning(
			if started then os.clock() - started else 0,
			State.DeathThrown[player] == true,
			State.DeathStruggle[player] or Config.Death.Struggle,
			t
		)
	elseif state == "Free" then
		j.phase += dt * TAU * p.BreastRate
		return breaststroke((j.phase / TAU) % 1)
	end
	return {}
end

-- A character's joints, found once: the ones the poses name (by their R15 names; an R6 avatar's by its own), each with
-- the turn of its own it must be carried into, and every other joint of the avatar, to be held at rest
local function jointsOf(character: Model): RiderJoints
	local motors: { [string]: Motor6D } = {}
	local turns: { [string]: CFrame } = {}
	local posed: { [Motor6D]: boolean } = {}
	for _, name in JOINTS do
		local m = joint(character, name) or (if R6[name] then joint(character, R6[name]) else nil)
		if m then
			motors[name] = m
			posed[m] = true
			local turn = m.C0.Rotation
			if not turn:FuzzyEq(CFrame.identity, 1e-3) then
				turns[name] = turn
			end
		end
	end
	local rest: { Motor6D } = {}
	for _, d in character:GetDescendants() do
		if (d:IsA("Motor6D") or d:IsA("AnimationConstraint")) and not posed[d :: any] then
			table.insert(rest, (d :: any) :: Motor6D)
		end
	end
	return {
		motors = motors,
		turns = turns,
		rest = rest,
		current = {},
		state = "",
		since = os.clock(),
		phase = 0,
		lean = 0,
	}
end

local function animateRider(player: Player, character: Model, state: string, dt: number, t: number)
	local j = riderJoints[character]
	if not j then
		j = jointsOf(character)
		riderJoints[character] = j
	end
	if j.state ~= state then
		j.state = state
		j.since = os.clock()
	end
	local goal = pose(j, state, t, dt, player)
	-- the landing squash: down and forward, springing back with a little overshoot
	local landed = State.Squash[character]
	if landed then
		local since = os.clock() - landed
		if since < 0.45 then
			local s = 1.75 * math.exp(-since * 9) * math.sin(since * 22) -- it swings in from nothing: no snap at the touch
			goal.Root = CFrame.new(0, -0.9 * s, 0) * rot(-14 * s, 0, 0)
			-- and the brace: arms thrown up and knees folded as we hit the saddle, then the grab
			local brace = math.min(Config.Animation.Brace, 0.45)
			if state == "Riding" and brace > 0 and since < brace then
				local hold = brace * 0.3
				local k = if since < hold then 1 else 1 - (since - hold) / (brace - hold)
				k *= k
				goal.LeftShoulder = (goal.LeftShoulder or CFrame.identity):Lerp(rot(150, 0, -20), k)
				goal.RightShoulder = (goal.RightShoulder or CFrame.identity):Lerp(rot(150, 0, 20), k)
				goal.LeftElbow = (goal.LeftElbow or CFrame.identity):Lerp(rot(10, 0, 0), k)
				goal.RightElbow = (goal.RightElbow or CFrame.identity):Lerp(rot(10, 0, 0), k)
				goal.LeftKnee = (goal.LeftKnee or CFrame.identity):Lerp(rot(-105, 0, 0), k)
				goal.RightKnee = (goal.RightKnee or CFrame.identity):Lerp(rot(-105, 0, 0), k)
			end
		else
			State.Squash[character] = nil
		end
	end
	-- on a fish, the rider goes with its body: the eased shift the fish worked out this frame (the wave, the landing's
	-- dip, the rearing, a buck), about the fish's Root, so they stay on the back without being shaken
	local mount: CFrame? = nil
	if state == "Riding" then
		local fish = ridden[player.UserId]
		local fj = if fish then fishJoints[fish] else nil
		local fishRoot = fish and fish.PrimaryPart
		local rootMotor = j.motors.Root
		local seated = rootMotor and rootMotor.Part0
		-- Only when that fish is really under us. For a few frames round a mount or a sandbox reset the fish this
		-- names can be one we are no longer on, or not on yet, a long way off: the shift is taken about ITS Root, so
		-- the body was thrown that far from our own root part, and the weight of it swung the whole of us and the fish
		-- away at over 1,000 studs a second (seen 2026-11-12: 5,800 studs under the map).
		if
			fj
			and fj.mount
			and fishRoot
			and rootMotor
			and seated
			and (fishRoot.Position - seated.Position).Magnitude < MOUNT_REACH
		then
			-- (in the joint's own directions already: it is taken about the joint as it stands)
			local from = seated.CFrame * rootMotor.C0
			local base = fishRoot.CFrame
			mount = from:Inverse() * base * fj.mount * base:Inverse() * from
		end
		if fj and (fj.flail > 0.02 or math.abs(fj.leanBack) > 0.5) then
			-- while the animal fights: arms and legs flung about, and thrown back by a bolt
			local f, now = fj.flail, os.clock()
			local reach = f * 25 * (0.5 + 0.5 * math.sin(now * 8))
			goal.LeftShoulder = (goal.LeftShoulder or CFrame.identity) * rot(f * 38 * math.sin(now * 11), 0, -reach)
			goal.RightShoulder = (goal.RightShoulder or CFrame.identity)
				* rot(f * 38 * math.sin(now * 11 + 2.1), 0, reach)
			goal.LeftHip = (goal.LeftHip or CFrame.identity) * rot(f * 18 * math.sin(now * 9), 0, 0)
			goal.RightHip = (goal.RightHip or CFrame.identity) * rot(f * 18 * math.sin(now * 9 + 3), 0, 0)
			goal.Waist = (goal.Waist or CFrame.identity) * rot(-fj.leanBack * 0.7, 0, 0)
		end
	end
	local a = Ease.alpha(Config.Pose.Blend, dt)
	for name, motor in j.motors do
		local want = goal[name] or CFrame.identity
		-- (the Root is never eased: the squash, the flip and the mount are each smooth in themselves)
		local now = if name == "Root" then want else (j.current[name] or CFrame.identity):Lerp(want, a)
		j.current[name] = now
		-- carried into the joint's own directions (an R6 joint is turned on its side; an R15 joint is not)
		local turn = j.turns[name]
		if turn then
			now = turn:Inverse() * now * turn
		end
		motor.Transform = if mount and name == "Root" then mount * now else now
	end
	-- every other joint of the avatar is held at rest, so nothing of Roblox's own animations shows through
	for _, motor in j.rest do
		motor.Transform = CFrame.identity
	end
end

-- Our own character's animation tracks are stopped while we are in the water: all of them now and then (a track
-- started before we got wet), and each new one as it starts
local hooked: { [Animator]: boolean } = setmetatable({}, { __mode = "k" }) :: any
local function stopTracks(character: Model)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
	if animator then
		if not hooked[animator] then
			hooked[animator] = true
			animator.AnimationPlayed:Connect(function(track)
				if State.inWater() then
					track:Stop(0)
				end
			end)
		end
		for _, track in animator:GetPlayingAnimationTracks() do
			track:Stop(0.1)
		end
	end
end

local lastStop = 0

function AnimController.Start()
	-- a rider landed on a fish (every client hears it): that fish dips and kicks
	Net.Fx.OnClientEvent:Connect(function(kind: string, player: any, fish: any, serial: any)
		if kind == "Land" and typeof(fish) == "Instance" and fish:IsA("Model") then
			landedOn[fish] = os.clock()
			if Config.Ride.Startle > 0 then
				-- the startle: one reaction for every landing, and a "!" over its head
				reactOn[fish] = { kind = "rear", sign = 1, phase = 0 }
				Feel.mark(fish)
				return
			end
			-- which reaction: LandingMix 0 none (the dip only), 1 the body type's own, 2 a mix (the user's choice: its
			-- own most often, its second often, now and then any of the seven). Seeded so every client picks the same.
			local mix = Config.Animation.LandingMix
			local id = fish:GetAttribute("Rig")
			if mix >= 1 and type(id) == "string" then
				local userId = if typeof(player) == "Instance" and player:IsA("Player") then player.UserId else 0
				-- (the server may send the landing's number, so a player who joined late picks the same; else we count)
				local count = if type(serial) == "number" then serial else (landings[userId] or 0) + 1
				landings[userId] = count
				local random = Random.new(userId * 31 + count)
				local pair = RideStyles.landingsOf(id)
				local pick = pair[1]
				if mix >= 2 then
					local roll = random:NextNumber()
					if roll >= 0.75 then
						pick = RideStyles.AllLandings[random:NextInteger(1, #RideStyles.AllLandings)]
					elseif roll >= 0.45 then
						pick = pair[2]
					end
				end
				reactOn[fish] = { kind = pick, sign = if random:NextNumber() < 0.5 then -1 else 1, phase = 0 }
			else
				reactOn[fish] = nil
			end
		end
	end)
	-- the players, kept as they come and go (not read every frame)
	local everyone = Players:GetPlayers()
	Players.PlayerAdded:Connect(function()
		everyone = Players:GetPlayers()
	end)
	Players.PlayerRemoving:Connect(function()
		task.defer(function()
			everyone = Players:GetPlayers()
		end)
	end)
	RunService.PreSimulation:Connect(function(dt)
		animateFish()
		local t = os.clock()
		for _, player in everyone do
			local character = player.Character
			local state = player:GetAttribute("State")
			if player == State.Player then
				-- our own pose follows what we already see (the jump) before the server's word
				-- (through the pull-in, and while we sit waiting for the server's word on the landing: the dash)
				state = if State.Mode == "Jumping" and JumpController.reel() then "Reeling" else State.Mode
			end
			if character and type(state) == "string" then
				if state ~= "Dock" then
					animateRider(player, character, state, dt, t)
				elseif riderJoints[character] then
					-- back on the dock: hand the joints back to the Animator
					for _, motor in riderJoints[character].motors do
						motor.Transform = CFrame.identity
					end
					riderJoints[character] = nil
				end
			end
		end
		local character = State.Player.Character
		if character and State.inWater() and t - lastStop > 0.25 then
			lastStop = t
			stopTracks(character)
		end
	end)
end

return AnimController
