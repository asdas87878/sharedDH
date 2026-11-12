--!strict
-- How each kind of body shows it wants its rider off (Config.Angry; Hugo, 2026-11-12: "different fishes should have
-- different slowdowns"; the reference's T-rex starts jumping, its bison rocks back and forth). One angry style to a
-- body type, keyed as Shared/RideStyles keys them (RideStyles.nameOf), and one for giants of any type. Each has its
-- own SHAPE of slow-down and its own numbers; RideController multiplies the ridden speed by it, RideService names it
-- on the fish (the "AngryStyle" attribute) and holds the speed check to it. Steering is never touched.
--   Shape: what the share of its speed does over one Period (seconds), between Slow (its lowest) and Peak (its highest):
--     Drag     steady: down to Slow and held there
--     Wave     swells and sinks, smoothly, once a Period
--     Zigzag   lost at each turn-over of a wag from side to side: two dips a Period
--     Stutter  short brakes and releases: at Slow for Hold of each Period, at Peak for the rest
--     Surge    surge and stall: over Peak's top for Hold of each Period, then a long dip to Slow
--     Pulse    a jet: up to Peak at once, running down to Slow over the Period
--     Fade     slow and heavy: sinks to Slow over Period seconds and stays (it does not repeat)
--   Pitch, Yaw, Roll (degrees) and Beat (seconds a cycle): THE STAND-IN MOTION, see the marked block below.
-- First numbers, 2026-11-12, not judged in play. Averages over a cycle, before rarity and heat: between 0.70 and
-- 0.78 of the fish's speed (a giant settles at 0.6, and giants are the rarest fish), so no style is the one to avoid;
-- what differs is how it feels.
local Config = require(script.Parent.Config)
local Ease = require(script.Parent.Ease)
local RideStyles = require(script.Parent.RideStyles)

local AngryStyles = {}

export type Style = {
	Name: string, -- what the fish's "AngryStyle" attribute says
	Shape: string,
	Slow: number,
	Peak: number,
	Period: number,
	Hold: number,
	Pitch: number,
	Yaw: number,
	Roll: number,
	Beat: number,
}

local function style(
	name: string,
	shape: string,
	slow: number,
	peak: number,
	period: number,
	hold: number,
	pitch: number,
	yaw: number,
	roll: number,
	beat: number
): Style
	return {
		Name = name,
		Shape = shape,
		Slow = slow,
		Peak = peak,
		Period = period,
		Hold = hold,
		Pitch = pitch,
		Yaw = yaw,
		Roll = roll,
		Beat = beat,
	}
end

-- stylua: ignore
AngryStyles.Styles = {
	--                name       shape      Slow  Peak  Period Hold  Pitch Yaw Roll Beat
	Darter   = style("Zigzag",  "Zigzag",  0.45, 0.95, 0.9,   0,    0,    10, 8,   0.9), -- wags hard side to side, losing speed at each turn-over
	Cruiser  = style("Drag",    "Drag",    0.7,  1,    1,     0,    0,    3.5, 0,  0.35), -- a shark just digs in: steady, with a shake of the head
	Snake    = style("Coil",    "Wave",    0.45, 1,    2.2,   0,    0,    5,  14,  2.2), -- long slow swells, rolling as it coils
	Galloper = style("Buck",    "Surge",   0.42, 1.1,  1.4,   0.35, 10,   0,  0,   1.4), -- surge and stall, rocking nose up and nose down
	Glider   = style("Flutter", "Wave",    0.6,  0.88, 0.7,   0,    0,    0,  12,  0.7), -- a quick shiver of the wings
	Paddler  = style("Balk",    "Stutter", 0.35, 0.95, 1.1,   0.3,  -6,   0,  0,   1.1), -- brakes hard, lets go, brakes again, nodding
	Jetter   = style("Pulse",   "Pulse",   0.5,  1.05, 1.2,   0,    3,    0,  0,   1.2), -- a jet and a long run-down
	Bobber   = style("Wobble",  "Wave",    0.66, 0.8,  0.8,   0,    0,    6,  14,  0.8), -- always slow, wobbling like a top
	Crawler  = style("Dig",     "Stutter", 0.5,  0.9,  0.5,   0.4,  3,    0,  0,   0.5), -- a quick judder
} :: { [string]: Style }

-- A giant (Config.Angry.GiantLength), whatever its body type: nothing sudden, it just gets heavier and heavier
AngryStyles.Giant = style("Fade", "Fade", 0.6, 1, 3.5, 0, 0, 0, 4, 3)

local PULSE_RUN = 2.2 -- how quickly a Pulse runs down (higher: sooner at its Slow)
local EDGE = 0.08 -- of a Period: how long a Stutter's brake takes to come on and off (so it is never a square step)

-- The angry style of a creature
function AngryStyles.of(fish: Config.FishType): Style
	if fish.Size.Z >= Config.Angry.GiantLength then
		return AngryStyles.Giant
	end
	return AngryStyles.Styles[RideStyles.nameOf(fish.Id)] or AngryStyles.Styles.Cruiser
end

-- The share of its speed a fish keeps `t` seconds into being angry, by the style's shape alone (Slow to Peak)
function AngryStyles.share(s: Style, t: number): number
	local period = math.max(s.Period, 0.05)
	local u = (t / period) % 1
	local shape = s.Shape
	if shape == "Drag" then
		return s.Slow
	elseif shape == "Wave" then
		return s.Slow + (s.Peak - s.Slow) * (0.5 + 0.5 * math.cos(2 * math.pi * u))
	elseif shape == "Zigzag" then
		return s.Slow + (s.Peak - s.Slow) * math.abs(math.cos(2 * math.pi * u))
	elseif shape == "Stutter" then
		local brake = Ease.smoothstep(0, EDGE, u) * (1 - Ease.smoothstep(s.Hold, s.Hold + EDGE, u))
		return s.Peak + (s.Slow - s.Peak) * brake
	elseif shape == "Surge" then
		local hold = math.clamp(s.Hold, 0.05, 0.95)
		if u < hold then
			return 1 + (s.Peak - 1) * math.sin(math.pi * u / hold)
		end
		return 1 + (s.Slow - 1) * math.sin(math.pi * (u - hold) / (1 - hold))
	elseif shape == "Pulse" then
		local last = math.exp(-PULSE_RUN) -- where the run-down ends: the next jet starts from there
		local run = if u < EDGE
			then last + (1 - last) * Ease.smoothstep(0, EDGE, u)
			else math.exp(-PULSE_RUN * (u - EDGE))
		return s.Slow + (s.Peak - s.Slow) * run
	elseif shape == "Fade" then
		return 1 + (s.Slow - 1) * Ease.smoothstep(0, period, t)
	end
	return s.Slow
end

-- The same, as it is ridden: `heat` is how far through its red part the meter is (0 to 1: the slow-down grows from
-- Angry.HeatFrom of itself to whole), and a rarer fish loses more (Config.AngryTier). Never under Angry.Floor.
function AngryStyles.speed(s: Style, t: number, heat: number, tier: string): number
	local a = Config.Angry
	local loss = 1 - AngryStyles.share(s, t)
	if loss > 0 then
		loss *= (Config.AngryTier[tier] or 1) * Ease.lerp(math.clamp(a.HeatFrom, 0, 1), 1, math.clamp(heat, 0, 1))
	end
	return math.max(1 - loss, math.clamp(a.Floor, 0.05, 1))
end

-- The most of its speed a style ever gives (1, or a Surge's or a Pulse's top): the server's speed check allows this
function AngryStyles.most(s: Style): number
	return if s.Shape == "Surge" or s.Shape == "Pulse" then math.max(s.Peak, 1) else 1
end

----------------------------------------------------------------------------------------------------------------------
-- THE STAND-IN MOTION (Config.Angry.Motion; 0 switches it off). Not an animation: one sine a style, on the fish's nose
-- (Pitch), turn (Yaw) and roll (Roll), in degrees, one cycle every Beat seconds, in step with the slow-down's shape.
-- RideController adds it to the fish's turn spring, so the whole fish and its rider rock and every player sees it.
-- It is here only so each style reads before there are animations. To replace it: set Angry.Motion to 0 and play an
-- animation by the fish's "AngryStyle" attribute (set while its "Angry" attribute is true), in AnimController, the
-- way a landing's reaction is played. Nothing else reads this block.
function AngryStyles.motion(s: Style, t: number): (number, number, number)
	local wave = math.sin(2 * math.pi * t / math.max(s.Beat, 0.05))
	return s.Pitch * wave, s.Yaw * wave, s.Roll * wave
end
----------------------------------------------------------------------------------------------------------------------

return AngryStyles
