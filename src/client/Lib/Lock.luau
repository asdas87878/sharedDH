--!strict
-- The lock-on (Config.Lock): which fish a grab would take. The aim is a thick ray from the camera along
-- where it looks, not a thin one: every free fish within Jump.GrabRange of the rider has an allowance, half of Lock.Cone
-- plus the angle that Lock.AimRadius (and half the fish's length) covers at its distance, so a near fish is far easier
-- to hit than a far one. A fish inside its allowance scores
--   AngleWeight x (how far off the aim it is, as a share of its allowance) + DistanceWeight x (distance / range),
-- and the lowest score wins: a fish aimed straight at beats a nearer one off to the side, and nearer wins close calls.
-- LeftPenalty puts the fish just left behind any other near the aim. A fish behind something
-- solid doesn't count (the pull-in would go through it).
-- The lock is sticky, so it doesn't flicker between two fish: the locked fish keeps it for MinHold, then until another
-- scores Sticky better, and it may drift KeepCone times further off the aim than it took to win the lock.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local State = require(script.Parent.State)

local Lock = {}

local lockedAt = -math.huge

local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Exclude
params.RespectCanCollide = true
params.IgnoreWater = true

-- Rebuild once per selection so joining/respawning co-op players cannot become stale obstructions.
local function refreshSight()
	local list: { Instance } = { workspace.CurrentCamera }
	for _, player in Players:GetPlayers() do
		if player.Character then
			table.insert(list, player.Character)
		end
	end
	local blockout = workspace:FindFirstChild("ClaudeBlockout")
	local surface = blockout and blockout:FindFirstChild("Surface")
	if surface then
		table.insert(list, surface)
	end
	params.FilterDescendantsInstances = list
end

-- Only solid scenery stops the line; not avatars or the sheet of water at the surface.
local function inSight(from: Vector3, to: Vector3): boolean
	return workspace:Raycast(from, to - from, params) == nil
end

-- A fish's score (lower is better), or nil when it is out of range or outside its allowance
local function score(model: Model, from: Vector3, eye: Vector3, aim: Vector3, range: number, keep: boolean): number?
	local l = Config.Lock
	local at = (model.PrimaryPart :: BasePart).Position
	local distance = (at - from).Magnitude
	if distance > range then
		return nil
	end
	local to = at - eye
	local away = to.Magnitude
	if away < 0.5 then
		return nil
	end
	local angle = math.acos(math.clamp(to:Dot(aim) / away, -1, 1))
	local kind = Config.FishById[model:GetAttribute("FishType") :: string]
	local radius = l.AimRadius + (if kind then kind.Size.Z / 2 else l.FallbackRadius)
	local allowance = math.min(math.rad(l.Cone / 2) + math.atan(radius / math.max(away, 1)), math.rad(l.MaxAngle))
	if angle > math.min(allowance * (if keep then l.KeepCone else 1), math.rad(l.MaxAngle)) then
		return nil
	end
	return l.AngleWeight * angle / allowance + l.DistanceWeight * distance / math.max(range, 1)
end

-- The fish to lock: `from` is the rider, `eye` and `aim` the camera's place and look, `current` the fish locked now,
-- `left` the fish we just left, `skip` one not to take at all (the server just refused it)
function Lock.pick(from: Vector3, eye: Vector3, aim: Vector3, current: Model?, left: Model?, skip: Model?): Model?
	refreshSight()
	local l = Config.Lock
	local range = Config.Jump.GrabRange
	local folder = workspace:FindFirstChild("Fish")
	if not folder then
		return nil
	end
	local best: Model? = nil
	local bestScore = math.huge
	local currentScore: number? = nil
	for _, model in folder:GetChildren() do
		if model:IsA("Model") and model ~= skip and State.isFreeFish(model) then
			local s = score(model, from, eye, aim, range, model == current)
			if s then
				if model == left then
					s += l.LeftPenalty
				end
				-- the line of sight last, and only for a fish that would matter: it costs a ray
				if (s < bestScore or model == current) and inSight(from, (model.PrimaryPart :: BasePart).Position) then
					if model == current then
						currentScore = s
					end
					if s < bestScore then
						best = model
						bestScore = s
					end
				end
			end
		end
	end
	local now = os.clock()
	if current and currentScore then
		if best == current or now - lockedAt < l.MinHold or bestScore > currentScore - l.Sticky then
			return current
		end
	end
	if best ~= current then
		lockedAt = now
	end
	return best
end

return Lock
