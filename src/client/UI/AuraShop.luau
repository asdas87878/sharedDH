--!strict
-- The Auras window, in the shop kit (UI/Shop; NULLROOM task s1, after Hugo's auras reference; task b2, Hugo
-- 2026-11-22: "integrate aura buying ui for the shop"). It opens when the player stands on the Auras stall's floor
-- ring and closes when they walk off (UI review 1, the user 2026-11-22: "they should pop up when you stand on the
-- stands corresponding to them in game"; Controllers/StallController), with the dim behind it.
-- What it shows: the twelve auras (Shared/Auras.Tiers) as tall cards in a sideways row, each tinted in its aura's own
-- colour: its name, "Lvl n", its icon in the cream well (the fish rider in a flame that grows with the tier: Hugo,
-- 2026-11-24, "fish rider"; art/ui/auras, tools/ui/aura_icons/build.py; a glow of its colours where the pictures aren't
-- there), "x2 Oxygen" with the multiplier in green, and
-- one button: the cash price. (The Robux button is built but kept hidden: no product ids exist and none are made up,
-- and two dead SOON buttons on a card read as a mistake.) The player's own "Aura" attribute shows as EQUIPPED, with
-- the light border; the ones under it as OWNED.
-- BUYING IS NOT ON YET: auras have no prices and the server has no aura purchase (Shared/Auras: "buying waits for the
-- economy's prices"), so every cash button says SOON and asks nothing. The hook-up is ready on this side: once a tier
-- in Shared/Auras carries a `Price` (coins), its card shows it (green when the player's "Coins" cover it and it is the
-- next aura, grey otherwise) and a press asks the server Action "AuraBuy", tier. The server must then check the
-- price and the order itself, take the coins and set the player's "Aura" attribute; nothing here is trusted.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Auras = require(ReplicatedStorage.Shared.Auras)
local Net = require(ReplicatedStorage.Shared.Net)
local State = require(script.Parent.Parent.Lib.State)
local Kit = require(script.Parent.Kit)
local Shop = require(script.Parent.Shop)

local AuraShop = {}

-- (the window is the Sell Fish window's size, so the two stalls' windows match)
local WIDE, HIGH = 860, 540
local CARD_W, CARD_H = 196, 404

-- The icons' picture (4 across, 3 down, 256 pixels each, by tier). Uploaded id: empty until the user says yes to the
-- upload. Studio reads the local copy (tools/ui/aura_icons/build.py --studio); a live game before that, or a PC without
-- the copy, shows the swatch.
local ICONS = ""
local ICONS_STUDIO = "rbxasset://textures/ridefish/aura_icons_e1.png"
local ICON_CELL, ICON_COLS = 256, 4
local ICON_SIZE = 180 -- as wide as the well

local window: Shop.Window? = nil
local carousel: Shop.Carousel
type Row = { Card: Shop.Card, Cash: Shop.Button, Robux: Shop.Button }
local rows: { [number]: Row } = {}

local function hex(c: Color3): string
	return string.format("#%02X%02X%02X", c.R * 255, c.G * 255, c.B * 255)
end

-- An aura's stand-in picture, where its icon isn't there: a glow of its two colours with bubbles round it
local function swatch(parent: Frame, tier: any): Frame
	local well: Frame = Kit.new("Frame", {
		Name = "Swatch",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ZIndex = 4,
	}, parent)
	for i, step in { { 0.96, 0.6 }, { 0.74, 0.35 }, { 0.5, 0.05 } } do
		local disc = Kit.new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.52),
			Size = UDim2.fromScale(step[1] * 0.92, step[1] * 0.92),
			BackgroundColor3 = Kit.White,
			BackgroundTransparency = step[2],
			BorderSizePixel = 0,
			ZIndex = 4 + i,
		}, well)
		Kit.corner(disc, 999)
		Kit.new("UIAspectRatioConstraint", { AspectRatio = 1 }, disc)
		Kit.gradient(disc, tier.Second, tier.Main)
	end
	for _, b in { { 0.18, 0.3, 14 }, { 0.82, 0.24, 18 }, { 0.2, 0.78, 10 }, { 0.8, 0.74, 12 }, { 0.5, 0.12, 9 } } do
		local bubble = Kit.bubble(well, b[3])
		bubble.AnchorPoint = Vector2.new(0.5, 0.5)
		bubble.Position = UDim2.fromScale(b[1], b[2])
		bubble.ZIndex = 8
	end
	Shop.icon(well, "Bubble", 76, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.52),
		ZIndex = 9,
	})
	return well
end

-- An aura's icon in its card's well; the swatch until it has loaded (so a missing picture leaves the swatch)
local function icon(well: Frame, tier: any)
	local stand = swatch(well, tier)
	local image = if ICONS ~= "" then ICONS elseif RunService:IsStudio() then ICONS_STUDIO else ""
	if image == "" then
		return
	end
	local at = tier.Id - 1
	local picture: ImageLabel = Kit.new("ImageLabel", {
		Name = "Icon",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(ICON_SIZE, ICON_SIZE),
		BackgroundTransparency = 1,
		Image = image,
		ImageRectOffset = Vector2.new(at % ICON_COLS, at // ICON_COLS) * ICON_CELL,
		ImageRectSize = Vector2.new(ICON_CELL, ICON_CELL),
		ScaleType = Enum.ScaleType.Fit,
		ZIndex = 10,
	}, well)
	local function look()
		stand.Visible = not picture.IsLoaded
	end
	picture:GetPropertyChangedSignal("IsLoaded"):Connect(look)
	look()
end

-- A tier's price in coins, when the economy has given it one (Shared/Auras has none yet: see the head note)
local function priceOf(id: number): number?
	local tier: any = Auras.Tiers[id]
	local price = tier and tier.Price
	return if type(price) == "number" then price else nil
end

local function wornNow(): number
	local worn = State.Player:GetAttribute("Aura")
	return if type(worn) == "number" then worn else 0
end

local function refresh()
	local now = wornNow()
	local coins = State.Player:GetAttribute("Coins")
	local have = if type(coins) == "number" then coins else 0
	for id, row in rows do
		row.Card.select(id == now)
		local price = priceOf(id)
		if id == now then
			row.Cash.set("Equipped", "Blue", false)
			row.Robux.Root.Visible = false
		elseif id < now then
			row.Cash.set("Owned", "Off", false)
			row.Robux.Root.Visible = false
		elseif price then
			-- bought one after another: only the next one is live, and only with the coins for it
			local can = id == now + 1 and have >= price
			row.Cash.set(Shop.cash(price), if can then "Cash" else "Off", can)
			row.Robux.Root.Visible = false
		else
			-- no prices yet: both dead (the economy draft decides them)
			row.Cash.set("Soon", "Off", false)
			row.Robux.Root.Visible = false
		end
	end
end

local function build()
	local w = Shop.window({
		Name = "AuraShop",
		Parent = State.Player:WaitForChild("PlayerGui"),
		Title = "Auras",
		Icon = "Bubble",
		Head = "Lavender",
		Width = WIDE,
		Height = HIGH,
		Dim = true,
		OnClose = function()
			Shop.go(nil)
		end,
	})
	window = w
	carousel = Shop.carousel(w.Body, {
		Position = UDim2.fromOffset(-6, 0),
		Size = UDim2.new(1, 12, 1, 0),
		CardWide = CARD_W,
		Gap = 12,
		Kind = "Lavender",
	})
	for _, tier in Auras.Tiers do
		local c = Shop.card(carousel.List, {
			Name = "Aura" .. tier.Id,
			Size = UDim2.fromOffset(CARD_W, CARD_H),
			Tint = tier.Main:Lerp(Color3.new(0, 0, 0), 0.08),
			Title = tier.Name .. " Aura",
			Line = "Lvl " .. tier.Id,
			WellHigh = 246,
			Stat = string.format('<font color="%s">x%s</font> Oxygen', hex(Shop.Money), tostring(tier.Mult)),
			SlotHigh = 46,
			LayoutOrder = tier.Id,
		})
		icon(c.Well, tier)
		local cash = Shop.button(c.Slot, {
			Name = "Cash",
			Kind = "Off",
			Size = UDim2.new(1, 0, 0, 44),
			TextSize = 26,
			LayoutOrder = 1,
			Live = false,
			Shine = true, -- (live only as the next aura with the coins for it: refresh)
		})
		local robux = Shop.button(c.Slot, {
			Name = "Robux",
			Kind = "Robux",
			Sign = "Robux",
			Size = UDim2.new(1, 0, 0, 34),
			TextSize = 22,
			LayoutOrder = 2,
		})
		rows[tier.Id] = { Card = c, Cash = cash, Robux = robux }
		cash.Root.Activated:Connect(function()
			-- (live only as the next aura with a price and the coins for it: refresh)
			if cash.Live and priceOf(tier.Id) and tier.Id == wornNow() + 1 then
				Net.Action:FireServer("AuraBuy", tier.Id)
			end
		end)
	end
	State.Player:GetAttributeChangedSignal("Aura"):Connect(refresh)
	State.Player:GetAttributeChangedSignal("Coins"):Connect(function()
		if w.isOpen() then
			refresh()
		end
	end)
end

function AuraShop.isOpen(): boolean
	return window ~= nil and window.isOpen()
end

-- Open or close the window. (Through Shop.go("Auras"), so another dock window closes.)
function AuraShop.open(on: boolean)
	if not window then
		if not on then
			return
		end
		build()
	end
	local w = window :: Shop.Window
	local was = w.isOpen()
	if on then
		refresh()
	end
	w.show(on)
	if on and not was then
		-- the aura worn, or the next one to buy, in view (once the window is laid out)
		task.defer(function()
			carousel.show(math.clamp(wornNow() + 1, 1, #Auras.Tiers))
		end)
	end
end

Shop.page("Auras", AuraShop.open)

return AuraShop
