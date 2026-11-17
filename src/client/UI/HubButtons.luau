--!strict
-- The dock's two buttons, at the middle of the screen's left edge where the reference has its own at its hub (the
-- user, 2026-11-17: "Now recreate the index and shop buttons"): Shop over Index. Sizes, places and colours are measured
-- off the user's recording of the reference (0.78 of a unit here to its pixel at 720 high): a bright plate 147 by 48
-- with a black edge and a dark line inside it, paler at the top, a darker lip along the foot, a slanted band of
-- stronger colour toward the right, a faint pattern, a picture at the left, the word in white with a black outline, and
-- on the Index a round red "!" when there is something new in it.
-- Ours, not the reference's: the pattern is our stud tile, and the two pictures are drawn here from frames (a bag and a
-- book) until there are painted ones.
-- They show at the dock only. Neither opens anything yet: a press dips the button and fires Pressed.
local Kit = require(script.Parent.Kit)

local HubButtons = {}

local pressed = Instance.new("BindableEvent")
-- Fired with "Shop" or "Index" when that button is pressed. Nothing listens yet: the panels are not built
HubButtons.Pressed = pressed.Event

local WIDTH = 147
local HEIGHT = 48
local GAP = 8.5
local LEFT = 10 -- as the stat rows'
local DOWN = 4 -- the pair's middle sits a hair under the screen's
local EDGE = 1.5
local ICON_AT = 25 -- the picture's middle, from the button's left edge
local WORD_AT = 0.62 -- the word's middle, across the button
local WORD = 16.5
local MARK = 23
local ON_TOUCH = 0.85

local BLACK = Color3.new(0, 0, 0)
-- The slanted band: where it starts and ends along a line turned SLANT degrees, and how see-through it is
local SLANT = 31
local BAND = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 1),
	NumberSequenceKeypoint.new(0.763, 1),
	NumberSequenceKeypoint.new(0.768, 0.5),
	NumberSequenceKeypoint.new(0.994, 0.5),
	NumberSequenceKeypoint.new(1, 1),
})

type Look = { Top: Color3, Bottom: Color3, Lip: Color3, Band: Color3 }
local SHOP: Look = {
	Top = Color3.fromRGB(244, 148, 162),
	Bottom = Color3.fromRGB(230, 91, 117),
	Lip = Color3.fromRGB(192, 59, 88),
	Band = Color3.fromRGB(222, 0, 45),
}
local INDEX: Look = {
	Top = Color3.fromRGB(164, 199, 247),
	Bottom = Color3.fromRGB(117, 161, 224),
	Lip = Color3.fromRGB(88, 122, 179),
	Band = Color3.fromRGB(20, 85, 215),
}

local holder: Frame
local size: UIScale
local mark: Frame
local shown = false

local function block(props: { [string]: any }, parent: Instance): Frame
	props.BorderSizePixel = 0
	return Kit.new("Frame", props, parent)
end

-- The Shop's picture: a bag with a handle
local function bag(parent: Instance)
	local handle = block({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 2),
		Size = UDim2.fromOffset(15, 16),
		BackgroundTransparency = 1,
	}, parent)
	Kit.corner(handle, 7)
	Kit.stroke(handle, 4.6, BLACK)
	local grip = block({ Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 2 }, handle)
	Kit.corner(grip, 7)
	Kit.stroke(grip, 2, Color3.fromRGB(158, 178, 202))
	local body = block({
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -2),
		Size = UDim2.fromOffset(25, 20),
		BackgroundColor3 = Kit.White,
		ZIndex = 3,
	}, parent)
	Kit.corner(body, 3)
	Kit.stroke(body, EDGE, BLACK)
	Kit.gradient(body, Color3.fromRGB(240, 62, 112), Color3.fromRGB(198, 22, 72))
	local lip = block({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 1, -24),
		Size = UDim2.fromOffset(29, 6),
		BackgroundColor3 = Color3.fromRGB(252, 104, 142),
		ZIndex = 4,
	}, parent)
	Kit.corner(lip, 2)
	Kit.stroke(lip, EDGE, BLACK)
end

-- The Index's picture: a book with a marker
local function book(parent: Instance)
	local cover = block({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(24, 30),
		BackgroundColor3 = Kit.White,
	}, parent)
	Kit.corner(cover, 2.5)
	Kit.stroke(cover, EDGE, BLACK)
	Kit.gradient(cover, Color3.fromRGB(52, 124, 232), Color3.fromRGB(26, 82, 200))
	local panel = block({
		Position = UDim2.fromOffset(5, 4),
		Size = UDim2.fromOffset(14, 10),
		BackgroundColor3 = Color3.fromRGB(150, 200, 250),
		ZIndex = 2,
	}, cover)
	Kit.corner(panel, 1)
	block({
		Position = UDim2.fromOffset(5, 17),
		Size = UDim2.fromOffset(14, 1.5),
		BackgroundColor3 = Color3.fromRGB(150, 200, 250),
		ZIndex = 2,
	}, cover)
	block({
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 2, 1, -2),
		Size = UDim2.new(1, -2, 0, 3.5),
		BackgroundColor3 = Color3.fromRGB(236, 242, 252),
		ZIndex = 2,
	}, cover)
	local marker = block({
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 14, 1, 3),
		Size = UDim2.fromOffset(4.5, 9),
		BackgroundColor3 = Color3.fromRGB(226, 52, 84),
		ZIndex = 3,
	}, cover)
	Kit.stroke(marker, 1, BLACK)
end

local function button(order: number, name: string, look: Look, picture: (Instance) -> (), turn: number): TextButton
	local plate: TextButton = Kit.new("TextButton", {
		Name = name,
		Size = UDim2.fromOffset(WIDTH, HEIGHT),
		BackgroundColor3 = BLACK,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Text = "",
		LayoutOrder = order,
	}, holder)
	Kit.corner(plate, 1)
	local face = block({
		Position = UDim2.fromOffset(EDGE, EDGE),
		Size = UDim2.new(1, -EDGE * 2, 1, -EDGE * 2),
		BackgroundColor3 = Kit.White,
		ZIndex = 2,
	}, plate)
	Kit.gradient(face, look.Top, look.Bottom)
	Kit.new("ImageLabel", {
		Name = "Pattern",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Image = Kit.Textures.Studs,
		ImageTransparency = 0.8,
		ScaleType = Enum.ScaleType.Tile,
		TileSize = UDim2.fromOffset(15, 15),
		ZIndex = 3,
	}, face)
	local band = block({ Name = "Band", Size = UDim2.fromScale(1, 1), BackgroundColor3 = look.Band, ZIndex = 4 }, face)
	Kit.new("UIGradient", { Transparency = BAND, Rotation = SLANT }, band)
	block({
		Name = "Lip",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, 2),
		BackgroundColor3 = look.Lip,
		ZIndex = 5,
	}, face)
	-- the dark line just inside the black edge
	local inner = block({
		Position = UDim2.fromOffset(EDGE, EDGE),
		Size = UDim2.new(1, -EDGE * 2, 1, -EDGE * 2),
		BackgroundTransparency = 1,
		ZIndex = 6,
	}, face)
	local rim = Kit.stroke(inner, EDGE, BLACK, 0.76)
	rim.LineJoinMode = Enum.LineJoinMode.Miter
	local sign = block({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0, ICON_AT, 0.5, 0),
		Size = UDim2.fromOffset(36, 36),
		BackgroundTransparency = 1,
		Rotation = turn,
		ZIndex = 7,
	}, plate)
	picture(sign)
	local word: TextLabel = Kit.new("TextLabel", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(WORD_AT, 0.5),
		Size = UDim2.fromOffset(80, HEIGHT),
		BackgroundTransparency = 1,
		Font = Kit.Font,
		Text = name,
		TextSize = WORD,
		TextColor3 = Kit.White,
		ZIndex = 8,
	}, plate)
	Kit.stroke(word, 1.4, BLACK)
	-- a press dips it; letting go, or sliding off, puts it back
	local function rest()
		face.Position = UDim2.fromOffset(EDGE, EDGE)
	end
	plate.MouseButton1Down:Connect(function()
		face.Position = UDim2.fromOffset(EDGE, EDGE + 1)
	end)
	plate.MouseButton1Up:Connect(rest)
	plate.MouseLeave:Connect(rest)
	plate.Activated:Connect(function()
		pressed:Fire(name)
	end)
	return plate
end

function HubButtons.build(parent: Instance)
	holder = Kit.new("Frame", {
		Name = "HubButtons",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, LEFT, 0.5, DOWN),
		Size = UDim2.fromOffset(WIDTH, HEIGHT * 2 + GAP),
		BackgroundTransparency = 1,
		Visible = false,
	}, parent)
	size = Kit.new("UIScale", {}, holder)
	Kit.new("UIListLayout", { Padding = UDim.new(0, GAP), SortOrder = Enum.SortOrder.LayoutOrder }, holder)
	button(1, "Shop", SHOP, bag, -6)
	local index = button(2, "Index", INDEX, book, -16)
	shown = false

	-- the red "!" on the Index's upper right corner: a dark edge, a white ring, a red disc
	mark = block({
		Name = "Mark",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(1, -9, 0, -4.5),
		Size = UDim2.fromOffset(MARK, MARK),
		BackgroundColor3 = Color3.fromRGB(24, 12, 12),
		Visible = false,
		ZIndex = 10,
	}, index)
	Kit.corner(mark, 999)
	local ring = block({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(1, -2, 1, -2),
		BackgroundColor3 = Kit.White,
		ZIndex = 11,
	}, mark)
	Kit.corner(ring, 999)
	local disc = block({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(1, -3.5, 1, -3.5),
		BackgroundColor3 = Kit.White,
		ZIndex = 12,
	}, ring)
	Kit.corner(disc, 999)
	Kit.gradient(disc, Color3.fromRGB(226, 70, 76), Color3.fromRGB(188, 30, 46))
	local bang: TextLabel = Kit.new("TextLabel", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Font = Kit.Font,
		Text = "!",
		TextSize = 15,
		TextColor3 = Kit.White,
		Rotation = 8,
		ZIndex = 13,
	}, disc)
	Kit.stroke(bang, 1.2, BLACK)

	-- looking in the Index is what takes its mark off
	HubButtons.Pressed:Connect(function(name: string)
		if name == "Index" then
			mark.Visible = false
		end
	end)
end

function HubButtons.place(touch: boolean)
	size.Scale = if touch then ON_TOUCH else 1
end

-- docked: at the dock, the only place the two buttons show
function HubButtons.update(docked: boolean)
	if docked ~= shown then
		shown = docked
		holder.Visible = docked
	end
end

-- Something new is in the Index (a kind caught for the first time): its red "!" goes up until the Index is pressed
function HubButtons.mark(on: boolean)
	mark.Visible = on
end

return HubButtons
