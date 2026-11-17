--!strict
-- The two rings beside the rider, as the reference's (measured off its frames, 2026-11-12):
--   the big one is the time left on this fish: a thick flat ring with a small clear hole. The part left runs clockwise
--   from the top; the used part is dark and see-through; the part just lost shows red for a moment behind what is left,
--   so a steady drain has a thin red line at its edge and a sudden loss a red wedge;
--   the small one, to its left, is the tame: dark, filling pink, and it stays pink when full;
--   a thin arc outside the big ring, from the top to the upper right, fills as the hop comes ready after a landing;
--   on a landing the big ring comes in white and a little small, and is its colour again in a fifth of a second;
--   on a hop it goes pale, shrinks and is gone;
--   the rings follow the rider on the screen (the reference's are fixed to the animal).
-- Ours: the ring is our Oxygen's aqua, and red in the last second. On a fish too strong for you the ring is red from
-- the landing, bigger, and shakes while the whole meter empties in a quarter of a second, with "Too strong!" and what
-- the fish needs under it. Words under the ring only for a state the ring can't show: floating, out of air, too strong.
-- In ticks (Hugo, 2026-11-18, task h1): the meter steps down every Config.Oxygen.Tick; each piece lost shows red, holds
-- a moment and fades out (Kit.RingLook). A short red mark across the band is the red zone's line (Config.angryAt).
-- Past Config.Oxygen.BarSize of max Oxygen, each further bar's worth is a thin ring hugging the big one, the outermost
-- draining first; the hop's arc moves out past them.
-- Two things the HUD had and the reference doesn't are switched off below, one line each to bring back: the seconds
-- written on the ring, and the fish's name and rarity under it.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Archetypes = require(ReplicatedStorage.Shared.Archetypes)
local Config = require(ReplicatedStorage.Shared.Config)
local Kit = require(script.Parent.Kit)

local Rings = {}

local SECONDS_ON_RING = false -- the seconds written over the big ring (the reference has no number)
local NAME_UNDER_RING = false -- the ridden fish's name and rarity under the ring (the reference has neither)

-- Sizes as a share of the screen's height on a desktop, off the reference's frame: 8.6% and 4.6%. The band is a third
-- of the ring across, the hole a third.
local BIG = 50
local BIG_THICK = 16
local SMALL = 28
local SMALL_THICK = 9
local OUTER = BIG + 13 -- the hop's arc
local OUTER_SHARE = 75 / 360 -- how much of the circle it covers when the hop is ready
local LOOK = Kit.RingLook
local FLASH = 0.22 -- a landing: white to its colour
local POP = 0.16 -- and a little small to full size
local LEAVE = 0.14 -- a hop: pale, shrinking, gone
local STRAIN_SIZE = 1.18

local PALE = Color3.fromRGB(255, 176, 196)
local WARN_TOP = Color3.fromRGB(255, 196, 196)
local READY = Color3.fromRGB(10, 28, 52)

-- What the HUD tells the rings each frame. One table, filled again each frame (none is made)
export type View = {
	Follow: boolean, -- X and Y are the rider on the screen, in the HUD's own units; false: the fixed place
	X: number,
	Y: number,
	Wide: number, -- the HUD's size in its own units
	High: number,
	Fraction: number, -- how full the meter is (unused by the rings since h1: Amount and Max)
	Amount: number, -- the meter, in Oxygen
	Max: number, -- the most it holds
	RedAt: number, -- the red zone's line, in Oxygen (0: no mark)
	Seconds: number, -- how long it lasts on this fish
	Name: string, -- the fish under us and its rarity ("" for none)
	Tier: string,
	Note: string, -- words for a state the ring can't show ("" for none), and a second line
	NoteSub: string,
	Warn: boolean, -- those words are a warning (red)
	Tame: number?, -- 0 to 1, or nil when there is no tame to show
	Ready: number, -- 0 to 1: how far the hop is from being ready again after a landing
	Strained: boolean, -- the fish under us is too strong: the meter is emptying at once
	Low: boolean, -- the meter is in its low part (Config.low, Oxygen.AngryAt): red, and the fish under us is angry
	Kind: string, -- the passive archetypes of the fish under us (Archetypes.line, "" for none): icons under the ring
	Endless: boolean, -- the Studio sandbox's endless air: the meter doesn't drain
}

local holder: Frame
local big: Kit.Ring
local bigScale: UIScale
local small: Kit.Ring
local outer: Kit.Sweep
local number: TextLabel? = nil
local nameText: TextLabel
local tierText: TextLabel
local tierGradient: UIGradient
local beat: (on: boolean) -> ()

local touchLayout = false
local shown = false
local leftAt: number? = nil -- os.clock() the ring began to leave
local landedAt = -math.huge
local flashing = false
local nextText = 0
local shownX = -1
local shownY = -1
local shownAmount = -1
local shownMax = -1

-- The piece of the meter just lost (Rings.lose): from, to, and when
local chunkOn = false
local chunkFrom = 0
local chunkTo = 0
local chunkAt = -math.huge
local chunkFaded = -1

-- The thin rings past Config.Oxygen.BarSize (made when first needed, kept)
type Extra = { Frame: Frame, Track: Kit.Sweep, Lag: Kit.Sweep, Front: Kit.Sweep, Diameter: number }
local extras: { Extra } = {}
local extraCount = 0
local outerScale: UIScale
local markPivot: Frame
local markLine: Frame
local markOn = -1 -- which bar carries the red zone's mark (0: the big ring; -1: none)
local markTurn = -1
local shownSpent = false
local shownTone = 0
local shownSize = 1
local shownTame = -2
local shownReady = -1
local shownSeconds = ""
local shownTitle = ""
local shownSub = ""
local shownKind = ""
local kindRow: Frame
local KIND_ICON = 24 -- the archetype icons under the ring (they replaced the words, Hugo, 2026-11-13)
local shownWarn = false

function Rings.build(parent: Instance)
	-- a point: the middle of the big ring. Everything hangs off it
	holder = Kit.new("Frame", {
		Name = "Rings",
		Size = UDim2.fromOffset(0, 0),
		BackgroundTransparency = 1,
		Visible = false,
	}, parent)
	outer = Kit.sweep(holder, OUTER, 2.6, READY)
	outer.Frame.AnchorPoint = Vector2.new(0.5, 0.5)
	outer.set(0)
	outerScale = Kit.new("UIScale", {}, outer.Frame)
	-- (Hugo, 2026-11-13: a little less detail. Both rings: one hairline round the outside and the hole, no pale line)
	big = Kit.ring(holder, BIG, BIG_THICK, true, LOOK.Outline, true)
	-- the ring's glow beats red while the air is nearly gone (Hugo's pass)
	beat = Kit.pulse(big.Glow, { Transparency = 1 }, { Transparency = 0.1 })
	big.Frame.AnchorPoint = Vector2.new(0.5, 0.5)
	bigScale = Kit.new("UIScale", {}, big.Frame) -- (no text is in the ring's frame: text never changes size)
	small = Kit.ring(holder, SMALL, SMALL_THICK, true, LOOK.Outline, true)
	small.Frame.AnchorPoint = Vector2.new(0.5, 0.5)
	small.colour(Kit.Pink)
	small.Frame.Visible = false
	-- the red zone's line: a frame the size of its ring, turned, with the mark at its top
	markPivot = Kit.new("Frame", {
		Name = "RedZone",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		BackgroundTransparency = 1,
		ZIndex = 3,
		Visible = false,
	}, big.Frame)
	markLine = Kit.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundColor3 = Kit.Coral,
		BorderSizePixel = 0,
		ZIndex = 3,
	}, markPivot)
	Kit.stroke(markLine, LOOK.Outline, Kit.Ink)
	if SECONDS_ON_RING then
		number = Kit.text({
			AnchorPoint = Vector2.new(0.5, 0.5),
			Size = UDim2.fromOffset(BIG + 20, 22),
			TextSize = 17,
		}, holder)
	end
	nameText = Kit.text({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromOffset(0, BIG / 2 + 5),
		Size = UDim2.fromOffset(170, 15),
		TextSize = 12.5,
	}, holder)
	tierText = Kit.text({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromOffset(0, BIG / 2 + 18),
		Size = UDim2.fromOffset(170, 13),
		TextSize = 10.5,
	}, holder)
	tierGradient = Kit.gradient(tierText, Kit.White, Kit.White)
	-- the passive archetypes of the fish under us, an icon each, side by side (docs/design/archetypes.md)
	kindRow = Kit.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromOffset(0, BIG / 2 + 5),
		Size = UDim2.fromOffset(220, KIND_ICON),
		BackgroundTransparency = 1,
	}, holder)
	Kit.new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 4),
	}, kindRow)
end

local function extraDiameter(k: number): number
	return BIG + 2 * k * (LOOK.ExtraThick + LOOK.ExtraGap)
end

local function makeExtra(k: number): Extra
	local d = extraDiameter(k)
	local frame: Frame = Kit.new("Frame", {
		Name = "Extra" .. k,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(d, d),
		BackgroundTransparency = 1,
	}, holder)
	local track = Kit.sweep(frame, d, LOOK.ExtraThick, Kit.Deep)
	track.fade(0.5)
	local lag = Kit.sweep(frame, d, LOOK.ExtraThick, Kit.Coral)
	lag.set(0)
	local front = Kit.sweep(frame, d, LOOK.ExtraThick, Kit.Aqua)
	return { Frame = frame, Track = track, Lag = lag, Front = front, Diameter = d }
end

-- How much one bar holds: the whole meter under BarSize, else BarSize (more past ExtraMost rings)
local function barOf(max: number): number
	local size = math.max(Config.Oxygen.BarSize or 0, 0)
	if size <= 0 or max <= size then
		return math.max(max, 0.001)
	end
	return math.max(size, max / (LOOK.ExtraMost + 1))
end

-- How full bar k (0: the big ring) is with `amount` in it
local function fill(amount: number, bar: number, k: number): number
	return math.clamp((amount - k * bar) / bar, 0, 1)
end

local function paint(colour: Color3)
	big.colour(colour)
	for i = 1, extraCount do
		extras[i].Front.colour(colour)
	end
end

-- The tame ring sits to the left of the big one, level with it: closer on a phone, where the rider is small
function Rings.place(touch: boolean)
	touchLayout = touch
	local gap = if touch then 12 else 21
	small.Frame.Position = UDim2.fromOffset(-(BIG / 2 + gap + SMALL / 2), 1)
	shownX = -1
end

-- Hidden, or on its way out: a hop takes the ring away pale and shrinking, as the reference's
function Rings.hide(now: number)
	if not shown then
		return
	end
	local began: number = leftAt or now
	if not leftAt then
		leftAt = now
		big.colour(PALE)
		big.lag(0)
		beat(false)
		shownTone = 0
		small.Frame.Visible = false
		shownTame = -2
		outer.Frame.Visible = false
		for _, extra in extras do
			extra.Frame.Visible = false
		end
		markPivot.Visible = false
		markOn = -1
		chunkOn = false
		chunkFaded = -1
		nameText.Visible = false
		tierText.Visible = false
		if number then
			number.Visible = false
		end
	end
	local t = (now - began) / LEAVE
	if t >= 1 then
		shown = false
		leftAt = nil
		holder.Visible = false
		bigScale.Scale = 1
		shownSize = 1
	else
		bigScale.Scale = 1 - 0.75 * t
	end
end

-- A landing on a fish: the ring comes in white and a little small (a fish too strong: red at once, no white)
function Rings.landed(now: number)
	landedAt = now
	flashing = true
end

-- The meter dropped from `from` to `to` (a tick, the red zone's drop, a crash): that piece shows red, then fades.
-- The same drop heard twice (the Oxygen attribute and the server's "OxygenTick") is one piece, not restarted.
function Rings.lose(now: number, from: number, to: number)
	if from <= to then
		return
	end
	if chunkOn and now - chunkAt < 0.15 and math.abs(chunkTo - to) < 0.01 then
		chunkFrom = math.max(chunkFrom, from)
		return
	end
	chunkOn = true
	chunkFrom = from
	chunkTo = to
	chunkAt = now
	chunkFaded = -1
end

function Rings.update(now: number, v: View)
	if not shown or leftAt then
		shown = true
		leftAt = nil
		holder.Visible = true
		outer.Frame.Visible = true
		shownMax = -1 -- (the extra rings come back with the next count)
		nameText.Visible = true
		tierText.Visible = true
		if number then
			number.Visible = true
		end
		bigScale.Scale = 1
		shownSize = 1
		shownTone = 0
	end

	-- where: beside the rider, to the right at shoulder height, kept on the screen
	local x, y
	if v.Follow then
		local reach = math.max(0.27 * v.High, BIG / 2 + SMALL + (if touchLayout then 56 else 70))
		x = math.clamp(v.X + reach, BIG + SMALL + 30, v.Wide - BIG)
		y = math.clamp(v.Y - 0.04 * v.High, BIG, v.High - BIG - 30)
	else
		x = v.Wide / 2 + (if touchLayout then 112 else 150)
		y = v.High / 2 - 20
	end
	if v.Strained then
		x += math.sin(now * 95) * 2.5
		y += math.cos(now * 71) * 2
	end
	if math.abs(x - shownX) > 0.2 or math.abs(y - shownY) > 0.2 then
		shownX = x
		shownY = y
		holder.Position = UDim2.fromOffset(x, y)
	end

	-- the bars: the big ring holds the first BarSize, each thin ring round it the next; the outermost drains first
	local spent = v.Amount <= 0 and not v.Endless
	local max = math.max(v.Max, 0.001)
	local bar = barOf(max)
	if max ~= shownMax then
		shownMax = max
		shownAmount = -1
		markOn = -1
		local count = math.max(math.ceil(max / bar - 1e-6) - 1, 0)
		for k = #extras + 1, count do
			extras[k] = makeExtra(k)
		end
		for k, extra in extras do
			extra.Frame.Visible = k <= count
			if k <= count then
				extra.Track.set(fill(max, bar, k))
			end
		end
		extraCount = count
		outerScale.Scale = (OUTER + extraDiameter(count) - BIG) / OUTER
		shownTone = 0 -- (paint the new rings)
	end
	if v.Amount ~= shownAmount then
		shownAmount = v.Amount
		big.set(fill(v.Amount, bar, 0))
		for k = 1, extraCount do
			extras[k].Front.set(fill(v.Amount, bar, k))
		end
	end
	-- the piece just lost: red, held, then fading out (a landing's refill takes it away)
	if chunkOn and (v.Endless or spent or v.Amount > chunkTo + 0.01) then
		chunkOn = false
	end
	local faded = 1
	if chunkOn then
		local since = now - chunkAt
		if since >= LOOK.TickHold + LOOK.TickFade then
			chunkOn = false
		else
			faded = math.clamp((since - LOOK.TickHold) / math.max(LOOK.TickFade, 0.001), 0, 1)
		end
	end
	local faded20 = math.floor(faded * 20 + 0.5)
	if faded20 ~= chunkFaded then
		chunkFaded = faded20
		local from = if faded20 >= 20 then 0 else chunkFrom
		big.lag(if faded20 >= 20 then 0 else fill(from, bar, 0))
		big.lagFade(faded20 / 20)
		for k = 1, extraCount do
			local extra = extras[k]
			extra.Lag.set(if faded20 >= 20 then 0 else fill(from, bar, k))
			extra.Lag.fade(faded20 / 20)
		end
	end
	-- the red zone's line, on whichever bar it falls
	local markBar, markAt = -1, 0
	if v.RedAt > 0 and not v.Endless then
		markBar = math.min(math.floor(v.RedAt / bar), extraCount)
		markAt = fill(v.RedAt, bar, markBar)
		if markAt <= 0 or markAt >= 1 then
			markBar = -1
		end
	end
	local turn = math.floor(markAt * 720 + 0.5)
	if markBar ~= markOn or turn ~= markTurn then
		markOn = markBar
		markTurn = turn
		markPivot.Visible = markBar >= 0
		if markBar >= 0 then
			local d = if markBar == 0 then BIG else extras[markBar].Diameter
			local band = if markBar == 0 then BIG_THICK else LOOK.ExtraThick
			markPivot.Parent = if markBar == 0 then big.Frame else extras[markBar].Frame
			markPivot.Size = UDim2.fromOffset(d, d)
			markPivot.Rotation = turn / 2
			markLine.Size = UDim2.fromOffset(LOOK.Mark, band + 2 * LOOK.MarkOver)
			markLine.Position = UDim2.new(0.5, 0, 0, -LOOK.MarkOver)
		end
	end
	-- an empty meter: the whole ring red (with nothing left there is no arc to be red)
	if spent ~= shownSpent then
		shownSpent = spent
		big.spent(spent)
	end

	-- its colour: aqua, red in its low part (where the fish turns angry: Oxygen.AngryAt) and on a fish too strong;
	-- white for a moment on a landing
	local tone = if v.Endless then 1 elseif v.Strained or v.Low then 3 else 1
	local colour = if tone == 3 then Kit.Coral else Kit.Aqua
	local size = if v.Strained then STRAIN_SIZE else 1
	if flashing then
		local since = now - landedAt
		if since >= FLASH or v.Strained then
			flashing = false
			shownTone = 0
		else
			paint(Kit.White:Lerp(colour, since / FLASH))
			local short = 1 - math.min(since / POP, 1)
			size = 1 - 0.18 * short * short
		end
	end
	if not flashing and tone ~= shownTone then
		shownTone = tone
		paint(colour)
		beat(tone == 3)
	end
	if size ~= shownSize then
		shownSize = size
		bigScale.Scale = size
	end

	-- the hop's arc: pale while it fills after a landing, then dark
	local ready = math.floor(math.clamp(v.Ready, 0, 1) * 40 + 0.5)
	if ready ~= shownReady then
		local was = shownReady
		shownReady = ready
		outer.set(OUTER_SHARE * (0.35 + 0.65 * ready / 40))
		if (ready >= 40) ~= (was >= 40) or was < 0 then
			outer.colour(if ready >= 40 then READY else Kit.White)
			outer.fade(if ready >= 40 then 0.4 else 0.1)
		end
	end

	-- the tame: pink, and pink when full. A fish too strong is never tamed, so it has no tame to show
	local tame = if v.Strained then nil else v.Tame
	local tameSteps = if tame then math.floor(math.clamp(tame, 0, 1) * 200 + 0.5) else -1
	if tameSteps ~= shownTame then
		shownTame = tameSteps
		small.Frame.Visible = tame ~= nil
		if tame then
			small.set(tame)
		end
	end

	local label = number
	if label and now >= nextText then
		nextText = now + 1 / 15
		local text = if v.Endless then "" else Kit.seconds(v.Seconds)
		if text ~= shownSeconds then
			shownSeconds = text
			label.Text = text
		end
	end

	-- the words under the ring
	local title, sub = v.Note, v.NoteSub
	if title == "" and NAME_UNDER_RING then
		title, sub = v.Name, v.Tier
	end
	if title == "" and v.Endless then
		title = "Endless air"
	end
	local warn = v.Warn and v.Note ~= ""
	local kindLine = if v.Note == "" then v.Kind else "" -- (a note has the room: "Too strong!", "Floating")
	if kindLine ~= shownKind then
		shownKind = kindLine
		Archetypes.icons(kindRow, kindLine, KIND_ICON)
	end
	if title ~= shownTitle then
		-- (the line sits right under the ring when no words are above it, and under them when there are)
		kindRow.Position = UDim2.fromOffset(0, BIG / 2 + (if title == "" then 5 else 31))
		shownTitle = title
		nameText.Text = title
	end
	if sub ~= shownSub or warn ~= shownWarn then
		shownSub = sub
		tierText.Text = sub
		if Config.Tiers[sub] then
			Kit.tierColours(tierText, tierGradient, sub, Config.Tiers)
		else
			tierGradient.Color = if warn then ColorSequence.new(WARN_TOP, Kit.Coral) else ColorSequence.new(Kit.White)
		end
	end
	if warn ~= shownWarn then
		shownWarn = warn
		nameText.TextColor3 = if warn then Color3.fromRGB(255, 120, 124) else Kit.White
	end
end

return Rings
