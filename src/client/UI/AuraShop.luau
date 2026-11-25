--!strict
-- The Auras window, in the shop kit (UI/Shop; NULLROOM task s1, after Hugo's auras reference; task b2, Hugo
-- 2026-11-22: "integrate aura buying ui for the shop"). It opens when the player stands on the Auras stall's floor
-- ring and closes when they walk off (UI review 1, the user 2026-11-22: "they should pop up when you stand on the
-- stands corresponding to them in game"; Controllers/StallController), with the dim behind it.
-- What it shows: the twelve auras (Shared/Auras.Tiers) as tall cards in a sideways row, each tinted in its aura's own
-- colour: its name, "Lvl n", its icon in the cream well (the fish rider in a flame that grows with the tier: Hugo,
-- 2026-11-24, "fish rider"; art/ui/auras, tools/ui/aura_icons/build.py; a plain glow of its colour where the picture isn't
-- there: the bubbles that stood behind it are gone, Hugo, 2026-11-24), "x2 Oxygen" with the multiplier in green, and
-- one button: the cash price. (The Robux button is built but kept hidden: no product ids exist and none are made up,
-- and two dead SOON buttons on a card read as a mistake.) The player's own "Aura" attribute shows as EQUIPPED, with
-- the light border; the ones under it as OWNED.
-- Buying (2026-11-24, Hugo: "make sure you can buy them"): the prices are Config.Aura.Prices (SOON while Config.Aura.On is
-- 0), bought one after another. A press asks the server, Action "AuraBuy", tier; AuraService checks and takes everything
-- and answers on Ride ("AuraBought", "AuraDenied"), said on this window's hint line (the sounds: SoundController). The next
-- aura is green with the coins for it, grey without; nothing here is trusted.
local ContentProvider = game:GetService("ContentProvider")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Auras = require(ReplicatedStorage.Shared.Auras)
local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)
local State = require(script.Parent.Parent.Lib.State)
local Kit = require(script.Parent.Kit)
local Shop = require(script.Parent.Shop)

local AuraShop = {}

-- (the window is the Sell Fish window's size, so the two stalls' windows match)
local WIDE, HIGH = 860, 540
local CARD_W, CARD_H = 196, 404

-- The icons' picture (4 across, 3 down, 256 pixels each, by tier). Uploaded 2026-11-25 (the user:
-- "Yes, both"); while it is empty, Studio reads the local copy (tools/ui/aura_icons/build.py --studio); a live game before that, or a PC without
-- the copy, shows the glow.
local ICONS = "rbxassetid://118905885839265"
local ICONS_STUDIO = "rbxasset://textures/ridefish/aura_icons_e1.png"
local ICON_CELL, ICON_COLS = 256, 4
local ICON_SIZE = 180 -- as wide as the well

local window: Shop.Window? = nil
local carousel: Shop.Carousel
type Row = { Card: Shop.Card, Cash: Shop.Button, Robux: Shop.Button, Can: boolean }
local rows: { [number]: Row } = {}
local hintText: TextLabel
local hintRun = 0
local HINT = Color3.fromRGB(255, 226, 80)
local askedAt = -math.huge

local function hex(c: Color3): string
	return string.format("#%02X%02X%02X", c.R * 255, c.G * 255, c.B * 255)
end

-- Where an aura's icon isn't there: a plain glow of its colour
local function glow(well: Frame, tier: any)
	if well:FindFirstChild("Glow") then
		return
	end
	local holder: Frame = Kit.new("Frame", {
		Name = "Glow",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ZIndex = 4,
	}, well)
	for i, step in { { 0.88, 0.6 }, { 0.68, 0.35 }, { 0.46, 0.05 } } do
		local disc = Kit.new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(step[1], step[1]),
			BackgroundColor3 = Kit.White,
			BackgroundTransparency = step[2],
			BorderSizePixel = 0,
			ZIndex = 4 + i,
		}, holder)
		Kit.corner(disc, 999)
		Kit.new("UIAspectRatioConstraint", { AspectRatio = 1 }, disc)
		Kit.gradient(disc, tier.Second, tier.Main)
	end
end

-- An aura's icon in its card's well; the glow only where there is no picture, never behind one
local function icon(well: Frame, tier: any, missing: boolean)
	if missing then
		return glow(well, tier)
	end
	local at = tier.Id - 1
	Kit.new("ImageLabel", {
		Name = "Icon",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(ICON_SIZE, ICON_SIZE),
		BackgroundTransparency = 1,
		Image = if ICONS ~= "" then ICONS else ICONS_STUDIO,
		ImageRectOffset = Vector2.new(at % ICON_COLS, at // ICON_COLS) * ICON_CELL,
		ImageRectSize = Vector2.new(ICON_CELL, ICON_CELL),
		ScaleType = Enum.ScaleType.Fit,
		ZIndex = 10,
	}, well)
end

-- A tier's price in coins (nil: not for sale)
local function priceOf(id: number): number?
	local price = Config.Aura.Prices[id]
	return if Config.Aura.On ~= 0 and type(price) == "number" then price else nil
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
		row.Can = false
		local price = priceOf(id)
		if id == now then
			row.Cash.set("Equipped", "Blue", false)
			row.Robux.Root.Visible = false
		elseif id < now then
			row.Cash.set("Owned", "Off", false)
			row.Robux.Root.Visible = false
		elseif price then
			-- bought one after another: the next one is green with the coins for it. The rest are grey but still ask:
			-- the server says why not
			row.Can = id == now + 1 and have >= price
			row.Cash.set(Shop.cash(price), if row.Can then "Cash" else "Off", true)
			row.Robux.Root.Visible = false
		else
			-- not for sale (Config.Aura.On 0): both dead
			row.Cash.set("Soon", "Off", false)
			row.Robux.Root.Visible = false
		end
	end
end

-- What the server said, a moment on the window's lower edge
local function hint(text: string)
	hintText.Text = text
	hintText.Visible = true
	hintRun += 1
	local run = hintRun
	task.delay(2.2, function()
		if run == hintRun then
			hintText.Visible = false
		end
	end)
end

local function answered(kind: string, a: any)
	if kind == "AuraBought" then
		local tier = Auras.Tiers[a]
		hint(if tier then `{string.upper(tier.Name)} AURA bought and put on! x{tier.Mult} Oxygen` else "Bought!")
	elseif kind == "AuraDenied" then
		local nextOne = Auras.Tiers[wornNow() + 1]
		hint(
			if a == "Coins"
				then "Not enough coins!"
				elseif a == "Order" and nextOne then `Buy the {nextOne.Name} Aura first!`
				elseif a == "Dock" then "Only at the aura stall!"
				elseif a == "Busy" then "One at a time!"
				else "Can't do that"
		)
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
	local missing = ICONS == "" and not RunService:IsStudio()
	local wells: { [number]: Frame } = {}
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
		icon(c.Well, tier, missing)
		wells[tier.Id] = c.Well
		local cash = Shop.button(c.Slot, {
			Name = "Cash",
			Kind = "Off",
			Size = UDim2.new(1, 0, 0, 44),
			TextSize = 26,
			LayoutOrder = 1,
			Live = false,
			Shine = function(): boolean
				local row = rows[tier.Id]
				return row ~= nil and row.Can
			end,
		})
		local robux = Shop.button(c.Slot, {
			Name = "Robux",
			Kind = "Robux",
			Sign = "Robux",
			Size = UDim2.new(1, 0, 0, 34),
			TextSize = 22,
			LayoutOrder = 2,
		})
		rows[tier.Id] = { Card = c, Cash = cash, Robux = robux, Can = false }
		cash.Root.Activated:Connect(function()
			-- (not one owned, and one ask at a time)
			if
				cash.Live
				and priceOf(tier.Id)
				and tier.Id > wornNow()
				and os.clock() - askedAt >= Config.Aura.BuyAgain
			then
				askedAt = os.clock()
				Net.Action:FireServer("AuraBuy", tier.Id)
			end
		end)
	end
	hintText = Shop.text(w.Root, {
		Name = "Hint",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(700, 40),
		Position = UDim2.new(0.5, 0, 0.5, HIGH / 2 + 4),
		TextSize = 30,
		TextColor3 = HINT,
		Visible = false,
	})
	hintText.ZIndex = 20
	Net.Ride.OnClientEvent:Connect(answered)
	if not missing then
		-- a picture that isn't there (a PC without the local copy): the glow
		task.spawn(function()
			local failed = false
			pcall(function()
				ContentProvider:PreloadAsync(
					{ if ICONS ~= "" then ICONS else ICONS_STUDIO } :: { any },
					function(_id, status)
						failed = failed or status == Enum.AssetFetchStatus.Failure
					end
				)
			end)
			if failed then
				for id, well in wells do
					glow(well, Auras.Tiers[id])
				end
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
