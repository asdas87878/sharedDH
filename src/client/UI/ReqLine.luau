--!strict
-- "Required: n" and the O2 picture, the last line of a fish's tag (A3 of docs/attachments/text-options-2026-11-25.png, Hugo's
-- pick, its outline turned down: Config.ReqLine): the number bigger than its word and shaded green (can hold), yellow or
-- red (too strong), a hard shadow under the letters, on no plate.
--   local line = ReqLine.new(parent, order)   line.Row, as wide as what is on it
--   line.set(text)      the number
--   line.state(n)       1 can hold, 2 short, 3 too strong
--   line.word(on)       the whole line, or the number and the picture only (a far fish)
--   line.shake()        the number shakes once (Config.ReqLine.Shake)
--   ReqLine.wide(text, whole)   the room it takes
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextService = game:GetService("TextService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Kit = require(script.Parent.Kit)

local ReqLine = {}

ReqLine.High = 22
local GAP = 5
local WORD = "Required:"
local FILLS = {
	ColorSequence.new(Color3.fromRGB(216, 255, 190), Color3.fromRGB(95, 220, 60)),
	ColorSequence.new(Color3.fromRGB(255, 243, 168), Color3.fromRGB(255, 168, 28)),
	ColorSequence.new(Color3.fromRGB(255, 201, 192), Color3.fromRGB(255, 74, 80)),
}

export type ReqLine = {
	Row: Frame,
	set: (text: string) -> (),
	state: (n: number) -> (),
	word: (on: boolean) -> (),
	shake: () -> (),
}

-- Letters over their own hard shadow: the shadow is the piece that has its place in the line
local function letters(
	parent: Instance,
	size: number,
	stroke: number,
	drop: number,
	order: number
): (TextLabel, TextLabel)
	local under = Kit.text({
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, ReqLine.High),
		TextSize = size,
		TextColor3 = Kit.Ink,
		LayoutOrder = order,
	}, parent, stroke)
	local over = Kit.text({
		Position = UDim2.fromOffset(0, -drop),
		Size = UDim2.fromScale(1, 1),
		TextSize = size,
	}, under, stroke)
	return over, under
end

function ReqLine.new(parent: Instance, order: number): ReqLine
	local c = Config.ReqLine
	local row: Frame = Kit.new("Frame", {
		Name = "Required",
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, ReqLine.High),
		BackgroundTransparency = 1,
		LayoutOrder = order,
	}, parent)
	Kit.new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, GAP),
	}, row)
	local word, wordUnder = letters(row, c.Word, c.WordStroke * c.Stroke, c.WordDrop * c.Stroke, 1)
	word.Text, wordUnder.Text = WORD, WORD
	local number, numberUnder = letters(row, c.Number, c.NumberStroke * c.Stroke, c.NumberDrop * c.Stroke, 2)
	local fill: UIGradient = Kit.new("UIGradient", { Rotation = 90, Color = FILLS[1] }, number)
	Kit.new("ImageLabel", {
		Size = UDim2.fromOffset(c.Picture, c.Picture),
		BackgroundTransparency = 1,
		Image = Kit.Textures.Oxygen,
		LayoutOrder = 3,
	}, row)
	return {
		Row = row,
		set = function(text: string)
			numberUnder.Text = text
			number.Text = text
		end,
		state = function(n: number)
			fill.Color = FILLS[n] or FILLS[1]
		end,
		word = function(on: boolean)
			wordUnder.Visible = on
		end,
		shake = function()
			if c.Shake <= 0 then
				return
			end
			numberUnder.Rotation = -c.Shake
			local t = TweenService:Create(
				numberUnder,
				TweenInfo.new(0.06, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, 4, true),
				{ Rotation = c.Shake }
			)
			t.Completed:Connect(function()
				numberUnder.Rotation = 0
			end)
			t:Play()
		end,
	}
end

local wordWide = 0 -- the word at its size, measured once
function ReqLine.wide(text: string, whole: boolean): number
	local c = Config.ReqLine
	if wordWide == 0 then
		wordWide = TextService:GetTextSize(WORD, c.Word, Kit.Font, Vector2.new(1000, 100)).X
	end
	local number = TextService:GetTextSize(text, c.Number, Kit.Font, Vector2.new(1000, 100)).X
	return number + GAP + c.Picture + (if whole then wordWide + GAP else 0)
end

return ReqLine
