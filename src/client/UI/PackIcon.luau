--!strict
-- The Great White pack's icon at the screen's top right (the user, 2026-11-25: "put an icon in the top right ... that
-- links to this starter pack"; Config.Packs.Icon): at the dock, until the pack is bought, not while a window is open. A
-- press opens the Shop at the pack (UI/ShopScreen, its first card). Round, as the
-- reference's (its layout, the user: "the icon in the corner should be a circle too"). Under the boost's chip (BoostController); left of
-- Roblox's player list while that can be up. Every word is true when shown: no timer, and the price only once on sale.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Products = require(ReplicatedStorage.Shared.Products)
local Anim = require(script.Parent.Anim)
local HubButtons = require(script.Parent.HubButtons)
local Kit = require(script.Parent.Kit)
local Portrait = require(script.Parent.Portrait)
local Shop = require(script.Parent.Shop)
local ShopScreen = require(script.Parent.ShopScreen)

local PackIcon = {}

local SIZE = 108
local TOP = 72 -- under the boost's chip, its ribbon clear of it
local SIDE = 34 -- from the screen's right edge: its words are wider than it is
local LIST = 200 -- how wide Roblox's player list is, about

local offer: Products.Offer? = nil
local where = ""
local root: TextButton? = nil
local price: TextLabel
local shown: any
local drawn = false
local touch = false
local next = 0

local function stand()
	if root then
		local list = not touch and #Players:GetPlayers() > 1
		root.Position = UDim2.new(1, if list then -LIST - SIDE else -SIDE, 0, TOP)
	end
end

function PackIcon.build(parent: Instance)
	for _, section in Products.Sections do
		for _, one in section.Offers do
			if one.Fish and one.Pack and not one.Hidden then
				offer, where = one, section.Title
				break
			end
		end
	end
	local pack = offer
	if not pack then
		return
	end
	local made: TextButton = Kit.new("TextButton", {
		Name = "PackIcon",
		AnchorPoint = Vector2.new(1, 0),
		Size = UDim2.fromOffset(SIZE, SIZE),
		BackgroundColor3 = Kit.White,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Text = "",
		Visible = false,
	}, parent)
	root = made
	made.BackgroundTransparency = 1 -- (its face is a frame over the glow: a lower ZIndex still draws over its own parent)
	local plate: Frame = Kit.new("Frame", {
		Name = "Face",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Kit.White,
		BorderSizePixel = 0,
		ZIndex = 2,
	}, made)
	Kit.corner(plate, 999)
	Kit.gradient(plate, Color3.fromRGB(150, 236, 255), Color3.fromRGB(24, 112, 226))
	Kit.stroke(plate, 4, Kit.White).ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	-- a soft gold light behind it, and the dark edge outside the white ring
	for i, one in { { 34, 0.8 }, { 20, 0.65 } } do
		local glow: Frame = Kit.new("Frame", {
			Name = "Glow" .. i,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.new(1, one[1], 1, one[1]),
			BackgroundColor3 = Color3.fromRGB(255, 206, 60),
			BackgroundTransparency = one[2],
			BorderSizePixel = 0,
			ZIndex = 1,
		}, made)
		Kit.corner(glow, 999)
	end
	local edge: Frame = Kit.new("Frame", {
		Name = "Edge",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(1, 8, 1, 8),
		BackgroundTransparency = 1,
		ZIndex = 2,
	}, made)
	Kit.corner(edge, 999)
	Kit.stroke(edge, 3, Shop.Edge)
	local studs = Shop.pattern(plate, "Card")
	Kit.corner(studs, 999)
	shown = Portrait.new(made, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(SIZE + 18, SIZE - 14),
		Whole = true,
		ZIndex = 3,
		Aspect = (SIZE + 18) / (SIZE - 14),
	})
	for _, one in { { "Cash", 0.08, 0.84 }, { "Oxygen", 0.92, 0.84 } } :: { { any } } do
		Kit.new("ImageLabel", {
			Name = one[1],
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(one[2], one[3]),
			Size = UDim2.fromOffset(38, 38),
			Rotation = -8,
			BackgroundTransparency = 1,
			Image = (Kit.Textures :: any)[one[1]],
			ScaleType = Enum.ScaleType.Fit,
			ZIndex = 5,
		}, made)
	end
	local ribbon: Frame = Kit.new("Frame", {
		Name = "Ribbon",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0),
		Size = UDim2.fromOffset(118, 24),
		Rotation = -5,
		BackgroundColor3 = Kit.White,
		BorderSizePixel = 0,
		ZIndex = 6,
	}, made)
	Kit.corner(ribbon, 10)
	Kit.gradient(ribbon, Shop.Kinds.Robux[1], Shop.Kinds.Robux[2])
	Kit.stroke(ribbon, 2.5, Shop.Edge)
	Shop.text(ribbon, { Size = UDim2.fromScale(1, 1), TextSize = 15, Text = "STARTER PACK!", ZIndex = 7 })
	Shop.text(made, {
		Name = "Words",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 1, 8),
		Size = UDim2.fromOffset(180, 24),
		TextSize = 21,
		Text = string.upper((string.gsub(pack.Name, " Pack$", ""))) .. "!",
		ZIndex = 5,
	})
	price = Shop.text(made, {
		Name = "Price",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 1, 33),
		Size = UDim2.fromOffset(180, 22),
		TextSize = 19,
		TextColor3 = Color3.fromRGB(255, 222, 72),
		Text = "",
		ZIndex = 5,
	})
	Anim.button(made, { Press = 0.92, Grow = 1.06 })
	made.Activated:Connect(function()
		HubButtons.shopSeen()
		ShopScreen.goTo(where)
	end)
	stand()
	Players.PlayerAdded:Connect(stand)
	Players.PlayerRemoving:Connect(function()
		task.defer(stand)
	end)
end

function PackIcon.place(onTouch: boolean)
	touch = onTouch
	stand()
end

-- docked: at the dock, the only place it shows
function PackIcon.update(docked: boolean)
	local made, pack = root, offer
	if not made or not pack then
		return
	end
	local on = docked
		and Config.Packs.Icon ~= 0
		and Anim.Windows == 0
		and Shop.Page == nil
		and not ShopScreen.owned(pack)
	if on ~= made.Visible then
		made.Visible = on
	end
	if on and os.clock() > next then
		next = os.clock() + 2
		-- (the fish's model may not be in yet: asked again until it is)
		drawn = drawn or shown.show(pack.Fish) ~= false
		local costs = ShopScreen.priceOf(pack)
		price.Text = if costs then `ONLY {utf8.char(0xE002)}{costs}` else ""
	end
end

return PackIcon
