--!strict
-- The stat rows (where the reference has its own, at the lower left): a plate each, a sign and a number. Your Oxygen
-- (the stat you train) is water: blue, with bubbles; it turns red and beats in the last second on a fish and while
-- you drown. Your coins are gold bricks; that row stays hidden until the game has coins (the player's "Coins").
-- On a phone the rows sit at the top left, clear of Roblox's stick.
local Kit = require(script.Parent.Kit)

local StatRows = {}

local WIDTH = 104
local HEIGHT = 29
local GAP = Kit.Space.Medium

local holder: Frame
local list: UIListLayout
local oxygenText: TextLabel
local oxygenLook: Kit.Dressed
local oxygenBeat: (on: boolean) -> ()
local coinsRow: Frame
local coinsText: TextLabel

local shownOxygen = -1
local shownLow = false
local shownCoins = -1

local function row(
	order: number,
	sign: (Instance, number) -> Frame,
	colour: Color3,
	style: Kit.Style
): (Kit.Panel, TextLabel)
	local panel = Kit.panel(holder, { Size = UDim2.fromOffset(WIDTH, HEIGHT), LayoutOrder = order }, style)
	local icon = sign(panel.Face, 19)
	icon.AnchorPoint = Vector2.new(0, 0.5)
	icon.Position = UDim2.new(0, Kit.Space.Medium, 0.5, 0)
	local label = Kit.text({
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 34, 0.5, 0),
		Size = UDim2.fromOffset(WIDTH - 38, HEIGHT),
		TextSize = 17,
		TextColor3 = colour,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, panel.Face)
	return panel, label
end

function StatRows.build(parent: Instance)
	holder = Kit.new("Frame", {
		Name = "StatRows",
		Size = UDim2.fromOffset(WIDTH, HEIGHT * 2 + GAP),
		BackgroundTransparency = 1,
	}, parent)
	list = Kit.new("UIListLayout", {
		Padding = UDim.new(0, GAP),
		SortOrder = Enum.SortOrder.LayoutOrder,
		VerticalAlignment = Enum.VerticalAlignment.Bottom,
	}, holder)
	local air, oxygen = row(1, Kit.bubble, Kit.White, Kit.Themes.Oxygen)
	oxygenText = oxygen
	oxygenLook = air.Look
	Kit.bubbles(air.Face, { { 0.66, 0.34, 7 }, { 0.8, 0.68, 5 }, { 0.91, 0.3, 4 } })
	oxygenBeat = Kit.pulse(air.Look.Outline, { Color = Kit.Ink }, { Color = Color3.fromRGB(255, 196, 180) })
	local money, coins = row(2, Kit.coin, Kit.White, Kit.Themes.Gold)
	coinsRow = money.Frame
	coinsText = coins
	coinsRow.Visible = false
end

function StatRows.place(touch: boolean)
	if touch then
		holder.AnchorPoint = Vector2.new(0, 0)
		holder.Position = UDim2.fromOffset(12, 58)
		list.VerticalAlignment = Enum.VerticalAlignment.Top
	else
		holder.AnchorPoint = Vector2.new(0, 1)
		holder.Position = UDim2.new(0, 12, 1, -14)
		list.VerticalAlignment = Enum.VerticalAlignment.Bottom
	end
end

-- oxygen: your max Oxygen; coins: nil until the game has them; spent: drowning with none left; low: the last second
-- on a fish. The row is the most you can carry, which a drowning player read as what they had left ("100"), so for
-- that moment it is a 0. Low or spent, the plate is red and its outline beats
function StatRows.update(oxygen: number, coins: number?, spent: boolean, low: boolean)
	local whole = if spent then 0 else math.floor(oxygen + 0.5)
	if whole ~= shownOxygen then
		shownOxygen = whole
		oxygenText.Text = Kit.short(whole)
	end
	local red = low or spent
	if red ~= shownLow then
		shownLow = red
		local theme = if red then Kit.Themes.Danger else Kit.Themes.Oxygen
		oxygenLook.paint(theme.Top, theme.Bottom)
		-- the water's picture is blue: over the red it is nearly taken out, or the plate goes grey
		local pattern = oxygenLook.Texture
		if pattern then
			pattern.ImageTransparency = if red then 0.93 else Kit.Themes.Oxygen.TextureFade or 0.8
		end
		oxygenBeat(red)
	end
	local money = if coins then math.floor(coins) else -1
	if money ~= shownCoins then
		shownCoins = money
		coinsRow.Visible = coins ~= nil
		if coins then
			coinsText.Text = "$" .. Kit.short(money)
		end
	end
end

return StatRows
