--!strict
-- The fish in the tanks on the dock swim (AquariumService puts each in its place, anchored, with the tag "TankFish"
-- and the numbers of its lap: TankCentre, TankReach, TankPhase, TankPace). Each client moves them round itself, so
-- they cost no traffic and the server does nothing each frame. Only tanks near the camera are moved, and no table is
-- made in a frame. Moving the anchored Root moves the whole fish: its parts are joined to it.
-- Putting a catch in (Hugo, 2026-11-18: "make the player actually be able to place down fishes in aquarium once
-- back"): what a dive caught stays in the slots until the player puts it in. At our own tank a prompt on its front glass
-- (hold E, or tap it; task k1: no pad any more) puts the chosen slot's fish in (the white ring: the newest, or the one clicked); while the prompt shows, a click
-- on a caught slot puts that fish in at once. The server checks it all (Action "Place", index, id: AquariumService).
-- And the moment a fish goes in (Ride "Deposited"): the view turns to our tank, and a line rises over the tank saying what it adds a second. A
-- stand-in for the real thing (a sound, the fish dropping in, the UI chat's own look).
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)
local State = require(script.Parent.Parent.Lib.State)
local Slots = require(script.Parent.Parent.UI.Slots)
local TankPanel = require(script.Parent.Parent.UI.TankPanel)

local AquariumController = {}

local TAG = "TankFish"

type Swimmer = { root: BasePart, centre: Vector3, reach: Vector3, phase: number, pace: number }

local swimmers: { [Instance]: Swimmer } = {}

local function add(model: Instance)
	if not model:IsA("Model") then
		return
	end
	local root = model.PrimaryPart
	local centre, reach = model:GetAttribute("TankCentre"), model:GetAttribute("TankReach")
	local phase, pace = model:GetAttribute("TankPhase"), model:GetAttribute("TankPace")
	if
		root
		and typeof(centre) == "Vector3"
		and typeof(reach) == "Vector3"
		and type(phase) == "number"
		and type(pace) == "number"
	then
		swimmers[model] = { root = root, centre = centre, reach = reach, phase = phase, pace = pace }
	end
end

-- Our own tank's water (the plot the server gave us: our "Plot" attribute)
local function ownWater(): BasePart?
	local name = Players.LocalPlayer:GetAttribute("Plot")
	local blockout = workspace:FindFirstChild("ClaudeBlockout")
	local dock = blockout and blockout:FindFirstChild("Dock")
	local plots = dock and dock:FindFirstChild("Plots")
	local plot = plots and type(name) == "string" and plots:FindFirstChild(name)
	local water = plot and plot:FindFirstChild("TankWater")
	return if water and water:IsA("BasePart") then water else nil
end

-- A catch went into our tank: look at it (we stand in front of it), and say what it earns
local function deposited(count: number, gained: number, id: string?)
	local water = ownWater()
	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not water or not root or not root:IsA("BasePart") then
		return
	end
	local camera = workspace.CurrentCamera
	if camera and camera.CameraType == Enum.CameraType.Custom then
		local to = Vector3.new(water.Position.X, root.Position.Y, water.Position.Z) - root.Position
		if to.Magnitude > 1 then
			camera.CFrame = CFrame.lookAt(root.Position - to.Unit * 26 + Vector3.new(0, 14, 0), water.Position)
		end
	end
	local kind = if id then Config.FishById[id] else nil
	local gui = Instance.new("BillboardGui")
	gui.Name = "Deposited"
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.Size = UDim2.fromOffset(420, 96)
	gui.StudsOffsetWorldSpace = Vector3.new(0, -water.Size.Y / 2 + 12, 0)
	gui.Adornee = water
	local function line(text: string, y: number, high: number, colour: Color3): TextLabel
		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.Position = UDim2.fromOffset(0, y)
		label.Size = UDim2.new(1, 0, 0, high)
		label.Font = Enum.Font.GothamBlack
		label.TextSize = high - 6
		label.TextColor3 = colour
		label.TextStrokeColor3 = Color3.fromRGB(10, 20, 40)
		label.TextStrokeTransparency = 0
		label.Text = text
		label.Parent = gui
		return label
	end
	local top = line(
		if kind and count == 1
			then string.upper(kind.Name) .. " IN YOUR TANK"
			else string.format("+%d IN YOUR TANK", count),
		0,
		46,
		Color3.new(1, 1, 1)
	)
	local under = line("+$" .. Config.shortNumber(gained) .. " a second", 48, 40, Color3.fromRGB(255, 214, 64))
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	local rise = TweenInfo.new(2.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(gui, rise, { StudsOffsetWorldSpace = gui.StudsOffsetWorldSpace + Vector3.new(0, 10, 0) }):Play()
	task.delay(1.8, function()
		local fade = TweenInfo.new(0.6)
		for _, label in { top, under } do
			TweenService:Create(label, fade, { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
		end
		task.wait(0.7)
		gui:Destroy()
	end)
end

-- The prompt on our own tank's front glass (Hugo, 2026-11-20, task k1: the green pad is gone; the prompt was on it):
-- on an attachment at the middle of the water's front face, low, so walking up to the glass shows it. While we carry
-- fish it puts the chosen one in ("Put in tank"); with empty hands, and fish swimming in the tank, it puts us on the
-- fish nearest us ("Ride a fish": Config.TankRide, TankRideService).
local prompt: ProximityPrompt? = nil
local promptShown = false
local promptVerb = "" -- "Place" or "Ride": what the prompt does now

local function place(index: number?, item: State.Caught?)
	if not index or not item then
		local list = State.Caught
		if not list or #list == 0 then
			return
		end
		index, item = #list, list[#list]
	end
	if index and item then
		Net.Action:FireServer("Place", index, item.Id)
	end
end

-- Our tank's fish swimming in it now, the one nearest us
local function nearestTankFish(water: BasePart): Model?
	local plot = water.Parent
	local shown = plot and plot:FindFirstChild("TankFish")
	local _, root = State.character()
	if not shown or not root then
		return nil
	end
	local best, found = math.huge, nil
	for _, m in shown:GetChildren() do
		if m:IsA("Model") and m.PrimaryPart and CollectionService:HasTag(m, TAG) then
			local d = (m.PrimaryPart.Position - root.Position).Magnitude
			if d < best then
				best, found = d, m
			end
		end
	end
	return found
end

-- The middle of the water's front face, a little over the sand: the plot's front is the way from the water to the
-- plot's Pad, which reaches further forward than the tank (AquariumService.frontOf works it out the same way)
local function frontSpot(water: BasePart): Vector3
	local plot = water.Parent
	local pad = plot and plot:FindFirstChild("Pad")
	local way = if pad and pad:IsA("BasePart")
		then (pad.Position - water.Position) * Vector3.new(1, 0, 1)
		else Vector3.zero
	if way.Magnitude < 1 then
		way = water.CFrame.LookVector * Vector3.new(1, 0, 1)
	end
	local local_ = water.CFrame:VectorToObjectSpace(way.Unit)
	local half = water.Size / 2
	-- (onto the face it points through most)
	local onX = math.abs(local_.X) * half.Z > math.abs(local_.Z) * half.X
	local at = if onX
		then Vector3.new(math.sign(local_.X) * (half.X + 0.3), 0, 0)
		else Vector3.new(0, 0, math.sign(local_.Z) * (half.Z + 0.3))
	return Vector3.new(at.X, -half.Y + math.min(4, half.Y), at.Z)
end

local function updatePrompt()
	local water = ownWater()
	if not water then
		if prompt then
			prompt.Enabled = false
		end
		return
	end
	local spot = water:FindFirstChild("TankFront")
	if not spot then
		local a = Instance.new("Attachment")
		a.Name = "TankFront"
		a.Parent = water
		spot = a
	end
	local attachment = spot :: Attachment
	attachment.Position = frontSpot(water)
	if not prompt or prompt.Parent ~= attachment then
		if prompt then
			prompt:Destroy()
		end
		local p = Instance.new("ProximityPrompt")
		p.Name = "PlaceFish"
		p.ActionText = "Put in tank"
		p.KeyboardKeyCode = Enum.KeyCode.E
		p.HoldDuration = 0.25
		p.MaxActivationDistance = 16
		p.RequiresLineOfSight = false
		p.Triggered:Connect(function()
			if promptVerb == "Place" then
				place(Slots.chosen())
			elseif promptVerb == "Ride" then
				Net.Action:FireServer("TankRide", "On", nearestTankFish(water))
			end
		end)
		p.PromptShown:Connect(function()
			promptShown = true
		end)
		p.PromptHidden:Connect(function()
			promptShown = false
		end)
		p.Parent = attachment
		prompt = p
	end
	local list = State.Caught
	local carrying = list ~= nil and #list > 0
	local p = prompt :: ProximityPrompt
	local onDock = State.Mode == "Dock" and not Players.LocalPlayer:GetAttribute("TankRide")
	if carrying then
		promptVerb = "Place"
		local _, item = Slots.chosen()
		local chosen = item or (list :: { State.Caught })[#(list :: { State.Caught })]
		local kind = Config.FishById[chosen.Id]
		p.ActionText = "Put in tank"
		p.ObjectText = if kind then kind.Name else chosen.Id
		p.Enabled = onDock
	else
		local fish = if Config.TankRide.On ~= 0 then nearestTankFish(water) else nil
		promptVerb = if fish then "Ride" else ""
		p.ActionText = "Ride a fish"
		local kind = fish and Config.FishById[fish:GetAttribute("FishType") :: string]
		p.ObjectText = if kind then kind.Name else ""
		p.Enabled = onDock and fish ~= nil
	end
end

function AquariumController.Start()
	-- the tank's popup: a click on our own tank from nearby (UI.TankPanel, task p1)
	TankPanel.init()
	Net.Ride.OnClientEvent:Connect(function(what: string, count: any, gained: any, _income: any, id: any)
		if what == "Deposited" and type(count) == "number" and type(gained) == "number" then
			deposited(count, gained, if type(id) == "string" then id else nil)
		end
	end)
	-- at the tank, a click on a caught slot puts that fish in
	Slots.Selected:Connect(function(index: number, item: State.Caught)
		if promptShown and prompt and prompt.Enabled then
			place(index, item)
		end
	end)
	-- anywhere else on the dock, a click on a caught slot holds that fish over the head; the held one's slot again,
	-- or an empty slot, puts it away (Config.Hold; the server checks it: AquariumService, Action "Hold")
	Slots.Picked:Connect(function(index: number, item: State.Caught?)
		if Config.Hold.On == 0 or State.Mode ~= "Dock" or (promptShown and prompt and prompt.Enabled) then
			return
		end
		local me = Players.LocalPlayer
		local holding = me:GetAttribute("HeldFish") ~= nil
		if not item or me:GetAttribute("HeldIndex") == index then
			if holding then
				Net.Action:FireServer("Hold", 0)
			end
		else
			Net.Action:FireServer("Hold", index, item.Id)
		end
	end)
	-- (looked at a few times a second: the catch, the mode and the chosen slot all change it)
	task.spawn(function()
		while true do
			updatePrompt()
			task.wait(0.2)
		end
	end)
	CollectionService:GetInstanceAddedSignal(TAG):Connect(function(model)
		-- (its PrimaryPart may come a moment after the model does)
		task.defer(add, model)
	end)
	CollectionService:GetInstanceRemovedSignal(TAG):Connect(function(model)
		swimmers[model] = nil
	end)
	for _, model in CollectionService:GetTagged(TAG) do
		add(model)
	end
	RunService.Heartbeat:Connect(function()
		local camera = workspace.CurrentCamera
		if not camera or not next(swimmers) then
			return
		end
		local eye = camera.CFrame.Position
		local far = Config.Aquarium.SeeFrom
		local now = workspace:GetServerTimeNow()
		for model, s in swimmers do
			if not model.Parent then
				swimmers[model] = nil
			elseif (s.centre - eye).Magnitude < far then
				-- round its lap, rising and sinking a little, nose first
				local angle = s.phase + now * s.pace
				local cos, sin = math.cos(angle), math.sin(angle)
				local at = s.centre
					+ Vector3.new(cos * s.reach.X, math.sin(now * 0.6 + s.phase) * s.reach.Y, sin * s.reach.Z)
				local way = Vector3.new(-sin * s.reach.X, 0, cos * s.reach.Z) * (if s.pace < 0 then -1 else 1)
				if way.Magnitude > 0.01 then
					s.root.CFrame = CFrame.lookAt(at, at + way)
				end
			end
		end
	end)
end

return AquariumController
