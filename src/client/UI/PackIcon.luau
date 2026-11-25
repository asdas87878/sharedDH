--!strict
-- The Great White pack's icon at the screen's top right (the user, 2026-11-25: "put an icon in the top right ... that
-- links to this starter pack"; Config.Packs.Icon): at the dock, until the pack is bought, not while a window is open. A
-- press opens the Shop at the pack (UI/ShopScreen, its first card). Under the boost's chip (BoostController); left of
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

local SIZE = 96
local TOP = 58 -- under the boost's chip
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
		root.Position = UDim2.new(1, if list then -LIST else -10, 0, TOP)
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
	Kit.corner(made, 12)
	local look = (Products.Looks :: any)[pack.Look] or Products.Looks.Gold
	Kit.gradient(made, look[1], look[2])
	Kit.stroke(made, 3, Shop.Edge).ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	Shop.pattern(made, "Card")
	shown = Portrait.new(made, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.42),
		Size = UDim2.fromOffset(SIZE + 14, SIZE - 22),
		ZIndex = 3,
		Aspect = (SIZE + 14) / (SIZE - 22),
	})
	Shop.text(made, {
		Name = "Words",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -2),
		Size = UDim2.new(1, 20, 0, 34),
		TextSize = 17,
		TextWrapped = true,
		LineHeight = 0.85,
		Text = string.upper(pack.Name),
		ZIndex = 5,
	})
	price = Shop.text(made, {
		Name = "Price",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 1, 4),
		Size = UDim2.new(1, 20, 0, 22),
		TextSize = 18,
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
		price.Text = if costs then `ONLY {costs}` else ""
	end
end

return PackIcon
