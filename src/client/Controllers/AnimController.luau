--!strict
-- Procedural animation, no uploaded animations: every fish's tail beat, body sway and fin flaps (faster the faster it
-- swims, slowed by the local slow-mo) and the buck when it throws its rider off, and every rider's pose by their State
-- (astride while riding, head first with arms out while dashing, an arm reaching out in the hook window and on the
-- rope, treading water while floating, panicking as the eater comes, flailing, weakening and going limp as they drown),
-- with a squash on landing.
-- Set in PreSimulation, after the Animator, so the poses win; our own character's animation tracks are stopped while
-- underwater. Poses are for R15 rigs.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Config = require(game:GetService("ReplicatedStorage").Shared.Config)
local Ease = require(game:GetService("ReplicatedStorage").Shared.Ease)
local State = require(script.Parent.Parent.Lib.State)

local AnimController = {}

type FishJoints = { sway: Motor6D?, tail: Motor6D?, finL: Motor6D?, finR: Motor6D?, phase: number }
local fishJoints: { [Model]: FishJoints } = setmetatable({}, { __mode = "k" }) :: any

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

local function animateFish(dt: number)
	local folder = workspace:FindFirstChild("Fish")
	if not folder then
		return
	end
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
					}
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
		-- the flight: swimming, arms sweeping out and back together, legs kicking in turn
		local stroke = math.sin(t * 4.5)
		local kick = math.sin(t * 9) * 18
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
		else
			State.Squash[character] = nil
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
	RunService.PreSimulation:Connect(function(dt)
		animateFish(dt)
		local t = os.clock()
		for _, player in Players:GetPlayers() do
			local character = player.Character
			local state = player:GetAttribute("State")
			if player == State.Player then
				-- our own pose follows what we already see (the jump) before the server's word
				state = State.Mode
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
