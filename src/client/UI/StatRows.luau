--!strict
-- The stat rows (the reference's, at the lower left): a dark bar that fades out to the right, with a darker edge down
-- its left and along its bottom, a sign and a number. Ours: your Oxygen (the stat you train, with the bubble) and
-- your coins. The coins row stays hidden until the game has coins (the player's "Coins" attribute).
-- On a phone the rows sit at the top left, clear of Roblox's stick.
local Kit = require(script.Parent.Kit)

local StatRows = {}

local WIDTH = 128
local HEIGHT = 29

local holder: Frame
local list: UIListLayout
local oxygenText: TextLabel
local coinsRow: Frame
local coinsText: TextLabel

local shownOxygen = -1
local shownSpent = false
local shownCoins = -1

local FADE = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 0.08),
	NumberSequenceKeypoint.new(0.55, 0.45),
	NumberSequenceKeypoint.new(1, 1),
})

local function row(order: number, sign: (Instance, number) -> Frame, colour: Color3): (Frame, TextLabel)
	local frame: Frame = Kit.new("Frame", {
		Size = UDim2.fromOffset(WIDTH, HEIGHT),
		BackgroundTransparency = 1,
		LayoutOrder = order,
	}, holder)
	local bar = Kit.new("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Kit.Navy,
		BorderSizePixel = 0,
	}, frame)
	Kit.new("UIGradient", { Transparency = FADE }, bar)
	-- the darker edge: down the left, and along the bottom where it fades out with the bar
	Kit.new("Frame", {
		Size = UDim2.new(0, 3, 1, 0),
		BackgroundColor3 = Kit.Ink,
		BorderSizePixel = 0,
	}, frame)
	local under = Kit.new("Frame", {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, 3),
		BackgroundColor3 = Kit.Ink,
		BorderSizePixel = 0,
	}, frame)
	Kit.new("UIGradient", { Transparency = FADE }, under)
	local icon = sign(frame, 19)
	icon.AnchorPoint = Vector2.new(0, 0.5)
	icon.Position = UDim2.new(0, 10, 0.5, -1)
	local label = Kit.text({
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 36, 0.5, -1),
		Size = UDim2.fromOffset(WIDTH - 40, HEIGHT),
		TextSize = 16,
		TextColor3 = colour,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, frame, 2.4)
	return frame, label
end

function StatRows.build(parent: Instance)
	holder = Kit.new("Frame", {
		Name = "StatRows",
		Size = UDim2.fromOffset(WIDTH, HEIGHT * 2 + 5),
		BackgroundTransparency = 1,
	}, parent)
	list = Kit.new("UIListLayout", {
		Padding = UDim.new(0, 5),
		SortOrder = Enum.SortOrder.LayoutOrder,
		VerticalAlignment = Enum.VerticalAlignment.Bottom,
	}, holder)
	local _, oxygen = row(1, Kit.bubble, Kit.White)
	oxygenText = oxygen
	coinsRow, coinsText = row(2, Kit.coin, Color3.fromRGB(255, 224, 102))
	coinsRow.Visible = false
end

function StatRows.place(touch: boolean)
	if touch then
		holder.AnchorPoint = Vector2.new(0, 0)
		holder.Position = UDim2.fromOffset(10, 58)
		list.VerticalAlignment = Enum.VerticalAlignment.Top
	else
		holder.AnchorPoint = Vector2.new(0, 1)
		holder.Position = UDim2.new(0, 10, 1, -10)
		list.VerticalAlignment = Enum.VerticalAlignment.Bottom
	end
end

-- oxygen: your max Oxygen; coins: nil until the game has them; spent: drowning with none left. The row is the most
-- you can carry, which a drowning player read as what they had left ("100"), so for that moment it is a red 0
function StatRows.update(oxygen: number, coins: number?, spent: boolean)
	local whole = if spent then 0 else math.floor(oxygen + 0.5)
	if whole ~= shownOxygen then
		shownOxygen = whole
		oxygenText.Text = Kit.short(whole)
	end
	if spent ~= shownSpent then
		shownSpent = spent
		oxygenText.TextColor3 = if spent then Kit.Coral else Kit.White
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
