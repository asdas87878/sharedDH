--!strict
-- Procedural animation, no uploaded animations: every fish's swim (a modelled creature's keyed cycle, or a
-- placeholder's tail beat, sway and fin flaps), faster the faster it swims, and the buck when it throws its rider off;
-- and every rider's pose by their State (astride while riding, the pop, the strokes of the glide and the drop, the
-- pull-in, treading water while floating, flailing, weakening and going limp as they drown), with a squash on landing.
-- On top of a modelled creature's keyed cycle sit the layers of Config.Animation (2026-11-11, the first slice of
-- docs/design/animation-study.md), all seen only:
--   effort: the swing and the beat rise when the fish speeds up or is landed on, and ease when it coasts;
--   the turn layer: the head leads into a turn, the tail joints trail and come round late, wild fish bank;
--   the body layer: the heave, nod, sway and rock of its style (Shared/RideStyles), the landing's dip, the buck and
--     the crash's flinch, as one shift of the whole body about the Root (the first joint carries it);
--   the beat's rate by style, and a jaw that hangs and opens now and then instead of chomping every beat.
-- The rider is moved by the same shift, so they stay on the back, and braces at a landing.
-- Set in PreSimulation, after the Animator, so the poses win; our own character's animation tracks are stopped while
-- underwater. Poses are for R15 rigs. No tables are made per frame for the fish.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Config = require(game:GetService("ReplicatedStorage").Shared.Config)
local Creatures = require(game:GetService("ReplicatedStorage").Shared.Creatures)
local Ease = require(game:GetService("ReplicatedStorage").Shared.Ease)
local Net = require(game:GetService("ReplicatedStorage").Shared.Net)
local RideStyles = require(game:GetService("ReplicatedStorage").Shared.RideStyles)
local State = require(script.Parent.Parent.Lib.State)

local AnimController = {}

-- A modelled creature's joints (FishModel's "Rig_<part>"), each with its turns through one swim cycle. `bend` is its
-- place in the turn layer: 1 on the chain to the head, -1 on the chain to the tail, 0 elsewhere.
type RigJoint = { motor: Motor6D, frames: { CFrame }, bend: number, jaw: boolean }
type FishJoints = {
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
	shift: CFrame?, -- this frame's shift of the whole body, in the Root's space (the rider takes it too)
}
local fishJoints: { [Model]: FishJoints } = setmetatable({}, { __mode = "k" }) :: any
local landedOn: { [Model]: number } = setmetatable({}, { __mode = "k" }) :: any -- fish -> os.clock() a rider landed on it
local ridden: { [number]: Model } = {} -- this frame: UserId -> the fish they ride (only fish near the camera)
local spines: { [string]: { [string]: number } } = {} -- creature Id -> part -> its place in the turn layer

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
type RiderJoints = { motors: { [string]: Motor6D }, current: { [string]: CFrame } }
local riderJoints: { [Model]: RiderJoints } = setmetatable({}, { __mode = "k" }) :: any

local rad = math.rad
local function rot(x: number, y: number, z: number): CFrame
	return CFrame.Angles(rad(x), rad(y), rad(z))
end

local function joint(model: Model, name: string): Motor6D?
	local found = model:FindFirstChild(name, true)
	return if found and found:IsA("Motor6D") then found else nil
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

local function animateFish(dt: number)
	local folder = workspace:FindFirstChild("Fish")
	if not folder then
		return
	end
	table.clear(ridden)
	local now = os.clock()
	local a = Config.Animation
	local cameraAt = workspace.CurrentCamera.CFrame.Position
	for _, model in folder:GetChildren() do
		if model:IsA("Model") then
			local root = model.PrimaryPart
			if root and (root.Position - cameraAt).Magnitude < 450 then
				local j = fishJoints[model]
				if not j then
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
					}
					local id = model:GetAttribute("Rig")
					local rig = if type(id) == "string" then Creatures.get(id) else nil
					local swim = if rig then Creatures.swim(id :: string) else nil
					if rig and swim then
						local spine = spineOf(id :: string, rig)
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
								})
								if part == first then
									j.bodyKeyed = true
								end
							end
						end
						j.rig = list
						local body = joint(model, "Rig_" .. first)
						j.body = body
						if body then
							j.bodyC0 = body.C0
							j.bodyC0Inverse = body.C0:Inverse()
						end
						j.style = RideStyles.of(id :: string)
						-- a big creature beats slower than a small one
						local kind = Config.FishById[id :: string]
						j.pace = math.clamp(14 / (if kind then kind.Size.Z else 14), 0.4, 1.3)
					end
					fishJoints[model] = j
				end
				local speed = root.AssemblyLinearVelocity.Magnitude
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
					local riderId = model:GetAttribute("Rider")
					local isRidden = type(riderId) == "number" and riderId ~= 0
					if isRidden then
						ridden[riderId :: number] = model
					end
					local landedAt = landedOn[model]
					local sinceLand = if landedAt then now - landedAt else math.huge

					-- effort: working harder as it speeds up or takes a rider, easing as it coasts
					j.gain = Ease.lerp(j.gain, (speed - j.speedWas) / math.max(dt, 1e-3), Ease.alpha(4, dt))
					j.speedWas = speed
					local want = 1
					if a.Effort > 0 then
						want = math.clamp(1 + j.gain * a.EffortAccel, 0.6, 1.5)
						if sinceLand < a.LandEffortTime then
							want += a.LandEffort * (1 - sinceLand / math.max(a.LandEffortTime, 0.01))
						end
						want = Ease.lerp(1, want, math.min(a.Effort, 1))
					end
					j.effort = Ease.lerp(j.effort, want, Ease.alpha(8, dt))
					local effort = j.effort

					-- the beat: by speed and length as before, by the style's cadence, and quicker with effort
					local cadence = if style then Ease.lerp(1, style.Cadence, math.clamp(a.Cadence, 0, 1)) else 1
					local rate = (0.5 + speed * 0.03 + buck * 2) * j.pace * cadence * (1 + (effort - 1) * a.EffortBeat)
					j.phase += dt * math.pi * 2 * math.max(rate, 0)
					local u = (j.phase / (math.pi * 2)) % 1

					-- the turn layer: the head leads, the tail trails
					local turning = root.AssemblyAngularVelocity.Y
					j.turnFast = Ease.lerp(j.turnFast, turning, Ease.alpha(8, dt))
					j.turnSlow = Ease.lerp(j.turnSlow, turning, Ease.alpha(2.5, dt))
					local headBend, tailBend, lead = 0, 0, 0
					if a.Turn > 0 then
						local most, total = rad(a.TurnMax), rad(a.TurnTotal)
						if j.headJoints > 0 then
							local cap = math.min(most, total / j.headJoints)
							headBend = math.clamp(j.turnFast * a.TurnLead, -cap, cap) * a.Turn
						else
							-- most creatures' first part IS the head, with no joint of its own to lead with: the whole
							-- body is turned a little ahead instead (in the body's shift, below), and the tail bends back
							lead = math.clamp(j.turnFast * a.TurnLead, -most, most) * a.Turn
						end
						if j.tailJoints > 0 then
							local cap = math.min(most, total / j.tailJoints)
							tailBend = -math.clamp(j.turnSlow * a.TurnBend, -cap, cap) * a.Turn
						end
					end
					-- a jaw hangs nearly shut and opens now and then (and at a landing or a buck), not every beat
					local jawOpen = 1
					if a.Jaw > 0 and buck <= 0 and sinceLand > 1 then
						jawOpen = 0.15 + 0.85 * math.max(0, math.sin(now * 0.8 + j.seed)) ^ 4
					end

					-- every joint through its keyed turns, between the two nearest moments, with the layers on top
					for _, r in rig do
						local count = #r.frames
						local at = u * count
						local i = math.floor(at)
						local turn = r.frames[i % count + 1]:Lerp(r.frames[(i + 1) % count + 1], at - i)
						local scale = if r.jaw then jawOpen else effort
						if math.abs(scale - 1) > 0.03 then
							local axis, angle = turn:ToAxisAngle()
							turn = CFrame.fromAxisAngle(axis, angle * scale)
						end
						if r.bend ~= 0 then
							local bend = if r.bend > 0 then headBend else tailBend
							if math.abs(bend) > 0.002 then
								turn = CFrame.Angles(0, bend, 0) * turn
							end
						end
						r.motor.Transform = turn
					end

					-- the body layer: one shift of the whole body about the Root (up, nose, yaw, roll)
					local up, nose, swing, roll = 0, 0, math.deg(lead), 0
					if style and a.Body > 0 then
						local s = math.sin(j.phase)
						up += style.Heave * s * a.Body
						nose += style.Nod * math.cos(j.phase) * a.Body
						swing += style.Sway * s * a.Body
						roll += style.Rock * math.sin(j.phase + 1) * a.Body
					end
					if bucked and buck > 0 then
						-- the buck: nose up hard, down, up again, rolling
						local t = (now - bucked) / Config.Death.Throw
						nose += 40 * math.sin(t * math.pi * 3) * buck
						roll += 18 * math.sin(t * math.pi * 4.5) * buck
					end
					if a.LandDip > 0 and sinceLand < a.LandDipTime then
						-- the landing: it sinks under the rider and springs back, a small fish further than a big one
						local spring = math.exp(-sinceLand * 6) * math.cos(sinceLand * 13)
						local deep = (if style then style.Dip else 1) * j.pace
						up -= a.LandDip * deep * spring
						nose -= a.LandNod * deep * spring
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
					if math.abs(up) > 0.005 or math.abs(nose) + math.abs(swing) + math.abs(roll) > 0.05 then
						shift = CFrame.new(0, up, 0) * rot(nose, swing, roll)
					end
					j.shift = shift
					if body then
						-- (written afresh every frame, keyed or not: the buck used to pile up on a first part with no keys)
						local keyed = if j.bodyKeyed then body.Transform else CFrame.identity
						body.Transform = if shift then j.bodyC0Inverse * shift * j.bodyC0 * keyed else keyed
					end
					continue
				end
				j.phase += dt * math.pi * 2 * (0.7 + speed * 0.045 + buck * 2.5)
				local beat = math.sin(j.phase)
				local amount = 18 + math.min(speed, 80) * 0.12 + buck * 14
				if j.tail then
					j.tail.Transform = rot(0, beat * amount, 0)
				end
				if j.sway then
					local sway = rot(0, math.sin(j.phase - 1.2) * amount * 0.22, 0)
					if bucked and buck > 0 then
						local u = (os.clock() - bucked) / Config.Death.Throw
						local nose = 40 * math.sin(u * math.pi * 3) * buck
						local roll = 18 * math.sin(u * math.pi * 4.5) * buck
						sway = rot(nose, 0, roll) * sway
					end
					j.sway.Transform = sway
				end
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

-- The pose for a state at a time; joints not named stay at rest
local function pose(state: string, t: number, player: Player): { [string]: CFrame }
	if state == "Riding" then
		local bob = math.sin(t * 6) * 3
		return {
			LeftHip = rot(75, 0, -28),
			RightHip = rot(75, 0, 28),
			LeftKnee = rot(-85, 0, 0),
			RightKnee = rot(-85, 0, 0),
			LeftShoulder = rot(55 + bob, 0, 10),
			RightShoulder = rot(55 + bob, 0, -10),
			LeftElbow = rot(30, 0, 0),
			RightElbow = rot(30, 0, 0),
			Waist = rot(18, 0, 0),
			Neck = rot(-15, 0, 0),
		}
	elseif state == "Jumping" then
		local phase = if player == State.Player then State.JumpPhase else nil
		if phase == "Pop" then
			-- thrown off the fish: arms together out ahead, legs trailing, a push off
			return {
				LeftShoulder = rot(165, 0, -8),
				RightShoulder = rot(165, 0, 8),
				LeftHip = rot(-14, 0, -4),
				RightHip = rot(-14, 0, 4),
				LeftKnee = rot(-10, 0, 0),
				RightKnee = rot(-10, 0, 0),
				Neck = rot(30, 0, 0),
			}
		end
		-- the glide and the drop: swimming through the water, arms sweeping out and back together, legs kicking in
		-- turn; in the drop the strokes are longer and the kick harder, swimming down
		local drop = phase == "Drop"
		local stroke = math.sin(t * (if drop then 3.4 else 4.5))
		local kick = math.sin(t * 9) * (if drop then 26 else 18)
		return {
			LeftShoulder = rot(120 + stroke * 45, 0, -25 - stroke * 30),
			RightShoulder = rot(120 + stroke * 45, 0, 25 + stroke * 30),
			LeftElbow = rot(15 - stroke * 15, 0, 0),
			RightElbow = rot(15 - stroke * 15, 0, 0),
			LeftHip = rot(-6 + kick, 0, -6),
			RightHip = rot(-6 - kick, 0, 6),
			LeftKnee = rot(-18 - math.abs(kick) * 0.6, 0, 0),
			RightKnee = rot(-18 - math.abs(kick) * 0.6, 0, 0),
			Neck = rot(28, 0, 0),
		}
	elseif state == "Reeling" then
		-- pulled onto the fish: one arm out ahead on the line, the other back, legs straight out behind
		return {
			RightShoulder = rot(175, 0, -6),
			LeftShoulder = rot(-25, 0, 14),
			LeftHip = rot(-10, 0, -5),
			RightHip = rot(-4, 0, 5),
			LeftKnee = rot(-8, 0, 0),
			RightKnee = rot(-14, 0, 0),
			Neck = rot(35, 0, 0),
		}
	elseif state == "Drowning" then
		local started = State.DeathStart[player]
		return drowning(
			if started then os.clock() - started else 0,
			State.DeathThrown[player] == true,
			State.DeathStruggle[player] or Config.Death.Struggle,
			t
		)
	elseif state == "Free" then
		local s = math.sin(t * 3)
		return {
			LeftShoulder = rot(20, 0, -55 - s * 20),
			RightShoulder = rot(20, 0, 55 + s * 20),
			LeftHip = rot(15 + s * 15, 0, -6),
			RightHip = rot(15 - s * 15, 0, 6),
			LeftKnee = rot(-25, 0, 0),
			RightKnee = rot(-25, 0, 0),
		}
	end
	return {}
end

local function animateRider(player: Player, character: Model, state: string, dt: number, t: number)
	local j = riderJoints[character]
	if not j then
		local motors = {}
		for _, name in JOINTS do
			local m = joint(character, name)
			if m then
				motors[name] = m
			end
		end
		j = { motors = motors, current = {} }
		riderJoints[character] = j
	end
	local goal = pose(state, t, player)
	-- the landing squash: down and forward, springing back with a little overshoot
	local landed = State.Squash[character]
	if landed then
		local since = os.clock() - landed
		if since < 0.45 then
			local s = math.exp(-since * 9) * math.cos(since * 22)
			goal.Root = CFrame.new(0, -0.9 * s, 0) * rot(-14 * s, 0, 0)
			-- and the brace: arms thrown up and knees folded as we hit the saddle, then the grab
			local brace = math.min(Config.Animation.Brace, 0.45)
			if state == "Riding" and brace > 0 and since < brace then
				local hold = brace * 0.3
				local k = if since < hold then 1 else 1 - (since - hold) / (brace - hold)
				k *= k
				goal.LeftShoulder = rot(55 + 95 * k, 0, 10 - 30 * k)
				goal.RightShoulder = rot(55 + 95 * k, 0, -10 + 30 * k)
				goal.LeftElbow = rot(30 - 20 * k, 0, 0)
				goal.RightElbow = rot(30 - 20 * k, 0, 0)
				goal.LeftKnee = rot(-85 - 20 * k, 0, 0)
				goal.RightKnee = rot(-85 - 20 * k, 0, 0)
				goal.Waist = rot(18 + 16 * k, 0, 0)
				goal.Neck = rot(-15 - 12 * k, 0, 0)
			end
		else
			State.Squash[character] = nil
		end
	end
	-- on a fish, the rider goes with its body: the same shift the fish's first joint was given this frame (its heave
	-- and nod, the landing's dip, the buck), about the fish's Root, so they stay on the back
	local follow = Config.Animation.RiderFollow
	if state == "Riding" and follow > 0 then
		local fish = ridden[player.UserId]
		local shift = if fish and fishJoints[fish] then fishJoints[fish].shift else nil
		local fishRoot = fish and fish.PrimaryPart
		local rootMotor = j.motors.Root
		local seat = rootMotor and rootMotor.Part0
		if shift and fishRoot and rootMotor and seat then
			local from = seat.CFrame * rootMotor.C0
			local base = fishRoot.CFrame
			local moved = from:Inverse() * base * shift * base:Inverse() * from
			if follow < 1 then
				moved = CFrame.new():Lerp(moved, follow)
			end
			goal.Root = if goal.Root then moved * goal.Root else moved
		end
	end
	local a = Ease.alpha(18, dt)
	for name, motor in j.motors do
		local want = goal[name] or CFrame.identity
		local now = (j.current[name] or CFrame.identity):Lerp(want, if name == "Root" then 1 else a)
		j.current[name] = now
		motor.Transform = now
	end
end

local function stopTracks(character: Model)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
	if animator then
		for _, track in animator:GetPlayingAnimationTracks() do
			track:Stop(0.1)
		end
	end
end

local lastStop = 0

function AnimController.Start()
	-- a rider landed on a fish (every client hears it): that fish dips and kicks
	Net.Fx.OnClientEvent:Connect(function(kind: string, _player: any, fish: any)
		if kind == "Land" and typeof(fish) == "Instance" and fish:IsA("Model") then
			landedOn[fish] = os.clock()
		end
	end)
	RunService.PreSimulation:Connect(function(dt)
		animateFish(dt)
		local t = os.clock()
		for _, player in Players:GetPlayers() do
			local character = player.Character
			local state = player:GetAttribute("State")
			if player == State.Player then
				-- our own pose follows what we already see (the jump) before the server's word
				state = if State.Mode == "Jumping" and State.Reeling then "Reeling" else State.Mode
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
