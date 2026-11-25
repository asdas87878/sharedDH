--!strict
-- The first minutes (docs/design/first-minutes.md, the smallest set; the user's yes, 2026-11-23): the lesson a new player
-- is taken through once. The server keeps each player's step and the client only draws it (LessonController).
--   The player's "Lesson" attribute, the step:
--     "Dive"     on the dock, nothing caught yet: go to the strip
--     "First"    in the water, nothing caught yet (the first-fish rule, below, is on: the "LessonHold" attribute)
--     "Hop"      the first fish is theirs: hop to the next
--     "Run"      they have hopped: the rest of the dive, taught by nothing
--     "Deposit"  home with a catch: put it in the tank
--     "Train"    the first fish is in: ride the seahorse until Config.lessonGoal(), or until they get off it
--     "Again"    ridden: dive again
--     nil        over: down again (or never: no tank of their own ends it after the first dive)
--   The first-fish rule (RideService.FirstFish): until the first tame the hook takes only a fish they can hold, its meter
--   doesn't run, and it can't be hopped off; and one is put ahead of them as they go in when none is in reach. It lets go by
--   itself: Lesson.HoldMost in the water, Lesson.RideMost on one fish. Never off the submarine or on their own fish.
--   What happened is read from the attributes the other services already keep (State, TankFish, Training, MaxOxygen) and
--   from each tame (RideService.OnTamed). Each step is counted once (Roblox's onboarding funnel), in one fixed order.
-- That it is over is saved (SaveParts, part "Lesson"), so it is a player's first visits' only. Off (Config.Lesson.On 0) nothing here hooks anything.
-- In Studio: the workspace's "LessonTest" attribute, true before Play, switches it on, the movement sandbox or not.
local AnalyticsService = game:GetService("AnalyticsService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local FishService = require(script.Parent.FishService)
local RideService = require(script.Parent.RideService)

type Wild = FishService.Wild
type Step = "Dive" | "First" | "Hop" | "Run" | "Deposit" | "Train" | "Again"
type Record = {
	Step: Step?,
	State: string, -- the State attribute as last seen
	Tamed: boolean, -- their first fish is theirs
	Reef: boolean, -- one of the goal land's own fish is theirs
	Dives: number, -- times into the water off the dock
	Deposited: boolean,
	TankFish: number, -- as last seen
	TrainFrom: number, -- their Oxygen as they got on the seahorse (0: not yet)
	Wet: number, -- os.clock() they went in, this dive
	HoldEnd: number, -- os.clock() the first-fish rule lets go (0: off)
	PutAt: number, -- os.clock() of the last look for a fish in reach
	Put: number, -- fish put for them so far
	Counted: number, -- the furthest funnel step counted
	Links: { RBXScriptConnection },
}

-- The funnel, in its one order: a step reached after a later one isn't counted (so what could come out of order waits
-- for the first deposit).
local FUNNEL = {
	Joined = { 1, "Joined" },
	Dived = { 2, "Left the dock" },
	Landed = { 3, "First landing" },
	Tamed = { 4, "First tame" },
	Home = { 5, "First dive ended" },
	Deposited = { 6, "First deposit" },
	Trained = { 7, "Rode the seahorse" },
	Again = { 8, "Second dive" },
	Reef = { 9, "Tamed a Coral Reef fish" },
}

local LessonService = {}

local records: { [Player]: Record } = {}
local easy: { Config.FishType } = {} -- the first land's fish a new player holds, with no archetype to surprise them

local function testing(): boolean
	return RunService:IsStudio() and workspace:GetAttribute("LessonTest") == true
end

-- On at all (asked once, as the server starts), and on right now
local function wanted(): boolean
	return Config.Lesson.On ~= 0 or testing()
end

local function on(): boolean
	return testing() or (Config.Lesson.On ~= 0 and workspace:GetAttribute("Sandbox") ~= true)
end

local function count(player: Player, r: Record, step: { any })
	local number: number, name: string = step[1], step[2]
	if number <= r.Counted or Config.Lesson.Count == 0 then
		return
	end
	r.Counted = number
	if RunService:IsStudio() then
		print(`[Lesson] {player.Name}: {number} {name}`)
		return
	end
	task.spawn(function()
		local ok, problem = pcall(function()
			(AnalyticsService :: any):LogOnboardingFunnelStepEvent(player, number, name)
		end)
		if not ok then
			warn(`[Lesson] step {number} wasn't counted: {problem}`)
		end
	end)
end

local function setStep(player: Player, r: Record, step: Step?)
	if r.Step == step then
		return
	end
	r.Step = step
	player:SetAttribute("Lesson", step)
end

local function setHold(player: Player, r: Record, untilAt: number)
	r.HoldEnd = untilAt
	player:SetAttribute("LessonHold", if untilAt > 0 then true else nil)
end

local function attr(player: Player, name: string): number
	local value = player:GetAttribute(name)
	return if type(value) == "number" then value else 0
end

-- The first-fish rule is on (RideService asks in its tick: a table lookup and no more)
local function holding(player: Player): boolean
	local r = records[player]
	return r ~= nil and r.HoldEnd > 0 and os.clock() < r.HoldEnd and Config.Tame.On ~= 0 and on()
end

----------------------------------------------------------------------------------------------------------------------
-- A fish they can hold, in reach as they go in

local function ensureFish(player: Player, r: Record)
	local l = Config.Lesson
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") or #easy == 0 then
		return
	end
	r.PutAt = os.clock()
	local max = attr(player, "MaxOxygen")
	local s = FishService.streamS(root.Position)
	local there = FishService.nearest(root.Position, l.InReachWide, player, nil, function(w: Wild): boolean
		if not Config.firstFish(w.Type, w.SizeTier, w.Variant, max) then
			return false
		end
		local ahead = FishService.streamS(w.Root.Position) - s
		return ahead >= l.InReachFrom and ahead <= l.InReachTo
	end)
	local put = 0
	local first = math.abs(player.UserId)
	if not there then
		for i = 1, l.PutCount do
			if r.Put >= l.PutMost then
				break
			end
			r.Put += 1
			put += 1
			local side = if i % 2 == 1 then 1 else -1
			-- (one kind after another, so a first dive's two catches aren't the same fish: 2026-11-24)
			local kind = easy[(first + r.Put) % #easy + 1]
			FishService.put(kind, s + l.PutAhead + (i - 1) * l.PutGap, side * l.PutShare, l.PutLift)
		end
	end
	if RunService:IsStudio() then
		local word = if there
			then `{there.Type.Id} {math.floor((there.Root.Position - root.Position).Magnitude)} studs off`
			else `none in reach, {put} put`
		print(`[Lesson] a first fish for {player.Name} at s {math.floor(s)}: {word}`)
	end
end

----------------------------------------------------------------------------------------------------------------------
-- The steps

local function finish(player: Player, r: Record)
	setStep(player, r, nil)
	setHold(player, r, 0)
end

-- After the first deposit: ride the seahorse, or (strong enough already) dive again
local function onward(player: Player, r: Record)
	if r.Reef then
		count(player, r, FUNNEL.Reef)
	end
	if attr(player, "MaxOxygen") >= Config.lessonGoal() then
		setStep(player, r, "Again")
	else
		setStep(player, r, "Train")
	end
end

local function wentIn(player: Player, r: Record)
	r.Dives += 1
	r.Wet = os.clock()
	count(player, r, FUNNEL.Dived)
	if r.Dives > 1 and r.Deposited then
		count(player, r, FUNNEL.Again)
	end
	if not r.Tamed then
		setStep(player, r, "First")
	elseif r.Step == "Train" or r.Step == "Again" then
		finish(player, r)
	end
end

local function cameHome(player: Player, r: Record)
	setHold(player, r, 0)
	if not r.Tamed then
		setStep(player, r, "Dive")
		return
	end
	count(player, r, FUNNEL.Home)
	if r.Deposited then
		return
	end
	if player:GetAttribute("Plot") == nil then
		finish(player, r) -- (no tank of their own: nothing more to teach)
	elseif #RideService.carried(player) > 0 then
		setStep(player, r, "Deposit")
	end
end

local function onState(player: Player, r: Record)
	local state = player:GetAttribute("State")
	if type(state) ~= "string" or state == r.State or not on() then
		return
	end
	local was = r.State
	r.State = state
	if state == "Dock" then
		if was ~= "" then
			cameHome(player, r)
		elseif r.Step == nil and not r.Tamed then
			setStep(player, r, "Dive")
		end
		return
	end
	if was == "Dock" or was == "" then
		wentIn(player, r)
		if state == "Free" and not r.Tamed and Config.Tame.On ~= 0 then
			setHold(player, r, os.clock() + Config.Lesson.HoldMost)
			ensureFish(player, r)
		end
	end
	if state == "Riding" then
		count(player, r, FUNNEL.Landed)
		if not r.Tamed and r.HoldEnd > 0 then
			setHold(player, r, math.min(r.HoldEnd, os.clock() + Config.Lesson.RideMost))
		elseif r.Step == "Hop" and was == "Jumping" then
			setStep(player, r, "Run")
		end
	elseif state == "Free" and was == "Riding" and not r.Tamed and r.HoldEnd > 0 then
		-- (that fish was lost under them: the rule is for the next one, within what is left of the dive's own time)
		setHold(player, r, r.Wet + Config.Lesson.HoldMost)
	elseif state == "Drowning" or state == "Failing" or state == "Carried" then
		setHold(player, r, 0)
	end
end

local function onTamed(player: Player, w: Wild)
	local r = records[player]
	if not r or not on() then
		return
	end
	setHold(player, r, 0)
	if w.Type.Home == Config.Lesson.GoalLand then
		r.Reef = true
		if r.Deposited then
			count(player, r, FUNNEL.Reef)
		end
	end
	if not r.Tamed then
		r.Tamed = true
		count(player, r, FUNNEL.Tamed)
		setStep(player, r, "Hop")
	end
end

local function onTankFish(player: Player, r: Record)
	local fish = attr(player, "TankFish")
	local more = fish > r.TankFish
	r.TankFish = fish
	if not more or r.Deposited or not on() then
		return
	end
	if not r.Tamed then
		-- (fish in the tank with none made theirs here: given back from a save, so not a new player)
		r.Tamed, r.Deposited = true, true
		finish(player, r)
		return
	end
	r.Deposited = true
	count(player, r, FUNNEL.Deposited)
	onward(player, r)
end

local function join(player: Player)
	if records[player] then
		return
	end
	local r: Record = {
		Step = nil,
		State = "",
		Tamed = false,
		Reef = false,
		Dives = 0,
		Deposited = false,
		TankFish = attr(player, "TankFish"),
		TrainFrom = 0,
		Wet = 0,
		HoldEnd = 0,
		PutAt = 0,
		Put = 0,
		Counted = 0,
		Links = {},
	}
	if r.TankFish > 0 then
		r.Tamed, r.Deposited = true, true -- (not a new player)
	end
	records[player] = r
	local function watch(name: string, f: () -> ())
		table.insert(r.Links, player:GetAttributeChangedSignal(name):Connect(f))
	end
	watch("State", function()
		onState(player, r)
	end)
	watch("TankFish", function()
		onTankFish(player, r)
	end)
	watch("Training", function()
		if not r.Deposited or not on() then
			return
		end
		if player:GetAttribute("Training") == true then
			r.TrainFrom = attr(player, "MaxOxygen")
			count(player, r, FUNNEL.Trained)
		elseif r.Step == "Train" and r.TrainFrom > 0 and attr(player, "MaxOxygen") > r.TrainFrom then
			-- (off it again with some Oxygen gained: that is the lesson)
			setStep(player, r, "Again")
		end
	end)
	watch("MaxOxygen", function()
		if r.Step == "Train" and on() then
			onward(player, r)
		end
	end)
	if on() then
		count(player, r, FUNNEL.Joined)
	end
	onState(player, r)
end

local function leave(player: Player)
	local r = records[player]
	if r then
		for _, link in r.Links do
			link:Disconnect()
		end
		records[player] = nil
	end
end

-- For saving (SaveParts, part "Lesson"): whether it is over for them; nil while we don't have them
function LessonService.dump(player: Player): { [string]: any }?
	local r = records[player]
	return if r then { Done = r.Deposited and r.Step == nil } else nil
end

function LessonService.restore(player: Player, kept: any): boolean
	local r = records[player]
	if r and type(kept) == "table" and kept.Done == true then
		r.Tamed, r.Deposited = true, true
		setHold(player, r, 0)
		setStep(player, r, nil)
	end
	return true
end

function LessonService.Init()
	if not wanted() then
		return
	end
	for _, fish in Config.Fish do
		if fish.Home == 1 and fish.Archetype == "" and Config.firstFish(fish, "Normal", "", Config.Oxygen.StartMax) then
			table.insert(easy, fish)
		end
	end
	RideService.FirstFish = holding
	RideService.OnTamed = onTamed
end

function LessonService.Start()
	if not wanted() then
		return
	end
	Players.PlayerAdded:Connect(join)
	Players.PlayerRemoving:Connect(leave)
	for _, player in Players:GetPlayers() do
		task.spawn(join, player)
	end
	-- (the rule lets go by itself; and a player floating or hopping with no fish to take gets one)
	while true do
		task.wait(0.5)
		local now = os.clock()
		for player, r in records do
			if r.HoldEnd > 0 then
				if not holding(player) then
					setHold(player, r, 0)
				elseif
					(r.State == "Free" or r.State == "Jumping")
					and now - r.PutAt >= Config.Lesson.PutEvery
					and r.Put < Config.Lesson.PutMost
				then
					ensureFish(player, r)
				end
			end
		end
	end
end

return LessonService
