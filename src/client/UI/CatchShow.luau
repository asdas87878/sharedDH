--!strict
-- The end of a dive, animated (task s3; Hugo, 2026-11-18: "Improve ui for catch, make sure it counts all the fish that
-- were caught in with a better animation, give me a couple options. make sure the text and spawning in also all has a
-- animation"). Four looks behind Kit.CatchLook (0 keeps Banners' own end of a dive, as before):
--   1 Cards: the title pops, each fish drops in as a face-down card and flips over with a burst, the count ticks up
--   2 Stack: a list at the right: each fish slides in as a row with its name and rarity, a badge counts them
--   3 Big number: rays turn behind one big number that rolls up a fish at a time, each fish bursts out to an arc
--   4 Toast: a compact pill drops in under the strip, the fish pop into it one by one as it widens, then the metres
-- Every word and piece comes in by its own move; nothing is a plain switch-on. Each look is a pose of the time since it
-- began (pose(t)), so the game plays it frame by frame and a sheet can stop it at any moment (preview).
-- Sheet: docs/attachments/catch-ui-options-1.png (GIFs catch-ui-option-<n>.gif), by tools/ui/catch_show/capture.py.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)
local Zones = require(ReplicatedStorage.Shared.Zones)
local Kit = require(script.Parent.Kit)
local Portrait = require(script.Parent.Portrait)

local CatchShow = {}

export type Item = { Id: string, Tier: string }
export type Show = {
	root: Frame,
	length: number, -- seconds until it is gone
	pose: (t: number) -> (),
	-- the catch screen's own (look 3): when everything is in its place (a click before skips to it), and its close,
	-- started at t, which gives back when it is gone
	settled: number?,
	leave: ((t: number) -> number)?,
}

local SHOWN = 7 -- the most fish drawn (Config.Tame.Carry is 7); the count still counts every one
local HOLD = 2.2 -- seconds everything stays up once the metres have counted
local OUT = 0.32 -- and the time it takes to go

local BIG: { [string]: boolean } = { Legendary = true, Mythic = true, Secret = true }

-- the look in play: Kit.CatchLook, or in Studio the workspace's "CatchLook" number
function CatchShow.look(): number
	local own = workspace:GetAttribute("CatchLook")
	if RunService:IsStudio() and type(own) == "number" then
		return own
	end
	return Kit.CatchLook
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
-- a bump: 0 at rest, up to 1 at once, settling back over d seconds after a
local function bump(t: number, a: number, d: number): number
	if t < a then
		return 0
	end
	local x = at(t, a, d)
	return (1 - x) ^ 2
end

---------------------------------------------------------------------------------------------------------------------
-- pieces
local ENDS = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 1),
	NumberSequenceKeypoint.new(0.22, 0.08),
	NumberSequenceKeypoint.new(0.78, 0.08),
	NumberSequenceKeypoint.new(1, 1),
})
local LINE = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 1),
	NumberSequenceKeypoint.new(0.25, 0),
	NumberSequenceKeypoint.new(0.75, 0),
	NumberSequenceKeypoint.new(1, 1),
})
local RAY = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 1),
	NumberSequenceKeypoint.new(0.3, 0.72),
	NumberSequenceKeypoint.new(0.5, 0.82),
	NumberSequenceKeypoint.new(0.7, 0.72),
	NumberSequenceKeypoint.new(1, 1),
})
local GOLD_TOP, GOLD_BOTTOM = Color3.fromRGB(255, 244, 170), Color3.fromRGB(255, 170, 40)

-- a holder that grows from its middle: a frame with a UIScale (its children scale with it)
local function holder(parent: Instance, size: UDim2, z: number): (Frame, UIScale)
	local frame: Frame = Kit.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = size,
		BackgroundTransparency = 1,
		ZIndex = z,
	}, parent)
	return frame, Kit.new("UIScale", {}, frame)
end

-- words with their drop shadow (both fade as one)
type Words = { top: TextLabel, under: TextLabel, fade: (a: number) -> () }
local function words(props: { [string]: any }, parent: Instance, drop: number): Words
	local underProps = table.clone(props)
	underProps.Position = (props.Position or UDim2.new()) + UDim2.fromOffset(0, drop)
	underProps.TextColor3 = Kit.Ink
	underProps.ZIndex = (props.ZIndex or 1) - 1
	local under = Kit.text(underProps, parent)
	local top = Kit.text(props, parent)
	local strokes = { top:FindFirstChildOfClass("UIStroke"), under:FindFirstChildOfClass("UIStroke") }
	local function fade(a: number)
		top.TextTransparency = 1 - a
		under.TextTransparency = 1 - a
		for _, s in strokes do
			if s then
				s.Transparency = 1 - a
			end
		end
	end
	return { top = top, under = under, fade = fade }
end

-- a label's letters and outline fading as one
local function fadeText(label: TextLabel, a: number)
	label.TextTransparency = 1 - a
	local s = label:FindFirstChildOfClass("UIStroke")
	if s then
		s.Transparency = 1 - a
	end
end

-- A bursting badge (BEST!): an eight-pointed star with a word on it
local function badge(parent: Instance, word: string, size: number, z: number): (Frame, UIScale)
	local frame, scale = holder(parent, UDim2.fromOffset(size, size), z)
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
			}, frame)
			Kit.corner(square, size * 0.08)
			if layer == 1 then
				Kit.stroke(square, 2, Kit.Ink)
			end
		end
	end
	Kit.text({ Size = UDim2.fromScale(1, 1), TextSize = size * 0.27, Text = word, ZIndex = z + 2 }, frame)
	return frame, scale
end

-- rays through one point, fading at their ends (only the holder's turn and see-through change)
local function rays(parent: Instance, size: number, count: number, z: number): (Frame, { Frame })
	local frame: Frame = Kit.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(size, size),
		BackgroundTransparency = 1,
		ZIndex = z,
	}, parent)
	local bars: { Frame } = {}
	for i = 1, count do
		local bar = Kit.new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(1, 0.085),
			Rotation = (i - 1) * 180 / count,
			BackgroundColor3 = Kit.White,
			BorderSizePixel = 0,
			ZIndex = z,
		}, frame)
		Kit.new("UIGradient", { Transparency = RAY }, bar)
		table.insert(bars, bar)
	end
	return frame, bars
end

-- A fish token: round (or a rounded card), in its rarity's colours, with its picture (its name's first letter when it
-- has no model to draw). The token is sized by its holder; scale is its own grow
type Token = { frame: Frame, scale: UIScale, face: Frame, back: Frame?, ring: Frame }
local function token(parent: Instance, item: Item, size: number, round: boolean, z: number, withBack: boolean): Token
	local frame, scale = holder(parent, UDim2.fromOffset(size, size), z)
	local face: Frame = Kit.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Kit.White,
		ZIndex = z,
	}, frame)
	Kit.corner(face, if round then 999 else size * 0.2)
	Kit.stroke(face, if size > 40 then 2.5 else 1.8, Kit.Ink)
	local fill = Kit.new("UIGradient", {}, face)
	fill.Color, fill.Rotation = Kit.tierFill(item.Tier, Config.Tiers)
	local picture = Portrait.new(face, {
		Position = UDim2.fromOffset(2, 2),
		Size = UDim2.new(1, -4, 1, -4),
		ZIndex = z + 1,
	})
	local pictured = picture.show(item.Id)
	picture.Frame.Visible = pictured
	if not pictured then
		local kind = Config.FishById[item.Id]
		Kit.text({
			Size = UDim2.fromScale(1, 1),
			TextSize = size * 0.5,
			Text = if kind then string.sub(kind.Name, 1, 1) else "?",
			ZIndex = z + 1,
		}, face)
	end
	-- a white ring that bursts out of the token as it lands
	local ring: Frame = Kit.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ZIndex = z - 1,
	}, frame)
	Kit.corner(ring, if round then 999 else size * 0.24)
	Kit.stroke(ring, 3, if BIG[item.Tier] then Kit.Sun else Kit.White)
	local back: Frame? = nil
	if withBack then
		local b: Frame = Kit.new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = Kit.Navy,
			ZIndex = z + 3,
		}, frame)
		Kit.corner(b, if round then 999 else size * 0.2)
		Kit.stroke(b, 2.5, Kit.Ink)
		Kit.new("UIGradient", {
			Color = ColorSequence.new(Kit.lighter(Kit.Navy, 0.25), Kit.Deep),
			Rotation = 90,
		}, b)
		local inner = Kit.new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.new(1, -8, 1, -8),
			BackgroundTransparency = 1,
			ZIndex = z + 4,
		}, b)
		Kit.corner(inner, size * 0.14)
		Kit.stroke(inner, 1.5, Kit.Sun, 0.35)
		Kit.text({ Size = UDim2.fromScale(1, 1), TextSize = size * 0.5, Text = "?", ZIndex = z + 5 }, b)
		back = b
	end
	return { frame = frame, scale = scale, face = face, back = back, ring = ring }
end

-- the burst ring's pose: grows out and fades over d seconds after a
local function burst(tk: Token, t: number, a: number, d: number, grow: number)
	local x = at(t, a, d)
	local live = t >= a and x < 1
	tk.ring.Visible = live
	if live then
		local s = 1 + quadOut(x) * grow
		tk.ring.Size = UDim2.fromScale(s, s)
		local stroke = tk.ring:FindFirstChildOfClass("UIStroke")
		if stroke then
			stroke.Transparency = quadIn(x)
		end
	end
end

-- a pill: the dark navy plate with a rim
local function pill(parent: Instance, size: UDim2, edge: Color3?, z: number): Frame
	local frame: Frame = Kit.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = size,
		ZIndex = z,
	}, parent)
	Kit.dress(frame, {
		Top = Kit.Themes.Navy.Top,
		Bottom = Kit.Themes.Navy.Bottom,
		Edge = edge,
		Radius = Kit.Radius.Round,
		Bevel = false,
	})
	return frame
end

-- the metres, counted up from a to a + d
local function metresAt(metres: number, t: number, a: number, d: number): string
	return math.floor(math.floor(metres) * quadOut(at(t, a, d)) + 0.5) .. " m deep"
end

local function nameOf(item: Item): string
	local kind = Config.FishById[item.Id]
	return if kind then kind.Name else item.Id
end

-- the fish to draw (the last SHOWN), and the count each drawn one brings the total to (all of them counted)
local function drawn(list: { Item }): ({ Item }, { number })
	local n = #list
	local first = math.max(n - SHOWN, 0)
	local out: { Item } = {}
	local totals: { number } = {}
	for i = first + 1, n do
		table.insert(out, list[i])
	end
	for i = 1, #out do
		-- (more than SHOWN: the first drawn one stands for every one before it too)
		totals[i] = first + i
	end
	return out, totals
end

-- how many fish the count shows at t: the total of the last fish revealed by then
local function countAt(times: { number }, totals: { number }, t: number): (number, number)
	local shown, last = 0, -1
	for i, when in times do
		if t >= when then
			shown, last = totals[i], when
		end
	end
	return shown, last
end

---------------------------------------------------------------------------------------------------------------------
-- 1 Cards
local function cards(parent: Instance, metres: number, isBest: boolean, list: { Item }): Show
	local root: Frame = Kit.new("Frame", {
		Name = "CatchShow",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(460, 220),
		BackgroundTransparency = 1,
		ZIndex = 15,
	}, parent)
	local rootScale = Kit.new("UIScale", {}, root)
	local items, totals = drawn(list)
	local n = #items

	local streak: Frame = Kit.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(230, 32),
		Size = UDim2.fromOffset(440, 56),
		Rotation = -2.5,
		BackgroundColor3 = Kit.Deep,
		BorderSizePixel = 0,
		ZIndex = 15,
	}, root)
	Kit.new("UIGradient", { Transparency = ENDS }, streak)
	for _, y in { 0, 1 } do
		local line = Kit.new("Frame", {
			AnchorPoint = Vector2.new(0, y),
			Position = UDim2.fromScale(0, y),
			Size = UDim2.new(1, 0, 0, 2.5),
			BackgroundColor3 = Kit.Sun,
			BorderSizePixel = 0,
			ZIndex = 16,
		}, streak)
		Kit.new("UIGradient", { Transparency = LINE }, line)
	end
	local titleBox, titleScale = holder(root, UDim2.fromOffset(400, 50), 18)
	titleBox.Position = UDim2.fromOffset(230, 30)
	titleBox.Rotation = -2.5
	local title = words({ Size = UDim2.fromScale(1, 1), TextSize = 42, Text = "GREAT DIVE!", ZIndex = 19 }, titleBox, 3)
	Kit.gradient(title.top, GOLD_TOP, GOLD_BOTTOM)
	local best, bestScale = badge(root, "BEST!", 56, 22)
	best.Position = UDim2.fromOffset(410, 14)
	best.Visible = isBest

	-- the cards, centred on however many there are
	local SIZE, GAP = 50, 9
	local rowWide = n * SIZE + math.max(n - 1, 0) * GAP
	local tokens: { Token } = {}
	local times: { number } = {}
	local STEP, FIRST = 0.3, 0.62
	for i, item in items do
		local tk = token(root, item, SIZE, false, 20, true)
		tk.frame.Position = UDim2.fromOffset(230 - rowWide / 2 + SIZE / 2 + (i - 1) * (SIZE + GAP), 96)
		tokens[i] = tk
		times[i] = FIRST + (i - 1) * STEP + 0.26 -- the moment its face shows
	end
	local lastCard = if n > 0 then times[n] else FIRST

	-- the tally: the count ticks up as each face shows
	local tallyBox, tallyScale = holder(root, UDim2.fromOffset(300, 30), 18)
	tallyBox.Position = UDim2.fromOffset(230, if n > 0 then 146 else 92)
	local tally = Kit.text({
		Size = UDim2.fromScale(1, 1),
		TextSize = 20,
		RichText = true,
		ZIndex = 19,
	}, tallyBox)
	local pillBox, pillScale = holder(root, UDim2.fromOffset(160, 28), 16)
	pillBox.Position = UDim2.fromOffset(230, if n > 0 then 186 else 130)
	local metresPill = pill(pillBox, UDim2.fromScale(1, 1), nil, 16)
	metresPill.Position = UDim2.fromScale(0.5, 0.5)
	local metresText = Kit.text({ Size = UDim2.fromScale(1, 1), TextSize = 15, ZIndex = 17 }, metresPill)

	local metresAtT = lastCard + 0.3
	local doneAt = metresAtT + 0.7
	local leaveAt = doneAt + HOLD
	local length = leaveAt + OUT

	local function pose(t: number)
		-- the streak sweeps open from the middle, the title pops and fades in over it
		local open = quadOut(at(t, 0, 0.28))
		streak.Size = UDim2.fromOffset(440 * open, 56)
		streak.Visible = open > 0
		local tp = at(t, 0.08, 0.38)
		titleScale.Scale = 0.2 + 0.8 * backOut(tp) + 0.08 * bump(t, lastCard + 0.05, 0.3)
		title.fade(quadOut(at(t, 0.08, 0.16)))
		-- BEST! spins in and then wobbles
		if isBest then
			local bp = at(t, 0.42, 0.4)
			bestScale.Scale = backOut(bp)
			best.Rotation = -40 + 54 * quadOut(bp) + math.sin(math.max(t - 0.82, 0) * 5) * 4 * bp
		end
		-- each card: drops in face down, flips (squeezes to an edge and opens on its face), bursts
		for i, tk in tokens do
			local a = FIRST + (i - 1) * STEP
			local drop = at(t, a, 0.16)
			local flip = at(t, a + 0.16, 0.2)
			tk.frame.Visible = t >= a
			local y = 96 - 34 * (1 - quadOut(drop))
			local x = 230 - rowWide / 2 + SIZE / 2 + (i - 1) * (SIZE + GAP)
			tk.frame.Position = UDim2.fromOffset(x, y)
			local back = tk.back :: Frame
			if flip < 0.5 then
				local w = 1 - quadIn(flip * 2)
				back.Visible = true
				back.Size = UDim2.fromScale(w, 1)
				tk.face.Visible = false
			else
				local w = quadOut((flip - 0.5) * 2)
				back.Visible = false
				tk.face.Visible = true
				tk.face.Size = UDim2.fromScale(w, 1)
			end
			tk.scale.Scale = 1 + 0.28 * bump(t, times[i], 0.32) * (if BIG[items[i].Tier] then 1.6 else 1)
			burst(tk, t, times[i], 0.45, if BIG[items[i].Tier] then 1.4 else 0.8)
		end
		-- the tally slides up, then counts
		local shown, last = countAt(times, totals, t)
		local tin = at(t, 0.5, 0.25)
		tallyScale.Scale = 0.6 + 0.4 * backOut(tin) + 0.3 * bump(t, last, 0.25)
		fadeText(tally, quadOut(tin))
		tallyBox.Position = UDim2.fromOffset(230, (if n > 0 then 146 else 92) + 10 * (1 - quadOut(tin)))
		if n > 0 then
			tally.Text = string.format('<font color="#FFD23F">%d</font> FISH CAUGHT', shown)
		else
			tally.Text = "NO CATCH THIS TIME"
		end
		-- the metres: the pill pops up and counts
		local mp = at(t, metresAtT, 0.3)
		pillBox.Visible = t >= metresAtT
		pillScale.Scale = backOut(mp) + 0.1 * bump(t, doneAt, 0.25)
		fadeText(metresText, quadOut(mp))
		metresText.Text = metresAt(metres, t, metresAtT, 0.7)
		-- out: a small breath in, then gone
		local o = at(t, leaveAt, OUT)
		rootScale.Scale = 1 - backIn(o)
		root.Visible = o < 1
	end
	pose(0)
	return { root = root, length = length, pose = pose }
end

---------------------------------------------------------------------------------------------------------------------
-- 2 Stack
local function stack(parent: Instance, metres: number, isBest: boolean, list: { Item }): Show
	local items, totals = drawn(list)
	local n = #items
	local WIDE, ROW, HEAD = 270, 36, 56
	local high = HEAD + n * ROW + 44
	local root: Frame = Kit.new("Frame", {
		Name = "CatchShow",
		AnchorPoint = Vector2.new(1, 0.5),
		Size = UDim2.fromOffset(WIDE, high),
		BackgroundTransparency = 1,
		ZIndex = 15,
	}, parent)

	-- the header: a plate with the title, a badge at its end that counts
	local head: Frame = Kit.new("Frame", {
		Size = UDim2.fromOffset(WIDE - 26, 46),
		ZIndex = 16,
	}, root)
	Kit.dress(head, {
		Top = Kit.Themes.Navy.Top,
		Bottom = Kit.Themes.Navy.Bottom,
		Edge = Kit.Sun,
		Radius = Kit.Radius.Plate,
		Bevel = false,
	})
	local titleBox, titleScale = holder(head, UDim2.fromOffset(190, 40), 18)
	titleBox.Position = UDim2.fromOffset(104, 23)
	local title = words({
		Size = UDim2.fromScale(1, 1),
		TextSize = 30,
		Text = "GREAT DIVE!",
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 19,
	}, titleBox, 2.5)
	Kit.gradient(title.top, GOLD_TOP, GOLD_BOTTOM)
	local countBox, countScale = holder(root, UDim2.fromOffset(50, 50), 21)
	countBox.Position = UDim2.fromOffset(WIDE - 30, 22)
	local disc = Kit.new("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Kit.White,
		ZIndex = 21,
	}, countBox)
	Kit.corner(disc, 999)
	Kit.stroke(disc, 3, Kit.Ink)
	Kit.gradient(disc, Color3.fromRGB(255, 226, 110), Color3.fromRGB(240, 150, 24))
	local countText = Kit.text({ Size = UDim2.fromScale(1, 1), TextSize = 24, ZIndex = 22 }, disc)
	local best, bestScale = badge(root, "BEST!", 44, 24)
	best.Position = UDim2.fromOffset(WIDE - 74, -6)
	best.Visible = isBest

	-- the rows
	type Row = { frame: Frame, tk: Token, name: TextLabel, tier: TextLabel, index: TextLabel, tierScale: UIScale }
	local rows: { Row } = {}
	local times: { number } = {}
	local STEP, FIRST = 0.24, 0.42
	for i, item in items do
		local y = HEAD + (i - 1) * ROW
		local bar: Frame = Kit.new("Frame", {
			Position = UDim2.fromOffset(8, y),
			Size = UDim2.fromOffset(WIDE - 40, ROW - 5),
			BackgroundColor3 = Kit.Deep,
			BackgroundTransparency = 0.2,
			ZIndex = 16,
		}, root)
		Kit.corner(bar, 999)
		Kit.stroke(bar, 2, Kit.Ink)
		local tint = Kit.new("Frame", {
			Size = UDim2.new(0, 60, 1, 0),
			BackgroundColor3 = (Config.Tiers[item.Tier] and Config.Tiers[item.Tier].Colour) or Kit.White,
			BackgroundTransparency = 0.55,
			ZIndex = 16,
		}, bar)
		Kit.corner(tint, 999)
		Kit.new("UIGradient", {
			Transparency = NumberSequence.new(0, 1),
		}, tint)
		local index = Kit.text({
			Position = UDim2.fromOffset(6, 0),
			Size = UDim2.fromOffset(16, ROW - 5),
			TextSize = 13,
			Text = tostring(totals[i]),
			TextColor3 = Kit.Sun,
			ZIndex = 18,
		}, bar)
		local tk = token(bar, item, 30, true, 18, false)
		tk.frame.Position = UDim2.fromOffset(40, (ROW - 5) / 2)
		local name = Kit.text({
			Position = UDim2.fromOffset(60, 0),
			Size = UDim2.new(1, -66, 1, 0),
			TextSize = 15,
			Text = nameOf(item),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
			ZIndex = 18,
		}, bar)
		local tierBox, tierScale = holder(bar, UDim2.fromOffset(80, ROW - 5), 18)
		tierBox.AnchorPoint = Vector2.new(1, 0.5)
		tierBox.Position = UDim2.new(1, -10, 0.5, 0)
		local tier = Kit.text({
			Size = UDim2.fromScale(1, 1),
			TextSize = 12,
			Text = string.upper(item.Tier),
			TextXAlignment = Enum.TextXAlignment.Right,
			ZIndex = 19,
		}, tierBox)
		Kit.tierColours(tier, Kit.gradient(tier, Kit.White, Kit.White), item.Tier, Config.Tiers)
		rows[i] = { frame = bar, tk = tk, name = name, tier = tier, index = index, tierScale = tierScale }
		times[i] = FIRST + (i - 1) * STEP + 0.18
	end
	local lastRow = if n > 0 then times[n] else FIRST

	-- the foot: the metres
	local foot = pill(root, UDim2.fromOffset(150, 28), nil, 16)
	foot.AnchorPoint = Vector2.new(0, 0)
	local footY = HEAD + n * ROW + 6
	local metresText = Kit.text({ Size = UDim2.fromScale(1, 1), TextSize = 15, ZIndex = 17 }, foot)
	local none = Kit.text({
		Position = UDim2.fromOffset(14, HEAD - 2),
		Size = UDim2.fromOffset(200, 24),
		TextSize = 16,
		Text = "No catch this time",
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 17,
	}, root)
	none.Visible = n == 0
	if n == 0 then
		footY = HEAD + 26
	end

	local metresAtT = lastRow + 0.22
	local doneAt = metresAtT + 0.7
	local leaveAt = doneAt + HOLD
	local length = leaveAt + OUT + 0.05 * n

	local function pose(t: number)
		-- the header slides in from the left edge and settles; its words follow a beat behind
		local hp = at(t, 0, 0.34)
		head.Position = UDim2.fromOffset((WIDE + 40) * (1 - backOut(hp)), 0)
		local tp = at(t, 0.12, 0.3)
		titleScale.Scale = 0.5 + 0.5 * backOut(tp)
		title.fade(quadOut(tp))
		-- the count badge pops on, then bumps with every row
		local shown, last = countAt(times, totals, t)
		local cp = at(t, 0.28, 0.3)
		countBox.Rotation = -90 * (1 - quadOut(cp))
		countScale.Scale = backOut(cp) + 0.35 * bump(t, last, 0.28)
		countText.Text = "×" .. shown
		if isBest then
			local bp = at(t, 0.5, 0.36)
			bestScale.Scale = backOut(bp)
			best.Rotation = 40 - 28 * quadOut(bp) + math.sin(math.max(t - 0.86, 0) * 5) * 4 * bp
		end
		-- rows: each slides in from the left, its token rolls in, its name fades up, its rarity pops
		local o = at(t, leaveAt, OUT)
		for i, row in rows do
			local a = FIRST + (i - 1) * STEP
			local p = at(t, a, 0.3)
			local leave = at(t, leaveAt + 0.05 * (n - i), OUT)
			row.frame.Visible = t >= a and leave < 1
			row.frame.Position =
				UDim2.fromOffset(8 + (WIDE + 40) * (1 - backOut(p)) + (WIDE + 40) * backIn(leave), HEAD + (i - 1) * ROW)
			row.tk.frame.Rotation = -200 * (1 - quadOut(p))
			row.tk.scale.Scale = 1 + 0.35 * bump(t, times[i], 0.3)
			burst(row.tk, t, times[i], 0.4, if BIG[items[i].Tier] then 1.2 else 0.6)
			local np = at(t, a + 0.12, 0.2)
			fadeText(row.name, quadOut(np))
			row.name.Position = UDim2.fromOffset(60 + 14 * (1 - quadOut(np)), 0)
			fadeText(row.index, quadOut(np))
			local rp = at(t, a + 0.2, 0.26)
			row.tierScale.Scale = backOut(rp) + (if BIG[items[i].Tier] then 0.12 * math.sin(t * 6) * rp else 0)
		end
		fadeText(none, quadOut(at(t, 0.4, 0.25)))
		-- the foot slides up into place and counts
		local fp = at(t, metresAtT, 0.3)
		foot.Visible = t >= metresAtT
		foot.Position = UDim2.fromOffset(8 + (WIDE + 40) * backIn(o), footY + 16 * (1 - backOut(fp)))
		fadeText(metresText, quadOut(fp))
		metresText.Text = metresAt(metres, t, metresAtT, 0.7)
		-- out: the header goes after the rows
		local ho = at(t, leaveAt + 0.05 * n, OUT)
		if ho > 0 then
			head.Position = UDim2.fromOffset((WIDE + 40) * backIn(ho), 0)
			countBox.Position = UDim2.fromOffset(WIDE - 30 + (WIDE + 40) * backIn(ho), 22)
			best.Position = UDim2.fromOffset(WIDE - 74 + (WIDE + 40) * backIn(ho), -6)
		else
			countBox.Position = UDim2.fromOffset(WIDE - 30, 22)
			best.Position = UDim2.fromOffset(WIDE - 74, -6)
		end
		root.Visible = ho < 1
	end
	pose(0)
	return { root = root, length = length, pose = pose }
end

---------------------------------------------------------------------------------------------------------------------
-- 3 The catch screen: Hugo's pick (task c1, 2026-11-19), built into the game with his changes. One big number rolls
-- up a fish at a time behind turning rays, each fish bursts out of it to its own rarity tile on an arc; "GREAT DIVE!"
-- with BEST! right beside it, "FISH CAUGHT!", the metres on a black oval, a CONTINUE button. Every word is a rarity
-- word (Kit.word) in an angular font (Bangers) with a thick dark edge, a gradient, a shine line and a glow; the
-- metres in the land strip's cartoon font. A see-through dark backdrop under it, and the backdrop and the screen fade
-- in and out together. A click or tap anywhere skips to the end; the next closes (CatchShow.play).
local SCREEN_FONT = Enum.Font.Bangers
local BACKDROP = 0.35 -- how dark the backdrop gets (black at this share: a little darker, still see-through)
local FADE_IN, FADE_OUT = 0.22, 0.3
-- the room the screen leaves round it when it has to shrink: the land strip over it and the slots under it (keyboard
-- and phone alike), and a little at the sides
local FIT_ROOM = Vector2.new(40, 150)
local TILE = 52 -- a fish's tile
local TILE_STEP = 60
local TILE_LINE = 2.5
local TILE_BLACK = Color3.fromRGB(6, 8, 14)
-- the rolling number's window fades out at its top and bottom edges
local ROLL_FADE = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 1),
	NumberSequenceKeypoint.new(0.2, 0),
	NumberSequenceKeypoint.new(0.8, 0),
	NumberSequenceKeypoint.new(1, 1),
})
local CUT = NumberSequence.new({ -- the arrow: the right half of a turned square
	NumberSequenceKeypoint.new(0, 1),
	NumberSequenceKeypoint.new(0.499, 1),
	NumberSequenceKeypoint.new(0.5, 0),
	NumberSequenceKeypoint.new(1, 0),
})
-- a word's letters and edges faded as one (a = 1 as built); each layer keeps its own see-through as built
local bases: { [Instance]: number } = setmetatable({}, { __mode = "k" }) :: any
local function fadeWord(w: Kit.Word, a: number)
	for _, d in w.root:GetDescendants() do
		if d:IsA("TextLabel") then
			local base = bases[d] or d.TextTransparency
			bases[d] = base
			d.TextTransparency = 1 - (1 - base) * a
		elseif d:IsA("UIStroke") then
			local base = bases[d] or d.Transparency
			bases[d] = base
			d.Transparency = 1 - (1 - base) * a
		end
	end
end

-- a caught fish's tile colours, as the slots': its rarity's colour a little lighter at the top and darker at the foot;
-- the top three their own gold, ember and rainbow, a little brighter
local function tileFill(tier: string): (ColorSequence, number)
	local entry = Config.Tiers[tier]
	if BIG[tier] or not entry then
		local colours, turn = Kit.tierFill(tier, Config.Tiers)
		local points = {}
		for _, point in colours.Keypoints do
			table.insert(points, ColorSequenceKeypoint.new(point.Time, Kit.lighter(point.Value, 0.14)))
		end
		return ColorSequence.new(points), turn
	end
	local colour: Color3 = entry.Colour
	return ColorSequence.new(Kit.lighter(colour, 0.08), Kit.darker(colour, 0.1)), 90
end

-- Where a fish's picture sits in its tile, by how it is shown (Portrait): a bust is bigger than the tile, its head
-- in the middle and its neck and body running on past the right and bottom edges, cut off at the tile's inner edge so
-- it fills the tile with no gap; a fish shown whole (small, thin, flat) is centred whole, with a little room round it
local FIT: { [string]: { X: number, Y: number, Wide: number, High: number } } = {
	Bust = { X = 0.6, Y = 0.56, Wide = 1.42, High = 1.32 },
	Whole = { X = 0.5, Y = 0.5, Wide = 1.06, High = 1.06 },
	Thin = { X = 0.5, Y = 0.5, Wide = 1.0, High = 1.08 },
	Flat = { X = 0.5, Y = 0.52, Wide = 1.08, High = 1.08 },
}

-- A fish on its own rarity tile: square, a black outline, the slots' light rim and dark lip, the picture clipped at
-- the tile's inner edge. The tile is sized by its holder; scale is its own grow
type Tile = { frame: Frame, scale: UIScale, ring: Frame }
local function fishTile(parent: Instance, item: Item, size: number, z: number): Tile
	local frame, scale = holder(parent, UDim2.fromOffset(size, size), z)
	local face: Frame = Kit.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Kit.White,
		BorderSizePixel = 0,
		ZIndex = z,
	}, frame)
	local line = Kit.stroke(face, TILE_LINE, TILE_BLACK)
	line.LineJoinMode = Enum.LineJoinMode.Miter
	local fill = Kit.new("UIGradient", {}, face)
	fill.Color, fill.Rotation = tileFill(item.Tier)
	-- the light rim along the top and down the sides, the darker lip along the foot (as a caught slot's)
	Kit.new("Frame", {
		Size = UDim2.new(1, 0, 0, 2.5),
		BackgroundColor3 = Kit.White,
		BackgroundTransparency = 0.25,
		BorderSizePixel = 0,
		ZIndex = z + 1,
	}, face)
	for _, right in { false, true } do
		local side = Kit.new("Frame", {
			AnchorPoint = Vector2.new(if right then 1 else 0, 0),
			Position = UDim2.new(if right then 1 else 0, 0, 0, 2.5),
			Size = UDim2.new(0, 2.5, 1, -5),
			BackgroundColor3 = Kit.White,
			BorderSizePixel = 0,
			ZIndex = z + 1,
		}, face)
		Kit.new("UIGradient", {
			Rotation = 90,
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.3),
				NumberSequenceKeypoint.new(0.5, 0.58),
				NumberSequenceKeypoint.new(1, 0.85),
			}),
		}, side)
	end
	Kit.new("Frame", {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, 2.5),
		BackgroundColor3 = TILE_BLACK,
		BackgroundTransparency = 0.6,
		BorderSizePixel = 0,
		ZIndex = z + 1,
	}, face)
	-- the picture's window: clipped at the tile's inner edge (the outline stands outside it)
	local clip: Frame = Kit.new("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		ZIndex = z + 2,
	}, face)
	local fit = FIT[Portrait.kindOf(item.Id) or "Whole"] or FIT.Whole
	local picture = Portrait.new(clip, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(fit.X, fit.Y),
		Size = UDim2.fromScale(fit.Wide, fit.High),
		ZIndex = z + 2,
	})
	local pictured = picture.show(item.Id)
	picture.Frame.Visible = pictured
	if not pictured then
		local kind = Config.FishById[item.Id]
		Kit.word(clip, {
			Text = if kind then string.sub(kind.Name, 1, 1) else "?",
			TextSize = size * 0.55,
			Font = SCREEN_FONT,
			Edge = 0.08,
			Position = UDim2.fromScale(0.5, 0.5),
			ZIndex = z + 3,
		})
	end
	-- a ring that bursts out of the tile as it lands (gold on a Legendary or rarer)
	local ring: Frame = Kit.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Visible = false,
		ZIndex = z - 1,
	}, frame)
	local ringLine = Kit.stroke(ring, 3, if BIG[item.Tier] then Kit.Sun else Kit.White)
	ringLine.LineJoinMode = Enum.LineJoinMode.Miter
	return { frame = frame, scale = scale, ring = ring }
end

-- A burst of points (BEST!): squares turned through one point, gold over red, each with the ink edge
local function star(parent: Instance, size: number, z: number): Frame
	local frame: Frame = Kit.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(size, size),
		BackgroundTransparency = 1,
		ZIndex = z,
	}, parent)
	for layer = 1, 2 do
		local share = if layer == 1 then 0.7 else 0.56
		for _, angle in { 0, 30, 60 } do
			local square = Kit.new("Frame", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromScale(share, share),
				Rotation = angle,
				BackgroundColor3 = if layer == 1 then Kit.Sun else Kit.Danger,
				BorderSizePixel = 0,
				ZIndex = z + layer - 1,
			}, frame)
			if layer == 1 then
				Kit.stroke(square, 3, TILE_BLACK)
			end
		end
	end
	return frame
end

local function screen(parent: Instance, metres: number, isBest: boolean, list: { Item }): Show
	local items, totals = drawn(list)
	local n = #items
	-- the whole screen: the backdrop (all of the screen and past its edges) and the screen itself, a group that fades
	local root: Frame = Kit.new("Frame", {
		Name = "CatchShow",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ZIndex = 50,
	}, parent)
	local backdrop: Frame = Kit.new("Frame", {
		Name = "Backdrop",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(1, 160, 1, 160),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 1,
	}, root)
	local W, H = 640, 490
	local group: CanvasGroup = Kit.new("CanvasGroup", {
		Name = "Screen",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(W, H),
		BackgroundTransparency = 1,
		GroupTransparency = 1,
		ZIndex = 2,
	}, root)
	local groupScale = Kit.new("UIScale", {}, group)
	local CX, CY = W / 2, 168

	local rayBox, bars = rays(group, 380, 9, 2)
	rayBox.Position = UDim2.fromOffset(CX, CY)
	local glow: Frame = Kit.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(CX, CY),
		Size = UDim2.fromOffset(170, 170),
		BackgroundColor3 = Kit.Sun,
		BackgroundTransparency = 0.6,
		ZIndex = 2,
	}, group)
	Kit.corner(glow, 999)
	Kit.new("UIGradient", {
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.5, 0.2),
			NumberSequenceKeypoint.new(1, 1),
		}),
	}, glow)

	-- the title, with BEST! right beside it; the two centred as one
	local titleBox, titleScale = holder(group, UDim2.fromOffset(10, 10), 10)
	titleBox.Rotation = -3
	local title = Kit.word(titleBox, {
		Text = "GREAT DIVE!",
		TextSize = 54,
		Font = SCREEN_FONT,
		Pal = Kit.GoldPal,
		Glow = true,
		Edge = 0.1,
		Position = UDim2.fromScale(0.5, 0.5),
		ZIndex = 10,
	})
	titleBox.Size = UDim2.fromOffset(title.wide, title.high)
	local BEST_SIZE = 66
	local bestBox, bestScale = holder(group, UDim2.fromOffset(BEST_SIZE, BEST_SIZE), 16)
	star(bestBox, BEST_SIZE, 16)
	local bestWord = Kit.word(bestBox, {
		Text = "BEST!",
		TextSize = 24,
		Font = SCREEN_FONT,
		Pal = Kit.WhitePal,
		Edge = 0.13,
		Position = UDim2.fromScale(0.5, 0.52),
		ZIndex = 20,
	})
	bestWord.root.Rotation = 12
	bestBox.Visible = isBest
	local pair = title.wide + (if isBest then BEST_SIZE * 0.95 else 0)
	local TITLE_Y = 46
	titleBox.Position = UDim2.fromOffset(CX - pair / 2 + title.wide / 2, TITLE_Y)
	bestBox.Position = UDim2.fromOffset(CX - pair / 2 + title.wide + BEST_SIZE * 0.46, TITLE_Y - 10)

	-- the number: two words in a window that fades out at its top and bottom, the old count rolling out downward as
	-- the new one drops in from above
	local ROLL = 150 -- the window's height, and how far a count rolls
	local window: CanvasGroup = Kit.new("CanvasGroup", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(CX, CY),
		Size = UDim2.fromOffset(240, ROLL),
		BackgroundTransparency = 1,
		ZIndex = 6,
	}, group)
	Kit.new("UIGradient", { Rotation = 90, Transparency = ROLL_FADE }, window)
	local numScale = Kit.new("UIScale", {}, window)
	local function digit(): Kit.Word
		return Kit.word(window, {
			Text = "0",
			TextSize = 118,
			Font = SCREEN_FONT,
			Pal = Kit.GoldPal,
			Glow = true,
			Edge = 0.075,
			Position = UDim2.fromScale(0.5, 0.5),
			ZIndex = 6,
		})
	end
	local now, before = digit(), digit()
	local caughtBox, caughtScale = holder(group, UDim2.fromOffset(10, 10), 12)
	caughtBox.Position = UDim2.fromOffset(CX, CY + 80)
	local caught = Kit.word(caughtBox, {
		Text = if n > 0 then "FISH CAUGHT!" else "NO CATCH THIS TIME",
		TextSize = 32,
		Font = SCREEN_FONT,
		Pal = Kit.WhitePal,
		Glow = true,
		Edge = 0.12,
		Position = UDim2.fromScale(0.5, 0.5),
		ZIndex = 12,
	})
	caughtBox.Size = UDim2.fromOffset(caught.wide, caught.high)

	-- the fish: out of the number to an arc under the words
	local tiles: { Tile } = {}
	local spots: { Vector2 } = {}
	local times: { number } = {}
	local STEP, FIRST = 0.3, 0.7
	local ARC_Y = CY + 140
	for i, item in items do
		tiles[i] = fishTile(group, item, TILE, 24)
		local u = (i - (n + 1) / 2) / 3
		spots[i] = Vector2.new(CX + (i - (n + 1) / 2) * TILE_STEP, ARC_Y - 14 * u * u)
		times[i] = FIRST + (i - 1) * STEP + 0.24
	end
	local lastFish = if n > 0 then times[n] else FIRST

	-- the metres: a black see-through oval, no edge, the land strip's cartoon font in the land's colours
	local land = 1
	for i, zone in Zones.fallback() do
		if metres >= zone.Metres then
			land = i
		end
	end
	local ovalBox, ovalScale = holder(group, UDim2.fromOffset(10, 44), 14)
	local OVAL_Y = ARC_Y + 62
	ovalBox.Position = UDim2.fromOffset(CX, OVAL_Y)
	local oval: Frame = Kit.new("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.3,
		BorderSizePixel = 0,
		ZIndex = 14,
	}, ovalBox)
	Kit.corner(oval, 999)
	local metresWord = Kit.word(ovalBox, {
		Text = "0 METERS DEEP",
		TextSize = 26,
		Font = Kit.LandMetresFont,
		Pal = Kit.palOf(Kit.Lands[math.clamp(land, 1, #Kit.Lands)]),
		Position = UDim2.new(0.5, 0, 0.5, 1),
		ZIndex = 15,
	})
	local function setMetres(text: string)
		metresWord.set(text)
		ovalBox.Size = UDim2.fromOffset(metresWord.wide + 34, 44)
	end
	-- (sized for the whole number from the start, so the oval never grows as it counts)
	setMetres(math.floor(metres) .. " METERS DEEP")
	local ovalWide = ovalBox.Size.X.Offset

	-- CONTINUE, with a filled arrow at its far right
	local buttonBox, buttonScale = holder(group, UDim2.fromOffset(200, 46), 18)
	buttonBox.Position = UDim2.fromOffset(CX, OVAL_Y + 56)
	local plate: Frame = Kit.new("Frame", {
		Size = UDim2.fromScale(1, 1),
		ZIndex = 18,
	}, buttonBox)
	local good = table.clone(Kit.Themes.Good)
	good.Radius = Kit.Radius.Plate
	Kit.dress(plate, good)
	local go = Kit.word(buttonBox, {
		Text = "CONTINUE",
		TextSize = 28,
		Font = SCREEN_FONT,
		Pal = Kit.WhitePal,
		Edge = 0.12,
		Position = UDim2.new(0.5, -14, 0.5, 0),
		ZIndex = 20,
	})
	local ARROW = 24
	local arrow: Frame = Kit.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(1, -ARROW * 0.8, 0.5, 0),
		Size = UDim2.fromOffset(ARROW, ARROW),
		Rotation = 45,
		BackgroundColor3 = Kit.White,
		BorderSizePixel = 0,
		ZIndex = 24,
	}, buttonBox)
	Kit.new("UIGradient", { Rotation = -45, Transparency = CUT }, arrow)

	local metresAtT = lastFish + 0.32
	local buttonAt = metresAtT + 0.75
	local settled = buttonAt + 0.35 -- everything in its place, every pop over
	local leaveAt: number? = nil

	-- The screen made smaller to fit between the land strip and the slots where the HUD is short (a phone held
	-- sideways is 340 to 390 tall, and the HUD's scale is never under 1): the room in the HUD's units is the root's
	-- size over every UIScale above it
	local function fit(): number
		local scale = 1
		local up: Instance? = root.Parent
		while up do
			local s = up:FindFirstChildOfClass("UIScale")
			if s then
				scale *= s.Scale
			end
			up = up.Parent
		end
		local size = root.AbsoluteSize / scale
		if size.Y <= 0 then
			return 1
		end
		return math.min(1, (size.Y - FIT_ROOM.Y) / H, (size.X - FIT_ROOM.X) / W)
	end

	local function pose(t: number)
		-- the backdrop and the screen fade in, and out once it is closing
		local a = quadOut(at(t, 0, FADE_IN))
		if leaveAt then
			a *= 1 - quadIn(at(t, leaveAt, FADE_OUT))
		end
		group.GroupTransparency = 1 - a
		backdrop.BackgroundTransparency = 1 - BACKDROP * a
		groupScale.Scale = fit()
			* (
				0.94
				+ 0.06 * quadOut(at(t, 0, FADE_IN))
				- (if leaveAt then 0.04 * quadIn(at(t, leaveAt, FADE_OUT)) else 0)
			)
		root.Visible = a > 0.001 or t < FADE_IN
		-- rays open and turn the whole time; a gold flash on a Legendary or rarer
		local rp = quadOut(at(t, 0, 0.45))
		rayBox.Size = UDim2.fromOffset(380 * rp, 380 * rp)
		rayBox.Rotation = t * 18
		local flash = 0
		for i, when in times do
			if BIG[items[i].Tier] then
				flash = math.max(flash, bump(t, when, 0.6))
			end
		end
		for _, bar in bars do
			bar.BackgroundColor3 = Kit.White:Lerp(Kit.Sun, flash)
		end
		glow.Size = UDim2.fromOffset(170 + 90 * flash, 170 + 90 * flash)
		glow.BackgroundTransparency = 1 - (0.4 + 0.5 * flash) * rp
		-- the title stamps down from big
		local tp = at(t, 0.05, 0.26)
		titleScale.Scale = 1.7 - 0.7 * quadOut(tp) + 0.06 * bump(t, 0.31, 0.2)
		fadeWord(title, quadOut(tp))
		if isBest then
			local bp = at(t, 0.4, 0.4)
			bestScale.Scale = backOut(bp)
			bestBox.Rotation = -30 + 42 * quadOut(bp) + math.sin(math.max(t - 0.8, 0) * 5) * 4 * bp
		end
		-- the number rolls: the newest count drops in from above, the old one falls out below
		local shown, last = countAt(times, totals, t)
		numScale.Scale = backOut(at(t, 0.3, 0.3)) + 0.22 * bump(t, last, 0.3)
		local roll = if last >= 0 then quadOut(at(t, last, 0.18)) else 1
		local prev = 0
		for i, when in times do
			if when < last then
				prev = totals[i]
			end
		end
		now.set(tostring(shown))
		before.set(tostring(prev))
		now.root.Position = UDim2.new(0.5, 0, 0.5, -ROLL * (1 - roll))
		before.root.Position = UDim2.new(0.5, 0, 0.5, ROLL * roll)
		before.root.Visible = roll < 1
		-- the fish burst out of the number and fly to their places
		for i, tl in tiles do
			local start = times[i] - 0.24
			local p = at(t, start, 0.34)
			tl.frame.Visible = t >= start
			local spot = Vector2.new(CX, CY):Lerp(spots[i], backOut(p))
			tl.frame.Position = UDim2.fromOffset(spot.X, spot.Y)
			tl.scale.Scale = 0.3 + 0.7 * quadOut(p) + 0.25 * bump(t, times[i], 0.3)
			local x = at(t, times[i], 0.45)
			local live = t >= times[i] and x < 1
			tl.ring.Visible = live
			if live then
				local s = 1 + quadOut(x) * (if BIG[items[i].Tier] then 1.2 else 0.6)
				tl.ring.Size = UDim2.fromScale(s, s)
				local line = tl.ring:FindFirstChildOfClass("UIStroke")
				if line then
					line.Transparency = quadIn(x)
				end
			end
		end
		-- "FISH CAUGHT!" stamps in once the count has finished
		local cp = at(t, lastFish + 0.05, 0.24)
		caughtScale.Scale = 1.6 - 0.6 * quadOut(cp)
		fadeWord(caught, quadOut(cp))
		-- the metres pop up and count
		local mp = at(t, metresAtT, 0.3)
		ovalBox.Visible = t >= metresAtT
		ovalScale.Scale = backOut(mp) + 0.08 * bump(t, metresAtT + 0.7, 0.25)
		ovalBox.Position = UDim2.fromOffset(CX, OVAL_Y + 14 * (1 - quadOut(mp)))
		metresWord.set(math.floor(math.floor(metres) * quadOut(at(t, metresAtT, 0.7)) + 0.5) .. " METERS DEEP")
		ovalBox.Size = UDim2.fromOffset(ovalWide, 44)
		-- CONTINUE pops up last
		local gp = at(t, buttonAt, 0.3)
		buttonBox.Visible = t >= buttonAt
		buttonScale.Scale = backOut(gp)
		fadeWord(go, quadOut(gp))
	end
	pose(0)
	local self: Show = {
		root = root,
		length = math.huge, -- (up until a click closes it, or CatchShow.Wait runs out)
		pose = pose,
		settled = settled,
		leave = nil,
	}
	self.leave = function(t: number): number
		if not leaveAt then
			leaveAt = t
		end
		return (leaveAt :: number) + FADE_OUT
	end
	return self
end

---------------------------------------------------------------------------------------------------------------------
-- 4 Toast
local function toast(parent: Instance, metres: number, isBest: boolean, list: { Item }): Show
	local items, totals = drawn(list)
	local n = #items
	local root: Frame = Kit.new("Frame", {
		Name = "CatchShow",
		AnchorPoint = Vector2.new(0.5, 0),
		Size = UDim2.fromOffset(520, 90),
		BackgroundTransparency = 1,
		ZIndex = 15,
	}, parent)
	local TOK, GAP = 32, 4
	local LEFT = 142 -- the words at the pill's left
	local RIGHT = 160 -- the count and the metres at its right
	local function wideFor(k: number): number
		return LEFT + k * TOK + math.max(k - 1, 0) * GAP + RIGHT
	end
	local plate = pill(root, UDim2.fromOffset(wideFor(0), 46), Kit.Sun, 16)
	plate.AnchorPoint = Vector2.new(0.5, 0)
	local titleBox, titleScale = holder(plate, UDim2.fromOffset(120, 30), 18)
	local title = words({ Size = UDim2.fromScale(1, 1), TextSize = 21, Text = "GREAT DIVE!", ZIndex = 19 }, titleBox, 2)
	Kit.gradient(title.top, GOLD_TOP, GOLD_BOTTOM)
	local tokens: { Token } = {}
	local times: { number } = {}
	local STEP, FIRST = 0.22, 0.42
	for i, item in items do
		local tk = token(plate, item, TOK, true, 19, false)
		tokens[i] = tk
		times[i] = FIRST + (i - 1) * STEP + 0.1
	end
	local lastFish = if n > 0 then times[n] else FIRST
	local countBox, countScale = holder(plate, UDim2.fromOffset(52, 30), 19)
	local count = Kit.text({ Size = UDim2.fromScale(1, 1), TextSize = 22, TextColor3 = Kit.Sun, ZIndex = 20 }, countBox)
	local line: Frame = Kit.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(2, 26),
		BackgroundColor3 = Kit.White,
		BackgroundTransparency = 0.6,
		BorderSizePixel = 0,
		ZIndex = 18,
	}, plate)
	local metresBox, metresScale = holder(plate, UDim2.fromOffset(96, 30), 19)
	local metresText = Kit.text({ Size = UDim2.fromScale(1, 1), TextSize = 16, ZIndex = 20 }, metresBox)
	-- a new best: a ribbon that drops out from under the pill
	local ribbon: Frame = Kit.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Size = UDim2.fromOffset(120, 24),
		BackgroundColor3 = Kit.Danger,
		ZIndex = 15,
	}, root)
	Kit.corner(ribbon, 6)
	Kit.stroke(ribbon, 2, Kit.Ink)
	local ribbonText =
		Kit.text({ Size = UDim2.fromScale(1, 1), TextSize = 14, Text = "NEW BEST!", ZIndex = 16 }, ribbon)
	ribbon.Visible = isBest

	local metresAtT = lastFish + 0.2
	local doneAt = metresAtT + 0.7
	local leaveAt = doneAt + HOLD + 0.2
	local length = leaveAt + OUT

	local function pose(t: number)
		-- how many fish the pill has room for by now: it widens a little ahead of each one
		local room = 0
		for i = 1, n do
			room += quadOut(at(t, times[i] - 0.18, 0.16))
		end
		local wide = wideFor(room)
		local drop = at(t, 0, 0.34)
		local o = at(t, leaveAt, OUT)
		local y = -80 * (1 - backOut(drop)) - 90 * backIn(o)
		plate.Size = UDim2.fromOffset(wide, 46)
		plate.Position = UDim2.new(0.5, 0, 0, y)
		local tp = at(t, 0.14, 0.26)
		titleBox.Position = UDim2.fromOffset(LEFT / 2 + 4 - 18 * (1 - quadOut(tp)), 23)
		titleScale.Scale = 0.6 + 0.4 * backOut(tp)
		title.fade(quadOut(tp))
		for i, tk in tokens do
			local a = times[i] - 0.1
			local p = at(t, a, 0.22)
			tk.frame.Visible = t >= a
			tk.frame.Position = UDim2.fromOffset(LEFT + TOK / 2 + (i - 1) * (TOK + GAP), 23 - 14 * (1 - quadOut(p)))
			tk.scale.Scale = backOut(p) + 0.25 * bump(t, times[i], 0.25)
			burst(tk, t, times[i], 0.35, if BIG[items[i].Tier] then 1.2 else 0.6)
		end
		local shown, last = countAt(times, totals, t)
		local right = wide - RIGHT
		local cp = at(t, 0.3, 0.24)
		countBox.Position = UDim2.fromOffset(right + 30, 23)
		countScale.Scale = backOut(cp) + 0.4 * bump(t, last, 0.25)
		fadeText(count, quadOut(cp))
		count.Text = if n > 0 then "×" .. shown else "—"
		line.Position = UDim2.fromOffset(right + 62, 23)
		line.Size = UDim2.fromOffset(2, 26 * quadOut(at(t, metresAtT - 0.1, 0.2)))
		local mp = at(t, metresAtT, 0.28)
		metresBox.Position = UDim2.fromOffset(right + 112 + 16 * (1 - quadOut(mp)), 23)
		metresScale.Scale = 0.7 + 0.3 * backOut(mp) + 0.12 * bump(t, doneAt, 0.25)
		fadeText(metresText, quadOut(mp))
		metresText.Text = string.gsub(metresAt(metres, t, metresAtT, 0.7), " deep", "")
		if isBest then
			local rp = at(t, doneAt, 0.3)
			ribbon.Visible = t >= doneAt and o < 1
			ribbon.Position = UDim2.new(0.5, 0, 0, y + 22 + 26 * backOut(rp))
			ribbon.Rotation = -4 * backOut(rp)
			fadeText(ribbonText, quadOut(rp))
		end
		root.Visible = o < 1
	end
	pose(0)
	return { root = root, length = length, pose = pose }
end

local BUILDERS: { [number]: (Instance, number, boolean, { Item }) -> Show } = {
	[1] = cards,
	[2] = stack,
	[3] = screen,
	[4] = toast,
}
-- where each sits on the HUD: clear of the rider at the middle and of the land strip at the top
local PLACES: { [number]: UDim2 } = {
	[1] = UDim2.fromScale(0.5, 0.36),
	[2] = UDim2.new(1, -24, 0.5, 0),
	[3] = UDim2.fromScale(0.5, 0.5),
	[4] = UDim2.new(0.5, 0, 0, 96),
}

-- where a look sits on the HUD
function CatchShow.placeOf(look: number): UDim2
	return PLACES[look] or UDim2.fromScale(0.5, 0.36)
end

-- One look built and stopped at its start, for sheets: the caller places its root and calls pose(t)
function CatchShow.preview(parent: Instance, look: number, metres: number, isBest: boolean, list: { Item }?): Show?
	local build = BUILDERS[look]
	if not build then
		return nil
	end
	return build(parent, metres, isBest, list or {})
end

-- The catch screen stays up until a click or tap closes it, or this many seconds after it has settled
CatchShow.Wait = 20
-- The clock it plays by (a capture script may stop it to shoot frames of the real thing)
CatchShow.Clock = os.clock

local current: { show: Show, conns: { RBXScriptConnection } }? = nil
local pressNow: () -> () = function() end

-- A click or tap on the catch screen, as the screen's own input takes it (also for test scripts)
function CatchShow.press()
	pressNow()
end

function CatchShow.stop()
	if current then
		for _, conn in current.conns do
			conn:Disconnect()
		end
		current.show.root:Destroy()
		current = nil
	end
end

-- Whether the catch screen (or a look) is up
function CatchShow.showing(): boolean
	return current ~= nil
end

local PRESS: { [Enum.UserInputType]: boolean } = {
	[Enum.UserInputType.MouseButton1] = true,
	[Enum.UserInputType.Touch] = true,
}
local KEYS: { [Enum.KeyCode]: boolean } = {
	[Enum.KeyCode.Return] = true,
	[Enum.KeyCode.Space] = true,
	[Enum.KeyCode.ButtonA] = true,
}

-- Plays the look in the HUD (false: no such look, Banners plays its own). The catch screen (look 3): a click or tap
-- anywhere while it is still coming in skips to the end; the next one closes it. Each press is taken as it comes (not
-- at the next frame), so two presses in one frame are a skip and a close, and presses once it is closing do nothing
function CatchShow.play(parent: Instance, look: number, metres: number, isBest: boolean, list: { Item }?): boolean
	local show = CatchShow.preview(parent, look, metres, isBest, list)
	if not show then
		return false
	end
	CatchShow.stop()
	show.root.Position = PLACES[look]
	local start = CatchShow.Clock()
	local goneAt = show.length
	local closing = false
	local entry: { show: Show, conns: { RBXScriptConnection } }
	local hit: TextButton? = nil
	local function close(t: number)
		closing = true
		goneAt = (show.leave :: (number) -> number)(t)
		-- (presses go on through to the game while it fades)
		if hit then
			hit.Visible = false
		end
	end
	pressNow = function()
		if current ~= entry or closing then
			return
		end
		local t = CatchShow.Clock() - start
		local settled = show.settled
		if settled and t < settled then
			start = CatchShow.Clock() - settled -- skip: everything at once in its place
			show.pose(settled)
		elseif show.leave then
			close(t)
		end
	end
	entry = { show = show, conns = {} }
	if show.leave then
		-- one button over the whole screen takes every press (nothing behind it gets them while the screen is up)
		local button: TextButton = Kit.new("TextButton", {
			Name = "Hit",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.new(1, 600, 1, 600),
			BackgroundTransparency = 1,
			Text = "",
			AutoButtonColor = false,
			ZIndex = 99,
		}, show.root)
		hit = button
		table.insert(
			entry.conns,
			button.InputBegan:Connect(function(input: InputObject)
				if PRESS[input.UserInputType] then
					pressNow()
				end
			end)
		)
		table.insert(
			entry.conns,
			UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
				-- (not a key the game has taken already: typing in the chat box)
				if KEYS[input.KeyCode] and not processed then
					pressNow()
				end
			end)
		)
	end
	table.insert(
		entry.conns,
		RunService.RenderStepped:Connect(function()
			local t = CatchShow.Clock() - start
			if not closing and show.leave and show.settled and t >= show.settled + CatchShow.Wait then
				close(t)
			end
			show.pose(t)
			if t >= goneAt and current == entry then
				CatchShow.stop()
			end
		end)
	)
	current = entry
	return true
end

return CatchShow
