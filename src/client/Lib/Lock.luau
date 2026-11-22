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
-- Since 2026-11-18 (the user: "when you hop off a dino it pretty much auto selects the one in front of you ... it also
--   switches selection often times when you press a or d"), Lock.Pick 2, the line: everything above is Pick 1. The
--   reference's ring lies under its rider and takes the dino nearest it, again and again with no hold (read off the
--   user's recording: docs/reference/ride-a-dino.md). Ours: every free fish in reach is measured from the line the
--   camera looks along (flat, through us), where it and we will be a moment on (LineLead): off to the side in studs,
--   ahead counting LineAhead of that, behind LineBehind, height LineUp, less a share of half its length (LineBody). The
--   nearest wins, and only fish in front of us count (FrontAngle, now and a moment on): one beside us, coming up from
--   behind, is taken only when no fish in front is in reach, and one behind us never but in the last chance
--   (FrontAside). No cone and no aiming. A or D steps the
--   lock to the next fish in front that way (StepEvery while held); turning the view moves it at once
--   (LineKeepSteer); otherwise the locked fish keeps it until another is LineKeep nearer, or LineChosen if it was
--   stepped or turned onto. (The first build's line was the way we fly, which A and D turn up to 90 degrees off the
--   view: the user, the same evening, "sometimes the a d function attatches to a fish thats basically behind the
--   player or just coming up to its peripherals".)
-- The reach is to the fish's whole body, not its middle (Lock.WholeBody, Config.fishGap; the user: "so that large
--   fish dont feel further than they are"): the server measures it the same way.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local FeelLog = require(script.Parent.FeelLog)
local State = require(script.Parent.State)

local Lock = {}
-- (the feel log's: every fish the last look scored, and its score, lower being better; only while it is on)
Lock.Debug = nil :: { At: number, Scores: { { Model: Model, Score: number } } }?

local lockedAt = -math.huge
local challenger: Model? = nil -- the fish that scores better than the locked one, waiting out SwitchTime
local challengerAt = 0
local PICK_EVERY = 0.05
local picked: Model? = nil -- what the last look chose,
local pickedAt = -1 -- and when
-- the leeway (Lock.Linger): the locked fish, and when it was last inside the reach and the aim
local heldFish: Model? = nil
local heldAt = -math.huge
local lingering = false
-- the rider's own velocity, from where they were at the last look (for the lead, Lock.Lead)
local lastFrom: Vector3? = nil
local lastFromAt = 0
local riderVelocity = Vector3.zero
-- the line (Lock.Pick 2): the view was being turned at the last look (the caller says), and the fish stepped or
-- turned onto, which keeps the lock harder (Lock.LineChosen)
local lookingNow = false
local chosen: Model? = nil
-- a fish beside us goes after every fish in front, and the fish we just left after every other (a line score is in
-- studs: no fish in reach scores either)
local OUT_OF_FRONT = 1e3
local LEFT_LAST = 1e4

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
	local root = model.PrimaryPart :: BasePart
	local at = root.Position
	local distance = (at - from).Magnitude
	if Config.fishGap(model, from) > range then
		return nil
	end
	-- Not a fish under us or behind us (Lock.Ahead; 2026-11-17, the user: "it still locks onto ur current fish or
	-- fish near the bottom of ur screen too much"). The camera looks at the rider, so the aim's line runs through
	-- the rider's own place: a fish right under us, the one we just left most of all, sat dead on the aim. A fish
	-- must be this far ahead of us, the way the camera looks across the water. (Not in the last chance, and the
	-- fish already locked keeps its lock.)
	local flat = Vector3.new(aim.X, 0, aim.Z)
	local against = root.AssemblyLinearVelocity - riderVelocity
	if not wide and flat.Magnitude > 0.05 then
		-- (judged where it will be in AheadLead seconds, against us: a slow fish just ahead that we are about to
		-- fly over doesn't count, and a fast one coming up from behind does as soon as it will be ahead. The fish
		-- already locked may fall AheadKeep further back before it is let go.)
		local ahead = ((at - from) + against * l.AheadLead):Dot(flat.Unit)
		if ahead < (if keep then l.Ahead - l.AheadKeep else l.Ahead) then
			return nil
		end
	end
	-- Where it will be in a moment, against us (Lock.Lead): a fish coming past fast is aimed at where it is going
	if l.Lead > 0 then
		at += against * l.Lead
	end
	local to = at - eye
	local away = to.Magnitude
	if away < 0.5 then
		return nil
	end
	local angle = math.acos(math.clamp(to:Dot(aim) / away, -1, 1))
	-- Up counts for less and down for more (Lock.UpEase, DownHard): a fish above the aim is easier to take than one
	-- as far below it, by how much of its being off the aim is height. The fast fish swim high; the fish at the
	-- bottom of the view are the ones under us.
	if angle > 0.001 then
		local rise = math.asin(math.clamp(to.Y / away, -1, 1)) - math.asin(math.clamp(aim.Y, -1, 1))
		local share = math.clamp(math.abs(rise) / angle, 0, 1)
		angle *= 1 + share * ((if rise >= 0 then l.UpEase else l.DownHard) - 1)
	end
	local kind = Config.FishById[model:GetAttribute("FishType") :: string]
	local body = if kind then Config.bodyOf(model, kind).Z / 2 else l.FallbackRadius
	local radius = l.AimRadius + body
	-- a far fish is small on the screen: it gets a margin round it, by its distance, that counts as on it
	local share = distance / math.max(range, 1)
	local grace = math.rad(l.FarAim) * share
	local allowance =
		math.min(math.rad(l.Cone / 2) + math.atan(radius / math.max(away, 1)) + grace, math.rad(l.MaxAngle))
	-- (`wide`, the last chance: anything in reach counts, however far off the aim, behind us too)
	-- Outside its allowance. With the assist (Lock.Assist) a fish ahead of us still counts, behind every fish
	-- that is aimed at: so with nothing under the aim the lock takes the fish ahead nearest to it, and there is
	-- nearly always a lock while any fish ahead is in reach. Aiming still chooses.
	local outside = 0
	if not wide and angle > math.min(allowance * (if keep then l.KeepCone else 1), math.rad(l.MaxAngle)) then
		if l.Assist <= 0 or angle > math.rad(l.AssistAngle) then
			return nil
		end
		outside = l.AssistPenalty
	end
	local far = l.DistanceWeight * share
	if l.EdgeAim > 0 then
		-- how far the aim passes from the fish itself, not from its middle: 0 when the aim goes through it
		local off = math.max(angle - math.atan(body / math.max(away, 1)) - grace, 0)
		return l.AngleWeight * off / math.max(math.rad(l.Cone / 2), 0.01) + far + outside
	end
	return l.AngleWeight * angle / allowance + far + outside
end

-- Degrees round from the line (`dir` ahead, `right` its right) to a place: + to the right, 0 for one so near across
-- the water (under us) that it has no side
local function roundFrom(rel: Vector3, dir: Vector3, right: Vector3): number
	local ahead, side = rel:Dot(dir), rel:Dot(right)
	if ahead * ahead + side * side < 36 then
		return 0
	end
	return math.deg(math.atan2(side, ahead))
end

-- How far the hook reaches toward a fish at `at` (Jump.AheadReach): `reach` off to the side and behind, up to `ahead`
-- straight in front of us (`dir`, the camera's look, and `right`), less the further round it is
local function reachToward(
	at: Vector3,
	from: Vector3,
	reach: number,
	ahead: number,
	dir: Vector3,
	right: Vector3
): number
	if ahead <= reach then
		return reach
	end
	local j = Config.Jump
	local round = math.abs(roundFrom(at - from, dir, right))
	local u = math.clamp((round - j.AheadFull) / math.max(j.AheadNone - j.AheadFull, 1), 0, 1)
	return reach + (ahead - reach) * (1 - u * u * (3 - 2 * u))
end

-- A fish's place against the line (Lock.Pick 2), in studs, lower being better, with how far round from the line it
-- will be (degrees, + to the right) and where it is: 0 in front of us, 1 beside us, 2 behind; nil when it is out of
-- reach. `dir`: the camera's look, flat. Where it and we will be LineLead seconds on, by both our speeds: off to the
-- side counts in full, ahead LineAhead of that, behind LineBehind, above or below LineUp; a big fish is nearer by
-- LineBody of half its length. In front: within FrontAngle of the line both now and then (`keep`, the locked fish:
-- FrontKeep more, and never behind); beside: within FrontAside; `wide`, the last chance: everything is in front. In
-- reach: `range` to the side, up to `ahead` straight in front (reachToward).
local function lineScore(
	model: Model,
	from: Vector3,
	dir: Vector3,
	range: number,
	ahead: number,
	keep: boolean,
	wide: boolean
): (number?, number, number)
	local l = Config.Lock
	local root = model.PrimaryPart :: BasePart
	local kind = Config.FishById[model:GetAttribute("FishType") :: string]
	local body = if kind then Config.bodyOf(model, kind) else Vector3.one * (l.FallbackRadius * 2)
	local right = Vector3.new(-dir.Z, 0, dir.X)
	if Config.bodyGap(root.CFrame, body, from) > reachToward(root.Position, from, range, ahead, dir, right) then
		return nil, 0, 2
	end
	local now = root.Position - from
	local rel = now + (root.AssemblyLinearVelocity - riderVelocity) * l.LineLead
	local fore = rel:Dot(dir)
	local side = rel:Dot(right)
	local along = if fore >= 0 then fore * l.LineAhead else -fore * l.LineBehind
	local up = rel.Y * l.LineUp
	local s = math.max(math.sqrt(side * side + along * along + up * up) - body.Z / 2 * l.LineBody, 0)
	local round = roundFrom(rel, dir, right)
	local most = math.max(math.abs(round), math.abs(roundFrom(now, dir, right)))
	local place = if wide or most <= l.FrontAngle + (if keep then l.FrontKeep else 0)
		then 0
		elseif most <= l.FrontAside then 1
		else 2
	-- (the locked fish sliding back past us, as we fly over it, keeps the lock as one beside us: only a new lock may
	-- never be behind. Dropping it there lost a hop in a test; any fish in front still takes the lock from it)
	if keep and place == 2 then
		place = 1
	end
	return s, round, place
end

-- The fish to lock: `from` is the rider, `eye` and `aim` the camera's place and look, `current` the fish locked now,
-- `back`: the fish we just left may take the lock when nothing else can (Lock.LeftBack);
-- `left` the fish we just left, `skip` one not to take at all (the server just refused it), `reach` how far the hook
-- goes right now (nil: Jump.GrabRange, the most it ever does), `wide` the last chance (Lock.LastChance): take any
-- fish in reach, all round, the one nearest the aim first. With Lock.Pick 2: `aimYaw` is the camera's look (radians, as
-- State.CamYaw; nil: Pick 1's way), `looking` that the view is being turned, `step` A or D this look (-1 left, 1 right,
-- 0 or nil none): the lock goes to the next fish in front that way; `ahead` the hook's reach straight in front of us
-- (Jump.AheadReach; nil: `reach` all round)
function Lock.pick(
	from: Vector3,
	eye: Vector3,
	aim: Vector3,
	current: Model?,
	left: Model?,
	skip: Model?,
	reach: number?,
	wide: boolean?,
	back: boolean?,
	aimYaw: number?,
	looking: boolean?,
	step: number?,
	ahead: number?
): Model?
	-- (the herd is gone over 20 times a second, not every frame: the lock holds for MinHold and SwitchTime anyway, and
	-- each look reads three attributes a fish and casts a few rays)
	local nowAt = os.clock()
	local stepping = step ~= nil and step ~= 0
	if nowAt - pickedAt < PICK_EVERY and picked == current and picked ~= skip and not stepping then
		if picked == nil or (picked.Parent ~= nil and State.isFreeFish(picked)) then
			return picked
		end
	end
	-- (our own velocity, for the lead: from where we were at the last look)
	if lastFrom and nowAt - lastFromAt > 0.01 and nowAt - lastFromAt < 0.5 then
		riderVelocity = (from - lastFrom) / (nowAt - lastFromAt)
	else
		-- (the first look of a hop: the body's own, still the fish's we leave; it was taken as standing still, so every
		-- fish was judged a moment ahead of where it would be against us)
		local _, me = State.character()
		riderVelocity = if me then me.AssemblyLinearVelocity else Vector3.zero
	end
	lastFrom, lastFromAt = from, nowAt
	pickedAt = nowAt
	refreshSight()
	local l = Config.Lock
	local range = reach or Config.Jump.GrabRange
	-- (the line, Lock.Pick 2: the camera's look, flat)
	local byLine = l.Pick >= 2 and aimYaw ~= nil
	local dir = if aimYaw then Vector3.new(-math.sin(aimYaw), 0, -math.cos(aimYaw)) else Vector3.zero
	local right = Vector3.new(-dir.Z, 0, dir.X)
	local reachAhead = if byLine then math.max(ahead or range, range) else range
	-- (the hook's reach toward a fish: further straight ahead, Jump.AheadReach)
	local function reachFor(model: Model): number
		return reachToward((model.PrimaryPart :: BasePart).Position, from, range, reachAhead, dir, right)
	end
	lookingNow = looking == true
	if current == nil then
		chosen = nil
	end
	local folder = workspace:FindFirstChild("Fish")
	if not folder then
		return nil
	end
	local best: Model? = nil
	local bestScore = math.huge
	local debugScores: { { Model: Model, Score: number } }? = if FeelLog.On then {} else nil
	local currentScore: number? = nil
	local currentRound = 0
	-- (Lock.Pick 2, for a step: every fish in front this look, with how far round it is)
	local steps: { { Model: Model, Round: number } } = {}
	for _, model in folder:GetChildren() do
		-- (the fish we just left is not taken at all until the last chance: Lock.LeftBan)
		local banned = model == left and l.LeftBan > 0 and wide ~= true
		if model:IsA("Model") and model ~= skip and not banned and State.isFreeFish(model) then
			local s: number?
			if byLine then
				local lineS, round, place =
					lineScore(model, from, dir, range, reachAhead, model == current, wide == true)
				-- (behind us: not taken, Lock.FrontAside)
				s = if place >= 2 then nil else lineS
				if s then
					if place == 1 then
						s += OUT_OF_FRONT
					elseif stepping and model ~= left then
						table.insert(steps, { Model = model, Round = round })
					end
					if model == current then
						currentRound = round
					end
				end
			else
				s = score(model, from, eye, aim, range, model == current, wide == true)
			end
			if s then
				if model == left then
					s += if byLine then LEFT_LAST else l.LeftPenalty
				end
				if debugScores then
					table.insert(debugScores, { Model = model, Score = s })
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
	-- Back onto the fish we just left (Lock.LeftBack; the user, 2026-11-17: "its now really hard to hook back onto
	-- the previous fish"). With no other fish to lock, the one we left takes the lock, wherever it is round us, if
	-- it is in reach and in sight (`back`: the hop is past its first moment). It is never scored, so any other fish
	-- that can be locked takes the lock from it at once, with none of the lock's stickiness.
	if not best and back and left and left ~= skip and l.LeftBack > 0 and left.Parent and State.isFreeFish(left) then
		local at = (left.PrimaryPart :: BasePart).Position
		if Config.fishGap(left, from) <= reachFor(left) and inSight(from, at) then
			best = left
		end
	end
	if debugScores then
		Lock.Debug = { At = nowAt, Scores = debugScores }
	end
	local now = os.clock()
	-- A or D (Lock.Pick 2): the next fish in front that way, the nearest round from the locked one (from the middle of
	-- the view with none), at least StepGap further; with none that way the lock stays as it is
	if byLine and stepping then
		local fromRound = if current and currentScore then currentRound else 0
		local side = if (step :: number) > 0 then 1 else -1
		table.sort(steps, function(a, b)
			return (a.Round - fromRound) * side < (b.Round - fromRound) * side
		end)
		for _, c in steps do
			if c.Model ~= current and (c.Round - fromRound) * side >= l.StepGap then
				if inSight(from, (c.Model.PrimaryPart :: BasePart).Position) then
					challenger = nil
					lingering = false
					lockedAt = now
					chosen = c.Model
					heldFish, heldAt = c.Model, now
					picked = c.Model
					return c.Model
				end
			end
		end
	end
	-- The leeway (Lock.Linger; the user, 2026-11-17: "if you lock onto a fish even if it goes outside of your
	-- boundaries you keep locked onto it for a small window of time"). The locked fish that has just left the reach
	-- or the aim keeps the lock for Linger seconds, while it is free and within LingerReach of the reach.
	lingering = false
	if current and currentScore then
		heldFish, heldAt = current, now
	elseif
		current
		and current == heldFish
		and now - heldAt < l.Linger
		and current ~= skip
		and State.isFreeFish(current)
		and Config.fishGap(current, from) <= reachFor(current) * l.LingerReach
	then
		lingering = true
		challenger = nil
		picked = current
		return current
	end
	if byLine and current and currentScore and best ~= current then
		-- the line's hold: the locked fish keeps the lock until another is LineKeep nearer the line, or LineChosen if
		-- it was stepped or turned onto; while the view is being turned the nearest takes it at once (LineKeepSteer).
		-- A locked fish that is no longer in front scores OUT_OF_FRONT more: any fish in front takes it from it.
		local margin = if lookingNow then l.LineKeepSteer elseif current == chosen then l.LineChosen else l.LineKeep
		if now - lockedAt < l.LineHold or bestScore > currentScore - margin then
			challenger = nil
			picked = current
			return current
		end
	elseif current and currentScore and best ~= current then
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
		-- (a fish the lock went to while the view was being turned is the one we chose)
		chosen = if lookingNow then best else nil
	end
	picked = best
	return best
end

-- The fish a press takes with no fish locked (Lock.PressAny): the one nearest the line (`aimYaw`, as Lock.pick's)
-- anywhere in reach and in sight, one in front first, then one beside us, never one behind us, the fish we just left
-- after every other; nil with none. The lock's own hold is left as it was. `ahead`: the reach straight in front of us.
function Lock.any(from: Vector3, aimYaw: number, range: number, left: Model?, skip: Model?, ahead: number?): Model?
	local folder = workspace:FindFirstChild("Fish")
	if not folder then
		return nil
	end
	refreshSight()
	local dir = Vector3.new(-math.sin(aimYaw), 0, -math.cos(aimYaw))
	local best: Model? = nil
	local bestScore = math.huge
	for _, model in folder:GetChildren() do
		if model:IsA("Model") and model ~= skip and State.isFreeFish(model) then
			local lineS, _, place = lineScore(model, from, dir, range, math.max(ahead or range, range), false, false)
			if lineS and place < 2 then
				local s = lineS + (if place == 1 then OUT_OF_FRONT else 0) + (if model == left then LEFT_LAST else 0)
				if s < bestScore and inSight(from, (model.PrimaryPart :: BasePart).Position) then
					best, bestScore = model, s
				end
			end
		end
	end
	return best
end

-- How far the hook reaches toward a fish (Jump.AheadReach): `reach` to the side and behind, up to `ahead` straight in
-- front of us, where the camera looks (`aimYaw`); with the lock's own Pick 1, `reach` all round
function Lock.reachOf(model: Model, from: Vector3, reach: number, ahead: number, aimYaw: number): number
	local root = model.PrimaryPart
	if not root or Config.Lock.Pick < 2 then
		return reach
	end
	local dir = Vector3.new(-math.sin(aimYaw), 0, -math.cos(aimYaw))
	return reachToward(root.Position, from, reach, ahead, dir, Vector3.new(-dir.Z, 0, dir.X))
end

-- How much further than the hook's reach a grab may take the locked fish right now: Lock.LingerReach while the lock
-- is being kept on a fish that has left the reach or the aim (the leeway), 1 otherwise
function Lock.slack(): number
	return if lingering then Config.Lock.LingerReach else 1
end

return Lock
