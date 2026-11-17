--!strict
-- The stat rows, at the lower left where the reference has its own (the user, 2026-11-17: "get the coins, oxygen
-- (stamina equivalent) looking to standard. Heavily ride a dino inspired. Copy their placements and sizes", then, with
-- a sharp picture of the reference's two rows: "make it 1:1 and then recreate the + icons next to it").
-- Every size and every fade below is measured off that picture, where a row is 80 pixels tall: half a unit here to its
-- pixel. A row is a black see-through bar whose fill thins evenly to nothing along its length, inside a line down its
-- left and along its top and bottom that stay dark for two thirds of the way and then go; a sign; the number in white
-- with a thin black outline; and, at the dock only (as the reference's at its hub), a green plus button past the bar's
-- end. Your Oxygen (the stat you train) is the upper row, with a bubble for its sign; it turns red and beats in the
-- last second on a fish and while you drown. Your coins are the lower row; it stays hidden until the game has coins
-- (the player's "Coins"), and the Oxygen row then sits where it was.
-- On a phone the rows sit at the top left, clear of Roblox's stick.
-- This replaces the glass box in the corner (Kit.OxygenBox, Hugo 2026-11-14): Kit still holds it, nothing here uses it.
local Kit = require(script.Parent.Kit)

local StatRows = {}

local pressed = Instance.new("BindableEvent")
-- Fired with "Oxygen" or "Coins" when that row's plus button is pressed. Nothing listens yet: what a plus opens is
-- not decided
StatRows.Pressed = pressed.Event

local HEIGHT = 40
local GAP = 2.5 -- a little more than the reference's 1.5, to go with the thicker lines (the user, 2026-11-17)
local LENGTH = 129 -- the bar, to where its lines have gone
local EDGE = 2 -- the lines' thickness: the reference's 1.5 drew thinner than its own on our screens (the user)
local LEFT = 10 -- the rows' gap to the screen's left edge (the reference's, off the user's recording)
local BOTTOM = 14 -- and to its bottom: the slots' own, so the two stay level
local ICON = 20 -- with its outline: 24.4, as the reference's signs
local ICON_AT = 20 -- the sign's middle, from the bar's left end
local TEXT = 22 -- capitals 12.5 tall (the font's capitals are 0.56 of its size)
local TEXT_AT = 41
local TEXT_LINE = 1.5
local PLUS = 27
local PLUS_AT = 129.5
local WIDTH = PLUS_AT + PLUS
local ON_TOUCH = 0.85 -- the rows' size on a phone, where they share the top left with Roblox's own buttons

local BLACK = Color3.new(0, 0, 0)
-- How see-through the fill is along the bar: 43% black at the left, thinning evenly, gone a little before the lines
local FILL = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 0.57),
	NumberSequenceKeypoint.new(0.2, 0.65),
	NumberSequenceKeypoint.new(0.4, 0.73),
	NumberSequenceKeypoint.new(0.58, 0.8),
	NumberSequenceKeypoint.new(0.68, 0.88),
	NumberSequenceKeypoint.new(0.78, 0.925),
	NumberSequenceKeypoint.new(0.87, 0.97),
	NumberSequenceKeypoint.new(0.96, 1),
	NumberSequenceKeypoint.new(1, 1),
})
-- And the top and bottom lines: nearly solid at the left, half gone at two thirds, then quickly to nothing
local LINE = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 0.13),
	NumberSequenceKeypoint.new(0.31, 0.31),
	NumberSequenceKeypoint.new(0.5, 0.41),
	NumberSequenceKeypoint.new(0.64, 0.47),
	NumberSequenceKeypoint.new(0.78, 0.66),
	NumberSequenceKeypoint.new(0.87, 0.82),
	NumberSequenceKeypoint.new(0.96, 0.95),
	NumberSequenceKeypoint.new(1, 1),
})
-- The signs as pictures: the user's own two icons (an O2 bubble, a stack of cash; 2026-11-17, "use these icons"),
-- cut out by tools/ui/icon_cut.py (art/ui/icons) and uploaded that day. Empty: the drawn bubble and coin stand in
local PICTURE: { [string]: string } = { Oxygen = Kit.Textures.Oxygen, Coins = Kit.Textures.Cash }
local PICTURE_SIZE = 27
-- the coins' number: pale gold beside the drawn coin, the reference's pale green beside the cash
local COINS = if PICTURE.Coins == "" then Color3.fromRGB(255, 226, 120) else Kit.Cash
local WARN = Color3.fromRGB(255, 170, 160) -- the Oxygen number on a red bar
local HOT = Color3.fromRGB(255, 122, 110) -- what a red bar beats to
-- The plus button's greens, top to bottom: its pale rim, its face, and the lip along its foot
local RIM = { Color3.fromRGB(209, 254, 196), Color3.fromRGB(60, 227, 56) }
local FACE = { Color3.fromRGB(172, 254, 0), Color3.fromRGB(36, 217, 0) }
local LIP = Color3.fromRGB(28, 189, 4)

type Row = { Frame: Frame, Fill: Frame, Text: TextLabel, Plus: TextButton, Colour: Color3 }

local holder: Frame
local size: UIScale
local list: UIListLayout
local air: Row
local money: Row
local oxygenBeat: (on: boolean) -> ()

local shownOxygen = -1
local shownLow = false
local shownCoins = -1
local shownDocked = false

local function block(props: { [string]: any }, parent: Instance): Frame
	props.BorderSizePixel = 0
	return Kit.new("Frame", props, parent)
end

-- A line on a bar's top or bottom edge, fading out as LINE says
local function line(parent: Instance, bottom: boolean)
	local edge = block({
		AnchorPoint = Vector2.new(0, if bottom then 1 else 0),
		Position = UDim2.fromScale(0, if bottom then 1 else 0),
		Size = UDim2.fromOffset(LENGTH, EDGE),
		BackgroundColor3 = BLACK,
		ZIndex = 2,
	}, parent)
	Kit.new("UIGradient", { Transparency = LINE }, edge)
end

-- One arm of the plus: a black bar (its outline, a hair deeper at the foot) or the white bar over it
local function arm(parent: Instance, wide: number, high: number, white: boolean)
	block({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, if white then 0 else 0.25),
		Size = if white then UDim2.fromOffset(wide, high) else UDim2.fromOffset(wide + 2, high + 2.5),
		BackgroundColor3 = if white then Kit.White else BLACK,
		ZIndex = if white then 7 else 6,
	}, parent)
end

-- The green plus button past a bar's end: a black edge, a pale rim, a brighter face, a darker lip along the foot
local function plus(parent: Instance, name: string): TextButton
	local at = UDim2.new(0, PLUS_AT, 0.5, 0)
	local button: TextButton = Kit.new("TextButton", {
		Name = "Plus",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = at,
		Size = UDim2.fromOffset(PLUS, PLUS),
		BackgroundColor3 = BLACK,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Text = "",
		Visible = false,
		ZIndex = 3,
	}, parent)
	Kit.corner(button, 1)
	-- the black edge is a little deeper along the foot
	local rim = block({
		Position = UDim2.fromOffset(EDGE, EDGE),
		Size = UDim2.new(1, -EDGE * 2, 1, -EDGE * 2 - 0.5),
		BackgroundColor3 = Kit.White,
		ZIndex = 4,
	}, button)
	Kit.gradient(rim, RIM[1], RIM[2])
	local face = block({
		Position = UDim2.fromOffset(2.5, 2),
		Size = UDim2.new(1, -5, 1, -4.5),
		BackgroundColor3 = Kit.White,
		ZIndex = 5,
	}, rim)
	Kit.gradient(face, FACE[1], FACE[2])
	block({
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, 2.5),
		BackgroundColor3 = LIP,
		ZIndex = 5,
	}, rim)
	arm(button, 3.5, 10.5, false)
	arm(button, 10.5, 3.5, false)
	arm(button, 3.5, 10.5, true)
	arm(button, 10.5, 3.5, true)
	-- a press dips it; letting go, or sliding off, puts it back
	local function rest()
		button.Position = at
	end
	button.MouseButton1Down:Connect(function()
		button.Position = at + UDim2.fromOffset(0, 1)
	end)
	button.MouseButton1Up:Connect(rest)
	button.MouseLeave:Connect(rest)
	button.Activated:Connect(function()
		pressed:Fire(name)
	end)
	return button
end

local function row(order: number, name: string, sign: (Instance, number) -> Frame, colour: Color3): Row
	local frame: Frame = Kit.new("Frame", {
		Name = name,
		Size = UDim2.fromOffset(WIDTH, HEIGHT),
		BackgroundTransparency = 1,
		LayoutOrder = order,
	}, holder)
	-- the fill runs under the lines, edge to edge: laid beside them, a row that falls between two pixels showed a
	-- pale gap between its fill and its bottom line
	local fill = block({
		Name = "Fill",
		Size = UDim2.fromOffset(LENGTH, HEIGHT),
		BackgroundColor3 = BLACK,
	}, frame)
	Kit.new("UIGradient", { Transparency = FILL }, fill)
	line(frame, false)
	line(frame, true)
	block({
		Name = "Left",
		Size = UDim2.fromOffset(EDGE, HEIGHT),
		BackgroundColor3 = BLACK,
		BackgroundTransparency = 0.13,
		ZIndex = 2,
	}, frame)
	local picture = PICTURE[name]
	local icon: GuiObject = if picture and picture ~= ""
		then Kit.new("ImageLabel", {
			Size = UDim2.fromOffset(PICTURE_SIZE, PICTURE_SIZE),
			BackgroundTransparency = 1,
			Image = picture,
			ScaleType = Enum.ScaleType.Fit,
		}, frame)
		else sign(frame, ICON)
	icon.AnchorPoint = Vector2.new(0.5, 0.5)
	icon.Position = UDim2.new(0, ICON_AT, 0.5, 0)
	icon.ZIndex = 3
	local label: TextLabel = Kit.new("TextLabel", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, TEXT_AT, 0.5, 0),
		Size = UDim2.fromOffset(LENGTH - TEXT_AT, HEIGHT),
		BackgroundTransparency = 1,
		Font = Kit.Font,
		Text = "",
		TextSize = TEXT,
		TextColor3 = colour,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 4,
	}, frame)
	Kit.stroke(label, TEXT_LINE, BLACK)
	return { Frame = frame, Fill = fill, Text = label, Plus = plus(frame, name), Colour = colour }
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
	air = row(1, "Oxygen", Kit.bubble, Kit.White)
	money = row(2, "Coins", Kit.coin, COINS)
	money.Frame.Visible = false
	shownOxygen = -1
	shownLow = false
	shownCoins = -1
	shownDocked = false
	oxygenBeat = Kit.pulse(air.Fill, { BackgroundColor3 = Kit.Danger }, { BackgroundColor3 = HOT })
end

function StatRows.place(touch: boolean)
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
-- on a fish; docked: at the dock, where the plus buttons show. The row is the most you can carry, which a drowning
-- player read as what they had left ("100"), so for that moment it is a 0. Low or spent, the bar is red and beats
function StatRows.update(oxygen: number, coins: number?, spent: boolean, low: boolean, docked: boolean)
	local whole = if spent then 0 else math.floor(oxygen + 0.5)
	if whole ~= shownOxygen then
		shownOxygen = whole
		air.Text.Text = Kit.short(whole)
	end
	local red = low or spent
	if red ~= shownLow then
		shownLow = red
		-- the beat runs from the colour the bar has when it starts, so the red goes on first
		if red then
			air.Fill.BackgroundColor3 = Kit.Danger
		end
		oxygenBeat(red)
		if not red then
			air.Fill.BackgroundColor3 = BLACK
		end
		air.Text.TextColor3 = if red then WARN else air.Colour
	end
	local count = if coins then math.floor(coins) else -1
	if count ~= shownCoins then
		shownCoins = count
		money.Frame.Visible = coins ~= nil
		if coins then
			money.Text.Text = "$" .. Kit.short(count)
		end
	end
	if docked ~= shownDocked then
		shownDocked = docked
		air.Plus.Visible = docked
		money.Plus.Visible = docked
	end
end

return StatRows
