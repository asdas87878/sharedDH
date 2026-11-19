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
-- The levels (Hugo, 2026-11-19, task sh1: the seahorse draft built): every player has a TrainerLevel, 1 to 12 (the
-- player's attribute; ours, for the session, beside the tank's coins), and each plot's ride shows its owner's: its
-- own seahorse and stand (ReplicatedStorage.TrainerModels.T<n>, art/creatures/Seahorse/tiers/install_tiers.py), the
-- coil in that level's colours from the stand's top straight into the seahorse's body (no plate). A seated rider gains that
-- level's Oxygen a second (Config.Train.Levels). The owner asks to go up a level by the ride ("Up"; the prompt is
-- the client's): on the dock, within Train.UpgradeNear of its coil, for the level's price (free while Train.Free is
-- 1); the ride is rebuilt at once (a rider stays seated on the new one) and the model's Build and UpgradeAt tell
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

local function levelRow(n: number): { Name: string, Oxygen: number, Price: number }
	local levels = Config.Train.Levels
	return levels[math.clamp(n, 1, #levels)]
end

local function short(n: number): string
	local sizes, marks = { 1e12, 1e9, 1e6, 1e3 }, { "T", "B", "M", "K" }
	for i, size in sizes do
		if n >= size then
			local text = string.format("%.1f", n / size)
			return (string.gsub(text, "%.0$", "")) .. marks[i]
		end
	end
	return tostring(math.floor(n))
end

-- The sign's level lines (the mock-up ui8-trainer-upgrade.jpg): under today's two lines, the ride's level and what it
-- gives on a white bar, the next level and what that gives, and its price on an orange button (press E by the ride).
-- The board grows to hold them, its foot kept where it was.
local function levelSign(spot: BasePart, level: number)
	local sign = spot:FindFirstChild("Sign")
	local board = sign and sign:FindFirstChild("Board")
	if not (sign and sign:IsA("BillboardGui") and board and board:IsA("Frame")) then
		return
	end
	local tall = 11.6
	if sign.Size.Y.Scale ~= tall then
		sign.Size = UDim2.fromScale(17, tall)
		sign.StudsOffsetWorldSpace = Vector3.new(0, 30.5 + (tall - 6.4) / 2, 0)
		local scale = 6.4 / tall -- today's two lines keep their size, at the top
		for _, line in board:GetChildren() do
			if line:IsA("TextLabel") then
				line.Position = UDim2.fromScale(line.Position.X.Scale, line.Position.Y.Scale * scale)
				line.Size = UDim2.fromScale(line.Size.X.Scale, line.Size.Y.Scale * scale)
			end
		end
	end
	local function text(name: string, y: number, high: number, colour: Color3, back: Color3?): TextLabel
		local found = board:FindFirstChild(name) :: TextLabel?
		if not found then
			local made = Instance.new("TextLabel")
			made.Name = name
			made.Position = UDim2.fromScale(0.06, y)
			made.Size = UDim2.fromScale(0.88, high)
			made.Font = Enum.Font.LuckiestGuy
			made.TextScaled = true
			made.ZIndex = 3
			made.BorderSizePixel = 0
			local stroke = Instance.new("UIStroke")
			stroke.Thickness = 1.5
			stroke.Color = SIGN_INK
			stroke.LineJoinMode = Enum.LineJoinMode.Round
			stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
			stroke.Parent = made
			if back then
				local corner = Instance.new("UICorner")
				corner.CornerRadius = UDim.new(0.25, 0)
				corner.Parent = made
				local pad = Instance.new("UIPadding")
				pad.PaddingTop = UDim.new(0.14, 0)
				pad.PaddingBottom = UDim.new(0.14, 0)
				pad.Parent = made
			end
			made.Parent = board
			found = made
		end
		local l = found :: TextLabel
		l.TextColor3 = colour
		l.BackgroundTransparency = if back then 0 else 1
		if back then
			l.BackgroundColor3 = back
		end
		return l
	end
	local now = levelRow(level)
	local top = #Config.Train.Levels
	text("Level", 0.42, 0.12, Color3.fromRGB(30, 110, 230), Color3.new(1, 1, 1)).Text =
		string.format("LEVEL %d: %s: +%s A SECOND", level, string.upper(now.Name), short(now.Oxygen))
	local nextLine = text("Next", 0.58, 0.1, Color3.new(1, 1, 1))
	local price = text("Price", 0.73, 0.2, Color3.new(1, 1, 1), Color3.fromRGB(255, 150, 20))
	price.Size = UDim2.fromScale(0.5, 0.2)
	price.Position = UDim2.fromScale(0.25, 0.73)
	if level >= top then
		nextLine.Text = "THE TOP LEVEL"
		price.Visible = false
	else
		local after = levelRow(level + 1)
		nextLine.Text =
			string.format("NEXT, LEVEL %d: %s: +%s A SECOND", level + 1, string.upper(after.Name), short(after.Oxygen))
		price.Visible = true
		price.Text = if Config.Train.Free == 1 then "FREE" else "$" .. short(after.Price)
	end
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
	levelSign(ride.Spot, level)
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

-- A level's Oxygen a second (Config.Train.Levels; Rate when there is no such table), and the share of max on top
local function gain(player: Player, dt: number, level: number): (boolean, number)
	local t = Config.Train
	local max = player:GetAttribute("MaxOxygen")
	local share = if type(max) == "number" then max * t.Share else 0
	local rate = if t.Levels then levelRow(level).Oxygen else t.Rate
	local amount = (rate + share) * dt
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
					on = gain(player, dt, levelOf(player))
				end
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
type Rider = { Ride: Ride?, OffAt: number, Clear: boolean, Left: boolean, Gained: number, ToldAt: number }

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
		if not build(ride, 1, false) then
			levelSign(ride.Spot, 1)
		end
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
			r = { Ride = nil, OffAt = -math.huge, Clear = true, Left = true, Gained = 0, ToldAt = 0 }
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
		r.Gained = 0
		r.ToldAt = os.clock()
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
			-- (no level models: the kit's toy stays, and the sign says the level)
			ride.Level = want
			levelSign(ride.Spot, want)
		end
	end

	local function upgrade(player: Player)
		local own = player:GetAttribute("Plot")
		local ride = if type(own) == "string" then rides[own] else nil
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if not ride or not (root and root:IsA("BasePart")) then
			remote:FireClient(player, "UpNo", "Plot")
			return
		end
		if
			RideService.stateOf(player) ~= "Dock"
			or flat(ride.Axis - root.Position).Magnitude > Config.Train.UpgradeNear
		then
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
		levels[player] = level + 1
		player:SetAttribute("TrainerLevel", level + 1)
		show(ride, true)
		remote:FireClient(player, "Up", level + 1, levelRow(level + 1).Name)
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
					local trained, amount = gain(player, dt, math.max(ride.Level, 1))
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
