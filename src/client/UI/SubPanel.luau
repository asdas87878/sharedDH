--!strict
-- The submarine shop at the stand (docs/design/submarine.md; Hugo, 2026-11-18: "remove the sub button, make the
-- player able to buy the subs there and equip them"). Walking up to the stand (Dock.Stations.Sub) shows a prompt on
-- its ring; pressing it opens the shop: every sub (Shared/SubModels, one a tier) with its picture, the land it reaches
-- and its price (the next one green when you can pay, free while Config.Sub.Free is 1; later ones grey), EQUIP or
-- EQUIPPED; "NO SUB" for
-- the ordinary dive-in. Under the list, GO TO cycles the lands the equipped sub reaches, and RIDE WITH a fish from your
-- tank to be dropped onto (or none: you are flung into a hop). It closes as you walk away. At the left edge a ticket
-- says where the sub will take you when you next jump in. The server decides everything (SubService: Action
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
local GREY = Color3.fromRGB(150, 160, 175)
local NONE_TINT = Color3.fromRGB(96, 120, 150) -- the NO SUB card

-- sizes in the window's points (Shop.window fits them to the screen)
local WIDE, HIGH = 800, 520
local CARD_W, CARD_H = 188, 300
local TOP = 34 -- the tagline row
local FOOT = 62 -- the footer bar

local gui: ScreenGui -- the ticket and the hint
local window: Shop.Window
local carousel: Shop.Carousel
local ticket: TextLabel
local coinsLabel: TextLabel
local freeLabel: TextLabel
local fishButton: Shop.Button
local goButton: Shop.Button
local prompt: ProximityPrompt? = nil
type Row = { Card: Shop.Card, Zone: TextLabel, Button: Shop.Button }
local shopRows: { [number]: Row } = {} -- 0: no sub
local hintLabel: TextLabel
local hintAt = -math.huge
local open = false

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
	ticket.Text = if going then "SUB > " .. landName(dest) else "SUB: OFF"
	ticket.TextColor3 = if going then YELLOW else GREY
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
			-- further on: its price, grey (buy the ones before it first)
			row.Button.set(cost, "Off", false)
		end
	end
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
	local model = SubModels.build(n)
	local sign = model:FindFirstChild("Label", true)
	if sign then
		sign:Destroy()
	end
	model.Parent = view
	local cam = Instance.new("Camera")
	cam.FieldOfView = 30
	cam.CFrame = CFrame.lookAt(Vector3.new(-44, 18, -36), Vector3.new(0, 2, 0))
	cam.Parent = view
	view.CurrentCamera = cam
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
			WellHigh = 112,
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
		})
		b.Root.Activated:Connect(function()
			if not b.Live then
				return
			end
			if n >= 1 and n > attr("SubTier", 0) then
				Net.Action:FireServer("SubBuy")
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

local function show(on: boolean)
	open = on and State.Mode == "Dock"
	window.show(open)
	if open then
		refresh()
		-- the equipped sub in view
		task.defer(function()
			carousel.show(attr("SubEquip", 0) + 1)
		end)
	end
end

-- The stand's ring (nil: not in the place, or not streamed in yet)
local function standRing(): BasePart?
	local blockout = workspace:FindFirstChild("ClaudeBlockout")
	local dock = blockout and blockout:FindFirstChild("Dock")
	local stations = dock and dock:FindFirstChild("Stations")
	local stand = stations and stations:FindFirstChild("Sub")
	local ring = stand and (stand:FindFirstChild("Ring") or (stand:IsA("Model") and stand.PrimaryPart))
	return if ring and ring:IsA("BasePart") then ring else nil
end

-- The prompt on the stand's ring, made once it is there (and again if the stand is rebuilt)
local function keepPrompt()
	local ring = standRing()
	if not ring or (prompt and prompt.Parent == ring) then
		return
	end
	if prompt then
		prompt:Destroy()
	end
	local p = Instance.new("ProximityPrompt")
	p.Name = "SubShop"
	p.ActionText = "Submarines"
	p.ObjectText = "Sub shop"
	p.KeyboardKeyCode = Enum.KeyCode.E
	p.HoldDuration = 0
	p.MaxActivationDistance = 16
	p.RequiresLineOfSight = false
	p.Triggered:Connect(function()
		show(not open)
	end)
	p.Parent = ring
	prompt = p
end

-- A line of help at the foot of the screen while it is asked for (called every frame it should show)
function SubPanel.hint(text: string)
	hintLabel.Text = text
	hintAt = os.clock()
end

-- Studio's tests: open or close the shop as the prompt does
-- Test hook: only the Studio checks call this (tools/studio/s2_subs_check.py, tools/ui/shop_kit/shop_client.luau).
function SubPanel.toggle(on: boolean)
	show(on)
end

function SubPanel.init()
	gui = Instance.new("ScreenGui")
	gui.Name = "SubPanel"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 7
	gui.Parent = State.Player:WaitForChild("PlayerGui")

	-- the ticket at the left edge, where the SUB button was: where the sub takes you
	ticket = Shop.text(gui, {
		Size = UDim2.fromOffset(220, 20),
		Position = UDim2.new(0, 10, 0.5, 112),
		TextSize = 18,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = YELLOW,
	})

	window = Shop.window({
		Name = "SubShop",
		Parent = State.Player:WaitForChild("PlayerGui"),
		Title = "SUBMARINES",
		Icon = "Sub",
		Head = "Sea",
		Width = WIDE,
		Height = HIGH,
		DisplayOrder = 7,
		OnClose = function()
			show(false)
		end,
	})
	local body = window.Body
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
	State.ModeChanged.Event:Connect(function(mode: string)
		ticket.Visible = mode == "Dock"
		if prompt then
			prompt.Enabled = mode == "Dock"
		end
		if mode ~= "Dock" then
			show(false)
		end
	end)
	local lastLook = 0
	RunService.RenderStepped:Connect(function()
		hintLabel.Visible = os.clock() - hintAt < 2.2
		if os.clock() - lastLook > 1 then
			lastLook = os.clock()
			keepPrompt()
		end
		-- walked away from the stand: the shop closes
		if open then
			local ring = standRing()
			local character = State.Player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			if ring and root and root:IsA("BasePart") then
				local gap = root.Position - ring.Position
				if Vector3.new(gap.X, 0, gap.Z).Magnitude > Config.Sub.Near then
					show(false)
				end
			end
		end
	end)
	refresh()
end

return SubPanel
