--!strict
-- The Shop: what is sold for Robux (UI review 1, the user, 2026-11-22: "The shop UI is a seperate thing"; the user's
-- pick: the reference's layout, offers SOON until their ids exist). The hub's Shop button opens it and closes it
-- (Controllers/StallController); no dim behind it, as the reference's. Laid out as the reference's: the shop kit's
-- window with a sky header and its gloss, one list scrolling down, the sections' titles, and the offers as bright
-- cards on a vivid gradient with a sunburst behind their picture: the wide ones one to a row, the boosts three to a
-- row. The offers are Shared/Products (every Id 0 for now): each card's button reads SOON and asks nothing until its
-- Id is set; then it shows the Robux price and asks Roblox for the purchase prompt. What a purchase gives is the
-- server's (Products' own note): nothing here grants anything.
-- ShopScreen.goTo("Cash") opens it at that section: what the stat rows' plus buttons do (Controllers/StallController).
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Products = require(ReplicatedStorage.Shared.Products)
local State = require(script.Parent.Parent.Lib.State)
local Anim = require(script.Parent.Anim)
local Kit = require(script.Parent.Kit)
local Shop = require(script.Parent.Shop)

local ShopScreen = {}

local WIDE, HIGH = 760, 540
local CARD_HIGH = 128 -- a wide card
local FEATURED_HIGH = 168
local SMALL_HIGH = 196 -- a boost card, three to a row
local GAP = 10

local TITLE_HIGH = 34
local PAD_TOP, PAD_FOOT = 4, 10 -- the list's
local SEEK = TweenInfo.new(0.28, Enum.EasingStyle.Quad, Enum.EasingDirection.Out) -- from one section to another
local HOLD = 0.8 -- how long an opening holds its section in view while the window springs

local window: Shop.Window? = nil
local tops: { [string]: number } = {} -- a section's title: how far down the list it starts, in points
local pictures: { [string]: { GuiObject } } = {} -- and its offers' pictures
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

-- The buy button: SOON until the offer has an id, then its price in Robux and the purchase prompt
local function buy(card: GuiObject, offer: Products.Offer, props: { [string]: any }): Shop.Button
	local onSale = offer.Id > 0
	props.Name = "Buy"
	props.Kind = if onSale then "Robux" else "Off"
	props.Sign = if onSale then "Robux" else nil
	props.Text = if onSale then tostring(offer.Price) else "Soon"
	props.Live = onSale
	props.Shine = onSale and offer.Key == "Featured" -- (one to a window)
	local b = Shop.button(card, props)
	b.Root.ZIndex = 5
	b.Root.Activated:Connect(function()
		if offer.Id <= 0 then
			return
		end
		if offer.Kind == "Pass" then
			MarketplaceService:PromptGamePassPurchase(State.Player, offer.Id)
		else
			MarketplaceService:PromptProductPurchase(State.Player, offer.Id)
		end
	end)
	return b
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

-- A wide card: the picture on its sunburst at the left, the name, the button at the right
local function wideCard(parent: Instance, offer: Products.Offer, high: number, order: number, spin: boolean)
	local card = face(parent, offer, UDim2.new(1, 0, 0, high), order)
	sunburst(card, Vector2.new(0.13, 0.5), spin)
	picture(card, offer, UDim2.fromScale(0.13, 0.5), high - 24)
	Shop.text(card, {
		Name = "Name",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.fromScale(0.26, 0.5),
		Size = UDim2.new(0.5, 0, 0, 44),
		TextSize = if high > CARD_HIGH then 44 else 36,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = offer.Name,
		ZIndex = 4,
	})
	buy(card, offer, {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -14, 0.5, 0),
		Size = UDim2.fromOffset(170, 58),
		TextSize = 28,
	})
end

-- A boost card, three to a row: the picture on its sunburst at the top, the name, the button along the foot
local function smallCard(parent: Instance, offer: Products.Offer, order: number): GuiObject?
	local card = face(parent, offer, UDim2.new(1 / 3, -GAP * 2 / 3, 1, 0), order)
	sunburst(card, Vector2.new(0.5, 0.36), false)
	local drawn = picture(card, offer, UDim2.fromScale(0.5, 0.36), 92)
	Shop.text(card, {
		Name = "Name",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -62),
		Size = UDim2.new(1, -12, 0, 28),
		TextSize = 25,
		Text = offer.Name,
		ZIndex = 4,
	})
	buy(card, offer, {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -8),
		Size = UDim2.new(1, -16, 0, 46),
		TextSize = 24,
	})
	return drawn
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
		Size = UDim2.fromScale(1, 1),
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
		if section.Wide then
			for _, offer in section.Offers do
				local featured = offer.Key == "Featured"
				local high = if featured then FEATURED_HIGH else CARD_HIGH
				wideCard(list, offer, high, slot(high), featured)
			end
		else
			local row: Frame = Kit.new("Frame", {
				Name = "Row" .. s,
				Size = UDim2.new(1, 0, 0, SMALL_HIGH),
				BackgroundTransparency = 1,
				LayoutOrder = slot(SMALL_HIGH),
			}, list)
			Kit.new("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				Padding = UDim.new(0, GAP),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}, row)
			for i, offer in section.Offers do
				local one = smallCard(row, offer, i)
				if one then
					table.insert(drawn, one)
				end
			end
		end
	end
	long = down - GAP + PAD_FOOT
	window = w
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
		(w.Body:FindFirstChild("List") :: ScrollingFrame).CanvasPosition = Vector2.zero
	end
	w.show(on)
end

-- Where the list has to be for a section's title to be at its top, or as near as its foot lets. (A list's own place
-- is in pixels, not points, so it is taken off the list as it is drawn now.)
local function placeOf(list: ScrollingFrame, title: string): number
	local whole = list.AbsoluteCanvasSize.Y
	return math.clamp((tops[title] - PAD_TOP) / long * whole, 0, math.max(0, whole - list.AbsoluteWindowSize.Y))
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
