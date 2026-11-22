--!strict
-- The Shop: what is sold for Robux (UI review 1, the user, 2026-11-22: "The shop UI is a seperate thing"; the user's
-- pick: the reference's layout, offers SOON until their ids exist). The hub's Shop button opens it and closes it
-- (Controllers/StallController); no dim behind it, as the reference's. Laid out as the reference's: the shop kit's
-- window with a sky header and its gloss, one list scrolling down, the sections' titles, and the offers as bright
-- cards on a vivid gradient with a sunburst behind their picture: the wide ones one to a row, the boosts three to a
-- row. The offers are Shared/Products (every Id 0 for now): each card's button reads SOON and asks nothing until its
-- Id is set; then it shows the Robux price and asks Roblox for the purchase prompt. What a purchase gives is the
-- server's (Products' own note): nothing here grants anything.
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Products = require(ReplicatedStorage.Shared.Products)
local State = require(script.Parent.Parent.Lib.State)
local Kit = require(script.Parent.Kit)
local Shop = require(script.Parent.Shop)

local ShopScreen = {}

local WIDE, HIGH = 760, 540
local CARD_HIGH = 128 -- a wide card
local FEATURED_HIGH = 168
local SMALL_HIGH = 196 -- a boost card, three to a row
local GAP = 10

local window: Shop.Window? = nil

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
local function picture(card: GuiObject, offer: Products.Offer, at: UDim2, size: number)
	local image = offer.Picture and (Kit.Textures :: any)[offer.Picture]
	if image then
		Kit.new("ImageLabel", {
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
		Shop.text(card, {
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
end

-- The buy button: SOON until the offer has an id, then its price in Robux and the purchase prompt
local function buy(card: GuiObject, offer: Products.Offer, props: { [string]: any }): Shop.Button
	local onSale = offer.Id > 0
	props.Name = "Buy"
	props.Kind = if onSale then "Robux" else "Off"
	props.Sign = if onSale then "Robux" else nil
	props.Text = if onSale then tostring(offer.Price) else "Soon"
	props.Live = onSale
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
local function smallCard(parent: Instance, offer: Products.Offer, order: number)
	local card = face(parent, offer, UDim2.new(1 / 3, -GAP * 2 / 3, 1, 0), order)
	sunburst(card, Vector2.new(0.5, 0.36), false)
	picture(card, offer, UDim2.fromScale(0.5, 0.36), 92)
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
		PaddingTop = UDim.new(0, 4),
		PaddingBottom = UDim.new(0, 10),
		PaddingLeft = UDim.new(0, 4),
		PaddingRight = UDim.new(0, 8),
	}, list)
	local order = 0
	local function slot(): number
		order += 1
		return order
	end
	for s, section in Products.Sections do
		Shop.text(list, {
			Name = "Title" .. s,
			Size = UDim2.new(1, 0, 0, 34),
			TextSize = 30,
			TextXAlignment = Enum.TextXAlignment.Left,
			Text = section.Title,
			LayoutOrder = slot(),
			ZIndex = 3,
		})
		if section.Wide then
			for _, offer in section.Offers do
				local featured = offer.Key == "Featured"
				wideCard(list, offer, if featured then FEATURED_HIGH else CARD_HIGH, slot(), featured)
			end
		else
			local row: Frame = Kit.new("Frame", {
				Name = "Row" .. s,
				Size = UDim2.new(1, 0, 0, SMALL_HIGH),
				BackgroundTransparency = 1,
				LayoutOrder = slot(),
			}, list)
			Kit.new("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				Padding = UDim.new(0, GAP),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}, row)
			for i, offer in section.Offers do
				smallCard(row, offer, i)
			end
		end
	end
	window = w
end

function ShopScreen.isOpen(): boolean
	return window ~= nil and (window :: Shop.Window).isOpen()
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
		(w.Body:FindFirstChild("List") :: ScrollingFrame).CanvasPosition = Vector2.zero
	end
	w.show(on)
end

Shop.page("Shop", ShopScreen.open)

return ShopScreen
