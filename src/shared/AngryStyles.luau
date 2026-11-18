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

----------------------------------------------------------------------------------------------------------------------
-- THE STRUGGLE ON THE OXYGEN TICKS (Hugo, 2026-11-18: "when a fish gets into the red zone and it plays the struggling
-- animation, make sure the oxygen loss ticks are matched up with the animation of the fish"). A THRASH is each
-- extreme of the struggle: the stand-in sine's top and bottom (a wag to each side, a nod up and a nod down), so one
-- every half Beat, and where a style's slow-down has a cycle (Period = Beat) its deepest stall falls on it too.
--   The server (RideService): while the fish is angry, the gap to the next tick is at least Oxygen.RedTick and then
--   lengthened to a whole number of thrashes (AngryStyles.snapGap) when that adds at most Sync.Bend of itself (task
--   r1: never shortened); a longer gap takes a bigger piece, so the seconds on the fish hold.
--   The client (AngryController hears each "OxygenTick" and its gap, AngryStyles.tick): the struggle is phase-locked
--   to the ticks: a thrash on the tick just heard and one on the next, with a whole number of thrashes between them
--   (the Beat stretched or squeezed the rest of the way), so the two can't drift. motion() and speed() read that
--   locked clock. Nothing is locked on the server, nor before the first tick: there they run on `t` as before.
-- Numbers here, not in Config, while this belongs to the angry mode's files; they read live like Config's.
AngryStyles.Sync = {
	On = 1, -- 0: the struggle runs on its own clock again, and the server leaves the gaps alone
	Bend = 0.2, -- the most the server lengthens a red-zone tick, as a share of its gap, to land it on a thrash
	Pull = 10, -- how quickly the struggle catches a beat it is off (a late or early tick), per second
	-- Seconds the struggle runs ahead of the ticks, because the fish's body trails what it is given: the stand-in
	-- goes through the turn spring (RideController), measured 70 to 90 ms behind on a Clownfish (2026-11-18). An
	-- animation played on the body itself has no such lag: set it to 0 for the real ones.
	Lead = 0.08,
}

-- Seconds between two thrashes of a style, as authored
function AngryStyles.thrashEvery(s: Style): number
	return math.max(s.Beat, 0.05) / 2
end

-- How many thrashes a gap of `gap` seconds holds best (at least one): the whole number nearest by ratio, so the
-- Beat is bent as little as it can be either way
function AngryStyles.thrashesIn(s: Style, gap: number): number
	local x = math.max(gap, 0.01) / AngryStyles.thrashEvery(s)
	local n = math.max(1, math.floor(x))
	if x >= 1 and x / n > (n + 1) / x then
		n += 1
	end
	return n
end

-- The server's gap to the next tick while the fish is angry: the next whole number of thrashes at or above `gap`, if
-- that lengthens it by at most Sync.Bend and is not under `least` (Oxygen.Tick), else `gap` as it was. Never shorter
-- (task r1, 2026-11-18: the red part's ticks are never quicker than the fish's own; until then it snapped to the
-- nearest, either way). The server makes the piece bigger to match (RideService.redGap), so the seconds hold.
function AngryStyles.snapGap(s: Style, gap: number, least: number): number
	local sync = AngryStyles.Sync
	if sync.On == 0 or gap <= 0 then
		return gap
	end
	local every = AngryStyles.thrashEvery(s)
	local snapped = math.max(1, math.ceil(gap / every - 1e-6)) * every
	if snapped >= least and snapped >= gap and snapped / gap - 1 <= sync.Bend then
		return snapped
	end
	return gap
end

-- The client's lock (one: only the rider's own fish struggles on their screen)
local lock = {
	At = -1, -- os.clock() the last tick was heard (-1: none yet)
	Gap = 0, -- seconds from it to the next, as the server said
	Phase = 0, -- where the struggle is, in turns of its Beat (a thrash at 0.25 and 0.75)
	Last = -1, -- the `t` it was last moved on at
}

-- A tick was just heard (Ride "OxygenTick"), the next due in `gap` seconds: lock the struggle to it
function AngryStyles.tick(gap: number)
	if gap > 0 then
		lock.At = os.clock()
		lock.Gap = gap
	end
end

-- The thrash the struggle is locked to now: seconds between thrashes (the Beat bent to fit the ticks) and seconds
-- to the next tick (0 to the gap), or nil with nothing locked. For animations that play by the beat (see below).
function AngryStyles.beat(s: Style): (number?, number?)
	if AngryStyles.Sync.On == 0 or lock.At < 0 then
		return nil, nil
	end
	local every = lock.Gap / AngryStyles.thrashesIn(s, lock.Gap)
	local since = os.clock() - lock.At
	return every, lock.Gap - since % lock.Gap
end

-- The struggle's clock: `t` seconds into being angry, turned into where in its cycle the struggle is (seconds, as
-- motion() and share() read time). Moved on once a frame (a second call at the same `t` gives the same).
function AngryStyles.clock(s: Style, t: number): number
	local every = AngryStyles.beat(s)
	if not every then
		return t
	end
	-- where a thrash on each tick puts the struggle now: a thrash (0.25) on the last tick heard, then one every `every`
	-- (Sync.Lead ahead, so the body, which trails, is at the thrash on the tick)
	local want = 0.25 + (os.clock() + AngryStyles.Sync.Lead - lock.At) / (2 * every)
	local dt = t - lock.Last
	if lock.Last < 0 or dt < 0 or dt > 0.5 then
		lock.Phase = want -- (a new stretch of anger, or a long pause: straight onto the beat)
	else
		lock.Phase += dt / (2 * every)
		-- (off by part of a thrash: pulled to the nearest one, top or bottom, never a half turn round)
		local off = (want - lock.Phase + 0.25) % 0.5 - 0.25
		lock.Phase += off * Ease.alpha(AngryStyles.Sync.Pull, dt)
	end
	lock.Phase %= 1
	lock.Last = t
	return lock.Phase * math.max(s.Beat, 0.05)
end
----------------------------------------------------------------------------------------------------------------------

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
	-- (on the ticks' beat, AngryStyles.clock; a Fade isn't a cycle, it runs on `t`)
	local loss = 1 - AngryStyles.share(s, if s.Shape == "Fade" then t else AngryStyles.clock(s, t))
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
-- Its thrashes (the sine's top and bottom) fall on the Oxygen ticks: it runs on AngryStyles.clock.
-- FOR THE REAL ANIMATIONS (the partner's): mark each thrash in the struggle animation with a keyframe marker named
-- "Thrash" (one or more a loop, evenly spaced). To keep them on the ticks, each frame: `every, toNext =
-- AngryStyles.beat(style)`; play the track at speed (marker spacing in the animation) / every, and when a tick is heard
-- (AngryStyles.tick, from AngryController) nudge TimePosition so the next "Thrash" is toNext seconds of play away.
-- With no lock (nil), play it at its own speed. Docs: docs/design/riding-feel.md, "The struggle on the ticks".
function AngryStyles.motion(s: Style, t: number): (number, number, number)
	local wave = math.sin(2 * math.pi * AngryStyles.clock(s, t) / math.max(s.Beat, 0.05))
	return s.Pitch * wave, s.Yaw * wave, s.Roll * wave
end
----------------------------------------------------------------------------------------------------------------------

return AngryStyles
