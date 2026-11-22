--!strict
-- Holding a fish over the head in the hub (Hugo, 2026-11-20; docs/design/holding.md): both arms up, like carrying a
-- trophy, for every player holding one (their "HeldFish" attribute, set by the server: AquariumService) while they
-- are on the dock. The fish itself is the server's, welded over the head, so everyone sees it already; this only
-- poses the arms, on every machine, for every player.
-- Set in PreSimulation, after the Animator, so the pose wins over the walk's arm swing; blended in and out from what
-- the Animator gave (Config.Hold.Blend). Only the shoulders and elbows are touched; the legs keep walking. Poses are
-- written in the body's own directions and carried into each joint's own (an R6 shoulder is turned on its side), as
-- AnimController's are; R6 has no elbows and simply lacks that bend.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Config = require(game:GetService("ReplicatedStorage").Shared.Config)
local Ease = require(game:GetService("ReplicatedStorage").Shared.Ease)

local HoldController = {}

local NAMES: { [string]: { string } } = {
	LeftShoulder = { "LeftShoulder", "Left Shoulder" },
	RightShoulder = { "RightShoulder", "Right Shoulder" },
	LeftElbow = { "LeftElbow" },
	RightElbow = { "RightElbow" },
}

-- `wrote`: what we set each joint to last frame. A joint still at that value was not driven by the Animator this frame
-- (some idle animations leave the elbows alone), so it blends from rest, not from our own last pose: the arms come
-- all the way down when the fish is put away
type Arms = {
	motors: { [string]: Motor6D },
	turns: { [string]: CFrame },
	wrote: { [string]: CFrame },
	weight: number,
}
local arms: { [Model]: Arms } = setmetatable({}, { __mode = "k" }) :: any

local function rot(x: number, y: number, z: number): CFrame
	return CFrame.Angles(math.rad(x), math.rad(y), math.rad(z))
end

-- A joint by its name: a Motor6D, or an AnimationConstraint, which stands in for one (AnimController.joint)
local function joint(model: Model, name: string): Motor6D?
	local found = model:FindFirstChild(name, true)
	if found and (found:IsA("Motor6D") or found:IsA("AnimationConstraint")) then
		return (found :: any) :: Motor6D
	end
	return nil
end

local function armsOf(character: Model): Arms
	local a = arms[character]
	if a then
		return a
	end
	local made: Arms = { motors = {}, turns = {}, wrote = {}, weight = 0 }
	for key, names in NAMES do
		for _, name in names do
			local m = joint(character, name)
			if m then
				made.motors[key] = m
				made.turns[key] = m.C0.Rotation
				break
			end
		end
	end
	arms[character] = made
	return made
end

-- The pose, in the body's directions: each arm lifted up past the head and out to its side, the forearm bent in
local function pose(): { [string]: CFrame }
	local c = Config.Hold
	return {
		LeftShoulder = rot(c.Lift, 0, -c.Out),
		RightShoulder = rot(c.Lift, 0, c.Out),
		LeftElbow = rot(0, 0, c.Elbow),
		RightElbow = rot(0, 0, -c.Elbow),
	}
end

function HoldController.Start()
	RunService.PreSimulation:Connect(function(dt)
		if Config.Hold.On == 0 then
			return
		end
		local goal: { [string]: CFrame }? = nil
		local blend = Ease.alpha(Config.Hold.Blend, dt)
		for _, player in Players:GetPlayers() do
			local character = player.Character
			if character then
				-- (one writer per joint, grade issue 6: astride the land fish or a tank's fish, AnimController has the
				-- arms, so the hold lets go at once instead of fading over its pose; on the trainer it has none)
				local owned = player:GetAttribute("TankRide") ~= nil
					or player:GetAttribute("TrainerRide") ~= nil
					or (player:GetAttribute("LandMounted") == true and Config.LandRide.On ~= 0)
				local holding = not owned
					and player:GetAttribute("HeldFish") ~= nil
					and player:GetAttribute("State") == "Dock"
				local a = arms[character]
				if owned and a and a.weight > 0 then
					a.weight = 0
					for key in a.motors do
						a.wrote[key] = nil -- (not written back to rest: the owner writes them this frame)
					end
				elseif holding or (a and a.weight > 0) then
					a = armsOf(character)
					a.weight += ((if holding then 1 else 0) - a.weight) * blend
					if not holding and a.weight < 0.01 then
						a.weight = 0
					end
					goal = goal or pose()
					for key, motor in a.motors do
						local want = (goal :: { [string]: CFrame })[key]
						local turn = a.turns[key]
						if turn and not turn:FuzzyEq(CFrame.identity, 1e-3) then
							want = turn:Inverse() * want * turn
						end
						-- (from what the Animator gave this frame, so the swing comes and goes smoothly)
						local from = motor.Transform
						if a.wrote[key] == from then
							from = CFrame.identity
						end
						if a.weight > 0 then
							local now = from:Lerp(want, a.weight)
							motor.Transform = now
							a.wrote[key] = now
						else
							motor.Transform = from -- (down: handed back to the Animator, or to rest)
							a.wrote[key] = nil
						end
					end
				end
			end
		end
	end)
end

return HoldController
