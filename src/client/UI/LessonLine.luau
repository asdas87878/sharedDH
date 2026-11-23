--!strict
-- The lesson's words (docs/design/first-minutes.md; Controllers/LessonController decides what they say): one line under
-- the land strip, with its key words in yellow (our "go here / press this"), and the goal bar under it (aqua, as all
-- Oxygen is). And the arrow that bobs by a button: LessonLine.arrow(button, ...) puts one on a button, and
-- LessonLine.note a white plate beside one.
-- Nothing is built until the first call that shows something.
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local Anim = require(script.Parent.Anim)
local Kit = require(script.Parent.Kit)
local Shop = require(script.Parent.Shop)

local LessonLine = {}

local LINE_AT = 0.2 -- the line's middle, down the screen, when there is no land strip to go by
local UNDER = 0.3 -- it is this much of the land strip's height under it (the metres and the best hang there)
local BAR_WIDE, BAR_HIGH = 340, 26

local built = false
local root: Frame
local scale: UIScale
local line: TextLabel
local bar: Frame
local barFill: Frame
local barWords: TextLabel
local barTick: TextLabel
local strip: GuiObject? = nil -- the land strip
local stripLookAt = 0
local lineAt = 0 -- the line's middle, in the root's points
local shownText = ""
local shownGoal = ""
local shownShare = -1

local function build()
	built = true
	local gui: ScreenGui = Kit.new("ScreenGui", {
		Name = "Lesson",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		DisplayOrder = 6,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	}, Players.LocalPlayer:WaitForChild("PlayerGui"))
	root = Kit.new("Frame", {
		Name = "Root",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
	}, gui)
	-- (the dock's notes' own points: as tall as a 720p screen's, and never wider than the screen)
	scale = Kit.new("UIScale", {}, root)
	local function fit()
		local camera = workspace.CurrentCamera
		local size = if camera then camera.ViewportSize else Vector2.new(1280, 720)
		local s = math.clamp(math.min(size.Y / 720, size.X / 760), 0.55, 1.5)
		scale.Scale = s
		root.Size = UDim2.fromScale(1 / s, 1 / s)
	end
	fit()
	if workspace.CurrentCamera then
		workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(fit)
	end
	line = Shop.text(root, {
		Name = "Line",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, LINE_AT),
		Size = UDim2.fromOffset(740, 40),
		TextSize = 32,
		RichText = true,
		Visible = false,
	})
	bar = Kit.new("Frame", {
		Name = "Goal",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, LINE_AT, 26),
		Size = UDim2.fromOffset(BAR_WIDE, BAR_HIGH),
		BackgroundColor3 = Kit.Deep,
		BorderSizePixel = 0,
		Visible = false,
	}, root)
	Kit.corner(bar, 999)
	Kit.stroke(bar, 3, Shop.Edge)
	barFill = Kit.new("Frame", {
		Name = "Fill",
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = Kit.White,
		BorderSizePixel = 0,
	}, bar)
	Kit.corner(barFill, 999)
	Kit.gradient(barFill, Kit.lighter(Kit.Aqua, 0.15), Kit.darker(Kit.Aqua, 0.25))
	barWords = Shop.text(bar, {
		Name = "Words",
		Size = UDim2.fromScale(1, 1),
		TextSize = 18,
		ZIndex = 2,
	})
	barTick = Shop.text(bar, {
		Name = "Done",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(1, 8, 0.5, 0),
		Size = UDim2.fromOffset(28, 28),
		TextSize = 26,
		Text = "✓",
		TextColor3 = Kit.Good,
		Visible = false,
	})
end

-- The line and the bar under the land strip, wherever it is on this screen (a phone's is bigger)
local function place()
	local player = Players.LocalPlayer
	if not (strip and strip:IsDescendantOf(player)) and os.clock() >= stripLookAt then
		stripLookAt = os.clock() + 1
		local gui = player:FindFirstChildOfClass("PlayerGui")
		local found = gui and gui:FindFirstChild("LandStrip", true)
		strip = if found and found:IsA("GuiObject") then found else nil
	end
	local s = math.max(scale.Scale, 0.01)
	local y = LINE_AT * root.AbsoluteSize.Y / s
	if strip and strip.AbsoluteSize.Y > 0 then
		local bottom = strip.AbsolutePosition.Y + strip.AbsoluteSize.Y * (1 + UNDER) - root.AbsolutePosition.Y
		y = bottom / s + 20
	end
	if math.abs(y - lineAt) > 0.5 then
		lineAt = y
		line.Position = UDim2.new(0.5, 0, 0, y)
		bar.Position = UDim2.new(0.5, 0, 0, y + 26)
	end
end

-- The foot of the bar, down the screen, pixels (LessonPointer's marker stays below it)
function LessonLine.foot(): number
	return if built then (lineAt + 26 + BAR_HIGH) * scale.Scale else 0
end

-- The line ("" or nil: none). Words between stars are yellow: "*DIVE IN!* Catch your first fish"
function LessonLine.say(text: string?)
	local words = text or ""
	if built and words ~= "" then
		place()
	end
	if words == shownText then
		return
	end
	shownText = words
	if not built then
		if words == "" then
			return
		end
		build()
		place()
	end
	if words == "" then
		Anim.toast(line, false)
		return
	end
	local rich = string.gsub(words, "%*(.-)%*", `<font color="#{Kit.Sun:ToHex()}">%1</font>`)
	line.Text = rich
	if line.Visible then
		Anim.toast(line, true) -- (in case it was on its way out)
		Anim.punch(line, 1.12)
	else
		Anim.toast(line, true)
	end
end

-- The goal bar: its words ("" or nil: no bar) and how full it is, 0 to 1 (1: ticked)
function LessonLine.goal(text: string?, share: number)
	local words = text or ""
	share = math.clamp(share, 0, 1)
	if words == shownGoal and (words == "" or math.abs(share - shownShare) < 0.002) then
		return
	end
	local was = shownGoal
	shownGoal = words
	if not built then
		if words == "" then
			return
		end
		build()
		place()
	end
	if words == "" then
		Anim.toast(bar, false)
		return
	end
	barWords.Text = words
	if share ~= shownShare then
		shownShare = share
		barFill.Visible = share > 0.01
		TweenService:Create(barFill, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Size = UDim2.fromScale(math.max(share, BAR_HIGH / BAR_WIDE), 1),
		}):Play()
		barTick.Visible = share >= 1
	end
	if was == "" then
		Anim.toast(bar, true)
	end
end

-- A chunky yellow arrow pointing down, dark round it, `size` points wide: a head (a square on its corner, its upper half
-- cut away) and a stem
local HEAD = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 1),
	NumberSequenceKeypoint.new(0.499, 1),
	NumberSequenceKeypoint.new(0.5, 0),
	NumberSequenceKeypoint.new(1, 0),
})

function LessonLine.shape(parent: Instance, size: number): Frame
	local holder: Frame = Kit.new("Frame", {
		Name = "Arrow",
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
		-- (a square on its corner, its lower half: as wide as 1.41 of its side)
		-- (the dark one a little higher, so it shows along the head's shoulders too)
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

-- The arrow over a button, bobbing (made once for each button; off: hidden)
local arrows: { [GuiObject]: { Frame: Frame, Bob: (on: boolean) -> () } } = {}

function LessonLine.arrow(button: GuiObject?, on: boolean)
	if not button then
		return
	end
	local a = arrows[button]
	if not a then
		if not on then
			return
		end
		local frame = LessonLine.shape(button, 44)
		frame.Name = "LessonArrow"
		frame.AnchorPoint = Vector2.new(0.5, 1)
		frame.Position = UDim2.new(0.5, 0, 0, -8)
		frame.ZIndex = 20
		a = {
			Frame = frame,
			Bob = Kit.pulse(
				frame,
				{ Position = UDim2.new(0.5, 0, 0, -8) },
				{ Position = UDim2.new(0.5, 0, 0, -22) },
				0.35
			),
		}
		arrows[button] = a
		button.Destroying:Connect(function()
			arrows[button] = nil
		end)
	end
	a.Frame.Visible = on
	a.Bob(on)
end

-- A white plate to the left of a button, with a few words (nil: none)
local notes: { [GuiObject]: { Frame: Frame, Label: TextLabel } } = {}

function LessonLine.note(button: GuiObject?, text: string?)
	if not button then
		return
	end
	local n = notes[button]
	if not n then
		if not text then
			return
		end
		local frame: Frame = Kit.new("Frame", {
			Name = "LessonNote",
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(0, -16, 0.5, 0),
			Size = UDim2.fromOffset(0, 38),
			AutomaticSize = Enum.AutomaticSize.X,
			BackgroundColor3 = Kit.White,
			BorderSizePixel = 0,
			Visible = false,
			ZIndex = 20,
		}, button)
		Kit.corner(frame, Kit.Radius.Plate)
		Kit.stroke(frame, 3, Kit.Ink)
		Kit.new("UIPadding", { PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12) }, frame)
		local label: TextLabel = Kit.new("TextLabel", {
			Size = UDim2.fromScale(0, 1),
			AutomaticSize = Enum.AutomaticSize.X,
			BackgroundTransparency = 1,
			Font = Kit.Font,
			TextSize = 20,
			TextColor3 = Kit.Ink,
			Text = "",
			ZIndex = 21,
		}, frame)
		n = { Frame = frame, Label = label }
		notes[button] = n
		button.Destroying:Connect(function()
			notes[button] = nil
		end)
	end
	if text and n.Label.Text ~= text then
		n.Label.Text = text
	end
	n.Frame.Visible = text ~= nil
end

-- All of it off (the lesson is over)
function LessonLine.clear()
	LessonLine.say(nil)
	LessonLine.goal(nil, 0)
	for button in arrows do
		LessonLine.arrow(button, false)
	end
	for button in notes do
		LessonLine.note(button, nil)
	end
end

return LessonLine
