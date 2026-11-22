--!strict
-- The shop's Sell Fish page (Hugo, 2026-11-22, task b2: "integrate both aura shop ui and selling dinos ui (as in
-- reference pic 1) in this same style as before"). Laid out after the reference's sell window, drawn with the shop
-- kit (UI/Shop): the title bar with its icon and the red X; a left column with "Sort by" (Value, Rarity), Select All
-- and the note that equipped fish can't be sold; a scrolling grid of cards (the name in its rarity's colour, the size
-- and colour as small words, the fish's picture, what it earns a second in green, what it sells for in a dark strip);
-- and a foot bar with the Total Value and Sell (n).
--   What it lists: everything the player has, from the server's own lists: the "TankList" attribute (the tank, which
--   is the inventory: key, id, size, variant, 1 if equipped) and "Hands" (what they carry). A fish equipped in the
--   tank is shown last, dimmed, marked EQUIPPED, and can't be picked.
--   Picking: a press on a card picks it (the light border and a tick), another press lets it go. Select All picks
--   every fish that can be sold, or lets them all go.
--   Selling: Sell (n) asks SURE? once (a sale can't be undone), then asks the server for each picked fish, one after
--   another, waiting for each answer: Action "Sell", "Tank", key | "Hand", index, id (AquariumService; it pays
--   Config.sellOf and answers Ride "Sold", id, coins or "TankDenied", why). Carried fish go last, the highest place
--   first, so the places of those still to go don't move. The prices shown are Config.sellOf, the function the server
--   pays by; nothing here sends a price.
--   The pictures are UI.Portrait's (the partner's renders from UI.FishIcons, else the live model).
-- It opens when the player stands on the Sell stall's floor ring and closes when they walk off (UI review 1, the user
-- 2026-11-22; Controllers/StallController), with the dim behind it.
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)
local State = require(script.Parent.Parent.Lib.State)
local Anim = require(script.Parent.Anim)
local Kit = require(script.Parent.Kit)
local Portrait = require(script.Parent.Portrait)
local Shop = require(script.Parent.Shop)

local SellFish = {}

-- sizes in the window's own points (Shop.window fits them to the screen)
local WIDE, HIGH = 860, 540
local SIDE = 176 -- the left column
local FOOT = 64 -- the foot bar
local CARD_W, CARD_H = 149, 196
local GAP = 9
local SURE = 2.5 -- seconds Sell (n) asks SURE? before it is Sell again
local ASK_GAP = 0.13 -- seconds between two asks (the server takes ten a second)
local ASK_WAIT = 2 -- seconds to wait for one answer before going on

local SIZE_HUE = { -- as the tank popup's and the fish tags' size words, cool to hot
	Tiny = Color3.fromRGB(150, 178, 204),
	Normal = Color3.fromRGB(176, 192, 214),
	Big = Color3.fromRGB(84, 226, 190),
	Giant = Color3.fromRGB(80, 182, 255),
	Huge = Color3.fromRGB(255, 160, 48),
	Colossal = Color3.fromRGB(255, 72, 80),
}
local VARIANT_HUE = {
	Silver = Color3.fromRGB(214, 224, 238),
	Gold = Color3.fromRGB(255, 214, 70),
}
local RAINBOW = {
	Color3.fromRGB(255, 120, 140),
	Color3.fromRGB(255, 200, 110),
	Color3.fromRGB(240, 250, 130),
	Color3.fromRGB(130, 240, 170),
	Color3.fromRGB(120, 190, 255),
	Color3.fromRGB(200, 140, 255),
}
local TIER_RANK = { Common = 1, Uncommon = 2, Rare = 3, Epic = 4, Legendary = 5, Mythic = 6, Secret = 7 }
local LIGHT = Color3.fromRGB(236, 255, 230) -- a picked card's border (the shop's chosen card)

type Fish = { Key: string, Id: string, Size: string, Variant: string, On: boolean, Hand: number?, Value: number }
type Card = {
	Item: Shop.ItemCard,
	Edge: UIStroke,
	Tags: TextLabel,
	Picture: Portrait.Portrait,
	Tick: Frame,
	Veil: Frame,
	Press: TextButton,
	Fish: Fish?,
}

local window: Shop.Window? = nil
local list: ScrollingFrame
local empty: TextLabel
local total: TextLabel
local foot: Frame
local shownTotal = 0 -- the total's value as last set: a sale counts it down from there
local sellButton: Shop.Button
local allButton: Shop.Button
local allDot: Frame
local sortButtons: { [string]: Shop.Button } = {}
local toast: Frame
local toastWord: TextLabel
local toastFill: UIGradient
local toastAt = -math.huge
local toastShown = false

local cards: { Card } = {}
local fish: { Fish } = {}
local picked: { [string]: boolean } = {}
local sortBy = "Value"
local sureUntil = 0
local selling = false
-- the answer to the ask in flight (Ride "Sold" or "TankDenied"): the coins paid, or false
local answer: (number | boolean)? = nil

local function hex(c: Color3): string
	return string.format("#%02X%02X%02X", math.round(c.R * 255), math.round(c.G * 255), math.round(c.B * 255))
end

local function decode(name: string): { any }
	local ok, rows = pcall(function()
		local value = State.Player:GetAttribute(name)
		return HttpService:JSONDecode(if type(value) == "string" then value else "[]")
	end)
	return if ok and type(rows) == "table" then rows else {}
end

-- What a fish sells for: the server's own function
local function valueOf(id: string, size: string, variant: string): number
	local kind = Config.FishById[id]
	return if kind then Config.sellOf(kind, size, variant) else 0
end

local function rankOf(f: Fish): number
	local kind = Config.FishById[f.Id]
	return TIER_RANK[if kind then kind.Tier else "Common"] or 0
end

-- Everything the player has: the tank's fish, then what they carry; in the order picked, the equipped ones last
local function read(): { Fish }
	local out: { Fish } = {}
	for _, row in decode("TankList") do
		if type(row) == "table" and type(row[1]) == "string" and type(row[2]) == "string" then
			local size, variant = tostring(row[3] or "Normal"), tostring(row[4] or "")
			table.insert(out, {
				Key = row[1],
				Id = row[2],
				Size = size,
				Variant = variant,
				On = row[5] == 1,
				Value = valueOf(row[2], size, variant),
			})
		end
	end
	for i, row in decode("Hands") do
		if type(row) == "table" and type(row[1]) == "string" then
			local size, variant = tostring(row[2] or "Normal"), tostring(row[3] or "")
			table.insert(out, {
				Key = "H" .. i .. "|" .. row[1],
				Id = row[1],
				Size = size,
				Variant = variant,
				On = false,
				Hand = i,
				Value = valueOf(row[1], size, variant),
			})
		end
	end
	table.sort(out, function(a: Fish, b: Fish): boolean
		if a.On ~= b.On then
			return b.On
		end
		if sortBy == "Rarity" then
			local x, y = rankOf(a), rankOf(b)
			if x ~= y then
				return x > y
			end
		end
		if a.Value ~= b.Value then
			return a.Value > b.Value
		end
		return a.Key < b.Key
	end)
	return out
end

local function say(text: string, good: boolean)
	local pair = if good then Shop.Kinds.Cash else Shop.Kinds.Red
	toastFill.Color = Shop.halves(pair[1], pair[2])
	toastWord.Text = text
	toastAt = os.clock()
	if toastShown then
		Anim.punch(toast, 1.08) -- a new line over one still up
	end
end

-- The size and the colour as small words under the name: "BIG  GOLD"
local function tagsOf(f: Fish): string
	local words = {}
	if f.Hand then
		table.insert(words, string.format('<font color="%s">CARRIED</font>', hex(Kit.White)))
	end
	if f.Size ~= "Normal" then -- (the usual size says nothing)
		table.insert(
			words,
			string.format('<font color="%s">%s</font>', hex(SIZE_HUE[f.Size] or Kit.White), string.upper(f.Size))
		)
	end
	if f.Variant == "Rainbow" then
		local letters = {}
		for i = 1, #"RAINBOW" do
			table.insert(
				letters,
				string.format(
					'<font color="%s">%s</font>',
					hex(RAINBOW[(i - 1) % #RAINBOW + 1]),
					string.sub("RAINBOW", i, i)
				)
			)
		end
		table.insert(words, table.concat(letters))
	elseif VARIANT_HUE[f.Variant] then
		table.insert(
			words,
			string.format('<font color="%s">%s</font>', hex(VARIANT_HUE[f.Variant]), string.upper(f.Variant))
		)
	end
	return table.concat(words, "  ")
end

local update: () -> ()

-- A press on a card: picks its fish, or lets it go
local function pressCard(card: Card)
	local f = card.Fish
	if not f or selling then
		return
	end
	if f.On then
		say("UNEQUIP IT FIRST", false)
		return
	end
	picked[f.Key] = if picked[f.Key] then nil else true
	sureUntil = 0
	update()
end

local function newCard(): Card
	local item = Shop.itemCard(list, { Size = UDim2.fromOffset(CARD_W, CARD_H) })
	item.Name.TextTruncate = Enum.TextTruncate.AtEnd
	item.Name.TextSize = 17
	local edge = item.Root:FindFirstChildOfClass("UIStroke") :: UIStroke
	local tags = Shop.text(item.Root, {
		Name = "Tags",
		Position = UDim2.fromOffset(8, 25),
		Size = UDim2.new(1, -16, 0, 15),
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Left,
		RichText = true,
		ZIndex = 4,
	})
	item.Picture.Position = UDim2.fromOffset(8, 40)
	item.Picture.Size = UDim2.new(1, -16, 1, -104)
	local picture = Portrait.new(item.Picture, { Size = UDim2.fromScale(1, 1), ZIndex = 2 })
	-- a picked card's tick, at its top right corner
	local tick: Frame = Kit.new("Frame", {
		Name = "Tick",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -5, 0, 26),
		Size = UDim2.fromOffset(24, 24),
		BackgroundColor3 = Shop.Kinds.Cash[2],
		BorderSizePixel = 0,
		Visible = false,
		ZIndex = 6,
	}, item.Root)
	Kit.corner(tick, 999)
	Kit.stroke(tick, 2.5, Shop.Edge)
	Shop.check(tick, 7)
	-- an equipped fish: dimmed, with the word across it
	local veil: Frame = Kit.new("Frame", {
		Name = "Equipped",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Shop.BodyDeep,
		BackgroundTransparency = 0.4,
		BorderSizePixel = 0,
		Visible = false,
		ZIndex = 7,
	}, item.Root)
	Kit.corner(veil, 5)
	local band: Frame = Kit.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.46),
		Size = UDim2.new(1, -12, 0, 26),
		BackgroundColor3 = Kit.White,
		BorderSizePixel = 0,
		Rotation = -6,
		ZIndex = 8,
	}, veil)
	Kit.corner(band, 4)
	Kit.stroke(band, 2.5, Shop.Edge)
	Kit.new("UIGradient", { Rotation = 90, Color = Shop.halves(Shop.Kinds.Blue[1], Shop.Kinds.Blue[2]) }, band)
	Shop.text(band, { Size = UDim2.fromScale(1, 1), TextSize = 16, Text = "Equipped", ZIndex = 9 })
	local press: TextButton = Kit.new("TextButton", {
		Name = "Press",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Text = "",
		ZIndex = 10,
	}, item.Root)
	local card: Card = {
		Item = item,
		Edge = edge,
		Tags = tags,
		Picture = picture,
		Tick = tick,
		Veil = veil,
		Press = press,
		Fish = nil,
	}
	press.Activated:Connect(function()
		pressCard(card)
	end)
	return card
end

local function fillCard(card: Card, f: Fish, order: number)
	local kind = Config.FishById[f.Id]
	local old = card.Fish
	if not old or old.Id ~= f.Id then
		card.Picture.show(f.Id)
	end
	card.Fish = f
	local tier = if kind then kind.Tier else "Common"
	local entry = Config.Tiers[tier]
	local colour = if entry then entry.Colour else Kit.White
	-- (the Secret's own colour is near black: on the dark card its name is pink)
	if colour.R + colour.G + colour.B < 0.6 then
		colour = Kit.Pink
	end
	card.Item.Root.LayoutOrder = order
	card.Item.Name.Text = if kind then kind.Name else f.Id
	card.Item.Name.TextColor3 = colour
	card.Tags.Text = tagsOf(f)
	card.Item.Rate.Text = Shop.cash(if kind then Config.incomeOf(kind, f.Size, f.Variant) else 0) .. "/s"
	card.Item.Price.Text = Shop.cash(f.Value)
	local on = picked[f.Key] == true
	card.Tick.Visible = on
	card.Veil.Visible = f.On
	card.Edge.Color = if on then LIGHT else Shop.Edge
	card.Edge.Thickness = if on then 4 else 3
	card.Item.Root.Visible = true
end

-- How many fish are picked, what they sell for together, and how many could be picked
local function count(): (number, number, number)
	local n, value, free = 0, 0, 0
	for _, f in fish do
		if not f.On then
			free += 1
			if picked[f.Key] then
				n += 1
				value += f.Value
			end
		end
	end
	return n, value, free
end

function update()
	if not window then
		return
	end
	fish = read()
	-- a pick whose fish is gone (sold, moved, equipped) is dropped
	local there: { [string]: boolean } = {}
	for _, f in fish do
		if not f.On then
			there[f.Key] = true
		end
	end
	for key in picked do
		if not there[key] then
			picked[key] = nil
		end
	end
	for i, f in fish do
		local card = cards[i]
		if not card then
			card = newCard()
			cards[i] = card
		end
		fillCard(card, f, i)
	end
	for i = #fish + 1, #cards do
		cards[i].Item.Root.Visible = false
		cards[i].Fish = nil
	end
	empty.Visible = #fish == 0
	local n, value, free = count()
	if value ~= shownTotal then
		-- while selling, the total counts down as each fish goes; otherwise it is set at once
		if selling then
			Anim.count(total, shownTotal, value, Shop.cash, 0.35)
		else
			Anim.count(total, value, value, Shop.cash, 0)
		end
		shownTotal = value
	end
	local all = free > 0 and n == free
	allButton.set(if all then "Select None" else "Select All", if all then "Cash" else "Off", free > 0)
	allDot.BackgroundColor3 = if all then Shop.Kinds.Cash[2] else Shop.BodyDeep
	local tick = allDot:FindFirstChild("Check") :: Frame?
	if tick then
		tick.Visible = all
	end
	if selling then
		sellButton.set("Selling...", "Off", false)
	elseif os.clock() < sureUntil and n > 0 then
		sellButton.set(string.format("Sure? (%d)", n), "Gold", true)
	else
		sellButton.set(string.format("Sell (%d)", n), if n > 0 then "Cash" else "Off", n > 0)
	end
	for name, b in sortButtons do
		b.set(nil, if name == sortBy then "Cash" else "Off", true)
	end
end

-- A green "+$N" pops over the sell button and drifts up, one per fish sold
local function riseCash(coins: number)
	local group: CanvasGroup = Kit.new("CanvasGroup", {
		Name = "Rise",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(1, -134 + math.random(-24, 24), 1, -FOOT - 4),
		Size = UDim2.fromOffset(220, 44),
		BackgroundTransparency = 1,
		ZIndex = 9, -- (in the body, over the tray: a sibling of the foot would tie with the tray)
	}, foot.Parent)
	Shop.text(group, {
		Size = UDim2.fromScale(1, 1),
		TextSize = 34,
		TextColor3 = Shop.Money,
		Text = "+" .. Shop.cash(coins),
		ZIndex = 10,
	})
	Anim.rise(group, 46, 0.5)
end

-- Sell every picked fish, one ask after another (see the head note)
local function sellPicked()
	local queue: { Fish } = {}
	for _, f in fish do
		if picked[f.Key] and not f.On then
			table.insert(queue, f)
		end
	end
	if #queue == 0 or selling then
		return
	end
	-- the tank's first, then the carried ones from the highest place down
	table.sort(queue, function(a: Fish, b: Fish): boolean
		if (a.Hand == nil) ~= (b.Hand == nil) then
			return a.Hand == nil
		end
		return (a.Hand or 0) > (b.Hand or 0)
	end)
	selling = true
	update()
	task.spawn(function()
		local sold, coins = 0, 0
		for _, f in queue do
			answer = nil
			if f.Hand then
				Net.Action:FireServer("Sell", "Hand", f.Hand, f.Id)
			else
				Net.Action:FireServer("Sell", "Tank", f.Key)
			end
			local asked = os.clock()
			while answer == nil and os.clock() - asked < ASK_WAIT do
				task.wait()
			end
			if type(answer) == "number" then
				sold += 1
				coins += answer
				riseCash(answer)
				Anim.punch(sellButton.Root, 1.06)
			end
			local left = ASK_GAP - (os.clock() - asked)
			if left > 0 then
				task.wait(left)
			end
		end
		selling = false
		table.clear(picked)
		if sold == #queue then
			say(string.format("SOLD %d FISH FOR %s", sold, Shop.cash(coins)), true)
		elseif sold > 0 then
			say(string.format("SOLD %d OF %d FISH FOR %s", sold, #queue, Shop.cash(coins)), true)
		else
			say("COULDN'T SELL", false)
		end
		update()
	end)
end

-- Select All: picks every fish that can be sold, or with all picked lets them go
local function pressAll()
	if selling then
		return
	end
	local n, _, free = count()
	local all = free > 0 and n == free
	table.clear(picked)
	if not all then
		for _, f in fish do
			if not f.On then
				picked[f.Key] = true
			end
		end
	end
	sureUntil = 0
	update()
end

-- Sell (n): asks SURE? once, and sells on the second press
local function pressSell()
	local n = count()
	if selling or n == 0 then
		return
	end
	if os.clock() > sureUntil then
		sureUntil = os.clock() + SURE
		update()
		return
	end
	sureUntil = 0
	sellPicked()
end

local function build()
	local w = Shop.window({
		Name = "SellFish",
		Parent = State.Player:WaitForChild("PlayerGui"),
		Title = "Sell Fish",
		Icon = "Shell",
		Head = "Kelp",
		Width = WIDE,
		Height = HIGH,
		Dim = true,
		OnClose = function()
			Shop.go(nil)
		end,
	})
	local body = w.Body

	-- the left column
	local side: Frame = Kit.new("Frame", {
		Name = "Side",
		Size = UDim2.new(0, SIDE, 1, -(FOOT + 10)),
		BackgroundTransparency = 1,
		ZIndex = 2,
	}, body)
	Shop.text(side, {
		Name = "SortBy",
		Position = UDim2.fromOffset(0, 2),
		Size = UDim2.new(1, 0, 0, 28),
		TextSize = 24,
		Text = "Sort By",
		ZIndex = 3,
	})
	for i, name in { "Value", "Rarity" } do
		local b = Shop.sort(side, {
			Name = name,
			Text = "   " .. name,
			On = name == sortBy,
			Position = UDim2.fromOffset(2, 36 + (i - 1) * 54),
			Size = UDim2.new(1, -4, 0, 46),
			TextSize = 24,
		})
		b.Root.ZIndex = 3
		b.Root.Activated:Connect(function()
			SellFish.sort(name)
		end)
		sortButtons[name] = b
	end
	Kit.new("Frame", {
		Name = "Line",
		Position = UDim2.fromOffset(10, 148),
		Size = UDim2.new(1, -20, 0, 4),
		BackgroundColor3 = Shop.Edge,
		BackgroundTransparency = 0.35,
		BorderSizePixel = 0,
		ZIndex = 3,
	}, side)
	allButton = Shop.button(side, {
		Name = "SelectAll",
		Text = "Select All",
		Kind = "Off",
		Position = UDim2.fromOffset(2, 164),
		Size = UDim2.new(1, -4, 0, 46),
		TextSize = 18,
	})
	allButton.Root.ZIndex = 3
	-- its square box: empty, or green with a tick when every fish is picked
	allDot = Kit.new("Frame", {
		Name = "Dot",
		Size = UDim2.fromOffset(26, 26),
		BackgroundColor3 = Shop.BodyDeep,
		BorderSizePixel = 0,
		LayoutOrder = 1,
		ZIndex = 3,
	}, allButton.Label.Parent)
	Kit.corner(allDot, 4)
	Kit.stroke(allDot, 2.5, Shop.Edge)
	Shop.check(allDot, 4).Visible = false
	allButton.Root.Activated:Connect(pressAll)

	-- the cards, in a dark tray
	local tray = Shop.inset(body, {
		Name = "Tray",
		Position = UDim2.fromOffset(SIDE + 10, 0),
		Size = UDim2.new(1, -(SIDE + 10), 1, -(FOOT + 10)),
		ClipsDescendants = true,
		ZIndex = 2,
	})
	list = Kit.new("ScrollingFrame", {
		Name = "List",
		Position = UDim2.fromOffset(4, 4),
		Size = UDim2.new(1, -8, 1, -8),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		ScrollBarThickness = 8,
		ScrollBarImageColor3 = Shop.Heads.Kelp,
		VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar,
		ZIndex = 3,
	}, tray)
	Kit.new("UIGridLayout", {
		CellSize = UDim2.fromOffset(CARD_W, CARD_H),
		CellPadding = UDim2.fromOffset(GAP, GAP),
		SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = Enum.HorizontalAlignment.Left,
	}, list)
	Kit.new("UIPadding", {
		PaddingLeft = UDim.new(0, 6),
		PaddingTop = UDim.new(0, 6),
		PaddingBottom = UDim.new(0, 8),
	}, list)
	empty = Shop.text(tray, {
		Name = "Empty",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.45),
		Size = UDim2.new(1, -60, 0, 80),
		TextSize = 24,
		TextWrapped = true,
		TextColor3 = Color3.fromRGB(214, 222, 236),
		Text = "No fish to sell",
		Visible = false,
		ZIndex = 4,
	})
	-- what the server answered, over the tray's foot for a moment
	toast = Kit.new("Frame", {
		Name = "Toast",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -10),
		Size = UDim2.new(1, -40, 0, 38),
		BackgroundColor3 = Kit.White,
		BorderSizePixel = 0,
		Visible = false,
		ZIndex = 12,
	}, tray)
	Kit.corner(toast, 5)
	Kit.stroke(toast, 3, Shop.Edge)
	toastFill = Kit.new("UIGradient", { Rotation = 90 }, toast)
	toastWord = Shop.text(toast, { Size = UDim2.fromScale(1, 1), TextSize = 18, ZIndex = 13 })

	-- the foot bar: the Total Value and Sell (n)
	foot = Shop.inset(body, {
		Name = "Foot",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, FOOT),
		ZIndex = 2,
	})
	Shop.text(foot, {
		Name = "TotalWord",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 20, 0.5, 0),
		Size = UDim2.fromOffset(190, 40),
		TextSize = 30,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "Total Value:",
		ZIndex = 3,
	})
	total = Shop.money(foot, {
		Name = "Total",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 214, 0.5, 0),
		Size = UDim2.fromOffset(280, 44),
		TextSize = 34,
		Colour = Kit.White,
		Align = Enum.HorizontalAlignment.Left,
		Text = "$0",
		ZIndex = 3,
	})
	sellButton = Shop.button(foot, {
		Name = "Sell",
		Text = "Sell (0)",
		Kind = "Off",
		TextSize = 30,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -9, 0.5, 0),
		Size = UDim2.fromOffset(250, FOOT - 16),
	})
	sellButton.Root.ZIndex = 3
	sellButton.Root.Activated:Connect(pressSell)

	for _, name in { "TankList", "Hands" } do
		State.Player:GetAttributeChangedSignal(name):Connect(function()
			if w.isOpen() then
				update()
			end
		end)
	end
	Net.Ride.OnClientEvent:Connect(function(kind: string, _what: any, coins: any)
		if not selling then
			return
		end
		if kind == "Sold" and type(coins) == "number" then
			answer = coins
		elseif kind == "TankDenied" then
			answer = false
		end
	end)
	RunService.Heartbeat:Connect(function()
		if not w.isOpen() then
			return
		end
		local now = os.clock()
		local show = now - toastAt < 2.6
		if toastShown ~= show then
			toastShown = show
			Anim.toast(toast, show)
		end
		-- SURE? runs out by itself
		if sureUntil ~= 0 and now > sureUntil then
			sureUntil = 0
			update()
		end
	end)
	window = w
end

-- The cards' order: "Value" or "Rarity" (the Sort By buttons, and Studio's tests)
function SellFish.sort(by: string)
	if by == "Value" or by == "Rarity" then
		sortBy = by
		update()
		if window then
			list.CanvasPosition = Vector2.zero
		end
	end
end

-- A button's own press, for Studio's tests (a script can't click): "Card", its place in the grid | "All" | "Sell"
function SellFish.press(what: string, index: number?)
	if not SellFish.isOpen() then
		return
	end
	if what == "Card" then
		local card = cards[index or 0]
		if card then
			pressCard(card)
		end
	elseif what == "All" then
		pressAll()
	elseif what == "Sell" then
		pressSell()
	end
end

function SellFish.isOpen(): boolean
	return window ~= nil and window.isOpen()
end

-- Open or close the window. (Through Shop.go("Sell"), so another dock window closes.)
function SellFish.open(on: boolean)
	if not window then
		if not on then
			return
		end
		build()
	end
	local w = window :: Shop.Window
	local opening = on and not w.isOpen()
	if opening then
		table.clear(picked)
		sureUntil = 0
		toastAt = -math.huge
		update()
	end
	w.show(on)
	-- the cards pop in one after another as it opens (only then: a pick or a sale doesn't replay it)
	if opening then
		local shown = {}
		for _, card in cards do
			if card.Fish then
				table.insert(shown, card.Item.Root :: GuiObject)
			end
		end
		Anim.stagger(shown)
	end
end

Shop.page("Sell", SellFish.open)

return SellFish
