--!strict
-- The end of a dive rebuilt on caught-text option 5's banner (task gd1; Hugo, 2026-11-19: reuse caught-text 5's banner
-- and animation for GREAT DIVE when you respawn; the caught fish plop down one by one with the same animation, and a
-- shiny number counts them). CatchShow look 5 (Kit.CatchLook); its variant is Kit.DiveLook (in Studio the
-- workspace's "DiveLook" number):
--   1 Slam: the band slashes open from a hairline, GREAT DIVE! slams onto it from the camera; each fish
--     slams down the same way (huge, squash, ring back) with a white flash and chips; the number shimmers gold
--   2 Drop (default, Hugo's pick 2026-11-19): the band drops in from above and bounces; each fish drops and bounces; the number takes the rarity
--     colours of the fish that just landed
--   3 Pop: the band unrolls from its left end; each fish pops out of nothing and overshoots with a ring; the number
--     bursts (rays and chips) on every count
--   4 Stamp: the band hovers big, then stamps down with dust; each fish hovers and stamps with dust; the number
--     shimmers gold and bursts
-- Kept from the catch screen (CatchShow look 3): every word a rarity word (Kit.word) in Bangers, the see-through
-- backdrop fading in and out with the screen, METERS DEEP on a black oval in the land's colours, BEST! (the red
-- medallion) on the end of the title, a click anywhere skips to the end and the next closes (CatchShow.play does the
-- presses; left alone it closes the same way 2 seconds after it has settled: Banners' GREAT_STAY, task b3). The fish tiles are CatchShow's own (passed in as `tile`), so their look stays in one place.
-- Like the other looks, it is a pose of the time since it began (pose(t)): the game plays it frame by frame, a capture
-- stops it at any moment. Sheet: docs/attachments/great-dive-options-1.png, by tools/ui/catch_show/gd1_capture.py.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Zones = require(ReplicatedStorage.Shared.Zones)
local Kit = require(script.Parent.Kit)

local DiveScreen = {}

export type Item = { Id: string, Tier: string }
export type Tile = { frame: Frame, scale: UIScale, ring: Frame }
export type Show = {
	root: Frame,
	length: number,
	pose: (t: number) -> (),
	settled: number?,
	leave: ((t: number) -> number)?,
}
export type Parts = {
	tile: (parent: Instance, item: Item, size: number, z: number) -> Tile,
	star: (parent: Instance, size: number, z: number) -> Frame,
}

type Variant = { Name: string, Enter: string, Plop: string, Count: string }
local VARIANTS: { Variant } = {
	{ Name = "Slam", Enter = "slash", Plop = "slam", Count = "shimmer" },
	{ Name = "Drop", Enter = "drop", Plop = "bounce", Count = "rarity" },
	{ Name = "Pop", Enter = "unroll", Plop = "pop", Count = "burst" },
	{ Name = "Stamp", Enter = "stamp", Plop = "stamp", Count = "both" },
}
DiveScreen.Variants = VARIANTS

-- the variant in play: Kit.DiveLook, or in Studio the workspace's "DiveLook" number
function DiveScreen.variant(): number
	local own = workspace:GetAttribute("DiveLook")
	if RunService:IsStudio() and type(own) == "number" and VARIANTS[own] then
		return own
	end
	return if VARIANTS[Kit.DiveLook] then Kit.DiveLook else 1
end

---------------------------------------------------------------------------------------------------------------------
-- easing (as CaughtText's)
local function at(t: number, a: number, d: number): number
	return math.clamp((t - a) / d, 0, 1)
end
local function backOut(x: number): number
	local c = 1.9
	return 1 + (c + 1) * (x - 1) ^ 3 + c * (x - 1) ^ 2
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
-- an overshoot that rings down: 0 at s = 0, over 1 by about a fifth, settled in half a second
local function settle(s: number): number
	if s <= 0 then
		return 0
	end
	return 1 - math.exp(-7 * s) * math.cos(15 * s)
end
-- a bounce off the floor: 0 at s = 0 (the first touch), small hops after, settled in about 0.45 s
local function hop(s: number): number
	if s <= 0 then
		return 0
	end
	return math.abs(math.sin(s * 14)) * math.exp(-8 * s)
end
local function bump(t: number, a: number, d: number): number
	if t < a then
		return 0
	end
	return (1 - at(t, a, d)) ^ 2
end
-- caught text 5's slam: from the camera, huge, down to 0.8 in `fall` seconds (the hit), then rings back to 1
local function slamScale(s: number, fall: number, from: number): number
	if s < fall then
		return lerp(from, 0.8, quadIn(math.max(s, 0) / fall))
	end
	return 0.8 + 0.2 * settle(s - fall)
end
local function P(x: number, y: number): UDim2
	return UDim2.fromOffset(x, y)
end

local BIG: { [string]: boolean } = { Legendary = true, Mythic = true, Secret = true }
local FONT = Enum.Font.Bangers
local BACKDROP = 0.35
local FADE_IN, FADE_OUT = 0.22, 0.3
local FIT_ROOM = Vector2.new(40, 150)
local BAND_ENDS = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 1),
	NumberSequenceKeypoint.new(0.16, 0.05),
	NumberSequenceKeypoint.new(0.84, 0.05),
	NumberSequenceKeypoint.new(1, 1),
})
local RAY = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 1),
	NumberSequenceKeypoint.new(0.3, 0.55),
	NumberSequenceKeypoint.new(0.5, 0.7),
	NumberSequenceKeypoint.new(0.7, 0.55),
	NumberSequenceKeypoint.new(1, 1),
})
-- the shimmer: a bright slanted strip that runs across the number
local SHINE = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 1),
	NumberSequenceKeypoint.new(0.4, 1),
	NumberSequenceKeypoint.new(0.5, 0.05),
	NumberSequenceKeypoint.new(0.6, 1),
	NumberSequenceKeypoint.new(1, 1),
})

-- a rarity's word tones: gold for a Legendary, its own colour made bright for the rest
local function tierPal(tier: string): Kit.Pal
	if tier == "Legendary" then
		return Kit.GoldPal
	end
	local entry = Config.Tiers[tier]
	return if entry then Kit.palOf(entry.Colour) else Kit.WhitePal
end

-- a word's letters and edges faded as one (a = 1 as built)
local bases: { [Instance]: number } = setmetatable({}, { __mode = "k" }) :: any
local function fadeAll(root: Instance, a: number)
	for _, d in root:GetDescendants() do
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

-- Specks thrown from a point (chips, dust); seeded, so a pose is the same every time
type Speck = { f: Frame, angle: number, speed: number, spin: number, life: number }
local function specks(
	parent: Instance,
	count: number,
	seed: number,
	colours: { Color3 },
	z: number,
	up: boolean?
): { Speck }
	local rng = Random.new(seed)
	local list: { Speck } = {}
	for i = 1, count do
		local size = rng:NextNumber(5, 10)
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
		-- (dust from a stamp flies out sideways and up, never down into the floor)
		local angle = if up then -rng:NextNumber(0.1, math.pi - 0.1) else rng:NextNumber(0, math.pi * 2)
		table.insert(list, {
			f = f,
			angle = angle,
			speed = rng:NextNumber(0.55, 1),
			spin = rng:NextNumber(-540, 540),
			life = rng:NextNumber(0.45, 0.8),
		})
	end
	return list
end
local function specksPose(
	list: { Speck },
	t: number,
	t0: number,
	x: number,
	y: number,
	reach: number,
	fall: number,
	sy: number
)
	for _, s in list do
		local age = t - t0
		if age < 0 or age > s.life then
			s.f.Visible = false
			continue
		end
		local k = age / s.life
		local out = reach * s.speed * quadOut(k)
		s.f.Visible = true
		s.f.Position = P(x + math.cos(s.angle) * out, y + math.sin(s.angle) * out * sy + fall * k * k)
		s.f.Rotation = s.spin * age
		s.f.BackgroundTransparency = k ^ 3
		local stroke = s.f:FindFirstChildOfClass("UIStroke")
		if stroke then
			stroke.Transparency = k ^ 3
		end
	end
end

---------------------------------------------------------------------------------------------------------------------
function DiveScreen.build(
	parent: Instance,
	metres: number,
	isBest: boolean,
	items: { Item },
	totals: { number },
	parts: Parts,
	which: number?
): Show
	local v = VARIANTS[which or DiveScreen.variant()] or VARIANTS[1]
	local n = #items
	local W, H = 720, 400
	local CX = W / 2

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
	local group: CanvasGroup = Kit.new("CanvasGroup", {
		Name = "Screen",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = P(W, H),
		BackgroundTransparency = 1,
		GroupTransparency = 1,
		ZIndex = 2,
	}, root)
	local groupScale = Kit.new("UIScale", {}, group)
	-- the body shakes with every hit
	local body: Frame = Kit.new("Frame", {
		Name = "Body",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ZIndex = 2,
	}, group)

	-- the land reached: the band's colours (caught text 5's band is the rarity's; this one is the land's)
	local land = 1
	for i, zone in Zones.fallback() do
		if metres >= zone.Metres then
			land = i
		end
	end
	local landPal = Kit.palOf(Kit.Lands[math.clamp(land, 1, #Kit.Lands)])

	-------------------------------------------------------------------------------------------------------------
	-- the banner: caught text 5's band, its light edges, speed lines and flash, "GREAT DIVE!" slammed onto it
	local BY = 70
	local BW, BH = 700, 88
	local band: Frame = Kit.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = P(CX, BY),
		Size = P(BW, BH),
		Rotation = -4,
		BackgroundColor3 = Kit.White,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		ZIndex = 3,
	}, body)
	Kit.new("UIGradient", {
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, landPal.Deep),
			ColorSequenceKeypoint.new(0.5, landPal.Dark:Lerp(landPal.Deep, 0.35)),
			ColorSequenceKeypoint.new(1, landPal.Deep),
		}),
		Transparency = BAND_ENDS,
	}, band)
	local edges: { Frame } = {}
	for _, y in { 0, 1 } do
		local edge = Kit.new("Frame", {
			AnchorPoint = Vector2.new(0, y),
			Position = UDim2.fromScale(0, y),
			Size = UDim2.new(1, 0, 0, 4),
			BackgroundColor3 = landPal.Light,
			BorderSizePixel = 0,
			ZIndex = 4,
		}, band)
		Kit.new("UIGradient", { Transparency = BAND_ENDS }, edge)
		table.insert(edges, edge)
	end
	type Streak = { f: Frame, start: number, speed: number, y: number }
	local streaks: { Streak } = {}
	local rng = Random.new(55)
	for i = 1, 8 do
		local s: Frame = Kit.new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Size = P(rng:NextNumber(60, 150), rng:NextNumber(2, 4)),
			BackgroundColor3 = Kit.White,
			BorderSizePixel = 0,
			Visible = false,
			ZIndex = 4,
		}, band)
		table.insert(
			streaks,
			{ f = s, start = rng:NextNumber(-0.3, 0.25), speed = rng:NextNumber(1.6, 2.6), y = 10 + (i - 1) * 9.5 }
		)
	end
	local flash: Frame = Kit.new("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Kit.White,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 5,
	}, band)
	-- (the stamp's shadow, under the band while it hovers)
	local shadow: Frame = Kit.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = P(CX, BY + 6),
		Size = P(BW * 0.8, BH * 0.8),
		Rotation = -4,
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 2,
	}, body)
	Kit.new("UIGradient", { Transparency = BAND_ENDS }, shadow)

	local titleBox: Frame = Kit.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		ZIndex = 10,
	}, body)
	local titleScale = Kit.new("UIScale", {}, titleBox)
	local title = Kit.word(titleBox, {
		Text = "GREAT DIVE!",
		TextSize = 66,
		Font = FONT,
		Pal = Kit.GoldPal,
		Glow = true,
		Edge = 0.1,
		Position = UDim2.fromScale(0.5, 0.5),
		ZIndex = 10,
	})
	titleBox.Size = P(title.wide, title.high)
	titleBox.Rotation = -4
	-- BEST!: the red medallion on the end of the title
	local BEST_SIZE = 70
	local bestBox: Frame = Kit.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = P(BEST_SIZE, BEST_SIZE),
		BackgroundTransparency = 1,
		Visible = isBest,
		ZIndex = 16,
	}, body)
	local bestScale = Kit.new("UIScale", {}, bestBox)
	parts.star(bestBox, BEST_SIZE, 16)
	local bestWord = Kit.word(bestBox, {
		Text = "BEST!",
		TextSize = 25,
		Font = FONT,
		Pal = Kit.WhitePal,
		Edge = 0.13,
		Position = UDim2.fromScale(0.5, 0.52),
		ZIndex = 20,
	})
	bestWord.root.Rotation = 12
	local pair = title.wide + (if isBest then BEST_SIZE * 0.66 else 0)
	local TITLE_X = CX - pair / 2 + title.wide / 2
	titleBox.Position = P(TITLE_X, BY - 2)
	local lift = math.sin(math.rad(4)) * title.wide / 2
	local BEST_AT = Vector2.new(CX - pair / 2 + title.wide + BEST_SIZE * 0.3, BY - lift - 22)
	bestBox.Position = P(BEST_AT.X, BEST_AT.Y)
	local chips = specks(body, 16, 66, { landPal.Light, Kit.White, Kit.Sun }, 9, v.Enter == "stamp")

	-------------------------------------------------------------------------------------------------------------
	-- the shiny number and "FISH CAUGHT!" beside it, centred as a pair
	local ROW_Y = 172
	local countBox: Frame = Kit.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = P(CX, ROW_Y),
		Size = P(10, 10),
		BackgroundTransparency = 1,
		ZIndex = 12,
	}, body)
	local countScale = Kit.new("UIScale", {}, countBox)
	local number = Kit.word(countBox, {
		Text = tostring(totals[n] or 0),
		TextSize = 96,
		Font = FONT,
		Pal = Kit.GoldPal,
		Glow = true,
		Edge = 0.075,
		AnchorPoint = Vector2.new(0.5, 0.5),
		ZIndex = 12,
	})
	local numScale = Kit.new("UIScale", {}, number.root)
	-- the shimmer: the same letters in white over the number, seen only through a strip that runs across
	local shine: TextLabel = Kit.new("TextLabel", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Font = FONT,
		TextSize = 96,
		TextColor3 = Kit.White,
		Text = "",
		ZIndex = 17,
	}, number.root)
	local shineFill = Kit.new("UIGradient", { Rotation = 18, Transparency = SHINE }, shine)
	local numWide = number.wide -- (room for the whole count from the start, so the pair never moves as it counts)
	local caught = Kit.word(countBox, {
		Text = if n > 0 then "FISH CAUGHT!" else "NO CATCH THIS TIME",
		TextSize = if n > 0 then 40 else 36,
		Font = FONT,
		Pal = Kit.WhitePal,
		Glow = true,
		Edge = 0.12,
		AnchorPoint = Vector2.new(0.5, 0.5),
		ZIndex = 12,
	})
	local GAP = 14
	local rowWide = if n > 0 then numWide + GAP + caught.wide else caught.wide
	countBox.Size = P(rowWide, number.high)
	number.root.Visible = n > 0
	number.root.Position = P(numWide / 2, number.high / 2)
	caught.root.Position = if n > 0
		then P(numWide + GAP + caught.wide / 2, number.high / 2 + 10)
		else P(rowWide / 2, number.high / 2)
	-- the burst behind the number: rays and a ring, and chips
	local burstAt = Vector2.new(CX - rowWide / 2 + numWide / 2, ROW_Y)
	local rayBox: Frame = Kit.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = P(burstAt.X, burstAt.Y),
		Size = P(200, 200),
		BackgroundTransparency = 1,
		Visible = false,
		ZIndex = 11,
	}, body)
	local rayBars: { Frame } = {}
	for i = 1, 8 do
		local bar = Kit.new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(1, 0.1),
			Rotation = (i - 1) * 180 / 8,
			BackgroundColor3 = Kit.Sun,
			BorderSizePixel = 0,
			ZIndex = 11,
		}, rayBox)
		Kit.new("UIGradient", { Transparency = RAY }, bar)
		table.insert(rayBars, bar)
	end
	local countRing: Frame = Kit.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = P(burstAt.X, burstAt.Y),
		BackgroundTransparency = 1,
		Visible = false,
		ZIndex = 11,
	}, body)
	Kit.corner(countRing, 999)
	local countRingLine = Kit.stroke(countRing, 4, Kit.Sun)
	local countChips: { { Speck } } = {}
	local burstCount = v.Count == "burst" or v.Count == "both"
	if burstCount then
		for i = 1, n do
			countChips[i] = specks(body, 8, 100 + i, { Kit.Sun, Kit.White, Kit.GoldPal.Dark }, 13)
		end
	end

	-------------------------------------------------------------------------------------------------------------
	-- the fish: one row, each plops down in turn
	local TILE, STEP_X = 56, 66
	local FISH_Y = 266
	local tiles: { Tile } = {}
	local flashes: { Frame } = {}
	local dusts: { { Speck } } = {}
	local spots: { Vector2 } = {}
	local starts: { number } = {}
	local lands: { number } = {}
	local FALL = ({ slam = 0.1, bounce = 0.22, pop = 0.0, stamp = 0.26 } :: { [string]: number })[v.Plop] or 0.1
	local FIRST, STEP = 0.78, 0.26
	for i, item in items do
		local tl = parts.tile(body, item, TILE, 24)
		tiles[i] = tl
		spots[i] = Vector2.new(CX + (i - (n + 1) / 2) * STEP_X, FISH_Y)
		starts[i] = FIRST + (i - 1) * STEP
		lands[i] = starts[i] + FALL
		local f: Frame = Kit.new("Frame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = Kit.White,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ZIndex = 30,
		}, tl.frame)
		flashes[i] = f
		local tierColour = Config.Tiers[item.Tier] and Config.Tiers[item.Tier].Colour or Kit.White
		dusts[i] = specks(
			body,
			if BIG[item.Tier] then 10 else 6,
			200 + i,
			if v.Plop == "stamp" then { Color3.fromRGB(230, 222, 200), Kit.White } else { tierColour, Kit.White },
			22,
			v.Plop == "stamp" or v.Plop == "bounce"
		)
	end
	local lastFish = if n > 0 then lands[n] else FIRST

	-------------------------------------------------------------------------------------------------------------
	-- the metres: a black see-through oval, the land strip's cartoon font in the land's colours
	local ovalBox: Frame = Kit.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = P(10, 44),
		BackgroundTransparency = 1,
		ZIndex = 14,
	}, body)
	local ovalScale = Kit.new("UIScale", {}, ovalBox)
	local OVAL_Y = if n > 0 then FISH_Y + 72 else ROW_Y + 80
	local oval: Frame = Kit.new("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.3,
		BorderSizePixel = 0,
		ZIndex = 14,
	}, ovalBox)
	Kit.corner(oval, 999)
	local metresWord = Kit.word(ovalBox, {
		Text = math.floor(metres) .. " METERS DEEP",
		TextSize = 26,
		Font = Kit.LandMetresFont,
		Pal = landPal,
		Position = UDim2.new(0.5, 0, 0.5, 1),
		ZIndex = 15,
	})
	local ovalWide = metresWord.wide + 34

	local metresAtT = lastFish + 0.34
	local settled = metresAtT + 0.85
	local leaveAt: number? = nil

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

	-- the band's entry by variant: how wide and tall it is, where, how faint, and when it hits
	local HIT = if v.Enter == "stamp" then 0.36 else 0.28
	local function poseBand(t: number): number
		local wide, high, x, y, alpha, scale = BW, BH, CX, BY, 1, 1
		if v.Enter == "slash" then
			-- caught text 5: a hairline streaks across, opens past its height and settles
			local LINE, OPEN = 0.12, 0.2
			wide = BW * quadOut(at(t, 0, LINE))
			if t < LINE then
				high = BH * 0.06
			elseif t < OPEN then
				high = BH * lerp(0.06, 1.18, quadOut(at(t, LINE, OPEN - LINE)))
			else
				high = BH * (1 + 0.18 * (1 - settle(t - OPEN)))
			end
		elseif v.Enter == "drop" then
			-- falls from above the screen, lands at the hit and bounces
			if t < HIT then
				y = lerp(-BH, BY, quadIn(at(t, 0.04, HIT - 0.04)))
			else
				y = BY - 26 * hop(t - HIT)
				high = BH * (1 - 0.12 * bump(t, HIT, 0.16))
			end
		elseif v.Enter == "unroll" then
			-- unrolls from its left end, overshooting a little
			local p = at(t, 0, HIT)
			wide = BW * math.max(backOut(p), 0)
			x = CX - BW / 2 + wide / 2
			high = BH * (0.5 + 0.5 * quadOut(p))
		elseif v.Enter == "stamp" then
			-- hovers big and faint, lifts a touch, slams down
			local HOVER = 0.22
			if t < HOVER then
				scale = 1.35 + 0.05 * quadOut(at(t, 0, HOVER))
				alpha = 0.45 * quadOut(at(t, 0, HOVER))
			elseif t < HIT then
				scale = lerp(1.4, 0.94, quadIn(at(t, HOVER, HIT - HOVER)))
				alpha = lerp(0.45, 1, at(t, HOVER, HIT - HOVER))
			else
				scale = 0.94 + 0.06 * settle(t - HIT)
			end
			shadow.Visible = t < HIT
			shadow.BackgroundTransparency = 1 - 0.35 * alpha
			shadow.Size = P(BW * (1.25 - 0.25 * at(t, 0, HIT)), BH * 0.9)
		end
		band.Size = P(wide * scale, high * scale)
		band.Position = P(x, y)
		band.BackgroundTransparency = 1 - alpha
		band.Visible = t > 0
		for _, edge in edges do
			edge.BackgroundTransparency = 1 - alpha
			edge.Size = UDim2.new(1, 0, 0, if high < BH * 0.5 then 2 else 4)
		end
		return y
	end

	local function pose(t: number)
		-- the backdrop and the screen fade in, and out once it is closing
		local a = quadOut(at(t, 0, FADE_IN))
		if leaveAt then
			a *= 1 - quadIn(at(t, leaveAt, FADE_OUT))
		end
		group.GroupTransparency = 1 - a
		backdrop.BackgroundTransparency = 1 - BACKDROP * a
		groupScale.Scale = fit() * (1 - (if leaveAt then 0.04 * quadIn(at(t, leaveAt, FADE_OUT)) else 0))
		root.Visible = a > 0.001 or t < FADE_IN

		-- the band, its flash and speed lines
		local bandY = poseBand(t)
		if v.Enter ~= "stamp" then
			shadow.Visible = false
		end
		flash.BackgroundTransparency = 1 - 0.9 * bump(t, HIT, 0.3)
		for _, s in streaks do
			local k = (t - HIT - s.start) * s.speed
			s.f.Visible = t >= HIT and k > 0 and k < 1
			s.f.Position = P(BW * (k * 1.4 - 0.2), s.y)
			s.f.BackgroundTransparency = 0.25 + 0.75 * k
		end
		-- the title: caught text 5's slam, from the camera onto the band
		local wt = t - (HIT - 0.1)
		titleBox.Visible = wt >= 0
		titleScale.Scale = slamScale(wt, 0.1, 3.4)
		titleBox.Position = P(TITLE_X, bandY - 2)
		specksPose(chips, t, HIT, CX, bandY, 300, 70, 0.6)
		-- BEST!: from the camera too, after the title, onto its end
		if isBest then
			local nb = t - 0.5
			bestBox.Visible = nb >= 0
			bestScale.Scale = if nb < 0.08
				then lerp(2.4, 0.85, quadIn(math.max(nb, 0) / 0.08))
				else 0.85 + 0.15 * settle(nb - 0.08)
			bestBox.Rotation = 14
			bestBox.Position = P(BEST_AT.X, BEST_AT.Y + bandY - BY)
		end

		-- the number and its words: pop up once the title is down, then the number counts each fish as it lands
		local shown, last, lastI = 0, -1, 0
		for i, when in lands do
			if t >= when then
				shown, last, lastI = totals[i], when, i
			end
		end
		local cs = t - 0.58
		countBox.Visible = cs >= 0
		countScale.Scale = if cs < 0.08
			then lerp(1.8, 0.85, quadIn(math.max(cs, 0) / 0.08))
			else 0.85 + 0.15 * settle(cs - 0.08)
		fadeAll(caught.root, quadOut(at(t, 0.58, 0.12)))
		number.set(tostring(shown))
		shine.Text = number.main.Text
		local kick = bump(t, last, 0.32)
		numScale.Scale = 1 + 0.35 * kick
		number.root.Rotation = -8 * kick
		-- its colour: gold, or the rarity of the fish that just landed
		if v.Count == "rarity" then
			number.paint(if lastI > 0 then tierPal(items[lastI].Tier) else Kit.GoldPal, true)
		end
		-- the shimmer: a strip runs across on every count and again every 1.6 s once it is all in
		local sweep = -1
		if v.Count == "shimmer" or v.Count == "both" or v.Count == "rarity" then
			if last >= 0 and t - last < 0.45 then
				sweep = at(t, last, 0.45)
			elseif t > settled then
				local cycle = (t - settled) % 1.6
				sweep = if cycle < 0.5 then cycle / 0.5 else -1
			end
		end
		shine.Visible = sweep >= 0
		shineFill.Offset = Vector2.new(lerp(-1, 1, math.max(sweep, 0)), 0)
		-- the burst: rays, a ring and chips from the number on every count (gold, or white on a Legendary or rarer)
		if burstCount and last >= 0 then
			local x = at(t, last, 0.45)
			local live = x < 1
			rayBox.Visible = live
			countRing.Visible = live
			if live then
				local loud = BIG[items[lastI].Tier] == true
				rayBox.Rotation = t * 40
				rayBox.Size =
					P(lerp(90, if loud then 300 else 220, quadOut(x)), lerp(90, if loud then 300 else 220, quadOut(x)))
				for _, bar in rayBars do
					bar.BackgroundTransparency = quadIn(x)
					bar.BackgroundColor3 = if loud then Kit.White else Kit.Sun
				end
				local r = lerp(40, 170, quadOut(x))
				countRing.Size = P(r, r)
				countRingLine.Transparency = quadIn(x)
			end
			for i, list in countChips do
				specksPose(list, t, lands[i], burstAt.X, burstAt.Y, 120, 40, 1)
			end
		else
			rayBox.Visible = false
			countRing.Visible = false
		end

		-- the fish plop down
		local shake = bump(t, HIT, 0.45)
		for i, tl in tiles do
			local s = t - starts[i]
			local spot = spots[i]
			local pos = spot
			local scale = 1
			-- (never turned: a turned frame does not clip, so the fish would show past its border; Yua, x3)
			tl.frame.Visible = s >= 0
			if v.Plop == "slam" then
				-- caught text 5's slam, small: from the camera, down onto its spot, rings back
				scale = slamScale(s, FALL, 2.8)
			elseif v.Plop == "bounce" then
				-- drops from above the row and bounces on it
				if s < FALL then
					pos = Vector2.new(spot.X, lerp(spot.Y - 150, spot.Y, quadIn(math.max(s, 0) / FALL)))
				else
					pos = Vector2.new(spot.X, spot.Y - 34 * hop(s - FALL))
					scale = 1 + 0.12 * bump(t, lands[i], 0.14)
				end
			elseif v.Plop == "pop" then
				-- out of nothing, overshoots and rings back
				scale = settle(s * 0.9) * (1 + 0.1 * bump(t, lands[i], 0.2))
			elseif v.Plop == "stamp" then
				-- hovers big over its spot, lifts, stamps down
				local HOVER = FALL * 0.55
				if s < HOVER then
					scale = 1.7 + 0.1 * quadOut(at(s, 0, HOVER))
					pos = Vector2.new(spot.X, spot.Y - 18)
				elseif s < FALL then
					local k = quadIn(at(s, HOVER, FALL - HOVER))
					scale = lerp(1.8, 0.86, k)
					pos = Vector2.new(spot.X, lerp(spot.Y - 18, spot.Y, k))
				else
					scale = 0.86 + 0.14 * settle(s - FALL)
				end
			end
			tl.frame.Position = P(pos.X, pos.Y)
			tl.scale.Scale = math.max(scale, 0)
			flashes[i].BackgroundTransparency = 1 - 0.85 * bump(t, lands[i], 0.22)
			-- the ring bursting out of it as it lands (gold on a Legendary or rarer)
			local x = at(t, lands[i], 0.45)
			local live = t >= lands[i] and x < 1
			tl.ring.Visible = live
			if live then
				local r = 1 + quadOut(x) * (if BIG[items[i].Tier] then 1.2 else 0.6)
				tl.ring.Size = UDim2.fromScale(r, r)
				local line = tl.ring:FindFirstChildOfClass("UIStroke")
				if line then
					line.Transparency = quadIn(x)
				end
			end
			specksPose(
				dusts[i],
				t,
				lands[i],
				spot.X,
				spot.Y + (if v.Plop == "slam" or v.Plop == "pop" then 0 else TILE / 2),
				60,
				30,
				0.7
			)
			shake = math.max(shake, 0.35 * bump(t, lands[i], 0.2) * (if BIG[items[i].Tier] then 1.8 else 1))
		end
		body.Position = P(math.sin(t * 83) * 10 * shake, math.cos(t * 71) * 7 * shake)

		-- the metres pop up and count
		local mp = at(t, metresAtT, 0.3)
		ovalBox.Visible = t >= metresAtT
		ovalScale.Scale = backOut(mp) + 0.08 * bump(t, metresAtT + 0.7, 0.25)
		ovalBox.Position = P(CX, OVAL_Y + 14 * (1 - quadOut(mp)))
		metresWord.set(math.floor(math.floor(metres) * quadOut(at(t, metresAtT, 0.7)) + 0.5) .. " METERS DEEP")
		ovalBox.Size = P(ovalWide, 44)
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

return DiveScreen
