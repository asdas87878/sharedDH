--!strict
-- The HUD's kit: its colours, its letters and the few shapes every piece is made of. Everything is Roblox's own UI
-- (frames, corners, outlines, gradients); no picture is uploaded. The look is pass 3 of docs/design/ui.md: plain
-- shapes with nearly square corners, a dark outline, letters with a thick outline straight on the world.
-- Rules for phones: nothing here is made per frame, text never changes size, and a label's text is only set when it
-- changes.
local UserInputService = game:GetService("UserInputService")

local Kit = {}

Kit.Font = Enum.Font.FredokaOne
Kit.Ink = Color3.fromRGB(16, 36, 63)
Kit.Navy = Color3.fromRGB(24, 52, 92)
Kit.Aqua = Color3.fromRGB(51, 214, 240)
Kit.Sun = Color3.fromRGB(255, 210, 63)
Kit.Coral = Color3.fromRGB(255, 90, 95)
Kit.Lime = Color3.fromRGB(124, 224, 75)
Kit.Good = Color3.fromRGB(141, 240, 106)
Kit.Pink = Color3.fromRGB(240, 96, 200)
Kit.White = Color3.new(1, 1, 1)

-- One colour a land, the map's own (tools/map/greybox.py, GROUND), and a short name for the strip's small tiles
Kit.Lands = {
	Color3.fromRGB(242, 214, 128),
	Color3.fromRGB(244, 148, 152),
	Color3.fromRGB(120, 172, 92),
	Color3.fromRGB(160, 148, 124),
	Color3.fromRGB(90, 124, 176),
	Color3.fromRGB(104, 96, 170),
	Color3.fromRGB(62, 66, 120),
	Color3.fromRGB(120, 72, 64),
	Color3.fromRGB(150, 150, 168),
	Color3.fromRGB(110, 44, 60),
}
Kit.LandShort = { "Shallows", "Reef", "Kelp", "Wrecks", "Blue", "Twilight", "Midnight", "Vents", "Bones", "Under" }

-- A fish you would hold this long reads green; shorter, yellow; under Short, red (the tuning chat's three steps)
Kit.HoldFine = 2
Kit.HoldShort = 0.5

function Kit.new(class: string, props: { [string]: any }, parent: Instance?): any
	local object = Instance.new(class :: any)
	for key, value in props do
		(object :: any)[key] = value
	end
	if parent then
		object.Parent = parent
	end
	return object
end

function Kit.lighter(colour: Color3, amount: number): Color3
	return colour:Lerp(Color3.new(1, 1, 1), amount)
end

function Kit.darker(colour: Color3, amount: number): Color3
	return colour:Lerp(Color3.new(0, 0, 0), amount)
end

-- Round corners; 999 and up makes a circle or a pill
function Kit.corner(parent: Instance, radius: number)
	Kit.new("UICorner", { CornerRadius = if radius >= 999 then UDim.new(0.5, 0) else UDim.new(0, radius) }, parent)
end

function Kit.stroke(parent: Instance, thickness: number, colour: Color3, transparency: number?): UIStroke
	return Kit.new("UIStroke", {
		Thickness = thickness,
		Color = colour,
		Transparency = transparency or 0,
		LineJoinMode = Enum.LineJoinMode.Round,
	}, parent)
end

-- A top-to-bottom gradient of colour on a frame, or in a label's letters
function Kit.gradient(parent: Instance, top: Color3, bottom: Color3): UIGradient
	return Kit.new("UIGradient", { Color = ColorSequence.new(top, bottom), Rotation = 90 }, parent)
end

-- Letters with a thick dark outline. The size is fixed: text never scales to fit.
function Kit.text(props: { [string]: any }, parent: Instance, outline: number?): TextLabel
	props.BackgroundTransparency = 1
	props.Font = props.Font or Kit.Font
	props.TextColor3 = props.TextColor3 or Kit.White
	props.TextSize = props.TextSize or 14
	props.Text = props.Text or ""
	local label: TextLabel = Kit.new("TextLabel", props, parent)
	Kit.stroke(label, outline or 2.2, Kit.Ink)
	return label
end

-- A rarity's word: its colour, lighter at the top (the label's own colour must stay white for the gradient to show)
function Kit.tierColours(label: TextLabel, gradient: UIGradient, tier: string, colours: { [string]: any })
	local entry = colours[tier]
	local colour: Color3 = if entry then entry.Colour else Kit.White
	if tier == "Secret" then
		colour = Color3.fromRGB(110, 110, 132)
	end
	label.TextColor3 = Kit.White
	gradient.Color = ColorSequence.new(Kit.lighter(colour, 0.45), colour)
end

-- The sign for Oxygen: a bubble (three circles)
function Kit.bubble(parent: Instance, size: number): Frame
	local bubble: Frame = Kit.new("Frame", {
		Size = UDim2.fromOffset(size, size),
		BackgroundColor3 = Color3.fromRGB(127, 227, 255),
	}, parent)
	Kit.corner(bubble, 999)
	Kit.stroke(bubble, math.max(1.5, size * 0.11), Kit.Ink)
	local shine = Kit.new("Frame", {
		Position = UDim2.fromScale(0.2, 0.16),
		Size = UDim2.fromScale(0.3, 0.22),
		BackgroundColor3 = Kit.White,
		BorderSizePixel = 0,
	}, bubble)
	Kit.corner(shine, 999)
	return bubble
end

-- The sign for money: a coin
function Kit.coin(parent: Instance, size: number): Frame
	local coin: Frame = Kit.new("Frame", {
		Size = UDim2.fromOffset(size, size),
		BackgroundColor3 = Kit.Sun,
	}, parent)
	Kit.corner(coin, 999)
	Kit.stroke(coin, math.max(1.5, size * 0.11), Kit.Ink)
	local rim = Kit.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.5, 0.5),
		BackgroundTransparency = 1,
	}, coin)
	Kit.corner(rim, 999)
	Kit.stroke(rim, math.max(1, size * 0.09), Color3.fromRGB(240, 168, 24))
	return coin
end

export type Ring = {
	Frame: Frame,
	Hole: Frame,
	set: (fraction: number) -> (),
	colour: (colour: Color3) -> (),
	spent: (spent: boolean) -> (), -- the emptied part in red (an empty ring has no arc left to carry the colour)
}

local TRACK = Color3.fromRGB(10, 28, 52)
local HALF = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 0),
	NumberSequenceKeypoint.new(0.5, 0),
	NumberSequenceKeypoint.new(0.501, 1),
	NumberSequenceKeypoint.new(1, 1),
})

-- A flat ring that empties, as the reference's: the part left runs clockwise from the top. It is two half rings, each
-- an outlined circle inside a frame that clips it to its half; the outline's gradient is see-through past its middle,
-- and turning that gradient sweeps the half open. Only the gradients' turn changes, in half-degree steps.
function Kit.ring(parent: Instance, diameter: number, thick: number): Ring
	local inner = diameter - thick * 2
	local holder: Frame = Kit.new("Frame", {
		Size = UDim2.fromOffset(diameter, diameter),
		BackgroundTransparency = 1,
	}, parent)
	local function band(into: Instance, x: number): UIStroke
		local circle = Kit.new("Frame", {
			Position = UDim2.fromOffset(x, thick),
			Size = UDim2.fromOffset(inner, inner),
			BackgroundTransparency = 1,
		}, into)
		Kit.corner(circle, 999)
		return Kit.stroke(circle, thick, Kit.Aqua)
	end
	local track = band(holder, thick)
	track.Color = TRACK
	track.Transparency = 0.5
	local right = Kit.new("Frame", {
		Position = UDim2.fromOffset(diameter / 2, 0),
		Size = UDim2.fromOffset(diameter / 2, diameter),
		BackgroundTransparency = 1,
		ClipsDescendants = true,
	}, holder)
	local left = Kit.new("Frame", {
		Size = UDim2.fromOffset(diameter / 2, diameter),
		BackgroundTransparency = 1,
		ClipsDescendants = true,
	}, holder)
	local rightStroke = band(right, thick - diameter / 2)
	local leftStroke = band(left, thick)
	local rightTurn: UIGradient = Kit.new("UIGradient", { Transparency = HALF, Rotation = 0 }, rightStroke)
	local leftTurn: UIGradient = Kit.new("UIGradient", { Transparency = HALF, Rotation = 180 }, leftStroke)
	local hole: Frame = Kit.new("Frame", {
		Position = UDim2.fromOffset(thick, thick),
		Size = UDim2.fromOffset(inner, inner),
		BackgroundColor3 = Color3.fromRGB(10, 28, 52),
		BackgroundTransparency = 0.5,
	}, holder)
	Kit.corner(hole, 999)

	local shown = -1
	local function set(fraction: number)
		local steps = math.floor(math.clamp(fraction, 0, 1) * 720 + 0.5)
		if steps == shown then
			return
		end
		shown = steps
		local degrees = steps / 2
		right.Visible = degrees > 0
		left.Visible = degrees > 180
		rightTurn.Rotation = math.min(degrees, 180)
		leftTurn.Rotation = 180 + math.max(degrees - 180, 0)
	end
	local function colour(value: Color3)
		rightStroke.Color = value
		leftStroke.Color = value
	end
	local function spent(value: boolean)
		track.Color = if value then Kit.Coral else TRACK
		track.Transparency = if value then 0.15 else 0.5
	end
	set(1)
	return { Frame = holder, Hole = hole, set = set, colour = colour, spent = spent }
end

-- Seconds as the HUD writes them: two decimals under a second, one up to ten, whole seconds to a minute, then nothing
function Kit.seconds(value: number): string
	if value < 1 then
		return string.format("%.2f", math.max(value, 0))
	elseif value < 10 then
		return string.format("%.1f", value)
	elseif value < 60 then
		return string.format("%d", math.floor(value))
	end
	return ""
end

local UNITS = { "K", "M", "B", "T" }

-- A big number in short: 950, 1.9K, 12.5K, 2.3M
function Kit.short(value: number): string
	if value < 1000 then
		return tostring(math.floor(value + 0.5))
	end
	local unit = 0
	while value >= 1000 and unit < #UNITS do
		value /= 1000
		unit += 1
	end
	local text = if value >= 100 then string.format("%d", math.floor(value)) else string.format("%.1f", value)
	text = (string.gsub(text, "%.0$", ""))
	return text .. UNITS[unit]
end

-- Whether the player is on a touch screen with no keyboard: the phone layout
function Kit.touch(): boolean
	local last = UserInputService:GetLastInputType()
	if last == Enum.UserInputType.Touch then
		return true
	elseif
		last == Enum.UserInputType.Keyboard
		or string.match(last.Name, "^Mouse")
		or string.match(last.Name, "^Gamepad")
	then
		return false
	end
	return UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
end

return Kit
