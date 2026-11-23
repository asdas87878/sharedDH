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
-- and you hop off. Only a seated rider trains: once for every whole second seated the level's whole Oxygen is added
-- and they are told ("Gain", a whole number), for the "+n" pops (task e1: no decimals, no share of max; a part of a
-- second is dropped on getting off, and starts again from nothing on an upgrade). The remote is Remotes.Trainer: client "Off" (let me off); server "On", ride | "Off", ride, reason |
-- "Gain", amount. The ride model carries Rider (the user id on it), SpringBase, SpringTop and Seat (CFrames at rest).
-- The levels (Hugo, 2026-11-19, task sh1: the seahorse draft built): every player has a TrainerLevel, 1 to 12 (the
-- player's attribute; ours, for the session, beside the tank's coins), and each plot's ride shows its owner's: its
-- own seahorse and stand (ReplicatedStorage.TrainerModels.T<n>, art/creatures/Seahorse/tiers/install_tiers.py), the
-- coil in that level's colours from the stand's top straight into the seahorse's body (no plate). A seated rider gains that
-- level's Oxygen a second (Config.Train.Levels). The owner asks to go up a level by the ride ("Up"; a click on the
-- cash block of their upgrade sign, UI.UpgradeSign, task e2): alive, on the dock, within Train.UpgradeNear of its
-- coil or Train.SignNear of the sign, one ask in Train.UpAgain, for the level's price (free while Train.Free is 1); the ride is rebuilt at once (a rider stays seated on the new one) and the model's Build and UpgradeAt tell
-- every machine to play the upgrade. Server "Up", level | "UpNo", reason. With no models installed the kit's toy
-- stays as before and only the numbers change.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)
local AquariumService = require(script.Parent.AquariumService)
local RideService = require(script.Parent.RideService)
local RideStyles = require(ReplicatedStorage.Shared.RideStyles)

local TrainService = {}

local EVERY = 0.25 -- seconds between checks: the gain is given in steps this long
local PAD_COLOUR = Color3.fromRGB(90, 220, 255)

-- The trainer's sign, in the hub's sign style (the user's pick of 2026-11-16, "B": the gate's sign; docs/design/
-- ui.md): a blue board with a white rim and a darker copy under it, "TRAIN" in white letters with a dark edge, and
-- one line saying what it does. It is sized in studs, so it keeps its size in the world, and is not drawn past 220
-- studs. It says only what the ride is for: its level, the next one and the prices are on the upgrade sign beside
-- the ride (upgradeSign, below; task s2).
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

-- A sign over a plot's ride: its foot is 19.5 studs up, clear of the tallest seahorse (17.9). (30.5 before the
-- pens of 2026-11-23: it had to clear the old tank's own sign, whose top stood 26 up; the pens' is on the gate, 10 up.)
local function label(spot: BasePart)
	if spot:FindFirstChild("Sign") then
		return
	end
	trainSign(spot, 22, true)
end

local function levelRow(n: number): { Name: string, Oxygen: number, Price: number }
	local levels = Config.Train.Levels
	return levels[math.clamp(n, 1, #levels)]
end

-- The upgrade sign's board and post (task s2: Ride a Dino's "Upgrade Machine" sign, ours): beside the ride, toward
-- the collect pad and a little toward the hub, facing the hub (Config.Train.Sign; tools/map/hub_kit.py builds the
-- same parts, so a map from it already has them and this does nothing). What it says is each machine's to write
-- (Client.UI.UpgradeSign); the board is the colour of the writing's border.
local SIGN_EDGE = Color3.fromRGB(10, 12, 22)
local SIGN_POST = Color3.fromRGB(28, 32, 46)

local function upgradeSign(plot: Instance, spot: BasePart)
	if plot:FindFirstChild("UpgradeBoard") then
		return
	end
	local s = Config.Train.Sign
	local floor = spot.Position.Y - spot.Size.Y / 2
	local at = spot.CFrame:PointToWorldSpace(Vector3.new(s.Side, 0, s.Ahead))
	local z = spot.CFrame.ZVector
	local front = Vector3.new(z.X, 0, z.Z).Unit
	local function piece(name: string, size: Vector3, middle: Vector3, colour: Color3): Part
		local p = Instance.new("Part")
		p.Name = name
		p.Size = size
		p.CFrame = CFrame.lookAt(middle, middle + front)
		p.Anchored = true
		p.CanCollide = true
		p.CanTouch = false
		p.Material = Enum.Material.SmoothPlastic
		p.Color = colour
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.Parent = plot
		return p
	end
	local postHigh = s.Foot + s.High / 2
	piece(
		"UpgradePost",
		Vector3.new(s.Post, postHigh, s.Post),
		Vector3.new(at.X, floor + postHigh / 2, at.Z) - front * (s.Thick / 2 + s.Post / 2),
		SIGN_POST
	)
	piece(
		"UpgradeBoard",
		Vector3.new(s.Wide, s.High, s.Thick),
		Vector3.new(at.X, floor + s.Foot + s.High / 2, at.Z),
		SIGN_EDGE
	)
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
	Level: number, -- the level it shows (0: the kit's toy, not yet made over)
	Foot: Vector3, -- the middle of the floor under the coil
	Ahead: Vector3, -- the way the seahorse faces (flat)
	Build: number,
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

-- The coil, between a base frame on the stand (its up along the coil) and a top frame under the toy, with the two
-- round plates it is fixed to: in the kit toy's grey, or a level's own colours (RideStyles.CoilColours: every other
-- half turn glows from level 7)
local function buildSpring(plot: Instance, base: CFrame, top: CFrame, level: number)
	local t = RideStyles.Trainer
	local old = plot:FindFirstChild("TrainerSpring")
	if old then
		old:Destroy()
	end
	local colours = if level > 0 then RideStyles.CoilColours[level] else nil
	local wire = if colours then Color3.fromHex(colours[1] :: string) else t.Colour
	local glow = if colours and colours[2] then Color3.fromHex(colours[2] :: string) else nil
	local caps = if colours then Color3.fromHex(colours[3] :: string) else t.CapColour
	local spring = Instance.new("Model")
	spring.Name = "TrainerSpring"
	local capAcross = (t.Radius + t.Wire / 2 + 0.15) * 2
	part(
		"CapBottom",
		Vector3.new(0.3, capAcross, capAcross),
		base * CFrame.new(0, 0.15, 0) * ON_END,
		caps,
		spring,
		true
	)
	part("CapTop", Vector3.new(0.4, capAcross, capAcross), top * CFrame.new(0, 0.1, 0) * ON_END, caps, spring, true)
	local half = t.PerTurn / 2
	for k, piece in RideStyles.coil(base, top) do
		local lit = glow ~= nil and math.floor((k - 1) / half) % 2 == 1
		local p = part(
			"Coil" .. k,
			Vector3.new(t.Wire, t.Wire, piece.Length),
			piece.At,
			if lit then glow :: Color3 else wire,
			spring
		)
		if lit then
			p.Material = Enum.Material.Neon
		end
	end
	spring.Parent = plot
end

-- The first look at a plot's ride: takes the kit's pad, block, post, coils and plate away and notes where the coil
-- stands and which way the toy faces; then the ride is built at level 1 (build). With no level models installed it
-- is the kit's toy, set down to the coil's length over a small red pad, as before the levels.
local function makeRide(plot: Instance, spot: BasePart): Ride?
	local model = plot:FindFirstChild("TrainerRide")
	local toy = model and model:FindFirstChild("Toy")
	local body = toy and toy:FindFirstChild("Body")
	if not (model and model:IsA("Model") and body and body:IsA("BasePart")) then
		return nil
	end
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
	-- (the floor you see may be higher than the spot's underside: a plot's Pad, seen, can cover the trainer's
	-- corner, 0.4 studs over the hub's floor, and buried the levels' thin pads. The highest seen top of the plot's
	-- own parts under the coil, within a stud of the spot's underside)
	local under = Vector3.new(body.Position.X, floor, body.Position.Z)
	for _, child in plot:GetChildren() do
		if child:IsA("BasePart") and child ~= spot and child.Transparency < 1 then
			local top = child.Position.Y + child.Size.Y / 2
			local at = child.CFrame:PointToObjectSpace(Vector3.new(under.X, child.Position.Y, under.Z))
			local half = child.Size / 2
			if math.abs(at.X) <= half.X and math.abs(at.Z) <= half.Z and top > floor and top < floor + 1 then
				floor = top
			end
		end
	end
	local head = (toy :: Instance):FindFirstChild("Head")
	local ahead = if head and head:IsA("BasePart") then flat(head.Position - body.Position) else Vector3.zero
	if ahead.Magnitude < 0.1 then
		ahead = flat(model:GetPivot().LookVector)
	end
	ahead = ahead.Unit
	local ride: Ride = {
		Plot = plot,
		Name = plot.Name,
		Model = model,
		Body = body,
		Spot = spot,
		Axis = Vector3.new(body.Position.X, floor, body.Position.Z),
		Bottom = 0,
		Seat = CFrame.identity,
		Rider = nil,
		Weld = nil,
		Level = 0,
		Foot = Vector3.new(body.Position.X, floor, body.Position.Z),
		Ahead = ahead,
		Build = 0,
	}
	local t = RideStyles.Trainer
	local templates = ReplicatedStorage:FindFirstChild("TrainerModels")
	if templates and templates:FindFirstChild("T1") then
		return ride
	end
	-- the kit's toy (no level models): the body's underside the coil's length over a small red pad
	local padTop = floor + t.PadHigh
	local lift = padTop + t.Length - (body.Position.Y - body.Size.Y / 2)
	model:PivotTo(model:GetPivot() + Vector3.new(0, lift, 0))
	local axis = Vector3.new(body.Position.X, padTop, body.Position.Z)
	local turn = CFrame.lookAt(Vector3.zero, ahead)
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
	local base = CFrame.new(axis) * turn
	local top = CFrame.new(axis + Vector3.new(0, t.Length, 0)) * turn
	buildSpring(plot, base, top, 0)
	local at = body.Position + Vector3.new(0, t.Seat.Y, 0) + ahead * t.Seat.Z
	ride.Axis = axis
	ride.Bottom = body.Position.Y - body.Size.Y / 2
	ride.Seat = CFrame.lookAt(at, at + ahead)
	model:SetAttribute("SpringBase", base)
	model:SetAttribute("SpringTop", top)
	model:SetAttribute("Seat", ride.Seat)
	model:SetAttribute("Rider", nil)
	return ride
end

-- Builds a ride at a level from its model (ReplicatedStorage.TrainerModels.T<level>): the seahorse (the model's Toy)
-- in the ride's model, the stand on the floor (TrainerStand, with an unseen block to stand on, TrainerPad), the coil
-- from the stand's top straight into the body's underside (no plate: SpringAt), the seat from the saddle (SeatAt). A seated rider is welded to the new
-- body. False when the level has no model (nothing changes).
local function build(ride: Ride, level: number, upgrade: boolean): boolean
	local templates = ReplicatedStorage:FindFirstChild("TrainerModels")
	local template = templates and templates:FindFirstChild("T" .. level)
	if not (template and template:IsA("Model")) then
		return false
	end
	local t = RideStyles.Trainer
	local k = t.Scale
	local foot = template:GetAttribute("Foot") :: Vector3
	local standTop = template:GetAttribute("StandTop") :: number
	local springAt = template:GetAttribute("SpringAt") :: Vector3
	local seatAt = template:GetAttribute("SeatAt") :: Vector3
	local copy = template:Clone()
	copy:ScaleTo(k)
	local toy = copy:FindFirstChild("Toy") :: Model
	local stand = copy:FindFirstChild("Stand") :: Model
	local body = toy:FindFirstChild("Body") :: BasePart
	-- (after the scale the model's space is k times smaller about its origin: a point p of it is at p * k)
	toy.WorldPivot = CFrame.identity
	stand.WorldPivot = CFrame.identity
	-- the stand on the floor, its axis on the coil's foot; the seahorse over it, the coil's length up, the point where
	-- the coil meets its body on the axis; both facing the way the ride faces (the head toward the model's -Z)
	local high = (standTop - foot.Y) * k
	local axis = ride.Foot + Vector3.new(0, high, 0)
	local meet = axis + Vector3.new(0, t.SpringLength, 0)
	local standPlace = CFrame.lookAt(ride.Foot, ride.Foot + ride.Ahead) * CFrame.new(-foot * k)
	local place = CFrame.lookAt(meet, meet + ride.Ahead) * CFrame.new(-springAt * k)
	stand:PivotTo(standPlace)
	toy:PivotTo(place)
	local plot = ride.Plot
	local rider, weld = ride.Rider, ride.Weld
	for _, name in { "TrainerStand", "TrainerPad", "TrainerPadTop" } do
		local old = plot:FindFirstChild(name)
		if old then
			old:Destroy()
		end
	end
	local oldToy = ride.Model:FindFirstChild("Toy")
	if oldToy then
		oldToy:Destroy() -- (and a rider's weld on its body with it)
	end
	toy.Parent = ride.Model
	stand.Name = "TrainerStand"
	stand.Parent = plot
	copy:Destroy()
	-- what you stand on: the stand's footprint, up to its top (the posts and crystals are only seen)
	local standPart = stand:FindFirstChild("Stand")
	local turn = CFrame.lookAt(Vector3.zero, ride.Ahead)
	if standPart and standPart:IsA("BasePart") then
		local block = part(
			"TrainerPad",
			Vector3.new(standPart.Size.X, high, standPart.Size.Z * 0.9),
			CFrame.new(Vector3.new(standPart.Position.X, ride.Foot.Y + high / 2, standPart.Position.Z)) * turn,
			Color3.new(1, 1, 1),
			plot
		)
		block.Transparency = 1
		block.CanCollide = true
		block.CastShadow = false
	end
	local base = CFrame.new(axis) * turn
	local top = CFrame.new(meet) * turn
	buildSpring(plot, base, top, level)
	local at = place * (seatAt * k) + Vector3.new(0, t.SeatLift, 0) - ride.Ahead * t.SeatBack
	ride.Body = body
	ride.Axis = axis
	ride.Bottom = body.Position.Y - body.Size.Y / 2
	ride.Seat = CFrame.lookAt(at, at + ride.Ahead)
	ride.Level = level
	ride.Build += 1
	ride.Model:SetAttribute("SpringBase", base)
	ride.Model:SetAttribute("SpringTop", top)
	ride.Model:SetAttribute("Seat", ride.Seat)
	ride.Model:SetAttribute("Level", level)
	ride.Model:SetAttribute("Title", levelRow(level).Name)
	if upgrade then
		ride.Model:SetAttribute("UpgradeAt", workspace:GetServerTimeNow())
	end
	local count = 0
	for _, d in ride.Model:GetDescendants() do
		if d:IsA("BasePart") then
			count += 1
		end
	end
	ride.Model:SetAttribute("PartCount", count)
	ride.Model:SetAttribute("Build", ride.Build)
	-- a rider stays on: welded to the new body at the new seat
	if rider and weld then
		local root = weld.Part1
		local again = Instance.new("Weld")
		again.Name = "TrainerWeld"
		again.Part0 = body
		again.Part1 = root
		again.C0 = body.CFrame:ToObjectSpace(ride.Seat)
		again:SetAttribute("Rider", rider.UserId)
		again.Parent = body
		ride.Weld = again
	end
	return true
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
				upgradeSign(plot, spot)
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

-- Each player's trainer level, for the session (with the tank's coins, to be saved with them); the attribute
-- TrainerLevel mirrors it
local levels: { [Player]: number } = {}

local function levelOf(player: Player): number
	return levels[player] or 1
end

-- (set in Start once the plots' rides are there: a level set from outside, the seated time settled first and the
-- player's ride shown at once; nil on a map with no plot rides)
local relevel: ((player: Player, level: number) -> ())? = nil

-- For saving (src/server/Lib/SaveParts.luau, the UI chat's saving, part "Trainer"): the seahorse's level, 1 to
-- #Train.Levels (1 from the moment they join). nil while we don't have the player (not joined yet, gone, or no
-- trainer: Train.On 0). Doesn't yield.
function TrainService.levelOf(player: Player): number?
	return levels[player]
end

-- For saving (SaveParts, part "Trainer", which never lowers it): the level set to `n`, a whole level that exists
-- (clamped to 1 .. #Train.Levels), no coins taken; the TrainerLevel attribute and the player's ride shown at once, as
-- after buying a level but without the upgrade's show. False for a player we don't have or a NaN. Doesn't yield.
function TrainService.setLevel(player: Player, n: number): boolean
	if levels[player] == nil or type(n) ~= "number" or n ~= n then
		return false
	end
	local level = math.clamp(math.floor(n), 1, #Config.Train.Levels)
	if relevel then
		relevel(player, level)
	else
		levels[player] = level
		player:SetAttribute("TrainerLevel", level)
	end
	return true
end

-- Training in whole seconds (task e1): `carry` is the part of a second already seated, `dt` more. Each whole second
-- it completes gives the level's whole Oxygen (Config.Train.Levels; Rate when there is no such table), never a share
-- of max. Returns the whole Oxygen given (0 when none was, or the server would not take it) and the carry left.
local function gain(player: Player, carry: number, dt: number, level: number): (number, number)
	local t = Config.Train
	local ticks, left = Config.trainTicks(carry, dt)
	if ticks <= 0 then
		return 0, left
	end
	local each = math.floor((if t.Levels then levelRow(level).Oxygen else t.Rate) + 0.5)
	local amount = ticks * each
	return if RideService.train(player, amount) then amount else 0, left
end

-- The old way, on a map with no plots: standing on the one spot is training
local function standing(spot: BasePart)
	local training: { [Player]: boolean } = {}
	local carry: { [Player]: number } = {} -- (the part of a second on it so far: task e1)
	-- (when the time on it was last counted: a player first seen on it counts from that look, never from the look
	-- before, when they were not on it yet: grade issue 2)
	local since: { [Player]: number } = {}
	Players.PlayerRemoving:Connect(function(player)
		training[player] = nil
		carry[player] = nil
		since[player] = nil
	end)
	while true do
		task.wait(EVERY)
		local now = os.clock()
		for _, player in Players:GetPlayers() do
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			local on = false
			if root and root:IsA("BasePart") then
				local away = (root.Position - spot.Position) * Vector3.new(1, 0, 1)
				if away.Magnitude <= Config.Train.Radius and math.abs(root.Position.Y - spot.Position.Y) < 12 then
					on = RideService.stateOf(player) == "Dock"
				end
			end
			if on then
				local from = since[player]
				if from then
					local _, left = gain(player, carry[player] or 0, now - from, levelOf(player))
					carry[player] = left
				else
					carry[player] = 0
				end
				since[player] = now
			else
				carry[player] = 0 -- (off it: a part of a second is dropped)
				since[player] = nil
			end
			if training[player] ~= on then
				training[player] = on
				player:SetAttribute("Training", on)
			end
		end
	end
end

-- (Clear: we have walked away since our last ride, so a walk-up seats us again; Left: we have at least left its top,
-- so coming down on it seats us)
-- (Carry: the part of a second seated that has not yet made a whole one, task e1; Since: when the seated time was last
-- counted, so an upgrade or a getting-off between two looks settles the time up to that moment: grade issue 2;
-- Died: the seated humanoid's death, which settles and gets off at once)
type Rider = {
	Ride: Ride?,
	OffAt: number,
	Clear: boolean,
	Left: boolean,
	Carry: number,
	Since: number,
	Died: RBXScriptConnection?,
}

local CHECK = 0.1 -- seconds between looks: a walk-up seats you this soon

function TrainService.Start()
	if Config.Train.On <= 0 then
		return
	end
	local function join(player: Player)
		levels[player] = levels[player] or 1
		player:SetAttribute("TrainerLevel", levels[player])
	end
	Players.PlayerAdded:Connect(join)
	for _, player in Players:GetPlayers() do
		join(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		task.defer(function()
			levels[player] = nil
		end)
	end)
	local rides = plotRides()
	for _, ride in rides do
		build(ride, 1, false)
	end
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
			r = { Ride = nil, OffAt = -math.huge, Clear = true, Left = true, Carry = 0, Since = os.clock() }
			riders[player] = r
		end
		return r
	end

	-- Counts the seated time since the last count, at the ride's level, up to now: whole seconds are given, the part
	-- of a second is kept in Carry (grade issue 2: an upgrade or getting off between two looks settles first)
	local function settle(player: Player, r: Rider)
		local ride = r.Ride
		local now = os.clock()
		local elapsed = now - r.Since
		r.Since = now
		if not ride or elapsed <= 0 then
			return
		end
		local amount, left = gain(player, r.Carry, elapsed, math.max(ride.Level, 1))
		r.Carry = left
		if amount > 0 and player.Parent then
			remote:FireClient(player, "Gain", amount)
		end
	end

	local function off(player: Player, r: Rider, reason: string)
		local ride = r.Ride
		if not ride then
			return
		end
		-- (asked, or died: the seat was fair up to now; lost to the water or a broken weld, it is counted only to the
		-- last look, since when exactly it stopped is not known)
		if reason == "Asked" or reason == "Died" then
			settle(player, r)
		end
		if r.Died then
			r.Died:Disconnect()
			r.Died = nil
		end
		if ride.Weld then
			ride.Weld:Destroy()
			ride.Weld = nil
		end
		ride.Rider = nil
		ride.Model:SetAttribute("Rider", nil)
		r.Ride = nil
		r.Carry = 0 -- (getting off drops a part of a second: no catching up later)
		r.OffAt = os.clock()
		r.Clear = false
		r.Left = false
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
		AquariumService.putAway(player) -- (no fish over the head while seated: grade issue 6)
		r.Carry = 0
		r.Since = os.clock() -- (the seat counts from now, never from the look before: grade issue 2)
		if r.Died then
			r.Died:Disconnect()
		end
		r.Died = humanoid.Died:Connect(function()
			if r.Ride == ride then
				off(player, r, "Died")
			end
		end)
		player:SetAttribute("TrainerRide", ride.Name)
		remote:FireClient(player, "On", ride.Model)
	end

	-- the level a plot's ride should show: its owner's (1 with no owner)
	local function ownerOf(ride: Ride): Player?
		for _, player in Players:GetPlayers() do
			if player:GetAttribute("Plot") == ride.Name then
				return player
			end
		end
		return nil
	end
	local function show(ride: Ride, upgrade: boolean)
		local owner = ownerOf(ride)
		local want = if owner then levelOf(owner) else 1
		if ride.Level ~= want and not build(ride, want, upgrade) then
			-- (no level models: the kit's toy stays, and the upgrade sign says the level)
			ride.Level = want
		end
	end

	local lastUp: { [Player]: number } = {}
	Players.PlayerRemoving:Connect(function(player)
		lastUp[player] = nil
	end)
	local function upgrade(player: Player)
		-- (one ask at a time: a second within Train.UpAgain of the last is the same click, and buys nothing: task e2)
		local now = os.clock()
		if now - (lastUp[player] or -math.huge) < Config.Train.UpAgain then
			return
		end
		lastUp[player] = now
		local own = player:GetAttribute("Plot")
		local ride = if type(own) == "string" then rides[own] else nil
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if not ride or not (root and root:IsA("BasePart")) then
			remote:FireClient(player, "UpNo", "Plot")
			return
		end
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if not humanoid or humanoid.Health <= 0 then
			remote:FireClient(player, "UpNo", "Dead")
			return
		end
		-- (near the ride, or in front of its upgrade sign: the sign's cash block is what is clicked)
		local board = ride.Plot:FindFirstChild("UpgradeBoard")
		local near = flat(ride.Axis - root.Position).Magnitude <= Config.Train.UpgradeNear
			or (
				board ~= nil
				and board:IsA("BasePart")
				and flat(board.Position - root.Position).Magnitude <= Config.Train.SignNear
			)
		if RideService.stateOf(player) ~= "Dock" or not near then
			remote:FireClient(player, "UpNo", "Near")
			return
		end
		local level = levelOf(player)
		if level >= #Config.Train.Levels then
			remote:FireClient(player, "UpNo", "Top")
			return
		end
		local price = levelRow(level + 1).Price
		if Config.Train.Free ~= 1 and not AquariumService.spend(player, price) then
			remote:FireClient(player, "UpNo", "Coins")
			return
		end
		-- (the seated time up to this moment is counted at the old level first, then the next whole second starts now,
		-- at the new level: task e1, grade issue 2)
		local seated = riders[player]
		if seated and seated.Ride then
			settle(player, seated)
			seated.Carry = 0
		end
		levels[player] = level + 1
		player:SetAttribute("TrainerLevel", level + 1)
		show(ride, true)
		remote:FireClient(player, "Up", level + 1, levelRow(level + 1).Name)
	end

	-- a level set from outside (TrainService.setLevel, for saving): as upgrade() above, without the price, the checks,
	-- the upgrade's show or its "Up" banner
	relevel = function(player: Player, level: number)
		local seated = riders[player]
		if seated and seated.Ride then
			settle(player, seated)
			seated.Carry = 0
		end
		levels[player] = level
		player:SetAttribute("TrainerLevel", level)
		local own = player:GetAttribute("Plot")
		local mine = if type(own) == "string" then rides[own] else nil
		if mine then
			show(mine, false)
		end
	end

	remote.OnServerEvent:Connect(function(player, what)
		local r = riders[player]
		if what == "Off" and r and r.Ride then
			off(player, r, "Asked")
		elseif what == "Up" then
			upgrade(player)
		end
	end)
	-- (Studio only, for scripted tests and captures: ServerStorage.TrainerTest:Invoke(op, userId, a).
	-- "level", n: the player's level set to n and their ride shown, played as an upgrade; "up": as the prompt asks,
	-- without the distance; "info": where their ride's coil, seat and body are)
	if RunService:IsStudio() then
		local ask = Instance.new("BindableFunction")
		ask.Name = "TrainerTest"
		ask.OnInvoke = function(op: string, userId: number, a: any): any
			local player = Players:GetPlayerByUserId(userId)
			if not player then
				return "no player"
			end
			local own = player:GetAttribute("Plot")
			local ride = if type(own) == "string" then rides[own] else nil
			if op == "level" and type(a) == "number" then
				levels[player] = math.clamp(math.floor(a), 1, #Config.Train.Levels)
				player:SetAttribute("TrainerLevel", levels[player])
				if ride then
					show(ride, true)
				end
			elseif op == "up" then
				upgrade(player)
			end
			if not ride then
				return "no ride"
			end
			return {
				Plot = ride.Name,
				Level = ride.Level,
				Axis = ride.Axis,
				Seat = ride.Seat,
				Body = ride.Body.CFrame,
				Bottom = ride.Bottom,
				Rider = if ride.Rider then ride.Rider.Name else nil,
			}
		end
		ask.Parent = game:GetService("ServerStorage")
	end
	-- who owns which plot changes as players come and go: each ride follows its owner's level
	task.spawn(function()
		while true do
			for _, ride in rides do
				show(ride, false)
			end
			task.wait(1)
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
		task.wait(CHECK)
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
					-- (seated on the dock is training; the Oxygen comes once a whole second: task e1)
					settle(player, r)
					if player:GetAttribute("Training") ~= true then
						player:SetAttribute("Training", true)
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
					if far > t.OnTop + 0.5 then
						r.Left = true
					end
					local walkedUp = r.Clear and far <= t.Reach and y > here.Axis.Y - 2 and y < here.Bottom + 12
					local landed = r.Left and os.clock() - r.OffAt > 0.6 and far <= t.OnTop and y >= here.Bottom
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
