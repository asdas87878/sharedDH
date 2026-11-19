--!strict
-- The aura stand's shop, in the shop kit (UI/Shop; NULLROOM task s1, after Hugo's auras reference). READY, NOT WIRED:
-- auras can't be bought yet (Shared/Auras: "buying waits for the economy's prices"), so nothing in the game opens this
-- and its buttons ask nothing of the server. When the aura stand and its prices land, its owner calls
-- AuraShop.open(true) from the stand's prompt and points the buttons at the server's action.
-- What it shows: the twelve auras (Shared/Auras.Tiers) as tall cards in a sideways row, each tinted in its aura's own
-- colour: its name, "Lvl n", a picture of its colours in the cream well, "x2 Oxygen" with the multiplier in green, and
-- two buttons: the cash price (grey "SOON" until prices exist) and a Robux price (visual only: no product ids exist,
-- none are made up). The player's own "Aura" attribute shows as EQUIPPED, with the light border.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Auras = require(ReplicatedStorage.Shared.Auras)
local State = require(script.Parent.Parent.Lib.State)
local Kit = require(script.Parent.Kit)
local Shop = require(script.Parent.Shop)

local AuraShop = {}

local WIDE, HIGH = 800, 450
local CARD_W, CARD_H = 188, 330

local window: Shop.Window? = nil
local carousel: Shop.Carousel
type Row = { Card: Shop.Card, Cash: Shop.Button, Robux: Shop.Button }
local rows: { [number]: Row } = {}

local function hex(c: Color3): string
	return string.format("#%02X%02X%02X", c.R * 255, c.G * 255, c.B * 255)
end

-- An aura's picture: a glow of its two colours with bubbles round it (no art of the aura exists yet)
local function swatch(well: Frame, tier: any)
	for i, step in { { 0.92, 0.55 }, { 0.7, 0.3 }, { 0.46, 0 } } do
		local disc = Kit.new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.52),
			Size = UDim2.fromScale(step[1] * 0.62, step[1]),
			BackgroundColor3 = Kit.White,
			BackgroundTransparency = step[2],
			BorderSizePixel = 0,
			ZIndex = 4 + i,
		}, well)
		Kit.corner(disc, 999)
		Kit.gradient(disc, tier.Second, tier.Main)
		if i == 3 then
			Kit.stroke(disc, 3, Shop.Edge)
		end
	end
	for _, b in { { 0.18, 0.3, 14 }, { 0.82, 0.24, 18 }, { 0.2, 0.78, 10 }, { 0.8, 0.74, 12 }, { 0.5, 0.12, 9 } } do
		local bubble = Kit.bubble(well, b[3])
		bubble.AnchorPoint = Vector2.new(0.5, 0.5)
		bubble.Position = UDim2.fromScale(b[1], b[2])
		bubble.ZIndex = 8
	end
	Shop.icon(well, "Bubble", 40, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.52),
		ZIndex = 9,
	})
end

local function refresh()
	local worn = State.Player:GetAttribute("Aura")
	local now = if type(worn) == "number" then worn else 0
	for id, row in rows do
		row.Card.select(id == now)
		if id == now then
			row.Cash.set("EQUIPPED", "Blue", false)
			row.Robux.Root.Visible = false
		else
			-- no prices yet: both grey-ish and dead (the economy draft decides them)
			row.Cash.set("SOON", "Off", false)
			row.Robux.set("SOON", "Robux", false)
			row.Robux.Root.Visible = true
		end
	end
end

local function build()
	local w = Shop.window({
		Name = "AuraShop",
		Parent = State.Player:WaitForChild("PlayerGui"),
		Title = "AURAS",
		Icon = "Bubble",
		Head = "Lavender",
		Centre = true,
		Width = WIDE,
		Height = HIGH,
		OnClose = function()
			AuraShop.open(false)
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
			WellHigh = 118,
			Stat = string.format('<font color="%s">x%s</font> Oxygen', hex(Shop.Money), tostring(tier.Mult)),
			SlotHigh = 80,
			LayoutOrder = tier.Id,
		})
		swatch(c.Well, tier)
		local cash = Shop.button(c.Slot, {
			Name = "Cash",
			Kind = "Off",
			Size = UDim2.new(1, 0, 0, 40),
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
	end
	State.Player:GetAttributeChangedSignal("Aura"):Connect(refresh)
end

-- Open or close the shop (nothing calls this yet but Studio's captures)
function AuraShop.open(on: boolean)
	if not window then
		if not on then
			return
		end
		build()
	end
	local w = window :: Shop.Window
	if on then
		refresh()
	end
	w.show(on)
end

return AuraShop
