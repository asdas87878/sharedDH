--!strict
-- The fish in the tanks on the dock swim (AquariumService puts each in its place, anchored, with the tag "TankFish"
-- and the numbers of its lap: TankCentre, TankReach, TankPhase, TankPace). Each client moves them round itself, so
-- they cost no traffic and the server does nothing each frame. Only tanks near the camera are moved, and no table is
-- made in a frame. Moving the anchored Root moves the whole fish: its parts are joined to it.
-- Putting a catch in (Hugo, 2026-11-18: "make the player actually be able to place down fishes in aquarium once
-- back"): what a dive caught stays in the slots until the player puts it in. At our own tank a prompt (hold E, or tap
-- it) puts the chosen slot's fish in (the white ring: the newest, or the one clicked); while the prompt shows, a click
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

-- A catch went into our tank: look at it (the tank stands behind the pad we wake on), and say what it earns
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

-- The prompt at our own tank: shown on the dock while we carry fish
local prompt: ProximityPrompt? = nil
local promptShown = false

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

local function updatePrompt()
	local water = ownWater()
	local plot = water and water.Parent
	local spot = plot and plot:FindFirstChild("CollectPad")
	local at = if spot and spot:IsA("BasePart") then spot else water
	if not at then
		if prompt then
			prompt.Enabled = false
		end
		return
	end
	if not prompt or prompt.Parent ~= at then
		if prompt then
			prompt:Destroy()
		end
		local p = Instance.new("ProximityPrompt")
		p.Name = "PlaceFish"
		p.ActionText = "Put in tank"
		p.KeyboardKeyCode = Enum.KeyCode.E
		p.HoldDuration = 0.25
		p.MaxActivationDistance = 22
		p.RequiresLineOfSight = false
		p.Triggered:Connect(function()
			place(Slots.chosen())
		end)
		p.PromptShown:Connect(function()
			promptShown = true
		end)
		p.PromptHidden:Connect(function()
			promptShown = false
		end)
		p.Parent = at
		prompt = p
	end
	local list = State.Caught
	local carrying = list ~= nil and #list > 0
	local p = prompt :: ProximityPrompt
	p.Enabled = carrying and State.Mode == "Dock"
	if carrying then
		local _, item = Slots.chosen()
		local chosen = item or (list :: { State.Caught })[#(list :: { State.Caught })]
		local kind = Config.FishById[chosen.Id]
		p.ObjectText = if kind then kind.Name else chosen.Id
	end
end

function AquariumController.Start()
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
