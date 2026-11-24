--!strict
-- The dock's lines in the middle of the screen, formatted as the reference's deposit (UI review 1, the user,
-- 2026-11-22: "if we have a deposit fish UI, make sure its formatted liek ride a dino"):
--   DockNotes.carrying(on)   "GO TO YOUR TANK TO DEPOSIT" low in the middle while this player carries a catch on the
--                            dock and no window is up (Controllers/StallController asks every look)
--   DockNotes.words(text)    what that line says instead (LessonController; nil: its own words)
--   DockNotes.lesson(text)   the line whether or not they carry anything, with these words (LessonController; nil: not).
--                            Words between stars are yellow (our "go here / press this"), in either.
--   DockNotes.full(line)     a pink "TANK FULL!" pill and one short line under it, popping in (0.17 s), gone after 2 s
--   DockNotes.note(word, line, good)   the same with other words: green (good) or pink
--   DockNotes.goal(text)     a smaller line under the caption's place (Controllers/GoalController; nil: none)
-- (The line over the tank as a fish goes in is UI.TankPrompt's.)
local Players = game:GetService("Players")

local Anim = require(script.Parent.Anim)
local Kit = require(script.Parent.Kit)
local Shop = require(script.Parent.Shop)

local DockNotes = {}

local CARRY = "GO TO YOUR TANK TO DEPOSIT"
local CARRY_AT = 0.686 -- the reference's: the line's middle, down the screen
local FULL_AT = 0.6
local FULL_STAY = 2
local GOAL_AT = 0.755
local PINK = { Color3.fromRGB(255, 120, 190), Color3.fromRGB(226, 52, 140) }
local GREEN = { Color3.fromRGB(150, 236, 92), Color3.fromRGB(44, 174, 62) }

local gui: ScreenGui? = nil
local carry: TextLabel
local full: Frame
local fullLine: TextLabel
local fullPill: Frame
local fullWord: TextLabel
local fullFill: UIGradient
local goal: TextLabel
local goalText: string? = nil
local fullAt = -math.huge
local carryOn = false
local carryWords = CARRY
local lessonWords: string? = nil
local shown = false

local function build()
	local g: ScreenGui = Kit.new("ScreenGui", {
		Name = "DockNotes",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		DisplayOrder = 6,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	}, Players.LocalPlayer:WaitForChild("PlayerGui"))
	local root: Frame = Kit.new("Frame", { Name = "Root", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }, g)
	-- (text in the window's points: as tall as a 720p screen's)
	local scale: UIScale = Kit.new("UIScale", {}, root)
	local function fit()
		local camera = workspace.CurrentCamera
		local s = if camera then math.clamp(camera.ViewportSize.Y / 720, 0.6, 1.5) else 1
		scale.Scale = s
		root.Size = UDim2.fromScale(1 / s, 1 / s)
	end
	fit()
	if workspace.CurrentCamera then
		workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(fit)
	end
	carry = Shop.text(root, {
		Name = "Carry",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, CARRY_AT),
		Size = UDim2.fromOffset(700, 40),
		TextSize = 30,
		Text = "",
		RichText = true,
		Visible = false,
	})
	goal = Shop.text(root, {
		Name = "Goal",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, GOAL_AT),
		Size = UDim2.fromOffset(700, 28),
		TextSize = 21,
		Text = "",
		RichText = true,
		Visible = false,
	})
	full = Kit.new("Frame", {
		Name = "Full",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, FULL_AT),
		Size = UDim2.fromOffset(520, 92),
		BackgroundTransparency = 1,
		Visible = false,
	}, root)
	local pill: Frame = Kit.new("Frame", {
		Name = "Pill",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0),
		Size = UDim2.fromOffset(250, 50),
		BackgroundColor3 = Kit.White,
		BorderSizePixel = 0,
	}, full)
	Kit.corner(pill, 999)
	Kit.stroke(pill, 3, Shop.Edge)
	fullFill = Kit.new("UIGradient", { Rotation = 90, Color = Shop.halves(PINK[1], PINK[2]) }, pill)
	fullPill = pill
	fullWord = Shop.text(pill, { Size = UDim2.fromScale(1, 1), TextSize = 32, Text = "TANK FULL!", ZIndex = 2 })
	fullLine = Shop.text(full, {
		Name = "Line",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(0.5, 1),
		Size = UDim2.new(1, 0, 0, 30),
		TextSize = 24,
		Text = "",
	})
	gui = g
end

-- The one line: the lesson's words first, else the catch's
local function refresh()
	local words = lessonWords or (if carryOn then carryWords else nil)
	if not gui then
		if not words then
			return
		end
		build()
	end
	if words then
		local rich = string.gsub(words, "%*(.-)%*", `<font color="#{Kit.Sun:ToHex()}">%1</font>`)
		local new = carry.Text ~= rich
		carry.Text = rich
		if shown and new then
			Anim.punch(carry, 1.12)
		end
	end
	if shown ~= (words ~= nil) then
		shown = words ~= nil
		if shown and carry.Visible then
			-- (still on its way out: at full size Anim.toast would take it for shown, and let it go)
			Anim.scaleOf(carry).Scale = 0.6
		end
		Anim.toast(carry, shown)
	end
end

function DockNotes.carrying(on: boolean)
	if on == carryOn then
		return
	end
	carryOn = on
	refresh()
end

function DockNotes.lesson(text: string?)
	if text ~= lessonWords then
		lessonWords = text
		refresh()
	end
end

function DockNotes.words(text: string?)
	local words = text or CARRY
	if words == carryWords then
		return
	end
	carryWords = words
	refresh()
end

function DockNotes.goal(text: string?)
	if text == goalText then
		return
	end
	if not gui then
		build()
	end
	local was = goalText
	goalText = text
	if text then
		goal.Text = string.gsub(text, "%*(.-)%*", `<font color="#{Kit.Sun:ToHex()}">%1</font>`)
	end
	if (was == nil) ~= (text == nil) then
		if text and goal.Visible then
			Anim.scaleOf(goal).Scale = 0.6 -- (as the caption: still on its way out)
		end
		Anim.toast(goal, text ~= nil)
	end
end

function DockNotes.full(line: string)
	DockNotes.note("TANK FULL!", line, false)
end

function DockNotes.note(word: string, line: string, good: boolean)
	if not gui then
		build()
	end
	local tones = if good then GREEN else PINK
	fullFill.Color = Shop.halves(tones[1], tones[2])
	fullWord.Text = word
	fullPill.Size = UDim2.fromOffset(math.max(250, 60 + #word * 20), 50)
	fullLine.Text = line
	fullAt = os.clock()
	if full.Visible then
		Anim.punch(full, 1.1)
	else
		Anim.toast(full, true)
	end
	local stamp = fullAt
	task.delay(FULL_STAY, function()
		if fullAt == stamp then
			Anim.toast(full, false)
		end
	end)
end

return DockNotes
