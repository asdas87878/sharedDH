--!strict
-- The submarine shop at the stand (docs/design/submarine.md; Hugo, 2026-11-18: "remove the sub button, make the
-- player able to buy the subs there and equip them"). Standing on the stand's ring (Dock.Stations.Sub) opens the shop
-- and walking off it closes it, as at the other stalls (Hugo, 2026-11-23: "you dont have to hold e but you should just
-- be able to stand on the circle for the ui to pop up, closing when walking off it"; Controllers/StallController does
-- the looking, this is the dock window "Sub" of Shop.go): every sub (Shared/SubModels, one a tier) with its picture,
-- the land it reaches and its price (the next one green when you can pay, free while Config.Sub.Free is 1; later ones
-- grey), EQUIP or EQUIPPED; "NO SUB" for
-- the ordinary dive-in. Under the list, GO TO cycles the lands the equipped sub reaches, and RIDE WITH a fish from your
-- tank to be dropped onto (or none: you are flung into a hop). Where the sub takes you is said
-- on GO TO alone (the ticket at the left edge, "SUB > land", is gone: Hugo, 2026-11-24, "Remove the submarine > area
-- text on the left"). The server decides everything (SubService: Action
-- "SubBuy", "SubEquip", n, "SubPick", land, fishKey, each only at the stand); this only shows the player's SubTier,
-- SubEquip, SubDest, SubFish, Coins and Tank attributes. The look is the shop kit (UI/Shop, task s1): a carousel of
-- tall cards tinted in each sub's hull colour, after Hugo's tier-shop reference.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)
local SubModels = require(ReplicatedStorage.Shared.SubModels)
local State = require(script.Parent.Parent.Lib.State)

local Kit = require(script.Parent.Kit)
local Shop = require(script.Parent.Shop)

local SubPanel = {}

local YELLOW = Color3.fromRGB(255, 196, 38)
local NONE_TINT = Color3.fromRGB(96, 120, 150) -- the NO SUB card

-- sizes in the window's points (Shop.window fits them to the screen)
local WIDE, HIGH = 800, 520
local CARD_W, CARD_H = 188, 300
local CARD_PAD = 16 -- a card's own inset, both sides together (Shop.card)
local WELL_HIGH = 112 -- the picture's box on a card
local TOP = 34 -- the tagline row
local FOOT = 62 -- the footer bar

-- A sub's picture on its card. Every sub is seen from the same side (three-quarters from the front, SHOT_FROM
-- looking at SHOT_AT), from that far or further, so a small sub stays smaller than a big one; the camera is moved
-- sideways until the model sits in the middle of the box, and back until the whole of it is inside SHOT_FILL of the
-- box (the long tiers, 5 to 9, were cut off at the box's edge from one fixed spot: task m4, 2026-11-23).
local SHOT_FROM = Vector3.new(-44, 18, -36)
local SHOT_AT = Vector3.new(0, 2, 0)
local SHOT_FOV = 30
local SHOT_FILL = 0.9
local SHOT_LOOK = (SHOT_AT - SHOT_FROM).Unit
local SHOT_FAR = (SHOT_AT - SHOT_FROM).Magnitude
-- Where the camera stands for each model of Shared/SubModels, worked out from the model's own points (a part's box
-- is all the game can see of a mesh, and a box's corners stand well outside a rounded hull). Written by
-- `python tools/subs/card_fit.py --write`; `--check` says when a rebuilt model no longer matches. A model without a
-- row, and the placeholder of plain parts, are framed by their parts' boxes (shotBy).
-- SHOTS: begin
local SHOTS: { [string]: Vector3 } = {
	Bathtub = Vector3.new(-42.86, 17.13, -36.89),
	ReefRunner = Vector3.new(-41.23, 18.76, -38.16),
	KelpCruiser = Vector3.new(-42.19, 18.83, -36.95),
	WreckDiver = Vector3.new(-42.11, 18.48, -37.21),
	BlueStreak = Vector3.new(-41.68, 17.86, -38.01),
	TwilightRay = Vector3.new(-45.62, 17.26, -38.69),
	MidnightHunter = Vector3.new(-41.60, 17.57, -38.24),
	VentCrawler = Vector3.new(-44.63, 15.87, -45.34),
	AbyssKing = Vector3.new(-54.26, 22.32, -53.01),
}
-- SHOTS: end

local gui: ScreenGui -- the hint
-- the cards' propellers, turned while the window is open: { the card's picture, the parts, each part's own place }
type Spinner = { View: ViewportFrame, Parts: { BasePart }, Rest: { CFrame } }
local spinners: { Spinner } = {}
local spin = 0
local window: Shop.Window? = nil -- (nil until init)
local carousel: Shop.Carousel
local coinsLabel: TextLabel
local freeLabel: TextLabel
local fishButton: Shop.Button
local goButton: Shop.Button
type Row = { Card: Shop.Card, Zone: TextLabel, Button: Shop.Button }
local shopRows: { [number]: Row } = {} -- 0: no sub
local hintLabel: TextLabel
local hintAt = -math.huge

local function attr(name: string, default: any): any
	local value = State.Player:GetAttribute(name)
	return if value == nil then default else value
end

type TankFish = { Key: string, Name: string }
local function tankFish(): { TankFish }
	local out: { TankFish } = {}
	local json = attr("Tank", "[]")
	local ok, rows = pcall(function()
		return HttpService:JSONDecode(json)
	end)
	if not ok or type(rows) ~= "table" then
		return out
	end
	for _, row in rows do
		if type(row) == "table" and type(row[1]) == "string" then
			local kind = Config.FishById[row[1]]
			local size, variant = tostring(row[2] or "Normal"), tostring(row[3] or "")
			local name = (if size ~= "Normal" then size .. " " else "")
				.. (if variant ~= "" then variant .. " " else "")
				.. (if kind then kind.Name else row[1])
			table.insert(out, { Key = row[1] .. "|" .. size .. "|" .. variant, Name = name })
		end
	end
	return out
end

local function fishName(key: string): string
	if key == "" then
		return "NO FISH"
	end
	for _, f in tankFish() do
		if f.Key == key then
			return string.upper(f.Name)
		end
	end
	return "NO FISH"
end

local function landName(index: number): string
	local zone = State.Zones[index]
	return if zone then string.upper(zone.Name) else ("LAND " .. index)
end

-- The lands the equipped sub reaches, in order (none when no sub is equipped)
local function reachable(): { number }
	local out = {}
	local lands = math.max(#State.Zones, 10)
	for land = 2, math.min(attr("SubEquip", 0) + 1, lands) do
		table.insert(out, land)
	end
	return out
end

local function refresh()
	local tier = attr("SubTier", 0)
	local equipped = attr("SubEquip", 0)
	local dest = attr("SubDest", 0)
	local coins = attr("Coins", 0)
	local fish = attr("SubFish", "")
	local free = Config.Sub.Free == 1
	coinsLabel.Text = Shop.cash(coins)
	freeLabel.Visible = free
	fishButton.set("RIDE WITH: " .. fishName(fish))
	local going = equipped >= 1 and dest >= 2
	goButton.set(
		if going then "GO TO: " .. dest .. " " .. landName(dest) else "GO TO: NO SUB",
		if equipped >= 1 then "Blue" else "Off"
	)
	for n, row in shopRows do
		row.Card.select(n == equipped)
		if n == 0 then
			if equipped == 0 then
				row.Button.set("EQUIPPED", "Blue", false)
			else
				row.Button.set("EQUIP", "Cash", true)
			end
			continue
		end
		local price = Config.Sub.Prices[n]
		local cost = if price then Shop.cash(price) else ""
		row.Zone.Text = landName(n + 1)
		if n == equipped then
			row.Button.set("EQUIPPED", "Blue", false)
		elseif n <= tier then
			row.Button.set("EQUIP", "Cash", true)
		elseif n == tier + 1 and price then
			-- the next sub: green when you can have it, grey when you can't pay
			local can = free or coins >= price
			row.Button.set(if free then "FREE" else cost, if can then "Cash" else "Off", can)
		else
			-- further on: its price, grey (buy the ones before it first); while subs are free it says why, not a price
			row.Button.set(if free then "LOCKED" else cost, "Off", false)
		end
	end
end

-- Where the camera stands to frame these parts (built at the origin) by their boxes' corners: the same rule as
-- tools/subs/card_fit.py, which has the models' real points
local function shotBy(parts: { BasePart }): Vector3
	local right = SHOT_LOOK:Cross(Vector3.yAxis).Unit
	local up = right:Cross(SHOT_LOOK)
	local halfY = math.tan(math.rad(SHOT_FOV / 2)) * SHOT_FILL
	local halfX = halfY * (CARD_W - CARD_PAD) / WELL_HIGH
	-- every corner in the camera's own axes (across, up, away)
	local corners: { Vector3 } = {}
	for _, p in parts do
		local half = p.Size / 2
		for i = 0, 7 do
			local corner = Vector3.new(
				if i % 2 == 0 then -half.X else half.X,
				if i // 2 % 2 == 0 then -half.Y else half.Y,
				if i // 4 == 0 then -half.Z else half.Z
			)
			local world = p.CFrame:PointToWorldSpace(corner)
			table.insert(corners, Vector3.new(world:Dot(right), world:Dot(up), world:Dot(SHOT_LOOK)))
		end
	end
	local across, over, far = 0, 0, SHOT_FAR
	for _ = 1, 12 do
		local x0, x1, y0, y1 = math.huge, -math.huge, math.huge, -math.huge
		for _, c in corners do
			local depth = math.max(c.Z + far, 0.1)
			local x, y = (c.X - across) / depth, (c.Y - over) / depth
			x0, x1, y0, y1 = math.min(x0, x), math.max(x1, x), math.min(y0, y), math.max(y1, y)
		end
		across += (x0 + x1) / 2 * far
		over += (y0 + y1) / 2 * far
		far = math.max(SHOT_FAR, far * math.max((x1 - x0) / 2 / halfX, (y1 - y0) / 2 / halfY))
	end
	return right * across + up * over - SHOT_LOOK * far
end

-- One sub's picture: its model in a viewport, three-quarters from the front, on the card's cream well
local function picture(parent: Instance, n: number)
	local view = Instance.new("ViewportFrame")
	view.BackgroundTransparency = 1
	view.BorderSizePixel = 0
	view.Size = UDim2.fromScale(1, 1)
	view.Ambient = Color3.fromRGB(170, 170, 170)
	view.LightColor = Color3.new(1, 1, 1)
	view.LightDirection = Vector3.new(-1, -1, -0.5)
	view.ZIndex = 4
	view.Parent = parent
	local model, parts = SubModels.build(n)
	local sign = model:FindFirstChild("Label", true)
	if sign then
		sign:Destroy()
	end
	model.Parent = view
	local hull = model.PrimaryPart
	local eye = if hull and hull:IsA("MeshPart") then SHOTS[SubModels.style(n).Id] else nil
	local cam = Instance.new("Camera")
	cam.FieldOfView = SHOT_FOV
	cam.CFrame = CFrame.lookAlong(eye or shotBy(parts), SHOT_LOOK)
	cam.Parent = view
	view.CurrentCamera = cam
	local s: Spinner = { View = view, Parts = {}, Rest = {} }
	for _, p in parts do
		if p.Name == "Prop" or p.Name == "Prop_Glow" then
			table.insert(s.Parts, p)
			table.insert(s.Rest, p.CFrame)
		end
	end
	table.insert(spinners, s)
end

-- Every propeller in view turned about its own Z, as on a trip at no speed
local function turnProps(dt: number)
	spin = (spin + dt * Config.Sub.PropIdle) % (2 * math.pi)
	local spun = CFrame.Angles(0, 0, spin)
	local list = carousel.List
	local from = list.AbsolutePosition.X
	local to = from + list.AbsoluteSize.X
	for _, s in spinners do
		local x = s.View.AbsolutePosition.X
		if x < to and x + s.View.AbsoluteSize.X > from then
			for i, p in s.Parts do
				p.CFrame = s.Rest[i] * spun
			end
		end
	end
end

-- The land a card reaches, in a dark box of the card's colour (the reference's zone box)
local function zoneBox(card: Shop.Card, tint: Color3, land: number, name: string): TextLabel
	local box = Instance.new("Frame")
	box.Name = "Zone"
	box.Size = UDim2.new(1, 0, 0, 50)
	box.BackgroundColor3 = Kit.darker(tint, 0.55)
	box.BackgroundTransparency = 0.15
	box.BorderSizePixel = 0
	box.LayoutOrder = 5
	box.ZIndex = 3
	box.Parent = card.Well.Parent
	Kit.corner(box, 4)
	local word = Kit.word(box, {
		Font = Kit.Font,
		TextSize = 22,
		Text = "LAND " .. land,
		Position = UDim2.new(0.5, 0, 0, 15),
		Pal = Kit.GoldPal,
		Edge = 0.16,
		ZIndex = 4,
	})
	word.root.Name = "Land"
	return Shop.text(box, {
		Name = "LandName",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -3),
		Size = UDim2.new(1, -6, 0, 16),
		TextSize = 15,
		Text = name,
		ZIndex = 4,
	})
end

local function build()
	local function card(n: number, name: string)
		local style = if n >= 1 then SubModels.style(n) else nil
		local tint = if style then style.Hull else NONE_TINT
		local c = Shop.card(carousel.List, {
			Name = "Sub" .. n,
			Size = UDim2.fromOffset(CARD_W, CARD_H),
			Tint = tint,
			Title = name,
			Line = if n == 0 then "The dive-in" else "Tier " .. n,
			WellHigh = WELL_HIGH,
			SlotHigh = 42,
			LayoutOrder = n,
		})
		if n >= 1 then
			picture(c.Well, n)
		else
			Shop.icon(c.Well, "Bubble", 84, {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				ZIndex = 4,
			})
		end
		local zone = zoneBox(c, tint, n + 1, if n == 0 then "Jump off the dock" else landName(n + 1))
		local b = Shop.button(c.Slot, {
			Name = "Buy",
			Kind = "Cash",
			Size = UDim2.new(1, 0, 0, 42),
			TextSize = 26,
			-- (only the sub you can buy now, not an EQUIP)
			Shine = function()
				return n >= 1 and n > attr("SubTier", 0)
			end,
		})
		b.Root.Activated:Connect(function()
			if not b.Live then
				return
			end
			if n >= 1 and n > attr("SubTier", 0) then
				Net.Action:FireServer("SubBuy", n)
			else
				Net.Action:FireServer("SubEquip", n)
			end
		end)
		shopRows[n] = { Card = c, Zone = zone, Button = b }
	end
	card(0, "No Sub")
	for n, style in SubModels.List do
		if Config.Sub.Prices[n] then
			card(n, style.Name)
		end
	end
end

-- Open or close the window. (Through Shop.go("Sub"), so another dock window closes.)
function SubPanel.open(on: boolean)
	local w = window
	if not w then
		return
	end
	local opening = on and not w.isOpen()
	w.show(on)
	if opening then
		refresh()
		-- the equipped sub in view
		task.defer(function()
			carousel.show(attr("SubEquip", 0) + 1)
		end)
	end
end

-- A line of help at the foot of the screen while it is asked for (called every frame it should show)
function SubPanel.hint(text: string)
	hintLabel.Text = text
	hintAt = os.clock()
end

-- Studio's tests: open or close the shop as standing on the ring does (on the dock only)
-- Test hook: only the Studio checks call this (tools/studio/s2_subs_check.py, tools/ui/shop_kit/shop_client.luau).
function SubPanel.toggle(on: boolean)
	if on and State.Mode == "Dock" then
		Shop.go("Sub")
	elseif not on and Shop.Page == "Sub" then
		Shop.go(nil)
	end
end

function SubPanel.init()
	gui = Instance.new("ScreenGui")
	gui.Name = "SubPanel"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 7
	gui.Parent = State.Player:WaitForChild("PlayerGui")

	local made = Shop.window({
		Name = "SubShop",
		Parent = State.Player:WaitForChild("PlayerGui"),
		Title = "SUBMARINES",
		Icon = "Sub",
		Head = "Sea",
		Width = WIDE,
		Height = HIGH,
		DisplayOrder = 7,
		OnClose = function()
			Shop.go(nil)
		end,
	})
	window = made
	local body = made.Body
	-- the tagline at the left, your coins at the right in green
	Shop.text(body, {
		Name = "Tagline",
		Size = UDim2.new(0.62, 0, 0, TOP - 6),
		TextSize = 24,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "Pick a Sub",
		ZIndex = 3,
	})
	freeLabel = Shop.text(body, {
		Name = "Free",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -150, 0, 4),
		Size = UDim2.fromOffset(200, 20),
		TextSize = 17,
		TextXAlignment = Enum.TextXAlignment.Right,
		TextColor3 = Kit.Sun,
		Text = "SUBS ARE FREE FOR NOW!",
		ZIndex = 3,
	})
	coinsLabel = Shop.money(body, {
		Name = "Coins",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, -2),
		Size = UDim2.fromOffset(150, TOP - 4),
		TextSize = 30,
	})
	carousel = Shop.carousel(body, {
		Position = UDim2.fromOffset(-6, TOP),
		Size = UDim2.new(1, 12, 1, -(TOP + FOOT + 8)),
		CardWide = CARD_W,
		Gap = 12,
		Kind = "Blue",
	})
	-- the footer: where the sub takes you, and which fish you ride
	local foot = Shop.inset(body, {
		Name = "Footer",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, FOOT),
		ZIndex = 2,
	})
	goButton = Shop.button(foot, {
		Name = "GoTo",
		Kind = "Blue",
		TextSize = 22,
		Position = UDim2.fromOffset(10, 9),
		Size = UDim2.new(0.5, -15, 1, -18),
	})
	goButton.Root.ZIndex = 3
	goButton.Root.Activated:Connect(function()
		-- the next land the equipped sub reaches, round to the first
		local options = reachable()
		if #options == 0 then
			return SubPanel.hint("Equip a sub first!")
		end
		local now = attr("SubDest", 0)
		local nextLand = options[1]
		for i, land in options do
			if land == now then
				nextLand = options[i % #options + 1]
				break
			end
		end
		Net.Action:FireServer("SubPick", nextLand, attr("SubFish", ""))
	end)
	fishButton = Shop.button(foot, {
		Name = "RideWith",
		Kind = "Purple",
		TextSize = 22,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -10, 0, 9),
		Size = UDim2.new(0.5, -15, 1, -18),
	})
	fishButton.Root.ZIndex = 3
	fishButton.Root.Activated:Connect(function()
		-- the next fish of the tank, round to none
		local options = tankFish()
		local now = attr("SubFish", "")
		local nextKey = if #options > 0 then options[1].Key else ""
		for i, f in options do
			if f.Key == now then
				nextKey = if options[i + 1] then options[i + 1].Key else ""
				break
			end
		end
		Net.Action:FireServer("SubPick", attr("SubDest", 0), nextKey)
	end)
	build()

	hintLabel = Shop.text(gui, {
		Size = UDim2.fromOffset(520, 32),
		Position = UDim2.new(0.5, -260, 0.78, 0),
		TextSize = 26,
		TextColor3 = YELLOW,
		Visible = false,
	})
	hintLabel.ZIndex = 20

	for _, name in { "SubTier", "SubEquip", "SubDest", "SubFish", "Coins", "Tank" } do
		State.Player:GetAttributeChangedSignal(name):Connect(function()
			refresh()
		end)
	end
	Net.Ride.OnClientEvent:Connect(function(kind: string, a: any)
		if kind == "SubDenied" then
			SubPanel.hint(
				if a == "Coins"
					then "Not enough coins!"
					elseif a == "Dock" then "Only at the sub stand!"
					else "Can't do that"
			)
		elseif kind == "SubBought" then
			local style = SubModels.style(tonumber(a) or 1)
			SubPanel.hint(string.upper(style.Name) .. " bought and equipped! Your boarding pass is ready")
		end
	end)
	RunService.RenderStepped:Connect(function(dt: number)
		hintLabel.Visible = os.clock() - hintAt < 2.2
		if window and window.isOpen() then
			turnProps(dt)
		end
	end)
	refresh()
end

Shop.page("Sub", SubPanel.open)

return SubPanel
