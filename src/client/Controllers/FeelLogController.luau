--!strict
-- The feel log (Config.FeelLog; the user, 2026-11-17: "How can we go about getting you to understand this the best
-- ... it doesnt feel as snappy, quick, and the selection doesnt feel like it grabs onto what is proper"). Studio only.
-- Claude can measure but not feel, and a scripted test never moves the camera, so this writes down what happens while
-- the user plays. In the Output, for Claude to read (and kept on the LocalPlayer, StringValues "FeelLog" and
-- "FeelMarks", for reading while still playing):
--   [FeelHop] one line a hop: off which fish and how fast, when the lock first took a fish and every fish it went to
--     (in order: A, B, A is a flip back), how the pull-in began (a press; "early", by itself as the fish came near;
--     "glide", by itself at the glide's end; "window"; "dive") and how long it took over what gap, the touch, how
--     long the server took to answer, every press and what it did ("grab", "nothing": no fish locked, "early":
--     too soon, "mash", "kept": made a moment later, "wait", "guard": refused by the mash guard), and how long you
--     rode the fish before (AfterLanding).
--   [FeelMark] press M when something feels off: the last BoxTime seconds, every SampleEvery: where you were and how
--     fast, the camera's look, the lock and the reach, and the fish nearest you (ahead, to the side and up from you,
--     their speed, and what the lock scored them: lower is better), with every event in that time.
--   [FeelPick] after a mark, numbers stand over the fish nearest you for PickTime: press the one you WANTED (0: none of
--     them). A handful of these and the lock can be fitted to what you meant instead of guessed at.
-- Nothing here changes the game.
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)
local FeelLog = require(script.Parent.Parent.Lib.FeelLog)
local Lock = require(script.Parent.Parent.Lib.Lock)
local State = require(script.Parent.Parent.Lib.State)

local FeelLogController = {}

local CHUNK = 3500 -- characters in one printed line at most (a mark goes out in parts)
local KEEP = 150000 -- characters kept in each StringValue (the oldest go first)
local NEAR = 220 -- fish further than this from us are left out of the black box, studs
local NUMBERS: { [Enum.KeyCode]: number } = {
	[Enum.KeyCode.Zero] = 0,
	[Enum.KeyCode.One] = 1,
	[Enum.KeyCode.Two] = 2,
	[Enum.KeyCode.Three] = 3,
	[Enum.KeyCode.Four] = 4,
	[Enum.KeyCode.Five] = 5,
	[Enum.KeyCode.Six] = 6,
	[Enum.KeyCode.Seven] = 7,
	[Enum.KeyCode.Eight] = 8,
	[Enum.KeyCode.Nine] = 9,
	[Enum.KeyCode.KeypadZero] = 0,
	[Enum.KeyCode.KeypadOne] = 1,
	[Enum.KeyCode.KeypadTwo] = 2,
	[Enum.KeyCode.KeypadThree] = 3,
	[Enum.KeyCode.KeypadFour] = 4,
	[Enum.KeyCode.KeypadFive] = 5,
	[Enum.KeyCode.KeypadSix] = 6,
	[Enum.KeyCode.KeypadSeven] = 7,
	[Enum.KeyCode.KeypadEight] = 8,
	[Enum.KeyCode.KeypadNine] = 9,
}

local studio = RunService:IsStudio()
local started = os.clock()

-- every fish gets a number of its own, so two Clownfish can be told apart: "Clownfish#12"
local ids: { [Instance]: number } = setmetatable({}, { __mode = "k" }) :: any
local lastId = 0
local function idOf(model: Instance?): string?
	if not model then
		return nil
	end
	local id = ids[model]
	if not id then
		lastId += 1
		id = lastId
		ids[model] = id
	end
	local kind = model:GetAttribute("FishType")
	return string.format("%s#%d", if type(kind) == "string" then kind else model.Name, id)
end

local function round(x: number, places: number?): number
	if x ~= x or x == math.huge or x == -math.huge then
		return 0
	end
	local k = 10 ^ (places or 1)
	return math.floor(x * k + 0.5) / k
end

-- Anything into what JSON can hold: a fish as its name and number, numbers rounded
local function clean(value: any): any
	local kind = typeof(value)
	if kind == "Instance" then
		return idOf(value)
	elseif kind == "number" then
		return round(value, 2)
	elseif kind == "Vector3" then
		return { round(value.X), round(value.Y), round(value.Z) }
	elseif kind == "table" then
		local out = {}
		for k, v in value do
			out[k] = clean(v)
		end
		return out
	elseif kind == "string" or kind == "boolean" then
		return value
	end
	return tostring(value)
end

local hopLines: StringValue? = nil
local markLines: StringValue? = nil

local function keep(value: StringValue?, line: string)
	if value then
		local text = value.Value .. line .. "\n"
		if #text > KEEP then
			text = string.sub(text, #text - KEEP)
		end
		value.Value = text
	end
end

-- The way we are going, and our right
local function axes(): (Vector3, Vector3)
	local yaw = State.Heading
	return Vector3.new(-math.sin(yaw), 0, -math.cos(yaw)), Vector3.new(math.cos(yaw), 0, -math.sin(yaw))
end

type Near = { Model: Model, D: number }

-- The fish nearest us (not the one we ride), nearest first
local function nearest(root: BasePart, count: number): { Near }
	local list: { Near } = {}
	local folder = workspace:FindFirstChild("Fish")
	if not folder then
		return list
	end
	for _, model in folder:GetChildren() do
		if model:IsA("Model") and model ~= State.Fish then
			local part = model.PrimaryPart
			if part then
				local d = (part.Position - root.Position).Magnitude
				if d < NEAR then
					table.insert(list, { Model = model, D = d })
				end
			end
		end
	end
	table.sort(list, function(a: Near, b: Near): boolean
		return a.D < b.D
	end)
	while #list > count do
		table.remove(list)
	end
	return list
end

-- THE BLACK BOX: a sample every Config.FeelLog.SampleEvery, the last BoxTime seconds of them
local samples: { { [string]: any } } = {}
local sampledAt = 0

local function sample(now: number)
	local _, root = State.character()
	if not root then
		return
	end
	local look = workspace.CurrentCamera.CFrame.LookVector
	local ahead, side = axes()
	local scores: { [Instance]: number } = {}
	local debug = Lock.Debug
	if debug and now - debug.At < 0.25 then
		for _, pair in debug.Scores do
			scores[pair.Model] = pair.Score
		end
	end
	local fish = {}
	for _, near in nearest(root, 6) do
		local part = near.Model.PrimaryPart :: BasePart
		local off = part.Position - root.Position
		local score = scores[near.Model]
		table.insert(fish, {
			Id = idOf(near.Model),
			D = round(near.D),
			A = round(off:Dot(ahead)),
			S = round(off:Dot(side)),
			U = round(off.Y),
			V = round(part.AssemblyLinearVelocity.Magnitude),
			Sc = if score then round(score, 2) else nil,
		})
	end
	local at = root.Position
	table.insert(samples, {
		At = now,
		T = round(now - started, 2),
		M = State.Mode,
		P = State.JumpPhase,
		Pos = { round(at.X), round(at.Y), round(at.Z) },
		V = round(State.Speed),
		Look = {
			round(math.deg(math.atan2(-look.X, -look.Z))),
			round(math.deg(math.asin(math.clamp(look.Y, -1, 1)))),
		},
		Heading = round(math.deg(State.Heading)),
		Lock = idOf(State.JumpTarget),
		Reach = if State.Reach then round(State.Reach) else nil,
		Fish = fish,
	})
	local box = math.max(Config.FeelLog.BoxTime, 1)
	while samples[1] and now - (samples[1].At :: number) > box do
		table.remove(samples, 1)
	end
end

-- THE HOP LINES
local hop: { [string]: any }? = nil
local hopAt = 0
local hops = 0
local lastMount: number? = nil
local lastLocked: Model? = nil
local loose: { { [string]: any } } = {} -- presses on a fish, between hops: told with the next hop

local function finish(why: string)
	local h = hop
	if not h then
		return
	end
	hop = nil
	h.End = why
	h.Same = h.Onto ~= nil and h.Onto == h.From
	local line = "[FeelHop] " .. HttpService:JSONEncode(clean(h))
	print(line)
	keep(hopLines, line)
end

local function heard(kind: string, info: { [string]: any }?, at: number)
	local i = info or {}
	local h = hop
	if kind == "hop" then
		if h then
			finish("unfinished")
		end
		hops += 1
		hopAt = at
		local target = State.JumpTarget
		hop = {
			N = hops,
			T = round(at - started, 2),
			From = idOf(i.From),
			Launch = round(i.Launch or 0),
			Reach = round(i.Reach or 0),
			Kept = i.Kept == true,
			AfterLanding = if lastMount then round(at - lastMount, 2) else nil,
			Before = if #loose > 0 then loose else nil,
			FirstLock = if target then 0 else nil,
			Locks = if target then { idOf(target) } else {},
			Presses = {},
		}
		loose = {}
		lastLocked = target
	elseif kind == "press" then
		if h then
			table.insert(h.Presses, { T = round(at - hopAt, 2), Did = i.Did })
		else
			table.insert(loose, { T = if lastMount then round(at - lastMount, 2) else nil, Did = i.Did })
		end
	elseif kind == "reel" and h then
		h.Grab = i.How
		h.GrabAt = round(at - hopAt, 2)
		h.Gap = round(i.Gap or 0)
		h.Reel = round(i.Time or 0, 2)
		h.GrabbedOn = idOf(i.Lock)
		h.SpeedAtGrab = round(i.Speed or 0)
	elseif kind == "touch" and h then
		h.Touch = round(at - hopAt, 2)
		h.Onto = idOf(i.Onto)
		-- (the pull-in's speeds: the slowest in its first part, a brake if under SpeedAtGrab; the speed we hit
		-- the fish at; and the fish's own)
		h.ReelLow = round(i.Low or 0)
		h.Arrive = round(i.Arrive or 0)
		h.FishSpeed = round(i.FishSpeed or 0)
	elseif kind == "lost" and h then
		h.Lost = (h.Lost or 0) + 1
	elseif kind == "mount" then
		if h then
			h.Server = if h.Touch then round(at - hopAt - h.Touch, 2) else nil
			finish("landed")
		end
		lastMount = at
	elseif kind == "miss" then
		finish("missed")
		lastMount = nil
	end
end

-- THE MARK, and the numbers over the fish
local gui: ScreenGui? = nil
local toast: TextLabel? = nil
local tags: { BillboardGui } = {}
local tagFish: { [number]: Model } = {}
local pickUntil = 0
local hideAt = 0
local marks = 0
local markLock: Model? = nil

local function build()
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local screen = Instance.new("ScreenGui")
	screen.Name = "FeelLog"
	screen.ResetOnSpawn = false
	screen.DisplayOrder = 60
	local label = Instance.new("TextLabel")
	label.Name = "Toast"
	label.AnchorPoint = Vector2.new(0.5, 0)
	label.Position = UDim2.new(0.5, 0, 0, 96)
	label.Size = UDim2.fromOffset(600, 40)
	label.BackgroundColor3 = Color3.fromRGB(18, 22, 38)
	label.BackgroundTransparency = 0.12
	label.TextColor3 = Color3.new(1, 1, 1)
	label.Font = Enum.Font.GothamBold
	label.TextSize = 18
	label.Visible = false
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = label
	label.Parent = screen
	toast = label
	for k = 1, 9 do
		local tag = Instance.new("BillboardGui")
		tag.Name = "Pick" .. k
		tag.Size = UDim2.fromOffset(40, 40)
		tag.StudsOffsetWorldSpace = Vector3.new(0, 5, 0)
		tag.AlwaysOnTop = true
		tag.Enabled = false
		local number = Instance.new("TextLabel")
		number.Size = UDim2.fromScale(1, 1)
		number.BackgroundColor3 = Color3.fromRGB(255, 221, 51)
		number.TextColor3 = Color3.new(0, 0, 0)
		number.Font = Enum.Font.GothamBlack
		number.TextSize = 26
		number.Text = tostring(k)
		local round_ = Instance.new("UICorner")
		round_.CornerRadius = UDim.new(1, 0)
		round_.Parent = number
		local edge = Instance.new("UIStroke")
		edge.Thickness = 2
		edge.Parent = number
		number.Parent = tag
		tag.Parent = screen
		tags[k] = tag
	end
	screen.Parent = playerGui
	gui = screen
end

local function say(text: string, seconds: number)
	local label = toast
	if label then
		label.Text = text
		label.Visible = true
		hideAt = os.clock() + seconds
	end
end

local function hideNumbers()
	pickUntil = 0
	FeelLog.TakesNumbers = false
	for k, tag in tags do
		tag.Enabled = false
		tag.Adornee = nil
		tagFish[k] = nil
	end
end

local function showNumbers(now: number)
	local _, root = State.character()
	if not root then
		return
	end
	local count = math.clamp(math.floor(Config.FeelLog.PickCount), 1, #tags)
	local list = nearest(root, count)
	-- (the locked fish always gets a number, if it is near enough to show)
	local target = State.JumpTarget
	if target and target.PrimaryPart then
		local found = false
		for _, near in list do
			if near.Model == target then
				found = true
			end
		end
		local d = (target.PrimaryPart.Position - root.Position).Magnitude
		if not found and d < NEAR then
			list[math.min(#list + 1, count)] = { Model = target, D = d }
		end
	end
	for k, tag in tags do
		local near = list[k]
		if near then
			tagFish[k] = near.Model
			tag.Adornee = near.Model.PrimaryPart
			tag.Enabled = true
			local number = tag:FindFirstChildOfClass("TextLabel")
			if number then
				-- (the locked fish's number is white)
				number.BackgroundColor3 = if near.Model == target
					then Color3.new(1, 1, 1)
					else Color3.fromRGB(255, 221, 51)
			end
		else
			tagFish[k] = nil
			tag.Adornee = nil
			tag.Enabled = false
		end
	end
	pickUntil = now + math.max(Config.FeelLog.PickTime, 1)
	FeelLog.TakesNumbers = true
end

local function mark()
	local now = os.clock()
	marks += 1
	markLock = State.JumpTarget
	local box: { [string]: any } = {
		N = marks,
		T = round(now - started, 2),
		Mode = State.Mode,
		Phase = State.JumpPhase,
		Hop = hop,
		Samples = {},
		Events = {},
	}
	for _, s in samples do
		local copy = table.clone(s)
		copy.At = nil
		table.insert(box.Samples, copy)
	end
	for _, e in FeelLog.since(now - math.max(Config.FeelLog.BoxTime, 1)) do
		table.insert(box.Events, { T = round(e.At - now, 2), Kind = e.Kind, Info = e.Info })
	end
	local text = HttpService:JSONEncode(clean(box))
	local parts = math.max(1, math.ceil(#text / CHUNK))
	for k = 1, parts do
		local line =
			string.format("[FeelMark %d %d/%d] %s", marks, k, parts, string.sub(text, (k - 1) * CHUNK + 1, k * CHUNK))
		print(line)
		keep(markLines, line)
	end
	showNumbers(now)
	say(string.format("Mark %d saved. Press the number of the fish you wanted (0: none of them)", marks), 6)
end

local function picked(choice: number)
	local model = if choice > 0 then tagFish[choice] else nil
	if choice > 0 and not model then
		return -- (no fish has that number)
	end
	local info: { [string]: any } = {
		N = marks,
		Choice = choice,
		LockedAtMark = idOf(markLock),
		LockedNow = idOf(State.JumpTarget),
	}
	local _, root = State.character()
	local part = model and model.PrimaryPart
	if model and part and root then
		local off = part.Position - root.Position
		local ahead, side = axes()
		info.Fish = idOf(model)
		info.D = round(off.Magnitude)
		info.A = round(off:Dot(ahead))
		info.S = round(off:Dot(side))
		info.U = round(off.Y)
		info.V = round(part.AssemblyLinearVelocity.Magnitude)
	end
	local line = "[FeelPick] " .. HttpService:JSONEncode(clean(info))
	print(line)
	keep(markLines, line)
	hideNumbers()
	say(
		if info.Fish
			then string.format("Mark %d: you wanted %s", marks, info.Fish)
			else string.format("Mark %d: none of them", marks),
		1.5
	)
end

local function step()
	FeelLog.On = studio and Config.FeelLog.On > 0
	if not FeelLog.On then
		return
	end
	local now = os.clock()
	if State.inWater() and now - sampledAt >= math.max(Config.FeelLog.SampleEvery, 0.02) then
		sampledAt = now
		sample(now)
	end
	-- every fish the lock goes to in a hop, in order
	local h = hop
	if h and State.Mode == "Jumping" then
		local target = State.JumpTarget
		if target ~= lastLocked then
			lastLocked = target
			if target then
				if not h.FirstLock then
					h.FirstLock = round(now - hopAt, 2)
				end
				if #h.Locks < 24 then
					table.insert(h.Locks, idOf(target))
				end
			end
		end
	end
	if pickUntil > 0 and now > pickUntil then
		hideNumbers()
	end
	local label = toast
	if label and label.Visible and now > hideAt and pickUntil == 0 then
		label.Visible = false
	end
end

function FeelLogController.Init()
	FeelLog.On = studio and Config.FeelLog.On > 0
end

function FeelLogController.Start()
	if not studio then
		return
	end
	local player = Players.LocalPlayer
	local a = Instance.new("StringValue")
	a.Name = "FeelLog"
	a.Parent = player
	hopLines = a
	local b = Instance.new("StringValue")
	b.Name = "FeelMarks"
	b.Parent = player
	markLines = b
	build()
	FeelLog.Fired.Event:Connect(heard)
	UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
		if processed or not FeelLog.On then
			return
		end
		if input.KeyCode == Enum.KeyCode.M then
			if State.inWater() then
				mark()
			end
		elseif pickUntil > 0 then
			local choice = NUMBERS[input.KeyCode]
			if choice then
				FeelLog.TakenInput = input
				picked(choice)
			end
		end
	end)
	RunService.RenderStepped:Connect(step)
	if FeelLog.On then
		print(
			"[FeelLog] on (Studio only): every hop is written as a [FeelHop] line; press M to save the last few seconds"
		)
	end
	local _ = gui
end

return FeelLogController
