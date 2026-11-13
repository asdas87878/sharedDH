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
-- Two things the HUD had and the reference doesn't are switched off below, one line each to bring back: the seconds
-- written on the ring, and the fish's name and rarity under it.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

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
local EDGE = 0.012 -- the thin red line at the edge of what is left, as a share of the ring
local LAG_RATE = 0.8 -- how fast the red follows what is left down: rings a second
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
	Fraction: number, -- how full the meter is
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
	Kind: string, -- the passive archetypes of the fish under us, as rich text ("" for none): a third line under the ring
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
local turnedAt = 0
local nextTurn = 0
local nextText = 0
local lagAt = 1
local shownX = -1
local shownY = -1
local shownFraction = -1
local shownSpent = false
local shownTone = 0
local shownSize = 1
local shownTame = -2
local shownReady = -1
local shownSeconds = ""
local shownTitle = ""
local shownSub = ""
local shownKind = ""
local kindText: TextLabel
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
	-- (Hugo, 2026-11-13: a little less detail. Both rings: one hairline round the outside and the hole, no pale line)
	big = Kit.ring(holder, BIG, BIG_THICK, true, Kit.Outline.Hair, true)
	-- the ring's glow beats red while the air is nearly gone (Hugo's pass)
	beat = Kit.pulse(big.Glow, { Transparency = 1 }, { Transparency = 0.1 })
	big.Frame.AnchorPoint = Vector2.new(0.5, 0.5)
	bigScale = Kit.new("UIScale", {}, big.Frame) -- (no text is in the ring's frame: text never changes size)
	small = Kit.ring(holder, SMALL, SMALL_THICK, true, Kit.Outline.Hair, true)
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
	-- the passive archetypes of the fish under us, each in its colour (docs/design/archetypes.md)
	kindText = Kit.text({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromOffset(0, BIG / 2 + 5),
		Size = UDim2.fromOffset(220, 12),
		TextSize = 10,
		RichText = true,
	}, holder)
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
	lagAt = 0
end

function Rings.update(now: number, v: View)
	if not shown or leftAt then
		shown = true
		leftAt = nil
		holder.Visible = true
		outer.Frame.Visible = true
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

	-- the ring turns thirty times a second: with seconds on a fish it would otherwise turn every frame
	local spent = v.Fraction <= 0 and not v.Endless
	if now >= nextTurn or v.Fraction > shownFraction + 0.05 then
		local step = math.min(now - turnedAt, 0.1)
		turnedAt = now
		nextTurn = now + 1 / 30
		shownFraction = v.Fraction
		big.set(v.Fraction)
		-- the part just lost, in red: it follows what is left down, and is never thinner than a line while it drains
		if v.Endless or v.Fraction >= lagAt then
			lagAt = v.Fraction
		else
			lagAt = math.max(v.Fraction, lagAt - LAG_RATE * step)
		end
		big.lag(if spent or v.Endless or v.Fraction >= 1 then 0 else math.min(math.max(lagAt, v.Fraction + EDGE), 1))
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
			big.colour(Kit.White:Lerp(colour, since / FLASH))
			local short = 1 - math.min(since / POP, 1)
			size = 1 - 0.18 * short * short
		end
	end
	if not flashing and tone ~= shownTone then
		shownTone = tone
		big.colour(colour)
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
		kindText.Text = kindLine
	end
	if title ~= shownTitle then
		-- (the line sits right under the ring when no words are above it, and under them when there are)
		kindText.Position = UDim2.fromOffset(0, BIG / 2 + (if title == "" then 5 else 31))
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
