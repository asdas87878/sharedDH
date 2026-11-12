--!strict
-- The jump button at the lower right: the press that is the whole game, so it is the loudest thing on the screen. A
-- chunky disc, yellow going to orange, with slanted motion stripes, a thick dark outline and a shadow; a dark arrow
-- that turns over in the air; on a keyboard the key's name on a key cap over its lower edge, on a phone the word HOP
-- or GRAB under the arrow. In the hop with a fish locked it is aqua (GRAB); with nothing to grab, grey. In the last
-- second on a fish a red ring beats round it.
-- It acts on the press, not the release: the hop is pressed every two or three seconds.
local Kit = require(script.Parent.Kit)

local HopButton = {}

local button: TextButton
local look: Kit.Dressed
local alarm: (on: boolean) -> ()
local arrow: Frame
local arrowParts: { Frame } = {}
local word: TextLabel
local cap: Frame

local shownMode = ""
local shownHot = false
local touch = false

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
		BackgroundTransparency = 1,
		Text = "",
		AutoButtonColor = false,
		Visible = false,
	}, parent)
	local style: Kit.Style = table.clone(Kit.Themes.Action)
	style.Radius = Kit.Radius.Round
	style.Outline = Kit.Outline.Heavy
	style.Shine = true
	-- under the disc: its shadow, and the red ring of the last second (clear until then)
	local shadow = Kit.new("Frame", {
		Position = UDim2.fromOffset(0, 5),
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(4, 10, 22),
		BackgroundTransparency = 0.45,
		ZIndex = 0,
	}, button)
	Kit.corner(shadow, 999)
	Kit.stroke(shadow, Kit.Outline.Heavy, Color3.fromRGB(4, 10, 22), 0.45).ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	local warn = Kit.new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 0 }, button)
	Kit.corner(warn, 999)
	local warnLine = Kit.stroke(warn, Kit.Outline.Heavy + 4, Kit.Coral, 1)
	alarm = Kit.pulse(warnLine, { Transparency = 1 }, { Transparency = 0 })
	local face: Frame = Kit.new("Frame", { Size = UDim2.fromScale(1, 1) }, button)
	look = Kit.dress(face, style)
	Kit.stripes(face, 999)

	arrow = Kit.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.4),
		Size = UDim2.fromOffset(34, 34),
		BackgroundTransparency = 1,
	}, face)
	-- the arrow, dark on the disc: a pointed head, a short stem, and a small bar under them. The head is a square
	-- turned on its corner with its lower half cut away by a gradient, so its edges are clean (it was four bars
	-- stepping in to a point, which read as a little tree)
	local head: Frame = Kit.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(17, 16),
		Size = UDim2.fromOffset(21, 21),
		Rotation = 45,
		BackgroundColor3 = Kit.Ink,
		BorderSizePixel = 0,
	}, arrow)
	Kit.corner(head, 3)
	Kit.new("UIGradient", { Transparency = HEAD, Rotation = 45 }, head)
	arrowParts[1] = head
	arrowParts[2] = Kit.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromOffset(17, 15.6), -- (a hair into the head, so no line shows between them)
		Size = UDim2.fromOffset(12, 8.4),
		BackgroundColor3 = Kit.Ink,
		BorderSizePixel = 0,
	}, arrow)
	arrowParts[3] = Kit.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromOffset(17, 27),
		Size = UDim2.fromOffset(12, 4.5),
		BackgroundColor3 = Kit.Ink,
		BorderSizePixel = 0,
	}, arrow)
	Kit.corner(arrowParts[3], 1)
	word = Kit.text({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0.4, 19),
		Size = UDim2.fromOffset(80, 16),
		Text = "HOP",
		TextSize = 16,
	}, face)

	local key = Kit.panel(button, {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 1, -17),
		Size = UDim2.fromOffset(62, 22),
		Visible = false,
		ZIndex = 2,
	}, Kit.Themes.Key)
	cap = key.Frame
	Kit.new("TextLabel", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Font = Kit.Font,
		Text = "Space",
		TextSize = 13,
		TextColor3 = Kit.Ink,
	}, key.Face)

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
	local theme = if mode == "grab" then Kit.Themes.Grab elseif mode == "off" then Kit.Themes.Off else Kit.Themes.Action
	look.paint(theme.Top, theme.Bottom)
	local faint = if mode == "off" then 0.55 else 0
	for _, part in arrowParts do
		part.BackgroundTransparency = faint
	end
	word.TextTransparency = faint
	alarm(hot)
	if touch then
		word.Visible = true
	end
end

return HopButton
