--!strict
-- The stat rows (where the reference has its own, at the lower left): a plate each, a sign and a number. Your Oxygen
-- (the stat you train) is water: blue, with bubbles; it turns red and beats in the last second on a fish and while
-- you drown. Your coins are gold bricks; that row stays hidden until the game has coins (the player's "Coins").
-- On a phone the rows sit at the top left, clear of Roblox's stick.
-- With a corner box (Kit.oxygenCorner, Hugo 2026-11-14) the Oxygen row on a keyboard grows into the screen's bottom left
-- corner: its glass runs out to the left and bottom edges, so only its top and right edges show. In the corner the
-- bubble and the number are bigger and fill the box (Hugo 2026-11-14: "make the text a bit bigger and make sure it fills
-- out the box better"): the box is cut to fit them, with the same gap on every side (CORNER).
local TextService = game:GetService("TextService")

local Kit = require(script.Parent.Kit)

local StatRows = {}

local WIDTH = 104
local HEIGHT = 29
local GAP = Kit.Space.Medium
local LEFT = 12 -- the rows' gap to the screen's left edge, and to its bottom on a keyboard
local BOTTOM = 14
local ON_TOUCH = 0.85 -- the rows' size on a phone, where they share the top left with Roblox's own buttons
local ICON = 19
local TEXT = 17
-- The Oxygen box in the corner: the gap round what it shows, the same on every side (to the screen's edges too; counted
-- from the outlines, which stand out past the bubble and the letters), the bubble's size, the gap from it to the
-- number, the number's size (a quarter bigger than a row's 17), and the widest number the box is cut for: a narrower one
-- sits in the middle of that room, a wider one (1.2K) widens the box. The box is as tall as the row and its gap to the
-- screen's bottom (29 + 14), so the bubble's size and Pad go together: 22 and its outline (2.4 a side) leave 8.
local CORNER = { Pad = 8, Icon = 22, Gap = 6, Text = 21, Room = "100" }

local holder: Frame
local size: UIScale
local list: UIListLayout
local oxygenText: TextLabel
local oxygenLook: Kit.Dressed
local oxygenBeat: (on: boolean) -> ()
local oxygenIcon: Frame
local inCorner = false
local airRow: Kit.Panel
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
): (Kit.Panel, TextLabel, Frame, Frame)
	local panel = Kit.panel(holder, { Size = UDim2.fromOffset(WIDTH, HEIGHT), LayoutOrder = order }, style)
	-- what the row shows, in a clear frame the row's size: the face can then grow round it (a corner box)
	local inner: Frame =
		Kit.new("Frame", { Name = "Inner", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }, panel.Face)
	local icon = sign(inner, ICON)
	icon.AnchorPoint = Vector2.new(0, 0.5)
	icon.Position = UDim2.new(0, Kit.Space.Medium, 0.5, 0)
	local label = Kit.text({
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 34, 0.5, 0),
		Size = UDim2.fromOffset(WIDTH - 38, HEIGHT),
		TextSize = TEXT,
		TextColor3 = colour,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, inner)
	return panel, label, inner, icon
end

-- How wide a number is at a size, in the rows' font
local function wide(text: string, textSize: number): number
	return TextService:GetTextSize(text, textSize, Kit.Font, Vector2.new(1000, 100)).X
end

-- The outlines' widths in the corner: the bubble's (as Kit.bubble draws it) and the number's (as Kit.text does)
local function iconLine(): number
	return math.max(1.5, CORNER.Icon * 0.11)
end
local function textLine(): number
	return math.clamp(CORNER.Text * 0.19, 1.6, 4)
end

-- The Oxygen box in the corner: the number's slot starts after the bubble and Gap, and the box ends Pad after it. The
-- slot is as wide as the number shown (never narrower than CORNER.Room) and its outline; the face runs out LEFT past
-- the row's left edge, to the screen's
local function fitCorner()
	local room = math.max(wide(oxygenText.Text, CORNER.Text), wide(CORNER.Room, CORNER.Text))
	local slot = math.ceil(room + textLine() * 2)
	local start = math.floor(CORNER.Pad + iconLine() * 2 + CORNER.Icon + CORNER.Gap + 0.5)
	oxygenText.Position = UDim2.new(0, start, 0.5, 0)
	oxygenText.Size = UDim2.new(0, slot, 1, 0)
	airRow.Face.Size = UDim2.new(0, start + slot + CORNER.Pad, 1, BOTTOM)
end

function StatRows.build(parent: Instance)
	holder = Kit.new("Frame", {
		Name = "StatRows",
		Size = UDim2.fromOffset(WIDTH, HEIGHT * 2 + GAP),
		BackgroundTransparency = 1,
	}, parent)
	size = Kit.new("UIScale", {}, holder) -- set once for a phone or a keyboard, never moved
	list = Kit.new("UIListLayout", {
		Padding = UDim.new(0, GAP),
		SortOrder = Enum.SortOrder.LayoutOrder,
		VerticalAlignment = Enum.VerticalAlignment.Bottom,
	}, holder)
	local air, oxygen, airInner, airIcon = row(1, Kit.bubble, Kit.White, Kit.Themes.Oxygen)
	airRow = air
	oxygenText = oxygen
	oxygenIcon = airIcon
	inCorner = false
	shownOxygen = -1
	shownLow = false
	oxygenLook = air.Look
	Kit.bubbles(airInner, { { 0.66, 0.34, 7 }, { 0.8, 0.68, 5 }, { 0.91, 0.3, 4 } })
	oxygenBeat = Kit.pulse(air.Look.Outline, { Color = Kit.Ink }, { Color = Color3.fromRGB(255, 196, 180) })
	local money, coins = row(2, Kit.coin, Kit.White, Kit.Themes.Gold)
	coinsRow = money.Frame
	coinsText = coins
	coinsRow.Visible = false
end

-- A corner box on a keyboard: the Oxygen row is the bottom one and its face reaches the screen's left and bottom edges
-- (the rows' own gaps to them, LEFT and BOTTOM). Its Inner frame then covers the whole face, and the bubble and the
-- number are laid out in it with CORNER's gaps; the plate's three small rings are left out (no room for them)
local function corner(on: boolean)
	inCorner = on
	local face = airRow.Face
	local inner = face:FindFirstChild("Inner") :: Frame
	local outline = oxygenText:FindFirstChildOfClass("UIStroke")
	airRow.Frame.LayoutOrder = if on then 3 else 1
	for _, ring in inner:GetChildren() do
		if ring.Name == "Bubble" and ring:IsA("GuiObject") then
			ring.Visible = not on
		end
	end
	inner.Position = UDim2.fromOffset(0, 0)
	inner.Size = UDim2.fromScale(1, 1)
	if on then
		face.Position = UDim2.fromOffset(-LEFT, 0)
		oxygenIcon.Size = UDim2.fromOffset(CORNER.Icon, CORNER.Icon)
		oxygenIcon.Position = UDim2.new(0, CORNER.Pad + iconLine(), 0.5, 0)
		oxygenText.TextSize = CORNER.Text
		oxygenText.TextXAlignment = Enum.TextXAlignment.Center
		fitCorner()
	else
		face.Position = UDim2.fromOffset(0, 0)
		face.Size = UDim2.fromScale(1, 1)
		oxygenIcon.Size = UDim2.fromOffset(ICON, ICON)
		oxygenIcon.Position = UDim2.new(0, Kit.Space.Medium, 0.5, 0)
		oxygenText.TextSize = TEXT
		oxygenText.TextXAlignment = Enum.TextXAlignment.Left
		oxygenText.Position = UDim2.new(0, 34, 0.5, 0)
		oxygenText.Size = UDim2.fromOffset(WIDTH - 38, HEIGHT)
	end
	if outline then
		outline.Thickness = math.clamp(oxygenText.TextSize * 0.19, 1.6, 4)
	end
	local ring = oxygenIcon:FindFirstChildOfClass("UIStroke")
	if ring then
		ring.Thickness = math.max(1.5, oxygenIcon.Size.X.Offset * 0.11)
	end
end

function StatRows.place(touch: boolean)
	corner(Kit.oxygenCorner() and not touch)
	if touch then
		holder.AnchorPoint = Vector2.new(0, 0)
		holder.Position = UDim2.fromOffset(LEFT, 58)
		list.VerticalAlignment = Enum.VerticalAlignment.Top
		size.Scale = ON_TOUCH
	else
		-- its bottom edge level with the slots' (Slots.place)
		holder.AnchorPoint = Vector2.new(0, 1)
		holder.Position = UDim2.new(0, LEFT, 1, -BOTTOM)
		list.VerticalAlignment = Enum.VerticalAlignment.Bottom
		size.Scale = 1
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
		if inCorner then
			fitCorner()
		end
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
