--!strict
-- The fish in the tanks on the dock swim (AquariumService puts each in its place, anchored, with the tag "TankFish"
-- and the numbers of its lap: TankCentre, TankReach, TankPhase, TankPace). Each client moves them round itself, so
-- they cost no traffic and the server does nothing each frame. Only tanks near the camera are moved, and no table is
-- made in a frame. Moving the anchored Root moves the whole fish: its parts are joined to it. Their joints' swim is
-- TankRideController's (task b4).
-- Putting a catch in (Hugo, 2026-11-18: "make the player actually be able to place down fishes in aquarium once
-- back"): what a dive caught stays in the slots until the player puts it in. A click or number key on a caught slot
-- holds it over the head; a click (a tap) on our own tank opens its popup (UI.TankPanel), where PUT IN and PUT ALL IN
-- put fish in and RIDE A FISH gets on one (Hugo, 2026-11-20, task c1: no prompt on the glass, no click-to-add; the
-- tank is outlined under the mouse). The server checks it all (AquariumService, Action "Tank").
-- And the moment a fish goes in (Ride "Deposited"): the view turns to our tank, and a line rises over the tank saying
-- what it adds a second. A stand-in for the real thing (a sound, the fish dropping in); drawn in the shop kit's look
-- (UI.TankPrompt, task s3).
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)
local State = require(script.Parent.Parent.Lib.State)
local Slots = require(script.Parent.Parent.UI.Slots)
local TankPanel = require(script.Parent.Parent.UI.TankPanel)
local TankPrompt = require(script.Parent.Parent.UI.TankPrompt)

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
		-- A tank's fish is its real size (task b4, Config.Aquarium.ShowShare 1), so one longer than its lap is wide
		-- would whirl on the spot: it comes round slower instead, its nose going no faster than a small fish swims.
		-- (TankRideService.lapOf works out the same lap: change both)
		local kind = Config.FishById[tostring(model:GetAttribute("FishType"))]
		local long = if kind then kind.Size.Z * Config.sizeScale(Config.sizeTierOf(model), kind) else 0
		pace *= math.min(1, math.max((reach.X + reach.Z) / 2, 1) / math.max(long / 2, 1))
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
local function deposited(count: number, gained: number, id: string?, more: number)
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
	-- (the line over the tank: UI.TankPrompt, in the shop kit's look)
	TankPrompt.deposited(water, count, gained, id, more)
end

function AquariumController.Start()
	-- the tank's popup: a click on our own tank from nearby (UI.TankPanel, task p1)
	TankPanel.init()
	Net.Ride.OnClientEvent:Connect(function(what: string, count: any, gained: any, _income: any, id: any, more: any)
		if what == "Deposited" and type(count) == "number" and type(gained) == "number" then
			deposited(
				count,
				gained,
				if type(id) == "string" then id else nil,
				if type(more) == "number" then more else 0
			)
		end
	end)
	-- on the dock, a click (or number key) on a caught slot holds that fish over the head, at the tank too (only the
	-- tank's popup puts one in); the held one's slot again, or an empty slot, puts it away (Config.Hold;
	-- the server checks it: AquariumService, Action "Hold")
	Slots.Picked:Connect(function(index: number, item: State.Caught?)
		if Config.Hold.On == 0 or State.Mode ~= "Dock" then
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
