--!strict
-- The aquarium (the user, 2026-11-16: "catches are for depositing in your aquarium, in which they then earn money").
-- The other half of the loop (docs/design/core-loop.md, docs/design/aquarium.md): what a dive catches goes into the
-- player's own tank on the dock, and the best fish in it earn coins every second.
--   A plot each: the map's Dock.Plots.PlotN (TankWater, Pad, SignBoard). A player takes the first free one
--   as they join and gives it up as they leave. With more players than plots, the rest have none: their catch is only
--   counted, as before.
--   Coming home: a player who is carrying fish wakes on the dock at their own tank (RideService.Home), not at the
--   dock's spawn. The catch stays in their hands (the slots) until they put it in: at their own tank a prompt on the
--   tank's front (a click or tap, task e2; there is no pad any more, task k1) puts the chosen fish in, one at a time (Action "Place", index, id; AquariumController; RideService.takeCarried). A failed
--   dive keeps its catch the same way.
--   Earning: each fish earns by what it takes to hold at home, its size and its colour (Config.incomeOf). Up to
--   Aquarium.Earning of them are equipped and earn; the rest are kept (stored) and earn nothing. A new fish takes a free
--   place if there is one, else it is stored.
--   The tank's popup (Hugo, 2026-11-19: "you should be able to click on the plot from nearby, then get a little popup
--   where you can equip the best fish instantly, unequip certain fishes and see how much money they produce"):
--   Client.UI.TankPanel. Its asks are Action "Tank", verb, a, b: "Best" (equip the best Earning, the rest stored),
--   "Equip", key, "Unequip", key, "PutIn", index, id (one carried fish in) and "PutAll" (every carried fish in). Each
--   only on the dock, near one's own tank (the plot's "PanelReach" attribute, studs from the tank, plus some slack);
--   refused with Ride "TankDenied", reason ("Far", "Full", "Gone"). What the popup shows comes from the player's
--   attributes "TankList" (every fish: key, id, size, variant, 1 if equipped) and "Hands" (what they carry: id, size,
--   variant, oldest first). Coins are the player's "Coins" attribute (the
--   HUD's coin row shows itself when it is there), "Income" what the tank earns a second, "TankFish" how many it holds.
--   Seen: the earning fish swim in the tank, small. The server puts each in its place, anchored, with the tag
--   "TankFish" and the numbers of its lap; every client moves them round itself (AquariumController), so they cost no
--   traffic. They are not in Workspace.Fish, so nothing can lock on to one or tag it. Its owner can ride one inside the
--   tank (Hugo, 2026-11-20, task k1: TankRideService, Config.TankRide).
--   Holding a fish over the head (Hugo, 2026-11-20; docs/design/holding.md): Action "Hold", index, id holds the
--   index-th fish the player carries (oldest first, which must still be `id`); index 0 puts it away. Only on the
--   dock. The server builds the fish, small, and welds it over the player's head, so everyone sees it; every client
--   lifts the arms (HoldController). The player's attributes: "HeldFish" (its id), "HeldSize", "HeldVariant",
--   "HeldIndex" (its place in the hands now). Held means one of the fish in the hands, that very one: once it is not
--   there any more (put in the tank, or gone any other way) it is put away. A new body (a respawn, a reset) puts it
--   away. A dive keeps it held, unseen. Holding is not riding (task e3): Q makes the held fish the ride fish
--   (RideService.equippedOf), and only that is ridden on land, after a dive in and after the sub.
-- For the session only: there are no saves yet.
local CollectionService = game:GetService("CollectionService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)
local Variants = require(ReplicatedStorage.Shared.Variants)
local FishModel = require(script.Parent.Parent.Lib.FishModel)
local RideService = require(script.Parent.RideService)

type Entry = {
	Key: string, -- the fish's own name in its tank, for the popup's asks
	Id: string,
	Size: string,
	Variant: string,
	Income: number,
	On: boolean, -- equipped: earning and swimming in the tank
}
type Tank = {
	Player: Player,
	Plot: Model,
	Fish: { Entry }, -- everything in the tank, the best earner first
	Coins: number,
	Income: number, -- coins a second: the equipped ones (at most Aquarium.Earning)
	Made: number, -- fish keys handed out so far
	Hands: string, -- the "Hands" attribute last written
	Shown: Folder?,
}

local AquariumService = {}

AquariumService.Tag = "TankFish"

local EVERY = 0.25 -- seconds between looks at who is standing where
-- How near one's own tank the popup opens (studs from the tank's water, across the floor), and the server's slack
-- over that for lag. Written on each plot as "PanelReach" so the player's machine uses the same number
local PANEL_REACH = 36
local PANEL_SLACK = 12
local plots: { Model } = {}
local tanks: { [Player]: Tank } = {}
local owners: { [Model]: Player } = {}

-- The fish a player holds over their head: the very entry of their hands (RideService.carried), and its model while shown
type Held = { Carry: RideService.Carry, Model: Model?, Body: Model? }
local held: { [Player]: Held } = {}
local heldFolder: Folder? = nil

local function part(plot: Model, name: string): BasePart?
	local found = plot:FindFirstChild(name)
	return if found and found:IsA("BasePart") then found else nil
end

-- The plot's sign, in the hub's sign style (the user's pick of 2026-11-16, "B": the gate's sign; docs/design/ui.md):
-- a blue board, a white band across its top with the owner's name in blue, and under it what the tank earns in white
-- letters with a dark edge. A free tank says so, paler, with no band.
-- Each player's own machine writes "YOUR TANK" over its own tank's band (Client.UI.HubSigns shows the label "Mine"
-- and hides "Owner"), so nothing here sets those two labels' Visible after they are made.
local SIGN_BLUE = Color3.fromRGB(30, 140, 255)
local SIGN_INK = Color3.fromRGB(16, 36, 63)
local SIGN_PALE = Color3.fromRGB(196, 224, 255)
local SIGN_FONT = Enum.Font.LuckiestGuy

local function signFace(board: BasePart, name: string, face: Enum.NormalId): SurfaceGui
	local gui = Instance.new("SurfaceGui")
	gui.Name = name
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 24
	gui.LightInfluence = 0
	local root = Instance.new("Frame")
	root.Name = "Board"
	root.Size = UDim2.fromScale(1, 1)
	root.BackgroundColor3 = SIGN_BLUE
	root.BorderSizePixel = 0
	root.Parent = gui
	local band = Instance.new("Frame")
	band.Name = "Band"
	band.Size = UDim2.fromScale(1, 0.3)
	band.BackgroundColor3 = Color3.new(1, 1, 1)
	band.BorderSizePixel = 0
	band.Parent = root
	for _, which in { "Owner", "Mine" } do
		local label = Instance.new("TextLabel")
		label.Name = which
		label.BackgroundTransparency = 1
		label.Position = UDim2.fromScale(0.03, 0.08)
		label.Size = UDim2.fromScale(0.94, 0.84)
		label.Font = SIGN_FONT
		label.TextScaled = true
		label.TextColor3 = SIGN_BLUE
		label.Text = if which == "Mine" then "YOUR TANK" else ""
		label.Visible = which == "Owner"
		label.Parent = band
	end
	local text = Instance.new("TextLabel")
	text.Name = "Text"
	text.BackgroundTransparency = 1
	text.Font = SIGN_FONT
	text.TextScaled = true
	text.Parent = root
	local edge = Instance.new("UIStroke")
	edge.Thickness = 3
	edge.Color = SIGN_INK
	edge.LineJoinMode = Enum.LineJoinMode.Round
	edge.Parent = text
	gui.Parent = board
	return gui
end

local function sign(plot: Model, tank: Tank?)
	local board = part(plot, "SignBoard")
	if not board then
		return
	end
	local owner = if tank then tank.Player.DisplayName else ""
	local text = if not tank
		then "FREE TANK"
		elseif tank.Income > 0 then string.format("$%s a second", Config.shortNumber(tank.Income))
		else "no fish yet"
	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
		local name = "Sign" .. face.Name
		local gui = board:FindFirstChild(name)
		if gui and not gui:FindFirstChild("Board") then
			gui:Destroy() -- (a sign of the old build)
			gui = nil
		end
		local root = (gui or signFace(board, name, face)):FindFirstChild("Board")
		local band = root and root:FindFirstChild("Band")
		local ownerLabel = band and band:FindFirstChild("Owner")
		local label = root and root:FindFirstChild("Text")
		if
			band
			and band:IsA("Frame")
			and ownerLabel
			and ownerLabel:IsA("TextLabel")
			and label
			and label:IsA("TextLabel")
		then
			band.Visible = tank ~= nil
			ownerLabel.Text = owner
			label.Text = text
			label.TextColor3 = if tank then Color3.new(1, 1, 1) else SIGN_PALE
			label.Position = if tank then UDim2.fromScale(0.03, 0.34) else UDim2.fromScale(0.05, 0.2)
			label.Size = if tank then UDim2.fromScale(0.94, 0.6) else UDim2.fromScale(0.9, 0.6)
		end
	end
end

-- The tank's earning fish, put in the water for everyone to see: small, anchored, each with the numbers of its lap
local function show(tank: Tank)
	local a = Config.Aquarium
	if tank.Shown then
		tank.Shown:Destroy()
		tank.Shown = nil
	end
	local water = part(tank.Plot, "TankWater")
	local equipped = {}
	for _, entry in tank.Fish do
		if entry.On then
			table.insert(equipped, entry)
		end
	end
	if not water or #equipped == 0 then
		return
	end
	local folder = Instance.new("Folder")
	folder.Name = "TankFish"
	local count = math.min(#equipped, a.Show)
	local half = water.Size / 2
	for i = 1, count do
		local entry = equipped[i]
		local kind = Config.FishById[entry.Id]
		if kind then
			local model = FishModel.build(kind)
			CollectionService:RemoveTag(model, FishModel.Tag)
			Variants.apply(model, entry.Variant)
			-- its size in the tank: its own size, a share of it, kept between two lengths so a Tiny shows and a
			-- Colossal fits
			local own = kind.Size.Z * Config.sizeScale(entry.Size, kind)
			local shown = math.clamp(own * a.ShowShare, a.ShowLeast, a.ShowMost)
			model:ScaleTo(model:GetScale() * shown / math.max(kind.Size.Z, 0.1))
			local root = model.PrimaryPart
			if root then
				for _, d in root:GetChildren() do
					-- (its movers, and its wake: a tank's fish leaves none)
					if d:IsA("Constraint") or d:IsA("Trail") then
						d:Destroy()
					end
				end
				root.Anchored = true
				-- a lap of its own: the big ones wide and slow in the middle of the water, the small ones nearer the
				-- glass, each at its own height
				local u = (i - 0.5) / count
				local rx = math.max(half.X - shown / 2 - 4, 4) * (0.45 + 0.5 * u)
				local rz = math.max(half.Z - shown / 2 - 4, 4) * (0.45 + 0.5 * u)
				local y = water.Position.Y - half.Y + 5 + (water.Size.Y - 10) * ((i * 0.618034) % 1)
				model:SetAttribute("TankCentre", Vector3.new(water.Position.X, y, water.Position.Z))
				model:SetAttribute("TankReach", Vector3.new(rx, math.min(2, half.Y / 6), rz))
				model:SetAttribute("TankPhase", (i * 2.399963) % (math.pi * 2))
				model:SetAttribute("TankPace", a.SwimPace / math.max((rx + rz) / 2, 1) * (if i % 2 == 0 then 1 else -1))
				model:SetAttribute("SizeTier", entry.Size)
				model:SetAttribute("Variant", entry.Variant)
				model:PivotTo(CFrame.new(water.Position.X + rx, y, water.Position.Z))
				CollectionService:AddTag(model, AquariumService.Tag)
				model.Parent = folder
			else
				model:Destroy()
			end
		end
	end
	folder.Parent = tank.Plot
	tank.Shown = folder
end

local TANK_LISTED = 12 -- the tank's best fish listed for the player's own panels (the submarine's "Ride with")

local function tell(tank: Tank)
	tank.Player:SetAttribute("Coins", math.floor(tank.Coins))
	tank.Player:SetAttribute("Income", tank.Income)
	tank.Player:SetAttribute("TankFish", #tank.Fish)
	local listed = {}
	for i = 1, math.min(#tank.Fish, TANK_LISTED) do
		local f = tank.Fish[i]
		table.insert(listed, { f.Id, f.Size, f.Variant })
	end
	tank.Player:SetAttribute("Tank", HttpService:JSONEncode(listed))
	-- every fish, for the popup (Client.UI.TankPanel): key, id, size, variant, 1 if equipped
	local all = {}
	for _, f in tank.Fish do
		local row: { any } = { f.Key, f.Id, f.Size, f.Variant, if f.On then 1 else 0 }
		table.insert(all, row)
	end
	tank.Player:SetAttribute("TankList", HttpService:JSONEncode(all))
	tank.Player:SetAttribute("TankEarning", Config.Aquarium.Earning)
end

-- What a player carries, for the popup ("Hands": id, size, variant, oldest first), written only when it changed
local function tellHands(tank: Tank)
	local rows = {}
	for _, c in RideService.carried(tank.Player) do
		table.insert(rows, { c.Id, c.Size, c.Variant })
	end
	local json = HttpService:JSONEncode(rows)
	if json ~= tank.Hands then
		tank.Hands = json
		tank.Player:SetAttribute("Hands", json)
	end
end

-- How high above the head's middle its top is, with what is worn on it (a hat, hair: accessories joined to the head),
-- at most Hold.HatMost above the head itself. So the fish lies on the hat, not through it
local function headTop(character: Model, head: BasePart): number
	local top = head.Size.Y / 2
	for _, d in character:GetChildren() do
		local handle = if d:IsA("Accessory") then d:FindFirstChild("Handle") else nil
		local weld = handle and handle:FindFirstChildWhichIsA("JointInstance")
		if handle and handle:IsA("BasePart") and weld and (weld.Part0 == head or weld.Part1 == head) then
			local cf, size = handle.CFrame, handle.Size
			for _, x in { -1, 1 } do
				for _, y in { -1, 1 } do
					for _, z in { -1, 1 } do
						local corner = head.CFrame:PointToObjectSpace(cf * (Vector3.new(x, y, z) * size / 2))
						-- (only what is over the head, not a scarf or a bag hanging down)
						if math.abs(corner.X) < head.Size.X * 1.5 and math.abs(corner.Z) < head.Size.Z * 1.5 then
							top = math.max(top, corner.Y)
						end
					end
				end
			end
		end
	end
	return math.min(top, head.Size.Y / 2 + Config.Hold.HatMost)
end

-- The held fish's model, built over the head of the player's body: small, its colour kept, every part welded and
-- weightless and touching nothing, so the body carries it and its owner's machine moves it for everyone
local function buildHeld(player: Player, h: Held): Model?
	local c = Config.Hold
	local character = player.Character
	local head = character and character:FindFirstChild("Head")
	local kind = Config.FishById[h.Carry.Id]
	if not character or not head or not head:IsA("BasePart") or not kind or not heldFolder then
		return nil
	end
	local model = FishModel.build(kind)
	CollectionService:RemoveTag(model, FishModel.Tag)
	Variants.apply(model, h.Carry.Variant)
	local own = kind.Size.Z * Config.sizeScale(h.Carry.Size, kind)
	local shown = math.clamp(own * c.Share, c.Least, c.Most)
	model:ScaleTo(model:GetScale() * shown / math.max(kind.Size.Z, 0.1))
	local root = model.PrimaryPart
	if not root then
		model:Destroy()
		return nil
	end
	for _, d in model:GetDescendants() do
		if d:IsA("Constraint") or d:IsA("Trail") then
			d:Destroy() -- (its movers and its wake)
		elseif d:IsA("BasePart") then
			d.Anchored = false
			d.CanCollide = false
			d.CanTouch = false
			d.CanQuery = false
			d.Massless = true
		end
	end
	-- the middle of its box over the middle of the head, its belly Above the head's top
	model:PivotTo(CFrame.new())
	local box, size = model:GetBoundingBox()
	local centre = root.CFrame:PointToObjectSpace(box.Position)
	local weld = Instance.new("Weld")
	weld.Name = "HeldWeld"
	weld.Part0 = head
	weld.Part1 = root
	weld.C0 = CFrame.new(0, headTop(character, head) + c.Above + size.Y / 2, 0) * CFrame.Angles(0, math.rad(c.Turn), 0)
	weld.C1 = CFrame.new(centre)
	weld.Parent = root
	model.Name = player.Name
	model:SetAttribute("HeldBy", player.UserId)
	model:SetAttribute("SizeTier", h.Carry.Size)
	model:SetAttribute("Variant", h.Carry.Variant)
	model.Parent = heldFolder
	return model
end

local function dropHeldModel(h: Held)
	if h.Model then
		h.Model:Destroy()
	end
	h.Model = nil
	h.Body = nil
end

local function putAway(player: Player)
	local h = held[player]
	if h then
		dropHeldModel(h)
		held[player] = nil
	end
	player:SetAttribute("HeldFish", nil)
	player:SetAttribute("HeldSize", nil)
	player:SetAttribute("HeldVariant", nil)
	player:SetAttribute("HeldIndex", nil)
end

-- Is the held fish still in the hands, and shown only on the dock, over the body the player has now
local function refreshHeld(player: Player)
	local h = held[player]
	if not h then
		return
	end
	local index = table.find(RideService.carried(player), h.Carry)
	if not index or Config.Hold.On == 0 then
		putAway(player)
		return
	end
	if player:GetAttribute("HeldIndex") ~= index then
		player:SetAttribute("HeldIndex", index)
	end
	local onDock = RideService.stateOf(player) == "Dock"
	if h.Model and (not onDock or h.Body ~= player.Character or not h.Model.Parent) then
		dropHeldModel(h)
	end
	if onDock and not h.Model then
		h.Model = buildHeld(player, h)
		h.Body = if h.Model then player.Character else nil
	end
end

-- Hold the index-th fish in the hands (it must still be `id`), or with index 0 put the held one away
local function hold(player: Player, index: number, id: string)
	if index == 0 then
		putAway(player)
		return
	end
	local c = RideService.carried(player)[index]
	if not c or c.Id ~= id or not Config.FishById[id] then
		Net.Ride:FireClient(player, "Denied", "Hold", "Gone")
		return
	end
	local h = held[player]
	if h and h.Carry == c then
		return
	end
	putAway(player)
	-- (off the land fish to hold one up, task e3: the ride fish stays equipped until Q picks the held one)
	RideService.landOff(player)
	held[player] = { Carry = c, Model = nil, Body = nil }
	player:SetAttribute("HeldFish", c.Id)
	player:SetAttribute("HeldSize", c.Size)
	player:SetAttribute("HeldVariant", c.Variant)
	refreshHeld(player)
end

-- The fish a player holds (one of their hands' entries, the very table), or nil. Kept through a dive: the next
-- task's ride after the sub reads it
function AquariumService.heldOf(player: Player): RideService.Carry?
	local h = held[player]
	return if h then h.Carry else nil
end

local function equippedCount(tank: Tank): number
	local n = 0
	for _, f in tank.Fish do
		if f.On then
			n += 1
		end
	end
	return n
end

-- What the tank earns: its equipped fish (the list is kept best first). Each fish's number is Config.incomeOf, worked
-- out again here so a change to how size or colour pays (the economy draft) reaches the fish already in tanks
local function count(tank: Tank)
	for _, f in tank.Fish do
		local kind = Config.FishById[f.Id]
		f.Income = if kind then Config.incomeOf(kind, f.Size, f.Variant) else 0
	end
	table.sort(tank.Fish, function(x, y)
		if x.Income ~= y.Income then
			return x.Income > y.Income
		end
		return x.Key < y.Key
	end)
	local income = 0
	local most = Config.Aquarium.Earning
	local on = 0
	for _, f in tank.Fish do
		if f.On then
			on += 1
			if on > most then
				f.On = false -- (Earning was lowered: the poorest step out)
			else
				income += f.Income
			end
		end
	end
	tank.Income = income
end

-- A new fish in the tank: equipped if there is a free place, else stored
local function add(tank: Tank, id: string, size: string, variant: string): Entry?
	local kind = Config.FishById[id]
	if not kind then
		return nil
	end
	tank.Made += 1
	local entry: Entry = {
		Key = tostring(tank.Made),
		Id = id,
		Size = size,
		Variant = variant,
		Income = Config.incomeOf(kind, size, variant),
		On = equippedCount(tank) < Config.Aquarium.Earning,
	}
	table.insert(tank.Fish, entry)
	return entry
end

-- (a tank is not endless: past Aquarium.Hold the poorest stored fish are let go; equipped ones are kept)
local function trim(tank: Tank)
	count(tank)
	local i = #tank.Fish
	while #tank.Fish > Config.Aquarium.Hold and i >= 1 do
		if not tank.Fish[i].On then
			table.remove(tank.Fish, i)
		end
		i -= 1
	end
end

-- Everything that follows a change to the tank: the numbers, the attributes, the fish in the water and the sign
local function changed(tank: Tank)
	count(tank)
	tell(tank)
	show(tank)
	sign(tank.Plot, tank)
end

-- One fish from the player's hands goes into their tank: the index-th they carry (oldest first), which must still be
-- the kind their machine saw there (`id`), so a list that changed under the click puts nothing in
local function place(tank: Tank, index: number, id: string): boolean
	local carried = RideService.carried(tank.Player)
	local c = carried[index]
	if not c or c.Id ~= id or not Config.FishById[id] then
		return false
	end
	local taken = RideService.takeCarried(tank.Player, index)
	local kind = taken and Config.FishById[taken.Id]
	if not taken or not kind then
		return false
	end
	local before = tank.Income
	add(tank, taken.Id, taken.Size, taken.Variant)
	trim(tank)
	changed(tank)
	tellHands(tank)
	refreshHeld(tank.Player) -- (put away at once if it was the held one)
	Net.Ride:FireClient(tank.Player, "Deposited", 1, tank.Income - before, tank.Income, taken.Id)
	return true
end

-- The popup's asks (Action "Tank"). Each returns nil when done, or why not
local function equipBest(tank: Tank): string?
	count(tank)
	local most = Config.Aquarium.Earning
	for i, f in tank.Fish do
		f.On = i <= most
	end
	changed(tank)
	return nil
end

local function find(tank: Tank, key: string): Entry?
	for _, f in tank.Fish do
		if f.Key == key then
			return f
		end
	end
	return nil
end

local function equip(tank: Tank, key: string, on: boolean): string?
	local entry = find(tank, key)
	if not entry then
		return "Gone"
	end
	if on and not entry.On and equippedCount(tank) >= Config.Aquarium.Earning then
		return "Full"
	end
	entry.On = on
	changed(tank)
	return nil
end

local function join(player: Player)
	if tanks[player] then
		return
	end
	for _, plot in plots do
		if not owners[plot] then
			local tank: Tank = {
				Player = player,
				Plot = plot,
				Fish = {},
				Coins = 0,
				Income = 0,
				Made = 0,
				Hands = "",
				Shown = nil,
			}
			owners[plot] = player
			tanks[player] = tank
			plot:SetAttribute("Owner", player.UserId)
			player:SetAttribute("Plot", plot.Name)
			tell(tank)
			sign(plot, tank)
			return
		end
	end
end

local function leave(player: Player)
	local tank = tanks[player]
	if not tank then
		return
	end
	tanks[player] = nil
	owners[tank.Plot] = nil
	if tank.Shown then
		tank.Shown:Destroy()
	end
	tank.Plot:SetAttribute("Owner", nil)
	sign(tank.Plot, nil)
end

-- Whether a place is on a plot (over its pad, near the ground)
local function onPlot(plot: Model, at: Vector3): boolean
	local pad = part(plot, "Pad")
	if not pad then
		return false
	end
	local offset = pad.CFrame:PointToObjectSpace(at)
	return math.abs(offset.X) <= pad.Size.X / 2
		and math.abs(offset.Z) <= pad.Size.Z / 2
		and offset.Y > -4
		and offset.Y < 30
end

-- The floor in front of a plot's tank, facing the tank (Hugo, 2026-11-20, task k1: the green collect pad is gone, so
-- this is where a player wakes with a catch, where the tank's E prompt sits and where a tank ride lets them off). The
-- plot's Pad (unseen, the area that counts as the plot) reaches further forward than the tank, so the way from the
-- water's middle to the Pad's is the plot's front.
local FRONT_AHEAD = 8 -- studs in front of the water's front face
local function frontOf(plot: Model): (CFrame?, Vector3?)
	local water = part(plot, "TankWater")
	local pad = part(plot, "Pad")
	if not water then
		return nil, nil
	end
	local way = if pad then (pad.Position - water.Position) * Vector3.new(1, 0, 1) else Vector3.zero
	if way.Magnitude < 1 then
		way = water.CFrame.LookVector * Vector3.new(1, 0, 1)
	end
	way = way.Unit
	-- (how far the water's front face is from its middle, that way)
	local half = water.Size / 2
	local face = math.abs(way:Dot(water.CFrame.RightVector)) * half.X
		+ math.abs(way:Dot(water.CFrame.LookVector)) * half.Z
	local floor = if pad then pad.Position.Y + pad.Size.Y / 2 else water.Position.Y - half.Y
	local at = Vector3.new(water.Position.X, floor, water.Position.Z) + way * (face + FRONT_AHEAD)
	local toward = Vector3.new(water.Position.X, floor, water.Position.Z)
	return CFrame.lookAt(at, toward), way
end

-- Whether a player stands at their tank, near enough to put a fish in (on its plot, or near its water: the prompt on
-- the tank's front and the popup, and some slack for lag)
local function atTank(tank: Tank): boolean
	local character = tank.Player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return false
	end
	if onPlot(tank.Plot, root.Position) then
		return true
	end
	local water = part(tank.Plot, "TankWater")
	if not water then
		return false
	end
	local offset = water.CFrame:PointToObjectSpace(root.Position)
	local half = water.Size / 2
	local dx = math.max(math.abs(offset.X) - half.X, 0)
	local dz = math.max(math.abs(offset.Z) - half.Z, 0)
	return math.sqrt(dx * dx + dz * dz) <= PANEL_REACH + PANEL_SLACK and math.abs(offset.Y) < half.Y + 40
end

-- Where a player comes home to: in front of their own tank, facing it, when they carry fish
local function home(player: Player): CFrame?
	local tank = tanks[player]
	if not tank or Config.Aquarium.HomeAtTank == 0 or #RideService.carried(player) == 0 then
		return nil
	end
	local spot = frontOf(tank.Plot)
	return if spot then spot + Vector3.new(0, 1, 0) else nil
end

-- For the tank ride (TankRideService): the player's plot, its fish in the water now, whether they stand at it, the
-- floor in front of it, the fish put back in their laps, and the held fish put away
function AquariumService.plotOf(player: Player): Model?
	local tank = tanks[player]
	return if tank then tank.Plot else nil
end

function AquariumService.shownOf(player: Player): Folder?
	local tank = tanks[player]
	return if tank then tank.Shown else nil
end

function AquariumService.atTank(player: Player): boolean
	local tank = tanks[player]
	return tank ~= nil and atTank(tank)
end

AquariumService.frontOf = frontOf

function AquariumService.reshow(player: Player)
	local tank = tanks[player]
	if tank then
		show(tank)
	end
end

AquariumService.putAway = function(player: Player)
	putAway(player)
end

-- Studio and other services: what a player's tank holds (nil with no tank)
function AquariumService.tankOf(player: Player): { Entry }?
	local tank = tanks[player]
	return if tank then tank.Fish else nil
end

-- What a player has to spend (0 with no tank), and spending it: false, and nothing taken, when they haven't enough
function AquariumService.coinsOf(player: Player): number
	local tank = tanks[player]
	return if tank then tank.Coins else 0
end

function AquariumService.spend(player: Player, amount: number): boolean
	local tank = tanks[player]
	if not tank or amount ~= amount or amount < 0 or tank.Coins < amount then
		return false
	end
	tank.Coins -= amount
	tell(tank)
	return true
end

-- Studio's tests only: coins and fish given straight to a tank
function AquariumService.give(player: Player, coins: number, fish: { { string } }?)
	local tank = tanks[player]
	if not tank then
		return
	end
	tank.Coins += coins
	local list: { { string } } = fish or {}
	for _, f in list do
		add(tank, f[1], f[2] or "Normal", f[3] or "")
	end
	trim(tank)
	changed(tank)
end

-- Holding works with or without a tank (the hands are RideService's)
local function startHolding()
	local folder = Instance.new("Folder")
	folder.Name = "HeldFish"
	folder.Parent = workspace
	heldFolder = folder
	-- Q equips the held fish (RideService, task e3)
	RideService.HeldOf = AquariumService.heldOf
	RideService.PutAway = putAway
	local lastHold: { [Player]: number } = {}
	Net.Action.OnServerEvent:Connect(function(player: Player, action: any, index: any, id: any)
		if action ~= "Hold" or type(index) ~= "number" or index ~= index or index % 1 ~= 0 then
			return
		end
		local now = os.clock()
		if Config.Hold.On == 0 or now - (lastHold[player] or 0) < 0.15 then
			return
		end
		lastHold[player] = now
		if index ~= 0 and (type(id) ~= "string" or RideService.stateOf(player) ~= "Dock") then
			Net.Ride:FireClient(player, "Denied", "Hold", "Far")
			return
		end
		hold(player, index, if type(id) == "string" then id else "")
	end)
	local function watch(player: Player)
		-- a new body (a respawn, a reset) puts it away
		player.CharacterAdded:Connect(function()
			putAway(player)
		end)
		player.CharacterRemoving:Connect(function()
			putAway(player)
		end)
	end
	Players.PlayerAdded:Connect(watch)
	for _, player in Players:GetPlayers() do
		watch(player)
	end
	Players.PlayerRemoving:Connect(function(player: Player)
		putAway(player)
		lastHold[player] = nil
	end)
	-- (looked at a few times a second, as the hands are: anything that took the fish out of them puts it away)
	task.spawn(function()
		while true do
			task.wait(EVERY / 2)
			for player in held do
				refreshHeld(player)
			end
		end
	end)
end

function AquariumService.Init()
	if Config.Aquarium.On == 0 then
		return
	end
	local blockout = workspace:FindFirstChild("ClaudeBlockout")
	local dock = blockout and blockout:FindFirstChild("Dock")
	local folder = dock and dock:FindFirstChild("Plots")
	if folder then
		for _, plot in folder:GetChildren() do
			if plot:IsA("Model") and part(plot, "TankWater") and part(plot, "Pad") then
				plot:SetAttribute("PanelReach", PANEL_REACH)
				table.insert(plots, plot)
			end
		end
	end
	if #plots == 0 then
		print("[AquariumService] the map has no plots (Dock.Plots.PlotN with a TankWater and a Pad): no aquariums")
		return
	end
	-- the nearest to the dock's spawn first, so the first players are the shortest walk from the gate
	local spawn = dock and dock:FindFirstChild("DockSpawn")
	local from = if spawn and spawn:IsA("BasePart") then spawn.Position else Vector3.zero
	table.sort(plots, function(x, y)
		local dx, dy = (x:GetPivot().Position - from).Magnitude, (y:GetPivot().Position - from).Magnitude
		return if dx ~= dy then dx < dy else x.Name < y.Name
	end)
	for _, plot in plots do
		sign(plot, nil)
	end
	RideService.Keeps = function(player: Player): boolean
		return tanks[player] ~= nil
	end
	RideService.Home = home
end

function AquariumService.Start()
	startHolding()
	if #plots == 0 then
		return
	end
	-- the player puts a fish they carry into their tank (Action "Place", index, id: AquariumController's click control). Only
	-- on the dock, at their own tank, a few a second at most
	local lastPlace: { [Player]: number } = {}
	Net.Action.OnServerEvent:Connect(function(player: Player, action: any, index: any, id: any)
		if action ~= "Place" or type(index) ~= "number" or type(id) ~= "string" then
			return
		end
		local tank = tanks[player]
		local now = os.clock()
		if not tank or now - (lastPlace[player] or 0) < 0.15 then
			return
		end
		lastPlace[player] = now
		if RideService.stateOf(player) ~= "Dock" or not atTank(tank) then
			Net.Ride:FireClient(player, "Denied", "Place", "Far")
			return
		end
		if not place(tank, index, id) then
			Net.Ride:FireClient(player, "Denied", "Place", "Gone") -- (it stays in their hands: task e2)
		end
	end)
	-- the popup's asks (Action "Tank", verb, a, b: Client.UI.TankPanel). Only on the dock, near one's own tank, ten a
	-- second at most
	local lastAsk: { [Player]: number } = {}
	Net.Action.OnServerEvent:Connect(function(player: Player, action: any, verb: any, a: any, b: any)
		if action ~= "Tank" or type(verb) ~= "string" then
			return
		end
		local tank = tanks[player]
		local now = os.clock()
		if not tank or now - (lastAsk[player] or 0) < 0.1 then
			return
		end
		lastAsk[player] = now
		if RideService.stateOf(player) ~= "Dock" or not atTank(tank) then
			Net.Ride:FireClient(player, "TankDenied", "Far")
			return
		end
		local why: string? = nil
		if verb == "Best" then
			why = equipBest(tank)
		elseif (verb == "Equip" or verb == "Unequip") and type(a) == "string" then
			why = equip(tank, a, verb == "Equip")
		elseif verb == "PutIn" and type(a) == "number" and type(b) == "string" then
			if not place(tank, a, b) then
				why = "Gone"
			end
		elseif verb == "PutAll" then
			-- the newest first, so each index still names the fish it did
			for i = #RideService.carried(player), 1, -1 do
				local c = RideService.carried(player)[i]
				if c then
					place(tank, i, c.Id)
				end
			end
		end
		if why then
			Net.Ride:FireClient(player, "TankDenied", why)
		end
	end)
	Players.PlayerRemoving:Connect(function(player: Player)
		lastPlace[player] = nil
		lastAsk[player] = nil
	end)
	Players.PlayerAdded:Connect(join)
	Players.PlayerRemoving:Connect(leave)
	for _, player in Players:GetPlayers() do
		join(player)
	end
	local paidAt = os.clock()
	while true do
		task.wait(EVERY)
		local now = os.clock()
		local pay = now - paidAt >= Config.Aquarium.Every
		for player, tank in tanks do
			if pay and tank.Income > 0 then
				tank.Coins += tank.Income * (now - paidAt)
				player:SetAttribute("Coins", math.floor(tank.Coins))
			end
			tellHands(tank)
		end
		if pay then
			paidAt = now
		end
	end
end

return AquariumService
