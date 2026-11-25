--!strict
-- A line of words with its key words on stickers (B1 of docs/attachments/text-options-2026-11-25.png, Hugo's pick): Luckiest
-- Guy in white with the dark outline and a hard shadow, the words between stars on a tilted gold sticker with a white rim,
-- and money between stars ("*$26.5K / $75K*") on a green one with the cash picture. Roblox's own pieces and our uploaded
-- cash picture only.
--   local s = Sticker.new(parent, props)   its frame (s.Root), as big as what is on it
--   s.set(words, size, most)               what it says: the letters' size, and the widest it may be (it shrinks to fit)
--   s.pose(on, clear)                      how far it is slapped on and how see-through it is, 0 to 1: the stickers turn and
--                                          grow into place, the words slide out from behind them
--   Sticker.parts(words)                   the words cut at the stars (for a check)
-- Every measure is a share of the letters' size.
local TextService = game:GetService("TextService")

local Kit = require(script.Parent.Kit)

local Sticker = {}

export type Part = { Text: string, Kind: "Word" | "Gold" | "Cash" }
export type Sticker = {
	Root: Frame,
	set: (words: string, size: number, most: number?, stroke: number?) -> (),
	pose: (on: number, clear: number) -> (),
}

local FONT = Enum.Font.LuckiestGuy
local DOWN = 0.11 -- (its capitals sit high in their line)

type Plate = {
	Letters: number, -- the letters' size
	Pad: number, -- the sticker is this much wider than its words
	High: number,
	Round: number,
	Top: Color3,
	Bottom: Color3,
	Ink: Color3, -- its letters' outline
	Stroke: number,
	Rim: number,
	Edge: number,
	Drop: number,
	Turn: number, -- degrees
	Left: number, -- kept clear before it (the cash picture hangs out there),
	Right: number, -- and after it
}
local PLATES: { [string]: Plate } = {
	Gold = {
		Letters = 1.06,
		Pad = 0.8,
		High = 1.24,
		Round = 0.34,
		Top = Color3.fromRGB(255, 216, 74),
		Bottom = Color3.fromRGB(245, 154, 14),
		Ink = Color3.fromRGB(122, 60, 0),
		Stroke = 0.1,
		Rim = 0.1,
		Edge = 0.09,
		Drop = 0.12,
		Turn = -3.5,
		Left = 0.19,
		Right = 0.19,
	},
	Cash = {
		Letters = 0.95,
		Pad = 2,
		High = 1.3,
		Round = 0.4,
		Top = Color3.fromRGB(142, 224, 90),
		Bottom = Color3.fromRGB(47, 158, 58),
		Ink = Color3.fromRGB(12, 74, 28),
		Stroke = 0.12,
		Rim = 0.095,
		Edge = 0.095,
		Drop = 0.12,
		Turn = -2.5,
		Left = 0.62,
		Right = 0.19,
	},
}
local GLOSS = 0.72 -- how see-through the shine on its top half is
local CASH, CASH_TURN = 1.75, -8 -- the cash picture, over the sticker's left end
local WORD, WORD_ROOM, WORD_DROP = 0.98, 0.35, 0.1 -- the plain words
local SLAP_TURN, SLAP_FROM, SLIDE = 4.5, 1.35, 1.1 -- slapped on from this much further round, this big, and the words
-- from this far behind

-- The words cut at the stars; between stars, money if it starts with the dollar
function Sticker.parts(words: string): { Part }
	local list: { Part } = {}
	for i, text in string.split(words, "*") do
		local bare = string.match(text, "^%s*(.-)%s*$") or ""
		if bare ~= "" then
			local kind = if i % 2 == 1 then "Word" elseif string.sub(bare, 1, 1) == "$" then "Cash" else "Gold"
			table.insert(list, { Text = bare, Kind = kind :: any })
		end
	end
	return list
end

-- What is see-through on a piece when it is all there, so a fade can bring it back
type Faded = { Thing: any, Prop: string, Base: number }
type Piece = {
	Part: Part,
	Frame: Frame,
	lay: (z: number, stroke: number) -> (number, number), -- the room it takes, and what of it is before its frame
	pose: (on: number, x: number) -> (),
	X: number, -- its middle along the line
}

local function measure(text: string, size: number): number
	return TextService:GetTextSize(text, size, FONT, Vector2.new(4000, 400)).X
end

-- Past its place and back (Back, out)
local function back(t: number): number
	local u = t - 1
	return 1 + 2.7 * u * u * u + 1.7 * u * u
end

function Sticker.new(parent: Instance, props: { [string]: any }): Sticker
	props.BackgroundTransparency = 1
	local root: Frame = Kit.new("Frame", props, parent)
	local pieces: { Piece } = {}
	local faded: { Faded } = {}
	local lastOn, lastClear = 1, 0

	local function fades(thing: any, prop: string): any
		table.insert(faded, { Thing = thing, Prop = prop, Base = thing[prop] })
		return thing
	end

	local function letters(
		parentTo: Instance,
		text: string,
		ink: Color3,
		colour: Color3,
		z: number
	): (TextLabel, UIStroke)
		local label: TextLabel = Kit.new("TextLabel", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			Font = FONT,
			Text = text,
			TextColor3 = colour,
			ZIndex = z,
		}, parentTo)
		local edge = Kit.stroke(label, 1, ink)
		fades(label, "TextTransparency")
		fades(edge, "Transparency")
		return label, edge
	end

	local function plain(part: Part): Piece
		local frame: Frame = Kit.new("Frame", {
			Name = "Word",
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			ZIndex = 1,
		}, root)
		local shade, shadeEdge = letters(frame, part.Text, Kit.Ink, Kit.Ink, 1)
		local face, faceEdge = letters(frame, part.Text, Kit.Ink, Kit.White, 2)
		local slide = 0
		return {
			Part = part,
			Frame = frame,
			lay = function(z: number, stroke: number): (number, number)
				local wide = measure(part.Text, z * WORD)
				frame.Size = UDim2.fromOffset(wide, z * 1.2)
				for i, label in { shade, face } do
					label.Text = part.Text
					label.TextSize = z * WORD
					label.Size = UDim2.fromScale(1, 1)
					label.Position = UDim2.new(0.5, 0, 0.5, z * (DOWN + (if i == 1 then WORD_DROP else 0)))
				end
				shadeEdge.Thickness = z * stroke
				faceEdge.Thickness = z * stroke
				slide = z * SLIDE
				return wide + z * WORD_ROOM, z * WORD_ROOM / 2
			end,
			pose = function(on: number, x: number)
				frame.Position = UDim2.new(0, x - (1 - on) * (1 - on) * slide, 0.5, 0)
			end,
			X = 0,
		}
	end

	local function sticker(part: Part): Piece
		local p = PLATES[part.Kind]
		local frame: Frame = Kit.new("Frame", {
			Name = part.Kind,
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			Rotation = p.Turn,
			ZIndex = 2,
		}, root)
		local scale: UIScale = Kit.new("UIScale", {}, frame)
		local function box(z: number, colour: Color3): (Frame, UICorner)
			local made: Frame = Kit.new("Frame", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundColor3 = colour,
				BorderSizePixel = 0,
				ZIndex = z,
			}, frame)
			fades(made, "BackgroundTransparency")
			return made, Kit.new("UICorner", {}, made)
		end
		local drop, dropCorner = box(1, Kit.Ink)
		local edge, edgeCorner = box(2, Kit.Ink)
		local rim, rimCorner = box(3, Kit.White)
		local face, faceCorner = box(4, Kit.White)
		Kit.gradient(face, p.Top, p.Bottom)
		local gloss, glossCorner = box(5, Kit.White)
		gloss.BackgroundTransparency = GLOSS
		faded[#faded].Base = GLOSS
		local label, labelEdge = letters(frame, part.Text, p.Ink, Kit.White, 7)
		local cash: ImageLabel? = nil
		if part.Kind == "Cash" then
			cash = Kit.new("ImageLabel", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				Image = Kit.Textures.Cash,
				Rotation = CASH_TURN,
				ZIndex = 6,
			}, frame)
			fades(cash, "ImageTransparency")
		end
		return {
			Part = part,
			Frame = frame,
			lay = function(z: number, _stroke: number): (number, number)
				local wide = measure(part.Text, z * p.Letters) + z * p.Pad
				local high = z * p.High
				frame.Size = UDim2.fromOffset(wide, high)
				local function size(thing: Frame, corner: UICorner, grow: number, down: number)
					thing.Size = UDim2.fromOffset(wide + grow * 2, high + grow * 2)
					thing.Position = UDim2.new(0.5, 0, 0.5, down)
					corner.CornerRadius = UDim.new(0, math.min(z * p.Round + grow, high / 2 + grow))
				end
				size(drop, dropCorner, z * (p.Rim + p.Edge), z * p.Drop)
				size(edge, edgeCorner, z * (p.Rim + p.Edge), 0)
				size(rim, rimCorner, z * p.Rim, 0)
				size(face, faceCorner, 0, 0)
				gloss.Size = UDim2.fromOffset(wide - z * 0.2, high * 0.4)
				gloss.Position = UDim2.new(0.5, 0, 0.5, z * 0.07 - high * 0.3)
				glossCorner.CornerRadius = UDim.new(0, math.min(z * p.Round, high * 0.2))
				local sign = cash
				if sign then
					sign.Size = UDim2.fromOffset(z * CASH, z * CASH)
					sign.Position = UDim2.new(0, z * 0.4, 0.5, 0)
				end
				label.Text = part.Text
				label.TextSize = z * p.Letters
				label.Size = UDim2.fromScale(1, 1)
				label.Position = UDim2.new(0.5, if sign then z * 0.5 else 0, 0.5, z * DOWN)
				labelEdge.Thickness = z * p.Stroke
				return wide + z * (p.Left + p.Right), z * p.Left
			end,
			pose = function(on: number, x: number)
				frame.Position = UDim2.new(0, x, 0.5, 0)
				frame.Rotation = p.Turn - (1 - back(on)) * SLAP_TURN
				scale.Scale = 1 + (1 - on) * (1 - on) * (SLAP_FROM - 1)
			end,
			X = 0,
		}
	end

	local function pose(on: number, clear: number)
		lastOn, lastClear = on, clear
		for _, piece in pieces do
			piece.pose(on, piece.X)
		end
		-- (and it comes into sight as it is slapped on)
		local seen = (1 - clear) * math.min(on * 2.5, 1)
		for _, f in faded do
			f.Thing[f.Prop] = 1 - (1 - f.Base) * seen
		end
	end

	local function same(parts: { Part }): boolean
		if #parts ~= #pieces then
			return false
		end
		for i, part in parts do
			if part.Kind ~= pieces[i].Part.Kind then
				return false
			end
		end
		return true
	end

	local function lay(z: number, stroke: number): number
		local x = 0
		for _, piece in pieces do
			local wide, left = piece.lay(z, stroke)
			piece.X = x + left + piece.Frame.Size.X.Offset / 2
			x += wide
		end
		return x
	end

	local function set(words: string, size: number, most: number?, stroke: number?)
		local parts = Sticker.parts(words)
		if same(parts) then
			for i, part in parts do
				pieces[i].Part.Text = part.Text
			end
		else
			for _, piece in pieces do
				piece.Frame:Destroy()
			end
			table.clear(pieces)
			table.clear(faded)
			for i, part in parts do
				pieces[i] = if part.Kind == "Word" then plain(part) else sticker(part)
			end
		end
		local s = stroke or 0.13
		local wide = lay(size, s)
		if most and wide > most and wide > 0 then
			size *= most / wide
			wide = lay(size, s)
		end
		root.Size = UDim2.fromOffset(wide, size * 1.7)
		pose(lastOn, lastClear)
	end

	return { Root = root, set = set, pose = pose }
end

return Sticker
