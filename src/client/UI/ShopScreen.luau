--!strict
-- The Shop: what is sold for Robux (UI review 1, the user, 2026-11-22: "The shop UI is a seperate thing"; the user's
-- pick: the reference's layout, offers SOON until their ids exist). The hub's Shop button opens it and closes it
-- (Controllers/StallController); no dim behind it, as the reference's. Laid out as the reference's: the shop kit's
-- window with a sky header and its gloss, one list scrolling down, the sections' titles, and the offers as bright
-- cards on a vivid gradient with a sunburst behind their picture: the wide ones one to a row, the boosts three to a
-- row. The offers are Shared/Products (every Id 0 for now): each card's button reads SOON and asks nothing until the
-- offer is on sale (Products.onSale); then it shows Roblox's own price and asks Roblox for the purchase prompt, once
-- the player's save is in (their "Saved..." attributes), and the card says how much it gives. What a purchase gives is the
-- server's (PurchaseService): nothing here grants anything.
-- ShopScreen.goTo("Cash") opens it at that section: what the stat rows' plus buttons do (Controllers/StallController).
-- After the fast food menus (the user, 2026-11-23; docs/reference/fast-food-menus.md): a rail of pictures at the left
-- picks the kind first; a pack's pile of pictures grows with its size; each pack says what it does for this player,
-- worked out from their own numbers; the pack that fits them now is tagged, and the Oxygen one leads the Shop; one tag
-- a section says which gives most a Robux. EVERY WORD HERE IS TRUE WHEN SHOWN: no timers, no struck-out prices, no
-- "most bought". In Studio the workspace's "ShopPreview" (set before Play) shows the agreed prices with nothing on
-- sale: the buttons do nothing.
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Products = require(ReplicatedStorage.Shared.Products)
local State = require(script.Parent.Parent.Lib.State)
local Anim = require(script.Parent.Anim)
local Kit = require(script.Parent.Kit)
local Shop = require(script.Parent.Shop)

local ShopScreen = {}

local RAIL = 100 -- the rail's width
local GAP = 10
local WIDE, HIGH = 760 + RAIL + GAP, 540
local CARD_HIGH = 128 -- a wide card
local FEATURED_HIGH = 168
local HERO_PILE = 190 -- Featured's pile's box; the share of it by place (one picture fills less of its box than six)
local HERO_FILL = { 1, 1, 0.84, 0.8, 0.76, 0.72 }
local SMALL_HIGH = 196 -- a boost card, three to a row (two rows and their title fill the list: every size in one look)
local PREVIEW = RunService:IsStudio() and workspace:GetAttribute("ShopPreview") == true

-- The tags: { top, bottom } of the plate. Few, and each a plain fact (refresh, below).
local TAGS = {
	["FOR YOU"] = { Color3.fromRGB(255, 96, 120), Color3.fromRGB(222, 36, 72) },
	["BEST VALUE"] = { Color3.fromRGB(190, 120, 255), Color3.fromRGB(120, 60, 226) },
}

-- A pack's pile: a picture for each place in its ladder, the back ones first: { x, y, size } as shares of its box
local PILES: { { { number } } } = {
	{ { 0, 0, 0.72 } },
	{ { 0.19, -0.1, 0.64 }, { -0.17, 0.1, 0.7 } },
	{ { 0, -0.22, 0.6 }, { 0.27, 0.1, 0.62 }, { -0.25, 0.14, 0.66 } },
	{ { 0, -0.27, 0.56 }, { 0.36, -0.02, 0.58 }, { -0.36, -0.02, 0.58 }, { 0, 0.17, 0.66 } },
	{ { 0.2, -0.27, 0.56 }, { -0.2, -0.27, 0.56 }, { 0.46, 0.06, 0.58 }, { -0.46, 0.06, 0.58 }, { 0, 0.16, 0.7 } },
	{
		{ 0, -0.29, 0.5 },
		{ 0.29, -0.2, 0.54 },
		{ -0.29, -0.2, 0.54 },
		{ 0.54, 0.1, 0.58 },
		{ -0.54, 0.1, 0.58 },
		{ 0, 0.14, 0.74 },
	},
}

local TITLE_HIGH = 34
local PAD_TOP, PAD_FOOT = 4, 10 -- the list's
local SEEK = TweenInfo.new(0.28, Enum.EasingStyle.Quad, Enum.EasingDirection.Out) -- from one section to another
local HOLD = 0.8 -- how long an opening holds its section in view while the window springs

local window: Shop.Window? = nil
local tops: { [string]: number } = {} -- a section's title: how far down the list it starts, in points
local pictures: { [string]: { GuiObject } } = {} -- and its offers' pictures
local prices: { [string]: number } = {} -- an offer's key: its price as Roblox has told it
local asked: { [string]: boolean } = {} -- the offers whose price Roblox has been asked for
local onPrice: { () -> () } = {} -- told when a price comes in

-- One pack's words and tag, drawn again when the player's numbers change
type Pack = { Offer: Products.Offer, Section: Products.Section, Line: TextLabel, Tag: (string?) -> () }
local packs: { Pack } = {}
local heroOffer: Products.Offer? = nil -- what Featured sells now
local showHero: ((offer: Products.Offer, rank: number, helps: boolean) -> ())? = nil
local long = 0 -- the whole list, in points
local seeking = 0 -- which seek is on: a newer one takes over

-- The sunburst: white rays turning slowly about a point, clipped to the card (a CanvasGroup clips turned frames)
local function sunburst(card: GuiObject, at: Vector2, spin: boolean)
	local group: CanvasGroup = Kit.new("CanvasGroup", {
		Name = "Rays",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ZIndex = 1,
	}, card)
	Kit.corner(group, Shop.Round.Card)
	local hub: Frame = Kit.new("Frame", {
		Name = "Hub",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(at.X, at.Y),
		Size = UDim2.fromOffset(1, 1),
		BackgroundTransparency = 1,
	}, group)
	for i = 0, 8 do
		Kit.new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Size = UDim2.fromOffset(1400, 30),
			Rotation = i * 20,
			BackgroundColor3 = Kit.White,
			BackgroundTransparency = 0.84,
			BorderSizePixel = 0,
		}, hub)
	end
	-- a soft light behind the picture
	local glow: Frame = Kit.new("Frame", {
		Name = "Glow",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(at.X, at.Y),
		Size = UDim2.fromOffset(150, 150),
		BackgroundColor3 = Kit.White,
		BackgroundTransparency = 0.6,
		BorderSizePixel = 0,
	}, group)
	Kit.corner(glow, 999)
	Kit.new("UIGradient", {
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.2),
			NumberSequenceKeypoint.new(0.5, 0.6),
			NumberSequenceKeypoint.new(1, 1),
		}),
	}, glow)
	if spin then
		TweenService
			:Create(hub, TweenInfo.new(24, Enum.EasingStyle.Linear, Enum.EasingDirection.In, -1), { Rotation = 360 })
			:Play()
	end
end

-- The offer's picture (a Kit picture) or its big word
local function picture(card: GuiObject, offer: Products.Offer, at: UDim2, size: number): GuiObject?
	local image = offer.Picture and (Kit.Textures :: any)[offer.Picture]
	if image then
		return Kit.new("ImageLabel", {
			Name = "Picture",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = at,
			Size = UDim2.fromOffset(size, size),
			Rotation = -6,
			BackgroundTransparency = 1,
			Image = image,
			ScaleType = Enum.ScaleType.Fit,
			ZIndex = 4,
		}, card)
	elseif offer.Big then
		return Shop.text(card, {
			Name = "Big",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = at,
			Size = UDim2.fromOffset(size, size),
			Rotation = -6,
			TextSize = math.floor(size * 0.6),
			Text = offer.Big,
			ZIndex = 4,
		})
	end
	return nil
end

-- A pack's pile: its picture as many times as its place in the ladder, so a bigger pack is a bigger sight
local function pile(card: GuiObject, offer: Products.Offer, rank: number, at: UDim2, size: number): GuiObject
	local box: Frame = Kit.new("Frame", {
		Name = "Picture",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = at,
		Size = UDim2.fromOffset(size, size),
		BackgroundTransparency = 1,
		ZIndex = 4,
	}, card)
	for i, one in PILES[math.clamp(rank, 1, #PILES)] do
		Kit.new("ImageLabel", {
			Name = "One",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5 + one[1], 0.5 + one[2]),
			Size = UDim2.fromScale(one[3], one[3]),
			Rotation = -6,
			BackgroundTransparency = 1,
			Image = (Kit.Textures :: any)[offer.Picture or ""] or "",
			ScaleType = Enum.ScaleType.Fit,
			ZIndex = i,
		}, box)
	end
	return box
end

-- A tag over a card's top edge, clear of its pile: what it returns is told which one to show, or none
local function tagOn(card: GuiObject, at: number): (string?) -> ()
	local plate: Frame = Kit.new("Frame", {
		Name = "Tag",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(at, 0, 0, 1),
		Size = UDim2.fromOffset(0, 22),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = Kit.White,
		BorderSizePixel = 0,
		Visible = false,
		ZIndex = 6,
	}, card)
	Kit.corner(plate, Shop.Round.Button)
	local fill = Kit.new("UIGradient", { Rotation = 90 }, plate)
	Kit.stroke(plate, 2.5, Shop.Edge).ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	Kit.new("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8) }, plate)
	local words = Shop.text(plate, {
		Name = "Words",
		Size = UDim2.fromScale(0, 1),
		AutomaticSize = Enum.AutomaticSize.X,
		TextSize = 16,
		Text = "",
		ZIndex = 2,
	})
	return function(which: string?)
		local look = which and (TAGS :: any)[which]
		plate.Visible = look ~= nil
		if look then
			words.Text = which :: string
			fill.Color = Shop.halves(look[1], look[2])
		end
	end
end

-- Whether an offer shows its price: it is on sale, or (Studio) the preview shows the price it will have
local function priced(offer: Products.Offer): boolean
	return Products.onSale(offer) or (PREVIEW and offer.Amount ~= nil and offer.Price > 0)
end

-- Ask Roblox, once, the price it will charge this player for an offer, in place of ours
local function askPrice(offer: Products.Offer)
	if asked[offer.Key] or not Products.onSale(offer) then
		return
	end
	asked[offer.Key] = true
	task.spawn(function()
		local ok, info = pcall(function()
			return MarketplaceService:GetProductInfo(offer.Id, Enum.InfoType.Product)
		end)
		local price = if ok and info then info.PriceInRobux else nil
		if type(price) == "number" then
			prices[offer.Key] = price
			for _, told in onPrice do
				told()
			end
		end
	end)
end

-- The buy button: SOON until the offer is on sale, then its price in Robux and the purchase prompt. `get`: what it sells
-- now (Featured's changes with the player; the card's one redraw is the function this gives back).
local function buy(card: GuiObject, get: () -> Products.Offer?, props: { [string]: any }): () -> ()
	props.Name = "Buy"
	props.Kind = "Off"
	props.Sign = "Robux" -- (hidden while it says SOON)
	props.Text = "Soon"
	props.Live = false
	local b = Shop.button(card, props)
	b.Root.ZIndex = 5
	local sign = b.Root:FindFirstChild("SignDisc", true) :: GuiObject?
	local function draw()
		local offer = get()
		if offer and priced(offer) then
			b.set(tostring(prices[offer.Key] or offer.Price), "Robux", true)
			askPrice(offer)
		else
			b.set("Soon", "Off", false)
		end
		if sign then
			sign.Visible = offer ~= nil and priced(offer)
		end
	end
	draw()
	table.insert(onPrice, draw)
	b.Root.Activated:Connect(function()
		local offer = get()
		if not offer or not Products.onSale(offer) then
			return
		end
		-- (nothing is asked for that the server could not give and keep yet: its part of the save is not on)
		local player = State.Player
		local part = Products.Part[offer.Gives or ""]
		if not part or player:GetAttribute("Saved" .. part) ~= true then
			return
		end
		MarketplaceService:PromptProductPurchase(player, offer.Id)
	end)
	return draw
end

----------------------------------------------------------------------------------------------------------------------
-- What a pack does for this player, from their own numbers

local function number(name: string, default: number): number
	local v = State.Player:GetAttribute(name)
	return if type(v) == "number" then v else default
end

-- The seahorse level these coins pay for, one level after another from the player's own
local function seahorse(coins: number): number
	local at = math.max(1, math.floor(number("TrainerLevel", 1)))
	if Config.Train.Free == 1 then
		return at
	end
	while true do
		local one = Config.Train.Levels[at + 1]
		if not one or coins < one.Price then
			return at
		end
		coins -= one.Price
		at += 1
	end
end

-- "You: 100 → 50.1K"; a pack too small to show in those says how little it adds
local function growth(have: number, amount: number, short: (number) -> string): string
	if amount < have * 0.01 or short(have) == short(have + amount) then
		local share = math.floor(amount / have * 1000) / 10
		return if share < 0.1 then "Adds under 0.1%" else `Adds {share}%`
	end
	return `You: {short(have)} → {short(have + amount)}`
end

-- One true line: the max Oxygen they would have, or the seahorse it pays for (their cash, when it pays for no more)
local function does(offer: Products.Offer): string
	local amount = offer.Amount or 0
	if offer.Gives == "Oxygen" then
		return growth(number("MaxOxygen", Config.Oxygen.StartMax), amount, Kit.short)
	elseif offer.Gives == "Coins" then
		local coins = number("Coins", 0)
		local level = seahorse(coins + amount)
		if level > seahorse(coins) then
			return `Pays for {Config.Train.Levels[level].Name} Seahorse`
		end
		return growth(coins, amount, Shop.cash)
	end
	return offer.Line or ""
end

-- The pack that fits them now, its place, and whether it helps: the smallest that at least doubles their Oxygen, or that
-- pays for a seahorse level their own cash doesn't; past all of those, the biggest, which is not called FOR YOU
local function fits(section: Products.Section): (Products.Offer?, number, boolean)
	for i, offer in section.Offers do
		local amount = offer.Amount or 0
		if offer.Gives == "Oxygen" then
			if amount >= number("MaxOxygen", Config.Oxygen.StartMax) then
				return offer, i, true
			end
		elseif offer.Gives == "Coins" then
			local coins = number("Coins", 0)
			if seahorse(coins + amount) > seahorse(coins) then
				return offer, i, true
			end
		end
	end
	return section.Offers[#section.Offers], #section.Offers, false
end

-- The pack that gives most for each Robux, by the prices the buttons show
local function bestValue(section: Products.Section): Products.Offer?
	local best: Products.Offer? = nil
	local most = 0
	for _, offer in section.Offers do
		local price = prices[offer.Key] or offer.Price
		local amount = offer.Amount
		if not amount or price <= 0 or not priced(offer) then
			return nil
		end
		if amount / price > most then
			best, most = offer, amount / price
		end
	end
	return best
end

local function sectionOf(title: string?): Products.Section?
	for _, section in Products.Sections do
		if section.Title == title then
			return section
		end
	end
	return nil
end

-- Every pack's line and tag, and Featured's pack, as the player's numbers are now
local function refresh()
	for _, pack in packs do
		pack.Line.Text = does(pack.Offer)
		local mine, _, helps = fits(pack.Section)
		local which: string? = nil
		if priced(pack.Offer) then
			which = if helps and mine == pack.Offer
				then "FOR YOU"
				elseif bestValue(pack.Section) == pack.Offer then "BEST VALUE"
				else nil
		end
		pack.Tag(which)
	end
	for _, section in Products.Sections do
		local from = sectionOf(section.Pick)
		local offer, rank, helps = nil :: Products.Offer?, 1, false
		if from then
			offer, rank, helps = fits(from)
		end
		if offer and showHero then
			showHero(offer, rank, helps)
		end
	end
end

local function face(parent: Instance, offer: Products.Offer, size: UDim2, order: number): Frame
	local look = (Products.Looks :: any)[offer.Look] or Products.Looks.Sky
	local card: Frame = Kit.new("Frame", {
		Name = offer.Key,
		Size = size,
		BackgroundColor3 = Kit.White,
		BorderSizePixel = 0,
		LayoutOrder = order,
		ZIndex = 1,
	}, parent)
	Kit.corner(card, Shop.Round.Card)
	Kit.new("UIGradient", {
		Rotation = 90,
		Color = ColorSequence.new(look[1], look[2]),
	}, card)
	Kit.stroke(card, 3, Shop.Edge).ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	local studs = Shop.pattern(card, "Card")
	studs.ZIndex = 2
	return card
end

-- A wide card: the picture on its sunburst at the left, the name and its line, the button at the right
local function wideCard(parent: Instance, offer: Products.Offer, high: number, order: number)
	local card = face(parent, offer, UDim2.new(1, 0, 0, high), order)
	sunburst(card, Vector2.new(0.13, 0.5), false)
	picture(card, offer, UDim2.fromScale(0.13, 0.5), high - 24)
	Shop.text(card, {
		Name = "Name",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.fromScale(0.26, if offer.Line then 0.38 else 0.5),
		Size = UDim2.new(0.5, 0, 0, 44),
		TextSize = 36,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = offer.Name,
		ZIndex = 4,
	})
	if offer.Line then
		Shop.text(card, {
			Name = "Line",
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.fromScale(0.26, 0.68),
			Size = UDim2.new(0.5, 0, 0, 24),
			TextSize = 20,
			TextXAlignment = Enum.TextXAlignment.Left,
			Text = offer.Line,
			ZIndex = 4,
		})
	end
	buy(card, function()
		return offer
	end, {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -14, 0.5, 0),
		Size = UDim2.fromOffset(170, 58),
		TextSize = 28,
	})
end

-- What a boost card is called: what it gives ("+$25M", "+500K"), or its name while that is not set
local function called(offer: Products.Offer): string
	local amount = offer.Amount
	if not amount then
		return offer.Name
	end
	return (if offer.Gives == "Coins" then "+$" else "+") .. Kit.short(amount)
end

-- Featured: the one pack that fits the player now, the Shop's biggest card
local function heroCard(parent: Instance, section: Products.Section, order: number): GuiObject
	local card = face(
		parent,
		{ Key = section.Title, Name = section.Title, Kind = "Product", Id = 0, Price = 0, Look = "Grape" },
		UDim2.new(1, 0, 0, FEATURED_HIGH),
		order
	)
	sunburst(card, Vector2.new(0.16, 0.5), true)
	local box: Frame = Kit.new("Frame", {
		Name = "Pile",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.165, 0.52),
		Size = UDim2.fromOffset(HERO_PILE, HERO_PILE),
		BackgroundTransparency = 1,
		ZIndex = 4,
	}, card)
	local tag = tagOn(card, 0.41)
	local function words(name: string, y: number, size: number): TextLabel
		return Shop.text(card, {
			Name = name,
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.fromScale(0.325, y),
			Size = UDim2.new(0.43, 0, 0, size + 8),
			TextSize = size,
			TextXAlignment = Enum.TextXAlignment.Left,
			Text = "",
			ZIndex = 4,
		})
	end
	local name = words("Name", 0.24, 22)
	local amount = words("Amount", 0.5, 42)
	local line = words("Line", 0.78, 24)
	local draw = buy(card, function()
		return heroOffer
	end, {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -14, 0.5, 0),
		Size = UDim2.fromOffset(160, 66),
		TextSize = 32,
		Shine = true, -- (one to a window)
	})
	showHero = function(offer: Products.Offer, rank: number, helps: boolean)
		line.Text = does(offer)
		tag(if helps and priced(offer) then "FOR YOU" else nil)
		if heroOffer == offer then
			return
		end
		heroOffer = offer
		local old = box:FindFirstChild("Picture")
		if old then
			old:Destroy()
		end
		pile(box, offer, rank, UDim2.fromScale(0.5, 0.5), HERO_PILE * HERO_FILL[math.clamp(rank, 1, #HERO_FILL)])
		name.Text = offer.Name
		amount.Text = called(offer) .. (if offer.Gives == "Oxygen" then " Oxygen" else "")
		draw()
	end
	return box
end

-- A boost card, three to a row: its pile on a sunburst at the top, how much, what it does, the button along the foot
local function smallCard(parent: Instance, section: Products.Section, offer: Products.Offer, rank: number): GuiObject
	local card = face(parent, offer, UDim2.new(1 / 3, -GAP * 2 / 3, 1, 0), rank)
	sunburst(card, Vector2.new(0.5, 0.28), false)
	local drawn = pile(card, offer, rank, UDim2.new(0.5, 0, 0, 52), 70)
	Shop.text(card, {
		Name = "Name",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -78),
		Size = UDim2.new(1, -12, 0, 32),
		TextSize = 29,
		Text = called(offer),
		ZIndex = 5,
	})
	local line = Shop.text(card, {
		Name = "Line",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -56),
		Size = UDim2.new(1, -8, 0, 22),
		TextSize = 18,
		Text = "",
		ZIndex = 5,
	})
	buy(card, function()
		return offer
	end, {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -7),
		Size = UDim2.new(1, -16, 0, 44),
		TextSize = 25,
	})
	table.insert(packs, { Offer = offer, Section = section, Line = line, Tag = tagOn(card, 0.5) })
	return drawn
end

-- Where the list has to be for a section's title to be at its top, or as near as its foot lets. (A list's own place
-- is in pixels, not points, so it is taken off the list as it is drawn now.)
local function placeOf(list: ScrollingFrame, title: string): number
	local whole = list.AbsoluteCanvasSize.Y
	return math.clamp((tops[title] - PAD_TOP) / long * whole, 0, math.max(0, whole - list.AbsoluteWindowSize.Y))
end

-- The rail: a picture and a word for each section, the one in view lit. Pressing one runs the list there.
local function rail(body: GuiObject, list: ScrollingFrame)
	local holder: Frame = Kit.new("Frame", {
		Name = "Rail",
		Position = UDim2.fromOffset(4, PAD_TOP),
		Size = UDim2.new(0, RAIL - 4, 1, -PAD_TOP * 2),
		BackgroundTransparency = 1,
		ZIndex = 2,
	}, body)
	Kit.new("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }, holder)
	local count = #Products.Sections
	local lit: { [string]: (boolean) -> () } = {}
	for i, section in Products.Sections do
		local b: TextButton = Kit.new("TextButton", {
			Name = section.Title,
			Size = UDim2.new(1, 0, 1 / count, -8 * (count - 1) / count),
			BackgroundColor3 = Kit.White,
			BorderSizePixel = 0,
			AutoButtonColor = false,
			Text = "",
			LayoutOrder = i,
			ZIndex = 2,
		}, holder)
		Kit.corner(b, Shop.Round.Card)
		local fill = Kit.new("UIGradient", { Rotation = 90 }, b)
		local edge = Kit.stroke(b, 3, Shop.Edge)
		edge.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		Shop.pattern(b, "Card")
		local image = (Kit.Textures :: any)[section.Rail]
		if image then
			Kit.new("ImageLabel", {
				Name = "Picture",
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.38),
				Size = UDim2.fromOffset(46, 46),
				BackgroundTransparency = 1,
				Image = image,
				ScaleType = Enum.ScaleType.Fit,
				ZIndex = 4,
			}, b)
		else
			Shop.text(b, {
				Name = "Picture",
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.38),
				Size = UDim2.fromOffset(60, 40),
				TextSize = if section.Pick then 46 else 34,
				TextColor3 = if section.Pick and section.Colour then section.Colour else Kit.White,
				Text = section.Rail,
				ZIndex = 4,
			})
		end
		Shop.text(b, {
			Name = "Words",
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -5),
			Size = UDim2.new(1, -4, 0, 20),
			TextSize = 18,
			Text = section.Title,
			ZIndex = 4,
		})
		Anim.button(b, { Press = 0.92, Grow = 1.03 })
		b.Activated:Connect(function()
			ShopScreen.goTo(section.Title)
		end)
		lit[section.Title] = function(on: boolean)
			fill.Color = if on
				then Shop.halves(Shop.Kinds.Blue[1], Shop.Kinds.Blue[2])
				else ColorSequence.new(Kit.lighter(Shop.Card, 0.06), Kit.darker(Shop.Card, 0.16))
		end
	end
	-- (the section in view: the last whose title has reached the top)
	local function look()
		local now = Products.Sections[1].Title
		local at = list.CanvasPosition.Y
		for _, section in Products.Sections do
			if placeOf(list, section.Title) <= at + 8 then
				now = section.Title
			end
		end
		for title, set in lit do
			set(title == now)
		end
	end
	list:GetPropertyChangedSignal("CanvasPosition"):Connect(look)
	list:GetPropertyChangedSignal("AbsoluteCanvasSize"):Connect(look)
	look()
end

local function build()
	local w = Shop.window({
		Name = "ShopScreen",
		Parent = State.Player:WaitForChild("PlayerGui"),
		Title = "Shop",
		Head = "Sea",
		Centre = true,
		Gloss = true,
		Width = WIDE,
		Height = HIGH,
		OnClose = function()
			Shop.go(nil)
		end,
	})
	local list: ScrollingFrame = Kit.new("ScrollingFrame", {
		Name = "List",
		Position = UDim2.fromOffset(RAIL + GAP, 0),
		Size = UDim2.new(1, -(RAIL + GAP), 1, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		ScrollBarThickness = 8,
		ScrollBarImageColor3 = Kit.White,
		ScrollBarImageTransparency = 0.3,
		VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar,
		ZIndex = 2,
	}, w.Body)
	Kit.new("UIListLayout", { Padding = UDim.new(0, GAP), SortOrder = Enum.SortOrder.LayoutOrder }, list)
	Kit.new("UIPadding", {
		PaddingTop = UDim.new(0, PAD_TOP),
		PaddingBottom = UDim.new(0, PAD_FOOT),
		PaddingLeft = UDim.new(0, 4),
		PaddingRight = UDim.new(0, 8),
	}, list)
	local order = 0
	local down = PAD_TOP
	-- the next thing down the list, so high
	local function slot(high: number): number
		order += 1
		down += high + GAP
		return order
	end
	for s, section in Products.Sections do
		tops[section.Title] = down
		local drawn: { GuiObject } = {}
		pictures[section.Title] = drawn
		Shop.text(list, {
			Name = "Title" .. s,
			Size = UDim2.new(1, 0, 0, TITLE_HIGH),
			TextSize = 30,
			TextColor3 = section.Colour or Kit.White,
			Text = section.Title,
			LayoutOrder = slot(TITLE_HIGH),
			ZIndex = 3,
		})
		if section.Pick then
			table.insert(drawn, heroCard(list, section, slot(FEATURED_HIGH)))
		end
		if section.Wide then
			for _, offer in section.Offers do
				wideCard(list, offer, CARD_HIGH, slot(CARD_HIGH))
			end
		else
			local row: Frame
			for i, offer in section.Offers do
				if i % 3 == 1 then
					row = Kit.new("Frame", {
						Name = `Row{s}_{i}`,
						Size = UDim2.new(1, 0, 0, SMALL_HIGH),
						BackgroundTransparency = 1,
						LayoutOrder = slot(SMALL_HIGH),
					}, list)
					Kit.new("UIListLayout", {
						FillDirection = Enum.FillDirection.Horizontal,
						Padding = UDim.new(0, GAP),
						SortOrder = Enum.SortOrder.LayoutOrder,
					}, row)
				end
				table.insert(drawn, smallCard(row, section, offer, i))
			end
		end
	end
	long = down - GAP + PAD_FOOT
	window = w
	rail(w.Body, list)
	refresh()
	-- (the lines follow the player's numbers while the Shop is up; opening it draws them again)
	local function changed()
		if w.isOpen() then
			refresh()
		end
	end
	for _, name in { "MaxOxygen", "Coins", "TrainerLevel" } do
		State.Player:GetAttributeChangedSignal(name):Connect(changed)
	end
	table.insert(onPrice, changed)
end

-- Open or close it. (Through Shop.go("Shop"), so another dock window closes.)
function ShopScreen.open(on: boolean)
	if not window then
		if not on then
			return
		end
		build()
	end
	local w = window :: Shop.Window
	if on and not w.isOpen() then
		seeking += 1
		refresh();
		(w.Body:FindFirstChild("List") :: ScrollingFrame).CanvasPosition = Vector2.zero
	end
	w.show(on)
end

-- Open the Shop at a section ("Cash"), or run down to it when it is open already; its pictures pop in turn
function ShopScreen.goTo(title: string)
	local was = window ~= nil and (window :: Shop.Window).isOpen()
	Shop.go("Shop")
	local w = window
	if not w or not tops[title] then
		return
	end
	seeking += 1
	local mine = seeking
	local list = w.Body:FindFirstChild("List") :: ScrollingFrame
	if was then
		TweenService:Create(list, SEEK, { CanvasPosition = Vector2.new(0, placeOf(list, title)) }):Play()
	else
		-- held there while the window springs: its pixels change each frame; a wheel, a press or a finger on it lets go
		local start = os.clock()
		local links: { RBXScriptConnection } = {}
		local function drop()
			for _, link in links do
				link:Disconnect()
			end
		end
		local function hand(input: InputObject)
			local t = input.UserInputType
			if t ~= Enum.UserInputType.MouseMovement then
				drop()
			end
		end
		table.insert(links, list.InputChanged:Connect(hand))
		table.insert(links, list.InputBegan:Connect(hand))
		table.insert(
			links,
			RunService.RenderStepped:Connect(function()
				if seeking ~= mine or not w.isOpen() or os.clock() - start > HOLD then
					drop()
				else
					list.CanvasPosition = Vector2.new(0, placeOf(list, title))
				end
			end)
		)
	end
	for i, one in pictures[title] do
		task.delay(0.2 + i * 0.07, function()
			if seeking == mine and w.isOpen() then
				Anim.punch(one, 1.3)
			end
		end)
	end
end

Shop.page("Shop", ShopScreen.open)

return ShopScreen
