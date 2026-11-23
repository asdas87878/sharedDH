--!strict
-- The first minutes, on our own screen (docs/design/first-minutes.md, the smallest set): what the lesson's step (the server's
-- "Lesson" attribute, LessonService) shows. The line and the goal bar (UI/LessonLine), the pointer (UI/LessonPointer), the
-- plate and arrow by the hop button, the tank's caption (UI/DockNotes) and the arrow on PUT ALL IN.
-- While the server's "LessonHold" is on (the first fish is still to come) the lock takes only a fish we can hold
-- (Lock.Allow), and there is no hop off a fish: the press is dropped here, before JumpController has it, and
-- the server refuses it too.
-- With no "Lesson" attribute (Config.Lesson.On 0, or the lesson is over) nothing here is built or runs each frame.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Actions = require(script.Parent.Parent.Lib.Actions)
local Lock = require(script.Parent.Parent.Lib.Lock)
local State = require(script.Parent.Parent.Lib.State)
local CatchShow = require(script.Parent.Parent.UI.CatchShow)
local DockNotes = require(script.Parent.Parent.UI.DockNotes)
local HopButton = require(script.Parent.Parent.UI.HopButton)
local Kit = require(script.Parent.Parent.UI.Kit)
local LessonLine = require(script.Parent.Parent.UI.LessonLine)
local LessonPointer = require(script.Parent.Parent.UI.LessonPointer)
local Shop = require(script.Parent.Parent.UI.Shop)
local TankPanel = require(script.Parent.Parent.UI.TankPanel)

local LessonController = {}

local player = Players.LocalPlayer
local PULL_WAIT = 0.2 -- after a pull-in's touch, while the server answers (Jump.AckTime), and this much more, a press is
-- still not the next hop (seconds)

local STEP = "Lesson" -- the render step's name

local running = false
local step: string? = nil
local stepAt = 0
local modeAt = 0
local lastMode = ""
local reeledAt = -math.huge -- the last frame we were being pulled in
local strainUntil = 0 -- "Too strong!" is up until then,
local strainSaid = false -- once a session,
local strainHome = false -- and once more on the dock after it
local endedAt = -math.huge -- the last frame the end of a dive had the screen
local redSaid = false -- the hop prompt's second showing (the first red ring) has been
local redOn = false
local wrapped = false
local hopButton: GuiObject? = nil
local putAll: GuiObject? = nil

local function holding(): boolean
	return player:GetAttribute("LessonHold") == true
end

-- A fish our first may be (Config.firstFish), by its model
local function allowed(model: Model): boolean
	local id = model:GetAttribute("FishType")
	local kind = if type(id) == "string" then Config.FishById[id] else nil
	if not kind then
		return false
	end
	local size, variant = model:GetAttribute("SizeTier"), model:GetAttribute("Variant")
	local max = player:GetAttribute("MaxOxygen")
	return Config.firstFish(
		kind,
		if type(size) == "string" then size else nil,
		if type(variant) == "string" then variant else nil,
		if type(max) == "number" then max else Config.Oxygen.StartMax
	)
end

-- The press, before the hop has it (JumpController's, put in as it starts): none off the first fish, and none kept from
-- the pull-in onto it
local function wrapJump()
	if wrapped then
		return
	end
	wrapped = true
	local jump = Actions.jump
	Actions.jump = function(): boolean
		if holding() then
			local mode = State.Mode
			local pulled = State.Reeling or os.clock() - reeledAt < Config.Jump.AckTime + PULL_WAIT
			if mode == "Riding" or (mode == "Jumping" and pulled) then
				return false
			end
		end
		return jump()
	end
end

local function dock(): Instance?
	local blockout = workspace:FindFirstChild("ClaudeBlockout")
	return blockout and blockout:FindFirstChild("Dock")
end

local function ownPlot(): Instance?
	local name = player:GetAttribute("Plot")
	local d = dock()
	local plots = d and d:FindFirstChild("Plots")
	return if plots and type(name) == "string" then plots:FindFirstChild(name) else nil
end

local strip: BasePart? = nil -- (found once: the dock holds a lot)
local stripLookAt = 0

local function stripPlace(): Vector3?
	if not (strip and strip:IsDescendantOf(workspace)) and os.clock() >= stripLookAt then
		stripLookAt = os.clock() + 1
		local d = dock()
		local found = d and d:FindFirstChild("StartStrip", true)
		strip = if found and found:IsA("BasePart") then found else nil
	end
	return if strip then strip.Position else nil
end

local function tankWater(): BasePart?
	local plot = ownPlot()
	local water = plot and plot:FindFirstChild("TankWater")
	return if water and water:IsA("BasePart") then water else nil
end

local function trainerPlace(): Vector3?
	local plot = ownPlot()
	local ride = plot and plot:FindFirstChild("TrainerRide")
	if ride and ride:IsA("Model") then
		return ride:GetPivot().Position
	elseif ride and ride:IsA("BasePart") then
		return ride.Position
	end
	return nil
end

-- A button of another screen's, by name
local function findButton(known: GuiObject?, name: string): GuiObject?
	if known and known.Parent then
		return known
	end
	local gui = player:FindFirstChildOfClass("PlayerGui")
	local found = gui and gui:FindFirstChild(name, true)
	return if found and found:IsA("GuiObject") then found else nil
end

local function update()
	local now = os.clock()
	local mode = State.Mode
	if mode ~= lastMode then
		lastMode = mode
		modeAt = now
	end
	if State.Reeling then
		reeledAt = now
	end
	local l = Config.Lesson
	local docked = mode == "Dock"
	local windows = Shop.Page ~= nil or TankPanel.isOpen()
	-- (home from a dive: the black, the fail's words, then the catch screen have the screen first)
	if docked and (State.FadeText ~= "" or State.Fade > 0.02 or CatchShow.showing()) then
		endedAt = now
	end
	local ending = docked and now - endedAt < 0.25
	local touch = Kit.touch()
	local character, root = State.character()
	local oxygen = player:GetAttribute("MaxOxygen")
	local max = if type(oxygen) == "number" then oxygen else 0
	local need = Config.lessonGoal()
	local training = player:GetAttribute("Training") == true or player:GetAttribute("TrainerRide") ~= nil

	-- "Too strong!": the first time a fish is, and once more when that dive has brought us home
	if State.Strained and not strainSaid then
		strainSaid = true
		strainHome = true
		strainUntil = now + l.StrainTime
	end
	if docked and strainHome and not ending then
		strainHome = false
		strainUntil = now + l.StrainTime
	end

	local words: string? = nil
	local goal = false
	local at: Vector3? = nil
	local high = 8
	local trail = true
	local near = l.PointerOff
	local hop: string? = nil
	local caption: string? = nil
	local putArrow = false

	-- home with nothing in hand to put in the tank (sold, or the lot lost): down again
	local caught = State.Caught
	local bare = caught ~= nil and #caught == 0
	local again = bare and (step == "Hop" or step == "Run" or step == "Deposit")

	if docked and (step == "Dive" or again) then
		words = if again then "*DIVE IN!* Catch another fish" else "*DIVE IN!* Catch your first fish"
		at = stripPlace()
	elseif step == "First" then
		if mode == "Riding" and holding() then
			words = "*Hold on!* It's almost yours"
		elseif mode == "Free" and now - modeAt > 0.8 then
			hop = if touch then "TAP TO HOP ON A FISH" else "SPACE: HOP ON A FISH"
		end
	elseif step == "Hop" then
		if mode == "Riding" then
			hop = if touch then "TAP TO HOP TO THE NEXT FISH" else "SPACE: HOP TO THE NEXT FISH"
		end
	elseif step == "Run" then
		-- (the first red ring after that: the prompt once more, for as long as that fish lasts)
		local fish = State.Fish
		local red = mode == "Riding" and fish ~= nil and fish:GetAttribute("Angry") == true and not State.Strained
		if red and not redSaid then
			redSaid = true
			redOn = true
		elseif redOn and not red then
			redOn = false
		end
		if redOn then
			hop = if touch then "TAP TO HOP TO THE NEXT FISH" else "SPACE: HOP TO THE NEXT FISH"
		end
	elseif step == "Deposit" and docked then
		local water = tankWater()
		if TankPanel.isOpen() then
			putArrow = true
		elseif water and root then
			local offset = water.CFrame:PointToObjectSpace(root.Position)
			local half = water.Size / 2
			local plot = ownPlot()
			local said = plot and plot:GetAttribute("PanelReach")
			local reach = if type(said) == "number" then said else 36
			local dx = math.max(math.abs(offset.X) - half.X, 0)
			local dz = math.max(math.abs(offset.Z) - half.Z, 0)
			local close = math.sqrt(dx * dx + dz * dz) <= reach
			if close then
				caption = if touch then "TAP YOUR TANK" else "CLICK YOUR TANK"
			end
			at = water.Position
			high = water.Size.Y / 2 + 4
			trail = not close
			near = 0
		end
	elseif step == "Train" then
		goal = true
		if now - stepAt < l.EarnTime then
			words = "Your fish *earn every second!*"
		elseif docked then
			words = "*Ride your seahorse:* more Oxygen holds stronger fish"
			if not training then
				at = trainerPlace()
				high = 9
				near = 8
			end
		end
	elseif step == "Reef" then
		if docked then
			words = `*DIVE IN!* Catch a {l.GoalName} fish`
			goal = true
			at = stripPlace()
		elseif now - modeAt < l.ReefTime and (mode == "Free" or mode == "Jumping" or mode == "Riding") then
			words = `Go down to the *{l.GoalName}* and catch a fish`
			goal = now - modeAt < l.BarTime
		end
	end
	if now < strainUntil and (docked or mode == "Riding") then
		words = "*Too strong!* Your seahorse builds your Oxygen"
	end
	if State.dying() then
		words, goal, hop = nil, false, nil
	end
	if windows or ending or player:GetAttribute("TankRide") then
		words, goal, at = nil, false, nil
	end

	LessonLine.say(words)
	if goal and need > 0 then
		local text = `{l.GoalName} fish: {Config.wholeNumber(math.min(max, need))} / {Config.wholeNumber(need)} Oxygen`
		LessonLine.goal(text, max / need)
	else
		LessonLine.goal(nil, 0)
	end
	LessonPointer.update(at, high, root, character, near, trail, now)
	DockNotes.words(caption)

	if hop or hopButton then
		hopButton = findButton(hopButton, "HopButton")
		LessonLine.note(hopButton, hop)
		LessonLine.arrow(hopButton, hop ~= nil)
	end
	if putArrow or putAll then
		putAll = findButton(putAll, "PutAll")
		LessonLine.arrow(putAll, putArrow)
	end
	-- (no hop button on the first fish: there is nothing to press yet)
	HopButton.hold(mode == "Riding" and holding())
end

local function stop()
	if running then
		running = false
		RunService:UnbindFromRenderStep(STEP)
	end
	LessonLine.clear()
	LessonPointer.clear()
	DockNotes.words(nil)
	HopButton.hold(false)
end

local function onStep()
	local value = player:GetAttribute("Lesson")
	local now: string? = if type(value) == "string" then value else nil
	if now == step then
		return
	end
	step = now
	stepAt = os.clock()
	if not step then
		stop()
	elseif not running then
		wrapJump()
		-- (after every camera step: the marker is drawn where the place is in this frame's view)
		running = true
		RunService:BindToRenderStep(STEP, Enum.RenderPriority.Last.Value, update)
	end
end

local function onHold()
	Lock.Allow = if holding() then allowed else nil
	if holding() then
		wrapJump()
	end
end

function LessonController.Start()
	player:GetAttributeChangedSignal("Lesson"):Connect(onStep)
	player:GetAttributeChangedSignal("LessonHold"):Connect(onHold)
	onStep()
	onHold()
end

return LessonController
