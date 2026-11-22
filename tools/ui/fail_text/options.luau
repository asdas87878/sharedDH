-- Fail-text options (task o2, 2026-11-22; Hugo: "make text better and more stylised when failing a run"). A test
-- ScreenGui in CoreGui (Edit mode; never in the game): one option, every fail line, each at the size it would have in
-- play, over the map dimmed as the fail's fade dims it. Run by tools/ui/fail_text/capture.py through studio-runner:
--   OPTION = 1..6 builds that option; OPTION = 0 removes the test UI.
-- Nothing here is game code: the live words are still Banners.miss.
local OPTION = 1
local DIM = 0.42

local CoreGui = game:GetService("CoreGui")
local TextService = game:GetService("TextService")

local old = CoreGui:FindFirstChild("FailTextTest")
if old then
	old:Destroy()
end
if OPTION == 0 then
	return "removed"
end

local INK = Color3.fromRGB(16, 18, 30)
local WHITE = Color3.new(1, 1, 1)
local function rgb(r, g, b)
	return Color3.fromRGB(r, g, b)
end

-- every line: the plain run-out, then one per outcome (Config.Fail.Outcomes' names)
local LINES = {
	{ Kind = "Breath", Text = "OUT OF BREATH!", Icon = "💨", A = rgb(72, 204, 255), B = rgb(18, 96, 208) },
	{ Kind = "Throw", Text = "THROWN OFF!", Icon = "💥", A = rgb(255, 170, 60), B = rgb(214, 82, 16) },
	{ Kind = "Chomp", Text = "EATEN!", Icon = "🦈", A = rgb(255, 86, 86), B = rgb(150, 14, 34) },
	{ Kind = "Gulp", Text = "GULPED!", Icon = "😮", A = rgb(206, 120, 255), B = rgb(98, 30, 170) },
	{ Kind = "Wrap", Text = "DRAGGED DOWN!", Icon = "🐙", A = rgb(132, 120, 255), B = rgb(44, 30, 140) },
	{ Kind = "Roll", Text = "ROLLED OFF!", Icon = "🐋", A = rgb(70, 220, 200), B = rgb(10, 120, 130) },
	{ Kind = "Flip", Text = "FLIPPED OFF!", Icon = "🔄", A = rgb(110, 190, 255), B = rgb(30, 90, 190) },
	{ Kind = "Shell", Text = "SHAKEN OFF!", Icon = "🐢", A = rgb(120, 226, 96), B = rgb(24, 122, 52) },
	{ Kind = "Coil", Text = "FLUNG OFF!", Icon = "🐍", A = rgb(232, 232, 70), B = rgb(150, 140, 10) },
	{ Kind = "Pin", Text = "PINNED!", Icon = "🦀", A = rgb(255, 140, 96), B = rgb(150, 50, 20) },
}
local RED = { A = rgb(255, 92, 84), B = rgb(160, 12, 36) }
local SUB = "YOUR CATCH IS SAFE"

local function new(class, props, parent)
	local o = Instance.new(class)
	for k, v in props do
		o[k] = v
	end
	o.Parent = parent
	return o
end
local function stroke(parent, thick, colour, fade)
	return new("UIStroke", {
		Thickness = thick,
		Color = colour or INK,
		Transparency = fade or 0,
		LineJoinMode = Enum.LineJoinMode.Round,
	}, parent)
end
local function grad(parent, top, bottom, rot)
	return new("UIGradient", { Color = ColorSequence.new(top, bottom), Rotation = rot or 90 }, parent)
end
local function lighter(c, x)
	return c:Lerp(WHITE, x)
end
local function darker(c, x)
	return c:Lerp(Color3.new(0, 0, 0), x)
end
local function text(parent, props)
	props.BackgroundTransparency = 1
	props.AnchorPoint = props.AnchorPoint or Vector2.new(0.5, 0.5)
	props.Position = props.Position or UDim2.fromScale(0.5, 0.5)
	props.Size = props.Size or UDim2.fromOffset(900, 120)
	props.TextColor3 = props.TextColor3 or WHITE
	return new("TextLabel", props, parent)
end
local function widthOf(s, size, font)
	return TextService:GetTextSize(s, size, font, Vector2.new(4000, 400)).X
end
-- a bubble: a ring with a glint
local function bubble(parent, x, y, d, fade, z)
	local b = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, x, 0.5, y),
		Size = UDim2.fromOffset(d, d),
		BackgroundColor3 = rgb(190, 236, 255),
		BackgroundTransparency = 0.78 + (fade or 0) * 0.2,
		ZIndex = z or 2,
	}, parent)
	new("UICorner", { CornerRadius = UDim.new(0.5, 0) }, b)
	stroke(b, math.max(1.5, d * 0.09), WHITE, 0.15 + (fade or 0) * 0.6)
	local g = new("Frame", {
		Position = UDim2.fromScale(0.2, 0.16),
		Size = UDim2.fromScale(0.26, 0.26),
		BackgroundColor3 = WHITE,
		BackgroundTransparency = 0.1 + (fade or 0) * 0.6,
		BorderSizePixel = 0,
		ZIndex = (z or 2) + 1,
	}, b)
	new("UICorner", { CornerRadius = UDim.new(0.5, 0) }, g)
	return b
end
-- a dark streak that fades out at both ends, with a line along each edge (the game's own miss and GREAT DIVE bands)
local ENDS = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 1),
	NumberSequenceKeypoint.new(0.22, 0.12),
	NumberSequenceKeypoint.new(0.78, 0.12),
	NumberSequenceKeypoint.new(1, 1),
})
local LINE = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 1),
	NumberSequenceKeypoint.new(0.25, 0),
	NumberSequenceKeypoint.new(0.75, 0),
	NumberSequenceKeypoint.new(1, 1),
})

local gui = new("ScreenGui", { Name = "FailTextTest", IgnoreGuiInset = true, DisplayOrder = 1000 }, CoreGui)
new("Frame", {
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = Color3.new(0, 0, 0),
	BackgroundTransparency = DIM,
	BorderSizePixel = 0,
	ZIndex = 0,
}, gui)
local grid = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }, gui)

---------------------------------------------------------------------------------------------------------------------
local build = {}

-- 1 SLAM BAND: the house style of GREAT DIVE and the catch: Bangers in hard metal shading on a tilted dark streak
build[1] = function(cell, line)
	local tilt = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(580, 150),
		BackgroundTransparency = 1,
		Rotation = -4,
	}, cell)
	local streak = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.46),
		Size = UDim2.fromOffset(580, 92),
		BackgroundColor3 = WHITE,
		BorderSizePixel = 0,
	}, tilt)
	new("UIGradient", {
		Color = ColorSequence.new(rgb(96, 8, 30), rgb(18, 4, 14)),
		Transparency = ENDS,
	}, streak)
	for _, y in { 0, 1 } do
		local l = new("Frame", {
			AnchorPoint = Vector2.new(0, y),
			Position = UDim2.fromScale(0, y),
			Size = UDim2.new(1, 0, 0, 4),
			BackgroundColor3 = rgb(255, 86, 86),
			BorderSizePixel = 0,
			ZIndex = 2,
		}, streak)
		new("UIGradient", { Transparency = LINE }, l)
	end
	local size = 76
	local at = UDim2.fromScale(0.5, 0.45)
	text(tilt, { Text = line.Text, Font = Enum.Font.Bangers, TextSize = size, TextColor3 = rgb(60, 4, 20), Position = at + UDim2.fromOffset(0, 7), ZIndex = 3 })
	stroke(tilt:FindFirstChildOfClass("TextLabel"), 5, rgb(20, 2, 10))
	local main = text(tilt, { Text = line.Text, Font = Enum.Font.Bangers, TextSize = size, Position = at, ZIndex = 4 })
	new("UIGradient", {
		Rotation = 90,
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, rgb(255, 232, 200)),
			ColorSequenceKeypoint.new(0.5, rgb(255, 150, 120)),
			ColorSequenceKeypoint.new(0.54, rgb(250, 64, 70)),
			ColorSequenceKeypoint.new(1, rgb(170, 14, 44)),
		}),
	}, main)
	stroke(main, 5, rgb(20, 2, 10))
	local sub = text(tilt, {
		Text = SUB,
		Font = Enum.Font.Bangers,
		TextSize = 26,
		TextColor3 = rgb(255, 226, 150),
		Position = UDim2.fromScale(0.5, 0.9),
		ZIndex = 5,
	})
	stroke(sub, 3, rgb(20, 2, 10))
end

-- 2 BUBBLE LETTERS: every letter its own fat bubbly letter, bobbing, with bubbles rising round the word
build[2] = function(cell, line)
	local font, size = Enum.Font.FredokaOne, 70
	local total = 0
	local widths = {}
	for i = 1, #line.Text do
		local ch = string.sub(line.Text, i, i)
		local w = if ch == " " then size * 0.34 else widthOf(ch, size, font) + 3
		widths[i] = w
		total += w
	end
	local x = -total / 2
	for i = 1, #line.Text do
		local ch = string.sub(line.Text, i, i)
		local w = widths[i]
		if ch ~= " " then
			local dy = math.sin(i * 1.7) * 9
			local rot = math.sin(i * 2.3 + 1) * 7
			for layer = 1, 2 do
				local l = text(cell, {
					Text = ch,
					Font = font,
					TextSize = size,
					Size = UDim2.fromOffset(w + 30, size + 30),
					Position = UDim2.new(0.5, x + w / 2, 0.5, dy + (if layer == 1 then 7 else 0)),
					Rotation = rot,
					ZIndex = 3 + layer,
					TextColor3 = if layer == 1 then darker(line.B, 0.55) else WHITE,
				})
				stroke(l, 6, darker(line.B, 0.72))
				if layer == 2 then
					new("UIGradient", {
						Rotation = 90,
						Color = ColorSequence.new({
							ColorSequenceKeypoint.new(0, WHITE),
							ColorSequenceKeypoint.new(0.45, lighter(line.A, 0.55)),
							ColorSequenceKeypoint.new(1, line.A),
						}),
					}, l)
				end
			end
		end
		x += w
	end
	local half = total / 2
	local spots = { { -half - 46, 10, 34 }, { -half - 18, -44, 18 }, { half + 40, -26, 40 }, { half + 14, 38, 16 }, { half + 74, 22, 14 }, { -half * 0.3, -70, 14 }, { half * 0.45, -76, 22 } }
	for _, s in spots do
		bubble(cell, s[1], s[2], s[3], 0, 2)
	end
end

-- 3 STICKER: a tilted sticker in the outcome's colour slapped on the screen, a white rim, chunky white letters
build[3] = function(cell, line)
	local font, size = Enum.Font.LuckiestGuy, 62
	local w = widthOf(line.Text, size, font) + 96
	local rot = if #line.Text % 2 == 0 then -6 else 5
	local back = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 6, 0.5, 9),
		Size = UDim2.fromOffset(w, 108),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.45,
		Rotation = rot,
		ZIndex = 1,
	}, cell)
	new("UICorner", { CornerRadius = UDim.new(0, 22) }, back)
	stroke(back, 10, Color3.new(0, 0, 0), 0.45)
	local rim = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(w, 108),
		BackgroundColor3 = WHITE,
		Rotation = rot,
		ZIndex = 2,
	}, cell)
	new("UICorner", { CornerRadius = UDim.new(0, 22) }, rim)
	stroke(rim, 10, WHITE)
	local plate = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(1, -4, 1, -4),
		BackgroundColor3 = WHITE,
		ZIndex = 3,
	}, rim)
	new("UICorner", { CornerRadius = UDim.new(0, 18) }, plate)
	grad(plate, line.A, line.B)
	stroke(plate, 4, INK)
	-- a sheen across the top
	local sheen = new("Frame", {
		Position = UDim2.new(0, 10, 0, 8),
		Size = UDim2.new(1, -20, 0.36, 0),
		BackgroundColor3 = WHITE,
		BackgroundTransparency = 0.78,
		BorderSizePixel = 0,
		ZIndex = 4,
	}, plate)
	new("UICorner", { CornerRadius = UDim.new(0, 12) }, sheen)
	local drop = text(plate, { Text = line.Text, Font = font, TextSize = size, TextColor3 = INK, Position = UDim2.new(0.5, 0, 0.5, 9), ZIndex = 5 })
	stroke(drop, 5, INK)
	local main = text(plate, { Text = line.Text, Font = font, TextSize = size, Position = UDim2.new(0.5, 0, 0.5, 4), ZIndex = 6 })
	grad(main, WHITE, rgb(255, 236, 170))
	stroke(main, 5, INK)
end

-- 4 COMIC BURST: a spiky burst in the outcome's colour, yellow comic letters across it, the outcome's emoji
build[4] = function(cell, line)
	local font, size = Enum.Font.Bangers, 78
	local w = widthOf(line.Text, size, font)
	local n = math.max(2, math.floor(w / 130 + 0.5))
	local tilt = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(900, 190),
		BackgroundTransparency = 1,
		Rotation = -5,
	}, cell)
	for pass = 1, 2 do
		for i = 1, n do
			local cx = (i - (n + 1) / 2) * (w / n)
			local d = 118 + (if i % 2 == 0 then 14 else 0)
			for k = 0, 2 do
				local sq = new("Frame", {
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.new(0.5, cx, 0.5, 0),
					Size = UDim2.fromOffset(d + (if pass == 1 then 16 else 0), d + (if pass == 1 then 16 else 0)),
					Rotation = k * 30 + i * 11,
					BackgroundColor3 = if pass == 1 then INK else WHITE,
					BorderSizePixel = 0,
					ZIndex = pass,
				}, tilt)
				if pass == 2 then
					grad(sq, line.A, line.B, 90 - (k * 30 + i * 11))
				end
			end
		end
	end
	local drop = text(tilt, { Text = line.Text, Font = font, TextSize = size, TextColor3 = INK, Position = UDim2.new(0.5, 5, 0.5, 8), ZIndex = 5 })
	stroke(drop, 6, INK)
	local main = text(tilt, { Text = line.Text, Font = font, TextSize = size, ZIndex = 6 })
	grad(main, rgb(255, 250, 170), rgb(255, 168, 30))
	stroke(main, 6, INK)
	local icon = text(tilt, {
		Text = line.Icon,
		Font = Enum.Font.GothamBlack,
		TextSize = 62,
		Size = UDim2.fromOffset(90, 90),
		Position = UDim2.new(0.5, -w / 2 - 26, 0.5, -34),
		Rotation = -12,
		ZIndex = 7,
	})
	stroke(icon, 4, INK)
end

-- 5 SINKING WORD: no plate at all: the word itself goes under, each letter lower, more turned and fainter than the last
build[5] = function(cell, line)
	local font, size = Enum.Font.GothamBlack, 64
	local total = 0
	local widths = {}
	for i = 1, #line.Text do
		local ch = string.sub(line.Text, i, i)
		local w = if ch == " " then size * 0.36 else widthOf(ch, size, font) + 2
		widths[i] = w
		total += w
	end
	local x = -total / 2
	local count = #line.Text
	for i = 1, count do
		local ch = string.sub(line.Text, i, i)
		local w = widths[i]
		local u = (i - 1) / math.max(count - 1, 1)
		if ch ~= " " then
			local dy = -22 + 58 * u ^ 2.2
			local rot = 26 * u ^ 2.4
			local fade = 0.55 * u ^ 3
			local l = text(cell, {
				Text = ch,
				Font = font,
				TextSize = size,
				Size = UDim2.fromOffset(w + 30, size + 30),
				Position = UDim2.new(0.5, x + w / 2, 0.5, dy),
				Rotation = rot,
				TextTransparency = fade,
				ZIndex = 4,
			})
			new("UIGradient", {
				Rotation = 90,
				Color = ColorSequence.new({
					ColorSequenceKeypoint.new(0, WHITE),
					ColorSequenceKeypoint.new(0.35, lighter(line.A, 0.6)),
					ColorSequenceKeypoint.new(1, line.B),
				}),
			}, l)
			stroke(l, 4, darker(line.B, 0.8), fade)
			if i % 3 == 0 then
				bubble(cell, x + w / 2 + 6, dy - 52 - (i % 4) * 9, 10 + (i % 5) * 3, 0.2 + u * 0.5, 3)
			end
		end
		x += w
	end
	local sub = text(cell, {
		Text = string.lower(SUB),
		Font = Enum.Font.GothamBold,
		TextSize = 20,
		TextColor3 = lighter(line.A, 0.7),
		TextTransparency = 0.15,
		Position = UDim2.new(0.5, -total * 0.18, 0.5, 44),
		ZIndex = 4,
	})
	stroke(sub, 2.5, darker(line.B, 0.8), 0.2)
end

-- 6 HAZARD TAPE: a strip of warning tape pulled across the screen, black letters, the outcome's emoji in a black disc
build[6] = function(cell, line)
	local font, size = Enum.Font.GothamBlack, 41
	local tilt = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(580, 150),
		BackgroundTransparency = 1,
		Rotation = -3,
	}, cell)
	new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.42, 8),
		Size = UDim2.fromOffset(570, 84),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.5,
		BorderSizePixel = 0,
	}, tilt)
	local tape = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.42),
		Size = UDim2.fromOffset(570, 84),
		BackgroundColor3 = WHITE,
		BorderSizePixel = 0,
		ZIndex = 2,
	}, tilt)
	grad(tape, rgb(255, 226, 72), rgb(255, 170, 24))
	stroke(tape, 4, INK)
	-- striped ends: hard stripes from one turned gradient
	local keys = {}
	local stripes = 3
	for s = 0, stripes - 1 do
		local a, b = s / stripes, (s + 0.5) / stripes
		table.insert(keys, ColorSequenceKeypoint.new(a, INK))
		table.insert(keys, ColorSequenceKeypoint.new(b - 0.001, INK))
		table.insert(keys, ColorSequenceKeypoint.new(b, rgb(255, 214, 50)))
		if s < stripes - 1 then
			table.insert(keys, ColorSequenceKeypoint.new((s + 1) / stripes - 0.001, rgb(255, 214, 50)))
		end
	end
	table.insert(keys, ColorSequenceKeypoint.new(1, rgb(255, 214, 50)))
	for _, side in { 0, 1 } do
		local cap = new("Frame", {
			AnchorPoint = Vector2.new(side, 0),
			Position = UDim2.fromScale(side, 0),
			Size = UDim2.new(0, 62, 1, 0),
			BackgroundColor3 = WHITE,
			BorderSizePixel = 0,
			ZIndex = 3,
		}, tape)
		new("UIGradient", { Color = ColorSequence.new(keys), Rotation = 35 }, cap)
	end
	local w = widthOf(line.Text, size, font)
	local disc = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, -w / 2 - 22, 0.5, 0),
		Size = UDim2.fromOffset(68, 68),
		BackgroundColor3 = INK,
		ZIndex = 4,
	}, tape)
	new("UICorner", { CornerRadius = UDim.new(0.5, 0) }, disc)
	stroke(disc, 3, rgb(255, 226, 72))
	text(disc, { Text = line.Icon, Font = Enum.Font.GothamBlack, TextSize = 40, Size = UDim2.fromScale(1, 1), ZIndex = 5 })
	text(tape, {
		Text = line.Text,
		Font = font,
		TextSize = size,
		TextColor3 = INK,
		Position = UDim2.new(0.5, 34, 0.5, 0),
		ZIndex = 4,
	})
	local chip = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 34, 0.42, 46),
		Size = UDim2.fromOffset(250, 30),
		BackgroundColor3 = INK,
		ZIndex = 5,
	}, tilt)
	new("UICorner", { CornerRadius = UDim.new(0, 8) }, chip)
	stroke(chip, 2, rgb(255, 226, 72))
	text(chip, { Text = SUB, Font = Enum.Font.GothamBlack, TextSize = 17, TextColor3 = rgb(255, 226, 72), Size = UDim2.fromScale(1, 1), ZIndex = 6 })
end

---------------------------------------------------------------------------------------------------------------------
-- two columns of five, the plain run-out first
local TOP, BOTTOM = 0.07, 0.03
for i, line in LINES do
	local col = (i - 1) % 2
	local row = math.floor((i - 1) / 2)
	local cell = new("Frame", {
		Name = line.Kind,
		Position = UDim2.fromScale(col * 0.5, TOP + row * (1 - TOP - BOTTOM) / 5),
		Size = UDim2.fromScale(0.5, (1 - TOP - BOTTOM) / 5),
		BackgroundTransparency = 1,
	}, grid)
	build[OPTION](cell, line)
end
local size = workspace.CurrentCamera.ViewportSize
return string.format("option %d built, viewport %d x %d", OPTION, size.X, size.Y)
