--!strict
-- The lock-on (Config.Lock): which fish a grab would take. The aim is a thick ray from the camera along
-- where it looks, not a thin one: every free fish within the hook's reach of the rider (by the rider's speed right now:
-- Config.reachOf, at most Jump.GrabRange; the caller gives it) has an allowance, half of Lock.Cone
-- plus the angle that Lock.AimRadius (and half the fish's length) covers at its distance, so a near fish is far easier
-- to hit than a far one. A fish inside its allowance scores
--   AngleWeight x (how far off the aim it is, as a share of its allowance) + DistanceWeight x (distance / range),
-- and the lowest score wins: a fish aimed straight at beats a nearer one off to the side, and nearer wins close calls.
-- LeftPenalty puts the fish just left behind any other near the aim. A fish behind something
-- solid doesn't count (the pull-in would go through it).
-- The lock is sticky, so it doesn't flicker between two fish: the locked fish keeps it for MinHold, then until another
-- scores Sticky better, and it may drift KeepCone times further off the aim than it took to win the lock.
-- Since 2026-11-11 (the user: it switched between too many fish, too close together, and was hard to pick with):
--   EdgeAim 1 measures "off the aim" from the fish's nearest edge, in plain degrees as a share of half the Cone, not as a
--   share of the fish's own allowance. The old way gave a near fish a small score wherever it was in its wide allowance,
--   so near fish off to the side kept taking the lock; now the fish under the middle of the view wins, and one the aim
--   passes through scores 0, which nothing can beat by Sticky. EdgeAim 0 is the old score.
--   SwitchTime: a better fish must stay the better one this long before it takes the lock, so a fish swimming across
--   the view for a moment doesn't.
-- Since 2026-11-12 (Hugo: a longer hook, the fish you AIM at, far fish as easy to pick as near ones): the range is 180,
--   being far counts a third of what it did (DistanceWeight), and FarAim gives a fish a margin round it, growing with
--   its distance, that counts as aimed at it: a fish at the full range is a few pixels long, and no harder to pick now.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local State = require(script.Parent.State)

local Lock = {}

local lockedAt = -math.huge
local challenger: Model? = nil -- the fish that scores better than the locked one, waiting out SwitchTime
local challengerAt = 0
local PICK_EVERY = 0.05
local picked: Model? = nil -- what the last look chose,
local pickedAt = -1 -- and when

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
local function score(
	model: Model,
	from: Vector3,
	eye: Vector3,
	aim: Vector3,
	range: number,
	keep: boolean,
	wide: boolean
): number?
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
	local body = if kind then Config.bodyOf(model, kind).Z / 2 else l.FallbackRadius
	local radius = l.AimRadius + body
	-- a far fish is small on the screen: it gets a margin round it, by its distance, that counts as on it
	local share = distance / math.max(range, 1)
	local grace = math.rad(l.FarAim) * share
	local allowance =
		math.min(math.rad(l.Cone / 2) + math.atan(radius / math.max(away, 1)) + grace, math.rad(l.MaxAngle))
	-- (`wide`, the last chance: anything in reach counts, however far off the aim, behind us too)
	if not wide and angle > math.min(allowance * (if keep then l.KeepCone else 1), math.rad(l.MaxAngle)) then
		return nil
	end
	local far = l.DistanceWeight * share
	if l.EdgeAim > 0 then
		-- how far the aim passes from the fish itself, not from its middle: 0 when the aim goes through it
		local off = math.max(angle - math.atan(body / math.max(away, 1)) - grace, 0)
		return l.AngleWeight * off / math.max(math.rad(l.Cone / 2), 0.01) + far
	end
	return l.AngleWeight * angle / allowance + far
end

-- The fish to lock: `from` is the rider, `eye` and `aim` the camera's place and look, `current` the fish locked now,
-- `left` the fish we just left, `skip` one not to take at all (the server just refused it), `reach` how far the hook
-- goes right now (nil: Jump.GrabRange, the most it ever does), `wide` the last chance (Lock.LastChance): take any
-- fish in reach, all round, the one nearest the aim first
function Lock.pick(
	from: Vector3,
	eye: Vector3,
	aim: Vector3,
	current: Model?,
	left: Model?,
	skip: Model?,
	reach: number?,
	wide: boolean?
): Model?
	-- (the herd is gone over 20 times a second, not every frame: the lock holds for MinHold and SwitchTime anyway, and
	-- each look reads three attributes a fish and casts a few rays)
	local nowAt = os.clock()
	if nowAt - pickedAt < PICK_EVERY and picked == current and picked ~= skip then
		if picked == nil or (picked.Parent ~= nil and State.isFreeFish(picked)) then
			return picked
		end
	end
	pickedAt = nowAt
	refreshSight()
	local l = Config.Lock
	local range = reach or Config.Jump.GrabRange
	local folder = workspace:FindFirstChild("Fish")
	if not folder then
		return nil
	end
	local best: Model? = nil
	local bestScore = math.huge
	local currentScore: number? = nil
	for _, model in folder:GetChildren() do
		if model:IsA("Model") and model ~= skip and State.isFreeFish(model) then
			local s = score(model, from, eye, aim, range, model == current, wide == true)
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
	if current and currentScore and best ~= current then
		if now - lockedAt < l.MinHold or bestScore > currentScore - l.Sticky then
			challenger = nil
			picked = current
			return current
		end
		-- a better fish: it takes the lock only once it has been the better one for SwitchTime
		if challenger ~= best then
			challenger = best
			challengerAt = now
		end
		if now - challengerAt < l.SwitchTime then
			picked = current
			return current
		end
	end
	challenger = nil
	if best ~= current then
		lockedAt = now
	end
	picked = best
	return best
end

return Lock
