--!strict
-- The two rings beside the rider, as the reference's (measured off its frames, 2026-11-12):
--   the big one is the time left on this fish: a thick flat ring with a small clear hole. The part left runs clockwise
--   from the top; the used part is dark and see-through;
--   the small one, to its left, is the tame: dark, filling pink, and it stays pink when full;
--   a thin arc outside the big ring, from the top to the upper right, fills as the hop comes ready after a landing;
--   on a landing the big ring comes in white and a little small, and is its colour again in a fifth of a second;
--   on a hop it goes pale, shrinks and is gone;
--   the rings follow the rider on the screen (the reference's are fixed to the animal).
-- Ours: the ring is our Oxygen's aqua, and red in the last second. On a fish too strong for you the ring is red from
-- the landing, bigger, and shakes while the whole meter empties in a quarter of a second, with "Too strong!" and what
-- the fish needs under it. Words under the ring only for a state the ring can't show: floating, out of air, too strong.
-- In ticks (Hugo, 2026-11-18, tasks h1 and o2): the meter steps down a piece at a time, every piece 1 / Oxygen.Ticks of
-- the max (o1), so on a ring every tick is the same share of the circle (Oxygen.TickSize picks how many, task s1; a
-- fish whose ticks would come faster than Oxygen.Tick takes bigger ones), and the red part ends in Oxygen.RedTicks
-- even ones (RedTime, task o1 of 2026-11-19). The piece just lost
-- stays WHITE behind what is left; when the next tick starts it breaks off (fades out, Kit.RingLook) and the new piece
-- is white. The 2/3 break-off on a fish too strong comes as one tick: one big white piece, broken off by the next.
-- Since t1 (Hugo, 2026-11-18) the white piece DRAWS BACK along the ring instead of fading, as a health bar's damage
-- trail (Kit.RingLook.TickTrail picks how; 0 the fade above).
-- Past Config.Oxygen.BarSize of max Oxygen a second ring goes all round the big one, in the same look, and past twice
-- BarSize a third round that (Config.ringsOf; never more). The meter is shared evenly between the rings and they empty
-- one after the other, the outermost first, every ring ticking at the same pace; the big ring starts only once the
-- thin ones are empty (task o1, 2026-11-19: until then the big ring and one extra ring emptied together). The second
-- ring is a little thicker than the third. The hop's arc moves out past them. No mark for the red zone (o2); the ring still goes red there, and the fish turns angry.
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
	RedAt: number, -- the red zone's line, in Oxygen (unused since o2: no mark)
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

-- The piece of the meter just lost (Rings.lose), white until the next tick: from, to, and when
local heldOn = false
local heldFrom = 0
local heldTo = 0
local heldAt = -math.huge
local lastGap = 0 -- seconds between the last two ticks (0: not known yet on this fish)
-- the piece before it, breaking off: down from `brokeFrom`, since when
local brokeOn = false
local brokeFrom = 0
local brokeAt = -math.huge
local brokeShown = -1
-- The damage trail (Kit.RingLook.TickTrail 1 to 3): the white's end, drawing back from `trailStart` (in Oxygen) to
-- `trailTarget` (1) or to what is left (2, 3), after a hold; `trailPos` is where it was last drawn
local trailOn = false
local trailStart = 0
local trailTarget = 0
local trailAt = -math.huge
local trailHold = 0
local trailDur = 0.2
local trailPos = 0
local trailShown = -1
local lostAt = -math.huge -- the last drop heard, and what it left
local lostTo = 0

-- The thin rings past Config.Oxygen.BarSize (made when first needed, kept): extras[1] the second ring, [2] the third
type Extra = { Frame: Frame, Track: Kit.Sweep, Broken: Kit.Sweep, Held: Kit.Sweep, Front: Kit.Sweep }
local extras: { Extra } = {}
local rings = 1 -- how many rings this max shows (Config.ringsOf), the big one included
local share = 1 -- the Oxygen each ring holds: max / rings
local outerScale: UIScale
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

-- The thin rings' bands (task o1, 2026-11-19: "make the second (thin) ring slightly thicker"; both were
-- LOOK.ExtraThick, 4) and each one's width across, out from the big ring
local EXTRA_THICK = { LOOK.ExtraThick + 2, LOOK.ExtraThick }
local EXTRA_ACROSS = {}
do
	local across = BIG
	for i, thick in EXTRA_THICK do
		across += 2 * (thick + LOOK.ExtraGap)
		EXTRA_ACROSS[i] = across
	end
end

local function makeExtra(i: number): Extra
	local across = EXTRA_ACROSS[i]
	local frame: Frame = Kit.new("Frame", {
		Name = "Extra" .. i,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(across, across),
		BackgroundTransparency = 1,
	}, holder)
	local thin = Kit.thinRing(frame, across, EXTRA_THICK[i]) -- (in the chosen look, Kit.RingStyle)
	thin.Track.set(1) -- (all round, whatever the max)
	return { Frame = frame, Track = thin.Track, Broken = thin.Broken, Held = thin.Held, Front = thin.Front }
end

-- How full ring `k` (0 the big one, 1 the second, 2 the third) is with `amount` in the meter: each holds `share`, the
-- big one the bottom of the meter, the outermost the top (so it empties first)
local function fillOf(k: number, amount: number): number
	return math.clamp((amount - k * share) / share, 0, 1)
end

local function bigFill(amount: number, _max: number): number
	return fillOf(0, amount)
end

local function paint(colour: Color3)
	big.colour(colour)
	for i, ring in extras do
		if i < rings then
			ring.Front.colour(colour)
		end
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
		big.held(0)
		big.broken(0, 1)
		beat(false)
		shownTone = 0
		small.Frame.Visible = false
		shownTame = -2
		outer.Frame.Visible = false
		for _, ring in extras do
			ring.Frame.Visible = false
		end
		heldOn = false
		brokeOn = false
		brokeShown = -1
		trailOn = false
		trailShown = -1
		lastGap = 0
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

-- The trail draws back from `from` (or from where it is, if further out: it never jumps) to `target`, after `hold`.
-- One tick's piece takes TrailDraw (at most TrailShare of the gap between ticks); a bigger one longer, as the square
-- root of its size in ticks, up to TrailDrawMost: the 2/3 break-off draws back slowly.
local function startTrail(now: number, from: number, target: number, hold: number)
	local start = if trailOn then math.max(trailPos, from) else from
	local max = if shownMax > 0 then shownMax else math.max(from, 0.001)
	local tick = max / math.max(Config.Oxygen.Ticks or 10, 1)
	local base = if lastGap > 0 then math.min(LOOK.TrailDraw, LOOK.TrailShare * lastGap) else LOOK.TrailDraw
	local pieces = math.max((start - target) / tick, 1)
	trailOn = true
	trailStart = start
	trailTarget = target
	trailPos = start
	trailAt = now
	trailHold = hold
	trailDur = math.clamp(base * math.sqrt(pieces), 0.05, math.max(LOOK.TrailDrawMost, base))
end

-- Where the trail's end is now, and how far through its draw-in (0 to 1)
local function trailNow(now: number, amount: number): (number, number)
	local t = math.clamp((now - trailAt - trailHold) / trailDur, 0, 1)
	if LOOK.TickTrail == 1 then
		return trailStart + (trailTarget - trailStart) * t, t
	end
	local e = 1 - (1 - t) * (1 - t) * (1 - t) -- (quick, then slowing into what is left)
	local target = math.min(amount, trailStart)
	return trailStart + (target - trailStart) * e, t
end

-- The meter dropped from `from` to `to` (a tick, the 2/3 break-off, a crash): that piece stays white, and the one
-- before it, if still there, breaks off now. The same drop heard twice (the Oxygen attribute and the server's
-- "OxygenTick") is one piece, not a new tick.
function Rings.lose(now: number, from: number, to: number)
	if from <= to then
		return
	end
	local mode = LOOK.TickTrail or 0
	if mode >= 2 then
		-- 2, 3: no piece waits for the next tick; each drop holds a moment and draws back to what is left
		if trailOn and now - lostAt < 0.15 and math.abs(lostTo - to) < 0.01 then
			if from > trailStart and now < trailAt + trailHold then
				trailStart = from
				trailPos = from
			end
			return
		end
		local gap = now - lostAt
		lastGap = if gap < LOOK.TickWait then gap else 0
		-- (a tick while the trail is still running takes it on at once, no second hold: it keeps moving)
		local moving = trailOn and now > trailAt + trailHold
		startTrail(now, from, to, if moving then 0 else LOOK.TrailHold)
		lostAt = now
		lostTo = to
		return
	end
	if heldOn and now - heldAt < 0.15 and math.abs(heldTo - to) < 0.01 then
		heldFrom = math.max(heldFrom, from)
		return
	end
	lostAt = now
	lostTo = to
	if heldOn then
		lastGap = now - heldAt
		if mode == 1 then
			-- the old piece draws straight back to the new white one
			startTrail(now, heldFrom, from, 0)
		else
			brokeOn = true
			brokeFrom = heldFrom
			brokeAt = now
			brokeShown = -1
		end
	end
	heldOn = true
	heldFrom = from
	heldTo = to
	heldAt = now
end

function Rings.update(now: number, v: View)
	if not shown or leftAt then
		shown = true
		leftAt = nil
		holder.Visible = true
		outer.Frame.Visible = true
		shownMax = -1 -- (the extra ring comes back with the next max)
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

	-- the bars: the meter shared evenly between the big ring and the thin ones round it (Config.ringsOf), the
	-- outermost emptying first
	local spent = v.Amount <= 0 and not v.Endless
	local max = math.max(v.Max, 0.001)
	if max ~= shownMax then
		shownMax = max
		shownAmount = -1
		trailShown = -1
		rings = math.clamp(Config.ringsOf(max), 1, #EXTRA_THICK + 1)
		share = max / rings
		for i = 1, rings - 1 do
			if not extras[i] then
				extras[i] = makeExtra(i)
			end
		end
		for i, ring in extras do
			ring.Frame.Visible = i < rings
		end
		local across = if rings > 1 then EXTRA_ACROSS[rings - 1] else BIG
		outerScale.Scale = (OUTER + across - BIG) / OUTER
		shownTone = 0 -- (paint the new ring)
	end
	if v.Amount ~= shownAmount then
		shownAmount = v.Amount
		big.set(bigFill(v.Amount, max))
		for i = 1, rings - 1 do
			extras[i].Front.set(fillOf(i, v.Amount))
		end
	end
	-- the piece just lost: white until the next tick (Rings.lose), or until one is long overdue (the meter emptied,
	-- the drain stopped); a landing's refill takes it away
	if heldOn and (v.Endless or v.Amount > heldTo + 0.01) then
		heldOn = false
		lastGap = 0 -- (a new fish: its own gap)
	end
	if heldOn then
		local due = if spent
			then (if lastGap > 0 then lastGap else Config.Oxygen.Tick)
			else math.max(lastGap * 1.5, LOOK.TickWait)
		if now - heldAt >= due then
			if LOOK.TickTrail == 1 then
				startTrail(now, heldFrom, heldTo, 0)
			else
				brokeOn = true
				brokeFrom = heldFrom
				brokeAt = now
				brokeShown = -1
			end
			heldOn = false
		end
	end
	local heldUpTo = if heldOn then heldFrom else 0
	big.held(bigFill(heldUpTo, max))
	for i = 1, rings - 1 do
		extras[i].Held.set(fillOf(i, heldUpTo))
	end
	-- the damage trail (TickTrail 1 to 3): the white's end drawing back; a refill (a landing) takes it away
	if trailOn and (v.Endless or v.Amount > lostTo + 0.01) then
		trailOn = false
	end
	if (LOOK.TickTrail or 0) ~= 0 then
		local upTo, melt = 0, 0
		if trailOn then
			local pos, t = trailNow(now, v.Amount)
			trailPos = pos
			if t >= 1 then
				trailOn = false
			else
				upTo = pos
				melt = if LOOK.TickTrail == 3 then LOOK.TrailMelt * t else 0
			end
		end
		-- (only when it shows a change: the sweep's half-degree steps, the melt in twentieths)
		-- (one ring at a time is drawing back but for a piece across a join: the key is where it is, all rings)
		local key = math.floor(upTo / max * 720 * rings + 0.5) * 32 + math.floor(melt * 20 + 0.5)
		if key ~= trailShown then
			trailShown = key
			big.broken(bigFill(upTo, max), melt)
			for i = 1, rings - 1 do
				extras[i].Broken.set(fillOf(i, upTo))
				extras[i].Broken.fade(melt)
			end
		end
	end
	-- the piece before it, breaking off: fading out over TickFade
	-- (shorter on quick ticks, so it is gone before the next one breaks off: Kit.RingLook.TickFadeShare)
	local faded = 20
	if (LOOK.TickTrail or 0) ~= 0 then
		brokeOn = false
		faded = brokeShown -- (the trail draws the broken sweep)
	elseif brokeOn then
		local fadeTime = if lastGap > 0 then math.min(LOOK.TickFade, LOOK.TickFadeShare * lastGap) else LOOK.TickFade
		faded = math.floor(math.clamp((now - brokeAt) / math.max(fadeTime, 0.001), 0, 1) * 20 + 0.5)
		if faded >= 20 then
			brokeOn = false
		end
	end
	if faded ~= brokeShown then
		brokeShown = faded
		local upTo = if faded >= 20 then 0 else brokeFrom
		-- (eased: it lets go quickly, then the last of it lingers a little)
		local t = faded / 20
		local fade = 1 - (1 - t) * (1 - t)
		big.broken(bigFill(upTo, max), fade)
		for i = 1, rings - 1 do
			extras[i].Broken.set(fillOf(i, upTo))
			extras[i].Broken.fade(fade)
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
