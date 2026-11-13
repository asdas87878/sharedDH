--!strict
-- The HUD's kit: its colours, its letters and the few shapes every piece is made of. The look is pass 4 of
-- docs/design/ui.md (Hugo, 2026-11-12: bolder): every plate is a chunky rounded shape with a thick dark outline, a
-- light line inside it, a top-to-bottom gradient, a faint pattern over it and a shadow under it, in a theme that says
-- what the piece is for (Kit.Themes). Letters have a thick outline. It is Roblox's own UI plus two pictures that were
-- already uploaded for the map (Kit.Textures); nothing new is uploaded.
-- Rules for phones: nothing here is made per frame, text never changes size, a label's text is only set when it
-- changes, and only what Kit.pulse is given is tweened.
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Kit = {}

Kit.Font = Enum.Font.FredokaOne
Kit.Ink = Color3.fromRGB(16, 36, 63) -- every outline
Kit.Deep = Color3.fromRGB(10, 24, 44) -- every dark see-through fill: bars, slots, pills, the button, a ring's used part
Kit.Danger = Color3.fromRGB(214, 44, 56) -- a plate that warns: dark enough for white letters
Kit.Navy = Color3.fromRGB(24, 52, 92)
Kit.Aqua = Color3.fromRGB(51, 214, 240)
Kit.Sun = Color3.fromRGB(255, 210, 63)
Kit.Coral = Color3.fromRGB(255, 90, 95)
Kit.Lime = Color3.fromRGB(124, 224, 75)
Kit.Good = Color3.fromRGB(141, 240, 106)
Kit.Pink = Color3.fromRGB(240, 96, 200)
Kit.White = Color3.new(1, 1, 1)

-- The spacing every piece keeps to (gaps, paddings), the outline's widths and the corners
Kit.Space = { Hair = 2, Small = 4, Medium = 8, Large = 12, Huge = 16 }
Kit.Outline = { Hair = 1.2, Thin = 2, Bold = 3, Heavy = 4 }
Kit.Radius = { Tile = 5, Plate = 9, Round = 999 }

-- Pictures laid over a plate as its pattern, both uploaded before this pass: the map's stud tile
-- (art/map/textures.json, "tile2") and the picture the moving water drifts (tools/map/water_look.luau)
Kit.Textures = {
	Studs = "rbxassetid://124244361010023",
	Water = "rbxassetid://6126332496",
}

export type Style = {
	Top: Color3, -- the fill, top to bottom
	Bottom: Color3,
	Edge: Color3?, -- the outline (the ink, if not given)
	Outline: number?, -- its width (3)
	Radius: number?, -- 999 and up: a circle or a pill
	Fade: number?, -- how see-through the fill is
	Texture: string?, -- a name in Kit.Textures
	TextureFade: number?,
	TextureSize: number?, -- one repeat of the picture, in the HUD's points
	Bevel: boolean?, -- the light line inside the outline (on, unless false)
	Shine: boolean?, -- a pale band over the upper half, as on glass
	Flat: boolean?, -- the plainer plate (Hugo, 2026-11-13): one colour, no light line, no shine, a hairline outline
	Drop: number?, -- how far under the plate its shadow sits (Kit.panel only; 0 for none)
}

-- One theme a purpose: what a plate is for is read from its colour and its pattern before its words
Kit.Themes = {
	-- air: water-blue, bubbles
	Oxygen = {
		Top = Color3.fromRGB(72, 204, 255),
		Bottom = Color3.fromRGB(18, 96, 208),
		Texture = "Water",
		TextureFade = 0.72,
		TextureSize = 72,
		Flat = true,
	},
	-- out of air, a miss: deep red going to black
	Danger = {
		Top = Color3.fromRGB(226, 52, 60),
		Bottom = Color3.fromRGB(70, 6, 28),
		Texture = "Water",
		TextureFade = 0.86,
		TextureSize = 72,
	},
	-- the press that is the game: yellow to orange (the stripes are Kit.stripes)
	Action = { Top = Color3.fromRGB(255, 226, 72), Bottom = Color3.fromRGB(255, 132, 24) },
	Grab = { Top = Color3.fromRGB(120, 240, 255), Bottom = Color3.fromRGB(20, 150, 226) },
	Off = { Top = Color3.fromRGB(128, 140, 160), Bottom = Color3.fromRGB(72, 82, 104) },
	-- money and a best: gold bricks
	Gold = {
		Top = Color3.fromRGB(255, 232, 110),
		Bottom = Color3.fromRGB(240, 150, 20),
		Texture = "Studs",
		TextureFade = 0.7,
		TextureSize = 28,
	},
	-- good news
	Good = {
		Top = Color3.fromRGB(96, 214, 96),
		Bottom = Color3.fromRGB(18, 110, 58),
		Texture = "Studs",
		TextureFade = 0.8,
		TextureSize = 28,
	},
	-- a plain dark plate: bricks
	Navy = {
		Top = Color3.fromRGB(38, 76, 130),
		Bottom = Color3.fromRGB(14, 32, 60),
		Texture = "Studs",
		TextureFade = 0.88,
		TextureSize = 28,
	},
	-- what holds a creature: an aquarium's glass
	Glass = {
		Top = Color3.fromRGB(170, 232, 255),
		Bottom = Color3.fromRGB(30, 110, 190),
		Fade = 0.45,
		Texture = "Water",
		TextureFade = 0.8,
		TextureSize = 64,
		Shine = true,
	},
	-- ours, not the player's: a tool's dark slate (the squares are Kit.grid)
	Tool = {
		Top = Color3.fromRGB(54, 62, 76),
		Bottom = Color3.fromRGB(26, 31, 41),
		Edge = Color3.fromRGB(8, 10, 14),
		Bevel = false,
	},
	-- a key of the keyboard
	Key = { Top = Color3.new(1, 1, 1), Bottom = Color3.fromRGB(206, 216, 232), Radius = 7 },
} :: { [string]: Style }

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

-- Letters with a thick dark outline (a little thicker on big letters). The size is fixed: text never scales to fit.
function Kit.text(props: { [string]: any }, parent: Instance, outline: number?): TextLabel
	props.BackgroundTransparency = 1
	props.Font = props.Font or Kit.Font
	props.TextColor3 = props.TextColor3 or Kit.White
	props.TextSize = props.TextSize or 14
	props.Text = props.Text or ""
	local label: TextLabel = Kit.new("TextLabel", props, parent)
	Kit.stroke(label, outline or math.clamp(props.TextSize * 0.19, 1.6, 4), Kit.Ink)
	return label
end

-- The one highlight a plain solid plate has: lit from above, a little darker toward its bottom edge
function Kit.shade(plate: Instance)
	Kit.new("UIGradient", {
		Color = ColorSequence.new(Kit.White, Color3.fromRGB(214, 222, 236)),
		Rotation = 90,
	}, plate)
end

local GOLD = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 250, 190)),
	ColorSequenceKeypoint.new(0.45, Color3.fromRGB(255, 208, 48)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(236, 132, 16)),
})
local EMBER = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 196, 150)),
	ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 70, 90)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(196, 30, 120)),
})
local RAINBOW = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 110, 120)),
	ColorSequenceKeypoint.new(0.2, Color3.fromRGB(255, 190, 90)),
	ColorSequenceKeypoint.new(0.4, Color3.fromRGB(250, 240, 120)),
	ColorSequenceKeypoint.new(0.6, Color3.fromRGB(120, 235, 150)),
	ColorSequenceKeypoint.new(0.8, Color3.fromRGB(110, 190, 255)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(200, 140, 255)),
})

-- A rarity's own colours, as a gradient and which way it runs (90: top to bottom). The lower rarities are their colour,
-- lighter at the top; a Legendary is gold, a Mythic an ember, and a Secret the rainbow, side to side
-- (docs/style/05-rarity-look.md: gold and the rainbow are the top of the ladder)
function Kit.tierFill(tier: string, colours: { [string]: any }): (ColorSequence, number)
	if tier == "Legendary" then
		return GOLD, 90
	elseif tier == "Mythic" then
		return EMBER, 90
	elseif tier == "Secret" then
		return RAINBOW, 0
	end
	local entry = colours[tier]
	local colour: Color3 = if entry then entry.Colour else Kit.White
	return ColorSequence.new(Kit.lighter(colour, 0.45), colour), 90
end

-- A rarity's word in those colours (the label's own colour must stay white for the gradient to show)
function Kit.tierColours(label: TextLabel, gradient: UIGradient, tier: string, colours: { [string]: any })
	label.TextColor3 = Kit.White
	gradient.Color, gradient.Rotation = Kit.tierFill(tier, colours)
end

export type Dressed = {
	Fill: UIGradient,
	Outline: UIStroke,
	Bevel: UIStroke?,
	Texture: ImageLabel?,
	paint: (top: Color3, bottom: Color3) -> (),
}

local BEVEL = NumberSequence.new(0.3, 0.88)
local SHINE = NumberSequence.new(0.66, 1)
local FLAT_MIX = 0.3 -- a flat plate's one colour: this far from its theme's top colour to its bottom one

local function outlineOf(style: Style): number
	return style.Outline or (if style.Flat then Kit.Outline.Hair else Kit.Outline.Bold)
end

local function fillOf(style: Style, top: Color3, bottom: Color3): ColorSequence
	return if style.Flat then ColorSequence.new(top:Lerp(bottom, FLAT_MIX)) else ColorSequence.new(top, bottom)
end

-- Dresses a frame as a plate of the look: the gradient, the thick outline, the light line inside it, the pattern and
-- the shine. What it adds sits under the frame's own children (ZIndex 0). The frame's own colour becomes white: the
-- gradient carries the colour from then on (paint changes it). A Flat style is the plainer plate: one colour (still
-- carried by the gradient, so paint works the same), a hairline outline, and neither the light line nor the shine.
function Kit.dress(face: GuiObject, style: Style): Dressed
	local radius = style.Radius or Kit.Radius.Plate
	local round = radius >= 999
	face.BackgroundColor3 = Kit.White
	face.BackgroundTransparency = style.Fade or 0
	face.BorderSizePixel = 0
	Kit.corner(face, radius)
	local flat = style.Flat == true
	local fill = Kit.gradient(face, style.Top, style.Bottom)
	fill.Color = fillOf(style, style.Top, style.Bottom)
	local outline = Kit.stroke(face, outlineOf(style), style.Edge or Kit.Ink)
	outline.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	local texture: ImageLabel? = nil
	if style.Texture then
		local size = style.TextureSize or 32
		texture = Kit.new("ImageLabel", {
			Name = "Pattern",
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Image = Kit.Textures[style.Texture],
			ImageTransparency = style.TextureFade or 0.8,
			ScaleType = Enum.ScaleType.Tile,
			TileSize = UDim2.fromOffset(size, size),
			ZIndex = 0,
		}, face)
		Kit.corner(texture :: ImageLabel, radius)
	end
	if style.Shine and not flat then
		local shine = Kit.new("Frame", {
			Name = "Shine",
			Position = UDim2.fromOffset(2, 2),
			Size = UDim2.new(1, -4, 0.5, -2),
			BackgroundColor3 = Kit.White,
			BorderSizePixel = 0,
			ZIndex = 0,
		}, face)
		Kit.corner(shine, if round then 999 else math.max(radius - 2, 0))
		Kit.new("UIGradient", { Transparency = SHINE, Rotation = 90 }, shine)
	end
	local bevel: UIStroke? = nil
	if style.Bevel ~= false and not flat then
		local line = Kit.new("Frame", {
			Name = "Bevel",
			Position = UDim2.fromOffset(2.5, 2.5),
			Size = UDim2.new(1, -5, 1, -5),
			BackgroundTransparency = 1,
			ZIndex = 0,
		}, face)
		Kit.corner(line, if round then 999 else math.max(radius - 2.5, 0))
		bevel = Kit.stroke(line, 1.5, Kit.White)
		Kit.new("UIGradient", { Transparency = BEVEL, Rotation = 90 }, bevel)
	end
	local function paint(top: Color3, bottom: Color3)
		fill.Color = fillOf(style, top, bottom)
	end
	return { Fill = fill, Outline = outline, Bevel = bevel, Texture = texture, paint = paint }
end

export type Panel = { Frame: Frame, Face: Frame, Shadow: Frame, Look: Dressed }

-- A plate with its shadow: a clear holder (it takes the props: where and how big), the shadow a little under it and
-- the dressed face over that. What the plate holds goes in Face.
function Kit.panel(parent: Instance, props: { [string]: any }, style: Style): Panel
	props.BackgroundTransparency = 1
	local holder: Frame = Kit.new("Frame", props, parent)
	local drop = style.Drop or 3
	local shadow: Frame = Kit.new("Frame", {
		Name = "Shadow",
		Position = UDim2.fromOffset(0, drop),
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(4, 10, 22),
		BackgroundTransparency = 0.45,
		BorderSizePixel = 0,
		Visible = drop > 0,
		ZIndex = 0,
	}, holder)
	Kit.corner(shadow, style.Radius or Kit.Radius.Plate)
	Kit.stroke(shadow, outlineOf(style), Color3.fromRGB(4, 10, 22), 0.45)
	local face: Frame = Kit.new("Frame", { Name = "Face", Size = UDim2.fromScale(1, 1) }, holder)
	return { Frame = holder, Face = face, Shadow = shadow, Look = Kit.dress(face, style) }
end

-- Motion stripes: slanted pale bands over a plate, as one gradient (no picture, and it keeps to the plate's corners)
function Kit.stripes(face: Instance, radius: number, fade: number?): Frame
	local clear = 1
	local pale = fade or 0.78
	local points = {}
	local bands = 4
	for i = 0, bands - 1 do
		local from = (i + 0.2) / bands
		local to = (i + 0.62) / bands
		table.insert(points, NumberSequenceKeypoint.new(if i == 0 then 0 else from - 0.001, clear))
		table.insert(points, NumberSequenceKeypoint.new(from, pale))
		table.insert(points, NumberSequenceKeypoint.new(to, pale))
		table.insert(points, NumberSequenceKeypoint.new(to + 0.001, clear))
	end
	table.insert(points, NumberSequenceKeypoint.new(1, clear))
	local frame: Frame = Kit.new("Frame", {
		Name = "Stripes",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Kit.White,
		BorderSizePixel = 0,
		ZIndex = 0,
	}, face)
	Kit.corner(frame, radius)
	Kit.new("UIGradient", { Transparency = NumberSequence.new(points), Rotation = -58 }, frame)
	return frame
end

-- A few bubbles as a plate's pattern: thin pale rings. spots: { x, y (0 to 1 across the plate), size } each
function Kit.bubbles(face: Instance, spots: { { number } })
	for _, spot in spots do
		local ring = Kit.new("Frame", {
			Name = "Bubble",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(spot[1], spot[2]),
			Size = UDim2.fromOffset(spot[3], spot[3]),
			BackgroundColor3 = Kit.White,
			BackgroundTransparency = 0.86,
			ZIndex = 0,
		}, face)
		Kit.corner(ring, 999)
		Kit.stroke(ring, 1, Kit.White, 0.45)
	end
end

-- A tool's squared paper: thin pale lines every cell points, over a plate up to wide by high
function Kit.grid(face: Instance, cell: number, wide: number, high: number)
	local sheet = Kit.new("Frame", {
		Name = "Grid",
		Position = UDim2.fromOffset(4, 4),
		Size = UDim2.new(1, -8, 1, -8),
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		ZIndex = 0,
	}, face)
	for x = cell, wide, cell do
		Kit.new("Frame", {
			Position = UDim2.fromOffset(x, 0),
			Size = UDim2.new(0, 1, 1, 0),
			BackgroundColor3 = Kit.White,
			BackgroundTransparency = 0.93,
			BorderSizePixel = 0,
		}, sheet)
	end
	for y = cell, high, cell do
		Kit.new("Frame", {
			Position = UDim2.fromOffset(0, y),
			Size = UDim2.new(1, 0, 0, 1),
			BackgroundColor3 = Kit.White,
			BackgroundTransparency = 0.93,
			BorderSizePixel = 0,
		}, sheet)
	end
end

-- Something that beats while a warning is on (an outline going bright and back): one tween, played and cancelled, the
-- only thing in the HUD that is tweened all the time it shows. rest is what the target goes back to.
function Kit.pulse(
	target: Instance,
	rest: { [string]: any },
	peak: { [string]: any },
	period: number?
): (on: boolean) -> ()
	local info = TweenInfo.new(period or 0.3, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
	local tween = TweenService:Create(target, info, peak)
	local running = false
	return function(on: boolean)
		if on == running then
			return
		end
		running = on
		if on then
			tween:Play()
		else
			tween:Cancel()
			for key, value in rest do
				(target :: any)[key] = value
			end
		end
	end
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

export type Sweep = {
	Frame: Frame,
	set: (fraction: number) -> (),
	colour: (colour: Color3) -> (),
	fade: (transparency: number) -> (),
}

export type Ring = {
	Frame: Frame,
	Hole: Frame,
	set: (fraction: number) -> (),
	colour: (colour: Color3) -> (),
	Glow: UIStroke, -- a line round the whole ring, clear until a warning lights it (Kit.pulse)
	spent: (spent: boolean) -> (), -- the emptied part in red (an empty ring has no arc left to carry the colour)
	lag: (fraction: number) -> (), -- a meter only: the part just lost, in red behind what is left
}

local TRACK = Kit.Deep
local HALF = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 0),
	NumberSequenceKeypoint.new(0.5, 0),
	NumberSequenceKeypoint.new(0.501, 1),
	NumberSequenceKeypoint.new(1, 1),
})
-- The left half laps over the right by this much. A ring more than half full had a thin dark line down from its hole
-- at 6 o'clock (seen on the tame ring, 2026-11-12, twice): the right half's own cut there is soft, a pixel of it half
-- see-through, and the left half stopped short of it. The left half now draws over that pixel in the same colour. The
-- right half does not lap the other way: that would start the arc a little before 12 o'clock.
local LAP = 2

-- A flat arc that runs clockwise from the top, as much of the circle as it is set to. It is two half rings, each an
-- outlined circle inside a frame that clips it to its half; the outline's gradient is see-through past its middle, and
-- turning that gradient sweeps the half open. Only the gradients' turn changes, in half-degree steps. A full circle is
-- one outline with no halves, so it has no seam.
function Kit.sweep(parent: Instance, diameter: number, thick: number, colour: Color3): Sweep
	local inner = diameter - thick * 2
	local half = diameter / 2
	local box: Frame = Kit.new("Frame", {
		Size = UDim2.fromOffset(diameter, diameter),
		BackgroundTransparency = 1,
	}, parent)
	local function band(into: Instance, x: number): (UIStroke, Frame)
		local circle: Frame = Kit.new("Frame", {
			Position = UDim2.fromOffset(x, thick),
			Size = UDim2.fromOffset(inner, inner),
			BackgroundTransparency = 1,
		}, into)
		Kit.corner(circle, 999)
		return Kit.stroke(circle, thick, colour), circle
	end
	local right: Frame = Kit.new("Frame", {
		Position = UDim2.fromOffset(half, 0),
		Size = UDim2.fromOffset(half, diameter),
		BackgroundTransparency = 1,
		ClipsDescendants = true,
	}, box)
	local left: Frame = Kit.new("Frame", {
		Size = UDim2.fromOffset(half + LAP, diameter),
		BackgroundTransparency = 1,
		ClipsDescendants = true,
	}, box)
	local rightStroke = band(right, thick - half)
	local leftStroke = band(left, thick)
	local wholeStroke, whole = band(box, thick)
	whole.Visible = false
	local rightTurn: UIGradient = Kit.new("UIGradient", { Transparency = HALF, Rotation = 0 }, rightStroke)
	local leftTurn: UIGradient = Kit.new("UIGradient", { Transparency = HALF, Rotation = 180 }, leftStroke)

	local shown = -1
	local function set(fraction: number)
		local steps = math.floor(math.clamp(fraction, 0, 1) * 720 + 0.5)
		if steps == shown then
			return
		end
		shown = steps
		local degrees = steps / 2
		local full = steps >= 720
		whole.Visible = full
		right.Visible = degrees > 0 and not full
		left.Visible = degrees > 180 and not full
		if not full then
			rightTurn.Rotation = math.min(degrees, 180)
			leftTurn.Rotation = 180 + math.max(degrees - 180, 0)
		end
	end
	local function setColour(value: Color3)
		rightStroke.Color = value
		leftStroke.Color = value
		wholeStroke.Color = value
	end
	local function fade(transparency: number)
		rightStroke.Transparency = transparency
		leftStroke.Transparency = transparency
		wholeStroke.Transparency = transparency
	end
	set(1)
	return { Frame = box, set = set, colour = setColour, fade = fade }
end

-- A ring that empties, as the reference's: the part left runs clockwise from the top, and the used part is dark and
-- see-through. meter: the reference's meter beside the rider, which also has a thin dark edge, a clear hole, and the
-- part just lost in red behind what is left (lag). outline: the look's bold dark line round its outer edge and its
-- hole, with a pale line on the band (0 or nil for none; a meter then keeps its thin edge). plain: that dark line
-- without the pale one (Hugo, 2026-11-13: the rings beside the rider, with a hairline for the outline).
function Kit.ring(
	parent: Instance,
	diameter: number,
	thick: number,
	meter: boolean?,
	outline: number?,
	plain: boolean?
): Ring
	local inner = diameter - thick * 2
	local bold = outline or 0
	local holder: Frame = Kit.new("Frame", {
		Size = UDim2.fromOffset(diameter, diameter),
		BackgroundTransparency = 1,
	}, parent)
	-- the warning's glow, then the dark line round the outside (both drawn outward from the ring's own edge)
	local rim = Kit.new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 0 }, holder)
	Kit.corner(rim, 999)
	local glow = Kit.stroke(rim, bold + 3, Kit.Coral, 1)
	if bold > 0 then
		local dark = Kit.new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 0 }, holder)
		Kit.corner(dark, 999)
		Kit.stroke(dark, bold, Kit.Ink)
	end
	local trackCircle = Kit.new("Frame", {
		Position = UDim2.fromOffset(thick, thick),
		Size = UDim2.fromOffset(inner, inner),
		BackgroundTransparency = 1,
	}, holder)
	Kit.corner(trackCircle, 999)
	local track = Kit.stroke(trackCircle, thick, TRACK, 0.5)
	local behind: Sweep? = nil
	if meter then
		local made = Kit.sweep(holder, diameter, thick, Kit.Coral)
		made.set(0)
		behind = made
	end
	local front = Kit.sweep(holder, diameter, thick, Kit.Aqua)
	local hole: Frame = Kit.new("Frame", {
		Position = UDim2.fromOffset(thick, thick),
		Size = UDim2.fromOffset(inner, inner),
		BackgroundColor3 = Kit.Deep,
		BackgroundTransparency = if meter then 1 else 0.5,
	}, holder)
	Kit.corner(hole, 999)
	if bold > 0 then
		-- the dark line round the hole, drawn over the band's inner edge
		local lip = Kit.new("Frame", {
			Position = UDim2.fromOffset(thick, thick),
			Size = UDim2.fromOffset(inner, inner),
			BackgroundTransparency = 1,
			ZIndex = 2,
		}, holder)
		Kit.corner(lip, 999)
		Kit.stroke(lip, bold, Kit.Ink)
	end
	if bold > 0 and not plain then
		-- a pale line on the band's outside
		local pale = Kit.new("Frame", {
			Position = UDim2.fromOffset(2, 2),
			Size = UDim2.new(1, -4, 1, -4),
			BackgroundTransparency = 1,
			ZIndex = 2,
		}, holder)
		Kit.corner(pale, 999)
		local paleLine = Kit.stroke(pale, 1.5, Kit.White)
		Kit.new("UIGradient", { Transparency = BEVEL, Rotation = 90 }, paleLine)
	elseif bold <= 0 and meter then
		-- the thin dark edge, outside and round the hole
		Kit.stroke(hole, 1.2, Kit.Ink, 0.45)
		local edge = Kit.new("Frame", {
			Size = UDim2.fromOffset(diameter, diameter),
			BackgroundTransparency = 1,
		}, holder)
		Kit.corner(edge, 999)
		Kit.stroke(edge, 1.2, Kit.Ink, 0.4)
	end

	local function spent(value: boolean)
		track.Color = if value then Kit.Coral else TRACK
		track.Transparency = if value then 0.15 else 0.5
	end
	local function lag(fraction: number)
		if behind then
			behind.set(fraction)
		end
	end
	return {
		Frame = holder,
		Hole = hole,
		Glow = glow,
		set = front.set,
		colour = front.colour,
		spent = spent,
		lag = lag,
	}
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
-- In Studio the workspace's "HudTouch" (true or false) forces the answer, to see the phone layout without a phone.
function Kit.touch(): boolean
	if RunService:IsStudio() then
		local forced = workspace:GetAttribute("HudTouch")
		if type(forced) == "boolean" then
			return forced
		end
	end
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
