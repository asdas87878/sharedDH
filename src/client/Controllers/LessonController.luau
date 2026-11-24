--!strict
-- The first minutes, on our own screen (docs/design/first-minutes.md): what the lesson's step (the server's "Lesson"
-- attribute, LessonService) shows. Each step names one place or one button, and nothing that another sign, ring or line of
-- the game already says. On the dock one line, the game's own (UI/DockNotes, where "GO TO YOUR TANK TO DEPOSIT" is), and
-- the pointer (UI/LessonPointer, in the world); in the water only the hop button's words and arrow (UI/LessonPrompt); in
-- the tank's window a ring round PUT ALL IN.
--   Dive     on the dock, nothing caught   DIVE IN AND CATCH A FISH                  the strip
--   First    floating, nothing caught      HOP ON A FISH                             the hop button
--   Hop      the first fish is theirs      HOP TO THE NEXT FISH                      the hop button
--   Run      the rest of that dive         nothing
--   Deposit  home with a catch             the game's caption, or CLICK YOUR TANK    the tank, then PUT ALL IN
--   Train    the first fish is in          RIDE YOUR SEAHORSE TO HOLD STRONGER FISH  the seahorse
--   Again    ridden                        CLAIM YOUR NEW FISH IN THE INDEX while one waits, then
--                                          DIVE IN AGAIN                             the strip
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
local LessonPointer = require(script.Parent.Parent.UI.LessonPointer)
local LessonPrompt = require(script.Parent.Parent.UI.LessonPrompt)
local Shop = require(script.Parent.Parent.UI.Shop)
local TankPanel = require(script.Parent.Parent.UI.TankPanel)

local LessonController = {}

local player = Players.LocalPlayer
local PULL_WAIT = 0.2 -- after a pull-in's touch, while the server answers (Jump.AckTime), and this much more, a press is
-- still not the next hop (seconds)

local STEP = "Lesson" -- the render step's name
local TANK_AHEAD = 8 -- the tank's trail ends this far in front of its glass, studs
local ARRIVED = 10 -- no trail this near its end, studs
local STRIP_HIGH, STRIP_LOW, STRIP_FALL = 9, 2.5, 0.13 -- the arrow's point over the strip, far and near, and the share of
-- the way there (so it never climbs the screen into the land strip as we come to it)
local STRIP_ON = 15 -- and none once we stand on it, this near its middle, studs
local TURN = 0.6 -- waking on the dock, the camera is behind us for this long under the black, seconds

local running = false
local step: string? = nil
local modeAt = 0
local lastMode = ""
local reeledAt = -math.huge -- the last frame we were being pulled in
local panelAt = -math.huge -- the last frame the tank's window was open (it takes a moment to close)
local endedAt = -math.huge -- the last frame the end of a dive had the screen
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

-- Where the pointer is: the place on the floor to walk to, what the arrow's point is over, and the most times larger the
-- arrow gets with the distance
type Place = { To: Vector3, Over: Vector3?, Most: number }

local strip: BasePart? = nil -- (found once: the dock holds a lot)
local stripLookAt = 0

local function stripPlace(feet: Vector3?): Place?
	local found = strip
	if not (found and found:IsDescendantOf(workspace)) then
		found = nil
		if os.clock() >= stripLookAt then
			stripLookAt = os.clock() + 1
			local d = dock()
			local part = d and d:FindFirstChild("StartStrip", true)
			found = if part and part:IsA("BasePart") then part else nil
		end
		strip = found
	end
	if not found then
		return nil
	end
	local top = found.Position + Vector3.new(0, found.Size.Y / 2, 0)
	local gap = if feet then ((top - feet) * Vector3.new(1, 0, 1)).Magnitude else math.huge
	local high = math.clamp(gap * STRIP_FALL, STRIP_LOW, STRIP_HIGH)
	return { To = top, Over = if gap > STRIP_ON then top + Vector3.new(0, high, 0) else nil, Most = 2.4 }
end

local function tankWater(): BasePart?
	local plot = ownPlot()
	local water = plot and plot:FindFirstChild("TankWater")
	return if water and water:IsA("BasePart") then water else nil
end

-- (in front of the tank, where a player wakes with a catch: AquariumService's frontOf; the arrow over the tank's own
-- board, not over its roof, which is off the top of the screen from there)
local function tankPlace(): Place?
	local water = tankWater()
	local plot = ownPlot()
	if not (water and plot) then
		return nil
	end
	local pad = plot:FindFirstChild("Pad")
	local half = water.Size / 2
	local way = water.CFrame.LookVector * Vector3.new(1, 0, 1)
	local floor = water.Position.Y - half.Y
	if pad and pad:IsA("BasePart") then
		local toPad = (pad.Position - water.Position) * Vector3.new(1, 0, 1)
		way = if toPad.Magnitude >= 1 then toPad else way
		floor = pad.Position.Y + pad.Size.Y / 2
	end
	way = way.Unit
	local face = math.abs(way:Dot(water.CFrame.RightVector)) * half.X
		+ math.abs(way:Dot(water.CFrame.LookVector)) * half.Z
	local front = water.Position + way * face
	local over = Vector3.new(front.X, water.Position.Y + half.Y + 1, front.Z)
	local board = plot:FindFirstChild("SignBoard")
	if board and board:IsA("BasePart") then
		over = board.Position + Vector3.new(0, board.Size.Y / 2 + 0.4, 0)
	end
	return { To = Vector3.new(front.X, floor, front.Z) + way * TANK_AHEAD, Over = over, Most = 1.8 }
end

-- (between the seahorse's head and the TRAIN sign over it, so it never grows)
local function trainerPlace(): Place?
	local plot = ownPlot()
	local ride = plot and plot:FindFirstChild("TrainerRide")
	if not (ride and ride:IsA("Model")) then
		return nil
	end
	local at, size = ride:GetBoundingBox()
	local up = Vector3.new(0, size.Y / 2, 0)
	return { To = at.Position - up, Over = at.Position + up + Vector3.new(0, 0.3, 0), Most = 0.8 }
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

-- Whether we are near enough to our tank to click it
local function atTank(root: BasePart): boolean
	local water, plot = tankWater(), ownPlot()
	if not (water and plot) then
		return false
	end
	local offset = water.CFrame:PointToObjectSpace(root.Position)
	local half = water.Size / 2
	local said = plot:GetAttribute("PanelReach")
	local reach = if type(said) == "number" then said else 36
	local dx = math.max(math.abs(offset.X) - half.X, 0)
	local dz = math.max(math.abs(offset.Z) - half.Z, 0)
	return math.sqrt(dx * dx + dz * dz) <= reach
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
	local docked = mode == "Dock"
	-- (home from a dive: the black, the fail's words, then the catch screen have the screen first)
	if docked and (State.FadeText ~= "" or State.Fade > 0.02 or CatchShow.showing()) then
		endedAt = now
		-- (the dive's camera looked anywhere: we wake looking where our body does, at the strip or our tank)
		if now - modeAt < TURN and State.Fade > 0.5 then
			local _, body = State.character()
			local camera = workspace.CurrentCamera
			if body and camera.CameraType == Enum.CameraType.Custom then
				local from = body.Position - body.CFrame.LookVector * 12 + Vector3.new(0, 5, 0)
				camera.CFrame = CFrame.lookAt(from, body.Position + Vector3.new(0, 2, 0))
			end
		end
	end
	if TankPanel.isOpen() then
		panelAt = now
	end
	local quiet = (docked and math.min(now - endedAt, now - panelAt) < 0.25)
		or Shop.Page ~= nil
		or State.dying()
		or player:GetAttribute("TankRide") ~= nil
	local character, root = State.character()
	local feet: Vector3? = nil
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if root and humanoid then
		feet = root.Position - Vector3.new(0, root.Size.Y / 2 + humanoid.HipHeight, 0)
	end
	local caught = State.Caught
	local carrying = caught ~= nil and #caught > 0

	local words: string? = nil
	local place: Place? = nil
	local trail = true
	local hop: string? = nil
	local caption: string? = nil
	local putRing = false

	local near = docked and step == "Deposit" and carrying and root ~= nil and atTank(root)
	if near then
		-- (even while the end of the dive has the screen: so the line comes up with the right words)
		caption = if Kit.touch() then "*TAP* YOUR TANK" else "*CLICK* YOUR TANK"
	end
	if docked and TankPanel.isOpen() then
		putRing = step == "Deposit"
	elseif docked and not quiet then
		if step == "Deposit" and carrying then
			place = tankPlace()
			trail = not near
		elseif carrying then
			-- (a catch in hand at any other step: the game's own caption has the line)
			words = nil
		elseif step == "Train" then
			if player:GetAttribute("Training") ~= true and player:GetAttribute("TrainerRide") == nil then
				words = "*RIDE YOUR SEAHORSE* TO HOLD STRONGER FISH"
				place = trainerPlace()
			end
		elseif step == "Again" then
			local claims = player:GetAttribute("IndexClaims")
			if type(claims) == "number" and claims > 0 then
				words = "*CLAIM* YOUR NEW FISH IN THE INDEX"
			else
				words = "*DIVE IN* AGAIN"
				place = stripPlace(feet)
			end
		elseif step == "Dive" or caught ~= nil then
			-- (or home with nothing to put in the tank, sold or the lot lost: down again)
			words = "*DIVE IN* AND CATCH A FISH"
			place = stripPlace(feet)
		end
	elseif mode == "Free" and step == "First" and now - modeAt > 0.8 and not quiet then
		hop = "*HOP* ON A FISH"
	elseif mode == "Riding" and step == "Hop" and not quiet then
		hop = "*HOP* TO THE NEXT FISH"
	end

	local to: Vector3? = nil
	if place and feet and trail then
		local gap = (place.To - feet) * Vector3.new(1, 0, 1)
		to = if gap.Magnitude > ARRIVED then place.To else nil
	end
	DockNotes.words(caption)
	DockNotes.lesson(words)
	LessonPointer.update(to, if place then place.Over else nil, if place then place.Most else 1, feet, now)

	if hop or hopButton then
		hopButton = findButton(hopButton, "HopButton")
		LessonPrompt.point(hopButton, hop)
	end
	if putRing or putAll then
		putAll = findButton(putAll, "PutAll")
		LessonPrompt.ring(putAll, putRing)
	end
	-- (no hop button on the first fish: there is nothing to press yet)
	HopButton.hold(mode == "Riding" and holding())
end

local function stop()
	if running then
		running = false
		RunService:UnbindFromRenderStep(STEP)
	end
	LessonPrompt.clear()
	LessonPointer.clear()
	DockNotes.words(nil)
	DockNotes.lesson(nil)
	HopButton.hold(false)
end

local function onStep()
	local value = player:GetAttribute("Lesson")
	local now: string? = if type(value) == "string" then value else nil
	if now == step then
		return
	end
	step = now
	if not step then
		stop()
	elseif not running then
		wrapJump()
		-- (after every camera step: the arrow turns to this frame's view)
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
