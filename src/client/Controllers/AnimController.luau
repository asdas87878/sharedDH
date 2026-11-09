--!strict
-- Procedural animation, no uploaded animations: every fish's tail beat, body sway and fin flaps (faster the faster it
-- swims, slowed by the local slow-mo), and every rider's pose by their State (astride while riding, head first with arms
-- out while dashing, an arm out on the rope while grappling, treading water while floating), with a squash on landing.
-- Set in PreSimulation, after the Animator, so the poses win; our own character's animation tracks are stopped while
-- underwater. Poses are for R15 rigs.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

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
	local scaled = dt * State.TimeScale
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
				j.phase += scaled * math.pi * 2 * (0.7 + speed * 0.045)
				local beat = math.sin(j.phase)
				local amount = 18 + math.min(speed, 80) * 0.12
				if j.tail then
					j.tail.Transform = rot(0, beat * amount, 0)
				end
				if j.sway then
					j.sway.Transform = rot(0, math.sin(j.phase - 1.2) * amount * 0.22, 0)
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

-- The pose for a state at a time; joints not named stay at rest
local function pose(state: string, t: number): { [string]: CFrame }
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
	elseif state == "Dashing" then
		local kick = math.sin(t * 30) * 12
		return {
			LeftShoulder = rot(170, 0, 8),
			RightShoulder = rot(170, 0, -8),
			LeftHip = rot(-8 + kick, 0, 0),
			RightHip = rot(-8 - kick, 0, 0),
			Neck = rot(25, 0, 0),
		}
	elseif state == "Grappling" then
		return {
			RightShoulder = rot(160, 0, 0),
			LeftShoulder = rot(-30, 0, 20),
			LeftHip = rot(-15, 0, -8),
			RightHip = rot(10, 0, 8),
			LeftKnee = rot(-30, 0, 0),
			RightKnee = rot(-20, 0, 0),
		}
	elseif state == "Free" or state == "PassedOut" then
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

local function animateRider(character: Model, state: string, dt: number, t: number)
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
	local goal = pose(state, t)
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
			if player == State.Player and State.Mode == "Aiming" then
				state = "Free"
			end
			if character and type(state) == "string" then
				if state ~= "Dock" then
					animateRider(character, state, dt, t)
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
