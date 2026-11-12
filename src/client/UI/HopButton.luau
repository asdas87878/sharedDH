--!strict
-- The jump button at the lower right, built as the reference's: a dark see-through circle, a thin pale ring, a pale
-- arrow that turns over in the air, and on a keyboard the key's name on a white cap over its lower edge. Ours: on a
-- phone the word HOP or GRAB sits under the arrow, and the ring goes red in the last second on a fish.
-- It acts on the press, not the release: the hop is pressed every two or three seconds.
local Kit = require(script.Parent.Kit)

local HopButton = {}

local button: TextButton
local ring: UIStroke
local arrow: Frame
local arrowParts: { Frame } = {}
local word: TextLabel
local cap: Frame

local shownMode = ""
local shownHot = false
local touch = false

local PALE = Color3.fromRGB(238, 246, 255)
-- the half of the head's square that shows: the corner that points up, down to the line between its two side corners
local HEAD = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 0),
	NumberSequenceKeypoint.new(0.5, 0),
	NumberSequenceKeypoint.new(0.501, 1),
	NumberSequenceKeypoint.new(1, 1),
})

function HopButton.build(parent: Instance, press: () -> ())
	button = Kit.new("TextButton", {
		Name = "HopButton",
		AnchorPoint = Vector2.new(1, 1),
		Size = UDim2.fromOffset(92, 92),
		BackgroundColor3 = Kit.Deep,
		BackgroundTransparency = 0.5,
		Text = "",
		AutoButtonColor = false,
		Visible = false,
	}, parent)
	Kit.corner(button, 999)
	ring = Kit.stroke(button, 3, Kit.White, 0.58)
	ring.ApplyStrokeMode = Enum.ApplyStrokeMode.Border

	arrow = Kit.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.4),
		Size = UDim2.fromOffset(34, 34),
		BackgroundTransparency = 1,
	}, button)
	-- the arrow, as the reference's: a pointed head, a short stem, and a small bar under them. The head is a square
	-- turned on its corner with its lower half cut away by a gradient, so its edges are clean (it was four bars
	-- stepping in to a point, which read as a little tree)
	local head: Frame = Kit.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(17, 16),
		Size = UDim2.fromOffset(21, 21),
		Rotation = 45,
		BackgroundColor3 = PALE,
		BackgroundTransparency = 0.14,
		BorderSizePixel = 0,
	}, arrow)
	Kit.corner(head, 3)
	Kit.new("UIGradient", { Transparency = HEAD, Rotation = 45 }, head)
	arrowParts[1] = head
	arrowParts[2] = Kit.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromOffset(17, 15.6), -- (a hair into the head, so no line shows between them)
		Size = UDim2.fromOffset(12, 8.4),
		BackgroundColor3 = PALE,
		BackgroundTransparency = 0.14,
		BorderSizePixel = 0,
	}, arrow)
	arrowParts[3] = Kit.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromOffset(17, 27),
		Size = UDim2.fromOffset(12, 4.5),
		BackgroundColor3 = PALE,
		BackgroundTransparency = 0.14,
		BorderSizePixel = 0,
	}, arrow)
	Kit.corner(arrowParts[3], 1)
	word = Kit.new("TextLabel", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0.4, 19),
		Size = UDim2.fromOffset(80, 16),
		BackgroundTransparency = 1,
		Font = Kit.Font,
		Text = "HOP",
		TextSize = 15,
		TextColor3 = PALE,
		TextTransparency = 0.14,
	}, button)

	cap = Kit.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 1, -17),
		Size = UDim2.fromOffset(62, 22),
		BackgroundColor3 = Kit.White,
		Visible = false,
	}, button)
	Kit.corner(cap, 8)
	Kit.stroke(cap, 2.2, Kit.Ink)
	Kit.shade(cap)
	Kit.new("TextLabel", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Font = Kit.Font,
		Text = "Space",
		TextSize = 13,
		TextColor3 = Kit.Ink,
	}, cap)

	button.InputBegan:Connect(function(input: InputObject)
		if
			input.UserInputType == Enum.UserInputType.Touch
			or input.UserInputType == Enum.UserInputType.MouseButton1
		then
			press()
		end
	end)
end

function HopButton.place(onTouch: boolean)
	touch = onTouch
	if onTouch then
		button.Size = UDim2.fromOffset(92, 92)
		button.Position = UDim2.new(1, -14, 1, -18)
		arrow.Position = UDim2.fromScale(0.5, 0.4)
	else
		button.Size = UDim2.fromOffset(78, 78)
		button.Position = UDim2.new(1, -54, 1, -54)
		arrow.Position = UDim2.fromScale(0.5, 0.46)
	end
	word.Visible = onTouch
	cap.Visible = not onTouch
end

function HopButton.hide()
	button.Visible = false
end

-- mode: "hop" (on a fish or floating), "grab" (in the hop with a fish locked), "off" (nothing to press for)
-- hot: the last second on a fish
function HopButton.update(mode: string, hot: boolean)
	button.Visible = true
	if mode == shownMode and hot == shownHot then
		return
	end
	shownMode = mode
	shownHot = hot
	arrow.Rotation = if mode == "grab" then 180 else 0
	word.Text = if mode == "grab" then "GRAB" else "HOP"
	local colour = if hot then Kit.Sun else PALE
	local faint = if mode == "off" then 0.65 else 0.14
	for _, part in arrowParts do
		part.BackgroundColor3 = colour
		part.BackgroundTransparency = faint
	end
	word.TextColor3 = colour
	word.TextTransparency = faint
	if hot then
		ring.Color = Kit.Coral
		ring.Transparency = 0
		ring.Thickness = 4
	elseif mode == "grab" then
		ring.Color = Color3.fromRGB(130, 232, 255)
		ring.Transparency = 0.15
		ring.Thickness = 3
	else
		ring.Color = Kit.White
		ring.Transparency = 0.58
		ring.Thickness = 3
	end
	if touch then
		word.Visible = true
	end
end

return HopButton
