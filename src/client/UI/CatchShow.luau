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

local Config = require(ReplicatedStorage.Shared.Config)
local Kit = require(script.Parent.Kit)
local Portrait = require(script.Parent.Portrait)

local CatchShow = {}

export type Item = { Id: string, Tier: string }
export type Show = {
	root: Frame,
	length: number, -- seconds until it is gone
	pose: (t: number) -> (),
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
-- 3 Big number
local function bigNumber(parent: Instance, metres: number, isBest: boolean, list: { Item }): Show
	local items, totals = drawn(list)
	local n = #items
	local root: Frame = Kit.new("Frame", {
		Name = "CatchShow",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(440, 290),
		BackgroundTransparency = 1,
		ZIndex = 15,
	}, parent)
	local rootScale = Kit.new("UIScale", {}, root)
	local CX, CY = 220, 116

	local rayBox, bars = rays(root, 320, 9, 15)
	rayBox.Position = UDim2.fromOffset(CX, CY)
	local glow: Frame = Kit.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(CX, CY),
		Size = UDim2.fromOffset(150, 150),
		BackgroundColor3 = Kit.Sun,
		BackgroundTransparency = 0.6,
		ZIndex = 15,
	}, root)
	Kit.corner(glow, 999)
	Kit.new("UIGradient", {
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.5, 0.2),
			NumberSequenceKeypoint.new(1, 1),
		}),
	}, glow)

	local titleBox, titleScale = holder(root, UDim2.fromOffset(400, 40), 19)
	titleBox.Position = UDim2.fromOffset(CX, 26)
	titleBox.Rotation = -3
	local title = words({ Size = UDim2.fromScale(1, 1), TextSize = 34, Text = "GREAT DIVE!", ZIndex = 20 }, titleBox, 3)
	Kit.gradient(title.top, GOLD_TOP, GOLD_BOTTOM)
	local best, bestScale = badge(root, "BEST!", 50, 23)
	best.Position = UDim2.fromOffset(CX + 150, 16)
	best.Visible = isBest

	-- the number: two labels in a window, the old one rolling up out as the new one rolls in from below
	local window: Frame = Kit.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(CX, CY),
		Size = UDim2.fromOffset(150, 96),
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		ZIndex = 20,
	}, root)
	local numScale = Kit.new("UIScale", {}, window)
	local function digit(): Words
		local w = words({ Size = UDim2.fromScale(1, 1), TextSize = 88, Text = "0", ZIndex = 22 }, window, 5)
		Kit.gradient(w.top, Color3.fromRGB(255, 255, 230), Color3.fromRGB(255, 186, 40))
		return w
	end
	local now, before = digit(), digit()
	local caughtBox, caughtScale = holder(root, UDim2.fromOffset(300, 30), 20)
	caughtBox.Position = UDim2.fromOffset(CX, CY + 52)
	local caught = words({
		Size = UDim2.fromScale(1, 1),
		TextSize = 22,
		Text = if n > 0 then "FISH CAUGHT!" else "NO CATCH THIS TIME",
		ZIndex = 21,
	}, caughtBox, 2.5)

	-- the fish: out of the number to an arc round its lower half
	local tokens: { Token } = {}
	local spots: { Vector2 } = {}
	local times: { number } = {}
	local STEP, FIRST = 0.3, 0.7
	for i, item in items do
		local tk = token(root, item, 42, true, 24, false)
		tokens[i] = tk
		-- a smile under the words: the middle lowest, the ends a little higher
		local u = (i - (n + 1) / 2) / 3
		spots[i] = Vector2.new(CX + (i - (n + 1) / 2) * 50, 222 - 18 * u * u)
		times[i] = FIRST + (i - 1) * STEP + 0.24
	end
	local lastFish = if n > 0 then times[n] else FIRST
	local pillBox, pillScale = holder(root, UDim2.fromOffset(160, 28), 18)
	pillBox.Position = UDim2.fromOffset(CX, 266)
	local metresPill = pill(pillBox, UDim2.fromScale(1, 1), nil, 18)
	metresPill.Position = UDim2.fromScale(0.5, 0.5)
	local metresText = Kit.text({ Size = UDim2.fromScale(1, 1), TextSize = 15, ZIndex = 19 }, metresPill)

	local metresAtT = lastFish + 0.32
	local doneAt = metresAtT + 0.7
	local leaveAt = doneAt + HOLD
	local length = leaveAt + OUT

	local function pose(t: number)
		-- rays open and turn the whole time; a gold flash on a Legendary or rarer
		local rp = quadOut(at(t, 0, 0.45))
		rayBox.Size = UDim2.fromOffset(320 * rp, 320 * rp)
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
		glow.Size = UDim2.fromOffset(150 + 80 * flash, 150 + 80 * flash)
		glow.BackgroundTransparency = 1 - (0.4 + 0.5 * flash) * rp
		-- the title stamps down from big
		local tp = at(t, 0.05, 0.26)
		titleScale.Scale = 2.2 - 1.2 * quadOut(tp) + 0.06 * bump(t, 0.31, 0.2)
		title.fade(quadOut(tp))
		if isBest then
			local bp = at(t, 0.4, 0.4)
			bestScale.Scale = backOut(bp)
			best.Rotation = -30 + 44 * quadOut(bp) + math.sin(math.max(t - 0.8, 0) * 5) * 4 * bp
		end
		-- the number rolls: the newest count drops in from above, the old one falls out below
		local shown, last = countAt(times, totals, t)
		local np = at(t, 0.3, 0.3)
		numScale.Scale = backOut(np) + 0.28 * bump(t, last, 0.3)
		local roll = if last >= 0 then quadOut(at(t, last, 0.16)) else 1
		now.top.Text, now.under.Text = tostring(shown), tostring(shown)
		local prev = 0
		for i, when in times do
			if when < last then
				prev = totals[i]
			end
		end
		before.top.Text, before.under.Text = tostring(prev), tostring(prev)
		now.top.Position = UDim2.fromOffset(0, -96 * (1 - roll))
		now.under.Position = UDim2.fromOffset(0, 5 - 96 * (1 - roll))
		before.top.Position = UDim2.fromOffset(0, 96 * roll)
		before.under.Position = UDim2.fromOffset(0, 5 + 96 * roll)
		before.top.Visible, before.under.Visible = roll < 1, roll < 1
		-- the fish burst out of the number and fly to their places, spinning
		for i, tk in tokens do
			local a = times[i] - 0.24
			local p = at(t, a, 0.34)
			tk.frame.Visible = t >= a
			local from = Vector2.new(CX, CY)
			local to = spots[i]
			local k = backOut(p)
			local spot = from:Lerp(to, k)
			tk.frame.Position = UDim2.fromOffset(spot.X, spot.Y)
			tk.frame.Rotation = 270 * (1 - quadOut(p))
			tk.scale.Scale = 0.3 + 0.7 * quadOut(p) + 0.3 * bump(t, times[i], 0.3)
			burst(tk, t, times[i], 0.45, if BIG[items[i].Tier] then 1.5 else 0.8)
		end
		-- "FISH CAUGHT!" stamps in once the count has finished
		local cp = at(t, lastFish + 0.05, 0.24)
		caughtScale.Scale = 1.8 - 0.8 * quadOut(cp)
		caught.fade(quadOut(cp))
		local mp = at(t, metresAtT, 0.3)
		pillBox.Visible = t >= metresAtT
		pillScale.Scale = backOut(mp) + 0.1 * bump(t, doneAt, 0.25)
		pillBox.Position = UDim2.fromOffset(CX, 266 + 14 * (1 - quadOut(mp)))
		fadeText(metresText, quadOut(mp))
		metresText.Text = metresAt(metres, t, metresAtT, 0.7)
		local o = at(t, leaveAt, OUT)
		rootScale.Scale = 1 - backIn(o)
		root.Visible = o < 1
	end
	pose(0)
	return { root = root, length = length, pose = pose }
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
	[3] = bigNumber,
	[4] = toast,
}
-- where each sits on the HUD: clear of the rider at the middle and of the land strip at the top
local PLACES: { [number]: UDim2 } = {
	[1] = UDim2.fromScale(0.5, 0.36),
	[2] = UDim2.new(1, -24, 0.5, 0),
	[3] = UDim2.fromScale(0.5, 0.36),
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

local current: { show: Show, conn: RBXScriptConnection }? = nil

function CatchShow.stop()
	if current then
		current.conn:Disconnect()
		current.show.root:Destroy()
		current = nil
	end
end

-- Plays the look in the HUD (false: no such look, Banners plays its own)
function CatchShow.play(parent: Instance, look: number, metres: number, isBest: boolean, list: { Item }?): boolean
	local show = CatchShow.preview(parent, look, metres, isBest, list)
	if not show then
		return false
	end
	CatchShow.stop()
	show.root.Position = PLACES[look]
	local start = os.clock()
	local entry: { show: Show, conn: RBXScriptConnection }
	entry = {
		show = show,
		conn = RunService.RenderStepped:Connect(function()
			local t = os.clock() - start
			show.pose(t)
			if t >= show.length and current == entry then
				CatchShow.stop()
			end
		end),
	}
	current = entry
	return true
end

return CatchShow
