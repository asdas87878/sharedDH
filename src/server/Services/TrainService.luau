--!strict
-- The training spot: ride the toy on your plot and your max Oxygen grows (Config.Train). It is the smallest thing that
-- lets the progression be played: more max Oxygen is more seconds on a fish, so deeper lands (docs/design/
-- progression.md). The gain is RideService's to give (RideService.train: only on the dock) and lasts the session; there
-- are no saves yet.
-- Where (since 2026-11-16, with the hub's models): on your own plot, at its toy ride. Every plot has a `TrainerSpot`
-- with a `TrainerRide` on it (the seahorse). A player with no plot (more players than plots) may use any free plot's.
-- Only a map with no such plots gets the old stand-in: the map's part named TrainSpot under the hub, or a pad made once
-- beside the dock's spawn, where standing is training. The player's "Training" attribute is true while they are
-- gaining, for the HUD and the ride.
-- The ride (Hugo, 2026-11-19, task h1, docs/design/trainer.md): the kit's square pad, block and post are taken away at
-- start, and the seahorse goes on a real grey coil (RideStyles.Trainer, RideStyles.coil) from the middle of its body's
-- underside down to a small round red pad. Walk up to it, or jump onto it, and you are seated on it (a weld to its
-- body; every machine plays the hop up and rocks the toy, and the rider with it: TrainerController); jump or walk off
-- and you hop off. Only a seated rider trains, and every half second they are told what they gained ("Gain"), for the
-- "+n" pops. The remote is Remotes.Trainer: client "Off" (let me off); server "On", ride | "Off", ride, reason |
-- "Gain", amount. The ride model carries Rider (the user id on it), SpringBase, SpringTop and Seat (CFrames at rest).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)
local RideService = require(script.Parent.RideService)
local RideStyles = require(ReplicatedStorage.Shared.RideStyles)

local TrainService = {}

local EVERY = 0.25 -- seconds between checks: the gain is given in steps this long
local PAD_COLOUR = Color3.fromRGB(90, 220, 255)

-- The trainer's sign, in the hub's sign style (the user's pick of 2026-11-16, "B": the gate's sign; docs/design/
-- ui.md): a blue board with a white rim and a darker copy under it, "TRAIN" in white letters with a dark edge, and
-- one line saying what it does. It is sized in studs, so it keeps its size in the world, and is not drawn past 220
-- studs. Only what is true today is on it: the ride's level and the next ride's price come with the upgrade.
-- Every plot's ride has one. Each player's own machine hides the others' (Client.UI.HubSigns), so a player sees the
-- sign once, over their own ride; nothing here sets Enabled after the sign is made.
local SIGN_BLUE = Color3.fromRGB(30, 140, 255)
local SIGN_INK = Color3.fromRGB(16, 36, 63)

local function trainSign(parent: BasePart, lift: number, riding: boolean?)
	local sign = Instance.new("BillboardGui")
	sign.Name = "Sign"
	sign.Size = UDim2.fromScale(17, 6.4)
	sign.StudsOffsetWorldSpace = Vector3.new(0, lift, 0)
	sign.MaxDistance = 220
	sign.LightInfluence = 0
	sign.AlwaysOnTop = false
	local shadow = Instance.new("Frame")
	shadow.Position = UDim2.fromScale(0, 0.08)
	shadow.Size = UDim2.fromScale(1, 0.92)
	shadow.BackgroundColor3 = SIGN_BLUE:Lerp(Color3.new(0, 0, 0), 0.6)
	shadow.BorderSizePixel = 0
	shadow.Parent = sign
	local board = Instance.new("Frame")
	board.Name = "Board"
	board.Size = UDim2.fromScale(1, 0.92)
	board.BackgroundColor3 = SIGN_BLUE
	board.BorderSizePixel = 0
	board.ZIndex = 2
	board.Parent = sign
	for _, frame in { shadow, board } do
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0.1, 0)
		corner.Parent = frame
	end
	local rim = Instance.new("UIStroke")
	rim.Thickness = 4
	rim.Color = Color3.new(1, 1, 1)
	rim.Parent = board
	local function line(name: string, text: string, y: number, high: number, colour: Color3, edge: number)
		local label = Instance.new("TextLabel")
		label.Name = name
		label.BackgroundTransparency = 1
		label.Position = UDim2.fromScale(0.06, y)
		label.Size = UDim2.fromScale(0.88, high)
		label.Font = Enum.Font.LuckiestGuy
		label.TextScaled = true
		label.TextColor3 = colour
		label.Text = text
		label.ZIndex = 3
		label.Parent = board
		local stroke = Instance.new("UIStroke")
		stroke.Thickness = edge
		stroke.Color = SIGN_INK
		stroke.LineJoinMode = Enum.LineJoinMode.Round
		stroke.Parent = label
	end
	line("Title", "TRAIN", 0.1, 0.56, Color3.new(1, 1, 1), 3)
	line(
		"What",
		if riding then "ride it: more Oxygen" else "stand on it: more Oxygen",
		0.7,
		0.2,
		Color3.fromRGB(214, 234, 255),
		1.5
	)
	sign.Parent = parent
end

local function standIn(dock: CFrame): BasePart
	local t = Config.Train
	local pad = Instance.new("Part")
	pad.Name = "TrainSpot"
	pad.Shape = Enum.PartType.Cylinder
	pad.Size = Vector3.new(0.6, t.Radius * 2, t.Radius * 2)
	pad.Anchored = true
	pad.CanCollide = false
	pad.CanQuery = false
	pad.Material = Enum.Material.SmoothPlastic
	pad.Color = PAD_COLOUR
	pad.TopSurface = Enum.SurfaceType.Smooth
	pad.BottomSurface = Enum.SurfaceType.Smooth
	local at = dock.Position + dock.RightVector * t.Right + dock.LookVector * t.Ahead
	-- (a cylinder's round faces are along its X: stood on end, just above the hub's floor)
	pad.CFrame = CFrame.new(at.X, dock.Position.Y - 0.6, at.Z) * CFrame.Angles(0, 0, math.rad(90))
	trainSign(pad, 12)
	pad.Parent = workspace
	return pad
end

-- A sign over a plot's ride. The ride stands in front of the right end of its tank's sign (SignBoard: 4 studs tall,
-- its top 26 studs up), and at 21 studs the trainer's board lay across that sign's end as seen from the front of
-- the plot, cutting off its words. Its foot is now above the tank sign's top, and the ride is nearer the viewer than
-- the tank's sign, so from the front the two are clear of each other at any distance: the tank's sign, and the
-- trainer's above its end.
local function label(spot: BasePart)
	if spot:FindFirstChild("Sign") then
		return
	end
	trainSign(spot, 30.5, true)
end

-- One plot's ride, made over (see the top of the file)
type Ride = {
	Plot: Instance,
	Name: string,
	Model: Model,
	Body: BasePart,
	Spot: BasePart,
	Axis: Vector3, -- the coil's foot: the middle of the pad's top
	Bottom: number, -- the body's underside (y)
	Seat: CFrame, -- where a rider's root sits, at rest
	Rider: Player?,
	Weld: Weld?,
}

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

local function part(name: string, size: Vector3, at: CFrame, colour: Color3, parent: Instance, round: boolean?): Part
	local p = Instance.new("Part")
	p.Name = name
	if round then
		p.Shape = Enum.PartType.Cylinder
	end
	p.Size = size
	p.CFrame = at
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.CastShadow = true
	p.Material = Enum.Material.SmoothPlastic
	p.Color = colour
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

-- (a cylinder's round faces are along its X: this stands one on end)
local ON_END = CFrame.Angles(0, 0, math.rad(90))

-- Takes the kit's pad, block, post, coils and plate away, sets the toy down to the coil's length over a small red
-- pad, and builds the coil between them
local function makeRide(plot: Instance, spot: BasePart): Ride?
	local model = plot:FindFirstChild("TrainerRide")
	local toy = model and model:FindFirstChild("Toy")
	local body = toy and toy:FindFirstChild("Body")
	if not (model and model:IsA("Model") and body and body:IsA("BasePart")) then
		return nil
	end
	local t = RideStyles.Trainer
	for _, child in plot:GetChildren() do
		if
			child:IsA("BasePart")
			and (child.Name == "TrainerBase" or child.Name == "TrainerSpring" or child.Name == "SpringCoil")
		then
			child:Destroy()
		end
	end
	local plate = model:FindFirstChild("TrainerRide")
	if plate and plate:IsA("BasePart") then
		model.WorldPivot = plate.CFrame
		plate:Destroy()
	end
	-- the kit's square red pad stays as the place the sign hangs from, unseen
	spot.Transparency = 1
	for _, d in spot:GetDescendants() do
		if d:IsA("Decal") then
			d.Transparency = 1
		end
	end
	local floor = spot.Position.Y - spot.Size.Y / 2
	local head = (toy :: Instance):FindFirstChild("Head")
	local ahead = if head and head:IsA("BasePart") then flat(head.Position - body.Position) else Vector3.zero
	if ahead.Magnitude < 0.1 then
		ahead = flat(model:GetPivot().LookVector)
	end
	ahead = ahead.Unit
	local padTop = floor + t.PadHigh
	-- the body's underside the coil's length over the pad (the toy's parts are turned about y only)
	local lift = padTop + t.Length - (body.Position.Y - body.Size.Y / 2)
	model:PivotTo(model:GetPivot() + Vector3.new(0, lift, 0))
	local axis = Vector3.new(body.Position.X, padTop, body.Position.Z)
	local turn = CFrame.lookAt(Vector3.zero, ahead)
	local bottom = body.Position.Y - body.Size.Y / 2

	local pad = part(
		"TrainerPad",
		Vector3.new(t.PadHigh, t.PadRadius * 2, t.PadRadius * 2),
		CFrame.new(axis.X, floor + t.PadHigh / 2, axis.Z) * ON_END,
		t.PadColour,
		plot,
		true
	)
	pad.CanCollide = true
	-- a lighter top, a little proud: the pad's lit face
	part(
		"TrainerPadTop",
		Vector3.new(0.2, t.PadRadius * 2 - 0.5, t.PadRadius * 2 - 0.5),
		CFrame.new(axis.X, padTop + 0.06, axis.Z) * ON_END,
		t.PadColour:Lerp(Color3.new(1, 1, 1), 0.18),
		plot,
		true
	)

	local spring = Instance.new("Model")
	spring.Name = "TrainerSpring"
	local base = CFrame.new(axis) * turn
	local top = CFrame.new(axis + Vector3.new(0, t.Length, 0)) * turn
	local capAcross = (t.Radius + t.Wire / 2 + 0.15) * 2
	part(
		"CapBottom",
		Vector3.new(0.3, capAcross, capAcross),
		base * CFrame.new(0, 0.15, 0) * ON_END,
		t.CapColour,
		spring,
		true
	)
	part(
		"CapTop",
		Vector3.new(0.4, capAcross, capAcross),
		top * CFrame.new(0, 0.1, 0) * ON_END,
		t.CapColour,
		spring,
		true
	)
	for k, piece in RideStyles.coil(base, top) do
		part("Coil" .. k, Vector3.new(t.Wire, t.Wire, piece.Length), piece.At, t.Colour, spring)
	end
	spring.Parent = plot

	local at = body.Position + Vector3.new(0, t.Seat.Y, 0) + ahead * t.Seat.Z
	local seat = CFrame.lookAt(at, at + ahead)
	model:SetAttribute("SpringBase", base)
	model:SetAttribute("SpringTop", top)
	model:SetAttribute("Seat", seat)
	model:SetAttribute("Rider", nil)
	return {
		Plot = plot,
		Name = plot.Name,
		Model = model,
		Body = body,
		Spot = spot,
		Axis = axis,
		Bottom = bottom,
		Seat = seat,
		Rider = nil,
		Weld = nil,
	}
end

-- The plots' rides, by the plot's name (none on a map without them)
local function plotRides(): { [string]: Ride }
	local rides: { [string]: Ride } = {}
	local blockout = workspace:FindFirstChild("ClaudeBlockout")
	local hub = blockout and blockout:FindFirstChild("Dock")
	local plots = hub and hub:FindFirstChild("Plots")
	if plots then
		for _, plot in plots:GetChildren() do
			local spot = plot:FindFirstChild("TrainerSpot")
			if spot and spot:IsA("BasePart") then
				label(spot)
				local ride = makeRide(plot, spot)
				if ride then
					rides[plot.Name] = ride
				end
			end
		end
	end
	return rides
end

local function findSpot(): BasePart?
	local blockout = workspace:FindFirstChild("ClaudeBlockout")
	local hub = blockout and blockout:FindFirstChild("Dock")
	local found = hub and hub:FindFirstChild("TrainSpot", true)
	if found and found:IsA("BasePart") then
		return found
	end
	-- the dock's spawn, published by RideService when it starts (it may start after us)
	local dock = Net.Folder:GetAttribute("Dock")
	local waited = 0
	while typeof(dock) ~= "CFrame" and waited < 10 do
		waited += task.wait(0.25)
		dock = Net.Folder:GetAttribute("Dock")
	end
	if typeof(dock) == "CFrame" then
		return standIn(dock)
	end
	return nil
end

local function gain(player: Player, dt: number): (boolean, number)
	local t = Config.Train
	local max = player:GetAttribute("MaxOxygen")
	local share = if type(max) == "number" then max * t.Share else 0
	local amount = (t.Rate + share) * dt
	return RideService.train(player, amount), amount
end

-- The old way, on a map with no plots: standing on the one spot is training
local function standing(spot: BasePart)
	local training: { [Player]: boolean } = {}
	Players.PlayerRemoving:Connect(function(player)
		training[player] = nil
	end)
	while true do
		local dt = task.wait(EVERY)
		for _, player in Players:GetPlayers() do
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			local on = false
			if root and root:IsA("BasePart") then
				local away = (root.Position - spot.Position) * Vector3.new(1, 0, 1)
				if away.Magnitude <= Config.Train.Radius and math.abs(root.Position.Y - spot.Position.Y) < 12 then
					on = gain(player, dt)
				end
			end
			if training[player] ~= on then
				training[player] = on
				player:SetAttribute("Training", on)
			end
		end
	end
end

type Rider = { Ride: Ride?, OffAt: number, Clear: boolean, Gained: number, ToldAt: number }

local CHECK = 0.1 -- seconds between looks: a walk-up seats you this soon

function TrainService.Start()
	if Config.Train.On <= 0 then
		return
	end
	local rides = plotRides()
	if next(rides) == nil then
		local spot = findSpot()
		if not spot then
			warn("[TrainService] no training spot: the map has no plots, no TrainSpot and no dock spawn to put one by")
			return
		end
		standing(spot)
		return
	end
	local remote = Instance.new("RemoteEvent")
	remote.Name = "Trainer"
	remote.Parent = Net.Folder
	local riders: { [Player]: Rider } = {}

	local function riderOf(player: Player): Rider
		local r = riders[player]
		if not r then
			r = { Ride = nil, OffAt = -math.huge, Clear = true, Gained = 0, ToldAt = 0 }
			riders[player] = r
		end
		return r
	end

	local function off(player: Player, r: Rider, reason: string)
		local ride = r.Ride
		if not ride then
			return
		end
		if ride.Weld then
			ride.Weld:Destroy()
			ride.Weld = nil
		end
		ride.Rider = nil
		ride.Model:SetAttribute("Rider", nil)
		r.Ride = nil
		r.OffAt = os.clock()
		r.Clear = false
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid.Sit = false
		end
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") then
			pcall(function()
				root:SetNetworkOwner(player)
			end)
		end
		if player.Parent then
			player:SetAttribute("Training", false)
			player:SetAttribute("TrainerRide", nil)
			remote:FireClient(player, "Off", ride.Model, reason)
		end
	end

	local function on(player: Player, r: Rider, ride: Ride, root: BasePart, humanoid: Humanoid)
		local weld = Instance.new("Weld")
		weld.Name = "TrainerWeld"
		weld.Part0 = ride.Body
		weld.Part1 = root
		weld.C0 = ride.Body.CFrame:ToObjectSpace(ride.Seat)
		weld:SetAttribute("Rider", player.UserId)
		weld.Parent = ride.Body
		humanoid.Sit = true
		ride.Weld = weld
		ride.Rider = player
		ride.Model:SetAttribute("Rider", player.UserId)
		r.Ride = ride
		r.Gained = 0
		r.ToldAt = os.clock()
		player:SetAttribute("TrainerRide", ride.Name)
		remote:FireClient(player, "On", ride.Model)
	end

	remote.OnServerEvent:Connect(function(player, what)
		local r = riders[player]
		if what == "Off" and r and r.Ride then
			off(player, r, "Asked")
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		local r = riders[player]
		if r then
			off(player, r, "Gone")
			riders[player] = nil
		end
	end)

	local t = RideStyles.Trainer
	while true do
		local dt = task.wait(CHECK)
		for _, player in Players:GetPlayers() do
			local r = riderOf(player)
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			local alive = root ~= nil and root:IsA("BasePart") and humanoid ~= nil and humanoid.Health > 0
			local docked = RideService.stateOf(player) == "Dock"
			local ride = r.Ride
			if ride then
				if not alive or not docked or not ride.Weld or ride.Weld.Parent == nil or ride.Weld.Part1 ~= root then
					off(player, r, "Lost")
				else
					local trained, amount = gain(player, dt)
					if trained then
						r.Gained += amount
					end
					if player:GetAttribute("Training") ~= trained then
						player:SetAttribute("Training", trained)
					end
					if os.clock() - r.ToldAt >= t.Every then
						r.ToldAt = os.clock()
						if r.Gained > 0 then
							remote:FireClient(player, "Gain", r.Gained)
						end
						r.Gained = 0
					end
				end
			elseif alive and docked and root and root:IsA("BasePart") and humanoid then
				-- which ride: our own plot's; with no plot (or none of ours), the nearest free one
				local own = player:GetAttribute("Plot")
				local here: Ride? = if type(own) == "string" then rides[own] else nil
				if not here then
					local best = math.huge
					for _, other in rides do
						local far = flat(other.Axis - root.Position).Magnitude
						if far < best and (other.Rider == nil or other.Rider == player) then
							best, here = far, other
						end
					end
				end
				if here then
					local far = flat(here.Axis - root.Position).Magnitude
					local y = root.Position.Y
					if far > t.Reach + 1.5 then
						r.Clear = true
					end
					local walkedUp = r.Clear and far <= t.Reach and y > here.Axis.Y - 2 and y < here.Bottom + 12
					local landed = os.clock() - r.OffAt > 0.6 and far <= t.OnTop and y >= here.Bottom
					if here.Rider == nil and (walkedUp or landed) then
						on(player, r, here, root :: BasePart, humanoid)
					end
				end
				if player:GetAttribute("Training") == true then
					player:SetAttribute("Training", false)
				end
			end
		end
	end
end

return TrainService
