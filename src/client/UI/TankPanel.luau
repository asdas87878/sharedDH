--!strict
-- The tank's popup (Hugo, 2026-11-19: "Making placing in the fishtank easier, you should be able to click on the plot
-- from nearby, then get a little popup where you can equip the best fish instantly, unequip certain fishes and see how
-- much money they produce and their rarities and special traits (like gold or colossal)").
--   Opening it: a click (or a tap) on one's own tank, from no further than the plot's "PanelReach" studs (written by
--   AquariumService, so both sides use one number). Near enough, the tank's glass is outlined under the mouse and a
--   small sign over the tank says to click or tap it. It closes with its X, a second click on the tank, walking away or
--   leaving the dock.
--   What it shows: every fish in the tank, the equipped ones (which earn and swim there, at most "TankEarning") and the
--   stored ones, and what one carries; each as a card with its picture (UI.Portrait: the partner's renders), name,
--   rarity, size (Tiny to Colossal), colour (Silver, Gold, Rainbow), archetype icons and coins a second. The coins are
--   Config.incomeOf, the one function the server pays by too, so the economy draft's numbers show here as they land.
--   What it asks (the server decides, AquariumService: Action "Tank", verb, ...): EQUIP BEST, EQUIP and UNEQUIP on a
--   card, PUT IN on a carried fish and PUT ALL IN. Refusals come back as Ride "TankDenied", reason.
--   The look (Hugo, 2026-11-20, task s3: "make placing down fishes UI cohesive with these styles"): the shop kit
--   (UI.Shop, task s1), laid out as its sell list: the Kelp header with the tank's earnings, a "Sort by" column
--   (Income, Rarity, Size: this screen's order only), the cards in a dark tray, each tinted in its rarity's colour
--   with its name in that colour and its rate in green, and a footer with the totals, PUT ALL IN and EQUIP BEST.
--   Buttons say what they do in the kit's colours: green EQUIP, blue UNEQUIP (an earning card is outlined light), gold
--   PUT IN, grey FULL (the tank's earning places are all taken; pressing it still asks, and the server says why).
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Archetypes = require(ReplicatedStorage.Shared.Archetypes)
local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)
local State = require(script.Parent.Parent.Lib.State)
local Kit = require(script.Parent.Kit)
local Portrait = require(script.Parent.Portrait)
local Shop = require(script.Parent.Shop)

local TankPanel = {}

-- sizes in the window's own points (it is scaled to the screen)
local PANEL_W, PANEL_H = 860, 540
local SIDE = 168 -- the "Sort by" column
local FOOT = 64 -- the footer bar
local CARD_W, CARD_H = 150, 218
local GAP = 10
local CLICK_MOVE = 12 -- a press that moves further than this (pixels) is a camera drag, not a click
local CLICK_TIME = 0.45

local SIZE_HUE = { -- as the fish tags' size words (UI.Tags), cool to hot
	Tiny = Color3.fromRGB(150, 178, 204),
	Normal = Color3.fromRGB(176, 192, 214),
	Big = Color3.fromRGB(84, 226, 190),
	Giant = Color3.fromRGB(80, 182, 255),
	Huge = Color3.fromRGB(255, 160, 48),
	Colossal = Color3.fromRGB(255, 72, 80),
}
local VARIANT_LOOK = {
	Silver = { Top = Color3.fromRGB(226, 234, 244), Bottom = Color3.fromRGB(120, 136, 160), Word = "SILVER" },
	Gold = { Top = Color3.fromRGB(255, 232, 110), Bottom = Color3.fromRGB(226, 140, 16), Word = "GOLD" },
	Rainbow = { Top = Color3.new(1, 1, 1), Bottom = Color3.new(1, 1, 1), Word = "RAINBOW" },
}
local RAINBOW = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 120, 140)),
	ColorSequenceKeypoint.new(0.2, Color3.fromRGB(255, 200, 110)),
	ColorSequenceKeypoint.new(0.4, Color3.fromRGB(240, 250, 130)),
	ColorSequenceKeypoint.new(0.6, Color3.fromRGB(130, 240, 170)),
	ColorSequenceKeypoint.new(0.8, Color3.fromRGB(120, 190, 255)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(200, 140, 255)),
})
local TIER_RANK = { Common = 1, Uncommon = 2, Rare = 3, Epic = 4, Legendary = 5, Mythic = 6, Secret = 7 }
local SIZE_RANK: { [string]: number } = {}
for i, name in Config.SizeOrder do
	SIZE_RANK[name] = i
end
local SORTS = { "Income", "Rarity", "Size" }

type Fish = { Key: string, Id: string, Size: string, Variant: string, On: boolean, Hand: number? }
type Card = {
	Root: Frame,
	Fill: UIGradient,
	Edge: UIStroke,
	Ring: UIStroke,
	Name: TextLabel,
	Info: TextLabel,
	Back: Frame,
	BackFill: UIGradient,
	Picture: Portrait.Portrait,
	VariantChip: Frame,
	VariantWord: TextLabel,
	VariantFill: UIGradient,
	Icons: Frame,
	Rate: TextLabel,
	Button: Shop.Button,
	Fish: Fish,
}

local window: Shop.Window
local list: ScrollingFrame
local tray: Frame
local headIncome: TextLabel
local footIncome: TextLabel
local countPill: Frame
local countWord: TextLabel
local bestButton: Shop.Button
local allButton: Shop.Button
local sortButtons: { [string]: Shop.Button } = {}
local sortBy = "Income"
local empty: TextLabel
local note: TextLabel
local toast: Frame
local toastWord: TextLabel
local toastAt = -math.huge
local sections: { [string]: { Head: TextLabel, Grid: Frame, Layout: UIGridLayout } } = {}
local cards: { [string]: Card } = {}
local open = false
local touch = false

local hint: BillboardGui? = nil
local farAt = -math.huge -- when a click on the tank came from too far away
local outline: Highlight? = nil

local function attr(name: string, default: any): any
	local value = State.Player:GetAttribute(name)
	return if value == nil then default else value
end

local function decode(name: string): { any }
	local ok, rows = pcall(function()
		return HttpService:JSONDecode(attr(name, "[]"))
	end)
	return if ok and type(rows) == "table" then rows else {}
end

-- What a fish earns a second: the server's own function (AquariumService pays by it too)
local function incomeOf(f: Fish): number
	local kind = Config.FishById[f.Id]
	return if kind then Config.incomeOf(kind, f.Size, f.Variant) else 0
end

local function tankRows(): { Fish }
	local out: { Fish } = {}
	for _, row in decode("TankList") do
		if type(row) == "table" and type(row[1]) == "string" and type(row[2]) == "string" then
			table.insert(out, {
				Key = row[1],
				Id = row[2],
				Size = tostring(row[3] or "Normal"),
				Variant = tostring(row[4] or ""),
				On = row[5] == 1,
			})
		end
	end
	return out
end

local function handRows(): { Fish }
	local out: { Fish } = {}
	for i, row in decode("Hands") do
		if type(row) == "table" and type(row[1]) == "string" then
			table.insert(out, {
				Key = "H" .. i .. "|" .. row[1],
				Id = row[1],
				Size = tostring(row[2] or "Normal"),
				Variant = tostring(row[3] or ""),
				On = false,
				Hand = i,
			})
		end
	end
	return out
end

-- Our own plot, and its tank's water (nil: no tank, or not streamed in)
local function ownPlot(): (Model?, BasePart?)
	local name = State.Player:GetAttribute("Plot")
	local blockout = workspace:FindFirstChild("ClaudeBlockout")
	local dock = blockout and blockout:FindFirstChild("Dock")
	local plots = dock and dock:FindFirstChild("Plots")
	local plot = plots and type(name) == "string" and plots:FindFirstChild(name)
	if not plot or not plot:IsA("Model") then
		return nil, nil
	end
	local water = plot:FindFirstChild("TankWater")
	return plot, if water and water:IsA("BasePart") then water else nil
end

-- How far we stand from our tank's water, across the floor (math.huge with no tank), and the reach it opens from
local function distance(): (number, number)
	local plot, water = ownPlot()
	local _, root = State.character()
	if not plot or not water or not root then
		return math.huge, 0
	end
	local offset = water.CFrame:PointToObjectSpace(root.Position)
	local half = water.Size / 2
	local dx = math.max(math.abs(offset.X) - half.X, 0)
	local dz = math.max(math.abs(offset.Z) - half.Z, 0)
	local reach = plot:GetAttribute("PanelReach")
	return math.sqrt(dx * dx + dz * dz), if type(reach) == "number" then reach else 36
end

-- The tank's box, as a click sees it: the water grown a little on every side, down over the base and up over the rim
-- and the sign. (The tank's glass, water and sign are CanQuery off in the map, so a raycast passes through them; the
-- ray is tested against this box instead, which needs nothing of the map's parts but the water)
local GROW = Vector3.new(4, 10, 4)

-- Whether a point on the screen is over our tank: an input's Position (under the top bar's inset), or with `whole`
-- a point on the whole viewport (UserInputService:GetMouseLocation)
local function overTank(x: number, y: number, whole: boolean?): boolean
	local _, water = ownPlot()
	local camera = workspace.CurrentCamera
	if not water or not camera then
		return false
	end
	local ray = if whole then camera:ViewportPointToRay(x, y) else camera:ScreenPointToRay(x, y)
	-- the slab test, in the water's own space
	local origin = water.CFrame:PointToObjectSpace(ray.Origin)
	local direction = water.CFrame:VectorToObjectSpace(ray.Direction)
	local half = (water.Size + GROW) / 2
	local near, far = -math.huge, math.huge
	for _, axis in { "X", "Y", "Z" } do
		local o, d, h = (origin :: any)[axis], (direction :: any)[axis], (half :: any)[axis]
		if math.abs(d) < 1e-6 then
			if math.abs(o) > h then
				return false
			end
		else
			local a, b = (-h - o) / d, (h - o) / d
			near = math.max(near, math.min(a, b))
			far = math.min(far, math.max(a, b))
		end
	end
	return near <= far and far > 0 and near < 600
end

local function say(text: string)
	toastWord.Text = text
	toastAt = os.clock()
end

-- A rarity's colour as the cards use it (the Secret's own colour is near black: on a dark card its words are drawn
-- white and its tint pink)
local function tierLook(tier: string): (Color3, Color3)
	local entry = Config.Tiers[tier]
	local colour = if entry then entry.Colour else Kit.White
	if colour.R + colour.G + colour.B < 0.6 then
		return Kit.White, Kit.Pink
	end
	return colour, colour
end

local function hex(c: Color3): string
	return string.format("#%02X%02X%02X", math.round(c.R * 255), math.round(c.G * 255), math.round(c.B * 255))
end

local function newCard(f: Fish): Card
	local root: Frame = Kit.new("Frame", {
		Name = "Card",
		BackgroundColor3 = Kit.White,
		BorderSizePixel = 0,
	}, nil)
	Kit.corner(root, 6)
	local fill = Kit.new("UIGradient", { Rotation = 90 }, root)
	local edge = Kit.stroke(root, 3, Shop.Edge)
	edge.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	Shop.pattern(root, "Head", 30, 0.9)
	Shop.gloss(root, 0.72, 0.1)
	-- the light border of an earning card (as the shop's chosen card)
	local ring: UIStroke = Kit.new(
		"UIStroke",
		{
			Name = "Earning",
			Thickness = 0,
			Color = Color3.fromRGB(236, 255, 230),
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		},
		Kit.new("Frame", {
			Name = "EarningRing",
			Position = UDim2.fromOffset(-4, -4),
			Size = UDim2.new(1, 8, 1, 8),
			BackgroundTransparency = 1,
			ZIndex = 1,
		}, root)
	)

	local name = Shop.text(root, {
		Name = "FishName",
		Position = UDim2.fromOffset(8, 5),
		Size = UDim2.new(1, -16, 0, 20),
		TextSize = 18,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		ZIndex = 4,
	})
	local info = Shop.text(root, {
		Name = "Info",
		Position = UDim2.fromOffset(8, 25),
		Size = UDim2.new(1, -16, 0, 15),
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Left,
		RichText = true,
		ZIndex = 4,
	})

	-- the picture, on a dark well that turns gold or rainbow with the fish
	local back: Frame = Kit.new("Frame", {
		Name = "Back",
		Position = UDim2.fromOffset(7, 44),
		Size = UDim2.new(1, -14, 0, 100),
		BackgroundColor3 = Kit.White,
		BorderSizePixel = 0,
		ZIndex = 2,
	}, root)
	Kit.corner(back, 4)
	Kit.stroke(back, 2, Shop.Edge).ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	local backFill = Kit.new("UIGradient", { Rotation = 90 }, back)
	Shop.pattern(back, "Body", 30, 0.9)
	local picture = Portrait.new(back, {
		Position = UDim2.fromOffset(2, 4),
		Size = UDim2.new(1, -4, 1, -8),
		ZIndex = 3,
	})
	local chip: Frame = Kit.new("Frame", {
		Name = "Variant",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -3, 0, 3),
		Size = UDim2.fromOffset(60, 17),
		BackgroundColor3 = Kit.White,
		BorderSizePixel = 0,
		ZIndex = 5,
	}, back)
	Kit.corner(chip, 4)
	Kit.stroke(chip, 2, Shop.Edge).ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	local chipFill = Kit.new("UIGradient", {}, chip)
	local chipWord = Shop.text(chip, {
		Size = UDim2.fromScale(1, 1),
		TextSize = 12,
		ZIndex = 6,
	})
	local icons: Frame = Kit.new("Frame", {
		Name = "Icons",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 4, 1, -3),
		Size = UDim2.new(1, -8, 0, 18),
		BackgroundTransparency = 1,
		ZIndex = 5,
	}, back)
	Kit.new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, 2),
		SortOrder = Enum.SortOrder.LayoutOrder,
		VerticalAlignment = Enum.VerticalAlignment.Bottom,
	}, icons)

	-- what it earns, in the shop's green, and the button
	local rate = Shop.text(root, {
		Name = "Rate",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 146),
		Size = UDim2.new(1, -12, 0, 26),
		TextSize = 25,
		TextColor3 = Shop.Money,
		ZIndex = 4,
	})
	local b = Shop.button(root, {
		Name = "Do",
		Text = "EQUIP",
		TextSize = 18,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -7),
		Size = UDim2.new(1, -14, 0, 36),
	})
	b.Root.ZIndex = 4

	local card: Card = {
		Root = root,
		Fill = fill,
		Edge = edge,
		Ring = ring,
		Name = name,
		Info = info,
		Back = back,
		BackFill = backFill,
		Picture = picture,
		VariantChip = chip,
		VariantWord = chipWord,
		VariantFill = chipFill,
		Icons = icons,
		Rate = rate,
		Button = b,
		Fish = f,
	}
	b.Root.Activated:Connect(function()
		local now = card.Fish
		if now.Hand then
			Net.Action:FireServer("Tank", "PutIn", now.Hand, now.Id)
		elseif now.On then
			Net.Action:FireServer("Tank", "Unequip", now.Key)
		else
			Net.Action:FireServer("Tank", "Equip", now.Key)
		end
	end)
	return card
end

local function fill(card: Card, f: Fish, full: boolean)
	card.Fish = f
	local kind = Config.FishById[f.Id]
	card.Picture.show(f.Id)
	local tier = if kind then kind.Tier else "Common"
	local words, tint = tierLook(tier)
	card.Name.Text = if kind then kind.Name else f.Id
	card.Name.TextColor3 = words
	card.Info.Text = string.format(
		'<font color="%s">%s</font>  <font color="%s">%s</font>',
		hex(Kit.lighter(words, 0.25)),
		string.upper(tier),
		hex(SIZE_HUE[f.Size] or Kit.White),
		string.upper(f.Size)
	)
	-- tinted in its rarity's colour: lit at the top, deepening into the shop's slate
	card.Fill.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Shop.Body:Lerp(Kit.lighter(tint, 0.1), 0.62)),
		ColorSequenceKeypoint.new(0.45, Shop.Body:Lerp(tint, 0.42)),
		ColorSequenceKeypoint.new(1, Shop.Body:Lerp(tint, 0.16)),
	})
	card.Ring.Thickness = if f.On then 3 else 0
	card.Edge.Color = if f.On then Kit.White else Shop.Edge
	local look = VARIANT_LOOK[f.Variant]
	card.VariantChip.Visible = look ~= nil
	if look then
		card.VariantWord.Text = look.Word
		card.VariantFill.Rotation = if f.Variant == "Rainbow" then 0 else 90
		card.VariantFill.Color = if f.Variant == "Rainbow" then RAINBOW else ColorSequence.new(look.Top, look.Bottom)
		card.BackFill.Rotation = if f.Variant == "Rainbow" then 20 else 90
		card.BackFill.Color = if f.Variant == "Rainbow"
			then RAINBOW
			else ColorSequence.new(Kit.lighter(look.Top, 0.2), look.Bottom)
	else
		card.BackFill.Rotation = 90
		card.BackFill.Color = ColorSequence.new(Shop.BodyDeep:Lerp(tint, 0.18), Shop.BodyDeep)
	end
	Archetypes.icons(card.Icons, if kind then Archetypes.line(kind) else "", 18)
	card.Rate.Text = Shop.cash(incomeOf(f)) .. "/s"
	if f.Hand then
		card.Button.set("PUT IN", "Gold", true)
	elseif f.On then
		card.Button.set("UNEQUIP", "Blue", true)
	elseif full then
		-- (still live: the server answers "Full" and the toast says to unequip one first)
		card.Button.set("FULL", "Off", true)
	else
		card.Button.set("EQUIP", "Cash", true)
	end
end

local function section(name: string, order: number)
	local head = Shop.text(list, {
		Name = name .. "Head",
		Size = UDim2.new(1, -8, 0, 26),
		TextSize = 22,
		TextXAlignment = Enum.TextXAlignment.Left,
		RichText = true,
		LayoutOrder = order,
		ZIndex = 3,
	})
	local grid: Frame = Kit.new("Frame", {
		Name = name,
		Size = UDim2.new(1, -8, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		LayoutOrder = order + 1,
		ZIndex = 3,
	}, list)
	local layout = Kit.new("UIGridLayout", {
		CellSize = UDim2.fromOffset(CARD_W, CARD_H),
		CellPadding = UDim2.fromOffset(GAP, GAP),
		SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = Enum.HorizontalAlignment.Left,
	}, grid)
	sections[name] = { Head = head, Grid = grid, Layout = layout }
end

local function byIncome(a: Fish, b: Fish): boolean
	local x, y = incomeOf(a), incomeOf(b)
	return if x ~= y then x > y else a.Key < b.Key
end

-- The order the cards are shown in ("Sort by"): only this screen's; which fish earn is the server's
local function order(a: Fish, b: Fish): boolean
	if sortBy == "Rarity" then
		local ka, kb = Config.FishById[a.Id], Config.FishById[b.Id]
		local x = TIER_RANK[if ka then ka.Tier else "Common"] or 0
		local y = TIER_RANK[if kb then kb.Tier else "Common"] or 0
		if x ~= y then
			return x > y
		end
	elseif sortBy == "Size" then
		local x, y = SIZE_RANK[a.Size] or 0, SIZE_RANK[b.Size] or 0
		if x ~= y then
			return x > y
		end
	end
	return byIncome(a, b)
end

local function refresh()
	if not open then
		return
	end
	local fish = tankRows()
	local hands = handRows()
	local most = attr("TankEarning", Config.Aquarium.Earning)
	local equipped, stored = {}, {}
	local income = 0
	for _, f in fish do
		if f.On then
			table.insert(equipped, f)
			income += incomeOf(f)
		else
			table.insert(stored, f)
		end
	end
	local full = #equipped >= most
	headIncome.Text = Shop.cash(income) .. "/s"
	footIncome.Text = Shop.cash(income) .. "/s"

	-- EQUIP BEST is bright while it would change something: a free place and a stored fish, or a stored fish that
	-- earns more than the poorest equipped one
	table.sort(equipped, byIncome)
	table.sort(stored, byIncome)
	local better = #stored > 0 and (not full or (#equipped > 0 and incomeOf(stored[1]) > incomeOf(equipped[#equipped])))
	bestButton.set(if better then "EQUIP BEST" else "BEST EQUIPPED", if better then "Cash" else "Off", true)
	allButton.Root.Visible = #hands > 0
	allButton.set("PUT ALL IN (" .. #hands .. ")", "Gold", true)
	-- the count: how many earn of how many may; red when the tank is full
	countWord.Text = (if full then "Tank full " else "Earning ") .. #equipped .. "/" .. most
	local pill = countPill:FindFirstChildOfClass("UIGradient") :: UIGradient
	local pair = if full then Shop.Kinds.Red else Shop.Kinds.Off
	pill.Color = Shop.halves(Kit.darker(pair[1], 0.45), Kit.darker(pair[2], 0.5))
	note.Text = "Only earning fish make coins. Up to " .. most .. " at once."

	table.sort(equipped, order)
	table.sort(stored, order)
	table.sort(hands, order)
	local seen: { [string]: boolean } = {}
	local function lay(rows: { Fish }, where: string)
		for i, f in rows do
			local key = if f.Hand then f.Key else "T" .. f.Key
			seen[key] = true
			local card = cards[key]
			if not card then
				card = newCard(f)
				cards[key] = card
			end
			card.Root.LayoutOrder = i
			card.Root.Parent = sections[where].Grid
			fill(card, f, full)
		end
	end
	lay(hands, "Hands")
	lay(equipped, "Earning")
	lay(stored, "Stored")
	for key, card in cards do
		if not seen[key] then
			card.Root:Destroy()
			cards[key] = nil
		end
	end
	local gold = hex(Kit.Sun)
	sections.Hands.Head.Visible = #hands > 0
	sections.Hands.Grid.Visible = #hands > 0
	sections.Hands.Head.Text = string.format('<font color="%s">In your hands</font>  %d', gold, #hands)
	sections.Earning.Head.Visible = #equipped > 0
	sections.Earning.Grid.Visible = #equipped > 0
	sections.Earning.Head.Text = string.format("Earning  %d/%d", #equipped, most)
	sections.Stored.Head.Visible = #stored > 0
	sections.Stored.Grid.Visible = #stored > 0
	sections.Stored.Head.Text = "Stored  " .. #stored
	empty.Visible = #fish == 0 and #hands == 0
end

-- The window's size and its points for this screen; the cards' columns follow the width. (Shop.window's own fit, made
-- roomier on a phone: the window takes the whole height there, so the cards' words stay readable)
local function layout()
	local camera = workspace.CurrentCamera
	if not camera or not window then
		return
	end
	local view = camera.ViewportSize
	touch = Kit.touch()
	-- (Studio's phone still: the workspace's "PanelPhone", a phone's screen in pixels, lays the window out for that
	-- screen in a box of its size in the middle of this one)
	local phone = if RunService:IsStudio() then workspace:GetAttribute("PanelPhone") else nil
	if typeof(phone) == "Vector2" then
		view = phone
		touch = true
	end
	local s = math.clamp(view.Y / (if touch then 430 else 720), 0.5, 1.4)
	local w = math.min(PANEL_W, view.X / s - 24)
	local h = math.min(PANEL_H, view.Y / s - 14)
	window.Scale.Scale = s
	window.Frame.Size = UDim2.fromOffset(w, h)
	window.Root.Size = UDim2.fromScale(1 / s, 1 / s)
	window.Root.Position = UDim2.new()
	if typeof(phone) == "Vector2" then
		local whole = camera.ViewportSize
		window.Root.Size = UDim2.fromOffset(view.X / s, view.Y / s)
		window.Root.Position = UDim2.fromOffset((whole.X - view.X) / 2, (whole.Y - view.Y) / 2)
	end
	-- the tray's width: the window's, less its body's padding, the side column and the gap
	local trayWide = w - (Shop.Pad + 2) * 2 - SIDE - 12
	local columns = math.max(1, math.floor((trayWide - 26 + GAP) / (CARD_W + GAP)))
	for _, s2 in sections do
		s2.Layout.FillDirectionMaxCells = columns
	end
end

local function show(on: boolean)
	open = on and State.Mode == "Dock"
	if open then
		refresh()
	end
	window.show(open)
end

-- Studio's tests: open or close the popup as a click on the tank does
function TankPanel.toggle(on: boolean)
	show(on)
end

function TankPanel.isOpen(): boolean
	return open
end

-- The cards' order ("Income", "Rarity" or "Size"): the Sort by buttons, and Studio's tests
function TankPanel.sort(name: string)
	sortBy = name
	for other, b in sortButtons do
		b.set(nil, if other == sortBy then "Cash" else "Off")
	end
	refresh()
end

-- A line in the toast (Studio's tests: the refusals' look)
function TankPanel.notice(text: string)
	say(text)
end

local function build()
	window = Shop.window({
		Name = "TankPanel",
		Parent = State.Player:WaitForChild("PlayerGui"),
		Title = "Your Tank",
		Icon = "Bubble",
		Head = "Kelp",
		Width = PANEL_W,
		Height = PANEL_H,
		DisplayOrder = 8,
		OnClose = function()
			show(false)
		end,
	})
	window.fit = layout
	local body = window.Body

	-- the tank's earnings in the header, before the X
	local label, holder = Shop.money(window.Header, {
		Name = "Income",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -(Shop.HeadHigh + 2), 0.5, 0),
		Size = UDim2.fromOffset(300, 40),
		TextSize = 34,
		ZIndex = 4,
	})
	headIncome = label
	holder.ZIndex = 4

	-- the "Sort by" column
	local side: Frame = Kit.new("Frame", {
		Name = "Side",
		Size = UDim2.new(0, SIDE, 1, -(FOOT + 12)),
		BackgroundTransparency = 1,
		ZIndex = 3,
	}, body)
	Kit.new("UIListLayout", {
		Padding = UDim.new(0, 10),
		SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
	}, side)
	Shop.text(side, { Size = UDim2.new(1, 0, 0, 28), TextSize = 26, Text = "Sort by:", LayoutOrder = 1, ZIndex = 3 })
	for i, name in SORTS do
		local b = Shop.sort(side, {
			Name = "Sort" .. name,
			Text = "  " .. name,
			On = name == sortBy,
			Size = UDim2.new(1, 0, 0, 44),
			LayoutOrder = 1 + i,
		})
		sortButtons[name] = b
		b.Root.Activated:Connect(function()
			TankPanel.sort(name)
		end)
	end
	note = Shop.text(side, {
		Name = "Note",
		Size = UDim2.new(1, -6, 0, 54),
		TextSize = 14,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextColor3 = Color3.fromRGB(196, 204, 220),
		LayoutOrder = 9,
		ZIndex = 3,
	})

	-- the cards' tray
	tray = Shop.inset(body, {
		Name = "Tray",
		Position = UDim2.fromOffset(SIDE + 12, 0),
		Size = UDim2.new(1, -(SIDE + 12), 1, -(FOOT + 12)),
		ZIndex = 2,
	})
	list = Kit.new("ScrollingFrame", {
		Name = "List",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 8,
		ScrollBarImageColor3 = Color3.fromRGB(150, 220, 120),
		ScrollingDirection = Enum.ScrollingDirection.Y,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		ZIndex = 3,
	}, tray)
	Kit.new("UIListLayout", {
		Padding = UDim.new(0, 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
	}, list)
	Kit.new("UIPadding", {
		PaddingTop = UDim.new(0, 8),
		PaddingBottom = UDim.new(0, 12),
		PaddingLeft = UDim.new(0, 12),
		PaddingRight = UDim.new(0, 12),
	}, list)
	section("Hands", 1)
	section("Earning", 3)
	section("Stored", 5)
	empty = Shop.text(tray, {
		Name = "Empty",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.45),
		Size = UDim2.new(1, -40, 0, 70),
		TextSize = 26,
		TextWrapped = true,
		Text = "No fish yet!\nCatch some and put them in.",
		Visible = false,
		ZIndex = 4,
	})

	-- the footer: the totals, PUT ALL IN, EQUIP BEST
	local foot = Shop.inset(body, {
		Name = "Footer",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, FOOT),
		ZIndex = 2,
	})
	local totals: Frame = Kit.new("Frame", {
		Name = "Totals",
		Position = UDim2.fromOffset(16, 0),
		Size = UDim2.new(1, -420, 1, 0),
		BackgroundTransparency = 1,
		ZIndex = 3,
	}, foot)
	Kit.new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = UDim.new(0, 10),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, totals)
	Shop.text(totals, {
		Size = UDim2.fromOffset(0, 34),
		AutomaticSize = Enum.AutomaticSize.X,
		TextSize = 28,
		Text = "Earning:",
		LayoutOrder = 1,
		ZIndex = 3,
	})
	local fi, fh = Shop.money(totals, {
		Name = "Total",
		Size = UDim2.fromOffset(0, 36),
		TextSize = 28,
		Align = Enum.HorizontalAlignment.Left,
		ZIndex = 3,
	})
	fh.AutomaticSize = Enum.AutomaticSize.X
	fh.LayoutOrder = 2
	footIncome = fi
	countPill = Kit.new("Frame", {
		Name = "Count",
		Size = UDim2.fromOffset(0, 34),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = Kit.White,
		BorderSizePixel = 0,
		LayoutOrder = 3,
		ZIndex = 3,
	}, totals)
	Kit.corner(countPill, 5)
	Kit.stroke(countPill, 2, Shop.Edge)
	Kit.new("UIGradient", { Rotation = 90 }, countPill)
	Kit.new("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10) }, countPill)
	countWord = Shop.text(countPill, {
		Size = UDim2.fromScale(0, 1),
		AutomaticSize = Enum.AutomaticSize.X,
		TextSize = 19,
		ZIndex = 4,
	})
	bestButton = Shop.button(foot, {
		Name = "Best",
		Text = "EQUIP BEST",
		Kind = "Cash",
		TextSize = 22,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -10, 0.5, 0),
		Size = UDim2.fromOffset(196, 46),
	})
	bestButton.Root.ZIndex = 4
	bestButton.Root.Activated:Connect(function()
		Net.Action:FireServer("Tank", "Best")
	end)
	allButton = Shop.button(foot, {
		Name = "PutAll",
		Text = "PUT ALL IN",
		Kind = "Gold",
		TextSize = 20,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -216, 0.5, 0),
		Size = UDim2.fromOffset(190, 46),
	})
	allButton.Root.ZIndex = 4
	allButton.Root.Activated:Connect(function()
		Net.Action:FireServer("Tank", "PutAll")
	end)

	-- a refusal, over the tray's foot: the kit's red bar
	toast = Kit.new("Frame", {
		Name = "Toast",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, (SIDE + 12) / 2, 1, -(FOOT + 22)),
		Size = UDim2.fromOffset(470, 44),
		BackgroundColor3 = Kit.White,
		BorderSizePixel = 0,
		Visible = false,
		ZIndex = 8,
	}, body)
	Kit.corner(toast, 6)
	Kit.stroke(toast, 3, Shop.Edge)
	Kit.new("UIGradient", { Rotation = 90, Color = Shop.halves(Shop.Kinds.Red[1], Shop.Kinds.Red[2]) }, toast)
	Shop.pattern(toast, "Head", 26, 0.88)
	toastWord = Shop.text(toast, { Size = UDim2.fromScale(1, 1), TextSize = 21, ZIndex = 9 })
end

-- The sign over our tank while we are near it with the popup shut (a small plate in the tank's Kelp, as the window's
-- header), and the glass outlined under the mouse in the same green
local function keepHint(near: boolean, hovered: boolean)
	local _, water = ownPlot()
	if not water then
		return
	end
	if not hint or hint.Adornee ~= water then
		if hint then
			hint:Destroy()
		end
		local b: BillboardGui = Kit.new("BillboardGui", {
			Name = "TankHint",
			Adornee = water,
			AlwaysOnTop = true,
			LightInfluence = 0,
			Size = UDim2.fromOffset(250, 44),
			StudsOffsetWorldSpace = Vector3.new(0, water.Size.Y / 2 + 9, 0),
			MaxDistance = 200,
		}, State.Player:WaitForChild("PlayerGui"))
		local plate: Frame = Kit.new("Frame", {
			Name = "Plate",
			Position = UDim2.fromOffset(3, 3),
			Size = UDim2.new(1, -6, 1, -6),
			BackgroundColor3 = Kit.White,
			BorderSizePixel = 0,
		}, b)
		Kit.corner(plate, 6)
		Kit.stroke(plate, 3, Shop.Edge)
		Kit.new("UIGradient", {
			Rotation = 90,
			Color = Shop.halves(Kit.lighter(Shop.Heads.Kelp, 0.22), Shop.Heads.Kelp, 0.46),
		}, plate)
		Shop.pattern(plate, "Head", 26, 0.84)
		Shop.gloss(plate, 0.66, 0.26)
		Shop.text(plate, { Name = "Word", Size = UDim2.fromScale(1, 1), TextSize = 22, ZIndex = 3 })
		hint = b
	end
	local h = hint :: BillboardGui
	local far = os.clock() - farAt < 2
	h.Enabled = (near or far) and not open
	local w = h:FindFirstChild("Word", true)
	if w and w:IsA("TextLabel") then
		w.Text = if near then (if touch then "TAP YOUR TANK" else "CLICK YOUR TANK") else "WALK CLOSER!"
	end
	if not outline or outline.Adornee ~= water then
		if outline then
			outline:Destroy()
		end
		outline = Kit.new("Highlight", {
			Name = "TankHover",
			Adornee = water,
			FillColor = Shop.Heads.Kelp,
			FillTransparency = 0.88,
			OutlineColor = Color3.fromRGB(200, 255, 150),
			DepthMode = Enum.HighlightDepthMode.Occluded,
		}, State.Player:WaitForChild("PlayerGui"))
	end
	(outline :: Highlight).Enabled = hovered and near and not open
end

-- A press on the world (not on a button): a click if it neither moved far nor lasted long
local function watchClicks()
	local downAt: { [InputObject]: { at: Vector3, t: number } } = {}
	UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
		if processed then
			return
		end
		local kind = input.UserInputType
		if kind == Enum.UserInputType.MouseButton1 or kind == Enum.UserInputType.Touch then
			downAt[input] = { at = input.Position, t = os.clock() }
		end
	end)
	UserInputService.InputEnded:Connect(function(input: InputObject, processed: boolean)
		local start = downAt[input]
		downAt[input] = nil
		if not start or processed or State.Mode ~= "Dock" then
			return
		end
		if (input.Position - start.at).Magnitude > CLICK_MOVE or os.clock() - start.t > CLICK_TIME then
			return
		end
		TankPanel.click(input.Position.X, input.Position.Y)
	end)
end

-- A click or tap at a point on the screen (an input's Position): on our tank and near enough, the popup opens (or
-- shuts); too far, the sign over the tank says to come closer. Studio's tests call it too. True when it was on the tank
function TankPanel.click(x: number, y: number): boolean
	if State.Mode ~= "Dock" or not overTank(x, y) then
		return false
	end
	local gap, reach = distance()
	if gap <= reach then
		show(not open)
	elseif not open then
		farAt = os.clock() -- (the sign over the tank says to come closer)
	end
	return true
end

function TankPanel.init()
	if Config.Aquarium.On == 0 then
		return
	end
	build()
	watchClicks()
	for _, name in { "TankList", "Hands", "TankEarning" } do
		State.Player:GetAttributeChangedSignal(name):Connect(refresh)
	end
	Net.Ride.OnClientEvent:Connect(function(kind: string, reason: any)
		if kind == "TankDenied" then
			say(
				if reason == "Full"
					then "THE TANK IS FULL: UNEQUIP ONE FIRST"
					elseif reason == "Far" then "TOO FAR FROM YOUR TANK"
					else "THAT FISH IS GONE"
			)
		end
	end)
	State.ModeChanged.Event:Connect(function(mode: string)
		if mode ~= "Dock" then
			show(false)
		end
	end)
	local camera = workspace.CurrentCamera
	if camera then
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(layout)
	end
	UserInputService.LastInputTypeChanged:Connect(function()
		if Kit.touch() ~= touch then
			layout()
		end
	end)
	layout()
	local lastLook = 0
	local near, hovered = false, false
	RunService.RenderStepped:Connect(function()
		toast.Visible = os.clock() - toastAt < 2.2
		if os.clock() - lastLook < 0.1 then
			return
		end
		lastLook = os.clock()
		if State.Mode ~= "Dock" then
			near, hovered = false, false
		else
			local gap, reach = distance()
			near = gap <= reach
			local mouse = UserInputService:GetMouseLocation()
			hovered = near and not touch and overTank(mouse.X, mouse.Y, true)
			-- walked away: it closes
			if open and gap > reach + 8 then
				show(false)
			end
		end
		keepHint(near, hovered)
	end)
end

return TankPanel
