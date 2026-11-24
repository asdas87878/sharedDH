--!strict
-- The words the moment a fish becomes yours (task t2; Hugo, 2026-11-19: "give me a selection for being caught, like for
-- the text: make it more stylised like the rest of the text UI, and it should feel better"). Five looks behind
-- Kit.CaughtLook (0 keeps Banners' own tilted "TAMED!" plate, as before), every word built like the fish tags' rarity
-- word (Kit.word: metal gradient in the rarity's tones, thick ink edge, a drop, a glow from Legendary up):
--   1 Punch: "CAUGHT!" punches in at the top centre out of a closing ring, the rarity and name rise under it
--   2 Stamp: a rarity-coloured stamp hovers, slams down with dust and a flash; the name unrolls on a ribbon under it
--   3 Banner: the old tilted plate at the left redone: it whips in, the fish's portrait pops, "CAUGHT!" drops on it
--   4 Burst: the fish's portrait bursts out of a point with rays and confetti in its rarity's colours, "CAUGHT!" over it
--   5 Slam: a rarity-coloured band slashes across the screen, "CAUGHT!" slams onto it, the screen shakes
-- Each has anticipation (a ring closing in, a hover, a pull back), an overshoot that rings down, and a clean exit with
-- its own small wind-up. Like CatchShow, a look is a pose of the time since it began (pose(t)), so the game plays it
-- frame by frame and a capture can stop it at any moment. Sheet: docs/attachments/caught-text-options-1.png (GIFs
-- caught-text-<n>.gif), by tools/ui/caught_text/capture.py.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Kit = require(script.Parent.Kit)
local Portrait = require(script.Parent.Portrait)
local Shake = require(script.Parent.Parent.Lib.Shake)

local CaughtText = {}

-- (Word: in place of "CAUGHT!", a colour's or a size's own; Great: Config.greatCatch, the plate stays longer; Bonus: the
-- max Oxygen its first catch pays at the Index; Note: in place of what it earns)
export type Info = {
	Id: string,
	Name: string,
	Tier: string,
	Earns: number?,
	New: boolean?,
	Word: string?,
	Great: boolean?,
	Bonus: number?,
	Note: string?,
}
export type Show = {
	root: Frame,
	length: number, -- seconds until it is gone
	pose: (t: number) -> (),
	impact: number?, -- when it hits (a camera shake then, `shake` strong)
	shake: number?,
}

local NAMES = { "Punch", "Stamp", "Banner", "Burst", "Slam" }
CaughtText.Names = NAMES

-- the look in play: Kit.CaughtLook, or in Studio the workspace's "CaughtLook" number
function CaughtText.look(): number
	local own = workspace:GetAttribute("CaughtLook")
	if RunService:IsStudio() and type(own) == "number" then
		return own
	end
	return Kit.CaughtLook
end

---------------------------------------------------------------------------------------------------------------------
-- easing: a share of the way through a move from a to a + d, and the curves
local function at(t: number, a: number, d: number): number
	return math.clamp((t - a) / d, 0, 1)
end
local function backOut(x: number): number
	local c = 1.9
	return 1 + (c + 1) * (x - 1) ^ 3 + c * (x - 1) ^ 2
end
local function backIn(x: number): number
	local c = 1.7
	return (c + 1) * x ^ 3 - c * x ^ 2
end
local function quadOut(x: number): number
	return 1 - (1 - x) ^ 2
end
local function quadIn(x: number): number
	return x * x
end
local function lerp(a: number, b: number, x: number): number
	return a + (b - a) * x
end
-- an overshoot that rings down: 0 at s = 0 (seconds since the hit), over 1 by about a fifth (0.23 at the top of the
-- first swing), settled in half a second
local function settle(s: number): number
	if s <= 0 then
		return 0
	end
	return 1 - math.exp(-7 * s) * math.cos(15 * s)
end
-- a bump: 1 at a, gone d seconds later
local function bump(t: number, a: number, d: number): number
	if t < a then
		return 0
	end
	return (1 - at(t, a, d)) ^ 2
end
local function P(x: number, y: number): UDim2
	return UDim2.fromOffset(x, y)
end

---------------------------------------------------------------------------------------------------------------------
-- the rarities' four tones, as the fish tags have them (Tags.luau, PAL): the lit top, the colour, the shade, the deepest
local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end
local PAL: { [string]: Kit.Pal } = {
	Common = { Light = rgb(252, 253, 255), Mid = rgb(198, 206, 218), Dark = rgb(128, 140, 160), Deep = rgb(58, 66, 84) },
	Uncommon = { Light = rgb(222, 255, 180), Mid = rgb(104, 224, 84), Dark = rgb(34, 160, 64), Deep = rgb(14, 80, 40) },
	Rare = { Light = rgb(200, 238, 255), Mid = rgb(76, 168, 255), Dark = rgb(36, 94, 226), Deep = rgb(18, 40, 124) },
	Epic = { Light = rgb(244, 210, 255), Mid = rgb(186, 98, 255), Dark = rgb(118, 46, 216), Deep = rgb(58, 18, 120) },
	Legendary = Kit.GoldPal,
	Mythic = { Light = rgb(255, 210, 180), Mid = rgb(255, 72, 98), Dark = rgb(192, 22, 106), Deep = rgb(92, 8, 56) },
	Secret = { Light = rgb(255, 255, 255), Mid = rgb(200, 140, 255), Dark = rgb(110, 60, 200), Deep = rgb(26, 14, 46) },
}
local BIG: { [string]: boolean } = { Legendary = true, Mythic = true, Secret = true }
local LOUD: { [string]: number } =
	{ Common = 0, Uncommon = 0, Rare = 1, Epic = 1, Legendary = 2, Mythic = 2, Secret = 2 }
local BANGERS = Enum.Font.Bangers
local SHARP = Enum.Font.GothamBlack

local function palOf(tier: string): Kit.Pal
	return PAL[tier] or PAL.Common
end

---------------------------------------------------------------------------------------------------------------------
-- pieces

-- A look's frames: the root (placed on the HUD, never moved), the body in it (moved, scaled and faded by the pose)
-- and fx over it (flashes, rings, specks: they fade by their own numbers)
local function frames(parent: Instance, w: number, h: number): (Frame, Frame, UIScale, Frame)
	local root: Frame = Kit.new("Frame", {
		Name = "Caught",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = P(w, h),
		BackgroundTransparency = 1,
		ZIndex = 30,
	}, parent)
	local body: Frame = Kit.new("Frame", {
		Name = "Body",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ZIndex = 30,
	}, root)
	local scale: UIScale = Kit.new("UIScale", {}, body)
	local fx: Frame = Kit.new("Frame", {
		Name = "Fx",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ZIndex = 30,
	}, body)
	return root, body, scale, fx
end

local function scaler(obj: Instance): UIScale
	return Kit.new("UIScale", {}, obj)
end

-- Fades everything under `root` (but what is under `skip`) as one: alpha 1 is as built, 0 is gone
local function fader(root: Instance, skip: { Instance }): (number) -> ()
	local list: { { inst: Instance, prop: string, base: number } } = {}
	local function add(inst: Instance, prop: string)
		table.insert(list, { inst = inst, prop = prop, base = (inst :: any)[prop] })
	end
	for _, d in root:GetDescendants() do
		local skipped = false
		for _, s in skip do
			if d == s or d:IsDescendantOf(s) then
				skipped = true
				break
			end
		end
		if skipped then
			continue
		end
		if d:IsA("TextLabel") then
			add(d, "TextTransparency")
			add(d, "TextStrokeTransparency")
			add(d, "BackgroundTransparency")
		elseif d:IsA("ImageLabel") or d:IsA("ViewportFrame") then
			add(d, "ImageTransparency")
			add(d, "BackgroundTransparency")
		elseif d:IsA("CanvasGroup") then
			add(d, "GroupTransparency")
		elseif d:IsA("Frame") then
			add(d, "BackgroundTransparency")
		elseif d:IsA("UIStroke") then
			add(d, "Transparency")
		end
	end
	local last = -1
	return function(alpha: number)
		alpha = math.clamp(alpha, 0, 1)
		if alpha == last then
			return
		end
		last = alpha
		for _, e in list do
			(e.inst :: any)[e.prop] = 1 - (1 - e.base) * alpha
		end
	end
end

local function word(
	parent: Instance,
	text: string,
	size: number,
	font: Enum.Font,
	pal: Kit.Pal,
	glow: boolean,
	z: number,
	pos: UDim2
): Kit.Word
	return Kit.word(parent, {
		Text = text,
		TextSize = size,
		Font = font,
		Pal = pal,
		Glow = glow,
		ZIndex = z,
		Position = pos,
		Edge = if font == BANGERS then 0.12 else nil,
	})
end

-- The rarity's word and the fish's name on one line, centred on `pos` (anchor: 0.5 centred, 0 from its left)
local function nameRow(parent: Instance, info: Info, z: number, pos: UDim2, anchorX: number?): Frame
	local row: Frame = Kit.new("Frame", {
		AnchorPoint = Vector2.new(anchorX or 0.5, 0.5),
		Position = pos,
		BackgroundTransparency = 1,
		ZIndex = z,
	}, parent)
	local pal = palOf(info.Tier)
	local tier = Kit.word(row, {
		Text = string.upper(info.Tier),
		TextSize = 14,
		Font = SHARP,
		Pal = pal,
		Glow = BIG[info.Tier] == true,
		ZIndex = z,
		AnchorPoint = Vector2.new(0, 0.5),
	})
	local name = Kit.word(row, {
		Text = info.Name,
		TextSize = 19,
		Font = SHARP,
		Pal = Kit.WhitePal,
		ZIndex = z,
		AnchorPoint = Vector2.new(0, 0.5),
	})
	local gap = 7
	local high = math.max(tier.high, name.high)
	row.Size = P(tier.wide + gap + name.wide, high)
	tier.root.Position = UDim2.new(0, 0, 0.5, 1)
	name.root.Position = UDim2.new(0, tier.wide + gap, 0.5, 0)
	return row
end

-- What the fish earns a second in a tank: the cash icon and the sum on a dark pill (nil earns: the pill is hidden).
-- `words`, with `icon` (nil: none) and `tone`: those in its place
local function chip(
	parent: Instance,
	earns: number?,
	z: number,
	pos: UDim2,
	words: string?,
	icon: string?,
	tone: Color3?
): Frame
	local pill: Frame = Kit.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = pos,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = P(0, 20),
		BackgroundColor3 = Kit.Deep,
		BackgroundTransparency = 0.2,
		Visible = earns ~= nil or words ~= nil,
		ZIndex = z,
	}, parent)
	Kit.corner(pill, 999)
	Kit.stroke(pill, 2, Kit.Ink)
	local bare = words ~= nil and icon == nil
	Kit.new("UIPadding", { PaddingLeft = UDim.new(0, if bare then 9 else 4), PaddingRight = UDim.new(0, 9) }, pill)
	Kit.new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 4),
	}, pill)
	Kit.new("ImageLabel", {
		Size = P(17, 17),
		BackgroundTransparency = 1,
		Image = if words then icon or "" else Kit.Textures.Cash,
		Visible = not bare,
		ScaleType = Enum.ScaleType.Fit,
		LayoutOrder = 1,
		ZIndex = z + 1,
	}, pill)
	Kit.text({
		AutomaticSize = Enum.AutomaticSize.X,
		Size = P(0, 20),
		TextSize = 12.5,
		TextColor3 = tone or Kit.Cash,
		Text = words or ("+" .. Kit.rate(earns or 0)),
		LayoutOrder = 2,
		ZIndex = z + 1,
	}, pill)
	return pill
end

-- A bursting badge (as Banners'): an eight-pointed star of two squares, one turned, with a word on it
local function badge(parent: Instance, text: string, size: number, z: number): Frame
	local holder: Frame = Kit.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = P(size, size),
		BackgroundTransparency = 1,
		ZIndex = z,
	}, parent)
	for layer = 1, 2 do
		for _, angle in { 0, 45 } do
			local square = Kit.new("Frame", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromScale(0.72, 0.72),
				Rotation = angle,
				BackgroundColor3 = Kit.Danger,
				BorderSizePixel = 0,
				ZIndex = z + layer - 1,
			}, holder)
			Kit.corner(square, size * 0.08)
			if layer == 1 then
				Kit.stroke(square, 2, Kit.Ink)
			end
		end
	end
	Kit.text({ Size = UDim2.fromScale(1, 1), TextSize = size * 0.27, Text = text, ZIndex = z + 2 }, holder)
	return holder
end

local RAY = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 1),
	NumberSequenceKeypoint.new(0.3, 0.6),
	NumberSequenceKeypoint.new(0.5, 0.75),
	NumberSequenceKeypoint.new(0.7, 0.6),
	NumberSequenceKeypoint.new(1, 1),
})

-- Rays through one point, fading out at their ends
local function rays(parent: Instance, pos: UDim2, size: number, count: number, colour: Color3, z: number): Frame
	local holder: Frame = Kit.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = pos,
		Size = P(size, size),
		BackgroundTransparency = 1,
		ZIndex = z,
	}, parent)
	for i = 1, count do
		local bar = Kit.new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(1, 0.1),
			Rotation = (i - 1) * 180 / count,
			BackgroundColor3 = colour,
			BorderSizePixel = 0,
			ZIndex = z,
		}, holder)
		Kit.new("UIGradient", { Transparency = RAY }, bar)
	end
	return holder
end

-- A round token in the rarity's colours with the fish's picture in it
local function token(parent: Instance, info: Info, size: number, z: number, pos: UDim2): Frame
	local disc: Frame = Kit.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = pos,
		Size = P(size, size),
		BackgroundColor3 = Kit.White,
		ZIndex = z,
	}, parent)
	Kit.corner(disc, 999)
	Kit.stroke(disc, 3.5, Kit.Ink)
	local fill: UIGradient = Kit.new("UIGradient", {}, disc)
	fill.Color, fill.Rotation = Kit.tierFill(info.Tier, Config.Tiers)
	local inner = Kit.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(1, -6, 1, -6),
		BackgroundTransparency = 1,
		ZIndex = z,
	}, disc)
	Kit.corner(inner, 999)
	Kit.stroke(inner, 2, Kit.White, 0.35)
	local picture = Portrait.new(disc, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.9, 0.9),
		ZIndex = z + 1,
	})
	picture.Frame.Visible = picture.show(info.Id)
	return disc
end

-- A ring (an outline only), placed and sized by the pose
local function ring(parent: Instance, colour: Color3, thick: number, z: number): (Frame, UIStroke)
	local frame: Frame = Kit.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		Visible = false,
		ZIndex = z,
	}, parent)
	Kit.corner(frame, 999)
	return frame, Kit.stroke(frame, thick, colour)
end

-- Specks thrown from a point (confetti, dust). Seeded, so a pose is the same every time it is asked for
type Speck = { f: Frame, angle: number, speed: number, spin: number, life: number, size: number, from: number }
local function specks(parent: Instance, count: number, seed: number, colours: { Color3 }, z: number): { Speck }
	local rng = Random.new(seed)
	local list: { Speck } = {}
	for i = 1, count do
		local size = rng:NextNumber(5, 11)
		local round = i % 3 == 0
		local f: Frame = Kit.new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Size = P(size, if round then size else size * 0.62),
			BackgroundColor3 = colours[(i - 1) % #colours + 1],
			Visible = false,
			ZIndex = z,
		}, parent)
		if round then
			Kit.corner(f, 999)
		end
		Kit.stroke(f, 1.5, Kit.Ink)
		table.insert(list, {
			f = f,
			angle = rng:NextNumber(0, math.pi * 2),
			speed = rng:NextNumber(0.55, 1),
			spin = rng:NextNumber(-540, 540),
			life = rng:NextNumber(0.55, 0.95),
			size = size,
			from = rng:NextNumber(0, 1),
		})
	end
	return list
end

-- Their pose: thrown from (x, y) at t0, `reach` units out at full speed, falling by `fall`; squashed into an ellipse
-- `sx` by `sy` (1, 1: round); `start` units out when thrown (from the edge of something)
local function specksPose(
	list: { Speck },
	t: number,
	t0: number,
	x: number,
	y: number,
	reach: number,
	fall: number,
	alpha: number,
	sx: number?,
	sy: number?,
	start: number?
)
	local ax, ay = sx or 1, sy or 1
	for _, s in list do
		local age = t - t0
		if age < 0 or age > s.life then
			s.f.Visible = false
			continue
		end
		local k = age / s.life
		local out = (start or 0) + reach * s.speed * quadOut(k)
		s.f.Visible = true
		s.f.Position = P(x + math.cos(s.angle) * out * ax, y + math.sin(s.angle) * out * ay + fall * k * k)
		s.f.Rotation = s.spin * age
		s.f.BackgroundTransparency = 1 - (1 - k ^ 3) * alpha
		local stroke = s.f:FindFirstChildOfClass("UIStroke")
		if stroke then
			stroke.Transparency = s.f.BackgroundTransparency
		end
	end
end

---------------------------------------------------------------------------------------------------------------------
-- 1 Punch: "CAUGHT!" punches in at the top centre out of a ring closing in, the rarity and name rise under it
local function punch(parent: Instance, info: Info): Show
	local pal = palOf(info.Tier)
	local big = BIG[info.Tier] == true
	local W, H = 380, 150
	local root, body, bodyScale, fx = frames(parent, W, H)
	local cx, wy = W / 2, 44
	local inRing, inStroke = ring(fx, pal.Light, 3, 31)
	local outRing, outStroke = ring(fx, Kit.White, 5, 31)
	local w = word(body, "CAUGHT!", 54, BANGERS, pal, true, 34, P(cx, wy))
	local wScale = scaler(w.root)
	local row = nameRow(body, info, 34, P(cx, 96))
	local pill = chip(body, info.Earns, 34, P(cx, 126))
	local pillScale = scaler(pill)
	local new = badge(body, "NEW!", 42, 38)
	new.Position = P(cx + w.wide / 2 + 4, wy - 26)
	new.Visible = info.New == true
	local newScale = scaler(new)
	local dots = specks(fx, if big then 18 else 10, 11, { pal.Light, pal.Mid, Kit.White }, 31)
	local fade = fader(body, { fx })
	local HIT = 0.2
	local L = 2.75
	local E = L - 0.34
	local pose = function(t: number)
		-- the ring closes in on where the word lands (the wind-up), the word punches through it and rings out a wave
		local x = at(t, 0, HIT)
		inRing.Visible = t < HIT
		local r = lerp(250, 30, quadIn(x))
		inRing.Size = P(r, r * 0.42)
		inRing.Position = P(cx, wy)
		inStroke.Transparency = lerp(1, 0.1, x)
		local o = at(t, HIT, 0.4)
		outRing.Visible = t >= HIT and o < 1
		local orr = lerp(60, 420, quadOut(o))
		outRing.Size = P(orr, orr * 0.4)
		outRing.Position = P(cx, wy)
		outStroke.Transparency = o
		outStroke.Thickness = lerp(6, 1, o)
		-- the word: unseen until it is close, then from huge down past its size (the hit), ringing back to it, and
		-- breathing while it stays
		w.root.Visible = t >= 0.07
		local s
		if t < HIT then
			s = lerp(2.7, 0.84, quadIn(at(t, 0.07, HIT - 0.07)))
		else
			s = 0.84 + 0.16 * settle(t - HIT)
			s *= 1 + 0.018 * math.sin((t - HIT) * 5.5) * at(t, HIT + 0.4, 0.3)
		end
		wScale.Scale = s
		w.root.Rotation = if t < HIT then lerp(-16, -7, at(t, 0.07, HIT - 0.07)) else -7 + 4 * settle(t - HIT)
		specksPose(dots, t, HIT, cx, wy, 150, 60, 1, 1.3, 0.55, 40)
		-- the rarity and the name rise under it, then the earnings pop
		local rx = at(t, 0.3, 0.3)
		row.Visible = t >= 0.3
		row.Position = P(cx, 96 + 18 * (1 - backOut(rx)))
		pill.Visible = info.Earns ~= nil and t >= 0.46
		pillScale.Scale = settle(t - 0.46)
		newScale.Scale = settle(t - 0.52)
		new.Rotation = 14 - 70 * (1 - settle(t - 0.52))
		-- the exit: a breath in (bigger), then up and away, shrinking
		local e1 = at(t, E, 0.08)
		local e2 = at(t, E + 0.08, 0.26)
		bodyScale.Scale = (1 + 0.07 * quadOut(e1)) * lerp(1, 0.45, backIn(e2))
		body.Position = P(0, -26 * quadIn(e2))
		fade(1 - quadIn(e2))
		if e2 > 0 then
			for _, d in dots do
				d.f.Visible = false
			end
		end
	end
	return { root = root, length = L, pose = pose }
end

---------------------------------------------------------------------------------------------------------------------
-- 2 Stamp: the stamp hovers, lifts a touch (the wind-up), slams down with a flash and dust; the name unrolls under it
local function stamp(parent: Instance, info: Info): Show
	local pal = palOf(info.Tier)
	local big = BIG[info.Tier] == true
	local W, H = 340, 160
	local root, body, bodyScale, fx = frames(parent, W, H)
	local cx, sy = W / 2, 50
	local SW, SH = 236, 80
	local plate: Frame = Kit.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = P(cx, sy),
		Size = P(SW, SH),
		BackgroundColor3 = pal.Dark,
		BackgroundTransparency = 0.45,
		ZIndex = 32,
	}, body)
	Kit.corner(plate, 12)
	Kit.stroke(plate, 9, Kit.Ink)
	local face: Frame = Kit.new("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ZIndex = 33,
	}, plate)
	Kit.corner(face, 12)
	Kit.stroke(face, 5, pal.Mid)
	local line: Frame = Kit.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(1, -14, 1, -14),
		BackgroundTransparency = 1,
		ZIndex = 33,
	}, plate)
	Kit.corner(line, 7)
	Kit.stroke(line, 2, pal.Light, 0.15)
	-- a star either side of the word, as a stamp has
	for _, side in { -1, 1 } do
		local star: Frame = Kit.new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, side * (SW / 2 - 20), 0.5, 0),
			Size = P(11, 11),
			Rotation = 45,
			BackgroundColor3 = pal.Light,
			ZIndex = 34,
		}, plate)
		Kit.stroke(star, 2, Kit.Ink)
	end
	word(plate, "CAUGHT!", 44, SHARP, pal, big, 35, UDim2.fromScale(0.5, 0.5))
	local flash: Frame = Kit.new("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Kit.White,
		BackgroundTransparency = 1,
		ZIndex = 40,
	}, plate)
	Kit.corner(flash, 12)
	local plateScale = scaler(plate)
	local shadow: Frame = Kit.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = P(cx + 4, sy + 6),
		Size = P(SW, SH),
		BackgroundColor3 = Kit.Ink,
		BackgroundTransparency = 0.45,
		ZIndex = 31,
	}, body)
	Kit.corner(shadow, 12)
	local shadowScale = scaler(shadow)
	local dust = specks(fx, if big then 22 else 14, 22, { pal.Light, Kit.White, pal.Mid }, 31)
	-- the ribbon: a dark pill that unrolls from its middle with the rarity and the name
	local ribbon: Frame = Kit.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = P(cx, 112),
		Size = P(0, 32),
		BackgroundColor3 = Kit.Deep,
		BackgroundTransparency = 0.1,
		ClipsDescendants = true,
		ZIndex = 33,
	}, body)
	Kit.corner(ribbon, 999)
	Kit.stroke(ribbon, 2.5, Kit.Ink)
	local row = nameRow(ribbon, info, 34, UDim2.fromScale(0.5, 0.5))
	local ribbonWide = row.Size.X.Offset + 34
	local pill = chip(body, info.Earns, 34, P(cx, 144))
	local pillScale = scaler(pill)
	local new = badge(body, "NEW!", 42, 42)
	new.Position = P(cx + SW / 2 - 6, sy - SH / 2 - 4)
	new.Visible = info.New == true
	local newScale = scaler(new)
	local fade = fader(body, { fx, flash })
	local HOVER, HIT = 0.16, 0.25
	local L = 2.8
	local E = L - 0.36
	local pose = function(t: number)
		-- hover high and see-through, lifting a little more (the wind-up), then down hard, a hair past flat, back
		local s, rot
		if t < HOVER then
			local x = at(t, 0, HOVER)
			s = lerp(1.65, 1.8, quadOut(x))
			rot = lerp(-17, -19, x)
		elseif t < HIT then
			local x = at(t, HOVER, HIT - HOVER)
			s = lerp(1.8, 0.93, quadIn(x))
			rot = lerp(-19, -7, quadIn(x))
		else
			s = 0.93 + 0.07 * settle(t - HIT)
			rot = -7
		end
		local inAlpha = if t < HIT then lerp(0, 0.55, at(t, 0, HOVER)) + 0.45 * at(t, HOVER, HIT - HOVER) else 1
		-- the exit: it lifts (bigger, turning) and fades as a stamp leaves the paper
		local e = at(t, E, 0.32)
		s *= 1 + 0.18 * quadOut(e)
		rot += 6 * quadOut(e)
		plateScale.Scale = s
		plate.Rotation = rot
		-- the shadow stays on the paper: far off while it hovers, under it once it lands
		local lift = math.max(s - 1, 0)
		shadowScale.Scale = s
		shadow.Rotation = rot
		shadow.Position = P(cx + 4 + 30 * lift, sy + 6 + 50 * lift)
		shadow.Visible = t < E + 0.32
		flash.BackgroundTransparency = 1 - 0.85 * bump(t, HIT, 0.28)
		-- the slam shakes everything a moment
		local k = bump(t, HIT, 0.35)
		body.Position = P(math.sin(t * 90) * 5 * k, math.cos(t * 77) * 4 * k)
		specksPose(dust, t, HIT, cx, sy, 70, 30, 1, 1, 0.42, 1)
		for _, d in dust do
			-- (from the plate's edge all round, not from its middle)
			if d.f.Visible then
				local edge = P(math.cos(d.angle) * SW * 0.5, math.sin(d.angle) * SH * 0.5)
				d.f.Position += edge
			end
		end
		-- the ribbon unrolls, the earnings and the badge stamp in after it
		local rx = at(t, 0.42, 0.24)
		local rOut = at(t, E, 0.2)
		ribbon.Size = P(ribbonWide * backOut(rx) * (1 - quadIn(rOut)), 32)
		ribbon.Visible = rx > 0 and rOut < 1
		pill.Visible = info.Earns ~= nil and t >= 0.6
		pillScale.Scale = settle(t - 0.6)
		local nb = t - 0.55
		newScale.Scale = if nb < 0
			then 0
			elseif nb < 0.08 then lerp(2.2, 0.9, quadIn(nb / 0.08))
			else 0.9 + 0.1 * settle(nb - 0.08)
		new.Rotation = 12
		fade(inAlpha * (1 - e))
		bodyScale.Scale = 1
	end
	return { root = root, length = L, pose = pose }
end

---------------------------------------------------------------------------------------------------------------------
-- 3 Banner: the tilted plate at the left whips in past its place and back, the portrait pops out of it, "CAUGHT!"
-- drops on it, the name slides in under it
local function plateFill(tier: string): (ColorSequence, number)
	if BIG[tier] then
		return Kit.tierFill(tier, Config.Tiers)
	end
	local p = palOf(tier)
	return ColorSequence.new(p.Mid, Kit.darker(p.Dark, 0.35)), 90
end

local function banner(parent: Instance, info: Info): Show
	local pal = palOf(info.Tier)
	local big = BIG[info.Tier] == true
	local W, H = 320, 130
	local root, body, _, fx = frames(parent, W, H)
	root.AnchorPoint = Vector2.new(0, 0)
	body.Rotation = -5
	local PX, PY, PW, PH = 18, 26, 262, 66
	local plate: CanvasGroup = Kit.new("CanvasGroup", {
		Position = P(PX, PY),
		Size = P(PW, PH),
		BackgroundColor3 = Kit.White,
		BorderSizePixel = 0,
		ZIndex = 31,
	}, body)
	Kit.corner(plate, 11)
	local fill: UIGradient = Kit.new("UIGradient", {}, plate)
	fill.Color, fill.Rotation = plateFill(info.Tier)
	local spin = rays(plate, P(42, PH / 2), 240, 8, Kit.White, 1)
	local gloss = Kit.new("Frame", {
		Position = P(3, 3),
		Size = UDim2.new(1, -6, 0, 22),
		BackgroundColor3 = Kit.White,
		BackgroundTransparency = 0.84,
		BorderSizePixel = 0,
		ZIndex = 2,
	}, plate)
	Kit.corner(gloss, 8)
	local rim: Frame = Kit.new("Frame", {
		Position = P(PX, PY),
		Size = P(PW, PH),
		BackgroundTransparency = 1,
		ZIndex = 32,
	}, body)
	Kit.corner(rim, 11)
	Kit.stroke(rim, 3.5, Kit.Ink)
	local inner = Kit.new("Frame", {
		Position = P(2, 2),
		Size = UDim2.new(1, -4, 1, -4),
		BackgroundTransparency = 1,
		ZIndex = 32,
	}, rim)
	Kit.corner(inner, 9)
	Kit.stroke(inner, 1.5, Kit.White, 0.4)
	local disc = token(body, info, 84, 34, P(PX + 34, PY + PH / 2 - 4))
	local discScale = scaler(disc)
	local wx = PX + 76 + (PW - 76) / 2
	local said = info.Word or "CAUGHT!"
	local w = word(body, said, if #said > 8 then 26 else 36, SHARP, pal, big or info.Great == true, 36, P(wx, PY + 24))
	local wScale = scaler(w.root)
	local pill = chip(body, info.Earns, 36, P(wx, PY + PH - 14), info.Note, nil, Kit.White)
	local pillScale = scaler(pill)
	local bonus: Frame? = nil
	local bonusScale: UIScale? = nil
	if info.Bonus then
		local made = chip(
			body,
			nil,
			36,
			P(PX + 104, PY + PH + 46),
			"+" .. Config.wholeNumber(info.Bonus) .. " MAX: CLAIM IN INDEX",
			Kit.Textures.Oxygen,
			Kit.Sun
		)
		bonus, bonusScale = made, scaler(made)
	end
	local row = nameRow(body, info, 34, P(PX + 8, PY + PH + 20), 0)
	local new = badge(body, "NEW!", 44, 40)
	new.Position = P(PX + PW + 2, PY) -- Hugo, 2026-11-19: "slightly to the right and down, just a touch"
	new.Visible = info.New == true
	local newScale = scaler(new)
	local shine = specks(fx, if big then 14 else 8, 33, { Kit.White, pal.Light }, 39)
	local fade = fader(body, { fx })
	local L = if info.Great then 3.4 else 2.4
	local E = L - 0.32
	local pose = function(t: number)
		-- in from the left, past its place and back; out the same way after a little pull the other way (the wind-up)
		local x = at(t, 0, 0.32)
		local e1 = at(t, E, 0.08)
		local e2 = at(t, E + 0.08, 0.24)
		local off = lerp(-380, 0, backOut(x)) + 14 * quadOut(e1) * (1 - e2) + lerp(0, -400, backIn(e2))
		body.Position = P(off, 0)
		spin.Rotation = t * 22
		-- the portrait pops out of the plate, turning, and sparkles
		-- (all of it comes in with the plate: for a quarter of a second the plate was an empty grey box, 2026-11-24)
		discScale.Scale = settle(t - 0.04) * (1 + 0.04 * math.sin((t - 0.04) * 5) * at(t, 0.7, 0.3))
		disc.Rotation = -30 * (1 - settle(t - 0.04)) + 5
		specksPose(shine, t, 0.1, PX + 34, PY + PH / 2 - 4, 70, 20, 1, 1, 1, 34)
		-- the word drops in from above, too big, lands and rings
		local wt = t - 0.06
		w.root.Visible = wt >= 0
		w.root.Position = P(wx, PY + 24 - 30 * (1 - quadIn(at(t, 0.06, 0.1))))
		wScale.Scale = if wt < 0.1 then lerp(1.5, 0.88, quadIn(wt / 0.1)) else 0.88 + 0.12 * settle(wt - 0.1)
		-- the earnings, the name under it, the badge
		pill.Visible = (info.Earns ~= nil or info.Note ~= nil) and t >= 0.28
		pillScale.Scale = settle(t - 0.28)
		if bonus and bonusScale then
			bonus.Visible = t >= 0.55
			bonusScale.Scale = settle(t - 0.55)
		end
		local rx = at(t, 0.18, 0.3)
		row.Visible = rx > 0
		row.Position = P(PX + 8 - 50 * (1 - backOut(rx)), PY + PH + 20)
		newScale.Scale = settle(t - 0.38)
		new.Rotation = 12 - 80 * (1 - settle(t - 0.38))
		fade(1 - 0.5 * e2)
		for _, d in shine do
			d.f.Visible = d.f.Visible and e2 == 0
		end
	end
	return { root = root, length = L, pose = pose }
end

---------------------------------------------------------------------------------------------------------------------
-- 4 Burst: a point of light draws in (the wind-up), the portrait bursts out of it with rays, a shock ring and
-- confetti in the rarity's colours; "CAUGHT!" pops over it, the name under it; it all sucks back into the point
local function burst(parent: Instance, info: Info): Show
	local pal = palOf(info.Tier)
	local big = BIG[info.Tier] == true
	local W, H = 360, 210
	local root, body, bodyScale, fx = frames(parent, W, H)
	local cx, ty = W / 2, 98
	local spin = rays(body, P(cx, ty), 250, if big then 12 else 9, pal.Light, 31)
	local spinScale = scaler(spin)
	local core: Frame = Kit.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = P(cx, ty),
		Size = P(40, 40),
		BackgroundColor3 = Kit.White,
		ZIndex = 33,
	}, fx)
	Kit.corner(core, 999)
	Kit.stroke(core, 6, pal.Light, 0.3)
	local coreScale = scaler(core)
	local shock, shockStroke = ring(fx, Kit.White, 5, 32)
	local disc = token(body, info, 84, 34, P(cx, ty))
	local discScale = scaler(disc)
	local w = word(body, "CAUGHT!", 48, BANGERS, pal, true, 37, P(cx, 32))
	local wScale = scaler(w.root)
	local row = nameRow(body, info, 36, P(cx, 156))
	local pill = chip(body, info.Earns, 36, P(cx, 183))
	local pillScale = scaler(pill)
	local new = badge(body, "NEW!", 42, 40)
	new.Position = P(cx + 44, ty - 40)
	new.Visible = info.New == true
	local newScale = scaler(new)
	local confetti =
		specks(fx, ({ 16, 24, 34 })[LOUD[info.Tier] + 1], 44, { pal.Light, pal.Mid, pal.Dark, Kit.White }, 36)
	local fade = fader(body, { fx })
	local POP = 0.2
	local L = 2.8
	local E = L - 0.34
	local pose = function(t: number)
		-- the point: grows, then draws in tight just before the pop
		local cs
		if t < 0.12 then
			cs = quadOut(at(t, 0, 0.12)) * 0.9
		elseif t < POP then
			cs = lerp(0.9, 0.35, quadIn(at(t, 0.12, POP - 0.12)))
		else
			cs = lerp(0.35, 2.4, quadOut(at(t, POP, 0.18)))
		end
		local e1 = at(t, E, 0.08)
		local e2 = at(t, E + 0.08, 0.26)
		core.Visible = (t < POP + 0.18) or (e2 > 0 and e2 < 1)
		if e2 > 0 then
			cs = 0.6 * math.sin(math.pi * e2)
		end
		coreScale.Scale = cs
		core.BackgroundTransparency = if t < POP then 0 elseif e2 > 0 then 0 else at(t, POP, 0.18)
		local sh = at(t, POP, 0.45)
		shock.Visible = t >= POP and sh < 1
		local sr = lerp(70, 360, quadOut(sh))
		shock.Size = P(sr, sr)
		shock.Position = P(cx, ty)
		shockStroke.Transparency = sh
		shockStroke.Thickness = lerp(8, 1, sh)
		-- the portrait and rays burst out past their size and ring back; the rays turn all the while
		local ds = settle(t - POP)
		discScale.Scale = ds * (1 + 0.03 * math.sin((t - POP) * 5) * at(t, POP + 0.5, 0.3))
		disc.Rotation = -18 * (1 - ds)
		spinScale.Scale = quadOut(at(t, POP, 0.3))
		spin.Rotation = t * 35
		specksPose(confetti, t, POP, cx, ty, 170, 120, 1 - e2, 1.2, 1, 30)
		-- "CAUGHT!" pops over it, the rest rises in after
		local wt = t - 0.3
		w.root.Visible = wt >= 0
		wScale.Scale = settle(wt) * (1 + 0.02 * math.sin(wt * 6) * at(t, 0.8, 0.3))
		w.root.Rotation = -6 + 6 * (1 - settle(wt))
		local rx = at(t, 0.42, 0.3)
		row.Visible = rx > 0
		row.Position = P(cx, 156 + 16 * (1 - backOut(rx)))
		pill.Visible = info.Earns ~= nil and t >= 0.54
		pillScale.Scale = settle(t - 0.54)
		newScale.Scale = settle(t - 0.6)
		new.Rotation = 14 - 60 * (1 - settle(t - 0.6))
		-- the exit: it all swells a hair, then sucks back into the point
		bodyScale.Scale = (1 + 0.06 * quadOut(e1)) * (1 - backIn(e2) * 0.92)
		body.Position = P(0, 0)
		fade(1 - e2 ^ 2)
	end
	return { root = root, length = L, pose = pose }
end

---------------------------------------------------------------------------------------------------------------------
-- 5 Slam: a hairline streaks across (the wind-up), opens into a rarity-coloured band, "CAUGHT!" slams onto it from
-- the camera, white flash, the screen shakes; the name slides in from the right; the band snaps shut to leave
local BAND_ENDS = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 1),
	NumberSequenceKeypoint.new(0.18, 0.05),
	NumberSequenceKeypoint.new(0.82, 0.05),
	NumberSequenceKeypoint.new(1, 1),
})

local function slam(parent: Instance, info: Info): Show
	local pal = palOf(info.Tier)
	local W, H = 600, 160
	local root, body, bodyScale, fx = frames(parent, W, H)
	local cx, by = W / 2, 54
	local BW, BH = 620, 72
	local band: Frame = Kit.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = P(cx, by),
		Size = P(BW, BH),
		Rotation = -4,
		BackgroundColor3 = Kit.White,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		ZIndex = 31,
	}, body)
	Kit.new("UIGradient", {
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, pal.Deep),
			ColorSequenceKeypoint.new(0.5, pal.Dark),
			ColorSequenceKeypoint.new(1, pal.Deep),
		}),
		Transparency = BAND_ENDS,
	}, band)
	local edges: { Frame } = {}
	for _, y in { 0, 1 } do
		local edge = Kit.new("Frame", {
			AnchorPoint = Vector2.new(0, y),
			Position = UDim2.fromScale(0, y),
			Size = UDim2.new(1, 0, 0, 4),
			BackgroundColor3 = pal.Light,
			BorderSizePixel = 0,
			ZIndex = 32,
		}, band)
		Kit.new("UIGradient", { Transparency = BAND_ENDS }, edge)
		table.insert(edges, edge)
	end
	-- speed lines streaking along the band after the hit
	local streaks: { Frame } = {}
	local rng = Random.new(55)
	for i = 1, 7 do
		local s: Frame = Kit.new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Size = P(rng:NextNumber(60, 140), rng:NextNumber(2, 4)),
			Position = P(0, 10 + (i - 1) * 9),
			BackgroundColor3 = Kit.White,
			BorderSizePixel = 0,
			Visible = false,
			ZIndex = 32,
		}, band)
		s:SetAttribute("Start", rng:NextNumber(-0.3, 0.2))
		s:SetAttribute("Speed", rng:NextNumber(1.6, 2.6))
		table.insert(streaks, s)
	end
	local flash: Frame = Kit.new("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Kit.White,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 39,
	}, band)
	local w = word(body, "CAUGHT!", 62, BANGERS, pal, true, 36, P(cx, by - 2))
	local wScale = scaler(w.root)
	local row = nameRow(body, info, 36, P(cx, 114))
	local pill = chip(body, info.Earns, 36, P(cx, 144))
	local pillScale = scaler(pill)
	local new = badge(body, "NEW!", 44, 40)
	new.Position = P(cx + w.wide / 2 + 10, by - 30)
	new.Visible = info.New == true
	local newScale = scaler(new)
	local chips = specks(fx, if BIG[info.Tier] then 20 else 12, 66, { pal.Light, Kit.White }, 35)
	local fade = fader(body, { fx, flash })
	local LINE, OPEN, HIT = 0.12, 0.2, 0.28
	local L = 2.7
	local E = L - 0.32
	local pose = function(t: number)
		-- the hairline streaks across, then opens past its height and settles
		local lx = quadOut(at(t, 0, LINE))
		local hy
		if t < LINE then
			hy = 0.06
		elseif t < OPEN then
			hy = lerp(0.06, 1.18, quadOut(at(t, LINE, OPEN - LINE)))
		else
			hy = 1 + 0.18 * (1 - settle(t - OPEN))
		end
		-- the exit: the band snaps shut to a line and the line shoots off to the right
		local e1 = at(t, E, 0.1)
		local e2 = at(t, E + 0.1, 0.22)
		hy = hy * lerp(1, 0.05, quadIn(e1))
		band.Size = P(BW * lx * (1 - quadIn(e2)), BH * hy)
		band.Position = P(cx + BW * 0.5 * quadIn(e2), by)
		band.Visible = t > 0 and e2 < 1
		for _, edge in edges do
			edge.Size = UDim2.new(1, 0, 0, if t < OPEN then 2 else 4)
		end
		flash.BackgroundTransparency = 1 - 0.9 * bump(t, HIT, 0.3)
		for _, s in streaks do
			local start = HIT + (s:GetAttribute("Start") :: number)
			local k = (t - start) * (s:GetAttribute("Speed") :: number)
			s.Visible = t >= HIT and k > 0 and k < 1 and e1 == 0
			s.Position = P(BW * (k * 1.4 - 0.2), s.Position.Y.Offset)
			s.BackgroundTransparency = 0.25 + 0.75 * k
		end
		-- the word: from the camera, huge and clear, down onto the band (the hit), squashes and rings back
		local wt = t - (HIT - 0.1)
		w.root.Visible = wt >= 0 and e2 < 0.6
		local s
		if wt < 0.1 then
			s = lerp(3.4, 0.8, quadIn(math.max(wt, 0) / 0.1))
		else
			s = 0.8 + 0.2 * settle(wt - 0.1)
		end
		s *= 1 + 0.08 * quadOut(e1) - 0.5 * quadIn(e2)
		wScale.Scale = s
		w.root.Rotation = -4
		w.root.Position = P(cx - 140 * quadIn(e2), by - 2)
		specksPose(chips, t, HIT, cx, by, 260, 70, 1, 1.4, 0.6, 50)
		-- the screen shakes with the hit (the camera too, in the game: Show.impact)
		local k = bump(t, HIT, 0.45)
		body.Position = P(math.sin(t * 83) * 11 * k, math.cos(t * 71) * 8 * k)
		-- the name in from the right, the earnings and badge after
		local rx = at(t, 0.38, 0.3)
		row.Visible = rx > 0
		row.Position = P(cx + 260 * (1 - backOut(rx)) - 180 * quadIn(e2), 114)
		pill.Visible = info.Earns ~= nil and t >= 0.52
		pillScale.Scale = settle(t - 0.52)
		local nb = t - 0.5
		newScale.Scale = if nb < 0
			then 0
			elseif nb < 0.08 then lerp(2.4, 0.85, quadIn(nb / 0.08))
			else 0.85 + 0.15 * settle(nb - 0.08)
		new.Rotation = 14
		fade(1 - quadIn(e2))
		bodyScale.Scale = 1
	end
	return { root = root, length = L, pose = pose, impact = HIT, shake = if BIG[info.Tier] then 2.2 else 1.5 }
end

---------------------------------------------------------------------------------------------------------------------
local BUILDERS: { [number]: (Instance, Info) -> Show } = { punch, stamp, banner, burst, slam }

-- where a look sits on the HUD: clear of the rider at the middle and of the strip at the top (the banner at the left,
-- where the old one was, a fifth of the way down)
local PLACES: { [number]: UDim2 } = {
	[1] = UDim2.fromScale(0.5, 0.27),
	[2] = UDim2.fromScale(0.5, 0.27),
	[3] = UDim2.new(0, 6, 0.2, -10),
	[4] = UDim2.fromScale(0.5, 0.28),
	[5] = UDim2.fromScale(0.5, 0.27),
}
function CaughtText.placeOf(look: number): UDim2
	return PLACES[look] or UDim2.fromScale(0.5, 0.27)
end

-- The info a look shows, from the fish's id (nil: no such fish)
-- (size and variant: in its name as on the tags, "BIG Gold Clownfish", and the best of the two is the plate's word)
local WORDS: { { string } } = {
	{ "Rainbow", "RAINBOW!" },
	{ "Colossal", "COLOSSAL!" },
	{ "Gold", "GOLD!" },
	{ "Huge", "HUGE!" },
	{ "Giant", "GIANT!" },
	{ "Silver", "SILVER!" },
}
function CaughtText.info(fishId: string, earns: number?, isNew: boolean?, size: string?, variant: string?): Info?
	local kind = Config.FishById[fishId]
	if not kind then
		return nil
	end
	local name = kind.Name
	if variant and variant ~= "" then
		name = variant .. " " .. name
	end
	if size and size ~= "Normal" then
		name = string.upper(size) .. " " .. name
	end
	local said: string? = nil
	for _, pair in WORDS do
		if pair[1] == variant or pair[1] == size then
			said = pair[2]
			break
		end
	end
	local bonus: number? = nil
	if isNew and Config.Index.On ~= 0 and Config.inIndex(kind) then
		bonus = (Config.indexFirst(kind))
	end
	return {
		Id = fishId,
		Name = name,
		Tier = kind.Tier,
		Earns = earns,
		New = isNew,
		Word = said,
		Great = Config.greatCatch(fishId, size, variant),
		Bonus = bonus,
	}
end

-- A look built and posed at 0, not playing (nil: no such look). For captures and sheets
-- Test hook: only the Studio checks call this (tools/ui/caught_text/client.luau).
function CaughtText.preview(parent: Instance, look: number, info: Info): Show?
	local build = BUILDERS[look]
	if not build then
		return nil
	end
	local show = build(parent, info)
	show.pose(0)
	return show
end

-- The clock it plays by (a capture script may hold it to shoot frames of the real thing)
CaughtText.Clock = os.clock

local current: { show: Show, conn: RBXScriptConnection }? = nil

function CaughtText.stop()
	if current then
		current.conn:Disconnect()
		current.show.root:Destroy()
		current = nil
	end
end

-- Plays the look in the HUD (false: no such look, Banners plays its own). A new catch replaces the one up
function CaughtText.play(parent: Instance, look: number, info: Info): boolean
	local build = BUILDERS[look]
	if not build then
		return false
	end
	CaughtText.stop()
	local show = build(parent, info)
	show.root.Position = CaughtText.placeOf(look)
	local start = CaughtText.Clock()
	local hit = false
	local entry: { show: Show, conn: RBXScriptConnection }
	entry = {
		show = show,
		conn = RunService.RenderStepped:Connect(function()
			local t = CaughtText.Clock() - start
			if not hit and show.impact and t >= show.impact then
				hit = true
				-- the camera shakes with it (the tame's own shake has already played)
				if show.shake then
					Shake.play("Tame", show.shake)
				end
			end
			show.pose(t)
			if t >= show.length and current == entry then
				CaughtText.stop()
			end
		end),
	}
	show.pose(0)
	current = entry
	return true
end

return CaughtText
