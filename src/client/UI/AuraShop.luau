--!strict
-- The shop's Auras page, in the shop kit (UI/Shop; NULLROOM task s1, after Hugo's auras reference; wired into the
-- shop in task b2, Hugo 2026-11-22: "integrate aura buying ui for the shop"). It opens as the shop's "Auras" page
-- (Shop.go("Auras"): the hub's Shop button, AuraController), with the shop's tabs on its top edge.
-- What it shows: the twelve auras (Shared/Auras.Tiers) as tall cards in a sideways row, each tinted in its aura's own
-- colour: its name, "Lvl n", a picture of its colours in the cream well, "x2 Oxygen" with the multiplier in green, and
-- one button: the cash price. (The Robux button is built but kept hidden: no product ids exist and none are made up,
-- and two dead SOON buttons on a card read as a mistake.) The player's own "Aura" attribute shows as EQUIPPED, with
-- the light border; the ones under it as OWNED.
-- BUYING IS NOT ON YET: auras have no prices and the server has no aura purchase (Shared/Auras: "buying waits for the
-- economy's prices"), so every cash button says SOON and asks nothing. The hook-up is ready on this side: once a tier
-- in Shared/Auras carries a `Price` (coins), its card shows it (green when the player's "Coins" cover it and it is the
-- next aura, grey otherwise) and a press asks the server Action "AuraBuy", tier. The server must then check the
-- price and the order itself, take the coins and set the player's "Aura" attribute; nothing here is trusted.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Auras = require(ReplicatedStorage.Shared.Auras)
local Net = require(ReplicatedStorage.Shared.Net)
local State = require(script.Parent.Parent.Lib.State)
local Kit = require(script.Parent.Kit)
local Shop = require(script.Parent.Shop)

local AuraShop = {}

-- (the window is the Sell Fish page's size, so the shop's tabs and title stay put from page to page)
local WIDE, HIGH = 860, 540
local CARD_W, CARD_H = 196, 404

local window: Shop.Window? = nil
local carousel: Shop.Carousel
type Row = { Card: Shop.Card, Cash: Shop.Button, Robux: Shop.Button }
local rows: { [number]: Row } = {}

local function hex(c: Color3): string
	return string.format("#%02X%02X%02X", c.R * 255, c.G * 255, c.B * 255)
end

-- An aura's picture: a glow of its two colours with bubbles round it (no art of the aura exists yet)
local function swatch(well: Frame, tier: any)
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
			row.Cash.set("EQUIPPED", "Blue", false)
			row.Robux.Root.Visible = false
		elseif id < now then
			row.Cash.set("OWNED", "Off", false)
			row.Robux.Root.Visible = false
		elseif price then
			-- bought one after another: only the next one is live, and only with the coins for it
			local can = id == now + 1 and have >= price
			row.Cash.set(Shop.cash(price), if can then "Cash" else "Off", can)
			row.Robux.Root.Visible = false
		else
			-- no prices yet: both dead (the economy draft decides them)
			row.Cash.set("SOON", "Off", false)
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
		Tabs = true,
		OnClose = function()
			Shop.go(nil)
		end,
	})
	window = w
	Shop.tabs(w, "Auras")
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
		swatch(c.Well, tier)
		local cash = Shop.button(c.Slot, {
			Name = "Cash",
			Kind = "Off",
			Size = UDim2.new(1, 0, 0, 44),
			TextSize = 26,
			LayoutOrder = 1,
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
		if w.Gui.Enabled then
			refresh()
		end
	end)
end

function AuraShop.isOpen(): boolean
	return window ~= nil and window.Gui.Enabled
end

-- Open or close the page. (Through Shop.go("Auras"), so the shop's other page closes.)
function AuraShop.open(on: boolean)
	if not window then
		if not on then
			return
		end
		build()
	end
	local w = window :: Shop.Window
	local was = w.Gui.Enabled
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
