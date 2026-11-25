--!strict
-- What the lesson puts by a button (docs/design/first-minutes.md; Controllers/LessonController decides when):
--   LessonPrompt.point(button, text)  a yellow arrow bobbing over it and a few words over the arrow (nil: neither), in
--                                     the HUD's own lettering, right edge with the screen's (the hop button's corner:
--                                     nothing else is above it). Words between stars are yellow
--   LessonPrompt.ring(button, on)     a yellow ring beating round it, for a button inside a window, where an arrow
--                                     would cover what is above it
--   LessonPrompt.arrow(button, from)  the arrow alone, bobbing at the button's "Right" or "Left" (pointing at it):
--                                     gives back what shows and hides it
-- Nothing is built until the first call that shows something.
local Kit = require(script.Parent.Kit)
local Shop = require(script.Parent.Shop)

local LessonPrompt = {}

local ARROW = 40 -- the arrow's size, points
local REST, RISE = 12, 12 -- it bobs from this far over the button, this much further
local WORDS = 24 -- the words' size
local MARGIN = 14 -- their right edge, from the screen's

-- A chunky yellow arrow pointing down, dark round it, `size` points wide: a head (a square on its corner, its upper half
-- cut away) and a stem
local HEAD = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 1),
	NumberSequenceKeypoint.new(0.499, 1),
	NumberSequenceKeypoint.new(0.5, 0),
	NumberSequenceKeypoint.new(1, 0),
})

local function shape(parent: Instance, size: number): Frame
	local holder: Frame = Kit.new("Frame", {
		Name = "LessonArrow",
		Size = UDim2.fromOffset(size, size),
		BackgroundTransparency = 1,
	}, parent)
	local function piece(grow: number, colour: Color3, z: number)
		local stem: Frame = Kit.new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, -grow),
			Size = UDim2.new(0.4, grow * 2, 0.56, grow * 2),
			BackgroundColor3 = colour,
			BorderSizePixel = 0,
			ZIndex = z,
		}, holder)
		Kit.corner(stem, 3)
		-- (a square on its corner, its lower half: as wide as 1.41 of its side; the dark one a little higher, so it
		-- shows along the head's shoulders too)
		local side = size * 0.68 + grow * 3.4
		local head: Frame = Kit.new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, 0, 0.48, -grow),
			Size = UDim2.fromOffset(side, side),
			Rotation = 45,
			BackgroundColor3 = colour,
			BorderSizePixel = 0,
			ZIndex = z,
		}, holder)
		Kit.corner(head, 3)
		Kit.new("UIGradient", { Transparency = HEAD, Rotation = 45 }, head)
	end
	piece(math.max(size * 0.07, 2.5), Kit.Ink, 1)
	piece(0, Kit.Sun, 2)
	return holder
end

type Point = { Arrow: Frame, Words: TextLabel, Bob: (on: boolean) -> () }
local points: { [GuiObject]: Point } = {}
local rings: { [GuiObject]: { Ring: Frame, Beat: (on: boolean) -> () } } = {}

function LessonPrompt.point(button: GuiObject?, text: string?)
	if not button then
		return
	end
	local p = points[button]
	if not p then
		if not text then
			return
		end
		local arrow = shape(button, ARROW)
		arrow.AnchorPoint = Vector2.new(0.5, 1)
		arrow.Position = UDim2.new(0.5, 0, 0, -REST)
		arrow.ZIndex = 20
		local words = Shop.text(button, {
			Name = "LessonWords",
			AnchorPoint = Vector2.new(1, 1),
			Size = UDim2.fromOffset(0, WORDS + 4),
			AutomaticSize = Enum.AutomaticSize.X,
			TextXAlignment = Enum.TextXAlignment.Right,
			TextSize = WORDS,
			RichText = true,
			ZIndex = 20,
		})
		local bob = Kit.pulse(
			arrow,
			{ Position = UDim2.new(0.5, 0, 0, -REST) },
			{ Position = UDim2.new(0.5, 0, 0, -REST - RISE) },
			0.35
		)
		p = { Arrow = arrow, Words = words, Bob = bob }
		points[button] = p
		button.Destroying:Connect(function()
			points[button] = nil
		end)
	end
	if text then
		p.Words.Text = string.gsub(text, "%*(.-)%*", `<font color="#{Kit.Sun:ToHex()}">%1</font>`)
		-- (the button stands in from the screen's edge, another distance on a phone)
		p.Words.Position = UDim2.new(1, -button.Position.X.Offset - MARGIN, 0, -REST - RISE - ARROW - 8)
	end
	p.Arrow.Visible = text ~= nil
	p.Words.Visible = text ~= nil
	p.Bob(text ~= nil)
end

function LessonPrompt.arrow(button: GuiObject, from: string): (on: boolean) -> ()
	local made: Frame? = nil
	local bob: (on: boolean) -> ()
	return function(on: boolean)
		if not made then
			if not on then
				return
			end
			local arrow = shape(button, ARROW)
			arrow.AnchorPoint = Vector2.new(0.5, 0.5)
			arrow.ZIndex = 30
			local right = from == "Right"
			arrow.Rotation = if right then 90 else -90
			local function at(off: number): UDim2
				off += ARROW / 2
				return if right then UDim2.new(1, off, 0.5, 0) else UDim2.new(0, -off, 0.5, 0)
			end
			arrow.Position = at(REST)
			bob = Kit.pulse(arrow, { Position = at(REST) }, { Position = at(REST + RISE) }, 0.35)
			made = arrow
		end
		local arrow = made :: Frame
		arrow.Visible = on
		bob(on)
	end
end

function LessonPrompt.ring(button: GuiObject?, on: boolean)
	if not button then
		return
	end
	local r = rings[button]
	if not r then
		if not on then
			return
		end
		local ring: Frame = Kit.new("Frame", {
			Name = "LessonRing",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.new(1, 8, 1, 8),
			BackgroundTransparency = 1,
			ZIndex = 20,
		}, button)
		Kit.corner(ring, 10)
		local line = Kit.stroke(ring, 4, Kit.Sun, 0)
		line.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		r = { Ring = ring, Beat = Kit.pulse(line, { Transparency = 0 }, { Transparency = 0.75 }, 0.4) }
		rings[button] = r
		button.Destroying:Connect(function()
			rings[button] = nil
		end)
	end
	r.Ring.Visible = on
	r.Beat(on)
end

-- All of it off (the lesson is over)
function LessonPrompt.clear()
	for button in points do
		LessonPrompt.point(button, nil)
	end
	for button in rings do
		LessonPrompt.ring(button, false)
	end
end

return LessonPrompt
